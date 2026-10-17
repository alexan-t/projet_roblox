// Contrôle hors Studio du second repère de rareté (docs/UI_DESIGN_SYSTEM.md § 2), sans Luau :
// `node tests/rarity-mark.test.mjs`. Lecture seule. Compare UITheme.RarityMark (src/shared/Config/UITheme.lua) :
//   - aux paliers de src/shared/Config/RarityConfig.lua et aux couleurs UITheme.Rarity ;
//   - aux formes dessinées par src/client/UI/RarityStyle.lua (table SHAPES) ;
//   - au tableau de docs/UI_DESIGN_SYSTEM.md § 2 (lu dans le document lui-même).
// Vérifie aussi que les vues passent par RarityStyle (repère + couleur) et jamais par la couleur seule.
// Complète src/server/Tests/RarityMark.spec.lua (tools/test-ui-theme.ps1), qui demande luau.exe.
// Le rendu à l'écran se contrôle dans Studio (docs/VISUAL_QA.md).
import { readFileSync, readdirSync, statSync } from 'node:fs';
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
// Contenu d'une table Luau `local <name> = { ... }` (jusqu'à la première ligne `}`).
function block(source, name) {
	const m = source.match(new RegExp(`^local ${name}\\b[^\\n]*= \\{\\n([\\s\\S]*?)\\n\\}`, 'm'));
	return m ? m[1] : null;
}

const theme = read('src/shared/Config/UITheme.lua');
const tiers = [...read('src/shared/Config/RarityConfig.lua').matchAll(/\{ Id = "(\w+)", Name = "([^"]+)", Weight = (\d+) \}/g)].map(
	(m) => ({ id: m[1], name: m[2] }),
);
const colors = Object.fromEntries(
	[...(block(theme, 'Rarity') ?? '').matchAll(/^\t(\w+) = hex\("(#[0-9A-Fa-f]{6})"\)/gm)].map((m) => [m[1], m[2].toUpperCase()]),
);
const markLines = [...(block(theme, 'RarityMark') ?? '').matchAll(/^\t(\w+) = \{ Shape = "(\w+)", Count = (\d+) \}/gm)];
const marks = Object.fromEntries(markLines.map((m) => [m[1], { shape: m[2], count: Number(m[3]) }]));

const style = read('src/client/UI/RarityStyle.lua');
const shapes = new Set([...(block(style, 'SHAPES') ?? '').matchAll(/^\t(\w+) = \{/gm)].map((m) => m[1]));

const doc = read('docs/UI_DESIGN_SYSTEM.md');
const SHAPE_WORDS = { Circle: 'rond', Diamond: 'losange', Cross: 'croix', Ring: 'anneau', Burst: 'éclat', Star: 'étoile' };

test('RarityConfig lists the ten tiers', () => {
	assert(tiers.length === 10, `${tiers.length} tiers found`);
});

test('every tier has a color and a mark, and no mark without a tier', () => {
	const ids = new Set(tiers.map((t) => t.id));
	for (const t of tiers) {
		assert(colors[t.id], `no color for ${t.id}`);
		assert(marks[t.id], `no mark for ${t.id}`);
	}
	assert(markLines.length === Object.keys(marks).length, 'a rarity has two marks');
	for (const id of Object.keys(marks)) assert(ids.has(id), `mark for unknown rarity ${id}`);
});

test('marks use shapes drawn by RarityStyle, 1 to 3 times', () => {
	assert(shapes.size > 0, 'no shape found in RarityStyle SHAPES');
	for (const [id, mark] of Object.entries(marks)) {
		assert(shapes.has(mark.shape), `${id}: shape ${mark.shape} not drawn by RarityStyle`);
		assert(Number.isInteger(mark.count) && mark.count >= 1 && mark.count <= 3, `${id}: count ${mark.count}`);
	}
	for (const shape of shapes) {
		assert(Object.values(marks).some((m) => m.shape === shape), `RarityStyle draws unused shape ${shape}`);
	}
});

test('every (shape, count) pair is unique', () => {
	const seen = new Map();
	for (const [id, mark] of Object.entries(marks)) {
		const key = `${mark.shape}x${mark.count}`;
		assert(!seen.has(key), `${id} and ${seen.get(key)} share ${key}`);
		seen.set(key, id);
	}
});

test('a shape covers consecutive tiers, counting 1, 2, 3 upward', () => {
	const last = new Map();
	const count = new Map();
	tiers.forEach((t, rank) => {
		const mark = marks[t.id];
		const previous = last.get(mark.shape);
		assert(previous === undefined || previous === rank - 1, `${t.id}: ${mark.shape} is not contiguous`);
		const expected = (count.get(mark.shape) ?? 0) + 1;
		assert(mark.count === expected, `${t.id}: ${mark.shape} count ${mark.count}, expected ${expected}`);
		last.set(mark.shape, rank);
		count.set(mark.shape, expected);
	});
});

test('close colors get different shapes (review: Épique / Maudit, Calamité / Error)', () => {
	assert(marks.Epique.shape !== marks.Maudit.shape, 'Épique / Maudit');
	assert(marks.Calamite.shape !== marks.Mythique.shape, 'Calamité / Mythique');
	assert(marks.Rare.shape !== marks.Transcendant.shape, 'Rare / Transcendant');
	assert(marks.Commun.shape !== marks.Supreme.shape, 'Commun / Suprême');
});

test('semantic colors (Error…) carry no rarity mark', () => {
	const semantic = [...(block(theme, 'Colors') ?? '').matchAll(/^\t(\w+) = hex\(/gm)].map((m) => m[1]);
	assert(semantic.includes('Error'), 'Error not found in UITheme.Colors');
	for (const name of semantic) assert(!marks[name], `semantic color ${name} has a mark`);
});

test('RarityMark is frozen and exported', () => {
	assert(/^for _, mark in RarityMark do\n\ttable\.freeze\(mark\)\nend$/m.test(theme), 'entries are not frozen');
	assert(/^\tRarityMark = table\.freeze\(RarityMark\),$/m.test(theme), 'RarityMark not exported frozen');
});

test('UI_DESIGN_SYSTEM § 2 table matches RarityMark and the colors', () => {
	const rows = new Map(
		[...doc.matchAll(/^\| ([^|]+?) \| ([^|]+?) \| (\d) ([^|]+?) \|$/gm)].map((m) => [m[1], { color: m[2], count: Number(m[3]), word: m[4] }]),
	);
	for (const t of tiers) {
		const row = rows.get(t.name);
		assert(row, `no row for ${t.name}`);
		const mark = marks[t.id];
		assert(row.count === mark.count, `${t.name}: doc count ${row.count}, token ${mark.count}`);
		assert(row.word.includes(SHAPE_WORDS[mark.shape]), `${t.name}: doc says "${row.word}", token ${mark.shape}`);
		if (t.id !== 'Transcendant') {
			assert(row.color.toUpperCase().includes(colors[t.id]), `${t.name}: doc color ${row.color}, token ${colors[t.id]}`);
		}
	}
});

test('RarityStyle draws the mark in badge, edgeBadge and chip', () => {
	for (const fn of ['badge', 'edgeBadge']) {
		const body = style.match(new RegExp(`function RarityStyle\\.${fn}\\([\\s\\S]*?\\nend\\n`))?.[0] ?? '';
		assert(body, `RarityStyle.${fn} not found`);
		assert(body.includes('withMark('), `RarityStyle.${fn} has no mark`);
	}
	const chip = style.match(/function RarityStyle\.chip\([\s\S]*?\nend\n/)?.[0] ?? '';
	assert(chip.includes('RarityStyle.mark('), 'RarityStyle.chip has no mark');
	assert(/withMark[\s\S]*?RarityStyle\.mark\(/.test(style), 'withMark does not draw the mark');
});

// Vues et contrôleurs client : une rareté passe par RarityStyle. UIKit.badge / edgeBadge avec une
// couleur de rareté, ou une pastille peinte avec RarityStyle.color, serait un repère couleur seule.
const clientFiles = [];
(function walk(dir) {
	for (const entry of readdirSync(dir)) {
		const path = join(dir, entry);
		if (statSync(path).isDirectory()) walk(path);
		else if (path.endsWith('.lua')) clientFiles.push(relative(repoRoot, path).replace(/\\/g, '/'));
	}
})(join(repoRoot, 'src/client'));

test('no client view shows a rarity by its color alone', () => {
	for (const path of clientFiles) {
		if (path === 'src/client/UI/RarityStyle.lua') continue;
		const source = read(path);
		assert(!/UITheme\.Rarity\b(?!Mark)/.test(source.replace(/--[^\n]*/g, '')), `${path} reads UITheme.Rarity directly`);
		assert(!/UIKit\.(badge|edgeBadge)\([^\n]*RarityStyle\.color/.test(source), `${path}: UIKit badge with a rarity color`);
	}
});

test('SummonView uses the mark in the rates panel, featured cards and reveal', () => {
	const view = read('src/client/UI/Views/SummonView.lua');
	const rates = view.match(/local function ratesPanel\([\s\S]*?\nend\n/)?.[0] ?? '';
	assert(rates.includes('RarityStyle.chip('), 'rates panel has no rarity chip');
	assert(view.includes('RarityStyle.edgeBadge('), 'featured card has no rarity badge');
	const chips = view.match(/RarityStyle\.chip\(/g)?.length ?? 0;
	assert(chips >= 2, `expected a chip in the rates panel and the reveal, found ${chips}`);
});

console.log(`RarityMark (node): ${passed} passed, ${failed} failed`);
if (failed > 0) process.exit(1);
