// Hand-drawn crayon backgrounds, one for each painted background in the minting art, in the fridge-drawing style
// (tools/make-crayon-mints.js): big flat crayon shapes with bold outlines, drawn the way a kid (or an ogre) would see
// the same place. The ogre stands in the middle, so the fun goes round the edges and up top.
// Writes %USERPROFILE%\killtracker-art-extra\CrayonHand\Background\<rarity>\<name>.png and backgrounds.png (each one
// with a crayon ogre on it).
// Usage: node tools/make-crayon-backgrounds.js [filter]   No dependencies.

const fs = require("fs");
const os = require("os");
const path = require("path");
const crayon = require("./make-role-icons");
const { decodePng, resample } = require("./convert-art");

const S = 1254;
crayon.setSize(S);
const { canvas, dab, stroke, crayonShape, circle, ellipse, star, quad, rotate, hex, OUTLINE, rng, writePng } = crayon;
const OUT = path.join(os.homedir(), "killtracker-art-extra", "CrayonHand");
const filter = process.argv[2] || "";

const LINE = 18, HATCH = 26;
const fill = (c, poly, col, r, o = {}) => crayonShape(c, poly, hex(col), r, { fit: true, line: LINE, hatch: HATCH, ...o });
const soft = (c, poly, col, r, o = {}) => fill(c, poly, col, r, { outline: null, ...o });
const line = (c, pts, w, col, r) => stroke(c, pts, w, typeof col === "string" ? hex(col) : col, 0.95, r);
const curve = (pts, n = 16) => pts.slice(1).flatMap((p, i) => quad(pts[i], [(pts[i][0] + p[0]) / 2, (pts[i][1] + p[1]) / 2], p, n).slice(i ? 1 : 0));
const rect = (x0, y0, x1, y1) => [[x0, y0], [x1, y0], [x1, y1], [x0, y1]];
const ALL = rect(0, 0, S, S);

// --- Pieces ---
const sky = (c, r, col) => soft(c, ALL, col, r, { hatch: 34 });
// A sky that changes colour in bands from the top (sunsets), scribbled.
function skyBands(c, r, cols) {
  const h = S / cols.length;
  cols.forEach((col, i) => soft(c, rect(0, i * h - 20, S, (i + 1) * h + 20), col, r, { hatch: 34 }));
}
// Rolling ground from height y down, wobbling up and down.
function hills(c, r, y, col, amp = 60, waves = 2, phase = 0) {
  const pts = [];
  for (let i = 0; i <= 24; i++) { const x = (i / 24) * S; pts.push([x, y - Math.sin((i / 24) * Math.PI * waves + phase) * amp]); }
  fill(c, [[0, S], ...pts, [S, S]], col, r, { hatch: 30 });
}
function sun(c, r, x, y, rad, face = true) {
  for (let i = 0; i < 12; i++) {
    const a = (i / 12) * 2 * Math.PI;
    line(c, [[x + Math.cos(a) * (rad + 20), y + Math.sin(a) * (rad + 20)], [x + Math.cos(a) * (rad + 70), y + Math.sin(a) * (rad + 70)]], 22, "#ff9a2a", r);
  }
  fill(c, circle(x, y, rad), "#ffd23f", r);
  if (face) {
    for (const dx of [-rad * 0.35, rad * 0.35]) line(c, curve([[x + dx - 16, y - 8], [x + dx, y + 6], [x + dx + 16, y - 8]], 6), 10, OUTLINE, r);
    line(c, curve([[x - 28, y + 30], [x, y + 46], [x + 28, y + 30]], 8), 10, OUTLINE, r);
  }
}
function moon(c, r, x, y, rad) {
  const arc = (cx, cy, rr, a0, a1) => Array.from({ length: 17 }, (_, k) => { const a = a0 + ((a1 - a0) * k) / 16; return [cx + Math.cos(a) * rr, cy + Math.sin(a) * rr]; });
  fill(c, [...arc(x, y, rad, -1.9, 1.9), ...arc(x - rad * 0.45, y - rad * 0.1, rad * 0.8, 1.6, -1.6)], "#fff2a8", r);
  dab(c, x + rad * 0.45, y - rad * 0.1, 8, OUTLINE, 0.9);  // a sleepy eye
}
function cloud(c, r, x, y, w, col = "#ffffff") {
  fill(c, [...curve([[x - w, y + 20], [x - w * 0.9, y - 30], [x - w * 0.4, y - 50], [x, y - 70], [x + w * 0.5, y - 45], [x + w, y - 10], [x + w * 0.9, y + 30]], 10),
    ...curve([[x + w * 0.9, y + 30], [x, y + 46], [x - w, y + 20]], 10).slice(1)], col, r, { hatch: 20 });
}
function stars(c, r, n, y1 = 600, col = "#fff6c0") {
  for (let i = 0; i < n; i++) { const x = 40 + r() * (S - 80), y = 30 + r() * y1; fill(c, star(x, y, 24 + r() * 14, 10), col, r, { line: 10, hatch: 10 }); }
}
// A lollipop tree: a trunk and a big round top.
function tree(c, r, x, ground, h, top = "#5bb43a", w = 1) {
  fill(c, rect(x - 26 * w, ground - h, x + 26 * w, ground + 10), "#8a5a2e", r);
  fill(c, circle(x, ground - h - 60 * w, 110 * w), top, r);
  for (let i = 0; i < 4; i++) dab(c, x - 50 * w + r() * 100 * w, ground - h - 110 * w + r() * 100 * w, 10, hex("#e8463a"), 0.9);  // apples
}
function palm(c, r, x, ground, h, lean = 1) {
  const trunk = curve([[x, ground], [x + 40 * lean, ground - h / 2], [x + 90 * lean, ground - h]]);
  line(c, trunk, 44, "#a8743e", r);
  const hx = x + 90 * lean, hy = ground - h;
  for (const a of [-2.8, -2.1, -1.5, -0.9, -0.25, 0.4]) {
    const tip = [hx + Math.cos(a) * 230, hy + Math.sin(a) * 150 + 70];
    const mid = [(hx + tip[0]) / 2, (hy + tip[1]) / 2], nx = -(tip[1] - hy), ny = tip[0] - hx, d = Math.hypot(nx, ny) || 1;
    const bulge = 45;
    fill(c, [[hx, hy], ...curve([[hx, hy], [mid[0] + (nx / d) * bulge, mid[1] + (ny / d) * bulge - 30], tip], 8).slice(1),
      ...curve([tip, [mid[0] - (nx / d) * bulge * 0.4, mid[1] - (ny / d) * bulge * 0.4], [hx, hy]], 8).slice(1)], "#3f9a3a", r, { hatch: 16, line: 14 });
  }
  for (const dx of [-24, 18]) fill(c, circle(hx + dx, hy + 30, 24), "#8a5a2e", r, { line: 12, hatch: 10 });  // coconuts
}
function flower(c, r, x, y, col) {
  line(c, [[x, y], [x, y + 90]], 14, "#3f8a2e", r);
  for (let i = 0; i < 5; i++) { const a = (i / 5) * 2 * Math.PI; fill(c, circle(x + Math.cos(a) * 26, y + Math.sin(a) * 26, 22), col, r, { line: 10, hatch: 12 }); }
  fill(c, circle(x, y, 18), "#ffd23f", r, { line: 10, hatch: 12 });
}
function waves(c, r, y, col = "#ffffff", n = 7) {
  for (let i = 0; i < n; i++) {
    const x = 60 + r() * (S - 120), yy = y + r() * 160;
    line(c, curve([[x, yy], [x + 30, yy - 18], [x + 60, yy], [x + 90, yy - 18], [x + 120, yy]], 6), 10, col, r);
  }
}
function flag(c, r, x, ground, col = "#e8463a") {
  line(c, [[x, ground], [x, ground - 220]], 12, "#3a3236", r);
  fill(c, [[x, ground - 220], [x + 100, ground - 190], [x, ground - 160]], col, r, { hatch: 14 });
}
function rock(c, r, x, y, w, col = "#9aa0a8") { fill(c, [...curve([[x - w, y], [x - w * 0.8, y - w * 0.7], [x, y - w * 0.9], [x + w * 0.9, y - w * 0.6], [x + w, y]], 8)], col, r); }
function zzz(c, r, x, y, s = 40, col = "#4f86e8") {
  [0, 1, 2].forEach((k) => { const ss = s * (1 - k * 0.2), xx = x + k * s * 0.9, yy = y - k * s * 0.8;
    line(c, [[xx, yy], [xx + ss, yy], [xx, yy + ss], [xx + ss, yy + ss]], 12, col, r); });
}

// --- The backgrounds ---
const BACKGROUNDS = {
  // Uncommon
  "Uncommon/golf-course-at-dawn": (c, r) => {
    skyBands(c, r, ["#ffb07a", "#ffc890", "#ffe0a8"]);
    sun(c, r, 220, 340, 110);
    cloud(c, r, 900, 200, 160);
    hills(c, r, 560, "#7fd65a", 70, 1.5);
    hills(c, r, 760, "#5bb43a", 40, 2, 1);
    flag(c, r, 1080, 700);
    fill(c, ellipse(1080, 712, 60, 18), "#3a3236", r, { line: 10 });
    tree(c, r, 120, 720, 160);
    fill(c, circle(260, 900, 14), "#ffffff", r, { line: 8, hatch: 8 });  // a golf ball
  },
  "Uncommon/moonlit-fairway": (c, r) => {
    sky(c, r, "#26347a");
    stars(c, r, 26, 450);
    moon(c, r, 1040, 220, 110);
    hills(c, r, 600, "#2f6e3a", 60, 1.5, 2);
    hills(c, r, 800, "#3f8a3a", 40, 2);
    flag(c, r, 200, 760, "#ffd23f");
    tree(c, r, 1130, 800, 180, "#2f6e3a");
    for (let i = 0; i < 9; i++) dab(c, 100 + r() * 1050, 650 + r() * 300, 9, hex("#e8ff7a"), 0.9);  // fireflies
  },
  "Uncommon/hammock-between-two-trees": (c, r) => {
    skyBands(c, r, ["#ffb0a0", "#ffd090", "#fff0b0"]);
    sun(c, r, 627, 330, 100, false);
    hills(c, r, 650, "#7fd65a", 50, 1);
    tree(c, r, 140, 900, 420, "#3f9a3a", 1.4);
    tree(c, r, 1110, 900, 420, "#3f9a3a", 1.4);
    // The hammock between them, empty (the ogre's in front), with a little pillow.
    fill(c, [...curve([[170, 560], [627, 820], [1080, 560]], 20), ...curve([[1080, 600], [627, 880], [170, 600]], 20)], "#f2e2c0", r);
    for (const [x, y] of [[170, 560], [1080, 560]]) line(c, [[x, y], [x + (x < 600 ? -10 : 10), y - 120]], 12, "#8a5a2e", r);
    zzz(c, r, 980, 380, 50);
    flower(c, r, 300, 1020, "#ff7fbf"); flower(c, r, 960, 1060, "#b07ae8");
  },
  "Uncommon/clubhouse-lounge": (c, r) => {
    soft(c, ALL, "#c46a3a", r, { hatch: 34 });  // the walls
    for (let x = 80; x < S; x += 170) line(c, [[x, 0], [x, 700]], 10, "#a85530", r);  // wallpaper stripes
    fill(c, rect(0, 700, S, S), "#8a4a2a", r);  // the floor
    fill(c, rect(160, 900, 1090, 1180), "#c8302a", r);  // the rug
    for (const x of [140, 1000]) {  // windows with a night sky
      fill(c, rect(x, 140, x + 160, 420), "#26347a", r);
      line(c, [[x + 80, 140], [x + 80, 420]], 10, OUTLINE, r); line(c, [[x, 280], [x + 160, 280]], 10, OUTLINE, r);
      fill(c, star(x + 40, 190, 14, 6), "#fff6c0", r, { line: 6, hatch: 6 });
    }
    // A fireplace and a club-crest painting.
    fill(c, rect(470, 120, 790, 330), "#ffd84a", r);
    fill(c, rect(500, 150, 760, 300), "#4f86e8", r);
    fill(c, circle(630, 225, 50), "#ffd84a", r, { line: 10 });
    fill(c, rect(960, 520, 1200, 720), "#7a7a80", r);
    fill(c, rect(1000, 580, 1160, 720), "#3a2a2a", r);
    fill(c, [[1030, 720], [1060, 640], [1080, 680], [1100, 620], [1130, 720]], "#ff8a2a", r, { hatch: 12 });
  },
  "Uncommon/spa-steam-room": (c, r) => {
    soft(c, ALL, "#d8a070", r, { hatch: 34 });
    for (let y = 60; y < 700; y += 110) line(c, [[0, y], [S, y]], 10, "#b07a50", r);  // wooden planks
    fill(c, rect(0, 760, S, S), "#9aa0a8", r);  // stone floor
    for (let x = 0; x < S; x += 160) line(c, [[x, 760], [x, S]], 8, "#6a7078", r);
    fill(c, ellipse(627, 960, 520, 150), "#7fe0f0", r);  // the pool
    waves(c, r, 900, "#ffffff", 6);
    for (let i = 0; i < 7; i++) {  // steam curls
      const x = 120 + r() * 1000, y = 300 + r() * 400;
      line(c, curve([[x, y + 140], [x + 30, y + 90], [x - 20, y + 40], [x + 10, y]], 8), 18, "#ffffff", r);
    }
    for (const x of [140, 1110]) { fill(c, rect(x - 30, 380, x + 30, 470), "#ffd84a", r, { line: 10 }); dab(c, x, 425, 12, hex("#ff8a2a"), 0.9); }  // lanterns
  },
  "Uncommon/swamp-hot-spring": (c, r) => {
    skyBands(c, r, ["#b07ae8", "#e88ab0", "#ffb0a0"]);
    moon(c, r, 980, 200, 70);
    hills(c, r, 560, "#4a7a3a", 50, 2);
    fill(c, ellipse(627, 960, 600, 200), "#3fb8b0", r);  // the spring
    for (let i = 0; i < 8; i++) fill(c, circle(200 + r() * 860, 880 + r() * 160, 12 + r() * 12), "#9fe8e0", r, { line: 8, hatch: 8 });  // bubbles
    for (const x of [80, 210, 1060, 1180]) {  // reeds with cattails
      line(c, [[x, 1100], [x + 10, 640]], 14, "#3f7a2e", r);
      fill(c, ellipse(x + 10, 640, 16, 46), "#8a5a2e", r, { line: 10, hatch: 10 });
    }
    for (let i = 0; i < 6; i++) dab(c, 100 + r() * 1050, 500 + r() * 300, 9, hex("#e8ff7a"), 0.9);
  },
  // Epic
  "Epic/pool-with-floaties": (c, r) => {
    sky(c, r, "#8fd0ff");
    sun(c, r, 1080, 200, 100);
    cloud(c, r, 260, 190, 150);
    fill(c, rect(0, 560, S, S), "#f0dcb0", r);  // the tiles round the pool
    fill(c, rect(70, 640, S - 70, S - 40), "#3fa8f0", r);
    waves(c, r, 700, "#ffffff", 8);
    // Floaties: a ring, a duck.
    fill(c, circle(260, 900, 110), "#ff5f8a", r, { holes: [circle(260, 900, 55)] });
    for (let k = 0; k < 4; k++) { const a = k * Math.PI / 2; dab(c, 260 + Math.cos(a) * 82, 900 + Math.sin(a) * 82, 18, hex("#ffffff"), 0.9); }
    fill(c, ellipse(1000, 960, 120, 70), "#ffd23f", r);
    fill(c, circle(1080, 870, 52), "#ffd23f", r);
    fill(c, [[1124, 868], [1170, 880], [1124, 894]], "#ff8a2a", r, { line: 10, hatch: 8 });
    dab(c, 1092, 856, 9, OUTLINE, 0.9);
    palm(c, r, 60, 640, 420, 1);
  },
  // Legendary
  "Legendary/ancient-treasure-lounge": (c, r) => {
    soft(c, ALL, "#5a3a2a", r, { hatch: 34 });  // the cave
    for (let i = 0; i < 6; i++) {  // glowing crystals on the walls
      const x = 60 + r() * 1100, y = 80 + r() * 440, col = ["#7ff0e0", "#c08aff", "#ff7fbf"][i % 3];
      fill(c, [[x, y + 70], [x - 26, y + 20], [x, y - 60], [x + 26, y + 20]], col, r, { hatch: 10 });
    }
    fill(c, rect(0, 820, S, S), "#8a6a4a", r);
    // Piles of gold coins either side, a chest, a big ruby.
    for (const [cx, w] of [[180, 220], [1080, 230]]) {
      fill(c, [...curve([[cx - w, 1000], [cx - w * 0.5, 760], [cx, 700], [cx + w * 0.5, 760], [cx + w, 1000]], 10)], "#ffcf3a", r);
      for (let k = 0; k < 9; k++) fill(c, ellipse(cx - w * 0.6 + r() * w * 1.2, 780 + r() * 200, 22, 12), "#ffe48a", r, { line: 8, hatch: 8 });
    }
    fill(c, rect(500, 980, 760, 1150), "#a8743e", r);
    fill(c, rect(500, 960, 760, 1010), "#ffcf3a", r, { line: 12 });
    fill(c, [[1100, 1080], [1140, 1040], [1180, 1080], [1140, 1140]], "#e8463a", r, { line: 12, hatch: 10 });
    for (const x of [340, 920]) { line(c, [[x, 120], [x, 260]], 8, "#3a3236", r); fill(c, rect(x - 30, 260, x + 30, 330), "#ffd84a", r, { line: 10 }); }  // lanterns
  },
  "Legendary/dragon-over-the-fairway": (c, r) => {
    sky(c, r, "#8fd0ff");
    cloud(c, r, 200, 300, 150); cloud(c, r, 1020, 420, 120);
    hills(c, r, 640, "#7fd65a", 60, 1.5, 1);
    // The dragon flying overhead: a fat body, a bat wing with ribs, spikes, a long tail, legs, a puff of fire.
    const body = [...curve([[340, 260], [460, 190], [620, 200], [780, 170], [900, 150]], 10), ...curve([[900, 150], [880, 250], [700, 300], [500, 300], [340, 260]], 10).slice(1)];
    line(c, curve([[350, 250], [230, 300], [140, 250], [90, 180]], 10), 34, "#e8463a", r);  // the tail
    fill(c, [[70, 160], [120, 160], [95, 205]], "#e8463a", r, { line: 12, hatch: 10 });  // its tip
    fill(c, body, "#e8463a", r);
    fill(c, [[520, 220], [560, 20], [650, 90], [720, 0], [790, 110], [880, 60], [780, 220]], "#c8302a", r);  // the wing
    for (const [x, y] of [[560, 20], [720, 0], [880, 60]]) line(c, [[650, 210], [x, y]], 10, OUTLINE, r);
    for (let k = 0; k < 5; k++) fill(c, [[420 + k * 80, 200 - k * 6], [450 + k * 80, 150 - k * 6], [480 + k * 80, 196 - k * 6]], "#ffd23f", r, { line: 10, hatch: 8 });
    for (const x of [520, 700]) line(c, [[x, 290], [x - 10, 360]], 22, "#e8463a", r);  // legs
    fill(c, ellipse(970, 140, 82, 56), "#e8463a", r);  // the head
    fill(c, [[930, 92], [950, 40], [975, 90]], "#ffd23f", r, { line: 10, hatch: 8 });  // a horn
    dab(c, 985, 125, 12, hex("#ffffff"), 0.95); dab(c, 990, 128, 7, OUTLINE, 0.95);
    fill(c, [[1050, 150], [1170, 100], [1140, 150], [1220, 175], [1140, 200], [1060, 170]], "#ff9a2a", r, { hatch: 14 });
    fill(c, [[1080, 152], [1150, 135], [1130, 160]], "#ffd23f", r, { line: 8, hatch: 8 });
    flag(c, r, 1060, 760);
    tree(c, r, 140, 800, 170);
  },
  "Legendary/floating-sky-spa": (c, r) => {
    skyBands(c, r, ["#ffb0d0", "#ffd0b0", "#b0e0ff"]);
    for (const [x, y, w] of [[220, 300, 150], [1030, 260, 170], [620, 120, 120], [180, 760, 200], [1080, 800, 180]]) cloud(c, r, x, y, w);
    // Floating islands with little waterfalls.
    for (const [x, y, w] of [[260, 520, 170], [1000, 560, 190]]) {
      fill(c, [[x - w, y], [x + w, y], [x + w * 0.4, y + 120], [x, y + 170], [x - w * 0.4, y + 120]], "#a8743e", r);
      fill(c, rect(x - w, y - 30, x + w, y + 10), "#7fd65a", r, { line: 12 });
      line(c, [[x + w * 0.6, y + 10], [x + w * 0.6, y + 240]], 22, "#8fe0ff", r);
    }
    fill(c, ellipse(627, 1080, 420, 130), "#7fe0f0", r);  // the spa pool on a cloud
    waves(c, r, 1030, "#ffffff", 4);
    stars(c, r, 6, 200, "#ffffff");
  },
  "Legendary/ghost-ship-cove": (c, r) => {
    sky(c, r, "#1e2a5e");
    stars(c, r, 20, 400);
    moon(c, r, 1060, 200, 100);
    fill(c, rect(0, 640, S, S), "#2a6a8a", r);  // the sea
    waves(c, r, 680, "#7fe0f0", 8);
    // The ghost ship: a green glowing hull, masts and tattered sails, a skull flag.
    fill(c, [[700, 560], [1180, 560], [1120, 660], [760, 660]], "#3a8a6a", r);
    for (const x of [820, 960, 1080]) {
      line(c, [[x, 560], [x, 240]], 14, "#3a3236", r);
      fill(c, [[x - 70, 280], [x + 70, 290], [x + 60, 470], [x - 60, 460]], "#c8f0d8", r, { hatch: 16 });
    }
    fill(c, rect(940, 200, 1010, 245), "#3a3236", r, { line: 10 });
    dab(c, 975, 222, 9, hex("#ffffff"), 0.9);
    palm(c, r, 80, 900, 460, 1);
    fill(c, [...curve([[0, 1000], [300, 900], [520, 1000]], 10), [520, S], [0, S]], "#e8d090", r);  // a bit of beach
  },
};

const T = 300, shown = [];
const want = Object.keys(BACKGROUNDS).filter((k) => k.includes(filter));
const crayonOgre = ["Skin/Uncommon/moss.png", "Outfit/Uncommon/striped-pajamas.png", "Expression/Uncommon/moss/smug-smile.png",
  "Eyes/Uncommon/moss/heavy-bags.png"].map((f) => Buffer.from(resample(decodePng(path.join(OUT, f)), 0, 0, S, S, T, T)));
function over(dst, src) {
  for (let i = 0; i < dst.length; i += 4) {
    const a = src[i + 3] / 255, b = dst[i + 3] / 255, o = a + b * (1 - a);
    if (!o) continue;
    for (let k = 0; k < 3; k++) dst[i + k] = Math.round((src[i + k] * a + dst[i + k] * b * (1 - a)) / o);
    dst[i + 3] = Math.round(o * 255);
  }
}
want.forEach((key, n) => {
  const c = canvas();
  BACKGROUNDS[key](c, rng(5150 + n * 7919));
  const rgba = crayon.toRgba(c), file = path.join(OUT, "Background", ...key.split("/")) + ".png";
  fs.mkdirSync(path.dirname(file), { recursive: true });
  writePng(file, S, S, rgba);
  const pic = Buffer.from(resample({ width: S, height: S, rgba }, 0, 0, S, S, T, T));
  for (const layer of crayonOgre) over(pic, layer);
  shown.push(pic);
  process.stdout.write(`\r${n + 1}/${want.length} ${key}`.padEnd(60));
});
console.log();
const cols = Math.min(4, shown.length), rows = Math.ceil(shown.length / cols), sheet = Buffer.alloc(T * cols * T * rows * 4);
shown.forEach((pic, k) => {
  const ox = (k % cols) * T, oy = Math.floor(k / cols) * T;
  for (let y = 0; y < T; y++) pic.copy(sheet, ((oy + y) * T * cols + ox) * 4, y * T * 4, (y + 1) * T * 4);
});
try { writePng(path.join(OUT, "backgrounds.png"), T * cols, T * rows, sheet); } catch (e) { console.log("(backgrounds.png is open elsewhere - not updated)"); }
console.log(`Wrote ${want.length} crayon backgrounds to ${path.join(OUT, "Background")}`);
