// Converts the club logo to Media/Logo.blp for the main window. The source PNG lives outside the addon, in
// %USERPROFILE%\killtracker-art-extra\sleepy-ogre-logo.png (or the file given as the first argument).
//
// The logo comes on a flat blue background but has blue in it too (banners, swirls), so only background
// connected to the image's edges is removed: a flood fill from the border through pixels close to the
// background colour. Pixels on the edge of the logo get partial transparency, so the outline stays smooth.
// Also writes logo-preview.png (on a checkerboard) next to the source, to check the cut-out.
// Usage: node tools/convert-logo.js [source.png] [--opaque]   No dependencies.

const fs = require("fs");
const os = require("os");
const path = require("path");
const zlib = require("zlib");
const { decodePng, resize, writeBlp } = require("./convert-art");

const SOURCE = process.argv.slice(2).find((a) => !a.startsWith("--")) || path.join(os.homedir(), "killtracker-art-extra", "sleepy-ogre-logo.png");
const TARGET = path.join(__dirname, "..", "Media", "Logo.blp");
const SIZE = 512;
const SOLID = 25;  // colour distance from the background below which a pixel is background (it's one flat colour)
const SOFT = 70;   // ...and below which an edge pixel is partly transparent

const image = decodePng(SOURCE);
const { width, height, rgba } = image;
// A source with its own transparency is used as it is (that cut-out is cleaner; the flood fill below only
// finds what's left of the background, normally nothing). Pass --opaque to ignore it and cut out by colour.
if (process.argv.includes("--opaque")) for (let i = 3; i < rgba.length; i += 4) rgba[i] = 255;
const at = (x, y) => (y * width + x) * 4;

// The background colour: the average of the four corners.
const corners = [at(0, 0), at(width - 1, 0), at(0, height - 1), at(width - 1, height - 1)];
const bg = [0, 1, 2].map((c) => corners.reduce((sum, i) => sum + rgba[i + c], 0) / 4);
const distance = (i) => Math.hypot(rgba[i] - bg[0], rgba[i + 1] - bg[1], rgba[i + 2] - bg[2]);

// Flood fill from the border through background-coloured pixels.
const removed = new Uint8Array(width * height);
const stack = [];
for (let x = 0; x < width; x++) stack.push(x, 0, x, height - 1);
for (let y = 0; y < height; y++) stack.push(0, y, width - 1, y);
while (stack.length) {
    const y = stack.pop(), x = stack.pop();
    if (x < 0 || y < 0 || x >= width || y >= height) continue;
    const p = y * width + x;
    if (removed[p] || distance(p * 4) >= SOLID) continue;
    removed[p] = 1;
    stack.push(x + 1, y, x - 1, y, x, y + 1, x, y - 1);
}

// Cut out: removed pixels transparent; their neighbours that are still bluish get partial alpha.
let cut = 0;
for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
        const p = y * width + x, i = p * 4;
        if (removed[p]) { rgba[i + 3] = 0; cut++; continue; }
        const touches = (x > 0 && removed[p - 1]) || (x < width - 1 && removed[p + 1])
            || (y > 0 && removed[p - width]) || (y < height - 1 && removed[p + width]);
        if (touches) {
            const d = distance(i);
            if (d < SOFT) rgba[i + 3] = Math.round(rgba[i + 3] * (d - SOLID) / (SOFT - SOLID));
        }
    }
}

const small = { rgba: resize(image, SIZE) };  // resize returns the pixels
writeBlp(TARGET, SIZE, SIZE, small.rgba);
console.log(`Removed ${Math.round(cut / (width * height) * 100)}% as background -> ${TARGET}`);

// Preview on a checkerboard (transparency shows as grey squares).
const preview = Buffer.alloc((SIZE * 3 + 1) * SIZE);
for (let y = 0; y < SIZE; y++) {
    preview[y * (SIZE * 3 + 1)] = 0;
    for (let x = 0; x < SIZE; x++) {
        const i = (y * SIZE + x) * 4, a = small.rgba[i + 3] / 255;
        const check = ((x >> 4) + (y >> 4)) % 2 ? 200 : 120;
        for (let c = 0; c < 3; c++) preview[y * (SIZE * 3 + 1) + 1 + x * 3 + c] = Math.round(small.rgba[i + c] * a + check * (1 - a));
    }
}
const crc = (buf) => { let c = ~0; for (const b of buf) { c ^= b; for (let k = 0; k < 8; k++) c = c & 1 ? (c >>> 1) ^ 0xedb88320 : c >>> 1; } return ~c >>> 0; };
const chunk = (type, data) => {
    const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
    const body = Buffer.concat([Buffer.from(type), data]);
    const sum = Buffer.alloc(4); sum.writeUInt32BE(crc(body));
    return Buffer.concat([len, body, sum]);
};
const header = Buffer.alloc(13); header.writeUInt32BE(SIZE, 0); header.writeUInt32BE(SIZE, 4); header[8] = 8; header[9] = 2;
fs.writeFileSync(path.join(path.dirname(SOURCE), "logo-preview.png"), Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]), chunk("IHDR", header),
    chunk("IDAT", zlib.deflateSync(preview)), chunk("IEND", Buffer.alloc(0))]));

// LogoMask.lua: which parts of the logo are visible, for dragging the window by the logo (UI.lua). The
// texture is cut into MASK_CELLS x MASK_CELLS cells; a cell counts if it's mostly opaque. Each row lists its
// runs of such cells as { first, last } (1-based columns), so the game needs one handle per run.
const MASK_CELLS = 21;
const cell = SIZE / MASK_CELLS;
const rows = [];
for (let r = 0; r < MASK_CELLS; r++) {
    const runs = [];
    let start = null;
    for (let c = 0; c <= MASK_CELLS; c++) {
        let opaque = false;
        if (c < MASK_CELLS) {
            let sum = 0, n = 0;
            for (let y = Math.floor(r * cell); y < Math.floor((r + 1) * cell); y++) {
                for (let x = Math.floor(c * cell); x < Math.floor((c + 1) * cell); x++) {
                    sum += small.rgba[(y * SIZE + x) * 4 + 3]; n++;
                }
            }
            opaque = sum / n > 127;
        }
        if (opaque && start === null) start = c + 1;
        if (!opaque && start !== null) { runs.push(`{ ${start}, ${c} }`); start = null; }
    }
    rows.push(`    { ${runs.join(", ")} },`);
}
fs.writeFileSync(path.join(__dirname, "..", "LogoMask.lua"),
    "-- Generated by tools/convert-logo.js - don't edit. Visible parts of Media/Logo.blp: per row (top to bottom),\n"
    + `-- runs of mostly opaque cells { first, last } in a ${MASK_CELLS} x ${MASK_CELLS} grid. See UI.lua (dragging by the logo).\n\n`
    + `local _, ns = ...\n\nns.LogoMask = { cells = ${MASK_CELLS}, rows = {\n${rows.join("\n")}\n} }\n`);
console.log("Wrote LogoMask.lua");
