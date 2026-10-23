-- Ogre Godz tribute: a chest made by hand in the dev menu (Dev.lua) with whatever's put in it (pieces, ingredients,
-- points, plinko drops: Unlocks.lua's ns.AddTribute), for you or a guildmate. A guildmate's goes as addon whispers
-- (PREFIX), in parts (an addon message holds 255 characters): "T:<id>:<part>/<parts>:<text>", the text
-- "t=<tier>;p=<points>;d=<plinko drops>;u=<option key>;i=<ingredient>*<n>;...;n=<note>". Their SOLC only takes it
-- from a dev character (ns.IsDevSender: the sender's character id in their own guild roster, Config.lua), only once
-- (KillTrackerDB.giftsTaken, by id), and answers "OK:<id>". Then the Ogre Godz float down to tell them (DMSay.lua);
-- the chest waits on their PIX page, glowing (Gallery.lua), and opens with its own show (Chests.lua).

local _, ns = ...

local PREFIX = "SOLCTRIB"
local PART_SIZE = 200
local SEND_INTERVAL = 0.3  -- (WoW drops addon messages sent in a burst)
local TIMEOUT = 15
local MAX_POINTS, MAX_DROPS, MAX_COUNT = 100000, 10, 99
local issecret = issecretvalue or function() return false end

-- The wire ----------------------------------------------------------------------------------------------------------

local function Clean(note) return (tostring(note or ""):gsub("[;|\n]", " "):sub(1, 80)) end

local function Serialize(spec)
    local parts = { "t=" .. (tonumber(spec.tier) or 4), "p=" .. (tonumber(spec.points) or 0), "d=" .. (tonumber(spec.plinko) or 0) }
    for _, item in ipairs(spec.items or {}) do
        if item.kind == "unlock" then parts[#parts + 1] = "u=" .. item.key
        elseif item.kind == "ingredient" then parts[#parts + 1] = ("i=%s*%d"):format(item.key, item.n or 1) end
    end
    parts[#parts + 1] = "n=" .. Clean(spec.note)
    return table.concat(parts, ";")
end

-- A tribute from its text, checked (nothing unknown, nothing silly); nil if it isn't one.
local function Parse(text)
    local spec = { items = {}, note = "" }
    for part in text:gmatch("[^;]+") do
        local key, value = part:match("^(%a)=(.*)$")
        if key == "t" then spec.tier = math.max(1, math.min(#ns.CHEST_TIERS, tonumber(value) or 4))
        elseif key == "p" then spec.points = math.max(0, math.min(MAX_POINTS, math.floor(tonumber(value) or 0)))
        elseif key == "d" then spec.plinko = math.max(0, math.min(MAX_DROPS, math.floor(tonumber(value) or 0)))
        elseif key == "n" then spec.note = Clean(value)
        elseif key == "u" and ns.OptionByKey(value) and #spec.items < ns.TRIBUTE_MAX_ITEMS then
            spec.items[#spec.items + 1] = { kind = "unlock", key = value }
        elseif key == "i" and #spec.items < ns.TRIBUTE_MAX_ITEMS then
            local ingredient, n = value:match("^([%w_]+)%*(%d+)$")
            if ingredient and ns.INGREDIENTS[ingredient] then
                spec.items[#spec.items + 1] = { kind = "ingredient", key = ingredient, n = math.max(1, math.min(MAX_COUNT, tonumber(n))) }
            end
        end
    end
    if not spec.tier then return nil end
    return spec
end

local queue, sending = {}, false
local function Pump()
    local item = table.remove(queue, 1)
    if not item then sending = false return end
    pcall(C_ChatInfo.SendAddonMessage, PREFIX, item.message, "WHISPER", item.target)
    if item.sent then item.sent() end
    C_Timer.After(SEND_INTERVAL, Pump)
end
local function Send(message, target, sent)
    queue[#queue + 1] = { message = message, target = target, sent = sent }
    if not sending then sending = true Pump() end
end

-- Telling them -------------------------------------------------------------------------------------------------------

-- A tribute that just came: the Ogre Godz float down to say so (DMSay.lua), and a line in the chat. Nothing opens:
-- it waits on the PIX page, glowing, until they open it.
function ns.AnnounceTribute(spec)
    if ns.ShowOgreGodz then ns.ShowOgreGodz(spec) end
    ns.Print("|cffffd100The Ogre Godz have granted you a tribute chest!|r It waits on your PIX page.")
end

-- Sending -------------------------------------------------------------------------------------------------------------

local waiting = {}  -- [id] = who, until they answer

-- Gives a tribute (spec: Unlocks.lua's) to target (a guildmate's full name, as KillTrackerFriends has them) or, with
-- none, to you.
function ns.SendTribute(spec, target)
    if not ns.IsDev() then return end
    if not target then
        ns.AddTribute(spec)
        ns.AnnounceTribute(spec)
        return
    end
    local id = ("%x%04x"):format(time(), math.random(0, 0xffff))
    local text = Serialize(spec)
    local count = math.ceil(#text / PART_SIZE)
    local short = Ambiguate(target, "short")
    waiting[id] = short
    for k = 1, count do
        local last = k == count
        Send(("T:%s:%d/%d:%s"):format(id, k, count, text:sub((k - 1) * PART_SIZE + 1, k * PART_SIZE)), target, last and function()
            C_Timer.After(TIMEOUT, function()
                if waiting[id] then
                    waiting[id] = nil
                    ns.Print(("No answer from %s about the tribute - offline, or on an older SOLC? Nothing was given."):format(short))
                end
            end)
        end or nil)
    end
    ns.Print(("Sending tribute to %s..."):format(short))
end

-- Receiving -----------------------------------------------------------------------------------------------------------

local partial = {}  -- [id] = { count, parts }
local listener = CreateFrame("Frame")
listener:RegisterEvent("CHAT_MSG_ADDON")
listener:SetScript("OnEvent", function(_, _, prefix, message, channel, sender)
    if prefix ~= PREFIX or channel ~= "WHISPER" or not KillTrackerDB then return end
    if issecret(message) or issecret(sender) then return end
    local okId = message:match("^OK:(%w+)$")
    if okId then
        if waiting[okId] then
            ns.Print(("%s got your tribute."):format(waiting[okId]))
            waiting[okId] = nil
        end
        return
    end
    local id, k, count, text = message:match("^T:(%w+):(%d+)/(%d+):(.*)$")
    k, count = tonumber(k), tonumber(count)
    if not id or not k or not count or count < 1 or count > 10 or k > count then return end
    if not ns.IsMember() or not ns.IsDevSender(sender) then return end  -- (only from the Ogre Godz themselves)
    local entry = partial[id] or { count = count, parts = {}, have = 0 }
    partial[id] = entry
    if not entry.parts[k] then entry.parts[k], entry.have = text, entry.have + 1 end
    if entry.have < entry.count then return end
    partial[id] = nil
    local db = KillTrackerDB
    db.giftsTaken = db.giftsTaken or {}
    if not db.giftsTaken[id] then
        local spec = Parse(table.concat(entry.parts))
        if not spec then return end
        db.giftsTaken[id] = time()
        ns.AddTribute(spec)
        ns.AnnounceTribute(spec)
    end
    Send("OK:" .. id, sender)  -- (again if it was a resend: they still want to hear)
end)
C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
