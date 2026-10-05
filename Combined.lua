-- Combined stats of you and everyone you follow, with mobs killed together counted once.
-- Solo kills can't overlap (other players see the mob as tapped), so they simply add up. Kills made in
-- a group carry a spawn key (Core.lua), and the combined total counts each key once, however many
-- group members recorded it. Group kills recorded before 0.10.0 have no key and count as solo kills.

local _, ns = ...

-- Spawn keys of a player's group kills: { [spawnKey] = npcID }.
local function MyGroupKills()
    local keys = {}
    for _, g in ipairs(KillTrackerDB.groupLog) do keys[g.k] = g.n end
    return keys
end

-- Returns stats shaped like KillTrackerDB (kills, records, total) plus members = number of players.
-- Records show who holds them; achievements are derived from the combined counts.
function ns.BuildCombined()
    local combined = { kills = {}, records = {}, total = 0, members = 0 }
    local together = {}  -- [spawnKey] = npcID, across everyone

    local function Add(holder, stats, groupKills)
        combined.members = combined.members + 1
        local groupCounts = {}
        for key, npcID in pairs(groupKills) do
            groupCounts[npcID] = (groupCounts[npcID] or 0) + 1
            together[key] = npcID
        end
        for npcID, e in pairs(stats.kills) do
            local c = combined.kills[npcID]
            if not c then
                c = { count = 0, name = e.name, type = e.type, rank = e.rank, family = e.family, subtype = e.subtype }
                combined.kills[npcID] = c
            end
            c.count = c.count + math.max(0, e.count - (groupCounts[npcID] or 0))  -- solo kills only
            if e.maxWeight and e.maxWeight > (c.maxWeight or 0) then c.maxWeight = e.maxWeight end
        end
        for key, r in pairs(stats.records) do
            local best = combined.records[key]
            if not best or r.weight > best.weight then
                combined.records[key] = { name = r.name, weight = r.weight, mob = ("%s (%s)"):format(r.mob, holder),
                    zone = r.zone, time = r.time }
            end
        end
    end

    Add(ns.MyName(), KillTrackerDB, MyGroupKills())
    for _, friend in ipairs(ns.GetFriends()) do
        Add(friend.name, friend.stats, friend.stats.group or {})
    end

    for _, npcID in pairs(together) do
        local c = combined.kills[npcID]
        if c then c.count = c.count + 1 end
    end
    for _, c in pairs(combined.kills) do
        combined.total = combined.total + c.count
    end
    return combined
end
