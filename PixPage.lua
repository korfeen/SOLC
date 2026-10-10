-- Pictures (PIX): your collection and the guild's gallery; pictures opened anywhere (ns.ShowMint) open here. The
-- key gallery opens the GUILD tab. A split page
-- (ProfileHeader.lua: the profile header over the left page, the middle beam).
-- Left: tabs. MINE (THEIRS on a guildmate's): their pictures, newest first, yours led by a tile to mint a new one.
-- GUILD: everyone's, newest first, with whose. SHOP: the Collection's rows (minting, the collectibles, the points and
-- where they came from, saved paintings), in the Overview feed's style.
-- Right: the picked picture hung in the Overview's frame, its rarity under it, its owner on the plaque; under the frame
-- its traits (on your own with the crayon edition: click one to draw it painted, in crayon or sketched), and buttons:
-- show it on your Overview, switch the whole picture's edition, use it as your Overview photo, reroll a duplicate.

local _, ns = ...
local UI = ns.UI
local List = UI.List
if not List then return end
local state = List.state
local Fit, Tooltip = UI.FitText, UI.Tooltip

local ART = "Interface\\AddOns\\SOLC\\Media\\Overview\\"
local NAME_FONT = "Interface\\AddOns\\SOLC\\Media\\Fonts\\GermaniaOne-Regular.ttf"
local SIGN_FONT = "Interface\\AddOns\\SOLC\\Media\\Fonts\\FingerPaint-Regular.ttf"
local INK = { 0.16, 0.16, 0.18 }
local CREAM, DIM = { 0.93, 0.88, 0.78 }, { 0.62, 0.56, 0.48 }
local GOLD = { 1, 0.85, 0.1 }
local HOVER_COLOR = { 0.65, 0.53, 0.28 }
local PLATE, PLATE_LIT = { 0.3, 0.22, 0.12 }, { 0.65, 0.53, 0.28 }

local TABS = {  -- { key, label, ogre word }; MINE reads THEIRS on someone else's
    { "mine", "MINE", "MINE" },
    { "guild", "GUILD", "CLAN" },
    { "shop", "SHOP", "SHOP" },
}
local TAB_FOR_PAGE = { gallery = "guild" }

-- In window pixels (from its top-left, y down). The left slot (UI.SPLIT.left): the tabs, a line about the tab, then
-- the tiles (three a row) or the shop's rows.
local LEFT = {
    tabs = { top = 285, bottom = 319, size = 17, color = { 0.16, 0.11, 0.08 } },
    line = { top = 319, bottom = 343, size = 13, color = { 0.12, 0.12, 0.12 } },
    tiles = { lefts = { 242, 371, 500 }, top = 349, size = 122, step = 128, rim = 2, color = { 0.03, 0.03, 0.03 } },
    rows = { top = 343, height = 24, size = 13, colors = { 0.25, 0.18 }, bar = 3, empty = { 0.1, 0.1, 0.1 } },
}
-- The right page: the frame (as the Overview's), the picture in its opening and the rarity under it, the plaque, and
-- under the frame the traits (left) and the buttons (right).
local RIGHT = {
    color = { 0.094, 0.094, 0.094 },
    frame = { x = 688, y = 156, w = 362, h = 447 },
    photo = { x = 869, y = 389.5, w = 308, h = 329 },
    picture = { x = 869, y = 381, size = 296 },
    rarity = { x = 869, y = 541 },
    plaque = { x = 874, y = 578, w = 170, size = 22 },
    traits = { x = 700, top = 612, width = 222, line = 15, size = 12 },
    buttons = { x = 930, top = 612, w = 128, h = 24, gap = 4 },
}

local function Capitalize(text) return (text:gsub("^%l", string.upper)) end
local function Short(key) return key and Ambiguate(key, "short") or ns.MyName() end

-- Someone's pictures, newest first: { { mint, owner (short name; nil: yours), key } }.
local function PicturesOf(key)
    local list = {}
    local mints = key and (KillTrackerFriends[key] or {}).mints or KillTrackerDB.mints or {}
    for _, mint in pairs(mints) do list[#list + 1] = { mint = mint, owner = key and Short(key) or nil, key = key } end
    table.sort(list, function(a, b) return a.mint.number > b.mint.number end)
    return list
end
-- Everyone's, newest first.
local function GuildPictures()
    local list = PicturesOf(nil)
    for _, friend in ipairs(ns.GetFriends()) do
        for _, picture in ipairs(PicturesOf(friend.key)) do
            picture.owner = friend.name
            list[#list + 1] = picture
        end
    end
    table.sort(list, function(a, b) return (a.mint.time or 0) > (b.mint.time or 0) end)
    return list
end

-- A flat wooden-looking button: plate:Set(text, enabled), its click and tooltip set by the caller.
local function Plate(parent, w, h)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(w, h)
    button.back = button:CreateTexture(nil, "BACKGROUND")
    button.back:SetAllPoints()
    button.text = button:CreateFontString(nil, "OVERLAY")
    button.text:SetFont(NAME_FONT, 13, "")
    button.text:SetPoint("CENTER", 0, 1)
    UI.OutlineText(button.text, { 0, 0, 0 })
    local function Paint(lit)
        button.back:SetColorTexture(unpack(lit and PLATE_LIT or PLATE))
        button.text:SetTextColor(unpack(lit and { 1, 1, 1 } or GOLD))
    end
    button:SetScript("OnEnter", function(self) Paint(true) if self.lines then Tooltip(self, self.lines) end end)
    button:SetScript("OnLeave", function() Paint(false) GameTooltip_Hide() end)
    function button:Set(text, lines) self.text:SetText(text) self.lines = lines self:Show() end
    Paint(false)
    return button
end

-- The page frame's own parts, made in create.
local page

-- Picks a picture ({ mint, owner, key }) for the right page.
local function Pick(picture)
    page.pick = picture
    ns.OpenPage(state.page)
end

-- The tiles for the MINE and GUILD tabs, from page.offset (in rows of three) on.
local function DrawTiles()
    local spec = LEFT.tiles
    local list = page.pictures
    local first = page.offset * #spec.lefts
    for i, tile in ipairs(page.tiles) do
        local index = first + i
        local picture = list[index]
        tile.picture = picture
        tile:SetShown(picture ~= nil)
        if picture then
            if picture.mintAction then
                tile.canvas:Hide()
                tile.plus:Show()
                tile.border:SetVertexColor(0.5, 0.4, 0.2)
                tile.caption:SetText(("MINT  |cffffbf66%d|r"):format(ns.MintCost()))
                tile.band:Show()
                tile.tag:SetText("")
            else
                tile.canvas:Show()
                tile.plus:Hide()
                ns.DrawMint(tile.canvas, picture.mint)
                local picked = page.pick and page.pick.mint == picture.mint
                if picked then tile.border:SetVertexColor(1, 1, 1) else tile.border:SetVertexColor(ns.RarityRGB(ns.MintRarity(picture.mint.traits))) end
                local guild = page.tab == "guild"
                tile.band:SetShown(guild)
                tile.caption:SetText(guild and (picture.owner or ("|cffffd100%s|r"):format(ns.MyName())) or "")
                local showcased = not picture.key and ns.IsShowcased(picture.mint.number)
                tile.tag:SetText(picture.mint.duplicateOf and not picture.key and "|cffff6060DUP|r" or showcased and "|cffffd100*|r" or "")
            end
        end
    end
    page.empty:SetShown(#list == 0)
end

-- The SHOP tab's rows, from page.offset on.
local function DrawRows()
    for i, row in ipairs(page.rows) do
        local d = page.data[page.offset + i]
        row.data = d
        row:SetShown(d ~= nil)
        if d then
            List.FillRow(row, d, page.total, page.max)
            row:Paint(false)
        end
    end
    page.empty:SetShown(#page.data == 0)
end

-- The right page: the picked picture, or (nothing picked) the first in the tab.
local function DrawPick()
    local picture = page.pick
    if not picture then  -- the tab's first picture; on SHOP, their newest
        for _, p in ipairs(page.tab == "shop" and PicturesOf(state.viewing) or page.pictures or {}) do
            if p.mint then picture = p break end
        end
    end
    page.shown = picture
    local mint = picture and picture.mint
    page.canvas:SetShown(mint ~= nil)
    page.nothing:SetShown(mint == nil)
    -- Nothing to hang: on yours, an invitation to mint (the whole opening is the button).
    local invite = mint == nil and not state.viewing
    page.invite:SetShown(invite)
    page.nothing:SetText(invite and ("|cffffd100+ MINT A PICTURE|r\n\n%d points - you have %d"):format(ns.MintCost(), ns.GetPoints().balance)
        or "No pictures here yet.")
    for _, row in ipairs(page.traitRows) do row:Hide() end
    for _, button in ipairs(page.buttons) do button:Hide() end
    if not mint then
        page.rarity:SetText("")
        Fit(page.plaque, SIGN_FONT, RIGHT.plaque.size, 8, "", RIGHT.plaque.w)
        return
    end
    ns.DrawMint(page.canvas, mint)
    local rarity = ns.MintRarity(mint.traits)
    page.rarity:SetText(("|c%s%s|r  |cff999999#%d%s|r"):format(ns.RARITY_COLORS[rarity], Capitalize(rarity), mint.number,
        mint.time and ("  " .. date("%Y-%m-%d", mint.time)) or ""))
    Fit(page.plaque, SIGN_FONT, RIGHT.plaque.size, 8, (picture.owner or ns.MyName()):match("^(%S+)"):upper(), RIGHT.plaque.w)

    -- The traits; on your own with the crayon edition, each switches its edition.
    local mine = picture.key == nil and picture.owner == nil
    local style = ns.MintStyle(mint)
    local editable = mine and ns.CrayonUnlocked(mint)
    for i, trait in ipairs(ns.MintTraits(mint.traits)) do
        local row = page.traitRows[i]
        if row then
            row.layer, row.editable, row.mint = trait[4], editable, mint
            row:EnableMouse(editable)
            row.text:SetText(("|cffffd100%s:|r |c%s%s|r"):format(trait[1], ns.RARITY_COLORS[trait[3]], trait[2]))
            local edition = ns.LayerEdition(style, trait[4])
            row.mark:SetText(edition and ("|cffff9a2a%s|r"):format(ns.EDITION_NAMES[edition]) or "")
            row:Show()
        end
    end

    -- The buttons (your own pictures only).
    if not mine then return end
    local n = 0
    local function Next() n = n + 1 return page.buttons[n] end
    if mint.duplicateOf then
        local b = Next()
        b:Set("REROLL", { "Reroll for free", ("%s minted this picture first."):format(mint.duplicateOf) })
        b.action = function() ns.ConfirmReroll(mint) end
    end
    local b = Next()
    b:Set(ns.IsShowcased(mint.number) and "UNSHOW" or "SHOWCASE",
        { "Your Overview's showcase", ("Show it on your Overview (up to %d)."):format(ns.SHOWCASE_SIZE) })
    b.action = function()
        local ok, reason = ns.ToggleShowcase(mint)
        if not ok then ns.Print(reason) end
    end
    local photo = KillTrackerDB.card and KillTrackerDB.card.portrait == mint.number
    b = Next()
    b:Set(photo and "NO PHOTO" or "AS PHOTO", { "Your Overview's photo", photo and "Show your character there again."
        or "Show this picture on your Overview instead of your character." })
    b.action = function()
        KillTrackerDB.card = KillTrackerDB.card or {}
        KillTrackerDB.card.portrait = not photo and mint.number or nil
        ns.Touch(KillTrackerDB.card)
    end
    if ns.CrayonUnlocked(mint) then
        local nextStyle = type(style) == "table" and ns.EDITIONS[1] or ns.NextEdition(style)
        b = Next()
        b:Set(nextStyle and nextStyle:upper() or "PAINTED", { "Crayon and sketch editions",
            "Redraw it all " .. (nextStyle and ("in " .. ns.EDITION_NAMES[nextStyle]) or "painted")
            .. ". Click a trait to switch just that one. Guildmates see it the way you pick." })
        b.action = function() ns.SetMintStyle(mint, nextStyle) end
    end
end

-- Opens a picture here (ns.ShowMint). owner: whose, if not yours (a short name).
function UI.PixShow(mint, owner)
    local key
    if owner then
        for _, friend in ipairs(ns.GetFriends()) do
            if friend.name == owner or Short(friend.key) == owner then key = friend.key end
        end
    end
    local wanted = { mint = mint, owner = owner, key = key }
    if page then
        page.pick = wanted
        page.tab = (key and key == state.viewing) and "mine" or owner and "guild" or (state.viewing and "guild" or "mine")
        page.offset = 0
    else
        UI.pendingPix = wanted
    end
    ns.OpenPage("collection")
end

ns.RegisterPage({
    key = "collection", label = "Pictures", section = "me", order = 3,
    bare = true,
    split = true,
    covers = { gallery = true },  -- (UI.lua) on the GUILD tab
    create = function(parent)
        page = CreateFrame("Frame", nil, parent)
        page:SetAllPoints()
        page.tab, page.offset = "mine", 0
        if UI.pendingPix then
            page.pick = UI.pendingPix
            page.tab = UI.pendingPix.owner and "guild" or "mine"
            UI.pendingPix = nil
        end
        local W = UI.window
        local slot, under = UI.SPLIT.left, UI.SPLIT.under
        local function At(region, point, x, y) region:SetPoint(point, W, "TOPLEFT", x, -y) end
        local function Ogre() return KillTrackerDB and KillTrackerDB.ogreMode end

        -- The boards.
        local book = CreateFrame("Frame", nil, page)
        book:SetAllPoints()
        local function Band(top, bottom, color, left, right)
            local fill = book:CreateTexture(nil, "BACKGROUND", nil, -8)
            At(fill, "TOPLEFT", left or under.left, top)
            fill:SetSize((right or under.middle) - (left or under.left), bottom - top)
            fill:SetColorTexture(unpack(color))
            return fill
        end
        Band(LEFT.tabs.top - 5, LEFT.tabs.bottom, LEFT.tabs.color)
        Band(LEFT.line.top, LEFT.line.bottom, LEFT.line.color)
        page.tilesBoard = Band(LEFT.line.bottom, under.bottom, LEFT.tiles.color)
        page.rowsBoard = Band(LEFT.rows.top, under.bottom, LEFT.rows.empty)
        Band(under.top, under.bottom, RIGHT.color, under.middle, under.right + 20)

        local left = CreateFrame("Frame", nil, page)
        left:SetAllPoints()
        left:SetFrameLevel(book:GetFrameLevel() + 2)

        -- The tabs.
        page.tabs = {}
        local tabWidth = (slot.right - slot.left) / #TABS
        for i, tab in ipairs(TABS) do
            local button = UI.TabButton(left, slot.left + (i - 1) * tabWidth, LEFT.tabs, tabWidth)
            function button:Redraw()
                local label = Ogre() and tab[3] or tab[2]
                if tab[1] == "mine" and state.viewing then label = Ogre() and "THEM" or "THEIRS" end
                self:SetTab(label, page.tab == tab[1])
            end
            button:SetScript("OnClick", function()
                UI.ClickSound()
                page.tab, page.offset, page.pick = tab[1], 0, nil
                ns.OpenPage(state.page)
            end)
            page.tabs[i] = button
        end
        page.line = left:CreateFontString(nil, "OVERLAY")
        page.line:SetFont(NAME_FONT, LEFT.line.size, "")
        page.line:SetTextColor(unpack(CREAM))
        At(page.line, "LEFT", slot.left + 10, (LEFT.line.top + LEFT.line.bottom) / 2)
        page.line:SetWidth(slot.right - slot.left - 20)
        page.line:SetJustifyH("LEFT")
        page.line:SetWordWrap(false)

        -- Under the tiles and rows: the wheel scrolls.
        local listArea = CreateFrame("Frame", nil, left)
        At(listArea, "TOPLEFT", slot.left - 20, LEFT.rows.top)
        listArea:SetSize(slot.right - slot.left + 40, slot.bottom - LEFT.rows.top)
        listArea:EnableMouse(true)
        listArea:EnableMouseWheel(true)
        listArea:SetScript("OnMouseWheel", function(_, delta)
            local most
            if page.tab == "shop" then
                most = math.max(0, #(page.data or {}) - #page.rows)
            else
                most = math.max(0, math.ceil(#(page.pictures or {}) / #LEFT.tiles.lefts) - #page.tiles / #LEFT.tiles.lefts)
            end
            local offset = math.max(0, math.min(most, page.offset - delta * (page.tab == "shop" and 3 or 1)))
            if offset ~= page.offset then
                page.offset = offset
                if page.tab == "shop" then DrawRows() else DrawTiles() end
            end
        end)

        -- The tiles: the picture in its rarity's colour, a band with whose (GUILD), a mark (* showcased, DUP).
        local spec = LEFT.tiles
        page.tiles = {}
        local visibleRows = math.floor((slot.bottom - spec.top + spec.step - spec.size) / spec.step)
        for r = 1, visibleRows do
            for c, x in ipairs(spec.lefts) do
                local tile = CreateFrame("Button", nil, left)
                tile:SetFrameLevel(listArea:GetFrameLevel() + 1)
                tile:SetSize(spec.size, spec.size)
                At(tile, "TOPLEFT", x, spec.top + (r - 1) * spec.step)
                tile.border = tile:CreateTexture(nil, "BACKGROUND")
                tile.border:SetAllPoints()
                tile.border:SetColorTexture(1, 1, 1)
                local inside = tile:CreateTexture(nil, "BORDER")
                inside:SetPoint("TOPLEFT", spec.rim, -spec.rim)
                inside:SetPoint("BOTTOMRIGHT", -spec.rim, spec.rim)
                inside:SetColorTexture(0.06, 0.06, 0.06)
                tile.canvas = CreateFrame("Frame", nil, tile)
                tile.canvas:SetPoint("TOPLEFT", spec.rim, -spec.rim)
                tile.canvas:SetPoint("BOTTOMRIGHT", -spec.rim, spec.rim)
                local over = CreateFrame("Frame", nil, tile)
                over:SetAllPoints()
                over:SetFrameLevel(tile.canvas:GetFrameLevel() + 10)
                tile.plus = over:CreateFontString(nil, "OVERLAY")
                tile.plus:SetFont(NAME_FONT, 40, "")
                tile.plus:SetPoint("CENTER", 0, 8)
                tile.plus:SetText("+")
                tile.plus:SetTextColor(unpack(GOLD))
                tile.band = over:CreateTexture(nil, "ARTWORK")
                tile.band:SetPoint("BOTTOMLEFT", spec.rim, spec.rim)
                tile.band:SetPoint("BOTTOMRIGHT", -spec.rim, spec.rim)
                tile.band:SetHeight(18)
                tile.band:SetColorTexture(0, 0, 0, 0.65)
                tile.caption = over:CreateFontString(nil, "OVERLAY")
                tile.caption:SetFont(NAME_FONT, 12, "")
                tile.caption:SetTextColor(unpack(CREAM))
                tile.caption:SetPoint("BOTTOM", 0, spec.rim + 3)
                tile.caption:SetWidth(spec.size - 8)
                tile.caption:SetWordWrap(false)
                tile.tag = over:CreateFontString(nil, "OVERLAY")
                tile.tag:SetFont(NAME_FONT, 14, "")
                tile.tag:SetPoint("TOPRIGHT", -6, -4)
                UI.OutlineText(tile.tag, { 0, 0, 0 })
                tile:SetScript("OnClick", function(self)
                    UI.ClickSound()
                    if self.picture.mintAction then return ns.ConfirmMint() end
                    Pick(self.picture)
                end)
                tile:SetScript("OnEnter", function(self)
                    local picture = self.picture
                    if picture.mintAction then
                        return Tooltip(self, { "Mint a picture", ("%d points. Rolls a random background, skin, outfit, expression, eyes, accessory and headwear. Rarer traits make a rarer picture."):format(ns.MintCost()) })
                    end
                    local mint = picture.mint
                    local rarity = ns.MintRarity(mint.traits)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:AddLine(("%s #%d"):format(picture.owner and (picture.owner .. "'s") or "Picture", mint.number))
                    GameTooltip:AddLine(Capitalize(rarity), ns.RarityRGB(rarity))
                    for _, trait in ipairs(ns.MintTraits(mint.traits)) do
                        GameTooltip:AddDoubleLine(trait[1], ("|c%s%s|r"):format(ns.RARITY_COLORS[trait[3]], trait[2]))
                    end
                    if mint.duplicateOf then GameTooltip:AddLine(("Duplicate of %s's"):format(mint.duplicateOf), 1, 0.4, 0.4) end
                    GameTooltip:Show()
                end)
                tile:SetScript("OnLeave", GameTooltip_Hide)
                page.tiles[#page.tiles + 1] = tile
            end
        end

        -- The SHOP rows.
        local rowsSpec, overhang = LEFT.rows, 20
        local rowWidth = slot.right - slot.left
        page.rows = {}
        for i = 1, math.floor((slot.bottom - rowsSpec.top) / rowsSpec.height) do
            local row = CreateFrame("Button", nil, left)
            row:SetFrameLevel(listArea:GetFrameLevel() + 1)
            row:SetSize(rowWidth + 2 * overhang, rowsSpec.height)
            At(row, "TOPLEFT", slot.left - overhang, rowsSpec.top + (i - 1) * rowsSpec.height)
            local shade = rowsSpec.colors[i % 2 == 1 and 1 or 2]
            row.stripe = row:CreateTexture(nil, "BACKGROUND")
            row.stripe:SetAllPoints()
            row.bar = row:CreateTexture(nil, "BORDER")
            row.bar:SetPoint("BOTTOMLEFT", overhang, 0)
            row.bar:SetHeight(rowsSpec.bar)
            row.bar:SetColorTexture(1, 1, 1)
            function row:SetBar(fraction) self.bar:SetWidth(math.max(1, rowWidth * math.min(1, fraction))) end
            row.count = row:CreateFontString(nil, "OVERLAY")
            row.count:SetFont(NAME_FONT, rowsSpec.size, "")
            row.count:SetTextColor(1, 0.75, 0.4)
            row.count:SetShadowOffset(1, -1)
            row.count:SetPoint("RIGHT", -(overhang + 6), 1)
            row.label = row:CreateFontString(nil, "OVERLAY")
            row.label:SetFont(NAME_FONT, rowsSpec.size, "")
            row.label:SetTextColor(0.94, 0.94, 0.94)
            row.label:SetShadowOffset(1, -1)
            row.label:SetPoint("LEFT", overhang + 8, 1)
            row.label:SetPoint("RIGHT", row.count, "LEFT", -8, 0)
            row.label:SetJustifyH("LEFT")
            row.label:SetWordWrap(false)
            function row:Paint(hovered) self.stripe:SetColorTexture(unpack(hovered and HOVER_COLOR or { shade, shade, shade })) end
            row:SetScript("OnEnter", function(self)
                if not self.data then return end
                self:Paint(true)
                List.RowTooltip(self)
            end)
            row:SetScript("OnLeave", function(self) self:Paint(false) GameTooltip_Hide() end)
            row:SetScript("OnClick", function(self)
                local d = self.data
                if not d then return end
                UI.ClickSound()
                if d.item and not d.owned and not state.viewing then
                    ns.ConfirmBuy(d.item)
                elseif d.mintAction then
                    ns.ConfirmMint()
                elseif d.extra and d.extra.onClick then
                    d.extra.onClick()
                end
            end)
            page.rows[i] = row
        end
        page.empty = left:CreateFontString(nil, "OVERLAY")
        page.empty:SetFont(NAME_FONT, 14, "")
        page.empty:SetTextColor(unpack(DIM))
        At(page.empty, "TOP", (slot.left + slot.right) / 2, LEFT.rows.top + 40)

        -- The right page.
        local card = CreateFrame("Frame", nil, page)
        card:SetAllPoints()
        card:SetFrameLevel(book:GetFrameLevel() + 2)
        local photo = CreateFrame("Frame", nil, card)
        photo:SetSize(RIGHT.photo.w, RIGHT.photo.h)
        At(photo, "CENTER", RIGHT.photo.x, RIGHT.photo.y)
        local sky = photo:CreateTexture(nil, "BACKGROUND")
        sky:SetAllPoints()
        sky:SetColorTexture(0.06, 0.05, 0.05)
        page.canvas = CreateFrame("Button", nil, card)
        page.canvas:SetSize(RIGHT.picture.size, RIGHT.picture.size)
        At(page.canvas, "CENTER", RIGHT.picture.x, RIGHT.picture.y)
        page.canvas:SetFrameLevel(photo:GetFrameLevel() + 1)
        page.nothing = photo:CreateFontString(nil, "OVERLAY")
        page.nothing:SetFont(NAME_FONT, 15, "")
        page.nothing:SetTextColor(unpack(DIM))
        page.nothing:SetPoint("CENTER")
        page.nothing:SetWidth(RIGHT.photo.w - 40)
        page.invite = CreateFrame("Button", nil, card)
        page.invite:SetAllPoints(photo)
        page.invite:SetFrameLevel(page.canvas:GetFrameLevel() + 1)
        local inviteGlow = page.invite:CreateTexture(nil, "HIGHLIGHT")
        inviteGlow:SetAllPoints()
        inviteGlow:SetColorTexture(1, 0.85, 0.3, 0.08)
        page.invite:SetScript("OnClick", function() UI.ClickSound() ns.ConfirmMint() end)
        page.invite:SetScript("OnEnter", function(self)
            Tooltip(self, { "Mint a picture", "Rolls a random background, skin, outfit, expression, eyes, accessory and headwear. Rarer traits make a rarer picture." })
        end)
        page.invite:SetScript("OnLeave", GameTooltip_Hide)
        page.invite:Hide()
        local hung = CreateFrame("Frame", nil, card)
        hung:SetAllPoints()
        hung:SetFrameLevel(page.canvas:GetFrameLevel() + 10)
        local frameArt = hung:CreateTexture(nil, "ARTWORK")
        frameArt:SetTexture(ART .. "HangingPicture")
        frameArt:SetTexCoord(0, RIGHT.frame.w / 512, 0, RIGHT.frame.h / 512)
        frameArt:SetSize(RIGHT.frame.w, RIGHT.frame.h)
        At(frameArt, "TOPLEFT", RIGHT.frame.x, RIGHT.frame.y)
        page.rarity = hung:CreateFontString(nil, "OVERLAY")
        page.rarity:SetFont(NAME_FONT, 13, "")
        At(page.rarity, "CENTER", RIGHT.rarity.x, RIGHT.rarity.y)
        UI.OutlineText(page.rarity, { 0, 0, 0 })
        page.plaque = hung:CreateFontString(nil, "OVERLAY")
        At(page.plaque, "CENTER", RIGHT.plaque.x, RIGHT.plaque.y)
        page.plaque:SetTextColor(unpack(INK))
        page.plaque:SetShadowOffset(0, 0)

        local traits = RIGHT.traits
        page.traitRows = {}
        for i = 1, 7 do
            local row = CreateFrame("Button", nil, card)
            row:SetSize(traits.width, traits.line)
            At(row, "TOPLEFT", traits.x, traits.top + (i - 1) * traits.line)
            row.text = row:CreateFontString(nil, "OVERLAY")
            row.text:SetFont(NAME_FONT, traits.size, "")
            row.text:SetPoint("LEFT")
            row.text:SetPoint("RIGHT", -52, 0)
            row.text:SetJustifyH("LEFT")
            row.text:SetWordWrap(false)
            row.mark = row:CreateFontString(nil, "OVERLAY")
            row.mark:SetFont(NAME_FONT, traits.size, "")
            row.mark:SetPoint("RIGHT")
            local glow = row:CreateTexture(nil, "BACKGROUND")
            glow:SetAllPoints()
            glow:SetColorTexture(1, 1, 1, 0.08)
            glow:Hide()
            row:SetScript("OnClick", function(self)
                if not self.editable then return end
                UI.ClickSound()
                ns.SetLayerEdition(self.mint, self.layer, ns.NextEdition(ns.LayerEdition(ns.MintStyle(self.mint), self.layer)))
                ns.OpenPage(state.page)
            end)
            row:SetScript("OnEnter", function(self)
                if not self.editable then return end
                glow:Show()
                Tooltip(self, { "Click to draw this one painted, in crayon or sketched, in turn" })
            end)
            row:SetScript("OnLeave", function() glow:Hide() GameTooltip_Hide() end)
            page.traitRows[i] = row
        end
        local spec2 = RIGHT.buttons
        page.buttons = {}
        for i = 1, 4 do
            local button = Plate(card, spec2.w, spec2.h)
            At(button, "TOPLEFT", spec2.x, spec2.top + (i - 1) * (spec2.h + spec2.gap))
            button:SetScript("OnClick", function(self)
                UI.ClickSound()
                if self.action then self.action() end
                ns.OpenPage(state.page)
            end)
            button:Hide()
            page.buttons[i] = button
        end
        return page
    end,

    refresh = function(p)
        if state.viewing and not KillTrackerFriends[state.viewing] then state.viewing = nil end
        -- The tab: GUILD when coming in from the Gallery.
        if p.asked ~= state.page then
            if TAB_FOR_PAGE[state.page] then p.tab, p.offset = TAB_FOR_PAGE[state.page], 0 end
            p.asked = state.page
        end
        if p.who ~= state.viewing then
            if p.tab ~= "guild" then p.pick, p.offset = nil, 0 end
            p.who = state.viewing
        end
        for _, tab in ipairs(p.tabs) do tab:Redraw(false) end
        ns.UpdateDuplicates()

        local shop = p.tab == "shop"
        p.tilesBoard:SetShown(not shop)
        p.rowsBoard:SetShown(shop)
        for _, tile in ipairs(p.tiles) do tile:SetShown(not shop) end
        for _, row in ipairs(p.rows) do row:SetShown(shop) end
        if shop then
            if state.listPage ~= "pix" or state.view ~= "collection" then state.path = {} end
            state.view, state.listPage = "collection", "pix"
            p.data = {}
            for _, d in ipairs(List.BuildRows()) do
                if not d.mint then p.data[#p.data + 1] = d end  -- the pictures are in MINE
            end
            p.total, p.max = 0, 0
            p.pictures = nil
            local points = ns.GetPoints(List.Source())
            p.line:SetText(("|cffffbf66%d|r points  |cff999999(%d earned, %d spent)|r"):format(points.balance, points.earned, points.spent))
            p.empty:SetText("")
            p.offset = math.min(p.offset, math.max(0, #p.data - #p.rows))
            DrawRows()
        else
            local guild = p.tab == "guild"
            p.pictures = guild and GuildPictures() or PicturesOf(state.viewing)
            local count = #p.pictures
            if not guild and not state.viewing then table.insert(p.pictures, 1, { mintAction = true }) end
            p.line:SetText(guild and ("|cffffbf66%d|r pictures in the guild, newest first"):format(count)
                or ("|cffffbf66%d|r picture%s%s"):format(count, count == 1 and "" or "s",
                    state.viewing and "" or ("  |cff999999- %d points|r"):format(ns.GetPoints().balance)))
            p.empty:SetText(guild and "No pictures in the guild yet." or "No pictures yet.")
            local perRow = #LEFT.tiles.lefts
            p.offset = math.min(p.offset, math.max(0, math.ceil(#p.pictures / perRow) - #p.tiles / perRow))
            DrawTiles()
        end
        DrawPick()
    end,
})
