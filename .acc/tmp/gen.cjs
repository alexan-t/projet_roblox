const { execFileSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const root = path.resolve(__dirname, '..', '..');
const rows = JSON.parse(execFileSync('node', [path.join(__dirname, 'parse.cjs'), path.join(root, 'studio/sandbox/partner_sandbox_v4.rbxl'), 'items'], { maxBuffer: 1 << 26 }).toString());
const ids = { 'Commun': 'Commun', 'Peu commun': 'PeuCommun', 'Rare': 'Rare', 'Épique': 'Epique', 'Légendaire': 'Legendaire', 'Mythique': 'Mythique', 'Maudit': 'Maudit', 'Suprême': 'Supreme', 'Calamité': 'Calamite', 'Transcendant': 'Transcendant' };
let out = ''; let last = null;
rows.forEach((r, i) => {
  if (r.Index !== i + 1 || r.ItemId !== `item_${String(i + 1).padStart(3, '0')}` || r.slot !== `Item_${String(i + 1).padStart(3, '0')}`) throw new Error('ordre ' + r.slot);
  if (!ids[r.Rarete]) throw new Error('rareté ' + r.Rarete);
  if (r.Rarete !== last) { out += `-- ${r.Rarete}\n`; last = r.Rarete; }
  out += `item(${JSON.stringify(r.ItemId)}, ${JSON.stringify(r.nom)}, ${JSON.stringify(ids[r.Rarete])}, ${JSON.stringify(r.SlotType)})\n`;
});
fs.writeFileSync(path.join(__dirname, 'items.lua'), out);
console.log(rows.length, 'items');
