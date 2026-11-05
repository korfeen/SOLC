// A rounded rectangle, white (tinted in game), for plates drawn as nine pieces so the corners stay round at any size
// (CavePage.lua's podium plates): Media/Overview/RoundPlate.blp, 32 square, corner radius 10, soft edges.
//   node tools/make-round-plate.js
const path = require("path");
const { writeBlp } = require("./convert-art");
const S = 32, R = 10, out = Buffer.alloc(S * S * 4);
for (let y = 0; y < S; y++) for (let x = 0; x < S; x++) {
  let n = 0;
  for (let sy = 0; sy < 4; sy++) for (let sx = 0; sx < 4; sx++) {
    const px = x + (sx + 0.5) / 4, py = y + (sy + 0.5) / 4;
    const cx = Math.min(Math.max(px, R), S - R), cy = Math.min(Math.max(py, R), S - R);
    if (Math.hypot(px - cx, py - cy) <= R) n++;
  }
  out.set([255, 255, 255, Math.round((n / 16) * 255)], (y * S + x) * 4);
}
writeBlp(path.join(__dirname, "..", "Media", "Overview", "RoundPlate.blp"), S, S, out);
console.log("Wrote Media/Overview/RoundPlate.blp");
