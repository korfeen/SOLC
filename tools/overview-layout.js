// The wooden window frame (on every page) and the new Overview: where each part goes. Writes OverviewLayout.lua
// (read by UI.lua and OverviewCard.lua) and a preview (%USERPROFILE%\killtracker-art-extra\Overview\preview.png):
// the design on the left, this layout drawn with the real textures and sample content on the right.
// The frame and the Overview's inside are the designer's own exports (tools/frame-art.js says where they sit). The
// live parts (numbers, pictures, the activity list, the name, the photo with the model, icons, signature, the GEARZ
// button) go on spots measured here in the design export with content (quarter pixels), converted to window pixels.
// Window coordinates: pixels from the window's top-left corner, y down (the window is 950 x 625). A piece: centre
// (x, y), w x h before turning, tilt in degrees (clockwise), texture (Media/Overview), coords (texture crop: left,
// right, top, bottom); drawn in this order, later ones on top.
// Usage: node tools/overview-layout.js   (after node tools/convert-overview.js)

const fs = require("fs");
const os = require("os");
const path = require("path");
const zlib = require("zlib");
const { decodePng, readBlp } = require("./convert-art");
const { FRAME_PARTS, QUARTER, quarterX, quarterY, INSIDE, CAPS, capArea } = require("./frame-art");

const ART = path.join(os.homedir(), "killtracker-art-extra", "Overview");
const DESIGN = path.join(ART, "v2", "BG_OVERVIEW_WITH_CONTENT2.png");  // the design, the whole window (quarter canvas)
const INSIDE_SIZE = { w: 813, h: 601 };  // the inside texture's art, in the top-left of its 1024x1024 texture
const SCALE = (QUARTER.scaleX + QUARTER.scaleY) / 2;

// Quarter pixels to window pixels.
const rect = (x0, y0, x1, y1) => ({ x: (quarterX(x0) + quarterX(x1)) / 2, y: (quarterY(y0) + quarterY(y1)) / 2,
  w: (x1 - x0) * QUARTER.scaleX, h: (y1 - y0) * QUARTER.scaleY });
const spot = (x, y, size) => ({ x: quarterX(x), y: quarterY(y), size: size * SCALE });
const point = (x, y) => ({ x: quarterX(x), y: quarterY(y) });

// The frame, on every page, each part where it sits in its export. Everything between the posts, above the
// bottom, is the page area (INNER).
const FRAME = FRAME_PARTS.map((p) => ({ x: (p.x0 + p.x1) / 2, y: (p.y0 + p.y1) / 2, w: p.x1 - p.x0, h: p.y1 - p.y0, tilt: 0, texture: p.texture }));
const INNER = { left: 206, right: 923, top: 44, bottom: 588 };

// The Overview's inside, under the frame; the spine's grey squares over the frame's bottom and the header.
const [ax, ay] = INSIDE.at;
const PAGE = [{ ...rect(ax, ay, ax + INSIDE_SIZE.w, ay + INSIDE_SIZE.h), tilt: 0, texture: "Inside",
  coords: [0, INSIDE_SIZE.w / 1024, 0, INSIDE_SIZE.h / 1024] }];
const SPINE_CAPS = CAPS.map((cap) => {
  const { x0, y0, x1, y1 } = capArea(cap);
  return { ...rect(x0, y0, x1, y1), tilt: 0, texture: cap.texture, coords: [0, (x1 - x0) / 128, 0, (y1 - y0) / 128] };
});

// The left page: the stat plaques' numbers, the showcase's three small polaroids, the activity list.
const STATS = {
  // points, achievements, kills: the board to hover, and where the number goes (centre, room)
  boards: [rect(235, 174, 333, 275), rect(351, 173, 450, 271), rect(474, 179, 573, 276)],
  numbers: [rect(245, 243, 325, 261), rect(361, 244, 441, 262), rect(483, 244, 563, 262)],
};
// A small polaroid: centre, tilt (degrees clockwise) and nail, in quarter pixels; drawn in this order (the middle one
// behind the other two). Its base (Media/Overview/PolaroidSmall) is 164 x 202 in the design's own pixels, shown at
// POLAROID_SCALE; the picture, the caption and the date sit at these spots on it (base pixels from its centre).
const POLAROID_SCALE = 0.956;
const POLAROIDS = [
  { slot: 2, x: 447.4, y: 390.3, tilt: -3.75, nail: [433.5, 300] },
  { slot: 1, x: 302.1, y: 424.1, tilt: -2.6, nail: [290, 335] },
  { slot: 3, x: 552.75, y: 441, tilt: 3.4, nail: [562.5, 345] },
];
const POLAROID_BASE = { w: 164, h: 202, photo: { x: 0, y: -21, size: 126 }, caption: { x: 0, y: 64, w: 140, h: 38 }, date: { x: 76, y: 90 } };
const FEED = {
  // the activity list on its flat panel (between the frame's post and the spine, under the heading board, above the
  // frame's bottom; quarter pixels), in this many even rows
  area: rect(226, 564, 584, 714),
  rows: 5,
  textSize: 13, timeSize: 11,
  under: [5, 407],  // the rows' stripes run from under the frame's post to under the spine (background x)
};
// The spine beside the list, drawn over its rows (cut by tools/convert-overview.js).
const SPINE_CUT = (() => {
  const { x0, x1, y0, y1 } = INSIDE.spineCut;
  return { ...rect(ax + x0, ay + y0, ax + x1, ay + y1), tilt: 0, texture: "SpineCut", coords: [0, (x1 - x0) / 64, 0, (y1 - y0) / 256] };
})();

// The right page: the character card and the GEARZ button.
const CARD = {
  label: rect(723.3, 188.3, 910, 225),
  arrows: [rect(668.3, 185, 723.3, 228.3), rect(910, 185, 963.3, 228.3)],
  arrowGlyphs: [rect(680, 193.3, 706.7, 220), rect(925, 190, 953.3, 221.7)],
  photo: rect(688.3, 264, 949.5, 565),
  icons: {
    race: spot(718.3, 296.3, 46),
    gender: spot(718.7, 347, 46),
    class: spot(914.2, 302.2, 52),
    professions: [spot(914.2, 480, 52), spot(914.2, 535.8, 52)],
    secondary: [spot(708.3, 491.7, 40), spot(734.2, 516.7, 40), spot(710, 543.3, 40)],
  },
  signature: rect(711.7, 581.7, 928.3, 635),
  gear: rect(731, 661.7, 893.3, 726.7),
};

// --- OverviewLayout.lua ----------------------------------------------------------------------------------

const num = (v) => String(Math.round(v * 1000) / 1000);
const piece = (p) => `{ x = ${num(p.x)}, y = ${num(p.y)}, w = ${num(p.w)}, h = ${num(p.h)}, tilt = ${num(p.tilt)}, texture = "${p.texture}"`
  + `${p.coords ? `, coords = { ${p.coords.map(num).join(", ")} }` : ""} }`;
const area = (r) => `{ x = ${num(r.x)}, y = ${num(r.y)}, w = ${num(r.w)}, h = ${num(r.h)} }`;
const at = (s) => `{ x = ${num(s.x)}, y = ${num(s.y)}, size = ${num(s.size)} }`;
const xy = (p) => `{ x = ${num(p.x)}, y = ${num(p.y)} }`;
const polaroidScale = POLAROID_SCALE * SCALE;  // base pixels to window pixels
const base = POLAROID_BASE;
const lua = [
  "-- Generated by tools/overview-layout.js - don't edit; change the layout there and rerun it.",
  "-- The wooden window frame (UI.lua) and the new Overview (OverviewCard.lua), in window pixels (from its top-left,",
  "-- y down). Pieces: { x, y (centre), w, h, tilt (degrees clockwise), texture (Media/Overview), coords (texture",
  "-- crop) } in drawing order; areas: { x, y (centre), w, h }; spots: { x, y (centre), size }.",
  "",
  "local _, ns = ...",
  "",
  "ns.OverviewLayout = {",
  "    frame = {", ...FRAME.map((p) => `        ${piece(p)},`), "    },",
  `    inner = { left = ${INNER.left}, right = ${INNER.right}, top = ${INNER.top}, bottom = ${INNER.bottom} },`,
  "    page = {", ...PAGE.map((p) => `        ${piece(p)},`), "    },",
  "    spineCaps = {", ...SPINE_CAPS.map((p) => `        ${piece(p)},`), "    },",
  "    stats = {",
  `        boards = { ${STATS.boards.map(area).join(", ")} },`,
  `        numbers = { ${STATS.numbers.map(area).join(", ")} },`,
  "    },",
  "    -- The showcase's small polaroids, in drawing order: slot (which showcase picture), centre, tilt, nail. The",
  "    -- base's parts are offsets from its centre before turning.",
  "    polaroids = {",
  ...POLAROIDS.map((p) => `        { slot = ${p.slot}, x = ${num(quarterX(p.x))}, y = ${num(quarterY(p.y))}, tilt = ${p.tilt}, nail = ${xy(point(...p.nail))} },`),
  "    },",
  `    polaroid = { w = ${num(base.w * polaroidScale)}, h = ${num(base.h * polaroidScale)},`,
  `        photo = { x = ${num(base.photo.x * polaroidScale)}, y = ${num(base.photo.y * polaroidScale)}, size = ${num(base.photo.size * polaroidScale)} },`,
  `        caption = { x = ${num(base.caption.x * polaroidScale)}, y = ${num(base.caption.y * polaroidScale)}, w = ${num(base.caption.w * polaroidScale)}, h = ${num(base.caption.h * polaroidScale)} },`,
  `        date = { x = ${num(base.date.x * polaroidScale)}, y = ${num(base.date.y * polaroidScale)} },`,
  `        nail = ${num(10 * SCALE)} },`,
  "    feed = {",
  `        left = ${num(FEED.area.x - FEED.area.w / 2)}, top = ${num(FEED.area.y - FEED.area.h / 2)}, width = ${num(FEED.area.w)},`,
  `        rowHeight = ${num(FEED.area.h / FEED.rows)}, rows = ${FEED.rows}, textSize = ${FEED.textSize}, timeSize = ${FEED.timeSize},`,
  `        rowLeft = ${num(quarterX(ax + FEED.under[0]))}, rowRight = ${num(quarterX(ax + FEED.under[1]))},`,
  `        spine = ${piece(SPINE_CUT)},`,
  "    },",
  "    card = {",
  `        label = ${area(CARD.label)},`,
  `        arrows = { ${CARD.arrows.map(area).join(", ")} },`,
  `        arrowGlyphs = { ${CARD.arrowGlyphs.map(area).join(", ")} },`,
  `        photo = ${area(CARD.photo)},`,
  "        icons = {",
  `            race = ${at(CARD.icons.race)},`,
  `            gender = ${at(CARD.icons.gender)},`,
  `            class = ${at(CARD.icons.class)},`,
  `            professions = { ${CARD.icons.professions.map(at).join(", ")} },`,
  `            secondary = { ${CARD.icons.secondary.map(at).join(", ")} },`,
  "        },",
  `        signature = ${area(CARD.signature)},`,
  `        gear = ${area(CARD.gear)},`,
  "    },",
  "}",
  "",
];
fs.writeFileSync(path.join(__dirname, "..", "OverviewLayout.lua"), lua.join("\n"));

// --- Preview ---------------------------------------------------------------------------------------------
// Drawn in the design's own (quarter) pixels, next to it.

const design = decodePng(DESIGN);
const W = design.width, H = design.height;
const out = new Float32Array(W * H * 3).fill(40);
const toQ = (x, y) => [(x - quarterX(0)) / QUARTER.scaleX, (y - quarterY(0)) / QUARTER.scaleY];
const put = (x, y, rgb, a) => {
  if (x < 0 || y < 0 || x >= W || y >= H || a <= 0) return;
  const i = (y * W + x) * 3;
  for (let k = 0; k < 3; k++) out[i + k] = rgb[k] * a + out[i + k] * (1 - a);
};
const sample = (img, u, v) => {
  const x = Math.min(img.width - 1, Math.max(0, u * img.width - 0.5)), y = Math.min(img.height - 1, Math.max(0, v * img.height - 0.5));
  const x0 = Math.floor(x), y0 = Math.floor(y), x1 = Math.min(x0 + 1, img.width - 1), y1 = Math.min(y0 + 1, img.height - 1);
  const fx = x - x0, fy = y - y0, px = (xx, yy, c) => img.rgba[(yy * img.width + xx) * 4 + c];
  return [0, 1, 2, 3].map((c) => (px(x0, y0, c) * (1 - fx) + px(x1, y0, c) * fx) * (1 - fy) + (px(x0, y1, c) * (1 - fx) + px(x1, y1, c) * fx) * fy);
};
const textures = {};
const texture = (name) => (textures[name] ??= readBlp(path.join(__dirname, "..", "Media", "Overview", name + ".blp")));
// A piece in window coordinates, drawn where it lands in the design's pixels.
function draw(p, img = texture(p.texture), tint) {
  const a = (p.tilt * Math.PI) / 180, cos = Math.cos(a), sin = Math.sin(a);
  const [l, r, t, b] = p.coords || [0, 1, 0, 1];
  const [cx, cy] = toQ(p.x, p.y), w = p.w / QUARTER.scaleX, h = p.h / QUARTER.scaleY, reach = Math.hypot(w, h) / 2 + 2;
  for (let y = Math.floor(cy - reach); y <= cy + reach; y++) {
    for (let x = Math.floor(cx - reach); x <= cx + reach; x++) {
      const dx = x + 0.5 - cx, dy = y + 0.5 - cy;
      const lx = dx * cos + dy * sin, ly = -dx * sin + dy * cos;
      const u = lx / w + 0.5, v = ly / h + 0.5;
      if (u < 0 || u > 1 || v < 0 || v > 1) continue;
      const [red, green, blue, alpha] = img ? sample(img, l + u * (r - l), t + v * (b - t)) : [...tint, 255];
      put(x, y, [red, green, blue], alpha / 255);
    }
  }
}
// The world behind, dimmed (from the design), then the layout.
for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
  const i = (y * W + x) * 4;
  for (let c = 0; c < 3; c++) out[(y * W + x) * 3 + c] = design.rgba[i + c] * 0.25;
}
for (const p of PAGE) draw(p);
for (const p of FRAME) draw(p);
for (const p of SPINE_CAPS) draw(p);
// Turned offsets from a polaroid's centre.
const turn = (p, dx, dy) => {
  const a = (p.tilt * Math.PI) / 180;
  return { x: quarterX(p.x) + dx * Math.cos(a) - dy * Math.sin(a), y: quarterY(p.y) + dx * Math.sin(a) + dy * Math.cos(a) };
};
for (const p of POLAROIDS) {
  draw({ x: quarterX(p.x), y: quarterY(p.y), w: base.w * polaroidScale, h: base.h * polaroidScale, tilt: p.tilt, texture: "PolaroidSmall" });
  const photo = turn(p, base.photo.x * polaroidScale, base.photo.y * polaroidScale), size = base.photo.size * polaroidScale;
  draw({ ...photo, w: size, h: size, tilt: p.tilt }, null, [120, 150, 210]);
  draw({ ...point(...p.nail), w: 10 * SCALE, h: 10 * SCALE, tilt: 0, texture: "Nail" });
}
{
  const r = CARD.photo;
  draw({ ...r, tilt: 0 }, null, [200, 180, 170]);
}
const icon = (name, s) => draw({ x: s.x, y: s.y, w: s.size, h: s.size, tilt: 0 }, texture("Icons/" + name));
icon("Race_SKYBORNE", CARD.icons.race);
icon("Gender_MALE", CARD.icons.gender);
icon("Class_DRUID", CARD.icons.class);
icon("Prof_LEATHERWORKING", CARD.icons.professions[0]);
icon("Prof_SKINNING", CARD.icons.professions[1]);
icon("Prof_COOKING", CARD.icons.secondary[0]);
icon("Prof_FISHING", CARD.icons.secondary[1]);
icon("Prof_FIRSTAID", CARD.icons.secondary[2]);
draw({ ...CARD.gear, tilt: 0, texture: "Button_NORMAL" });
// Text spots as outlines.
const box = (r, colour) => {
  const [x0, y0] = toQ(r.x - r.w / 2, r.y - r.h / 2), [x1, y1] = toQ(r.x + r.w / 2, r.y + r.h / 2);
  for (let x = Math.round(x0); x <= x1; x++) { put(x, Math.round(y0), colour, 1); put(x, Math.round(y1), colour, 1); }
  for (let y = Math.round(y0); y <= y1; y++) { put(Math.round(x0), y, colour, 1); put(Math.round(x1), y, colour, 1); }
};
for (const r of [...STATS.numbers, CARD.label, CARD.signature]) box(r, [0, 255, 255]);
for (let i = 0; i < FEED.rows; i++) {
  const h = FEED.area.h / FEED.rows, r = FEED.area;
  box({ x: r.x, y: r.y - r.h / 2 + h * (i + 0.5), w: r.w, h: h - 2 }, [255, 255, 0]);
}

// Side by side: the design, then the preview (the window part of each).
const X0 = 180, X1 = W, Y0 = 80, CW = X1 - X0, CH = H - Y0, PW = CW * 2 + 10;
const raw = Buffer.alloc((PW * 3 + 1) * CH);
for (let y = 0; y < CH; y++) {
  for (let x = 0; x < CW; x++) {
    const d = ((y + Y0) * W + x + X0) * 4, p = ((y + Y0) * W + x + X0) * 3, a = design.rgba[d + 3] / 255;
    const o = y * (PW * 3 + 1) + 1;
    raw.set([0, 1, 2].map((c) => Math.round(design.rgba[d + c] * a + 40 * (1 - a))), o + x * 3);
    raw.set([out[p], out[p + 1], out[p + 2]].map((v) => Math.max(0, Math.min(255, Math.round(v)))), o + (CW + 10 + x) * 3);
  }
}
const table = Array.from({ length: 256 }, (_, n) => { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; return c >>> 0; });
const crc = (buf) => { let c = 0xffffffff; for (const b of buf) c = table[(c ^ b) & 255] ^ (c >>> 8); return (c ^ 0xffffffff) >>> 0; };
const chunk = (type, data) => {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
  const body = Buffer.concat([Buffer.from(type), data]);
  const sum = Buffer.alloc(4); sum.writeUInt32BE(crc(body));
  return Buffer.concat([len, body, sum]);
};
const header = Buffer.alloc(13); header.writeUInt32BE(PW, 0); header.writeUInt32BE(CH, 4); header[8] = 8; header[9] = 2;
fs.writeFileSync(path.join(ART, "preview.png"), Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk("IHDR", header),
  chunk("IDAT", zlib.deflateSync(raw)), chunk("IEND", Buffer.alloc(0))]));
console.log("OverviewLayout.lua and preview.png written");
