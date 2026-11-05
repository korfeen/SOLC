// The Collection's open book (PixCollection.lua): the Dream Bed's red storybook (DreamBed\pieces\book.png) opened flat,
// two blank parchment pages, painted by Codex in the ogre pictures' style. Its pages are found in the painting (the
// cream parchment) and the picture placed so they land on the Collection's two pages (PAGES: window pixels).
//   node tools/gen-collection-book.js            paint it (one Codex image), then place it
//   node tools/gen-collection-book.js --place    place the painting made already (raw.png) again
// Out: killtracker-art-extra\Collection\ (raw.png, check.png: the pages found outlined), Media\Collection\book.blp and
// CollectionBookArt.lua (where to draw it).
const fs = require("fs");
const os = require("os");
const path = require("path");
const { generate } = require("./gen-art");
const { decodePng, resample, writeBlp } = require("./convert-art");
const { writePng } = require("./make-role-icons");

const EXTRA = path.join(os.homedir(), "killtracker-art-extra");
const ART = path.join(os.homedir(), "killtracker-art");
const WORK = path.join(EXTRA, "Collection");
const MEDIA = path.join(__dirname, "..", "Media", "Collection");
// The Collection's two pages (PixCollection.lua's panels), window pixels: the book's pages go there.
const PAGES = { left: { x: 236, y: 146, w: 398, h: 584 }, right: { x: 674, y: 146, w: 390, h: 584 } };

const PROMPT = `Paint an OPEN book lying flat, seen straight from above, as a wide landscape picture.
It is the SAME red leather book as the first reference image (red leather, gold metal corner pieces, a gold star on its
cover), now opened out flat: two large BLANK cream parchment pages side by side, a soft shadowed fold down the exact
middle where the pages meet, the red leather cover showing as a narrow border all round the pages with the gold corner
pieces at the four outer corners, and the red ribbon bookmark lying across the bottom of the right page.
The pages must lie PERFECTLY FLAT, like a book pressed open on a scanner: no curl, no bulge, no waves, no shading
across them, evenly lit from edge to edge, the fold in the middle only a thin soft shadow line. (Things are drawn on
these pages afterwards, so they must be flat and plain.)
The pages must be completely EMPTY: no writing, no pictures, no lines, no stains - plain warm parchment with a faint
paper texture and slightly darker edges. The book fills almost the whole picture, centred, straight (not tilted), with a
little dark wooden table showing round it. Even, soft, warm lighting.
Paint it in the soft painterly style of the other reference images (the ogre pictures' style), not photographic.`;

// The parchment: warm and light.
const isPage = (r, g, b) => r > 225 && g > 175 && b > 90;
function PageBox(img, x0, x1) {
  // its columns: parchment through the middle band of rows; its rows: parchment through the middle band of its columns
  const y0 = Math.floor(img.height * 0.3), y1 = Math.floor(img.height * 0.7);
  const mx0 = Math.floor(x0 + (x1 - x0) * 0.3), mx1 = Math.floor(x0 + (x1 - x0) * 0.7);
  const page = (x, y) => { const i = (y * img.width + x) * 4; return isPage(img.rgba[i], img.rgba[i + 1], img.rgba[i + 2]); };
  const cols = [], rows = [];
  for (let x = x0; x < x1; x++) { let n = 0; for (let y = y0; y < y1; y++) if (page(x, y)) n++; cols.push(n / (y1 - y0)); }
  for (let y = 0; y < img.height; y++) { let n = 0; for (let x = mx0; x < mx1; x++) if (page(x, y)) n++; rows.push(n / (mx1 - mx0)); }
  const first = (a, t) => a.findIndex((v) => v > t), last = (a, t) => a.length - 1 - [...a].reverse().findIndex((v) => v > t);
  return { x: x0 + first(cols, 0.85), x2: x0 + last(cols, 0.85), y: first(rows, 0.85), y2: last(rows, 0.85) };
}

function Place(raw) {
  const img = decodePng(raw);
  const mid = Math.floor(img.width / 2);
  const L = PageBox(img, 0, mid), R = PageBox(img, mid, img.width);
  // (a check: the pages found, outlined)
  const check = Buffer.from(img.rgba);
  for (const b of [L, R]) for (let x = b.x; x <= b.x2; x++) for (const y of [b.y, b.y2]) { const i = (y * img.width + x) * 4; check[i] = 255; check[i + 1] = 0; check[i + 2] = 255; }
  for (const b of [L, R]) for (let y = b.y; y <= b.y2; y++) for (const x of [b.x, b.x2]) { const i = (y * img.width + x) * 4; check[i] = 255; check[i + 1] = 0; check[i + 2] = 255; }
  writePng(path.join(WORK, "check.png"), img.width, img.height, check);
  // The painting's scale and place: its left page's left edge and the right page's right edge on the panels' outer
  // edges; the pages' top and bottom on theirs.
  const sx = (PAGES.right.x + PAGES.right.w - PAGES.left.x) / (R.x2 - L.x);
  const top = Math.min(L.y, R.y), bottom = Math.max(L.y2, R.y2);
  const sy = PAGES.left.h / (bottom - top);
  const place = { x: Math.round(PAGES.left.x - L.x * sx), y: Math.round(PAGES.left.y - top * sy),
    w: Math.round(img.width * sx), h: Math.round(img.height * sy) };
  fs.mkdirSync(MEDIA, { recursive: true });
  writeBlp(path.join(MEDIA, "book.blp"), 1024, 1024, Buffer.from(resample(img, 0, 0, img.width, img.height, 1024, 1024)));
  fs.writeFileSync(path.join(__dirname, "..", "CollectionBookArt.lua"),
    "-- The Collection's open book (tools/gen-collection-book.js - don't edit): where its picture goes, window pixels.\n" +
    "local _, ns = ...\n" +
    `ns.CollectionBookArt = { x = ${place.x}, y = ${place.y}, w = ${place.w}, h = ${place.h} }\n`);
  console.log("Pages found: left", L, "right", R, "-> drawn at", place);
}

fs.mkdirSync(WORK, { recursive: true });
const raw = path.join(WORK, "raw.png");
if (!process.argv.includes("--place")) {
  const work = path.join(WORK, "work");
  fs.mkdirSync(work, { recursive: true });
  const refs = [path.join(EXTRA, "DreamBed", "pieces", "book.png"), path.join(ART, "Background", "Uncommon", "clubhouse-lounge.png"),
    path.join(ART, "Background", "Uncommon", "spa-steam-room.png")];
  const made = generate(work, refs, PROMPT, "open-book.png", "landscape, 3:2");
  fs.copyFileSync(made, raw);
}
Place(raw);
