// The top beam's edit button (UI.lua's header buttons, beside Settings and Close: on the Overview, your look): a
// paintbrush in the header icons' crayon - off-white, a thick dark outline - its bristles dipped in orange paint, a
// drip off the tip; lying corner to corner, the bristles bottom-left. Drawn by code with tools/make-role-icons.js's
// crayon. Writes Media/Icons/EditBrush.blp (128x128, from 256).
// Usage: node tools/make-edit-brush.js [preview.png]   No dependencies.
const path = require("path");
const crayon = require("./make-role-icons");
const { resize, writeBlp } = require("./convert-art");

const S = 256;
crayon.setSize(S);
const { canvas, crayonShape, stroke, dab, hex, rng, toRgba } = crayon;
const c = canvas(), r = rng(7);
const WHITE = hex("#f3eee2"), PAINT = hex("#ff8a2a"), INK = hex("#2b1a10");

// Along the brush: t from the bristles' tip (0) to the handle's end (1), on the diagonal; side: off its middle.
const A = [40, 216], B = [220, 36];
const along = (t, side) => {
  const dx = B[0] - A[0], dy = B[1] - A[1], len = Math.hypot(dx, dy), nx = -dy / len, ny = dx / len;
  return [A[0] + dx * t + nx * side, A[1] + dy * t + ny * side];
};

// The handle (a touch thicker towards the end, rounded off), the ferrule, the bristles to a point (orange: the paint).
crayonShape(c, [along(0.44, -14), along(0.94, -19), along(0.99, -10), along(0.99, 10), along(0.94, 19), along(0.44, 14)],
    WHITE, r, { hatch: 8, line: 14, fit: true });
crayonShape(c, [along(0.30, -18), along(0.45, -16), along(0.45, 16), along(0.30, 18)], WHITE, r, { hatch: 7, line: 14, fit: true });
crayonShape(c, [along(0.31, -17), along(0.31, 17), along(0.12, 13), along(0.0, 0), along(0.12, -13)], PAINT, r, { hatch: 7, line: 14, fit: true });
// (the ferrule's rings, a drip off the tip)
stroke(c, [along(0.36, -16), along(0.36, 16)], 6, INK, 0.85, r);
stroke(c, [along(0.40, -16), along(0.40, 16)], 6, INK, 0.85, r);
const [tx, ty] = along(0.02, 0);
stroke(c, [[tx, ty], [tx - 1, ty + 10]], 7, PAINT, 0.95, r);
dab(c, tx - 1, ty + 15, 8, PAINT, 0.95);

const image = resize({ width: S, height: S, rgba: toRgba(c) }, 128);
writeBlp(path.join(__dirname, "..", "Media", "Icons", "EditBrush.blp"), 128, 128, image);
if (process.argv[2]) crayon.writePng(process.argv[2], S, S, toRgba(c));  // (a full-size preview, to look at)
console.log("Media/Icons/EditBrush.blp");
