// Renders an ogre from its picture pieces to a PNG, the way the game draws it (Minting.lua's ns.RenderMint): the
// background, the pieces' parts behind the ogre, the skin (with the clothes' hide masks cut out of it), the clothes,
// the mouth, the eyes, the accessory, the hat. From the game's own textures (Media\Collectible\*.blp), painted
// edition. Then cropped to a square and scaled, e.g. for a Discord avatar.
//   node tools/render-portrait.js <out.png> [crop x y size, fractions of the picture] [size in px]
// The look is Reginald's (ProShopRoom.lua's STEWARD) unless REGINALD below is changed.

const fs = require("fs");
const path = require("path");
const zlib = require("zlib");
const { readBlp } = require("./convert-art.js");

const MEDIA = path.join(__dirname, "..", "Media", "Collectible");
const REGINALD = { skin: "club_sage", eyes: "snooty_eyes", expression: "snooty_sneer", outfit: "shop_steward_vest", headwear: "shop_steward_boater" };
const ORDER = ["background", "skin", "outfit", "expression", "eyes", "accessory", "headwear"];  // (Minting.lua's ns.MintLayers)
const FOLDER = { background: "Background", skin: "Skin", outfit: "Outfit", expression: "Expression", eyes: "Eyes", accessory: "Accessory", headwear: "Headwear" };
const N = 512;  // the picture's size at the game's density

// The pieces' data from MintArt.lua: id, rect, perSkin, hide, behind, behindRect (painted edition only).
function option(layer, id) {
  const src = fs.readFileSync(path.join(__dirname, "..", "MintArt.lua"), "utf8");
  const line = src.split(/\r?\n/).find((l) => l.includes(`id = "${id}"`) && l.includes(`${FOLDER[layer]}\\\\`));
  if (!line) throw Error(`no ${layer} ${id} in MintArt.lua`);
  const rect = (name) => { const m = line.match(new RegExp(`[ ,{]${name} = \\{ ([\\d., ]+) \\}`)); return m ? m[1].split(",").map(Number) : null; };
  const file = (name) => { const m = line.match(new RegExp(`[ ,{]${name} = MEDIA \\.\\. "([^"]+)"`)); return m ? m[1].replace(/\\\\/g, "/") : null; };
  return { id, rect: rect("rect"), perSkin: /perSkin = true/.test(line), texture: file("texture"), hide: file("hide"), behind: file("behind"), behindRect: rect("behindRect") };
}
const load = (rel, skin) => readBlp(path.join(MEDIA, rel.replace("%s", skin) + ".blp"));

function draw(canvas, image, rect, mask) {
  const [x0, y0, w, h] = (rect ?? [0, 0, 1, 1]).map((v) => v * N);
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const cx = Math.round(x0 + x), cy = Math.round(y0 + y);
    if (cx < 0 || cy < 0 || cx >= N || cy >= N) continue;
    const sx = Math.min(image.width - 1, Math.floor(x * image.width / w)), sy = Math.min(image.height - 1, Math.floor(y * image.height / h));
    const s = (sy * image.width + sx) * 4, d = (cy * N + cx) * 4;
    let a = image.rgba[s + 3] / 255;
    if (mask) a *= mask.rgba[(Math.floor(cy * mask.height / N) * mask.width + Math.floor(cx * mask.width / N)) * 4 + 3] / 255;
    for (let c = 0; c < 3; c++) canvas[d + c] = canvas[d + c] * (1 - a) + image.rgba[s + c] * a;
    canvas[d + 3] = Math.max(canvas[d + 3], a * 255);
  }
}

function png(width, height, rgba) {
  const crcTable = Array.from({ length: 256 }, (_, n) => { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; return c >>> 0; });
  const crc = (buf) => { let c = 0xffffffff; for (const b of buf) c = crcTable[(c ^ b) & 255] ^ (c >>> 8); return (c ^ 0xffffffff) >>> 0; };
  const chunk = (type, data) => { const len = Buffer.alloc(4); len.writeUInt32BE(data.length); const td = Buffer.concat([Buffer.from(type), data]); const c = Buffer.alloc(4); c.writeUInt32BE(crc(td)); return Buffer.concat([len, td, c]); };
  const raw = Buffer.alloc((width * 4 + 1) * height);
  for (let y = 0; y < height; y++) { raw[y * (width * 4 + 1)] = 0; Buffer.from(rgba.buffer, rgba.byteOffset + y * width * 4, width * 4).copy(raw, y * (width * 4 + 1) + 1); }
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(width, 0); ihdr.writeUInt32BE(height, 4); ihdr[8] = 8; ihdr[9] = 6;
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk("IHDR", ihdr), chunk("IDAT", zlib.deflateSync(raw)), chunk("IEND", Buffer.alloc(0))]);
}

const [out = "reginald.png", cx = "0.18", cy = "0", cs = "0.64", size = "512"] = process.argv.slice(2);
const traits = REGINALD;
const skinFace = traits.skin;  // (Club Sage's faces are drawn in its own colour: Media\Collectible\Eyes\club_sage)
const canvas = new Float64Array(N * N * 4);
// The background: the club's burgundy, darker toward the edges (Discord shows it in a circle).
for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
  const d = Math.hypot(x / N - 0.5, y / N - 0.32) * 1.6, i = (y * N + x) * 4, k = Math.max(0.35, 1 - d);
  canvas[i] = 120 * k; canvas[i + 1] = 28 * k; canvas[i + 2] = 40 * k; canvas[i + 3] = 255;
}
const opts = Object.fromEntries(Object.entries(traits).map(([layer, id]) => [layer, option(layer, id)]));
for (const o of Object.values(opts)) if (o.behind) draw(canvas, load(o.behind, skinFace), o.behindRect);
const masks = Object.values(opts).filter((o) => o.hide).map((o) => load(o.hide, skinFace));
for (const layer of ORDER) {
  const o = opts[layer];
  if (!o) continue;
  const image = load(o.texture, skinFace);
  if (layer === "skin" && masks.length) {
    const mask = { width: N, height: N, rgba: new Uint8Array(N * N * 4).fill(255) };
    for (const m of masks) for (let p = 0; p < N * N; p++) {
      const a = m.rgba[(Math.floor(Math.floor(p / N) * m.height / N) * m.width + Math.floor((p % N) * m.width / N)) * 4 + 3];
      mask.rgba[p * 4 + 3] = Math.min(mask.rgba[p * 4 + 3], a);
    }
    draw(canvas, image, o.rect, mask);
  } else draw(canvas, image, o.rect);
}
// Crop and scale (box filter).
const S = Number(size), X0 = Number(cx) * N, Y0 = Number(cy) * N, W = Number(cs) * N;
const result = new Uint8Array(S * S * 4);
for (let y = 0; y < S; y++) for (let x = 0; x < S; x++) {
  const acc = [0, 0, 0, 0]; let n = 0;
  for (let yy = Y0 + y * W / S; yy < Y0 + (y + 1) * W / S; yy++) for (let xx = X0 + x * W / S; xx < X0 + (x + 1) * W / S; xx++) {
    const i = (Math.min(N - 1, Math.floor(yy)) * N + Math.min(N - 1, Math.floor(xx))) * 4;
    for (let c = 0; c < 4; c++) acc[c] += canvas[i + c]; n++;
  }
  for (let c = 0; c < 4; c++) result[(y * S + x) * 4 + c] = Math.round(acc[c] / Math.max(1, n));
}
fs.writeFileSync(out, png(S, S, result));
console.log(`wrote ${out} (${S}x${S})`);
