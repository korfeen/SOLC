-- The puzzle board: a picture cut into a size x size grid (ns.SIZES) and scrambled, in one of two modes:
--   swap     click two pieces to swap them
--   sliding  the classic 15-puzzle: the bottom-right piece is left out, slide pieces into the gap
-- Scrambles come from a seed through our own random generator, so two players given the same seed and size
-- get exactly the same puzzle (math.random isn't the same across clients).

local _, ns = ...

ns.SIZES = { 3, 4, 5 }
ns.DEFAULT_SIZE = 4
local OUTLINE = 3  -- px, the selected / hover outline
local COLORS = { selected = { 1, 0.82, 0 }, target = { 0.3, 1, 0.3 }, hover = { 1, 1, 1 } }

-- Deterministic random numbers: rng(n) -> 1..n.
local function Random(seed)
    local state = seed % 2147483648
    return function(n)
        state = (state * 1103515245 + 12345) % 2147483648
        return math.floor(state / 65536) % n + 1
    end
end

local function Solved(slots)
    for i = 1, #slots do
        if slots[i] ~= i then return false end
    end
    return true
end

-- slots[i] = the piece in slot i (the last piece = the gap in sliding mode), scrambled from seed.
local function Scramble(mode, seed, size)
    local rng = Random(seed)
    local count = size * size
    local slots = {}
    for i = 1, count do slots[i] = i end
    repeat
        if mode == "sliding" then
            -- Random slides from the solved board, so it's always solvable; never straight back.
            local gap, previous = count, nil
            for _ = 1, 15 * count do
                local row, col = math.floor((gap - 1) / size), (gap - 1) % size
                local options = {}
                if row > 0 then options[#options + 1] = gap - size end
                if row < size - 1 then options[#options + 1] = gap + size end
                if col > 0 then options[#options + 1] = gap - 1 end
                if col < size - 1 then options[#options + 1] = gap + 1 end
                for i = #options, 1, -1 do
                    if options[i] == previous then table.remove(options, i) end
                end
                local from = options[rng(#options)]
                slots[gap], slots[from] = slots[from], slots[gap]
                previous, gap = gap, from
            end
        else
            for i = count, 2, -1 do
                local j = rng(i)
                slots[i], slots[j] = slots[j], slots[i]
            end
        end
    until not Solved(slots)
    return slots
end
ns.Scramble = Scramble

-- A board frame in parent, about pixels wide and high whatever the grid size. board:Start(traits, mode,
-- seed, size) scrambles a picture; board.OnMove(moves) and board.OnSolved(moves) are called as it's played;
-- board:Stop() freezes it; board:ShowWhole(traits, size) shows the picture uncut.
function ns.CreateBoard(parent, pixels)
    local board = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    board:SetSize(pixels + 8, pixels + 8)
    board:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    board:SetBackdropColor(0, 0, 0, 0.8)

    local size, pieceSize, pieces  -- the current grid
    local slots, mode, moves, selected, hovered, playing
    local sets = {}  -- [size] = pieces, made on first use

    -- Each piece is a clipping frame showing its part of a full-size copy of the picture.
    local function MakePieces(n, px)
        local list = {}
        for id = 1, n * n do
            local piece = CreateFrame("Button", nil, board)
            piece:SetSize(px, px)
            piece:SetClipsChildren(true)
            piece.picture = CreateFrame("Frame", nil, piece)
            piece.picture:SetSize(n * px, n * px)
            local row, col = math.floor((id - 1) / n), (id - 1) % n
            piece.picture:SetPoint("TOPLEFT", -col * px, row * px)
            -- An outline (four edges): gold = selected, green = would swap with it, white = hover. On its own
            -- frame above the picture: the picture is a child frame, and those draw over their parent's textures.
            piece.overlay = CreateFrame("Frame", nil, piece)
            piece.overlay:SetAllPoints()
            piece.overlay:SetFrameLevel(piece.picture:GetFrameLevel() + 2)
            piece.edges = {}
            for i, points in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" },
                { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
                local edge = piece.overlay:CreateTexture(nil, "OVERLAY")
                edge:SetPoint(points[1])
                edge:SetPoint(points[2])
                if i <= 2 then edge:SetHeight(OUTLINE) else edge:SetWidth(OUTLINE) end
                piece.edges[i] = edge
            end
            piece.tint = piece.overlay:CreateTexture(nil, "ARTWORK")
            piece.tint:SetAllPoints()
            piece.id = id
            piece:Hide()
            list[id] = piece
        end
        return list
    end

    local function SlotOf(id)
        for slot, pieceID in ipairs(slots) do
            if pieceID == id then return slot end
        end
    end

    local function Place()
        local gapID = size * size
        for slot, id in ipairs(slots) do
            local piece = pieces[id]
            local row, col = math.floor((slot - 1) / size), (slot - 1) % size
            piece:ClearAllPoints()
            piece:SetPoint("TOPLEFT", 4 + col * pieceSize, -4 - row * pieceSize)
            piece:SetShown(not (mode == "sliding" and id == gapID and playing))
        end
    end

    -- True if piece can move into the gap (sliding mode).
    local function Slidable(piece)
        local slot, gap = SlotOf(piece.id), SlotOf(size * size)
        local sameRow = math.floor((slot - 1) / size) == math.floor((gap - 1) / size)
        return (math.abs(slot - gap) == 1 and sameRow) or math.abs(slot - gap) == size
    end

    -- Outlines: the selected piece (swap), and the hovered one: green if clicking it would move or swap it.
    local function Paint()
        for _, piece in ipairs(pieces) do
            local state
            if playing and piece == selected then
                state = "selected"
            elseif playing and piece == hovered then
                if mode == "sliding" then
                    state = Slidable(piece) and "target" or nil
                else
                    state = selected and "target" or "hover"
                end
            end
            local color = state and COLORS[state]
            for _, edge in ipairs(piece.edges) do
                edge:SetShown(color ~= nil)
                if color then edge:SetColorTexture(color[1], color[2], color[3], 1) end
            end
            piece.tint:SetShown(state == "selected" or state == "target")
            if color then piece.tint:SetColorTexture(color[1], color[2], color[3], 0.18) end
        end
    end

    local function Moved()
        moves = moves + 1
        Place()
        if board.OnMove then board.OnMove(moves) end
        if Solved(slots) then
            playing = false
            Place()  -- shows the last piece in sliding mode
            if board.OnSolved then board.OnSolved(moves) end
        end
        Paint()
    end

    local function Click(piece)
        if not playing then return end
        local slot = SlotOf(piece.id)
        if mode == "sliding" then
            if Slidable(piece) then
                local gap = SlotOf(size * size)
                slots[slot], slots[gap] = slots[gap], slots[slot]
                Moved()
            end
        elseif not selected then
            selected = piece
            Paint()
        else
            local first = selected
            selected = nil
            if first ~= piece then  -- clicking the same piece again just deselects it
                local other = SlotOf(first.id)
                slots[slot], slots[other] = slots[other], slots[slot]
                Moved()
            else
                Paint()
            end
        end
    end

    -- The picture's size in UI units: about `pixels`, but a whole number of screen pixels that every grid size
    -- divides (a multiple of 60 for 3, 4 and 5), so every cut between pieces falls exactly on a screen pixel.
    -- Otherwise the game rounds each cut its own way and the picture shifts slightly between grid sizes.
    local function PictureSize()
        -- Screen pixels per UI unit: the effective scale is relative to a 768 pixel tall screen.
        local _, screenHeight = GetPhysicalScreenSize()
        local perUnit = board:GetEffectiveScale() * (screenHeight or 768) / 768
        local step = 60
        local screen = math.max(step, math.floor((pixels * perUnit + step / 2) / step) * step)
        return screen / perUnit
    end

    -- Sizes a set of pieces for the current picture size (it changes with the UI scale).
    local function Fit(list, n, px)
        for id, piece in ipairs(list) do
            piece:SetSize(px, px)
            piece.picture:SetSize(n * px, n * px)
            local row, col = math.floor((id - 1) / n), (id - 1) % n
            piece.picture:ClearAllPoints()
            piece.picture:SetPoint("TOPLEFT", -col * px, row * px)
        end
        list.px = px
    end

    -- Switches to a grid size (hiding the other sizes' pieces) and draws the picture into its pieces.
    local function Use(newSize, traits)
        if pieces and newSize ~= size then
            for _, piece in ipairs(pieces) do piece:Hide() end
        end
        local picture = PictureSize()
        board:SetSize(picture + 8, picture + 8)
        size, pieceSize = newSize, picture / newSize
        if sets[size] and sets[size].px ~= pieceSize then Fit(sets[size], size, pieceSize) end
        if not sets[size] then
            sets[size] = MakePieces(size, pieceSize)
            sets[size].px = pieceSize
            for _, piece in ipairs(sets[size]) do
                piece:SetScript("OnClick", Click)
                piece:SetScript("OnEnter", function(self) hovered = self Paint() end)
                piece:SetScript("OnLeave", function(self) if hovered == self then hovered = nil end Paint() end)
            end
        end
        pieces = sets[size]
        for _, piece in ipairs(pieces) do
            SOLC.RenderPicture(piece.picture, traits)
            -- Each piece would otherwise be nudged to whole screen pixels on its own, a little differently per
            -- grid size, so the picture seemed to shift when changing size.
            for _, layer in ipairs(piece.picture.layers or {}) do
                if layer.SetSnapToPixelGrid then layer:SetSnapToPixelGrid(false) end
                if layer.SetTexelSnappingBias then layer:SetTexelSnappingBias(0) end
            end
        end
    end

    function board:Start(traits, newMode, seed, newSize)
        Use(newSize or ns.DEFAULT_SIZE, traits)
        mode, moves, playing, selected = newMode, 0, true, nil
        slots = Scramble(mode, seed, size)
        Place()
        Paint()
    end

    -- Shows the picture whole (before a race starts, or to preview). Not "Show": that's the frame's own.
    function board:ShowWhole(traits, newSize)
        Use(newSize or size or ns.DEFAULT_SIZE, traits)
        playing, selected = false, nil
        slots = {}
        for i = 1, size * size do slots[i] = i end
        Place()
        Paint()
    end

    function board:Stop()
        playing, selected = false, nil
        if pieces then Paint() end
    end

    function board:IsPlaying() return playing end
    return board
end

-- Lays out rows of buttons across the full width of parent, evenly with gap pixels between them, and again
-- whenever parent's width changes. ns.SpreadRow(parent, { button, ... }, y) for a row at y below the top.
local function LayoutRows(parent)
    local width = parent:GetWidth()
    if not width or width <= 0 then return end
    for _, row in ipairs(parent.spreadRows) do
        local n = #row.buttons
        local w = (width - row.gap * (n - 1)) / n
        for i, button in ipairs(row.buttons) do
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", parent, "TOPLEFT", (i - 1) * (w + row.gap), -row.y)
            button:SetWidth(w)
        end
    end
end

function ns.SpreadRow(parent, buttons, y, gap)
    if not parent.spreadRows then
        parent.spreadRows = {}
        parent:HookScript("OnSizeChanged", LayoutRows)
    end
    parent.spreadRows[#parent.spreadRows + 1] = { buttons = buttons, y = y, gap = gap or 6 }
    LayoutRows(parent)
end
