// Crayon versions of the generated pieces (tools/gen-art.js: gear, chase items, creature and faction outfits), drawn
// with the same crayon tools as the hand-drawn backgrounds (tools/make-crayon-backgrounds.js): each piece's painting,
// as fitted, simplified to a few big flat colour areas (its main colours), each a crayon shape - hatched in its colour
// with a bold dark outline - in exactly the painting's place, so the crayon piece sits where the painted one does.
// RECIPES: per piece, { base: its colour (else the painting's commonest), areas: false to leave out the painting's
// own colour areas (busy textures came out as blotches), draw: details on top in the piece's own box (0..1 across
// and down) } - what makes it recognisable: an emblem, stripes, a belt, eyes.
// Writes %USERPROFILE%\killtracker-art-extra\Unlocks\generated\crayon\<id>.png (make-unlock-art.js takes them as the
// crayon twins) and crayon-pieces.png there: each painting above its crayon version.
// Usage: node tools/make-crayon-pieces.js [filter] [--force]   (filter: ids containing it; made ones are skipped)
const fs = require("fs");
const os = require("os");
const path = require("path");
const crayon = require("./make-role-icons");
const { decodePng, resample } = require("./convert-art");

const S = 1254, L = 314;  // the canvas, and the size the shapes are found at
crayon.setSize(S);
const { canvas, stroke, crayonShape, hex, OUTLINE, rng, writePng } = crayon;
const GEN = path.join(os.homedir(), "killtracker-art-extra", "Unlocks", "generated");
const args = process.argv.slice(2), force = args.includes("--force");
const filter = args.find((a) => !a.startsWith("--")) || "";

// k-means on colours: the centres.
function kmeans(px, k, r) {
  let c = Array.from({ length: k }, () => px[Math.floor(r() * px.length)].slice());
  for (let it = 0; it < 12; it++) {
    const sum = c.map(() => [0, 0, 0, 0]);
    for (const p of px) { let b = 0, bd = 1e9; c.forEach((q, i) => { const d = (p[0] - q[0]) ** 2 + (p[1] - q[1]) ** 2 + (p[2] - q[2]) ** 2; if (d < bd) { bd = d; b = i; } }); sum[b][0] += p[0]; sum[b][1] += p[1]; sum[b][2] += p[2]; sum[b][3]++; }
    c = sum.map((s, i) => (s[3] ? [s[0] / s[3], s[1] / s[3], s[2] / s[3]] : c[i]));
  }
  return c;
}
// The outlines of a mask's areas (each a polygon, in L pixels), traced round each patch of at least min pixels.
function outlines(mask, min) {
  const seen = new Uint8Array(L * L), polys = [];
  const at = (x, y) => x >= 0 && y >= 0 && x < L && y < L && mask[y * L + x];
  for (let start = 0; start < L * L; start++) {
    if (!mask[start] || seen[start]) continue;
    const st = [start], patch = [];
    seen[start] = 1;
    while (st.length) { const p = st.pop(); patch.push(p); const x = p % L, y = (p / L) | 0;
      for (const q of [x > 0 ? p - 1 : -1, x < L - 1 ? p + 1 : -1, y > 0 ? p - L : -1, y < L - 1 ? p + L : -1]) if (q >= 0 && mask[q] && !seen[q]) { seen[q] = 1; st.push(q); } }
    if (patch.length < min) continue;
    // Moore tracing round the patch from its top-left pixel.
    const first = Math.min(...patch), sx = first % L, sy = (first / L) | 0;
    const dirs = [[1, 0], [1, 1], [0, 1], [-1, 1], [-1, 0], [-1, -1], [0, -1], [1, -1]];
    let x = sx, y = sy, d = 6; const pts = [];
    for (let n = 0; n < L * L * 2; n++) {
      pts.push([x, y]);
      let found = false;
      for (let k = 0; k < 8; k++) { const dd = (d + 6 + k) % 8, nx = x + dirs[dd][0], ny = y + dirs[dd][1];
        if (at(nx, ny) && patch.length) { x = nx; y = ny; d = dd; found = true; break; } }
      if (!found || (x === sx && y === sy && pts.length > 2)) break;
    }
    polys.push(simplify(pts, 1.6));
  }
  return polys;
}
// How round a shape is (1: a circle; a ragged blotch: near 0).
function compact(poly) {
  let a = 0, p = 0;
  for (let i = 0; i < poly.length; i++) { const [x1, y1] = poly[i], [x2, y2] = poly[(i + 1) % poly.length]; a += x1 * y2 - x2 * y1; p += Math.hypot(x2 - x1, y2 - y1); }
  return p ? (4 * Math.PI * Math.abs(a / 2)) / (p * p) : 0;
}
function simplify(pts, eps) {  // Ramer-Douglas-Peucker
  if (pts.length < 4) return pts;
  const [a, b] = [pts[0], pts[pts.length - 1]];
  let best = 0, bi = 0;
  for (let i = 1; i < pts.length - 1; i++) { const p = pts[i], dx = b[0] - a[0], dy = b[1] - a[1], len = Math.hypot(dx, dy) || 1;
    const d = Math.abs(dy * p[0] - dx * p[1] + b[0] * a[1] - b[1] * a[0]) / len; if (d > best) { best = d; bi = i; } }
  if (best <= eps) return [a, b];
  return simplify(pts.slice(0, bi + 1), eps).slice(0, -1).concat(simplify(pts.slice(bi), eps));
}
// A label map smoothed: each pixel takes the most common label round it (big calm areas, the kid's way).
function smooth(labels, k, rad, times) {
  for (let t = 0; t < times; t++) {
    const out = Int8Array.from(labels);
    for (let y = 0; y < L; y++) for (let x = 0; x < L; x++) {
      const i = y * L + x; if (labels[i] < 0) continue;
      const count = new Array(k).fill(0);
      for (let dy = -rad; dy <= rad; dy++) for (let dx = -rad; dx <= rad; dx++) { const j = (y + dy) * L + x + dx; if (y + dy >= 0 && y + dy < L && x + dx >= 0 && x + dx < L && labels[j] >= 0) count[labels[j]]++; }
      out[i] = count.indexOf(Math.max(...count));
    }
    labels = out;
  }
  return labels;
}

// The recipes, by piece id. draw(d, r): d = { fill(points, colour, opts), line(points, width, colour),
// circle(x, y, radius, colour), rect(x0, y0, x1, y1, colour) }, all in the piece's box (0..1; a radius in box widths).
const GREY = "#9a9aa4", BONE = "#f0e6d0", GOLD = "#e8b84a", INK = "#2b1a10";
// Button eyes (a black dot with a shine), big googly eyes (white with a pupil), teeth along a line, a triangle.
const eyes = (d, pts, rad = 0.035) => { for (const [x, y] of pts) { d.circle(x, y, rad, INK); d.circle(x - rad * 0.3, y - rad * 0.3, rad * 0.3, "#ffffff", { line: 0 }); } };
const googly = (d, pts, rad = 0.07) => { for (const [x, y] of pts) { d.circle(x, y, rad, "#ffffff"); d.circle(x + rad * 0.15, y + rad * 0.15, rad * 0.45, INK); } };
const teeth = (d, x0, x1, y, n, h = 0.08, col = BONE) => { for (let k = 0; k < n; k++) { const x = x0 + (x1 - x0) * (n === 1 ? 0.5 : k / (n - 1)), w = Math.min(0.03, (x1 - x0) / n / 2); d.fill([[x - w, y], [x, y + h], [x + w, y]], col, { line: 5, hatch: 5 }); } };
const tri = (d, a, b, c, col) => d.fill([a, b, c], col);
// A onesie's belly patch (an egg shape from x0..x1, y0..y1), and a row of buttons down x.
const belly = (d, col, x0 = 0.3, x1 = 0.7, y0 = 0.2, y1 = 0.95) => d.fill(Array.from({ length: 24 }, (_, i) => { const a = (i / 24) * 2 * Math.PI, cx = (x0 + x1) / 2, cy = (y0 + y1) / 2;
  return [cx + Math.cos(a) * (x1 - x0) / 2 * (Math.sin(a) < 0 ? 0.85 : 1), cy + Math.sin(a) * (y1 - y0) / 2]; }), col, { hatch: 16, line: 10 });
const buttons = (d, x, ys, col = "#6a4026", rad = 0.02) => { for (const y of ys) d.circle(x, y, rad, col); };
// The dragonflights' whelp costumes (repaints of the dragonkin's, tools/gen-art-dragonflights.json): the dragonkin's
// recipe in each flight's colours - its sequins (base), belly panel, horns and spikes - and Bronze's hourglass patch.
function Flight(base, belly, horn, extra, spike = horn, snout = belly) {
  return {
    // (the hat, read off the painting: spikes down the back on the left, three horns on top, the snout and eye at the front)
    head: { base, areas: false, draw: (d) => {
      for (const [tip, a, b] of [[[0.16, 0.18], [0.36, 0.17], [0.3, 0.32]], [[0.02, 0.45], [0.22, 0.36], [0.22, 0.53]],
        [[0.0, 0.74], [0.17, 0.6], [0.16, 0.76]], [[0.02, 0.95], [0.15, 0.82], [0.16, 0.93]]]) tri(d, tip, a, b, spike);
      for (const [tip, a, b] of [[[0.45, 0.0], [0.39, 0.19], [0.55, 0.16]], [[0.65, 0.02], [0.58, 0.14], [0.72, 0.14]],
        [[0.93, 0.04], [0.82, 0.19], [0.96, 0.17]]]) tri(d, tip, a, b, horn);
      d.fill(Array.from({ length: 20 }, (_, i) => { const t = (i / 20) * 2 * Math.PI; return [0.74 + Math.cos(t) * 0.18, 0.36 + Math.sin(t) * 0.09]; }), snout, { hatch: 12, line: 10 });
      for (const x of [0.72, 0.86]) d.circle(x, 0.35, 0.018, INK);
      eyes(d, [[0.56, 0.27]], 0.045);
    } },
    body: { base, areas: false, draw: (d) => { d.fill([[0.32, 0.12], [0.68, 0.12], [0.72, 0.98], [0.28, 0.98]], belly); for (const y of [0.3, 0.45, 0.6, 0.75, 0.9]) d.line([[0.32, y], [0.68, y]], 6, horn); tri(d, [0.12, 0.1], [0.2, -0.02], [0.28, 0.08], horn); tri(d, [0.72, 0.08], [0.8, -0.02], [0.88, 0.1], horn); if (extra) extra(d); } },
  };
}
const FLIGHTS = {
  black: Flight("#2e2a32", "#f07a20", "#f07a20"),
  red: Flight("#d8302a", "#f8c840", "#f8c840"),
  green: Flight("#2f8a4a", "#f0dcb0", "#f0dcb0", null, "#b070d0", "#f0b8a8"),
  blue: Flight("#2f6ad8", "#e8f0f8", "#bfe4ff"),
  bronze: Flight("#c8782e", "#f0d8a8", "#f0c040", (d) => { d.fill([[0.56, 0.62], [0.66, 0.62], [0.61, 0.7]], GOLD); d.fill([[0.56, 0.78], [0.66, 0.78], [0.61, 0.7]], GOLD); }),
};
const RECIPES = {
  ...Object.fromEntries(Object.entries(FLIGHTS).flatMap(([k, r]) => [["crit_" + k + "flight_head", r.head], ["crit_" + k + "flight_body", r.body]])),
  // --- Factions ---
  fac_blackrock_head: { base: "#4a4448", areas: false, draw: (d) => {
    for (const x of [0.22, 0.62]) d.fill([[x, 0.38], [x + 0.07, 0.36], [x + 0.1, 0.72], [x + 0.03, 0.74]], "#d8302e");
    d.fill([[0.44, 0.32], [0.5, 0.02], [0.56, 0.32]], GREY);
    d.fill([[0.24, 0.36], [0.26, 0.16], [0.33, 0.33]], GREY); d.fill([[0.67, 0.33], [0.74, 0.16], [0.76, 0.36]], GREY);
    d.fill([[0.04, 0.5], [0.0, 0.38], [0.12, 0.44]], GREY); d.fill([[0.88, 0.44], [1, 0.38], [0.96, 0.5]], GREY);
  } },
  fac_blackrock_body: { base: "#4a4448", areas: false, draw: (d) => {
    d.fill([[0.3, 0.24], [0.37, 0.24], [0.45, 0.56], [0.38, 0.56]], "#d8302e"); d.fill([[0.63, 0.24], [0.7, 0.24], [0.62, 0.56], [0.55, 0.56]], "#d8302e");
    d.fill([[0.04, 0.16], [0.11, 0.13], [0.17, 0.42], [0.1, 0.44]], "#d8302e"); d.fill([[0.89, 0.13], [0.96, 0.16], [0.9, 0.44], [0.83, 0.42]], "#d8302e");
    d.rect(0.28, 0.74, 0.72, 0.81, "#6a4a3a"); d.rect(0.44, 0.73, 0.56, 0.82, GREY);
    d.fill([[0.4, 0.84], [0.6, 0.84], [0.58, 1], [0.42, 1]], "#c8282e");
    for (const [x, y] of [[0.08, 0.13], [0.2, 0.08], [0.8, 0.08], [0.92, 0.13]]) d.fill([[x - 0.04, y], [x, y - 0.12], [x + 0.04, y]], GREY);
  } },
  fac_venture_head: { base: "#f0b830", areas: false, draw: (d) => {
    d.fill([[0.16, 0.36], [0.86, 0.32], [0.88, 0.46], [0.16, 0.5]], "#7a4a2e");
    d.circle(0.6, 0.26, 0.17, GREY); d.circle(0.6, 0.26, 0.1, "#fff4a0");
  } },
  fac_venture_body: { base: "#f0b830", areas: false, draw: (d) => {
    for (const x of [0.12, 0.27, 0.42, 0.57, 0.72, 0.87]) d.rect(x - 0.035, 0.2, x + 0.035, 0.72, "#2e2824");
    d.rect(0.33, 0.31, 0.67, 0.42, "#d8b880");
    d.rect(0.0, 0.74, 1, 0.84, "#7a4a2e"); d.rect(0.42, 0.74, 0.58, 0.84, GOLD);
    d.line([[0.05, 0.58], [0.05, 0.76]], 14, GREY); d.line([[0.95, 0.58], [0.95, 0.76]], 14, GREY);
  } },
  fac_defias_head: { base: "#3e3634", areas: false, draw: (d) => {
    d.fill([[0.08, 0.36], [0.5, 0.26], [0.88, 0.3], [0.9, 0.46], [0.5, 0.42], [0.14, 0.52]], "#d8302e");
    d.fill([[0.0, 0.56], [0.14, 0.48], [0.2, 0.6], [0.1, 0.78]], "#d8302e");
  } },
  fac_defias_body: { base: "#7a5034", draw: (d) => {
    for (const y of [0.38, 0.5, 0.62]) d.rect(0.45, y, 0.55, y + 0.045, GOLD);
    d.fill([[0.08, 0.8], [0.92, 0.8], [0.94, 0.92], [0.06, 0.92]], "#d8302e");
    d.line([[0.74, 0.04], [0.84, 0.12], [0.82, 0.3], [0.76, 0.42]], 22, "#e0b864");
  } },
  fac_kolkar_head: { base: "#a85a34", draw: (d) => {
    for (const [x, y, col] of [[0.27, 0.56, "#3a9ab0"], [0.3, 0.68, "#d8302e"], [0.73, 0.56, "#3a9ab0"], [0.7, 0.68, "#d8302e"]]) d.circle(x, y, 0.035, col);
    d.circle(0.5, 0.36, 0.07, BONE);
  } },
  fac_kolkar_body: { base: "#d8803e", areas: false, draw: (d) => {
    d.fill([[0.2, 0.3], [0.5, 0.36], [0.45, 0.6], [0.15, 0.55]], "#f0c080"); d.fill([[0.55, 0.45], [0.85, 0.4], [0.88, 0.7], [0.58, 0.72]], "#f0c080");
    for (const [x0, y0] of [[0.62, 0.12], [0.7, 0.3], [0.3, 0.62]]) d.line([[x0, y0], [x0 + 0.12, y0 + 0.14]], 16, "#c8402e");
    d.line([[0.25, 0.1], [0.38, 0.22], [0.5, 0.26], [0.62, 0.22], [0.75, 0.1]], 8, "#5a3418");
    for (const x of [0.32, 0.42, 0.5, 0.58, 0.68]) d.fill([[x - 0.02, 0.22], [x, 0.3], [x + 0.02, 0.22]], BONE, { line: 6, hatch: 6 });
  } },
  fac_burningblade_head: { base: "#b8282e", areas: false, draw: (d) => {
    d.fill([[0.28, 0.32], [0.34, 0.12], [0.4, 0.24], [0.47, 0.04], [0.53, 0.22], [0.6, 0.08], [0.66, 0.3], [0.5, 0.28]], "#ff9a2a");
    d.fill([[0.06, 0.8], [0.1, 0.62], [0.14, 0.74]], "#ff9a2a"); d.fill([[0.86, 0.74], [0.9, 0.62], [0.94, 0.8]], "#ff9a2a");
  } },
  fac_burningblade_body: { base: "#8a1e22", areas: false, draw: (d) => {
    d.fill([[0.47, 0.2], [0.53, 0.2], [0.53, 0.55], [0.58, 0.55], [0.5, 0.76], [0.42, 0.55], [0.47, 0.55]], "#ffa030");
    d.rect(0.38, 0.29, 0.62, 0.35, "#ffa030");
    for (const [x, y] of [[0.14, 0.18], [0.86, 0.18], [0.16, 0.6], [0.84, 0.6]]) d.fill([[x - 0.06, y + 0.08], [x - 0.02, y - 0.06], [x + 0.01, y + 0.02], [x + 0.05, y - 0.08], [x + 0.06, y + 0.08]], "#ff8a2a");
    for (const x of [0.4, 0.5, 0.6]) d.line([[x - 0.02, 0.86], [x + 0.02, 0.9], [x - 0.02, 0.94]], 8, "#ffd060");
  } },
  fac_syndicate_head: { base: "#3a3434" },
  fac_syndicate_body: { base: "#5a4a3c", areas: false, draw: (d) => {
    d.fill([[0.62, 0.0], [0.76, 0.0], [0.42, 0.72], [0.28, 0.72]], "#ff8a2a");
    d.rect(0.12, 0.6, 0.88, 0.67, "#3a2a20"); d.rect(0.45, 0.59, 0.55, 0.68, GOLD);
    d.fill([[0.18, 0.7], [0.86, 0.7], [0.9, 0.82], [0.14, 0.82]], "#ff8a2a");
    for (const x of [0.2, 0.68]) d.rect(x, 0.42, x + 0.1, 0.55, "#6a5442");
  } },
  fac_scarlet_head: { base: "#d0282e", areas: false, draw: (d) => {
    d.fill([[0.0, 0.62], [0.5, 0.48], [1, 0.62], [1, 0.8], [0.5, 0.64], [0.0, 0.8]], "#fff0e0");
    d.fill([[0.5, 0.12], [0.57, 0.28], [0.63, 0.22], [0.6, 0.42], [0.4, 0.42], [0.37, 0.22], [0.43, 0.28]], "#fff0c8");
  } },
  fac_scarlet_body: { base: "#d0282e", draw: (d) => {
    d.fill([[0.5, 0.2], [0.56, 0.36], [0.63, 0.3], [0.58, 0.5], [0.5, 0.72], [0.42, 0.5], [0.37, 0.3], [0.44, 0.36]], "#fff0c8");
  } },
  fac_bloodsail_head: { base: "#3a3236", areas: false, draw: (d) => {
    d.fill([[0.6, 0.36], [0.62, 0.06], [0.76, 0.0], [0.92, 0.1], [0.86, 0.3], [0.72, 0.4]], "#d8282e");
    d.circle(0.6, 0.36, 0.07, BONE);
    d.line([[0.06, 0.62], [0.3, 0.3], [0.5, 0.2]], 8, GOLD);
  } },
  // --- Gear sets (each dungeon's boss look) ---
  gear_barrow_body: { base: "#6a3a9a", areas: false, draw: (d) => {
    for (const x of [0.3, 0.66]) d.rect(x, 0.05, x + 0.04, 1, "#d0c8e0");
    d.rect(0.46, 0.15, 0.54, 1, "#a87ad8"); d.rect(0.1, 0.66, 0.9, 0.72, "#d0c8e0");
    d.circle(0.5, 0.12, 0.025, "#e0b8ff");
    for (const [x, y] of [[0.16, 0.3], [0.84, 0.3], [0.16, 0.5], [0.84, 0.5]]) d.fill([[x, y - 0.06], [x + 0.03, y], [x, y + 0.06], [x - 0.03, y]], "#c8a0e8", { line: 6, hatch: 6 });
  } },
  gear_barrow_head: { base: "#c8c8d8", areas: false, draw: (d) => {
    d.line([[0.34, 0.16], [0.5, 0.1], [0.7, 0.16]], 14, "#c8b040"); d.circle(0.53, 0.2, 0.07, "#d8b0ff");
  } },
  gear_bfd_body: { base: "#4a5a8a", areas: false, draw: (d) => {
    d.fill([[0.3, 0.2], [0.7, 0.2], [0.72, 0.98], [0.28, 0.98]], "#f0dca8");
    for (const y of [0.4, 0.6, 0.8]) d.line([[0.3, y], [0.7, y]], 6, "#c8a878");
    d.line([[0.5, 0.15], [0.5, 1]], 8, "#5a4a3a");
    for (const [x, y] of [[0.12, 0.1], [0.26, 0.05], [0.74, 0.05], [0.88, 0.1]]) d.fill([[x - 0.04, y + 0.06], [x, y - 0.06], [x + 0.04, y + 0.06]], "#f0d0a0", { line: 6, hatch: 6 });
  } },
  gear_bfd_head: { base: "#5a6a9a", areas: false, draw: (d) => {
    for (const x of [0.35, 0.73]) { d.circle(x, 0.3, 0.06, "#ffc020"); d.circle(x, 0.3, 0.02, "#2b1a10"); }
    for (let k = 0; k < 6; k++) { const x = 0.3 + k * 0.09; d.fill([[x - 0.03, 0.46], [x, 0.56], [x + 0.03, 0.46]], "#f0e0c0", { line: 6, hatch: 6 }); }
    for (const x of [0.3, 0.45, 0.6, 0.75]) d.fill([[x - 0.04, 0.12], [x, 0.0], [x + 0.04, 0.12]], "#f0d0a0", { line: 6, hatch: 6 });
  } },
  gear_brd_body: { base: "#2e2a2a", areas: false, draw: (d) => {
    for (const x of [0.22, 0.68]) { d.rect(x, 0.02, x + 0.1, 1, "#d8302e"); d.line([[x, 0.02], [x, 1]], 8, "#e8a830"); d.line([[x + 0.1, 0.02], [x + 0.1, 1]], 8, "#e8a830"); }
    d.fill([[0.0, 0.06], [0.22, 0.0], [0.25, 0.22], [0.0, 0.26]], "#e8a830"); d.fill([[0.78, 0.0], [1, 0.06], [1, 0.26], [0.75, 0.22]], "#e8a830");
    d.rect(0.2, 0.62, 0.8, 0.72, "#e8a830"); d.circle(0.5, 0.67, 0.06, "#ffd060");
  } },
  gear_brd_head: { base: "#4a3426", areas: false, draw: (d) => {
    d.rect(0.3, 0.0, 0.72, 0.09, "#c8282e"); d.rect(0.28, 0.08, 0.74, 0.12, "#e8a830");
    for (const [x0, y0] of [[0.22, 0.58], [0.67, 0.58], [0.44, 0.72]]) d.rect(x0, y0, x0 + 0.1, y0 + 0.08, "#e8a830");
  } },
  gear_dm_body: { base: "#2e3448", areas: false, draw: (d) => {
    for (const x of [0.44, 0.56]) d.line([[x, 0.05], [x, 0.92]], 10, "#d8a030");
    for (const y of [0.34, 0.47, 0.6]) d.rect(0.44, y, 0.56, y + 0.05, "#8a5a2e");
    for (const x of [0.12, 0.88]) d.line([[x - 0.06, 0.2], [x, 0.12], [x + 0.06, 0.2], [x, 0.28]], 8, "#d8a030");
    d.rect(0.22, 0.88, 0.78, 0.94, "#8a5a2e");
  } },
  gear_dm_head: { base: "#2a2422", areas: false, draw: (d) => {
    d.fill([[0.34, 0.42], [0.9, 0.38], [0.86, 0.6], [0.6, 0.86], [0.4, 0.6]], "#d8282e"); d.circle(0.1, 0.34, 0.05, "#d8282e");
  } },
  gear_dme_body: { base: "#5a3e26", draw: (d) => {
    for (const [x, y] of [[0.1, 0.22], [0.2, 0.1], [0.84, 0.1], [0.92, 0.26], [0.04, 0.4], [0.96, 0.42]]) d.circle(x, y, 0.025, "#ffffff");
    for (const [x, y] of [[0.14, 0.32], [0.88, 0.34], [0.24, 0.2], [0.78, 0.2]]) d.fill([[x, y - 0.03], [x + 0.04, y], [x, y + 0.03], [x - 0.04, y]], "#5bb43a", { line: 6, hatch: 6 });
  } },
  gear_dme_head: { base: "#3a4a2a", draw: (d) => {
    d.line([[0.14, 0.42], [0.2, 0.7]], 10, "#8af06a"); d.line([[0.86, 0.42], [0.8, 0.7]], 10, "#8af06a");
  } },
  gear_dmn_body: { base: "#7a2a9a", areas: false, draw: (d) => {
    d.fill([[0.04, 0.0], [0.96, 0.0], [0.86, 0.16], [0.5, 0.24], [0.14, 0.16]], "#f0d8a0");
    d.line([[0.3, 0.08], [0.5, 0.2], [0.7, 0.08]], 14, "#e8b030");
    d.rect(0.14, 0.68, 0.86, 0.76, "#7a4a2e"); d.rect(0.45, 0.66, 0.55, 0.78, "#e8b030");
  } },
  gear_dmn_head: { base: "#e0a830", areas: false, draw: (d) => { d.circle(0.5, 0.74, 0.04, "#c8402e"); d.circle(0.3, 0.8, 0.03, "#c8402e"); d.circle(0.7, 0.8, 0.03, "#c8402e"); } },
  gear_dmw_body: { base: "#e8902e", areas: false, draw: (d) => {
    for (const [x0, y0] of [[0.05, 0.25], [0.2, 0.45], [0.55, 0.3], [0.7, 0.55], [0.3, 0.75], [0.6, 0.85]]) d.line([[x0, y0], [x0 + 0.18, y0 - 0.08]], 22, "#6a8a3a");
    d.line([[0.25, 0.08], [0.5, 0.2], [0.75, 0.08]], 10, "#ffd060");
  } },
  gear_dmw_head: { base: "#f0d890", areas: false, draw: (d) => {
    for (const x of [0.12, 0.2, 0.8, 0.88]) d.line([[x, 0.3], [x - 0.02, 0.9]], 6, "#c8a860");
  } },
  gear_excav_body: { base: "#a8988a", areas: false, draw: (d) => {
    for (const y of [0.24, 0.6]) d.rect(0.12, y, 0.88, y + 0.05, "#3ad8d0");
    d.fill([[0.5, 0.18], [0.56, 0.27], [0.5, 0.36], [0.44, 0.27]], "#3ad8d0");
    for (const x of [0.04, 0.96]) d.rect(x - 0.04, 0.72, x + 0.04, 0.78, "#3ad8d0");
  } },
  gear_excav_head: { base: "#8a7a6a", areas: false, draw: (d) => {
    d.rect(0.14, 0.42, 0.86, 0.54, "#3ad8d0"); d.fill([[0.5, 0.34], [0.58, 0.48], [0.5, 0.62], [0.42, 0.48]], "#3ad8d0");
  } },
  gear_gnomer_body: { base: "#e8742e", areas: false, draw: (d) => {
    d.circle(0.5, 0.26, 0.1, "#7a7a8a"); d.circle(0.5, 0.26, 0.06, "#d8ff3a");
    for (const [x, y] of [[0.2, 0.2], [0.8, 0.2], [0.3, 0.55], [0.7, 0.55], [0.5, 0.75]]) d.circle(x, y, 0.02, "#7a7a8a");
    d.fill([[0.14, 0.06], [0.2, -0.02], [0.24, 0.08]], "#e8a030"); d.fill([[0.76, 0.08], [0.8, -0.02], [0.86, 0.06]], "#e8a030");
    d.rect(0.2, 0.62, 0.8, 0.67, "#7a7a8a");
  } },
  gear_gnomer_head: { base: "#d8662a", areas: false, draw: (d) => {
    for (const x of [0.32, 0.7]) { d.circle(x, 0.28, 0.1, "#7a7a8a"); d.circle(x, 0.28, 0.065, "#c8ff3a"); }
    d.fill([[0.18, 0.18], [0.24, 0.0], [0.3, 0.16]], "#e8a030"); d.fill([[0.7, 0.16], [0.78, 0.0], [0.84, 0.18]], "#e8a030");
  } },
  gear_hyjal_body: { base: "#a8683a", areas: false, draw: (d) => {
    for (const [x0, y0, x1, y1] of [[0.1, 0.1], [0.3, 0.3], [0.6, 0.15], [0.2, 0.6], [0.65, 0.55]].map(([a, b]) => [a, b, a + 0.2, b + 0.2])) d.line([[x0, y0], [(x0 + x1) / 2 + 0.05, (y0 + y1) / 2], [x1, y1]], 12, "#5bb43a");
    for (const [x, y] of [[0.2, 0.15], [0.45, 0.4], [0.75, 0.25], [0.35, 0.7], [0.8, 0.65]]) d.fill([[x, y - 0.035], [x + 0.04, y], [x, y + 0.035], [x - 0.04, y]], "#7ad65a", { line: 6, hatch: 6 });
  } },
  gear_hyjal_head: { base: "#b8885a", areas: false, draw: (d) => {
    for (const [x, y] of [[0.15, 0.6], [0.3, 0.5], [0.45, 0.7], [0.6, 0.55], [0.75, 0.62], [0.9, 0.5]]) d.fill([[x, y - 0.05], [x + 0.04, y], [x, y + 0.08], [x - 0.04, y]], "#5bb43a", { line: 6, hatch: 6 });
  } },
  gear_lbrs_body: { base: "#5a4a44", areas: false, draw: (d) => {
    d.fill([[0.2, 0.3], [0.32, 0.24], [0.84, 0.62], [0.72, 0.68]], "#c8282e");
    for (const [x, y] of [[0.1, 0.1], [0.25, 0.06], [0.75, 0.06], [0.9, 0.1]]) d.fill([[x - 0.04, y + 0.06], [x, y - 0.08], [x + 0.04, y + 0.06]], "#b8a8a0");
    d.fill([[0.5, 0.2], [0.55, 0.28], [0.5, 0.36], [0.45, 0.28]], "#c8a060"); d.rect(0.38, 0.92, 0.62, 1, "#c8282e");
  } },
  gear_lbrs_head: { base: "#6a4a3a", areas: false, draw: (d) => {
    for (const [x, y, h] of [[0.5, 0.3, 0.3], [0.32, 0.36, 0.16], [0.68, 0.36, 0.16], [0.14, 0.42, 0.1], [0.86, 0.42, 0.1]]) d.fill([[x - 0.06, y], [x, y - h], [x + 0.06, y]], "#c8b0a8");
    d.fill([[0.5, 0.36], [0.55, 0.42], [0.5, 0.48], [0.45, 0.42]], "#c8a060");
  } },
  gear_mara_body: { base: "#8a6a3a", areas: false, draw: (d) => {
    for (const [x, y] of [[0.1, 0.06], [0.18, 0.12], [0.84, 0.06], [0.9, 0.14], [0.14, 0.86], [0.86, 0.86]]) d.fill([[x - 0.03, y + 0.06], [x, y - 0.08], [x + 0.03, y + 0.06]], "#b06aff");
    d.fill([[0.5, 0.36], [0.53, 0.42], [0.5, 0.48], [0.47, 0.42]], "#b06aff");
    for (const [x0, y0] of [[0.2, 0.3], [0.62, 0.32], [0.3, 0.6], [0.62, 0.62]]) d.line([[x0, y0], [x0 + 0.12, y0 + 0.08]], 12, "#6aa83a");
  } },
  gear_mara_head: { base: "#8a5a3a", areas: false, draw: (d) => {
    for (const [x, y, h] of [[0.5, 0.42, 0.42], [0.3, 0.46, 0.2], [0.7, 0.46, 0.2], [0.12, 0.6, 0.14], [0.88, 0.6, 0.14]]) d.fill([[x - 0.05, y], [x - 0.03, y - h * 0.8], [x, y - h], [x + 0.03, y - h * 0.8], [x + 0.05, y]], "#b06aff");
  } },
  gear_ony_body: { base: "#3a2a2a", areas: false, draw: (d) => {
    d.fill([[0.3, 0.2], [0.7, 0.2], [0.74, 0.92], [0.26, 0.92]], "#f0d8a8");
    for (const y of [0.35, 0.5, 0.65, 0.8]) d.circle(0.5, y, 0.015, "#8a4a2e");
    d.fill([[0.0, 0.05], [0.2, 0.0], [0.12, 0.2]], "#8a2a2e"); d.fill([[0.8, 0.0], [1, 0.05], [0.88, 0.2]], "#8a2a2e");
  } },
  gear_ony_head: { base: "#4a2a2e", areas: false, draw: (d) => {
    for (const x of [0.33, 0.68]) { d.circle(x, 0.28, 0.05, "#d88a3a"); d.line([[x - 0.02, 0.26], [x + 0.02, 0.3]], 5, "#2b1a10"); }
    d.fill([[0.14, 0.26], [0.1, 0.02], [0.24, 0.2]], "#f0e0c0"); d.fill([[0.76, 0.2], [0.9, 0.02], [0.86, 0.26]], "#f0e0c0");
    for (let k = 0; k < 5; k++) { const x = 0.32 + k * 0.09; d.fill([[x - 0.025, 0.44], [x, 0.54], [x + 0.025, 0.44]], "#f0e6d0", { line: 5, hatch: 5 }); }
    for (const x of [0.4, 0.5, 0.6]) d.fill([[x - 0.03, 0.06], [x, -0.02], [x + 0.03, 0.06]], "#c8283e", { line: 6, hatch: 6 });
  } },
  gear_rfc_body: { base: "#b8282e", areas: false, draw: (d) => {
    d.line([[0.32, 0.6], [0.5, 0.64], [0.68, 0.6]], 14, "#d8b060");
    d.fill([[0.45, 0.06], [0.5, 0.16], [0.55, 0.06]], "#e8e0d0", { line: 6, hatch: 6 });
    d.rect(0.38, 0.76, 0.44, 1, "#3a2a2a"); d.rect(0.56, 0.76, 0.62, 1, "#3a2a2a");
  } },
  gear_rfc_head: { base: "#3a3a2e", areas: false, draw: (d) => {
    d.fill([[0.0, 0.1], [0.12, 0.0], [0.2, 0.06], [0.08, 0.2]], "#c8ff3a"); d.fill([[0.8, 0.06], [0.88, 0.0], [1, 0.1], [0.92, 0.2]], "#c8ff3a");
    d.line([[0.06, 0.4], [0.1, 0.6]], 8, "#7aff3a"); d.line([[0.94, 0.4], [0.9, 0.6]], 8, "#7aff3a");
    d.fill([[0.5, 0.42], [0.55, 0.52], [0.5, 0.62], [0.45, 0.52]], "#7aff3a");
  } },
  gear_rfd_body: { base: "#2e3a5a", areas: false, draw: (d) => {
    for (const [x, y] of [[0.1, 0.1], [0.2, 0.04], [0.8, 0.04], [0.9, 0.1]]) d.fill([[x - 0.04, y + 0.08], [x, y - 0.06], [x + 0.04, y + 0.08]], "#bfe8ff");
    d.circle(0.42, 0.17, 0.03, "#f0e6d0"); d.circle(0.6, 0.17, 0.03, "#f0e6d0"); d.line([[0.42, 0.17], [0.6, 0.17]], 6, "#9aa0a8");
    for (const [x0, y0] of [[0.12, 0.4], [0.82, 0.4], [0.16, 0.7], [0.8, 0.7]]) d.line([[x0, y0], [x0 + 0.04, y0 + 0.12]], 8, "#9ad8ff");
  } },
  gear_rfd_head: { base: "#a8d8f8", areas: false, draw: (d) => {
    for (const [x, h] of [[0.2, 0.3], [0.38, 0.5], [0.5, 0.8], [0.62, 0.5], [0.8, 0.3]]) d.fill([[x - 0.05, 0.75], [x, 0.75 - h], [x + 0.05, 0.75]], "#e8f8ff");
  } },
  gear_rfk_body: { base: "#c8a070", areas: false, draw: (d) => {
    d.line([[0.12, 0.0], [0.5, 0.32], [0.88, 0.0]], 18, "#f0dcb0"); d.line([[0.36, 0.0], [0.5, 0.18], [0.64, 0.0]], 14, "#f0dcb0");
    for (const [x, y] of [[0.05, 0.36], [0.95, 0.36]]) d.circle(x, y, 0.05, "#8a4a2e");
    d.fill([[0.18, 0.85], [0.82, 0.85], [0.78, 1], [0.22, 1]], "#8a4a2e");
  } },
  gear_rfk_head: { base: "#e8d0a0", areas: false, draw: (d) => {
    for (const x of [0.38, 0.6]) d.circle(x, 0.38, 0.06, "#4a3020");
    d.circle(0.48, 0.6, 0.05, "#4a3020"); d.circle(0.56, 0.6, 0.05, "#4a3020");
    d.fill([[0.06, 0.3], [0.02, 0.0], [0.16, 0.24]], "#f8f0d8"); d.fill([[0.84, 0.24], [0.98, 0.0], [0.94, 0.3]], "#f8f0d8");
  } },
  gear_ruins_body: { base: "#c8282e", areas: false, draw: (d) => {
    d.fill([[0.26, 0.12], [0.74, 0.12], [0.72, 1], [0.28, 1]], "#2a2424");
    for (const y of [0.22, 0.3, 0.38, 0.46, 0.54]) { d.line([[0.32, y], [0.47, y + 0.03]], 10, "#f0e0b0"); d.line([[0.53, y + 0.03], [0.68, y]], 10, "#f0e0b0"); }
    d.line([[0.5, 0.18], [0.5, 0.72]], 12, "#f0e0b0");
    d.circle(0.2, 0.12, 0.04, "#f0e0b0"); d.circle(0.8, 0.12, 0.04, "#f0e0b0");
  } },
  gear_ruins_head: { base: "#f0e6d8", areas: false, draw: (d) => {
    d.fill([[0.3, 0.2], [0.38, 0.0], [0.5, 0.06], [0.6, 0.0], [0.72, 0.2]], "#7ab8f0");
    for (const x of [0.33, 0.67]) d.circle(x, 0.35, 0.07, "#4a4040");
  } },
  gear_scholo_body: { base: "#2a2426", areas: false, draw: (d) => {
    for (const x of [0.42, 0.58]) d.rect(x - 0.035, 0.0, x + 0.035, 1, "#a040d8");
    for (const y of [0.2, 0.28]) d.rect(0.44, y, 0.56, y + 0.04, "#f0e0b0");
    for (const y of [0.4, 0.55, 0.7, 0.85]) { d.line([[0.39, y], [0.45, y + 0.04]], 6, "#e0a0ff"); d.line([[0.55, y], [0.61, y + 0.04]], 6, "#e0a0ff"); }
    d.rect(0.0, 0.84, 0.16, 0.9, "#a040d8"); d.rect(0.84, 0.84, 1, 0.9, "#a040d8");
  } },
  gear_scholo_head: { base: "#2e2830", areas: false, draw: (d) => {
    d.line([[0.06, 0.82], [0.2, 0.3], [0.5, 0.04], [0.8, 0.3], [0.94, 0.82]], 10, "#a040d8");
    for (const [x, y] of [[0.42, 0.14], [0.58, 0.14], [0.22, 0.45], [0.78, 0.45]]) d.fill([[x, y - 0.03], [x + 0.025, y], [x, y + 0.03], [x - 0.025, y]], "#e0a0ff", { line: 5, hatch: 5 });
  } },
  gear_sfk_body: { base: "#3a3030", areas: false, draw: (d) => {
    for (const [x, y] of [[0.06, 0.06], [0.2, 0.0], [0.8, 0.0], [0.94, 0.06]]) d.fill([[x - 0.035, y + 0.1], [x, y - 0.04], [x + 0.035, y + 0.1]], "#e8f060");
    d.line([[0.5, 0.1], [0.5, 0.9]], 10, "#c8b8a8");
    for (const y of [0.42, 0.58, 0.74]) d.fill([[0.5, y - 0.04], [0.54, y], [0.5, y + 0.04], [0.46, y]], "#c8b8a8", { line: 6, hatch: 6 });
  } },
  gear_sfk_head: { base: "#2a2426", areas: false, draw: (d) => {
    d.line([[0.06, 0.0], [0.14, 0.24], [0.5, 0.34], [0.86, 0.24], [0.94, 0.0]], 18, "#c8c0c0");
    d.fill([[0.44, 0.34], [0.5, 0.22], [0.56, 0.34], [0.5, 0.42]], "#c8c0c0");
  } },
  gear_smarm_body: { base: "#d0282e", areas: false, draw: (d) => {
    d.line([[0.22, 0.12], [0.5, 0.42], [0.78, 0.12]], 20, "#e8a830"); d.line([[0.24, 0.48], [0.5, 0.2], [0.76, 0.48]], 20, "#e8a830");
    d.circle(0.5, 0.33, 0.035, "#ffd060");
    d.rect(0.2, 0.84, 0.8, 0.92, "#e8a830"); d.rect(0.46, 0.83, 0.54, 0.93, "#ffd060");
    for (const x of [0.12, 0.88]) d.circle(x, 0.14, 0.03, "#ffd060");
  } },
  gear_smarm_head: { base: "#d0282e", areas: false, draw: (d) => {
    d.rect(0.48, 0.0, 0.56, 0.5, "#e8a830"); d.line([[0.06, 0.82], [0.2, 0.4], [0.5, 0.3], [0.8, 0.4]], 12, "#e8a830");
    d.circle(0.24, 0.5, 0.06, "#e8a830");
  } },
  gear_smcath_body: { base: "#d0282e", areas: false, draw: (d) => {
    for (const x of [0.28, 0.72]) d.rect(x - 0.08, 0.14, x + 0.08, 0.84, "#f0e0b8");
    d.rect(0.1, 0.72, 0.9, 0.8, "#c8282e");
    for (const x of [0.2, 0.36, 0.64, 0.8]) d.line([[x, 0.14], [x, 0.84]], 6, "#e8a830");
  } },
  gear_smcath_head: { base: "#f0f0f0", areas: false, draw: (d) => {
    d.rect(0.26, 0.0, 0.84, 0.16, "#c8282e"); d.line([[0.26, 0.16], [0.84, 0.16]], 8, "#e8a830");
    d.fill([[0.52, 0.02], [0.56, 0.08], [0.52, 0.14], [0.48, 0.08]], "#e8a830");
    for (const x of [0.08, 0.16, 0.84, 0.92]) d.line([[x, 0.3], [x, 0.9]], 6, "#c8c8d0");
  } },
  gear_smgy_body: { base: "#c8282e", areas: false, draw: (d) => {
    d.line([[0.42, 0.04], [0.5, 0.3], [0.58, 0.04]], 10, "#e8a830");
    for (const [x0, y0] of [[0.06, 0.8], [0.2, 0.86], [0.8, 0.86], [0.94, 0.8]]) d.fill([[x0 - 0.04, y0 + 0.12], [x0 - 0.02, y0], [x0, y0 + 0.08], [x0 + 0.02, y0 - 0.02], [x0 + 0.04, y0 + 0.12]], "#ff8a2a");
  } },
  gear_smgy_head: { base: "#c8282e", areas: false, draw: (d) => {
    d.line([[0.06, 0.92], [0.14, 0.5], [0.3, 0.2], [0.5, 0.06], [0.7, 0.2], [0.86, 0.5], [0.94, 0.92]], 10, "#ff9a2a");
  } },
  gear_smlib_body: { base: "#c8282e", areas: false, draw: (d) => {
    d.rect(0.0, 0.62, 1, 0.74, "#3a5ac8");
    for (const [x, y] of [[0.1, 0.25], [0.88, 0.25], [0.3, 0.5], [0.7, 0.5], [0.12, 0.85], [0.88, 0.85]]) d.fill([[x, y - 0.035], [x + 0.012, y - 0.01], [x + 0.035, y], [x + 0.012, y + 0.01], [x, y + 0.035], [x - 0.012, y + 0.01], [x - 0.035, y], [x - 0.012, y - 0.01]], "#ffd040", { line: 5, hatch: 5 });
    for (const x of [0.4, 0.6]) d.line([[x, 0.05], [x, 0.62]], 8, "#e8a830");
  } },
  gear_smlib_head: { base: "#c8282e", areas: false, draw: (d) => {
    d.fill([[0.1, 0.6], [0.9, 0.62], [0.9, 0.74], [0.1, 0.72]], "#e8b030");
    for (const [x, y] of [[0.4, 0.26], [0.55, 0.42], [0.3, 0.5]]) d.fill([[x, y - 0.035], [x + 0.012, y - 0.01], [x + 0.035, y], [x + 0.012, y + 0.01], [x, y + 0.035], [x - 0.012, y + 0.01], [x - 0.035, y], [x - 0.012, y - 0.01]], "#ffd040", { line: 5, hatch: 5 });
  } },
  gear_st_body: { base: "#2e5a3e", areas: false, draw: (d) => {
    for (const y of [0.25, 0.4, 0.55, 0.7, 0.85]) for (const x of [0.25, 0.4, 0.55, 0.7]) d.fill([[x, y], [x + 0.06, y + 0.04], [x, y + 0.08], [x - 0.06, y + 0.04]], "#c8d8d0", { line: 5, hatch: 5 });
    d.line([[0.42, 0.05], [0.5, 0.2], [0.58, 0.05]], 10, "#d8a830");
  } },
  gear_st_head: { base: "#6a8a3a", areas: false, draw: (d) => {
    d.fill([[0.55, 0.0], [0.62, 0.15], [0.55, 0.38], [0.48, 0.15]], "#3aff6a");
    for (const [x, y] of [[0.15, 0.4], [0.3, 0.25], [0.75, 0.25], [0.9, 0.4]]) d.fill([[x, y - 0.06], [x + 0.04, y], [x, y + 0.06], [x - 0.04, y]], "#7ad65a", { line: 6, hatch: 6 });
  } },
  gear_stocks_body: { base: "#4a4a40", areas: false, draw: (d) => {
    for (const [x, y] of [[0.2, 0.15], [0.8, 0.15], [0.35, 0.4], [0.65, 0.4], [0.3, 0.6], [0.7, 0.6]]) d.circle(x, y, 0.018, "#c8a060");
    d.rect(0.08, 0.74, 0.92, 0.82, "#7a4a2e"); d.rect(0.42, 0.72, 0.58, 0.84, "#c8a060");
    d.rect(0.2, 0.9, 0.8, 1, "#c8282e");
  } },
  gear_stocks_head: { base: "#2a2422", areas: false, draw: (d) => {
    d.fill([[0.3, 0.5], [0.72, 0.5], [0.52, 0.88]], "#c8282e");
  } },
  gear_stratl_body: { base: "#3a2a44", areas: false, draw: (d) => {
    for (const [x, y] of [[0.12, 0.3], [0.22, 0.24], [0.4, 0.32], [0.6, 0.32], [0.78, 0.24], [0.88, 0.3], [0.5, 0.5], [0.08, 0.6], [0.92, 0.6]]) d.fill([[x - 0.025, y + 0.04], [x, y - 0.08], [x + 0.025, y + 0.04]], "#e8c890", { line: 6, hatch: 6 });
    d.fill([[0.0, 0.0], [0.16, 0.0], [0.2, 0.2], [0.04, 0.24]], "#6a3a7a"); d.fill([[0.84, 0.0], [1, 0.0], [0.96, 0.24], [0.8, 0.2]], "#6a3a7a");
  } },
  gear_stratl_head: { base: "#f0e0b8", areas: false, draw: (d) => {
    d.line([[0.15, 0.5], [0.2, 0.7]], 8, "#c8b080"); d.line([[0.85, 0.5], [0.8, 0.7]], 8, "#c8b080");
  } },
  gear_stratu_body: { base: "#3a3e48", areas: false, draw: (d) => {
    d.line([[0.24, 0.1], [0.34, 0.3], [0.5, 0.36], [0.66, 0.3], [0.76, 0.1]], 12, "#5ab8ff");
    d.line([[0.5, 0.36], [0.5, 0.6]], 10, "#5ab8ff"); d.fill([[0.5, 0.6], [0.54, 0.7], [0.5, 0.8], [0.46, 0.7]], "#8ad8ff");
    for (const x of [0.1, 0.9]) d.line([[x, 0.1], [x, 0.45]], 10, "#5ab8ff");
  } },
  gear_stratu_head: { base: "#3a3e4a", areas: false, draw: (d) => {
    d.line([[0.06, 0.12], [0.2, 0.32], [0.4, 0.3]], 10, "#5ab8ff"); d.line([[0.6, 0.3], [0.8, 0.32], [0.94, 0.12]], 10, "#5ab8ff");
    d.fill([[0.5, 0.2], [0.55, 0.3], [0.5, 0.4], [0.45, 0.3]], "#8ad8ff");
  } },
  gear_thanes_body: { base: "#6a5a4a", areas: false, draw: (d) => {
    for (const x of [0.36, 0.64]) d.line([[x, 0.0], [x, 0.6]], 16, "#4a4040");
    d.rect(0.18, 0.62, 0.82, 0.7, "#5a3a26"); d.circle(0.5, 0.66, 0.05, "#9a9aa4");
    d.rect(0.2, 0.84, 0.8, 1, "#c88a3a");
  } },
  gear_thanes_head: { base: "#c8401e", areas: false, draw: (d) => {
    d.line([[0.24, 0.06], [0.5, 0.0], [0.76, 0.06]], 12, "#5a4a3a"); d.circle(0.34, 0.08, 0.04, "#c8282e"); d.circle(0.66, 0.08, 0.04, "#c8282e");
    for (const [x0, y0] of [[0.18, 0.5], [0.4, 0.66], [0.62, 0.66], [0.82, 0.5]]) d.rect(x0 - 0.05, y0, x0 + 0.05, y0 + 0.06, "#e8a830");
  } },
  gear_ubrs_body: { base: "#3a2a2a", areas: false, draw: (d) => {
    for (const [x0, y0] of [[0.3, 0.15], [0.55, 0.15], [0.35, 0.45], [0.55, 0.45], [0.2, 0.7], [0.65, 0.7]]) d.line([[x0, y0], [x0 + 0.1, y0 + 0.06], [x0 + 0.04, y0 + 0.12]], 8, "#ff6a2a");
    for (const [x, y] of [[0.06, 0.1], [0.94, 0.1], [0.02, 0.6], [0.98, 0.6]]) d.fill([[x - 0.03, y + 0.06], [x, y - 0.08], [x + 0.03, y + 0.06]], "#f0e0c0");
  } },
  gear_ubrs_head: { base: "#e8702e", areas: false, draw: (d) => {
    for (const x of [0.4, 0.62]) d.circle(x, 0.32, 0.035, "#ffd040");
    d.fill([[0.12, 0.3], [0.0, 0.2], [0.14, 0.12]], "#f0e0c0"); d.fill([[0.86, 0.12], [1, 0.2], [0.88, 0.3]], "#f0e0c0");
    for (let k = 0; k < 4; k++) { const x = 0.4 + k * 0.07; d.fill([[x - 0.02, 0.44], [x, 0.52], [x + 0.02, 0.44]], "#f0e6d0", { line: 5, hatch: 5 }); }
  } },
  gear_ulda_body: { base: "#a88a6a", areas: false, draw: (d) => {
    d.rect(0.46, 0.08, 0.54, 0.42, "#3ad8f0");
    for (const [x0, y0] of [[0.2, 0.25], [0.7, 0.25], [0.3, 0.55], [0.6, 0.55], [0.45, 0.8]]) d.rect(x0, y0, x0 + 0.1, y0 + 0.06, "#3ad8f0");
    for (const x of [0.06, 0.94]) d.rect(x - 0.04, 0.4, x + 0.04, 0.48, "#3ad8f0");
  } },
  gear_ulda_head: { base: "#8a7a6a", areas: false, draw: (d) => {
    d.rect(0.46, 0.06, 0.54, 0.34, "#3ad8f0"); d.rect(0.12, 0.32, 0.3, 0.42, "#3ad8f0"); d.rect(0.7, 0.32, 0.88, 0.42, "#3ad8f0");
    d.fill([[0.5, 0.44], [0.54, 0.5], [0.5, 0.56], [0.46, 0.5]], "#3ad8f0");
  } },
  gear_wc_body: { base: "#2aa8a8", areas: false, draw: (d) => {
    d.fill([[0.3, 0.12], [0.7, 0.12], [0.74, 1], [0.26, 1]], "#f0e0c0");
    for (const y of [0.28, 0.44, 0.6, 0.76]) d.fill([[0.48, y], [0.52, y], [0.53, y + 0.06], [0.47, y + 0.06]], "#d88a3a", { line: 5, hatch: 5 });
    d.fill([[0.0, 0.3], [0.1, 0.24], [0.08, 0.4]], "#ff7a2a"); d.fill([[0.9, 0.24], [1, 0.3], [0.92, 0.4]], "#ff7a2a");
  } },
  gear_wc_head: { base: "#2aa8a8", areas: false, draw: (d) => {
    for (const x of [0.22, 0.75]) { d.circle(x, 0.24, 0.08, "#ffffff"); d.circle(x + 0.01, 0.25, 0.035, "#2b1a10"); }
    for (let k = 0; k < 5; k++) { const x = 0.32 + k * 0.09; d.fill([[x - 0.025, 0.34], [x, 0.44], [x + 0.025, 0.34]], "#ffffff", { line: 5, hatch: 5 }); }
    d.fill([[0.0, 0.5], [0.12, 0.4], [0.1, 0.6]], "#ff7a2a"); d.fill([[0.9, 0.4], [1, 0.5], [0.9, 0.6]], "#ff7a2a");
    d.circle(0.52, 0.04, 0.05, "#ff7a2a");
  } },
  gear_zf_body: { base: "#b8282e", areas: false, draw: (d) => {
    for (const [x, y] of [[0.1, 0.08], [0.9, 0.08], [0.06, 0.4], [0.94, 0.4]]) d.fill([[x - 0.04, y + 0.06], [x, y - 0.08], [x + 0.04, y + 0.06]], "#f0e0c0");
    d.line([[0.12, 0.55], [0.5, 0.68], [0.88, 0.55]], 14, "#5a3a2a");
    for (const [x, y] of [[0.3, 0.2], [0.7, 0.2], [0.5, 0.4]]) d.circle(x, y, 0.02, "#9a9aa4");
  } },
  gear_zf_head: { base: "#d8282e", areas: false, draw: (d) => {
    for (const x of [0.38, 0.46, 0.54, 0.62]) d.fill([[x - 0.04, 0.4], [x, 0.0], [x + 0.04, 0.4]], "#ff5a3a", { line: 6, hatch: 8 });
    d.fill([[0.14, 0.62], [0.04, 0.08], [0.24, 0.5]], "#f0e0c0"); d.fill([[0.76, 0.5], [0.96, 0.08], [0.86, 0.62]], "#f0e0c0");
    d.fill([[0.5, 0.48], [0.54, 0.56], [0.5, 0.64], [0.46, 0.56]], "#9a9aa4");
  } },
  // --- Chase items (most read fine as plain crayon shapes; these needed their mark back) ---
  chase_brd_ironfoe: { base: "#7a7a8a", draw: (d) => { d.rect(0.3, 0.12, 0.7, 0.4, "#5a4a3a"); d.fill([[0.5, 0.14], [0.6, 0.26], [0.5, 0.38], [0.4, 0.26]], "#ffb030"); d.rect(0.42, 0.45, 0.58, 1, "#8a5a2e"); } },
  chase_dme_ring_of_demonic_potency: { base: "#4a3048", areas: false, draw: (d) => {
    for (const [x, y] of [[0.2, 0.3], [0.4, 0.15], [0.6, 0.12], [0.8, 0.28]]) d.fill([[x - 0.06, y + 0.1], [x - 0.02, y - 0.06], [x + 0.02, y + 0.02], [x + 0.06, y - 0.08], [x + 0.06, y + 0.1]], "#b06aff");
  } },
  chase_ruins_mirror_of_rathmael: { base: "#5a4a3a", areas: false, draw: (d) => {
    for (const [x0, y0] of [[0.25, 0.2], [0.45, 0.25], [0.65, 0.2], [0.3, 0.55], [0.55, 0.6]]) d.line([[x0, y0], [x0 + 0.05, y0 + 0.08], [x0 - 0.02, y0 + 0.16]], 10, "#8aff3a");
    d.line([[0.06, 0.5], [0.94, 0.5]], 10, "#8a8a9a");
  } },
  chase_gnomer_gigaflux_reactivator: { base: "#9a9aa8", draw: (d) => { for (const x of [0.3, 0.7]) d.circle(x, 0.65, 0.07, "#5a5a68"); d.rect(0.44, 0.0, 0.56, 0.2, "#c8b070"); } },
  chase_smcath_whitemanes_chapeau: { base: "#c8282e", draw: (d) => { d.rect(0.2, 0.42, 0.8, 0.54, "#e8b030"); d.circle(0.5, 0.48, 0.05, "#c8282e"); } },
  "chase_smcath_whitemanes_chapeau.nohair": { base: "#c8282e", draw: (d) => { d.rect(0.1, 0.62, 0.9, 0.76, "#e8b030"); d.circle(0.5, 0.69, 0.06, "#c8282e"); } },
  chase_stratl_book_of_the_dead: { base: "#5a2a6a", areas: false, draw: (d) => {
    d.circle(0.5, 0.5, 0.16, "#ff8a2a"); d.circle(0.44, 0.47, 0.035, "#2b1a10"); d.circle(0.56, 0.47, 0.035, "#2b1a10");
    d.line([[0.08, 0.1], [0.92, 0.1]], 10, "#e8b030");
  } },
  // --- Creature hats (the faces are the point: eyes, noses, teeth) ---
  crit_bat_head: { base: "#8a1e4a", draw: (d) => { tri(d, [0.08, 0.1], [0.22, 0.75], [0.32, 0.2], "#e86a9a"); tri(d, [0.68, 0.2], [0.78, 0.75], [0.92, 0.1], "#e86a9a"); eyes(d, [[0.42, 0.25], [0.58, 0.25]], 0.03); teeth(d, 0.4, 0.6, 0.36, 2, 0.12); } },
  crit_bear_head: { base: "#8a5232", draw: (d) => { d.circle(0.15, 0.2, 0.1, "#d8a878"); d.circle(0.85, 0.2, 0.1, "#d8a878"); d.circle(0.5, 0.42, 0.12, "#d8a878"); d.circle(0.5, 0.36, 0.04, INK); eyes(d, [[0.36, 0.3], [0.64, 0.3]]); } },
  crit_boar_head: { base: "#8a5a3a", draw: (d) => { d.circle(0.5, 0.36, 0.11, "#e89090"); d.circle(0.46, 0.36, 0.025, INK); d.circle(0.54, 0.36, 0.025, INK); eyes(d, [[0.36, 0.22], [0.64, 0.22]], 0.03); tri(d, [0.26, 0.44], [0.22, 0.6], [0.3, 0.46], BONE); tri(d, [0.7, 0.46], [0.78, 0.6], [0.74, 0.44], BONE); tri(d, [0.06, 0.08], [0.12, 0.34], [0.22, 0.14], "#e8a0a0"); tri(d, [0.78, 0.14], [0.88, 0.34], [0.94, 0.08], "#e8a0a0"); } },
  crit_carrion_bird_head: { base: "#8a3a22", draw: (d) => { d.circle(0.62, 0.22, 0.13, "#f0a0a8"); eyes(d, [[0.58, 0.18], [0.7, 0.18]], 0.03); tri(d, [0.62, 0.28], [0.86, 0.3], [0.7, 0.5], "#f0c040"); d.fill([[0.2, 0.42], [0.5, 0.36], [0.8, 0.5], [0.9, 0.7], [0.5, 0.56], [0.2, 0.62]], "#f8f0e8"); } },
  crit_cat_head: { base: "#e8862e", draw: (d) => { tri(d, [0.04, 0.06], [0.08, 0.34], [0.26, 0.2], "#f8a0b8"); tri(d, [0.74, 0.2], [0.92, 0.34], [0.96, 0.06], "#f8a0b8"); eyes(d, [[0.36, 0.34], [0.64, 0.34]]); tri(d, [0.46, 0.42], [0.54, 0.42], [0.5, 0.47], "#f86a8a"); for (const [x0, x1] of [[0.24, 0.42], [0.58, 0.76]]) { d.line([[x0, 0.46], [x1, 0.48]], 4, "#fff6e0"); d.line([[x0, 0.52], [x1, 0.5]], 4, "#fff6e0"); } } },
  crit_centaur_head: { base: "#8a5a3a", draw: (d) => { d.fill([[0.42, 0.2], [0.7, 0.18], [0.82, 0.3], [0.72, 0.44], [0.46, 0.4]], "#c8a070"); eyes(d, [[0.5, 0.24]], 0.03); d.circle(0.78, 0.3, 0.02, INK); tri(d, [0.4, 0.04], [0.46, 0.18], [0.5, 0.06], "#c8a070"); tri(d, [0.72, 0.04], [0.74, 0.18], [0.82, 0.08], "#c8a070"); for (const y of [0.4, 0.55, 0.7]) d.line([[0.04, y], [0.16, y + 0.08]], 8, "#e8c890"); } },
  crit_crab_head: { base: "#d8402e", draw: (d) => { googly(d, [[0.38, 0.12], [0.62, 0.12]], 0.07); } },
  crit_crocolisk_head: { base: "#5a8a3a", draw: (d) => { googly(d, [[0.32, 0.2], [0.68, 0.24]], 0.06); teeth(d, 0.12, 0.85, 0.5, 8, 0.1); for (const x of [0.4, 0.55, 0.7, 0.85]) tri(d, [x - 0.04, 0.12], [x, 0.0], [x + 0.04, 0.12], "#3a6a2a"); } },
  crit_demon_head: { base: "#c8282e", draw: (d) => { for (const x of [0.4, 0.6]) { d.circle(x, 0.3, 0.04, "#ffd030"); d.circle(x, 0.3, 0.015, INK); } d.fill([[0.36, 0.4], [0.64, 0.4], [0.58, 0.48], [0.42, 0.48]], "#f8f0d0"); d.line([[0.42, 0.24], [0.48, 0.27]], 5, INK); d.line([[0.58, 0.24], [0.52, 0.27]], 5, INK); } },
  crit_dragonkin_head: { base: "#d8402e", draw: (d) => { eyes(d, [[0.55, 0.22]], 0.035); d.circle(0.86, 0.26, 0.015, INK); tri(d, [0.36, 0.08], [0.4, -0.02], [0.44, 0.1], "#f0b030"); tri(d, [0.82, 0.06], [0.86, -0.02], [0.9, 0.1], "#f0b030"); } },
  crit_dwarf_head: { base: "#e86a1e", draw: (d) => { d.fill([[0.12, 0.2], [0.88, 0.2], [0.86, 0.06], [0.14, 0.06]], "#8a6a4a"); tri(d, [0.04, 0.08], [0.0, -0.02], [0.14, 0.1], BONE); tri(d, [0.86, 0.1], [1, -0.02], [0.96, 0.08], BONE); for (const y of [0.45, 0.65]) { d.rect(0.3, y, 0.42, y + 0.04, "#8a6a4a"); d.rect(0.58, y, 0.7, y + 0.04, "#8a6a4a"); } } },
  crit_elemental_head: { base: "#e8582e", draw: (d) => { for (const [x, h] of [[0.15, 0.22], [0.32, 0.3], [0.5, 0.36], [0.68, 0.3], [0.85, 0.22]]) d.fill([[x - 0.06, 0.34], [x, 0.34 - h], [x + 0.06, 0.34]], "#ffc030"); } },
  crit_furbolg_head: { base: "#8a5a32", draw: (d) => { d.circle(0.5, 0.42, 0.14, "#f0d8b0"); d.circle(0.5, 0.36, 0.05, INK); eyes(d, [[0.34, 0.28], [0.66, 0.28]]); d.line([[0.8, 0.1], [0.86, 0.3]], 8, "#f0e0c0"); } },
  crit_ghost_head: { base: "#f4ece0", draw: (d) => { d.circle(0.38, 0.2, 0.05, "#d8d0c8"); d.circle(0.62, 0.2, 0.05, "#d8d0c8"); } },
  crit_ghoul_head: { base: "#a8b07a", draw: (d) => { d.circle(0.32, 0.26, 0.07, "#f0e0c0"); d.line([[0.29, 0.23], [0.35, 0.29]], 5, INK); d.line([[0.35, 0.23], [0.29, 0.29]], 5, INK); d.circle(0.56, 0.28, 0.06, "#5a3a4a"); d.line([[0.24, 0.42], [0.6, 0.42]], 6, INK); for (const x of [0.3, 0.38, 0.46, 0.54]) d.line([[x, 0.39], [x, 0.45]], 4, INK); d.fill([[0.5, 0.42], [0.6, 0.42], [0.58, 0.6], [0.52, 0.58]], "#e8708a"); } },
  crit_gnoll_head: { base: "#d88a7a", draw: (d) => { d.circle(0.48, 0.42, 0.05, INK); eyes(d, [[0.34, 0.32], [0.6, 0.32]], 0.03); tri(d, [0.4, 0.06], [0.5, -0.02], [0.56, 0.08], "#c85a2e"); for (const [x, y] of [[0.12, 0.4], [0.82, 0.5], [0.7, 0.3]]) d.circle(x, y, 0.035, "#8a3a2a"); } },
  crit_gorilla_head: { base: "#3a3232", draw: (d) => { d.fill([[0.3, 0.12], [0.7, 0.12], [0.76, 0.36], [0.5, 0.46], [0.24, 0.36]], "#9a8a84"); eyes(d, [[0.4, 0.2], [0.6, 0.2]], 0.03); d.circle(0.46, 0.3, 0.02, INK); d.circle(0.54, 0.3, 0.02, INK); d.line([[0.4, 0.38], [0.6, 0.38]], 5, INK); d.circle(0.06, 0.3, 0.07, "#9a8a84"); d.circle(0.94, 0.3, 0.07, "#9a8a84"); } },
  crit_harpy_head: { base: "#c88ae8", draw: (d) => { googly(d, [[0.38, 0.28], [0.62, 0.28]], 0.065); tri(d, [0.46, 0.34], [0.54, 0.34], [0.5, 0.44], "#f0c030"); } },
  crit_human_head: { base: "#e8c070", draw: (d) => { d.fill([[0.3, 0.14], [0.76, 0.14], [0.78, 0.6], [0.5, 0.7], [0.28, 0.6]], "#f8dcc0"); eyes(d, [[0.42, 0.3], [0.62, 0.3]], 0.025); d.line([[0.44, 0.42], [0.52, 0.46], [0.6, 0.42]], 6, INK); d.circle(0.36, 0.42, 0.035, "#f0a0a0", { line: 0 }); d.circle(0.68, 0.42, 0.035, "#f0a0a0", { line: 0 }); } },
  crit_hyena_head: { base: "#c8a070", draw: (d) => { for (const [x, y] of [[0.2, 0.2], [0.8, 0.22], [0.3, 0.55], [0.72, 0.6], [0.15, 0.7], [0.85, 0.72], [0.5, 0.6]]) d.circle(x, y, 0.035, "#6a4a2e"); d.fill([[0.4, 0.32], [0.6, 0.32], [0.58, 0.5], [0.42, 0.5]], "#5a3a2a"); eyes(d, [[0.36, 0.24], [0.64, 0.24]], 0.03); d.circle(0.12, 0.2, 0.1, "#d8b088"); d.circle(0.88, 0.2, 0.1, "#d8b088"); } },
  crit_kobold_head: { base: "#c8a070", draw: (d) => { d.circle(0.15, 0.3, 0.12, "#e8908a"); d.circle(0.85, 0.36, 0.12, "#e8908a"); eyes(d, [[0.44, 0.38], [0.58, 0.38]], 0.025); d.circle(0.54, 0.5, 0.03, INK); d.rect(0.48, 0.0, 0.56, 0.16, "#f8f0d8"); tri(d, [0.48, 0.0], [0.52, -0.08], [0.56, 0.0], "#ffc030"); } },
  crit_kodo_head: { base: "#7a7a8a", draw: (d) => { d.fill([[0.36, 0.26], [0.66, 0.26], [0.7, 0.5], [0.32, 0.5]], "#9a9aa8"); eyes(d, [[0.4, 0.3], [0.62, 0.3]], 0.03); d.circle(0.45, 0.44, 0.02, INK); d.circle(0.57, 0.44, 0.02, INK); d.fill([[0.26, 0.2], [0.12, 0.06], [0.14, 0.4], [0.24, 0.42]], "#e8d0a0"); d.fill([[0.76, 0.2], [0.88, 0.06], [0.86, 0.4], [0.76, 0.42]], "#e8d0a0"); } },
  crit_murloc_head: { base: "#4a9a3a", draw: (d) => { googly(d, [[0.18, 0.3], [0.86, 0.3]], 0.09); d.fill([[0.36, 0.0], [0.42, 0.18], [0.5, 0.0], [0.56, 0.18], [0.64, 0.05], [0.66, 0.22], [0.36, 0.22]], "#e85a2e"); d.line([[0.2, 0.52], [0.5, 0.6], [0.82, 0.52]], 10, "#e85a2e"); teeth(d, 0.3, 0.7, 0.54, 5, 0.06); } },
  crit_naga_head: { base: "#2a8ab8", draw: (d) => { d.fill([[0.42, 0.24], [0.46, 0.0], [0.52, 0.18], [0.56, 0.02], [0.6, 0.24]], "#f0e8c0"); d.fill([[0.0, 0.3], [0.2, 0.5], [0.14, 0.8], [0.02, 0.6]], "#e8e0b8"); d.fill([[0.8, 0.5], [1, 0.3], [0.98, 0.6], [0.86, 0.8]], "#e8e0b8"); } },
  crit_orc_head: { base: "#5a8a3a", draw: (d) => { d.line([[0.3, 0.3], [0.44, 0.34]], 10, "#3a5a2a"); d.line([[0.56, 0.34], [0.7, 0.3]], 10, "#3a5a2a"); for (const x of [0.36, 0.64]) { d.circle(x, 0.4, 0.04, "#f8e8a0"); d.circle(x, 0.4, 0.015, INK); } tri(d, [0.3, 0.62], [0.32, 0.5], [0.36, 0.62], BONE); tri(d, [0.64, 0.62], [0.68, 0.5], [0.7, 0.62], BONE); d.line([[0.5, 0.0], [0.42, 0.08], [0.58, 0.08]], 10, INK); } },
  crit_quilboar_head: { base: "#a8622e", draw: (d) => { d.circle(0.52, 0.38, 0.1, "#f0a0a0"); d.circle(0.48, 0.38, 0.02, INK); d.circle(0.56, 0.38, 0.02, INK); eyes(d, [[0.38, 0.26], [0.64, 0.26]], 0.025); tri(d, [0.32, 0.42], [0.3, 0.56], [0.36, 0.44], BONE); tri(d, [0.68, 0.44], [0.74, 0.56], [0.72, 0.42], BONE); for (const x of [0.3, 0.4, 0.5, 0.6, 0.7]) tri(d, [x - 0.03, 0.14], [x, 0.0], [x + 0.03, 0.14], "#6a3a1e"); tri(d, [0.04, 0.14], [0.12, 0.4], [0.22, 0.2], "#f0a0a0"); tri(d, [0.78, 0.2], [0.88, 0.4], [0.96, 0.14], "#f0a0a0"); } },
  crit_raptor_head: { base: "#5a8a3a", draw: (d) => { d.circle(0.3, 0.42, 0.08, "#f0c030"); d.circle(0.3, 0.42, 0.03, INK); for (const [x0, y0] of [[0.1, 0.2], [0.5, 0.3], [0.7, 0.5]]) d.line([[x0, y0], [x0 + 0.15, y0 + 0.1]], 12, "#e8702e"); teeth(d, 0.32, 0.92, 0.76, 9, 0.1, "#f8f0e0"); } },
  crit_satyr_head: { base: "#5a2a6a" },
  crit_scorpid_head: { base: "#e8762e", draw: (d) => { eyes(d, [[0.4, 0.66], [0.6, 0.66]], 0.035); } },
  crit_skeleton_head: { base: "#2a2424", draw: (d) => { d.fill([[0.3, 0.1], [0.7, 0.1], [0.74, 0.4], [0.62, 0.56], [0.38, 0.56], [0.26, 0.4]], "#f0e6d0"); d.circle(0.4, 0.28, 0.06, INK); d.circle(0.6, 0.28, 0.06, INK); tri(d, [0.48, 0.38], [0.52, 0.38], [0.5, 0.33], INK); d.line([[0.36, 0.48], [0.64, 0.48]], 5, INK); for (const x of [0.42, 0.5, 0.58]) d.line([[x, 0.45], [x, 0.51]], 4, INK); } },
  crit_spider_head: { base: "#2a2426", draw: (d) => { for (const [x, y] of [[0.42, 0.18], [0.58, 0.18], [0.36, 0.3], [0.64, 0.3], [0.46, 0.3], [0.54, 0.3]]) d.circle(x, y, 0.03, "#d8282e"); tri(d, [0.4, 0.4], [0.42, 0.52], [0.45, 0.4], BONE); tri(d, [0.55, 0.4], [0.58, 0.52], [0.6, 0.4], BONE); } },
  crit_tallstrider_head: { base: "#e8b8a8", draw: (d) => { googly(d, [[0.22, 0.38], [0.8, 0.42]], 0.08); d.fill([[0.42, 0.36], [0.62, 0.36], [0.98, 0.7], [0.78, 0.78]], "#f0a070"); d.fill([[0.28, 0.06], [0.36, -0.02], [0.44, 0.06], [0.52, -0.04], [0.6, 0.08], [0.56, 0.18], [0.3, 0.18]], "#e85a5a"); } },
  crit_trogg_head: { base: "#6a7a8a", draw: (d) => { for (const x of [0.3, 0.72]) { d.circle(x, 0.42, 0.09, "#c8742e"); d.line([[x - 0.03, 0.39], [x + 0.03, 0.45]], 5, INK); d.line([[x + 0.03, 0.39], [x - 0.03, 0.45]], 5, INK); } tri(d, [0.06, 0.4], [0.06, 0.12], [0.16, 0.34], "#e8d0a0"); tri(d, [0.84, 0.34], [0.96, 0.18], [0.94, 0.42], "#e8d0a0"); d.circle(0.5, 0.06, 0.08, "#9a9aa4"); } },
  crit_troll_head: { base: "#2a5ac8", draw: (d) => { d.fill([[0.36, 0.3], [0.38, 0.0], [0.46, 0.06], [0.5, -0.02], [0.56, 0.08], [0.62, 0.0], [0.6, 0.36]], "#e82a2a"); tri(d, [0.26, 0.4], [0.28, 0.18], [0.32, 0.4], BONE); tri(d, [0.68, 0.4], [0.72, 0.18], [0.74, 0.4], BONE); } },
  crit_turtle_head: { base: "#3a8a3a", draw: (d) => { d.circle(0.5, 0.3, 0.2, "#b8d85a"); googly(d, [[0.43, 0.26], [0.6, 0.26]], 0.05); d.line([[0.42, 0.38], [0.5, 0.42], [0.58, 0.38]], 5, INK); for (const [x, y] of [[0.15, 0.35], [0.85, 0.35], [0.3, 0.6], [0.7, 0.6]]) d.circle(x, y, 0.06, "#6aaa3a"); } },
  crit_wolf_head: { base: "#7a7a84", draw: (d) => { tri(d, [0.06, 0.04], [0.14, 0.42], [0.3, 0.22], "#e8d8c0"); tri(d, [0.72, 0.22], [0.88, 0.42], [0.96, 0.04], "#e8d8c0"); d.circle(0.56, 0.48, 0.1, "#f0e0c8"); d.circle(0.56, 0.42, 0.05, INK); eyes(d, [[0.38, 0.34], [0.72, 0.34]], 0.03); tri(d, [0.48, 0.6], [0.5, 0.78], [0.53, 0.6], BONE); tri(d, [0.6, 0.6], [0.62, 0.78], [0.65, 0.6], BONE); } },
  crit_zombie_head: { base: "#9aa86a", draw: (d) => { d.circle(0.36, 0.42, 0.08, "#f0e0c0"); d.line([[0.33, 0.39], [0.39, 0.45]], 5, INK); d.line([[0.39, 0.39], [0.33, 0.45]], 5, INK); d.circle(0.62, 0.42, 0.07, "#3a2a2a"); d.circle(0.9, 0.9, 0.06, "#f0e6d0"); d.circle(0.9, 0.9, 0.025, INK); for (const x of [0.3, 0.42, 0.54]) d.line([[x, 0.0], [x + 0.04, 0.12]], 6, "#6a3a1e"); } },
  // --- Creature onesies ---
  crit_bat_body: { base: "#7a1a3e", areas: false, draw: (d) => { belly(d, "#c86a8a", 0.28, 0.72, 0.12, 0.95); buttons(d, 0.5, [0.25, 0.42, 0.58, 0.74], "#5a0a2a"); } },
  crit_bear_body: { base: "#9a4a26", areas: false, draw: (d) => { belly(d, "#e0b070", 0.3, 0.7, 0.12, 0.95); d.line([[0.5, 0.12], [0.5, 0.92]], 5, "#e8d8b0"); for (const x of [0.08, 0.92]) d.circle(x, 0.72, 0.04, "#e0b070"); } },
  crit_boar_body: { base: "#9a6a3a", areas: false, draw: (d) => { belly(d, "#e0b878", 0.28, 0.72, 0.2, 0.98); d.line([[0.5, 0.15], [0.5, 0.95]], 6, "#7a4a2a"); } },
  crit_carrion_bird_body: { base: "#6a2a1a", areas: false, draw: (d) => { d.fill([[0.18, 0.0], [0.82, 0.0], [0.7, 0.2], [0.5, 0.28], [0.3, 0.2]], "#f8f0e8"); for (const [x, y] of [[0.2, 0.4], [0.4, 0.5], [0.6, 0.45], [0.8, 0.42], [0.3, 0.7], [0.55, 0.75], [0.75, 0.68], [0.15, 0.85]]) d.circle(x, y, 0.022, "#f0a040"); } },
  crit_cat_body: { base: "#f08a1e", areas: false, draw: (d) => { belly(d, "#f8ecd8", 0.3, 0.7, 0.08, 0.98); for (const [x, y] of [[0.12, 0.2], [0.85, 0.2], [0.1, 0.45], [0.88, 0.45], [0.12, 0.7], [0.86, 0.7]]) d.line([[x - 0.08, y], [x + 0.08, y + 0.03]], 12, "#c85a1e"); } },
  crit_centaur_body: { base: "#8a4a22", areas: false, draw: (d) => { d.fill([[0.22, 0.04], [0.32, 0.0], [0.86, 0.66], [0.78, 0.72]], "#e8d8c0"); for (let k = 0; k < 5; k++) { const t = 0.15 + k * 0.15; d.fill([[0.26 + t * 0.56, 0.02 + t * 0.66], [0.3 + t * 0.56, -0.02 + t * 0.66], [0.32 + t * 0.56, 0.04 + t * 0.66]], "#c84a2e", { line: 4, hatch: 4 }); } buttons(d, 0.5, [0.28, 0.48, 0.68, 0.86], "#e8c890"); } },
  crit_crab_body: { base: "#e8402e", areas: false, draw: (d) => { for (const y of [0.32, 0.5, 0.68, 0.84]) d.line([[0.1, y], [0.5, y + 0.04], [0.9, y]], 8, "#8a2010"); d.fill([[0.04, 0.08], [0.08, -0.04], [0.16, 0.06], [0.1, 0.14]], "#e8402e"); d.fill([[0.84, 0.06], [0.92, -0.04], [0.96, 0.08], [0.9, 0.14]], "#e8402e"); } },
  crit_crocolisk_body: { base: "#5a8a3a", areas: false, draw: (d) => { belly(d, "#f0e8c8", 0.3, 0.7, 0.3, 0.98); for (const [x, y] of [[0.15, 0.2], [0.3, 0.12], [0.85, 0.2], [0.12, 0.55], [0.88, 0.55]]) d.rect(x - 0.04, y - 0.04, x + 0.04, y + 0.04, "#8ab85a"); buttons(d, 0.5, [0.35, 0.55, 0.75, 0.9], "#8a5a2e"); } },
  crit_demon_body: { base: "#a81a22", areas: false, draw: (d) => { belly(d, "#7a0a14", 0.25, 0.75, 0.3, 0.98); tri(d, [0.08, 0.08], [0.0, 0.0], [0.2, 0.04], "#6a0a10"); tri(d, [0.8, 0.04], [1, 0.0], [0.92, 0.08], "#6a0a10"); } },
  crit_dragonkin_body: { base: "#e8402e", areas: false, draw: (d) => { d.fill([[0.32, 0.12], [0.68, 0.12], [0.72, 0.98], [0.28, 0.98]], "#f8c840"); for (const y of [0.3, 0.45, 0.6, 0.75, 0.9]) d.line([[0.32, y], [0.68, y]], 6, "#e8962e"); tri(d, [0.12, 0.1], [0.2, -0.02], [0.28, 0.08], "#f8c840"); tri(d, [0.72, 0.08], [0.8, -0.02], [0.88, 0.1], "#f8c840"); } },
  crit_dwarf_body: { base: "#6a6a72", areas: false, draw: (d) => { for (const x of [0.3, 0.7]) d.rect(x - 0.06, 0.05, x + 0.06, 0.95, "#c86a2a"); d.rect(0.0, 0.7, 1, 0.8, "#5a3a26"); d.rect(0.44, 0.69, 0.56, 0.81, GOLD); d.circle(0.62, 0.3, 0.06, "#c86a2a"); } },
  crit_elemental_body: { base: "#e8462e", areas: false, draw: (d) => { for (const [x, y] of [[0.15, 0.25], [0.35, 0.15], [0.55, 0.3], [0.75, 0.2], [0.25, 0.55], [0.5, 0.65], [0.75, 0.55], [0.2, 0.85], [0.6, 0.88], [0.85, 0.8]]) d.fill([[x - 0.05, y + 0.06], [x - 0.02, y - 0.04], [x, y + 0.01], [x + 0.03, y - 0.07], [x + 0.05, y + 0.06]], "#ffc030"); } },
  crit_furbolg_body: { base: "#a8622e", areas: false, draw: (d) => { belly(d, "#f0d8b0", 0.3, 0.7, 0.12, 0.98); d.rect(0.56, 0.24, 0.66, 0.32, "#6a3a1e"); } },
  crit_ghost_body: { base: "#f4ece0", areas: false, draw: (d) => { for (const [x, y] of [[0.24, 0.24], [0.74, 0.24], [0.3, 0.72], [0.72, 0.74]]) { d.fill([[x - 0.04, y + 0.06], [x - 0.04, y - 0.02], [x, y - 0.06], [x + 0.04, y - 0.02], [x + 0.04, y + 0.06]], "#ffffff", { line: 6, hatch: 6 }); d.circle(x - 0.015, y - 0.01, 0.008, "#5a8ac8", { line: 0 }); d.circle(x + 0.015, y - 0.01, 0.008, "#5a8ac8", { line: 0 }); } } },
  crit_ghoul_body: { base: "#8a9a5a", areas: false, draw: (d) => { for (const [x0, y0, col] of [[0.05, 0.15, "#b84a3a"], [0.65, 0.1, "#c8b890"], [0.15, 0.55, "#c8b890"], [0.6, 0.6, "#b84a3a"], [0.35, 0.3, "#a8a070"]]) d.rect(x0, y0, x0 + 0.2, y0 + 0.2, col); buttons(d, 0.5, [0.25, 0.45, 0.65, 0.85]); } },
  crit_gnoll_body: { base: "#c8584a", areas: false, draw: (d) => { belly(d, "#f0d0a8", 0.3, 0.7, 0.25, 0.98); for (const [x0, y0] of [[0.05, 0.08], [0.72, 0.1], [0.08, 0.5], [0.78, 0.5]]) d.rect(x0, y0, x0 + 0.16, y0 + 0.16, "#a83a2e"); buttons(d, 0.5, [0.2, 0.4, 0.6, 0.8], "#8a4a2e"); } },
  crit_gorilla_body: { base: "#3a3030", areas: false, draw: (d) => { belly(d, "#b8a49a", 0.28, 0.72, 0.1, 0.95); d.line([[0.36, 0.3], [0.5, 0.36], [0.64, 0.3]], 5, "#8a7a74"); } },
  crit_harpy_body: { base: "#c87ae8", areas: false, draw: (d) => { for (const [x, y] of [[0.15, 0.2], [0.35, 0.3], [0.55, 0.2], [0.75, 0.32], [0.25, 0.55], [0.5, 0.6], [0.75, 0.6], [0.2, 0.85], [0.6, 0.85]]) d.fill([[x, y - 0.06], [x + 0.04, y], [x, y + 0.06], [x - 0.04, y]], "#f0b0f8", { line: 6, hatch: 6 }); } },
  crit_human_body: { base: "#3a5aa8", areas: false, draw: (d) => { for (const [x0, y0, col] of [[0.0, 0.1, "#c8402e"], [0.0, 0.45, "#e8d8b0"], [0.84, 0.1, "#e8d8b0"], [0.84, 0.45, "#c8402e"], [0.1, 0.8, "#e8d8b0"], [0.6, 0.8, "#c8402e"]]) d.rect(x0, y0, x0 + 0.16, y0 + 0.2, col); d.fill([[0.5, 0.22], [0.62, 0.3], [0.62, 0.48], [0.5, 0.58], [0.38, 0.48], [0.38, 0.3]], "#f0b830"); d.circle(0.48, 0.34, 0.012, INK); d.circle(0.53, 0.34, 0.012, INK); } },
  crit_hyena_body: { base: "#c8a070", areas: false, draw: (d) => { belly(d, "#f0d8b0", 0.3, 0.7, 0.12, 0.98); for (const [x, y] of [[0.1, 0.15], [0.2, 0.35], [0.08, 0.6], [0.82, 0.15], [0.9, 0.38], [0.84, 0.65], [0.15, 0.85], [0.86, 0.88]]) d.circle(x, y, 0.035, "#6a4a2e"); buttons(d, 0.5, [0.15, 0.32, 0.5, 0.68], "#c85a2e"); } },
  crit_kobold_body: { base: "#b8803e", areas: false, draw: (d) => { belly(d, "#e8c890", 0.28, 0.72, 0.3, 0.98); d.line([[0.62, 0.15], [0.72, 0.25]], 10, "#7a7a8a"); buttons(d, 0.5, [0.4, 0.55, 0.7, 0.85]); } },
  crit_kodo_body: { base: "#7a7a8a", areas: false, draw: (d) => { belly(d, "#d8b888", 0.32, 0.68, 0.25, 0.98); d.line([[0.24, 0.05], [0.76, 0.35]], 14, "#8a4a26"); d.line([[0.76, 0.05], [0.24, 0.35]], 14, "#8a4a26"); buttons(d, 0.5, [0.5, 0.68, 0.86], "#d8742e"); } },
  crit_murloc_body: { base: "#4a9a3a", areas: false, draw: (d) => { belly(d, "#f0dca8", 0.28, 0.72, 0.15, 0.98); buttons(d, 0.5, [0.25, 0.42, 0.58, 0.74, 0.9], "#e8c890"); d.fill([[0.94, 0.3], [1, 0.25], [1, 0.42]], "#f08a3a"); } },
  crit_naga_body: { base: "#2a9ac8", areas: false, draw: (d) => { belly(d, "#f8ecd0", 0.28, 0.72, 0.1, 0.98); } },
  crit_orc_body: { base: "#5a8a3a", areas: false, draw: (d) => { d.rect(0.46, 0.05, 0.54, 0.7, "#8a5a2e"); buttons(d, 0.5, [0.1, 0.25, 0.4, 0.55], "#e8c890"); d.rect(0.15, 0.72, 0.85, 0.82, "#6a4026"); d.rect(0.42, 0.7, 0.58, 0.84, GOLD); d.fill([[0.72, 0.1], [0.9, 0.12], [0.94, 0.4], [0.78, 0.38]], "#8a5a2e"); } },
  crit_quilboar_body: { base: "#c86a2e", areas: false, draw: (d) => { belly(d, "#f0d098", 0.28, 0.72, 0.15, 0.98); for (const x of [0.12, 0.88]) tri(d, [x - 0.04, 0.1], [x, -0.04], [x + 0.04, 0.1], "#f0e0b0"); } },
  crit_raptor_body: { base: "#5a8a4a", areas: false, draw: (d) => { belly(d, "#f0d8a0", 0.3, 0.7, 0.1, 0.98); for (const [x0, y0] of [[0.04, 0.2], [0.04, 0.45], [0.04, 0.7], [0.8, 0.2], [0.8, 0.45], [0.8, 0.7]]) d.line([[x0, y0], [x0 + 0.16, y0 + 0.06]], 14, "#f08a2e"); } },
  crit_satyr_body: { base: "#5a1a5a", areas: false, draw: (d) => { for (const [x0, y0] of [[0.2, 0.2], [0.6, 0.4], [0.3, 0.7]]) d.line([[x0, y0], [x0 + 0.1, y0 + 0.05]], 8, "#8a3a8a"); } },
  crit_scorpid_body: { base: "#f07a2e", areas: false, draw: (d) => { for (const y of [0.25, 0.42, 0.58, 0.74, 0.9]) d.line([[0.1, y], [0.5, y + 0.03], [0.9, y]], 8, "#a8461e"); } },
  crit_skeleton_body: { base: "#2a2424", areas: false, draw: (d) => {
    d.line([[0.5, 0.05], [0.5, 0.7]], 14, BONE);
    for (const y of [0.18, 0.28, 0.38, 0.48]) { d.line([[0.47, y], [0.3, y + 0.04], [0.26, y + 0.08]], 12, BONE); d.line([[0.53, y], [0.7, y + 0.04], [0.74, y + 0.08]], 12, BONE); }
    d.fill([[0.3, 0.72], [0.7, 0.72], [0.62, 0.86], [0.38, 0.86]], BONE);
    for (const x of [0.06, 0.94]) d.line([[x, 0.1], [x, 0.85]], 12, BONE);
  } },
  crit_spider_body: { base: "#2a2426", areas: false, draw: (d) => { d.fill([[0.42, 0.42], [0.58, 0.42], [0.5, 0.56]], "#e8202e"); d.fill([[0.5, 0.56], [0.58, 0.7], [0.42, 0.7]], "#e8202e"); } },
  crit_tallstrider_body: { base: "#f0d8c0", areas: false, draw: (d) => { for (const [x, y, col] of [[0.06, 0.2, "#e85a5a"], [0.12, 0.28, "#3ab8b0"], [0.08, 0.38, "#c87ae8"], [0.94, 0.2, "#e85a5a"], [0.88, 0.28, "#3ab8b0"], [0.92, 0.38, "#c87ae8"], [0.06, 0.55, "#3ab8b0"], [0.94, 0.55, "#e85a5a"]]) d.fill([[x, y - 0.05], [x + 0.04, y], [x, y + 0.05], [x - 0.04, y]], col, { line: 6, hatch: 6 }); buttons(d, 0.5, [0.2, 0.36, 0.52, 0.68], "#d8b898"); for (const x of [0.28, 0.72]) d.line([[x, 0.86], [x, 0.98]], 10, "#f0904a"); } },
  crit_trogg_body: { base: "#5a6a7a", areas: false, draw: (d) => { for (const [x, y] of [[0.12, 0.25], [0.2, 0.45], [0.1, 0.65], [0.85, 0.25], [0.9, 0.5], [0.82, 0.68]]) d.circle(x, y, 0.05, "#9a9a9a"); buttons(d, 0.5, [0.2, 0.42, 0.62, 0.82], "#d86a2e", 0.03); } },
  crit_troll_body: { base: "#1a4ac8", areas: false, draw: (d) => { belly(d, "#7aa8f0", 0.3, 0.7, 0.15, 0.75); d.fill([[0.1, 0.72], [0.9, 0.72], [0.88, 0.98], [0.12, 0.98]], "#5aaa3a"); for (const x of [0.3, 0.42, 0.58, 0.7]) d.fill([[x - 0.04, 0.12], [x, 0.04], [x + 0.04, 0.12], [x, 0.16]], BONE, { line: 5, hatch: 5 }); } },
  crit_turtle_body: { base: "#2a6a2a", areas: false, draw: (d) => { belly(d, "#c8d85a", 0.25, 0.75, 0.05, 0.98); for (const y of [0.3, 0.5, 0.7]) d.line([[0.28, y], [0.72, y]], 6, "#a8b83a"); } },
  crit_wolf_body: { base: "#7a7a84", areas: false, draw: (d) => { belly(d, "#f0e0c8", 0.28, 0.72, 0.1, 0.98); for (const x of [0.04, 0.96]) d.circle(x, 0.94, 0.05, "#f0e0c8"); } },
  crit_zombie_body: { base: "#b8b07a", areas: false, draw: (d) => { for (const [x0, y0] of [[0.02, 0.4], [0.7, 0.6], [0.2, 0.75], [0.8, 0.3], [0.3, 0.1]]) d.rect(x0, y0, x0 + 0.16, y0 + 0.14, "#8a2a2a"); d.circle(0.68, 0.24, 0.07, "#f0a0b8"); buttons(d, 0.5, [0.2, 0.4, 0.6, 0.8], "#e8d0a0"); } },
  // --- Rare hunters ---
  hunt_tracker_head: { base: "#e0c88a", areas: false, draw: (d) => {
    d.fill([[0.12, 0.32], [0.88, 0.3], [0.88, 0.42], [0.12, 0.44]], "#8a5a2e");
    d.circle(0.5, 0.04, 0.03, "#c8b070");
  } },
  hunt_tracker_body: { base: "#c8a868", areas: false, draw: (d) => {
    d.fill([[0.27, 0.1], [0.36, 0.07], [0.8, 0.72], [0.71, 0.75]], "#6a4026");
    for (let k = 0; k < 6; k++) { const t = 0.15 + k * 0.1; d.line([[0.3 + t * 0.5, 0.1 + t * 0.62], [0.34 + t * 0.5, 0.08 + t * 0.62]], 8, GOLD); }
    d.rect(0.2, 0.46, 0.4, 0.6, "#b0905a"); d.rect(0.6, 0.46, 0.8, 0.6, "#b0905a");
    for (const y of [0.3, 0.45, 0.6, 0.75]) d.circle(0.5, y, 0.018, "#6a4026");
  } },
  // --- The ogre tribes (Posters.lua; tools/gen-art-bounty.json), read off each painting on a tenths grid ---
  fac_mogrosh_head: { base: "#8a8c90", areas: false, draw: (d) => {
    d.fill([[0.4, 0.08], [0.2, 0.2], [0.06, 0.45], [0.0, 0.88], [0.1, 0.9], [0.24, 0.56], [0.42, 0.34]], "#e0d4bc", { hatch: 8 });
    d.line([[0.36, 0.38], [0.6, 0.32], [0.84, 0.34], [0.98, 0.44]], 30, "#6a4a30");
    for (const [x, y] of [[0.46, 0.36], [0.62, 0.33], [0.78, 0.33], [0.92, 0.4]]) d.circle(x, y, 0.02, GREY);
    d.line([[0.6, 0.06], [0.6, 0.2]], 13, INK); d.line([[0.54, 0.13], [0.66, 0.13]], 13, INK); } },
  fac_splinterfist_head: { base: "#a86a38", areas: false, draw: (d) => {
    for (const x of [0.12, 0.24, 0.66, 0.88]) d.line([[x, 0.12], [x, 0.44]], 10, INK);
    d.rect(0.45, 0.1, 0.56, 0.46, "#5a4a3c");
    d.line([[0.0, 0.47], [0.5, 0.43], [1.0, 0.41]], 35, "#4a3a30");
    d.rect(0.38, 0.03, 0.6, 0.12, "#6a5a4a"); tri(d, [0.41, 0.04], [0.49, -0.04], [0.57, 0.04], "#f0a020");
    d.circle(0.76, 0.3, 0.07, "#4a2a1a"); } },
  fac_boulderfist_head: { base: "#a8a8a0", areas: false, draw: (d) => {
    d.fill([[0.0, 0.62], [0.12, 0.3], [0.25, 0.32], [0.15, 0.96], [0.02, 0.96]], "#7a4a2a");
    d.fill([[0.84, 0.34], [0.95, 0.3], [1.0, 0.96], [0.9, 0.96]], "#7a4a2a");
    d.line([[0.6, 0.0], [0.6, 0.62]], 35, "#7a4a2a");
    for (const [a, b] of [[[0.3, 0.56], [0.42, 0.1]], [[0.48, 0.58], [0.56, 0.1]], [[0.72, 0.55], [0.82, 0.14]], [[0.03, 0.85], [0.1, 0.45]]]) d.line([a, b], 30, "#f0d020"); } },
  fac_crushridge_head: { base: "#7a7c82", areas: false, draw: (d) => {
    d.fill([[0.1, 0.55], [0.5, 0.47], [0.9, 0.55], [0.88, 0.96], [0.7, 0.8], [0.5, 0.75], [0.3, 0.8], [0.12, 0.96]], "#c8b8a0");
    d.fill([[0.24, 0.5], [0.04, 0.36], [0.0, 0.0], [0.1, 0.02], [0.16, 0.26], [0.3, 0.36]], "#f0dca8", { hatch: 8 });
    d.fill([[0.76, 0.5], [0.96, 0.36], [1.0, 0.0], [0.9, 0.02], [0.84, 0.26], [0.7, 0.36]], "#f0dca8", { hatch: 8 });
    d.line([[0.25, 0.36], [0.75, 0.36]], 20, "#5a5c62");
    for (const x of [0.4, 0.5, 0.6]) d.line([[x - 0.03, 0.28], [x, 0.2], [x + 0.03, 0.28]], 10, INK); } },
  fac_dustbelcher_head: { base: "#efe2c8", areas: false, draw: (d) => {
    for (const [a, b] of [[[0.28, 0.26], [0.44, 0.2]], [[0.5, 0.14], [0.6, 0.26]], [[0.66, 0.22], [0.76, 0.36]], [[0.2, 0.4], [0.3, 0.32]]]) d.line([a, b], 20, "#c0502e");
    tri(d, [0.1, 0.0], [0.08, 0.26], [0.2, 0.3], "#c0502e"); tri(d, [0.55, 0.03], [0.5, 0.16], [0.6, 0.13], "#c0502e");
    tri(d, [0.0, 0.56], [0.1, 0.45], [0.12, 0.62], "#c0502e");
    d.circle(0.42, 0.5, 0.08, INK); d.circle(0.88, 0.55, 0.05, INK);
    teeth(d, 0.3, 0.85, 0.7, 5, 0.18); } },
  fac_moshogg_head: { base: "#a8683a", areas: false, draw: (d) => {
    for (const x of [0.25, 0.3, 0.7, 0.75]) { d.line([[x, 0.45], [x, 0.92]], 10, "#6a4026"); d.circle(x, 0.94, 0.025, BONE); }
    d.fill([[0.0, 0.3], [0.34, 0.26], [0.3, 0.46], [0.02, 0.44]], "#d8302a", { hatch: 8 }); d.fill([[1.0, 0.3], [0.66, 0.26], [0.7, 0.46], [0.98, 0.44]], "#d8302a", { hatch: 8 });
    d.fill([[0.14, 0.28], [0.26, 0.04], [0.38, 0.1], [0.36, 0.32]], "#1f9a9a", { hatch: 8 }); d.fill([[0.86, 0.28], [0.74, 0.04], [0.62, 0.1], [0.64, 0.32]], "#1f9a9a", { hatch: 8 });
    d.fill([[0.06, 0.5], [0.3, 0.46], [0.22, 0.7]], "#f0e6d0", { hatch: 8 }); d.fill([[0.94, 0.5], [0.7, 0.46], [0.78, 0.7]], "#f0e6d0", { hatch: 8 });
    tri(d, [0.42, 0.16], [0.5, 0.0], [0.58, 0.16], "#c8302a");
    d.line([[0.38, 0.3], [0.62, 0.3]], 20, "#1f8a8a");
    d.line([[0.38, 0.4], [0.46, 0.42]], 15, INK); d.line([[0.54, 0.42], [0.62, 0.4]], 15, INK);
    teeth(d, 0.42, 0.58, 0.58, 4, 0.06); } },
  fac_gordunni_head: { base: "#c8822e", areas: false, draw: (d) => {
    d.fill([[0.0, 0.66], [0.1, 0.3], [0.25, 0.05], [0.5, 0.0], [0.75, 0.05], [0.66, 0.3], [0.42, 0.36], [0.2, 0.5]], "#2a5ab8");
    d.rect(0.45, 0.28, 0.7, 0.42, "#d89a40");
    d.line([[0.3, 0.62], [0.48, 0.6]], 20, "#4a8ad8"); d.line([[0.7, 0.6], [0.86, 0.56]], 20, "#4a8ad8");
    d.circle(0.57, 0.56, 0.03, "#8a5020"); } },
  fac_dunemaul_head: { base: "#e6c890", areas: false, draw: (d) => {
    for (const pts of [[[0.3, 0.16], [0.6, 0.06], [0.9, 0.1]], [[0.25, 0.3], [0.6, 0.2], [1.0, 0.25]], [[0.3, 0.46], [0.65, 0.4], [0.95, 0.45]], [[0.1, 0.8], [0.3, 0.6]]]) d.line(pts, 15, "#c8a060"); } },
  fac_dreadmaul_head: { base: "#4a4448", areas: false, draw: (d) => {
    d.fill([[0.49, 0.3], [0.57, 0.3], [0.53, 0.58]], "#7ee03a", { hatch: 8 });
    d.line([[0.2, 0.4], [0.12, 0.66]], 20, "#7ee03a"); d.line([[0.8, 0.4], [0.85, 0.68]], 20, "#7ee03a"); } },
  fac_firegut_head: { base: "#8a4a2a", areas: false, draw: (d) => {
    d.fill([[0.18, 0.4], [0.15, 0.15], [0.25, 0.0], [0.4, 0.1], [0.5, 0.0], [0.65, 0.08], [0.78, 0.0], [0.85, 0.2], [0.82, 0.4]], "#f08a20", { hatch: 8 });
    d.fill([[0.3, 0.4], [0.35, 0.18], [0.5, 0.1], [0.62, 0.2], [0.7, 0.4]], "#f8d040", { hatch: 8 });
    d.line([[0.3, 0.66], [0.35, 0.5], [0.41, 0.66], [0.47, 0.5], [0.53, 0.66], [0.6, 0.5], [0.66, 0.66], [0.72, 0.5]], 23, "#e05a20"); } },
  fac_gordok_head: { base: "#e8b83a", areas: false, draw: (d) => {
    d.circle(0.48, 0.38, 0.09, "#d02a3a"); d.circle(0.73, 0.72, 0.07, "#2a9a3a"); d.circle(0.05, 0.42, 0.05, "#3a5ab8"); } },
  fac_spirestone_head: { base: "#5a4440", areas: false, draw: (d) => {
    for (const pts of [[[0.55, 0.36], [0.62, 0.25], [0.72, 0.3]], [[0.8, 0.12], [0.85, 0.36]], [[0.3, 0.5], [0.38, 0.4]], [[0.64, 0.42], [0.75, 0.46], [0.84, 0.4]], [[0.12, 0.8], [0.2, 0.7]]]) d.line(pts, 20, "#f05a20"); } },
  fac_deadwind_head: { base: "#9aa0b0", areas: false, draw: (d) => {
    d.line([[0.15, 0.86], [0.2, 0.6], [0.35, 0.2], [0.5, 0.1]], 30, "#40d8f0"); d.line([[0.65, 0.15], [0.85, 0.5], [0.9, 0.9]], 30, "#40d8f0");
    d.line([[0.4, 0.05], [0.55, 0.12]], 18, "#40e070"); } },
  fac_urok_head: { base: "#3a3638", areas: false, draw: (d) => {
    tri(d, [0.12, 0.0], [0.18, 0.14], [0.26, 0.08], "#8a6a5a"); tri(d, [0.88, 0.0], [0.82, 0.14], [0.74, 0.08], "#8a6a5a");
    for (const x of [0.36, 0.62]) d.circle(x, 0.25, 0.025, "#f0a020");
    d.circle(0.55, 0.34, 0.04, INK); teeth(d, 0.36, 0.72, 0.42, 4, 0.1); } },
  fac_crimson_head: { base: "#f4f0e8", areas: false, draw: (d) => {
    d.line([[0.0, 0.86], [0.15, 0.62], [0.5, 0.6], [0.85, 0.62], [1.0, 0.86]], 30, "#d02a2a");
    d.line([[0.05, 0.32], [0.25, 0.26]], 20, "#d02a2a"); d.line([[0.75, 0.26], [0.95, 0.32]], 20, "#d02a2a");
    d.fill([[0.5, 0.08], [0.44, 0.26], [0.5, 0.56], [0.56, 0.26]], "#c8202a", { hatch: 8 }); } },
  fac_darkiron_head: { base: "#5a4038", areas: false, draw: (d) => {
    d.line([[0.05, 0.56], [0.5, 0.46], [0.95, 0.56]], 35, "#7a5040");
    for (const [x, y] of [[0.12, 0.56], [0.24, 0.5], [0.4, 0.48], [0.58, 0.48], [0.75, 0.5], [0.88, 0.56]]) d.circle(x, y, 0.03, "#f0a040");
    for (const [x, y] of [[0.3, 0.2], [0.5, 0.12], [0.7, 0.2]]) d.circle(x, y, 0.025, "#c07030"); } },
  fac_mogrosh_body: { base: "#a89a88", areas: false, draw: (d) => {
    d.rect(0.0, 0.69, 0.86, 0.79, "#6a4026");
    for (const [x, y] of [[0.55, 0.26], [0.63, 0.4], [0.72, 0.3]]) tri(d, [x - 0.03, y - 0.06], [x + 0.03, y - 0.06], [x, y + 0.06], BONE);
    d.rect(0.25, 0.72, 0.33, 0.88, "#7a4a2a"); d.line([[0.2, 0.6], [0.3, 0.96]], 23, "#5a3a20"); } },
  fac_splinterfist_body: { base: "#8a4a2a", areas: false, draw: (d) => {
    d.line([[0.12, 0.2], [0.13, 0.6]], 23, GREY); d.line([[0.82, 0.2], [0.85, 0.6]], 23, GREY);
    d.circle(0.45, 0.3, 0.05, GREY); d.rect(0.05, 0.66, 1.0, 0.78, "#6a3a20"); d.rect(0.42, 0.65, 0.52, 0.79, GREY);
    d.circle(0.83, 0.8, 0.06, "#5a3a20"); } },
  fac_boulderfist_body: { base: "#8a3a1a", areas: false, draw: (d) => {
    d.line([[0.55, 0.1], [0.55, 0.9]], 10, INK);
    for (const [x, y] of [[0.28, 0.3], [0.85, 0.3], [0.42, 0.6], [0.12, 0.6], [0.86, 0.62]]) {
      d.circle(x, y, 0.065, "#f0c020", { line: 0, hatch: 6 });
      for (const k of [-1.5, -0.5, 0.5, 1.5]) d.line([[x + k * 0.03, y - 0.04], [x + k * 0.04, y - 0.13]], 14, "#f0c020");
      d.line([[x + 0.05, y + 0.01], [x + 0.1, y - 0.04]], 14, "#f0c020");
    }
    for (const x of [0.2, 0.38, 0.6, 0.78]) d.circle(x, 0.86, 0.05, GREY); } },
  fac_crushridge_body: { base: "#8a6a4a", areas: false, draw: (d) => {
    d.fill([[0.0, 0.1], [0.3, 0.0], [0.35, 0.3], [0.05, 0.42]], "#ece0c8", { hatch: 8 }); d.fill([[1.0, 0.1], [0.7, 0.0], [0.65, 0.3], [0.95, 0.42]], "#ece0c8", { hatch: 8 });
    d.fill([[0.35, 0.36], [0.6, 0.3], [0.62, 0.56], [0.38, 0.6]], "#ece0c8", { hatch: 8 });
    d.rect(0.22, 0.72, 0.78, 0.8, "#4a3020"); d.circle(0.55, 0.3, 0.04, GREY); } },
  fac_dustbelcher_body: { base: "#c8a870", areas: false, draw: (d) => {
    d.fill([[0.55, 0.1], [0.85, 0.05], [0.85, 0.35], [0.6, 0.4]], "#b8482e", { hatch: 8 });
    d.fill([[0.0, 0.45], [0.12, 0.42], [0.14, 0.76], [0.0, 0.78]], "#b8482e"); d.fill([[1.0, 0.45], [0.88, 0.42], [0.86, 0.76], [1.0, 0.78]], "#b8482e");
    for (const [x, y] of [[0.36, 0.22], [0.44, 0.32], [0.3, 0.4]]) tri(d, [x - 0.03, y], [x + 0.03, y], [x, y + 0.08], BONE);
    d.rect(0.15, 0.68, 0.85, 0.76, "#6a3a20"); tri(d, [0.46, 0.7], [0.54, 0.7], [0.5, 0.84], BONE); } },
  fac_moshogg_body: { base: "#3a8a3a", areas: false, draw: (d) => {
    d.fill([[0.0, 0.25], [0.42, 0.35], [0.42, 0.46], [0.0, 0.38]], "#7a3aa8"); d.fill([[0.58, 0.4], [1.0, 0.3], [1.0, 0.42], [0.58, 0.52]], "#7a3aa8");
    for (const x of [0.3, 0.5, 0.7]) tri(d, [x - 0.07, 0.66], [x, 0.54], [x + 0.07, 0.66], "#2aa8a8");
    d.line([[0.3, 0.0], [0.5, 0.15], [0.7, 0.0]], 20, BONE); d.circle(0.5, 0.15, 0.045, "#c87a3a");
    teeth(d, 0.15, 0.85, 0.84, 7, 0.08); } },
  fac_gordunni_body: { base: "#2a5ab8", areas: false, draw: (d) => {
    d.line([[0.1, 0.05], [0.6, 0.6]], 40, "#1a3a8a");
    for (const t of [0.1, 0.4, 0.75]) { const x = 0.1 + 0.5 * t, y = 0.05 + 0.55 * t; d.rect(x - 0.05, y - 0.04, x + 0.05, y + 0.04, "#e8e0d0"); d.circle(x + 0.06, y, 0.02, "#d8a040"); }
    d.line([[0.0, 0.66], [1.0, 0.66]], 25, "#d8a040");
    d.rect(0.02, 0.6, 0.18, 0.7, "#e8e0d0"); d.rect(0.84, 0.55, 1.0, 0.65, "#e8e0d0"); } },
  fac_dunemaul_body: { base: "#e8c090", areas: false, draw: (d) => {
    for (const pts of [[[0.2, 0.1], [0.5, 0.45]], [[0.8, 0.1], [0.5, 0.45]], [[0.3, 0.3], [0.35, 0.96]], [[0.7, 0.3], [0.65, 0.96]]]) d.line(pts, 15, "#c89a68");
    d.rect(0.05, 0.57, 0.95, 0.65, "#7a4a2a"); d.circle(0.3, 0.76, 0.08, "#8a5a30"); } },
  fac_dreadmaul_body: { base: "#4a3a36", areas: false, draw: (d) => {
    d.rect(0.2, 0.86, 0.8, 0.96, "#8a2a20"); d.line([[0.3, 0.2], [0.45, 0.45]], 23, GREY);
    d.fill([[0.5, 0.24], [0.57, 0.32], [0.53, 0.46], [0.47, 0.32]], "#7ee03a", { hatch: 6 });
    for (const pts of [[[0.15, 0.14], [0.18, 0.3]], [[0.85, 0.14], [0.88, 0.3]], [[0.12, 0.6], [0.1, 0.72]], [[0.92, 0.6], [0.94, 0.72]], [[0.62, 0.55], [0.65, 0.7]]]) d.line(pts, 25, "#7ee03a"); } },
  fac_firegut_body: { base: "#7a3a1e", areas: false, draw: (d) => {
    d.line([[0.12, 0.0], [0.15, 0.18]], 35, "#5a3a20"); d.line([[0.85, 0.0], [0.82, 0.18]], 35, "#5a3a20");
    d.line([[0.15, 0.26], [0.22, 0.18], [0.29, 0.26], [0.36, 0.18], [0.43, 0.26], [0.5, 0.18], [0.57, 0.26], [0.64, 0.18], [0.71, 0.26], [0.78, 0.18], [0.85, 0.26]], 25, "#f07020");
    d.rect(0.0, 0.6, 1.0, 0.68, "#5a3020"); d.circle(0.2, 0.62, 0.07, "#f05a20"); d.circle(0.88, 0.68, 0.07, "#8a4a2a"); } },
  fac_gordok_body: { base: "#3a3e48", areas: false, draw: (d) => {
    for (const pts of [[[0.05, 0.1], [0.3, 0.2], [0.5, 0.25], [0.7, 0.2], [0.95, 0.1]], [[0.25, 0.4], [0.5, 0.5], [0.75, 0.4]], [[0.5, 0.25], [0.5, 0.68]]]) d.line(pts, 30, "#e8b83a");
    d.rect(0.18, 0.68, 0.85, 0.8, "#6a2aa0"); d.fill([[0.7, 0.76], [0.8, 0.76], [0.82, 0.98], [0.72, 0.98]], "#6a2aa0"); } },
  fac_spirestone_body: { base: "#6a3028", areas: false, draw: (d) => {
    d.line([[0.15, 0.05], [0.2, 0.4]], 23, GREY); d.line([[0.85, 0.05], [0.8, 0.4]], 23, GREY);
    for (const pts of [[[0.3, 0.3], [0.4, 0.4], [0.35, 0.5]], [[0.6, 0.3], [0.7, 0.42], [0.65, 0.55]], [[0.45, 0.55], [0.55, 0.65], [0.5, 0.8]], [[0.1, 0.5], [0.15, 0.65]], [[0.9, 0.5], [0.85, 0.65]], [[0.3, 0.75], [0.4, 0.85]]]) d.line(pts, 23, "#f8601e"); } },
  fac_deadwind_body: { base: "#7a8aa8", areas: false, draw: (d) => {
    for (const pts of [[[0.05, 0.3], [0.15, 0.42]], [[0.3, 0.6], [0.38, 0.72]], [[0.9, 0.35], [0.85, 0.5]], [[0.55, 0.2], [0.6, 0.3]]]) d.line(pts, 28, "#40d8f0");
    d.line([[0.08, 0.1], [0.2, 0.16]], 20, "#40e070"); d.rect(0.62, 0.75, 0.72, 0.92, "#3ab8e8"); } },
  fac_urok_body: { base: "#3a3430", areas: false, draw: (d) => {
    d.fill([[0.0, 0.0], [0.35, 0.05], [0.35, 0.2], [0.05, 0.26]], "#6a5848", { hatch: 8 }); d.fill([[1.0, 0.0], [0.65, 0.05], [0.65, 0.2], [0.95, 0.26]], "#6a5848", { hatch: 8 });
    d.line([[0.45, 0.0], [0.5, 0.35]], 23, GREY);
    d.line([[0.25, 0.45], [0.75, 0.45]], 23, "#6a5a50"); d.line([[0.25, 0.6], [0.75, 0.6]], 23, "#6a5a50"); d.rect(0.2, 0.82, 0.8, 0.9, "#2a2420"); } },
  fac_crimson_body: { base: "#f4f0e8", areas: false, draw: (d) => {
    d.fill([[0.0, 0.15], [0.16, 0.1], [0.2, 0.95], [0.0, 0.95]], GREY); d.fill([[1.0, 0.15], [0.84, 0.1], [0.8, 0.95], [1.0, 0.95]], GREY);
    d.rect(0.25, 0.1, 0.3, 0.95, "#d02a2a"); d.rect(0.7, 0.1, 0.75, 0.95, "#d02a2a");
    d.line([[0.35, 0.02], [0.5, 0.1], [0.65, 0.02]], 25, "#d02a2a");
    d.fill([[0.5, 0.28], [0.44, 0.42], [0.5, 0.62], [0.56, 0.42]], "#c8202a", { hatch: 6 });
    d.rect(0.25, 0.78, 0.75, 0.84, "#7a4a2a"); d.rect(0.4, 0.85, 0.45, 1.0, "#d02a2a"); d.rect(0.55, 0.85, 0.6, 1.0, "#d02a2a"); } },
  fac_darkiron_body: { base: "#4a3a34", areas: false, draw: (d) => {
    d.fill([[0.0, 0.15], [0.18, 0.1], [0.2, 0.9], [0.0, 0.9]], "#7a7a7a"); d.fill([[1.0, 0.15], [0.82, 0.1], [0.8, 0.9], [1.0, 0.9]], "#7a7a7a");
    d.rect(0.2, 0.2, 0.8, 0.98, "#6a3a2a");
    d.fill([[0.38, 0.6], [0.62, 0.6], [0.58, 0.66], [0.53, 0.66], [0.55, 0.78], [0.45, 0.78], [0.47, 0.66], [0.42, 0.66]], "#f07a20", { hatch: 6 });
    tri(d, [0.43, 0.58], [0.5, 0.42], [0.57, 0.58], "#f8c040"); } },
  // --- Rexxar and Nathanos (the rares feat's sets, repainted 2026-10-23; Rexxar keeps one pauldron, as fitted) ---
  hunt_master_head: { base: "#3a2620", areas: false, draw: (d) => {
    tri(d, [0.33, 0.0], [0.27, 0.3], [0.41, 0.22], "#b0582a"); tri(d, [0.7, 0.0], [0.6, 0.22], [0.73, 0.3], "#b0582a");
    d.fill([[0.3, 0.25], [0.4, 0.18], [0.6, 0.18], [0.7, 0.25], [0.72, 0.45], [0.62, 0.62], [0.38, 0.62], [0.28, 0.45]], "#b0582a");
    d.line([[0.5, 0.15], [0.5, 0.45]], 22, GREY); d.line([[0.3, 0.33], [0.7, 0.33]], 18, GREY); } },
  hunt_master_body: { base: "#7a4a2a", areas: false, draw: (d) => {
    d.fill([[0.0, 0.32], [0.3, 0.32], [0.25, 0.46], [0.0, 0.44]], "#4a3020", { hatch: 8 });
    d.fill([[0.0, 0.06], [0.32, 0.0], [0.38, 0.28], [0.05, 0.36]], "#5a4a44");
    for (const [x, y] of [[0.08, 0.04], [0.2, 0.0], [0.32, 0.04]]) tri(d, [x - 0.04, y + 0.06], [x, y - 0.06], [x + 0.04, y + 0.06], "#d8c8a8");
    d.circle(0.5, 0.38, 0.05, GREY);
    d.rect(0.1, 0.72, 0.9, 0.82, "#5a3420"); d.circle(0.5, 0.77, 0.05, GREY);
    d.rect(0.0, 0.56, 0.15, 0.95, "#6a5a50"); d.rect(0.82, 0.56, 1.0, 0.95, "#6a5a50"); } },
  hunt_stalker_head: { base: "#4a4e44", areas: false, draw: (d) => {
    d.line([[0.3, 0.84], [0.25, 0.4], [0.35, 0.12], [0.5, 0.05], [0.65, 0.12], [0.75, 0.4], [0.68, 0.84]], 16, "#e8dcc4");
    d.fill([[0.55, 0.84], [0.6, 0.9], [0.55, 0.97], [0.5, 0.9]], "#8a4a5a"); } },
  hunt_stalker_body: { base: "#6a5a48", areas: false, draw: (d) => {
    d.fill([[0.0, 0.45], [0.15, 0.42], [0.15, 0.7], [0.0, 0.7]], "#7a8a7a"); d.fill([[1.0, 0.45], [0.85, 0.42], [0.85, 0.7], [1.0, 0.7]], "#7a8a7a");
    d.fill([[0.0, 0.15], [0.25, 0.1], [0.28, 0.3], [0.05, 0.45]], "#4a6a3a");
    d.fill([[0.68, 0.1], [0.95, 0.15], [0.98, 0.4], [0.72, 0.35]], "#4a3a34");
    d.fill([[0.3, 0.25], [0.7, 0.25], [0.72, 0.6], [0.5, 0.68], [0.28, 0.6]], "#d0ccc4");
    d.line([[0.3, 0.45], [0.7, 0.45]], 14, "#8a8680"); d.rect(0.25, 0.68, 0.75, 0.75, "#5a3a20");
    d.rect(0.12, 0.0, 0.22, 0.15, "#5a3a20"); } },
  fac_scourge_head: { base: "#6a2a8a", areas: false, draw: (d) => {
    d.circle(0.3, 0.25, 0.06, BONE); d.circle(0.28, 0.24, 0.015, INK, { line: 0 }); d.circle(0.32, 0.24, 0.015, INK, { line: 0 }); } },
  fac_scourge_body: { base: "#6a2a8a", areas: false, draw: (d) => {
    d.rect(0.32, 0.06, 0.68, 0.96, "#3a2a3a");
    d.circle(0.5, 0.4, 0.08, BONE); d.rect(0.45, 0.46, 0.55, 0.62, BONE);
    d.circle(0.47, 0.39, 0.018, INK, { line: 0 }); d.circle(0.53, 0.39, 0.018, INK, { line: 0 }); } },
  fac_bloodsail_body: { base: "#3a2a26", areas: false, draw: (d) => {
    d.fill([[0.3, 0.0], [0.7, 0.0], [0.72, 1.0], [0.28, 1.0]], "#f0e6d0");
    for (const y of [0.3, 0.45, 0.6, 0.75, 0.9]) d.rect(0.3, y, 0.71, y + 0.06, "#c8302a");
    d.line([[0.25, 0.1], [0.75, 0.55]], 30, "#a82a2a"); d.rect(0.5, 0.28, 0.6, 0.38, GOLD);
    for (const x of [0.27, 0.73]) for (const y of [0.3, 0.45, 0.6]) d.circle(x, y, 0.02, GOLD);
    d.rect(0.0, 0.75, 0.12, 0.88, "#a82a2a"); d.rect(0.88, 0.75, 1.0, 0.88, "#a82a2a"); } },
};

function draw(id) {
  const img = decodePng(path.join(GEN, "painted", id + ".png"));
  const small = resample(img, 0, 0, img.width, img.height, L, L);
  const px = [], idx = [];
  for (let i = 0; i < L * L; i++) if (small[i * 4 + 3] > 110) { px.push([small[i * 4], small[i * 4 + 1], small[i * 4 + 2]]); idx.push(i); }
  const c = canvas(), r = rng(9000 + id.length * 7919);
  if (px.length < 30) return crayon.toRgba(c);
  const k = Math.min(3, Math.max(2, Math.round(px.length / 3000)));
  const centres = kmeans(px, k, r);
  let labels = new Int8Array(L * L).fill(-1);
  idx.forEach((i, n) => { const p = px[n]; let b = 0, bd = 1e9; centres.forEach((q, j) => { const d = (p[0] - q[0]) ** 2 + (p[1] - q[1]) ** 2 + (p[2] - q[2]) ** 2; if (d < bd) { bd = d; b = j; } }); labels[i] = b; });
  labels = smooth(labels, k, 3, 4);
  const scale = S / L;
  const toCanvas = (poly) => poly.map(([x, y]) => [x * scale + scale / 2, y * scale + scale / 2]);
  // (the whole piece first: its outline round everything, in its commonest colour; then each colour's areas on it)
  const recipe = RECIPES[id] || {};
  const counts = centres.map((_, j) => labels.filter((l) => l === j).length), main = counts.indexOf(Math.max(...counts));
  // (crayon-bright: more colourful, and never so dark the outlines vanish)
  const colour = (j) => { const c0 = centres[j], grey = (c0[0] + c0[1] + c0[2]) / 3, lift = Math.max(0, 70 - grey) * 0.9;
    return c0.map((v) => Math.max(0, Math.min(255, grey + (v - grey) * 1.35 + 10 + lift))); };
  const whole = Uint8Array.from(labels, (l) => (l >= 0 ? 1 : 0));
  // (the fill: hatched over the whole box, then cut to the shape itself - a traced outline can miss a thin part, the
  // shape can't; the outline is drawn over it)
  const base = canvas();
  crayonShape(base, [[0, 0], [S, 0], [S, S], [0, S]], recipe.base ? hex(recipe.base) : colour(main), r, { fit: true, hatch: 22, outline: null });
  const fillRgba = Buffer.from(crayon.toRgba(base));
  const edge = Buffer.from(resample({ width: L, height: L, rgba: Buffer.from(Array.from(whole, (m) => [0, 0, 0, m ? 255 : 0]).flat()) }, 0, 0, L, L, S, S));
  for (let i = 0; i < S * S; i++) fillRgba[i * 4 + 3] = Math.min(fillRgba[i * 4 + 3], edge[i * 4 + 3] > 127 ? 255 : 0);
  const line = canvas();  // (the outline on its own, over everything: the areas and details are cut to the shape, holes too)
  for (const poly of outlines(whole, 40)) stroke(line, [...toCanvas(poly), toCanvas(poly)[0]], 20, OUTLINE, 0.95, r);
  // (and round its holes: a hood's face opening)
  const holes = Uint8Array.from(whole, (m, i) => { if (m) return 0; const x = i % L, y = (i / L) | 0; return x > 0 && y > 0 && x < L - 1 && y < L - 1 ? 1 : 0; });
  { const outside = new Uint8Array(L * L), st = []; for (let i = 0; i < L * L; i++) { const x = i % L, y = (i / L) | 0; if (!whole[i] && (x === 0 || y === 0 || x === L - 1 || y === L - 1)) { outside[i] = 1; st.push(i); } }
    while (st.length) { const p = st.pop(), x = p % L, y = (p / L) | 0; for (const q of [x > 0 ? p - 1 : -1, x < L - 1 ? p + 1 : -1, y > 0 ? p - L : -1, y < L - 1 ? p + L : -1]) if (q >= 0 && !whole[q] && !outside[q]) { outside[q] = 1; st.push(q); } }
    for (let i = 0; i < L * L; i++) holes[i] = !whole[i] && !outside[i] ? 1 : 0; }
  for (const poly of outlines(holes, 30)) stroke(line, [...toCanvas(poly), toCanvas(poly)[0]], 14, OUTLINE, 0.95, r);
  centres.forEach((_, j) => {
    if (j === main || recipe.areas === false) return;
    const m = Uint8Array.from(labels, (l) => (l === j ? 1 : 0));
    // (only big, simple areas: a tabard's panel, a sash; texture blotches are left to the details)
    for (const poly of outlines(m, Math.max(220, idx.length * 0.03))) if (compact(poly) > 0.3) crayonShape(c, toCanvas(poly), colour(j), r, { fit: true, hatch: 18, line: 12 });
  });
  // (details, in the piece's box)
  const xs = idx.map((i) => i % L), ys = idx.map((i) => (i / L) | 0);
  const box = [Math.min(...xs) * scale, Math.min(...ys) * scale, (Math.max(...xs) - Math.min(...xs) + 1) * scale, (Math.max(...ys) - Math.min(...ys) + 1) * scale];
  if (recipe.draw) {
    const u = (x) => box[0] + x * box[2], v = (y) => box[1] + y * box[3], pt = ([x, y]) => [u(x), v(y)];
    const fill = (poly, col, o = {}) => crayonShape(c, poly.map(pt), hex(col), r, { fit: true, hatch: 12, line: 10, ...o });
    recipe.draw({ fill, line: (pts, w, col) => stroke(c, pts.map(pt), w, typeof col === "string" ? hex(col) : col, 0.95, r),
      rect: (x0, y0, x1, y1, col, o) => fill([[x0, y0], [x1, y0], [x1, y1], [x0, y1]], col, o),
      circle: (x, y, rad, col, o) => crayonShape(c, crayon.circle(u(x), v(y), rad * box[2], 24), hex(col), r, { fit: true, hatch: 10, line: 8, ...o }) }, r);
  }
  const top = Buffer.from(crayon.toRgba(c)), out = fillRgba;  // (the areas and details over the fill, cut to the shape; then the outline)
  for (let i = 0; i < S * S; i++) if (edge[i * 4 + 3] <= 127) top[i * 4 + 3] = 0;
  const lines = crayon.toRgba(line);
  for (const layer of [top, lines]) for (let i = 0; i < out.length; i += 4) {
    const a = layer[i + 3] / 255, bb = out[i + 3] / 255, o = a + bb * (1 - a);
    if (!o) continue;
    for (let k = 0; k < 3; k++) out[i + k] = Math.round((layer[i + k] * a + out[i + k] * bb * (1 - a)) / o);
    out[i + 3] = Math.round(o * 255);
  }
  return out;
}

// The painting's holes stay holes (a mask's eye holes, where the picture's eyes show through): see-through areas of
// the painting enclosed by it, too small for the traced outline to keep, cut out of the crayon piece again.
function keepHoles(id, rgba) {
  const p = decodePng(path.join(GEN, "painted", id + ".png")).rgba;
  const clear = (i) => p[i * 4 + 3] < 24, outside = new Uint8Array(S * S), st = [];
  for (let x = 0; x < S; x++) st.push(x, (S - 1) * S + x);
  for (let y = 0; y < S; y++) st.push(y * S, y * S + S - 1);
  while (st.length) {
    const i = st.pop();
    if (outside[i] || !clear(i)) continue;
    outside[i] = 1;
    const x = i % S, y = (i / S) | 0;
    if (x > 0) st.push(i - 1); if (x < S - 1) st.push(i + 1); if (y > 0) st.push(i - S); if (y < S - 1) st.push(i + S);
  }
  for (let i = 0; i < S * S; i++) if (clear(i) && !outside[i]) rgba[i * 4 + 3] = 0;
}

const all = fs.readdirSync(path.join(GEN, "painted")).filter((f) => /^(gear|chase|crit|fac|hunt)_.*\.png$/.test(f) && !/_suit\.png$/.test(f))
  .map((f) => f.slice(0, -4)).filter((id) => id.includes(filter));
fs.mkdirSync(path.join(GEN, "crayon"), { recursive: true });
const shown = [];
all.forEach((id, n) => {
  const out = path.join(GEN, "crayon", id + ".png");
  if (fs.existsSync(out) && !force) return;
  const rgba = draw(id);
  keepHoles(id, rgba);
  writePng(out, S, S, rgba);
  shown.push(id);
  process.stdout.write(`\r${n + 1}/${all.length} ${id}`.padEnd(70));
});
console.log();
// The review: each painting above its crayon version, cropped round the piece.
if (shown.length) {
  const T = 220, cols = Math.min(8, shown.length), rows = Math.ceil(shown.length / cols), sheet = Buffer.alloc(T * cols * T * 2 * rows * 4);
  shown.forEach((id, n) => {
    const p = decodePng(path.join(GEN, "painted", id + ".png"));
    let x0 = S, y0 = S, x1 = 0, y1 = 0;
    for (let i = 0; i < S * S; i++) if (p.rgba[i * 4 + 3] > 40) { const x = i % S, y = (i / S) | 0; x0 = Math.min(x0, x); y0 = Math.min(y0, y); x1 = Math.max(x1, x); y1 = Math.max(y1, y); }
    const side = Math.max(x1 - x0, y1 - y0) + 40, cx = (x0 + x1) / 2, cy = (y0 + y1) / 2;
    [p, decodePng(path.join(GEN, "crayon", id + ".png"))].forEach((img, row) => {
      const s = resample(img, Math.max(0, cx - side / 2), Math.max(0, cy - side / 2), Math.min(side, S), Math.min(side, S), T, T);
      const ox = (n % cols) * T, oy = (Math.floor(n / cols) * 2 + row) * T;
      for (let y = 0; y < T; y++) for (let x = 0; x < T; x++) { const i = (y * T + x) * 4, o = ((oy + y) * T * cols + ox + x) * 4, a = s[i + 3] / 255;
        sheet[o] = Math.round(s[i] * a + 226 * (1 - a)); sheet[o + 1] = Math.round(s[i + 1] * a + 216 * (1 - a)); sheet[o + 2] = Math.round(s[i + 2] * a + 196 * (1 - a)); sheet[o + 3] = 255; }
    });
  });
  try { writePng(path.join(GEN, "crayon-pieces.png"), T * cols, T * 2 * rows, sheet); } catch (e) { console.log("(crayon-pieces.png is open: not updated)"); }
}
console.log(`Drew ${shown.length} crayon pieces into ${path.join(GEN, "crayon")}`);
