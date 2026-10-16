// Contrôle hors Studio de l'inventaire des écrans réels (docs/references/ui/README.md § 3), sans Luau :
// `node tests/ui-captures.test.mjs`. Lecture seule du dépôt. Vérifie :
//   - que l'inventaire est cohérent (numéros, noms de fichier, états) et suit les fichiers de ecrans/ ;
//   - que tout contrôleur ou vue qui dessine une interface figure dans l'inventaire ;
//   - que les contrôleurs, vues, démos (ApercuUI, ApercuEcranRecompenses, IntroDemo) et commandes
//     DebugData citées par la procédure de capture existent dans src/ ;
//   - que tools/test-ui-captures.ps1 accepte l'inventaire et refuse chaque erreur (jeux d'essai
//     temporaires, ignoré si Windows PowerShell est absent).
// Ne remplace pas les captures : elles se font en Studio (docs/references/ui/README.md § 2).
import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, mkdtempSync, readdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const read = (path) => readFileSync(join(repoRoot, path), 'utf8').replace(/\r\n/g, '\n');

let passed = 0;
let failed = 0;
let skipped = 0;
function test(name, run) {
	try {
		if (run() === 'skip') {
			skipped += 1;
			console.log(`SKIP ${name}`);
			return;
		}
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

const inventoryPath = 'docs/references/ui/README.md';
const inventory = read(inventoryPath);
const rows = inventory
	.split('\n')
	.filter((line) => /^\| \d/.test(line))
	.map((line) => {
		const cells = line.trim().replace(/^\||\|$/g, '').split('|').map((cell) => cell.trim());
		return { line, number: cells[0], file: cells[1].replace(/`/g, ''), owners: cells[3], source: cells[4], trigger: cells[5], state: cells.at(-1) };
	});
const screensDir = join(repoRoot, 'docs/references/ui/ecrans');
const screenFiles = existsSync(screensDir) ? readdirSync(screensDir).filter((name) => name !== '.gitkeep') : [];

const clientFiles = (dir) =>
	readdirSync(join(repoRoot, dir))
		.filter((name) => name.endsWith('.lua'))
		.map((name) => ({ name: name.replace(/\.lua$/, ''), source: read(`${dir}/${name}`) }));
const controllers = clientFiles('src/client/Controllers');
const views = clientFiles('src/client/UI/Views');
const owned = rows.map((row) => row.owners).join(' ');

test('inventaire lisible, 7 colonnes par ligne', () => {
	assert(rows.length > 0, 'aucune ligne dans le tableau § 3');
	for (const row of rows) assert(row.line.split('|').length === 9, `${row.number} : nombre de colonnes`);
});

test('numéros 01, 02, … sans trou ni doublon', () => {
	rows.forEach((row, i) => assert(row.number === String(i + 1).padStart(2, '0'), `ligne ${i + 1} : numéro ${row.number}`));
});

test('fichiers nommés NN_nom.png, uniques', () => {
	const seen = new Set();
	for (const row of rows) {
		assert(new RegExp(`^${row.number}_[a-z0-9_]+\\.png$`).test(row.file), `${row.number} : nom ${row.file}`);
		assert(!seen.has(row.file), `${row.file} en double`);
		seen.add(row.file);
	}
});

test('états « à capturer » ou « capturé AAAA-MM-JJ », source Jeu ou Démo', () => {
	for (const row of rows) {
		assert(/^(à capturer|capturé \d{4}-\d{2}-\d{2})$/.test(row.state), `${row.number} : état ${row.state}`);
		assert(['Jeu', 'Démo'].includes(row.source), `${row.number} : source ${row.source}`);
	}
});

test('« capturé » ⇔ fichier présent dans ecrans/', () => {
	for (const row of rows) {
		const present = screenFiles.includes(row.file);
		if (row.state.startsWith('capturé')) assert(present, `${row.number} capturé mais ecrans/${row.file} absent`);
		else assert(!present, `${row.number} : ecrans/${row.file} présent, état à passer en « capturé AAAA-MM-JJ »`);
	}
	const known = new Set(rows.map((row) => row.file));
	for (const name of screenFiles) assert(known.has(name), `ecrans/${name} hors inventaire`);
});

test('le texte annonce le bon nombre d\'écrans', () => {
	for (const m of inventory.matchAll(/les (\d+) captures/g)) assert(Number(m[1]) === rows.length, `« les ${m[1]} captures » pour ${rows.length} lignes`);
});

test('tout contrôleur ou vue qui dessine une interface est dans l\'inventaire', () => {
	const drawsUi = /UIKit|ScreenGui|BillboardGui|SurfaceGui|Views\./;
	for (const file of [...controllers, ...views]) {
		if (drawsUi.test(file.source)) assert(new RegExp(`\\b${file.name}\\b`).test(owned), `${file.name} sans écran dans l'inventaire`);
	}
});

test('contrôleurs et vues cités existent dans src/client', () => {
	const names = new Set([...controllers, ...views].map((file) => file.name));
	for (const m of owned.matchAll(/\b([A-Z]\w+(?:Controller|View))\b/g)) assert(names.has(m[1]), `${m[1]} introuvable`);
	const summonView = views.find((file) => file.name === 'SummonView');
	if (/SummonView\.Reveal/.test(owned)) assert(/\bReveal\b/.test(summonView.source), 'SummonView.Reveal introuvable');
	if (/UIKit\.curtain/.test(owned)) assert(/function UIKit\.curtain\b/.test(read('src/client/UI/UIKit.lua')), 'UIKit.curtain introuvable');
});

test('démos ApercuUI citées = démos de UIPreviewController', () => {
	const source = read('src/client/Controllers/UIPreviewController.lua');
	const block = source.match(/local DEMOS[^=]*= \{([\s\S]*?)\n\}/)?.[1] ?? '';
	const demos = new Set([...block.matchAll(/^\t(\w+) = /gm)].map((m) => m[1]));
	assert(demos.size > 0, 'table DEMOS illisible');
	const listed = inventory.match(/attribut `Workspace\.ApercuUI` \(([^)]*)\)/)?.[1] ?? '';
	const cited = new Set([...listed.matchAll(/`(\w+)`/g)].map((m) => m[1]));
	for (const m of inventory.matchAll(/ApercuUI = "?(\w+)"?/g)) cited.add(m[1]);
	for (const name of cited) assert(demos.has(name), `démo ApercuUI « ${name} » inexistante`);
	for (const name of demos) assert(cited.has(name), `démo ApercuUI « ${name} » absente de la procédure`);
});

test('démos ApercuEcranRecompenses et IntroDemo existent', () => {
	assert(/GetAttribute\("ApercuEcranRecompenses"\)/.test(read('src/client/Controllers/RewardScreenController.lua')), 'ApercuEcranRecompenses');
	const intro = read('src/client/Controllers/CombatIntroController.lua');
	assert(/GetAttributeChangedSignal\("IntroDemo"\)/.test(intro), 'IntroDemo');
	assert(/"AreneCombat"/.test(intro), 'tag AreneCombat');
});

test('commandes DebugData de la procédure reconnues par DebugService', () => {
	const service = read('src/server/Services/DebugService.lua');
	const commands = new Set([...service.matchAll(/command == "(\w+)"/g)].map((m) => m[1]));
	const calls = [...inventory.matchAll(/d:Invoke\(p, "(\w+)"(?:, ([^)\n]*))?\)/g)];
	assert(calls.length > 0, 'aucune commande dans la procédure');
	for (const [, command] of calls) assert(commands.has(command), `commande ${command} inconnue`);
	for (const row of rows) {
		for (const m of row.trigger.matchAll(/`(\w+)`/g)) {
			if (/^[A-Z][a-z]+[A-Z]\w*$/.test(m[1]) && !/^(Apercu|Intro)/.test(m[1]) && !m[1].endsWith('Completed')) {
				assert(commands.has(m[1]), `${row.number} : commande ${m[1]} inconnue`);
			}
		}
	}
});

test('arguments des commandes : héros, monnaies et événement de quête valides', () => {
	const heroes = new Set([...read('src/shared/Config/HeroConfig.lua').matchAll(/^hero\("(\w+)"/gm)].map((m) => m[1]));
	const currencies = new Set([...read('src/shared/Types/PlayerDataTypes.lua').matchAll(/^\t(\w+): number,/gm)].map((m) => m[1]));
	const questEvents = new Set([...read('src/server/Config/QuestConfig.lua').matchAll(/Event = "(\w+)"/g)].map((m) => m[1]));
	for (const [, command, args] of inventory.matchAll(/d:Invoke\(p, "(\w+)", "(\w+)"/g)) {
		if (command === 'AddHero') assert(heroes.has(args), `héros ${args} inconnu`);
		if (command === 'AddCurrency') assert(currencies.has(args), `monnaie ${args} inconnue`);
		if (command === 'QuestEvent') assert(questEvents.has(args), `événement ${args} absent de QuestConfig`);
	}
});

test('la maquette v1 est déclarée périmée', () => {
	assert(/maquette_v1\.jpg[^\n]*\n?[^\n]*périmée/.test(inventory), 'inventaire');
	assert(/maquette_v1[\s\S]{0,200}périmée/.test(read('docs/UI_DESIGN_SYSTEM.md')), 'UI_DESIGN_SYSTEM.md');
	assert(/docs\/references\/ui\/ecrans/.test(read('CLAUDE.md')), 'CLAUDE.md renvoie vers ecrans/');
});

// --- tools/test-ui-captures.ps1 sur des jeux d'essai ---
const script = join(repoRoot, 'tools/test-ui-captures.ps1');
const shell = ['powershell', 'pwsh'].find((exe) => spawnSync(exe, ['-NoProfile', '-Command', 'exit 0']).status === 0);
function runScript(uiDir, strict = false) {
	const args = ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', script];
	if (uiDir) args.push('-UiDir', uiDir);
	if (strict) args.push('-Strict');
	const result = spawnSync(shell, args, { encoding: 'utf8' });
	return { ok: result.status === 0, output: `${result.stdout}${result.stderr}` };
}
function fixture(edit, files = []) {
	const dir = mkdtempSync(join(tmpdir(), 'ui-captures-'));
	mkdirSync(join(dir, 'ecrans'));
	writeFileSync(join(dir, 'README.md'), edit(inventory), 'utf8');
	for (const name of files) writeFileSync(join(dir, 'ecrans', name), '');
	return dir;
}
function scriptCase(name, edit, files, { strict = false, ok, expect }) {
	test(`test-ui-captures.ps1 : ${name}`, () => {
		if (!shell) return 'skip';
		const dir = fixture(edit, files);
		try {
			const result = runScript(dir, strict);
			assert(result.ok === ok, `code de sortie inattendu\n${result.output}`);
			if (expect) assert(expect.test(result.output), `message attendu ${expect}\n${result.output}`);
		} finally {
			rmSync(dir, { recursive: true, force: true });
		}
	});
}
const first = rows[0];
const markCaptured = (text) => text.replace(first.line, first.line.replace(/à capturer \|$/, 'capturé 2026-10-16 |'));

test('test-ui-captures.ps1 : passe sur le dépôt', () => {
	if (!shell) return 'skip';
	const result = runScript();
	assert(result.ok, result.output);
	assert(result.output.includes(`Screens in inventory: ${rows.length}`), result.output);
});
scriptCase('-Strict échoue tant qu\'il reste des écrans à capturer', (t) => t, [], { strict: true, ok: false, expect: /still to capture/ });
scriptCase('écran capturé avec son fichier : accepté', markCaptured, [first.file], { ok: true, expect: new RegExp(`still to capture: ${rows.length - 1}`) });
scriptCase('écran capturé sans fichier : refusé', markCaptured, [], { ok: false, expect: /marked as captured/ });
scriptCase('fichier hors inventaire : refusé', (t) => t, ['99_inconnu.png'], { ok: false, expect: /not in the inventory/ });
scriptCase('numéro en double : refusé', (t) => t.replace(rows[1].line, rows[1].line.replace(/^\| \d{2}/, `| ${first.number}`)), [], { ok: false, expect: /duplicate number/ });
scriptCase('mauvais nom de fichier : refusé', (t) => t.replace(first.line, first.line.replace(first.file, 'HUD.png')), [], { ok: false, expect: /invalid file name/ });
scriptCase('état inconnu : refusé', (t) => t.replace(first.line, first.line.replace(/à capturer \|$/, 'fait |')), [], { ok: false, expect: /invalid state/ });
scriptCase('inventaire vide : refusé', () => '# vide\n', [], { ok: false, expect: /empty or unreadable/ });
test('test-ui-captures.ps1 : tout capturé, -Strict passe', () => {
	if (!shell) return 'skip';
	const all = rows.reduce((text, row) => text.replace(row.line, row.line.replace(/à capturer \|$/, 'capturé 2026-10-16 |')), inventory);
	const dir = fixture(() => all, rows.map((row) => row.file));
	try {
		const result = runScript(dir, true);
		assert(result.ok, result.output);
	} finally {
		rmSync(dir, { recursive: true, force: true });
	}
});

console.log(`\n${passed} passed, ${failed} failed, ${skipped} skipped`);
if (failed > 0) process.exit(1);
