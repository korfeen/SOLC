-- The Puzzle page in SOLC's sidebar (Guild section). Practice: pick any picture in the guild and a mode -
-- solve it as a puzzle (swap or sliding, 3x3-5x5) against the clock, or paint it (Paint.lua) before time runs
-- out. Best per mode and size: SOLCPuzzleDB.best["swap4"] = { time, moves }, ["paint16"] = { score }.

local _, ns = ...

local BOARD = 384  -- px, whatever the grid size
local MODES = { { key = "swap", label = "Swap pieces" }, { key = "sliding", label = "Sliding" }, { key = "paint", label = "Paint" } }
local MODE_HELP = {
    swap = "Click two pieces to swap them.",
    sliding = "Click a piece next to the gap to slide it in.",
    paint = "Copy the picture with its own colours before time runs out.",
}

local function FormatTime(seconds)
    return ("%d:%04.1f"):format(math.floor(seconds / 60), seconds % 60)
end
ns.FormatTime = FormatTime

-- Every picture in the guild: yours first, then synced players': { { traits, number, rarity, owner } }.
local function AllPictures()
    local list = {}
    for _, picture in ipairs(SOLC.GetPictures(nil)) do
        picture.owner = SOLC.MyName()
        list[#list + 1] = picture
    end
    for _, player in ipairs(SOLC.GetPlayers()) do
        for _, picture in ipairs(SOLC.GetPictures(player.key)) do
            picture.owner = player.name
            list[#list + 1] = picture
        end
    end
    return list
end

local function Create(parent)
    local UI = SOLC.UI
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    page.title, page.line = UI.CreateHeader(page)
    page.title:SetText("Puzzle")
    page.line:SetText("Practice: solve any picture in the guild against the clock. Duels and mint battles are coming.")

    page.board = ns.CreateBoard(page, BOARD)
    page.board:SetPoint("TOPLEFT", 12, -50)
    page.canvas = ns.CreateCanvas(page, BOARD)  -- the paint game's canvas, in the board's place
    page.canvas:SetPoint("TOPLEFT", 12, -50)
    page.canvas:Hide()

    -- The right column: picture, mode, start, clock.
    local right = CreateFrame("Frame", nil, page)
    right:SetPoint("TOPLEFT", page.board, "TOPRIGHT", 20, 0)
    right:SetPoint("BOTTOMRIGHT", -12, 12)
    page.practicePanel = right  -- swapped with the duel panel by the tabs (DuelPanel.lua)

    UI.CreateSection(right, "Picture", 0)
    page.thumb = CreateFrame("Frame", nil, right, "BackdropTemplate")
    page.thumb:SetSize(70, 70)
    page.thumb:SetPoint("TOPLEFT", 0, -20)
    page.thumb:SetBackdrop(UI.INSET_BACKDROP)
    page.thumb:SetBackdropColor(0, 0, 0, 0.6)
    page.thumb.canvas = CreateFrame("Frame", nil, page.thumb)
    page.thumb.canvas:SetSize(64, 64)
    page.thumb.canvas:SetPoint("CENTER")
    page.pictureText = right:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    page.pictureText:SetPoint("TOPLEFT", page.thumb, "TOPRIGHT", 10, -6)
    page.pictureText:SetPoint("RIGHT", right, "RIGHT")
    page.pictureText:SetJustifyH("LEFT")
    local function ArrowButton(label, delta, x)
        local button = CreateFrame("Button", nil, right, "UIPanelButtonTemplate")
        button:SetSize(32, 22)
        button:SetPoint("TOPLEFT", page.thumb, "TOPRIGHT", x, -40)
        button:SetText(label)
        button:SetScript("OnClick", function() page:Pick(delta) end)
        return button
    end
    page.prev = ArrowButton("<", -1, 10)
    page.next = ArrowButton(">", 1, 46)

    UI.CreateSection(right, "Mode", 108)
    page.modeButtons = {}
    for i, mode in ipairs(MODES) do
        local button = CreateFrame("Button", nil, right, "UIPanelButtonTemplate")
        button:SetSize(120, 24)
        button:SetPoint("TOPLEFT", (i - 1) * 126, -128)
        button:SetText(mode.label)
        button:SetScript("OnClick", function() page:SetMode(mode.key) end)
        page.modeButtons[mode.key] = button
    end
    page.help = right:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    UI.CreateSection(right, "Size", 162)
    page.sizeButtons = {}
    for i, size in ipairs(ns.SIZES) do
        local button = CreateFrame("Button", nil, right, "UIPanelButtonTemplate")
        button:SetSize(78, 24)
        button:SetPoint("TOPLEFT", (i - 1) * 84, -182)
        button:SetText(("%dx%d"):format(size, size))
        button:SetScript("OnClick", function() page:SetGridSize(size) end)
        page.sizeButtons[size] = button
    end
    page.paintSizeButtons = {}  -- shown instead of the puzzle sizes in paint mode
    for _, size in ipairs(ns.PAINT_SIZES) do
        local button = CreateFrame("Button", nil, right, "UIPanelButtonTemplate")
        button:SetHeight(24)
        button:SetText(("%dx%d"):format(size, size))
        button:SetScript("OnClick", function() page:SetGridSize(size) end)
        page.paintSizeButtons[size] = button
    end
    -- Rows fill the column's width (ns.SpreadRow), so there's no dead space on the right.
    local modeRow, sizeRow, paintSizeRow = {}, {}, {}
    for i, mode in ipairs(MODES) do modeRow[i] = page.modeButtons[mode.key] end
    for i, size in ipairs(ns.SIZES) do sizeRow[i] = page.sizeButtons[size] end
    for i, size in ipairs(ns.PAINT_SIZES) do paintSizeRow[i] = page.paintSizeButtons[size] end
    ns.SpreadRow(right, modeRow, 128)
    ns.SpreadRow(right, sizeRow, 182)
    ns.SpreadRow(right, paintSizeRow, 182)
    page.paintTimeButtons, page.paintTimeRow = {}, {}
    for i, seconds in ipairs(ns.PAINT_TIMES) do
        local button = CreateFrame("Button", nil, right, "UIPanelButtonTemplate")
        button:SetHeight(24)
        button:SetText(("%ds"):format(seconds))
        button:SetScript("OnClick", function() page:SetPaintTime(seconds) end)
        page.paintTimeButtons[seconds] = button
        page.paintTimeRow[i] = button
    end
    ns.SpreadRow(right, page.paintTimeRow, 214)
    page.help:SetPoint("TOPLEFT", 0, -248)
    page.help:SetPoint("RIGHT", right, "RIGHT")
    page.help:SetJustifyH("LEFT")

    page.start = CreateFrame("Button", nil, right, "UIPanelButtonTemplate")
    page.start:SetSize(246, 30)
    page.start:SetPoint("TOPLEFT", 0, -240)
    page.start:SetText("Start")
    page.start:SetScript("OnClick", function() page:StartPractice() end)
    ns.SpreadRow(right, { page.start }, 276)

    page.clock = right:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    page.clock:SetPoint("TOPLEFT", 0, -322)
    page.movesText = right:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    page.movesText:SetPoint("TOPLEFT", page.clock, "BOTTOMLEFT", 0, -6)
    page.result = right:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    page.result:SetPoint("TOPLEFT", page.movesText, "BOTTOMLEFT", 0, -10)
    page.result:SetPoint("RIGHT", right, "RIGHT")
    page.result:SetJustifyH("LEFT")

    -- Paint mode: save the finished painting, and look at saved ones (with replays).
    page.saveButton = CreateFrame("Button", nil, right, "UIPanelButtonTemplate")
    page.saveButton:SetHeight(24)
    page.saveButton:SetText("Save painting")
    page.saveButton:SetScript("OnClick", function() page:SaveLastPainting() end)
    page.galleryButton = CreateFrame("Button", nil, right, "UIPanelButtonTemplate")
    page.galleryButton:SetHeight(24)
    page.galleryButton:SetText("My paintings")
    page.galleryButton:SetScript("OnClick", function() page:OpenPaintings() end)
    ns.SpreadRow(right, { page.saveButton, page.galleryButton }, 412)

    page.bestHeading = UI.CreateSection(right, "Your best", 446)
    page.bestText = right:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    page.bestText:SetPoint("TOPLEFT", 0, -466)
    page.bestText:SetJustifyH("LEFT")

    page.empty = page:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    page.empty:SetPoint("CENTER", page.board)
    page.empty:SetWidth(BOARD - 40)
    page.empty:SetText("No pictures in the guild yet. Mint one in Collection to have something to solve.")

    -- The paint tools take the right column's place while painting (practice and duels, see DuelPanel.lua).
    page.toolsHolder = CreateFrame("Frame", nil, page)
    page.toolsHolder:SetAllPoints(right)
    page.paintTools = ns.CreatePaintTools(page.toolsHolder, page.canvas)
    page.viewer = ns.CreatePaintingViewer(page.toolsHolder, page.canvas)
    page.viewer.OnBack = function()
        right:Show()
        page:ShowPicture()
    end

    page.mode, page.size, page.paintSize, page.index = "swap", ns.DEFAULT_SIZE, ns.PAINT_SIZES[1], 1
    page.paintTime = ns.DEFAULT_PAINT_TIME
    local lastPainting  -- the finished practice painting, until saved: { size, palette, info }
    local started
    local painting  -- practice painting in progress: { target, palette }

    -- The clock runs while a puzzle is being solved.
    page:SetScript("OnUpdate", function()
        if started and page.board:IsPlaying() then page.clock:SetText(FormatTime(GetTime() - started)) end
    end)

    page.board.OnMove = function(moves) page.movesText:SetText(("%d moves"):format(moves)) end
    page.board.OnSolved = function(moves)
        local seconds = GetTime() - started
        started = nil
        page.clock:SetText(FormatTime(seconds))
        SOLCPuzzleDB.best = SOLCPuzzleDB.best or {}
        local best = SOLCPuzzleDB.best[page.mode .. page.size]
        if not best or seconds < best.time then
            SOLCPuzzleDB.best[page.mode .. page.size] = { time = seconds, moves = moves }
            page.result:SetText("|cff40ff40Solved - a new best!|r")
        else
            page.result:SetText(("Solved! Your best is %s."):format(FormatTime(best.time)))
        end
        page.start:SetText("Again")
        page:Update()
    end

    function page:Picture()
        local list = AllPictures()
        if #list == 0 then return nil, list end
        self.index = (self.index - 1) % #list + 1
        return list[self.index], list
    end

    -- Paint practice: the canvas and tools replace the board and the column until time is up or Done.
    function page:StartPainting(picture)
        local target = ns.PaintTarget(picture.traits, self.paintSize)
        painting = { target = target, palette = ns.PaintPalette(target) }
        self.board:Hide()
        self.canvas:Show()
        self.canvas:Start(self.paintSize, painting.palette)
        right:Hide()
        local seconds, size, palette = self.paintTime, self.paintSize, painting.palette
        lastPainting = nil
        self.paintTools:Begin(picture.traits, painting.palette, seconds, function(cells)
            local score = ns.PaintScore(cells, painting.target, painting.palette)
            lastPainting = { size = size, palette = palette, info = { traits = picture.traits, owner = picture.owner,
                number = picture.number, seconds = seconds, score = score } }
            painting = nil
            self.paintTools:End()
            right:Show()
            self.clock:SetText(("%.1f%%"):format(score))
            local key = "paint" .. self.paintSize
            SOLCPuzzleDB.best = SOLCPuzzleDB.best or {}
            local best = SOLCPuzzleDB.best[key]
            if not best or score > best.score then
                SOLCPuzzleDB.best[key] = { score = score }
                self.result:SetText("|cff40ff40A new best!|r Your painting is on the left.")
            else
                self.result:SetText(("Your best is %.1f%%. Your painting is on the left."):format(best.score))
            end
            self.start:SetText("Again")
            self:Update()
        end)
    end

    function page:SetPaintTime(seconds)
        self.paintTime = seconds
        self:Update()
    end

    -- Saves the finished practice painting (once).
    function page:SaveLastPainting()
        if not lastPainting then return end
        local count, dropped = ns.SavePainting(self.canvas, lastPainting.size, lastPainting.palette, lastPainting.info)
        lastPainting = nil
        SOLC.Refresh()  -- the Collection page lists saved paintings
        self.result:SetText(("Saved - %d in My paintings%s."):format(count, dropped and " (the oldest made room)" or ""))
        self:Update()
    end

    -- My paintings, in the right column; the canvas shows them.
    function page:OpenPaintings(at)
        if self.board:IsPlaying() then self:StopPractice() end
        lastPainting = nil  -- the canvas is about to show saved ones instead
        right:Hide()
        self.board:Hide()
        self.viewer:Open(at)
    end

    function page:ClosePaintings()
        if not self.viewer:IsShown() then return end
        self.canvas:StopReplay()
        self.viewer:Hide()
        right:Show()
        self:ShowPicture()
    end

    -- Back from a finished painting to showing the picture.
    function page:ShowPicture()
        self.canvas:Hide()
        local picture = self:Picture()
        self.board:SetShown(picture ~= nil)
        if picture then self.board:ShowWhole(picture.traits, self.size) end
    end

    -- Abandons paint practice in progress (switching tabs).
    function page:StopPainting()
        if not painting then return end
        painting = nil
        self.paintTools:End()
        right:Show()
        self:ShowPicture()
    end

    -- Stops a puzzle in progress and shows the picture whole again.
    function page:StopPractice()
        started = nil
        local picture = self:Picture()
        if picture then self.board:ShowWhole(picture.traits, self.size) else self.board:Stop() end
        self.start:SetText("Start")
        self.result:SetText("")
        self.clock:SetText("")
        self.movesText:SetText("")
    end

    function page:Pick(delta)
        if self.board:IsPlaying() then self:StopPractice() end
        self.index = self.index + delta
        self:Update()
        self:ShowPicture()
    end

    function page:SetMode(mode)
        if self.board:IsPlaying() then self:StopPractice() end
        self.mode = mode
        self.result:SetText("")
        self.clock:SetText("")
        self:ShowPicture()
        self:Update()
    end

    function page:SetGridSize(size)
        if self.board:IsPlaying() then self:StopPractice() end
        if self.mode == "paint" then self.paintSize = size else self.size = size end  -- canvas sizes: 16, 24
        self:ShowPicture()
        self:Update()
    end

    function page:StartPractice()
        if self.board:IsPlaying() then return self:StopPractice() end  -- the button reads "Stop" meanwhile
        local picture = self:Picture()
        if not picture then return end
        self.result:SetText("")
        self.clock:SetText("")
        if self.mode == "paint" then return self:StartPainting(picture) end
        self:ShowPicture()
        self.board:Start(picture.traits, self.mode, math.random(1, 2 ^ 30), self.size)
        started = GetTime()
        self.result:SetText("")
        self.movesText:SetText("0 moves")
        self.start:SetText("Stop")
    end

    function page:Update()
        local picture, list = self:Picture()
        self.empty:SetShown(picture == nil)
        if not self.canvas:IsShown() then self.board:SetShown(picture ~= nil) end
        self.start:SetEnabled(picture ~= nil)
        self.prev:SetEnabled(#list > 1)
        self.next:SetEnabled(#list > 1)
        self.thumb.canvas:SetShown(picture ~= nil)
        if picture then
            SOLC.RenderPicture(self.thumb.canvas, picture.traits)
            self.thumb:SetBackdropBorderColor(SOLC.RarityColor(picture.rarity))
            self.pictureText:SetText(("%s's #%d\n%s"):format(picture.owner, picture.number, SOLC.RarityText(picture.rarity)))
        else
            self.pictureText:SetText("")
        end
        for key, button in pairs(self.modeButtons) do
            if key == self.mode then button:LockHighlight() else button:UnlockHighlight() end
        end
        local paintMode = self.mode == "paint"
        for size, button in pairs(self.sizeButtons) do
            button:SetShown(not paintMode)
            if size == self.size then button:LockHighlight() else button:UnlockHighlight() end
        end
        for size, button in pairs(self.paintSizeButtons) do
            button:SetShown(paintMode)
            if size == self.paintSize then button:LockHighlight() else button:UnlockHighlight() end
        end
        for seconds, button in pairs(self.paintTimeButtons) do
            button:SetShown(paintMode)
            if seconds == self.paintTime then button:LockHighlight() else button:UnlockHighlight() end
        end
        self.saveButton:SetShown(paintMode)
        self.galleryButton:SetShown(paintMode)
        self.saveButton:SetEnabled(lastPainting ~= nil and self.canvas:IsShown())
        self.help:SetText(MODE_HELP[self.mode])
        local best = SOLCPuzzleDB.best or {}
        local lines = {}
        if paintMode then
            for _, size in ipairs(ns.PAINT_SIZES) do
                local b = best["paint" .. size]
                lines[#lines + 1] = ("Paint %dx%d: %s"):format(size, size, b and ("%.1f%%"):format(b.score) or "-")
            end
            self.bestHeading:SetText("Your best paintings")
        else
            for _, mode in ipairs(MODES) do
                if mode.key ~= "paint" then
                    local b = best[mode.key .. self.size]
                    lines[#lines + 1] = ("%s: %s"):format(mode.label, b and ("%s (%d moves)"):format(FormatTime(b.time), b.moves) or "-")
                end
            end
            self.bestHeading:SetText(("Your best (%dx%d)"):format(self.size, self.size))
        end
        self.bestText:SetText(table.concat(lines, "\n"))
    end

    ns.page = page  -- for the duel tab and the challenge popup (DuelPanel.lua)
    ns.BuildDuelPanel(page)
    local first = page:Picture()
    if first then page.board:ShowWhole(first.traits, page.size) end
    return page
end

SOLC.RegisterPage({
    key = "puzzle", label = "Puzzle", section = "guild", order = 5.5,
    create = Create,
    refresh = function(page)
        if not page.board:IsPlaying() then page:Update() end
        page:UpdateDuel()
    end,
})

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, _, name)
    if name ~= "SOLC_Puzzle" then return end
    SOLCPuzzleDB = SOLCPuzzleDB or {}
    -- Best times from before grid sizes were all 4x4.
    local best = SOLCPuzzleDB.best
    for _, mode in ipairs({ "swap", "sliding" }) do
        if best and best[mode] then
            best[mode .. "4"] = best[mode .. "4"] or best[mode]
            best[mode] = nil
        end
    end
    self:UnregisterEvent("ADDON_LOADED")
end)


-- Saved paintings in SOLC's Collection page, after your pictures; a click opens them in My paintings.
SOLC.AddCollectionRows(function()
    local rows = {}
    for i, saved in ipairs(SOLCPuzzleDB and SOLCPuzzleDB.paintings or {}) do
        rows[#rows + 1] = {
            label = ("|cffd8b4ffPainting|r of %s's #%d"):format(saved.owner or "?", saved.number or 0),
            right = ("%.1f%%"):format(saved.score or 0),
            onClick = function()
                SOLC.OpenPage("puzzle")
                if not ns.page then return end
                ns.page:SetTab("practice")
                ns.page:SetMode("paint")
                ns.page:OpenPaintings(i)
            end,
            onEnter = function(row)
                local rarity = SOLC.PictureRarity(saved.traits)
                GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
                GameTooltip:AddLine(("Painting of %s's #%d %s"):format(saved.owner or "?", saved.number or 0, SOLC.RarityText(rarity)))
                GameTooltip:AddDoubleLine("Score", ("%.1f%%"):format(saved.score or 0), nil, nil, nil, 1, 1, 1)
                GameTooltip:AddDoubleLine("Canvas", ("%dx%d, %ds"):format(saved.size, saved.size, saved.seconds or 0), nil, nil, nil, 1, 1, 1)
                if saved.opponent then GameTooltip:AddDoubleLine("Duel", "vs " .. saved.opponent, nil, nil, nil, 1, 1, 1) end
                GameTooltip:AddDoubleLine("Painted", date("%Y-%m-%d %H:%M", saved.when or 0), nil, nil, nil, 1, 1, 1)
                GameTooltip:AddLine("Click to view and replay", 0.6, 0.6, 0.6)
                GameTooltip:Show()
            end,
        }
    end
    return rows
end)
