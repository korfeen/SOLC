// One-off (2026-11-05): the rotation's posters fit a bracket only if they start near its bottom (the first bracket,
// 1-20: by level 13; the others: within 5 levels of their start) - a level 11 had Orcs, Venture Company, VanCleef and
// 25 elites. Some posters get levels; the Alliance starter zones' tribes join (Frostmane trolls, Riverpaw and Redridge
// gnolls).
const fs = require("fs");
const path = require("path");
process.chdir(path.join(__dirname, ".."));
let s = fs.readFileSync("Posters.lua", "utf8");
const nl = s.includes("\r\n") ? "\r\n" : "\n";
function rep(a, b) {
  a = a.split("\n").join(nl); b = b.split("\n").join(nl);
  if (s.split(a).length !== 2) throw Error(a.slice(0, 70));
  s = s.replace(a, () => b);
}
rep(`    defias = { 10, 25 }, venture = { 10, 40 },`, `    defias = { 10, 25 }, venture = { 15, 40 },`);
rep(`    demon = { 20, 60 }, pvp = { 21, 60 },`,
`    demon = { 20, 60 }, pvp = { 21, 60 }, undead = { 18, 60 }, elemental = { 15, 60 }, dragonkin = { 30, 60 },
    elites = { 15, 60 }, dungeons = { 15, 60 },
    -- (the Alliance starter zones' tribes: custom bounties, tribe_<faction squashed>)
    tribe_trollfrostmane = { 5, 12 }, tribe_gnollriverpaw = { 10, 20 }, tribe_gnollredridge = { 15, 25 },`);
rep(`    kind_kobold = "crit_kobold", kind_gnoll = "crit_gnoll", kind_trogg = "crit_trogg",  -- (the Alliance starter zones' foes)`,
`    kind_kobold = "crit_kobold", kind_gnoll = "crit_gnoll", kind_trogg = "crit_trogg",  -- (the Alliance starter zones' foes)
    tribe_trollfrostmane = "crit_troll", tribe_gnollriverpaw = "crit_gnoll", tribe_gnollredridge = "crit_gnoll",`);
rep(`-- Whether a poster fits a bracket's levels.
local function Fits(poster, bracket)
    local l, b = poster.levels, BRACKETS[bracket]
    return not l or not b or (l[1] <= b[2] and l[2] >= b[1])
end`,
`-- Whether a poster fits a bracket's levels: it reaches into the bracket, and starts near its bottom - by level 13 in
-- the first (1-20, it goes fast), within 5 levels of the start in the others - so nobody gets a poster for later.
local function Fits(poster, bracket)
    local l, b = poster.levels, BRACKETS[bracket]
    return not l or not b or (l[1] <= (bracket == 1 and 13 or b[1] + 5) and l[2] >= b[1])
end`);
rep(`    wanted_thanes = "Alliance" }`,
`    wanted_thanes = "Alliance", tribe_trollfrostmane = "Alliance", tribe_gnollriverpaw = "Alliance", tribe_gnollredridge = "Alliance" }`);
rep(`local EXTRA = { "kind_kobold", "kind_gnoll", "kind_trogg" }`,
`local EXTRA = { "kind_kobold", "kind_gnoll", "kind_trogg", "tribe_trollfrostmane", "tribe_gnollriverpaw", "tribe_gnollredridge" }`);
fs.writeFileSync("Posters.lua", s);
console.log("done");
