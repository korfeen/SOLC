-- The Pro Shop's till (after the mockup's checkout, tools/proshop-mock/index.html): the view pans in on the steward
-- behind his counter. The painted till on the counter shows the sum in its own display window, on rolling number
-- drums (hooks.display: where its window is on the page), and a receipt prints out top left, a line a piece (the total
-- and a torn edge at the end). His speech bubble beside him, its tail at his mouth: a line about each piece
-- (StewardLines.lua) with its name and price under it, rung up a click at a time with a coin clink (the pieces aren't
-- shown: most look poor on their own). Then the total (the register's bell): "It's for me" pays (the posh green S.O.L.C. paper bag, Codex's painting, drops in) or "Not yet". An empty cart gets a quip. Gifts and
-- the postcard rack come later. ns.ShopUI.Till(room, hooks) makes it; hooks = { camera(p) (0 the room .. 1 on the
-- steward), buy(keys) -> ok, result or reason, done(bought) }; till:Start(items) rings up a cart (items:
-- ProShopRoom.lua's stock items); hooks.display() -> x, y, w, h: the painted till's window, page pixels. Art:
-- tools/make-shop-ui.js; the bag: Media/ProShop/Bag (tools/gen-proshop-bag.js).

local _, ns = ...
local UI = ns.UI
local S = ns.ShopUI
if not UI or not S then return end

local ART = "Interface\\AddOns\\SOLC\\Media\\ProShop\\UI\\"
local CAMERA_TIME, COUNT_TIME, PRINT_TIME, BAG_TIME = 0.6, 0.45, 0.5, 0.8
-- (places in page pixels from the top left)
local DRUMS = 5
local RECEIPT = { line = 14 }  -- (where it prints: hooks.receipt, under the till)
local BAG = "Interface\\AddOns\\SOLC\\Media\\ProShop\\Bag"
local BUBBLE = { x = 568, y = 110, w = 240, pad = 14 }  -- (beside his head, its tail at his mouth)
-- The game's own sounds (if this client has them): a coin clink, the bell, paper.
local SOUNDS = { ring = "LOOT_WINDOW_COIN_SOUND", bell = "AUCTION_WINDOW_OPEN", paper = "IG_QUEST_LOG_OPEN" }

local function Pick(list) return list and list[math.random(#list)] end
local function Ease(p) return p * p * (3 - 2 * p) end
local function Back(p) local s = 1.7 return 1 + (s + 1) * (p - 1) ^ 3 + s * (p - 1) ^ 2 end  -- (overshoots, settles)
local function Sound(name)
    if KillTrackerDB and KillTrackerDB.clickSounds == false then return end
    local id = SOUNDKIT and SOUNDKIT[SOUNDS[name]]
    ns.PlaySound(id, "SFX")
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

-- The register: the painted till's display window (register:Fit(x, y, w, h): put on it, page pixels), its drums
-- (register:ShowValue(value): the number, rolling like an odometer: each drum turns as the one to its right goes from 9
-- to 0) in a warm glow.
local function Register(till)
    local register = CreateFrame("Frame", nil, till)
    register:SetFrameLevel(till:GetFrameLevel() + 3)
    local glass = register:CreateTexture(nil, "BACKGROUND")  -- (the window lit a little from inside)
    glass:SetAllPoints()
    glass:SetColorTexture(0.12, 0.08, 0.04, 0.85)
    register.drums = {}
    for i = 1, DRUMS do
        local window = CreateFrame("Frame", nil, register)
        window:SetClipsChildren(true)
        window.digits = {}
        for d = 1, 2 do
            local digit = window:CreateFontString(nil, "ARTWORK")
            digit:SetTextColor(S.C("#ffd98a"))
            window.digits[d] = digit
        end
        register.drums[i] = window
    end
    function register:Fit(x, y, w, h)
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", till, "TOPLEFT", x, -y)
        self:SetSize(w, h)
        local dw = w / DRUMS
        self.drumH = h
        for i, window in ipairs(self.drums) do
            window:ClearAllPoints()
            window:SetPoint("TOPLEFT", (i - 1) * dw, 0)
            window:SetSize(dw, h)
            for _, digit in ipairs(window.digits) do
                digit:SetFont(S.BODY_FONT, math.max(8, math.floor(h * 0.85)), "")
                digit:SetSize(dw, h)
            end
        end
    end
    function register:ShowValue(v)
        local DRUM_H = self.drumH or 20
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
    return register
end

-- The receipt: paper printing out top left, a line a piece, then the total and a torn edge.
local function Receipt(till)
    local receipt = CreateFrame("Frame", nil, till)
    receipt:SetFrameLevel(till:GetFrameLevel() + 2)
    receipt:SetClipsChildren(true)
    local paper = receipt:CreateTexture(nil, "BACKGROUND")
    paper:SetPoint("TOPLEFT") paper:SetPoint("BOTTOMRIGHT", 0, 8)
    paper:SetColorTexture(S.C("#f6ecd2"))
    local edge = receipt:CreateTexture(nil, "BACKGROUND")
    edge:SetPoint("BOTTOMLEFT") edge:SetPoint("BOTTOMRIGHT")
    edge:SetHeight(8)
    edge:SetTexture(ART .. "ReceiptEdge", "REPEAT", "CLAMP")
    local shade = receipt:CreateTexture(nil, "BORDER")  -- (curling out of the slot: shaded at the top)
    shade:SetPoint("TOPLEFT") shade:SetPoint("TOPRIGHT")
    shade:SetHeight(10)
    S.Gradient(shade, { 0, 0, 0, 0.35 }, { 0, 0, 0, 0 })
    receipt.lines = {}
    function receipt:Line(i, left, right, big)
        local line = self.lines[i]
        if not line then
            line = {
                left = S.Text(self, S.BODY_FONT, 10, "#3b2412"),
                right = S.Text(self, S.BODY_FONT, 10, "#3b2412"),
            }
            line.left:SetShadowOffset(0, 0) line.right:SetShadowOffset(0, 0)
            line.left:SetJustifyH("LEFT")
            line.left:SetWordWrap(false)
            self.lines[i] = line
        end
        local font = big and S.DISPLAY_FONT or S.BODY_FONT
        line.left:SetFont(font, big and 11 or 10, "") line.right:SetFont(font, big and 11 or 10, "")
        line.left:ClearAllPoints() line.left:SetPoint("TOPLEFT", 5, -(6 + (i - 1) * RECEIPT.line))
        line.left:SetPoint("RIGHT", self, "RIGHT", -38, 0)
        line.right:ClearAllPoints() line.right:SetPoint("TOPRIGHT", -5, -(6 + (i - 1) * RECEIPT.line))
        line.left:SetText(left) line.right:SetText(right)
        line.left:Show() line.right:Show()
    end
    function receipt:Clear()
        for _, line in ipairs(self.lines) do line.left:Hide() line.right:Hide() end
        self:SetHeight(0.1)
    end
    function receipt:Height(n) return 6 + n * RECEIPT.line + 10 end
    function receipt:Place(x, y, w)  -- (under the till: page pixels)
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", till, "TOPLEFT", x, -y)
        self:SetWidth(w)
        edge:SetTexCoord(0, w / 16, 0, 1)
    end
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
    local receipt = Receipt(till)

    -- His bubble: parchment in gilt, its tail down at his mouth; what he says, who it's about, buttons.
    local bubble = CreateFrame("Frame", nil, till)
    bubble:SetWidth(BUBBLE.w)
    bubble:SetFrameLevel(till:GetFrameLevel() + 4)
    Nine(bubble, "Bubble", 20, "BACKGROUND")
    local tail = bubble:CreateTexture(nil, "BORDER")  -- (over the bubble's edge where they join, so they're one shape)
    tail:SetSize(32, 32)
    tail:SetPoint("TOPRIGHT", bubble, "TOPLEFT", 3, -24)
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
    -- (the bag, over the words when you've paid: Codex's painting)
    local bag = CreateFrame("Frame", nil, bubble)
    bag:SetSize(120, 130)
    bag.body = bag:CreateTexture(nil, "ARTWORK")
    bag.body:SetSize(130, 130)
    bag.body:SetTexture(BAG)
    bag:Hide()

    local skip = S.Text(till, S.BODY_FONT, 12, "#e8cf9a")
    skip:SetPoint("BOTTOM", 0, 6)
    skip:SetText("Click to go on")

    -- The sale so far.
    local sale = { items = {}, i = 0, sum = 0, shown = 0 }
    local tweens = {}
    local function Tween(duration, fn, after) tweens[#tweens + 1] = { t = 0, d = duration, fn = fn, after = after } end

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
        register:Hide() receipt:Hide()
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
        -- (the bag drops in, settling with a little bounce)
        bag.body:ClearAllPoints() bag.body:SetPoint("BOTTOM", 0, 0)
        Tween(BAG_TIME, function(p)
            local drop = Back(math.min(1, p / 0.6))
            bag.body:SetPoint("BOTTOM", 0, 80 * (1 - drop))
            bag.body:SetAlpha(math.min(1, p / 0.25))
        end)
    end

    local function Ask()
        -- (the receipt's total and torn edge; the till's bell)
        Sound("bell")
        local n = #sale.items
        receipt:Line(n + 1, "TOTAL", BreakUpLargeNumbers(sale.sum), true)
        local from = receipt:GetHeight()
        Tween(PRINT_TIME, function(p) receipt:SetHeight(from + (receipt:Height(n + 1) + 4 - from) * Ease(p)) end)
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
        -- (the till's drums roll on, the receipt prints a line)
        Tween(COUNT_TIME, function(p) register:ShowValue(from + (sale.sum - from) * Ease(p)) end)
        receipt:Line(sale.i, item.option.name, BreakUpLargeNumbers(item.price))
        local height = receipt:GetHeight()
        Tween(PRINT_TIME, function(p) receipt:SetHeight(height + (receipt:Height(sale.i) - height) * Ease(p)) end)
    end

    till:SetScript("OnClick", Next)
    ns.UI.CombatSafeKeys(till)
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
        register:Hide() receipt:Hide()
        local any = #items > 0
        self:SetAlpha(0)
        self:Show()
        if not InCombatLockdown() then self:EnableKeyboard(true) end
        Tween(CAMERA_TIME, function(p)
            hooks.camera(Ease(p))
            self:SetAlpha(p)
        end, function()
            if any and hooks.display then  -- (in on him now: the drums on the painted till's window)
                register:Fit(hooks.display())
                register:ShowValue(0)
                register:Show()
            end
            if any and hooks.receipt then  -- (and the receipt under it)
                receipt:Place(hooks.receipt())
                receipt:Show()
            end
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
        register:Hide()
        if not InCombatLockdown() then self:EnableKeyboard(false) end
        self:Hide()
    end
    return till
end
