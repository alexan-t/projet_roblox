// Contrôle hors Studio du catalogue des ressources (docs/RESOURCES.md), sans Luau :
// `node tests/resources.test.mjs`. Lecture seule. Compare src/shared/Config/ResourceConfig.lua :
//   - à la répartition du tableau de docs/RESOURCES.md § 2 (lue dans le document lui-même) ;
//   - au catalogue de production automation/catalogues/resources.json (une tâche par ressource).
// Complète src/server/Tests/ResourceConfig.spec.lua (tools/test-resources.ps1), qui demande luau.exe.
// La vitrine Studio se contrôle avec tools/studio-resources-vitrine.luau.
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const read = (path) => readFileSync(join(repoRoot, path), 'utf8').replace(/\r\n/g, '\n');

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

const source = read('src/shared/Config/ResourceConfig.lua');
const resources = [...source.matchAll(/^resource\("([^"]*)", "([^"]*)", "([^"]*)"(?:, "([^"]*)")?\)\s*$/gm)].map(
	(m, i) => ({ id: m[1], name: m[2], family: m[3], icon: m[4], index: i + 1 }),
);
const resourceCalls = source.match(/^resource\(/gm)?.length ?? 0;
const families = [...source.matchAll(/\{ Id = "(\w+)", Name = "([^"]+)" \}/g)].map((m) => ({ id: m[1], name: m[2] }));

const doc = read('docs/RESOURCES.md');
const docFamilies = [...doc.matchAll(/^\| ([^|]+?) \| `(\w+)` \| (\d{3}) – (\d{3}) \| (\d+) \|$/gm)].map((m) => ({
	name: m[1],
	id: m[2],
	first: Number(m[3]),
	last: Number(m[4]),
	count: Number(m[5]),
}));

const catalogue = JSON.parse(read('automation/catalogues/resources.json'));

test('ResourceConfig: every resource(...) line parses, 60 resources resource_001..resource_060', () => {
	assert(resourceCalls === resources.length, `${resourceCalls} appels resource(), ${resources.length} lus`);
	assert(resources.length === 60, `${resources.length} ressources`);
	for (const info of resources) assert(info.id === `resource_${String(info.index).padStart(3, '0')}`, info.id);
});

test('ResourceConfig: names unique, icons nil or rbxassetid, no rarity', () => {
	const seen = new Set();
	for (const info of resources) {
		assert(info.name !== '' && !seen.has(info.name), `${info.id}: nom vide ou en double`);
		seen.add(info.name);
		assert(info.icon === undefined || /^rbxassetid:\/\/\d+$/.test(info.icon), `${info.id}: icône ${info.icon}`);
	}
	assert(!/Rarity|Rarete/.test(source.replace(/^--.*$/gm, '')), 'champ de rareté dans ResourceConfig');
});

test('RESOURCES.md § 2: same families, names and order as ResourceConfig; contiguous tiers of 001..060', () => {
	assert(docFamilies.length === families.length, `${docFamilies.length} lignes au § 2, ${families.length} familles`);
	let next = 1;
	docFamilies.forEach((row, i) => {
		assert(row.id === families[i].id && row.name === families[i].name, `${row.name} ≠ ${families[i].name}`);
		assert(row.first === next, `${row.name} commence à ${row.first}, attendu ${next}`);
		assert(row.last - row.first + 1 === row.count, `${row.name} : ${row.count} ≠ plage`);
		next = row.last + 1;
	});
	assert(next === 61, `le tableau s'arrête à ${next - 1}`);
});

test('ResourceConfig: each resource sits in the family range of RESOURCES.md § 2', () => {
	for (const info of resources) {
		const row = docFamilies.find((r) => info.index >= r.first && info.index <= r.last);
		assert(row && row.id === info.family, `${info.id}: famille ${info.family}, attendu ${row?.id}`);
	}
});

test('resources.json: one task per resource, same id, name, family and order', () => {
	const queue = catalogue.queue;
	assert(queue.length === resources.length, `${queue.length} tâches`);
	queue.forEach((task, i) => {
		const info = resources[i];
		assert(task.id === info.id && task.name === info.name && task.family === info.family, `${task.id} ≠ ${info.id}`);
	});
});

test('resources.json: tasks follow TASK_FORMAT and target their Ressources #NNN slot', () => {
	const familyName = new Map(families.map((f) => [f.id, f.name]));
	for (const task of catalogue.queue) {
		assert(task.type === 'resource', `${task.id}: type ${task.type}`);
		assert(typeof task.icon_hook === 'string' && task.icon_hook.length >= 30, `${task.id}: icon_hook`);
		assert(task.brief_source === 'docs/RESOURCES.md', `${task.id}: brief_source`);
		const expected = `Ressources #${task.id.slice(-3)} [${familyName.get(task.family)}]`;
		assert(task.target_studio_slot === expected, `${task.id}: ${task.target_studio_slot}`);
		assert(task.status === 'todo' && task.iteration === 0 && task.max_iterations > 0, `${task.id}: état`);
		assert(!('rarity' in task), `${task.id}: rareté inventée`);
	}
});

test('resources.json: schema_version 1, unique ids, every TASK_FORMAT field present', () => {
	assert(catalogue.schema_version === 1, `schema_version ${catalogue.schema_version}`);
	assert(new Set(catalogue.queue.map((task) => task.id)).size === catalogue.queue.length, 'identifiants en double');
	for (const task of catalogue.queue) {
		assert(task.worker === 'windows' && Number.isInteger(task.priority), `${task.id}: worker ou priority`);
		assert(Array.isArray(task.screenshots) && task.screenshots.length === 0, `${task.id}: screenshots`);
		assert(task.latest_review === null && typeof task.notes === 'string', `${task.id}: latest_review ou notes`);
	}
});

test('resources.json: references are the four main validated creatures (CLAUDE.md, ART_DIRECTION § 1)', () => {
	const art = read('docs/ART_DIRECTION.md');
	const main = ['KingTreant', 'Treant_Masque', 'KingSlime', 'RoiOrc'];
	for (const id of main) assert(art.includes(`\`${id}\``), `${id} absent de ART_DIRECTION.md`);
	for (const task of catalogue.queue) {
		assert(JSON.stringify(task.reference_priority) === JSON.stringify(main), `${task.id}: reference_priority`);
	}
});

test('resources.json: icon hooks stay in the DA (no rarity, emoji, futuristic or chrome look)', () => {
	const banned = /rar(e|eté)|légendaire|épique|commun[e]?\b|emoji|futuris|néon|chrom|holograph|photoréal/i;
	const emoji = /\p{Extended_Pictographic}/u;
	for (const task of catalogue.queue) {
		const hit = task.icon_hook.match(banned);
		assert(!hit, `${task.id}: « ${hit?.[0]} » dans icon_hook`);
		assert(!emoji.test(task.icon_hook) && !emoji.test(task.name), `${task.id}: emoji`);
	}
});

test('RESOURCES.md: boss trophies and slot example match ResourceConfig', () => {
	const byId = new Map(resources.map((info) => [info.id, info]));
	for (const [id, name] of [...doc.matchAll(/`(resource_\d{3})` \(([^,)«]+)/g)].map((m) => [m[1], m[2].replace(/\s+/g, ' ')])) {
		assert(byId.get(id)?.name === name, `${id}: « ${name} » dans la doc, « ${byId.get(id)?.name} » au catalogue`);
	}
	const example = doc.match(/`(resource_\d{3})` \(« Ressources #(\d{3}) \[([^\]]+)\] »\)/);
	assert(example, 'exemple du § 3 introuvable');
	const familyName = new Map(families.map((f) => [f.id, f.name]));
	assert(example[1].slice(-3) === example[2], `exemple : ${example[1]} → #${example[2]}`);
	assert(familyName.get(byId.get(example[1]).family) === example[3], `exemple : famille ${example[3]}`);
});

test('ResourceConfig.spec.lua: FAMILIES list matches ResourceConfig.Families', () => {
	const spec = read('src/server/Tests/ResourceConfig.spec.lua');
	const list = spec.match(/local FAMILIES = \{([^}]*)\}/);
	assert(list, 'FAMILIES introuvable dans le spec');
	const ids = [...list[1].matchAll(/"(\w+)"/g)].map((m) => m[1]);
	assert(ids.join() === families.map((f) => f.id).join(), `spec : ${ids.join()}`);
});

test('studio-resources-vitrine.luau: slot path of RESOURCES.md § 3, emits lines this test can parse', () => {
	const vitrine = read('tools/studio-resources-vitrine.luau');
	const path = doc.match(/→ Workspace\.Bestiaire\.Inventaire\.Ressources\.(Panneau\.Affichage\.Fond\.Emplacements)\.Ressource_NNN/);
	assert(path && vitrine.includes(`panel.${path[1]}`), 'chemin des emplacements différent de la doc');
	assert(/require\(.*\.Shared\.Config\.ResourceConfig\)/.test(vitrine), 'ResourceConfig non lu par le script');
	assert(vitrine.includes('string.format("resource(%q, %q, %q, %q)"'), 'format des lignes resource(...) changé');
	assert(/ChangeHistoryService/.test(vitrine), 'pas d\'étape ChangeHistoryService');
	// Ligne telle que %q la produit pour une icône livrée : elle doit passer le motif du premier test.
	const line = 'resource("resource_036", "Pépite d\'Or", "mine", "rbxassetid://123456")';
	const m = line.match(/^resource\("([^"]*)", "([^"]*)", "([^"]*)"(?:, "([^"]*)")?\)\s*$/);
	assert(m && /^rbxassetid:\/\/\d+$/.test(m[4]), 'ligne générée non reconnue');
});

test('docs: README, UI_DESIGN_SYSTEM and TASK_FORMAT point to RESOURCES.md', () => {
	assert(read('README.md').includes('docs/RESOURCES.md'), 'README.md');
	assert(read('docs/UI_DESIGN_SYSTEM.md').includes('docs/RESOURCES.md'), 'UI_DESIGN_SYSTEM.md');
	const format = read('automation/TASK_FORMAT.md');
	assert(format.includes('`resource`') && format.includes('docs/RESOURCES.md'), 'TASK_FORMAT.md');
});

console.log(`Resources: ${passed} passed, ${failed} failed`);
process.exitCode = failed > 0 ? 1 : 0;
