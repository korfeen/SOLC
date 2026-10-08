-- Achievements. Kill counts: per kind of creature (subtype) in seven tiers, e.g. "Kennel Closed" for 100 gnolls of
-- any tribe, and one per tribe/faction at 1000 kills, e.g. "Sent Up The River" (names: AchievementNames.lua). And
-- feats (FEATS): leaders slain, rares found, elites, variety, totals, PvP, pictures.
-- Earned achievements are stored as KillTrackerDB.achievements[id] = time earned, with id =
-- "<dimension>:<category>:<target>", e.g. "subtype:Gnoll:100" or "feat:leaders:5". Ids never change; names can.
-- Everything is worked out from synced data (kills, PvP total, pictures), so guildmates' achievements show too
-- (their earn dates aren't synced: their tiers count as earned once reached).

local _, ns = ...

local TIERS = {
    { kills = 10, points = nil }, { kills = 25 }, { kills = 50 }, { kills = 100 }, { kills = 250 }, { kills = 500 },
    { kills = 1000 },
}
local TRIBE_TIERS = { { kills = 1000 } }
local DIMENSIONS = {
    { key = "subtype", tiers = TIERS },
    { key = "faction", tiers = TRIBE_TIERS },
}

-- Tribe factions read better without their race: "Gnoll - Riverpaw" -> "Riverpaw", "Troll, Sandfury" -> "Sandfury".
local RACE_PREFIXES = { "Gnoll", "Ogre", "Troll", "Murloc", "Harpy", "Kobold", "Furbolg", "Trogg", "Naga", "Satyr",
    "Quilboar", "Centaur", "Gnome" }
local function ShortName(category)
    for _, race in ipairs(RACE_PREFIXES) do
        local tribe = category:match("^" .. race .. "[,%s%-]+(.+)$")
        if tribe then return tribe end
    end
    return category
end

local function AchievementID(dimension, category, target)
    return ("%s:%s:%d"):format(dimension, category, target)
end

local function TierName(dimension, category, tierIndex)
    if dimension == "faction" then return ns.TribeAchievementName(ShortName(category)) end
    return ns.CreatureAchievementName(category, tierIndex)
end

-- Feats: { key, label (the row's name), unit (what's counted, for "5 leaders"), count(source, facts) -> number or
-- nil (unknown for this source: the row isn't shown), tiers = { { target, name, points } } }.
local RARE_RANKS = { ["Rare"] = true, ["Rare Elite"] = true }
local ELITE_RANKS = { ["Elite"] = true, ["Rare Elite"] = true, ["Boss"] = true }
local RARITY_ORDER = { uncommon = 1, rare = 2, epic = 3, legendary = 4 }
local FEATS = {
    { key = "leaders", label = "Leaders slain", unit = "leaders", count = function(_, f) return f.leaders end, tiers = {
        { 1, "Crown Snatcher", 10 }, { 5, "Regime Change", 20 }, { 10, "Hat Collection", 30 },
        { 25, "No More Bosses", 50 }, { 50, "Throne Hoarder", 80 } } },
    { key = "rares", label = "Rares found", unit = "rares", count = function(_, f) return f.rares end, tiers = {
        { 1, "Lucky Find", 10 }, { 5, "Rare Hunter", 20 }, { 10, "Oddity Collector", 30 },
        { 25, "Nothing Rare About It", 50 }, { 50, "Rarest Of Them All", 80 }, { 100, "Rare Connoisseur", 120 },
        { 200, "Half The World's Weirdos", 200 }, { 0, "Every Last Oddball", 400 } } },  -- 0: all of them (Rares.lua)
    { key = "elites", label = "Elite kills", unit = "elites", count = function(_, f) return f.elites end, tiers = {
        { 25, "Picks On Big Guys", 10 }, { 100, "Elite Smasher", 20 }, { 500, "Bigger They Are", 40 },
        { 1000, "Elitist", 60 } } },
    { key = "variety", label = "Kinds of creature", unit = "kinds", count = function(_, f) return f.kinds end, tiers = {
        { 10, "Picky Eater", 10 }, { 25, "Varied Diet", 20 }, { 50, "Menagerie Visitor", 30 },
        { 75, "Menagerie Keeper", 50 }, { 100, "One Of Everything", 80 } } },
    { key = "census", label = "Different creatures", unit = "creatures", count = function(_, f) return f.creatures end, tiers = {
        { 100, "Getting Around", 10 }, { 500, "Seen It All", 25 }, { 1000, "Census Taker", 40 },
        { 2000, "Walking Bestiary", 60 } } },
    { key = "total", label = "Total kills", unit = "kills", count = function(source) return source.total or 0 end, tiers = {
        { 100, "Warm-Up", 5 }, { 1000, "Busy Ogre", 15 }, { 5000, "Smash Machine", 30 },
        { 10000, "Ten Thousand Thumps", 50 }, { 25000, "Extinction Event", 80 } } },
    { key = "pvp", label = "Players defeated", unit = "players", count = function(source)
        if source.pvp then return source.pvp.total or 0 end
        return source.pvpTotal
    end, tiers = {
        { 1, "First Blood", 5 }, { 10, "Horde Botherer", 15 }, { 50, "Red Name Hunter", 30 },
        { 100, "Hordebane", 50 }, { 500, "Warlord Of The Club", 80 } } },
    { key = "pictures", label = "Pictures owned", unit = "pictures", count = function(_, f) return f.pictures end, tiers = {
        { 1, "Proud Parent", 5 }, { 5, "Gallery Opening", 15 }, { 10, "Art Hoarder", 25 },
        { 25, "Museum Of Ogres", 50 } } },
    { key = "epic", label = "Epic pictures", unit = "epic or better", count = function(_, f) return f.epic end, tiers = {
        { 1, "Purple Patch", 15 }, { 5, "Art Snob", 40 } } },
    { key = "legendary", label = "Legendary pictures", unit = "legendary", count = function(_, f) return f.legendary end, tiers = {
        { 1, "Legendary Lounger", 50 } } },
    { key = "showcase", label = "Showcase", unit = "on show", count = function(_, f) return f.showcase end, tiers = {
        { 3, "Proud Display", 10 } } },
    { key = "puzzles", label = "Puzzle races won", unit = "won", count = function(_, f) return f.won end, tiers = {
        { 1, "Puzzle Pincher", 15 }, { 5, "Board Bully", 30 }, { 10, "Swap King", 50 } } },
}
-- Every rare in a zone (Rares.lua): one feat per zone, "<zone>'s Most Wanted" unless it has a name of its own.
local ZONE_RARE_NAMES = {
    ["Elwynn Forest"] = "Elwynn's Most Wanted", ["Westfall"] = "Westfall Wanted Posters", ["Dun Morogh"] = "Snowed Under",
    ["Teldrassil"] = "Tree Trimmer", ["Darkshore"] = "Shore Leave", ["Loch Modan"] = "Loch, Stock And Barrel",
    ["Redridge Mountains"] = "Red Ridge, Dead Ridge", ["Duskwood"] = "Things That Go Bump", ["Wetlands"] = "Swamp Fever",
    ["The Barrens"] = "Barrens Bounty Hunter", ["Ashenvale"] = "Ashes To Ashenvale", ["Stranglethorn Vale"] = "Jungle Law",
    ["Hillsbrad Foothills"] = "Foothill Feud", ["Arathi Highlands"] = "Highland Games", ["Desolace"] = "Desolate Indeed",
    ["Stonetalon Mountains"] = "Talon Clipper", ["Thousand Needles"] = "Needle In A Haystack", ["Dustwallow Marsh"] = "Marsh Mellow",
    ["Badlands"] = "Badlands, Good Hunting", ["Swamp of Sorrows"] = "Sorrow For Them", ["The Hinterlands"] = "Hinter No More",
    ["Feralas"] = "Feral Ogre", ["Tanaris"] = "Sand In Everything", ["Azshara"] = "Azshara's Leftovers",
    ["Searing Gorge"] = "Searing Success", ["Burning Steppes"] = "Steppe Up", ["Blasted Lands"] = "Blasted Them",
    ["Felwood"] = "Fel Swoop", ["Un'Goro Crater"] = "Crater Raider", ["Western Plaguelands"] = "Plague Doctor",
    ["Eastern Plaguelands"] = "Plague Doctor, Again", ["Winterspring"] = "Winter Is Over", ["Silithus"] = "Bug Hunt",
    ["Alterac Mountains"] = "Peak Performance", ["Silverpine Forest"] = "Pine Needles", ["Tirisfal Glades"] = "Grave Tidings",
    ["Durotar"] = "Red Dirt Rumble", ["Mulgore"] = "Moo-ving On", ["Stormwind City"] = "Sewer Rats Of Stormwind",
    ["The Deadmines"] = "Dead Mines, Deader Bosses", ["The Stockade"] = "Jailbreak", ["Wailing Caverns"] = "Stop Your Wailing",
    ["Shadowfang Keep"] = "Fangs For The Memories", ["Gnomeregan"] = "Radiation Sickness", ["Razorfen Kraul"] = "Kraul Space",
    ["Scarlet Monastery"] = "Seeing Red", ["Uldaman"] = "Uld-a-man Down", ["Zul'Farrak"] = "Farrak Out",
    ["Maraudon"] = "Purple Rain", ["Sunken Temple"] = "Sunk Costs", ["Blackrock Depths"] = "Depth Charge",
    ["Blackrock Mountain"] = "Rock Bottom Raider", ["Blackrock Spire"] = "Spire Fire", ["Dire Maul"] = "Dire Consequences",
    ["Stratholme"] = "Culling Of The Culled",
}
for index, zone in ipairs(ns.RareZones or {}) do
    local count = 0
    for _, rare in pairs(ns.Rares) do
        if rare[2] == index then count = count + 1 end
    end
    if count > 0 then
        FEATS[#FEATS + 1] = { key = "zone:" .. zone, label = "Rares of " .. zone, unit = "rares", zoneRares = index,
            count = function(_, f) return f.zoneRares[index] end,
            tiers = { { count, ZONE_RARE_NAMES[zone] or (zone .. "'s Most Wanted"), 10 + 5 * count } } }
    end
end
-- A target of 0 means all of them: every rare.
local rareTotal = 0
for _ in pairs(ns.Rares or {}) do rareTotal = rareTotal + 1 end
for _, feat in ipairs(FEATS) do
    for _, tier in ipairs(feat.tiers) do
        if tier[1] == 0 then tier[1] = rareTotal end
    end
end

local FEAT_POINTS = {}  -- [id] = points
for _, feat in ipairs(FEATS) do
    for _, tier in ipairs(feat.tiers) do FEAT_POINTS[AchievementID("feat", feat.key, tier[1])] = tier[3] end
end
function ns.FeatPoints(id) return FEAT_POINTS[id] end
local FEAT_NAMES = {}  -- [id] = name, for the activity feed
for _, feat in ipairs(FEATS) do
    for _, tier in ipairs(feat.tiers) do FEAT_NAMES[AchievementID("feat", feat.key, tier[1])] = tier[2] end
end
function ns.FeatName(id) return FEAT_NAMES[id] end

-- An earned achievement for the activity feed: its name and what it took ("Kennel Closed", "100 Gnoll kills").
function ns.AchievementTitle(id)
    if FEAT_NAMES[id] then return FEAT_NAMES[id] end
    local dimension, category, target = tostring(id):match("^(%a+):(.*):(%d+)$")
    if not dimension then return tostring(id) end
    for _, dim in ipairs(DIMENSIONS) do
        if dim.key == dimension then
            for i, tier in ipairs(dim.tiers) do
                if tier.kills == tonumber(target) then
                    return TierName(dimension, category, i), ("%s %s kills"):format(target, ShortName(category))
                end
            end
        end
    end
    return tostring(id)
end

-- Counts for a source (KillTrackerDB or a friend's stats): kills per creature and tribe, and the feats' facts.
local function CountKills(source)
    local counts = {}
    for _, dim in ipairs(DIMENSIONS) do counts[dim.key] = {} end
    local facts = { leaders = 0, rares = 0, elites = 0, kinds = 0, creatures = 0, zoneRares = {} }
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
        facts.creatures = facts.creatures + 1
        if ns.IsLeader and ns.IsLeader(npcID) then facts.leaders = facts.leaders + 1 end
        local rare = ns.Rares and ns.Rares[npcID]
        if rare or RARE_RANKS[c.rank] then facts.rares = facts.rares + 1 end
        if rare then facts.zoneRares[rare[2]] = (facts.zoneRares[rare[2]] or 0) + 1 end
        if ELITE_RANKS[c.rank] then facts.elites = facts.elites + entry.count end
    end, source)
    for _ in pairs(counts.subtype) do facts.kinds = facts.kinds + 1 end
    -- Pictures: yours are a list, a friend's are keyed by number. Won ones are known only for yours.
    local mine = source == KillTrackerDB
    facts.pictures, facts.epic, facts.legendary = 0, 0, 0
    facts.won = mine and 0 or nil
    for _, mint in pairs(source.mints or {}) do
        facts.pictures = facts.pictures + 1
        local rarity = ns.MintRarity and RARITY_ORDER[ns.MintRarity(mint.traits)] or 0
        if rarity >= 3 then facts.epic = facts.epic + 1 end
        if rarity >= 4 then facts.legendary = facts.legendary + 1 end
        if mine and mint.wonFrom then facts.won = facts.won + 1 end
    end
    facts.showcase = source.showcase and #(source.showcase.numbers or {}) or 0
    return counts, facts
end

-- Awards every reached tier and feat not yet earned (yours). Returns the number newly awarded.
local function Award(id, name, detail, silent)
    local earned = KillTrackerDB.achievements
    if earned[id] then return 0 end
    earned[id] = time()
    if not silent then
        if ns.AddEvent then ns.AddEvent("A", id) end
        local points = ns.AchievementPoints(id)
        ns.ShowToast("achievement", "Achievement earned!", name, ("%s  -  +%d points"):format(detail, points))
        ns.Print(("Achievement earned: |cffff8000%s|r (%s, +%d points)"):format(name, detail, points))
    end
    return 1
end

local function CheckAchievements(silent)
    if not KillTrackerDB or not KillTrackerDB.achievements then return 0 end
    local awarded = 0
    local counts, facts = CountKills(KillTrackerDB)
    for _, dim in ipairs(DIMENSIONS) do
        for category, kills in pairs(counts[dim.key]) do
            for i, tier in ipairs(dim.tiers) do
                if kills < tier.kills then break end
                awarded = awarded + Award(AchievementID(dim.key, category, tier.kills), TierName(dim.key, category, i),
                    ("%d %s kills"):format(tier.kills, ShortName(category)), silent)
            end
        end
    end
    for _, feat in ipairs(FEATS) do
        local count = feat.count(KillTrackerDB, facts)
        for _, tier in ipairs(count and feat.tiers or {}) do
            if count < tier[1] then break end
            awarded = awarded + Award(AchievementID("feat", feat.key, tier[1]), tier[2], ("%d %s"):format(tier[1], feat.unit), silent)
        end
    end
    return awarded
end
-- For things that change outside kills (pictures, PvP, the showcase): check, with the usual popup.
function ns.CheckAchievements()
    CheckAchievements(false)
    if ns.CheckRank then ns.CheckRank() end  -- achievements and the rest earn points
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
        ns.Print(("%d achievements awarded for earlier deeds. Type /solc to see them."):format(awarded))
    end
end)

-- For the UI: one row per creature, tribe and feat that has something counted, with progress towards its next tier.
-- Each row: { category (display name), tribe (the 1000-kill tribe one), feat (a feat), unit ("kills", "leaders"...),
-- kills (the count), earned (tiers earned), next (tier or nil), tiers = {...} } where tiers[i] = { name, kills (the
-- target), points, earned, time (nil if unknown) }. source is KillTrackerDB (default) or a friend's stats.
-- Pages ask for this several times per refresh (totals, lists); the rows are kept per source until its data changes
-- (its change number, total or earned achievements). Callers only read them.
local progressCache = setmetatable({}, { __mode = "k" })

local function ProgressStamp(source)
    if not source.seq then return nil end  -- e.g. the combined stats, rebuilt each time
    local earned = 0
    for _ in pairs(source.achievements or {}) do earned = earned + 1 end
    return ("%d:%d:%d"):format(source.seq, source.total or 0, earned)
end

local BuildProgress
function ns.GetAchievementProgress(source)
    source = source or KillTrackerDB
    local stamp = ProgressStamp(source)
    local cached = progressCache[source]
    if stamp and cached and cached.stamp == stamp then return cached.rows end
    local rows = BuildProgress(source)
    if stamp then progressCache[source] = { stamp = stamp, rows = rows } end
    return rows
end

BuildProgress = function(source)
    local earnedTimes = source.achievements
    local counts, facts = CountKills(source)
    local rows = {}
    local function Row(row, list)  -- list: { { id, name, target, points } }
        row.earned, row.tiers = 0, {}
        for i, t in ipairs(list) do
            local time = earnedTimes and earnedTimes[t[1]]
            local earned = time ~= nil or (not earnedTimes and row.kills >= t[3])
            row.tiers[i] = { name = t[2], kills = t[3], points = t[4], earned = earned, time = time }
            if earned then
                row.earned = row.earned + 1
            elseif not row.next then
                row.next = row.tiers[i]
            end
        end
        rows[#rows + 1] = row
    end
    for _, dim in ipairs(DIMENSIONS) do
        for category, kills in pairs(counts[dim.key]) do
            local list = {}
            for i, tier in ipairs(dim.tiers) do
                local id = AchievementID(dim.key, category, tier.kills)
                list[i] = { id, TierName(dim.key, category, i), tier.kills, ns.AchievementPoints(id) }
            end
            Row({ category = ShortName(category), tribe = dim.key == "faction", unit = "kills", kills = kills }, list)
        end
    end
    for _, feat in ipairs(FEATS) do
        local count = feat.count(source, facts)
        if count and count > 0 then
            local list = {}
            for i, tier in ipairs(feat.tiers) do list[i] = { AchievementID("feat", feat.key, tier[1]), tier[2], tier[1], tier[3] } end
            Row({ category = feat.label, feat = true, unit = feat.unit, kills = count }, list)
        end
    end
    return rows
end

function ns.GetAchievementTotals(source)
    local count = 0
    for _, row in ipairs(ns.GetAchievementProgress(source)) do count = count + row.earned end
    return count
end
