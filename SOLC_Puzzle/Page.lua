-- The Puzzle page in SOLC's sidebar (Guild section). For now: practice - pick any picture in the guild and
-- a mode and grid size, and solve it against the clock. Best times per mode and size:
-- SOLCPuzzleDB.best["swap4"] = { time, moves }.

local _, ns = ...

local BOARD = 384  -- px, whatever the grid size
local MODES = { { key = "swap", label = "Swap pieces" }, { key = "sliding", label = "Sliding" } }
local MODE_HELP = {
    swap = "Click two pieces to swap them.",
    sliding = "Click a piece next to the gap to slide it in.",
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
    page.help:SetPoint("TOPLEFT", 0, -216)
    page.help:SetPoint("RIGHT", right, "RIGHT")
    page.help:SetJustifyH("LEFT")

    page.start = CreateFrame("Button", nil, right, "UIPanelButtonTemplate")
    page.start:SetSize(246, 30)
    page.start:SetPoint("TOPLEFT", 0, -240)
    page.start:SetText("Start")
    page.start:SetScript("OnClick", function() page:StartPractice() end)

    page.clock = right:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    page.clock:SetPoint("TOPLEFT", 0, -290)
    page.movesText = right:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    page.movesText:SetPoint("TOPLEFT", page.clock, "BOTTOMLEFT", 0, -6)
    page.result = right:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    page.result:SetPoint("TOPLEFT", page.movesText, "BOTTOMLEFT", 0, -10)
    page.result:SetPoint("RIGHT", right, "RIGHT")
    page.result:SetJustifyH("LEFT")

    page.bestHeading = UI.CreateSection(right, "Your best", 384)
    page.bestText = right:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    page.bestText:SetPoint("TOPLEFT", 0, -404)
    page.bestText:SetJustifyH("LEFT")

    page.empty = page:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    page.empty:SetPoint("CENTER", page.board)
    page.empty:SetWidth(BOARD - 40)
    page.empty:SetText("No pictures in the guild yet. Mint one in Collection to have something to solve.")

    page.mode, page.size, page.index = "swap", ns.DEFAULT_SIZE, 1
    local started

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
        local picture = self:Picture()
        if picture then self.board:ShowWhole(picture.traits, self.size) end
    end

    function page:SetMode(mode)
        if self.board:IsPlaying() then self:StopPractice() end
        self.mode = mode
        self:Update()
    end

    function page:SetGridSize(size)
        if self.board:IsPlaying() then self:StopPractice() end
        self.size = size
        local picture = self:Picture()
        if picture then self.board:ShowWhole(picture.traits, size) end
        self:Update()
    end

    function page:StartPractice()
        if self.board:IsPlaying() then return self:StopPractice() end  -- the button reads "Stop" meanwhile
        local picture = self:Picture()
        if not picture then return end
        self.board:Start(picture.traits, self.mode, math.random(1, 2 ^ 30), self.size)
        started = GetTime()
        self.result:SetText("")
        self.movesText:SetText("0 moves")
        self.start:SetText("Stop")
    end

    function page:Update()
        local picture, list = self:Picture()
        self.empty:SetShown(picture == nil)
        self.board:SetShown(picture ~= nil)
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
        for size, button in pairs(self.sizeButtons) do
            if size == self.size then button:LockHighlight() else button:UnlockHighlight() end
        end
        self.help:SetText(MODE_HELP[self.mode])
        local best = SOLCPuzzleDB.best or {}
        local lines = {}
        for _, mode in ipairs(MODES) do
            local b = best[mode.key .. self.size]
            lines[#lines + 1] = ("%s: %s"):format(mode.label, b and ("%s (%d moves)"):format(FormatTime(b.time), b.moves) or "-")
        end
        self.bestText:SetText(table.concat(lines, "\n"))
        self.bestHeading:SetText(("Your best (%dx%d)"):format(self.size, self.size))
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

