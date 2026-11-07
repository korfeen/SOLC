// Turns a painted piece's green parts (left by Codex's green screen: smoke, a glow) into a see-through colour: each
// green pixel takes the target colour at its own brightness, and its opacity from how green it was (strong green: more
// solid). Everything else stays. The original is kept beside it as <id>.green-backup.png (first run only).
//   node tools/green-to-glass.js <piece id> [colour hex, default c8c8c8 grey] [opacity 0-1, default 0.6]
// Then fit and save it in the item fitter as usual (it reads the painted png).
const fs = require("fs");
const path = require("path");
const os = require("os");
const { decodePng } = require("./convert-art");
const { png } = require("./render-picture.js");

const [id, hex = "c8c8c8", opacityArg = "0.6"] = process.argv.slice(2);
if (!id) throw Error("usage: node tools/green-to-glass.js <piece id> [hex] [opacity]");
const GEN = path.join(os.homedir(), "killtracker-art-extra", "Unlocks", "generated");
const file = path.join(GEN, "painted", id + ".png");
const backup = path.join(GEN, "painted", id + ".green-backup.png");
if (!fs.existsSync(backup)) fs.copyFileSync(file, backup);
const img = decodePng(backup);  // (always from the original: running it again re-tints, it doesn't stack)
const target = [0, 2, 4].map((i) => parseInt(hex.slice(i, i + 2), 16));
const opacity = Number(opacityArg);
let changed = 0;
for (let i = 0; i < img.rgba.length; i += 4) {
  const r = img.rgba[i], g = img.rgba[i + 1], b = img.rgba[i + 2], a = img.rgba[i + 3];
  const green = g - Math.max(r, b);  // (how much greener than it is red or blue)
  if (a === 0 || green < 30) continue;
  const strength = Math.min(1, green / 160);
  const bright = (r + g + b) / (3 * 255);
  for (let c = 0; c < 3; c++) img.rgba[i + c] = Math.round(target[c] * (0.55 + 0.45 * bright));
  img.rgba[i + 3] = Math.round(a * opacity * (0.35 + 0.65 * strength));
  changed++;
}
fs.writeFileSync(file, png({ width: img.width, height: img.height, rgba: img.rgba }));
console.log(`${id}: ${changed} green pixels now see-through #${hex} (original: ${path.basename(backup)})`);
