// Crayon art for the Overview (OverviewCard.lua, FeedDetail.lua), in the fridge-drawing style
// (tools/make-crayon-backgrounds.js); every scene 2:1, cropped by the game:
// - Professions: behind a profession's info on CRAFTS. The main thing on the right (the icon, name and skill bar go over
//   the left and middle, on a darkening); only about the middle two thirds of the height show: keep what matters
//   between y 100 and 410.
// - Feed and Dungeons (tools/overview-dungeons.js): behind a feed event's details on the right page (a creature's model or a rank's badge goes over the middle).
//   The full height shows but only about the middle 72% of the width: keep what matters between x 150 and 870.
// Writes Media/Overview/<set>/<KEY>.blp (512x256) and a preview sheet per set,
// %USERPROFILE%\killtracker-art-extra\Overview\<set>.png (the shown part outlined).
// Usage: node tools/make-overview-art.js [filter]   No dependencies.

const fs = require("fs");
const os = require("os");
const path = require("path");
const crayon = require("./make-role-icons");
const { resample, writeBlp } = require("./convert-art");

const W = 1024, H = 512;  // drawn on the top half of a square canvas
crayon.setSize(W);
const { canvas, dab, stroke, crayonShape, circle, ellipse, star, quad, rotate, hex, OUTLINE, rng, writePng } = crayon;
const MEDIA = path.join(__dirname, "..", "Media", "Overview");
const PREVIEW = path.join(os.homedir(), "killtracker-art-extra", "Overview");
const filter = (process.argv[2] || "").toUpperCase();

const LINE = 14, HATCH = 22;
const fill = (c, poly, col, r, o = {}) => crayonShape(c, poly, hex(col), r, { fit: true, line: LINE, hatch: HATCH, ...o });
const soft = (c, poly, col, r, o = {}) => fill(c, poly, col, r, { outline: null, ...o });
const line = (c, pts, w, col, r) => stroke(c, pts, w, typeof col === "string" ? hex(col) : col, 0.95, r);
const curve = (pts, n = 16) => pts.slice(1).flatMap((p, i) => quad(pts[i], [(pts[i][0] + p[0]) / 2, (pts[i][1] + p[1]) / 2], p, n).slice(i ? 1 : 0));
const rect = (x0, y0, x1, y1) => [[x0, y0], [x1, y0], [x1, y1], [x0, y1]];
const wall = (c, r, col) => soft(c, rect(0, 0, W, H), col, r, { hatch: 30 });
const floor = (c, r, y, col) => fill(c, rect(-20, y, W + 20, H + 20), col, r, { hatch: 26 });
const dots = (c, r, n, col, size, box) => {
  for (let i = 0; i < n; i++) dab(c, box[0] + r() * (box[2] - box[0]), box[1] + r() * (box[3] - box[1]), size * (0.6 + r() * 0.6), hex(col), 0.9);
};
const sparkle = (c, r, x, y, size, col) => fill(c, star(x, y, size, size * 0.4), col, r, { line: 8 });
// A cog: teeth round a wheel, a hole in the middle.
function gear(c, r, cx, cy, rad, teeth, col) {
  const pts = [];
  for (let i = 0; i < teeth * 4; i++) {
    const a = (i / (teeth * 4)) * 2 * Math.PI, out = i % 4 < 2;
    pts.push([cx + Math.cos(a) * (out ? rad : rad * 0.8), cy + Math.sin(a) * (out ? rad : rad * 0.8)]);
  }
  fill(c, pts, col, r, { holes: [circle(cx, cy, rad * 0.3)] });
}
function flower(c, r, x, y, size, petal, middle = "#ffd23f") {
  line(c, [[x, y + size], [x + 6, y + size * 3.2]], 10, "#3f8f3a", r);
  for (let i = 0; i < 6; i++) {
    const a = (i / 6) * 2 * Math.PI;
    fill(c, circle(x + Math.cos(a) * size * 0.8, y + Math.sin(a) * size * 0.8, size * 0.6), petal, r, { line: 9 });
  }
  fill(c, circle(x, y, size * 0.5), middle, r, { line: 9 });
}
// A hide: a lumpy stretched pelt round (x, y).
const hide = (x, y, w, h) => [[x - w * 0.5, y - h * 0.5], [x - w * 0.2, y - h * 0.42], [x, y - h * 0.55], [x + w * 0.2, y - h * 0.42],
  [x + w * 0.5, y - h * 0.5], [x + w * 0.4, y - h * 0.1], [x + w * 0.5, y + h * 0.45], [x + w * 0.15, y + h * 0.38], [x, y + h * 0.5],
  [x - w * 0.15, y + h * 0.38], [x - w * 0.5, y + h * 0.45], [x - w * 0.4, y - h * 0.1]];
function flame(c, r, x, y, w, h) {
  fill(c, curve([[x - w, y], [x - w * 0.9, y - h * 0.5], [x, y - h], [x + w * 0.9, y - h * 0.5], [x + w, y]], 8), "#ff7a1a", r, { line: 10 });
  fill(c, curve([[x - w * 0.5, y], [x - w * 0.4, y - h * 0.35], [x, y - h * 0.6], [x + w * 0.4, y - h * 0.35], [x + w * 0.5, y]], 8), "#ffd23f", r, { outline: null });
}

const PROFESSIONS = {
  ALCHEMY(c, r) {
    wall(c, r, "#3b2a4a");
    fill(c, rect(-20, 210, 560, 232), "#7a4a26", r);  // the shelf
    [["#e0403a", 90], ["#3a8ae0", 170], ["#ffd23f", 250], ["#7ad85a", 330], ["#e07ad8", 410], ["#3ad8c8", 490]].forEach(([col, x], i) => {
      const h = 50 + (i % 3) * 14;
      fill(c, rect(x - 22, 210 - h, x + 22, 210), col, r, { line: 10 });
      fill(c, rect(x - 9, 210 - h - 24, x + 9, 210 - h), "#d8f0f0", r, { line: 8 });
    });
    floor(c, r, 410, "#6b4022");
    fill(c, rect(768, 150, 832, 250), "#d8f0f0", r);  // the big flask
    fill(c, circle(800, 320, 110), "#d8f0f0", r);
    soft(c, circle(800, 320, 110).filter(([, y]) => y > 300), "#6af04a", r);
    for (const [x, y, s] of [[790, 128, 14], [822, 108, 10], [806, 84, 8], [830, 300, 12], [770, 360, 16], [820, 380, 9]]) {
      fill(c, circle(x, y, s), "#b8ff9a", r, { line: 6 });
    }
    flame(c, r, 800, 450, 60, 70);
  },
  BLACKSMITHING(c, r) {
    wall(c, r, "#2a1a14");
    soft(c, ellipse(170, 330, 240, 150), "#ff7a1a", r);  // the forge's glow
    soft(c, ellipse(170, 350, 140, 80), "#ffcc33", r);
    floor(c, r, 400, "#3a2a20");
    fill(c, [[630, 250], [970, 250], [940, 295], [870, 300], [850, 360], [890, 405], [710, 405], [750, 360], [730, 300], [630, 285]], "#5a5f66", r);
    line(c, [[600, 160], [760, 250]], 24, "#8a5a30", r);  // the hammer
    fill(c, rotate(rect(560, 110, 640, 170), 0.5, 600, 140), "#9aa0a8", r);
    for (let i = 0; i < 9; i++) sparkle(c, r, 820 + r() * 180, 140 + r() * 90, 10 + r() * 10, i % 2 ? "#ffd23f" : "#ff9a2a");
  },
  ENCHANTING(c, r) {
    wall(c, r, "#1c1f4a");
    dots(c, r, 70, "#fff2a8", 3, [0, 0, W, H]);
    fill(c, circle(800, 290, 160), "#b07aff", r, { holes: [circle(800, 290, 132)] });  // the rune circle
    fill(c, star(800, 290, 118, 48), "#e0c8ff", r);
    for (let i = 0; i < 8; i++) {
      const a = (i / 8) * 2 * Math.PI;
      dab(c, 800 + Math.cos(a) * 146, 290 + Math.sin(a) * 146, 8, hex("#ffffff"), 0.9);
    }
    line(c, [[560, 430], [690, 190]], 16, "#d8a040", r);  // the rod
    fill(c, circle(690, 186, 22), "#9fe8ff", r);
    for (let i = 0; i < 7; i++) sparkle(c, r, 560 + r() * 440, 110 + r() * 300, 8 + r() * 10, "#9fe8ff");
  },
  ENGINEERING(c, r) {
    wall(c, r, "#2b3a44");
    fill(c, rect(-20, 120, W + 20, 140), "#4a5a64", r);  // a pipe
    gear(c, r, 800, 300, 145, 12, "#a0a8b0");
    gear(c, r, 625, 200, 75, 8, "#d0a040");
    gear(c, r, 975, 440, 95, 10, "#c06a3a");
    line(c, [[330, 410], [500, 270]], 26, "#c0c8d0", r);  // a wrench
    fill(c, rotate(circle(510, 260, 40), 0, 0, 0), "#c0c8d0", r, { holes: [circle(522, 248, 16)] });
    dots(c, r, 12, "#e8e8e8", 7, [40, 180, 480, 460]);
  },
  HERBALISM(c, r) {
    wall(c, r, "#8fd0ff");
    fill(c, circle(130, 130, 46), "#ffd23f", r);
    fill(c, [[-20, H + 20], ...curve([[-20, 330], [300, 290], [600, 340], [W + 20, 300]], 12), [W + 20, H + 20]], "#5cb84a", r);
    flower(c, r, 820, 230, 46, "#ff7ab0");
    flower(c, r, 680, 300, 30, "#ffffff");
    flower(c, r, 950, 310, 32, "#b07aff");
    flower(c, r, 420, 350, 22, "#ffd23f", "#ff7a1a");
    for (let i = 0; i < 10; i++) {
      const x = 40 + i * 100 + r() * 30;
      line(c, curve([[x, 470], [x - 12, 420], [x + 6, 380]], 6), 8, "#2f7a2a", r);
    }
  },
  LEATHERWORKING(c, r) {
    wall(c, r, "#5a3a22");
    line(c, [[640, 120], [960, 460]], 18, "#3a2414", r);  // the stretching frame
    line(c, [[960, 120], [640, 460]], 18, "#3a2414", r);
    fill(c, hide(800, 290, 300, 260), "#c89060", r);
    const seam = curve([[700, 200], [800, 240], [900, 200]], 10);
    for (let i = 0; i < seam.length - 1; i += 2) line(c, [[seam[i][0], seam[i][1] - 8], [seam[i][0], seam[i][1] + 8]], 6, OUTLINE, r);
    line(c, [[500, 400], [640, 300]], 8, "#e0e0e0", r);  // a needle and its thread
    line(c, curve([[500, 400], [420, 440], [380, 360], [300, 420]], 8), 5, "#f0e0b0", r);
    fill(c, hide(220, 250, 180, 150), "#8a5a34", r);
  },
  MINING(c, r) {
    wall(c, r, "#2a2420");
    for (const [x, y, s] of [[120, 160, 120], [380, 120, 140], [620, 430, 160], [900, 140, 150], [260, 440, 130]]) {
      fill(c, circle(x, y, s, 9), "#4a4038", r);
    }
    for (const [col, x, y] of [["#e0a040", 880, 260], ["#ffd84a", 960, 360], ["#9fe8ff", 740, 220], ["#e0a040", 420, 280]]) {
      for (let i = 0; i < 6; i++) fill(c, circle(x + (r() - 0.5) * 70, y + (r() - 0.5) * 50, 10 + r() * 8, 6), col, r, { line: 8 });
    }
    line(c, [[640, 440], [850, 200]], 26, "#8a5a30", r);  // the pickaxe
    line(c, curve([[730, 190], [840, 150], [960, 230]], 10), 34, "#9aa0a8", r);
    soft(c, circle(200, 250, 90), "#ffcc55", r);  // a lantern
    fill(c, rect(175, 215, 225, 290), "#ffe08a", r);
    fill(c, rect(168, 200, 232, 215), "#3a3236", r, { line: 8 });
  },
  SKINNING(c, r) {
    wall(c, r, "#3a2a3e");
    for (let i = 0; i < 6; i++) {
      const x = 60 + i * 180, h = 200 + r() * 120;
      fill(c, [[x - 70, 470], [x, 470 - h], [x + 70, 470]], "#1f3a2a", r);
    }
    floor(c, r, 450, "#2a2018");
    line(c, curve([[540, 130], [780, 175], [1040, 130]], 12), 8, "#c8a070", r);  // the drying line
    fill(c, hide(640, 260, 150, 200), "#a06a3a", r);
    fill(c, hide(800, 280, 170, 230), "#d8c8b0", r);
    fill(c, hide(960, 260, 140, 190), "#6a4a2a", r);
    line(c, [[420, 420], [520, 330]], 12, "#c0c8d0", r);  // a knife
    line(c, [[390, 448], [420, 420]], 18, "#6a4020", r);
  },
  TAILORING(c, r) {
    wall(c, r, "#4a2a4a");
    for (const [col, y] of [["#e07a9a", 140], ["#7ab0e0", 250], ["#e0c86a", 360]]) {
      fill(c, [[-20, y], ...curve([[-20, y], [200, y - 30], [420, y + 20], [540, y - 10]], 10), [540, y + 80], [-20, y + 90]], col, r);
    }
    fill(c, rect(740, 200, 860, 380), "#e04a6a", r);  // the spool
    for (let y = 215; y < 370; y += 22) line(c, [[745, y], [855, y + 6]], 4, "#a02a4a", r);
    fill(c, ellipse(800, 195, 90, 26), "#c08a50", r);
    fill(c, ellipse(800, 385, 90, 26), "#c08a50", r);
    line(c, [[600, 430], [700, 170]], 10, "#dcdcdc", r);  // the needle
    line(c, curve([[700, 175], [760, 120], [860, 140], [900, 260], [860, 300]], 10), 5, "#e04a6a", r);
    for (const [x, y] of [[940, 140], [960, 430], [600, 120]]) {
      fill(c, circle(x, y, 22), "#ffd23f", r, { line: 8 });
      dab(c, x - 6, y, 4, OUTLINE, 0.9);
      dab(c, x + 6, y, 4, OUTLINE, 0.9);
    }
  },
  COOKING(c, r) {
    wall(c, r, "#5a2e1a");
    floor(c, r, 430, "#3a2014");
    flame(c, r, 760, 460, 60, 90);
    flame(c, r, 860, 460, 50, 70);
    fill(c, [[680, 260], [920, 260], [900, 400], [700, 400]], "#3a3a40", r);  // the pot
    fill(c, ellipse(800, 260, 130, 28), "#5a5a62", r);
    soft(c, ellipse(800, 258, 105, 18), "#e0b040", r);
    for (const x of [740, 800, 860]) line(c, curve([[x, 225], [x - 20, 180], [x + 15, 140], [x - 5, 100]], 8), 12, "#f0ece0", r);
    fill(c, rotate(ellipse(300, 300, 90, 60), -0.5, 300, 300), "#b0602a", r);  // a drumstick
    line(c, [[360, 250], [430, 200]], 22, "#f4f0e0", r);
    fill(c, circle(438, 190, 18), "#f4f0e0", r, { line: 8 });
  },
  FISHING(c, r) {
    wall(c, r, "#2a3a6a");
    dots(c, r, 30, "#fff2a8", 3, [0, 0, W, 260]);
    fill(c, circle(160, 150, 52), "#fff2a8", r);
    fill(c, rect(-20, 300, W + 20, H + 20), "#2a6aa0", r);
    for (let i = 0; i < 8; i++) {
      const x = 40 + i * 130, y = 340 + (i % 3) * 45;
      line(c, curve([[x, y], [x + 30, y - 12], [x + 60, y]], 6), 6, "#8ac8f0", r);
    }
    line(c, [[520, 60], [640, 120]], 14, "#8a5a30", r);  // the rod's tip and the line
    line(c, curve([[640, 120], [780, 150], [840, 290]], 12), 4, "#e8e8e8", r);
    fill(c, circle(840, 300, 28).filter(([, y]) => y <= 300), "#e0403a", r, { line: 8 });  // the bobber
    fill(c, circle(840, 300, 28).filter(([, y]) => y >= 300), "#ffffff", r, { line: 8 });
    fill(c, rotate(ellipse(680, 330, 60, 28), -0.6, 680, 330), "#ffb040", r);  // a fish jumping
    fill(c, rotate([[628, 330], [578, 296], [578, 364]], -0.6, 680, 330), "#ffb040", r, { line: 8 });
    dab(c, 715, 300, 5, OUTLINE, 0.9);
  },
  FIRSTAID(c, r) {
    wall(c, r, "#d8c8a8");
    fill(c, [[760, 160], [840, 160], [840, 250], [930, 250], [930, 330], [840, 330], [840, 420], [760, 420], [760, 330], [670, 330],
      [670, 250], [760, 250]], "#e0403a", r);
    fill(c, circle(440, 310, 90), "#f4f0e8", r, { holes: [circle(440, 310, 22)] });  // a bandage roll
    line(c, curve([[440, 250], [490, 280], [480, 340], [430, 360], [395, 320]], 10), 5, "#c8c0b0", r);
    fill(c, [[510, 390], [700, 360], [705, 400], [515, 430]], "#f4f0e8", r);
    for (const [x, y, a] of [[180, 180, 0.6], [240, 420, -0.4]]) {
      fill(c, rotate(rect(x - 60, y - 18, x + 60, y + 18), a, x, y), "#f0c090", r, { line: 8 });
      fill(c, rotate(rect(x - 16, y - 14, x + 16, y + 14), a, x, y), "#f8e0c0", r, { outline: null });
    }
  },
};

// A stone arch round a dark doorway (the dungeon entrance): blocks along the half-ellipse.
function arch(c, r, cx, base, rx, ry) {
  const n = 9;
  for (let i = 0; i < n; i++) {
    const a0 = Math.PI + (i / n) * Math.PI, a1 = Math.PI + ((i + 1) / n) * Math.PI;
    const at = (a, k) => [cx + Math.cos(a) * rx * k, base + Math.sin(a) * ry * k];
    fill(c, [at(a0, 1), at(a1, 1), at(a1, 1.28), at(a0, 1.28)], i % 2 ? "#8a8078" : "#a09890", r, { line: 10 });
  }
}
// Sun rays from a point, every other wedge in a lighter colour.
function rays(c, r, cx, cy, n, col) {
  for (let i = 0; i < n; i += 2) {
    const a0 = (i / n) * 2 * Math.PI, a1 = ((i + 1) / n) * 2 * Math.PI;
    soft(c, [[cx, cy], [cx + Math.cos(a0) * 1400, cy + Math.sin(a0) * 1400], [cx + Math.cos(a1) * 1400, cy + Math.sin(a1) * 1400]], col, r);
  }
}
const FEED = {
  DUNGEON(c, r) {
    wall(c, r, "#2a2430");
    fill(c, [[-20, 460], [120, 180], [300, 90], [512, 40], [720, 100], [900, 170], [W + 20, 440]], "#4a4040", r, { hatch: 26 });
    fill(c, ellipse(512, 470, 150, 300).filter(([, y]) => y <= 470), "#120c10", r, { outline: null });
    arch(c, r, 512, 470, 150, 300);
    dab(c, 488, 300, 9, hex("#ffd23f"), 0.95);  // something looking out
    dab(c, 536, 300, 9, hex("#ffd23f"), 0.95);
    floor(c, r, 460, "#3a3030");
    for (const x of [300, 724]) {
      line(c, [[x, 470], [x, 330]], 18, "#6a4020", r);
      flame(c, r, x, 335, 34, 70);
    }
    dots(c, r, 18, "#5a5050", 9, [40, 380, 980, 500]);
  },
  ACHIEVEMENT(c, r) {
    wall(c, r, "#3a2a4a");
    rays(c, r, 512, 230, 24, "#4e3a64");
    fill(c, rect(420, 400, 604, 470), "#8a6a4a", r);  // the pedestal
    fill(c, rect(380, 466, 644, 520), "#6a4a2a", r);
    for (const x of [380, 644]) fill(c, circle(x, 170, 46), "#ffd23f", r, { holes: [circle(x, 170, 26)] });  // the handles
    fill(c, rect(470, 360, 554, 404), "#ffd23f", r);  // the base, the stem, the bowl
    fill(c, rect(496, 290, 528, 362), "#ffd23f", r);
    fill(c, curve([[400, 110], [420, 260], [512, 300], [604, 260], [624, 110]], 12), "#ffd23f", r);
    soft(c, curve([[440, 130], [452, 220], [490, 262]], 8).concat([[470, 130]]), "#fff2a8", r);
    const colours = ["#ff4a3a", "#4f86e8", "#5bd24a", "#ff9a2a", "#e07ad8", "#3ad8c8"];
    for (let i = 0; i < 40; i++) {
      const x = 150 + r() * 720, y = 20 + r() * 330;
      if (Math.abs(x - 512) < 170 && y > 80) continue;
      fill(c, rotate(rect(x - 10, y - 5, x + 10, y + 5), r() * 3, x, y), colours[i % colours.length], r, { line: 6 });
    }
  },
  RANK(c, r) {
    wall(c, r, "#5a3a1a");
    rays(c, r, 512, 250, 28, "#7a5226");
    fill(c, [[-20, H + 20], ...curve([[-20, 420], [300, 380], [700, 400], [W + 20, 370]], 12), [W + 20, H + 20]], "#4a7a2a", r);
    fill(c, rect(400, 430, 624, 520), "#8a5a2e", r);  // the podium
    fill(c, rect(250, 465, 400, 520), "#7a4e28", r);
    fill(c, rect(624, 475, 774, 520), "#7a4e28", r);
    for (let i = 0; i < 10; i++) sparkle(c, r, 180 + r() * 660, 40 + r() * 120, 10 + r() * 10, "#ffd23f");
  },
  BOUNTY(c, r) {
    wall(c, r, "#6b4a2a");
    for (let y = 60; y < H; y += 90) line(c, [[-20, y], [W + 20, y + 6]], 6, "#4a3018", r);  // planks
    fill(c, rect(240, 60, 784, 460), "#8a5a30", r);  // the board
    for (const [x, y, a] of [[360, 250, -0.06], [520, 230, 0.04], [670, 260, 0.08]]) {
      fill(c, rotate(rect(x - 70, y - 120, x + 70, y + 120), a, x, y), "#f0e0b0", r);  // a wanted poster
      const at = (dx, dy) => rotate([[x + dx, y + dy]], a, x, y)[0];
      line(c, [at(-44, -90), at(44, -90)], 10, "#8a2a1a", r);
      const [fx, fy] = at(0, -20);
      fill(c, circle(fx, fy, 40), "#5bd24a", r, { line: 8 });  // a scribbled face
      for (const dx of [-14, 14]) { const [ex, ey] = at(dx, -28); dab(c, ex, ey, 6, OUTLINE, 0.9); }
      line(c, [at(-16, -2), at(16, -2)], 6, OUTLINE, r);
      for (const dy of [50, 74]) line(c, [at(-44, dy), at(44, dy)], 6, "#8a7050", r);
      const [nx, ny] = at(0, -112);
      dab(c, nx, ny, 9, hex("#9aa0a8"), 0.95);  // its nail
    }
    line(c, [[540, 120], [600, 60]], 14, "#c0c8d0", r);  // a knife stuck in the board
    line(c, [[600, 60], [624, 36]], 20, "#6a4020", r);
  },
  CREATURE(c, r) {
    ["#232344", "#352c4c", "#4a3450", "#5e3c4c"].forEach((col, i) => soft(c, rect(-20, i * 100 - 10, W + 20, (i + 1) * 100 + 10), col, r));
    fill(c, circle(820, 90, 40), "#fff2a8", r);
    dots(c, r, 30, "#fff2a8", 3, [0, 0, W, 200]);
    fill(c, [[-20, H + 20], ...curve([[-20, 330], [260, 280], [520, 320], [780, 270], [W + 20, 320]], 12), [W + 20, H + 20]], "#2a2a3a", r);
    floor(c, r, 400, "#2f3a26");
    for (const [x, h] of [[90, 300], [190, 220], [860, 260], [950, 320]]) {
      line(c, [[x, 420], [x, 420 - h * 0.4]], 18, "#3a2414", r);
      fill(c, [[x - 70, 420 - h * 0.3], [x, 420 - h], [x + 70, 420 - h * 0.3]], "#1f3a2a", r);
    }
    for (let i = 0; i < 8; i++) {
      const x = 260 + i * 70 + r() * 20;
      line(c, curve([[x, 470], [x - 10, 440], [x + 4, 415]], 6), 7, "#4a6a3a", r);
    }
  },
};

// The dungeons' scenes (tools/overview-dungeons.js), drawn with the pieces here.
const { DUNGEONS } = require("./overview-dungeons")({ W, H, fill, soft, line, curve, rect, wall, floor, dots, sparkle, gear,
  flame, arch, rays, circle, ellipse, star, rotate, hex, dab, OUTLINE });

// The sets: their scenes, folder and the part the game shows (as shares of the width and height, for the preview).
const SETS = [
  { name: "Professions", scenes: PROFESSIONS, seed: 9001, shown: [0, 0.173, 1, 0.827] },
  { name: "Feed", scenes: FEED, seed: 4242, shown: [0.138, 0, 0.862, 1] },
  { name: "Dungeons", scenes: DUNGEONS, seed: 7331, shown: [0.138, 0, 0.862, 1] },
];
// Also a library: the dungeon scenes for the minting backdrops (tools/make-unlock-art.js).
module.exports = { W, H, DUNGEONS, toRgba: crayon.toRgba, canvas, rng };
if (require.main === module) {
const PW = 512, PH = 256;
fs.mkdirSync(PREVIEW, { recursive: true });
for (const set of SETS) {
  const all = Object.keys(set.scenes), keys = all.filter((k) => k.includes(filter)), shown = [];
  if (keys.length === 0) continue;
  keys.forEach((key, n) => {
    const c = canvas();
    set.scenes[key](c, rng(set.seed + all.indexOf(key) * 7919));
    const full = crayon.toRgba(c);
    const band = { width: W, height: H, rgba: Buffer.from(full.subarray(0, W * H * 4)) };
    const small = Buffer.from(resample(band, 0, 0, W, H, PW, PH));
    writeBlp(path.join(MEDIA, set.name, key + ".blp"), PW, PH, small);
    shown.push(small);
    process.stdout.write(`\r${set.name} ${n + 1}/${keys.length} ${key}`.padEnd(50));
  });
  console.log();
  // The preview: each one with the part the game shows outlined.
  const cols = 3, rows = Math.ceil(shown.length / cols), sheet = Buffer.alloc(PW * cols * PH * rows * 4);
  const [x0, y0, x1, y1] = set.shown.map((v, i) => Math.min((i % 2 ? PH : PW) - 1, Math.round(v * (i % 2 ? PH : PW))));
  shown.forEach((pic, k) => {
    const ox = (k % cols) * PW, oy = Math.floor(k / cols) * PH;
    for (let y = 0; y < PH; y++) {
      pic.copy(sheet, ((oy + y) * PW * cols + ox) * 4, y * PW * 4, (y + 1) * PW * 4);
      for (let x = 0; x < PW; x++) {
        const edge = ((y === y0 || y === y1) && x >= x0 && x <= x1) || ((x === x0 || x === x1) && y >= y0 && y <= y1);
        if (edge) sheet.set([255, 255, 255, 255], ((oy + y) * PW * cols + ox + x) * 4);
      }
    }
  });
  writePng(path.join(PREVIEW, set.name + ".png"), PW * cols, PH * rows, sheet);
  console.log(`Wrote ${keys.length} ${set.name} scenes to ${path.join(MEDIA, set.name)}`);
}
}
