-- The Pro Shop's dressing pieces, copied from the mockup (tools/proshop-mock/index.html; the art: tools/make-shop-ui.js,
-- Media/ProShop/UI): the velvet button (and its greyed-out look), the gold "floor cart" plaque button, a tab's brass
-- plaque (velvet while open), the round velvet knob with an arrow, a curtain's panel with its brass pin, the striped
-- velvet curtains with their curved inner corner, and the valance with its gold fringe. Used by ProShopRoom.lua.

local _, ns = ...
local UI = ns.UI
if not UI then return end

local ART = "Interface\\AddOns\\SOLC\\Media\\ProShop\\UI\\"
local DISPLAY = "Interface\\AddOns\\SOLC\\Media\\Fonts\\GermaniaOne-Regular.ttf"
local CAP = 24 / 128  -- (the plaques' and buttons' ends: this much of their art's width, the middle stretches)

local ShopUI = {}
ns.ShopUI = ShopUI
ShopUI.DISPLAY_FONT, ShopUI.BODY_FONT = DISPLAY, "Fonts\\FRIZQT__.TTF"
ShopUI.GOLD, ShopUI.GILT = { 0.95, 0.76, 0.31 }, { 0.79, 0.63, 0.29 }

-- A colour from "#rrggbb".
local function C(h) return tonumber(h:sub(2, 3), 16) / 255, tonumber(h:sub(4, 5), 16) / 255, tonumber(h:sub(6, 7), 16) / 255 end
ShopUI.C = C
local function Col(h) local r, g, b = C(h) return CreateColor(r, g, b, 1) end  -- (for gradients)

local function Gradient(tex, top, bottom)
    tex:SetColorTexture(1, 1, 1)
    tex:SetGradient("VERTICAL", CreateColor(bottom[1], bottom[2], bottom[3], bottom[4] or 1), CreateColor(top[1], top[2], top[3], top[4] or 1))
end
ShopUI.Gradient = Gradient

-- Text in the mock's way: a font, size and colour, a drop shadow under it.
function ShopUI.Text(parent, font, size, hexColor, layer)
    local text = parent:CreateFontString(nil, layer or "OVERLAY")
    text:SetFont(font, size, "")
    text:SetTextColor(C(hexColor))
    text:SetShadowOffset(0, -1)
    text:SetShadowColor(0, 0, 0, 1)
    return text
end

-- Three slices of one art on frame (its ends as wide as the art's ends at this height, the middle stretched);
-- slices:Set(name) changes the art.
local function Slices(frame, name)
    local parts = {}
    for i, coords in ipairs({ { 0, CAP }, { CAP, 1 - CAP }, { 1 - CAP, 1 } }) do
        local t = frame:CreateTexture(nil, "BACKGROUND")
        t:SetTexCoord(coords[1], coords[2], 0, 1)
        parts[i] = t
    end
    local function Place()
        local cap = frame:GetHeight() * CAP * 2  -- (the art is twice as wide as tall)
        parts[1]:SetPoint("TOPLEFT") parts[1]:SetPoint("BOTTOMLEFT") parts[1]:SetWidth(cap)
        parts[3]:SetPoint("TOPRIGHT") parts[3]:SetPoint("BOTTOMRIGHT") parts[3]:SetWidth(cap)
        parts[2]:SetPoint("TOPLEFT", parts[1], "TOPRIGHT") parts[2]:SetPoint("BOTTOMRIGHT", parts[3], "BOTTOMLEFT")
    end
    frame:HookScript("OnSizeChanged", Place)
    Place()
    local slices = {}
    function slices:Set(art) for _, t in ipairs(parts) do t:SetTexture(ART .. art) end end
    function slices:SetVertexColor(r, g, b) for _, t in ipairs(parts) do t:SetVertexColor(r, g, b) end end
    slices:Set(name)
    return slices
end

-- The mock's .btn: velvet, a gilt border, gold text; brighter while hovered, a pixel down while pressed; greyed out
-- while disabled (button:SetEnabled).
function ShopUI.Button(parent, width, height, label, size)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, height)
    button.art = Slices(button, "Button")
    button.text = ShopUI.Text(button, DISPLAY, size or 14, "#f6d98a")
    button.text:SetPoint("CENTER", 0, 0)
    button.text:SetText(label or "")
    local function Look(self)
        local on = self:IsEnabled()
        self.art:Set(on and "Button" or "ButtonOff")
        self.text:SetTextColor(C(on and "#f6d98a" or "#ece2cf"))
        local lit = on and self:IsMouseOver() and 1.12 or 1
        self.art:SetVertexColor(lit, lit, lit)
    end
    button:HookScript("OnEnable", Look)
    button:HookScript("OnDisable", Look)
    button:HookScript("OnEnter", Look)
    button:HookScript("OnLeave", function(self) Look(self) GameTooltip:Hide() end)
    button:HookScript("OnMouseDown", function(self) if self:IsEnabled() then self.text:SetPoint("CENTER", 0, -1) end end)
    button:HookScript("OnMouseUp", function(self) self.text:SetPoint("CENTER", 0, 0) end)
    Look(button)
    return button
end

-- The mock's gold plaque look (its tabs and the floor cart): brass, a rivet at each end, dark ink. plaque:SetLit(true):
-- the open tab's velvet with gold text.
function ShopUI.Plaque(parent, width, height, size)
    local plaque = CreateFrame("Button", nil, parent)
    plaque:SetSize(width, height)
    plaque.art = Slices(plaque, "Plaque")
    plaque.text = plaque:CreateFontString(nil, "OVERLAY")
    plaque.text:SetFont(DISPLAY, size or 13, "")
    plaque.text:SetPoint("CENTER", 0, 0)
    function plaque:SetLit(lit)
        self.lit = lit
        self.art:Set(lit and "PlaqueOn" or "Plaque")
        self.text:SetTextColor(C(lit and "#f6d98a" or "#3a2610"))
        if lit then  -- (velvet: a dark shadow; brass: a light one under the ink)
            self.text:SetShadowColor(0, 0, 0, 1) self.text:SetShadowOffset(0, -1)
        else
            self.text:SetShadowColor(1, 0.94, 0.78, 0.6) self.text:SetShadowOffset(0, -1)
        end
    end
    plaque:HookScript("OnEnter", function(self) if not self.lit then self.art:SetVertexColor(1.08, 1.08, 1.08) end end)
    plaque:HookScript("OnLeave", function(self) self.art:SetVertexColor(1, 1, 1) end)
    plaque:SetLit(false)
    return plaque
end

-- The mock's round velvet knob (36 px, a gilt rim and a dark ring) with an arrow: dir -1 left, 1 right.
function ShopUI.Knob(parent, dir)
    local knob = CreateFrame("Button", nil, parent)
    knob:SetSize(40, 40)
    local face = knob:CreateTexture(nil, "BACKGROUND")
    face:SetPoint("CENTER", 0, -1)
    face:SetSize(46, 46)
    face:SetTexture(ART .. "Knob")
    local arrow = knob:CreateTexture(nil, "ARTWORK")
    arrow:SetSize(16, 16)
    arrow:SetPoint("CENTER", dir < 0 and -1 or 1, 0)
    arrow:SetTexture(ART .. "Arrow")
    if dir > 0 then arrow:SetTexCoord(1, 0, 0, 1) end
    knob:SetScript("OnEnter", function() face:SetVertexColor(1.15, 1.15, 1.15) end)
    knob:SetScript("OnLeave", function() face:SetVertexColor(1, 1, 1) end)
    knob:SetScript("OnMouseDown", function() face:SetPoint("CENTER", 0, -2) arrow:SetPoint("CENTER", dir < 0 and -1 or 1, -1) end)
    knob:SetScript("OnMouseUp", function() face:SetPoint("CENTER", 0, -1) arrow:SetPoint("CENTER", dir < 0 and -1 or 1, 0) end)
    return knob
end

-- A curtain's panel: a dark velvet gradient in a rounded gilt frame (nine slices), a brass pin on its top, a shadow
-- under it.
function ShopUI.Panel(parent)
    local panel = CreateFrame("Frame", nil, parent)
    local shadow = panel:CreateTexture(nil, "BACKGROUND", nil, -2)
    shadow:SetPoint("TOPLEFT", -2, -4) shadow:SetPoint("BOTTOMRIGHT", 2, -8)
    shadow:SetColorTexture(0, 0, 0, 0.35)
    local fill = panel:CreateTexture(nil, "BACKGROUND", nil, -1)
    fill:SetPoint("TOPLEFT", 2, -2) fill:SetPoint("BOTTOMRIGHT", -2, 2)
    Gradient(fill, { C("#3d0b12") }, { C("#2c070c") })
    local E = 16 / 64  -- (the frame's corners: 16 px of its 64)
    local cells = { { 0, E }, { E, 1 - E }, { 1 - E, 1 } }
    local parts = {}
    for row = 1, 3 do
        for col = 1, 3 do
            local t = panel:CreateTexture(nil, "BORDER")
            t:SetTexture(ART .. "Panel")
            t:SetTexCoord(cells[col][1], cells[col][2], cells[row][1], cells[row][2])
            parts[(row - 1) * 3 + col] = t
        end
    end
    local function Place()
        local w, h = panel:GetSize()
        local x = { 0, 16, w - 16 }
        local y = { 0, 16, h - 16 }
        local sw = { 16, w - 32, 16 }
        local sh = { 16, h - 32, 16 }
        for row = 1, 3 do
            for col = 1, 3 do
                local t = parts[(row - 1) * 3 + col]
                t:ClearAllPoints()
                t:SetPoint("TOPLEFT", x[col], -y[row])
                t:SetSize(math.max(0.1, sw[col]), math.max(0.1, sh[row]))
            end
        end
    end
    panel:SetScript("OnSizeChanged", Place)
    local pin = panel:CreateTexture(nil, "OVERLAY")
    pin:SetSize(16, 16)
    pin:SetPoint("CENTER", panel, "TOP", 0, -1)
    pin:SetTexture(ART .. "Rivet")
    return panel
end

-- A velvet curtain: the folds (a tile repeated across), lighter at the top and darker at the bottom, its inner bottom
-- corner curved (a mask), its shadow on the room following that outline. side "left" or "right".
function ShopUI.Curtain(parent, side)
    local curtain = CreateFrame("Frame", nil, parent)
    local folds = curtain:CreateTexture(nil, "BACKGROUND")
    folds:SetAllPoints()
    folds:SetTexture(ART .. "Stripes", "REPEAT", "REPEAT")
    local wash = curtain:CreateTexture(nil, "BORDER")
    wash:SetAllPoints()
    Gradient(wash, { 1, 1, 1, 0.06 }, { 0, 0, 0, 0.25 })
    local mask = curtain:CreateMaskTexture()
    mask:SetTexture(ART .. (side == "right" and "CurtainMaskRight" or "CurtainMask"), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints()
    folds:AddMaskTexture(mask)
    wash:AddMaskTexture(mask)
    local shadow = curtain:CreateTexture(nil, "BACKGROUND", nil, -1)  -- (on the room, round its inner edge and curve)
    shadow:SetTexture(ART .. (side == "right" and "CurtainShadowRight" or "CurtainShadow"))
    if side == "left" then
        shadow:SetPoint("TOPLEFT") shadow:SetPoint("BOTTOMRIGHT", 22, 0)
    else
        shadow:SetPoint("TOPLEFT", -22, 0) shadow:SetPoint("BOTTOMRIGHT")
    end
    function curtain:Layout(width)
        folds:SetTexCoord(0, width / 32, 0, 1)  -- (one fold every 32 px)
    end
    return curtain
end

-- The valance across the top: velvet, a 3 px gilt edge at its bottom and a gold fringe hanging under that, its
-- shadow on what's below.
function ShopUI.Valance(parent)
    local valance = CreateFrame("Frame", nil, parent)
    local velvet = valance:CreateTexture(nil, "ARTWORK")
    velvet:SetPoint("TOPLEFT") velvet:SetPoint("BOTTOMRIGHT", 0, 3)
    velvet:SetColorTexture(1, 1, 1)
    -- (#9a2834 -> #6b1a21 at 70% -> #4a0b11: two gradients)
    velvet:SetGradient("VERTICAL", Col("#6b1a21"), Col("#9a2834"))
    velvet:ClearAllPoints()
    velvet:SetPoint("TOPLEFT") velvet:SetPoint("TOPRIGHT")
    local low = valance:CreateTexture(nil, "ARTWORK")
    low:SetPoint("BOTTOMLEFT", 0, 3) low:SetPoint("BOTTOMRIGHT", 0, 3)
    low:SetColorTexture(1, 1, 1)
    low:SetGradient("VERTICAL", Col("#4a0b11"), Col("#6b1a21"))
    velvet:SetPoint("BOTTOM", low, "TOP")
    local edge = valance:CreateTexture(nil, "ARTWORK")
    edge:SetPoint("BOTTOMLEFT") edge:SetPoint("BOTTOMRIGHT")
    edge:SetHeight(3)
    edge:SetColorTexture(C("#c9a14a"))
    local fringe = valance:CreateTexture(nil, "ARTWORK")
    fringe:SetPoint("TOPLEFT", valance, "BOTTOMLEFT", 0, -2) fringe:SetPoint("TOPRIGHT", valance, "BOTTOMRIGHT", 0, -2)
    fringe:SetHeight(10)
    fringe:SetTexture(ART .. "Fringe", "REPEAT", "CLAMP")
    local shadow = valance:CreateTexture(nil, "BACKGROUND")
    shadow:SetPoint("TOPLEFT", valance, "BOTTOMLEFT") shadow:SetPoint("TOPRIGHT", valance, "BOTTOMRIGHT")
    shadow:SetHeight(14)
    Gradient(shadow, { 0, 0, 0, 0.6 }, { 0, 0, 0, 0 })
    function valance:Layout(width, height)
        low:SetHeight((height - 3) * 0.3)
        fringe:SetTexCoord(0, width / 8, 0, 1)
    end
    return valance
end
