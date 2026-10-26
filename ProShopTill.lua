-- The Pro Shop's till (after the mockup's checkout, tools/proshop-mock/index.html): the view pans in on the steward
-- behind his counter. Top left, his brass cash register: S.O.L.C. on its crest, the sum on rolling number drums, a
-- velvet price flag popping up out of its top on each ring, and a receipt printing out under it, a line a piece (the
-- total and a torn edge at the end). His speech bubble beside him, its tail at his mouth: a line about each piece
-- (its name and price under it; the pieces aren't shown, most look poor on their own) (StewardLines.lua), rung up a click at a time with a coin clink. Then the total (the register's bell):
-- "It's for me" pays (the posh green S.O.L.C. paper bag drops in) or "Not yet". An empty cart gets a quip. Gifts and
-- the postcard rack come later. ns.ShopUI.Till(room, hooks) makes it; hooks = { camera(p) (0 the room .. 1 on the
-- steward), buy(keys) -> ok, result or reason, done(bought) }; till:Start(items) rings up a cart (items:
-- ProShopRoom.lua's stock items). Art: tools/make-shop-ui.js.

local _, ns = ...
local UI = ns.UI
local S = ns.ShopUI
if not UI or not S then return end

local ART = "Interface\\AddOns\\SOLC\\Media\\ProShop\\UI\\"
local CAMERA_TIME, COUNT_TIME, FLAG_TIME, PRINT_TIME, BAG_TIME = 0.6, 0.45, 0.6, 0.5, 0.3, 1.0
-- (places in page pixels from the top left)
local REGISTER = { x = 20, y = 18, size = 210 }  -- (its art: crest, body with the drum panel at 22,76 166x52, base)
local DRUMS, DRUM_W, DRUM_H = 5, 28, 40
local RECEIPT = { x = 50, y = 214, w = 150, line = 16 }
local BUBBLE = { x = 470, y = 34, w = 332, pad = 14 }
-- The game's own sounds (if this client has them): a coin clink, the bell, paper.
local SOUNDS = { ring = "LOOT_WINDOW_COIN_SOUND", bell = "AUCTION_WINDOW_OPEN", paper = "IG_QUEST_LOG_OPEN" }

local function Pick(list) return list and list[math.random(#list)] end
local function Ease(p) return p * p * (3 - 2 * p) end
local function Back(p) local s = 1.7 return 1 + (s + 1) * (p - 1) ^ 3 + s * (p - 1) ^ 2 end  -- (overshoots, settles)
local function Sound(name)
    if KillTrackerDB and KillTrackerDB.clickSounds == false then return end
    local id = SOUNDKIT and SOUNDKIT[SOUNDS[name]]
    if id then PlaySound(id, "SFX") end
end

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

-- The register: its art, the crest's S.O.L.C., the drums (register:Show(value): the number, rolling like an
-- odometer: each drum turns as the one to its right goes from 9 to 0), the count on its base, the flag behind it.
local function Register(till)
    local register = CreateFrame("Frame", nil, till)
    register:SetSize(REGISTER.size, REGISTER.size)
    register:SetFrameLevel(till:GetFrameLevel() + 3)
    local art = register:CreateTexture(nil, "ARTWORK")
    art:SetAllPoints()
    art:SetTexture(ART .. "Register")
    local crest = register:CreateFontString(nil, "OVERLAY")
    crest:SetFont(S.DISPLAY_FONT, 17, "")
    crest:SetTextColor(S.C("#5c3d10"))
    crest:SetShadowOffset(0, -1)
    crest:SetShadowColor(1, 0.95, 0.75, 0.6)  -- (engraved: a light edge under it)
    crest:SetPoint("CENTER", register, "TOPLEFT", 105, -40)
    crest:SetText("S.O.L.C.")
    register.count = register:CreateFontString(nil, "OVERLAY")
    register.count:SetFont(S.DISPLAY_FONT, 12, "")
    register.count:SetTextColor(S.C("#f3dc9a"))
    register.count:SetPoint("CENTER", register, "TOPLEFT", 105, -185)
    -- The drums: a window each, two digits in it (the one showing and the next, rolling up).
    register.drums = {}
    local left = 22 + (166 - (DRUMS * DRUM_W + (DRUMS - 1) * 4)) / 2
    for i = 1, DRUMS do
        local window = CreateFrame("Frame", nil, register)
        window:SetSize(DRUM_W, DRUM_H)
        window:SetPoint("TOPLEFT", left + (i - 1) * (DRUM_W + 4), -82)
        window:SetClipsChildren(true)
        local face = window:CreateTexture(nil, "BACKGROUND")
        face:SetAllPoints()
        face:SetTexture(ART .. "Drum")
        window.digits = {}
        for d = 1, 2 do
            local digit = window:CreateFontString(nil, "ARTWORK")
            digit:SetFont(S.BODY_FONT, 26, "")
            digit:SetTextColor(S.C("#f6e3b0"))
            digit:SetSize(DRUM_W, DRUM_H)
            window.digits[d] = digit
        end
        local shine = window:CreateTexture(nil, "OVERLAY")  -- (the glass: darker top and bottom)
        shine:SetAllPoints()
        S.Gradient(shine, { 0, 0, 0, 0.55 }, { 0, 0, 0, 0 })
        shine:SetHeight(DRUM_H * 0.3)
        shine:ClearAllPoints() shine:SetPoint("TOPLEFT") shine:SetPoint("TOPRIGHT")
        register.drums[i] = window
    end
    function register:ShowValue(v)
        v = math.max(0, v)
        for i, window in ipairs(self.drums) do
            local place = 10 ^ (DRUMS - i)
            local base = math.floor(v / place)
            local rest = v - base * place  -- (what the drums to its right show)
            local turn = place == 1 and (v - math.floor(v)) or math.max(0, rest - (place - 1))
            local a, b = window.digits[1], window.digits[2]
            a:SetText((base == 0 and i < DRUMS) and "" or tostring(base % 10))  -- (no leading zeros)
            b:SetText(tostring((base + 1) % 10))  -- (below it, out of the window until it rolls)
            a:ClearAllPoints() a:SetPoint("TOP", 0, DRUM_H * turn)
            b:ClearAllPoints() b:SetPoint("TOP", a, "BOTTOM")
        end
    end
    -- The price flag: behind the crest, popping up out of it.
    local flag = CreateFrame("Frame", nil, till)
    flag:SetSize(76, 38)
    flag:SetFrameLevel(register:GetFrameLevel() - 1)
    local cloth = flag:CreateTexture(nil, "ARTWORK")
    cloth:SetAllPoints()
    cloth:SetTexture(ART .. "PriceFlag")
    flag.text = S.Text(flag, S.DISPLAY_FONT, 18, "#f6d98a")
    flag.text:SetPoint("CENTER", 0, 1)
    flag:Hide()
    register.flag = flag
    function register:Flag(p)  -- 0 hidden in the crest .. 1 up
        flag:ClearAllPoints()
        flag:SetPoint("BOTTOM", self, "TOPLEFT", 105, -30 + 44 * p)
    end
    return register
end

-- The receipt: paper hanging from the register, a line a piece, then the total and a torn edge.
local function Receipt(till)
    local receipt = CreateFrame("Frame", nil, till)
    receipt:SetWidth(RECEIPT.w)
    receipt:SetFrameLevel(till:GetFrameLevel() + 2)
    receipt:SetClipsChildren(true)
    local paper = receipt:CreateTexture(nil, "BACKGROUND")
    paper:SetPoint("TOPLEFT") paper:SetPoint("BOTTOMRIGHT", 0, 8)
    paper:SetColorTexture(S.C("#f6ecd2"))
    local edge = receipt:CreateTexture(nil, "BACKGROUND")
    edge:SetPoint("BOTTOMLEFT") edge:SetPoint("BOTTOMRIGHT")
    edge:SetHeight(8)
    edge:SetTexture(ART .. "ReceiptEdge", "REPEAT", "CLAMP")
    edge:SetTexCoord(0, RECEIPT.w / 16, 0, 1)
    local shade = receipt:CreateTexture(nil, "BORDER")  -- (curling out of the slot: shaded at the top)
    shade:SetPoint("TOPLEFT") shade:SetPoint("TOPRIGHT")
    shade:SetHeight(10)
    S.Gradient(shade, { 0, 0, 0, 0.35 }, { 0, 0, 0, 0 })
    receipt.lines = {}
    function receipt:Line(i, left, right, big)
        local line = self.lines[i]
        if not line then
            line = {
                left = S.Text(self, S.BODY_FONT, 11, "#3b2412"),
                right = S.Text(self, S.BODY_FONT, 11, "#3b2412"),
            }
            line.left:SetShadowOffset(0, 0) line.right:SetShadowOffset(0, 0)
            line.left:SetJustifyH("LEFT")
            line.left:SetWordWrap(false)
            self.lines[i] = line
        end
        local font = big and S.DISPLAY_FONT or S.BODY_FONT
        line.left:SetFont(font, big and 13 or 11, "") line.right:SetFont(font, big and 13 or 11, "")
        line.left:ClearAllPoints() line.left:SetPoint("TOPLEFT", 8, -(8 + (i - 1) * RECEIPT.line))
        line.left:SetPoint("RIGHT", self, "RIGHT", -52, 0)
        line.right:ClearAllPoints() line.right:SetPoint("TOPRIGHT", -8, -(8 + (i - 1) * RECEIPT.line))
        line.left:SetText(left) line.right:SetText(right)
        line.left:Show() line.right:Show()
    end
    function receipt:Clear()
        for _, line in ipairs(self.lines) do line.left:Hide() line.right:Hide() end
        self:SetHeight(0.1)
    end
    function receipt:Height(n) return 8 + n * RECEIPT.line + 10 end
    return receipt
end

function S.Till(room, hooks)
    local till = CreateFrame("Button", nil, room)
    till:SetAllPoints()
    till:SetFrameLevel(UI.window:GetFrameLevel() + UI.FRAME_LEVEL.wood - 9)  -- (under the window's wood, as the curtains)
    till:RegisterForClicks("LeftButtonUp")
    till:Hide()
    local vignette = till:CreateTexture(nil, "BACKGROUND")
    vignette:SetPoint("TOPLEFT", -14, 14) vignette:SetPoint("BOTTOMRIGHT", 14, -14)
    vignette:SetTexture(ART .. "Vignette")

    local register = Register(till)
    register:SetPoint("TOPLEFT", REGISTER.x, -REGISTER.y)
    local receipt = Receipt(till)
    receipt:SetPoint("TOPLEFT", RECEIPT.x, -RECEIPT.y)

    -- His bubble: parchment in gilt, its tail down at his mouth; what he says, who it's about, buttons.
    local bubble = CreateFrame("Frame", nil, till)
    bubble:SetWidth(BUBBLE.w)
    bubble:SetFrameLevel(till:GetFrameLevel() + 4)
    Nine(bubble, "Bubble", 20, "BACKGROUND")
    local tail = bubble:CreateTexture(nil, "BORDER")
    tail:SetSize(22, 22)
    tail:SetPoint("CENTER", bubble, "BOTTOMLEFT", 6, 4)
    tail:SetTexture(ART .. "BubbleTail")
    tail:SetRotation(math.rad(40))  -- (it points left; turned to point down and left, at him)
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
    bag.handle = bag:CreateTexture(nil, "ARTWORK", nil, 1)
    bag.handle:SetSize(50, 50)
    bag.handle:SetTexture(ART .. "BagHandle")
    bag.mark = bag:CreateFontString(nil, "OVERLAY")
    bag.mark:SetFont(S.DISPLAY_FONT, 16, "")
    bag.mark:SetTextColor(S.C("#f2c14e"))
    bag.mark:SetText("S.O.L.C.")
    bag:Hide()

    local skip = S.Text(till, S.BODY_FONT, 12, "#e8cf9a")
    skip:SetPoint("BOTTOM", 0, 6)
    skip:SetText("Click to go on")

    -- The sale so far.
    local sale = { items = {}, i = 0, sum = 0, shown = 0 }
    local tweens = {}
    local function Tween(duration, fn, after) tweens[#tweens + 1] = { t = 0, d = duration, fn = fn, after = after } end
    local function Count() register.count:SetText(("%d / %d"):format(math.min(sale.i, #sale.items), #sale.items)) end

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
        bubble:Show()
        skip:SetShown(choices == nil)
    end

    local function End(bought)
        sale.ending = true
        bubble:Hide() skip:Hide()
        if not InCombatLockdown() then till:EnableKeyboard(false) end
        Tween(CAMERA_TIME, function(p)
            hooks.camera(1 - Ease(p))
            till:SetAlpha(1 - p)
        end, function()
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
        Sound("paper")
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
        -- (the receipt's total and torn edge; the register's bell; the cushion cleared)
        Sound("bell")
        local n = #sale.items
        receipt:Line(n + 1, "TOTAL", BreakUpLargeNumbers(sale.sum), true)
        local from = receipt:GetHeight()
        Tween(PRINT_TIME, function(p) receipt:SetHeight(from + (receipt:Height(n + 1) + 4 - from) * Ease(p)) end)
        register:Flag(0) register.flag:Hide()
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
        Sound("ring")
        Bubble(LineFor(item), ("%s  ·  %s points"):format(item.option.name, BreakUpLargeNumbers(item.price)))
        Count()
        -- (the register: the flag pops up with the price, the drums roll on, the receipt prints a line)
        register.flag.text:SetText(BreakUpLargeNumbers(item.price))
        register.flag:Show()
        Tween(FLAG_TIME, function(p) register:Flag(Back(p)) end)
        Tween(COUNT_TIME, function(p) register:ShowValue(from + (sale.sum - from) * Ease(p)) end)
        receipt:Line(sale.i, item.option.name, BreakUpLargeNumbers(item.price))
        local height = receipt:GetHeight()
        Tween(PRINT_TIME, function(p) receipt:SetHeight(height + (receipt:Height(sale.i) - height) * Ease(p)) end)
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
        sale.items, sale.i, sale.sum, sale.ending = items, 0, 0, false
        bubble:ClearAllPoints()
        bubble:SetPoint("TOPLEFT", BUBBLE.x, -BUBBLE.y)
        bubble:Hide() skip:Hide()
        receipt:Clear()
        register:ShowValue(0)
        register.flag:Hide()
        Count()
        local any = #items > 0
        register:SetShown(any) receipt:SetShown(any)
        self:SetAlpha(0)
        self:Show()
        if not InCombatLockdown() then self:EnableKeyboard(true) end
        Tween(CAMERA_TIME, function(p)
            hooks.camera(Ease(p))
            self:SetAlpha(p)
        end, function()
            if not any then
                Bubble(Say("empty", "Nothing to ring up?"), nil, { { "Back to the shop", function() End(false) end } })
                return
            end
            Bubble(Say("open", "Ahem."), "The steward")
        end)
    end
    -- Leaving the page: gone at once, the room as it was.
    function till:Reset()
        wipe(tweens)
        sale.ending = false
        hooks.camera(0)
        if not InCombatLockdown() then self:EnableKeyboard(false) end
        self:Hide()
    end
    return till
end
