// Contrôle hors Studio de l'interface Loot & Inventaire V1 (#72, côté client), sans Luau :
// `node tests/loot-ui.test.mjs`. Lecture seule. Vérifie, sur le code source :
//   - le butin (CombatEnded.Loot) est relayé et lu à part des monnaies (Rewards) ;
//   - aucune rareté ni couleur de rareté sur les ressources (règle 1 de docs/UI_DESIGN_SYSTEM.md § 2) ;
//   - une seule fonction de carte d'équipement (ItemCard), point de bascule unique pour #61 / #75 ;
//   - aucun compteur « 0/7 équipés » en dur, aucun texte en dur périmé (Équiper / Retirer : equipment-ui) ;
//   - les libellés d'états vides honnêtes, sans date ni nom de système futur ;
//   - le store d'inventaire est en lecture seule (GetInventory / InventoryChanged, aucun remote d'écriture) ;
//   - aucun rbxassetid dans les vues (icônes centralisées dans les *VisualConfig / catalogues).
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const read = (path) => readFileSync(join(repoRoot, path), 'utf8').replace(/\r\n/g, '\n');
const stripComments = (source) => source.replace(/--\[(=*)\[[\s\S]*?\]\1\]/g, '').replace(/--.*$/gm, '');

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
// Texte entre deux repères (premier repère inclus, second exclu).
function slice(source, from, to) {
	const start = source.indexOf(from);
	assert(start >= 0, `repère introuvable : ${from}`);
	const end = source.indexOf(to, start + from.length);
	assert(end > start, `repère introuvable : ${to}`);
	return source.slice(start, end);
}

const files = {
	reward: 'src/client/Controllers/RewardScreenController.lua',
	relay: 'src/client/Controllers/ArenaPlacementController.lua',
	sacoche: 'src/client/UI/Views/SacocheView.lua',
	expedition: 'src/client/UI/Views/ExpeditionView.lua',
	card: 'src/client/UI/ItemCard.lua',
	store: 'src/client/Inventory/InventoryStore.lua',
	heroBar: 'src/client/Controllers/HeroBarController.lua',
};
const code = Object.fromEntries(Object.entries(files).map(([key, path]) => [key, stripComments(read(path))]));

test('CombatEnded.Loot is relayed apart from Rewards and read apart from the currency cards', () => {
	const relay = slice(code.relay, 'RewardScreenController.Show({', '}, function()');
	assert(/\bRewards = rewards,/.test(relay) && /\bLoot = if typeof\(event\.Loot\) == "table" then event\.Loot else nil,/.test(relay), 'Loot and Rewards are not two separate fields');
	assert(!/event\.Rewards[^\n]*Loot|event\.Loot[^\n]*Rewards/.test(relay), 'Loot mixed with Rewards in the relay');
	assert(/LootModel\.parse\(data\.Loot,/.test(code.reward), 'the reward screen does not parse data.Loot');
	const loot = slice(code.reward, 'local function lootBlock(', 'function RewardScreenController.Hide()');
	assert(!/data\.Rewards|\brewards\b/.test(loot), 'the loot block reads the currency rewards');
	const card = slice(code.reward, 'local function card(', 'local function primaryButton(');
	assert(!/Loot|loot/.test(card), 'the currency card reads the loot');
});

test('the loot block plays a single sound for the whole line', () => {
	const loot = slice(code.reward, 'local function lootBlock(', 'function RewardScreenController.Hide()');
	assert((loot.match(/AudioController\.Play\(/g) ?? []).length === 1, 'exactly one Play in the loot block');
	const chip = slice(code.reward, 'local function resourceChip(', 'local function lootBlock(');
	assert(!/AudioController/.test(chip), 'a chip plays its own sound');
});

test('rule 1: no rarity and no rarity colour on a resource (reward chips, Sacoche tiles)', () => {
	const chip = slice(code.reward, 'local function resourceChip(', 'local function lootBlock(');
	const tiles = slice(code.sacoche, 'local function resourceTile(', 'local function renderEquipmentList(');
	for (const [name, block] of [['resourceChip', chip], ['Sacoche resource tiles', tiles]]) {
		assert(!/RarityStyle|Rarity|Rarete|rareté|\.Rank\b/i.test(block), `${name} touches a rarity`);
	}
	// l'écran de fin n'utilise RarityStyle que pour le rang (meilleur objet)
	const calls = [...code.reward.matchAll(/\bRarityStyle\.(\w+)/g)].map((m) => m[1]);
	assert(calls.every((name) => name === 'rank'), `RewardScreenController uses RarityStyle.${calls.filter((n) => n !== 'rank').join(', ')}`);
});

test('one item card: Sacoche and the reward screen both go through ItemCard, which owns the rarity text', () => {
	assert(/ItemCard\.create\(grid, card, \{/.test(code.sacoche) && /Variant = "Tile"/.test(code.sacoche), 'Sacoche does not use ItemCard (Tile)');
	assert(/ItemCard\.create\(root, best, \{/.test(code.reward) && /Variant = "Band"/.test(code.reward), 'the reward screen does not use ItemCard (Band)');
	assert(/function ItemCard\.rarity\(rarity: string\): string\s+return RarityStyle\.name\(rarity\)/.test(code.card), 'ItemCard.rarity is not the single RarityStyle.name entry point');
	const uses = [...code.card.matchAll(/\bRarityStyle\.(\w+)/g)].map((m) => m[1]);
	assert(uses.length > 0 && uses.every((name) => name === 'name'), `ItemCard reads RarityStyle.${uses.join(', ')} (neutral frame, text only until #61 / #75)`);
	const list = slice(code.sacoche, 'local function renderEquipmentList(', 'local function renderOther(');
	const loot = slice(code.reward, 'local function lootBlock(', 'function RewardScreenController.Hide()');
	for (const [name, block] of [['Sacoche equipment list', list], ['reward loot block', loot]]) {
		assert(!/\.Rarity\b|Rarete|RarityStyle/.test(block), `${name} reads an item rarity directly`);
	}
	// cadre extérieur neutre : le contour de la carte ne prend jamais la couleur de rareté
	assert(!/UIKit\.stroke\([^)]*(RarityStyle|Rarity)/.test(code.card), 'the card outline uses a rarity colour');
});

// #73 : l'action Équiper / Retirer existe désormais (détail d'un objet) ; elle est contrôlée par
// tests/equipment-ui.test.mjs. Ici : le compteur « x/7 » n'est jamais écrit en dur.
test('Sacoche: no hard-coded "0/7 équipés", no obsolete hard-coded text', () => {
	assert(!/0\/7|\/7 équipés/.test(code.sacoche), 'a hard-coded "0/7 équipés" counter is back');
	for (const stale of ['Le butin d\'Expédition arrive bientôt', 'Tes ressources apparaîtront ici']) {
		assert(!code.sacoche.includes(stale), `obsolete text "${stale}"`);
	}
});

test('honest empty states and labels (no date, no future system name)', () => {
	const sacoche = code.sacoche;
	for (const text of [
		'"Aucune ressource", "Gagne des combats pour en obtenir"',
		'"Aucun équipement", "Il peut tomber à la fin d\'un combat"',
		'"Pas encore utilisables : garde-les pour la suite"',
		'"Inventaire indisponible"',
	]) assert(sacoche.includes(text), `missing in SacocheView: ${text}`);
	assert(code.reward.includes('"Ajoutées à ta Sacoche"'), 'missing caption « Ajoutées à ta Sacoche »');
	assert(/Sacoche pleine/.test(code.reward), 'missing the honest Overflow message');
	assert(code.expedition.includes('"Pas de butin pour l\'instant"') && !/Équipements et ressources : bientôt|Butin à venir/.test(code.expedition), 'ExpeditionView fallback text');
	// aucun libellé affiché ne cite une date ou un système futur
	for (const key of ['sacoche', 'reward', 'card', 'expedition']) {
		const strings = [...code[key].matchAll(/"((?:[^"\\\n]|\\.)*)"/g)].map((m) => m[1]);
		for (const text of strings) {
			assert(!/forge|craft|recycl|bientôt|\b20\d\d\b|alpha|0\.0\.\d|#\d{2,3}\b/i.test(text), `${files[key]}: libellé « ${text} » cite une date ou un système futur`);
		}
	}
});

test('InventoryStore is read-only: GetInventory + InventoryChanged, no write remote', () => {
	assert(/WaitForChild\("GetInventory"/.test(code.store) && /WaitForChild\("InventoryChanged"/.test(code.store), 'remotes not awaited');
	assert(!/FireServer|GrantItem|GrantResource/.test(code.store), 'the store writes to the server');
	assert((code.store.match(/InvokeServer/g) ?? []).length === 1, 'exactly one InvokeServer (GetInventory)');
	assert(/pcall\(getRemote\.InvokeServer/.test(code.store), 'GetInventory is not protected by pcall (remote may be absent)');
	assert(/InventoryStore\.start\(\)/.test(code.heroBar), 'HeroBarController does not start the store');
});

test('views hold no asset id (icons stay in the configs and catalogues)', () => {
	for (const key of ['reward', 'sacoche', 'card', 'store', 'expedition']) {
		assert(!/rbxassetid/.test(code[key]), `${files[key]} contains a rbxassetid`);
	}
});

console.log(`Loot UI (node): ${passed} passed, ${failed} failed`);
if (failed > 0) process.exit(1);
