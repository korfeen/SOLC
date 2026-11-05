// Draws a minted picture from its traits at the source paintings' full size (1254 px; the game's textures are 512), the
// way the game does (Minting.lua's ns.RenderMint) - for galleries outside the game (the Discord bot's, solc-bot).
// Order, back to front (the game's sublevels): the background; parts behind the ogre (an outfit's back, the pieces'
// "behind" parts and linings from the item fitter); the skin, with the worn pieces' "hide" masks cut out; the clothes;
// the mouth; the eyes; a skin's or outfit's front (a boss's mask, a collar over the chin); the accessory if it's worn
// under the hat (UNDER_HAT); the hat (or the hooded onesie, a suit, in its place); accessories and floating face bits
// over the hat. A piece's layers it covers aren't drawn. Each layer in its edition (mint.style: one edition, or
// { [layer] = edition }), painted where it has no twin. Eyes and mouths only show on the head (some face pieces kept
// a bit of the painting's backdrop past the head).
// Sources: %USERPROFILE%\killtracker-art (<Layer>/<Rarity>/[<skin>/]<piece>.png), killtracker-art-extra\CrayonHand
// (crayon) and CrayonArt (sketch) laid out the same, and killtracker-art-extra\Unlocks\{painted,crayon,sketch} plus
// Unlocks\generated\fits (the fitter's <id>.behind/.hide/.lining.png) - as tools/convert-art.js reads them.
//   const { renderPicture, png } = require("./render-picture.js");
//   fs.writeFileSync("pic.png", png(renderPicture({ traits, style }, { size: 1024 })));
//   node tools/render-picture.js out.png background=x skin=y ... [style=crayon] [size=1024]

const fs = require("fs");
const path = require("path");
const zlib = require("zlib");
const { SOURCE, decodePng } = require("./convert-art.js");

const EXTRA = path.join(path.dirname(SOURCE), "killtracker-art-extra");
const UNLOCKS = path.join(EXTRA, "Unlocks");
const FITS = path.join(UNLOCKS, "generated", "fits");
const ROOTS = {  // [edition] = the folders laid out <Layer>/<Rarity>/[<skin>/]<piece>.png
  painted: [SOURCE, path.join(UNLOCKS, "painted")],
  crayon: [path.join(EXTRA, "CrayonHand"), path.join(UNLOCKS, "crayon")],
  sketch: [path.join(EXTRA, "CrayonArt"), path.join(UNLOCKS, "sketch")],
};
const LAYERS = ["background", "skin", "outfit", "expression", "eyes", "accessory", "headwear"];  // (ns.MintLayers)
const toId = (name) => name.toLowerCase().replace(/\.png$/, "").replace(/[^a-z0-9]+/g, "_").replace(/^_|_$/g, "");

// The game's piece data (MintArt.lua) and its draw rules (Minting.lua's UNDER_HAT, FACE_OVER_HAT), read once.
let art;
function loadArt() {
  if (art) return art;
  const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require("C:/Users/faluk/Projects/solc-activity/node_modules/fengari");
  const L = lauxlib.luaL_newstate(); lualib.luaL_openlibs(L);
  const src = fs.readFileSync(path.join(__dirname, "..", "MintArt.lua"), "utf8");
  const run = (code) => { if (lauxlib.luaL_loadbuffer(L, to_luastring(code), null, to_luastring("MintArt")) || lua.lua_pcall(L, 0, 1, 0)) throw Error(to_jsstring(lua.lua_tostring(L, -1))); };
  run(`local ns = {} local f = assert(load(${JSON.stringify(src)})) f("SOLC", ns)
    local out = {}
    local function enc(v) if type(v) == "table" then local p = {} for k, x in pairs(v) do p[#p + 1] = string.format("%q", tostring(k)) .. ":" .. enc(x) end return "{" .. table.concat(p, ",") .. "}" elseif type(v) == "string" then return string.format("%q", v) else return tostring(v) end end
    return enc(ns.MintArt)`);
  const mintArt = JSON.parse(to_jsstring(lua.lua_tostring(L, -1)).replace(/\\\n/g, "\\n"));
  const options = {};
  for (const layer of LAYERS) {
    options[layer] = {};
    for (const o of Object.values(mintArt[layer] || {})) options[layer][o.id] = o;
  }
  const minting = fs.readFileSync(path.join(__dirname, "..", "Minting.lua"), "utf8");
  const ids = (name) => new Set([...(minting.match(new RegExp(`local ${name} = \\{([\\s\\S]*?)\\n?\\}`))?.[1] ?? "").matchAll(/([a-z0-9_]+) = true/g)].map((m) => m[1]));
  // Every source painting: [edition][layer][id][skin or ""] = file, and its .front/.back/.suit beside it.
  const files = {};
  for (const [edition, roots] of Object.entries(ROOTS)) {
    const index = (files[edition] = {});
    for (const root of roots) {
      if (!fs.existsSync(root)) continue;
      for (const folder of fs.readdirSync(root)) {
        const layer = toId(folder), dir = path.join(root, folder);
        if (!LAYERS.includes(layer) || !fs.statSync(dir).isDirectory()) continue;
        for (const rarity of fs.readdirSync(dir)) {
          const rdir = path.join(dir, rarity);
          if (!fs.statSync(rdir).isDirectory()) continue;
          const add = (file, skin) => {
            const m = path.basename(file).match(/^(.*?)(?:\.(front|back|suit))?\.png$/i);
            if (!m) return;
            const id = toId(m[1]), key = (skin || "") + (m[2] ? "." + m[2].toLowerCase() : "");
            ((index[layer] ||= {})[id] ||= {})[key] ||= file;  // (the first root wins: the base art over Unlocks)
          };
          for (const f of fs.readdirSync(rdir)) {
            const p = path.join(rdir, f);
            if (fs.statSync(p).isDirectory()) { for (const g of fs.readdirSync(p)) if (/\.png$/i.test(g)) add(path.join(p, g), toId(f)); }
            else if (/\.png$/i.test(f)) add(p, null);
          }
        }
      }
    }
  }
  art = { options, files, underHat: ids("UNDER_HAT"), faceOverHat: ids("FACE_OVER_HAT") };
  return art;
}

const cache = new Map();
function image(file) {
  if (!file || !fs.existsSync(file)) return null;
  if (!cache.has(file)) { if (cache.size > 40) cache.delete(cache.keys().next().value); cache.set(file, decodePng(file)); }
  return cache.get(file);
}
// A piece's painting in an edition (painted where it has no twin), for a skin's face art, or a variant (front/back/suit).
function source(edition, layer, id, skin, variant) {
  const { files } = loadArt();
  const key = (skin || "") + (variant ? "." + variant : "");
  for (const e of [edition, "painted"]) {
    const f = files[e]?.[layer]?.[id]?.[key];
    if (f) return image(f);
  }
  return null;
}
const fit = (name) => image(path.join(FITS, name + ".png"));

function renderPicture(mint, { size } = {}) {
  const { options, underHat, faceOverHat } = loadArt();
  const traits = mint.traits || {}, style = mint.style;
  const editionOf = (layer) => (typeof style === "string" ? style : (style && style[layer]) || "painted");
  const pick = {};
  for (const layer of LAYERS) if (traits[layer] && options[layer][traits[layer]]) pick[layer] = options[layer][traits[layer]];
  const covered = new Set();
  for (const o of Object.values(pick)) for (const k of Object.keys(o.covers || {})) covered.add(o.covers[k] === true ? k : o.covers[k]);
  const skin = pick.skin, faceSkin = skin ? (skin.faceSkin || skin.id) : "moss";
  const suit = pick.outfit && pick.outfit.suit && pick.outfit.suitHead === traits.headwear ? pick.outfit : null;
  const img = (layer, o, variant) => source(editionOf(layer), layer, o.id, o.perSkin ? faceSkin : null, variant);

  // What gets drawn, as { image, mask, behind (its behind part's mask), lining, z }, z the game's sublevel.
  const parts = [], hides = [];
  const Z = { background: -6, skin: -4, outfit: -2, expression: 0, eyes: 2, accessory: 4, headwear: 6 };
  for (const layer of LAYERS) {
    const o = pick[layer];
    if (!o || covered.has(layer) || (suit && layer === "outfit")) continue;
    const suitHere = suit && layer === "headwear";
    const fitId = suitHere ? suit.id.replace(/_body$/, "_suit") : o.id;
    const im = suitHere ? img("outfit", suit, "suit") : img(layer, o);
    if (!im) continue;
    let z = Z[layer];
    if (layer === "accessory" && !underHat.has(o.id)) z = 7;
    if (faceOverHat.has(o.id)) z = 7;
    const hide = (o.hide || (suitHere && suit.suitHide)) ? fit(fitId + ".hide") : null;
    if (hide) hides.push(hide);
    // (eyes and mouths only on the head, except the bits meant to float off it: a snore bubble)
    const headOnly = (layer === "eyes" || layer === "expression") && !faceOverHat.has(o.id);
    // (its behind part: the painted piece through the fitter's mask, as the game's option.behind; only a painted piece
    // is split, an edition's twin is drawn whole, as in game)
    const painted = editionOf(suitHere ? "outfit" : layer) === "painted" || im === (suitHere ? source("painted", "outfit", suit.id, null, "suit") : source("painted", layer, o.id, o.perSkin ? faceSkin : null));
    const behind = fit(fitId + ".behind");
    const behindImage = behind && (suitHere ? source("painted", "outfit", suit.id, null, "suit") : source("painted", layer, o.id, o.perSkin ? faceSkin : null));
    parts.push({ layer, image: im, z, headOnly, behind, behindImage, split: painted, lining: fit(fitId + ".lining") });
    if (layer === "skin" && o.front) { const f = img("skin", o, "front"); if (f) parts.push({ layer: "front", image: f, z: 3 }); }
    if (layer === "outfit" && !suit) {
      const front = o.front && img("outfit", o, "front"), back = o.back && img("outfit", o, "back");
      if (front) parts.push({ layer: "front", image: front, z: 3 });
      if (back) parts.push({ layer: "back", image: back, z: -5 });
    }
  }
  const N = Math.max(...parts.map((p) => p.image.width));
  const canvas = new Float64Array(N * N * 3);
  const at = (im, x, y) => (im.width === N ? (y * N + x) * 4 : (Math.floor(y * im.height / N) * im.width + Math.floor(x * im.width / N)) * 4);
  const over = (im, a, i, x, y) => { if (a <= 0) return; const s = at(im, x, y); for (let c = 0; c < 3; c++) canvas[i * 3 + c] += (im.rgba[s + c] - canvas[i * 3 + c]) * a; };
  const alphaAt = (im, x, y) => (im ? im.rgba[at(im, x, y) + 3] / 255 : 0);
  // (behind parts and linings first, just above the background: z -5)
  const bg = parts.find((p) => p.layer === "background");
  const ordered = parts.filter((p) => p !== bg).sort((a, b) => a.z - b.z);
  const skinPart = parts.find((p) => p.layer === "skin");
  for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
    const i = y * N + x;
    if (bg) over(bg.image, alphaAt(bg.image, x, y), i, x, y);
    for (const p of parts) {
      if (p.lining) over(p.lining, alphaAt(p.lining, x, y), i, x, y);
      if (p.behind && p.behindImage) over(p.behindImage, alphaAt(p.behindImage, x, y) * alphaAt(p.behind, x, y), i, x, y);
    }
    for (const p of ordered) {
      let a = alphaAt(p.image, x, y);
      if (!a) continue;
      if (p.behind && p.split) a *= 1 - alphaAt(p.behind, x, y);
      if (p.layer === "skin") for (const h of hides) a *= 1 - alphaAt(h, x, y);
      if (p.headOnly && skinPart) a *= alphaAt(skinPart.image, x, y);
      over(p.image, a, i, x, y);
    }
  }
  const S = size || N, out = Buffer.alloc(S * S * 4);
  for (let y = 0; y < S; y++) for (let x = 0; x < S; x++) {
    const acc = [0, 0, 0]; let n = 0;
    for (let yy = Math.floor(y * N / S); yy < Math.max(Math.floor(y * N / S) + 1, Math.floor((y + 1) * N / S)); yy++)
      for (let xx = Math.floor(x * N / S); xx < Math.max(Math.floor(x * N / S) + 1, Math.floor((x + 1) * N / S)); xx++) {
        const i = (Math.min(N - 1, yy) * N + Math.min(N - 1, xx)) * 3; for (let c = 0; c < 3; c++) acc[c] += canvas[i + c]; n++;
      }
    const d = (y * S + x) * 4;
    for (let c = 0; c < 3; c++) out[d + c] = Math.round(acc[c] / n);
    out[d + 3] = 255;
  }
  return { width: S, height: S, rgba: out };
}

function png({ width, height, rgba }) {
  const table = Array.from({ length: 256 }, (_, n) => { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; return c >>> 0; });
  const crc = (buf) => { let c = 0xffffffff; for (const b of buf) c = table[(c ^ b) & 255] ^ (c >>> 8); return (c ^ 0xffffffff) >>> 0; };
  const chunk = (type, data) => { const len = Buffer.alloc(4); len.writeUInt32BE(data.length); const td = Buffer.concat([Buffer.from(type), data]); const c = Buffer.alloc(4); c.writeUInt32BE(crc(td)); return Buffer.concat([len, td, c]); };
  const raw = Buffer.alloc((width * 4 + 1) * height);
  for (let y = 0; y < height; y++) rgba.copy(raw, y * (width * 4 + 1) + 1, y * width * 4, (y + 1) * width * 4);
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(width, 0); ihdr.writeUInt32BE(height, 4); ihdr[8] = 8; ihdr[9] = 6;
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk("IHDR", ihdr), chunk("IDAT", zlib.deflateSync(raw, { level: 9 })), chunk("IEND", Buffer.alloc(0))]);
}

// A picture's overall rarity, as Minting.lua's ns.MintRarity: its pieces' scores added up, graded by how few everyday
// rolls score at least that high (the piece the bedtime story asked for counts as the lowest).
const WEIGHTS = { uncommon: 25, rare: 10, epic: 4, legendary: 1 }, SCORES = { uncommon: 1, rare: 2, epic: 3, legendary: 4 };
const TIERS = [["legendary", 0.015], ["epic", 0.05], ["rare", 0.17]];
let atLeast;
function pictureRarity(traits, asked) {
  const { options } = loadArt();
  if (!atLeast) {
    let chance = { 0: 1 };
    for (const layer of LAYERS) {
      const everyday = Object.values(options[layer]).filter((o) => !o.unlock && !o.retired);
      if (!everyday.length) continue;
      const total = everyday.reduce((t, o) => t + (o.weight || WEIGHTS[o.rarity]), 0), next = {};
      for (const [score, p] of Object.entries(chance)) for (const o of everyday) {
        const s = Number(score) + SCORES[o.rarity];
        next[s] = (next[s] || 0) + p * (o.weight || WEIGHTS[o.rarity]) / total;
      }
      chance = next;
    }
    atLeast = {};
    let sum = 0;
    for (let s = Math.max(...Object.keys(chance).map(Number)); s >= 0; s--) { sum += chance[s] || 0; atLeast[s] = sum; }
  }
  let score = 0;
  for (const layer of LAYERS) {
    const o = options[layer][traits[layer]];
    score += layer === asked ? SCORES.uncommon : o ? SCORES[o.rarity] : 0;
  }
  const share = atLeast[score] ?? 1;
  for (const [rarity, limit] of TIERS) if (share <= limit + 1e-9) return rarity;
  return "uncommon";
}

// The pieces' names and rarities, in layer order: [{ layer, name, rarity }].
function pieces(traits) {
  const { options } = loadArt();
  return LAYERS.filter((l) => options[l][traits[l]]).map((l) => ({ layer: l, name: options[l][traits[l]].name, rarity: options[l][traits[l]].rarity }));
}

module.exports = { renderPicture, png, loadArt, pictureRarity, pieces };

if (require.main === module) {
  const [out, ...args] = process.argv.slice(2);
  const traits = {}, opts = {};
  let style;
  for (const a of args) {
    const [k, v] = a.split("=");
    if (k === "style") style = v; else if (k === "size") opts.size = Number(v); else traits[k] = v;
  }
  const t = Date.now();
  fs.writeFileSync(out, png(renderPicture({ traits, style }, opts)));
  console.log(`wrote ${out} in ${Date.now() - t} ms`);
}
