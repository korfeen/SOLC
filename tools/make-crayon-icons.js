// Crayon card icons on different tiles, drawn by code (tools/make-role-icons.js's crayon, as the crayon backgrounds):
// the crayon symbol (killtracker-art-extra\RoleIcons\<name>.png) on the card's tile for its kind - classes on the
// heptagon, races on the circle, professions on theirs (traced) - in each style, to match the painted ones (tools/gen-icon-parts.js).
// Writes %USERPROFILE%\killtracker-art-extra\Unlocks\generated\icons\crayon\<style>_<Kind>_<NAME>.png (512x512).
// Usage: node tools/make-crayon-icons.js [filter]   No dependencies.
const fs = require("fs");
const os = require("os");
const path = require("path");
const crayon = require("./make-role-icons");
const { decodePng, resample, readBlp } = require("./convert-art");

const S = 512;
crayon.setSize(S);
const { canvas, dab, stroke, crayonShape, hex, OUTLINE, rng, writePng } = crayon;
const EXTRA = path.join(os.homedir(), "killtracker-art-extra");
const OUT = path.join(EXTRA, "Unlocks", "generated", "icons", "crayon");
const filter = process.argv[2] || "";
const ICONS = { Class: ["DRUID", "HUNTER", "MAGE", "PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR"], Race: ["DWARF", "GNOME", "HUMAN", "NIGHTELF", "SKYBORNE"],
  Prof: ["ALCHEMY", "BLACKSMITHING", "COOKING", "ENCHANTING", "ENGINEERING", "FIRSTAID", "FISHING", "HERBALISM", "LEATHERWORKING", "MINING", "SKINNING", "TAILORING"] };
const NOT_FOR = { Prof: ["gold", "epic"] };  // (styles a kind isn't made in)

// The card's shapes: the class heptagon (point up), the race circle. Gems: where the gold tile's studs go.
const R = 232, ring = (n, r, dy) => Array.from({ length: n }, (_, i) => { const a = -Math.PI / 2 + (i / n) * 2 * Math.PI; return [S / 2 + Math.cos(a) * r, S / 2 + dy + Math.sin(a) * r]; });
const SHAPES = { Class: { tile: ring(7, R, 6), gems: ring(7, R * 0.82, 6) }, Race: { tile: ring(96, R, 0), gems: ring(6, R * 0.8, 0) } };
// The other shapes traced from the card's own tiles (Media\Overview\Icons\Base_<KIND>.blp): from the middle out, the
// edge every 3 degrees. Professions: the pentagon; the secondary ones (cooking, first aid, fishing) the square.
const SECONDARY = ["COOKING", "FIRSTAID", "FISHING"];
function traced(kind) {
  const img = readBlp(path.join(__dirname, "..", "Media", "Overview", "Icons", `Base_${kind}.blp`)), k = S / img.width;
  const solid = (x, y) => { const px = Math.floor(x / k), py = Math.floor(y / k); return px >= 0 && py >= 0 && px < img.width && py < img.height && img.rgba[(py * img.width + px) * 4 + 3] > 128; };
  let x0 = S, y0 = S, x1 = 0, y1 = 0;
  for (let y = 0; y < S; y += 2) for (let x = 0; x < S; x += 2) if (solid(x, y)) { x0 = Math.min(x0, x); x1 = Math.max(x1, x); y0 = Math.min(y0, y); y1 = Math.max(y1, y); }
  const cx = (x0 + x1) / 2, cy = (y0 + y1) / 2, edge = [];
  for (let d = 0; d < 360; d += 3) {
    const a = d * Math.PI / 180;
    let r = 0;
    while (r < S && solid(cx + Math.cos(a) * (r + 1), cy + Math.sin(a) * (r + 1))) r++;
    edge.push([cx + Math.cos(a) * (r - 8), cy + Math.sin(a) * (r - 8)]);  // (a little in: the outline goes over the edge)
  }
  return { tile: edge, gems: edge.filter((_, i) => i % 20 === 0).map(([x, y]) => [cx + (x - cx) * 0.82, cy + (y - cy) * 0.82]) };
}
const shapeOf = (kind, name) => kind !== "Prof" ? SHAPES[kind] : (SHAPES[SECONDARY.includes(name) ? "SECONDARY" : "PROFESSION"] ||= traced(SECONDARY.includes(name) ? "SECONDARY" : "PROFESSION"));
function inside(x, y, poly) {
  let a = false;
  for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) { const [xi, yi] = poly[i], [xj, yj] = poly[j]; if ((yi > y) !== (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) a = !a; }
  return a;
}
const line = (c, pts, w, col, r) => stroke(c, pts, w, hex(col), 0.9, r);
const wobbly = (y, r) => Array.from({ length: 12 }, (_, k) => [k * S / 11, y + Math.sin(k * 0.9 + r() * 6) * 6]);
// Each tile style: what's drawn under the symbol (the whole square; cut to the tile after).
const STYLES = {
  white: (c, r) => { crayonShape(c, [[0, 0], [S, 0], [S, S], [0, S]], hex("#ece8e0"), r, { fit: true, hatch: 18, outline: null }); },
  lightwood: (c, r) => {
    crayonShape(c, [[0, 0], [S, 0], [S, S], [0, S]], hex("#e2b878"), r, { fit: true, hatch: 18, outline: null });
    for (let y = 70; y < S; y += 92) line(c, wobbly(y, r), 7, "#a8783e", r);
    for (let k = 0; k < 10; k++) { const x = r() * S, y = r() * S; line(c, [[x, y], [x + 40, y + 3], [x + 70, y]], 4, "#c8945a", r); }
  },
  darkwood: (c, r) => {
    crayonShape(c, [[0, 0], [S, 0], [S, S], [0, S]], hex("#6a4026"), r, { fit: true, hatch: 18, outline: null });
    for (let y = 70; y < S; y += 92) line(c, wobbly(y, r), 8, "#3e2414", r);
    for (let k = 0; k < 10; k++) { const x = r() * S, y = r() * S; line(c, [[x, y], [x + 40, y + 3], [x + 70, y]], 4, "#8a5a36", r); }
  },
  parchment: (c, r) => {
    crayonShape(c, [[0, 0], [S, 0], [S, S], [0, S]], hex("#f2e2bc"), r, { fit: true, hatch: 18, outline: null });
    for (let k = 0; k < 40; k++) { const a = r() * 2 * Math.PI, d = R * (0.82 + r() * 0.2); dab(c, S / 2 + Math.cos(a) * d, S / 2 + Math.sin(a) * d, 14 + r() * 10, hex("#d4b47c"), 0.5); }
    for (let k = 0; k < 14; k++) dab(c, 60 + r() * (S - 120), 60 + r() * (S - 120), 5, hex("#c8a46c"), 0.5);
  },
  // (level 60's: one special tile, three candidates)
  gold: (c, r, gems) => {
    crayonShape(c, [[0, 0], [S, 0], [S, S], [0, S]], hex("#f0c040"), r, { fit: true, hatch: 18, outline: null });
    for (let k = 0; k < 6; k++) line(c, [[40 + k * 80, 20], [10 + k * 80, S - 20]], 10, "#fff0a0", r);
    for (const [cx, cy] of gems) crayonShape(c, crayon.circle(cx, cy, 14, 12), hex("#d8282e"), r, { fit: true, hatch: 6, line: 6 });
  },
  epic: (c, r) => {
    crayonShape(c, [[0, 0], [S, 0], [S, S], [0, S]], hex("#7a3ac8"), r, { fit: true, hatch: 18, outline: null });
    dab(c, S / 2, S / 2, 200, hex("#d8a8ff"), 0.35);
    for (let k = 0; k < 7; k++) { const x = 40 + r() * (S - 80), y = 40 + r() * (S - 80); line(c, [[x, y], [x + 30, y - 40], [x + 60, y]], 5, "#e8c8ff", r); }
  },
  molten: (c, r) => {
    crayonShape(c, [[0, 0], [S, 0], [S, S], [0, S]], hex("#2e2628"), r, { fit: true, hatch: 18, outline: null });
    for (let k = 0; k < 6; k++) { let x = 40 + r() * (S - 80), y = 40 + r() * (S - 80); const pts = [[x, y]]; for (let n = 0; n < 4; n++) { x += (r() - 0.5) * 80; y += 20 + r() * 30; pts.push([x, y]); } line(c, pts, 10, "#ff7a1a", r); line(c, pts, 4, "#ffd060", r); }
  },
  stone: (c, r) => {
    crayonShape(c, [[0, 0], [S, 0], [S, S], [0, S]], hex("#aaa298"), r, { fit: true, hatch: 18, outline: null });
    for (let k = 0; k < 5; k++) { let x = 40 + r() * (S - 80), y = 40 + r() * (S - 80); const pts = [[x, y]]; for (let n = 0; n < 4; n++) { x += (r() - 0.5) * 70; y += 20 + r() * 30; pts.push([x, y]); } line(c, pts, 5, "#6a645c", r); }
    for (let k = 0; k < 30; k++) dab(c, r() * S, r() * S, 6, hex(r() < 0.5 ? "#8a847a" : "#c8c0b4"), 0.6);
  },
  // (dark ones: the symbols read best on dark, as on the dark walnut)
  ebony: (c, r) => {
    crayonShape(c, [[0, 0], [S, 0], [S, S], [0, S]], hex("#2a1c16"), r, { fit: true, hatch: 18, outline: null });
    for (let y = 60; y < S; y += 70) line(c, wobbly(y, r), 5, "#3e2a20", r);
    for (let k = 0; k < 8; k++) { const x = r() * S, y = r() * S; line(c, [[x, y], [x + 50, y + 2], [x + 90, y]], 3, "#4e382a", r); }
  },
  iron: (c, r, gems) => {
    crayonShape(c, [[0, 0], [S, 0], [S, S], [0, S]], hex("#3a3c40"), r, { fit: true, hatch: 18, outline: null });
    for (let k = 0; k < 8; k++) { const x = 60 + r() * (S - 120), y = 60 + r() * (S - 120); line(c, [[x, y], [x + 40 + r() * 40, y + (r() - 0.5) * 30]], 3, "#55585e", r); }
    for (const [cx, cy] of gems) crayonShape(c, crayon.circle(cx, cy, 11, 10), hex("#7a7e86"), r, { fit: true, hatch: 6, line: 5 });
  },
  slate: (c, r) => {
    crayonShape(c, [[0, 0], [S, 0], [S, S], [0, S]], hex("#34404a"), r, { fit: true, hatch: 18, outline: null });
    for (let k = 0; k < 4; k++) { let x = 40 + r() * (S - 80), y = 40 + r() * (S - 80); const pts = [[x, y]]; for (let n = 0; n < 4; n++) { x += (r() - 0.5) * 70; y += 20 + r() * 30; pts.push([x, y]); } line(c, pts, 5, "#222a32", r); }
    for (let k = 0; k < 24; k++) dab(c, r() * S, r() * S, 6, hex("#4a5864"), 0.6);
  },
  leather: (c, r, gems, tile) => {
    crayonShape(c, [[0, 0], [S, 0], [S, S], [0, S]], hex("#4a2e1c"), r, { fit: true, hatch: 18, outline: null });
    for (let k = 0; k < 20; k++) dab(c, r() * S, r() * S, 10, hex("#3a2214"), 0.5);
    // (stitches round the edge)
    const ring = tile.map(([x, y]) => [S / 2 + (x - S / 2) * 0.84, S / 2 + (y - S / 2) * 0.84]), pts = [];
    for (let i = 0; i < ring.length; i++) { const [ax, ay] = ring[i], [bx, by] = ring[(i + 1) % ring.length], n = Math.max(1, Math.round(Math.hypot(bx - ax, by - ay) / 14)); for (let k = 0; k < n; k++) pts.push([ax + (bx - ax) * k / n, ay + (by - ay) * k / n]); }
    for (let i = 0; i + 1 < pts.length; i += 2) line(c, [pts[i], pts[i + 1]], 5, "#c8a070", r);
  },
  forest: (c, r) => {
    crayonShape(c, [[0, 0], [S, 0], [S, S], [0, S]], hex("#22382a"), r, { fit: true, hatch: 18, outline: null });
    for (let y = 70; y < S; y += 92) line(c, wobbly(y, r), 8, "#142418", r);
    for (let k = 0; k < 10; k++) { const x = r() * S, y = r() * S; line(c, [[x, y], [x + 40, y + 3], [x + 70, y]], 4, "#34503c", r); }
  },
  wine: (c, r) => {
    crayonShape(c, [[0, 0], [S, 0], [S, S], [0, S]], hex("#4a1820"), r, { fit: true, hatch: 18, outline: null });
    for (let k = 0; k < 3; k++) line(c, [[60 + k * 140, 30], [20 + k * 140, S - 30]], 12, "#62262e", r);
  },
  midnight: (c, r) => {
    crayonShape(c, [[0, 0], [S, 0], [S, S], [0, S]], hex("#1c2244"), r, { fit: true, hatch: 18, outline: null });
    for (let k = 0; k < 30; k++) dab(c, 30 + r() * (S - 60), 30 + r() * (S - 60), 2 + r() * 3, hex("#c8d0ff"), 0.8);
  },
  bronze: (c, r) => {
    crayonShape(c, [[0, 0], [S, 0], [S, S], [0, S]], hex("#4a3a22"), r, { fit: true, hatch: 18, outline: null });
    for (let k = 0; k < 6; k++) line(c, [[40 + k * 80, 20], [10 + k * 80, S - 20]], 8, "#5e4a2c", r);
    for (let k = 0; k < 26; k++) { const a = r() * 2 * Math.PI, d = R * (0.75 + r() * 0.25); dab(c, S / 2 + Math.cos(a) * d, S / 2 + Math.sin(a) * d, 10 + r() * 8, hex("#3a6a5a"), 0.55); }
  },
};

function over(dst, src) {
  for (let i = 0; i < dst.length; i += 4) {
    const a = src[i + 3] / 255, b = dst[i + 3] / 255, o = a + b * (1 - a);
    if (!o) continue;
    for (let k = 0; k < 3; k++) dst[i + k] = Math.round((src[i + k] * a + dst[i + k] * b * (1 - a)) / o);
    dst[i + 3] = Math.round(o * 255);
  }
}
fs.mkdirSync(OUT, { recursive: true });
let made = 0;
for (const [style, draw] of Object.entries(STYLES)) for (const [kind, list] of Object.entries(ICONS)) for (const cls of list) {
  const name = `${style}_${kind}_${cls}`;
  if (!name.includes(filter)) continue;
  if ((NOT_FOR[kind] || []).includes(style)) continue;
  const r = rng(7000 + cls.length * 131 + style.length * 977), { tile: TILE, gems } = shapeOf(kind, cls);
  // (the tile: its style, cut to the shape, the outline round it)
  const c = canvas(); draw(c, r, gems, TILE);
  const tile = Buffer.from(crayon.toRgba(c));
  for (let y = 0; y < S; y++) for (let x = 0; x < S; x++) if (!inside(x + 0.5, y + 0.5, TILE)) tile[(y * S + x) * 4 + 3] = 0;
  const edge = canvas(); stroke(edge, [...TILE, TILE[0]], 26, OUTLINE, 0.95, r);
  over(tile, crayon.toRgba(edge));
  // (the symbol: the class's crayon icon, 60% of the tile, a little low like the card's)
  const file = path.join(EXTRA, "RoleIcons", cls.toLowerCase() + ".png");
  if (fs.existsSync(file)) {
    const icon = decodePng(file), size = Math.round(S * 0.6), small = Buffer.from(resample(icon, 0, 0, icon.width, icon.height, size, size));
    const big = Buffer.alloc(S * S * 4), x0 = Math.round((S - size) / 2), y0 = Math.round((S - size) / 2 + 0.03 * S);
    for (let y = 0; y < size; y++) small.copy(big, ((y0 + y) * S + x0) * 4, y * size * 4, (y + 1) * size * 4);
    over(tile, big);
  }
  writePng(path.join(OUT, name + ".png"), S, S, tile);
  made++;
}
console.log(`Drew ${made} crayon icons into ${OUT}`);
