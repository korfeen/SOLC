// The profile card's icons and the Ogre Rank badges repainted by Codex in the pictures' painted style (the gear and
// chase items'), each keeping its own shape, symbol, colours and layout: the class, race, profession and gender
// icons (the designer's exports in %USERPROFILE%\killtracker-art-extra\Overview) and the seven rank badges
// (killtracker-art-extra\RoleIcons\rank1..7.png, tools/make-role-icons.js).
// Out: %USERPROFILE%\killtracker-art-extra\Unlocks\generated\icons\<name>.png (512x512, see-through round the shape)
// and icons-review.png beside them (the icon now above its repaint). Nothing in the game changes until they're
// approved and converted.
// Usage: node tools/gen-icons.js [filter] [--redo]   (filter: names containing it, e.g. "Class_" or "Rank_3")
const fs = require("fs");
const os = require("os");
const path = require("path");
const gen = require("./gen-art");
const { decodePng, resample } = require("./convert-art");
const { writePng } = require("./make-role-icons");

const EXTRA = path.join(os.homedir(), "killtracker-art-extra");
const OUT = path.join(gen.OUT, "icons");
const N = 512;
const args = process.argv.slice(2);
const redo = args.includes("--redo");
// --variant <name> "<the tile instead>": a try-out with a different tile (or rim), into icons/variants/<name>_<icon>.png
const vi = args.indexOf("--variant"), variant = vi >= 0 ? { name: args[vi + 1], tile: args[vi + 2] } : null;
if (vi >= 0) args.splice(vi, 3);
const filter = args.find((a) => !a.startsWith("--")) || "";

// What to repaint: { name (the game texture's), file (the icon now), what (for the prompt) }.
const ICONS = [];
const KINDS = {
  Class: ["DRUID", "HUNTER", "MAGE", "PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR"],
  Race: ["DWARF", "GNOME", "HUMAN", "NIGHTELF", "SKYBORNE"],
  Prof: ["ALCHEMY", "BLACKSMITHING", "COOKING", "ENCHANTING", "ENGINEERING", "FIRSTAID", "FISHING", "HERBALISM",
    "LEATHERWORKING", "MINING", "SKINNING", "TAILORING"],
  Gender: ["FEMALE", "MALE", "NONBINARY"],
};
const KIND_WORD = { Class: "class", Race: "race", Prof: "profession", Gender: "gender" };
for (const [kind, names] of Object.entries(KINDS)) for (const name of names) {
  const src = { NIGHTELF: "NIGHT ELF", NONBINARY: "NONBIN" }[name] || name;  // (the exports' own names)
  ICONS.push({ name: `${kind}_${name}`, file: path.join(EXTRA, "Overview", src + ".png"),
    what: `the World of Warcraft ${KIND_WORD[kind]} icon for ${name.toLowerCase().replace("nightelf", "night elf").replace("firstaid", "first aid")}` });
}
for (let i = 1; i <= 7; i++) ICONS.push({ name: `Rank_${i}`, file: path.join(EXTRA, "RoleIcons", `rank${i}.png`), what: `an ogre rank badge (rank tier ${i} of 7)` });

// The style to copy: a few painted chase items, each on a plain backdrop, cropped round it.
function styleRefs(work) {
  const dir = path.join(gen.OUT, "painted");
  const picks = fs.readdirSync(dir).filter((f) => /^chase_/.test(f)).sort().filter((_, i) => i % 9 === 0).slice(0, 3);
  return picks.map((f, i) => {
    const img = gen.load(path.join(dir, f));
    let x0 = gen.SIZE, y0 = gen.SIZE, x1 = 0, y1 = 0;
    for (let p = 0; p < gen.SIZE * gen.SIZE; p++) if (img[p * 4 + 3] > 16) { const x = p % gen.SIZE, y = (p / gen.SIZE) | 0; x0 = Math.min(x0, x); y0 = Math.min(y0, y); x1 = Math.max(x1, x); y1 = Math.max(y1, y); }
    const side = Math.max(x1 - x0, y1 - y0) + 40, cx = (x0 + x1) / 2, cy = (y0 + y1) / 2;
    const flat = Buffer.alloc(gen.SIZE * gen.SIZE * 4);
    for (let p = 0; p < flat.length; p += 4) { const a = img[p + 3] / 255; for (let k = 0; k < 3; k++) flat[p + k] = Math.round(img[p + k] * a + 200 * (1 - a)); flat[p + 3] = 255; }
    const crop = resample({ width: gen.SIZE, height: gen.SIZE, rgba: flat }, Math.max(0, cx - side / 2), Math.max(0, cy - side / 2), side, side, 512, 512);
    const file = path.join(work, `ref_style_${i + 1}.png`);
    writePng(file, 512, 512, Buffer.from(crop));
    return file;
  });
}
// An icon on the screen green, as big as the picture (its shape is what's kept).
function onGreen(file, size) {
  const img = decodePng(file), big = Buffer.from(resample(img, 0, 0, img.width, img.height, size, size));
  for (let p = 0; p < big.length; p += 4) { const a = big[p + 3] / 255; big[p] = Math.round(big[p] * a); big[p + 1] = Math.round(big[p + 1] * a + 255 * (1 - a)); big[p + 2] = Math.round(big[p + 2] * a); big[p + 3] = 255; }
  return big;
}
// Its silhouette, grown a little: what of the repaint is kept (the green round it, and anything the generator added
// outside the shape, goes).
function silhouette(file, size, grow) {
  const img = decodePng(file), a = resample(img, 0, 0, img.width, img.height, size, size);
  const m = new Uint8Array(size * size);
  for (let p = 0; p < m.length; p++) m[p] = a[p * 4 + 3] > 60 ? 1 : 0;
  for (let k = 0; k < grow; k++) {
    const g = Uint8Array.from(m);
    for (let p = 0; p < m.length; p++) if (m[p]) { const x = p % size; if (x > 0) g[p - 1] = 1; if (x < size - 1) g[p + 1] = 1; if (p >= size) g[p - size] = 1; if (p < m.length - size) g[p + size] = 1; }
    m.set(g);
  }
  return m;
}

fs.mkdirSync(OUT, { recursive: true });
const list = ICONS.filter((i) => i.name.includes(filter) && fs.existsSync(i.file));
let made = 0, failed = 0;
for (const icon of list) {
  const out = variant ? path.join(OUT, "variants", variant.name + "_" + icon.name + ".png") : path.join(OUT, icon.name + ".png");
  fs.mkdirSync(path.dirname(out), { recursive: true });
  if (fs.existsSync(out) && !redo) { console.log(icon.name + ": there already, skipped"); continue; }
  const work = path.join(gen.OUT, "work", "icon_" + (variant ? variant.name + "_" : "") + icon.name);
  fs.mkdirSync(work, { recursive: true });
  const ref = path.join(work, "ref_icon.png");
  writePng(ref, 1024, 1024, onGreen(icon.file, 1024));
  const refs = [ref, ...styleRefs(work)];
  const prompt = [
    `Image 1 is a small game icon: ${icon.what}, a symbol on a shaped tile.`,
    "The other images show items painted in the style to use: soft, smooth painting, gentle highlights, warm light, chunky and",
    "a little cute, rich colour, not realistic.",
    "Repaint the icon in image 1 as ONE crisp, high-quality icon in that painted style. Keep EXACTLY its tile shape and outline,",
    "the same symbol, the same colours and the same layout and proportions, filling the picture the same way, centred.",
    "Make it clean and readable at a small size: bold simple shapes and a dark outline round the tile. No text.",
    ...(variant ? [`ONE CHANGE from image 1: ${variant.tile}. Keep the symbol and the outline shape exactly.`] : []),
    "Put it on a perfectly flat pure green (#00FF00) background, filling the rest of the picture.",
  ].join("\n");
  fs.writeFileSync(path.join(work, "prompt.txt"), prompt);
  try {
    const raw = gen.generate(work, refs, prompt, "generated.png");
    const keyed = gen.key(gen.load(raw), true);  // (keeping its own greens: a herb's leaves)
    const small = Buffer.from(resample({ width: gen.SIZE, height: gen.SIZE, rgba: keyed }, 0, 0, gen.SIZE, gen.SIZE, N, N));
    const keep = silhouette(icon.file, N, 10);
    for (let p = 0; p < keep.length; p++) if (!keep[p]) small[p * 4 + 3] = 0;
    writePng(out, N, N, small);
    made++;
    console.log(icon.name + ": done");
  } catch (err) {
    failed++;
    console.log(icon.name + ": FAILED " + err.message.split("\n")[0]);
    if (failed >= 3 && !made) { console.log("Three failures and nothing made: stopping (the image limit?)."); break; }
  }
}
// The review: each icon now above its repaint, on the card's brown.
const done = ICONS.filter((i) => fs.existsSync(path.join(OUT, i.name + ".png")));
if (done.length) {
  const T = 128, cols = Math.min(10, done.length), rows = Math.ceil(done.length / cols), sheet = Buffer.alloc(T * cols * T * 2 * rows * 4);
  done.forEach((icon, n) => {
    [decodePng(icon.file), decodePng(path.join(OUT, icon.name + ".png"))].forEach((img, row) => {
      const s = resample(img, 0, 0, img.width, img.height, T, T), ox = (n % cols) * T, oy = (Math.floor(n / cols) * 2 + row) * T;
      for (let y = 0; y < T; y++) for (let x = 0; x < T; x++) {
        const i = (y * T + x) * 4, o = ((oy + y) * T * cols + ox + x) * 4, a = s[i + 3] / 255;
        sheet[o] = Math.round(s[i] * a + 74 * (1 - a)); sheet[o + 1] = Math.round(s[i + 1] * a + 50 * (1 - a)); sheet[o + 2] = Math.round(s[i + 2] * a + 32 * (1 - a)); sheet[o + 3] = 255;
      }
    });
  });
  writePng(path.join(OUT, "icons-review.png"), T * cols, T * 2 * rows, sheet);
}
console.log(`Made ${made}, failed ${failed}. Review: ${path.join(OUT, "icons-review.png")}`);
