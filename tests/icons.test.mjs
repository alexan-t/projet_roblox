// Contrôle hors Studio des icônes de l'interface (docs/UI_DESIGN_SYSTEM.md § 7), sans Luau :
// `node tests/icons.test.mjs`. Lecture seule. Compare src/shared/Config/IconConfig.lua :
//   - aux modèles provisoires de src/client/UI/Icons.lua (SHAPES) ;
//   - au tableau « Catalogue et état » de docs/UI_DESIGN_SYSTEM.md § 7 ;
//   - aux identifiants littéraux passés à Icons.icon dans src/client, aux profils de HeroConfig
//     (icônes de classe) et aux monnaies de CurrencyView ;
//   - aux couleurs d'UITheme, au bouton sacoche et à tools/studio-icons-atelier.luau.
// Complète src/server/Tests/IconConfig.spec.lua (tools/test-icons.ps1), qui demande luau.exe.
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { dirname, join, relative } from 'node:path';
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
function luaFiles(dir) {
	return readdirSync(join(repoRoot, dir)).flatMap((name) => {
		const path = join(dir, name);
		return statSync(join(repoRoot, path)).isDirectory() ? luaFiles(path) : path.endsWith('.lua') ? [path] : [];
	});
}

const source = read('src/shared/Config/IconConfig.lua');
const icons = [...source.matchAll(/^icon\("([^"]*)", "([^"]*)", "([^"]*)", "([^"]*)"(?:, "([^"]*)")?\)\s*$/gm)].map((m) => ({
	id: m[1],
	name: m[2],
	group: m[3],
	hook: m[4],
	image: m[5],
}));
const iconCalls = source.match(/^icon\(/gm)?.length ?? 0;
const ids = new Set(icons.map((info) => info.id));

const iconsModule = read('src/client/UI/Icons.lua');
const shapes = new Set([...iconsModule.matchAll(/^\t(\w+) = function\(part\)$/gm)].map((m) => m[1]));

const doc = read('docs/UI_DESIGN_SYSTEM.md');
const docIds = [...doc.matchAll(/^\| [^|]+ \| `(\w+)` \| [^|]+ \| [^|]+ \|$/gm)].map((m) => m[1]);

// Les sept icônes prioritaires qui manquaient (revue « Design et expérience » du 16 octobre).
const PRIORITY = ['Collection', 'Royaume', 'Carte', 'Parametres', 'Coche', 'Ultime', 'Sacoche'];

test('IconConfig: every icon(...) line parses, ids unique, groups known', () => {
	assert(iconCalls === icons.length && icons.length > 0, `${iconCalls} appels icon(), ${icons.length} lus`);
	assert(ids.size === icons.length, 'identifiant en double');
	for (const info of icons) {
		assert(['Classe', 'Objet', 'Navigation'].includes(info.group), `${info.id}: groupe ${info.group}`);
		assert(info.name !== '' && info.hook !== '', `${info.id}: nom ou objet vide`);
	}
});

test('IconConfig: images are nil or rbxassetid', () => {
	for (const info of icons) {
		assert(info.image === undefined || /^rbxassetid:\/\/\d+$/.test(info.image), `${info.id}: image ${info.image}`);
	}
});

test('IconConfig: the 7 missing priority icons are catalogued', () => {
	for (const id of PRIORITY) assert(ids.has(id), `${id} absent`);
});

test('Icons.lua: one provisional model per catalogued icon, no orphan model', () => {
	for (const id of ids) assert(shapes.has(id), `${id}: pas de modèle dans SHAPES`);
	for (const id of shapes) assert(ids.has(id), `${id}: modèle absent d'IconConfig`);
});

test('UI_DESIGN_SYSTEM.md § 7: table lists the catalogue, in order', () => {
	assert(docIds.join(',') === icons.map((info) => info.id).join(','), `doc : ${docIds.join(', ')}`);
});

test('screens use Icons.icon with known ids, never Icons.viewport directly', () => {
	for (const path of luaFiles('src/client')) {
		const rel = relative(repoRoot, join(repoRoot, path)).replace(/\\/g, '/');
		if (rel === 'src/client/UI/Icons.lua') continue;
		const text = read(path);
		assert(!/Icons\.viewport\(/.test(text), `${rel}: Icons.viewport au lieu d'Icons.icon`);
		for (const m of text.matchAll(/Icons\.icon\([^,]+, "(\w+)"\)/g)) assert(ids.has(m[1]), `${rel}: icône inconnue ${m[1]}`);
	}
});

const theme = read('src/shared/Config/UITheme.lua');
const themeColors = new Set([...theme.match(/^local Colors = \{\n([\s\S]*?)\n\}/m)[1].matchAll(/^\t(\w+) = hex\(/gm)].map((m) => m[1]));

test('Icons.lua: every Colors.X exists in UITheme.Colors', () => {
	assert(themeColors.size > 0, 'UITheme.Colors illisible');
	for (const m of iconsModule.matchAll(/\bColors\.(\w+)/g)) assert(themeColors.has(m[1]), `Colors.${m[1]} absent d'UITheme`);
});

test('Icons.lua: no model is painted Ink (the atelier strips Ink parts as the silhouette)', () => {
	const shapesBody = iconsModule.match(/^local SHAPES[\s\S]*?^\}$/m)[0];
	assert(!/Colors\.Ink\b/.test(shapesBody), 'une pièce Colors.Ink serait détruite par tools/studio-icons-atelier.luau');
	assert(/^local Stroke = \{\n\tColor = Colors\.Ink,/m.test(theme), 'UITheme.Stroke.Color n\'est plus Ink');
});

test('dynamic ids: every hero CombatProfile and CurrencyView icon is catalogued', () => {
	const heroes = read('src/shared/Config/HeroConfig.lua');
	const profiles = new Set([...heroes.matchAll(/^hero\("[^"]+", "[^"]+", "[^"]+", "(\w+)"/gm)].map((m) => m[1]));
	const classes = new Set(icons.filter((info) => info.group === 'Classe').map((info) => info.id));
	assert(profiles.size > 0, 'HeroConfig illisible');
	for (const id of profiles) assert(classes.has(id), `profil ${id} sans icône de classe`);
	for (const id of classes) assert(profiles.has(id), `icône de classe ${id} sans profil HeroConfig`);
	const currencies = [...read('src/client/UI/Views/CurrencyView.lua').matchAll(/\{ Key = "\w+", Icon = "(\w+)" \}/g)].map((m) => m[1]);
	assert(currencies.length === 3, `${currencies.length} monnaies lues`);
	for (const id of currencies) assert(ids.has(id), `CurrencyView: icône inconnue ${id}`);
});

test('UI_DESIGN_SYSTEM.md § 7: delivery state agrees with IconConfig.Image', () => {
	const delivered = icons.filter((info) => info.image !== undefined).length;
	const saysNone = doc.includes('Aucune icône n\'est encore livrée en PNG');
	assert(saysNone === (delivered === 0), `doc « aucune livrée » = ${saysNone}, ${delivered} PNG dans IconConfig`);
});

test('HeroBarController: bag button shows the Sacoche icon, no text label', () => {
	const bar = read('src/client/Controllers/HeroBarController.lua');
	assert(/UIKit\.button\(screen, "", "Secondary"/.test(bar), 'bouton sacoche avec libellé');
	assert(/Icons\.icon\(toggle\.face, "Sacoche"\)/.test(bar), 'icône Sacoche absente du bouton');
	assert(!/"Sac"/.test(bar), 'libellé « Sac » encore présent');
});

test('studio-icons-atelier.luau: one Ctrl+Z step, relative to Bestiaire, never edits it', () => {
	const tool = read('tools/studio-icons-atelier.luau');
	assert((tool.match(/TryBeginRecording\(/g) ?? []).length === 1 && /FinishRecording\(recording, Enum\.FinishRecordingOperation\.Commit\)/.test(tool), 'étape ChangeHistoryService');
	assert(/workspace\.Bestiaire:GetPivot\(\)/.test(tool), 'placement non relatif au Bestiaire');
	assert(!/Bestiaire[\w.:]*(?:Destroy|Parent\s*=|PivotTo|ScaleTo)/.test(tool), 'le Bestiaire est modifié');
	assert(/IconConfig\.Ordered/.test(tool) && /Icons\.model\(info\.Id\)/.test(tool), 'ne parcourt pas le catalogue');
	assert(!/\.Source\s*=/.test(tool), 'écrit un Source de script');
});

console.log(`Icons: ${passed} passed, ${failed} failed`);
if (failed > 0) process.exit(1);
