-- Dev and DM mode (/solc dev): a window for trying out the chests and the picture art, and for officers, giving chests.
-- Left, the chests: every dungeon (its backdrop's rarity colour; unlocked or not; your chests of it), each with Show
-- (the chest show with everything it can hold, nothing unlocked: Chests.lua's preview) and, for officers, +1: a real
-- chest of it for whoever "Give to" says (you, or a synced guildmate: a gift). Officers also get a chest of every
-- dungeon for them, and for themselves: unlock everything, relock everything (unlocks, chests and tokens cleared, to try
-- it all from scratch), 5 of every ingredient (the minting pot, MintPot.lua).
-- Right, the layer browser: a picture drawn from one option per layer, each stepped through with arrows over every
-- option there is, locked or not, with its rarity and what unlocks it; Random (everything) and Random unlockables.
--
-- Gifts: an officer's chest for a guildmate goes to them as an addon whisper (GIFT_PREFIX: "C:<dungeon>:<id>"). WoW
-- tells the receiver who really sent it and the guild roster says their rank, so a gift only counts from an officer
-- (ns.IsGuildOfficer: the guild master and the first officer rank) - nobody else can make someone's SOLC take one.
-- The receiver gets the chest (a toast, the feed: event G, a = giver, b = what), answers "OK:<id>" so the giver hears
-- it arrived, and remembers the gift ids it took (KillTrackerDB.giftsTaken) so a resend can't count twice.
-- (Anyone can still edit their own SOLC or saved data to cheat themselves; this only keeps them from faking gifts.)

local _, ns = ...

local NAME_FONT = "Interface\\AddOns\\SOLC\\Media\\Fonts\\GermaniaOne-Regular.ttf"
local ROWS, ROW_HEIGHT = 16, 24
local PICTURE = 250
local GIFT_PREFIX = "SOLCGIFT"
local GIFT_TIMEOUT = 10  -- seconds to hear back before saying it didn't arrive
local issecret = issecretvalue or function() return false end

local window
local function IsOfficer() return ns.CanEditConfig() end  -- (you: the guild master or an officer, or no guild)

local function DungeonName(key)
    local d = ns.DungeonByKey(key)
    return d and d.name or key
end
local function GiveChest(key, tier) return ns.AddChest(key, tier) end
local function Refresh()
    if window and window:IsShown() then window:Refresh() end
    if ns.OnKillsChanged then ns.OnKillsChanged() end
end

-- Gifts -----------------------------------------------------------------------------------------------------------

local waiting = {}  -- [gift id] = { to, what } until they answer
-- Whispers go out one every SEND_INTERVAL (WoW drops addon messages sent in a burst); sent(): when it went.
local SEND_INTERVAL = 0.3
local queue, sending = {}, false
local function Pump()
    local item = table.remove(queue, 1)
    if not item then sending = false return end
    pcall(C_ChatInfo.SendAddonMessage, GIFT_PREFIX, item.message, "WHISPER", item.target)
    if item.sent then item.sent() end
    C_Timer.After(SEND_INTERVAL, Pump)
end
local function Send(message, target, sent)
    queue[#queue + 1] = { message = message, target = target, sent = sent }
    if not sending then sending = true Pump() end
end

-- Sends a chest of a dungeon to a guildmate (their full name, as KillTrackerFriends has them).
function ns.GiftChest(dungeonKey, target)
    if not IsOfficer() then return ns.Print("Only officers can give chests.") end
    local id = ("%x%04x"):format(time(), math.random(0, 0xffff))
    waiting[id] = { to = target, what = DungeonName(dungeonKey) .. " chest" }
    local short = Ambiguate(target, "short")
    Send(("C:%s:%s"):format(dungeonKey, id), target, function()
        C_Timer.After(GIFT_TIMEOUT, function()
            if waiting[id] then
                waiting[id] = nil
                ns.Print(("No answer from %s about the %s chest - offline, or not on SOLC 0.41.0 yet? Nothing was given."):format(short, DungeonName(dungeonKey)))
            end
        end)
    end)
end

local listener = CreateFrame("Frame")
listener:RegisterEvent("CHAT_MSG_ADDON")
listener:SetScript("OnEvent", function(_, _, prefix, message, channel, sender)
    if prefix ~= GIFT_PREFIX or channel ~= "WHISPER" or not KillTrackerDB then return end
    if issecret(message) or issecret(sender) then return end
    local short = Ambiguate(sender, "short")
    local okId = message:match("^OK:(%w+)$")
    if okId then  -- they got one of ours
        local gift = waiting[okId]
        if gift then
            waiting[okId] = nil
            ns.Print(("%s got it: %s."):format(short, gift.what))
        end
        return
    end
    local dungeonKey, id = message:match("^C:(%w+):(%w+)$")
    if not dungeonKey or not ns.DungeonByKey(dungeonKey) then return end
    if not ns.IsGuildOfficer(sender) then return end  -- only an officer's gift counts
    local db = KillTrackerDB
    db.giftsTaken = db.giftsTaken or {}
    if not db.giftsTaken[id] then
        db.giftsTaken[id] = time()
        GiveChest(dungeonKey)
        local what = DungeonName(dungeonKey) .. " chest"
        ns.ShowToast("achievement", "A gift from " .. short .. "!", what, "Open it on your PIX page, whenever you like")
        ns.Print(("%s gave you a |cffffd100%s|r - open it on your PIX page."):format(short, what))
        if ns.AddEvent then ns.AddEvent("G", short, "chest:" .. dungeonKey) end
        Refresh()
    end
    Send("OK:" .. id, sender)  -- (again if it was a resend: they still want to hear)
end)
C_ChatInfo.RegisterAddonMessagePrefix(GIFT_PREFIX)

-- The chests ------------------------------------------------------------------------------------------------------

local function BuildChests(parent)
    local left = CreateFrame("Frame", nil, parent)
    left:SetPoint("TOPLEFT", 12, -40)
    left:SetSize(400, 60 + ROWS * ROW_HEIGHT)
    left.officer = {}  -- what only officers see

    -- Who +1 gives to: you or one of your synced guildmates.
    left.target = nil  -- nil: you
    local who = left:CreateFontString(nil, "OVERLAY")
    who:SetFont(NAME_FONT, 13, "")
    who:SetTextColor(0.93, 0.88, 0.78)
    who:SetPoint("TOPLEFT", 56, -4)
    local function Step(delta)
        local list = { false }
        for _, friend in ipairs(ns.GetFriends()) do list[#list + 1] = friend.key end
        local at = 1
        for i, key in ipairs(list) do if key == (left.target or false) then at = i end end
        local key = list[(at - 1 + delta) % #list + 1]
        left.target = key or nil
        left:Refresh()
    end
    local prev = CreateFrame("Button", nil, left, "UIPanelButtonTemplate")
    prev:SetSize(24, 20) prev:SetText("<") prev:SetPoint("TOPLEFT", 0, 0)
    prev:SetScript("OnClick", function() Step(-1) end)
    local next = CreateFrame("Button", nil, left, "UIPanelButtonTemplate")
    next:SetSize(24, 20) next:SetText(">") next:SetPoint("TOPLEFT", 26, 0)
    next:SetScript("OnClick", function() Step(1) end)
    left.officer[#left.officer + 1] = prev
    left.officer[#left.officer + 1] = next
    left.who = who

    local function GiveTo(key)
        if left.target then ns.GiftChest(key, left.target) else GiveChest(key) end
    end
    local x = 0
    for _, spec in ipairs({
        { "Chest of each", 100, function()
            for _, d in ipairs(ns.Dungeons()) do GiveTo(d.key) end
            if not left.target then ns.Print("Dev: a chest of every dungeon.") end
            Refresh() end },
        { "Unlock all", 92, function()
            for _, layer in ipairs(ns.MintLayers) do
                for _, option in ipairs(layer.options) do
                    if option.unlock then ns.UnlockOption(ns.OptionKey(layer.key, option), true) end
                end
            end
            ns.Print("Dev: everything unlocked.") Refresh() end },
        { "Relock all", 92, function()
            KillTrackerDB.unlocks, KillTrackerDB.chests, KillTrackerDB.tokens = {}, {}, {}
            ns.Print("Dev: every unlock, chest and token of yours cleared.") Refresh() end },
        { "+5 of all", 92, function()
            KillTrackerDB.tokens = KillTrackerDB.tokens or {}
            for _, d in ipairs(ns.Dungeons()) do KillTrackerDB.tokens[d.key] = (KillTrackerDB.tokens[d.key] or 0) + 5 end
            for _, spec in ipairs(ns.LAYER_INGREDIENTS) do ns.AddIngredient(spec.key, 5, true) end
            for _, fuel in ipairs(ns.FUELS) do ns.AddIngredient(fuel.key, 5, true) end
            ns.Print("Dev: 5 of every ingredient for you.") Refresh() end },
    }) do
        local button = CreateFrame("Button", nil, left, "UIPanelButtonTemplate")
        button:SetSize(spec[2], 22)
        button:SetText(spec[1])
        button:SetScript("OnClick", spec[3])
        button:SetPoint("TOPLEFT", x, -26)
        x = x + spec[2] + 6
        left.officer[#left.officer + 1] = button
    end
    -- Show plays a chest of this tier (its effects: ns.CHEST_TIERS), for everyone.
    left.previewTier = 1
    local tierButton = CreateFrame("Button", nil, left, "UIPanelButtonTemplate")
    tierButton:SetSize(150, 20)
    tierButton:SetPoint("TOPRIGHT", 0, 0)
    tierButton:SetScript("OnClick", function()
        left.previewTier = left.previewTier % #ns.CHEST_TIERS + 1
        left:Refresh()
    end)
    left.tierButton = tierButton
    left.note = left:CreateFontString(nil, "OVERLAY")
    left.note:SetFont(NAME_FONT, 12, "")
    left.note:SetTextColor(0.62, 0.56, 0.48)
    left.note:SetPoint("TOPLEFT", 0, -4)
    left.note:SetText("Previews only - giving chests is for officers.")

    left.rows, left.offset = {}, 0
    for i = 1, ROWS do
        local row = CreateFrame("Frame", nil, left)
        row:SetSize(400, ROW_HEIGHT)
        row:SetPoint("TOPLEFT", 0, -56 - (i - 1) * ROW_HEIGHT)
        row.stripe = row:CreateTexture(nil, "BACKGROUND")
        row.stripe:SetAllPoints()
        row.stripe:SetColorTexture(1, 1, 1, i % 2 == 0 and 0.05 or 0)
        row.name = row:CreateFontString(nil, "OVERLAY")
        row.name:SetFont(NAME_FONT, 13, "")
        row.name:SetPoint("LEFT", 4, 0)
        row.name:SetWidth(200)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)
        row.status = row:CreateFontString(nil, "OVERLAY")
        row.status:SetFont(NAME_FONT, 12, "")
        row.status:SetTextColor(0.62, 0.56, 0.48)
        row.status:SetPoint("LEFT", 208, 0)
        row.status:SetWidth(80)
        row.status:SetJustifyH("LEFT")
        row.give = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        row.give:SetSize(36, 20) row.give:SetText("+1") row.give:SetPoint("RIGHT", -52, 0)
        row.give:SetScript("OnClick", function(self) GiveTo(self:GetParent().key) Refresh() end)
        row.show = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        row.show:SetSize(48, 20) row.show:SetText("Show") row.show:SetPoint("RIGHT", 0, 0)
        row.show:SetScript("OnClick", function(self) ns.ShowChest(self:GetParent().key, true, left.previewTier) end)
        left.rows[i] = row
    end
    left:EnableMouseWheel(true)
    left:SetScript("OnMouseWheel", function(self, delta)
        self.offset = math.max(0, math.min(#ns.Dungeons() - ROWS, self.offset - delta * 3))
        self:Refresh()
    end)
    function left:Refresh()
        local officer = IsOfficer()
        for _, region in ipairs(self.officer) do region:SetShown(officer) end
        self.who:SetShown(officer)
        self.note:SetShown(not officer)
        local tier = ns.CHEST_TIERS[self.previewTier]
        self.tierButton:SetText("Show as: " .. tier.name)
        self.who:SetText("Give to: |cffffd100" .. (self.target and Ambiguate(self.target, "short") or "me") .. "|r")
        local dungeons, counts = ns.Dungeons(), ns.ChestCounts()
        for i, row in ipairs(self.rows) do
            local d = dungeons[self.offset + i]
            row:SetShown(d ~= nil)
            if d then
                row.key = d.key
                local backdrop = ns.UnlockOptions("clear:" .. d.key)[1]
                local colour = backdrop and ns.RARITY_COLORS[backdrop.option.rarity] or "ffffffff"
                row.name:SetText(("|c%s%s|r"):format(colour, d.name))
                local have, all = ns.PoolProgress("clear:" .. d.key)
                row.status:SetText((have == all and all > 0 and ("|cff55dd55%d/%d|r"):format(have, all) or ("%d/%d"):format(have, all)) .. ((counts[d.key] or 0) > 0 and ("  |cffffd100x%d|r"):format(counts[d.key]) or ""))
                row.give:SetShown(officer)
            end
        end
    end
    return left
end

-- The layer browser -----------------------------------------------------------------------------------------------

local function BuildBrowser(parent)
    local right = CreateFrame("Frame", nil, parent)
    right:SetPoint("TOPLEFT", 430, -40)
    right:SetSize(330, 470)
    right.traits, right.index = {}, {}
    local frame = right:CreateTexture(nil, "BACKGROUND")
    frame:SetPoint("TOP", 0, 0)
    frame:SetSize(PICTURE + 6, PICTURE + 6)
    frame:SetColorTexture(0.3, 0.22, 0.12)
    right.canvas = CreateFrame("Frame", nil, right)
    right.canvas:SetSize(PICTURE, PICTURE)
    right.canvas:SetPoint("TOP", 0, -3)
    right.rows = {}
    for i, layer in ipairs(ns.MintLayers) do
        local row = CreateFrame("Frame", nil, right)
        row:SetSize(330, 26)
        row:SetPoint("TOPLEFT", 0, -PICTURE - 12 - (i - 1) * 26)
        local function Step(delta)
            local n = #layer.options
            right.index[layer.key] = ((right.index[layer.key] or 1) - 1 + delta) % n + 1
            right:Refresh()
        end
        row.prev = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        row.prev:SetSize(24, 20) row.prev:SetText("<") row.prev:SetPoint("LEFT", 0, 0)
        row.prev:SetScript("OnClick", function() Step(-1) end)
        row.next = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        row.next:SetSize(24, 20) row.next:SetText(">") row.next:SetPoint("LEFT", 26, 0)
        row.next:SetScript("OnClick", function() Step(1) end)
        row.text = row:CreateFontString(nil, "OVERLAY")
        row.text:SetFont(NAME_FONT, 12, "")
        row.text:SetTextColor(0.93, 0.88, 0.78)
        row.text:SetPoint("LEFT", 56, 0)
        row.text:SetWidth(272)
        row.text:SetJustifyH("LEFT")
        row.text:SetWordWrap(false)
        row.layer = layer
        right.rows[i] = row
    end
    local function Randomize(onlyUnlockables)
        for _, layer in ipairs(ns.MintLayers) do
            local choices = {}
            for i, option in ipairs(layer.options) do
                if not onlyUnlockables or option.unlock then choices[#choices + 1] = i end
            end
            if #choices > 0 then right.index[layer.key] = choices[math.random(#choices)] end
        end
        right:Refresh()
    end
    local random = CreateFrame("Button", nil, right, "UIPanelButtonTemplate")
    random:SetSize(100, 22) random:SetText("Random")
    random:SetPoint("TOPLEFT", 0, -PICTURE - 12 - #ns.MintLayers * 26 - 6)
    random:SetScript("OnClick", function() Randomize(false) end)
    local unlockables = CreateFrame("Button", nil, right, "UIPanelButtonTemplate")
    unlockables:SetSize(150, 22) unlockables:SetText("Random unlockables")
    unlockables:SetPoint("LEFT", random, "RIGHT", 6, 0)
    unlockables:SetScript("OnClick", function() Randomize(true) end)
    function right:Refresh()
        for _, row in ipairs(self.rows) do
            local layer = row.layer
            local i = self.index[layer.key] or 1
            local option = layer.options[i]
            self.traits[layer.key] = option and option.id
            if option then
                local unlock = option.unlock and ((ns.IsUnlocked(ns.OptionKey(layer.key, option)) and "|cff55dd55" or "|cffff8040") .. option.unlock .. "|r") or "|cff888888base|r"
                row.text:SetText(("%s: |c%s%s|r  %d/%d  %s"):format(layer.name, ns.RARITY_COLORS[option.rarity] or "ffffffff",
                    option.name, i, #layer.options, unlock))
            end
        end
        ns.RenderMint(self.canvas, self.traits)
    end
    return right
end

-- The window ------------------------------------------------------------------------------------------------------

local function Build()
    window = CreateFrame("Frame", "SOLCDev", UIParent, "BackdropTemplate")
    window:SetSize(780, 580)
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:SetBackdrop({ bgFile = ns.WINDOW_BACKGROUND, edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 32, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    window:SetBackdropColor(unpack(ns.WINDOW_COLOR))
    window:EnableMouse(true)
    window:SetMovable(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    window:SetClampedToScreen(true)
    local title = window:CreateFontString(nil, "OVERLAY")
    title:SetFont(NAME_FONT, 18, "")
    title:SetTextColor(1, 0.5, 0.25)
    title:SetPoint("TOPLEFT", 14, -12)
    local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)
    close:SetScript("OnClick", function() window:Hide() end)
    local chests = BuildChests(window)
    local browser = BuildBrowser(window)
    function window:Refresh()
        title:SetText(IsOfficer() and "SOLC DM MODE - chests and picture art (drag to move)" or "SOLC DEV - previews and picture art (drag to move)")
        chests:Refresh()
        browser:Refresh()
    end
    window:SetScript("OnShow", function(self) self:Refresh() end)
    window:Hide()
end

function ns.ToggleDev()
    if not window then Build() end
    window:SetShown(not window:IsShown())
end
