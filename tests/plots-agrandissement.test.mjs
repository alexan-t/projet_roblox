// Contrôle hors Studio de l'agrandissement des parcelles (docs/PLOTS.md § Agrandissement), sans Luau :
// `node tests/plots-agrandissement.test.mjs`. Lecture seule.
//   - tools/studio-agrandir-plots.luau : réglages = tableau de la doc, une étape Ctrl+Z annulée en cas
//     d'erreur, répétable, refus avant toute modification si deux sols voisins se touchent, rien de supprimé ;
//   - SIMULATION : la géométrie du script (survey, plan, apply, neighbourGap, recalculés ici à l'identique)
//     est appliquée aux 8 Lobby.Plots du snapshot studio/sandbox/partner_sandbox_v4.rbxl (format binaire
//     lu ici : chunks LZ4, INST, PROP, PRNT). Vérifie les mesures avant / après de la doc, les repères
//     immobiles (dalles, royaume, portail, pancartes), le front ennemi reculé, l'absence de chevauchement
//     entre plots voisins, la forêt et les murs invisibles, et un couloir de combat sans obstacle.
// Ne prouve pas l'état de la DEV Studio : seules les captures avant / après et la grille PASS/FIX
// de docs/PLOTS.md le font. Les boîtes des modèles sont alignées sur le repère du front (Studio :
// GetBoundingBox orientée), d'où une tolérance de quelques dixièmes sur les mesures.
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const read = (path) => readFileSync(join(repoRoot, path));
const SNAPSHOT = 'studio/sandbox/partner_sandbox_v4.rbxl';
const SCRIPT = 'tools/studio-agrandir-plots.luau';

let passed = 0;
let failed = 0;
function test(name, run) {
	try {
		run();
		passed += 1;
		console.log(`PASS ${name}`);
	} catch (err) {
		failed += 1;
		console.log(`FAIL ${name}: ${err.message}`);
	}
}
function assert(condition, message) {
	if (!condition) throw new Error(message);
}
const near = (value, expected, tolerance, label) =>
	assert(Math.abs(value - expected) <= tolerance, `${label} : ${value.toFixed(2)} au lieu de ${expected} (± ${tolerance})`);

// --- Script Studio (lu comme texte) ---

const script = read(SCRIPT).toString('utf8').replace(/\r\n/g, '\n');
const constant = (name) => {
	const m = script.match(new RegExp(`^local ${name} = (-?[\\d.]+)`, 'm'));
	assert(m, `${name} absent du script`);
	return Number(m[1]);
};
const doc = read('docs/PLOTS.md').toString('utf8').replace(/\r\n/g, '\n');
const section = doc.slice(doc.indexOf('## Agrandissement pour les combats'), doc.indexOf('## Attribution et nettoyage'));

// --- Snapshot Studio (.rbxl binaire) : noms, CFrame, tailles, formes, collisions ---

function lz4Block(src, size) {
	const out = Buffer.alloc(size);
	let s = 0;
	let d = 0;
	while (s < src.length) {
		const token = src[s++];
		let literals = token >> 4;
		if (literals === 15) for (let b = 255; b === 255; literals += b) b = src[s++];
		src.copy(out, d, s, s + literals);
		s += literals;
		d += literals;
		if (s >= src.length) break;
		const offset = src[s] | (src[s + 1] << 8);
		s += 2;
		let length = token & 15;
		if (length === 15) for (let b = 255; b === 255; length += b) b = src[s++];
		length += 4;
		for (let k = 0; k < length; k++, d++) out[d] = out[d - offset];
	}
	assert(d === size, `LZ4 : ${d} octets au lieu de ${size}`);
	return out;
}

function interleaved(buf, offset, count) {
	const values = [];
	for (let i = 0; i < count; i++)
		values.push(
			((buf[offset + i] << 24) | (buf[offset + count + i] << 16) | (buf[offset + 2 * count + i] << 8) | buf[offset + 3 * count + i]) >>> 0,
		);
	return values;
}
function interleavedInts(buf, offset, count) {
	let previous = 0;
	return interleaved(buf, offset, count).map((raw) => (previous += (raw >>> 1) ^ -(raw & 1)));
}
const floatView = new DataView(new ArrayBuffer(4));
function floats(buf, offset, count) {
	return interleaved(buf, offset, count).map((raw) => {
		floatView.setUint32(0, ((raw >>> 1) | (raw << 31)) >>> 0);
		return floatView.getFloat32(0);
	});
}

const AXES = [[1, 0, 0], [0, 1, 0], [0, 0, 1], [-1, 0, 0], [0, -1, 0], [0, 0, -1]];
const add = (a, b) => [a[0] + b[0], a[1] + b[1], a[2] + b[2]];
const sub = (a, b) => [a[0] - b[0], a[1] - b[1], a[2] - b[2]];
const scale = (a, k) => [a[0] * k, a[1] * k, a[2] * k];
const dot = (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
const cross = (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
const unit = (a) => scale(a, 1 / Math.hypot(...a));

function readPlace(file) {
	assert(file.toString('latin1', 0, 8) === '<roblox!', 'pas un .rbxl binaire');
	const classes = new Map();
	const instances = new Map();
	let p = 32;
	for (;;) {
		const name = file.toString('latin1', p, p + 4);
		const compressed = file.readUInt32LE(p + 4);
		const size = file.readUInt32LE(p + 8);
		p += 16;
		const raw = compressed === 0 ? file.subarray(p, p + size) : file.subarray(p, p + compressed);
		p += compressed === 0 ? size : compressed;
		if (name === 'END\0') break;
		assert(compressed === 0 || raw.readUInt32BE(0) !== 0x28b52ffd, 'chunk ZSTD non pris en charge');
		const chunk = compressed === 0 ? raw : lz4Block(raw, size);
		let c = 0;
		const str = () => {
			const len = chunk.readUInt32LE(c);
			c += 4;
			const value = chunk.subarray(c, c + len);
			c += len;
			return value;
		};
		if (name === 'INST') {
			const classId = chunk.readUInt32LE(0);
			c = 4;
			const className = str().toString('utf8');
			c += 1;
			const count = chunk.readUInt32LE(c);
			c += 4;
			const refs = interleavedInts(chunk, c, count);
			classes.set(classId, { className, refs });
			for (const ref of refs) instances.set(ref, { ref, className, props: {}, children: [] });
		} else if (name === 'PROP') {
			const classId = chunk.readUInt32LE(0);
			c = 4;
			const prop = str().toString('utf8');
			const type = chunk[c++];
			const refs = classes.get(classId).refs;
			const n = refs.length;
			let values;
			if (type === 0x01 && prop === 'Name') values = refs.map(() => str().toString('utf8'));
			else if (type === 0x0e && prop === 'size') {
				const [xs, ys, zs] = [0, 1, 2].map((k) => floats(chunk, c + 4 * n * k, n));
				values = xs.map((x, i) => [x, ys[i], zs[i]]);
			} else if (type === 0x10 && prop === 'CFrame') {
				// Rotation : 0 = neuf flottants (ligne par ligne), sinon identifiant d'une rotation à angle droit.
				const rotations = [];
				for (let i = 0; i < n; i++) {
					const id = chunk[c++];
					if (id !== 0) {
						const x = AXES[Math.floor((id - 1) / 6)];
						const y = AXES[(id - 1) % 6];
						rotations.push([...x, ...y, ...cross(x, y)]);
						continue;
					}
					const m = [];
					for (let k = 0; k < 9; k++, c += 4) m.push(chunk.readFloatLE(c));
					rotations.push(m);
				}
				const [xs, ys, zs] = [0, 1, 2].map((k) => floats(chunk, c + 4 * n * k, n));
				values = rotations.map((r, i) => ({ r, p: [xs[i], ys[i], zs[i]] }));
			} else if (type === 0x12 && prop === 'shape') values = interleaved(chunk, c, n);
			else if (type === 0x09 && prop === 'CanCollide') values = refs.map((_, i) => chunk[c + i] !== 0);
			if (values) refs.forEach((ref, i) => (instances.get(ref).props[prop] = values[i]));
		} else if (name === 'PRNT') {
			const count = chunk.readUInt32LE(1);
			const children = interleavedInts(chunk, 5, count);
			const parents = interleavedInts(chunk, 5 + 4 * count, count);
			children.forEach((child, i) => {
				const instance = instances.get(child);
				instance.parent = instances.get(parents[i]);
				instance.parent?.children.push(instance);
			});
		}
	}
	return [...instances.values()].filter((i) => !i.parent);
}

const nameOf = (instance) => instance.props.Name;
const child = (instance, name) => instance?.children.find((c) => nameOf(c) === name);
const isPart = (instance) => instance.props.CFrame && instance.props.size && instance.className !== 'Attachment';
function descendants(instance, out = []) {
	for (const c of instance.children) {
		out.push(c);
		descendants(c, out);
	}
	return out;
}
const ancestorNamed = (instance, name) => {
	for (let a = instance.parent; a; a = a.parent) if (nameOf(a) === name) return true;
	return false;
};
const column = (cf, i) => [cf.r[i], cf.r[3 + i], cf.r[6 + i]];
const toWorld = (cf, v) => add(cf.p, [dot(cf.r.slice(0, 3), v), dot(cf.r.slice(3, 6), v), dot(cf.r.slice(6, 9), v)]);

// --- Géométrie du script, recalculée à l'identique (mêmes noms que tools/studio-agrandir-plots.luau) ---

const LONGUEUR = constant('LONGUEUR');
const ELARGISSEMENT = constant('ELARGISSEMENT');
const AXE_FIXE = constant('AXE_FIXE');
const BANDE_BORD = constant('BANDE_BORD');
const GRAND_MODELE = constant('GRAND_MODELE');
const MARGE_FORET = constant('MARGE_FORET');
const ECART_MIN_VOISINS = constant('ECART_MIN_VOISINS');
const ENTIERS = new Set(['Royaume', 'PortailInvocation', 'PanneauProprietaire', 'PanneauStage']);
const IGNORES = new Set(['Emplacements', 'Runtime']);

function makeFrame(front) {
	const x = column(front.props.CFrame, 0);
	const X = unit([x[0], 0, x[2]]);
	const Y = [0, 1, 0];
	const Z = cross(X, Y);
	const o = front.props.CFrame.p;
	return {
		toLocal: (w) => {
			const d = sub(w, o);
			return [dot(d, X), dot(d, Y), dot(d, Z)];
		},
		toWorld: (l) => add(o, add(add(scale(X, l[0]), scale(Y, l[1])), scale(Z, l[2]))),
		Z,
	};
}

function extents(frame, part) {
	const { CFrame: cf, size } = part.props;
	let lo = [Infinity, Infinity, Infinity];
	let hi = [-Infinity, -Infinity, -Infinity];
	for (const sx of [-0.5, 0.5])
		for (const sy of [-0.5, 0.5])
			for (const sz of [-0.5, 0.5]) {
				const l = frame.toLocal(toWorld(cf, [size[0] * sx, size[1] * sy, size[2] * sz]));
				lo = lo.map((v, k) => Math.min(v, l[k]));
				hi = hi.map((v, k) => Math.max(v, l[k]));
			}
	return { lo, hi };
}
function modelExtents(frame, model) {
	let lo = [Infinity, Infinity, Infinity];
	let hi = [-Infinity, -Infinity, -Infinity];
	for (const part of descendants(model).filter(isPart)) {
		const e = extents(frame, part);
		lo = lo.map((v, k) => Math.min(v, e.lo[k]));
		hi = hi.map((v, k) => Math.max(v, e.hi[k]));
	}
	return { lo, hi };
}
const middle = ({ lo, hi }) => lo.map((v, k) => (v + hi[k]) / 2);
function closestAxis(cf, dir) {
	let best = 0;
	let score = 0;
	for (let i = 0; i < 3; i++) {
		const s = Math.abs(dot(column(cf, i), dir));
		if (s > score) [best, score] = [i, s];
	}
	return { axis: best, score };
}

function survey(plot) {
	const arena = child(plot, 'Arene');
	const front = descendants(child(arena, 'Zones')).find((d) => nameOf(d) === 'FrontEnnemi' && isPart(d));
	assert(front, `${nameOf(plot)} : FrontEnnemi absent`);
	const frame = makeFrame(front);
	const layers = [];
	for (const d of descendants(child(plot, 'Sol'))) {
		const [a, c, b] = ['BoutArriere', 'Centre', 'BoutAvant'].map((n) => child(d, n));
		if (!(a && c && b)) continue;
		assert(a.props.shape === 2 && b.props.shape === 2, `${nameOf(d)} : bouts non cylindriques`);
		layers.push({
			arriere: a, centre: c, avant: b,
			zA: frame.toLocal(a.props.CFrame.p)[2], zB: frame.toLocal(b.props.CFrame.p)[2],
			r: Math.min(a.props.size[1], a.props.size[2]) / 2,
		});
	}
	assert(layers.length > 0, `${nameOf(plot)} : sol en stade introuvable`);
	layers.sort((x, y) => y.r - x.r);
	const ref = layers[0];
	const poses = descendants(child(arena, 'Emplacements')).filter((d) => nameOf(d) === 'PointDePose');
	const poseZ = poses.map((d) => frame.toLocal(d.props.CFrame.p)[2]);
	assert(poses.length > 0 && Math.min(...poseZ) > ref.zA + 5, `${nameOf(plot)} : dalles trop près de la coupe`);
	const info = {
		plot, arena, front, frame, layers, poses,
		zA: ref.zA, zB: ref.zB, r: ref.r, sx: frame.toLocal(ref.arriere.props.CFrame.p)[0],
		heroZ: Math.min(...poseZ),
	};
	info.k = (ref.r + ELARGISSEMENT - AXE_FIXE) / (ref.r - AXE_FIXE);
	info.map = (d) => (d <= AXE_FIXE ? d : AXE_FIXE + (d - AXE_FIXE) * info.k);
	info.r2 = info.map(ref.r);
	info.point = (l) => {
		const x = l[0] - info.sx;
		const z = l[2];
		if (z < info.zA) {
			const d = Math.hypot(x, z - info.zA);
			const s = d > 1e-3 ? info.map(d) / d : 1;
			return [info.sx + x * s, l[1], info.zA + (z - info.zA) * s - LONGUEUR];
		}
		return [info.sx + Math.sign(x) * info.map(Math.abs(x)), l[1], z];
	};
	info.a2 = info.zA - LONGUEUR;
	info.b2 = info.zB - (info.r2 - info.r);
	return info;
}

function plan(info) {
	const handled = new Set(info.layers.flatMap((l) => [l.arriere, l.centre, l.avant]));
	const units = [];
	const stretched = [];
	const { frame, zA } = info;
	const walk = (container) => {
		for (const c of container.children) {
			if (handled.has(c) || (container === info.arena && IGNORES.has(nameOf(c)))) continue;
			if (c.className === 'Folder') walk(c);
			else if (c.className === 'Model') {
				const e = modelExtents(frame, c);
				const crosses = e.lo[2] < zA && e.hi[2] > zA;
				const big = Math.max(e.hi[0] - e.lo[0], e.hi[2] - e.lo[2]) >= GRAND_MODELE;
				if (c === info.arena || (crosses && !ENTIERS.has(nameOf(c)) && big)) walk(c);
				else units.push({ inst: c, center: middle(e) });
			} else if (isPart(c)) {
				const e = extents(frame, c);
				const center = frame.toLocal(c.props.CFrame.p);
				const { axis, score } = closestAxis(c.props.CFrame, frame.Z);
				if (e.lo[2] < zA && e.hi[2] > zA && c.className === 'Part' && c.props.shape === 1 &&
					Math.abs(center[0] - info.sx) < BANDE_BORD && score > 0.9) {
					stretched.push({ inst: c, center, axis, grow: LONGUEUR / score });
				} else units.push({ inst: c, center });
				walk(c);
			}
		}
	};
	walk(info.plot);
	const copies = units.filter(({ inst, center }) =>
		center[2] >= zA && center[2] < zA + LONGUEUR && Math.abs(center[0] - info.sx) >= BANDE_BORD &&
		!isPart(inst.parent) && !ancestorNamed(inst, 'SourcesEnnemis'));
	return { units, stretched, copies };
}

// Emprise horizontale après agrandissement : { name, center (repère du front), radius, lo, hi } par pièce.
function simulate(info) {
	const { units, stretched, copies } = plan(info);
	const delta = (l) => sub(info.point(l), l);
	const out = [];
	const pushPart = (part, shift, label) => {
		const e = extents(info.frame, part);
		out.push({ name: label, part, lo: add(e.lo, shift), hi: add(e.hi, shift) });
	};
	const moved = new Map();
	for (const u of units) {
		const d = delta(u.center);
		moved.set(u.inst, d);
		const parts = u.inst.className === 'Model' ? descendants(u.inst).filter(isPart) : [u.inst];
		for (const part of parts) pushPart(part, d, nameOf(u.inst));
	}
	for (const s of stretched) {
		const c = s.center;
		const target = [info.sx + Math.sign(c[0] - info.sx) * info.map(Math.abs(c[0] - info.sx)), c[1], c[2] - LONGUEUR / 2];
		const e = extents(info.frame, s.inst);
		const shift = sub(target, c);
		// allongement de LONGUEUR le long de l'axe du plot, centré sur la nouvelle position
		out.push({ name: nameOf(s.inst), part: s.inst, lo: add(add(e.lo, shift), [0, 0, -LONGUEUR / 2]), hi: add(add(e.hi, shift), [0, 0, LONGUEUR / 2]) });
	}
	for (const u of copies) {
		const d = add(moved.get(u.inst), [0, 0, -LONGUEUR]);
		const parts = u.inst.className === 'Model' ? descendants(u.inst).filter(isPart) : [u.inst, ...descendants(u.inst).filter(isPart)];
		for (const part of parts) pushPart(part, d, `${nameOf(u.inst)} (copie)`);
	}
	return { units, stretched, copies, moved, parts: out };
}

function stadiumDistance(info, world, a, b, r) {
	const l = info.frame.toLocal(world);
	const cz = Math.min(Math.max(l[2], a), b);
	return Math.hypot(l[0] - info.sx, l[2] - cz) - r;
}
const segment = (info) => [info.frame.toWorld([info.sx, 0, info.a2]), info.frame.toWorld([info.sx, 0, info.b2])];
function neighbourGap(a, b, after = true) {
	const [a0, a1] = after ? segment(a) : [a.frame.toWorld([a.sx, 0, a.zA]), a.frame.toWorld([a.sx, 0, a.zB])];
	let best = Infinity;
	for (let i = 0; i <= 60; i++) {
		const p = add(a0, scale(sub(a1, a0), i / 60));
		best = Math.min(best, after ? stadiumDistance(b, p, b.a2, b.b2, b.r2) : stadiumDistance(b, p, b.zA, b.zB, b.r));
	}
	return best - (after ? a.r2 : a.r);
}

// --- Données ---

let lobby;
let workspace;
let snapshotError;
try {
	const roots = readPlace(read(SNAPSHOT));
	workspace = roots.find((r) => r.className === 'Workspace');
	lobby = child(workspace, 'Lobby');
} catch (err) {
	snapshotError = err;
}
const plots = lobby ? child(lobby, 'Plots').children.filter((p) => p.className === 'Model' && child(p, 'Arene')) : [];
const infos = plots.map(survey);
const sims = new Map(infos.map((info) => [info, simulate(info)]));
const pairs = infos.flatMap((a, i) => infos.slice(i + 1).map((b) => [a, b]));
const monde = child(lobby, 'Monde');
const centreDeLaPlace = child(monde, 'SpawnLobby')?.props.CFrame.p ?? [0, 0, 0];
const walls = monde ? descendants(child(monde, 'Limites')).filter(isPart) : [];
const tip = (info, after) => {
	const z = after ? info.a2 - info.r2 : info.zA - info.r;
	const w = info.frame.toWorld([info.sx, 0, z]);
	return Math.hypot(w[0] - centreDeLaPlace[0], w[2] - centreDeLaPlace[2]);
};

// --- Tests du script ---

test('réglages du script = tableau de docs/PLOTS.md', () => {
	assert(section.length > 0, 'section « Agrandissement pour les combats » absente');
	assert(LONGUEUR === 20 && section.includes(`| \`LONGUEUR\` | ${LONGUEUR} studs |`), `LONGUEUR ${LONGUEUR} ≠ doc`);
	assert(ELARGISSEMENT === 5 && section.includes(`| \`ELARGISSEMENT\` | ${ELARGISSEMENT} studs par côté |`), `ELARGISSEMENT ${ELARGISSEMENT} ≠ doc`);
	assert(section.includes(`au-delà de ${AXE_FIXE} studs de l'axe`), `AXE_FIXE ${AXE_FIXE} ≠ doc`);
	assert(section.includes(`moins de ${ECART_MIN_VOISINS} studs`), `ECART_MIN_VOISINS ${ECART_MIN_VOISINS} ≠ doc`);
});

test('script : assets uniquement, aucun script créé ni Source modifié, rien de détruit', () => {
	assert(!/\.Source\b/.test(script), 'écrit un Source');
	assert(!/Instance\.new\("(Script|LocalScript|ModuleScript)"\)/.test(script), 'crée un script');
	assert(!/:Destroy\(|:Remove\(|:ClearAllChildren\(/.test(script), 'détruit des instances');
	assert(!/loadstring|require\(/.test(script), 'charge du code');
});

test('script : une seule étape Ctrl+Z, annulée en cas d\'erreur', () => {
	const begins = script.match(/TryBeginRecording\(/g) ?? [];
	assert(begins.length === 1, `${begins.length} TryBeginRecording`);
	assert(/assert\(recording,/.test(script), 'enregistrement non vérifié');
	assert(/local ok, err = pcall\(function\(\)/.test(script), 'modifications hors pcall');
	assert(/FinishRecording\(recording, if ok then Enum\.FinishRecordingOperation\.Commit else Enum\.FinishRecordingOperation\.Cancel\)/.test(script), 'pas d\'annulation sur erreur');
	const apply = script.indexOf('for _, info in infos do apply(');
	assert(apply > script.indexOf('TryBeginRecording(') && apply < script.indexOf('FinishRecording('), 'apply hors enregistrement');
});

test('script : répétable et mode mesure seule', () => {
	assert(/if plot:GetAttribute\("AgrandiCombat"\) == VERSION then[\s\S]{0,120}continue/.test(script), 'plot déjà agrandi non ignoré');
	assert(/info\.plot:SetAttribute\("AgrandiCombat", VERSION\)/.test(script), 'attribut AgrandiCombat non posé');
	assert(/if APPLIQUER and #infos > 0 then/.test(script), 'APPLIQUER non respecté');
});

test('script : refus des voisins trop proches avant toute modification', () => {
	const check = script.indexOf('assert(minGap >= ECART_MIN_VOISINS');
	assert(check > 0, 'pas de contrôle des voisins');
	assert(check < script.indexOf('TryBeginRecording('), 'contrôle des voisins après le début des modifications');
});

// --- Tests sur le snapshot ---

test('snapshot : 8 plots du lobby mesurables', () => {
	if (snapshotError) throw snapshotError;
	assert(infos.length === 8, `${infos.length} plots`);
	for (const info of infos) {
		assert(info.layers.length >= 3, `${nameOf(info.plot)} : ${info.layers.length} couches de sol`);
		assert(info.poses.length === 9, `${nameOf(info.plot)} : ${info.poses.length} dalles`);
		assert(!child(info.plot, 'AgrandiCombat'), 'déjà agrandi');
	}
});

test('mesures avant = doc (122 × 178, dalles à 23 studs du front, voisins à 22,3)', () => {
	for (const info of infos) {
		near(info.r * 2, 122, 0.05, `${nameOf(info.plot)} largeur`);
		near(info.zB - info.zA + info.r * 2, 178, 0.1, `${nameOf(info.plot)} longueur`);
		near(info.heroZ, 23, 1, `${nameOf(info.plot)} dalles → front`);
		near(info.sx, 0, 0.1, `${nameOf(info.plot)} front hors de l'axe`);
	}
	const gap = Math.min(...pairs.map(([a, b]) => neighbourGap(a, b, false)));
	near(gap, 22.3, 0.1, 'écart minimal entre sols voisins');
	near(Math.max(...infos.map((i) => tip(i, false))), 328, 1, 'pointe extérieure');
	assert(section.includes('| Sol (`Sol.SoclePierre`) | 122 × 178 studs | 132 × 203 studs |'), 'ligne Sol de la doc');
});

test('mesures après = doc (132 × 203, dalles à 43 studs du front, voisins à 15,8)', () => {
	for (const info of infos) {
		near(info.r2 * 2, 132, 0.05, `${nameOf(info.plot)} largeur`);
		near(info.b2 - info.a2 + info.r2 * 2, 203, 0.1, `${nameOf(info.plot)} longueur`);
		const front = info.point(info.frame.toLocal(info.front.props.CFrame.p));
		near(info.heroZ - front[2], 43, 1, `${nameOf(info.plot)} dalles → front`);
	}
	const gap = Math.min(...pairs.map(([a, b]) => neighbourGap(a, b)));
	assert(gap >= ECART_MIN_VOISINS, `sols voisins à ${gap.toFixed(1)} studs : le script refuserait`);
	near(gap, 15.8, 0.1, 'écart minimal entre sols voisins');
	near(Math.max(...infos.map((i) => tip(i, true))), 353, 1, 'pointe extérieure');
	assert(section.includes('| Première rangée de dalles → front ennemi | 23 studs | 43 studs |'), 'ligne dalles de la doc');
	assert(section.includes('| Écart minimal entre sols voisins | 22,3 studs | 15,8 studs |'), 'ligne voisins de la doc');
	assert(section.includes('| Pointe extérieure (distance au centre de la place) | 328 studs | 353 studs |'), 'ligne pointe de la doc');
});

test('dalles, royaume, portail, pancartes et apparition ne bougent pas', () => {
	for (const info of infos) {
		for (const pose of info.poses) {
			const l = info.frame.toLocal(pose.props.CFrame.p);
			const d = sub(info.point(l), l);
			assert(Math.hypot(...d) < 1e-6, `${nameOf(info.plot)} : une dalle bouge de ${Math.hypot(...d).toFixed(2)}`);
		}
		const { moved } = sims.get(info);
		// PanneauStage (pancarte du stage) a été ajouté dans Studio après le snapshot v4 : contrôlé s'il existe.
		for (const name of ['Royaume', 'PortailInvocation', 'PanneauProprietaire', 'PanneauStage', 'PointApparition']) {
			const inst = descendants(info.plot).find((d) => nameOf(d) === name);
			if (name === 'PanneauStage' && !inst) continue;
			assert(inst, `${nameOf(info.plot)} : ${name} absent`);
			const d = moved.get(inst);
			assert(d, `${nameOf(info.plot)} : ${name} découpé au lieu d'être gardé entier`);
			assert(Math.hypot(...d) < 1e-6, `${nameOf(info.plot)} : ${name} bouge de ${Math.hypot(...d).toFixed(2)} studs`);
		}
	}
});

test('front ennemi reculé de 20 studs, formation ennemie sur le sol agrandi', () => {
	// FRONT_SLOTS et BOSS_SLOT de CombatIntroController, repère du FrontEnnemi
	const slots = [[-9, 0, 4], [-3, 0, 4.5], [3, 0, 4.5], [9, 0, 4], [-6, 0, -1], [6, 0, -1], [0, 0, -5]];
	for (const info of infos) {
		const l = info.frame.toLocal(info.front.props.CFrame.p);
		const d = sub(info.point(l), l);
		near(d[2], -LONGUEUR, 1e-6, `${nameOf(info.plot)} recul du front`);
		near(Math.hypot(d[0], d[1]), 0, 1e-6, `${nameOf(info.plot)} front décalé de côté`);
		for (const s of slots) {
			const w = info.frame.toWorld(add(info.point(l), s));
			const inside = -stadiumDistance(info, w, info.a2, info.b2, info.r2);
			assert(inside > 15, `${nameOf(info.plot)} : ennemi à ${inside.toFixed(1)} studs du bord`);
		}
	}
});

test('portées de combat : les héros à distance doivent avancer, tout le monde reste sur le sol', () => {
	const combat = read('src/server/Config/CombatConfig.lua').toString('utf8');
	const ranges = [...combat.matchAll(/AttackRange = (\d+)/g)].map((m) => Number(m[1]));
	assert(ranges.length >= 9, 'portées introuvables');
	for (const info of infos) {
		const gap = info.heroZ + LONGUEUR; // première rangée de dalles → front reculé
		assert(gap > Math.max(...ranges), `${nameOf(info.plot)} : un héros tire depuis sa dalle (${gap} studs)`);
		// le point de rencontre (mi-chemin) reste à plus de 40 studs du bord en largeur
		const meet = info.frame.toWorld([info.sx, 0, (info.heroZ - LONGUEUR) / 2]);
		assert(-stadiumDistance(info, meet, info.a2, info.b2, info.r2) > 40, `${nameOf(info.plot)} : mêlée trop près du bord`);
	}
});

test('camp ennemi (Arene.Zones, côté ennemis) reculé d\'un bloc avec le front', () => {
	for (const info of infos) {
		const zones = new Set(descendants(child(info.arena, 'Zones')));
		for (const u of sims.get(info).units) {
			if (!zones.has(u.inst) || u.center[2] >= info.zA) continue; // porche et piliers côté héros : immobiles
			const d = sims.get(info).moved.get(u.inst);
			const inst = u.inst;
			// recul de LONGUEUR, plus l'écartement du bout (au plus ELARGISSEMENT, nul à moins de AXE_FIXE)
			const spread = Math.hypot(d[0], d[1], d[2] + LONGUEUR);
			assert(spread <= ELARGISSEMENT + 1e-6, `${nameOf(info.plot)}/${nameOf(inst)} déplacé de ${spread.toFixed(1)} studs en plus du recul`);
			const dist = Math.hypot(u.center[0] - info.sx, u.center[2] - info.zA);
			if (dist <= AXE_FIXE) assert(spread < 1e-6, `${nameOf(info.plot)}/${nameOf(inst)} près du front mais déformé`);
		}
	}
});

// Couloir ajouté : largeur de la formation ennemie (x ±9) + 1 stud, de la ligne ennemie arrière
// (front - 1) aux dalles. Le CampGobelin (falaise, rampe, palissade) flanque le front à x ≥ 6,5 dès
// front - 4,7, comme avant l'agrandissement, et recule avec lui (test précédent).
test('couloir de combat (dalles → ennemis) sans obstacle', () => {
	const problems = [];
	let camp = Infinity;
	for (const info of infos) {
		const floorTop = Math.max(...info.layers.map((l) => {
			const c = l.centre.props;
			return info.frame.toLocal(c.CFrame.p)[1] + Math.min(...c.size) / 2;
		}));
		for (const p of sims.get(info).parts) {
			if (p.part.props.CanCollide === false || ancestorNamed(p.part, 'Emplacements')) continue;
			const blocks = p.hi[1] > floorTop + 2 && p.lo[1] < floorTop + 5;
			const inLength = p.hi[2] > -LONGUEUR - 1 && p.lo[2] < info.heroZ - 2;
			if (!blocks || !inLength) continue;
			const side = Math.max(p.lo[0] - info.sx, info.sx - p.hi[0]);
			camp = Math.min(camp, side);
			if (side < 10) problems.push(`${nameOf(info.plot)}/${p.name}`);
		}
	}
	assert(problems.length === 0, `obstacles : ${[...new Set(problems)].join(', ')}`);
	console.log(`  premier obstacle à ${camp.toFixed(1)} studs de l'axe (ennemis jusqu'à 9)`);
});

test('aucune pièce d\'un plot sur le sol agrandi d\'un voisin', () => {
	const problems = [];
	let clearance = Infinity;
	for (const [a, b] of pairs.flatMap(([x, y]) => [[x, y], [y, x]])) {
		if (neighbourGap(a, b) > 60) continue;
		for (const p of sims.get(a).parts) {
			const c = a.frame.toWorld(middle(p));
			const radius = Math.hypot(p.hi[0] - p.lo[0], p.hi[2] - p.lo[2]) / 2;
			const d = stadiumDistance(b, c, b.a2, b.b2, b.r2) - radius;
			clearance = Math.min(clearance, d);
			if (d < 0) problems.push(`${nameOf(a.plot)}/${p.name} → ${nameOf(b.plot)} (${d.toFixed(1)})`);
		}
	}
	assert(problems.length === 0, `chevauchements : ${problems.slice(0, 8).join(', ')}${problems.length > 8 ? ` … (${problems.length})` : ''}`);
	console.log(`  marge minimale entre une pièce et le sol voisin : ${clearance.toFixed(1)} studs`);
});

// Même mesure que le script : distance au sol du centre du mur, moins sa demi-longueur (prudent).
test('murs invisibles hors de l\'emprise, ≈ 41 puis ≈ 28 studs du sol le plus proche', () => {
	assert(walls.length === 90, `${walls.length} murs`);
	let before = Infinity;
	let after = Infinity;
	for (const wall of walls) {
		const half = Math.max(wall.props.size[0], wall.props.size[2]) / 2;
		for (const info of infos) {
			before = Math.min(before, stadiumDistance(info, wall.props.CFrame.p, info.zA, info.zB, info.r) - half);
			after = Math.min(after, stadiumDistance(info, wall.props.CFrame.p, info.a2, info.b2, info.r2) - half);
		}
	}
	console.log(`  sol → mur le plus proche : ${before.toFixed(1)} → ${after.toFixed(1)} studs`);
	near(before, 41, 1, 'sol → mur avant');
	near(after, 28, 1, 'sol → mur après');
	assert(section.includes('| Mur invisible `LimiteMap` le plus proche de la pointe | ≈ 41 studs | ≈ 28 studs |'), 'ligne murs de la doc');
});

test('forêt de bordure : arbres de la nouvelle emprise recensés pour archivage', () => {
	const foret = child(child(lobby, 'Monde'), 'ForetBordure');
	const trees = descendants(foret).filter((t) => (t.className === 'Model' || (isPart(t) && t.parent.className === 'Folder')) && t.parent.className !== 'Model');
	assert(trees.length > 0, 'forêt vide');
	const inside = (world, old) => infos.some((info) =>
		stadiumDistance(info, world, old ? info.zA : info.a2, old ? info.zB : info.b2, old ? info.r : info.r2) < MARGE_FORET);
	const moved = trees.filter((t) => {
		const pos = t.className === 'Model' ? t.parent && infos[0].frame.toWorld(middle(modelExtents(infos[0].frame, t))) : t.props.CFrame.p;
		return inside(pos, false) && !inside(pos, true);
	});
	console.log(`  ${trees.length} arbres, ${moved.length} archivés par le script`);
	assert(moved.length < trees.length / 4, `${moved.length} arbres archivés : la forêt serait trouée`);
});

console.log(`\n${passed} réussis, ${failed} échoués`);
if (failed > 0) process.exitCode = 1;
