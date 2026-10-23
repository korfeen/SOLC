-- Plinko: drop a ball through the pins into a prize slot (/solc plinko; a place in the window comes later). One free
-- drop a day (from the daily reset), after that the guild's "Plinko drop" price in points. You aim it along the top's
-- middle (PLINKO.AIM_W pixels wide), then it really bounces: wherever it lands is the prize (PRIZES: points back or
-- more, a spice for the minting pot, fuel, or a chest of a dungeon at your level). The prizes and odds are placeholders.
-- KillTrackerDB.plinko = { day, freeUsed, drops }; points won go to KillTrackerDB.points.plinko (Points.lua: added to
-- your balance, not to what you've earned, so it never raises your rank).
--
-- A board is data (DefaultBoard; the guild master and officers make their own in the board maker, kept on their
-- character as KillTrackerDB.plinkoBoard, and pass it on as a code: BoardCode / CodeBoard):
--   rows  = { { pins, speed, shift, spacing } }, top down (0 pins: a gap, its room kept; the board ends at the last row
--           with pins): a row's pins spacing pixels apart (0: spread evenly over the board's width), sliding sideways speed
--           pixels a second (negative: left) and wrapping round the board, shift: where they start, a fraction of their
--           spacing (pins close together: a cluster that sweeps across);
--   slots = { { width, prize } }: the prize slots left to right, each its share of the board's width (PLINKO.BOARD_W,
--           always the same: width 80 is twice as wide as 40); prize: a key of PRIZES.
-- Moving rows make where it lands depend on when it meets each row, not only where it's dropped: a still board has
-- sweet spots (one tried had a pixel giving chests 58% of the time). Check a board's odds by its code (a Node
-- simulation, every drop point x every moment) before it's anyone's.

local _, ns = ...
local UI = ns.UI
if not UI then return end

local NAME_FONT = "Interface\\AddOns\\SOLC\\Media\\Fonts\\GermaniaOne-Regular.ttf"
local ROUND = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"  -- (a white disc: pins and the ball)
local COIN = "Interface\\Icons\\INV_Misc_Coin_01"
local CHEST = "Interface\\AddOns\\SOLC\\Media\\Bounty\\chest"
local NOTHING = "Interface\\Icons\\INV_Misc_QuestionMark"
-- The board's measures (pixels; y down from its top) and its physics, in one table: Lua 5.1 lets a function see at most
-- 60 upvalues.
local PLINKO = {
    ROW_H = 30, TOP = 64, PEG_R = 4, BALL_R = 8, START_Y = 22, SLOT_H = 54, MARGIN = 24,
    BOARD_W = 360,  -- (the board's width, however many slots: they share it)
    AIM_W = 120,  -- (how wide the aim along the top's middle is)
    GRAVITY = 1100, BOUNCE = 0.3, JITTER = 20, DRAG = 6, MAX_SPEED = 650, STEP = 1 / 240,
    -- (what the board maker allows)
    -- (a row of 0 pins: a gap; spacing 0: even)
    ROWS = 16, PINS = { 0, 20 }, SPACING = { 0, 120 }, SPEED = { -200, 200 }, SLOTS = { 3, 15 }, WIDTH = { 15, 120 },
    -- (smashing the board while the ball falls: hold the mouse on it to charge (a ring round the mouse fills in
    -- SMASH_CHARGE seconds), let go to knock the ball away from there - SMASH pixels a second fully charged, a tap
    -- SMASH_TAP of it, and a hop up of SMASH_LIFT of it (only which side of the ball you let go on counts);
    -- SMASHES a drop, SMASH_WAIT seconds apart. Simulated: a player smashing perfectly toward a chest
    -- every drop, fully charged, gets one ~6% of the time, ~19% the 3x slot)
    SMASH = 200, SMASH_CHARGE = 0.8, SMASH_TAP = 0.15, SMASH_LIFT = 0.35, SMASHES = 2, SMASH_WAIT = 0.35,
}
-- What a slot can pay, in the order the maker's button goes through them.
local PRIZES = {
    chest = { kind = "chest", label = "Chest", icon = CHEST },
    x5 = { kind = "points", times = 5 }, x3 = { kind = "points", times = 3 }, x2 = { kind = "points", times = 2 },
    x1 = { kind = "points", times = 1 }, x05 = { kind = "points", times = 0.5 },
    -- (the slots' keys stay, as boards have them: they pay the Dream Bed's milk and stories now)
    frostwood = { kind = "fuel", key = "milk", label = "Milk" },
    shimmer = { kind = "fuel", key = "milk", label = "Milk x2", n = 2 },
    spice = { kind = "spice", label = "Spice" },
    bonk = { kind = "fuel", key = "bonk", label = "Bonk" },  -- (another night in the Dream Bed)
    none = { kind = "none", label = "Nothing", icon = NOTHING },
}
local PRIZE_ORDER = { "chest", "x5", "x3", "x2", "x1", "x05", "frostwood", "shimmer", "spice", "bonk", "none" }

-- The board everyone plays (until the guild has boards of its own): conveyor rows by turns left and right over the
-- slots' middles and their walls; a Node simulation of it: about 0.6% chests, ~9% at most for a drop perfect to the
-- pixel and the moment.
local function DefaultBoard()
    local b = { rows = {}, slots = {} }
    for r = 1, 12 do b.rows[r] = { pins = 9, speed = r % 2 == 1 and -30 or 30, shift = r % 2 == 1 and 0.5 or 0 } end
    for i, prize in ipairs({ "chest", "x3", "frostwood", "x1", "spice", "x1", "frostwood", "x3", "chest" }) do
        b.slots[i] = { width = 40, prize = prize }
    end
    return b
end
-- A board as a code to pass on ("R9,-30,0.5;9,30,0;...|S40,chest;40,x3;...") and back (nil if it isn't one).
local function BoardCode(b)
    local rows, slots = {}, {}
    for i, row in ipairs(b.rows) do rows[i] = ("%d,%d,%s,%d"):format(row.pins, row.speed, tostring(row.shift or 0), row.spacing or 0) end
    for i, slot in ipairs(b.slots) do slots[i] = ("%d,%s"):format(slot.width, slot.prize) end
    return "R" .. table.concat(rows, ";") .. "|S" .. table.concat(slots, ";")
end
local function CodeBoard(code)
    local r, s = (code or ""):match("^%s*R([^|]+)|S(.+)$")
    if not r then return end
    local b = { rows = {}, slots = {} }
    for part in r:gmatch("[^;]+") do
        local pins, speed, shift, spacing = part:match("^(%d+),(%-?%d+),([%d%.]+),?(%d*)$")
        if not pins then return end
        b.rows[#b.rows + 1] = { pins = tonumber(pins), speed = tonumber(speed), shift = tonumber(shift), spacing = tonumber(spacing) or 0 }
    end
    for width, prize in s:gmatch("(%d+),(%w+)") do
        if PRIZES[prize] then b.slots[#b.slots + 1] = { width = tonumber(width), prize = prize } end
    end
    local any = false
    for _, row in ipairs(b.rows) do if row.pins > 0 then any = true end end
    if not any or #b.rows > PLINKO.ROWS or #b.slots < PLINKO.SLOTS[1] then return end
    return b
end
-- The board in play: yours from the maker, or the default.
local function Board()
    local db = KillTrackerDB
    return db and db.plinkoBoard or DefaultBoard()
end

local function Cost() return ns.Config("plinkoCost") or 50 end

local Today = ns.Today  -- (Core.lua: the daily reset's day)
local function State()
    local db = KillTrackerDB
    db.plinko = db.plinko or { drops = 0 }
    if db.plinko.day ~= Today() then db.plinko.day, db.plinko.freeUsed = Today(), false end
    return db.plinko
end
-- Free drops given in an Ogre Godz tribute (Unlocks.lua): kept until used, after the day's own (state.gifted).
function ns.GiftPlinkoDrops(n)
    local state = State()
    state.gifted = (state.gifted or 0) + n
end
function ns.PlinkoFreeLeft()
    local state = State()
    return not state.freeUsed or (state.gifted or 0) > 0
end

-- A chest's dungeon: one at your level (Posters.lua's ranges), else the nearest below.
local function ChestDungeon()
    local level, fits, best, bestTop = UnitLevel("player"), {}, nil, -1
    for _, d in ipairs(ns.Dungeons and ns.Dungeons() or {}) do
        local range = ns.DUNGEON_LEVELS and ns.DUNGEON_LEVELS[d.key]
        if range and level >= range[1] and level <= range[2] then fits[#fits + 1] = d.key end
        if range and range[1] <= level and range[2] > bestTop then best, bestTop = d.key, range[2] end
    end
    return #fits > 0 and fits[math.random(#fits)] or best or "rfc"
end

-- Pays a slot's prize. Returns what it was, for the chat line.
local function Pay(prize)
    local db = KillTrackerDB
    if prize.kind == "points" then
        local won = math.floor(Cost() * prize.times + 0.5)
        db.points.plinko = (db.points.plinko or 0) + won
        if ns.Touch then ns.Touch(db.points) end
        return ("%d points"):format(won)
    elseif prize.kind == "fuel" then
        ns.AddIngredient(prize.key, prize.n or 1, true)
        return ns.IngredientName(prize.key)
    elseif prize.kind == "spice" then
        ns.AddIngredient("story", 1, true)
        return ns.IngredientName("story")
    elseif prize.kind == "chest" then
        local key = ChestDungeon()
        ns.AddChest(key)
        if ns.Tally then ns.Tally("jackpots") end  -- (the Plinko jackpots deed)
        local d = ns.DungeonByKey(key)
        ns.ShowToast("achievement", "Plinko jackpot!", (d and d.name or key) .. " chest", "Open it on your PIX page")
        return (d and d.name or key) .. " chest"
    end
    return "nothing"
end
local function PrizeIcon(prize)
    if prize.kind == "points" then return COIN end
    if prize.kind == "fuel" then return ns.IngredientIcon(prize.key) end
    if prize.kind == "spice" then return ns.IngredientIcon("story") end
    return prize.icon
end
local function PrizeLabel(prize)
    if prize.kind == "points" then return tostring(math.floor(Cost() * prize.times + 0.5)) end
    return prize.label
end

-- Built once -------------------------------------------------------------------------------------------------------

local panel, board
local Refresh, Drop, Smash, OnUpdate, Layout  -- (below)
local ball = { live = false }
-- The board laid out (Layout): its width, the slots' edges (edges[i]: slot i's right edge), where the slots start, and
-- for each row its y, spacing and pin textures.
local geo = { W = 360, edges = {}, slotY = 0, rows = {} }
local clock, ahead = 0, 0  -- (the board's time, stepped with the physics; what's left over of a frame)
local function PinX(row, k)  -- (row k's pin, 1..pins)
    return (row.shift * row.spacing + (k - 1) * row.spacing + row.speed * clock) % geo.W
end

local function Text(parent, size, color)
    local t = parent:CreateFontString(nil, "OVERLAY")
    t:SetFont(NAME_FONT, size, "")
    t:SetTextColor(unpack(color or { 0.96, 0.9, 0.78 }))
    t:SetShadowColor(0, 0, 0, 0.8)
    t:SetShadowOffset(1, -1)
    return t
end
local function At(region, x, y, size)  -- (its middle at x, y on the board)
    region:ClearAllPoints()
    region:SetPoint("CENTER", board, "TOPLEFT", x, -y)
    if size then region:SetSize(size, size) end
end
local function Btn(parent, w, h, text, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, h)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end

-- Tuning (the guild master and officers, to try values in game): the physics, each with - and + (shift: a bigger step),
-- kept on this character only (KillTrackerDB.plinkoTune) until they become the defaults above; RESET goes back to them.
local TUNE = {
    { key = "GRAVITY", label = "Gravity", step = 50, min = 200, max = 3000 },
    { key = "BOUNCE", label = "Bounce", step = 0.05, min = 0, max = 1 },
    { key = "JITTER", label = "Pin nudge", step = 2, min = 0, max = 150 },
    { key = "DRAG", label = "Sideways drag", step = 0.5, min = 0, max = 30 },
    { key = "MAX_SPEED", label = "Top speed", step = 25, min = 100, max = 2000 },
    { key = "AIM_W", label = "Aim width", step = 10, min = 20, max = 600 },
    { key = "SMASH", label = "Smash force", step = 20, min = 0, max = 1500 },
    { key = "SMASHES", label = "Smashes a drop", step = 1, min = 0, max = 20 },
    { key = "SMASH_LIFT", label = "Smash hop up", step = 0.1, min = 0, max = 5 },
}
local DEFAULTS = {}
for _, t in ipairs(TUNE) do DEFAULTS[t.key] = PLINKO[t.key] end
local function ApplyTune()
    local saved = KillTrackerDB and KillTrackerDB.plinkoTune or {}
    for _, t in ipairs(TUNE) do PLINKO[t.key] = saved[t.key] or DEFAULTS[t.key] end
end
local function BuildTune()
    local tune = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    tune:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    tune:SetBackdropColor(0, 0, 0, 0.85)
    tune:SetSize(210, 30 + #TUNE * 26 + 34)
    tune:SetPoint("TOPRIGHT", -10, -40)
    tune:SetFrameLevel(panel:GetFrameLevel() + 20)
    tune:Hide()
    local heading = Text(tune, 14, { 1, 0.82, 0.1 })
    heading:SetPoint("TOPLEFT", 10, -8)
    heading:SetText("Tune (this character only)")
    tune.rows = {}
    for i, t in ipairs(TUNE) do
        local y = -30 - (i - 1) * 26
        local label = Text(tune, 12)
        label:SetPoint("TOPLEFT", 10, y - 4)
        label:SetText(t.label)
        local value = Text(tune, 12, { 1, 1, 1 })
        value:SetPoint("TOPRIGHT", -62, y - 4)
        local function Nudge(sign)
            local db = KillTrackerDB
            db.plinkoTune = db.plinkoTune or {}
            local step = t.step * (IsShiftKeyDown() and 5 or 1)
            local v = math.max(t.min, math.min(t.max, PLINKO[t.key] + sign * step))
            v = math.floor(v / t.step + 0.5) * t.step  -- (no drift from adding 0.05s)
            db.plinkoTune[t.key] = v ~= DEFAULTS[t.key] and v or nil
            ApplyTune()
            panel:Refresh()
        end
        Btn(tune, 24, 20, "-", function() Nudge(-1) end):SetPoint("TOPRIGHT", -34, y)
        Btn(tune, 24, 20, "+", function() Nudge(1) end):SetPoint("TOPRIGHT", -8, y)
        tune.rows[i] = { t = t, value = value }
    end
    Btn(tune, 90, 22, "RESET", function()
        KillTrackerDB.plinkoTune = nil
        ApplyTune()
        panel:Refresh()
    end):SetPoint("BOTTOMLEFT", 10, 8)
    function tune:Draw()
        for _, row in ipairs(self.rows) do
            local v, changed = PLINKO[row.t.key], PLINKO[row.t.key] ~= DEFAULTS[row.t.key]
            row.value:SetText((changed and "|cffffd100%s|r" or "%s"):format(row.t.step < 1 and ("%.2f"):format(v) or tostring(v)))
        end
    end
    panel.tune = tune
end

-- The board maker (the guild master and officers): the rows (pins, speed) and the slots (width, prize), changed in
-- place on your own board (KillTrackerDB.plinkoBoard, made from the one in play the first time), redrawn as you go;
-- its code to copy, or one pasted in (Enter) to load; NEW BOARD: the default again.
local MAKER_LINES = 16
local function Mine()
    local db = KillTrackerDB
    if not db.plinkoBoard then db.plinkoBoard = CodeBoard(BoardCode(Board())) end  -- (a copy)
    return db.plinkoBoard
end
local function Changed()
    ball.live = false
    ball.tex:Hide()
    Layout()
    panel:Refresh()
end
local function BuildMaker()
    local maker = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    maker:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    maker:SetBackdropColor(0, 0, 0, 0.85)
    maker:SetSize(290, 40 + MAKER_LINES * 24 + 96)
    maker:SetPoint("TOPLEFT", 10, -40)
    maker:SetFrameLevel(panel:GetFrameLevel() + 20)
    maker:Hide()
    maker.tab = "rows"
    local heading = Text(maker, 14, { 1, 0.82, 0.1 })
    heading:SetPoint("TOPLEFT", 10, -8)
    heading:SetText("Board maker")
    maker.rowsTab = Btn(maker, 70, 20, "ROWS", function() maker.tab = "rows" maker:Draw() end)
    maker.rowsTab:SetPoint("TOPRIGHT", -84, -6)
    maker.slotsTab = Btn(maker, 70, 20, "SLOTS", function() maker.tab = "slots" maker:Draw() end)
    maker.slotsTab:SetPoint("TOPRIGHT", -8, -6)
    -- (a line: its number, two values each with - and +; or for a slot, its width and its prize's button)
    maker.lines = {}
    for i = 1, MAKER_LINES do
        local y = -34 - (i - 1) * 24
        local line = { n = Text(maker, 12, { 0.75, 0.68, 0.56 }) }
        line.n:SetPoint("TOPLEFT", 10, y - 4)
        line.n:SetText(tostring(i))
        -- (three values, each between its - and +: at x, the - button; the value; the + button)
        for n, part in ipairs({ { "a", 28 }, { "b", 112 }, { "c", 196 } }) do
            local key, x = part[1], part[2]
            line[key] = Text(maker, 12, { 1, 1, 1 })
            line[key]:SetPoint("TOPLEFT", x + 23, y - 4)
            line[key .. "Minus"] = Btn(maker, 20, 18, "-", function() maker:Nudge(i, key, -1) end)
            line[key .. "Minus"]:SetPoint("TOPLEFT", x, y)
            line[key .. "Plus"] = Btn(maker, 20, 18, "+", function() maker:Nudge(i, key, 1) end)
            line[key .. "Plus"]:SetPoint("TOPLEFT", x + 60, y)
        end
        line.prize = Btn(maker, 120, 18, "", nil)
        line.prize:SetPoint("TOPLEFT", 112, y)
        line.prize:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        line.prize:SetScript("OnClick", function(_, button) maker:NextPrize(i, button == "RightButton" and -1 or 1) end)
        maker.lines[i] = line
    end
    maker.header = Text(maker, 11, { 0.75, 0.68, 0.56 })
    maker.header:SetPoint("TOPLEFT", 30, -24)
    local bottom = -34 - MAKER_LINES * 24 - 4
    maker.add = Btn(maker, 106, 20, "+ ADD", function() maker:AddRemove(1) end)
    maker.add:SetPoint("TOPLEFT", 10, bottom)
    maker.remove = Btn(maker, 106, 20, "- REMOVE LAST", function() maker:AddRemove(-1) end)
    maker.remove:SetPoint("TOPRIGHT", -10, bottom)
    -- (the code: selected to copy with Ctrl+C; paste one in and press Enter to load it)
    maker.code = CreateFrame("EditBox", nil, maker, "InputBoxTemplate")
    maker.code:SetSize(212, 20)
    maker.code:SetPoint("TOPLEFT", 16, bottom - 28)
    maker.code:SetAutoFocus(false)
    maker.code:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    maker.code:SetScript("OnEscapePressed", function(self) self:ClearFocus() maker:Draw() end)
    maker.code:SetScript("OnEnterPressed", function(self)
        local b = CodeBoard(self:GetText())
        self:ClearFocus()
        if not b then ns.Print("That isn't a plinko board code.") maker:Draw() return end
        KillTrackerDB.plinkoBoard = b
        Changed()
    end)
    Btn(maker, 106, 20, "NEW BOARD", function()
        KillTrackerDB.plinkoBoard = nil
        Changed()
    end):SetPoint("TOPLEFT", 10, bottom - 54)
    function maker:Nudge(i, which, sign)
        local b, fast = Mine(), IsShiftKeyDown() and 5 or 1
        if self.tab == "rows" then
            for k = #b.rows + 1, i do b.rows[k] = { pins = 0, speed = 0, shift = k % 2 == 1 and 0.5 or 0, spacing = 0 } end
            local row = b.rows[i]
            if which == "a" then
                row.pins = math.max(PLINKO.PINS[1], math.min(PLINKO.PINS[2], row.pins + sign * fast))
            elseif which == "c" then
                row.spacing = math.max(PLINKO.SPACING[1], math.min(PLINKO.SPACING[2], (row.spacing or 0) + sign * 2 * fast))
            else
                row.speed = math.max(PLINKO.SPEED[1], math.min(PLINKO.SPEED[2], row.speed + sign * 5 * fast))
            end
        else
            local slot = b.slots[i]
            slot.width = math.max(PLINKO.WIDTH[1], math.min(PLINKO.WIDTH[2], slot.width + sign * 5 * fast))
        end
        Changed()
    end
    function maker:NextPrize(i, sign)
        local slot = Mine().slots[i]
        local at = 1
        for k, key in ipairs(PRIZE_ORDER) do if key == slot.prize then at = k end end
        slot.prize = PRIZE_ORDER[(at - 1 + sign) % #PRIZE_ORDER + 1]
        Changed()
    end
    function maker:AddRemove(sign)
        local b = Mine()
        local list, limits = b.slots, PLINKO.SLOTS  -- (slots only: every row has its line)
        if sign > 0 and #list < math.min(limits[2], MAKER_LINES) then
            local last = list[#list]
            list[#list + 1] = { width = last.width, prize = last.prize }
        elseif sign < 0 and #list > limits[1] then
            list[#list] = nil
        end
        Changed()
    end
    function maker:Draw()
        local b, rows = Board(), self.tab == "rows"
        self.rowsTab:SetEnabled(not rows)
        self.slotsTab:SetEnabled(rows)
        self.header:SetText(rows and "pins              speed (- left)       spacing" or "share of width     prize (right-click: back)")
        local list = rows and b.rows or b.slots
        self.add:SetShown(not rows)
        self.remove:SetShown(not rows)
        for i, line in ipairs(self.lines) do
            local item = list[i] or (rows and { pins = 0, speed = 0 }) or nil  -- (a row past the end: empty)
            line.n:SetShown(item ~= nil)
            for _, part in ipairs({ line.a, line.aMinus, line.aPlus }) do part:SetShown(item ~= nil) end
            for _, part in ipairs({ line.b, line.bMinus, line.bPlus, line.c, line.cMinus, line.cPlus }) do part:SetShown(item ~= nil and rows) end
            line.prize:SetShown(item ~= nil and not rows)
            if item and rows then
                line.a:SetText(item.pins == 0 and "|cff888888gap|r" or tostring(item.pins))
                line.b:SetText(item.speed == 0 and "still" or ("%s%d"):format(item.speed > 0 and "+" or "", item.speed))
                line.c:SetText((item.spacing or 0) == 0 and "even" or tostring(item.spacing))
            elseif item then
                line.a:SetText(tostring(item.width))
                line.prize:SetText(PrizeLabel(PRIZES[item.prize]) .. (PRIZES[item.prize].kind == "points" and " pts" or ""))
            end
        end
        if not self.code:HasFocus() then self.code:SetText(BoardCode(b)) self.code:SetCursorPosition(0) end
    end
    panel.maker = maker
end

local function Build()
    panel = CreateFrame("Frame", "SOLCPlinko", UIParent, "BackdropTemplate")
    panel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    panel:SetBackdropColor(0.08, 0.06, 0.05, 0.97)
    panel:EnableMouse(true)
    panel:Hide()
    panel:HookScript("OnHide", function()
        ball.live = false
        if ns.UI.ClearScreen then ns.UI.ClearScreen("Plinko") end
    end)
    panel.title = Text(panel, 28, { 1, 0.82, 0.1 })
    panel.title:SetPoint("TOP", 0, -12)
    panel.title:SetText("Plinko!")
    panel.line = Text(panel, 14)
    panel.line:SetPoint("TOP", panel.title, "BOTTOM", 0, -4)

    board = CreateFrame("Frame", nil, panel)
    board:SetPoint("TOP", 0, -64)
    board.back = board:CreateTexture(nil, "BACKGROUND")
    board.back:SetPoint("TOPLEFT", -PLINKO.MARGIN / 2, 0)
    board.back:SetPoint("BOTTOMRIGHT", PLINKO.MARGIN / 2, 0)
    board.back:SetColorTexture(0.2, 0.13, 0.08, 1)
    -- (where you can aim it: the top's middle, lit)
    board.aim = board:CreateTexture(nil, "BORDER")
    board.aim:SetColorTexture(1, 0.82, 0.3, 0.12)
    board.aim:SetPoint("TOP", board, "TOP", 0, 0)
    board.pins, board.slots, board.walls = {}, {}, {}  -- (pools: Layout shows as many as the board has)
    -- The ball, and its ghost along the top where the mouse aims it.
    ball.tex = board:CreateTexture(nil, "OVERLAY")
    ball.tex:SetTexture(ROUND)
    ball.tex:SetVertexColor(1, 0.78, 0.2)
    ball.tex:Hide()
    board.ghost = board:CreateTexture(nil, "OVERLAY")
    board.ghost:SetTexture(ROUND)
    board.ghost:SetVertexColor(1, 0.78, 0.2, 0.45)
    board.ghost:SetSize(PLINKO.BALL_R * 2, PLINKO.BALL_R * 2)

    panel.drop = Btn(panel, 320, 30, "", function() panel:Drop() end)
    panel.drop:SetPoint("TOP", board, "BOTTOM", 0, -14)
    board:EnableMouse(true)
    -- (falling: hold to charge a smash, let go to smash; else a click drops it)
    board:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" and ball.live and (ball.smashes or 0) > 0 and ball.wait <= 0 then
            ball.charging = 0
            board.ring:SetCooldown(GetTime(), PLINKO.SMASH_CHARGE)
            board.ring:Show()
        end
    end)
    board:SetScript("OnMouseUp", function(_, button)
        if button ~= "LeftButton" then return end
        if ball.charging then panel:Smash() elseif not ball.live then panel:Drop() end
    end)
    -- The charge: a ring round the mouse filling up (a cooldown swipe over a dark disc), red once it's full.
    board.ring = CreateFrame("Cooldown", nil, board, "CooldownFrameTemplate")
    board.ring:SetSize(46, 46)
    board.ring:SetFrameLevel(board:GetFrameLevel() + 10)
    board.ring:SetSwipeTexture(ROUND)
    board.ring:SetSwipeColor(1, 0.8, 0.2, 0.85)
    board.ring:SetReverse(true)  -- (filling, not emptying)
    board.ring:SetDrawEdge(false)
    if board.ring.SetDrawBling then board.ring:SetDrawBling(false) end
    if board.ring.SetHideCountdownNumbers then board.ring:SetHideCountdownNumbers(true) end
    board.ring.back = board.ring:CreateTexture(nil, "BACKGROUND")
    board.ring.back:SetTexture(ROUND)
    board.ring.back:SetVertexColor(0, 0, 0, 0.45)
    board.ring.back:SetAllPoints()
    board.ring.full = board.ring:CreateTexture(nil, "OVERLAY")
    board.ring.full:SetTexture(ROUND)
    board.ring.full:SetVertexColor(1, 0.25, 0.1, 0.8)
    board.ring.full:SetAllPoints()
    board.ring:Hide()
    panel.Refresh, panel.Drop, panel.Smash = Refresh, Drop, Smash
    panel:SetScript("OnUpdate", OnUpdate)
    BuildTune()
    BuildMaker()
    -- (the officers' buttons: the board maker, and tuning the physics)
    panel.makerButton = Btn(panel, 80, 22, "MAKER", function() panel.maker:SetShown(not panel.maker:IsShown()) Layout() panel:Refresh() end)
    panel.makerButton:SetPoint("TOPLEFT", 10, -10)
    panel.tuneButton = Btn(panel, 70, 22, "TUNE", function() panel.tune:SetShown(not panel.tune:IsShown()) Layout() panel:Refresh() end)
    panel.tuneButton:SetPoint("TOPRIGHT", -10, -10)
end

-- Lays the board in play out: its size, the rows' pins (as many as each has), the slots and the walls between them.
Layout = function()
    local b = Board()
    local W, total, sum = PLINKO.BOARD_W, 0, 0
    for _, slot in ipairs(b.slots) do total = total + slot.width end
    for i, slot in ipairs(b.slots) do  -- (each its share of the board's width)
        sum = sum + slot.width
        geo.edges[i] = W * sum / total
    end
    for i = #b.slots + 1, #geo.edges do geo.edges[i] = nil end
    geo.W = W
    local last = 1
    for r, data in ipairs(b.rows) do if data.pins > 0 then last = r end end
    geo.slotY = PLINKO.TOP + (last - 1) * PLINKO.ROW_H + 26
    geo.count = last
    board:SetSize(W, geo.slotY + PLINKO.SLOT_H)
    -- Rows.
    wipe(geo.rows)
    local used = 0
    for r, data in ipairs(b.rows) do
        if data.pins > 0 and r <= last then
            local spacing = (data.spacing or 0) > 0 and data.spacing or W / data.pins
            local row = { y = PLINKO.TOP + (r - 1) * PLINKO.ROW_H, spacing = spacing, speed = data.speed,
                shift = data.shift or 0, pins = {} }
            for k = 1, data.pins do
                used = used + 1
                local tex = board.pins[used]
                if not tex then
                    tex = board:CreateTexture(nil, "ARTWORK")
                    tex:SetTexture(ROUND)
                    tex:SetVertexColor(0.85, 0.75, 0.55)
                    tex:SetSize(PLINKO.PEG_R * 2, PLINKO.PEG_R * 2)
                    board.pins[used] = tex
                end
                tex:Show()
                row.pins[k] = tex
            end
            geo.rows[r] = row
        end
    end
    for i = used + 1, #board.pins do board.pins[i]:Hide() end
    -- Slots, and a wall between each two.
    for i, data in ipairs(b.slots) do
        local slot = board.slots[i]
        if not slot then
            slot = CreateFrame("Frame", nil, board)
            slot.fill = slot:CreateTexture(nil, "BORDER")
            slot.fill:SetAllPoints()
            slot.icon = slot:CreateTexture(nil, "ARTWORK")
            slot.icon:SetPoint("TOP", 0, -6)
            slot.label = Text(slot, 11)
            slot.label:SetPoint("TOP", slot.icon, "BOTTOM", 0, -3)
            slot.flash = 0
            board.slots[i] = slot
        end
        local left = geo.edges[i - 1] or 0
        local wide = geo.edges[i] - left
        slot:SetSize(wide - 2, PLINKO.SLOT_H)
        slot:ClearAllPoints()
        slot:SetPoint("TOPLEFT", board, "TOPLEFT", left + 1, -geo.slotY)
        slot.icon:SetSize(math.max(8, math.min(24, wide - 6)), math.max(8, math.min(24, wide - 6)))
        slot.prize = PRIZES[data.prize] or PRIZES.none
        slot:Show()
        if i > 1 then
            local wall = board.walls[i]
            if not wall then
                wall = board:CreateTexture(nil, "ARTWORK")
                wall:SetColorTexture(0.85, 0.75, 0.55)
                wall:SetSize(2, PLINKO.SLOT_H)
                board.walls[i] = wall
            end
            wall:ClearAllPoints()
            wall:SetPoint("TOP", board, "TOPLEFT", left, -geo.slotY)
            wall:Show()
        end
    end
    for i = #b.slots + 1, #board.slots do board.slots[i]:Hide() end
    for i = #b.slots + 1, #board.walls do if board.walls[i] then board.walls[i]:Hide() end end
    -- (as big as fits under the title and over the button, and between the side panels while they're open)
    local room = (panel:GetHeight() > 0 and panel:GetHeight() or 584) - 64 - 60
    local sides = (panel.maker:IsShown() or panel.tune:IsShown()) and 2 * 300 or 40
    local wide = (panel:GetWidth() > 0 and panel:GetWidth() or 827) - sides
    board:SetScale(math.min(1, room / (geo.slotY + PLINKO.SLOT_H), wide / (W + PLINKO.MARGIN)))
end

-- The mouse's x on the board.
local function MouseX()
    return GetCursorPosition() / board:GetEffectiveScale() - (board:GetLeft() or 0)
end
-- Where the mouse aims it along the top (board x), kept within the aim.
local function AimX()
    local x = MouseX()
    local half = math.min(PLINKO.AIM_W, geo.W) / 2
    return math.max(geo.W / 2 - half + PLINKO.BALL_R, math.min(geo.W / 2 + half - PLINKO.BALL_R, x))
end

-- One physics step: gravity, the pins, the side walls; into a slot once it's down there.
local function Step(dt)
    local P, W = PLINKO, geo.W
    ball.vy = ball.vy + P.GRAVITY * dt
    ball.vx = ball.vx * (1 - P.DRAG * dt)  -- (it slows sideways: a bell curve under where it's dropped, edges rare)
    ball.x, ball.y = ball.x + ball.vx * dt, ball.y + ball.vy * dt
    local R = P.PEG_R + P.BALL_R
    -- (the rows it could touch: the nearest one and those either side; in each, the nearest pin)
    local near = math.floor((ball.y - P.TOP) / P.ROW_H + 0.5)
    for r = near, near + 2 do
        local row = geo.rows[r]
        if row and math.abs(ball.y - row.y) < R then
            for k = 1, #row.pins do  -- (every pin of it: close together, it may touch two)
                local px = PinX(row, k)
                local dx, dy = ball.x - px, ball.y - row.y
                local d = math.sqrt(dx * dx + dy * dy)
                if d < R then
                    if d < 0.01 then dx, dy, d = (math.random() - 0.5), -1, 1 end
                    local nx, ny = dx / d, dy / d
                    ball.x, ball.y = px + nx * R, row.y + ny * R
                    local vn = (ball.vx - row.speed) * nx + ball.vy * ny  -- (against the moving pin)
                    if vn < 0 then
                        ball.vx, ball.vy = ball.vx - (1 + P.BOUNCE) * vn * nx, ball.vy - (1 + P.BOUNCE) * vn * ny
                    end
                    -- (a nudge along the pin's edge: no ball balances on one, and no two drops go quite the same way)
                    local kick = (math.random() * 2 - 1) * P.JITTER
                    ball.vx, ball.vy = ball.vx - ny * kick, ball.vy + nx * kick
                end
            end
        end
    end
    if ball.x < P.BALL_R then ball.x, ball.vx = P.BALL_R, math.abs(ball.vx) * P.BOUNCE end
    if ball.x > W - P.BALL_R then ball.x, ball.vx = W - P.BALL_R, -math.abs(ball.vx) * P.BOUNCE end
    local speed = math.sqrt(ball.vx * ball.vx + ball.vy * ball.vy)
    if speed > P.MAX_SPEED then ball.vx, ball.vy = ball.vx * P.MAX_SPEED / speed, ball.vy * P.MAX_SPEED / speed end
    -- (in the slots: between its walls, down to the bottom)
    if ball.y > geo.slotY then
        if not ball.slot then
            ball.slot = #geo.edges
            for i, edge in ipairs(geo.edges) do if ball.x < edge then ball.slot = i break end end
        end
        local left, right = (geo.edges[ball.slot - 1] or 0) + P.BALL_R + 1, geo.edges[ball.slot] - P.BALL_R - 1
        ball.x = right > left and math.max(left, math.min(right, ball.x)) or (left + right) / 2
        if ball.y > geo.slotY + P.SLOT_H - P.BALL_R - 4 then return true end
    end
end

function ns.ShowPlinko()
    if not ns.IsMember() then return ns.ShowTeaser() end
    if not panel then Build() end
    ApplyTune()
    local pageArea = ns.UI and ns.UI.pageArea
    panel:ClearAllPoints()
    if pageArea then
        if not pageArea:IsVisible() then ns.ToggleUI() end
        panel:SetParent(pageArea)
        panel:SetAllPoints(pageArea)
        panel:SetFrameStrata(pageArea:GetFrameStrata())
        panel:SetFrameLevel(pageArea:GetFrameLevel() + 50)
    else
        panel:SetParent(UIParent)
        panel:SetSize(900, 620)
        panel:SetPoint("CENTER")
        panel:SetFrameStrata("DIALOG")
    end
    panel:Show()
    Layout()
    if ns.UI.SetScreen then ns.UI.SetScreen("Plinko", "PLINK", function() panel:Hide() end) end
    panel:Refresh()
end

-- The prizes on the slots, your points, today's free drop and the buttons.
Refresh = function(self)
    for i = 1, #geo.edges do
        local slot = board.slots[i]
        slot.fill:SetColorTexture(1, 0.82, 0.3, slot.flash > 0 and 0.35 or (slot.prize.kind == "chest" and 0.16 or 0.06))
        slot.icon:SetTexture(PrizeIcon(slot.prize))
        slot.label:SetText(PrizeLabel(slot.prize))
    end
    local free = ns.PlinkoFreeLeft()
    self.line:SetText(("%d points  ·  %s"):format(ns.GetPoints().balance,
        free and "|cff55dd55your free drop today is waiting|r" or ("a drop costs %d points"):format(Cost())))
    if ball.live then  -- (while it falls: the smashes left)
        self.drop:SetText((ball.smashes or 0) > 0 and ("HOLD ON THE BOARD, LET GO: SMASH (%d)"):format(ball.smashes) or "NO SMASHES LEFT")
    else
        self.drop:SetText(free and "FREE DROP" or ("DROP  (%d points)"):format(Cost()))
    end
    self.drop:SetEnabled(not ball.live)
    board.aim:SetSize(math.min(PLINKO.AIM_W, geo.W), PLINKO.START_Y * 2)
    local officer = ns.CanEditConfig and ns.CanEditConfig() or false
    self.tuneButton:SetShown(officer)
    self.makerButton:SetShown(officer)
    if not officer then self.tune:Hide() self.maker:Hide() end
    if self.tune:IsShown() then self.tune:Draw() end
    if self.maker:IsShown() then self.maker:Draw() end
end

Drop = function(self)
    if ball.live then return end
    local state, db = State(), KillTrackerDB
    local gifted = state.freeUsed and (state.gifted or 0) > 0  -- (the day's own is used: a tribute's, if any)
    local free = not state.freeUsed or gifted
    if gifted then state.gifted = state.gifted - 1 end
    if not free then
        if ns.GetPoints().balance < Cost() then
            ns.Print(("Not enough points for a drop (%d needed)."):format(Cost()))
            return
        end
        db.points.spent = db.points.spent + Cost()
        if ns.Touch then ns.Touch(db.points) end
    end
    state.freeUsed, state.drops = true, (state.drops or 0) + 1
    if ns.CheckAchievements then ns.CheckAchievements() end  -- (the Plinko drops deeds)
    ball.live, ball.slot, ball.smashes, ball.wait = true, nil, PLINKO.SMASHES, 0
    ball.x, ball.y = AimX() + (math.random() * 2 - 1), PLINKO.START_Y
    ball.vx, ball.vy = (math.random() * 2 - 1) * 15, 0
    At(ball.tex, ball.x, ball.y, PLINKO.BALL_R * 2)
    ball.tex:Show()
    if PlaySound and SOUNDKIT then PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) end
    self:Refresh()
end

-- A smash of the board, let go after charging: the ball knocked away from the side you let go on (harder the longer it
-- charged) with a hop up, the board shaken (harder for a bigger smash).
Smash = function(self)
    local charge = ball.charging
    ball.charging = nil
    board.ring:Hide()
    if not ball.live or not charge or (ball.smashes or 0) <= 0 then return end
    local power = math.max(PLINKO.SMASH_TAP, charge)
    local away = ball.x - MouseX()  -- (only which side of the ball: how far off doesn't matter)
    local force = PLINKO.SMASH * power * (0.85 + math.random() * 0.3)
    ball.vx = ball.vx + (away >= 0 and 1 or -1) * force
    ball.vy = ball.vy - force * PLINKO.SMASH_LIFT
    ball.smashes, ball.wait = ball.smashes - 1, PLINKO.SMASH_WAIT
    board.shake = 0.15 + 0.25 * power
    if PlaySound and SOUNDKIT then PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF) end
    self:Refresh()
end

OnUpdate = function(self, elapsed)
    if not board or #geo.edges == 0 then return end
    -- (shaken by a smash: a quick rattle sideways, dying out)
    if (board.shake or 0) > 0 then
        board.shake = math.max(0, board.shake - elapsed)
        board:ClearAllPoints()
        board:SetPoint("TOP", panel, "TOP", math.sin(GetTime() * 70) * board.shake * 24, -64)
    end
    if ball.live and ball.wait > 0 then ball.wait = math.max(0, ball.wait - elapsed) end
    -- (charging: the ring at the mouse, the board trembling more as it fills; it landing meanwhile ends it)
    if ball.charging then
        if not ball.live then ball.charging = nil board.ring:Hide() end
    end
    if ball.charging then
        ball.charging = math.min(1, ball.charging + elapsed / PLINKO.SMASH_CHARGE)
        local x, y = GetCursorPosition()
        local scale = board:GetEffectiveScale()
        board.ring:ClearAllPoints()
        board.ring:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / UIParent:GetEffectiveScale(), y / UIParent:GetEffectiveScale())
        board.ring:SetScale(1 / scale * UIParent:GetEffectiveScale())  -- (the same size however the board is scaled)
        board.ring.full:SetShown(ball.charging >= 1)
        board.shake = math.max(board.shake or 0, 0.04 * ball.charging)
    end
    board.ghost:SetShown(not ball.live and board:IsMouseOver())
    if not ball.live then At(board.ghost, AimX(), PLINKO.START_Y) end
    for i = 1, #geo.edges do
        local slot = board.slots[i]
        if slot.flash > 0 then
            slot.flash = slot.flash - elapsed
            if slot.flash <= 0 then self:Refresh() end
        end
    end
    -- (the board's clock and the ball, in physics steps; the rows drawn where the clock puts them)
    ahead = ahead + math.min(elapsed, 0.1)
    local landed = false
    while ahead >= PLINKO.STEP do
        ahead = ahead - PLINKO.STEP
        clock = clock + PLINKO.STEP
        if ball.live and Step(PLINKO.STEP) then landed = true break end
    end
    for _, row in pairs(geo.rows) do  -- (with gaps)
        for k, tex in ipairs(row.pins) do At(tex, PinX(row, k), row.y) end
    end
    if not ball.live then return end
    if landed then
        ball.live = false
        local slot = board.slots[ball.slot]
        slot.flash = 1.2
        local what = Pay(slot.prize)
        ns.Print(("Plinko: |cffffd100%s|r!"):format(what))
        if PlaySound and SOUNDKIT then PlaySound(SOUNDKIT.LOOT_WINDOW_COIN_SOUND) end
        if ns.OnKillsChanged then ns.OnKillsChanged() end
        self:Refresh()
        C_Timer.After(1.2, function() if not ball.live then ball.tex:Hide() end end)
    end
    At(ball.tex, ball.x, ball.y)
end
