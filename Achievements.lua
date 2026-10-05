-- Kill-count achievements: per creature (subtype) in seven tiers, e.g. "Murloc Bane" for 100 murlocs of
-- any tribe, plus a single one per tribe/faction at 1000 kills, e.g. "Riverpaw Exterminator".
-- Earned achievements are stored as KillTrackerDB.achievements[id] = time earned,
-- with id = "<dimension>:<category>:<kills>", e.g. "subtype:Gnoll:100".

local _, ns = ...

local TIERS = {
    { kills = 10, title = "Novice" },
    { kills = 25, title = "Hunter" },
    { kills = 50, title = "Slayer" },
    { kills = 100, title = "Bane" },
    { kills = 250, title = "Scourge" },
    { kills = 500, title = "Nemesis" },
    { kills = 1000, title = "Exterminator" },
}
local TRIBE_TIERS = { { kills = 1000, title = "Exterminator" } }
local DIMENSIONS = {
    { key = "subtype", tiers = TIERS },
    { key = "faction", tiers = TRIBE_TIERS },
}

-- Tribe factions read better without their race: "Gnoll - Riverpaw" -> "Riverpaw", "Troll, Sandfury" -> "Sandfury".
local RACE_PREFIXES = { "Gnoll", "Ogre", "Troll", "Murloc", "Harpy", "Kobold", "Furbolg", "Trogg", "Naga", "Satyr",
    "Quilboar", "Centaur" }
local function ShortName(category)
    for _, race in ipairs(RACE_PREFIXES) do
        local tribe = category:match("^" .. race .. "[,%s%-]+(.+)$")
        if tribe then return tribe end
    end
    return category
end

local function AchievementID(dimension, category, tier)
    return ("%s:%s:%d"):format(dimension, category, tier.kills)
end

local function AchievementName(category, tier)
    return ShortName(category) .. " " .. tier.title
end

-- Returns counts[dimensionKey][category] = kills, for KillTrackerDB or a friend's stats.
local function CountKills(source)
    local counts = {}
    for _, dim in ipairs(DIMENSIONS) do counts[dim.key] = {} end
    ns.ForEachKill(function(npcID, entry)
        local c = ns.Categorize(npcID, entry)
        for _, dim in ipairs(DIMENSIONS) do
            local category = c[dim.key]
            -- A race's general faction (plain "Murloc") is already covered by the creature achievements.
            local generalFaction = dim.key == "faction" and category == c.subtype
            if not ns.NO_AWARDS[category] and not generalFaction then
                counts[dim.key][category] = (counts[dim.key][category] or 0) + entry.count
            end
        end
    end, source)
    return counts
end

-- Awards every reached tier not yet earned. Returns the number newly awarded.
local function CheckAchievements(silent)
    local earned = KillTrackerDB.achievements
    local awarded = 0
    local counts = CountKills()
    for _, dim in ipairs(DIMENSIONS) do
        for category, kills in pairs(counts[dim.key]) do
            for _, tier in ipairs(dim.tiers) do
                if kills < tier.kills then break end
                local id = AchievementID(dim.key, category, tier)
                if not earned[id] then
                    earned[id] = time()
                    awarded = awarded + 1
                    if not silent then
                        if ns.AddEvent then ns.AddEvent("A", id) end
                        local name = AchievementName(category, tier)
                        local points = ns.AchievementPoints(id)
                        ns.ShowToast("achievement", "Achievement earned!", name,
                            ("%d %s kills  -  +%d points"):format(tier.kills, ShortName(category), points))
                        ns.Print(("Achievement earned: |cffff8000%s|r (%d %s kills, +%d points)"):format(
                            name, tier.kills, ShortName(category), points))
                    end
                end
            end
        end
    end
    return awarded
end

table.insert(ns.KillHandlers, function()
    CheckAchievements(false)
end)

-- Catch up on achievements reached without a popup (e.g. tiers added later), silently.
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    local awarded = CheckAchievements(true)
    if awarded > 0 then
        ns.Print(("%d achievements awarded for earlier kills. Type /kt to see them."):format(awarded))
    end
end)

-- For the UI: one row per category with kills, with progress towards its next tier.
-- Each row: { category (display name), tribe (true for the 1000-kill tribe achievement), kills, earned (number of tiers), next (tier or nil), tiers = {...} }
-- where tiers[i] = { name, kills, earned, time (nil if unknown) }. source is KillTrackerDB (default) or a
-- friend's stats; friends' earn dates aren't synced, so their tiers count as earned once reached.
function ns.GetAchievementProgress(source)
    source = source or KillTrackerDB
    local earnedTimes = source.achievements
    local counts = CountKills(source)
    local rows = {}
    for _, dim in ipairs(DIMENSIONS) do
        for category, kills in pairs(counts[dim.key]) do
            local row = { category = ShortName(category), tribe = dim.key == "faction", kills = kills, earned = 0, tiers = {} }
            for i, tier in ipairs(dim.tiers) do
                local time = earnedTimes and earnedTimes[AchievementID(dim.key, category, tier)]
                local earned = time ~= nil or (not earnedTimes and kills >= tier.kills)
                row.tiers[i] = { name = AchievementName(category, tier), kills = tier.kills, earned = earned, time = time }
                if earned then
                    row.earned = row.earned + 1
                elseif not row.next then
                    row.next = row.tiers[i]
                end
            end
            rows[#rows + 1] = row
        end
    end
    return rows
end

function ns.GetAchievementTotals(source)
    local count = 0
    for _, row in ipairs(ns.GetAchievementProgress(source)) do count = count + row.earned end
    return count
end
