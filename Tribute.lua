-- Ogre Godz tribute: a chest made by hand in the dev menu (Dev.lua) with whatever's put in it (pieces, ingredients,
-- points, plinko drops: Unlocks.lua's ns.AddTribute), for you or a guildmate. A guildmate's goes as addon whispers
-- (PREFIX), in parts (an addon message holds 255 characters): "T:<id>:<part>/<parts>:<text>", the text
-- "t=<tier>;p=<points>;d=<plinko drops>;u=<option key>;i=<ingredient>*<n>;...;n=<note>". Their SOLC only takes it
-- from a dev character (ns.IsDevSender: the sender's character id in their own guild roster, Config.lua), only once
-- (KillTrackerDB.giftsTaken, by id), and answers "OK:<id>". Taking one pops up the Ogre Godz' words over the screen
-- (OPEN IT plays the chest show, Chests.lua; it waits on the PIX page until then).

local _, ns = ...

local PREFIX = "SOLCTRIB"
local PART_SIZE = 200
local SEND_INTERVAL = 0.3  -- (WoW drops addon messages sent in a burst)
local TIMEOUT = 15
local MAX_POINTS, MAX_DROPS, MAX_COUNT = 100000, 10, 99
local NAME_FONT = "Interface\\AddOns\\SOLC\\Media\\Fonts\\GermaniaOne-Regular.ttf"
local FX = "Interface\\AddOns\\SOLC\\Media\\Icons\\Fx_"
local GOLD = { 1, 0.85, 0.4 }
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

-- The pop-up ----------------------------------------------------------------------------------------------------------

local pop
local function Hue(h)  -- (as Chests.lua's: a crayon rainbow)
    local i, f = math.floor(h * 6) % 6, h * 6 - math.floor(h * 6)
    local rgb = ({ { 1, f, 0 }, { 1 - f, 1, 0 }, { 0, 1, f }, { 0, 1 - f, 1 }, { f, 0, 1 }, { 1, 0, 1 - f } })[i + 1]
    return rgb[1] * 0.6 + 0.4, rgb[2] * 0.6 + 0.4, rgb[3] * 0.6 + 0.4
end
local function Text(parent, size, r, g, b)
    local text = parent:CreateFontString(nil, "OVERLAY")
    text:SetFont(NAME_FONT, size, "")
    text:SetTextColor(r, g, b)
    ns.UI.OutlineText(text, { 0, 0, 0 })
    return text
end
local function Plank(parent, width, label, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, 34)
    button.word = Text(button, 17, 1, 0.93, 0.78)
    button.word:SetPoint("CENTER", 0, 1)
    button.word:SetText(label)
    ns.UI.SkinButton(button, { steady = true })
    button:SetScript("OnClick", function() ns.UI.ClickSound() onClick() end)
    return button
end

local function BuildPop()
    pop = CreateFrame("Frame", "SOLCTributePop", UIParent)
    pop:SetSize(600, 360)
    pop:SetPoint("CENTER", 0, 90)
    pop:SetFrameStrata("FULLSCREEN_DIALOG")
    pop:EnableMouse(true)
    pop:Hide()
    pop.rays = pop:CreateTexture(nil, "BACKGROUND", nil, 1)
    pop.rays:SetTexture(FX .. "Rays")
    pop.rays:SetBlendMode("ADD")
    pop.rays:SetVertexColor(unpack(GOLD))
    pop.rays:SetSize(620, 620)
    pop.rays:SetPoint("CENTER", 0, 40)
    pop.glow = pop:CreateTexture(nil, "BACKGROUND", nil, 2)
    pop.glow:SetTexture(FX .. "Glow")
    pop.glow:SetBlendMode("ADD")
    pop.glow:SetVertexColor(unpack(GOLD))
    pop.glow:SetSize(520, 380)
    pop.glow:SetPoint("CENTER", 0, 20)
    pop.chest = pop:CreateTexture(nil, "ARTWORK")
    pop.chest:SetTexture("Interface\\AddOns\\SOLC\\Media\\Icons\\Chest")
    pop.chest:SetSize(150, 150)
    pop.chest:SetPoint("CENTER", 0, 40)
    pop.ogre = pop:CreateTexture(nil, "ARTWORK", nil, 1)
    pop.ogre:SetTexture(FX .. "Ogre")
    pop.ogre:SetSize(150, 150)
    pop.ogre:SetPoint("CENTER", -210, 30)
    pop.big = Text(pop, 48, 1, 0.85, 0.3)
    pop.big:SetPoint("TOP", 0, 0)
    pop.small = Text(pop, 26, 1, 0.95, 0.75)
    pop.small:SetPoint("TOP", pop.big, "BOTTOM", 0, -2)
    pop.note = Text(pop, 17, 0.9, 0.85, 0.72)
    pop.note:SetPoint("TOP", pop.chest, "BOTTOM", 0, -6)
    pop.note:SetWidth(520)
    pop.open = Plank(pop, 180, "OPEN IT", function()
        pop:Hide()
        ns.ShowChest(ns.TRIBUTE)
    end)
    pop.open:SetPoint("BOTTOM", -100, 8)
    pop.later = Plank(pop, 150, "LATER", function()
        pop:Hide()
        ns.Print("Your tribute waits on your PIX page.")
    end)
    pop.later:SetPoint("BOTTOM", 100, 8)
    pop:SetScript("OnUpdate", function(self, dt)
        self.time = (self.time or 0) + dt
        local t = self.time
        self.rays:SetRotation(t * 0.4)
        self.big:SetTextColor(Hue(t * 0.5))
        self.glow:SetAlpha(0.45 + math.sin(t * 3) * 0.12)
        self.chest:SetRotation(math.sin(t * 9) * 0.04 * math.max(0, 1 - t / 2.5))
        local p = math.min(1, t / 0.45)  -- the entrance: it pops in with an overshoot
        local s = 1 + 2.7 * (p - 1) ^ 3 + 1.7 * (p - 1) ^ 2
        self:SetScale(math.max(0.05, s))
        self.ogre:SetPoint("CENTER", -210, 30 + math.abs(math.sin(t * 4)) * 14)
    end)
end

-- Pops up the Ogre Godz' words for a tribute that's just come.
function ns.AnnounceTribute(spec)
    if not pop then BuildPop() end
    local ogreMode = KillTrackerDB and KillTrackerDB.ogreMode
    pop.big:SetText(ogreMode and "OGRE GODZ GIVE" or "THE OGRE GODZ")
    pop.small:SetText(ogreMode and "YOU LOOT!" or "HAVE GRACED YOU WITH TRIBUTE")
    pop.open.word:SetText(ogreMode and "OPEN!" or "OPEN IT")
    pop.note:SetText(spec and spec.note and spec.note ~= "" and ('"%s"'):format(spec.note) or "")
    pop.time = 0
    pop:Show()
    if SOUNDKIT and SOUNDKIT.UI_LEGENDARY_LOOT_TOAST then pcall(PlaySound, SOUNDKIT.UI_LEGENDARY_LOOT_TOAST) end
    ns.Print("|cffffd100The Ogre Godz have graced you with tribute!|r Open it on your PIX page.")
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
