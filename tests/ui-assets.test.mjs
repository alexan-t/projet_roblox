// Pack visuel validé : MenuIconConfig et CurrencyVisualConfig sont les SEULES sources des AssetIds du
// menu et des monnaies ; alignées sur TutorialConfig (menu) et sur les clés de récompense / PlayerData.
// node --test tests/
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('..', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');
const read = (path) => readFileSync(join(root, path), 'utf8').replace(/\r\n/g, '\n');

const iconConfig = read('src/shared/Config/MenuIconConfig.lua');
const currencyConfig = read('src/shared/Config/CurrencyVisualConfig.lua');
const tutorialConfig = read('src/shared/Config/TutorialConfig.lua');
const ASSET = /^rbxassetid:\/\/[1-9]\d{5,}$/;

// blocs « <indent><Id> = {\n ... \n<indent>}, » : boutons du menu (2 tabulations) ou monnaies (1 tabulation)
function blocks(source, indent) {
	const map = {};
	const re = new RegExp(`^${indent}(\\w+) = \\{\\n([\\s\\S]*?)\\n${indent}\\},`, 'gm');
	for (const [, id, body] of source.matchAll(re)) {
		const field = (name) => (body.match(new RegExp(`\\b${name} = "([^"]*)"`)) ?? [])[1];
		map[id] = { body, field };
	}
	return map;
}

const menuButtons = () => blocks(iconConfig, '\t\t');
const currencies = () => blocks(currencyConfig, '\t');
const menuIds = () => [...tutorialConfig.matchAll(/\{ Id = "(\w+)", Label = "[^"]+", View = /g)].map((m) => m[1]);

test('menu: six entries (2 columns x 3 rows) in the mockup order, one icon config each', () => {
	assert.deepEqual(menuIds(), ['Shop', 'Bag', 'Index', 'Guild', 'Stats', 'Quest']);
	assert.deepEqual(Object.keys(menuButtons()).sort(), [...menuIds()].sort());
});

test('menu: normal + badge variant per button and the shared "!" (badge.png), real asset ids', () => {
	for (const [id, { field }] of Object.entries(menuButtons())) {
		assert.match(field('Icon') ?? '', ASSET, `${id}.Icon`);
		assert.match(field('BadgeIcon') ?? '', ASSET, `${id}.BadgeIcon`);
	}
	const badge = (iconConfig.match(/^\tBadge = "([^"]*)"/m) ?? [])[1];
	assert.match(badge ?? '', ASSET, 'Badge (badge.png)');
});

test('currencies: Gold / Gems / SummonTicket with Small, Normal, Glow, a 3D model and the PlayerData key', () => {
	const map = currencies();
	assert.deepEqual(Object.keys(map).sort(), ['Gems', 'Gold', 'SummonTicket']);
	const expected = { Gold: ['Gold', 'Gold'], Gems: ['Gems', 'Gems'], SummonTicket: ['SummonTicket', 'SummonTickets'] };
	for (const [kind, { field }] of Object.entries(map)) {
		for (const name of ['Small', 'Normal', 'Glow']) assert.match(field(name) ?? '', ASSET, `${kind}.${name}`);
		assert.equal(field('Model'), expected[kind][0], `${kind}.Model (ReplicatedStorage.Assets.Currencies)`);
		assert.equal(field('Currency'), expected[kind][1], `${kind}.Currency (PlayerData.Currencies key)`);
	}
	assert.match(currencyConfig, /Order = \{ "Gold", "Gems", "SummonTicket" \}/, 'HUD order: Or, Gemme, Ticket');
});

test('every pack asset id is distinct (no PNG published twice under two names)', () => {
	const all = [...iconConfig.matchAll(/"(rbxassetid:\/\/\d+)"/g), ...currencyConfig.matchAll(/"(rbxassetid:\/\/\d+)"/g)].map((m) => m[1]);
	assert.equal(new Set(all).size, all.length, all.join(', '));
	assert.equal(all.length, 6 * 2 + 1 + 3 * 3);
});

test('no pack asset id outside its config (controllers and views read the configs)', () => {
	const ids = [...iconConfig.matchAll(/rbxassetid:\/\/(\d+)/g), ...currencyConfig.matchAll(/rbxassetid:\/\/(\d+)/g)].map((m) => m[1]);
	const files = [];
	const walk = (dir) => {
		for (const name of readdirSync(join(root, dir))) {
			const path = join(dir, name);
			if (statSync(join(root, path)).isDirectory()) walk(path);
			else if (path.endsWith('.lua') || path.endsWith('.luau')) files.push(path);
		}
	};
	walk('src');
	for (const file of files) {
		const normalized = file.replace(/\\/g, '/');
		if (normalized.endsWith('Config/MenuIconConfig.lua') || normalized.endsWith('Config/CurrencyVisualConfig.lua')) continue;
		const source = read(file);
		for (const id of ids) assert.ok(!source.includes(id), `${file} contains pack asset ${id}`);
	}
});
