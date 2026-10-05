-- Sleepy Ogre Leisure Club (SOLC)
-- Combat log events are unavailable to addons in 12.0.0, so kills are inferred:
-- a hostile NPC on target/nameplates that we saw being fought by us or our group (threat), that dies
-- without being tapped by someone else, counts as a kill.
-- Kills are stored by NPC ID and categorized at display time using Data.lua and Overrides.lua.
-- Every mob gets a faction and a subtype (Gnoll, Ghoul, Fire Elemental, Kodo...). Mobs missing from
-- Data.lua keep what the game showed when they died (type, rank, family, model) and get guesses
-- from their name.

local ADDON_NAME, ns = ...

local CREATURE_TYPES = {
    [1] = "Beast", [2] = "Dragonkin", [3] = "Demon", [4] = "Elemental", [5] = "Giant",
    [6] = "Undead", [7] = "Humanoid", [8] = "Critter", [9] = "Mechanical", [10] = "Other",
    [11] = "Totem",
}
local RANKS = { [1] = "Elite", [2] = "Rare Elite", [3] = "Boss", [4] = "Rare" }
local CLASSIFICATION_RANKS = { elite = "Elite", rareelite = "Rare Elite", worldboss = "Boss", rare = "Rare" }
local UNCATEGORIZED = "Uncategorized"
local OTHER = "Other"
local NO_FACTION = "No faction"
-- Blizzard's catch-all factions for mobs that belong to no group; shown together as NO_FACTION.
local GENERIC_FACTIONS = { ["Monster"] = true, ["Creature"] = true, ["Ambient"] = true }

ns.WOWHEAD_NPC_URL = "https://www.wowhead.com/classic/npc=%d"
ns.NO_AWARDS = { [UNCATEGORIZED] = true, [OTHER] = true, [NO_FACTION] = true, ["Totem"] = true }  -- no records or achievements
ns.KillHandlers = {}  -- functions(npcID, entry, categories, unit) run after every recorded kill

local sessionKills = 0
local engaged = {}     -- [guid] = true: mobs seen alive, fought by us or our group, not tapped by others
local counted = {}     -- [guid] = true: already counted this session

local issecret = issecretvalue or function() return false end

-- Returns v, or nil if it is a secret value tainted code can't inspect.
local function Readable(v)
    if issecret(v) then return nil end
    return v
end

local function Print(msg)
    print("|cff9acd32SOLC:|r " .. msg)
end

local function NotifyChanged()
    if ns.OnKillsChanged then ns.OnKillsChanged() end
end

local function NpcIDFromGUID(guid)
    local unitType, _, _, _, _, npcID = strsplit("-", guid)
    if unitType == "Creature" or unitType == "Vehicle" then
        return tonumber(npcID)
    end
end

-- Identifies one spawned mob across players: its spawn UID plus server ID from the GUID.
local function SpawnKey(guid)
    local _, _, serverID, _, _, _, spawnUID = strsplit("-", guid)
    return spawnUID .. serverID
end

-- Categorizing ---------------------------------------------------------------

-- Looks a name up in a Name*/Word* table pair from Data.lua. Returns the matched ID or nil.
local function GuessFromName(name, byName, byWord)
    if not name then return end
    name = name:lower()
    if byName[name] then return byName[name] end

    -- The best-supported match among the name's words, e.g. "Riverpaw" -> Gnoll.
    local best
    for word in name:gmatch("[a-z']+") do
        local match = byWord[word]
        if match and (not best or match[2] > best[2]) then best = match end
    end
    return best and best[1]
end

-- Identifies a unit's subtype from its 3D model, via a hidden model frame.
local modelProbe
local function SubtypeFromModel(unit)
    if not modelProbe then
        modelProbe = CreateFrame("PlayerModel", nil, UIParent)
        modelProbe:SetSize(1, 1)
        modelProbe:SetAlpha(0)
    end
    local ok, fileID = pcall(function()
        modelProbe:SetUnit(unit)
        return modelProbe:GetModelFileID()
    end)
    modelProbe:ClearModel()
    if not ok or not Readable(fileID) then return end
    return ns.Subtypes[ns.ModelSubtypes[fileID]]
end

-- Subtype name -> its ID in ns.Subtypes (built on first use).
local subtypeIDs
local function SubtypeID(name)
    if not subtypeIDs then
        subtypeIDs = {}
        for id, subtype in ipairs(ns.Subtypes) do subtypeIDs[subtype] = id end
    end
    return subtypeIDs[name]
end

-- Returns { faction, factionGuess, subtype, subtypeGuess, type, rank, size } for a recorded mob.
-- rank may be nil; size is 1 for a typical member of its subtype. For NPCs not in Data.lua,
-- entry holds the type/rank/family/subtype captured at kill time.
local function Categorize(npcID, entry)
    local info = ns.NPCs[npcID]
    local c = {}

    if ns.Overrides[npcID] then
        c.faction = ns.Overrides[npcID]
    elseif info and info[1] ~= 0 then
        c.faction = ns.Factions[info[1]]
    else
        local factionID = GuessFromName(entry.name, ns.NameFactions, ns.WordFactions)
        c.faction = factionID and ns.Factions[factionID] or entry.family  -- beasts: their kind, e.g. "Wolf"
        c.factionGuess = c.faction ~= nil
    end

    if info then
        c.type, c.rank, c.subtype, c.size = CREATURE_TYPES[info[2]], RANKS[info[3]], ns.Subtypes[info[4]], info[5]
    else
        c.type, c.rank, c.size = entry.type, entry.rank, 1
        c.subtype = entry.subtype or entry.family
        if not c.subtype then
            c.subtype = ns.Subtypes[GuessFromName(entry.name, ns.NameSubtypes, ns.WordSubtypes)]
            c.subtypeGuess = c.subtype ~= nil
        end
        -- The game didn't say: use the type this subtype usually has.
        if not c.type and c.subtype then
            c.type = CREATURE_TYPES[ns.SubtypeTypes[SubtypeID(c.subtype)]]
        end
    end

    if GENERIC_FACTIONS[c.faction] then c.faction, c.factionGuess = NO_FACTION, nil end
    c.faction = c.faction or UNCATEGORIZED
    c.type = c.type or OTHER
    c.subtype = c.subtype or c.type
    return c
end

-- "Gnoll - Riverpaw | Gnoll", with "?" after guessed parts.
local function CategoryLabel(c)
    return ("%s%s | %s%s"):format(c.faction, c.factionGuess and "?" or "", c.subtype, c.subtypeGuess and "?" or "")
end

-- Calls fn(npcID, entry) for every recorded mob. source is KillTrackerDB (default) or a friend's
-- synced stats (see Sync.lua); both have the same kills table.
local function ForEachKill(fn, source)
    for npcID, entry in pairs((source or KillTrackerDB).kills) do
        fn(npcID, entry)
    end
end

-- Saved data -----------------------------------------------------------------

-- Every change to a kill entry or record is stamped with the next change number (db.seq), so syncing
-- can send only what changed since a friend's last update. db.syncID changes on reset, which tells
-- friends to drop their copy and fetch everything again. See Sync.lua.
local function NewSyncID()
    local chars = {}
    for i = 1, 8 do
        local n = math.random(1, 36)
        chars[i] = ("0123456789abcdefghijklmnopqrstuvwxyz"):sub(n, n)
    end
    return table.concat(chars)
end

-- Stamps a kill entry or record as changed. Returns the change number.
local function Touch(t)
    local db = KillTrackerDB
    db.seq = db.seq + 1
    t.seq = db.seq
    t.created = t.created or db.seq
    return db.seq
end

-- Upgrades data saved by older versions. Can be removed once every character has logged in on 0.6.0+.
local function Migrate(db)
    -- Pre-0.2.0: kills stored by name only; they can't be categorized properly, so drop them.
    if db.byName then
        for _, count in pairs(db.byName) do db.total = math.max(0, db.total - count) end
        db.byName = nil
    end
    -- Pre-0.6.0: records and achievements per race / beast family / type, now per subtype.
    for key, record in pairs(db.records) do
        local name = key:match("^race:(.+)") or key:match("^family:(.+)")
        if name then
            db.records[key] = nil
            local newKey = "subtype:" .. name
            if not db.records[newKey] or db.records[newKey].weight < record.weight then
                db.records[newKey] = record
            end
        end
    end
    for id, earned in pairs(db.achievements) do
        local rest = id:match("^race:(.+)")
        if rest then
            db.achievements["subtype:" .. rest] = db.achievements["subtype:" .. rest] or earned
        end
        if rest or id:match("^type:") then db.achievements[id] = nil end
    end
    for _, entry in pairs(db.kills) do
        entry.subtype, entry.race = entry.subtype or entry.race, nil
    end
    -- 0.11.0: weights are now based on real model heights; records from the old model are dropped.
    -- A new syncID makes friends fetch everything again, so their copies lose the old records too.
    if (db.weightModel or 1) < 2 then
        wipe(db.records)
        for _, entry in pairs(db.kills) do entry.maxWeight = nil end
        db.syncID = NewSyncID()
        db.weightModel = 2
        if next(db.kills) then Print("Weight records were reset for the new, more realistic weight model.") end
    end
    -- 0.18.0: faction/tribe achievements below 1000 kills were dropped (only the 1000 one remains).
    for id in pairs(db.achievements) do
        local kills = id:match("^faction:.*:(%d+)$")
        if kills and kills ~= "1000" then db.achievements[id] = nil end
    end
end

local function InitDB()
    KillTrackerDB = KillTrackerDB or {}
    local db = KillTrackerDB
    db.total = db.total or 0
    db.kills = db.kills or {}                -- [npcID] = { name, count, maxWeight, seq, created [, type, rank, family, subtype if not in Data.lua] }
    db.records = db.records or {}            -- [recordKey] = heaviest kill, see Records.lua
    db.achievements = db.achievements or {}  -- [achievementID] = time earned, see Achievements.lua
    db.groupLog = db.groupLog or {}          -- kills made in a group: { s = change number, n = npcID, k = spawn key }
    db.pvp = db.pvp or { total = 0, unknown = 0, players = {} }  -- PvP kills, see PvP.lua
    -- Points (Points.lua): kill points so far and points spent. Kills from before points existed: 1 each.
    db.points = db.points or { kills = db.total, spent = 0 }
    db.collection = db.collection or {}      -- [itemID] = { time bought, claim = true when marked for minting }
    db.mints = db.mints or {}                -- minted pictures, see Minting.lua
    db.minimap = db.minimap or { angle = 225, hide = false }
    db.announce = db.announce or false
    if db.sharing == nil then db.sharing = true end  -- share kill stats with guildmates and /kt sync requests
    db.syncID = db.syncID or NewSyncID()
    db.seq = db.seq or 0
    Migrate(db)
    for _, entry in pairs(db.kills) do
        if not entry.seq then Touch(entry) end
    end
    for _, record in pairs(db.records) do
        if not record.seq then Touch(record) end
    end
    for _, mint in ipairs(db.mints) do
        if not mint.seq then Touch(mint) end
    end

    KillTrackerFriends = KillTrackerFriends or {}    -- account-wide: ["Name-Realm"] = synced stats
end

-- Kill detection ---------------------------------------------------------------

-- Kills made in a group are logged by spawn key too, so the combined total of several players can count
-- a mob they killed together only once (solo kills can't be shared: others see the mob as tapped).
local function RecordKill(npcID, unit, guid)
    local db = KillTrackerDB
    db.total = db.total + 1
    sessionKills = sessionKills + 1

    local entry = db.kills[npcID]
    if not entry then
        entry = { count = 0 }
        db.kills[npcID] = entry
    end
    entry.count = entry.count + 1
    entry.name = Readable(UnitName(unit)) or entry.name or ("NPC " .. npcID)
    Touch(entry)
    if IsInGroup() then
        db.groupLog[#db.groupLog + 1] = { s = db.seq, n = npcID, k = SpawnKey(guid) }
    end

    -- Not in Data.lua: keep what the game tells us so the mob can still be categorized.
    if not ns.NPCs[npcID] then
        entry.type = Readable(UnitCreatureType(unit)) or entry.type
        entry.family = Readable(UnitCreatureFamily(unit)) or entry.family
        local classification = Readable(UnitClassification(unit))
        if classification then entry.rank = CLASSIFICATION_RANKS[classification] end
        entry.subtype = SubtypeFromModel(unit) or entry.subtype
    end

    local c = Categorize(npcID, entry)
    if db.announce then
        Print(("Killed %s [%s] (%d)"):format(entry.name, CategoryLabel(c), entry.count))
    end
    for _, handler in ipairs(ns.KillHandlers) do
        handler(npcID, entry, c, unit)
    end
    NotifyChanged()
end

-- True if you, your pet or a group member (or their pet) is on unit's threat table, i.e. fighting it.
-- Threat can be secret inside instances; there every mob is your group's, so unknowable counts as yes.
local function GroupIsFighting(unit)
    local function OnThreatTable(member)
        local status = UnitThreatSituation(member, unit)
        return issecret(status) or status ~= nil
    end
    if OnThreatTable("player") or OnThreatTable("pet") then return true end
    local prefix = IsInRaid() and "raid" or "party"
    for i = 1, GetNumGroupMembers() do
        if OnThreatTable(prefix .. i) or OnThreatTable(prefix .. "pet" .. i) then return true end
    end
    return false
end

local function CheckUnit(unit)
    if not UnitExists(unit) then return end

    local guid = Readable(UnitGUID(unit))
    if not guid or counted[guid] then return end

    local npcID = NpcIDFromGUID(guid)
    if not npcID then return end
    if Readable(UnitCanAttack("player", unit)) ~= true then return end

    local dead = Readable(UnitIsDead(unit))
    if dead == nil then return end

    if not dead then
        -- Untapped mobs aren't tap denied either, so also require that we're actually fighting it.
        if not engaged[guid] and Readable(UnitIsTapDenied(unit)) == false and GroupIsFighting(unit) then
            engaged[guid] = true
        end
    elseif engaged[guid] then
        engaged[guid] = nil
        counted[guid] = true
        -- Someone else may have tapped it after we engaged: then the corpse is theirs.
        if Readable(UnitIsTapDenied(unit)) ~= true then
            RecordKill(npcID, unit, guid)
        end
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
frame:RegisterEvent("UNIT_HEALTH")
frame:RegisterEvent("UNIT_THREAT_LIST_UPDATE")  -- catches the pull, before the first health change

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON_NAME then
            InitDB()
            self:UnregisterEvent("ADDON_LOADED")
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        wipe(engaged)
        wipe(counted)
    elseif event == "PLAYER_TARGET_CHANGED" then
        CheckUnit("target")
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        CheckUnit(arg1)
    elseif event == "UNIT_HEALTH" or event == "UNIT_THREAT_LIST_UPDATE" then
        if arg1 == "target" or arg1:find("^nameplate") then
            CheckUnit(arg1)
        end
    end
end)

-- Shared with the other files -------------------------------------------------------

ns.Touch = Touch
ns.Categorize = Categorize
ns.ForEachKill = ForEachKill
ns.Print = Print
ns.OTHER = OTHER
ns.GetSessionKills = function() return sessionKills end

-- Slash commands ---------------------------------------------------------------

-- Mobs whose faction is guessed or unknown, with Wowhead links for adding them to Overrides.lua.
local function ShowUnknown()
    local list = {}
    ForEachKill(function(npcID, entry)
        local c = Categorize(npcID, entry)
        if c.factionGuess or c.faction == UNCATEGORIZED then
            list[#list + 1] = { npcID = npcID, entry = entry, label = CategoryLabel(c) }
        end
    end)
    if #list == 0 then
        Print("Every mob you've killed has a known faction.")
        return
    end
    table.sort(list, function(a, b) return a.entry.count > b.entry.count end)
    Print(("%d mobs without a confirmed faction (add them to Overrides.lua):"):format(#list))
    for _, item in ipairs(list) do
        Print(("  %s [%s] x%d - %s"):format(item.entry.name, item.label, item.entry.count,
            ns.WOWHEAD_NPC_URL:format(item.npcID)))
    end
end

local function ShowHelp()
    Print("/solc (or /kt) - open/close the Sleepy Ogre Leisure Club window")
    Print("/solc sync <name> - swap kill stats with a player outside your guild (guildmates sync automatically)")
    Print("/solc forget <name> - remove a player's synced stats")
    Print("/solc sharing - turn sharing your kill stats on/off")
    Print("/solc bounty - this week's guild bounty and how far the guild is")
    Print("/solc bounties - the Bounty Board: pick this or next week's bounty (officers)")
    Print("/solc config - point values and guild settings (officers can change them)")
    Print("/solc unknown - mobs with a guessed or unknown faction, with Wowhead links")
    Print("/solc announce - toggle per-kill chat messages")
    Print("/solc minimap - show/hide the minimap button")
    Print("/solc reset - clear all data for this character")
end

SLASH_SOLC1 = "/solc"
SLASH_SOLC2 = "/kt"
SlashCmdList.SOLC = function(input)
    local msg, arg = strtrim(input or ""):match("^(%S*)%s*(.-)$")
    msg = msg:lower()
    local db = KillTrackerDB
    if msg == "" then
        ns.ToggleUI()
    elseif msg == "sync" and arg ~= "" then
        ns.SyncWith(arg)
    elseif msg == "forget" and arg ~= "" then
        ns.ForgetFriend(arg)
    elseif msg == "sharing" then
        db.sharing = not db.sharing
        Print("Sharing your kill stats " .. (db.sharing and "on." or "off."))
    elseif msg == "config" or msg == "settings" then
        ns.ToggleConfig()
    elseif msg == "bounties" or msg == "board" then
        ns.ToggleBountyBoard()
    elseif msg == "bounty" then
        ns.PrintBounty()
    elseif msg == "unknown" then
        ShowUnknown()
    elseif msg == "announce" then
        db.announce = not db.announce
        Print("Kill announcements " .. (db.announce and "on." or "off."))
    elseif msg == "minimap" then
        db.minimap.hide = not db.minimap.hide
        ns.UpdateMinimapButton()
        Print("Minimap button " .. (db.minimap.hide and "hidden." or "shown."))
    elseif msg == "reset" then
        wipe(db.kills)
        wipe(db.records)
        wipe(db.achievements)
        wipe(db.groupLog)
        db.pvp = { total = 0, unknown = 0, players = {} }
        db.points = { kills = 0, spent = 0 }
        db.bounty, db.guildBosses = nil, nil
        wipe(db.collection)
        wipe(db.mints)
        db.total, sessionKills = 0, 0
        db.syncID, db.seq = NewSyncID(), 0
        Print("All kill data reset.")
        NotifyChanged()
        if ns.OnDataReset then ns.OnDataReset() end
    else
        ShowHelp()
    end
end
