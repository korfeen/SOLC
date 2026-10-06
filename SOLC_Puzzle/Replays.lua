-- Puzzle replays: a solve is its scramble (mode, seed, size, picture) plus every move, so it can be played back.
-- Duels keep both players' moves (swapped after the race, Duel.ShareMoves) and replay side by side.
-- SOLCPuzzleDB.replays = { newest first, at most MAX_SAVED } of { when, kind = "practice" | "duel", mode, size,
-- seed, traits, owner, number (the puzzle's picture), moves, time, opponent, theirMoves, theirTime, won }.
-- moves = 5 characters per move: time in tenths of a second (3), the two slots swapped (1 each).

local _, ns = ...

local MAX_SAVED = 40
local CHARS = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ+/"
local VALUE = {}
for i = 1, #CHARS do VALUE[CHARS:sub(i, i)] = i - 1 end

local function Encode(n, width)
    local s = ""
    for _ = 1, width do
        s = CHARS:sub(n % 64 + 1, n % 64 + 1) .. s
        n = math.floor(n / 64)
    end
    return s
end

local function Decode(text)
    local n = 0
    for i = 1, #text do n = n * 64 + (VALUE[text:sub(i, i)] or 0) end
    return n
end

-- A board's recording (board.recording) as text, and back to { { t, a, b } }.
function ns.EncodeMoves(recording)
    local out = {}
    for i, m in ipairs(recording or {}) do
        out[i] = Encode(math.min(262143, math.floor(m.t * 10)), 3) .. Encode(m.a, 1) .. Encode(m.b, 1)
    end
    return table.concat(out)
end

function ns.DecodeMoves(text)
    local moves = {}
    for i = 1, #(text or ""), 5 do
        local chunk = text:sub(i, i + 4)
        if #chunk == 5 then
            moves[#moves + 1] = { t = Decode(chunk:sub(1, 3)) / 10, a = Decode(chunk:sub(4, 4)), b = Decode(chunk:sub(5, 5)) }
        end
    end
    return moves
end

-- Saves a solve (see the fields above). Returns how many are saved, and whether the oldest had to go.
function ns.SaveReplay(entry)
    SOLCPuzzleDB.replays = SOLCPuzzleDB.replays or {}
    local list = SOLCPuzzleDB.replays
    local traits = {}
    for key, id in pairs(entry.traits) do traits[key] = id end
    entry.traits, entry.when = traits, time()
    table.insert(list, 1, entry)
    local dropped = false
    while #list > MAX_SAVED do
        table.remove(list)
        dropped = true
    end
    return #list, dropped
end

local MODE_NAMES = { swap = "Swap pieces", sliding = "Sliding" }

-- My replays, in the page's right column (page.toolsHolder): saved solves one at a time. Practice replays
-- play on the page's board; duels on two half-size boards side by side, in sync. viewer:Open(); viewer.OnBack.
function ns.CreateReplayViewer(page)
    local UI = SOLC.UI
    local viewer = CreateFrame("Frame", nil, page.toolsHolder)
    viewer:SetAllPoints()
    viewer:Hide()

    -- The two duel boards, over the main board's area.
    local pair = CreateFrame("Frame", nil, page)
    pair:SetAllPoints(page.board)
    pair:Hide()
    local sides = {}
    for i = 1, 2 do
        local side = CreateFrame("Frame", nil, pair)
        side:SetSize(200, 300)
        side:SetPoint("TOPLEFT", (i - 1) * 206, -20)
        side.name = side:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        side.name:SetPoint("TOP", 0, 18)
        side.board = ns.CreateBoard(side, 192)
        side.board:SetPoint("TOP", 0, 0)
        side.clock = side:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        side.clock:SetPoint("TOP", side.board, "BOTTOM", 0, -8)
        side.result = side:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        side.result:SetPoint("TOP", side.clock, "BOTTOM", 0, -4)
        sides[i] = side
    end

    local heading = UI.CreateSection(viewer, "My replays", 0)
    local reference = CreateFrame("Frame", nil, viewer, "BackdropTemplate")
    reference:SetSize(96, 96)
    reference:SetPoint("TOPLEFT", 0, -22)
    reference:SetBackdrop(UI.INSET_BACKDROP)
    reference:SetBackdropColor(0, 0, 0, 0.6)
    reference.canvas = CreateFrame("Frame", nil, reference)
    reference.canvas:SetSize(90, 90)
    reference.canvas:SetPoint("CENTER")
    local info = viewer:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    info:SetPoint("TOPLEFT", reference, "TOPRIGHT", 10, -4)
    info:SetPoint("RIGHT", viewer, "RIGHT")
    info:SetJustifyH("LEFT")
    local empty = viewer:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    empty:SetPoint("TOPLEFT", 0, -30)
    empty:SetPoint("RIGHT", viewer, "RIGHT")
    empty:SetJustifyH("LEFT")
    empty:SetText("No saved replays yet. Puzzle duels are saved by themselves; practice solves with Save replay.")

    local index = 1
    local function Button(label, onClick)
        local button = CreateFrame("Button", nil, viewer, "UIPanelButtonTemplate")
        button:SetHeight(24)
        button:SetText(label)
        button:SetScript("OnClick", onClick)
        return button
    end
    local prev = Button("< Previous", function() index = index - 1 viewer:Show1() end)
    local nextButton = Button("Next >", function() index = index + 1 viewer:Show1() end)
    local play = Button("Replay", function() viewer:Play(1) end)
    local playFast = Button("Replay 4x", function() viewer:Play(4) end)
    local delete = Button("Delete", function()
        local list = SOLCPuzzleDB.replays or {}
        if list[index] then table.remove(list, index) end
        viewer:Show1()
    end)
    local back = Button("Back", function() viewer:Close() end)
    ns.SpreadRow(viewer, { prev, nextButton }, 130)
    ns.SpreadRow(viewer, { play, playFast }, 160)
    ns.SpreadRow(viewer, { delete }, 196)
    ns.SpreadRow(viewer, { back }, 232)
    local status = viewer:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    status:SetPoint("TOPLEFT", 0, -270)
    status:SetPoint("RIGHT", viewer, "RIGHT")
    status:SetJustifyH("LEFT")

    local function StopAll()
        page.board:StopReplay()
        for _, side in ipairs(sides) do side.board:StopReplay() end
    end

    local function Current() return (SOLCPuzzleDB.replays or {})[index] end

    -- Shows the replay at index (wrapping around) before it's played: the picture whole.
    function viewer:Show1()
        StopAll()
        status:SetText("")
        local list = SOLCPuzzleDB.replays or {}
        local has = #list > 0
        if has then index = (index - 1) % #list + 1 end
        heading:SetText(has and ("My replays (%d of %d)"):format(index, #list) or "My replays")
        empty:SetShown(not has)
        reference:SetShown(has)
        for _, button in ipairs({ prev, nextButton }) do button:SetEnabled(#list > 1) end
        for _, button in ipairs({ play, playFast, delete }) do button:SetEnabled(has) end
        local r = Current()
        local duel = r and r.kind == "duel"
        page.canvas:Hide()
        pair:SetShown(duel and true or false)
        page.board:SetShown(r ~= nil and not duel)
        if not r then
            info:SetText("")
            return
        end
        SOLC.RenderPicture(reference.canvas, r.traits)
        local rarity = SOLC.PictureRarity(r.traits)
        reference:SetBackdropBorderColor(SOLC.RarityColor(rarity))
        local who = duel and ("Duel vs %s - %s"):format(r.opponent or "?", r.won and "|cff40ff40won|r" or "|cffff4040lost|r")
            or "Practice"
        info:SetText(("%s\n%s, %dx%d\n%s's #%d %s\n|cff999999%s|r"):format(who, MODE_NAMES[r.mode] or r.mode, r.size, r.size,
            r.owner or "?", r.number or 0, SOLC.RarityText(rarity), date("%Y-%m-%d %H:%M", r.when or 0)))
        if duel then
            for i, side in ipairs(sides) do
                local mine = i == 1
                side.name:SetText(mine and SOLC.MyName() or (r.opponent or "?"))
                side.board:ShowWhole(r.traits, r.size)
                local t = mine and r.time or r.theirTime
                side.clock:SetText(t and ns.FormatTime(t) or "-")
                side.result:SetText(mine == (r.won and true or false) and "|cff40ff40winner|r" or "")
            end
        else
            page.board:ShowWhole(r.traits, r.size)
            status:SetText(r.time and ("Solved in %s"):format(ns.FormatTime(r.time)) or "")
        end
    end

    -- Plays the current replay, speed times as fast; duels: both boards together.
    function viewer:Play(speed)
        local r = Current()
        if not r then return end
        StopAll()
        if r.kind == "duel" then
            local running = 0
            for i, side in ipairs(sides) do
                local moves = ns.DecodeMoves(i == 1 and r.moves or r.theirMoves)
                if #moves == 0 then
                    side.board:ShowWhole(r.traits, r.size)
                    side.clock:SetText("|cff999999no replay|r")
                    side.result:SetText(i == 2 and "Their moves didn't arrive." or "")
                else
                    running = running + 1
                    side.result:SetText("")
                    side.board:Replay(r.traits, r.mode, r.seed, r.size, moves, speed,
                        function(at, done) side.clock:SetText(("%s  -  %d moves"):format(ns.FormatTime(at), done)) end,
                        function()
                            running = running - 1
                            if running == 0 then status:SetText("Replay finished.") end
                        end)
                end
            end
            status:SetText(running > 0 and ("Replaying%s..."):format(speed > 1 and (" at %dx"):format(speed) or "") or "")
        else
            status:SetText(("Replaying%s..."):format(speed > 1 and (" at %dx"):format(speed) or ""))
            page.board:Replay(r.traits, r.mode, r.seed, r.size, ns.DecodeMoves(r.moves), speed,
                function(at, done) status:SetText(("%s  -  %d moves"):format(ns.FormatTime(at), done)) end,
                function() status:SetText(("Replay finished: %s."):format(r.time and ns.FormatTime(r.time) or "solved")) end)
        end
    end

    function viewer:Open(at)
        index = at or 1
        self:Show()
        self:Show1()
    end

    function viewer:Close()
        if not self:IsShown() then return end
        StopAll()
        pair:Hide()
        self:Hide()
        if self.OnBack then self.OnBack() end
    end
    return viewer
end
