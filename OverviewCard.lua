-- The Overview (ME). A split page (ProfileHeader.lua: the profile header over the left page, the middle
-- beam). In the left slot, under its tabs: ME (LEFT, from the designer's REFPIC_LEFT_SCREEN_OVERVIEW): their three
-- showcase pictures and what happened to them lately; GEARZ: their gear; CRAFTS: their professions, and the recipes
-- they know of one. On the right page (RIGHT, from REFPIC_RIGHT_SCREEN_OVERVIEW): their photo hung in a wooden frame,
-- their first name on its plaque.
-- The photo shows the character's model on the background they picked, or one of their pictures instead (right-click
-- your own photo); when there's no model of someone to show (their character isn't synced), their chosen picture
-- shows, else their first showcase picture, else their newest.
-- KillTrackerDB.card = { gender = "MALE" | "FEMALE" | "NONBINARY" (no longer shown), portrait = picture number, seq },
-- synced (Sync.lua, the card section).

local _, ns = ...
local UI = ns.UI
local Fit, SetTooltip = UI.FitText, UI.Tooltip

local ART = "Interface\\AddOns\\SOLC\\Media\\Overview\\"
local NAME_FONT = "Interface\\AddOns\\SOLC\\Media\\Fonts\\GermaniaOne-Regular.ttf"
local SIGN_FONT = "Interface\\AddOns\\SOLC\\Media\\Fonts\\FingerPaint-Regular.ttf"
local INK = { 0.16, 0.16, 0.18 }            -- the plaque's crayon
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
-- The right page, in window pixels: the board, the frame (its top-left; Media/Overview/HangingPicture at 1:1; in the
-- page's middle), the photo in it, the plaque on it. Centres unless said.
local RIGHT = {
    color = { 0.094, 0.094, 0.094 },
    frame = { x = 688, y = 214, w = 362, h = 447 },
    photo = { x = 869, y = 447.5, w = 308, h = 329 },
    plaque = { x = 874, y = 636, w = 170, size = 22 },
}
local CRAFT_ROW = { height = 24, size = 13, colors = { 0.25, 0.18 } }  -- CRAFTS' rows
local HEADING_COLOR = { 1, 0.85, 0.1 }
local FEED_AGO_COLOR = { 0.98, 0.64, 0.26 }
local FEED_HOVER_COLOR = { 0.65, 0.53, 0.28 }  -- the row under the mouse

-- The picture shown on your photo instead of your model: a picture number, or nil for your model.
local function ChoosePortrait(number)
    KillTrackerDB.card = KillTrackerDB.card or {}
    KillTrackerDB.card.portrait = number
    ns.Touch(KillTrackerDB.card)
    ns.OpenPage("overview")
end

-- Right-clicking your own photo: what it shows (your model or one of your pictures) and the background behind your
-- model (from the ones on your pictures).
local function PhotoMenu(owner)
    if not MenuUtil then return UI.PickBackdrop(owner) end  -- no menus: step through the backgrounds
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle("Photo")
        local chosen = KillTrackerDB.card and KillTrackerDB.card.portrait
        root:CreateRadio("My character", function() return chosen == nil end, function() ChoosePortrait(nil) end)
        local mints = KillTrackerDB.mints or {}
        for _, mint in ipairs(mints) do
            local name = ("|c%s%s|r"):format(ns.RARITY_COLORS[ns.MintRarity(mint.traits)] or "ffffffff", ("Picture #%d"):format(mint.number))
            root:CreateRadio(name, function() return chosen == mint.number end, function() ChoosePortrait(mint.number) end)
        end
        if #mints == 0 then root:CreateTitle("Mint a picture to show one here") end
        local background = root:CreateButton("Background behind my character")
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

-- GEARZ: their gear over the left slot, like a character sheet. Two columns of slots (icon with a rim in the item's
-- quality colour, its name and item level beside it), the weapons in a row under them, the average item level at the
-- top and the stats the gear adds up to at the bottom. Hover for the item, shift-click to link it. page: the Overview
-- page; returns a frame with :SetPlayer(key).
local GEAR_LEFT = { 1, 2, 3, 15, 5, 4, 19, 9 }
local GEAR_RIGHT = { 10, 6, 7, 8, 11, 12, 13, 14 }
local GEAR_WEAPONS = { 16, 17, 18 }
local SLOT_SIZE, SLOT_ROW = 28, 31
local GEAR_STAT_LINES = 8
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

local function GearPage(page)
    local gear = CreateFrame("Frame", nil, page)
    gear:SetPoint("TOPLEFT", UI.window, "TOPLEFT", GEAR_PANEL.left, -GEAR_PANEL.top)
    gear:SetSize(GEAR_PANEL.width, GEAR_PANEL.height)
    local shade = gear:CreateTexture(nil, "BACKGROUND")
    shade:SetPoint("TOPLEFT", -8, 8)
    shade:SetPoint("BOTTOMRIGHT", 8, -8)
    shade:SetColorTexture(0.05, 0.03, 0.02, 0.92)

    gear.average = gear:CreateFontString(nil, "OVERLAY")
    gear.average:SetFont(NAME_FONT, 13, "")
    gear.average:SetTextColor(unpack(FEED_COLOR))
    gear.average:SetPoint("TOPLEFT", 4, -2)
    gear.empty = gear:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    gear.empty:SetPoint("TOP", 0, -80)
    gear.empty:SetWidth(GEAR_PANEL.width - 20)
    gear.empty:SetText("No gear synced yet. It shows once they log in with SOLC 0.37.0 or newer.")

    -- A slot: the icon on a rim in the quality's colour (Media/Overview/Edge, soft-edged), name and level beside it
    -- (side: "left" column puts them right of the icon, "right" left of it, nil: under it, the weapons).
    local slots = {}
    local function Slot(slot, x, y, side)
        local cell = CreateFrame("Button", nil, gear)
        cell:SetSize(SLOT_SIZE, SLOT_SIZE)
        cell:SetPoint("TOPLEFT", x, -y)
        cell.slot = slot
        cell.rim = cell:CreateTexture(nil, "BACKGROUND")
        cell.rim:SetTexture(ART .. "Edge")
        cell.rim:SetPoint("CENTER")
        cell.rim:SetSize((SLOT_SIZE + 2 * RIM) / EDGE_FILL, (SLOT_SIZE + 2 * RIM) / EDGE_FILL)
        cell.icon = cell:CreateTexture(nil, "ARTWORK")
        cell.icon:SetPoint("TOPLEFT", 1, -1)
        cell.icon:SetPoint("BOTTOMRIGHT", -1, 1)
        cell.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        if side then
            cell.name = gear:CreateFontString(nil, "OVERLAY")
            cell.name:SetFont(NAME_FONT, 11, "")
            cell.name:SetWidth(GEAR_PANEL.width / 2 - SLOT_SIZE - 14)
            cell.name:SetWordWrap(false)
            cell.level = gear:CreateFontString(nil, "OVERLAY")
            cell.level:SetFont(NAME_FONT, 10, "")
            cell.level:SetTextColor(0.6, 0.55, 0.45)
            if side == "left" then
                cell.name:SetPoint("TOPLEFT", cell, "TOPRIGHT", 6, -3)
                cell.name:SetJustifyH("LEFT")
                cell.level:SetPoint("TOPLEFT", cell.name, "BOTTOMLEFT", 0, -2)
            else
                cell.name:SetPoint("TOPRIGHT", cell, "TOPLEFT", -6, -3)
                cell.name:SetJustifyH("RIGHT")
                cell.level:SetPoint("TOPRIGHT", cell.name, "BOTTOMRIGHT", 0, -2)
            end
        end
        cell:SetScript("OnEnter", function(self)
            if not self.item then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if gear.key then GameTooltip:SetHyperlink(self.item) else GameTooltip:SetInventoryItem("player", self.slot) end
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
    for i, slot in ipairs(GEAR_LEFT) do Slot(slot, 2, 22 + (i - 1) * SLOT_ROW, "left") end
    for i, slot in ipairs(GEAR_RIGHT) do Slot(slot, GEAR_PANEL.width - SLOT_SIZE - 2, 22 + (i - 1) * SLOT_ROW, "right") end
    for i, slot in ipairs(GEAR_WEAPONS) do
        Slot(slot, GEAR_PANEL.width / 2 - SLOT_SIZE / 2 + (i - 2) * (SLOT_SIZE + 14), 22 + #GEAR_LEFT * SLOT_ROW + 2)
    end

    -- The stats the gear adds up to, in two columns.
    local statsTop = 22 + #GEAR_LEFT * SLOT_ROW + SLOT_SIZE + 12
    local statsTitle = gear:CreateFontString(nil, "OVERLAY")
    statsTitle:SetFont(NAME_FONT, 14, "")
    statsTitle:SetTextColor(1, 0.82, 0.25)
    statsTitle:SetPoint("TOPLEFT", 4, -statsTop)
    statsTitle:SetText("Stats from gear")
    gear.statLines = {}
    for i = 1, GEAR_STAT_LINES do
        local line = gear:CreateFontString(nil, "OVERLAY")
        line:SetFont(NAME_FONT, 12, "")
        line:SetTextColor(unpack(FEED_COLOR))
        line:SetPoint("TOPLEFT", 4 + ((i - 1) % 2) * (GEAR_PANEL.width / 2), -statsTop - 18 - math.floor((i - 1) / 2) * 15)
        line:SetWidth(GEAR_PANEL.width / 2 - 8)
        line:SetJustifyH("LEFT")
        line:SetWordWrap(false)
        gear.statLines[i] = line
    end

    function gear:Refresh()
        local data = UI.GearData(self.key)
        self.empty:SetShown(not data.has)
        self.average:SetText(data.average and ("Item level %d"):format(data.average) or "")
        for _, cell in ipairs(slots) do
            local item = data.slots[cell.slot]
            cell:SetShown(data.has)
            if cell.name then cell.name:SetShown(data.has) cell.level:SetShown(data.has) end
            cell.item = item and item.item
            if item then
                cell.icon:SetTexture(item.texture or "Interface\\Icons\\INV_Misc_QuestionMark")
                cell.icon:SetDesaturated(false)
                local r, g, b = unpack(QUALITY_GREY)
                if item.quality then r, g, b = QualityColor(item.quality) end
                cell.rim:SetVertexColor(r, g, b)
                if cell.name then
                    cell.name:SetText(item.name or "...")
                    cell.name:SetTextColor(r, g, b)
                    cell.level:SetText(item.level and ("ilvl %d"):format(item.level) or "")
                end
            else
                local emptyTexture = GetInventorySlotInfo and select(2, GetInventorySlotInfo(UI.GEAR_SLOT_NAMES[cell.slot]))
                cell.icon:SetTexture(emptyTexture)
                cell.icon:SetDesaturated(true)
                cell.rim:SetVertexColor(unpack(QUALITY_GREY))
                if cell.name then
                    cell.name:SetText(_G[UI.GEAR_SLOT_NAMES[cell.slot]] or "")
                    cell.name:SetTextColor(0.4, 0.4, 0.4)
                    cell.level:SetText("")
                end
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
    gear:SetScript("OnShow", function(self) self:Refresh() end)
    return gear
end

-- CRAFTS: their professions over the left slot, a row each with its skill; click one for the recipes they know of it
-- (the first row goes back). page: the Overview page; returns a frame with :SetPlayer(key).
local function CraftsPage(page)
    local crafts = CreateFrame("Frame", nil, page)
    crafts:SetPoint("TOPLEFT", UI.window, "TOPLEFT", GEAR_PANEL.left, -GEAR_PANEL.top)
    crafts:SetSize(GEAR_PANEL.width, GEAR_PANEL.height)
    crafts:EnableMouseWheel(true)
    local shade = crafts:CreateTexture(nil, "BACKGROUND")
    shade:SetPoint("TOPLEFT", -8, 8)
    shade:SetPoint("BOTTOMRIGHT", 8, -8)
    shade:SetColorTexture(0.05, 0.03, 0.02, 0.92)
    crafts.offset = 0
    crafts.rows = {}
    for i = 1, math.floor(GEAR_PANEL.height / CRAFT_ROW.height) do
        local row = CreateFrame("Button", nil, crafts)
        row:SetSize(GEAR_PANEL.width, CRAFT_ROW.height)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * CRAFT_ROW.height)
        local tone = CRAFT_ROW.colors[i % 2 == 1 and 1 or 2]
        row.stripe = row:CreateTexture(nil, "BACKGROUND")
        row.stripe:SetAllPoints()
        row.bar = row:CreateTexture(nil, "BORDER")
        row.bar:SetPoint("BOTTOMLEFT")
        row.bar:SetHeight(3)
        row.bar:SetColorTexture(0.3, 0.6, 1, 0.9)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(18, 18)
        row.icon:SetPoint("LEFT", 4, 0)
        row.count = row:CreateFontString(nil, "OVERLAY")
        row.count:SetFont(NAME_FONT, CRAFT_ROW.size, "")
        row.count:SetTextColor(unpack(FEED_AGO_COLOR))
        row.count:SetPoint("RIGHT", -6, 1)
        row.label = row:CreateFontString(nil, "OVERLAY")
        row.label:SetFont(NAME_FONT, CRAFT_ROW.size, "")
        row.label:SetTextColor(0.94, 0.94, 0.94)
        row.label:SetPoint("LEFT", 28, 1)
        row.label:SetPoint("RIGHT", row.count, "LEFT", -8, 0)
        row.label:SetJustifyH("LEFT")
        row.label:SetWordWrap(false)
        function row:Paint(hovered) self.stripe:SetColorTexture(unpack(hovered and FEED_HOVER_COLOR or { tone, tone, tone })) end
        row:SetScript("OnEnter", function(self)
            local d = self.d
            if not d then return end
            self:Paint(true)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if d.recipe then
                GameTooltip:SetSpellByID(d.recipe)
            elseif d.back then
                GameTooltip:AddLine("Back to the professions")
            else
                GameTooltip:AddLine(d.prof.name)
                GameTooltip:AddLine(("Skill %d / %d"):format(d.prof.rank or 0, d.prof.max or 0), 1, 1, 1)
                GameTooltip:AddLine("Click for the recipes", 0.6, 0.6, 0.6)
            end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function(self) self:Paint(false) GameTooltip_Hide() end)
        row:SetScript("OnClick", function(self)
            local d = self.d
            if not d then return end
            if d.recipe then
                if IsModifiedClick("CHATLINK") and C_Spell and C_Spell.GetSpellLink then
                    local link = C_Spell.GetSpellLink(d.recipe)
                    if link then ChatEdit_InsertLink(link) end
                end
                return
            end
            UI.ClickSound()
            crafts.line = not d.back and d.prof.line or nil
            crafts.offset = 0
            crafts:Refresh()
        end)
        row:Paint(false)
        crafts.rows[i] = row
    end
    crafts.empty = crafts:CreateFontString(nil, "OVERLAY")
    crafts.empty:SetFont(NAME_FONT, 13, "")
    crafts.empty:SetTextColor(0.62, 0.56, 0.48)
    crafts.empty:SetPoint("TOP", 0, -60)
    crafts.empty:SetWidth(GEAR_PANEL.width - 30)

    function crafts:Refresh()
        local professions = ns.GetProfessions(self.key)
        local data = {}
        if self.line then
            local prof
            for _, p in ipairs(professions.list) do if p.line == self.line then prof = p end end
            data[1] = { back = true, label = ("|cffffd100<|r  %s"):format(prof and prof.name or "Back"),
                count = prof and ("%d/%d"):format(prof.rank or 0, prof.max or 0) or "", icon = prof and prof.icon }
            local recipes = {}
            for _, id in ipairs(professions.recipes and professions.recipes[self.line] or {}) do
                local name, icon = ns.RecipeInfo(id)
                if not name and C_Spell and C_Spell.RequestLoadSpellData then C_Spell.RequestLoadSpellData(id) end
                recipes[#recipes + 1] = { recipe = id, label = name or "...", icon = icon }
            end
            table.sort(recipes, function(a, b) return a.label < b.label end)
            for _, r in ipairs(recipes) do data[#data + 1] = r end
            self.empty:SetText(#recipes == 0 and "No recipes known yet. They show once that profession's window has been opened." or "")
        else
            for _, prof in ipairs(professions.list) do
                data[#data + 1] = { prof = prof, label = prof.name, count = ("%d/%d"):format(prof.rank or 0, prof.max or 0),
                    icon = prof.icon, share = (prof.rank or 0) / math.max(1, prof.max or 1) }
            end
            self.empty:SetText(#data == 0 and "No professions yet. They show once they log in with SOLC 0.37.0 or newer." or "")
        end
        self.data = data
        self.offset = math.min(self.offset, math.max(0, #data - #self.rows))
        for i, row in ipairs(self.rows) do
            local d = data[self.offset + i]
            row.d = d
            row:SetShown(d ~= nil)
            if d then
                row.label:SetText(d.label)
                row.count:SetText(d.count or "")
                row.icon:SetShown(d.icon ~= nil)
                if d.icon then row.icon:SetTexture(d.icon) end
                row.bar:SetShown(d.share ~= nil)
                if d.share then row.bar:SetWidth(math.max(1, GEAR_PANEL.width * math.min(1, d.share))) end
            end
        end
    end
    crafts:SetScript("OnMouseWheel", function(self, delta)
        local most = math.max(0, #(self.data or {}) - #self.rows)
        local offset = math.max(0, math.min(most, self.offset - delta * 3))
        if offset ~= self.offset then
            self.offset = offset
            self:Refresh()
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
        if not self:IsVisible() or not self.line or pending then return end
        pending = true
        C_Timer.After(0.5, function()
            pending = nil
            if self:IsVisible() then self:Refresh() end
        end)
    end)
    crafts:SetScript("OnShow", function(self) self:Refresh() end)
    return crafts
end

ns.RegisterPage({
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
            SetTooltip(self, { "Drag to turn, scroll to zoom", not page.key and "Right-click to show a picture instead, or pick a background" or nil })
        end)
        -- A picture instead of the model: square, as tall as the photo, its sides cut off by the photo's edges.
        photo:SetClipsChildren(true)
        page.portrait = CreateFrame("Frame", nil, photo)
        page.portrait:SetSize(card.photo.h, card.photo.h)
        page.portrait:SetPoint("CENTER")
        page.portrait:Hide()
        -- While it shows, the photo takes the clicks: left to open the picture, right (yours) for the menu.
        photo:SetScript("OnMouseUp", function(self, button)
            if not page.portraitMint then return end
            if button == "RightButton" and not page.key then
                PhotoMenu(self)
            elseif button == "LeftButton" then
                UI.ClickSound()
                ns.ShowMint(page.portraitMint, page.key and Ambiguate(page.key, "short") or nil)
            end
        end)
        photo:SetScript("OnEnter", function(self)
            if not page.portraitMint then return end
            SetTooltip(self, { ("Picture #%d"):format(page.portraitMint.number), "Click to view",
                not page.key and "Right-click to show your character instead" or nil })
        end)
        photo:SetScript("OnLeave", GameTooltip_Hide)
        model:SetScript("OnLeave", GameTooltip_Hide)
        page.empty = photo:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        page.empty:SetPoint("CENTER")
        page.empty:SetWidth(card.photo.w - 16)
        page.empty:SetText("No character synced yet. It shows once they log in with SOLC 0.37.0 or newer.")

        -- The frame over the photo's edges, and their first name on its plaque.
        local hung = CreateFrame("Frame", nil, cardFrame)
        hung:SetAllPoints()
        hung:SetFrameLevel(photo:GetFrameLevel() + 10)  -- over the model
        local frameArt = hung:CreateTexture(nil, "ARTWORK")
        frameArt:SetTexture(ART .. "HangingPicture")
        frameArt:SetTexCoord(0, RIGHT.frame.w / 512, 0, RIGHT.frame.h / 512)
        frameArt:SetSize(RIGHT.frame.w, RIGHT.frame.h)
        At(frameArt, "TOPLEFT", RIGHT.frame.x, RIGHT.frame.y)
        page.signature = hung:CreateFontString(nil, "OVERLAY")
        At(page.signature, "CENTER", RIGHT.plaque.x, RIGHT.plaque.y)
        page.signature:SetTextColor(unpack(INK))
        page.signature:SetShadowOffset(0, 0)
        page.signatureWidth = RIGHT.plaque.w

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
            holder:SetScript("OnClick", function(self)
                UI.ClickSound()
                if self.mint then
                    ns.ShowMint(self.mint, self.key and Ambiguate(self.key, "short") or nil)
                elseif not self.key then
                    ns.OpenPage("collection")  -- your pictures, to pick one
                end
            end)
            holder:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                if self.mint then
                    local rarity = ns.MintRarity(self.mint.traits)
                    GameTooltip:AddLine(("Picture #%d"):format(self.mint.number))
                    GameTooltip:AddLine((rarity:gsub("^%l", string.upper)), ns.RarityRGB(rarity))
                    for _, trait in ipairs(ns.MintTraits(self.mint.traits)) do
                        GameTooltip:AddDoubleLine(trait[1], ("|c%s%s|r"):format(ns.RARITY_COLORS[trait[3]], trait[2]))
                    end
                    if self.mint.time then GameTooltip:AddLine(date("Minted %Y-%m-%d", self.mint.time), 0.6, 0.6, 0.6) end
                    GameTooltip:AddLine("Click to view", 0.6, 0.6, 0.6)
                else
                    GameTooltip:AddLine("Showcase")
                    GameTooltip:AddLine(("Open one of your pictures and click \"Show on your Overview\" (up to %d)."):format(ns.SHOWCASE_SIZE),
                        1, 1, 1, true)
                    GameTooltip:AddLine("Click to see your pictures", 0.6, 0.6, 0.6)
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
            row:SetScript("OnClick", function(self) if self.item then UI.ShowFeedPicture(self.item) end end)
            row:SetScript("OnEnter", function(self)
                if not self.item then return end
                self.stripe:SetColorTexture(unpack(FEED_HOVER_COLOR))
                UI.FeedTooltip(self, self.item)
            end)
            row:SetScript("OnLeave", function(self)
                self.stripe:SetColorTexture(shade, shade, shade)
                GameTooltip_Hide()
            end)
            page.feed[i] = row
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
            page.gearPanel:SetShown(which == "gear")
            page.craftsPanel:SetShown(which == "crafts")
            left:SetShown(which == nil)
            for _, tab in ipairs(page.tabs) do tab:Redraw() end
        end
        local tabWidth = (LEFT.right - LEFT.left) / #TABS
        for i, spec in ipairs(TABS) do
            local tab = UI.TabButton(tabs, LEFT.left + (i - 1) * tabWidth, LEFT.tabs, tabWidth)
            function tab:Redraw()
                self:SetTab(KillTrackerDB and KillTrackerDB.ogreMode and spec[3] or spec[2], page.panel == spec[1])
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
        local p = UI.Profile(key)

        -- The photo: their chosen picture, or (no model of them to show) their first showcase picture or else their
        -- newest picture, or the model.
        local friend = key and KillTrackerFriends[key]
        local gear = friend and friend.gear
        local portrait = ns.FindMint(key, p.portrait)
        if not portrait and key and not gear then portrait = ns.GetShowcase(key)[1] or ns.NewestMint(key) end
        local switched = (page.portraitMint ~= nil) ~= (portrait ~= nil)
        page.portraitMint = portrait
        page.portrait:SetShown(portrait ~= nil)
        page.photo:EnableMouse(portrait ~= nil)
        if portrait then ns.DrawMint(page.portrait, portrait) end
        -- The model: reloaded only for someone else, new gear or after a picture, so turning it sticks while the page
        -- refreshes.
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
            if mint then
                ns.DrawMint(holder.canvas, mint)
                holder.border:SetVertexColor(ns.RarityRGB(ns.MintRarity(mint.traits)))
            else
                holder.border:SetVertexColor(0.35, 0.35, 0.35)
            end
        end

        -- What happened to them lately (WHAT HAPPEN TO ME? on yours, their first name on someone else's).
        local who = key and Ambiguate(key, "short") or ns.MyName()
        page.heading:SetText(key and ("WHAT HAPPEN TO %s?"):format(((p.name or ""):match("^(%S+)") or ""):upper()) or LEFT.heading.text)
        local items = {}
        for _, item in ipairs(ns.GetFeed(true)) do
            if item.who == who then items[#items + 1] = item end
            if #items == #page.feed then break end
        end
        for i, row in ipairs(page.feed) do
            local item = items[i]
            row.item = item
            row.stripe:SetShown(item ~= nil)
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
    end,
})
