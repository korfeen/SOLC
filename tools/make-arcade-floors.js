// The arcade rooms' floors in crayon, drawn by code (crayon is never Codex): one picture of the whole stage seen from
// above, from the room's layout in tools/arcade-stages.json (so the path, the lawns and the props' spots agree).
// The mockup lays it on the angled floor in thin strips across (and so can WoW: a stack of strip textures, each showing
// its slice of the picture with SetTexCoord).
//   node tools/make-arcade-floors.js [floor]      floors: smgy (Forlorn Cloister), smlib, smarm, smcath
// Out: %USERPROFILE%\killtracker-art-extra\Arcade\floors\<floor>.png - 1200 wide, the stage's shape (3600 x 2200),
// its top row the back wall, its bottom row the entrance.
const fs = require("fs");
const os = require("os");
const path = require("path");
const crayon = require("./make-role-icons");

// (each floor its room's shape: layout.size, else 3600 x 2200; the longer side 1200 px. The crayon canvas is square:
// the floor uses its top-left W x H.)
let W = 1200, H = Math.round(1200 * 2200 / 3600);
function sizeFor(L) { const [x, z] = (L && L.size) || [3600, 2200]; if (x >= z) { W = 1200; H = Math.round(1200 * z / x); } else { H = 1200; W = Math.round(1200 * x / z); } crayon.setSize(Math.max(W, H)); }
const { canvas, stroke, crayonShape, hex, rng, writePng, circle } = crayon;
const OUT = path.join(os.homedir(), "killtracker-art-extra", "Arcade", "floors");
const A = JSON.parse(fs.readFileSync(path.join(__dirname, "arcade-stages.json"), "utf8"));
const sm = A.stages.find((s) => s.key === "sm");
// stage fractions -> picture pixels (z: 0 = the entrance at the bottom, 1 = the back wall at the top)
const px = (x, z) => [x * W, (1 - z) * H];
const blob = (cx, cy, rx, ry, n = 14, r = Math.random) => Array.from({ length: n }, (_, i) => { const a = i / n * 6.283, k = 0.8 + r() * 0.35; return [cx + Math.cos(a) * rx * k, cy + Math.sin(a) * ry * k]; });
const rect = (x0, y0, x1, y1) => [[x0, y0], [x1, y0], [x1, y1], [x0, y1]];

const FLOORS = {
  // The Forlorn Cloister: lawns, the cobbled path up the middle (wider by the tomb), a curb, dirt before each grave,
  // scorched ground round the pyres, a stone landing at the tomb's steps.
  smgy(c, r) {
    const L = sm.rooms[0].layout, half = L.path.half;
    const halfAt = (z) => { for (let i = 1; i < half.length; i++) if (z <= half[i][0]) { const [a, ha] = half[i - 1], [b, hb] = half[i]; return ha + (hb - ha) * (z - a) / (b - a); } return half[half.length - 1][1]; };
    crayonShape(c, rect(0, 0, W, H), hex("#557d36"), r, { fit: true, hatch: 10, outline: null });
    for (let i = 0; i < 70; i++) { const x = r() * W, y = r() * H; crayonShape(c, blob(x, y, 20 + r() * 40, 10 + r() * 18, 12, r), hex(r() < 0.5 ? "#476c2c" : "#68913f"), r, { fit: true, hatch: 7, outline: null }); }
    for (let i = 0; i < 260; i++) { const x = r() * W, y = r() * H; stroke(c, [[x, y], [x + (r() - 0.5) * 6, y - 8 - r() * 8]], 3, hex(r() < 0.5 ? "#3b5e25" : "#7aa64a"), 0.9, r); }  // (grass tufts)
    // the path: its outline down the stage, both sides
    const zs = Array.from({ length: 41 }, (_, i) => i / 40);
    const left = zs.map((z) => px(L.path.x - halfAt(z), z)), right = zs.map((z) => px(L.path.x + halfAt(z), z)).reverse();
    const pathPoly = [...left, ...right];
    crayonShape(c, pathPoly, hex("#b9ad98"), r, { fit: true, hatch: 9, outline: null });
    // cobbles: rows of rounded stones, offset every other row
    for (let y = 4; y < H; y += 22) {
      const z = 1 - y / H, hw = halfAt(z) * W, cx = L.path.x * W, row = Math.round(y / 22);
      for (let x = cx - hw + (row % 2 ? 12 : 2); x < cx + hw - 12; x += 26 + r() * 6) {
        crayonShape(c, blob(x + 11, y + 9, 11, 8, 9, r), hex(pick(r, ["#a89b85", "#c6baa4", "#b3a690", "#9d917c"])), r, { fit: true, hatch: 5, line: 3, outline: hex("#6b5f4e") });
      }
    }
    stroke(c, [...left], 8, hex("#ddd3c0"), 0.95, r); stroke(c, right.slice().reverse(), 8, hex("#ddd3c0"), 0.95, r);  // (the curb)
    stroke(c, left.map(([x, y]) => [x - 5, y]), 4, hex("#2b1a10"), 0.9, r); stroke(c, right.slice().reverse().map(([x, y]) => [x + 5, y]), 4, hex("#2b1a10"), 0.9, r);
    // dirt in front of each grave (in front = towards the entrance: below it in the picture)
    for (const [x, z] of L.graves) { const [gx, gy] = px(x, z); crayonShape(c, blob(gx, gy + 14, 24, 13, 12, r), hex("#6b4a2e"), r, { fit: true, hatch: 6, line: 4 }); }
    // scorched ground and ash round the pyres
    for (const [x, z] of L.pyres) { const [gx, gy] = px(x, z); crayonShape(c, blob(gx, gy, 70, 36, 16, r), hex("#2e241c"), r, { fit: true, hatch: 8, outline: null }); crayonShape(c, blob(gx, gy, 40, 20, 12, r), hex("#5a4a3c"), r, { fit: true, hatch: 6, outline: null }); }
    // the landing before the tomb, and the entrance threshold
    const [tx, ty] = px(L.tomb[0], L.tomb[1]);
    crayonShape(c, rect(tx - 170, ty - 40, tx + 170, ty + 50), hex("#c9c0b2"), r, { fit: true, hatch: 8, line: 6 });
    crayonShape(c, rect(L.path.x * W - halfAt(0) * W - 20, H - 26, L.path.x * W + halfAt(0) * W + 20, H), hex("#8c8478"), r, { fit: true, hatch: 6, line: 6 });
  },
  // The Library wing: the Huntsman's Cloister at the entrance (pinkish stone walkway round a square lawn), a step up into
  // the Gallery of Treasures (dark warm flagstones, the red carpet edged in gold), and Doan's round Athenaeum at the back
  // (a purple stone disc with arcane rings)
  smlib(c, r) {
    const L = LAYOUT.smlib, R = (q) => [q[0] * W, (1 - q[3]) * H, q[2] * W, (1 - q[1]) * H];  // (a walk rect in pixels: x0, y0, x1, y1)
    const flags = (box, cols, line, sz = 46) => { const [x0, y0, x1, y1] = box; for (let y = y0; y < y1; y += sz) for (let x = x0 + (((y - y0) / sz) % 2) * sz * 0.75; x < x1; x += sz * 1.5 + r() * 16) crayonShape(c, rect(x + 3, y + 3, x + sz * 1.45, y + sz - 3), hex(pick(r, cols)), r, { fit: true, hatch: 7, line: 3, outline: hex(line) }); };
    crayonShape(c, rect(0, 0, W, H), hex("#6e4e3a"), r, { fit: true, hatch: 10, outline: null });
    // the cloister's walkway, its lawn
    flags(R(L.walk[0]), ["#c9a9a0", "#b8968e", "#d4b6ac"], "#7a5a52");
    const [lx0, lz0, lx1, lz1] = L.lawn, [ax, ay] = px(lx0, lz1), [bx, by] = px(lx1, lz0);
    crayonShape(c, rect(ax, ay, bx, by), hex("#5f8a3a"), r, { fit: true, hatch: 9, line: 7 });
    for (let i = 0; i < 90; i++) { const x = ax + r() * (bx - ax), y = ay + r() * (by - ay); stroke(c, [[x, y], [x + (r() - 0.5) * 6, y - 8 - r() * 6]], 3, hex(r() < 0.5 ? "#3b5e25" : "#7aa64a"), 0.9, r); }
    // the doorways and the gallery with its alcoves: dark warm flagstones
    for (const k of [1, 2, 3, 4, 5, 6, 7]) flags(R(L.walk[k]), ["#7a5644", "#6a4a38", "#84604c"], "#3e2a1e", 40);
    // the carpet, edged in gold: from the cloister's doorway to the Athenaeum
    const cx = L.carpet.x * W, hw = L.carpet.half * W, [ix, iy] = px(L.inlay.x, L.inlay.z), ir = L.inlay.r * W, ty = (1 - L.threshold) * H;
    crayonShape(c, rect(cx - hw - 7, iy + ir * 0.6, cx + hw + 7, ty), hex("#d8a838"), r, { fit: true, hatch: 6, outline: null });
    crayonShape(c, rect(cx - hw, iy + ir * 0.6, cx + hw, ty), hex("#9c2420"), r, { fit: true, hatch: 8, line: 4 });
    // the Athenaeum: the round room's purple stone floor, its rings and runes
    crayonShape(c, circle(ix, iy, ir, 48), hex("#6e5482"), r, { fit: true, hatch: 9, outline: null });
    crayonShape(c, circle(ix, iy, ir * 0.62, 40), hex("#8e6aa4"), r, { fit: true, hatch: 8, line: 6 });
    stroke(c, [...circle(ix, iy, ir * 0.4, 36), circle(ix, iy, ir * 0.4, 36)[0]], 5, hex("#e0b0ff"), 0.95, r);
    for (let i = 0; i < 10; i++) { const a = i / 10 * 6.283, x = ix + Math.cos(a) * ir * 0.8, y = iy + Math.sin(a) * ir * 0.8; stroke(c, [[x - 7, y], [x + 7, y]], 4, hex("#e0b0ff"), 0.9, r); stroke(c, [[x, y - 7], [x, y + 7]], 4, hex("#e0b0ff"), 0.9, r); }
  },
  // The Armory: big grey flagstones, a red runner up to the dais
  smarm(c, r) {
    crayonShape(c, rect(0, 0, W, H), hex("#8e8a84"), r, { fit: true, hatch: 10, outline: null });
    for (let y = 0; y < H; y += 60) for (let x = (y / 60 % 2) * 45; x < W; x += 90) crayonShape(c, rect(x + 3, y + 3, x + 87, y + 57), hex(pick(r, ["#99958e", "#86827c", "#a29e96"])), r, { fit: true, hatch: 7, line: 3, outline: hex("#4e4a44") });
    crayonShape(c, rect(W * 0.46, 0, W * 0.54, H), hex("#9c2a24"), r, { fit: true, hatch: 8, line: 6 });
  },
  // The Cathedral: a chequered marble floor, the red carpet down the aisle
  smcath(c, r) {
    for (let y = 0; y < H; y += 50) for (let x = 0; x < W; x += 50) crayonShape(c, rect(x, y, x + 50, y + 50), hex((x / 50 + y / 50) % 2 ? "#e6dccb" : "#8e6a5a"), r, { fit: true, hatch: 7, outline: null });
    crayonShape(c, rect(W * 0.43, 0, W * 0.57, H), hex("#a8231e"), r, { fit: true, hatch: 8, line: 7 });
    stroke(c, [[W * 0.445, 0], [W * 0.445, H]], 5, hex("#e8c45a"), 0.9, r); stroke(c, [[W * 0.555, 0], [W * 0.555, H]], 5, hex("#e8c45a"), 0.9, r);
  },
};
function pick(r, list) { return list[Math.floor(r() * list.length)]; }

fs.mkdirSync(OUT, { recursive: true });
const only = process.argv[2];
// A room's outline (layout.walk, as the mockup reads it): outside it, dark wall tops; round it, a paper edge.
const LAYOUT = Object.fromEntries(sm.rooms.filter((r) => r.layout).map((r) => [r.layout.floor, r.layout]));
function walkFn(L) {
  if (!L || !L.walk) return null;
  const sh = L.walk.map((w) => w.length === 4 ? { r: w } : { c: w });
  return (x, z) => sh.some((q) => q.r ? x >= q.r[0] && x <= q.r[2] && z >= q.r[1] && z <= q.r[3] : Math.hypot((x - q.c[0]) * W, (z - q.c[1]) * H) <= q.c[2] * W);
}
for (const [name, draw] of Object.entries(FLOORS)) {
  if (only && name !== only) continue;
  const L = LAYOUT[name]; sizeFor(L);
  const SZ = Math.max(W, H), crop = (c) => { const all = crayon.toRgba(c), out = Buffer.alloc(W * H * 4); for (let y = 0; y < H; y++) all.copy ? all.copy(out, y * W * 4, y * SZ * 4, (y * SZ + W) * 4) : out.set(all.subarray(y * SZ * 4, (y * SZ + W) * 4), y * W * 4); return out; };
  const c = canvas(), r = rng(4242 + name.length);
  draw(c, r);
  const rgba = crop(c);
  const walk = walkFn(L);
  if (walk) {
    // outside: dark wall tops, hatched
    const dark = canvas();
    crayonShape(dark, rect(0, 0, W, H), hex("#3a2a24"), r, { fit: true, hatch: 12, outline: null });
    const d = crop(dark), inside = (x, y) => walk(x / W, 1 - y / H);
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) if (!inside(x + 0.5, y + 0.5)) { const i = (y * W + x) * 4; rgba[i] = d[i]; rgba[i + 1] = d[i + 1]; rgba[i + 2] = d[i + 2]; }
    // the edge: runs of points along the outline, a cream paper line with a dark one outside it
    const edge = canvas(), runs = [], step = 4;
    for (let y = 0; y < H; y += step) for (let x = 0; x < W; x += step) {
      if (!inside(x, y)) continue;
      if (!inside(x + step, y) || !inside(x - step, y) || !inside(x, y + step) || !inside(x, y - step)) runs.push([x, y]);
    }
    for (const [x, y] of runs) { crayon.dab(edge, x, y, 5, hex("#fbf6ea"), 0.95); }
    for (const [x, y] of runs) for (const [dx, dy] of [[step, 0], [-step, 0], [0, step], [0, -step]]) if (!inside(x + dx, y + dy)) crayon.dab(edge, x + dx * 1.2, y + dy * 1.2, 3, hex("#2b1a10"), 0.9);
    const e = crop(edge);
    for (let i = 0; i < rgba.length; i += 4) { const a = e[i + 3] / 255; if (a) for (let k = 0; k < 3; k++) rgba[i + k] = Math.round(e[i + k] * a + rgba[i + k] * (1 - a)); }
  }
  for (let i = 3; i < rgba.length; i += 4) rgba[i] = 255;
  writePng(path.join(OUT, name + ".png"), W, H, Buffer.from(rgba));
  console.log("floor", name, W + "x" + H);
}
