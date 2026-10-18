// Export des icônes de ressources depuis une capture Studio brute, sans PowerShell.
// Même rendu que tools/export-resource-icon.ps1 -ChromaKeyMagenta et tools/.reframe-resource-icons.ps1 :
// fond magenta de l'atelier détouré, objet centré à environ 78 % du cadre, contour Ink cuit (15 px).
// Node seul (aucune dépendance). Les captures arrivent par `node tools/icon-render.mjs serve`
// (POST /raw → build/icons/<nom>.rgba, pixels de CaptureService lus par EditableImage).
//
//   node tools/export-resource-icon.mjs build <resource_id> <capture> [--soft]
//     build/icons/<capture>.rgba → assets/icons/resources/<resource_id>.png (512 × 512 RGBA).
//     --soft : élimine aussi les pixels magenta mélangés aux bords (objets sans violet).
//   node tools/export-resource-icon.mjs png <capture> <sortie.png>
//     Convertit la capture brute en PNG de preuve (automation/screenshots/resources/...).
//   node tools/export-resource-icon.mjs sheet <sortie.png> <resource_id> [...]
//     Planche de lecture : chaque icône à 128 px et 32 px sur fond de carte et sur fond sombre.

import fs from "node:fs";
import path from "node:path";
import zlib from "node:zlib";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const WORK = path.join(ROOT, "build", "icons");
const OUT = path.join(ROOT, "assets", "icons", "resources");
const SIZE = 512;
const FILL = 0.78; // comme .reframe-resource-icons.ps1
const OUTLINE = 15; // comme export-resource-icon.ps1
const INK = [31, 26, 23];

const CRC_TABLE = new Int32Array(256).map((_, n) => {
	let c = n;
	for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
	return c;
});

function crc32(buf) {
	let c = -1;
	for (const byte of buf) c = CRC_TABLE[(c ^ byte) & 0xff] ^ (c >>> 8);
	return (c ^ -1) >>> 0;
}

function chunk(type, data) {
	const head = Buffer.alloc(8);
	head.writeUInt32BE(data.length, 0);
	head.write(type, 4, "ascii");
	const tail = Buffer.alloc(4);
	tail.writeUInt32BE(crc32(Buffer.concat([head.subarray(4), data])), 0);
	return Buffer.concat([head, data, tail]);
}

function encodePng(width, height, rgba) {
	const ihdr = Buffer.alloc(13);
	ihdr.writeUInt32BE(width, 0);
	ihdr.writeUInt32BE(height, 4);
	ihdr[8] = 8;
	ihdr[9] = 6;
	const raw = Buffer.alloc((width * 4 + 1) * height);
	for (let y = 0; y < height; y++) {
		Buffer.from(rgba.buffer, rgba.byteOffset + y * width * 4, width * 4).copy(raw, y * (width * 4 + 1) + 1);
	}
	return Buffer.concat([
		Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
		chunk("IHDR", ihdr),
		chunk("IDAT", zlib.deflateSync(raw, { level: 9 })),
		chunk("IEND", Buffer.alloc(0)),
	]);
}

// Relit nos propres PNG (un seul IDAT, filtre 0).
function readPng(file) {
	const data = fs.readFileSync(file);
	const width = data.readUInt32BE(16);
	const height = data.readUInt32BE(20);
	const chunks = [];
	for (let offset = 8; offset < data.length; ) {
		const len = data.readUInt32BE(offset);
		if (data.toString("ascii", offset + 4, offset + 8) === "IDAT") chunks.push(data.subarray(offset + 8, offset + 8 + len));
		offset += len + 12;
	}
	const raw = zlib.inflateSync(Buffer.concat(chunks));
	const px = new Uint8Array(width * height * 4);
	for (let y = 0; y < height; y++) raw.copy(px, y * width * 4, y * (width * 4 + 1) + 1, (y + 1) * (width * 4 + 1));
	return { width, height, px };
}

function readRaw(file) {
	const data = fs.readFileSync(file);
	const width = data.readUInt32LE(0);
	const height = data.readUInt32LE(4);
	return { width, height, px: new Uint8Array(data.buffer, data.byteOffset + 8, width * height * 4) };
}

// Studio limite un POST à 1 Mo : une capture plein écran arrive en bandes <capture>__0, __1, ...
function readCapture(name) {
	const whole = path.join(WORK, `${name}.rgba`);
	if (fs.existsSync(whole)) return readRaw(whole);
	const bands = [];
	for (let i = 0; fs.existsSync(path.join(WORK, `${name}__${i}.rgba`)); i++) bands.push(readRaw(path.join(WORK, `${name}__${i}.rgba`)));
	if (!bands.length) throw new Error(`capture introuvable : build/icons/${name}.rgba`);
	const width = bands[0].width;
	if (bands.some((band) => band.width !== width)) throw new Error("bandes de largeurs différentes");
	const height = bands.reduce((sum, band) => sum + band.height, 0);
	const px = new Uint8Array(width * height * 4);
	let offset = 0;
	for (const band of bands) {
		px.set(band.px, offset);
		offset += band.px.length;
	}
	return { width, height, px };
}

// Seuils de export-resource-icon.ps1 : ne pas confondre les ombres violettes avec le fond saturé.
function isMagenta(r, g, b, soft) {
	if (r > 200 && b > 200 && g < 80 && Math.abs(r - b) < 60) return true;
	return soft && r > 130 && b > 130 && r > g + 30 && b > g + 30;
}

// Cadre carré centré sur l'objet, comme .reframe-resource-icons.ps1.
function frame({ width, height, px }) {
	let x0 = width, y0 = height, x1 = -1, y1 = -1;
	for (let y = 0; y < height; y++) {
		for (let x = 0; x < width; x++) {
			const i = (y * width + x) * 4;
			const [r, g, b] = [px[i], px[i + 1], px[i + 2]];
			if (!(r > g + 50 && b > g + 50 && r > 130 && b > 130)) {
				x0 = Math.min(x0, x); y0 = Math.min(y0, y); x1 = Math.max(x1, x); y1 = Math.max(y1, y);
			}
		}
	}
	if (x1 < 0) throw new Error("aucun objet détecté sur le fond magenta");
	const size = Math.min(height, Math.ceil(Math.max(x1 - x0 + 1, y1 - y0 + 1) / FILL));
	const cx = Math.round(Math.max(0, Math.min(width - size, (x0 + x1 - size) / 2)));
	const cy = Math.round(Math.max(0, Math.min(height - size, (y0 + y1 - size) / 2)));
	return { cx, cy, size, box: [x0, y0, x1, y1] };
}

// Rééchantillonnage par moyenne de zone (réduction) ou bilinéaire (agrandissement).
function resample(img, cx, cy, size) {
	const out = new Uint8Array(SIZE * SIZE * 4);
	const scale = size / SIZE;
	const taps = Math.max(1, Math.ceil(scale * 2));
	for (let y = 0; y < SIZE; y++) {
		for (let x = 0; x < SIZE; x++) {
			const acc = [0, 0, 0];
			for (let sy = 0; sy < taps; sy++) {
				for (let sx = 0; sx < taps; sx++) {
					const fx = Math.min(img.width - 1, Math.max(0, cx + (x + (sx + 0.5) / taps) * scale - 0.5));
					const fy = Math.min(img.height - 1, Math.max(0, cy + (y + (sy + 0.5) / taps) * scale - 0.5));
					const ix = Math.floor(fx), iy = Math.floor(fy);
					const tx = fx - ix, ty = fy - iy;
					const jx = Math.min(img.width - 1, ix + 1), jy = Math.min(img.height - 1, iy + 1);
					for (let c = 0; c < 3; c++) {
						const p = (xx, yy) => img.px[(yy * img.width + xx) * 4 + c];
						acc[c] += (p(ix, iy) * (1 - tx) + p(jx, iy) * tx) * (1 - ty) + (p(ix, jy) * (1 - tx) + p(jx, jy) * tx) * ty;
					}
				}
			}
			const o = (y * SIZE + x) * 4;
			for (let c = 0; c < 3; c++) out[o + c] = Math.round(acc[c] / (taps * taps));
			out[o + 3] = 255;
		}
	}
	return out;
}

// Détourage et contour Ink, transcription de ResourceIconChroma (export-resource-icon.ps1).
function chroma(px, soft) {
	const w = SIZE, h = SIZE;
	const mask = new Uint8Array(w * h);
	for (let i = 0; i < w * h; i++) mask[i] = isMagenta(px[i * 4], px[i * 4 + 1], px[i * 4 + 2], soft) ? 0 : 1;
	const expanded = mask.slice();
	for (let y = 0; y < h; y++) {
		for (let x = 0; x < w; x++) {
			const i = y * w + x;
			if (!mask[i]) continue;
			if (x > 0 && x < w - 1 && y > 0 && y < h - 1 && mask[i - 1] && mask[i + 1] && mask[i - w] && mask[i + w]) continue;
			for (let dy = -OUTLINE; dy <= OUTLINE; dy++) {
				const yy = y + dy;
				if (yy < 0 || yy >= h) continue;
				const half = Math.floor(Math.sqrt(OUTLINE * OUTLINE - dy * dy));
				for (let dx = -half; dx <= half; dx++) {
					const xx = x + dx;
					if (xx >= 0 && xx < w) expanded[yy * w + xx] = 1;
				}
			}
		}
	}
	const out = new Uint8Array(w * h * 4);
	for (let y = 0; y < h; y++) {
		for (let x = 0; x < w; x++) {
			const i = y * w + x;
			const edge = mask[i] && (x < 2 || y < 2 || x >= w - 2 || y >= h - 2 || !mask[i - 2] || !mask[i + 2] || !mask[i - 2 * w] || !mask[i + 2 * w]);
			if (mask[i] && !edge) out.set([px[i * 4], px[i * 4 + 1], px[i * 4 + 2], 255], i * 4);
			else if (expanded[i]) out.set([...INK, 255], i * 4);
		}
	}
	return out;
}

function build(resourceId, capture, soft) {
	if (!/^resource_\d{3}$/.test(resourceId)) throw new Error(`identifiant invalide : ${resourceId}`);
	const catalogue = JSON.parse(fs.readFileSync(path.join(ROOT, "automation/catalogues/resources.json"), "utf8"));
	if (!catalogue.queue.some((entry) => entry.id === resourceId)) throw new Error(`ressource hors catalogue : ${resourceId}`);
	const img = readCapture(capture);
	const { cx, cy, size, box } = frame(img);
	const rgba = chroma(resample(img, cx, cy, size), soft);
	fs.mkdirSync(OUT, { recursive: true });
	const file = path.join(OUT, `${resourceId}.png`);
	fs.writeFileSync(file, encodePng(SIZE, SIZE, rgba));
	console.log(`${resourceId}: objet ${box[2] - box[0] + 1} × ${box[3] - box[1] + 1} px, cadre ${size} px → ${path.relative(ROOT, file)}`);
}

function downscale({ px }, size) {
	const f = SIZE / size;
	const out = new Float32Array(size * size * 4);
	for (let y = 0; y < SIZE; y++) {
		for (let x = 0; x < SIZE; x++) {
			const i = (y * SIZE + x) * 4;
			const o = (Math.floor(y / f) * size + Math.floor(x / f)) * 4;
			const al = px[i + 3] / 255;
			for (let c = 0; c < 3; c++) out[o + c] += px[i + c] * al;
			out[o + 3] += al;
		}
	}
	return { size, out, n: f * f };
}

function sheet(target, ids) {
	const cell = 160;
	const backgrounds = [[0xf4, 0xe8, 0xd0], [0x2b, 0x24, 0x20]];
	const width = cell * 2 * ids.length;
	const height = cell + 48;
	const px = new Uint8Array(width * height * 4);
	ids.forEach((id, index) => {
		const icon = readPng(path.join(OUT, `${id}.png`));
		const big = downscale(icon, 128);
		const small = downscale(icon, 32);
		backgrounds.forEach((bg, k) => {
			const left = (index * 2 + k) * cell;
			for (let y = 0; y < height; y++) for (let x = left; x < left + cell; x++) px.set([...bg, 255], (y * width + x) * 4);
			for (const [img, ox, oy] of [[big, left + 16, 16], [small, left + 64, cell]]) {
				for (let y = 0; y < img.size; y++) {
					for (let x = 0; x < img.size; x++) {
						const i = (y * img.size + x) * 4;
						const al = img.out[i + 3] / img.n;
						const o = ((oy + y) * width + ox + x) * 4;
						for (let c = 0; c < 3; c++) {
							const fg = img.out[i + 3] > 0 ? img.out[i + c] / img.out[i + 3] : 0;
							px[o + c] = Math.round(fg * al + bg[c] * (1 - al));
						}
					}
				}
			}
		});
	});
	fs.mkdirSync(path.dirname(target), { recursive: true });
	fs.writeFileSync(target, encodePng(width, height, px));
	console.log(`planche → ${path.relative(ROOT, target)}`);
}

const [command, ...args] = process.argv.slice(2);
if (command === "build") build(args[0], args[1], args.includes("--soft"));
else if (command === "png") {
	const { width, height, px } = readCapture(args[0]);
	fs.mkdirSync(path.dirname(path.resolve(args[1])), { recursive: true });
	fs.writeFileSync(path.resolve(args[1]), encodePng(width, height, px));
} else if (command === "sheet") sheet(path.resolve(args[0]), args.slice(1));
else {
	console.error("usage : node tools/export-resource-icon.mjs build <resource_id> <capture> [--soft] | png <capture> <sortie.png> | sheet <sortie.png> <resource_id>...");
	process.exit(1);
}
