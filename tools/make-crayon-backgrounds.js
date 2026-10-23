// Hand-drawn crayon backgrounds, one for each painted background in the minting art, in the fridge-drawing style
// (tools/make-crayon-mints.js): big flat crayon shapes with bold outlines, drawn the way a kid (or an ogre) would see
// the same place. The ogre stands in the middle, so the fun goes round the edges and up top.
// Writes %USERPROFILE%\killtracker-art-extra\CrayonHand\Background\<rarity>\<name>.png and backgrounds.png (each one
// with a crayon ogre on it).
// Also the dungeons' backgrounds (bg_<key>, the painted ones from tools/gen-art.js): their crayon twins go to
// %USERPROFILE%\killtracker-art-extra\Unlocks\generated\crayon\bg_<key>.png, where make-unlock-art.js takes them.
// Usage: node tools/make-crayon-backgrounds.js [filter]   No dependencies.

const fs = require("fs");
const os = require("os");
const path = require("path");
const crayon = require("./make-role-icons");
const { decodePng, resample } = require("./convert-art");

const S = 1254;
crayon.setSize(S);
const { canvas, dab, stroke, crayonShape, circle, ellipse, star, quad, rotate, hex, OUTLINE, rng, writePng } = crayon;
const OUT = path.join(os.homedir(), "killtracker-art-extra", "CrayonHand");
const filter = process.argv[2] || "";

const LINE = 18, HATCH = 26;
const fill = (c, poly, col, r, o = {}) => crayonShape(c, poly, hex(col), r, { fit: true, line: LINE, hatch: HATCH, ...o });
const soft = (c, poly, col, r, o = {}) => fill(c, poly, col, r, { outline: null, ...o });
const line = (c, pts, w, col, r) => stroke(c, pts, w, typeof col === "string" ? hex(col) : col, 0.95, r);
const curve = (pts, n = 16) => pts.slice(1).flatMap((p, i) => quad(pts[i], [(pts[i][0] + p[0]) / 2, (pts[i][1] + p[1]) / 2], p, n).slice(i ? 1 : 0));
const rect = (x0, y0, x1, y1) => [[x0, y0], [x1, y0], [x1, y1], [x0, y1]];
const ALL = rect(0, 0, S, S);

// --- Pieces ---
const sky = (c, r, col) => soft(c, ALL, col, r, { hatch: 34 });
// A sky that changes colour in bands from the top (sunsets), scribbled.
function skyBands(c, r, cols) {
  const h = S / cols.length;
  cols.forEach((col, i) => soft(c, rect(0, i * h - 20, S, (i + 1) * h + 20), col, r, { hatch: 34 }));
}
// Rolling ground from height y down, wobbling up and down.
function hills(c, r, y, col, amp = 60, waves = 2, phase = 0) {
  const pts = [];
  for (let i = 0; i <= 24; i++) { const x = (i / 24) * S; pts.push([x, y - Math.sin((i / 24) * Math.PI * waves + phase) * amp]); }
  fill(c, [[0, S], ...pts, [S, S]], col, r, { hatch: 30 });
}
function sun(c, r, x, y, rad, face = true) {
  for (let i = 0; i < 12; i++) {
    const a = (i / 12) * 2 * Math.PI;
    line(c, [[x + Math.cos(a) * (rad + 20), y + Math.sin(a) * (rad + 20)], [x + Math.cos(a) * (rad + 70), y + Math.sin(a) * (rad + 70)]], 22, "#ff9a2a", r);
  }
  fill(c, circle(x, y, rad), "#ffd23f", r);
  if (face) {
    for (const dx of [-rad * 0.35, rad * 0.35]) line(c, curve([[x + dx - 16, y - 8], [x + dx, y + 6], [x + dx + 16, y - 8]], 6), 10, OUTLINE, r);
    line(c, curve([[x - 28, y + 30], [x, y + 46], [x + 28, y + 30]], 8), 10, OUTLINE, r);
  }
}
function moon(c, r, x, y, rad) {
  const arc = (cx, cy, rr, a0, a1) => Array.from({ length: 17 }, (_, k) => { const a = a0 + ((a1 - a0) * k) / 16; return [cx + Math.cos(a) * rr, cy + Math.sin(a) * rr]; });
  fill(c, [...arc(x, y, rad, -1.9, 1.9), ...arc(x - rad * 0.45, y - rad * 0.1, rad * 0.8, 1.6, -1.6)], "#fff2a8", r);
  dab(c, x + rad * 0.45, y - rad * 0.1, 8, OUTLINE, 0.9);  // a sleepy eye
}
function cloud(c, r, x, y, w, col = "#ffffff") {
  fill(c, [...curve([[x - w, y + 20], [x - w * 0.9, y - 30], [x - w * 0.4, y - 50], [x, y - 70], [x + w * 0.5, y - 45], [x + w, y - 10], [x + w * 0.9, y + 30]], 10),
    ...curve([[x + w * 0.9, y + 30], [x, y + 46], [x - w, y + 20]], 10).slice(1)], col, r, { hatch: 20 });
}
function stars(c, r, n, y1 = 600, col = "#fff6c0") {
  for (let i = 0; i < n; i++) { const x = 40 + r() * (S - 80), y = 30 + r() * y1; fill(c, star(x, y, 24 + r() * 14, 10), col, r, { line: 10, hatch: 10 }); }
}
// A lollipop tree: a trunk and a big round top.
function tree(c, r, x, ground, h, top = "#5bb43a", w = 1) {
  fill(c, rect(x - 26 * w, ground - h, x + 26 * w, ground + 10), "#8a5a2e", r);
  fill(c, circle(x, ground - h - 60 * w, 110 * w), top, r);
  for (let i = 0; i < 4; i++) dab(c, x - 50 * w + r() * 100 * w, ground - h - 110 * w + r() * 100 * w, 10, hex("#e8463a"), 0.9);  // apples
}
function palm(c, r, x, ground, h, lean = 1) {
  const trunk = curve([[x, ground], [x + 40 * lean, ground - h / 2], [x + 90 * lean, ground - h]]);
  line(c, trunk, 44, "#a8743e", r);
  const hx = x + 90 * lean, hy = ground - h;
  for (const a of [-2.8, -2.1, -1.5, -0.9, -0.25, 0.4]) {
    const tip = [hx + Math.cos(a) * 230, hy + Math.sin(a) * 150 + 70];
    const mid = [(hx + tip[0]) / 2, (hy + tip[1]) / 2], nx = -(tip[1] - hy), ny = tip[0] - hx, d = Math.hypot(nx, ny) || 1;
    const bulge = 45;
    fill(c, [[hx, hy], ...curve([[hx, hy], [mid[0] + (nx / d) * bulge, mid[1] + (ny / d) * bulge - 30], tip], 8).slice(1),
      ...curve([tip, [mid[0] - (nx / d) * bulge * 0.4, mid[1] - (ny / d) * bulge * 0.4], [hx, hy]], 8).slice(1)], "#3f9a3a", r, { hatch: 16, line: 14 });
  }
  for (const dx of [-24, 18]) fill(c, circle(hx + dx, hy + 30, 24), "#8a5a2e", r, { line: 12, hatch: 10 });  // coconuts
}
function flower(c, r, x, y, col) {
  line(c, [[x, y], [x, y + 90]], 14, "#3f8a2e", r);
  for (let i = 0; i < 5; i++) { const a = (i / 5) * 2 * Math.PI; fill(c, circle(x + Math.cos(a) * 26, y + Math.sin(a) * 26, 22), col, r, { line: 10, hatch: 12 }); }
  fill(c, circle(x, y, 18), "#ffd23f", r, { line: 10, hatch: 12 });
}
function waves(c, r, y, col = "#ffffff", n = 7) {
  for (let i = 0; i < n; i++) {
    const x = 60 + r() * (S - 120), yy = y + r() * 160;
    line(c, curve([[x, yy], [x + 30, yy - 18], [x + 60, yy], [x + 90, yy - 18], [x + 120, yy]], 6), 10, col, r);
  }
}
function flag(c, r, x, ground, col = "#e8463a") {
  line(c, [[x, ground], [x, ground - 220]], 12, "#3a3236", r);
  fill(c, [[x, ground - 220], [x + 100, ground - 190], [x, ground - 160]], col, r, { hatch: 14 });
}
function rock(c, r, x, y, w, col = "#9aa0a8") { fill(c, [...curve([[x - w, y], [x - w * 0.8, y - w * 0.7], [x, y - w * 0.9], [x + w * 0.9, y - w * 0.6], [x + w, y]], 8)], col, r); }
function zzz(c, r, x, y, s = 40, col = "#4f86e8") {
  [0, 1, 2].forEach((k) => { const ss = s * (1 - k * 0.2), xx = x + k * s * 0.9, yy = y - k * s * 0.8;
    line(c, [[xx, yy], [xx + ss, yy], [xx, yy + ss], [xx + ss, yy + ss]], 12, col, r); });
}

// Caves: icicle-like rocks hanging from the top.
function stalactites(c, r, n, col, len = 180) {
  for (let i = 0; i < n; i++) {
    const x = (i + 0.5) * (S / n) + (r() - 0.5) * 50, w = 40 + r() * 40, l = len * (0.6 + r() * 0.7);
    fill(c, [[x - w, -10], [x + w, -10], [x + 6, l]], col, r, { hatch: 16 });
  }
}
// A lava river from y0 to y1: orange with yellow squiggles and bubbles.
function lava(c, r, y0, y1) {
  fill(c, [[0, y0], ...curve([[0, y0], [S * 0.3, y0 - 30], [S * 0.6, y0 + 20], [S, y0 - 10]], 12).slice(1), [S, y1], [0, y1]], "#ff7a1a", r, { hatch: 22 });
  for (let i = 0; i < 10; i++) {
    const x = 40 + r() * (S - 160), y = y0 + 20 + r() * (y1 - y0 - 40);
    line(c, curve([[x, y], [x + 30, y - 14], [x + 60, y], [x + 90, y - 14]], 6), 10, "#ffd23f", r);
  }
  for (let i = 0; i < 6; i++) fill(c, circle(60 + r() * (S - 120), y0 + 30 + r() * (y1 - y0 - 50), 12 + r() * 14), "#ffe27a", r, { line: 8, hatch: 8 });
}
// Glowing bits floating up.
function embers(c, r, n, y0, y1) {
  for (let i = 0; i < n; i++) dab(c, 30 + r() * (S - 60), y0 + r() * (y1 - y0), 7 + r() * 6, hex(r() < 0.5 ? "#ffb02a" : "#ffe27a"), 0.95);
}
// A rope bridge from x0 to x1, sagging, with planks.
function ropeBridge(c, r, x0, x1, y, sag = 50) {
  const at = (t) => [x0 + (x1 - x0) * t, y + Math.sin(t * Math.PI) * sag];
  for (const dy of [0, -70]) line(c, Array.from({ length: 13 }, (_, k) => { const [x, yy] = at(k / 12); return [x, yy + dy]; }), 8, "#c8a060", r);
  for (let k = 0; k <= 12; k++) { const [x, yy] = at(k / 12); fill(c, rect(x - 16, yy - 6, x + 16, yy + 14), "#8a5a2e", r, { line: 8, hatch: 8 }); line(c, [[x, yy - 70], [x, yy]], 6, "#c8a060", r); }
  for (const x of [x0, x1]) fill(c, rect(x - 14, y - 110, x + 14, y + 20), "#6a4026", r, { line: 10, hatch: 10 });
}
// A fire bowl on legs.
function brazier(c, r, x, ground) {
  line(c, [[x - 50, ground], [x, ground - 120]], 14, "#3a3236", r); line(c, [[x + 50, ground], [x, ground - 120]], 14, "#3a3236", r);
  fill(c, [[x - 80, ground - 140], [x + 80, ground - 140], [x + 50, ground - 100], [x - 50, ground - 100]], "#5a5058", r, { hatch: 12 });
  fill(c, [[x - 60, ground - 140], [x - 40, ground - 220], [x - 10, ground - 170], [x + 10, ground - 260], [x + 30, ground - 175], [x + 50, ground - 215], [x + 62, ground - 140]], "#ff7a1a", r, { hatch: 12 });
  fill(c, [[x - 28, ground - 140], [x, ground - 200], [x + 28, ground - 140]], "#ffe27a", r, { line: 8, hatch: 8 });
}

// A flat floor from y down (a wobbly top edge).
function floor(c, r, y, col, amp = 20) {
  fill(c, [[0, y], ...curve([[0, y], [S * 0.35, y - amp], [S * 0.7, y + amp], [S, y - amp / 2]], 12).slice(1), [S, S], [0, S]], col, r);
}
// Water from y down, with little wave marks.
function water(c, r, y, col, wave = "#bff7e8", n = 8) {
  fill(c, [[0, y], ...curve([[0, y], [S * 0.5, y - 16], [S, y]], 12).slice(1), [S, S], [0, S]], col, r);
  waves(c, r, y + 20, wave, n);
}
// A big mushroom: a stalk and a round cap with spots.
function mushroom(c, r, x, ground, h, cap, w = 1) {
  fill(c, [[x - 30 * w, ground], [x - 22 * w, ground - h], [x + 22 * w, ground - h], [x + 30 * w, ground]], "#f0e2c0", r);
  fill(c, [...curve([[x - 130 * w, ground - h + 10], [x - 110 * w, ground - h - 100 * w], [x, ground - h - 130 * w], [x + 110 * w, ground - h - 100 * w], [x + 130 * w, ground - h + 10]], 12)], cap, r);
  for (let i = 0; i < 4; i++) fill(c, circle(x - 70 * w + i * 45 * w, ground - h - 50 * w - (i % 2) * 30 * w, 14 * w), "#fff6e0", r, { line: 8, hatch: 8 });
}
// Vines hanging from the top, with leaves.
function vines(c, r, xs, col = "#3f9a3a") {
  for (const x of xs) {
    const len = 200 + r() * 260, pts = curve([[x, -10], [x + 30, len * 0.5], [x - 20, len]], 10);
    line(c, pts, 12, col, r);
    for (let k = 2; k < pts.length; k += 3) fill(c, ellipse(pts[k][0] + (k % 2 ? 22 : -22), pts[k][1], 22, 12), "#5bb43a", r, { line: 8, hatch: 8 });
  }
}
// A lantern hanging on a rope, glowing.
function lantern(c, r, x, y, rope = 120) {
  line(c, [[x, y - rope], [x, y - 30]], 6, "#3a3236", r);
  dab(c, x, y, 50, hex("#ffd23f"), 0.25);
  fill(c, rect(x - 26, y - 30, x + 26, y + 34), "#ffd23f", r, { line: 10, hatch: 10 });
  fill(c, rect(x - 32, y - 40, x + 32, y - 28), "#3a3236", r, { line: 8, hatch: 8 });
}
// A barrel; a crate.
function barrel(c, r, x, ground, w = 70, band = "#3a3236") {
  fill(c, [...curve([[x - w, ground], [x - w - 12, ground - w], [x - w, ground - w * 2]], 8), ...curve([[x + w, ground - w * 2], [x + w + 12, ground - w], [x + w, ground]], 8)], "#a8743e", r);
  for (const k of [0.3, 1.7]) line(c, [[x - w - 8, ground - w * k], [x + w + 8, ground - w * k]], 10, band, r);
}
function crate(c, r, x, ground, w = 120) {
  fill(c, rect(x - w / 2, ground - w, x + w / 2, ground), "#c8944e", r);
  line(c, [[x - w / 2 + 10, ground - w + 10], [x + w / 2 - 10, ground - 10]], 10, "#8a5a2e", r);
  line(c, [[x + w / 2 - 10, ground - w + 10], [x - w / 2 + 10, ground - 10]], 10, "#8a5a2e", r);
}
// A castle tower: walls, battlements, a lit window or two, maybe a pointy roof.
function tower(c, r, x, ground, w, h, col = "#7a7a8a", roof = null) {
  fill(c, rect(x - w / 2, ground - h, x + w / 2, ground), col, r);
  const n = Math.max(2, Math.round(w / 60));
  if (!roof) for (let i = 0; i < n; i++) { const bx = x - w / 2 + (i + 0.5) * (w / n); fill(c, rect(bx - w / n / 3, ground - h - 50, bx + w / n / 3, ground - h + 4), col, r, { hatch: 12 }); }
  else fill(c, [[x - w / 2 - 20, ground - h], [x, ground - h - w * 0.9], [x + w / 2 + 20, ground - h]], roof, r);
  for (let k = 0; k < 2; k++) fill(c, [...curve([[x - 18, ground - h * (0.45 + k * 0.3) + 40], [x - 18, ground - h * (0.45 + k * 0.3)], [x, ground - h * (0.45 + k * 0.3) - 22], [x + 18, ground - h * (0.45 + k * 0.3)], [x + 18, ground - h * (0.45 + k * 0.3) + 40]], 6)], "#ffd23f", r, { line: 8, hatch: 8 });
}
// A torch on a wall: a stick and a flame.
function torch(c, r, x, y) {
  line(c, [[x, y], [x + 10, y - 70]], 14, "#6a4026", r);
  fill(c, [[x - 18, y - 70], [x + 4, y - 140], [x + 14, y - 100], [x + 30, y - 120], [x + 34, y - 70]], "#ff8a2a", r, { line: 10, hatch: 10 });
  fill(c, [[x - 2, y - 72], [x + 10, y - 108], [x + 20, y - 72]], "#ffe27a", r, { line: 6, hatch: 6 });
}
// A bat (or a few).
function bat(c, r, x, y, s = 1) {
  fill(c, [[x, y], [x - 30 * s, y - 24 * s], [x - 70 * s, y - 10 * s], [x - 50 * s, y + 4 * s], [x - 30 * s, y - 2 * s], [x - 12 * s, y + 14 * s], [x, y + 6 * s],
    [x + 12 * s, y + 14 * s], [x + 30 * s, y - 2 * s], [x + 50 * s, y + 4 * s], [x + 70 * s, y - 10 * s], [x + 30 * s, y - 24 * s]], "#2a2436", r, { line: 8, hatch: 8 });
}
// Soft mist low down.
function mist(c, r, y, n, col = "#d8e0f0") {
  for (let i = 0; i < n; i++) soft(c, ellipse(r() * S, y + r() * 120, 120 + r() * 120, 30 + r() * 20), col, r, { hatch: 30 });
}
// A stone pillar, whole or broken off.
function pillar(c, r, x, ground, h, col = "#b8b0c8", broken = false) {
  const top = ground - h;
  fill(c, broken ? [[x - 45, ground], [x - 45, top + 30], [x - 10, top], [x + 10, top + 40], [x + 45, top + 10], [x + 45, ground]] : rect(x - 45, top, x + 45, ground), col, r);
  if (!broken) fill(c, rect(x - 65, top - 30, x + 65, top + 4), col, r, { hatch: 12 });
  fill(c, rect(x - 65, ground - 30, x + 65, ground + 4), col, r, { hatch: 12 });
}
// Bubbles going up.
function bubbles(c, r, n, col = "#cfefff") { for (let i = 0; i < n; i++) fill(c, circle(40 + r() * (S - 80), 60 + r() * 700, 8 + r() * 14), col, r, { line: 6, hatch: 6, outline: hex("#ffffff") }); }
// Seaweed from the bottom.
function seaweed(c, r, x, ground, h, col = "#3f9a5a") {
  line(c, curve([[x, ground], [x + 30, ground - h * 0.35], [x - 30, ground - h * 0.7], [x + 10, ground - h]], 10), 18, col, r);
}
// Iron bars across an opening.
function bars(c, r, x0, y0, x1, y1) {
  fill(c, rect(x0, y0, x1, y1), "#24242c", r);
  for (let x = x0 + 30; x < x1; x += 46) line(c, [[x, y0 + 6], [x, y1 - 6]], 12, "#9aa0a8", r);
  line(c, [[x0 + 6, y0 + 50], [x1 - 6, y0 + 50]], 12, "#9aa0a8", r);
}
// A chain hanging down.
function chain(c, r, x, y0, len) { for (let y = y0; y < y0 + len; y += 34) fill(c, ellipse(x, y, 12, 20), "#9aa0a8", r, { line: 8, hatch: 6 }); }
// A cog: a ring of teeth round a wheel with a hub.
function gear(c, r, x, y, rad, col = "#b0a070") {
  const pts = [];
  for (let i = 0; i < 48; i++) { const a = (i / 48) * 2 * Math.PI, out = Math.floor(i / 3) % 2 ? rad : rad * 1.18; pts.push([x + Math.cos(a) * out, y + Math.sin(a) * out]); }
  fill(c, pts, col, r);
  fill(c, circle(x, y, rad * 0.35), "#5a5058", r, { hatch: 10 });
}
// A thick pipe through points, with joints.
function pipe(c, r, pts, col = "#7a8a9a") {
  line(c, pts, 54, OUTLINE, r); line(c, pts, 38, col, r);
  for (const [x, y] of pts) fill(c, circle(x, y, 32), col, r, { line: 10, hatch: 10 });
}
// A thorny bramble: a fat wiggly stem with spikes.
function bramble(c, r, pts, col = "#5a6a2a") {
  const path = curve(pts, 14);
  line(c, path, 46, OUTLINE, r); line(c, path, 32, col, r);
  for (let k = 3; k < path.length - 1; k += 4) {
    const [x, y] = path[k], [x2, y2] = path[k + 1], nx = -(y2 - y), ny = x2 - x, d = Math.hypot(nx, ny) || 1, side = k % 8 < 4 ? 1 : -1;
    fill(c, [[x - 10, y], [x + (nx / d) * 46 * side, y + (ny / d) * 46 * side], [x + 10, y]], "#e8d8a0", r, { line: 6, hatch: 6 });
  }
}
// A bone totem: a pole of stacked skulls.
function totem(c, r, x, ground, h) {
  line(c, [[x, ground], [x, ground - h]], 22, "#8a5a2e", r);
  for (let k = 0; k < 3; k++) {
    const y = ground - h + k * 90;
    fill(c, [...curve([[x - 40, y + 30], [x - 44, y - 20], [x, y - 40], [x + 44, y - 20], [x + 40, y + 30]], 8)], "#f0e8d0", r, { hatch: 10 });
    dab(c, x - 16, y - 2, 10, OUTLINE, 0.95); dab(c, x + 16, y - 2, 10, OUTLINE, 0.95);
  }
  for (const dx of [-60, 60]) line(c, [[x, ground - h + 40], [x + dx, ground - h - 10]], 12, "#f0e8d0", r);  // tusks
}
// A hut: a dome with a dark door.
function hut(c, r, x, ground, w, col = "#8a7a3a") {
  fill(c, [[x - w, ground], ...curve([[x - w, ground], [x - w * 0.8, ground - w * 0.9], [x, ground - w * 1.1], [x + w * 0.8, ground - w * 0.9], [x + w, ground]], 12).slice(1)], col, r);
  fill(c, [...curve([[x - w * 0.25, ground], [x - w * 0.25, ground - w * 0.45], [x, ground - w * 0.55], [x + w * 0.25, ground - w * 0.45], [x + w * 0.25, ground]], 8)], "#2a2020", r, { hatch: 10 });
}

// A tombstone, round-topped, with a cross scratched on.
function tombstone(c, r, x, ground, w = 70, tilt = 0) {
  fill(c, [[x - w + tilt, ground], ...curve([[x - w, ground - w * 1.4], [x - w * 0.8, ground - w * 2], [x + tilt, ground - w * 2.2], [x + w * 0.8, ground - w * 2], [x + w, ground - w * 1.4]], 8), [x + w + tilt, ground]], "#9a9aa8", r);
  line(c, [[x + tilt / 2, ground - w * 1.8], [x + tilt / 2, ground - w * 0.9]], 10, "#5a5a68", r);
  line(c, [[x - w * 0.35, ground - w * 1.5], [x + w * 0.35, ground - w * 1.5]], 10, "#5a5a68", r);
}
// A bare dead tree, branches like a hand.
function deadTree(c, r, x, ground, h, col = "#4a3a3a") {
  line(c, curve([[x, ground], [x + 10, ground - h * 0.5], [x - 10, ground - h]], 10), 40, col, r);
  for (const [dx, dy, ex, ey] of [[-10, 0.7, -140, 0.95], [10, 0.6, 150, 0.85], [-5, 0.85, -60, 1.15], [0, 0.9, 80, 1.15]])
    line(c, curve([[x + dx, ground - h * dy], [x + (dx + ex) / 2, ground - h * (dy + ey) / 2 - 20], [x + ex, ground - h * ey]], 8), 18, col, r);
}
// A long banner hanging down with a point at the bottom (and an emblem dot).
function banner(c, r, x, y, w, h, col, emblem = "#ffd23f") {
  fill(c, [[x - w / 2, y], [x + w / 2, y], [x + w / 2, y + h], [x, y + h - 50], [x - w / 2, y + h]], col, r, { hatch: 14 });
  line(c, [[x - w / 2 - 20, y], [x + w / 2 + 20, y]], 12, "#6a4026", r);
  fill(c, circle(x, y + h * 0.4, w * 0.22), emblem, r, { line: 8, hatch: 8 });
}
// A candle (a few, on a stand) with a flame.
function candle(c, r, x, ground, h = 90, flame = "#ffd23f") {
  fill(c, rect(x - 16, ground - h, x + 16, ground), "#f0e8d0", r, { line: 8, hatch: 8 });
  fill(c, [[x - 12, ground - h], [x, ground - h - 46], [x + 12, ground - h]], flame, r, { line: 6, hatch: 6 });
}
// A bookshelf full of coloured books.
function bookshelf(c, r, x0, y0, x1, y1) {
  fill(c, rect(x0, y0, x1, y1), "#7a4a26", r);
  const rows = Math.max(2, Math.round((y1 - y0) / 140)), cols = ["#d8402e", "#4f86e8", "#5bb43a", "#ffd23f", "#9a5ac8", "#e88a3a"];
  for (let k = 0; k < rows; k++) {
    const top = y0 + 20 + k * ((y1 - y0 - 20) / rows), bot = top + (y1 - y0 - 20) / rows - 20;
    for (let x = x0 + 18; x < x1 - 30; x += 34) fill(c, rect(x, top + (r() * 24), x + 28, bot), cols[Math.floor(r() * cols.length)], r, { line: 6, hatch: 6 });
    line(c, [[x0, bot + 6], [x1, bot + 6]], 12, "#5a3418", r);
  }
}
// A rack of swords; a training dummy.
function swordRack(c, r, x, ground) {
  fill(c, rect(x - 110, ground - 30, x + 110, ground), "#7a4a26", r, { hatch: 10 });
  for (let k = 0; k < 4; k++) { const sx = x - 80 + k * 54; fill(c, [[sx - 10, ground - 30], [sx - 10, ground - 260], [sx, ground - 290], [sx + 10, ground - 260], [sx + 10, ground - 30]], "#c8d0d8", r, { line: 8, hatch: 6 }); line(c, [[sx - 26, ground - 70], [sx + 26, ground - 70]], 10, "#ffd23f", r); }
}
function dummy(c, r, x, ground) {
  line(c, [[x, ground], [x, ground - 260]], 18, "#8a5a2e", r);
  line(c, [[x - 90, ground - 190], [x + 90, ground - 190]], 16, "#8a5a2e", r);
  fill(c, ellipse(x, ground - 160, 60, 80), "#e8c870", r, { hatch: 12 });
  fill(c, circle(x, ground - 270, 44), "#e8c870", r, { hatch: 10 });
  for (const dx of [-14, 14]) line(c, [[x + dx - 8, ground - 278], [x + dx + 8, ground - 262]], 6, OUTLINE, r);
}
// A tall pointed stained-glass window.
function stainedGlass(c, r, x, y, w, h) {
  const shape = [[x - w / 2, y + h], ...curve([[x - w / 2, y + w / 2], [x - w / 2, y], [x, y - w / 2], [x + w / 2, y], [x + w / 2, y + w / 2]], 8), [x + w / 2, y + h]];
  fill(c, shape, "#4f86e8", r);
  const cols = ["#d8402e", "#ffd23f", "#5bb43a", "#9a5ac8"];
  for (let k = 0; k < 6; k++) fill(c, rect(x - w / 2 + 14 + (k % 2) * (w / 2 - 14), y + (k >> 1) * (h / 3), x - 14 + (k % 2) * (w / 2), y + (k >> 1) * (h / 3) + h / 3 - 20), cols[k % 4], r, { line: 6, hatch: 8 });
  line(c, [[x, y - w / 2 + 10], [x, y + h]], 10, OUTLINE, r);
}
// A stepped pyramid (temple), from the ground up.
function pyramid(c, r, x, ground, w, h, col, steps = 4) {
  for (let k = 0; k < steps; k++) { const ww = w * (1 - k / steps), hh = h / steps; fill(c, rect(x - ww / 2, ground - (k + 1) * hh, x + ww / 2, ground - k * hh), col, r, { hatch: 14 }); }
  fill(c, rect(x - 30, ground - 110, x + 30, ground), "#3a2a20", r, { hatch: 8 });
}
// A crystal: a tall glowing shard (a cluster when n > 1).
function crystal(c, r, x, ground, h, col = "#b07aff", n = 3) {
  for (let k = 0; k < n; k++) { const dx = (k - (n - 1) / 2) * 50, hh = h * (k === Math.floor(n / 2) ? 1 : 0.65), lean = (k - (n - 1) / 2) * 30;
    fill(c, [[x + dx - 26, ground], [x + dx - 22 + lean, ground - hh * 0.8], [x + dx + lean, ground - hh], [x + dx + 22 + lean, ground - hh * 0.8], [x + dx + 26, ground]], col, r, { hatch: 10 }); }
  dab(c, x, ground - h * 0.5, h * 0.6, hex(col), 0.15);
}
// A waterfall down to y1.
function waterfall(c, r, x, y0, y1, w = 90) {
  fill(c, rect(x - w / 2, y0, x + w / 2, y1), "#7ad0f0", r, { hatch: 10 });
  for (let k = 0; k < 4; k++) line(c, [[x - w / 2 + 18 + k * (w - 36) / 3, y0 + 20], [x - w / 2 + 18 + k * (w - 36) / 3, y1 - 20]], 6, "#e0f8ff", r);
  cloud(c, r, x, y1, w * 0.9, "#ffffff");
}
// A blocky stone statue standing on a plinth (a dwarf thane, a titan): a big head, a beard, arms crossed.
function statue(c, r, x, ground, h, col = "#a8a0a0", beard = true) {
  fill(c, rect(x - 90, ground - 60, x + 90, ground), col, r, { hatch: 12 });
  fill(c, rect(x - 70, ground - h * 0.75, x + 70, ground - 60), col, r);
  fill(c, circle(x, ground - h * 0.82, 56), col, r);
  if (beard) fill(c, [[x - 46, ground - h * 0.8], [x + 46, ground - h * 0.8], [x, ground - h * 0.55]], col, r, { hatch: 10 });
  line(c, [[x - 60, ground - h * 0.5], [x + 60, ground - h * 0.5]], 14, "#7a7272", r);
  for (const dx of [-20, 20]) dab(c, x + dx, ground - h * 0.85, 8, OUTLINE, 0.9);
}
// An anvil, and a forge's glowing mouth.
function anvil(c, r, x, ground) {
  fill(c, [[x - 70, ground], [x - 40, ground - 60], [x - 90, ground - 70], [x - 90, ground - 110], [x + 110, ground - 110], [x + 60, ground - 70], [x + 40, ground - 60], [x + 70, ground]], "#5a5a68", r);
}
function forge(c, r, x, ground, w = 260) {
  fill(c, rect(x - w / 2, ground - w, x + w / 2, ground), "#6a5a5a", r);
  fill(c, [...curve([[x - w / 3, ground - 30], [x - w / 3, ground - w * 0.55], [x, ground - w * 0.75], [x + w / 3, ground - w * 0.55], [x + w / 3, ground - 30]], 8)], "#ff8a2a", r, { hatch: 10 });
  fill(c, [[x - 40, ground - 30], [x - 10, ground - 140], [x + 10, ground - 90], [x + 40, ground - 30]], "#ffe27a", r, { line: 8, hatch: 8 });
  dab(c, x, ground - w * 0.4, w * 0.7, hex("#ffb02a"), 0.18);
}
// Rain streaks.
function rain(c, r, n, col = "#a8c8e8") { for (let i = 0; i < n; i++) { const x = r() * S, y = r() * S * 0.9; line(c, [[x, y], [x - 16, y + 50]], 5, col, r); } }
// A mine cart on a rail.
function mineCart(c, r, x, ground, load = "#9aa0a8") {
  line(c, [[x - 220, ground + 8], [x + 220, ground + 8]], 10, "#5a5058", r);
  fill(c, [...curve([[x - 80, ground - 92], [x - 60, ground - 120], [x, ground - 130], [x + 60, ground - 120], [x + 80, ground - 92]], 8)], load, r, { hatch: 10 });
  fill(c, [[x - 100, ground - 100], [x + 100, ground - 100], [x + 80, ground - 10], [x - 80, ground - 10]], "#7a7a8a", r, { hatch: 12 });
  for (const dx of [-50, 50]) fill(c, circle(x + dx, ground, 20), "#3a3236", r, { line: 8, hatch: 6 });
}

// A dragon's egg: an oval with spots.
function egg(c, r, x, ground, h = 130, col = "#5a3a4a", spot = "#ff7a3a") {
  fill(c, Array.from({ length: 40 }, (_, i) => { const a = (i / 40) * 2 * Math.PI, top = Math.sin(a) < 0;  // (an egg: narrower at the top)
    return [x + Math.cos(a) * h * (top ? 0.34 : 0.4), ground - h * 0.42 + Math.sin(a) * h * (top ? 0.58 : 0.42)]; }), col, r);
  for (const [dx, dy] of [[-0.12, 0.35], [0.1, 0.5], [-0.02, 0.72]]) dab(c, x + dx * h, ground - dy * h, h * 0.06, hex(spot), 0.95);
}
// A pile of gold coins.
function gold(c, r, x, ground, w) {
  fill(c, [[x - w, ground], ...curve([[x - w, ground], [x - w * 0.5, ground - w * 0.45], [x, ground - w * 0.6], [x + w * 0.5, ground - w * 0.45], [x + w, ground]], 10).slice(1)], "#ffd23f", r);
  for (let k = 0; k < 6; k++) fill(c, circle(x - w * 0.6 + k * w * 0.24, ground - w * 0.15 - (k % 2) * w * 0.2, 16), "#ffe27a", r, { line: 6, hatch: 6 });
}
// A house with a pitched roof (on fire if asked).
function house(c, r, x, ground, w, h, col = "#c8b090", roof = "#8a4a3a", fire = false) {
  fill(c, rect(x - w / 2, ground - h, x + w / 2, ground), col, r);
  fill(c, [[x - w / 2 - 20, ground - h], [x, ground - h - w * 0.5], [x + w / 2 + 20, ground - h]], roof, r);
  fill(c, rect(x - 18, ground - 70, x + 18, ground), "#5a3418", r, { hatch: 8 });
  fill(c, rect(x - w / 2 + 20, ground - h + 30, x - w / 2 + 60, ground - h + 70), "#ffd23f", r, { line: 8, hatch: 8 });
  if (fire) fill(c, [[x - w / 3, ground - h - w * 0.25], [x - w / 4, ground - h - w * 0.75], [x - w / 8, ground - h - w * 0.5], [x, ground - h - w], [x + w / 8, ground - h - w * 0.55], [x + w / 4, ground - h - w * 0.8], [x + w / 3, ground - h - w * 0.3]], "#ff7a1a", r, { hatch: 12 });
}
// A Scourge ziggurat: a dark stepped pyramid with a glowing top.
function ziggurat(c, r, x, ground, w, h) {
  pyramid(c, r, x, ground, w, h, "#4a3a5a", 3);
  fill(c, [[x - w * 0.12, ground - h], [x, ground - h - w * 0.2], [x + w * 0.12, ground - h]], "#7aff9a", r, { hatch: 10 });
  dab(c, x, ground - h - w * 0.1, w * 0.4, hex("#7aff9a"), 0.18);
}
// An ogre's tent.
function tent(c, r, x, ground, w, col = "#b8945a") {
  fill(c, [[x - w, ground], [x, ground - w * 1.1], [x + w, ground]], col, r);
  fill(c, [[x - w * 0.25, ground], [x, ground - w * 0.55], [x + w * 0.25, ground]], "#3a2a1a", r, { hatch: 10 });
  for (const dx of [-30, 30]) line(c, [[x, ground - w * 1.1], [x + dx, ground - w * 1.35]], 12, "#8a5a2e", r);
}
// A pine tree with snow on it.
function pine(c, r, x, ground, h, snow = true) {
  fill(c, rect(x - 18, ground - 40, x + 18, ground), "#6a4026", r, { hatch: 8 });
  for (let k = 0; k < 3; k++) { const w = h * (0.42 - k * 0.1), y = ground - 40 - k * h * 0.28;
    fill(c, [[x - w, y], [x, y - h * 0.42], [x + w, y]], "#2f7a4a", r, { hatch: 12 });
    if (snow) fill(c, [[x - w * 0.5, y - h * 0.2], [x, y - h * 0.42], [x + w * 0.5, y - h * 0.2]], "#ffffff", r, { line: 8, hatch: 6 }); }
}
// Wavy bands of aurora light in the sky.
function aurora(c, r, cols) {
  cols.forEach((col, k) => { const y = 120 + k * 70;
    soft(c, [...curve([[-20, y], [S * 0.3, y - 60], [S * 0.6, y + 40], [S + 20, y - 30]], 12), ...curve([[S + 20, y + 30], [S * 0.6, y + 100], [S * 0.3, y], [-20, y + 60]], 12)], col, r, { hatch: 30 }); });
}
// A skull lying about.
function skull(c, r, x, y, s = 1) {
  fill(c, [...curve([[x - 36 * s, y + 20 * s], [x - 40 * s, y - 24 * s], [x, y - 44 * s], [x + 40 * s, y - 24 * s], [x + 36 * s, y + 20 * s]], 8)], "#f0e8d0", r, { hatch: 8 });
  dab(c, x - 15 * s, y - 8 * s, 9 * s, OUTLINE, 0.95); dab(c, x + 15 * s, y - 8 * s, 9 * s, OUTLINE, 0.95);
}

// --- The dungeons (bg_<key>, as gen-art-backgrounds.json describes them) ---
const DUNGEONS = {
  // Ragefire Chasm: the fiery cave under Orgrimmar - lava rivers, red rock, smoke and embers, a rope bridge.
  rfc: (c, r) => {
    sky(c, r, "#4a2220");  // the cave
    stalactites(c, r, 9, "#2e1412", 200);
    hills(c, r, 470, "#6e3226", 90, 2.5, 0.6);  // far rock
    // lava falls down the far wall
    for (const x of [230, 1010]) fill(c, [[x - 40, 300], [x + 40, 300], [x + 55, 640], [x - 55, 640]], "#ff8a2a", r, { hatch: 14 });
    ropeBridge(c, r, 300, 960, 560, 40);
    lava(c, r, 640, 790);
    fill(c, [[0, 790], ...curve([[0, 790], [S * 0.35, 760], [S * 0.7, 800], [S, 770]], 12).slice(1), [S, S], [0, S]], "#8a4a36", r);  // the rock floor
    for (const [x, y, w] of [[90, 1010, 90], [1170, 990, 110], [330, 1180, 70], [960, 1200, 80]]) rock(c, r, x, y, w, "#a0604a");
    brazier(c, r, 130, 900); brazier(c, r, 1130, 880);
    // a little lava blob with a face, peeking out
    fill(c, [...curve([[560, 720], [600, 650], [660, 640], [700, 700]], 8)], "#ffb02a", r, { line: 12, hatch: 10 });
    dab(c, 615, 685, 8, OUTLINE, 0.9); dab(c, 655, 682, 8, OUTLINE, 0.9);
    embers(c, r, 30, 120, 760);
  },
  // Wailing Caverns: a green cave with glowing roots, misty pools, giant mushrooms and vines.
  wc: (c, r) => {
    sky(c, r, "#1f3a2a");
    stalactites(c, r, 8, "#142a1c", 170);
    hills(c, r, 520, "#2f5a3a", 70, 2, 1.2);
    for (const pts of [[[-20, 120], [160, 260], [120, 520]], [[1280, 160], [1080, 300], [1150, 560]]]) line(c, curve(pts, 12), 40, "#7a5a36", r);  // big roots
    vines(c, r, [380, 560, 760, 940]);
    water(c, r, 680, "#3fb8a0", "#c8fff0", 7);
    floor(c, r, 860, "#4a6a3a");
    mushroom(c, r, 150, 980, 260, "#e8a03a"); mushroom(c, r, 1110, 960, 320, "#c86ae0", 1.15);
    // a little green snake in the pool, saying hi
    line(c, curve([[520, 760], [560, 720], [610, 760], [660, 720], [700, 740]], 8), 26, "#7ad65a", r);
    fill(c, ellipse(712, 732, 34, 24), "#7ad65a", r, { line: 10, hatch: 8 }); dab(c, 720, 724, 7, OUTLINE, 0.95);
    for (let i = 0; i < 22; i++) dab(c, 40 + r() * (S - 80), 80 + r() * 640, 8, hex("#c8ff7a"), 0.95);  // glowing spores
  },
  // The Deadmines: a cave cove with the Defias pirate ship, mine scaffolding and rails, lanterns, crates and powder barrels.
  dm: (c, r) => {
    sky(c, r, "#3a2a24");
    stalactites(c, r, 8, "#241814", 160);
    water(c, r, 560, "#2a8aa8", "#bff0ff", 6);
    // the ship: a hull, two masts, red sails, a skull flag
    fill(c, [[640, 470], [1230, 470], [1160, 600], [700, 600]], "#7a4a26", r);
    for (let k = 0; k < 6; k++) fill(c, circle(740 + k * 75, 520, 14), "#2a1a12", r, { line: 6, hatch: 6 });  // portholes
    for (const x of [820, 1040]) {
      line(c, [[x, 470], [x, 130]], 16, "#3a2a20", r);
      fill(c, [[x - 110, 170], [x + 110, 180], [x + 95, 410], [x - 95, 400]], "#d8402e", r, { hatch: 16 });
    }
    fill(c, rect(1000, 90, 1080, 135), "#2a2020", r, { line: 10 }); dab(c, 1040, 112, 10, hex("#ffffff"), 0.95);
    // scaffolding on the left, a mine cart on its rail
    for (const x of [60, 260]) line(c, [[x, 120], [x, 760]], 30, "#8a5a2e", r);
    for (const y of [260, 480]) line(c, [[30, y], [300, y]], 26, "#8a5a2e", r);
    line(c, [[40, 270], [250, 470]], 16, "#6a4026", r);
    line(c, [[0, 470], [330, 470]], 10, "#5a5058", r);
    fill(c, [[120, 400], [260, 400], [240, 465], [140, 465]], "#7a7a8a", r, { hatch: 12 });
    for (const x of [150, 230]) fill(c, circle(x, 470, 16), "#3a3236", r, { line: 8, hatch: 6 });
    lantern(c, r, 160, 180, 60); lantern(c, r, 580, 200, 200);
    // the dock, and cargo
    fill(c, rect(0, 800, S, S), "#a0703a", r);
    for (let x = 0; x < S; x += 140) line(c, [[x, 810], [x + 30, S]], 8, "#6a4026", r);
    crate(c, r, 110, 960, 150); crate(c, r, 150, 820, 110);
    barrel(c, r, 1150, 980, 70, "#d8402e"); barrel(c, r, 1010, 1010, 60);
    line(c, curve([[1150, 840], [1180, 800], [1170, 770]], 6), 8, "#3a3236", r); dab(c, 1170, 765, 14, hex("#ffd23f"), 0.95);  // a lit fuse!
  },
  // Shadowfang Keep: a dark castle courtyard at night, a full moon, torches, gargoyles and mist.
  sfk: (c, r) => {
    sky(c, r, "#22243e");
    fill(c, circle(940, 200, 120), "#fff2a8", r);  // the full moon
    cloud(c, r, 260, 170, 150, "#4a4e6a"); cloud(c, r, 1130, 330, 110, "#4a4e6a");
    bat(c, r, 760, 120, 1); bat(c, r, 640, 220, 0.7);
    tower(c, r, 130, 820, 220, 560, "#6a6a7a", "#3a3a5a");
    tower(c, r, 1130, 820, 220, 600, "#6a6a7a", "#3a3a5a");
    fill(c, rect(240, 420, 1020, 820), "#5a5a6a", r);  // the far wall
    for (let i = 0; i < 9; i++) fill(c, rect(250 + i * 88, 380, 300 + i * 88, 424), "#5a5a6a", r, { hatch: 12 });
    // a gargoyle on the left tower: a grey lump with horns and a grin
    fill(c, [...curve([[70, 280], [90, 210], [130, 190], [170, 210], [190, 280]], 8)], "#8a8a9a", r, { hatch: 10 });
    for (const dx of [-30, 30]) fill(c, [[130 + dx - 10, 205], [130 + dx * 1.6, 160], [130 + dx + 10, 210]], "#8a8a9a", r, { line: 8, hatch: 6 });
    dab(c, 115, 235, 7, hex("#ffd23f"), 0.95); dab(c, 145, 235, 7, hex("#ffd23f"), 0.95);
    torch(c, r, 330, 640); torch(c, r, 930, 640);
    floor(c, r, 820, "#7a7a88", 10);
    for (let y = 860; y < S; y += 90) line(c, [[0, y], [S, y + 10]], 6, "#5a5a68", r);
    mist(c, r, 820, 7);
  },
  // Blackfathom Deeps: sunken night elf ruins under deep blue water, broken pillars, a glowing moonwell, seaweed, shells.
  bfd: (c, r) => {
    skyBands(c, r, ["#2a5aa0", "#1e4682", "#16305a"]);
    for (const x of [300, 640, 980]) soft(c, [[x - 40, -10], [x + 40, -10], [x + 160, 800], [x + 60, 800]], "#4a7ac0", r, { hatch: 40 });  // light from above
    pillar(c, r, 150, 820, 520, "#9a8ac8"); pillar(c, r, 1100, 820, 420, "#9a8ac8", true);
    fill(c, [[300, 560], ...curve([[300, 560], [380, 380], [520, 360], [560, 420]], 10).slice(1), [560, 470], [360, 600]], "#9a8ac8", r);  // a broken arch
    floor(c, r, 820, "#4a5a8a");
    // the moonwell: a ring of stone round glowing water
    fill(c, ellipse(1000, 900, 150, 50), "#b8b0d8", r); fill(c, ellipse(1000, 896, 112, 32), "#7aeaff", r, { hatch: 10 });
    dab(c, 1000, 880, 120, hex("#bff7ff"), 0.2);
    for (const [x, h] of [[60, 260], [330, 200], [1200, 240], [800, 160]]) seaweed(c, r, x, 1000, h);
    for (const [x, y] of [[260, 1060], [700, 1120]]) fill(c, [...curve([[x - 40, y], [x - 30, y - 40], [x, y - 50], [x + 30, y - 40], [x + 40, y]], 8)], "#f0b0c0", r, { hatch: 8 });  // shells
    fill(c, star(980, 1120, 46, 20), "#ff8a5a", r, { line: 10, hatch: 8 });  // a starfish
    // a little fish
    fill(c, ellipse(560, 260, 60, 30), "#ffb02a", r, { line: 10, hatch: 8 }); fill(c, [[500, 260], [460, 230], [460, 290]], "#ffb02a", r, { line: 10, hatch: 8 });
    dab(c, 590, 252, 7, OUTLINE, 0.95);
    bubbles(c, r, 16);
  },
  // The Stockade: grey stone corridors, iron-barred cells, chains on the walls, flickering torches, straw on the floor.
  stocks: (c, r) => {
    sky(c, r, "#5a5a64");
    for (let y = 60; y < 840; y += 80) for (let x = (y / 80) % 2 ? 0 : 70; x < S; x += 140) line(c, [[x, y], [x, y + 80]], 6, "#46464e", r);  // bricks
    for (let y = 60; y < 840; y += 80) line(c, [[0, y], [S, y]], 6, "#46464e", r);
    bars(c, r, 30, 300, 300, 820); bars(c, r, 954, 300, 1224, 820);
    // someone's in that cell: two eyes in the dark
    dab(c, 1060, 560, 9, hex("#ffd23f"), 0.95); dab(c, 1100, 560, 9, hex("#ffd23f"), 0.95);
    chain(c, r, 420, 0, 330); chain(c, r, 840, 0, 260);
    torch(c, r, 380, 520); torch(c, r, 880, 520);
    floor(c, r, 830, "#7a7480", 10);
    for (let i = 0; i < 40; i++) { const x = r() * S, y = 860 + r() * 360; line(c, [[x, y], [x + 30 + r() * 30, y - 10 + r() * 20]], 7, "#e8c860", r); }  // straw
    // a mouse
    fill(c, ellipse(220, 1000, 50, 30), "#9a9aa4", r, { line: 10, hatch: 8 }); fill(c, circle(180, 980, 16), "#e8b0c0", r, { line: 8, hatch: 6 });
    line(c, curve([[270, 1005], [310, 990], [330, 1020]], 6), 6, "#9a9aa4", r); dab(c, 196, 996, 6, OUTLINE, 0.95);
  },
  // Gnomeregan: big gears and pipes, steam, leaking green goo, metal walkways and blinking lights.
  gnomer: (c, r) => {
    sky(c, r, "#2a3a4a");
    gear(c, r, 170, 240, 150, "#b0a070"); gear(c, r, 1090, 180, 120, "#9aa0a8"); gear(c, r, 960, 420, 80, "#b0a070");
    pipe(c, r, [[-20, 560], [300, 560], [300, 340], [520, 340]]);
    pipe(c, r, [[1270, 640], [1010, 640], [1010, 760]], "#8a9a7a");
    for (const [x, y] of [[520, 300], [600, 250], [690, 280]]) cloud(c, r, x, y, 60, "#e8eef4");  // steam
    // a walkway with railings
    fill(c, rect(0, 800, S, S), "#6a7a8a", r);
    for (let x = 0; x < S; x += 70) line(c, [[x, 810], [x, S]], 6, "#5a6a7a", r);
    for (let y = 860; y < S; y += 70) line(c, [[0, y], [S, y]], 6, "#5a6a7a", r);
    line(c, [[0, 720], [S, 720]], 12, "#9aa0a8", r);
    for (let x = 40; x < S; x += 160) line(c, [[x, 720], [x, 800]], 10, "#9aa0a8", r);
    // leaking green goo
    fill(c, [...curve([[970, 900], [1040, 860], [1150, 870], [1220, 920], [1130, 960], [1010, 950]], 10)], "#7aff4a", r, { hatch: 12 });
    for (const x of [1020, 1000]) fill(c, ellipse(x, 800 + (x - 1000) * 3, 12, 20), "#7aff4a", r, { line: 8, hatch: 6 });
    dab(c, 1090, 910, 120, hex("#bfff9a"), 0.2);
    for (let i = 0; i < 12; i++) dab(c, 40 + r() * (S - 80), 60 + r() * 600, 11, hex(["#ff4a4a", "#7aff4a", "#ffd23f"][i % 3]), 0.95);  // blinking lights
  },
  // Razorfen Kraul: a maze of huge thorny brambles, quilboar huts and bone totems, dusty orange light.
  rfk: (c, r) => {
    skyBands(c, r, ["#f0b070", "#e8a060", "#e09050"]);
    fill(c, circle(640, 180, 90), "#fff0b0", r, { hatch: 14 });  // a dusty sun
    floor(c, r, 760, "#c08050");
    bramble(c, r, [[-40, 300], [200, 360], [120, 640], [300, 820]]);
    bramble(c, r, [[1300, 260], [1060, 380], [1150, 620], [960, 820]]);
    bramble(c, r, [[200, 120], [420, 220], [560, 140], [760, 240], [1000, 120]], "#6a7a2a");
    hut(c, r, 170, 900, 170);
    totem(c, r, 1110, 960, 330);
    for (let i = 0; i < 18; i++) dab(c, r() * S, 860 + r() * 360, 8, hex("#9a6038"), 0.8);  // pebbles
  },
  // Scarlet Monastery Graveyard at dusk: crooked tombstones and crypts, dead trees, red banners, ghostly fog and candles.
  smgy: (c, r) => {
    skyBands(c, r, ["#5a3a6a", "#8a4a6a", "#d8705a"]);
    fill(c, circle(1050, 330, 80), "#ffd090", r, { hatch: 14 });  // the low sun
    hills(c, r, 600, "#3a3a4a", 40, 1.5);
    fill(c, rect(820, 380, 1080, 640), "#6a6070", r);  // a crypt
    fill(c, [[800, 380], [950, 270], [1100, 380]], "#4a4050", r);
    fill(c, [...curve([[910, 640], [910, 520], [950, 490], [990, 520], [990, 640]], 8)], "#2a2030", r, { hatch: 8 });
    banner(c, r, 870, 420, 60, 160, "#c8282e"); banner(c, r, 1030, 420, 60, 160, "#c8282e");
    deadTree(c, r, 160, 760, 420);
    floor(c, r, 760, "#4a5a3a");
    tombstone(c, r, 260, 900, 60, -14); tombstone(c, r, 1040, 920, 70, 12); tombstone(c, r, 1180, 1060, 55, -8); tombstone(c, r, 120, 1080, 65, 10);
    candle(c, r, 360, 960, 70); candle(c, r, 920, 980, 90);
    mist(c, r, 800, 8, "#c8c8e0");
    // a little ghost peeking out from behind a stone
    fill(c, [...curve([[1110, 880], [1100, 790], [1140, 760], [1180, 790], [1170, 880]], 8), [1155, 860], [1140, 885], [1125, 860]], "#eef4ff", r, { hatch: 10 });
    dab(c, 1128, 800, 7, OUTLINE, 0.95); dab(c, 1152, 800, 7, OUTLINE, 0.95);
  },
  // Scarlet Monastery Library: tall bookshelves full of tomes, red carpets and banners, candelabras and reading desks.
  smlib: (c, r) => {
    sky(c, r, "#6a3a2e");
    bookshelf(c, r, 0, 120, 300, 780); bookshelf(c, r, 954, 120, S, 780);
    banner(c, r, 470, 80, 90, 280, "#c8282e"); banner(c, r, 780, 80, 90, 280, "#c8282e");
    stainedGlass(c, r, 627, 140, 150, 330);
    floor(c, r, 780, "#8a5a3a", 6);
    fill(c, [[460, 780], [800, 780], [1000, S], [260, S]], "#c8282e", r, { hatch: 16 });  // the red carpet
    for (const x of [110, 1150]) { fill(c, rect(x - 90, 900, x + 90, 940), "#7a4a26", r); line(c, [[x - 70, 940], [x - 70, 1060]], 14, "#5a3418", r); line(c, [[x + 70, 940], [x + 70, 1060]], 14, "#5a3418", r);
      fill(c, [[x - 60, 900], [x, 870], [x + 60, 900]], "#f0e8d0", r, { line: 8, hatch: 8 }); }  // reading desks with open books
    for (const x of [380, 880]) { line(c, [[x, 1000], [x, 820]], 12, "#c8a040", r); line(c, [[x - 60, 860], [x + 60, 860]], 10, "#c8a040", r); for (const dx of [-60, 0, 60]) candle(c, r, x + dx, 860, 50); }
    // a book flying off the shelf
    fill(c, [[560, 560], [640, 530], [720, 560], [720, 600], [640, 575], [560, 600]], "#4f86e8", r, { line: 10, hatch: 8 });
  },
  // Scarlet Monastery Armory: racks of swords and shields, red and gold banners, a training yard with dummies.
  smarm: (c, r) => {
    sky(c, r, "#7a6a6a");
    for (let y = 60; y < 700; y += 90) line(c, [[0, y], [S, y]], 6, "#6a5a5a", r);
    banner(c, r, 200, 60, 110, 330, "#c8282e"); banner(c, r, 1054, 60, 110, 330, "#c8282e");
    banner(c, r, 627, 40, 140, 300, "#ffd23f", "#c8282e");
    for (const [x, y] of [[420, 330], [840, 330]]) { fill(c, [...curve([[x - 60, y - 60], [x + 60, y - 60], [x + 60, y + 10], [x, y + 80], [x - 60, y + 10]], 8)], "#c8282e", r); fill(c, circle(x, y, 22), "#ffd23f", r, { line: 8, hatch: 8 }); }  // shields
    floor(c, r, 720, "#b89a6a", 8);
    swordRack(c, r, 150, 860); swordRack(c, r, 1100, 860);
    dummy(c, r, 330, 1080); dummy(c, r, 950, 1100);
    for (let i = 0; i < 14; i++) dab(c, r() * S, 760 + r() * 460, 8, hex("#9a7a4a"), 0.8);
  },
  // Scarlet Monastery Cathedral: a grand hall, tall stained-glass windows, red banners, golden candlesticks and pews.
  smcath: (c, r) => {
    sky(c, r, "#8a6a6a");
    for (const x of [180, 627, 1074]) stainedGlass(c, r, x, 120, x === 627 ? 220 : 150, x === 627 ? 420 : 360);
    for (const x of [380, 874]) banner(c, r, x, 60, 90, 300, "#c8282e");
    floor(c, r, 700, "#c8b8a0", 6);
    for (let y = 760; y < S; y += 90) line(c, [[0, y], [S, y]], 6, "#a89880", r);
    fill(c, [[520, 700], [734, 700], [860, S], [394, S]], "#c8282e", r, { hatch: 16 });
    for (const y of [800, 960, 1120]) { fill(c, rect(20, y, 330, y + 50), "#7a4a26", r, { hatch: 10 }); fill(c, rect(924, y, 1234, y + 50), "#7a4a26", r, { hatch: 10 }); }  // pews
    for (const x of [470, 784]) { line(c, [[x, 760], [x, 600]], 14, "#ffd23f", r); candle(c, r, x, 600, 60); }
    dab(c, 627, 300, 260, hex("#fff0b0"), 0.18);  // holy light
  },
  // Razorfen Downs: bramble mounds overgrown with death, bones and skulls, cold blue frosty light.
  rfd: (c, r) => {
    skyBands(c, r, ["#3a4a6a", "#4a5a7a", "#6a7a9a"]);
    fill(c, circle(620, 160, 70), "#d8f0ff", r, { hatch: 14 });  // a cold moon
    floor(c, r, 760, "#7a8a9a");
    bramble(c, r, [[-40, 340], [180, 420], [120, 700], [300, 830]], "#4a5a5a");
    bramble(c, r, [[1300, 300], [1080, 420], [1160, 660], [980, 830]], "#4a5a5a");
    totem(c, r, 160, 980, 300);
    for (const [x, y] of [[1050, 980], [420, 1120], [880, 1180]]) {  // bones and a skull
      line(c, [[x - 50, y], [x + 50, y - 10]], 14, "#f0e8d0", r);
      fill(c, [...curve([[x + 40, y - 30], [x + 36, y - 70], [x + 70, y - 90], [x + 104, y - 70], [x + 100, y - 30]], 8)], "#f0e8d0", r, { hatch: 8 });
      dab(c, x + 60, y - 60, 8, OUTLINE, 0.95); dab(c, x + 84, y - 60, 8, OUTLINE, 0.95);
    }
    for (let i = 0; i < 26; i++) fill(c, star(r() * S, 60 + r() * 700, 14, 6), "#e8f8ff", r, { line: 6, hatch: 4 });  // frost sparkles
  },
  // Uldaman: an ancient titan vault of carved stone, huge titan statues, dwarven dig scaffolding, glowing blue runes.
  ulda: (c, r) => {
    sky(c, r, "#6a6058");
    statue(c, r, 170, 760, 620, "#9a948a", false); statue(c, r, 1084, 760, 620, "#9a948a", false);
    fill(c, rect(380, 200, 874, 700), "#8a8278", r);  // the vault door
    for (const [x, y] of [[480, 300], [627, 260], [774, 300], [530, 480], [724, 480], [627, 600]]) fill(c, circle(x, y, 26), "#5ad8ff", r, { line: 8, hatch: 8 });  // runes
    dab(c, 627, 440, 220, hex("#5ad8ff"), 0.15);
    for (const x of [340, 914]) line(c, [[x, 160], [x, 760]], 24, "#a8743e", r);  // dig scaffolding
    line(c, [[330, 420], [924, 420]], 20, "#a8743e", r);
    floor(c, r, 760, "#a89a80");
    mineCart(c, r, 1040, 1040, "#c8a060");
    lantern(c, r, 300, 600, 100);
    for (let i = 0; i < 12; i++) dab(c, r() * S, 800 + r() * 400, 10, hex("#8a7a60"), 0.8);
  },
  // Zul'Farrak: a sandy desert troll city, stepped temple pyramids, palm trees, sandstone ruins, tiki torches, a hot sun.
  zf: (c, r) => {
    skyBands(c, r, ["#5ab8f0", "#8ad0f0", "#f0e0a0"]);
    sun(c, r, 1080, 200, 100);
    pyramid(c, r, 627, 620, 640, 400, "#d8b070", 5);
    pyramid(c, r, 160, 640, 300, 200, "#c8a060", 3);
    floor(c, r, 620, "#f0d090", 30);
    palm(c, r, 1100, 900, 420, -1); palm(c, r, 120, 960, 380, 1);
    for (const x of [300, 954]) { line(c, [[x, 1000], [x, 760]], 16, "#8a5a2e", r); fill(c, [[x - 30, 760], [x, 680], [x + 30, 760]], "#ff8a2a", r, { line: 8, hatch: 8 }); }  // tiki torches
    for (const [x, y] of [[420, 1100], [820, 1150]]) fill(c, rect(x - 70, y - 50, x + 70, y), "#d8b070", r);  // ruins
    // a little scorpid in the sand
    fill(c, ellipse(980, 1120, 50, 26), "#c8502e", r, { line: 10, hatch: 8 });
    line(c, curve([[1020, 1110], [1070, 1060], [1050, 1020]], 6), 12, "#c8502e", r);
  },
  // Maraudon: a vast cave with glowing purple crystals, a waterfall, lush green ferns and vines, earthy rocks and pools.
  mara: (c, r) => {
    sky(c, r, "#3a2a3a");
    stalactites(c, r, 7, "#24182a", 170);
    hills(c, r, 520, "#5a4a3a", 60, 2);
    waterfall(c, r, 980, 100, 680, 110);
    water(c, r, 680, "#4ab0c8", "#d0f8ff", 5);
    floor(c, r, 820, "#6a5a3a");
    crystal(c, r, 160, 900, 300, "#b07aff", 3); crystal(c, r, 1130, 980, 220, "#d07aff", 3);
    vines(c, r, [280, 520, 720]);
    for (const [x, y] of [[360, 1000], [880, 1060]]) for (let k = 0; k < 5; k++) line(c, curve([[x, y], [x + (k - 2) * 40, y - 60], [x + (k - 2) * 70, y - 100]], 6), 12, "#5bb43a", r);  // ferns
    for (let i = 0; i < 16; i++) dab(c, 40 + r() * (S - 80), 100 + r() * 600, 8, hex("#e0b0ff"), 0.95);
  },
  // The Hall of Thanes: an ancient underground dwarven hall, old Ironforge carved from the rock - statues of thanes,
  // pillars and arches, a great forge.
  thanes: (c, r) => {
    sky(c, r, "#4a3a34");
    for (const x of [0, 627, S]) fill(c, [...curve([[x - 200, 700], [x - 200, 200], [x, 60], [x + 200, 200], [x + 200, 700]], 12)], "#5a4a40", r, { outline: null, hatch: 30 });  // arches
    statue(c, r, 170, 760, 600); statue(c, r, 1084, 760, 600);
    forge(c, r, 627, 700, 300);
    banner(c, r, 400, 60, 80, 260, "#4f86e8"); banner(c, r, 854, 60, 80, 260, "#4f86e8");
    floor(c, r, 760, "#8a7a6a", 6);
    for (let y = 820; y < S; y += 100) line(c, [[0, y], [S, y]], 6, "#6a5a4a", r);
    anvil(c, r, 360, 960); brazier(c, r, 1000, 980);
  },
  // The ruins of Lordaeron at dusk: the broken white throne room, crumbled pillars, dead vines and green plague mist.
  ruins: (c, r) => {
    skyBands(c, r, ["#5a3a7a", "#a85a7a", "#f0a060"]);
    fill(c, circle(1060, 420, 70), "#ffd090", r, { hatch: 14 });
    pillar(c, r, 150, 780, 560, "#f0ece0"); pillar(c, r, 1100, 780, 380, "#f0ece0", true); pillar(c, r, 380, 780, 300, "#f0ece0", true);
    // the throne up some steps
    for (let k = 0; k < 3; k++) fill(c, rect(500 - k * 40, 700 - k * 50 + 50, 754 + k * 40, 700 - k * 50 + 100), "#e0dcd0", r, { hatch: 12 });
    fill(c, rect(560, 420, 694, 650), "#e0dcd0", r); fill(c, rect(580, 440, 674, 600), "#4a4a8a", r, { hatch: 10 });
    floor(c, r, 800, "#c8c0b0", 10);
    vines(c, r, [140, 1110], "#6a5a3a");
    mist(c, r, 820, 9, "#a8f0a0");
    for (const [x, y] of [[300, 1100], [980, 1060]]) fill(c, rect(x - 60, y - 40, x + 60, y), "#e0dcd0", r);  // rubble
  },
  // An excavation dig site in the misty, rainy Wetlands: wooden scaffolding, mine carts, unearthed old stones, lanterns.
  excav: (c, r) => {
    skyBands(c, r, ["#7a8a8a", "#8a9a98", "#9aa8a4"]);
    hills(c, r, 560, "#5a7a5a", 60, 1.5);
    for (const x of [120, 320]) line(c, [[x, 220], [x, 780]], 26, "#8a5a2e", r);  // scaffolding
    for (const y of [360, 560]) line(c, [[90, y], [350, y]], 22, "#8a5a2e", r);
    line(c, [[110, 370], [330, 550]], 14, "#6a4026", r);
    for (const [x, h] of [[900, 300], [1040, 380], [1170, 260]]) fill(c, [[x - 50, 780], [x - 40, 780 - h], [x, 780 - h - 30], [x + 40, 780 - h], [x + 50, 780]], "#9a9a8a", r);  // unearthed standing stones
    floor(c, r, 780, "#7a6a4a");
    mineCart(c, r, 300, 980, "#9a8a6a");
    lantern(c, r, 560, 420, 160); lantern(c, r, 760, 360, 100);
    for (let i = 0; i < 6; i++) fill(c, ellipse(r() * S, 900 + r() * 300, 60 + r() * 40, 16), "#8ab0c8", r, { line: 8, hatch: 8 });  // puddles
    rain(c, r, 60);
    mist(c, r, 600, 5, "#e0e8e8");
  },
  // The Sunken Temple: a troll temple half-sunk in a green swamp lake, dragon statues, vines, glowing green water.
  st: (c, r) => {
    skyBands(c, r, ["#4a6a4a", "#6a8a5a", "#8aa86a"]);
    pyramid(c, r, 627, 600, 620, 420, "#8a9a7a", 4);
    water(c, r, 560, "#4aa86a", "#c8ffb0", 8);
    dab(c, 627, 760, 300, hex("#7aff9a"), 0.15);
    // dragon statues: a long neck up out of the water, a head with a horn
    for (const [x, d] of [[170, 1], [1084, -1]]) {
      line(c, curve([[x, 900], [x + 20 * d, 700], [x - 20 * d, 520], [x + 40 * d, 440]], 10), 60, "#7a8a6a", r);
      fill(c, ellipse(x + 70 * d, 430, 70, 40), "#7a8a6a", r); fill(c, [[x + 40 * d, 400], [x + 10 * d, 330], [x + 70 * d, 395]], "#5a6a4a", r, { line: 8, hatch: 6 });
      dab(c, x + 80 * d, 420, 9, hex("#ff4a4a"), 0.95);
    }
    vines(c, r, [380, 880]);
    fill(c, ellipse(400, 1080, 90, 30), "#5bb43a", r, { line: 10, hatch: 8 }); fill(c, ellipse(900, 1000, 70, 24), "#5bb43a", r, { line: 10, hatch: 8 });  // lily pads
    // a frog on the pad
    fill(c, [...curve([[860, 1000], [870, 960], [900, 950], [930, 960], [940, 1000]], 8)], "#7ad65a", r, { line: 10, hatch: 8 }); dab(c, 885, 965, 7, OUTLINE, 0.95); dab(c, 915, 965, 7, OUTLINE, 0.95);
  },
  // Blackrock Depths: the Dark Iron city in the mountain, huge forges, rivers of lava, iron bridges, the Grim Guzzler's glow.
  brd: (c, r) => {
    sky(c, r, "#2e2424");
    stalactites(c, r, 8, "#1c1414", 160);
    forge(c, r, 180, 700, 320); forge(c, r, 1074, 700, 300);
    lava(c, r, 700, 800);
    line(c, [[0, 640], [S, 640]], 22, "#5a5a68", r);  // an iron bridge
    for (let x = 30; x < S; x += 90) line(c, [[x, 640], [x + 45, 600]], 10, "#5a5a68", r);
    line(c, [[0, 600], [S, 600]], 12, "#5a5a68", r);
    // the Grim Guzzler: a tavern door with a mug sign
    fill(c, rect(480, 360, 774, 600), "#6a4a3a", r); fill(c, [...curve([[560, 600], [560, 470], [627, 430], [694, 470], [694, 600]], 8)], "#ffd23f", r, { hatch: 10 });
    fill(c, rect(600, 280, 660, 350), "#c8944e", r, { line: 10, hatch: 8 }); fill(c, rect(596, 268, 664, 290), "#ffffff", r, { line: 8, hatch: 6 });  // a mug of ale
    floor(c, r, 800, "#4a3a3a");
    anvil(c, r, 300, 1000); barrel(c, r, 1060, 1040, 70);
    embers(c, r, 26, 120, 760);
  },
  // Lower Blackrock Spire: rough black rock halls of the orc stronghold, spiked Blackrock banners, fires and lava light.
  lbrs: (c, r) => {
    sky(c, r, "#2a2222");
    hills(c, r, 300, "#3a3030", 120, 3, 0.4);
    banner(c, r, 330, 80, 120, 380, "#3a3236", "#d8402e"); banner(c, r, 924, 80, 120, 380, "#3a3236", "#d8402e");
    for (const x of [330, 924]) for (const dx of [-80, 80]) fill(c, [[x + dx - 14, 80], [x + dx, 20], [x + dx + 14, 80]], "#9aa0a8", r, { line: 8, hatch: 6 });  // spikes on the poles
    lava(c, r, 640, 720);
    floor(c, r, 720, "#4a3a36");
    brazier(c, r, 150, 980); brazier(c, r, 1100, 980);
    for (const [x, y] of [[450, 1060], [820, 1120]]) skull(c, r, x, y, 1);
    embers(c, r, 20, 120, 700);
  },
  // Upper Blackrock Spire: a black dragon's hall, dragon eggs on a rocky perch, black spiked walls, red banners, fire.
  ubrs: (c, r) => {
    sky(c, r, "#241c22");
    for (let x = 0; x < S; x += 140) fill(c, [[x, 0], [x + 70, 260 + (x % 280 ? 60 : 0)], [x + 140, 0]], "#3a2a32", r, { hatch: 16 });  // spiked walls
    banner(c, r, 627, 60, 130, 360, "#c8282e", "#2a2020");
    fill(c, [[0, 700], [80, 560], [300, 520], [380, 640], [380, 760], [0, 760]], "#4a3a40", r);  // the perch
    for (const x of [90, 180, 270]) egg(c, r, x, 600, 110);
    fill(c, [[1254, 720], [1170, 580], [960, 540], [880, 660], [880, 760], [1254, 760]], "#4a3a40", r);
    for (const x of [990, 1080, 1170]) egg(c, r, x, 610, 120, "#3a2a3a", "#ff5a2a");
    floor(c, r, 760, "#3a2e30");
    brazier(c, r, 330, 1000); brazier(c, r, 930, 1000);
    // one egg hatching: a little dragon peeking out
    egg(c, r, 627, 1120, 150, "#5a3a4a"); fill(c, ellipse(627, 990, 56, 40), "#3a2a3a", r, { line: 10, hatch: 8 }); dab(c, 610, 980, 8, hex("#ffd23f"), 0.95); dab(c, 644, 980, 8, hex("#ffd23f"), 0.95);
  },
  // Dire Maul East: overgrown night elf ruins in a dark green forest, twisted corrupted trees, glowing purple flowers.
  dme: (c, r) => {
    sky(c, r, "#1e3a2a");
    for (const x of [120, 400, 860, 1140]) deadTree(c, r, x, 700, 460 + (x % 3) * 40, "#3a2a3a");
    pillar(c, r, 300, 760, 360, "#9a8ac8", true); pillar(c, r, 980, 760, 420, "#9a8ac8");
    floor(c, r, 740, "#2f5a3a");
    for (let i = 0; i < 9; i++) flower(c, r, 60 + r() * (S - 120), 860 + r() * 260, i % 2 ? "#c86ae0" : "#9a5ac8");
    for (let i = 0; i < 18; i++) dab(c, r() * S, 120 + r() * 600, 8, hex("#e0b0ff"), 0.95);
  },
  // Dire Maul West: an elegant ruined Highborne palace, purple arcane crystals and pylons, broken marble arches.
  dmw: (c, r) => {
    skyBands(c, r, ["#3a2a6a", "#5a3a8a", "#7a5aa8"]);
    stars(c, r, 14, 300);
    for (const x of [120, 1134]) { pillar(c, r, x, 780, 520, "#e8e0f0"); }
    fill(c, [[300, 780], [300, 380], ...curve([[300, 380], [460, 220], [627, 200], [794, 220], [954, 380]], 12).slice(1), [954, 780], [880, 780], [880, 420], ...curve([[880, 420], [627, 300], [374, 420]], 10).slice(1), [374, 780]], "#d8d0e8", r);  // a great arch
    for (const x of [450, 804]) { fill(c, rect(x - 40, 600, x + 40, 780), "#b8b0c8", r); crystal(c, r, x, 600, 200, "#b07aff", 1); }  // pylons
    floor(c, r, 780, "#a898c0", 8);
    crystal(c, r, 200, 1080, 160, "#c86ae0", 3);
    for (const [x, y] of [[980, 1040], [600, 1150]]) fill(c, rect(x - 70, y - 40, x + 70, y), "#d8d0e8", r);
  },
  // Dire Maul North: an ogre-held courtyard of broken elven ruins, ogre tents and campfires, King Gordok's throne.
  dmn: (c, r) => {
    skyBands(c, r, ["#3a5a7a", "#5a7a8a", "#8a9a8a"]);
    pillar(c, r, 140, 760, 440, "#c8c0d0", true); pillar(c, r, 1110, 760, 500, "#c8c0d0");
    // the throne: a big rough chair with a club leaning on it
    fill(c, rect(500, 320, 754, 700), "#7a5a3a", r); fill(c, rect(470, 560, 784, 640), "#8a6a4a", r);
    for (const x of [490, 764]) fill(c, [[x - 20, 320], [x, 250], [x + 20, 320]], "#f0e8d0", r, { line: 8, hatch: 6 });  // tusks on the posts
    line(c, [[800, 700], [860, 460]], 34, "#8a5a2e", r); fill(c, circle(866, 440, 46), "#8a5a2e", r);
    floor(c, r, 740, "#7a8a5a");
    tent(c, r, 200, 1000, 170); tent(c, r, 1060, 1020, 160, "#a87a4a");
    for (const x of [470, 790]) { for (const a of [-0.5, 0.5]) line(c, [[x - 50, 1040], [x + 50, 1040 - a * 40]], 14, "#6a4026", r); fill(c, [[x - 40, 1030], [x - 10, 940], [x + 10, 980], [x + 40, 1030]], "#ff8a2a", r, { line: 8, hatch: 8 }); }  // campfires
  },
  // Scholomance: a dark necromancer school in a crypt, shelves of forbidden tomes, green candles, bones, a chalk circle.
  scholo: (c, r) => {
    sky(c, r, "#2a2a32");
    bookshelf(c, r, 0, 140, 280, 760); bookshelf(c, r, 974, 140, S, 760);
    for (let y = 80; y < 760; y += 90) line(c, [[280, y], [974, y]], 6, "#3a3a44", r);
    floor(c, r, 760, "#4a4a54", 6);
    // the chalk circle on the floor with a star in it
    line(c, [...ellipse(627, 1000, 300, 110), ellipse(627, 1000, 300, 110)[0]], 10, "#e8e8f0", r);
    const pts = Array.from({ length: 6 }, (_, k) => { const a = -Math.PI / 2 + k * 4 * Math.PI / 5; return [627 + Math.cos(a) * 260, 1000 + Math.sin(a) * 95]; });
    line(c, pts, 8, "#e8e8f0", r);
    for (const x of [380, 874, 520, 734]) candle(c, r, x, 840 + (x % 3) * 10, 80, "#7aff6a");
    skull(c, r, 160, 1080, 1.2); skull(c, r, 1100, 1110, 1);
    line(c, [[1050, 1180], [1150, 1170]], 14, "#f0e8d0", r);
  },
  // Stratholme, the living side: a burning human city, red Scarlet banners, cobbled streets, burning houses, embers.
  stratl: (c, r) => {
    skyBands(c, r, ["#5a2a2a", "#a84a2a", "#e88a3a"]);
    house(c, r, 160, 720, 260, 260, "#c8b090", "#8a4a3a", true); house(c, r, 1094, 720, 260, 300, "#c8b090", "#6a3a3a", true);
    house(c, r, 420, 660, 180, 200, "#b8a080", "#8a4a3a"); house(c, r, 834, 660, 180, 220, "#b8a080", "#8a4a3a", true);
    banner(c, r, 627, 120, 100, 300, "#c8282e");
    floor(c, r, 720, "#8a7a6a", 6);
    for (let y = 760; y < S; y += 70) for (let x = (y / 70) % 2 ? 0 : 50; x < S; x += 100) fill(c, ellipse(x, y, 40, 22), "#9a8a7a", r, { line: 6, hatch: 6 });  // cobbles
    embers(c, r, 40, 80, 720);
  },
  // Stratholme, the undead side: a plague-ruined city, ziggurats and Scourge banners, green fog, dead trees, purple sky.
  stratu: (c, r) => {
    skyBands(c, r, ["#3a2a5a", "#5a3a7a", "#7a5a8a"]);
    ziggurat(c, r, 300, 700, 360, 330); ziggurat(c, r, 980, 680, 320, 280);
    house(c, r, 627, 700, 160, 180, "#8a8090", "#4a3a4a");
    banner(c, r, 470, 120, 80, 260, "#3a3a5a", "#7aff9a"); banner(c, r, 784, 120, 80, 260, "#3a3a5a", "#7aff9a");
    deadTree(c, r, 120, 860, 400, "#3a2a3a"); deadTree(c, r, 1140, 880, 360, "#3a2a3a");
    floor(c, r, 760, "#5a5a6a", 8);
    mist(c, r, 760, 10, "#9aff9a");
    skull(c, r, 420, 1100, 1); skull(c, r, 900, 1150, 0.9);
  },
  // Onyxia's Lair: a vast dark volcanic cave full of dragon eggs, lava cracks glowing orange, gold and bones.
  ony: (c, r) => {
    sky(c, r, "#2a1e22");
    stalactites(c, r, 9, "#1a1214", 220);
    hills(c, r, 600, "#3a2a2e", 70, 2);
    floor(c, r, 660, "#5a3a34");
    for (let i = 0; i < 7; i++) { const x = 60 + r() * (S - 180), y = 700 + r() * 460; line(c, [[x, y], [x + 60, y + 30], [x + 40, y + 80], [x + 110, y + 110]], 14, "#ff8a2a", r); }  // lava cracks
    for (let i = 0; i < 6; i++) { const x = i < 3 ? 80 + i * 110 : 940 + (i - 3) * 110; egg(c, r, x, 880 + (i % 2) * 60, 130, "#6a3a5a", "#ffb02a"); }
    gold(c, r, 260, 1160, 200); gold(c, r, 1000, 1180, 220);
    skull(c, r, 600, 1120, 1.1);
    dab(c, 627, 420, 300, hex("#ff7a3a"), 0.08);
  },
  // The Barrow Deeps: ancient night elf barrows under Mount Hyjal, stone tombs with sleeping druids, green and blue runes, roots.
  barrow: (c, r) => {
    sky(c, r, "#1e2a2a");
    for (const pts of [[[-20, 100], [200, 260], [140, 560]], [[1280, 140], [1060, 300], [1120, 600]], [[500, -20], [560, 200], [460, 380]], [[780, -20], [740, 160], [820, 300]]]) line(c, curve(pts, 12), 34, "#5a4a36", r);  // roots
    for (const [x, y] of [[300, 300], [627, 220], [954, 300], [460, 480], [794, 480]]) { fill(c, circle(x, y, 24), (x + y) % 2 ? "#5ad8ff" : "#7aff9a", r, { line: 8, hatch: 8 }); dab(c, x, y, 60, hex("#7aff9a"), 0.12); }  // runes
    floor(c, r, 760, "#3a4a44");
    // stone tombs, a druid asleep on one (zzz)
    for (const x of [200, 1054]) { fill(c, rect(x - 150, 860, x + 150, 980), "#8a9a94", r); fill(c, rect(x - 170, 840, x + 170, 870), "#9aaaa4", r, { hatch: 10 }); }
    fill(c, ellipse(1054, 820, 110, 30), "#6a5a8a", r, { line: 10, hatch: 8 }); fill(c, circle(944, 810, 30), "#7a9ad8", r, { line: 10, hatch: 8 });
    zzz(c, r, 920, 720, 40);
    vines(c, r, [330, 920], "#4a7a4a");
  },
  // Hyjal Summit: the World Tree Nordrassil towering over snowy pine forests and green aurora light.
  hyjal: (c, r) => {
    sky(c, r, "#14243a");
    aurora(c, r, ["#3a9a6a", "#4ac88a", "#3a8aa8"]);
    stars(c, r, 16, 400);
    // the World Tree: a vast trunk and a crown of glowing leaves
    fill(c, [[540, 760], [570, 380], [500, 260], [600, 300], [627, 180], [654, 300], [754, 260], [684, 380], [714, 760]], "#7a5a3a", r);
    fill(c, [...curve([[300, 300], [360, 120], [627, 40], [894, 120], [954, 300], [800, 340], [627, 300], [454, 340]], 14)], "#5ac88a", r, { hatch: 16 });
    dab(c, 627, 200, 300, hex("#bfffd8"), 0.15);
    hills(c, r, 700, "#e8f0f8", 40, 1.5);
    for (const [x, h] of [[90, 300], [220, 240], [1040, 260], [1170, 320]]) pine(c, r, x, 820, h);
    floor(c, r, 800, "#f0f6ff", 10);
    pine(c, r, 140, 1100, 260); pine(c, r, 1120, 1120, 240);
    for (let i = 0; i < 30; i++) dab(c, r() * S, r() * 760, 6, hex("#ffffff"), 0.9);  // snowflakes
  },
};

// --- The backgrounds ---
const BACKGROUNDS = {
  // Uncommon
  "Uncommon/golf-course-at-dawn": (c, r) => {
    skyBands(c, r, ["#ffb07a", "#ffc890", "#ffe0a8"]);
    sun(c, r, 220, 340, 110);
    cloud(c, r, 900, 200, 160);
    hills(c, r, 560, "#7fd65a", 70, 1.5);
    hills(c, r, 760, "#5bb43a", 40, 2, 1);
    flag(c, r, 1080, 700);
    fill(c, ellipse(1080, 712, 60, 18), "#3a3236", r, { line: 10 });
    tree(c, r, 120, 720, 160);
    fill(c, circle(260, 900, 14), "#ffffff", r, { line: 8, hatch: 8 });  // a golf ball
  },
  "Uncommon/moonlit-fairway": (c, r) => {
    sky(c, r, "#26347a");
    stars(c, r, 26, 450);
    moon(c, r, 1040, 220, 110);
    hills(c, r, 600, "#2f6e3a", 60, 1.5, 2);
    hills(c, r, 800, "#3f8a3a", 40, 2);
    flag(c, r, 200, 760, "#ffd23f");
    tree(c, r, 1130, 800, 180, "#2f6e3a");
    for (let i = 0; i < 9; i++) dab(c, 100 + r() * 1050, 650 + r() * 300, 9, hex("#e8ff7a"), 0.9);  // fireflies
  },
  "Uncommon/hammock-between-two-trees": (c, r) => {
    skyBands(c, r, ["#ffb0a0", "#ffd090", "#fff0b0"]);
    sun(c, r, 627, 330, 100, false);
    hills(c, r, 650, "#7fd65a", 50, 1);
    tree(c, r, 140, 900, 420, "#3f9a3a", 1.4);
    tree(c, r, 1110, 900, 420, "#3f9a3a", 1.4);
    // The hammock between them, empty (the ogre's in front), with a little pillow.
    fill(c, [...curve([[170, 560], [627, 820], [1080, 560]], 20), ...curve([[1080, 600], [627, 880], [170, 600]], 20)], "#f2e2c0", r);
    for (const [x, y] of [[170, 560], [1080, 560]]) line(c, [[x, y], [x + (x < 600 ? -10 : 10), y - 120]], 12, "#8a5a2e", r);
    zzz(c, r, 980, 380, 50);
    flower(c, r, 300, 1020, "#ff7fbf"); flower(c, r, 960, 1060, "#b07ae8");
  },
  "Uncommon/clubhouse-lounge": (c, r) => {
    soft(c, ALL, "#c46a3a", r, { hatch: 34 });  // the walls
    for (let x = 80; x < S; x += 170) line(c, [[x, 0], [x, 700]], 10, "#a85530", r);  // wallpaper stripes
    fill(c, rect(0, 700, S, S), "#8a4a2a", r);  // the floor
    fill(c, rect(160, 900, 1090, 1180), "#c8302a", r);  // the rug
    for (const x of [140, 1000]) {  // windows with a night sky
      fill(c, rect(x, 140, x + 160, 420), "#26347a", r);
      line(c, [[x + 80, 140], [x + 80, 420]], 10, OUTLINE, r); line(c, [[x, 280], [x + 160, 280]], 10, OUTLINE, r);
      fill(c, star(x + 40, 190, 14, 6), "#fff6c0", r, { line: 6, hatch: 6 });
    }
    // A fireplace and a club-crest painting.
    fill(c, rect(470, 120, 790, 330), "#ffd84a", r);
    fill(c, rect(500, 150, 760, 300), "#4f86e8", r);
    fill(c, circle(630, 225, 50), "#ffd84a", r, { line: 10 });
    fill(c, rect(960, 520, 1200, 720), "#7a7a80", r);
    fill(c, rect(1000, 580, 1160, 720), "#3a2a2a", r);
    fill(c, [[1030, 720], [1060, 640], [1080, 680], [1100, 620], [1130, 720]], "#ff8a2a", r, { hatch: 12 });
  },
  "Uncommon/spa-steam-room": (c, r) => {
    soft(c, ALL, "#d8a070", r, { hatch: 34 });
    for (let y = 60; y < 700; y += 110) line(c, [[0, y], [S, y]], 10, "#b07a50", r);  // wooden planks
    fill(c, rect(0, 760, S, S), "#9aa0a8", r);  // stone floor
    for (let x = 0; x < S; x += 160) line(c, [[x, 760], [x, S]], 8, "#6a7078", r);
    fill(c, ellipse(627, 960, 520, 150), "#7fe0f0", r);  // the pool
    waves(c, r, 900, "#ffffff", 6);
    for (let i = 0; i < 7; i++) {  // steam curls
      const x = 120 + r() * 1000, y = 300 + r() * 400;
      line(c, curve([[x, y + 140], [x + 30, y + 90], [x - 20, y + 40], [x + 10, y]], 8), 18, "#ffffff", r);
    }
    for (const x of [140, 1110]) { fill(c, rect(x - 30, 380, x + 30, 470), "#ffd84a", r, { line: 10 }); dab(c, x, 425, 12, hex("#ff8a2a"), 0.9); }  // lanterns
  },
  "Uncommon/swamp-hot-spring": (c, r) => {
    skyBands(c, r, ["#b07ae8", "#e88ab0", "#ffb0a0"]);
    moon(c, r, 980, 200, 70);
    hills(c, r, 560, "#4a7a3a", 50, 2);
    fill(c, ellipse(627, 960, 600, 200), "#3fb8b0", r);  // the spring
    for (let i = 0; i < 8; i++) fill(c, circle(200 + r() * 860, 880 + r() * 160, 12 + r() * 12), "#9fe8e0", r, { line: 8, hatch: 8 });  // bubbles
    for (const x of [80, 210, 1060, 1180]) {  // reeds with cattails
      line(c, [[x, 1100], [x + 10, 640]], 14, "#3f7a2e", r);
      fill(c, ellipse(x + 10, 640, 16, 46), "#8a5a2e", r, { line: 10, hatch: 10 });
    }
    for (let i = 0; i < 6; i++) dab(c, 100 + r() * 1050, 500 + r() * 300, 9, hex("#e8ff7a"), 0.9);
  },
  // Epic
  "Epic/pool-with-floaties": (c, r) => {
    sky(c, r, "#8fd0ff");
    sun(c, r, 1080, 200, 100);
    cloud(c, r, 260, 190, 150);
    fill(c, rect(0, 560, S, S), "#f0dcb0", r);  // the tiles round the pool
    fill(c, rect(70, 640, S - 70, S - 40), "#3fa8f0", r);
    waves(c, r, 700, "#ffffff", 8);
    // Floaties: a ring, a duck.
    fill(c, circle(260, 900, 110), "#ff5f8a", r, { holes: [circle(260, 900, 55)] });
    for (let k = 0; k < 4; k++) { const a = k * Math.PI / 2; dab(c, 260 + Math.cos(a) * 82, 900 + Math.sin(a) * 82, 18, hex("#ffffff"), 0.9); }
    fill(c, ellipse(1000, 960, 120, 70), "#ffd23f", r);
    fill(c, circle(1080, 870, 52), "#ffd23f", r);
    fill(c, [[1124, 868], [1170, 880], [1124, 894]], "#ff8a2a", r, { line: 10, hatch: 8 });
    dab(c, 1092, 856, 9, OUTLINE, 0.9);
    palm(c, r, 60, 640, 420, 1);
  },
  // Legendary
  "Legendary/ancient-treasure-lounge": (c, r) => {
    soft(c, ALL, "#5a3a2a", r, { hatch: 34 });  // the cave
    for (let i = 0; i < 6; i++) {  // glowing crystals on the walls
      const x = 60 + r() * 1100, y = 80 + r() * 440, col = ["#7ff0e0", "#c08aff", "#ff7fbf"][i % 3];
      fill(c, [[x, y + 70], [x - 26, y + 20], [x, y - 60], [x + 26, y + 20]], col, r, { hatch: 10 });
    }
    fill(c, rect(0, 820, S, S), "#8a6a4a", r);
    // Piles of gold coins either side, a chest, a big ruby.
    for (const [cx, w] of [[180, 220], [1080, 230]]) {
      fill(c, [...curve([[cx - w, 1000], [cx - w * 0.5, 760], [cx, 700], [cx + w * 0.5, 760], [cx + w, 1000]], 10)], "#ffcf3a", r);
      for (let k = 0; k < 9; k++) fill(c, ellipse(cx - w * 0.6 + r() * w * 1.2, 780 + r() * 200, 22, 12), "#ffe48a", r, { line: 8, hatch: 8 });
    }
    fill(c, rect(500, 980, 760, 1150), "#a8743e", r);
    fill(c, rect(500, 960, 760, 1010), "#ffcf3a", r, { line: 12 });
    fill(c, [[1100, 1080], [1140, 1040], [1180, 1080], [1140, 1140]], "#e8463a", r, { line: 12, hatch: 10 });
    for (const x of [340, 920]) { line(c, [[x, 120], [x, 260]], 8, "#3a3236", r); fill(c, rect(x - 30, 260, x + 30, 330), "#ffd84a", r, { line: 10 }); }  // lanterns
  },
  "Legendary/dragon-over-the-fairway": (c, r) => {
    sky(c, r, "#8fd0ff");
    cloud(c, r, 200, 300, 150); cloud(c, r, 1020, 420, 120);
    hills(c, r, 640, "#7fd65a", 60, 1.5, 1);
    // The dragon flying overhead: a fat body, a bat wing with ribs, spikes, a long tail, legs, a puff of fire.
    const body = [...curve([[340, 260], [460, 190], [620, 200], [780, 170], [900, 150]], 10), ...curve([[900, 150], [880, 250], [700, 300], [500, 300], [340, 260]], 10).slice(1)];
    line(c, curve([[350, 250], [230, 300], [140, 250], [90, 180]], 10), 34, "#e8463a", r);  // the tail
    fill(c, [[70, 160], [120, 160], [95, 205]], "#e8463a", r, { line: 12, hatch: 10 });  // its tip
    fill(c, body, "#e8463a", r);
    fill(c, [[520, 220], [560, 20], [650, 90], [720, 0], [790, 110], [880, 60], [780, 220]], "#c8302a", r);  // the wing
    for (const [x, y] of [[560, 20], [720, 0], [880, 60]]) line(c, [[650, 210], [x, y]], 10, OUTLINE, r);
    for (let k = 0; k < 5; k++) fill(c, [[420 + k * 80, 200 - k * 6], [450 + k * 80, 150 - k * 6], [480 + k * 80, 196 - k * 6]], "#ffd23f", r, { line: 10, hatch: 8 });
    for (const x of [520, 700]) line(c, [[x, 290], [x - 10, 360]], 22, "#e8463a", r);  // legs
    fill(c, ellipse(970, 140, 82, 56), "#e8463a", r);  // the head
    fill(c, [[930, 92], [950, 40], [975, 90]], "#ffd23f", r, { line: 10, hatch: 8 });  // a horn
    dab(c, 985, 125, 12, hex("#ffffff"), 0.95); dab(c, 990, 128, 7, OUTLINE, 0.95);
    fill(c, [[1050, 150], [1170, 100], [1140, 150], [1220, 175], [1140, 200], [1060, 170]], "#ff9a2a", r, { hatch: 14 });
    fill(c, [[1080, 152], [1150, 135], [1130, 160]], "#ffd23f", r, { line: 8, hatch: 8 });
    flag(c, r, 1060, 760);
    tree(c, r, 140, 800, 170);
  },
  "Legendary/floating-sky-spa": (c, r) => {
    skyBands(c, r, ["#ffb0d0", "#ffd0b0", "#b0e0ff"]);
    for (const [x, y, w] of [[220, 300, 150], [1030, 260, 170], [620, 120, 120], [180, 760, 200], [1080, 800, 180]]) cloud(c, r, x, y, w);
    // Floating islands with little waterfalls.
    for (const [x, y, w] of [[260, 520, 170], [1000, 560, 190]]) {
      fill(c, [[x - w, y], [x + w, y], [x + w * 0.4, y + 120], [x, y + 170], [x - w * 0.4, y + 120]], "#a8743e", r);
      fill(c, rect(x - w, y - 30, x + w, y + 10), "#7fd65a", r, { line: 12 });
      line(c, [[x + w * 0.6, y + 10], [x + w * 0.6, y + 240]], 22, "#8fe0ff", r);
    }
    fill(c, ellipse(627, 1080, 420, 130), "#7fe0f0", r);  // the spa pool on a cloud
    waves(c, r, 1030, "#ffffff", 4);
    stars(c, r, 6, 200, "#ffffff");
  },
  "Legendary/ghost-ship-cove": (c, r) => {
    sky(c, r, "#1e2a5e");
    stars(c, r, 20, 400);
    moon(c, r, 1060, 200, 100);
    fill(c, rect(0, 640, S, S), "#2a6a8a", r);  // the sea
    waves(c, r, 680, "#7fe0f0", 8);
    // The ghost ship: a green glowing hull, masts and tattered sails, a skull flag.
    fill(c, [[700, 560], [1180, 560], [1120, 660], [760, 660]], "#3a8a6a", r);
    for (const x of [820, 960, 1080]) {
      line(c, [[x, 560], [x, 240]], 14, "#3a3236", r);
      fill(c, [[x - 70, 280], [x + 70, 290], [x + 60, 470], [x - 60, 460]], "#c8f0d8", r, { hatch: 16 });
    }
    fill(c, rect(940, 200, 1010, 245), "#3a3236", r, { line: 10 });
    dab(c, 975, 222, 9, hex("#ffffff"), 0.9);
    palm(c, r, 80, 900, 460, 1);
    fill(c, [...curve([[0, 1000], [300, 900], [520, 1000]], 10), [520, S], [0, S]], "#e8d090", r);  // a bit of beach
  },
};

const T = 300, shown = [];
for (const [key, draw] of Object.entries(DUNGEONS)) BACKGROUNDS["Dungeon/bg_" + key] = draw;
const want = Object.keys(BACKGROUNDS).filter((k) => k.includes(filter));
const crayonOgre = ["Skin/Uncommon/moss.png", "Outfit/Uncommon/striped-pajamas.png", "Expression/Uncommon/moss/smug-smile.png",
  "Eyes/Uncommon/moss/heavy-bags.png"].map((f) => Buffer.from(resample(decodePng(path.join(OUT, f)), 0, 0, S, S, T, T)));
function over(dst, src) {
  for (let i = 0; i < dst.length; i += 4) {
    const a = src[i + 3] / 255, b = dst[i + 3] / 255, o = a + b * (1 - a);
    if (!o) continue;
    for (let k = 0; k < 3; k++) dst[i + k] = Math.round((src[i + k] * a + dst[i + k] * b * (1 - a)) / o);
    dst[i + 3] = Math.round(o * 255);
  }
}
want.forEach((key, n) => {
  const c = canvas();
  BACKGROUNDS[key](c, rng(5150 + n * 7919));
  const rgba = crayon.toRgba(c), file = key.startsWith("Dungeon/")
    ? path.join(os.homedir(), "killtracker-art-extra", "Unlocks", "generated", "crayon", key.slice(8) + ".png")
    : path.join(OUT, "Background", ...key.split("/")) + ".png";
  fs.mkdirSync(path.dirname(file), { recursive: true });
  writePng(file, S, S, rgba);
  const pic = Buffer.from(resample({ width: S, height: S, rgba }, 0, 0, S, S, T, T));
  for (const layer of crayonOgre) over(pic, layer);
  shown.push(pic);
  process.stdout.write(`\r${n + 1}/${want.length} ${key}`.padEnd(60));
});
console.log();
const cols = Math.min(4, shown.length), rows = Math.ceil(shown.length / cols), sheet = Buffer.alloc(T * cols * T * rows * 4);
shown.forEach((pic, k) => {
  const ox = (k % cols) * T, oy = Math.floor(k / cols) * T;
  for (let y = 0; y < T; y++) pic.copy(sheet, ((oy + y) * T * cols + ox) * 4, y * T * 4, (y + 1) * T * 4);
});
try { writePng(path.join(OUT, filter ? "backgrounds-" + filter.replace(/\W/g, "") + ".png" : "backgrounds.png"), T * cols, T * rows, sheet); } catch (e) { console.log("(backgrounds.png is open elsewhere - not updated)"); }
console.log(`Wrote ${want.length} crayon backgrounds to ${path.join(OUT, "Background")}`);
