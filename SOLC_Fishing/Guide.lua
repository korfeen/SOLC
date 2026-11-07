-- The fishing and cooking guide: a second page beside the catch log (its GUIDE button, or /solcfish guide).
--   Where to fish: your fishing skill, this zone's (the skill where fish stop getting away, ZONES), what that means
--   for you, and the zones that suit your skill now.
--   Cooking your catch: the fish worth cooking on the way up (FISH: the dish, and the cooking skill it's learnt at),
--   ticked when you've caught one, with your cooking skill.
-- The zone numbers are approximate (gathered by anglers over the years, as the wikis give them); in Classic the cap is
-- 300, so the zones above that want a better pole and a lure. Reginald comments.

local _, F = ...

-- Each zone: the fishing skill at which fish stop getting away (below it, some slip off the hook).
local ZONES = {
    ["Dun Morogh"] = 25, ["Durotar"] = 25, ["Elwynn Forest"] = 25, ["Mulgore"] = 25, ["Tirisfal Glades"] = 25, ["Teldrassil"] = 25,
    ["Darkshore"] = 75, ["Loch Modan"] = 75, ["The Barrens"] = 75, ["Redridge Mountains"] = 75, ["Silverpine Forest"] = 75,
    ["Westfall"] = 75, ["Stormwind City"] = 75, ["Ironforge"] = 75, ["Darnassus"] = 75, ["Orgrimmar"] = 75,
    ["Thunder Bluff"] = 75, ["Undercity"] = 75, ["The Deadmines"] = 75, ["Wailing Caverns"] = 75, ["Blackfathom Deeps"] = 75,
    ["Arathi Highlands"] = 150, ["Ashenvale"] = 150, ["Duskwood"] = 150, ["Hillsbrad Foothills"] = 150,
    ["Stranglethorn Vale"] = 150, ["Stonetalon Mountains"] = 150, ["Wetlands"] = 150,
    ["Desolace"] = 225, ["Dustwallow Marsh"] = 225, ["Feralas"] = 225, ["The Hinterlands"] = 225, ["Scarlet Monastery"] = 225,
    ["Western Plaguelands"] = 225,
    ["Badlands"] = 300, ["Eastern Plaguelands"] = 300, ["Felwood"] = 300, ["Moonglade"] = 300, ["Tanaris"] = 300,
    ["Thousand Needles"] = 300, ["Azshara"] = 300,
    ["Un'Goro Crater"] = 375,
    ["Blasted Lands"] = 425, ["Deadwind Pass"] = 425, ["Dire Maul"] = 425, ["Scholomance"] = 425, ["Searing Gorge"] = 425,
    ["Silithus"] = 425, ["Stratholme"] = 425, ["Swamp of Sorrows"] = 425, ["Winterspring"] = 425,
}
-- The fish worth cooking on the way up: the raw fish, the dish, the cooking skill its recipe is learnt at.
local FISH = {
    { "Raw Brilliant Smallfish", "Brilliant Smallfish", 1 },
    { "Raw Longjaw Mud Snapper", "Longjaw Mud Snapper", 50 },
    { "Raw Bristle Whisker Catfish", "Bristle Whisker Catfish", 100 },
    { "Raw Mithril Head Trout", "Cooked Mithril Head Trout", 175 },
    { "Raw Spotted Yellowtail", "Spotted Yellowtail", 225 },
    { "Large Raw Mightfish", "Mightfish Steak", 275 },
}

-- A profession's skill by its skill line (356 fishing, 185 cooking), or nil if you don't have it.
local function Skill(line)
    if not GetProfessions or not GetProfessionInfo then return end
    for _, index in pairs({ GetProfessions() }) do
        if index then
            local _, _, rank, max, _, _, skillLine = GetProfessionInfo(index)
            if skillLine == line then return rank, max end
        end
    end
end

local INK, INK_DIM, RED_INK, GREEN_INK = { 0.2, 0.12, 0.05 }, { 0.45, 0.35, 0.24 }, { 0.62, 0.12, 0.08 }, { 0.15, 0.42, 0.12 }
local INK_FONT = "Interface\\AddOns\\SOLC\\Media\\Fonts\\GermaniaOne-Regular.ttf"
local function Ink(parent, size, color)
    local text = parent:CreateFontString(nil, "OVERLAY")
    if not text:SetFont(INK_FONT, size, "") then text:SetFontObject("GameFontHighlight") end
    text:SetTextColor(color[1], color[2], color[3])
    text:SetJustifyH("LEFT")
    return text
end

local page  -- (built the first time it's opened, beside the catch log)
local function Build()
    page = CreateFrame("Frame", nil, F.panel, "BackdropTemplate")
    page:SetSize(260, 300)
    page:SetPoint("TOPLEFT", F.panel, "TOPRIGHT", 6, 0)
    page:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 14, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    page:SetBackdropColor(0.93, 0.87, 0.72, 0.97)
    page:SetBackdropBorderColor(0.42, 0.28, 0.14)
    local close = CreateFrame("Button", nil, page, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    close:SetScript("OnClick", function() page:Hide() end)
    page.where = Ink(page, 18, INK)
    page.where:SetPoint("TOPLEFT", 14, -12)
    page.where:SetText("Where to fish")
    page.zone = Ink(page, 13, INK)
    page.zone:SetPoint("TOPLEFT", 14, -36)
    page.zone:SetWidth(232)
    page.zone:SetSpacing(2)
    page.zones = Ink(page, 12, INK_DIM)
    page.zones:SetPoint("TOPLEFT", page.zone, "BOTTOMLEFT", 0, -6)
    page.zones:SetWidth(232)
    page.cook = Ink(page, 18, INK)
    page.cook:SetPoint("TOPLEFT", page.zones, "BOTTOMLEFT", 0, -12)
    page.cook:SetText("Cooking your catch")
    page.rows = {}
    for i = 1, #FISH do
        local row = Ink(page, 12, INK)
        row:SetPoint("TOPLEFT", page.cook, "BOTTOMLEFT", 0, -6 - (i - 1) * 15)
        row:SetWidth(232)
        row:SetWordWrap(false)
        page.rows[i] = row
    end
    page.cookSkill = Ink(page, 12, INK_DIM)
    page.cookSkill:SetPoint("BOTTOMLEFT", 14, 12)
end

local function Refresh()
    local fishing = Skill(356)
    local zone = GetRealZoneText and GetRealZoneText() or ""
    local need = ZONES[zone]
    -- (this zone, and what it means for your skill)
    local lines = { ("Your fishing: %s"):format(fishing and tostring(fishing) or "not learnt yet - any fishing trainer") }
    if need then
        lines[#lines + 1] = ("%s: fish stop getting away at about %d."):format(zone, need)
        if fishing and fishing >= need then lines[#lines + 1] = "|cff2e6b1fYou'll land everything here.|r"
        elseif fishing and fishing >= need - 95 then lines[#lines + 1] = "|cff9a5a10Some will slip off the hook. A lure helps.|r"
        elseif fishing then lines[#lines + 1] = "|cff9a1f14Too hard for now: most get away.|r" end
        if need > 300 then lines[#lines + 1] = "|cff806650(above 300: it takes a better pole and a lure)|r" end
    else
        lines[#lines + 1] = ("%s: no numbers for these waters."):format(zone ~= "" and zone or "Here")
    end
    page.zone:SetText(table.concat(lines, "\n"))
    -- (the zones that suit you now: fish don't get away, the hardest first)
    if fishing then
        local good = {}
        for name, z in pairs(ZONES) do
            if z <= fishing and z >= fishing - 80 then good[#good + 1] = name end
        end
        table.sort(good, function(a, b) if ZONES[a] ~= ZONES[b] then return ZONES[a] > ZONES[b] end return a < b end)
        page.zones:SetText(#good > 0 and ("Good for you now: " .. table.concat(good, ", ", 1, math.min(#good, 8))) or "")
    else
        page.zones:SetText("")
    end
    -- (the fish worth cooking: caught ones ticked, the ones your cooking can do now in ink, the rest faded)
    local cooking = Skill(185)
    for i, fish in ipairs(FISH) do
        local caught = F.Caught and F.Caught(fish[1]) or 0
        local canCook = cooking and cooking >= fish[3]
        page.rows[i]:SetText(("%s %s -> %s  (cooking %d)"):format(caught > 0 and "|cff2e6b1f[x]|r" or "[ ]", fish[1]:gsub("^Raw ", ""):gsub("^Large Raw ", "Large "), fish[2], fish[3]))
        local ink = canCook and INK or INK_DIM
        page.rows[i]:SetTextColor(ink[1], ink[2], ink[3])
    end
    page.cookSkill:SetText(cooking and ("Your cooking: %d. Recipes from cooking trainers and vendors."):format(cooking) or "Cooking not learnt yet - any cooking trainer.")
end

-- Reginald's word on where you stand.
local function Remark()
    local fishing, zone = Skill(356), GetRealZoneText and GetRealZoneText() or ""
    local need = ZONES[zone]
    if not fishing then return "One cannot fish without learning to, sir. A trainer, perhaps." end
    if need and fishing >= need then return "These waters are beneath you. Splendid." end
    if need and fishing < need - 95 then return "Ambitious. The fish here will laugh at you." end
    if need then return "Some will get away. Do try to look as if you meant it." end
    return "Uncharted waters. How adventurous."
end

function F.ToggleGuide()
    if not page then Build() end
    if page:IsShown() then page:Hide() return end
    F.Open()
    Refresh()
    page:Show()
    if F.Say then F.Say(Remark()) end
end
-- (kept current while it's open: a catch, a new zone, a skill point)
local events = CreateFrame("Frame")
for _, e in ipairs({ "LOOT_CLOSED", "ZONE_CHANGED_NEW_AREA", "SKILL_LINES_CHANGED" }) do events:RegisterEvent(e) end
events:SetScript("OnEvent", function() if page and page:IsShown() then Refresh() end end)
