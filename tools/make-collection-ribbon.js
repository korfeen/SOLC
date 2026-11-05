// The Collection book's ribbon bookmark - its way back to the Bedroom (PixCollection.lua): the red ribbon cut out of the
// book's painting (killtracker-art-extra\Collection\raw.png) by its own shape (straight sides, a notched tail), its
// plain silk lengthened so it hangs down from the top of the page, and a gold-thread cross stitched on near its tail
// so it reads as "close". Media/Collection/ribbon.blp (128 x 256).
//   node tools/make-collection-ribbon.js
const fs = require("fs");
const os = require("os");
const path = require("path");
const { decodePng, writeBlp } = require("./convert-art");
const crayon = require("./make-role-icons");

const RAW = path.join(os.homedir(), "killtracker-art-extra", "Collection", "raw.png");
const W = 128, H = 256;
// The ribbon in the painting (painting pixels): its sides, its top, its tail's ends and the notch's point.
const R = { x0: 1146, x1: 1229, top: 912, end: 1004, notch: 984 };
const SILK = { from: 925, to: 950 };  // (plain silk rows: stretched to lengthen it)
const PAD = 12;  // (room round it in the texture, left and right)

const img = decodePng(RAW);
const out = Buffer.alloc(W * H * 4);
const rw = R.x1 - R.x0, scale = (W - 2 * PAD) / rw;
const tail = Math.round((R.end - SILK.to) * scale);  // (the tail as painted, at the bottom)
const headRows = Math.round((SILK.from - R.top) * scale);
// Rows of the texture -> rows of the painting: the head as painted, then the silk stretched, then the tail as painted.
const srcY = (y) => {
  if (y < headRows) return R.top + y / scale;
  if (y >= H - tail) return SILK.to + (y - (H - tail)) / scale;
  return SILK.from + ((y - headRows) / (H - tail - headRows)) * (SILK.to - SILK.from);
};
const notchDepth = (R.end - R.notch) * scale;
for (let y = 0; y < H; y++) {
  const sy = srcY(y);
  for (let x = PAD; x < W - PAD; x++) {
    const u = (x - PAD) / (W - 2 * PAD);  // 0..1 across
    // (the notch: the tail's bottom edge rises to its point in the middle)
    const cut = H - notchDepth * (1 - Math.abs(u - 0.5) * 2);
    if (y >= cut) continue;
    const sx = R.x0 + u * rw;
    const i = (Math.floor(sy) * img.width + Math.floor(sx)) * 4, o = (y * W + x) * 4;
    out[o] = img.rgba[i]; out[o + 1] = img.rgba[i + 1]; out[o + 2] = img.rgba[i + 2];
    // (soft edges: its sides and the notch)
    const edge = Math.min(x - PAD, W - PAD - 1 - x, cut - y);
    out[o + 3] = Math.round(255 * Math.max(0, Math.min(1, (edge + 0.5) / 1.5)));
  }
}
// A gold-thread cross near its tail: two stitched lines, darker under for depth.
crayon.setSize(H);  // (its canvas is square: as tall as the ribbon)
const c = crayon.canvas();
const random = crayon.rng(77);
const cx = W / 2, cy = H - notchDepth - 46, a = 17;
for (const [col, off] of [[[90, 40, 10], 1.5], [[255, 205, 90], 0]]) {
  crayon.stroke(c, [[cx - a + off, cy - a + off], [cx + a + off, cy + a + off]], 6, col, 0.95, random);
  crayon.stroke(c, [[cx + a + off, cy - a + off], [cx - a + off, cy + a + off]], 6, col, 0.95, random);
}
const cross = crayon.toRgba(c);
for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
  const i = y * W + x, j = y * H + x;
  const al = cross[j * 4 + 3] / 255;
  if (!al || !out[i * 4 + 3]) continue;
  for (let k = 0; k < 3; k++) out[i * 4 + k] = Math.round(cross[j * 4 + k] * al + out[i * 4 + k] * (1 - al));
}
writeBlp(path.join(__dirname, "..", "Media", "Collection", "ribbon.blp"), W, H, out);
const look = path.join(os.homedir(), "killtracker-art-extra", "Collection", "ribbon.png");
crayon.writePng(look, W, H, out);
console.log("Wrote Media/Collection/ribbon.blp; look: " + look);
