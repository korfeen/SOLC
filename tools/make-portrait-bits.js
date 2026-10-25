// The Overview portrait's small pieces (OverviewCard.lua), drawn here with soft edges so they stay smooth in the game
// (a plain colour block turned in WoW gets jagged edges): Media/Overview/Note (the motto's paper), Pin (its pin) and
// Plate (the name plate: rounded, a gilt rim, a rivet at each end; drawn as three slices so it can stretch).
// Run: node tools/make-portrait-bits.js   (restart WoW after: new textures)
const path = require("path");
const { writeBlp } = require("./convert-art");

const OUT = path.join(__dirname, "..", "Media", "Overview");
const clamp = (v) => Math.max(0, Math.min(1, v));
const hash = (x, y) => { let n = (x * 374761393 + y * 668265263) | 0; n = Math.imul(n ^ (n >>> 13), 1274126177); return ((n ^ (n >>> 16)) >>> 0) / 4294967296; };

// A picture from fn(x, y) -> [r, g, b, a] (0..1), sampled 4x4 per pixel so edges come out soft.
function paint(w, h, fn) {
  const rgba = Buffer.alloc(w * h * 4);
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    let r = 0, g = 0, b = 0, a = 0;
    for (let sy = 0; sy < 4; sy++) for (let sx = 0; sx < 4; sx++) {
      const c = fn(x + (sx + 0.5) / 4, y + (sy + 0.5) / 4);
      if (!c) continue;
      r += c[0] * c[3]; g += c[1] * c[3]; b += c[2] * c[3]; a += c[3];
    }
    const i = (y * w + x) * 4;
    if (a > 0) { rgba[i] = Math.round(r / a * 255); rgba[i + 1] = Math.round(g / a * 255); rgba[i + 2] = Math.round(b / a * 255); }
    rgba[i + 3] = Math.round(a / 16 * 255);
  }
  return rgba;
}
// Distance inside a rounded rectangle (negative: outside).
function inside(x, y, x0, y0, x1, y1, r) {
  const qx = Math.max(x0 + r - x, 0, x - (x1 - r)), qy = Math.max(y0 + r - y, 0, y - (y1 - r));
  return Math.min(x - x0, x1 - x, y - y0, y1 - y, r - Math.hypot(qx, qy) + (qx && qy ? 0 : r));
}

// The note: cream paper with a little grain and a darker bottom edge, a soft margin all round (it's turned in game).
const NW = 256, NH = 64, NM = 6;
writeBlp(path.join(OUT, "Note.blp"), NW, NH, paint(NW, NH, (x, y) => {
  if (inside(x, y, NM, NM, NW - NM, NH - NM, 2) < 0) return null;
  const n = (hash(Math.floor(x), Math.floor(y)) - 0.5) * 0.04, shade = 1 - 0.07 * clamp((y - (NH - NM - 10)) / 10);
  return [(0.965 + n) * shade, (0.925 + n) * shade, (0.82 + n) * shade, 1];
}));

// The pin: a red ball with a highlight, a soft shadow under it.
const PS = 32;
writeBlp(path.join(OUT, "Pin.blp"), PS, PS, paint(PS, PS, (x, y) => {
  const cx = 15, cy = 14, r = 9, d = Math.hypot(x - cx, y - cy);
  if (d <= r) {
    const hl = clamp(1 - Math.hypot(x - (cx - 3), y - (cy - 3)) / 6) * 0.7, dark = clamp((d - 4) / 5) * 0.45;
    return [clamp(0.78 + hl * 0.5 - dark), clamp(0.18 + hl - dark * 0.3), clamp(0.13 + hl - dark * 0.3), 1];
  }
  const s = Math.hypot(x - cx - 1.5, y - cy - 2.5);
  return s <= r + 1.5 ? [0, 0, 0, 0.35 * clamp((r + 1.5 - s) / 2)] : null;
}));

// The plate: a dark board in a gilt rim (rounded), a gilt rivet at each end. 128 wide: the game uses its left and
// right 32 as the ends and stretches the middle 64.
const LW = 128, LH = 64, LM = 3, RIM = 2.5;
writeBlp(path.join(OUT, "Plate.blp"), LW, LH, paint(LW, LH, (x, y) => {
  const d = inside(x, y, LM, LM, LW - LM, LH - LM, 8);
  if (d < 0) return null;
  for (const rx of [14, LW - 14]) {
    const rd = Math.hypot(x - rx, y - LH / 2);
    if (rd <= 4) { const hl = clamp(1 - Math.hypot(x - rx + 1.2, y - LH / 2 + 1.2) / 3); return [0.79 + hl * 0.2, 0.63 + hl * 0.3, 0.29 + hl * 0.4, 1]; }
  }
  if (d < RIM) { const t = clamp(1 - Math.abs(y - LH * 0.3) / (LH * 0.7)); return [0.6 + t * 0.35, 0.45 + t * 0.32, 0.18 + t * 0.2, 1]; }
  const g = clamp((y - LM) / (LH - 2 * LM));
  return [0.17 - g * 0.07, 0.1 - g * 0.04, 0.06 - g * 0.03, 1];
}));
// The showcase (OverviewCard.lua): Glow, a soft square glow behind a spot a picture is dragged over (tinted gold in
// game); Dashed, the chalk outline of an empty spot (white, tinted in game).
const GS = 128;
writeBlp(path.join(OUT, "Glow.blp"), GS, GS, paint(GS, GS, (x, y) => {
  const d = inside(x, y, 24, 24, GS - 24, GS - 24, 10);
  const a = d >= 0 ? 1 : clamp(1 + d / 22);
  return a > 0 ? [1, 1, 1, a * a] : null;
}));
writeBlp(path.join(OUT, "Dashed.blp"), GS, GS, paint(GS, GS, (x, y) => {
  const d = inside(x, y, 6, 6, GS - 6, GS - 6, 8);
  if (d < 0 || d > 3) return null;
  const along = Math.abs(x - GS / 2) > Math.abs(y - GS / 2) ? y : x;  // (dashes along whichever side it's on)
  return Math.floor((along + 4) / 10) % 2 === 0 ? [1, 1, 1, 0.9] : null;
}));

console.log("Note, Pin, Plate, Glow and Dashed written to Media/Overview");
