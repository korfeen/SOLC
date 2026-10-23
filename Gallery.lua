-- The Overview's gallery (OverviewCard.lua): your pictures over the right page, instead of the photo, opened by clicking
-- your showcase. It starts with a tile to mint a new one (the Dream Bed, DreamBed.lua), your ogre (built from what
-- you have, Minting.lua: click to build it, drag it onto PHOTO to show it) and one per dungeon with chests to open
-- (Chests.lua). Click a picture to look at it (on the photo's place: its traits, editions, reroll). Drag
-- one onto a showcase slot to put it there; drag a showcase picture onto another to swap them, or anywhere else to take
-- it off. Newest first; the mouse wheel scrolls. Showcased ones wear their slot's number. The PHOTO slot in its header is the big photo's: drag a
-- picture onto it to show it there, drag it out to show your character again.

local _, ns = ...
local UI = ns.UI

local NAME_FONT = "Interface\\AddOns\\SOLC\\Media\\Fonts\\GermaniaOne-Regular.ttf"
local GOLD, CREAM = { 1, 0.85, 0.1 }, { 0.93, 0.88, 0.78 }
-- In window pixels (from its top-left, y down), on the right page (UI.SPLIT.right: x 674..1064, y 146..730).
local G = { heading = { x = 692, y = 172 }, hint = { x = 692, y = 196 }, grid = { top = 214, cols = 4, cell = 90, gap = 8 },
    footer = 716 }

-- A picture being dragged (from the gallery or a showcase slot), following the cursor; the slot under it lit.
local ghost = CreateFrame("Frame", nil, UIParent)
ghost:SetSize(72, 72)
ghost:SetFrameStrata("TOOLTIP")
ghost:Hide()
-- (Sized, not just anchored: a picture is drawn by its canvas's width, which a hidden frame's anchors don't give yet.)
ghost.canvas = CreateFrame("Frame", nil, ghost)
ghost.canvas:SetSize(66, 66)
ghost.canvas:SetPoint("CENTER")
-- Its outline in its rarity's colour, turning with it (Media/Icons/Kitchen/Outline: the square is 208 of its 256, room
-- round it to turn in).
ghost.outline = ghost.canvas:CreateTexture(nil, "OVERLAY", nil, 7)
ghost.outline:SetTexture("Interface\\AddOns\\SOLC\\Media\\Icons\\Kitchen\\Outline")
ghost.outline:SetSize(66 * 256 / 208 + 4, 66 * 256 / 208 + 4)
ghost.outline:SetPoint("CENTER")
ghost:SetAlpha(0.9)

function UI.Gallery(page)
    local split = UI.SPLIT
    local function At(region, point, x, y) region:SetPoint(point, UI.window, "TOPLEFT", x, -y) end
    local gallery = CreateFrame("Frame", nil, page)
    gallery:SetAllPoints()
    gallery:SetFrameLevel(page.photo:GetFrameLevel() + 5)
    gallery:EnableMouseWheel(true)
    gallery:Hide()
    gallery.offset = 0  -- rows scrolled

    local board = gallery:CreateTexture(nil, "BACKGROUND", nil, -8)
    At(board, "TOPLEFT", split.under.middle, split.under.top)
    board:SetPoint("BOTTOMRIGHT", UI.window, "TOPLEFT", split.under.right, -split.under.bottom)
    board:SetColorTexture(0.05, 0.03, 0.02)
    local heading = gallery:CreateFontString(nil, "OVERLAY")
    heading:SetFont(NAME_FONT, 22, "")
    heading:SetTextColor(unpack(GOLD))
    UI.OutlineText(heading, { 0, 0, 0 })
    At(heading, "LEFT", G.heading.x, G.heading.y)
    heading:SetText("YOUR PIX")
    local hint = gallery:CreateFontString(nil, "OVERLAY")
    hint:SetFont(NAME_FONT, 13, "")
    hint:SetTextColor(unpack(CREAM))
    At(hint, "LEFT", G.hint.x, G.hint.y)
    hint:SetText("Click to look, drag onto your showcase or photo")
    local footer = gallery:CreateFontString(nil, "OVERLAY")
    footer:SetFont(NAME_FONT, 12, "")
    footer:SetTextColor(0.62, 0.56, 0.48)
    At(footer, "CENTER", (split.right.left + split.right.right) / 2, G.footer)
    local close = CreateFrame("Button", nil, gallery, "UIPanelCloseButton")
    At(close, "CENTER", split.right.right - 14, G.heading.y)
    close:SetScript("OnClick", function() page.CloseGallery() end)

    -- The photo's slot: a little polaroid (YOU while it's your character).
    local P = { x = split.right.right - 66, y = G.heading.y + 10, size = 50 }
    local photo = CreateFrame("Button", nil, gallery)
    photo:SetSize(P.size, P.size + 8)
    At(photo, "CENTER", P.x, P.y)
    photo:RegisterForDrag("LeftButton")
    photo.paper = photo:CreateTexture(nil, "BACKGROUND")
    photo.paper:SetAllPoints()
    photo.canvas = CreateFrame("Frame", nil, photo)
    photo.canvas:SetSize(P.size - 8, P.size - 8)
    photo.canvas:SetPoint("TOP", 0, -4)
    photo.you = photo:CreateFontString(nil, "OVERLAY")
    photo.you:SetFont(NAME_FONT, 14, "")
    photo.you:SetTextColor(0.35, 0.25, 0.15)
    photo.you:SetPoint("CENTER", photo.canvas)
    photo.you:SetText("YOU")
    local photoLabel = gallery:CreateFontString(nil, "OVERLAY")
    photoLabel:SetFont(NAME_FONT, 14, "")
    photoLabel:SetTextColor(unpack(GOLD))
    UI.OutlineText(photoLabel, { 0, 0, 0 })
    photoLabel:SetPoint("RIGHT", photo, "LEFT", -6, 0)
    photoLabel:SetText("PHOTO")
    function photo:paint(lit) self.paper:SetColorTexture(unpack(lit and GOLD or { 0.95, 0.92, 0.84 })) end
    function photo:Shake()
        self.shaking = 0
        self:SetScript("OnUpdate", function(f, elapsed)
            f.shaking = f.shaking + elapsed
            local fade = 1 - f.shaking / 0.35
            f:ClearAllPoints()
            if fade <= 0 then
                At(f, "CENTER", P.x, P.y)
                f:SetScript("OnUpdate", nil)
            else
                At(f, "CENTER", P.x + math.sin(f.shaking * 55) * 2 * fade, P.y)
            end
        end)
    end
    photo:SetScript("OnDragStart", function(self) if self.mint then gallery:StartDrag(self.mint, nil, true) end end)
    photo:SetScript("OnDragStop", function() gallery:StopDrag() end)
    photo:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Your photo")
        GameTooltip:AddLine(self.mint and "Drag it out to show your character" or "Drag a picture here to show it big", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    photo:SetScript("OnLeave", GameTooltip_Hide)
    photo:paint(false)
    gallery.photoSlot = photo
    -- Your photo: a picture's number, or nil for your character (as the Pictures page's AS PHOTO sets it).
    local function SetPhoto(number)
        KillTrackerDB.card = KillTrackerDB.card or {}
        KillTrackerDB.card.portrait = number
        KillTrackerDB.card.photoOgre = nil  -- (a picture, or your character: not your ogre)
        ns.Touch(KillTrackerDB.card)
        if ns.OnKillsChanged then ns.OnKillsChanged() end
    end

    -- The grid.
    local g = G.grid
    local width = g.cols * g.cell + (g.cols - 1) * g.gap
    local left = (split.right.left + split.right.right - width) / 2
    local rows = math.floor((G.footer - 12 - g.top) / (g.cell + g.gap))
    gallery.thumbs = {}
    for i = 1, rows * g.cols do
        local col, row = (i - 1) % g.cols, math.floor((i - 1) / g.cols)
        local thumb = CreateFrame("Button", nil, gallery)
        thumb:SetSize(g.cell, g.cell)
        local tx, ty = left + col * (g.cell + g.gap), g.top + row * (g.cell + g.gap)
        At(thumb, "TOPLEFT", tx, ty)
        -- A little shake (a picture dragged over it), as the showcase's slots do (OverviewCard.lua).
        function thumb:Shake()
            self.shaking = 0
            self:SetScript("OnUpdate", function(t, elapsed)
                t.shaking = t.shaking + elapsed
                local fade = 1 - t.shaking / 0.35
                t:ClearAllPoints()
                if fade <= 0 then
                    At(t, "TOPLEFT", tx, ty)
                    if t.mint then ns.DrawMint(t.canvas, t.mint) end
                    t:SetScript("OnUpdate", nil)
                else
                    local wobble = math.sin(t.shaking * 55) * fade
                    At(t, "TOPLEFT", tx + wobble * 2, ty)
                    if t.mint then ns.DrawMint(t.canvas, t.mint, math.floor(wobble * 3 + 0.5) / 2) end  -- (rocking, up to 1.5 degrees)
                end
            end)
        end
        thumb:RegisterForDrag("LeftButton")
        thumb.border = thumb:CreateTexture(nil, "BACKGROUND")
        thumb.border:SetAllPoints()
        thumb.canvas = CreateFrame("Frame", nil, thumb)
        thumb.canvas:SetSize(g.cell - 6, g.cell - 6)
        thumb.canvas:SetPoint("CENTER")
        -- Over the picture (its own frame: above the canvas), when it's in use: a shade, and its showcase slot's number
        -- big in the middle (or PHOTO, for the photo's).
        thumb.cover = CreateFrame("Frame", nil, thumb)
        thumb.cover:SetAllPoints(thumb.canvas)
        thumb.cover:SetFrameLevel(thumb.canvas:GetFrameLevel() + 2)
        local shade = thumb.cover:CreateTexture(nil, "BACKGROUND")
        shade:SetAllPoints()
        shade:SetColorTexture(0, 0, 0, 0.6)
        thumb.badge = thumb.cover:CreateFontString(nil, "OVERLAY")
        thumb.badge:SetFont(NAME_FONT, 34, "")
        thumb.badge:SetTextColor(unpack(GOLD))
        UI.OutlineText(thumb.badge, { 0, 0, 0 })
        thumb.badge:SetPoint("CENTER", 0, 2)
        thumb.cover:Hide()
        -- A tile that isn't a picture: MINT (a big +) or a dungeon's chests (the chest, how many), with a caption.
        thumb.tile = CreateFrame("Frame", nil, thumb)
        thumb.tile:SetAllPoints(thumb.canvas)
        thumb.tile:SetFrameLevel(thumb.canvas:GetFrameLevel() + 1)
        thumb.icon = thumb.tile:CreateTexture(nil, "ARTWORK")
        thumb.icon:SetSize(g.cell - 30, g.cell - 30)
        thumb.icon:SetPoint("CENTER", 0, 8)
        thumb.plus = thumb.tile:CreateFontString(nil, "OVERLAY")
        thumb.plus:SetFont(NAME_FONT, 44, "")
        thumb.plus:SetTextColor(unpack(GOLD))
        UI.OutlineText(thumb.plus, { 0, 0, 0 })
        thumb.plus:SetPoint("CENTER", 0, 8)
        thumb.plus:SetText("+")
        thumb.caption = thumb.tile:CreateFontString(nil, "OVERLAY")
        thumb.caption:SetFont(NAME_FONT, 12, "")
        thumb.caption:SetTextColor(unpack(CREAM))
        UI.OutlineText(thumb.caption, { 0, 0, 0 })
        thumb.caption:SetPoint("BOTTOM", 0, 4)
        thumb.caption:SetWidth(g.cell - 10)
        thumb.caption:SetWordWrap(false)
        thumb.tile:Hide()
        thumb:SetScript("OnClick", function(self)
            local entry = self.entry
            if not entry then return end
            UI.ClickSound()
            if entry.mintAction then return ns.ConfirmMint() end
            if entry.ogre then return page.OpenBuilder(true) end
            if entry.chest then return ns.ShowChest(entry.chest) end
            if page.OpenView then page.OpenView(entry.mint, true) end
        end)
        thumb:SetScript("OnDragStart", function(self)
            local mint = self.mint or (self.entry and self.entry.ogreMint)
            if mint then gallery:StartDrag(mint) end
        end)
        thumb:SetScript("OnDragStop", function() gallery:StopDrag() end)
        thumb:SetScript("OnEnter", function(self)
            local entry = self.entry
            if entry and entry.mintAction then
                return UI.Tooltip(self, { "Mint a picture", ns.BonksLine() })
            elseif entry and entry.ogre then
                return UI.Tooltip(self, { "Your ogre", "Click to build it from what you have. Drag it onto PHOTO to show it" })
            elseif entry and entry.chest then
                return UI.Tooltip(self, { (self.dungeonName or "A dungeon") .. (entry.count > 1 and (" chests (%d)"):format(entry.count) or " chest"),
                    "Click to open" })
            end
            if not self.mint then return end
            local rarity = ns.MintRarity(self.mint.traits, self.mint.asked)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(("Picture #%d"):format(self.mint.number))
            GameTooltip:AddLine((rarity:gsub("^%l", string.upper)), ns.RarityRGB(rarity))
            GameTooltip:Show()
        end)
        thumb:SetScript("OnLeave", GameTooltip_Hide)
        gallery.thumbs[i] = thumb
    end
    gallery:SetScript("OnMouseWheel", function(self, delta)
        self.offset = math.max(0, math.min(self.maxOffset or 0, self.offset - delta))
        self:Refresh()
    end)

    function gallery:Refresh()
        local mints = {}
        for _, mint in ipairs(KillTrackerDB.mints or {}) do mints[#mints + 1] = mint end
        table.sort(mints, function(a, b) return a.number > b.number end)
        local entries = { { mintAction = true }, { ogre = true, ogreMint = { traits = ns.BaseTraits(), ogre = true, style = KillTrackerDB.card and KillTrackerDB.card.ogreStyle } } }
        local counts, order = ns.ChestCounts()
        for _, key in ipairs(order or {}) do entries[#entries + 1] = { chest = key, count = counts[key] } end
        for _, mint in ipairs(mints) do entries[#entries + 1] = { mint = mint } end
        local slotOf = {}
        for i, mint in ipairs(ns.GetShowcase()) do slotOf[mint.number] = i end
        local photoNumber = KillTrackerDB.card and KillTrackerDB.card.portrait
        self.maxOffset = math.max(0, math.ceil(#entries / g.cols) - rows)
        self.offset = math.min(self.offset, self.maxOffset)
        for i, thumb in ipairs(self.thumbs) do
            local entry = entries[self.offset * g.cols + i]
            local mint = entry and entry.mint
            thumb.entry, thumb.mint = entry, mint
            thumb:SetShown(entry ~= nil)
            local ogre = entry and entry.ogre
            thumb.canvas:SetShown(mint ~= nil or ogre == true)
            thumb.tile:SetShown(entry ~= nil and mint == nil)
            if ogre then  -- your ogre, YOUR OGRE under it
                ns.DrawMint(thumb.canvas, entry.ogreMint)
                thumb.plus:Hide()
                thumb.icon:Hide()
                thumb.caption:SetText("YOUR OGRE")
                thumb.border:SetColorTexture(1, 0.82, 0.25)
            elseif entry and not mint then
                thumb.cover:Hide()
                thumb.plus:SetShown(entry.mintAction == true)
                thumb.icon:SetShown(entry.chest ~= nil)
                if entry.chest then
                    local d = ns.DungeonByKey and ns.DungeonByKey(entry.chest)
                    thumb.dungeonName = d and d.name or "A dungeon"
                    thumb.icon:SetTexture("Interface\\AddOns\\SOLC\\Media\\Icons\\Chest")
                    thumb.caption:SetText(("OPEN%s"):format(entry.count > 1 and ("  |cffffd100x%d|r"):format(entry.count) or ""))
                    thumb.border:SetColorTexture(1, 0.82, 0.25)
                else
                    thumb.caption:SetText(("MINT  |T%s:12|t|cffffbf66%d|r"):format(ns.IngredientIcon("bonk"), ns.Bonks()))
                    thumb.border:SetColorTexture(0.5, 0.4, 0.2)
                end
            end
            if mint then
                ns.DrawMint(thumb.canvas, mint)
                thumb.border:SetColorTexture(ns.RarityRGB(ns.MintRarity(mint.traits, mint.asked)))
                local isPhoto = photoNumber == mint.number
                local slot = slotOf[mint.number]
                thumb.cover:SetShown(slot ~= nil or isPhoto)
                thumb.badge:SetFont(NAME_FONT, slot and 34 or 18, "")
                thumb.badge:SetText(slot and (isPhoto and (slot .. "\nPHOTO") or tostring(slot)) or (isPhoto and "PHOTO" or ""))
            end
        end
        -- The photo's slot.
        local card = KillTrackerDB.card
        local portrait = card and card.portrait and ns.FindMint(nil, card.portrait)
        if not portrait and card and card.photoOgre and card.ogre then portrait = { traits = card.ogre, ogre = true, style = card.ogreStyle } end
        photo.mint = portrait or nil
        photo.canvas:SetShown(portrait ~= nil)
        photo.you:SetShown(not portrait)
        if portrait then ns.DrawMint(photo.canvas, portrait) end
        footer:SetText(#mints == 0 and "No pictures yet: mint your first!"
            or ("%d picture%s%s"):format(#mints, #mints == 1 and "" or "s", self.maxOffset > 0 and "  (scroll for more)" or ""))
    end

    -- Dragging: from the gallery (mint) or from a showcase slot (mint, fromSlot). Dropped on a slot: there (swapped with
    -- the slot it came from); dropped elsewhere from a slot: taken off.
    local dragging, dragFrom, dragPhoto  -- the picture being dragged; its showcase slot, or the photo, if from one
    function gallery:StartDrag(mint, fromSlot, fromPhoto)
        GameTooltip_Hide()
        dragging, dragFrom, dragPhoto = mint, fromSlot, fromPhoto
        ghost:Show()
        ghost.mint, ghost.tilt, ghost.lastX, ghost.over = mint, 0, nil, nil
        ns.DrawMint(ghost.canvas, mint, 0)
        ghost.outline:SetVertexColor(ns.RarityRGB(ns.MintRarity(mint.traits, mint.asked)))
        ghost.outline:SetRotation(0)
    end
    local function SlotUnderCursor()
        for _, holder in ipairs(page.polaroids) do
            if holder:IsShown() and holder:IsMouseOver() then return holder end
        end
    end
    -- It follows the cursor, leaning the way it moves (faster, more: up to 14 degrees), easing back upright; a slot it
    -- reaches gives a little shake.
    ghost:SetScript("OnUpdate", function(_, elapsed)
        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        x, y = x / scale, y / scale
        ghost:ClearAllPoints()
        ghost:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
        local speed = ghost.lastX and elapsed > 0 and (x - ghost.lastX) / elapsed or 0
        ghost.lastX = x
        local want = math.max(-14, math.min(14, speed * 0.03))
        ghost.tilt = ghost.tilt + (want - ghost.tilt) * math.min(1, elapsed * 10)
        local shown = math.floor(ghost.tilt * 2 + 0.5) / 2  -- (redrawn in half degrees)
        if ghost.mint then
            ns.DrawMint(ghost.canvas, ghost.mint, shown)
            ghost.outline:SetRotation(-math.rad(shown))  -- (as the picture's layers turn: Minting.lua's Place)
        end
        local over = SlotUnderCursor() or (photo:IsMouseOver() and photo) or nil
        photo:paint(over == photo)
        if not over then  -- (or a picture in the gallery: it shakes too)
            for _, thumb in ipairs(gallery.thumbs) do
                if thumb:IsShown() and thumb:IsMouseOver() then over = thumb end
            end
        end
        if over and over ~= ghost.over and over.Shake then over:Shake() end
        ghost.over = over
        for _, holder in ipairs(page.polaroids) do
            if holder == over then holder.border:SetVertexColor(unpack(GOLD)) elseif holder.paint then holder:paint() end
        end
    end)
    function gallery:StopDrag()
        local mint, from, fromPhoto = dragging, dragFrom, dragPhoto
        if not mint then return end
        dragging, dragFrom, dragPhoto = nil, nil, nil
        ghost:Hide()
        photo:paint(false)
        -- Onto the photo's slot: the big photo shows it. From it, anywhere but a showcase slot: your character again.
        if photo:IsMouseOver() then
            if not fromPhoto then
                if mint.ogre then ns.SetOgre(mint.traits, true) else SetPhoto(mint.number) end
                UI.ClickSound()
            end
            return
        end
        if fromPhoto and (mint.ogre or not SlotUnderCursor()) then
            SetPhoto(nil)
            UI.ClickSound()
            return
        end
        if mint.ogre then return end  -- (your ogre goes on the photo, not the showcase)
        local numbers = {}
        for _, m in ipairs(ns.GetShowcase()) do numbers[#numbers + 1] = m.number end
        local target = SlotUnderCursor()
        local onThumb
        if not target then
            for _, thumb in ipairs(self.thumbs) do
                if thumb:IsShown() and thumb:IsMouseOver() and thumb.mint then onThumb = thumb.mint end
            end
        end
        local at = from  -- (already showcased, from the gallery too: it moves, swapping with the slot it lands on)
        for i, n in ipairs(numbers) do if not at and n == mint.number then at = i end end
        if target then
            if at then
                local to = math.min(target.slot, #numbers)  -- (an empty slot: the last filled one)
                numbers[at], numbers[to] = numbers[to], numbers[at]
            else
                numbers[math.min(target.slot, #numbers + 1)] = mint.number  -- (an empty slot: the next free one)
            end
            UI.ClickSound()
        elseif from and onThumb and onThumb.number ~= mint.number then
            -- From the showcase onto a gallery picture: that one takes its slot (or, showcased too, they trade slots).
            local other
            for i, n in ipairs(numbers) do if n == onThumb.number then other = i end end
            if other then numbers[from], numbers[other] = numbers[other], numbers[from]
            else numbers[from] = onThumb.number end
            UI.ClickSound()
        elseif from and not onThumb then
            table.remove(numbers, from)  -- dragged off the showcase
            UI.ClickSound()
        end
        ns.SetShowcase(numbers)
    end
    return gallery
end
