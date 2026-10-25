// The Pro Shop's walnut mannequin (ProShop.lua): the moss ogre skin (killtracker-art\Skin\Uncommon\moss.png) recoloured
// to polished walnut, with a faint grain running down it. Its olive skin tones turn walnut; the tusks, the eyes' whites
// and the loincloth (a redder brown) stay. Writes Media/ProShop/Mannequin.blp (512, like the skins) and a preview PNG
// beside the source art (killtracker-art-extra\ProShop\mannequin.png).
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

// Its stand (Media/ProShop/Stand.blp, 256 square): a brass pole down the middle onto a round walnut base with a
// brass rim, its shadow on the floor. Sampled 4x4 per pixel so the edges come out soft.
const S = 256;
const mix = (a, b, t) => a.map((v, k) => v + (b[k] - v) * t);
const BRASS_LIT = [0.93, 0.78, 0.42], BRASS_DARK = [0.45, 0.31, 0.12], WALNUT_LIT = [0.42, 0.25, 0.13], WALNUT_DARK = [0.16, 0.09, 0.05];
function stand(x, y) {
  const cx = S / 2, baseY = 214, rx = 92, ry = 24, depth = 12;
  const dx = (x - cx) / rx;
  const top = dx * dx + ((y - baseY) / ry) ** 2;  // (the base's top face)
  const bottom = dx * dx + ((y - baseY - depth) / ry) ** 2;  // (its underside's edge)
  if (Math.abs(x - cx) <= 7 && y < baseY) {  // the pole, lit on its left
    const t = (x - cx + 7) / 14;
    return [...mix(BRASS_LIT, BRASS_DARK, Math.min(1, Math.abs(t - 0.3) * 1.6)), 1];
  }
  if (top <= 1) {
    if (top > 0.82) return [...mix(BRASS_LIT, BRASS_DARK, (y - baseY + ry) / (2 * ry)), 1];  // the brass rim
    return [...mix(WALNUT_LIT, WALNUT_DARK, 0.35 + 0.3 * (y - baseY + ry) / (2 * ry) + 0.03 * grain(x * 3, y * 9)), 1];
  }
  if (Math.abs(dx) <= 1 && (bottom <= 1 || (y > baseY && y < baseY + depth))) {  // its brass side, darker round the back
    return [...mix(BRASS_DARK, [0.25, 0.16, 0.06], Math.abs(dx)), 1];
  }
  const shadow = (dx / 1.25) ** 2 + ((y - baseY - depth - 4) / (ry * 1.25)) ** 2;
  if (shadow <= 1) return [0, 0, 0, 0.45 * (1 - shadow)];
  return null;
}
const rgba = Buffer.alloc(S * S * 4);
for (let y = 0; y < S; y++) for (let x = 0; x < S; x++) {
  let r = 0, g = 0, b = 0, a = 0;
  for (let sy = 0; sy < 4; sy++) for (let sx = 0; sx < 4; sx++) {
    const c = stand(x + (sx + 0.5) / 4, y + (sy + 0.5) / 4);
    if (!c) continue;
    r += c[0] * c[3]; g += c[1] * c[3]; b += c[2] * c[3]; a += c[3];
  }
  const i = (y * S + x) * 4;
  if (a > 0) { rgba[i] = Math.round(r / a * 255); rgba[i + 1] = Math.round(g / a * 255); rgba[i + 2] = Math.round(b / a * 255); }
  rgba[i + 3] = Math.round(a / 16 * 255);
}
writePng(PREVIEW.replace(/\.png$/, "-stand.png"), S, S, rgba);
writeBlp(path.join(path.dirname(OUT), "Stand.blp"), S, S, rgba);
console.log("Wrote Stand.blp");
