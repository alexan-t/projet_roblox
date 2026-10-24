// Outil de republication Open Cloud (tools/republish-assets.mjs) contre un faux Roblox : aucun appel réseau.
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import zlib from "node:zlib";

import { buildMapping, createClient, inspectFile, loadKey, lotFromCheckOutput, openWorkspace, runDownload, runPublish } from "../tools/republish-assets.mjs";

const KEY = "cle-secrete-de-test-123";
const png = (w, h) => {
	const bytes = Buffer.alloc(33);
	Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]).copy(bytes);
	bytes.writeUInt32BE(13, 8);
	bytes.write("IHDR", 12, "latin1");
	bytes.writeUInt32BE(w, 16);
	bytes.writeUInt32BE(h, 20);
	return bytes;
};
const mesh = Buffer.from("version 5.00\nbinary-data", "latin1");

const lot = {
	lot: "lot-test",
	targetOwner: { userId: "11714751172" },
	assets: [
		{ n: 1, piece: "Ennemi_Slime.body.body_geom", type: "Image", oldId: "107504521703864", oldOwner: "cypher1359" },
		{ n: 2, piece: "Ennemi_Slime.body.body_geom", type: "Mesh", oldId: "98155401096105", oldOwner: "cypher1359" },
		{ n: 3, piece: "Copie.body", type: "Image", oldId: "111", oldOwner: "cypher1359" },
	],
};

function fakeRoblox({ files, failFirst = {} }) {
	const calls = [];
	let nextAsset = 900;
	const json = (body, status = 200) => new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });
	const fetchImpl = async (url, init = {}) => {
		const u = new URL(url);
		calls.push({ url, method: init.method ?? "GET", key: init.headers?.["x-api-key"] });
		if (failFirst[u.pathname] > 0) {
			failFirst[u.pathname]--;
			return new Response("trop vite", { status: 429, headers: { "retry-after": "1" } });
		}
		let m = /^\/asset-delivery-api\/v1\/assetId\/(\d+)$/.exec(u.pathname);
		if (m) return files[m[1]] ? json({ location: `https://cdn.example.test/${m[1]}` }) : json({ errors: [{ message: "Asset not found" }] }, 404);
		m = /^\/(\d+)$/.exec(u.pathname);
		if (u.host === "cdn.example.test" && m) return new Response(zlib.gzipSync(files[m[1]]));
		if (u.pathname === "/assets/v1/assets" && init.method === "POST") {
			const request = JSON.parse(init.body.get("request"));
			assert.equal(request.creationContext.creator.userId, "11714751172");
			const id = String(nextAsset++);
			return json({ path: `operations/op-${id}`, done: false });
		}
		m = /^\/assets\/v1\/operations\/op-(\d+)$/.exec(u.pathname);
		if (m) return json({ done: true, response: { assetId: m[1], moderationResult: { moderationState: "Approved" } } });
		m = /^\/assets\/v1\/assets\/(\d+)$/.exec(u.pathname);
		if (m) return json({ assetId: m[1], creationContext: { creator: { userId: "11714751172" } } });
		return new Response("inconnu", { status: 500 });
	};
	return { calls, fetchImpl };
}

const tmpWork = () => openWorkspace("lot-test", fs.mkdtempSync(path.join(os.tmpdir(), "republish-")));
const quiet = () => {};

test("inspectFile reconnaît PNG et mesh, refuse le reste", () => {
	assert.deepEqual(inspectFile(png(1024, 1024), "Image"), { kind: "png", ext: "png", width: 1024, height: 1024 });
	assert.equal(inspectFile(mesh, "Mesh").meshVersion, "5.00");
	assert.throws(() => inspectFile(png(9000, 10), "Image"), /trop grande/);
	assert.throws(() => inspectFile(mesh, "Image"), /format inattendu/);
	assert.throws(() => inspectFile(Buffer.from("<roblox>"), "Mesh"), /format inattendu/);
});

test("lotFromCheckOutput lit les lignes FIX-PROPRIETAIRE du contrôle Studio", () => {
	const text = [
		"Propriétaire cible : User 11714751172 — 4 AssetIds",
		"FIX-PROPRIETAIRE\t70477964649838\t1\timage\tcypher1359\tServerStorage.Assets.Royaume.HutteChaume.TextureID",
		"FIX-PROPRIETAIRE\t89350036237005\t4\tmaillage\tcypher1359\tServerStorage.Assets.Royaume.HutteChaume.MeshId (+3)",
		"FIX-PROPRIETAIRE\t507765000\t24\tAnim\tRoblox\tX.Animate.walk.AnimationId",
		"OK\t99196320622532\t1\tshop.png\tnxtoma\tMenuIconConfig.Buttons.Shop.Icon",
	].join("\r\n");
	const { lot: built, skipped } = lotFromCheckOutput("royaume-test", text, "11714751172");
	assert.deepEqual(built.assets.map((a) => [a.oldId, a.type, a.piece]), [
		["70477964649838", "Image", "ServerStorage.Assets.Royaume.HutteChaume"],
		["89350036237005", "Mesh", "ServerStorage.Assets.Royaume.HutteChaume"],
	]);
	assert.deepEqual(skipped, ["507765000 (type 24)"]);
});

test("loadKey refuse un fichier de clé dans le dépôt", () => {
	assert.equal(loadKey({ ROBLOX_OPEN_CLOUD_KEY: "abc" }), "abc");
	assert.throws(() => loadKey({ ROBLOX_OPEN_CLOUD_KEY_FILE: "package.json" }), /hors du dépôt/);
	assert.throws(() => loadKey({}), /clé absente/);
});

test("download : décompresse, contrôle, journalise, reprend et n'envoie jamais la clé au CDN", async () => {
	const files = { "107504521703864": png(1024, 1024), "98155401096105": mesh };
	const roblox = fakeRoblox({ files, failFirst: { "/asset-delivery-api/v1/assetId/107504521703864": 1 } });
	const client = createClient({ key: KEY, fetchImpl: roblox.fetchImpl, sleep: async () => {} });
	const work = tmpWork();
	const lines = [];
	const result = await runDownload(lot, work, client, {}, (l) => lines.push(l));
	assert.deepEqual(result, { ok: 2, failed: 1 }); // 111 : 404
	assert.equal(work.state["107504521703864"].download.width, 1024);
	assert.equal(work.state["111"].download.status, 404);
	for (const call of roblox.calls) {
		if (new URL(call.url).host === "cdn.example.test") assert.equal(call.key, undefined);
		else assert.equal(call.key, KEY);
	}
	const written = fs.readFileSync(path.join(work.dir, "journal.jsonl"), "utf8") + lines.join("\n") + JSON.stringify(work.state);
	assert.ok(!written.includes(KEY), "la clé ne doit apparaître ni dans le journal ni dans les messages");
	const before = roblox.calls.length;
	await runDownload(lot, work, client, { only: ["107504521703864"] }, quiet);
	assert.equal(roblox.calls.length, before, "un asset déjà contrôlé n'est pas retéléchargé");
});

test("publish : exige --confirm, un asset par défaut, détecte les doublons, puis mapping", async () => {
	const files = { "107504521703864": png(64, 64), "98155401096105": mesh, "111": png(64, 64) };
	const roblox = fakeRoblox({ files });
	const client = createClient({ key: KEY, fetchImpl: roblox.fetchImpl, sleep: async () => {} });
	const work = tmpWork();
	await runDownload(lot, work, client, {}, quiet);
	await assert.rejects(runPublish(lot, work, client, {}, quiet), /--confirm/);
	assert.equal((await runPublish(lot, work, client, { confirm: true }, quiet)).published, 1);
	await runPublish(lot, work, client, { confirm: true, limit: 5 }, quiet);
	assert.equal(work.state["111"].publish.duplicateOf, "107504521703864"); // même contenu : pas de seconde publication
	assert.equal(roblox.calls.filter((c) => c.method === "POST").length, 2);
	const { ready, pending, luau } = buildMapping(lot, work);
	assert.equal(ready.length, 3);
	assert.equal(pending.length, 0);
	assert.match(luau, /\["98155401096105"\] = "\d+",/);
});
