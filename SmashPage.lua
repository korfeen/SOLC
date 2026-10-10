-- Kills (SMASH), with PvP, Rares and Deeds as its tabs (the keys pvp, rares, achievements open them). A split
-- page (ProfileHeader.lua: the profile header over the left page, the middle beam).
-- Left: tabs (CREATURES, RARES, PVP, DEEDS), the way into the list (back, the categories clicked into), and the list
-- itself: the same rows as the Kills, PvP, Rares and Achievements lists (UI.lua's BuildRows), in the Overview feed's
-- style. A category opens it; anything else is picked.
-- Right: the pick hung in the Overview's frame: a creature's model (drag to turn, scroll to zoom), or for a deed its
-- tiers, for a player what's known of them; its name on the plaque, and under the frame its kills and its deeds'
-- progress. Inside a category with nothing picked: the category, with its most-killed creature; at the top: the deeds
-- closest to their next tier.

local _, ns = ...
local UI = ns.UI
local List = UI.List
if not List then return end
local state = List.state
local Fit, Tooltip = UI.FitText, UI.Tooltip

local ART = "Interface\\AddOns\\SOLC\\Media\\Overview\\"
local NAME_FONT = "Interface\\AddOns\\SOLC\\Media\\Fonts\\GermaniaOne-Regular.ttf"
local SIGN_FONT = "Interface\\AddOns\\SOLC\\Media\\Fonts\\FingerPaint-Regular.ttf"
local INK = { 0.16, 0.16, 0.18 }
local CREAM, DIM = { 0.93, 0.88, 0.78 }, { 0.62, 0.56, 0.48 }
local GOLD = { 1, 0.85, 0.1 }
local HOVER_COLOR, PICKED_COLOR = { 0.65, 0.53, 0.28 }, { 0.45, 0.36, 0.18 }

local TABS = {  -- { view (BuildRows), label, ogre word }; the rares are a switch on DEEDS (RARES_SWITCH)
    { "creatures", "CREATURES", "BEAST" },
    { "pvp", "PVP", "BONK" },
    { "achievements", "DEEDS", "BRAG" },
}
local RARES_SWITCH = { width = 70, label = "RARES", ogre = "SHINY" }  -- at the right end of the line under the tabs
-- The page asked for (UI state.page) picks the tab when you come in from it.
local TAB_FOR_PAGE = { pvp = "pvp", rares = "rares", achievements = "achievements" }

-- In window pixels (from its top-left, y down). The left slot (UI.SPLIT.left): the tabs, the way in, the rows.
local LEFT = {
    tabs = { top = 285, bottom = 319, size = 17, color = { 0.16, 0.11, 0.08 } },
    crumb = { top = 319, bottom = 343, size = 13, color = { 0.12, 0.12, 0.12 } },
    rows = { top = 343, height = 24, size = 13, colors = { 0.25, 0.18 }, bar = 3, empty = { 0.1, 0.1, 0.1 } },
}
-- The right page: the frame (as the Overview's), the photo opening, the plaque, and the lines and bar under the frame.
local RIGHT = {
    color = { 0.094, 0.094, 0.094 },
    frame = { x = 688, y = 156, w = 362, h = 447 },
    photo = { x = 869, y = 389.5, w = 308, h = 329 },
    plaque = { x = 874, y = 578, w = 170, size = 22 },
    info = { x = 700, top = 614, width = 340, line = 18, lines = 3, size = 13 },
    bar = { top = 666, height = 16, gap = 20 },  -- up to three deed bars, one under the other
}
local BACK_WIDTH = 62  -- the BACK button, at the start of the way in
local PANEL_LINES = 15  -- text lines in the photo opening (a deed's tiers, a player)

-- The deeds (achievement rows) about a creature's kinds: its subtype's, and its tribe's.
local function DeedsFor(c)
    local found = {}
    if not c then return found end
    for _, progress in ipairs(ns.GetAchievementProgress(List.Source())) do
        if not progress.feat and ((not progress.tribe and progress.category == c.subtype)
            or (progress.tribe and c.faction and (c.faction == progress.category or c.faction:find(progress.category, 1, true)))) then
            found[#found + 1] = progress
        end
    end
    return found
end

-- The deeds closest to their next tier (completed ones left out).
local function NearestDeeds(count)
    local list = {}
    for _, progress in ipairs(ns.GetAchievementProgress(List.Source())) do
        if progress.next then list[#list + 1] = progress end
    end
    table.sort(list, function(a, b) return a.kills / a.next.kills > b.kills / b.next.kills end)
    local out = {}
    for i = 1, math.min(count, #list) do out[i] = list[i] end
    return out
end

-- The rows from page.offset on.
local function DrawRows(page)
    for i, row in ipairs(page.rows) do
        local d = page.data[page.offset + i]
        row.data = d
        row:SetShown(d ~= nil)
        if d then
            List.FillRow(row, d, page.total, page.max)
            local r, g, b = row.bar:GetVertexColor()
            row.bar:SetVertexColor(r, g, b, 0.9)
            row:Paint(false)
        end
    end
    page.empty:SetShown(#page.data == 0)
    page.empty:SetText(state.view == "pvp" and "No PvP kills yet." or "Nothing smashed yet - go smash something.")
end

-- Writes a creature's model, or says it isn't known yet.
local function ShowCreature(page, npcID)
    page.model:Show()
    page.model:ClearModel()
    page.model:SetCreature(npcID)
    page.model:SetFacing(page.facing)
    for _, line in ipairs(page.panel) do line:SetText("") end
    C_Timer.After(0.1, function()
        local loaded = page.model.GetModelFileID and page.model:GetModelFileID()
        page.unseen:SetShown(not loaded)
    end)
end

local function ShowPanel(page, lines)
    page.model:Hide()
    page.unseen:Hide()
    for i, line in ipairs(page.panel) do
        local text = lines[i]
        line:SetText(type(text) == "table" and text[1] or text or "")
        line:SetTextColor(unpack(type(text) == "table" and text[2] or CREAM))
    end
end

local function SetInfo(page, lines, deeds)
    for i, line in ipairs(page.info) do line:SetText(lines[i] or "") end
    for i, bar in ipairs(page.bars) do bar:Set(deeds and deeds[i]) end
end

-- The right page, for what's picked (or the category, or the top).
local function DrawPick(page)
    local d = page.pick
    local name
    if d and (d.mob or d.leader or d.rare) then
        local npcID = d.mob and d.mob.npcID or d.leader and d.leader.npcID or d.rare.npcID
        local c = d.mob and d.mob.c or d.rare and d.rare.c
        name = d.label
        ShowCreature(page, npcID)
        local kills = d.mob and d.mob.count or d.leader and d.leader.kills or d.rare.kills
        local kind = d.leader and "|cffffd100Leader|r" or d.rare and (d.rare.elite and "|cffc0c0ffRare elite|r" or "|cffc0c0ffRare|r")
            or (c and c.rank or "")
        SetInfo(page, {
            ("Smashed |cffffbf66%s|r  %s"):format(kills > 0 and kills or "never", kind),
            c and ("%s%s"):format(c.subtype or "", c.faction and c.faction ~= c.subtype and (" - " .. c.faction) or "") or "",
            d.rare and ("Level %d, %s"):format(d.rare.level, d.rare.zone or "") or "",
        }, DeedsFor(c))
    elseif d and d.achievement then
        local progress = d.achievement
        name = progress.category
        local lines = { { progress.category, GOLD }, ("%d %s so far"):format(progress.kills, progress.unit or "kills"), " " }
        for _, tier in ipairs(progress.tiers) do
            lines[#lines + 1] = tier.earned
                and { ("%s  -  %s"):format(tier.name, tier.time and date("%Y-%m-%d", tier.time) or "earned"), { 0.4, 1, 0.4 } }
                or { ("%s  -  %d %s"):format(tier.name, tier.kills, progress.unit or "kills"), DIM }
        end
        ShowPanel(page, lines)
        SetInfo(page, { ("%d of %d tiers earned"):format(progress.earned, #progress.tiers) }, { progress })
    elseif d and d.player then
        local pl = d.player
        name = pl.name
        ShowPanel(page, {
            { pl.realm and (pl.name .. "-" .. pl.realm) or pl.name, GOLD },
            ("%s %s"):format(pl.race or "?", pl.class or "?"),
            pl.level and ("Level %d"):format(pl.level) or nil,
            " ",
            pl.zone and pl.zone ~= "" and ("Last smashed in %s"):format(pl.zone) or nil,
            pl.time and date("%Y-%m-%d %H:%M", pl.time) or nil,
        })
        SetInfo(page, { ("Smashed |cffffbf66%d|r times"):format(pl.count or d.count) })
    elseif #state.path > 0 then
        -- Inside a category: it, with its most-killed creature.
        local step = state.path[#state.path]
        name = step.label
        local top
        for _, row in ipairs(page.data) do
            if row.mob and (not top or row.count > top.count) then top = row end
        end
        if top then ShowCreature(page, top.mob.npcID) else ShowPanel(page, {}) end
        SetInfo(page, {
            ("|cffffbf66%d|r smashed in here"):format(page.total),
            top and ("Most smashed: %s (%d)"):format(top.label, top.count) or "",
        }, top and DeedsFor(top.mob.c) or nil)
    else
        -- The top: the deeds closest to their next tier.
        local who = UI.Profile(ns.GetViewing())
        name = (who.name or ""):match("^(%S+)") or ""
        local nearest = NearestDeeds(3)
        local lines = { { "Closest deeds", GOLD } }
        for _, progress in ipairs(NearestDeeds(PANEL_LINES - 2)) do
            lines[#lines + 1] = ("%s: %d/%d"):format(progress.category, progress.kills, progress.next.kills)
        end
        ShowPanel(page, lines)
        SetInfo(page, { ("|cffffbf66%d|r smashed in all"):format(page.total) }, nearest)
    end
    Fit(page.plaque, SIGN_FONT, RIGHT.plaque.size, 8, (name or ""):upper(), RIGHT.plaque.w)
end

ns.RegisterPage({
    key = "kills", label = "Kills", section = "me", order = 2,
    bare = true,
    split = true,
    covers = { pvp = true, rares = true, achievements = true },  -- (UI.lua) on those tabs
    create = function(parent)
        local page = CreateFrame("Frame", nil, parent)
        page:SetAllPoints()
        local W = UI.window
        local slot, under = UI.SPLIT.left, UI.SPLIT.under
        local function At(region, point, x, y) region:SetPoint(point, W, "TOPLEFT", x, -y) end
        local ogre = function() return KillTrackerDB and KillTrackerDB.ogreMode end

        -- The boards: the tabs' band, the way in, under the rows, the right page's board.
        local book = CreateFrame("Frame", nil, page)
        book:SetAllPoints()
        local function Band(top, bottom, color, left, right)
            local fill = book:CreateTexture(nil, "BACKGROUND", nil, -8)
            At(fill, "TOPLEFT", left or under.left, top)
            fill:SetSize((right or under.middle) - (left or under.left), bottom - top)
            fill:SetColorTexture(unpack(color))
        end
        Band(LEFT.tabs.top - 5, LEFT.tabs.bottom, LEFT.tabs.color)  -- from under the header's strip
        Band(LEFT.crumb.top, LEFT.crumb.bottom, LEFT.crumb.color)
        Band(LEFT.rows.top, under.bottom, LEFT.rows.empty)
        Band(under.top, under.bottom, RIGHT.color, under.middle, under.right + 20)

        local left = CreateFrame("Frame", nil, page)
        left:SetAllPoints()
        left:SetFrameLevel(book:GetFrameLevel() + 2)

        -- The tabs.
        page.tabs = {}
        local tabWidth = (slot.right - slot.left) / #TABS
        for i, tab in ipairs(TABS) do
            local button = UI.TabButton(left, slot.left + (i - 1) * tabWidth, LEFT.tabs, tabWidth)
            button.view = tab[1]
            function button:Redraw()
                local current = state.view == self.view or (self.view == "achievements" and state.view == "rares")
                self:SetTab(ogre() and tab[3] or tab[2], current)
            end
            button:SetScript("OnClick", function(self)
                UI.ClickSound()
                page.view, page.pick, page.offset = self.view, nil, 0
                state.view, state.path = self.view, {}
                ns.OpenPage(state.page)
            end)
            page.tabs[i] = button
        end

        -- The way in: back, and the categories clicked into.
        local crumbY = (LEFT.crumb.top + LEFT.crumb.bottom) / 2
        -- Up one level: the BACK button, or right-click anywhere on the list.
        local function GoBack()
            if #state.path == 0 then return end
            UI.ClickSound()
            repeat local step = table.remove(state.path) until not step or not step.auto  -- past levels skipped on the way in
            page.pick, page.offset = nil, 0
            ns.OpenPage(state.page)
        end
        page.GoBack = GoBack
        local back = CreateFrame("Button", nil, left)
        back:SetSize(BACK_WIDTH, LEFT.crumb.bottom - LEFT.crumb.top)
        At(back, "LEFT", slot.left + 2, crumbY)
        local backPlate = back:CreateTexture(nil, "BACKGROUND")
        backPlate:SetPoint("TOPLEFT", 0, -3)
        backPlate:SetPoint("BOTTOMRIGHT", 0, 3)
        backPlate:SetColorTexture(0.3, 0.22, 0.12)
        local backArt = back:CreateTexture(nil, "ARTWORK")
        backArt:SetSize(12, 12)
        backArt:SetPoint("LEFT", 6, 0)
        backArt:SetTexture(ART .. "Arrow")
        backArt:SetTexCoord(1, 0, 0, 1)
        local backText = back:CreateFontString(nil, "OVERLAY")
        backText:SetFont(NAME_FONT, LEFT.crumb.size, "")
        backText:SetPoint("LEFT", backArt, "RIGHT", 4, 0)
        backText:SetText("BACK")
        local function Lit(on)
            local c = on and { 1, 1, 1 } or GOLD
            backArt:SetVertexColor(unpack(c))
            backText:SetTextColor(unpack(c))
            backPlate:SetColorTexture(unpack(on and HOVER_COLOR or { 0.3, 0.22, 0.12 }))
        end
        Lit(false)
        back:SetScript("OnEnter", function(self) Lit(true) Tooltip(self, { "Back", "Or right-click the list" }) end)
        back:SetScript("OnLeave", function() Lit(false) GameTooltip_Hide() end)
        back:SetScript("OnClick", GoBack)
        page.back = back
        page.crumb = left:CreateFontString(nil, "OVERLAY")
        page.crumb:SetFont(NAME_FONT, LEFT.crumb.size, "")
        page.crumb:SetTextColor(unpack(CREAM))
        page.crumb:SetJustifyH("LEFT")
        page.crumb:SetWordWrap(false)
        page.crumb:SetWidth(slot.right - slot.left - 36 - RARES_SWITCH.width)

        -- DEEDS' rares switch: the deeds, or every rare by zone (found or not), what the rare deeds count.
        local rares = CreateFrame("Button", nil, left)
        rares:SetSize(RARES_SWITCH.width, LEFT.crumb.bottom - LEFT.crumb.top - 6)
        At(rares, "RIGHT", slot.right - 4, crumbY)
        local raresPlate = rares:CreateTexture(nil, "BACKGROUND")
        raresPlate:SetAllPoints()
        rares.text = rares:CreateFontString(nil, "OVERLAY")
        rares.text:SetFont(NAME_FONT, LEFT.crumb.size, "")
        rares.text:SetPoint("CENTER", 0, 1)
        function rares:Redraw(hovered)
            local on = state.view == "rares"
            self.text:SetText((on and "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:12|t " or "")
                .. (KillTrackerDB and KillTrackerDB.ogreMode and RARES_SWITCH.ogre or RARES_SWITCH.label))
            self.text:SetTextColor(unpack(on and GOLD or hovered and { 1, 1, 1 } or DIM))
            raresPlate:SetColorTexture(unpack(hovered and HOVER_COLOR or on and { 0.3, 0.22, 0.12 } or { 0.2, 0.17, 0.14 }))
        end
        rares:SetScript("OnEnter", function(self) self:Redraw(true) Tooltip(self, { "Rares", "Every rare by zone, found or not. Finding them earns the rare deeds." }) end)
        rares:SetScript("OnLeave", function(self) self:Redraw(false) GameTooltip_Hide() end)
        rares:SetScript("OnClick", function()
            UI.ClickSound()
            page.view = state.view == "rares" and "achievements" or "rares"
            page.pick, page.offset = nil, 0
            state.view, state.path = page.view, {}
            ns.OpenPage(state.page)
        end)
        page.raresSwitch = rares

        -- The rows, running on under the post and the middle beam; the wheel scrolls them.
        local rowsSpec, overhang = LEFT.rows, 20
        local rowWidth = slot.right - slot.left
        -- Under the rows (and below the last): the wheel scrolls, right-click goes back.
        local listArea = CreateFrame("Frame", nil, left)
        At(listArea, "TOPLEFT", slot.left - overhang, rowsSpec.top)
        listArea:SetSize(rowWidth + 2 * overhang, slot.bottom - rowsSpec.top)
        listArea:EnableMouse(true)
        listArea:EnableMouseWheel(true)
        listArea:SetScript("OnMouseUp", function(_, button) if button == "RightButton" then GoBack() end end)
        page.rows = {}
        page.offset = 0
        for i = 1, math.floor((slot.bottom - rowsSpec.top) / rowsSpec.height) do
            local row = CreateFrame("Button", nil, left)
            row:SetFrameLevel(listArea:GetFrameLevel() + 1)
            row:EnableMouseWheel(false)  -- the wheel goes on to the list area
            row:SetSize(rowWidth + 2 * overhang, rowsSpec.height)
            At(row, "TOPLEFT", slot.left - overhang, rowsSpec.top + (i - 1) * rowsSpec.height)
            local shade = rowsSpec.colors[i % 2 == 1 and 1 or 2]
            row.shade = { shade, shade, shade }
            row.stripe = row:CreateTexture(nil, "BACKGROUND")
            row.stripe:SetAllPoints()
            row.bar = row:CreateTexture(nil, "BORDER")
            row.bar:SetPoint("BOTTOMLEFT", overhang, 0)
            row.bar:SetHeight(rowsSpec.bar)
            row.bar:SetColorTexture(1, 1, 1)
            function row:SetBar(fraction) self.bar:SetWidth(math.max(1, rowWidth * math.min(1, fraction))) end
            row.count = row:CreateFontString(nil, "OVERLAY")
            row.count:SetFont(NAME_FONT, rowsSpec.size, "")
            row.count:SetTextColor(1, 0.75, 0.4)
            row.count:SetShadowOffset(1, -1)
            row.count:SetPoint("RIGHT", -(overhang + 6), 1)
            row.label = row:CreateFontString(nil, "OVERLAY")
            row.label:SetFont(NAME_FONT, rowsSpec.size, "")
            row.label:SetTextColor(0.94, 0.94, 0.94)
            row.label:SetShadowOffset(1, -1)
            row.label:SetPoint("LEFT", overhang + 8, 1)
            row.label:SetPoint("RIGHT", row.count, "LEFT", -8, 0)
            row.label:SetJustifyH("LEFT")
            row.label:SetWordWrap(false)
            function row:Paint(hovered)
                local picked = self.data and self.data == page.pick
                self.stripe:SetColorTexture(unpack(hovered and HOVER_COLOR or picked and PICKED_COLOR or self.shade))
            end
            row:SetScript("OnEnter", function(self)
                if not self.data then return end
                self:Paint(true)
                List.RowTooltip(self)
            end)
            row:SetScript("OnLeave", function(self)
                self:Paint(false)
                GameTooltip_Hide()
            end)
            row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            row:SetScript("OnClick", function(self, button)
                if button == "RightButton" then return GoBack() end
                local d = self.data
                if not d then return end
                UI.ClickSound()
                if d.category then
                    state.path[#state.path + 1] = { value = d.category, label = d.label }
                    page.pick, page.offset = nil, 0
                elseif d.mob or d.leader or d.rare or d.player or d.achievement then
                    page.pick = page.pick ~= d and d or nil
                end
                ns.OpenPage(state.page)
            end)
            page.rows[i] = row
        end
        page.empty = left:CreateFontString(nil, "OVERLAY")
        page.empty:SetFont(NAME_FONT, 14, "")
        page.empty:SetTextColor(unpack(DIM))
        At(page.empty, "TOP", (slot.left + slot.right) / 2, rowsSpec.top + 40)
        listArea:SetScript("OnMouseWheel", function(_, delta)
            local most = math.max(0, #(page.data or {}) - #page.rows)
            local offset = math.max(0, math.min(most, page.offset - delta * 3))
            if offset ~= page.offset then
                page.offset = offset
                page:DrawRows()
            end
        end)

        -- The right page: the frame, with a model or a text panel in its opening, the plaque, the lines and bars under it.
        local card = CreateFrame("Frame", nil, page)
        card:SetAllPoints()
        card:SetFrameLevel(book:GetFrameLevel() + 2)
        local p = RIGHT.photo
        local photo = CreateFrame("Frame", nil, card)
        photo:SetSize(p.w, p.h)
        At(photo, "CENTER", p.x, p.y)
        local sky = photo:CreateTexture(nil, "BACKGROUND")
        sky:SetAllPoints()
        sky:SetTexture("Interface\\Buttons\\WHITE8X8")
        sky:SetGradient("VERTICAL", CreateColor(0.12, 0.1, 0.09, 1), CreateColor(0.3, 0.25, 0.2, 1))
        local model = CreateFrame("PlayerModel", nil, photo)
        model:SetAllPoints()
        model:EnableMouse(true)
        model:EnableMouseWheel(true)
        page.model, page.facing, page.zoom = model, 0, 0
        model:SetScript("OnMouseWheel", function(self, delta)
            page.zoom = math.max(-0.5, math.min(0.6, page.zoom + delta * 0.1))
            if self.SetPortraitZoom then self:SetPortraitZoom(math.max(0, page.zoom)) end
            if self.SetCamDistanceScale then self:SetCamDistanceScale(1 - math.min(0, page.zoom)) end
        end)
        model:SetScript("OnMouseDown", function(self, button)
            if button ~= "LeftButton" then return end
            local lastX = GetCursorPosition()
            self:SetScript("OnUpdate", function()
                local x = GetCursorPosition()
                page.facing = page.facing + (x - lastX) / 80
                lastX = x
                self:SetFacing(page.facing)
            end)
        end)
        model:SetScript("OnMouseUp", function(self) self:SetScript("OnUpdate", nil) end)
        model:SetScript("OnHide", function(self) self:SetScript("OnUpdate", nil) end)
        model:SetScript("OnEnter", function(self) Tooltip(self, { "Drag to turn, scroll to zoom" }) end)
        model:SetScript("OnLeave", GameTooltip_Hide)
        page.unseen = photo:CreateFontString(nil, "OVERLAY")
        page.unseen:SetFont(NAME_FONT, 14, "")
        page.unseen:SetTextColor(unpack(DIM))
        page.unseen:SetPoint("CENTER")
        page.unseen:SetWidth(p.w - 40)
        page.unseen:SetText("Not seen up close yet - its model shows once you've seen one in the game.")
        page.panel = {}
        for i = 1, PANEL_LINES do
            local line = photo:CreateFontString(nil, "OVERLAY")
            line:SetFont(NAME_FONT, 13, "")
            line:SetPoint("TOPLEFT", 14, -12 - (i - 1) * 20)
            line:SetPoint("RIGHT", -14, 0)
            line:SetJustifyH("LEFT")
            line:SetWordWrap(false)
            page.panel[i] = line
        end

        local hung = CreateFrame("Frame", nil, card)
        hung:SetAllPoints()
        hung:SetFrameLevel(photo:GetFrameLevel() + 10)  -- over the model
        local frameArt = hung:CreateTexture(nil, "ARTWORK")
        frameArt:SetTexture(ART .. "HangingPicture")
        frameArt:SetTexCoord(0, RIGHT.frame.w / 512, 0, RIGHT.frame.h / 512)
        frameArt:SetSize(RIGHT.frame.w, RIGHT.frame.h)
        At(frameArt, "TOPLEFT", RIGHT.frame.x, RIGHT.frame.y)
        page.plaque = hung:CreateFontString(nil, "OVERLAY")
        At(page.plaque, "CENTER", RIGHT.plaque.x, RIGHT.plaque.y)
        page.plaque:SetTextColor(unpack(INK))
        page.plaque:SetShadowOffset(0, 0)

        local info = RIGHT.info
        page.info = {}
        for i = 1, info.lines do
            local line = card:CreateFontString(nil, "OVERLAY")
            line:SetFont(NAME_FONT, info.size, "")
            line:SetTextColor(unpack(CREAM))
            At(line, "TOPLEFT", info.x, info.top + (i - 1) * info.line)
            line:SetWidth(info.width)
            line:SetJustifyH("LEFT")
            line:SetWordWrap(false)
            page.info[i] = line
        end
        page.bars = {}
        for i = 1, 3 do
            local bar = CreateFrame("Frame", nil, card)
            bar:SetSize(info.width, RIGHT.bar.height)
            At(bar, "TOPLEFT", info.x, RIGHT.bar.top + (i - 1) * RIGHT.bar.gap)
            local edge = bar:CreateTexture(nil, "BACKGROUND")
            edge:SetAllPoints()
            edge:SetColorTexture(0, 0, 0)
            local track = bar:CreateTexture(nil, "BORDER")
            track:SetPoint("TOPLEFT", 1, -1)
            track:SetPoint("BOTTOMRIGHT", -1, 1)
            track:SetColorTexture(0.16, 0.12, 0.11)
            bar.fill = bar:CreateTexture(nil, "ARTWORK")
            bar.fill:SetPoint("TOPLEFT", 1, -1)
            bar.fill:SetHeight(RIGHT.bar.height - 2)
            bar.fill:SetColorTexture(1, 0.6, 0.15)
            bar.text = bar:CreateFontString(nil, "OVERLAY")
            bar.text:SetFont(NAME_FONT, 11, "")
            bar.text:SetPoint("LEFT", 6, 0)
            bar.text:SetPoint("RIGHT", -6, 0)
            bar.text:SetJustifyH("LEFT")
            bar.text:SetWordWrap(false)
            UI.OutlineText(bar.text, { 0, 0, 0 })
            function bar:Set(progress)
                self:SetShown(progress ~= nil)
                if not progress then return end
                local done = not progress.next
                local share = done and 1 or progress.kills / progress.next.kills
                self.fill:SetWidth(math.max(1, (info.width - 2) * math.min(1, share)))
                self.text:SetText(done and ("%s - all %d tiers"):format(progress.category, #progress.tiers)
                    or ("%s: %s  %d/%d"):format(progress.category, progress.next.name, progress.kills, progress.next.kills))
            end
            page.bars[i] = bar
        end
        page.DrawRows, page.DrawPick = DrawRows, DrawPick
        return page
    end,

    refresh = function(page)
        -- Yours or a synced guildmate's (the old lists' combined stats aren't shown here).
        if state.viewing and not KillTrackerFriends[state.viewing] then state.viewing = nil end
        -- The tab: from the page asked for, when that changed; else the last one used.
        local wanted = TAB_FOR_PAGE[state.page] or "creatures"
        if page.asked ~= state.page then
            if TAB_FOR_PAGE[state.page] or not page.view then page.view, page.pick, page.offset = wanted, nil, 0 end
            page.asked = state.page
        end
        if state.view ~= page.view or state.listPage ~= "smash" then state.path = {} end
        state.view, state.listPage = page.view, "smash"
        if page.who ~= state.viewing then page.pick, page.offset, page.who = nil, 0, state.viewing end
        for _, tab in ipairs(page.tabs) do tab:Redraw(false) end
        page.raresSwitch:SetShown(state.view == "achievements" or state.view == "rares")
        page.raresSwitch:Redraw(false)

        page.data = List.BuildRows()
        local total, max = 0, 0
        for _, d in ipairs(page.data) do
            if not d.leader and not d.rare then total = total + d.count end
            if d.count > max then max = d.count end
        end
        page.total, page.max = total, max
        page.offset = math.min(page.offset, math.max(0, #page.data - #page.rows))

        -- The way in.
        local inside = #state.path > 0
        page.back:SetShown(inside)
        page.crumb:ClearAllPoints()
        page.crumb:SetPoint("LEFT", UI.window, "TOPLEFT", UI.SPLIT.left.left + (inside and BACK_WIDTH + 10 or 10), -(LEFT.crumb.top + LEFT.crumb.bottom) / 2)
        local labels = {}
        for _, step in ipairs(state.path) do
            if step.label ~= labels[#labels] then labels[#labels + 1] = step.label end
        end
        local root = state.view == "achievements" and "All deeds" or state.view == "rares" and "Rares by zone"
            or state.view == "pvp" and "Players" or "All creatures"
        page.crumb:SetText(inside and ("%s  |cffffbf66%d|r"):format(table.concat(labels, " > "), total)
            or state.view == "achievements" and root
            or ("%s  |cffffbf66%d|r"):format(root, total))
        page:DrawRows()
        page:DrawPick()
    end,
})
