-- Ogre says (DM mode): an officer pops in on guildmates' screens as an ogre character and says something. The officer
-- dresses the ogre in the DM window's layer browser (Dev.lua; "Dress as" puts on a dungeon end boss's set: its gear
-- hat and outfit and a chase item of it), names it, writes a line and sends it to everyone online or one guildmate.
-- There the ogre, cut out (no background) with its name on a wooden plate under it (over the picture's cut-off
-- bottom), slides in at the left with a speech bubble, stays a while for the length
-- of the line and slides away (click: away now). Several queue up.
--
-- Wire (SAY_PREFIX, GUILD or WHISPER): "<id>\t<part>\t<parts>\t<chunk>", the chunks making
-- "<name>\n<key:id,key:id,...>\n<text>". Only an officer's counts (ns.IsGuildOfficer, by the receiver's own roster;
-- WoW says who really sent it), as the gifts (Dev.lua).

local _, ns = ...

local NAME_FONT = "Interface\\AddOns\\SOLC\\Media\\Fonts\\GermaniaOne-Regular.ttf"
local SAY_PREFIX = "SOLCSAY"
local CHUNK = 220            -- bytes of payload per message (an addon message holds 255)
local SEND_INTERVAL = 0.3    -- (WoW drops addon messages sent in a burst)
local MAX_TEXT, MAX_NAME = 240, 40
local OGRE = 230             -- the cut-out ogre's size on screen
local WOOD = "Interface\\AddOns\\SOLC\\Media\\Wood\\"
local SLIDE = 0.35           -- seconds to slide in or out
local issecret = issecretvalue or function() return false end

-- Each dungeon's end boss, the "Dress as" list's names (a dungeon not here goes by its own name).
local BOSSES = {
    rfc = "Taragaman the Hungerer", wc = "Mutanus the Devourer", dm = "Edwin VanCleef", sfk = "Archmage Arugal",
    bfd = "Aku'mai", stocks = "Bazil Thredd", gnomer = "Mekgineer Thermaplugg", rfk = "Charlga Razorflank",
    smgy = "Bloodmage Thalnos", smlib = "Arcanist Doan", smarm = "Herod", smcath = "High Inquisitor Whitemane",
    rfd = "Amnennar the Coldbringer", ulda = "Archaedas", mara = "Princess Theradras", zf = "Chief Ukorz Sandscalp",
    st = "Shade of Eranikus", brd = "Emperor Dagran Thaurissan", lbrs = "Overlord Wyrmthalak", ubrs = "General Drakkisath",
    dme = "Alzzin the Wildshaper", dmw = "Prince Tortheldrin", dmn = "King Gordok", scholo = "Darkmaster Gandling",
    stratl = "Balnazzar", stratu = "Baron Rivendare", ony = "Onyxia",
}

local function Clean(text, max)
    return (text or ""):gsub("[\t\n\r]", " "):gsub("^%s+", ""):gsub("%s+$", ""):sub(1, max)
end

-- The pop-in ---------------------------------------------------------------------------------------------------------

local pop, showing
local queue = {}
local function BuildPop()
    pop = CreateFrame("Button", "SOLCOgreSays", UIParent)
    pop:SetSize(OGRE + 320, OGRE + 14)
    pop:SetFrameStrata("HIGH")
    pop:Hide()
    pop.canvas = CreateFrame("Frame", nil, pop)
    pop.canvas:SetSize(OGRE, OGRE)
    pop.canvas:SetPoint("BOTTOMLEFT", 0, 14)
    -- (the name plate: a plank with its ends, as wide as the name, across the bottom of the picture)
    pop.plate = CreateFrame("Frame", nil, pop)
    pop.plate:SetHeight(40)
    pop.plate:SetPoint("BOTTOM", pop.canvas, "BOTTOM", 0, -14)
    pop.plate:SetFrameLevel(pop.canvas:GetFrameLevel() + 5)
    local left = pop.plate:CreateTexture(nil, "ARTWORK")
    left:SetTexture(WOOD .. "PlankLeft")
    left:SetSize(20, 40)
    left:SetPoint("LEFT")
    local right = pop.plate:CreateTexture(nil, "ARTWORK")
    right:SetTexture(WOOD .. "PlankRight")
    right:SetSize(20, 40)
    right:SetPoint("RIGHT")
    local middle = pop.plate:CreateTexture(nil, "ARTWORK")
    middle:SetTexture(WOOD .. "Plank")
    middle:SetPoint("TOPLEFT", left, "TOPRIGHT")
    middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
    pop.bubble = CreateFrame("Frame", nil, pop, "BackdropTemplate")
    -- (beside the ogre, its bottom at mouth height, over the picture's edge; a tail pointing at the ogre)
    pop.bubble:SetPoint("BOTTOMLEFT", pop.canvas, "RIGHT", 8, 10)
    pop.bubble:SetFrameLevel(pop.canvas:GetFrameLevel() + 10)
    pop.tail = pop.bubble:CreateTexture(nil, "BACKGROUND", nil, -1)
    pop.tail:SetSize(18, 18)
    pop.tail:SetPoint("CENTER", pop.bubble, "BOTTOMLEFT", 2, 12)
    pop.tail:SetColorTexture(0.98, 0.95, 0.86, 0.96)
    pop.tail:SetRotation(math.rad(45))
    pop.bubble:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    pop.bubble:SetBackdropColor(0.98, 0.95, 0.86, 0.96)
    pop.bubble:SetBackdropBorderColor(0.35, 0.24, 0.12)
    pop.name = pop.plate:CreateFontString(nil, "OVERLAY")
    pop.name:SetFont(NAME_FONT, 19, "")
    pop.name:SetTextColor(1, 0.86, 0.55)
    pop.name:SetShadowOffset(1, -1)
    pop.name:SetShadowColor(0, 0, 0, 0.9)
    pop.name:SetPoint("CENTER", 0, 1)
    pop.text = pop.bubble:CreateFontString(nil, "OVERLAY")
    pop.text:SetFont(NAME_FONT, 15, "")
    pop.text:SetTextColor(0.15, 0.1, 0.06)
    pop.text:SetPoint("TOPLEFT", 12, -12)
    pop.text:SetWidth(270)
    pop.text:SetJustifyH("LEFT")
    pop.text:SetSpacing(2)
    pop:SetScript("OnClick", function(self) if self.phase ~= "out" then self.phase, self.t = "out", 0 end end)
    pop:SetScript("OnUpdate", function(self, elapsed)
        self.t = self.t + elapsed
        local x
        if self.phase == "in" then
            local f = math.min(1, self.t / SLIDE)
            x = -OGRE + (OGRE + self.restX) * (1 - (1 - f) ^ 3)
            if f >= 1 then self.phase, self.t = "hold", 0 end
        elseif self.phase == "hold" then
            x = self.restX
            if self.t >= self.hold then self.phase, self.t = "out", 0 end
        else
            local f = math.min(1, self.t / SLIDE)
            x = self.restX - (OGRE + self.restX) * f * f
            if f >= 1 then
                self:Hide()
                showing = false
                C_Timer.After(0.4, function() if not showing and #queue > 0 then ns.ShowOgreSays(table.remove(queue, 1)) end end)
                return
            end
        end
        self:ClearAllPoints()
        self:SetPoint("LEFT", UIParent, "LEFT", x, 20)  -- (mid-left: clear of the chat and the action bars)
        self.bubble:SetAlpha(self.phase == "hold" and 1 or (self.phase == "in" and 0 or 1 - math.min(1, self.t / SLIDE * 2)))
    end)
end

-- Shows (or queues) one: { name, traits = { [layer] = id }, text }.
function ns.ShowOgreSays(say)
    if not pop then BuildPop() end
    if showing then queue[#queue + 1] = say return end
    showing = true
    local traits = {}
    for key, id in pairs(say.traits) do traits[key] = id end
    traits.background = nil  -- (the cut-out)
    ns.RenderMint(pop.canvas, traits)
    pop.name:SetText(say.name ~= "" and say.name or "Ogre")
    pop.plate:SetWidth(math.max(OGRE * 0.7, pop.name:GetUnboundedStringWidth() + 56))
    pop.text:SetText(say.text)
    pop.bubble:SetSize(math.max(150, math.min(294, pop.text:GetUnboundedStringWidth() + 24)), pop.text:GetStringHeight() + 26)
    pop.hold = math.min(20, 4 + #say.text * 0.06)
    pop.restX = math.max(30, (pop.plate:GetWidth() - OGRE) / 2 + 12)  -- (the name plate on screen too)
    pop.phase, pop.t = "in", 0
    pop:Show()
    pcall(PlaySound, SOUNDKIT and SOUNDKIT.TELL_MESSAGE or 3081)
end

-- Sending and hearing --------------------------------------------------------------------------------------------

local sendQueue, sending = {}, false
local function Pump()
    local item = table.remove(sendQueue, 1)
    if not item then sending = false return end
    pcall(C_ChatInfo.SendAddonMessage, SAY_PREFIX, item.message, item.channel, item.target)
    C_Timer.After(SEND_INTERVAL, Pump)
end

local function TraitsText(traits)
    local list = {}
    for key, id in pairs(traits) do
        if key ~= "background" and id then list[#list + 1] = key .. ":" .. id end
    end
    return table.concat(list, ",")
end

-- Sends one to everyone online in the guild (target nil) or one guildmate (their full name).
function ns.SendOgreSays(name, traits, text, target)
    if not ns.CanEditConfig() or not IsInGuild() then return ns.Print("Only officers can pop in as an ogre.") end
    name, text = Clean(name, MAX_NAME), Clean(text, MAX_TEXT)
    if text == "" then return ns.Print("Write something for the ogre to say first.") end
    local payload = name .. "\n" .. TraitsText(traits) .. "\n" .. text
    local id = ("%x"):format(math.random(0, 0xffffff))
    local parts = math.ceil(#payload / CHUNK)
    for i = 1, parts do
        sendQueue[#sendQueue + 1] = { message = ("%s\t%d\t%d\t%s"):format(id, i, parts, payload:sub((i - 1) * CHUNK + 1, i * CHUNK)),
            channel = target and "WHISPER" or "GUILD", target = target }
    end
    if not sending then sending = true Pump() end
    -- (a whisper doesn't come back to you: see it here too; the guild's does)
    if target then ns.ShowOgreSays({ name = name, traits = traits, text = text }) end
end

local incoming = {}  -- [sender .. id] = { parts = {}, got, total }
local listener = CreateFrame("Frame")
listener:RegisterEvent("CHAT_MSG_ADDON")
listener:SetScript("OnEvent", function(_, _, prefix, message, channel, sender)
    if prefix ~= SAY_PREFIX or (channel ~= "GUILD" and channel ~= "WHISPER") then return end
    if issecret(message) or issecret(sender) then return end
    local id, part, total, chunk = message:match("^(%x+)\t(%d+)\t(%d+)\t(.*)$")
    part, total = tonumber(part), tonumber(total)
    if not id or not part or not total or total > 8 or part > total then return end
    if not ns.IsGuildOfficer(sender) then return end
    local key = sender .. id
    local entry = incoming[key] or { parts = {}, got = 0 }
    incoming[key] = entry
    if not entry.parts[part] then entry.parts[part], entry.got = chunk, entry.got + 1 end
    if entry.got < total then return end
    incoming[key] = nil
    local name, traitText, text = table.concat(entry.parts):match("^(.-)\n(.-)\n(.*)$")
    if not text then return end
    local traits = {}
    for layer, option in traitText:gmatch("([%w_]+):([%w_]+)") do traits[layer] = option end
    ns.ShowOgreSays({ name = Clean(name, MAX_NAME), traits = traits, text = Clean(text, MAX_TEXT) })
end)
C_ChatInfo.RegisterAddonMessagePrefix(SAY_PREFIX)

-- The officer's panel (beside the DM window) -----------------------------------------------------------------------

-- Each dungeon's end-boss set as a template: { name, key, set = { [layer] = id } } (its gear hat and outfit, a chase
-- item of it held), for the dungeons that have one.
local function Templates()
    local list = {}
    for _, d in ipairs(ns.Dungeons()) do
        local set = {}
        for _, layer in ipairs(ns.MintLayers) do
            for _, option in ipairs(layer.options) do
                local id = option.id
                if id == "gear_" .. d.key .. "_head" or id == "gear_" .. d.key .. "_body" then set[layer.key] = id end
                if layer.key == "accessory" and not set.accessory and id:find("^chase_" .. d.key .. "_") then set.accessory = id end
            end
        end
        if next(set) then list[#list + 1] = { name = BOSSES[d.key] or d.name, key = d.key, set = set } end
    end
    return list
end

local function EditBox(parent, width, height, multi)
    local box = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    box:SetSize(width, height)
    box:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    box:SetBackdropColor(0, 0, 0, 0.6)
    box:SetFont(NAME_FONT, 14, "")
    box:SetTextColor(0.95, 0.9, 0.8)
    box:SetTextInsets(8, 8, 6, 6)
    box:SetAutoFocus(false)
    box:SetMultiLine(multi or false)
    box:SetScript("OnEscapePressed", box.ClearFocus)
    if not multi then box:SetScript("OnEnterPressed", box.ClearFocus) end
    box:EnableMouse(true)
    box:SetScript("OnMouseDown", box.SetFocus)
    return box
end

local function Label(parent, text, y)
    local label = parent:CreateFontString(nil, "OVERLAY")
    label:SetFont(NAME_FONT, 13, "")
    label:SetTextColor(0.62, 0.56, 0.48)
    label:SetPoint("TOPLEFT", 14, y)
    label:SetText(text)
    return label
end

-- window: the DM window; browser: its layer browser (traits, index, Refresh). The panel, or nil.
function ns.BuildDMSay(window, browser)
    local panel = CreateFrame("Frame", nil, window, "BackdropTemplate")
    panel:SetSize(300, 330)
    panel:SetPoint("TOPLEFT", window, "TOPRIGHT", 4, 0)
    panel:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 32, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    panel:SetBackdropColor(unpack(ns.WINDOW_COLOR))
    panel:EnableMouse(true)
    local title = panel:CreateFontString(nil, "OVERLAY")
    title:SetFont(NAME_FONT, 18, "")
    title:SetTextColor(1, 0.5, 0.25)
    title:SetPoint("TOPLEFT", 14, -12)
    title:SetText("OGRE SAYS - pop in as the ogre")

    -- (dress the browser's ogre as a boss; the name goes with it)
    local dress = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    dress:SetSize(272, 22)
    dress:SetPoint("TOPLEFT", 14, -40)
    dress:SetText("Dress as a boss...")
    Label(panel, "Name", -70)
    local name = EditBox(panel, 272, 28)
    name:SetPoint("TOPLEFT", 14, -86)
    name:SetMaxLetters(MAX_NAME)
    dress:SetScript("OnClick", function(self)
        if not MenuUtil then return end
        MenuUtil.CreateContextMenu(self, function(_, root)
            root:CreateTitle("End bosses")
            if root.SetScrollMode then root:SetScrollMode(400) end
            for _, template in ipairs(Templates()) do
                root:CreateButton(template.name, function()
                    for _, layer in ipairs(ns.MintLayers) do
                        local id = template.set[layer.key]
                        if id then
                            for i, option in ipairs(layer.options) do
                                if option.id == id then browser.index[layer.key] = i end
                            end
                        end
                    end
                    browser:Refresh()
                    name:SetText(template.name)
                end)
            end
        end)
    end)

    Label(panel, "Says", -120)
    local text = EditBox(panel, 272, 110, true)
    text:SetPoint("TOPLEFT", 14, -136)
    text:SetMaxLetters(MAX_TEXT)

    -- (to: everyone online, or one of your synced guildmates)
    panel.target = nil
    local who = panel:CreateFontString(nil, "OVERLAY")
    who:SetFont(NAME_FONT, 13, "")
    who:SetTextColor(0.93, 0.88, 0.78)
    who:SetPoint("TOPLEFT", 70, -258)
    local function Step(delta)
        local list = { false }
        for _, friend in ipairs(ns.GetFriends()) do list[#list + 1] = friend.key end
        local at = 1
        for i, key in ipairs(list) do if key == (panel.target or false) then at = i end end
        panel.target = list[(at - 1 + delta) % #list + 1] or nil
        panel:Refresh()
    end
    for i, dir in ipairs({ -1, 1 }) do
        local arrow = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        arrow:SetSize(24, 20)
        arrow:SetText(dir < 0 and "<" or ">")
        arrow:SetPoint("TOPLEFT", 14 + (i - 1) * 26, -254)
        arrow:SetScript("OnClick", function() Step(dir) end)
    end

    local preview = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    preview:SetSize(90, 24)
    preview:SetPoint("BOTTOMLEFT", 14, 14)
    preview:SetText("Preview")
    preview:SetScript("OnClick", function()
        local line = Clean(text:GetText(), MAX_TEXT)
        ns.ShowOgreSays({ name = Clean(name:GetText(), MAX_NAME), traits = browser.traits, text = line ~= "" and line or "..." })
    end)
    local send = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    send:SetSize(90, 24)
    send:SetPoint("BOTTOMRIGHT", -14, 14)
    send:SetText("Send")
    send:SetScript("OnClick", function()
        text:ClearFocus()
        ns.SendOgreSays(name:GetText(), browser.traits, text:GetText(), panel.target)
    end)

    function panel:Refresh()
        who:SetText("To: |cffffd100" .. (self.target and Ambiguate(self.target, "short") or "everyone online") .. "|r")
    end
    panel:Refresh()
    return panel
end
