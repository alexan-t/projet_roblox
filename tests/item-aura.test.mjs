// Contrôle hors Studio de l'aura de rareté des items (docs/ITEMS.md § 7), sans Luau :
// `node tests/item-aura.test.mjs`. Lecture seule. Vérifie src/shared/Config/ItemAuraConfig.lua :
//   - un palier par rareté de RarityConfig, dans le même ordre, rien d'autre ;
//   - l'effet ne faiblit jamais d'une rareté à la suivante et grandit à chaque palier ;
//   - les 100 items de ItemConfig ont tous une aura ;
//   - le rendu (ItemAura) n'emploie aucune couleur en dur et aucune image à charger.
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const read = (path) => readFileSync(join(repoRoot, path), 'utf8');

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

const tiers = [...read('src/shared/Config/RarityConfig.lua').matchAll(/\{ Id = "(\w+)", Name = "[^"]+", Weight = \d+ \}/g)].map((m) => m[1]);
const auraSource = read('src/shared/Config/ItemAuraConfig.lua');
const auras = new Map(
	[...auraSource.matchAll(/^\t(\w+) = \{ (Fill = [^}]*) \},$/gm)].map((m) => [
		m[1],
		Object.fromEntries(m[2].split(', ').map((pair) => pair.split(' = ')).map(([k, v]) => [k, Number(v)])),
	]),
);
const items = [...read('src/shared/Config/ItemConfig.lua').matchAll(/^item\("([^"]*)", "[^"]*", "([^"]*)"/gm)].map((m) => ({ id: m[1], rarity: m[2] }));
const FIELDS = ['Fill', 'Stroke', 'Sheen', 'Halo', 'Reach', 'Pulse', 'Rays', 'Spin', 'Sparkles', 'Motes', 'Dark'];
// sens de « plus impressionnant » : +1 = la valeur monte, -1 = elle descend (plus plein, plus rapide)
const GROWS = { Fill: -1, Stroke: 1, Sheen: -1, Halo: 1, Reach: 1, Rays: 1, Spin: 1, Sparkles: 1, Motes: 1 };

test('one aura per RarityConfig tier, same order, all fields numeric', () => {
	assert(tiers.length === 10, `${tiers.length} tiers in RarityConfig`);
	assert([...auras.keys()].join() === tiers.join(), `auras ${[...auras.keys()].join()} vs tiers ${tiers.join()}`);
	for (const [id, aura] of auras) {
		for (const field of FIELDS) assert(Number.isFinite(aura[field]), `${id}.${field} = ${aura[field]}`);
		assert(Object.keys(aura).length === FIELDS.length, `${id}: ${Object.keys(aura).join()}`);
	}
});

test('aura never weakens and grows at every tier', () => {
	for (let i = 1; i < tiers.length; i += 1) {
		const before = auras.get(tiers[i - 1]);
		const after = auras.get(tiers[i]);
		let stronger = false;
		for (const [field, way] of Object.entries(GROWS)) {
			const delta = (after[field] - before[field]) * way;
			assert(delta >= 0, `${tiers[i]}.${field} weaker than ${tiers[i - 1]}`);
			stronger ||= delta > 0;
		}
		// la respiration accélère dès qu'il y en a une
		if (before.Pulse > 0) assert(after.Pulse > 0 && after.Pulse <= before.Pulse, `${tiers[i]}.Pulse slower than ${tiers[i - 1]}`);
		assert(stronger, `${tiers[i]} not stronger than ${tiers[i - 1]}`);
	}
});

test('bounds: transparencies in 0..1, at most 2 ray layers and 8 sparkles, only Maudit is dark', () => {
	for (const [id, aura] of auras) {
		assert(aura.Fill > 0 && aura.Fill < 1, `${id}.Fill`);
		for (const field of ['Halo', 'Rays', 'Sparkles', 'Motes']) {
			assert(Number.isInteger(aura[field]) && aura[field] >= 0, `${id}.${field}: non-negative integer required`);
		}
		assert(aura.Stroke > 0 && aura.Sheen > 0, `${id}: positive stroke and sheen period required`);
		assert(aura.Pulse >= 0 && aura.Spin >= 0, `${id}: negative animation timing`);
		assert(aura.Halo === 0 || aura.Pulse > 0, `${id}: halo must breathe`);
		assert(aura.Rays <= 2 && aura.Sparkles <= 8, `${id} rays/sparkles`);
		assert(aura.Reach >= 1, `${id}.Reach`);
		assert(aura.Dark === (id === 'Maudit' ? 1 : 0), `${id}.Dark`);
		assert((aura.Rays === 0) === (aura.Spin === 0), `${id}: Spin without rays or rays without Spin`);
	}
	const first = auras.get(tiers[0]);
	const last = auras.get(tiers.at(-1));
	assert(first.Halo === 0 && first.Rays === 0 && first.Sparkles === 0 && first.Motes === 0, 'Commun stays sober (tint + sheen)');
	assert(last.Halo > 0 && last.Rays > 0 && last.Sparkles > 0 && last.Motes > 0, 'Transcendant has every layer');
});

test('every catalogue item has an aura', () => {
	assert(items.length === 100, `${items.length} items`);
	assert(new Set(items.map((item) => item.id)).size === 100, 'duplicate item IDs');
	for (const item of items) assert(auras.has(item.rarity), `${item.id}: no aura for ${item.rarity}`);
	const catalogue = JSON.parse(read('automation/catalogues/items.json')).queue;
	// Le catalogue de production exclut les 58 icônes livrées par le partenaire.
	assert(catalogue.length > 0, 'empty production catalogue');
	assert(new Set(catalogue.map((item) => item.id)).size === catalogue.length, 'duplicate production IDs');
	assert(catalogue.every((task) => items.some((item) => item.id === task.id)), 'production item missing from aura coverage');
});

test('preview visits the full catalogue and applies each item rarity', () => {
	const preview = read('src/client/UI/Views/ItemAuraView.lua');
	assert(/for _, info in ItemConfig\.Ordered do/.test(preview), 'preview must read all items');
	assert(/for r, tier in RarityConfig\.Tiers do/.test(preview), 'preview must include all tiers');
	assert(/ItemAura\.apply\(tile, info\.Rarity,/.test(preview), 'preview must use item rarity');
	const controller = read('src/client/Controllers/UIPreviewController.lua');
	assert(/ItemAuraView\.Show\(/.test(controller), 'preview not reachable');
});

test('ItemAura renderer: colors from RarityStyle / UITheme only, no image asset', () => {
	const renderer = read('src/client/UI/ItemAura.lua');
	assert(!/Color3\.(fromRGB|fromHex)|#[0-9A-Fa-f]{6}/.test(renderer), 'hard-coded color in ItemAura.lua');
	assert(!/rbxassetid|ImageLabel/.test(renderer), 'ItemAura.lua depends on an image asset');
	assert(/Config\.forRarity\(/.test(renderer), 'ItemAura.lua does not read ItemAuraConfig');
	const expedition = read('src/client/UI/Views/ExpeditionView.lua');
	assert(/drop\.Kind == "Item"[^\n]*\n[^\n]*\n\s*ItemAura\.apply\(/.test(expedition), 'Expedition loot: aura on items only');
});

console.log(`ItemAura: ${passed} passed, ${failed} failed`);
if (failed > 0) process.exit(1);
