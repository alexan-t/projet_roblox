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

console.log(`Resources: ${passed} passed, ${failed} failed`);
process.exitCode = failed > 0 ? 1 : 0;
