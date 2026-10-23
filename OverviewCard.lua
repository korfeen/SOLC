-- The Overview (ME). A split page (ProfileHeader.lua: the profile header over the left page, the middle
-- beam). In the left slot, under its tabs: ME (LEFT, from the designer's REFPIC_LEFT_SCREEN_OVERVIEW): their three
-- showcase pictures and what happened to them lately; GEARZ: their stats, their gear round their character on the right
-- page; CRAFTS: their professions, the one picked and its recipes filling the right page. On the right page (RIGHT)
-- otherwise: their photo, filling it down to a cross beam with their first name on.
-- The photo (ME) is the ogre they built (Minting.lua: their avatar; the showcase is for their lucky mints). With none
-- built: for you a big MAKE YOUR OGRE (the builder); for someone else the picture they chose, else their first showcase
-- picture, else their newest, else their character. Characters are on GEARZ (their gear round them).
-- KillTrackerDB.card = { gender = "MALE" | "FEMALE" | "NONBINARY" (no longer shown), portrait = picture number, seq },
-- synced (Sync.lua, the card section).

local _, ns = ...
-- Shorter names for the long layer labels, for a trait that doesn't fit even in a smaller font.
local SHORT_LABELS = { Background = "Back", Expression = "Face", Accessory = "Extra", Headwear = "Hat" }
local UI = ns.UI
local Fit, SetTooltip = UI.FitText, UI.Tooltip

local ART = "Interface\\AddOns\\SOLC\\Media\\Overview\\"
local NAME_FONT = "Interface\\AddOns\\SOLC\\Media\\Fonts\\GermaniaOne-Regular.ttf"
local SIGN_FONT = "Interface\\AddOns\\SOLC\\Media\\Fonts\\FingerPaint-Regular.ttf"
local FEED_COLOR = { 0.93, 0.88, 0.78 }      -- cream
-- The small icon at the start of a line, by the event's kind (Feed.lua); a picture's line shows the picture itself.
local FEED_ICON = "Interface\\AddOns\\SOLC\\Media\\Icons\\Feed_"  -- the feed's own crayon icons (tools/make-role-icons.js)
local FEED_ICONS = {
    L = "Leader",       -- a leader slain
    R = "Rare",         -- a rare found
    A = "Achievement",
    M = "Mint",         -- a picture minted (shown as the picture itself while they still have it)
    W = "Won",          -- a picture won in a puzzle race
    B = "Bounty",
    D = "Boss",         -- a boss with the guild
}
local EDGE_FILL = 60 / 64                    -- Media/Overview/Edge's square
local GEAR_PANEL = { left = 247, top = 327, width = 370, height = 397 }  -- GEARZ and CRAFTS, in the left slot (window pixels)
local TABS = {  -- { panel (nil: ME), label, ogre word }
    { nil, "ME", "ME" },
    { "gear", "GEARZ", "GEARZ" },
    { "crafts", "CRAFTS", "MAKE" },
}
-- The tabs' names on the top beam (ns.UI.SetTab; ME: nothing added) and in ogre mode.
local TAB_TITLES, TABS_OGRE = { gear = "Gear", crafts = "Crafts" }, { gear = "GEARZ", crafts = "MAKE" }
-- The ME tab on someone else's Overview: their pronoun, by the gender on their card (UI.Profile), THEY if unknown.
local PRONOUNS = { MALE = "HE", FEMALE = "SHE", NONBINARY = "THEY" }

-- The left slot, in window pixels (from the window's top-left, y down): flat colours for now, the heading a cross beam.
local LEFT = {
    left = 237, right = 627, bottom = 730,
    tabs = { top = 285, bottom = 319, size = 17 },
    bands = {  -- top to bottom, from under the header's strip: { bottom, r, g, b }, or { bottom, beam = true }
        { 319, 0.16, 0.11, 0.08, top = 280 },  -- the tabs
        { 452, 0.03, 0.03, 0.03 },             -- the pictures
        { 494, beam = true },                  -- the feed's heading
        { 750, 0.1, 0.1, 0.1 },                -- the feed
    },
    pictures = { lefts = { 242, 371, 500 }, top = 325, size = 122, rim = 2 },
    heading = { x = 247, y = 473, size = 22, text = "WHAT HAPPEN TO ME?" },
    feed = { top = 494, rowHeight = 24, textSize = 13, iconSize = 18, colors = { 0.25, 0.18 } },
}
-- The right page, in window pixels: the board, the photo (its centre; from the top beam down, its sides under the middle
-- beam and the post), the cross beam under it (its top; UI.PhotoBeam) and the name written on it.
local RIGHT = {
    color = { 0.094, 0.094, 0.094 },
    photo = { x = 869, y = 393, w = 396, h = 494 },
    beam = 634,
    -- A picture as the photo: laid out as on the Pictures page (PixPage.lua's RIGHT): square, the beam under it, its
    -- rarity and number under that, then its traits in two columns.
    square = { y = 344, beam = 536, rarity = 594, traits = { top = 612, lefts = { 690, 878 }, line = 16, size = 12 } },
    plaque = { w = UI.PHOTO_NAME_WIDTH, size = 22 },
}
local CRAFT_ROW = { height = 24, size = 13, colors = { 0.25, 0.18 } }  -- CRAFTS' rows
local HEADING_COLOR = { 1, 0.85, 0.1 }
local FEED_AGO_COLOR = { 0.98, 0.64, 0.26 }
local FEED_HOVER_COLOR = { 0.65, 0.53, 0.28 }  -- the row under the mouse
local FEED_OPEN_COLOR = { 0.42, 0.3, 0.12 }    -- the row whose details are open

-- Right-clicking your own character (GEARZ): the background behind it (from the ones on your pictures).
local function PhotoMenu(owner)
    if not MenuUtil then return UI.PickBackdrop(owner) end  -- no menus: step through the backgrounds
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle("Background behind my character")
        local background = root
        local function IsCurrent(id) return (KillTrackerDB.showcase and KillTrackerDB.showcase.backdrop) == id end
        background:CreateRadio("None", function() return IsCurrent(nil) end, function() ns.SetModelBackdrop(nil) end)
        local owned = ns.OwnedBackgrounds()
        for _, option in ipairs(owned) do
            local name = ("|c%s%s|r"):format(ns.RARITY_COLORS[option.rarity] or "ffffffff", option.name)
            background:CreateRadio(name, function() return IsCurrent(option.id) end, function() ns.SetModelBackdrop(option.id) end)
        end
        if #owned == 0 then background:CreateTitle("Mint a picture to get backgrounds") end
    end)
end

-- GEARZ: a character sheet over both pages. Left: their average item level and the stats their gear adds up to.
-- Right: their character (never a picture while it's open) with their gear round it like the game's character sheet:
-- a column of slots down each side, the weapons in a row at the bottom; each icon on a rim in the item's quality colour.
-- Hover for the item, shift-click to link it. page: the Overview page; returns a frame with :SetPlayer(key).
local GEAR_LEFT = { 1, 2, 3, 15, 5, 4, 19, 9 }
local GEAR_RIGHT = { 10, 6, 7, 8, 11, 12, 13, 14 }
local GEAR_WEAPONS = { 16, 17, 18 }
-- The slots on the right page, in window pixels: their size and spacing, the columns' outer edges, the weapons' row.
local GEAR_SLOTS = { size = 38, row = 46, top = 172, left = 684, right = 1054, weapons = 580, weaponGap = 10 }
local GEAR_STAT_LINES = 24
local QUALITY_GREY = { 0.35, 0.35, 0.35 }
local RIM = 1  -- the quality colour round a slot's icon, pixels
-- An item quality's colour (the API moved under C_Item; ITEM_QUALITY_COLORS as a fallback).
local function QualityColor(quality)
    local get = C_Item and C_Item.GetItemQualityColor or GetItemQualityColor
    if get then
        local r, g, b = get(quality)
        if r then return r, g, b end
    end
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if c then return c.r, c.g, c.b end
    return unpack(QUALITY_GREY)
end

-- The backing of a panel over the left slot (GEARZ, CRAFTS): solid, from under the tabs to the bottom and from wood
-- to wood (it runs on under them, UI.SPLIT.under), so nothing of the ME page behind shows.
local function PanelBacking(panel)
    local under = UI.SPLIT.under
    local backing = panel:CreateTexture(nil, "BACKGROUND", nil, -8)
    backing:SetPoint("TOPLEFT", UI.window, "TOPLEFT", under.left, -LEFT.tabs.bottom)
    backing:SetPoint("BOTTOMRIGHT", UI.window, "TOPLEFT", under.middle, -under.bottom)
    backing:SetColorTexture(0.05, 0.03, 0.02)
end

local function Heading(parent, size)
    local text = parent:CreateFontString(nil, "OVERLAY")
    text:SetFont(NAME_FONT, size, "")
    text:SetTextColor(1, 0.82, 0.25)
    UI.OutlineText(text, { 0, 0, 0 })
    return text
end

local function GearPage(page)
    local gear = CreateFrame("Frame", nil, page)
    gear:SetPoint("TOPLEFT", UI.window, "TOPLEFT", GEAR_PANEL.left, -GEAR_PANEL.top)
    gear:SetSize(GEAR_PANEL.width, GEAR_PANEL.height)
    PanelBacking(gear)

    -- Left: the average item level, then the stats in two columns.
    gear.average = Heading(gear, 20)
    gear.average:SetPoint("TOPLEFT", 4, -4)
    local statsTitle = Heading(gear, 15)
    statsTitle:SetPoint("TOPLEFT", 4, -40)
    statsTitle:SetText("Stats from gear")
    gear.statLines = {}
    for i = 1, GEAR_STAT_LINES do
        local line = gear:CreateFontString(nil, "OVERLAY")
        line:SetFont(NAME_FONT, 13, "")
        line:SetTextColor(unpack(FEED_COLOR))
        line:SetPoint("TOPLEFT", 4 + ((i - 1) % 2) * (GEAR_PANEL.width / 2), -62 - math.floor((i - 1) / 2) * 19)
        line:SetWidth(GEAR_PANEL.width / 2 - 8)
        line:SetJustifyH("LEFT")
        line:SetWordWrap(false)
        gear.statLines[i] = line
    end
    gear.empty = gear:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    gear.empty:SetPoint("TOP", 0, -80)
    gear.empty:SetWidth(GEAR_PANEL.width - 20)
    gear.empty:SetText("No gear synced yet. It shows once they log in with SOLC 0.37.0 or newer.")

    -- Right: the slots round the photo, over the model (under the photo's frame).
    local around = CreateFrame("Frame", nil, page)
    around:SetAllPoints()
    around:SetFrameLevel(page.photo:GetFrameLevel() + 5)
    around:Hide()
    gear.around = around
    local S = GEAR_SLOTS
    local slots = {}
    local function Slot(slot, x, y)
        local cell = CreateFrame("Button", nil, around)
        cell:SetSize(S.size, S.size)
        cell:SetPoint("TOPLEFT", UI.window, "TOPLEFT", x, -y)
        cell.slot = slot
        cell.rim = cell:CreateTexture(nil, "BACKGROUND")
        cell.rim:SetTexture(ART .. "Edge")
        cell.rim:SetPoint("CENTER")
        cell.rim:SetSize((S.size + 2 * RIM) / EDGE_FILL, (S.size + 2 * RIM) / EDGE_FILL)
        cell.icon = cell:CreateTexture(nil, "ARTWORK")
        cell.icon:SetPoint("TOPLEFT", 1, -1)
        cell.icon:SetPoint("BOTTOMRIGHT", -1, 1)
        cell.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        cell:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if not self.item then
                GameTooltip:AddLine(_G[UI.GEAR_SLOT_NAMES[self.slot]] or "Empty", 0.6, 0.6, 0.6)
            elseif gear.key then
                GameTooltip:SetHyperlink(self.item)
            else
                GameTooltip:SetInventoryItem("player", self.slot)
            end
            GameTooltip:Show()
        end)
        cell:SetScript("OnLeave", GameTooltip_Hide)
        cell:SetScript("OnClick", function(self)
            if self.item and IsModifiedClick("CHATLINK") then
                local _, link = GetItemInfo(self.item)
                if link then ChatEdit_InsertLink(link) end
            end
        end)
        slots[#slots + 1] = cell
    end
    for i, slot in ipairs(GEAR_LEFT) do Slot(slot, S.left, S.top + (i - 1) * S.row) end
    for i, slot in ipairs(GEAR_RIGHT) do Slot(slot, S.right - S.size, S.top + (i - 1) * S.row) end
    local middle = (S.left + S.right) / 2
    for i, slot in ipairs(GEAR_WEAPONS) do
        Slot(slot, middle - S.size / 2 + (i - 2) * (S.size + S.weaponGap), S.weapons)
    end

    function gear:Refresh()
        local data = UI.GearData(self.key)
        self.empty:SetShown(not data.has)
        self.average:SetText(data.average and ("Item level %d"):format(data.average) or "")
        for _, cell in ipairs(slots) do
            local item = data.slots[cell.slot]
            cell:SetShown(data.has)
            cell.item = item and item.item
            if item then
                cell.icon:SetTexture(item.texture or "Interface\\Icons\\INV_Misc_QuestionMark")
                cell.icon:SetDesaturated(false)
                local r, g, b = unpack(QUALITY_GREY)
                if item.quality then r, g, b = QualityColor(item.quality) end
                cell.rim:SetVertexColor(r, g, b)
            else
                local emptyTexture = GetInventorySlotInfo and select(2, GetInventorySlotInfo(UI.GEAR_SLOT_NAMES[cell.slot]))
                cell.icon:SetTexture(emptyTexture)
                cell.icon:SetDesaturated(true)
                cell.rim:SetVertexColor(unpack(QUALITY_GREY))
            end
        end
        for i, line in ipairs(self.statLines) do
            local stat = data.stats[i]
            line:SetText(stat and ("|cff40ff40+%d|r %s"):format(stat[2], stat[1]) or (i == 1 and data.loading and "loading items..." or ""))
            line:SetShown(data.has)
        end
    end
    function gear:SetPlayer(key)
        self.key = key
        if self:IsShown() then self:Refresh() end
    end
    -- Item info arrives later for items this client hasn't seen yet; your own gear can change while open.
    local pending
    gear:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    gear:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    gear:SetScript("OnEvent", function(self)
        if not self:IsVisible() or pending then return end
        pending = true
        C_Timer.After(0.2, function()
            pending = nil
            if self:IsVisible() then self:Refresh() end
        end)
    end)
    gear:SetScript("OnShow", function(self) around:Show() self:Refresh() end)
    gear:SetScript("OnHide", function() around:Hide() end)
    return gear
end

-- CRAFTS: their professions on the left page, a row each with its skill; the one picked (the first at the start)
-- fills the right page instead of the photo: its icon, name and skill over a cross beam, the recipes they know of it
-- under it. page: the Overview page; returns a frame with :SetPlayer(key).
local CRAFT_RIGHT = {  -- window pixels
    icon = { x = 690, y = 166, size = 56 },
    text = 760, name = 170, skill = 200, bar = { top = 222, right = 1044, height = 18 },
    beam = 262, list = 308,
}
local PROFESSION_ART = "Interface\\AddOns\\SOLC\\Media\\Overview\\Professions\\"
-- A skill bar: a wooden rim, a dark track, the fill a gradient with a shine along its top (blue, gold once at the
-- cap), notches at every rank step (each 75 skill) and the numbers on it. bar:Set(rank, max).
local SKILL_STEP = 75
local SKILL_FILL = { { 0.1, 0.3, 0.72 }, { 0.42, 0.74, 1 } }      -- bottom, top
local SKILL_FULL = { { 0.72, 0.45, 0.05 }, { 1, 0.86, 0.32 } }
local function Gradient(texture, colors, alpha)
    texture:SetTexture("Interface\\Buttons\\WHITE8X8")
    texture:SetGradient("VERTICAL", CreateColor(colors[1][1], colors[1][2], colors[1][3], alpha or 1),
        CreateColor(colors[2][1], colors[2][2], colors[2][3], alpha or 1))
end
local function SkillBar(parent, x, y, w, h)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetSize(w, h)
    bar:SetPoint("TOPLEFT", UI.window, "TOPLEFT", x, -y)
    local rim = bar:CreateTexture(nil, "BORDER", nil, 0)
    rim:SetPoint("TOPLEFT", -2, 2)
    rim:SetPoint("BOTTOMRIGHT", 2, -2)
    Gradient(rim, { { 0.3, 0.2, 0.11 }, { 0.62, 0.45, 0.27 } })
    local edge = bar:CreateTexture(nil, "BORDER", nil, 1)
    edge:SetPoint("TOPLEFT", -1, 1)
    edge:SetPoint("BOTTOMRIGHT", 1, -1)
    edge:SetColorTexture(0.02, 0.01, 0.01)
    local track = bar:CreateTexture(nil, "BORDER", nil, 2)
    track:SetAllPoints()
    Gradient(track, { { 0.12, 0.1, 0.09 }, { 0.04, 0.03, 0.03 } })
    bar.fill = bar:CreateTexture(nil, "ARTWORK", nil, 0)
    bar.fill:SetPoint("TOPLEFT")
    bar.fill:SetPoint("BOTTOMLEFT")
    local shine = bar:CreateTexture(nil, "ARTWORK", nil, 1)
    shine:SetPoint("TOPLEFT", bar.fill, "TOPLEFT", 0, -1)
    shine:SetPoint("TOPRIGHT", bar.fill, "TOPRIGHT", 0, -1)
    shine:SetHeight(math.max(1, math.floor(h / 3)))
    shine:SetColorTexture(1, 1, 1, 0.22)
    bar.notches = {}
    for i = 1, 6 do
        local notch = bar:CreateTexture(nil, "ARTWORK", nil, 2)
        notch:SetSize(2, h)
        notch:SetColorTexture(0.02, 0.01, 0.01, 0.75)
        bar.notches[i] = notch
    end
    bar.text = bar:CreateFontString(nil, "OVERLAY")
    bar.text:SetFont(NAME_FONT, math.max(9, h - 5), "")
    bar.text:SetPoint("CENTER", 0, 1)
    bar.text:SetTextColor(1, 1, 1)
    UI.OutlineText(bar.text, { 0, 0, 0 })
    function bar:Set(rank, max)
        rank, max = rank or 0, math.max(1, max or 1)
        local share = math.min(1, rank / max)
        self.fill:SetWidth(math.max(1, w * share))
        self.fill:SetShown(rank > 0)
        shine:SetShown(rank > 0)
        Gradient(self.fill, rank >= max and SKILL_FULL or SKILL_FILL)
        for i, notch in ipairs(self.notches) do
            local at = i * SKILL_STEP
            notch:SetShown(at < max)
            notch:SetPoint("LEFT", w * at / max - 1, 0)
        end
        self.text:SetText(("%d / %d"):format(rank, max))
    end
    return bar
end
-- A profession's rank by its cap.
local SKILL_RANKS = { [75] = "Apprentice", [150] = "Journeyman", [225] = "Expert", [300] = "Artisan" }

local CRAFT_PICKED = { 0.42, 0.3, 0.12 }  -- the picked profession's row

-- A list's row running from wood to wood (left .. right, window pixels, under the wood) with its content inside
-- (inLeft .. inRight): stripe, icon, label, count on the right, a bar along the bottom.
local function CraftRow(parent, left, right, inLeft, inRight, y, i)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(right - left, CRAFT_ROW.height)
    row:SetPoint("TOPLEFT", UI.window, "TOPLEFT", left, -y)
    row.tone = CRAFT_ROW.colors[i % 2 == 1 and 1 or 2]
    row.stripe = row:CreateTexture(nil, "BACKGROUND")
    row.stripe:SetAllPoints()
    row.barWidth = inRight - inLeft
    row.track = row:CreateTexture(nil, "BORDER", nil, 0)  -- the skill bar along the bottom (SkillBar's colours)
    row.track:SetPoint("BOTTOMLEFT", inLeft - left, 1)
    row.track:SetSize(row.barWidth, 4)
    row.track:SetColorTexture(0, 0, 0, 0.6)
    row.bar = row:CreateTexture(nil, "BORDER", nil, 1)
    row.bar:SetPoint("BOTTOMLEFT", row.track)
    row.bar:SetHeight(4)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(18, 18)
    row.icon:SetPoint("LEFT", inLeft - left + 4, 0)
    row.count = row:CreateFontString(nil, "OVERLAY")
    row.count:SetFont(NAME_FONT, CRAFT_ROW.size, "")
    row.count:SetTextColor(unpack(FEED_AGO_COLOR))
    row.count:SetPoint("RIGHT", -(right - inRight + 6), 1)
    row.label = row:CreateFontString(nil, "OVERLAY")
    row.label:SetFont(NAME_FONT, CRAFT_ROW.size, "")
    row.label:SetTextColor(0.94, 0.94, 0.94)
    row.label:SetPoint("LEFT", inLeft - left + 28, 1)
    row.label:SetPoint("RIGHT", row.count, "LEFT", -8, 0)
    row.label:SetJustifyH("LEFT")
    row.label:SetWordWrap(false)
    function row:Paint()
        local color = self.hovered and FEED_HOVER_COLOR or self.picked and CRAFT_PICKED or { self.tone, self.tone, self.tone }
        self.stripe:SetColorTexture(unpack(color))
    end
    row:SetScript("OnLeave", function(self)
        self.hovered = false
        self:Paint()
        GameTooltip_Hide()
    end)
    row:Paint()
    return row
end

local function CraftsPage(page)
    local split = UI.SPLIT
    local crafts = CreateFrame("Frame", nil, page)
    crafts:SetPoint("TOPLEFT", UI.window, "TOPLEFT", GEAR_PANEL.left, -GEAR_PANEL.top)
    crafts:SetSize(GEAR_PANEL.width, GEAR_PANEL.height)
    PanelBacking(crafts)

    -- Left: the professions.
    crafts.rows = {}
    for i = 1, math.floor(GEAR_PANEL.height / CRAFT_ROW.height) do
        local row = CraftRow(crafts, split.under.left, split.under.middle, GEAR_PANEL.left, GEAR_PANEL.left + GEAR_PANEL.width,
            GEAR_PANEL.top + (i - 1) * CRAFT_ROW.height, i)
        row:SetScript("OnEnter", function(self)
            local prof = self.prof
            if not prof then return end
            self.hovered = true
            self:Paint()
            SetTooltip(self, { prof.name, ("Skill %d / %d"):format(prof.rank or 0, prof.max or 0), "Click for the recipes" })
        end)
        row:SetScript("OnClick", function(self)
            if not self.prof then return end
            UI.ClickSound()
            crafts.line, crafts.offset = self.prof.line, 0
            crafts:Refresh()
        end)
        crafts.rows[i] = row
    end
    crafts.empty = crafts:CreateFontString(nil, "OVERLAY")
    crafts.empty:SetFont(NAME_FONT, 13, "")
    crafts.empty:SetTextColor(0.62, 0.56, 0.48)
    crafts.empty:SetPoint("TOP", 0, -60)
    crafts.empty:SetWidth(GEAR_PANEL.width - 30)

    -- Right: over the photo's place (it hides while CRAFTS is open), on a board of its own.
    local C = CRAFT_RIGHT
    local right = CreateFrame("Frame", nil, page)
    right:SetAllPoints()
    right:SetFrameLevel(page.photo:GetFrameLevel() + 5)
    right:EnableMouseWheel(true)
    right:Hide()
    crafts.right = right
    local board = right:CreateTexture(nil, "BACKGROUND", nil, -8)
    board:SetPoint("TOPLEFT", UI.window, "TOPLEFT", split.under.middle, -split.under.top)
    board:SetPoint("BOTTOMRIGHT", UI.window, "TOPLEFT", split.under.right, -split.under.bottom)
    board:SetColorTexture(0.05, 0.03, 0.02)
    -- The info's part: the profession's crayon background (tools/make-profession-backgrounds.js; 2:1, cropped to the
    -- strip), darkened most on the left where the words go; a plain lighter brown for one without art.
    local top = right:CreateTexture(nil, "BACKGROUND", nil, -7)
    top:SetPoint("TOPLEFT", board)
    top:SetPoint("BOTTOMRIGHT", UI.window, "TOPLEFT", split.under.right, -C.beam - 10)
    top:SetColorTexture(0.16, 0.11, 0.08)
    right.art = right:CreateTexture(nil, "BACKGROUND", nil, -6)
    right.art:SetAllPoints(top)
    local stripW, stripH = split.under.right - split.under.middle, C.beam + 10 - split.under.top
    local cut = (1 - 2 * stripH / stripW) / 2
    right.art:SetTexCoord(0, 1, cut, 1 - cut)
    right.shade = right:CreateTexture(nil, "BACKGROUND", nil, -5)
    right.shade:SetAllPoints(top)
    right.shade:SetTexture("Interface\\Buttons\\WHITE8X8")
    right.shade:SetGradient("HORIZONTAL", CreateColor(0, 0, 0, 0.85), CreateColor(0, 0, 0, 0.3))
    local function At(region, point, x, y) region:SetPoint(point, UI.window, "TOPLEFT", x, -y) end
    right.icon = right:CreateTexture(nil, "ARTWORK")
    right.icon:SetSize(C.icon.size, C.icon.size)
    At(right.icon, "TOPLEFT", C.icon.x, C.icon.y)
    right.name = Heading(right, 22)
    At(right.name, "TOPLEFT", C.text, C.name)
    UI.OutlineText(right.name, { 0, 0, 0 })
    right.skill = right:CreateFontString(nil, "OVERLAY")
    right.skill:SetFont(NAME_FONT, 15, "")
    right.skill:SetTextColor(unpack(FEED_COLOR))
    UI.OutlineText(right.skill, { 0, 0, 0 })
    At(right.skill, "TOPLEFT", C.text, C.skill)
    right.bar = SkillBar(right, C.text, C.bar.top, C.bar.right - C.text, C.bar.height)
    UI.CrossBeam(right, split.right.left, split.right.right, C.beam)

    -- The recipes under the beam, from wood to wood.
    right.rows = {}
    for i = 1, math.floor((split.right.bottom - C.list) / CRAFT_ROW.height) do
        local row = CraftRow(right, split.under.middle, split.under.right, split.right.left + 8, split.right.right - 8,
            C.list + (i - 1) * CRAFT_ROW.height, i)
        row.bar:Hide()
        row.track:Hide()
        row:SetScript("OnEnter", function(self)
            if not self.recipe then return end
            self.hovered = true
            self:Paint()
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetSpellByID(self.recipe)
            GameTooltip:Show()
        end)
        row:SetScript("OnClick", function(self)
            if self.recipe and IsModifiedClick("CHATLINK") and C_Spell and C_Spell.GetSpellLink then
                local link = C_Spell.GetSpellLink(self.recipe)
                if link then ChatEdit_InsertLink(link) end
            end
        end)
        right.rows[i] = row
    end
    right.empty = right:CreateFontString(nil, "OVERLAY")
    right.empty:SetFont(NAME_FONT, 13, "")
    right.empty:SetTextColor(0.62, 0.56, 0.48)
    At(right.empty, "TOP", (split.right.left + split.right.right) / 2, C.list + 40)
    right.empty:SetWidth(split.right.right - split.right.left - 40)
    crafts.offset = 0

    function crafts:Refresh()
        local professions = ns.GetProfessions(self.key)
        local picked
        for _, prof in ipairs(professions.list) do if prof.line == self.line then picked = prof end end
        picked = picked or professions.list[1]
        self.line = picked and picked.line
        self.empty:SetText(#professions.list == 0 and "No professions yet. They show once they log in with SOLC 0.37.0 or newer." or "")
        for i, row in ipairs(self.rows) do
            local prof = professions.list[i]
            row.prof = prof
            row:SetShown(prof ~= nil)
            if prof then
                row.picked = prof == picked
                row:Paint()
                row.label:SetText(prof.name)
                row.count:SetText(("%d/%d"):format(prof.rank or 0, prof.max or 0))
                row.icon:SetShown(prof.icon ~= nil)
                if prof.icon then row.icon:SetTexture(prof.icon) end
                row.bar:SetWidth(math.max(1, row.barWidth * math.min(1, (prof.rank or 0) / math.max(1, prof.max or 1))))
                Gradient(row.bar, (prof.rank or 0) >= (prof.max or 1) and SKILL_FULL or SKILL_FILL)
            end
        end

        -- The right page: the picked profession and its recipes.
        local art = picked and UI.ProfessionKey(picked.line)
        if art then right.art:SetTexture(PROFESSION_ART .. art) end
        right.art:SetShown(art ~= nil)
        right.shade:SetShown(art ~= nil)
        right.icon:SetShown(picked ~= nil)
        if picked and picked.icon then right.icon:SetTexture(picked.icon) end
        right.name:SetText(picked and picked.name or "")
        local recipes = {}
        for _, id in ipairs(picked and professions.recipes and professions.recipes[picked.line] or {}) do
            local name, icon = ns.RecipeInfo(id)
            if not name and C_Spell and C_Spell.RequestLoadSpellData then C_Spell.RequestLoadSpellData(id) end
            recipes[#recipes + 1] = { recipe = id, label = name or "...", icon = icon }
        end
        table.sort(recipes, function(a, b) return a.label < b.label end)
        right.skill:SetText(picked and ("%s    |cffc8bca8%d recipes known|r"):format(SKILL_RANKS[picked.max or 0] or "Skill", #recipes) or "")
        right.bar:SetShown(picked ~= nil)
        if picked then right.bar:Set(picked.rank, picked.max) end
        right.empty:SetText(picked and #recipes == 0 and "No recipes known yet. They show once that profession's window has been opened." or "")
        self.recipes = recipes
        self.offset = math.max(0, math.min(self.offset, #recipes - #right.rows))
        for i, row in ipairs(right.rows) do
            local r = recipes[self.offset + i]
            row.recipe = r and r.recipe
            row:SetShown(r ~= nil)
            if r then
                row.label:SetText(r.label)
                row.icon:SetShown(r.icon ~= nil)
                if r.icon then row.icon:SetTexture(r.icon) end
            end
        end
    end
    right:SetScript("OnMouseWheel", function(_, delta)
        local most = math.max(0, #(crafts.recipes or {}) - #right.rows)
        local offset = math.max(0, math.min(most, crafts.offset - delta * 3))
        if offset ~= crafts.offset then
            crafts.offset = offset
            crafts:Refresh()
        end
    end)
    function crafts:SetPlayer(key)
        if key ~= self.key then self.line, self.offset = nil, 0 end
        self.key = key
        if self:IsShown() then self:Refresh() end
    end
    -- Recipe names load a moment later for spells this client hasn't seen yet.
    local pending
    crafts:RegisterEvent("SPELL_DATA_LOAD_RESULT")
    crafts:SetScript("OnEvent", function(self)
        if not self:IsVisible() or pending then return end
        pending = true
        C_Timer.After(0.5, function()
            pending = nil
            if self:IsVisible() then self:Refresh() end
        end)
    end)
    crafts:SetScript("OnShow", function(self) right:Show() self:Refresh() end)
    crafts:SetScript("OnHide", function() right:Hide() end)
    return crafts
end

local OVERVIEW  -- the page's registration, for its refresh
OVERVIEW = {
    key = "overview", label = "Overview", section = "me", order = 1,
    bare = true,   -- its own boards fill the frame (UI.lua)
    split = true,  -- the profile header over its left page (ProfileHeader.lua)
    create = function(parent)
        local page = CreateFrame("Frame", nil, parent)
        page:SetAllPoints()
        local card = RIGHT
        local W = UI.window
        local under = UI.SPLIT.under
        local function At(region, point, x, y) region:SetPoint(point, W, "TOPLEFT", x, -y) end

        -- The boards, under everything: the left slot's bands (the heading a cross beam), the right page's board.
        -- They run on under the post and the beams round them.
        local book = CreateFrame("Frame", nil, page)
        book:SetAllPoints()
        local bandTop
        for _, band in ipairs(LEFT.bands) do
            bandTop = band.top or bandTop
            local fill = book:CreateTexture(nil, "BACKGROUND", nil, -8)
            At(fill, "TOPLEFT", under.left, bandTop)
            fill:SetSize(under.middle - under.left, band[1] - bandTop)
            if band.beam then
                fill:SetColorTexture(0.06, 0.04, 0.03)  -- behind the beam's ragged edges
                UI.CrossBeam(book, LEFT.left, LEFT.right, bandTop, nil, band[1] - bandTop, true)
            else
                fill:SetColorTexture(band[2], band[3], band[4])
            end
            bandTop = band[1]
        end
        local board = book:CreateTexture(nil, "BACKGROUND")
        At(board, "TOPLEFT", under.middle, under.top)
        board:SetSize(under.right - under.middle + 20, under.bottom - under.top)
        board:SetColorTexture(unpack(RIGHT.color))

        local cardFrame = CreateFrame("Frame", nil, page)
        cardFrame:SetAllPoints()
        cardFrame:SetFrameLevel(book:GetFrameLevel() + 2)
        local function Place(region, area)  -- area: { x, y (centre), w, h }
            region:SetSize(area.w, area.h)
            At(region, "CENTER", area.x, area.y)
        end

        -- The photo: a picture (their chosen background, else an evening sky over grass) and the model on it.
        local photo = CreateFrame("Frame", nil, cardFrame)
        Place(photo, card.photo)
        page.photo = photo
        photo:SetFrameLevel(cardFrame:GetFrameLevel() + 2)
        local sky = photo:CreateTexture(nil, "BACKGROUND")
        sky:SetAllPoints()
        sky:SetTexture("Interface\\Buttons\\WHITE8X8")
        sky:SetGradient("VERTICAL", CreateColor(0.42, 0.58, 0.3, 1), CreateColor(0.96, 0.8, 0.74, 1))
        page.backdrop = photo:CreateTexture(nil, "ARTWORK")
        page.backdrop:SetAllPoints()
        local crop = (1 - card.photo.w / card.photo.h) / 2  -- the square pictures cropped to the photo's shape
        page.backdrop:SetTexCoord(crop, 1 - crop, 0, 1)
        page.backdrop:Hide()

        local model = CreateFrame("DressUpModel", nil, photo)
        model:SetAllPoints()
        model:EnableMouse(true)
        model:EnableMouseWheel(true)
        page.model, page.facing, page.zoom = model, 0, 0
        local function ApplyZoom()
            if model.SetCamDistanceScale then model:SetCamDistanceScale(UI.CharacterCamera(page.key, page.zoom)) end
        end
        page.ApplyZoom = ApplyZoom
        model:SetScript("OnMouseWheel", function(_, delta)
            page.zoom = math.max(UI.MIN_ZOOM, math.min(UI.MAX_ZOOM, page.zoom - delta * 0.1))
            ApplyZoom()
        end)
        model:SetScript("OnMouseDown", function(self, button)
            if button ~= "LeftButton" then return end
            local lastX = GetCursorPosition()
            self:SetScript("OnUpdate", function()
                local x = GetCursorPosition()
                page.facing = page.facing + (x - lastX) / 80
                lastX = x
                self:SetFacing(page.facing)
            end)
        end)
        model:SetScript("OnMouseUp", function(self, button)
            self:SetScript("OnUpdate", nil)
            if button == "RightButton" and not page.key then PhotoMenu(self) end
        end)
        model:SetScript("OnHide", function(self) self:SetScript("OnUpdate", nil) end)
        model:SetScript("OnEnter", function(self)
            SetTooltip(self, { "Drag to turn, scroll to zoom", not page.key and "Right-click to pick the background behind it" or nil })
        end)
        -- A picture instead of the model: square, as tall as the photo, its sides cut off by the photo's edges.
        photo:SetClipsChildren(true)
        -- A picture shows whole, as on the Pictures page: the photo goes square (refresh), the picture filling it.
        page.portrait = CreateFrame("Frame", nil, photo)
        page.portrait:SetSize(card.photo.w, card.photo.w)
        page.portrait:SetPoint("CENTER")
        page.portrait:Hide()
        -- While it shows, the photo takes the clicks: left to open the picture, right (yours) for the menu.
        photo:SetScript("OnMouseUp", function(self, button)
            if not page.portraitMint then return end
            if page.portraitMint.ogre then  -- an ogre (built, Minting.lua): yours opens the builder
                if not page.key and button == "LeftButton" and not page.building then UI.ClickSound() page.OpenBuilder() end
                return
            end
            if button == "RightButton" and not page.key then
                PhotoMenu(self)
            elseif button == "LeftButton" then
                UI.ClickSound()
                if page.viewing and page.viewing == page.portraitMint then  -- (open: turned over to read its dream, and back)
                    page.reading = not page.reading
                    ns.ShowMintTale(page.portrait, page.viewing, page.reading)
                    self:GetScript("OnEnter")(self)
                    return
                end
                ns.ShowMint(page.portraitMint, page.key and Ambiguate(page.key, "short") or nil)
            end
        end)
        photo:SetScript("OnEnter", function(self)
            if not page.portraitMint then return end
            if page.portraitMint.ogre then
                return SetTooltip(self, { page.key and "Their ogre" or "Your ogre", not page.key and not page.building and "Click to build" or nil })
            end
            if page.viewing and page.viewing == page.portraitMint then
                return SetTooltip(self, { page.reading and "Back to the picture" or page.viewing.tale and "Read the dream"
                    or "Turn it over", "Click to turn the picture over." })
            end
            SetTooltip(self, { ("Picture #%d"):format(page.portraitMint.number), "Click to view",
                not page.key and "Right-click to show your character instead" or nil })
        end)
        photo:SetScript("OnLeave", GameTooltip_Hide)
        model:SetScript("OnLeave", GameTooltip_Hide)
        page.empty = photo:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        page.empty:SetPoint("CENTER")
        page.empty:SetWidth(card.photo.w - 16)
        page.empty:SetText("No character synced yet. It shows once they log in with SOLC 0.37.0 or newer.")
        -- No picture of yours yet: a big way into the ogre builder instead.
        page.makePrompt = CreateFrame("Button", nil, photo)
        page.makePrompt:SetSize(card.photo.w - 40, 64)
        page.makePrompt:SetPoint("CENTER")
        page.makePrompt:SetFrameLevel(photo:GetFrameLevel() + 20)
        page.makePrompt.word = page.makePrompt:CreateFontString(nil, "OVERLAY")
        page.makePrompt.word:SetFont(NAME_FONT, 24, "")
        page.makePrompt.word:SetPoint("CENTER", 0, 1)
        page.makePrompt.word:SetText("MAKE YOUR OGRE")
        page.makePrompt.word:SetTextColor(1, 0.93, 0.78)  -- (cream, as the sidebar's planks)
        UI.OutlineText(page.makePrompt.word, { 0.18, 0.09, 0.03 })
        UI.SkinButton(page.makePrompt, { steady = true })
        page.makePrompt.note = page.makePrompt:CreateFontString(nil, "OVERLAY")
        page.makePrompt.note:SetFont(NAME_FONT, 15, "")
        UI.OutlineText(page.makePrompt.note, { 0, 0, 0 })
        page.makePrompt.note:SetPoint("TOP", page.makePrompt, "BOTTOM", 0, -8)
        page.makePrompt.note:SetWidth(card.photo.w - 30)
        page.makePrompt.note:SetText("Dress up your ogre: it's your picture here, for the whole guild to see")
        page.makePrompt:SetScript("OnClick", function() UI.ClickSound() page.OpenBuilder() end)
        page.makePrompt:Hide()

        -- The frame over the photo's edges, and their first name on its plaque.
        local hung = CreateFrame("Frame", nil, cardFrame)
        hung:SetAllPoints()
        hung:SetFrameLevel(photo:GetFrameLevel() + 10)  -- over the model
        page.hung = hung
        page.tallBeam, page.signature = UI.PhotoBeam(hung, RIGHT.beam)  -- the photo's bottom edge, the name on it
        page.signatureWidth = RIGHT.plaque.w
        -- A picture's: the beam higher (under the square photo), its rarity and number, its traits.
        local sq = RIGHT.square
        page.squareBeam, page.squareSignature = UI.PhotoBeam(hung, sq.beam)
        page.portraitInfo = hung:CreateFontString(nil, "OVERLAY")
        page.portraitInfo:SetFont(NAME_FONT, 14, "")
        UI.OutlineText(page.portraitInfo, { 0, 0, 0 })
        page.portraitInfo:SetPoint("CENTER", UI.window, "TOPLEFT", card.photo.x, -sq.rarity)
        -- Its traits, two columns; on your own picture with the crayon edition, click one to draw it painted, in crayon
        -- or sketched, in turn.
        page.portraitTraits = {}
        -- Your ogre's trait, one step on (dir 1) or back (-1) through what you have for it: kept (ns.SetOgre), redrawn.
        local function Step(row, dir)
            local options, at = ns.OwnedOptions(row.layer), 0
            if #options == 0 then return end
            local current = page.building or (row.mint and row.mint.traits) or {}
            for i, option in ipairs(options) do if option.id == current[row.layer] then at = i end end
            -- (a new table: the picture is redrawn only for different traits, ns.DrawMint)
            local traits = {}
            for k, id in pairs(current) do traits[k] = id end
            traits[row.layer] = options[(at - 1 + dir) % #options + 1].id
            if page.building then page.building = traits end
            UI.ClickSound()
            ns.SetOgre(traits)
            OVERVIEW.refresh(page)  -- (now, not after the usual moment)
        end
        -- Right-click: every option you have for it, to pick one.
        local function PickFromList(row)
            if not MenuUtil then return end
            local layer = ns.MintLayerByKey and ns.MintLayerByKey(row.layer)
            MenuUtil.CreateContextMenu(row, function(_, root)
                root:CreateTitle(layer and layer.name or row.layer)
                if root.SetScrollMode then root:SetScrollMode(360) end
                local current = page.building or (row.mint and row.mint.traits) or {}
                for _, option in ipairs(ns.OwnedOptions(row.layer)) do
                    root:CreateRadio(("|c%s%s|r"):format(ns.RARITY_COLORS[option.rarity] or "ffffffff", option.name),
                        function() return current[row.layer] == option.id end,
                        function()
                            local traits = {}
                            for k, id in pairs(current) do traits[k] = id end
                            traits[row.layer] = option.id
                            if page.building then page.building = traits end
                            ns.SetOgre(traits)
                            OVERVIEW.refresh(page)
                        end)
                end
            end)
        end
        for i = 1, 8 do
            local trait = CreateFrame("Button", nil, hung)
            trait:SetSize(sq.traits.lefts[2] - sq.traits.lefts[1] - 8, sq.traits.line)
            local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
            trait:SetPoint("TOPLEFT", UI.window, "TOPLEFT", sq.traits.lefts[col + 1], -(sq.traits.top + row * sq.traits.line))
            -- (a faint band behind it, so the list reads as rows to work with)
            trait.band = trait:CreateTexture(nil, "BACKGROUND", nil, -1)
            trait.band:SetPoint("TOPLEFT", -2, 1)
            trait.band:SetPoint("BOTTOMRIGHT", 2, -1)
            trait.band:SetColorTexture(1, 0.9, 0.7, 0.05)
            trait.text = trait:CreateFontString(nil, "OVERLAY")
            trait.text:SetFont(NAME_FONT, sq.traits.size, "")
            trait.text:SetPoint("LEFT")
            trait.text:SetPoint("RIGHT", -22, 0)
            -- (your ogre: arrows to flip through what you have, either side)
            for _, dir in ipairs({ -1, 1 }) do
                local arrow = CreateFrame("Button", nil, trait)
                arrow:SetSize(18, 18)
                local art = dir < 0 and "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-" or "Interface\\Buttons\\UI-SpellbookIcon-NextPage-"
                arrow:SetNormalTexture(art .. "Up")
                arrow:SetPushedTexture(art .. "Down")
                arrow:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
                if dir < 0 then arrow:SetPoint("LEFT", -2, 0) else arrow:SetPoint("RIGHT", -18, 0) end
                arrow:SetScript("OnClick", function() Step(trait, dir) end)
                arrow:Hide()
                trait[dir < 0 and "prev" or "next"] = arrow
            end
            -- Its edition, a little icon at its end (a brush, a crayon, a pencil): click for the next one it has.
            trait.ed = CreateFrame("Button", nil, trait)
            trait.ed:SetSize(18, 18)
            trait.ed:SetPoint("RIGHT", 0, 0)
            trait.ed.icon = trait.ed:CreateTexture(nil, "ARTWORK")
            trait.ed.icon:SetAllPoints()
            trait.ed:SetScript("OnClick", function(self)
                local row = self:GetParent()
                if not row.option then return end
                UI.ClickSound()
                local next = ns.NextEditionFor(row.option, row.edition)
                if row.picker then ns.SetOgreEdition(row.layer, next)
                elseif row.editable then ns.SetLayerEdition(row.mint, row.layer, next) end
                OVERVIEW.refresh(page)
            end)
            trait.ed:SetScript("OnEnter", function(self)
                local row = self:GetParent()
                local name = row.edition and (row.edition:gsub("^%l", string.upper)) or "Painted"
                SetTooltip(self, { name, "Click: the next edition it has" })
            end)
            trait.ed:SetScript("OnLeave", GameTooltip_Hide)
            trait.ed:Hide()
            trait.text:SetJustifyH("LEFT")
            trait.text:SetWordWrap(false)
            local glow = trait:CreateTexture(nil, "BACKGROUND")
            glow:SetAllPoints()
            glow:SetColorTexture(1, 1, 1, 0.08)
            glow:Hide()
            trait:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            trait:SetScript("OnClick", function(self, mouse)
                if self.picker then  -- your ogre: right-click the list; click its style (painted, crayon, sketched)
                    if mouse == "RightButton" then return PickFromList(self) end
                    if not self.option then return end
                    UI.ClickSound()
                    ns.SetOgreEdition(self.layer, ns.NextEditionFor(self.option, self.edition))
                    OVERVIEW.refresh(page)
                    return
                end
                if not self.editable then return end
                UI.ClickSound()
                ns.SetLayerEdition(self.mint, self.layer, ns.NextEdition(ns.LayerEdition(ns.MintStyle(self.mint), self.layer)))
                OVERVIEW.refresh(page)
            end)
            trait:SetScript("OnEnter", function(self)
                if self.picker then
                    glow:Show()
                    return SetTooltip(self, { "Arrows: flip through  -  right-click: pick from the list", "Click: painted, crayon or sketched",
                        ("%d to pick from"):format(#ns.OwnedOptions(self.layer)) })
                end
                if not self.editable then return end
                glow:Show()
                SetTooltip(self, { "Click: painted, crayon or sketched" })
            end)
            trait:SetScript("OnLeave", function() glow:Hide() GameTooltip_Hide() end)
            page.portraitTraits[i] = trait
        end
        -- A picture opened to look at (yours: from your gallery, or anywhere, ns.ShowMint): its buttons under its traits.
        page.viewButtons = {}
        for i = 1, 4 do  -- (placed when shown: centred under the photo, however many)
            local button = CreateFrame("Button", nil, hung)
            button:SetSize(118, 22)
            button.back = button:CreateTexture(nil, "BACKGROUND")
            button.back:SetAllPoints()
            button.text = button:CreateFontString(nil, "OVERLAY")
            button.text:SetFont(NAME_FONT, 13, "")
            button.text:SetPoint("CENTER", 0, 1)
            UI.OutlineText(button.text, { 0, 0, 0 })
            local function Paint(lit)
                button.back:SetColorTexture(unpack(lit and { 0.65, 0.53, 0.28 } or { 0.3, 0.22, 0.12 }))
                button.text:SetTextColor(unpack(lit and { 1, 1, 1 } or HEADING_COLOR))
            end
            button:SetScript("OnEnter", function(self) Paint(true) if self.lines then SetTooltip(self, self.lines) end end)
            button:SetScript("OnLeave", function() Paint(false) GameTooltip_Hide() end)
            button:SetScript("OnClick", function(self)
                UI.ClickSound()
                if self.action then self.action() end
            end)
            Paint(false)
            button:Hide()
            page.viewButtons[i] = button
        end

        -- The left slot: the showcase's pictures, and what happened to them lately.
        local left = CreateFrame("Frame", nil, page)
        left:SetAllPoints()
        left:SetFrameLevel(book:GetFrameLevel() + 2)
        page.left = left

        -- The showcase's pictures, side by side, each in its rarity's colour.
        local pictures = LEFT.pictures
        page.polaroids = {}
        for i, x in ipairs(pictures.lefts) do
            local holder = CreateFrame("Button", nil, left)
            holder:SetSize(pictures.size, pictures.size)
            At(holder, "TOPLEFT", x, pictures.top)
            -- A little shake (a picture dragged onto it, Gallery.lua): side to side, dying down.
            function holder:Shake()
                self.shaking = 0
                self:SetScript("OnUpdate", function(s, elapsed)
                    s.shaking = s.shaking + elapsed
                    local left = 1 - s.shaking / 0.35
                    s:ClearAllPoints()
                    if left <= 0 then
                        At(s, "TOPLEFT", x, pictures.top)
                        if s.mint then ns.DrawMint(s.canvas, s.mint) end
                        s:SetScript("OnUpdate", nil)
                    else
                        local wobble = math.sin(s.shaking * 55) * left
                        At(s, "TOPLEFT", x + wobble * 2, pictures.top)
                        if s.mint then ns.DrawMint(s.canvas, s.mint, math.floor(wobble * 3 + 0.5) / 2) end  -- (rocking, up to 1.5 degrees)
                    end
                end)
            end
            holder.slot = i
            holder.border = holder:CreateTexture(nil, "BACKGROUND")
            holder.border:SetAllPoints()
            holder.border:SetColorTexture(1, 1, 1)
            local inside = holder:CreateTexture(nil, "BORDER")
            inside:SetPoint("TOPLEFT", pictures.rim, -pictures.rim)
            inside:SetPoint("BOTTOMRIGHT", -pictures.rim, pictures.rim)
            inside:SetColorTexture(0.06, 0.06, 0.06)
            holder.canvas = CreateFrame("Frame", nil, holder)
            holder.canvas:SetPoint("TOPLEFT", pictures.rim, -pictures.rim)
            holder.canvas:SetPoint("BOTTOMRIGHT", -pictures.rim, pictures.rim)
            holder.empty = holder:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
            holder.empty:SetPoint("CENTER")
            holder.empty:SetText("+")
            holder.empty:SetTextColor(0.5, 0.5, 0.5)
            holder:RegisterForDrag("LeftButton")
            function holder:paint()  -- its border back to its picture's rarity (after a drag lit it)
                self.border:SetVertexColor(unpack(self.borderColor or { 0.35, 0.35, 0.35 }))
            end
            holder:SetScript("OnClick", function(self)
                UI.ClickSound()
                if not self.key then
                    page.OpenGallery()  -- yours: your gallery on the right page, to drag pictures in (Gallery.lua)
                elseif self.mint then
                    ns.ShowMint(self.mint, Ambiguate(self.key, "short"))
                end
            end)
            holder:SetScript("OnDragStart", function(self)
                if self.key or not self.mint then return end
                if not page.gallery:IsShown() then page.OpenGallery() end  -- (picked up first: the gallery opens to drop it on)
                page.gallery:StartDrag(self.mint, self.slot)
            end)
            holder:SetScript("OnDragStop", function() page.gallery:StopDrag() end)
            holder:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                if self.mint then
                    local rarity = ns.MintRarity(self.mint.traits, self.mint.asked)
                    GameTooltip:AddLine(("Picture #%d"):format(self.mint.number))
                    GameTooltip:AddLine((rarity:gsub("^%l", string.upper)), ns.RarityRGB(rarity))
                    for _, trait in ipairs(ns.MintTraits(self.mint.traits)) do
                        GameTooltip:AddDoubleLine(trait[1], ("|c%s%s|r"):format(ns.RARITY_COLORS[trait[3]], trait[2]))
                    end
                    if self.mint.time then GameTooltip:AddLine(date("Minted %Y-%m-%d", self.mint.time), 0.6, 0.6, 0.6) end
                    GameTooltip:AddLine(self.key and "Click to view" or "Click: your gallery. Drag to move it", 0.6, 0.6, 0.6)
                else
                    GameTooltip:AddLine("Showcase")
                    GameTooltip:AddLine("Click to pick from your gallery", 0.6, 0.6, 0.6)
                end
                GameTooltip:Show()
            end)
            holder:SetScript("OnLeave", GameTooltip_Hide)
            page.polaroids[i] = holder
        end

        -- What happened to them lately: the heading, then a row per event (its kind's icon, the line, how long ago),
        -- every other row lighter, the one under the mouse gold. The rows run on under the post and the middle beam.
        local heading = left:CreateFontString(nil, "OVERLAY")
        At(heading, "LEFT", LEFT.heading.x, LEFT.heading.y)
        heading:SetFont(NAME_FONT, LEFT.heading.size, "")
        heading:SetTextColor(unpack(HEADING_COLOR))
        UI.OutlineText(heading, { 0, 0, 0 })
        page.heading = heading
        local feed = LEFT.feed
        local under = 20  -- how far the rows run on under the post and the beam
        page.feed = {}
        for i = 1, math.floor((LEFT.bottom - feed.top) / feed.rowHeight) do
            local row = CreateFrame("Button", nil, left)
            row:SetSize(LEFT.right - LEFT.left + 2 * under, feed.rowHeight)
            At(row, "TOPLEFT", LEFT.left - under, feed.top + (i - 1) * feed.rowHeight)
            local shade = feed.colors[i % 2 == 1 and 1 or 2]
            row.stripe = row:CreateTexture(nil, "BACKGROUND")
            row.stripe:SetAllPoints()
            row.stripe:SetColorTexture(shade, shade, shade)
            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetSize(feed.iconSize, feed.iconSize)
            row.icon:SetPoint("LEFT", under + 4, 0)
            row.picture = CreateFrame("Frame", nil, row)  -- a picture's line: the picture, small
            row.picture:SetSize(feed.iconSize, feed.iconSize)
            row.picture:SetPoint("LEFT", under + 4, 0)
            row.time = row:CreateFontString(nil, "OVERLAY")
            row.time:SetFont(NAME_FONT, feed.textSize, "")
            row.time:SetTextColor(unpack(FEED_AGO_COLOR))
            row.time:SetShadowOffset(1, -1)
            row.time:SetPoint("RIGHT", -(under + 6), 0)
            row.text = row:CreateFontString(nil, "OVERLAY")
            row.text:SetFont(NAME_FONT, feed.textSize, "")
            row.text:SetTextColor(0.94, 0.94, 0.94)
            row.text:SetShadowOffset(1, -1)
            row.text:SetShadowColor(0, 0, 0, 0.8)
            row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
            row.text:SetPoint("RIGHT", row.time, "LEFT", -8, 0)
            row.text:SetJustifyH("LEFT")
            row.text:SetWordWrap(false)
            -- Click for its details on the right page (FeedDetail.lua), again to close them; the open one stays lit.
            function row:Paint()
                local open = self.item and page.detail:IsShown() and page.detail.event == self.item.event
                self.stripe:SetColorTexture(unpack(self.hovered and FEED_HOVER_COLOR or open and FEED_OPEN_COLOR or { shade, shade, shade }))
            end
            row:SetScript("OnClick", function(self)
                if not self.item then return end
                UI.ClickSound()
                if page.detail:IsShown() and page.detail.event == self.item.event then page.CloseDetail() else page.OpenDetail(self.item) end
            end)
            row:SetScript("OnEnter", function(self)
                if not self.item then return end
                self.hovered = true
                self:Paint()
                UI.FeedTooltip(self, self.item, "Click for the details")
            end)
            row:SetScript("OnLeave", function(self)
                self.hovered = false
                self:Paint()
                GameTooltip_Hide()
            end)
            page.feed[i] = row
        end

        -- An event's details over the right page instead of the photo.
        page.detail = UI.FeedDetail(page)
        local function PaintFeed() for _, row in ipairs(page.feed) do row:Paint() end end
        -- Your gallery over the right page instead of the photo (Gallery.lua), from your showcase.
        page.gallery = UI.Gallery(page)
        -- One of your pictures, opened to look at (on the photo's place, with its buttons). fromGallery: BACK reopens it.
        function page.OpenView(mint, fromGallery)
            page.CloseDetail()
            page.gallery:Hide()
            page.building, page.buildingFromGallery = nil, nil
            page.viewing, page.viewingFromGallery = mint, fromGallery
            page.photo:Show()
            page.hung:Show()
            OVERVIEW.refresh(page)
        end
        function page.CloseView()
            local fromGallery = page.viewingFromGallery
            page.viewing, page.viewingFromGallery = nil, nil
            if fromGallery then page.OpenGallery() else OVERVIEW.refresh(page) end
        end
        -- Building your ogre (on the photo's place): from the one you have, else your photo's picture, else a plain one.
        function page.OpenBuilder(fromGallery)
            page.CloseDetail()
            page.gallery:Hide()
            page.viewing, page.viewingFromGallery = nil, nil
            page.building, page.buildingFromGallery = ns.BaseTraits(), fromGallery
            page.photo:Show()
            page.hung:Show()
            OVERVIEW.refresh(page)
        end
        function page.CloseBuilder()
            local fromGallery = page.buildingFromGallery
            page.building, page.buildingFromGallery = nil, nil
            if fromGallery then page.OpenGallery() else OVERVIEW.refresh(page) end
        end
        UI.overviewPage = page
        function page.OpenGallery()
            page.viewing, page.viewingFromGallery = nil, nil
            page.building, page.buildingFromGallery = nil, nil
            page.CloseDetail()
            page.gallery:Show()
            page.gallery:Refresh()
            page.photo:Hide()
            page.hung:Hide()
            if UI.SetTab then UI.SetTab("overview", "Gallery", "PIX") end
        end
        function page.CloseGallery()
            if not page.gallery:IsShown() then return end
            page.gallery:Hide()
            page.photo:SetShown(page.panel ~= "crafts")
            page.hung:SetShown(page.panel ~= "crafts")
            if UI.SetTab then UI.SetTab("overview", TAB_TITLES[page.panel or "me"], page.panel and TABS_OGRE[page.panel]) end
        end
        function page.OpenDetail(item)
            page.gallery:Hide()
            page.detail:ShowItem(item)
            page.photo:Hide()
            page.hung:Hide()
            PaintFeed()
        end
        function page.CloseDetail()
            if not page.detail:IsShown() then return end
            page.detail:Hide()
            page.photo:SetShown(page.panel ~= "crafts")
            page.hung:SetShown(page.panel ~= "crafts")
            PaintFeed()
        end

        page.gearPanel = GearPage(page)
        page.gearPanel:SetFrameLevel(left:GetFrameLevel() + 20)
        page.craftsPanel = CraftsPage(page)
        page.craftsPanel:SetFrameLevel(left:GetFrameLevel() + 20)

        -- The tabs: ME (the pictures and the feed), GEARZ, CRAFTS.
        local tabs = CreateFrame("Frame", nil, page)
        tabs:SetAllPoints()
        tabs:SetFrameLevel(left:GetFrameLevel() + 25)
        page.tabs = {}
        local function ShowPanel(which)
            page.panel = which
            page.detail:Hide()
            page.gallery:Hide()
            page.viewing, page.viewingFromGallery = nil, nil
            page.gearPanel:SetShown(which == "gear")
            page.craftsPanel:SetShown(which == "crafts")
            left:SetShown(which == nil)
            page.photo:SetShown(which ~= "crafts")  -- CRAFTS fills the right page itself
            page.hung:SetShown(which ~= "crafts")
            for _, tab in ipairs(page.tabs) do tab:Redraw() end
            if page.loaded then OVERVIEW.refresh(page) end  -- GEARZ shows the model, not a picture
        end
        page.ShowPanel = ShowPanel
        local tabWidth = (LEFT.right - LEFT.left) / #TABS
        for i, spec in ipairs(TABS) do
            local tab = UI.TabButton(tabs, LEFT.left + (i - 1) * tabWidth, LEFT.tabs, tabWidth)
            function tab:Redraw()
                local word = KillTrackerDB and KillTrackerDB.ogreMode and spec[3] or spec[2]
                if spec[1] == nil and page.key then word = PRONOUNS[UI.Profile(page.key).gender or ""] or "THEY" end
                self:SetTab(word, page.panel == spec[1])
            end
            tab:SetScript("OnClick", function()
                UI.ClickSound()
                ShowPanel(spec[1])
            end)
            page.tabs[i] = tab
        end
        ShowPanel(nil)

        -- The page is usually created while already showing, so the model may not have its size at the first
        -- load; load once more on the next frame, and whenever the page comes back.
        page.Load = function()
            if page.portraitMint then  -- a picture shows instead
                page.makePrompt:Hide()
                model:ClearModel()
                model:Hide()
                page.empty:Hide()
                return
            end
            page.makePrompt:SetShown(page.noPicture and not page.building or false)
            if page.makePrompt:IsShown() then
                model:ClearModel()
                model:Hide()
                page.empty:Hide()
                return
            end
            model:Show()
            local shown = UI.LoadCharacter(model, page.key)
            model:SetShown(shown)
            page.empty:SetShown(not shown)
            model:SetFacing(page.facing)
            ApplyZoom()
        end
        page:SetScript("OnShow", function() if page.loaded then page.Load() end end)
        C_Timer.After(0, function() if page.loaded then page.Load() end end)
        return page
    end,

    refresh = function(page)
        local key = ns.GetViewing()
        if key and page.gallery and page.gallery:IsShown() then page.CloseGallery() end  -- (someone else's: no gallery)
        local galleryOpen = page.gallery and page.gallery:IsShown()
        if UI.SetTab then  -- (the top beam)
            if galleryOpen then UI.SetTab("overview", "Gallery", "PIX")
            elseif page.viewing and not key then UI.SetTab("overview", ("Picture #%d"):format(page.viewing.number), "PIX")
            elseif page.building and not key then UI.SetTab("overview", "Your Ogre", "ME OGRE")
            else UI.SetTab("overview", TAB_TITLES[page.panel or "me"], page.panel and TABS_OGRE[page.panel]) end
        end
        if galleryOpen then page.gallery:Refresh() end
        local p = UI.Profile(key)

        -- The photo: their chosen picture, or (no model of them to show) their first showcase picture or else their
        -- newest picture, or the model.
        local friend = key and KillTrackerFriends[key]
        local cardData = key and friend and friend.card or (not key and KillTrackerDB.card) or nil
        local portrait
        if cardData and cardData.ogre and next(cardData.ogre) then  -- the ogre they built: their avatar
            portrait = { traits = cardData.ogre, ogre = true, style = cardData.ogreStyle }
        elseif key then  -- (someone who hasn't built one: a picture of theirs, else their character)
            portrait = ns.FindMint(key, p.portrait) or ns.GetShowcase(key)[1] or ns.NewestMint(key)
        end
        page.noPicture = not key and not portrait and page.panel == nil  -- (you, none: MAKE YOUR OGRE)
        if page.panel == "gear" then portrait = nil end  -- their gear goes round their character
        -- One of your pictures opened to look at: it, instead (with its buttons), until BACK.
        if page.viewing and (key or page.panel ~= nil or not ns.FindMint(nil, page.viewing.number)) then
            page.viewing, page.viewingFromGallery = nil, nil
        end
        if page.viewing then portrait = page.viewing end
        -- Building your ogre: it, with a picker on each trait.
        if page.building and (key or page.panel ~= nil) then page.building, page.buildingFromGallery = nil, nil end
        if page.building then portrait = { traits = page.building, ogre = true, style = KillTrackerDB.card and KillTrackerDB.card.ogreStyle } end
        local switched = (page.portraitMint ~= nil) ~= (portrait ~= nil)
        page.portraitMint = portrait
        page.portrait:SetShown(portrait ~= nil)
        page.photo:EnableMouse(portrait ~= nil)
        -- A picture: the photo square, the beam under it, its rarity and traits (as on the Pictures page); the model: the
        -- tall photo, its beam at the bottom.
        local square = portrait ~= nil
        page.photo:ClearAllPoints()
        page.photo:SetSize(RIGHT.photo.w, square and RIGHT.photo.w or RIGHT.photo.h)
        page.photo:SetPoint("CENTER", UI.window, "TOPLEFT", RIGHT.photo.x, -(square and RIGHT.square.y or RIGHT.photo.y))
        page.tallBeam:SetShown(not square)
        page.squareBeam:SetShown(square)
        page.portraitInfo:SetShown(square)
        local traits = square and ns.MintTraits(portrait.traits) or {}
        local editable = square and not key and not portrait.ogre and ns.CrayonUnlocked(portrait)
        local style = square and ns.MintStyle(portrait)
        for i, button in ipairs(page.portraitTraits) do
            local trait = traits[i]
            button:SetShown(trait ~= nil)
            if trait then
                local edition = ns.LayerEdition(style, trait[4])
                button.mint, button.layer, button.editable = portrait, trait[4], editable
                button.picker = page.building ~= nil or (portrait.ogre and not key) or false
                button:EnableMouse((editable or button.picker) and true or false)
                local layer = ns.MintLayerByKey and ns.MintLayerByKey(trait[4])
                button.option, button.edition = nil, edition
                for _, option in ipairs(layer and layer.options or {}) do
                    if option.id == portrait.traits[trait[4]] then button.option = option end
                end
                local twins = button.option and (button.option.crayon or button.option.sketch)
                button.ed:SetShown((editable or button.picker) and twins and true or false)
                button.ed.icon:SetTexture("Interface\\AddOns\\SOLC\\Media\\Icons\\Kitchen\\"
                    .. (edition == "crayon" and "EdCrayon" or edition == "sketch" and "EdSketch" or "EdPainted"))
                button.prev:SetShown(button.picker)
                button.next:SetShown(button.picker)
                button.text:ClearAllPoints()
                button.text:SetPoint("LEFT", button.picker and 18 or 0, 0)
                button.text:SetPoint("RIGHT", button.picker and -38 or -22, 0)
                -- (all of it shown: the font smaller to fit, then a shorter label - Hat for Headwear - rather than cut off)
                local rest = button.picker and ("|c%s%s|r"):format(ns.RARITY_COLORS[trait[3]], trait[2])
                    or ("|c%s%s|r%s%s"):format(ns.RARITY_COLORS[trait[3]], trait[2],
                        edition and not button.ed:IsShown() and ("  |cffff9a2a%s|r"):format(ns.EDITION_NAMES[edition]) or "", ns.TraitNote(trait))
                local width = button:GetWidth() - (button.picker and 56 or 22)
                for _, label in ipairs({ trait[1], SHORT_LABELS[trait[1]] or trait[1] }) do
                    UI.FitText(button.text, NAME_FONT, RIGHT.square.traits.size, 9, ("|cffffd100%s:|r %s"):format(label, rest), width)
                    if button.text:GetStringWidth() <= width then break end
                end
            end
        end
        -- Looking at one: BACK (to your gallery, if it came from there), its whole edition, a duplicate's reroll.
        for _, button in ipairs(page.viewButtons) do button:Hide() end
        local n = 0
        local function Button(text, lines, action)
            n = n + 1
            local button = page.viewButtons[n]
            button.text:SetText(text)
            button.lines, button.action = lines, action
            button:Show()
        end
        if page.building then
            Button("BACK", { page.buildingFromGallery and "Back to your gallery" or "Back to your photo" }, function() page.CloseBuilder() end)
            Button("RANDOM", { "A random ogre", "From what you have" }, function()
                local traits = {}  -- (a new table, so the picture is redrawn)
                for k, id in pairs(page.building) do traits[k] = id end
                for _, layer in ipairs(ns.MintLayers) do
                    local options = ns.OwnedOptions(layer.key)
                    if #options > 0 then traits[layer.key] = options[math.random(#options)].id end
                end
                page.building = traits
                ns.SetOgre(page.building)
                OVERVIEW.refresh(page)
            end)
        end
        if page.viewing then
            local mint, Next = page.viewing, Button
            Next("BACK", { page.viewingFromGallery and "Back to your gallery" or "Back to your photo" }, function() page.CloseView() end)
            if ns.CrayonUnlocked(mint) then
                local nextStyle = type(style) == "table" and ns.EDITIONS[1] or ns.NextEdition(style)
                Next(nextStyle and nextStyle:upper() or "PAINTED", { "Crayon and sketch editions", "Redraw it all "
                    .. (nextStyle and ("in " .. ns.EDITION_NAMES[nextStyle]) or "painted") .. ". Click a trait for just that one." },
                    function() ns.SetMintStyle(mint, nextStyle) OVERVIEW.refresh(page) end)
            end
            if mint.duplicateOf then
                Next("REROLL", { "Reroll for free", ("%s minted this picture first."):format(mint.duplicateOf) },
                    function() ns.ConfirmReroll(mint) end)
            end
            if ns.PICTURE_FRAMES then  -- (its frame: the next one you have)
                local frame = ns.FrameById(mint.frame or ns.DefaultFrame())
                local nextFrame = ns.FrameById(ns.NextFrame(mint.frame))
                Next("FRAME", { "Frame: " .. (frame and frame.name or "?"), "Click: " .. (nextFrame and nextFrame.name or "?") },
                    function() if nextFrame then ns.SetMintFrame(mint, nextFrame.id) end OVERVIEW.refresh(page) end)
            end
        end
        for i = 1, n do  -- (centred under the photo)
            page.viewButtons[i]:ClearAllPoints()
            page.viewButtons[i]:SetPoint("CENTER", UI.window, "TOPLEFT", RIGHT.photo.x + (i - (n + 1) / 2) * 124, -704)
        end
        -- (one of yours opened: turned over to read its dream, till another's opened)
        if page.readingOf ~= page.viewing then page.readingOf, page.reading = page.viewing, false end
        if portrait then
            ns.DrawMint(page.portrait, portrait)
            ns.ShowMintTale(page.portrait, portrait, page.reading and portrait == page.viewing)
            local rarity = ns.MintRarity(portrait.traits, portrait.asked)
            local what = portrait.ogre and (key and (((p.name or ""):match("^(%S+)") or "Their") .. "'s ogre") or "Your ogre")
                or ("#%d%s"):format(portrait.number, portrait.time and ("  " .. date("%Y-%m-%d", portrait.time)) or "")
            page.portraitInfo:SetText(("|c%s%s|r  |cff999999%s|r"):format(ns.RARITY_COLORS[rarity] or "ffffffff",
                (rarity:gsub("^%l", string.upper)), what))
        end
        -- The model: reloaded only for someone else, new gear or after a picture, so turning it sticks while the page
        -- refreshes.
        if key ~= page.key then page.CloseDetail() end  -- someone else's feed
        if not page.loaded or switched or key ~= page.key or (key and gear ~= page.model.shownGear) then
            page.loaded, page.key = true, key
            page.Load()
        end
        local option = not portrait and ns.GetModelBackdrop and ns.GetModelBackdrop(key)
        if option then page.backdrop:SetTexture(ns.MintTexture(option, {})) end
        page.backdrop:SetShown(option ~= nil and option ~= false)

        -- The showcase's pictures (your empty ones show a +; someone else's empty ones aren't there).
        local pictures = ns.GetShowcase(key)
        for _, holder in ipairs(page.polaroids) do
            local mint = pictures[holder.slot]
            holder.mint, holder.key = mint, key
            holder:SetShown(mint ~= nil or key == nil)
            holder.canvas:SetShown(mint ~= nil)
            holder.empty:SetShown(mint == nil)
            holder.borderColor = mint and { ns.RarityRGB(ns.MintRarity(mint.traits, mint.asked)) } or nil
            if mint then ns.DrawMint(holder.canvas, mint) end
            holder:paint()
        end

        -- What happened to them lately (WHAT HAPPEN TO ME? on yours, their first name on someone else's).
        page.heading:SetText(key and ("WHAT HAPPEN TO %s?"):format(((p.name or ""):match("^(%S+)") or ""):upper()) or LEFT.heading.text)
        local items = ns.GetFeed(true, false, key or "me")
        for i, row in ipairs(page.feed) do
            local item = items[i]
            row.item = item
            row.stripe:SetShown(item ~= nil)
            row:Paint()
            row.text:SetText(item and item.text or (i == 1 and "Nothing yet - go smash something." or ""))
            row.time:SetText(item and ns.TimeAgo(item.time) or "")
            local thumbnail = item and item.kind == "M" and item.mint
            local icon = item and not thumbnail and FEED_ICONS[item.kind]
            row.icon:SetShown(icon ~= nil)
            if icon then row.icon:SetTexture(FEED_ICON .. icon) end
            if item and item.kind == "K" then  -- a rank reached: that rank's badge
                local reached = tonumber(item.text:match("rank (%d+)")) or 1
                row.icon:SetTexture(UI.BadgeArt(reached))
                row.icon:Show()
            end
            row.picture:SetShown(thumbnail and true or false)
            if thumbnail then ns.DrawMint(row.picture, item.mint) end
        end

        page.gearPanel:SetPlayer(key)
        page.craftsPanel:SetPlayer(key)
        for _, tab in ipairs(page.tabs) do tab:Redraw() end

        -- The first name on the frame's plaque, as big as fits.
        local first = (p.name or ""):match("^(%S+)") or ""
        Fit(page.signature, SIGN_FONT, RIGHT.plaque.size, 8, first:upper(), page.signatureWidth)
        Fit(page.squareSignature, SIGN_FONT, RIGHT.plaque.size, 8, first:upper(), page.signatureWidth)
    end,
}
ns.RegisterPage(OVERVIEW)

-- One of your pictures, opened anywhere (ns.ShowMint): your own Overview, the ME tab, the picture on the photo's place.
function UI.ShowOwnPicture(mint)
    ns.ViewPlayer(nil, "overview")  -- (yours, from anyone's or the guild's view)
    local page = UI.overviewPage
    if not page then return end
    if page.panel then page.ShowPanel(nil) end
    page.OpenView(mint)
end
