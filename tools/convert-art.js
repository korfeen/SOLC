// Converts the collectible layer art to WoW textures and writes MintArt.lua, the list of every layer
// option the minting rolls from. The source art lives outside the addon (it isn't needed in game), in
// %USERPROFILE%\killtracker-art or the folder in the KILLTRACKER_ART environment variable, laid out as:
//
//   <Layer>/<Rarity>/<option>.png           e.g. Headwear/Rare/tiny-top-hat.png
//   <Layer>/<Rarity>/<skin>/<option>.png    drawn once per skin colour, e.g. Eyes/Rare/moss/bloodshot.png;
//                                            the game picks the file matching the picture's rolled skin
//
// Every PNG is the same square canvas with transparency, so layers line up when stacked. Each option is
// cropped to the area it actually covers (a hat is a small texture placed where it belongs), sampled at
// DENSITY pixels per full picture, and padded to power-of-two sizes as WoW needs. The textures are BLP
// files, WoW's own compressed format: DXT1 for fully opaque art, DXT5 for art with transparency, with
// mipmaps. Option ids come from the file names (tiny-top-hat -> tiny_top_hat) and are saved in minted
// pictures, so never rename a file after release. Media/Collectible is rebuilt from scratch each run.
// The editions (EDITIONS): every option's twin in another style, the same file under its folder in
// %USERPROFILE%\killtracker-art-extra, is converted the same way into its Media folder, cropped to its own visible
// part; MintArt.lua gives such an option <edition> (texture) and <edition>Rect. Crayon: hand-drawn
// (tools/make-crayon-*.js); sketch: the paintings through a crayon filter (tools/crayonize-art.js). A picture's
// layers show in an edition once unlocked (Minting.lua).
// Usage: node tools/convert-art.js [density]   (default 512). No dependencies.

const fs = require("fs");
const os = require("os");
const path = require("path");
const zlib = require("zlib");

const DENSITY = Number(process.argv[2]) || 512;
const SOURCE = process.env.KILLTRACKER_ART || path.join(os.homedir(), "killtracker-art");
const TARGET = path.join(__dirname, "..", "Media", "Collectible");
const LUA_FILE = path.join(__dirname, "..", "MintArt.lua");
const EDITIONS = [
    { key: "crayon", source: path.join(os.homedir(), "killtracker-art-extra", "CrayonHand"), folder: "Crayon" },
    { key: "sketch", source: path.join(os.homedir(), "killtracker-art-extra", "CrayonArt"), folder: "Sketch" },
];
for (const edition of EDITIONS) edition.target = path.join(__dirname, "..", "Media", edition.folder);
const RARITIES = ["uncommon", "rare", "epic", "legendary"];  // no common: uncommon is the everyday tier
const SKIN_LAYER = "skin";  // per-skin options are drawn once per option of this layer

if (require.main === module && (DENSITY & (DENSITY - 1))) throw new Error("Density must be a power of two, e.g. 256 or 512");

// Decodes an 8-bit PNG (RGBA, RGB, grey, grey+alpha or palette) into { width, height, rgba }.
function decodePng(file) {
    const buf = fs.readFileSync(file);
    if (buf.readUInt32BE(0) !== 0x89504e47) throw new Error(file + " is not a PNG");
    let pos = 8, width, height, depth, colorType, palette, alpha;
    const idat = [];
    while (pos < buf.length) {
        const length = buf.readUInt32BE(pos);
        const type = buf.toString("ascii", pos + 4, pos + 8);
        const data = buf.subarray(pos + 8, pos + 8 + length);
        if (type === "IHDR") {
            width = data.readUInt32BE(0); height = data.readUInt32BE(4);
            depth = data[8]; colorType = data[9];
            if (data[12]) throw new Error(file + ": interlaced PNGs aren't supported, save without interlacing");
        } else if (type === "PLTE") palette = data;
        else if (type === "tRNS") alpha = data;
        else if (type === "IDAT") idat.push(data);
        else if (type === "IEND") break;
        pos += 12 + length;
    }
    if (depth !== 8) throw new Error(file + ": only 8 bits per channel is supported");
    const channels = { 0: 1, 2: 3, 3: 1, 4: 2, 6: 4 }[colorType];
    const raw = zlib.inflateSync(Buffer.concat(idat));
    const stride = width * channels;
    const pixels = Buffer.alloc(height * stride);
    for (let y = 0; y < height; y++) {
        const filter = raw[y * (stride + 1)];
        for (let x = 0; x < stride; x++) {
            const v = raw[y * (stride + 1) + 1 + x];
            const a = x >= channels ? pixels[y * stride + x - channels] : 0;
            const b = y > 0 ? pixels[(y - 1) * stride + x] : 0;
            const c = x >= channels && y > 0 ? pixels[(y - 1) * stride + x - channels] : 0;
            let p = v;
            if (filter === 1) p = v + a;
            else if (filter === 2) p = v + b;
            else if (filter === 3) p = v + ((a + b) >> 1);
            else if (filter === 4) {
                const pa = Math.abs(b - c), pb = Math.abs(a - c), pc = Math.abs(a + b - 2 * c);
                p = v + (pa <= pb && pa <= pc ? a : pb <= pc ? b : c);
            }
            pixels[y * stride + x] = p & 255;
        }
    }
    const rgba = Buffer.alloc(width * height * 4);
    for (let i = 0; i < width * height; i++) {
        const s = i * channels, d = i * 4;
        if (colorType === 6) pixels.copy(rgba, d, s, s + 4);
        else if (colorType === 2) { pixels.copy(rgba, d, s, s + 3); rgba[d + 3] = 255; }
        else if (colorType === 0) { rgba.fill(pixels[s], d, d + 3); rgba[d + 3] = 255; }
        else if (colorType === 4) { rgba.fill(pixels[s], d, d + 3); rgba[d + 3] = pixels[s + 1]; }
        else if (colorType === 3) {
            const index = pixels[s];
            palette.copy(rgba, d, index * 3, index * 3 + 3);
            rgba[d + 3] = alpha && index < alpha.length ? alpha[index] : 255;
        }
    }
    return { width, height, rgba };
}

// Area-average resample of the region (sx, sy, sw, sh) of image to outW x outH (smooth, no jagged
// edges); colours are weighted by alpha so transparent pixels don't darken the edges.
function resample(image, sx, sy, sw, sh, outW, outH) {
    const { width, rgba } = image;
    const out = Buffer.alloc(outW * outH * 4);
    const fx = sw / outW, fy = sh / outH;
    for (let y = 0; y < outH; y++) {
        const y0 = sy + y * fy, y1 = y0 + fy;
        for (let x = 0; x < outW; x++) {
            const x0 = sx + x * fx, x1 = x0 + fx;
            let r = 0, g = 0, b = 0, a = 0, weight = 0;
            for (let py = Math.floor(y0); py < Math.ceil(y1); py++) {
                const wy = Math.min(y1, py + 1) - Math.max(y0, py);
                for (let px = Math.floor(x0); px < Math.ceil(x1); px++) {
                    const w = wy * (Math.min(x1, px + 1) - Math.max(x0, px));
                    const i = (py * width + px) * 4;
                    const pa = rgba[i + 3] / 255;
                    r += rgba[i] * pa * w; g += rgba[i + 1] * pa * w; b += rgba[i + 2] * pa * w;
                    a += pa * w; weight += w;
                }
            }
            const o = (y * outW + x) * 4;
            out[o] = a ? Math.round(r / a) : 0;
            out[o + 1] = a ? Math.round(g / a) : 0;
            out[o + 2] = a ? Math.round(b / a) : 0;
            out[o + 3] = Math.round((a / weight) * 255);
        }
    }
    return out;
}

// Whole image to size x size.
function resize(image, size) {
    return resample(image, 0, 0, image.width, image.height, size, size);
}

// Fully transparent pixels get the colour of their nearest visible neighbours, so texture filtering and
// compression don't pull a dark fringe in around the edges of the art. Changes rgba in place.
function bleedEdges(rgba, width, height) {
    let filled = new Uint8Array(width * height);
    for (let i = 0; i < width * height; i++) filled[i] = rgba[i * 4 + 3] > 0 ? 1 : 0;
    for (let pass = 0; pass < 16; pass++) {
        const next = filled.slice();
        let changed = 0;
        for (let y = 0; y < height; y++) {
            for (let x = 0; x < width; x++) {
                const i = y * width + x;
                if (filled[i]) continue;
                let r = 0, g = 0, b = 0, n = 0;
                for (const [dx, dy] of [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
                    const nx = x + dx, ny = y + dy;
                    if (nx < 0 || ny < 0 || nx >= width || ny >= height || !filled[ny * width + nx]) continue;
                    const j = (ny * width + nx) * 4;
                    r += rgba[j]; g += rgba[j + 1]; b += rgba[j + 2]; n++;
                }
                if (n) {
                    rgba[i * 4] = r / n; rgba[i * 4 + 1] = g / n; rgba[i * 4 + 2] = b / n;
                    next[i] = 1;
                    changed++;
                }
            }
        }
        filled = next;
        if (!changed) break;
    }
    return rgba;
}

// DXT (BC1/BC3) compression -------------------------------------------------------------------------

const CHANNEL_WEIGHT = [0.299, 0.587, 0.114];  // the eye is most sensitive to green, least to blue

const to565 = (c) => (Math.round(c[0] * 31 / 255) << 11) | (Math.round(c[1] * 63 / 255) << 5) | Math.round(c[2] * 31 / 255);
function from565(v) {
    const r = (v >> 11) & 31, g = (v >> 5) & 63, b = v & 31;
    return [(r << 3) | (r >> 2), (g << 2) | (g >> 4), (b << 3) | (b >> 2)];
}
const colorError = (a, b) => CHANNEL_WEIGHT[0] * (a[0] - b[0]) ** 2 + CHANNEL_WEIGHT[1] * (a[1] - b[1]) ** 2 + CHANNEL_WEIGHT[2] * (a[2] - b[2]) ** 2;
const mix = (a, b, t) => [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t];
const clamp255 = (c) => c.map((v) => Math.min(255, Math.max(0, v)));
// The four colours of a block, as decoders compute them from its two endpoints.
const PALETTE_T = [0, 1, 1 / 3, 2 / 3];
const palette4 = (c0, c1) => PALETTE_T.map((t) => mix(c0, c1, t));

// Colour half of a block (8 bytes): two 5:6:5 endpoints on the main axis of the pixels' colours,
// refined by least squares, and a 2-bit palette index per pixel. weights: how much each pixel matters.
function encodeColorBlock(pixels, weights, out, o) {
    let total = 0;
    const mean = [0, 0, 0];
    for (let i = 0; i < 16; i++) {
        total += weights[i];
        for (let c = 0; c < 3; c++) mean[c] += pixels[i][c] * weights[i];
    }
    for (let c = 0; c < 3; c++) mean[c] /= total;
    const cov = [[0, 0, 0], [0, 0, 0], [0, 0, 0]];
    for (let i = 0; i < 16; i++) {
        const d = [0, 1, 2].map((c) => pixels[i][c] - mean[c]);
        for (let a = 0; a < 3; a++) for (let b = 0; b < 3; b++) cov[a][b] += d[a] * d[b] * weights[i];
    }
    let axis = [1, 1, 1];
    for (let iter = 0; iter < 8; iter++) {
        const next = [0, 1, 2].map((a) => cov[a][0] * axis[0] + cov[a][1] * axis[1] + cov[a][2] * axis[2]);
        const len = Math.hypot(...next);
        if (len < 1e-9) break;
        axis = next.map((v) => v / len);
    }
    let lo = Infinity, hi = -Infinity;
    for (let i = 0; i < 16; i++) {
        if (weights[i] <= 0) continue;
        const t = (pixels[i][0] - mean[0]) * axis[0] + (pixels[i][1] - mean[1]) * axis[1] + (pixels[i][2] - mean[2]) * axis[2];
        lo = Math.min(lo, t); hi = Math.max(hi, t);
    }
    let e0 = clamp255(mean.map((m, c) => m + axis[c] * hi));
    let e1 = clamp255(mean.map((m, c) => m + axis[c] * lo));
    // Least squares: with each pixel's palette slot fixed, the endpoints that fit the pixels best.
    for (let iter = 0; iter < 2; iter++) {
        const pal = palette4(e0, e1);
        let aa = 0, ab = 0, bb = 0;
        const ax = [0, 0, 0], bx = [0, 0, 0];
        for (let i = 0; i < 16; i++) {
            let best = 0, bestErr = Infinity;
            for (let k = 0; k < 4; k++) {
                const err = colorError(pixels[i], pal[k]);
                if (err < bestErr) { bestErr = err; best = k; }
            }
            const t = PALETTE_T[best], a = 1 - t, b = t, w = weights[i];
            aa += a * a * w; ab += a * b * w; bb += b * b * w;
            for (let c = 0; c < 3; c++) { ax[c] += a * pixels[i][c] * w; bx[c] += b * pixels[i][c] * w; }
        }
        const det = aa * bb - ab * ab;
        if (Math.abs(det) < 1e-6) break;
        e0 = clamp255([0, 1, 2].map((c) => (ax[c] * bb - bx[c] * ab) / det));
        e1 = clamp255([0, 1, 2].map((c) => (bx[c] * aa - ax[c] * ab) / det));
    }
    let c0 = to565(e0), c1 = to565(e1);
    if (c0 < c1) [c0, c1] = [c1, c0];  // c0 > c1 selects the four-colour mode
    let indices = 0;
    if (c0 !== c1) {
        const pal = palette4(from565(c0), from565(c1));
        for (let i = 15; i >= 0; i--) {
            let best = 0, bestErr = Infinity;
            for (let k = 0; k < 4; k++) {
                const err = colorError(pixels[i], pal[k]);
                if (err < bestErr) { bestErr = err; best = k; }
            }
            indices = (indices << 2) | best;
        }
    }
    out.writeUInt16LE(c0, o);
    out.writeUInt16LE(c1, o + 2);
    out.writeUInt32LE(indices >>> 0, o + 4);
}

// The alpha values of a BC3 block, as decoders compute them from its two endpoints.
function alphaPalette(a0, a1) {
    if (a0 > a1) return [a0, a1, ...[1, 2, 3, 4, 5, 6].map((k) => ((7 - k) * a0 + k * a1) / 7)];
    return [a0, a1, ...[1, 2, 3, 4].map((k) => ((5 - k) * a0 + k * a1) / 5), 0, 255];
}

// Alpha half of a BC3 block (8 bytes): tries the 8-step ramp and the 6-step ramp with exact 0 and 255
// (good for edges), keeping whichever fits better.
function encodeAlphaBlock(alphas, out, o) {
    const lo = Math.min(...alphas), hi = Math.max(...alphas);
    const inner = alphas.filter((a) => a > 0 && a < 255);
    const candidates = [[hi, lo]];
    if (inner.length) candidates.push([Math.min(...inner), Math.max(...inner)]);
    else candidates.push([0, 0]);
    let best;
    for (const [a0, a1] of candidates) {
        const pal = alphaPalette(a0, a1);
        let err = 0;
        const idx = alphas.map((a) => {
            let k = 0;
            for (let j = 1; j < 8; j++) if (Math.abs(pal[j] - a) < Math.abs(pal[k] - a)) k = j;
            err += (pal[k] - a) ** 2;
            return k;
        });
        if (!best || err < best.err) best = { a0, a1, idx, err };
    }
    out[o] = best.a0;
    out[o + 1] = best.a1;
    for (let half = 0; half < 2; half++) {
        let bits = 0;
        for (let i = 7; i >= 0; i--) bits = bits * 8 + best.idx[half * 8 + i];
        out[o + 2 + half * 3] = bits & 255;
        out[o + 3 + half * 3] = (bits >> 8) & 255;
        out[o + 4 + half * 3] = (bits >> 16) & 255;
    }
}

// One mip level to BC1 (8 bytes per 4x4 block) or BC3 (16 bytes: alpha, then colour).
function compressDxt(rgba, width, height, withAlpha) {
    const bw = Math.ceil(width / 4), bh = Math.ceil(height / 4), blockBytes = withAlpha ? 16 : 8;
    const out = Buffer.alloc(bw * bh * blockBytes);
    const pixels = Array.from({ length: 16 }, () => [0, 0, 0]), weights = new Array(16), alphas = new Array(16);
    for (let by = 0; by < bh; by++) {
        for (let bx = 0; bx < bw; bx++) {
            for (let i = 0; i < 16; i++) {
                const x = Math.min(bx * 4 + (i & 3), width - 1), y = Math.min(by * 4 + (i >> 2), height - 1);
                const p = (y * width + x) * 4;
                pixels[i][0] = rgba[p]; pixels[i][1] = rgba[p + 1]; pixels[i][2] = rgba[p + 2];
                alphas[i] = rgba[p + 3];
                weights[i] = withAlpha ? 0.02 + rgba[p + 3] / 255 : 1;  // see-through pixels matter less
            }
            const o = (by * bw + bx) * blockBytes;
            if (withAlpha) encodeAlphaBlock(alphas, out, o);
            encodeColorBlock(pixels, weights, out, withAlpha ? o + 8 : o);
        }
    }
    return out;
}

// BLP2 texture with DXT compression and a full mip chain. Fully opaque art uses DXT1, else DXT5.
const BLP_HEADER_SIZE = 1172;
function writeBlp(file, width, height, rgba) {
    let opaque = true;
    for (let i = 3; i < rgba.length; i += 4) if (rgba[i] !== 255) { opaque = false; break; }
    const levels = [];
    let image = { width, height, rgba: bleedEdges(Buffer.from(rgba), width, height) };
    for (;;) {
        levels.push(compressDxt(image.rgba, image.width, image.height, !opaque));
        if ((image.width === 1 && image.height === 1) || levels.length === 16) break;
        const w = Math.max(1, image.width >> 1), h = Math.max(1, image.height >> 1);
        image = { width: w, height: h, rgba: bleedEdges(resample(image, 0, 0, image.width, image.height, w, h), w, h) };
    }
    const header = Buffer.alloc(BLP_HEADER_SIZE);
    header.write("BLP2", 0, "ascii");
    header.writeUInt32LE(1, 4);       // BLP (not JPEG) content
    header[8] = 2;                    // DXT
    header[9] = opaque ? 0 : 8;       // alpha bits
    header[10] = opaque ? 0 : 7;      // DXT1 / DXT5
    header[11] = 1;                   // has mipmaps
    header.writeUInt32LE(width, 12);
    header.writeUInt32LE(height, 16);
    let offset = BLP_HEADER_SIZE;
    levels.forEach((level, i) => {
        header.writeUInt32LE(offset, 20 + i * 4);
        header.writeUInt32LE(level.length, 84 + i * 4);
        offset += level.length;
    });
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, Buffer.concat([header, ...levels]));
}

// Reads the top mip level of a DXT BLP back to { width, height, rgba } (for previews and checks).
function readBlp(file) {
    const buf = fs.readFileSync(file);
    if (buf.toString("ascii", 0, 4) !== "BLP2" || buf[8] !== 2) throw new Error(file + " isn't a DXT BLP2 texture");
    const width = buf.readUInt32LE(12), height = buf.readUInt32LE(16), withAlpha = buf[10] === 7;
    const data = buf.subarray(buf.readUInt32LE(20));
    const rgba = Buffer.alloc(width * height * 4);
    const bw = Math.ceil(width / 4), blockBytes = withAlpha ? 16 : 8;
    for (let block = 0; block < bw * Math.ceil(height / 4); block++) {
        const o = block * blockBytes, co = withAlpha ? o + 8 : o;
        const pal = palette4(from565(data.readUInt16LE(co)), from565(data.readUInt16LE(co + 2)));
        const colorBits = data.readUInt32LE(co + 4);
        const apal = withAlpha ? alphaPalette(data[o], data[o + 1]) : null;
        const alphaBits = withAlpha ? [data.readUIntLE(o + 2, 3), data.readUIntLE(o + 5, 3)] : null;
        for (let i = 0; i < 16; i++) {
            const x = (block % bw) * 4 + (i & 3), y = Math.floor(block / bw) * 4 + (i >> 2);
            if (x >= width || y >= height) continue;
            const c = pal[(colorBits >>> (i * 2)) & 3], p = (y * width + x) * 4;
            rgba[p] = c[0]; rgba[p + 1] = c[1]; rgba[p + 2] = c[2];
            rgba[p + 3] = withAlpha ? apal[(alphaBits[i >> 3] >> ((i & 7) * 3)) & 7] : 255;
        }
    }
    return { width, height, rgba };
}

module.exports = { SOURCE, decodePng, resize, resample, writeBlp, readBlp, bleedEdges };
if (require.main !== module) return;  // used as a library (the chain companion's renderer)

const toId = (name) => name.toLowerCase().replace(/\.png$/, "").replace(/[^a-z0-9]+/g, "_").replace(/^_|_$/g, "");
const SMALL_WORDS = new Set(["a", "an", "and", "at", "between", "in", "of", "on", "over", "the", "to", "with"]);
const toName = (name) => name.replace(/\.png$/i, "").split(/[-_ ]+/)
    .map((w, i) => (i > 0 && SMALL_WORDS.has(w) ? w : w.charAt(0).toUpperCase() + w.slice(1))).join(" ");
const nextPow2 = (n) => 2 ** Math.ceil(Math.log2(Math.max(n, 1)));
const subdirs = (dir) => fs.readdirSync(dir).filter((f) => fs.statSync(path.join(dir, f)).isDirectory());
const pngs = (dir) => fs.readdirSync(dir).filter((f) => /\.png$/i.test(f));

// Bounding box of the visible pixels: { x0, y0, x1, y1 } (x1/y1 exclusive), or null if fully transparent.
function visibleBox(image) {
    let x0 = image.width, y0 = image.height, x1 = 0, y1 = 0;
    for (let y = 0; y < image.height; y++) {
        for (let x = 0; x < image.width; x++) {
            if (image.rgba[(y * image.width + x) * 4 + 3] > 2) {
                if (x < x0) x0 = x;
                if (x >= x1) x1 = x + 1;
                if (y < y0) y0 = y;
                if (y >= y1) y1 = y + 1;
            }
        }
    }
    return x1 > x0 ? { x0, y0, x1, y1 } : null;
}

// One axis of the crop: a power-of-two texture size and the source span it covers, centred on the
// visible part and kept inside the canvas. The whole canvas when the art needs that much anyway.
function cropAxis(from, to, canvas) {
    const scale = DENSITY / canvas;
    const pad = Math.ceil(canvas / DENSITY) * 2;  // a couple of texture pixels around the edges
    const pixels = nextPow2(Math.ceil((to - from + pad * 2) * scale));
    if (pixels >= DENSITY) return { start: 0, span: canvas, pixels: DENSITY };
    const span = pixels / scale;
    const start = Math.min(Math.max((from + to) / 2 - span / 2, 0), canvas - span);
    return { start, span, pixels };
}

if (!fs.existsSync(SOURCE)) {
    console.log("Put your layer art in " + SOURCE + "\\<Layer>\\<Rarity>\\<option>.png first.");
    process.exit(1);
}

// Collect every option: { layer, folder, id, name, rarity, files: [{ skin, file }] }.
const layers = {};
for (const folder of subdirs(SOURCE)) {
    const key = toId(folder);
    const options = new Map();
    for (const rarityFolder of subdirs(path.join(SOURCE, folder))) {
        const rarity = rarityFolder.toLowerCase();
        if (!RARITIES.includes(rarity)) {
            console.log(`Skipping ${folder}/${rarityFolder}: not a rarity (${RARITIES.join(", ")})`);
            continue;
        }
        const add = (file, skin) => {
            const base = path.basename(file);
            const id = toId(base);
            const option = options.get(id) || { id, name: toName(base), rarity, files: [] };
            if (option.rarity !== rarity) throw new Error(`${folder}/${base} is in both ${option.rarity} and ${rarity}`);
            option.files.push({ skin, file });
            options.set(id, option);
        };
        const dir = path.join(SOURCE, folder, rarityFolder);
        for (const file of pngs(dir)) add(path.join(dir, file), null);
        for (const skinFolder of subdirs(dir)) {
            for (const file of pngs(path.join(dir, skinFolder))) add(path.join(dir, skinFolder, file), toId(skinFolder));
        }
    }
    if (options.size) layers[key] = { key, folder, options: [...options.values()] };
}

// Sanity checks: per-skin options need a file for every skin, and nothing else.
const skins = (layers[SKIN_LAYER] ? layers[SKIN_LAYER].options : []).map((o) => o.id);
let problems = 0;
for (const layer of Object.values(layers)) {
    for (const option of layer.options) {
        const perSkin = option.files.some((f) => f.skin);
        if (!perSkin) continue;
        if (option.files.some((f) => !f.skin)) {
            console.log(`Problem: ${layer.folder}/${option.id} has both a plain file and per-skin files`);
            problems++;
        }
        for (const skin of skins) {
            if (!option.files.some((f) => f.skin === skin)) {
                console.log(`Problem: ${layer.folder}/${option.id} has no version for skin "${skin}"`);
                problems++;
            }
        }
        for (const f of option.files) {
            if (f.skin && !skins.includes(f.skin)) {
                console.log(`Problem: ${layer.folder}/${option.id} has a version for unknown skin "${f.skin}"`);
                problems++;
            }
        }
    }
}
if (problems) {
    console.log(`${problems} problem(s), nothing converted.`);
    process.exit(1);
}

// Converts one option's images (per-skin versions share one crop, so the option has a single rect) into target.
// Returns { rect, full, pixels }.
function convertOption(layer, option, images, target) {
        const canvas = images[0].image.width;
        let box = null;
        for (const { file, image } of images) {
            if (image.width !== canvas || image.height !== canvas) {
                throw new Error(`${file} is ${image.width}x${image.height}, every layer must be ${canvas}x${canvas}`);
            }
            const b = visibleBox(image);
            if (b) box = box ? { x0: Math.min(box.x0, b.x0), y0: Math.min(box.y0, b.y0), x1: Math.max(box.x1, b.x1), y1: Math.max(box.y1, b.y1) } : b;
        }
        box = box || { x0: 0, y0: 0, x1: canvas, y1: canvas };
        const cx = cropAxis(box.x0, box.x1, canvas), cy = cropAxis(box.y0, box.y1, canvas);
        for (const { skin, image } of images) {
            const out = path.join(target, layer.folder, ...(skin ? [skin] : []), option.id + ".blp");
            writeBlp(out, cx.pixels, cy.pixels, resample(image, cx.start, cy.start, cx.span, cy.span, cx.pixels, cy.pixels));
            bytes += fs.statSync(out).size;
            count++;
        }
        return { full: cx.span === canvas && cy.span === canvas, rect: [cx.start / canvas, cy.start / canvas, cx.span / canvas, cy.span / canvas],
            pixels: `${cx.pixels}x${cy.pixels}` };
}

// New paintings first get their sketch twin (tools/crayonize-art.js, only for files without one), and the ones
// still without a crayon twin are listed (those are drawn by hand: tools/make-crayon-*.js).
{
    const sketch = EDITIONS.find((e) => e.key === "sketch"), crayon = EDITIONS.find((e) => e.key === "crayon");
    const files = Object.values(layers).flatMap((layer) => layer.options.flatMap((o) => o.files.map((f) => path.relative(SOURCE, f.file))));
    for (const rel of files.filter((f) => !fs.existsSync(path.join(sketch.source, f)))) {
        console.log(`Sketching ${rel}`);
        require("child_process").execFileSync(process.execPath, [path.join(__dirname, "crayonize-art.js"), rel], { stdio: "ignore" });
    }
    const noCrayon = files.filter((f) => !fs.existsSync(path.join(crayon.source, f)));
    if (noCrayon.length) console.log(`No crayon version yet (shown painted until drawn): ${noCrayon.join(", ")}`);
}

// Convert.
fs.rmSync(TARGET, { recursive: true, force: true });
for (const edition of EDITIONS) fs.rmSync(edition.target, { recursive: true, force: true });
let count = 0, bytes = 0;
const twinCounts = {};
for (const layer of Object.values(layers)) {
    for (const option of layer.options) {
        const images = option.files.map((f) => ({ ...f, image: decodePng(f.file) }));
        option.perSkin = images.some((f) => f.skin);
        const painted = convertOption(layer, option, images, TARGET);
        option.full = painted.full;
        option.rect = painted.rect;
        // Its twins in the editions, where every one of its files has one.
        option.editions = {};
        for (const edition of EDITIONS) {
            const twins = option.files.map((f) => path.join(edition.source, path.relative(SOURCE, f.file)));
            if (!twins.every((t) => fs.existsSync(t))) continue;
            option.editions[edition.key] = convertOption(layer, option, option.files.map((f, i) => ({ ...f, image: decodePng(twins[i]) })), edition.target);
            twinCounts[edition.key] = (twinCounts[edition.key] || 0) + 1;
        }
        console.log(`${layer.folder}/${option.id} (${option.rarity}${option.perSkin ? ", per skin" : ""}): ${painted.pixels}` +
            Object.entries(option.editions).map(([k, e]) => `, ${k} ${e.pixels}`).join(""));
    }
}

// MintArt.lua: options per layer, most common first.
const num = (n) => String(Math.round(n * 10000) / 10000);
const lines = [
    "-- Generated by tools/convert-art.js from the source art; don't edit, rerun the script instead.",
    "-- [layer key] = options { id, name, rarity, texture, rect = { x, y, width, height } as fractions of the",
    "-- picture, perSkin = texture has a %s for the skin id, crayon / sketch = its twin's texture in that edition",
    "-- (crayonRect / sketchRect its rect) }.",
    "-- Layer order and names are in Minting.lua.",
    "",
    "local _, ns = ...",
    "",
    'local MEDIA = "Interface\\\\AddOns\\\\SOLC\\\\Media\\\\Collectible\\\\"',
    ...EDITIONS.map((e) => `local ${e.key.toUpperCase()} = "Interface\\\\AddOns\\\\SOLC\\\\Media\\\\${e.folder}\\\\"`),
    "",
    "ns.MintArt = {",
];
for (const layer of Object.values(layers)) {
    lines.push(`    ${layer.key} = {`);
    const sorted = [...layer.options].sort((a, b) => RARITIES.indexOf(a.rarity) - RARITIES.indexOf(b.rarity) || a.id.localeCompare(b.id));
    for (const o of sorted) {
        const texture = `MEDIA .. "${layer.folder}\\\\${o.perSkin ? "%s\\\\" : ""}${o.id}"`;
        const rect = o.full ? "" : `, rect = { ${o.rect.map(num).join(", ")} }`;
        let crayon = "";
        for (const [key, e] of Object.entries(o.editions)) {
            crayon += `, ${key} = ${key.toUpperCase()} .. "${layer.folder}\\\\${o.perSkin ? "%s\\\\" : ""}${o.id}"`;
            if (!e.full) crayon += `, ${key}Rect = { ${e.rect.map(num).join(", ")} }`;
        }
        lines.push(`        { id = "${o.id}", name = "${o.name}", rarity = "${o.rarity}", texture = ${texture}${rect}${o.perSkin ? ", perSkin = true" : ""}${crayon} },`);
    }
    lines.push("    },");
}
lines.push("}", "");
fs.writeFileSync(LUA_FILE, lines.join("\n"));
console.log(`Converted ${count} file(s) (twins: ${Object.entries(twinCounts).map(([k, n]) => n + " " + k).join(", ")}), ${(bytes / 1048576).toFixed(1)} MB, and wrote MintArt.lua. Restart WoW (not just /reload) to load new textures.`);
