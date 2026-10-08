// Converts the art of the wooden window frame and the new Overview (the character card) to game textures.
// Source: %USERPROFILE%\killtracker-art-extra\Overview: the designer's exports of the frame (FRAME.png) and of the
// new Overview's inside (INSIDE.png), placed by tools/frame-art.js, and the grey square (GREY_SQUARE_WOOD.png).
// Target: Media/Overview:
//   FrameLeft, FrameRight, FrameBottom   the window frame, cut from FRAME.png
//   Inside               the designer's export of the new Overview's inside (INSIDE.png), sample text wiped
//   Cap                  the grey square of boards on the spine's ends (drawn again over the frame and header)
//   Arrow                a white arrow pointing right (the name bar's; mirrored for left)
//   Icons/<Kind>_<NAME>  the card's icons: the crayon icons (tools/make-role-icons.js) on the design's shapes,
//                        128x128: Class_DRUID, Race_NIGHTELF, Gender_MALE,
//                        Prof_ALCHEMY ... and the empty shapes Base_CLASS, Base_RACE, Base_GENDER,
//                        Base_PROFESSION, Base_SECONDARY
// Usage: node tools/convert-overview.js   No dependencies.

const fs = require("fs");
const os = require("os");
const path = require("path");
const { decodePng, resample, writeBlp, bleedEdges } = require("./convert-art");

const SOURCE = path.join(os.homedir(), "killtracker-art-extra", "Overview");
const TARGET = path.join(__dirname, "..", "Media", "Overview");
const source = (name) => decodePng(path.join(SOURCE, name + ".png"));

// Smooth (bilinear) resample for enlarging: the icons are painted small, and resample() (area average) would
// blow their pixels up into blocks. Colours weighted by alpha, as in resample().
function enlarge(image, sx, sy, sw, sh, outW, outH) {
  const { width, height, rgba } = image;
  const out = Buffer.alloc(outW * outH * 4);
  const at = (x, y, c) => rgba[(Math.min(height - 1, Math.max(0, y)) * width + Math.min(width - 1, Math.max(0, x))) * 4 + c];
  for (let y = 0; y < outH; y++) {
    for (let x = 0; x < outW; x++) {
      const u = sx + ((x + 0.5) * sw) / outW - 0.5, v = sy + ((y + 0.5) * sh) / outH - 0.5;
      const x0 = Math.floor(u), y0 = Math.floor(v), fx = u - x0, fy = v - y0;
      let r = 0, g = 0, b = 0, a = 0;
      for (const [dx, dy, w] of [[0, 0, (1 - fx) * (1 - fy)], [1, 0, fx * (1 - fy)], [0, 1, (1 - fx) * fy], [1, 1, fx * fy]]) {
        const pa = (at(x0 + dx, y0 + dy, 3) / 255) * w;
        r += at(x0 + dx, y0 + dy, 0) * pa; g += at(x0 + dx, y0 + dy, 1) * pa; b += at(x0 + dx, y0 + dy, 2) * pa; a += pa;
      }
      const o = (y * outW + x) * 4;
      out.set([a ? r / a : 0, a ? g / a : 0, a ? b / a : 0, Math.round(a * 255)], o);
    }
  }
  return out;
}

// The box around the visible pixels.
function bounds(image) {
  let x0 = image.width, y0 = image.height, x1 = 0, y1 = 0;
  for (let y = 0; y < image.height; y++) {
    for (let x = 0; x < image.width; x++) {
      if (image.rgba[(y * image.width + x) * 4 + 3] > 8) {
        x0 = Math.min(x0, x); y0 = Math.min(y0, y); x1 = Math.max(x1, x + 1); y1 = Math.max(y1, y + 1);
      }
    }
  }
  return { x: x0, y: y0, w: x1 - x0, h: y1 - y0 };
}

function save(name, width, height, rgba) {
  bleedEdges(rgba, width, height);
  writeBlp(path.join(TARGET, name + ".blp"), width, height, rgba);
}

fs.rmSync(TARGET, { recursive: true, force: true });
fs.mkdirSync(path.join(TARGET, "Icons"), { recursive: true });

// The frame: the designer's export of the whole window frame (FRAME.png, the window drawn 4.29 times its size in
// the game), cut into the left post, the right post and the bottom (with the corner squares) as they are, crooked
// planks and all; tools/frame-art.js says where each part goes in the window.
const { FRAME_ART, FRAME_PARTS, INSIDE_WIPE, INSIDE_CAPS, INSIDE_POLAROID, capArea } = require("./frame-art");
{
  const image = source("FRAME");
  for (const part of FRAME_PARTS) {
    const sx = (part.x0 - FRAME_ART.left) * FRAME_ART.scaleX, sy = (part.y0 - FRAME_ART.top) * FRAME_ART.scaleY;
    const sw = (part.x1 - part.x0) * FRAME_ART.scaleX, sh = (part.y1 - part.y0) * FRAME_ART.scaleY;
    save(part.texture, part.width, part.height, resample(image, sx, sy, sw, sh, part.width, part.height));
  }
}
// The grey square: its visible part, filling the texture.
for (const [file, name, w, h] of []) {
  const image = source(file), box = bounds(image);
  const enlarging = box.w < w || box.h < h;
  save(name, w, h, (enlarging ? enlarge : resample)(image, box.x, box.y, box.w, box.h, w, h));
}
// The inside of the new Overview: the designer's export as it is (INSIDE.png), its sample name and signature wiped
// (INSIDE_WIPE), at its own size in the top-left corner of a 1024x1024 texture (OverviewLayout.lua crops it).
{
  const image = source("INSIDE"), { width, height, rgba } = image;
  const lum = (o) => 0.3 * rgba[o] + 0.59 * rgba[o + 1] + 0.11 * rgba[o + 2];
  for (const wipe of INSIDE_WIPE) {
    // The letters (and their outline, two pixels round them).
    const marked = new Set();
    for (let y = wipe.y0; y < wipe.y1; y++) {
      for (let x = wipe.x0; x < wipe.x1; x++) {
        const v = lum((y * width + x) * 4);
        if (wipe.bright ? v > wipe.bright : v < wipe.dark) {
          for (let dy = -2; dy <= 2; dy++) for (let dx = -2; dx <= 2; dx++) marked.add((y + dy) * width + x + dx);
        }
      }
    }
    const flat = wipe.sample && rgba.subarray((wipe.sample[1] * width + wipe.sample[0]) * 4, (wipe.sample[1] * width + wipe.sample[0]) * 4 + 3);
    for (const i of marked) {
      const x = i % width;
      if (wipe.fill === "flat") { rgba.set(flat, i * 4); continue; }
      // The middle value of the column's unmarked wood between the label's top and bottom rows.
      const column = [];
      for (let y = wipe.rows[0]; y <= wipe.rows[1]; y++) if (!marked.has(y * width + x)) column.push(y * width + x);
      if (!column.length) continue;
      column.sort((a, b) => lum(a * 4) - lum(b * 4));
      rgba.copy(rgba, i * 4, column[column.length >> 1] * 4, column[column.length >> 1] * 4 + 3);
    }
  }
  // The polaroid's shadow: the painted one (a hard band on the boards left of it and under it) taken out by carrying
  // the wood next to it over the band, then a soft one that fades out from the polaroid's edge.
  {
    const P = INSIDE_POLAROID, at = (x, y) => (y * width + x) * 4;
    const isPolaroid = (o) => rgba[o] > 195 && Math.abs(rgba[o] - rgba[o + 1]) < 10 && Math.abs(rgba[o + 1] - rgba[o + 2]) < 10;
    const edge = {};  // [y] = the polaroid's leftmost x on that row
    for (let y = P.top; y <= P.bottom; y++) {
      for (let x = P.searchLeft; x < P.searchLeft + 80; x++) if (isPolaroid(at(x, y))) { edge[y] = x; break; }
    }
    const left = Math.min(...Object.values(edge));
    for (let y = P.top; y <= P.bottom; y++) {
      if (edge[y] === undefined) continue;
      for (let x = edge[y] - P.band; x < edge[y]; x++) rgba.copy(rgba, at(x, y), at(x - P.band, y), at(x - P.band, y) + 4);
    }
    for (let x = left - P.band; x <= P.right; x++) {
      for (let y = P.bottom + 1; y <= P.bottom + P.band; y++) rgba.copy(rgba, at(x, y), at(x, y + P.band), at(x, y + P.band) + 4);
    }
    const bottomEdge = edge[P.bottom] ?? left;
    for (let y = P.top; y <= P.bottom + P.soft; y++) {
      for (let x = left - P.soft; x <= P.right; x++) {
        const inside = y <= P.bottom && edge[y] !== undefined && x >= edge[y];
        if (inside) continue;
        const dx = y <= P.bottom && edge[y] !== undefined ? edge[y] - x : Infinity;
        const dy = y > P.bottom && x >= bottomEdge ? y - P.bottom : Infinity;
        const corner = y > P.bottom && x < bottomEdge ? Math.hypot(bottomEdge - x, y - P.bottom) : Infinity;
        const d = Math.min(dx, dy, corner) - 1;
        if (d >= P.soft) continue;
        const fade = Math.min(1, (P.right - x) / P.soft);  // the shadow under it ends softly at its right corner
        const dark = 1 - P.strength * (1 - Math.max(0, d) / P.soft) ** 2 * fade;
        const o = at(x, y);
        for (let c = 0; c < 3; c++) rgba[o + c] = Math.round(rgba[o + c] * dark);
      }
    }
  }
  // The spine's grey squares, moved to their own textures (128x128, from the top left) and cleared here.
  for (const cap of INSIDE_CAPS) {
    const { poly, x0, y0, x1, y1 } = capArea(cap);
    const own = Buffer.alloc(128 * 128 * 4);
    for (let y = y0; y < y1; y++) {
      for (let x = x0; x < x1; x++) {
        let inside = false;
        for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) {
          const [xi, yi] = poly[i], [xj, yj] = poly[j];
          if (yi > y + 0.5 !== yj > y + 0.5 && x + 0.5 < ((xj - xi) * (y + 0.5 - yi)) / (yj - yi) + xi) inside = !inside;
        }
        if (!inside) continue;
        rgba.copy(own, ((y - y0) * 128 + x - x0) * 4, (y * width + x) * 4, (y * width + x) * 4 + 4);
        rgba.fill(0, (y * width + x) * 4, (y * width + x) * 4 + 4);
      }
    }
    save(cap.texture, 128, 128, own);
  }
  const canvas = Buffer.alloc(1024 * 1024 * 4);
  for (let y = 0; y < height; y++) rgba.copy(canvas, y * 1024 * 4, y * width * 4, (y + 1) * width * 4);
  save("Inside", 1024, 1024, canvas);
}
// The arrow: a white arrowhead pointing right, its back edge curving in a little; antialiased by supersampling.
{
  const size = 64, rgba = Buffer.alloc(size * size * 4);
  const inside = (x, y) => {  // in units of the texture (0..1)
    const tip = 0.94, back = 0.12, half = 0.44;
    if (x > tip) return false;
    const reach = ((tip - x) / (tip - back)) * half;  // the sloping sides
    if (Math.abs(y - 0.5) > reach) return false;
    const notch = back + 0.16 * (1 - ((y - 0.5) / half) ** 2);  // the curved back
    return x >= notch;
  };
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      let hits = 0;
      for (let sy = 0; sy < 4; sy++) for (let sx = 0; sx < 4; sx++) if (inside((x + (sx + 0.5) / 4) / size, (y + (sy + 0.5) / 4) / size)) hits++;
      rgba.set([255, 255, 255, Math.round((hits / 16) * 255)], (y * size + x) * 4);
    }
  }
  save("Arrow", size, size, rgba);
}
// The icons: a shape drawn here (as in the design: light grey, a dark slightly wobbly outline) with a crayon icon
// from tools/make-role-icons.js (%USERPROFILE%killtracker-art-extraRoleIcons, 256x256) on it, 128x128.
const ROLE_ICONS = path.join(os.homedir(), "killtracker-art-extra", "RoleIcons");
const SIZE = 128, FILL = [218, 218, 218], LINE = [30, 28, 28], LINE_WIDTH = 9;
// A regular polygon pointing up, filling the canvas (radius r from the centre, its corners nudged a little).
function polygon(sides, r, turn = 0, seed = 1, amount = 2.4) {
  let n = seed;
  const wobble = () => { n = (n * 16807) % 2147483647; return (n / 2147483647 - 0.5) * amount; };
  return Array.from({ length: sides }, (_, i) => {
    const a = -Math.PI / 2 + turn + (i * 2 * Math.PI) / sides;
    return [SIZE / 2 + Math.cos(a) * r + wobble(), SIZE / 2 + Math.sin(a) * r + wobble()];
  });
}
const SHAPES = {
  CLASS: () => polygon(7, 61, 0, 7),
  GENDER: () => polygon(6, 62, 0, 6),
  RACE: () => polygon(64, 59, 0, 3, 0.5),
  PROFESSION: () => polygon(5, 63, 0, 5),
  SECONDARY: () => polygon(4, 62, 0, 4),
};
// The icon's size on its shape (share of the canvas) and how far down its centre sits (the pentagon's middle is
// lower than the canvas's).
const PLACE = { CLASS: [0.6, 0.02], GENDER: [0.62, 0], RACE: [0.66, 0], PROFESSION: [0.56, 0.06], SECONDARY: [0.5, 0] };
function distanceToEdge(x, y, poly) {
  let best = Infinity;
  for (let i = 0; i < poly.length; i++) {
    const [ax, ay] = poly[i], [bx, by] = poly[(i + 1) % poly.length];
    const dx = bx - ax, dy = by - ay, t = Math.max(0, Math.min(1, ((x - ax) * dx + (y - ay) * dy) / (dx * dx + dy * dy)));
    best = Math.min(best, Math.hypot(x - ax - t * dx, y - ay - t * dy));
  }
  return best;
}
function insidePoly(x, y, poly) {
  let inside = false;
  for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    const [xi, yi] = poly[i], [xj, yj] = poly[j];
    if (yi > y !== yj > y && x < ((xj - xi) * (y - yi)) / (yj - yi) + xi) inside = !inside;
  }
  return inside;
}
// The shape alone: the outline straddles the polygon's edge (half its width outside), so it's drawn inset by that.
function shape(kind) {
  const poly = SHAPES[kind]().map(([x, y]) => [SIZE / 2 + (x - SIZE / 2) * (1 - LINE_WIDTH / SIZE), SIZE / 2 + (y - SIZE / 2) * (1 - LINE_WIDTH / SIZE)]);
  const rgba = Buffer.alloc(SIZE * SIZE * 4);
  for (let y = 0; y < SIZE; y++) {
    for (let x = 0; x < SIZE; x++) {
      let fill = 0, line = 0;
      for (let sy = 0; sy < 4; sy++) {
        for (let sx = 0; sx < 4; sx++) {
          const px = x + (sx + 0.5) / 4, py = y + (sy + 0.5) / 4;
          if (distanceToEdge(px, py, poly) < LINE_WIDTH / 2) line++;
          else if (insidePoly(px, py, poly)) fill++;
        }
      }
      const alpha = (fill + line) / 16;
      if (!alpha) continue;
      const mix = line / (fill + line);
      rgba.set([...FILL.map((c, k) => c * (1 - mix) + LINE[k] * mix), Math.round(alpha * 255)], (y * SIZE + x) * 4);
    }
  }
  return rgba;
}
// Lays a crayon icon over a shape (alpha "over"), scaled to share of the canvas, centred (shifted down by drop).
function overlay(rgba, iconFile, share, drop) {
  const icon = decodePng(iconFile), size = Math.round(SIZE * share);
  const small = resample(icon, 0, 0, icon.width, icon.height, size, size);
  const x0 = Math.round((SIZE - size) / 2), y0 = Math.round((SIZE - size) / 2 + drop * SIZE);
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      const i = (y * size + x) * 4, o = ((y0 + y) * SIZE + x0 + x) * 4, a = small[i + 3] / 255;
      if (!a) continue;
      const under = rgba[o + 3] / 255, out = a + under * (1 - a);
      for (let c = 0; c < 3; c++) rgba[o + c] = Math.round((small[i + c] * a + rgba[o + c] * under * (1 - a)) / out);
      rgba[o + 3] = Math.round(out * 255);
    }
  }
  return rgba;
}
const ICONS = {
  Class: ["DRUID", "HUNTER", "MAGE", "PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR"].map((n) => [n, "CLASS"]),
  Race: ["DWARF", "GNOME", "HUMAN", "NIGHTELF", "SKYBORNE"].map((n) => [n, "RACE"]),
  Gender: ["MALE", "FEMALE", "NONBINARY"].map((n) => [n, "GENDER"]),
  Prof: [...["ALCHEMY", "BLACKSMITHING", "ENCHANTING", "ENGINEERING", "HERBALISM", "LEATHERWORKING", "MINING", "SKINNING",
    "TAILORING"].map((n) => [n, "PROFESSION"]), ...["COOKING", "FIRSTAID", "FISHING"].map((n) => [n, "SECONDARY"])],
};
for (const kind of Object.keys(SHAPES)) save(path.join("Icons", "Base_" + kind), SIZE, SIZE, shape(kind));
for (const [prefix, list] of Object.entries(ICONS)) {
  for (const [name, kind] of list) {
    const [share, drop] = PLACE[kind];
    save(path.join("Icons", `${prefix}_${name}`), SIZE, SIZE, overlay(shape(kind), path.join(ROLE_ICONS, name.toLowerCase() + ".png"), share, drop));
  }
}
console.log("Media/Overview written:", fs.readdirSync(TARGET).length - 1, "textures and", fs.readdirSync(path.join(TARGET, "Icons")).length, "icons");
