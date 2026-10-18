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

test('resource icons acceptance: all 60 resources have a published icon and local PNG', () => {
	const missing = resources.filter((r) => !r.icon).map((r) => r.id);
	assert.equal(resources.length, 60);
	assert.equal(missing.length, 0, `${delivered.length}/60 delivered; missing: ${missing.join(', ')}`);
	assert.equal(files.length, 60);
});
