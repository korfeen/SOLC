-- The Duel tab of the Puzzle page (Duel.lua does the duel itself). Right column: challenge an online
-- guildmate, answer a challenge, then at the duel table pick your offer, react and press Ready; during the race
-- the clocks. Over the board area, the duel table: both offers side by side like a trade window, with Ready
-- marks and reaction bubbles. Adds Practice / Duel tabs to the page; the board is shared with practice.

local _, ns = ...
local Duel = ns.Duel

local MODES = { { key = "swap", label = "Swap pieces" }, { key = "sliding", label = "Sliding" } }
local MODE_NAMES = { swap = "Swap pieces", sliding = "Sliding" }
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
    opponentText:SetPoint("TOPLEFT", 38, -24)
    opponentText:SetWidth(170)
    local opponentIndex, stakeIndex = 1, 1
    local mode, size = "swap", ns.DEFAULT_SIZE
    local prevOpponent = Button(setup, "<", 32, 0, 20, function() opponentIndex = opponentIndex - 1 page:UpdateDuel() end)
    local nextOpponent = Button(setup, ">", 32, 214, 20, function() opponentIndex = opponentIndex + 1 page:UpdateDuel() end)
    UI.CreateSection(setup, "Mode", 56)
    local modeButtons, sizeButtons = {}, {}
    for i, m in ipairs(MODES) do
        modeButtons[m.key] = Button(setup, m.label, 120, (i - 1) * 126, 76, function() mode = m.key page:UpdateDuel() end)
    end
    UI.CreateSection(setup, "Size", 110)
    for i, s in ipairs(ns.SIZES) do
        sizeButtons[s] = Button(setup, ("%dx%d"):format(s, s), 78, (i - 1) * 84, 130, function() size = s page:UpdateDuel() end)
    end

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
    local ready = CreateFrame("Button", nil, atTable, "UIPanelButtonTemplate")
    ready:SetSize(246, 30)
    ready:SetPoint("TOPLEFT", 0, -80)
    ready:SetScript("OnClick", function()
        local d = Duel.Get()
        if d then Duel.SetReady(not d.myReady) end
    end)
    UI.CreateSection(atTable, "React", 124)
    for i, r in ipairs(ns.REACTIONS) do
        local column, row = (i - 1) % 3, math.floor((i - 1) / 3)
        Button(atTable, r.text, 78, column * 84, 144 + row * 28, function() Duel.React(r.key) end)
    end
    local leave = Button(atTable, "Leave table", 246, 0, 214, function() Duel.Cancel() end)

    -- The main button for the other phases (Challenge / Withdraw / Accept / Give up / OK), and Decline.
    local action = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    action:SetSize(246, 30)
    local decline = Button(panel, "Decline", 246, 0, 0, function() Duel.Cancel() end)

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

    -- The countdown, big over the board (on its own frame: the pieces are child frames and would cover it).
    local countdownFrame = CreateFrame("Frame", nil, page.board)
    countdownFrame:SetAllPoints()
    countdownFrame:SetFrameLevel(page.board:GetFrameLevel() + 20)
    local countdown = countdownFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    countdown:SetPoint("CENTER")
    countdown:SetTextHeight(72)

    local function Place(region, y)
        region:ClearAllPoints()
        region:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -y)
    end

    function page:SetTab(key)
        local d = Duel.Get()
        if key == "practice" and d and (d.phase == "countdown" or d.phase == "racing") then return end
        if key == "duel" and self.board:IsPlaying() then self:StopPractice() end
        self.tab = key
        practicePanel:SetShown(key == "practice")
        panel:SetShown(key == "duel")
        for k, tab in pairs(tabs) do
            if k == key then tab:LockHighlight() else tab:UnlockHighlight() end
        end
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
        self.board:SetShown(not atTheTable)
        decline:Hide()
        action:Show()
        action:Enable()
        status:Show()
        status:SetFontObject("GameFontNormal")
        clock:SetText("")
        opponentLine:SetText("")
        countdown:SetText("")
        resultThumb:Hide()

        if not d then
            local opponents = Duel.OnlineGuildmates()
            if #opponents > 0 then opponentIndex = (opponentIndex - 1) % #opponents + 1 end
            local opponent = opponents[opponentIndex]
            opponentText:SetText(opponent or "|cff999999No guildmates online|r")
            prevOpponent:SetEnabled(#opponents > 1)
            nextOpponent:SetEnabled(#opponents > 1)
            for key, button in pairs(modeButtons) do
                if key == mode then button:LockHighlight() else button:UnlockHighlight() end
            end
            for s, button in pairs(sizeButtons) do
                if s == size then button:LockHighlight() else button:UnlockHighlight() end
            end
            Place(action, 166)
            action:SetText("Challenge")
            action:SetEnabled(opponent ~= nil)
            action:SetScript("OnClick", function()
                local ok, why = Duel.Challenge(opponent, mode, size)
                if not ok then SOLC.Print(why) end
            end)
            Place(status, 206)
            status:SetFontObject("GameFontHighlightSmall")
            status:SetText("You'll both put up a picture at the duel table and press Ready. The puzzle is one of the "
                .. "two pictures; the faster solver takes the other's.")
            return
        end

        local settings = ("%s, %dx%d"):format(MODE_NAMES[d.mode], d.size, d.size)
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
            status:SetText(("Racing %s: your %s vs their %s\n%s"):format(d.opponent,
                SOLC.RarityText(SOLC.PictureRarity(d.mine.traits)), SOLC.RarityText(SOLC.PictureRarity(d.theirs.traits)), settings))
            Place(clock, 80)
        elseif phase == "done" then
            local r = d.result
            Place(action, 0)
            action:SetText("OK")
            action:SetScript("OnClick", function() Duel.Clear() end)
            Place(status, 40)
            local times = ("You %s  -  %s %s"):format(r.myTime and ns.FormatTime(r.myTime) or "-", d.opponent,
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
            resultThumb:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -90)
            resultThumb:Show()
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
            clock:SetText(ns.FormatTime(d.myTime or Duel.Elapsed() or 0))
            if d.theirTime then
                opponentLine:SetText(("%s finished in %s%s"):format(d.opponent, ns.FormatTime(d.theirTime),
                    d.phase == "racing" and " - beat it!" or ""))
            else
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
    Duel.OnChange = function(d)
        if d and d.phase == "countdown" then
            if page.tab ~= "duel" then page:SetTab("duel") end
            page.board:Show()
            page.board:ShowWhole(d.puzzle, d.size)
        elseif d and d.phase == "done" then
            page.board:Stop()
        end
        page:UpdateDuel()
    end
    Duel.OnRaceStart = function(d)
        page.board:Start(d.puzzle, d.mode, d.seed, d.size)
    end
    Duel.OnReaction = function()
        pcall(PlaySound, SOUNDKIT and SOUNDKIT.IG_CHAT_EMOTE_BUTTON or 1115)
    end
    page:SetTab("practice")
end

-- A challenge arriving: a popup, also when the window is closed. "Open" shows the Duel tab to answer it.
StaticPopupDialogs["SOLC_PUZZLE_CHALLENGE"] = {
    text = "%s challenges you to a puzzle race!\n%s",
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
