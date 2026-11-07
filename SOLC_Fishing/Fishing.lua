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
-- new trip.

local ADDON = ...

local FISHING_ID = 7620  -- (Fishing; its name in your language casts any rank you know)
local function SpellName(id)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    return GetSpellInfo and (GetSpellInfo(id)) or nil
end
local issecret = issecretvalue or function() return false end

local db  -- SOLCFishingDB, set up at login
local trip = { total = 0, caught = {}, order = {} }  -- this trip's catch (until /solcfish reset or a logout)

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

-- The ogre's catch log ----------------------------------------------------------------------------------------------

local SAY = {
    fish = { "FISH!", "GOT ONE!", "SLIPPY!", "YUM YUM", "DINNER!", "IN BUCKET", "GOOD FISH", "SPLASH!" },
    big = { "BIG ONE!", "HUGE FISH!", "LOOK! LOOK!", "FISH KING!" },  -- (a rare or better)
    junk = { "BOOT?!", "NOT FISH.", "WHO LOST THIS", "BAD FISH", "HMPH." },
    start = { "QUIET. FISH.", "OGRE FISHIN'", "SHHH...", "WATER. FISH. GO." },
}
local function Say(kind) local list = SAY[kind] return list[math.random(#list)] end
-- (no fishing key set yet: once a session, where to set one)
local hinted = false
local function HintKey()
    if hinted or GetBindingKey("CLICK SOLCFishButton:LeftButton") then return end
    hinted = true
    print("|cffffd100SOLC Fishing:|r pick your fishing key in Options > Keybindings > AddOns > SOLC Fishing. Press it to cast, and again to reel in.")
end

local panel = CreateFrame("Frame", "SOLCFishingPanel", UIParent, "BackdropTemplate")
panel:SetSize(230, 210)
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
title:SetPoint("TOPLEFT", 12, -10)
title:SetText("Ogre Fishin'")
local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", 2, 2)
close:SetScript("OnClick", function() panel:Hide() end)

local tripLine = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
tripLine:SetPoint("TOPLEFT", 12, -34)
local rows = {}
for i = 1, 6 do
    local row = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row:SetPoint("TOPLEFT", 14, -54 - (i - 1) * 15)
    row:SetPoint("RIGHT", -12, 0)
    row:SetJustifyH("LEFT")
    row:SetWordWrap(false)
    rows[i] = row
end
local posterLine = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
posterLine:SetPoint("BOTTOMLEFT", 12, 34)
posterLine:SetPoint("RIGHT", -12, 0)
posterLine:SetJustifyH("LEFT")
-- (the ogre's word: big, at the bottom)
local said = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
said:SetPoint("BOTTOM", 0, 10)
said:SetTextColor(1, 0.82, 0.25)

local function Refresh()
    tripLine:SetText(("This trip: |cffffffff%d|r   Ever: |cffffffff%d|r"):format(trip.total, db and db.total or 0))
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
events:SetScript("OnEvent", function(_, event, unit, _, spellID)
    if event == "PLAYER_LOGIN" then
        SOLCFishingDB = SOLCFishingDB or {}
        db = SOLCFishingDB
        db.caught, db.total = db.caught or {}, db.total or 0
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
            Open()
            HintKey()
        else
            LineIn()
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- (a fight: the key's own again before combat locks bindings)
        ClearOverrideBindings(owner)
    elseif event == "LOOT_OPENED" then
        if not (IsFishingLoot and IsFishingLoot()) then return end
        for slot = 1, GetNumLootItems() do
            local _, name, quantity, _, quality = GetLootSlotInfo(slot)
            if name and (quantity or 0) > 0 then Caught(name, quantity, quality) end
        end
    end
end)

SLASH_SOLCFISH1 = "/solcfish"
SlashCmdList.SOLCFISH = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "reset" then
        trip = { total = 0, caught = {}, order = {} }
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
