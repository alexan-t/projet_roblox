// Republication d'assets sous le propriétaire de l'expérience par Open Cloud (docs/ASSET_OWNERSHIP.md
// § 6, voie C de docs/REPUBLICATION_LOT_PILOTE.md). Node seul (aucune dépendance).
//
//   node tools/republish-assets.mjs lot <nom> <sortie-du-contrôle.tsv> <userId>
//     Crée automation/republication/<nom>.json à partir des lignes FIX-PROPRIETAIRE imprimées par
//     tools/studio-check-asset-ownership.luau (images et meshes).
//   node tools/republish-assets.mjs download <lot.json> [--only <id,id>] [--limit N]
//     Télécharge le fichier d'origine de chaque ancien AssetId (Asset Delivery, scope
//     legacy-asset:manage), le décompresse et contrôle son format (PNG/JPEG < 8000 px, mesh Roblox
//     « version x.yz », < 20 Mo). Aucune écriture côté Roblox.
//   node tools/republish-assets.mjs publish <lot.json> --confirm [--only <id,id>] [--limit N]
//     Publie les fichiers contrôlés sous creationContext.creator.userId = targetOwner.userId du lot
//     (Assets API, scopes asset:read + asset:write), attend l'opération, puis relit l'asset pour
//     vérifier le propriétaire. Sans --limit, un seul asset par lancement.
//   node tools/republish-assets.mjs refresh <lot.json>
//     Relit propriétaire et modération des assets publiés non encore approuvés (« Reviewing »).
//   node tools/republish-assets.mjs status <lot.json>
//   node tools/republish-assets.mjs mapping <lot.json>
//     Écrit build/republication/<lot>/mapping.luau (bloc MAPPING de tools/studio-replace-asset-ids.luau)
//     et mapping.json, pour les seuls assets publiés, approuvés et au bon propriétaire.
//
// Clé : variable d'environnement ROBLOX_OPEN_CLOUD_KEY, ou ROBLOX_OPEN_CLOUD_KEY_FILE (chemin d'un
// fichier HORS du dépôt). La clé n'est jamais écrite, affichée ni envoyée ailleurs qu'à
// apis.roblox.com (pas à l'URL CDN du téléchargement). Elle appartient au propriétaire cible.
// Travail, journal et reprise : build/republication/<lot>/ (state.json, journal.jsonl, files/).

import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import zlib from "node:zlib";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const API = "https://apis.roblox.com";
const MAX_BYTES = 20 * 1024 * 1024;
const MAX_IMAGE_SIDE = 8000;
// Intervalle minimal entre deux appels (quotas : livraison 1000/min, création 120/min, opérations 300/min).
const SPACING_MS = { delivery: 100, cdn: 0, create: 700, operation: 250, read: 600 };
const CONTENT_TYPES = { Image: { png: "image/png", jpeg: "image/jpeg" }, Mesh: { mesh: "model/x-file-mesh-data" } };

export class HttpError extends Error {
	constructor(status, message) {
		super(message);
		this.status = status;
	}
}

export function loadKey(env = process.env) {
	let key = env.ROBLOX_OPEN_CLOUD_KEY;
	if (!key && env.ROBLOX_OPEN_CLOUD_KEY_FILE) {
		const file = path.resolve(env.ROBLOX_OPEN_CLOUD_KEY_FILE);
		if (!path.relative(ROOT, file).startsWith("..")) {
			throw new Error("ROBLOX_OPEN_CLOUD_KEY_FILE doit être hors du dépôt");
		}
		key = fs.readFileSync(file, "utf8").trim();
	}
	if (!key) throw new Error("clé absente : définir ROBLOX_OPEN_CLOUD_KEY ou ROBLOX_OPEN_CLOUD_KEY_FILE");
	return key;
}

// Format du fichier téléchargé. Renvoie { kind, ext, width?, height?, meshVersion? } ou lève une erreur.
export function inspectFile(bytes, type) {
	if (bytes.length === 0) throw new Error("fichier vide");
	if (bytes.length > MAX_BYTES) throw new Error(`fichier trop gros (${bytes.length} octets > 20 Mo)`);
	if (type === "Image") {
		if (bytes.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) {
			const width = bytes.readUInt32BE(16);
			const height = bytes.readUInt32BE(20);
			if (width >= MAX_IMAGE_SIDE || height >= MAX_IMAGE_SIDE) throw new Error(`image trop grande (${width}×${height})`);
			return { kind: "png", ext: "png", width, height };
		}
		if (bytes[0] === 0xff && bytes[1] === 0xd8) return { kind: "jpeg", ext: "jpg" };
		throw new Error(`image dans un format inattendu (début : ${bytes.subarray(0, 12).toString("hex")})`);
	}
	if (type === "Mesh") {
		const head = bytes.subarray(0, 13).toString("latin1");
		const match = /^version (\d\.\d\d)/.exec(head);
		if (!match) throw new Error(`mesh dans un format inattendu (début : ${JSON.stringify(head)})`);
		return { kind: "mesh", ext: "mesh", meshVersion: match[1] };
	}
	throw new Error(`type non géré : ${type}`);
}

export function createClient({ key, fetchImpl = fetch, sleep = (ms) => new Promise((r) => setTimeout(r, ms)), log = () => {} }) {
	const last = {};
	const redact = (text) => String(text).split(key).join("<clé>");

	async function call(kind, url, init = {}, { auth = true, retries = 5 } = {}) {
		for (let attempt = 0; ; attempt++) {
			const wait = (last[kind] ?? 0) + SPACING_MS[kind] - Date.now();
			if (wait > 0) await sleep(wait);
			last[kind] = Date.now();
			const headers = { ...(init.headers ?? {}) };
			if (auth) {
				if (new URL(url).origin !== API) throw new Error("la clé n'est envoyée qu'à apis.roblox.com");
				headers["x-api-key"] = key;
			}
			let response;
			try {
				response = await fetchImpl(url, { ...init, headers });
			} catch (error) {
				if (attempt >= retries) throw new Error(redact(`réseau : ${error.message}`));
				await sleep(1000 * 2 ** attempt);
				continue;
			}
			if (response.ok) return response;
			const body = redact((await response.text()).slice(0, 300));
			if ((response.status === 429 || response.status >= 500) && attempt < retries) {
				const retryAfter = Number(response.headers.get("retry-after"));
				const delay = Number.isFinite(retryAfter) && retryAfter > 0 ? retryAfter * 1000 : 1000 * 2 ** attempt;
				log(`HTTP ${response.status} sur ${kind}, nouvel essai dans ${Math.round(delay / 1000)} s`);
				await sleep(delay);
				continue;
			}
			throw new HttpError(response.status, `HTTP ${response.status} (${kind}) : ${body}`);
		}
	}

	async function download(assetId) {
		const meta = await (await call("delivery", `${API}/asset-delivery-api/v1/assetId/${assetId}`, { headers: { "Accept-Encoding": "gzip" } })).json();
		if (!meta.location) throw new Error(`réponse sans location : ${redact(JSON.stringify(meta).slice(0, 200))}`);
		// URL CDN temporaire : jamais de clé.
		const response = await call("cdn", meta.location, { headers: { "Accept-Encoding": "gzip" } }, { auth: false });
		let bytes = Buffer.from(await response.arrayBuffer());
		if (bytes[0] === 0x1f && bytes[1] === 0x8b) bytes = zlib.gunzipSync(bytes);
		return bytes;
	}

	async function publish({ bytes, type, format, displayName, description, userId }) {
		const contentType = CONTENT_TYPES[type]?.[format];
		if (!contentType) throw new Error(`pas de type de contenu pour ${type}/${format}`);
		const form = new FormData();
		form.append("request", JSON.stringify({ assetType: type, displayName, description, creationContext: { creator: { userId: String(userId) } } }));
		form.append("fileContent", new Blob([bytes], { type: contentType }), `${displayName}.${format}`);
		let operation = await (await call("create", `${API}/assets/v1/assets`, { method: "POST", body: form })).json();
		const operationId = String(operation.operationId ?? operation.path ?? "").replace(/^operations\//, "");
		if (!operationId) throw new Error(`réponse sans opération : ${redact(JSON.stringify(operation).slice(0, 200))}`);
		for (let poll = 0; !operation.done; poll++) {
			if (poll >= 30) throw new Error(`opération ${operationId} non terminée après 30 lectures`);
			await sleep(Math.min(1000 * (poll + 1), 5000));
			operation = await (await call("operation", `${API}/assets/v1/operations/${operationId}`)).json();
		}
		if (operation.error) throw new Error(`opération ${operationId} en erreur : ${redact(JSON.stringify(operation.error))}`);
		const asset = operation.response ?? {};
		return { operationId, newId: String(asset.assetId ?? ""), moderation: asset.moderationResult?.moderationState ?? "INCONNU" };
	}

	async function readAsset(assetId) {
		// Sans readMask, la réponse ne contient pas moderationResult.
		return (await call("read", `${API}/assets/v1/assets/${assetId}?readMask=creationContext,moderationResult`)).json();
	}

	return { download, publish, readAsset, redact };
}

// L'API renvoie « Approved » (constaté le 24/10/2026) ; la doc annonce « MODERATION_STATE_APPROVED ».
export const isApproved = (state) => state === "Approved" || state === "MODERATION_STATE_APPROVED";

// --- Lot, état et journal ---

export function loadLot(file) {
	const lot = JSON.parse(fs.readFileSync(file, "utf8"));
	if (!/^\d+$/.test(String(lot.targetOwner?.userId ?? ""))) throw new Error("targetOwner.userId manquant dans le lot");
	const seen = new Set();
	for (const asset of lot.assets) {
		if (!/^\d+$/.test(asset.oldId)) throw new Error(`oldId invalide : ${asset.oldId}`);
		if (!CONTENT_TYPES[asset.type]) throw new Error(`type non géré pour ${asset.oldId} : ${asset.type}`);
		if (seen.has(asset.oldId)) throw new Error(`oldId en double dans le lot : ${asset.oldId}`);
		seen.add(asset.oldId);
	}
	return lot;
}

export function openWorkspace(lotName, root = path.join(ROOT, "build", "republication")) {
	const dir = path.join(root, lotName);
	fs.mkdirSync(path.join(dir, "files"), { recursive: true });
	const stateFile = path.join(dir, "state.json");
	const state = fs.existsSync(stateFile) ? JSON.parse(fs.readFileSync(stateFile, "utf8")) : {};
	return {
		dir,
		state,
		save() {
			fs.writeFileSync(`${stateFile}.tmp`, JSON.stringify(state, null, 2));
			fs.renameSync(`${stateFile}.tmp`, stateFile);
		},
		journal(entry) {
			fs.appendFileSync(path.join(dir, "journal.jsonl"), `${JSON.stringify({ at: new Date().toISOString(), ...entry })}\n`);
		},
	};
}

function select(lot, { only, limit }) {
	let assets = lot.assets;
	if (only) assets = assets.filter((asset) => only.includes(asset.oldId));
	return limit ? assets.slice(0, limit) : assets;
}

export async function runDownload(lot, work, client, options = {}, log = console.log) {
	let ok = 0;
	let failed = 0;
	for (const asset of select(lot, options)) {
		const entry = (work.state[asset.oldId] ??= {});
		if (entry.download?.ok) continue; // reprise : déjà téléchargé et contrôlé
		try {
			const bytes = await client.download(asset.oldId);
			const format = inspectFile(bytes, asset.type);
			const sha256 = crypto.createHash("sha256").update(bytes).digest("hex");
			const file = path.join(work.dir, "files", `${asset.oldId}.${format.ext}`);
			fs.writeFileSync(file, bytes);
			entry.download = { ok: true, file: path.relative(work.dir, file), bytes: bytes.length, sha256, ...format };
			work.journal({ step: "download", oldId: asset.oldId, ok: true, bytes: bytes.length, sha256, ...format });
			log(`OK   #${asset.n} ${asset.oldId} ${asset.type} ${format.kind}${format.width ? ` ${format.width}×${format.height}` : ""}${format.meshVersion ? ` v${format.meshVersion}` : ""} ${bytes.length} o`);
			ok++;
		} catch (error) {
			entry.download = { ok: false, error: client.redact(error.message), status: error.status };
			work.journal({ step: "download", oldId: asset.oldId, ok: false, status: error.status, error: client.redact(error.message) });
			log(`KO   #${asset.n} ${asset.oldId} : ${client.redact(error.message)}`);
			failed++;
		}
		work.save();
	}
	return { ok, failed };
}

export async function runPublish(lot, work, client, options = {}, log = console.log) {
	if (!options.confirm) throw new Error("publication refusée sans --confirm");
	const userId = String(lot.targetOwner.userId);
	const bySha = new Map();
	for (const [oldId, entry] of Object.entries(work.state)) {
		if (entry.publish?.newId) bySha.set(entry.download?.sha256, { oldId, ...entry.publish });
	}
	let published = 0;
	let failed = 0;
	const todo = select(lot, { only: options.only }).filter((asset) => !work.state[asset.oldId]?.publish?.newId);
	for (const asset of todo.slice(0, options.limit ?? 1)) {
		const entry = work.state[asset.oldId] ?? {};
		if (!entry.download?.ok) {
			log(`SAUTÉ #${asset.n} ${asset.oldId} : pas de fichier contrôlé (lancer download)`);
			continue;
		}
		const duplicate = bySha.get(entry.download.sha256);
		if (duplicate) {
			entry.publish = { ...duplicate, duplicateOf: duplicate.oldId };
			work.journal({ step: "publish", oldId: asset.oldId, duplicateOf: duplicate.oldId, newId: duplicate.newId });
			log(`DOUBLON #${asset.n} ${asset.oldId} = ${duplicate.oldId} → ${duplicate.newId}`);
			work.save();
			continue;
		}
		try {
			const bytes = fs.readFileSync(path.join(work.dir, entry.download.file));
			if (crypto.createHash("sha256").update(bytes).digest("hex") !== entry.download.sha256) throw new Error("fichier modifié depuis le contrôle");
			const displayName = `${lot.lot}_${asset.n}_${asset.piece.split(".").slice(-2).join("_")}`.replace(/[^\w-]/g, "_").slice(0, 50);
			const description = `Republication sous le propriétaire de l'expérience. Ancien AssetId ${asset.oldId} (${asset.oldOwner ?? "?"}).`;
			const result = await client.publish({ bytes, type: asset.type, format: entry.download.kind, displayName, description, userId });
			if (!/^\d+$/.test(result.newId)) throw new Error(`opération ${result.operationId} sans assetId`);
			const meta = await client.readAsset(result.newId);
			const owner = String(meta.creationContext?.creator?.userId ?? meta.creationContext?.creator?.groupId ?? "");
			entry.publish = { ...result, owner, ownerOk: owner === userId };
			bySha.set(entry.download.sha256, { oldId: asset.oldId, ...entry.publish });
			work.journal({ step: "publish", oldId: asset.oldId, ...entry.publish });
			log(`${entry.publish.ownerOk ? "PUBLIÉ" : "PROPRIÉTAIRE FAUX"} #${asset.n} ${asset.oldId} → ${result.newId} (${result.moderation}, propriétaire ${owner})`);
			published++;
		} catch (error) {
			entry.publishError = client.redact(error.message);
			work.journal({ step: "publish", oldId: asset.oldId, ok: false, status: error.status, error: entry.publishError });
			log(`KO   #${asset.n} ${asset.oldId} : ${entry.publishError}`);
			failed++;
		}
		work.state[asset.oldId] = entry;
		work.save();
	}
	return { published, failed, remaining: Math.max(0, todo.length - (options.limit ?? 1)) };
}

// Relit le propriétaire et la modération des assets publiés mais pas encore approuvés (« Reviewing »).
export async function runRefresh(lot, work, client, log = console.log) {
	const userId = String(lot.targetOwner.userId);
	let approved = 0;
	let pending = 0;
	let failed = 0;
	for (const asset of lot.assets) {
		const publish = work.state[asset.oldId]?.publish;
		if (!publish?.newId || (isApproved(publish.moderation) && publish.ownerOk)) continue;
		try {
			const meta = await client.readAsset(publish.newId);
			publish.moderation = meta.moderationResult?.moderationState ?? "INCONNU";
			publish.owner = String(meta.creationContext?.creator?.userId ?? meta.creationContext?.creator?.groupId ?? "");
			publish.ownerOk = publish.owner === userId;
			work.journal({ step: "refresh", oldId: asset.oldId, newId: publish.newId, moderation: publish.moderation, owner: publish.owner });
			log(`${isApproved(publish.moderation) ? "APPROUVÉ" : publish.moderation} #${asset.n} ${publish.newId}`);
			if (isApproved(publish.moderation)) approved++;
			else pending++;
		} catch (error) {
			log(`KO   #${asset.n} ${publish.newId} : ${client.redact(error.message)}`);
			failed++;
		}
		work.save();
	}
	return { approved, pending, failed };
}

export function buildMapping(lot, work) {
	const ready = [];
	const pending = [];
	for (const asset of lot.assets) {
		const publish = work.state[asset.oldId]?.publish;
		if (publish?.newId && publish.ownerOk && isApproved(publish.moderation)) ready.push([asset.oldId, publish.newId]);
		else pending.push(asset.oldId);
	}
	const luau = `local MAPPING: { [string]: string } = {\n${ready.map(([o, n]) => `\t["${o}"] = "${n}",`).join("\n")}\n}\n`;
	return { ready, pending, luau };
}

// Lot à partir de la sortie de tools/studio-check-asset-ownership.luau (lignes « FIX-PROPRIETAIRE »,
// colonnes Statut, AssetId, Type, Nom, Propriétaire, Références). Types 1 = Image, 4 = Mesh.
export function lotFromCheckOutput(name, text, userId) {
	const types = { 1: "Image", 4: "Mesh" };
	const assets = [];
	const skipped = [];
	for (const line of text.split(/\r?\n/)) {
		const cols = line.split("\t");
		if (cols[0].trim() !== "FIX-PROPRIETAIRE") continue;
		const [, oldId, type, , owner, where] = cols.map((c) => c.trim());
		if (!types[type]) {
			skipped.push(`${oldId} (type ${type})`);
			continue;
		}
		if (assets.some((a) => a.oldId === oldId)) continue;
		assets.push({ n: assets.length + 1, piece: (where ?? "").replace(/\.(MeshId|TextureID|TextureId|ColorMap|Texture|Image)( \(\+\d+\))?$/, ""), type: types[type], oldId, oldOwner: owner });
	}
	return { lot: { lot: name, targetOwner: { userId: String(userId) }, assets }, skipped };
}

// --- Ligne de commande ---

function parseArgs(argv) {
	const [command, lotFile, ...rest] = argv;
	const options = {};
	for (let i = 0; i < rest.length; i++) {
		if (rest[i] === "--confirm") options.confirm = true;
		else if (rest[i] === "--only") options.only = rest[++i].split(",");
		else if (rest[i] === "--limit") options.limit = Number(rest[++i]);
		else throw new Error(`option inconnue : ${rest[i]}`);
	}
	return { command, lotFile, options };
}

async function main() {
	if (process.argv[2] === "lot") {
		const [, , , name, input, userId] = process.argv;
		if (!name || !input || !/^\d+$/.test(userId ?? "")) throw new Error("usage : lot <nom> <sortie-du-contrôle.tsv> <userId propriétaire>");
		const { lot, skipped } = lotFromCheckOutput(name, fs.readFileSync(input, "utf8"), userId);
		const out = path.join(ROOT, "automation", "republication", `${name}.json`);
		fs.writeFileSync(out, `${JSON.stringify(lot, null, 2)}\n`);
		console.log(`${lot.assets.length} assets → ${path.relative(ROOT, out)}${skipped.length ? ` ; ignorés (type non republiable ici) : ${skipped.join(", ")}` : ""}`);
		return;
	}
	const { command, lotFile, options } = parseArgs(process.argv.slice(2));
	if (!command || !lotFile) {
		console.log("Usage : node tools/republish-assets.mjs <lot|download|publish|refresh|status|mapping> <lot.json> [--only id,id] [--limit N] [--confirm]");
		process.exit(2);
	}
	const lot = loadLot(lotFile);
	const work = openWorkspace(lot.lot);
	if (command === "status") {
		const count = (test) => lot.assets.filter((a) => test(work.state[a.oldId] ?? {})).length;
		console.log(`${lot.assets.length} assets : ${count((e) => e.download?.ok)} téléchargés, ${count((e) => e.download && !e.download.ok)} en échec, ${count((e) => e.publish?.newId)} publiés, ${count((e) => isApproved(e.publish?.moderation))} approuvés`);
		return;
	}
	if (command === "mapping") {
		const { ready, pending, luau } = buildMapping(lot, work);
		fs.writeFileSync(path.join(work.dir, "mapping.luau"), luau);
		fs.writeFileSync(path.join(work.dir, "mapping.json"), `${JSON.stringify(Object.fromEntries(ready), null, 2)}\n`);
		console.log(`${ready.length} paires prêtes, ${pending.length} en attente → ${path.relative(ROOT, work.dir)}/mapping.luau`);
		return;
	}
	const client = createClient({ key: loadKey(), log: console.log });
	const result = command === "download" ? await runDownload(lot, work, client, options) : command === "publish" ? await runPublish(lot, work, client, options) : command === "refresh" ? await runRefresh(lot, work, client) : null;
	if (!result) throw new Error(`commande inconnue : ${command}`);
	console.log(JSON.stringify(result));
	if (result.failed) process.exitCode = 1;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
	main().catch((error) => {
		console.error(`Erreur : ${error.message}`);
		process.exit(1);
	});
}
