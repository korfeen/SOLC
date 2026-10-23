// The picture frames (tools/gen-frame-art.js: %USERPROFILE%\killtracker-art-extra\Frames) into the game:
// Media\Frames\<id>.blp and Frames.lua: ns.PICTURE_FRAMES = { { id, name, texture, inner = { x, y, w, h }, outer, unlock } },
// in the picker's order. inner: the opening (fractions of the frame's square: the picture fills it, a little under the
// frame's edge). outer: the frame's own extent (same units). unlock: nil (free), "rank:<n>" (Ogre Rank) or "deed:<id>". The first (the tape) is every picture's
// frame until you pick another.
// Each also gets its back (Media\Frames\<id>_back.blp, made here: see Back) as back = its texture.
// Usage: node tools/convert-frames.js [preview folder]   (restart WoW after: new textures)
const fs = require("fs");
const os = require("os");
const path = require("path");
const { decodePng, resample, writeBlp } = require("./convert-art");

const SRC = path.join(os.homedir(), "killtracker-art-extra", "Frames");
const OUT = path.join(__dirname, "..", "Media", "Frames");
const SIZE = 512;
// The frames, in order: name, how you get it.
const FRAMES = [
  { id: "taped", name: "Taped Up", back: "under" },  // (back: how its back is made, see Back)
  { id: "polaroid", name: "Polaroid", back: "plain" },
  { id: "wood", name: "Honey Wood" },
  { id: "driftwood", name: "Driftwood", unlock: "rank:5" },
  { id: "gilded", name: "Gilded", unlock: "rank:12" },
  { id: "bone", name: "Bone and Tusk", unlock: "rank:20" },
  { id: "dungeon", name: "Dungeon Iron", unlock: "rank:8" },
];
const r4 = (v) => Math.round(v * 10000) / 10000;

// The opening: the see-through area round the middle (flooded from it); if that reaches the edge (the tape: no
// frame round it), the frame's own extent, a little inside.
function Opening(img) {
  const { width: w, height: h, rgba } = img, clear = (x, y) => rgba[(y * w + x) * 4 + 3] < 128;
  const seen = new Uint8Array(w * h), stack = [[w >> 1, h >> 1]];
  let x0 = w, y0 = h, x1 = -1, y1 = -1, edge = false;
  while (stack.length) {
    const [x, y] = stack.pop();
    if (x < 0 || y < 0 || x >= w || y >= h) { edge = true; continue; }
    const i = y * w + x;
    if (seen[i] || !clear(x, y)) continue;
    seen[i] = 1;
    x0 = Math.min(x0, x); x1 = Math.max(x1, x); y0 = Math.min(y0, y); y1 = Math.max(y1, y);
    stack.push([x + 1, y], [x - 1, y], [x, y + 1], [x, y - 1]);
  }
  if (edge || x1 < 0) {
    x0 = w; y0 = h; x1 = -1; y1 = -1;
    for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) if (!clear(x, y)) { x0 = Math.min(x0, x); x1 = Math.max(x1, x); y0 = Math.min(y0, y); y1 = Math.max(y1, y); }
    const ix = (x1 - x0) * 0.06, iy = (y1 - y0) * 0.06;
    x0 += ix; x1 -= ix; y0 += iy; y1 -= iy;
  }
  return { x: r4(x0 / w), y: r4(y0 / h), w: r4((x1 - x0 + 1) / w), h: r4((y1 - y0 + 1) / h) };
}

// The frame's own extent (everything not see-through): the frame is centred on this in the game, so a lopsided one
// (the polaroid's thick bottom) doesn't hang out on one side.
function Extent(img) {
  const { width: w, height: h, rgba } = img;
  let x0 = w, y0 = h, x1 = -1, y1 = -1;
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) if (rgba[(y * w + x) * 4 + 3] >= 128) {
    x0 = Math.min(x0, x); x1 = Math.max(x1, x); y0 = Math.min(y0, y); y1 = Math.max(y1, y);
  }
  return { x: r4(x0 / w), y: r4(y0 / h), w: r4((x1 - x0 + 1) / w), h: r4((y1 - y0 + 1) / h) };
}

// The frame squeezed (across or down, round the middle) so its opening is an exact square: pictures are square.
function Squared(img) {
  const o = Opening(img), w = img.width, h = img.height;
  const sx = o.w > o.h ? o.h / o.w : 1, sy = o.h > o.w ? o.w / o.h : 1;
  if (sx === 1 && sy === 1) return img;
  const out = Buffer.alloc(w * h * 4);
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const ux = Math.floor((x - w / 2) / sx + w / 2), uy = Math.floor((y - h / 2) / sy + h / 2);  // (where it came from)
    if (ux < 0 || uy < 0 || ux >= w || uy >= h) continue;
    img.rgba.copy(out, (y * w + x) * 4, (uy * w + ux) * 4, (uy * w + ux) * 4 + 4);
  }
  return { width: w, height: h, rgba: out };
}

// The frame's back (a picture turned over to read its dream, PixPage.lua): the frame mirrored, darker and duller, round
// a kraft-paper backing board in its opening (a little under the frame). Mirrored round the opening's middle, so the
// opening stays where it is and the game places it like the front. style (the frame's back = ...):
//   "under" - the picture's own paper back, the frame (the tape) behind it: only what sticks out past the paper shows
//   "plain" - one plain card in the frame's own colour (the polaroid): the opening and its edge line filled in
function Back(img, style) {
  const { width: w, height: h, rgba } = img, out = Buffer.alloc(w * h * 4);
  const o = Opening(img), plain = style === "plain";
  const pad = w * (plain ? 0.035 : 0.02), x0 = o.x * w - pad, y0 = o.y * h - pad, x1 = (o.x + o.w) * w + pad, y1 = (o.y + o.h) * h + pad;
  const cx = (o.x + o.w / 2) * w, R = plain ? 0 : 8, LINE = 3, FADE = 8;  // (FADE: the plain card's middle blends into its edge)
  const hash = (x, y) => { let n = (x * 374761393 + y * 668265263) | 0; n = Math.imul(n ^ (n >>> 13), 1274126177); return ((n ^ (n >>> 16)) >>> 0) / 4294967296; };
  const fiber = [];  // (a streak per row: the paper's grain)
  for (let y = 0; y < h; y++) fiber[y] = (hash(7, y >> 1) - 0.5) * 10;
  // (plain: the card's colour, from its light pixels under the opening)
  let card = [200, 165, 118];
  if (plain) {
    let r = 0, g = 0, bl = 0, n = 0;
    for (let y = Math.round(y1); y < h; y++) for (let x = Math.round(x0); x < x1; x++) {
      const i = (y * w + x) * 4;
      if (rgba[i + 3] > 250 && rgba[i] + rgba[i + 1] + rgba[i + 2] > 600) { r += rgba[i]; g += rgba[i + 1]; bl += rgba[i + 2]; n++; }
    }
    if (n) card = [r / n, g / n, bl / n];
  }
  const over = (i, r, g, b, a) => {  // (r, g, b at alpha a over what's there)
    const da = out[i + 3] / 255, oa = a + da * (1 - a);
    if (oa <= 0) return;
    out[i] = (r * a + out[i] * da * (1 - a)) / oa; out[i + 1] = (g * a + out[i + 1] * da * (1 - a)) / oa; out[i + 2] = (b * a + out[i + 2] * da * (1 - a)) / oa;
    out[i + 3] = oa * 255;
  };
  const frameAt = (x, y, i) => {  // the frame, mirrored (its back plainer and in shadow, unless plain)
    const sx = Math.round(2 * cx - x);
    if (sx < 0 || sx >= w) return;
    const s = (y * w + sx) * 4, a = rgba[s + 3] / 255;
    if (a <= 0) return;
    const gray = 0.3 * rgba[s] + 0.59 * rgba[s + 1] + 0.11 * rgba[s + 2];
    const v = (c) => plain ? rgba[s + c] : (rgba[s + c] * 0.65 + gray * 0.35) * 0.62;
    over(i, v(0), v(1), v(2), a);
  };
  const boardAt = (x, y, i) => {  // the board (or the picture's paper back, or the plain card's middle)
    const qx = Math.max(x0 + R - x, 0, x - (x1 - R)), qy = Math.max(y0 + R - y, 0, y - (y1 - R));
    const inside = Math.min(x - x0, x1 - x, y - y0, y1 - y, R ? R - Math.hypot(qx, qy) + (qx && qy ? 0 : R) : Infinity);
    if (inside <= 0) return;
    if (plain) {  // (the card itself: its colour, a little grain, no edge)
      const n = (hash(x, y) - 0.5) * 6;
      return over(i, card[0] + n, card[1] + n, card[2] + n, Math.min(1, inside / FADE));
    }
    const shade = 1 - 0.16 * Math.max(0, 1 - inside / 36);
    const n = (hash(x, y) - 0.5) * 14 + fiber[y];
    let r = (200 + n) * shade, g = (165 + n) * shade, b = (118 + n * 0.8) * shade;
    if (inside < LINE) { const t = Math.min(1, inside / LINE); r = 92 + (r - 92) * (1 - t) * 0.3; g = 58 + (g - 58) * (1 - t) * 0.3; b = 34 + (b - 34) * (1 - t) * 0.3; }
    over(i, r, g, b, Math.min(1, inside));
  };
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const i = (y * w + x) * 4;
    // (the tape behind the paper, the plain card's middle blended over its edge; a frame over its board)
    if (style === "under" || plain) { frameAt(x, y, i); boardAt(x, y, i); } else { boardAt(x, y, i); frameAt(x, y, i); }
  }
  return { width: w, height: h, rgba: out };
}

fs.mkdirSync(OUT, { recursive: true });
const PREVIEW = process.argv[2];  // (a folder: each back also as a PNG there, to look at)
const list = [];
for (const frame of FRAMES) {
  const file = path.join(SRC, frame.id + ".png");
  if (!fs.existsSync(file)) { console.log(frame.id + ": not painted yet"); continue; }
  const img = Squared(decodePng(file));
  frame.inner = Opening(img);
  frame.outer = Extent(img);
  frame.texture = "Interface\\AddOns\\SOLC\\Media\\Frames\\" + frame.id;
  writeBlp(path.join(OUT, frame.id + ".blp"), SIZE, SIZE, Buffer.from(resample(img, 0, 0, img.width, img.height, SIZE, SIZE)));
  const backStyle = frame.back;
  delete frame.back;  // (only for here: Frames.lua's back is the texture)
  const back = Back(img, backStyle), backPixels = Buffer.from(resample(back, 0, 0, back.width, back.height, SIZE, SIZE));
  frame.back = frame.texture + "_back";
  writeBlp(path.join(OUT, frame.id + "_back.blp"), SIZE, SIZE, backPixels);
  if (PREVIEW) require("./make-role-icons").writePng(path.join(PREVIEW, frame.id + "_back.png"), SIZE, SIZE, backPixels);
  list.push(frame);
  console.log(`${frame.id}: opening ${JSON.stringify(frame.inner)}`);
}
const lua = (v) => Array.isArray(v) ? "{\n" + v.map((e) => "    " + lua(e) + ",").join("\n") + "\n}"
  : v && typeof v === "object" ? "{ " + Object.keys(v).map((k) => `${k} = ${lua(v[k])}`).join(", ") + " }"
  : typeof v === "number" ? String(v) : JSON.stringify(v);
fs.writeFileSync(path.join(__dirname, "..", "Frames.lua"), ["-- The picture frames (generated by tools/convert-frames.js - don't edit; Minting.lua uses them).",
  "local _, ns = ...", "ns.PICTURE_FRAMES = " + lua(list), ""].join("\n"));
console.log(`Frames.lua: ${list.length} frames`);
