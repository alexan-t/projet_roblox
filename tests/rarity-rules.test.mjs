// Contrôle hors Studio des règles arbitrées du rendu des raretés (docs/UI_DESIGN_SYSTEM.md § 2,
// « Rendu des raretés »), sans Luau : `node tests/rarity-rules.test.mjs`. Lecture seule. Vérifie :
//   - une seule palette, calée sur les paliers de RarityConfig, et des items sur ces paliers (règle 1) ;
//   - qu'une vue qui montre une couleur de rareté montre aussi son libellé ou son repère (règle 2) ;
//   - qu'aucune vue client ne lit UITheme.Rarity / RarityPrism / RarityMark hors de RarityStyle (règle 3) ;
//   - que les tokens au même hex qu'une rareté mais d'un autre sens existent dans UITheme.Colors ;
//   - que les écrans Invocation V2 n'ajoutent pas de badge de rareté (règle 5) ;
//   - qu'ITEMS.md interdit toujours la couleur de rareté dans l'icône (règle 6) ;
//   - que la doc garde les sept règles, le point 8 du § 11, le plan docs/RARITY_REVIEW.md et une
//     ligne « État au » à jour (repère de forme présent ou non dans RarityStyle) ;
//   - qu'aucune rareté n'apparaît côté monstres ni ressources (règle 1).
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

function luaFiles(dir) {
	const out = [];
	for (const name of readdirSync(join(repoRoot, dir))) {
		const path = join(dir, name);
		if (statSync(join(repoRoot, path)).isDirectory()) out.push(...luaFiles(path));
		else if (/\.luau?$/.test(name)) out.push(relative(repoRoot, join(repoRoot, path)).replace(/\\/g, '/'));
	}
	return out;
}
const stripComments = (source) => source.replace(/--\[(=*)\[[\s\S]*?\]\1\]/g, '').replace(/--.*$/gm, '');

const theme = read('src/shared/Config/UITheme.lua');
const doc = read('docs/UI_DESIGN_SYSTEM.md');
const hexOf = (block, key) => block.match(new RegExp(`^\\t${key} = hex\\("(#[0-9A-Fa-f]{6})"\\)`, 'm'))?.[1]?.toUpperCase();
const colors = theme.match(/local Colors = \{([\s\S]*?)\n\}/)?.[1] ?? '';
const rarity = theme.match(/local Rarity = \{([\s\S]*?)\n\}/)?.[1] ?? '';

test('no client file reads UITheme.Rarity, RarityPrism or RarityMark outside RarityStyle', () => {
	for (const path of luaFiles('src/client')) {
		if (path === 'src/client/UI/RarityStyle.lua') continue;
		const code = stripComments(read(path));
		const hit = code.match(/\b\w+\.(Rarity|RarityPrism|RarityMark)\b(?!\s*=)/g)?.filter((m) => /^(UITheme|Theme)\./.test(m));
		assert(!hit?.length, `${path} reads ${hit?.join(', ')} directly (use RarityStyle)`);
	}
});

test('colours that share a rarity hex but mean something else have their own token', () => {
	assert(colors.length > 0 && rarity.length > 0, 'Colors or Rarity block not found in UITheme');
	assert(hexOf(colors, 'DropChanceLow') === hexOf(rarity, 'Epique'), 'DropChanceLow must keep the Expédition maquette hex');
	assert(hexOf(colors, 'Guarantee') === hexOf(rarity, 'Maudit'), 'Guarantee must keep the Invocation V2 hex');
	assert(read('src/client/UI/Views/ExpeditionView.lua').includes('C.DropChanceLow'), 'ExpeditionView no longer uses DropChanceLow');
	assert(read('src/client/UI/Views/SummonLayout.lua').includes('C.Guarantee'), 'SummonLayout no longer uses Guarantee');
});

test('UI_DESIGN_SYSTEM § 2 keeps the seven arbitrated rules', () => {
	const section = doc.match(/### Rendu des raretés : règles arbitrées[^\n]*\n([\s\S]*?)\n## 3\./)?.[1] ?? '';
	assert(section.length > 0, 'section « Rendu des raretés » not found in § 2');
	for (const n of [1, 2, 3, 4, 5, 6, 7]) assert(new RegExp(`^${n}\\. \\*\\*`, 'm').test(section), `rule ${n} missing`);
	for (const pr of ['#61', '#62', '#75', '#80']) assert(section.includes(pr), `${pr} not named`);
	assert(section.includes('docs/RARITY_REVIEW.md'), 'no link to the review plan');
	assert(/couleur n'est jamais seule/.test(section), 'colour-alone rule missing');
	assert(/jamais dans l'icône/.test(section), 'item icon rule missing');
});

test('UI_DESIGN_SYSTEM § 11 keeps the colour-alone check', () => {
	const control = doc.match(/## 11\. Contrôle avant de livrer une interface([\s\S]*?)## 12\./)?.[1] ?? '';
	assert(control.includes('couleur seule'), 'no colour-alone rule');
	assert(control.includes('repère de forme'), 'no shape-mark rule');
	assert(/gris|daltonien/.test(control), 'no grey-scale check');
	assert(/Épique \/ Maudit/.test(control) && /Calamité/.test(control), 'the two confusable pairs are not named');
});

test('docs/RARITY_REVIEW.md gives an order and a checklist for each PR', () => {
	const plan = read('docs/RARITY_REVIEW.md');
	for (const pr of ['#75', '#61', '#62', '#65']) assert(new RegExp(`^### ${pr} `, 'm').test(plan), `no checklist for ${pr}`);
	const order = plan.match(/## Ordre de revue et de fusion([\s\S]*?)\n## /)?.[1] ?? '';
	const at = (pr) => order.indexOf(`**${pr}**`);
	assert(at('#75') >= 0 && at('#61') > at('#75'), '#61 must come after #75 (it needs RarityStyle.chip)');
});

const tierIds = [...read('src/shared/Config/RarityConfig.lua').matchAll(/\{ Id = "(\w+)", Name = "[^"]+", Weight = \d+ \}/g)].map((m) => m[1]);
// Fichiers client qui requièrent RarityStyle, avec l'alias local utilisé (« Rarity », « RarityStyle »…).
const rarityStyleUsers = luaFiles('src/client')
	.filter((path) => path !== 'src/client/UI/RarityStyle.lua')
	.map((path) => ({ path, code: stripComments(read(path)) }))
	.map((file) => ({ ...file, alias: file.code.match(/local (\w+) = require\([^)]*RarityStyle\)/)?.[1] }))
	.filter((file) => file.alias);
const calls = (file, names) => file.code.match(new RegExp(`\\b${file.alias}\\.(${names})\\(`, 'g')) ?? [];

test('rule 1: one palette, exactly on the RarityConfig tiers', () => {
	assert(tierIds.length === 10, `expected 10 tiers in RarityConfig, found ${tierIds.length}`);
	const keys = [...rarity.matchAll(/^\t(\w+) = hex\(/gm)].map((m) => m[1]);
	assert(keys.join(',') === tierIds.join(','), `UITheme.Rarity keys (${keys.join(', ')}) differ from RarityConfig (${tierIds.join(', ')})`);
	const palettes = [...theme.matchAll(/^local (\w*Rarit\w*) = /gm)].map((m) => m[1]);
	const extra = palettes.filter((name) => !['Rarity', 'RarityPrism', 'RarityMark'].includes(name));
	assert(!extra.length, `second rarity palette in UITheme: ${extra.join(', ')}`);
	const prism = theme.match(/^local RarityPrism = \{([^\n]*)\}/m)?.[1] ?? '';
	assert((prism.match(/hex\("#[0-9A-Fa-f]{6}"\)/g) ?? []).length >= 2, 'RarityPrism needs at least two colours');
});

test('rule 1: every item uses an existing RarityConfig tier', () => {
	const items = [...stripComments(read('src/shared/Config/ItemConfig.lua')).matchAll(/^item\("(\w+)", "[^"]+", "(\w+)"/gm)];
	assert(items.length > 0, 'no item(...) line found in ItemConfig');
	const unknown = items.filter((m) => !tierIds.includes(m[2])).map((m) => `${m[1]} (${m[2]})`);
	assert(!unknown.length, `items with an unknown rarity: ${unknown.join(', ')}`);
});

test('rule 2: a file that shows a rarity colour also shows its label or shape mark', () => {
	assert(rarityStyleUsers.length > 0, 'no client file requires RarityStyle');
	for (const file of rarityStyleUsers) {
		if (!calls(file, 'color|colorAt|sequence|paint|prism').length) continue;
		assert(calls(file, 'name|badge|edgeBadge|mark|chip').length, `${file.path} shows a rarity colour without its label or mark`);
	}
});

test('rule 5: Invocation V2 screens add no rarity badge on top of the maquette', () => {
	const v2 = ['src/client/UI/HeroCard.lua', 'src/client/UI/Views/SummonView.lua', 'src/client/UI/Views/SummonLayout.lua', 'src/client/UI/Views/SummonReveal.lua'];
	for (const path of v2) {
		const file = rarityStyleUsers.find((f) => f.path === path);
		assert(file, `${path} no longer reads the rarity through RarityStyle`);
		const hit = calls(file, 'badge|edgeBadge');
		assert(!hit.length, `${path} adds ${hit.join(', ')} (rarity is carried by the rank frames and the label)`);
	}
});

test('rule 6: item icons stay free of rarity colour', () => {
	assert(/Aucune couleur de rareté[^\n]*dans l'image/.test(read('docs/ITEMS.md')), 'ITEMS.md § 5 no longer forbids rarity colour in the icon');
});

test('§ 2 status line matches RarityStyle (shape mark lands with #75)', () => {
	const style = stripComments(read('src/client/UI/RarityStyle.lua'));
	const hasMark = /function RarityStyle\.(mark|chip)\(/.test(style);
	const status = doc.match(/^État au [^\n]*\n(?:[^\n]+\n)*/m)?.[0] ?? '';
	assert(status.length > 0, 'status line « État au … » not found in § 2');
	if (hasMark) assert(!/arrive avec #75/.test(status), 'RarityStyle has mark/chip: update the « État au » line of § 2');
	else assert(/#75/.test(status), 'status line must say the shape mark is still waiting for #75');
});

test('monsters and resources carry no rarity', () => {
	assert(!/Rarity|Rarete/.test(stripComments(read('src/shared/Config/ResourceConfig.lua'))), 'rarity field in ResourceConfig');
	assert(!/Rarity|Rarete/.test(stripComments(read('src/shared/Config/EnemyPresentationConfig.lua'))), 'rarity field in EnemyPresentationConfig');
});

console.log(`Rarity rules (node): ${passed} passed, ${failed} failed`);
if (failed > 0) process.exit(1);
