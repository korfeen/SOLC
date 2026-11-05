// The Pro Shop steward's own skin, Club Sage: the Slate Gray skin and every eye and mouth drawn for it, tinted a pale,
// powdered grey-green - its grey skin only (little colour), the rest (eye whites, cloth, lips) left alone - in every
// edition: the painted art (%USERPROFILE%\killtracker-art), crayon (killtracker-art-extra\CrayonHand) and sketch
// (killtracker-art-extra\CrayonArt). Writes Skin\Legendary\club-sage.png and the <...>\club-sage\ folders beside each
// slate-gray one. (2026-11-02: from moss it came out blotchy - moss's browns and highlights stayed; grey tints evenly.)
// Unlocked by the Pro Shop spending deeds (convert-art.js BASE_UNLOCKS).
// Then: node tools/faces-to-skins.js for faces made on moss (their club-sage copies), node tools/convert-art.js
// Usage: node tools/make-steward-skin.js
const fs = require("fs");
const os = require("os");
const path = require("path");
const { decodePng } = require("./convert-art");
const { writePng } = require("./make-role-icons");

const ROOTS = [path.join(os.homedir(), "killtracker-art"), path.join(os.homedir(), "killtracker-art-extra", "CrayonHand"),
  path.join(os.homedir(), "killtracker-art-extra", "CrayonArt")];
const FROM = "slate-gray", TO = "club-sage";
const TINT = [1.31, 1.45, 1.04];  // (slate's face ~105,101,100 -> sage ~138,147,104)

function satVal(r, g, b) { const mx = Math.max(r, g, b), mn = Math.min(r, g, b); return [mx ? (mx - mn) / mx : 0, mx / 255]; }
// Grey skin (saturation under 0.16, not near white): tinted by TINT.
function recolour(file, out) {
  const img = decodePng(file), px = Buffer.from(img.rgba);
  for (let i = 0; i < px.length; i += 4) {
    if (!px[i + 3]) continue;
    const [s, v] = satVal(px[i], px[i + 1], px[i + 2]);
    if (s > 0.16 || v > 0.86) continue;
    for (let c = 0; c < 3; c++) px[i + c] = Math.min(255, Math.round(px[i + c] * TINT[c]));
  }
  fs.mkdirSync(path.dirname(out), { recursive: true });
  writePng(out, img.width, img.height, px);
}

const walk = (dir) => fs.readdirSync(dir, { withFileTypes: true }).flatMap((e) => e.isDirectory() ? walk(path.join(dir, e.name)) : [path.join(dir, e.name)]);
let n = 0;
for (const root of ROOTS) {
  if (!fs.existsSync(root)) continue;
  for (const file of walk(root)) {
    const rel = path.relative(root, file), top = rel.split(path.sep)[0];
    let out = null;
    if (top === "Skin" && path.basename(file) === FROM + ".png") out = path.join(root, "Skin", "Legendary", TO + ".png");
    else if (/^(Eyes|Expression)$/.test(top) && rel.split(path.sep).includes(FROM) && file.endsWith(".png")) out = file.replace(path.sep + FROM + path.sep, path.sep + TO + path.sep);
    if (!out) continue;
    recolour(file, out);
    n++;
  }
}
console.log(`Club Sage: ${n} files tinted from ${FROM}`);
