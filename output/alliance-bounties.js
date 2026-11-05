// One-off (2026-11-05, launch week): the bounty rotation fits the guild's side - posters only the other faction meets at
// those levels are left out (by the player's faction: a guild is one faction, so every member's addon still agrees) -
// and the Alliance starter zones' foes join the easy pool: kobolds, gnolls, troggs. Raptors and orcs get level ranges.
const fs = require("fs");
const path = require("path");
process.chdir(path.join(__dirname, ".."));
const f = "Posters.lua";
let s = fs.readFileSync(f, "utf8");
const nl = s.includes("\r\n") ? "\r\n" : "\n";
function rep(a, b) {
  a = a.split("\n").join(nl); b = b.split("\n").join(nl);
  if (s.split(a).length !== 2) throw Error(a.slice(0, 60));
  s = s.replace(a, () => b);
}
rep(`    deadwind = { 55, 60 }, urok = { 54, 60 },`,
`    deadwind = { 55, 60 }, urok = { 54, 60 },
    -- (creatures met only from these levels on; and the Alliance starter zones' foes, custom bounties: kind_<subtype>)
    Raptor = { 20, 60 }, Orc = { 15, 60 }, kind_kobold = { 1, 25 }, kind_gnoll = { 1, 35 }, kind_trogg = { 1, 30 },`);
rep(`-- The rotation's pool for a tier and bracket: catalogue bounties, and for hard also the dungeons' wanted posters, that
-- fit the bracket's levels.
local pools = {}
local function Pool(tier, bracket)
    local key = tier .. ":" .. tostring(bracket)
    if pools[key] then return pools[key] end
    local pool = {}
    for _, bounty in ipairs(ns.BOUNTIES or {}) do
        local poster = TIERS[bounty.id] and TIERS[bounty.id][1] == tier and PosterBounty(bounty.id)
        if poster and Fits(poster, bracket) then pool[#pool + 1] = bounty.id end
    end
    if tier == "hard" then
        for _, d in ipairs(ns.Dungeons and ns.Dungeons() or {}) do
            local poster = WANTED[d.key] and not d.raid and PosterBounty("wanted_" .. d.key)
            if poster and Fits(poster, bracket) then pool[#pool + 1] = poster.id end
        end
    end`,
`-- The rotation's pool for a tier and bracket: catalogue bounties, and for hard also the dungeons' wanted posters, that
-- fit the bracket's levels - and the guild's side: SIDE marks the ones only one faction meets at their levels (the
-- player's faction stands for the guild's: a guild is one faction, so every member's addon agrees). EXTRA: custom
-- bounties in the rotation too (the Alliance starter zones' foes), by tier.
local SIDE = { kolkar = "Horde", burningblade = "Horde", Scorpid = "Horde", wanted_rfc = "Horde", wanted_ruins = "Horde",
    wanted_thanes = "Alliance" }
local EXTRA = { easy = { "kind_kobold", "kind_gnoll", "kind_trogg" } }
local pools = {}
local function Pool(tier, bracket)
    local side = UnitFactionGroup and UnitFactionGroup("player")
    local key = tier .. ":" .. tostring(bracket) .. ":" .. tostring(side)
    if pools[key] then return pools[key] end
    local pool = {}
    local function OurSide(id) return not (SIDE[id] and side and SIDE[id] ~= side) end
    for _, bounty in ipairs(ns.BOUNTIES or {}) do
        local poster = TIERS[bounty.id] and TIERS[bounty.id][1] == tier and PosterBounty(bounty.id)
        if poster and Fits(poster, bracket) and OurSide(bounty.id) then pool[#pool + 1] = bounty.id end
    end
    for _, id in ipairs(EXTRA[tier] or {}) do
        local poster = PosterBounty(id)
        if poster and Fits(poster, bracket) and OurSide(id) then pool[#pool + 1] = id end
    end
    if tier == "hard" then
        for _, d in ipairs(ns.Dungeons and ns.Dungeons() or {}) do
            local poster = WANTED[d.key] and not d.raid and PosterBounty("wanted_" .. d.key)
            if poster and Fits(poster, bracket) and OurSide(poster.id) then pool[#pool + 1] = poster.id end
        end
    end`);
fs.writeFileSync(f, s);
console.log("done");
