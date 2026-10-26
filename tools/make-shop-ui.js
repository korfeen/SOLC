// The Pro Shop's dressing UI (ProShopRoom.lua), drawn from the mockup's CSS (tools/proshop-mock/index.html) so the game
// matches it: Media/ProShop/UI/
//   Plaque, PlaqueOn   a tab's brass plaque / the open tab's velvet one: rounded, a 1px border, a rivet at each end
//                      (3 slices: the ends CAP px wide each, the middle stretches)
//   Button, ButtonOff  the velvet button (gilt border, a faint gilt inner line) / greyed out (3 slices too)
//   Knob, Arrow        the round velvet knob with its gilt rim and dark ring; the arrow on it (points left)
//   Panel              a curtain's panel frame: rounded, gilt border, a dark band, a faint gilt line (9 slices;
//                      its fill is a gradient in the game); Rivet = the brass pin on its top
//   Stripes            the curtains' velvet folds, a tile repeated across; CurtainMask(Right) = the curved inner bottom
//   CurtainShadow(Right) the curtains' shadow on the room, round the inner edge and the curve
//   Fringe             the valance's gold fringe, a tile repeated across
//   Vignette           the room's edges darkened while zoomed in
// Drawn 4x4 sampled per pixel, so the edges come out soft. Run: node tools/make-shop-ui.js   (restart WoW after)
const fs = require("fs");
const path = require("path");
const { writeBlp } = require("./convert-art");

const OUT = path.join(__dirname, "..", "Media", "ProShop", "UI");
fs.mkdirSync(OUT, { recursive: true });

const hex = (h, a = 1) => [parseInt(h.slice(1, 3), 16) / 255, parseInt(h.slice(3, 5), 16) / 255, parseInt(h.slice(5, 7), 16) / 255, a];
const mix = (a, b, t) => a.map((v, i) => v + (b[i] - v) * t);
// A colour along CSS-like stops [[pos 0..1, colour], ...].
function along(stops, t) {
  if (t <= stops[0][0]) return stops[0][1];
  for (let i = 1; i < stops.length; i++) {
    if (t <= stops[i][0]) return mix(stops[i - 1][1], stops[i][1], (t - stops[i - 1][0]) / (stops[i][0] - stops[i - 1][0]));
  }
  return stops[stops.length - 1][1];
}
// "over": colour b drawn over a (both premultiplied-free rgba).
function over(a, b) {
  if (!b) return a;
  if (!a) return b;
  const alpha = b[3] + a[3] * (1 - b[3]);
  if (!alpha) return [0, 0, 0, 0];
  return [0, 1, 2].map((i) => (b[i] * b[3] + a[i] * a[3] * (1 - b[3])) / alpha).concat(alpha);
}
// Distance inside a rounded rectangle (positive inside), x/y from its top-left, size w x h, corner radius r.
function inside(x, y, w, h, r) {
  const qx = Math.abs(x - w / 2) - (w / 2 - r), qy = Math.abs(y - h / 2) - (h / 2 - r);
  return r - (Math.hypot(Math.max(qx, 0), Math.max(qy, 0)) + Math.min(Math.max(qx, qy), 0));
}
// A picture from fn(x, y) -> rgba (0..1) or null, sampled 4x4 per pixel.
function paint(w, h, fn) {
  const rgba = Buffer.alloc(w * h * 4);
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    let r = 0, g = 0, b = 0, a = 0;
    for (let sy = 0; sy < 4; sy++) for (let sx = 0; sx < 4; sx++) {
      const c = fn(x + (sx + 0.5) / 4, y + (sy + 0.5) / 4);
      if (!c || !c[3]) continue;
      r += c[0] * c[3]; g += c[1] * c[3]; b += c[2] * c[3]; a += c[3];
    }
    const i = (y * w + x) * 4;
    if (a > 0) { rgba[i] = Math.round(r / a * 255); rgba[i + 1] = Math.round(g / a * 255); rgba[i + 2] = Math.round(b / a * 255); }
    rgba[i + 3] = Math.round(a / 16 * 255);
  }
  return rgba;
}
function save(name, w, h, rgba) {
  writeBlp(path.join(OUT, name + ".blp"), w, h, rgba);
  console.log("Wrote " + name + " (" + w + " x " + h + ")");
}

const GILT = hex("#c9a14a"), RIVET = (d) => mix(hex("#fff0b8"), hex("#8a6420"), Math.min(1, d));

// --- plaques and buttons: 128 x 64, standing for a 25 px (plaque) or 30-38 px (button) tall shape: S tex px a px.
// A rounded bar filling the texture, a border, optional inner lines and rivets.
function bar({ stops, border, radius, highlight, innerLine, rivets }) {
  const W = 128, H = 64, S = H / 25;  // (drawn for a 25 px tall plaque; buttons use the same proportions)
  return paint(W, H, (x, y) => {
    const d = inside(x, y, W, H, radius * S);
    if (d < 0) return null;
    let c = along(stops, y / H);
    if (highlight && y < 1.6 * S && d > S) c = mix(c, highlight, 0.9);  // (a light line along the top inside)
    if (innerLine && d > S && d < 2 * S) c = over(c, innerLine);
    if (d < S) c = border;  // the 1 px border
    if (rivets) {
      for (const cx of [6 * S, W - 6 * S]) {
        const rd = Math.hypot(x - cx, y - H / 2) / (2 * S);
        if (rd <= 1) c = RIVET(Math.hypot(x - (cx - 0.6 * S), y - (H / 2 - 0.6 * S)) / (2.2 * S));
      }
    }
    return c;
  });
}
save("Plaque", 128, 64, bar({ stops: [[0, hex("#f3dc9a")], [0.45, hex("#d6b25e")], [1, hex("#b88c3a")]], border: hex("#6e4f1c"),
  radius: 3, highlight: hex("#fff3c4"), rivets: true }));
save("PlaqueOn", 128, 64, bar({ stops: [[0, hex("#8e2a33")], [0.55, hex("#6b1a21")], [1, hex("#4d1016")]], border: GILT, radius: 3, rivets: true }));
save("Button", 128, 64, bar({ stops: [[0, hex("#8e2a33")], [1, hex("#5c141b")]], border: GILT, radius: 3, innerLine: hex("#f6d98a", 0.35) }));
save("ButtonOff", 128, 64, bar({ stops: [[0, hex("#a89a86")], [1, hex("#857663")]], border: hex("#8f8270"), radius: 3 }));

// --- the knob: 128 square for a 40 px knob (36 + its 2 px dark ring), a soft shadow under it.
{
  const N = 128, S = N / 46, C = N / 2;  // (46 px across: the knob, its ring, room for the shadow)
  save("Knob", N, N, paint(N, N, (x, y) => {
    const d = Math.hypot(x - C, y - C) / S;  // in px from the middle
    const shadow = Math.hypot(x - C, y - C - 3 * S) / S;
    let c = shadow < 23 ? [0, 0, 0, 0.5 * Math.max(0, Math.min(1, (23 - shadow) / 6))] : null;
    if (d <= 20) c = hex("#4d1016");  // the ring
    if (d <= 18) c = GILT;  // the rim
    if (d <= 16) {
      const g = Math.hypot(x - (C - 18 * S + 0.4 * 36 * S), y - (C - 18 * S + 0.35 * 36 * S)) / (18 * S);
      c = along([[0, hex("#9b3039")], [0.7, hex("#5c141b")], [1, hex("#5c141b")]], g / 1.0);
    }
    return c;
  }));
  // The arrow: a cream triangle pointing left with a dark drop shadow, 32 square for 14 px.
  const A = 32, AS = A / 16;
  const tri = (x, y) => x >= 4 * AS && x <= 12 * AS && Math.abs(y - 8 * AS) <= (x - 4 * AS) * 0.62;
  save("Arrow", A, A, paint(A, A, (x, y) => {
    if (tri(x, y)) return hex("#f6d98a");
    if (tri(x, y - AS)) return [0, 0, 0, 0.8];
    return null;
  }));
}

// --- the panel's frame: 128 square for 64 px (S = 2), corners 16 px. Rounded 6, a gilt border, a 3 px dark band, then
// a faint gilt line; the middle left clear for the fill.
{
  const N = 128, S = 2;
  save("Panel", N, N, paint(N, N, (x, y) => {
    const d = inside(x, y, N, N, 6 * S) / S;
    if (d < 0) return null;
    if (d < 1) return GILT;
    if (d < 4) return hex("#2c070c");
    if (d < 5) return over(hex("#2c070c", 0), hex("#c9a14a", 0.45));
    return null;
  }));
  // The pin: 32 square for 16 px, lit from the top left.
  save("Rivet", 32, 32, paint(32, 32, (x, y) => {
    const d = Math.hypot(x - 16, y - 16) / 16;
    if (d > 1) return null;
    return RIVET(Math.hypot(x - 11.2, y - 11.2) / 18);
  }));
}

// --- the curtains: a 32 x 8 tile of folds (the mock's 34 px stripe, here 32), repeated across; the light-to-dark wash
// over them is a gradient in the game.
save("Stripes", 32, 8, paint(32, 8, (x) => along([[0, hex("#4a0b11")], [10 / 34, hex("#7d1b25")], [17 / 34, hex("#9a2834")],
  [26 / 34, hex("#6b1a21")], [1, hex("#4a0b11")]], x / 32)));
// The curve at its inner bottom corner (the mock's border-radius 60% / 12%), as a mask: white = shown. Drawn for the
// LEFT curtain (inner side = right); the right one uses it mirrored.
{
  const W = 128, H = 256, rx = 0.6 * W, ry = 0.12 * H;
  for (const [name, flip] of [["CurtainMask", false], ["CurtainMaskRight", true]]) {
    save(name, W, H, paint(W, H, (px, y) => {
      const x = flip ? W - px : px, cx = W - rx, cy = H - ry;
      if (x > cx && y > cy && ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 > 1) return [1, 1, 1, 0];
      return [1, 1, 1, 1];
    }));
  }
}
// --- the fringe: an 8 x 16 tile, a gold bar 3 of every 7 px (here of 8), for a 10 px tall fringe.
save("Fringe", 8, 16, paint(8, 16, (x) => (x < 3.4 ? hex("#f2c14e", 0.85) : null)));
// --- the vignette: clear in the middle, rgba(20,8,4,.75) at the edges (the mock's radial gradient from 45%).
save("Vignette", 256, 256, paint(256, 256, (x, y) => {
  const d = Math.hypot((x - 128) / 128, (y - 128) / 128) / Math.SQRT2;  // (0 middle .. 1 corner, as an ellipse to the corners)
  const t = Math.max(0, Math.min(1, (d - 0.45) / 0.55));
  return [20 / 255, 8 / 255, 4 / 255, 0.75 * t];
}));

// --- the curtains' shadow on the room (the mock's box-shadow 0 0 22px), following the curtain's outline: its straight
// inner edge and the curve at the bottom. Drawn for a curtain of about 214 x 612 px with 22 px of shadow beside it
// (stretched to the real size), the curtain on the left of the texture; ...Right mirrored.
{
  const W = 128, H = 256, CW = 214, CH = 612, SH = 22, NW = CW + SH;
  const rx = 0.6 * CW, ry = 0.12 * CH, cx = CW - rx, cy = CH - ry;
  const away = (x, y) => {  // how far outside the curtain's outline (0 inside)
    if (y < cy || x < cx) return Math.max(0, x - CW);
    const dx = x - cx, dy = y - cy, r = Math.hypot(dx / rx, dy / ry);
    return r <= 1 ? 0 : Math.hypot(dx, dy) * (1 - 1 / r);
  };
  for (const [name, flip] of [["CurtainShadow", false], ["CurtainShadowRight", true]]) {
    save(name, W, H, paint(W, H, (px, py) => {
      const x = (flip ? W - px : px) * NW / W, y = py * CH / H;
      const d = away(x, y);
      if (d <= 0) return [0, 0, 0, 0.6];  // (under the curtain: hidden by it, but no seam at its edge)
      const t = Math.max(0, 1 - d / SH);
      return [0, 0, 0, 0.6 * t * t];
    }));
  }
}

// --- the panels' shadow (the mock's 0 6px 14px rgba(0,0,0,.55)): a rounded rectangle blurred, 128 square for 64 px
// (S = 2): the panel's outline 16 px in from every side, the shadow fading over 14 px past it. 9 slices, corners 24 px.
{
  const N = 128, S = 2, M = 16;
  save("PanelShadow", N, N, paint(N, N, (x, y) => {
    const d = -inside(x - M * S, y - M * S, N - 2 * M * S, N - 2 * M * S, 6 * S) / S;  // (px outside the outline)
    const t = d <= 0 ? 1 : Math.max(0, 1 - d / 14);
    return [0, 0, 0, 0.55 * t * t];
  }));
}

// --- the till (the steward ringing up the cart), 128 squares standing for 64 px (S = 2) unless said:
//   Bubble      the steward's speech bubble: parchment, a 2 px gilt border, rounded 14 (9 slices, corners 20 px)
//   BubbleTail  its tail, pointing left at him: a gilt triangle, 32 x 32 for 16 x 16 px
//   BagBody, BagTissue, BagHandle   the posh green S.O.L.C. paper bag's parts (the bag drops in, then the tissue,
//               then the handle), each drawn at 2x its size in px
{
  const N = 128, S = 2;
  save("Bubble", N, N, paint(N, N, (x, y) => {
    const d = inside(x, y, N, N, 14 * S) / S;
    if (d < 0) return null;
    return d < 2 ? hex("#c9a14a") : hex("#efe1bd");
  }));
  save("BubbleTail", 32, 32, paint(32, 32, (x, y) => {
    // (16 x 16 px: the point at the left, the base along the right edge)
    const px = x / 2, py = y / 2;
    return Math.abs(py - 8) <= (px / 16) * 8 ? hex("#c9a14a") : null;
  }));
  // The bag: its body 100 x 96 px (a green gradient, rounded 2 at the top and 6 at the bottom, a darker band at the
  // bottom), the tissue 64 x 22 (a cream zigzag), the handle 50 x 34 (a gold arch, 4 px thick).
  save("BagBody", 256, 256, paint(256, 256, (x, y) => {
    const px = x * 100 / 256, py = y * 96 / 256;
    const r = py > 48 ? 6 : 2;
    if (inside(px, py, 100, 96, r) < 0) return null;
    const c = mix(hex("#2f5a34"), hex("#1f3d23"), py / 96);
    return py > 90 ? mix(c, [0, 0, 0, 1], 0.2) : c;
  }));
  save("BagTissue", 128, 64, paint(128, 64, (x, y) => {
    const px = x * 64 / 128, py = y * 22 / 64;
    const pts = [[0, 22], [9.6, 4.4], [22.4, 15.4], [32, 0], [41.6, 15.4], [54.4, 4.4], [64, 22]];
    // (inside the zigzag: below the line through the points)
    for (let i = 1; i < pts.length; i++) {
      const [x0, y0] = pts[i - 1], [x1, y1] = pts[i];
      if (px >= x0 && px <= x1) return py >= y0 + (y1 - y0) * (px - x0) / (x1 - x0) ? hex("#f4e9d0") : null;
    }
    return null;
  }));
  save("BagHandle", 128, 128, paint(128, 128, (x, y) => {
    const px = x * 50 / 128, py = y * 50 / 128;  // (square: the arch is 50 wide, 34 tall, its bottom open)
    if (py > 34) return null;
    const d = Math.hypot((px - 25) / 25, (py - 34) / 34);
    return d <= 1 && d >= 1 - 4 / 25 ? hex("#f2c14e") : null;
  }));
}

// --- the till, take two (a proper shop counter):
//   Register    the brass cash register: an arched top with room for the price flag behind it, a panel for the number
//               drums, a darker base (256 square for 210 x 210 px)
//   Drum        one number drum's window: dark, shaded top and bottom like a turning drum (32 x 64)
//   PriceFlag   the flag that pops up out of the register's top on each ring: velvet with a gilt rim (128 x 64)
//   ReceiptEdge the receipt's torn bottom: a zigzag tile (16 x 8)
{
  const brass = (t) => along([[0, hex("#fff0b8")], [0.25, hex("#e7c66c")], [0.6, hex("#b88c3a")], [1, hex("#7a5418")]], t);
  save("Register", 256, 256, paint(256, 256, (x, y) => {
    const px = x * 210 / 256, py = y * 210 / 256;
    // the crest: an arch over the top, 60 px tall, narrower than the body
    const crest = Math.hypot((px - 105) / 70, (py - 62) / 50);
    if (py < 62 && crest <= 1) {
      if (crest > 0.9) return hex("#5c3d10");
      const t = 1 - crest;
      return mix(brass(py / 62), hex("#fff3c4"), Math.max(0, t - 0.6));
    }
    // the body: 190 x 110 from y 60, rounded 8; a recessed panel for the drums; rivets
    const body = inside(px - 10, py - 60, 190, 110, 8);
    if (body >= 0 && py < 170) {
      if (body < 2) return hex("#5c3d10");
      const panel = inside(px - 22, py - 76, 166, 52, 5);
      if (panel >= 0) return panel < 2 ? hex("#7a5418") : hex("#2a1a0a");
      for (const [rx, ry] of [[22, 70], [188, 70], [22, 160], [188, 160]]) {
        const d = Math.hypot(px - rx, py - ry);
        if (d < 4) return RIVET(Math.hypot(px - rx + 1.2, py - ry + 1.2) / 4.5);
      }
      // engraved lines under the panel
      if (py > 134 && py < 136 || py > 140 && py < 141) return hex("#8a6420");
      return brass((py - 60) / 110 * 0.8);
    }
    // the base: wider, darker, rounded 4
    const base = inside(px - 2, py - 168, 206, 34, 4);
    if (base >= 0) return base < 2 ? hex("#3a2610") : mix(hex("#8a6420"), hex("#4d3410"), (py - 168) / 34);
    // its shadow on the counter
    if (py > 196) { const s = Math.abs(px - 105) / 110; return s < 1 ? [0, 0, 0, 0.4 * (1 - s)] : null; }
    return null;
  }));
  save("Drum", 32, 64, paint(32, 64, (x, y) => {
    const t = y / 64;
    const shade = 1 - Math.pow(Math.abs(t - 0.5) * 2, 2);  // (lit across the middle, dark top and bottom)
    return mix(hex("#0e0904"), hex("#3b2a14"), shade);
  }));
  save("PriceFlag", 128, 64, paint(128, 64, (x, y) => {
    const d = inside(x, y, 128, 64, 8);
    if (d < 0) return null;
    if (d < 3) return hex("#c9a14a");
    return mix(hex("#8e2a33"), hex("#5c141b"), y / 64);
  }));
  save("ReceiptEdge", 16, 8, paint(16, 8, (x, y) => (y < 8 - Math.abs(x - 8) ? hex("#f6ecd2") : null)));
}
