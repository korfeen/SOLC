// One-off (2026-11-05): this week's HUNT and CLAN posters make their kills worth more kill points all week (Config
// "bountyKillBonus", % extra), and the rotation's "Rare Hunters" odd job becomes one named rare, at the bracket's levels
// and in a zone of the guild's side (Rares.lua).
const fs = require("fs");
const path = require("path");
process.chdir(path.join(__dirname, ".."));
function edit(f, pairs) {
  let s = fs.readFileSync(f, "utf8");
  const nl = s.includes("\r\n") ? "\r\n" : "\n";
  for (let [a, b] of pairs) {
    a = a.split("\n").join(nl); b = b.split("\n").join(nl);
    if (s.split(a).length !== 2) throw Error(f + ": " + a.slice(0, 70));
    s = s.replace(a, () => b);
  }
  fs.writeFileSync(f, s);
}
edit("Config.lua", [[
`    { key = "bountyReward", label = "Reward", default = 100, min = 0, max = 100000 },`,
`    { key = "bountyReward", label = "Reward", default = 100, min = 0, max = 100000 },
    { key = "bountyKillBonus", label = "Hunt and clan kills: % more kill points", default = 100, min = 0, max = 1000 },`]]);
edit("Points.lua", [[
`    points.kills = points.kills + KillPoints(c, unit)`,
`    local base = KillPoints(c, unit)
    -- (a kill this week's HUNT or CLAN poster wants: more, all week; Posters.lua)
    if base > 0 and ns.PosterKillBonus and ns.PosterKillBonus(npcID, entry, c) then
        base = base + math.floor(base * (ns.Config("bountyKillBonus") or 0) / 100 + 0.5)
    end
    points.kills = points.kills + base`]]);
edit("Posters.lua", [[
`    local piece = POSTER_OGRE[id]
    if not piece then return end`,
`    local piece = POSTER_OGRE[id] or (id:find("^rare_") and POSTER_OGRE.rares)  -- (a named rare: the Rare Hunters' ogre)
    if not piece then return end`],
[`local PICK_ONLY = { gather = true }`,
`local PICK_ONLY = { gather = true }
-- The rotation's "Rare Hunters" is one named rare instead (rare_<npcID>): out in the world (no dungeons or cities), not
-- elite (but at 60), at the bracket's levels (the first: the starter zones on), in a zone of the guild's side.
local RARE_LEVELS = { { 6, 17 }, { 18, 29 }, { 28, 39 }, { 38, 49 }, { 48, 59 }, { 55, 63 } }
local NOT_WORLD = { ["Blackrock Depths"] = true, ["Blackrock Mountain"] = true, ["Blackrock Spire"] = true,
    ["Dire Maul"] = true, ["Gnomeregan"] = true, ["Maraudon"] = true, ["Razorfen Kraul"] = true, ["Scarlet Monastery"] = true,
    ["Shadowfang Keep"] = true, ["Stormwind City"] = true, ["Stratholme"] = true, ["Sunken Temple"] = true,
    ["The Deadmines"] = true, ["The Stockade"] = true, ["Uldaman"] = true, ["Wailing Caverns"] = true, ["Zul'Farrak"] = true }
local ZONE_SIDE = { ["Durotar"] = "Horde", ["Mulgore"] = "Horde", ["Tirisfal Glades"] = "Horde", ["Silverpine Forest"] = "Horde",
    ["The Barrens"] = "Horde", ["Elwynn Forest"] = "Alliance", ["Dun Morogh"] = "Alliance", ["Teldrassil"] = "Alliance",
    ["Westfall"] = "Alliance", ["Loch Modan"] = "Alliance", ["Darkshore"] = "Alliance", ["Redridge Mountains"] = "Alliance",
    ["Duskwood"] = "Alliance", ["Wetlands"] = "Alliance" }
local rarePools = {}
local function RarePool(bracket)
    local side = UnitFactionGroup and UnitFactionGroup("player")
    local key = tostring(bracket) .. ":" .. tostring(side)
    if rarePools[key] then return rarePools[key] end
    local pool, levels = {}, RARE_LEVELS[bracket] or RARE_LEVELS[1]
    for npcID, r in pairs(ns.Rares or {}) do
        local zone = ns.RareZones and ns.RareZones[r[2]]
        local zoneSide = zone and ZONE_SIDE[zone]
        if zone and not NOT_WORLD[zone] and not (zoneSide and side and zoneSide ~= side)
            and r[3] >= levels[1] and r[3] <= levels[2] and (not r[4] or bracket == #RARE_LEVELS) then
            pool[#pool + 1] = npcID
        end
    end
    table.sort(pool)  -- (pairs has no order: sorted, every member's addon agrees)
    rarePools[key] = pool
    return pool
end`],
[`    local key = id:match("^wanted_(%w+)$")
    if key then`,
`    local key = id:match("^wanted_(%w+)$")
    local rareID = tonumber(id:match("^rare_(%d+)$") or "")
    if rareID then  -- (a named rare: one kill)
        local r = ns.Rares and ns.Rares[rareID]
        if not r then return end
        local zone = ns.RareZones and ns.RareZones[r[2]] or "?"
        poster = { id = id, name = r[1], short = r[1], tier = "hard", kind = "odd", solo = 1, rare = rareID,
            desc = ("A rare, level %d, somewhere in %s. Find it before someone else does."):format(r[3], zone),
            objective = "FIND & SMASH", count = function(npcID) return npcID == rareID end }
    elseif key then`],
[`    if goal then return goal end
    if poster.wanted then return 1 end`,
`    if goal then return goal end
    if poster.wanted or poster.rare then return 1 end`],
[`        local id = pool[(start + i) % #pool + 1]
        if not taken[id] and not PICK_ONLY[id] then return id end`,
`        local id = pool[(start + i) % #pool + 1]
        if id == "rares" then  -- (one named rare, by the same hash)
            local rares = RarePool(bracket)
            local rare = #rares > 0 and ("rare_" .. rares[math.floor(h / 1024) % #rares + 1])
            if rare and not taken[rare] then return rare end
        elseif not taken[id] and not PICK_ONLY[id] then return id end`],
[`table.insert(ns.KillHandlers, function(npcID, entry, c)
    CountWhere(function(bounty) return bounty.count and bounty.count(npcID, entry, c) end)
end)`,
`table.insert(ns.KillHandlers, function(npcID, entry, c)
    CountWhere(function(bounty) return bounty.count and bounty.count(npcID, entry, c) end)
end)

-- Whether a kill is one this week's HUNT or CLAN poster wants (claimed or not): it's worth more kill points all week
-- (Points.lua). Not before the board opens, nor while pretending a rank.
function ns.PosterKillBonus(npcID, entry, c)
    if ns.RankLocked and ns.RankLocked("bounties") then return false end
    if ns.Pretending and ns.Pretending() then return false end
    local board = MyBoard()
    if not board then return false end
    for _, p in ipairs(board.posters) do
        local b = p.bounty
        if (b.kind == "hunt" or b.kind == "clan") and b.count and b.count(npcID, entry, c) then return true end
    end
    return false
end`]]);
edit("HuntsBoard.lua", [[
`    if e and e.ends > 0 then line[#line + 1] = "down in " .. ns.BountyTimeLeft(e.ends - GetServerTime()) end`,
`    if e and e.ends > 0 then line[#line + 1] = "down in " .. ns.BountyTimeLeft(e.ends - GetServerTime()) end
    local bonus = ns.Config("bountyKillBonus") or 0
    if bonus > 0 and (p.bounty.kind == "hunt" or p.bounty.kind == "clan") then  -- (its kills worth more all week: Points.lua)
        line[#line + 1] = ("kills +%d%% points all week"):format(bonus)
    end`]]);
console.log("done");
