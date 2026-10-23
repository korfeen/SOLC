// New eyes and expressions (faces) for the minting art, made the way the originals sit: in the exact footprint of an
// existing face layer, with its soft edge, so nothing outside it changes (the skin keeps the head's outline, chin, jaw
// and brows; hats sit over the brows).
//
//   node tools/gen-face.js eyes x_eyes "both eyes knocked out: ..."  [--like heavy-bags] [--from raw.png]
//
// 1. Our moss ogre drawn as the game does (skin, pajamas, a mouth and eyes), cropped round the head: Codex repaints only
//    the eyes (or the mouth) on it.
// 2. Its picture is lined up with ours again (a small shift or size change: found on the parts that must not change).
// 3. Kept only inside the footprint of an existing layer of that kind (--like; its alpha, soft edge and all), its
//    colour matched to the skin at the edge so there's no seam.
// Out: %USERPROFILE%\killtracker-art-extra\Faces\<layer>\<id>_moss.png (1254 canvas, like the originals) and a review
// sheet beside it (now, new, new under a hat). The other skins: later (recoloured from moss).
const fs = require("fs");
const os = require("os");
const path = require("path");
const { spawnSync } = require("child_process");
const { decodePng, resample } = require("./convert-art");
const { writePng } = require("./make-role-icons");

const S = 1254;
const ART = path.join(os.homedir(), "killtracker-art");
const OUT = path.join(os.homedir(), "killtracker-art-extra", "Faces");
// The head crop given to Codex (canvas pixels) and the size it's sent at.
const CROP = { x: 380, y: 60, size: 494 }, SENT = 1024;
// What the ogre wears while its face is repainted, and the layer each kind of face replaces (its footprint).
const BASE = { skin: "Skin/Uncommon/moss.png", outfit: "Outfit/Uncommon/striped-pajamas.png",
  expression: "Expression/Uncommon/moss/smug-smile.png", eyes: "Eyes/Uncommon/moss/heavy-bags.png" };
const FOOTPRINT = { eyes: "Eyes/Uncommon/moss/%s.png", expression: "Expression/Uncommon/moss/%s.png" };
const DEFAULT_LIKE = { eyes: "heavy-bags", expression: "smug-smile" };

const load = (file) => { const p = decodePng(file); return p.width === S ? Buffer.from(p.rgba) : Buffer.from(resample(p, 0, 0, p.width, p.height, S, S)); };
function over(img, src, alpha) {
  for (let i = 0; i < S * S; i++) {
    const a = (src[i * 4 + 3] / 255) * (alpha ? alpha[i] : 1);
    if (!a) continue;
    const da = img[i * 4 + 3] / 255, oa = a + da * (1 - a);
    for (let c = 0; c < 3; c++) img[i * 4 + c] = (src[i * 4 + c] * a + img[i * 4 + c] * da * (1 - a)) / oa;
    img[i * 4 + 3] = oa * 255;
  }
}
function ogre(layers) {
  const img = Buffer.alloc(S * S * 4);
  for (let i = 0; i < S * S; i++) { img[i * 4] = 40; img[i * 4 + 1] = 38; img[i * 4 + 2] = 44; img[i * 4 + 3] = 255; }
  for (const l of layers) over(img, typeof l === "string" ? load(path.join(ART, l)) : l);
  return img;
}
const gray = (rgba, w, h) => { const g = new Float32Array(w * h); for (let i = 0; i < w * h; i++) g[i] = 0.3 * rgba[i * 4] + 0.59 * rgba[i * 4 + 1] + 0.11 * rgba[i * 4 + 2]; return g; };

// Lines Codex's picture (the crop, any size) up with ours: the scale and shift that best match the face where it must
// not change (outside the footprint, inside the head). Returns the picture in canvas pixels over the crop.
function align(made, base, footprint) {
  const N = 256, k = CROP.size / N;
  const ours = gray(Buffer.from(resample({ width: S, height: S, rgba: base }, CROP.x, CROP.y, CROP.size, CROP.size, N, N)), N, N);
  const mask = Buffer.from(resample({ width: S, height: S, rgba: footprint }, CROP.x, CROP.y, CROP.size, CROP.size, N, N));
  const head = load(path.join(ART, "head-mask.png"));
  const headSmall = Buffer.from(resample({ width: S, height: S, rgba: head }, CROP.x, CROP.y, CROP.size, CROP.size, N, N));
  const use = []; for (let i = 0; i < N * N; i++) if (headSmall[i * 4] > 128 && mask[i * 4 + 3] < 8) use.push(i);
  let best = null;
  for (let s = 0.94; s <= 1.0601; s += 0.01) for (let dy = -12; dy <= 12; dy += 1) for (let dx = -12; dx <= 12; dx += 1) {
    // (our crop pixel u -> made pixel: centre-scaled by s, shifted by dx, dy, in N units)
    const mw = made.width, sc = mw / N;
    let sum = 0, n = 0;
    for (let j = 0; j < use.length; j += 3) {
      const i = use[j], x = i % N, y = (i / N) | 0;
      const mx = Math.round(((x - N / 2) * s + N / 2 + dx) * sc), my = Math.round(((y - N / 2) * s + N / 2 + dy) * sc);
      if (mx < 0 || my < 0 || mx >= mw || my >= made.height) { sum += 255; n++; continue; }
      const m = (my * mw + mx) * 4;
      sum += Math.abs(0.3 * made.rgba[m] + 0.59 * made.rgba[m + 1] + 0.11 * made.rgba[m + 2] - ours[i]); n++;
    }
    const score = sum / n;
    if (!best || score < best.score) best = { s, dx, dy, score };
  }
  console.log(`Lined up: scale ${best.s.toFixed(2)}, shift ${best.dx * k | 0},${best.dy * k | 0} px, difference ${best.score.toFixed(1)}`);
  // Its picture back on the canvas, over the crop.
  const out = Buffer.alloc(S * S * 4), sc = made.width / N;
  for (let y = 0; y < CROP.size; y++) for (let x = 0; x < CROP.size; x++) {
    const ux = x / k, uy = y / k;
    const mx = Math.min(made.width - 1, Math.max(0, Math.round(((ux - N / 2) * best.s + N / 2 + best.dx) * sc)));
    const my = Math.min(made.height - 1, Math.max(0, Math.round(((uy - N / 2) * best.s + N / 2 + best.dy) * sc)));
    const d = ((CROP.y + y) * S + CROP.x + x) * 4, m = (my * made.width + mx) * 4;
    out[d] = made.rgba[m]; out[d + 1] = made.rgba[m + 1]; out[d + 2] = made.rgba[m + 2]; out[d + 3] = 255;
  }
  return { img: out, score: best.score };
}

function main() {
  const args = process.argv.slice(2);
  const flag = (name) => { const i = args.indexOf(name); if (i < 0) return null; const v = args[i + 1]; args.splice(i, 2); return v; };
  const like = flag("--like"), from = flag("--from");
  // (--brows: eyes that move the brows too: the footprint reaches up over them, soft-edged; hats still sit over it)
  const brows = args.includes("--brows");
  if (brows) args.splice(args.indexOf("--brows"), 1);
  const [layer, id, ...words] = args;
  const desc = words.join(" ");
  if (!FOOTPRINT[layer] || !id || (!desc && !from)) {
    console.log('Usage: node tools/gen-face.js <eyes|expression> <id> "<what it looks like>" [--like <existing moss layer>] [--from raw.png]');
    process.exit(1);
  }
  const work = path.join(OUT, "work", id);
  fs.mkdirSync(work, { recursive: true });
  const base = ogre([BASE.skin, BASE.outfit, BASE.expression, BASE.eyes]);
  const footprint = load(path.join(ART, FOOTPRINT[layer].replace("%s", like || DEFAULT_LIKE[layer])));
  if (brows && layer === "eyes") {
    // The brows' patch: a rounded box over both brows (canvas pixels), its edge feathered like the layers'.
    const B = { x0: 528, x1: 766, y0: 140, y1: 236 }, R = 30, FEATHER = 18;
    for (let y = 0; y < S; y++) for (let x = 0; x < S; x++) {
      const qx = Math.max(B.x0 + R - x, 0, x - (B.x1 - R)), qy = Math.max(B.y0 + R - y, 0, y - (B.y1 - R));
      const out = Math.hypot(qx, qy) - R;  // (<= 0 inside)
      const a = Math.round(255 * Math.max(0, Math.min(1, 1 - out / FEATHER)));
      const i = (y * S + x) * 4;
      if (a > footprint[i + 3]) footprint[i + 3] = a;
    }
  }

  // 1. Codex repaints the face.
  let raw = from;
  if (!raw) {
    const ref = path.join(work, "ref_head.png");
    writePng(ref, SENT, SENT, Buffer.from(resample({ width: S, height: S, rgba: base }, CROP.x, CROP.y, CROP.size, CROP.size, SENT, SENT)));
    const part = layer === "eyes" ? (brows ? "EYES AND BROWS (the eyes, the eyelids and bags round them, and the brows just above)"
      : "EYES (the eyes and the eyelids and bags right round them)") : "MOUTH (the lips, mouth and tusks)";
    const prompt = [
      "Edit this image of an ogre's head. Change ONLY its " + part + ": " + desc + ".",
      "Everything else stays EXACTLY as it is, pixel for pixel: the same head, the same position and size in the picture, the same",
      "skin colour and texture, lighting, nose, ears, " + (layer === "eyes" ? (brows ? "mouth and tusks" : "brows, mouth and tusks") : "brows, eyes") + ", outline, pajamas and background. Do not move, zoom,",
      "crop or re-frame anything. Keep the change small and inside the face where the " + (layer === "eyes" ? "eyes are" : "mouth is") + " now, in the same soft painted",
      "low-poly 3D look as the rest of the face.",
      "",
      "Use your image generation tool for this (one image, square). Save the image as made.png in the current directory, then reply with only its path.",
    ].join("\n");
    fs.writeFileSync(path.join(work, "prompt.txt"), prompt);
    raw = path.join(work, "made.png");
    if (fs.existsSync(raw)) fs.rmSync(raw);
    console.log("Asking Codex... about two minutes.");
    spawnSync(`codex exec --skip-git-repo-check -s workspace-write --ephemeral -C "${work}" -i "${ref}"`,
      { cwd: work, input: prompt, shell: true, encoding: "utf8", timeout: 600000 });
    if (!fs.existsSync(raw)) throw new Error("Codex made no image.");
  }

  // 2. Lined up with ours.
  const { img } = align(decodePng(raw), base, footprint);

  // 3. Only inside the footprint (its alpha), its colour matched to the skin at the edge.
  const alpha = new Float32Array(S * S);
  for (let i = 0; i < S * S; i++) alpha[i] = footprint[i * 4 + 3] / 255;
  const sumNew = [0, 0, 0], sumOld = [0, 0, 0]; let n = 0;
  for (let i = 0; i < S * S; i++) if (alpha[i] > 0.05 && alpha[i] < 0.7) {
    for (let c = 0; c < 3; c++) { sumNew[c] += img[i * 4 + c]; sumOld[c] += base[i * 4 + c]; } n++;
  }
  const gain = sumNew.map((v, c) => (n ? sumOld[c] / Math.max(1, v) : 1));
  console.log(`Edge colour match: x${gain.map((g) => g.toFixed(2)).join(" ")}`);
  const piece = Buffer.alloc(S * S * 4);
  for (let i = 0; i < S * S; i++) {
    if (!alpha[i]) continue;
    for (let c = 0; c < 3; c++) piece[i * 4 + c] = Math.min(255, img[i * 4 + c] * gain[c]);
    piece[i * 4 + 3] = footprint[i * 4 + 3];
  }
  fs.mkdirSync(path.join(OUT, layer), { recursive: true });
  const file = path.join(OUT, layer, `${id}_moss.png`);
  writePng(file, S, S, piece);

  // 4. The review: now | new | new under a hat.
  const now = base;
  const withNew = ogre([BASE.skin, BASE.outfit, ...(layer === "eyes" ? [BASE.expression] : [BASE.eyes]), piece, ...(layer === "eyes" ? [] : [])]);
  const hatFile = path.join(os.homedir(), "killtracker-art-extra", "Unlocks", "generated", "painted", "crit_murloc_head.png");
  const withHat = ogre([BASE.skin, BASE.outfit, ...(layer === "eyes" ? [BASE.expression] : [BASE.eyes]), piece, ...(fs.existsSync(hatFile) ? [load(hatFile)] : [])]);
  const T = 420, sheet = Buffer.alloc(T * 3 * T * 4);
  [now, withNew, withHat].forEach((pic, k) => {
    const px = resample({ width: S, height: S, rgba: pic }, CROP.x, CROP.y, CROP.size, CROP.size, T, T);
    for (let y = 0; y < T; y++) for (let x = 0; x < T; x++) { const s = (y * T + x) * 4, d = (y * T * 3 + k * T + x) * 4; for (let c = 0; c < 4; c++) sheet[d + c] = px[s + c]; }
  });
  const review = path.join(OUT, layer, `${id}_review.png`);
  writePng(review, T * 3, T, sheet);
  console.log("Made " + file + "\nReview " + review);
}
main();
