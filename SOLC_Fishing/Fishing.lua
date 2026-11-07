-- SOLC Fishing: one key for fishing, and an ogre who keeps your catch log.
--
-- The key (Options > Keybindings > AddOns > SOLC Fishing) clicks SOLCFishButton, a secure button that casts Fishing.
-- While the line is out (the Fishing channel), the same key is bound over to Interact With Target, and soft-interact is
-- turned on, so pressing it again reels in the bobber - no clicking it. When the channel ends, both go back as they were.
-- Nothing changes in combat (WoW won't allow it): then you fish the usual way.
--
-- The catch log: a small panel that comes up when you cast. This trip's catch by kind, an ogre's word on each catch,
-- and (with SOLC) your Gone Fishing poster this week. SOLCFishingDB = { point = { ... } (where you put the panel),
-- caught = { [item name] = total ever }, total = fish ever }. /solcfish shows or hides it; /solcfish reset starts a
-- new trip; /solcfish sound turns the fishing sound boost off or on.

local ADDON = ...

local FISHING_ID = 7620  -- (Fishing; its name in your language casts any rank you know)
local function SpellName(id)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    return GetSpellInfo and (GetSpellInfo(id)) or nil
end
local issecret = issecretvalue or function() return false end

local db  -- SOLCFishingDB, set up at login
local trip = { total = 0, caught = {}, order = {}, away = 0 }  -- this trip's catch, and the fish that got away (until /solcfish reset or a logout)

-- The cast button -------------------------------------------------------------------------------------------------

local button = CreateFrame("Button", "SOLCFishButton", UIParent, "SecureActionButtonTemplate")
button:SetAttribute("type", "spell")
-- (a click on key down or key up, as your action bars are set: both would cast twice and pull the line in again)
local function ClickOn() return (C_CVar and C_CVar.GetCVarBool and C_CVar.GetCVarBool("ActionButtonUseKeyDown")) and "AnyDown" or "AnyUp" end

_G.BINDING_HEADER_SOLCFISHING = "SOLC Fishing"
_G["BINDING_NAME_CLICK SOLCFishButton:LeftButton"] = "Fish / reel in"

-- While the line is out: the fishing key interacts with the bobber, soft-interact on (and reaching far enough).
local owner = CreateFrame("Frame")
local saved  -- the CVars as they were, while we've changed them
local SOFT = { SoftTargetInteract = "3", SoftTargetInteractArc = "2", SoftTargetInteractRange = "30" }
local function GetCVar(name) return C_CVar and C_CVar.GetCVar and C_CVar.GetCVar(name) end
local function SetCVar(name, value) if C_CVar and C_CVar.SetCVar then pcall(C_CVar.SetCVar, name, value) end end

local function LineOut()
    if InCombatLockdown() then return end
    saved = saved or {}
    for name, value in pairs(SOFT) do
        if saved[name] == nil then saved[name] = GetCVar(name) or false end
        SetCVar(name, value)
    end
    for _, key in ipairs({ GetBindingKey("CLICK SOLCFishButton:LeftButton") }) do
        SetOverrideBinding(owner, true, key, "INTERACTTARGET")
    end
end
local function LineIn()
    if InCombatLockdown() then return end
    ClearOverrideBindings(owner)
    for name, value in pairs(saved or {}) do
        if value ~= false then SetCVar(name, value) end
    end
    saved = nil
end

-- The sound: while you fish, game sounds up and music and ambience down, so the bobber's splash is easy to hear (and
-- sound on with WoW in the background). It stays so between casts and goes back SOUND_BACK seconds after the last one,
-- when a fight starts, or at logout. The volumes as they were are kept in SOLCFishingDB.sound meanwhile, so a crash
-- doesn't leave your music off: the next login puts them back. /solcfish sound turns it off or on (db.noSound).
local SOUND = { Sound_SFXVolume = "1.0", Sound_MusicVolume = "0", Sound_AmbienceVolume = "0", Sound_EnableSoundWhenGameIsInBG = "1" }
local SOUND_BACK = 20
local soundTimer
local function SoundBack()
    if soundTimer then soundTimer:Cancel() soundTimer = nil end
    for name, value in pairs(db and db.sound or {}) do
        if value ~= false then SetCVar(name, value) end
    end
    if db then db.sound = nil end
end
local function SoundUp()
    if not db or db.noSound then return end
    if soundTimer then soundTimer:Cancel() soundTimer = nil end
    if not db.sound then
        db.sound = {}
        for name, value in pairs(SOUND) do
            db.sound[name] = GetCVar(name) or false
            SetCVar(name, value)
        end
    end
end
local WeaponsBack  -- (below)
local function SoundLater()
    if not (db and (db.sound or db.weapons)) or not C_Timer then return end
    if soundTimer then soundTimer:Cancel() end
    soundTimer = C_Timer.NewTimer(SOUND_BACK, function() SoundBack() if WeaponsBack then WeaponsBack() end end)
end

-- The pole and the lure: the fishing key first puts your fishing pole on (your weapons remembered), then a lure on it
-- if it has none, then casts. Your weapons go back with the sound, SOUND_BACK seconds after the last cast - not in a
-- fight (WoW allows no gear swaps by addons then: the ogre shouts, and you swap yourself or wait).
local LURES = { 6533, 7307, 6532, 6530, 6529 }  -- (best first: Aquadynamic Fish Attractor, Flesh Eating Worm, Bright Baubles, Nightcrawlers, Shiny Bauble)
local function ItemInfo(id)
    if C_Item and C_Item.GetItemInfoInstant then return C_Item.GetItemInfoInstant(id) end
    return GetItemInfoInstant and GetItemInfoInstant(id)
end
local function IsPole(id)
    if not id then return false end
    local _, _, _, _, _, classID, subclassID = ItemInfo(id)
    return classID == 2 and subclassID == 20  -- (a weapon: fishing pole)
end
local function PoleInBags()
    local slots = C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
    local itemAt = C_Container and C_Container.GetContainerItemID or GetContainerItemID
    for bag = 0, 4 do
        for slot = 1, slots and slots(bag) or 0 do
            local id = itemAt(bag, slot)
            if IsPole(id) then return id end
        end
    end
end
local function ItemCount(id)
    if C_Item and C_Item.GetItemCount then return C_Item.GetItemCount(id) end
    return GetItemCount and GetItemCount(id) or 0
end
local function BestLure()
    for _, id in ipairs(LURES) do if ItemCount(id) > 0 then return id end end
end
local function PoleOn() return IsPole(GetInventoryItemID("player", 16)) end
local function Lured() return (GetWeaponEnchantInfo()) == true end
-- (before each press, out of combat: what the key does this time)
button:SetScript("PreClick", function(self)
    if InCombatLockdown() then return end
    local pole = not PoleOn() and PoleInBags()
    local lure = PoleOn() and not Lured() and BestLure()
    if pole then
        if db and not db.weapons then  -- (your weapons, to put back)
            db.weapons = { main = GetInventoryItemID("player", 16), off = GetInventoryItemID("player", 17) }
        end
        self:SetAttribute("type", "macro")
        self:SetAttribute("macrotext", "/equip item:" .. pole)
    elseif lure then
        self:SetAttribute("type", "macro")
        self:SetAttribute("macrotext", "/use item:" .. lure .. "\n/use 16")
    else
        self:SetAttribute("type", "spell")
    end
end)
local function EquipID(id, slot)
    if not id then return end
    if C_Item and C_Item.EquipItemByName then pcall(C_Item.EquipItemByName, id, slot) elseif EquipItemByName then pcall(EquipItemByName, id, slot) end
end
function WeaponsBack()
    if not (db and db.weapons) or InCombatLockdown() then return end
    if PoleOn() then
        EquipID(db.weapons.main, 16)
        EquipID(db.weapons.off, 17)
    end
    db.weapons = nil
end

-- The catch log, kept by Reginald (the club's steward, dressed for fishing: MediaReginald, tools/make-fishing-reginald.js)
-- in his own voice: a word on each catch, now and then a tip ----------------------------------------------------------------------------------------------

local SAY = {
    fish = { "A respectable catch.", "Into the bucket, if you please.", "Adequate. Barely.", "One more for the club's kitchen.",
        "Do try not to drip on the tweed.", "Mm. It will fry." },
    big = { "Good heavens. A proper specimen!", "Now THAT is a fish worth telling the club about.", "I shall have it mounted. Over your bed." },  -- (a rare or better)
    junk = { "A boot. How very... you.", "That is not a fish. That is litter.", "Throw it back. Discreetly." },
    start = { "Ahem. Fishing, are we? One does not splash. One waits.", "Patience, sir. The fish can smell desperation.",
        "I've packed the good bucket. Do not lose it.", "Quietly now. This is a leisure club." },
    tip = { "Lures help, I'm told. I've taken the liberty of putting one on.", "The shimmering pools hold more fish. Fish there.",
        "Every catch sharpens the skill. Even the boots.", "Fight with your weapons, sir. Not the pole." },
    fight = { "Sir! Your weapons! The pole is NOT a weapon." },
    away = { "It got away. They do that when one dawdles.", "Gone. I shan't mention it at the club.", "Too slow, sir. Press the key when it splashes.",
        "A pity. That one looked expensive." },
    nothing = { "Nothing was biting yet, sir. Wait for the splash." },
}
local casts = 0  -- (this session: every few casts Reginald offers a tip)
local function Say(kind) local list = SAY[kind] return list[math.random(#list)] end
local said  -- (his bubble's text: below)
-- (no fishing key set yet: once a session, where to set one)
local hinted = false
local function HintKey()
    if hinted or GetBindingKey("CLICK SOLCFishButton:LeftButton") then return end
    hinted = true
    print("|cffffd100SOLC Fishing:|r pick your fishing key in Options > Keybindings > AddOns > SOLC Fishing. Press it to cast, and again to reel in.")
end

local panel = CreateFrame("Frame", "SOLCFishingPanel", UIParent, "BackdropTemplate")
panel:SetSize(260, 212)
panel:SetPoint("RIGHT", UIParent, "RIGHT", -220, 40)
panel:SetFrameStrata("MEDIUM")
panel:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 14, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
panel:SetBackdropColor(0.08, 0.06, 0.04, 0.88)
panel:SetBackdropBorderColor(0.75, 0.6, 0.35)
panel:SetMovable(true)
panel:EnableMouse(true)
panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", panel.StartMoving)
panel:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    if db then db.point = { point, relPoint, x, y } end
end)
panel:Hide()

local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 12, -24)  -- (under Reginald's name plate)
title:SetText("Catch log")
local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", 2, 2)
close:SetScript("OnClick", function() panel:Hide() end)

-- Reginald standing on top of the panel, as he stands on the club window's top beam in the tour (Onboarding.lua): drawn
-- from his picture pieces by SOLC (SOLC.RenderPicture; without SOLC: his painted portrait, Media\Reginald), cut off at
-- the panel's top edge as if behind it, his name plate on the edge, his bubble on his left.
local SOLC_MEDIA = "Interface\\AddOns\\SOLC\\Media\\"
local NAME_FONT = SOLC_MEDIA .. "Fonts\\GermaniaOne-Regular.ttf"
local REGINALD = { skin = "club_sage", eyes = "snooty_eyes", expression = "snooty_sneer", headwear = "gacha_head_souwester",
    outfit = "shop_norfolk_jacket", accessory = "prop_fish" }
local OGRE, STAND, SUNK = 150, 140, 10  -- (his size; his middle, from the panel's left; how much of him is behind its edge)
local clip = CreateFrame("Frame", nil, panel)
clip:SetPoint("BOTTOMLEFT", panel, "TOPLEFT", 0, -2)
clip:SetPoint("BOTTOMRIGHT", panel, "TOPRIGHT", 0, -2)
clip:SetHeight(OGRE)
clip:SetClipsChildren(true)
local canvas = CreateFrame("Frame", nil, clip)
canvas:SetSize(OGRE, OGRE)
canvas:SetPoint("BOTTOM", panel, "TOPLEFT", STAND, -SUNK)
local portrait = canvas:CreateTexture(nil, "ARTWORK")  -- (without SOLC: his painted head and shoulders instead)
portrait:SetSize(OGRE * 0.62, OGRE * 0.62)
portrait:SetPoint("BOTTOM")
portrait:SetTexture("Interface\\AddOns\\SOLC_Fishing\\Media\\Reginald")
local drawn = false
local function DrawReginald()
    if drawn then return end
    drawn = true
    local ok = SOLC and SOLC.RenderPicture and pcall(SOLC.RenderPicture, canvas, REGINALD)
    portrait:SetShown(not ok)
end
-- (his name plate, on the panel's edge under him: SOLC's wooden plank)
local plate = CreateFrame("Frame", nil, panel)
plate:SetSize(120, 30)
plate:SetPoint("CENTER", panel, "TOPLEFT", STAND, -2)
plate:SetFrameLevel(panel:GetFrameLevel() + 6)
for _, part in ipairs({ { "PlankLeft", "LEFT", 15 }, { "PlankRight", "RIGHT", 15 } }) do
    local t = plate:CreateTexture(nil, "ARTWORK")
    t:SetTexture(SOLC_MEDIA .. "Wood\\" .. part[1]) t:SetSize(part[3], 30) t:SetPoint(part[2])
    plate[part[1]] = t
end
local plank = plate:CreateTexture(nil, "ARTWORK")
plank:SetTexture(SOLC_MEDIA .. "Wood\\Plank")
plank:SetPoint("TOPLEFT", plate.PlankLeft, "TOPRIGHT") plank:SetPoint("BOTTOMRIGHT", plate.PlankRight, "BOTTOMLEFT")
local plateName = plate:CreateFontString(nil, "OVERLAY")
if not plateName:SetFont(NAME_FONT, 15, "") then plateName:SetFontObject("GameFontNormal") end
plateName:SetTextColor(1, 0.86, 0.55)
plateName:SetShadowOffset(1, -1)
plateName:SetPoint("CENTER", 0, 1)
plateName:SetText("Reginald")
-- (his bubble: parchment, on his left above the panel, its tail toward him)
local bubble = CreateFrame("Frame", nil, panel, "BackdropTemplate")
bubble:SetPoint("BOTTOMRIGHT", panel, "TOPLEFT", STAND - OGRE * 0.32, 20)
bubble:SetWidth(200)
bubble:SetFrameLevel(panel:GetFrameLevel() + 8)
bubble:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 14, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
bubble:SetBackdropColor(0.98, 0.95, 0.86, 0.97)
bubble:SetBackdropBorderColor(0.35, 0.24, 0.12)
local tail = bubble:CreateTexture(nil, "BACKGROUND", nil, -1)
tail:SetSize(16, 16)
tail:SetPoint("CENTER", bubble, "BOTTOMRIGHT", -2, 12)
tail:SetColorTexture(0.98, 0.95, 0.86, 0.97)
tail:SetRotation(math.rad(45))
said = bubble:CreateFontString(nil, "OVERLAY")
if not said:SetFont(NAME_FONT, 14, "") then said:SetFontObject("GameFontNormal") end
said:SetTextColor(0.15, 0.1, 0.06)
said:SetPoint("TOPLEFT", 12, -10)
said:SetWidth(176)
said:SetJustifyH("LEFT")
said:SetSpacing(2)
-- (the bubble as tall as what he says)
hooksecurefunc(said, "SetText", function(self) bubble:SetHeight((self:GetStringHeight() or 14) + 22) end)

local tripLine = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
tripLine:SetPoint("TOPLEFT", 12, -48)
local rows = {}
for i = 1, 6 do
    local row = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row:SetPoint("TOPLEFT", 14, -68 - (i - 1) * 15)
    row:SetPoint("RIGHT", -12, 0)
    row:SetJustifyH("LEFT")
    row:SetWordWrap(false)
    rows[i] = row
end
local posterLine = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
posterLine:SetPoint("BOTTOMLEFT", 12, 12)
posterLine:SetPoint("RIGHT", -12, 0)
posterLine:SetJustifyH("LEFT")

local function Refresh()
    tripLine:SetText(("This trip: |cffffffff%d|r   Got away: |cffffffff%d|r   Ever: |cffffffff%d|r"):format(trip.total, trip.away, db and db.total or 0))
    -- (the most caught first)
    local list = {}
    for _, name in ipairs(trip.order) do list[#list + 1] = name end
    table.sort(list, function(a, b) return trip.caught[a].count > trip.caught[b].count end)
    for i, row in ipairs(rows) do
        local name = list[i]
        if name then
            local c = trip.caught[name]
            local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[c.quality or 1]
            row:SetText(("%s%s|r  x%d"):format(color and color.hex or "|cffffffff", name, c.count))
        else
            row:SetText(i == 1 and trip.total == 0 and "|cff999999Nothing yet. Cast with your fishing key.|r" or "")
        end
    end
    -- (SOLC's Gone Fishing poster, if it's on your board this week)
    local have, goal, done
    if SOLC and SOLC.FishingPoster then have, goal, done = SOLC.FishingPoster() end
    posterLine:SetText(goal and (done and "Gone Fishing poster: |cff40ff40claimed!|r" or ("Gone Fishing poster: %d / %d"):format(have, goal)) or "")
end

local function Open()
    DrawReginald()
    if not panel:IsShown() then
        said:SetText(Say("start"))
        panel:Show()
    end
    Refresh()
end

-- A catch: counted for the trip and ever, and the ogre has his say.
local function Caught(name, quantity, quality)
    if not name or issecret(name) then return end
    quantity = quantity or 1
    local c = trip.caught[name]
    if not c then
        c = { count = 0, quality = quality }
        trip.caught[name] = c
        trip.order[#trip.order + 1] = name
    end
    c.count = c.count + quantity
    trip.total = trip.total + quantity
    if db then
        db.caught[name] = (db.caught[name] or 0) + quantity
        db.total = (db.total or 0) + quantity
    end
    said:SetText(Say((quality or 1) == 0 and "junk" or (quality or 1) >= 3 and "big" or "fish"))
    Open()
end

-- Events ---------------------------------------------------------------------------------------------------------

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
events:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("LOOT_OPENED")
events:RegisterEvent("PLAYER_LOGOUT")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event, unit, _, spellID)
    if event == "PLAYER_LOGIN" then
        SOLCFishingDB = SOLCFishingDB or {}
        db = SOLCFishingDB
        db.caught, db.total = db.caught or {}, db.total or 0
        SoundBack()  -- (left boosted by a crash or a disconnect: your own volumes back)
        if db.point then
            panel:ClearAllPoints()
            panel:SetPoint(db.point[1], UIParent, db.point[2], db.point[3], db.point[4])
        end
        local fishing = SpellName(FISHING_ID)
        if fishing then button:SetAttribute("spell", fishing) end
        button:RegisterForClicks(ClickOn())
    elseif event == "UNIT_SPELLCAST_CHANNEL_START" or event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        if unit ~= "player" or issecret(spellID) then return end
        local name = SpellName(spellID)
        if not name or name ~= SpellName(FISHING_ID) then return end
        if event == "UNIT_SPELLCAST_CHANNEL_START" then
            LineOut()
            SoundUp()
            Open()
            casts = casts + 1
            if casts % 6 == 0 then said:SetText(Say("tip")) end
            HintKey()
        else
            LineIn()
            SoundLater()
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- (a fight: the key's own again before combat locks bindings, and your sound back)
        ClearOverrideBindings(owner)
        SoundBack()
        if db and db.weapons and PoleOn() then  -- (a fight with the pole in hand: we may not swap now)
            said:SetText(Say("fight"))
            print("|cffff5555SOLC Fishing:|r you're fighting with your fishing pole! Swap to your weapons yourself - addons can't in a fight.")
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if db and db.weapons and not (UnitChannelInfo and UnitChannelInfo("player")) then WeaponsBack() end  -- (after the fight: weapons back)
    elseif event == "PLAYER_LOGOUT" then
        SoundBack()
    elseif event == "LOOT_OPENED" then
        if not (IsFishingLoot and IsFishingLoot()) then return end
        for slot = 1, GetNumLootItems() do
            local _, name, quantity, _, quality = GetLootSlotInfo(slot)
            if name and (quantity or 0) > 0 then Caught(name, quantity, quality) end
        end
    end
end)

-- The fish that got away: WoW says so as an error ("Your fish got away!"; too early: "No fish are hooked.").
local function ErrorText(name) local text = _G[name] return type(text) == "string" and text or nil end
local errors = CreateFrame("Frame")
errors:RegisterEvent("UI_ERROR_MESSAGE")
errors:RegisterEvent("UI_INFO_MESSAGE")
errors:RegisterEvent("CHAT_MSG_SYSTEM")
local debugErrors = false  -- (/solcfish debug: every such message printed, to see WoW's exact words)
local function Matches(message, ...)
    for _, name in ipairs({ ... }) do
        local text = ErrorText(name)
        if text and message == text then return true end
    end
end
errors:SetScript("OnEvent", function(_, event, a, b)
    -- (UI_ERROR_MESSAGE and UI_INFO_MESSAGE: type, message; CHAT_MSG_SYSTEM: the message first)
    local message = type(b) == "string" and b or a
    if type(message) ~= "string" or issecret(message) then return end
    if debugErrors then print(("|cffffd100SOLC Fishing debug|r %s: %s"):format(event, message)) end
    local lower = message:lower()
    if Matches(message, "ERR_FISH_ESCAPED", "FISH_ESCAPED") or lower:find("got away", 1, true) then
        trip.away = trip.away + 1
        said:SetText(Say("away"))
        if panel:IsShown() then Refresh() end
    elseif Matches(message, "ERR_FISH_NOT_HOOKED") or lower:find("no fish are hooked", 1, true) then
        said:SetText(Say("nothing"))
    end
end)

SLASH_SOLCFISH1 = "/solcfish"
SlashCmdList.SOLCFISH = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "debug" then
        debugErrors = not debugErrors
        print("|cffffd100SOLC Fishing:|r error and info messages " .. (debugErrors and "printed in chat (let a fish get away now)." or "no longer printed."))
    elseif msg == "sound" then
        db.noSound = not db.noSound or nil
        if db.noSound then SoundBack() end
        print("|cffffd100SOLC Fishing:|r the fishing sound boost is " .. (db.noSound and "off." or "on."))
    elseif msg == "reset" then
        trip = { total = 0, caught = {}, order = {}, away = 0 }
        said:SetText(Say("start"))
        Refresh()
        print("|cffffd100SOLC Fishing:|r a new trip.")
    elseif panel:IsShown() then
        panel:Hide()
    else
        Open()
        HintKey()
    end
end
