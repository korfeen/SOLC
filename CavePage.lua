-- The guild's home (CAVE), with the Bounty Board and the rankings (the keys bounties and leaderboard open it, the
-- first on HUNTS). A split page (ProfileHeader.lua: the profile header over the left page, the middle beam).
-- Left: tabs. NEWS: this week's bounty (its bar, your share, the time left; click for HUNTS) over the guild's activity,
-- in the Overview feed's style. HUNTS: the Bounty Board (BountyBoard.lua), moved in here while it shows.
-- Right: the rankings. A tab per measure (points, kills, this week's bounty, PvP, pictures), the top three on a
-- podium with a picture each, then everyone in rows. Clicking someone views them (the header, and every page).

local _, ns = ...
local UI = ns.UI
if not UI.Members or not UI.List then return end
local state = UI.List.state
local Fit, Tooltip = UI.FitText, UI.Tooltip

local NAME_FONT = "Interface\\AddOns\\SOLC\\Media\\Fonts\\GermaniaOne-Regular.ttf"
local CREAM, DIM = { 0.93, 0.88, 0.78 }, { 0.62, 0.56, 0.48 }
local HOVER_COLOR = { 0.65, 0.53, 0.28 }
local AGO_COLOR = { 0.98, 0.64, 0.26 }
local FEED_ICON = "Interface\\AddOns\\SOLC\\Media\\Icons\\Feed_"
local FEED_ICONS = { L = "Leader", R = "Rare", A = "Achievement", M = "Mint", W = "Won", B = "Bounty", D = "Boss" }
local MEDALS = { { 1, 0.82, 0.1 }, { 0.78, 0.78, 0.82 }, { 0.8, 0.5, 0.2 } }  -- gold, silver, bronze

local TABS = { { "news", "NEWS", "NEWS" }, { "hunts", "HUNTS", "HUNTS" } }
local TAB_FOR_PAGE = { bounties = "hunts" }
local METRICS = {  -- { Members() field, label, ogre word, what it is }
    { "points", "POINTS", "GOLD", "Points earned, before spending" },
    { "kills", "KILLS", "SMASH", "Kills" },
    { "bounty", "BOUNTY", "HUNTS", "Kills for this week's bounty" },
    { "pvp", "PVP", "BONK", "PvP kills" },
    { "pictures", "PIX", "PIX", "Pictures minted" },
}

-- In window pixels (from its top-left, y down).
local LEFT = {
    tabs = { top = 285, bottom = 319, size = 17, color = { 0.16, 0.11, 0.08 } },
    bounty = { top = 319, bottom = 393, color = { 0.14, 0.1, 0.07 } },  -- this week's bounty, on NEWS
    rows = { top = 393, height = 24, size = 13, colors = { 0.25, 0.18 }, empty = { 0.1, 0.1, 0.1 }, icon = 18 },
    hunts = { top = 319 },  -- the Bounty Board, from here to the slot's bottom
}
local RIGHT = {
    color = { 0.094, 0.094, 0.094 },
    tabs = { top = 146, bottom = 182, size = 16, color = { 0.16, 0.11, 0.08 } },
    -- The podium: { centre x, top, picture size } for first, second, third; the name and the number under each.
    podium = { { 869, 196, 116 }, { 752, 222, 92 }, { 986, 222, 92 } }, rim = 3,
    rows = { top = 384, height = 24, size = 13, colors = { 0.25, 0.18 } },
}

local page
local function Ogre() return KillTrackerDB and KillTrackerDB.ogreMode end

-- Views someone (nil: you) on every page.
local function View(member) ns.ViewPlayer(member and member.key or nil, state.page) end

-- A tab strip: buttons across [left, right] at top..bottom; current() is the current key; onPick(key).
local function TabStrip(parent, tabs, left, right, spec, current, onPick)
    local buttons = {}
    local width = (right - left) / #tabs
    for i, tab in ipairs(tabs) do
        local button = UI.TabButton(parent, left + (i - 1) * width, spec, width)
        function button:Redraw()
            self:SetTab(Ogre() and tab[3] or tab[2], current() == tab[1])
        end
        button:HookScript("OnEnter", function(self) if tab[4] then Tooltip(self, { tab[4] }) end end)
        button:HookScript("OnLeave", GameTooltip_Hide)
        button:SetScript("OnClick", function()
            UI.ClickSound()
            onPick(tab[1])
            ns.OpenPage(state.page)
        end)
        buttons[i] = button
    end
    return buttons
end

-- A column of feed-style rows: their stripes, an icon, the text, a number at the right end.
local function Rows(parent, left, right, spec, bottom, overhang)
    local rows = {}
    for i = 1, math.floor((bottom - spec.top) / spec.height) do
        local row = CreateFrame("Button", nil, parent)
        row:SetSize(right - left + 2 * overhang, spec.height)
        row:SetPoint("TOPLEFT", UI.window, "TOPLEFT", left - overhang, -(spec.top + (i - 1) * spec.height))
        local shade = spec.colors[i % 2 == 1 and 1 or 2]
        row.stripe = row:CreateTexture(nil, "BACKGROUND")
        row.stripe:SetAllPoints()
        row.bar = row:CreateTexture(nil, "BORDER")
        row.bar:SetPoint("BOTTOMLEFT", overhang, 0)
        row.bar:SetHeight(3)
        row.bar:SetColorTexture(0.9, 0.7, 0.1, 0.9)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(spec.icon or 18, spec.icon or 18)
        row.icon:SetPoint("LEFT", overhang + 4, 0)
        row.picture = CreateFrame("Frame", nil, row)
        row.picture:SetSize(spec.icon or 18, spec.icon or 18)
        row.picture:SetPoint("LEFT", overhang + 4, 0)
        row.count = row:CreateFontString(nil, "OVERLAY")
        row.count:SetFont(NAME_FONT, spec.size, "")
        row.count:SetTextColor(unpack(AGO_COLOR))
        row.count:SetShadowOffset(1, -1)
        row.count:SetPoint("RIGHT", -(overhang + 6), 1)
        row.label = row:CreateFontString(nil, "OVERLAY")
        row.label:SetFont(NAME_FONT, spec.size, "")
        row.label:SetTextColor(0.94, 0.94, 0.94)
        row.label:SetShadowOffset(1, -1)
        row.label:SetPoint("RIGHT", row.count, "LEFT", -8, 0)
        row.label:SetJustifyH("LEFT")
        row.label:SetWordWrap(false)
        function row:Layout(withIcon)
            self.label:ClearAllPoints()
            self.label:SetPoint("LEFT", overhang + (withIcon and 28 or 8), 1)
            self.label:SetPoint("RIGHT", self.count, "LEFT", -8, 0)
        end
        function row:Paint(hovered) self.stripe:SetColorTexture(unpack(hovered and HOVER_COLOR or { shade, shade, shade })) end
        row:Paint(false)
        row.width = right - left
        rows[i] = row
    end
    return rows
end

local function DrawNews()
    -- This week's bounty.
    local progress = ns.GetBountyProgress()
    local b = page.bountyBox
    if progress then
        local bounty = progress.current.bounty
        Fit(b.name, NAME_FONT, 15, 10, ("|cffffd100%s|r  |cff999999%s|r"):format(bounty.name, bounty.desc or ""), b.width)
        b.fill:SetWidth(math.max(1, (b.width - 2) * math.min(1, progress.total / math.max(1, progress.goal))))
        b.barText:SetText(progress.rewarded and ("%d/%d - done!"):format(progress.total, progress.goal) or ("%d/%d"):format(progress.total, progress.goal))
        b.details:SetText(("You %d (share %d)  |cff666666-|r  resets in %s"):format(progress.mine, progress.needed,
            ns.BountyTimeLeft(progress.current.resetsIn)))
        b.track:Show()
    else
        b.name:SetText("|cff999999Weekly bounties are for guilds.|r")
        b.details:SetText("")
        b.track:Hide()
    end

    -- The guild's activity.
    local feed = ns.GetFeed()
    for i, row in ipairs(page.newsRows) do
        local item = feed[i]
        row.item = item
        row:SetShown(item ~= nil or i == 1)
        row.bar:Hide()
        row.label:SetText(item and item.text or "No guild activity yet.")
        row.count:SetText(item and ns.TimeAgo(item.time) or "")
        local thumbnail = item and item.kind == "M" and item.mint
        local icon = item and not thumbnail and FEED_ICONS[item.kind]
        row.icon:SetShown(icon ~= nil)
        if icon then row.icon:SetTexture(FEED_ICON .. icon) end
        if item and item.kind == "K" then
            row.icon:SetTexture(UI.BadgeArt(tonumber(item.text:match("rank (%d+)")) or 1))
            row.icon:Show()
        end
        row.picture:SetShown(thumbnail and true or false)
        if thumbnail then ns.DrawMint(row.picture, item.mint) end
        row:Layout(item ~= nil)
    end
end

local function DrawRankings()
    local metric = page.metric
    local ranked = {}
    for _, m in ipairs(UI.Members()) do
        if m[metric] then ranked[#ranked + 1] = m end
    end
    table.sort(ranked, function(a, b)
        if a[metric] ~= b[metric] then return a[metric] > b[metric] end
        return a.name < b.name
    end)
    page.ranked = ranked
    local best = ranked[1] and ranked[1][metric] or 0

    for i, stand in ipairs(page.podium) do
        local m = ranked[i]
        stand.member = m
        stand:SetShown(m ~= nil)
        if m then
            local picture = ns.GetShowcase(m.key)[1] or ns.NewestMint(m.key)
            stand.canvas:SetShown(picture ~= nil)
            stand.none:SetShown(picture == nil)
            if picture then ns.DrawMint(stand.canvas, picture) end
            Fit(stand.name, NAME_FONT, 14, 9, m.me and ("|cffffd100%s|r"):format(m.name) or m.name, stand.size + 30)
            stand.value:SetText(m[metric])
        end
    end
    for i, row in ipairs(page.rankRows) do
        local m = ranked[i]
        row.member = m
        row:SetShown(m ~= nil)
        if m then
            local medal = MEDALS[i]
            row.label:SetText(("%s%d.|r  %s"):format(medal and ("|cff%02x%02x%02x"):format(medal[1] * 255, medal[2] * 255, medal[3] * 255) or "|cffffffff",
                i, m.me and ("|cffffd100%s|r"):format(m.name) or m.name))
            row.count:SetText(m[metric])
            row.bar:SetWidth(math.max(1, row.width * (best > 0 and m[metric] / best or 0)))
            row.icon:Hide()
            row.picture:Hide()
            row:Layout(false)
        end
    end
end

ns.RegisterPage({
    key = "home", label = "Guild", section = "guild", order = 1,
    bare = true,
    split = true,
    covers = { leaderboard = true, bounties = true },  -- (UI.lua)
    create = function(parent)
        page = CreateFrame("Frame", nil, parent)
        page:SetAllPoints()
        page.tab, page.metric = "news", "points"
        local W = UI.window
        local slot, right, under = UI.SPLIT.left, UI.SPLIT.right, UI.SPLIT.under
        local function At(region, point, x, y) region:SetPoint(point, W, "TOPLEFT", x, -y) end

        -- The boards.
        local book = CreateFrame("Frame", nil, page)
        book:SetAllPoints()
        local function Band(top, bottom, color, left, rightX)
            local fill = book:CreateTexture(nil, "BACKGROUND", nil, -8)
            At(fill, "TOPLEFT", left or under.left, top)
            fill:SetSize((rightX or under.middle) - (left or under.left), bottom - top)
            fill:SetColorTexture(unpack(color))
            return fill
        end
        Band(LEFT.tabs.top - 5, LEFT.tabs.bottom, LEFT.tabs.color)
        page.bountyBand = Band(LEFT.bounty.top, LEFT.bounty.bottom, LEFT.bounty.color)
        Band(LEFT.bounty.bottom, under.bottom, LEFT.rows.empty)
        page.huntsBand = Band(LEFT.hunts.top, under.bottom, { 0.08, 0.07, 0.06 })
        Band(under.top, RIGHT.tabs.bottom, RIGHT.tabs.color, under.middle, under.right + 20)
        Band(RIGHT.tabs.bottom, under.bottom, RIGHT.color, under.middle, under.right + 20)

        local left = CreateFrame("Frame", nil, page)
        left:SetAllPoints()
        left:SetFrameLevel(book:GetFrameLevel() + 2)
        page.tabs = TabStrip(left, TABS, slot.left, slot.right, LEFT.tabs, function() return page.tab end,
            function(key) page.tab = key end)

        -- NEWS: the bounty box and the activity rows.
        local news = CreateFrame("Frame", nil, left)
        news:SetAllPoints()
        page.news = news
        local box = CreateFrame("Button", nil, news)
        At(box, "TOPLEFT", slot.left + 10, LEFT.bounty.top + 6)
        box:SetSize(slot.right - slot.left - 20, LEFT.bounty.bottom - LEFT.bounty.top - 12)
        box.width = slot.right - slot.left - 20
        box.name = box:CreateFontString(nil, "OVERLAY")
        box.name:SetPoint("TOPLEFT")
        box.name:SetWidth(box.width)
        box.name:SetJustifyH("LEFT")
        box.name:SetWordWrap(false)
        box.track = CreateFrame("Frame", nil, box)
        box.track:SetPoint("TOPLEFT", 0, -22)
        box.track:SetSize(box.width, 16)
        local edge = box.track:CreateTexture(nil, "BACKGROUND")
        edge:SetAllPoints()
        edge:SetColorTexture(0, 0, 0)
        local inside = box.track:CreateTexture(nil, "BORDER")
        inside:SetPoint("TOPLEFT", 1, -1)
        inside:SetPoint("BOTTOMRIGHT", -1, 1)
        inside:SetColorTexture(0.16, 0.12, 0.11)
        box.fill = box.track:CreateTexture(nil, "ARTWORK")
        box.fill:SetPoint("TOPLEFT", 1, -1)
        box.fill:SetHeight(14)
        box.fill:SetColorTexture(1, 0.85, 0.01)
        box.barText = box.track:CreateFontString(nil, "OVERLAY")
        box.barText:SetFont(NAME_FONT, 11, "")
        box.barText:SetPoint("CENTER")
        UI.OutlineText(box.barText, { 0, 0, 0 })
        box.details = box:CreateFontString(nil, "OVERLAY")
        box.details:SetFont(NAME_FONT, 12, "")
        box.details:SetTextColor(unpack(CREAM))
        box.details:SetPoint("TOPLEFT", 0, -44)
        box.details:SetWidth(box.width)
        box.details:SetJustifyH("LEFT")
        box.details:SetWordWrap(false)
        box:SetScript("OnClick", function()
            UI.ClickSound()
            page.tab = "hunts"
            ns.OpenPage(state.page)
        end)
        box:SetScript("OnEnter", function(self)
            local progress = ns.GetBountyProgress()
            if not progress then return end
            local bounty = progress.current.bounty
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(("Weekly guild bounty: %s"):format(bounty.name))
            GameTooltip:AddLine(bounty.desc, 1, 1, 1, true)
            GameTooltip:AddLine(("If the guild reaches %d, everyone who got at least %d earns %d points."):format(progress.goal,
                progress.needed, ns.Config("bountyReward")), 1, 1, 1, true)
            for _, c in ipairs(progress.contributors) do UI.AddValue(c.name, c.kills) end
            GameTooltip:AddLine("Click for the Bounty Board", 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end)
        box:SetScript("OnLeave", GameTooltip_Hide)
        page.bountyBox = box
        page.newsRows = Rows(news, slot.left, slot.right, LEFT.rows, slot.bottom, 20)
        for _, row in ipairs(page.newsRows) do
            row:SetScript("OnEnter", function(self)
                if not self.item then return end
                self:Paint(true)
                UI.FeedTooltip(self, self.item)
            end)
            row:SetScript("OnLeave", function(self) self:Paint(false) GameTooltip_Hide() end)
            row:SetScript("OnClick", function(self) if self.item then UI.ShowFeedPicture(self.item) end end)
        end

        -- HUNTS: a place for the Bounty Board.
        page.hunts = CreateFrame("Frame", nil, left)
        At(page.hunts, "TOPLEFT", slot.left, LEFT.hunts.top)
        page.hunts:SetSize(slot.right - slot.left, slot.bottom - LEFT.hunts.top)

        -- The rankings: the measures, the podium, the rows.
        local board = CreateFrame("Frame", nil, page)
        board:SetAllPoints()
        board:SetFrameLevel(book:GetFrameLevel() + 2)
        page.metricTabs = TabStrip(board, METRICS, right.left, right.right, RIGHT.tabs, function() return page.metric end,
            function(key) page.metric = key end)
        page.podium = {}
        for i, spot in ipairs(RIGHT.podium) do
            local size = spot[3]
            local stand = CreateFrame("Button", nil, board)
            stand.size = size
            stand:SetSize(size + 2 * RIGHT.rim, size + 2 * RIGHT.rim + 34)
            At(stand, "TOP", spot[1], spot[2])
            local rim = stand:CreateTexture(nil, "BACKGROUND")
            rim:SetPoint("TOP")
            rim:SetSize(size + 2 * RIGHT.rim, size + 2 * RIGHT.rim)
            rim:SetColorTexture(unpack(MEDALS[i]))
            local backing = stand:CreateTexture(nil, "BORDER")
            backing:SetPoint("TOP", 0, -RIGHT.rim)
            backing:SetSize(size, size)
            backing:SetColorTexture(0.06, 0.06, 0.06)
            stand.canvas = CreateFrame("Frame", nil, stand)
            stand.canvas:SetPoint("TOP", 0, -RIGHT.rim)
            stand.canvas:SetSize(size, size)
            stand.none = stand:CreateFontString(nil, "OVERLAY")
            stand.none:SetFont(NAME_FONT, 30, "")
            stand.none:SetTextColor(unpack(DIM))
            stand.none:SetPoint("CENTER", backing)
            stand.none:SetText("?")
            local place = CreateFrame("Frame", nil, stand)
            place:SetAllPoints()
            place:SetFrameLevel(stand.canvas:GetFrameLevel() + 5)
            local number = place:CreateFontString(nil, "OVERLAY")
            number:SetFont(NAME_FONT, i == 1 and 26 or 20, "")
            number:SetPoint("TOPLEFT", 4, -2)
            number:SetText(i)
            number:SetTextColor(unpack(MEDALS[i]))
            UI.OutlineText(number, { 0, 0, 0 })
            stand.name = place:CreateFontString(nil, "OVERLAY")
            stand.name:SetPoint("TOP", rim, "BOTTOM", 0, -3)
            stand.name:SetTextColor(unpack(CREAM))
            UI.OutlineText(stand.name, { 0, 0, 0 })
            stand.value = place:CreateFontString(nil, "OVERLAY")
            stand.value:SetFont(NAME_FONT, 13, "")
            stand.value:SetTextColor(unpack(AGO_COLOR))
            stand.value:SetPoint("TOP", stand.name, "BOTTOM", 0, -1)
            stand:SetScript("OnClick", function(self) UI.ClickSound() View(self.member) end)
            stand:SetScript("OnEnter", function(self) if self.member then Tooltip(self, { self.member.name, "Click to view them" }) end end)
            stand:SetScript("OnLeave", GameTooltip_Hide)
            page.podium[i] = stand
        end
        page.rankRows = Rows(board, right.left, right.right, RIGHT.rows, right.bottom, 20)
        for _, row in ipairs(page.rankRows) do
            row:SetScript("OnEnter", function(self)
                if not self.member then return end
                self:Paint(true)
                Tooltip(self, { self.member.name, ("Updated %s"):format(self.member.me and "now" or ns.TimeAgo(self.member.updated or 0)),
                    "Click to view them" })
            end)
            row:SetScript("OnLeave", function(self) self:Paint(false) GameTooltip_Hide() end)
            row:SetScript("OnClick", function(self) if self.member then UI.ClickSound() View(self.member) end end)
        end
        return page
    end,

    refresh = function(p)
        if p.asked ~= state.page then
            if TAB_FOR_PAGE[state.page] then p.tab = TAB_FOR_PAGE[state.page] end
            p.asked = state.page
        end
        for _, tab in ipairs(p.tabs) do tab:Redraw(false) end
        for _, tab in ipairs(p.metricTabs) do tab:Redraw(false) end
        local hunts = p.tab == "hunts"
        p.news:SetShown(not hunts)
        p.bountyBand:SetShown(not hunts)
        p.huntsBand:SetShown(hunts)
        p.hunts:SetShown(hunts)
        if hunts then
            ns.EmbedBountyBoard(p.hunts, UI.SPLIT.left.right - UI.SPLIT.left.left):Show()
            if ns.RefreshBountyBoard then ns.RefreshBountyBoard() end
        else
            DrawNews()
        end
        DrawRankings()
    end,
})
