// Contrôle hors Studio des règles arbitrées du rendu des raretés (docs/UI_DESIGN_SYSTEM.md § 2,
// « Rendu des raretés »), sans Luau : `node tests/rarity-rules.test.mjs`. Lecture seule. Vérifie :
//   - qu'aucune vue client ne lit UITheme.Rarity / RarityPrism / RarityMark hors de RarityStyle (règle 3) ;
//   - que les tokens au même hex qu'une rareté mais d'un autre sens existent dans UITheme.Colors ;
//   - que la doc garde les sept règles, le point 8 du § 11 et le plan de revue docs/RARITY_REVIEW.md ;
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

test('monsters and resources carry no rarity', () => {
	assert(!/Rarity|Rarete/.test(stripComments(read('src/shared/Config/ResourceConfig.lua'))), 'rarity field in ResourceConfig');
	assert(!/Rarity|Rarete/.test(stripComments(read('src/shared/Config/EnemyPresentationConfig.lua'))), 'rarity field in EnemyPresentationConfig');
});

console.log(`Rarity rules (node): ${passed} passed, ${failed} failed`);
if (failed > 0) process.exit(1);
