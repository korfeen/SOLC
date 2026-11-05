// Crayon twins of the arcade's painted props (tools/gen-arcade-props.js), drawn by code with exactly the crayon pieces'
// recipe (tools/make-crayon-pieces.js: the painting simplified to a few big flat colour areas, hatched, a bold dark
// outline) - crayon is never Codex. User: the props drawn like the crayon ogres on the field.
//   node tools/make-crayon-props.js [filter] [--force]
// In:  %USERPROFILE%\killtracker-art-extra\Arcade\props\<name>.png
// Out: ...\Arcade\props\crayon\<name>.png (same size as the painting) and crayon-review.png (painting above crayon).
// Details on top, per prop: PROP_RECIPES below (as make-crayon-pieces' RECIPES: base colour, areas, draw in its box 0..1).
const fs = require("fs");
const os = require("os");
const path = require("path");
const { decodePng, resample } = require("./convert-art");
const { writePng } = require("./make-role-icons");
const pieces = require("./make-crayon-pieces");

const DIR = path.join(os.homedir(), "killtracker-art-extra", "Arcade", "props");
const OUT = path.join(DIR, "crayon"), WORK = path.join(DIR, "work", "_square");
const S = pieces.S, BOX = 1100;  // (the prop fitted into the pieces' 1254 canvas, at most this big)
const args = process.argv.slice(2), force = args.includes("--force"), filter = args.find((a) => !a.startsWith("--")) || "";

// Details per prop (ids: <sheet>_<n>); greys for stone, so the moss doesn't win the base colour.
const STONE = "#9aa0aa", WOOD = "#8a5a32";
const MOSS = "#7aa23e", DARK = "#5c6270", INK = "#2b1a10";
const moss = (d, pts) => { for (const [x, y, r] of pts) d.circle(x, y, r, MOSS, { hatch: 6, line: 5 }); };
const crack = (d, pts) => d.line(pts, 7, INK);
const PROP_RECIPES = {
  // round-topped, leaning: a quatrefoil at the top, the inner arch, moss at its feet
  smgy_graves_a_1: { base: STONE, areas: false, draw: (d) => {
    d.line([[0.22, 0.95], [0.22, 0.3], [0.5, 0.12], [0.78, 0.3], [0.78, 0.95]], 6, DARK);
    for (const [x, y] of [[0.5, 0.2], [0.42, 0.27], [0.58, 0.27], [0.5, 0.34]]) d.circle(x, y, 0.06, DARK, { hatch: 5, line: 5 });
    crack(d, [[0.6, 0.55], [0.68, 0.65], [0.62, 0.78]]);
    moss(d, [[0.12, 0.92, 0.09], [0.86, 0.9, 0.08], [0.45, 0.06, 0.07]]); } },
  // celtic cross: the ring round the crossing
  smgy_graves_a_2: { base: STONE, areas: false, draw: (d) => {
    d.line(Array.from({ length: 25 }, (_, i) => [0.5 + 0.27 * Math.cos(i / 24 * 6.283), 0.27 + 0.13 * Math.sin(i / 24 * 6.283)]), 9, DARK);
    d.rect(0.3, 0.8, 0.7, 0.86, DARK, { hatch: 5, line: 5 });
    moss(d, [[0.2, 0.92, 0.1], [0.75, 0.95, 0.07], [0.55, 0.05, 0.05]]); } },
  // square-shouldered: the carved sun, a melted candle on top, its side columns
  smgy_graves_a_3: { base: STONE, areas: false, draw: (d) => {
    d.line([[0.16, 0.95], [0.16, 0.28]], 6, DARK); d.line([[0.84, 0.95], [0.84, 0.28]], 6, DARK);
    for (let i = 0; i < 12; i++) { const a = i / 12 * 6.283; d.line([[0.5 + 0.1 * Math.cos(a), 0.42 + 0.07 * Math.sin(a)], [0.5 + 0.2 * Math.cos(a), 0.42 + 0.14 * Math.sin(a)]], 6, "#c9a24a"); }
    d.circle(0.5, 0.42, 0.1, "#e8c45a", { hatch: 6, line: 6 });
    d.rect(0.46, 0.0, 0.56, 0.12, "#f2ead8", { hatch: 5, line: 5 }); d.circle(0.51, -0.02, 0.03, "#ffcf3a", { hatch: 4, line: 4 });
    moss(d, [[0.1, 0.18, 0.08], [0.9, 0.18, 0.08], [0.15, 0.93, 0.08]]); } },
  // broken: cracks and moss
  smgy_graves_a_4: { base: STONE, areas: false, draw: (d) => {
    crack(d, [[0.3, 0.1], [0.4, 0.3], [0.32, 0.5]]); crack(d, [[0.7, 0.4], [0.62, 0.6], [0.72, 0.75]]);
    moss(d, [[0.6, 0.12, 0.1], [0.2, 0.9, 0.09], [0.82, 0.92, 0.08]]); } },
  // gothic: the pointed inner arch, its columns
  smgy_graves_b_1: { base: STONE, areas: false, draw: (d) => {
    d.line([[0.28, 0.85], [0.28, 0.35], [0.5, 0.12], [0.72, 0.35], [0.72, 0.85]], 7, DARK);
    d.line([[0.12, 0.88], [0.12, 0.35]], 6, DARK); d.line([[0.88, 0.88], [0.88, 0.35]], 6, DARK);
    d.rect(0.05, 0.88, 0.95, 0.97, DARK, { hatch: 5, line: 5 });
    moss(d, [[0.5, 0.06, 0.05], [0.2, 0.93, 0.07]]); } },
  // wooden cross: the rope tied round the crossing, red rags hanging
  smgy_graves_b_2: { base: WOOD, areas: false, draw: (d) => {
    d.line([[0.25, 0.2], [0.35, 0.3]], 6, "#5a3a1a"); d.line([[0.65, 0.12], [0.7, 0.35]], 6, "#5a3a1a");
    d.fill([[0.3, 0.27], [0.4, 0.27], [0.38, 0.62], [0.33, 0.55]], "#b8302a", { hatch: 6, line: 6 });
    d.fill([[0.62, 0.27], [0.72, 0.27], [0.7, 0.7], [0.64, 0.6]], "#b8302a", { hatch: 6, line: 6 });
    d.line([[0.42, 0.2], [0.58, 0.36]], 8, "#d8c08a"); d.line([[0.58, 0.2], [0.42, 0.36]], 8, "#d8c08a"); } },
  // the angel: head, folded wings either side, the robe, the pedestal
  smgy_graves_b_3: { base: STONE, areas: false, draw: (d) => {
    d.fill([[0.12, 0.12], [0.35, 0.18], [0.38, 0.6], [0.2, 0.62], [0.08, 0.35]], "#c3c7cf", { hatch: 6, line: 7 });
    d.fill([[0.88, 0.12], [0.65, 0.18], [0.62, 0.6], [0.8, 0.62], [0.92, 0.35]], "#c3c7cf", { hatch: 6, line: 7 });
    d.fill([[0.38, 0.22], [0.62, 0.22], [0.68, 0.78], [0.32, 0.78]], "#b0b5bf", { hatch: 6, line: 7 });
    d.circle(0.5, 0.12, 0.09, "#c9ccd4", { hatch: 5, line: 6 });
    d.rect(0.15, 0.78, 0.85, 0.98, DARK, { hatch: 6, line: 6 });
    moss(d, [[0.22, 0.85, 0.07], [0.8, 0.92, 0.06]]); } },
  // the sunken one with a skull
  smgy_graves_b_4: { base: STONE, areas: false, draw: (d) => {
    d.line([[0.2, 0.95], [0.2, 0.3], [0.5, 0.12], [0.8, 0.3], [0.8, 0.95]], 6, DARK);
    d.circle(0.55, 0.3, 0.13, "#f0e6d0", { hatch: 5, line: 6 });
    d.circle(0.5, 0.29, 0.035, INK, { line: 0 }); d.circle(0.6, 0.29, 0.035, INK, { line: 0 });
    d.rect(0.5, 0.4, 0.6, 0.45, "#f0e6d0", { hatch: 4, line: 4 });
    crack(d, [[0.3, 0.55], [0.38, 0.7], [0.32, 0.85]]);
    moss(d, [[0.25, 0.15, 0.08], [0.85, 0.9, 0.08]]); } },
  // cypresses: a dark green flame on a short trunk, a few scallops of foliage
  ...Object.fromEntries([1, 2, 3].map((n) => [`smgy_trees_${n}`, { base: "#3f6e3c", areas: false, draw: (d) => {
    d.rect(0.42, 0.88, 0.58, 1.0, WOOD, { hatch: 5, line: 6 });
    for (const y of [0.25, 0.42, 0.58, 0.74]) d.line([[0.3 + (0.62 - y) * 0.15, y], [0.5, y + 0.05], [0.7 - (0.62 - y) * 0.15, y]], 7, "#2c4f2a");
    for (const [x, y] of [[0.62, 0.35], [0.66, 0.55], [0.64, 0.72]]) d.circle(x, y, 0.06, "#6f9a3e", { hatch: 5, line: 0 }); } }])),
  // the big tree by the tomb: the gnarled trunk, branches, lighter leaf clumps
  smgy_trees_4: { base: "#4a7a40", areas: false, draw: (d) => {
    d.fill([[0.42, 1.0], [0.47, 0.6], [0.4, 0.42], [0.47, 0.44], [0.52, 0.55], [0.6, 0.4], [0.64, 0.43], [0.57, 0.62], [0.62, 1.0]], WOOD, { hatch: 6, line: 8 });
    for (const [x, y, r] of [[0.25, 0.3, 0.1], [0.5, 0.15, 0.11], [0.75, 0.28, 0.1], [0.35, 0.5, 0.08], [0.82, 0.5, 0.08]]) d.circle(x, y, r, "#6f9a3e", { hatch: 6, line: 0 }); } },
  // the Library: candelabra (gold, five candles), lectern (the open book), the knight's portrait, the Scarlet armour
  smlib_hall_1: { base: "#d8a838", areas: false, draw: (d) => {
    for (const [x, y] of [[0.1, 0.22], [0.29, 0.14], [0.5, 0.08], [0.71, 0.14], [0.9, 0.22]]) { d.rect(x - 0.06, y, x + 0.06, y + 0.12, "#f2ead8", { hatch: 4, line: 5 }); d.circle(x, y - 0.03, 0.04, "#ffcf3a", { hatch: 3, line: 4 }); } } },
  smlib_hall_2: { base: "#8a5a32", areas: false, draw: (d) => {
    d.fill([[0.06, 0.04], [0.94, 0.04], [0.92, 0.42], [0.08, 0.42]], "#f2e2c0", { hatch: 6, line: 7 });
    d.line([[0.5, 0.05], [0.5, 0.42]], 6, "#8a5a32"); d.rect(0.52, 0.05, 0.6, 0.6, "#c0302a", { hatch: 4, line: 5 });
    d.line([[0.3, 0.12], [0.3, 0.32]], 5, "#c9a24a"); d.line([[0.22, 0.2], [0.38, 0.2]], 5, "#c9a24a");
    d.line([[0.5, 0.6], [0.5, 0.82]], 6, "#d8a838"); } },
  smlib_hall_3: { base: "#8a5a32", areas: false, draw: (d) => {
    d.rect(0.04, 0.14, 0.96, 0.67, "#d8a838", { hatch: 5, line: 7 });
    d.rect(0.12, 0.2, 0.88, 0.62, "#e8d2b0", { hatch: 6, line: 5 });
    d.fill([[0.35, 0.36], [0.65, 0.36], [0.68, 0.62], [0.32, 0.62]], "#c0302a", { hatch: 5, line: 6 });
    d.circle(0.5, 0.3, 0.08, "#b7c1cc", { hatch: 4, line: 6 }); d.line([[0.43, 0.3], [0.57, 0.3]], 5, INK);
    d.line([[0.5, 0.42], [0.5, 0.56]], 6, "#f2ead8"); d.line([[0.44, 0.47], [0.56, 0.47]], 6, "#f2ead8"); } },
  smlib_hall_4: { base: "#b7c1cc", areas: false, draw: (d) => {
    d.fill([[0.36, 0.22], [0.64, 0.22], [0.62, 0.8], [0.5, 0.88], [0.38, 0.8]], "#c0302a", { hatch: 6, line: 7 });
    d.line([[0.5, 0.35], [0.5, 0.55]], 7, "#e8c45a"); d.line([[0.43, 0.42], [0.57, 0.42]], 7, "#e8c45a");
    d.line([[0.42, 0.09], [0.58, 0.09]], 6, INK); d.rect(0.3, 0.52, 0.7, 0.57, "#8a5a32", { hatch: 4, line: 5 });
    d.rect(0.2, 0.93, 0.8, 1.0, "#8a5a32", { hatch: 4, line: 5 }); } },
  // bookcases: rows of coloured spines; the book pile; Loksey's kennel
  smlib_shelves_1: { base: "#8a5a32", areas: false, draw: (d, r) => {
    for (const [y0, y1] of [[0.2, 0.37], [0.42, 0.59], [0.65, 0.84]]) { d.rect(0.12, y0, 0.88, y1, "#3e2614", { hatch: 5, line: 4 });
      for (let x = 0.14; x < 0.85; x += 0.05) d.rect(x, y0 + 0.02, x + 0.04, y1, ["#b8302a", "#2d5f9c", "#3e7a35", "#7a3a8a", "#c08a2a"][Math.floor(r() * 5)], { hatch: 3, line: 3 }); } } },
  smlib_shelves_2: { base: "#8a5a32", areas: false, draw: (d, r) => {
    d.rect(0.12, 0.5, 0.88, 0.88, "#3e2614", { hatch: 5, line: 4 });
    for (let x = 0.14; x < 0.85; x += 0.06) d.rect(x, 0.53, x + 0.05, 0.88, ["#b8302a", "#2d5f9c", "#3e7a35", "#c08a2a"][Math.floor(r() * 4)], { hatch: 3, line: 3 });
    d.rect(0.05, 0.05, 0.4, 0.2, "#2d5f9c", { hatch: 4, line: 4 }); d.rect(0.38, 0.1, 0.62, 0.2, "#efe2c0", { hatch: 4, line: 4 });
    d.rect(0.83, 0.0, 0.89, 0.15, "#f2ead8", { hatch: 3, line: 4 }); d.circle(0.86, -0.03, 0.025, "#ffcf3a", { hatch: 3, line: 3 }); } },
  smlib_shelves_3: { base: "#9a3a2a", areas: false, draw: (d) => {
    for (const [y, col] of [[0.38, "#c08a2a"], [0.48, "#3e7a35"], [0.58, "#b8302a"], [0.7, "#2d5f9c"], [0.84, "#7a3a8a"]]) d.rect(0.05, y, 0.95, y + 0.11, col, { hatch: 4, line: 5 });
    d.rect(0.4, 0.12, 0.6, 0.34, "#f2ead8", { hatch: 4, line: 5 }); d.circle(0.5, 0.06, 0.05, "#ffcf3a", { hatch: 3, line: 4 }); } },
  smlib_shelves_4: { base: "#9a6436", areas: false, draw: (d) => {
    d.fill([[0.32, 0.95], [0.32, 0.6], [0.5, 0.45], [0.68, 0.6], [0.68, 0.95]], "#2b1a10", { hatch: 4, line: 6 });
    d.fill([[0.28, 0.3], [0.62, 0.3], [0.6, 0.68], [0.45, 0.78], [0.3, 0.68]], "#c0302a", { hatch: 5, line: 6 });
    d.line([[0.45, 0.4], [0.45, 0.62]], 6, "#e8c45a"); d.line([[0.38, 0.48], [0.52, 0.48]], 6, "#e8c45a");
    d.fill([[0.0, 0.42], [0.5, 0.0], [1.0, 0.42], [0.9, 0.45], [0.5, 0.1], [0.1, 0.45]], "#6b3e1c", { hatch: 5, line: 6 }); } },
  smgy_yard_1: { base: "#4a4652" },  // iron fence
  // the pyre: logs, the shrouded body roped on top, log ends
  smgy_yard_2: { base: "#9a6436", areas: false, draw: (d) => {
    d.fill([[0.12, 0.12], [0.85, 0.08], [0.95, 0.25], [0.82, 0.38], [0.15, 0.4], [0.05, 0.26]], "#efe6d6", { hatch: 6, line: 7 });
    for (const x of [0.3, 0.5, 0.68]) d.line([[x, 0.08], [x + 0.03, 0.42]], 6, "#c49a52");
    for (const [x, y] of [[0.15, 0.55], [0.85, 0.62], [0.2, 0.9], [0.55, 0.92], [0.9, 0.88]]) d.circle(x, y, 0.06, "#d8a868", { hatch: 4, line: 5 });
    for (const y of [0.5, 0.68, 0.84]) d.line([[0.05, y], [0.95, y]], 5, "#5a3a1a"); } },
  // the stocks: three holes, iron plates
  smgy_yard_3: { base: "#a06a38", areas: false, draw: (d) => {
    d.circle(0.5, 0.33, 0.09, INK, { line: 0 }); d.circle(0.3, 0.33, 0.05, INK, { line: 0 }); d.circle(0.7, 0.33, 0.05, INK, { line: 0 });
    d.line([[0.12, 0.38], [0.88, 0.38]], 6, "#5a3a1a");
    for (const x of [0.13, 0.86]) d.rect(x - 0.03, 0.12, x + 0.03, 0.42, "#4a4652", { hatch: 4, line: 4 }); } },
  // the rack: its table, the rope rollers, the iron wheel
  smgy_yard_4: { base: "#a06a38", areas: false, draw: (d) => {
    d.line([[0.2, 0.1], [0.55, 0.05]], 9, "#d8c08a"); d.line([[0.45, 0.5], [0.8, 0.45]], 11, "#d8c08a");
    d.circle(0.86, 0.58, 0.11, null === 0 ? INK : "#4a4652", { hatch: 4, line: 6 });
    for (let i = 0; i < 8; i++) { const a = i / 8 * 6.283; d.line([[0.86, 0.58], [0.86 + 0.15 * Math.cos(a), 0.58 + 0.2 * Math.sin(a)]], 5, "#4a4652"); } } },
  // Honor's Tomb: the dark arched door, the steps, the round window, the red roof, spires
  smgy_tomb_1: { base: "#b4adb6", areas: false, draw: (d) => {
    d.fill([[0.3, 0.27], [0.5, 0.12], [0.7, 0.27]], "#b0583a", { hatch: 6, line: 7 });
    d.fill([[0.42, 0.74], [0.42, 0.55], [0.5, 0.47], [0.58, 0.55], [0.58, 0.74]], "#3a2a30", { hatch: 5, line: 7 });
    d.circle(0.5, 0.31, 0.06, "#8a8490", { hatch: 4, line: 6 });
    for (let i = 0; i < 6; i++) { const y = 0.74 + i * 0.04; d.line([[0.28 + i * 0.006, y], [0.72 - i * 0.006, y]], 5, "#7a7480"); }
    for (const x of [0.13, 0.25, 0.75, 0.87]) d.line([[x, 0.12 + (x < 0.2 || x > 0.8 ? 0.4 : 0)], [x, 0.3 + (x < 0.2 || x > 0.8 ? 0.4 : 0)]], 6, "#7a7480"); } },
};
Object.assign(pieces.RECIPES, PROP_RECIPES);

fs.mkdirSync(OUT, { recursive: true }); fs.mkdirSync(WORK, { recursive: true });
const names = fs.readdirSync(DIR).filter((f) => f.endsWith(".png")).map((f) => f.slice(0, -4)).filter((n) => n.includes(filter));
const done = [];
for (const name of names) {
  const out = path.join(OUT, name + ".png");
  if (fs.existsSync(out) && !force) continue;
  const img = decodePng(path.join(DIR, name + ".png"));
  // into the square canvas, centred, as big as BOX allows
  const k = BOX / Math.max(img.width, img.height), w = Math.round(img.width * k), h = Math.round(img.height * k);
  const x0 = Math.round((S - w) / 2), y0 = Math.round((S - h) / 2);
  const big = Buffer.from(resample(img, 0, 0, img.width, img.height, w, h)), sq = Buffer.alloc(S * S * 4);
  for (let y = 0; y < h; y++) big.copy(sq, ((y0 + y) * S + x0) * 4, y * w * 4, (y + 1) * w * 4);
  const file = path.join(WORK, name + ".png");
  writePng(file, S, S, sq);
  const rgba = pieces.draw(name, file);
  pieces.keepHoles(name, rgba, file);
  // back to the painting's own size (a little margin for the outline, which reaches past the painting's edge)
  const m = 14, cw = w + m * 2, ch = h + m * 2, crop = Buffer.alloc(cw * ch * 4);
  for (let y = 0; y < ch; y++) { const sy = y0 - m + y; if (sy < 0 || sy >= S) continue; rgba.copy(crop, y * cw * 4, ((sy) * S + x0 - m) * 4, ((sy) * S + x0 - m + cw) * 4); }
  const kk = Math.min(1, 340 / ch), ow = Math.round(cw * kk), oh = Math.round(ch * kk);
  writePng(out, ow, oh, kk < 1 ? Buffer.from(resample({ width: cw, height: ch, rgba: crop }, 0, 0, cw, ch, ow, oh)) : crop);
  done.push(name);
  console.log("crayon", name);
}
// The review: each painting above its crayon twin.
if (done.length) {
  const T = 200, cols = Math.min(6, done.length), rows = Math.ceil(done.length / cols), sheet = Buffer.alloc(T * cols * T * 2 * rows * 4);
  done.forEach((name, n) => [path.join(DIR, name + ".png"), path.join(OUT, name + ".png")].forEach((f, row) => {
    const im = decodePng(f), k = Math.min(T / im.width, T / im.height), w = Math.max(1, Math.round(im.width * k)), h = Math.max(1, Math.round(im.height * k));
    const s = resample(im, 0, 0, im.width, im.height, w, h), ox = (n % cols) * T + ((T - w) >> 1), oy = (Math.floor(n / cols) * 2 + row) * T + (T - h);
    for (let y = 0; y < T; y++) for (let x = 0; x < T; x++) { const o = (((Math.floor(n / cols) * 2 + row) * T + y) * T * cols + (n % cols) * T + x) * 4; sheet[o] = 226; sheet[o + 1] = 216; sheet[o + 2] = 196; sheet[o + 3] = 255; }
    for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) { const i = (y * w + x) * 4, a = s[i + 3] / 255, o = ((oy + y) * T * cols + ox + x) * 4;
      for (let c = 0; c < 3; c++) sheet[o + c] = Math.round(s[i + c] * a + sheet[o + c] * (1 - a)); }
  }));
  writePng(path.join(OUT, "crayon-review.png"), T * cols, T * 2 * rows, sheet);
}
console.log(`${done.length} crayon props -> ${OUT}`);
