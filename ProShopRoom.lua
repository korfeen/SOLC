-- The Pro Shop's room: its own page in the sidebar (Guild: Pro Shop; SHOP in ogre mode), the whole page area.
-- The ROOM: a stand-in until the shop floor is repainted - the concept painting (Media/ProShop/Room: the steward
-- behind his counter, the shelves; tools/make-mannequin.js) with the Dream Bed's easel standing on the floor, the display
-- set painted on its canvas: the walnut mannequin (Media/ProShop/Mannequin, the moss ogre in walnut) wearing it.
-- Click the easel -> ZOOMED IN: the room dims, the picture comes forward to the middle in a gilt and burgundy border,
-- red velvet curtains slide in from the sides and a valance drops in on top (empty for now: the tabs, the piece's info
-- and the cart come next). Back or Escape -> the room. The wares and buying: ProShop.lua.

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
local EASEL = { x = 655, bottom = 574, height = 300 }  -- (its middle, the floor it stands on: by the sewing table)
local PICTURE = { x = 413, y = 255, size = 340 }  -- zoomed in: its middle and size
local CURTAIN_W, VALANCE_H = 200, 58
local OPEN_TIME = 0.55

-- What the mannequin wears when you walk in.
ns.SHOP_DISPLAY = { headwear = "shop_flat_cap", outfit = "shop_argyle_vest" }

local room

local function Gradient(tex, orientation, from, to)
    tex:SetColorTexture(1, 1, 1)
    tex:SetGradient(orientation, CreateColor(from[1], from[2], from[3], from[4] or 1), CreateColor(to[1], to[2], to[3], to[4] or 1))
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
-- draws it at that size (the pieces are placed by it).
local function NewPicture(parent)
    local picture = CreateFrame("Frame", nil, parent)
    local backdrop = picture:CreateTexture(nil, "BACKGROUND")
    backdrop:SetAllPoints()
    Gradient(backdrop, "VERTICAL", { 0.16, 0.05, 0.04 }, { 0.42, 0.17, 0.12 })
    picture.canvas = CreateFrame("Frame", nil, picture)
    picture.canvas:SetPoint("CENTER")
    picture.body = picture.canvas:CreateTexture(nil, "ARTWORK", nil, -4)  -- (the skin's sublevel: Minting.lua)
    picture.body:SetAllPoints()
    picture.body:SetTexture(MEDIA .. "Mannequin")
    picture.masks = {}
    -- The pieces drawn as a picture with no skin (ns.RenderMint), the walnut body in the skin's place under them, cut
    -- where the pieces hide the body (their masks, as RenderMint puts them on a skin).
    function picture:Dress(traits, size)
        if self.traits == traits and self.size == size then return end
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
        self.traits, self.size = traits, size
    end
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

-- The zoomed view at its point in the opening (zoom.t, 0 closed .. 1 open, eased).
local function PlaceZoom()
    local zoom = room.zoom
    local w, h = room:GetSize()
    if w == 0 or h == 0 then return end
    local sx, sy = w / SCENE_W, h / SCENE_H
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
    local size = math.floor(PICTURE.size * math.min(sx, sy))
    zoom.frame:ClearAllPoints()
    zoom.frame:SetPoint("CENTER", room, "TOPLEFT", PICTURE.x * sx, -PICTURE.y * sy)
    zoom.frame:SetSize(size, size)
    zoom.frame:SetAlpha(math.max(0, (zoom.t or 0) * 2 - 1))  -- (comes in once the curtains are half way)
    zoom.picture:Dress(ns.SHOP_DISPLAY, size)
    zoom.back:ClearAllPoints()
    zoom.back:SetPoint("BOTTOM", room, "BOTTOM", 0, 14)
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

local function Build(holder)
    room = CreateFrame("Frame", nil, holder)
    room:SetAllPoints()
    room.scene = room:CreateTexture(nil, "BACKGROUND")
    room.scene:SetAllPoints()
    room.scene:SetTexture(MEDIA .. "Room")
    room.scene:SetTexCoord(0, SCENE_W / 1024, 0, SCENE_H / 1024)

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
    room.cart = Pill(room, 110, "Cart (0)")
    room.cart:SetPoint("BOTTOMRIGHT", -14, 12)
    room.cart:HookScript("OnEnter", function(self) UI.Tooltip(self, { "Your cart", "Empty. Try something on first." }) end)
    room.points = room:CreateFontString(nil, "OVERLAY")
    room.points:SetPoint("BOTTOMRIGHT", room.cart, "TOPRIGHT", 0, 5)
    room.points:SetFont(NAME_FONT, 14, "")
    room.points:SetTextColor(unpack(CREAM))
    UI.OutlineText(room.points, { 0, 0, 0 })

    -- Zoomed in: over the room (which takes no clicks while it's up).
    local zoom = CreateFrame("Frame", nil, room)
    zoom:SetAllPoints()
    zoom:SetFrameLevel(room:GetFrameLevel() + 20)
    zoom:EnableMouse(true)
    zoom:Hide()
    zoom.dim = zoom:CreateTexture(nil, "BACKGROUND")
    zoom.dim:SetAllPoints()
    zoom.dim:SetColorTexture(0, 0, 0, 0.6)
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
    -- Escape goes back (caught only out of combat, as on the bounty board).
    zoom:SetScript("OnKeyDown", function(self, key)
        local escape = key == "ESCAPE"
        if not InCombatLockdown() then self:SetPropagateKeyboardInput(not escape) end
        if escape then Zoom(false) end
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
    local w, h = room:GetSize()
    if w == 0 or h == 0 then return end
    local sx, sy = w / SCENE_W, h / SCENE_H
    local easel = room.easel
    local eh = EASEL.height * sy
    local ew = eh * easel.box.w / easel.box.h
    easel:ClearAllPoints()
    easel:SetPoint("BOTTOM", room, "BOTTOMLEFT", EASEL.x * sx, (SCENE_H - EASEL.bottom) * sy)
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
            if not InCombatLockdown() then room.zoom:EnableKeyboard(false) end
        end)
        return holder
    end,
    refresh = function() Refresh() end,
})

function ns.ShowProShop() ns.OpenPage("proshop") end
