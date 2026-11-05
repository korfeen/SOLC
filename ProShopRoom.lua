-- The Pro Shop's room: its own page in the sidebar (Guild: Pro Shop; SHOP in ogre mode), the whole page area.
-- (2026-11-01: the painting repainted - wallpaper rolls and borders, no painted steward, the sewing corner cleared for the
-- easel: tools/gen-proshop-room.js; the steward is one of our ogres now, STEWARD.)
-- The ROOM: a stand-in until the shop floor is repainted - the concept painting (Media/ProShop/Room: the steward
-- behind his counter, the shelves; tools/make-mannequin.js) with the Dream Bed's easel standing on the floor, the display
-- set painted on its canvas: the walnut mannequin (Media/ProShop/Mannequin, the moss ogre in walnut) wearing it, with
-- today's special on (ProShop.lua ns.ShopSpecial: its plaque under the canvas; clicking the easel opens on it).
-- Click the easel -> ZOOMED IN: the room blurs and dims (it crossfades to a pre-blurred twin, Media/ProShop/Room-blur),
-- the easel's picture comes forward to the middle in a gilt and burgundy border, red velvet curtains slide in from the
-- sides and a valance drops in on top. The left curtain: a brass plaque per layer in stock, in the mockup's words and
-- groups (WEAR: Clothes, Headwear, Accessory; you walk in on Clothes); the right: the piece's name, rarity, price (or "In
-- your wardrobe") and your cart (a piece a layer, the total, your points, Checkout). Under the picture: knobs either side of Add to cart and a count. The mannequin wears the display
-- set, the cart over it, the piece looked at over that (headwear zoomed further in). Keys: Up/Down tabs,
-- Left/Right pieces, Enter adds, Back or Escape -> the room. CHECKOUT (the curtains' button, the floor cart, or the
-- painting's steward): the till, ProShopTill.lua, the view panned in on him. The wares and buying: ProShop.lua.

local _, ns = ...
local UI = ns.UI
if not UI then return end

local MEDIA = "Interface\\AddOns\\SOLC\\Media\\ProShop\\"
local EASEL_ART = "Interface\\AddOns\\SOLC\\Media\\DreamBed\\easel"
local NAME_FONT = "Interface\\AddOns\\SOLC\\Media\\Fonts\\GermaniaOne-Regular.ttf"
local CREAM, GILT = { 0.96, 0.9, 0.78 }, { 0.79, 0.63, 0.29 }
local BURGUNDY = { 0.3, 0.06, 0.09 }

-- The room's painting is 827 x 584 (the page's size): everything is placed in its pixels and scaled to the page.
local SCENE_W, SCENE_H = 827, 584
local BLEED = 14  -- (the painting, and the zoomed view, run this far under the wooden frame on every side)
local EASEL = { x = 680, bottom = 548, height = 370 }  -- (its middle, where its feet stand: by the sewing table)
local PICTURE = { x = 413, y = 260, size = 340 }  -- zoomed in: its middle and size
-- The steward: one of our ogres (his whole look comes with the Pro Shop spending deeds, Achievements.lua), standing
-- behind the counter where the painting has none: his picture (no background) this big, its middle x and its top, in
-- painting pixels. The counter and till are drawn over him (Media/ProShop/RoomFront, tools/make-mannequin.js).
local STEWARD = { x = 409, top = 48, size = 290,
    traits = { skin = "club_sage", eyes = "snooty_eyes", expression = "snooty_sneer", outfit = "shop_steward_vest",
        headwear = "shop_steward_boater" } }
local CURTAIN_W, VALANCE_H = 200, 58
local POST_REACH = 18  -- (how far the window's posts reach over the page's sides)
local OPEN_TIME = 0.55
local ZOOM_TIME, CLOSE_ZOOM = 0.4, 1.92  -- (switching to a head layer's tab: how long the zoom takes, how far in)

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
    picture.backdrop = backdrop
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

-- The dressing (zoomed in): the layers the shop stocks as tabs, the piece looked at on each, the cart (one piece a
-- layer; kept while you're logged in).
-- (the mockup's words and groups, but Clothes for the outfit layer; you walk in on Clothes, so not zoomed in)
local TAB_ORDER = { "skin", "eyes", "expression", "outfit", "headwear", "accessory", "background", "wallpaper", "frame" }
local TAB_LABELS = { skin = "Skin", eyes = "Eyes", expression = "Mouth", outfit = "Clothes", headwear = "Headwear", accessory = "Accessory",
    background = "Background", wallpaper = "Wallpaper", frame = "Frame" }
local TAB_GROUPS = { skin = "OGRE", eyes = "OGRE", expression = "OGRE", outfit = "WEAR", headwear = "WEAR", accessory = "WEAR",
    background = "PICTURE", wallpaper = "PORTRAIT", frame = "PORTRAIT" }
-- (the PORTRAIT tabs: your own ogre shown, framed, your wallpaper behind it - not the mannequin)
local PORTRAIT_TABS = { wallpaper = true, frame = true }
local PORTRAIT_W = 410  -- (the framed portrait's width, page pixels: between the panels, by the curtains)
-- Shortcuts in the painting (its pixels): click them to open the try-on on that tab (no label: the user disliked them).
local SHORTCUTS = {
    { tab = "wallpaper", label = "Wallpapers", x0 = 8, y0 = 205, x1 = 200, y1 = 480 },    -- (the roll shelves, left)
    { tab = "wallpaper", label = "Wallpapers", x0 = 485, y0 = 30, x1 = 712, y1 = 272 },   -- (the rolls and borders, right wall)
    { tab = "frame", label = "Frames", x0 = 25, y0 = 12, x1 = 250, y1 = 190 },            -- (the empty gold frames)
}
local PORTRAIT_DY = 14  -- (and how far lower than the mannequin's picture it sits)
local FIRST_TAB = "outfit"
local CLOSE_LAYERS = { headwear = true, eyes = true, expression = true }
local CART_LINES = 5  -- (the cart's lines shown; one piece a layer, so 3 for now)
local view = { look = {}, cart = {} }  -- tab: the open one's index; look[layer key] = its stock's index; cart[layer key] = a stock item

-- The mockup's layout, in page pixels (827 x 584): the panels on the curtains (moved in a little, clear of the posts),
-- what's in them, the buttons under the picture.
local L = {
    panel = { x = 18, y = 78, w = 178, h = 428 },  -- (the left one; the right one mirrored)
    plaques = { x = 15, y = 10, w = 148, h = 25, gap = 4 },  -- inside the left panel
    info = { x = 14, y = 16, w = 150 },  -- inside the right panel; the cart under it at cartY
    cartY = 212,
    add = { x = 413, y = 538, w = 110, h = 38 }, knobs = { 334, 492 }, count = 568,  -- (middles)
    back = { x = 21, y = 14, w = 130, h = 28 },  -- (top-left)
}

-- The tabs: { key, label, items (stock items, cheapest first) }, for the layers with something in stock.
local function Tabs()
    if view.tabs then return view.tabs end
    local byLayer = {}
    local stock = ns.ShopStock()
    for _, item in ipairs(ns.ShopExtraStock and ns.ShopExtraStock() or {}) do stock[#stock + 1] = item end
    for _, item in ipairs(stock) do
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
    if not view.tab then  -- (walking in: Clothes)
        for i, tab in ipairs(tabs) do if tab.key == FIRST_TAB then view.tab = i end end
    end
    view.tab = math.min(view.tab or 1, math.max(1, #tabs))
    return tabs
end

-- The piece looked at, its tab and its place in it.
local function Looked()
    local tab = Tabs()[view.tab]
    if not tab then return end
    local index = view.look[tab.key] or 1
    return tab.items[index], tab, index
end

-- The display: the display set with today's special on (ProShop.lua ns.ShopSpecial), as the easel shows it.
local function DisplayTraits()
    local traits = {}
    for key, id in pairs(ns.SHOP_DISPLAY) do traits[key] = id end
    local special = ns.ShopSpecial and ns.ShopSpecial()
    local layer, id = tostring(special or ""):match("^(%w+):(.+)$")
    if layer then traits[layer] = id end
    return traits
end

-- What the mannequin wears: the display, the cart over it, the piece looked at over that.
local function ShownTraits()
    local traits = DisplayTraits()
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

-- Puts a region's middle at a spot in page pixels (scaled like the room).
local function AtPage(region, x, y, sx, sy)
    region:ClearAllPoints()
    region:SetPoint("CENTER", room, "TOPLEFT", x * sx - BLEED, BLEED - y * sy)
end

-- The zoomed view at its point in the opening (zoom.t, 0 closed .. 1 open, eased).
local function PlaceZoom()
    local zoom = room.zoom
    local sx, sy = Scale()
    if not sx then return end
    local t = 1 - (1 - (zoom.t or 0)) ^ 3
    local cw = CURTAIN_W * sx + BLEED  -- (from the zoomed view's edge, under the post, to the mock's 200 px in)
    zoom.left:ClearAllPoints()
    zoom.left:SetPoint("TOPLEFT", -cw * (1 - t), 0) zoom.left:SetPoint("BOTTOMLEFT", -cw * (1 - t), 0)
    zoom.left:SetWidth(cw)
    zoom.right:ClearAllPoints()
    zoom.right:SetPoint("TOPRIGHT", cw * (1 - t), 0) zoom.right:SetPoint("BOTTOMRIGHT", cw * (1 - t), 0)
    zoom.right:SetWidth(cw)
    zoom.left:Layout(cw) zoom.right:Layout(cw)
    local vh = VALANCE_H * sy + BLEED
    zoom.valance:ClearAllPoints()
    zoom.valance:SetPoint("TOPLEFT", 0, (vh + 30) * (1 - t)) zoom.valance:SetPoint("TOPRIGHT", 0, (vh + 30) * (1 - t))
    zoom.valance:SetHeight(vh)
    zoom.valance:Layout(zoom:GetWidth(), vh)
    zoom.dim:SetAlpha(t)
    zoom.vignette:SetAlpha(t)
    room.blur:SetAlpha(t)
    room.easel:SetAlpha(1 - t)  -- (its picture comes forward; the easel goes with the sharp room)
    room.stewardArt:SetAlpha(1 - t)  -- (he and the counter in front of him go with it too)
    room.front:SetAlpha(1 - t)
    local size = math.floor(PICTURE.size * math.min(sx, sy))
    zoom.frame:SetSize(size, size)
    local late = math.max(0, (zoom.t or 0) * 2 - 1)  -- (the picture and the buttons come in once the curtains are half way)
    zoom.frame:SetAlpha(late)
    -- The PORTRAIT tabs: the same mannequin picture in the frame looked at (or carted, or yours), the wallpaper likewise
    -- filling the view behind the curtains round the frame (the velvet stays behind the ogre), the gilt box gone - eased in and out (zoom.mix, 0 .. 1: zoom.mixer),
    -- the picture scaled down so it fits between the panels with its frame round it; a new one pops in.
    local looked, tab = Looked()
    local portrait = tab and PORTRAIT_TABS[tab.key] and true or false
    zoom.mixGoal = portrait and 1 or 0
    local e = zoom.mix or 0
    e = e * e * (3 - 2 * e)
    local function Pick(key, own)
        if tab and tab.key == key and looked then return looked.option.id end
        return view.cart[key] and view.cart[key].option.id or own
    end
    local paper, frameId = Pick("wallpaper", ns.GetWallpaper()), Pick("frame", (KillTrackerDB.card or {}).frame or "wood")
    local frame = ns.FrameById and ns.FrameById(frameId)
    if e > 0 and paper .. frameId ~= zoom.showing then
        if zoom.showing then zoom.pop = 0 end
        zoom.showing = paper .. frameId
    end
    for _, t in ipairs(zoom.box) do t:SetAlpha(1 - e) end
    zoom.paper:SetAlpha(e)
    zoom.frameArt:SetAlpha(e)
    if e > 0 then
        UI.SetWallpaper(zoom.paper, paper, zoom:GetWidth(), zoom:GetHeight(), math.floor(size * 0.55))
        if frame then  -- (its art the picture's size over its opening)
            local o = frame.inner
            local fw, fh = size / o.w, size / o.h
            zoom.frameArt.tex:SetTexture(frame.texture)
            zoom.frameArt:ClearAllPoints()
            zoom.frameArt:SetPoint("TOPLEFT", zoom.frame, "TOPLEFT", -o.x * fw, o.y * fh)
            zoom.frameArt:SetSize(fw, fh)
        end
        zoom.frameArt:SetShown(frame ~= nil)
    end
    -- (the scale: the framed picture PORTRAIT_W wide on the PORTRAIT tabs; a pop eases in from a touch smaller)
    local fit = frame and (PORTRAIT_W * math.min(sx, sy)) / (size / frame.inner.w) or 1
    local pop = zoom.pop or 1
    pop = pop * pop * (3 - 2 * pop)
    local k = (1 + (fit - 1) * e) * (1 - 0.06 * e * (1 - pop))
    zoom.frame:SetScale(k)
    zoom.frame:ClearAllPoints()  -- (a scaled frame's offsets are in its own scale)
    zoom.frame:SetPoint("CENTER", room, "TOPLEFT", (PICTURE.x * sx - BLEED) / k, (BLEED - (PICTURE.y + PORTRAIT_DY * e) * sy) / k)
    zoom.picture:Dress(ShownTraits(), size)
    zoom.picture:SetZoom(tab and CLOSE_LAYERS[tab.key] and CLOSE_ZOOM or 1, (zoom.t or 0) < 1)  -- (opening: no zoom on top)
    zoom.controls:SetAlpha(late)
    AtPage(zoom.add, L.add.x, L.add.y, sx, sy)
    AtPage(zoom.prev, L.knobs[1], L.add.y, sx, sy)
    AtPage(zoom.next, L.knobs[2], L.add.y, sx, sy)
    AtPage(zoom.count, L.add.x, L.count, sx, sy)
    zoom.back:ClearAllPoints()
    zoom.back:SetPoint("TOPLEFT", room, "TOPLEFT", L.back.x, -L.back.y)
    zoom.back:SetAlpha(late)
    local panelX, panelY = L.panel.x * sx, L.panel.y * sy + BLEED
    zoom.leftPanel:ClearAllPoints()
    zoom.leftPanel:SetPoint("TOPRIGHT", zoom.left, "TOPRIGHT", -(cw - BLEED - panelX - L.panel.w), -panelY)
    zoom.rightPanel:ClearAllPoints()
    zoom.rightPanel:SetPoint("TOPLEFT", zoom.right, "TOPLEFT", cw - BLEED - panelX - L.panel.w, -panelY)
end

local Redraw  -- (further down)

-- Zooms in on the easel (true) or back out to the room. Walking in, you start on Clothes (not zoomed in), unless
-- keepTab (sent here with pieces from EDIT: their tab).
local function Zoom(open, keepTab)
    local zoom = room.zoom
    if open then
        if not zoom:IsShown() then
            zoom.t = 0
            if not keepTab then for i, tab in ipairs(Tabs()) do if tab.key == FIRST_TAB then view.tab = i end end end
            Redraw()
        end
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
-- floor cart.
function Redraw()
    local zoom, S = room.zoom, ns.ShopUI
    local tabs = Tabs()
    PlaceZoom()
    -- (the plaques down the left panel, a small heading over each group)
    local P = L.plaques
    local y, group = P.y, nil
    for _, heading in pairs(zoom.headings) do heading:Hide() end
    for i, tab in ipairs(tabs) do
        if TAB_GROUPS[tab.key] ~= group then
            if group then y = y + 6 end
            group = TAB_GROUPS[tab.key]
            local heading = zoom.headings[group]
            if not heading then
                heading = S.Text(zoom.leftPanel, S.DISPLAY_FONT, 11, "#d9b66a")
                heading:SetText(group:gsub("(.)", "%1 "):sub(1, -2))  -- (spaced out, as the mock's letter-spacing)
                zoom.headings[group] = heading
            end
            heading:ClearAllPoints()
            heading:SetPoint("TOP", zoom.leftPanel, "TOPLEFT", P.x + P.w / 2, -y)
            heading:Show()
            y = y + 15
        end
        local plaque = zoom.plaques[i]
        plaque:ClearAllPoints()
        plaque:SetPoint("TOPLEFT", P.x, -y)
        plaque.text:SetText(tab.label)
        plaque:SetLit(i == view.tab)
        plaque:Show()
        y = y + P.h + P.gap
    end
    for i = #tabs + 1, #zoom.plaques do zoom.plaques[i]:Hide() end
    -- (the piece)
    local info = zoom.info
    local item, tab, index = Looked()
    if item then
        UI.FitText(info.name, S.DISPLAY_FONT, 21, 12, item.option.name, L.info.w)
        info.name:SetTextColor(ns.RarityRGB(item.option.rarity))
        info.line:SetText(item.option.rarity:gsub("^%l", string.upper) .. " " .. tab.label:lower())
        info.price:SetText(BreakUpLargeNumbers(item.price))
        info.price:SetPoint("TOP", info, "TOP", -(info.unit:GetStringWidth() + 4) / 2, -64)
        info.price:SetShown(not item.owned)
        info.unit:SetShown(not item.owned)
        info.owned:SetShown(item.owned)
        info.special:SetText(("Today's special, was %s"):format(BreakUpLargeNumbers(item.full or item.price)))
        info.special:SetShown(item.special and not item.owned)
        zoom.count:SetText(("%d / %d"):format(index, #tab.items))
        zoom.add.text:SetText(item.owned and "Yours already" or view.cart[tab.key] == item and "Take it out" or "Add to cart")
        zoom.add:SetEnabled(not item.owned)
    end
    -- (the cart)
    local items, total = CartItems()
    for i, line in ipairs(info.lines) do
        local inCart = items[i]
        if inCart then
            UI.FitText(line.name, S.BODY_FONT, 11, 7, inCart.option.name, L.info.w - 58)
            line.price:SetText(BreakUpLargeNumbers(inCart.price))
            line.item = inCart
        end
        line:SetShown(inCart ~= nil)
    end
    info.empty:SetShown(#items == 0)
    info.cartCount:SetText(#items > 0 and ("(%d)"):format(#items) or "")
    local balance = ns.GetPoints().balance
    info.total:SetText(BreakUpLargeNumbers(total))
    info.points:SetText(BreakUpLargeNumbers(balance))
    info.short:SetText(view.message or (total > balance and ("%s points short"):format(BreakUpLargeNumbers(total - balance))) or "")
    info.checkout:SetEnabled(#items > 0 and total <= balance)
    -- (the room's floor cart: only with something in it)
    room.cart.text:SetText(("%d piece%s  ·  %s points"):format(#items, #items == 1 and "" or "s", BreakUpLargeNumbers(total)))
    room.cart:SetWidth(room.cart.text:GetStringWidth() + 26)
    room.cart:SetShown(#items > 0)
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

-- The till's camera (ProShopTill.lua): p 0 = the whole room .. 1 = on the steward behind his counter (the mock's 1.75x,
-- on x 395, y 215 of the painting, put at 413, 300), the easel moving with the painting, the corner's bits fading away.
local STEWARD_VIEW = { scale = 1.75, x = 395, y = 215, at = { 413, 300 } }  -- (his face under the bubble)
-- The painted till's display window (where the drums go), painting pixels.
local TILL_WINDOW = { x0 = 502, y0 = 237, x1 = 539, y1 = 249 }
-- Where the receipt prints out: on the till itself, out of its wooden base between its two little wooden feet.
local RECEIPT_SPOT = { x0 = 486, x1 = 551, y = 310 }
-- Puts the easel where it stands in the painting while x0..x1, y0..y1 of the painting fill the page (the whole of it,
-- or the till camera's close-up): scaled with the painting, not drawn again.
local function PlaceEasel(x0, y0, x1, y1)
    local w, h = room:GetSize()
    if w == 0 or h == 0 then return end
    local k = SCENE_W / (x1 - x0)
    local fx = (EASEL.x - x0) / (x1 - x0) * (w + 2 * BLEED) - BLEED
    local fy = (EASEL.bottom - y0) / (y1 - y0) * (h + 2 * BLEED) - BLEED
    room.easel:SetScale(k)
    room.easel:ClearAllPoints()
    room.easel:SetPoint("BOTTOM", room, "TOPLEFT", fx / k, -fy / k)  -- (a scaled frame's offsets are in its own scale)
end

-- Puts the steward where he stands in the painting while x0..x1, y0..y1 of it fill the page (as PlaceEasel): drawn once
-- at the whole room's scale (Layout), scaled with the painting.
local function PlaceSteward(x0, y0, x1, y1)
    local w, h = room:GetSize()
    if w == 0 or h == 0 or not room.stewardArt.base then return end
    local k = SCENE_W / (x1 - x0)
    local fx = (STEWARD.x - STEWARD.size / 2 - x0) / (x1 - x0) * (w + 2 * BLEED) - BLEED
    local fy = (STEWARD.top - y0) / (y1 - y0) * (h + 2 * BLEED) - BLEED
    room.stewardArt:SetScale(k)
    room.stewardArt:ClearAllPoints()
    room.stewardArt:SetPoint("TOPLEFT", room, "TOPLEFT", fx / k, -fy / k)
end

local function Camera(p)
    local v = STEWARD_VIEW
    local w, h = SCENE_W / v.scale, SCENE_H / v.scale
    local left, top = v.x - v.at[1] / v.scale, v.y - v.at[2] / v.scale
    local x0, y0 = left * p, top * p
    local x1, y1 = SCENE_W + (left + w - SCENE_W) * p, SCENE_H + (top + h - SCENE_H) * p
    room.cam = { x0, y0, x1, y1 }  -- (kept: a layout while the camera is in - the page refreshed after buying - keeps it)
    room.scene:SetTexCoord(x0 / 1024, x1 / 1024, y0 / 1024, y1 / 1024)
    room.front:SetTexCoord(x0 / 1024, x1 / 1024, y0 / 1024, y1 / 1024)
    PlaceEasel(x0, y0, x1, y1)  -- (moving with the painting, fading out: not part of checking out)
    room.easel:SetAlpha(1 - p)
    PlaceSteward(x0, y0, x1, y1)
    room.corner:SetAlpha(1 - p)
    room.steward:SetShown(p == 0)
    for _, spot in ipairs(room.shortcuts) do spot:SetShown(p == 0) end
end

-- Checkout: to the steward at the till (from the curtains, the floor cart or the steward himself).
local function Checkout()
    if room.zoom:IsShown() then Zoom(false) end
    room.till:Start((CartItems()))
end

-- The right panel's piece info and cart (the mock's .info and .chit).
local function BuildInfo(zoom, S)
    local info = CreateFrame("Frame", nil, zoom.rightPanel)
    info:SetPoint("TOPLEFT", L.info.x, -L.info.y)
    info:SetSize(L.info.w, L.panel.h - L.info.y)
    info.name = S.Text(info, S.DISPLAY_FONT, 21, "#f6e3b0")
    info.name:SetPoint("TOP", 0, 0)
    info.name:SetHeight(26)  -- (a fixed slot, no width: a long name shrinks to fit (Redraw) without moving what's under it)
    info.line = S.Text(info, S.BODY_FONT, 12, "#e8cf9a")
    info.line:SetPoint("TOP", 0, -32)
    for side = 1, 2 do  -- the rule: gilt fading out to both ends
        local half = info:CreateTexture(nil, "ARTWORK")
        half:SetSize((L.info.w - 12) / 2, 1)
        half:SetPoint(side == 1 and "TOPRIGHT" or "TOPLEFT", info, "TOP", 0, -58)
        half:SetColorTexture(1, 1, 1)
        local gilt, clear = CreateColor(0.79, 0.63, 0.29, 1), CreateColor(0.79, 0.63, 0.29, 0)
        half:SetGradient("HORIZONTAL", side == 1 and clear or gilt, side == 1 and gilt or clear)
    end
    info.price = S.Text(info, S.DISPLAY_FONT, 24, "#f2c14e")
    info.unit = S.Text(info, S.DISPLAY_FONT, 13, "#e8cf9a")
    info.unit:SetPoint("BOTTOMLEFT", info.price, "BOTTOMRIGHT", 4, 3)
    info.unit:SetText("points")
    info.owned = S.Text(info, S.DISPLAY_FONT, 15, "#9fdc8f")
    info.owned:SetPoint("TOP", 0, -72)
    info.owned:SetText("In your wardrobe")
    info.special = S.Text(info, S.BODY_FONT, 11, "#9fdc8f")
    info.special:SetPoint("TOP", 0, -94)
    -- The cart.
    local y = L.cartY - L.info.y
    local top = info:CreateTexture(nil, "ARTWORK")
    top:SetPoint("TOPLEFT", 0, -y) top:SetPoint("TOPRIGHT", 0, -y)
    top:SetHeight(1)
    top:SetColorTexture(0.79, 0.63, 0.29, 0.55)
    local heading = S.Text(info, S.DISPLAY_FONT, 15, "#f6d98a")
    heading:SetPoint("TOPLEFT", 0, -(y + 8))
    heading:SetText("Your cart")
    info.cartCount = S.Text(info, S.BODY_FONT, 10, "#d9c296")
    info.cartCount:SetPoint("TOPRIGHT", 0, -(y + 11))
    info.empty = S.Text(info, S.BODY_FONT, 11, "#9d7f6a")
    info.empty:SetPoint("TOPLEFT", 0, -(y + 30))
    info.empty:SetText("Nothing yet")
    info.lines = {}
    for i = 1, CART_LINES do
        local line = CreateFrame("Button", nil, info)
        line:SetHeight(17)
        line:SetPoint("TOPLEFT", 0, -(y + 28 + (i - 1) * 17))
        line:SetPoint("TOPRIGHT", 0, -(y + 28 + (i - 1) * 17))
        line.name = S.Text(line, S.BODY_FONT, 11, "#f1dfb5")
        line.name:SetPoint("LEFT")  -- (no right edge: a long name shrinks to fit, Redraw)
        line.price = S.Text(line, S.BODY_FONT, 11, "#f1dfb5")
        line.price:SetPoint("RIGHT", -16, 0)
        local x = S.Text(line, S.BODY_FONT, 12, "#f0a0a0")
        x:SetPoint("RIGHT", 0, 0)
        x:SetText("x")
        line:SetScript("OnEnter", function(self) UI.Tooltip(self, { self.item.option.name, "Click to take it out of the cart" }) end)
        line:SetScript("OnLeave", GameTooltip_Hide)
        line:SetScript("OnClick", function(self)
            view.cart[self.item.layer.key] = nil
            view.message = nil
            Redraw()
        end)
        info.lines[i] = line
    end
    local ty = y + 28 + CART_LINES * 17 + 4
    local rule = info:CreateTexture(nil, "ARTWORK")
    rule:SetPoint("TOPLEFT", 0, -ty) rule:SetPoint("TOPRIGHT", 0, -ty)
    rule:SetHeight(1)
    rule:SetColorTexture(0.79, 0.63, 0.29, 0.55)
    local totalLabel = S.Text(info, S.DISPLAY_FONT, 13, "#f6d98a")
    totalLabel:SetPoint("TOPLEFT", 0, -(ty + 4))
    totalLabel:SetText("Total")
    info.total = S.Text(info, S.DISPLAY_FONT, 13, "#f6d98a")
    info.total:SetPoint("TOPRIGHT", 0, -(ty + 4))
    local pointsLabel = S.Text(info, S.BODY_FONT, 11, "#f1dfb5")
    pointsLabel:SetPoint("TOPLEFT", 0, -(ty + 22))
    pointsLabel:SetText("Your points")
    info.points = S.Text(info, S.BODY_FONT, 11, "#f1dfb5")
    info.points:SetPoint("TOPRIGHT", 0, -(ty + 22))
    info.short = S.Text(info, S.BODY_FONT, 11, "#ff9b8a")
    info.short:SetPoint("TOPLEFT", 0, -(ty + 38))
    info.short:SetPoint("TOPRIGHT", 0, -(ty + 38))
    info.short:SetJustifyH("LEFT")
    info.checkout = S.Button(info, L.info.w, 30, "Checkout", 14)
    info.checkout:SetPoint("TOP", 0, -(ty + 56))
    info.checkout:SetScript("OnClick", Checkout)
    zoom.info = info
end

local function Build(holder)
    local S = ns.ShopUI
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
    -- (inside a frame the painting's size that clips: scaled up by the till camera, it never shows past the painting)
    room.inPainting = CreateFrame("Frame", nil, room)
    room.inPainting:SetAllPoints(room.scene)
    room.inPainting:SetClipsChildren(true)
    -- The steward (STEWARD), then the counter and till over him, then the easel.
    room.stewardArt = CreateFrame("Frame", nil, room.inPainting)
    room.stewardArt:SetFrameLevel(room.inPainting:GetFrameLevel() + 1)
    room.stewardArt.canvas = CreateFrame("Frame", nil, room.stewardArt)
    room.stewardArt.canvas:SetPoint("TOPLEFT")
    room.front = CreateFrame("Frame", nil, room.inPainting)
    room.front:SetFrameLevel(room.inPainting:GetFrameLevel() + 2)
    room.front:SetAllPoints(room.scene)
    room.front.art = room.front:CreateTexture(nil, "ARTWORK")
    room.front.art:SetAllPoints()
    room.front.art:SetTexture(MEDIA .. "RoomFront")
    room.front.art:SetTexCoord(0, SCENE_W / 1024, 0, SCENE_H / 1024)
    function room.front:SetTexCoord(...) self.art:SetTexCoord(...) end
    local easel = CreateFrame("Button", nil, room.inPainting)
    easel:SetFrameLevel(room.inPainting:GetFrameLevel() + 3)
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
    -- (no brass label: the easel just lights up while pointed at)
    easel:SetScript("OnEnter", function(self) self.board:SetVertexColor(1, 1, 1) end)
    easel:SetScript("OnLeave", function(self) self.board:SetVertexColor(0.88, 0.86, 0.82) end)
    -- Today's special: a brass plaque hung under the canvas; clicking the easel opens the curtains on it.
    easel.special = S.Plaque(easel, 176, 24, 12)
    easel.special:SetPoint("TOP", easel.blank, "BOTTOM", 0, -3)
    easel.special.text:SetText(("Today's special  ·  %d%% off"):format(ns.SHOP_SPECIAL_OFF * 100))
    easel.special:EnableMouse(false)
    easel.special:SetFrameLevel(easel.blank:GetFrameLevel() + 5)
    easel:SetScript("OnClick", function()
        local special = ns.ShopSpecial and ns.ShopSpecial()
        local keep = false
        for t, tab in ipairs(Tabs()) do
            for i, item in ipairs(tab.items) do
                if item.key == special then view.tab, view.look[tab.key], keep = t, i, true end
            end
        end
        Zoom(true, keep)
    end)
    room.easel = easel

    -- Over the easel: your points, and the floor cart (the mock's gold plaque, top right, while the cart has something).
    room.corner = CreateFrame("Frame", nil, room)
    room.corner:SetAllPoints()
    room.corner:SetFrameLevel(easel:GetFrameLevel() + 5)
    room.cart = S.Plaque(room.corner, 160, 30, 14)
    room.cart:SetPoint("TOPRIGHT", -(POST_REACH + 6), -12)
    room.cart:HookScript("OnEnter", function(self)
        local items, total = CartItems()
        local lines = { "Your cart" }
        for _, item in ipairs(items) do lines[#lines + 1] = item.option.name .. " - " .. BreakUpLargeNumbers(item.price) end
        lines[#lines + 1] = ("Total: %s points"):format(BreakUpLargeNumbers(total))
        UI.Tooltip(self, lines)
    end)
    room.cart:HookScript("OnLeave", GameTooltip_Hide)
    room.cart:SetScript("OnClick", Checkout)
    -- The steward behind his counter (the painting's): click him to check out; a little brass "Checkout" over him.
    room.steward = CreateFrame("Button", nil, room)
    room.steward.hint = S.Plaque(room.steward, 90, 22, 12)
    room.steward.hint:SetPoint("BOTTOM", room.steward, "TOP", 0, 2)
    room.steward.hint.text:SetText("Checkout")
    room.steward.hint:EnableMouse(false)
    room.steward.hint:Hide()
    room.steward:SetScript("OnEnter", function(self) self.hint:SetShown(#(CartItems()) > 0) end)  -- (only with something to pay for)
    room.steward:SetScript("OnLeave", function(self) self.hint:Hide() end)
    room.steward:SetScript("OnClick", Checkout)
    -- The shortcuts (SHORTCUTS): the try-on opened on their tab.
    room.shortcuts = {}
    for i, spec in ipairs(SHORTCUTS) do
        local spot = CreateFrame("Button", nil, room)
        spot.spec = spec
        spot:SetScript("OnClick", function(self)
            UI.ClickSound()
            for t, tab in ipairs(Tabs()) do if tab.key == self.spec.tab then view.tab = t end end
            view.message = nil
            Zoom(true, true)
        end)
        room.shortcuts[i] = spot
    end
    room.points = room.corner:CreateFontString(nil, "OVERLAY")
    room.points:SetPoint("BOTTOMRIGHT", -(POST_REACH + 4), 14)
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
    zoom:SetClipsChildren(true)  -- (the curtains wait outside it, sliding in and out: never drawn past the beams)
    zoom:Hide()
    zoom.dim = zoom:CreateTexture(nil, "BACKGROUND")  -- (the mock's room: blurred, darker, a vignette)
    zoom.dim:SetAllPoints()
    zoom.dim:SetColorTexture(0, 0, 0, 0.45)
    zoom.vignette = zoom:CreateTexture(nil, "BACKGROUND", nil, 1)
    zoom.vignette:SetAllPoints()
    zoom.vignette:SetTexture(MEDIA .. "UI\\Vignette")
    zoom.frame = CreateFrame("Frame", nil, zoom)  -- the border: a shadow, gilt, burgundy, then the picture
    local shadow = zoom.frame:CreateTexture(nil, "BACKGROUND", nil, -2)
    zoom.box = { shadow }  -- (the box round the mannequin: gone on the PORTRAIT tabs)
    shadow:SetPoint("TOPLEFT", -2, -6) shadow:SetPoint("BOTTOMRIGHT", 6, -10)
    shadow:SetColorTexture(0, 0, 0, 0.55)
    local gilt = zoom.frame:CreateTexture(nil, "BACKGROUND", nil, -1)
    gilt:SetPoint("TOPLEFT", -4, 4) gilt:SetPoint("BOTTOMRIGHT", 4, -4)
    gilt:SetColorTexture(unpack(GILT))
    local burgundy = zoom.frame:CreateTexture(nil, "BACKGROUND")
    burgundy:SetPoint("TOPLEFT", -2, 2) burgundy:SetPoint("BOTTOMRIGHT", 2, -2)
    burgundy:SetColorTexture(unpack(BURGUNDY))
    zoom.box[2], zoom.box[3] = gilt, burgundy
    zoom.picture = NewPicture(zoom.frame)
    zoom.picture:SetAllPoints()
    zoom.picture:SetClipsChildren(true)
    -- (the PORTRAIT tabs: the wallpaper filling the view, under the curtains; the frame's art over the picture)
    zoom.paper = zoom:CreateTexture(nil, "BACKGROUND", nil, 2)
    zoom.paper:SetAllPoints()
    zoom.paper:SetAlpha(0)
    zoom.frameArt = CreateFrame("Frame", nil, zoom.frame)
    zoom.frameArt:SetFrameLevel(zoom.picture:GetFrameLevel() + 10)
    zoom.frameArt.tex = zoom.frameArt:CreateTexture(nil, "OVERLAY")
    zoom.frameArt.tex:SetAllPoints()
    zoom.frameArt:SetAlpha(0)
    -- (the easing: the mix towards its goal over ZOOM_TIME, a new one's pop over two thirds of that)
    zoom.mixer = CreateFrame("Frame", nil, zoom)
    zoom.mixer:SetScript("OnUpdate", function(_, elapsed)
        local goal, moved = zoom.mixGoal or 0, false
        local mix = zoom.mix or 0
        if mix ~= goal then
            local step = elapsed / ZOOM_TIME
            zoom.mix = goal > mix and math.min(goal, mix + step) or math.max(goal, mix - step)
            moved = true
        end
        local pop = zoom.pop
        if pop and pop < 1 then zoom.pop = math.min(1, pop + elapsed / (ZOOM_TIME * 0.66)) moved = true end
        if moved then PlaceZoom() end
    end)
    zoom.left, zoom.right = S.Curtain(zoom, "left"), S.Curtain(zoom, "right")
    zoom.valance = S.Valance(zoom)
    zoom.valance:SetFrameLevel(zoom.left:GetFrameLevel() + 3)
    zoom.leftPanel, zoom.rightPanel = S.Panel(zoom.left), S.Panel(zoom.right)
    zoom.leftPanel:SetSize(L.panel.w, L.panel.h)
    zoom.rightPanel:SetSize(L.panel.w, L.panel.h)
    zoom.back = S.Button(zoom, L.back.w, L.back.h, "Back to the shop", 13)
    zoom.back:SetFrameLevel(zoom.valance:GetFrameLevel() + 2)
    zoom.back:SetScript("OnClick", function() Zoom(false) end)
    -- The left panel: a brass plaque a tab (velvet: the one open).
    zoom.plaques, zoom.headings = {}, {}
    for i = 1, #TAB_ORDER do
        local plaque = S.Plaque(zoom.leftPanel, L.plaques.w, L.plaques.h, 13)
        plaque:SetScript("OnClick", function() Step(i - view.tab, 0) end)
        zoom.plaques[i] = plaque
    end
    BuildInfo(zoom, S)
    -- Under the picture: the knobs either side of Add to cart, the count under it.
    zoom.controls = CreateFrame("Frame", nil, zoom)
    zoom.controls:SetAllPoints()
    zoom.add = S.Button(zoom.controls, L.add.w, L.add.h, "Add to cart", 15)
    zoom.add:SetScript("OnClick", ToggleCart)
    zoom.prev = S.Knob(zoom.controls, -1)
    zoom.prev:SetScript("OnClick", function() Step(0, -1) end)
    zoom.next = S.Knob(zoom.controls, 1)
    zoom.next:SetScript("OnClick", function() Step(0, 1) end)
    zoom.count = S.Text(zoom.controls, S.DISPLAY_FONT, 13, "#f1dfb5")
    -- Keys (let go of in combat: UI.CombatSafeKeys): Up/Down tabs, Left/Right pieces, Enter adds (or takes out),
    -- Escape goes back. (Not W/A/S/D: those stay yours to walk with.)
    local KEYS = { UP = { -1, 0 }, DOWN = { 1, 0 }, LEFT = { 0, -1 }, RIGHT = { 0, 1 } }
    zoom:SetScript("OnKeyDown", function(self, key)
        local move = KEYS[key]
        local handled = move ~= nil or key == "ESCAPE" or key == "ENTER"
        if not InCombatLockdown() then self:SetPropagateKeyboardInput(not handled) end
        if key == "ESCAPE" then Zoom(false)
        elseif key == "ENTER" then ToggleCart()
        elseif move then Step(move[1], move[2]) end
    end)
    ns.UI.CombatSafeKeys(zoom)
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
    -- The till: pays for the cart (it empties, what you own changes), back in the room after.
    room.till = S.Till(room, {
        camera = Camera,
        receipt = function()  -- (where the receipt prints out on the page, where the camera is now: x, y, width)
            local w, h = room:GetSize()
            local x0, y0, x1, y1 = unpack(room.cam or { 0, 0, SCENE_W, SCENE_H })
            local fx = function(x) return (x - x0) / (x1 - x0) * (w + 2 * BLEED) - BLEED end
            local t = RECEIPT_SPOT
            return fx(t.x0), (t.y - y0) / (y1 - y0) * (h + 2 * BLEED) - BLEED, fx(t.x1) - fx(t.x0)
        end,
        display = function()  -- (the till's window on the page, where the camera is now)
            local w, h = room:GetSize()
            local x0, y0, x1, y1 = unpack(room.cam or { 0, 0, SCENE_W, SCENE_H })
            local fx = function(x) return (x - x0) / (x1 - x0) * (w + 2 * BLEED) - BLEED end
            local fy = function(y) return (y - y0) / (y1 - y0) * (h + 2 * BLEED) - BLEED end
            local t = TILL_WINDOW
            return fx(t.x0), fy(t.y0), fx(t.x1) - fx(t.x0), fy(t.y1) - fy(t.y0)
        end,
        buy = function(keys)
            local ok, result = ns.ShopBuy(keys)
            if ok then
                wipe(view.cart)
                view.tabs, view.message = nil, nil
            end
            return ok, result
        end,
        done = function()
            Redraw()
            room.points:SetText(("You have |cffffd21a%s|r points"):format(BreakUpLargeNumbers(ns.GetPoints().balance)))
        end,
    })
end

local function Layout()
    local sx, sy = Scale()
    if not sx then return end
    local easel = room.easel
    local eh = EASEL.height * sy
    local ew = eh * easel.box.w / easel.box.h
    easel:SetSize(ew, eh)
    PlaceEasel(unpack(room.cam or { 0, 0, SCENE_W, SCENE_H }))
    local cv = easel.cv
    easel.blank:ClearAllPoints()
    easel.blank:SetPoint("TOPLEFT", cv.x * ew, -cv.y * eh)
    easel.blank:SetSize(cv.w * ew, cv.h * eh)
    local side = math.floor(math.max(cv.w * ew, cv.h * eh))
    easel.picture:SetSize(side, side)
    easel.picture:Dress(DisplayTraits(), side)
    -- The steward: drawn at the whole room's scale (a new size only when the page's changes), placed by the camera.
    local base = math.floor(STEWARD.size * sx + 0.5)
    if room.stewardArt.base ~= base then
        room.stewardArt.base = base
        room.stewardArt:SetSize(base, base)
        room.stewardArt.canvas:SetSize(base, base)
        ns.RenderMint(room.stewardArt.canvas, STEWARD.traits)
    end
    PlaceSteward(unpack(room.cam or { 0, 0, SCENE_W, SCENE_H }))
    room.steward:ClearAllPoints()  -- (the steward's hotspot: x 300-490, y 92-318)
    room.steward:SetPoint("TOPLEFT", room, "TOPLEFT", 300 * sx - BLEED, BLEED - 92 * sy)
    room.steward:SetSize(190 * sx, 226 * sy)
    for _, spot in ipairs(room.shortcuts) do
        local c = spot.spec
        spot:ClearAllPoints()
        spot:SetPoint("TOPLEFT", room, "TOPLEFT", c.x0 * sx - BLEED, BLEED - c.y0 * sy)
        spot:SetSize((c.x1 - c.x0) * sx, (c.y1 - c.y0) * sy)
    end
    if room.zoom:IsShown() then PlaceZoom() end
end

-- Pieces sent here from EDIT (ns.ShowProShopWith): put in the cart, their tab open, the curtains in.
local pending
local function TakePending()
    local keys = pending
    pending = nil
    if not keys then return end
    view.tabs = nil
    local first
    for _, key in ipairs(keys) do
        for t, tab in ipairs(Tabs()) do
            for i, item in ipairs(tab.items) do
                if item.key == key and not item.owned then
                    view.cart[tab.key] = item
                    if not first then first, view.tab, view.look[tab.key] = true, t, i end
                end
            end
        end
    end
    room.zoom:Hide()  -- (fresh curtains)
    Zoom(true, first)
    Redraw()
end

local function Refresh()
    Layout()
    view.tabs = nil  -- (what you own may have changed)
    Redraw()
    TakePending()
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
            room.stewardArt:SetAlpha(1)
            room.front:SetAlpha(1)
            room.till:Reset()
            if not InCombatLockdown() then room.zoom:EnableKeyboard(false) end
        end)
        return holder
    end,
    refresh = function() Refresh() end,
})

-- Opens the shop with these pieces ("layer:id" keys) in the cart and the first one's tab open (EDIT's PRO SHOP button).
function ns.ShowProShopWith(keys)
    pending = keys
    ns.OpenPage("proshop")
    if room and room:IsVisible() and pending then TakePending() end
end
