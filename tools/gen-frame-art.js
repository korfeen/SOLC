// Picture frames (Frames.lua: a picture's frame, shown wherever it's drawn), painted by Codex in the room's style (the
// Dream Bed's concept and two of our backgrounds with the ogre as references, as tools/gen-dreambed-art.js). Each a
// square frame with a square opening, on green, the opening green too: both cut out (gen-art.js's key, enclosed green
// included), tools/convert-frames.js measures the opening. The polaroid is the pictures' look before frames: not
// painted here.
//   node tools/gen-frame-art.js          (the frames not made yet)
//   node tools/gen-frame-art.js <id>     (one again)
// Out: %USERPROFILE%\killtracker-art-extra\Frames\<id>.png
const fs = require("fs");
const os = require("os");
const path = require("path");
const { generate, ogre, load, save, key, ART } = require("./gen-art");

const OUT = path.join(os.homedir(), "killtracker-art-extra", "Frames");
const CONCEPT = path.join(os.homedir(), "killtracker-art-extra", "DreamBed", "concept.png");

const LOOK = "Match image 1's painting style exactly (soft, painterly cartoon, warm light, rich colour, bold dark outlines, chunky simple shapes - NOT realistic).";
const SHAPE = ["Seen perfectly straight on, flat, not turned or tilted. It's a SQUARE frame (exactly as wide as tall) filling most of the picture, its",
  "border about one eighth of the frame's width on every side, and the OPENING in its middle an exact SQUARE filled with perfectly flat",
  "pure green (#00FF00) - no picture, no glass, no backing in it. Everything outside the frame is the same flat pure green. No text."].join("\n");
// id: what it is. (Names and unlocks: tools/convert-frames.js.)
const FRAMES = {
  polaroid: "NOT a wooden frame: the white border of an instant photo (a polaroid): a clean, slightly off-white card border, thin on the top, left and right, and a much thicker white strip along the bottom (where you'd write on it). The whole thing a little taller than wide; the opening still an exact square.",
  wood: "A simple, sturdy picture frame of warm honey-coloured wood, like the bed and easel in image 1, its corners joined with little pegs.",
  taped: "NOT a frame: four strips of slightly crumpled masking tape, one across each corner of the square opening, as if a child's drawing was taped to a fridge. Only the four tape strips, nothing between them (all green); the opening is the square the tape corners hold.",
  gilded: "An ornate gilded picture frame: carved gold leaves and curls, a little worn, rich and shiny, like a painting in a noble's hall.",
  bone: "A gruesome-but-cute ogre-made frame built from big bones and tusks lashed together with leather cord at the corners, a little skull at the top middle.",
  dungeon: "A heavy dark iron frame with rivets and bands, a short rusty chain hanging from each top corner, like it came from a dungeon's wall.",
  driftwood: "A rustic frame of grey-brown driftwood sticks, a few seashells and a starfish stuck on its corners.",
};

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

const which = process.argv[2];
for (const id of which ? [which] : Object.keys(FRAMES)) {
  if (!FRAMES[id]) { console.log(id + ": no such frame"); continue; }
  const out = path.join(OUT, id + ".png");
  if (!which && fs.existsSync(out)) { console.log(id + ": there already"); continue; }
  const work = path.join(OUT, "work", id);
  fs.mkdirSync(work, { recursive: true });
  const refs = [path.join(work, "ref_0.png")];
  fs.copyFileSync(CONCEPT, refs[0]);
  refs.push(...StyleRefs(work));
  try {
    const raw = generate(work, refs, [LOOK, "Paint ONLY this picture frame: " + FRAMES[id], SHAPE].join("\n"), id + ".png", "square");
    fs.mkdirSync(OUT, { recursive: true });
    save(out, key(load(raw), false), 512);  // (the opening's green too)
    console.log(id + ": done");
  } catch (e) { console.log(id + ": FAILED " + e.message.split("\n")[0]); }
}
