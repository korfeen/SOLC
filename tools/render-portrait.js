// Renders an ogre from its picture pieces to a PNG, the way the game draws it (Minting.lua's ns.RenderMint), from the
// full-size source paintings (1254 px a picture; the game's textures are 512) so a close crop stays sharp:
// the background, the pieces' parts behind the ogre (their "behind" masks and linings from the item fitter), the skin
// (with the clothes' "hide" masks cut out of it), the clothes, the mouth, the eyes, the accessory, the hat.
// The eyes and mouth only show where the head is (the skin's own shape): some face pieces kept a bit of the painting's
// dark backdrop past the head (Snooty Eyes did), which the game would show where a hat doesn't cover it.
//   node tools/render-portrait.js <out.png> [crop x y size, fractions of the picture] [size in px]
// Default: Reginald (ProShopRoom.lua's STEWARD), his face and hat, 512 px - his Discord avatar.

const fs = require("fs");
const path = require("path");
const zlib = require("zlib");
const { SOURCE, decodePng } = require("./convert-art.js");

const EXTRA = path.join(path.dirname(SOURCE), "killtracker-art-extra", "Unlocks");
const FITS = path.join(EXTRA, "generated", "fits");
// Reginald's pieces: the source painting of each (the face pieces in his skin's colour) and its fitter files.
const PIECES = {
  skin: path.join(SOURCE, "Skin", "Legendary", "club-sage.png"),
  outfit: path.join(EXTRA, "painted", "Outfit", "Epic", "shop-steward-vest.png"),
  expression: path.join(SOURCE, "Expression", "Epic", "club-sage", "snooty-sneer.png"),
  eyes: path.join(SOURCE, "Eyes", "Epic", "club-sage", "snooty-eyes.png"),
  headwear: path.join(EXTRA, "painted", "Headwear", "Legendary", "shop-steward-boater.png"),
};
const FIT_IDS = { outfit: "shop_steward_vest", headwear: "shop_steward_boater" };
const ORDER = ["skin", "outfit", "expression", "eyes", "headwear"];  // (Minting.lua's ns.MintLayers, back to front)

const load = (file) => (fs.existsSync(file) ? decodePng(file) : null);
const alpha = (img, i) => img.rgba[i * 4 + 3] / 255;

const [out = "reginald.png", cx = "0.275", cy = "0", cs = "0.47", size = "512"] = process.argv.slice(2);
const images = Object.fromEntries(ORDER.map((k) => [k, decodePng(PIECES[k])]));
const N = images.skin.width;  // (every source is the whole picture, the same size)
for (const [k, img] of Object.entries(images)) if (img.width !== N || img.height !== N) throw Error(`${k} isn't ${N}x${N}`);

// The picture, as floats: the club's burgundy, darker toward the edges (Discord shows it in a circle).
const canvas = new Float64Array(N * N * 3);
for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
  const k = Math.max(0.35, 1 - Math.hypot(x / N - 0.51, y / N - 0.2) * 1.7), i = (y * N + x) * 3;
  canvas[i] = 122 * k; canvas[i + 1] = 28 * k; canvas[i + 2] = 40 * k;
}
const over = (rgba, i, a) => { if (a <= 0) return; for (let c = 0; c < 3; c++) canvas[i * 3 + c] = canvas[i * 3 + c] * (1 - a) + rgba[i * 4 + c] * a; };

// What of each piece goes behind the ogre (the fitter's Behind ogre mask), and the lining under it.
const behindOf = {};
for (const [layer, id] of Object.entries(FIT_IDS)) {
  behindOf[layer] = load(path.join(FITS, id + ".behind.png"));
  const lining = load(path.join(FITS, id + ".lining.png"));
  for (let i = 0; i < N * N; i++) {
    if (lining) over(lining.rgba, i, alpha(lining, i));
    const m = behindOf[layer] ? alpha(behindOf[layer], i) : 0;
    if (m) over(images[layer].rgba, i, alpha(images[layer], i) * m);
  }
}
// Where the clothes hide the ogre (the fitter's Hide ogre).
const hides = Object.values(FIT_IDS).map((id) => load(path.join(FITS, id + ".hide.png"))).filter(Boolean);
for (const layer of ORDER) {
  const img = images[layer];
  for (let i = 0; i < N * N; i++) {
    let a = alpha(img, i);
    if (layer === "skin") for (const h of hides) a *= 1 - alpha(h, i);
    if (layer === "eyes" || layer === "expression") a *= alpha(images.skin, i);  // (only on the head)
    if (behindOf[layer]) a *= 1 - alpha(behindOf[layer], i);  // (its behind part is already drawn)
    over(img.rgba, i, a);
  }
}

// Crop and scale down (box filter).
const S = Number(size), X0 = Number(cx) * N, Y0 = Number(cy) * N, W = Number(cs) * N;
const result = Buffer.alloc(S * S * 4);
for (let y = 0; y < S; y++) for (let x = 0; x < S; x++) {
  const acc = [0, 0, 0]; let n = 0;
  for (let yy = Math.floor(Y0 + y * W / S); yy < Y0 + (y + 1) * W / S; yy++) for (let xx = Math.floor(X0 + x * W / S); xx < X0 + (x + 1) * W / S; xx++) {
    const i = (Math.min(N - 1, yy) * N + Math.min(N - 1, xx)) * 3;
    for (let c = 0; c < 3; c++) acc[c] += canvas[i + c]; n++;
  }
  const d = (y * S + x) * 4;
  for (let c = 0; c < 3; c++) result[d + c] = Math.round(acc[c] / Math.max(1, n));
  result[d + 3] = 255;
}

function png(width, height, rgba) {
  const table = Array.from({ length: 256 }, (_, n) => { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; return c >>> 0; });
  const crc = (buf) => { let c = 0xffffffff; for (const b of buf) c = table[(c ^ b) & 255] ^ (c >>> 8); return (c ^ 0xffffffff) >>> 0; };
  const chunk = (type, data) => { const len = Buffer.alloc(4); len.writeUInt32BE(data.length); const td = Buffer.concat([Buffer.from(type), data]); const c = Buffer.alloc(4); c.writeUInt32BE(crc(td)); return Buffer.concat([len, td, c]); };
  const raw = Buffer.alloc((width * 4 + 1) * height);
  for (let y = 0; y < height; y++) rgba.copy(raw, y * (width * 4 + 1) + 1, y * width * 4, (y + 1) * width * 4);
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(width, 0); ihdr.writeUInt32BE(height, 4); ihdr[8] = 8; ihdr[9] = 6;
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk("IHDR", ihdr), chunk("IDAT", zlib.deflateSync(raw)), chunk("IEND", Buffer.alloc(0))]);
}
fs.writeFileSync(out, png(S, S, result));
console.log(`wrote ${out} (${S}x${S}, from ${N}px sources)`);
