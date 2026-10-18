// Menu principal : MenuIconConfig est la seule source des AssetIds du menu, alignée sur TutorialConfig.
// node --test tests/
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('..', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');
const read = (path) => readFileSync(join(root, path), 'utf8');

const iconConfig = read('src/shared/Config/MenuIconConfig.lua');
const tutorialConfig = read('src/shared/Config/TutorialConfig.lua');

// { Shop: { Icon, BadgeIcon }, ... } lu dans le source Luau
function icons() {
	const map = {};
	for (const [, id, body] of iconConfig.matchAll(/^\t(\w+) = \{\n([\s\S]*?)\n\t\},/gm)) {
		const field = (name) => (body.match(new RegExp(`${name} = "([^"]*)"`)) ?? [])[1];
		map[id] = { Icon: field('Icon'), BadgeIcon: field('BadgeIcon') };
	}
	return map;
}

function menuIds() {
	return [...tutorialConfig.matchAll(/\{ Id = "(\w+)", Label = "[^"]+", View = /g)].map((m) => m[1]);
}

test('MenuIconConfig: one entry per menu button (TutorialConfig.Menu.Entries), same ids', () => {
	assert.deepEqual(Object.keys(icons()).sort(), menuIds().sort());
	assert.deepEqual(menuIds(), ['Shop', 'Bag', 'Index', 'Guild', 'Stats']);
});

test('MenuIconConfig: every icon is a real rbxassetid (or explicitly empty), never 0, all distinct', () => {
	const seen = new Set();
	for (const [id, entry] of Object.entries(icons())) {
		for (const field of ['Icon', 'BadgeIcon']) {
			const value = entry[field];
			assert.notEqual(value, undefined, `${id}.${field} missing`);
			if (value === '') continue;
			assert.match(value, /^rbxassetid:\/\/[1-9]\d{5,}$/, `${id}.${field} = ${value}`);
			assert.ok(!seen.has(value), `${id}.${field} duplicated`);
			seen.add(value);
		}
		assert.notEqual(entry.Icon, '', `${id}: normal icon required`);
	}
});

test('no menu AssetId outside MenuIconConfig (controllers and views read the config)', () => {
	const ids = Object.values(icons()).flatMap((e) => [e.Icon, e.BadgeIcon]).filter(Boolean).map((v) => v.replace('rbxassetid://', ''));
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
		if (file.replace(/\\/g, '/').endsWith('Config/MenuIconConfig.lua')) continue;
		const source = read(file);
		for (const id of ids) assert.ok(!source.includes(id), `${file} contains menu asset ${id}`);
	}
});
