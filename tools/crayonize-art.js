// Crayon twins of the minting art: every picture layer in %USERPROFILE%\killtracker-art redrawn as if in crayon, in
// the same shape, place and colours, into %USERPROFILE%\killtracker-art-extra\CrayonArt (the same folders). Each layer's
// colours are simplified to a few flat areas (k-means), each area coloured in with crayon hatching in its colour
// (tools/make-role-icons.js), the shape outlined in dark crayon and the areas' borders in thinner lines.
// Also writes preview.png there: a few whole ogres, the original above its crayon twin.
// Usage: node tools/crayonize-art.js [filter]   (filter: only paths containing it, e.g. "Headwear"). No dependencies.

const fs = require("fs");
const os = require("os");
const path = require("path");
const crayon = require("./make-role-icons");
const { decodePng, resample } = require("./convert-art");

const SIZE = 1254;
crayon.setSize(SIZE);
const { canvas, dab, stroke, OUTLINE, rng, writePng } = crayon;
const SOURCE = path.join(os.homedir(), "killtracker-art");
const OUT = path.join(os.homedir(), "killtracker-art-extra", "CrayonArt");
const filter = (process.argv[2] || "").split("/").join(path.sep);

const SMALL = 314;  // the colour areas are found at a quarter of the size
const SCALE = SIZE / SMALL;
const COLOURS = { Background: 7, Skin: 5, Outfit: 6 };  // areas per layer (others: 5)

// k-means on the visible pixels' colours: returns the centres.
function kmeans(pixels, k, random) {
  const centres = [];
  for (let i = 0; i < k; i++) centres.push(pixels[Math.floor(random() * pixels.length)].slice());
  const assign = new Int32Array(pixels.length);
  for (let round = 0; round < 10; round++) {
    const sums = centres.map(() => [0, 0, 0, 0]);
    pixels.forEach((p, i) => {
      let best = 0, bestD = Infinity;
      centres.forEach((c, j) => {
        const d = (p[0] - c[0]) ** 2 * 0.3 + (p[1] - c[1]) ** 2 * 0.59 + (p[2] - c[2]) ** 2 * 0.11;
        if (d < bestD) { bestD = d; best = j; }
      });
      assign[i] = best;
      const s = sums[best]; s[0] += p[0]; s[1] += p[1]; s[2] += p[2]; s[3]++;
    });
    sums.forEach((s, j) => { if (s[3]) centres[j] = [s[0] / s[3], s[1] / s[3], s[2] / s[3]]; });
  }
  return centres;
}
const nearest = (p, centres) => {
  let best = 0, bestD = Infinity;
  centres.forEach((c, j) => {
    const d = (p[0] - c[0]) ** 2 * 0.3 + (p[1] - c[1]) ** 2 * 0.59 + (p[2] - c[2]) ** 2 * 0.11;
    if (d < bestD) { bestD = d; best = j; }
  });
  return best;
};
// Crayons are brighter and purer than paint: a little more colour.
const crayonColour = ([r, g, b]) => {
  const grey = (r + g + b) / 3;
  return [r, g, b].map((v) => Math.max(0, Math.min(255, grey + (v - grey) * 1.25 + 8)));
};

function crayonize(file, random) {
  const layer = file.split(path.sep)[0];
  const image = decodePng(path.join(SOURCE, file));
  const small = resample(image, 0, 0, SIZE, SIZE, SMALL, SMALL);
  // Labels: -1 where see-through, else the colour area.
  const pixels = [], index = [];
  for (let i = 0; i < SMALL * SMALL; i++) {
    if (small[i * 4 + 3] > 128) { pixels.push([small[i * 4], small[i * 4 + 1], small[i * 4 + 2]]); index.push(i); }
  }
  const out = canvas();
  if (!pixels.length) return crayon.toRgba(out);
  const k = Math.min(COLOURS[layer] || 5, pixels.length);
  const centres = kmeans(pixels, k, random);
  let labels = new Int16Array(SMALL * SMALL).fill(-1);
  pixels.forEach((p, i) => { labels[index[i]] = nearest(p, centres); });
  // Smooth the areas (majority of the 5x5 neighbourhood, three times) so they read as shapes, not speckle.
  for (let pass = 0; pass < 3; pass++) {
    const next = labels.slice();
    for (let y = 2; y < SMALL - 2; y++) {
      for (let x = 2; x < SMALL - 2; x++) {
        const i = y * SMALL + x;
        if (labels[i] < 0) continue;
        const votes = {};
        for (let dy = -2; dy <= 2; dy++) for (let dx = -2; dx <= 2; dx++) {
          const l = labels[i + dy * SMALL + dx];
          if (l >= 0) votes[l] = (votes[l] || 0) + 1;
        }
        let best = labels[i], most = 0;
        for (const l in votes) if (votes[l] > most) { most = votes[l]; best = +l; }
        next[i] = best;
      }
    }
    labels = next;
  }
  const labelAt = (x, y) => {
    const sx = Math.min(SMALL - 1, Math.max(0, Math.floor(x / SCALE))), sy = Math.min(SMALL - 1, Math.max(0, Math.floor(y / SCALE)));
    return labels[sy * SMALL + sx];
  };
  const alphaAt = (x, y) => x >= 0 && y >= 0 && x < SIZE && y < SIZE && image.rgba[(Math.floor(y) * SIZE + Math.floor(x)) * 4 + 3] > 128;

  // The crayon size follows the shape's size: small things (eyes) get fine strokes.
  let x0 = SIZE, y0 = SIZE, x1 = 0, y1 = 0;
  for (const i of index) { const x = i % SMALL, y = Math.floor(i / SMALL); x0 = Math.min(x0, x); y0 = Math.min(y0, y); x1 = Math.max(x1, x); y1 = Math.max(y1, y); }
  const extent = Math.hypot(x1 - x0, y1 - y0) * SCALE;
  const hatch = Math.max(7, Math.min(24, extent / 40)), outline = Math.max(6, Math.min(20, extent / 50));

  // Each area coloured in, biggest first: hatching in two directions, only where the area is.
  const areas = centres.map((c, j) => ({ j, colour: crayonColour(c), size: labels.filter((l) => l === j).length }))
    .sort((a, b) => b.size - a.size);
  for (const area of areas) {
    for (const [angle, strength] of [[0.6, 0.8], [1.8, 0.5]]) {
      const dx = Math.cos(angle), dy = Math.sin(angle), nx = -dy, ny = dx, reach = SIZE * 0.75;
      for (let offset = -reach; offset <= reach; offset += hatch * 0.8) {
        const shade = 0.9 + random() * 0.18, tone = area.colour.map((v) => Math.min(255, v * shade));
        let run = [];
        for (let t = -reach; t <= reach; t += 3) {
          const x = SIZE / 2 + nx * offset + dx * t, y = SIZE / 2 + ny * offset + dy * t;
          if (alphaAt(x, y) && labelAt(x, y) === area.j) run.push([x, y]);
          else if (run.length) { if (run.length > 1) stroke(out, run, hatch, tone, strength, random); run = []; }
        }
        if (run.length > 1) stroke(out, run, hatch, tone, strength, random);
      }
    }
  }
  // Outlines: the shape's edge thick; borders between areas thin, and only between clearly different colours (a hue
  // or a big brightness change, not a colour's light and shaded parts).
  const apart = centres.map((a) => centres.map((b) => {
    const la = 0.3 * a[0] + 0.59 * a[1] + 0.11 * a[2], lb = 0.3 * b[0] + 0.59 * b[1] + 0.11 * b[2];
    const ca = a.map((v) => v - la), cb = b.map((v) => v - lb);
    return Math.hypot(ca[0] - cb[0], ca[1] - cb[1], ca[2] - cb[2]) > 45 || Math.abs(la - lb) > 90;
  }));
  const step = Math.max(2, Math.round(outline / 4));
  for (let y = step; y < SIZE - step; y += step) {
    for (let x = step; x < SIZE - step; x += step) {
      if (!alphaAt(x, y)) continue;
      const edge = !alphaAt(x - step, y) || !alphaAt(x + step, y) || !alphaAt(x, y - step) || !alphaAt(x, y + step);
      if (edge && layer !== "Background") { dab(out, x, y, outline / 2, OUTLINE, 0.55); continue; }
      const l = labelAt(x, y);
      const right = labelAt(x + SCALE, y), below = labelAt(x, y + SCALE);
      if (l >= 0 && (right >= 0 && right !== l && apart[l][right]) || (l >= 0 && below >= 0 && below !== l && apart[l][below])) dab(out, x, y, outline / 4, OUTLINE, 0.35);
    }
  }
  return crayon.toRgba(out);
}

// Every layer file (with its folders) under the art folder.
function walk(dir, rel = "") {
  return fs.readdirSync(path.join(dir, rel), { withFileTypes: true }).flatMap((e) =>
    e.isDirectory() ? walk(dir, path.join(rel, e.name)) : e.name.endsWith(".png") ? [path.join(rel, e.name)] : []);
}
fs.mkdirSync(OUT, { recursive: true });
const files = walk(SOURCE).filter((f) => f.includes(filter));
files.forEach((file, n) => {
  const rgba = crayonize(file, rng(4242 + n * 7919));
  fs.mkdirSync(path.join(OUT, path.dirname(file)), { recursive: true });
  writePng(path.join(OUT, file), SIZE, SIZE, rgba);
  process.stdout.write(`\r${n + 1}/${files.length} ${file}`.padEnd(90));
});
console.log();

// Preview: a few whole ogres, the original above its crayon twin.
const OGRES = [
  ["Background/Uncommon/moonlit-fairway.png", "Skin/Uncommon/moss.png", "Outfit/Uncommon/striped-pajamas.png",
    "Expression/Uncommon/moss/smug-smile.png", "Eyes/Uncommon/moss/heavy-bags.png", "Accessory/Rare/monocle.png", "Headwear/Rare/flower-crown.png"],
  ["Background/Uncommon/swamp-hot-spring.png", "Skin/Uncommon/swamp-green.png", "Outfit/Rare/onesie.png",
    "Expression/Uncommon/swamp-green/mouth-hanging-open.png", "Eyes/Uncommon/swamp-green/fully-asleep.png", "Accessory/Epic/floating-sheep.png",
    "Headwear/Uncommon/nightcap-with-pom-pom.png"],
  ["Background/Legendary/ghost-ship-cove.png", "Skin/Uncommon/mud-brown.png", "Outfit/Epic/pirate-captain-coat.png",
    "Expression/Epic/mud-brown/sea-dog-grin.png", "Eyes/Uncommon/mud-brown/heavy-bags.png", "Accessory/Epic/sleepy-parrot.png",
    "Headwear/Rare/captain-tricorn.png"],
];
const T = 320, sheet = Buffer.alloc(T * OGRES.length * T * 2 * 4);
function over(dst, src) {
  for (let i = 0; i < dst.length; i += 4) {
    const a = src[i + 3] / 255, b = dst[i + 3] / 255, o = a + b * (1 - a);
    if (!o) continue;
    for (let k = 0; k < 3; k++) dst[i + k] = Math.round((src[i + k] * a + dst[i + k] * b * (1 - a)) / o);
    dst[i + 3] = Math.round(o * 255);
  }
}
OGRES.forEach((layers, n) => {
  [SOURCE, OUT].forEach((root, row) => {
    const pic = Buffer.alloc(T * T * 4);
    for (const f of layers) {
      const p = path.join(root, f);
      if (fs.existsSync(p)) over(pic, Buffer.from(resample(decodePng(p), 0, 0, SIZE, SIZE, T, T)));
    }
    for (let y = 0; y < T; y++) pic.copy(sheet, ((row * T + y) * T * OGRES.length + n * T) * 4, y * T * 4, (y + 1) * T * 4);
  });
});
try { writePng(path.join(OUT, "preview.png"), T * OGRES.length, T * 2, sheet); } catch (e) { console.log("(preview.png is open elsewhere - not updated)"); }
console.log(`Wrote ${files.length} crayon layers to ${OUT}`);
