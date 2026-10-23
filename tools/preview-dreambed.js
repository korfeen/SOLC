// A picture of the Dream Bed as the game would show it: the painted pieces (tools/gen-dreambed-art.js) at the layout
// in tools/dreambed-layout.json (fractions of the page, 827x584, drawn at 2x), the sky behind the window, an ogre in bed.
// Usage: node tools/preview-dreambed.js [out.png] [night|day]   (default out: killtracker-art-extra/DreamBed/preview.png)
const fs = require("fs"), os = require("os"), path = require("path");
const ROOT = path.join(__dirname, "..") + "/";
const { decodePng, resample } = require(ROOT + "tools/convert-art");
const { writePng } = require(ROOT + "tools/make-role-icons");
const P = path.join(os.homedir(), "killtracker-art-extra", "DreamBed", "pieces");
const ART = path.join(os.homedir(), "killtracker-art");
const K = 2, W = 827 * K, H = 584 * K;
const mode = process.argv[3] || "night";
const out = Buffer.alloc(W * H * 4);
for (let i = 3; i < out.length; i += 4) out[i] = 255;
// A layout (fractions of the page), shared with DreamBed.lua.
const L = JSON.parse(fs.readFileSync(path.join(__dirname, "dreambed-layout.json"), "utf8"));

// (rot: degrees clockwise around the piece's middle, as the game's SetRotation)
let clipTop = 0;  // (rows above this aren't drawn: the floor stays below the wall)
function over(img, sx, sy, sw, sh, dx, dy, dw, dh, alpha = 1, rot = 0) {
  const s = resample(img, sx, sy, sw, sh, Math.round(dw), Math.round(dh));
  dw = Math.round(dw); dh = Math.round(dh); dx = Math.round(dx); dy = Math.round(dy);
  const t = rot * Math.PI / 180, cos = Math.cos(t), sin = Math.sin(t), cx = dw / 2, cy = dh / 2;
  const R = rot ? Math.ceil(Math.hypot(dw, dh) / 2) : 0;
  for (let y = -R; y < dh + R; y++) for (let x = -R; x < dw + R; x++) {
    const X = dx + x, Y = dy + y;
    if (X < 0 || Y < clipTop || X >= W || Y >= H) continue;
    // (which of the picture's pixels lands here: turned back)
    const ux = rot ? Math.round(cos * (x - cx) + sin * (y - cy) + cx) : x, uy = rot ? Math.round(-sin * (x - cx) + cos * (y - cy) + cy) : y;
    if (ux < 0 || uy < 0 || ux >= dw || uy >= dh) continue;
    const i = (uy * dw + ux) * 4, o = (Y * W + X) * 4, a = (s[i + 3] / 255) * alpha;
    if (!a) continue;
    for (let c = 0; c < 3; c++) out[o + c] = Math.round(s[i + c] * a + out[o + c] * (1 - a));
  }
}
function box(img) {
  let x0 = img.width, y0 = img.height, x1 = 0, y1 = 0;
  for (let y = 0; y < img.height; y++) for (let x = 0; x < img.width; x++) if (img.rgba[(y * img.width + x) * 4 + 3] > 40) { x0 = Math.min(x0, x); x1 = Math.max(x1, x); y0 = Math.min(y0, y); y1 = Math.max(y1, y); }
  return { x: x0, y: y0, w: x1 - x0 + 1, h: y1 - y0 + 1 };
}
// A piece by its visible box: x, w (fractions), and bottom or top (fractions); returns where it landed (px).
function piece(name, spec) {
  const img = decodePng(path.join(P, name + ".png")), b = box(img);
  const dw = spec.w * W, dh = dw * b.h / b.w * (spec.flat || 1);
  const dx = spec.x * W, dy = spec.top !== undefined ? spec.top * H : spec.bottom * H - dh;
  over(img, b.x, b.y, b.w, b.h, dx, dy, dw, dh, spec.alpha, spec.rot);
  return { x: dx, y: dy, w: dw, h: dh, img, b };
}

// The sky (behind the room's window), then the room (its sides cropped to the page's shape).
const room = decodePng(path.join(P, "room.png"));
const fx = (W / H) / (room.width / room.height), left = (1 - fx) / 2;
const win = (() => { let x0 = 1e9, y0 = 1e9, x1 = 0, y1 = 0; for (let y = 0; y < room.height * 0.55; y++) for (let x = 0; x < room.width; x++) if (room.rgba[(y * room.width + x) * 4 + 3] < 128) { x0 = Math.min(x0, x); x1 = Math.max(x1, x); y0 = Math.min(y0, y); y1 = Math.max(y1, y); } return { x: x0 / room.width, y: y0 / room.height, w: (x1 - x0) / room.width, h: (y1 - y0) / room.height }; })();
const wx = (win.x - left) / fx * W, wy = win.y * H, ww = win.w / fx * W, wh = win.h * H;
const sky = mode === "night" ? [[10, 15, 50], [26, 33, 96]] : [[128, 196, 255], [207, 233, 255]];
for (let y = Math.floor(wy); y < wy + wh; y++) for (let x = Math.floor(wx); x < wx + ww; x++) {
  const t = (y - wy) / wh, o = (y * W + x) * 4;
  for (let c = 0; c < 3; c++) out[o + c] = Math.round(sky[0][c] + (sky[1][c] - sky[0][c]) * t);
}
if (mode === "night") {
  for (let i = 0; i < 26; i++) { const x = Math.floor(wx + Math.random() * ww), y = Math.floor(wy + Math.random() * wh * 0.75); for (let d = 0; d < 4; d++) { const o = ((y + (d >> 1)) * W + x + (d & 1)) * 4; out[o] = out[o + 1] = out[o + 2] = 240; } }
  const mx = wx + ww * 0.68, my = wy + wh * 0.25, r = ww * 0.09;
  for (let y = -r * 3; y < r * 3; y++) for (let x = -r * 3; x < r * 3; x++) { const d = Math.hypot(x, y), o = (Math.round(my + y) * W + Math.round(mx + x)) * 4, a = d < r ? 1 : Math.max(0, 0.35 * (1 - (d - r) / (r * 2))); if (a > 0 && mx + x > wx && mx + x < wx + ww && my + y > wy && my + y < wy + wh) for (let c = 0; c < 3; c++) out[o + c] = Math.round([246, 240, 200][c] * a + out[o + c] * (1 - a)); }
}
// The floor (the whole page, behind the room's cut-out floor) and the rug on it, then the room and its nightstand.
if (fs.existsSync(path.join(P, "floor.png"))) {
  const floor = decodePng(path.join(P, "floor.png")), ff = (W / H) / (floor.width / floor.height);
  const f = L.floor || {}, z = f.zoom || 1;  // (slid and zoomed as laid out; below the wall only)
  clipTop = H / 2;
  over(floor, (1 - ff) / 2 * floor.width, 0, ff * floor.width, floor.height, W / 2 - W * z / 2 + (f.x || 0) * W, H / 2 - H * z / 2 + (f.y || 0) * H, W * z, H * z);
  clipTop = 0;
}
{ // (the wall down to wall.floor: the room's wooden panel strip stretched, the rest as painted)
  let y = Math.floor(room.height * 0.4);
  for (; y < room.height; y++) { let clear = true; for (let k = 1; k < 10; k++) if (room.rgba[(y * room.width + Math.floor(room.width * k / 10)) * 4 + 3] > 20) clear = false; if (clear) break; }
  const painted = y / room.height, P = painted - 0.035, to = (L.wall && L.wall.floor) || painted;
  over(room, left * room.width, 0, fx * room.width, P * room.height, 0, 0, W, P * H);
  over(room, left * room.width, P * room.height, fx * room.width, 0.035 * room.height, 0, P * H, W, (to - P) * H);
}
if (L.rug && fs.existsSync(path.join(P, "rug.png"))) piece("rug", L.rug);
if (L.nightstand && fs.existsSync(path.join(P, "nightstand.png"))) piece("nightstand", L.nightstand);
if (L.mallet && fs.existsSync(path.join(P, "mallet.png"))) piece("mallet", L.mallet);
if (L.peg && fs.existsSync(path.join(P, "peg.png"))) piece("peg", L.peg);

// The bed: frame, pillow, your ogre's head, the quilt.
piece("headboard", L.headboard);
piece("pillow", L.pillow);
{
  const layers = ["Skin/Uncommon/moss.png", "Eyes/Uncommon/moss/" + (mode === "night" ? "fully-asleep.png" : "heavy-bags.png"),
    "Expression/Uncommon/moss/" + (mode === "night" ? "mouth-hanging-open.png" : "smug-smile.png"), "Headwear/Rare/captain-tricorn.png"];
  const S = L.head.size * H, hx = L.head.x * W, hy = L.head.top * H;
  for (const rel of layers) {
    const f = path.join(ART, rel);
    if (fs.existsSync(f)) { const img = decodePng(f); over(img, 0, 0, img.width, img.height, hx, hy, S, S); }
  }
}
piece("quilt", L.quilt);
// The nightstand: candle and flame, mug, book.
const candle = piece("candle", L.candle);
if (mode === "night") {
  const fl = decodePng(path.join(P, "flame.png")), b = box(fl), fw = L.flame.w * W, fh = fw * b.h / b.w;
  over(fl, b.x, b.y, b.w, b.h, candle.x + candle.w * L.flame.dx - fw / 2, candle.y - fh * L.flame.dy, fw, fh);
  // (the candle's glow, drawn by the game: a soft warm light round it, added)
  const gx = candle.x + candle.w / 2, gy = candle.y, R = W * 0.16;
  for (let y = Math.max(0, Math.floor(gy - R)); y < Math.min(H, gy + R); y++) for (let x = Math.max(0, Math.floor(gx - R)); x < Math.min(W, gx + R); x++) {
    const d = Math.hypot(x - gx, y - gy) / R, o = (y * W + x) * 4;
    if (d >= 1) continue;
    const a = 0.55 * (1 - d) * (1 - d);
    out[o] = Math.min(255, out[o] + 255 * a); out[o + 1] = Math.min(255, out[o + 1] + 150 * a); out[o + 2] = Math.min(255, out[o + 2] + 60 * a);
  }
}
piece("mug", L.mug);
piece("book", L.book);
// The easel, the jar and its tools.
piece("easel", L.easel);
for (const t of ["brush", "pencils", "crayon"]) piece(t, L[t]);
piece("jar", L.jar);
// (the night: the room darker but the candle; the morning: warmer)
if (mode === "night") for (let i = 0; i < out.length; i += 4) { for (let c = 0; c < 3; c++) out[i + c] = Math.round(out[i + c] * 0.85); }
const file = process.argv[2] || path.join(os.homedir(), "killtracker-art-extra", "DreamBed", "preview.png");
writePng(file, W, H, out);
console.log("wrote " + file);
