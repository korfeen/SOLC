-- The Pro Shop's till (the mockup's checkout, tools/proshop-mock/index.html): the view pans in on the steward behind his
-- counter, the till's brass box at the top left (THE TILL n / N over a dark screen with the running sum), his speech
-- bubble beside him, and each piece of the cart rung up a click at a time: his line about it (StewardLines.lua), its
-- card sliding in (the piece, its name, *ka-ching*), the till counting up. Then the total: "It's for me" pays (the
-- posh green S.O.L.C. paper bag drops in) or "Not yet". An empty cart gets a quip. Gifts and the postcard rack come
-- later. ns.ShopUI.Till(room, hooks) makes it; hooks = { camera(p) (0 the room .. 1 on the steward), buy(keys) -> ok,
-- result or reason, done(bought) }; till:Start(items, total) rings up a cart (items: ProShopRoom.lua's stock items).

local _, ns = ...
local UI = ns.UI
local S = ns.ShopUI
if not UI or not S then return end

local ART = "Interface\\AddOns\\SOLC\\Media\\ProShop\\UI\\"
local CAMERA_TIME, CARD_TIME, COUNT_TIME, BAG_TIME = 0.6, 0.4, 0.4, 1.0
-- (the mock's places, page pixels from the top left)
local BOX = { x = 22, y = 30, w = 214 }
local BUBBLE = { x = 470, y = 34, w = 332, pad = 14 }
local CARD = { x = 300, y = 360, w = 254 }

local function Pick(list) return list and list[math.random(#list)] end
local function Ease(p) return p * p * (3 - 2 * p) end

-- What the steward says about a piece: its own line, or his line for its layer and rarity, or just its name.
local function LineFor(item)
    local lines = ns.StewardLines or {}
    local own = lines.pieces and lines.pieces[item.option.id]
    if own and #own > 0 then return Pick(own) end
    local byLayer = lines.layers and lines.layers[item.layer.key]
    local fallback = byLayer and byLayer[item.option.rarity]
    if fallback and #fallback > 0 then return Pick(fallback):format(item.option.name) end
    return item.option.name .. "."
end
local function Say(key, fallback) return Pick((ns.StewardLines or {})[key]) or fallback end

-- Nine slices of a 64 px art (corners `corner` px) filling frame.
local function Nine(frame, art, corner, layer)
    local E = corner / 64
    local cells = { { 0, E }, { E, 1 - E }, { 1 - E, 1 } }
    local parts = {}
    for row = 1, 3 do
        for col = 1, 3 do
            local t = frame:CreateTexture(nil, layer or "BACKGROUND")
            t:SetTexture(ART .. art)
            t:SetTexCoord(cells[col][1], cells[col][2], cells[row][1], cells[row][2])
            parts[(row - 1) * 3 + col] = t
        end
    end
    local function Place()
        local w, h = frame:GetSize()
        for row = 1, 3 do
            for col = 1, 3 do
                local t = parts[(row - 1) * 3 + col]
                t:ClearAllPoints()
                t:SetPoint("TOPLEFT", ({ 0, corner, w - corner })[col], -({ 0, corner, h - corner })[row])
                t:SetSize(math.max(0.1, ({ corner, w - 2 * corner, corner })[col]), math.max(0.1, ({ corner, h - 2 * corner, corner })[row]))
            end
        end
    end
    frame:HookScript("OnSizeChanged", Place)
end

function S.Till(room, hooks)
    local till = CreateFrame("Button", nil, room)
    till:SetAllPoints()
    till:SetFrameLevel(UI.window:GetFrameLevel() + UI.FRAME_LEVEL.wood - 8)  -- (under the window's wood, as the curtains)
    till:RegisterForClicks("LeftButtonUp")
    till:Hide()
    local vignette = till:CreateTexture(nil, "BACKGROUND")
    vignette:SetPoint("TOPLEFT", -14, 14) vignette:SetPoint("BOTTOMRIGHT", 14, -14)
    vignette:SetTexture(ART .. "Vignette")

    -- The till's box: brass, THE TILL and the count over a dark screen with the sum.
    local box = CreateFrame("Frame", nil, till)
    box:SetSize(BOX.w, 76)
    local fill = box:CreateTexture(nil, "BACKGROUND")
    fill:SetPoint("TOPLEFT", 2, -2) fill:SetPoint("BOTTOMRIGHT", -2, 2)
    S.Gradient(fill, { S.C("#e7c66c") }, { S.C("#a87d2c") })
    Nine(box, "TillFrame", 16, "BORDER")
    local label = box:CreateFontString(nil, "OVERLAY")
    label:SetFont(S.DISPLAY_FONT, 12, "")
    label:SetTextColor(S.C("#3a2610"))
    label:SetPoint("TOPLEFT", 12, -10)
    label:SetText("THE TILL")
    local count = box:CreateFontString(nil, "OVERLAY")
    count:SetFont(S.DISPLAY_FONT, 12, "")
    count:SetTextColor(S.C("#3a2610"))
    count:SetPoint("TOPRIGHT", -12, -10)
    local screen = box:CreateTexture(nil, "ARTWORK")
    screen:SetPoint("TOPLEFT", 12, -28) screen:SetPoint("BOTTOMRIGHT", -12, 10)
    screen:SetColorTexture(S.C("#1d1408"))
    local glass = box:CreateTexture(nil, "ARTWORK", nil, 1)  -- (its inner shadow along the top)
    glass:SetPoint("TOPLEFT", screen) glass:SetPoint("TOPRIGHT", screen)
    glass:SetHeight(6)
    S.Gradient(glass, { 0, 0, 0, 0.8 }, { 0, 0, 0, 0 })
    local sum = box:CreateFontString(nil, "OVERLAY")
    sum:SetFont(S.BODY_FONT, 22, "")
    sum:SetTextColor(S.C("#ffcf5a"))
    sum:SetPoint("RIGHT", screen, "RIGHT", -8, 0)

    -- His bubble: parchment in gilt, its tail pointing at him; what he says, who it's about, buttons.
    local bubble = CreateFrame("Frame", nil, till)
    bubble:SetWidth(BUBBLE.w)
    Nine(bubble, "Bubble", 20, "BACKGROUND")
    local tail = bubble:CreateTexture(nil, "BORDER")
    tail:SetSize(16, 16)
    tail:SetPoint("TOPRIGHT", bubble, "TOPLEFT", 2, -34)
    tail:SetTexture(ART .. "BubbleTail")
    local words = S.Text(bubble, S.DISPLAY_FONT, 18, "#3b2412")
    words:SetShadowOffset(0, 0)
    words:SetWidth(BUBBLE.w - 2 * BUBBLE.pad)
    words:SetJustifyH("LEFT")
    words:SetSpacing(2)
    local who = S.Text(bubble, S.BODY_FONT, 11, "#6b4a2c")
    who:SetShadowOffset(0, 0)
    who:SetWidth(BUBBLE.w - 2 * BUBBLE.pad)
    who:SetJustifyH("LEFT")
    local buttons = {}
    for i = 1, 2 do buttons[i] = S.Button(bubble, 130, 32, "", 14) end
    -- (the bag, over the words when you've paid)
    local bag = CreateFrame("Frame", nil, bubble)
    bag:SetSize(120, 130)
    bag.body = bag:CreateTexture(nil, "ARTWORK")
    bag.body:SetSize(100, 96)
    bag.body:SetTexture(ART .. "BagBody")
    bag.tissue = bag:CreateTexture(nil, "ARTWORK", nil, 1)
    bag.tissue:SetSize(64, 22)
    bag.tissue:SetTexture(ART .. "BagTissue")
    bag.tissue:SetTexCoord(0, 1, 0, 1)
    bag.handle = bag:CreateTexture(nil, "ARTWORK", nil, 1)
    bag.handle:SetSize(50, 50)
    bag.handle:SetTexture(ART .. "BagHandle")
    bag.mark = bag:CreateFontString(nil, "OVERLAY")
    bag.mark:SetFont(S.DISPLAY_FONT, 16, "")
    bag.mark:SetTextColor(S.C("#f2c14e"))
    bag.mark:SetText("S.O.L.C.")
    bag:Hide()

    -- The piece's card: cream, the piece, its name, *ka-ching*.
    local card = CreateFrame("Frame", nil, till)
    card:SetSize(CARD.w, 172)
    Nine(card, "Card", 8, "BACKGROUND")
    card.pic = CreateFrame("Frame", nil, card)
    card.pic:SetSize(110, 110)
    card.pic:SetPoint("TOP", 0, -10)
    card.name = S.Text(card, S.DISPLAY_FONT, 18, "#3b2412")
    card.name:SetShadowOffset(0, 0)
    card.name:SetPoint("TOP", card.pic, "BOTTOM", 0, -4)
    card.ching = S.Text(card, S.BODY_FONT, 12, "#6b4a2c")
    card.ching:SetShadowOffset(0, 0)
    card.ching:SetPoint("TOP", card.name, "BOTTOM", 0, -4)
    card.ching:SetText("*ka-ching*")
    card:Hide()

    local skip = S.Text(till, S.BODY_FONT, 12, "#e8cf9a")
    skip:SetPoint("BOTTOM", 0, 14)
    skip:SetText("Click to go on")

    -- The sale so far.
    local sale = { items = {}, i = 0, sum = 0, shown = 0, camera = 0 }
    local tweens = {}
    local function Tween(duration, fn, after) tweens[#tweens + 1] = { t = 0, d = duration, fn = fn, after = after } end

    local function Box()
        count:SetText(("%d / %d"):format(math.min(sale.i, #sale.items), #sale.items))
        sum:SetText(BreakUpLargeNumbers(math.floor(sale.shown + 0.5)))
    end
    -- His bubble: text, who (optional), up to two buttons { label, onClick }, the bag on top (optional).
    local function Bubble(text, whoText, choices, withBag)
        local y = BUBBLE.pad
        bag:SetShown(withBag and true or false)
        if withBag then
            bag:ClearAllPoints()
            bag:SetPoint("TOP", 0, -y)
            y = y + 130 + 8
        end
        words:ClearAllPoints()
        words:SetPoint("TOPLEFT", BUBBLE.pad, -y)
        words:SetText(text)
        y = y + words:GetStringHeight()
        who:ClearAllPoints()
        who:SetPoint("TOPLEFT", BUBBLE.pad, -(y + 6))
        who:SetText(whoText or "")
        who:SetShown(whoText ~= nil)
        if whoText then y = y + 6 + who:GetStringHeight() end
        local x = BUBBLE.pad
        for i, button in ipairs(buttons) do
            local choice = choices and choices[i]
            button:SetShown(choice ~= nil)
            if choice then
                button.text:SetText(choice[1])
                button:SetWidth(math.max(90, button.text:GetStringWidth() + 28))
                button:SetScript("OnClick", choice[2])
                button:ClearAllPoints()
                button:SetPoint("TOPLEFT", x, -(y + 10))
                x = x + button:GetWidth() + 8
            end
        end
        if choices then y = y + 10 + 32 end
        bubble:SetHeight(y + BUBBLE.pad)
        skip:SetShown(choices == nil)
    end

    local function End(bought)
        sale.ending = true
        card:Hide()
        bubble:Hide()
        box:Hide()
        skip:Hide()
        if not InCombatLockdown() then till:EnableKeyboard(false) end
        Tween(CAMERA_TIME, function(p) sale.camera = 1 - Ease(p) hooks.camera(sale.camera) end, function()
            till:Hide()
            sale.ending = false
            hooks.done(bought)
        end)
    end

    local function Pay()
        local keys = {}
        for i, item in ipairs(sale.items) do keys[i] = item.key end
        local ok, result = hooks.buy(keys)
        if not ok then
            Bubble(result, "The steward, unmoved", { { "Back to the shop", function() End(false) end } })
            return
        end
        Bubble(Say("bag", "Splendid."), "All of it is in your wardrobe now.", { { "Thank you", function() End(true) end } }, true)
        -- (the bag drops in, then its tissue, then its handle)
        bag.body:ClearAllPoints() bag.body:SetPoint("BOTTOM", 0, 0)
        bag.tissue:ClearAllPoints() bag.tissue:SetPoint("BOTTOM", bag.body, "TOP", 0, -10)
        bag.handle:ClearAllPoints() bag.handle:SetPoint("BOTTOM", bag.body, "TOP", 0, -16)
        bag.mark:ClearAllPoints() bag.mark:SetPoint("TOP", bag.body, "TOP", 0, -36)
        bag.tissue:SetAlpha(0) bag.handle:SetAlpha(0)
        Tween(BAG_TIME, function(p)
            local drop = Ease(math.min(1, p / 0.45))
            bag.body:SetPoint("BOTTOM", 0, 80 * (1 - drop))
            bag.body:SetAlpha(drop) bag.mark:SetAlpha(drop)
            bag.tissue:SetAlpha(math.max(0, math.min(1, (p - 0.45) / 0.3)))
            bag.handle:SetAlpha(math.max(0, math.min(1, (p - 0.7) / 0.3)))
        end)
    end

    local function Ask()
        card:Hide()
        local balance = ns.GetPoints().balance
        if balance < sale.sum then
            Bubble(("That comes to %s points. You have %s. Do come back when you are... solvent."):format(
                BreakUpLargeNumbers(sale.sum), BreakUpLargeNumbers(balance)), nil, { { "Back to the shop", function() End(false) end } })
            return
        end
        Bubble(Say("total", "That comes to %s points."):format(BreakUpLargeNumbers(sale.sum)), nil,
            { { "It's for me", Pay }, { "Not yet", function() End(false) end } })
    end

    -- Rings up the next piece (a click anywhere), or asks for the total after the last.
    local function Next()
        if sale.ending or not skip:IsShown() then return end
        if sale.i >= #sale.items then return Ask() end
        sale.i = sale.i + 1
        local item = sale.items[sale.i]
        local from = sale.sum
        sale.sum = sale.sum + item.price
        Bubble(LineFor(item), ("%s  ·  %s points"):format(item.option.name, BreakUpLargeNumbers(item.price)))
        ns.DrawPiece(card.pic, item.layer.key, item.option)
        card.name:SetText(item.option.name)
        card.name:SetTextColor(ns.RarityRGB(item.option.rarity))
        card:Show()
        Tween(CARD_TIME, function(p)  -- (slides in from the left)
            local e = Ease(p)
            card:ClearAllPoints()
            card:SetPoint("TOPLEFT", till, "TOPLEFT", CARD.x - 260 * (1 - e), -CARD.y)
            card:SetAlpha(e)
        end)
        Tween(COUNT_TIME, function(p)  -- (the till counts up, its box jumps)
            sale.shown = from + (sale.sum - from) * Ease(p)
            box:SetPoint("TOPLEFT", till, "TOPLEFT", BOX.x, -BOX.y + 4 * math.sin(math.pi * math.min(1, p / 0.6)))
            Box()
        end)
        Box()
    end

    till:SetScript("OnClick", Next)
    till:SetScript("OnKeyDown", function(self, key)
        local handled = key == "ESCAPE" or key == "ENTER" or key == "SPACE"
        if not InCombatLockdown() then self:SetPropagateKeyboardInput(not handled) end
        if key == "ESCAPE" then End(false) elseif handled then Next() end
    end)
    till:SetScript("OnUpdate", function(_, elapsed)
        for i = #tweens, 1, -1 do
            local tw = tweens[i]
            tw.t = math.min(tw.d, tw.t + elapsed)
            tw.fn(tw.t / tw.d)
            if tw.t >= tw.d then
                table.remove(tweens, i)
                if tw.after then tw.after() end
            end
        end
    end)

    function till:Start(items)
        wipe(tweens)
        sale.items, sale.i, sale.sum, sale.shown, sale.ending = items, 0, 0, 0, false
        box:ClearAllPoints()
        box:SetPoint("TOPLEFT", BOX.x, -BOX.y)
        bubble:ClearAllPoints()
        bubble:SetPoint("TOPLEFT", BUBBLE.x, -BUBBLE.y)
        card:Hide()
        bubble:Hide() box:Hide() skip:Hide()
        self:SetAlpha(1)
        self:Show()
        if not InCombatLockdown() then self:EnableKeyboard(true) end
        Tween(CAMERA_TIME, function(p) sale.camera = Ease(p) hooks.camera(sale.camera) end, function()
            bubble:Show()
            if #items == 0 then
                Bubble(Say("empty", "Nothing to ring up?"), nil, { { "Back to the shop", function() End(false) end } })
                return
            end
            box:Show()
            Box()
            Bubble(Say("open", "Ahem."), "The steward")
        end)
    end
    -- Leaving the page: gone at once, the room as it was.
    function till:Reset()
        wipe(tweens)
        sale.camera, sale.ending = 0, false
        hooks.camera(0)
        if not InCombatLockdown() then self:EnableKeyboard(false) end
        self:Hide()
    end
    return till
end
