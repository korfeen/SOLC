// The Pro Shop's stand-in art (ProShopRoom.lua). The walnut mannequin: the moss ogre skin (killtracker-art\Skin\Uncommon\moss.png) recoloured
// to polished walnut, with a faint grain running down it. Its olive skin tones turn walnut; the tusks, the eyes' whites
// and the loincloth (a redder brown) stay. Writes Media/ProShop/Mannequin.blp (512, like the skins) and a preview PNG
// beside the source art (killtracker-art-extra\ProShop\mannequin.png). And the room, below.
// Run: node tools/make-mannequin.js   (restart WoW after: new texture)
const fs = require("fs");
const os = require("os");
const path = require("path");
const { decodePng, resize, writeBlp } = require("./convert-art");
const { writePng } = require("./make-role-icons");

const SOURCE = path.join(os.homedir(), "killtracker-art", "Skin", "Uncommon", "moss.png");
const OUT = path.join(__dirname, "..", "Media", "ProShop", "Mannequin.blp");
const PREVIEW = path.join(os.homedir(), "killtracker-art-extra", "ProShop", "mannequin.png");

function rgb2hsv(r, g, b) {
  const mx = Math.max(r, g, b), mn = Math.min(r, g, b), d = mx - mn;
  let h = 0;
  if (d) h = mx === r ? ((g - b) / d) % 6 : mx === g ? (b - r) / d + 2 : (r - g) / d + 4;
  return [(h * 60 + 360) % 360, mx ? d / mx : 0, mx / 255];
}
function hsv2rgb(h, s, v) {
  const c = v * s, x = c * (1 - Math.abs(((h / 60) % 2) - 1)), m = v - c;
  const [r, g, b] = h < 60 ? [c, x, 0] : h < 120 ? [x, c, 0] : h < 180 ? [0, c, x] : h < 240 ? [0, x, c] : h < 300 ? [x, 0, c] : [c, 0, x];
  return [r, g, b].map((t) => Math.round(Math.max(0, Math.min(1, t + m)) * 255));
}
// The grain: soft streaks running down, wavering a little, from a few sine waves (no randomness: same every run).
function grain(x, y) {
  const u = x + 9 * Math.sin(y / 97) + 4 * Math.sin(y / 31 + x / 211);
  return 0.6 * Math.sin(u / 5.3) + 0.3 * Math.sin(u / 2.1 + 1.7) + 0.1 * Math.sin(u / 13.7);
}

const img = decodePng(SOURCE), px = Buffer.from(img.rgba);
for (let i = 0; i < px.length; i += 4) {
  if (!px[i + 3]) continue;
  const [h, s, v] = rgb2hsv(px[i], px[i + 1], px[i + 2]);
  if (s < 0.12 || h < 30 || h > 90) continue;  // (whites, darks and the loincloth stay)
  const p = i / 4, x = p % img.width, y = Math.floor(p / img.width);
  const value = v * 0.7 * (1 + 0.08 * grain(x, y));
  const [r, g, b] = hsv2rgb(27 + (h - 50) * 0.15, Math.min(1, s * 0.9 + 0.06), value);
  px[i] = r; px[i + 1] = g; px[i + 2] = b;
}
fs.mkdirSync(path.dirname(PREVIEW), { recursive: true });
writePng(PREVIEW, img.width, img.height, px);
fs.mkdirSync(path.dirname(OUT), { recursive: true });
writeBlp(OUT, 512, 512, resize({ width: img.width, height: img.height, rgba: px }, 512));
console.log("Wrote " + OUT + " and " + PREVIEW);

// The room until the shop floor is repainted: the concept painting (tools/proshop-mock/img/scene1.png, 827 x 584, the
// page's size) in the top-left of a 1024 square (ProShopRoom.lua shows that part): Media/ProShop/Room.blp.
const SCENE = path.join(__dirname, "proshop-mock", "img", "scene1.png");
const scene = decodePng(SCENE), room = Buffer.alloc(1024 * 1024 * 4);
for (let y = 0; y < scene.height; y++) scene.rgba.copy(room, y * 1024 * 4, y * scene.width * 4, (y + 1) * scene.width * 4);
writeBlp(path.join(path.dirname(OUT), "Room.blp"), 1024, 1024, room);
console.log("Wrote Room.blp (" + scene.width + " x " + scene.height + ")");
