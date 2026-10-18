// Contrôle hors Studio du catalogue des items (docs/ITEMS.md), sans Luau : `node tests/items-vitrine.test.mjs`.
// Lecture seule. Compare src/shared/Config/ItemConfig.lua :
//   - à la répartition du tableau de docs/ITEMS.md § 2 (lue dans le document lui-même) ;
//   - aux paliers de src/shared/Config/RarityConfig.lua ;
//   - au catalogue de production automation/catalogues/items.json (une tâche par icône restante) ;
//   - CONTRÔLE HISTORIQUE : aux 100 cartes Item_NNN de la vitrine Workspace.Bestiaire.Inventaire du
//     snapshot versionné studio/sandbox/partner_sandbox_v4.rbxl (format binaire lu ici : chunks LZ4,
//     INST, PROP, PRNT), d'où le catalogue a été relevé. Ne prouve pas l'état de la DEV Studio
//     actuelle : celle-ci se contrôle avec tools/studio-items-vitrine.luau.
// Complète src/server/Tests/ItemConfig.spec.lua (tools/test-items.ps1), qui demande luau.exe.
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const read = (path) => readFileSync(join(repoRoot, path));
const SNAPSHOT = 'studio/sandbox/partner_sandbox_v4.rbxl';
const SLOTS_PATH = ['Workspace', 'Bestiaire', 'Inventaire', 'Equipement', 'Panneau', 'Affichage', 'Fond', 'Emplacements'];

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

// --- Sources Luau (lues comme texte) ---

const itemSource = read('src/shared/Config/ItemConfig.lua').toString('utf8');
const items = [...itemSource.matchAll(/^item\("([^"]*)", "([^"]*)", "([^"]*)", "([^"]*)"(?:, "([^"]*)")?\)\s*$/gm)].map(
	(m, i) => ({ id: m[1], name: m[2], rarity: m[3], slotType: m[4], icon: m[5], index: i + 1 }),
);
const itemCalls = itemSource.match(/^item\(/gm)?.length ?? 0;
const slotTypes = [...itemSource.matchAll(/\{ Id = "(\w+)", Name = "([^"]+)" \}/g)].map((m) => ({ id: m[1], name: m[2] }));

const raritySource = read('src/shared/Config/RarityConfig.lua').toString('utf8');
const tiers = [...raritySource.matchAll(/\{ Id = "(\w+)", Name = "([^"]+)", Weight = \d+ \}/g)].map((m) => ({ id: m[1], name: m[2] }));
const rarityRank = new Map(tiers.map((t, i) => [t.id, i + 1]));
const rarityName = new Map(tiers.map((t) => [t.id, t.name]));

// --- docs/ITEMS.md § 2 ---

const itemsDoc = read('docs/ITEMS.md').toString('utf8');
const docTiers = [...itemsDoc.matchAll(/^\| ([^|]+?) \| (\d{3}) – (\d{3}) \| (\d+) \|$/gm)].map((m) => ({
	name: m[1],
	first: Number(m[2]),
	last: Number(m[3]),
	count: Number(m[4]),
}));
const docSlots = new Map([...itemsDoc.matchAll(/`(\w+)` (\d+)/g)].map((m) => [m[1], Number(m[2])]));

// --- Snapshot Studio (.rbxl binaire) ---

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

function interleavedInts(buf, offset, count) {
	const values = [];
	let previous = 0;
	for (let i = 0; i < count; i++) {
		const raw =
			((buf[offset + i] << 24) | (buf[offset + count + i] << 16) | (buf[offset + 2 * count + i] << 8) | buf[offset + 3 * count + i]) >>> 0;
		previous += (raw >>> 1) ^ -(raw & 1);
		values.push(previous);
	}
	return values;
}

// Attributs Roblox sérialisés : seuls les types présents sur les cartes sont lus (string, bool, double).
function attributes(buf) {
	const result = {};
	if (buf.length < 4) return result;
	let p = 0;
	const str = () => {
		const len = buf.readUInt32LE(p);
		p += 4;
		const value = buf.toString('utf8', p, p + len);
		p += len;
		return value;
	};
	const count = buf.readUInt32LE(p);
	p += 4;
	for (let i = 0; i < count; i++) {
		const key = str();
		const type = buf[p++];
		if (type === 0x02) result[key] = str();
		else if (type === 0x03) result[key] = buf[p++] !== 0;
		else if (type === 0x06) {
			result[key] = buf.readDoubleLE(p);
			p += 8;
		} else if (type === 0x05) {
			result[key] = buf.readFloatLE(p);
			p += 4;
		} else {
			result[key] = { unsupportedType: type };
			break;
		}
	}
	return result;
}

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
			const propName = str().toString('utf8');
			const type = chunk[c++];
			if (type !== 0x01 || !['Name', 'Text', 'Image', 'AttributesSerialize'].includes(propName)) continue;
			for (const ref of classes.get(classId).refs) instances.get(ref).props[propName] = str();
		} else if (name === 'PRNT') {
			const count = chunk.readUInt32LE(1);
			const children = interleavedInts(chunk, 5, count);
			const parents = interleavedInts(chunk, 5 + 4 * count, count);
			children.forEach((child, i) => {
				const instance = instances.get(child);
				instance.parent = parents[i];
				instances.get(parents[i])?.children.push(instance);
			});
		}
	}
	const nameOf = (instance) => instance.props.Name?.toString('utf8');
	const child = (instance, name) => instance?.children.find((c) => nameOf(c) === name);
	const roots = [...instances.values()].filter((i) => i.parent === -1);
	return { roots, nameOf, child };
}

let slots;
let vitrineError;
try {
	const place = readPlace(read(SNAPSHOT));
	let node = place.roots.find((r) => r.className === SLOTS_PATH[0]);
	for (const name of SLOTS_PATH.slice(1)) node = place.child(node, name);
	assert(node, `${SLOTS_PATH.join('.')} introuvable`);
	slots = new Map(
		node.children.map((card) => [
			place.nameOf(card),
			{
				attrs: attributes(card.props.AttributesSerialize ?? Buffer.alloc(0)),
				nom: place.child(card, 'Nom')?.props.Text?.toString('utf8'),
				icone: place.child(place.child(card, 'Illustration'), 'Icone'),
			},
		]),
	);
} catch (err) {
	vitrineError = err;
}

// --- Tests ---

test('ItemConfig: every item(...) line parses, 100 items item_001..item_100', () => {
	assert(itemCalls === items.length, `${itemCalls} appels item(), ${items.length} lus`);
	assert(items.length === 100, `${items.length} items`);
	for (const info of items) assert(info.id === `item_${String(info.index).padStart(3, '0')}`, info.id);
});

test('RarityConfig: 10 tiers, same order as ITEMS.md § 2', () => {
	assert(tiers.length === 10, `${tiers.length} paliers`);
	assert(docTiers.length === 10, `${docTiers.length} lignes dans le tableau du § 2`);
	docTiers.forEach((row, i) => assert(row.name === tiers[i].name, `${row.name} ≠ ${tiers[i].name}`));
});

test('ITEMS.md § 2: tiers are contiguous from 001 to 100 and counts add up', () => {
	let next = 1;
	for (const row of docTiers) {
		assert(row.first === next, `${row.name} commence à ${row.first}, attendu ${next}`);
		assert(row.last - row.first + 1 === row.count, `${row.name} : ${row.count} ≠ plage`);
		next = row.last + 1;
	}
	assert(next === 101, `dernier item ${next - 1}`);
	const slotTotal = [...docSlots.values()].reduce((a, b) => a + b, 0);
	assert(slotTotal === 100, `emplacements : ${slotTotal}`);
});

test('ItemConfig: each item sits in its ITEMS.md § 2 rarity range', () => {
	for (const info of items) {
		assert(rarityRank.has(info.rarity), `${info.id} : rareté inconnue ${info.rarity}`);
		const row = docTiers.find((r) => info.index >= r.first && info.index <= r.last);
		assert(row && row.name === rarityName.get(info.rarity), `${info.id} : ${info.rarity}, attendu ${row?.name}`);
	}
});

test('ItemConfig: slot types match ITEMS.md § 2 (ids and counts)', () => {
	assert(slotTypes.length === 7, `${slotTypes.length} types`);
	assert(slotTypes.every((s) => docSlots.has(s.id)), 'type absent du § 2');
	const counts = new Map();
	for (const info of items) {
		assert(slotTypes.some((s) => s.id === info.slotType), `${info.id} : emplacement inconnu ${info.slotType}`);
		counts.set(info.slotType, (counts.get(info.slotType) ?? 0) + 1);
	}
	for (const [slotType, expected] of docSlots) assert(counts.get(slotType) === expected, `${slotType} : ${counts.get(slotType)} au lieu de ${expected}`);
});

test('ItemConfig: names unique and trimmed, icons nil or rbxassetid', () => {
	const seen = new Set();
	for (const info of items) {
		assert(info.name !== '' && info.name === info.name.trim(), `${info.id} : nom « ${info.name} »`);
		assert(!seen.has(info.name), `${info.id} : nom en double`);
		seen.add(info.name);
		assert(info.icon === undefined || /^rbxassetid:\/\/\d+$/.test(info.icon), `${info.id} : icône ${info.icon}`);
	}
});

test(`Snapshot historique (${SNAPSHOT}): exactly Item_001..Item_100 under Emplacements`, () => {
	if (vitrineError) throw vitrineError;
	const cards = [...slots.keys()].filter((name) => /^Item_\d+$/.test(name));
	assert(cards.length === 100, `${cards.length} cartes`);
	for (const info of items) assert(slots.has(`Item_${String(info.index).padStart(3, '0')}`), `Item_${info.index} absent`);
});

test(`Snapshot historique (${SNAPSHOT}): ItemId, Index, Rarete, SlotType and Nom match ItemConfig`, () => {
	if (vitrineError) throw vitrineError;
	const problems = [];
	for (const info of items) {
		const slotName = `Item_${String(info.index).padStart(3, '0')}`;
		const card = slots.get(slotName);
		if (!card) continue;
		const expected = { ItemId: info.id, Index: info.index, Rarete: rarityName.get(info.rarity), SlotType: info.slotType };
		for (const [key, value] of Object.entries(expected)) {
			if (card.attrs[key] !== value) problems.push(`${slotName} ${key} = ${JSON.stringify(card.attrs[key])}, attendu ${value}`);
		}
		if (card.nom !== info.name) problems.push(`${slotName} Nom = ${card.nom}, attendu ${info.name}`);
	}
	assert(problems.length === 0, `${problems.length} écart(s) : ${problems.slice(0, 5).join(' ; ')}`);
});

// Le snapshot est antérieur aux icônes livrées (référence des assets : la vitrine de la DEV Studio,
// tools/studio-items-vitrine.luau). Une carte sans icône dans le snapshot n'interdit donc pas une icône
// livrée depuis dans ItemConfig ; une carte qui en a une doit concorder.
test(`Snapshot historique (${SNAPSHOT}): every card has Illustration.Icone; AssetId agrees with Icone.Image (and ItemConfig.Icon when set)`, () => {
	if (vitrineError) throw vitrineError;
	const problems = [];
	for (const info of items) {
		const slotName = `Item_${String(info.index).padStart(3, '0')}`;
		const card = slots.get(slotName);
		if (!card) continue;
		if (!card.icone) {
			problems.push(`${slotName} Illustration.Icone absente`);
			continue;
		}
		const image = card.icone.props.Image?.toString('utf8') ?? '';
		const assetId = card.attrs.AssetId ?? '';
		if (image !== assetId) problems.push(`${slotName} Icone.Image = ${image}, AssetId = ${assetId}`);
		if (assetId !== '' && (info.icon ?? '') !== assetId) problems.push(`${slotName} AssetId = ${assetId}, ItemConfig.Icon = ${info.icon}`);
	}
	assert(problems.length === 0, `${problems.length} écart(s) : ${problems.slice(0, 5).join(' ; ')}`);
});

// --- Catalogue de production automation/catalogues/items.json (icônes restant à produire) ---

const catalogue = JSON.parse(read('automation/catalogues/items.json').toString('utf8'));
// Icônes fournies par le partenaire (PR #74) : elles n'ont pas de tâche.
const partnerDelivered = (index) => (index >= 35 && index <= 44) || index >= 53;

test('items.json: one task per item outside the partner delivery (001-034, 045-052), same id, name, slot type and order', () => {
	const expected = items.filter((info) => !partnerDelivered(info.index));
	const queue = catalogue.queue;
	assert(queue.length === 42 && expected.length === 42, `${queue.length} tâches, ${expected.length} attendues`);
	queue.forEach((task, i) => {
		const info = expected[i];
		assert(task.id === info.id && task.name === info.name && task.slot_type === info.slotType, `${task.id} ≠ ${info.id}`);
		assert(info.icon === undefined, `${task.id} : icône déjà livrée dans ItemConfig, tâche à retirer`);
	});
});

test('items.json: tasks follow TASK_FORMAT and target their Items #NNN [Rareté] slot', () => {
	assert(catalogue.schema_version === 1, `schema_version ${catalogue.schema_version}`);
	assert(new Set(catalogue.queue.map((task) => task.id)).size === catalogue.queue.length, 'identifiants en double');
	const byId = new Map(items.map((info) => [info.id, info]));
	for (const task of catalogue.queue) {
		assert(task.type === 'item' && task.brief_source === 'docs/ITEMS.md', `${task.id}: type ou brief_source`);
		assert(typeof task.icon_hook === 'string' && task.icon_hook.length >= 30, `${task.id}: icon_hook`);
		const expected = `Items #${task.id.slice(-3)} [${rarityName.get(byId.get(task.id).rarity)}]`;
		assert(task.target_studio_slot === expected, `${task.id}: ${task.target_studio_slot}`);
		assert(task.status === 'todo' && task.iteration === 0 && task.max_iterations > 0, `${task.id}: état`);
		assert(task.worker === 'windows' && Number.isInteger(task.priority), `${task.id}: worker ou priority`);
		assert(Array.isArray(task.screenshots) && task.screenshots.length === 0, `${task.id}: screenshots`);
		assert(task.latest_review === null && typeof task.notes === 'string', `${task.id}: latest_review ou notes`);
		assert(!('rarity' in task), `${task.id}: champ de rareté (elle vient de ItemConfig)`);
	}
});

test('items.json: exactly the TASK_FORMAT fields of an item task, one distinct icon_hook per task', () => {
	const fields = [
		'id', 'name', 'type', 'slot_type', 'icon_hook', 'brief_source', 'target_studio_slot', 'worker', 'status',
		'iteration', 'max_iterations', 'priority', 'reference_priority', 'screenshots', 'latest_review', 'notes',
	].sort().join(',');
	const hooks = new Map();
	for (const task of catalogue.queue) {
		assert(Object.keys(task).sort().join(',') === fields, `${task.id}: champs ${Object.keys(task).join(',')}`);
		const hook = task.icon_hook.trim().toLowerCase();
		assert(!hooks.has(hook), `${task.id}: même icon_hook que ${hooks.get(hook)}`);
		hooks.set(hook, task.id);
	}
});

test('items.json: references are the four main validated creatures (CLAUDE.md, ART_DIRECTION § 1)', () => {
	const art = read('docs/ART_DIRECTION.md').toString('utf8');
	const main = ['KingTreant', 'Treant_Masque', 'KingSlime', 'RoiOrc'];
	for (const id of main) assert(art.includes(`\`${id}\``), `${id} absent de ART_DIRECTION.md`);
	for (const task of catalogue.queue) {
		assert(JSON.stringify(task.reference_priority) === JSON.stringify(main), `${task.id}: reference_priority`);
	}
});

test('items.json: icon hooks stay in the DA (no rarity, emoji, futuristic or chrome look)', () => {
	const banned = /rar(e|eté)|légendaire|épique|commun[e]?\b|emoji|futuris|néon|chrom|holograph|photoréal/i;
	const emoji = /\p{Extended_Pictographic}/u;
	for (const task of catalogue.queue) {
		const hit = task.icon_hook.match(banned);
		assert(!hit, `${task.id}: « ${hit?.[0]} » dans icon_hook`);
		assert(!emoji.test(task.icon_hook), `${task.id}: emoji`);
	}
});

test('docs: ITEMS.md, TASK_FORMAT and README point to items.json', () => {
	for (const path of ['docs/ITEMS.md', 'automation/TASK_FORMAT.md', 'README.md']) {
		assert(read(path).toString('utf8').includes('automation/catalogues/items.json'), path);
	}
});

console.log(`Items: ${passed} passed, ${failed} failed`);
process.exitCode = failed > 0 ? 1 : 0;
