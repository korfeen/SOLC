// The Pro Shop's bag (ProShopTill.lua: it drops into the steward's bubble when you've paid): Codex's painting of a posh
// S.O.L.C. carrier bag on green (killtracker-art-extra\ProShop\bag\bag.png), keyed out (gen-art.js's key, the green
// between its handles too) and cropped to a square round it: Media/ProShop/Bag.blp, 256.
//   node tools/gen-proshop-bag.js           (keys the painting there; to paint a new one, see the prompt in git history)
const os = require("os");
const path = require("path");
const { decodePng, resample, writeBlp } = require("./convert-art");
const { writePng } = require("./make-role-icons");
const { key, SIZE } = require("./gen-art");

const SRC = path.join(os.homedir(), "killtracker-art-extra", "ProShop", "bag", "bag.png");
let img = decodePng(SRC);
if (img.width !== SIZE) img = { width: SIZE, height: SIZE, rgba: Buffer.from(resample(img, 0, 0, img.width, img.height, SIZE, SIZE)) };
const rgba = key(img.rgba);
// (its box, made square round its middle, a little margin)
let x0 = SIZE, y0 = SIZE, x1 = 0, y1 = 0;
for (let y = 0; y < SIZE; y++) for (let x = 0; x < SIZE; x++) if (rgba[(y * SIZE + x) * 4 + 3] > 40) { x0 = Math.min(x0, x); x1 = Math.max(x1, x); y0 = Math.min(y0, y); y1 = Math.max(y1, y); }
const side = Math.max(x1 - x0, y1 - y0) + 16, cx = (x0 + x1) / 2, cy = (y0 + y1) / 2;
const out = Buffer.from(resample({ width: SIZE, height: SIZE, rgba }, cx - side / 2, cy - side / 2, side, side, 256, 256));
writeBlp(path.join(__dirname, "..", "Media", "ProShop", "Bag.blp"), 256, 256, out);
writePng(path.join(path.dirname(SRC), "bag-keyed.png"), 256, 256, out);
console.log("Wrote Media/ProShop/Bag.blp");
