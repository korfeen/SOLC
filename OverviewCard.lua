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
    { "edit", "EDIT", "EDIT" },  -- (yours only: your look, changed in place on your portrait)
}
-- The tabs' names on the top beam (ns.UI.SetTab; ME: nothing added) and in ogre mode.
local TAB_TITLES, TABS_OGRE = { gear = "Gear", crafts = "Crafts", edit = "Your Look" }, { gear = "GEARZ", crafts = "MAKE", edit = "ME OGRE" }
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
    -- (each hangs a touch crooked, in its own frame; the middle one in front)
    pictures = { lefts = { 242, 371, 500 }, top = 325, size = 122, tilts = { -3, 2, -1.5 }, levels = { 1, 3, 2 } },
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

-- The portrait (ME, the right page): the ogre they built (or the picture shown instead) hung in the frame they picked,
-- the frame its only frame: big frames reach over the middle beam, the window's edge and the top beam (the gear and
-- the X hide meanwhile). The picture keeps its size and place whatever the frame; the frame goes round it. Under it
-- their name on a plate in their name colour (written on a polaroid's white strip instead), under that their motto
-- on a pinned note. KillTrackerDB.card.frame / .motto (synced, Sync.lua's card section).
-- In window pixels (from its top-left, y down): the picture's middle and size, the plate's and the note's middles.
local PORTRAIT = { x = 870, y = 321, size = 345, plate = 590, note = 676, level = 45, mottoMax = 90,
    noteWidth = 270, noteLine = 18,  -- (the note: as wide as this at most, up to 3 lines)
    hand = 442 / 512,  -- (the polaroid's white strip under its opening, its middle: where the name is written)
    -- One of your pictures opened (a showcase picture clicked, or from the gallery): in the portrait's place, the same
    -- size, in its own frame; its layers at one height whatever the frame (two columns), its buttons under them.
    traits = { top = 628, lefts = { 690, 878 }, width = 180, line = 16, size = 12 }, buttons = 712 }
local INK = { 0.17, 0.13, 0.09 }
-- (their art: tools/make-portrait-bits.js. The note's paper has a soft margin round it, NOTE_PAPER of the texture; the
-- plate's ends are its left and right quarters, the middle stretches)
local NOTE_PAPER = { w = 244 / 256, h = 52 / 64 }
local DEFAULT_PORTRAIT_FRAME = "wood"

-- Your motto (the note's editbox): kept, synced.
local function SetMotto(text)
    KillTrackerDB.card = KillTrackerDB.card or {}
    text = strtrim(((text or ""):gsub("[#~^|]", ""):gsub("%s+", " ")))
    KillTrackerDB.card.motto = text ~= "" and text or nil
    ns.Touch(KillTrackerDB.card)
    if ns.OnKillsChanged then ns.OnKillsChanged() end
end

-- Your portrait's frame: one of the frames you have (Frames.lua; the same ones as your pictures').
local function SetPortraitFrame(id)
    KillTrackerDB.card = KillTrackerDB.card or {}
    KillTrackerDB.card.frame = id ~= DEFAULT_PORTRAIT_FRAME and id or nil
    ns.Touch(KillTrackerDB.card)
    if ns.OnKillsChanged then ns.OnKillsChanged() end
end

-- Builds the portrait over the page (and over the window's wood: its own level, PORTRAIT.level). onClick(button):
-- clicking the picture.
local function BuildPortrait(page, onClick)
    local W = UI.window
    local top = CreateFrame("Frame", nil, W)
    top:SetAllPoints()
    top:SetFrameLevel(W:GetFrameLevel() + PORTRAIT.level)
    top:Hide()
    page.portraitTop = top
    -- The picture, then the frame over its edge.
    local picture = CreateFrame("Button", nil, top)
    picture:SetSize(PORTRAIT.size, PORTRAIT.size)
    picture:SetPoint("CENTER", W, "TOPLEFT", PORTRAIT.x, -PORTRAIT.y)
    picture:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    picture:SetScript("OnClick", function(_, button) onClick(button) end)
    picture.canvas = CreateFrame("Frame", nil, picture)
    picture.canvas:SetAllPoints()
    top.picture = picture
    local over = CreateFrame("Frame", nil, top)
    over:SetAllPoints()
    over:SetFrameLevel(picture:GetFrameLevel() + 5)
    top.frame = over:CreateTexture(nil, "ARTWORK")
    top.frameGlow = over:CreateTexture(nil, "OVERLAY")  -- (saving: the frame lit up, fading)
    top.frameGlow:SetBlendMode("ADD")
    top.frameGlow:SetAllPoints(top.frame)
    top.frameGlow:Hide()

    -- Turned over (an opened picture): its frame's back, solid, over the picture and the frame; the dream on it.
    local backside = CreateFrame("Frame", nil, top)
    backside:SetAllPoints()
    backside:SetFrameLevel(over:GetFrameLevel() + 3)
    backside:Hide()
    top.backTex = backside:CreateTexture(nil, "ARTWORK")
    local tale = CreateFrame("Frame", nil, top)
    tale:SetAllPoints(picture)
    tale:SetFrameLevel(backside:GetFrameLevel() + 1)
    tale.framing = CreateFrame("Frame", nil, tale)  -- (as Minting.lua's framed canvas: its back and its opening)
    tale.framing.backside, tale.framing.picture = backside, picture
    top.tale = tale
    -- The plate: a dark board in a gilt rim, a rivet at each end (three slices, the middle stretching), the name on it.
    local plate = CreateFrame("Frame", nil, over)
    plate:SetFrameLevel(over:GetFrameLevel() + 1)
    local ends = {}
    for i, slice in ipairs({ { 0, 0.25 }, { 0.25, 0.75 }, { 0.75, 1 } }) do
        local t = plate:CreateTexture(nil, "BACKGROUND")
        t:SetTexture(ART .. "Plate")
        t:SetTexCoord(slice[1], slice[2], 0, 1)
        ends[i] = t
    end
    ends[1]:SetPoint("TOPLEFT") ends[1]:SetPoint("BOTTOMLEFT") ends[1]:SetWidth(18)
    ends[3]:SetPoint("TOPRIGHT") ends[3]:SetPoint("BOTTOMRIGHT") ends[3]:SetWidth(18)
    ends[2]:SetPoint("TOPLEFT", ends[1], "TOPRIGHT") ends[2]:SetPoint("BOTTOMRIGHT", ends[3], "BOTTOMLEFT")
    plate.name = plate:CreateFontString(nil, "OVERLAY")
    plate.name:SetPoint("CENTER", 0, 1)
    plate.name:SetFont(NAME_FONT, 24, "")
    UI.OutlineText(plate.name, { 0, 0, 0 })
    top.plate = plate
    -- (on a polaroid: the name written on it, no plate)
    top.written = over:CreateFontString(nil, "OVERLAY")
    -- The motto: a pinned note, the paper a touch crooked (text can't turn, so the words stay level). Yours: click it
    -- and write on it (Enter keeps it, Escape drops it).
    local note = CreateFrame("Button", nil, top)
    note:SetFrameLevel(over:GetFrameLevel() + 1)
    note.shade = note:CreateTexture(nil, "BACKGROUND", nil, -1)  -- (its shadow on the wood)
    note.shade:SetPoint("CENTER", 1, -3)
    note.shade:SetTexture(ART .. "Note")
    note.shade:SetVertexColor(0, 0, 0, 0.45)
    note.shade:SetRotation(math.rad(2))
    note.paper = note:CreateTexture(nil, "BACKGROUND")
    note.paper:SetPoint("CENTER")
    note.paper:SetTexture(ART .. "Note")
    note.paper:SetRotation(math.rad(2))
    note.pin = note:CreateTexture(nil, "OVERLAY")
    note.pin:SetSize(18, 18)
    note.pin:SetTexture(ART .. "Pin")
    note.text = note:CreateFontString(nil, "ARTWORK")
    note.text:SetPoint("CENTER", 0, -1)
    note.text:SetFont(SIGN_FONT, 15, "")
    note.text:SetTextColor(unpack(INK))
    note.text:SetWordWrap(true)
    note.text:SetSpacing(2)
    note.text:SetMaxLines(3)
    local box = CreateFrame("EditBox", nil, note)
    box:SetPoint("TOPLEFT", 14, -8)
    box:SetPoint("BOTTOMRIGHT", -14, 6)
    box:SetMultiLine(true)
    box:SetFont(SIGN_FONT, 15, "")
    box:SetTextColor(unpack(INK))
    box:SetJustifyH("CENTER")
    box:SetAutoFocus(false)
    box:SetMaxLetters(PORTRAIT.mottoMax)
    box:Hide()
    local function Done(keep)
        if not box:IsShown() then return end
        local text = box:GetText()
        box:Hide()
        note.text:Show()
        if keep then SetMotto(text) end
    end
    box:SetScript("OnEnterPressed", function() Done(true) end)
    box:SetScript("OnEscapePressed", function() Done(false) end)
    box:SetScript("OnEditFocusLost", function() Done(false) end)
    box:SetScript("OnTextChanged", function(self)
        local text = self:GetText() or ""
        if text:find("\n") then self:SetText((text:gsub("\n", " "))) end  -- (no line breaks of your own: it wraps)
    end)
    note.box = box
    note:SetScript("OnClick", function()
        if page.key or box:IsShown() then return end
        UI.ClickSound()
        note.text:Hide()
        page.SizeNote(3)  -- (writing: room for all three lines)
        box:SetText(KillTrackerDB.card and KillTrackerDB.card.motto or "")
        box:Show()
        box:SetFocus()
        box:HighlightText()
    end)
    note:SetScript("OnEnter", function(self) if not page.key and not box:IsShown() then SetTooltip(self, { "Your motto", "Click to write it" }) end end)
    note:SetScript("OnLeave", GameTooltip_Hide)
    -- (its size: as wide as the text up to noteWidth, then wrapping onto up to 3 lines; lines: a set number, writing)
    function page.SizeNote(lines)
        local most = PORTRAIT.noteWidth - 44
        note.text:SetWidth(most)
        local one = note.text.GetUnboundedStringWidth and note.text:GetUnboundedStringWidth() or note.text:GetStringWidth()
        local w = lines and PORTRAIT.noteWidth or math.max(120, math.min(one, most) + 44)
        if not lines then note.text:SetWidth(w - 44) end
        lines = lines or math.max(1, math.min(3, math.floor(note.text:GetStringHeight() / PORTRAIT.noteLine + 0.5)))
        local h = lines * PORTRAIT.noteLine + 18
        note:SetSize(w, h)
        note.paper:SetSize(w / NOTE_PAPER.w, h / NOTE_PAPER.h)
        note.shade:SetSize(w / NOTE_PAPER.w, h / NOTE_PAPER.h)
    end
    top.note = note
    -- A picture opened: its layers (two columns) and its buttons.
    local tr = PORTRAIT.traits
    top.traits = {}
    for i = 1, 8 do
        local line = over:CreateFontString(nil, "OVERLAY")
        line:SetFont(NAME_FONT, tr.size, "")
        UI.OutlineText(line, { 0, 0, 0 })
        line:SetJustifyH("LEFT")
        line:SetWordWrap(false)
        line:SetWidth(tr.width)
        line:SetPoint("TOPLEFT", UI.window, "TOPLEFT", tr.lefts[(i - 1) % 2 + 1], -(tr.top + math.floor((i - 1) / 2) * tr.line))
        top.traits[i] = line
    end
    top.buttons = {}
    for i = 1, 3 do
        local button = CreateFrame("Button", nil, over)
        button:SetSize(118, 24)
        button:SetFrameLevel(over:GetFrameLevel() + 2)
        button.back = button:CreateTexture(nil, "BACKGROUND")
        button.back:SetAllPoints()
        button.text = button:CreateFontString(nil, "OVERLAY")
        button.text:SetFont(NAME_FONT, 13, "")
        button.text:SetPoint("CENTER", 0, 1)
        UI.OutlineText(button.text, { 0, 0, 0 })
        function button:Paint(lit)
            local off = not self:IsEnabled()
            self.back:SetColorTexture(unpack(lit and not off and { 0.65, 0.53, 0.28 } or { 0.3, 0.22, 0.12 }))
            self.text:SetTextColor(unpack(off and { 0.62, 0.55, 0.42 } or lit and { 1, 1, 1 } or HEADING_COLOR))
        end
        button:SetScript("OnEnter", function(self) self:Paint(true) end)
        button:SetScript("OnLeave", function(self) self:Paint(false) end)
        button:SetScript("OnClick", function(self) UI.ClickSound() if self.action then self.action() end end)
        button:SetPoint("CENTER", UI.window, "TOPLEFT", PORTRAIT.x + (i - 2) * 126, -PORTRAIT.buttons)
        top.buttons[i] = button
    end
    picture:SetScript("OnEnter", function(self)
        local mint = page.portraitMint
        if not mint then return end
        if page.viewing and mint == page.viewing then
            return SetTooltip(self, { ("Picture #%d"):format(mint.number), page.reading and "Click: back to the picture"
                or "Click: turn it over", "Right-click: its frame" })
        end
        if page.key then return SetTooltip(self, { mint.ogre and "Their ogre" or ("Picture #%d"):format(mint.number) }) end
        SetTooltip(self, { mint.ogre and "Your ogre" or ("Picture #%d"):format(mint.number), "Click to change your look",
            "Right-click: frame and motto" })
    end)
    picture:SetScript("OnLeave", GameTooltip_Hide)
    -- Showing it: the page's own photo and its beams hide, the header's buttons too.
    top:SetScript("OnShow", function() if UI.SetHeaderButtonsShown then UI.SetHeaderButtonsShown(false) end end)
    top:SetScript("OnHide", function() if UI.SetHeaderButtonsShown then UI.SetHeaderButtonsShown(true) end end)
    page:HookScript("OnHide", function() top:Hide() end)
end

-- Your portrait's menu (right-click it): its frame, from the ones you have, and your motto.
local function PortraitMenu(owner)
    if not MenuUtil then return end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle("Frame")
        local current = KillTrackerDB.card and KillTrackerDB.card.frame or DEFAULT_PORTRAIT_FRAME
        for _, frame in ipairs(ns.PICTURE_FRAMES or {}) do
            local has, how = ns.FrameUnlocked(frame)
            if has then
                root:CreateRadio(frame.name, function() return current == frame.id end, function() SetPortraitFrame(frame.id) end)
            else
                root:CreateTitle(("|cff808080%s (%s)|r"):format(frame.name, how or "locked"))
            end
        end
        root:CreateDivider()
        root:CreateButton("Write your motto", function() local page = UI.overviewPage if page then page.portraitTop.note:Click() end end)
    end)
end

-- An opened picture's menu (right-click it): its frame (the ones you have), a duplicate's free reroll.
local function PictureMenu(owner, mint, refresh)
    if not MenuUtil then return end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle("Frame")
        for _, frame in ipairs(ns.PICTURE_FRAMES or {}) do
            local has, how = ns.FrameUnlocked(frame)
            if has then
                root:CreateRadio(frame.name, function() return (mint.frame or ns.DefaultFrame()) == frame.id end,
                    function() ns.SetMintFrame(mint, frame.id) refresh() end)
            else
                root:CreateTitle(("|cff808080%s (%s)|r"):format(frame.name, how or "locked"))
            end
        end
        if mint.duplicateOf then
            root:CreateDivider()
            root:CreateButton(("Reroll for free (%s minted it first)"):format(mint.duplicateOf), function() ns.ConfirmReroll(mint) end)
        end
    end)
end

-- Hangs a picture in a showcase spot (slot), or (no slot) in the first free one, else the last: already in another
-- spot, the two trade places.
local function HangInShowcase(mint, slot)
    local numbers = {}
    for _, m in ipairs(ns.GetShowcase()) do numbers[#numbers + 1] = m.number end
    local at
    for i, n in ipairs(numbers) do if n == mint.number then at = i end end
    slot = math.min(slot or #numbers + 1, ns.SHOWCASE_SIZE or 3)
    if at then
        local to = math.min(slot, #numbers)
        numbers[at], numbers[to] = numbers[to], numbers[at]
    else
        numbers[math.min(slot, #numbers + 1)] = mint.number
    end
    ns.SetShowcase(numbers)
end

-- Draws the portrait: mint (the ogre or picture), card (their card's choices), name (their first name), color (their
-- name colour), own (yours: the note shows even empty, to write on). view: one of your pictures opened instead (its own
-- frame, its number and rarity, its layers and buttons; no motto).
local function ShowPortrait(page, mint, card, name, color, own, view)
    local top = page.portraitTop
    local side, picture = PORTRAIT.size, top.picture
    -- (a picture shown as the portrait: drawn without its own frame, the portrait's goes round it)
    ns.DrawMint(picture.canvas, mint.ogre and mint or setmetatable({ number = false }, { __index = mint }))
    -- The frame round the picture: its opening on the picture (a little smaller, its edge under the frame).
    local frame = view and ns.FrameById(mint.frame or ns.DefaultFrame())
        or ns.FrameById(card and card.frame or DEFAULT_PORTRAIT_FRAME) or ns.FrameById(DEFAULT_PORTRAIT_FRAME)
    if view then  -- (a picture: its number for its name, in its rarity's colour; turned over to read its dream)
        local rarity = ns.MintRarity(mint.traits, mint.asked)
        name, color = ("Picture #%d"):format(mint.number), { ns.RarityRGB(rarity) }
    end
    top.tale.framing.hasBack = view and frame and frame.back ~= nil or false
    ns.ShowMintTale(top.tale, mint, view and page.reading or false)
    local written = frame and frame.id == "polaroid"
    if frame and frame.texture then
        local inner = frame.inner
        local tex = side / (math.max(inner.w, inner.h) * 1.03)
        local ix, iy = inner.x + inner.w / 2, inner.y + inner.h / 2
        top.frame:ClearAllPoints()
        top.frame:SetSize(tex, tex)
        top.frame:SetPoint("TOPLEFT", UI.window, "TOPLEFT", PORTRAIT.x - ix * tex, -(PORTRAIT.y - iy * tex))
        top.frame:SetTexture(frame.texture)
        top.frame:Show()
        top.backTex:ClearAllPoints()
        top.backTex:SetSize(tex, tex)
        top.backTex:SetPoint("TOPLEFT", UI.window, "TOPLEFT", PORTRAIT.x - ix * tex, -(PORTRAIT.y - iy * tex))
        top.backTex:SetTexture(frame.back)
        if written then  -- (on its white strip)
            top.written:ClearAllPoints()
            top.written:SetPoint("CENTER", UI.window, "TOPLEFT", PORTRAIT.x, -(PORTRAIT.y + (PORTRAIT.hand - iy) * tex))
        end
    else
        top.frame:Hide()
    end
    -- Their name: written in marker on a polaroid (outlined, so a light colour reads on the white), else on the plate.
    top.plate:SetShown(not written)
    top.written:SetShown(written and true or false)
    if written then
        top.written:SetFont(SIGN_FONT, 26, "OUTLINE")
        top.written:SetText(name)
        top.written:SetTextColor(unpack(color))
    else
        local plate = top.plate
        plate.name:SetText(view and name or name:upper())
        plate.name:SetTextColor(unpack(color))
        plate:SetSize(math.max(150, plate.name:GetStringWidth() + 52), 36)
        plate:ClearAllPoints()
        plate:SetPoint("CENTER", UI.window, "TOPLEFT", PORTRAIT.x, -PORTRAIT.plate)
    end
    -- The motto: theirs, or (yours, none yet) an empty note to write on.
    local motto = card and card.motto
    local note = top.note
    local editing = page.panel == "edit" and not view
    note:SetShown(not view and not editing and (motto ~= nil or own))
    if page.editButtons then page.editButtons:SetShown(editing) end
    -- (the handwriting font's apostrophes read like an I: left out)
    note.text:SetText(motto and (motto:gsub("'", "")) or "Write your motto...")
    note.text:SetAlpha(motto and 1 or 0.45)
    if not note.box:IsShown() then page.SizeNote() end
    note.pin:ClearAllPoints()
    note.pin:SetPoint("CENTER", note, "TOP", 0, -1)
    note:ClearAllPoints()
    note:SetPoint("TOP", UI.window, "TOPLEFT", PORTRAIT.x, -PORTRAIT.note + 17)  -- (its top fixed: more lines grow down)
    -- An opened picture's layers and buttons.
    local traits = view and ns.MintTraits(mint.traits) or {}
    for i, line in ipairs(top.traits) do
        local trait = traits[i]
        line:SetShown(trait ~= nil)
        if trait then
            line:SetText(("|cffffd100%s:|r |c%s%s|r"):format(trait[1], ns.RARITY_COLORS[trait[3]] or "ffffffff", trait[2]))
            if line:GetStringWidth() > PORTRAIT.traits.width then  -- (too long: the shorter label)
                line:SetText(("|cffffd100%s:|r |c%s%s|r"):format(SHORT_LABELS[trait[1]] or trait[1], ns.RARITY_COLORS[trait[3]] or "ffffffff", trait[2]))
            end
        end
    end
    local b = top.buttons
    for _, button in ipairs(b) do button:SetShown(view and true or false) end
    if view then
        b[1].text:SetText("BACK")
        b[1].action = function() page.CloseView() end
        local shown
        for i, m in ipairs(ns.GetShowcase()) do if m.number == mint.number then shown = i end end
        local slot = page.viewingSlot
        if shown and (not slot or shown == slot) then
            b[2].text:SetText(("IN SPOT %d"):format(shown))
            b[2]:Disable()
        else
            b[2].text:SetText(slot and ("HANG IN SPOT %d"):format(slot) or "HANG IT")
            b[2]:Enable()
            b[2].action = function() HangInShowcase(mint, slot) end
        end
        b[3].text:SetText("GALLERY")
        b[3].action = function() page.OpenGallery() end
        for _, button in ipairs(b) do button:Paint(false) end
    end
end

-- EDIT (yours): your look, changed in place - every pick shows on your portrait at once, kept with SAVE (CANCEL, or
-- another tab, drops it). On the left slot under the tabs: the groups' tabs, then what you have for the one picked
-- (two columns; the mouse wheel scrolls), then CANCEL and SAVE. page.edit = the draft { traits, frame, header (the header choices to put back), tab }.
local EDIT = { left = 247, top = 327, width = 370, height = 397, row = 24, cell = 42, cols = 2, rows = 6, thumb = 34 }
local EDIT_GROUPS = {
    { "OGRE", { { "skin", "Skin" }, { "eyes", "Eyes" }, { "expression", "Expression" } } },
    { "WEAR", { { "outfit", "Clothes" }, { "headwear", "Headwear" }, { "accessory", "Accessory" } } },
    { "PICTURE", { { "background", "Background" }, { "frame", "Frame" } } },
    { "ME", { { "name", "Name colour" }, { "header", "Header" } } },
}
local CREAM, GOLD_TEXT = { 0.93, 0.88, 0.78 }, { 1, 0.82, 0 }
-- (the header's choices, changed as you pick in its panel: kept when EDIT opens, put back by CANCEL)
local HEADER_FIELDS = { "headerBg", "cropX", "cropY", "cropZoom", "nameColor", "bgColor" }

-- Where a piece you don't have comes from (its unlock key, Unlocks.lua), in a few words.
local function HowToGet(option, nextDeed)
    local kind, a, b = tostring(option.unlock or ""):match("^(%w+):([^:]*):?(.*)$")
    local d = a and ns.DungeonByKey and ns.DungeonByKey(a)
    if kind == "clear" then return (d and d.name or "A dungeon") .. " chests"
    elseif kind == "chase" then return "Chase: " .. (d and d.name or "a dungeon") .. " chests"
    elseif kind == "deed" then
        local title = ns.AchievementTitle and ns.AchievementTitle(option.unlock:sub(6))
        return (nextDeed and ("Next deed (" .. nextDeed .. "): ") or "Deed: ") .. (title or "a deed")
    elseif kind == "rank" then return "Ogre Rank " .. a
    elseif kind == "combine" then return "Combine its pieces"
    elseif kind == "loot" then return "Loot it"
    elseif kind == "shop" then return "Pro Shop: " .. (ns.ShopPrice(option) or "?") .. " points" end
    return "Not yours yet"
end
-- The pieces you've seen: on guildmates (their ogre on their Overview, a picture of theirs opened), in the Pro Shop, and your
-- next deed step's rewards (each ladder's lowest step you haven't earned): "layer:id" = true. Built when it's turned on.
local function SeenPieces()
    local seen, nextDeed = {}, {}
    for _, row in ipairs(ns.GetAchievementProgress and ns.GetAchievementProgress() or {}) do  -- (your next tier on each ladder you've started)
        if row.next and row.next.id then nextDeed[row.next.id] = ("%d/%d"):format(row.kills or 0, row.next.kills or 0) end
    end
    for _, layer in ipairs(ns.MintLayers or {}) do
        for _, option in ipairs(layer.options) do
            local unlock = option.unlock or ""
            if unlock:find("^shop:") then seen[layer.key .. ":" .. option.id] = true end
            local progress = unlock:find("^deed:") and nextDeed[unlock:sub(6)]
            if progress then seen[layer.key .. ":" .. option.id] = progress end
        end
    end
    for piece in pairs(KillTrackerDB.seenPieces or {}) do seen[piece] = seen[piece] or true end  -- (on guildmates: ns.SeePieces)
    return seen
end

-- The choices for one of the editor's tabs: { id, name, color (RGB, for the name), texture (its thumbnail) or swatch }.
local function EditChoices(tab, draft)
    local list = {}
    if tab == "frame" then
        for _, frame in ipairs(ns.PICTURE_FRAMES or {}) do
            if ns.FrameUnlocked(frame) then list[#list + 1] = { id = frame.id, name = frame.name, color = CREAM, texture = frame.texture } end
        end
    elseif tab == "name" then
        for _, entry in ipairs(ns.Colors()) do
            if ns.HasNameColor(entry) then list[#list + 1] = { id = entry.id, name = entry.name, color = entry.value, swatch = entry.value } end
        end
    elseif tab == "header" then  -- (a background picture you have, then a plain colour: your skins' own)
        for _, option in ipairs(ns.OwnedBackgrounds()) do
            local hex = ns.RARITY_COLORS[option.rarity] or "ffffffff"
            list[#list + 1] = { id = option.id, name = option.name, texture = ns.MintTexture(option, {}),
                color = { tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255, tonumber(hex:sub(7, 8), 16) / 255 } }
        end
        for _, entry in ipairs(ns.Colors()) do
            if ns.HasNameColor(entry) then list[#list + 1] = { id = "c:" .. entry.id, name = entry.name .. " wash", color = CREAM, fill = entry.base } end
        end
    else
        local owned = {}
        local function Add(option, extra)
            local hex = ns.RARITY_COLORS[option.rarity] or "ffffffff"
            local choice = { id = option.id, name = option.name,
                color = { tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255, tonumber(hex:sub(7, 8), 16) / 255 },
                texture = ns.MintTexture(option, draft.traits) }
            for k, v in pairs(extra or {}) do choice[k] = v end
            list[#list + 1] = choice
        end
        for _, option in ipairs(ns.OwnedOptions(tab)) do owned[option.id] = true Add(option) end
        if draft.seenToo then
            local layer
            for _, l in ipairs(ns.MintLayers or {}) do if l.key == tab then layer = l end end
            local seen = draft.seenPieces or {}
            for _, option in ipairs(layer and layer.options or {}) do
                if not owned[option.id] and not option.retired then
                    local why = seen[tab .. ":" .. option.id]
                    if why then Add(option, { notMine = true, how = HowToGet(option, why ~= true and why or nil) }) end  -- (unseen: not shown at all)
                end
            end
        end
    end
    return list
end
local function WearsNotMine(draft)
    for _, layer in ipairs(ns.MintLayers or {}) do
        local id = draft.traits[layer.key]
        if id then
            local mine = false
            for _, option in ipairs(ns.OwnedOptions(layer.key)) do if option.id == id then mine = true end end
            if not mine then return true end
        end
    end
    return false
end
local function EditCurrent(tab, draft)
    local card = KillTrackerDB.card or {}
    if tab == "frame" then return draft.frame elseif tab == "name" then return card.nameColor or "white" end
    if tab == "header" then return ns.BackgroundOption(nil, card.headerBg) and card.headerBg or ("c:" .. (card.bgColor or "white")) end
    return draft.traits[tab]
end

local function SmallButton(parent, width, label, height, size)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, height or 22)
    button.back = button:CreateTexture(nil, "BACKGROUND")
    button.back:SetAllPoints()
    button.text = button:CreateFontString(nil, "OVERLAY")
    button.text:SetFont(NAME_FONT, size or 12, "")
    button.text:SetPoint("CENTER", 0, 1)
    button.text:SetText(label)
    UI.OutlineText(button.text, { 0, 0, 0 })
    function button:Paint(lit)
        local on = lit or self.selected
        self.back:SetColorTexture(unpack(self.pressed and { 0.11, 0.07, 0.04 } or self.selected and { 0.45, 0.31, 0.15 }
            or lit and { 0.32, 0.22, 0.12 } or { 0.2, 0.13, 0.07 }))
        self.text:SetTextColor(unpack(self.selected and GOLD_TEXT or on and { 1, 1, 1 } or CREAM))
    end
    button:SetScript("OnEnter", function(self) self.hover = true self:Paint(true) end)
    button:SetScript("OnLeave", function(self) self.hover, self.pressed = false, false self:Dip(false) self:Paint(false) end)
    function button:Dip(down)  -- (pressed: the label and its icon a pixel lower)
        local x, y = self.textX or 0, (self.textY or 1) - (down and 2 or 0)
        self.text:ClearAllPoints()
        self.text:SetPoint("CENTER", x, y)
    end
    button:SetScript("OnMouseDown", function(self) if self:IsEnabled() then self.pressed = true self:Dip(true) self:Paint(true) end end)
    button:SetScript("OnMouseUp", function(self) self.pressed = false self:Dip(false) self:Paint(self.hover) end)
    button:Paint(false)
    return button
end

local function BuildEditor(page, parent)
    local W = UI.window
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetSize(EDIT.width, EDIT.height)
    panel:SetPoint("TOPLEFT", W, "TOPLEFT", EDIT.left, -EDIT.top)
    panel:Hide()
    local board = panel:CreateTexture(nil, "BACKGROUND", nil, -8)
    board:SetPoint("TOPLEFT", W, "TOPLEFT", UI.SPLIT.under.left, -LEFT.tabs.bottom)
    board:SetPoint("BOTTOMRIGHT", W, "TOPLEFT", UI.SPLIT.under.middle, -UI.SPLIT.under.bottom)
    board:SetColorTexture(0.03, 0.03, 0.03)
    local hint = panel:CreateFontString(nil, "OVERLAY")
    hint:SetFont(NAME_FONT, 12, "")
    hint:SetPoint("TOPLEFT", 2, -2)
    hint:SetTextColor(0.62, 0.56, 0.48)
    hint:SetText("Changes show on your portrait as you pick")
    panel.hint = hint
    local seenToggle = SmallButton(panel, 96, "MINE")
    seenToggle:SetPoint("TOPRIGHT", 0, 2)
    seenToggle:SetScript("OnClick", function(self)
        local edit = page.edit
        if not edit then return end
        UI.ClickSound()
        edit.seenToo = not edit.seenToo
        if edit.seenToo then edit.seenPieces = SeenPieces() end
        edit.offset = 0
        panel:Refresh()
    end)
    seenToggle:SetScript("OnEnter", function(self) self:Paint(true) SetTooltip(self, { "Mine / Mine + seen",
        "Also show what you've seen: on guildmates' ogres and pictures, in the Pro Shop, your next deeds' rewards" }) end)
    panel.seenToggle = seenToggle
    -- The groups' tabs.
    panel.tabs = {}
    for g, group in ipairs(EDIT_GROUPS) do
        local y = -20 - (g - 1) * (EDIT.row + 3)
        local label = panel:CreateFontString(nil, "OVERLAY")
        label:SetFont(NAME_FONT, 11, "")
        label:SetPoint("TOPLEFT", 2, y - 6)
        label:SetTextColor(0.72, 0.65, 0.51)
        label:SetText(group[1])
        local x = 62
        for _, spec in ipairs(group[2]) do
            local button = SmallButton(panel, spec[2]:len() * 7 + 18, spec[2])
            button:SetPoint("TOPLEFT", x, y)
            button:SetScript("OnClick", function()
                UI.ClickSound()
                page.edit.tab, page.edit.offset = spec[1], 0
                panel:Refresh()
            end)
            button.tab = spec[1]
            panel.tabs[#panel.tabs + 1] = button
            x = x + button:GetWidth() + 4
        end
    end
    -- The list: what you have for the tab picked, two columns.
    local listTop = -20 - #EDIT_GROUPS * (EDIT.row + 3) - 6
    local list = CreateFrame("Frame", nil, panel)
    list:SetPoint("TOPLEFT", 0, listTop - 4)  -- (13 px of grey round the cells on every side)
    list:SetSize(EDIT.width, EDIT.cell * EDIT.rows + 6)
    local back = panel:CreateTexture(nil, "BACKGROUND", nil, -7)  -- (grey under the list, to the slot's bottom)
    back:SetPoint("TOPLEFT", W, "TOPLEFT", UI.SPLIT.under.left, -(EDIT.top - listTop - 5))  -- (halfway from the tabs above)
    back:SetPoint("BOTTOMRIGHT", W, "TOPLEFT", UI.SPLIT.under.middle, -UI.SPLIT.under.bottom)
    back:SetColorTexture(0.1, 0.1, 0.1)
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta)
        local edit = page.edit
        local rows = math.ceil(#EditChoices(edit.tab, edit) / EDIT.cols)
        edit.offset = math.max(0, math.min(math.max(0, rows - EDIT.rows), (edit.offset or 0) - delta))
        panel:Refresh()
    end)
    local cellWidth = (EDIT.width - 9) / EDIT.cols
    panel.cells = {}
    for i = 1, EDIT.cols * EDIT.rows do
        local cell = CreateFrame("Button", nil, list)
        cell:SetSize(cellWidth, EDIT.cell - 3)
        cell:SetPoint("TOPLEFT", 3 + ((i - 1) % EDIT.cols) * (cellWidth + 3), -3 - math.floor((i - 1) / EDIT.cols) * EDIT.cell)
        cell.back = cell:CreateTexture(nil, "BACKGROUND")
        cell.back:SetAllPoints()
        cell.rim = {}
        for side = 1, 4 do  -- (picked: a gold rim)
            local edge = cell:CreateTexture(nil, "BORDER")
            edge:SetColorTexture(1, 0.82, 0.3)
            if side <= 2 then edge:SetHeight(2) edge:SetPoint("LEFT") edge:SetPoint("RIGHT") edge:SetPoint(side == 1 and "TOP" or "BOTTOM")
            else edge:SetWidth(2) edge:SetPoint("TOP") edge:SetPoint("BOTTOM") edge:SetPoint(side == 3 and "LEFT" or "RIGHT") end
            cell.rim[side] = edge
        end
        cell.thumb = cell:CreateTexture(nil, "ARTWORK")
        cell.thumb:SetSize(EDIT.thumb, EDIT.thumb)
        cell.thumb:SetPoint("LEFT", 3, 0)
        cell.swatch = cell:CreateFontString(nil, "OVERLAY")
        cell.swatch:SetFont(NAME_FONT, 16, "")
        cell.swatch:SetPoint("CENTER", cell.thumb)
        cell.swatch:SetText("Aa")
        UI.OutlineText(cell.swatch, { 0, 0, 0 })
        cell.name = cell:CreateFontString(nil, "OVERLAY")
        cell.name:SetFont(NAME_FONT, 12, "")
        cell.name:SetPoint("LEFT", cell.thumb, "RIGHT", 6, 0)
        cell.name:SetPoint("RIGHT", -18, 0)
        cell.name:SetJustifyH("LEFT")
        cell.name:SetWordWrap(false)
        UI.OutlineText(cell.name, { 0, 0, 0 })
        cell.how = cell:CreateFontString(nil, "OVERLAY")
        cell.how:SetFont(NAME_FONT, 11, "")
        cell.how:SetPoint("TOPLEFT", cell.name, "BOTTOMLEFT", 0, -1)
        cell.how:SetPoint("RIGHT", -4, 0)
        cell.how:SetJustifyH("LEFT")
        cell.how:SetWordWrap(false)
        cell.how:SetTextColor(0.91, 0.65, 0.42)
        UI.OutlineText(cell.how, { 0, 0, 0 })
        cell.tick = cell:CreateTexture(nil, "OVERLAY")
        cell.tick:SetSize(16, 16)
        cell.tick:SetPoint("TOPRIGHT", -2, -2)
        cell.tick:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        cell:SetScript("OnEnter", function(self)
            self.hover = true
            panel:PaintCell(self)
            local c = self.choice
            if c and (c.notMine or c.mystery) then SetTooltip(self, { c.mystery and "???" or c.name, c.how, c.notMine and "Try it on: not yours to keep yet" or nil }) end
        end)
        cell:SetScript("OnLeave", function(self) self.hover = false panel:PaintCell(self) GameTooltip_Hide() end)
        cell:SetScript("OnClick", function(self)
            local edit, choice = page.edit, self.choice
            if not choice or choice.mystery then return end
            UI.ClickSound()
            if edit.tab == "frame" then edit.frame = choice.id
            elseif edit.tab == "name" or edit.tab == "header" then  -- (your card, live; CANCEL puts it back)
                local card = KillTrackerDB.card or {}
                KillTrackerDB.card = card
                if edit.tab == "name" then card.nameColor = choice.id ~= "white" and choice.id or nil
                elseif choice.id:find("^c:") then card.headerBg, card.bgColor = nil, choice.id:sub(3) ~= "white" and choice.id:sub(3) or nil
                else
                    if card.headerBg ~= choice.id then card.cropX, card.cropY, card.cropZoom = nil, nil, nil end
                    card.headerBg = choice.id
                end
                if UI.RedrawHeader then UI.RedrawHeader() end
            else  -- (a new table: the portrait is redrawn only for different traits, ns.DrawMint)
                local traits = {}
                for k, id in pairs(edit.traits) do traits[k] = id end
                traits[edit.tab] = choice.id
                edit.traits = traits
            end
            page.RefreshNow()
        end)
        panel.cells[i] = cell
    end
    panel:SetScript("OnHide", function() if UI.SetHeaderCropping then UI.SetHeaderCropping(false) end end)
    panel.cropHint = panel:CreateFontString(nil, "OVERLAY")  -- (Header: what the board does meanwhile)
    panel.cropHint:SetFont(NAME_FONT, 12, "")
    panel.cropHint:SetPoint("TOPLEFT", 2, -2)
    panel.cropHint:SetTextColor(1, 0.82, 0.3)
    panel.cropHint:SetText("Drag your header's picture to move it, scroll to zoom")
    panel.cropHint:Hide()
    function panel:PaintCell(cell)
        local picked, c = cell.picked, cell.choice or {}
        local trying = picked and c.notMine
        cell.back:SetColorTexture(unpack(trying and { 0.4, 0.22, 0.08, 0.6 } or picked and { 0.35, 0.27, 0.09, 0.9 }
            or cell.hover and { 1, 1, 1, 0.1 } or { 1, 1, 1, 0.04 }))
        for _, edge in ipairs(cell.rim) do
            edge:SetShown(picked)
            edge:SetColorTexture(unpack(trying and { 0.91, 0.65, 0.42 } or { 1, 0.82, 0.3 }))
        end
        cell.tick:SetShown(picked and not trying)
        cell:SetAlpha((c.notMine and not picked or c.mystery) and 0.55 or 1)
    end
    -- CANCEL and SAVE.
    -- CANCEL and SAVE: big, under your portrait in the motto's place (shown by ShowPortrait while editing).
    local buttons = CreateFrame("Frame", nil, page.portraitTop)
    buttons:SetAllPoints()
    buttons:SetFrameLevel(page.portraitTop:GetFrameLevel() + 12)
    buttons:Hide()
    page.editButtons = buttons
    -- SAVE is the main one (gold, a tick); it only wakes once something's changed, then pulses gently. CANCEL dimmer
    -- (cream, a cross). Enter saves, Escape cancels. Saving flashes the portrait's frame.
    local function Icon(button, file)
        local icon = button:CreateTexture(nil, "OVERLAY")
        icon:SetSize(18, 18)
        icon:SetTexture(file)
        button.textX = 10
        button.text:ClearAllPoints()
        button.text:SetPoint("CENTER", 10, 1)
        icon:SetPoint("RIGHT", button.text, "LEFT", -6, 0)
        button.icon = icon
    end
    local save = SmallButton(buttons, 140, "SAVE", 36, 18)
    save:SetPoint("CENTER", W, "TOPLEFT", PORTRAIT.x + 76, -PORTRAIT.note)
    Icon(save, "Interface\\RaidFrame\\ReadyCheck-Ready")
    save.glow = save:CreateTexture(nil, "BORDER")
    save.glow:SetPoint("TOPLEFT", -3, 3)
    save.glow:SetPoint("BOTTOMRIGHT", 3, -3)
    save.glow:SetColorTexture(1, 0.78, 0.25)
    save.glow:Hide()
    local cancel = SmallButton(buttons, 140, "CANCEL", 36, 18)
    cancel:SetPoint("CENTER", W, "TOPLEFT", PORTRAIT.x - 76, -PORTRAIT.note)
    Icon(cancel, "Interface\\RaidFrame\\ReadyCheck-NotReady")
    cancel.icon:SetAlpha(0.7)
    -- (whether the draft differs from what's saved)
    local function Changed()
        local edit, card = page.edit, KillTrackerDB.card or {}
        if not edit then return false end
        if edit.frame ~= (card.frame or DEFAULT_PORTRAIT_FRAME) then return true end
        for _, field in ipairs(HEADER_FIELDS) do if card[field] ~= edit.header[field] then return true end end
        local saved = ns.BaseTraits()
        for k, id in pairs(edit.traits) do if saved[k] ~= id then return true end end
        for k, id in pairs(saved) do if edit.traits[k] ~= id then return true end end
        return false
    end
    -- (SAVE asleep: dim, unclickable; awake: gold, pulsing)
    local paintSave = save.Paint
    function save:Paint(lit)
        paintSave(self, lit)
        local awake = self:IsEnabled()
        self.text:SetTextColor(unpack(awake and GOLD_TEXT or { 0.5, 0.45, 0.36 }))
        self.icon:SetDesaturated(not awake)
        self.icon:SetAlpha(awake and 1 or 0.4)
        self.glow:SetShown(awake)
    end
    save:SetScript("OnEnter", function(self)
        self.hover = true self:Paint(true)
        if page.edit and WearsNotMine(page.edit) then SetTooltip(self, { "Not yet", "Take off what isn't yours first" }) end
    end)
    save:SetScript("OnLeave", function(self) self.hover, self.pressed = false, false self:Dip(false) self:Paint(false) GameTooltip_Hide() end)
    save:SetScript("OnUpdate", function(self)
        if self.glow:IsShown() then self.glow:SetAlpha(0.18 + 0.22 * (0.5 + 0.5 * math.sin(GetTime() * 4))) end
    end)
    function page.PaintEditButtons()
        save:SetEnabled(Changed() and not (page.edit and WearsNotMine(page.edit)))
        save:Paint(false)
        cancel:Paint(false)
        cancel.text:SetTextColor(0.8, 0.75, 0.66)
    end
    local function Flash()  -- (the new look hung: the frame lights up and fades)
        local top, start = page.portraitTop, GetTime()
        top.frameGlow:SetTexture(top.frame:GetTexture())
        top.frameGlow:Show()
        local flasher = page.portraitFlash or CreateFrame("Frame")
        page.portraitFlash = flasher
        flasher:SetScript("OnUpdate", function(self)
            local t = (GetTime() - start) / 1.2
            if t >= 1 then top.frameGlow:Hide() self:SetScript("OnUpdate", nil) return end
            top.frameGlow:SetAlpha(0.85 * (1 - t) ^ 2)
        end)
    end
    save:SetScript("OnClick", function()
        local edit = page.edit
        if not edit or not Changed() or WearsNotMine(edit) then return end
        UI.ClickSound()
        local card = KillTrackerDB.card or {}
        KillTrackerDB.card = card
        card.frame = edit.frame ~= DEFAULT_PORTRAIT_FRAME and edit.frame or nil
        page.edit = nil
        ns.SetOgre(edit.traits)  -- (syncs the card, all of it)
        page.ShowPanel(nil)
        Flash()
    end)
    cancel:SetScript("OnClick", function() UI.ClickSound() page.ShowPanel(nil) end)  -- (ShowPanel drops the draft)
    -- Enter saves, Escape cancels (out of combat: keys can't be caught in it); other keys go on to the game.
    buttons:SetScript("OnKeyDown", function(self, key)
        if InCombatLockdown() then return end
        local mine = key == "ENTER" or key == "ESCAPE"
        self:SetPropagateKeyboardInput(not mine)
        if key == "ENTER" then save:Click() elseif key == "ESCAPE" then cancel:Click() end
    end)
    buttons:SetScript("OnShow", function(self) if not InCombatLockdown() then self:EnableKeyboard(true) end end)
    buttons:SetScript("OnHide", function(self) if not InCombatLockdown() then self:EnableKeyboard(false) end end)
    function panel:Refresh()
        local edit = page.edit
        if not edit then return end
        for _, button in ipairs(self.tabs) do button.selected = button.tab == edit.tab button:Paint(false) end
        self.seenToggle.text:SetText(edit.seenToo and "MINE + SEEN" or "MINE")
        self.seenToggle.selected = edit.seenToo
        self.seenToggle:Paint(false)
        self.seenToggle:SetShown(edit.tab ~= "frame" and edit.tab ~= "name" and edit.tab ~= "header")
        local onHeader = edit.tab == "header"
        if UI.SetHeaderCropping then UI.SetHeaderCropping(onHeader) end
        self.cropHint:SetShown(onHeader)
        self.hint:SetShown(not onHeader)
        local choices, current = EditChoices(edit.tab, edit), EditCurrent(edit.tab, edit)
        local first = (edit.offset or 0) * EDIT.cols
        for i, cell in ipairs(self.cells) do
            local choice = choices[first + i]
            cell.choice = choice
            cell:SetShown(choice ~= nil)
            if choice then
                cell.picked = choice.id == current
                cell.name:SetText(choice.name)
                cell.how:SetText(choice.how or "")
                cell.how:SetShown(choice.how ~= nil)
                cell.name:ClearAllPoints()  -- (with a second line: the name up a little)
                cell.name:SetPoint("LEFT", cell.thumb, "RIGHT", 6, choice.how and 6 or 0)
                cell.name:SetPoint("RIGHT", -18, 0)
                cell.name:SetTextColor(unpack(choice.color))
                cell.thumb:SetTexture(choice.texture or "Interface\\Buttons\\WHITE8X8")
                cell.thumb:SetShown(not choice.mystery)
                if choice.swatch then cell.thumb:SetVertexColor(0.08, 0.05, 0.03)
                elseif choice.fill then cell.thumb:SetVertexColor(unpack(choice.fill))
                else cell.thumb:SetVertexColor(1, 1, 1) end
                cell.swatch:SetShown(choice.swatch ~= nil)
                if choice.swatch then cell.swatch:SetTextColor(unpack(choice.swatch)) end
                self:PaintCell(cell)
            end
        end
    end
    return panel
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
                page.feedBeam = UI.CrossBeam(book, LEFT.left, LEFT.right, bandTop, nil, band[1] - bandTop, true)
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
                if not page.key and button == "LeftButton" then UI.ClickSound() page.ShowPanel("edit") end
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
        page.makePrompt:SetScript("OnClick", function() UI.ClickSound() page.ShowPanel("edit") end)
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

        -- The showcase's pictures, side by side: no box round them, each hanging in its own frame (Minting.lua), a touch
        -- crooked. An empty one of yours: a chalk outline with a +. A spot a picture is dragged over glows gold.
        local pictures = LEFT.pictures
        page.polaroids = {}
        for i, x in ipairs(pictures.lefts) do
            local holder = CreateFrame("Button", nil, left)
            holder:SetSize(pictures.size, pictures.size)
            At(holder, "TOPLEFT", x, pictures.top)
            holder:SetFrameLevel(left:GetFrameLevel() + 2 + pictures.levels[i] * 3)
            local tilt = pictures.tilts[i]
            holder.tilt = tilt
            -- A little shake (a picture dragged onto it, Gallery.lua): side to side, dying down.
            function holder:Shake()
                self.shaking = 0
                self:SetScript("OnUpdate", function(s, elapsed)
                    s.shaking = s.shaking + elapsed
                    local left = 1 - s.shaking / 0.35
                    s:ClearAllPoints()
                    if left <= 0 then
                        At(s, "TOPLEFT", x, pictures.top)
                        if s.mint then ns.DrawMint(s.canvas, s.mint, tilt) end
                        s:SetScript("OnUpdate", nil)
                    else
                        local wobble = math.sin(s.shaking * 55) * left
                        At(s, "TOPLEFT", x + wobble * 2, pictures.top)
                        if s.mint then ns.DrawMint(s.canvas, s.mint, tilt + math.floor(wobble * 3 + 0.5) / 2) end  -- (rocking, up to 1.5 degrees)
                    end
                end)
            end
            holder.slot = i
            holder.glow = holder:CreateTexture(nil, "BACKGROUND")
            holder.glow:SetPoint("CENTER")
            holder.glow:SetSize(pictures.size * 1.25, pictures.size * 1.25)
            holder.glow:SetTexture(ART .. "Glow")
            holder.glow:SetVertexColor(1, 0.82, 0.3, 0.8)
            holder.glow:SetBlendMode("ADD")
            holder.glow:Hide()
            holder.canvas = CreateFrame("Frame", nil, holder)
            holder.canvas:SetAllPoints()
            holder.outline = holder:CreateTexture(nil, "ARTWORK")  -- (an empty spot: chalk)
            holder.outline:SetPoint("CENTER")
            holder.outline:SetSize(pictures.size * 0.82, pictures.size * 0.82)
            holder.outline:SetTexture(ART .. "Dashed")
            holder.outline:SetVertexColor(0.86, 0.82, 0.74, 0.4)
            holder.outline:SetRotation(-math.rad(tilt))
            holder.empty = holder:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
            holder.empty:SetPoint("CENTER")
            holder.empty:SetText("+")
            holder.empty:SetTextColor(0.86, 0.82, 0.74, 0.55)
            holder:RegisterForDrag("LeftButton")
            function holder:paint(lit)  -- lit: a picture being dragged over it (Gallery.lua)
                self.glow:SetShown(lit and true or false)
            end
            holder:SetScript("OnClick", function(self)
                UI.ClickSound()
                if not self.key and self.mint then
                    page.OpenView(self.mint, false, self.slot)  -- yours: it, big, in the portrait's place
                elseif not self.key then
                    page.OpenGallery()  -- an empty spot of yours: your gallery, to drag a picture in (Gallery.lua)
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
        function page.OpenView(mint, fromGallery, slot)
            page.CloseDetail()
            page.gallery:Hide()
            page.building, page.buildingFromGallery = nil, nil
            page.viewing, page.viewingFromGallery, page.viewingSlot = mint, fromGallery, slot
            page.photo:Show()
            page.hung:Show()
            OVERVIEW.refresh(page)
        end
        function page.CloseView()
            local fromGallery = page.viewingFromGallery
            page.viewing, page.viewingFromGallery, page.viewingSlot = nil, nil, nil
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
            page.portraitTop:Hide()
            if UI.SetTab then UI.SetTab("overview", "Gallery", "PIX") end
        end
        function page.CloseGallery()
            if not page.gallery:IsShown() then return end
            page.gallery:Hide()
            page.photo:SetShown(page.panel ~= "crafts")
            page.hung:SetShown(page.panel ~= "crafts")
            if UI.SetTab then UI.SetTab("overview", TAB_TITLES[page.panel or "me"], page.panel and TABS_OGRE[page.panel]) end
            if page.loaded then OVERVIEW.refresh(page) end  -- (the portrait back)
        end
        function page.OpenDetail(item)
            page.gallery:Hide()
            page.detail:ShowItem(item)
            page.photo:Hide()
            page.hung:Hide()
            page.portraitTop:Hide()
            PaintFeed()
        end
        function page.CloseDetail()
            if not page.detail:IsShown() then return end
            page.detail:Hide()
            page.photo:SetShown(page.panel ~= "crafts")
            page.hung:SetShown(page.panel ~= "crafts")
            PaintFeed()
            if page.loaded then OVERVIEW.refresh(page) end  -- (the portrait back)
        end
        -- The portrait (ME, nothing else open): click it (yours) to change your look, right-click for its frame and
        -- your motto; someone else's picture opens.
        BuildPortrait(page, function(button)
            local mint = page.portraitMint
            if not mint then return end
            if page.viewing and mint == page.viewing then  -- (an opened picture: turn it over, right-click its menu)
                if button == "RightButton" then return PictureMenu(page.portraitTop.picture, mint, function() OVERVIEW.refresh(page) end) end
                UI.ClickSound()
                page.reading = not page.reading
                return OVERVIEW.refresh(page)
            end
            if not page.key then
                if button == "RightButton" then return PortraitMenu(page.portraitTop.picture) end
                UI.ClickSound()
                if page.panel ~= "edit" then page.ShowPanel("edit") end
            elseif not mint.ogre then
                UI.ClickSound()
                ns.ShowMint(mint, Ambiguate(page.key, "short"))
            end
        end)

        page.gearPanel = GearPage(page)
        page.gearPanel:SetFrameLevel(left:GetFrameLevel() + 20)
        page.craftsPanel = CraftsPage(page)
        page.craftsPanel:SetFrameLevel(left:GetFrameLevel() + 20)
        page.RefreshNow = function() OVERVIEW.refresh(page) end
        page.editPanel = BuildEditor(page, page)
        page.editPanel:SetFrameLevel(left:GetFrameLevel() + 20)

        -- The tabs: ME (the pictures and the feed), GEARZ, CRAFTS.
        local tabs = CreateFrame("Frame", nil, page)
        tabs:SetAllPoints()
        tabs:SetFrameLevel(left:GetFrameLevel() + 25)
        page.tabs = {}
        local function ShowPanel(which)
            if which == "edit" and page.key then which = nil end  -- (only yours)
            if which ~= "edit" and page.edit then  -- (left: not saved; the header's choices put back)
                local card, kept, changed = KillTrackerDB.card or {}, page.edit.header, false
                for _, field in ipairs(HEADER_FIELDS) do
                    if card[field] ~= kept[field] then card[field], changed = kept[field], true end
                end
                page.edit = nil
                if changed and UI.RedrawHeader then UI.RedrawHeader() end
            end
            if which == "edit" and not page.edit then
                local card = KillTrackerDB.card or {}
                page.edit = { traits = ns.BaseTraits(), frame = card.frame or DEFAULT_PORTRAIT_FRAME, header = {}, tab = "outfit", offset = 0,
                    seenToo = true, seenPieces = SeenPieces() }  -- (what you've seen shows by default, after yours)
                for _, field in ipairs(HEADER_FIELDS) do page.edit.header[field] = card[field] end
            end
            page.panel = which
            page.editPanel:SetShown(which == "edit")
            if page.feedBeam then page.feedBeam:SetShown(which ~= "edit") end  -- (the editor's board covers it all)
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
                self:SetShown(spec[1] ~= "edit" or not page.key)  -- (EDIT: yours only)
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
        if page.panel == "edit" and page.edit and not key then  -- (your look being changed: the draft)
            portrait = { traits = page.edit.traits, ogre = true, style = cardData and cardData.ogreStyle }
        end
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
        -- The portrait instead of the photo (ME, their ogre or picture, nothing else open: not a picture opened, not
        -- the builder, not the gallery or a feed line's details).
        local hanging = portrait ~= nil and (page.panel == nil or page.panel == "edit") and not page.building and not galleryOpen
            and not (page.detail and page.detail:IsShown())
        if hanging and key and portrait.ogre and ns.SeePieces then ns.SeePieces(portrait.traits) end  -- (their ogre: seen)
        if hanging then
            page.photo:Hide()
            page.hung:Hide()
            local edit = page.panel == "edit" and page.edit
            ShowPortrait(page, portrait, edit and { frame = edit.frame, motto = cardData and cardData.motto } or cardData,
                (p.name or ""):match("^(%S+)") or "", ns.GetNameColor(key), not key,
                page.viewing ~= nil and portrait == page.viewing)
        elseif page.panel ~= "crafts" and not galleryOpen and not (page.detail and page.detail:IsShown()) then
            page.photo:Show()
            page.hung:Show()
        end
        page.portraitTop:SetShown(hanging)
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
            holder.outline:SetShown(mint == nil)
            if mint then ns.DrawMint(holder.canvas, mint, holder.tilt) end
            holder:paint(false)
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
        if page.panel == "edit" then page.editPanel:Refresh() if page.PaintEditButtons then page.PaintEditButtons() end end
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
