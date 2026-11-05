// Painted props for the arcade's rooms (SOLC Survivors): things that stand on the floor as paper cutouts, like the
// ogres (billboards: always facing you). Codex paints a SHEET of a few of them in a row on green, in the room's own
// painting's style (that painting + one of our ogre pictures as references); the sheet is keyed and split into one
// cut-out picture per prop.
//
//   node tools/gen-arcade-props.js                 (the sheets not made yet)
//   node tools/gen-arcade-props.js smgy_graves_a   (one sheet, again)
//   node tools/gen-arcade-props.js smgy_graves_a --recut   (split the sheet already painted again; no Codex)
//
// Out: %USERPROFILE%\killtracker-art-extra\Arcade\props\<sheet>_<n>.png (cropped, at most 512 tall), the sheet and its
// raw painting beside them in sheets\. The mockup (tools/dreamrun-mock.js) serves them as /prop/<name>.png.

const fs = require("fs");
const os = require("os");
const path = require("path");
const { decodePng, resample } = require("./convert-art");
const { writePng } = require("./make-role-icons");
const { generate, ogre, load, save, ART } = require("./gen-art");

const OUT = path.join(os.homedir(), "killtracker-art-extra", "Arcade", "props");
const PAINTED = path.join(os.homedir(), "killtracker-art-extra", "Unlocks", "generated", "painted");
const STYLE = "in exactly the soft painted style of the reference images: smooth shading, gentle highlights, warm glowing light, " +
  "rich colour, a little stylised and cosy, no hard black outlines";
const CUT = "Each object stands on its own with clear green space all round it (they never touch or overlap), seen from the " +
  "front at eye level, standing upright, its bottom flat as if on the ground. Paint ONLY the objects, on a perfectly flat pure " +
  "green (#00FF00) background filling the rest of the picture. No ground, no grass patch under them, no shadow on the " +
  "background, no text, no people.";

// sheet: { room painting (style ref), how many, what, refs: real WoW screenshots (Arcade/props/refs) as LOOSE references }
const LOOSE = "The LAST reference image is a screenshot of the real place in the game: take the objects' shapes and key features from it, but paint them in OUR painted style, not a game-screenshot look.";
const SHEETS = {
  smgy_graves_a: { bg: "bg_smgy", count: 4, shape: "wide landscape, 2:1", prompt:
    `Four different old graveyard headstones from a gloomy monastery churchyard, side by side in one row, ${STYLE}. ` +
    "Weathered grey-blue stone with patches of moss and lichen, cracks and chipped edges, a little cool moonlight on one side " +
    "and warm candle glow on the other, like the churchyard in the first reference image. From left to right: a tall " +
    "round-topped headstone leaning slightly; a stone celtic cross with a ring; a wide square-shouldered headstone with a " +
    "carved sun emblem and a single melted candle on top; a small broken headstone, its top snapped off at an angle. " +
    "Blank faces: no letters or writing on them. " + CUT },
  smgy_trees: { bg: "bg_smgy", count: 4, shape: "wide landscape, 2:1", refs: ["Forlorn_Cloister.jpg"], prompt:
    `Four trees for a gloomy monastery churchyard at night, side by side in one row, ${STYLE}. From left to right: three tall, ` +
    "slim, dark green cypress trees (narrow flame-shaped columns of dense foliage on short trunks, each a little different in " +
    "height and lean), then one big old broad-leafed tree with a thick gnarled trunk and a wide dark canopy. Cool moonlight on " +
    "one side, a little warm glow on the other. " + LOOSE + " " + CUT },
  smgy_yard: { bg: "bg_smgy", count: 4, shape: "wide landscape, 2:1", refs: ["Chamber_of_Atonement.jpg"], prompt:
    `Four objects from the Scarlet Crusade's monastery graveyard and torture hall, side by side in one row, ${STYLE}. From left ` +
    "to right: a section of black wrought-iron cemetery fence with spiked posts, wider than tall; a corpse pyre, a pile of " +
    "stacked logs with a body wrapped in a pale shroud on top, not yet lit; a wooden pillory stocks on posts with three holes; " +
    "a wooden torture rack table with rope and an iron wheel crank. " + LOOSE + " " + CUT },
  smgy_tomb: { bg: "bg_smgy", count: 1, shape: "square", refs: ["Honors_Tomb.jpg"], prompt:
    `Honor's Tomb, a stone mausoleum in a gloomy monastery churchyard, ${STYLE}: pale grey stone, gothic, with pointed ` +
    "spires at its corners, a dark arched doorway, a short flight of wide stone steps up to it with stone balustrades, a " +
    "little moss and cobwebs, a rusty iron ornament on the roof. Seen from the front at eye level, the whole building in " +
    "the picture, standing on its own. " + LOOSE + " " + CUT },
  smlib_hall: { bg: "bg_smlib", count: 4, shape: "wide landscape, 2:1", refs: ["Gallery_of_Treasures.jpg"], prompt:
    `Four objects from the Scarlet Crusade's monastery library halls, side by side in one row, ${STYLE}. From left to right: ` +
    "a tall thin golden floor candelabra with five lit candles; a wooden reading lectern with a big open book on it; a framed " +
    "painting of a Scarlet Crusade knight in red and white standing on a wooden easel; a polished suit of plate armour with a " +
    "red tabard on a stand. " + LOOSE + " " + CUT },
  smlib_shelves: { bg: "bg_smlib", count: 4, shape: "wide landscape, 2:1", refs: ["Athenaeum.jpg"], prompt:
    `Four objects for the same monastery library, side by side in one row, ${STYLE}. From left to right: a tall dark wooden ` +
    "bookcase, wider than tall, packed with old books in red, blue, green and brown; a short wide wooden bookcase with books and " +
    "a few scrolls; a messy pile of stacked old books with a candle on top; a small wooden dog kennel with a red Scarlet " +
    "Crusade cloth over its doorway and a bone in front. " + LOOSE + " " + CUT },
  smgy_graves_b: { bg: "bg_smgy", count: 4, shape: "wide landscape, 2:1", prompt:
    `Four more churchyard grave markers for the same gloomy monastery graveyard, side by side in one row, ${STYLE}. ` +
    "Weathered grey-blue stone, moss, cracks, cool moonlight and a touch of warm candle glow, like the churchyard in the first " +
    "reference image. From left to right: a tall pointed gothic headstone with a carved arch; a rough wooden grave cross, " +
    "bound with rope, a faded red cloth tied on it; a stone angel statue with folded wings and bowed head on a small " +
    "pedestal; a short fat rounded headstone sunk at a tilt, with a skull carved on it. Blank: no letters or writing. " + CUT },
};

function references(work, bg) {
  const files = [];
  const room = path.join(PAINTED, bg + ".png");
  if (!fs.existsSync(room)) throw new Error("no painting " + room);
  const a = path.join(work, "ref_room.png"); save(a, load(room), 1024); files.push(a);
  // (and one of our pictures, an ogre in front of a background: the collection's painted look)
  const dir = path.join(ART, "Background", "Epic");
  const one = fs.readdirSync(dir).find((f) => f.endsWith(".png"));
  if (one) { const b = path.join(work, "ref_style.png"); save(b, ogre("painted", load(path.join(dir, one))), 1024); files.push(b); }
  return files;
}

// Green out: the screen and its fringe (the same key as the bounty board's pieces).
function keyGreen(rgba) {
  const out = Buffer.from(rgba);
  for (let i = 0; i < out.length; i += 4) {
    const r = out[i], g = out[i + 1], b = out[i + 2], spill = g - Math.max(r, b);
    if (spill > 90 && g > 150) { out[i + 3] = 0; continue; }
    if (spill > 25) { out[i + 3] = Math.round(out[i + 3] * Math.max(0, 1 - (spill - 25) / 65)); out[i + 1] = Math.max(r, b); }
  }
  return out;
}

// The sheet split into its props: the separate blobs of paint (found on a quarter-size grid, so a candle flame or a
// stray leaf joins its neighbour), the biggest `count` of them, left to right, each cropped to what's painted.
function split(width, height, rgba, count) {
  const q = 4, W = Math.ceil(width / q), H = Math.ceil(height / q), on = new Uint8Array(W * H), lab = new Int32Array(W * H).fill(-1);
  for (let y = 0; y < height; y++) for (let x = 0; x < width; x++) if (rgba[(y * width + x) * 4 + 3] > 60) on[((y / q) | 0) * W + ((x / q) | 0)] = 1;
  const blobs = [];
  for (let i = 0; i < W * H; i++) {
    if (!on[i] || lab[i] >= 0) continue;
    const st = [i], bb = { x0: W, y0: H, x1: 0, y1: 0, n: 0 }; lab[i] = blobs.length;
    while (st.length) { const p = st.pop(), x = p % W, y = (p / W) | 0; bb.n++; bb.x0 = Math.min(bb.x0, x); bb.x1 = Math.max(bb.x1, x); bb.y0 = Math.min(bb.y0, y); bb.y1 = Math.max(bb.y1, y);
      for (let dy = -2; dy <= 2; dy++) for (let dx = -2; dx <= 2; dx++) { const nx = x + dx, ny = y + dy, n = ny * W + nx; if (nx >= 0 && ny >= 0 && nx < W && ny < H && on[n] && lab[n] < 0) { lab[n] = blobs.length; st.push(n); } } }
    blobs.push(bb);
  }
  return blobs.sort((u, v) => v.n - u.n).slice(0, count).sort((u, v) => u.x0 - v.x0).map((bb) => {
    const x0 = bb.x0 * q, y0 = bb.y0 * q, x1 = Math.min(width - 1, bb.x1 * q + q - 1), y1 = Math.min(height - 1, bb.y1 * q + q - 1);
    const w = x1 - x0 + 1, h = y1 - y0 + 1, out = Buffer.alloc(w * h * 4);
    for (let y = 0; y < h; y++) rgba.copy(out, y * w * 4, ((y + y0) * width + x0) * 4, ((y + y0) * width + x1 + 1) * 4);
    return { width: w, height: h, rgba: out };
  });
}

function cut(name) {
  const sheet = SHEETS[name];
  const raw = path.join(OUT, "sheets", name + ".raw.png");
  const img = decodePng(raw);
  const keyed = keyGreen(img.rgba);
  writePng(path.join(OUT, "sheets", name + ".png"), img.width, img.height, keyed);
  const props = split(img.width, img.height, keyed, sheet.count);
  props.forEach((p, i) => {
    const k = Math.min(1, 512 / p.height), w = Math.max(1, Math.round(p.width * k)), h = Math.max(1, Math.round(p.height * k));
    const small = k < 1 ? Buffer.from(resample(p, 0, 0, p.width, p.height, w, h)) : p.rgba;
    writePng(path.join(OUT, `${name}_${i + 1}.png`), w, h, small);
  });
  console.log(`${name}: ${props.length}/${sheet.count} props cut -> ${OUT}`);
}

function make(name) {
  const sheet = SHEETS[name];
  const work = path.join(OUT, "work", name);
  fs.mkdirSync(work, { recursive: true });
  fs.mkdirSync(path.join(OUT, "sheets"), { recursive: true });
  const refs = references(work, sheet.bg);
  for (const r of sheet.refs || []) refs.push(path.join(OUT, "refs", r));  // (Codex takes the .jpg as it is)
  const file = generate(work, refs, sheet.prompt, name + ".png", sheet.shape);
  fs.copyFileSync(file, path.join(OUT, "sheets", name + ".raw.png"));
  cut(name);
}

if (require.main === module) {
  const only = process.argv[2] && !process.argv[2].startsWith("--") ? process.argv[2] : null;
  if (only && !SHEETS[only]) { console.log("No sheet " + only + ". Sheets: " + Object.keys(SHEETS).join(", ")); process.exit(1); }
  if (only && process.argv.includes("--recut")) { cut(only); return; }
  for (const name of only ? [only] : Object.keys(SHEETS)) {
    if (!only && fs.existsSync(path.join(OUT, "sheets", name + ".raw.png"))) { console.log(`${name}: there already`); continue; }
    try { make(name); } catch (e) { console.log(`${name}: FAILED ${e.message.split("\n")[0]}`); }
  }
}

module.exports = { SHEETS, OUT };
