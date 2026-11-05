// One-off (2026-11-05): nothing for pictures before minting opens (the Collection and Dream Bed, Ogre Rank 3): the rank
// pieces from rank 3 up, Polaroid and Honey Wood frames at 3 and 4. Also gives every perk a short label (Ranks.lua).
const fs = require("fs");
const path = require("path");
process.chdir(path.join(__dirname, ".."));
const RANKS = {
  "expression/sea_dog_grin": 3, "eyes/dreamy_swirl": 4, "accessory/pirate_eyepatch": 5, "background/pool_with_floaties": 6,
  "accessory/floating_sheep": 7, "outfit/pirate_captain_coat": 8, "headwear/astral_nightcap": 9,
  "expression/crystal_drool": 10, "accessory/moonstone_pendant": 11, "expression/stardust_snore": 13, "eyes/starlit_dreamer": 14,
  "outfit/celestial_pajamas": 15, "skin/sea_cursed_teal": 17, "headwear/dragon_hatchling_hat": 19,
  "outfit/dragonhide_golf_jacket": 21, "skin/enchanted_jade": 23, "background/floating_sky_spa": 24, "outfit/royal_nap_robe": 25,
  "accessory/pocket_portal": 26, "skin/celestial_blue": 27, "headwear/crown_of_eternal_rest": 28,
  "background/dragon_over_the_fairway": 29,
};
const FRAMES = { polaroid: 3, wood: 4 };
const nlOf = (s) => (s.includes("\r\n") ? "\r\n" : "\n");
function rewrite(file, fn) {
  const s = fs.readFileSync(file, "utf8");
  const t = fn(s, nlOf(s));
  if (t === s) throw Error("no change: " + file);
  fs.writeFileSync(file, t);
}
const cfg = JSON.parse(fs.readFileSync("output/starter-unlocks.json", "utf8"));
cfg.rank = RANKS;
fs.writeFileSync("output/starter-unlocks.json", JSON.stringify(cfg));

// MintArt.lua: each piece's unlock = "rank:<n>" (matched by its layer's texture folder and id).
const FOLDER = { background: "Background", skin: "Skin", outfit: "Outfit", expression: "Expression", eyes: "Eyes", accessory: "Accessory", headwear: "Headwear" };
rewrite("MintArt.lua", (s, nl) => s.split(nl).map((line) => {
  const id = (line.match(/\{ id = "([^"]+)"/) || [])[1];
  if (!id || line.includes("retired = true")) return line;
  for (const [key, rank] of Object.entries(RANKS)) {
    const [layer, pid] = key.split("/");
    if (pid === id && line.includes(FOLDER[layer] + "\\\\")) return line.replace(/unlock = "rank:\d+"/, `unlock = "rank:${rank}"`);
  }
  return line;
}).join(nl));
rewrite("tools/convert-art.js", (s) => {
  for (const [key, rank] of Object.entries(RANKS)) s = s.replace(new RegExp(`("${key}": )"rank:\\d+"`), `$1"rank:${rank}"`);
  return s.replace("(Ranks.lua RANK_PIECES, 2026-11-05)", "(Ranks.lua's piece perks; from rank 3, when minting opens: 2026-11-05)");
});
rewrite("Frames.lua", (s) => s.replace('name = "Polaroid", unlock = "rank:2"', `name = "Polaroid", unlock = "rank:${FRAMES.polaroid}"`)
  .replace('name = "Honey Wood", unlock = "rank:3"', `name = "Honey Wood", unlock = "rank:${FRAMES.wood}"`));
rewrite("tools/convert-frames.js", (s) => s.replace('name: "Polaroid", unlock: "rank:2"', `name: "Polaroid", unlock: "rank:${FRAMES.polaroid}"`)
  .replace('name: "Honey Wood", unlock: "rank:3"', `name: "Honey Wood", unlock: "rank:${FRAMES.wood}"`));

// Ranks.lua: the perks with short labels (short; a piece's is its name, in its rarity's colour: ns.PerkLabel).
const SHORT = {
  "Two more ogre crayons (ogre mode's letters)": "2 crayons", "Silver name on your card": "Silver name",
  "Your ogre in pencil sketch (EDIT's STYLE)": "Pencil sketch", "Ogre voices on clicks twice as often": "Voices x2",
  "Lucky minting: epic and legendary layers 25% likelier": "Luck +25%", "Gold name on your card": "Gold name",
  "Two more ogre crayons": "2 crayons", "Your ogre in crayon (EDIT's STYLE)": "Crayon style",
  "Ogre voices on clicks three times as often": "Voices x3", "Luckier minting: epic and legendary layers 50% likelier": "Luck +50%",
  "Three more ogre crayons": "3 crayons", "The Blue Blocks wallpaper (EDIT's Wallpaper)": "Blue Blocks wallpaper",
  "Ogre-orange name on your card": "Orange name", "Luckiest minting: epic and legendary layers twice as likely": "Luck x2",
  "Grand Sleepy Ogre pink name on your card": "Pink name",
};
rewrite("Ranks.lua", (s, nl) => {
  for (const [text, short] of Object.entries(SHORT)) {
    const from = `text = "${text}" }`;
    if (!s.includes(from)) throw Error("perk text: " + text);
    s = s.split(from).join(`text = "${text}", short = "${short}" }`);
  }
  // pieces: their new ranks, and no text of their own (ns.PerkLabel builds it)
  s = s.replace(/    \{ rank = \d+, kind = "piece", key = "(\w+):(\w+)", text = "[^"]*" \},/g, (m, layer, id) => {
    const rank = layer === "skin" && id === "grand_sleepy_pink" ? 30 : RANKS[`${layer}/${id}`];
    if (!rank) throw Error("no rank for " + layer + "/" + id);
    return `    { rank = ${rank}, kind = "piece", key = "${layer}:${id}" },`;
  });
  s = s.replace(/    \{ rank = (\d+), kind = "frame", text = "The ([^"]+) picture frame" \},/g, (m, rank, name) => {
    const r = name === "Polaroid" ? FRAMES.polaroid : name === "Honey Wood" ? FRAMES.wood : +rank;
    return `    { rank = ${r}, kind = "frame", short = "${name} frame" },`;
  });
  s = s.replace("legendaries that used to be free, one a rank (2026-11-05). CheckRank unlocks them.",
    "legendaries that used to be free, one a rank from 3, when minting opens (2026-11-05). CheckRank unlocks them.");
  return s;
});
console.log("done");
