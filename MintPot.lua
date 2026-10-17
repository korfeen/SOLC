-- The minting pot: minting as a little cooking game, when you have ingredients (Unlocks.lua; Minting.lua's
-- ns.ConfirmMint, else a plain popup asks). Over the main window's pages, like the chest show: a witch's cauldron on a
-- fire, a shelf of your ingredients over it (dungeons', layers' and Shimmer Dust, with how many you have):
-- - drag one into the cauldron (or click it: it's thrown in, in an arc): it sinks into the brew, which ripples and takes
--   on its colour, and floats in it; right-click it to take one back out, or (a dungeon's) to buy one of its missing
--   pieces (ns.TOKEN_SHOP_PRICE of them);
-- - the recipe card says what it does: the pieces it aims at with their chances, and how much rarer it makes the layers
--   (ns.PotPlan, Minting.lua: never past its ceiling); the price card the mint's price and your points;
-- - the cauldron is your rank's (Ranks.lua's ns.CAULDRONS: bigger ones hold more), drawn bigger the bigger it is;
-- - stir it with the spoon, three times, and it goes POOF: the mint, the ingredients in it spent (ns.DoMint).
-- Drawn with the crayon art from tools/make-kitchen-art.js (Media/Icons/Kitchen, Media/Icons/Ingredients).

local _, ns = ...

local NAME_FONT = "Interface\\AddOns\\SOLC\\Media\\Fonts\\GermaniaOne-Regular.ttf"
local KITCHEN = "Interface\\AddOns\\SOLC\\Media\\Icons\\Kitchen\\"
local FX = "Interface\\AddOns\\SOLC\\Media\\Icons\\Fx_"
local BUTTON_WORD = { 1, 0.93, 0.78 }
-- The page's layout (positions from the window's top middle, sizes in pixels): the drying line, the stations, the
-- cauldron, the chef and the reveal; and how many stirs it takes. One table, not locals: Lua 5.1 lets a function see at
-- most 60 of them.
local LAYOUT = {
    ROPE_Y = -34,
    ROPE_W = 800,
    PHOTOS = 7,
    PHOTO_W = 74,
    PHOTO_H = 86,
    -- Three stations: the pantry shelf (dungeons' ingredients, paged), the spice rack (the layers', always all seven,
    -- in the same places) and the woodpile by the fire (the fuels, all three).
    SHELF_Y = -170,
    SLOT = 56,
    SLOT_GAP = 14,
    SLOTS = 10,
    RACK_X = -212,
    RACK_Y = -238,
    RACK_SLOT = 42,
    RACK_GAP = 8,
    WOOD_X = -112,
    WOOD_Y = -552,
    WOOD_SLOT = 42,
    WOOD_GAP = 8,
    POT_Y = -404,
    POT_SIZE = 240,
    CHEF_X = -318,
    CHEF_Y = -478,
    CHEF_SIZE = 210,
    BIG = 280, BIG_Y = -190, REEL_Y = -432,  -- the reveal: the photo's picture size, its middle, the reel's middle
    STIRS = 3,
}
local MASK = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"  -- (a round mask: the splash spreading)
local OGRE_RARITY = { uncommon = "OK!", rare = "NICE!", epic = "WOW!", legendary = "WOAH!" }
local MURKY = { 0.45, 0.55, 0.4 }  -- an empty brew
-- Each ingredient's colour in the brew.
local COLORS = {
    rfc = { 1, 0.45, 0.1 }, wc = { 0.48, 1, 0.29 }, dm = { 1, 0.82, 0.25 }, sfk = { 0.6, 0.58, 0.63 }, bfd = { 0.29, 0.23, 0.54 },
    stocks = { 0.6, 0.63, 0.66 }, gnomer = { 0.48, 0.85, 0.29 }, rfk = { 0.55, 0.36, 0.2 }, smgy = { 0.36, 0.25, 0.19 },
    smlib = { 0.94, 0.88, 0.69 }, smarm = { 0.75, 0.16, 0.16 }, smcath = { 1, 0.95, 0.66 }, rfd = { 0.62, 0.91, 1 },
    ulda = { 0.35, 0.78, 1 }, zf = { 0.78, 0.58, 0.35 }, mara = { 0.69, 0.48, 1 }, thanes = { 0.62, 0.91, 1 },
    ruins = { 0.48, 0.85, 0.42 }, excav = { 0.78, 0.58, 0.35 }, st = { 0.23, 0.6, 0.35 }, brd = { 1, 0.48, 0.1 },
    lbrs = { 0.75, 0.16, 0.16 }, ubrs = { 1, 0.6, 0.16 }, dme = { 0.36, 0.82, 0.29 }, dmw = { 0.48, 0.69, 1 },
    dmn = { 0.48, 1, 0.29 }, scholo = { 0.6, 0.42, 0.85 }, stratl = { 0.62, 0.85, 1 }, stratu = { 0.69, 0.48, 1 },
    ony = { 0.42, 0.29, 0.35 }, barrow = { 0.72, 0.66, 1 }, hyjal = { 0.88, 0.63, 0.19 },
    l_background = { 0.5, 0.8, 1 }, l_skin = { 0.6, 1, 0.8 }, l_outfit = { 0.85, 0.3, 0.3 }, l_expression = { 1, 0.35, 0.8 },
    l_eyes = { 0.9, 0.85, 0.2 }, l_accessory = { 0.95, 0.8, 0.4 }, l_headwear = { 0.85, 0.75, 0.6 }, shimmer = { 0.9, 0.7, 1 },
}

local window
local pot, page = {}, 0  -- what's in the pot ({ [ingredient key] = n }); the shelf's page
local tweens, bubbles, live, bits = {}, {}, {}, {}
local stirs, stirring, drag = 0, false, nil
local potSize, bubbleTimer, clock, swirl = LAYOUT.POT_SIZE, 0, 0, 0  -- (swirl: how far stirring has turned the brew)
local squash, slosh, flare = 1, 0, 0  -- the cauldron's gulp (its height, 1 at rest), the brew's slosh after it, the fire's flare
local function IsFuel(key) return ns.IngredientKind(key) == "fuel" end
local RANK = { uncommon = 1, rare = 2, epic = 3, legendary = 4 }

local function Text(parent, size, r, g, b)
    local text = parent:CreateFontString(nil, "OVERLAY")
    text:SetFont(NAME_FONT, size, "")
    text:SetTextColor(r, g, b)
    ns.UI.OutlineText(text, { 0, 0, 0 })
    return text
end
local function Tween(duration, update, done) tweens[#tweens + 1] = { t = 0, d = duration, update = update, done = done } end
local function EaseOut(p) return 1 - (1 - p) ^ 3 end
-- How many ingredients are in the pot (fuels: in the fire, instead).
local function InPot(fire)
    local total = 0
    for key, n in pairs(pot) do
        if IsFuel(key) == (fire or false) then total = total + n end
    end
    return total
end
-- The fire's colour: its rarest fuel's (nil: no fuel, an ordinary fire).
local function FireColor()
    local color
    for _, fuel in ipairs(ns.FUELS) do
        if (pot[fuel.key] or 0) > 0 then color = fuel.color end
    end
    return color
end
local function Sound(name)
    local id = SOUNDKIT and SOUNDKIT[name]
    if id then pcall(PlaySound, id) end
end
-- The brew's colour: its ingredients' colours mixed by how many of each, by hue (averaged around the colour wheel), so it
-- stays bright: red and green make yellow, not brown. Shown, it eases there (brewShown), after flashing in the colour of
-- whatever just went in.
local function ToHSV(c)
    local r, g, b = c[1], c[2], c[3]
    local max, min = math.max(r, g, b), math.min(r, g, b)
    local d, h = max - min, 0
    if d > 0 then
        if max == r then h = ((g - b) / d) % 6 elseif max == g then h = (b - r) / d + 2 else h = (r - g) / d + 4 end
        h = h / 6
    end
    return h, max > 0 and d / max or 0, max
end
local function FromHSV(h, s, v)
    local i = math.floor(h * 6) % 6
    local f = h * 6 - math.floor(h * 6)
    local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
    return ({ { v, t, p }, { q, v, p }, { p, v, t }, { p, q, v }, { t, p, v }, { v, p, q } })[i + 1]
end
local function BrewColor()
    local total = InPot()
    if total == 0 then return MURKY end
    local x, y, sat, val = 0, 0, 0, 0
    for key, n in pairs(pot) do
        local h, s, v = ToHSV(COLORS[key] or MURKY)
        local w = IsFuel(key) and 0 or n / total
        x, y = x + math.cos(h * 2 * math.pi) * s * w, y + math.sin(h * 2 * math.pi) * s * w
        sat, val = sat + s * w, val + v * w
    end
    local hue = (math.atan2 and math.atan2(y, x) or math.atan(y, x)) / (2 * math.pi) % 1
    return FromHSV(hue, math.max(0.35, sat), math.max(0.5, val))
end
local brewShown = { MURKY[1], MURKY[2], MURKY[3] }
local function Place(region, x, y, point)
    region:ClearAllPoints()
    region:SetPoint(point or "CENTER", window, "TOP", x, y)
end
-- The brew's surface (its middle): it goes down with the cauldron's gulp, and sloshes after it.
local function Surface()
    return LAYOUT.POT_Y - potSize * (1 - squash) / 2 + potSize * squash * 0.11 + math.sin(clock * 14) * 4 * slosh
end
local function FireY() return LAYOUT.POT_Y - potSize * 0.36 end
-- The cursor, as an offset from the window's top middle.
local function CursorPos()
    local x, y = GetCursorPosition()
    local scale = window:GetEffectiveScale()
    return x / scale - (window:GetLeft() + window:GetWidth() / 2), y / scale - window:GetTop()
end
local function OverPot(x, y)
    return math.abs(x) < potSize * 0.42 and y < Surface() + potSize * 0.3 and y > LAYOUT.POT_Y - potSize * 0.4
end
local function OverFire(x, y)
    return math.abs(x) < potSize * 0.45 and y < LAYOUT.POT_Y - potSize * 0.1 and y > FireY() - potSize * 0.4
end
local function Bubble(x, y, size, life, color)
    local tex = table.remove(bubbles) or window.over:CreateTexture(nil, "OVERLAY", nil, 3)
    tex:SetTexture(KITCHEN .. "Bubble")
    tex:SetVertexColor(unpack(color))
    tex:SetAlpha(1)
    tex:Show()
    live[#live + 1] = { tex = tex, x = x, y = y, size = size, age = 0, life = life }
end

-- The scenery: the kitchen's back wall and floor, behind everything, filling the main window's page background to the
-- wood (ns.UI.pageBody, under the beams; the kitchen itself is over the pages only); the fire's warm glow on the wall,
-- the cauldron's shadow on the floor, the corners darker. Its own frame: under the wood, over the pages.
local FLOOR_Y = -478  -- the floor's far edge, from the page's top
local function BuildScene()
    local scene = CreateFrame("Frame", nil, UIParent)
    scene:Hide()
    local function Tiled(file, layer, sublevel, r, g, b)
        local tex = scene:CreateTexture(nil, layer, nil, sublevel)
        tex:SetTexture(KITCHEN .. file, "REPEAT", "REPEAT")
        tex:SetVertexColor(r, g, b)
        return tex
    end
    local function Shade(layer, sublevel, a1, a2, horizontal)  -- black, fading from a1 to a2 (bottom to top / left to right)
        local tex = scene:CreateTexture(nil, layer, nil, sublevel)
        tex:SetColorTexture(1, 1, 1, 1)
        if CreateColor then tex:SetGradient(horizontal and "HORIZONTAL" or "VERTICAL", CreateColor(0, 0, 0, a1), CreateColor(0, 0, 0, a2)) end
        return tex
    end
    scene.wall = Tiled("Wall", "BACKGROUND", 0, 0.42, 0.36, 0.34)
    scene.wall:SetAllPoints()
    scene.glow = scene:CreateTexture(nil, "BACKGROUND", nil, 2)
    scene.glow:SetTexture(FX .. "Glow")
    scene.glow:SetBlendMode("ADD")
    scene.floor = Tiled("Floor", "BORDER", 0, 0.62, 0.46, 0.36)
    scene.wallFoot = Shade("BACKGROUND", 3, 0.55, 0)     -- the wall darkening down to the floor
    scene.floorFar = Shade("BORDER", 1, 0, 0.6)          -- the floor darker far back, at the wall
    scene.seam = scene:CreateTexture(nil, "BORDER", nil, 2)
    scene.seam:SetColorTexture(0.08, 0.05, 0.04, 1)
    scene.shadow = scene:CreateTexture(nil, "ARTWORK", nil, 0)  -- under the cauldron
    scene.shadow:SetTexture(KITCHEN .. "Brew")
    scene.shadow:SetVertexColor(0, 0, 0)
    scene.shadow:SetAlpha(0.6)
    scene.edges = { Shade("ARTWORK", 2, 0, 0.75), Shade("ARTWORK", 2, 0.75, 0), Shade("ARTWORK", 2, 0.7, 0, true), Shade("ARTWORK", 2, 0, 0.7, true) }
    -- Fills page (the page area) and body (all of the background, to the wood), at level.
    function scene:Fit(parent, body, page, level)
        self:SetParent(parent)
        self:ClearAllPoints()
        self:SetAllPoints(body)
        self:SetFrameLevel(level)
        -- Its edges from the page's top middle (the glow is cropped to them).
        local cx, top = (page:GetLeft() or 0) + (page:GetWidth() or 0) / 2, page:GetTop() or 0
        self.bounds = { left = (body:GetLeft() or 0) - cx, right = (body:GetRight() or 0) - cx,
            top = (body:GetTop() or 0) - top, bottom = (body:GetBottom() or 0) - top }
        local w, h = body:GetWidth(), body:GetHeight()
        self.wall:SetTexCoord(0, w / 256, 0, h / 256)
        local floorH = math.max(1, ((page:GetTop() or 0) + FLOOR_Y) - (body:GetBottom() or 0))
        self.floor:ClearAllPoints()
        self.floor:SetPoint("BOTTOMLEFT")
        self.floor:SetPoint("BOTTOMRIGHT")
        self.floor:SetHeight(floorH)
        self.floor:SetTexCoord(0, w / 256, 0, floorH / 256)
        self.wallFoot:ClearAllPoints()
        self.wallFoot:SetPoint("BOTTOMLEFT", self.floor, "TOPLEFT")
        self.wallFoot:SetPoint("BOTTOMRIGHT", self.floor, "TOPRIGHT")
        self.wallFoot:SetHeight(90)
        self.floorFar:ClearAllPoints()
        self.floorFar:SetPoint("TOPLEFT", self.floor)
        self.floorFar:SetPoint("TOPRIGHT", self.floor)
        self.floorFar:SetHeight(50)
        self.seam:ClearAllPoints()
        self.seam:SetPoint("LEFT", self.floor, "TOPLEFT")
        self.seam:SetPoint("RIGHT", self.floor, "TOPRIGHT")
        self.seam:SetHeight(4)
        local top, bottom, left, right = unpack(self.edges)
        top:SetPoint("TOPLEFT") top:SetPoint("TOPRIGHT") top:SetHeight(80)
        bottom:SetPoint("BOTTOMLEFT") bottom:SetPoint("BOTTOMRIGHT") bottom:SetHeight(80)
        left:SetPoint("TOPLEFT") left:SetPoint("BOTTOMLEFT") left:SetWidth(110)
        right:SetPoint("TOPRIGHT") right:SetPoint("BOTTOMRIGHT") right:SetWidth(110)
        self.page = page
    end
    -- Each frame: the glow behind the cauldron flickering in the fire's colour, the shadow under the cauldron.
    function scene:Update(potY, size, flicker, color)
        if not self.page then return end
        -- The glow's square, cropped to the scene (its part outside cut off, the texture with it).
        local glow, cy, b = size * 1.9 * flicker, potY - size * 0.2, self.bounds
        local x0, x1, y0, y1 = -glow / 2, glow / 2, cy + glow / 2, cy - glow / 2  -- (y0 its top, y1 its bottom)
        local cl, cr = math.max(x0, b.left), math.min(x1, b.right)
        local ct, cb = math.min(y0, b.top), math.max(y1, b.bottom)
        self.glow:ClearAllPoints()
        self.glow:SetPoint("TOPLEFT", self.page, "TOP", cl, ct)
        self.glow:SetSize(math.max(1, cr - cl), math.max(1, ct - cb))
        self.glow:SetTexCoord((cl - x0) / glow, (cr - x0) / glow, (y0 - ct) / glow, (y0 - cb) / glow)
        self.glow:SetVertexColor(color[1], color[2], color[3])
        self.glow:SetAlpha(0.26 * flicker)
        self.shadow:SetSize(size * 1.1, size * 0.5)
        self.shadow:ClearAllPoints()
        self.shadow:SetPoint("CENTER", self.page, "TOP", 0, potY - size * 0.48)
    end
    return scene
end

-- What an ingredient does, in a word: its dungeon's name ("Deadmines"), its layer's ("Headwear") or its fuel's rarity
-- ("Epic"); and the colour to say it in.
-- ink: the colour for the recipe's paper (darker), not for the dark kitchen.
local LAYER_WORD, LAYER_INK = { 0.6, 0.85, 1 }, { 0.12, 0.32, 0.6 }
local DUNGEON_WORD, DUNGEON_INK = { 1, 0.82, 0.25 }, { 0.55, 0.32, 0.05 }
local function EffectWord(key, ink)
    local kind = ns.IngredientKind(key)
    if kind == "fuel" then
        local fuel = ns.Fuel(key)
        local r, g, b = ns.RarityRGB(fuel.rarity)
        local k = ink and 0.72 or 1
        return (fuel.rarity:gsub("^%l", string.upper)), { r * k, g * k, b * k }
    elseif kind == "layer" then
        local layer = ns.MintLayerByKey and ns.MintLayerByKey(key:sub(3))
        return layer and layer.name or key, ink and LAYER_INK or LAYER_WORD
    end
    local d = ns.DungeonByKey and ns.DungeonByKey(key)
    return ((d and d.name or key):gsub("^The ", "")), ink and DUNGEON_INK or DUNGEON_WORD
end

-- Built once -----------------------------------------------------------------------------------------------------

local function Build()
    window = CreateFrame("Frame", "SOLCMintPot", UIParent, "BackdropTemplate")
    window:SetBackdrop({ bgFile = ns.WINDOW_BACKGROUND, edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 32, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    window:SetBackdropColor(0.09, 0.07, 0.06, 1)
    window:EnableMouse(true)
    window:SetClipsChildren(true)  -- (the chef stands behind the bottom beam, not over it)
    window:Hide()
    window.scene = BuildScene()
    window:HookScript("OnHide", function()
        window.scene:Hide()
        if ns.UI.ClearScreen then ns.UI.ClearScreen("Minting Kitchen") end
    end)


    -- The drying line: your newest pictures pegged on a rope, like an old photo studio's (the newest first).
    window.rope = window:CreateTexture(nil, "BACKGROUND", nil, 1)
    window.rope:SetTexture(KITCHEN .. "Rope")
    window.rope:SetSize(LAYOUT.ROPE_W, 120)
    window.photos = {}
    for i = 1, LAYOUT.PHOTOS + 1 do  -- (one more: the new one, developing)
        local photo = CreateFrame("Frame", nil, window)
        photo:SetSize(LAYOUT.PHOTO_W, LAYOUT.PHOTO_H)
        photo.paper = photo:CreateTexture(nil, "BACKGROUND")
        photo.paper:SetAllPoints()
        photo.paper:SetColorTexture(0.95, 0.92, 0.84)
        photo.canvas = CreateFrame("Frame", nil, photo)
        photo.canvas:SetPoint("TOPLEFT", 5, -5)
        photo.canvas:SetSize(LAYOUT.PHOTO_W - 10, LAYOUT.PHOTO_W - 10)
        photo.dark = photo.canvas:CreateTexture(nil, "OVERLAY", nil, 7)  -- the developer: fades off as it develops
        photo.dark:SetAllPoints()
        photo.dark:SetColorTexture(0.2, 0.13, 0.08)
        photo.dark:SetAlpha(0)
        photo.peg = photo:CreateTexture(nil, "OVERLAY")
        photo.peg:SetTexture(KITCHEN .. "Peg")
        photo.peg:SetSize(18, 38)
        photo.peg:SetPoint("CENTER", photo, "TOP", 0, 2)
        photo:Hide()
        window.photos[i] = photo
    end

    -- The chef: your Overview photo's ogre (or your newest picture's), without its backdrop and in a chef's hat, with
    -- something to say in a speech bubble.
    window.chef = CreateFrame("Frame", nil, window)
    window.chef:SetSize(LAYOUT.CHEF_SIZE, LAYOUT.CHEF_SIZE)
    window.chef.hat = window.chef:CreateTexture(nil, "OVERLAY", nil, 7)
    window.chef.hat:SetTexture(KITCHEN .. "ChefHat")
    window.chef.hat:SetSize(LAYOUT.CHEF_SIZE * 0.54, LAYOUT.CHEF_SIZE * 0.54)  -- (as tools/make-kitchen-art.js's preview-chef.png)
    window.chef.hat:SetPoint("CENTER", window.chef, "TOPLEFT", LAYOUT.CHEF_SIZE * 0.51, LAYOUT.CHEF_SIZE * 0.08)
    window.chef.apron = window.chef:CreateTexture(nil, "OVERLAY", nil, 6)  -- over the outfit, under the hat
    window.chef.apron:SetTexture(KITCHEN .. "Apron")
    window.chef.apron:SetSize(LAYOUT.CHEF_SIZE * 0.72, LAYOUT.CHEF_SIZE * 0.72)
    window.chef.apron:SetPoint("CENTER", window.chef, "TOPLEFT", LAYOUT.CHEF_SIZE * 0.5, -LAYOUT.CHEF_SIZE * 0.8)
    window.speech = CreateFrame("Frame", nil, window)
    window.speech:SetSize(130, 92)
    window.speech.art = window.speech:CreateTexture(nil, "ARTWORK")
    window.speech.art:SetAllPoints()
    window.speech.art:SetTexture(KITCHEN .. "Speech")
    window.speech.word = window.speech:CreateFontString(nil, "OVERLAY")  -- (ink on the bubble: no outline)
    window.speech.word:SetFont(NAME_FONT, 22, "")
    window.speech.word:SetTextColor(0.25, 0.15, 0.1)
    window.speech.word:SetPoint("CENTER", 4, 10)
    window.speech.word:SetWidth(150)
    window.speech.word:SetSpacing(2)
    window.speech:SetAlpha(0)

    -- The stations' slots: an ingredient with how many you have left (x3) and how many are in (+2), dragged or clicked in.
    local function MakeSlot(size, x, y, countSize)
        local slot = CreateFrame("Button", nil, window)
        slot:SetSize(size, size)
        slot.size, slot.x, slot.y = size, x, y
        Place(slot, x, y)
        slot:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        slot:RegisterForDrag("LeftButton")
        slot.icon = slot:CreateTexture(nil, "ARTWORK")
        slot.icon:SetAllPoints()
        slot.count = Text(slot, countSize or 15, 1, 1, 1)
        slot.count:SetPoint("BOTTOMRIGHT", 4, -4)
        slot.used = Text(slot, countSize or 15, 1, 0.82, 0.25)
        slot.used:SetPoint("TOPLEFT", -4, 4)
        slot:SetScript("OnEnter", function(self)
            if not self.key or drag then return end
            local how = self.kind == "fuel" and "Drag it onto the fire (or click)." or "Drag it into the cauldron (or click)."
            ns.UI.Tooltip(self, { ns.IngredientName(self.key), ns.IngredientSource(self.key) .. (" You have %d."):format(ns.Tokens(self.key)),
                how .. (self.kind == "dungeon" and " Right-click: take one out, or buy a piece." or " Right-click: take one out.") })
            self.icon:SetVertexColor(1.2, 1.2, 1.2)
        end)
        slot:SetScript("OnLeave", function(self) self.icon:SetVertexColor(1, 1, 1) GameTooltip_Hide() end)
        slot:SetScript("OnClick", function(self, button)
            if not self.key or drag then return end
            if button == "RightButton" then return window:SlotMenu(self) end
            window:Throw(self)
        end)
        slot:SetScript("OnDragStart", function(self) window:StartDrag(self) end)
        slot:SetScript("OnDragStop", function() window:StopDrag() end)
        return slot
    end
    -- The pantry shelf: the dungeons' ingredients you have.
    local shelf = window:CreateTexture(nil, "BACKGROUND", nil, 1)
    shelf:SetTexture(KITCHEN .. "Shelf")
    shelf:SetSize(780, 170)
    Place(shelf, 0, LAYOUT.SHELF_Y - 18)
    window.slots = {}
    for i = 1, LAYOUT.SLOTS do window.slots[i] = MakeSlot(LAYOUT.SLOT, (i - (LAYOUT.SLOTS + 1) / 2) * (LAYOUT.SLOT + LAYOUT.SLOT_GAP), LAYOUT.SHELF_Y) end
    -- The spice rack: every layer's ingredient, greyed while you have none.
    local count = #ns.LAYER_INGREDIENTS
    local rack = window:CreateTexture(nil, "BACKGROUND", nil, 1)
    rack:SetTexture(KITCHEN .. "Shelf")
    rack:SetSize(count * (LAYOUT.RACK_SLOT + LAYOUT.RACK_GAP) + 40, 110)
    Place(rack, LAYOUT.RACK_X, LAYOUT.RACK_Y - 12)
    window.rack = {}
    for i, spec in ipairs(ns.LAYER_INGREDIENTS) do
        local slot = MakeSlot(LAYOUT.RACK_SLOT, LAYOUT.RACK_X + (i - (count + 1) / 2) * (LAYOUT.RACK_SLOT + LAYOUT.RACK_GAP), LAYOUT.RACK_Y, 13)
        slot.key, slot.kind = spec.key, "layer"
        window.rack[i] = slot
    end
    -- The woodpile, by the fire: every fuel.
    local logs = window:CreateTexture(nil, "BACKGROUND", nil, 1)
    logs:SetTexture(KITCHEN .. "Logs")
    logs:SetSize(#ns.FUELS * (LAYOUT.WOOD_SLOT + LAYOUT.WOOD_GAP) + 40, 120)
    Place(logs, LAYOUT.WOOD_X, LAYOUT.WOOD_Y + 30)  -- (the logs are drawn low in their art: under the fuels)
    window.wood = {}
    for i, fuel in ipairs(ns.FUELS) do
        local slot = MakeSlot(LAYOUT.WOOD_SLOT, LAYOUT.WOOD_X + (i - (#ns.FUELS + 1) / 2) * (LAYOUT.WOOD_SLOT + LAYOUT.WOOD_GAP), LAYOUT.WOOD_Y, 13)
        slot.key, slot.kind = fuel.key, "fuel"
        window.wood[i] = slot
    end
    for _, spec in ipairs({ { -1, "<" }, { 1, ">" } }) do  -- the shelf's pages, if there are more ingredients than fit
        local arrow = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
        arrow:SetSize(26, 26)
        arrow:SetText(spec[2])
        Place(arrow, spec[1] * 385, LAYOUT.SHELF_Y)
        arrow:SetScript("OnClick", function()
            local dungeons = 0
            for _, entry in ipairs(ns.IngredientList()) do if entry.kind == "dungeon" then dungeons = dungeons + 1 end end
            page = math.max(0, math.min(math.floor((dungeons - 1) / LAYOUT.SLOTS), page + spec[1]))
            window:Refresh()
        end)
        window["arrow" .. (spec[1] < 0 and "Left" or "Right")] = arrow
    end

    -- The cauldron on its fire, the brew in it (a glow behind it while you drag something over it), the spoon.
    window.fire = window:CreateTexture(nil, "BACKGROUND", nil, 2)
    window.fire:SetTexture(KITCHEN .. "Fire")
    window.fireTint = window:CreateTexture(nil, "BACKGROUND", nil, 2)
    window.fireTint:SetTexture(KITCHEN .. "FireTint")
    window.fireTint:SetBlendMode("ADD")
    window.glow = window:CreateTexture(nil, "BACKGROUND", nil, 3)
    window.glow:SetTexture(FX .. "Glow")
    window.glow:SetBlendMode("ADD")
    window.glow:SetAlpha(0)
    window.pot = window:CreateTexture(nil, "ARTWORK", nil, 1)
    window.pot:SetTexture(KITCHEN .. "Cauldron")
    window.brew = window:CreateTexture(nil, "ARTWORK", nil, 2)
    window.brew:SetTexture(KITCHEN .. "Brew")
    window.over = CreateFrame("Frame", nil, window)  -- over the cauldron: the bits floating in it, bubbles, ripples, puff
    window.over:SetAllPoints()
    window.ripple = window.over:CreateTexture(nil, "OVERLAY", nil, 2)
    window.ripple:SetTexture(FX .. "Ring")
    window.ripple:SetBlendMode("ADD")
    window.ripple:Hide()
    window.puff = window.over:CreateTexture(nil, "OVERLAY", nil, 6)
    window.puff:SetTexture(KITCHEN .. "Puff")
    window.puff:Hide()
    window.dragIcon = window.over:CreateTexture(nil, "OVERLAY", nil, 7)
    window.dragIcon:SetSize(LAYOUT.SLOT * 1.15, LAYOUT.SLOT * 1.15)
    window.dragIcon:Hide()
    window.spoon = CreateFrame("Button", nil, window)
    window.spoon:SetSize(160, 160)
    window.spoon.art = window.spoon:CreateTexture(nil, "ARTWORK")
    window.spoon.art:SetAllPoints()
    window.spoon.art:SetTexture(KITCHEN .. "Spoon")
    window.spoon.glow = window.spoon:CreateTexture(nil, "BACKGROUND")
    window.spoon.glow:SetTexture(FX .. "Glow")
    window.spoon.glow:SetBlendMode("ADD")
    window.spoon.glow:SetVertexColor(1, 0.8, 0.3)
    window.spoon.glow:SetPoint("CENTER")
    window.spoon.glow:SetSize(220, 220)
    window.spoon.glow:SetAlpha(0)
    window.spoon:SetScript("OnEnter", function(self) ns.UI.Tooltip(self, { "Stir it!", ("Stir %d times and it's done."):format(LAYOUT.STIRS) }) end)
    window.spoon:SetScript("OnLeave", GameTooltip_Hide)
    window.spoon:SetScript("OnClick", function() window:Stir() end)

    -- The recipe card, with the price at its foot (right; the chef's on the left), the way back (a plank, like the
    -- chest show's).
    -- The recipe: a page from a cookbook, pinned to the wall, written in ink (no outline); it grows with what's on it.
    window.recipe = window:CreateFontString(nil, "OVERLAY")
    window.recipe:SetFont(NAME_FONT, 16, "")
    window.recipe:SetTextColor(0.24, 0.14, 0.07)
    window.recipe:SetPoint("TOPRIGHT", -40, -262)
    window.recipe:SetWidth(214)
    window.recipe:SetJustifyH("LEFT")
    window.recipe:SetSpacing(3)
    local heading = window:CreateFontString(nil, "OVERLAY")
    heading:SetFont(NAME_FONT, 21, "")
    heading:SetTextColor(0.5, 0.14, 0.08)
    heading:SetPoint("BOTTOMLEFT", window.recipe, "TOPLEFT", 0, 6)
    heading:SetText("Recipe")
    local paper = window:CreateTexture(nil, "BORDER")
    paper:SetTexture(KITCHEN .. "Paper")
    paper:SetPoint("TOPLEFT", heading, "TOPLEFT", -36, 16)  -- (the text right of the page's red margin)
    paper:SetPoint("BOTTOMRIGHT", window.recipe, "BOTTOMRIGHT", 26, -34)
    -- Over the card: its exact odds, in a tooltip (window.odds, from Refresh).
    local oddsHit = CreateFrame("Frame", nil, window)
    oddsHit:SetPoint("TOPLEFT", window.recipe, "TOPLEFT", -4, 4)
    oddsHit:SetPoint("BOTTOMRIGHT", window.recipe, "BOTTOMRIGHT", 4, -4)
    oddsHit:EnableMouse(true)
    oddsHit:SetScript("OnEnter", function(self) if window.odds then ns.UI.Tooltip(self, window.odds) end end)
    oddsHit:SetScript("OnLeave", GameTooltip_Hide)
    -- How full the cauldron and the fire are: a dot a place, filled as it fills (on the cauldron's belly; over the
    -- woodpile).
    local function Pips(count)
        local list = {}
        for i = 1, count do
            local ring = window.over:CreateTexture(nil, "OVERLAY", nil, 1)
            ring:SetTexture(KITCHEN .. "Bubble")
            ring.icon = window.over:CreateTexture(nil, "OVERLAY", nil, 2)
            list[i] = ring
        end
        return list
    end
    -- A place: at x, y, size big, holding key's icon (nil: empty, a pale ring).
    function window:FillPip(ring, x, y, size, key)
        ring:SetSize(size, size)
        Place(ring, x, y)
        ring:SetVertexColor(1, 0.93, 0.78)
        ring:SetAlpha(key and 1 or 0.45)
        ring:Show()
        ring.icon:SetShown(key ~= nil)
        if key then
            ring.icon:SetTexture(ns.IngredientIcon(key))
            ring.icon:SetSize(size * 0.78, size * 0.78)
            Place(ring.icon, x, y)
        end
    end
    window.potPips, window.firePips = Pips(12), Pips(3)
    -- The words an ingredient says as it goes in ("Deadmines+"), rising and fading.
    window.words = {}
    local back = CreateFrame("Button", nil, window)
    back:SetSize(150, 34)
    back.word = Text(back, 17, unpack(BUTTON_WORD))
    back.word:SetPoint("CENTER", 0, 1)
    back.word:SetText("Not now")
    ns.UI.SkinButton(back, { steady = true })
    back:SetPoint("BOTTOMRIGHT", -20, 18)
    back:SetScript("OnClick", function() ns.UI.ClickSound() window:Hide() end)

    -- The reveal's stage, over the kitchen (dimmed): the new photo, big, blank, its layers dripped on one by one as the
    -- reel under it lands on each.
    local stage = CreateFrame("Frame", nil, window)
    stage:SetAllPoints()
    stage:SetFrameLevel(window:GetFrameLevel() + 40)
    stage:EnableMouse(true)
    stage:Hide()
    stage.dim = stage:CreateTexture(nil, "BACKGROUND")
    stage.dim:SetAllPoints()
    stage.dim:SetColorTexture(0.03, 0.02, 0.02, 1)
    stage.big = CreateFrame("Frame", nil, stage)
    stage.big:SetSize(LAYOUT.BIG + 24, LAYOUT.BIG + 54)
    stage.big.paper = stage.big:CreateTexture(nil, "BACKGROUND")
    stage.big.paper:SetAllPoints()
    stage.big.paper:SetColorTexture(0.95, 0.92, 0.84)
    stage.big.peg = stage.big:CreateTexture(nil, "OVERLAY")
    stage.big.peg:SetTexture(KITCHEN .. "Peg")
    stage.big.peg:SetSize(40, 84)
    stage.big.peg:SetPoint("CENTER", stage.big, "TOP", 0, 6)
    stage.canvas = CreateFrame("Frame", nil, stage.big)
    stage.canvas:SetSize(LAYOUT.BIG, LAYOUT.BIG)
    stage.canvas:SetPoint("TOP", 0, -12)
    stage.canvas:SetClipsChildren(true)
    stage.masks = {}
    stage.fx = CreateFrame("Frame", nil, stage)  -- the drops and splats, over the photo
    stage.fx:SetAllPoints()
    stage.fx:SetFrameLevel(stage:GetFrameLevel() + 10)
    stage.title = Text(stage, 26, 1, 0.82, 0.25)
    stage.title:SetPoint("CENTER", stage, "TOP", 0, LAYOUT.REEL_Y + 52)
    stage.reel = ns.NewMintReel(stage, 400)  -- (clear of the chef, who watches from over the stage)
    stage.reel.frame:SetPoint("CENTER", stage, "TOP", 0, LAYOUT.REEL_Y)
    stage.result = Text(stage, 20, 1, 1, 1)
    stage.result:SetPoint("CENTER", stage, "TOP", 0, LAYOUT.REEL_Y - 50)
    stage.hint = Text(stage, 14, 0.75, 0.7, 0.6)
    stage.hint:SetPoint("BOTTOM", 0, 12)
    stage:SetScript("OnMouseDown", function() window:StageClick() end)
    window.stage = stage

    -- Motion: the tweens, the dragged ingredient, the bubbles rising, the bits bobbing, the spoon resting.
    window:SetScript("OnUpdate", function(self, dt)
        dt = math.min(dt, 0.05)
        clock = clock + dt
        self.stage.reel:Update(dt)
        for i = #tweens, 1, -1 do
            local tw = tweens[i]
            if tw then
                tw.t = tw.t + dt
                local p = math.min(1, tw.t / tw.d)
                tw.update(p)
                if p >= 1 then
                    table.remove(tweens, i)
                    if tw.done then tw.done() end
                end
            end
        end
        slosh = math.max(0, slosh - dt * 1.5)
        flare = math.max(0, flare - dt * 1.2)
        self.scene:Update(LAYOUT.POT_Y, potSize, 1 + math.sin(clock * 7) * 0.05 + math.sin(clock * 13) * 0.03 + flare * 0.2,
            FireColor() or { 1, 0.55, 0.2 })
        self.pot:SetSize(potSize * (2 - squash), potSize * squash)
        Place(self.pot, 0, LAYOUT.POT_Y - potSize * (1 - squash) / 2)
        local surface = Surface()
        local wobble = 1 + math.sin(clock * 11) * 0.03 * slosh
        self.brew:SetSize(potSize * 0.77 * (2 - squash) * wobble, potSize * 0.77 * squash / wobble)
        Place(self.brew, 0, surface)
        local fire = potSize * (0.72 + InPot(true) * 0.07 + flare * 0.3) * (1 + math.sin(clock * 9) * 0.025)
        self.fire:SetSize(fire, fire)
        self.fireTint:SetSize(fire, fire)
        Place(self.fire, 0, FireY() + fire * 0.06)
        Place(self.fireTint, 0, FireY() + fire * 0.06)
        local fireColor = FireColor()
        self.fireTint:SetShown(fireColor ~= nil)
        if fireColor then self.fireTint:SetVertexColor(fireColor[1], fireColor[2], fireColor[3]) end
        self.fire:SetAlpha(fireColor and 0.35 or 1)
        local target = BrewColor()
        for k = 1, 3 do brewShown[k] = brewShown[k] + (target[k] - brewShown[k]) * math.min(1, dt * 2.5) end
        self.brew:SetVertexColor(brewShown[1], brewShown[2], brewShown[3])
        if drag then
            local x, y = CursorPos()
            Place(self.dragIcon, x, y)
            local over = drag.kind == "fuel" and (OverFire(x, y) or OverPot(x, y)) or OverPot(x, y)
            self.glow:SetAlpha(over and 0.55 + math.sin(clock * 8) * 0.15 or 0)
        end
        -- Bubbles: more, the fuller the pot (and while stirring).
        bubbleTimer = bubbleTimer - dt
        if bubbleTimer <= 0 then
            bubbleTimer = 0.5 / (1 + InPot() * 0.6 + (stirring and 6 or 0))
            Bubble((math.random() - 0.5) * potSize * 0.55, surface, 10 + math.random() * 16, 0.9 + math.random() * 0.6, BrewColor())
        end
        for i = #live, 1, -1 do
            local b = live[i]
            b.age = b.age + dt
            b.y = b.y + dt * 60
            b.tex:SetSize(b.size * (1 + b.age), b.size * (1 + b.age))
            Place(b.tex, b.x + math.sin(b.age * 6 + b.x) * 6, b.y)
            b.tex:SetAlpha(math.max(0, 1 - b.age / b.life))
            if b.age >= b.life then
                b.tex:Hide()
                bubbles[#bubbles + 1] = b.tex
                table.remove(live, i)
            end
        end
        -- The bits floating in the brew, half under, bobbing.
        local n = #bits
        for i, bit in ipairs(bits) do
            -- Spread over the brew; stirring turns them round it (on the same flat circle as the spoon).
            local x = (i - (n + 1) / 2) * math.min(30, potSize * 0.55 / math.max(1, n))
            local r, a = math.abs(x), (x < 0 and math.pi or 0) + swirl
            Place(bit, r * math.cos(a) + math.sin(clock * 1.3 + i * 2) * 3, surface - 4 + r * math.sin(a) * 0.15
                + math.sin(clock * 2.5 + i) * 3, "BOTTOM")
        end
        if not stirring then  -- the spoon, resting in the pot, swaying a little
            self.spoon:ClearAllPoints()
            self.spoon:SetPoint("CENTER", self, "TOP", potSize * 0.32, surface + 58 + math.sin(clock * 1.2) * 3)
        end
        -- The chef, breathing (and hopping when it speaks), its words fading; the photos swaying on their pegs.
        self.hop = math.max(0, (self.hop or 0) - dt)
        local hop = math.sin(math.min(1, (self.hop or 0) / 0.3) * math.pi) * 14
        Place(self.chef, LAYOUT.CHEF_X, LAYOUT.CHEF_Y + math.sin(clock * 1.6) * 3 + hop)
        self.saying = math.max(0, (self.saying or 0) - dt)
        self.nag = (self.nag or 2) - dt
        if self.nag <= 0 then self:Nag() end
        -- The spoon: glowing and wiggling once there's something in to stir.
        local ready = not stirring and not self.reveal and InPot() + InPot(true) > 0
        self.spoon.glow:SetAlpha(ready and 0.45 + math.sin(clock * 4) * 0.25 or 0)
        if not stirring then self.spoon.art:SetRotation(ready and math.sin(clock * 6) * 0.06 or 0) end
        self.speech:SetAlpha(math.min(1, self.saying * 3))
        Place(self.speech, LAYOUT.CHEF_X + 125, LAYOUT.CHEF_Y + LAYOUT.CHEF_SIZE * 0.5 + 40 + hop)
        for _, photo in ipairs(self.photos) do
            if photo:IsShown() and photo.x and not photo.flying then
                photo.swing = math.max(0.15, (photo.swing or 0.15) - dt * 0.4)
                local sway = math.sin(clock * 2.2 + photo.x * 0.05) * 3 * photo.swing
                Place(photo, photo.x + sway, photo.y, "TOP")
            end
        end
    end)

    -- The chef says something (ogre words: ALL CAPS, at most 5 letters each), for seconds (default 1.5), and hops. The
    -- bubble fits the words.
    function window:Say(words, seconds)
        local word = self.speech.word
        word:SetWidth(150)
        word:SetText(words)
        local w = math.min(150, word:GetStringWidth() or 60)
        word:SetWidth(w + 4)
        self.speech:SetSize(math.max(96, w + 56), math.max(80, (word:GetStringHeight() or 24) + 58))
        self.saying, self.hop = seconds or 1.5, 0.3
        self.nag = math.max(self.nag or 0, (seconds or 1.5) + 1)
    end
    -- What the chef says when nothing's happening: how it's done while the pot's empty, else to stir.
    local HOWTO = { "DRAG STUFF IN POT!", "WOOD IN FIRE!", "THEN STIR!" }
    function window:Nag()
        if stirring or self.reveal or drag then self.nag = 2 return end
        if InPot() + InPot(true) == 0 then
            self.howto = (self.howto or 0) % #HOWTO + 1
            self:Say(HOWTO[self.howto], 2.4)
            self.nag = self.howto == #HOWTO and 7 or 2.8
        else
            self:Say("STIR IT!", 2)
            self.nag = 9
        end
    end
    -- The rope's height at x (it sags in the middle).
    local function RopeY(x) return LAYOUT.ROPE_Y + 18 - 28 * (1 - (x / (LAYOUT.ROPE_W / 2)) ^ 2) end
    -- Pegs your newest pictures on the line, newest first (leftmost). Returns the newest's photo.
    function window:HangPhotos()
        Place(self.rope, 0, LAYOUT.ROPE_Y)
        local mints = {}
        for _, mint in ipairs(KillTrackerDB.mints or {}) do mints[#mints + 1] = mint end
        table.sort(mints, function(a, b) return a.number > b.number end)
        local count = math.min(LAYOUT.PHOTOS, #mints)
        for i, photo in ipairs(self.photos) do
            local mint = i <= count and mints[i]
            photo:SetShown(mint and true or false)
            if mint then
                photo.x = (i - (count + 1) / 2) * (LAYOUT.PHOTO_W + 34)
                photo.y = RopeY(photo.x) - 4
                photo.flying = nil
                photo.dark:SetAlpha(0)
                photo.canvas:SetAlpha(1)
                ns.DrawMint(photo.canvas, mint)
                Place(photo, photo.x, photo.y, "TOP")
            end
        end
        return count > 0 and self.photos[1] or nil
    end
    -- Dresses the chef: your Overview photo's ogre (else your newest picture's, else a plain one), its own hat off.
    function window:DressChef()
        local card = KillTrackerDB.card
        local mint = card and card.portrait and ns.FindMint(nil, card.portrait) or ns.NewestMint()
        local traits = {}
        if mint then
            for key, id in pairs(mint.traits) do traits[key] = id end
        else
            for _, layer in ipairs(ns.MintLayers) do
                for _, option in ipairs(layer.options) do
                    if not option.unlock then traits[layer.key] = option.id break end
                end
            end
        end
        traits.background, traits.headwear = nil, nil
        ns.DrawMint(self.chef, { traits = traits, style = mint and mint.style })
    end

    -- An ingredient going into the brew, at x: it sinks under the surface (cut off at it, taking on the brew's colour),
    -- the brew ripples and splashes, the cauldron gulps, and it floats there.
    function window:Sink(key, tex, x)
        local surface = Surface()
        x = math.max(-potSize * 0.24, math.min(potSize * 0.24, x))
        Sound("LOOT_WINDOW_COIN_SOUND")
        local col = COLORS[key] or MURKY
        self:Say(({ "YUM!", "MMM!", "GOOD!", "TASTY" })[math.random(4)])
        self:Float(key, x, surface + 40)
        brewShown[1], brewShown[2], brewShown[3] = col[1], col[2], col[3]
        for _ = 1, 7 do Bubble(x + (math.random() - 0.5) * 60, surface, 12 + math.random() * 14, 0.45, COLORS[key] or MURKY) end
        self.ripple:SetVertexColor(unpack(COLORS[key] or MURKY))
        self.ripple:Show()
        Tween(0.7, function(p)
            local w = 20 + EaseOut(p) * potSize * 0.6
            self.ripple:SetSize(w, w * 0.35)
            Place(self.ripple, x, surface)
            self.ripple:SetAlpha((1 - p) * 0.9)
        end, function() self.ripple:Hide() end)
        local size, brew = LAYOUT.SLOT * 0.8, col
        tex:SetSize(size, size)
        Tween(0.55, function(p)
            local left = 1 - p
            tex:SetTexCoord(0, 1, 0, left)
            tex:SetSize(size, math.max(0.5, size * left))
            Place(tex, x + math.sin(p * 18) * 3 * left, surface - 2, "BOTTOM")
            tex:SetVertexColor(1 - (1 - brew[1]) * p, 1 - (1 - brew[2]) * p, 1 - (1 - brew[3]) * p)
        end, function()
            tex:Hide()
            tex:SetTexCoord(0, 1, 0, 1)
            tex:SetVertexColor(1, 1, 1)
            local bit = self.over:CreateTexture(nil, "OVERLAY", nil, 4)
            bit:SetTexture(ns.IngredientIcon(key))
            bit:SetTexCoord(0, 1, 0, 0.6)
            bit:SetSize(34, 34 * 0.6)
            bit.key = key
            bits[#bits + 1] = bit
            self:Refresh()
        end)
        Tween(0.35, function(p)  -- the gulp: the cauldron squashes, the brew with it, and sloshes after
            squash = 1 - math.sin(p * math.pi) * 0.06
        end, function() squash, slosh = 1, 1 end)
    end
    -- What it does, in a word rising out of where it went in ("Deadmines+", "Headwear+", "Epic+").
    function window:Float(key, x, y)
        local word, color = EffectWord(key)
        local text = table.remove(self.words) or Text(self.over, 24, 1, 1, 1)
        text:SetText(word .. "+")
        text:SetTextColor(color[1], color[2], color[3])
        text:Show()
        Tween(1.3, function(p)
            Place(text, x, y + EaseOut(p) * 70)
            text:SetAlpha(p < 0.6 and 1 or (1 - p) / 0.4)
        end, function()
            text:Hide()
            self.words[#self.words + 1] = text
        end)
    end
    -- A fuel going into the fire, at x: it shrinks into the flames, which flare up in its colour, with sparks.
    function window:Burn(key, tex, x)
        local fuel = ns.Fuel(key)
        x = math.max(-60, math.min(60, x))
        Sound("LOOT_WINDOW_COIN_SOUND")
        self:Say(({ "HOT!", "FIRE!", "OOH!" })[math.random(3)])
        local from = FireY() + 10
        Tween(0.45, function(p)
            local size = LAYOUT.SLOT * 0.8 * (1 - p)
            tex:SetSize(math.max(0.5, size), math.max(0.5, size))
            Place(tex, x * (1 - p), from - p * 20)
        end, function()
            tex:Hide()
            flare = 1
            self:Float(key, x, FireY() + 60)
            for _ = 1, 10 do Bubble((math.random() - 0.5) * 120, FireY() + 30, 6 + math.random() * 8, 0.8, fuel and fuel.color or { 1, 0.6, 0.2 }) end
            self:Refresh()
        end)
    end
    -- Whether one more of an ingredient can go in; says why not, if not.
    function window:CanAdd(key)
        local cauldron = ns.Cauldron()
        if IsFuel(key) then
            if InPot(true) >= ns.FIRE_SLOTS then
                self:Say("FIRE FULL!", 2)
                return false
            end
            return (pot[key] or 0) < ns.Tokens(key)
        end
        if InPot() >= cauldron.slots then
            self:Say("POT FULL! BIG POT LATER", 2.5)  -- (a bigger cauldron comes with your Ogre Rank)
            return false
        end
        return (pot[key] or 0) < ns.Tokens(key)
    end
    -- Click: thrown in, in an arc off the shelf.
    function window:Throw(slot)
        local key = slot.key
        if not self:CanAdd(key) then return end
        pot[key] = (pot[key] or 0) + 1
        ns.UI.ClickSound()
        local fly = self.over:CreateTexture(nil, "OVERLAY", nil, 5)
        fly:SetTexture(ns.IngredientIcon(key))
        fly:SetSize(LAYOUT.SLOT, LAYOUT.SLOT)
        local fuel = IsFuel(key)
        local toX, toY = (math.random() - 0.5) * potSize * 0.3, fuel and FireY() + 10 or Surface() + 30
        Tween(0.45, function(p)
            local e = EaseOut(p)
            Place(fly, slot.x + (toX - slot.x) * e, slot.y + (toY - slot.y) * e + math.sin(p * math.pi) * 110)
        end, function()
            if fuel then self:Burn(key, fly, toX) else self:Sink(key, fly, toX) end
        end)
        self:Refresh()
    end
    -- Drag: the ingredient comes off the shelf on the cursor; let go over the cauldron and in it goes, else it goes back.
    function window:StartDrag(slot)
        if not slot.key or stirring or (pot[slot.key] or 0) >= ns.Tokens(slot.key) then return end
        GameTooltip_Hide()
        drag = slot
        self.dragIcon:SetTexture(ns.IngredientIcon(slot.key))
        self.dragIcon:SetSize(slot.size * 1.2, slot.size * 1.2)
        self.dragIcon:SetAlpha(1)
        self.dragIcon:Show()
        self.glow:SetVertexColor(unpack(COLORS[slot.key] or MURKY))
        Sound("IG_ABILITY_ICON_PICKUP")
    end
    function window:StopDrag()
        local slot = drag
        if not slot then return end
        drag = nil
        self.glow:SetAlpha(0)
        local x, y = CursorPos()
        local icon = self.dragIcon
        local key = slot.key
        local fly = self.over:CreateTexture(nil, "OVERLAY", nil, 5)
        fly:SetTexture(ns.IngredientIcon(key))
        fly:SetSize(LAYOUT.SLOT, LAYOUT.SLOT)
        icon:Hide()
        local fuel = slot.kind == "fuel"
        if (OverPot(x, y) or (fuel and OverFire(x, y))) and self:CanAdd(key) then
            pot[key] = (pot[key] or 0) + 1
            self:Refresh()
            local toY = fuel and FireY() + 10 or Surface() + 30
            Tween(0.18, function(p)  -- drops in from where you let go
                Place(fly, x, y + (toY - y) * p * p)
            end, function()
                if fuel then self:Burn(key, fly, x) else self:Sink(key, fly, x) end
            end)
        else  -- back onto the shelf
            self:Say("NO?")
            Tween(0.25, function(p)
                local e = EaseOut(p)
                Place(fly, x + (slot.x - x) * e, y + (slot.y - y) * e)
            end, function() fly:Hide() end)
        end
    end
    -- Takes one of an ingredient back out of the pot.
    function window:TakeOut(key)
        if (pot[key] or 0) == 0 then return end
        pot[key] = pot[key] - 1
        if pot[key] == 0 then pot[key] = nil end
        for i = #bits, 1, -1 do
            if bits[i].key == key then
                bits[i]:Hide()
                table.remove(bits, i)
                break
            end
        end
        self:Refresh()
    end
    function window:SlotMenu(slot)
        local key = slot.key
        if not MenuUtil or slot.kind ~= "dungeon" then return self:TakeOut(key) end
        local d = ns.DungeonByKey(key) or { name = key }
        MenuUtil.CreateContextMenu(slot, function(_, root)
            root:CreateTitle(ns.IngredientName(key))
            local out = root:CreateButton("Take one out of the pot", function() self:TakeOut(key) end)
            if (pot[key] or 0) == 0 then out:SetEnabled(false) end
            local missing = ns.MissingPieces(key)
            local buy = root:CreateButton(("Buy a piece of %s (%d)"):format(d.name, ns.TOKEN_SHOP_PRICE))
            for _, unlocked in ipairs(missing) do
                local option = unlocked.option
                buy:CreateButton(("|c%s%s|r (%s)"):format(ns.RARITY_COLORS[option.rarity] or "ffffffff", option.name, unlocked.layer.name:lower()), function()
                    local ok, why = ns.BuyPiece(key, ns.OptionKey(unlocked.layer.key, option))
                    if not ok then ns.Print(why) end
                    while (pot[key] or 0) > ns.Tokens(key) do self:TakeOut(key) end  -- (spent on it)
                    self:Refresh()
                end)
            end
            if #missing == 0 then buy:CreateTitle("You have every piece of it.")
            elseif ns.Tokens(key) < ns.TOKEN_SHOP_PRICE then buy:SetEnabled(false) end
        end)
    end
    -- A stir: the spoon goes round, the brew swirls, the fire flares; the last one: POOF, and the mint.
    function window:Stir()
        if stirring then return end
        local points, cost = ns.GetPoints().balance, ns.MintCost(pot)
        if points < cost then
            self:Say("NEED MORE COIN", 2.5)
            return
        end
        stirs = stirs + 1
        stirring = true
        ns.UI.ClickSound()
        local surface = Surface()
        Tween(0.8, function(p)
            -- Round the pot on a flat circle (seen from the side: left and right, a little back and forth), the handle
            -- leaning the way it goes; the bits floating in the brew swirl along.
            local a = (p * p * (3 - 2 * p)) * 2 * math.pi
            self.spoon:ClearAllPoints()
            self.spoon:SetPoint("CENTER", self, "TOP", potSize * 0.32 * math.cos(a), surface + 58 + math.sin(a) * 5)
            self.spoon.art:SetRotation(-math.sin(a) * 0.25)
            swirl = swirl + (a - (self.lastA or 0))
            self.lastA = p >= 1 and 0 or a
            flare = math.max(flare, math.sin(p * math.pi) * 0.8)
        end, function()
            if stirs < LAYOUT.STIRS then
                stirring = false
                self:Say(({ "STIR!", "MORE!" })[stirs] or "STIR!")
                return
            end
            self:Poof()
        end)
    end
    function window:Poof()
        self:Say("BOOM!")
        self.puff:SetVertexColor(unpack(BrewColor()))
        self.puff:Show()
        Sound("LOOT_WINDOW_COIN_SOUND")
        Tween(0.6, function(p)
            local s = potSize * (0.4 + EaseOut(p) * 1.6)
            self.puff:SetSize(s, s)
            Place(self.puff, 0, LAYOUT.POT_Y + potSize * 0.2 + p * 60)
            self.puff:SetAlpha(1 - p * 0.6)
        end, function() self:Develop() end)
    end
    -- The mint: the photo comes up out of the brew, gets pegged on the line, dark, and develops; then the reel shows it
    -- off (MintReel.lua).
    function window:Develop()
        local tokens = {}
        for key, n in pairs(pot) do if n > 0 then tokens[key] = n end end
        local mint, reason = ns.Mint(next(tokens) and tokens or nil)
        self.puff:Hide()
        if not mint then
            ns.Print(reason)
            self:Say("HUH?")
            stirs, stirring = 0, false
            return
        end
        wipe(pot)
        for _, bit in ipairs(bits) do bit:Hide() end
        wipe(bits)
        self:Refresh()
        self:Say("LOOK!")
        local photo = self:HangPhotos()
        if not photo then
            stirring = false
            return ns.PlayMintReel(mint)
        end
        -- Up out of the brew onto the line, blank.
        photo.flying = true
        photo.canvas:SetAlpha(0)
        local fromY = Surface()
        Tween(0.7, function(p)
            local e = EaseOut(p)
            Place(photo, photo.x * e, fromY + (photo.y - fromY) * e + math.sin(p * math.pi) * 60, "TOP")
        end, function()
            photo.flying, photo.swing = nil, 1
            Sound("LOOT_WINDOW_COIN_SOUND")
            self:Reveal(mint, photo)
        end)
    end

    -- The reveal -----------------------------------------------------------------------------------------------------

    -- The big photo, at scale s with its middle at x, y (from the window's top middle).
    local function PlaceBig(s, x, y)
        local big = window.stage.big
        big:SetScale(s)
        big:ClearAllPoints()
        big:SetPoint("CENTER", window, "TOP", x / s, y / s)
    end
    -- Zooms in on the new photo (from its place on the line), blank; then each layer: the reel lands on it and a drop of
    -- the brew, its rarity's colour, falls on the photo and splashes it on.
    function window:Reveal(mint, photo)
        local stage = self.stage
        local reveal = { mint = mint, photo = photo, order = ns.MintRevealOrder(), step = 0, shown = {} }
        self.reveal = reveal
        -- The whole picture drawn, every layer hidden until its drop.
        ns.RenderMint(stage.canvas, mint.traits, nil, mint.style)
        for i, tex in ipairs(stage.canvas.layers or {}) do
            reveal.shown[i] = tex:IsShown()
            tex:Hide()
        end
        reveal.front = stage.canvas.front and stage.canvas.front:IsShown()
        if stage.canvas.front then stage.canvas.front:Hide() end
        stage.title:SetText("")
        stage.result:SetText("")
        stage.hint:SetText("Click to skip")
        stage.reel.frame:SetAlpha(0)
        stage.dim:SetAlpha(0)
        stage:Show()
        local from = (LAYOUT.PHOTO_W) / (LAYOUT.BIG + 24)
        local fromX, fromY = photo.x, photo.y - LAYOUT.PHOTO_H / 2
        PlaceBig(from, fromX, fromY)
        Tween(0.8, function(p)
            local e = p * p * (3 - 2 * p)
            PlaceBig(from + (1 - from) * e, fromX * (1 - e), fromY + (LAYOUT.BIG_Y - fromY) * e)
            stage.dim:SetAlpha(0.85 * e)
        end, function()
            Tween(0.3, function(p) stage.reel.frame:SetAlpha(p) end)
            self:NextLayer()
        end)
    end
    function window:NextLayer()
        local reveal = self.reveal
        if not reveal or reveal.done then return end
        reveal.step = reveal.step + 1
        local key = reveal.order[reveal.step]
        if not key then return self:RevealDone() end
        local layer = ns.MintLayerByKey(key)
        local winner
        for _, option in ipairs(layer.options) do
            if option.id == reveal.mint.traits[key] then winner = option end
        end
        if not winner then return self:NextLayer() end
        self.stage.title:SetText(layer.name)
        self.stage.result:SetText("")
        self.stage.reel:Spin(layer, winner, reveal.mint.traits, function() self:Drip(layer, winner) end)
    end
    -- A drop of the brew, the winner's rarity's colour, falls onto the photo and splashes: the layer spreads out from where
    -- it lands (a round mask, growing), tinted at first, and drips run down the paper.
    function window:Drip(layer, option)
        local stage, reveal = self.stage, self.reveal
        local r, g, b = ns.RarityRGB(option.rarity)
        stage.result:SetText(("|c%s%s|r"):format(ns.RARITY_COLORS[option.rarity] or "ffffffff", option.name))
        local hitX, hitY = (math.random() - 0.5) * LAYOUT.BIG * 0.4, (math.random() - 0.5) * LAYOUT.BIG * 0.3  -- from the photo's middle
        local centerY = LAYOUT.BIG_Y + 15  -- (the picture's middle: the paper's, a little up)
        local drop = stage.fx.drop or stage.fx:CreateTexture(nil, "OVERLAY", nil, 5)
        stage.fx.drop = drop
        drop:SetTexture(KITCHEN .. "Drop")
        drop:SetVertexColor(r, g, b)
        drop:SetSize(34, 34)
        drop:SetAlpha(1)
        drop:Show()
        Sound("IG_MAINMENU_OPTION_CHECKBOX_ON")
        Tween(0.35, function(p)
            Place(drop, hitX, -10 + (centerY + hitY + 10) * p * p)
        end, function()
            drop:Hide()
            Sound(({ uncommon = "LOOT_WINDOW_COIN_SOUND", rare = "UI_EPICLOOT_TOAST", epic = "UI_EPICLOOT_TOAST", legendary = "UI_LEGENDARY_LOOT_TOAST" })[option.rarity] or "LOOT_WINDOW_COIN_SOUND")
            self:Say(OGRE_RARITY[option.rarity] or "OK!")
            -- The splat.
            local splat = stage.fx.splat or stage.fx:CreateTexture(nil, "OVERLAY", nil, 4)
            stage.fx.splat = splat
            splat:SetTexture(KITCHEN .. "Splat")
            splat:SetVertexColor(r, g, b)
            splat:Show()
            Tween(0.5, function(p)
                local s = 30 + EaseOut(p) * 120
                splat:SetSize(s, s)
                Place(splat, hitX, centerY + hitY)
                splat:SetAlpha(0.9 * (1 - p))
            end, function() splat:Hide() end)
            -- The drips running down.
            for k = 1, 3 do
                stage.fx.drips = stage.fx.drips or {}
                local drip = table.remove(stage.fx.drips) or stage.fx:CreateTexture(nil, "OVERLAY", nil, 3)
                drip:Show()
                drip:SetTexture(KITCHEN .. "Drop")
                drip:SetVertexColor(r, g, b)
                drip:SetSize(10, 14)
                local dx, run = hitX + (k - 2) * 26 + (math.random() - 0.5) * 10, 40 + math.random() * 60
                Tween(1.2 + k * 0.15, function(p)
                    Place(drip, dx, centerY + hitY - EaseOut(p) * run)
                    drip:SetAlpha(1 - p)
                end, function()
                    drip:Hide()
                    table.insert(stage.fx.drips, drip)
                end)
            end
            -- The layer, spreading out from the splash.
            local index
            for i, l in ipairs(ns.MintLayers) do if l == layer then index = i end end
            local textures = {}
            if index and reveal.shown[index] then textures[#textures + 1] = stage.canvas.layers[index] end
            if layer.key == "skin" and reveal.front then textures[#textures + 1] = stage.canvas.front end
            local mask = stage.masks[index or 0] or stage.canvas:CreateMaskTexture()
            stage.masks[index or 0] = mask
            mask:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            mask:ClearAllPoints()
            mask:SetPoint("CENTER", stage.canvas, "CENTER", hitX, hitY)
            for _, tex in ipairs(textures) do
                tex:AddMaskTexture(mask)
                tex:Show()
            end
            local tint = not option.color
            Tween(0.75, function(p)
                local s = math.max(1, EaseOut(p) * LAYOUT.BIG * 3)
                mask:SetSize(s, s)
                if tint then
                    for _, tex in ipairs(textures) do tex:SetVertexColor(r + (1 - r) * p, g + (1 - g) * p, b + (1 - b) * p) end
                end
            end, function()
                for _, tex in ipairs(textures) do
                    tex:RemoveMaskTexture(mask)
                    if tint then tex:SetVertexColor(1, 1, 1) end
                end
                Tween(0.35, function() end, function() self:NextLayer() end)
            end)
        end)
    end
    -- Every layer on: the picture's rarity, the toast; a click puts it back on the line.
    function window:RevealDone()
        local reveal = self.reveal
        if not reveal or reveal.done then return end
        reveal.done = true
        local mint = reveal.mint
        self.stage.reel:Stop()
        local rarity = ns.MintRarity(mint.traits)
        local Rarity = rarity:gsub("^%l", string.upper)
        local big = rarity == "legendary" or rarity == "epic"
        ns.ShowToast(big and "achievement" or "record", "Minted!", ("Picture #%d"):format(mint.number), Rarity)
        self.stage.title:SetText(("Picture #%d"):format(mint.number))
        self.stage.result:SetText(("|c%s%s|r"):format(ns.RARITY_COLORS[rarity] or "ffffffff", Rarity))
        self.stage.hint:SetText("Click to hang it on the line")
        self:Say(OGRE_RARITY[rarity] or "PIX!")
        if ns.OnKillsChanged then ns.OnKillsChanged() end
    end
    -- Skip: every layer on at once. Done: back onto the line, and the kitchen's ready for another.
    function window:StageClick()
        local reveal, stage = self.reveal, self.stage
        if not reveal then return end
        if not reveal.done then
            if reveal.step == 0 then return end  -- (still zooming in)
            wipe(tweens)
            stage.reel:Stop()
            if stage.fx.drop then stage.fx.drop:Hide() end
            if stage.fx.splat then stage.fx.splat:Hide() end
            for i, tex in ipairs(stage.canvas.layers or {}) do
                if stage.masks[i] then tex:RemoveMaskTexture(stage.masks[i]) end
                tex:SetShown(reveal.shown[i])
            end
            if stage.canvas.front then stage.canvas.front:SetShown(reveal.front) end
            ns.RenderMint(stage.canvas, reveal.mint.traits, nil, reveal.mint.style)  -- (the colours, as they should be)
            return self:RevealDone()
        end
        if reveal.leaving then return end
        reveal.leaving = true
        local photo = reveal.photo
        local to = LAYOUT.PHOTO_W / (LAYOUT.BIG + 24)
        local toX, toY = photo.x, photo.y - LAYOUT.PHOTO_H / 2
        stage.hint:SetText("")
        Tween(0.6, function(p)
            local e = p * p * (3 - 2 * p)
            PlaceBig(1 + (to - 1) * e, toX * e, LAYOUT.BIG_Y + (toY - LAYOUT.BIG_Y) * e)
            stage.dim:SetAlpha(0.85 * (1 - e))
            stage.reel.frame:SetAlpha(1 - e)
            stage.title:SetAlpha(1 - e)
            stage.result:SetAlpha(1 - e)
        end, function()
            stage:Hide()
            stage.title:SetAlpha(1)
            stage.result:SetAlpha(1)
            photo.canvas:SetAlpha(1)
            photo.swing = 1
            self.reveal = nil
            stirs, stirring = 0, false
            self:Say("MORE?")
            self:Refresh()
        end)
    end

    function window:FillSlot(slot, count)
        slot.icon:SetTexture(ns.IngredientIcon(slot.key))
        local left = count - (pot[slot.key] or 0)
        slot.count:SetText(("x%d"):format(left))
        slot.icon:SetDesaturated(left <= 0)
        slot.icon:SetAlpha(count > 0 and 1 or 0.4)
        slot.used:SetText((pot[slot.key] or 0) > 0 and ("+" .. pot[slot.key]) or "")
    end
    function window:Refresh()
        local cauldron = ns.Cauldron()
        potSize = LAYOUT.POT_SIZE * cauldron.size
        self.glow:SetSize(potSize * 1.3, potSize * 1.3)
        Place(self.glow, 0, LAYOUT.POT_Y)
        -- The spice rack and the woodpile (always all of them).
        for _, slot in ipairs(self.rack) do self:FillSlot(slot, ns.Tokens(slot.key)) end
        for _, slot in ipairs(self.wood) do self:FillSlot(slot, ns.Tokens(slot.key)) end
        -- The pantry shelf: the dungeons' you have.
        local list = {}
        for _, entry in ipairs(ns.IngredientList()) do
            if entry.kind == "dungeon" then list[#list + 1] = entry end
        end
        page = math.max(0, math.min(page, math.floor(math.max(0, #list - 1) / LAYOUT.SLOTS)))
        for i, slot in ipairs(self.slots) do
            local entry = list[page * LAYOUT.SLOTS + i]
            slot:SetShown(entry ~= nil)
            if entry then
                slot.key, slot.kind = entry.key, entry.kind
                self:FillSlot(slot, entry.count)
            end
        end
        self.arrowLeft:SetShown(#list > LAYOUT.SLOTS)
        self.arrowRight:SetShown(#list > LAYOUT.SLOTS)

        -- How full: the cauldron's places on its belly, the fire's over the woodpile (each fuel in its colour).
        local total, fire = InPot(), InPot(true)
        local inPot, inFire = {}, {}
        for _, entry in ipairs(ns.IngredientList()) do
            for _ = 1, pot[entry.key] or 0 do
                local list = entry.kind == "fuel" and inFire or inPot
                list[#list + 1] = entry.key
            end
        end
        local step = math.min(26, potSize * 0.78 / cauldron.slots)
        for i, ring in ipairs(self.potPips) do
            if i <= cauldron.slots then
                self:FillPip(ring, (i - (cauldron.slots + 1) / 2) * step, LAYOUT.POT_Y - potSize * 0.14, step - 2, inPot[i])
            else
                ring:Hide()
                ring.icon:Hide()
            end
        end
        for i, ring in ipairs(self.firePips) do
            self:FillPip(ring, LAYOUT.WOOD_X + (i - (#self.firePips + 1) / 2) * 30, LAYOUT.WOOD_Y + 40, 26, inFire[i])
        end

        -- The recipe card, simply: what's in, by what it does ("Deadmines ++", "Headwear +", "Epic +"); the exact odds
        -- (each piece it aims at, with its chance and without; how much rarer it makes the layers) in its tooltip.
        local card = { ("|cff7a2a10%s|r  %d/%d"):format(cauldron.name, total, cauldron.slots),
            ("|cff7a2a10Fire|r  %d/%d"):format(fire, ns.FIRE_SLOTS), " " }
        for _, entry in ipairs(ns.IngredientList()) do
            local n = pot[entry.key] or 0
            if n > 0 then
                local word, color = EffectWord(entry.key, true)
                card[#card + 1] = ("|cff%02x%02x%02x%s|r %s"):format(math.floor(color[1] * 255 + 0.5),
                    math.floor(color[2] * 255 + 0.5), math.floor(color[3] * 255 + 0.5), word,
                    n > 5 and ("+" .. n) or string.rep("+", n))
            end
        end
        if #card == 3 then
            card[#card + 1] = "Nothing in yet: every part rolls as usual."
            card[#card + 1] = "|cff8a7660Dungeons pull their pieces, spices aim at a part, fuel makes it rarer.|r"
        else
            card[#card + 1] = "|cff8a7660(hover for the exact odds)|r"
        end
        -- The price, at the page's foot.
        local points, cost, plain = ns.GetPoints().balance, ns.MintCost(pot), ns.MintCost()
        card[#card + 1] = " "
        card[#card + 1] = ("|cff7a2a10Price|r  %d points%s"):format(cost, cost > plain and (" |cff8a7660(%d + ingredients)|r"):format(plain) or "")
        card[#card + 1] = ("You have |c%s%d|r"):format(points >= cost and "ff2a7a2a" or "ffaa2020", points)
        self.recipe:SetText(table.concat(card, "\n"))
        local lines = { "Exact odds" }
        local plan = ns.PotPlan(pot)
        local targets, rarer, everyLayer = {}, {}, true
        -- How rare "rarer" is: from the fire's commonest fuel (rare, without any: the layer ingredients make rare and up likelier).
        local floor = "rare"
        for i = #ns.FUELS, 1, -1 do
            if (pot[ns.FUELS[i].key] or 0) > 0 then floor = ns.FUELS[i].rarity end
        end
        local floorName = floor == "legendary" and "legendary" or floor .. "+"
        for _, layer in ipairs(ns.MintLayers) do
            local entry = plan[layer.key]
            if entry.total > 0 or entry.boosted then
                local odds, before = ns.LayerOdds(layer, entry), ns.LayerOdds(layer)
                for option, p in pairs(odds) do
                    local dungeon = option.unlock and option.unlock:match("^clear:(.+)")
                    if dungeon and entry.dungeons[dungeon] then
                        targets[#targets + 1] = { option = option, p = p, was = before[option] or 0 }
                    end
                end
                if entry.boosted then
                    local now, was = 0, 0
                    for option, p in pairs(odds) do if RANK[option.rarity] >= RANK[floor] then now = now + p end end
                    for option, p in pairs(before) do if RANK[option.rarity] >= RANK[floor] then was = was + p end end
                    rarer[#rarer + 1] = { layer = layer, now = now, was = was }
                end
            end
            if not entry.boosted then everyLayer = false end
        end
        table.sort(targets, function(a, b) return a.p > b.p end)
        local function Pct(p) return math.floor(p * 100 + 0.5) end
        for i = 1, math.min(5, #targets) do
            local t = targets[i]
            lines[#lines + 1] = ("|c%s%s|r: |cff55dd55%d%%|r |cff999999(was %d%%)|r"):format(ns.RARITY_COLORS[t.option.rarity] or "ffffffff",
                t.option.name, Pct(t.p), Pct(t.was))
        end
        if #targets > 5 then lines[#lines + 1] = ("|cff999999and %d more|r"):format(#targets - 5) end
        if everyLayer and #rarer > 0 then
            lines[#lines + 1] = ("Rarer everywhere: %s %d%% to |cff55dd55%d%%|r"):format(floorName, Pct(rarer[1].was), Pct(rarer[1].now))
        else
            for _, r in ipairs(rarer) do
                lines[#lines + 1] = ("Rarer %s: %s %d%% to |cff55dd55%d%%|r"):format(r.layer.name:lower(), floorName, Pct(r.was), Pct(r.now))
            end
        end
        if total == 0 and InPot(true) == 0 then
            lines[#lines + 1] = "Empty: every layer rolls as usual."
            lines[#lines + 1] = "Dungeon ingredients pull their pieces, spices aim at a part, fuel on the fire makes it rarer."
        elseif #targets == 0 and #rarer == 0 then
            lines[#lines + 1] = "Nothing to pull yet: unlock the dungeon's pieces from its chests."
        end
        lines[#lines + 1] = ("|cff999999No piece goes past %d%%.|r"):format(Pct(ns.POT_CEILING))
        self.odds = lines

    end
end

function ns.ShowMintPot()
    if not window then Build() end
    -- Over the main window's pages, covering them (the sidebar stays usable), like the chest show.
    local pageArea = ns.UI and ns.UI.pageArea
    window:ClearAllPoints()
    if pageArea then
        if not pageArea:IsVisible() then ns.ToggleUI() end
        window:SetParent(pageArea)
        window:SetAllPoints(pageArea)
        window:SetFrameStrata(pageArea:GetFrameStrata())
        window:SetFrameLevel(pageArea:GetFrameLevel() + 50)
    else
        window:SetParent(UIParent)
        window:SetSize(827, 584)
        window:SetPoint("CENTER")
        window:SetFrameStrata("DIALOG")
    end
    -- The scenery behind it: to the wood, under the main window's beams (their level, ns.UI.FRAME_LEVEL, less a few); on
    -- its own, the window's own background.
    local body = pageArea and ns.UI.pageBody
    window:SetBackdropColor(0.09, 0.07, 0.06, body and 0 or 1)
    window:SetBackdropBorderColor(1, 1, 1, body and 0 or 1)
    window.scene:Show()
    if body then
        local main = body:GetParent()
        window.scene:Fit(main, body, pageArea, main:GetFrameLevel() + ns.UI.FRAME_LEVEL.middleBeam + 1)
    else
        window.scene:Fit(window, window, window, window:GetFrameLevel())
    end
    -- Back to front: the kitchen, the reveal's stage (its drops over it), then the chef and its words, over everything:
    -- the chef watches the reveal too.
    local level = window:GetFrameLevel()
    window.stage:SetFrameLevel(level + 40)
    window.stage.fx:SetFrameLevel(level + 50)
    window.chef:SetFrameLevel(level + 60)
    window.speech:SetFrameLevel(level + 62)
    wipe(pot)
    for _, bit in ipairs(bits) do bit:Hide() end
    wipe(bits)
    wipe(tweens)
    for _, b in ipairs(live) do b.tex:Hide() bubbles[#bubbles + 1] = b.tex end
    wipe(live)
    stirs, page, stirring, drag = 0, 0, false, nil
    window.puff:Hide()
    window.ripple:Hide()
    window.stage:Hide()
    window.stage.reel:Stop()
    window.reveal = nil
    window.dragIcon:Hide()
    window.glow:SetAlpha(0)
    window.spoon.art:SetRotation(0)
    swirl, window.lastA, squash, slosh, flare = 0, 0, 1, 0, 0
    window:DressChef()
    window:HangPhotos()
    window:Say(({ "COOK!", "STEW!", "HUNGY" })[math.random(3)])
    window.howto, window.nag = 0, 2
    brewShown[1], brewShown[2], brewShown[3] = MURKY[1], MURKY[2], MURKY[3]
    window:Show()
    -- The top beam's title: the page, then the kitchen (clicking the page's part leaves it).
    if ns.UI.SetScreen then ns.UI.SetScreen("Minting Kitchen", "STEW", function() window:Hide() end) end
    window:Refresh()
end
