// A new face (gen-face.js paints it on moss: killtracker-art-extra\Faces\<layer>\<id>_moss.png) made for every skin, as
// the game wants per-skin eyes and mouths: %USERPROFILE%\killtracker-art\<Eyes|Expression>\<rarity>\<skin>\<id>.png.
// Its skin parts take each skin's tone from the skins themselves: where the face shows skin, its colour is multiplied by
// (that skin / moss) at the same spot of the body - shading, freckles and all. Eye whites, teeth, tusks and dark lines
// (little colour, or not moss's olive) stay as they are. Painted only (no crayon or sketch twins yet).
//
//   node tools/faces-to-skins.js <eyes|expression> <id> <rarity>      e.g. eyes snooty_eyes Epic
// Then: node tools/convert-art.js
const fs = require("fs");
const os = require("os");
const path = require("path");
const { decodePng } = require("./convert-art");
const { writePng } = require("./make-role-icons");

const ART = path.join(os.homedir(), "killtracker-art");
const FACES = path.join(os.homedir(), "killtracker-art-extra", "Faces");
const [layer, id, rarity] = process.argv.slice(2);
const FOLDER = { eyes: "Eyes", expression: "Expression" }[layer];
if (!FOLDER || !id || !rarity) throw new Error("Usage: node tools/faces-to-skins.js <eyes|expression> <id> <Uncommon|Rare|Epic|Legendary>");

function hsv(r, g, b) {
  const mx = Math.max(r, g, b), mn = Math.min(r, g, b), d = mx - mn;
  let h = 0;
  if (d) h = mx === r ? ((g - b) / d) % 6 : mx === g ? (b - r) / d + 2 : (r - g) / d + 4;
  return [(h * 60 + 360) % 360, mx ? d / mx : 0];
}
// (the skins: Skin\<rarity>\<id>.png)
const skins = {};
for (const r of fs.readdirSync(path.join(ART, "Skin"))) {
  for (const f of fs.readdirSync(path.join(ART, "Skin", r))) if (f.endsWith(".png")) skins[f.slice(0, -4)] = path.join(ART, "Skin", r, f);
}
const face = decodePng(path.join(FACES, layer, id + "_moss.png")), moss = decodePng(skins.moss);
const file = id.replace(/_/g, "-") + ".png";
for (const [skin, skinFile] of Object.entries(skins)) {
  const target = skin === "moss" ? null : decodePng(skinFile), px = Buffer.from(face.rgba);
  if (target) {
    for (let i = 0; i < px.length; i += 4) {
      if (!px[i + 3]) continue;
      const [h, s] = hsv(px[i], px[i + 1], px[i + 2]);
      if (s < 0.2 || h < 15 || h > 65) continue;  // (not skin: whites, teeth, tusks, lines)
      for (let c = 0; c < 3; c++) {
        const k = Math.min(3, (target.rgba[i + c] + 4) / (moss.rgba[i + c] + 4));
        px[i + c] = Math.max(0, Math.min(255, Math.round(px[i + c] * k)));
      }
    }
  }
  const out = path.join(ART, FOLDER, rarity, skin, file);
  fs.mkdirSync(path.dirname(out), { recursive: true });
  writePng(out, face.width, face.height, px);
}
console.log(`${FOLDER}/${rarity}/<skin>/${file}: ${Object.keys(skins).length} skins`);
