-- The Pro Shop's room: its own page in the sidebar (Guild: Pro Shop; SHOP in ogre mode), the whole page area. A
-- stand-in until the shop floor is painted: burgundy velvet walls over dark wood panelling and floor, a brass plate
-- with the shop's name and your points, and in the middle the walnut mannequin (Media/ProShop/Mannequin, the moss ogre
-- in walnut: tools/make-mannequin.js) on its brass stand, wearing the display set. The wares and buying: ProShop.lua.
-- Next: clicking the mannequin opens the dressing view (the curtains), the cart pill its checkout.

local _, ns = ...
local UI = ns.UI
if not UI then return end
local Tooltip = UI.Tooltip

local MEDIA = "Interface\\AddOns\\SOLC\\Media\\ProShop\\"
local NAME_FONT = "Interface\\AddOns\\SOLC\\Media\\Fonts\\GermaniaOne-Regular.ttf"
local PLATE = "Interface\\AddOns\\SOLC\\Media\\Overview\\Plate"
local CREAM, GOLD = { 0.96, 0.9, 0.78 }, { 1, 0.82, 0.1 }
local VELVET_TOP, VELVET_BOTTOM = { 0.36, 0.06, 0.09 }, { 0.2, 0.03, 0.05 }
local WOOD_TOP, WOOD_BOTTOM = { 0.2, 0.12, 0.07 }, { 0.09, 0.05, 0.03 }
local BRASS = { 0.78, 0.62, 0.3 }

-- What the mannequin wears when you walk in.
ns.SHOP_DISPLAY = { headwear = "shop_flat_cap", outfit = "shop_argyle_vest" }

local room

local function Gradient(tex, top, bottom)
    tex:SetColorTexture(1, 1, 1)
    tex:SetGradient("VERTICAL", CreateColor(bottom[1], bottom[2], bottom[3], 1), CreateColor(top[1], top[2], top[3], 1))
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

-- Dresses the mannequin: the pieces drawn as a picture with no skin (ns.RenderMint), the walnut body in the skin's
-- place under them, cut where the pieces hide the body (their masks, as RenderMint puts them on a skin).
local function Dress(mannequin, traits)
    ns.RenderMint(mannequin.canvas, traits)
    for _, mask in ipairs(mannequin.masks or {}) do mannequin.body:RemoveMaskTexture(mask) end
    mannequin.masks = {}
    for _, option in pairs(Worn(traits)) do
        if option.hide then
            local mask = mannequin.canvas:CreateMaskTexture()
            mask:SetTexture(option.hide, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            mask:SetAllPoints(mannequin.canvas)
            mannequin.body:AddMaskTexture(mask)
            mannequin.masks[#mannequin.masks + 1] = mask
        end
    end
    mannequin.traits = traits
end

local function Build(holder)
    room = CreateFrame("Frame", nil, holder)
    room:SetAllPoints()

    -- The walls: velvet, a darker stripe every so often like a damask, over a band of panelling with a brass rail;
    -- the floor's boards below.
    local wall = room:CreateTexture(nil, "BACKGROUND", nil, -8)
    wall:SetAllPoints()
    Gradient(wall, VELVET_TOP, VELVET_BOTTOM)
    room.stripes = {}
    local floor = room:CreateTexture(nil, "BACKGROUND", nil, -5)
    floor:SetPoint("BOTTOMLEFT") floor:SetPoint("BOTTOMRIGHT")
    Gradient(floor, WOOD_TOP, WOOD_BOTTOM)
    local panel = room:CreateTexture(nil, "BACKGROUND", nil, -6)
    panel:SetPoint("BOTTOMLEFT", floor, "TOPLEFT") panel:SetPoint("BOTTOMRIGHT", floor, "TOPRIGHT")
    panel:SetHeight(54)
    Gradient(panel, { 0.25, 0.15, 0.08 }, { 0.15, 0.09, 0.05 })
    local rail = room:CreateTexture(nil, "BACKGROUND", nil, -4)
    rail:SetPoint("BOTTOMLEFT", panel, "TOPLEFT") rail:SetPoint("BOTTOMRIGHT", panel, "TOPRIGHT")
    rail:SetHeight(3)
    rail:SetColorTexture(unpack(BRASS))
    local skirting = room:CreateTexture(nil, "BACKGROUND", nil, -4)
    skirting:SetPoint("TOPLEFT", floor) skirting:SetPoint("TOPRIGHT", floor)
    skirting:SetHeight(2)
    skirting:SetColorTexture(0.05, 0.03, 0.02)
    room.floor, room.panel = floor, panel

    -- The plate: the shop's name, your points under it.
    local plate = CreateFrame("Frame", nil, room)
    plate:SetSize(220, 40)
    plate:SetPoint("TOP", 0, -14)
    local ends = {}
    for i, slice in ipairs({ { 0, 0.25 }, { 0.25, 0.75 }, { 0.75, 1 } }) do
        local t = plate:CreateTexture(nil, "ARTWORK")
        t:SetTexture(PLATE)
        t:SetTexCoord(slice[1], slice[2], 0, 1)
        ends[i] = t
    end
    ends[1]:SetPoint("TOPLEFT") ends[1]:SetPoint("BOTTOMLEFT") ends[1]:SetWidth(18)
    ends[3]:SetPoint("TOPRIGHT") ends[3]:SetPoint("BOTTOMRIGHT") ends[3]:SetWidth(18)
    ends[2]:SetPoint("TOPLEFT", ends[1], "TOPRIGHT") ends[2]:SetPoint("BOTTOMRIGHT", ends[3], "BOTTOMLEFT")
    local name = plate:CreateFontString(nil, "OVERLAY")
    name:SetPoint("CENTER", 0, 1)
    name:SetFont(NAME_FONT, 24, "")
    name:SetTextColor(unpack(GOLD))
    UI.OutlineText(name, { 0, 0, 0 })
    name:SetText("Pro Shop")
    room.points = room:CreateFontString(nil, "OVERLAY")
    room.points:SetPoint("TOP", plate, "BOTTOM", 0, -6)
    room.points:SetFont(NAME_FONT, 15, "")
    room.points:SetTextColor(unpack(CREAM))
    UI.OutlineText(room.points, { 0, 0, 0 })

    -- The mannequin: its stand on the floor, the walnut body on the pole, the display set on it.
    local mannequin = CreateFrame("Button", nil, room)
    mannequin.stand = room:CreateTexture(nil, "BORDER")
    mannequin.stand:SetTexture(MEDIA .. "Stand")
    mannequin.canvas = CreateFrame("Frame", nil, mannequin)
    mannequin.canvas:SetAllPoints()
    mannequin.body = mannequin.canvas:CreateTexture(nil, "ARTWORK", nil, -4)  -- (the skin's sublevel: Minting.lua)
    mannequin.body:SetAllPoints()
    mannequin.body:SetTexture(MEDIA .. "Mannequin")
    mannequin:SetScript("OnEnter", function(self)
        local lines = { "The display set" }
        for _, layer in ipairs(ns.MintLayers or {}) do
            local option = Worn(self.traits or ns.SHOP_DISPLAY)[layer.key]
            if option then lines[#lines + 1] = ("|c%s%s|r"):format(ns.RARITY_COLORS[option.rarity] or "ffffffff", option.name) end
        end
        lines[#lines + 1] = "Trying things on: coming soon"
        Tooltip(self, lines)
    end)
    mannequin:SetScript("OnLeave", GameTooltip_Hide)
    room.mannequin = mannequin

    -- The cart, in the corner (empty until the dressing view fills it).
    local cart = CreateFrame("Button", nil, room)
    cart:SetSize(110, 30)
    cart:SetPoint("BOTTOMRIGHT", -16, 14)
    local pill = cart:CreateTexture(nil, "BACKGROUND")
    pill:SetAllPoints()
    pill:SetColorTexture(0.12, 0.07, 0.04, 0.9)
    local rim = cart:CreateTexture(nil, "BORDER")
    rim:SetPoint("TOPLEFT", -1, 1) rim:SetPoint("BOTTOMRIGHT", 1, -1)
    rim:SetColorTexture(unpack(BRASS))
    rim:SetDrawLayer("BACKGROUND", -1)
    cart.text = cart:CreateFontString(nil, "OVERLAY")
    cart.text:SetPoint("CENTER")
    cart.text:SetFont(NAME_FONT, 15, "")
    cart.text:SetTextColor(unpack(CREAM))
    cart:SetScript("OnEnter", function(self) Tooltip(self, { "Your cart", "Empty. Try something on first." }) end)
    cart:SetScript("OnLeave", GameTooltip_Hide)
    room.cart = cart
end

-- Sizes everything to the page area: the floor the bottom quarter, the mannequin as big as fits above it, its stand's
-- base on the floor; the velvet's stripes across the width.
local function Layout()
    local w, h = room:GetSize()
    if w == 0 or h == 0 then return end
    local floorH = math.floor(h * 0.24)
    room.floor:SetHeight(floorH)
    local stripe = 0
    for x = 22, w, 44 do
        stripe = stripe + 1
        local t = room.stripes[stripe] or room:CreateTexture(nil, "BACKGROUND", nil, -7)
        room.stripes[stripe] = t
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", x, 0)
        t:SetPoint("BOTTOM", room.panel, "TOP")
        t:SetWidth(14)
        t:SetColorTexture(0, 0, 0, 0.12)
        t:Show()
    end
    for i = stripe + 1, #room.stripes do room.stripes[i]:Hide() end
    local size = math.min(h * 0.6, w * 0.6, 360)
    local m = room.mannequin
    m:SetSize(size, size)
    m:ClearAllPoints()
    m:SetPoint("BOTTOM", room, "BOTTOM", 0, floorH * 0.55 + size * 0.28)
    m.stand:ClearAllPoints()
    m.stand:SetSize(size * 0.62, size * 0.62)
    m.stand:SetPoint("BOTTOM", room, "BOTTOM", 0, floorH * 0.55 - size * 0.62 * 0.12)
    if m.dressedAt ~= size then  -- (the pieces are placed by the mannequin's size)
        Dress(m, m.traits or ns.SHOP_DISPLAY)
        m.dressedAt = size
    end
end

local function Refresh()
    Layout()
    room.points:SetText(("You have |cffffd21a%s|r points"):format(BreakUpLargeNumbers(ns.GetPoints().balance)))
    room.cart.text:SetText("Cart (0)")
end

ns.RegisterPage({
    key = "proshop", label = "Pro Shop", section = "guild", order = 4,
    bare = true,
    create = function(parent)
        local holder = CreateFrame("Frame", nil, parent)
        holder:SetAllPoints()
        Build(holder)
        room:SetScript("OnSizeChanged", Layout)
        return holder
    end,
    refresh = function() Refresh() end,
})

function ns.ShowProShop() ns.OpenPage("proshop") end
