// Converts the window's skeleton (the designer's NEW_DESIGN exports) to game textures and writes its layout.
// Source: %USERPROFILE%\killtracker-art-extra\NewDesign:
//   LOGO+TOPBEAM.png       the club logo and the top beam it sits on (the window's top-left corner, at 0, 0)
//   BOTTOM+SIDEBEAMS.png   the two posts and the bottom beam, on every page (at FRAME_AT)
//   MIDDLEBEAM.png         an upright beam a page can place (the Overview's spine), any length
//   CROSSBEAM.png          a lying beam a page can place (a divider), any length
// Target: Media/Skeleton: Logo, TopBeam, PostLeft, PostRight, Bottom (cut from the first two, at 1:1), and per
// placeable beam its two ends (with the nails, as painted) and a middle stretch made to repeat without a seam:
// its far end blended into the wood just before its start, so it runs on from the first end and into itself
// (CrossLeft, CrossRight, CrossTile; MiddleTop, MiddleBottom, MiddleTile). The far end's join is blended in the
// game (ns.UI.Beam, UI.lua). Also writes ../SkeletonLayout.lua: where the pieces go, in window pixels.
// Usage: node tools/convert-skeleton.js   No dependencies.

const fs = require("fs");
const os = require("os");
const path = require("path");
const { decodePng, writeBlp, bleedEdges } = require("./convert-art");

const SOURCE = path.join(os.homedir(), "killtracker-art-extra", "NewDesign");
const TARGET = path.join(__dirname, "..", "Media", "Skeleton");
const OUT = path.join(__dirname, "..", "SkeletonLayout.lua");
const FRAME_AT = { x: 184, y: 120 };  // the posts and bottom beam, in the window: close to the sidebar, the top beam running on past the right post
const WINDOW = { width: 1132, height: 778 };
const MASK_CELL = 8;  // the logo's drag handles: cells of this many pixels, where the logo is mostly opaque

fs.mkdirSync(TARGET, { recursive: true });
const source = (name) => decodePng(path.join(SOURCE, name + ".png"));

// The w x h block at (sx, sy) of img (or of what pixel(x, y) gives) in the top-left of a texW x texH texture.
// Returns the texture coordinates of the block.
function save(name, img, sx, sy, w, h, texW, texH, pixel) {
  const rgba = Buffer.alloc(texW * texH * 4);
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const o = (y * texW + x) * 4;
    if (pixel) rgba.set(pixel(x, y), o);
    else img.rgba.copy(rgba, o, ((sy + y) * img.width + sx + x) * 4, ((sy + y) * img.width + sx + x) * 4 + 4);
  }
  bleedEdges(rgba, texW, texH);
  writeBlp(path.join(TARGET, name + ".blp"), texW, texH, rgba);
  return [0, w / texW, 0, h / texH];
}
const piece = (file, x, y, w, h, coords) => ({ file, x, y, w, h, coords });

// The logo and the top beam.
const top = source("LOGO+TOPBEAM");
const LOGO = { w: 256, h: top.height }, BEAM = { x: 232, y: 88, w: top.width - 232, h: 64 };
const pieces = [
  piece("TopBeam", BEAM.x, BEAM.y, BEAM.w, BEAM.h, save("TopBeam", top, BEAM.x, BEAM.y, BEAM.w, BEAM.h, 1024, 64)),
  piece("Logo", 0, 0, LOGO.w, LOGO.h, save("Logo", top, 0, 0, LOGO.w, LOGO.h, 256, 256)),
];
const mask = [];
for (let cy = 0; cy * MASK_CELL < LOGO.h; cy++) {
  const runs = [];
  let start = -1;
  for (let cx = 0; cx <= LOGO.w / MASK_CELL; cx++) {
    let opaque = 0, n = 0;
    for (let y = cy * MASK_CELL; y < Math.min(LOGO.h, (cy + 1) * MASK_CELL); y++)
      for (let x = cx * MASK_CELL; x < Math.min(LOGO.w, (cx + 1) * MASK_CELL); x++) { n++; if (top.rgba[(y * top.width + x) * 4 + 3] > 128) opaque++; }
    const solid = n > 0 && opaque > n / 2;
    if (solid && start < 0) start = cx;
    if (!solid && start >= 0) { runs.push([start, cx - 1]); start = -1; }
  }
  mask.push(runs);
}

// The posts and the bottom beam (drawn over the posts' feet, where both have the same pixels).
const frame = source("BOTTOM+SIDEBEAMS");
const POST_H = 604, FOOT = 600;
const at = (x, y) => [FRAME_AT.x + x, FRAME_AT.y + y];
pieces.unshift(
  piece("PostLeft", ...at(0, 0), 64, POST_H, save("PostLeft", frame, 0, 0, 64, POST_H, 64, 1024)),
  piece("PostRight", ...at(frame.width - 64, 0), 64, POST_H, save("PostRight", frame, frame.width - 64, 0, 64, POST_H, 64, 1024)),
  piece("Bottom", ...at(0, FOOT), frame.width, frame.height - FOOT, save("Bottom", frame, 0, FOOT, frame.width, frame.height - FOOT, 1024, 64)),
);
// Drawn in this order: posts and bottom first (they're behind the top beam), then the top beam, then the logo.
pieces.sort((a, b) => ["PostLeft", "PostRight", "Bottom", "TopBeam", "Logo"].indexOf(a.file) - ["PostLeft", "PostRight", "Bottom", "TopBeam", "Logo"].indexOf(b.file));

// A placeable beam: along x for a lying one; an upright one is read with x and y swapped. cap: each end's length
// (also where the repeating stretch starts), tile: the stretch's length, blend: how much of its far end runs
// into the wood before its start.
function beam(name, img, upright, cap, tile, blend, ends) {
  const len = upright ? img.height : img.width, thick = upright ? img.width : img.height;
  const px = (along, across) => {
    const o = ((upright ? along : across) * img.width + (upright ? across : along)) * 4;
    return [...img.rgba.subarray(o, o + 4)];
  };
  const texThick = 64, texCap = 64, texTile = tile;
  const write = (file, length, texLength, f) => save(file, null, 0, 0,
    upright ? thick : length, upright ? length : thick, upright ? texThick : texLength, upright ? texLength : texThick,
    (x, y) => f(upright ? y : x, upright ? x : y));
  const first = write(name + ends[0], cap, texCap, (a, c) => px(a, c));
  const last = write(name + ends[1], cap, texCap, (a, c) => px(len - cap + a, c));
  const repeat = write(name + "Tile", tile, texTile, (a, c) => {
    const p = px(cap + a, c);
    if (a < tile - blend) return p;
    const t = (a - (tile - blend)) / blend, q = px(cap + a - tile, c);
    return p.map((v, i) => Math.round(v * (1 - t) + q[i] * t));
  });
  return { upright, thick, cap, tile, files: [name + ends[0], name + ends[1], name + "Tile"], coords: [first, last, repeat] };
}
const beams = {
  cross: beam("Cross", source("CROSSBEAM"), false, 64, 256, 60, ["Left", "Right"]),
  middle: beam("Middle", source("MIDDLEBEAM"), true, 56, 512, 56, ["Top", "Bottom"]),
};

// The page area: between the posts, under the top beam, over the bottom beam.
const inner = { left: FRAME_AT.x + 53, right: FRAME_AT.x + 880, top: BEAM.y + 58, bottom: FRAME_AT.y + 610 };

const num = (v) => +v.toFixed(4);
const list = (a) => `{ ${a.map(num).join(", ")} }`;
const lua = [
  "-- Generated by tools/convert-skeleton.js - don't edit; change it and rerun it.",
  "-- The window's skeleton (UI.lua): its size, the pieces on every page { file (Media/Skeleton), x, y (top-left, from the",
  "-- window's top-left, y down), w, h, coords (texture crop) } in drawing order, the page area between them, the",
  "-- logo's drag handles (rows of cells, runs of opaque ones) and the beams a page can place (ns.UI.Beam).",
  "",
  "local _, ns = ...",
  "",
  "ns.SkeletonLayout = {",
  `    width = ${WINDOW.width}, height = ${WINDOW.height},`,
  "    pieces = {",
  ...pieces.map((p) => `        { file = "${p.file}", x = ${p.x}, y = ${p.y}, w = ${p.w}, h = ${p.h}, coords = ${list(p.coords)} },`),
  "    },",
  `    inner = { left = ${inner.left}, right = ${inner.right}, top = ${inner.top}, bottom = ${inner.bottom} },`,
  `    topBeam = { left = ${BEAM.x}, right = ${top.width}, top = 94, bottom = 146 },`,
  `    logoSignBottom = 174,  -- the "Leisure Club" sign's bottom edge, where the sidebar's top button hangs`,
  `    logoMask = { cell = ${MASK_CELL}, rows = {`,
  ...mask.map((runs) => `        { ${runs.map((r) => `{ ${r[0] + 1}, ${r[1] + 1} }`).join(", ")} },`),
  "    } },",
  "    beams = {",
  ...Object.entries(beams).map(([key, b]) =>
    `        ${key} = { upright = ${b.upright}, thick = ${b.thick}, cap = ${b.cap}, tile = ${b.tile}, files = { ${b.files.map((f) => `"${f}"`).join(", ")} }, coords = { ${b.coords.map(list).join(", ")} } },`),
  "    },",
  "}",
  "",
];
fs.writeFileSync(OUT, lua.join("\n"));
console.log("Media/Skeleton and SkeletonLayout.lua written; page area", inner);
