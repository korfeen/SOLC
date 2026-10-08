// Crayon picture layers: things the ogre drew himself, in the same crayon style as the icons (tools/make-role-icons.js),
// on the minting art's 1254x1254 canvas (the head's top near (627, 120)). Writes them to
// %USERPROFILE%\killtracker-art-extra\CrayonMints\<Layer>\<Rarity>\<name>.png, outside the minting art, to try out;
// move one into %USERPROFILE%\killtracker-art (same folders) to make it mintable (tools/convert-art.js). Also writes
// preview.png there: each one on a sample ogre, and ogre.png: a whole crayon ogre, one crayon layer of each kind.
// The crayon ogre's skin and outfit follow the real base layers' outlines (BASE_SKIN, BASE_OUTFIT), so they're the
// same size and in the same place; its eyes and grin sit where the real ones do.
// Usage: node tools/make-crayon-mints.js   No dependencies.

const fs = require("fs");
const os = require("os");
const path = require("path");
const crayon = require("./make-role-icons");
const { decodePng, resample } = require("./convert-art");

const SIZE = 1254;
crayon.setSize(SIZE);
const { canvas, dab, stroke, crayonShape, circle, ellipse, star, quad, rotate, hex, OUTLINE, rng, writePng } = crayon;
const OUT = path.join(os.homedir(), "killtracker-art-extra", "CrayonMints");
const ART = path.join(os.homedir(), "killtracker-art");
// Crayon on this canvas: about five times the icons' sizes (a picture shows at a fifth of this or less).
const LINE = 22, HATCH = 22;
const fill = (c, poly, color, random, options = {}) =>
  crayonShape(c, poly, color, random, { fit: true, line: LINE, hatch: HATCH, ...options });
const line = (c, points, width, color, random) => stroke(c, points, width, color, 0.95, random);

// --- Shapes from the real art: a layer's outline as a mask ----------------------------------------------

const BASE_SKIN = "Skin/Uncommon/moss.png", BASE_OUTFIT = "Outfit/Uncommon/striped-pajamas.png";
const masks = {};
function mask(file) {
  if (masks[file]) return masks[file];
  const image = decodePng(path.join(ART, file)), m = new Uint8Array(SIZE * SIZE);
  for (let i = 0; i < SIZE * SIZE; i++) m[i] = image.rgba[i * 4 + 3] > 128 ? 1 : 0;
  return (masks[file] = m);
}
const at = (m, x, y) => x >= 0 && y >= 0 && x < SIZE && y < SIZE && m[Math.floor(y) * SIZE + Math.floor(x)] === 1;
// Crayon hatching (two directions) wherever the mask is, and where keep(x, y) says, if given.
function maskFill(c, m, color, random, { hatch = HATCH, angle = 0.6, keep = () => true } = {}) {
  for (const [a, strength] of [[angle, 0.75], [angle + 1.2, 0.45]]) {
    const dx = Math.cos(a), dy = Math.sin(a), nx = -dy, ny = dx, reach = SIZE * 0.75;
    for (let offset = -reach; offset <= reach; offset += hatch * 0.85) {
      const shade = 0.88 + random() * 0.2, tone = color.map((v) => Math.min(255, v * shade));
      let run = [];
      for (let t = -reach; t <= reach; t += 3) {
        const x = SIZE / 2 + nx * offset + dx * t, y = SIZE / 2 + ny * offset + dy * t;
        if (at(m, x, y) && keep(x, y)) run.push([x, y]);
        else if (run.length) { if (run.length > 1) stroke(c, run, hatch, tone, strength, random); run = []; }
      }
      if (run.length > 1) stroke(c, run, hatch, tone, strength, random);
    }
  }
}
// The mask's edge in crayon: dabs along its border pixels (every few, so it doesn't pile up).
function maskOutline(c, m, width, color, random) {
  for (let y = 1; y < SIZE - 1; y += 3) {
    for (let x = 1; x < SIZE - 1; x += 3) {
      if (!m[y * SIZE + x]) continue;
      if (m[y * SIZE + x - 3] && m[y * SIZE + x + 3] && m[(y - 3) * SIZE + x] && m[(y + 3) * SIZE + x]) continue;
      dab(c, x + (random() - 0.5) * 2, y + (random() - 0.5) * 2, width / 2, color, 0.6);
    }
  }
}

const OGRE_GREEN = hex("#86c64e");
const LAYERS = [
  // The base: a crayon ogre body in the real skin's outline: green, a big nose, ears, belly button, loincloth.
  ["Skin", "Uncommon", "crayon-green", (c, r) => {
    const m = mask(BASE_SKIN);
    const loincloth = (x, y) => y >= 1085 && x > 250 && x < 1000;  // (the hands either side stay green)
    maskFill(c, m, OGRE_GREEN, r, { keep: (x, y) => !loincloth(x, y) });
    maskFill(c, m, hex("#8a5a2e"), r, { keep: loincloth });
    maskOutline(c, m, 18, OUTLINE, r);
    line(c, quad([300, 1085], [630, 1110], [960, 1085], 30), 16, OUTLINE, r);  // the loincloth's waistband
    fill(c, ellipse(632, 300, 46, 38), hex("#6fae3f"), r, { line: 16, hatch: 16 });  // nose
    for (const x of [614, 650]) fill(c, circle(x, 316, 7), OUTLINE, r, { outline: null, hatch: 6 });
    line(c, quad([500, 205], [480, 245], [505, 290], 10), 14, OUTLINE, r);  // ears
    line(c, quad([768, 215], [790, 255], [764, 298], 10), 14, OUTLINE, r);
    line(c, quad([470, 840], [630, 900], [800, 840], 20), 14, OUTLINE, r);  // chest
    line(c, quad([440, 1010], [630, 1060], [820, 1010], 20), 14, OUTLINE, r);  // belly
    fill(c, circle(630, 990, 12), OUTLINE, r, { outline: null, hatch: 8 });  // belly button
  }],
  // An outfit in the real pyjamas' outline: a red crayon jumper with a yellow zigzag band and big buttons.
  ["Outfit", "Uncommon", "crayon-jumper", (c, r) => {
    const m = mask(BASE_OUTFIT);
    const zig = (x) => 760 + 40 * Math.abs(((x / 80) % 2) - 1);
    maskFill(c, m, hex("#e8463a"), r, { keep: (x, y) => !(y > zig(x) - 40 && y < zig(x) + 40) });
    maskFill(c, m, hex("#ffd23f"), r, { keep: (x, y) => y > zig(x) - 40 && y < zig(x) + 40 });
    maskOutline(c, m, 18, OUTLINE, r);
    for (const y of [560, 920, 1080]) fill(c, circle(630, y, 22), hex("#4f86e8"), r, { line: 12, hatch: 12 });
  }],
  // A wide crayon grin with two tusks, where the real mouths are (any skin).
  ["Expression", "Uncommon", "crayon-grin", (c, r) => {
    line(c, quad([548, 350], [630, 392], [716, 350], 16), 14, OUTLINE, r);
    for (const x of [560, 700]) fill(c, [[x - 16, 358], [x + 16, 358], [x + 4, 312]], hex("#fff6dc"), r, { line: 10, hatch: 10 });
  }],
  // Sleepy crayon eyes, where the real eyes are (any skin): white with a pupil, heavy lids.
  ["Eyes", "Uncommon", "crayon-sleepy-eyes", (c, r) => {
    for (const x of [586, 704]) {
      fill(c, ellipse(x, 250, 36, 24), hex("#ffffff"), r, { line: 12, hatch: 12 });
      fill(c, circle(x, 258, 11), OUTLINE, r, { outline: null, hatch: 8 });
      line(c, [[x - 40, 244], [x + 40, 244]], 14, OUTLINE, r);  // the lid, half closed
    }
  }],
  // A paper crown, coloured in yellow with lopsided red and blue gems.
  ["Headwear", "Rare", "crayon-paper-crown", (c, r) => {
    const up = -40;
    fill(c, [[452, 210], [440, 70], [520, 140], [578, 34], [636, 128], [700, 30], [752, 132], [826, 60], [808, 214]]
      .map(([x, y]) => [x, y + up]), hex("#ffd23f"), r);
    fill(c, circle(560, 170 + up, 22), hex("#ff4a3a"), r, { line: 14, hatch: 12 });
    fill(c, circle(640, 168 + up, 24), hex("#4f86e8"), r, { line: 14, hatch: 12 });
    fill(c, circle(722, 172 + up, 22), hex("#5bd24a"), r, { line: 14, hatch: 12 });
  }],
  // A striped party hat, a bit crooked, with a pom-pom.
  ["Headwear", "Epic", "crayon-party-hat", (c, r) => {
    const hat = rotate([[548, 160], [622, 4], [702, 160]], 0.12, 625, 120);
    fill(c, hat, hex("#ff7fbf"), r);
    for (const t of [0.35, 0.65]) {
      const y = 160 - 156 * t, half = 77 * (1 - t);
      line(c, rotate([[625 - half, y], [625 + half, y]], 0.12, 625, 120), 26, hex("#4f86e8"), r);
    }
    fill(c, circle(...rotate([[622, 14]], 0.12, 625, 120)[0], 30), hex("#fff6dc"), r, { line: 26, hatch: 16 });
  }],
  // A big curly moustache drawn over the face.
  ["Accessory", "Uncommon", "drawn-on-moustache", (c, r) => {
    for (const side of [-1, 1]) {
      const curl = [[627, 300], ...quad([627, 300], [627 + side * 90, 270], [627 + side * 150, 330]).slice(1),
        ...quad([627 + side * 150, 330], [627 + side * 170, 360], [627 + side * 130, 352]).slice(1),
        ...quad([627 + side * 130, 352], [627 + side * 70, 330], [627, 336]).slice(1)];
      fill(c, curl, hex("#3a2a20"), r, { outline: null, hatch: 18 });
      line(c, [...curl, curl[0]], 22, OUTLINE, r);
    }
  }],
  // A pink heart doodled on the cheek.
  ["Accessory", "Uncommon", "cheek-heart-doodle", (c, r) => {
    const cx = 520, cy = 300, s = 1.1;
    const heart = [...quad([cx, cy + 50 * s], [cx - 64 * s, cy], [cx - 40 * s, cy - 34 * s]),
      ...quad([cx - 40 * s, cy - 34 * s], [cx - 16 * s, cy - 56 * s], [cx, cy - 22 * s]).slice(1),
      ...quad([cx, cy - 22 * s], [cx + 16 * s, cy - 56 * s], [cx + 40 * s, cy - 34 * s]).slice(1),
      ...quad([cx + 40 * s, cy - 34 * s], [cx + 64 * s, cy], [cx, cy + 50 * s]).slice(1)];
    fill(c, heart, hex("#ff5fa8"), r, { line: 22, hatch: 14 });
  }],
  // A sun with a sleepy face in the sky, its rays scribbled round it.
  ["Accessory", "Rare", "crayon-sun-buddy", (c, r) => {
    const cx = 200, cy = 200;
    for (let i = 0; i < 12; i++) {
      const a = (i / 12) * 2 * Math.PI;
      line(c, [[cx + Math.cos(a) * 130, cy + Math.sin(a) * 130], [cx + Math.cos(a) * 185, cy + Math.sin(a) * 185]], 28, hex("#ff9a2a"), r);
    }
    fill(c, circle(cx, cy, 108), hex("#ffd23f"), r);
    for (const x of [-38, 38]) line(c, quad([cx + x - 22, cy - 10], [cx + x, cy + 8], [cx + x + 22, cy - 10], 8), 14, OUTLINE, r);
    line(c, quad([cx - 34, cy + 44], [cx, cy + 64], [cx + 34, cy + 44], 10), 14, OUTLINE, r);
  }],
  // A fridge drawing for a background: a blue scribbled sky, green hills, a little house and flowers.
  ["Background", "Rare", "fridge-drawing", (c, r) => {
    fill(c, [[0, 0], [SIZE, 0], [SIZE, SIZE], [0, SIZE]], hex("#9fd2ff"), r, { outline: null, hatch: 30 });
    fill(c, [[0, 520], ...quad([0, 520], [300, 380], [640, 540], 30).slice(1), ...quad([640, 540], [980, 360], [SIZE, 470], 30).slice(1),
      [SIZE, SIZE], [0, SIZE]], hex("#7fd65a"), r, { hatch: 30 });
    fill(c, [[1010, 380], [1170, 380], [1170, 520], [1010, 520]], hex("#ff9a6a"), r);
    fill(c, [[980, 385], [1090, 270], [1200, 385]], hex("#d8322a"), r);
    fill(c, [[1070, 440], [1112, 440], [1112, 520], [1070, 520]], hex("#8a5a2e"), r, { line: 16, hatch: 14 });
    for (const [x, y, col] of [[70, 560, "#ff4a3a"], [190, 600, "#ffd23f"], [1080, 600, "#b07ae8"], [1190, 560, "#ff7fbf"]]) {
      line(c, [[x, y], [x, y + 110]], 16, hex("#3f8a2e"), r);
      for (let i = 0; i < 5; i++) {
        const a = (i / 5) * 2 * Math.PI;
        fill(c, circle(x + Math.cos(a) * 28, y + Math.sin(a) * 28, 22), hex(col), r, { line: 12, hatch: 12 });
      }
      fill(c, circle(x, y, 18), hex("#ffd23f"), r, { line: 12, hatch: 12 });
    }
    for (const [x, y] of [[180, 160], [1050, 130]]) fill(c, ellipse(x, y, 120, 48), hex("#ffffff"), r, { line: 16, hatch: 18 });
    for (let i = 0; i < 12; i++) {  // a corner sun
      const a = (i / 12) * 2 * Math.PI;
      line(c, [[90 + Math.cos(a) * 110, 330 + Math.sin(a) * 110], [90 + Math.cos(a) * 150, 330 + Math.sin(a) * 150]], 18, hex("#ff9a2a"), r);
    }
    fill(c, circle(90, 330, 90), hex("#ffd23f"), r);
  }],
];

// A sample ogre to show them on (moss skin, striped pyjamas, smug smile, heavy eyes; a background unless one of these
// is the background).
const OGRE = ["Skin/Uncommon/moss.png", "Outfit/Uncommon/striped-pajamas.png", "Expression/Uncommon/moss/smug-smile.png",
  "Eyes/Uncommon/moss/heavy-bags.png"];
const SKY = "Background/Uncommon/moonlit-fairway.png";
const THUMB = 256;
function over(dst, src) {  // straight alpha "over", RGBA buffers of the same size
  for (let i = 0; i < dst.length; i += 4) {
    const a = src[i + 3] / 255, b = dst[i + 3] / 255, out = a + b * (1 - a);
    if (!out) continue;
    for (let k = 0; k < 3; k++) dst[i + k] = Math.round((src[i + k] * a + dst[i + k] * b * (1 - a)) / out);
    dst[i + 3] = Math.round(out * 255);
  }
}
const small = (rgba) => Buffer.from(resample({ width: SIZE, height: SIZE, rgba }, 0, 0, SIZE, SIZE, THUMB, THUMB));
const base = Object.fromEntries([SKY, ...OGRE].map((f) => [f, small(decodePng(path.join(ART, f)).rgba)]));

const sheet = Buffer.alloc(THUMB * LAYERS.length * THUMB * 4);
LAYERS.forEach(([layer, rarity, name, draw], n) => {
  const c = canvas();
  draw(c, rng(1000 + n * 7919));
  const rgba = crayon.toRgba(c);
  const dir = path.join(OUT, layer, rarity);
  fs.mkdirSync(dir, { recursive: true });
  writePng(path.join(dir, name + ".png"), SIZE, SIZE, rgba);
  // On the sample ogre: background, then the ogre, then the item (or the item as the background).
  const pic = Buffer.alloc(THUMB * THUMB * 4);
  const item = small(rgba);
  over(pic, layer === "Background" ? item : base[SKY]);
  for (const f of OGRE) over(pic, base[f]);
  if (layer !== "Background") over(pic, item);
  for (let y = 0; y < THUMB; y++) pic.copy(sheet, (y * THUMB * LAYERS.length + n * THUMB) * 4, y * THUMB * 4, (y + 1) * THUMB * 4);
});
try { writePng(path.join(OUT, "preview.png"), THUMB * LAYERS.length, THUMB, sheet); } catch (e) { console.log("(preview.png is open elsewhere - not updated)"); }

// The whole crayon ogre: one crayon layer of each kind, stacked in the minting order.
{
  const order = ["Background/Rare/fridge-drawing", "Skin/Uncommon/crayon-green", "Outfit/Uncommon/crayon-jumper",
    "Expression/Uncommon/crayon-grin", "Eyes/Uncommon/crayon-sleepy-eyes", "Accessory/Uncommon/cheek-heart-doodle",
    "Headwear/Rare/crayon-paper-crown"];
  const big = 627, pic = Buffer.alloc(big * big * 4);
  for (const name of order) {
    const image = decodePng(path.join(OUT, name + ".png"));
    over(pic, Buffer.from(resample(image, 0, 0, SIZE, SIZE, big, big)));
  }
  try { writePng(path.join(OUT, "ogre.png"), big, big, pic); } catch (e) { console.log("(ogre.png is open elsewhere - not updated)"); }
}
console.log(`Wrote ${LAYERS.map((l) => l[2]).join(", ")} to ${OUT}`);
