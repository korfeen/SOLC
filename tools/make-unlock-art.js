// The unlockable picture layers (Unlocks.lua unlocks them in game; tools/convert-art.js turns them into textures):
// - Backgrounds: each dungeon's crayon scene (tools/overview-dungeons.js, the same drawing as its feed art) as a
//   backdrop, unlocked with its dungeon ("clear:<dungeon key>", Unlocks.lua: a clear's chance).
// - Skins: each dungeon's end boss (tools/unlock-bosses.js) drawn onto one of the ogre skins, in every edition (the
//   boss over that edition's skin), wearing that skin's eyes and mouths; unlocked with its dungeon ("clear:<key>"). A
//   boss with something in front of the whole picture (VanCleef's mask) gets it as <option>.front.png beside its skin.
// Writes %USERPROFILE%\killtracker-art-extra\Unlocks\painted\<Layer>\<Rarity>\<option>.png (twins in ...\crayon and
// ...\sketch where an option has them), Unlocks\unlocks.json (what unlocks each, its name, a boss skin's faceSkin) and a
// preview sheet, Unlocks\preview.png (backdrops behind the crayon ogre; skins in crayon with a face, then painted in an
// outfit and a hat). Then run tools/convert-art.js.
// Option ids come from the file names and are saved in minted pictures: never rename one after release.
// - Gear: each end boss's set (tools/unlock-gear.js): an outfit, a headwear and a charm (an accessory); in the dungeon's
//   chest. The set's pieces are at the dungeon's rarity, a step rarer and two steps rarer, which is which shuffled per
//   dungeon (pieceSteps).
// - Creatures: a creature's hat and onesie (tools/gen-art-creatures.json), unlocked by its kill deeds; worn together,
//   its hooded onesie.
// Usage: node tools/make-unlock-art.js [backgrounds|skins|gear|chase|creatures]   (default: all). No dependencies.

const fs = require("fs");
const os = require("os");
const path = require("path");
const overview = require("./make-overview-art");  // (sets the crayon canvas to its 1024)
const crayon = require("./make-role-icons");
const { decodePng, resample } = require("./convert-art");

const SIZE = 1254;  // the minting art's canvas
const ART = path.join(os.homedir(), "killtracker-art");
const EXTRA = path.join(os.homedir(), "killtracker-art-extra");
const UNLOCKS = path.join(EXTRA, "Unlocks");
const EDITION_ART = { painted: ART, crayon: path.join(EXTRA, "CrayonHand"), sketch: path.join(EXTRA, "CrayonArt") };
const only = process.argv[2];
// Only the painted pieces sent to the build (generated\build.json, the item fitter's Build: fitted first); without the
// list, all of them.
const BUILD_LIST = path.join(UNLOCKS, "generated", "build.json");
const sent = fs.existsSync(BUILD_LIST) ? new Set(JSON.parse(fs.readFileSync(BUILD_LIST, "utf8")).ids) : null;
const ready = (id) => fs.existsSync(path.join(UNLOCKS, "generated", "painted", id + ".png")) && (!sent || sent.has(id));

// The dungeons (keys and names as in Achievements.lua), by their backdrop's rarity: the levelling ones uncommon, then
// rare, the high-level ones epic, the raids legendary. A boss skin is a step rarer (legendary at most); the set: pieceSteps.
const DUNGEONS = {
  uncommon: { RFC: "Ragefire Chasm", WC: "Wailing Caverns", DM: "The Deadmines", SFK: "Shadowfang Keep", BFD: "Blackfathom Deeps",
    STOCKS: "The Stockade", GNOMER: "Gnomeregan", RFK: "Razorfen Kraul" },
  rare: { SMGY: "Scarlet Monastery: Graveyard", SMLIB: "Scarlet Monastery: Library", SMARM: "Scarlet Monastery: Armory",
    SMCATH: "Scarlet Monastery: Cathedral", RFD: "Razorfen Downs", ULDA: "Uldaman", ZF: "Zul'Farrak", MARA: "Maraudon",
    THANES: "The Hall of Thanes", RUINS: "Ruins of Lordaeron", EXCAV: "Excavation Site: Wetlands" },
  epic: { ST: "Sunken Temple", BRD: "Blackrock Depths", LBRS: "Lower Blackrock Spire", UBRS: "Upper Blackrock Spire",
    DME: "Dire Maul: East", DMW: "Dire Maul: West", DMN: "Dire Maul: North", SCHOLO: "Scholomance", STRATL: "Stratholme: Live",
    STRATU: "Stratholme: Undead" },
  legendary: { ONY: "Onyxia's Lair", BARROW: "Barrow Deeps", HYJAL: "Hyjal Summit" },
};
const RARITIES = ["uncommon", "rare", "epic", "legendary"];
// How many rarity steps over its dungeon's each of a dungeon's pieces is. The backdrop is at the dungeon's, the boss skin
// a step up; the set's three pieces have the same steps in every dungeon (one at the dungeon's, one a step up, one two),
// but which piece gets which is shuffled per dungeon (seeded by its key, so it stays put): the rarest piece isn't always
// the charm.
const PIECE_STEPS = [0, 1, 2];
const PIECES = ["body", "head", "charm"];
function pieceSteps(key) {
  let seed = 0;
  for (const ch of key) seed = (seed * 31 + ch.charCodeAt(0)) >>> 0;
  const next = () => { seed = (seed * 1103515245 + 12345) >>> 0; return seed / 4294967296; };
  const steps = [...PIECE_STEPS];
  for (let i = steps.length - 1; i > 0; i--) { const j = Math.floor(next() * (i + 1)); [steps[i], steps[j]] = [steps[j], steps[i]]; }
  return { background: 0, skin: 1, ...Object.fromEntries(PIECES.map((piece, i) => [piece, steps[i]])) };
}
const stepUp = (rarity, step) => RARITIES[Math.min(RARITIES.length - 1, RARITIES.indexOf(rarity) + step)];
// Writes a piece's file in its rarity's folder, removing it from the others (when its rarity changes).
function writeIn(dir, rarity, base, rgba) {
  for (const r of Object.values(FOLDER)) {
    const f = path.join(dir, r, base + ".png");
    if (r !== FOLDER[rarity] && fs.existsSync(f)) fs.rmSync(f);
  }
  const file = path.join(dir, FOLDER[rarity], base + ".png");
  write(file, rgba);
  return file;
}
const FOLDER = { uncommon: "Uncommon", rare: "Rare", epic: "Epic", legendary: "Legendary" };
const toId = (name) => name.toLowerCase().replace(/\.png$/, "").replace(/[^a-z0-9]+/g, "_").replace(/^_|_$/g, "");

const infoFile = path.join(UNLOCKS, "unlocks.json");
const info = fs.existsSync(infoFile) ? JSON.parse(fs.readFileSync(infoFile, "utf8")) : {};
const made = [];  // { layer, file, base } for the preview
function over(dst, src) {  // straight alpha "over", RGBA buffers of the same size
  for (let i = 0; i < dst.length; i += 4) {
    const a = src[i + 3] / 255, b = dst[i + 3] / 255, o = a + b * (1 - a);
    if (!o) continue;
    for (let k = 0; k < 3; k++) dst[i + k] = Math.round((src[i + k] * a + dst[i + k] * b * (1 - a)) / o);
    dst[i + 3] = Math.round(o * 255);
  }
}
const write = (file, rgba) => { fs.mkdirSync(path.dirname(file), { recursive: true }); crayon.writePng(file, SIZE, SIZE, rgba); };

// --- Backgrounds -------------------------------------------------------------------------------------------------

// A dungeon's backdrop: its whole 2:1 scene across the top half of the square (the ogre covers the middle and the
// bottom, so the scene shows round his head and shoulders), its ground going on below in crayon, blended in.
function backdrop(key, seed) {
  crayon.setSize(overview.W);
  const scene = overview.canvas();
  overview.DUNGEONS[key](scene, overview.rng(seed));
  const sceneRgba = { width: overview.W, height: overview.W, rgba: overview.toRgba(scene) };
  const h = Math.round(SIZE / 2);
  const part = resample(sceneRgba, 0, 0, overview.W, overview.H, SIZE, h);
  const sum = [0, 0, 0];
  for (let y = h - 24; y < h; y++) for (let x = 0; x < SIZE; x++) for (let k = 0; k < 3; k++) sum[k] += part[(y * SIZE + x) * 4 + k];
  const colour = sum.map((v) => Math.round(v / (24 * SIZE)));
  crayon.setSize(SIZE);
  const ground = crayon.canvas();
  crayon.crayonShape(ground, [[0, h - 80], [SIZE, h - 80], [SIZE, SIZE], [0, SIZE]], colour, crayon.rng(seed + 1),
    { outline: null, fit: true, hatch: 30, line: 22 });
  const out = Buffer.from(crayon.toRgba(ground));
  for (let y = 0; y < h; y++) {
    const blend = Math.min(1, (h - y) / 40);  // (the scene fades into the ground over its last rows)
    for (let x = 0; x < SIZE; x++) {
      const i = (y * SIZE + x) * 4;
      for (let k = 0; k < 3; k++) out[i + k] = Math.round(part[i + k] * blend + out[i + k] * (1 - blend));
    }
  }
  for (let i = 3; i < out.length; i += 4) out[i] = 255;  // a backdrop is opaque
  return out;
}
// (Retired 2026-10-20 with the boss skins: crayon scenes, no painted version. Made only when asked for by name;
// otherwise any made before are taken out, below.)
if (only === "backgrounds") {
  const sceneOrder = Object.keys(overview.DUNGEONS);
  for (const [rarity, dungeons] of Object.entries(DUNGEONS)) {
    for (const [key, name] of Object.entries(dungeons)) {
      const id = "dungeon_" + key.toLowerCase();
      const file = writeIn(path.join(UNLOCKS, "painted", "Background"), stepUp(rarity, pieceSteps(key).background), id.replace(/_/g, "-"),
        backdrop(key, 7331 + sceneOrder.indexOf(key) * 7919));  // the feed art's seed
      info["background/" + id] = { unlock: "clear:" + key.toLowerCase(), name };
      made.push({ layer: "Background", file });
      process.stdout.write(`\rBackground ${made.length} ${key}`.padEnd(50));
    }
  }
  console.log();
}

// --- Boss skins --------------------------------------------------------------------------------------------------

crayon.setSize(SIZE);
const LINE = 22, HATCH = 22;
const { canvas, dab, stroke, crayonShape, circle, ellipse, star, quad, rotate, hex, OUTLINE, rng } = crayon;
const colour = (c) => (typeof c === "string" ? hex(c) : c);
const H = {
  fill: (c, poly, col, r, o = {}) => crayonShape(c, poly, colour(col), r, { fit: true, line: LINE, hatch: HATCH, ...o }),
  soft: (c, poly, col, r, o = {}) => crayonShape(c, poly, colour(col), r, { fit: true, line: LINE, hatch: HATCH, outline: null, ...o }),
  line: (c, pts, w, col, r) => stroke(c, pts, w, colour(col), 0.95, r),
  dab, circle, ellipse, star, quad, rotate, hex, OUTLINE,
  gear(c, r, cx, cy, rad, teeth, col) {
    const pts = [];
    for (let i = 0; i < teeth * 4; i++) {
      const a = (i / (teeth * 4)) * 2 * Math.PI, out = i % 4 < 2;
      pts.push([cx + Math.cos(a) * (out ? rad : rad * 0.8), cy + Math.sin(a) * (out ? rad : rad * 0.8)]);
    }
    H.fill(c, pts, col, r, { holes: [circle(cx, cy, rad * 0.3)] });
  },
};
const BOSSES = require("./unlock-bosses")(H);
// A skin's file in an edition (its rarity folder found).
function skinFile(edition, base) {
  for (const rarity of Object.values(FOLDER)) {
    const f = path.join(EDITION_ART[edition], "Skin", rarity, base + ".png");
    if (fs.existsSync(f)) return f;
  }
  throw new Error(`No ${edition} skin "${base}"`);
}
// (Retired 2026-10-20: the boss skins are crayon drawings in every edition, with no painted version; the dungeon sets
// carry the bosses' looks now. Made only when asked for by name; otherwise any made before are taken out, below.)
if (only === "skins") {
  let n = 0;
  for (const [rarity, dungeons] of Object.entries(DUNGEONS)) {
    for (const key of Object.keys(dungeons)) {
      const skinRarity = stepUp(rarity, pieceSteps(key).skin);
      const boss = BOSSES[key];
      const id = "boss_" + key.toLowerCase(), seed = 4100 + n * 7919;
      const layers = [];
      for (const part of ["behind", "front"]) {
        const c = canvas();
        if (boss[part]) boss[part](c, rng(seed + (part === "front" ? 1 : 0)));
        layers.push(Buffer.from(crayon.toRgba(c)));
      }
      for (const edition of Object.keys(EDITION_ART)) {
        const out = Buffer.from(layers[0]);
        over(out, decodePng(skinFile(edition, boss.base)).rgba);
        over(out, layers[1]);
        const file = writeIn(path.join(UNLOCKS, edition, "Skin"), skinRarity, id.replace(/_/g, "-"), out);
        if (edition === "painted") made.push({ layer: "Skin", file, base: boss.base, over: !!boss.over });
      }
      if (boss.over) {  // in front of the whole picture: one crayon drawing for every edition (convert-art.js: the front)
        const c = canvas();
        boss.over(c, rng(seed + 2));
        writeIn(path.join(UNLOCKS, "painted", "Skin"), skinRarity, id.replace(/_/g, "-") + ".front", Buffer.from(crayon.toRgba(c)));
      }
      info["skin/" + id] = { unlock: "clear:" + key.toLowerCase(), name: boss.name, faceSkin: toId(boss.base) };
      n++;
      process.stdout.write(`\rSkin ${n} ${key} (${boss.name} on ${boss.base})`.padEnd(70));
    }
  }
  console.log();
}
// --- Boss gear ----------------------------------------------------------------------------------------------------

// The base outfit's outline (the painted striped pyjamas) as a mask, and crayon hatching and an outline inside it.
let outfitMask;
function OutfitMask() {
  if (outfitMask) return outfitMask;
  const image = decodePng(path.join(ART, "Outfit", "Uncommon", "striped-pajamas.png"));
  outfitMask = new Uint8Array(SIZE * SIZE);
  for (let i = 0; i < SIZE * SIZE; i++) outfitMask[i] = image.rgba[i * 4 + 3] > 128 ? 1 : 0;
  return outfitMask;
}
const inMask = (m, x, y) => x >= 0 && y >= 0 && x < SIZE && y < SIZE && m[Math.floor(y) * SIZE + Math.floor(x)] === 1;
H.outfitFill = (c, col, r, keep = () => true) => {
  const m = OutfitMask(), tone0 = colour(col);
  for (const [a, strength] of [[0.6, 0.75], [1.8, 0.45]]) {
    const dx = Math.cos(a), dy = Math.sin(a), nx = -dy, ny = dx, reach = SIZE * 0.75;
    for (let off = -reach; off <= reach; off += HATCH * 0.85) {
      const shade = 0.88 + r() * 0.2, tone = tone0.map((v) => Math.min(255, v * shade));
      let run = [];
      for (let t = -reach; t <= reach; t += 3) {
        const x = SIZE / 2 + nx * off + dx * t, y = SIZE / 2 + ny * off + dy * t;
        if (inMask(m, x, y) && keep(x, y)) run.push([x, y]);
        else if (run.length) { if (run.length > 1) stroke(c, run, HATCH, tone, strength, r); run = []; }
      }
      if (run.length > 1) stroke(c, run, HATCH, tone, strength, r);
    }
  }
};
H.outfitOutline = (c, r) => {
  const m = OutfitMask();
  for (let y = 1; y < SIZE - 1; y += 3) for (let x = 1; x < SIZE - 1; x += 3) {
    if (!m[y * SIZE + x]) continue;
    if (m[y * SIZE + x - 3] && m[y * SIZE + x + 3] && m[(y - 3) * SIZE + x] && m[(y + 3) * SIZE + x]) continue;
    dab(c, x + (r() - 0.5) * 2, y + (r() - 0.5) * 2, 9, OUTLINE, 0.6);
  }
};
const GEAR = require("./unlock-gear")(H);
// An accessory drawn small enough to plan comfortably, then enlarged round its own middle so it reads in a picture.
const ACCESSORY_SCALE = 1.35;
// The headwear is drawn with its band at the brow (unlock-gear.js), which sits over the eyes: every hat goes up this
// many pixels (of the SIZE canvas), leaving the eyes free.
const HAT_LIFT = 48;
function Lift(rgba, by) {
  const out = Buffer.alloc(rgba.length), row = SIZE * 4;
  rgba.copy(out, 0, by * row);
  return out;
}
function Enlarge(rgba, scale) {
  let x0 = SIZE, y0 = SIZE, x1 = -1, y1 = -1;
  for (let y = 0; y < SIZE; y++) for (let x = 0; x < SIZE; x++) {
    if (rgba[(y * SIZE + x) * 4 + 3] > 0) { x0 = Math.min(x0, x); y0 = Math.min(y0, y); x1 = Math.max(x1, x); y1 = Math.max(y1, y); }
  }
  if (x1 < 0) return rgba;
  const w = x1 - x0 + 1, ht = y1 - y0 + 1, sw = Math.round(w * scale), sh = Math.round(ht * scale);
  const big = resample({ width: SIZE, height: SIZE, rgba }, x0, y0, w, ht, sw, sh);
  const out = Buffer.alloc(SIZE * SIZE * 4);
  const ox = Math.round((x0 + x1) / 2 - sw / 2), oy = Math.round((y0 + y1) / 2 - sh / 2);
  const left = Math.min(Math.max(ox, 0), SIZE - sw), top = Math.min(Math.max(oy, 0), SIZE - sh);  // (kept inside the picture)
  for (let y = 0; y < sh; y++) for (let x = 0; x < sw; x++) {
    const tx = left + x, ty = top + y;
    if (tx < 0 || ty < 0 || tx >= SIZE || ty >= SIZE) continue;
    for (let k = 0; k < 4; k++) out[(ty * SIZE + tx) * 4 + k] = big[(y * sw + x) * 4 + k];
  }
  return out;
}
// The headwear is drawn wider than the original hats (unlock-gear.js: a brow of x 456..808, the head's about 470..740):
// every hat is scaled down this much round the brow's middle (HAT_PIVOT), so it sits on the head like the others.
const HAT_SCALE = 0.8, HAT_PIVOT = [632, 236];
function Shrink(rgba, scale, [px, py]) {
  let x0 = SIZE, y0 = SIZE, x1 = -1, y1 = -1;
  for (let y = 0; y < SIZE; y++) for (let x = 0; x < SIZE; x++) {
    if (rgba[(y * SIZE + x) * 4 + 3] > 0) { x0 = Math.min(x0, x); y0 = Math.min(y0, y); x1 = Math.max(x1, x); y1 = Math.max(y1, y); }
  }
  if (x1 < 0) return rgba;
  const w = x1 - x0 + 1, ht = y1 - y0 + 1, sw = Math.max(1, Math.round(w * scale)), sh = Math.max(1, Math.round(ht * scale));
  const small = resample({ width: SIZE, height: SIZE, rgba }, x0, y0, w, ht, sw, sh);
  const out = Buffer.alloc(SIZE * SIZE * 4);
  const left = Math.round(px + (x0 - px) * scale), top = Math.round(py + (y0 - py) * scale);
  for (let y = 0; y < sh; y++) for (let x = 0; x < sw; x++) {
    const tx = left + x, ty = top + y;
    if (tx < 0 || ty < 0 || tx >= SIZE || ty >= SIZE) continue;
    for (let k = 0; k < 4; k++) out[(ty * SIZE + tx) * 4 + k] = small[(y * sw + x) * 4 + k];
  }
  return out;
}
// The head (the plain ogre's: its skin within an oval from the cheeks down to the chin, and the skull and ears above):
// an outfit is cut away there, so a high collar sits behind the head and never crosses the face. And the fists (at the
// bottom corners, below the cuffs): never hidden in a sleeve, so a held weapon always has a fist to grip.
let HEAD = null;
function headMask() {
  if (HEAD) return HEAD;
  // Clean lines, no fade: HEAD.cut = how much of a pixel is head, 0..1 - the skin's own edge along the head's outline
  // (its anti-aliasing, so no specks), and inside the skin smooth curves (head, wide at the jaw, and a chin cap for the
  // mouths) measured on 4x4 points per pixel, crisp. The collar goes behind the whole head: no front.
  const skin = decodePng(path.join(ART, "Skin", "Uncommon", "moss.png"));
  const rgba = skin.width === SIZE ? skin.rgba : resample(skin, 0, 0, skin.width, skin.height, SIZE, SIZE);
  const cut = new Float32Array(SIZE * SIZE);
  const inHead = (x, y) => {
    const ex = (x - 630) / 190, ey = (y - 285) / 128, cx = (x - 630) / 150, cy = (y - 380) / 48;
    return (y < 375 && (ex * ex + ey * ey <= 1 || (y < 330 && Math.abs(x - 630) < 240))) || cx * cx + cy * cy <= 1;
  };
  for (let y = 0; y < SIZE; y++) for (let x = 0; x < SIZE; x++) {
    const i = y * SIZE + x, skinA = rgba[i * 4 + 3] / 255;
    if (!skinA) continue;
    if (y >= 1165 && (x < 280 || x > 990)) { cut[i] = skinA; continue; }  // (the fists)
    if (y >= 440) continue;
    let n = 0;
    for (let sy = 0; sy < 4; sy++) for (let sx = 0; sx < 4; sx++) if (inHead(x + (sx + 0.5) / 4, y + (sy + 0.5) / 4)) n++;
    cut[i] = skinA * n / 16;
  }
  HEAD = { cut, front: new Float32Array(SIZE * SIZE) };
  return HEAD;
}
function blur(m, r) {  // a box blur, twice (soft edges)
  let a = m;
  for (let pass = 0; pass < 2; pass++) {
    const h = new Float32Array(a.length), v = new Float32Array(a.length), n = 2 * r + 1;
    for (let y = 0; y < SIZE; y++) { let sum = 0; for (let x = -r; x < SIZE + r; x++) {
      sum += a[y * SIZE + Math.min(SIZE - 1, Math.max(0, x + r))] - (x - r - 1 >= 0 ? a[y * SIZE + x - r - 1] : a[y * SIZE]);
      if (x >= 0 && x < SIZE) h[y * SIZE + x] = sum / n; } }
    for (let x = 0; x < SIZE; x++) { let sum = 0; for (let y = -r; y < SIZE + r; y++) {
      sum += h[Math.min(SIZE - 1, Math.max(0, y + r)) * SIZE + x] - (y - r - 1 >= 0 ? h[(y - r - 1) * SIZE + x] : h[x]);
      if (y >= 0 && y < SIZE) v[y * SIZE + x] = sum / n; } }
    a = v;
  }
  return a;
}
// The green screen's fringe: at a piece's edge (a see-through neighbour) green pulled down to its other channels.
function defringe(rgba) {
  const al = (x, y) => (x < 0 || y < 0 || x >= SIZE || y >= SIZE ? 0 : rgba[(y * SIZE + x) * 4 + 3]);
  for (let y = 0; y < SIZE; y++) for (let x = 0; x < SIZE; x++) {
    const i = (y * SIZE + x) * 4;
    if (!rgba[i + 3]) continue;
    let edge = false;
    for (let d = 1; d <= 2 && !edge; d++) if (al(x - d, y) < 30 || al(x + d, y) < 30 || al(x, y - d) < 30 || al(x, y + d) < 30) edge = true;
    if (!edge) continue;
    const m = Math.max(rgba[i], rgba[i + 2]);
    if (rgba[i + 1] > m) rgba[i + 1] = m;
    if (rgba[i + 3] < 255) rgba[i + 3] = Math.round(rgba[i + 3] * 0.7);
  }
  return rgba;
}
// An outfit split at the head: what's inside the head's outline (the skull, ears, cheeks and jaw, down to the jaw: smooth
// curves, measured on 4x4 points a pixel) goes BEHIND the ogre (<option>.back.png, under the skin: Minting.lua), so a high
// collar stands behind the head and ears and the head covers it; the rest stays in front, so a collar still wraps round
// the neck. (The fists aren't cut through it any more: the pieces are fitted, tools/item-fitter.js, and what covers the
// ogre's hands is decided there.)
// The head's outline: drawn by hand if there's a mask (killtracker-art\head-mask.png, 1254 square: white = the head),
// else smooth curves (InHead). HEAD_MASK[i] = how much of a pixel is head, 0..1.
let HEAD_MASK = null;
function HeadMask() {
  if (HEAD_MASK !== null) return HEAD_MASK;
  const file = path.join(ART, "head-mask.png");
  HEAD_MASK = false;
  if (fs.existsSync(file)) {
    const img = decodePng(file);
    const px = img.width === SIZE ? img.rgba : resample(img, 0, 0, img.width, img.height, SIZE, SIZE);
    HEAD_MASK = new Float32Array(SIZE * SIZE);
    for (let i = 0; i < HEAD_MASK.length; i++) HEAD_MASK[i] = (px[i * 4] + px[i * 4 + 1] + px[i * 4 + 2]) / 765 * (px[i * 4 + 3] / 255);
    console.log("Head outline: " + file);
  }
  return HEAD_MASK;
}
function InHead(x, y) {
  const ex = (x - 630) / 190, ey = (y - 285) / 128;
  return (y < 330 && Math.abs(x - 630) < 240) || ex * ex + ey * ey <= 1;
}
function splitOutfit(rgba) {
  const back = Buffer.alloc(SIZE * SIZE * 4);
  let n = 0;
  for (let y = 0; y < SIZE; y++) for (let x = 0; x < SIZE; x++) {
    const i = y * SIZE + x, a = rgba[i * 4 + 3];
    if (!a) continue;
    let toBack;
    const drawn = HeadMask();
    if (drawn) toBack = drawn[i];
    else {
      if (y >= 440) continue;
      let k = 0;
      for (let sy = 0; sy < 4; sy++) for (let sx = 0; sx < 4; sx++) if (InHead(x + (sx + 0.5) / 4, y + (sy + 0.5) / 4)) k++;
      toBack = k / 16;
    }
    if (!toBack) continue;
    rgba.copy(back, i * 4, i * 4, i * 4 + 3);
    back[i * 4 + 3] = Math.round(a * toBack);
    rgba[i * 4 + 3] = Math.round(a * (1 - toBack));
    n++;
  }
  return { rgba, back: n > 100 ? back : null };
}
function cutHead(rgba) {
  const { cut, front: f } = headMask(), front = Buffer.alloc(SIZE * SIZE * 4);
  let n = 0;
  for (let i = 0; i < cut.length; i++) {
    if (!cut[i]) continue;
    const a = rgba[i * 4 + 3];
    if (f[i] > 0 && a) { rgba.copy(front, i * 4, i * 4, i * 4 + 3); front[i * 4 + 3] = Math.round(a * Math.min(f[i], cut[i])); n++; }
    rgba[i * 4 + 3] = Math.round(a * (1 - cut[i]));
  }
  return { rgba, front: n > 200 ? front : null };
}
// A set's pieces: their layer (and its folder); their rarity steps are the dungeon's (pieceSteps).
const SET_PIECES = [
  { slot: "body", layer: "outfit", folder: "Outfit" },
  { slot: "head", layer: "headwear", folder: "Headwear" },
  { slot: "charm", layer: "accessory", folder: "Accessory" },
];
if (!only || only === "gear") {
  // (The gear from before sets, one piece a dungeon, goes.)
  for (const folder of ["Outfit", "Headwear", "Accessory"]) {
    for (const rarity of Object.values(FOLDER)) {
      const dir = path.join(UNLOCKS, "painted", folder, rarity);
      for (const f of fs.existsSync(dir) ? fs.readdirSync(dir) : []) if (/^gear-/.test(f)) fs.rmSync(path.join(dir, f));
    }
  }
  for (const key of Object.keys(info)) if (key.includes("/gear_")) delete info[key];
  let n = 0;
  for (const [rarity, dungeons] of Object.entries(DUNGEONS)) {
    for (const key of Object.keys(dungeons)) {
      const set = GEAR[key];
      for (const piece of SET_PIECES) {
        const gear = set[piece.slot];
        const id = `gear_${key.toLowerCase()}_${piece.slot}`;
        const pieceRarity = stepUp(rarity, pieceSteps(key)[piece.slot]);
        const c = canvas();
        gear.draw(c, rng(6100 + n * 7919));
        const file = path.join(UNLOCKS, "painted", piece.folder, FOLDER[pieceRarity], id.replace(/_/g, "-") + ".png");
        let rgba = Buffer.from(crayon.toRgba(c));
        if (gear.enlarge) rgba = Enlarge(rgba, ACCESSORY_SCALE);  // (only the charms that float free)
        if (piece.layer === "headwear") rgba = Lift(Shrink(rgba, HAT_SCALE, HAT_PIVOT), HAT_LIFT);
        // A generated piece (tools/gen-art.js: painted in the originals' style) instead, where there is one; its crayon
        // and sketch twins into those editions' folders.
        const generated = (edition) => path.join(UNLOCKS, "generated", edition, id + ".png");
        if (ready(id)) rgba = defringe(Buffer.from(decodePng(generated("painted")).rgba));
        for (const edition of ["crayon", "sketch"]) {
          const dir = path.join(UNLOCKS, edition, piece.folder);
          for (const r of Object.values(FOLDER)) {  // (a twin from before, maybe in another rarity's folder)
            const old = path.join(dir, r, id.replace(/_/g, "-") + ".png");
            if (fs.existsSync(old)) fs.rmSync(old);
          }
          if (fs.existsSync(generated(edition))) write(path.join(dir, FOLDER[pieceRarity], id.replace(/_/g, "-") + ".png"), Buffer.from(decodePng(generated(edition)).rgba));
        }
        // (only painted pieces: the code-drawn crayon ones are retired - one not painted yet isn't in the game)
        if (!ready(id)) { n++; continue; }
        let back = null;
        if (piece.layer === "outfit") ({ rgba, back } = splitOutfit(rgba));
        write(file, rgba);
        if (back) write(file.replace(/\.png$/i, ".back.png"), back);
        info[piece.layer + "/" + id] = { unlock: "clear:" + key.toLowerCase(), name: gear.name };
        made.push({ layer: piece.folder, file });
        n++;
        process.stdout.write(`Gear ${n} ${key} ${gear.name}`.padEnd(70));
      }
    }
  }
  console.log();
}

// - Chase items: each end boss's famous drop (tools/gen-art-chase.json, painted by tools/gen-art.js), in whatever layer
//   it is: in the dungeon's chest by luck ("chase:<dungeon>:<id>", Unlocks.lua), or made from others ("combine:...":
//   unlocked once all its parts are in your wardrobe). Only the ones painted so far.
if (!only || only === "gear" || only === "chase") {
  const chase = JSON.parse(fs.readFileSync(path.join(__dirname, "gen-art-chase.json"), "utf8"));
  const LAYER_FOLDER = { headwear: "Headwear", accessory: "Accessory", outfit: "Outfit" };
  for (const edition of ["painted", "crayon", "sketch"]) {
    for (const folder of Object.values(LAYER_FOLDER)) for (const rarity of Object.values(FOLDER)) {
      const dir = path.join(UNLOCKS, edition, folder, rarity);
      for (const f of fs.existsSync(dir) ? fs.readdirSync(dir) : []) if (/^chase-/.test(f)) fs.rmSync(path.join(dir, f));
    }
  }
  for (const key of Object.keys(info)) if (key.includes("/chase_")) delete info[key];
  let n = 0;
  for (const item of chase) {
    if (!ready(item.id)) continue;
    const base = item.id.replace(/_/g, "-") + ".png";
    for (const edition of ["painted", "crayon", "sketch"]) {
      const src = path.join(UNLOCKS, "generated", edition, item.id + ".png");
      if (fs.existsSync(src)) write(path.join(UNLOCKS, edition, LAYER_FOLDER[item.layer], FOLDER[item.rarity], base), Buffer.from(decodePng(src).rgba));
    }
    if (!fs.existsSync(path.join(UNLOCKS, "generated", "painted", item.id + ".png"))) continue;
    info[item.layer + "/" + item.id] = { unlock: item.unlock || `chase:${item.dungeon}:${item.id}`, name: item.desc.split(":")[0],
      ...(item.dropChance ? { dropChance: item.dropChance } : {}) };
    made.push({ layer: LAYER_FOLDER[item.layer], file: path.join(UNLOCKS, "painted", LAYER_FOLDER[item.layer], FOLDER[item.rarity], base) });
    n++;
  }
  console.log(`Chase items: ${n} painted of ${chase.length}`);
}

// - Creatures: each creature's hat and onesie (tools/gen-art-creatures.json, painted by tools/gen-art.js), unlocked by its
//   kill deeds ("deed:subtype:<Kind>:<kills>", Unlocks.lua). Worn together they're one hooded onesie, its suit
//   (crit_<kind>_suit, painted from the two): <onesie>.suit.png beside the onesie, and the onesie's suitHead the hat it
//   goes with (convert-art.js; drawn in the hat's place, Minting.lua). Only the ones painted so far.
if (!only || only === "gear" || only === "creatures") {
  // (and the bounty posters' pieces, tools/gen-art-bounty.json: the factions' outfits and the specials' props, each
  // unlocked by an achievement - built the same way, without suits)
  const creatures = JSON.parse(fs.readFileSync(path.join(__dirname, "gen-art-creatures.json"), "utf8"))
    .concat(JSON.parse(fs.readFileSync(path.join(__dirname, "gen-art-bounty.json"), "utf8")))
    .concat(JSON.parse(fs.readFileSync(path.join(__dirname, "gen-art-dragonflights.json"), "utf8")))  // (the dragonkin costume in each flight's colours)
    .concat(JSON.parse(fs.readFileSync(path.join(__dirname, "gen-art-backgrounds.json"), "utf8")));  // (the dungeons' painted backgrounds, bg_<key>)
  const LAYER_FOLDER = { headwear: "Headwear", outfit: "Outfit", accessory: "Accessory", background: "Background" };
  for (const edition of ["painted", "crayon", "sketch"]) {
    for (const folder of Object.values(LAYER_FOLDER)) for (const rarity of Object.values(FOLDER)) {
      const dir = path.join(UNLOCKS, edition, folder, rarity);
      for (const f of fs.existsSync(dir) ? fs.readdirSync(dir) : []) if (/^(crit|fac|prop|hunt|bg)-/.test(f)) fs.rmSync(path.join(dir, f));
    }
  }
  for (const key of Object.keys(info)) if (/\/(crit|fac|prop|hunt|bg)_/.test(key)) delete info[key];
  const generated = (edition, id) => path.join(UNLOCKS, "generated", edition, id + ".png");
  let n = 0, suits = 0;
  for (const item of creatures) {
    if (!LAYER_FOLDER[item.layer] || !ready(item.id)) continue;
    const base = item.id.replace(/_/g, "-") + ".png";
    const file = path.join(UNLOCKS, "painted", LAYER_FOLDER[item.layer], FOLDER[item.rarity], base);
    let rgba = defringe(Buffer.from(decodePng(generated("painted", item.id)).rgba)), back = null;
    if (item.layer === "outfit") ({ rgba, back } = splitOutfit(rgba));
    write(file, rgba);
    if (back) write(file.replace(/.png$/i, ".back.png"), back);
    for (const edition of ["crayon", "sketch"]) {
      if (fs.existsSync(generated(edition, item.id))) write(path.join(UNLOCKS, edition, LAYER_FOLDER[item.layer], FOLDER[item.rarity], base), Buffer.from(decodePng(generated(edition, item.id)).rgba));
    }
    const entry = { unlock: item.unlock, name: item.desc.split(":")[0] };
    const suit = item.id.replace(/_body$/, "_suit");
    if (item.layer === "outfit" && ready(suit)) {
      write(file.replace(/.png$/i, ".suit.png"), defringe(Buffer.from(decodePng(generated("painted", suit)).rgba)));
      entry.suitHead = item.id.replace(/_body$/, "_head");
      suits++;
    }
    info[item.layer + "/" + item.id] = entry;
    made.push({ layer: LAYER_FOLDER[item.layer], file });
    n++;
  }
  console.log(`Creatures: ${n} pieces painted, ${suits} hooded onesies`);
}

// - Pro Shop pieces: the golf and club wearables (tools/gen-art-proshop.json, gen-art-proshop-club.json) and the zone
//   golf courses (gen-art-zone-courses.json), all bought in the shop: "shop:<id>". Nothing unlocks that until the shop
//   is built, so they sit in the game locked (never rolled). Only the ones painted (and, for wearables, fitted) so far.
if (!only || only === "gear" || only === "shop") {
  const read = (f) => fs.existsSync(path.join(__dirname, f)) ? JSON.parse(fs.readFileSync(path.join(__dirname, f), "utf8")) : [];
  const shop = read("gen-art-proshop.json").concat(read("gen-art-proshop-club.json"), read("gen-art-zone-courses.json"));
  const LAYER_FOLDER = { headwear: "Headwear", outfit: "Outfit", accessory: "Accessory", background: "Background" };
  for (const edition of ["painted", "crayon", "sketch"]) {
    for (const folder of Object.values(LAYER_FOLDER)) for (const rarity of Object.values(FOLDER)) {
      const dir = path.join(UNLOCKS, edition, folder, rarity);
      for (const f of fs.existsSync(dir) ? fs.readdirSync(dir) : []) if (/^(shop|zone)-/.test(f)) fs.rmSync(path.join(dir, f));
    }
  }
  for (const key of Object.keys(info)) if (/\/(shop|zone)_/.test(key)) delete info[key];
  const generated = (edition, id) => path.join(UNLOCKS, "generated", edition, id + ".png");
  let n = 0;
  for (const item of shop) {
    if (!LAYER_FOLDER[item.layer] || !ready(item.id)) continue;
    const base = item.id.replace(/_/g, "-") + ".png";
    const file = path.join(UNLOCKS, "painted", LAYER_FOLDER[item.layer], FOLDER[item.rarity], base);
    let rgba = defringe(Buffer.from(decodePng(generated("painted", item.id)).rgba)), back = null;
    if (item.layer === "outfit") ({ rgba, back } = splitOutfit(rgba));
    write(file, rgba);
    if (back) write(file.replace(/.png$/i, ".back.png"), back);
    for (const edition of ["crayon", "sketch"]) {
      if (fs.existsSync(generated(edition, item.id))) write(path.join(UNLOCKS, edition, LAYER_FOLDER[item.layer], FOLDER[item.rarity], base), Buffer.from(decodePng(generated(edition, item.id)).rgba));
    }
    info[item.layer + "/" + item.id] = { unlock: item.unlock || "shop:" + item.id, name: item.desc.split(":")[0] };
    made.push({ layer: LAYER_FOLDER[item.layer], file });
    n++;
  }
  console.log(`Pro Shop: ${n} pieces painted of ${shop.length}`);
}

// (the retired backdrops out, unless they were just made on purpose)
if (only !== "backgrounds") {
  for (const edition of ["painted", "crayon", "sketch"]) for (const rarity of Object.values(FOLDER)) {
    const dir = path.join(UNLOCKS, edition, "Background", rarity);
    for (const f of fs.existsSync(dir) ? fs.readdirSync(dir) : []) if (/^dungeon-/.test(f)) fs.rmSync(path.join(dir, f));
  }
  for (const key of Object.keys(info)) if (key.startsWith("background/dungeon_")) delete info[key];
}
// (the retired boss skins out, unless they were just made on purpose)
if (only !== "skins") {
  for (const edition of ["painted", "crayon", "sketch"]) for (const rarity of Object.values(FOLDER)) {
    const dir = path.join(UNLOCKS, edition, "Skin", rarity);
    for (const f of fs.existsSync(dir) ? fs.readdirSync(dir) : []) if (/^boss-/.test(f)) fs.rmSync(path.join(dir, f));
  }
  for (const key of Object.keys(info)) if (key.startsWith("skin/boss_")) delete info[key];
}

fs.mkdirSync(UNLOCKS, { recursive: true });
fs.writeFileSync(infoFile, JSON.stringify(info, null, 1));

// --- The preview -------------------------------------------------------------------------------------------------

const T = 256;
const small = (file) => Buffer.from(resample(decodePng(file), 0, 0, SIZE, SIZE, T, T));
const hand = (rel) => small(path.join(EDITION_ART.crayon, rel));
const painted = (rel) => small(path.join(ART, rel));
const OGRE = [hand("Skin/Uncommon/moss.png"), hand("Outfit/Uncommon/striped-pajamas.png"), hand("Expression/Uncommon/moss/smug-smile.png"),
  hand("Eyes/Uncommon/moss/heavy-bags.png")];
const BG = painted("Background/Uncommon/moonlit-fairway.png");
const pics = [];
for (const { layer, file, base, over: front } of made) {
  if (layer === "Background") {
    const pic = Buffer.alloc(T * T * 4);
    over(pic, small(file));
    for (const l of OGRE) over(pic, l);
    pics.push(pic);
  } else if (layer !== "Skin") {  // gear: on the crayon ogre in front of a backdrop (an outfit in place of his pyjamas)
    const pic = Buffer.alloc(T * T * 4);
    const item = small(file);
    for (const l of [BG, OGRE[0], layer === "Outfit" ? item : OGRE[1], OGRE[2], OGRE[3]]) over(pic, l);
    if (layer !== "Outfit") over(pic, item);
    pics.push(pic);
  } else {
    const crayonPic = Buffer.alloc(T * T * 4), paintedPic = Buffer.alloc(T * T * 4);
    const mask = front ? [small(file.replace(/\.png$/, ".front.png"))] : [];  // over the face, under the hat
    for (const l of [BG, small(file.replace(path.join(UNLOCKS, "painted"), path.join(UNLOCKS, "crayon"))),
      hand(`Expression/Uncommon/${base}/smug-smile.png`), hand(`Eyes/Uncommon/${base}/heavy-bags.png`), ...mask]) over(crayonPic, l);
    for (const l of [BG, small(file), painted("Outfit/Rare/onesie.png"), painted(`Expression/Uncommon/${base}/mouth-hanging-open.png`),
      painted(`Eyes/Uncommon/${base}/fully-asleep.png`), ...mask, painted("Headwear/Rare/tiny-top-hat.png")]) over(paintedPic, l);
    pics.push(crayonPic, paintedPic);
  }
}
const cols = 8, rows = Math.ceil(pics.length / cols), sheet = Buffer.alloc(T * cols * T * rows * 4);
pics.forEach((pic, k) => {
  const ox = (k % cols) * T, oy = Math.floor(k / cols) * T;
  for (let y = 0; y < T; y++) pic.copy(sheet, ((oy + y) * T * cols + ox) * 4, y * T * 4, (y + 1) * T * 4);
});
crayon.writePng(path.join(UNLOCKS, only ? `preview-${only}.png` : "preview.png"), T * cols, T * rows, sheet);

// The whole sets: each boss skin (crayon) in front of its dungeon's backdrop, wearing its outfit, its base skin's face,
// its mask if it has one, its headwear and its charm - the whole boss.
if (!only || only === "gear") {
  const find = (folder, name) => {
    for (const rarity of Object.values(FOLDER)) {
      const f = path.join(UNLOCKS, folder, rarity, name + ".png");
      if (fs.existsSync(f)) return f;
    }
  };
  const sets = [];
  for (const key of Object.values(DUNGEONS).flatMap((d) => Object.keys(d))) {
    // (on its boss skin if there is one - retired; else the plain crayon ogre)
    const k = key.toLowerCase(), bossSkin = find(path.join("crayon", "Skin"), "boss-" + k);
    const base = bossSkin && info["skin/boss_" + k] ? info["skin/boss_" + k].faceSkin.replace(/_/g, "-") : "moss";
    const skin = bossSkin || path.join(EDITION_ART.crayon, "Skin", "Uncommon", "moss.png");
    const front = find(path.join("painted", "Skin"), "boss-" + k + ".front");
    const pic = Buffer.alloc(T * T * 4);
    for (const file of [find(path.join("painted", "Background"), "dungeon-" + k), skin, find(path.join("painted", "Outfit"), `gear-${k}-body`),
      path.join(EDITION_ART.crayon, "Expression", "Uncommon", base, "smug-smile.png"), path.join(EDITION_ART.crayon, "Eyes", "Uncommon", base, "heavy-bags.png"),
      front, find(path.join("painted", "Headwear"), `gear-${k}-head`), find(path.join("painted", "Accessory"), `gear-${k}-charm`)]) {
      if (file && fs.existsSync(file)) over(pic, small(file));
    }
    sets.push(pic);
  }
  const setCols = 8, setRows = Math.ceil(sets.length / setCols), setSheet = Buffer.alloc(T * setCols * T * setRows * 4);
  sets.forEach((pic, i) => {
    const ox = (i % setCols) * T, oy = Math.floor(i / setCols) * T;
    for (let y = 0; y < T; y++) pic.copy(setSheet, ((oy + y) * T * setCols + ox) * 4, y * T * 4, (y + 1) * T * 4);
  });
  crayon.writePng(path.join(UNLOCKS, "preview-sets.png"), T * setCols, T * setRows, setSheet);
}
console.log(`Wrote ${made.length} unlockable layers and unlocks.json to ${UNLOCKS}`);
