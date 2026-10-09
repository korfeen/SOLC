-- The paint tools, shown in the page's right column while painting (practice or a duel): the picture to copy,
-- its palette, brush sizes and fill, the time left and a Done button. ns.CreatePaintTools(parent, canvas);
-- tools:Begin(traits, palette, seconds, onDone, style) and tools:End(); tools:Remaining() in seconds.

local _, ns = ...

local TOOLS = { { key = "1", label = "Brush 1" }, { key = "2", label = "Brush 2" }, { key = "3", label = "Brush 3" },
    { key = "fill", label = "Fill" } }

function ns.CreatePaintTools(parent, canvas)
    local UI = SOLC.UI
    local tools = CreateFrame("Frame", nil, parent)
    tools:SetAllPoints()
    tools:Hide()

    UI.CreateSection(tools, "Paint this", 0)
    local reference = CreateFrame("Frame", nil, tools, "BackdropTemplate")
    reference:SetSize(126, 126)
    reference:SetPoint("TOPLEFT", 0, -20)
    reference:SetBackdrop(UI.INSET_BACKDROP)
    reference:SetBackdropColor(0, 0, 0, 0.6)
    reference.canvas = CreateFrame("Frame", nil, reference)
    reference.canvas:SetSize(120, 120)
    reference.canvas:SetPoint("CENTER")
    local timer = tools:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    timer:SetPoint("TOPLEFT", reference, "TOPRIGHT", 14, -10)
    local timerLabel = tools:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    timerLabel:SetPoint("TOPLEFT", timer, "BOTTOMLEFT", 0, -4)
    timerLabel:SetText("time left")

    -- Palette: swatches in two rows; the chosen one gets a gold outline.
    UI.CreateSection(tools, "Colours", 156)
    local swatches = {}
    local function Select(index)
        canvas.color = index
        for i, swatch in ipairs(swatches) do swatch.outline:SetShown(i == index) end
    end
    canvas.OnPick = Select
    local rows = { {}, {} }
    for i = 1, 12 do
        local swatch = CreateFrame("Button", nil, tools)
        swatch:SetHeight(30)
        swatch.fill = swatch:CreateTexture(nil, "ARTWORK")
        swatch.fill:SetPoint("TOPLEFT", 2, -2)
        swatch.fill:SetPoint("BOTTOMRIGHT", -2, 2)
        swatch.outline = swatch:CreateTexture(nil, "BACKGROUND")
        swatch.outline:SetAllPoints()
        swatch.outline:SetColorTexture(1, 0.82, 0)
        swatch.outline:Hide()
        swatch:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        swatch:SetScript("OnClick", function() Select(i) end)
        swatches[i] = swatch
        local list = rows[i <= 6 and 1 or 2]
        list[#list + 1] = swatch
    end
    ns.SpreadRow(tools, rows[1], 176, 4)
    ns.SpreadRow(tools, rows[2], 210, 4)

    -- Tools: brush sizes and fill.
    UI.CreateSection(tools, "Brush", 250)
    local toolButtons, toolRow = {}, {}
    local function SetTool(key)
        if key == "fill" then canvas.tool = "fill" else canvas.tool, canvas.brush = "brush", tonumber(key) end
        for k, button in pairs(toolButtons) do
            if k == key then button:LockHighlight() else button:UnlockHighlight() end
        end
    end
    for i, t in ipairs(TOOLS) do
        local button = CreateFrame("Button", nil, tools, "UIPanelButtonTemplate")
        button:SetHeight(24)
        button:SetText(t.label)
        button:SetScript("OnClick", function() SetTool(t.key) end)
        toolButtons[t.key] = button
        toolRow[i] = button
    end
    ns.SpreadRow(tools, toolRow, 270)
    local hint = tools:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", 0, -300)
    hint:SetPoint("RIGHT", tools, "RIGHT")
    hint:SetJustifyH("LEFT")
    hint:SetText("Click or drag to paint. Right-click the canvas to pick up a colour that's already there.")

    local done = CreateFrame("Button", nil, tools, "UIPanelButtonTemplate")
    done:SetHeight(30)
    done:SetText("Done")
    ns.SpreadRow(tools, { done }, 336)

    local endsAt, onDone
    tools:SetScript("OnUpdate", function()
        if not endsAt then return end
        local left = endsAt - GetTime()
        timer:SetText(("%d"):format(math.max(0, math.ceil(left))))
        if left <= 10 then timer:SetTextColor(1, 0.3, 0.3) else timer:SetTextColor(1, 0.82, 0) end  -- red near the end
        if left <= 0 then tools:Finish() end
    end)
    done:SetScript("OnClick", function() tools:Finish() end)

    -- Starts painting: the reference, the palette, the clock. onDone(cells) when time runs out or Done.
    function tools:Begin(traits, palette, seconds, doneCallback, style)
        SOLC.RenderPicture(reference.canvas, traits, style)
        reference:SetBackdropBorderColor(SOLC.RarityColor(SOLC.PictureRarity(traits)))
        for i, swatch in ipairs(swatches) do
            local c = palette[i]
            swatch:SetShown(c ~= nil)
            if c then swatch.fill:SetColorTexture(c[1], c[2], c[3]) end
        end
        Select(1)
        SetTool("1")
        endsAt, onDone = GetTime() + seconds, doneCallback
        done:Enable()
        self:Show()
    end

    -- Ends painting now (time up or Done): calls the onDone given to Begin, once.
    function tools:Finish()
        if not endsAt then return end
        endsAt = nil
        done:Disable()
        canvas:Stop()
        local callback = onDone
        onDone = nil
        if callback then callback(canvas.cells) end
    end

    -- Stops without calling onDone (painting abandoned).
    function tools:End()
        endsAt, onDone = nil, nil
        canvas:Stop()
        self:Hide()
    end

    function tools:Remaining() return endsAt and endsAt - GetTime() end
    return tools
end

-- My paintings: saved paintings (ns.SavePainting) one at a time, shown on the canvas, with what they copied,
-- the score and when, and Replay (the painting being made, stroke by stroke), Delete and Back.
-- ns.CreatePaintingViewer(parent, canvas); viewer:Open(); viewer.OnBack().
function ns.CreatePaintingViewer(parent, canvas)
    local UI = SOLC.UI
    local viewer = CreateFrame("Frame", nil, parent)
    viewer:SetAllPoints()
    viewer:Hide()

    local heading = UI.CreateSection(viewer, "My paintings", 0)
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
    empty:SetText("No saved paintings yet. Finish a painting and press Save painting.")

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
    local replay = Button("Replay", function() viewer:Replay(1) end)
    local replayFast = Button("Replay 4x", function() viewer:Replay(4) end)
    local delete = Button("Delete", function()
        local list = SOLCPuzzleDB.paintings or {}
        if list[index] then table.remove(list, index) end
        viewer:Show1()
        SOLC.Refresh()  -- the Collection page lists saved paintings
    end)
    local back = Button("Back", function()
        canvas:StopReplay()
        viewer:Hide()
        if viewer.OnBack then viewer.OnBack() end
    end)
    ns.SpreadRow(viewer, { prev, nextButton }, 130)
    ns.SpreadRow(viewer, { replay, replayFast }, 160)
    ns.SpreadRow(viewer, { delete }, 196)
    ns.SpreadRow(viewer, { back }, 232)
    local status = viewer:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    status:SetPoint("TOPLEFT", 0, -266)
    status:SetPoint("RIGHT", viewer, "RIGHT")
    status:SetJustifyH("LEFT")

    -- Shows the painting at index (wrapping around), or the empty note.
    function viewer:Show1()
        canvas:StopReplay()
        status:SetText("")
        local list = SOLCPuzzleDB.paintings or {}
        local has = #list > 0
        if has then index = (index - 1) % #list + 1 end
        heading:SetText(has and ("My paintings (%d of %d)"):format(index, #list) or "My paintings")
        empty:SetShown(not has)
        reference:SetShown(has)
        for _, button in ipairs({ prev, nextButton }) do button:SetEnabled(#list > 1) end
        for _, button in ipairs({ replay, replayFast, delete }) do button:SetEnabled(has) end
        if not has then
            info:SetText("")
            canvas:Hide()
            return
        end
        local saved = list[index]
        canvas:Show()
        canvas:ShowPainting(ns.LoadPainting(saved))
        SOLC.RenderPicture(reference.canvas, saved.traits, saved.style)
        local rarity = SOLC.PictureRarity(saved.traits)
        reference:SetBackdropBorderColor(SOLC.RarityColor(rarity))
        info:SetText(("Copy of %s's #%d %s\n%.1f%%  -  %dx%d, %ds%s\n|cff999999%s|r"):format(saved.owner or "?",
            saved.number or 0, SOLC.RarityText(rarity), saved.score or 0, saved.size, saved.size, saved.seconds or 0,
            saved.opponent and ("\nduel vs " .. saved.opponent) or "", date("%Y-%m-%d %H:%M", saved.when or 0)))
    end

    function viewer:Replay(speed)
        local saved = (SOLCPuzzleDB.paintings or {})[index]
        if not saved then return end
        status:SetText(("Replaying%s..."):format(speed > 1 and (" at %dx"):format(speed) or ""))
        canvas:Replay(ns.LoadPainting(saved), speed, function()
            canvas:ShowPainting(ns.LoadPainting(saved))  -- the finished painting, whatever the replay missed
            status:SetText("Replay finished.")
        end)
    end

    function viewer:Open(at)
        index = at or 1
        self:Show()
        self:Show1()
    end
    return viewer
end
