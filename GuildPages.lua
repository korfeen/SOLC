-- Pages of the main window (UI.lua) beyond the kill lists:
--   Me      Overview: your points, this week's bounty, achievements close to their next tier, recent highlights
--   Guild   Home: the bounty and the activity feed. Members: everyone synced. Leaderboard: rankings.
--           Bounties: the Bounty Board (BountyBoard.lua). Gallery: every picture minted in the guild.
--   Settings (Config.lua)

local _, ns = ...

local UI = ns.UI
local WIDTH, HEIGHT = UI.PAGE_WIDTH, UI.PAGE_HEIGHT

local function Capitalize(text) return (text:gsub("^%l", string.upper)) end

-- Everyone on the guild pages: you first, then synced guildmates, as
-- { key (nil = you), name, kills, points, pvp, pictures, bounty (this week's), updated, officer, stats }.
local function Members()
    local bounty = ns.GetBounty()
    local function BountyKills(record)
        if not bounty or not record or record.week ~= bounty.week or record.target ~= bounty.bounty.id then return 0 end
        return record.kills
    end
    local db = KillTrackerDB
    local list = { {
        name = ns.MyName(), kills = db.total, points = ns.GetPoints().earned, pvp = db.pvp and db.pvp.total or 0,
        pictures = #(db.mints or {}), bounty = BountyKills(db.bounty), updated = time(), me = true,
        officer = IsInGuild() and ns.CanEditConfig(), stats = db, version = ns.ADDON_VERSION,
    } }
    for _, friend in ipairs(ns.GetFriends()) do
        local stats = friend.stats
        local pictures = 0
        for _ in pairs(stats.mints or {}) do pictures = pictures + 1 end
        list[#list + 1] = {
            key = friend.key, name = friend.name, kills = stats.total or 0, points = stats.earned, pvp = stats.pvpTotal,
            pictures = pictures, bounty = BountyKills(stats.bounty), updated = stats.received,
            officer = ns.IsGuildOfficer(friend.key), stats = stats, version = stats.version,
        }
    end
    return list
end

-- A page frame with a title and a line under it.
local function NewPage(parent, titleText)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    page.title, page.line = UI.CreateHeader(page)
    page.title:SetText(titleText)
    return page
end

-- A fixed (non-scrolling) stack of rows at y: rows:Set(data, render) with render(row, item).
local function RowStack(page, y, count)
    local holder = CreateFrame("Frame", nil, page)
    holder:SetPoint("TOPLEFT", 10, -y)
    holder:SetSize(WIDTH - 40, count * UI.ROW_HEIGHT)
    local stack = { rows = {} }
    for i = 1, count do
        local row = UI.CreateRow(holder, i)
        row:SetScript("OnLeave", GameTooltip_Hide)
        stack.rows[i] = row
    end
    function stack:Set(data, render)
        for i, row in ipairs(self.rows) do
            local item = data[i]
            row:SetShown(item ~= nil)
            if item then
                row.data = item
                row.bar:SetVertexColor(0.8, 0.2, 0.2, 0.45)
                row:SetBar(0)
                render(row, item)
            end
        end
    end
    return stack
end

-- A scrolling list: list:Set(data, render, onClick, onEnter).
local function ScrollList(page, top)
    local scroll = UI.CreateScroll(page, top)
    local list = { rows = {}, scroll = scroll }
    function list:Set(data, render, onClick, onEnter)
        for i, item in ipairs(data) do
            local row = self.rows[i]
            if not row then
                row = UI.CreateRow(scroll.content, i)
                row:SetScript("OnLeave", GameTooltip_Hide)
                self.rows[i] = row
            end
            row.data = item
            row.bar:SetVertexColor(0.8, 0.2, 0.2, 0.45)
            row:SetBar(0)
            row:SetScript("OnClick", onClick and function(self) onClick(self.data) end or nil)
            row:SetScript("OnEnter", onEnter and function(self) onEnter(self, self.data) end or nil)
            render(row, item)
            row:Show()
        end
        for i = #data + 1, #self.rows do self.rows[i]:Hide() end
        scroll.content:SetHeight(math.max(1, #data * UI.ROW_HEIGHT))
    end
    return list
end

-- The bounty block shared by Overview and Guild home: name, bar, details. Click opens the Bounty Board.
local function BountyBlock(page, y)
    local block = CreateFrame("Button", nil, page)
    block:SetPoint("TOPLEFT", 12, -y)
    block:SetSize(WIDTH - 24, 58)
    block:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    block.name = block:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    block.name:SetPoint("TOPLEFT", 0, -2)
    block.bar = UI.CreateBar(block, WIDTH - 24)
    block.bar:SetPoint("TOPLEFT", 0, -20)
    block.details = block:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    block.details:SetPoint("TOPLEFT", 0, -40)
    block.details:SetPoint("RIGHT", block, "RIGHT")
    block.details:SetJustifyH("LEFT")
    block:SetScript("OnClick", function() ns.OpenPage("bounties") end)
    block:SetScript("OnEnter", function(self)
        local progress = ns.GetBountyProgress()
        if not progress then return end
        local bounty = progress.current.bounty
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(("Weekly guild bounty: %s"):format(bounty.name))
        GameTooltip:AddLine(bounty.desc, 1, 1, 1, true)
        GameTooltip:AddLine((bounty.count and ("Each one is worth %d%% extra points. "):format(ns.Config("bountyExtra")) or "")
            .. ("If the guild reaches %d, everyone who got at least %d earns %d points."):format(progress.goal, progress.needed,
            ns.Config("bountyReward")), 1, 1, 1, true)
        for _, c in ipairs(progress.contributors) do UI.AddValue(c.name, c.kills) end
        GameTooltip:AddLine("Click for the Bounty Board", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    block:SetScript("OnLeave", GameTooltip_Hide)
    function block:Update(withTop)
        local progress = ns.GetBountyProgress()
        if not progress then
            self.name:SetText("|cff999999Weekly bounties are for guilds.|r")
            self.bar:Hide()
            self.details:SetText("")
            return
        end
        self.bar:Show()
        local bounty = progress.current.bounty
        self.name:SetText(("|cffffd100%s|r  |cff999999%s|r"):format(bounty.name, bounty.desc))
        self.bar:SetProgress(progress.total / progress.goal,
            progress.rewarded and ("%d/%d - done!"):format(progress.total, progress.goal) or ("%d/%d"):format(progress.total, progress.goal))
        local parts = { ("You %d (share: %d)"):format(progress.mine, progress.needed), "resets in " .. ns.BountyTimeLeft(progress.current.resetsIn) }
        if withTop then
            local top = {}
            for i = 1, math.min(3, #progress.contributors) do
                top[i] = ("%s %d"):format(progress.contributors[i].name, progress.contributors[i].kills)
            end
            if #top > 0 then table.insert(parts, 1, "Top: " .. table.concat(top, ", ")) end
        end
        local nextWeek = ns.GetBounty(1)
        if nextWeek then parts[#parts + 1] = "next week: " .. nextWeek.bounty.name end
        self.details:SetText(table.concat(parts, "  |cff666666-|r  "))
    end
    return block
end

-- Overview ----------------------------------------------------------------------------------

local function StatCard(page, index, label)
    local card = CreateFrame("Frame", nil, page, "BackdropTemplate")
    local width = (WIDTH - 24 - 3 * 8) / 4
    card:SetSize(width, 46)
    card:SetPoint("TOPLEFT", 12 + (index - 1) * (width + 8), -48)
    card:SetBackdrop(UI.INSET_BACKDROP)
    card:SetBackdropColor(0, 0, 0, 0.5)
    card.value = card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    card.value:SetPoint("TOP", 0, -8)
    card.label = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    card.label:SetPoint("BOTTOM", 0, 7)
    card.label:SetText(label)
    return card
end

ns.RegisterPage({
    key = "overview", label = "Overview", section = "me", order = 1,
    create = function(parent)
        local page = NewPage(parent, "Overview")
        page.cards = { StatCard(page, 1, "points"), StatCard(page, 2, "kills"), StatCard(page, 3, "achievements"), StatCard(page, 4, "PvP kills") }
        UI.CreateSection(page, "Guild bounty", 106)
        page.bounty = BountyBlock(page, 124)
        UI.CreateSection(page, "Almost there", 192)
        page.close = RowStack(page, 210, 4)
        UI.CreateSection(page, "Recent highlights", 292)
        page.recent = RowStack(page, 310, 6)
        page.recentEmpty = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        page.recentEmpty:SetPoint("TOPLEFT", 16, -314)
        page.recentEmpty:SetText("Nothing yet - leaders, rares, achievements and pictures show up here.")
        return page
    end,
    refresh = function(page)
        local db = KillTrackerDB
        local p = ns.GetPoints()
        page.line:SetText(("%s - %d kills this session"):format(ns.MyName(), ns.GetSessionKills()))
        page.cards[1].value:SetText(p.balance)
        page.cards[2].value:SetText(db.total)
        page.cards[3].value:SetText(ns.GetAchievementTotals(db))
        page.cards[4].value:SetText(db.pvp and db.pvp.total or 0)
        page.bounty:Update(false)

        local close = {}
        for _, progress in ipairs(ns.GetAchievementProgress(db)) do
            if progress.next then close[#close + 1] = progress end
        end
        table.sort(close, function(a, b) return a.kills / a.next.kills > b.kills / b.next.kills end)
        page.close:Set(close, function(row, progress)
            row.label:SetText(("%s  |cff999999%s|r"):format(progress.category, progress.next.name or ""))
            row.count:SetText(("%d/%d"):format(progress.kills, progress.next.kills))
            row.bar:SetVertexColor(1, 0.5, 0.1, 0.45)
            row:SetBar(progress.kills / progress.next.kills)
            row:SetScript("OnClick", function() ns.OpenPage("achievements") end)
        end)

        local mine = {}
        for _, item in ipairs(ns.GetFeed()) do
            if item.who == ns.MyName() then mine[#mine + 1] = item end
        end
        page.recent:Set(mine, function(row, item)
            row.label:SetText(item.text)
            row.count:SetText("|cff999999" .. ns.TimeAgo(item.time) .. "|r")
        end)
        page.recentEmpty:SetShown(#mine == 0)
    end,
})

-- Guild home ------------------------------------------------------------------------------------

ns.RegisterPage({
    key = "home", label = "Home", section = "guild", order = 1,
    create = function(parent)
        local page = NewPage(parent, "Guild")
        UI.CreateSection(page, "This week's bounty", 48)
        page.bounty = BountyBlock(page, 66)
        UI.CreateSection(page, "Guild activity", 136)
        page.feed = ScrollList(page, 154)
        page.empty = page:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        page.empty:SetPoint("TOP", 0, -200)
        page.empty:SetWidth(WIDTH - 60)
        page.empty:SetText("No guild activity yet. Leader kills, rares, achievements, pictures, bounties and guild dungeon clears from everyone using SOLC show up here.")
        return page
    end,
    refresh = function(page)
        local guild = IsInGuild() and GetGuildInfo("player")
        page.title:SetText(guild or "Guild")
        local members = Members()
        page.line:SetText(guild and ("%d member%s using SOLC"):format(#members, #members == 1 and "" or "s")
            or "You're not in a guild. Guild pages show what you and anyone you /kt sync with do.")
        page.bounty:Update(true)
        local feed = ns.GetFeed()
        page.feed:Set(feed, function(row, item)
            row.label:SetText(item.text)
            row.count:SetText("|cff999999" .. ns.TimeAgo(item.time) .. "|r")
        end, nil, function(row, item)
            GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
            GameTooltip:AddLine(item.text, 1, 1, 1, true)
            GameTooltip:AddLine(date("%Y-%m-%d %H:%M", item.time), 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end)
        page.empty:SetShown(#feed == 0)
    end,
})

-- Members ------------------------------------------------------------------------------------------

local OFFICER = "|TInterface\\GroupFrame\\UI-Group-AssistantIcon:12|t"

ns.RegisterPage({
    key = "members", label = "Members", section = "guild", order = 2,
    create = function(parent)
        local page = NewPage(parent, "Members")
        page.sync = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
        page.sync:SetSize(120, 22)
        page.sync:SetPoint("TOPRIGHT", -12, -12)
        page.sync:SetText("Sync with target")
        page.sync:SetScript("OnClick", function() ns.SyncWithTarget() end)
        page.sync:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Sync with target")
            GameTooltip:AddLine("Guildmates sync by themselves. Use this to swap stats with someone outside the guild.", 1, 1, 1, true)
            GameTooltip:Show()
        end)
        page.sync:SetScript("OnLeave", GameTooltip_Hide)
        local columns = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        columns:SetPoint("TOPLEFT", 14, -50)
        columns:SetText("Name")
        page.columns = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        page.columns:SetPoint("TOPRIGHT", -40, -50)
        page.columns:SetText("kills    points    updated")
        page.list = ScrollList(page, 66)
        return page
    end,
    refresh = function(page)
        local members = Members()
        page.line:SetText(("%d using SOLC. Click someone to see their kills."):format(#members))
        page.list:Set(members, function(row, m)
            row.label:SetText((m.officer and OFFICER .. " " or "") .. (m.me and ("|cffffd100%s|r (you)"):format(m.name) or m.name))
            row.count:SetText(("%d    |cffffd100%s|r    |cff999999%s|r"):format(m.kills, m.points or "?", m.me and "now" or ns.TimeAgo(m.updated)))
        end, function(m)
            if m.me then ns.ViewPlayer(nil) else ns.ViewPlayer(m.key) end
        end, function(row, m)
            GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
            GameTooltip:AddLine(m.name)
            if m.officer then GameTooltip:AddLine("Guild master or officer", 1, 0.82, 0) end
            UI.AddValue("Kills", m.kills)
            UI.AddValue("Points earned", m.points or "? (older SOLC)")
            UI.AddValue("PvP kills", m.pvp or "?")
            UI.AddValue("Pictures", m.pictures)
            UI.AddValue("This week's bounty", m.bounty)
            if m.version then
                local outdated = not m.me and ns.IsNewerVersion(ns.ADDON_VERSION, m.version)
                UI.AddValue("SOLC version", outdated and ("|cffff6060%s (outdated)|r"):format(m.version) or m.version)
            end
            if not m.me and m.updated then UI.AddValue("Last update", date("%Y-%m-%d %H:%M", m.updated)) end
            GameTooltip:AddLine("Click to see their kills", 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end)
    end,
})

-- Leaderboard ---------------------------------------------------------------------------------------

local METRICS = {
    { key = "points", label = "Points" }, { key = "kills", label = "Kills" }, { key = "bounty", label = "Bounty" },
    { key = "pvp", label = "PvP" }, { key = "pictures", label = "Pictures" },
}

ns.RegisterPage({
    key = "leaderboard", label = "Leaderboard", section = "guild", order = 3,
    create = function(parent)
        local page = NewPage(parent, "Leaderboard")
        page.metric = "points"
        page.buttons = {}
        local width = (WIDTH - 24 - 4 * 4) / #METRICS
        for i, metric in ipairs(METRICS) do
            local button = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
            button:SetSize(width, 22)
            button:SetPoint("TOPLEFT", 12 + (i - 1) * (width + 4), -48)
            button:SetText(metric.label)
            button:SetScript("OnClick", function() page.metric = metric.key; ns.OpenPage("leaderboard") end)
            page.buttons[metric.key] = button
        end
        page.list = ScrollList(page, 78)
        return page
    end,
    refresh = function(page)
        for key, button in pairs(page.buttons) do
            if key == page.metric then button:LockHighlight() else button:UnlockHighlight() end
        end
        local ranked = {}
        for _, m in ipairs(Members()) do
            if m[page.metric] then ranked[#ranked + 1] = m end
        end
        table.sort(ranked, function(a, b)
            if a[page.metric] ~= b[page.metric] then return a[page.metric] > b[page.metric] end
            return a.name < b.name
        end)
        local best = ranked[1] and ranked[1][page.metric] or 0
        local bounty = ns.GetBounty()
        page.line:SetText(page.metric == "bounty" and bounty and ("This week: %s"):format(bounty.bounty.name)
            or page.metric == "points" and "Points earned, before spending."
            or ("%d players"):format(#ranked))
        page.list:Set(ranked, function(row, m)
            local rank = 0
            for i, other in ipairs(ranked) do if other == m then rank = i end end
            local medal = rank == 1 and "|cffffd100" or rank == 2 and "|cffc0c0c0" or rank == 3 and "|cffcd7f32" or "|cffffffff"
            row.label:SetText(("%s%d.|r  %s"):format(medal, rank, m.me and ("|cffffd100%s|r"):format(m.name) or m.name))
            row.count:SetText(m[page.metric])
            row.bar:SetVertexColor(0.9, 0.7, 0.1, 0.4)
            row:SetBar(best > 0 and m[page.metric] / best or 0)
        end, function(m)
            if m.me then ns.ViewPlayer(nil) else ns.ViewPlayer(m.key) end
        end)
    end,
})

-- Bounties -----------------------------------------------------------------------------------------

ns.RegisterPage({
    key = "bounties", label = "Bounties", section = "guild", order = 4,
    create = function(parent) return ns.EmbedBountyBoard(parent, WIDTH) end,
    refresh = function() if ns.RefreshBountyBoard then ns.RefreshBountyBoard() end end,
})
function ns.ToggleBountyBoard() ns.OpenPage("bounties") end

-- Gallery ------------------------------------------------------------------------------------------

local TILE, TILE_GAP = 96, 12

ns.RegisterPage({
    key = "gallery", label = "Gallery", section = "guild", order = 5,
    create = function(parent)
        local page = NewPage(parent, "Gallery")
        page.scroll = UI.CreateScroll(page, 48)
        page.tiles = {}
        page.empty = page:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        page.empty:SetPoint("TOP", 0, -120)
        page.empty:SetText("No pictures yet. Mint one in Collection.")
        return page
    end,
    refresh = function(page)
        ns.UpdateDuplicates()
        local pictures = {}
        for _, mint in ipairs(KillTrackerDB.mints or {}) do pictures[#pictures + 1] = { mint = mint, owner = ns.MyName(), me = true } end
        for _, friend in ipairs(ns.GetFriends()) do
            for _, mint in pairs(friend.stats.mints or {}) do pictures[#pictures + 1] = { mint = mint, owner = friend.name } end
        end
        table.sort(pictures, function(a, b) return a.mint.time > b.mint.time end)
        page.line:SetText(("%d picture%s minted in the guild, newest first. Every one is unique."):format(#pictures, #pictures == 1 and "" or "s"))
        local perRow = math.floor((WIDTH - 40 + TILE_GAP) / (TILE + TILE_GAP))
        for i, picture in ipairs(pictures) do
            local tile = page.tiles[i]
            if not tile then
                tile = CreateFrame("Button", nil, page.scroll.content, "BackdropTemplate")
                tile:SetSize(TILE + 6, TILE + 34)
                tile:SetBackdrop(UI.INSET_BACKDROP)
                tile:SetBackdropColor(0, 0, 0, 0.6)
                tile:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
                tile.canvas = CreateFrame("Frame", nil, tile)
                tile.canvas:SetSize(TILE, TILE)
                tile.canvas:SetPoint("TOP", 0, -3)
                tile.owner = tile:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                tile.owner:SetPoint("TOP", tile.canvas, "BOTTOM", 0, -3)
                tile.rarity = tile:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
                tile.rarity:SetPoint("TOP", tile.owner, "BOTTOM", 0, -1)
                tile:SetScript("OnClick", function(self)
                    ns.ShowMint(self.picture.mint, not self.picture.me and self.picture.owner or nil)
                end)
                tile:SetScript("OnEnter", function(self)
                    local mint = self.picture.mint
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:AddLine(("%s's picture #%d"):format(self.picture.owner, mint.number))
                    for _, trait in ipairs(ns.MintTraits(mint.traits)) do
                        GameTooltip:AddDoubleLine(trait[1], ("|c%s%s|r"):format(ns.RARITY_COLORS[trait[3]], trait[2]))
                    end
                    UI.AddValue("Minted", date("%Y-%m-%d", mint.time))
                    if mint.duplicateOf then GameTooltip:AddLine(("Duplicate of %s's"):format(mint.duplicateOf), 1, 0.4, 0.4) end
                    GameTooltip:Show()
                end)
                tile:SetScript("OnLeave", GameTooltip_Hide)
                page.tiles[i] = tile
            end
            tile.picture = picture
            local column, line = (i - 1) % perRow, math.floor((i - 1) / perRow)
            tile:ClearAllPoints()
            tile:SetPoint("TOPLEFT", column * (TILE + TILE_GAP), -line * (TILE + 34 + TILE_GAP))
            ns.RenderMint(tile.canvas, picture.mint.traits)
            local rarity = ns.MintRarity(picture.mint.traits)
            tile.owner:SetText(picture.me and ("|cffffd100%s|r"):format(picture.owner) or picture.owner)
            tile.rarity:SetText(("|c%s%s|r #%d"):format(ns.RARITY_COLORS[rarity], Capitalize(rarity), picture.mint.number))
            tile:Show()
        end
        for i = #pictures + 1, #page.tiles do page.tiles[i]:Hide() end
        page.scroll.content:SetHeight(math.max(1, math.ceil(#pictures / perRow) * (TILE + 34 + TILE_GAP)))
        page.empty:SetShown(#pictures == 0)
    end,
})

-- Settings -----------------------------------------------------------------------------------------

ns.RegisterPage({
    key = "settings", label = "Settings", section = "settings", order = 1,
    create = function(parent) return ns.EmbedConfig(parent, WIDTH) end,
    refresh = function() if ns.RefreshConfigPanel then ns.RefreshConfigPanel() end end,
})
function ns.ToggleConfig() ns.OpenPage("settings") end
