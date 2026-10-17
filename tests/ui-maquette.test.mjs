// Contrôle hors Studio de la maquette de validation v2 (docs/UI_DESIGN_SYSTEM.md, en-tête et § 14),
// sans Luau : `node tests/ui-maquette.test.mjs`. Lecture seule. Vérifie dans le code et la doc :
//   - la démo ApercuUI « Maquette » (UIPreviewController) : vraies vues, fiche Builder Sans dans un
//     sous-panneau PanelStrong (§ 3), aucune consigne d'ultime, nettoyée par hideAll ;
//   - le placement des vues (§ 12) : monnaies en haut au centre, quête en haut à gauche ;
//   - l'ultime automatique : démo ApercuUltime = Announce puis Play, comme CombatViewController ;
//   - la doc : maquette_v2 en référence, maquette_v1 déclarée obsolète.
// Le rendu lui-même (capture maquette_v2.jpg, VISUAL_QA) se contrôle dans Studio (§ 14, procédure).
import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const read = (path) => readFileSync(join(repoRoot, path), 'utf8').replace(/\r\n/g, '\n');

let passed = 0;
let failed = 0;
let skipped = 0;
function test(name, run) {
	try {
		const result = run();
		if (result === 'skip') {
			skipped += 1;
			console.log(`SKIP ${name}`);
			return;
		}
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

// Corps d'une fonction Luau locale : de `local function name(` jusqu'au `end` en colonne 0.
function luauFunction(source, name) {
	const start = source.search(new RegExp(`^local function ${name}\\(`, 'm'));
	assert(start >= 0, `local function ${name} introuvable`);
	const end = source.indexOf('\nend\n', start);
	assert(end > start, `fin de ${name} introuvable`);
	return source.slice(start, end + 4);
}

function luaFiles(dir) {
	const out = [];
	for (const entry of readdirSync(join(repoRoot, dir), { withFileTypes: true })) {
		const path = `${dir}/${entry.name}`;
		if (entry.isDirectory()) out.push(...luaFiles(path));
		else if (/\.luau?$/.test(entry.name)) out.push(path);
	}
	return out;
}

const preview = read('src/client/Controllers/UIPreviewController.lua');
const ultimate = read('src/client/Controllers/UltimateEffectController.lua');
const combatView = read('src/client/Controllers/CombatViewController.lua');
const currencyView = read('src/client/UI/Views/CurrencyView.lua');
const questView = read('src/client/UI/Views/QuestView.lua');
const collectionView = read('src/client/UI/Views/CollectionView.lua');
const uikit = read('src/client/UI/UIKit.lua');
const theme = read('src/shared/Config/UITheme.lua');
const doc = read('docs/UI_DESIGN_SYSTEM.md');
const maquette = luauFunction(preview, 'maquette');
const hideAll = luauFunction(preview, 'hideAll');

test('UIPreviewController: démo « Maquette » enregistrée dans DEMOS et documentée en tête', () => {
	assert(/^\tMaquette = maquette,$/m.test(preview), 'Maquette = maquette absent de DEMOS');
	assert(/^--\s+"Maquette"\s+.*maquette_v2\.jpg/m.test(preview), 'ligne "Maquette" absente de l\'en-tête');
});

test('UIPreviewController: chaque démo de DEMOS est listée dans l\'en-tête et dans § 12', () => {
	const block = preview.slice(preview.indexOf('local DEMOS'));
	const keys = [...block.matchAll(/^\t(\w+) = /gm)].map((m) => m[1]);
	assert(keys.length >= 8, `${keys.length} démos lues`);
	const section = doc.slice(doc.indexOf('### Démonstrations Studio'));
	for (const key of keys) {
		assert(new RegExp(`^--\\s+"${key}"`, 'm').test(preview), `${key} absent de l'en-tête`);
		assert(section.includes(`\`${key}\``), `${key} absent de § 12`);
	}
});

test('Maquette: compose les vraies vues (quête terminée avec Récupérer, monnaies, collection)', () => {
	assert(/QuestView\.Show\(\{[^}]*Completed = true[^}]*\}, \{\s*OnClaim = /s.test(maquette), 'quête terminée avec OnClaim');
	const gold = maquette.match(/CurrencyView\.Set\(\{ Gold = (\d+), Gems = (\d+), SummonTickets = (\d+) \}\)/);
	assert(gold, 'CurrencyView.Set avec or, gemmes, tickets');
	assert(gold[1] === '12450' && gold[2] === '85' && gold[3] === '3', `valeurs ${gold.slice(1).join(' / ')}`);
	assert(doc.includes('12 450 · 85 · 3'), '§ 14 ne cite pas les mêmes valeurs');
	assert(/CollectionView\.Show\(entries\)/.test(maquette), 'CollectionView.Show');
	for (const field of ['Name', 'Model', 'ClassId', 'Count', 'New', 'Equipped']) {
		assert(new RegExp(`\\b${field} = `).test(maquette), `entrée de collection sans ${field}`);
		assert(new RegExp(`\\b${field}: `).test(collectionView), `CollectionView ne lit pas ${field}`);
	}
});

test('Maquette: un seul héros Équipé et un seul Nouveau, distincts (badges § 14)', () => {
	assert(/Equipped = i == 1/.test(maquette), 'Équipé = premier héros');
	assert(/New = i == 2/.test(maquette), 'Nouveau = deuxième héros');
	assert(/Count = if i == 1 then 2 else 1/.test(maquette), '« ×2 » sur le premier héros');
});

test('Maquette § 3: texte Builder Sans dans un UIKit.subPanel PanelStrong, jamais sur un Panel', () => {
	assert(/UIKit\.subPanel\(screen,/.test(maquette), 'fiche = UIKit.subPanel');
	assert(!/UIKit\.(panel|window)\(/.test(maquette), 'la fiche ne doit pas être un Panel ni une fenêtre');
	const sub = uikit.slice(uikit.indexOf('function UIKit.subPanel'), uikit.indexOf('\nend\n', uikit.indexOf('function UIKit.subPanel')));
	assert(/BackgroundTransparency = UITheme\.Transparency\.PanelStrong/.test(sub), 'subPanel n\'utilise pas PanelStrong');
	assert(/PanelStrong = 0\.12/.test(theme), 'UITheme.Transparency.PanelStrong ≠ 0,12');
	const body = maquette.match(/local body = UIKit\.text\(fiche, "([^"]+)", Typography\.Size\.Body, \{([^}]*)\}\)/s);
	assert(body, 'texte long Body posé dans la fiche');
	assert(/Font = Typography\.Body/.test(body[2]), 'texte long sans police Builder Sans (Typography.Body)');
	assert(/Stroke = false/.test(body[2]), 'texte long Builder Sans sans contour (§ 4)');
	assert(/Body = Font\.new\("rbxasset:\/\/fonts\/families\/BuilderSans\.json"/.test(theme), 'Typography.Body ≠ Builder Sans');
	assert(/UIKit\.text\(fiche, name, Typography\.Size\.Heading/.test(maquette), 'nom du héros Fredoka Heading');
});

test('Maquette: aucune valeur de style en dur (UITheme uniquement)', () => {
	assert(!/Color3\.(fromRGB|new|fromHex)|Font\.new|Enum\.Font\./.test(maquette), 'couleur ou police en dur');
	assert(!/BackgroundTransparency\s*=\s*[\d.]/.test(maquette), 'transparence en dur');
	assert(/Spacing\.ScreenMargin/.test(maquette), 'marge d\'écran lue dans UITheme.Spacing');
});

test('Maquette: aucun bouton ni consigne d\'ultime (ultime automatique)', () => {
	assert(!/UIKit\.(button|roundButton)\(/.test(maquette), 'bouton dans la démo Maquette');
	assert(!/Ultime prêt|Touchez|touche|Appuie|Clique/i.test(maquette), 'consigne d\'ultime');
	const offenders = luaFiles('src').filter((path) => /Ultime prêt|Touchez le héros/.test(read(path)));
	assert(offenders.length === 0, `consigne d'ultime manuel dans ${offenders.join(', ')}`);
});

test('Maquette: la fiche passe au-dessus du voile de la collection et est détruite par hideAll', () => {
	const fiche = maquette.match(/UIKit\.screen\("MaquetteFiche", (\d+)\)/);
	const collection = collectionView.match(/UIKit\.screen\("Collection", (\d+)\)/);
	assert(fiche && collection, 'DisplayOrder lus');
	assert(Number(fiche[1]) > Number(collection[1]), `fiche ${fiche[1]} ≤ collection ${collection[1]}`);
	assert(/maquetteScreen = screen/.test(maquette), 'écran de la fiche non mémorisé');
	assert(/maquetteScreen:Destroy\(\)/.test(hideAll) && /maquetteScreen = nil/.test(hideAll), 'hideAll ne détruit pas la fiche');
	for (const view of ['QuestView', 'CurrencyView', 'CollectionView']) {
		assert(hideAll.includes(`${view}.Hide()`), `hideAll ne masque pas ${view}`);
	}
});

test('§ 12 placement: monnaies en haut au centre, quête en haut à gauche', () => {
	assert(/row\.AnchorPoint = Vector2\.new\(0\.5, 0\)/.test(currencyView), 'monnaies : AnchorPoint (0.5, 0)');
	assert(/row\.Position = UDim2\.new\(0\.5, 0, 0, TOP\)/.test(currencyView), 'monnaies : Position haut centre');
	assert(/panel\.Position = UDim2\.fromOffset\(Spacing\.ScreenMargin, TOP\)/.test(questView), 'quête : haut gauche');
	assert(/quête en haut à gauche, monnaies en haut au centre/.test(doc), '§ 12 ne décrit plus ce placement');
});

test('Ultime automatique: démo ApercuUltime = Announce puis Play, comme en combat', () => {
	const demo = luauFunction(ultimate, 'runDemo');
	const announce = demo.indexOf('UltimateEffectController.Announce(model, speed)');
	const play = demo.indexOf('UltimateEffectController.Play(model,');
	assert(announce >= 0, 'la démo n\'appelle pas Announce');
	assert(play > announce, 'Announce doit précéder Play');
	const combatAnnounce = combatView.indexOf('UltimateEffectController.Announce(');
	assert(combatAnnounce >= 0, 'CombatViewController n\'annonce plus l\'ultime');
	assert(/annonce « ULTIME ! »/.test(ultimate), 'en-tête ApercuUltime sans l\'annonce');
});

test('Doc: maquette_v2 en référence, maquette_v1 obsolète avec ses écarts, § 14 complet', () => {
	const head = doc.slice(0, doc.indexOf('## 1.'));
	assert(head.includes('docs/references/ui/maquette_v2.jpg'), 'en-tête sans maquette_v2.jpg');
	assert(/maquette_v1\.jpg` est \*\*obsolète\*\*/.test(head), 'maquette_v1 non déclarée obsolète');
	for (const gap of ['Ultime prêt', 'haut à gauche', '§ 3', 'Quête terminée', 'portraits 3D', 'barre de combat']) {
		assert(head.includes(gap), `écart de la v1 non listé : ${gap}`);
	}
	const s14 = doc.slice(doc.indexOf('## 14. Maquette de validation'));
	assert(s14.length > 100, '§ 14 absent');
	for (const needle of ['**haut centre**', 'PanelStrong', 'ApercuUltime', 'Workspace.AtelierAnimation', 'ApercuUI', 'VISUAL_QA', 'Réinitialiser la caméra']) {
		assert(s14.includes(needle), `§ 14 sans ${needle}`);
	}
	assert(existsSync(join(repoRoot, 'docs/references/ui/maquette_v1.jpg')), 'maquette_v1.jpg supprimée (gardée pour l\'historique)');
});

test('Capture: docs/references/ui/maquette_v2.jpg présente (à produire dans Studio, § 14)', () => {
	if (!existsSync(join(repoRoot, 'docs/references/ui/maquette_v2.jpg'))) return 'skip';
});

console.log(`\n${passed} passed, ${failed} failed, ${skipped} skipped`);
process.exit(failed === 0 ? 0 : 1);
