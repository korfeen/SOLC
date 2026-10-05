-- Points: earned by killing, finding new mobs, killing leaders, achievements, PvP and guild activities
-- (Guild.lua); spent in the Collection (Collection.lua). Kill points are counted as kills happen
-- (KillTrackerDB.points.kills); everything else is worked out from the stats, so it also credits what was
-- done before points existed, and follows changes to the values. The values are guild settings (Config.lua).

local _, ns = ...

-- Setting keys (Config.lua) per rank, leader kind and achievement tier.
local RANK_SETTING = { ["Elite"] = "killElite", ["Rare"] = "killRare", ["Rare Elite"] = "killRareElite", ["Boss"] = "killBoss" }
local LEADER_SETTING = { faction = "leaderTribe", subtype = "leaderCreature", race = "leaderRace" }
local function TierPoints(kills) return ns.Config("ach" .. kills) or 0 end

-- Highest level that's grey (no XP) for a player of the given level, as in Classic.
local function GreyLevel(playerLevel)
    if playerLevel <= 5 then return 0 end
    if playerLevel <= 39 then return playerLevel - 5 - math.floor(playerLevel / 10) end
    if playerLevel <= 59 then return playerLevel - 1 - math.floor(playerLevel / 5) end
    return playerLevel - 9
end

local issecret = issecretvalue or function() return false end

local function KillPoints(c, unit)
    local level = unit and UnitLevel(unit)
    if level and not issecret(level) and level > 0 and level <= GreyLevel(UnitLevel("player")) then
        return 0  -- grey mob
    end
    return ns.Config(RANK_SETTING[c.rank] or "killNormal")
end
ns.KillPoints = KillPoints

-- [npcID] = { [kind] = true } for every leader: tribe (faction), creature (subtype) or race.
local leaderKinds
local function LeaderKinds()
    if not leaderKinds then
        leaderKinds = {}
        for kind, list in pairs({ faction = ns.Leaders, subtype = ns.SubtypeLeaders, race = ns.RaceLeaders }) do
            for _, leaders in pairs(list or {}) do
                for _, leader in ipairs(leaders) do
                    leaderKinds[leader[1]] = leaderKinds[leader[1]] or {}
                    leaderKinds[leader[1]][kind] = true
                end
            end
        end
    end
    return leaderKinds
end

-- True if npcID leads a tribe, a creature kind or a race (it has a crown in the window).
function ns.IsLeader(npcID)
    return LeaderKinds()[npcID] ~= nil
end

-- Points for killing a leader (once), the highest if it leads several things; nil if not a leader.
local function LeaderPoints(npcID)
    local kinds = LeaderKinds()[npcID]
    if not kinds then return end
    local best = 0
    for kind in pairs(kinds) do best = math.max(best, ns.Config(LEADER_SETTING[kind])) end
    return best
end

local function AchievementPoints(id)
    local dimension, kills = id:match("^(%a+):.*:(%d+)$")
    kills = tonumber(kills)
    if dimension == "faction" then return kills == 1000 and ns.Config("achTribe") or 0 end
    return TierPoints(kills)
end
ns.AchievementPoints = AchievementPoints

-- Points of KillTrackerDB or a friend's stats: { kills, newMobs, leaders, achievements, pvp, guildGroup, dungeons,
-- bounty, earned, spent, balance }.
-- Friends' kill points aren't synced, so they're estimated at 1 per kill.
function ns.GetPoints(source)
    source = source or KillTrackerDB
    local p = { newMobs = 0, leaders = 0, achievements = 0 }
    local newMob = ns.Config("newMob")
    for npcID in pairs(source.kills) do
        p.newMobs = p.newMobs + newMob
        p.leaders = p.leaders + (LeaderPoints(npcID) or 0)
    end
    if source.achievements then
        for id in pairs(source.achievements) do p.achievements = p.achievements + AchievementPoints(id) end
    else
        for _, row in ipairs(ns.GetAchievementProgress(source)) do
            for _, tier in ipairs(row.tiers) do
                if tier.earned then p.achievements = p.achievements + (row.tribe and ns.Config("achTribe") or TierPoints(tier.kills)) end
            end
        end
    end
    p.kills = source.points and source.points.kills or source.total or 0
    p.pvp = (source.pvp and source.pvp.total or 0) * ns.Config("pvpKill")
    p.spent = source.points and source.points.spent or 0
    -- Guild group bonuses come in quarter points; only whole points count.
    p.guildGroup = math.floor(source.points and source.points.guildGroup or 0)
    p.dungeons = source.points and source.points.dungeons or 0
    p.bounty = source.points and source.points.bounty or 0
    p.earned = p.kills + p.newMobs + p.leaders + p.achievements + p.pvp + p.guildGroup + p.dungeons + p.bounty
    p.balance = p.earned - p.spent
    return p
end

table.insert(ns.KillHandlers, function(npcID, entry, c, unit)
    local points = KillTrackerDB.points
    points.kills = points.kills + KillPoints(c, unit)
    local leader = LeaderPoints(npcID)
    if leader and entry.count == 1 then
        ns.ShowToast("record", "Leader slain!", entry.name, ("+%d points"):format(leader))
        if ns.AddEvent then ns.AddEvent("L", npcID) end
    elseif entry.count == 1 and (c.rank == "Rare" or c.rank == "Rare Elite") and ns.AddEvent then
        ns.AddEvent("R", npcID)
    end
end)
