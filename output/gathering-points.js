// One-off (2026-11-05): every profession earns points. Gathering (herbs, ore, skins, fish) counts each node, corpse or
// catch (a life stat: Share / Just me / Off) for points and deed ladders; every profession's skill points earn points
// too, by your best level ever in it, and your best profession level has deeds of its own.
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

edit("LifeStats.lua", [
[`    { key = "gold", name = "Gold", desc = "Gold that came in (loot, quests, sales, trades, the mail) and went out." },
}`,
`    { key = "gold", name = "Gold", desc = "Gold that came in (loot, quests, sales, trades, the mail) and went out." },
    { key = "gathering", name = "Gathering", desc = "Herbs picked, ore mined, beasts skinned and fish caught: points for each, and deeds." },
}`],
[`    if shared("gold") then out.goldIn, out.goldOut = life.goldIn, life.goldOut end
    return out`,
`    if shared("gold") then out.goldIn, out.goldOut = life.goldIn, life.goldOut end
    if shared("gathering") then out.herbs, out.ore, out.skins, out.fish = life.herbs or 0, life.ore or 0, life.skins or 0, life.fish or 0 end
    return out`],
[`local napTicker, napUnsynced = nil, 0
local frame = CreateFrame("Frame")`,
`-- Gathering: a herb picked, ore mined or a beast skinned (its cast, then the loot window it opens), or a fish caught
-- (fishing loot): one each, whatever it gives (life.herbs / ore / skins / fish). Each is points too (the guild's
-- "gather" setting, KillTrackerDB.points.gather) and counts for its deeds (Achievements.lua).
local GATHER_IDS = { [2366] = "herbs", [2368] = "herbs", [3570] = "herbs", [11993] = "herbs",
    [2575] = "ore", [2576] = "ore", [3564] = "ore", [10248] = "ore", [8613] = "skins", [8617] = "skins", [8618] = "skins", [10768] = "skins" }
local GATHER_NAMES = { ["Herb Gathering"] = "herbs", ["Mining"] = "ore", ["Skinning"] = "skins" }  -- (other ranks, by name)
local pendingGather, pendingAt
local function GatherKind(spellID)
    if not spellID or issecret(spellID) then return end
    if GATHER_IDS[spellID] then return GATHER_IDS[spellID] end
    local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID) or (GetSpellInfo and GetSpellInfo(spellID))
    if name and not issecret(name) then return GATHER_NAMES[name] end
end
local function Gathered(kind)
    if not (KillTrackerDB and Counting("gathering")) then return end
    local life = Life()
    life[kind] = (life[kind] or 0) + 1
    local points = KillTrackerDB.points
    if points then
        points.gather = (points.gather or 0) + (ns.Config("gather") or 0)
        ns.Touch(points)
    end
    Changed(life)
    if ns.CheckAchievements then ns.CheckAchievements() end
end

local napTicker, napUnsynced = nil, 0
local frame = CreateFrame("Frame")
frame:RegisterEvent("LOOT_OPENED")
if frame.RegisterUnitEvent then frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player") end`],
[`frame:SetScript("OnEvent", function(_, event)
    if not KillTrackerDB then return end
    local life = Life()
    if event == "PLAYER_ENTERING_WORLD" then`,
`frame:SetScript("OnEvent", function(_, event, ...)
    if not KillTrackerDB then return end
    local life = Life()
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local kind = GatherKind(select(3, ...))
        if kind then pendingGather, pendingAt = kind, GetTime() end
    elseif event == "LOOT_OPENED" then
        if IsFishingLoot and IsFishingLoot() then Gathered("fish")
        elseif pendingGather and GetTime() - pendingAt < 5 then Gathered(pendingGather) end
        pendingGather = nil
    elseif event == "PLAYER_ENTERING_WORLD" then`],
]);

edit("Sync.lua", [
[`    return table.concat({ "L", N36(l.nap), N36(l.deaths), N36(l.quests), N36(l.places), N36(l.goldIn), N36(l.goldOut) }, FIELD)`,
 `    return table.concat({ "L", N36(l.nap), N36(l.deaths), N36(l.quests), N36(l.places), N36(l.goldIn), N36(l.goldOut),
        N36(l.herbs), N36(l.ore), N36(l.skins), N36(l.fish) }, FIELD)  -- (gathering: added at the end, older versions skip it)`],
[`local LIFE_FIELDS = { "nap", "deaths", "quests", "places", "goldIn", "goldOut" }`,
 `local LIFE_FIELDS = { "nap", "deaths", "quests", "places", "goldIn", "goldOut", "herbs", "ore", "skins", "fish" }`],
[`                N36(s.life.nap), N36(s.life.deaths), N36(s.life.quests), N36(s.life.places), N36(s.life.goldIn), N36(s.life.goldOut) }, FIELD)`,
 `                N36(s.life.nap), N36(s.life.deaths), N36(s.life.quests), N36(s.life.places), N36(s.life.goldIn), N36(s.life.goldOut),
                N36(s.life.herbs), N36(s.life.ore), N36(s.life.skins), N36(s.life.fish) }, FIELD)`],
]);

edit("Config.lua", [[
`    { key = "pvpKill", label = "PvP kill", default = 3, min = 0, max = 1000 },`,
`    { key = "pvpKill", label = "PvP kill", default = 3, min = 0, max = 1000 },
    { heading = "Professions" },
    { key = "gather", label = "Gathering (herb, ore, skin, fish)", default = 1, min = 0, max = 1000 },
    { key = "skillPoint", label = "Profession skill point", default = 1, min = 0, max = 1000 },`]]);

edit("Professions.lua", [[
`    local p = Professions()
    local same = #list == #p.list`,
`    local p = Professions()
    -- Each profession's best level ever (p.best = { [line] = rank }): its skill points earn points (Points.lua), and
    -- dropping it never takes them back.
    p.best = p.best or {}
    local better = false
    for _, prof in ipairs(list) do
        if (prof.rank or 0) > (p.best[prof.line] or 0) then p.best[prof.line], better = prof.rank, true end
    end
    if better and ns.CheckAchievements then ns.CheckAchievements() end
    local same = #list == #p.list`]]);

edit("Points.lua", [
[`    p.chests = source.points and source.points.chests or 0  -- coins from dungeon chests (Unlocks.lua)
    p.earned = p.kills + p.newMobs + p.leaders + p.achievements + p.pvp + p.guildGroup + p.dungeons + p.bounty + p.chests`,
`    p.chests = source.points and source.points.chests or 0  -- coins from dungeon chests (Unlocks.lua)
    -- Professions: each gather (LifeStats.lua) as it happens, and every skill point by each profession's best level ever
    -- (Professions.lua; a guildmate's: the levels they have now).
    p.gather = source.points and source.points.gather or 0
    local skills, prof = 0, source.professions
    if prof and prof.best then for _, rank in pairs(prof.best) do skills = skills + rank end
    elseif prof then for _, entry in ipairs(prof.list or {}) do skills = skills + (entry.rank or 0) end end
    p.skills = skills * ns.Config("skillPoint")
    p.earned = p.kills + p.newMobs + p.leaders + p.achievements + p.pvp + p.guildGroup + p.dungeons + p.bounty + p.chests
        + p.gather + p.skills`],
[`-- bounty, chests, earned, spent, duels, balance }.`, `-- bounty, chests, gather, skills, earned, spent, duels, balance }.`],
]);

edit("Achievements.lua", [
[`    -- What you've spent in the Pro Shop, wallpapers too`,
`    -- Gathering (LifeStats.lua: yours; nothing counts while it's Off in Settings).
    { key = "herbs", label = "Herbs picked", unit = "herbs", count = function(_, f) return f.herbs end, tiers = {
        { 25, "Weed Puller", 5 }, { 100, "Green Thumb", 10 }, { 250, "Flower Muncher", 20 }, { 500, "Herb Hoarder", 35 },
        { 1000, "Walking Salad", 60 } } },
    { key = "ore", label = "Ore mined", unit = "nodes", count = function(_, f) return f.ore end, tiers = {
        { 25, "Rock Knocker", 5 }, { 100, "Pick Swinger", 10 }, { 250, "Vein Hunter", 20 }, { 500, "Deep Delver", 35 },
        { 1000, "Mountain Mover", 60 } } },
    { key = "skins", label = "Beasts skinned", unit = "skins", count = function(_, f) return f.skins end, tiers = {
        { 25, "Hide Peeler", 5 }, { 100, "Fur Trader", 10 }, { 250, "Pelt Pile", 20 }, { 500, "Rug Maker", 35 },
        { 1000, "Nothing Left But Bones", 60 } } },
    { key = "fish", label = "Fish caught", unit = "fish", count = function(_, f) return f.fish end, tiers = {
        { 25, "Bait Dunker", 5 }, { 100, "Reel Ogre", 10 }, { 250, "Bobber Watcher", 20 }, { 500, "Old Salt", 35 },
        { 1000, "Lake Emptier", 60 } } },
    -- Your best profession's level (Professions.lua: synced, so guildmates' show too).
    { key = "craft", label = "Best profession", unit = "skill", count = function(_, f) return f.craft end, tiers = {
        { 75, "Apprentice Ogre", 10 }, { 150, "Journeyman Ogre", 20 }, { 225, "Expert Ogre", 35 }, { 300, "Artisan Ogre", 60 } } },
    -- What you've spent in the Pro Shop, wallpapers too`],
[`    facts.showcase = source.showcase and #(source.showcase.numbers or {}) or 0`,
`    facts.showcase = source.showcase and #(source.showcase.numbers or {}) or 0
    facts.craft = 0
    local prof = source.professions
    for _, rank in pairs(prof and prof.best or {}) do facts.craft = math.max(facts.craft, rank) end
    for _, entry in ipairs(prof and prof.list or {}) do facts.craft = math.max(facts.craft, entry.rank or 0) end`],
[`        facts.bounties, facts.chests = tally.bounties or 0, tally.chests or 0`,
 `        facts.bounties, facts.chests = tally.bounties or 0, tally.chests or 0
        local life = source.life or {}
        facts.herbs, facts.ore, facts.skins, facts.fish = life.herbs or 0, life.ore or 0, life.skins or 0, life.fish or 0`],
]);
console.log("done");
