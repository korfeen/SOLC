// Poster art for the bounty board (Posters.lua): a square painted picture per poster subject, in the original
// pictures' painted style, through Codex (the same way as tools/gen-art.js). No text on them: the board writes that.
//
//   node tools/gen-poster-art.js Murloc "a murloc warrior with a spear, croaking"   (one; its id as the poster's)
//   node tools/gen-poster-art.js --queue <list.json> [--redo]                       (a list; skips what's made)
//
// References: two of our pictures (an ogre on its backdrop), for the style. Out: Media\Posters\<id>.blp (256x256, for
// the game; ids lower-cased) and %USERPROFILE%\killtracker-art-extra\Posters\<id>.png (the full painting).
// Its log: killtracker-art-extra\Posters\queue.log.

const fs = require("fs");
const os = require("os");
const path = require("path");
const { decodePng, resample, writeBlp } = require("./convert-art");
const { writePng } = require("./make-role-icons");
const { generate, ogre, load, save, ART } = require("./gen-art");

const OUT = path.join(os.homedir(), "killtracker-art-extra", "Posters");
const MEDIA = path.join(__dirname, "..", "Media", "Posters");
const SIZE = 256;

// The style references: our ogre in an outfit on two of the backdrops.
function references(work) {
  const files = [];
  const backdrops = [];
  for (const rarity of ["Legendary", "Epic", "Rare"]) {
    const dir = path.join(ART, "Background", rarity);
    for (const f of fs.existsSync(dir) ? fs.readdirSync(dir) : []) if (f.endsWith(".png")) backdrops.push(path.join(dir, f));
  }
  backdrops.slice(0, 2).forEach((bg, i) => {
    const pic = load(bg);
    const o = ogre("painted", pic);
    const file = path.join(work, `ref_style_${i + 1}.png`);
    save(file, o, 1024);
    files.push(file);
  });
  return files;
}

function make(id, desc) {
  const work = path.join(OUT, "work", id);
  fs.mkdirSync(work, { recursive: true });
  // (our pictures as the look to match: their chunky, cute shapes, drawn here in ink; a game screenshot for the subject)
  const refs = references(work);
  const realRef = ["png", "jpg", "jpeg"].map((ext) => path.join(OUT, "refs", id + "." + ext)).find((f) => fs.existsSync(f));
  if (realRef) refs.push(realRef);
  // (painted exactly like our ogre pictures; the board tones it sepia until it's claimed, HuntsBoard.lua)
  const prompt = [
    "The first images are from our picture collection: a chunky, rounded, cute ogre, painted in a soft smooth style",
    "(smooth shading, gentle highlights, warm lighting, simple soft shapes, almost like a soft toy), on a simple backdrop.",
    "Paint a NEW picture in EXACTLY that style, as if the same painter made it for the same collection: the same",
    "character style as the ogre (chunky, round, soft, cute, a bit silly, big expressive face), the same lighting and",
    `finish. The subject, from World of Warcraft: ${desc}.`,
    "A portrait like the ogre's: head and shoulders (or the whole creature for beasts), big and centred, seen from the",
    "front, looking at the viewer, a bit grumpy or mischievous, on a simple soft backdrop that suits it. Not realistic,",
    "not an illustration with ink lines: the same soft painted look. No text, no letters, no frame, no border. Do not",
    "paint the ogre itself.",
    realRef ? "The LAST image is a screenshot from the game of the real thing: copy its look (only that subject)." : "",
  ].join("\n");
  fs.writeFileSync(path.join(work, "prompt.txt"), prompt);
  const raw = generate(work, refs, prompt, "poster.png");
  const img = decodePng(raw);
  const full = path.join(OUT, id + ".png");
  fs.mkdirSync(OUT, { recursive: true });
  fs.copyFileSync(raw, full);
  const side = Math.min(img.width, img.height);
  const small = Buffer.from(resample(img, (img.width - side) / 2, (img.height - side) / 2, side, side, SIZE, SIZE));
  fs.mkdirSync(MEDIA, { recursive: true });
  writeBlp(path.join(MEDIA, id.toLowerCase() + ".blp"), SIZE, SIZE, small);
  writePng(path.join(OUT, id + "_small.png"), SIZE, SIZE, small);
  console.log(`Poster art: ${full}`);
}

function queue(file, redo) {
  const jobs = JSON.parse(fs.readFileSync(file, "utf8"));
  const log = path.join(OUT, "queue.log");
  fs.mkdirSync(OUT, { recursive: true });
  const say = (text) => { const line = `${new Date().toISOString().slice(11, 19)} ${text}`; console.log(line); fs.appendFileSync(log, line + "\n"); };
  let failedInRow = 0;
  for (let i = 0; ; i++) {
    const list = JSON.parse(fs.readFileSync(file, "utf8"));  // (re-read: edits count from the next one)
    const job = list[i];
    if (!job) break;
    if (!redo && fs.existsSync(path.join(MEDIA, job.id.toLowerCase() + ".blp"))) { say(`[${i + 1}/${list.length}] ${job.id}: there already, skipped`); continue; }
    say(`[${i + 1}/${list.length}] ${job.id}...`);
    try {
      make(job.id, job.desc);
      failedInRow = 0;
      say("  done");
    } catch (e) {
      failedInRow++;
      say(`  FAILED: ${String(e.message).split("\n")[0]}`);
      if (failedInRow >= 3) { say("Three failures in a row: stopping (the image limit?). Run the queue again later: it skips what's made."); break; }
    }
  }
  say("Done: restart WoW to see them.");
}

if (require.main === module) {
  const qi = process.argv.indexOf("--queue");
  try {
    if (qi > 0) queue(process.argv[qi + 1], process.argv.includes("--redo"));
    else {
      const [id, ...words] = process.argv.slice(2);
      if (!id || !words.length) { console.log('Usage: node tools/gen-poster-art.js <id> "<what to paint>"   or   --queue <file.json>'); process.exit(1); }
      make(id, words.join(" "));
    }
  } catch (e) { console.error(e.message); process.exit(1); }
}
