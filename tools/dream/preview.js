// Prints dreams the way the ogre tells them at the Dream Bed, so you can read new lines without WoW. It runs the
// addon's own storyteller (DreamTeller.lua with DreamStory.lua and MintArt.lua) in fengari, so this is exactly what
// the game says. Build first if you changed a story file: node tools/dream/build-story-lua.js
// Usage: node tools/dream/preview.js                    10 random dreams
//        node tools/dream/preview.js 30 --seed 7        the same 30 pictures every time (compare before/after a change)
//        node tools/dream/preview.js --with fac_urok_head,bg_rfc   dreams with these pieces in them
//        node tools/dream/preview.js --find "rolled Need"          only dreams that contain this text (to see your joke)
//        node tools/dream/preview.js 30 --check         flags dreams that are too long, repeat a word, stack endings...
// Needs fengari (a Lua for Node): it's used from ..\solc-activity\node_modules, or install it here (npm i fengari).
const fs = require("fs");
const path = require("path");
const HERE = __dirname, ROOT = path.join(HERE, "..", "..");

let fengari;
for (const where of ["fengari", path.join(ROOT, "..", "solc-activity", "node_modules", "fengari")]) {
  try { fengari = require(where); break; } catch (e) { /* next */ }
}
if (!fengari) { console.log("fengari not found: run `npm i fengari` in the repo, or keep solc-activity next to it."); process.exit(1); }
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = fengari;

// Arguments.
const args = process.argv.slice(2);
let count = 10, find = null, forced = [], seed = null, check = false;
for (let i = 0; i < args.length; i++) {
  if (args[i] === "--find") find = (args[++i] || "").toLowerCase();
  else if (args[i] === "--with") forced = (args[++i] || "").split(",").map((s) => s.trim()).filter(Boolean);
  else if (args[i] === "--seed") seed = Number(args[++i]) || 1;
  else if (args[i] === "--check") check = true;
  else if (/^\d+$/.test(args[i])) count = Number(args[i]);
}
if (seed === null) seed = Math.floor(Math.random() * 1e9);

// A small seeded random, for picking the pictures (the same seed gives the same pictures).
let s = seed >>> 0;
const rand = () => { s = (s + 0x6d2b79f5) >>> 0; let t = s; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
const pick = (list) => list[Math.floor(rand() * list.length)];

// The Lua side: the three files, as the addon loads them (local _, ns = ...).
const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);
lua.lua_newtable(L);
lua.lua_setglobal(L, to_luastring("NS"));
function Run(code, name, withNs) {
  if (lauxlib.luaL_loadbuffer(L, to_luastring(code), null, to_luastring("@" + name)) !== lua.LUA_OK) throw new Error(to_jsstring(lua.lua_tostring(L, -1)));
  let n = 0;
  if (withNs) { lua.lua_pushstring(L, to_luastring("SOLC")); lua.lua_getglobal(L, to_luastring("NS")); n = 2; }
  if (lua.lua_pcall(L, n, 1, 0) !== lua.LUA_OK) throw new Error(to_jsstring(lua.lua_tostring(L, -1)));
  const out = lua.lua_isstring(L, -1) ? to_jsstring(lua.lua_tostring(L, -1)) : null;
  lua.lua_pop(L, 1);
  return out;
}
for (const f of ["MintArt.lua", "DreamStory.lua", "DreamTeller.lua"]) Run(fs.readFileSync(path.join(ROOT, f), "utf8"), f, true);
// The layers as Minting.lua lists them (ns.MintLayers: { key, options }), and the pieces you can roll.
const layers = JSON.parse(Run(`
  local ns = NS
  ns.MintLayers = {}
  local parts = {}
  for key, options in pairs(ns.MintArt) do
    ns.MintLayers[#ns.MintLayers + 1] = { key = key, options = options }
    local ids = {}
    for _, o in ipairs(options) do if not o.retired then ids[#ids + 1] = string.format("%q", o.id) end end
    parts[#parts + 1] = string.format("%q:[%s]", key, table.concat(ids, ","))
  end
  return "{" .. table.concat(parts, ",") .. "}"`, "layers"));
const ORDER = ["background", "skin", "outfit", "headwear", "eyes", "expression", "accessory"];
const forcedBy = {};
for (const id of forced) {
  const layer = ORDER.find((l) => layers[l].includes(id));
  if (!layer) { console.log("No piece with id \"" + id + "\" in MintArt.lua (retired pieces are left out)."); process.exit(1); }
  forcedBy[layer] = id;
}

// A pretend player, so the cameo lines have names to fill in.
const CTX = `{ me = "Koffe", mates = { "Grubnar", "Lilmoss", "Snorebert" }, kills = { n = 312, name = "murlocs" },
  buddies = { { name = "Grubnar", place = "the Deadmines" }, { name = "Lilmoss", place = "Scholomance" } } }`;
const q = (t) => JSON.stringify(t);
function Tell(pictures, luaSeed) {
  const calls = pictures.map((p) => `out[#out + 1] = ns.DreamText(ns.TellDream({ ${ORDER.map((l) => l + " = " + q(p[l])).join(", ")} }, nil, ctx))`);
  return Run(`local ns, out, ctx = NS, {}, ${CTX}\nmath.randomseed(${luaSeed})\n${calls.join("\n")}\nreturn table.concat(out, "\\1")`, "preview").split("\x01");
}
const Picture = () => Object.fromEntries(ORDER.map((l) => [l, forcedBy[l] || pick(layers[l])]));
const nameOf = {};
Object.assign(nameOf, JSON.parse(Run(`local p = {} for key, options in pairs(NS.MintArt) do for _, o in ipairs(options) do p[#p + 1] = string.format("%q:%q", key .. "/" .. o.id, o.name) end end return "{" .. table.concat(p, ",") .. "}"`, "names")));

// The dreams.
let shown = [];
if (find) {
  for (let round = 0; shown.length < count && round < 40; round++) {
    const pictures = Array.from({ length: 500 }, Picture), texts = Tell(pictures, seed + round);
    texts.forEach((t, i) => { if (shown.length < count && t.toLowerCase().includes(find)) shown.push({ text: t, picture: pictures[i] }); });
  }
  if (!shown.length) console.log("No dream said \"" + find + "\" in 20000 tries. Is the line in story-solc.js, built, and spelled the same?");
} else {
  const pictures = Array.from({ length: count }, Picture);
  shown = Tell(pictures, seed).map((t, i) => ({ text: t, picture: pictures[i] }));
}

// The check: what makes a dream hard to follow.
const COMMON = new Set("about after again all also and around back been before being down every from have here into just like look looks more much next only other over really some still than that their them then there these they this through very want what when where which while with would your".split(" "));
function Problems(text) {
  const problems = [];
  const words = text.split(/\s+/).length;
  if (words > 85) problems.push(words + " words");
  const ending = text.slice(text.lastIndexOf("...") + 3);
  const endSentences = (ending.match(/(^|[.!?)]\s+)And /g) || []).length;
  if (endSentences > 2) problems.push(endSentences + " ending sentences");
  const excited = (text.match(/ \((I SWEAR|honestly|I'm not making this up|GLOWING, I'm telling you|like, properly)\)/g) || []).length;
  if (excited > 1) problems.push(excited + "x excited");
  // (a word from the opening or from what he does coming back in the ending is a callback, not a repeat)
  const does = text.slice(text.lastIndexOf("and then he "));
  const setup = text.slice(0, text.indexOf("...")) + " " + does.slice(0, does.search(/[.!?](s|$)/) + 1);
  const opening = new Set(setup.toLowerCase().match(/[a-z']{5,}/g) || []);
  const seen = {};
  for (const w of text.toLowerCase().match(/[a-z']{5,}/g) || []) if (!COMMON.has(w)) seen[w] = (seen[w] || 0) + 1;
  const repeats = Object.entries(seen).filter(([w, n]) => n > 1 && !opening.has(w)).map(([w]) => w);
  if (repeats.length) problems.push("repeats: " + repeats.join(", "));
  return problems;
}

let flagged = 0;
for (const d of shown) {
  const problems = check ? Problems(d.text) : [];
  if (problems.length) flagged++;
  console.log("\n" + d.text + "\n  (" + ORDER.map((l) => nameOf[l + "/" + d.picture[l]] || d.picture[l]).join(" / ") + ")" + (problems.length ? "\n  !! " + problems.join("; ") : ""));
}
if (check) console.log("\n" + flagged + " of " + shown.length + " dreams flagged.");
console.log("(seed " + seed + ")\n");
