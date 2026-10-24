// The Pro Shop's painted scenes (the shop floor and the changing stall), laid out from tools/proshop-layout.json on the
// page area (827x584), as tools/gen-dreambed-art.js does the bedroom.
//   node tools/gen-proshop-art.js layout          (only the flat colour layout guides: layout-floor.png, layout-stall.png)
//   node tools/gen-proshop-art.js concept floor   (Codex paints the whole scene in one picture: the look to agree on first)
//   node tools/gen-proshop-art.js concept stall
// Out: %USERPROFILE%\killtracker-art-extra\ProShop\
const fs = require("fs");
const os = require("os");
const path = require("path");
const { writePng } = require("./make-role-icons");

const OUT = path.join(os.homedir(), "killtracker-art-extra", "ProShop");
const W = 827, H = 584;
const LAYOUTS = JSON.parse(fs.readFileSync(path.join(__dirname, "proshop-layout.json"), "utf8"));

function LayoutGuide(scene) {
  const px = Buffer.alloc(W * H * 4);
  for (const [, [x, y, w, h], c] of LAYOUTS[scene]) {
    const x0 = Math.round(x * W), y0 = Math.round(y * H), x1 = Math.round((x + w) * W), y1 = Math.round((y + h) * H);
    for (let yy = Math.max(0, y0); yy < Math.min(H, y1); yy++) for (let xx = Math.max(0, x0); xx < Math.min(W, x1); xx++) {
      const i = (yy * W + xx) * 4;
      px[i] = c[0]; px[i + 1] = c[1]; px[i + 2] = c[2]; px[i + 3] = 255;
    }
  }
  const file = path.join(OUT, `layout-${scene}.png`);
  fs.mkdirSync(OUT, { recursive: true });
  writePng(file, W, H, px);
  return file;
}

const STYLE = "in the same soft, painterly cartoon style as the reference pictures (smooth painting, gentle highlights, warm light, rich colour, dark outlines)";
const CONCEPT = {
  floor: [
    `The pro shop of a posh but rickety ogre country club, ${STYLE}. Lay it out EXACTLY like image 1 (the layout guide: each`,
    "flat colour block is where that thing goes, the same place and size): a carved wooden PRO SHOP sign at the top middle; on",
    "the left wall empty ornate picture frames hanging crooked, below them a shelf of neatly folded patchwork quilts and pillows;",
    "in the middle a snooty ogre steward behind a polished wooden counter (green skin, bow tie, waistcoat, monocle, nose in the",
    "air); on the counter a glass dome on a little stand (EMPTY under the dome), a glass tip jar with a 'CLUB DUES' label and an",
    "old brass till; top right a shelf of party favours",
    "(confetti poppers, cream pies, rubber chickens); bottom right a small sewing table with an old embroidery machine and",
    "spools of thread; at the far right edge a changing stall with a heavy red velvet curtain. Green wood-panelled walls,",
    "wooden floor, warm lamplight. Seen straight on, like a stage set. No text except the PRO SHOP sign.",
  ].join("\n"),
  stall: [
    `Inside a changing stall of a posh but rickety ogre country club's pro shop, ${STYLE}. Lay it out EXACTLY like image 1`,
    "(the layout guide: each flat colour block is where that thing goes, the same place and size): on the left a big standing",
    "mirror in a carved gilded wooden frame, its glass painted perfectly flat pure green (#00FF00, nothing reflected in it);",
    "in the middle an EMPTY spot of perfectly flat pure green (#00FF00) where a shop mannequin will be added later, with only",
    "a round wooden stand base on the floor under it; to the right a wooden hat stand, a clothes rail with hangers, below them",
    "a small glass display case, and a spinning postcard rack; between the mirror and the mannequin a little stool with an",
    "EMPTY wicker basket on it; on the right a heavy red velvet",
    "curtain, a snooty ogre steward (green skin, bow tie, monocle) poking his head in through its gap. Racks and stand",
    "EMPTY (no hats, no clothes, no cards: the game hangs those). Warm wood-panelled walls, wooden floor, soft lamplight.",
    "Seen straight on, like a stage set. No text.",
  ].join("\n"),
};

const [which = "layout", scene] = process.argv.slice(2);
if (which === "layout") {
  for (const s of Object.keys(LAYOUTS)) if (s !== "_") console.log("Made " + LayoutGuide(s));
} else if (which === "concept") {
  if (!CONCEPT[scene]) { console.log("concept floor | concept stall"); process.exit(1); }
  // (gen-art is loaded only here: the layout step needs no Codex)
  const { generate, ogre, load, save, ART } = require("./gen-art");
  const work = path.join(OUT, "work", "concept-" + scene);
  fs.mkdirSync(work, { recursive: true });
  const refs = [path.join(work, "ref_0.png")];
  fs.copyFileSync(LayoutGuide(scene), refs[0]);
  const backdrops = [];
  for (const rarity of ["Legendary", "Epic"]) {
    const dir = path.join(ART, "Background", rarity);
    for (const f of fs.existsSync(dir) ? fs.readdirSync(dir) : []) if (f.endsWith(".png")) backdrops.push(path.join(dir, f));
  }
  backdrops.slice(0, 2).forEach((bg, i) => {
    const file = path.join(work, `ref_style_${i + 1}.png`);
    save(file, ogre("painted", load(bg)), 1024);
    refs.push(file);
  });
  try {
    const out = generate(work, refs, CONCEPT[scene], `concept-${scene}.png`, "wide landscape, about 3:2");
    fs.copyFileSync(out, path.join(OUT, `concept-${scene}.png`));
    console.log(`Made concept-${scene}.png`);
  } catch (e) { console.log("FAILED: " + e.message.split("\n")[0]); }
}
