// The Grand Sleepy Pink ogre skin (Ogre Rank 30's): the Pale Lavender skin and every eye and mouth drawn for it,
// recoloured pink - its lavender skin tones turned to a warm pink, the rest (whites, blacks, tusks) left alone - in
// every edition: the painted art (%USERPROFILE%\killtracker-art), crayon (killtracker-art-extra\CrayonHand) and sketch
// (killtracker-art-extra\CrayonArt). Writes Skin\Legendary\grand-sleepy-pink.png and the <...>\grand-sleepy-pink\
// folders beside each pale-lavender one. Then: node tools/convert-art.js (convert-art.js BASE_UNLOCKS locks it to rank 30).
// Usage: node tools/make-pink-skin.js
const fs = require("fs");
const os = require("os");
const path = require("path");
const { decodePng } = require("./convert-art");
const { writePng } = require("./make-role-icons");

const ROOTS = [path.join(os.homedir(), "killtracker-art"), path.join(os.homedir(), "killtracker-art-extra", "CrayonHand"),
  path.join(os.homedir(), "killtracker-art-extra", "CrayonArt")];
const FROM = "pale-lavender", TO = "grand-sleepy-pink";

function rgb2hsv(r, g, b) {
  const mx = Math.max(r, g, b), mn = Math.min(r, g, b), d = mx - mn;
  let h = 0;
  if (d) h = mx === r ? ((g - b) / d) % 6 : mx === g ? (b - r) / d + 2 : (r - g) / d + 4;
  return [(h * 60 + 360) % 360, mx ? d / mx : 0, mx / 255];
}
function hsv2rgb(h, s, v) {
  const c = v * s, x = c * (1 - Math.abs(((h / 60) % 2) - 1)), m = v - c;
  const [r, g, b] = h < 60 ? [c, x, 0] : h < 120 ? [x, c, 0] : h < 180 ? [0, c, x] : h < 240 ? [0, x, c] : h < 300 ? [x, 0, c] : [c, 0, x];
  return [r, g, b].map((t) => Math.round((t + m) * 255));
}
// Lavender (hue ~311) to pink (~333): more colourful and a little brighter. Greys, whites and blacks stay.
function recolour(file, out) {
  const img = decodePng(file), px = Buffer.from(img.rgba);
  for (let i = 0; i < px.length; i += 4) {
    if (!px[i + 3]) continue;
    const [h, s, v] = rgb2hsv(px[i], px[i + 1], px[i + 2]);
    if (s < 0.07 || h < 265 || h > 352) continue;
    const [r, g, b] = hsv2rgb((h + 28) % 360, Math.min(1, s * 1.6), Math.min(1, v * 1.15));
    px[i] = r; px[i + 1] = g; px[i + 2] = b;
  }
  fs.mkdirSync(path.dirname(out), { recursive: true });
  writePng(out, img.width, img.height, px);
}
const walk = (dir) => fs.readdirSync(dir, { withFileTypes: true }).flatMap((e) => e.isDirectory() ? walk(path.join(dir, e.name)) : [path.join(dir, e.name)]);
let n = 0;
for (const root of ROOTS) {
  if (!fs.existsSync(root)) continue;
  for (const file of walk(root)) {
    const rel = path.relative(root, file);
    let out = null;
    if (rel.split(path.sep)[0] === "Skin" && path.basename(file) === FROM + ".png") out = path.join(root, "Skin", "Legendary", TO + ".png");
    else if (/^(Eyes|Expression)$/.test(rel.split(path.sep)[0]) && rel.split(path.sep).includes(FROM) && file.endsWith(".png")) out = file.replace(path.sep + FROM + path.sep, path.sep + TO + path.sep);
    if (!out) continue;
    recolour(file, out);
    n++;
  }
}
console.log(`Grand Sleepy Pink: ${n} files recoloured from ${FROM}`);
