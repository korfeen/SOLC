// Generated picture pieces, in the original pictures' painted style, through Codex's image generation (your ChatGPT
// plan: no API key, no credits): the same idea as Projects\emote-strip, without Scenario.
//
//   node tools/gen-art.js headwear gear_dm_head "a red Defias bandana, knotted at the back"
//   node tools/gen-art.js headwear gear_dm_head --edition crayon      (its crayon twin; sketch likewise)
//   node tools/gen-art.js headwear gear_dm_head --from raw.png        (no generating: cut and place an image you have)
//   node tools/gen-art.js headwear gear_dm_head --at 632,232 --width 280   (where it sits, if not the layer's usual)
//   node tools/gen-art.js headwear gear_dm_head "..." --behind-ears   (its knot and tails behind the ears, the ears in front)
//   node tools/gen-art.js --queue tools/gen-art-headwear.json [--redo]   (a list, one after another; then built for the game)
//
// 1. References: a plain ogre (the base the pieces are drawn for) and up to three original pieces of the same layer,
//    each on that ogre (the style to match: painted, or for --edition the hand-drawn crayon or sketch art).
// 2. Codex paints only the new piece, on pure green (#00FF00), as it would sit on that ogre.
// 3. The green is keyed out (its fringe too) and the piece cropped.
// 4. It's placed by the layer's rule (a hat: as wide as the original hats, its bottom at the brow), not by where the
//    generator happened to put it.
// 5. A review sheet: the new piece on the ogre beside the one there now.
// Out: %USERPROFILE%\killtracker-art-extra\Unlocks\generated\<edition>\<id>.png (make-unlock-art.js uses it instead
// of the code-drawn piece), raw\ (what Codex made) and review\. Headwear, accessories and outfits (an outfit: drawn on the
// ogre without its pajamas, the set's generated hat shown beside it to match); not skins.

const fs = require("fs");
const os = require("os");
const path = require("path");
const { spawnSync } = require("child_process");
const { decodePng, resample } = require("./convert-art");
const { writePng } = require("./make-role-icons");

const SIZE = 1254;  // the minting art's canvas
const ART = path.join(os.homedir(), "killtracker-art");
const EXTRA = path.join(os.homedir(), "killtracker-art-extra");
const EDITION_ART = { painted: ART, crayon: path.join(EXTRA, "CrayonHand"), sketch: path.join(EXTRA, "CrayonArt") };
const OUT = path.join(EXTRA, "Unlocks", "generated");
const FOLDERS = { headwear: "Headwear", accessory: "Accessory", outfit: "Outfit", suit: "Outfit" };
// Where a layer's piece goes: its bottom middle (headwear) or its middle (accessory) at x, y; at most width wide and
// height tall.
const RULES = {
  headwear: { anchor: "bottom", x: 634, y: 232, width: 300, height: 320 },
  accessory: { anchor: "center", x: 1010, y: 230, width: 300, height: 300 },
  outfit: { anchor: "bottom", x: 627, y: SIZE, width: SIZE, height: 960 },
  // (a creature's hooded onesie, crit_<kind>_suit: its onesie and hat in one, the hood up over the head; drawn in game
  // when a picture wears both, Minting.lua)
  suit: { anchor: "bottom", x: 627, y: SIZE, width: SIZE, height: SIZE },
};
// What a layer's piece is called in the prompts.
const NOUN = { headwear: "hat", accessory: "item", outfit: "clothes", suit: "hooded onesie" };
const KIND = { headwear: "a piece of headwear", accessory: "an accessory (a small item, pet or charm floating beside the ogre)",
  outfit: "an outfit (clothes, from the neck down)",
  suit: "a hooded onesie costume (one piece: the suit and its hood pulled up over the head, the face showing through the hood's opening)" };
// (an accessory worn, --fit wear: a weapon, shield or the like carried on the ogre: see the wear prompt)
// The ogre the pieces are drawn for (and shown on).
const BASE = ["Skin/Uncommon/moss.png", "Outfit/Uncommon/striped-pajamas.png", "Expression/Uncommon/moss/smug-smile.png",
  "Eyes/Uncommon/moss/heavy-bags.png"];
const STYLE = {
  painted: "the same soft painted look as the example pieces: smooth shading, gentle highlights, warm lighting, clean edges, no outline",
  crayon: "the same hand-drawn wax-crayon look as the example pieces: visible crayon strokes, bold dark outline, flat bright colours",
  sketch: "the same pencil-sketch look as the example pieces: loose graphite lines and hatching, lightly coloured",
};

// --- Images ---------------------------------------------------------------------------------------------------------

function load(file) {
  const img = decodePng(file);
  return img.width === SIZE && img.height === SIZE ? Buffer.from(img.rgba) : Buffer.from(resample(img, 0, 0, img.width, img.height, SIZE, SIZE));
}
function over(dst, src) {  // straight alpha "over", same-size RGBA
  for (let i = 0; i < dst.length; i += 4) {
    const a = src[i + 3] / 255, b = dst[i + 3] / 255, o = a + b * (1 - a);
    if (!o) continue;
    for (let k = 0; k < 3; k++) dst[i + k] = Math.round((src[i + k] * a + dst[i + k] * b * (1 - a)) / o);
    dst[i + 3] = Math.round(o * 255);
  }
}
function solid(r, g, b) { const out = Buffer.alloc(SIZE * SIZE * 4); for (let i = 0; i < out.length; i += 4) out.set([r, g, b, 255], i); return out; }
function ogre(edition, background, bare) {
  const out = background || solid(0, 255, 0);  // (by default on the same green the piece comes back on)
  for (const rel of BASE) {
    if (bare && rel.startsWith("Outfit/")) continue;  // (bare: without its pajamas, for drawing outfits on)
    const file = path.join(EDITION_ART[edition] || ART, rel);
    if (fs.existsSync(file)) over(out, load(file));
  }
  return out;
}
// Up to three original pieces of the layer (in the edition's art), each on the ogre.
function examples(layer, edition) {
  const dir = path.join(EDITION_ART[edition] || ART, FOLDERS[layer]);
  const files = [];
  for (const rarity of fs.existsSync(dir) ? fs.readdirSync(dir) : []) {
    const sub = path.join(dir, rarity);
    if (!fs.statSync(sub).isDirectory()) continue;
    for (const f of fs.readdirSync(sub)) if (f.endsWith(".png") && !f.startsWith("gear-")) files.push(path.join(sub, f));
  }
  return files.sort().filter((_, i, all) => i % Math.max(1, Math.floor(all.length / 3)) === 0).slice(0, 3).map((file) => {
    const pic = ogre(edition, null, layer === "outfit" || layer === "suit");
    over(pic, load(file));
    return pic;
  });
}

// The green keyed out, only the background: the screen green reaching the picture's edges, and in holes (a ring's,
// between an arm and a haft), so the item's own greens (lime runes, jade bands, an emerald crystal) stay as painted. Then
// its fringe (FRINGE pixels round it, where the item's edge blends into the green): each pixel taken apart into the item's
// colour next to it and the screen green, which gives how see-through it is and its colour without the green.
const FRINGE = 3;
function key(rgba) {
  const out = Buffer.from(rgba), n = SIZE * SIZE;
  const spillAt = (p) => out[p * 4 + 1] - Math.max(out[p * 4], out[p * 4 + 2]);
  const screen = (p) => spillAt(p) > 160 && out[p * 4 + 1] > 180;
  const bg = new Uint8Array(n), st = [];
  for (let p = 0; p < n; p++) {
    const x = p % SIZE, y = (p / SIZE) | 0;
    if ((x === 0 || y === 0 || x === SIZE - 1 || y === SIZE - 1) && screen(p)) { bg[p] = 1; st.push(p); }
    else if (spillAt(p) > 200 && out[p * 4 + 1] > 230) { bg[p] = 1; st.push(p); }  // (screen green in a hole)
  }
  while (st.length) {
    const p = st.pop(), x = p % SIZE, y = (p / SIZE) | 0;
    for (const q of [x > 0 ? p - 1 : -1, x < SIZE - 1 ? p + 1 : -1, y > 0 ? p - SIZE : -1, y < SIZE - 1 ? p + SIZE : -1]) {
      if (q >= 0 && !bg[q] && screen(q)) { bg[q] = 1; st.push(q); }
    }
  }
  // (the screen's colour: the background's average)
  const K = [0, 0, 0];
  let count = 0;
  for (let p = 0; p < n; p += 7) if (bg[p]) { for (let c = 0; c < 3; c++) K[c] += out[p * 4 + c]; count++; }
  if (count) for (let c = 0; c < 3; c++) K[c] /= count; else K.splice(0, 3, 0, 255, 0);
  // (the fringe: anything within FRINGE pixels of the background)
  const near = Uint8Array.from(bg);
  for (let k = 0; k < FRINGE; k++) {
    const grow = Uint8Array.from(near);
    for (let p = 0; p < n; p++) {
      if (!near[p]) continue;
      const x = p % SIZE, y = (p / SIZE) | 0;
      if (x > 0) grow[p - 1] = 1; if (x < SIZE - 1) grow[p + 1] = 1;
      if (y > 0) grow[p - SIZE] = 1; if (y < SIZE - 1) grow[p + SIZE] = 1;
    }
    near.set(grow);
  }
  const src = Buffer.from(out), R = FRINGE + 2;
  for (let p = 0; p < n; p++) {
    if (!near[p]) continue;
    const i = p * 4;
    if (bg[p]) { out[i + 3] = 0; continue; }
    // the item's colour here: the average of its solid pixels close by (past the fringe)
    const x = p % SIZE, y = (p / SIZE) | 0, I = [0, 0, 0];
    let m = 0;
    for (let dy = -R; dy <= R; dy++) for (let dx = -R; dx <= R; dx++) {
      const qx = x + dx, qy = y + dy;
      if (qx < 0 || qy < 0 || qx >= SIZE || qy >= SIZE) continue;
      const q = qy * SIZE + qx;
      if (near[q]) continue;
      for (let c = 0; c < 3; c++) I[c] += src[q * 4 + c];
      m++;
    }
    const C = [src[i], src[i + 1], src[i + 2]];
    let a;
    if (m) {
      for (let c = 0; c < 3; c++) I[c] /= m;
      // C = a * I + (1 - a) * K: a from how far C is from the screen towards the item
      let num = 0, den = 0;
      for (let c = 0; c < 3; c++) { num += (C[c] - K[c]) * (I[c] - K[c]); den += (I[c] - K[c]) ** 2; }
      a = den > 1 ? Math.max(0, Math.min(1, num / den)) : 1;
    } else {  // (a thin bit with nothing solid beside it: by how green it is)
      a = Math.max(0, Math.min(1, 1 - (spillAt(p) - 25) / 65));
    }
    if (a < 0.04) { out[i + 3] = 0; continue; }
    for (let c = 0; c < 3; c++) out[i + c] = Math.max(0, Math.min(255, Math.round((C[c] - (1 - a) * K[c]) / a)));
    out[i + 3] = Math.round(src[i + 3] * a);
  }
  return despeckle(out);
}
// Screen green the keying missed: small pockets of it shut in by the piece (between a mane's spikes, inside a loop),
// too dark or too blended with the piece to count as background. A pocket is a patch of greenish pixels (green well
// over red and blue) of at most SPECK pixels; the piece's own greens (a murloc's body) are bigger patches and stay. The
// pockets go see-through and the green that bled into the pixels round them (SPILL_RING pixels) is taken out.
const SPECK = 600, SPILL_RING = 2;
function despeckle(rgba) {
  const n = SIZE * SIZE;
  const greenish = (p) => {
    const r = rgba[p * 4], g = rgba[p * 4 + 1], b = rgba[p * 4 + 2];
    return rgba[p * 4 + 3] > 0 && g > 90 && g - Math.max(r, b) > 50 && Math.max(r, b) < g * 0.7;
  };
  const seen = new Uint8Array(n), gone = [];
  for (let start = 0; start < n; start++) {
    if (seen[start] || !greenish(start)) continue;
    const patch = [start], st = [start];
    seen[start] = 1;
    while (st.length) {
      const p = st.pop(), x = p % SIZE, y = (p / SIZE) | 0;
      for (const q of [x > 0 ? p - 1 : -1, x < SIZE - 1 ? p + 1 : -1, y > 0 ? p - SIZE : -1, y < SIZE - 1 ? p + SIZE : -1]) {
        if (q >= 0 && !seen[q] && greenish(q)) { seen[q] = 1; patch.push(q); st.push(q); }
      }
    }
    if (patch.length > SPECK) continue;
    // (and only where the piece round it isn't green itself: a highlight in green yarn has green all round it)
    const inPatch = new Set(patch);
    let round = 0, green = 0;
    for (const p of patch) {
      const x = p % SIZE, y = (p / SIZE) | 0;
      for (const q of [x > 0 ? p - 1 : -1, x < SIZE - 1 ? p + 1 : -1, y > 0 ? p - SIZE : -1, y < SIZE - 1 ? p + SIZE : -1]) {
        if (q < 0 || inPatch.has(q)) continue;
        round++;
        if (rgba[q * 4 + 3] && rgba[q * 4 + 1] > Math.max(rgba[q * 4], rgba[q * 4 + 2]) + 10) green++;
      }
    }
    if (green > round * 0.5) continue;
    for (const p of patch) gone.push(p);
  }
  for (const p of gone) rgba[p * 4 + 3] = 0;
  for (const p of gone) {
    const x = p % SIZE, y = (p / SIZE) | 0;
    for (let dy = -SPILL_RING; dy <= SPILL_RING; dy++) for (let dx = -SPILL_RING; dx <= SPILL_RING; dx++) {
      const qx = x + dx, qy = y + dy;
      if (qx < 0 || qy < 0 || qx >= SIZE || qy >= SIZE) continue;
      const i = (qy * SIZE + qx) * 4;
      if (rgba[i + 3] && rgba[i + 1] > Math.max(rgba[i], rgba[i + 2])) rgba[i + 1] = Math.round((rgba[i] + rgba[i + 2]) / 2);
    }
  }
  return despill(rgba);
}
// The screen's green bled into a piece's edges (frayed tips, the gaps between spikes): within EDGE_SPILL pixels of
// see-through, green that's over both red and blue brought down to between them. Only on a piece that's hardly green itself
// (under GREEN_PIECE of it): a murloc or a naga keeps its own greens at its edges.
const EDGE_SPILL = 6, GREEN_PIECE = 0.12;
function despill(rgba) {
  const n = SIZE * SIZE;
  let solid = 0, green = 0;
  for (let p = 0; p < n; p++) {
    if (rgba[p * 4 + 3] < 250) continue;
    solid++;
    if (rgba[p * 4 + 1] > Math.max(rgba[p * 4], rgba[p * 4 + 2]) + 10) green++;
  }
  if (!solid || green / solid >= GREEN_PIECE) return rgba;
  // (how far each pixel is from see-through, up to EDGE_SPILL: grown out from the see-through pixels)
  let ring = new Uint8Array(n);
  for (let p = 0; p < n; p++) if (rgba[p * 4 + 3] < 250) ring[p] = 1;
  for (let k = 0; k < EDGE_SPILL; k++) {
    const grow = Uint8Array.from(ring);
    for (let p = 0; p < n; p++) {
      if (!ring[p]) continue;
      const x = p % SIZE, y = (p / SIZE) | 0;
      if (x > 0) grow[p - 1] = 1; if (x < SIZE - 1) grow[p + 1] = 1;
      if (y > 0) grow[p - SIZE] = 1; if (y < SIZE - 1) grow[p + SIZE] = 1;
    }
    ring = grow;
  }
  for (let p = 0; p < n; p++) {
    const i = p * 4;
    if (!ring[p] || !rgba[i + 3]) continue;
    const spill = rgba[i + 1] - Math.max(rgba[i], rgba[i + 2]);
    if (spill <= 0) continue;
    rgba[i + 1] = Math.round((rgba[i] + rgba[i + 2]) / 2);  // (green over both: down to their middle, a tan not a mustard)
    // (very green at an edge: mostly the screen itself, a frayed tip's fringe - faded out with it)
    if (spill > FADE_SPILL) rgba[i + 3] = Math.round(rgba[i + 3] * Math.max(0, 1 - (spill - FADE_SPILL) / 40));
  }
  return rgba;
}
const FADE_SPILL = 15;
function bbox(rgba) {
  let x0 = SIZE, y0 = SIZE, x1 = -1, y1 = -1;
  for (let y = 0; y < SIZE; y++) for (let x = 0; x < SIZE; x++) {
    if (rgba[(y * SIZE + x) * 4 + 3] > 40) { x0 = Math.min(x0, x); y0 = Math.min(y0, y); x1 = Math.max(x1, x); y1 = Math.max(y1, y); }
  }
  return x1 < 0 ? null : { x0, y0, w: x1 - x0 + 1, h: y1 - y0 + 1 };
}
// The cut-out piece placed by the rule: scaled to the rule's width (never up), anchored at its point.
function place(rgba, rule) {
  const box = bbox(rgba);
  if (!box) throw new Error("Nothing left after keying out the green: was the background green?");
  const scale = Math.min(1, rule.width / box.w, rule.height / box.h);
  const w = Math.max(1, Math.round(box.w * scale)), h = Math.max(1, Math.round(box.h * scale));
  const part = Buffer.from(resample({ width: SIZE, height: SIZE, rgba }, box.x0, box.y0, box.w, box.h, w, h));
  const left = Math.round(rule.x - w / 2), top = Math.round(rule.anchor === "bottom" ? rule.y - h : rule.y - h / 2);
  const out = Buffer.alloc(SIZE * SIZE * 4);
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const tx = left + x, ty = top + y;
    if (tx < 0 || ty < 0 || tx >= SIZE || ty >= SIZE) continue;
    part.copy(out, (ty * SIZE + tx) * 4, (y * w + x) * 4, (y * w + x) * 4 + 4);
  }
  return out;
}
// The head (the plain ogre's skin, measured): its middle, and the band where a hat's bottom sits.
const HEAD = { x: 630, top: 130, brow: { min: 200, max: 290, to: 246 } };
// Kept where the model drew it (it saw the ogre: it's already about where it belongs, at 1:1, the canvas's size), only
// nudged: a hat's middle onto the head's, its bottom into the brow's band. Something drawn far off falls back on the
// rule's box.
function snap(rgba, layer, rule) {
  const box = bbox(rgba);
  if (!box) throw new Error("Nothing left after keying out the green: was the background green?");
  if (layer === "outfit") return rgba;  // (the model's own place: it drew it on the whole ogre, at 1:1)
  if (layer !== "headwear") {
    const sane = box.w < 600 && box.h < 600 && box.x0 + box.w > 40 && box.x0 < SIZE - 40;
    return sane ? rgba : place(rgba, rule);
  }
  // The hat's bottom and middle where it sits on the skull: its lowest row over the head, and the middle of its mass
  // there (over the head: tails and feathers hanging off to a side don't pull it).
  let bottom = -1, sum = 0, count = 0;
  for (let y = box.y0; y < box.y0 + box.h; y++) for (let x = HEAD.x - 150; x <= HEAD.x + 150; x++) {
    if (x >= 0 && x < SIZE && rgba[(y * SIZE + x) * 4 + 3] > 40) { bottom = y; sum += x; count++; }
  }
  if (bottom < 0 || box.w > 700 || bottom < HEAD.top) return place(rgba, rule);
  const middle = sum / count;
  const dx = Math.round(HEAD.x - middle);
  const dy = bottom < HEAD.brow.min || bottom > HEAD.brow.max ? HEAD.brow.to - bottom : 0;
  const out = Buffer.alloc(SIZE * SIZE * 4);
  for (let y = 0; y < SIZE; y++) for (let x = 0; x < SIZE; x++) {
    const tx = x + dx, ty = y + dy;
    if (tx < 0 || ty < 0 || tx >= SIZE || ty >= SIZE) continue;
    rgba.copy(out, (ty * SIZE + tx) * 4, (y * SIZE + x) * 4, (y * SIZE + x) * 4 + 4);
  }
  console.log(`Snapped by ${dx}, ${dy} (its bottom was at ${bottom}, its middle at ${Math.round(middle)}).`);
  return out;
}
// The generator doesn't keep the framing when it redraws the ogre (bigger or smaller, higher or lower): how its ogre
// (worn) maps onto ours, as a scale and a shift (ours = s * theirs + t), found by matching their outlines (what isn't
// green) over the head, shoulders and chest, leaving out the hat itself (the lifted piece: it isn't on our ogre, and
// matching its top to our head's would push it down onto the face). A coarse search, then a fine one round the best.
function mask(rgba, cell, test) {
  const n = Math.floor(SIZE / cell), out = new Uint8Array(n * n);
  for (let cy = 0; cy < n; cy++) for (let cx = 0; cx < n; cx++) {
    const i = ((cy * cell + (cell >> 1)) * SIZE + cx * cell + (cell >> 1)) * 4;
    out[cy * n + cx] = test(rgba[i], rgba[i + 1], rgba[i + 2], rgba[i + 3]) ? 1 : 0;
  }
  return { n, m: out, cell };
}
const notGreen = (r, g, b, a) => a > 40 && !(g > 150 && g - Math.max(r, b) > 90);
const opaque = (r, g, b, a) => a > 40;
const MATCH_BOTTOM = 760;  // (the part compared: from the top down to here; below, the body only runs off the picture)
function score(a, hat, b, s, tx, ty, bottom = MATCH_BOTTOM) {
  let both = 0, either = 0;
  const rows = Math.floor(bottom / b.cell);
  for (let y = 0; y < rows; y++) for (let x = 0; x < b.n; x++) {
    const px = x * b.cell + b.cell / 2, py = y * b.cell + b.cell / 2;  // a point on ours
    const wx = Math.floor((px - tx) / s / a.cell), wy = Math.floor((py - ty) / s / a.cell);  // where it is on theirs
    const inside = wx >= 0 && wy >= 0 && wx < a.n && wy < a.n;
    if (inside && hat.m[wy * a.n + wx]) continue;  // (the hat: left out)
    const inA = inside && a.m[wy * a.n + wx], inB = b.m[y * b.n + x];
    if (inA && inB) both++;
    if (inA || inB) either++;
  }
  return either ? both / either : 0;
}
// bottom: the part compared, from the top down to it (a hat or a mask: the head and shoulders only, MATCH_HEAD: the
// generator may redraw the head a little smaller or bigger than the body, and a hat goes with the head).
const MATCH_HEAD = 470;
function register(worn, ours, hatOnWorn, bottom = MATCH_BOTTOM) {
  let best = null;
  const search = (cell, scales, shifts) => {
    const a = mask(worn, cell, notGreen), hat = mask(hatOnWorn, cell, opaque), b = mask(ours, cell, notGreen);
    for (const s of scales) for (const tx of shifts.x) for (const ty of shifts.y) {
      const sc = score(a, hat, b, s, tx, ty, bottom);
      if (!best || sc > best.score) best = { score: sc, s, tx, ty };
    }
  };
  const range = (from, to, step) => { const out = []; for (let v = from; v <= to + 1e-9; v += step) out.push(v); return out; };
  // Coarse: scales 0.8..1.25, shifts of up to 200 pixels (a shift as if scaling round the middle, then moved).
  const coarse = [];
  for (const s of range(0.8, 1.25, 0.025)) coarse.push(s);
  for (const s of coarse) {
    const centre = SIZE / 2 * (1 - s);  // (keeps the middle where it is; the shift then moves from there)
    search(16, [s], { x: range(centre - 200, centre + 200, 16), y: range(centre - 200, centre + 200, 16) });
  }
  // Fine, round the best.
  const c = best;
  search(8, range(c.s - 0.03, c.s + 0.03, 0.005), { x: range(c.tx - 16, c.tx + 16, 4), y: range(c.ty - 16, c.ty + 16, 4) });
  return best;
}
// The lift (the piece alone) isn't always where it was in the worn picture: the generator may redraw it a little
// bigger or lower. Its place in the worn picture (worn = s * lift + t), found by matching its colours there: the scale
// and shift where its pixels look most like the worn picture's. A coarse search, then a fine one round the best.
function alignLift(lift, worn) {
  const cell = 6, pts = [];
  let cx = 0, cy = 0;
  for (let y = 0; y < SIZE; y += cell) for (let x = 0; x < SIZE; x += cell) {
    const i = (y * SIZE + x) * 4;
    if (lift[i + 3] > 200) { pts.push([x, y, lift[i], lift[i + 1], lift[i + 2]]); cx += x; cy += y; }
  }
  if (pts.length < 50) return null;
  cx /= pts.length; cy /= pts.length;
  const sample = pts.filter((_, i) => i % Math.max(1, Math.floor(pts.length / 2500)) === 0);
  const cost = (sc, dx, dy) => {
    let sum = 0;
    for (const [x, y, r, g, b] of sample) {
      const wx = Math.round(cx + sc * (x - cx) + dx), wy = Math.round(cy + sc * (y - cy) + dy);
      if (wx < 0 || wy < 0 || wx >= SIZE || wy >= SIZE) { sum += 300; continue; }
      const j = (wy * SIZE + wx) * 4;
      sum += Math.abs(worn[j] - r) + Math.abs(worn[j + 1] - g) + Math.abs(worn[j + 2] - b);
    }
    return sum / sample.length;
  };
  let best = { c: cost(1, 0, 0), s: 1, dx: 0, dy: 0 };
  const none = best.c;
  for (let sc = 0.7; sc <= 1.3001; sc += 0.025) for (let dx = -120; dx <= 120; dx += 8) for (let dy = -120; dy <= 120; dy += 8) {
    const c = cost(sc, dx, dy);
    if (c < best.c) best = { c, s: sc, dx, dy };
  }
  const b0 = best;
  for (let sc = b0.s - 0.025; sc <= b0.s + 0.0251; sc += 0.005) for (let dx = b0.dx - 8; dx <= b0.dx + 8; dx += 2) for (let dy = b0.dy - 8; dy <= b0.dy + 8; dy += 2) {
    const c = cost(sc, dx, dy);
    if (c < best.c) best = { c, s: sc, dx, dy };
  }
  return { s: best.s, tx: cx * (1 - best.s) + best.dx, ty: cy * (1 - best.s) + best.dy, before: none, after: best.c };
}
// An outfit runs off the bottom of the picture: if fitting moved it up, the rows left empty at the bottom are filled
// with its last whole row (between the fists), so no strip of skin shows there.
function extendBottom(rgba) {
  const covered = (y) => { let c = 0; for (let x = 300; x < SIZE - 300; x++) if (rgba[(y * SIZE + x) * 4 + 3] > 40) c++; return c >= 50; };
  let last = SIZE - 1;
  while (last > SIZE - 80 && !covered(last)) last--;
  if (last === SIZE - 1 || last <= SIZE - 80) return rgba;
  return stretchBottom(rgba, Math.max(0, last - 2));  // (a row a little above its very edge: whole, not its soft rim)
}
// The lower body (STRETCH rows above the row 'to'), stretched smoothly down to the picture's bottom: an outfit the
// generator's ogre ended short of it (theirs drawn a little bigger than ours) reaches it, its texture whole - a row
// repeated down to it was streaks. The body only, between the fists: the hands at the bottom corners stay as they are.
const STRETCH = 300;
function stretchBottom(rgba, to) {
  const top = Math.max(0, to - STRETCH), src = Buffer.from(rgba);
  for (let y = top; y < SIZE; y++) {
    const f = top + (y - top) * (to - top) / (SIZE - 1 - top), y0 = Math.floor(f), y1 = Math.min(to, y0 + 1), t = f - y0;
    for (let x = 280; x < SIZE - 280; x++) {
      const o = (y * SIZE + x) * 4, a = (y0 * SIZE + x) * 4, b = (y1 * SIZE + x) * 4;
      for (let c = 0; c < 4; c++) rgba[o + c] = Math.round(src[a + c] * (1 - t) + src[b + c] * t);
    }
  }
  return rgba;
}
// Moves an image drawn on their ogre onto ours (ours = s * theirs + t).
function transform(rgba, t) {
  const out = Buffer.alloc(SIZE * SIZE * 4);
  for (let y = 0; y < SIZE; y++) for (let x = 0; x < SIZE; x++) {
    const sx = Math.round((x - t.tx) / t.s), sy = Math.round((y - t.ty) / t.s);
    if (sx < 0 || sy < 0 || sx >= SIZE || sy >= SIZE) continue;
    rgba.copy(out, (y * SIZE + x) * 4, (sy * SIZE + sx) * 4, (sy * SIZE + sx) * 4 + 4);
  }
  return out;
}
// The ears (the plain ogre's): its skin sticking out of the skull's oval at ear height, left 160..300, right 238..325.
// A piece worn behind the ears (--behind-ears: a bandana's knot and tails) has them cut out of it, so the ears show in
// front (the hat layer is drawn over the skin: a hole is the only way).
function earMask() {
  const file = path.join(ART, BASE[0]);
  const out = new Uint8Array(SIZE * SIZE);
  if (!fs.existsSync(file)) return out;
  const skin = load(file);
  for (let y = 160; y <= 325; y++) for (let x = 0; x < SIZE; x++) {
    const left = x < HEAD.x;
    if (left ? y > 300 : y < 238) continue;
    if (skin[(y * SIZE + x) * 4 + 3] <= 60) continue;
    const dy = (Math.min(y, 300) - 250) / 125, inside = 1 - dy * dy;
    const half = inside > 0 ? 118 * Math.sqrt(inside) : 0;
    if (Math.abs(x - HEAD.x) > half + 3) out[y * SIZE + x] = 1;
  }
  return out;
}
// The hands (the plain ogre's fists at the bottom corners, apart from the body): a weapon held (--hold left|right|both,
// as you look at the picture) has them cut out of it where it passes them, so the fist is in front of the grip.
// A held weapon moved so its grip runs into the fist: its lowest point on that side (the pommel, the grip's end) put
// a little below the fist's middle (the fist then cut out in front of it, cutHands). Not for both hands (a pair is
// drawn in the fists already) or when it's far off (then it's left where the model put it).
const FIST_TOP = 1165;  // (the fists: below the sleeves' cuffs, at the bottom corners)
function gripToFist(rgba, which) {
  const file = path.join(ART, BASE[0]);
  if (which === "both" || !fs.existsSync(file)) return rgba;
  const skin = load(file);
  let hx = 0, hy = 0, n = 0, gx = 0, gy = -1;
  const inSide = (x) => (which === "left" ? x < 280 : x > 990);
  for (let y = FIST_TOP; y < SIZE; y++) for (let x = 0; x < SIZE; x++) {
    if (inSide(x) && skin[(y * SIZE + x) * 4 + 3] > 60) { hx += x; hy += y; n++; }
  }
  if (!n) return rgba;
  hx /= n; hy /= n;
  const half = which === "left" ? [0, SIZE / 2] : [SIZE / 2, SIZE];
  for (let y = SIZE - 1; y >= 0 && gy < 0; y--) {
    let sx = 0, c = 0;
    for (let x = half[0]; x < half[1]; x++) if (rgba[(y * SIZE + x) * 4 + 3] > 120) { sx += x; c++; }
    if (c >= 3) { gy = y; gx = sx / c; }
  }
  if (gy < 0) return rgba;
  const dx = Math.round(hx - gx), dy = Math.round(SIZE - 8 - gy);  // (its end at the bottom edge, through the fist)
  if (Math.hypot(dx, dy) > 450) return rgba;
  console.log(`The grip into the fist: moved ${dx}, ${dy}.`);
  const out = Buffer.alloc(SIZE * SIZE * 4);
  for (let y = 0; y < SIZE; y++) for (let x = 0; x < SIZE; x++) {
    const sx = x - dx, sy = y - dy;
    if (sx < 0 || sy < 0 || sx >= SIZE || sy >= SIZE) continue;
    rgba.copy(out, (y * SIZE + x) * 4, (sy * SIZE + sx) * 4, (sy * SIZE + sx) * 4 + 4);
  }
  return out;
}
function cutHands(rgba, which) {
  const file = path.join(ART, BASE[0]);
  if (!fs.existsSync(file)) return rgba;
  const skin = load(file);
  for (let y = FIST_TOP; y < SIZE; y++) for (let x = 0; x < SIZE; x++) {
    const side = x < 280 ? "left" : x > 990 ? "right" : null;
    if (!side || (which !== "both" && which !== side)) continue;
    if (skin[(y * SIZE + x) * 4 + 3] > 60) rgba[(y * SIZE + x) * 4 + 3] = 0;
  }
  return rgba;
}
function cutEars(rgba) {
  const ears = earMask();
  for (let i = 0; i < ears.length; i++) if (ears[i]) rgba[i * 4 + 3] = 0;
  return rgba;
}
// The plain ogre's outline drawn over a review picture, thin and yellow.
function outline(rgba) {
  const file = path.join(ART, BASE[0]);
  if (!fs.existsSync(file)) return;
  const skin = load(file);
  const solidAt = (x, y) => x >= 0 && y >= 0 && x < SIZE && y < SIZE && skin[(y * SIZE + x) * 4 + 3] > 60;
  for (let y = 0; y < SIZE; y++) for (let x = 0; x < SIZE; x++) {
    if (solidAt(x, y) && (!solidAt(x - 2, y) || !solidAt(x + 2, y) || !solidAt(x, y - 2) || !solidAt(x, y + 2))) {
      rgba.set([255, 220, 40, 255], (y * SIZE + x) * 4);
    }
  }
}
function save(file, rgba, size) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  const s = size || SIZE;
  writePng(file, s, s, s === SIZE ? rgba : Buffer.from(resample({ width: SIZE, height: SIZE, rgba }, 0, 0, SIZE, SIZE, s, s)));
}

// --- Codex ----------------------------------------------------------------------------------------------------------

// shape: "square" (default) or e.g. "wide landscape, 3:2".
function generate(work, refs, prompt, outName, shape) {
  const args = ["exec", "--skip-git-repo-check", "-s", "workspace-write", "--ephemeral", "-C", work];
  for (const ref of refs) args.push("-i", ref);
  const full = prompt + `\n\nUse your image generation tool for this (one image, ${shape || "square"}). Save the image as ${outName} in the ` +
    "current directory, then reply with only its path.";
  console.log(`Asking Codex (${refs.length} reference images)... about a minute.`);
  // (The prompt on stdin: as an argument, a shell would mangle its lines and quotes.)
  const command = ["codex", ...args.map((a) => (/[\s"]/.test(a) ? `"${a.replace(/"/g, '\\"')}"` : a))].join(" ");
  const file = path.join(work, outName);
  // (the last run's image gone first: else when Codex makes none - its image limit - the old one passed for a new one)
  if (fs.existsSync(file)) fs.rmSync(file);
  const run = spawnSync(command, { cwd: work, input: full, stdio: ["pipe", "pipe", "pipe"], shell: true, encoding: "utf8", timeout: 600000 });
  if (!fs.existsSync(file)) throw new Error("Codex made no image.\n" + (run.stdout || "").slice(-800) + (run.stderr || "").slice(-400));
  return file;
}

// --- The command ----------------------------------------------------------------------------------------------------

function main() {
  const args = process.argv.slice(2);
  const flag = (name) => { const i = args.indexOf(name); if (i < 0) return null; const v = args[i + 1]; args.splice(i, 2); return v; };
  const edition = flag("--edition") || "painted";
  const from = flag("--from");
  const at = flag("--at");
  const width = flag("--width");
  const fitFlag = flag("--fit");
  // (--alone: the item painted on its own, upright and centred, copying its game screenshot (Unlocks\refs\<id>.png;
  // more than one: <id>.2.png...): placed by hand afterwards in tools/item-fitter.js)
  const alone = args.includes("--alone");
  if (alone) args.splice(args.indexOf("--alone"), 1);
  const behindEars = args.includes("--behind-ears");
  if (behindEars) args.splice(args.indexOf("--behind-ears"), 1);
  // (--covers-face: a mask meant to be over the nose and mouth; the eyes still free. Mark it in convert-art.js COVERS.)
  const hold = flag("--hold");
  // (--tall: a two-hander, staff, bow or gun held standing tall beside it, leaning on its shoulder; else brandished at the
  // viewer)
  const tall = args.includes("--tall");
  const offhand = args.includes("--offhand");  // (a shield held up, or a magic book, mirror or ring hovering over the fist)
  if (offhand) args.splice(args.indexOf("--offhand"), 1);
  if (tall) args.splice(args.indexOf("--tall"), 1);  // (a weapon held in a fist: left, right or both, as you look at the picture)
  const coversFace = args.includes("--covers-face");
  if (coversFace) args.splice(args.indexOf("--covers-face"), 1);
  const [layer, id, ...words] = args;
  const description = words.join(" ");
  if (!RULES[layer] || !id || !EDITION_ART[edition]) {
    console.log("Usage: node tools/gen-art.js <headwear|accessory|outfit> <option id> \"<what it is>\" [--fit wear|snap|rule] [--behind-ears] [--covers-face] [--edition crayon|sketch] [--from image.png] [--at x,y] [--width w]");
    process.exit(1);
  }
  const rule = { ...RULES[layer] };
  if (at) [rule.x, rule.y] = at.split(",").map(Number);
  if (width) rule.width = Number(width);

  // How it's fitted: wear (headwear's default: drawn on the ogre, then lifted off it), snap (accessories': kept where
  // the model drew it, nudged onto the head's middle), rule (the layer's fixed box: RULES).
  const fit = fitFlag || (layer === "accessory" ? "snap" : "wear");
  const work = path.join(OUT, "work", `${id}_${edition}`);
  fs.mkdirSync(work, { recursive: true });
  let raw = from;
  if (!raw && alone) {
    const refs = [];
    for (const suffix of ["", ".2", ".3"]) {
      for (const ext of ["png", "jpg"]) {
        const file = path.join(EXTRA, "Unlocks", "refs", id + suffix + "." + ext);
        if (fs.existsSync(file)) refs.push(file);
      }
    }
    const prompt = [
      `Paint ONE item for a fantasy picture collection: ${description || id}.`,
      refs.length ? "The image(s) given are screenshots of the real item from World of Warcraft: copy its shape, colours and details exactly (only the item)." : "",
      "Paint it in a soft, smooth, chunky painted style: smooth shading, gentle highlights, warm lighting, rich colour, a little",
      "stylised and cute, not realistic, no hard outlines. A weapon or staff stands UPRIGHT (its grip or haft at the bottom, its",
      "blade or head at the top), straight up; a shield, book, mirror or ring faces the viewer. Big and centred, filling most",
      "of the picture's height, nothing cut off. ONLY the item: no hands, no character, no shadow, no text, no frame, on a",
      "perfectly flat pure green (#00FF00) background filling the rest of the picture.",
    ].join("\n");
    fs.writeFileSync(path.join(work, "prompt_alone.txt"), prompt);
    raw = generate(work, refs, prompt, "generated.png");
  }
  if (!raw) {
    // The references: the ogre, then the examples of the style.
    const refs = [path.join(work, "ref_ogre.png")];
    const bare = layer === "outfit" || layer === "suit";
    save(refs[0], ogre(edition, null, bare), 1024);
    examples(layer, edition).forEach((pic, i) => {
      const file = path.join(work, `ref_example_${i + 1}.png`);
      save(file, pic, 1024);
      refs.push(file);
    });
    const painted = path.join(OUT, "painted", id + ".png");
    let what = description || id.replace(/_/g, " ");
    if (edition !== "painted" && fs.existsSync(painted)) {  // a twin: the painted piece is what to redraw
      const pic = ogre("painted", null, bare);
      over(pic, load(painted));
      const file = path.join(work, "ref_painted_piece.png");
      save(file, pic, 1024);
      refs.push(file);
      what = `the same ${NOUN[layer]} as on the ogre in the last image` + (description ? ` (${description})` : "");
    }
    const kind = layer === "accessory" && fit === "wear" ? "an item it carries" : KIND[layer];
    // A piece of a set: the set's other piece (generated: an outfit's hat, a hat's outfit) on the ogre, last, to match it.
    const other = layer === "outfit" ? id.replace(/_body$/, "_head") : layer === "headwear" ? id.replace(/_head$/, "_body") : id;
    const setHat = path.join(OUT, edition, other + ".png");
    let matchHat = false;
    // (a suit: its creature's hat and onesie, each on our ogre, to sew into one)
    const suitParts = layer === "suit" ? ["_head", "_body"].map((end) => path.join(OUT, edition, id.replace(/_suit$/, end) + ".png")) : [];
    if (suitParts.length && !suitParts.every((part) => fs.existsSync(part))) throw new Error("Paint the hat and the onesie first: " + suitParts.join(", "));
    suitParts.forEach((part, i) => {
      const pic = ogre(edition, null, i === 1);
      over(pic, load(part));
      const ref = path.join(work, i === 0 ? "ref_suit_hat.png" : "ref_suit_onesie.png");
      save(ref, pic, 1024);
      refs.push(ref);
    });
    if (other !== id && fs.existsSync(setHat)) {
      const pic = ogre(edition, null, layer === "headwear");
      over(pic, load(setHat));
      const file = path.join(work, "ref_set_hat.png");
      save(file, pic, 1024);
      refs.push(file);
      matchHat = true;
    }
    // The real thing (a screenshot from the game: %USERPROFILE%\killtracker-art-extra\Unlocks\refs\<id>.png or .jpg),
    // shown last, to copy its look.
    const realRef = ["png", "jpg", "jpeg"].map((ext) => path.join(EXTRA, "Unlocks", "refs", id + "." + ext)).find((file) => fs.existsSync(file));
    if (realRef) refs.push(realRef);
    const style = `Match ${STYLE[edition]}.`;
    if (fit === "wear") {
      // 1. The ogre wearing it (the model fits it round the head itself) ...
      const wearPrompt = (layer === "suit" ? [
        `Image 1 is an ogre character on a green background. The next images show example outfits worn by that same ogre, then`,
        `(the last two images) the same ogre wearing a creature hat, and wearing that creature's onesie costume.`,
        `EDIT image 1 itself - do not redraw the ogre. Paint onto this exact picture: every pixel of the ogre that the costume`,
        `doesn't cover stays exactly as it is (its face, eyes, mouth, tusks, arms and hands, where and how big they are), and the`,
        `green background stays. The only change: it now wears ${kind}: ${what}.`,
        `It is the onesie from the last image with the hat from the one before sewn onto it as its hood: the hood pulled UP over`,
        `the head and joined to the onesie's collar with no gap, the hat's look (its colours, eyes, fins, ears, horns or other`,
        `features) now on the hood. The hood covers the top and sides of the head and the ears; it may come down over the brow`,
        `and the sides of the face like a snug costume hood, but the eyes, nose and mouth still show through its opening.`,
        `It is a LOOSE, roomy costume, a size too big: baggy sleeves clearly wider than its arms, the body wider than its body all round - never skin tight, no skin showing at the sides of its body or arms.`,
        `Keep the onesie's body as in the last image (as loose or looser), and the arms and hands exactly where they are in image 1. The ogre stays EXACTLY the size it is in image 1, and the costume runs all the way down OFF the bottom edge of the picture across its whole body, never ending above it. ${style}`,
      ] : layer === "outfit" ? [
        `Image 1 is an ogre character on a green background. Images 2 onward show example outfits worn by that same ogre.`,
        `EDIT image 1 itself - do not redraw the ogre. Paint the new item onto this exact picture: every pixel of the ogre that`,
        `the item doesn't cover stays exactly as it is (its head, face, ears, neck, arms and hands, where and how big they are),`,
        `and the green background stays. The only change: it now wears ${kind}: ${what}.`,
        `NOTHING of the outfit rises above the bottom of the jaw beside the head: no stand-up or high collar next to the`,
        `cheeks or ears. Collars are low: folded down, flat, or a rounded neckline at the base of the neck. Tall parts`,
        `(pauldrons, spikes, wings, capes, furs) belong on the shoulders and out to the sides, away from the head.`,
        `The ogre stays EXACTLY the size it is in image 1, not bigger or smaller, and the clothes run all the way down OFF the bottom edge of the picture across its whole body, cut off by the edge just as its body is in image 1 - never ending above it.`,
        `Keep its arms and hands EXACTLY where and as wide as in image 1. Anything on the arms (sleeves, bracers, gauntlets) is chunky and a little oversized, wrapping the whole arm with no skin showing at its sides.`,
        id.startsWith("crit_") ? `It is a LOOSE, roomy costume, a size too big for it: baggy sleeves clearly wider than its arms, the body wider than its body all round, soft and puffy - never skin tight, and no skin showing anywhere at the sides of its body or arms.` : "",
        `Fit the clothes naturally to its body. They don't have to follow its outline: big parts (pauldrons, spikes, capes,`,
        `wings, tails, furs) can stick out past it, and skimpy clothes can leave lots of skin bare (a loincloth, a mankini).`,
        `The head and face stay bare: no hat, no headwear, nothing over the face. ${style}`,
        matchHat ? "The image after the examples shows the hat of the same set: the clothes must match it (its colours, materials and theme), but do NOT draw the hat." : "",
      ] : [
        `Image 1 is an ogre character on a green background. Images 2 onward show example ${layer} pieces worn by that same ogre.`,
        `EDIT image 1 itself - do not redraw the ogre. Paint the new item onto this exact picture: every pixel of the ogre that`,
        `the item doesn't cover stays exactly as it is (its head, face, clothes and hands, where and how big they are), and the`,
        `green background stays. The only change: it now wears ${kind}: ${what}.`,
        layer === "accessory" && hold ? `It carries it: ${offhand ? `a shield held in front of the fist at the bottom ${hold === "left" ? "left" : "right"} corner, covering that whole fist and hand, facing the viewer, its lower part cut off by the bottom edge of the picture; a magic item (a book, mirror, orb or ring) instead hovers glowing just above that fist, as if casting with it. Big and clear, as its famous look.` : tall ? `standing tall beside its body at the bottom ${hold === "left" ? "left" : "right"} of the picture: the long haft or grip starts OFF the bottom edge of the picture (held below the frame, the hand not seen) and rises up past its shoulder, the whole weapon big and upright, as its famous look; the fist at that corner is hidden behind the weapon or off the edge.` : `brandishing it: the weapon angled up and FORWARD, its tip coming towards the viewer (a little foreshortened), like a pirate holding up a cutlass at the camera, big and clear, as its famous look. The fist wraps around the grip: the guard just above the fist and the pommel peeking out just below it, so it clearly reads as gripped.`} The arms and fists stay exactly where they are in image 1. It must not cover the face. ${style}` :
        layer === "accessory" ? `It carries it: a weapon strapped on its back with the handle sticking up over one shoulder (a big two-handed weapon may rest on its shoulder instead), a shield strapped on its back behind one shoulder, a book, orb or mirror floating beside its shoulder. Draw the item big and clear, as its famous look. It must not cover the face. ${style}` :
        `Fit it naturally on its head, as the examples sit. ${coversFace ? "It covers the lower face (nose, mouth and tusks) as described: that is meant; the eyes stay uncovered." : "It must not cover the eyes or the face: it sits on the head, above the brow."} ${style}`,
        behindEars ? "Its back parts (a knot, tails, straps) go BEHIND the ears: the ears are in front of them, covering them." : "",
        matchHat ? "The image after the examples shows the outfit of the same set: the headwear must match it (its colours, materials and theme), but the ogre keeps the clothes of image 1." : "",
      ]).concat(realRef ? ["The LAST image is a screenshot of the real item from the game: copy its shape, colours and details exactly (only the item, not the character or background in it)."] : []).join("\n");
      fs.writeFileSync(path.join(work, "prompt_wear.txt"), wearPrompt);
      const worn = generate(work, refs, wearPrompt, "worn.png");
      fs.mkdirSync(path.join(OUT, "review"), { recursive: true });
      fs.copyFileSync(worn, path.join(OUT, "review", `${id}_${edition}_worn.png`));
      // 2. ... then everything but it taken away, it left exactly where it is.
      const liftPrompt = (layer === "suit" ? [
        "Edit this image. Remove the ogre completely: its face, eyes, mouth, tusks, neck, hands and any bare skin.",
        `Keep ONLY the hooded onesie it wears (${what}): the suit AND its hood, exactly where they are, at exactly the same size`,
        "and shape, unchanged. The face inside the hood's opening becomes green too, as do the hands.",
        "Everything else becomes perfectly flat pure green (#00FF00).",
      ] : layer === "outfit" ? [
        "Edit this image. Remove the ogre completely: its head, face, ears, neck, hands and any bare skin.",
        `Keep ONLY the clothes it wears (${what}), exactly where they are, at exactly the same size and shape, unchanged.`,
        "Where skin showed between or around the clothes (the neck, bare arms, hands), fill with the green too.",
        "Everything else becomes perfectly flat pure green (#00FF00).",
      ] : [
        `Edit this image. Remove the ogre completely: its head, face, ears, body and clothes.`,
        `Keep ONLY the ${layer === "headwear" ? "headwear" : "accessory"} it wears (${what}), exactly where it is, at exactly the same`,
        `size and shape, unchanged. Where the head was inside or under it, fill with the green too.`,
        `Everything else becomes perfectly flat pure green (#00FF00).`,
        behindEars ? "Where the ears covered parts of it, leave those parts green too (a gap): do not draw what the ears hid." : "",
      ]).join("\n");
      fs.writeFileSync(path.join(work, "prompt_lift.txt"), liftPrompt);
      raw = generate(work, [worn], liftPrompt, "generated.png");
    } else {
      const prompt = [
        `Image 1 is an ogre character on a green background. Images 2 onward show example ${layer} pieces on that same ogre.`,
        `Draw ${kind}: ${what}.`,
        `Draw ONLY that piece, nothing else: no ogre, no face, no body, no shadow, no text, no frame.`,
        `Put it on a perfectly flat pure green (#00FF00) background, filling the background completely.`,
        layer === "headwear" ? "Draw it exactly where and at the size it would sit on the ogre's head in image 1, seen from the front."
          : "Draw it about a quarter of the image wide, where it would float beside the ogre in image 1, seen from the front.",
        style,
      ].join("\n");
      fs.writeFileSync(path.join(work, "prompt.txt"), prompt);
      raw = generate(work, refs, prompt, "generated.png");
    }
  }
  const rawCopy = path.join(OUT, "raw", `${id}_${edition}.png`);
  fs.mkdirSync(path.dirname(rawCopy), { recursive: true });
  if (path.resolve(raw) !== path.resolve(rawCopy)) fs.copyFileSync(raw, rawCopy);

  let keyed = key(load(raw));
  if (alone) {  // (centred as it was painted: placed by hand in the fitter)
    const out = path.join(OUT, edition, id + ".png");
    save(out, keyed);
    const now = ogre(edition, solid(40, 32, 40));
    over(now, keyed);
    save(path.join(OUT, "review", `${id}_${edition}.png`), now, 512);
    console.log(`Alone (placed by hand: node tools/item-fitter.js)\nPlaced: ${out}`);
    return;
  }
  // Worn: moved from the generator's ogre onto ours (it redraws the ogre a little bigger or smaller, higher or lower).
  const wornFile = path.join(work, "worn.png");
  let matched = false;
  if (fit === "wear" && fs.existsSync(wornFile)) {
    // (first the lift onto the worn picture, where it really was; then that picture's ogre onto ours)
    const worn = load(wornFile);
    const a = alignLift(keyed, worn);
    if (a && a.after < a.before - 2 && (Math.abs(a.s - 1) > 0.004 || Math.abs(a.tx) > 2 || Math.abs(a.ty) > 2)) {
      console.log(`The lift onto the worn picture: scale ${a.s.toFixed(3)}, moved ${Math.round(a.tx)}, ${Math.round(a.ty)} (colour difference ${a.before.toFixed(0)} -> ${a.after.toFixed(0)}).`);
      keyed = transform(keyed, a);
    }
    const t = register(worn, ogre(edition, null, layer === "outfit" || layer === "suit"), keyed, layer === "headwear" ? MATCH_HEAD : MATCH_BOTTOM);  // (keyed: the lifted hat, still where it is on theirs)
    if (t && t.score > 0.6) {
      console.log(`Its ogre onto ours: scale ${t.s.toFixed(2)}, matched ${(t.score * 100).toFixed(0)}% of the outline.`);
      keyed = transform(keyed, t);
      matched = true;
    } else {
      console.log("Couldn't match its ogre to ours: placed by the snap alone.");
    }
  }
  // (Worn and matched: where the model put it on the head is the fit; nothing nudged.)
  let piece = fit === "rule" ? place(keyed, rule) : fit === "wear" && matched ? keyed : snap(keyed, layer, rule);
  if (layer === "outfit" || layer === "suit") piece = extendBottom(piece);
  // (held in the fist: the grip moved into it, the fist in front; a two-hander rising from below the frame and an
  // off-hand covering the fist stay where the model put them)
  if (hold && !offhand && !tall) piece = cutHands(gripToFist(piece, hold), hold);  // (an off-hand stays where the model put it)  // (the grip into the fist, the fist in front of it)
  if (behindEars) piece = cutEars(piece);  // (the ears in front: cut out of it, exactly our ogre's)
  const out = path.join(OUT, edition, id + ".png");
  save(out, piece);
  // The review: the new piece on the ogre, as it looks; and a fit check with the head's outline over it.
  const now = ogre(edition, solid(40, 32, 40), layer === "outfit" || layer === "suit");
  over(now, piece);
  const review = path.join(OUT, "review", `${id}_${edition}.png`);
  save(review, now, 512);
  outline(now);  // (and a second one with the head's outline over it: does the brim follow the skull?)
  save(path.join(OUT, "review", `${id}_${edition}_fit.png`), now, 512);
  console.log(`Fit: ${fit}\nPlaced: ${out}\nReview: ${review}\nRaw:    ${rawCopy}\nThen: node tools/make-unlock-art.js gear && node tools/convert-art.js`);
}

// A queue (--queue file.json: [{ layer, id, desc, flags }]): each in turn, one after another; the ones already made
// skipped (--redo makes them again); three failures in a row stop it (likely the plan's image limit: run it again later).
// Then the unlock art is built and converted for the game. Its log: generated/queue.log. The list is read again before
// each piece (edit it while it runs: the change counts from the next piece); --from <id> starts at that piece.
// To stop without losing anything: create generated/queue.stop (node tools/gen-art.js --stop). The piece being painted
// is finished, what was made is built for the game, and the log says where to pick up (--from).
const STOP = path.join(OUT, "queue.stop");
function queue(file, redo, from) {
  if (fs.existsSync(STOP)) fs.rmSync(STOP);  // (an old one)
  const read = () => JSON.parse(fs.readFileSync(file, "utf8"));
  let jobs = read();
  if (from && !jobs.some((j) => j.id === from)) throw new Error("No " + from + " in " + file);
  const log = path.join(OUT, "queue.log");
  fs.mkdirSync(OUT, { recursive: true });
  const say = (text) => { const line = `${new Date().toISOString().slice(11, 19)} ${text}`; console.log(line); fs.appendFileSync(log, line + "\n"); };
  let made = 0, failedInRow = 0, n = 0;
  for (let i = 0; ; i++) {
    jobs = read();  // (before checking the length: pieces added while it runs count)
    const job = jobs[i];
    if (!job) break;
    n = i + 1;
    if (from) { if (job.id !== from) continue; from = null; }
    if (fs.existsSync(STOP)) {
      fs.rmSync(STOP);
      say(`Stopped before [${n}/${jobs.length}] ${job.id}. Pick up with: --queue ${file} --redo --from ${job.id}`);
      break;
    }
    if (!redo && fs.existsSync(path.join(OUT, "painted", job.id + ".png"))) { say(`[${n}/${jobs.length}] ${job.id}: there already, skipped`); continue; }
    say(`[${n}/${jobs.length}] ${job.id}: ${job.desc.split(":")[0]}...`);
    const run = spawnSync(process.execPath, [__filename, job.layer, job.id, job.desc, ...(job.flags || [])], { encoding: "utf8" });
    if (run.status === 0) {
      made++, failedInRow = 0;
      say(`  done (${(run.stdout.match(/matched \d+%/) || ["placed"])[0]})`);
    } else {
      failedInRow++;
      say(`  FAILED: ${((run.stderr || "") + (run.stdout || "")).trim().split("\n").slice(-2).join(" / ")}`);
      if (failedInRow >= 3) { say("Three failures in a row: stopping (the image limit?). Run the queue again later: it skips what's made."); break; }
    }
  }
  if (made > 0) {
    say(`${made} made: building the unlock art and converting it...`);
    spawnSync(process.execPath, [path.join(__dirname, "make-unlock-art.js"), "gear"], { stdio: "ignore" });
    spawnSync(process.execPath, [path.join(__dirname, "convert-art.js")], { stdio: "ignore" });
    say("Done: restart WoW to see them. Reviews in generated/review.");
  }
}

if (require.main === module) {
  const qi = process.argv.indexOf("--queue");
  try {
    if (process.argv.includes("--stop")) { fs.writeFileSync(STOP, ""); console.log("The queue stops after the piece it is painting."); return; }
    const fi = process.argv.indexOf("--from");
    if (qi > 0) queue(process.argv[qi + 1], process.argv.includes("--redo"), fi > 0 ? process.argv[fi + 1] : null);
    else main();
  } catch (e) { console.error(e.message); process.exit(1); }
}
module.exports = { key, despeckle, place, extendBottom, stretchBottom, generate, ogre, load, save, RULES, OUT, ART, SIZE };
