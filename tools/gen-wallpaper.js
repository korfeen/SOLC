// Wallpapers: old-school repeating patterns (70s florals) for behind the Overview's photo, under the inventory's tiles,
// the Dream Bed's walls... and for each one a matching border, a strip repeating sideways (a divider, put anywhere: the
// wall repeats on its own).
//
//   node tools/gen-wallpaper.js <id> "<the motifs>" [--ground #3b2314] [--seed n] [--size 0.36] [--layout]
//        [--ref <example>] [--fill 0.3] [--gap 30] [--sparkles 30]   (a sparse print in another example's style)
//   node tools/gen-wallpaper.js <id> --pattern <ogee|loops>             (drawn here whole)
//
// Codex paints the motifs only, apart on green (the user's examples in killtracker-art-extra/Wallpapers/refs as the
// style). They're keyed out and laid out here on the tile, which wraps round: a motif over one edge goes on at the
// opposite one, so the repeat is perfect and nothing is ever cut. The big ones first on a half-drop, then the rest
// scattered (turned a little, some mirrored) into the gaps till it's full. Codex can't be trusted with the repeat
// itself: it paints repeats side by side with shapes clipped where they meet.
// --layout: no Codex, lay the motifs out again (another --seed, --size: the big ones' width, part of the tile).
// The border: a frieze drawn here from the same motifs, in the wallpaper's colours.
// Out: killtracker-art-extra/Wallpapers/<id>/ (motifs.png, tile.png, preview.png: the wall tiled, the border on its
// own under it) and Media/Wallpaper/<id>.blp + <id>_Border.blp (powers of two, for SetTexture(file, "REPEAT",
// "REPEAT")), their true shapes in WallpaperData.lua.
const fs = require("fs");
const os = require("os");
const path = require("path");
const { decodePng, resample, writeBlp } = require("./convert-art");
const { writePng } = require("./make-role-icons");
const { generate, key, SIZE } = require("./gen-art");

const ROOT = path.join(os.homedir(), "killtracker-art-extra", "Wallpapers");
const REFS = path.join(ROOT, "refs");
const MEDIA = path.join(__dirname, "..", "Media", "Wallpaper");
const TILE = 512, BORDER = { h: 128 };  // (the textures: the wall tile's height, the border's)
const WORK = 1024;  // (the tile is laid out at this size)

function scaled(img, w, h) { return { width: w, height: h, rgba: Buffer.from(resample(img, 0, 0, img.width, img.height, w, h)) }; }
function tiled(img, w, h) {
  const out = Buffer.alloc(w * h * 4);
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const s = ((y % img.height) * img.width + (x % img.width)) * 4;
    img.rgba.copy(out, (y * w + x) * 4, s, s + 4);
  }
  return { width: w, height: h, rgba: out };
}
function rng(seed) {  // (mulberry32)
  let a = seed >>> 0;
  return () => { a = (a + 0x6d2b79f5) >>> 0; let t = a; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
}

// The texture for a repeat: kx x ky whole repeats on a power-of-two size, picked so its shape is as close as can be to
// theirs (hardly squashed); the side named fixed at that size. Returns it and its true shape (width / height), which
// the game draws it at (WallpaperData.lua), undoing what squash is left.
function texture(img, fixed, size, maxOther) {
  let best = null;
  for (let kx = 1; kx <= 8; kx++) for (let ky = 1; ky <= 8; ky++) {
    const w = img.width * kx, h = img.height * ky;
    for (let other = 16; other <= maxOther; other *= 2) {
      const tw = fixed === "w" ? size : other, th = fixed === "w" ? other : size;
      const off = Math.abs(Math.log((w / h) / (tw / th))) + (kx * ky) * 0.002;  // (fewer repeats when it ties)
      if (!best || off < best.off) best = { off, kx, ky, tw, th };
    }
  }
  const all = tiled(img, img.width * best.kx, img.height * best.ky);
  return { tex: scaled(all, best.tw, best.th), aspect: all.width / all.height, kx: best.kx, ky: best.ky };
}

// --- Codex: the motifs ----------------------------------------------------------------------------------------------

function refs() {
  const files = fs.existsSync(REFS) ? fs.readdirSync(REFS).filter((f) => /\.(png|jpe?g)$/i.test(f)).map((f) => path.join(REFS, f)) : [];
  if (!files.length) throw new Error("No style examples in " + REFS);
  return files.slice(0, 4);
}

// ref: one example of its own (--ref) instead of the 70s ones - its style copied as it is, its greens allowed.
function Motifs(what, work, ref) {
  const prompt = [
    ref ? "The example image is an old-school wallpaper. Draw the separate MOTIFS for a new wallpaper in exactly its style" +
      " - the same drawing, colours, printing and level of detail:"
      : "The example images are old-school 1970s wallpapers. Draw the separate MOTIFS for a new wallpaper in exactly their" +
      " style - flat printed shapes in a few solid colours, clean thin dark outlines, warm and retro, a slightly worn print:",
    `${what}.`,
    "Draw them as a sticker sheet: about 2 big ones, 3 medium ones, 4 small ones and 5 leaves or leaf sprigs, every one",
    "WHOLE and standing ALONE, with wide empty space round each - nothing touches or overlaps anything else or the",
    "image's edges. The background everywhere else is flat pure green #00FF00. " + (ref
      ? "Leaves keep their own muted greens, but nothing is the screen's pure bright green,"
      : "No bright green in the motifs themselves (olive or mustard leaves are fine),") +
      " no shadows, no wallpaper background behind them, no text, no frame.",
  ].join("\n");
  return generate(work, ref ? [ref] : refs(), prompt, "motifs.png");
}

// The sheet keyed, and cut into its motifs: the separate shapes (8-connected, see-through between), specks dropped,
// biggest first.
function cutMotifs(file) {
  let img = decodePng(file);
  if (img.width !== SIZE || img.height !== SIZE) img = scaled(img, SIZE, SIZE);
  const rgba = key(img.rgba), n = SIZE * SIZE, seen = new Uint8Array(n), motifs = [];
  for (let p = 0; p < n; p++) {
    if (seen[p] || rgba[p * 4 + 3] < 40) continue;
    const stack = [p], pixels = [];
    seen[p] = 1;
    let x0 = SIZE, y0 = SIZE, x1 = 0, y1 = 0;
    while (stack.length) {
      const q = stack.pop(), x = q % SIZE, y = (q / SIZE) | 0;
      pixels.push(q);
      x0 = Math.min(x0, x); x1 = Math.max(x1, x); y0 = Math.min(y0, y); y1 = Math.max(y1, y);
      for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) {
        const nx = x + dx, ny = y + dy;
        if (nx < 0 || ny < 0 || nx >= SIZE || ny >= SIZE) continue;
        const r = ny * SIZE + nx;
        if (!seen[r] && rgba[r * 4 + 3] >= 40) { seen[r] = 1; stack.push(r); }
      }
    }
    if (pixels.length < 600) continue;
    // (its box, with the soft edge round it)
    const pad = 3, bx = Math.max(0, x0 - pad), by = Math.max(0, y0 - pad);
    const w = Math.min(SIZE - 1, x1 + pad) - bx + 1, h = Math.min(SIZE - 1, y1 + pad) - by + 1, out = Buffer.alloc(w * h * 4);
    // (only its own pixels and their soft edge: not bits of a neighbour or specks inside its box)
    const own = new Uint8Array(w * h);
    for (const q of pixels) {
      const x = (q % SIZE) - bx, y = ((q / SIZE) | 0) - by;
      for (let dy = -pad; dy <= pad; dy++) for (let dx = -pad; dx <= pad; dx++) {
        if (x + dx >= 0 && y + dy >= 0 && x + dx < w && y + dy < h) own[(y + dy) * w + x + dx] = 1;
      }
    }
    for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
      if (own[y * w + x]) rgba.copy(out, (y * w + x) * 4, ((by + y) * SIZE + bx + x) * 4, ((by + y) * SIZE + bx + x) * 4 + 4);
    }
    motifs.push({ width: w, height: h, rgba: out, area: pixels.length });
  }
  motifs.sort((a, b) => b.area - a.area);
  if (!motifs.length) throw new Error("No motifs found on " + file);
  return motifs;
}

// Little stars in clusters over the gaps (wrapping round, kept off the motifs): mostly faded gold, a few dark.
function sparkles(tile, S, taken, G, random, clusters) {
  const GOLD = [196, 178, 136], DARK = [70, 62, 56];
  const star = (cx, cy, R, points, col) => {
    for (let y = Math.floor(cy - R) - 1; y <= cy + R + 1; y++) for (let x = Math.floor(cx - R) - 1; x <= cx + R + 1; x++) {
      let hit = 0;
      for (let sy = 0; sy < 3; sy++) for (let sx = 0; sx < 3; sx++) {
        const dx = x + (sx + 0.5) / 3 - cx, dy = y + (sy + 0.5) / 3 - cy, d = Math.hypot(dx, dy), t = Math.atan2(dy, dx);
        if (d < R * (0.18 + 0.82 * Math.pow(Math.abs(Math.cos((points * t) / 2)), 6))) hit++;
      }
      if (!hit) continue;
      const a = hit / 9, o = ((((y % S) + S) % S) * S + (((x % S) + S) % S)) * 4;
      for (let c = 0; c < 3; c++) tile[o + c] = Math.round(tile[o + c] * (1 - a) + col[c] * a);
    }
  };
  const free = (x, y) => !taken[((Math.floor(y / CELL) % G + G) % G) * G + ((Math.floor(x / CELL) % G + G) % G)];
  for (let k = 0; k < clusters; k++) {
    const cx = random() * S, cy = random() * S, n = 3 + Math.floor(random() * 6);
    for (let j = 0; j < n; j++) {
      const x = cx + (random() * 2 - 1) * 55, y = cy + (random() * 2 - 1) * 45;
      if (!free(x, y) || !free(x + 12, y) || !free(x - 12, y) || !free(x, y + 12) || !free(x, y - 12)) continue;
      star(x, y, 5 + random() * 8, random() < 0.6 ? 6 : 4, random() < 0.82 ? GOLD : DARK);
    }
  }
}

// --- Laying them out ------------------------------------------------------------------------------------------------

// A motif scaled, turned (radians) and maybe mirrored: a new image, its box grown to fit.
function transform(m, scale, angle, flip) {
  const cos = Math.cos(angle), sin = Math.sin(angle), sw = m.width * scale, sh = m.height * scale;
  const w = Math.ceil(Math.abs(sw * cos) + Math.abs(sh * sin)) + 2, h = Math.ceil(Math.abs(sw * sin) + Math.abs(sh * cos)) + 2;
  const out = Buffer.alloc(w * h * 4);
  // (smaller: area-averaged first, so it doesn't sparkle)
  const src = scale < 0.9 ? scaled(m, Math.max(1, Math.round(sw)), Math.max(1, Math.round(sh))) : null, s = src ? 1 : scale;
  const base = src || m;
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const dx = x - w / 2, dy = y - h / 2;
    let u = (dx * cos + dy * sin) / s + base.width / 2, v = (-dx * sin + dy * cos) / s + base.height / 2;
    if (flip) u = base.width - u;
    const a = sampleFrom(base, u - 0.5, v - 0.5, 3);
    if (a < 1) continue;
    const o = (y * w + x) * 4;
    for (let c = 0; c < 3; c++) out[o + c] = Math.min(255, Math.round(sampleFrom(base, u - 0.5, v - 0.5, c) / (a / 255)));
    out[o + 3] = Math.round(a);
  }
  return { width: w, height: h, rgba: out };
  function sampleFrom(img, x, y, c) {
    const x0 = Math.floor(x), y0 = Math.floor(y), fx = x - x0, fy = y - y0;
    const at = (xx, yy) => (xx < 0 || yy < 0 || xx >= img.width || yy >= img.height ? 0 : img.rgba[(yy * img.width + xx) * 4 + c] * (c === 3 ? 1 : img.rgba[(yy * img.width + xx) * 4 + 3] / 255));
    return at(x0, y0) * (1 - fx) * (1 - fy) + at(x0 + 1, y0) * fx * (1 - fy) + at(x0, y0 + 1) * (1 - fx) * fy + at(x0 + 1, y0 + 1) * fx * fy;
  }
}

// The tile: WORK x WORK on the ground colour, wrapping round. Taken: a coarse grid (CELL px a cell) of what's covered,
// each motif kept GAP px from the others.
// opts: fill (stop when this much is covered: a sparse print), gap (px between motifs), sparkles (clusters of little
// stars drawn in the gaps).
const CELL = 4;
function layout(motifs, ground, seed, bigSize, opts = {}) {
  const GAP = opts.gap || 10, FILL = opts.fill || 1;
  const random = rng(seed), S = WORK, G = S / CELL;
  const tile = Buffer.alloc(S * S * 4), taken = new Uint8Array(G * G);
  for (let i = 0; i < S * S; i++) tile.set([ground[0], ground[1], ground[2], 255], i * 4);
  const maxSide = Math.max(motifs[0].width, motifs[0].height), scale = (bigSize * S) / maxSide;
  const big = motifs.filter((m) => m.area >= motifs[0].area * 0.45);
  const rest = motifs.filter((m) => !big.includes(m));
  const cells = (img, cx, cy, grow) => {  // the grid cells it covers (wrapped), grown by grow cells
    const list = [], x0 = Math.round(cx - img.width / 2), y0 = Math.round(cy - img.height / 2);
    for (let gy = Math.floor(y0 / CELL) - grow; gy <= Math.floor((y0 + img.height) / CELL) + grow; gy++) {
      for (let gx = Math.floor(x0 / CELL) - grow; gx <= Math.floor((x0 + img.width) / CELL) + grow; gx++) {
        // (covered: any solid pixel in the cell or within grow cells of it)
        let hit = false;
        for (let yy = Math.max(0, (gy - grow) * CELL - y0); !hit && yy < Math.min(img.height, (gy + grow + 1) * CELL - y0); yy += 2) {
          for (let xx = Math.max(0, (gx - grow) * CELL - x0); xx < Math.min(img.width, (gx + grow + 1) * CELL - x0); xx += 2) {
            if (img.rgba[(yy * img.width + xx) * 4 + 3] > 60) { hit = true; break; }
          }
        }
        if (hit) list.push((((gy % G) + G) % G) * G + (((gx % G) + G) % G));
      }
    }
    return list;
  };
  const place = (img, cx, cy) => {
    const x0 = Math.round(cx - img.width / 2), y0 = Math.round(cy - img.height / 2);
    for (let y = 0; y < img.height; y++) for (let x = 0; x < img.width; x++) {
      const i = (y * img.width + x) * 4, a = img.rgba[i + 3] / 255;
      if (!a) continue;
      const o = ((((y0 + y) % S + S) % S) * S + (((x0 + x) % S + S) % S)) * 4;
      for (let c = 0; c < 3; c++) tile[o + c] = Math.round(tile[o + c] * (1 - a) + img.rgba[i + c] * a);
    }
    for (const c of cells(img, cx, cy, 0)) taken[c] = 1;
  };
  const tryPlace = (m, cx, cy, s, angle) => {
    const img = transform(m, s, angle, random() < 0.5);
    if (cells(img, cx, cy, Math.ceil(GAP / CELL)).some((c) => taken[c])) return false;
    place(img, cx, cy);
    return true;
  };
  const turn = (most) => (random() * 2 - 1) * most;
  // The big ones on a half-drop (two a tile), the next on the other half-drop, nudged a little.
  const spots = [[0.25, 0.25], [0.75, 0.75], [0.75, 0.25], [0.25, 0.75]];
  const firsts = [...big, ...big].slice(0, 2).concat(rest.slice(0, 2));
  firsts.forEach((m, i) => {
    const [fx, fy] = spots[i];
    for (let k = 0; k < 40; k++) {
      if (tryPlace(m, (fx + turn(0.04)) * S, (fy + turn(0.04)) * S, scale * (i < 2 ? 1 : 0.95), turn(0.35))) break;
    }
  });
  // The rest scattered into the gaps, smaller ones as it fills, till nothing more fits.
  const pool = [...big, ...rest];
  let placed = 0;
  for (let k = 0; k < 2500; k++) {
    if (FILL < 1 && k % 25 === 0 && taken.reduce((a, b) => a + b, 0) / taken.length >= FILL) break;
    const late = k / 2500, m = pool[Math.floor(random() * pool.length)];
    const isBig = big.includes(m);
    if (isBig && late > 0.25) continue;
    const s = scale * (isBig ? 0.85 : 1 - late * 0.35) * (0.9 + random() * 0.2);
    if (tryPlace(m, random() * S, random() * S, s, m.width > m.height * 1.6 || m.height > m.width * 1.6 ? random() * Math.PI * 2 : turn(0.6))) placed++;
  }
  if (opts.sparkles) sparkles(tile, S, taken, G, random, opts.sparkles);
  const covered = taken.reduce((a, b) => a + b, 0) / taken.length;
  console.log(`  laid out: ${motifs.length} motifs (${big.length} big), ${placed + firsts.length} placed, ${(covered * 100).toFixed(0)}% covered`);
  return { width: S, height: S, rgba: tile };
}

// --- Drawn patterns --------------------------------------------------------------------------------------------------

// The geometric ones are drawn here whole (no Codex): each a distance field over the tile, coloured in nested rings
// (RINGS: [up to this far in, colour]), its edges smoothed (3x3 samples a pixel), wobbled a touch like a hand-cut print
// (whole waves across the tile, so it still repeats) and grained. Each also gives one of its shapes alone, for its
// frieze.
const hex = (h) => h.replace("#", "").match(/../g).map((v) => parseInt(v, 16));
const BLOCKS = [
    "llll ccll dccd cccc cddc llcc llll dddd cccc llll dddd ccdd lccl cccc cllc ddcc dddd llll cccc dddd",
    "cccc cddc llcc llll dddd cccc llll dddd ccdd lccl cccc cllc ddcc dddd llll cccc dddd llll ccll dccd",
    "llll dddd cccc llll dddd ccdd lccl cccc cllc ddcc dddd llll cccc dddd llll ccll dccd cccc cddc llcc",
    "llll dddd ccdd lccl cccc cllc ddcc dddd llll cccc dddd llll ccll dccd cccc cddc llcc llll dddd cccc",
    "lccl cccc cllc ddcc dddd llll cccc dddd llll ccll dccd cccc cddc llcc llll dddd cccc llll dddd ccdd",
    "ddcc dddd llll cccc dddd llll ccll dccd cccc cddc llcc llll dddd cccc llll dddd ccdd lccl cccc cllc",
    "cccc dddd llll ccll dccd cccc cddc llcc llll dddd cccc llll dddd ccdd lccl cccc cllc ddcc dddd llll",
    "ccll dccd cccc cddc llcc llll dddd cccc llll dddd ccdd lccl cccc cllc ddcc dddd llll cccc dddd llll",
    "cddc llcc llll dddd cccc llll dddd ccdd lccl cccc cllc ddcc dddd llll cccc dddd llll ccll dccd cccc",
    "dddd cccc llll dddd ccdd lccl cccc cllc ddcc dddd llll cccc dddd llll ccll dccd cccc cddc llcc llll",
    "dddd ccdd lccl cccc cllc ddcc dddd llll cccc dddd llll ccll dccd cccc cddc llcc llll dddd cccc llll",
    "cccc cllc ddcc dddd llll cccc dddd llll ccll dccd cccc cddc llcc llll dddd cccc llll dddd ccdd lccl",
    "dddd llll cccc dddd llll ccll dccd cccc cddc llcc llll dddd cccc llll dddd ccdd lccl cccc cllc ddcc",
    "dddd llll ccll dccd cccc cddc llcc llll dddd cccc llll dddd ccdd lccl cccc cllc ddcc dddd llll cccc",
    "dccd cccc cddc llcc llll dddd cccc llll dddd ccdd lccl cccc cllc ddcc dddd llll cccc dddd llll ccll",
    "llcc llll dddd cccc llll dddd ccdd lccl cccc cllc ddcc dddd llll cccc dddd llll ccll dccd cccc cddc",
    "cccc llll dddd ccdd lccl cccc cllc ddcc dddd llll cccc dddd llll ccll dccd cccc cddc llcc llll dddd",
    "ccdd lccl cccc cllc ddcc dddd llll cccc dddd llll ccll dccd cccc cddc llcc llll dddd cccc llll dddd",
    "cllc ddcc dddd llll cccc dddd llll ccll dccd cccc cddc llcc llll dddd cccc llll dddd ccdd lccl cccc",
    "llll cccc dddd llll ccll dccd cccc cddc llcc llll dddd cccc llll dddd ccdd lccl cccc cllc ddcc dddd",
];
const PATTERNS = {
  // Teardrop ogee: wavy brown bands, between them drops in rings of mustard, red-orange and orange round a cream heart.
  // Columns cw wide, walls swinging A each way over ch; next door's swing the other way (a half-drop).
  ogee: {
    w: 360, h: 520, ground: "#5b2a12", centre: [0.25, 0.75],  // (a drop's middle: the widest in the first column)
    rings: [[0.16, "#5b2a12"], [0.36, "#f2a11d"], [0.54, "#e2481c"], [0.68, "#f59a1b"], [1, "#f7ecd0"]],
    field(x, y, P) {
      const cw = P.w / 2, A = cw * 0.5, k = Math.floor(x / cw);
      const wall = (j) => j * cw + (j % 2 ? -1 : 1) * A * Math.sin((2 * Math.PI * y) / P.h);
      const slope = (j) => Math.abs((j % 2 ? -1 : 1) * A * ((2 * Math.PI) / P.h) * Math.cos((2 * Math.PI * y) / P.h));
      // (the walls either side: the one past x may have swung over it)
      let left = -Infinity, right = Infinity, sl = 0, sr = 0;
      for (let j = k - 1; j <= k + 2; j++) {
        const at = wall(j);
        if (at <= x && at > left) { left = at; sl = slope(j); }
        if (at > x && at < right) { right = at; sr = slope(j); }
      }
      const d = Math.min((x - left) / Math.sqrt(1 + sl * sl), (right - x) / Math.sqrt(1 + sr * sr));
      return d / (cw / 2 + A);  // (0 on a wall, 1 at the widest drop's middle)
    },
  },
  // Oval loops: rows of long rounded ovals, ringed orange, cream and light orange round an orange middle, on peach.
  // Club Walnut, everyone's to start with (2026-11-05): a dark clubhouse stripe, dark so white text reads on it - a walnut
  // band edged in a near-black pinstripe and a gold one, then a plain darker band. STRIPES: { from x, colour } over a repeat.
  walnut: {
    w: 256, h: 256, grain: 0.035,
    stripes: [[0, "#4a3322"], [46, "#22150c"], [50, "#3a2819"], [54, "#9a7442"], [56, "#3a2819"],
      [92, "#3a2819"], [94, "#3a2819"], [124, "#9a7442"], [126, "#3a2819"], [130, "#22150c"]],
    period: 134,
    colourAt(x) {
      const at = x % (this.w / 2) * (this.period / (this.w / 2));  // (two repeats a tile)
      let col = this.stripes[0][1];
      for (const [from, c] of this.stripes) if (at >= from) col = c;
      return hex(col);
    },
    // Its border: plain - the walnut band with two thin gold lines along it.
    friezeAt(x, y, W, H) {
      const top = 26, inner = H - 2 * top, t = (y - top) / inner;
      if (t < 0 || t >= 1) return null;
      return Math.abs(t - 0.28) < 0.025 || Math.abs(t - 0.72) < 0.025 ? hex("#9a7442") : hex("#4a3322");
    },
  },
  // Club Stripes (free; everyone's default before Club Walnut, 2026-11-05): a quiet clubhouse stripe - a wide
  // tan band edged in a brown pinstripe and a gold one, then a wide cream band (its faint middle line taken out: it
  // showed as a stray pixel line). STRIPES: { from x, colour } over a repeat.
  stripes: {
    w: 256, h: 256, grain: 0.035,
    stripes: [[0, "#b08a5c"], [46, "#5a3a22"], [50, "#ecdfc3"], [54, "#b8925a"], [56, "#ecdfc3"],
      [124, "#b8925a"], [126, "#ecdfc3"], [130, "#5a3a22"]],
    period: 134,
    colourAt(x) {
      const at = x % (this.w / 2) * (this.period / (this.w / 2));  // (two repeats a tile)
      let col = this.stripes[0][1];
      for (const [from, c] of this.stripes) if (at >= from) col = c;
      return hex(col);
    },
    // Its border: plain - the tan band with two thin cream lines along it.
    friezeAt(x, y, W, H) {
      const top = 26, inner = H - 2 * top, t = (y - top) / inner;
      if (t < 0 || t >= 1) return null;
      return Math.abs(t - 0.28) < 0.025 || Math.abs(t - 0.72) < 0.025 ? hex("#ecdfc3") : hex("#b08a5c");
    },
  },
  // Blue blocks, measured off the user's example (refs: GE5035): navy, light blue and cream on a square grid, every
  // square one colour or split corner to corner (its top, right, bottom and left quarters' colours in BLOCKS: tl/br
  // the same on one side = split along "\", tr/bl = along "/"). It repeats one step 3 squares left and 1 down, so
  // straight across only every 20; the table is those 20 x 20, read off the example through that step.
  blocks: {
    w: 1024, h: 1024, cells: 20, grain: 0.025,
    colours: { d: [1, 78, 105], l: [161, 187, 195], c: [237, 234, 228] },
    colourAt(x, y) {
      const u = this.w / this.cells, i = Math.floor(x / u) % this.cells, j = Math.floor(y / u) % this.cells;
      const fx = x / u - Math.floor(x / u), fy = y / u - Math.floor(y / u), q = BLOCKS[j].split(" ")[i];
      const [t, rt, b, l] = q;
      let k = t;
      if (t === rt && b === l && t !== b) k = fy < fx ? t : b;  // (split along "\": top-right / bottom-left)
      else if (t === l && b === rt && t !== b) k = fx + fy < 1 ? t : b;  // (along "/": top-left / bottom-right)
      return this.colours[k];
    },
    // Its frieze: a band of it, 20 squares to the strip's repeat, from row friezeRow down.
    friezeRow: 2,
    friezeAt(x, y, W, H) {
      const top = 26, u = W / this.cells, scale = (this.w / this.cells) / u;
      if (y < top || y >= H - top) return null;
      return this.colourAt(x * scale, (this.friezeRow * u + (y - top)) * scale);
    },
  },
  // Oval loops, measured off the user's example (refs/loops.jpg, its colours too): a straight
  // grid of long ovals touching their neighbours all round (beige only in the diamonds between four), each ringed red-orange, tan and pale cream round an orange middle - the rings
  // scaled-down copies of the outline (so thicker at the ends than top and bottom) - and a faint dot in the beige
  // between every four.
  loops: {
    w: 288, h: 172, ground: "#c1a07d", centre: [0.5, 0.5], dot: { r: 11, colour: "#c1a988" },
    rings: [[0, "#c1a07d"], [0.155, "#b45930"], [0.29, "#be935f"], [0.48, "#c1a884"], [1, "#b37134"]],
    field(x, y, P) { return 1 - ovalScale(x - P.w / 2, y - P.h / 2, P.h / 2, P.w / P.h); },  // (the outline: the cell)
    // Its frieze: a chain of 4 of them a repeat, each running a little into the next (the nearest one's rings win).
    frieze(x, y, W, H) {
      const cell = W / 4;
      let best = -Infinity;
      for (let i = 0; i < 4; i++) {
        const dx = ((((x - (i + 0.5) * cell) % W) + W * 1.5) % W) - W / 2;
        best = Math.max(best, 1 - ovalScale(dx, y - H / 2, 60, 288 / 172));
      }
      return best;
    },
  },
};
// How far out (dx, dy) is on an oval of half height hh, aspect times as long, ends round: 1 on its outline, 0.5 on its
// copy half the size (the scale it would need to pass through there).
function ovalScale(dx, dy, hh, aspect) {
  const px = Math.abs(dx) / hh, py = Math.abs(dy) / hh, a = aspect - 1;  // (a: the straight part's half length, unit radius)
  if (px <= a * py) return py;
  if (a >= 1) return Math.max(py, px - a * py);  // (not a real oval: no rounded ends to speak of)
  return (-a * px + Math.sqrt(a * a * px * px + (1 - a * a) * (px * px + py * py))) / (1 - a * a);
}
// Flat ones (P.colourAt instead of a field and rings): the colour at each point, edges smoothed (4x4 samples a
// pixel), no wobble - crisp, like the example. No shape alone: their frieze is P.friezeAt.
function drawFlat(P, seed) {
  const W = P.w, H = P.h, out = Buffer.alloc(W * H * 4);
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    let r = 0, g = 0, b = 0;
    for (let sy = 0; sy < 4; sy++) for (let sx = 0; sx < 4; sx++) {
      const c = P.colourAt(x + (sx + 0.5) / 4, y + (sy + 0.5) / 4);
      r += c[0]; g += c[1]; b += c[2];
    }
    out.set([Math.round(r / 16), Math.round(g / 16), Math.round(b / 16), 255], (y * W + x) * 4);
  }
  if (P.grain) grain(out, seed, P.grain);
  return { wall: { width: W, height: H, rgba: out }, stamp: null, ground: P.colourAt(0.5, 0.5) };
}
function ringColour(P, t) {
  if (t <= 0) return P.groundRgb;
  for (const [to, col] of P.ringRgb) if (t <= to) return col;
  return P.ringRgb[P.ringRgb.length - 1][1];
}
function drawPattern(name, seed) {
  const P = PATTERNS[name];
  if (!P) throw new Error("No pattern " + name + " (" + Object.keys(PATTERNS).join(", ") + ")");
  P.groundRgb = hex(P.ground);
  P.ringRgb = P.rings.map(([to, c]) => [to, hex(c)]);
  const random = rng(seed + 7), W = P.w, H = P.h;
  // (the wobble: a couple of whole waves each way)
  const waves = [0, 1].map(() => [1 + Math.floor(random() * 3), random() * 6.3]);
  const wob = (x, y) => [x + 1.6 * Math.sin((2 * Math.PI * waves[0][0] * y) / H + waves[0][1]),
    y + 1.6 * Math.sin((2 * Math.PI * waves[1][0] * x) / W + waves[1][1])];
  const shade = (x, y, alone) => {
    let r = 0, g = 0, b = 0, a = 0;
    for (let sy = 0; sy < 3; sy++) for (let sx = 0; sx < 3; sx++) {
      let [px, py] = wob(x + (sx + 0.5) / 3, y + (sy + 0.5) / 3);
      px = ((px % W) + W) % W; py = ((py % H) + H) % H;
      const t = P.field(px, py, P);
      // (the ground's dots: at the tile's corners, between four shapes)
      if (t <= 0 && P.dot && !alone && Math.hypot(Math.min(px, W - px), Math.min(py, H - py)) < P.dot.r) {
        const c = hex(P.dot.colour); r += c[0]; g += c[1]; b += c[2]; a++; continue;
      }
      // (alone: one shape, see-through round it - its outermost ring kept as its outline)
      if (alone && t <= P.rings[0][0]) continue;
      const c = ringColour(P, t);
      r += c[0]; g += c[1]; b += c[2]; a++;
    }
    return a ? [r / a, g / a, b / a, (a / 9) * 255] : [0, 0, 0, 0];
  };
  const out = Buffer.alloc(W * H * 4);
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) out.set(shade(x, y).map(Math.round), (y * W + x) * 4);
  grain(out, seed);
  // One shape alone: the tile shifted so one sits in the middle (P.centre), only the pixels joined to the middle one
  // (a flood from it), cut to its box.
  const ox = P.centre[0] * W - W / 2, oy = P.centre[1] * H - H / 2, all = [];
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) all.push(shade(x + ox, y + oy, true));
  const alone = Buffer.alloc(W * H * 4), seen = new Uint8Array(W * H), stack = [(H >> 1) * W + (W >> 1)];
  let x0 = W, y0 = H, x1 = 0, y1 = 0;
  while (stack.length) {
    const p = stack.pop();
    if (seen[p] || !all[p][3]) continue;
    seen[p] = 1;
    const x = p % W, y = (p / W) | 0;
    alone.set(all[p].map(Math.round), p * 4);
    x0 = Math.min(x0, x); x1 = Math.max(x1, x); y0 = Math.min(y0, y); y1 = Math.max(y1, y);
    if (x > 0) stack.push(p - 1); if (x < W - 1) stack.push(p + 1); if (y > 0) stack.push(p - W); if (y < H - 1) stack.push(p + W);
  }
  const sw = x1 - x0 + 1, sh = y1 - y0 + 1, stamp = Buffer.alloc(sw * sh * 4);
  for (let y = 0; y < sh; y++) alone.copy(stamp, y * sw * 4, ((y0 + y) * W + x0) * 4, ((y0 + y) * W + x1 + 1) * 4);
  return { wall: { width: W, height: H, rgba: out }, stamp: { width: sw, height: sh, rgba: stamp, area: sw * sh }, ground: P.groundRgb };
}

// --- The border ------------------------------------------------------------------------------------------------------

// The wallpaper's colours: a few found by k-means, with how much of it each covers.
function palette(img, k = 5) {
  const px = [];
  for (let i = 0; i < img.rgba.length; i += 4 * 7) px.push([img.rgba[i], img.rgba[i + 1], img.rgba[i + 2]]);
  let centres = Array.from({ length: k }, (_, i) => px[Math.floor((i + 0.5) * px.length / k)].slice());
  let counts;
  for (let round = 0; round < 12; round++) {
    const sums = centres.map(() => [0, 0, 0]); counts = centres.map(() => 0);
    for (const p of px) {
      let bi = 0, bd = Infinity;
      centres.forEach((c, i) => { const d = (p[0] - c[0]) ** 2 + (p[1] - c[1]) ** 2 + (p[2] - c[2]) ** 2; if (d < bd) { bd = d; bi = i; } });
      sums[bi][0] += p[0]; sums[bi][1] += p[1]; sums[bi][2] += p[2]; counts[bi]++;
    }
    centres = centres.map((c, i) => counts[i] ? sums[i].map((s) => s / counts[i]) : c);
  }
  return centres.map((c, i) => ({ c: c.map(Math.round), share: counts[i] / px.length, lum: c[0] * 0.3 + c[1] * 0.59 + c[2] * 0.11 }));
}
// A frieze in the wallpaper's own motifs and colours: on its ground, small flowers taking turns with leaf sprigs lying
// along it, between two printed edges (a band of its lightest colour, a thin line of its second) a little wobbly, like a
// hand-pulled print. Everything wraps round its ends, so it repeats perfectly. W x H, BORDER_SLOTS motifs a repeat.
const BORDER_W = 768, BORDER_H = 192, BORDER_SLOTS = 4;
function drawBorder(motifs, wall, ground, seed, P) {
  const straight = !!P;
  const random = rng(seed + 101), W = BORDER_W, H = BORDER_H;
  const pal = palette(wall).sort((a, b) => b.share - a.share);
  const light = pal.slice(1).reduce((a, b) => (b.lum > a.lum ? b : a)).c;
  const line = (pal.slice(1).find((p) => p.c !== light && p.lum < 160 && p.lum > 70) || pal[1]).c;
  const out = Buffer.alloc(W * H * 4);
  for (let i = 0; i < W * H; i++) out.set([ground[0], ground[1], ground[2], 255], i * 4);
  const paint = (x, y, col, a) => {
    const o = (y * W + (((x % W) + W) % W)) * 4;
    for (let c = 0; c < 3; c++) out[o + c] = Math.round(out[o + c] * (1 - a) + col[c] * a);
  };
  // (a wobble that comes back round: whole waves across the width)
  const wobble = () => {
    const waves = [[2 + Math.floor(random() * 3), random() * 6.3, 1.6], [7 + Math.floor(random() * 5), random() * 6.3, 0.8]];
    return (x) => waves.reduce((s, [k, ph, amp]) => s + amp * Math.sin((2 * Math.PI * k * x) / W + ph), 0);
  };
  // The edges, top and mirrored at the bottom: the light band out to `to`, then a thin line from..to.
  const band = (from, to, col) => {
    const top = wobble(), bottom = wobble();
    for (let x = 0; x < W; x++) {
      for (const [edge, flipped] of [[top, false], [bottom, true]]) {
        const a0 = from + (from ? edge(x) : 0), a1 = to + edge(x);
        for (let y = Math.floor(a0); y <= Math.ceil(a1); y++) {
          const cover = Math.max(0, Math.min(y + 1, a1) - Math.max(y, a0));
          if (cover > 0) paint(x, flipped ? H - 1 - y : y, col, cover);
        }
      }
    }
  };
  band(0, 11, light);
  band(11, 13.5, [52, 30, 18]);
  band(19, 22, line);
  // A flat pattern's frieze: a band of it (P.friezeAt), between the edges.
  if (P && P.friezeAt) {
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
      let r = 0, g = 0, b = 0, a = 0;
      for (let sy = 0; sy < 4; sy++) for (let sx = 0; sx < 4; sx++) {
        const c = P.friezeAt(x + (sx + 0.5) / 4, y + (sy + 0.5) / 4, W, H);
        if (!c) continue;
        r += c[0]; g += c[1]; b += c[2]; a++;
      }
      if (a) paint(x, y, [r / a, g / a, b / a], a / 16);
    }
    if (P.grain) grain(out, seed + 202, P.grain);
    return { width: W, height: H, rgba: out };
  }
  // A drawn pattern with its own frieze (P.frieze: a field along the strip, coloured in its rings): that instead.
  if (P && P.frieze) {
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
      let r = 0, g = 0, b = 0, a = 0;
      for (let sy = 0; sy < 3; sy++) for (let sx = 0; sx < 3; sx++) {
        const t = P.frieze(x + (sx + 0.5) / 3, y + (sy + 0.5) / 3, W, H);
        if (t <= 0) continue;
        const c = ringColour(P, t);
        r += c[0]; g += c[1]; b += c[2]; a++;
      }
      if (a) paint(x, y, [r / a, g / a, b / a], a / 9);
    }
    grain(out, seed + 202);
    return { width: W, height: H, rgba: out };
  }
  // The motifs: small flowers (the not-leafy ones, smallest first) and sprigs (the leafy ones), taking turns.
  // (leafy: yellow-green, little blue - olive and mustard leaves, not a cream flower; flowers: the round ones under the
  // big ones, smallest first)
  const leafy = (m) => {
    let r = 0, g = 0, b = 0;
    for (let i = 0; i < m.rgba.length; i += 16) if (m.rgba[i + 3] > 128) { r += m.rgba[i]; g += m.rgba[i + 1]; b += m.rgba[i + 2]; }
    return g / Math.max(1, r) > 0.65 && b / Math.max(1, g) < 0.5;
  };
  const leaves = motifs.filter(leafy);
  const round = motifs.filter((m) => !leafy(m) && Math.abs(m.width / m.height - 1) < 0.15 && m.area < motifs[0].area * 0.45);
  const flowers = (round.length ? round : motifs.filter((m) => !leafy(m))).slice(-3).reverse();
  const room = H - 2 * 26;
  for (let i = 0; i < BORDER_SLOTS; i++) {
    const sprig = i % 2 === 1 && leaves.length > 0;
    const m = sprig ? leaves[(i >> 1) % leaves.length] : flowers[(i >> 1) % flowers.length];
    // (sprigs lie along it, every other one the other way; flowers turned a little)
    const angle = sprig ? (Math.PI / 2) * ((i >> 1) % 2 ? 1 : -1) : straight ? 0 : (random() * 2 - 1) * 0.4;
    const img = transform(m, (sprig ? room * 1.25 : room * 0.95) / Math.max(m.width, m.height), angle, random() < 0.5);
    const cx = (i + 0.5) * (W / BORDER_SLOTS), x0 = Math.round(cx - img.width / 2), y0 = Math.round(H / 2 - img.height / 2);
    for (let y = 0; y < img.height; y++) for (let x = 0; x < img.width; x++) {
      const a = img.rgba[(y * img.width + x) * 4 + 3] / 255;
      if (a && y0 + y >= 0 && y0 + y < H) paint(x0 + x, y0 + y, img.rgba.subarray((y * img.width + x) * 4), a);
    }
  }
  grain(out, seed + 202);
  return { width: W, height: H, rgba: out };
}
// Paper grain: every pixel a touch lighter or darker (any per-pixel noise repeats with the tile).
function grain(rgba, seed, amount = 0.07) {
  const random = rng(seed);
  for (let i = 0; i < rgba.length; i += 4) {
    const f = 1 + (random() - 0.5) * amount;
    for (let c = 0; c < 3; c++) rgba[i + c] = Math.max(0, Math.min(255, Math.round(rgba[i + c] * f)));
  }
}

// WallpaperData.lua: each wallpaper's true shapes (a texture tile's width / height; its border's), kept in order.
const DATA = path.join(__dirname, "..", "WallpaperData.lua");
function saveData(id, data) {
  const all = {};
  if (fs.existsSync(DATA)) {
    for (const m of fs.readFileSync(DATA, "utf8").matchAll(/^\s+(\w+) = \{ aspect = ([\d.]+)(?:, border = ([\d.]+))?(, plain = .*?)? \},?\r?$/gm)) {
      all[m[1]] = { aspect: +m[2], border: m[3] ? +m[3] : undefined, plain: m[4] };  // (plain: tools/plain-borders.js)
    }
  }
  all[id] = { ...data, plain: all[id] && all[id].plain };
  const f = (n) => n.toFixed(4).replace(/0+$/, "").replace(/\.$/, "");
  const lines = Object.keys(all).sort().map((k) => `    ${k} = { aspect = ${f(all[k].aspect)}${all[k].border ? `, border = ${f(all[k].border)}` : ""}${all[k].plain || ""} },`);
  fs.writeFileSync(DATA, ["-- Made by tools/gen-wallpaper.js: each wallpaper's true shape (its tile's width / height, and its border's), for",
    "-- drawing the textures in Media/Wallpaper (squashed to powers of two) unsquashed.", "local _, ns = ...", "", "ns.WALLPAPERS = {",
    ...lines, "}", ""].join("\r\n"));
}

// --- The command ----------------------------------------------------------------------------------------------------

function main() {
  const args = process.argv.slice(2);
  const flag = (name) => { const i = args.indexOf(name); if (i >= 0) args.splice(i, 1); return i >= 0; };
  const opt = (name) => { const i = args.indexOf(name); return i >= 0 ? args.splice(i, 2)[1] : null; };
  const ref = opt("--ref"), fill = +(opt("--fill") || 1), gap = +(opt("--gap") || 10), sparkleCount = +(opt("--sparkles") || 0);
  const pattern = opt("--pattern"), again = flag("--layout"), seed = +(opt("--seed") || 1), size = +(opt("--size") || 0.36);
  let ground = (opt("--ground") || "#3b2314").replace("#", "").match(/../g).map((h) => parseInt(h, 16));
  const [id, what] = args;
  if (!id || !/^[a-z0-9_]+$/.test(id) || (!again && !what && !pattern)) {
    throw new Error('Usage: node tools/gen-wallpaper.js <id> "<the motifs>" [--ground #3b2314] [--seed n] [--size 0.36] [--layout]\n' +
      `       node tools/gen-wallpaper.js <id> --pattern <${Object.keys(PATTERNS).join("|")}>`);
  }
  const work = path.join(ROOT, id);
  fs.mkdirSync(work, { recursive: true });
  fs.mkdirSync(MEDIA, { recursive: true });
  let wall, motifs;
  if (pattern) {
    const drawn = PATTERNS[pattern] && PATTERNS[pattern].colourAt ? drawFlat(PATTERNS[pattern], seed) : drawPattern(pattern, seed);
    wall = drawn.wall; motifs = drawn.stamp ? [drawn.stamp] : []; ground = drawn.ground;
  } else {
    const sheet = path.join(work, "motifs.png");
    if (!again) Motifs(what, work, ref && path.resolve(ref));
    if (!fs.existsSync(sheet)) throw new Error("No motifs yet: " + sheet);
    motifs = cutMotifs(sheet); wall = layout(motifs, ground, seed, size, { fill, gap, sparkles: sparkleCount });
    grain(wall.rgba, seed);
  }
  writePng(path.join(work, "tile.png"), wall.width, wall.height, wall.rgba);
  const w = texture(wall, "h", TILE, 1024), wallTex = w.tex;
  writeBlp(path.join(MEDIA, id + ".blp"), wallTex.width, wallTex.height, wallTex.rgba);

  const b = texture(drawBorder(motifs, wall, ground, seed, pattern && PATTERNS[pattern]), "h", BORDER.h, 1024);
  writeBlp(path.join(MEDIA, id + "_Border.blp"), b.tex.width, b.tex.height, b.tex.rgba);
  saveData(id, { aspect: w.aspect, border: b.aspect });

  // Preview: the wall tiled (a tile 320 px here), the border on its own under it.
  const W = 960, H = 640, T = 320, BH = 64, SPACE = 12, all = Buffer.alloc(W * (H + SPACE + BH) * 4, 255);
  tiled(scaled(wallTex, Math.round(T * w.aspect), T), W, H).rgba.copy(all, 0);
  tiled(scaled(b.tex, Math.round(BH * b.aspect), BH), W, BH).rgba.copy(all, (H + SPACE) * W * 4);
  // (preview.png open in a viewer can be locked: then a numbered one)
  let shown = path.join(work, "preview.png");
  for (let n = 2; ; n++) {
    try { writePng(shown, W, H + SPACE + BH, all); break; } catch (e) { if (n > 9) throw e; shown = path.join(work, `preview-${n}.png`); }
  }
  console.log("Done:", shown);
}

if (require.main === module) {
  try { main(); } catch (e) { console.error(e.message); process.exit(1); }
}
module.exports = { cutMotifs, layout, drawBorder };
