// Contrôle des armes des héros (docs/HEROES_QA.md) : le script Studio en lecture seule
// tools/studio-check-heroes.luau attend les mêmes poses d'épée qu'AnimationKit (styles Epee et Rempart)
// et le même instant d'impact que l'ultime. Si l'un change sans l'autre, ce test casse.
// node --test tests/heroes-weapons.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('..', import.meta.url));
const read = (path) => readFileSync(join(root, path), 'utf8').replace(/\r\n/g, '\n');

const kit = read('tools/animation/AnimationKit.luau');
const check = read('tools/studio-check-heroes.luau');
const ultimate = read('src/client/Controllers/UltimateEffectController.lua');
const heroConfig = read('src/shared/Config/HeroConfig.lua');
const skeletonConfig = read('src/shared/Config/SkeletonConfig.lua');
const qa = read('docs/HEROES_QA.md');

const numbers = (text) => text.split(',').map((value) => Number(value.trim()));

// Style d'AnimationKit : Impact et, pour chaque clé, le temps et weaponRight (0, 0, 0 si absent).
function kitStyle(name) {
	const block = (kit.match(new RegExp(`\\n\\t${name} = \\{\\n([\\s\\S]*?)\\n\\t\\},`)) ?? [])[1];
	assert.ok(block, `Kit.Attacks.${name} introuvable`);
	const impact = Number(block.match(/Impact = ([\d.]+)/)[1]);
	const keys = block.split('{ Time = ').slice(1).map((chunk) => {
		const weapon = chunk.match(/weaponRight = \{ ([-\d., ]+) \}/);
		return [Number(chunk.match(/^([\d.]+)/)[1]), weapon ? numbers(weapon[1]) : [0, 0, 0]];
	});
	return { impact, keys };
}

// Table du script Studio : local NOM = { Impact = x, Keys = { { t, { rx, ry, rz } }, ... } }.
function checkStyle(name) {
	const block = (check.match(new RegExp(`\\nlocal ${name} = \\{\\n([\\s\\S]*?)\\n\\}`)) ?? [])[1];
	assert.ok(block, `${name} introuvable dans le script Studio`);
	const impact = Number(block.match(/Impact = ([\d.]+)/)[1]);
	const keys = [...block.matchAll(/\{ ([\d.]+), \{ ([-\d., ]+) \} \}/g)].map((m) => [Number(m[1]), numbers(m[2])]);
	return { impact, keys };
}

test('the Studio check is read-only and returns the number of problems', () => {
	assert.match(check, /^--!strict\n/);
	assert.match(check, /Lecture seule, ne modifie rien/);
	for (const forbidden of [/:SetAttribute\(/, /Instance\.new\(/, /:Destroy\(/, /\.Parent\s*=/, /ChangeHistoryService/, /\.CFrame\s*=/, /\.Transform\s*=/]) {
		assert.doesNotMatch(check, forbidden, String(forbidden));
	}
	assert.match(check, /\nreturn #problems\n?$/);
});

test('sword poses of the Studio check match AnimationKit (Epee and Rempart)', () => {
	for (const [kitName, checkName] of [['Epee', 'EPEE'], ['Rempart', 'REMPART']]) {
		assert.deepEqual(checkStyle(checkName), kitStyle(kitName), `${kitName} / ${checkName}`);
	}
});

test('the fixed sword poses are present at impact and after (blade out of the shield, thrust forward)', () => {
	const epee = kitStyle('Epee');
	const rempart = kitStyle('Rempart');
	const at = (style, time) => style.keys.find(([t]) => t === time)?.[1];
	assert.deepEqual(at(epee, epee.impact), [0, -20, 30]);
	assert.deepEqual(at(epee, 0.3), [0, -40, 0]);
	assert.deepEqual(at(rempart, 0.15), [50, -20, 0]);
	assert.deepEqual(at(rempart, rempart.impact), [-30, -60, 10]);
	assert.deepEqual(at(rempart, 0.5), [-30, -60, 10]);
	// Début et fin neutres : l'animation repart de la pose de repos de l'arme.
	for (const style of [epee, rempart]) {
		assert.deepEqual(style.keys[0][1], [0, 0, 0]);
		assert.deepEqual(style.keys.at(-1)[1], [0, 0, 0]);
	}
});

test('the ultimate impact of AnimationKit equals ANIMATION_IMPACT of UltimateEffectController', () => {
	const impact = Number(ultimate.match(/local ANIMATION_IMPACT = ([\d.]+)/)[1]);
	assert.equal(kitStyle('Rempart').impact, impact);
});

test('the Écuyer is the animated hero and its sword is ArmeDroite (short_sword_geom)', () => {
	assert.match(heroConfig, /hero\("ecuyer_du_rempart", "Écuyer du Rempart", "Commun", "Epeiste", "Heros_EcuyerDuRempart"\)/);
	assert.match(skeletonConfig, /short_sword_geom/);
	assert.match(skeletonConfig, /ArmeDroite/);
	assert.match(check, /FindFirstChild\("short_sword_geom", true\)/);
});

test('the corrected heroes checked in Studio exist in HeroConfig and in the QA report', () => {
	const corrected = [
		['Socle_25', 'PretresseAuxLucioles', 'pretresse_aux_lucioles', '#25 Prêtresse aux Lucioles'],
		['Socle_47', 'TisseurDeDestins', 'tisseur_de_destins', '#47 Tisseur de Destins'],
		['Socle_58', 'ReineDuFirmamentDore', 'reine_du_firmament_dore', '#58 Reine du Firmament Doré'],
		['Socle_01', 'EcuyerDuRempart', 'ecuyer_du_rempart', '#01 Écuyer du Rempart'],
	];
	for (const [socle, model, id, label] of corrected) {
		assert.match(check, new RegExp(`\\{ "${socle}", "${model}", "[\\w.]+", [\\d.]+ \\}`), `${model} dans TENUS`);
		assert.match(heroConfig, new RegExp(`hero\\("${id}",`), `${id} dans HeroConfig`);
		assert.ok(qa.includes(label), `${label} dans docs/HEROES_QA.md`);
	}
	// Une arme tenue au poing ne tolère aucun écart ; seul le bouclier (poignée) a une marge.
	const tolerances = [...check.matchAll(/\{ "Socle_\d+", "\w+", "([\w.]+)", ([\d.]+) \}/g)];
	for (const [, path, tolerance] of tolerances) {
		assert.equal(Number(tolerance), path.startsWith('shield.') ? 0.2 : 0, path);
	}
});

test('the QA report points to the Studio check and keeps the drafts as known FIX', () => {
	assert.match(qa, /tools\/studio-check-heroes\.luau/);
	assert.match(qa, /\*\*Verdict global : FIX\.\*\*/);
	assert.match(check, /BROUILLONS = \{ Socle_10 = true, Socle_11 = true \}/);
	assert.match(qa, /#10 et #11/);
});
