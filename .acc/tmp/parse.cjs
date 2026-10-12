// Extrait la vitrine Inventaire d'un .rbxl binaire (lecture seule).
const fs = require('fs');
const zlib = require('zlib');
const buf = fs.readFileSync(process.argv[2]);

function lz4(src, outLen) {
  const out = Buffer.alloc(outLen); let i = 0, o = 0;
  while (i < src.length) {
    const tok = src[i++]; let lit = tok >> 4;
    if (lit === 15) { let b; do { b = src[i++]; lit += b; } while (b === 255); }
    src.copy(out, o, i, i + lit); i += lit; o += lit;
    if (i >= src.length) break;
    const off = src[i] | (src[i + 1] << 8); i += 2;
    let ml = tok & 15;
    if (ml === 15) { let b; do { b = src[i++]; ml += b; } while (b === 255); }
    ml += 4;
    for (let k = 0; k < ml; k++) { out[o] = out[o - off]; o++; }
  }
  return out;
}

let p = 32; const chunks = [];
while (p < buf.length) {
  const name = buf.toString('latin1', p, p + 4).replace(/\0/g, '');
  const clen = buf.readUInt32LE(p + 4), ulen = buf.readUInt32LE(p + 8); p += 16;
  let data;
  if (clen === 0) { data = buf.subarray(p, p + ulen); p += ulen; }
  else {
    const raw = buf.subarray(p, p + clen); p += clen;
    if (raw.readUInt32LE(0) === 0xFD2FB528) data = zlib.zstdDecompressSync(raw);
    else data = lz4(raw, ulen);
  }
  chunks.push({ name, data });
  if (name === 'END') break;
}

function deinterleave(d, off, count, size) {
  const out = [];
  for (let i = 0; i < count; i++) { let v = 0; for (let b = 0; b < size; b++) v = v * 256 + d[off + b * count + i]; out.push(v >>> 0); }
  return out;
}
const untransform = (v) => (v % 2 === 0 ? v / 2 : -(v + 1) / 2);
function refs(d, off, count) {
  const raw = deinterleave(d, off, count, 4); let acc = 0;
  return raw.map((v) => (acc += untransform(v)));
}
function readStr(d, o) { const n = d.readUInt32LE(o); return [d.subarray(o + 4, o + 4 + n), o + 4 + n]; }

const classes = {}; const inst = {};
for (const c of chunks) {
  const d = c.data;
  if (c.name === 'INST') {
    const id = d.readUInt32LE(0); const [cn, o] = readStr(d, 4);
    const count = d.readUInt32LE(o + 1);
    const ids = refs(d, o + 5, count);
    classes[id] = { name: cn.toString(), ids };
    for (const r of ids) inst[r] = { cls: cn.toString(), props: {}, children: [] };
  }
}
for (const c of chunks) {
  const d = c.data;
  if (c.name === 'PROP') {
    const id = d.readUInt32LE(0); let [pn, o] = readStr(d, 4); pn = pn.toString();
    const type = d[o]; o++;
    if (!['Name', 'Text', 'AttributesSerialize', 'Image'].includes(pn) && !(pn === 'AttributesSerialize')) continue;
    if (type !== 1) continue;
    for (const r of classes[id].ids) { const [s, n] = readStr(d, o); o = n; inst[r].props[pn] = s; }
  } else if (c.name === 'PRNT') {
    const count = d.readUInt32LE(1);
    const ch = refs(d, 5, count), pa = refs(d, 5 + count * 4, count);
    for (let i = 0; i < count; i++) { inst[ch[i]].parent = pa[i]; if (inst[pa[i]]) inst[pa[i]].children.push(ch[i]); }
  }
}
function attrs(b) {
  const out = {}; if (!b || b.length < 4) return out;
  let o = 0; const n = b.readUInt32LE(o); o += 4;
  for (let i = 0; i < n; i++) {
    let k; [k, o] = readStr(b, o); k = k.toString(); const t = b[o++];
    if (t === 2) { let s; [s, o] = readStr(b, o); out[k] = s.toString(); }
    else if (t === 3) { out[k] = !!b[o]; o += 1; }
    else if (t === 5) { out[k] = b.readFloatLE(o); o += 4; }
    else if (t === 6) { out[k] = b.readDoubleLE(o); o += 8; }
    else if (t === 0x0E) { o += 12; out[k] = '<Vector3>'; }
    else if (t === 0x0F) { o += 12; out[k] = '<Color3>'; }
    else { out[k] = `<type ${t}>`; break; }
  }
  return out;
}
const nameOf = (r) => inst[r].props.Name ? inst[r].props.Name.toString() : '?';
function path(r) { const parts = []; while (r !== undefined && inst[r]) { parts.unshift(nameOf(r)); r = inst[r].parent; } return parts.join('.'); }
function find(r, n) { return inst[r].children.find((c) => nameOf(c) === n); }

const mode = process.argv[3] || 'items';
const all = Object.keys(inst).map(Number);
if (mode === 'tree') {
  const root = all.find((r) => nameOf(r) === 'Inventaire');
  const walk = (r, depth, max) => {
    if (depth > max) return;
    const a = attrs(inst[r].props.AttributesSerialize);
    console.log('  '.repeat(depth) + nameOf(r) + ' [' + inst[r].cls + ']' + (inst[r].props.Text ? ' text=' + JSON.stringify(inst[r].props.Text.toString()) : '') + (Object.keys(a).length ? ' ' + JSON.stringify(a) : ''));
    const kids = inst[r].children;
    kids.slice(0, depth >= 5 ? 2 : 40).forEach((c) => walk(c, depth + 1, max));
  };
  console.log(path(root)); walk(root, 0, Number(process.argv[4] || 12));
} else {
  const items = all.filter((r) => /^Item_\d{3}$/.test(nameOf(r)));
  const rows = items.map((r) => {
    const a = attrs(inst[r].props.AttributesSerialize);
    const nom = find(r, 'Nom');
    return { slot: nameOf(r), path: path(r), nom: nom && inst[nom].props.Text ? inst[nom].props.Text.toString() : null, ...a };
  }).sort((x, y) => x.slot.localeCompare(y.slot));
  console.log(JSON.stringify(rows, null, 1));
}
