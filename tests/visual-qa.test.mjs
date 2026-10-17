// Contrôle hors Studio du protocole docs/VISUAL_QA.md, sans Luau : `node tests/visual-qa.test.mjs`.
// Lecture seule. Vérifie que les grilles PASS/FIX (créatures, interfaces, icônes, VFX) sont
// complètes et que ce qu'elles citent existe vraiment dans le dépôt :
//   - structure : tableau d'orientation, captures, grille OK/KO avec colonne « Bloquant », rapport ;
//   - tokens UITheme, contrôleurs, démonstrations Studio, fichiers et sections des autres docs ;
//   - valeurs chiffrées recopiées du code (14 px, 44 px, 0,85 s) ;
//   - renvois vers VISUAL_QA depuis CLAUDE.md, UI_DESIGN_SYSTEM, ITEMS et RESOURCES.
// Ne remplace pas le contrôle visuel : une grille ne se note que sur captures réelles de Studio.
import { existsSync, readFileSync } from 'node:fs';
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

const doc = read('docs/VISUAL_QA.md');

// Titres « ## 6. Interfaces » / « ### 6.1 Captures obligatoires » -> { '6': ..., '6.1': ... }.
const headings = new Map(
	[...doc.matchAll(/^(#{2,3}) (\d+(?:\.\d+)?)\.? .+$/gm)].map((m) => [m[2], { depth: m[1].length, index: m.index }]),
);
// Texte de la section, jusqu'au titre suivant de même niveau ou plus haut.
function section(number) {
	const start = headings.get(number);
	assert(start, `section § ${number} absente`);
	const next = [...headings.values()].find((h) => h.index > start.index && h.depth <= start.depth);
	return doc.slice(start.index, next ? next.index : doc.length);
}
function tableRows(text) {
	return text
		.split('\n')
		.filter((line) => line.startsWith('|') && !/^\|[-|]+\|$/.test(line))
		.map((line) => line.slice(1, -1).split(' | ').map((cell) => cell.trim()));
}

const grids = [
	{ name: 'créatures', captures: '1', grid: '2', report: '5', ids: ['1', '2', '3', '4', '5', '6'], min: 15 },
	{ name: 'interfaces', captures: '6.1', grid: '6.2', report: '6.3', ids: ['U1', 'U2', 'U3', 'U4', 'U5'], min: 10 },
	{ name: 'icônes', captures: '7.1', grid: '7.2', report: '7.3', ids: ['I1', 'I2', 'I3', 'I4'], min: 10 },
	{ name: 'VFX', captures: '8.1', grid: '8.2', report: '8.3', ids: ['V1', 'V2', 'V3', 'V4', 'V5', 'V6'], min: 10 },
];

test('orientation: one row per deliverable type, pointing to existing sections', () => {
	const rows = tableRows(doc.slice(0, headings.get('1').index)).slice(1);
	assert(rows.length === grids.length, `${rows.length} lignes au lieu de ${grids.length}`);
	rows.forEach((row, i) => {
		const refs = row.slice(1).map((cell) => cell.replace('§ ', ''));
		const g = grids[i];
		assert(
			refs.join() === [g.captures, g.grid, g.report].join(),
			`ligne « ${row[0]} » : ${refs.join(', ')} au lieu de ${g.captures}, ${g.grid}, ${g.report}`,
		);
		for (const ref of refs) assert(headings.has(ref), `§ ${ref} cité mais absent`);
	});
	assert(/pas de PASS sans capture/i.test(doc.slice(0, headings.get('1').index)), 'règle « pas de PASS sans capture » absente');
});

for (const g of grids) {
	test(`${g.name}: captures table lists ${g.ids.join(', ')} in order`, () => {
		const rows = tableRows(section(g.captures)).slice(1);
		const ids = rows.map((row) => row[0]);
		assert(ids.join() === g.ids.join(), `captures ${ids.join(', ')}`);
	});

	test(`${g.name}: grid has ≥ ${g.min} criteria, each with a question and a blocking flag`, () => {
		const rows = tableRows(section(g.grid));
		assert(rows[0].join() === 'Critère,Question,Bloquant', `en-tête ${rows[0].join(' | ')}`);
		const criteria = rows.slice(1);
		assert(criteria.length >= g.min, `${criteria.length} critères`);
		const names = new Set();
		for (const [name, question, blocking] of criteria) {
			assert(!names.has(name), `critère en double : ${name}`);
			names.add(name);
			assert(question.includes('?'), `${name} : la question ne se termine par aucun « ? »`);
			assert(/^(oui|non)\b/.test(blocking), `${name} : bloquant « ${blocking} »`);
		}
		assert(criteria.some((row) => row[2].startsWith('oui')), 'aucun critère bloquant');
		assert(/OK\*\* ou \*\*KO/.test(section(g.grid)), 'notation OK / KO non rappelée');
	});

	test(`${g.name}: report template ends on PASS | FIX and cites its captures`, () => {
		const block = section(g.report).match(/```\n([\s\S]*?)```/);
		assert(block, 'bloc de rapport absent');
		const report = block[1];
		assert(/^Verdict : PASS \| FIX$/m.test(report), 'ligne « Verdict : PASS | FIX » absente');
		for (const field of ['Captures :', 'Grille :', 'Défauts (si FIX) :', 'Corrections appliquées :'])
			assert(report.includes(field), `champ « ${field} » absent`);
		assert(report.includes(`${g.ids[0]}..${g.ids.at(-1)}`), `plage de captures ${g.ids[0]}..${g.ids.at(-1)} absente`);
	});
}

test('verdict (§ 3): only PASS or FIX, applies to every grid', () => {
	const verdict = section('3');
	for (const g of grids) assert(verdict.includes(`§ ${g.grid}`), `§ ${g.grid} non couvert par le verdict`);
	assert(/\*\*PASS\*\*/.test(verdict) && /\*\*FIX\*\*/.test(verdict), 'PASS / FIX absents');
	assert(/pas d'autre résultat/i.test(verdict), '« pas d’autre résultat » absent');
	assert(!/\b(PARTIEL|WARN|N\/A)\b/.test(doc), 'un troisième verdict apparaît dans le document');
});

test('FIX format (§ 4): capture ids U/I/V usable for every grid', () => {
	const fix = section('4');
	for (const id of ['U2', 'I3', 'V4']) assert(fix.includes(`\`${id}\``), `exemple ${id} absent`);
	assert(/nouvelles captures/i.test(fix), 'reprise sur nouvelles captures absente');
});

test('VFX require a sequence; captures end with a camera reset', () => {
	assert(/une seule capture ne suffit jamais/i.test(section('8')), 'VFX : séquence non exigée');
	for (const s of ['1', '6.1', '8.1'])
		assert(section(s).includes('Outils § A'), `§ ${s} : réinitialisation de la caméra absente`);
	assert(/Outils \(MCP Roblox Studio\)/.test(read('docs/MONSTER_PRODUCTION.md')), 'MONSTER_PRODUCTION : § Outils absent');
});

test('UITheme tokens cited by the grids exist in src/shared/Config/UITheme.lua', () => {
	const theme = read('src/shared/Config/UITheme.lua');
	const tokens = ['Ink', 'PanelStrong', 'Caption', 'Thin', 'Regular', 'Thick', 'Success', 'Error', 'Selected', 'Rarity', 'RarityPrism'];
	for (const token of tokens) assert(new RegExp(`\\b${token} = `).test(theme), `token ${token} absent du thème`);
	const caption = Number(theme.match(/\bCaption = (\d+)/)[1]);
	assert(section('6.2').includes(`${caption} px`), `taille minimale ${caption} px non reprise`);
	const touch = Number(theme.match(/\bTouchTarget = (\d+)/)[1]);
	assert(section('6.2').includes(`≥ ${touch} px`), `zone tactile ≥ ${touch} px non reprise`);
});

test('controllers, views and demos cited exist in src/client', () => {
	const controllers = [...doc.matchAll(/`(\w+Controller)`/g)].map((m) => m[1]);
	assert(controllers.length >= 8, `${controllers.length} contrôleurs cités`);
	for (const name of new Set(controllers))
		assert(existsSync(join(repoRoot, `src/client/Controllers/${name}.lua`)), `${name}.lua absent`);
	assert(existsSync(join(repoRoot, 'src/client/UI/Icons.lua')), 'src/client/UI/Icons.lua absent');

	const preview = read('src/client/Controllers/UIPreviewController.lua');
	const modes = section('6.1').match(/`Workspace\.ApercuUI` \(([^)]*)\)/)[1].match(/`(\w+)`/g).map((m) => m.slice(1, -1));
	for (const mode of modes) assert(preview.includes(`"${mode}"`), `mode ApercuUI « ${mode} » inconnu du contrôleur`);
	assert(read('src/client/Controllers/RewardScreenController.lua').includes('"ApercuEcranRecompenses"'), 'ApercuEcranRecompenses');
	assert(read('src/client/Controllers/DamageFeedbackController.lua').includes('"ApercuDegats"'), 'tag ApercuDegats');
	assert(read('src/client/Controllers/DamageFeedbackController.lua').includes('"ApercuAllie"'), 'attribut ApercuAllie');
	assert(read('src/client/Controllers/DefeatEffectController.lua').includes('"ApercuDisparition"'), 'tag ApercuDisparition');
});

test('VFX durations copied in the grid match the code', () => {
	const defeat = Number(read('src/client/Controllers/DefeatEffectController.lua').match(/local DURATION = ([\d.]+)/)[1]);
	assert(section('8.2').includes(`mort ${String(defeat).replace('.', ',')} s`), `durée de mort ${defeat} s non reprise`);
});

test('reference files and sections cited by the grids exist', () => {
	assert(existsSync(join(repoRoot, 'docs/references/ui/maquette_v1.jpg')), 'maquette_v1.jpg absente');
	const ui = read('docs/UI_DESIGN_SYSTEM.md');
	for (const n of ['1', '7', '8', '12']) assert(new RegExp(`^## ${n}\\. `, 'm').test(ui), `UI_DESIGN_SYSTEM § ${n} absent`);
	assert(/^## 4\. Produire une icône/m.test(read('docs/ITEMS.md')), 'ITEMS § 4 absent');
	assert(/^## 4\. Produire une icône/m.test(read('docs/RESOURCES.md')), 'RESOURCES § 4 absent');
	assert(/Workspace\.Bestiaire\.Inventaire/.test(read('docs/ITEMS.md')), 'vitrine Bestiaire.Inventaire inconnue de ITEMS');
	const summon = read('docs/SUMMON.md');
	assert(/^\| Rareté \| En plus \|$/m.test(summon), 'SUMMON : tableau « En plus » absent');
	for (const rarity of ['Commun', 'Légendaire', 'Transcendant']) assert(summon.includes(rarity), `SUMMON : ${rarity} absent`);
	assert(/secousse de caméra/.test(summon), 'SUMMON : secousse de caméra au Légendaire absente');
	for (const file of ['COMBAT.md', 'SUMMON.md', 'ART_DIRECTION.md', 'MONSTER_PRODUCTION.md'])
		assert(existsSync(join(repoRoot, 'docs', file)), `docs/${file} absent`);
});

test('the other guides send UI, icon and VFX checks to VISUAL_QA', () => {
	const ui = read('docs/UI_DESIGN_SYSTEM.md');
	const control = ui.slice(ui.indexOf('## 11.'), ui.indexOf('## 12.'));
	for (const s of ['§ 6', '§ 7', '§ 8']) assert(control.includes(s), `UI_DESIGN_SYSTEM § 11 ne renvoie pas à ${s}`);
	assert(/VISUAL_QA\.md` § 7/.test(ui.slice(ui.indexOf('## 7.'), ui.indexOf('## 8.'))), 'UI_DESIGN_SYSTEM § 7 sans renvoi');
	for (const file of ['docs/ITEMS.md', 'docs/RESOURCES.md']) {
		const text = read(file);
		const five = text.slice(text.indexOf('## 5.'), text.indexOf('## 6.'));
		assert(/VISUAL_QA\.md` § 7/.test(five) && /PASS\*\* ou \*\*FIX/.test(five), `${file} § 5 sans verdict VISUAL_QA`);
	}
	assert(/VISUAL_QA\.md` \(créature, interface, icône ou VFX/.test(read('CLAUDE.md')), 'CLAUDE.md : règle limitée aux créatures');
});

test('no rarity on monsters: grids forbid it for UI, icons and VFX', () => {
	assert(/Aucune couleur de rareté sur un monstre/.test(section('6.2')), 'interfaces');
	assert(/Aucune couleur de rareté/.test(section('7.2')), 'icônes');
	assert(/Aucune couleur de rareté sur un effet de monstre/.test(section('8.2')), 'VFX');
});

console.log(`\n${passed} passed, ${failed} failed`);
if (failed > 0) process.exit(1);
