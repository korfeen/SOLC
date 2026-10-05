-- Guild activities that earn points (on top of Points.lua):
--   Guild groups    kills made in a group with guildmates earn +25% kill points per guildmate (max +100%).
--   Guild dungeons  dungeon and raid bosses killed with at least 3 guildmates in the group: +10, or +50
--                   for a final boss. Each boss pays once per day.
--   Weekly bounty   one bounty per week, the same for the whole guild. Officers can pick it from the
--                   catalogue below on the Bounty Board (BountyBoard.lua), for this week or next; otherwise
--                   the guild's rotation of creature kinds picks one, from the guild name and the week, so
--                   every member's addon agrees without talking. Bounty kills earn extra points, and when the
--                   guild reaches the goal, everyone who did their share gets a reward. Progress is shared
--                   through guild sync (Sync.lua).
-- Points are kept in KillTrackerDB.points.guildGroup / dungeons / bounty. The numbers are guild settings
-- (Config.lua); the defaults are given above.

local _, ns = ...

local WEEK = 7 * 24 * 3600

-- Bounty catalogue ------------------------------------------------------------------
-- id: saved and synced, never change it. count(npcID, entry, c) = true for a kill that counts; or event =
-- "pvp" / "dungeon". goal: for a guild with a handful of active players (the "Bounty goal %" setting scales
-- it). rotation: part of the automatic weekly rotation, in this order (never reorder those).

local function Subtype(subtype) return function(_, _, c) return c.subtype == subtype end end
local function CreatureType(creatureType) return function(_, _, c) return c.type == creatureType end end
local function Factions(...)
    local set = {}
    for _, faction in ipairs({ ... }) do set[faction] = true end
    return function(_, _, c) return set[c.faction] == true end
end
local function Ranks(...)
    local set = {}
    for _, rank in ipairs({ ... }) do set[rank] = true end
    return function(_, _, c) return set[c.rank] == true end
end

local BOUNTIES = {
    -- Creature kinds found at every level: the automatic rotation.
    { id = "Murloc", name = "Murlocs", goal = 300, rotation = true, count = Subtype("Murloc"), desc = "Murlocs of any tribe, on every coast and lake." },
    { id = "Troll", name = "Trolls", goal = 300, rotation = true, count = Subtype("Troll"), desc = "Trolls of any tribe, from Dun Morogh to Zul'Gurub." },
    { id = "Spider", name = "Spiders", goal = 300, rotation = true, count = Subtype("Spider"), desc = "Spiders of every forest, cave and crypt." },
    { id = "Wolf", name = "Wolves", goal = 300, rotation = true, count = Subtype("Wolf"), desc = "Wolves and worg packs." },
    { id = "Human", name = "Humans", goal = 300, rotation = true, count = Subtype("Human"), desc = "Hostile humans: Defias, Syndicate, Scarlet Crusade, cultists and more." },
    { id = "Orc", name = "Orcs", goal = 300, rotation = true, count = Subtype("Orc"), desc = "Hostile orcs: Burning Blade, Blackrock, Dragonmaw and more." },
    { id = "Dwarf", name = "Dwarves", goal = 300, rotation = true, count = Subtype("Dwarf"), desc = "Hostile dwarves, mostly Dark Irons." },
    { id = "Cat", name = "Cats", goal = 300, rotation = true, count = Subtype("Cat"), desc = "Lions, tigers, panthers and other big cats." },
    { id = "Scorpid", name = "Scorpids", goal = 300, rotation = true, count = Subtype("Scorpid"), desc = "Scorpids, from Durotar to Silithus." },
    { id = "Raptor", name = "Raptors", goal = 300, rotation = true, count = Subtype("Raptor"), desc = "Raptors of the Barrens, Wetlands, Stranglethorn and Un'Goro." },
    -- Enemy factions, by level.
    { id = "defias", name = "Defias Brotherhood", goal = 250, count = Factions("Defias Brotherhood"), desc = "Westfall, Redridge and the Deadmines. Levels 10-25." },
    { id = "venture", name = "Venture Company", goal = 250, count = Factions("Venture Company"), desc = "Goblin loggers and miners in Stonetalon, the Barrens and Stranglethorn. Levels 10-40." },
    { id = "kolkar", name = "Kolkar Centaurs", goal = 200, count = Factions("Centaur, Kolkar"), desc = "Kolkar centaurs in the Barrens and Desolace. Levels 10-35." },
    { id = "burningblade", name = "Burning Blade", goal = 150, count = Factions("Burning Blade"), desc = "Demon-worshipping orcs in Durotar, Ragefire Chasm and Desolace. Levels 10-40." },
    { id = "syndicate", name = "Syndicate", goal = 200, count = Factions("Syndicate"), desc = "Perenolde's thieves in Alterac and Hillsbrad. Levels 20-40." },
    { id = "scarlet", name = "Scarlet Crusade", goal = 300, count = Factions("Scarlet Crusade"), desc = "Tirisfal, Scarlet Monastery and the Plaguelands. Levels 30-60." },
    { id = "bloodsail", name = "Bloodsail Buccaneers", goal = 150, count = Factions("Bloodsail Buccaneers"), desc = "Pirates on the Stranglethorn coast. Levels 40-48." },
    { id = "darkiron", name = "Dark Iron Dwarves", goal = 400, count = Factions("Dark Iron Dwarves"), desc = "Searing Gorge, Burning Steppes and Blackrock Depths. Levels 45-60." },
    { id = "blackrock", name = "Blackrock Orcs", goal = 300, count = Factions("Orc, Blackrock"), desc = "Redridge, the Burning Steppes and Blackrock Spire. Levels 20-60." },
    { id = "scourge", name = "The Scourge", goal = 500, count = Factions("Undead, Scourge", "Scourge Invaders"), desc = "The Plaguelands, Stratholme and Scholomance. Levels 35-60." },
    -- Creature types.
    { id = "undead", name = "Undead Purge", goal = 400, count = CreatureType("Undead"), desc = "Every undead creature, at any level." },
    { id = "demon", name = "Demon Hunt", goal = 150, count = CreatureType("Demon"), desc = "Demons in Ashenvale, Desolace, Felwood, Azshara and the Blasted Lands." },
    { id = "elemental", name = "Elemental Unrest", goal = 250, count = CreatureType("Elemental"), desc = "Elementals of fire, earth, air and water." },
    { id = "dragonkin", name = "Dragon Slayers", goal = 100, count = CreatureType("Dragonkin"), desc = "Whelps, drakes, dragonspawn and dragons." },
    -- Special.
    { id = "elites", name = "Elite Hunt", goal = 150, count = Ranks("Elite", "Rare Elite", "Boss"), desc = "Elite mobs, out in the world or in dungeons." },
    { id = "rares", name = "Rare Hunters", goal = 10, count = Ranks("Rare", "Rare Elite"), desc = "Rare mobs: track them down before someone else does." },
    { id = "leaders", name = "Decapitation", goal = 15, count = function(npcID) return ns.IsLeader(npcID) end, desc = "Tribe leaders, overlords and rulers (the crowned mobs). Repeat kills count." },
    { id = "dungeons", name = "Dungeon Crawl", goal = 60, event = "dungeon", desc = "Dungeon and raid bosses killed in a guild group (counted per member, each boss once a day)." },
    { id = "pvp", name = "Blood and Honor", goal = 100, event = "pvp", desc = "Honorable kills of the other faction's players." },
    { id = "explorers", name = "Explorers", goal = 75, count = function(_, entry) return entry.count == 1 end, desc = "Mob types you've never killed before." },
}
ns.BOUNTIES = BOUNTIES

local BOUNTY_BY_ID, ROTATION = {}, {}
ns.BOUNTY_BY_ID = BOUNTY_BY_ID
for _, bounty in ipairs(BOUNTIES) do
    BOUNTY_BY_ID[bounty.id] = bounty
    if bounty.rotation then ROTATION[#ROTATION + 1] = bounty end
end

-- Custom bounties, built by officers on the Bounty Board: any creature kind ("kind_ogre"), one tribe or
-- faction ("tribe_ogremoshogg"), or PvP kills of one race ("pvp_nightelf"). Ids are names squashed to
-- lowercase letters and digits, so they travel through sync like the catalogue's.

local PLAYER_RACES = { "Human", "Dwarf", "Night Elf", "Gnome", "Orc", "Troll", "Tauren", "Undead" }
local RACE_PLURALS = { ["Human"] = "Humans", ["Dwarf"] = "Dwarves", ["Night Elf"] = "Night Elves", ["Gnome"] = "Gnomes",
    ["Orc"] = "Orcs", ["Troll"] = "Trolls", ["Tauren"] = "Tauren", ["Undead"] = "Undead" }
local PLURAL_EXCEPTIONS = { Wolf = "Wolves", Dwarf = "Dwarves", ["Night Elf"] = "Night Elves", ["High Elf"] = "High Elves",
    Tauren = "Tauren", Undead = "Undead", Sheep = "Sheep", Fish = "Fish", Deer = "Deer", Silithid = "Silithid",
    Qiraji = "Qiraji", Wendigo = "Wendigos", Ooze = "Oozes", Ghost = "Ghosts", ["Lost One"] = "Lost Ones" }
local CUSTOM_GOALS = { kind = 300, tribe = 150, pvp = 50 }
local HIDDEN_TYPES = { Critter = true, Totem = true, Other = true }

local function Squash(text) return (text:lower():gsub("[^%w]", "")) end

-- Enemy groups worth a bounty: tribes and clans ("Ogre, Mosh'Ogg", "Gnoll - Redridge"), factions with a
-- leader (Defias Brotherhood, Scarlet Crusade...) and a few more. Leaves out friendly ones like Orgrimmar.
local EXTRA_ENEMIES = { ["Venture Company"] = true, ["Bloodsail Buccaneers"] = true, ["Scourge Invaders"] = true }
local NOT_ENEMIES = { ["HIllsbrad, Southshore Mayor"] = true, ["Human, Night Watch"] = true }
local function IsEnemyGroup(faction)
    if NOT_ENEMIES[faction] or faction:find("^PLAYER") then return false end
    return faction:find("^.-, .+$") ~= nil or faction:find("^.- %- .+$") ~= nil
        or (ns.Leaders and ns.Leaders[faction] ~= nil) or EXTRA_ENEMIES[faction] == true
end

local function Plural(name)
    if PLURAL_EXCEPTIONS[name] then return PLURAL_EXCEPTIONS[name] end
    if name:find("y$") and not name:find("[aeiou]y$") then return name:sub(1, -2) .. "ies" end
    if name:find("[sxz]$") or name:find("ch$") then return name .. "es" end
    return name .. "s"
end

-- "Ogre, Mosh'Ogg" -> "Mosh'Ogg Ogres", "Gnoll - Redridge" -> "Redridge Gnolls", "Syndicate" -> "Syndicate".
local function TribeName(faction)
    local race, tribe = faction:match("^(.-), (.+)$")
    if not race then race, tribe = faction:match("^(.-) %- (.+)$") end
    return race and (tribe .. " " .. Plural(race)) or faction
end
ns.BountyTribeName = TribeName

-- What custom bounties can target, from the mob data: { kinds = { [squashed] = subtype },
-- tribes = { [squashed] = faction }, races = { [squashed] = race },
-- byType = { { type, subtypes = { { subtype, tribes = { faction... } } } } } } for the board.
local targets
local function Targets()
    if targets then return targets end
    targets = { kinds = {}, tribes = {}, races = {}, byType = {} }
    for _, race in ipairs(PLAYER_RACES) do targets.races[Squash(race)] = race end
    local tribeCounts, typeOf = {}, {}  -- [subtype][faction] = NPC types; [subtype] = creature type
    for npcID in pairs(ns.NPCs or {}) do
        local c = ns.Categorize(npcID, {})
        if c.subtype and not HIDDEN_TYPES[c.type] and not ns.NO_AWARDS[c.subtype] then
            typeOf[c.subtype] = c.type
            tribeCounts[c.subtype] = tribeCounts[c.subtype] or {}
            local faction = c.faction
            if faction and not ns.NO_AWARDS[faction] and faction ~= c.subtype and not c.factionGuess and IsEnemyGroup(faction) then
                tribeCounts[c.subtype][faction] = (tribeCounts[c.subtype][faction] or 0) + 1
            end
        end
    end
    local types = {}
    for subtype, creatureType in pairs(typeOf) do
        targets.kinds[Squash(subtype)] = subtype
        local tribes = {}
        for faction, count in pairs(tribeCounts[subtype]) do
            if count >= 2 then
                tribes[#tribes + 1] = faction
                targets.tribes[Squash(faction)] = faction
            end
        end
        table.sort(tribes, function(a, b) return TribeName(a) < TribeName(b) end)
        types[creatureType] = types[creatureType] or {}
        table.insert(types[creatureType], { subtype = subtype, tribes = tribes })
    end
    for creatureType, list in pairs(types) do
        table.sort(list, function(a, b) return a.subtype < b.subtype end)
        targets.byType[#targets.byType + 1] = { type = creatureType, subtypes = list }
    end
    table.sort(targets.byType, function(a, b) return a.type < b.type end)
    return targets
end
ns.BountyTargets = Targets
ns.PLAYER_RACES = PLAYER_RACES

-- The bounty for an id: a catalogue entry, or a custom one built (once) from its id. nil if unknown.
local custom = {}
local function ResolveBounty(id)
    if not id then return end
    if BOUNTY_BY_ID[id] then return BOUNTY_BY_ID[id] end
    if custom[id] then return custom[id] end
    local kind, key = id:match("^(%a+)_(%w+)$")
    local bounty
    if kind == "kind" and Targets().kinds[key] then
        local subtype = Targets().kinds[key]
        bounty = { name = Plural(subtype), count = Subtype(subtype), goal = CUSTOM_GOALS.kind,
            desc = ("%s of any tribe or faction."):format(Plural(subtype)) }
    elseif kind == "tribe" and Targets().tribes[key] then
        local faction = Targets().tribes[key]
        bounty = { name = TribeName(faction), count = Factions(faction), goal = CUSTOM_GOALS.tribe,
            desc = ("Members of %s."):format(faction) }
    elseif kind == "pvp" and Targets().races[key] then
        local race = Targets().races[key]
        bounty = { name = "Blood and Honor: " .. RACE_PLURALS[race], event = "pvp", race = race, goal = CUSTOM_GOALS.pvp,
            desc = ("Honorable kills of %s players."):format(RACE_PLURALS[race]:gsub("^%u", string.lower)) }
    end
    if bounty then
        bounty.id, bounty.custom = id, true
        custom[id] = bounty
    end
    return bounty
end
ns.ResolveBounty = ResolveBounty

-- Ids for building custom bounties (a kind already in the rotation uses the rotation's bounty).
function ns.KindBountyID(subtype)
    for _, bounty in ipairs(ROTATION) do
        if bounty.id == subtype then return bounty.id end
    end
    return "kind_" .. Squash(subtype)
end
function ns.TribeBountyID(faction) return "tribe_" .. Squash(faction) end
function ns.RaceBountyID(race) return race and ("pvp_" .. Squash(race)) or "pvp" end

-- Final bosses (DungeonEncounter ids from the Classic game data), one per dungeon wing, plus raid end
-- bosses. Some appear twice: the game has two versions of the encounter.
local FINAL_BOSSES = {
    [2735] = true,                                 -- Ragefire Chasm: Bazzalan
    [2747] = true,                                 -- Deadmines: Edwin VanCleef
    [592] = true,                                  -- Wailing Caverns: Mutanus the Devourer
    [2755] = true,                                 -- Shadowfang Keep: Archmage Arugal
    [2910] = true, [2767] = true, [2891] = true,   -- Blackfathom Deeps: Aku'mai
    [2760] = true,                                 -- Stormwind Stockade: Bazil Thredd
    [2772] = true, [2940] = true,                  -- Gnomeregan: Mekgineer Thermaplugg
    [2778] = true,                                 -- Razorfen Kraul: Charlga Razorflank
    [2779] = true, [447] = true, [448] = true, [450] = true,  -- Scarlet Monastery: Thalnos, Doan, Herod, Whitemane
    [2785] = true,                                 -- Razorfen Downs: Amnennar the Coldbringer
    [554] = true,                                  -- Uldaman: Archaedas
    [600] = true,                                  -- Zul'Farrak: Chief Ukorz Sandscalp
    [429] = true,                                  -- Maraudon: Princess Theradras
    [493] = true, [2959] = true,                   -- Sunken Temple: Shade of Eranikus
    [2790] = true,                                 -- Blackrock Depths: Emperor Dagran Thaurissan
    [275] = true, [3069] = true,                   -- Blackrock Spire: Overlord Wyrmthalak, General Drakkisath
    [346] = true, [361] = true, [368] = true,      -- Dire Maul: Alzzin, Prince Tortheldrin, King Gordok
    [2801] = true,                                 -- Scholomance: Darkmaster Gandling
    [484] = true, [478] = true,                    -- Stratholme: Baron Rivendare, Balnazzar
    [672] = true, [617] = true, [1084] = true, [793] = true,  -- Ragnaros, Nefarian, Onyxia, Hakkar
    [723] = true, [717] = true, [1114] = true,     -- Ossirian, C'Thun, Kel'Thuzad
}

local issecret = issecretvalue or function() return false end

local function Points()
    local p = KillTrackerDB.points
    p.guildGroup, p.dungeons, p.bounty = p.guildGroup or 0, p.dungeons or 0, p.bounty or 0
    return p
end

-- Guildmates ------------------------------------------------------------------

local rosterNames  -- [name] = true for guild members, a fallback when a unit's guild can't be read

local function RosterNames()
    if rosterNames then return rosterNames end
    rosterNames = {}
    for i = 1, GetNumGuildMembers and GetNumGuildMembers() or 0 do
        local fullName = GetGuildRosterInfo(i)
        if fullName and not issecret(fullName) then
            rosterNames[fullName] = true
            rosterNames[(fullName:match("^[^-]+"))] = true
        end
    end
    return rosterNames
end

local function IsGuildmate(unit)
    if not UnitExists(unit) or UnitIsUnit(unit, "player") then return false end
    local inGuild = UnitIsInMyGuild and UnitIsInMyGuild(unit)
    if inGuild ~= nil and not issecret(inGuild) then return inGuild and true or false end
    local name, realm = UnitName(unit)
    if not name or issecret(name) then return false end
    local names = RosterNames()
    return names[name] or (realm and realm ~= "" and names[name .. "-" .. realm]) or false
end

-- Number of guildmates in your party or raid (not counting you).
function ns.GuildmatesInGroup()
    if not IsInGuild() or not IsInGroup() then return 0 end
    local count = 0
    local prefix, size = "party", 4
    if IsInRaid() then prefix, size = "raid", 40 end
    for i = 1, size do
        if IsGuildmate(prefix .. i) then count = count + 1 end
    end
    return count
end

-- Weekly bounty ------------------------------------------------------------------

-- The week, as the day number of its weekly reset; the same for everyone on the realm. Also returns the
-- seconds until the next reset.
local function CurrentWeek()
    local now = GetServerTime and GetServerTime() or time()
    local untilReset = C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset and C_DateAndTime.GetSecondsUntilWeeklyReset()
    if untilReset and not issecret(untilReset) then
        return math.floor((now + untilReset - WEEK + 3600) / 86400), untilReset
    end
    local week = math.floor(now / WEEK)
    return week * 7, (week + 1) * WEEK - now
end
ns.CurrentWeek = CurrentWeek

local function Hash(text)
    local h = 5381
    for i = 1, #text do h = (h * 33 + text:byte(i)) % 2147483647 end
    return h
end

-- The guild's own shuffled order of the rotation, seeded by its name: every kind comes up once per
-- cycle and never twice in a row, and different guilds hunt different things.
local orders = {}
local function GuildOrder(guild)
    if orders[guild] then return orders[guild] end
    local order, seed = {}, Hash(guild)
    for i = 1, #ROTATION do order[i] = i end
    for i = #order, 2, -1 do
        seed = (seed * 1103515245 + 12345) % 2147483648
        local j = math.floor(seed / 65536) % i + 1
        order[i], order[j] = order[j], order[i]
    end
    orders[guild] = order
    return order
end

-- A bounty's goal for your guild, scaled by the "Bounty goal %" setting.
function ns.BountyGoal(bounty)
    return math.max(1, math.floor(bounty.goal * ns.Config("bountyGoalPercent") / 100 + 0.5))
end

-- Kills of your own needed for the reward: the "Reward share %" of the goal, at least 1.
local function ShareNeeded(goal)
    return math.max(1, math.ceil(goal * ns.Config("bountyMinPercent") / 100))
end

-- The guild's bounty weeksAhead weeks from now (0 = this week): { week, bounty = BOUNTIES entry or custom
-- bounty, scheduled = true if an officer picked it, goal = the officer's own goal or nil, resetsIn = seconds
-- until this week ends }, or nil outside a guild.
function ns.GetBounty(weeksAhead)
    local guild = IsInGuild() and GetGuildInfo("player")
    if not guild or issecret(guild) then return end
    local week, resetsIn = CurrentWeek()
    week = week + 7 * (weeksAhead or 0)
    local id, goal = ns.GetScheduledBounty(week)
    local scheduled = ResolveBounty(id)
    local order = GuildOrder(guild)
    local bounty = scheduled or ROTATION[order[math.floor(week / 7) % #order + 1]]
    return { week = week, bounty = bounty, scheduled = scheduled ~= nil, goal = scheduled and goal, resetsIn = resetsIn }
end

-- Your bounty record for this week (KillTrackerDB.bounty = { week, target = bounty id, kills, rewarded }),
-- started fresh when the week or the bounty changes. Friends receive it through sync.
local function MyBounty(current)
    local db = KillTrackerDB
    if not db.bounty or db.bounty.week ~= current.week or db.bounty.target ~= current.bounty.id then
        db.bounty = { week = current.week, target = current.bounty.id, kills = 0 }
    end
    return db.bounty
end

-- Guild progress this week: { current, goal, needed, total, mine, contributors = { { name, kills } }, rewarded }.
function ns.GetBountyProgress()
    local current = ns.GetBounty()
    if not current then return end
    local mine = MyBounty(current)
    local goal = current.goal or ns.BountyGoal(current.bounty)
    local progress = { current = current, goal = goal, needed = ShareNeeded(goal), total = mine.kills, mine = mine.kills,
        rewarded = mine.rewarded, contributors = { { name = ns.MyName(), kills = mine.kills } } }
    for _, friend in ipairs(ns.GetFriends()) do
        local theirs = friend.stats.bounty
        if theirs and theirs.week == current.week and theirs.target == current.bounty.id and theirs.kills > 0 then
            progress.total = progress.total + theirs.kills
            progress.contributors[#progress.contributors + 1] = { name = friend.name, kills = theirs.kills }
        end
    end
    table.sort(progress.contributors, function(a, b) return a.kills > b.kills end)
    return progress
end

-- Pays the reward once the guild reaches the goal, if you did your share. Called after kills and syncs.
function ns.CheckBountyGoal()
    local progress = ns.GetBountyProgress()
    if not progress or progress.rewarded or progress.total < progress.goal or progress.mine < progress.needed then return end
    KillTrackerDB.bounty.rewarded = true
    ns.Touch(KillTrackerDB.bounty)
    local reward = ns.Config("bountyReward")
    local p = Points()
    p.bounty = p.bounty + reward
    ns.AddEvent("B", progress.current.bounty.id)
    ns.ShowToast("achievement", "Bounty complete!", ("%s: %d/%d"):format(progress.current.bounty.name, progress.total, progress.goal),
        ("+%d points"):format(reward))
end

-- Counts one towards your bounty.
local function Count()
    local current = ns.GetBounty()
    if not current then return end
    local mine = MyBounty(current)
    mine.kills = mine.kills + 1
    ns.Touch(mine)
    ns.CheckBountyGoal()
end

-- Non-kill bounties: called with "pvp" and the victim { race } if known (PvP.lua), or "dungeon" (below).
-- A race bounty only counts victims whose race is known.
function ns.OnBountyEvent(event, victim)
    local current = ns.GetBounty()
    if not current or current.bounty.event ~= event then return end
    if current.bounty.race and not (victim and victim.race == current.bounty.race) then return end
    Count()
end

local function TimeLeft(seconds)
    return ("%dd %dh"):format(math.floor(seconds / 86400), math.floor(seconds % 86400 / 3600))
end
ns.BountyTimeLeft = TimeLeft

function ns.PrintBounty()
    local progress = ns.GetBountyProgress()
    if not progress then
        ns.Print("Weekly bounties are for guilds; join one to take part.")
        return
    end
    local bounty = progress.current.bounty
    ns.Print(("This week's bounty: %s - %s"):format(bounty.name, bounty.desc))
    ns.Print(("Guild %d/%d, you %d. Resets in %s."):format(progress.total, progress.goal, progress.mine, TimeLeft(progress.current.resetsIn)))
    if progress.rewarded then
        ns.Print("Done! You got the reward.")
    elseif progress.mine < progress.needed then
        ns.Print(("Get at least %d to share the %d point reward."):format(progress.needed, ns.Config("bountyReward")))
    end
    local nextWeek = ns.GetBounty(1)
    if nextWeek then
        ns.Print(("Next week: %s%s."):format(nextWeek.bounty.name, nextWeek.scheduled and "" or " (unless an officer picks another)"))
    end
end

-- Kills ----------------------------------------------------------------------------

table.insert(ns.KillHandlers, function(npcID, entry, c, unit)
    local base = ns.KillPoints(c, unit)
    local p = Points()
    local guildmates = math.min(ns.GuildmatesInGroup(), ns.Config("groupMaxGuildmates"))
    if guildmates > 0 then
        p.guildGroup = p.guildGroup + base * ns.Config("groupBonus") / 100 * guildmates
    end
    local current = ns.GetBounty()
    if current and current.bounty.count and current.bounty.count(npcID, entry, c) then
        p.bounty = p.bounty + base * ns.Config("bountyExtra") / 100  -- default: double points
        Count()
    end
end)

-- Dungeon bosses -----------------------------------------------------------------------

local function OnEncounterEnd(encounterID, encounterName, _, _, success)
    if issecret(encounterID) or issecret(success) or success ~= 1 then return end
    local guildmates = ns.GuildmatesInGroup()
    if guildmates < ns.Config("dungeonGuildmates") then return end
    local db = KillTrackerDB
    db.guildBosses = db.guildBosses or {}  -- [encounterID] = day it last paid
    local today = date("%Y-%m-%d")
    if db.guildBosses[encounterID] == today then return end
    db.guildBosses[encounterID] = today
    local final = FINAL_BOSSES[encounterID]
    local points = ns.Config(final and "dungeonFinalBoss" or "dungeonBoss")
    local p = Points()
    p.dungeons = p.dungeons + points
    local name = (encounterName and not issecret(encounterName)) and encounterName or "Boss"
    ns.ShowToast(final and "achievement" or "record", final and "Guild clear!" or "Guild boss down!", name,
        ("+%d points (%d guildmates)"):format(points, guildmates))
    ns.AddEvent("D", name, final and 1 or 0)
    ns.OnBountyEvent("dungeon")
    if ns.OnKillsChanged then ns.OnKillsChanged() end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ENCOUNTER_END")
frame:RegisterEvent("GUILD_ROSTER_UPDATE")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ENCOUNTER_END" then
        OnEncounterEnd(...)
    elseif event == "PLAYER_LOGIN" then
        -- Load the guild roster, the fallback for telling guildmates apart (see IsGuildmate).
        if C_GuildInfo and C_GuildInfo.GuildRoster then pcall(C_GuildInfo.GuildRoster) end
    else
        rosterNames = nil
    end
end)
