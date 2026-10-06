-- The Duel tab of the Puzzle page (Duel.lua does the duel itself). Right column: challenge an online
-- guildmate, answer a challenge, then at the duel table pick your offer, react and press Ready; during the race
-- the clocks. Over the board area, the duel table: both offers side by side like a trade window, with Ready
-- marks and reaction bubbles. Adds Practice / Duel tabs to the page; the board is shared with practice.

local _, ns = ...
local Duel = ns.Duel

local MODES = { { key = "swap", label = "Swap pieces" }, { key = "sliding", label = "Sliding" }, { key = "paint", label = "Paint" } }
local MODE_NAMES = { swap = "Swap pieces", sliding = "Sliding", paint = "Paint" }
local BUBBLE_TIME = 4  -- seconds a reaction stays up

local function PictureLabel(owner, picture)
    return ("%s's #%d %s"):format(owner, picture.number or 0, SOLC.RarityText(SOLC.PictureRarity(picture.traits)))
end

local function Button(parent, label, width, x, y, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 24)
    button:SetPoint("TOPLEFT", x, -y)
    button:SetText(label)
    button:SetScript("OnClick", onClick)
    return button
end

-- One side of the duel table: a heading, the offered picture with a rarity border, its label, a Ready mark
-- and a reaction bubble above it.
local function TableCard(parent, heading, x, width)
    local UI = SOLC.UI
    local card = CreateFrame("Frame", nil, parent)
    card:SetSize(width, 290)
    card:SetPoint("TOPLEFT", x, -46)
    card.heading = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    card.heading:SetPoint("TOP", 0, 0)
    card.heading:SetText(heading)
    card.frame = CreateFrame("Frame", nil, card, "BackdropTemplate")
    card.frame:SetSize(width - 10, width - 10)
    card.frame:SetPoint("TOP", 0, -20)
    card.frame:SetBackdrop(UI.INSET_BACKDROP)
    card.frame:SetBackdropColor(0, 0, 0, 0.6)
    card.canvas = CreateFrame("Frame", nil, card.frame)
    card.canvas:SetSize(width - 16, width - 16)
    card.canvas:SetPoint("CENTER")
    card.empty = card.frame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    card.empty:SetPoint("CENTER")
    card.empty:SetWidth(width - 30)
    card.label = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    card.label:SetPoint("TOP", card.frame, "BOTTOM", 0, -6)
    card.ready = card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    card.ready:SetPoint("TOP", card.label, "BOTTOM", 0, -6)
    -- The bubble: above the picture, on its own frame so it draws over it.
    card.bubble = CreateFrame("Frame", nil, card, "BackdropTemplate")
    card.bubble:SetFrameLevel(card.frame:GetFrameLevel() + 10)
    card.bubble:SetPoint("BOTTOM", card.frame, "TOP", 0, -30)
    card.bubble:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14,
        insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    card.bubble:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    card.bubble.text = card.bubble:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    card.bubble.text:SetPoint("CENTER")
    card.bubble:Hide()

    function card:Set(offer, owner, emptyText, ready)
        self.canvas:SetShown(offer ~= nil)
        self.empty:SetShown(offer == nil)
        self.empty:SetText(emptyText or "")
        if offer then
            SOLC.RenderPicture(self.canvas, offer.traits)
            self.frame:SetBackdropBorderColor(SOLC.RarityColor(SOLC.PictureRarity(offer.traits)))
            self.label:SetText(PictureLabel(owner, offer))
        else
            self.frame:SetBackdropBorderColor(0.4, 0.4, 0.4)
            self.label:SetText("")
        end
        self.ready:SetText(ready and "|cff40ff40READY|r" or "|cff777777not ready|r")
    end

    function card:React(reaction)
        local show = reaction and GetTime() - reaction.at < BUBBLE_TIME
        self.bubble:SetShown(show and true or false)
        if show then
            self.bubble.text:SetText(ns.REACTION_TEXT[reaction.key])
            self.bubble:SetSize(self.bubble.text:GetStringWidth() + 28, 36)
        end
    end
    return card
end

function ns.BuildDuelPanel(page)
    local UI = SOLC.UI
    local practicePanel = page.practicePanel
    local panel = CreateFrame("Frame", nil, page)
    panel:SetAllPoints(practicePanel)
    panel:Hide()
    page.duelPanel = panel
    page.tab = "practice"

    -- Tabs, top right of the page.
    local tabs = {}
    local function Tab(key, label, x)
        local tab = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
        tab:SetSize(90, 22)
        tab:SetPoint("TOPRIGHT", x, -12)
        tab:SetText(label)
        tab:SetScript("OnClick", function() page:SetTab(key) end)
        tabs[key] = tab
    end
    Tab("duel", "Duel", -12)
    Tab("practice", "Practice", -106)

    -- The duel table, over the board area.
    local duelTable = CreateFrame("Frame", nil, page, "BackdropTemplate")
    duelTable:SetAllPoints(page.board)
    duelTable:SetFrameLevel(page.board:GetFrameLevel() + 30)
    duelTable:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    duelTable:Hide()
    duelTable.title = duelTable:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    duelTable.title:SetPoint("TOP", 0, -14)
    duelTable.settings = duelTable:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    duelTable.settings:SetPoint("BOTTOM", 0, 14)
    local cardWidth = 190
    local myCard = TableCard(duelTable, "You put up", 12, cardWidth)
    local theirCard = TableCard(duelTable, "", 12 + cardWidth + 10, cardWidth)

    -- Right column. Setting up a challenge: opponent, mode, size.
    local setup = CreateFrame("Frame", nil, panel)
    setup:SetAllPoints()
    UI.CreateSection(setup, "Opponent", 0)
    local opponentText = setup:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    local opponentIndex, stakeIndex = 1, 1
    local mode, size = "swap", ns.DEFAULT_SIZE
    local prevOpponent = Button(setup, "<", 32, 0, 20, function() opponentIndex = opponentIndex - 1 page:UpdateDuel() end)
    local nextOpponent = Button(setup, ">", 32, 0, 20, function() opponentIndex = opponentIndex + 1 page:UpdateDuel() end)
    nextOpponent:ClearAllPoints()
    nextOpponent:SetPoint("TOPRIGHT", setup, "TOPRIGHT", 0, -20)
    opponentText:SetPoint("LEFT", prevOpponent, "RIGHT", 4, 0)
    opponentText:SetPoint("RIGHT", nextOpponent, "LEFT", -4, 0)
    UI.CreateSection(setup, "Mode", 56)
    local modeButtons, sizeButtons = {}, {}
    for i, m in ipairs(MODES) do
        modeButtons[m.key] = Button(setup, m.label, 120, (i - 1) * 126, 76, function() mode = m.key page:UpdateDuel() end)
    end
    UI.CreateSection(setup, "Size", 110)
    for i, s in ipairs(ns.SIZES) do
        sizeButtons[s] = Button(setup, ("%dx%d"):format(s, s), 78, (i - 1) * 84, 130, function() size = s page:UpdateDuel() end)
    end
    local paintSize = ns.PAINT_SIZES[1]
    local paintSizeButtons = {}  -- instead of the puzzle sizes when Paint is picked
    for _, s in ipairs(ns.PAINT_SIZES) do
        paintSizeButtons[s] = Button(setup, ("%dx%d"):format(s, s), 78, 0, 130, function() paintSize = s page:UpdateDuel() end)
    end
    -- Rows fill the column's width (ns.SpreadRow).
    local modeRow, sizeRow, paintSizeRow = {}, {}, {}
    for i, m in ipairs(MODES) do modeRow[i] = modeButtons[m.key] end
    for i, s in ipairs(ns.SIZES) do sizeRow[i] = sizeButtons[s] end
    for i, s in ipairs(ns.PAINT_SIZES) do paintSizeRow[i] = paintSizeButtons[s] end
    ns.SpreadRow(setup, modeRow, 76)
    ns.SpreadRow(setup, sizeRow, 130)
    ns.SpreadRow(setup, paintSizeRow, 130)
    local paintTime = ns.DEFAULT_PAINT_TIME
    local timeButtons, timeRow = {}, {}
    for i, seconds in ipairs(ns.PAINT_TIMES) do
        timeButtons[seconds] = Button(setup, ("%ds"):format(seconds), 50, 0, 162, function() paintTime = seconds page:UpdateDuel() end)
        timeRow[i] = timeButtons[seconds]
    end
    ns.SpreadRow(setup, timeRow, 162)

    -- Whether others can challenge you (Duel.AcceptsDuels); also /solcpuzzle duels.
    local accept = CreateFrame("CheckButton", nil, setup, "UICheckButtonTemplate")
    accept:SetSize(24, 24)
    accept:SetPoint("TOPLEFT", 0, -310)
    accept.label = setup:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    accept.label:SetPoint("LEFT", accept, "RIGHT", 4, 0)
    accept.label:SetText("Accept duel challenges")
    accept.note = setup:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    accept.note:SetPoint("TOPLEFT", accept, "BOTTOMLEFT", 4, -2)
    accept.note:SetPoint("RIGHT", setup, "RIGHT")
    accept.note:SetJustifyH("LEFT")
    accept.note:SetText("Off: challenges are declined without asking you. Someone you decline can't challenge you again for a minute.")
    accept:SetScript("OnClick", function(self) Duel.SetAcceptDuels(self:GetChecked()) end)

    -- At the table: your offer, Ready, reactions, leave.
    local atTable = CreateFrame("Frame", nil, panel)
    atTable:SetAllPoints()
    UI.CreateSection(atTable, "Your offer", 0)
    local offerText = atTable:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    offerText:SetPoint("TOPLEFT", 0, -22)
    offerText:SetPoint("RIGHT", atTable, "RIGHT")
    offerText:SetJustifyH("LEFT")
    local function StepOffer(delta)
        local stakes = SOLC.GetPictures(nil)
        if #stakes == 0 then return end
        stakeIndex = (stakeIndex - 1 + delta) % #stakes + 1
        Duel.Offer(stakes[stakeIndex])
    end
    local prevOffer = Button(atTable, "< Previous", 120, 0, 44, function() StepOffer(-1) end)
    local nextOffer = Button(atTable, "Next >", 120, 126, 44, function() StepOffer(1) end)
    ns.SpreadRow(atTable, { prevOffer, nextOffer }, 44)
    local ready = CreateFrame("Button", nil, atTable, "UIPanelButtonTemplate")
    ready:SetSize(246, 30)
    ready:SetPoint("TOPLEFT", 0, -80)
    ready:SetScript("OnClick", function()
        local d = Duel.Get()
        if d then Duel.SetReady(not d.myReady) end
    end)
    ns.SpreadRow(atTable, { ready }, 80)
    UI.CreateSection(atTable, "React", 124)
    local reactionRows = { {}, {} }
    for i, r in ipairs(ns.REACTIONS) do
        local column, row = (i - 1) % 3, math.floor((i - 1) / 3)
        local list = reactionRows[row + 1]
        list[#list + 1] = Button(atTable, r.text, 78, column * 84, 144 + row * 28, function() Duel.React(r.key) end)
    end
    ns.SpreadRow(atTable, reactionRows[1], 144)
    ns.SpreadRow(atTable, reactionRows[2], 172)
    local leave = Button(atTable, "Leave table", 246, 0, 214, function() Duel.Cancel() end)
    ns.SpreadRow(atTable, { leave }, 214)

    -- The main button for the other phases (Challenge / Withdraw / Accept / Give up / OK), and Decline.
    local action = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    action:SetHeight(30)
    action.fullWidth = true
    local decline = Button(panel, "Decline", 246, 0, 0, function() Duel.Cancel() end)
    decline.fullWidth = true
    local saveDuel = Button(panel, "Save my painting", 246, 0, 0, function()
        local d = Duel.Get()
        if not d or not d.painting or d.painting.saved then return end
        -- Which picture it copied: theirs or yours (the puzzle is one of the two offers).
        local info = d.painting.info
        local theirs = d.theirs and SOLC.TraitsToText(d.theirs.traits) == SOLC.TraitsToText(d.puzzle)
        info.owner = theirs and d.opponent or SOLC.MyName()
        info.number = theirs and d.theirs.number or d.mine.number
        local count = ns.SavePainting(page.canvas, d.painting.size, d.painting.palette, info)
        d.painting.saved = true
        SOLC.Refresh()  -- the Collection page lists saved paintings
        SOLC.Print(("Painting saved (%d in My paintings)."):format(count))
        page:UpdateDuel()
    end)
    saveDuel.fullWidth = true

    -- Status and the race clocks.
    local status = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    status:SetPoint("RIGHT", panel, "RIGHT")
    status:SetJustifyH("LEFT")
    local clock = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    local opponentLine = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    opponentLine:SetPoint("TOPLEFT", clock, "BOTTOMLEFT", 0, -8)
    opponentLine:SetPoint("RIGHT", panel, "RIGHT")
    opponentLine:SetJustifyH("LEFT")
    local resultThumb = TableCard(panel, "", 0, 150)
    resultThumb:Hide()

    -- Puzzle duels: the opponent's board live (their moves arrive once a second), with how far along they are.
    local live = CreateFrame("Frame", nil, panel)
    live:SetPoint("TOPLEFT", 0, -150)
    live:SetPoint("RIGHT", panel, "RIGHT")
    live:SetHeight(290)
    live:Hide()
    live.heading = live:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    live.heading:SetPoint("TOPLEFT", 0, 0)
    live.board = ns.CreateBoard(live, 180)
    live.board:SetPoint("TOPLEFT", 0, -18)
    live.bar = UI.CreateBar(live, 188, 0.3, 0.8, 0.3)
    live.bar:SetPoint("TOPLEFT", live.board, "BOTTOMLEFT", 0, -6)
    live.moves = live:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    live.moves:SetPoint("TOPLEFT", live.bar, "BOTTOMLEFT", 0, -4)
    local function UpdateLive(d)
        local inPlace, total = live.board:InPlace()
        live.bar:SetProgress(total > 0 and inPlace / total or 0, ("%d of %d pieces in place"):format(inPlace, total))
        live.moves:SetText(("%d moves"):format(d.theirLiveMoves or 0))
    end

    -- The countdown, big over the board (on its own frame: the pieces are child frames and would cover it).
    local countdownFrame = CreateFrame("Frame", nil, page.board)
    countdownFrame:SetAllPoints()
    countdownFrame:SetFrameLevel(page.board:GetFrameLevel() + 20)
    local countdown = countdownFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    countdown:SetPoint("CENTER")
    countdown:SetTextHeight(72)

    -- Moves a region to y in the column; text keeps the column's width (so it wraps instead of running on).
    local function Place(region, y)
        region:ClearAllPoints()
        region:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -y)
        if region.SetWordWrap or region.fullWidth then region:SetPoint("RIGHT", panel, "RIGHT") end
    end

    function page:SetTab(key)
        local d = Duel.Get()
        if key == "practice" and d and (d.phase == "countdown" or d.phase == "racing") then return end
        if key == "duel" and self.board:IsPlaying() then self:StopPractice() end
        if key == "duel" then
            self:StopPainting()
            self:ClosePaintings()
            self:CloseReplays()
        end
        self.tab = key
        practicePanel:SetShown(key == "practice")
        panel:SetShown(key == "duel")
        for k, tab in pairs(tabs) do
            if k == key then tab:LockHighlight() else tab:UnlockHighlight() end
        end
        self.line:SetText(key == "practice" and "Practice: solve any picture in the guild against the clock."
            or "Duel: challenge a guildmate. You both put up a picture; the faster solver takes the other's.")
        if key == "practice" then
            duelTable:Hide()
            self.board:Show()
            local picture = self:Picture()
            if picture then self.board:ShowWhole(picture.traits, self.size) end
            self:Update()
        else
            Duel.RequestRoster()
            self:UpdateDuel()
        end
    end

    -- Shows the duel's state.
    function page:UpdateDuel()
        if self.tab ~= "duel" then return end
        local d = Duel.Get()
        local phase = d and d.phase
        local atTheTable = phase == "table" or phase == "starting"
        setup:SetShown(not d)
        atTable:SetShown(atTheTable)
        duelTable:SetShown(atTheTable)
        local painting = d and d.mode == "paint" and (phase == "racing" or phase == "waiting" or phase == "done")
        self.board:SetShown(not atTheTable and not painting)
        self.canvas:SetShown(painting and true or false)
        panel:SetShown(not (painting and phase == "racing"))  -- the paint tools take the column while painting
        decline:Hide()
        saveDuel:Hide()
        action:Show()
        action:Enable()
        status:Show()
        status:SetFontObject("GameFontNormal")
        clock:SetText("")
        opponentLine:SetText("")
        countdown:SetText("")
        resultThumb:Hide()
        local showLive = d and d.mode ~= "paint" and d.liveStarted
            and (phase == "racing" or phase == "waiting" or phase == "done")
        live:SetShown(showLive and true or false)
        if showLive then live.heading:SetText(("%s's board"):format(d.opponent)) end

        if not d then
            local opponents = Duel.OnlineGuildmates()
            if #opponents > 0 then opponentIndex = (opponentIndex - 1) % #opponents + 1 end
            local opponent = opponents[opponentIndex]
            opponentText:SetText(opponent or "|cff999999No guildmates online|r")
            accept:SetChecked(Duel.AcceptsDuels())
            prevOpponent:SetEnabled(#opponents > 1)
            nextOpponent:SetEnabled(#opponents > 1)
            for key, button in pairs(modeButtons) do
                if key == mode then button:LockHighlight() else button:UnlockHighlight() end
            end
            for s, button in pairs(sizeButtons) do
                button:SetShown(mode ~= "paint")
                if s == size then button:LockHighlight() else button:UnlockHighlight() end
            end
            for s, button in pairs(paintSizeButtons) do
                button:SetShown(mode == "paint")
                if s == paintSize then button:LockHighlight() else button:UnlockHighlight() end
            end
            for seconds, button in pairs(timeButtons) do
                button:SetShown(mode == "paint")
                if seconds == paintTime then button:LockHighlight() else button:UnlockHighlight() end
            end
            Place(action, 200)
            action:SetText("Challenge")
            action:SetEnabled(opponent ~= nil)
            action:SetScript("OnClick", function()
                local ok, why = Duel.Challenge(opponent, mode, mode == "paint" and paintSize or size,
                    mode == "paint" and paintTime or nil)
                if not ok then SOLC.Print(why) end
            end)
            Place(status, 240)
            status:SetFontObject("GameFontHighlightSmall")
            status:SetText("You'll both put up a picture at the duel table and press Ready. The puzzle is one of the "
                .. "two pictures; the faster solver takes the other's.")
            return
        end

        local settings = ("%s, %dx%d%s"):format(MODE_NAMES[d.mode], d.size, d.size,
            d.mode == "paint" and (", %ds"):format(d.seconds or ns.DEFAULT_PAINT_TIME) or "")
        if phase == "inviting" then
            Place(action, 0)
            action:SetText("Withdraw challenge")
            action:SetScript("OnClick", function() Duel.Cancel() end)
            Place(status, 40)
            status:SetText(("Waiting for %s to answer...\n%s"):format(d.opponent, settings))
        elseif phase == "invited" then
            Place(action, 0)
            action:SetText("Go to the duel table")
            action:SetScript("OnClick", function() Duel.Accept() end)
            Place(decline, 36)
            decline:Show()
            Place(status, 76)
            status:SetText(("%s challenges you to a puzzle race!\n%s"):format(d.opponent, settings))
        elseif atTheTable then
            action:Hide()
            local stakes = SOLC.GetPictures(nil)
            if not d.mine and #stakes > 0 and phase == "table" then
                Duel.Offer(stakes[(stakeIndex - 1) % #stakes + 1])  -- start with a picture on the table
                return
            end
            offerText:SetText(d.mine and PictureLabel(SOLC.MyName(), d.mine)
                or "|cff999999You have no pictures to put up. Mint one in Collection.|r")
            prevOffer:SetEnabled(phase == "table" and #stakes > 1)
            nextOffer:SetEnabled(phase == "table" and #stakes > 1)
            ready:SetText(phase == "starting" and "Starting..." or d.myReady and "Not ready" or "Ready")
            ready:SetEnabled(phase == "table" and d.mine ~= nil)
            leave:SetEnabled(true)
            Place(status, 250)
            status:SetFontObject("GameFontHighlightSmall")
            status:SetText(d.theirs and (d.myReady and d.theirReady and "Both ready - starting!"
                or "When you both press Ready, the race starts. Changing an offer clears both Ready marks.")
                or ("Waiting for %s to put up a picture..."):format(d.opponent))
            duelTable.title:SetText(("Duel with %s"):format(d.opponent))
            duelTable.settings:SetText(settings .. "  -  the puzzle will be one of these two pictures")
            theirCard.heading:SetText(("%s puts up"):format(d.opponent))
            myCard:Set(d.mine, SOLC.MyName(), "No picture", d.myReady)
            theirCard:Set(d.theirs, d.opponent, "Choosing...", d.theirReady)
        elseif phase == "countdown" or phase == "racing" or phase == "waiting" then
            Place(action, 0)
            action:SetText(phase == "waiting" and "Waiting..." or "Give up")
            action:SetEnabled(phase ~= "waiting")
            action:SetScript("OnClick", function() Duel.GiveUp() end)
            Place(status, 40)
            status:SetFontObject("GameFontHighlightSmall")
            status:SetText(((d.mode == "paint" and "Painting against %s" or "Racing %s") .. ": your %s vs their %s\n%s"):format(d.opponent,
                SOLC.RarityText(SOLC.PictureRarity(d.mine.traits)), SOLC.RarityText(SOLC.PictureRarity(d.theirs.traits)), settings))
            Place(clock, 80)
        elseif phase == "done" then
            local r = d.result
            Place(action, 0)
            action:SetText("OK")
            action:SetScript("OnClick", function()
                ns.SaveDuelReplay(d)  -- if their moves never came, with only yours
                Duel.Clear()
            end)
            local statusY = 40
            if d.mode == "paint" and d.painting then
                Place(saveDuel, 36)
                saveDuel:Show()
                saveDuel:SetEnabled(not d.painting.saved)
                saveDuel:SetText(d.painting.saved and "Saved" or "Save my painting")
                statusY = 70
            end
            Place(status, statusY)
            local times = d.mode == "paint"
                and ("You %s  -  %s %s"):format(r.myScore and ("%.1f%%"):format(r.myScore) or "-", d.opponent,
                    r.theirScore and ("%.1f%%"):format(r.theirScore) or "-")
                or ("You %s  -  %s %s"):format(r.myTime and ns.FormatTime(r.myTime) or "-", d.opponent,
                    r.theirTime and ns.FormatTime(r.theirTime) or "-")
            if r.won then
                status:SetText(("|cff40ff40You won!|r %s\n%s"):format(r.prize and "You get their picture:"
                    or "Waiting for their picture...", times))
                resultThumb:Set(d.theirs, d.opponent, nil, false)
            else
                status:SetText(("|cffff4040You lost|r (%s). %s takes your picture.\n%s"):format(r.reason, d.opponent, times))
                resultThumb:Set(d.mine, SOLC.MyName(), nil, false)
            end
            resultThumb.ready:SetText("")
            resultThumb:ClearAllPoints()
            resultThumb:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -(statusY + 50))
            resultThumb:Show()
            live:Hide()
        end
    end

    -- Every frame: reaction bubbles, the countdown, the clocks and Duel.Tick.
    page:HookScript("OnUpdate", function()
        if page.tab ~= "duel" then return end
        local d = Duel.Get()
        if not d then return end
        myCard:React(d.reactions.mine)
        theirCard:React(d.reactions.theirs)
        Duel.Tick()
        d = Duel.Get()
        if not d then return end
        if d.phase == "countdown" then
            countdown:SetText(tostring(math.max(1, math.ceil(d.countdownEnds - GetTime()))))
        elseif d.phase == "racing" or d.phase == "waiting" then
            countdown:SetText("")
            if d.mode == "paint" then
                clock:SetText(d.myScore and ("%.1f%%"):format(d.myScore) or "")
                opponentLine:SetText(d.theirScore and ("%s scored %.1f%%"):format(d.opponent, d.theirScore)
                    or ("%s is still painting..."):format(d.opponent))
            elseif d.theirTime then
                clock:SetText(ns.FormatTime(d.myTime or Duel.Elapsed() or 0))
                opponentLine:SetText(("%s finished in %s%s"):format(d.opponent, ns.FormatTime(d.theirTime),
                    d.phase == "racing" and " - beat it!" or ""))
            else
                clock:SetText(ns.FormatTime(d.myTime or Duel.Elapsed() or 0))
                opponentLine:SetText(("%s is still solving..."):format(d.opponent))
            end
        end
    end)

    -- Solving: during a duel it goes to the duel, otherwise to practice.
    local practiceSolved = page.board.OnSolved
    page.board.OnSolved = function(moves)
        local d = Duel.Get()
        if page.tab == "duel" and d and d.phase == "racing" then Duel.Solved(moves) else practiceSolved(moves) end
    end

    -- Duel events: the board shows the puzzle for the countdown, plays it, and freezes when it's over.
    -- Puzzle duels are saved as replays by themselves: once their moves arrive, 20 seconds after the end
    -- without them, or when you press OK.
    function ns.SaveDuelReplay(d)
        if not d or d.mode == "paint" or d.replaySaved or not d.result or not d.seed then return end
        d.replaySaved = true
        local theirs = d.theirs and SOLC.TraitsToText(d.theirs.traits) == SOLC.TraitsToText(d.puzzle)
        ns.SaveReplay({ kind = "duel", mode = d.mode, size = d.size, seed = d.seed, traits = d.puzzle,
            owner = theirs and d.opponent or SOLC.MyName(), number = theirs and d.theirs.number or d.mine.number,
            moves = d.myMoves, time = d.result.myTime, opponent = d.opponent, theirMoves = d.theirMoves,
            theirTime = d.result.theirTime, won = d.result.won })
    end

    Duel.OnChange = function(d)
        if d and d.liveStarted and d.theirMoves and not d.liveFinal then
            -- Their complete moves: rebuild their board exactly (live batches may have been cut short).
            d.liveFinal = true
            local all = ns.DecodeMoves(d.theirMoves)
            d.theirLiveMoves = #all
            live.board:Mirror(d.puzzle, d.mode, d.seed, d.size)
            live.board:ApplyMoves(all)
            UpdateLive(d)
        end
        -- After your race (solved, out of time or given up): send your moves; save once theirs are here.
        if d and d.mode ~= "paint" and (d.phase == "waiting" or d.phase == "done") and not d.myMoves then
            -- (no race yet, e.g. given up in the countdown: the board still holds an older recording)
            Duel.ShareMoves(d.startedAt and ns.EncodeMoves(page.board.recording) or "")
        end
        if d and d.phase == "done" and d.mode ~= "paint" and not d.replaySaved then
            if d.theirMoves then
                ns.SaveDuelReplay(d)
            elseif not d.replayTimer then
                d.replayTimer = true
                C_Timer.After(20, function() ns.SaveDuelReplay(d) end)
            end
        end
        if d and d.phase == "countdown" then
            if page.tab ~= "duel" then page:SetTab("duel") end
            page.canvas:Hide()
            page.board:Show()
            page.board:ShowWhole(d.puzzle, d.mode == "paint" and ns.DEFAULT_SIZE or d.size)
        elseif d and d.phase == "done" then
            page.board:Stop()
            page.paintTools:End()
        elseif not d then
            page.paintTools:End()
            page.canvas:Hide()
        end
        page:UpdateDuel()
    end
    Duel.OnRaceStart = function(d)
        if d.mode ~= "paint" then
            page.board:Start(d.puzzle, d.mode, d.seed, d.size)
            live.board:Mirror(d.puzzle, d.mode, d.seed, d.size)
            d.liveStarted, d.theirLiveMoves = true, 0
            UpdateLive(d)
            local sent = 0
            local ticker
            ticker = C_Timer.NewTicker(1, function()
                local recording = page.board.recording or {}
                if Duel.Get() ~= d or (d.phase ~= "racing" and d.phase ~= "waiting") then
                    ticker:Cancel()
                    return
                end
                if #recording > sent then
                    local fresh = {}
                    for i = sent + 1, #recording do fresh[#fresh + 1] = recording[i] end
                    sent = #recording
                    Duel.SendLive(ns.EncodeMoves(fresh))
                end
                if d.phase == "waiting" then ticker:Cancel() end  -- solved: that was the last batch
            end)
            page:UpdateDuel()
            return
        end
        local target = ns.PaintTarget(d.puzzle, d.size)
        local palette = ns.PaintPalette(target)
        page.board:Hide()
        page.canvas:Show()
        page.canvas:Start(d.size, palette)
        page.paintTools:Begin(d.puzzle, palette, d.seconds or ns.DEFAULT_PAINT_TIME, function(cells)
            page.paintTools:End()
            local score = ns.PaintScore(cells, target, palette)
            d.painting = { size = d.size, palette = palette, info = { traits = d.puzzle, seconds = d.seconds,
                score = score, opponent = d.opponent } }
            Duel.Painted(score)
        end)
    end
    Duel.OnLiveMoves = function(d, moves)
        if not d.liveStarted then return end
        live.board:ApplyMoves(moves)
        UpdateLive(d)
    end
    Duel.OnReaction = function()
        pcall(PlaySound, SOUNDKIT and SOUNDKIT.IG_CHAT_EMOTE_BUTTON or 1115)
    end
    page:SetTab("practice")
end

-- A challenge arriving: a popup, also when the window is closed. "Open" shows the Duel tab to answer it.
StaticPopupDialogs["SOLC_PUZZLE_CHALLENGE"] = {
    text = "%s challenges you to a duel!\n%s",
    button1 = "Open",
    button2 = DECLINE or "Decline",
    OnAccept = function()
        SOLC.OpenPage("puzzle")
        if ns.page then ns.page:SetTab("duel") end
    end,
    OnCancel = function(_, _, reason)
        if reason == "clicked" then Duel.Cancel() end
    end,
    timeout = 90,
    whileDead = true,
    hideOnEscape = true,
}
Duel.OnInvited = function(d)
    StaticPopup_Show("SOLC_PUZZLE_CHALLENGE", d.opponent, ("%s, %dx%d. You'll both put up a picture at the duel table.")
        :format(MODE_NAMES[d.mode], d.size, d.size))
end

-- The duel table opening or a race starting while the window is closed or on another page: show it, once
-- per phase (you can still close the window or look elsewhere afterwards).
local opener = CreateFrame("Frame")
local lastPhase
opener:SetScript("OnUpdate", function()
    local d = Duel.Get()
    local p = d and d.phase
    if p == lastPhase then return end
    lastPhase = p
    if (p == "table" or p == "countdown") and not (ns.page and ns.page:IsVisible() and ns.page.tab == "duel") then
        SOLC.OpenPage("puzzle")
        if ns.page then ns.page:SetTab("duel") end
    end
end)
