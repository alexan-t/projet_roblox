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
	assert(rows.size === tiers.length, `${rows.size} rarity rows in § 2, ${tiers.length} tiers`);
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

// --- Formes réellement dessinées ---------------------------------------------------------------
// Le nom d'une forme ne suffit pas : deux clés différentes pourraient dessiner le même objet.
// Chaque ligne du bloc SHAPES (`Nom = { { W, H, Rotation?, Round?, Hole? }, … },`) est lue telle
// quelle ; les pièces forment la signature visuelle de la forme.
const SHAPE_KEYS = ['W', 'H', 'Rotation', 'Round', 'Hole'];
function parsePieces(source) {
	const out = new Map();
	for (const line of (block(source, 'SHAPES') ?? '').split('\n')) {
		const row = line.match(/^\t(\w+) = \{ (.*) \},?$/);
		if (!row) continue;
		const pieces = [...row[2].matchAll(/\{ ([^{}]*) \}/g)].map((p) =>
			Object.fromEntries([...p[1].matchAll(/(\w+) = (-?[\w.]+)/g)].map((kv) => [kv[1], Number.isNaN(Number(kv[2])) ? kv[2] : Number(kv[2])])),
		);
		out.set(row[1], pieces);
	}
	return out;
}
const pieces = parsePieces(style);
const signature = (shape) =>
	JSON.stringify(
		(shape ?? []).map((p) => [p.W, p.H, p.Rotation ?? 0, p.Round ?? false, p.Hole ?? false]),
	);

test('every mark shape is drawn with 1 to 3 frames and known piece fields', () => {
	assert(pieces.size === shapes.size, `${pieces.size} shapes parsed, ${shapes.size} found`);
	for (const [name, shape] of pieces) {
		assert(shape.length >= 1 && shape.length <= 3, `${name}: ${shape.length} pieces`);
		for (const p of shape) {
			assert(typeof p.W === 'number' && p.W > 0 && p.W <= 1, `${name}: W ${p.W}`);
			assert(typeof p.H === 'number' && p.H > 0 && p.H <= 1, `${name}: H ${p.H}`);
			for (const key of Object.keys(p)) assert(SHAPE_KEYS.includes(key), `${name}: unknown field ${key}`);
			if ('Rotation' in p) assert(typeof p.Rotation === 'number', `${name}: rotation ${p.Rotation}`);
		}
	}
	for (const [id, mark] of Object.entries(marks)) assert(pieces.has(mark.shape), `${id}: ${mark.shape} not parsed`);
});

test('the six shapes draw different silhouettes (Épique ≠ Maudit)', () => {
	const seen = new Map();
	for (const [name, shape] of pieces) {
		const key = signature(shape);
		assert(!seen.has(key), `${name} and ${seen.get(key)} are drawn identically`);
		seen.set(key, name);
	}
	// Un anneau sans creux serait un rond, un éclat ou une étoile une seule barre.
	assert(pieces.get('Ring')?.some((p) => p.Hole), 'Ring has no hole');
	assert(pieces.get('Star')?.length >= 2, 'Star is a single bar');
	assert(pieces.get('Burst')?.length >= 2, 'Burst is a single bar');
	assert(pieces.get('Cross')?.length === 2, 'Cross is not an X');
});

test('the mark is drawn with frames, never a glyph or an emoji', () => {
	const markFn = style.match(/function RarityStyle\.mark\([\s\S]*?\nend\n/)?.[0] ?? '';
	assert(markFn.includes('Instance.new("Frame")'), 'RarityStyle.mark builds no Frame');
	assert(!/TextLabel|TextBox|ImageLabel|ImageButton|\bText =/.test(markFn), 'RarityStyle.mark uses a glyph or an image');
	assert(!/[\u{1F000}-\u{1FAFF}]/u.test(theme + style), 'emoji in UITheme or RarityStyle');
	// Aucune vue ne dessine sa propre forme : toutes passent par RarityStyle.
	for (const path of clientFiles) {
		if (path === 'src/client/UI/RarityStyle.lua') continue;
		assert(!read(path).includes('UITheme.RarityMark'), `${path} reads UITheme.RarityMark directly`);
	}
});

test('RarityStyle.chip has one width for every rarity, and an unknown rarity falls back', () => {
	const chip = style.match(/function RarityStyle\.chip\([\s\S]*?\nend\n/)?.[0] ?? '';
	assert(chip.includes('markWidth(MAX_COUNT'), 'chip width is not the common one');
	assert(/MAX_COUNT = math\.max\(MAX_COUNT, spec\.Count\)/.test(style), 'MAX_COUNT is not read from RarityMark');
	assert(
		/\(UITheme\.RarityMark :: any\)\[id or ""\] or UITheme\.RarityMark\.Commun/.test(style),
		'no fallback to the first tier for an unknown rarity',
	);
});

// --- Pourquoi le repère : les paires que la revue signale sont proches en teinte ------------------
const semantic = Object.fromEntries(
	[...(block(theme, 'Colors') ?? '').matchAll(/^\t(\w+) = hex\("(#[0-9A-Fa-f]{6})"\)/gm)].map((m) => [m[1], m[2].toUpperCase()]),
);
function hueOf(hex) {
	const [r, g, b] = [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16) / 255);
	const max = Math.max(r, g, b);
	const min = Math.min(r, g, b);
	if (max === min) return 0;
	const d = max - min;
	const h = max === r ? (g - b) / d + (g < b ? 6 : 0) : max === g ? (b - r) / d + 2 : (r - g) / d + 4;
	return h * 60;
}
const hueGap = (a, b) => {
	const gap = Math.abs(hueOf(a) - hueOf(b)) % 360;
	return gap > 180 ? 360 - gap : gap;
};

test('the pairs named by the review differ by shape, not only by colour', () => {
	const pairs = [
		['Épique', colors.Epique, marks.Epique.shape, 'Maudit', colors.Maudit, marks.Maudit.shape],
		['Calamité', colors.Calamite, marks.Calamite.shape, 'Error', semantic.Error, null],
	];
	for (const [nameA, colorA, shapeA, nameB, colorB, shapeB] of pairs) {
		assert(colorA && colorB, `missing colour for ${nameA} / ${nameB}`);
		const gap = hueGap(colorA, colorB);
		// Règle générale : deux couleurs de même teinte exigent deux formes différentes.
		assert(gap >= 60 || shapeA !== shapeB, `${nameA}/${nameB}: ${gap.toFixed(0)}° of hue and the same shape`);
	}
	assert(marks.Epique.shape !== marks.Maudit.shape, 'Épique and Maudit share a shape');
	assert(hueGap(colors.Epique, colors.Maudit) < 30, 'the review pair Épique/Maudit is no longer close in hue');
	assert(semantic.Error !== undefined && marks.Error === undefined, 'Error must carry no rarity mark');
});

// --- Doc et câblage des deux suites ------------------------------------------------------------
const section = (title, next) => doc.match(new RegExp(`## ${title}([\\s\\S]*?)## ${next}`))?.[1] ?? '';

test('UI_DESIGN_SYSTEM § 9 keeps the RarityMark token', () => {
	const tokens = section('9\\. Tokens Roblox', '10\\.');
	assert(tokens.length > 0, '§ 9 not found');
	assert(/RarityMark = \{ Commun = \{ Shape = "\w+", Count = 1 \}/.test(tokens), 'RarityMark missing from the token list');
});

test('UI_DESIGN_SYSTEM § 11 keeps the colour-alone rule and the grey-scale check', () => {
	const control = section('11\\. Contrôle avant de livrer une interface', '12\\.');
	assert(control.length > 0, '§ 11 not found');
	assert(control.includes('couleur seule'), 'no colour-alone rule');
	assert(control.includes('repère de forme'), 'no shape-mark rule');
	assert(/gris|daltonien/.test(control), 'no grey-scale / colour-blind check');
	assert(/Épique \/ Maudit/.test(control) && /Calamité/.test(control), 'the two confusable pairs are not named');
});

test('docs/SUMMON.md says where the mark is shown', () => {
	const summon = read('docs/SUMMON.md');
	assert(/RarityStyle|UITheme\.RarityMark/.test(summon), 'no RarityStyle / RarityMark reference');
	assert(/repère de\s+forme/.test(summon), 'no shape mark');
	assert(/RarityStyle\.chip|pastille sans texte/.test(summon), 'no chip');
});

test('the Luau spec and its runner stay wired together', () => {
	const spec = read('src/server/Tests/RarityMark.spec.lua');
	const runner = read('tools/test-ui-theme.ps1');
	assert(runner.includes('src/server/Tests/RarityMark.spec.lua'), 'runner does not load the spec');
	assert(runner.includes('docs/UI_DESIGN_SYSTEM.md'), 'runner gives no doc text');
	assert(runner.includes('src/client/UI/RarityStyle.lua'), 'runner gives no RarityStyle text');
	for (const rule of [
		'every RarityConfig tier has a mark',
		'every (shape, count) pair is unique',
		'a shape covers consecutive tiers',
		'marks are frozen',
		'UI_DESIGN_SYSTEM § 2 table matches RarityMark',
	]) {
		assert(spec.includes(rule), `Luau spec no longer checks "${rule}"`);
	}
	// Le spec Luau lit les formes dans la source de RarityStyle (motifs Lua) : mêmes entrées, même résultat.
	const luauBlock = style.match(/local SHAPES[^\n]*\n([\s\S]*?)\n}/)?.[1] ?? '';
	const luauKeys = luauBlock
		.split('\n')
		.map((line) => line.match(/^\s*(\w+)\s*=\s*\{/)?.[1])
		.filter(Boolean);
	assert(new Set(luauKeys).size === shapes.size, `the Luau spec would read ${luauKeys.length} shapes, ${shapes.size} expected`);
	// Le motif de doc du spec Luau doit encore trouver les dix lignes du tableau du § 2.
	const table = doc.match(/\| Rareté \| Couleur \| Repère[^\n]*\n\|[^\n]*\n((?:\|[^\n]*\n)+)/)?.[1] ?? '';
	const found = new Map();
	for (const line of table.split('\n')) {
		const row = line.match(/^\| ([^|]*?) \|(.*)\| (\d [^|]*?) \|$/); // même motif que le spec
		if (row) found.set(row[1], row[3].trim());
	}
	for (const t of tiers) {
		const cell = found.get(t.name);
		assert(cell, `Luau spec finds no doc row for ${t.name}`);
		assert(Number(cell[0]) === marks[t.id].count, `${t.name}: Luau would read "${cell}"`);
	}
});

console.log(`RarityMark (node): ${passed} passed, ${failed} failed`);
if (failed > 0) process.exit(1);
