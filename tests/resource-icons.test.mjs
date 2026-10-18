// node --test tests/resource-icons.test.mjs
// Contrôles techniques ; la conformité artistique reste une review sur captures Studio.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';
import { inflateSync } from 'node:zlib';

const root = new URL('../', import.meta.url);
const read = (path) => readFileSync(new URL(path, root));
const source = read('src/shared/Config/ResourceConfig.lua').toString('utf8');
const resources = [...source.matchAll(/^resource\("([^"]+)", "([^"]+)", "([^"]+)"(?:, "([^"]+)")?\)\s*$/gm)]
	.map((m) => ({ id: m[1], family: m[3], icon: m[4] }));
const delivered = resources.filter((r) => r.icon);
const directory = 'assets/icons/resources/';
const files = readdirSync(fileURLToPath(new URL(directory, root))).filter((f) => f.endsWith('.png')).sort();

test('resource icons: PNG files and published code entries correspond exactly', () => {
	assert.equal(resources.length, 60, 'catalogue must parse completely');
	assert.ok(delivered.length > 0, 'no delivered icons');
	assert.deepEqual(files, delivered.map((r) => `${r.id}.png`).sort());
});

test('resource icons: published asset ids and PNG contents are unique', () => {
	const hashes = new Set();
	const ids = new Set();
	for (const r of delivered) {
		assert.match(r.icon, /^rbxassetid:\/\/[1-9]\d+$/, r.id);
		assert.ok(!ids.has(r.icon), `${r.id}: duplicate AssetId`);
		ids.add(r.icon);
		const hash = createHash('sha256').update(read(`${directory}${r.id}.png`)).digest('hex');
		assert.ok(!hashes.has(hash), `${r.id}: duplicate PNG`);
		hashes.add(hash);
	}
});

// Decode the current exporter format (8-bit RGBA, non-interlaced), including PNG row filters.
function crc32(bytes) {
	let crc = 0xffffffff;
	for (const byte of bytes) {
		crc ^= byte;
		for (let bit = 0; bit < 8; bit++) crc = (crc >>> 1) ^ ((crc & 1) ? 0xedb88320 : 0);
	}
	return (crc ^ 0xffffffff) >>> 0;
}

function pixels(png) {
	assert.deepEqual([...png.subarray(0, 8)], [137, 80, 78, 71, 13, 10, 26, 10]);
	assert.equal(png.toString('ascii', 12, 16), 'IHDR');
	assert.equal(png.readUInt32BE(16), 512, 'width');
	assert.equal(png.readUInt32BE(20), 512, 'height');
	assert.deepEqual([...png.subarray(24, 29)], [8, 6, 0, 0, 0], '8-bit RGBA, non-interlaced');
	const chunks = [];
	let end = false;
	for (let pos = 8; pos < png.length;) {
		assert.ok(pos + 12 <= png.length, 'truncated PNG chunk header');
		const size = png.readUInt32BE(pos);
		assert.ok(pos + size + 12 <= png.length, 'truncated PNG chunk');
		const kind = png.toString('ascii', pos + 4, pos + 8);
		assert.equal(crc32(png.subarray(pos + 4, pos + 8 + size)), png.readUInt32BE(pos + 8 + size), `${kind}: invalid CRC`);
		if (kind === 'IDAT') chunks.push(png.subarray(pos + 8, pos + 8 + size));
		pos += size + 12;
		if (kind === 'IEND') { end = true; assert.equal(pos, png.length); break; }
	}
	assert.ok(end, 'missing IEND');
	const stride = 512 * 4;
	const raw = inflateSync(Buffer.concat(chunks), { maxOutputLength: 512 * (stride + 1) });
	assert.equal(raw.length, 512 * (stride + 1));
	const out = Buffer.alloc(512 * stride);
	for (let y = 0; y < 512; y++) {
		const filter = raw[y * (stride + 1)];
		assert.ok(filter <= 4, 'invalid row filter');
		for (let x = 0; x < stride; x++) {
			const i = y * stride + x;
			const a = x >= 4 ? out[i - 4] : 0;
			const b = y ? out[i - stride] : 0;
			const c = y && x >= 4 ? out[i - stride - 4] : 0;
			const p = a + b - c;
			const paeth = Math.abs(p - a) <= Math.abs(p - b) && Math.abs(p - a) <= Math.abs(p - c)
				? a : Math.abs(p - b) <= Math.abs(p - c) ? b : c;
			const prediction = [0, a, b, Math.floor((a + b) / 2), paeth][filter];
			out[i] = (raw[y * (stride + 1) + x + 1] + prediction) & 255;
		}
	}
	return out;
}

test('resource icons: decoder rejects corrupted PNG chunk data', () => {
	const png = Buffer.from(read(directory + files[0]));
	// Change IHDR compression method without updating its CRC; dimensions remain intact.
	png[26] ^= 1;
	assert.throws(() => pixels(png), /8-bit RGBA/);
	const damaged = Buffer.from(read(directory + files[0]));
	// Alter the IHDR checksum itself to exercise integrity validation independently.
	damaged[29] ^= 1;
	assert.throws(() => pixels(damaged), /invalid CRC/);
	const original = read(directory + files[0]);
	// Preserve the complete IHDR, then truncate the next chunk header or payload.
	assert.throws(() => pixels(original.subarray(0, 34)), /truncated PNG chunk header/);
	assert.throws(() => pixels(original.subarray(0, original.length - 1)), /truncated PNG chunk/);
});

test('resource icons: delivered PNGs decode at 512 x 512 with visible content and transparent background', () => {
	for (const file of files) {
		const rgba = pixels(read(directory + file));
		let transparent = 0, visible = 0;
		for (let i = 3; i < rgba.length; i += 4) {
			if (rgba[i] === 0) transparent++;
			if (rgba[i] > 0) visible++;
		}
		assert.ok(transparent > 0 && visible > 0, `${file}: empty image or opaque background`);
	}
});

test('resource icons restart: tracked deliveries and blocked resources have consistent reviews and evidence', () => {
	const states = readdirSync(fileURLToPath(new URL('automation/state/', root)))
		.filter((file) => /^resource_\d{3}\.json$/.test(file))
		.map((file) => JSON.parse(read(`automation/state/${file}`)));
	assert.equal(states.length, 24, 'the authorized restart tracks 24 resources');
	assert.equal(new Set(states.map((state) => state.task_id)).size, 24);
	const jobs = JSON.parse(read('automation/screenshots/resources/generation-final-resume-2026-10-18.json')).jobs;
	for (const state of states) {
		const resource = resources.find((r) => r.id === state.task_id);
		assert.ok(resource, state.task_id);
		assert.ok(state.restart_authorization && state.previous_series, `${state.task_id}: restart history`);
		assert.ok(state.iteration <= state.max_iterations, `${state.task_id}: iteration limit`);
		const review = read(state.latest_review).toString('utf8');
		assert.ok(state.evidence.length > 0, `${state.task_id}: evidence required`);
		for (const path of state.evidence) assert.ok(read(path).length > 0, path);
		if (resource.icon) {
			assert.equal(state.status, 'done', state.task_id);
			assert.equal(state.icon, resource.icon, state.task_id);
			assert.match(review, /\bPASS\b/, state.task_id);
			assert.ok(state.evidence.some((path) => /\.(jpg|png)$/.test(path)), `${state.task_id}: capture required`);
			assert.deepEqual(state.remaining_steps, [], state.task_id);
		} else {
			assert.equal(state.status, 'human_review', state.task_id);
			assert.equal(state.iteration, state.max_iterations, state.task_id);
			assert.match(review, /\bFIX\b/, state.task_id);
			assert.ok(state.remaining_steps.length > 0, state.task_id);
			const job = jobs.find((job) => job.id === state.task_id);
			assert.ok(job, `${state.task_id}: final generation proof`);
			assert.equal(job.pass, state.iteration, state.task_id);
			const result = JSON.parse(job.result.content[0].text);
			assert.equal(result.status, 'Failed', state.task_id);
			assert.match(JSON.stringify(result.jobResult), /Unable to generate Model/, state.task_id);
		}
	}
});

test('resource icons acceptance: all 60 resources have a published icon and local PNG', () => {
	const missing = resources.filter((r) => !r.icon).map((r) => r.id);
	assert.equal(resources.length, 60);
	assert.equal(missing.length, 0, `${delivered.length}/60 delivered; missing: ${missing.join(', ')}`);
	assert.equal(files.length, 60);
});

test('resource icons hand-built series: the 15 former generation failures are delivered without the generator', () => {
	const ids = ['020', '030', '036', '040', '041', '044', '045', '046', '048', '050', '051', '054', '055', '059', '060'];
	for (const n of ids) {
		const id = `resource_${n}`;
		const state = JSON.parse(read(`automation/state/${id}.json`));
		const resource = resources.find((r) => r.id === id);
		assert.ok(resource && resource.icon, `${id}: published icon in ResourceConfig`);
		assert.equal(state.status, 'done', id);
		assert.equal(state.icon, resource.icon, id);
		assert.equal(state.last_completed_step, 'handbuilt_studio_card_family_capture_pass', id);
		assert.ok(state.handbuilt_series, `${id}: hand-built series recorded`);
		assert.match(state.handbuilt_series.authorization, /sans generate_mesh ni generate_procedural_model/, id);
		assert.match(state.handbuilt_series.method, /AtelierIcones/, id);
		assert.match(state.handbuilt_series.method, /Archive_ResourceIcons_Handbuilt_\d{8}/, id);
		// The failed generator history stays as evidence of why the method changed.
		assert.ok(read(`automation/reviews/${id}-final-resume.md`).length > 0, `${id}: failure history kept`);
		assert.ok(state.evidence.includes('automation/screenshots/resources/generation-final-resume-2026-10-18.json'), id);
		assert.equal(state.latest_review, `automation/reviews/${id}-handbuilt.md`, id);
		const review = read(state.latest_review).toString('utf8');
		assert.match(review.split('\n')[0], new RegExp(`^# ${id} — .+ — PASS\\s*$`), `${id}: review verdict`);
		assert.doesNotMatch(review, /\bFIX\b/, `${id}: no open FIX`);
		assert.ok(review.includes(resource.icon), `${id}: review cites Icon Git = Image = AssetId`);
		const capture = `automation/screenshots/resources/${id}-handbuilt.png`;
		assert.ok(state.evidence.includes(capture), `${id}: hand-built capture in evidence`);
		assert.ok(review.includes(capture), `${id}: review cites its capture`);
		for (const path of state.evidence) assert.ok(read(path).length > 0, path);
	}
});
