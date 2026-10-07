// Draws the leader crown (Media/Crown.blp): a 32x32 crown in shades of grey with a dark outline, so the text
// escape that shows it can colour it - gold for a killed leader, grey for one still alive (UI.lua, CROWN).
// Also writes a zoomed preview, crown-preview.png, next to this script (not shipped).
// Usage: node tools/make-crown.js   No dependencies.

const fs = require("fs");
const path = require("path");
const zlib = require("zlib");
const { writeBlp } = require("./convert-art");

const SIZE = 32, SS = 4;  // supersampled 4x4 per pixel for smooth edges
// The crown's outline (x, y in pixels, y down): three points with a ball on each, over a band.
const BODY = [[4, 26], [4, 11], [10, 17], [16, 7], [22, 17], [28, 11], [28, 26]];
const BALLS = [[4.5, 8.5, 3.3], [16, 4.5, 3.5], [27.5, 8.5, 3.3]];
const BAND = [17.5, 26];  // the band's top and bottom


function inPolygon(x, y, poly) {
    let inside = false;
    for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) {
        const [xi, yi] = poly[i], [xj, yj] = poly[j];
        if ((yi > y) !== (yj > y) && x < ((xj - xi) * (y - yi)) / (yj - yi) + xi) inside = !inside;
    }
    return inside;
}
const inCircle = (x, y, [cx, cy, r]) => (x - cx) ** 2 + (y - cy) ** 2 <= r * r;
const inCrown = (x, y) => inPolygon(x, y, BODY) || BALLS.some((b) => inCircle(x, y, b));

// The shade of the crown at a point (0..255): kept simple so it reads at 16px - a flat fill, the band a
// step darker.
function shade(x, y) {
    return y >= BAND[0] && !BALLS.some((b) => inCircle(x, y, b)) ? 200 : 250;
}

const rgba = Buffer.alloc(SIZE * SIZE * 4);
for (let py = 0; py < SIZE; py++) {
    for (let px = 0; px < SIZE; px++) {
        let fill = 0, edge = 0, sum = 0;
        for (let sy = 0; sy < SS; sy++) {
            for (let sx = 0; sx < SS; sx++) {
                const x = px + (sx + 0.5) / SS, y = py + (sy + 0.5) / SS;
                if (inCrown(x, y)) {
                    // Within 1.6px of the outside: the dark outline (a texture pixel is half a screen pixel at 16px).
                    let near = false;
                    for (const [dx, dy] of [[-1.6, 0], [1.6, 0], [0, -1.6], [0, 1.6], [-1.1, -1.1], [1.1, 1.1], [-1.1, 1.1], [1.1, -1.1]]) {
                        if (!inCrown(x + dx, y + dy)) near = true;
                    }
                    if (near) edge++; else { fill++; sum += shade(x, y); }
                }
            }
        }
        const n = SS * SS, covered = fill + edge;
        if (!covered) continue;
        const v = Math.round((sum + edge * 35) / covered);
        const i = (py * SIZE + px) * 4;
        rgba[i] = rgba[i + 1] = rgba[i + 2] = v;
        rgba[i + 3] = Math.round((covered / n) * 255);
    }
}
writeBlp(path.join(__dirname, "..", "Media", "Crown.blp"), SIZE, SIZE, Buffer.from(rgba));

// Preview: gold and grey side by side, 8x, on the list's dark red.
const S = 8, W = SIZE * 2 * S + S * 4, H = SIZE * S;
const raw = Buffer.alloc((W * 3 + 1) * H);
const tints = [[1, 0.8, 0.24], [0.55, 0.55, 0.55]];
for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
        const o = y * (W * 3 + 1) + 1 + x * 3;
        let c = [90, 20, 25];
        const which = x < SIZE * S ? 0 : x >= SIZE * S + S * 4 ? 1 : -1;
        if (which >= 0) {
            const lx = Math.floor((x - which * (SIZE * S + S * 4)) / S), ly = Math.floor(y / S);
            const i = (ly * SIZE + lx) * 4, a = rgba[i + 3] / 255;
            c = c.map((bg, k) => Math.round(rgba[i] * tints[which][k] * a + bg * (1 - a)));
        }
        raw[o] = c[0]; raw[o + 1] = c[1]; raw[o + 2] = c[2];
    }
}
const crcTable = Array.from({ length: 256 }, (_, n) => { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; return c >>> 0; });
const crc = (b) => { let c = 0xffffffff; for (const v of b) c = crcTable[(c ^ v) & 255] ^ (c >>> 8); return (c ^ 0xffffffff) >>> 0; };
const chunk = (type, data) => { const l = Buffer.alloc(4); l.writeUInt32BE(data.length); const td = Buffer.concat([Buffer.from(type), data]); const c = Buffer.alloc(4); c.writeUInt32BE(crc(td)); return Buffer.concat([l, td, c]); };
const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(W, 0); ihdr.writeUInt32BE(H, 4); ihdr[8] = 8; ihdr[9] = 2;
fs.writeFileSync(path.join(__dirname, "crown-preview.png"), Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk("IHDR", ihdr), chunk("IDAT", zlib.deflateSync(raw)), chunk("IEND", Buffer.alloc(0))]));
console.log("Wrote Media/Crown.blp and tools/crown-preview.png");
