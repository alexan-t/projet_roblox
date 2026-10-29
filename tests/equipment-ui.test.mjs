// Contrôle hors Studio de l'interface Équipement V1 (#73, côté client), sans Luau :
// `node tests/equipment-ui.test.mjs`. Lecture seule. Vérifie, sur le code source :
//   - un seul remote d'écriture côté client, EquipmentAction, appelé avec EXACTEMENT 3 arguments
//     (action, héros, objet ou emplacement) ; aucune stat, rareté, ItemId ni niveau envoyé ;
//   - le store tolère l'absence du remote (boutons désactivés) ;
//   - aucun bouton Améliorer / Forge, aucun niveau d'amélioration affiché à +0 ;
//   - la rareté d'un item ne passe que par ItemCard (texte), jamais par le badge d'état ni la poupée ;
//   - UNE action principale dans le détail, erreur serveur et raison affichées ;
//   - textes >= 14 px et cibles >= 44 px dans les nouveaux blocs ; seules cibles de guidage : celles que
//     TutorialConfig vise (premier équipement : onglet, héros, premier objet libre, « Équiper »).
import { readFileSync, readdirSync, statSync } from 'node:fs';
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
function slice(source, from, to) {
	const start = source.indexOf(from);
	assert(start >= 0, `repère introuvable : ${from}`);
	const end = source.indexOf(to, start + from.length);
	assert(end > start, `repère introuvable : ${to}`);
	return source.slice(start, end);
}
function walk(dir) {
	const out = [];
	for (const name of readdirSync(join(repoRoot, dir))) {
		const path = `${dir}/${name}`;
		if (statSync(join(repoRoot, path)).isDirectory()) out.push(...walk(path));
		else if (path.endsWith('.lua')) out.push(path);
	}
	return out;
}
const strings = (source) => [...source.matchAll(/"((?:[^"\\\n]|\\.)*)"|`((?:[^`\\]|\\.)*)`/g)].map((m) => m[1] ?? m[2]);

const files = {
	store: 'src/client/Inventory/EquipmentStore.lua',
	model: 'src/shared/Sacoche/EquipmentModel.lua',
	sacoche: 'src/client/UI/Views/SacocheView.lua',
	card: 'src/client/UI/ItemCard.lua',
	heroBar: 'src/client/Controllers/HeroBarController.lua',
	inventoryStore: 'src/client/Inventory/InventoryStore.lua',
};
const code = Object.fromEntries(Object.entries(files).map(([key, path]) => [key, stripComments(read(path))]));

test('one client write remote: EquipmentAction, only in EquipmentStore, exactly 3 arguments', () => {
	for (const path of walk('src/client')) {
		if (path === files.store) continue;
		assert(!/EquipmentAction/.test(stripComments(read(path))), `${path} touches EquipmentAction`);
	}
	assert(/WaitForChild\("EquipmentAction"/.test(code.store), 'EquipmentAction not awaited');
	const calls = [...code.store.matchAll(/InvokeServer[^\n]*/g)].map((m) => m[0]);
	assert(calls.length === 1, `${calls.length} InvokeServer in EquipmentStore`);
	assert(/pcall\(r\.InvokeServer, r, action, heroInstanceId, target\)/.test(code.store), `call is not (action, hero, target): ${calls[0]}`);
	assert(!/FireServer/.test(code.store), 'EquipmentStore fires a RemoteEvent');
	assert(/action ~= "Equip" and action ~= "Unequip"/.test(code.store), 'actions other than Equip / Unequip are not rejected');
	// le store d'inventaire reste en lecture seule
	assert((code.inventoryStore.match(/InvokeServer/g) ?? []).length === 1 && !/EquipmentAction/.test(code.inventoryStore), 'InventoryStore writes');
});

test('no stat, rarity, ItemId or level is sent to the server', () => {
	assert(!/MaxHealth|AttackDamage|Bonus|Rarity|ItemId|UpgradeLevel/.test(code.store), 'EquipmentStore mentions a stat / rarity / ItemId');
	const request = slice(code.model, 'function EquipmentModel.request(', '\nend');
	assert(/return action\.Kind, action\.Hero, action\.Target/.test(request), 'request does not return (Kind, Hero, Target)');
	assert(!/Bonus|MaxHealth|AttackDamage|Rarity|ItemId/.test(request), 'request reads a stat / rarity / ItemId');
	const onAction = slice(code.heroBar, 'OnEquipAction = function()', 'BindDrag');
	assert(/EquipmentModel\.request\(detail\.Action\)/.test(onAction) && /EquipmentStore\.request\(action, hero, target\)/.test(onAction), 'the controller does not send EquipmentModel.request');
	assert(!/MaxHealth|AttackDamage|Bonus|Rarity/.test(onAction), 'the controller action reads a stat or rarity');
});

test('tolerant store: unavailable until the remote exists; actions disabled with a reason', () => {
	assert(/EquipmentStore\.available = false/.test(code.store), 'available does not start false');
	assert(/WaitForChild\("Remotes", WAIT\)/.test(code.store) && /found:IsA\("RemoteFunction"\)/.test(code.store), 'remote lookup not bounded / checked');
	assert(/Available = EquipmentStore\.available/.test(code.heroBar), 'the controller ignores the remote availability');
	assert(/"Équipement indisponible"/.test(code.model) && /"Impossible pendant un combat"/.test(code.model), 'missing disabled reasons');
	assert(/InCombat = ArenaStore\.inCombat\(\)/.test(code.heroBar), 'combat state not passed to the model');
});

test('no Améliorer / Forge button, no upgrade level shown at +0', () => {
	for (const key of ['sacoche', 'card', 'heroBar', 'model', 'store']) {
		for (const text of strings(code[key])) {
			assert(!/am[ée]lior|forge|upgrade|craft|affixe/i.test(text), `${files[key]}: label « ${text} »`);
		}
	}
	assert(!/UpgradeLevel/.test(code.sacoche) && !/UpgradeLevel/.test(code.card), 'a view reads UpgradeLevel directly (only InventoryModel.levelText may)');
	assert(/if card\.LevelText then/.test(code.card), 'ItemCard no longer gates the level badge on LevelText');
});

test('rarity only through ItemCard (text); state badge and doll never show a rarity', () => {
	const equipBlocks = slice(code.sacoche, 'local function renderEquipmentList(', 'local function renderOther(');
	assert(!/\.Rarity\b|RarityStyle|Rarete/.test(equipBlocks), 'the equipment blocks read an item rarity directly');
	assert(/ItemCard\.rarityLine\(card\)/.test(equipBlocks), 'the detail does not use ItemCard for the rarity text');
	assert(!/Rarity/.test(code.model), 'EquipmentModel touches a rarity');
	const badge = slice(code.card, 'local function stateBadge(', 'local function tile(');
	assert(!/Rarity|RarityStyle/.test(badge), 'the state badge uses a rarity');
	assert(/stateBadge\(frame, badgeText, if kind == "Equipped" then C\.Success else C\.RoyalRed, options\)/.test(code.card), 'state badge colour is not a state colour');
	assert(!/UIKit\.stroke\([^)]*(RarityStyle|Rarity)/.test(code.card), 'the card outline uses a rarity colour');
});

test('detail: ONE main action (Équiper / Retirer), server error and reason shown, Retour', () => {
	const detail = slice(code.sacoche, 'local function renderItemDetail(', 'local function equipKey(');
	assert((detail.match(/chunky\(/g) ?? []).length === 1, 'not exactly one main button');
	assert(/UIKit\.text\(face, a\.Label, L\.EquipCtaSize\)/.test(detail), 'the main label does not come from the model');
	assert(/equip\.Error/.test(detail) && /a\.Reason/.test(detail), 'error / reason not displayed');
	assert(/h\.OnItemBack/.test(detail) && /"Retour"/.test(detail), 'no way back to the doll');
	assert(/Label = "Équiper"/.test(code.model) && /Label = "Retirer"/.test(code.model), 'labels');
	// pas de seconde fenêtre : le détail vit dans le panneau de la poupée
	assert(!/ScreenState|UIKit\.window|UIKit\.overlay/.test(detail), 'the detail opens another screen');
});

test('new blocks: texts >= 14 px (tokens), touch targets >= 44 px', () => {
	const blocks = slice(code.sacoche, 'local function renderEquipmentList(', 'local function renderOther(');
	// text / line / UIKit.text (parent, contenu, TAILLE, ...) : une taille littérale doit être >= 14
	const call = /\b(?:text|line|UIKit\.text)\(\s*[^,()]+,\s*(?:"[^"]*"|`[^`]*`|[^,()"`]+),\s*(\d+)\b/g;
	for (const m of blocks.matchAll(call)) {
		assert(Number(m[1]) >= 14, `literal text size ${m[1]} in the equipment blocks: ${m[0]}`);
	}
	assert(/text\(count, "équipés", L\.EquipNoteSize/.test(blocks), 'the counter caption does not use a token');
	assert(!/pill\([^)]*,\s*1[23]\)/.test(code.sacoche), 'a 12 / 13 px pill is back in the Sacoche');
	const theme = read('src/shared/Config/UITheme.lua');
	for (const pack of ['Wide', 'Phone']) {
		const sacochePack = slice(theme, '\tSacoche = {', 'Margin = ');
		const block = slice(sacochePack, `\t\t${pack} = {`, '\n\t\t},');
		for (const key of ['DollStatSize', 'DollTagSize', 'BadgeSize', 'EquipNameSize', 'EquipTextSize', 'EquipNoteSize', 'EquipCtaSize', 'ItemLineSize']) {
			const value = Number((block.match(new RegExp(`\\b${key} = (\\d+)`)) ?? [])[1]);
			assert(value >= (pack === 'Phone' ? 15 : 14), `${pack}.${key} = ${value}`);
		}
		for (const key of ['EquipCtaHeight', 'BackWidth', 'SlotSize']) {
			const value = Number((block.match(new RegExp(`\\b${key} = (\\d+)`)) ?? [])[1]);
			assert(value >= 44, `${pack}.${key} = ${value}`);
		}
	}
});

test('guidance targets: only those TutorialConfig points at; the first-equipment ones are registered', () => {
	const registered = new Set();
	for (const key of ['sacoche', 'heroBar']) {
		for (const m of code[key].matchAll(/GuideTargets\.(?:register|open)\("([^"]+)"/g)) registered.add(m[1]);
	}
	const config = read('src/shared/Config/TutorialConfig.lua');
	const allowed = new Set(['Bag', 'Hotbar.Bar', 'Hotbar.Guide']);
	for (const m of config.matchAll(/Target = "([^"]+)"/g)) allowed.add(m[1]);
	for (const name of registered) assert(allowed.has(name), `guide target « ${name} » not used by TutorialConfig`);
	for (const name of ['Bag.EquipmentTab', 'Bag.EquipHero', 'Bag.FirstItem', 'Bag.EquipAction']) {
		assert(registered.has(name), `first-equipment target « ${name} » not registered by the Sacoche`);
	}
	// « Équiper » seulement : jamais « Retirer », jamais un bouton désactivé (combat)
	assert(/if on and a\.Kind == "Equip" then\s*GuideTargets\.register\("Bag\.EquipAction"/.test(code.sacoche), 'Bag.EquipAction: Équiper, enabled only');
});

test('equipment tutorial remains pending until the server inventory confirms an equipped item', () => {
	const controller = read('src/client/Controllers/TutorialController.lua');
	const rules = read('src/shared/Tutorial/TutorialRules.lua');
	assert(/if key ~= "Equipment" then\s*mark\(key\)/.test(controller), 'Equipment flagged at opening');
	assert(/TutorialRules\.hasEquipped\(count, entries, ItemConfig\.Items\)/.test(controller), 'server equipment confirmation missing');
	assert(/not seen\.Equipment[\s\S]*?TutorialRules\.hasEquipped[\s\S]*?mark\("Equipment"\)/.test(controller), 'equipment marked before confirmation');
	assert(/local equipmentLast[\s\S]*?sequence\.key == "Equipment"[\s\S]*?OnActivated = if fromSequence and not equipmentLast then nextStep else nil/.test(controller), 'last step must not end on a rejected Equip click');
	assert(/function TutorialRules\.hasEquipped/.test(rules), 'missing pure server inventory rule');
});

test('views hold no asset id (item icons come from ItemConfig)', () => {
	for (const key of ['sacoche', 'card', 'store', 'model', 'heroBar']) {
		assert(!/rbxassetid/.test(code[key]), `${files[key]} contains a rbxassetid`);
	}
});

console.log(`Equipment UI (node): ${passed} passed, ${failed} failed`);
if (failed > 0) process.exit(1);
