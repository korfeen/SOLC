// The Pro Shop room repainted from the one it has: Codex edits that picture - only what the pass asks, every hotspot
// (the counter, the easel's spot) staying where it is. Codex paints 3:2, so the room goes in padded on the right (its
// last columns stretched) and comes back cut to it (827 x 584, tools/proshop-mock/img/).
//
//   node tools/gen-proshop-room.js <pass>            (Codex; then the check)
//   node tools/gen-proshop-room.js <pass> --check    (no Codex: cut and check what it made last)
//
// Passes (each from the one before): wallpaper (scene1 -> scene2: wallpaper rolls for the quilts, borders for the party
// favours, the counter's dome and jar gone), empty (scene2 -> scene3: the painted steward and the sewing corner gone -
// the steward is one of our ogres now, drawn over it, and the easel stands in the corner).
// Work: killtracker-art-extra/ProShop/repaint/<pass>/ (in.png padded, out.png Codex's, check.png: where it differs from
// the room before - the edits should be the only bright parts). To use one: point make-mannequin.js's SCENE at it.
const fs = require("fs");
const os = require("os");
const path = require("path");
const { decodePng, resample } = require("./convert-art");
const { writePng } = require("./make-role-icons");
const { generate } = require("./gen-art");

const ROOT = path.join(os.homedir(), "killtracker-art-extra", "ProShop", "repaint");
const IMG = path.join(__dirname, "proshop-mock", "img");
const KEEP = "EDIT image 1 itself - do not redraw the room. Keep the same painting style, light, camera, framing and size, and every" +
  " thing not listed below EXACTLY where and how it is.";

const PASSES = {
  wallpaper: {
    from: "scene1.png", to: "scene2.png", refs: ["wallpapers.png"],
    prompt: [
      "Image 1 is a painting of a posh country-club PRO SHOP with a snooty ogre steward behind the counter. Image 2 is a sheet",
      "of our shop's wallpapers (the six squares) and their matching borders (the strip under each square).",
      KEEP + " That means the steward ogre and his outfit, the sign, the lamps, the empty gold",
      "frames on the wall, the counter and its crest, the brass cash register, the sewing machine and table, the stool, the",
      "red curtain, the plants, the floor and the walls. Change ONLY these:",
      "1. The shelves on the LEFT: take away every quilt, blanket and the cushions; fill the same shelves instead with neat",
      "   stacks and rows of WALLPAPER ROLLS lying on their sides, rolls showing our wallpapers from image 2 on their paper,",
      "   a couple of rolls standing upright, all tidy like a decorating shop. The plaid blanket hanging off the shelf goes too.",
      "2. The small wall shelf on the RIGHT (rubber chickens, cupcakes, party crackers, baskets): take every party favour",
      "   away. On that shelf put a few WALLPAPER ROLLS standing upright and rolled-up BORDER strips (narrow rolls showing the",
      "   border patterns from image 2), and hang two or three unrolled border strips and a wallpaper sample on the green wall",
      "   beside it like a pattern display.",
      "3. On the counter: remove the glass dome and the glass jar of coins. The counter top is bare there (the brass cash",
      "   register stays).",
      "No text anywhere except the PRO SHOP sign as it is.",
    ],
  },
  empty: {
    from: "scene2.png", to: "scene3.png", refs: [],
    prompt: [
      "Image 1 is a painting of a posh country-club PRO SHOP.",
      KEEP + " That means the sign, the lamps, the empty gold frames, the wallpaper rolls on the",
      "left shelves, the wall shelf of rolls and the border strips on the right, the counter and its crest, the brass cash",
      "register, the red curtain, the plants, the floor and the walls. Change ONLY these:",
      "1. Remove the ogre standing behind the counter COMPLETELY - his head, monocle, body and arms. Behind the counter is",
      "   now just the empty shop: the green wooden wall and the dark wood panelling below it carry on there, plain, nothing",
      "   standing or hanging where he was (the counter and the cash register on it stay exactly as they are).",
      "2. Remove the whole sewing corner on the right: the sewing machine, its table with the embroidered cloth, the cotton",
      "   reels and the round stool. That corner is now EMPTY - the green wall, the panelling and the wooden floor carry on",
      "   there, clear, with room for something to stand on the floor later.",
      "No text anywhere except the PRO SHOP sign as it is. No people or creatures anywhere.",
    ],
  },
};

const name = process.argv[2], pass = PASSES[name];
if (!pass) throw new Error("Pass: " + Object.keys(PASSES).join(" | "));
const work = path.join(ROOT, name);
fs.mkdirSync(work, { recursive: true });

// (the room before, padded to 3:2 on the right)
const old = decodePng(path.join(IMG, pass.from));
const PW = Math.round(old.height * 1.5), PH = old.height;
if (!process.argv.includes("--check")) {
  const pad = Buffer.alloc(PW * PH * 4);
  for (let y = 0; y < PH; y++) for (let x = 0; x < PW; x++) {
    const sx = Math.min(x, old.width - 1);
    old.rgba.copy(pad, (y * PW + x) * 4, (y * old.width + sx) * 4, (y * old.width + sx) * 4 + 4);
  }
  writePng(path.join(work, "in.png"), PW, PH, pad);
  generate(work, [path.join(work, "in.png"), ...pass.refs.map((f) => path.join(ROOT, f))], pass.prompt.join("\n"), "out.png", "wide landscape, 3:2");
}

// Back to the padded size, cut to the room; and where it differs.
const raw = decodePng(path.join(work, "out.png"));
const back = Buffer.from(resample(raw, 0, 0, raw.width, raw.height, PW, PH));
const W = old.width, H = old.height, out = Buffer.alloc(W * H * 4), diff = Buffer.alloc(W * H * 4);
let far = 0;
for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
  const s = (y * PW + x) * 4, o = (y * W + x) * 4;
  back.copy(out, o, s, s + 4);
  const d = (Math.abs(back[s] - old.rgba[o]) + Math.abs(back[s + 1] - old.rgba[o + 1]) + Math.abs(back[s + 2] - old.rgba[o + 2])) / 3;
  if (d > 40) far++;
  const v = Math.min(255, d * 3);
  diff.set([v, v, v, 255], o);
}
writePng(path.join(IMG, pass.to), W, H, out);
writePng(path.join(work, "check.png"), W, H, diff);
console.log(`${pass.to} written; ${((far / (W * H)) * 100).toFixed(1)}% differs a lot from ${pass.from} (${path.join(work, "check.png")})`);
