// Rendu des icônes PNG d'items (docs/ITEMS.md § 4) à partir de deux captures Studio du même objet.
// Node seul (aucune dépendance).
//
//   node tools/icon-render.mjs serve
//     Petit serveur local 127.0.0.1:8765 :
//     - POST /raw?name=<nom>&w=<largeur>&h=<hauteur>  corps = pixels RGBA en base64 (EditableImage
//       :ReadPixelsBuffer + EncodingService:Base64Encode) → build/icons/<nom>.rgba ;
//     - GET /<chemin relatif au dépôt> → le fichier (PNG pour upload_image).
//   node tools/icon-render.mjs build <item_id> [<item_id> ...]
//     Lit build/icons/<item_id>_a.rgba (fond A) et <item_id>_b.rgba (fond B, couleur opposée) et écrit
//     assets/icons/items/<item_id>.png : 512 × 512, fond transparent (matage par différence des deux
//     fonds), objet recadré à environ 80 % du cadre, contour Ink #1F1A17 cuit dans l'image, ombre
//     portée douce. Si <item_id>_c.rgba existe (même cadrage, chaque couleur de pièce remplacée par
//     un aplat Neon distinct), les frontières entre pièces deviennent des traits Ink internes.
//   node tools/icon-render.mjs sheet <sortie.png> <item_id> [...]
//     Planche de contrôle : chaque icône à 128 px et 32 px, sur fond clair et sur fond sombre.
//   node tools/icon-render.mjs png <capture> [...]
//     Convertit une capture brute build/icons/<capture>.rgba en PNG (contrôle d'une capture).

import fs from "node:fs";
import http from "node:http";
import path from "node:path";
import zlib from "node:zlib";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const WORK = path.join(ROOT, "build", "icons");
const OUT = path.join(ROOT, "assets", "icons", "items");
const SIZE = 512;
const FILL = 0.8; // part du cadre occupée par l'objet, contour compris
const OUTLINE = 10; // épaisseur du contour Ink, en px sur 512 (comme les icônes voisines)
const LINE = 2.2; // demi-épaisseur des traits Ink internes, en px sur 512
const INK = [0x1f, 0x1a, 0x17];
const SHADOW = 0.22; // opacité de l'ombre portée sous l'objet

// --- PNG -------------------------------------------------------------------------------------------

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
	ihdr[8] = 8; // bits par canal
	ihdr[9] = 6; // RGBA
	const raw = Buffer.alloc((width * 4 + 1) * height);
	for (let y = 0; y < height; y++) {
		raw[y * (width * 4 + 1)] = 0;
		Buffer.from(rgba.buffer, rgba.byteOffset + y * width * 4, width * 4).copy(raw, y * (width * 4 + 1) + 1);
	}
	return Buffer.concat([
		Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
		chunk("IHDR", ihdr),
		chunk("IDAT", zlib.deflateSync(raw, { level: 9 })),
		chunk("IEND", Buffer.alloc(0)),
	]);
}

// --- Captures --------------------------------------------------------------------------------------

function readCapture(name) {
	const file = path.join(WORK, `${name}.rgba`);
	const data = fs.readFileSync(file);
	const width = data.readUInt32LE(0);
	const height = data.readUInt32LE(4);
	return { width, height, px: new Uint8Array(data.buffer, data.byteOffset + 8, width * height * 4) };
}

// Couleur du fond rendu : médiane des pixels du bord de l'image.
function borderColor({ width, height, px }) {
	const channels = [[], [], []];
	const take = (x, y) => {
		const i = (y * width + x) * 4;
		for (let c = 0; c < 3; c++) channels[c].push(px[i + c]);
	};
	for (let x = 0; x < width; x += 3) {
		take(x, 0);
		take(x, height - 1);
	}
	for (let y = 0; y < height; y += 3) {
		take(0, y);
		take(width - 1, y);
	}
	return channels.map((values) => values.sort((a, b) => a - b)[values.length >> 1]);
}

// Matage par différence : même objet devant deux fonds de couleurs opposées.
// Renvoie couleur (non prémultipliée, 0..1) et alpha par pixel.
function matte(a, b) {
	if (a.width !== b.width || a.height !== b.height) throw new Error("captures de tailles différentes");
	const bgA = borderColor(a);
	const bgB = borderColor(b);
	const diff = bgA.map((v, c) => v - bgB[c]);
	const norm = diff.reduce((s, v) => s + v * v, 0);
	if (norm < 100 * 100) throw new Error(`fonds trop proches : ${bgA} / ${bgB}`);
	const n = a.width * a.height;
	const color = new Float32Array(n * 3);
	const alpha = new Float32Array(n);
	for (let p = 0; p < n; p++) {
		let dot = 0;
		for (let c = 0; c < 3; c++) dot += (a.px[p * 4 + c] - b.px[p * 4 + c]) * diff[c];
		let al = 1 - dot / norm;
		al = al < 0.06 ? 0 : al > 0.94 ? 1 : al;
		alpha[p] = al;
		if (al > 0) {
			for (let c = 0; c < 3; c++) {
				const mix = (a.px[p * 4 + c] + b.px[p * 4 + c] - (1 - al) * (bgA[c] + bgB[c])) / 2;
				color[p * 3 + c] = Math.min(1, Math.max(0, mix / al / 255));
			}
		}
	}
	return { width: a.width, height: a.height, color, alpha, bgA, bgB };
}

// Garde la plus grande zone connexe (élimine les poussières de bord).
function keepMainBlob(img) {
	const { width, height, alpha } = img;
	const label = new Int32Array(width * height);
	let best = 0;
	let bestSize = 0;
	let next = 0;
	const stack = [];
	for (let start = 0; start < width * height; start++) {
		if (alpha[start] < 0.25 || label[start]) continue;
		next++;
		let size = 0;
		stack.push(start);
		label[start] = next;
		while (stack.length) {
			const p = stack.pop();
			size++;
			const x = p % width;
			const y = (p / width) | 0;
			for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
				const nx = x + dx;
				const ny = y + dy;
				if (nx < 0 || ny < 0 || nx >= width || ny >= height) continue;
				const q = ny * width + nx;
				if (alpha[q] >= 0.25 && !label[q]) {
					label[q] = next;
					stack.push(q);
				}
			}
		}
		if (size > bestSize) {
			bestSize = size;
			best = next;
		}
	}
	// Les pixels faibles (< 0.25) restent s'ils touchent la zone principale (bord antialiasé).
	for (let p = 0; p < width * height; p++) {
		if (label[p] && label[p] !== best) alpha[p] = 0;
	}
	return bestSize;
}

function bounds({ width, height, alpha }) {
	let x0 = width;
	let y0 = height;
	let x1 = -1;
	let y1 = -1;
	for (let y = 0; y < height; y++) {
		for (let x = 0; x < width; x++) {
			if (alpha[y * width + x] > 0.1) {
				if (x < x0) x0 = x;
				if (x > x1) x1 = x;
				if (y < y0) y0 = y;
				if (y > y1) y1 = y;
			}
		}
	}
	if (x1 < 0) throw new Error("aucun objet détecté");
	return { x0, y0, x1: x1 + 1, y1: y1 + 1 };
}

// Frontières entre pièces dans la capture C (aplats Neon) : 1 là où deux voisins diffèrent nettement.
function pieceEdges(img, ids) {
	const { width, height, alpha } = img;
	const edge = new Float32Array(width * height);
	const diff = (p, q) => {
		let m = 0;
		for (let c = 0; c < 3; c++) m = Math.max(m, Math.abs(ids.px[p * 4 + c] - ids.px[q * 4 + c]));
		return m;
	};
	for (let y = 0; y < height - 1; y++) {
		for (let x = 0; x < width - 1; x++) {
			const p = y * width + x;
			if (alpha[p] < 0.9) continue;
			for (const q of [p + 1, p + width]) {
				if (alpha[q] >= 0.9 && diff(p, q) > 60) {
					edge[p] = 1;
					edge[q] = 1;
				}
			}
		}
	}
	return edge;
}

// Rééchantillonne (bilinéaire, couleurs prémultipliées) la zone box de img dans un carré SIZE.
// L'objet est centré un peu au-dessus du milieu pour laisser la place à l'ombre portée.
function placeInSquare(img, box, edge) {
	const bw = box.x1 - box.x0;
	const bh = box.y1 - box.y0;
	const scale = (SIZE * FILL - 2 * OUTLINE) / Math.max(bw, bh);
	const ox = (SIZE - bw * scale) / 2;
	const oy = (SIZE - bh * scale) / 2 - SIZE * 0.03;
	const color = new Float32Array(SIZE * SIZE * 3);
	const alpha = new Float32Array(SIZE * SIZE);
	const lines = new Float32Array(SIZE * SIZE);
	const sample = (x, y, w, acc) => {
		x = Math.min(Math.max(x, 0), img.width - 1);
		y = Math.min(Math.max(y, 0), img.height - 1);
		const p = y * img.width + x;
		const al = img.alpha[p] * w;
		acc[0] += img.color[p * 3] * al;
		acc[1] += img.color[p * 3 + 1] * al;
		acc[2] += img.color[p * 3 + 2] * al;
		acc[3] += al;
		if (edge && edge[p] > 0) acc[4] = Math.max(acc[4], w);
	};
	// Suréchantillonnage 3 × 3 par pixel de sortie (réduit le crénelage si l'objet est réduit).
	const sub = 3;
	for (let y = 0; y < SIZE; y++) {
		for (let x = 0; x < SIZE; x++) {
			const acc = [0, 0, 0, 0, 0];
			for (let sy = 0; sy < sub; sy++) {
				for (let sx = 0; sx < sub; sx++) {
					const fx = box.x0 + (x + (sx + 0.5) / sub - ox) / scale - 0.5;
					const fy = box.y0 + (y + (sy + 0.5) / sub - oy) / scale - 0.5;
					if (fx < box.x0 - 1 || fy < box.y0 - 1 || fx > box.x1 || fy > box.y1) continue;
					const ix = Math.floor(fx);
					const iy = Math.floor(fy);
					const tx = fx - ix;
					const ty = fy - iy;
					sample(ix, iy, (1 - tx) * (1 - ty), acc);
					sample(ix + 1, iy, tx * (1 - ty), acc);
					sample(ix, iy + 1, (1 - tx) * ty, acc);
					sample(ix + 1, iy + 1, tx * ty, acc);
				}
			}
			const al = acc[3] / (sub * sub);
			const p = y * SIZE + x;
			alpha[p] = al;
			lines[p] = acc[4] > 0.25 ? 1 : 0;
			if (acc[3] > 0) for (let c = 0; c < 3; c++) color[p * 3 + c] = acc[c] / acc[3];
		}
	}
	return { color, alpha, lines, bottom: oy + bh * scale, width: bw * scale };
}

// Disques de rayon r autour des pixels marqués : couverture antialiasée 0..1.
function dilate(mask, r) {
	const offsets = [];
	const reach = Math.ceil(r + 1);
	for (let dy = -reach; dy <= reach; dy++) {
		for (let dx = -reach; dx <= reach; dx++) {
			const d = Math.hypot(dx, dy);
			if (d <= r + 1) offsets.push([dx, dy, d]);
		}
	}
	offsets.sort((a, b) => a[2] - b[2]);
	const out = new Float32Array(SIZE * SIZE);
	for (let y = 0; y < SIZE; y++) {
		for (let x = 0; x < SIZE; x++) {
			for (const [dx, dy, d] of offsets) {
				const nx = x + dx;
				const ny = y + dy;
				if (nx < 0 || ny < 0 || nx >= SIZE || ny >= SIZE || !mask[ny * SIZE + nx]) continue;
				out[y * SIZE + x] = Math.min(1, Math.max(0, r + 0.5 - d));
				break;
			}
		}
	}
	return out;
}

// Léger étalonnage peint main : un peu plus de saturation et de contraste que le rendu Studio
// (brume et étalonnage de la place affadissent les couleurs).
function grade(r, g, b) {
	const l = 0.299 * r + 0.587 * g + 0.114 * b;
	return [r, g, b].map((v) => {
		const saturated = l + (v - l) * 1.18;
		return Math.min(1, Math.max(0, (saturated - 0.5) * 1.08 + 0.5));
	});
}

// Composition finale : ombre portée, contour Ink sous l'objet, objet, traits Ink internes.
function compose({ color, alpha, lines, bottom, width }) {
	const solid = new Uint8Array(SIZE * SIZE);
	for (let p = 0; p < SIZE * SIZE; p++) solid[p] = alpha[p] >= 0.5 ? 1 : 0;
	const outline = dilate(solid, OUTLINE);
	const inner = dilate(lines, LINE);
	const sx = Math.max(60, width * 0.36);
	const sy = 16;
	const scx = SIZE / 2;
	const scy = Math.min(SIZE - sy - 6, bottom + OUTLINE + 18);
	const rgba = new Uint8Array(SIZE * SIZE * 4);
	for (let y = 0; y < SIZE; y++) {
		for (let x = 0; x < SIZE; x++) {
			const p = y * SIZE + x;
			const e = ((x - scx) / sx) ** 2 + ((y - scy) / sy) ** 2;
			const shadow = e < 1 ? SHADOW * (1 - e) ** 0.6 : 0;
			let r = INK[0];
			let g = INK[1];
			let b = INK[2];
			let a = shadow;
			// contour Ink par-dessus l'ombre
			const ink = outline[p];
			a = ink + a * (1 - ink);
			// objet (traits internes mélangés à sa couleur) par-dessus
			const al = alpha[p];
			if (al > 0) {
				const line = inner[p] * (solid[p] ? 1 : 0);
				const [gr, gg, gb] = grade(color[p * 3], color[p * 3 + 1], color[p * 3 + 2]);
				const cr = gr * 255 * (1 - line) + INK[0] * line;
				const cg = gg * 255 * (1 - line) + INK[1] * line;
				const cb = gb * 255 * (1 - line) + INK[2] * line;
				const outA = al + a * (1 - al);
				r = (cr * al + r * a * (1 - al)) / outA;
				g = (cg * al + g * a * (1 - al)) / outA;
				b = (cb * al + b * a * (1 - al)) / outA;
				a = outA;
			}
			const o = p * 4;
			rgba[o] = Math.round(r);
			rgba[o + 1] = Math.round(g);
			rgba[o + 2] = Math.round(b);
			rgba[o + 3] = Math.round(a * 255);
		}
	}
	return rgba;
}

function build(itemId) {
	const img = matte(readCapture(`${itemId}_a`), readCapture(`${itemId}_b`));
	keepMainBlob(img);
	const box = bounds(img);
	const idsFile = path.join(WORK, `${itemId}_c.rgba`);
	const edge = fs.existsSync(idsFile) ? pieceEdges(img, readCapture(`${itemId}_c`)) : null;
	const rgba = compose(placeInSquare(img, box, edge));
	fs.mkdirSync(OUT, { recursive: true });
	const file = path.join(OUT, `${itemId}.png`);
	fs.writeFileSync(file, encodePng(SIZE, SIZE, rgba));
	console.log(
		`${itemId}: fonds ${img.bgA} / ${img.bgB}, objet ${box.x1 - box.x0} × ${box.y1 - box.y0} px` +
			`${edge ? ", traits internes" : ""} → ${path.relative(ROOT, file)}`
	);
	return rgba;
}

// --- Planche de contrôle ---------------------------------------------------------------------------

function readPngRgba(itemId) {
	// Relit nos propres PNG (un seul IDAT, filtre 0) : suffisant pour la planche.
	const data = fs.readFileSync(path.join(OUT, `${itemId}.png`));
	const chunks = [];
	let offset = 8;
	while (offset < data.length) {
		const len = data.readUInt32BE(offset);
		const type = data.toString("ascii", offset + 4, offset + 8);
		if (type === "IDAT") chunks.push(data.subarray(offset + 8, offset + 8 + len));
		offset += len + 12;
	}
	const raw = zlib.inflateSync(Buffer.concat(chunks));
	const rgba = new Uint8Array(SIZE * SIZE * 4);
	for (let y = 0; y < SIZE; y++) raw.copy(rgba, y * SIZE * 4, y * (SIZE * 4 + 1) + 1, (y + 1) * (SIZE * 4 + 1));
	return rgba;
}

function downscale(rgba, size) {
	const f = SIZE / size;
	const out = new Float32Array(size * size * 4);
	for (let y = 0; y < SIZE; y++) {
		for (let x = 0; x < SIZE; x++) {
			const i = (y * SIZE + x) * 4;
			const o = (Math.floor(y / f) * size + Math.floor(x / f)) * 4;
			const al = rgba[i + 3] / 255;
			for (let c = 0; c < 3; c++) out[o + c] += rgba[i + c] * al;
			out[o + 3] += al;
		}
	}
	return { size, out, n: f * f };
}

function sheet(target, ids) {
	const cell = 160;
	const width = cell * 2 * ids.length;
	const height = cell + 48;
	const px = new Uint8Array(width * height * 4);
	const backgrounds = [
		[0xf4, 0xe8, 0xd0],
		[0x2b, 0x24, 0x20],
	];
	ids.forEach((id, index) => {
		const rgba = readPngRgba(id);
		const big = downscale(rgba, 128);
		const small = downscale(rgba, 32);
		backgrounds.forEach((bg, k) => {
			const left = (index * 2 + k) * cell;
			for (let y = 0; y < height; y++) {
				for (let x = left; x < left + cell; x++) {
					const o = (y * width + x) * 4;
					px.set([...bg, 255], o);
				}
			}
			for (const [img, ox, oy] of [
				[big, left + 16, 16],
				[small, left + 64, cell],
			]) {
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

// --- Serveur ---------------------------------------------------------------------------------------

function serve() {
	fs.mkdirSync(WORK, { recursive: true });
	const server = http.createServer((req, res) => {
		const url = new URL(req.url, "http://127.0.0.1");
		if (req.method === "POST" && url.pathname === "/raw") {
			const name = url.searchParams.get("name") ?? "";
			const width = Number(url.searchParams.get("w"));
			const height = Number(url.searchParams.get("h"));
			if (!/^[\w-]+$/.test(name) || !width || !height) {
				res.writeHead(400).end("paramètres invalides");
				return;
			}
			const parts = [];
			req.on("data", (d) => parts.push(d));
			req.on("end", () => {
				const pixels = Buffer.from(Buffer.concat(parts).toString("ascii"), "base64");
				if (pixels.length !== width * height * 4) {
					res.writeHead(400).end(`taille ${pixels.length} ≠ ${width * height * 4}`);
					return;
				}
				const head = Buffer.alloc(8);
				head.writeUInt32LE(width, 0);
				head.writeUInt32LE(height, 4);
				fs.writeFileSync(path.join(WORK, `${name}.rgba`), Buffer.concat([head, pixels]));
				console.log(`reçu ${name} ${width} × ${height}`);
				res.writeHead(200).end("ok");
			});
			return;
		}
		if (req.method === "GET") {
			const file = path.resolve(ROOT, "." + decodeURIComponent(url.pathname));
			if (!file.startsWith(ROOT + path.sep) || !fs.existsSync(file) || !fs.statSync(file).isFile()) {
				res.writeHead(404).end();
				return;
			}
			res.writeHead(200, { "Content-Type": file.endsWith(".png") ? "image/png" : "application/octet-stream" });
			res.end(fs.readFileSync(file));
			return;
		}
		res.writeHead(405).end();
	});
	server.listen(8765, "127.0.0.1", () => console.log("icon-render : http://127.0.0.1:8765"));
}

const [command, ...args] = process.argv.slice(2);
if (command === "serve") serve();
else if (command === "build") for (const id of args) build(id);
else if (command === "sheet") sheet(path.resolve(args[0]), args.slice(1));
else if (command === "png")
	for (const name of args) {
		const { width, height, px } = readCapture(name);
		fs.writeFileSync(path.join(WORK, `${name}.png`), encodePng(width, height, px));
	}
else {
	console.error("usage : node tools/icon-render.mjs serve | build <item_id>... | sheet <sortie.png> <item_id>... | png <capture>...");
	process.exit(1);
}
