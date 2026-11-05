// Each wallpaper's PLAIN border (a simple band in three of its colours, like a painted stripe: dark edge, main colour,
// light middle, mirrored) - its colours picked from its tile (killtracker-art-extra\Wallpapers\<id>\tile.png): the
// most colourful of its main colours (the bands), that darkened (the edges), its lightest (the middle). Written into
// WallpaperData.lua as plain = { dark, main, light } (0..1); Wallpaper.lua draws the band with plain colour.
//   node tools/plain-borders.js
const fs = require("fs");
const os = require("os");
const path = require("path");
const { decodePng } = require("./convert-art");

const ROOT = path.join(os.homedir(), "killtracker-art-extra", "Wallpapers");
const DATA = path.join(__dirname, "..", "WallpaperData.lua");
function palette(img, k = 6) {
  const px = [];
  for (let i = 0; i < img.rgba.length; i += 4 * 11) px.push([img.rgba[i], img.rgba[i + 1], img.rgba[i + 2]]);
  let c = Array.from({ length: k }, (_, i) => px[Math.floor((i + 0.5) * px.length / k)].slice()), n;
  for (let r = 0; r < 14; r++) {
    const s = c.map(() => [0, 0, 0]); n = c.map(() => 0);
    for (const p of px) { let b = 0, bd = Infinity; c.forEach((q, j) => { const d = (p[0] - q[0]) ** 2 + (p[1] - q[1]) ** 2 + (p[2] - q[2]) ** 2; if (d < bd) { bd = d; b = j; } }); for (let t = 0; t < 3; t++) s[b][t] += p[t]; n[b]++; }
    c = c.map((q, j) => (n[j] ? s[j].map((v) => v / n[j]) : q));
  }
  return c.map((q, j) => ({ c: q, share: n[j] / px.length, sat: (Math.max(...q) - Math.min(...q)) / (Math.max(...q) || 1), lum: q[0] * 0.3 + q[1] * 0.59 + q[2] * 0.11 }));
}
let data = fs.readFileSync(DATA, "utf8");
for (const id of fs.readdirSync(ROOT)) {
  const tile = path.join(ROOT, id, "tile.png");
  if (!fs.existsSync(tile) || !new RegExp(String.raw`^\s+${id} = `, "m").test(data)) continue;
  const pal = palette(decodePng(tile)).filter((p) => p.share > 0.03);
  const score = (p) => p.sat * (p.lum / 255) * Math.pow(p.share, 0.25);  // (colourful, bright, not a speck: not a dark ground)
  const main = pal.reduce((a, b) => (score(b) > score(a) ? b : a));
  const light = pal.reduce((a, b) => (b.lum > a.lum ? b : a));
  const dark = main.c.map((v) => v * 0.62);
  const f = (c) => `{ ${c.map((v) => (v / 255).toFixed(3)).join(", ")} }`;
  const plain = `plain = { ${f(dark)}, ${f(main.c)}, ${f(light.c)} }`;
  data = data.replace(new RegExp(String.raw`^(\s+${id} = \{ aspect = [\d.]+(?:, border = [\d.]+)?)(?:, plain = \{.*?\} \})? \},`, "m"), `$1, ${plain} },`);
  console.log(id.padEnd(14), "main", main.c.map(Math.round).join(","), " light", light.c.map(Math.round).join(","));
}
fs.writeFileSync(DATA, data);
