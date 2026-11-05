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
const SCENE = path.join(__dirname, "proshop-mock", "img", "scene3.png");  // (repainted 2026-11-01: tools/gen-proshop-room.js)
const scene = decodePng(SCENE), room = Buffer.alloc(1024 * 1024 * 4);
for (let y = 0; y < scene.height; y++) scene.rgba.copy(room, y * 1024 * 4, y * scene.width * 4, (y + 1) * scene.width * 4);
writeBlp(path.join(path.dirname(OUT), "Room.blp"), 1024, 1024, room);
console.log("Wrote Room.blp (" + scene.width + " x " + scene.height + ")");

// Its blurred twin (Media/ProShop/Room-blur.blp): what the room looks like behind the curtains when you zoom in (WoW
// can't blur live, so it crossfades to this). Three box blurs of radius 3 ~ a gaussian of about 3 px.
function boxBlur(src, w, h, r) {
  const out = Buffer.alloc(src.length), tmp = Buffer.alloc(src.length);
  for (const [from, to, horizontal] of [[src, tmp, true], [tmp, out, false]]) {
    for (let a = 0; a < (horizontal ? h : w); a++) for (let b = 0; b < (horizontal ? w : h); b++) {
      const sum = [0, 0, 0, 0];
      for (let k = -r; k <= r; k++) {
        const c = Math.max(0, Math.min((horizontal ? w : h) - 1, b + k));
        const i = horizontal ? (a * w + c) * 4 : (c * w + a) * 4;
        for (let ch = 0; ch < 4; ch++) sum[ch] += from[i + ch];
      }
      const o = horizontal ? (a * w + b) * 4 : (b * w + a) * 4;
      for (let ch = 0; ch < 4; ch++) to[o + ch] = Math.round(sum[ch] / (2 * r + 1));
    }
  }
  return out;
}
let blurred = Buffer.from(scene.rgba);
for (let pass = 0; pass < 3; pass++) blurred = boxBlur(blurred, scene.width, scene.height, 3);
const blurRoom = Buffer.alloc(1024 * 1024 * 4);
for (let y = 0; y < scene.height; y++) blurred.copy(blurRoom, y * 1024 * 4, y * scene.width * 4, (y + 1) * scene.width * 4);
writeBlp(path.join(path.dirname(OUT), "Room-blur.blp"), 1024, 1024, blurRoom);
console.log("Wrote Room-blur.blp");

// The room's front (Media/ProShop/RoomFront.blp, laid like Room.blp): the counter and the till on it, cut out of the
// painting, the rest see-through - drawn over the steward (ProShopRoom.lua: one of our ogres, standing behind them).
// The counter: from its top board down (FRONT.counter); the till: its display and body whole (boxes), the thin crank on
// its left by its brass (warm, colourful, bright pixels), gaps closed, and its wooden base. Painting pixels.
// (2026-11-02: the till traced by hand round its real shape instead - display, body, crank, base - edges soft.)
const FRONT = { counter: { x0: 252, x1: 578, y0: 319 },
  till: [[490, 236], [494, 231], [545, 231], [548, 236], [548, 252], [553, 256], [556, 262], [555, 303], [559, 306], [559, 321],
    [465, 321], [465, 312], [470, 306], [462, 296], [461, 289], [470, 283], [472, 268], [478, 264], [482, 256], [489, 251]] };
const inside = (poly, x, y) => { let c = false; for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) { const [xi, yi] = poly[i], [xj, yj] = poly[j];
  if ((yi > y) !== (yj > y) && x < ((xj - xi) * (y - yi)) / (yj - yi) + xi) c = !c; } return c; };
const front = Buffer.alloc(1024 * 1024 * 4), on = new Uint8Array(scene.width * scene.height);
const hueSat = (r, g, b) => {
  const mx = Math.max(r, g, b), mn = Math.min(r, g, b), d = mx - mn;
  let h = 0;
  if (d) h = mx === r ? ((g - b) / d) % 6 : mx === g ? (b - r) / d + 2 : (r - g) / d + 4;
  return [(h * 60 + 360) % 360, mx ? d / mx : 0, mx / 255];
};
// (each pixel: how much of it is the counter or the till, 4x4 samples - soft edges)
for (let y = 0; y < scene.height; y++) for (let x = 0; x < scene.width; x++) {
  let n = 0;
  for (let sy = 0; sy < 4; sy++) for (let sx = 0; sx < 4; sx++) {
    const px = x + (sx + 0.5) / 4, py = y + (sy + 0.5) / 4, c = FRONT.counter;
    if ((px >= c.x0 && px <= c.x1 && py >= c.y0) || inside(FRONT.till, px, py)) n++;
  }
  if (!n) continue;
  scene.rgba.copy(front, (y * 1024 + x) * 4, (y * scene.width + x) * 4, (y * scene.width + x) * 4 + 4);
  front[(y * 1024 + x) * 4 + 3] = Math.round((n / 16) * 255);
}
writeBlp(path.join(path.dirname(OUT), "RoomFront.blp"), 1024, 1024, front);
writePng(path.join(path.dirname(PREVIEW), "room-front.png"), 1024, 1024, front);
console.log("Wrote RoomFront.blp");
