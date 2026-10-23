// Builds DreamStory.lua (the addon's dream storyteller data, ns.DreamStory) from the story files here: story.js (the
// club pieces, by name), story-dungeon-places.js, story-chase.js, story-wearables.js, story-crowds.js (by option id),
// story-payoffs.js (each opening's ending), storyteller.js's word lists and story-solc.js (SOLC jokes, added to the lists). Every piece is keyed by its option id (MintArt.lua: names -> ids), as pictures
// store them. DreamTeller.lua tells the dreams from it.
// Usage: node tools/dream/build-story-lua.js   (then /reload; no new textures)
const fs = require("fs");
const path = require("path");
const HERE = __dirname, ROOT = path.join(HERE, "..", "..");
// (story-ends-*.js: each group of pieces' own endings, added to story-piece-ends.js's PIECE_ENDS)
const FILES = ["story.js", "story-dungeon-places.js", "story-chase.js", "story-wearables.js", "story-crowds.js", "story-payoffs.js", "story-piece-ends.js",
  ...fs.readdirSync(HERE).filter((f) => /^story-ends-.+.js$/.test(f)).sort(), "piece-tags.js",
  ...fs.readdirSync(HERE).filter((f) => /^tags-.+.js$/.test(f)).sort(), "storyteller.js", "story-solc.js"];
const src = FILES.map((f) => fs.readFileSync(path.join(HERE, f), "utf8")).join("\n");
const S = new Function(src + `;return { OPENERS, SETTING, SKIN, OUTFIT, HAT, EYES, FACE, THING, WILD, SETTING_DUNGEON, THING_CHASE, HAT_CHASE,
  OUTFIT_MORE, HAT_MORE, CROWD, REACTIONS, OPENERS_TIME, EXCITED, CAMEOS, BUDDY_CAMEOS, SET_FACTIONS, SET_CREATURES, GENERIC_ENDS, SHORT, PAYOFF, ME, WILD_TAGGED, PIECE_ENDS, TAG_LIST, PIECE_TAGS, TAG_ENDS };`)();

// Names -> ids, per layer (MintArt.lua).
const ids = {}, names = {};
{
  let layer = null;
  for (const line of fs.readFileSync(path.join(ROOT, "MintArt.lua"), "utf8").split(/\r?\n/)) {
    const m = line.match(/^\s+(\w+) = \{$/);
    if (m) { layer = m[1]; continue; }
    const o = line.match(/id = "([^"]+)", name = "([^"]+)"/);
    if (o && layer) { (ids[layer] = ids[layer] || {})[o[2]] = o[1]; (names[layer] = names[layer] || {})[o[1]] = o[2]; }
  }
}
const missing = [];
const byId = (layer, table) => {
  const out = {};
  for (const [name, value] of Object.entries(table)) {
    const id = ids[layer] && ids[layer][name];
    if (id) out[id] = value; else missing.push(layer + ": " + name);
  }
  return out;
};

// Places merge their crowd (CROWD) and payoffs (PAYOFF) in: club places by name, dungeon places by id. pay[i] is the
// list of endings that answer at[i]; back keeps the other callbacks (minus any that became a payoff, so an ending never repeats).
const place = {}, payProblems = [];
function Place(id, key, p) {
  const pay = (S.PAYOFF[key] || []).map((list) => (Array.isArray(list) ? list : [list]));
  if (pay.length !== p.at.length) payProblems.push(key + " (" + p.at.length + " openings, " + pay.length + " payoff lists)");
  const paid = new Set(pay.flat());
  place[id] = { at: p.at, pay, enters: p.enters, back: p.back.filter((b) => !paid.has(b)), mobs: (S.CROWD[key] || {}).mobs, boss: (S.CROWD[key] || {}).boss };
}
for (const [name, p] of Object.entries(S.SETTING)) {
  const id = ids.background[name];
  if (!id) { missing.push("background: " + name); continue; }
  Place(id, name, p);
}
for (const [id, p] of Object.entries(S.SETTING_DUNGEON)) Place(id, id, p);
const thing = byId("accessory", Object.fromEntries(Object.entries(S.THING).map(([n, t]) => [n, { does: t.does, ends: t.end }])));
for (const [id, t] of Object.entries(S.THING_CHASE)) thing[id] = { does: t.does, ends: t.end };
const hat = Object.assign(byId("headwear", S.HAT), S.HAT_MORE);
for (const [id, h] of Object.entries(S.HAT_CHASE)) hat[id] = h.hat;
const outfit = Object.assign(byId("outfit", S.OUTFIT), S.OUTFIT_MORE);
const short = {};
for (const [name, word] of Object.entries(S.SHORT)) for (const layer of ["headwear", "outfit", "accessory", "skin"]) if (ids[layer] && ids[layer][name]) short[ids[layer][name]] = word;

// Tags: plain keywords (Lua patterns have no alternation), found in "<id> <name>" lowercased.
const TAGS = {
  fire: ["ember", "flame", "fel", "fire", "lava", "molten", "magma", "phoenix", "burn", "ragefire", "rfc", "brd", "blackrock", "smoulder", "obsidian", "ironfoe", "sunburnt"],
  water: ["pool", "spring", "bfd", "blackfathom", "cove", "sea", "naga", "murloc", "wailing", "steam", "water", "hydra", "crab", "turtle", "croc"],
  undead: ["ghost", "skeleton", "zombie", "ghoul", "strat", "scholo", "rfd", "downs", "scourge", "undead", "bone", "dead", "graveyard", "smgy", "rivendare", "lordaeron", "ruins", "cultist"],
  holy: ["scarlet", "whitemane", "crusade", "smlib", "smarm", "smcath", "holy", "priest", "cathedral"],
  pirate: ["pirate", "tricorn", "parrot", "eyepatch", "bloodsail", "sea dog", "ship", "captain"],
  golf: ["golf", "fairway", "tee", "club", "polo", "visor", "membership", "caddie"],
  sleepy: ["sleep", "nap", "snore", "pajama", "pyjama", "nightcap", "yawn", "asleep", "dream", "bathrobe", "eye mask", "hammock", "barrow"],
  dragon: ["dragon", "drake", "whelp", "onyx", "drakkisath", "ubrs", "deathbringer", "draconian", "eranikus", "sunken"],
  ice: ["ice", "frost", "cold", "snow", "amnennar"],
  gnome: ["gnome", "gnomer", "gigaflux", "mech", "venture", "goblin", "reactor", "thermaplugg", "excav", "golem"],
  morning: ["dawn", "morning", "sunrise"],
  night: ["moon", "night", "midnight", "ghost ship", "dusk", "star"],
};

// Lua writer.
const q = (t) => '"' + String(t).replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/\n/g, "\\n") + '"';
const isIdent = (k) => /^[A-Za-z_][A-Za-z0-9_]*$/.test(k);
function lua(v, indent) {
  const pad = "    ".repeat(indent);
  if (Array.isArray(v)) return "{ " + v.map((x) => lua(x, indent + 1)).join(", ") + " }";
  if (v && typeof v === "object") {
    const keys = Object.keys(v).filter((k) => v[k] !== undefined).sort();
    if (!keys.length) return "{}";
    return "{\n" + keys.map((k) => pad + "    " + (isIdent(k) ? k : "[" + q(k) + "]") + " = " + lua(v[k], indent + 1) + ",").join("\n") + "\n" + pad + "}";
  }
  if (typeof v === "number") return String(v);
  return q(v);
}
const data = {
  OPENERS: S.OPENERS, OPENERS_TIME: S.OPENERS_TIME, WILD: S.WILD, GENERIC_ENDS: S.GENERIC_ENDS, CAMEOS: S.CAMEOS, BUDDY_CAMEOS: S.BUDDY_CAMEOS,
  EXCITED: S.EXCITED, REACTIONS: S.REACTIONS, SET_FACTIONS: S.SET_FACTIONS, SET_CREATURES: S.SET_CREATURES, SHORT: short, TAGS, ME: S.ME, WILD_TAGGED: S.WILD_TAGGED, ENDS: S.PIECE_ENDS, PIECE_TAGS: S.PIECE_TAGS, TAG_ENDS: S.TAG_ENDS,
  PLACE: place, SKIN: byId("skin", S.SKIN), OUTFIT: outfit, HAT: hat, EYES: byId("eyes", S.EYES), FACE: byId("expression", S.FACE), THING: thing,
};
const out = ["-- The Dream Bed's storyteller data (generated by tools/dream/build-story-lua.js from tools/dream/*.js - don't edit here).",
  "-- Every piece by its option id. Told by DreamTeller.lua.", "local _, ns = ...", "ns.DreamStory = " + lua(data, 0), ""].join("\n");
fs.writeFileSync(path.join(ROOT, "DreamStory.lua"), out);
const count = (o) => Object.keys(o).length;
console.log(`DreamStory.lua: ${count(place)} places, ${count(data.SKIN)} skins, ${count(outfit)} outfits, ${count(hat)} hats, ${count(data.EYES)} eyes, ${count(data.FACE)} faces, ${count(thing)} things (${Math.round(out.length / 1024)} KB)`);
if (missing.length) console.log("Not in MintArt.lua (left out): " + missing.join("; "));

// Mint pieces with no story lines yet (retired ones too: old pictures still tell them). Write them in tools/dream/*.js.
const SECTION = { background: place, skin: data.SKIN, outfit, headwear: hat, eyes: data.EYES, expression: data.FACE, accessory: thing };
const untold = [];
for (const [layer, list] of Object.entries(names)) for (const [id, name] of Object.entries(list)) if (SECTION[layer] && !SECTION[layer][id]) untold.push(layer + ": " + name + " (" + id + ")");
if (untold.length) console.log("\nNO STORY YET (" + untold.length + "): the ogre can't tell these. Add lines in tools/dream/*.js:\n  " + untold.join("\n  "));
else console.log("Every mint piece has story lines.");
// Faction/hunter hat + outfit pairs are told as one costume ("dressed exactly like {who}"): who comes from SET_FACTIONS.
const pairKeys = new Set();
for (const id of Object.keys(names.headwear || {})) {
  const m = id.match(/^(fac|hunt)_(.+)_head$/);
  if (m && names.outfit && names.outfit[m[1] + "_" + m[2] + "_body"]) pairKeys.add(m[2]);
}
const unnamed = [...pairKeys].filter((k) => !S.SET_FACTIONS[k]);
if (unnamed.length) console.log("NO SET NAME in storyteller.js SET_FACTIONS (told as 'someone else'): " + unnamed.join(", "));
if (payProblems.length) console.log("PAYOFFS DON'T MATCH THE OPENINGS in story-payoffs.js (one list of payoffs per opening, same order): " + payProblems.join("; "));
// Hats, outfits and skins without their own endings (PIECE_ENDS, story-ends-*.js), and endings for pieces that don't exist.
const noEnds = [];
for (const layer of ["skin", "outfit", "headwear"]) for (const [id, name] of Object.entries(names[layer] || {})) if (!S.PIECE_ENDS[id]) noEnds.push(name + " (" + id + ")");
if (noEnds.length) console.log("NO OWN ENDINGS (" + noEnds.length + ") in story-ends-*.js: " + (noEnds.length > 12 ? noEnds.slice(0, 12).join(", ") + ", ..." : noEnds.join(", ")));
const known = new Set(["skin", "outfit", "headwear"].flatMap((l) => Object.keys(names[l] || {})));
const strayEnds = Object.keys(S.PIECE_ENDS).filter((id) => !known.has(id));
if (strayEnds.length) console.log("ENDINGS FOR UNKNOWN IDS (typo?): " + strayEnds.join(", "));
// Hand-picked tags (piece-tags.js, tags-*.js): only TAG_LIST's words; pieces with no entry fall back to the keyword TAGS.
const badTags = [], untagged = [];
for (const [id, tags] of Object.entries(S.PIECE_TAGS)) for (const t of tags) if (!S.TAG_LIST[t]) badTags.push(id + ": " + t);
if (badTags.length) { console.log("UNKNOWN TAGS (not in piece-tags.js TAG_LIST): " + badTags.join("; ")); process.exitCode = 1; }
for (const [layer, list] of Object.entries(names)) for (const [id, name] of Object.entries(list)) if (!S.PIECE_TAGS[id]) untagged.push(name + " (" + id + ")");
if (untagged.length) console.log("NOT TAGGED (" + untagged.length + ") in tags-*.js: " + (untagged.length > 12 ? untagged.slice(0, 12).join(", ") + ", ..." : untagged.join(", ")));
// Tag-locked lines may only use TAG_LIST's tags.
for (const [what, table] of [["ME", S.ME], ["WILD_TAGGED", S.WILD_TAGGED], ["TAG_ENDS", S.TAG_ENDS]]) for (const t of Object.keys(table)) if (t !== "any" && !S.TAG_LIST[t]) console.log(what + " uses a tag that isn't in TAG_LIST: " + t);
for (const pair of S.REACTIONS) for (const t of [pair[0], pair[1]]) if (!S.TAG_LIST[t]) console.log("REACTIONS uses a tag that isn't in TAG_LIST: " + t);
