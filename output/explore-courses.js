// One-off (2026-11-05): exploring a zone fully is a deed (its world map's fog all gone: the explored map pieces against
// the zone's total, from the game data - output/explore/*.csv, wago.tools, build 1.60.1.70205), and the zone's golf
// course background is its reward (no longer a Pro Shop item). Ironforge and Darnassus are left out (cities: nothing to
// explore).
const fs = require("fs");
const path = require("path");
process.chdir(path.join(__dirname, ".."));
function edit(file, pairs) {
  let s = fs.readFileSync(file, "utf8");
  const nl = s.includes("\r\n") ? "\r\n" : "\n";
  for (const [a, b] of pairs) {
    const from = a.replace(/\n/g, nl), to = b.replace(/\n/g, nl);
    const n = s.split(from).length - 1;
    if (n !== 1) throw Error(`${file}: found ${n} times: ${a.slice(0, 70)}`);
    s = s.replace(from, () => to);
  }
  fs.writeFileSync(file, s);
}
// zone key, name, its uiMap, its map pieces in all, the deed's name; the course's id
const ZONES = [
  ["elwynn", "Elwynn Forest", 1429, 12, "Lost In Elwynn", "zone_elwynn"],
  ["dunmorogh", "Dun Morogh", 1426, 18, "Snow Angel", "zone_dunmorogh"],
  ["westfall", "Westfall", 1436, 14, "Scarecrow's Tour", "zone_westfall"],
  ["redridge", "Redridge Mountains", 1433, 11, "Red All Over", "zone_redridge"],
  ["needles", "Thousand Needles", 1441, 9, "Needle Threader", "zone_needles"],
];

edit("Achievements.lua", [
[`FEATS[#FEATS + 1] = { key = "dungeons", label = "Dungeons cleared", unit = "dungeons", dungeon = true,
    count = function(_, f) return f.dungeonsCleared end, tiers = VARIETY }
`,
`FEATS[#FEATS + 1] = { key = "dungeons", label = "Dungeons cleared", unit = "dungeons", dungeon = true,
    count = function(_, f) return f.dungeonsCleared end, tiers = VARIETY }

-- Exploration: a zone's whole world map uncovered (its explored map pieces, C_MapExplorationInfo, against all of them:
-- the game data's WorldMapOverlay rows for the zone's map art, build 1.60.1.70205). Its golf course background is the
-- reward (tools/gen-art-zone-courses.json: unlock "deed:feat:explore:<key>:<pieces>"). Yours only.
-- { key, zone, uiMap, pieces, deed name }
local EXPLORE = {
${ZONES.map(([k, n, m, p, d]) => `    { "${k}", "${n}", ${m}, ${p}, "${d.replace(/"/g, '\\"')}" },`).join("\n")}
}
local function Explored(uiMap)
    local textures = C_MapExplorationInfo and C_MapExplorationInfo.GetExploredMapTextures and C_MapExplorationInfo.GetExploredMapTextures(uiMap)
    return textures and #textures or 0
end
for _, z in ipairs(EXPLORE) do
    FEATS[#FEATS + 1] = { key = "explore:" .. z[1], label = "Explore " .. z[2], unit = "map pieces", group = "Exploration",
        count = function(source) if source == KillTrackerDB then return Explored(z[3]) end end,
        tiers = { { z[4], z[5], 25 } } }
end
`],
[`ns.DEED_GROUPS = { "Creatures", "Tribes", "Hunting", "Rares", "Dungeons", "Pictures", "Professions", "Club life", "Secrets" }`,
 `ns.DEED_GROUPS = { "Creatures", "Tribes", "Hunting", "Rares", "Dungeons", "Exploration", "Pictures", "Professions", "Club life", "Secrets" }`],
]);

edit("LifeStats.lua", [[
`    if added then Changed(life) end`,
`    if added then
        Changed(life)
        if ns.CheckAchievements then ns.CheckAchievements() end  -- (somewhere new: the exploration deeds, Achievements.lua)
    end`]]);

// The courses: Ironforge and Darnassus out; the rest unlocked by their zone's deed, not sold.
const file = "tools/gen-art-zone-courses.json";
const list = JSON.parse(fs.readFileSync(file, "utf8")).filter((c) => !["zone_ironforge", "zone_darnassus"].includes(c.id));
for (const c of list) {
  const z = ZONES.find((zz) => zz[5] === c.id);
  if (!z) throw Error("no zone for " + c.id);
  delete c.shop;
  c.unlock = `deed:feat:explore:${z[0]}:${z[3]}`;
}
fs.writeFileSync(file, JSON.stringify(list, null, 1));
console.log("done", list.map((c) => c.id + " " + c.unlock).join(", "));
