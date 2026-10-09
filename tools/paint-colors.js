// Writes SOLC_Puzzle/PaintData.lua: every collectible layer option as a small grid of colours, for the paint
// game (WoW can't read a texture's pixels, so the colours a picture is made of are worked out here). Each
// option's full-size PNG (the source art, see convert-art.js) is averaged down to GRID_SIZES cells across,
// weighting pixels by their alpha, so a cell half covered by a hat is the hat's colour at half opacity.
// The game stacks an option's grids the way the picture's layers stack, giving the picture to paint. The editions'
// art (crayon, sketch: see convert-art.js EDITIONS) gets grids too (ns.PaintEditionGrids[edition]), so a layer shown
// in an edition is painted in it.
//
// Cells are 4 characters from CHARS: red, green, blue (6 bits each) and alpha (6 bits). A run of fully
// transparent cells is "~" and its length in one character (1-64). Rows run top to bottom, left to right.
// Usage: node tools/paint-colors.js   (after convert-art.js; reads the same source art). No dependencies.

const fs = require("fs");
const path = require("path");
const os = require("os");
const { SOURCE, decodePng } = require("./convert-art");
const EDITIONS = { crayon: path.join(os.homedir(), "killtracker-art-extra", "CrayonHand"),
    sketch: path.join(os.homedir(), "killtracker-art-extra", "CrayonArt") };

const GRID_SIZES = [16, 24];
const RARITIES = ["uncommon", "rare", "epic", "legendary"];  // the folders convert-art.js reads
const CHARS = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ+/";
const OUT = path.join(__dirname, "..", "SOLC_Puzzle", "PaintData.lua");

const toId = (name) => name.toLowerCase().replace(/\.png$/, "").replace(/[^a-z0-9]+/g, "_").replace(/^_|_$/g, "");
const subdirs = (dir) => fs.readdirSync(dir).filter((f) => fs.statSync(path.join(dir, f)).isDirectory());
const pngs = (dir) => fs.readdirSync(dir).filter((f) => /\.png$/i.test(f));
const six = (v) => CHARS[Math.min(63, Math.round(v * 63 / 255))];

// The image averaged to size x size cells, as the encoded string described above.
function grid(image, size) {
    const { width, height, rgba } = image;
    let out = "", transparent = 0;
    const flush = () => {
        while (transparent > 0) {
            const n = Math.min(64, transparent);
            out += "~" + CHARS[n - 1];
            transparent -= n;
        }
    };
    for (let cy = 0; cy < size; cy++) {
        const y0 = Math.floor(cy * height / size), y1 = Math.floor((cy + 1) * height / size);
        for (let cx = 0; cx < size; cx++) {
            const x0 = Math.floor(cx * width / size), x1 = Math.floor((cx + 1) * width / size);
            let a = 0, r = 0, g = 0, b = 0, count = 0;
            for (let y = y0; y < y1; y++) {
                for (let x = x0; x < x1; x++) {
                    const i = (y * width + x) * 4;
                    const alpha = rgba[i + 3];
                    a += alpha; r += rgba[i] * alpha; g += rgba[i + 1] * alpha; b += rgba[i + 2] * alpha;
                    count++;
                }
            }
            const alpha = a / count;
            if (six(alpha) === "0") { transparent++; continue; }
            flush();
            out += six(r / a) + six(g / a) + six(b / a) + six(alpha);
        }
    }
    flush();
    return out;
}

// [size][layer][option] = grid, or [size][layer][option][skin] = grid for per-skin art, from the art under root (only
// the options the painted art has).
let files = 0;
function build(root) {
const grids = {};
for (const size of GRID_SIZES) grids[size] = {};
for (const folder of subdirs(SOURCE)) {
    const layer = toId(folder);
    for (const rarityFolder of subdirs(path.join(SOURCE, folder))) {
        if (!RARITIES.includes(toId(rarityFolder))) continue;
        const dir = path.join(SOURCE, folder, rarityFolder);
        const add = (file, option, skin) => {
            const image = decodePng(file);
            for (const size of GRID_SIZES) {
                const byLayer = (grids[size][layer] = grids[size][layer] || {});
                if (skin) (byLayer[option] = byLayer[option] || {})[skin] = grid(image, size);
                else byLayer[option] = grid(image, size);
            }
            files++;
        };
        const twin = (file) => path.join(root, path.relative(SOURCE, file));
        for (const file of pngs(dir)) if (fs.existsSync(twin(path.join(dir, file)))) add(twin(path.join(dir, file)), toId(file));
        for (const skinFolder of subdirs(dir)) {
            for (const file of pngs(path.join(dir, skinFolder))) {
                const f = twin(path.join(dir, skinFolder, file));
                if (fs.existsSync(f)) add(f, toId(file), toId(skinFolder));
            }
        }
    }
}
return grids;
}

// Lua, sorted so the file only changes when the art does.
const quote = (s) => JSON.stringify(s);
const sorted = (o) => Object.keys(o).sort();
// One set of grids as a Lua table (indent: its depth).
function table(grids, indent) {
const pad = " ".repeat(indent);
let lua = "{\n";
for (const size of GRID_SIZES) {
    lua += `    [${size}] = {\n`;
    for (const layer of sorted(grids[size])) {
        lua += `        ${layer} = {\n`;
        for (const option of sorted(grids[size][layer])) {
            const value = grids[size][layer][option];
            if (typeof value === "string") {
                lua += `            ${option} = ${quote(value)},\n`;
            } else {
                lua += `            ${option} = {\n`;
                for (const skin of sorted(value)) lua += `                ${skin} = ${quote(value[skin])},\n`;
                lua += "            },\n";
            }
        }
        lua += "        },\n";
    }
    lua += "    },\n";
}
return lua.split("\n").map((l, i) => (i && l ? pad + l : l)).join("\n") + pad + "}";
}
let lua = "-- Generated by tools/paint-colors.js from the collectible art - don't edit. See that script for the format.\n\n"
    + "local _, ns = ...\n\nns.PaintGrids = " + table(build(SOURCE), 0) + "\n\nns.PaintEditionGrids = {\n";
for (const [edition, root] of Object.entries(EDITIONS)) lua += `    ${edition} = ${table(build(root), 4)},\n`;
lua += "}\n";
fs.writeFileSync(OUT, lua);
console.log(`${files} images -> ${OUT} (${Math.round(lua.length / 1024)} KB)`);
