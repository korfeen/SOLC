// Draws the Discord role icons (256x256 PNG, transparent) in "ogre crayon" style: chunky shapes filled with
// wobbly crayon hatching on paper grain, with a thick dark crayon outline, in the ogre mode crayon colours.
// Writes %USERPROFILE%\killtracker-art-extra\RoleIcons\<name>.png and a preview sheet (preview.png) there.
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
// WoW's class colours (the same as the Discord class roles).
const CLASS = {
  warrior: hex("#C69B6D"), paladin: hex("#F48CBA"), hunter: hex("#AAD372"), rogue: hex("#FFF468"),
  priest: hex("#FFFFFF"), shaman: hex("#0070DD"), mage: hex("#3FC7EB"), warlock: hex("#8788EE"), druid: hex("#FF7C0A"),
};

// --- The icons ---------------------------------------------------------------------------------------

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
    const tilt = Math.PI / 4;
    const blade = rotate([[128, 8], [154, 40], [154, 164], [102, 164], [102, 40]], tilt);
    crayonShape(c, blade, C.steel, random);
    crayonShape(c, rotate([[125, 34], [131, 34], [131, 156], [125, 156]], tilt), C.white, random, { outline: null, hatch: 6 });
    crayonShape(c, rotate([[66, 162], [190, 162], [190, 192], [66, 192]], tilt), C.gold, random, { hatch: 8 });
    crayonShape(c, rotate([[114, 192], [142, 192], [142, 226], [114, 226]], tilt), C.brown, random, { hatch: 8 });
    crayonShape(c, rotate(circle(128, 234, 18), tilt), C.red, random, { hatch: 7 });
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
// Preview: every icon on Discord's dark and light backgrounds.
const sheet = Buffer.alloc(SIZE * names.length * SIZE * 2 * 4);
names.forEach((name, n) => {
  const c = canvas();
  ICONS[name](c, rng(n * 7919 + 17));
  const rgba = toRgba(c);
  writePng(path.join(OUT, name + ".png"), SIZE, SIZE, rgba);
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
