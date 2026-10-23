-- The dev menu (/solc supersafesolcdev, and only on the dev characters: Config.lua's ns.IsDev): giving out almost
-- anything, to yourself or (as an Ogre Godz tribute) a guildmate. Three tabs:
-- CHESTS & ART. Left, the chests: every dungeon (its backdrop's rarity colour; unlocked or not; your chests of it), each
-- with Show (the chest show with everything it can hold, nothing unlocked: Chests.lua's preview) and +1: a real chest of
-- it for you or whoever "Give to" says (a synced guildmate: a gift). Also a chest of every dungeon, and for yourself:
-- unlock everything, relock everything (unlocks, chests and tokens cleared, to try it all from scratch), 5 of every
-- ingredient. Right, the layer browser: a picture drawn from one option per layer, each stepped through with arrows over
-- every option there is, locked or not, with its rarity and what unlocks it; Random (everything) and Random unlockables.
-- TRIBUTE: a chest made by hand (pieces, ingredients, points, plinko drops, a note, how fancy it looks), previewed, and
-- sent to a guildmate or yourself; it comes down from the Ogre Godz (Tribute.lua, Unlocks.lua, Chests.lua).
-- DEEDS & ME, for yourself: kills of any creature kind or tribe, dungeon clears, leaders, Random deeds (the
-- achievements and their pieces follow by themselves); points, an Ogre Rank, plinko drops, Dream Bed items.
-- (Officers who aren't dev characters can't open it; DM mode, Ogre Says, stays for officers: DMSay.lua.)
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
-- (you: a dev character, the guild master or an officer, or no guild)
local function IsOfficer() return ns.IsDev() or ns.CanEditConfig() end

local function DungeonName(key)
    local d = ns.DungeonByKey(key)
    return d and d.name or key
end
local function GiveChest(key, tier) return ns.AddChest(key, tier) end
local function Refresh()
    if window and window:IsShown() then window:Refresh() end
    if ns.OnKillsChanged then ns.OnKillsChanged() end
end

-- Random deeds (testing): kills of 8 random kinds of creature (enough for a few tiers each), 4 random dungeons
-- cleared 1-12 times (every boss, and a chest each) and 3 tribe leaders slain, counted as if they'd happened. The
-- achievements and the pieces they unlock follow by themselves, quietly.
local DEED_COUNTS = { 12, 30, 60, 120, 300, 600 }
local function AddKills(npcID, count, name)
    local db = KillTrackerDB
    local entry = db.kills[npcID] or { count = 0 }
    db.kills[npcID] = entry
    entry.count = entry.count + count
    entry.name = entry.name or name
    db.total = db.total + count
    ns.Touch(entry)
end
local function Pick(list) return table.remove(list, math.random(#list)) end

-- The normal mobs (Data.lua) of each creature kind and each tribe: { [name] = { npcID, ... } }, and the names sorted.
local mobsBy
local function MobsBy()
    if mobsBy then return mobsBy end
    mobsBy = { subtype = {}, faction = {}, subtypes = {}, factions = {} }
    for npcID, info in pairs(ns.NPCs) do
        if info[3] == 0 then
            local subtype, faction = ns.Subtypes[info[4]], ns.Factions[info[1]]
            if subtype then
                if not mobsBy.subtype[subtype] then mobsBy.subtype[subtype] = {} table.insert(mobsBy.subtypes, subtype) end
                table.insert(mobsBy.subtype[subtype], npcID)
            end
            if faction and not faction:match("^PLAYER") then
                if not mobsBy.faction[faction] then mobsBy.faction[faction] = {} table.insert(mobsBy.factions, faction) end
                table.insert(mobsBy.faction[faction], npcID)
            end
        end
    end
    for _, list in pairs(mobsBy.subtype) do table.sort(list) end
    for _, list in pairs(mobsBy.faction) do table.sort(list) end
    table.sort(mobsBy.subtypes)
    table.sort(mobsBy.factions)
    return mobsBy
end
-- Kills of a creature kind ("subtype") or tribe ("faction"): all on its first mob, named after the kind.
local function KillsOf(dimension, name, count)
    local mobs = MobsBy()[dimension][name]
    if mobs then AddKills(mobs[1], count, name .. " (dev)") end
end

local bossNames
local function BossName(npcID)
    if not bossNames then
        bossNames = {}
        for _, bosses in pairs(ns.EncounterNPCs or {}) do
            for _, boss in ipairs(bosses) do bossNames[boss[1]] = boss[2] end
        end
    end
    return bossNames[npcID] or "Boss"
end
-- A dungeon cleared this many times: every boss killed that often, and chests (default: one a clear, up to 10).
local function ClearDungeon(d, times, chests)
    local done = {}
    for _, npcID in ipairs(d.bossNPCs) do AddKills(npcID, times, BossName(npcID)) done[npcID] = true end
    for npcID in pairs(d.lastNPCs) do
        if not done[npcID] then AddKills(npcID, times, BossName(npcID)) end
    end
    for _ = 1, chests or math.min(times, 10) do ns.AddChest(d.key) end
end
local function SlayLeaders(n)
    local tribes, names = {}, {}
    for tribe in pairs(ns.Leaders) do tribes[#tribes + 1] = tribe end
    for _ = 1, math.min(n, #tribes) do
        local leader = ns.Leaders[Pick(tribes)][1]
        if leader then AddKills(leader[1], 1, leader[2]) names[#names + 1] = leader[2] end
    end
    return names
end

-- After kills were added: the achievements (and the pieces they unlock, the rank) caught up quietly, and one line
-- saying how many came of it.
local function Recount(what)
    local function Count() local n = 0 for _ in pairs(KillTrackerDB.achievements) do n = n + 1 end return n end
    local before = Count()
    ns.CheckAchievements(true)
    ns.Print(("Dev: %s - %d new achievements."):format(what, Count() - before))
    Refresh()
end

function ns.RandomDeeds()
    local kinds = {}
    for _, subtype in ipairs(MobsBy().subtypes) do kinds[#kinds + 1] = subtype end
    for _ = 1, math.min(8, #kinds) do KillsOf("subtype", Pick(kinds), DEED_COUNTS[math.random(#DEED_COUNTS)]) end
    local dungeons, cleared = {}, {}
    for _, d in ipairs(ns.Dungeons()) do if not d.raid and #d.bossNPCs > 0 then dungeons[#dungeons + 1] = d end end
    for _ = 1, math.min(4, #dungeons) do
        local d, times = Pick(dungeons), math.random(1, 12)
        ClearDungeon(d, times, 1)
        cleared[#cleared + 1] = ("%s x%d"):format(d.name, times)
    end
    SlayLeaders(3)
    Recount(("random deeds; cleared %s"):format(table.concat(cleared, ", ")))
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
    if not ns.IsGuildOfficer(sender) and not ns.IsDevSender(sender) then return end  -- only an officer's or dev's gift counts
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
    left.gifting = { prev, next }  -- (picking a guildmate to give to: officers only)
    who:SetWidth(90)
    who:SetWordWrap(false)
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
            wipe(KillTrackerDB.unlocks)  -- (what you wear: the account's wardrobe too, while you share it)
            wipe(KillTrackerDB.ownUnlocks or {})
            KillTrackerDB.chests, KillTrackerDB.tokens = {}, {}
            ns.Print("Dev: your wardrobe (the shared one too, if you share it), chests and tokens cleared.") Refresh() end },
        { "+5 of all", 92, function()
            KillTrackerDB.tokens = KillTrackerDB.tokens or {}
            for _, d in ipairs(ns.Dungeons()) do KillTrackerDB.tokens[d.key] = (KillTrackerDB.tokens[d.key] or 0) + 5 end
            for _, spec in ipairs(ns.LAYER_INGREDIENTS) do ns.AddIngredient(spec.key, 5, true) end
            for _, fuel in ipairs(ns.FUELS) do ns.AddIngredient(fuel.key, 5, true) end
            for key in pairs(ns.DREAM_ITEMS) do ns.AddIngredient(key, 5, true) end  -- (milk, stories, bonks)
            ns.Print("Dev: 5 of every ingredient for you, and 5 milk, stories and bonks.") Refresh() end },
    }) do
        local button = CreateFrame("Button", nil, left, "UIPanelButtonTemplate")
        button:SetSize(spec[2], 22)
        button:SetText(spec[1])
        button:SetScript("OnClick", spec[3])
        button:SetPoint("TOPLEFT", x, -26)
        x = x + spec[2] + 6
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
        if not officer then self.target = nil end
        for _, region in ipairs(self.gifting) do region:SetShown(officer) end
        self.who:SetShown(officer)
        local tier = ns.CHEST_TIERS[self.previewTier]
        self.tierButton:SetText("Show as: " .. tier.name)
        self.who:SetText("Give to: |cffffd100" .. (self.target and Ambiguate(self.target, "short") or "me") .. "|r")
        local dungeons, counts = ns.Dungeons(), ns.ChestCounts()
        for i, row in ipairs(self.rows) do
            local d = dungeons[self.offset + i]
            row:SetShown(d ~= nil)
            if d then
                row.key = d.key
                local colour = ns.RARITY_COLORS[ns.DungeonRarity(d.key)] or "ffffffff"
                row.name:SetText(("|c%s%s|r"):format(colour, d.name))
                local have, all = ns.PoolProgress("clear:" .. d.key)
                row.status:SetText((have == all and all > 0 and ("|cff55dd55%d/%d|r"):format(have, all) or ("%d/%d"):format(have, all)) .. ((counts[d.key] or 0) > 0 and ("  |cffffd100x%d|r"):format(counts[d.key]) or ""))
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

-- Small parts for the pages ---------------------------------------------------------------------------------------

local function Button(parent, text, width, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 22)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end
local function Label(parent, size, r, g, b)
    local text = parent:CreateFontString(nil, "OVERLAY")
    text:SetFont(NAME_FONT, size or 13, "")
    text:SetTextColor(r or 0.93, g or 0.88, b or 0.78)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    return text
end
local function Heading(parent, text, x, y)
    local heading = Label(parent, 16, 1, 0.5, 0.25)
    heading:SetPoint("TOPLEFT", x, y)
    heading:SetText(text)
    return heading
end
-- A row stepping through a list ([<] [>], Shift: ten at a time): "name: label  i/n". list() gives { { label, value } };
-- onChange(value) after a step. :Reload() reads the list again, :Value() is the one shown.
local function Stepper(parent, width, name, list, onChange)
    local stepper = CreateFrame("Frame", nil, parent)
    stepper:SetSize(width, 22)
    stepper.index, stepper.list = 1, {}
    stepper.text = Label(stepper, 13)
    stepper.text:SetPoint("LEFT", 54, 0)
    stepper.text:SetWidth(width - 54)
    local function Step(delta)
        local n = #stepper.list
        if n == 0 then return end
        if IsShiftKeyDown() then delta = delta * 10 end
        stepper.index = (stepper.index - 1 + delta) % n + 1
        stepper:Draw()
        if onChange then onChange(stepper:Value()) end
    end
    Button(stepper, "<", 24, function() Step(-1) end):SetPoint("LEFT", 0, 0)
    Button(stepper, ">", 24, function() Step(1) end):SetPoint("LEFT", 26, 0)
    function stepper:Value()
        local entry = self.list[self.index]
        if entry then return entry.value end
    end
    function stepper:Draw()
        local entry = self.list[self.index]
        self.text:SetText(("%s: %s  |cff888888%d/%d|r"):format(name, entry and entry.label or "-", entry and self.index or 0, #self.list))
    end
    function stepper:Reload()
        self.list = list()
        self.index = math.max(1, math.min(self.index, #self.list))
        self:Draw()
    end
    function stepper:Select(value)
        for i, entry in ipairs(self.list) do if entry.value == value then self.index = i end end
        self:Draw()
    end
    return stepper
end
local function Colored(rarity, text) return ("|c%s%s|r"):format(ns.RARITY_COLORS[rarity] or "ffffffff", text) end
local function IngredientLabel(key) return ("|T%s:14|t %s"):format(ns.IngredientIcon(key), ns.IngredientName(key)) end
-- Every ingredient there is: the Dream Bed's, the fuels, the layers', the dungeons' tokens.
local function AllIngredients()
    local keys = { "milk", "story", "bonk" }
    for _, fuel in ipairs(ns.FUELS) do keys[#keys + 1] = fuel.key end
    for _, spec in ipairs(ns.LAYER_INGREDIENTS) do keys[#keys + 1] = spec.key end
    for _, d in ipairs(ns.Dungeons()) do if ns.INGREDIENTS[d.key] then keys[#keys + 1] = d.key end end
    return keys
end

-- TRIBUTE ---------------------------------------------------------------------------------------------------------

local function BuildTribute(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetPoint("TOPLEFT", 12, -40)
    page:SetSize(756, 520)
    local spec = { tier = #ns.CHEST_TIERS, items = {}, points = 0, plinko = 0, note = "" }

    -- Left: who it's for, how fancy, and what to put in.
    Heading(page, "Ogre Godz tribute", 0, 0)
    local to = Stepper(page, 360, "To", function()
        local list = { { label = "|cffffd100me|r", value = false } }
        for _, friend in ipairs(ns.GetFriends()) do list[#list + 1] = { label = friend.name, value = friend.key } end
        return list
    end)
    to:SetPoint("TOPLEFT", 0, -26)
    local look = Stepper(page, 360, "Chest", function()
        local list = {}
        for i, tier in ipairs(ns.CHEST_TIERS) do
            list[i] = { label = Colored(({ "uncommon", "rare", "epic", "legendary" })[i], tier.name), value = i }
        end
        return list
    end, function(tier) spec.tier = tier page:Draw() end)
    look:SetPoint("TOPLEFT", 0, -50)

    Heading(page, "A piece", 0, -84)
    local preview = CreateFrame("Frame", nil, page)
    preview:SetSize(96, 96)
    preview:SetPoint("TOPLEFT", 264, -110)
    local previewBack = page:CreateTexture(nil, "BACKGROUND")
    previewBack:SetPoint("TOPLEFT", preview, -3, 3)
    previewBack:SetPoint("BOTTOMRIGHT", preview, 3, -3)
    previewBack:SetColorTexture(0.3, 0.22, 0.12)
    local piece  -- (below: the layer's stepper reloads it)
    local function ShowPiece()
        local layer, option = page.layer, piece and piece:Value()
        if layer and option then ns.DrawPiece(preview, layer.key, option) end
    end
    local layerStep = Stepper(page, 260, "Layer", function()
        local list = {}
        for _, layer in ipairs(ns.MintLayers) do list[#list + 1] = { label = layer.name, value = layer } end
        return list
    end, function(layer) page.layer = layer piece:Reload() ShowPiece() end)
    layerStep:SetPoint("TOPLEFT", 0, -110)
    piece = Stepper(page, 260, "Piece", function()
        local list = {}
        for _, option in ipairs(page.layer and page.layer.options or {}) do
            if option.unlock then
                local have = ns.IsUnlocked(ns.OptionKey(page.layer.key, option)) and " |cff55dd55(yours)|r" or ""
                list[#list + 1] = { label = Colored(option.rarity, option.name) .. have, value = option }
            end
        end
        return list
    end, ShowPiece)
    piece:SetPoint("TOPLEFT", 0, -134)
    local function Full()
        if #spec.items < ns.TRIBUTE_MAX_ITEMS then return false end
        ns.Print(("Dev: the chest is full (%d things)."):format(ns.TRIBUTE_MAX_ITEMS))
        return true
    end
    local function AddPiece(option)
        if not option or Full() then return end
        local key = ns.OptionKey(page.layer.key, option)
        for _, item in ipairs(spec.items) do if item.key == key then return end end
        spec.items[#spec.items + 1] = { kind = "unlock", key = key }
        page:Draw()
    end
    Button(page, "Put it in", 90, function() AddPiece(piece:Value()) end):SetPoint("TOPLEFT", 0, -162)
    Button(page, "A random one", 110, function()
        local options = {}
        for _, entry in ipairs(piece.list) do options[#options + 1] = entry.value end
        if #options > 0 then AddPiece(options[math.random(#options)]) end
    end):SetPoint("TOPLEFT", 96, -162)

    Heading(page, "An ingredient", 0, -222)
    local ingredient = Stepper(page, 360, "Ingredient", function()
        local list = {}
        for _, key in ipairs(AllIngredients()) do list[#list + 1] = { label = IngredientLabel(key), value = key } end
        return list
    end)
    ingredient:SetPoint("TOPLEFT", 0, -246)
    local function AddIngredient(n)
        local key = ingredient:Value()
        if not key then return end
        for _, item in ipairs(spec.items) do
            if item.kind == "ingredient" and item.key == key then item.n = math.min(99, item.n + n) return page:Draw() end
        end
        if Full() then return end
        spec.items[#spec.items + 1] = { kind = "ingredient", key = key, n = n }
        page:Draw()
    end
    for i, n in ipairs({ 1, 5, 20 }) do
        Button(page, "+" .. n, 54, function() AddIngredient(n) end):SetPoint("TOPLEFT", (i - 1) * 60, -272)
    end

    Heading(page, "Points and plinko", 0, -306)
    for i, n in ipairs({ 50, 500, 5000 }) do
        Button(page, ("+%d pts"):format(n), 84, function() spec.points = math.min(100000, spec.points + n) page:Draw() end)
            :SetPoint("TOPLEFT", (i - 1) * 90, -330)
    end
    Button(page, "No points", 84, function() spec.points = 0 page:Draw() end):SetPoint("TOPLEFT", 270, -330)
    Button(page, "+1 plinko drop", 120, function() spec.plinko = math.min(10, spec.plinko + 1) page:Draw() end)
        :SetPoint("TOPLEFT", 0, -356)
    Button(page, "No drops", 84, function() spec.plinko = 0 page:Draw() end):SetPoint("TOPLEFT", 126, -356)

    Heading(page, "A note (shown with it)", 0, -390)
    local note = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
    note:SetSize(340, 22)
    note:SetPoint("TOPLEFT", 6, -414)
    note:SetAutoFocus(false)
    note:SetMaxLetters(80)
    note:SetScript("OnTextChanged", function(self) spec.note = self:GetText() end)
    note:SetScript("OnEnterPressed", note.ClearFocus)
    note:SetScript("OnEscapePressed", note.ClearFocus)

    -- Right: what's in it, and the buttons.
    Heading(page, "In the chest", 400, 0)
    local rows = {}
    for i = 1, ns.TRIBUTE_MAX_ITEMS do
        local row = CreateFrame("Frame", nil, page)
        row:SetSize(350, 24)
        row:SetPoint("TOPLEFT", 400, -26 - (i - 1) * 26)
        row.text = Label(row, 13)
        row.text:SetPoint("LEFT", 30, 0)
        row.text:SetWidth(320)
        row.remove = Button(row, "x", 24, function() table.remove(spec.items, i) page:Draw() end)
        row.remove:SetPoint("LEFT", 0, 0)
        rows[i] = row
    end
    local summary = Label(page, 13)
    summary:SetPoint("TOPLEFT", 400, -26 - ns.TRIBUTE_MAX_ITEMS * 26 - 8)
    summary:SetWidth(350)
    summary:SetWordWrap(true)
    local function Copy()
        local items = {}
        for i, item in ipairs(spec.items) do items[i] = { kind = item.kind, key = item.key, n = item.n } end
        return { tier = spec.tier, points = spec.points, plinko = spec.plinko, note = spec.note, items = items }
    end
    local function Empty() return #spec.items == 0 and spec.points == 0 and spec.plinko == 0 end
    Button(page, "Preview", 100, function()
        -- (out of the way while it plays: back when the chest closes)
        if window and _G.SOLCChest and not window.hooked then
            window.hooked = true
            _G.SOLCChest:HookScript("OnHide", function() if window.reopen then window.reopen = nil window:Show() end end)
        end
        window.reopen = true
        window:Hide()
        ns.ShowChest(ns.TRIBUTE, true, nil, Copy())
    end):SetPoint("TOPLEFT", 400, -260)
    local send = Button(page, "SEND TRIBUTE", 160, function()
        if Empty() then return ns.Print("Dev: the chest is empty.") end
        ns.SendTribute(Copy(), to:Value() or nil)
        Refresh()
    end)
    send:SetPoint("TOPLEFT", 506, -260)
    Button(page, "Empty it", 80, function()
        wipe(spec.items)
        spec.points, spec.plinko = 0, 0
        page:Draw()
    end):SetPoint("TOPLEFT", 672, -260)
    local help = Label(page, 12, 0.62, 0.56, 0.48)
    help:SetPoint("TOPLEFT", 400, -292)
    help:SetWidth(350)
    help:SetWordWrap(true)
    help:SetText("A guildmate gets it as a whisper: they must be online with this SOLC, and their SOLC checks it's from one of your characters. It waits on their PIX page until they open it. Shift-click the arrows to step ten at a time.")

    function page:Draw()
        for i, row in ipairs(rows) do
            local item = spec.items[i]
            row:SetShown(item ~= nil)
            if item and item.kind == "unlock" then
                local unlocked = ns.OptionByKey(item.key)
                row.text:SetText(unlocked and ("%s  |cff888888%s|r"):format(Colored(unlocked.option.rarity, unlocked.option.name), unlocked.layer.name:lower()) or item.key)
            elseif item then
                row.text:SetText(("%d x %s"):format(item.n, IngredientLabel(item.key)))
            end
        end
        summary:SetText(("%s%d points, %d plinko drop%s, a %s chest."):format(#spec.items == 0 and "Nothing else yet; " or "Plus ",
            spec.points, spec.plinko, spec.plinko == 1 and "" or "s", ns.CHEST_TIERS[spec.tier].name:lower()))
    end
    function page:Refresh()
        to:Reload()
        look:Reload()
        look:Select(spec.tier)
        layerStep:Reload()
        page.layer = layerStep:Value()
        piece:Reload()
        ShowPiece()
        ingredient:Reload()
        page:Draw()
    end
    return page
end

-- DEEDS & ME ------------------------------------------------------------------------------------------------------

local function BuildDeeds(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetPoint("TOPLEFT", 12, -40)
    page:SetSize(756, 520)
    local function Names(list)
        return function()
            local out = {}
            for _, name in ipairs(list()) do out[#out + 1] = { label = name, value = name } end
            return out
        end
    end

    -- Left: deeds, on you.
    Heading(page, "Deeds (on you)", 0, 0)
    local kind = Stepper(page, 360, "Creature", Names(function() return MobsBy().subtypes end))
    kind:SetPoint("TOPLEFT", 0, -26)
    for i, n in ipairs({ 10, 100, 1000 }) do
        Button(page, ("+%d kills"):format(n), 100, function()
            local name = kind:Value()
            if name then KillsOf("subtype", name, n) Recount(("%d %s kills"):format(n, name)) end
        end):SetPoint("TOPLEFT", (i - 1) * 106, -50)
    end
    local tribe = Stepper(page, 360, "Tribe", Names(function() return MobsBy().factions end))
    tribe:SetPoint("TOPLEFT", 0, -84)
    for i, n in ipairs({ 100, 1000 }) do
        Button(page, ("+%d kills"):format(n), 100, function()
            local name = tribe:Value()
            if name then KillsOf("faction", name, n) Recount(("%d %s kills"):format(n, name)) end
        end):SetPoint("TOPLEFT", (i - 1) * 106, -108)
    end
    local dungeon = Stepper(page, 360, "Dungeon", function()
        local list = {}
        for _, d in ipairs(ns.Dungeons()) do
            if #d.bossNPCs > 0 or next(d.lastNPCs) then list[#list + 1] = { label = d.name, value = d } end
        end
        return list
    end)
    dungeon:SetPoint("TOPLEFT", 0, -142)
    for i, n in ipairs({ 1, 10 }) do
        Button(page, ("+%d clear%s"):format(n, n == 1 and "" or "s"), 100, function()
            local d = dungeon:Value()
            if d then ClearDungeon(d, n) Recount(("%s cleared %d times (and %d chests)"):format(d.name, n, math.min(n, 10))) end
        end):SetPoint("TOPLEFT", (i - 1) * 106, -166)
    end
    Button(page, "Slay 3 leaders", 120, function()
        local names = SlayLeaders(3)
        Recount("slain " .. table.concat(names, ", "))
    end):SetPoint("TOPLEFT", 0, -204)
    Button(page, "Random deeds", 120, function() ns.RandomDeeds() end):SetPoint("TOPLEFT", 126, -204)
    local note = Label(page, 12, 0.62, 0.56, 0.48)
    note:SetPoint("TOPLEFT", 0, -236)
    note:SetWidth(370)
    note:SetWordWrap(true)
    note:SetText("Kills count as if they happened: the achievements, their creature hats and onesies, points and rank follow by themselves. A dungeon's clears give a chest each (up to 10). Shift-click the arrows to step ten at a time.")

    -- Right: you.
    Heading(page, "Me", 400, 0)
    local status = Label(page, 13)
    status:SetPoint("TOPLEFT", 400, -26)
    status:SetWidth(350)
    local function AddPoints(n)
        local points = KillTrackerDB.points
        points.chests = (points.chests or 0) + n
        ns.Touch(points)
        ns.CheckRank()
        Refresh()
    end
    for i, n in ipairs({ 100, 1000, 10000 }) do
        Button(page, ("+%d pts"):format(n), 100, function() AddPoints(n) end):SetPoint("TOPLEFT", 400 + (i - 1) * 106, -50)
    end
    local rank = Stepper(page, 350, "Ogre Rank", function()
        local list = {}
        for _, r in ipairs(ns.RANKS) do list[#list + 1] = { label = ("%d %s"):format(r.rank, r.title), value = r } end
        return list
    end)
    rank:SetPoint("TOPLEFT", 400, -84)
    Button(page, "Reach it", 100, function()
        local r = rank:Value()
        local need = r and r.points - ns.GetPoints().earned or 0
        if need <= 0 then return ns.Print("Dev: you're there already (a rank can't go down: points earned stay earned).") end
        AddPoints(need)
    end):SetPoint("TOPLEFT", 400, -108)
    Button(page, "+1 plinko drop", 120, function() ns.GiftPlinkoDrops(1) ns.Print("Dev: a free plinko drop.") end)
        :SetPoint("TOPLEFT", 400, -146)
    Button(page, "+3 plinko drops", 120, function() ns.GiftPlinkoDrops(3) ns.Print("Dev: 3 free plinko drops.") end)
        :SetPoint("TOPLEFT", 526, -146)
    Heading(page, "Dream Bed", 400, -184)
    for row, key in ipairs({ "milk", "story", "bonk" }) do
        local label = Label(page, 13)
        label:SetPoint("TOPLEFT", 400, -212 - (row - 1) * 26)
        label:SetWidth(160)
        label:SetText(IngredientLabel(key))
        for i, n in ipairs({ 1, 5 }) do
            Button(page, "+" .. n, 48, function() ns.AddIngredient(key, n) Refresh() end)
                :SetPoint("TOPLEFT", 566 + (i - 1) * 54, -208 - (row - 1) * 26)
        end
    end

    function page:Refresh()
        kind:Reload()
        tribe:Reload()
        dungeon:Reload()
        rank:Reload()
        local p, r = ns.GetPoints(), ns.GetRank()
        local plinko = KillTrackerDB.plinko
        status:SetText(("Earned %d points, %d to spend. Rank %d %s. Plinko drops waiting: %d."):format(p.earned, p.balance,
            r.rank, r.title, plinko and plinko.gifted or 0))
        rank:Select(ns.RANKS[math.min(#ns.RANKS, r.rank + 1)])
    end
    return page
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
    -- The tabs: CHESTS & ART (the chests and the layer browser), TRIBUTE, DEEDS & ME.
    local main = CreateFrame("Frame", nil, window)
    main:SetAllPoints()
    local chests = BuildChests(main)
    local browser = BuildBrowser(main)
    local tribute = BuildTribute(window)
    local deeds = BuildDeeds(window)
    local say = ns.BuildDMSay and ns.BuildDMSay(window, browser)  -- (officers: pop in as the ogre, DMSay.lua)
    local pages = { { "CHESTS & ART", main, 120 }, { "TRIBUTE", tribute, 90 }, { "DEEDS & ME", deeds, 110 } }
    window.tab = 1
    local x = -40
    for i = #pages, 1, -1 do
        local spec = pages[i]
        x = x - spec[3] - 4
        spec.button = Button(window, spec[1], spec[3], function()
            window.tab = i
            window:Refresh()
        end)
        spec.button:SetPoint("TOPRIGHT", x + spec[3], -10)
    end
    function window:Refresh()
        title:SetText("SOLC DEV (drag to move)")
        for i, spec in ipairs(pages) do
            spec[2]:SetShown(i == self.tab)
            if i == self.tab then spec.button:LockHighlight() else spec.button:UnlockHighlight() end
        end
        if self.tab == 1 then
            chests:Refresh()
            browser:Refresh()
        else
            pages[self.tab][2]:Refresh()
        end
        if say then say:SetShown(self.tab == 1 and ns.CanEditConfig()) end
    end
    window:SetScript("OnShow", function(self) self:Refresh() end)
    window:Hide()
end

function ns.ToggleDev()
    if not ns.IsDev() then return false end
    if not window then Build() end
    window:SetShown(not window:IsShown())
end
