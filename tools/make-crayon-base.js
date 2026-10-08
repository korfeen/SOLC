// Hand-coloured crayon skins and outfits, to go with the crayon eyes and mouths (tools/make-crayon-items.js):
//   Skins: every skin redrawn in crayon on the painted skin's own outline, in the same colour the crayon eyes and
//     mouths use for that skin (so a face's patch blends in), with the same simple features (nose, ears, chest, belly,
//     loincloth); the legendary skins get a little extra each (stars, embers, sparkle, runes, barnacles).
//   Outfits: each coloured in on its own outline by its real colours, grouped by hue (not brightness, so the painted
//     shading doesn't break it into bands), every colour area hatched in one flat crayon colour and outlined; then
//     hand-drawn details (stars, moons, dragon scales, tweed, the club crest).
// Writes into %USERPROFILE%\killtracker-art-extra\CrayonHand\Skin and \Outfit (the original's path), and
// base.png: the originals above their crayon versions.
// Usage: node tools/make-crayon-base.js [filter]   No dependencies.

const fs = require("fs");
const os = require("os");
const path = require("path");
const crayon = require("./make-role-icons");
const { decodePng, resample } = require("./convert-art");

const SIZE = 1254;
crayon.setSize(SIZE);
const { canvas, dab, stroke, crayonShape, circle, ellipse, star, quad, hex, OUTLINE, rng, writePng } = crayon;
const ART = path.join(os.homedir(), "killtracker-art");
const OUT = path.join(os.homedir(), "killtracker-art-extra", "CrayonHand");
const filter = (process.argv[2] || "").split("/").join(path.sep);

const HATCH = 20, LINE = 16;
const fill = (c, poly, color, r, o = {}) => crayonShape(c, poly, color, r, { fit: true, line: LINE, hatch: HATCH, ...o });
const line = (c, pts, width, color, r) => stroke(c, pts, width, color, 0.95, r);
const curve = (pts, n = 12) => pts.slice(1).flatMap((p, i) => quad(pts[i], [(pts[i][0] + p[0]) / 2, (pts[i][1] + p[1]) / 2], p, n).slice(i ? 1 : 0));

// The skin colours: the same as the crayon eyes and mouths (tools/make-crayon-items.js SKINS, brightened alike).
const SKINS = {
  "celestial-blue": [66, 72, 107], "enchanted-jade": [112, 119, 58], gold: [182, 131, 40], "obsidian-ember": [92, 56, 43],
  "sea-cursed-teal": [70, 114, 104], "pale-lavender": [164, 127, 155], "slate-gray": [106, 101, 102], "sunburnt-red": [182, 67, 54],
  moss: [136, 107, 43], "mud-brown": [125, 82, 47], "swamp-green": [104, 94, 48],
};
const skinCrayon = (rgb) => rgb.map((v) => Math.min(255, v * 1.18 + 10));

// --- Masks and filling by mask ---
function load(rel) { return decodePng(path.join(ART, rel)); }
function maskOf(image, threshold = 128) {
  const m = new Uint8Array(SIZE * SIZE);
  for (let i = 0; i < SIZE * SIZE; i++) m[i] = image.rgba[i * 4 + 3] > threshold ? 1 : 0;
  return m;
}
const at = (m, x, y) => x >= 0 && y >= 0 && x < SIZE && y < SIZE && m[Math.floor(y) * SIZE + Math.floor(x)] === 1;
function hatchWhere(c, test, color, r, { hatch = HATCH, angle = 0.6 } = {}) {
  for (const [a, strength] of [[angle, 0.8], [angle + 1.2, 0.5]]) {
    const dx = Math.cos(a), dy = Math.sin(a), nx = -dy, ny = dx, reach = SIZE * 0.75;
    for (let offset = -reach; offset <= reach; offset += hatch * 0.8) {
      const shade = 0.9 + r() * 0.18, tone = color.map((v) => Math.min(255, v * shade));
      let run = [];
      for (let t = -reach; t <= reach; t += 3) {
        const x = SIZE / 2 + nx * offset + dx * t, y = SIZE / 2 + ny * offset + dy * t;
        if (test(x, y)) run.push([x, y]);
        else if (run.length) { if (run.length > 1) stroke(c, run, hatch, tone, strength, r); run = []; }
      }
      if (run.length > 1) stroke(c, run, hatch, tone, strength, r);
    }
  }
}
// A bold crayon outline along the shape's edge (as heavy as the faces' lines): solid dabs along the border, every
// couple of pixels, so the line reads solid at picture size.
function outlineWhere(c, test, width, color, r, opacity = 0.95) {
  const step = 2, probe = 3;
  for (let y = probe; y < SIZE - probe; y += step) {
    for (let x = probe; x < SIZE - probe; x += step) {
      if (!test(x, y)) continue;
      if (test(x - probe, y) && test(x + probe, y) && test(x, y - probe) && test(x, y + probe)) continue;
      dab(c, x + (r() - 0.5) * 1.5, y + (r() - 0.5) * 1.5, width / 2, color, opacity);
    }
  }
}

// --- Skins ---
const LOINCLOTH = (x, y) => y >= 1085 && x > 250 && x < 1000;
const EXTRAS = {
  "celestial-blue": (c, m, r) => { for (let i = 0; i < 40; i++) { const x = 100 + r() * 1050, y = 300 + r() * 800; if (at(m, x, y) && !LOINCLOTH(x, y)) fill(c, star(x, y, 9, 4), hex("#fff6c0"), r, { outline: null, hatch: 4 }); } },
  "obsidian-ember": (c, m, r) => { for (let i = 0; i < 14; i++) { let x = 150 + r() * 950, y = 420 + r() * 600; const pts = []; for (let k = 0; k < 5; k++) { pts.push([x, y]); x += (r() - 0.5) * 70; y += 20 + r() * 30; } if (pts.every(([px, py]) => at(m, px, py))) line(c, pts, 7, hex("#ff8a2a"), r); } },
  gold: (c, m, r) => { for (let i = 0; i < 24; i++) { const x = 100 + r() * 1050, y = 300 + r() * 800; if (at(m, x, y) && !LOINCLOTH(x, y)) fill(c, star(x, y, 11, 3), hex("#fffbe0"), r, { outline: null, hatch: 4 }); } },
  "enchanted-jade": (c, m, r) => { for (const [x, y] of [[420, 760], [840, 760], [630, 640]]) { line(c, [...circle(x, y, 26, 24), circle(x, y, 26, 24)[0]], 6, hex("#c8ff9a"), r); line(c, [[x, y - 18], [x, y + 18]], 6, hex("#c8ff9a"), r); } },
  "sea-cursed-teal": (c, m, r) => { for (let i = 0; i < 16; i++) { const x = 150 + r() * 950, y = 450 + r() * 600; if (at(m, x, y) && !LOINCLOTH(x, y)) fill(c, circle(x, y, 9 + r() * 7, 14), hex("#d8d0b8"), r, { line: 6, hatch: 5 }); } },
};
function drawSkin(c, r, rel, skin) {
  const m = maskOf(load(rel)), colour = skinCrayon(SKINS[skin]);
  hatchWhere(c, (x, y) => at(m, x, y) && !LOINCLOTH(x, y), colour, r);
  hatchWhere(c, (x, y) => at(m, x, y) && LOINCLOTH(x, y), hex("#8a5a2e"), r);
  outlineWhere(c, (x, y) => at(m, x, y), 24, OUTLINE, r);
  line(c, curve([[300, 1085], [630, 1110], [960, 1085]]), 18, OUTLINE, r);
  // The nose (the crayon eyes and mouths draw it the same, tools/make-crayon-items.js).
  fill(c, ellipse(632, 294, 52, 40), colour.map((v) => v * 0.7), r, { line: 16, hatch: 14 });
  fill(c, circle(616, 278, 11, 16), colour.map((v) => Math.min(255, v * 1.25)), r, { outline: null, hatch: 6 });
  for (const x of [614, 650]) for (let i = 0; i < 2; i++) dab(c, x, 312, 9, OUTLINE, 0.9);
  line(c, curve([[500, 205], [482, 245], [505, 290]]), 16, OUTLINE, r);  // ears
  line(c, curve([[768, 215], [788, 255], [764, 298]]), 16, OUTLINE, r);
  line(c, curve([[470, 840], [630, 900], [800, 840]]), 16, OUTLINE, r);  // chest
  line(c, curve([[440, 1010], [630, 1060], [820, 1010]]), 16, OUTLINE, r);  // belly
  dab(c, 630, 990, 11, OUTLINE, 0.9);
  if (EXTRAS[skin]) EXTRAS[skin](c, m, r);
}

// --- Outfits: colour areas by hue ---
function hueKey([r, g, b]) {  // colour without its brightness (so shading joins its colour), a little brightness kept
  const luma = 0.3 * r + 0.59 * g + 0.11 * b, k = 90 / Math.max(25, luma);
  return [r * k, g * k, b * k, luma * 0.15];
}
function kmeans(points, k, r) {
  let centres = Array.from({ length: k }, () => points[Math.floor(r() * points.length)].slice());
  const assign = new Int32Array(points.length);
  for (let round = 0; round < 12; round++) {
    const sums = centres.map(() => [0, 0, 0, 0, 0]);
    points.forEach((p, i) => {
      let best = 0, bestD = Infinity;
      centres.forEach((cc, j) => { const d = (p[0] - cc[0]) ** 2 + (p[1] - cc[1]) ** 2 + (p[2] - cc[2]) ** 2 + (p[3] - cc[3]) ** 2; if (d < bestD) { bestD = d; best = j; } });
      assign[i] = best;
      const s = sums[best]; for (let q = 0; q < 4; q++) s[q] += p[q]; s[4]++;
    });
    centres = sums.map((s, j) => (s[4] ? s.slice(0, 4).map((v) => v / s[4]) : centres[j]));
  }
  return assign;
}
const SMALL = 314, SCALE = SIZE / SMALL;
// Outfit settings: colour areas (k), and the extra hand-drawn details.
// Outfit settings: its crayon colours (each part of the outfit takes the one nearest its painted colour, by hue; a
// colour given as [colour, y] only below that height, as the trousers; one given as { like, show } is told by its
// painted look but drawn in another, for a colour's deep shadows), how much brightness counts (light: 4 by default),
// and the extra hand-drawn details.
const OUTFITS = {
  "pirate-captain-coat": { palette: ["#a8262a", { like: "#4a1416", show: "#a8262a" }, "#f2e2c0"], light: 40 },  // (its thin gold piping left out)
  "celestial-pajamas": { palette: ["#26347a", "#e8b030"], extra: "stars" },
  "dragonhide-golf-jacket": { palette: ["#b0482c", "#f0dcb0", ["#8a7a3a", 1130]], extra: "scales" },
  "royal-nap-robe": { palette: ["#6e2cb0", "#f0b830", "#f2e2c0"] },
  "blazer-with-club-crest": { palette: ["#24326e", "#f2ead8", ["#8a7a3a", 1130], "#e8b030"], light: 20, extra: "crest" },
  onesie: { palette: ["#a8cff0"], extra: "moons" },
  "tweed-vest": { palette: ["#8a5a30", "#e8d0a0"], extra: "tweed" },
  "fluffy-bathrobe": { palette: ["#f4ead2", "#2aa8a0"], extra: "fluff" },
  "golf-polo": { palette: ["#f2ead2", "#2a8a7a", ["#8a7a3a", 1130]] },
  "loincloth-and-member-sash": { palette: ["#2a5ad0"] },
  "spa-towel": { palette: ["#f4ead2"], extra: "fluff" },
  "striped-pajamas": { palette: ["#4a78c8", "#f2ead2"] },
};
function drawOutfit(c, r, rel, name) {
  const image = load(rel), m = maskOf(image);
  const settings = OUTFITS[name] || { palette: ["#c0a080"] };
  const palette = settings.palette.map((p) => hex(Array.isArray(p) ? p[0] : p.show || p));
  const matches = settings.palette.map((p) => hex(Array.isArray(p) ? p[0] : p.like || p));
  const below = settings.palette.map((p) => (Array.isArray(p) ? p[1] : 0)), light = settings.light || 4;
  const small = resample(image, 0, 0, SIZE, SIZE, SMALL, SMALL);
  const pts = [], idx = [];
  for (let i = 0; i < SMALL * SMALL; i++) if (small[i * 4 + 3] > 128) { pts.push(hueKey([small[i * 4], small[i * 4 + 1], small[i * 4 + 2]])); idx.push(i); }
  // Each pixel to the nearest palette colour by hue (brightness counts a little, to tell a dark colour from a light
  // one of the same hue).
  const keys = matches.map(hueKey);
  const assign = pts.map((p, n) => {
    const y = Math.floor(idx[n] / SMALL) * SCALE;
    let best = 0, bestD = Infinity;
    keys.forEach((q, j) => {
      if (y < below[j]) return;
      const d = (p[0] - q[0]) ** 2 + (p[1] - q[1]) ** 2 + (p[2] - q[2]) ** 2 + (p[3] - q[3]) ** 2 * light;
      if (d < bestD) { bestD = d; best = j; }
    });
    return best;
  });
  let labels = new Int16Array(SMALL * SMALL).fill(-1);
  idx.forEach((i, n) => { labels[i] = assign[n]; });
  for (let pass = 0; pass < 5; pass++) {  // smooth: 5x5 majority
    const next = labels.slice();
    for (let y = 2; y < SMALL - 2; y++) for (let x = 2; x < SMALL - 2; x++) {
      const i = y * SMALL + x;
      if (labels[i] < 0) continue;
      const votes = {};
      for (let dy = -2; dy <= 2; dy++) for (let dx = -2; dx <= 2; dx++) { const l = labels[i + dy * SMALL + dx]; if (l >= 0) votes[l] = (votes[l] || 0) + 1; }
      let best = labels[i], most = 0;
      for (const l in votes) if (votes[l] > most) { most = votes[l]; best = +l; }
      next[i] = best;
    }
    labels = next;
  }
  const labelAt = (x, y) => labels[Math.min(SMALL - 1, Math.floor(y / SCALE)) * SMALL + Math.min(SMALL - 1, Math.floor(x / SCALE))];
  const colours = palette;
  const inside = (x, y) => at(m, x, y);
  for (let j = 0; j < colours.length; j++) {
    if (colours[j].some(Number.isNaN)) continue;
    hatchWhere(c, (x, y) => inside(x, y) && labelAt(x, y) === j, colours[j], r);
  }
  // Details, over the colours.
  const extra = settings.extra;
  if (extra === "stars") for (let i = 0; i < 46; i++) { const x = 100 + r() * 1050, y = 380 + r() * 850; if (inside(x, y)) fill(c, star(x, y, 26, 11), hex("#ffd84a"), r, { line: 7, hatch: 7 }); }
  if (extra === "moons") for (let i = 0; i < 16; i++) {
    const x = 100 + r() * 1050, y = 380 + r() * 850;
    // A crescent: the outer arc round its right side, the inner one back, centred a little to the left.
    const arc = (cx, rad, from, to) => Array.from({ length: 13 }, (_, k) => { const an = from + ((to - from) * k) / 12; return [cx + Math.cos(an) * rad, y + Math.sin(an) * rad]; });
    const moon = [...arc(x, 44, -2, 2), ...arc(x - 18, 34, 1.75, -1.75)];
    if (inside(x - 30, y) && inside(x + 46, y)) fill(c, moon, hex("#fff2b8"), r, { line: 7, hatch: 7 });
  }
  if (extra === "scales") {
    const main = labelAt(627, 800);
    for (let y = 420; y < 1100; y += 34) for (let x = 60 + ((y / 34) % 2) * 22; x < 1200; x += 44) {
      if (inside(x, y) && labelAt(x, y) === main) line(c, curve([[x - 20, y], [x, y + 16], [x + 20, y]], 4), 5, colours[main].map((v) => v * 0.6), r);
    }
  }
  if (extra === "tweed") {
    for (let y = 400; y < 1250; y += 26) for (let x = 100; x < 1160; x += 40) {
      if (inside(x, y) && labelAt(x, y) === labelAt(627, 900)) line(c, [[x, y], [x + 14, y + 12]], 4, hex("#5a3a20"), r);
    }
  }
  if (extra === "fluff") for (let i = 0; i < 260; i++) { const x = r() * SIZE, y = 340 + r() * 910; if (inside(x, y)) dab(c, x, y, 7, hex("#ffffff"), 0.45); }
  if (extra === "crest") {
    fill(c, [[760, 640], [810, 640], [808, 690], [785, 712], [762, 690]], hex("#ffd84a"), r, { line: 8, hatch: 6 });
    line(c, curve([[778, 660], [790, 672], [778, 684]], 4), 4, OUTLINE, r);
  }
  // Outlines: the outfit's edge, and the borders between its colour areas.
  outlineWhere(c, inside, 24, OUTLINE, r);
  const step = 4;
  for (let y = step; y < SIZE - step; y += step) for (let x = step; x < SIZE - step; x += step) {
    if (!inside(x, y)) continue;
    const l = labelAt(x, y), right = labelAt(x + SCALE, y), below = labelAt(x, y + SCALE);
    if ((right >= 0 && right !== l) || (below >= 0 && below !== l)) dab(c, x, y, 8, OUTLINE, 0.85);
  }
}

// --- Draw ---
const jobs = [];
for (const rarity of fs.readdirSync(path.join(ART, "Skin"))) for (const f of fs.readdirSync(path.join(ART, "Skin", rarity))) jobs.push(["Skin", rarity, f]);
for (const rarity of fs.readdirSync(path.join(ART, "Outfit"))) for (const f of fs.readdirSync(path.join(ART, "Outfit", rarity))) jobs.push(["Outfit", rarity, f]);
const done = [];
jobs.forEach(([layer, rarity, f], n) => {
  const rel = path.join(layer, rarity, f);
  if (!rel.includes(filter)) return;
  const c = canvas(), r = rng(9090 + n * 7919), name = f.replace(".png", "");
  if (layer === "Skin") drawSkin(c, r, rel, name); else drawOutfit(c, r, rel, name);
  fs.mkdirSync(path.join(OUT, layer, rarity), { recursive: true });
  writePng(path.join(OUT, rel), SIZE, SIZE, crayon.toRgba(c));
  done.push(rel);
  process.stdout.write(`\r${done.length} ${rel}`.padEnd(70));
});
console.log();

// --- base.png: originals above their crayon versions ---
const T = 200, cols = Math.min(12, done.length), rows = Math.ceil(done.length / cols);
const px = Buffer.alloc(T * cols * T * rows * 2 * 4);
for (let i = 0; i < px.length; i += 4) px.set([70, 70, 74, 255], i);
done.forEach((rel, k) => {
  [path.join(ART, rel), path.join(OUT, rel)].forEach((file, row) => {
    const sm = resample(decodePng(file), 0, 0, SIZE, SIZE, T, T);
    const ox = (k % cols) * T, oy = (Math.floor(k / cols) * 2 + row) * T;
    for (let y = 0; y < T; y++) for (let x = 0; x < T; x++) {
      const i = (y * T + x) * 4, a = sm[i + 3] / 255, o = ((oy + y) * T * cols + ox + x) * 4;
      for (let q = 0; q < 3; q++) px[o + q] = Math.round(sm[i + q] * a + px[o + q] * (1 - a));
    }
  });
});
try { writePng(path.join(OUT, "base.png"), T * cols, T * rows * 2, px); } catch (e) { console.log("(base.png is open elsewhere - not updated)"); }
console.log(`Wrote ${done.length} crayon skins and outfits to ${OUT}`);
