-- Sharing kill stats with other players through hidden addon messages.
--
-- Every change to your data has a change number (KillTrackerDB.seq, see Core.lua), and friends keep
-- the number they're up to, so only changes are sent:
--   H  hello   "I'm <syncID> at change #N"       guild broadcast on login, after instances, every 5 min
--   G  get     "I have your <syncID> up to #N"   whispered when a friend's copy is behind
--   U  update  changed kills/records, as totals   whispered in answer to G; broadcast to the guild live
--   N  no      "I'm not sharing"                 whispered in answer to G when sharing is off
--   C  config  guild settings (Config.lua)        from officers: to the guild when changed, and whispered
--                                                to anyone whose hello shows older settings
-- Updates carry totals ("52 kills"), never increments, so applying one twice is harmless. An update
-- is applied only once complete and only if it continues from the receiver's copy; otherwise the
-- receiver asks for a catch-up. A new syncID (after /kt reset) makes friends fetch everything again.
-- Addon messages are blocked inside instances in 12.0.0, so nothing is sent there.
--
-- Wire format: H|6|syncID|seq|wantReply|configVersion|addonVersion   G|6|syncID|haveSeq   N|6
--              U|transferID|part|parts|chunk   C|transferID|part|parts|chunk (chunk of "6#version#settings#bounties")
-- Update payload: 6 # name # syncID # baseSeq # seq # total # kills # records # group kills # pictures # bounty
--                 # summary # events # gear # professions # showcase # removed pictures   (sections added
--                 later go at the end; receivers ignore unknown ones)
-- (items "~", fields "^"; npcID, count and time in base 36):
--   kill       = npcID^count^maxWeight[^name^type^rank^family^subtype]  (names only when new to the receiver)
--   record     = subtype^weight^mob^zone^time
--   group kill = npcID^spawnKey                  (for the de-duplicated combined total, see Combined.lua)
--   picture    = number^time^layer:option;layer:option...   (minted pictures, see Minting.lua)
--   bounty     = week^bounty id^kills            (this week's guild bounty kills, see Guild.lua; at most one)
--   summary    = earned points^PvP kills         (always sent, for the Members and Leaderboard pages)
--   event      = time^kind^a^b                   (guild activity feed, see Feed.lua)
--   gear       = race^sex^class^level^guid^slot:itemID[:enchant:suffix];...   (character and equipment, see
--                Gear.lua; only when changed, empty otherwise; enchant and suffix in decimal)
--   professions = P^line:rank:max:icon:name;...^line=recipeID,recipeID...^line=...   (see Professions.lua;
--                only when changed, empty otherwise; the "P" tells "no professions" from "unchanged")
--   showcase   = S^number,number,number^backdrop     (pictures on their Overview and the background option
--                behind their model, see Minting.lua; only when changed, empty otherwise; the "S" tells
--                "none" from "unchanged")
--   removed    = number,number                      (pictures given away since baseSeq, see Minting.lua)

local addonName, ns = ...

local PREFIX = "SOLC"
local GetMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
local ADDON_VERSION = GetMetadata and GetMetadata(addonName, "Version") or "0"
ns.ADDON_VERSION = ADDON_VERSION
local PROTOCOL = "6"
local SECTIONS = 13  -- sections in an update payload; more are allowed (from newer versions)
local CHUNK_SIZE = 230        -- addon messages are limited to 255 characters including the header
local MAX_PARTS = 1500        -- ignore absurdly large transfers (a big player's full update can pass 400)
local SEND_INTERVAL = 0.3     -- seconds between messages; throttled sends are retried
local LIVE_INTERVAL = 10      -- seconds between live update broadcasts (only if something changed)
local HELLO_INTERVAL = 300    -- seconds between hello broadcasts, to catch anything missed
local REPLY_TIMEOUT = 15      -- seconds to wait for an answer to /kt sync, or to a get before asking again
local TRANSFER_TIMEOUT = 120  -- seconds before an incomplete incoming transfer is dropped
local SECTION, ITEM, FIELD = "#", "~", "^"
local DIGITS = "0123456789abcdefghijklmnopqrstuvwxyz"

local issecret = issecretvalue or function() return false end

-- Text helpers ---------------------------------------------------------------

-- Strips separators and "|" (chat escape codes) from text that goes over the wire.
local function Clean(value)
    return (tostring(value or ""):gsub("[#~^|]", ""))
end

-- Cleaned text, or nil if empty.
local function Optional(text)
    text = Clean(text)
    if text ~= "" then return text end
end

local function Split(text, separator)
    local parts, start = {}, 1
    while true do
        local i = text:find(separator, start, true)
        if not i then
            parts[#parts + 1] = text:sub(start)
            return parts
        end
        parts[#parts + 1] = text:sub(start, i - 1)
        start = i + 1
    end
end

local function Base36(n)
    n = math.floor(n)
    if n <= 0 then return "0" end
    local s = ""
    while n > 0 do
        local d = n % 36
        s = DIGITS:sub(d + 1, d + 1) .. s
        n = math.floor(n / 36)
    end
    return s
end

local function FromBase36(s)
    return s and s ~= "" and tonumber(s, 36) or nil
end

-- 120.5, 0.05, 100 - up to three decimals, no trailing zeros.
local function Decimal(n)
    if not n then return "" end
    return (("%.3f"):format(n):gsub("%.?0+$", ""))
end

local function DisplayName(fullName)
    return Ambiguate and Ambiguate(fullName, "short") or fullName
end

-- Our own guild broadcasts come back to us; senders are "Name" or "Name-Realm". With last names (as on
-- this beta) UnitName gives "Lance" but we send as "Lance Hedman", so the name we really send as is
-- learned from the first message carrying our own syncID (see RecognizeMe).
local mySender

local function IsMe(sender)
    if sender == mySender then return true end
    local name, realm = sender:match("^([^-]+)-?(.*)$")
    return name == UnitName("player") and (realm == "" or realm == GetNormalizedRealmName())
end

-- True if syncID is ours: sender is us. Remembers that, keeps our full name (ns.MyName) and drops any
-- copy of ourselves stored as a friend.
local function RecognizeMe(sender, syncID)
    if syncID ~= KillTrackerDB.syncID then return false end
    mySender = sender
    local changed = KillTrackerDB.myName ~= DisplayName(sender) or KillTrackerFriends[sender] ~= nil
    KillTrackerDB.myName = DisplayName(sender)
    KillTrackerFriends[sender] = nil
    if changed and ns.OnFriendsChanged then ns.OnFriendsChanged() end
    return true
end

local function CanSend()
    return not IsInInstance()
end

-- Serializing ----------------------------------------------------------------

-- The professions section: levels and known recipes, if they changed after baseSeq (see Professions.lua).
local function SerializeProfessions(db, baseSeq)
    local p = db.professions
    if not p or (p.seq or 0) <= baseSeq then return "" end
    local levels = {}
    for _, prof in ipairs(p.list) do
        levels[#levels + 1] = table.concat({ Base36(prof.line), Base36(prof.rank), Base36(prof.max),
            Base36(tonumber(prof.icon) or 0), (Clean(prof.name):gsub("[:;=,]", "")) }, ":")
    end
    local parts = { "P", table.concat(levels, ";") }
    for line, recipes in pairs(p.recipes) do
        -- Only professions whose recipes changed (a skill-up alone doesn't resend them); receivers keep the rest.
        if (p.recipeSeq and p.recipeSeq[line] or p.seq) > baseSeq then
            local ids = {}
            for i, id in ipairs(recipes) do ids[i] = Base36(id) end
            parts[#parts + 1] = Base36(line) .. "=" .. table.concat(ids, ",")
        end
    end
    return table.concat(parts, FIELD)
end

-- The showcase section: the pictures on your Overview, if they changed after baseSeq (see Minting.lua).
local function SerializeShowcase(db, baseSeq)
    local showcase = db.showcase
    if not showcase or (showcase.seq or 0) <= baseSeq then return "" end
    local numbers = {}
    for i, number in ipairs(showcase.numbers) do numbers[i] = Base36(number) end
    return "S" .. FIELD .. table.concat(numbers, ",") .. FIELD .. (showcase.backdrop or "")
end

-- Pictures given away after baseSeq (won by someone in a puzzle race), so receivers drop them.
local function SerializeRemoved(db, baseSeq)
    local numbers = {}
    for number, seq in pairs(db.removedMints or {}) do
        if seq > baseSeq then numbers[#numbers + 1] = Base36(number) end
    end
    return table.concat(numbers, ",")
end

-- Everything in db changed after baseSeq (0 = everything).
local function Serialize(db, baseSeq)
    local kills, records = {}, {}
    for npcID, e in pairs(db.kills) do
        if (e.seq or 0) > baseSeq then
            local fields = { Base36(npcID), Base36(e.count), Decimal(e.maxWeight) }
            -- Names are only needed by friends who don't have this mob yet; unknown NPCs' details may change.
            if (e.created or 0) > baseSeq or not ns.NPCs[npcID] then
                fields[4], fields[5], fields[6], fields[7], fields[8] =
                    Clean(e.name), Clean(e.type), Clean(e.rank), Clean(e.family), Clean(e.subtype)
            end
            kills[#kills + 1] = table.concat(fields, FIELD)
        end
    end
    for _, r in pairs(db.records) do
        if (r.seq or 0) > baseSeq then
            records[#records + 1] = table.concat({ Clean(r.name), Decimal(r.weight), Clean(r.mob), Clean(r.zone), Base36(r.time) }, FIELD)
        end
    end
    -- The group log is in change order, so only its tail can be new.
    local pictures = {}
    for _, mint in ipairs(db.mints or {}) do
        if (mint.seq or 0) > baseSeq then
            local traits = {}
            for key, id in pairs(mint.traits) do traits[#traits + 1] = Clean(key) .. ":" .. Clean(id) end
            table.sort(traits)
            pictures[#pictures + 1] = table.concat({ Base36(mint.number), Base36(mint.time), table.concat(traits, ";") }, FIELD)
        end
    end
    local group = {}
    for i = #db.groupLog, 1, -1 do
        local g = db.groupLog[i]
        if g.s <= baseSeq then break end
        group[#group + 1] = Base36(g.n) .. FIELD .. Clean(g.k)
    end
    local bounty = ""
    if db.bounty and (db.bounty.seq or 0) > baseSeq then
        bounty = table.concat({ Base36(db.bounty.week), Clean(db.bounty.target), Base36(db.bounty.kills) }, FIELD)
    end
    local summary = table.concat({ Base36(ns.GetPoints and ns.GetPoints().earned or 0), Base36(db.pvp and db.pvp.total or 0) }, FIELD)
    local gear = ""
    if db.gear and (db.gear.seq or 0) > baseSeq then
        local g, items = db.gear, {}
        for slot, itemID in pairs(g.items) do
            local extra = g.extras and g.extras[slot]
            items[#items + 1] = Base36(slot) .. ":" .. Base36(itemID)
                .. (extra and (":%d:%d"):format(extra.enchant, extra.suffix) or "")  -- decimal: suffixes can be negative
        end
        gear = table.concat({ Base36(g.race or 0), Base36(g.sex or 0), Clean(g.class), Base36(g.level or 0), Clean(g.guid),
            table.concat(items, ";") }, FIELD)
    end
    local events = {}
    for _, e in ipairs(db.events or {}) do
        if (e.seq or 0) > baseSeq then
            events[#events + 1] = table.concat({ Base36(e.t), Clean(e.k), Clean(e.a), Clean(e.b) }, FIELD)
        end
    end
    return table.concat({ PROTOCOL, Clean(ns.MyName()), db.syncID, Base36(baseSeq), Base36(db.seq), Base36(db.total),
        table.concat(kills, ITEM), table.concat(records, ITEM), table.concat(group, ITEM), table.concat(pictures, ITEM),
        bounty, summary, table.concat(events, ITEM), gear, SerializeProfessions(db, baseSeq),
        SerializeShowcase(db, baseSeq), SerializeRemoved(db, baseSeq) }, SECTION)
end

-- Returns the update as a table, or nil if the payload is malformed or from another protocol.
local function Deserialize(payload)
    local s = Split(payload, SECTION)
    if s[1] ~= PROTOCOL or #s < SECTIONS then return end
    local update = {
        name = Optional(s[2]), syncID = Optional(s[3]), base = FromBase36(s[4]), seq = FromBase36(s[5]),
        total = FromBase36(s[6]) or 0, kills = {}, records = {}, group = {},
    }
    if not update.syncID or not update.base or not update.seq then return end

    for _, item in ipairs(Split(s[7], ITEM)) do
        local f = Split(item, FIELD)
        local npcID, count = FromBase36(f[1]), FromBase36(f[2])
        if npcID and count then
            update.kills[npcID] = {
                count = count, maxWeight = tonumber(f[3]), name = Optional(f[4]),
                type = Optional(f[5]), rank = Optional(f[6]), family = Optional(f[7]), subtype = Optional(f[8]),
            }
        end
    end
    for _, item in ipairs(Split(s[8], ITEM)) do
        local f = Split(item, FIELD)
        local subtype, weight, time = Optional(f[1]), tonumber(f[2]), FromBase36(f[5])
        if subtype and weight and time then
            update.records["subtype:" .. subtype] = { name = subtype, weight = weight, mob = Optional(f[3]) or "?", zone = Optional(f[4]), time = time }
        end
    end
    for _, item in ipairs(Split(s[9], ITEM)) do
        local f = Split(item, FIELD)
        local npcID, key = FromBase36(f[1]), Optional(f[2])
        if npcID and key then update.group[key] = npcID end
    end
    update.mints = {}
    for _, item in ipairs(Split(s[10], ITEM)) do
        local f = Split(item, FIELD)
        local number, time = FromBase36(f[1]), FromBase36(f[2])
        if number and time and f[3] then
            local traits = {}
            for pair in f[3]:gmatch("[^;]+") do
                local key, id = pair:match("^([%w_]+):([%w_]+)$")
                if key then traits[key] = id end
            end
            update.mints[#update.mints + 1] = { number = number, time = time, traits = traits }
        end
    end
    local f = Split(s[11], FIELD)
    local week, target, kills = FromBase36(f[1]), Optional(f[2]), FromBase36(f[3])
    if week and target and kills then update.bounty = { week = week, target = target, kills = kills } end
    f = Split(s[12], FIELD)
    update.earned, update.pvp = FromBase36(f[1]), FromBase36(f[2])
    update.events = {}
    for _, item in ipairs(Split(s[13], ITEM)) do
        local e = Split(item, FIELD)
        local t, kind = FromBase36(e[1]), Optional(e[2])
        if t and kind then update.events[#update.events + 1] = { t = t, k = kind, a = Optional(e[3]), b = Optional(e[4]) } end
    end
    f = Split(s[14] or "", FIELD)  -- from 0.37.0 on
    if f[6] then
        local gear = { race = FromBase36(f[1]), sex = FromBase36(f[2]), class = Optional(f[3]), level = FromBase36(f[4]),
            guid = Optional(f[5]), items = {}, extras = {} }
        for item in f[6]:gmatch("[^;]+") do
            local p = Split(item, ":")
            local slot, itemID = FromBase36(p[1]), FromBase36(p[2])
            if slot and itemID then
                gear.items[slot] = itemID
                local enchant, suffix = tonumber(p[3]), tonumber(p[4])
                if enchant and suffix then gear.extras[slot] = { enchant = enchant, suffix = suffix } end
            end
        end
        update.gear = gear
    end
    f = Split(s[15] or "", FIELD)  -- from 0.37.0 on
    if f[1] == "P" then
        local professions = { list = {}, recipes = {} }
        for entry in (f[2] or ""):gmatch("[^;]+") do
            local p = Split(entry, ":")
            local line = FromBase36(p[1])
            if line then
                professions.list[#professions.list + 1] = { line = line, rank = FromBase36(p[2]) or 0,
                    max = FromBase36(p[3]) or 0, icon = FromBase36(p[4]), name = Optional(p[5]) or "?" }
            end
        end
        for i = 3, #f do
            local line, ids = f[i]:match("^(%w+)=(.*)$")
            line = FromBase36(line)
            if line then
                local recipes = {}
                for id in ids:gmatch("[^,]+") do recipes[#recipes + 1] = FromBase36(id) end
                professions.recipes[line] = recipes
            end
        end
        update.professions = professions
    end
    f = Split(s[16] or "", FIELD)  -- from 0.37.0 on
    if f[1] == "S" then
        local numbers = {}
        for number in (f[2] or ""):gmatch("[^,]+") do numbers[#numbers + 1] = FromBase36(number) end
        update.showcase = { numbers = numbers, backdrop = Optional(f[3]) }  -- backdrop from 0.39.0 on
    end
    update.removed = {}  -- from 0.38.0 on
    for number in (s[17] or ""):gmatch("[^,]+") do update.removed[#update.removed + 1] = FromBase36(number) end
    return update
end

-- Applies an update to the friend's stored copy. Returns false if it doesn't continue from that copy.
local function Apply(sender, update)
    local friend = KillTrackerFriends[sender]
    if update.base == 0 then
        friend = { kills = {}, records = {}, group = {}, mints = {}, version = friend and friend.version }  -- full update: start over
    elseif not friend or friend.syncID ~= update.syncID or (friend.seq or 0) < update.base then
        return false
    end
    for npcID, k in pairs(update.kills) do
        local e = friend.kills[npcID] or {}
        e.count, e.maxWeight = k.count, k.maxWeight or e.maxWeight
        e.name = k.name or e.name or ("NPC " .. npcID)
        e.type, e.rank, e.family, e.subtype = k.type or e.type, k.rank or e.rank, k.family or e.family, k.subtype or e.subtype
        friend.kills[npcID] = e
    end
    for key, record in pairs(update.records) do
        friend.records[key] = record
    end
    friend.mints = friend.mints or {}  -- [number] = { number, time, traits }: their minted pictures
    -- Removals first: numbers are never reused, but if one were, the new picture should stay.
    for _, number in ipairs(update.removed) do friend.mints[number] = nil end
    for _, mint in ipairs(update.mints) do
        friend.mints[mint.number] = mint
    end
    friend.group = friend.group or {}  -- [spawnKey] = npcID: their kills made in a group
    for key, npcID in pairs(update.group) do
        friend.group[key] = npcID
    end
    if update.bounty then friend.bounty = update.bounty end  -- { week, target, kills }
    friend.earned, friend.pvpTotal = update.earned or friend.earned, update.pvp or friend.pvpTotal
    if #update.events > 0 then ns.MergeEvents(friend, update.events) end
    if update.gear then friend.gear = update.gear end  -- see Gear.lua
    if update.professions then  -- see Professions.lua; recipes come only for professions whose recipes changed
        local old = friend.professions
        for _, prof in ipairs(update.professions.list) do
            if not update.professions.recipes[prof.line] and old and old.recipes then
                update.professions.recipes[prof.line] = old.recipes[prof.line]
            end
        end
        friend.professions = update.professions
    end
    if update.showcase then friend.showcase = update.showcase end  -- see Minting.lua
    friend.name, friend.syncID, friend.total = update.name, update.syncID, update.total
    friend.version = ns.SeenVersion(sender) or friend.version
    friend.seq = math.max(friend.seq or 0, update.seq)
    friend.received = time()
    KillTrackerFriends[sender] = friend
    return true
end

-- Sending --------------------------------------------------------------------

local queue = {}  -- { channel, target, message }
local ticker

local function SendResult(item)
    local ok, result = pcall(C_ChatInfo.SendAddonMessage, PREFIX, item.message, item.channel, item.target)
    if not ok then return "failed" end
    local results = Enum and Enum.SendAddonMessageResult
    if result == nil or result == true or (results and result == results.Success) then return "sent" end
    if results and result == results.AddonMessageThrottle then return "throttled" end
    return "failed"
end

local function Pump()
    local item = queue[1]
    if not item then
        ticker:Cancel()
        ticker = nil
        return
    end
    if not CanSend() then return end  -- hold everything until we're out of the instance
    local result = SendResult(item)
    if result == "throttled" then return end
    table.remove(queue, 1)
    if result == "failed" and item.target then
        -- Drop the rest for this player; partial transfers are useless. Their next hello recovers.
        for i = #queue, 1, -1 do
            if queue[i].target == item.target then table.remove(queue, i) end
        end
    end
end

local function Queue(channel, target, message)
    queue[#queue + 1] = { channel = channel, target = target, message = message }
    ticker = ticker or C_Timer.NewTicker(SEND_INTERVAL, Pump)
end

-- target nil = broadcast to the guild.
local function Send(target, message)
    Queue(target and "WHISPER" or "GUILD", target, message)
end

local function SendHello(target, wantReply)
    local db = KillTrackerDB
    if not db.sharing or (not target and not IsInGuild()) then return end
    Send(target, ("H|%s|%s|%s|%d|%s|%s"):format(PROTOCOL, db.syncID, Base36(db.seq), wantReply and 1 or 0,
        Base36(ns.ConfigVersion()), Clean(ADDON_VERSION)))
end

local function SendGet(target, syncID, haveSeq)
    Send(target, ("G|%s|%s|%s"):format(PROTOCOL, syncID or "-", Base36(haveSeq or 0)))
end

-- Sends a payload in numbered chunks as kind ("U" or "C") messages. Transfer IDs count up (from a random
-- start), so two transfers in flight never share one; random IDs could, and their chunks would mix.
local lastTransfer = math.random(0, 9999)
local function SendChunked(kind, target, payload)
    lastTransfer = (lastTransfer + 1) % 10000
    local id = tostring(lastTransfer)
    local parts = math.max(1, math.ceil(#payload / CHUNK_SIZE))
    for part = 1, parts do
        local chunk = payload:sub((part - 1) * CHUNK_SIZE + 1, part * CHUNK_SIZE)
        Send(target, ("%s|%s|%d|%d|%s"):format(kind, id, part, parts, chunk))
    end
end

local function SendUpdate(target, baseSeq)
    SendChunked("U", target, Serialize(KillTrackerDB, baseSeq))
end

-- Our guild settings, if we're an officer who may share them (target nil = the whole guild).
local function SendConfig(target)
    if not IsInGuild() or not ns.CanEditConfig() or ns.ConfigVersion() == 0 then return end
    local values, bounties = ns.SerializeConfig()
    SendChunked("C", target, table.concat({ PROTOCOL, Base36(ns.ConfigVersion()), values, bounties }, SECTION))
end

local awaiting = {}  -- [sender] = time we sent a get that hasn't been answered yet

-- Asks for whatever is missing from our copy of sender's data. Returns false if we're up to date.
local function CatchUp(sender, syncID, seq)
    local friend = KillTrackerFriends[sender]
    local upToDate = friend and friend.syncID == syncID and friend.seq == seq
    if upToDate then return false end
    if awaiting[sender] and GetTime() - awaiting[sender] < REPLY_TIMEOUT then return true end  -- already asked
    awaiting[sender] = GetTime()
    if friend and friend.syncID == syncID and (friend.seq or 0) < seq then
        SendGet(sender, syncID, friend.seq)
    else
        SendGet(sender, nil, 0)  -- unknown, reset or rolled back: get everything
    end
    return true
end

-- Receiving ------------------------------------------------------------------

local incoming = {}       -- ["sender|transferID"] = { parts, count, chunks, started }
-- [short name, lowercase] = { name, started } while /kt sync awaits an answer. Only manual syncs print
-- to chat; automatic guild syncing is silent and just updates the stats in the window.
local pendingManual = {}

local function OnUpdateComplete(sender, payload)
    awaiting[sender] = nil
    local short = DisplayName(sender):lower()
    local update = Deserialize(payload)
    if update and RecognizeMe(sender, update.syncID) then return end
    if not update then
        if pendingManual[short] then
            pendingManual[short] = nil
            ns.Print(("%s has a different SOLC version; you both need the same one to sync."):format(DisplayName(sender)))
        end
        return
    end
    if not Apply(sender, update) then
        CatchUp(sender, update.syncID, update.seq)  -- we missed something in between
        return
    end
    if pendingManual[short] then
        pendingManual[short] = nil
        ns.Print(("Synced with %s: %d kills."):format(DisplayName(sender), update.total))
    end
    if update.bounty and ns.CheckBountyGoal then ns.CheckBountyGoal() end
    if ns.OnFriendsChanged then ns.OnFriendsChanged() end
end

local handlers = {}

-- "0.36.0" -> comparable numbers. True if version a is newer than b.
local function IsNewer(a, b)
    local x, y = {}, {}
    for n in tostring(a):gmatch("%d+") do x[#x + 1] = tonumber(n) end
    for n in tostring(b):gmatch("%d+") do y[#y + 1] = tonumber(n) end
    for i = 1, math.max(#x, #y) do
        if (x[i] or 0) ~= (y[i] or 0) then return (x[i] or 0) > (y[i] or 0) end
    end
    return false
end
ns.IsNewerVersion = IsNewer

-- Remembers each player's SOLC version (shown on the Members page) and tells you, once per newer
-- version, when a guildmate runs a newer one than yours.
local warnedVersion
local seenVersions = {}  -- [sender] = version from their hello, until their stats arrive
function ns.SeenVersion(sender) return seenVersions[sender] end
local function NoteVersion(sender, version)
    if not version or version == "" then return end
    seenVersions[sender] = version
    if KillTrackerFriends[sender] then KillTrackerFriends[sender].version = version end
    if IsNewer(version, ADDON_VERSION) and (not warnedVersion or IsNewer(version, warnedVersion)) then
        warnedVersion = version
        ns.Print(("%s has SOLC |cff33ff33%s|r - you have %s. Update it to keep everything in sync with your guild."):format(
            DisplayName(sender), version, ADDON_VERSION))
    end
end

function handlers.H(sender, channel, protocol, syncID, seq, wantReply, configVersion, addonVersion)
    NoteVersion(sender, addonVersion)  -- also from players on another protocol: they're the ones to tell
    seq = FromBase36(seq)
    if protocol ~= PROTOCOL or not seq or RecognizeMe(sender, syncID) then return end
    if (FromBase36(configVersion) or 0) < ns.ConfigVersion() and channel == "GUILD" then
        SendConfig(sender)  -- they have older guild settings (only officers' addons send)
    end
    local short = DisplayName(sender):lower()
    if not CatchUp(sender, syncID, seq) and pendingManual[short] then
        pendingManual[short] = nil
        ns.Print(("Already up to date with %s."):format(DisplayName(sender)))
    end
    if wantReply == "1" then
        if KillTrackerDB.sharing then
            SendHello(sender, false)
        elseif channel == "WHISPER" then
            Send(sender, "N|" .. PROTOCOL)  -- a manual /kt sync deserves an answer
        end
    end
end

-- Requests for our data are collected for GET_BATCH seconds: when a few guildmates ask at once (typically
-- right after we log in), one guild broadcast from the earliest change any of them lacks answers them all,
-- instead of the same data whispered to each. Updates carry totals, so getting data you already have is
-- harmless. A single request, or one from outside the guild (/kt sync), is whispered as before.
local GET_BATCH = 2
local gets = {}  -- [sender] = the change number they have
local getsTimer

local function AnswerGets()
    getsTimer = nil
    local senders, base = {}, nil
    for sender, have in pairs(gets) do
        senders[#senders + 1] = sender
        base = base and math.min(base, have) or have
    end
    wipe(gets)
    if #senders == 1 then
        SendUpdate(senders[1], base)
    elseif #senders > 1 then
        SendUpdate(nil, base)
    end
end

function handlers.G(sender, _, protocol, syncID, haveSeq)
    if protocol ~= PROTOCOL then return end
    local db = KillTrackerDB
    if not db.sharing then
        Send(sender, "N|" .. PROTOCOL)
        return
    end
    haveSeq = FromBase36(haveSeq) or 0
    local base = (syncID == db.syncID and haveSeq <= db.seq) and haveSeq or 0
    if not IsInGuild() or not ns.IsGuildMember(sender) then
        SendUpdate(sender, base)  -- they can't hear a guild broadcast
        return
    end
    gets[sender] = math.min(gets[sender] or base, base)
    getsTimer = getsTimer or C_Timer.NewTimer(GET_BATCH, AnswerGets)
end

function handlers.N(sender)
    local short = DisplayName(sender):lower()
    if pendingManual[short] then
        pendingManual[short] = nil
        ns.Print(("%s isn't sharing kill stats right now."):format(DisplayName(sender)))
    end
end

-- Collects the chunks of a transfer; calls onComplete(sender, payload) once all have arrived.
local function Collect(kind, sender, id, part, parts, chunk, onComplete)
    part, parts = tonumber(part), tonumber(parts)
    if not part or not parts or not chunk or parts > MAX_PARTS or part < 1 or part > parts then return end
    local key = kind .. "|" .. sender .. "|" .. id
    local transfer = incoming[key]
    if not transfer then
        transfer = { parts = parts, count = 0, chunks = {}, started = GetTime() }
        incoming[key] = transfer
    end
    if not transfer.chunks[part] then
        transfer.chunks[part] = chunk
        transfer.count = transfer.count + 1
    end
    if transfer.count == transfer.parts then
        incoming[key] = nil
        onComplete(sender, table.concat(transfer.chunks))
    end
end

function handlers.U(sender, _, id, part, parts, chunk)
    Collect("U", sender, id, part, parts, chunk, OnUpdateComplete)
end

-- Guild settings: Config.lua applies them only if they're newer and the sender is an officer.
function handlers.C(sender, channel, id, part, parts, chunk)
    if channel ~= "GUILD" and channel ~= "WHISPER" then return end
    Collect("C", sender, id, part, parts, chunk, function(from, payload)
        local s = Split(payload, SECTION)
        if s[1] == PROTOCOL then ns.ReceiveConfig(from, FromBase36(s[2]), s[3], s[4]) end
    end)
end

local function OnAddonMessage(prefix, message, channel, sender)
    if prefix ~= PREFIX or issecret(message) or issecret(sender) or IsMe(sender) then return end
    local fields = Split(message, "|")
    local handler = handlers[fields[1]]
    if handler then
        -- Chunks keep any "|" inside them (there shouldn't be any, but don't split data).
        if fields[1] == "U" or fields[1] == "C" then
            local id, part, parts, chunk = message:match("^%a|(%d+)|(%d+)|(%d+)|(.*)$")
            if id then handler(sender, channel, id, part, parts, chunk) end
        else
            handler(sender, channel, select(2, unpack(fields)))
        end
    end
end

-- Timers and events ------------------------------------------------------------

local lastBroadcastSeq    -- change number our guild already has from us
local wasInInstance = false

-- Live updates: broadcast whatever changed since the last broadcast.
local function BroadcastChanges()
    local db = KillTrackerDB
    if not db.sharing or not IsInGuild() or not CanSend() then return end
    lastBroadcastSeq = lastBroadcastSeq or db.seq
    if db.seq > lastBroadcastSeq then
        SendUpdate(nil, lastBroadcastSeq)
        lastBroadcastSeq = db.seq
    end
end

-- Drops incomplete transfers and unanswered /kt sync requests.
local function Cleanup()
    local now = GetTime()
    for key, transfer in pairs(incoming) do
        if now - transfer.started > TRANSFER_TIMEOUT then incoming[key] = nil end
    end
    for short, pending in pairs(pendingManual) do
        if now - pending.started > REPLY_TIMEOUT then
            pendingManual[short] = nil
            ns.Print(("No answer from %s. Are they online with the same SOLC version?"):format(pending.name))
        end
    end
end

-- Your other characters on this account never sync with this one (they're never online together), so on
-- logout this character is stored in the account-wide KillTrackerFriends like a synced guildmate: they see
-- it everywhere guildmates show. The copy is dropped again when this character logs in (RecognizeMe, by
-- its syncID), so a character never sees itself twice.
local myRealm  -- remembered while playing (the game may no longer tell during logout); nil without realms
local function RememberRealm()
    local realm = GetNormalizedRealmName and GetNormalizedRealmName()
    if realm and realm ~= "" and not issecret(realm) then myRealm = realm end
end

-- Returns what happened, kept in KillTrackerDB.otherCharacters for finding problems.
local function SaveForOtherCharacters()
    local db = KillTrackerDB
    RememberRealm()
    if not db or not db.syncID then return "skipped: no data" end
    -- The name others see us by: learned from our own messages, else the name (with the realm if there is
    -- one; this beta's megaservers have none, and senders come without it).
    local key = mySender or (myRealm and (ns.MyName() .. "-" .. myRealm) or ns.MyName())
    local update = Deserialize(Serialize(db, 0))
    if not update then return "skipped: couldn't read own data" end
    KillTrackerFriends[key] = nil  -- a full copy, not an update
    Apply(key, update)
    if not KillTrackerFriends[key] then return "skipped: copy not stored" end
    KillTrackerFriends[key].version = ADDON_VERSION
    return "saved as " .. key
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:SetScript("OnEvent", function(_, event, ...)
    if event == "CHAT_MSG_ADDON" then
        OnAddonMessage(...)
    elseif event == "PLAYER_LOGIN" then
        RememberRealm()
        lastBroadcastSeq = KillTrackerDB.seq
        for fullName, friend in pairs(KillTrackerFriends) do
            if friend.syncID == KillTrackerDB.syncID then RecognizeMe(fullName, friend.syncID) end
        end
        C_Timer.NewTicker(LIVE_INTERVAL, function()
            BroadcastChanges()
            Cleanup()
        end)
        C_Timer.NewTicker(HELLO_INTERVAL, function() if CanSend() then SendHello(nil, false) end end)
        C_Timer.After(10, function() SendHello(nil, true) end)  -- guild info is ready a bit after login
    elseif event == "PLAYER_ENTERING_WORLD" then
        RememberRealm()
        local inInstance = IsInInstance()
        if wasInInstance and not inInstance then SendHello(nil, true) end
        wasInInstance = inInstance
    elseif event == "PLAYER_LOGOUT" then
        -- Errors at logout never reach the screen; keep any in this character's data to find later.
        local ok, result = pcall(SaveForOtherCharacters)
        KillTrackerDB.otherCharactersError = nil  -- replaced by otherCharacters
        KillTrackerDB.otherCharacters = ("%s %s"):format(date("%Y-%m-%d %H:%M"), ok and tostring(result) or ("error: " .. tostring(result)))
    end
end)
C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)

-- Public ---------------------------------------------------------------------

-- Finds the stored friend whose full or short name matches (case-insensitive).
local function FindFriend(name)
    name = name:lower()
    for fullName in pairs(KillTrackerFriends) do
        if fullName:lower() == name or DisplayName(fullName):lower() == name then return fullName end
    end
end

-- Manual sync, for players outside the guild (guildmates sync by themselves).
function ns.SyncWith(target)
    if not CanSend() then
        ns.Print("Syncing doesn't work inside dungeons, raids or battlegrounds.")
        return
    end
    target = FindFriend(target) or target
    pendingManual[DisplayName(target):lower()] = { name = DisplayName(target), started = GetTime() }
    ns.Print(("Syncing with %s..."):format(DisplayName(target)))
    Send(target, ("H|%s|%s|%s|1"):format(PROTOCOL, KillTrackerDB.syncID, Base36(KillTrackerDB.seq)))
end

-- Syncs with the targeted player, if any.
function ns.SyncWithTarget()
    if not UnitIsPlayer("target") or UnitIsUnit("target", "player") then
        ns.Print("Target another player to sync kill stats with them.")
        return
    end
    local name, realm = UnitName("target")
    if issecret(name) then return end
    ns.SyncWith(realm and realm ~= "" and (name .. "-" .. realm) or name)
end

function ns.ForgetFriend(name)
    local fullName = FindFriend(name)
    if not fullName then
        ns.Print(("No synced stats for %s."):format(name))
        return
    end
    KillTrackerFriends[fullName] = nil
    ns.Print(("Removed %s's kill stats. Guildmates come back on their next update."):format(DisplayName(fullName)))
    if ns.OnFriendsChanged then ns.OnFriendsChanged() end
end

-- New guild settings saved here: send them to the guild.
function ns.BroadcastConfig()
    if CanSend() then SendConfig(nil) end
end

-- After /kt reset: friends must drop their copy, which the new syncID in our hello tells them.
function ns.OnDataReset()
    lastBroadcastSeq = 0
    if CanSend() then SendHello(nil, false) end
end

-- Synced friends, sorted by name: { { key, name, stats } }.
function ns.GetFriends()
    local list = {}
    for fullName, stats in pairs(KillTrackerFriends) do
        list[#list + 1] = { key = fullName, name = DisplayName(fullName), stats = stats }
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end
