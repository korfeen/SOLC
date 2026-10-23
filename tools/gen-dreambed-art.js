// The Dream Bed's painted room (DreamBed.lua), by Codex in the ogre pictures' style (two of our backgrounds with the
// ogre as the style references, as tools/gen-board-art.js), laid out like the scene: a layout guide drawn from
// DreamBed.lua's positions (the page area's 827x584, as fractions).
//   node tools/gen-dreambed-art.js concept     (the whole bedroom in one painting: the look to agree on first)
//   node tools/gen-dreambed-art.js pieces      (the game's pieces not made yet, the concept as their look; or one by name)
// The room is wide (its window glass painted pure green, cut out for the code's sky); the rest are painted on a green
// screen and cut out (gen-art.js's key), each a square piece: the bed in loose parts (headboard, pillow, quilt: other
// pillows and quilts later, cosmetics in the same slots), the easel (square canvas), the brush jar EMPTY (the tools you
// pull out of it: brush, coloured pencils, crayon), the candle and its flame apart, the mug, the storybook.
// Out: %USERPROFILE%\killtracker-art-extra\DreamBed\ (concept.png, layout.png, pieces\<name>.png).
const fs = require("fs");
const os = require("os");
const path = require("path");
const { generate, ogre, load, save, key, ART } = require("./gen-art");
const { writePng } = require("./make-role-icons");
const { decodePng } = require("./convert-art");

const OUT = path.join(os.homedir(), "killtracker-art-extra", "DreamBed");
const W = 827, H = 584;
// The layout (DreamBed.lua): [x, y, w, h] as fractions, a flat colour each for the guide.
const LAYOUT = [
  ["wall", [0, 0, 1, 0.62], [62, 46, 84]],
  ["floor", [0, 0.62, 1, 0.38], [86, 58, 38]],
  ["window", [0.06, 0.07, 0.24, 0.37], [40, 70, 160]],
  ["headboard", [0.04, 0.45, 0.46, 0.26], [130, 86, 50]],
  ["pillow", [0.07, 0.52, 0.23, 0.14], [240, 236, 248]],
  ["quilt", [0.02, 0.6, 0.5, 0.36], [140, 90, 168]],
  ["nightstand", [0.52, 0.64, 0.17, 0.32], [100, 66, 38]],
  ["candle", [0.54, 0.51, 0.032, 0.13], [245, 235, 215]],
  ["mug", [0.585, 0.55, 0.055, 0.09], [235, 225, 205]],
  ["storybook", [0.635, 0.52, 0.085, 0.13], [150, 40, 50]],
  ["easel", [0.66, 0.06, 0.3, 0.9], [150, 100, 55]],
  ["canvas", [0.672, 0.08, 0.276, 0.39], [245, 240, 225]],
];
function LayoutGuide(file) {
  const px = Buffer.alloc(W * H * 4);
  for (const [, [x, y, w, h], c] of LAYOUT) {
    const x0 = Math.round(x * W), y0 = Math.round(y * H), x1 = Math.round((x + w) * W), y1 = Math.round((y + h) * H);
    for (let yy = y0; yy < Math.min(H, y1); yy++) for (let xx = x0; xx < Math.min(W, x1); xx++) {
      const i = (yy * W + xx) * 4;
      px[i] = c[0]; px[i + 1] = c[1]; px[i + 2] = c[2]; px[i + 3] = 255;
    }
  }
  fs.mkdirSync(path.dirname(file), { recursive: true });
  writePng(file, W, H, px);
  return file;
}
function StyleRefs(work) {
  const files = [], backdrops = [];
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

const STYLE = "in the same soft, painterly cartoon style as the reference pictures (smooth painting, gentle highlights, warm light, rich colour, dark outlines)";
const CONCEPT = [
  `A cosy bedroom at night in an ogre's leisure club, ${STYLE}. Lay it out EXACTLY like image 1 (the layout guide: each flat`,
  "colour block is where that thing goes, the same place and size): top left a wooden-framed window (cross bars) showing a deep",
  "blue night sky with a moon and stars; below it a big wooden bed seen from the front-left: a carved headboard, a big soft",
  "pillow, and a thick patchwork quilt pulled up high, the bed EMPTY (nobody in it: an ogre is added later; leave the pillow",
  "clear); right of the bed a small wooden nightstand with a lit candle (warm glow), a big ceramic mug and a red storybook with",
  "a gold star on its cover; on the right a painter's wooden easel holding a BLANK canvas (completely empty, cream), a paint",
  "palette and brushes on its ledge. Warm candlelight on a dark purple wall, a wooden floor with a round rug. Seen straight on,",
  "like a stage set. No people, no text.",
].join("\n");
// The game's pieces: the concept (image 1) is the look to match; one thing each.
const LOOK = "Match image 1 (our bedroom painting) EXACTLY in style, colours, wood and light: this is one piece of that same room.";
const GREEN = "Put it on a perfectly flat pure green (#00FF00) background, the whole object in the picture, nothing cut off, nothing else in the picture.";
const PIECES = {
  room: { wide: true, prompt: [LOOK, "Paint the SAME bedroom again laid out like image 2 (the layout guide), but EMPTY, no furniture at all:",
    "the purple wall, the wooden-framed window with its cross bars. NOTHING else: NO nightstand, NO bed,",
    "NO easel, NO rug, NO candle, NO mug, NO book on the nightstand (its top bare). The window's GLASS panes filled with",
    "perfectly flat pure green (#00FF00) - no sky, no moon, no trees in them. The WHOLE FLOOR (everything below the wall's",
    "bottom edge) is ALSO perfectly flat pure green (#00FF00): no floorboards, no shadows on it. NO candle glow and NO bright spot on the wall: the room evenly and",
    "softly lit, a calm dusky light all over (the game adds the candle's glow itself).",
    "No people, no text."].join("\n") },
  floor: { wide: true, prompt: [LOOK, "Paint ONLY the room's wooden floor from image 1, filling the WHOLE picture edge to edge: warm wooden",
    "floorboards seen from the same angle and height as in image 1 (a stage floor, boards running back towards the wall), softly",
    "lit. NO rug, NO furniture, NO wall, nothing standing on it. No people, no text."].join("\n") },
  rug: { prompt: [LOOK, "Paint ONLY the round braided rug from image 1, lying flat on the floor seen from the same angle as in image 1",
    "(a wide, flat oval, seen from the front and a little from above), its braided rings in warm colours. " + GREEN].join("\n") },
  nightstand: { prompt: [LOOK, "Paint ONLY the small wooden nightstand from image 1, seen from the same angle, its top BARE (no candle,",
    "no mug, no book, nothing on it), standing on its legs. " + GREEN].join("\n") },
  headboard: { prompt: [LOOK, "Paint ONLY the bed's carved wooden headboard and bed frame from image 1, seen from the front: the headboard with its",
    "posts, and the wooden bed frame below, with NO pillow, NO quilt, NO mattress showing (just the wooden bed). " + GREEN].join("\n") },
  pillow: { prompt: [LOOK, "Paint ONLY one big soft white pillow like the one in image 1, seen from the front, lying flat. " + GREEN].join("\n") },
  quilt: { prompt: [LOOK, "Paint ONLY the thick patchwork quilt from image 1 (purples, reds, oranges, creams, stitched squares), as if pulled up",
    "over a bed and seen from the front: its top edge folded over a little, hanging down the bed's front. Wide and soft. " + GREEN].join("\n") },
  easel: { prompt: [LOOK, "Paint ONLY the wooden painter's easel from image 1, holding a BLANK SQUARE canvas (exactly as wide as tall, completely",
    "empty, cream), a paint palette on its ledge (no brush jar). " + GREEN].join("\n") },
  jar: { prompt: [LOOK, "Paint ONLY the little blue-and-cream ceramic brush jar from image 1, EMPTY (no brushes in it). " + GREEN].join("\n") },
  brush: { prompt: [LOOK, "Paint ONLY one paintbrush like those in image 1, upright, its bristles dipped in a little paint. " + GREEN].join("\n") },
  pencils: { prompt: [LOOK, "Paint ONLY ONE coloured pencil (a single blue one, sharpened, a little worn), upright. " + GREEN].join("\n") },
  crayon: { prompt: [LOOK, "Paint ONLY one big fat red wax crayon with a paper wrapper, upright, a little worn at the tip. " + GREEN].join("\n") },
  candle: { prompt: [LOOK, "Paint ONLY the candle from image 1 in its metal holder, NOT lit (no flame, just the wick). " + GREEN].join("\n") },
  flame: { prompt: [LOOK, "Paint ONLY a small candle flame, warm yellow-orange with a soft glow, like the one in image 1. " + GREEN].join("\n") },
  // (the Bonk: he sleeps once a day, then it's the mallet)
  mallet: { prompt: [LOOK, "Paint ONLY a big, chunky wooden mallet, the kind a cartoon ogre would keep by his bed: a fat round wooden head",
    "bound with iron bands, a little cloth bandage wrapped round it (for the gentle bonks), a long wooden handle, standing upright",
    "on its head, the handle up, seen from the side at the same eye level as image 1. Bold dark outlines, chunky simple shapes,",
    "painterly - NOT realistic. " + GREEN].join("\n") },
  // (what the mallet hangs on, on the wall)
  peg: { prompt: [LOOK, "Paint ONLY a small wooden wall peg like on a cabin wall: a short round wooden dowel with a rounded knob on its end,",
    "sticking straight out of the wall towards the viewer, seen from the front and a little from the side, with a small square",
    "wooden plate behind it where it's nailed to the wall. Bold dark outlines, chunky simple shapes, painterly - NOT realistic. " + GREEN].join("\n") },
  // (the "mug" slot holds the warm milk: the concept's mug, full of it)
  mug: { prompt: [LOOK, "Paint ONLY the blue-and-cream ceramic mug from image 1, FULL of warm white milk: tipped a little towards the viewer",
    "so the creamy white milk and a little froth show at its top, a soft curl of steam rising from it, its handle on the right.",
    "Cartoon game style like the candle in image 1: bold dark outlines, chunky simple shapes, painterly - NOT realistic. " + GREEN].join("\n") },
  book: { prompt: [LOOK, "Paint ONLY the red storybook with the gold star (the one in image 1), closed and LYING FLAT, like a book lying on a",
    "table in a cartoon game, seen from the front and about 30 degrees from above: the red cover on top is a clear TRAPEZOID,",
    "wider at its front edge than at its back, the gold star on it easy to read; along the front a strip of cream page edges; a",
    "wide red ribbon bookmark hanging down over the front. Level and NOT turned: its front edge runs straight left to right.",
    "Bold dark outlines, chunky simple shapes, painterly - NOT realistic. " + GREEN].join("\n") },
};

function Run(name, prompt, refsFirst, wide) {
  const work = path.join(OUT, "work", name);
  fs.mkdirSync(work, { recursive: true });
  const refs = refsFirst.map((file, i) => { const to = path.join(work, "ref_" + i + ".png"); fs.copyFileSync(file, to); return to; });
  refs.push(...StyleRefs(work));
  return generate(work, refs, prompt, name + ".png", wide ? "wide landscape, about 3:2" : "square");
}

const which = process.argv[2] || "concept";
const guide = LayoutGuide(path.join(OUT, "layout.png"));
if (which === "concept") {
  try { fs.copyFileSync(Run("concept", CONCEPT, [guide], true), path.join(OUT, "concept.png")); console.log("Made concept.png"); }
  catch (e) { console.log("FAILED: " + e.message.split("\n")[0]); }
} else {
  const names = which === "pieces" ? Object.keys(PIECES) : [which];
  const concept = path.join(OUT, "concept.png");
  for (const name of names) {
    const piece = PIECES[name];
    if (!piece) { console.log(name + ": no such piece"); continue; }
    const out = path.join(OUT, "pieces", name + ".png");
    if (which === "pieces" && fs.existsSync(out)) { console.log(name + ": there already"); continue; }
    try {
      const raw = Run(name, piece.prompt, piece.wide ? [concept, guide] : [concept], piece.wide);
      fs.mkdirSync(path.dirname(out), { recursive: true });
      if (piece.wide) {  // (the window's green glass cut out; the room keeps its shape)
        const img = decodePng(raw), px = Buffer.from(img.rgba);
        for (let i = 0; i < px.length; i += 4) if (px[i + 1] - Math.max(px[i], px[i + 2]) > 40) px[i + 3] = 0;
        writePng(out, img.width, img.height, px);
      } else {
        save(out, key(load(raw), true), 512);
      }
      console.log(name + ": done");
    } catch (e) { console.log(name + ": FAILED " + e.message.split("\n")[0]); }
  }
}
