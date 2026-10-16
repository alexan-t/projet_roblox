// Hors Studio : node --test tests/ui-effects.test.mjs
// Contrats de source ; ne remplace pas le contrôle visuel dans Studio.
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import assert from 'node:assert/strict';

const read = (path) => readFileSync(new URL(`../${path}`, import.meta.url), 'utf8')
  .replace(/\r\n/g, '\n').replace(/--\[\[[\s\S]*?\]\]/g, '').replace(/--[^\n]*/g, '');
const theme = read('src/shared/Config/UITheme.lua');
const groups = ['CombatIntro', 'Ultimate', 'Reward', 'Summon'];
const files = ['CombatIntroController', 'UltimateEffectController', 'RewardScreenController', 'SummonEffectController'];
const sources = Object.fromEntries(groups.map((group, i) => [group, read(`src/client/Controllers/${files[i]}.lua`)]));
const tokens = Object.fromEntries(groups.map(group => {
  const block = theme.match(new RegExp(`\\b${group} = table\\.freeze\\(\\{([\\s\\S]*?)\\}\\)`));
  assert.ok(block, `groupe figé manquant : ${group}`);
  return [group, Object.fromEntries([...block[1].matchAll(/(\w+)\s*=\s*([\d.]+)/g)]
    .map(([, key, value]) => [key, Number(value)]))];
}));
const palette = new Set([...theme.match(/local Colors = \{([\s\S]*?)\n\}/)[1].matchAll(/(\w+)\s*=\s*hex\(/g)].map(m => m[1]));

test('les tokens sont exportés et leurs groupes sont immuables', () => {
  assert.match(theme, /local Effects = table\.freeze\(/);
  assert.match(theme, /Effects = Effects/);
  assert.match(theme, /return table\.freeze\(UITheme\)/);
  for (const [group, values] of Object.entries(tokens)) {
    assert.ok(Object.keys(values).length > 0, group);
    for (const [key, value] of Object.entries(values)) assert.ok(Number.isFinite(value) && value > 0, `${group}.${key}`);
  }
});

for (const group of groups) {
  const source = sources[group];
  test(`${group} : chaque référence Effects existe dans son groupe`, () => {
    assert.match(source, new RegExp(`local Effects = UITheme\\.Effects\\.${group}\\b`));
    const refs = [...source.matchAll(/(?<![\w.])Effects\.(\w+)/g)].map(m => m[1]);
    assert.ok(refs.length > 0);
    for (const key of refs) assert.ok(Object.hasOwn(tokens[group], key), `${group}.${key} absent`);
  });
  test(`${group} : couleurs issues de la palette, sans constructeur local`, () => {
    assert.doesNotMatch(source, /\bColor3\.(?:new|fromRGB|fromHSV|fromHex)\s*\(/);
    const refs = [...source.matchAll(/\b(?:UITheme\.)?Colors\.(\w+)/g)];
    assert.ok(refs.length > 0);
    for (const [, key] of refs) assert.ok(palette.has(key), `couleur inconnue : ${key}`);
  });
  test(`${group} : aucun délai, tween ou temps de particules littéral`, () => {
    assert.doesNotMatch(source, /\b(?:TweenInfo\.new|task\.(?:wait|delay))\s*\(\s*\d/);
    assert.doesNotMatch(source, /\bLifetime\s*=\s*NumberRange\.new\s*\(\s*\d/);
    assert.doesNotMatch(source, /\blocal\s+\w*(?:TIME|DELAY|DURATION|CHARGE|FLIGHT|REVEAL)\w*\s*=\s*\d/);
  });
}

test('impact ultime : délai commun aux visuels, dégâts et audio, compatible x1/x2', () => {
  const s = sources.Ultimate;
  assert.match(s, /local ANIMATION_IMPACT = Effects\.AnimationImpact/);
  assert.match(s, /local TRAVEL_TIME = Effects\.Travel/);
  assert.match(s, /IMPACT_DELAY = ANIMATION_IMPACT \+ TRAVEL_TIME/);
  assert.match(s, /return UltimateEffectController\.IMPACT_DELAY \/ \(speed or 1\)/);
  assert.match(s, /Delay = UltimateEffectController\.ImpactDelay\(scale\)/);
  assert.match(s, /task\.delay\(ANIMATION_IMPACT \/ scale/);
  assert.ok(Math.abs(tokens.Ultimate.AnimationImpact + tokens.Ultimate.Travel - 0.45) < 1e-9);
});

test('invocation : charge par rang et callback après révélation conservés', () => {
  const s = sources.Summon;
  for (const [alias, token] of [['CHARGE', 'Charge'], ['FLIGHT', 'Flight'], ['REVEAL', 'Reveal']]) {
    assert.match(s, new RegExp(`local ${alias} = Effects\\.${token}\\b`));
  }
  assert.match(s, /return CHARGE \+ Effects\.ChargePerRank \* \(rank - 1\)/);
  assert.match(s, /return chargeOf\(rankOf\(rarity\)\) \+ FLIGHT \+ REVEAL/);
  assert.match(s, /task\.delay\(REVEAL, onRevealed\)/);
  assert.equal(tokens.Summon.Charge, 1.2);
  assert.equal(tokens.Summon.ChargePerRank, 0.2);
  assert.equal(tokens.Summon.Flight, 0.45);
  assert.equal(tokens.Summon.Reveal, 0.6);
});

test('récompenses : les 14 s restent une rotation infinie indépendante de Continuer', () => {
  assert.equal(tokens.Reward.RaysPeriod, 14);
  assert.match(sources.Reward, /TweenInfo\.new\(Effects\.RaysPeriod, Enum\.EasingStyle\.Linear, Enum\.EasingDirection\.InOut, -1\)/);
  assert.match(sources.Reward, /task\.delay\(Animation\.Close\.Time, onContinue\)/);
  assert.doesNotMatch(sources.Reward, /task\.(?:wait|delay)\(Effects\.RaysPeriod/);
});
