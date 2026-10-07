-- The guild activity feed: notable things each player did, synced to guildmates (Sync.lua) and shown on
-- the Guild home page. KillTrackerDB.events = { { t = time, k = kind, a, b, seq } }, oldest first, the
-- last MAX_EVENTS kept. Kinds:
--   L  killed a leader for the first time      a = npcID
--   R  killed a rare for the first time        a = npcID
--   A  earned an achievement                   a = achievement id ("subtype:Gnoll:100")
--   M  minted a picture                        a = picture number
--   W  won a picture in a puzzle race          a = picture number, b = who it was won from
--   B  did their share of a completed bounty   a = bounty id
--   D  killed a boss in a guild group          a = boss name, b = 1 for a final boss

local _, ns = ...

local MAX_EVENTS = 40
local MAX_FEED = 60

function ns.AddEvent(kind, a, b)
    local db = KillTrackerDB
    db.events = db.events or {}
    local event = { t = time(), k = kind, a = a, b = b }
    db.events[#db.events + 1] = event
    while #db.events > MAX_EVENTS do table.remove(db.events, 1) end
    ns.Touch(event)
end

-- A friend's events, merged into their stored list (deduplicated, capped).
function ns.MergeEvents(friend, events)
    friend.events = friend.events or {}
    local seen = {}
    for _, e in ipairs(friend.events) do seen[e.t .. e.k .. tostring(e.a)] = true end
    for _, e in ipairs(events) do
        if not seen[e.t .. e.k .. tostring(e.a)] then friend.events[#friend.events + 1] = e end
    end
    table.sort(friend.events, function(x, y) return x.t < y.t end)
    while #friend.events > MAX_EVENTS do table.remove(friend.events, 1) end
end

local function NpcName(npcID, source)
    local entry = source.kills and source.kills[tonumber(npcID)]
    return entry and entry.name or ("NPC " .. tostring(npcID))
end

local function AchievementText(id)
    local dimension, category, kills = tostring(id):match("^(%a+):(.*):(%d+)$")
    if not dimension then return tostring(id) end
    local name = dimension == "faction" and ns.BountyTribeName and ns.BountyTribeName(category) or category
    return ("%s kills: %s"):format(kills, name)
end

-- The picture a minted (M) or won (W) event is about, if its owner still has it.
local function EventMint(e, source)
    if e.k ~= "M" and e.k ~= "W" then return nil end
    if source == KillTrackerDB then
        for _, m in ipairs(KillTrackerDB.mints or {}) do
            if m.number == tonumber(e.a) then return m end
        end
        return nil
    end
    return source.mints and source.mints[tonumber(e.a)]
end

-- An event as text, or nil if unknown. who: the player's name; source: their stats (for mob names).
local function Describe(e, who, source)
    if e.k == "L" then
        return ("%s slew |cffffd100%s|r"):format(who, NpcName(e.a, source))
    elseif e.k == "R" then
        return ("%s killed the rare |cff0070dd%s|r"):format(who, NpcName(e.a, source))
    elseif e.k == "A" then
        return ("%s earned |cffff8000%s|r"):format(who, AchievementText(e.a))
    elseif e.k == "M" then
        local mint = EventMint(e, source)
        local rarity = mint and ns.MintRarity(mint.traits)
        return ("%s minted %spicture #%s"):format(who,
            rarity and ("|c%s%s|r "):format(ns.RARITY_COLORS[rarity], rarity:gsub("^%l", string.upper)) or "", tostring(e.a))
    elseif e.k == "W" then
        local mint = EventMint(e, source)
        local rarity = mint and ns.MintRarity(mint.traits)
        return ("%s won %spicture #%s%s"):format(who,
            rarity and ("|c%s%s|r "):format(ns.RARITY_COLORS[rarity], rarity:gsub("^%l", string.upper)) or "", tostring(e.a),
            e.b and (" from %s"):format(e.b) or "")
    elseif e.k == "B" then
        local bounty = ns.ResolveBounty and ns.ResolveBounty(e.a)
        return ("%s helped complete the bounty |cffffd100%s|r"):format(who, bounty and bounty.name or tostring(e.a))
    elseif e.k == "D" then
        return ("%s %s |cffffd100%s|r with the guild"):format(who, tonumber(e.b) == 1 and "cleared" or "killed", tostring(e.a))
    end
end

-- The guild feed, newest first: { { time, text, who, mint, owner } }, from you and everyone synced. mint: the
-- picture a minted/won event is about (click to view); owner: whose it is (nil for yours).
function ns.GetFeed()
    local feed = {}
    local function Add(who, source)
        for _, e in ipairs(source.events or {}) do
            local text = Describe(e, who, source)
            if text then
                feed[#feed + 1] = { time = e.t, text = text, who = who, mint = EventMint(e, source),
                    owner = source ~= KillTrackerDB and who or nil }
            end
        end
    end
    Add(ns.MyName(), KillTrackerDB)
    for _, friend in ipairs(ns.GetFriends()) do Add(friend.name, friend.stats) end
    table.sort(feed, function(x, y) return x.time > y.time end)
    while #feed > MAX_FEED do table.remove(feed) end
    return feed
end

-- "just now", "5m ago", "3h ago", "2d ago".
function ns.TimeAgo(t)
    local seconds = math.max(0, time() - (t or 0))
    if seconds < 60 then return "just now" end
    if seconds < 3600 then return ("%dm ago"):format(seconds / 60) end
    if seconds < 86400 then return ("%dh ago"):format(seconds / 3600) end
    return ("%dd ago"):format(seconds / 86400)
end
