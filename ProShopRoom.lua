-- The Pro Shop's room: its own page in the sidebar (Guild: Pro Shop; SHOP in ogre mode), the whole page area.
-- The ROOM: a stand-in until the shop floor is repainted - the concept painting (Media/ProShop/Room: the steward
-- behind his counter, the shelves; tools/make-mannequin.js) with the Dream Bed's easel standing on the floor, the display
-- set painted on its canvas: the walnut mannequin (Media/ProShop/Mannequin, the moss ogre in walnut) wearing it.
-- Click the easel -> ZOOMED IN: the room blurs and dims (it crossfades to a pre-blurred twin, Media/ProShop/Room-blur),
-- the easel's picture comes forward to the middle in a gilt and burgundy border, red velvet curtains slide in from the
-- sides and a valance drops in on top. The left curtain: a brass plaque per layer in stock (Hats, Outfits,
-- Accessories); the right: the piece's name, rarity, price (or "In your wardrobe") and your cart (a piece a layer, the
-- total, your points, Checkout: bought at once for now, the steward rings it up later). Under the picture: knobs either
-- side of Add to cart and a count. The mannequin wears the display set, the cart over it, the piece looked at over that
-- (hats zoomed further in). Keys: W/S or Up/Down tabs, A/D or Left/Right pieces, Enter adds, Escape goes back. Back or Escape -> the room. The wares and buying: ProShop.lua.

local _, ns = ...
local UI = ns.UI
if not UI then return end

local MEDIA = "Interface\\AddOns\\SOLC\\Media\\ProShop\\"
local EASEL_ART = "Interface\\AddOns\\SOLC\\Media\\DreamBed\\easel"
local NAME_FONT = "Interface\\AddOns\\SOLC\\Media\\Fonts\\GermaniaOne-Regular.ttf"
local CREAM, GOLD, GILT = { 0.96, 0.9, 0.78 }, { 1, 0.82, 0.1 }, { 0.79, 0.63, 0.29 }
local BURGUNDY = { 0.3, 0.06, 0.09 }
local VELVET_LIT, VELVET_DARK = { 0.55, 0.1, 0.13 }, { 0.22, 0.03, 0.05 }

-- The room's painting is 827 x 584 (the page's size): everything is placed in its pixels and scaled to the page.
local SCENE_W, SCENE_H = 827, 584
local BLEED = 14  -- (the painting, and the zoomed view, run this far under the wooden frame on every side)
local EASEL = { x = 650, bottom = 548, height = 370 }  -- (its middle, where its feet stand: by the sewing table)
local PICTURE = { x = 413, y = 255, size = 340 }  -- zoomed in: its middle and size
local CURTAIN_W, VALANCE_H = 200, 58
local OPEN_TIME = 0.55
local ZOOM_TIME, CLOSE_ZOOM = 0.4, 1.6  -- (switching to a head layer's tab: how long the zoom takes, how far in)

-- What the mannequin wears when you walk in.
ns.SHOP_DISPLAY = { headwear = "shop_flat_cap", outfit = "shop_argyle_vest" }

local room

local function Gradient(tex, orientation, from, to)
    tex:SetColorTexture(1, 1, 1)
    tex:SetGradient(orientation, CreateColor(from[1], from[2], from[3], from[4] or 1), CreateColor(to[1], to[2], to[3], to[4] or 1))
end

-- The room's scale: page pixels per painting pixel, the painting stretched BLEED past the page on every side.
local function Scale()
    local w, h = room:GetSize()
    if w == 0 or h == 0 then return end
    return (w + 2 * BLEED) / SCENE_W, (h + 2 * BLEED) / SCENE_H
end

-- The pieces a set of traits wears, by layer key: { [layer key] = option }.
local function Worn(traits)
    local worn = {}
    for _, layer in ipairs(ns.MintLayers or {}) do
        for _, option in ipairs(layer.options) do
            if option.id == traits[layer.key] then worn[layer.key] = option end
        end
    end
    return worn
end

-- A picture of the mannequin: a velvet backdrop, the walnut body and the pieces it wears. picture:Dress(traits, size)
-- draws it at that size (the pieces are placed by it); picture:SetZoom(z, instant) zooms it in (z > 1) keeping its top
-- (a whole hat), easing in and out over ZOOM_TIME - the drawing only scaled, not drawn again.
local function NewPicture(parent)
    local picture = CreateFrame("Frame", nil, parent)
    local backdrop = picture:CreateTexture(nil, "BACKGROUND")
    backdrop:SetAllPoints()
    Gradient(backdrop, "VERTICAL", { 0.16, 0.05, 0.04 }, { 0.42, 0.17, 0.12 })
    picture.canvas = CreateFrame("Frame", nil, picture)
    picture.canvas:SetPoint("TOP")  -- (unzoomed it fills the picture; zoomed in, the top stays put)
    picture.body = picture.canvas:CreateTexture(nil, "ARTWORK", nil, -4)  -- (the skin's sublevel: Minting.lua)
    picture.body:SetAllPoints()
    picture.body:SetTexture(MEDIA .. "Mannequin")
    picture.masks = {}
    -- The pieces drawn as a picture with no skin (ns.RenderMint), the walnut body in the skin's place under them, cut
    -- where the pieces hide the body (their masks, as RenderMint puts them on a skin).
    function picture:Dress(traits, size)
        local key = tostring(size)
        for _, layer in ipairs(ns.MintLayers or {}) do key = key .. "|" .. (traits[layer.key] or "") end
        if self.key == key then return end
        self.canvas:SetSize(size, size)
        ns.RenderMint(self.canvas, traits)
        for _, mask in ipairs(self.masks) do self.body:RemoveMaskTexture(mask) end
        wipe(self.masks)
        for _, option in pairs(Worn(traits)) do
            if option.hide then
                local mask = self.canvas:CreateMaskTexture()
                mask:SetTexture(option.hide, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
                mask:SetAllPoints(self.canvas)
                self.body:AddMaskTexture(mask)
                self.masks[#self.masks + 1] = mask
            end
        end
        self.key = key
    end
    picture.z = 1
    function picture:SetZoom(z, instant)
        if instant then
            self.z, self.zTo, self.zT = z, z, nil
            self.canvas:SetScale(z)
        elseif z ~= self.zTo then
            self.zFrom, self.zTo, self.zT = self.z, z, 0
        end
    end
    picture:SetScript("OnUpdate", function(self, elapsed)
        if not self.zT then return end
        self.zT = math.min(1, self.zT + elapsed / ZOOM_TIME)
        local e = self.zT * self.zT * (3 - 2 * self.zT)  -- (smoothstep: eases in and out)
        self.z = self.zFrom + (self.zTo - self.zFrom) * e
        self.canvas:SetScale(self.z)
        if self.zT == 1 then self.zT = nil end
    end)
    return picture
end

-- A dark pill with a brass rim and a label (the cart, Back).
local function Pill(parent, width, text)
    local pill = CreateFrame("Button", nil, parent)
    pill:SetSize(width, 30)
    local rim = pill:CreateTexture(nil, "BACKGROUND", nil, -1)
    rim:SetPoint("TOPLEFT", -1, 1) rim:SetPoint("BOTTOMRIGHT", 1, -1)
    rim:SetColorTexture(unpack(GILT))
    local fill = pill:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    fill:SetColorTexture(0.12, 0.07, 0.04, 0.95)
    pill.text = pill:CreateFontString(nil, "OVERLAY")
    pill.text:SetPoint("CENTER")
    pill.text:SetFont(NAME_FONT, 15, "")
    pill.text:SetTextColor(unpack(CREAM))
    pill.text:SetText(text or "")
    pill:SetScript("OnEnter", function(self) self.text:SetTextColor(unpack(GOLD)) end)
    pill:SetScript("OnLeave", function(self) self.text:SetTextColor(unpack(CREAM)) GameTooltip:Hide() end)
    return pill
end

-- A velvet curtain: folds across it (lit and shaded in turn), a gilt edge on the side facing the middle.
local function Curtain(parent, side)
    local curtain = CreateFrame("Frame", nil, parent)
    curtain.folds = {}
    for i = 1, 16 do
        local fold = curtain:CreateTexture(nil, "BACKGROUND")
        local lit = i % 2 == 0
        Gradient(fold, "HORIZONTAL", lit and VELVET_DARK or VELVET_LIT, lit and VELVET_LIT or VELVET_DARK)
        curtain.folds[i] = fold
    end
    local shade = curtain:CreateTexture(nil, "BORDER")  -- (darker towards the top, under the valance)
    shade:SetAllPoints()
    Gradient(shade, "VERTICAL", { 0, 0, 0, 0 }, { 0, 0, 0, 0.45 })
    local edge = curtain:CreateTexture(nil, "ARTWORK")
    edge:SetPoint("TOP") edge:SetPoint("BOTTOM")
    edge:SetPoint(side == "left" and "RIGHT" or "LEFT")
    edge:SetWidth(3)
    edge:SetColorTexture(unpack(GILT))
    function curtain:Layout(width)
        local w = width / #self.folds
        for i, fold in ipairs(self.folds) do
            fold:ClearAllPoints()
            fold:SetPoint("TOPLEFT", (i - 1) * w, 0)
            fold:SetPoint("BOTTOMLEFT", (i - 1) * w, 0)
            fold:SetWidth(w + 0.5)
        end
    end
    return curtain
end

-- The dressing (zoomed in): the layers the shop stocks as tabs, the piece looked at on each, the cart (one piece a
-- layer; kept while you're logged in).
local TAB_ORDER = { "headwear", "outfit", "accessory", "skin", "eyes", "expression", "background" }
local TAB_LABELS = { headwear = "Hats", outfit = "Outfits", accessory = "Accessories", skin = "Skins", eyes = "Eyes", expression = "Faces", background = "Backdrops" }
local PIECE_WORDS = { headwear = "hat", outfit = "outfit", accessory = "accessory", skin = "skin", eyes = "eyes", expression = "face", background = "backdrop" }
local CLOSE_LAYERS = { headwear = true, eyes = true, expression = true }
local view = { tab = 1, look = {}, cart = {} }  -- look[layer key] = its stock's index; cart[layer key] = a stock item

-- The tabs: { key, label, items (stock items, cheapest first) }, for the layers with something in stock.
local function Tabs()
    if view.tabs then return view.tabs end
    local byLayer = {}
    for _, item in ipairs(ns.ShopStock()) do
        byLayer[item.layer.key] = byLayer[item.layer.key] or {}
        table.insert(byLayer[item.layer.key], item)
    end
    local tabs = {}
    for _, key in ipairs(TAB_ORDER) do
        local items = byLayer[key]
        if items then
            table.sort(items, function(a, b)
                if a.price ~= b.price then return a.price < b.price end
                return a.option.name < b.option.name
            end)
            tabs[#tabs + 1] = { key = key, label = TAB_LABELS[key], items = items }
        end
    end
    for key, old in pairs(view.cart) do  -- (the cart's pieces in the new stock; ones you own now drop out)
        local found
        for _, item in ipairs(byLayer[key] or {}) do if item.key == old.key and not item.owned then found = item end end
        view.cart[key] = found
    end
    view.tabs = tabs
    return tabs
end

-- The piece looked at, its tab and its place in it.
local function Looked()
    local tab = Tabs()[view.tab]
    if not tab then return end
    local index = view.look[tab.key] or 1
    return tab.items[index], tab, index
end

-- What the mannequin wears: the display set, the cart over it, the piece looked at over that.
local function ShownTraits()
    local traits = {}
    for key, id in pairs(ns.SHOP_DISPLAY) do traits[key] = id end
    for key, item in pairs(view.cart) do traits[key] = item.option.id end
    local item, tab = Looked()
    if item then traits[tab.key] = item.option.id end
    return traits
end

-- The cart: its pieces in the tabs' order, and what they cost.
local function CartItems()
    local items, total = {}, 0
    for _, key in ipairs(TAB_ORDER) do
        local item = view.cart[key]
        if item then
            items[#items + 1] = item
            total = total + item.price
        end
    end
    return items, total
end

-- The zoomed view at its point in the opening (zoom.t, 0 closed .. 1 open, eased).
local function PlaceZoom()
    local zoom = room.zoom
    local sx, sy = Scale()
    if not sx then return end
    local t = 1 - (1 - (zoom.t or 0)) ^ 3
    local cw = CURTAIN_W * sx
    zoom.left:ClearAllPoints()
    zoom.left:SetPoint("TOPLEFT", -cw * (1 - t), 0) zoom.left:SetPoint("BOTTOMLEFT", -cw * (1 - t), 0)
    zoom.left:SetWidth(cw)
    zoom.right:ClearAllPoints()
    zoom.right:SetPoint("TOPRIGHT", cw * (1 - t), 0) zoom.right:SetPoint("BOTTOMRIGHT", cw * (1 - t), 0)
    zoom.right:SetWidth(cw)
    zoom.left:Layout(cw) zoom.right:Layout(cw)
    local vh = VALANCE_H * sy
    zoom.valance:ClearAllPoints()
    zoom.valance:SetPoint("TOPLEFT", 0, (vh + 10) * (1 - t)) zoom.valance:SetPoint("TOPRIGHT", 0, (vh + 10) * (1 - t))
    zoom.valance:SetHeight(vh)
    zoom.dim:SetAlpha(t)
    room.blur:SetAlpha(t)
    room.easel:SetAlpha(1 - t)  -- (its picture comes forward; the easel goes with the sharp room)
    local size = math.floor(PICTURE.size * math.min(sx, sy))
    zoom.frame:ClearAllPoints()
    zoom.frame:SetPoint("CENTER", room, "TOPLEFT", PICTURE.x * sx - BLEED, BLEED - PICTURE.y * sy)
    zoom.frame:SetSize(size, size)
    zoom.frame:SetAlpha(math.max(0, (zoom.t or 0) * 2 - 1))  -- (comes in once the curtains are half way)
    local _, tab = Looked()
    zoom.picture:Dress(ShownTraits(), size)
    zoom.picture:SetZoom(tab and CLOSE_LAYERS[tab.key] and CLOSE_ZOOM or 1, (zoom.t or 0) < 1)  -- (opening: no zoom on top)
    zoom.controls:SetAlpha(math.max(0, (zoom.t or 0) * 2 - 1))
    zoom.back:ClearAllPoints()
    zoom.back:SetPoint("BOTTOM", room, "BOTTOM", 0, 12)
    zoom.back:SetAlpha(t)
end

-- Zooms in on the easel (true) or back out to the room.
local function Zoom(open)
    local zoom = room.zoom
    if open then
        if not zoom:IsShown() then zoom.t = 0 end
        zoom:Show()
        if not InCombatLockdown() then zoom:EnableKeyboard(true) end
        PlaceZoom()
    elseif not zoom:IsShown() then
        return
    elseif not InCombatLockdown() then
        zoom:EnableKeyboard(false)
    end
    zoom.goal = open
end

-- Draws the dressing: the tabs, the piece's info, the cart, the buttons; the mannequin (PlaceZoom). And the room's
-- cart pill.
local function Redraw()
    local zoom = room.zoom
    local tabs = Tabs()
    PlaceZoom()  -- (first: the curtains' width, which the name is fitted to)
    for i, tab in ipairs(tabs) do
        local plaque = zoom.plaques[i]
        plaque.text:SetText(tab.label)
        plaque:SetLit(i == view.tab)
        plaque:Show()
    end
    for i = #tabs + 1, #zoom.plaques do zoom.plaques[i]:Hide() end
    local info = zoom.info
    local item, tab, index = Looked()
    if item then
        UI.FitText(info.name, NAME_FONT, 20, 12, item.option.name, info:GetWidth() - 16)
        info.name:SetTextColor(ns.RarityRGB(item.option.rarity))
        info.line:SetText(item.option.rarity:gsub("^%l", string.upper) .. " " .. (PIECE_WORDS[tab.key] or ""))
        info.price:SetText(item.owned and "In your wardrobe" or (BreakUpLargeNumbers(item.price) .. " points"))
        info.price:SetTextColor(unpack(item.owned and CREAM or GOLD))
        zoom.count:SetText(("%d / %d"):format(index, #tab.items))
        zoom.add.text:SetText(item.owned and "Yours already" or view.cart[tab.key] == item and "Take it out" or "Add to cart")
        zoom.add:SetEnabled(not item.owned)
        zoom.add:SetAlpha(item.owned and 0.6 or 1)
    end
    local items, total = CartItems()
    for i, line in ipairs(info.lines) do
        local inCart = items[i]
        if inCart then
            line.name:SetText(inCart.option.name)
            line.name:SetTextColor(ns.RarityRGB(inCart.option.rarity))
            line.price:SetText(BreakUpLargeNumbers(inCart.price))
            line.item = inCart
        end
        line:SetShown(inCart ~= nil)
    end
    info.empty:SetShown(#items == 0)
    local balance = ns.GetPoints().balance
    local canBuy = #items > 0 and total <= balance
    info.total:SetText(("Total  |cffffd21a%s|r"):format(BreakUpLargeNumbers(total)))
    info.points:SetText(("You have %s points"):format(BreakUpLargeNumbers(balance)))
    info.message:SetText(view.message or (total > balance and ("%s points short"):format(BreakUpLargeNumbers(total - balance))) or "")
    info.checkout:SetEnabled(canBuy)
    info.checkout:SetAlpha(canBuy and 1 or 0.5)
    room.cart.text:SetText(("Cart (%d)"):format(#items))
end

-- Moves to another tab (dt) or piece (di), round the ends.
local function Step(dt, di)
    local tabs = Tabs()
    if #tabs == 0 then return end
    view.tab = (view.tab - 1 + dt) % #tabs + 1
    local tab = tabs[view.tab]
    view.look[tab.key] = ((view.look[tab.key] or 1) - 1 + di) % #tab.items + 1
    view.message = nil
    Redraw()
end

-- Puts the piece looked at in the cart (in its layer's place) or takes it out again.
local function ToggleCart()
    local item, tab = Looked()
    if not item or item.owned then return end
    if view.cart[tab.key] == item then view.cart[tab.key] = nil else view.cart[tab.key] = item end
    view.message = nil
    Redraw()
end

-- Buys the cart (the steward rings it up later; for now it's straight to the till).
local function Checkout()
    local keys = {}
    for i, item in ipairs((CartItems())) do keys[i] = item.key end
    local ok, result = ns.ShopBuy(keys)
    if ok then
        ns.ShowToast("achievement", "Bought at the Pro Shop", (#keys == 1 and "1 piece" or #keys .. " pieces") .. " for "
            .. BreakUpLargeNumbers(result) .. " points", "In your wardrobe: wear it from your Overview's EDIT")
        wipe(view.cart)
        view.tabs, view.message = nil, nil  -- (what you own changed)
    else
        view.message = result
    end
    Redraw()
end

local function Build(holder)
    room = CreateFrame("Frame", nil, holder)
    room:SetAllPoints()
    room.scene = room:CreateTexture(nil, "BACKGROUND")
    room.scene:SetPoint("TOPLEFT", -BLEED, BLEED)
    room.scene:SetPoint("BOTTOMRIGHT", BLEED, -BLEED)
    room.scene:SetTexture(MEDIA .. "Room")
    room.scene:SetTexCoord(0, SCENE_W / 1024, 0, SCENE_H / 1024)
    room.blur = room:CreateTexture(nil, "BACKGROUND", nil, 1)  -- (zoomed in: the room crossfades to its blurred twin)
    room.blur:SetAllPoints(room.scene)
    room.blur:SetTexture(MEDIA .. "Room-blur")
    room.blur:SetTexCoord(0, SCENE_W / 1024, 0, SCENE_H / 1024)
    room.blur:SetAlpha(0)

    -- The easel, the display set painted on its canvas (square, cut at the canvas's edges, as the Dream Bed does).
    local art = ns.DreamBedArt or {}
    local box = art.pieces and art.pieces.easel and art.pieces.easel.box or { x = 0.2246, y = 0.0117, w = 0.5508, h = 0.9355 }
    local easel = CreateFrame("Button", nil, room)
    easel.box, easel.cv = box, art.easelCanvas or { x = 0.0815, y = 0.1232, w = 0.8226, h = 0.4489 }
    easel.board = easel:CreateTexture(nil, "ARTWORK")
    easel.board:SetAllPoints()
    easel.board:SetTexture(EASEL_ART)
    easel.board:SetTexCoord(box.x, box.x + box.w, box.y, box.y + box.h)
    easel.board:SetVertexColor(0.88, 0.86, 0.82)  -- (lit up while pointed at)
    easel.blank = CreateFrame("Frame", nil, easel)
    easel.blank:SetClipsChildren(true)
    easel.picture = NewPicture(easel.blank)
    easel.picture:SetPoint("CENTER")
    easel.hint = Pill(easel, 130, "Try things on")
    easel.hint:SetPoint("BOTTOM", easel, "TOP", 0, 4)
    easel.hint:EnableMouse(false)
    easel.hint:Hide()
    easel:SetScript("OnEnter", function(self)
        self.hint:Show()
        self.board:SetVertexColor(1, 1, 1)
    end)
    easel:SetScript("OnLeave", function(self)
        self.hint:Hide()
        self.board:SetVertexColor(0.88, 0.86, 0.82)
    end)
    easel:SetScript("OnClick", function() Zoom(true) end)
    room.easel = easel

    -- Your points and the cart, in the corner (empty until the curtains can fill it).
    room.corner = CreateFrame("Frame", nil, room)  -- (over the easel)
    room.corner:SetAllPoints()
    room.corner:SetFrameLevel(easel:GetFrameLevel() + 5)
    room.cart = Pill(room.corner, 110, "Cart (0)")
    room.cart:SetPoint("BOTTOMRIGHT", -14, 12)
    room.cart:HookScript("OnEnter", function(self)
        local items, total = CartItems()
        local lines = { "Your cart" }
        for _, item in ipairs(items) do lines[#lines + 1] = item.option.name .. " - " .. BreakUpLargeNumbers(item.price) end
        lines[#lines + 1] = #items == 0 and "Empty. Try something on first." or ("Total: %s points"):format(BreakUpLargeNumbers(total))
        UI.Tooltip(self, lines)
    end)
    room.cart:SetScript("OnClick", function() Zoom(true) end)
    room.points = room.corner:CreateFontString(nil, "OVERLAY")
    room.points:SetPoint("BOTTOMRIGHT", room.cart, "TOPRIGHT", 0, 5)
    room.points:SetFont(NAME_FONT, 14, "")
    room.points:SetTextColor(unpack(CREAM))
    UI.OutlineText(room.points, { 0, 0, 0 })

    -- Zoomed in: over the room (which takes no clicks while it's up).
    local zoom = CreateFrame("Frame", nil, room)
    zoom:SetPoint("TOPLEFT", -BLEED, BLEED)
    zoom:SetPoint("BOTTOMRIGHT", BLEED, -BLEED)
    -- (under the window's posts and beams, UI.FRAME_LEVEL.wood, so they cover what runs under them; its own parts sit up
    -- to 6 levels above it)
    zoom:SetFrameLevel(UI.window:GetFrameLevel() + UI.FRAME_LEVEL.wood - 8)
    zoom:EnableMouse(true)
    zoom:Hide()
    zoom.dim = zoom:CreateTexture(nil, "BACKGROUND")
    zoom.dim:SetAllPoints()
    zoom.dim:SetColorTexture(0, 0, 0, 0.5)
    zoom.frame = CreateFrame("Frame", nil, zoom)  -- the border: a shadow, gilt, burgundy, then the picture
    local shadow = zoom.frame:CreateTexture(nil, "BACKGROUND", nil, -2)
    shadow:SetPoint("TOPLEFT", -2, -6) shadow:SetPoint("BOTTOMRIGHT", 6, -10)
    shadow:SetColorTexture(0, 0, 0, 0.55)
    local gilt = zoom.frame:CreateTexture(nil, "BACKGROUND", nil, -1)
    gilt:SetPoint("TOPLEFT", -4, 4) gilt:SetPoint("BOTTOMRIGHT", 4, -4)
    gilt:SetColorTexture(unpack(GILT))
    local burgundy = zoom.frame:CreateTexture(nil, "BACKGROUND")
    burgundy:SetPoint("TOPLEFT", -2, 2) burgundy:SetPoint("BOTTOMRIGHT", 2, -2)
    burgundy:SetColorTexture(unpack(BURGUNDY))
    zoom.picture = NewPicture(zoom.frame)
    zoom.picture:SetAllPoints()
    zoom.picture:SetClipsChildren(true)
    zoom.left, zoom.right = Curtain(zoom, "left"), Curtain(zoom, "right")
    zoom.valance = CreateFrame("Frame", nil, zoom)
    zoom.valance:SetFrameLevel(zoom.left:GetFrameLevel() + 2)
    local valance = zoom.valance:CreateTexture(nil, "BACKGROUND")
    valance:SetAllPoints()
    Gradient(valance, "VERTICAL", VELVET_DARK, VELVET_LIT)
    local trim = zoom.valance:CreateTexture(nil, "ARTWORK")
    trim:SetPoint("BOTTOMLEFT", 0, 6) trim:SetPoint("BOTTOMRIGHT", 0, 6)
    trim:SetHeight(3)
    trim:SetColorTexture(unpack(GILT))
    local fringe = zoom.valance:CreateTexture(nil, "ARTWORK")
    fringe:SetPoint("TOPLEFT", zoom.valance, "BOTTOMLEFT") fringe:SetPoint("TOPRIGHT", zoom.valance, "BOTTOMRIGHT")
    fringe:SetHeight(8)
    Gradient(fringe, "VERTICAL", { GILT[1], GILT[2], GILT[3], 0 }, { GILT[1], GILT[2], GILT[3], 0.9 })
    zoom.back = Pill(zoom, 170, "Back to the shop")
    zoom.back:SetFrameLevel(zoom.valance:GetFrameLevel() + 1)
    zoom.back:SetScript("OnClick", function() Zoom(false) end)
    -- The left curtain: a brass plaque a tab (polished: the one open).
    zoom.plaques = {}
    for i = 1, #TAB_ORDER do
        local plaque = CreateFrame("Button", nil, zoom.left)
        plaque:SetSize(150, 30)
        plaque:SetPoint("TOP", 0, -(VALANCE_H + 40 + (i - 1) * 38))
        local rim = plaque:CreateTexture(nil, "BACKGROUND", nil, -1)
        rim:SetPoint("TOPLEFT", -1, 1) rim:SetPoint("BOTTOMRIGHT", 1, -1)
        rim:SetColorTexture(0.24, 0.15, 0.06)
        plaque.fill = plaque:CreateTexture(nil, "BACKGROUND")
        plaque.fill:SetAllPoints()
        plaque.text = plaque:CreateFontString(nil, "OVERLAY")
        plaque.text:SetPoint("CENTER")
        plaque.text:SetFont(NAME_FONT, 16, "")
        function plaque:SetLit(lit)
            self.lit = lit
            Gradient(self.fill, "VERTICAL", lit and { 0.72, 0.55, 0.22 } or { 0.3, 0.2, 0.09 }, lit and { 1, 0.88, 0.55 } or { 0.52, 0.38, 0.18 })
            self.text:SetTextColor(unpack(lit and { 0.23, 0.15, 0.08 } or CREAM))
        end
        plaque:SetScript("OnClick", function() Step(i - view.tab, 0) end)
        plaque:SetScript("OnEnter", function(self) if not self.lit then self.text:SetTextColor(unpack(GOLD)) end end)
        plaque:SetScript("OnLeave", function(self) if not self.lit then self.text:SetTextColor(unpack(CREAM)) end end)
        zoom.plaques[i] = plaque
    end
    -- The right curtain: a dark panel with the piece's info and the cart.
    local info = CreateFrame("Frame", nil, zoom.right)
    info:SetPoint("TOPLEFT", 12, -(VALANCE_H + 30))
    info:SetPoint("BOTTOMRIGHT", -12, 60)
    local panel = info:CreateTexture(nil, "BACKGROUND")
    panel:SetAllPoints()
    Gradient(panel, "VERTICAL", { 0.17, 0.03, 0.05, 0.95 }, { 0.24, 0.04, 0.07, 0.95 })
    local function Text(size, color)
        local text = info:CreateFontString(nil, "OVERLAY")
        text:SetFont(NAME_FONT, size, "")
        text:SetTextColor(unpack(color))
        return text
    end
    info.name = Text(20, CREAM)
    info.name:SetPoint("TOP", 0, -12)
    info.name:SetHeight(26)  -- (a fixed slot: a long name shrinks to fit without moving what's under it)
    info.name:SetJustifyV("MIDDLE")
    info.line = Text(13, { 0.78, 0.68, 0.55 })
    info.line:SetPoint("TOP", info.name, "BOTTOM", 0, -3)
    info.price = Text(17, GOLD)
    info.price:SetPoint("TOP", info.line, "BOTTOM", 0, -8)
    local rule = info:CreateTexture(nil, "ARTWORK")
    rule:SetPoint("TOPLEFT", 12, -92) rule:SetPoint("TOPRIGHT", -12, -92)
    rule:SetHeight(1)
    rule:SetColorTexture(GILT[1], GILT[2], GILT[3], 0.6)
    local heading = Text(15, GOLD)
    heading:SetPoint("TOP", 0, -102)
    heading:SetText("Your cart")
    info.empty = Text(13, { 0.7, 0.6, 0.5 })
    info.empty:SetPoint("TOP", heading, "BOTTOM", 0, -8)
    info.empty:SetText("Nothing yet")
    info.lines = {}
    for i = 1, #TAB_ORDER do
        local line = CreateFrame("Button", nil, info)
        line:SetHeight(18)
        line:SetPoint("TOPLEFT", 10, -(124 + (i - 1) * 20))
        line:SetPoint("TOPRIGHT", -10, -(124 + (i - 1) * 20))
        line.name = line:CreateFontString(nil, "OVERLAY")
        line.name:SetFont(NAME_FONT, 13, "")
        line.name:SetPoint("LEFT")
        line.name:SetPoint("RIGHT", -44, 0)
        line.name:SetJustifyH("LEFT")
        line.name:SetWordWrap(false)
        line.price = line:CreateFontString(nil, "OVERLAY")
        line.price:SetFont(NAME_FONT, 13, "")
        line.price:SetPoint("RIGHT")
        line.price:SetTextColor(unpack(CREAM))
        line:SetScript("OnEnter", function(self) UI.Tooltip(self, { self.item.option.name, "Click to take it out of the cart" }) end)
        line:SetScript("OnLeave", GameTooltip_Hide)
        line:SetScript("OnClick", function(self)
            view.cart[self.item.layer.key] = nil
            view.message = nil
            Redraw()
        end)
        info.lines[i] = line
    end
    info.checkout = Pill(info, 130, "Checkout")
    info.checkout:SetPoint("BOTTOM", 0, 12)
    info.checkout:SetScript("OnClick", Checkout)
    info.message = Text(13, { 1, 0.45, 0.35 })
    info.message:SetPoint("BOTTOM", info.checkout, "TOP", 0, 8)
    info.message:SetWidth(150)
    info.points = Text(13, CREAM)
    info.points:SetPoint("BOTTOM", info.message, "TOP", 0, 6)
    info.total = Text(16, CREAM)
    info.total:SetPoint("BOTTOM", info.points, "TOP", 0, 4)
    zoom.info = info
    -- Under the picture: the knobs either side of Add to cart, the count under it.
    zoom.controls = CreateFrame("Frame", nil, zoom)
    zoom.controls:SetAllPoints()
    zoom.add = Pill(zoom.controls, 150, "Add to cart")
    zoom.add:SetPoint("TOP", zoom.frame, "BOTTOM", 0, -18)
    zoom.add:SetScript("OnClick", ToggleCart)
    local prev = Pill(zoom.controls, 36, "<")
    prev:SetPoint("RIGHT", zoom.add, "LEFT", -10, 0)
    prev:SetScript("OnClick", function() Step(0, -1) end)
    local nxt = Pill(zoom.controls, 36, ">")
    nxt:SetPoint("LEFT", zoom.add, "RIGHT", 10, 0)
    nxt:SetScript("OnClick", function() Step(0, 1) end)
    zoom.count = zoom.controls:CreateFontString(nil, "OVERLAY")
    zoom.count:SetPoint("TOP", zoom.add, "BOTTOM", 0, -6)
    zoom.count:SetFont(NAME_FONT, 13, "")
    zoom.count:SetTextColor(unpack(CREAM))
    UI.OutlineText(zoom.count, { 0, 0, 0 })
    -- Keys (caught only out of combat, as on the bounty board): Up/Down or W/S tabs, Left/Right or A/D pieces, Enter
    -- adds (or takes out), Escape goes back.
    local KEYS = { UP = { -1, 0 }, W = { -1, 0 }, DOWN = { 1, 0 }, S = { 1, 0 }, LEFT = { 0, -1 }, A = { 0, -1 }, RIGHT = { 0, 1 }, D = { 0, 1 } }
    zoom:SetScript("OnKeyDown", function(self, key)
        local move = KEYS[key]
        local handled = move ~= nil or key == "ESCAPE" or key == "ENTER"
        if not InCombatLockdown() then self:SetPropagateKeyboardInput(not handled) end
        if key == "ESCAPE" then Zoom(false)
        elseif key == "ENTER" then ToggleCart()
        elseif move then Step(move[1], move[2]) end
    end)
    -- Opening and closing: the curtains and the valance slide, the dark and the picture fade.
    zoom:SetScript("OnUpdate", function(self, elapsed)
        if self.goal == nil then return end
        local step = elapsed / OPEN_TIME
        self.t = math.max(0, math.min(1, (self.t or 0) + (self.goal and step or -step)))
        PlaceZoom()
        if self.t == (self.goal and 1 or 0) then
            if not self.goal then self:Hide() end
            self.goal = nil
        end
    end)
    room.zoom = zoom
end

local function Layout()
    local sx, sy = Scale()
    if not sx then return end
    local easel = room.easel
    local eh = EASEL.height * sy
    local ew = eh * easel.box.w / easel.box.h
    easel:ClearAllPoints()
    easel:SetPoint("BOTTOM", room, "BOTTOMLEFT", EASEL.x * sx - BLEED, (SCENE_H - EASEL.bottom) * sy - BLEED)
    easel:SetSize(ew, eh)
    local cv = easel.cv
    easel.blank:ClearAllPoints()
    easel.blank:SetPoint("TOPLEFT", cv.x * ew, -cv.y * eh)
    easel.blank:SetSize(cv.w * ew, cv.h * eh)
    local side = math.floor(math.max(cv.w * ew, cv.h * eh))
    easel.picture:SetSize(side, side)
    easel.picture:Dress(ns.SHOP_DISPLAY, side)
    if room.zoom:IsShown() then PlaceZoom() end
end

local function Refresh()
    Layout()
    view.tabs = nil  -- (what you own may have changed)
    Redraw()
    room.points:SetText(("You have |cffffd21a%s|r points"):format(BreakUpLargeNumbers(ns.GetPoints().balance)))
end

ns.RegisterPage({
    key = "proshop", label = "Pro Shop", section = "guild", order = 4,
    bare = true,
    create = function(parent)
        local holder = CreateFrame("Frame", nil, parent)
        holder:SetAllPoints()
        Build(holder)
        room:SetScript("OnSizeChanged", Layout)
        holder:SetScript("OnHide", function()  -- (leaving the page: back in the room next time)
            room.zoom:Hide()
            room.zoom.goal, room.zoom.t = nil, 0
            room.blur:SetAlpha(0)
            room.easel:SetAlpha(1)
            if not InCombatLockdown() then room.zoom:EnableKeyboard(false) end
        end)
        return holder
    end,
    refresh = function() Refresh() end,
})

function ns.ShowProShop() ns.OpenPage("proshop") end
