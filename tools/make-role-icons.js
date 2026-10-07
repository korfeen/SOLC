// Draws the Discord role icons (256x256 PNG, transparent) in "ogre crayon" style: chunky shapes filled with
// wobbly crayon hatching on paper grain, with a thick dark crayon outline, in the ogre mode crayon colours.
// Writes %USERPROFILE%\killtracker-art-extra\RoleIcons\<name>.png and a preview sheet (preview.png) there, and
// the stat card icons (ADDON_ICONS) as textures into Media/Icons.
// Usage: node tools/make-role-icons.js   No dependencies.

const fs = require("fs");
const os = require("os");
const path = require("path");
const zlib = require("zlib");

const SIZE = 256;
const OUT = path.join(os.homedir(), "killtracker-art-extra", "RoleIcons");

// --- Randomness and noise, seeded so every run draws the same icons -------------------------------------

function rng(seed) {
  let s = seed >>> 0;
  return () => ((s = (s * 1664525 + 1013904223) >>> 0) / 4294967296);
}
// Paper grain: hashed per-pixel noise, some pixels take less crayon.
const grain = (x, y) => {
  let h = (Math.floor(x) * 374761393 + Math.floor(y) * 668265263) >>> 0;
  h = Math.imul(h ^ (h >>> 13), 1274126177) >>> 0;
  return 0.4 + 0.6 * ((h & 1023) / 1023);
};

// --- Canvas: straight-alpha RGBA floats with "over" blending ---------------------------------------------

function canvas() {
  return { rgb: new Float32Array(SIZE * SIZE * 3), a: new Float32Array(SIZE * SIZE) };
}
function blend(c, x, y, color, alpha) {
  if (x < 0 || y < 0 || x >= SIZE || y >= SIZE || alpha <= 0) return;
  const i = y * SIZE + x, below = c.a[i], out = alpha + below * (1 - alpha);
  for (let k = 0; k < 3; k++) c.rgb[i * 3 + k] = (color[k] * alpha + c.rgb[i * 3 + k] * below * (1 - alpha)) / out;
  c.a[i] = out;
}
// One crayon dab: a soft round spot, thinned by the paper grain.
function dab(c, cx, cy, r, color, strength) {
  for (let y = Math.floor(cy - r - 1); y <= cy + r + 1; y++) {
    for (let x = Math.floor(cx - r - 1); x <= cx + r + 1; x++) {
      const d = Math.hypot(x + 0.5 - cx, y + 0.5 - cy);
      const edge = Math.min(1, Math.max(0, r + 0.5 - d));
      if (edge > 0) blend(c, x, y, color, strength * edge * grain(x, y));
    }
  }
}
// A crayon stroke along points: dabs every pixel, wandering a little sideways.
function stroke(c, points, width, color, strength, random) {
  let wobble = 0;
  for (let p = 1; p < points.length; p++) {
    const [x0, y0] = points[p - 1], [x1, y1] = points[p];
    const length = Math.hypot(x1 - x0, y1 - y0), steps = Math.max(1, Math.ceil(length));
    const nx = -(y1 - y0) / (length || 1), ny = (x1 - x0) / (length || 1);
    for (let s = 0; s < steps; s++) {
      const t = s / steps;
      wobble = Math.max(-1.6, Math.min(1.6, wobble + (random() - 0.5) * 0.5));
      const r = width / 2 * (0.85 + random() * 0.3);
      dab(c, x0 + (x1 - x0) * t + nx * wobble, y0 + (y1 - y0) * t + ny * wobble, r, color, strength);
    }
  }
}

// --- Shapes as polygons ------------------------------------------------------------------------------

function inside(x, y, poly) {
  let hit = false;
  for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    const [xi, yi] = poly[i], [xj, yj] = poly[j];
    if ((yi > y) !== (yj > y) && x < ((xj - xi) * (y - yi)) / (yj - yi) + xi) hit = !hit;
  }
  return hit;
}
const quad = (a, b, c, n = 24) => Array.from({ length: n + 1 }, (_, i) => {
  const t = i / n, u = 1 - t;
  return [u * u * a[0] + 2 * u * t * b[0] + t * t * c[0], u * u * a[1] + 2 * u * t * b[1] + t * t * c[1]];
});
const circle = (cx, cy, r, n = 48) => Array.from({ length: n }, (_, i) => [cx + r * Math.cos((i / n) * 2 * Math.PI), cy + r * Math.sin((i / n) * 2 * Math.PI)]);
const ellipse = (cx, cy, rx, ry, n = 48) => Array.from({ length: n }, (_, i) => [cx + rx * Math.cos((i / n) * 2 * Math.PI), cy + ry * Math.sin((i / n) * 2 * Math.PI)]);
// A five-pointed star (outer radius r, inner radius r2).
const star = (cx, cy, r, r2) => Array.from({ length: 10 }, (_, i) => {
  const a = (i / 10) * 2 * Math.PI - Math.PI / 2, d = i % 2 ? r2 : r;
  return [cx + d * Math.cos(a), cy + d * Math.sin(a)];
});
// A curved band (a bow): the arc of radius r around (cx, cy) from angle a0 to a1, w thick.
const arcBand = (cx, cy, r, w, a0, a1, n = 32) => {
  const arc = (radius) => Array.from({ length: n + 1 }, (_, i) => {
    const a = a0 + ((a1 - a0) * i) / n;
    return [cx + radius * Math.cos(a), cy + radius * Math.sin(a)];
  });
  return [...arc(r + w / 2), ...arc(r - w / 2).reverse()];
};
// A crescent: circle (ax, ay, ar) with circle (bx, by, br) bitten out of it.
function crescent(ax, ay, ar, bx, by, br, n = 180) {
  const inB = ([x, y]) => Math.hypot(x - bx, y - by) < br;
  const inA = ([x, y]) => Math.hypot(x - ax, y - ay) < ar;
  const outer = Array.from({ length: n }, (_, i) => [ax + ar * Math.cos((i / n) * 2 * Math.PI), ay + ar * Math.sin((i / n) * 2 * Math.PI)]);
  const inner = Array.from({ length: n }, (_, i) => [bx + br * Math.cos((i / n) * 2 * Math.PI), by + br * Math.sin((i / n) * 2 * Math.PI)]);
  // The outer arc that's left, starting just after the bite, then the bite's edge back the other way.
  const start = outer.findIndex((p, i) => !inB(p) && inB(outer[(i + n - 1) % n]));
  const arc = [];
  for (let i = 0; i < n; i++) { const p = outer[(start + i) % n]; if (inB(p)) break; arc.push(p); }
  const startB = inner.findIndex((p, i) => inA(p) && !inA(inner[(i + n - 1) % n]));
  const bite = [];
  for (let i = 0; i < n; i++) { const p = inner[(startB + i) % n]; if (!inA(p)) break; bite.push(p); }
  return [...arc, ...bite.reverse()];
}
const rotate = (poly, angle, cx = 128, cy = 128) => poly.map(([x, y]) => [
  cx + (x - cx) * Math.cos(angle) - (y - cy) * Math.sin(angle), cy + (x - cx) * Math.sin(angle) + (y - cy) * Math.cos(angle)]);

// Fills a polygon with crayon hatching (two directions, like scribbling it in), then outlines it.
function crayonShape(c, poly, color, random, { outline = OUTLINE, hatch = 9, angle = 0.6 } = {}) {
  for (const [a, strength] of [[angle, 0.75], [angle + 1.2, 0.45]]) {
    const dx = Math.cos(a), dy = Math.sin(a), nx = -dy, ny = dx;
    for (let offset = -200; offset <= 200; offset += hatch * 0.85) {
      // Each stroke a slightly different shade, like a real crayon pressed harder or softer.
      const shade = 0.88 + random() * 0.2;
      const tone = color.map((v) => Math.min(255, v * shade));
      // Walk the line across the canvas, stroking the parts inside the shape.
      let run = [];
      for (let t = -190; t <= 190; t += 2) {
        const x = 128 + nx * offset + dx * t, y = 128 + ny * offset + dy * t;
        if (inside(x, y, poly)) run.push([x, y]);
        else if (run.length) { if (run.length > 1) stroke(c, run, hatch, tone, strength, random); run = []; }
      }
      if (run.length > 1) stroke(c, run, hatch, tone, strength, random);
    }
  }
  if (outline) stroke(c, [...poly, poly[0]], 11, outline, 0.95, random);
}

// --- Colours (the ogre mode crayons) -----------------------------------------------------------------

const hex = (h) => [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16));
const OUTLINE = hex("#2b1a10");
const C = {
  blue: hex("#4f86e8"), steel: hex("#b7c1cc"), green: hex("#5bd24a"), white: hex("#fff6dc"),
  red: hex("#ff4a3a"), orange: hex("#ff9a2a"), brown: hex("#8a5a2e"), gold: hex("#ffd23f"),
};
// The header buttons' light grey paint (as in the header design).
const PAINT = hex("#e6e1d6");
// WoW's class colours (the same as the Discord class roles).
const CLASS = {
  warrior: hex("#C69B6D"), paladin: hex("#F48CBA"), hunter: hex("#AAD372"), rogue: hex("#FFF468"),
  priest: hex("#FFFFFF"), shaman: hex("#0070DD"), mage: hex("#3FC7EB"), warlock: hex("#8788EE"), druid: hex("#FF7C0A"),
};

// --- The icons ---------------------------------------------------------------------------------------

// A chunky sword standing on the centre line, turned by tilt (radians) and shrunk by scale.
function sword(c, random, tilt, scale = 1) {
  const shape = (poly) => rotate(poly.map(([x, y]) => [128 + (x - 128) * scale, 128 + (y - 128) * scale]), tilt);
  crayonShape(c, shape([[128, 8], [154, 40], [154, 164], [102, 164], [102, 40]]), C.steel, random);
  crayonShape(c, shape([[125, 34], [131, 34], [131, 156], [125, 156]]), C.white, random, { outline: null, hatch: 6 });
  crayonShape(c, shape([[66, 162], [190, 162], [190, 192], [66, 192]]), C.gold, random, { hatch: 8 });
  crayonShape(c, shape([[114, 192], [142, 192], [142, 226], [114, 226]]), C.brown, random, { hatch: 8 });
  crayonShape(c, shape(circle(128, 234, 18)), C.red, random, { hatch: 7 });
}

const ICONS = {
  // A big round-topped shield with a gold boss.
  tank(c, random) {
    const shield = [
      ...quad([44, 58], [128, 18], [212, 58]),
      ...quad([212, 58], [214, 170], [128, 232]).slice(1),
      ...quad([128, 232], [42, 170], [44, 58]).slice(1),
    ];
    crayonShape(c, shield, C.blue, random);
    crayonShape(c, quad([128, 46], [128, 140], [128, 214]).flatMap(([x, y]) => [[x - 9, y]]).concat(
      quad([128, 214], [128, 140], [128, 46]).map(([x, y]) => [x + 9, y])), C.steel, random, { outline: null, hatch: 7 });
    crayonShape(c, circle(128, 118, 30), C.gold, random, { hatch: 7 });
  },
  // A chunky healing cross with a little heart.
  healer(c, random) {
    const w = 34, l = 92;
    const cross = [[128 - w, 128 - l], [128 + w, 128 - l], [128 + w, 128 - w], [128 + l, 128 - w], [128 + l, 128 + w],
      [128 + w, 128 + w], [128 + w, 128 + l], [128 - w, 128 + l], [128 - w, 128 + w], [128 - l, 128 + w],
      [128 - l, 128 - w], [128 - w, 128 - w]];
    crayonShape(c, rotate(cross, -0.08), C.green, random);
    const heart = [...quad([128, 150], [96, 124], [104, 106]), ...quad([104, 106], [116, 92], [128, 110]).slice(1),
      ...quad([128, 110], [140, 92], [152, 106]).slice(1), ...quad([152, 106], [160, 124], [128, 150]).slice(1)];
    crayonShape(c, heart, C.white, random, { hatch: 6 });
  },
  // A chunky sword, point up and to the right.
  dps(c, random) {
    sword(c, random, Math.PI / 4);
  },

  // --- The Overview's stat cards (also written into the addon as textures, see ADDON_ICONS) ---

  // A stack of gold coins.
  points(c, random) {
    const rim = hex("#e0a020");
    for (const y of [206, 180, 154]) crayonShape(c, ellipse(104, y, 78, 26), rim, random, { hatch: 7 });
    crayonShape(c, circle(156, 112, 74), hex("#ffcf3a"), random);
    crayonShape(c, circle(156, 112, 46), hex("#fff09a"), random, { outline: null, hatch: 7 });
    crayonShape(c, star(156, 112, 30, 13), rim, random, { outline: null, hatch: 5 });
  },
  // A cartoon skull.
  kills(c, random) {
    // The cranium: a circle's arc from lower left, over the top, to lower right; then the jaw.
    const cranium = Array.from({ length: 41 }, (_, i) => {
      const a = Math.PI - 0.5 + (i / 40) * (Math.PI + 1);
      return [128 + 88 * Math.cos(a), 108 + 88 * Math.sin(a)];
    });
    crayonShape(c, [...cranium, [186, 160], [176, 216], [80, 216], [70, 160]], hex("#f4ecd8"), random);
    for (const x of [94, 162]) crayonShape(c, ellipse(x, 118, 26, 30), OUTLINE, random, { outline: null, hatch: 6 });
    crayonShape(c, [[128, 142], [114, 170], [142, 170]], OUTLINE, random, { outline: null, hatch: 5 });
    for (const x of [106, 128, 150]) stroke(c, [[x, 188], [x, 214]], 7, OUTLINE, 0.9, random);
  },
  // A medal on a red ribbon, with a star.
  achievements(c, random) {
    crayonShape(c, [[70, 12], [118, 12], [146, 120], [104, 132]], C.red, random, { hatch: 7 });
    crayonShape(c, [[186, 12], [138, 12], [110, 120], [152, 132]], hex("#d8322a"), random, { hatch: 7 });
    crayonShape(c, circle(128, 168, 66), C.gold, random);
    crayonShape(c, star(128, 168, 40, 17), C.white, random, { hatch: 6 });
  },
  // Two crossed swords.
  pvp(c, random) {
    sword(c, random, Math.PI / 4, 0.8);
    sword(c, random, -Math.PI / 4, 0.8);
  },

  // --- The window's header buttons (on the dark wooden squares) ---

  // A chunky X.
  close(c, random) {
    const bar = [[106, 26], [150, 26], [150, 230], [106, 230]];
    crayonShape(c, rotate(bar, Math.PI / 4), PAINT, random);
    crayonShape(c, rotate(bar, -Math.PI / 4), PAINT, random);
  },
  // A cog with a hole.
  settings(c, random) {
    const cog = [];
    for (let i = 0; i < 32; i++) {
      const a = (i / 32) * 2 * Math.PI, r = i % 4 < 2 ? 112 : 84;
      cog.push([128 + r * Math.cos(a), 128 + r * Math.sin(a)]);
    }
    crayonShape(c, cog, PAINT, random);
    crayonShape(c, circle(128, 128, 34), OUTLINE, random, { outline: null, hatch: 6 });
  },

  // Level: a round blue badge with a big gold up-arrow.
  level(c, random) {
    crayonShape(c, circle(128, 128, 112), C.blue, random);
    crayonShape(c, [[128, 34], [206, 122], [158, 122], [158, 214], [98, 214], [98, 122], [50, 122]], C.gold, random);
  },

  // --- Professions ---

  // A round flask of green potion with a cork.
  alchemy(c, random) {
    crayonShape(c, [[106, 34], [150, 34], [150, 100], [106, 100]], hex("#cfe8f0"), random, { hatch: 7 });
    crayonShape(c, circle(128, 160, 78), hex("#cfe8f0"), random);
    crayonShape(c, [...circle(128, 160, 62).filter(([, y]) => y > 150), [70, 150], [186, 150]].sort((a, b) =>
      Math.atan2(a[1] - 160, a[0] - 128) - Math.atan2(b[1] - 160, b[0] - 128)), hex("#5be04a"), random, { outline: null, hatch: 7 });
    crayonShape(c, [[100, 14], [156, 14], [152, 44], [104, 44]], C.brown, random, { hatch: 6 });
    crayonShape(c, circle(100, 130, 12), C.white, random, { outline: null, hatch: 5 });
  },
  // An anvil.
  blacksmithing(c, random) {
    const steel = hex("#8e98a6");
    crayonShape(c, [[20, 70], [196, 70], [226, 92], [196, 120], [176, 120], [160, 150], [96, 150], [80, 120], [40, 120]], steel, random);
    crayonShape(c, [[96, 150], [160, 150], [182, 214], [74, 214]], hex("#6d7684"), random);
    crayonShape(c, [[48, 214], [208, 214], [208, 238], [48, 238]], hex("#5a6270"), random, { hatch: 7 });
  },
  // A wand with a purple magic star.
  enchanting(c, random) {
    crayonShape(c, rotate([[120, 100], [136, 100], [136, 244], [120, 244]], 0.6), C.brown, random, { hatch: 7 });
    crayonShape(c, star(170, 76, 62, 26), hex("#c27cff"), random);
    crayonShape(c, star(170, 76, 24, 10), C.white, random, { outline: null, hatch: 5 });
    for (const [x, y, r] of [[70, 50, 22], [214, 168, 18], [52, 136, 15]]) crayonShape(c, star(x, y, r, r * 0.45), C.gold, random, { outline: null, hatch: 4 });
  },
  // A wrench.
  engineering(c, random) {
    const tilt = Math.PI / 4;
    crayonShape(c, rotate([[114, 80], [142, 80], [142, 236], [114, 236]], tilt), C.steel, random);
    crayonShape(c, rotate([...circle(128, 62, 44), ], tilt), C.steel, random);
    crayonShape(c, rotate([[114, 10], [142, 10], [142, 62], [114, 62]], tilt), OUTLINE, random, { outline: null, hatch: 6 });
    crayonShape(c, rotate(circle(128, 220, 10), tilt), OUTLINE, random, { outline: null, hatch: 5 });
  },
  // A flower with leaves.
  herbalism(c, random) {
    stroke(c, [[128, 244], [124, 190], [130, 130]], 12, hex("#3d8a2e"), 0.95, random);
    crayonShape(c, [...quad([126, 200], [60, 196], [52, 150]), ...quad([52, 150], [104, 150], [126, 200]).slice(1)], hex("#62c94a"), random, { hatch: 6 });
    crayonShape(c, [...quad([130, 178], [196, 172], [206, 126]), ...quad([206, 126], [150, 130], [130, 178]).slice(1)], hex("#62c94a"), random, { hatch: 6 });
    for (let i = 0; i < 5; i++) {
      const a = (i / 5) * 2 * Math.PI - Math.PI / 2;
      crayonShape(c, circle(128 + 40 * Math.cos(a), 84 + 40 * Math.sin(a), 30), hex("#ff8fc8"), random, { hatch: 6 });
    }
    crayonShape(c, circle(128, 84, 24), C.gold, random, { hatch: 6 });
  },
  // A stretched leather hide with stitches.
  leatherworking(c, random) {
    const hide = [[60, 30], [100, 52], [156, 52], [196, 30], [214, 84], [196, 128], [222, 192], [180, 228], [128, 210], [76, 228], [34, 192], [60, 128], [42, 84]];
    crayonShape(c, hide, hex("#b5763a"), random);
    for (let y = 76; y <= 188; y += 28) stroke(c, [[96, y], [160, y]], 5, hex("#f3e2c0"), 0.85, random);
  },
  // A pickaxe.
  mining(c, random) {
    crayonShape(c, rotate([[116, 70], [140, 70], [140, 246], [116, 246]], 0.5), C.brown, random, { hatch: 7 });
    const head = [...quad([18, 112], [118, 14], [238, 64]), [226, 102], ...quad([204, 96], [128, 70], [46, 136]).slice(1)];
    crayonShape(c, rotate(head, 0.5), C.steel, random);
  },
  // A curved skinning knife.
  skinning(c, random) {
    const blade = [...quad([62, 150], [70, 40], [214, 22]), ...quad([214, 22], [150, 90], [146, 168]).slice(1)];
    crayonShape(c, blade, C.steel, random);
    crayonShape(c, rotate([[104, 156], [152, 156], [152, 238], [104, 238]], 0.45), hex("#8a5a2e"), random, { hatch: 7 });
  },
  // A spool of red thread with a needle.
  tailoring(c, random) {
    crayonShape(c, [[60, 40], [196, 40], [196, 66], [60, 66]], hex("#c8a26a"), random, { hatch: 7 });
    crayonShape(c, [[74, 66], [182, 66], [182, 190], [74, 190]], hex("#e8433a"), random);
    for (let y = 84; y <= 176; y += 18) stroke(c, [[80, y], [176, y + 6]], 4, hex("#a82a22"), 0.7, random);
    crayonShape(c, [[60, 190], [196, 190], [196, 216], [60, 216]], hex("#c8a26a"), random, { hatch: 7 });
    crayonShape(c, rotate([[214, 20], [224, 20], [222, 244], [216, 244]], -0.35), C.steel, random, { hatch: 4 });
  },
  // A big meat drumstick: a teardrop of roast meat on a bone with knobbly ends.
  cooking(c, random) {
    const tilt = -0.75;
    crayonShape(c, rotate([[114, 150], [142, 150], [142, 226], [114, 226]], tilt), hex("#f4ecd8"), random, { hatch: 6 });
    for (const x of [112, 144]) crayonShape(c, rotate(circle(x, 232, 20), tilt), hex("#f4ecd8"), random, { hatch: 5 });
    const meat = [...quad([128, 176], [40, 150], [52, 82]), ...quad([52, 82], [72, 18], [128, 16]).slice(1),
      ...quad([128, 16], [184, 18], [204, 82]).slice(1), ...quad([204, 82], [216, 150], [128, 176]).slice(1)];
    crayonShape(c, rotate(meat, tilt), hex("#b8642a"), random);
    crayonShape(c, rotate(ellipse(104, 74, 30, 20), tilt), hex("#e0904a"), random, { outline: null, hatch: 6 });
  },
  // A rolled bandage.
  firstaid(c, random) {
    crayonShape(c, [[90, 150], [230, 150], [230, 210], [90, 210]], hex("#f4f1ea"), random);
    crayonShape(c, circle(90, 120, 76), hex("#f4f1ea"), random);
    crayonShape(c, circle(90, 120, 30), hex("#d9d2c4"), random, { hatch: 6 });
    crayonShape(c, [[150, 166], [196, 166], [196, 194], [150, 194]], C.red, random, { hatch: 5 });
  },
  // A blue fish.
  fishing(c, random) {
    crayonShape(c, ellipse(116, 128, 92, 56), hex("#4f9ae8"), random);
    crayonShape(c, [[196, 128], [246, 76], [246, 180]], hex("#3a7cc8"), random);
    crayonShape(c, circle(62, 112, 12), OUTLINE, random, { outline: null, hatch: 5 });
    stroke(c, [[94, 92], [104, 128], [94, 164]], 6, hex("#2d5fa0"), 0.9, random);
  },

  // --- Classes: each in its class colour (CLASS below) ---

  // A double-bladed axe.
  warrior(c, random) {
    const tilt = -0.45;
    crayonShape(c, rotate([[119, 30], [137, 30], [137, 238], [119, 238]], tilt), C.brown, random, { hatch: 7 });
    const right = [[138, 54], ...quad([186, 24], [232, 84], [186, 140]), [138, 112]];
    const left = right.map(([x, y]) => [256 - x, y]);
    crayonShape(c, rotate(right, tilt), CLASS.warrior, random);
    crayonShape(c, rotate(left, tilt), CLASS.warrior, random);
    crayonShape(c, rotate([[114, 46], [142, 46], [142, 120], [114, 120]], tilt), C.steel, random, { hatch: 6 });
  },
  // A big warhammer.
  paladin(c, random) {
    const tilt = 0.5;
    crayonShape(c, rotate([[118, 84], [138, 84], [138, 240], [118, 240]], tilt), C.brown, random, { hatch: 7 });
    crayonShape(c, rotate([[58, 30], [198, 30], [198, 98], [58, 98]], tilt), CLASS.paladin, random);
    crayonShape(c, rotate([[112, 30], [144, 30], [144, 98], [112, 98]], tilt), C.gold, random, { outline: null, hatch: 7 });
  },
  // A bow with an arrow nocked.
  hunter(c, random) {
    crayonShape(c, arcBand(60, 128, 112, 32, -1.05, 1.05), CLASS.hunter, random);
    const tip = (a) => [60 + 112 * Math.cos(a), 128 + 112 * Math.sin(a)];
    stroke(c, [tip(-1.05), [96, 128], tip(1.05)], 5, OUTLINE, 0.95, random);
    crayonShape(c, [[40, 119], [192, 119], [192, 137], [40, 137]], C.brown, random, { hatch: 7 });
    crayonShape(c, [[186, 96], [246, 128], [186, 160]], C.steel, random, { hatch: 7 });
    crayonShape(c, [[22, 94], [72, 120], [50, 128], [22, 128]], C.red, random, { hatch: 7 });
    crayonShape(c, [[22, 162], [72, 136], [50, 128], [22, 128]], C.red, random, { hatch: 7 });
  },
  // Two crossed daggers with yellow grips.
  rogue(c, random) {
    for (const tilt of [0.62, -0.62]) {
      crayonShape(c, rotate([[128, 10], [154, 46], [154, 140], [102, 140], [102, 46]], tilt), C.steel, random);
      crayonShape(c, rotate([[78, 138], [178, 138], [178, 162], [78, 162]], tilt), C.brown, random, { hatch: 7 });
      crayonShape(c, rotate([[112, 162], [144, 162], [144, 214], [112, 214]], tilt), CLASS.rogue, random, { hatch: 7 });
      crayonShape(c, rotate(circle(128, 226, 17), tilt), C.gold, random, { hatch: 7 });
    }
  },
  // A holy sun: white rays around a golden centre.
  priest(c, random) {
    const rays = [];
    for (let i = 0; i < 16; i++) {
      const a = (i / 16) * 2 * Math.PI, r = i % 2 ? 66 : 116;
      rays.push([128 + r * Math.cos(a - Math.PI / 2), 128 + r * Math.sin(a - Math.PI / 2)]);
    }
    crayonShape(c, rays, CLASS.priest, random);
    crayonShape(c, circle(128, 128, 46), C.gold, random, { hatch: 7 });
  },
  // A lightning bolt.
  shaman(c, random) {
    crayonShape(c, [[158, 14], [80, 140], [124, 140], [94, 244], [186, 104], [140, 104], [182, 14]], CLASS.shaman, random);
    crayonShape(c, [[152, 34], [110, 112], [126, 112]], C.white, random, { outline: null, hatch: 5 });
  },
  // A wizard hat with stars.
  mage(c, random) {
    crayonShape(c, ellipse(128, 200, 104, 30), CLASS.mage, random);
    const cone = [...quad([84, 196], [104, 110], [150, 22]), ...quad([150, 22], [140, 70], [176, 196]).slice(1)];
    crayonShape(c, cone, CLASS.mage, random);
    crayonShape(c, [[86, 180], [174, 180], [178, 198], [82, 198]], C.gold, random, { hatch: 6 });
    crayonShape(c, star(124, 132, 18, 8), C.gold, random, { hatch: 5 });
    crayonShape(c, star(148, 82, 12, 5), C.gold, random, { hatch: 4 });
  },
  // A fel flame.
  warlock(c, random) {
    const flame = [...quad([128, 244], [52, 230], [64, 150]), ...quad([64, 150], [74, 100], [100, 70]).slice(1),
      ...quad([100, 70], [96, 110], [118, 120]).slice(1), ...quad([118, 120], [112, 50], [150, 12]).slice(1),
      ...quad([150, 12], [146, 72], [176, 96]).slice(1), ...quad([176, 96], [210, 150], [196, 196]).slice(1),
      ...quad([196, 196], [182, 244], [128, 244]).slice(1)];
    crayonShape(c, flame, CLASS.warlock, random);
    const core = [...quad([128, 228], [92, 220], [98, 180]), ...quad([98, 180], [108, 150], [128, 132]).slice(1),
      ...quad([128, 132], [130, 160], [150, 170]).slice(1), ...quad([150, 170], [166, 200], [128, 228]).slice(1)];
    crayonShape(c, core, hex("#d7ff6a"), random, { outline: null, hatch: 7 });
  },
  // A paw print.
  druid(c, random) {
    crayonShape(c, ellipse(128, 168, 62, 52), CLASS.druid, random);
    for (const [x, y, r] of [[58, 108, 24], [98, 62, 26], [158, 62, 26], [198, 108, 24]]) {
      crayonShape(c, ellipse(x, y, r, r * 1.2), CLASS.druid, random, { hatch: 7 });
    }
  },

  // --- Races (the guild's Alliance races in WoW: Forever) ---

  // A gold crown with red gems.
  human(c, random) {
    crayonShape(c, [[44, 196], [44, 92], [88, 138], [128, 62], [168, 138], [212, 92], [212, 196]], C.gold, random);
    for (const [x, y] of [[44, 84], [128, 54], [212, 84]]) crayonShape(c, circle(x, y, 14), C.gold, random, { hatch: 6 });
    crayonShape(c, [[44, 166], [212, 166], [212, 198], [44, 198]], hex("#e8a92a"), random, { hatch: 7 });
    for (const x of [88, 128, 168]) crayonShape(c, circle(x, 182, 11), C.red, random, { hatch: 5 });
  },
  // A horned helmet over a ginger beard.
  dwarf(c, random) {
    const horn = hex("#f3e6c4");
    const left = [...quad([70, 118], [30, 96], [26, 34]), ...quad([26, 34], [54, 92], [92, 96]).slice(1)];
    crayonShape(c, left, horn, random, { hatch: 6 });
    crayonShape(c, left.map(([x, y]) => [256 - x, y]), horn, random, { hatch: 6 });
    const beard = [[70, 140], [186, 140], ...quad([186, 140], [198, 206], [160, 222]).slice(1), [146, 240], [128, 226],
      [110, 240], [96, 222], ...quad([96, 222], [58, 206], [70, 140]).slice(1)];
    crayonShape(c, beard, hex("#d9652b"), random);
    crayonShape(c, [...quad([60, 132], [64, 36], [128, 32]), ...quad([128, 32], [192, 36], [196, 132]).slice(1)], C.steel, random);
    crayonShape(c, [[50, 120], [206, 120], [206, 150], [50, 150]], hex("#c9a227"), random, { hatch: 7 });
    crayonShape(c, [[118, 118], [138, 118], [138, 182], [118, 182]], C.steel, random, { hatch: 6 });
  },
  // A crescent moon with a little star.
  nightelf(c, random) {
    crayonShape(c, crescent(116, 132, 100, 156, 104, 84), hex("#c7b6ff"), random);
    crayonShape(c, star(186, 170, 30, 13), C.gold, random, { hatch: 6 });
  },
  // A cog with a pink centre.
  gnome(c, random) {
    const cog = [];
    const teeth = 10;
    for (let i = 0; i < teeth * 4; i++) {
      const a = (i / (teeth * 4)) * 2 * Math.PI, r = i % 4 < 2 ? 112 : 86;
      cog.push([128 + r * Math.cos(a), 128 + r * Math.sin(a)]);
    }
    crayonShape(c, cog, C.steel, random);
    crayonShape(c, circle(128, 128, 42), hex("#ff8fc8"), random, { hatch: 7 });
  },
  // A feather, for the Skyborne's gift of the wind.
  skyborne(c, random) {
    const feather = [...quad([80, 222], [44, 110], [208, 22]), ...quad([208, 22], [214, 150], [100, 230]).slice(1)];
    crayonShape(c, feather, hex("#9fe3ff"), random);
    stroke(c, [[64, 248], [96, 206], ...quad([96, 206], [146, 120], [204, 30]).slice(1)], 7, OUTLINE, 0.95, random);
    for (const [x0, y0, x1, y1] of [[96, 176, 70, 158], [124, 138, 168, 140], [140, 104, 112, 88]]) {
      stroke(c, [[x0, y0], [x1, y1]], 6, OUTLINE, 0.9, random);
    }
  },
};

// --- PNG -----------------------------------------------------------------------------------------------

const crcTable = Array.from({ length: 256 }, (_, n) => { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; return c >>> 0; });
const crc = (b) => { let c = 0xffffffff; for (const v of b) c = crcTable[(c ^ v) & 255] ^ (c >>> 8); return (c ^ 0xffffffff) >>> 0; };
const chunk = (type, data) => { const l = Buffer.alloc(4); l.writeUInt32BE(data.length); const td = Buffer.concat([Buffer.from(type), data]); const c = Buffer.alloc(4); c.writeUInt32BE(crc(td)); return Buffer.concat([l, td, c]); };
function writePng(file, width, height, rgba) {
  const raw = Buffer.alloc((width * 4 + 1) * height);
  for (let y = 0; y < height; y++) rgba.copy(raw, y * (width * 4 + 1) + 1, y * width * 4, (y + 1) * width * 4);
  const header = Buffer.alloc(13); header.writeUInt32BE(width, 0); header.writeUInt32BE(height, 4); header[8] = 8; header[9] = 6;
  fs.writeFileSync(file, Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk("IHDR", header), chunk("IDAT", zlib.deflateSync(raw)), chunk("IEND", Buffer.alloc(0))]));
}
const toRgba = (c) => {
  const out = Buffer.alloc(SIZE * SIZE * 4);
  for (let i = 0; i < SIZE * SIZE; i++) {
    for (let k = 0; k < 3; k++) out[i * 4 + k] = Math.round(Math.min(255, c.rgb[i * 3 + k]));
    out[i * 4 + 3] = Math.round(Math.min(1, c.a[i]) * 255);
  }
  return out;
};

fs.mkdirSync(OUT, { recursive: true });
const names = Object.keys(ICONS);
// Each icon's wobble is seeded by its place in this list, so adding icons (at the end) never changes the others.
const SEED_ORDER = ["tank", "healer", "dps", "warrior", "paladin", "hunter", "rogue", "priest", "shaman", "mage",
  "warlock", "druid", "human", "dwarf", "nightelf", "gnome", "skyborne", "points", "kills", "achievements", "pvp",
  "close", "settings", "alchemy", "blacksmithing", "enchanting", "engineering", "herbalism", "leatherworking", "mining",
  "skinning", "tailoring", "cooking", "firstaid", "fishing", "level"];
const seedOf = (name) => {
  const index = SEED_ORDER.indexOf(name);
  if (index < 0) throw new Error(`Add ${name} to the end of SEED_ORDER`);
  return index * 7919 + 17;
};
// The icons the addon uses too: written as 128x128 textures into Media/Icons (the Overview's stat cards).
const ADDON_ICONS = { points: "Points", kills: "Kills", achievements: "Achievements", pvp: "PvP", close: "Close", settings: "Settings" };
const { resize, writeBlp, bleedEdges } = require("./convert-art");
const ADDON_OUT = path.join(__dirname, "..", "Media", "Icons");
// Preview: every icon on Discord's dark and light backgrounds.
const sheet = Buffer.alloc(SIZE * names.length * SIZE * 2 * 4);
names.forEach((name, n) => {
  const c = canvas();
  ICONS[name](c, rng(seedOf(name)));
  const rgba = toRgba(c);
  writePng(path.join(OUT, name + ".png"), SIZE, SIZE, rgba);
  if (ADDON_ICONS[name]) {
    const small = Buffer.from(resize({ width: SIZE, height: SIZE, rgba }, 128));
    bleedEdges(small, 128, 128);
    fs.mkdirSync(ADDON_OUT, { recursive: true });
    writeBlp(path.join(ADDON_OUT, ADDON_ICONS[name] + ".blp"), 128, 128, small);
  }
  for (const [row, bg] of [[0, [49, 51, 56]], [1, [242, 243, 245]]]) {
    for (let y = 0; y < SIZE; y++) for (let x = 0; x < SIZE; x++) {
      const i = (y * SIZE + x) * 4, a = rgba[i + 3] / 255, o = ((row * SIZE + y) * SIZE * names.length + n * SIZE + x) * 4;
      for (let k = 0; k < 3; k++) sheet[o + k] = Math.round(rgba[i + k] * a + bg[k] * (1 - a));
      sheet[o + 3] = 255;
    }
  }
});
writePng(path.join(OUT, "preview.png"), SIZE * names.length, SIZE * 2, sheet);
console.log(`Wrote ${names.join(", ")} to ${OUT}`);
