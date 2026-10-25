// Contrôles Studio de reprise des zones (docs/ZONES_QA.md § Reprise) : les deux scripts en lecture seule
// lisent les mêmes noms et attributs que le code serveur. Si l'un change, ce test casse avant le test manuel.
// node --test tests/zones-studio-checks.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('..', import.meta.url));
const read = (path) => readFileSync(join(root, path), 'utf8').replace(/\r\n/g, '\n');

const menuCheck = read('tools/studio-check-menu-icons.luau');
const playersCheck = read('tools/studio-check-two-players.luau');
const iconConfig = read('src/shared/Config/MenuIconConfig.lua');
const qa = read('docs/ZONES_QA.md');

// Les trois images que le propriétaire doit débloquer (quest.png, shop.png, bag.png).
const BLOCKED = { Quest: '74149875739571', Shop: '99196320622532', Bag: '136778535271316' };

test('both Studio checks are read-only (no write, no Instance.new, no Destroy)', () => {
	for (const [name, source] of [['menu-icons', menuCheck], ['two-players', playersCheck]]) {
		assert.match(source, /^--!strict\n/, `${name}: --!strict`);
		assert.match(source, /Lecture seule|lecture seule/, `${name}: annoncé en lecture seule`);
		for (const forbidden of [/:SetAttribute\(/, /Instance\.new\(/, /:Destroy\(/, /\.Parent\s*=/, /ChangeHistoryService/]) {
			assert.doesNotMatch(source, forbidden, `${name}: ${forbidden}`);
		}
		assert.match(source, /\nreturn #\w+\n?$/, `${name}: renvoie le nombre de problèmes (0 = PASS)`);
	}
});

test('menu icons check reads MenuIconConfig (Badge + Icon/BadgeIcon per button = 13 images)', () => {
	assert.match(menuCheck, /require\(game\.ReplicatedStorage\.Shared\.Config\.MenuIconConfig\)/);
	assert.match(menuCheck, /config\.Badge\b/);
	assert.match(menuCheck, /for button, icons in config\.Buttons do/);
	assert.match(menuCheck, /icons\.Icon\b/);
	assert.match(menuCheck, /icons\.BadgeIcon\b/);
	assert.match(menuCheck, /ContentProvider:PreloadAsync/);
	assert.match(menuCheck, /Enum\.AssetFetchStatus\.Success/);
	const ids = [...iconConfig.matchAll(/"rbxassetid:\/\/(\d+)"/g)].map((m) => m[1]);
	assert.equal(ids.length, 13, 'docs/ZONES_QA.md attend « 13/13 lisibles »');
	assert.match(qa, /13\/13 lisibles/);
});

test('the three blocked images are still the ones in MenuIconConfig and in the QA doc', () => {
	for (const [button, id] of Object.entries(BLOCKED)) {
		const block = (iconConfig.match(new RegExp(`\\t\\t${button} = \\{\\n([\\s\\S]*?)\\n\\t\\t\\},`)) ?? [])[1] ?? '';
		assert.match(block, new RegExp(`Icon = "rbxassetid://${id}"`), `${button}.Icon`);
		assert.ok(qa.includes(`\`${id}\``), `${id} cité dans docs/ZONES_QA.md`);
	}
});

test('two players check uses the plot contract (Workspace.Lobby.Plots, OwnerUserId, Arene.Zones)', () => {
	const plotConfig = read('src/server/Config/PlotConfig.lua');
	const arenaConfig = read('src/shared/Config/ArenaConfig.lua');
	const plotService = read('src/server/Services/PlotService.lua');
	assert.match(plotConfig, /PlotsFolder = table\.freeze\(\{ "Lobby", "Plots" \}\)/);
	assert.match(playersCheck, /workspace:FindFirstChild\("Lobby"\)/);
	assert.match(playersCheck, /lobby:FindFirstChild\("Plots"\)/);
	assert.match(plotService, /:SetAttribute\("OwnerUserId", player\.UserId\)/);
	assert.match(playersCheck, /GetAttribute\("OwnerUserId"\) == player\.UserId/);
	assert.match(arenaConfig, /ArenaName = "Arene"/);
	assert.match(playersCheck, /plot:FindFirstChild\("Arene"\)/);
	assert.match(read('src/server/Arena/ZoneDecor.lua'), /FindFirstChild\("Zones"\)/);
	assert.match(playersCheck, /arena:FindFirstChild\("Zones"\)/);
	assert.match(playersCheck, /GetAttribute\("ZoneId"\)/);
});

test('two players check uses the combat attributes set by the server (DataLoaded, CombatId, Alive)', () => {
	assert.match(read('src/server/Services/DataService.lua'), /SetAttribute\("DataLoaded", true\)/);
	assert.match(playersCheck, /GetAttribute\("DataLoaded"\) == true/);
	const combat = read('src/server/Services/CombatService.lua');
	assert.match(combat, /model:SetAttribute\("CombatId", session\.id\)/);
	assert.match(combat, /model:SetAttribute\("Alive", false\)/);
	assert.match(playersCheck, /GetAttribute\("CombatId"\)/);
	assert.match(playersCheck, /GetAttribute\("Alive"\) ~= false/);
	assert.match(playersCheck, /#players >= 2/);
	assert.match(playersCheck, /"Deux joueurs : PASS"/);
	assert.match(qa, /Deux joueurs : PASS/);
});

test('the QA doc points to both checks and keeps the honest verdict until the manual steps are done', () => {
	assert.match(qa, /tools\/studio-check-menu-icons\.luau/);
	assert.match(qa, /tools\/studio-check-two-players\.luau/);
	assert.match(qa, /## Reprise/);
	assert.match(qa, /two-players-client1\.jpg/);
	assert.match(qa, /two-players-client2\.jpg/);
});
