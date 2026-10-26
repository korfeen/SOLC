// The pictures' small crayon icons (once part of the minting kitchen's art, gone with the kitchen): a picture's outline
// (Gallery.lua's dragged picture) and the three editions' icons (OverviewCard.lua's trait lines). Same drawings and
// seeds as before, so they come out as they were.
// Writes Media/Icons/Picture/<name>.blp (Outline 256x256, the editions 128x128).
// Usage: node tools/make-picture-icons.js   No dependencies.

const fs = require("fs");
const path = require("path");
const crayon = require("./make-role-icons");
const { resize, writeBlp, bleedEdges } = require("./convert-art");

crayon.setSize(256);
const { canvas, stroke, crayonShape, rotate, hex, rng } = crayon;
const MEDIA = path.join(__dirname, "..", "Media", "Icons", "Picture");
const fill = (c, poly, col, r, o = {}) => crayonShape(c, poly, typeof col === "string" ? hex(col) : col, r, { line: 12, hatch: 7, ...o });
const line = (c, pts, w, col, r) => stroke(c, pts, w, typeof col === "string" ? hex(col) : col, 0.95, r);

// { name: [seed, size, draw] }
const PIECES = {
  // A picture's outline (white, tinted to its rarity in the game), with room round it so it can turn (Gallery.lua's
  // dragged picture tilts): the square is 208 of the 256, from 24 to 232.
  Outline: [436426, 256, (c, r) => line(c, [[24, 24], [232, 24], [232, 232], [24, 232], [24, 24]], 9, "#ffffff", r)],
  // A layer's edition, at the end of its trait line (OverviewCard.lua): painted (a brush), crayon, sketch (a pencil).
  EdPainted: [444345, 128, (c, r) => {
    line(c, [[60, 220], [170, 100]], 22, "#8a5a30", r);
    fill(c, [[160, 112], [178, 92], [196, 98], [214, 60], [226, 40], [206, 52], [176, 76], [150, 96]], "#c8c8d0", r, { line: 8 });
    fill(c, [[196, 98], [234, 30], [244, 40], [214, 104]], "#4a8ad8", r, { line: 8 });
  }],
  EdCrayon: [452264, 128, (c, r) => {
    fill(c, rotate([[100, 60], [156, 60], [156, 210], [100, 210]], 0.6, 128, 135), "#e04848", r);
    fill(c, rotate([[100, 60], [128, 18], [156, 60]], 0.6, 128, 135), "#e04848", r, { line: 8 });
    for (const y of [100, 170]) line(c, rotate([[100, y], [156, y]], 0.6, 128, 135), 8, "#f0e0d0", r);
  }],
  EdSketch: [460183, 128, (c, r) => {
    fill(c, rotate([[108, 50], [148, 50], [148, 200], [108, 200]], 0.6, 128, 135), "#e8c050", r);
    fill(c, rotate([[108, 50], [128, 14], [148, 50]], 0.6, 128, 135), "#e8d0a0", r, { line: 8 });
    fill(c, rotate([[120, 28], [128, 14], [136, 28]], 0.6, 128, 135), "#3a3236", r, { line: 4 });
    fill(c, rotate([[108, 200], [148, 200], [148, 222], [108, 222]], 0.6, 128, 135), "#e88a9a", r, { line: 8 });
  }],
};

fs.mkdirSync(MEDIA, { recursive: true });
for (const [name, [seed, size, draw]] of Object.entries(PIECES)) {
  const c = canvas();
  draw(c, rng(seed));
  const small = Buffer.from(resize({ width: 256, height: 256, rgba: crayon.toRgba(c) }, size));
  bleedEdges(small, size, size);
  writeBlp(path.join(MEDIA, name + ".blp"), size, size, small);
}
console.log(`Wrote ${Object.keys(PIECES).length} picture icons to ${MEDIA}`);
