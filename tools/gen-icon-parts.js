// The profile card's painted icons in parts, so every icon of a style matches: Codex paints each style's BLANK base
// tile once per shape (the card's shapes: class heptagon, race circle, profession pentagon, secondary square, gender
// hexagon) and each SYMBOL once on its own; this puts them together - the base cut to the shape exactly, the symbol
// scaled and centred the same way on every base, a soft shadow under it.
//   node tools/gen-icon-parts.js bases [style|""] [KIND]  (Codex: the blank bases; KIND: CLASS (default), RACE, ...)
//   node tools/gen-icon-parts.js symbols [filter]     (Codex: the symbols, e.g. "Class_")
//   node tools/gen-icon-parts.js compose              (no Codex: every symbol on every base of its shape)
// Out: %USERPROFILE%\killtracker-art-extra\Unlocks\generated\icons\parts\ (base_<style>_<KIND>.png, sym_<icon>.png)
// and icons\v2\<style>_<icon>.png + v2-review.png. tools/convert-icon-styles.js takes v2 as the painted styles.
const fs = require("fs");
const os = require("os");
const path = require("path");
const gen = require("./gen-art");
const { decodePng, resample, readBlp } = require("./convert-art");
const { writePng } = require("./make-role-icons");

const EXTRA = path.join(os.homedir(), "killtracker-art-extra");
const ICONS = path.join(gen.OUT, "icons"), PARTS = path.join(ICONS, "parts"), V2 = path.join(ICONS, "v2");
const N = 512;
const [mode, arg] = process.argv.slice(2);
const STYLES = {
  white: "smooth white-grey glazed porcelain with a soft sheen",
  parchment: "warm old cream parchment paper, softly worn at the edges",
  lightwood: "pale sanded light oak planks with soft wood grain",
  darkwood: "rich dark walnut planks with wood grain",
  stone: "warm grey carved stone with a slight chiselled texture",
  gold: "polished gilded gold with small red gem studs near the corners",
  epic: "glowing epic purple crystal, softly lit from within",
  molten: "black obsidian rock with glowing orange lava cracks",
  // (dark ones: the symbols read best on dark)
  ebony: "near-black ebony wood with a faint fine grain and a soft sheen",
  iron: "dark forged iron plate with small rivets near the edge, slightly worn",
  slate: "dark blue-grey slate stone, smooth with faint chisel marks",
  leather: "dark brown tooled leather with a stitched seam round the edge",
  forest: "deep dark green stained wood planks with wood grain",
  wine: "deep burgundy red lacquered wood with a soft sheen",
  midnight: "deep midnight blue enamel with a faint starry speckle",
  bronze: "dark aged bronze with green patina in the crevices",
};
const KIND_OF = { Class: "CLASS", Race: "RACE", Prof: "PROFESSION", Gender: "GENDER" };
const SECONDARY = ["COOKING", "FIRSTAID", "FISHING"];
const kindOf = (icon) => { const [k, name] = icon.split("_"); return k === "Prof" && SECONDARY.includes(name) ? "SECONDARY" : KIND_OF[k]; };
// The shape's silhouette (the card's own Base_<KIND> tile), N x N alpha.
function shapeMask(kind) {
  const img = readBlp(path.join(__dirname, "..", "Media", "Overview", "Icons", `Base_${kind}.blp`));
  const big = resample(img, 0, 0, img.width, img.height, N, N), m = new Float32Array(N * N);
  for (let i = 0; i < N * N; i++) m[i] = big[i * 4 + 3] / 255;
  return m;
}
function onGreen(rgba, size) {  // an RGBA (size x size) over the screen green, gen-art's size
  const out = Buffer.alloc(gen.SIZE * gen.SIZE * 4);
  for (let i = 0; i < out.length; i += 4) out.set([0, 255, 0, 255], i);
  const big = resample({ width: size, height: size, rgba }, 0, 0, size, size, gen.SIZE, gen.SIZE);
  for (let i = 0; i < out.length; i += 4) { const a = big[i + 3] / 255; for (let k = 0; k < 3; k++) out[i + k] = Math.round(big[i + k] * a + out[i + k] * (1 - a)); }
  return out;
}
const STYLE_REFS = () => {  // a few painted chase items: the style to paint in
  const dir = path.join(gen.OUT, "painted");
  return fs.readdirSync(dir).filter((f) => /^chase_/.test(f)).sort().filter((_, i) => i % 11 === 0).slice(0, 2).map((f) => path.join(dir, f));
};

fs.mkdirSync(PARTS, { recursive: true });
if (mode === "bases") {
  const kind = process.argv[4] || "CLASS";  // (the shape: CLASS, RACE, PROFESSION, SECONDARY, GENDER)
  for (const [style, what] of Object.entries(STYLES)) {
    if (arg && arg !== "all" && style !== arg) continue;
    const out = path.join(PARTS, `base_${style}_${kind}.png`);
    if (fs.existsSync(out)) { console.log(style + ": there already"); continue; }
    const work = path.join(gen.OUT, "work", `iconbase_${style}_${kind}`);
    fs.mkdirSync(work, { recursive: true });
    const m = shapeMask(kind), shape = Buffer.alloc(N * N * 4);
    for (let i = 0; i < N * N; i++) shape.set([60, 60, 60, Math.round(m[i] * 255)], i * 4);
    const ref = path.join(work, "ref_shape.png");
    gen.save(ref, onGreen(shape, N), 1024);
    const refs = [ref, ...STYLE_REFS()];
    const prompt = [
      "Image 1 shows the exact outline of a game icon tile (the dark shape) on green.",
      "The other images show items painted in the style to use: soft, smooth painting, gentle highlights, warm light, rich colour.",
      `Paint ONE EMPTY icon tile with EXACTLY that outline, filling the same area, centred: made of ${what}, with a softly`,
      "bevelled raised edge and a thin dark outline round it. Completely EMPTY in the middle: no symbol, no picture, no text.",
      "Put it on a perfectly flat pure green (#00FF00) background.",
    ].join("\n");
    try { gen.save(out, gen.key(gen.load(gen.generate(work, refs, prompt, "generated.png")), true), N); console.log(style + ": done"); }
    catch (e) { console.log(style + ": FAILED " + e.message.split("\n")[0]); }
  }
} else if (mode === "symbols") {
  const names = { Class: ["DRUID", "HUNTER", "MAGE", "PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR"], Race: ["DWARF", "GNOME", "HUMAN", "NIGHTELF", "SKYBORNE"],
    Prof: ["ALCHEMY", "BLACKSMITHING", "COOKING", "ENCHANTING", "ENGINEERING", "FIRSTAID", "FISHING", "HERBALISM", "LEATHERWORKING", "MINING", "SKINNING", "TAILORING"], Gender: ["FEMALE", "MALE", "NONBINARY"] };
  for (const [k, list] of Object.entries(names)) for (const name of list) {
    const icon = `${k}_${name}`;
    if (arg && !icon.includes(arg)) continue;
    const out = path.join(PARTS, `sym_${icon}.png`);
    if (fs.existsSync(out)) { console.log(icon + ": there already"); continue; }
    const crayon = path.join(EXTRA, "RoleIcons", name.toLowerCase() + ".png");
    if (!fs.existsSync(crayon)) { console.log(icon + ": no crayon symbol to go by"); continue; }
    const work = path.join(gen.OUT, "work", `iconsym_${icon}`);
    fs.mkdirSync(work, { recursive: true });
    const c = decodePng(crayon), ref = path.join(work, "ref_symbol.png");
    gen.save(ref, onGreen(Buffer.from(resample(c, 0, 0, c.width, c.height, N, N)), N), 1024);
    const painted = path.join(ICONS, icon + ".png");  // (its earlier painted icon, if any: the look of the symbol)
    const refs = [ref, ...(fs.existsSync(painted) ? [painted] : []), ...STYLE_REFS()];
    const prompt = [
      "Image 1 is a game icon's symbol, drawn simply in crayon, on green.",
      "The other images show the painted style to use: soft, smooth painting, gentle highlights, warm light, rich colour, a dark outline.",
      "Paint ONLY that symbol again in the painted style: the same object, shape, colours and pose, big and centred, filling",
      "most of the picture. NO tile, NO frame, NO background shape behind it, no text.",
      "Put it on a perfectly flat pure green (#00FF00) background.",
    ].join("\n");
    try { gen.save(out, gen.key(gen.load(gen.generate(work, refs, prompt, "generated.png")), false), N); console.log(icon + ": done"); }  // (the normal keying: green pockets out)
    catch (e) { console.log(icon + ": FAILED " + e.message.split("\n")[0]); }
  }
} else if (mode === "compose") {
  fs.mkdirSync(V2, { recursive: true });
  const files = fs.readdirSync(PARTS), made = [];
  for (const b of files.filter((f) => /^base_/.test(f))) {
    const [, style, kind] = b.slice(0, -4).match(/^base_(\w+?)_([A-Z]+)$/);
    const m = shapeMask(kind), base = Buffer.from(decodePng(path.join(PARTS, b)).rgba);
    for (let i = 0; i < N * N; i++) base[i * 4 + 3] = Math.round(Math.min(base[i * 4 + 3] / 255, m[i]) * 255);  // (cut to the shape exactly)
    for (const sf of files.filter((f) => /^sym_/.test(f))) {
      const icon = sf.slice(4, -4);
      if (kindOf(icon) !== kind) continue;
      const sym = decodePng(path.join(PARTS, sf));
      // (its box, scaled into the middle 56% of the tile, a touch low as the card's are)
      let x0 = N, y0 = N, x1 = 0, y1 = 0;
      for (let i = 0; i < N * N; i++) if (sym.rgba[i * 4 + 3] > 40) { const x = i % N, y = (i / N) | 0; x0 = Math.min(x0, x); y0 = Math.min(y0, y); x1 = Math.max(x1, x); y1 = Math.max(y1, y); }
      if (x1 <= x0) continue;
      const box = Math.max(x1 - x0, y1 - y0) + 2, fit = Math.round(N * 0.56), cx = (x0 + x1) / 2, cy = (y0 + y1) / 2;
      const small = resample(sym, cx - box / 2, cy - box / 2, box, box, fit, fit);
      const out = Buffer.from(base), ox = Math.round((N - fit) / 2), oy = Math.round((N - fit) / 2 + N * 0.02);
      for (const [dx, dy, shade] of [[6, 8, true], [0, 0, false]]) for (let y = 0; y < fit; y++) for (let x = 0; x < fit; x++) {
        const si = (y * fit + x) * 4, a = small[si + 3] / 255 * (shade ? 0.35 : 1);
        if (!a) continue;
        const o = ((oy + y + dy) * N + ox + x + dx) * 4;
        if (o < 0 || o >= out.length) continue;
        for (let k = 0; k < 3; k++) out[o + k] = Math.round((shade ? 20 : small[si + k]) * a + out[o + k] * (1 - a));
      }
      writePng(path.join(V2, `${style}_${icon}.png`), N, N, out);
      made.push(`${style}_${icon}`);
    }
  }
  // (the review: each style a row)
  const styles = [...new Set(made.map((m) => m.split("_")[0]))], icons = [...new Set(made.map((m) => m.split("_").slice(1).join("_")))];
  const T = 110, sheet = Buffer.alloc(T * icons.length * T * styles.length * 4);
  styles.forEach((st, r) => icons.forEach((ic, c) => {
    const f = path.join(V2, `${st}_${ic}.png`); if (!fs.existsSync(f)) return;
    const s = resample(decodePng(f), 0, 0, N, N, T, T);
    for (let y = 0; y < T; y++) for (let x = 0; x < T; x++) { const i = (y * T + x) * 4, o = ((r * T + y) * T * icons.length + c * T + x) * 4, a = s[i + 3] / 255; sheet[o] = s[i] * a + 74 * (1 - a); sheet[o + 1] = s[i + 1] * a + 50 * (1 - a); sheet[o + 2] = s[i + 2] * a + 32 * (1 - a); sheet[o + 3] = 255; }
  }));
  if (made.length) writePng(path.join(ICONS, "v2-review.png"), T * icons.length, T * styles.length, sheet);
  console.log(`Composed ${made.length} icons into ${V2}`);
} else console.log("Usage: node tools/gen-icon-parts.js bases|symbols|compose [filter]");
