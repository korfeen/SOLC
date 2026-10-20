// The bounty board screen's art (HuntsBoard.lua), painted by Codex in the ogre pictures' style (two of our pictures as
// the style references): the board backdrop (wide, the whole screen) and the pieces cut out of a green screen (a blank
// poster sheet, a pin, the CLAIMED stamp, the title plank, the counter bar's trough, its molten gold and the gold's front, the
// guild chest).
//
//   node tools/gen-board-art.js            (the ones not made yet)
//   node tools/gen-board-art.js stamp      (one, again)
//   node tools/gen-board-art.js stamp --recut   (from its painting already made: only the game's .blp, again)
//
// Out: Media\Bounty\<name>.blp and %USERPROFILE%\killtracker-art-extra\Bounty\<name>.png (the full painting).

const fs = require("fs");
const os = require("os");
const path = require("path");
const { decodePng, resample, writeBlp } = require("./convert-art");
const { writePng } = require("./make-role-icons");
const { generate, ogre, load, save, key, ART } = require("./gen-art");

const OUT = path.join(os.homedir(), "killtracker-art-extra", "Bounty");
const MEDIA = path.join(__dirname, "..", "Media", "Bounty");
const STYLE = "in exactly the soft painted style of the reference images: smooth shading, gentle highlights, warm lighting, " +
  "rich colour, a little stylised and cute";
const CUT = "Paint ONLY that object, nothing else, on a perfectly flat pure green (#00FF00) background that fills the rest of the " +
  "picture. No shadow on the background, no text unless asked.";
// name: { what to paint, cut out of green?, shape, size in the game (w, h: powers of two) }
const PIECES = {
  backdrop: { size: [1024, 1024], shape: "wide landscape, 3:2", prompt:
    `A big wooden bounty board hanging on the wall inside a cozy fantasy tavern, ${STYLE}. The board fills almost the whole ` +
    "picture: a large flat panel of weathered dark oak planks with a sturdy carved wooden frame, iron corner brackets, a few " +
    "old nail holes and scraps of torn paper, completely EMPTY (no posters, no papers pinned on it, no text). Around its " +
    "edges a little of the tavern: warm lantern light from both sides, stone wall, a shelf with mugs. Seen straight from " +
    "the front, evenly lit across the panel." },
  poster: { cut: true, size: [256, 512], shape: "tall portrait, 2:3", prompt:
    `A single blank sheet of old wanted-poster paper, ${STYLE}: aged yellowed parchment, slightly torn and curled edges, a few ` +
    "stains and creases, standing upright, seen straight from the front, filling most of the height. Completely blank: no " +
    `text, no drawing on it. ${CUT}` },
  // Where a poster was torn off its nail (the read poster wears it instead of the pin).
  rip: { cut: true, size: [64, 64], prompt:
    `A small ragged hole torn in a sheet of old yellowed parchment, where a nail was pulled through it when the paper was ` +
    `ripped off a board, ${STYLE}, seen straight from the front, big and centred. The hole itself is dark brown-black shadow; ` +
    "around it a narrow ring of torn, frayed and slightly curled paper fibres, a short tear running up from the hole. " +
    `Paint ONLY the hole and its torn ring: everything else, even the rest of the paper, is flat pure green (#00FF00). ${CUT}` },
  // An officer's own poster's marks (HuntsBoard.lua): timed (it comes down on a timer) and limited (a few claims).
  hourglass: { cut: true, size: [64, 64], prompt:
    `A small old wooden hourglass with brass fittings and golden sand running, ${STYLE}, upright, seen from the front, big ` +
    `and centred. ${CUT}` },
  seal: { cut: true, size: [64, 64], prompt:
    `A single round blob of red sealing wax pressed onto paper, ${STYLE}: a thick round seal with uneven drippy edges and a ` +
    `smooth, flat, completely blank middle (no emblem, no letters), seen straight from the front, big and centred. ${CUT}` },
  pin: { cut: true, size: [64, 64], prompt:
    `A single round iron nail head with a little brass, as it pins a paper to a board, ${STYLE}, seen from the front, big and ` +
    `centred. ${CUT}` },
  stamp: { cut: true, size: [256, 128], shape: "wide landscape, 2:1", prompt:
    `A red ink rubber-stamp mark that says CLAIMED in big bold capital letters inside a rectangular border, stamped at a slight ` +
    `angle, ink a little uneven and faded at the edges like a real stamp, ${STYLE}. Only the red ink mark. ${CUT}` },
  plank: { cut: true, size: [512, 128], shape: "wide landscape, 3:1", prompt:
    `A single long wooden sign plank, ${STYLE}: warm oak with a carved border, two iron nails at the ends, a little worn. ` +
    `Completely blank: no text. Seen straight from the front, filling the width. ${CUT}` },
  barframe: { cut: true, size: [1024, 64], shape: "very wide landscape, 4:1", prompt:
    `A long empty horizontal progress-bar frame for a game, ${STYLE}: a carved dark wooden trough with iron end caps and rivets, ` +
    "its inside an empty dark groove running the whole length, seen straight from the front, filling the whole width, thin and " +
    `long. No text. ${CUT}` },
  // The counter bar's trough as a crossbeam of the board's own frame (the backdrop as a reference): its slot cut
  // through to the green, so the gold behind shows through it; cropped to the beam, the slot's box printed (for
  // HuntsBoard.lua's SLOT).
  beam: { cut: true, crop: true, size: [1024, 64], shape: "very wide landscape, 3:1", refs: ["backdrop.png"], prompt:
    `One long, thin horizontal wooden crossbeam, ${STYLE}, made of exactly the same weathered warm oak as the thick beams of the ` +
    "board's frame in the third reference image (same colour, grain, worn edges and lighting). It is very long and thin " +
    "(about 14 times as long as it is tall) and fills the whole width of the picture, end to end. Its ends are plain cut " +
    "wood: NO metal, NO iron caps, NO rivets, NO nails, no brackets. Along its middle runs one long slot with rounded ends, " +
    "cut cleanly all the way through the beam, about half the beam's height, from near one end to near the other; through " +
    "the slot the flat pure green (#00FF00) background shows. The slot's edges are bevelled wood, a little darker inside. " +
    `Seen straight from the front. ${CUT}` },
  barfill: { cut: true, size: [512, 32], shape: "very wide landscape, 4:1", prompt:
    `A long thin horizontal strip of glowing warm molten gold, like thick honey with little bright highlights and bubbles, ${STYLE}, ` +
    `filling the whole width edge to edge, even along its length. No frame. ${CUT}` },
  barhead: { cut: true, size: [128, 64], shape: "wide landscape, 2:1", refs: ["barfill.png"], fadeLeft: 0.3, prompt:
    `The leading front end of a thick stream of glowing molten gold magma slowly flowing to the right, seen from the side, ${STYLE}, ` +
    "the same colour and look as the third reference image (that molten gold strip). Its LEFT edge is cut off perfectly straight " +
    "and vertical, top to bottom, as if the stream continues to the left; its RIGHT side is the rounded, bulging, blobby front " +
    "of the flow, a little taller than the stream, with a darker orange-red cooling crust along its edge, a very bright hot " +
    "yellow-white core, a few bubbles and a small drip. Filling the picture's height, the cut left edge at the picture's left " +
    `edge. ${CUT}` },
  chest: { cut: true, size: [128, 128], prompt:
    `A small sturdy treasure chest with purple and gold trim and a skull-and-crossed-axes guild emblem, lid shut, glowing a ` +
    `little, ${STYLE}, seen from the front, big and centred. ${CUT}` },
};

function references(work) {
  const files = [];
  const backdrops = [];
  for (const rarity of ["Legendary", "Epic"]) {
    const dir = path.join(ART, "Background", rarity);
    for (const f of fs.existsSync(dir) ? fs.readdirSync(dir) : []) if (f.endsWith(".png")) backdrops.push(path.join(dir, f));
  }
  backdrops.slice(0, 2).forEach((bg, i) => {
    const file = path.join(work, `ref_style_${i + 1}.png`);
    save(file, ogre("painted", load(bg)), 1024);
    files.push(file);
  });
  return files;
}

function make(name) {
  const piece = PIECES[name];
  const work = path.join(OUT, "work", name);
  fs.mkdirSync(work, { recursive: true });
  const refs = references(work).concat((piece.refs || []).map(r => path.join(OUT, r)));
  const raw = generate(work, refs, piece.prompt, name + ".png", piece.shape);
  const img = decodePng(raw);
  let rgba = Buffer.from(img.rgba);
  if (piece.cut) {
    // (keyed at its own size: key() works on the art canvas, so one row at a time is fine for any size)
    const keyed = Buffer.from(rgba);
    for (let i = 0; i < keyed.length; i += 4) {
      const r = keyed[i], g = keyed[i + 1], b = keyed[i + 2];
      const spill = g - Math.max(r, b);
      if (spill > 90 && g > 150) { keyed[i + 3] = 0; continue; }
      if (spill > 25) { keyed[i + 3] = Math.round(keyed[i + 3] * Math.max(0, 1 - (spill - 25) / 65)); keyed[i + 1] = Math.max(r, b); }
    }
    rgba = keyed;
  }
  fs.mkdirSync(OUT, { recursive: true });
  writePng(path.join(OUT, name + ".png"), img.width, img.height, rgba);
  finish(name, img.width, img.height, rgba);
}

// To the box of what's painted (alpha over 40); the slot (a hole in the middle row): its box, in fractions.
function crop(width, height, rgba) {
  let x0 = width, y0 = height, x1 = -1, y1 = -1;
  for (let y = 0; y < height; y++) for (let x = 0; x < width; x++) {
    if (rgba[(y * width + x) * 4 + 3] > 40) { x0 = Math.min(x0, x); x1 = Math.max(x1, x); y0 = Math.min(y0, y); y1 = Math.max(y1, y); }
  }
  const w = x1 - x0 + 1, h = y1 - y0 + 1;
  const out = Buffer.alloc(w * h * 4);
  for (let y = 0; y < h; y++) rgba.copy(out, y * w * 4, ((y + y0) * width + x0) * 4, ((y + y0) * width + x1 + 1) * 4);
  const clear = (x, y) => out[(y * w + x) * 4 + 3] < 128;
  const mid = Math.floor(h / 2);
  let l = -1, r = -1;
  for (let x = Math.floor(w * 0.03); x < w * 0.97; x++) if (clear(x, mid)) { if (l < 0) l = x; r = x; }
  const cx = Math.floor((l + r) / 2);
  let t = mid, b = mid;
  while (t > 0 && clear(cx, t - 1)) t--;
  while (b < h - 1 && clear(cx, b + 1)) b++;
  const f = (v, n) => (v / n).toFixed(4);
  console.log(`cropped to ${w}x${h}; slot: left ${f(l, w)} right ${f(r + 1, w)} top ${f(t, h)} bottom ${f(b + 1, h)}`);
  return { width: w, height: h, rgba: out };
}

// The painting (keyed) to the game's size; fadeLeft: its left part fades in (the bar's front over the gold's end).
function finish(name, width, height, rgba) {
  const piece = PIECES[name];
  if (piece.crop) ({ width, height, rgba } = crop(width, height, rgba));
  const img = { width, height };
  if (piece.fadeLeft) {
    rgba = Buffer.from(rgba);
    const edge = Math.round(width * piece.fadeLeft);
    for (let y = 0; y < height; y++) for (let x = 0; x < edge; x++) {
      const i = (y * width + x) * 4 + 3;
      rgba[i] = Math.round(rgba[i] * (x / edge));
    }
  }
  const [w, h] = piece.size;
  const small = Buffer.from(resample({ width: img.width, height: img.height, rgba }, 0, 0, img.width, img.height, w, h));
  fs.mkdirSync(MEDIA, { recursive: true });
  writeBlp(path.join(MEDIA, name + ".blp"), w, h, small);
  writePng(path.join(OUT, name + "_small.png"), w, h, small);
  console.log(`${name}: ${img.width}x${img.height} -> Media\\Bounty\\${name}.blp (${w}x${h})`);
}

if (require.main === module) {
  const only = process.argv[2];
  if (only && process.argv.includes("--recut")) {
    const img = decodePng(path.join(OUT, only + ".png"));
    finish(only, img.width, img.height, Buffer.from(img.rgba));
    return;
  }
  for (const name of only ? [only] : Object.keys(PIECES)) {
    if (!only && fs.existsSync(path.join(MEDIA, name + ".blp"))) { console.log(`${name}: there already`); continue; }
    try { make(name); } catch (e) { console.log(`${name}: FAILED ${e.message.split("\n")[0]}`); }
  }
}
