// Hand-drawn crayon versions of the minting art's headwear, accessories, eyes and mouths: each drawn in crayon
// (tools/make-role-icons.js) in the same place and about the same shape as the painted original. Eyes and mouths that
// the art draws once per skin colour (with a patch of skin round them) are drawn the same way here, the patch in that
// skin's colour (SKINS). Writes %USERPROFILE%\killtracker-art-extra\CrayonHand\<the original's path>, and compare.png:
// every original above its crayon version.
// Usage: node tools/make-crayon-items.js [filter]   No dependencies.

const fs = require("fs");
const os = require("os");
const path = require("path");
const crayon = require("./make-role-icons");
const { decodePng, resample } = require("./convert-art");

const SIZE = 1254;
crayon.setSize(SIZE);
const { canvas, dab, stroke, crayonShape, circle, ellipse, star, quad, rotate, hex, OUTLINE, rng, writePng } = crayon;
const ART = path.join(os.homedir(), "killtracker-art");
const OUT = path.join(os.homedir(), "killtracker-art-extra", "CrayonHand");
const filter = (process.argv[2] || "").split("/").join(path.sep);

// Crayon sizes for these (small things, shown at a fifth of this canvas or less).
const L = 14, H = 14;
const fill = (c, poly, color, r, o = {}) => crayonShape(c, poly, color, r, { fit: true, line: L, hatch: H, ...o });
const soft = (c, poly, color, r, o = {}) => fill(c, poly, color, r, { outline: null, ...o });  // no outline
const line = (c, points, width, color, r) => stroke(c, points, width, color, 0.95, r);
// A dot: a few crayon dabs on top of each other (too small to colour in).
const dot = (c, x, y, rad, color, r) => { for (let i = 0; i < 3; i++) dab(c, x + (r() - 0.5) * 2, y + (r() - 0.5) * 2, rad, color, 0.7); };
// A wobbly curve through points (each pair joined by a gentle quadratic).
const curve = (pts, n = 12) => pts.slice(1).flatMap((p, i) => {
  const a = pts[i], mid = [(a[0] + p[0]) / 2, (a[1] + p[1]) / 2];
  return quad(a, mid, p, n).slice(i ? 1 : 0);
});
const band = (pts, width) => {  // a thick band along a path, as a polygon
  const left = [], right = [];
  pts.forEach((p, i) => {
    const a = pts[Math.max(0, i - 1)], b = pts[Math.min(pts.length - 1, i + 1)];
    const dx = b[0] - a[0], dy = b[1] - a[1], d = Math.hypot(dx, dy) || 1;
    left.push([p[0] - (dy / d) * width / 2, p[1] + (dx / d) * width / 2]);
    right.push([p[0] + (dy / d) * width / 2, p[1] - (dx / d) * width / 2]);
  });
  return [...left, ...right.reverse()];
};
const K = {
  purple: hex("#7a4fd0"), cream: hex("#f6ead0"), gold: hex("#ffcf3a"), darkGold: hex("#e0a020"), black: hex("#3a3236"),
  red: hex("#e8463a"), green: hex("#5bb43a"), brown: hex("#8a5a2e"), blue: hex("#4f86e8"), white: hex("#ffffff"),
  orange: hex("#ff8a2a"), teal: hex("#3fb8b0"), grey: hex("#9aa0a8"), pink: hex("#ff8fb0"), navy: hex("#2c3e78"),
  olive: hex("#7d8a3a"), ice: hex("#bfefff"),
};
// Each skin's face colour (sampled from the skins), brightened a little like a crayon.
const SKINS = {
  "celestial-blue": [66, 72, 107], "enchanted-jade": [112, 119, 58], gold: [182, 131, 40], "obsidian-ember": [92, 56, 43],
  "sea-cursed-teal": [70, 114, 104], "pale-lavender": [164, 127, 155], "slate-gray": [106, 101, 102], "sunburnt-red": [182, 67, 54],
  moss: [136, 107, 43], "mud-brown": [125, 82, 47], "swamp-green": [104, 94, 48],
};
const skinCrayon = (rgb) => rgb.map((v) => Math.min(255, v * 1.18 + 10));

// The line round the top of the head that the painted hats sit on (their lower edge), shifted by dy.
const HEAD_LINE = [[516, 204], [560, 184], [590, 174], [630, 166], [660, 167], [702, 190], [740, 236], [760, 236]];
const head = (dy) => curve(HEAD_LINE.map(([x, y]) => [x, y + dy]), 8);
// The eyes and mouth positions (as in the art).
const EYE = [[590, 242], [702, 242]];
const MOUTH = [628, 338];
// The nose, as the crayon skins draw it (tools/make-crayon-base.js): the eye and mouth patches cover part of it, so
// each draws it again on top, the same, and it looks the same whatever is layered over the face.
const nose = (c, skin, r) => {
  fill(c, ellipse(632, 294, 52, 40), skin.map((v) => v * 0.7), r, { line: 16, hatch: 14 });
  soft(c, circle(616, 278, 11, 16), skin.map((v) => Math.min(255, v * 1.25)), r, { hatch: 6 });  // a highlight
  for (const x of [614, 650]) for (let i = 0; i < 2; i++) dab(c, x, 312, 9, OUTLINE, 0.9);
};
const eyePatch = (c, skin, r, which = EYE) => { for (const [x, y] of which) soft(c, ellipse(x, y + 4, 52, 34), skin, r); nose(c, skin, r); };
const mouthPatch = (c, skin, r) => { soft(c, ellipse(MOUTH[0], MOUTH[1], 110, 66), skin, r); nose(c, skin, r); };
const tusks = (c, r, y = 320) => {
  for (const [x, lean] of [[548, -6], [708, 6]]) fill(c, [[x - 14, y + 24], [x + 14, y + 24], [x + lean, y - 22]], K.cream, r, { line: 10, hatch: 8 });
};
// An open eye: white, a coloured iris, a pupil (slit, star or dot), a heavy lid line.
function openEye(c, r, x, y, iris, pupil = "dot", lid = true) {
  fill(c, ellipse(x, y, 30, 18), K.white, r, { line: 10, hatch: 8 });
  dot(c, x, y + 1, 12, iris, r);
  if (pupil === "dot") dot(c, x, y + 1, 5, OUTLINE, r);
  else if (pupil === "slit") line(c, [[x, y - 9], [x, y + 11]], 5, OUTLINE, r);
  else if (pupil === "star") soft(c, star(x, y + 1, 9, 4), K.white, r, { hatch: 4 });
  if (lid) line(c, curve([[x - 34, y - 6], [x, y - 16], [x + 34, y - 6]]), 10, OUTLINE, r);
}

// [path, draw(c, r, skin)]; skin: the skin's colour for per-skin ones (their path has "<skin>").
const ITEMS = [
  // --- Headwear: all sit on the head's line (HEAD), as the painted ones do ---
  ["Headwear/Epic/astral-nightcap.png", (c, r) => {
    fill(c, [...head(0), ...curve([[760, 236], [840, 170], [858, 236], [800, 200]]).slice(1), ...curve([[790, 150], [700, 86], [600, 84], [516, 204]]).slice(1)], K.purple, r);
    fill(c, band(head(-6), 30), K.cream, r);
    for (const [x, y] of [[600, 130], [680, 110], [740, 150], [650, 150]]) soft(c, star(x, y, 14, 6), K.gold, r, { hatch: 5 });
    fill(c, star(852, 246, 24, 10), K.gold, r, { line: 10, hatch: 7 });
  }],
  ["Headwear/Epic/bald-with-fly.png", (c, r) => {
    for (const [x, y] of curve([[610, 200], [640, 170], [680, 190], [700, 160], [714, 144]], 4)) dot(c, x, y, 3, OUTLINE, r);
    fill(c, ellipse(722, 140, 12, 9), OUTLINE, r, { line: 6, hatch: 5 });
    for (const dx of [-8, 8]) fill(c, ellipse(722 + dx, 128, 8, 6), K.ice, r, { line: 5, hatch: 4 });
  }],
  ["Headwear/Legendary/crown-of-eternal-rest.png", (c, r) => {
    fill(c, [...head(0).slice(0, -1), [744, 150], [700, 128], [628, 46], [560, 128], [512, 150]], K.gold, r);
    for (const [x, y, h] of [[540, 150, 50], [628, 70, 70], [726, 150, 50]]) fill(c, [[x - 18, y + 20], [x, y - h / 2], [x + 18, y + 20]], K.darkGold, r, { line: 10, hatch: 8 });
    fill(c, [...curve([[606, 130], [628, 104], [652, 130]]), ...curve([[646, 138], [628, 122], [612, 142]])], K.cream, r, { line: 8, hatch: 6 });
    for (const x of [566, 694]) dot(c, x, 168, 10, K.orange, r);
  }],
  ["Headwear/Legendary/dragon-hatchling-hat.png", (c, r) => {
    fill(c, [[484, 310], [480, 210], ...curve([[480, 210], [520, 110], [628, 86], [740, 110], [782, 210]]).slice(1), [780, 330], [742, 292],
      ...curve([[742, 240], [702, 190], [630, 166], [560, 184], [520, 236]]), [518, 290]], K.brown, r);
    for (const x of [586, 676]) { fill(c, circle(x, 140, 30), K.grey, r, { line: 12, hatch: 10 }); soft(c, circle(x, 140, 18), K.ice, r, { hatch: 8 }); }
    fill(c, ellipse(610, 64, 110, 38), K.red, r, { line: 12 });
    fill(c, [[600, 52], [640, 4], [690, 46]], hex("#c8302a"), r, { line: 10, hatch: 8 });
    fill(c, circle(716, 62, 26), K.red, r, { line: 12, hatch: 10 });
    line(c, [[706, 58], [724, 54]], 6, OUTLINE, r);
  }],
  ["Headwear/Rare/captain-tricorn.png", (c, r) => {
    const top = [...curve([[446, 196], [520, 96], [600, 112]]), ...curve([[600, 112], [690, 120], [770, 104]]).slice(1),
      ...curve([[770, 104], [860, 116], [906, 158]]).slice(1)];
    fill(c, [...top, [800, 240], ...curve([[800, 240], [740, 238], [700, 186], [630, 162], [560, 180], [446, 196]]).slice(1)], K.black, r);
    line(c, curve([[456, 198], [560, 184], [630, 166], [700, 188], [740, 238], [800, 236], [900, 164]]), 12, K.darkGold, r);
    fill(c, [...curve([[812, 150], [880, 84], [942, 62]]), ...curve([[942, 62], [900, 116], [826, 170]])], K.red, r, { line: 12, hatch: 10 });
  }],
  ["Headwear/Rare/flower-crown.png", (c, r) => {
    line(c, curve([[498, 200], [560, 176], [630, 156], [702, 176], [784, 236]]), 22, K.green, r);
    curve([[506, 196], [560, 174], [630, 154], [702, 172], [774, 228]], 3).forEach(([x, y], i) => {
      if (i % 2) return;
      const petal = i % 4 ? K.white : hex("#c7a6f0");
      for (let p = 0; p < 5; p++) { const an = (p / 5) * 2 * Math.PI; soft(c, circle(x + Math.cos(an) * 12, y - 6 + Math.sin(an) * 12, 10, 16), petal, r, { hatch: 5 }); }
      dot(c, x, y - 6, 7, K.gold, r);
    });
  }],
  ["Headwear/Rare/tiny-top-hat.png", (c, r) => {
    fill(c, rotate([[548, 66], [654, 66], [660, 160], [542, 160]], -0.12, 600, 120), K.black, r);
    fill(c, rotate([[543, 132], [659, 132], [660, 154], [542, 154]], -0.12, 600, 120), K.purple, r, { line: 10, hatch: 8 });
    fill(c, rotate(ellipse(600, 168, 92, 18), -0.12, 600, 120), K.black, r);
  }],
  ["Headwear/Rare/towel-turban.png", (c, r) => {
    fill(c, [...curve([[500, 204], [500, 110], [600, 26], [700, 36], [764, 120], [764, 232]]), ...curve([[764, 232], [702, 170], [630, 152], [560, 172], [500, 204]]).slice(1)], K.cream, r);
    for (const pts of [[[524, 160], [620, 96], [740, 150]], [[534, 108], [640, 60], [720, 80]], [[560, 186], [650, 132], [752, 196]]]) line(c, curve(pts), 10, hex("#c9b896"), r);
  }],
  ["Headwear/Uncommon/bucket-hat.png", (c, r) => {
    fill(c, [...curve([[530, 192], [556, 104], [640, 92], [720, 104], [744, 196]]), ...curve([[744, 196], [630, 168], [530, 192]]).slice(1)], K.olive, r);
    fill(c, band(curve([[462, 212], [560, 184], [630, 174], [702, 192], [808, 250]]), 30), hex("#6c7a30"), r);
  }],
  ["Headwear/Uncommon/nightcap-with-pom-pom.png", (c, r) => {
    fill(c, [...head(0), ...curve([[760, 236], [830, 180], [842, 232], [790, 196]]).slice(1), ...curve([[790, 150], [700, 86], [600, 84], [516, 204]]).slice(1)], K.blue, r);
    fill(c, band(head(-6), 30), K.cream, r);
    fill(c, circle(838, 240, 26), K.white, r, { line: 12, hatch: 10 });
  }],
  ["Headwear/Uncommon/sun-visor.png", (c, r) => {
    fill(c, band(curve([[514, 196], [560, 176], [630, 164], [702, 178], [798, 230]]), 28), K.cream, r);
    fill(c, [...curve([[624, 182], [720, 186], [802, 220]]), ...curve([[802, 220], [790, 244], [700, 230], [624, 200]])], K.teal, r);
  }],
  // --- Accessories ---
  ["Accessory/Epic/floating-sheep.png", (c, r) => {
    for (const [x, y] of [[920, 360], [960, 340], [1000, 366], [944, 398], [990, 400], [960, 372]]) soft(c, circle(x, y, 30), K.cream, r);
    fill(c, [...ellipse(960, 372, 72, 56)], K.cream, r, { line: 12 });
    fill(c, ellipse(930, 380, 24, 20), hex("#5a4a46"), r, { line: 10, hatch: 8 });
    for (const x of [922, 938]) line(c, curve([[x - 5, 378], [x, 382], [x + 5, 378]], 4), 4, K.white, r);
    for (const [x, y, s] of [[960, 300, 14], [990, 280, 18], [1022, 256, 22]]) {
      line(c, [[x - s / 2, y - s / 2], [x + s / 2, y - s / 2], [x - s / 2, y + s / 2], [x + s / 2, y + s / 2]], 6, K.gold, r);
    }
  }],
  ["Accessory/Epic/sleepy-parrot.png", (c, r) => {
    fill(c, [[320, 456], [370, 400], [356, 380]], K.blue, r, { line: 10 });
    fill(c, rotate(ellipse(400, 392, 48, 66), 0.4, 400, 392), K.red, r);
    fill(c, rotate(ellipse(380, 410, 26, 46), 0.5, 380, 410), K.blue, r, { line: 10 });
    soft(c, rotate(ellipse(372, 420, 14, 26), 0.5, 372, 420), K.gold, r);
    fill(c, circle(424, 338, 34), K.red, r, { line: 12 });
    fill(c, [[448, 330], [470, 344], [454, 372], [444, 352]], K.grey, r, { line: 10, hatch: 6 });
    line(c, curve([[410, 332], [420, 338], [430, 332]], 4), 5, OUTLINE, r);
    soft(c, circle(410, 360, 10), K.cream, r);
  }],
  ["Accessory/Legendary/moonstone-pendant.png", (c, r) => {
    line(c, curve([[456, 356], [520, 480], [614, 586]]), 6, K.grey, r);
    line(c, curve([[776, 356], [720, 480], [618, 586]]), 6, K.grey, r);
    fill(c, [...curve([[616, 590], [592, 616], [616, 636]]), ...curve([[616, 636], [640, 616], [616, 590]]).slice(1)], hex("#e4f2ff"), r, { line: 10, hatch: 8 });
  }],
  ["Accessory/Legendary/phoenix-on-shoulder.png", (c, r) => {
    for (const [dx, col] of [[-24, K.red], [0, K.orange], [24, K.gold]]) {
      fill(c, [[820 + dx, 430], [790 + dx * 2, 520], [834 + dx, 470]], col, r, { line: 10, hatch: 8 });
    }
    fill(c, rotate(ellipse(836, 410, 36, 50), 0.3, 836, 410), K.orange, r);
    fill(c, circle(856, 362, 24), K.red, r, { line: 10 });
    fill(c, [[874, 360], [890, 368], [874, 374]], K.gold, r, { line: 6, hatch: 5 });
    for (const dx of [-10, 0, 10]) line(c, [[852 + dx, 340], [848 + dx * 1.6, 326]], 6, K.gold, r);
  }],
  ["Accessory/Legendary/pocket-portal.png", (c, r) => {
    line(c, curve([[458, 356], [520, 480], [612, 590]]), 8, hex("#4a3426"), r);
    line(c, curve([[782, 356], [720, 480], [628, 590]]), 8, hex("#4a3426"), r);
    fill(c, circle(620, 626, 46), hex("#b07a3a"), r, { line: 12 });
    soft(c, circle(620, 626, 32), K.purple, r);
    const swirl = Array.from({ length: 30 }, (_, i) => { const a = i * 0.45, rad = 28 - i * 0.9; return [620 + Math.cos(a) * rad, 626 + Math.sin(a) * rad]; });
    line(c, swirl, 6, hex("#e8b8ff"), r);
  }],
  ["Accessory/Rare/gold-chain.png", (c, r) => {
    const links = curve([[448, 356], [520, 500], [620, 538], [720, 500], [792, 356]], 10);
    links.forEach(([x, y], i) => fill(c, rotate(ellipse(x, y, 14, 9, 16), i * 0.4, x, y), K.gold, r, { line: 6, hatch: 5 }));
  }],
  ["Accessory/Rare/monocle.png", (c, r) => {
    line(c, [...circle(704, 238, 38, 40), circle(704, 238, 38, 40)[0]], 12, K.gold, r);
    line(c, curve([[740, 252], [754, 300], [744, 350]]), 5, K.darkGold, r);
  }],
  ["Accessory/Rare/pet-frog.png", (c, r) => {
    fill(c, ellipse(860, 422, 50, 30), K.green, r);
    for (const x of [836, 884]) {
      fill(c, circle(x, 392, 16), K.green, r, { line: 10, hatch: 8 });
      line(c, curve([[x - 9, 392], [x, 398], [x + 9, 392]], 4), 5, OUTLINE, r);
    }
    line(c, curve([[838, 428], [860, 436], [882, 428]], 6), 5, OUTLINE, r);
  }],
  ["Accessory/Rare/pet-snail.png", (c, r) => {
    fill(c, [[346, 436], [440, 436], [452, 412], [430, 400], [360, 420]], hex("#e8c890"), r, { line: 10 });
    fill(c, circle(380, 392, 34), hex("#c07a3a"), r);
    const spiral = Array.from({ length: 28 }, (_, i) => { const a = i * 0.5, rad = 28 - i; return [380 + Math.cos(a) * rad, 392 + Math.sin(a) * rad]; });
    line(c, spiral, 6, OUTLINE, r);
    for (const dx of [0, 14]) { line(c, [[432 + dx, 410], [436 + dx, 368]], 5, OUTLINE, r); dot(c, 436 + dx, 366, 6, OUTLINE, r); }
  }],
  ["Accessory/Uncommon/eye-mask-pushed-up.png", (c, r) => {
    fill(c, [...curve([[536, 150], [580, 134], [636, 146], [692, 134], [738, 152]]), ...curve([[738, 152], [690, 190], [636, 176], [580, 190], [536, 150]]).slice(1)], K.navy, r);
    for (const [x, y] of curve([[552, 154], [636, 158], [722, 154]], 6)) dot(c, x, y, 3, K.white, r);
  }],
  ["Accessory/Uncommon/membership-card.png", (c, r) => {
    line(c, curve([[466, 356], [530, 470], [604, 590]]), 7, K.gold, r);
    line(c, curve([[770, 356], [700, 470], [632, 590]]), 7, OUTLINE, r);
    fill(c, rotate([[584, 588], [664, 588], [664, 640], [584, 640]], -0.08, 624, 614), K.cream, r, { line: 10 });
    fill(c, [...curve([[606, 600], [600, 618], [614, 630]]), ...curve([[614, 630], [604, 616], [612, 602]])], K.gold, r, { line: 5, hatch: 4 });
    line(c, [[630, 606], [642, 606], [630, 618], [642, 618]], 4, OUTLINE, r);
  }],
  // --- Eyes (per skin: a patch of skin round them) ---
  ["Eyes/Epic/<skin>/dreamy-swirl.png", (c, r, skin) => {
    eyePatch(c, skin, r);
    for (const [x, y] of EYE) {
      fill(c, ellipse(x, y, 30, 18), K.white, r, { line: 10, hatch: 8 });
      line(c, Array.from({ length: 22 }, (_, i) => { const a = i * 0.6, rad = 14 - i * 0.6; return [x + Math.cos(a) * rad, y + 1 + Math.sin(a) * rad]; }), 4, K.purple, r);
      line(c, curve([[x - 34, y - 6], [x, y - 16], [x + 34, y - 6]]), 10, OUTLINE, r);
    }
  }],
  ["Eyes/Epic/pirate-eyepatch.png", (c, r) => {
    line(c, curve([[550, 156], [620, 180], [690, 214]]), 9, OUTLINE, r);
    fill(c, rotate(ellipse(704, 238, 40, 30), 0.3, 704, 238), K.black, r);
  }],
  ["Eyes/Legendary/<skin>/dragon-gaze.png", (c, r, skin) => { eyePatch(c, skin, r); for (const [x, y] of EYE) openEye(c, r, x, y, K.orange, "slit"); }],
  ["Eyes/Legendary/<skin>/golden-oracle.png", (c, r, skin) => {
    eyePatch(c, skin, r);
    for (const [x, y] of EYE) { soft(c, ellipse(x, y, 40, 26), hex("#fff2a0"), r); openEye(c, r, x, y, K.gold, "dot"); }
  }],
  ["Eyes/Legendary/<skin>/starlit-dreamer.png", (c, r, skin) => { eyePatch(c, skin, r); for (const [x, y] of EYE) openEye(c, r, x, y, K.blue, "star"); }],
  ["Eyes/Rare/<skin>/bloodshot.png", (c, r, skin) => {
    eyePatch(c, skin, r);
    for (const [x, y] of EYE) {
      openEye(c, r, x, y, hex("#d06a5a"), "dot");
      for (const d of [-1, 1]) line(c, [[x + d * 26, y + 2], [x + d * 16, y + 4]], 3, K.red, r);
    }
  }],
  ["Eyes/Rare/<skin>/single-eye-open.png", (c, r, skin) => { eyePatch(c, skin, r, [EYE[0]]); openEye(c, r, EYE[0][0], EYE[0][1], K.green, "dot"); }],
  ["Eyes/Rare/cucumber-slices.png", (c, r) => {
    for (const [x, y] of [[584, 228], [700, 232]]) {
      fill(c, circle(x, y, 40), hex("#3f9a3a"), r, { line: 10 });
      soft(c, circle(x, y, 30), hex("#c8f0a0"), r);
      for (let i = 0; i < 6; i++) { const a = (i / 6) * 2 * Math.PI; dot(c, x + Math.cos(a) * 14, y + Math.sin(a) * 14, 3, hex("#e8ffd8"), r); }
    }
  }],
  ["Eyes/Uncommon/<skin>/fully-asleep.png", (c, r, skin) => {
    eyePatch(c, skin, r);
    for (const [x, y] of EYE) {
      line(c, curve([[x - 32, y], [x, y + 12], [x + 32, y]]), 9, OUTLINE, r);
      for (const dx of [-16, 0, 16]) line(c, [[x + dx, y + 8], [x + dx * 1.2, y + 18]], 4, OUTLINE, r);
    }
  }],
  ["Eyes/Uncommon/<skin>/heavy-bags.png", (c, r, skin) => {
    eyePatch(c, skin, r);
    for (const [x, y] of EYE) {
      openEye(c, r, x, y, hex("#7a5a3a"), "dot");
      line(c, curve([[x - 28, y + 22], [x, y + 34], [x + 28, y + 22]]), 7, hex("#5a4a3a"), r);
    }
  }],
  // --- Mouths (per skin: a patch of skin round them) and face extras ---
  ["Expression/Epic/<skin>/sea-dog-grin.png", (c, r, skin) => {
    mouthPatch(c, skin, r);
    line(c, curve([[540, 340], [628, 372], [716, 340]]), 10, OUTLINE, r);
    tusks(c, r);
    fill(c, [[660, 346], [680, 346], [678, 366], [662, 366]], K.gold, r, { line: 6, hatch: 5 });
  }],
  ["Expression/Legendary/<skin>/ember-yawn.png", (c, r, skin) => {
    mouthPatch(c, skin, r);
    fill(c, ellipse(628, 356, 70, 36), hex("#5a1a10"), r, { line: 12 });
    soft(c, ellipse(628, 364, 44, 18), K.orange, r);
    tusks(c, r, 330);
  }],
  ["Expression/Legendary/crystal-drool.png", (c, r) => {
    fill(c, [...curve([[700, 340], [690, 360], [700, 378]]), ...curve([[700, 378], [712, 360], [702, 340]])], K.ice, r, { line: 6, hatch: 5 });
    fill(c, rotate([[690, 370], [712, 370], [712, 392], [690, 392]], 0.78, 701, 381), hex("#7fe8f0"), r, { line: 6, hatch: 5 });
  }],
  ["Expression/Legendary/stardust-snore.png", (c, r) => {
    for (const [x, y] of curve([[728, 344], [770, 320], [810, 330], [850, 290], [884, 268]], 4)) dot(c, x, y, 3, hex("#c08aff"), r);
    for (const [x, y, s] of [[740, 340, 10], [800, 324, 14], [880, 270, 20]]) fill(c, star(x, y, s, s * 0.4), hex("#f0d0ff"), r, { line: 5, hatch: 4 });
  }],
  ["Expression/Rare/<skin>/mid-yawn.png", (c, r, skin) => {
    mouthPatch(c, skin, r);
    fill(c, ellipse(628, 350, 58, 44), hex("#4a1a18"), r, { line: 12 });
    soft(c, ellipse(628, 372, 34, 16), K.pink, r);
    tusks(c, r, 326);
  }],
  ["Expression/Uncommon/<skin>/mouth-hanging-open.png", (c, r, skin) => {
    mouthPatch(c, skin, r);
    fill(c, ellipse(628, 350, 76, 30), hex("#4a1a18"), r, { line: 12 });
    soft(c, ellipse(628, 362, 44, 12), K.pink, r);
    tusks(c, r, 326);
  }],
  ["Expression/Uncommon/<skin>/smug-smile.png", (c, r, skin) => {
    mouthPatch(c, skin, r);
    line(c, curve([[548, 336], [628, 360], [712, 328]]), 10, OUTLINE, r);
    tusks(c, r);
  }],
  ["Expression/Uncommon/drooling.png", (c, r) => {
    fill(c, [...curve([[680, 336], [672, 380], [686, 412]]), ...curve([[686, 412], [700, 380], [692, 336]])], K.ice, r, { line: 6, hatch: 5 });
  }],
  ["Expression/Uncommon/snoring-zzz-bubble.png", (c, r) => {
    fill(c, [[742, 340], [780, 310], ...curve([[780, 310], [770, 260], [830, 248], [900, 262], [906, 310], [850, 334], [790, 324]]).slice(1)], K.white, r, { line: 12 });
    for (const [x, y, s] of [[800, 284, 26], [836, 296, 22], [868, 306, 18]]) line(c, [[x - s / 2, y - s / 2], [x + s / 2, y - s / 2], [x - s / 2, y + s / 2], [x + s / 2, y + s / 2]], 6, K.blue, r);
  }],
  ["Expression/Uncommon/tiny-snore-bubble.png", (c, r) => {
    fill(c, circle(560, 270, 28), hex("#d8f4ff"), r, { line: 8, hatch: 8 });
    dot(c, 552, 262, 6, K.white, r);
  }],
];

// --- Draw them all ---
const written = [];
ITEMS.forEach(([pattern, draw], n) => {
  const skins = pattern.includes("<skin>") ? Object.keys(SKINS) : [null];
  for (const skin of skins) {
    const rel = (skin ? pattern.replace("<skin>", skin) : pattern).split("/").join(path.sep);
    if (!rel.includes(filter)) continue;
    if (skin && !fs.existsSync(path.join(ART, rel))) continue;  // only the skins the art has it for
    const c = canvas();
    draw(c, rng(777 + n * 7919), skin && skinCrayon(SKINS[skin]));
    fs.mkdirSync(path.join(OUT, path.dirname(rel)), { recursive: true });
    writePng(path.join(OUT, rel), SIZE, SIZE, crayon.toRgba(c));
    written.push(rel);
  }
});

// --- Compare: each item (the moss version of per-skin ones), the original above the crayon one, cropped round it ---
const shown = ITEMS.map(([p]) => p.replace("<skin>", "moss").split("/").join(path.sep)).filter((p) => written.includes(p));
const C = 150, cols = 11, rows = Math.ceil(shown.length / cols), W = C * cols, HH = C * rows * 2;
const px = Buffer.alloc(W * HH * 4);
for (let i = 0; i < px.length; i += 4) px.set([70, 70, 74, 255], i);
shown.forEach((rel, k) => {
  const orig = decodePng(path.join(ART, rel)), mine = decodePng(path.join(OUT, rel));
  let x0 = SIZE, y0 = SIZE, x1 = 0, y1 = 0;
  for (const im of [orig, mine]) for (let y = 0; y < SIZE; y += 3) for (let x = 0; x < SIZE; x += 3) {
    if (im.rgba[(y * SIZE + x) * 4 + 3] > 40) { x0 = Math.min(x0, x); y0 = Math.min(y0, y); x1 = Math.max(x1, x); y1 = Math.max(y1, y); }
  }
  const side = Math.max(x1 - x0, y1 - y0) + 24, sx = Math.max(0, (x0 + x1 - side) / 2), sy = Math.max(0, (y0 + y1 - side) / 2);
  const sw = Math.min(side, SIZE - sx), sh = Math.min(side, SIZE - sy);
  [orig, mine].forEach((im, row) => {
    const sm = resample(im, sx, sy, sw, sh, C - 4, C - 4);
    const ox = (k % cols) * C + 2, oy = (Math.floor(k / cols) * 2 + row) * C + 2;
    for (let y = 0; y < C - 4; y++) for (let x = 0; x < C - 4; x++) {
      const i = (y * (C - 4) + x) * 4, a = sm[i + 3] / 255, o = ((oy + y) * W + ox + x) * 4;
      for (let ch = 0; ch < 3; ch++) px[o + ch] = Math.round(sm[i + ch] * a + px[o + ch] * (1 - a));
    }
  });
});
try { writePng(path.join(OUT, "compare.png"), W, HH, px); } catch (e) { console.log("(compare.png is open elsewhere - not updated)"); }
console.log(`Wrote ${written.length} crayon items to ${OUT}`);
