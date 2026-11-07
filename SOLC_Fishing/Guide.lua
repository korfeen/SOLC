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
-- Alliance and neutral recipe vendors: name, town, zone, and x, y where Classic coordinates are known (those can be
-- pinned on the map; the rest are named only - their wiki coordinates are from the modern game, where towns moved).
local THARYNN = { "Tharynn Bouden", "Goldshire", "Elwynn Forest", 41.9, 67.1 }
local KHARA = { "Khara Deepwater", "the Loch", "Loch Modan", 40, 39 }
-- The fish worth cooking on the way up: the raw fish, the dish, the cooking skill its recipe is learnt at, and who
-- sells the recipe.
local FISH = {
    { "Raw Brilliant Smallfish", "Brilliant Smallfish", 1, { THARYNN, KHARA } },
    { "Raw Longjaw Mud Snapper", "Longjaw Mud Snapper", 50, { THARYNN, KHARA } },
    { "Raw Bristle Whisker Catfish", "Bristle Whisker Catfish", 100,
        { { "Lindea Rabonne", "Southshore", "Hillsbrad Foothills" }, { "Catherine Leland", "the Canals", "Stormwind City" } } },
    { "Raw Mithril Head Trout", "Cooked Mithril Head Trout", 175,
        { { "Stuart Fleming", "Menethil Harbor", "Wetlands", 6.3, 57.4 }, { "Heldan Galesong", "the coast", "Darkshore", 37.0, 56.4 } } },
    { "Raw Spotted Yellowtail", "Spotted Yellowtail", 225, { { "Gikkix", "Steamwheedle Port", "Tanaris" } } },
    { "Large Raw Mightfish", "Mightfish Steak", 275,
        { { "Kelsey Yance", "Booty Bay", "Stranglethorn Vale" }, { "Vivianna", "Feathermoon", "Feralas" } } },
}

-- A zone's map by its name: searched under the world the player stands in.
local function FindMap(zone)
    if not (C_Map and C_Map.GetMapInfo and C_Map.GetMapChildrenInfo) then return end
    local id, root = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    while id do
        local info = C_Map.GetMapInfo(id)
        if not info then break end
        root = id
        if not info.parentMapID or info.parentMapID == 0 then break end
        id = info.parentMapID
    end
    for _, top in ipairs({ root, 947, 1414, 1415 }) do
        for _, child in ipairs(C_Map.GetMapChildrenInfo(top, Enum.UIMapType.Zone, true) or {}) do
            if child.name == zone then return child.mapID end
        end
    end
end

-- A vendor pinned on the world map (WoW's own map pin, tracked on screen); in chat if the map can't take it.
local function Pin(vendor)
    local name, town, zone, x, y = unpack(vendor)
    local map = FindMap(zone)
    if map and C_Map.SetUserWaypoint and UiMapPoint
        and (not C_Map.CanSetUserWaypointOnMap or C_Map.CanSetUserWaypointOnMap(map)) then
        C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(map, x / 100, y / 100))
        if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
        if F.Say then F.Say(("%s, %s. I've marked it on your map, sir. Do try not to get lost."):format(name, town)) end
    else
        print(("|cffd4a017SOLC Fishing:|r %s, %s in %s, at %.1f, %.1f."):format(name, town, zone, x, y))
    end
end

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
local W, PAD, TEXT_W = 320, 16, 288
local function Build()
    page = CreateFrame("Frame", nil, F.panel, "BackdropTemplate")
    page:SetSize(W, 440)
    page:SetPoint("TOPLEFT", F.panel, "TOPRIGHT", 6, 0)
    page:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 14, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    page:SetBackdropColor(0.93, 0.87, 0.72, 1)
    page:SetBackdropBorderColor(0.42, 0.28, 0.14)
    local close = CreateFrame("Button", nil, page, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    close:SetScript("OnClick", function() page:Hide() end)
    page.where = Ink(page, 20, INK)
    page.where:SetText("Where to fish")
    page.zone = Ink(page, 15, INK)
    page.zone:SetWidth(TEXT_W)
    page.zone:SetSpacing(3)
    page.zones = Ink(page, 14, INK_DIM)
    page.zones:SetWidth(TEXT_W)
    page.zones:SetSpacing(2)
    page.cook = Ink(page, 20, INK)
    page.cook:SetText("Cooking your catch")
    page.rows = {}
    for i, fish in ipairs(FISH) do
        page.rows[i] = { fish = Ink(page, 15, INK), dish = Ink(page, 13, INK_DIM), vendors = {} }
        page.rows[i].fish:SetWidth(TEXT_W)
        page.rows[i].dish:SetWidth(TEXT_W - 22)
        -- (each vendor a line: the ones with a known spot in red ink, click to pin them on the map)
        for j, vendor in ipairs(fish[4]) do
            local line = CreateFrame("Button", nil, page)
            line.text = Ink(line, 13, vendor[4] and RED_INK or INK_DIM)
            line.text:SetPoint("TOPLEFT")
            line.text:SetWidth(TEXT_W - 30)
            line.text:SetText(("%s, %s (%s)%s"):format(vendor[1], vendor[2], vendor[3], vendor[4] and " - pin it" or ""))
            line:SetSize(TEXT_W - 30, line.text:GetStringHeight())
            if vendor[4] then
                line:SetScript("OnClick", function() Pin(vendor) end)
                line:SetScript("OnEnter", function() line.text:SetAlpha(0.65) end)
                line:SetScript("OnLeave", function() line.text:SetAlpha(1) end)
            end
            page.rows[i].vendors[j] = line
        end
    end
    page.cookSkill = Ink(page, 13, INK_DIM)
    page.cookSkill:SetWidth(TEXT_W)
end

-- (the page laid out from the top down, each block under the last by its own height: nothing piles up)
local function Place(text, y, x)
    text:ClearAllPoints()
    text:SetPoint("TOPLEFT", page, "TOPLEFT", x or PAD, -y)
    return y + math.max(1, text:GetStringHeight() or 0)
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
    local good = {}
    if fishing then
        for name, z in pairs(ZONES) do
            if z <= fishing and z >= fishing - 80 then good[#good + 1] = name end
        end
        table.sort(good, function(a, b) if ZONES[a] ~= ZONES[b] then return ZONES[a] > ZONES[b] end return a < b end)
    end
    page.zones:SetText(#good > 0 and ("Good for you now: " .. table.concat(good, ", ", 1, math.min(#good, 8))) or "")
    -- (the fish worth cooking: caught ones ticked, the ones your cooking can do now in ink, the rest faded)
    local cooking = Skill(185)
    for i, fish in ipairs(FISH) do
        local row = page.rows[i]
        local caught = (F.Caught and F.Caught(fish[1]) or 0) > 0
        local name = fish[1]:gsub("^Large Raw ", "Large "):gsub("^Raw ", "")
        row.fish:SetText((caught and "|cff2e6b1f[x]|r " or "[  ] ") .. name)
        row.dish:SetText(("cooks into %s, at cooking %d"):format(fish[2], fish[3]))
        local ink = (cooking and cooking >= fish[3]) and INK or INK_DIM
        row.fish:SetTextColor(ink[1], ink[2], ink[3])
    end
    page.cookSkill:SetText((cooking and ("Your cooking: %d."):format(cooking) or "Cooking not learnt yet - any cooking trainer.")
        .. " Under each dish: who sells its recipe. Click a red one to pin it on your map.")
    -- (laid out top to bottom)
    local y = 14
    y = Place(page.where, y) + 8
    y = Place(page.zone, y) + 8
    if #good > 0 then y = Place(page.zones, y) + 6 end
    y = y + 8
    y = Place(page.cook, y) + 8
    for _, row in ipairs(page.rows) do
        y = Place(row.fish, y) + 1
        y = Place(row.dish, y, PAD + 22) + 2
        for _, line in ipairs(row.vendors) do
            line:ClearAllPoints()
            line:SetPoint("TOPLEFT", page, "TOPLEFT", PAD + 30, -y)
            local h = math.max(12, line.text:GetStringHeight() or 0)
            line:SetHeight(h)
            y = y + h + 1
        end
        y = y + 5
    end
    y = Place(page.cookSkill, y + 4) + 14
    page:SetHeight(y)
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
