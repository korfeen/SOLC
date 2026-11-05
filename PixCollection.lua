-- Personal collection progress. Sync receipt alone never reveals a piece.
local _, ns = ...

local function InitHistory()
    local db = KillTrackerDB
    if db.pixPieceMinted then return end
    db.pixPieceMinted = {}
    -- Preserve lifetime skin history from the first catalogue version.
    for id, record in pairs(db.pixMinted or {}) do
        db.pixPieceMinted['skin:' .. id] = { count = record.count, first = record.first }
    end
    local hadSkinHistory = db.pixMinted ~= nil
    for _, mint in ipairs(db.mints or {}) do
        if not mint.wonFrom then
            for layer, id in pairs(mint.traits or {}) do
                if not (layer == 'skin' and hadSkinHistory) then
                    local key = layer .. ':' .. id
                    local record = db.pixPieceMinted[key] or { count = 0 }
                    db.pixPieceMinted[key] = record
                    record.count = record.count + 1
                    if mint.time and (not record.first or mint.time < record.first) then record.first = mint.time end
                end
            end
        end
    end
end

function ns.RecordCollectionMint(mint)
    InitHistory()
    for layer, id in pairs(mint and mint.traits or {}) do
        local key = layer .. ':' .. id
        local record = KillTrackerDB.pixPieceMinted[key] or { count = 0 }
        KillTrackerDB.pixPieceMinted[key] = record
        record.count = record.count + 1
        if mint.time and (not record.first or mint.time < record.first) then record.first = mint.time end
    end
end

function ns.PixCollectionEntries(layer)
    layer = layer or 'skin'
    InitHistory()
    local db = KillTrackerDB
    db.seenPieces = db.seenPieces or {}
    local known = {}
    for _, option in ipairs(ns.OwnedOptions(layer)) do known[option.id] = true end
    local entries = {}
    for _, option in ipairs(ns.MintArt[layer] or {}) do
        local key = layer .. ':' .. option.id
        local unlocked = ns.MintAllowed(option) == true
        local owned = db.pixPieceMinted[key]
        if known[option.id] or unlocked or owned then db.seenPieces[key] = true end
        local seen = db.seenPieces[key] == true
        entries[#entries + 1] = { number = assert(ns.PixCollectionNumbers[key], 'Missing collection number: ' .. key),
            layer = layer, option = option, owned = owned, seen = seen, unlocked = unlocked, minted = owned ~= nil,
            state = owned and 'MINTED' or unlocked and 'UNLOCKED' or seen and 'SEEN' or 'UNKNOWN' }
    end
    table.sort(entries, function(a,b) return a.number < b.number end)
    return entries
end

function ns.PixCollectionUnlockText(option)
    if option.retired then return 'Retired from minting.' end
    local unlock = option.unlock
    if not unlock then return 'Available when you mint a picture.' end
    local kind, value = unlock:match('^(%w+):(.+)$')
    if kind == 'rank' then return 'Reach Ogre Rank ' .. value .. '.' end
    if kind == 'deed' then
        local name, detail
        if ns.AchievementInfo then name, detail = ns.AchievementInfo(value) end
        return 'Complete: ' .. (detail or name or value) .. '.'
    end
    if kind == 'clear' or kind == 'chase' then
        local dungeon = ns.DungeonByKey(value:match('^([^:]+)'))
        return 'Find it in ' .. (dungeon and dungeon.name or value) .. ' chests.'
    end
    if kind == 'loot' then return 'Loot or equip: ' .. value .. '.' end
    if kind == 'combine' then return 'Collect its component pieces.' end
    if kind == 'shop' then return 'Buy it in the Shop.' end
    if kind == 'gacha' then return 'From the claw machine.' end
    return 'Earn its wardrobe unlock to mint this piece.'
end

local UI = ns.UI
local FONT = "Interface\\AddOns\\SOLC\\Media\\Fonts\\GermaniaOne-Regular.ttf"

local function DrawBase(canvas, entry, edition)
    if entry.layer ~= "skin" then
        local option = entry.option
        if entry.seen and edition and option[edition] then
            local copy = {}
            for key, value in pairs(option) do copy[key] = value end
            copy.texture = option[edition]
            copy.rect = option[edition .. "Rect"] or option.rect
            copy.behind = option[edition .. "Behind"]
            copy.behindRect = option[edition .. "BehindRect"]
            option = copy
        end
        ns.DrawPiece(canvas, entry.layer, option)
        local shade = entry.seen and 1 or 0
        for _, key in ipairs({ "piece", "pieceFront", "pieceBehind" }) do
            if canvas[key] then canvas[key]:SetVertexColor(shade, shade, shade) end
        end
        return
    end
    local traits = { skin = entry.option.id }
    if entry.seen then traits.expression, traits.eyes = "smug_smile", "heavy_bags" end
    ns.RenderMint(canvas, traits, 0, entry.seen and edition or nil)
    -- Multiplying the skin by black preserves its alpha silhouette, hiding every detail.
    local shade = entry.seen and 1 or 0
    for _, texture in pairs(canvas.layers or {}) do texture:SetVertexColor(shade, shade, shade) end
    if canvas.front then canvas.front:SetVertexColor(shade, shade, shade) end
end

-- Try on a known piece without changing the equipped ogre or its edition settings.
local function DrawEquipped(canvas, entry, edition)
    if not entry.seen then return DrawBase(canvas, entry) end
    local traits, style = {}, {}
    for key, id in pairs(ns.BaseTraits()) do traits[key] = id end
    traits[entry.layer] = entry.option.id
    local card = KillTrackerDB.card
    local equippedStyle = card and card.ogre and card.ogreStyle
    if card and not card.ogre and card.portrait then
        local mint = ns.FindMint(nil, card.portrait)
        equippedStyle = mint and mint.style
    end
    for _, layer in ipairs(ns.MintLayers or {}) do
        local value = ns.LayerEdition(equippedStyle, layer.key)
        if value then style[layer.key] = value end
    end
    -- The edition picker applies only to the selected piece.
    style[entry.layer] = edition
    -- Clear a previous silhouette before the renderer applies each piece's own colours.
    for _, texture in pairs(canvas.layers or {}) do texture:SetVertexColor(1, 1, 1) end
    if canvas.front then canvas.front:SetVertexColor(1, 1, 1) end
    ns.RenderMint(canvas, traits, 0, style)
end

-- A picked word's underline (Media/Icons/Streak1..5, tools/make-streak.js): one of the brush flicks at random, mirrored
-- or not, a little tilted, its length a little off - chosen as the word gets picked, kept while it stays picked.
function UI.Flick(t)
    t:SetTexture("Interface\\AddOns\\SOLC\\Media\\Icons\\Streak" .. math.random(5))
    if math.random() < 0.5 then t:SetTexCoord(0, 1, 0, 1) else t:SetTexCoord(1, 0, 0, 1) end
    t:SetRotation(math.rad(-1.5 + math.random() * 2.5))  -- (gently: a long one mustn't dip into the line below)
    t.len = 0.94 + math.random() * 0.14
end
-- Its look: an open book (CollectionBookArt.lua, tools/gen-collection-book.js: the Dream Bed's red book opened flat)
-- with ink on its parchment pages, else the old dark boards.
local BOOK = ns.CollectionBookArt
local INK = BOOK and {
    panel = { 0, 0, 0, 0 }, backing = { 0, 0, 0, 0 }, text = { 0.22, 0.13, 0.06 }, heading = { 0.55, 0.12, 0.08 },
    dim = { 0.42, 0.31, 0.19 }, track = { 0.74, 0.64, 0.48 }, bar = { 0.62, 0.32, 0.1 },
    tab = { 0.82, 0.71, 0.52 }, tabOn = { 0.58, 0.15, 0.1 }, label = { 0.3, 0.19, 0.09 }, labelOn = { 1, 0.92, 0.72 },
    edge = { 0.5, 0.35, 0.18 }, edgeOn = { 0.9, 0.7, 0.28 },
    tile = { 0.86, 0.79, 0.64 }, unseen = { 0.62, 0.55, 0.43 }, rarityDim = 0.9,
} or {
    panel = { 0.065, 0.045, 0.03, 1 }, backing = { 0.045, 0.032, 0.022, 1 }, text = { 0.93, 0.88, 0.78 }, heading = { 1, 0.82, 0.48 },
    dim = { 0.65, 0.59, 0.49 }, track = { 0.2, 0.15, 0.09 }, bar = { 0.73, 0.53, 0.23 },
    tab = { 0.18, 0.12, 0.07 }, tabOn = { 0.38, 0.26, 0.12 }, label = { 0.72, 0.65, 0.53 }, labelOn = { 1, 0.84, 0.5 },
    edge = { 0.1, 0.07, 0.04 }, edgeOn = { 0.9, 0.7, 0.28 },
    tile = { 0.06, 0.045, 0.03 }, unseen = { 0.25, 0.22, 0.18 }, rarityDim = 0.45,
}

function UI.PixCollection(parent)
    local dex = CreateFrame("Frame", nil, parent)
    dex:SetAllPoints()
    dex.offset, dex.filter, dex.edition, dex.layer = 0, "all", nil, "skin"
    local function At(region, point, x, y)
        region:SetPoint(point, UI.window, "TOPLEFT", x, -y)
    end
    local function Panel(x, y, w, h)
        local panel = CreateFrame("Frame", nil, dex)
        panel:SetSize(w, h)
        At(panel, "TOPLEFT", x, y)
        panel:EnableMouse(true)
        local bg = panel:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(unpack(INK.panel))
        return panel
    end
    local function Text(parentFrame, size, x, y, width)
        local text = parentFrame:CreateFontString(nil, "OVERLAY")
        text:SetFont(FONT, size, "")
        text:SetTextColor(unpack(INK.text))
        At(text, "TOPLEFT", x, y)
        text:SetWidth(width)
        text:SetJustifyH("LEFT")
        return text
    end
    local backing = dex:CreateTexture(nil, "BACKGROUND", nil, -8)
    At(backing, "TOPLEFT", 226, 146)
    backing:SetSize(848, 584)
    backing:SetColorTexture(unpack(INK.backing))
    if BOOK then
        -- The open book's two pages (the painting's parchment only - its cover and gold corners left out: the window's
        -- wood is the cover), filling the page area edge to edge, the fold on the gap between the Collection's halves.
        -- Laid out as the page shows (LayBook), when the page area's size is known.
        local area = UI.pageArea or dex
        local BLEED = 14  -- (as the Dream Bed's and the shop's rooms)
        local FOLD = 654  -- (window pixels: between the left page, to 634, and the right, from 674)
        local PAGE = { left = { 175, 760 }, right = { 778, 1375 }, top = 125, bottom = 855, w = 1536, h = 1024 }  -- (painting pixels)
        local sheets = {}
        for i, side in ipairs({ PAGE.left, PAGE.right }) do
            local t = dex:CreateTexture(nil, "BACKGROUND", nil, -7)
            t:SetTexture("Interface\\AddOns\\SOLC\\Media\\Collection\\book")
            t:SetTexCoord(side[1] / PAGE.w, side[2] / PAGE.w, PAGE.top / PAGE.h, PAGE.bottom / PAGE.h)
            sheets[i] = t
        end
        function dex:LayBook()
            local win = UI.window
            if not (win and area:GetLeft() and win:GetLeft()) then return end
            local s = area:GetEffectiveScale() / win:GetEffectiveScale()
            local l, r = (area:GetLeft() * s - win:GetLeft()), (area:GetRight() * s - win:GetLeft())
            local t, b = (win:GetTop() - area:GetTop() * s), (win:GetTop() - area:GetBottom() * s)
            for i, sheet in ipairs(sheets) do
                sheet:ClearAllPoints()
                -- (BLEED past the page area on every side, under the window's wood: no gap at its edges)
                At(sheet, "TOPLEFT", i == 1 and l - BLEED or FOLD, t - BLEED)
                sheet:SetSize(i == 1 and FOLD - l + BLEED or r - FOLD + BLEED, b - t + 2 * BLEED)
            end
        end
    end
    local left = Panel(236, 146, 398, 584)
    local right = Panel(674, 146, 390, 584)
    local heading = Text(left, 25, 246, 160, 375)
    heading:SetText("SKINS")
    heading:SetTextColor(unpack(INK.heading))
    local progress = Text(left, 13, 246, 253, 375)
    local track = left:CreateTexture(nil, "BACKGROUND")
    At(track, "TOPLEFT", 246, 275)
    track:SetSize(375, 4)
    track:SetColorTexture(unpack(INK.track))
    local bar = left:CreateTexture(nil, "ARTWORK")
    At(bar, "TOPLEFT", 246, 275)
    bar:SetHeight(4)
    bar:SetColorTexture(unpack(INK.bar))
    local footer = Text(left, 12, 283, 708, 300)
    footer:SetJustifyH("CENTER")
    footer:SetTextColor(unpack(INK.dim))
    local filterButtons, layerButtons = {}, {}
    local title = Text(right, 23, 690, 158, BOOK and 305 or 355)  -- (in the book: clear of the ribbon)
    local details = Text(right, 15, 690, 552, 355)
    local editionButtons = {}
    local viewport = CreateFrame("Frame", nil, right)
    viewport:SetSize(350, 350)
    At(viewport, "TOPLEFT", 694, 193)
    viewport:SetClipsChildren(true)
    local canvas = CreateFrame("Frame", nil, viewport)
    canvas:SetSize(350, 350)
    canvas:SetPoint("TOP", viewport, "TOP", 0, 0)
    viewport.zoom, viewport.goal = 1, 1
    -- Same top-anchored 1.92x crop and 0.4-second easing as the Pro Shop.
    viewport:SetScript("OnUpdate", function(self, elapsed)
        if self.zoom == self.goal then return end
        self.elapsed = math.min(0.4, (self.elapsed or 0) + elapsed)
        local t = self.elapsed / 0.4
        local eased = t * t * (3 - 2 * t)
        self.zoom = self.from + (self.goal - self.from) * eased
        canvas:SetScale(self.zoom)
    end)
    local function Zoom(entry)
        local close = entry and entry.seen and (entry.layer == "headwear" or entry.layer == "eyes" or entry.layer == "expression")
        local goal = close and 1.92 or 1
        if viewport.goal ~= goal then
            viewport.from, viewport.goal, viewport.elapsed = viewport.zoom, goal, 0
        end
    end
    local function Button(parentFrame, label, x, y, width, action)
        local button = CreateFrame("Button", nil, parentFrame)
        button:SetSize(width, 24)
        At(button, "TOPLEFT", x, y)
        button.label = button:CreateFontString(nil, "OVERLAY")
        button.label:SetFont(FONT, 13, "")
        button.label:SetPoint("CENTER")
        button.label:SetText(label)
        button:SetScript("OnClick", function() UI.ClickSound() action() end)
        button:SetScript("OnEnter", function(self) self.hovered = true self:Paint(self.active) end)
        button:SetScript("OnLeave", function(self) self.hovered = false self:Paint(self.active) end)
        if BOOK then
            -- In the book: words in ink, no boxes. Picked: red ink and a streak of it under the word (two strokes, a little
            -- crooked, like a quick underline by hand); hovered: the word itself warms to red.
            button.streak = {}
            for i, stroke in ipairs({ { 7, 0, 0.95, 0, -2 } }) do  -- height, y, alpha, tilt, x
                local t = button:CreateTexture(nil, "ARTWORK")
                t:SetVertexColor(INK.heading[1], INK.heading[2], INK.heading[3], stroke[3])  -- (a brush flick: tools/make-streak.js)
                t:SetHeight(stroke[1])
                t:SetPoint("TOP", button.label, "BOTTOM", stroke[5], stroke[2] + 2)
                t:SetRotation(math.rad(stroke[4]))
                t:Hide()
                button.streak[i] = t
            end
            function button:Paint(active)
                self.active = active
                local w = self.label:GetStringWidth() + 12
                for i, t in ipairs(self.streak) do
                    if active and not self.picked then UI.Flick(t) end  -- (picked just now: a fresh flick)
                    t:SetWidth(math.min((w - (i - 1) * 8) * (t.len or 1), self:GetWidth() - 2)) t:SetShown(active and true or false)  -- (within its tab)
                end
                self.picked = active
                self.label:SetTextColor(unpack((active or self.hovered) and INK.heading or INK.text))
            end
            button:Paint(false)
            return button
        end
        -- (no book: a boxed tab - its outline, its face, a soft shine on top, shade under; hovered: warmer)
        button.edge = button:CreateTexture(nil, "BACKGROUND", nil, -2)
        button.edge:SetAllPoints()
        local bg = button:CreateTexture(nil, "BACKGROUND", nil, -1)
        bg:SetPoint("TOPLEFT", 1, -1) bg:SetPoint("BOTTOMRIGHT", -1, 1)
        button.bg = bg
        local hover = button:CreateTexture(nil, "HIGHLIGHT")
        hover:SetAllPoints(bg)
        hover:SetColorTexture(1, 0.86, 0.5, 0.15)
        function button:Paint(active)
            self.active = active
            self.bg:SetColorTexture(unpack(active and INK.tabOn or INK.tab))
            self.edge:SetColorTexture(unpack(active and INK.edgeOn or INK.edge))
            self.label:SetTextColor(unpack(active and INK.labelOn or INK.label))
        end
        button:Paint(false)
        return button
    end
    local function Preview()
        local entry = dex.selected
        viewport:SetShown(entry ~= nil)
        Zoom(entry)
        canvas:SetShown(entry ~= nil)
        local EDITIONS = { [1] = nil, [2] = "crayon", [3] = "sketch" }  -- (the one shown: underlined)
        for i, button in ipairs(editionButtons) do
            button:SetShown(entry ~= nil and entry.seen)
            button:Paint(dex.edition == EDITIONS[i])
        end
        if not entry then title:SetText("No matching pieces") details:SetText("") return end
        local option, own = entry.option, entry.owned
        title:SetText(("#%03d  %s"):format(entry.number, entry.seen and option.name or "Unknown"))
        if not entry.seen then
            details:SetText("UNDISCOVERED\n\nOpen a guildmate's picture or view their ogre to discover this piece. Unlocking or owning it also reveals it.")
            DrawEquipped(canvas, entry)
            return
        end
        local lines = {
            ("|c%s%s|r"):format(ns.RARITY_COLORS[option.rarity] or "ffffffff", option.rarity:upper()),
            entry.state,
            option.retired and "Retired from minting" or entry.unlocked and "Unlocked: this piece can roll in your pictures." or "Locked: this piece cannot roll yet.",
            own and ("Personally minted: %d picture%s using this piece."):format(own.count, own.count == 1 and "" or "s") or "Not minted with this piece yet.",
        }
        if own and own.first then lines[#lines + 1] = "First minted: " .. date("%Y-%m-%d", own.first) end
        lines[#lines + 1] = ns.PixCollectionUnlockText(option)
        details:SetText(table.concat(lines, "\n"))
        DrawEquipped(canvas, entry, dex.edition)
    end
    local tiles = {}
    function dex:Draw()
        for _, group in ipairs({ { layerButtons, self.layer }, { filterButtons, self.filter } }) do
            for key, button in pairs(group[1]) do
                local active = group[2] == key
                button:Paint(active)
            end
        end
        local count = #self.filtered
        footer:SetText(count == 0 and "No matching pieces" or ("%d-%d of %d  -  scroll to browse"):format(self.offset * 3 + 1, math.min(count, self.offset * 3 + 9), count))
        for i, tile in ipairs(tiles) do
            local entry = self.filtered[self.offset * 3 + i]
            tile.entry = entry
            tile:SetShown(entry ~= nil)
            if entry then
                DrawBase(tile.canvas, entry)
                tile.caption:SetText(("#%03d %s\n%s"):format(entry.number, entry.seen and entry.option.name or "Unknown",
                    entry.state))
                if self.selected and entry.option.id == self.selected.option.id then
                    tile.border:SetColorTexture(0.95, 0.73, 0.32)
                elseif entry.seen then
                    local r, g, b = ns.RarityRGB(entry.option.rarity)
                    tile.border:SetColorTexture(r * INK.rarityDim, g * INK.rarityDim, b * INK.rarityDim)
                else tile.border:SetColorTexture(unpack(INK.unseen)) end
            end
        end
        Preview()
    end
    for i = 1, 9 do
        local tile = CreateFrame("Button", nil, left)
        tile:SetSize(122, 122)
        At(tile, "TOPLEFT", 242 + ((i - 1) % 3) * 129, 318 + math.floor((i - 1) / 3) * 127)
        tile.border = tile:CreateTexture(nil, "BACKGROUND")
        tile.border:SetAllPoints()
        local bg = tile:CreateTexture(nil, "BORDER")
        bg:SetPoint("TOPLEFT", 2, -2) bg:SetPoint("BOTTOMRIGHT", -2, 2)
        bg:SetColorTexture(unpack(INK.tile))
        tile.canvas = CreateFrame("Frame", nil, tile)
        tile.canvas:SetSize(88, 88) tile.canvas:SetPoint("TOP", 0, -2)
        tile.caption = tile:CreateFontString(nil, "OVERLAY")
        tile.caption:SetFont(FONT, 11, "")
        tile.caption:SetTextColor(unpack(INK.text))
        tile.caption:SetPoint("BOTTOM", 0, 4) tile.caption:SetWidth(116)
        tile:SetScript("OnClick", function(self)
            dex.selected, dex.edition = self.entry, nil
            UI.ClickSound() dex:Draw()
        end)
        tiles[i] = tile
    end
    local layers = { { "background", "BACKGROUND" }, { "skin", "SKIN" }, { "outfit", "CLOTHES" },
        { "expression", "MOUTH" }, { "eyes", "EYES" }, { "accessory", "ACCESSORY" }, { "headwear", "HEADWEAR" } }
    local SHORT = { background = "PLACE", skin = "SKIN", outfit = "CLOTHES", expression = "MOUTH", eyes = "EYES",
        accessory = "EXTRA", headwear = "HAT" }
    -- A hand-drawn rule across the left page (a brush flick in faint brown ink), between its parts.
    local function Rule(y)
        local t = left:CreateTexture(nil, "ARTWORK")
        UI.Flick(t)
        t:SetRotation(0)
        t:SetVertexColor(0.42, 0.3, 0.17, 0.45)
        At(t, "TOPLEFT", 240, y)
        t:SetSize(388, 6)
    end
    for i, layer in ipairs(layers) do
        local function Pick()
            dex.layer, dex.offset, dex.edition, dex.selected = layer[1], 0, nil, nil
            heading:SetText(layer[2])
            dex:Refresh()
        end
        if BOOK then
            -- (in the book: its crayon icon, its short name under it)
            local b = CreateFrame("Button", nil, left)
            b:SetSize(54, 60)
            At(b, "TOPLEFT", 240 + (i - 1) * 55, 184)
            b.icon = b:CreateTexture(nil, "ARTWORK")
            b.icon:SetPoint("TOP", 0, -1)
            b.icon:SetTexture("Interface\\AddOns\\SOLC\\Media\\Icons\\Layer_" .. layer[1])
            b.label = b:CreateFontString(nil, "OVERLAY")
            b.label:SetFont(FONT, 13, "")
            b.label:SetPoint("BOTTOM", 0, 6)
            b.label:SetText(SHORT[layer[1]])
            local streak = b:CreateTexture(nil, "ARTWORK")
            streak:SetPoint("TOP", b.label, "BOTTOM", 0, 1)
            streak:SetHeight(6)
            function b:Paint(active)
                if active and not self.picked then UI.Flick(streak) end
                self.picked = active
                streak:SetVertexColor(INK.heading[1], INK.heading[2], INK.heading[3], 0.95)
                streak:SetWidth(math.min(self.label:GetStringWidth() + 8, 54) * (streak.len or 1))
                streak:SetShown(active and true or false)
                local size = (active or self.hovered) and 44 or 40
                self.icon:SetSize(size, size)
                self.icon:SetAlpha((active or self.hovered) and 1 or 0.65)
                self.label:SetTextColor(unpack((active or self.hovered) and INK.heading or INK.text))
            end
            b:SetScript("OnClick", function() UI.ClickSound() Pick() end)
            b:SetScript("OnEnter", function(self) self.hovered = true self:Paint(self.picked) end)
            b:SetScript("OnLeave", function(self) self.hovered = false self:Paint(self.picked) end)
            b:Paint(false)
            layerButtons[layer[1]] = b
        else
            layerButtons[layer[1]] = Button(left, layer[2], 242 + ((i - 1) % 4) * 98, 193 + math.floor((i - 1) / 4) * 28, 94, Pick)
        end
    end
    if BOOK then Rule(247) Rule(310) end
    local filters = { { "all", "ALL" }, { "seen", "SEEN" },
        { "unlocked", "UNLOCKED" }, { "minted", "MINTED" } }
    for i, filter in ipairs(filters) do
        filterButtons[filter[1]] = Button(left, filter[2], 242 + (i - 1) * 98, 286, 94, function()
            dex.filter, dex.offset = filter[1], 0
            dex:Refresh()
        end)
        if BOOK and i > 1 then  -- (a dot between them)
            local dot = left:CreateFontString(nil, "OVERLAY")
            dot:SetFont(FONT, 16, "")
            dot:SetTextColor(INK.dim[1], INK.dim[2], INK.dim[3])
            dot:SetText("·")
            At(dot, "TOPLEFT", 242 + (i - 1) * 98 - 6, 289)
        end
    end
    for i, edition in ipairs({ { "PAINTED", "" }, { "CRAYON", "crayon" }, { "SKETCH", "sketch" } }) do
        editionButtons[i] = Button(right, edition[1], 690 + (i - 1) * 120, 690, 112, function()
            local option = dex.selected and dex.selected.option
            if option and dex.selected.seen and (edition[2] == "" or option[edition[2]]) then
                dex.edition = edition[2] ~= "" and edition[2] or nil
                Preview()
            end
        end)
    end
    local function Scroll(delta)
        dex.offset = math.max(0, math.min(math.max(0, math.ceil(#dex.filtered / 3) - 3), dex.offset + delta))
        dex:Draw()
    end
    -- (the way back to the Dream Bed's room: the book lies there)
    if BOOK then
        -- The way back to the Bedroom: the book's ribbon bookmark hanging over the right page's top-right corner, from
        -- under the top beam (a gold cross stitched on: close); hovered, it slides down a touch, as if tugged.
        local ribbon = CreateFrame("Button", nil, right)
        ribbon:SetSize(50, 100)
        ribbon:SetFrameLevel(right:GetFrameLevel() + 5)
        local tex = ribbon:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints()
        tex:SetTexture("Interface\\AddOns\\SOLC\\Media\\Collection\\ribbon")
        local function Hang(drop) ribbon:ClearAllPoints() At(ribbon, "TOPLEFT", 1008, 126 + drop) end
        Hang(0)
        ribbon:SetScript("OnEnter", function(self)
            Hang(7)
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:AddLine("Back to the Bedroom")
            GameTooltip:AddLine("Close the book", 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end)
        ribbon:SetScript("OnLeave", function() Hang(0) GameTooltip_Hide() end)
        ribbon:SetScript("OnClick", function() UI.ClickSound() if ns.OpenPage then ns.OpenPage("dreambed") end end)
    end
    -- (the page arrows: big, easy to hit)
    for _, arrow in ipairs({ { "<", 236, -1 }, { ">", 595, 1 } }) do
        local b = Button(left, arrow[1], arrow[2], 698, 40, function() Scroll(arrow[3]) end)
        b:SetHeight(34)
        b.label:SetFont(FONT, 26, "")
        b:Paint(false)
    end
    left:EnableMouseWheel(true)
    left:SetScript("OnMouseWheel", function(_, delta)
        dex.offset = math.max(0, math.min(math.max(0, math.ceil(#dex.filtered / 3) - 3), dex.offset - delta))
        dex:Draw()
    end)
    function dex:Refresh()
        if self.LayBook then self:LayBook() end  -- (the book's pages over the page area, as it is now)
        self.filtered = {}
        local minted, unlocked, seen, selected, entries = 0, 0, 0, nil, ns.PixCollectionEntries(self.layer)
        for _, entry in ipairs(entries) do
            if entry.minted then minted = minted + 1 end
            if entry.unlocked then unlocked = unlocked + 1 end
            if entry.seen then seen = seen + 1 end
            if self.filter == "all" or (self.filter == "minted" and entry.minted)
                or (self.filter == "unlocked" and entry.unlocked)
                or (self.filter == "seen" and entry.seen) then
                self.filtered[#self.filtered + 1] = entry
                if self.selected and self.selected.option.id == entry.option.id then selected = entry end
            end
        end
        self.selected = selected or self.filtered[1]
        self.offset = math.min(self.offset, math.max(0, math.ceil(#self.filtered / 3) - 3))
        progress:SetText(("%d / %d seen  -  %d unlocked  -  %d minted"):format(seen, #entries, unlocked, minted))
        bar:SetWidth(math.max(1, 375 * seen / math.max(1, #entries)))
        self:Draw()
    end
    dex:Hide()
    return dex
end

-- Personal catalogue: reachable from the current sidebar, independently of the legacy Pictures page.
ns.RegisterPage({
    key = "pixcollection", label = "Collection", section = "me", order = 4, under = "dreambed",  -- (the Dream Bed's book opens it)
    bare = true,
    create = function(parent)
        local page = UI.PixCollection(parent)
        return page
    end,
    refresh = function(page) page:Refresh() end,
})
