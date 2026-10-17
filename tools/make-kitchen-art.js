// The minting pot's crayon art (MintPot.lua): the dungeons' ingredients (their tokens, Unlocks.lua: one each, keyed by
// the dungeon keys in Achievements.lua, upper case) and the kitchen: the cauldron, the brew (white, tinted in game), the
// fire, the spoon, a bubble and a puff of smoke (white, tinted), the shelf.
// Writes Media/Icons/Ingredients/<KEY>.blp and Media/Icons/Kitchen/<name>.blp (128x128; 256x256 for the cauldron), and
// a preview sheet, %USERPROFILE%\killtracker-art-extra\Kitchen\preview.png.
// Usage: node tools/make-kitchen-art.js   No dependencies.

const fs = require("fs");
const os = require("os");
const path = require("path");
const crayon = require("./make-role-icons");
const { resize, writeBlp, bleedEdges } = require("./convert-art");

crayon.setSize(256);
const { canvas, dab, stroke, crayonShape, circle, ellipse, star, quad, rotate, hex, OUTLINE, rng, writePng } = crayon;
const MEDIA = path.join(__dirname, "..", "Media", "Icons");
const PREVIEW = path.join(os.homedir(), "killtracker-art-extra", "Kitchen");
const fill = (c, poly, col, r, o = {}) => crayonShape(c, poly, typeof col === "string" ? hex(col) : col, r, { line: 12, hatch: 7, ...o });
const soft = (c, poly, col, r, o = {}) => fill(c, poly, col, r, { outline: null, ...o });
const line = (c, pts, w, col, r) => stroke(c, pts, w, typeof col === "string" ? hex(col) : col, 0.95, r);
const rect = (x0, y0, x1, y1) => [[x0, y0], [x1, y0], [x1, y1], [x0, y1]];
const shine = (c, r, x, y, s = 14) => soft(c, ellipse(x, y, s * 0.6, s), "#ffffff", r);
function vial(c, r, liquid, glass = "#d8f0f0") {
  fill(c, rect(110, 40, 146, 90), glass, r);
  fill(c, rect(104, 28, 152, 46), "#8a5a30", r, { line: 10 });  // the cork
  fill(c, circle(128, 160, 70), glass, r);
  soft(c, circle(128, 160, 70).filter(([, y]) => y > 140), liquid, r);
  shine(c, r, 98, 140);
}
function crystal(c, r, col, glow) {
  if (glow) soft(c, circle(128, 128, 110), glow, r, { hatch: 14 });
  fill(c, [[128, 20], [176, 90], [158, 230], [98, 230], [80, 90]], col, r);
  line(c, [[128, 30], [128, 220]], 6, "#ffffff", r);
}
function orb(c, r, col, glow) {
  soft(c, circle(128, 128, 116), glow, r, { hatch: 14 });
  fill(c, circle(128, 128, 82), col, r);
  shine(c, r, 100, 98, 20);
}
function ore(c, r, rock, vein) {
  fill(c, [[40, 150], [70, 70], [140, 40], [210, 80], [226, 170], [160, 220], [80, 214]], rock, r);
  for (const p of [[[80, 110], [130, 140], [180, 100]], [[100, 180], [160, 170]]]) line(c, p, 12, vein, r);
}

// The ingredients: { name (plural, as you'd have several), draw }.
const INGREDIENTS = {
  RFC: ["Searing Embers", (c, r) => { soft(c, circle(128, 140, 110), "#ff7a1a", r, { hatch: 14 }); fill(c, [[90, 210], [80, 140], [128, 50], [176, 140], [166, 210]], "#ff4a1a", r); soft(c, [[110, 200], [104, 150], [128, 100], [152, 150], [146, 200]], "#ffd23f", r); }],
  WC: ["Fang Venom", (c, r) => { fill(c, [[90, 40], [166, 40], [128, 200]], "#f4f0e0", r); fill(c, [[118, 190], [138, 190], [140, 240], [116, 240]].map(([x, y]) => [x, y]), "#7aff4a", r, { line: 8 }); fill(c, circle(128, 236, 18), "#7aff4a", r, { line: 8 }); }],
  DM: ["Defias Doubloons", (c, r) => { fill(c, circle(128, 128, 104), "#ffd23f", r); fill(c, circle(128, 128, 76), "#ffe680", r, { line: 8 }); fill(c, [[96, 110], [160, 110], [150, 150], [106, 150]], "#c02a2a", r, { line: 8 }); dab(c, 112, 100, 8, OUTLINE, 0.9); dab(c, 144, 100, 8, OUTLINE, 0.9); }],
  SFK: ["Worgen Fur", (c, r) => { for (let i = 0; i < 7; i++) { const x = 60 + i * 22; fill(c, quad([x, 220], [x - 30 + (i % 2) * 40, 130], [x + 10, 40 + (i % 3) * 20], 10).concat([[x + 26, 220]]), i % 2 ? "#7a7480" : "#9a94a0", r, { line: 8 }); } }],
  BFD: ["Twilight Pearls", (c, r) => { fill(c, [...quad([30, 160], [128, 250], [226, 160], 12), [128, 190]], "#d8c8b0", r); fill(c, circle(128, 140, 50), "#4a3a8a", r); shine(c, r, 112, 124); }],
  STOCKS: ["Prison Keys", (c, r) => { fill(c, circle(80, 90, 50), "#9aa0a8", r, { holes: [circle(80, 90, 24)] }); fill(c, [[110, 112], [220, 200], [204, 218], [96, 130]], "#9aa0a8", r); fill(c, rect(178, 196, 196, 236), "#9aa0a8", r, { line: 8 }); fill(c, rect(204, 208, 220, 240), "#9aa0a8", r, { line: 8 }); }],
  GNOMER: ["Irradiated Cogs", (c, r) => { soft(c, circle(128, 128, 118), "#9aff5a", r, { hatch: 14 }); const pts = []; for (let i = 0; i < 40; i++) { const a = (i / 40) * 2 * Math.PI, rr = i % 4 < 2 ? 100 : 78; pts.push([128 + Math.cos(a) * rr, 128 + Math.sin(a) * rr]); } fill(c, pts, "#7ad84a", r, { holes: [circle(128, 128, 30)] }); }],
  RFK: ["Bramble Thorns", (c, r) => { const vine = quad([30, 210], [128, 60], [226, 160], 14); line(c, vine, 26, "#5a3a20", r); for (let k = 2; k < vine.length; k += 3) { const [x, y] = vine[k]; fill(c, [[x - 10, y], [x, y - 44], [x + 10, y]], "#c8b890", r, { line: 6 }); } }],
  SMGY: ["Grave Dirt", (c, r) => { fill(c, [...quad([20, 220], [128, 60], [236, 220], 14)], "#5a4030", r); fill(c, [[90, 150], [170, 130]].flatMap(([x, y]) => []).concat(rect(80, 150, 180, 166)), "#f0ece0", r, { line: 8 }); for (const [x, y] of [[80, 158], [180, 158]]) fill(c, circle(x, y, 14), "#f0ece0", r, { line: 6 }); }],
  SMLIB: ["Scarlet Scrolls", (c, r) => { fill(c, rect(50, 70, 206, 190), "#f0e0b0", r); for (const y of [70, 190]) fill(c, ellipse(128, y, 90, 20), "#e0c890", r, { line: 8 }); for (const y of [100, 125, 150]) line(c, [[76, y], [180, y]], 6, "#8a7050", r); fill(c, circle(128, 190, 24), "#c02a2a", r, { line: 8 }); }],
  SMARM: ["Scarlet Ingots", (c, r) => { fill(c, [[40, 170], [80, 110], [216, 110], [176, 170]], "#c02a2a", r); fill(c, [[40, 170], [176, 170], [176, 200], [40, 200]], "#8a1a1a", r); fill(c, [[176, 170], [216, 110], [216, 140], [176, 200]], "#a02020", r); shine(c, r, 120, 136, 10); }],
  SMCATH: ["Holy Candles", (c, r) => { soft(c, circle(128, 70, 60), "#fff2a8", r); fill(c, rect(100, 100, 156, 230), "#f8f4e8", r); fill(c, [[118, 100], [128, 40], [138, 100]], "#ffd23f", r, { line: 8 }); fill(c, [[100, 120], [110, 160], [100, 170]], "#f8f4e8", r, { line: 6 }); }],
  RFD: ["Frost Bones", (c, r) => { line(c, [[60, 190], [196, 66]], 30, "#e8f4ff", r); for (const [x, y] of [[54, 196], [70, 210], [190, 60], [206, 74]]) fill(c, circle(x, y, 22), "#e8f4ff", r, { line: 8 }); for (let i = 0; i < 5; i++) fill(c, [[90 + i * 22, 150 - i * 20], [96 + i * 22, 190 - i * 20], [102 + i * 22, 150 - i * 20]], "#9fe8ff", r, { line: 6 }); }],
  ULDA: ["Titan Shards", (c, r) => { fill(c, [[60, 200], [80, 80], [150, 40], [200, 110], [180, 220]], "#8a8078", r); line(c, [[90, 90], [130, 140], [110, 190], [160, 200]], 12, "#5ac8ff", r); soft(c, circle(130, 140, 40), "#5ac8ff", r); }],
  ZF: ["Sandfury Sand", (c, r) => { fill(c, [...quad([50, 220], [40, 110], [100, 80], 10), [128, 50], [156, 80], ...quad([156, 80], [216, 110], [206, 220], 10).slice(1)], "#c8945a", r); line(c, [[96, 84], [160, 84]], 12, "#8a5a30", r); for (let i = 0; i < 10; i++) dab(c, 70 + (i * 37) % 120, 140 + (i * 23) % 70, 5, hex("#f0d8a0"), 0.9); }],
  MARA: ["Purple Lotus", (c, r) => { for (let i = 0; i < 6; i++) { const a = (i / 6) * 2 * Math.PI - Math.PI / 2; fill(c, rotate(ellipse(128, 70, 30, 60), a, 128, 128), "#b07aff", r, { line: 8 }); } fill(c, circle(128, 128, 30), "#ffd23f", r, { line: 8 }); }],
  THANES: ["Thane Runes", (c, r) => { fill(c, [[60, 220], [50, 70], [128, 30], [206, 70], [196, 220]], "#8a8078", r); line(c, [[100, 80], [100, 180], [156, 130], [156, 200]], 12, "#c8f0ff", r); soft(c, circle(128, 140, 50), "#9fe8ff", r); }],
  RUINS: ["Plague Vials", (c, r) => vial(c, r, "#7ad86a")],
  EXCAV: ["Relic Fragments", (c, r) => { fill(c, [[40, 120], [120, 40], [220, 90], [200, 200], [80, 220]], "#c8945a", r); line(c, quad([70, 130], [130, 100], [190, 140], 10), 10, "#5ac8ff", r); for (const [x, y] of [[100, 170], [150, 170]]) dab(c, x, y, 10, hex("#5ac8ff"), 0.9); }],
  ST: ["Dream Leaves", (c, r) => { fill(c, [...quad([128, 230], [20, 130], [128, 20], 14), ...quad([128, 20], [236, 130], [128, 230], 14).slice(1)], "#3a9a5a", r); line(c, [[128, 220], [128, 40]], 8, "#a8e8a0", r); for (const y of [80, 130, 180]) { line(c, [[128, y], [90, y - 30]], 6, "#a8e8a0", r); line(c, [[128, y], [166, y - 30]], 6, "#a8e8a0", r); } }],
  BRD: ["Dark Iron Ore", (c, r) => ore(c, r, "#3a3236", "#ff7a1a")],
  LBRS: ["Blackrock Shards", (c, r) => { fill(c, [[128, 20], [200, 120], [160, 236], [70, 220], [56, 110]], "#2a2228", r); line(c, [[110, 60], [140, 130], [110, 200]], 10, "#c02a2a", r); }],
  UBRS: ["Dragon Eggshells", (c, r) => { fill(c, [...quad([40, 140], [128, 250], [216, 140], 14), [190, 110], [160, 140], [128, 100], [96, 140], [66, 110]], "#2a2228", r); line(c, [[80, 170], [120, 190], [160, 170]], 8, "#ff9a2a", r); }],
  DME: ["Felvine Shards", (c, r) => crystal(c, r, "#5bd24a", "#9aff5a")],
  DMW: ["Arcane Shards", (c, r) => crystal(c, r, "#7ab0ff", "#c8f0ff")],
  DMN: ["Gordok Green Grog", (c, r) => { fill(c, rect(60, 70, 180, 230), "#8a5a30", r); fill(c, circle(196, 150, 46), "#8a5a30", r, { holes: [circle(196, 150, 24)] }); fill(c, ellipse(120, 70, 66, 24), "#7aff4a", r); for (const [x, y] of [[90, 54], [130, 46], [150, 60]]) fill(c, circle(x, y, 18), "#b8ff8a", r, { line: 6 }); }],
  SCHOLO: ["Bone Dust", (c, r) => { fill(c, [...quad([20, 220], [128, 90], [236, 220], 14)], "#c8c0d8", r); for (let i = 0; i < 8; i++) dab(c, 70 + (i * 41) % 120, 170 + (i * 17) % 40, 6, hex("#9a6ad8"), 0.9); fill(c, circle(128, 120, 34), "#f0ece0", r, { line: 8 }); for (const x of [116, 140]) dab(c, x, 118, 8, OUTLINE, 0.9); }],
  STRATL: ["Stratholme Holy Water", (c, r) => vial(c, r, "#9fd8ff")],
  STRATU: ["Righteous Orbs", (c, r) => orb(c, r, "#b07aff", "#e0c8ff")],
  ONY: ["Onyxia Scales", (c, r) => { fill(c, [...quad([128, 236], [30, 140], [70, 40], 14), ...quad([70, 40], [128, 70], [186, 40], 10).slice(1), ...quad([186, 40], [226, 140], [128, 236], 14).slice(1)], "#2a2228", r); line(c, [[128, 80], [128, 220]], 8, "#6a4a5a", r); shine(c, r, 96, 100, 16); }],
  BARROW: ["Barrow Moss", (c, r) => { soft(c, circle(128, 140, 110), "#b8a8ff", r, { hatch: 14 }); for (let i = 0; i < 9; i++) fill(c, circle(70 + (i * 31) % 120, 120 + (i * 47) % 90, 30), i % 2 ? "#5a7a4a" : "#6a8a5a", r, { line: 8 }); }],
  HYJAL: ["Nordrassil Sap", (c, r) => { soft(c, circle(128, 140, 110), "#ffd23f", r, { hatch: 14 }); fill(c, [...quad([128, 30], [60, 160], [128, 230], 12), ...quad([128, 230], [196, 160], [128, 30], 12).slice(1)], "#e0a030", r); shine(c, r, 104, 140, 18); }],
  // The layers' ingredients (from kills, by creature type) and Shimmer Dust (rarer pieces).
  L_BACKGROUND: ["Elemental Mote", (c, r) => { orb(c, r, "#7ac8ff", "#c8f0ff"); line(c, quad([80, 150], [128, 70], [176, 130], 10), 10, "#ffffff", r); }],
  L_SKIN: ["Ectoplasm", (c, r) => { soft(c, circle(128, 140, 112), "#b8ffd8", r, { hatch: 14 }); fill(c, [...quad([50, 220], [60, 40], [196, 50], 14), ...quad([196, 50], [216, 140], [206, 220], 10).slice(1), [170, 196], [140, 226], [110, 196], [80, 226]], "#8affc0", r); for (const x of [104, 152]) dab(c, x, 120, 12, OUTLINE, 0.9); }],
  L_OUTFIT: ["Bolt of Cloth", (c, r) => { fill(c, rect(50, 80, 200, 190), "#d84a4a", r); for (const x of [50, 200]) fill(c, ellipse(x, 135, 22, 55), "#a02a2a", r, { line: 8 }); for (const y of [110, 160]) line(c, [[70, y], [180, y]], 6, "#ffd23f", r); fill(c, [[200, 190], [236, 230], [190, 236]], "#d84a4a", r, { line: 8 }); }],
  L_EXPRESSION: ["Imp Giggle", (c, r) => { vial(c, r, "#ff6ac8"); line(c, quad([96, 176], [128, 206], [160, 176], 8), 10, OUTLINE, r); for (const x of [108, 148]) dab(c, x, 160, 8, OUTLINE, 0.9); }],
  L_EYES: ["Eye of Newt", (c, r) => { fill(c, circle(128, 128, 96), "#f8f4e8", r); fill(c, circle(128, 128, 56), "#e8d83a", r, { line: 8 }); fill(c, ellipse(128, 128, 12, 46), "#1a1418", r, { line: 6 }); shine(c, r, 104, 96, 14); }],
  L_ACCESSORY: ["Shiny Trinket", (c, r) => { soft(c, circle(128, 128, 116), "#fff2a8", r, { hatch: 14 }); fill(c, circle(128, 150, 70), "#ffd23f", r, { holes: [circle(128, 150, 44)] }); fill(c, [[128, 40], [160, 76], [128, 108], [96, 76]], "#5ac8ff", r); shine(c, r, 118, 66, 10); }],
  L_HEADWEAR: ["Dragon Horn", (c, r) => { fill(c, [...quad([60, 230], [40, 110], [150, 30], 14), [196, 24], ...quad([170, 60], [110, 130], [130, 230], 14)], "#d8c8a0", r); for (const y of [190, 150, 110]) line(c, [[60 + (230 - y) * 0.1, y], [130 - (230 - y) * 0.1, y]], 6, "#8a7050", r); }],
  FROSTWOOD: ["Frostwood Kindling", (c, r) => { soft(c, circle(128, 140, 112), "#9fd8ff", r, { hatch: 14 }); for (const [x0, y0, x1, y1] of [[50, 200, 200, 90], [60, 120, 210, 190], [90, 230, 170, 60]]) line(c, [[x0, y0], [x1, y1]], 22, "#6a90b0", r); for (const [x, y] of [[90, 90], [176, 70], [200, 150]]) fill(c, star(x, y, 18, 7), "#e8f8ff", r, { line: 6 }); }],
  SUNWOOD: ["Sunwood Log", (c, r) => { soft(c, circle(128, 140, 112), "#ffd890", r, { hatch: 14 }); fill(c, [[40, 110], [190, 80], [210, 170], [60, 200]], "#b8782a", r); fill(c, ellipse(200, 125, 26, 46), "#ffe080", r, { holes: [ellipse(200, 125, 10, 20)] }); for (const y of [120, 150]) line(c, [[60, y + 10], [180, y - 20]], 6, "#8a5a1a", r); }],
  SHIMMER: ["Shimmer Dust", (c, r) => { soft(c, circle(128, 140, 112), "#e8c8ff", r, { hatch: 14 }); fill(c, [...quad([60, 230], [40, 140], [96, 100], 12), [160, 100], ...quad([216, 140], [196, 230], [60, 230], 1)], "#9a6ad8", r); line(c, [[96, 100], [160, 100]], 12, "#ffd23f", r); for (const [x, y, s] of [[90, 60, 22], [150, 40, 30], [196, 80, 18], [128, 170, 20]]) fill(c, star(x, y, s, s * 0.4, 4), "#ffffff", r, { line: 6 }); }],
};

// The kitchen.
const KITCHEN = {
  Cauldron: (c, r) => {
    for (const x of [70, 186]) fill(c, rect(x - 14, 200, x + 14, 246), "#2a2228", r);  // its feet
    fill(c, [...quad([24, 100], [20, 250], [128, 236], 16), ...quad([128, 236], [236, 250], [232, 100], 16).slice(1)], "#3a3236", r);
    fill(c, ellipse(128, 100, 112, 26), "#4a4248", r, { holes: [ellipse(128, 100, 92, 16)] });  // its rim
    shine(c, r, 60, 150, 20);
  },
  Brew: (c, r) => soft(c, ellipse(128, 128, 120, 28), "#ffffff", r, { hatch: 8 }),
  Fire: (c, r) => {
    for (const [x, ht, col] of [[60, 150, "#ff4a1a"], [128, 210, "#ff7a1a"], [196, 160, "#ff4a1a"], [100, 120, "#ffd23f"], [160, 130, "#ffd23f"]]) {
      fill(c, [...quad([x - 40, 246], [x - 30, 246 - ht * 0.5], [x, 246 - ht], 8), ...quad([x, 246 - ht], [x + 30, 246 - ht * 0.5], [x + 40, 246], 8).slice(1)], col, r, { line: 8 });
    }
    for (const [x0, x1] of [[20, 200], [56, 236]]) line(c, [[x0, 240], [x1, 220]], 20, "#5a3a20", r);
  },
  Spoon: (c, r) => {
    line(c, [[40, 240], [190, 40]], 22, "#8a5a30", r);
    fill(c, rotate(ellipse(200, 30, 26, 40), 0.65, 200, 30), "#8a5a30", r);
  },
  Bubble: (c, r) => { line(c, circle(128, 128, 100).concat([[228, 128]]), 18, "#ffffff", r); soft(c, ellipse(96, 96, 22, 30), "#ffffff", r); },
  Puff: (c, r) => { for (const [x, y, s] of [[90, 150, 70], [160, 140, 76], [128, 90, 80], [128, 170, 70]]) soft(c, circle(x, y, s), "#ffffff", r, { hatch: 10 }); },
  Shelf: (c, r) => {
    fill(c, rect(4, 100, 252, 150), "#8a5a30", r);
    for (const x of [40, 216]) fill(c, [[x - 16, 150], [x + 16, 150], [x, 200]], "#6a4020", r, { line: 8 });
  },
  // The chef (your picture, MintPot.lua) and the drying line of photos.
  ChefHat: (c, r) => {
    for (const [x, y, s] of [[80, 120, 56], [176, 120, 56], [128, 80, 70]]) fill(c, circle(x, y, s), "#f8f4ec", r);
    fill(c, rect(62, 140, 194, 236), "#f8f4ec", r);
    for (const x of [100, 128, 156]) line(c, [[x, 150], [x, 226]], 5, "#c8c0b0", r);
  },
  Apron: (c, r) => {
    line(c, [[76, 34], [128, 6], [180, 34]], 7, "#c8c0b0", r);  // the neck strap
    fill(c, [[70, 30], [186, 30], [192, 100], [236, 112], [228, 250], [28, 250], [20, 112], [64, 100]], "#f8f4ec", r);
    line(c, [[12, 112], [244, 112]], 9, "#c02a2a", r);  // the waist ties
    fill(c, rect(92, 150, 164, 198), "#f0e8d8", r, { line: 8 });  // the pocket
    for (const [x, y] of [[66, 220], [168, 64], [196, 196]]) dab(c, x, y, 8, hex("#8a5a30"), 0.8);  // a stew stain or three
  },
  // The kitchen's back wall and floor (tiled across the page; tinted dark in the game).
  Wall: (c, r) => {
    soft(c, rect(0, 0, 256, 256), "#3a3034", r, { hatch: 10 });  // the mortar
    for (let row = 0; row < 8; row++) {
      const y = row * 32, shift = row % 2 ? 32 : 0;
      for (let k = -1; k < 4; k++) {
        const x = k * 64 + shift, tone = ["#8a7a70", "#7a6a64", "#958478", "#6e625e"][(row * 3 + k + 4) % 4];
        fill(c, rect(x + 3, y + 3, x + 61, y + 29), tone, r, { line: 5 });
      }
    }
  },
  Floor: (c, r) => {
    for (let row = 0; row < 4; row++) {
      const y = row * 64, tone = ["#8a5a30", "#7a4e2a", "#94643a", "#83552e"][row];
      fill(c, rect(0, y + 2, 256, y + 62), tone, r, { line: 5 });
      for (const x of [(row * 97) % 256, (row * 97 + 128) % 256]) line(c, [[x, y + 4], [x, y + 60]], 5, "#4a2e18", r);
      line(c, quad([20, y + 30], [128, y + 26], [236, y + 34], 6), 3, "#6a4220", r);  // the grain
    }
  },
  // The recipe card: a page torn from a cookbook, pinned to the wall (stretched to the card in the game).
  Paper: (c, r) => {
    const edge = [];
    for (let i = 0; i <= 16; i++) edge.push([12 + i * 14.5, 14 + (i % 2) * 5]);           // the torn top
    for (let i = 1; i <= 16; i++) edge.push([244 - (i % 2) * 4, 14 + i * 14]);            // the right
    for (let i = 1; i <= 16; i++) edge.push([244 - i * 14.5, 240 - (i % 3) * 4]);          // the bottom
    for (let i = 1; i < 16; i++) edge.push([12 + (i % 2) * 4, 240 - i * 14]);             // the left
    fill(c, edge, "#f2e4c4", r, { line: 7 });
    line(c, [[40, 30], [40, 230]], 4, "#d88a7a", r);                                     // the margin
    for (const [x, y, s] of [[190, 190, 26], [70, 210, 14]]) soft(c, circle(x, y, s), "#e0c898", r);  // stew stains
    fill(c, circle(128, 22, 9), "#8a5a30", r, { line: 5 });                              // the pin
  },
  Rope: (c, r) => line(c, quad([0, 90], [128, 150], [256, 90], 16), 12, "#c8a070", r),
  Peg: (c, r) => {
    fill(c, rect(104, 20, 152, 236), "#d8a868", r);
    line(c, [[104, 128], [152, 128]], 6, "#5a3a20", r);
    fill(c, rect(96, 100, 160, 120), "#a8b0b8", r, { line: 6 });
  },
  // The fire with fuel in it: pale, tinted in the game by the fuel's colour (rare blue, epic purple, legendary gold).
  FireTint: (c, r) => {
    for (const [x, ht, col] of [[60, 150, "#c8c8c8"], [128, 210, "#e0e0e0"], [196, 160, "#c8c8c8"], [100, 120, "#ffffff"], [160, 130, "#ffffff"]]) {
      fill(c, [...quad([x - 40, 246], [x - 30, 246 - ht * 0.5], [x, 246 - ht], 8), ...quad([x, 246 - ht], [x + 30, 246 - ht * 0.5], [x + 40, 246], 8).slice(1)], col, r, { line: 8 });
    }
  },
  Logs: (c, r) => {
    for (const [x0, x1] of [[20, 200], [56, 236]]) line(c, [[x0, 240], [x1, 220]], 20, "#5a3a20", r);
  },
  // The reveal's drops of brew (white, tinted in the game by the layer's rarity) and their splat.
  Drop: (c, r) => {
    const pts = [[128, 20]];
    for (let i = 0; i <= 24; i++) { const a = -0.2 * Math.PI + (i / 24) * 1.4 * Math.PI; pts.push([128 + Math.cos(a) * 62, 168 + Math.sin(a) * 62]); }
    fill(c, pts, "#ffffff", r);
    shine(c, r, 106, 166, 12);
  },
  Splat: (c, r) => {
    const pts = [];
    for (let i = 0; i < 28; i++) { const a = (i / 28) * 2 * Math.PI, rr = i % 2 ? 70 + (i * 37) % 30 : 104 + (i * 53) % 20; pts.push([128 + Math.cos(a) * rr, 128 + Math.sin(a) * rr]); }
    soft(c, pts, "#ffffff", r);
    for (const [x, y, s] of [[40, 60, 14], [216, 70, 10], [210, 210, 16], [50, 200, 10]]) soft(c, circle(x, y, s), "#ffffff", r);
  },
  Speech: (c, r) => {
    fill(c, [...ellipse(138, 104, 112, 80), [138, 104]].slice(0, -1), "#fffaf0", r);
    fill(c, [[60, 150], [30, 236], [110, 170]], "#fffaf0", r, { line: 8 });
  },
};

const sheet = [];
function make(name, draw, file, size, seed) {
  const c = canvas();
  draw(c, rng(seed));
  const rgba = crayon.toRgba(c);
  const small = Buffer.from(resize({ width: 256, height: 256, rgba }, size));
  bleedEdges(small, size, size);
  fs.mkdirSync(path.dirname(file), { recursive: true });
  writeBlp(file, size, size, small);
  sheet.push(Buffer.from(resize({ width: 256, height: 256, rgba }, 128)));
}
let n = 0;
for (const [key, [name, draw]] of Object.entries(INGREDIENTS)) make(name, draw, path.join(MEDIA, "Ingredients", key + ".blp"), 128, 7700 + n++ * 7919);
for (const [name, draw] of Object.entries(KITCHEN)) make(name, draw, path.join(MEDIA, "Kitchen", name + ".blp"), ["Cauldron", "Wall", "Floor", "Paper"].includes(name) ? 256 : 128, 8800 + n++ * 7919);
// The preview, on a dark board; and the names as Lua for Unlocks.lua (printed).
const T = 128, cols = 10, rows = Math.ceil(sheet.length / cols), out = Buffer.alloc(T * cols * T * rows * 4);
sheet.forEach((pic, k) => {
  const ox = (k % cols) * T, oy = Math.floor(k / cols) * T;
  for (let y = 0; y < T; y++) for (let x = 0; x < T; x++) {
    const i = (y * T + x) * 4, o = ((oy + y) * T * cols + ox + x) * 4, a = pic[i + 3] / 255;
    for (let q = 0; q < 3; q++) out[o + q] = Math.round(pic[i + q] * a + [50, 40, 60][q] * (1 - a));
    out[o + 3] = 255;
  }
});
fs.mkdirSync(PREVIEW, { recursive: true });
writePng(path.join(PREVIEW, "preview.png"), T * cols, T * rows, out);
// The chef's preview: an ogre with the hat and the apron where MintPot.lua puts them (centre and size as fractions of
// the chef's picture).
{
  const { decodePng, resample } = require("./convert-art");
  const ART = path.join(os.homedir(), "killtracker-art");
  const S = 256, chef = Buffer.alloc(S * S * 4);
  const over = (src, x0, y0, w, h) => {  // src: S-sized RGBA, drawn at x0, y0 scaled to w x h
    for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
      const tx = x0 + x, ty = y0 + y;
      if (tx < 0 || ty < 0 || tx >= S || ty >= S) continue;
      const i = (Math.floor(y * S / h) * S + Math.floor(x * S / w)) * 4, o = (ty * S + tx) * 4, a = src[i + 3] / 255;
      if (!a) continue;
      for (let q = 0; q < 3; q++) chef[o + q] = Math.round(src[i + q] * a + chef[o + q] * (1 - a));
      chef[o + 3] = Math.max(chef[o + 3], src[i + 3]);
    }
  };
  for (let i = 0; i < S * S; i++) chef.set([50, 40, 60, 255], i * 4);
  for (const rel of ["Skin/Uncommon/moss.png", "Outfit/Uncommon/striped-pajamas.png", "Expression/Uncommon/moss/smug-smile.png", "Eyes/Uncommon/moss/heavy-bags.png"]) {
    const file = path.join(ART, rel);
    if (!fs.existsSync(file)) continue;
    const img = decodePng(file);
    over(Buffer.from(resample(img, 0, 0, img.width, img.height, S, S)), 0, 0, S, S);
  }
  const piece = (name) => { const c = canvas(); KITCHEN[name](c, rng(1)); return Buffer.from(resize({ width: 256, height: 256, rgba: crayon.toRgba(c) }, S)); };
  const place = (name, cx, cy, size) => over(piece(name), Math.round((cx - size / 2) * S), Math.round((cy - size / 2) * S), Math.round(size * S), Math.round(size * S));
  place("Apron", 0.5, 0.8, 0.72);
  place("ChefHat", 0.51, -0.08, 0.54);
  writePng(path.join(PREVIEW, "preview-chef.png"), S, S, chef);
}
console.log(`Wrote ${Object.keys(INGREDIENTS).length} ingredients and ${Object.keys(KITCHEN).length} kitchen pieces.`);
if (process.argv[2] === "names") for (const [key, [name]] of Object.entries(INGREDIENTS)) console.log(`    ${key.toLowerCase()} = "${name}",`);
