-- The Sleepy Ogre Leisure Club window: a sidebar of pages on the left, the chosen page on the right.
--   Me      Overview, Kills, PvP, Achievements, Collection
--   Guild   Home, Members, Leaderboard, Bounties, Gallery (GuildPages.lua)
--   Settings
-- Pages register with ns.RegisterPage; this file has the window, the sidebar, and the list pages (Kills,
-- PvP, Achievements, Collection), which show your stats, the combined stats of everyone you follow (see
-- Combined.lua) or a synced guildmate's (see Sync.lua), chosen with the arrows in the page header.

local _, ns = ...

local WIDTH, HEIGHT = 700, 500
local SIDEBAR_WIDTH = 150
local PAGE_WIDTH, PAGE_HEIGHT = WIDTH - SIDEBAR_WIDTH - 44, HEIGHT - 68
local ROW_HEIGHT = 18
local LIST_WIDTH = PAGE_WIDTH - 40
local NORMAL_RANK = "Normal"
local SECTIONS = { { key = "me", label = "Me" }, { key = "guild", label = "Guild" }, { key = "settings" } }

ns.UI = { PAGE_WIDTH = PAGE_WIDTH, PAGE_HEIGHT = PAGE_HEIGHT, ROW_HEIGHT = ROW_HEIGHT }

-- Kill views: levels are the categories (fields of ns.Categorize's result) a view drills through, one
-- click each, before listing the mobs themselves.
local VIEWS = {
    creatures = { label = "Creatures", levels = { "subtype", "faction" } },
    rank = { label = "Rank", levels = { "rank" } },
    mobs = { label = "Mobs", levels = {} },
    pvp = { levels = { "race", "class" }, players = true },
}
local PLURALS = { subtype = "subtypes", faction = "factions", rank = "ranks", race = "races", class = "classes" }

local EMPTY_TEXT = {
    achievements = "No achievements yet - keep killing.",
    pvp = "No PvP kills yet.",
}

local COMBINED = "*combined*"

-- page: the page shown. view: the list on a list page ("creatures", "rank", "mobs", "pvp",
-- "achievements" or "collection"). path: the categories clicked into so far, { value, label, auto } per
-- level; auto marks a level skipped because it had only one choice. viewing: nil for you, COMBINED, or a
-- friend's key in KillTrackerFriends. combined: the combined stats, rebuilt on every refresh while viewed.
local state = { page = "overview", view = "creatures", path = {}, viewing = nil, combined = nil }

-- The stats being viewed: KillTrackerDB, the combined stats or a friend's synced stats.
local function Source()
    if state.viewing == COMBINED then return state.combined end
    return state.viewing and KillTrackerFriends[state.viewing] or KillTrackerDB
end

local function CategoryOf(c, level)
    if level == "rank" then return c.rank or NORMAL_RANK end
    return c[level]
end

-- "Gnoll - Riverpaw" under Gnoll reads as "Riverpaw"; "Troll, Bloodscalp" under Troll as "Bloodscalp".
local function ShortFaction(faction, subtype)
    if faction:lower():sub(1, #subtype) == subtype:lower() then
        local rest = faction:sub(#subtype + 1):gsub("^[%s,%-]+", "")
        if rest ~= "" then return rest end
    end
    return faction
end

-- Faction leaders (ns.Leaders, from Data.lua): a gold crown once killed, a grey one until then.
local LEADER_TITLES = {
    overlord = "Overlord of all its tribes",
    champion = "Champion: the mightiest of its race",
}
-- "Overlord", "Champion", "Ruler" or "Leader", for tooltips.
local function LeaderTitle(leader)
    return leader.kind == "overlord" and "Overlord" or leader.kind == "champion" and "Champion"
        or state.view == "pvp" and "Ruler" or "Leader"
end
local CROWN = "|TInterface\\GroupFrame\\UI-Group-LeaderIcon:14|t"
local CROWN_GREY = "|TInterface\\GroupFrame\\UI-Group-LeaderIcon:14:14:0:0:16:16:0:16:0:16:110:110:110|t"
ns.UI.CROWN = CROWN

local leaderIDs  -- [npcID] = true for every faction leader (built on first use)
local function IsLeader(npcID)
    if not leaderIDs then
        leaderIDs = {}
        for _, list in pairs(ns.Leaders) do
            for _, leader in ipairs(list) do leaderIDs[leader[1]] = true end
        end
    end
    return leaderIDs[npcID]
end

-- Levels whose categories have leaders: creatures (an overlord or champion, ns.SubtypeLeaders),
-- factions (ns.Leaders) and player races (ns.RaceLeaders).
local function LeadersOf(level, category)
    local leaders = level == "faction" and ns.Leaders or level == "race" and ns.RaceLeaders
        or level == "subtype" and ns.SubtypeLeaders
    return leaders and leaders[category]
end

-- A category's leaders and how often the viewed player killed them: { { npcID, name, kills, kind } },
-- or nil. kind is "overlord" or "champion" for creature leaders.
local function LeaderStatus(level, category)
    local leaders = LeadersOf(level, category)
    if not leaders then return end
    local status, kills = {}, Source().kills
    for _, leader in ipairs(leaders) do
        local entry = kills[leader[1]]
        status[#status + 1] = { npcID = leader[1], name = leader[2], kills = entry and entry.count or 0, kind = leaders.kind }
    end
    return status
end

-- Crown after a faction name: gold when all its leaders are dead, grey (with "1/3" if several) until then.
local function LeaderCrown(status)
    local killed = 0
    for _, leader in ipairs(status) do
        if leader.kills > 0 then killed = killed + 1 end
    end
    if killed == #status then return CROWN end
    return #status > 1 and ("%s|cff888888%d/%d|r"):format(CROWN_GREY, killed, #status) or CROWN_GREY
end

-- Returns every recorded mob as { name, count, npcID, c = categories }.
local function CollectMobs()
    local mobs = {}
    ns.ForEachKill(function(npcID, entry)
        mobs[#mobs + 1] = {
            name = entry.name,
            count = entry.count,
            npcID = npcID,
            c = ns.Categorize(npcID, entry),
        }
    end, Source())
    return mobs
end

-- Rows for the current list: { label, count, mob, category, achievement, player or leader (one of them) }.
local function BuildRows()
    local rows = {}
    if state.view == "collection" then
        if state.viewing == COMBINED then return rows end  -- points are per player
        local p = ns.GetPoints(Source())
        for _, part in ipairs({ { "Kills", p.kills }, { "New mob types", p.newMobs }, { "Leaders", p.leaders },
            { "Achievements", p.achievements }, { "PvP", p.pvp }, { "Guild groups", p.guildGroup },
            { "Guild dungeons", p.dungeons }, { "Guild bounty", p.bounty }, { "Spent", -p.spent } }) do
            rows[#rows + 1] = { label = part[1], count = part[2], pointsPart = true }
        end
        if not state.viewing then
            rows[#rows + 1] = { label = "Mint a picture", count = ns.MintCost(), mintAction = true }
        end
        if not state.viewing then ns.UpdateDuplicates() end
        local mints = {}
        for _, mint in pairs(Source().mints or {}) do mints[#mints + 1] = mint end
        table.sort(mints, function(a, b) return a.number > b.number end)  -- newest first
        for _, mint in ipairs(mints) do
            rows[#rows + 1] = { label = ("Picture #%d"):format(mint.number), count = 0, mint = mint }
        end
        local owned = Source().collection or {}
        for _, item in ipairs(ns.Collectibles) do
            rows[#rows + 1] = { label = item.name, count = item.cost, item = item, owned = owned[item.id] ~= nil }
        end
        return rows
    end

    if state.view == "achievements" then
        for _, progress in ipairs(ns.GetAchievementProgress(Source())) do
            -- Sort key: closest to its next tier first, fully completed categories last.
            local sortKey = progress.next and progress.kills / progress.next.kills or -1
            rows[#rows + 1] = { label = progress.category, count = progress.kills, achievement = progress, sortKey = sortKey }
        end
        table.sort(rows, function(a, b)
            if a.sortKey ~= b.sortKey then return a.sortKey > b.sortKey end
            return a.label < b.label
        end)
        return rows
    end

    -- Mobs (or, on the PvP page, players) inside the categories clicked into so far.
    local view = VIEWS[state.view]
    local levels = view.levels
    local mobs = {}
    for _, mob in ipairs(view.players and ns.CollectPlayers(Source()) or CollectMobs()) do
        local inside = true
        for i, step in ipairs(state.path) do
            if CategoryOf(mob.c, levels[i]) ~= step.value then inside = false break end
        end
        if inside then mobs[#mobs + 1] = mob end
    end

    local level = levels[#state.path + 1]
    if not level then
        for _, mob in ipairs(mobs) do
            if mob.c and not mob.npcID then
                rows[#rows + 1] = { label = mob.name, count = mob.count, player = mob.player,
                    hint = not mob.player and "Honorable kills where the victim couldn't be identified." or nil }
            else
                rows[#rows + 1] = { label = mob.name, count = mob.count, mob = mob, leading = IsLeader(mob.npcID) }
            end
        end
    else
        local counts, types, keys = {}, {}, 0
        for _, mob in ipairs(mobs) do
            local key = CategoryOf(mob.c, level)
            if not counts[key] then keys = keys + 1 end
            counts[key] = (counts[key] or 0) + mob.count
            if not types[key] or types[key] == ns.OTHER then types[key] = mob.c.type end
        end
        local parent = state.path[#state.path]
        -- A level with a single choice (e.g. all your kobolds are faction "Kobold") is skipped.
        if keys == 1 and parent then
            local key = next(counts)
            state.path[#state.path + 1] = { value = key, label = ShortFaction(key, parent.value), auto = true }
            return BuildRows()
        end
        local deeper = levels[#state.path + 2]
        local hint = deeper and "Click to see its " .. (PLURALS[deeper] or deeper) .. "."
            or (view.players and "Click to see the players." or "Click to see the mobs.")
        for key, count in pairs(counts) do
            local label = level == "faction" and parent and ShortFaction(key, parent.value) or key
            -- Subtypes show their creature type, unless the subtype is the type itself.
            local note = level == "subtype" and types[key] ~= key and types[key] or nil
            rows[#rows + 1] = { label = label, count = count, category = key, note = note, hint = hint,
                leaders = LeaderStatus(level, key) }
        end
    end

    -- Inside a category with leaders (a faction, a race), they're always listed: greyed out until
    -- killed. Also when the levels below it were skipped automatically.
    for i = #state.path, 1, -1 do
        local status = LeaderStatus(levels[i], state.path[i].value)
        if status then
            local listed = {}
            for _, row in ipairs(rows) do
                if row.mob then listed[row.mob.npcID] = true end
            end
            for _, leader in ipairs(status) do
                if not listed[leader.npcID] then
                    rows[#rows + 1] = { label = leader.name, count = leader.kills, leader = leader, leading = true }
                end
            end
            break
        end
        if not state.path[i].auto then break end
    end
    -- Leaders first, then by kills.
    table.sort(rows, function(a, b)
        if (a.leading or false) ~= (b.leading or false) then return a.leading == true end
        if a.count ~= b.count then return a.count > b.count end
        return a.label < b.label
    end)
    return rows
end

-- Window ------------------------------------------------------------------------

local DIALOG_BACKDROP = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
}
local INSET_BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}
ns.UI.DIALOG_BACKDROP, ns.UI.INSET_BACKDROP = DIALOG_BACKDROP, INSET_BACKDROP

local frame = CreateFrame("Frame", "SOLCFrame", UIParent, "BackdropTemplate")
frame:SetSize(WIDTH, HEIGHT)
frame:SetPoint("CENTER")
frame:SetFrameStrata("DIALOG")
frame:SetBackdrop(DIALOG_BACKDROP)
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relativePoint, x, y = self:GetPoint()
    KillTrackerDB.ui = { point = point, relativePoint = relativePoint, x = x, y = y }
end)
frame:Hide()
tinsert(UISpecialFrames, "SOLCFrame")  -- close with Escape

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 22, -18)
title:SetText("Sleepy Ogre Leisure Club")
local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
subtitle:SetPoint("LEFT", title, "RIGHT", 10, -1)

local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -6, -6)

local sidebar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
sidebar:SetPoint("TOPLEFT", 14, -44)
sidebar:SetPoint("BOTTOMLEFT", 14, 14)
sidebar:SetWidth(SIDEBAR_WIDTH)
sidebar:SetBackdrop(INSET_BACKDROP)
sidebar:SetBackdropColor(0, 0, 0, 0.5)

local pageArea = CreateFrame("Frame", nil, frame, "BackdropTemplate")
pageArea:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 8, 0)
pageArea:SetPoint("BOTTOMRIGHT", -14, 14)
pageArea:SetBackdrop(INSET_BACKDROP)
pageArea:SetBackdropColor(0, 0, 0, 0.35)

-- Pages -------------------------------------------------------------------------------

-- [key] = { key, label, section, order, create(parent) -> frame, refresh(frame), frame }. Pages of one
-- section appear by order.
local pages, pageOrder = {}, {}

function ns.RegisterPage(page)
    pages[page.key] = page
    pageOrder[#pageOrder + 1] = page
end

local navButtons, sidebarBuilt = {}, false
local function BuildSidebar()
    if sidebarBuilt then return end
    sidebarBuilt = true
    local y = -10
    for _, section in ipairs(SECTIONS) do
        if section.label then
            local heading = sidebar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            heading:SetPoint("TOPLEFT", 12, y)
            heading:SetText(section.label:upper())
            y = y - 18
        else
            y = y - 8
        end
        local inSection = {}
        for _, page in ipairs(pageOrder) do
            if page.section == section.key then inSection[#inSection + 1] = page end
        end
        table.sort(inSection, function(a, b) return (a.order or 99) < (b.order or 99) end)
        for _, page in ipairs(inSection) do
            do
                local button = CreateFrame("Button", nil, sidebar)
                button:SetSize(SIDEBAR_WIDTH - 12, 20)
                button:SetPoint("TOPLEFT", 6, y)
                button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
                button.selected = button:CreateTexture(nil, "BACKGROUND")
                button.selected:SetAllPoints()
                button.selected:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
                button.selected:SetVertexColor(1, 0.82, 0, 0.6)
                button.selected:SetBlendMode("ADD")
                button.text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                button.text:SetPoint("LEFT", 14, 0)
                button.text:SetText(page.label)
                button:SetScript("OnClick", function() ns.OpenPage(page.key) end)
                navButtons[page.key] = button
                y = y - 21
            end
        end
        y = y - 6
    end
end

local Refresh

-- Shows a page (creating it on first use) and refreshes it.
function ns.OpenPage(key)
    if not pages[key] then return end
    state.page = key
    if not frame:IsShown() then ns.ToggleUI() else Refresh() end
end

-- Viewing someone else's stats on the list pages (from the Members page): their key in KillTrackerFriends.
function ns.ViewPlayer(key, page)
    state.viewing, state.path = key, {}
    ns.OpenPage(page or "kills")
end

-- Shared widgets ---------------------------------------------------------------------------

-- Tooltip line: grey label on the left, white value on the right.
local function AddValue(label, value)
    GameTooltip:AddDoubleLine(label, value, nil, nil, nil, 1, 1, 1)
end
ns.UI.AddValue = AddValue

-- A scrolling list in parent between top (offset from its top) and the bottom: list.content holds rows.
function ns.UI.CreateScroll(parent, top)
    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 10, -top)
    scroll:SetPoint("BOTTOMRIGHT", -30, 10)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(LIST_WIDTH, 1)
    scroll:SetScrollChild(content)
    scroll.content = content
    return scroll
end

-- A list row: highlight, a bar behind it, a label on the left and a count on the right.
function ns.UI.CreateRow(content, i)
    local row = CreateFrame("Button", nil, content)
    row:SetSize(LIST_WIDTH, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row.bar = row:CreateTexture(nil, "BACKGROUND")
    row.bar:SetPoint("TOPLEFT", 0, -1)
    row.bar:SetPoint("BOTTOMLEFT", 0, 1)
    row.bar:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    row.bar:SetVertexColor(0.8, 0.2, 0.2, 0.45)
    row.count = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.count:SetPoint("RIGHT", -4, 0)
    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.label:SetPoint("LEFT", 4, 0)
    row.label:SetPoint("RIGHT", row.count, "LEFT", -6, 0)
    row.label:SetJustifyH("LEFT")
    row.label:SetWordWrap(false)
    row.SetBar = function(self, fraction) self.bar:SetWidth(math.max(1, LIST_WIDTH * math.min(1, fraction))) end
    return row
end

-- A progress bar: bar:SetProgress(fraction, text).
function ns.UI.CreateBar(parent, width, r, g, b)
    local bar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    bar:SetSize(width, 16)
    bar:SetBackdrop(INSET_BACKDROP)
    bar:SetBackdropColor(0, 0, 0, 0.6)
    bar.fill = bar:CreateTexture(nil, "ARTWORK")
    bar.fill:SetPoint("TOPLEFT", 3, -3)
    bar.fill:SetPoint("BOTTOMLEFT", 3, 3)
    bar.fill:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar.fill:SetVertexColor(r or 0.9, g or 0.7, b or 0.1, 0.9)
    bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.text:SetPoint("CENTER")
    bar.SetProgress = function(self, fraction, text)
        self.fill:SetWidth(math.max(1, (width - 6) * math.max(0, math.min(1, fraction))))
        self.text:SetText(text or "")
    end
    return bar
end

-- A page title and a line under it, at the top of a page.
function ns.UI.CreateHeader(parent)
    local heading = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", 12, -12)
    local line = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    line:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -4)
    line:SetPoint("RIGHT", parent, "RIGHT", -12, 0)
    line:SetJustifyH("LEFT")
    return heading, line
end

-- A gold section heading at y (offset from the top of parent).
function ns.UI.CreateSection(parent, text, y)
    local heading = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    heading:SetPoint("TOPLEFT", 12, -y)
    heading:SetText(text)
    return heading
end

-- List pages (Kills, PvP, Achievements, Collection) ------------------------------------------

local list = CreateFrame("Frame", nil, pageArea)
list:SetAllPoints()
list:Hide()

local listTitle, totals = ns.UI.CreateHeader(list)

-- Viewing: you, the combined stats, or a synced guildmate - the arrows step through them.
local viewingLabel = list:CreateFontString(nil, "OVERLAY", "GameFontNormal")
local function StepViewing(delta)
    local keys = { false, COMBINED }  -- false = you
    for _, friend in ipairs(ns.GetFriends()) do keys[#keys + 1] = friend.key end
    local index = 1
    for i, key in ipairs(keys) do
        if key == (state.viewing or false) then index = i end
    end
    state.viewing = keys[(index - 1 + delta) % #keys + 1] or nil
    state.path = {}
    Refresh()
end
local function CreateArrow(direction, texture)
    local arrow = CreateFrame("Button", nil, list)
    arrow:SetSize(20, 20)
    arrow:SetNormalTexture(texture .. "-Up")
    arrow:SetPushedTexture(texture .. "-Down")
    arrow:SetDisabledTexture(texture .. "-Disabled")
    arrow:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    arrow:SetScript("OnClick", function() StepViewing(direction) end)
    arrow:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Whose stats")
        GameTooltip:AddLine("Step through yours, everyone's combined, and each synced guildmate's.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    arrow:SetScript("OnLeave", GameTooltip_Hide)
    return arrow
end
local nextArrow = CreateArrow(1, "Interface\\Buttons\\UI-SpellbookIcon-NextPage")
nextArrow:SetPoint("TOPRIGHT", -10, -10)
viewingLabel:SetPoint("RIGHT", nextArrow, "LEFT", -2, 0)
local prevArrow = CreateArrow(-1, "Interface\\Buttons\\UI-SpellbookIcon-PrevPage")
prevArrow:SetPoint("RIGHT", viewingLabel, "LEFT", -2, 0)

-- Kills: how to group them.
local viewButtons = {}
for i, key in ipairs({ "creatures", "rank", "mobs" }) do
    local button = CreateFrame("Button", nil, list, "UIPanelButtonTemplate")
    button:SetSize(100, 22)
    button:SetPoint("TOPLEFT", 10 + (i - 1) * 104, -48)
    button:SetText(VIEWS[key].label)
    button:SetScript("OnClick", function()
        state.view, state.path = key, {}
        Refresh()
    end)
    viewButtons[key] = button
end

-- Drill-down header (shown while inside a category)
local back = CreateFrame("Button", nil, list, "UIPanelButtonTemplate")
back:SetSize(60, 20)
back:SetText("< Back")
-- Up one level, also past levels that were skipped automatically.
back:SetScript("OnClick", function()
    repeat
        local step = table.remove(state.path)
    until not step or not step.auto
    Refresh()
end)
local header = list:CreateFontString(nil, "OVERLAY", "GameFontNormal")
header:SetPoint("LEFT", back, "RIGHT", 8, 0)
header:SetPoint("RIGHT", list, "RIGHT", -20, 0)
header:SetJustifyH("LEFT")
header:SetWordWrap(false)

local scroll = ns.UI.CreateScroll(list, 80)
local content = scroll.content

local empty = list:CreateFontString(nil, "OVERLAY", "GameFontDisable")
empty:SetPoint("CENTER", scroll, "CENTER")

local function ShowMobTooltip(row)
    local mob = row.data.mob
    local c = mob.c
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:AddLine(mob.name)
    AddValue("Kills", mob.count)
    AddValue("Faction", c.faction .. (c.factionGuess and " (guess)" or ""))
    AddValue("Subtype", c.subtype .. (c.subtypeGuess and " (guess)" or ""))
    AddValue("Type", c.type)
    AddValue("Rank", c.rank or NORMAL_RANK)
    GameTooltip:AddLine(ns.WOWHEAD_NPC_URL:format(mob.npcID), 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

local function ShowAchievementTooltip(row)
    local progress = row.data.achievement
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:AddLine(progress.category)
    AddValue("Kills", progress.kills)
    GameTooltip:AddLine(" ")
    for _, tier in ipairs(progress.tiers) do
        if tier.earned then
            GameTooltip:AddDoubleLine(tier.name, tier.time and date("%Y-%m-%d", tier.time) or "Earned", 0.2, 1, 0.2, 0.2, 1, 0.2)
        else
            GameTooltip:AddDoubleLine(tier.name, ("%d kills"):format(tier.kills), 0.6, 0.6, 0.6, 0.6, 0.6, 0.6)
        end
    end
    GameTooltip:Show()
end

local rows = {}
local function GetRow(i)
    if rows[i] then return rows[i] end
    local row = ns.UI.CreateRow(content, i)
    row:SetScript("OnClick", function(self)
        if self.data.category then
            state.path[#state.path + 1] = { value = self.data.category, label = self.data.label }
            Refresh()
        elseif self.data.item and not self.data.owned and not state.viewing then
            ns.ConfirmBuy(self.data.item)
        elseif self.data.mintAction then
            ns.ConfirmMint()
        elseif self.data.mint then
            if self.data.mint.duplicateOf and not state.viewing then
                ns.ConfirmReroll(self.data.mint)
            else
                ns.ShowMint(self.data.mint)
            end
        end
    end)
    row:SetScript("OnEnter", function(self)
        if self.data.mob then
            ShowMobTooltip(self)
        elseif self.data.achievement then
            ShowAchievementTooltip(self)
        elseif self.data.item then
            local item = self.data.item
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(("|c%s%s|r"):format(ns.RARITY_COLORS[item.rarity] or "ffffffff", item.name))
            if item.description then GameTooltip:AddLine(item.description, 1, 1, 1, true) end
            AddValue("Cost", ("%d points"):format(item.cost))
            GameTooltip:AddLine(self.data.owned and "In your collection" or "Click to buy", 0.6, 0.6, 0.6)
            GameTooltip:Show()
        elseif self.data.mint then
            local mint = self.data.mint
            local rarity = ns.MintRarity(mint.traits)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(("|c%s%s|r"):format(ns.RARITY_COLORS[rarity], self.data.label))
            for _, trait in ipairs(ns.MintTraits(mint.traits)) do
                GameTooltip:AddDoubleLine(trait[1], ("|c%s%s|r"):format(ns.RARITY_COLORS[trait[3]], trait[2]))
            end
            AddValue("Minted", date("%Y-%m-%d %H:%M", mint.time))
            if mint.duplicateOf then
                GameTooltip:AddLine(("Duplicate: %s minted this picture first."):format(mint.duplicateOf), 1, 0.4, 0.4, true)
                GameTooltip:AddLine("Click to reroll it for free", 0.6, 0.6, 0.6)
            else
                GameTooltip:AddLine("Unique in your guild", 0.2, 1, 0.2)
                GameTooltip:AddLine("Click to view", 0.6, 0.6, 0.6)
            end
            GameTooltip:Show()
        elseif self.data.mintAction then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Mint a picture")
            GameTooltip:AddLine("Rolls a random background, skin, outfit, expression, eyes, accessory and headwear. Rarer traits make a rarer picture.", 1, 1, 1, true)
            GameTooltip:Show()
        elseif self.data.pointsPart then
            return
        elseif self.data.player then
            local p = self.data.player
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(p.realm and (p.name .. "-" .. p.realm) or p.name)
            AddValue("Kills", p.count)
            AddValue("Race", p.race or "?")
            AddValue("Class", p.class or "?")
            if p.level then AddValue("Level", p.level) end
            if p.zone and p.zone ~= "" then AddValue("Last killed in", p.zone) end
            if p.time then AddValue("Last killed", date("%Y-%m-%d %H:%M", p.time)) end
            GameTooltip:Show()
        elseif self.data.leader then
            local leader = self.data.leader
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(leader.name)
            GameTooltip:AddLine(LEADER_TITLES[leader.kind] or (state.view == "pvp" and "Ruler of this race")
                or "Leader of this faction", 1, 0.82, 0)
            AddValue("Kills", leader.kills > 0 and leader.kills or "Not killed yet")
            GameTooltip:AddLine(ns.WOWHEAD_NPC_URL:format(leader.npcID), 0.6, 0.6, 0.6)
            GameTooltip:Show()
        else
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(self.data.label)
            for _, leader in ipairs(self.data.leaders or {}) do
                if leader.kills > 0 then
                    GameTooltip:AddDoubleLine(LeaderTitle(leader) .. ": " .. leader.name, "Killed", 1, 0.82, 0, 0.2, 1, 0.2)
                else
                    GameTooltip:AddDoubleLine(LeaderTitle(leader) .. ": " .. leader.name, "Not killed yet", 1, 0.82, 0, 0.6, 0.6, 0.6)
                end
            end
            GameTooltip:AddLine(self.data.hint, 1, 1, 1)
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)
    rows[i] = row
    return row
end

local function WhoIsViewed()
    if state.viewing == COMBINED then return "|cffffd100Combined|r" end
    if state.viewing then return ("|cff66ccff%s|r"):format(Ambiguate(state.viewing, "short")) end
    return ns.MyName()
end

local function RefreshList()
    local hasFriends = next(KillTrackerFriends) ~= nil
    if state.viewing == COMBINED then
        if hasFriends then state.combined = ns.BuildCombined() else state.viewing = nil end
    elseif state.viewing and not KillTrackerFriends[state.viewing] then
        state.viewing = nil
    end
    prevArrow:SetShown(hasFriends)
    nextArrow:SetShown(hasFriends)
    viewingLabel:SetText(hasFriends and WhoIsViewed() or "")

    local source = Source()
    local page = state.page
    listTitle:SetText(pages[page].label)
    if page == "collection" then
        if state.viewing == COMBINED then
            totals:SetText("Points are per player.")
        else
            local p = ns.GetPoints(source)
            totals:SetText(("|cffffd100%d points|r (%d earned, %d spent)"):format(p.balance, p.earned, p.spent))
        end
    elseif page == "pvp" then
        local pvp = source.pvp or { total = 0 }
        totals:SetText(state.viewing and ("%d PvP kills"):format(pvp.total)
            or ("%d PvP kills (%d this session)"):format(pvp.total, ns.GetSessionPvPKills()))
    elseif state.viewing == COMBINED then
        totals:SetText(("%d players - %d kills - %d achievements"):format(source.members, source.total, ns.GetAchievementTotals(source)))
    elseif state.viewing then
        totals:SetText(("%d kills - %d achievements - updated %s"):format(source.total, ns.GetAchievementTotals(source),
            ns.TimeAgo(source.received)))
    else
        totals:SetText(("%d kills (%d this session) - %d achievements"):format(source.total, ns.GetSessionKills(),
            ns.GetAchievementTotals(source)))
    end

    local isKills = page == "kills"
    for key, button in pairs(viewButtons) do
        button:SetShown(isKills)
        if key == state.view then button:LockHighlight() else button:UnlockHighlight() end
    end

    local data = BuildRows()
    local total, max = 0, 0
    for _, d in ipairs(data) do
        if not d.leader then total = total + d.count end  -- leaders listed from elsewhere don't add up
        if d.count > max then max = d.count end
    end

    local top = isKills and 76 or 50
    local inside = #state.path > 0
    back:SetShown(inside)
    header:SetShown(inside)
    if inside then
        local labels = {}
        for _, step in ipairs(state.path) do
            if step.label ~= labels[#labels] then labels[#labels + 1] = step.label end  -- "Kobold > Kobold"
        end
        header:SetText(("%s (%d)"):format(table.concat(labels, " > "), total))
        back:ClearAllPoints()
        back:SetPoint("TOPLEFT", 10, -top)
        top = top + 24
    end
    scroll:SetPoint("TOPLEFT", 10, -top)

    for i, d in ipairs(data) do
        local row = GetRow(i)
        row.data = d
        row.label:SetText(d.label)
        local barFraction = max > 0 and d.count / max or 0
        row.bar:SetVertexColor(0.8, 0.2, 0.2, 0.45)
        if d.mintAction then
            row.label:SetText("|cffffd100+ Mint a picture|r")
            row.count:SetText(("%d points"):format(d.count))
            barFraction = 0
        elseif d.mint then
            local rarity = ns.MintRarity(d.mint.traits)
            row.label:SetText(("|c%s%s|r"):format(ns.RARITY_COLORS[rarity], d.label)
                .. (d.mint.duplicateOf and "  |cffff6060Duplicate|r" or ""))
            row.count:SetText(d.mint.duplicateOf and "|cffffd100Reroll free|r"
                or ("|c%s%s|r"):format(ns.RARITY_COLORS[rarity], (rarity:gsub("^%l", string.upper))))
            barFraction = 0
        elseif d.pointsPart then
            row.label:SetText(d.label)
            row.count:SetText((d.count < 0 and "|cffff6060%d|r" or "|cffffd100+%d|r"):format(d.count))
            barFraction = 0
        elseif d.item then
            local color = ns.RARITY_COLORS[d.item.rarity] or "ffffffff"
            row.label:SetText(("|T%s:14|t |c%s%s|r"):format(d.item.texture or "Interface\\Icons\\INV_Misc_QuestionMark", color, d.label))
            row.count:SetText(d.owned and "|cff33ff33Owned|r" or ("%d points"):format(d.count))
            barFraction = 0
        elseif d.achievement then
            local progress = d.achievement
            row.label:SetText(progress.tribe and ("%s  |cff999999tribe|r"):format(progress.category)
                or ("%s  |cff999999%d/%d|r"):format(progress.category, progress.earned, #progress.tiers))
            if progress.next then
                row.count:SetText(("%d/%d"):format(progress.kills, progress.next.kills))
                barFraction = progress.kills / progress.next.kills
            else
                row.count:SetText("|cff33ff33Complete|r")
                barFraction = 1
            end
            row.bar:SetVertexColor(1, 0.5, 0.1, 0.45)
        elseif d.leader then
            local killed = d.leader.kills > 0
            row.label:SetText((killed and CROWN or CROWN_GREY) .. " " .. (killed and d.label or "|cff888888" .. d.label .. "|r"))
            row.count:SetText(killed and d.count or "|cff888888not killed|r")
        elseif d.category then
            local label = d.note and ("%s  |cff999999%s|r"):format(d.label, d.note) or d.label
            row.label:SetText(d.leaders and label .. "  " .. LeaderCrown(d.leaders) or label)
            row.count:SetText(("%d  |cff999999%d%%|r"):format(d.count, total > 0 and math.floor(d.count / total * 100 + 0.5) or 0))
        else
            if d.leading then row.label:SetText(CROWN .. " " .. d.label) end
            row.count:SetText(d.count)
        end
        row:SetBar(barFraction)
        row:Show()
    end
    for i = #data + 1, #rows do
        rows[i]:Hide()
    end
    content:SetHeight(math.max(1, #data * ROW_HEIGHT))
    empty:SetText(state.viewing == COMBINED and page == "collection" and "" or EMPTY_TEXT[state.view] or "No kills recorded yet.")
    empty:SetShown(#data == 0)
end

-- The list pages share one frame; each sets which list it shows.
local function ListPage(key, label, order, view)
    ns.RegisterPage({
        key = key, label = label, section = "me", order = order,
        create = function() return list end,
        refresh = function()
            if state.listPage ~= key then state.path = {} end
            state.listPage = key
            if view then
                state.view = view
            elseif not viewButtons[state.view] then
                state.view = "creatures"  -- Kills keeps its grouping between visits
            end
            RefreshList()
        end,
    })
end

-- Picture viewer, next to the window --------------------------------------------

local viewer = CreateFrame("Frame", "SOLCMintViewer", frame, "BackdropTemplate")
viewer:SetSize(290, 400)
viewer:SetPoint("TOPLEFT", frame, "TOPRIGHT", -6, 0)
viewer:SetBackdrop(DIALOG_BACKDROP)
viewer:EnableMouse(true)
viewer:Hide()

viewer.title = viewer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
viewer.title:SetPoint("TOP", 0, -18)
viewer.rarity = viewer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
viewer.rarity:SetPoint("TOP", viewer.title, "BOTTOM", 0, -4)
viewer.canvas = CreateFrame("Frame", nil, viewer)
viewer.canvas:SetSize(256, 256)
viewer.canvas:SetPoint("TOP", 0, -56)
viewer.traits = viewer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
viewer.traits:SetPoint("TOPLEFT", viewer.canvas, "BOTTOMLEFT", 0, -8)
viewer.traits:SetPoint("TOPRIGHT", viewer.canvas, "BOTTOMRIGHT", 0, -8)
viewer.traits:SetJustifyH("LEFT")
local viewerClose = CreateFrame("Button", nil, viewer, "UIPanelCloseButton")
viewerClose:SetPoint("TOPRIGHT", -6, -6)

-- Shows a picture next to the window. owner: whose it is, if not yours.
function ns.ShowMint(mint, owner)
    local rarity = ns.MintRarity(mint.traits)
    viewer.title:SetText(owner and ("%s's #%d"):format(owner, mint.number) or ("Picture #%d"):format(mint.number))
    viewer.rarity:SetText(("|c%s%s|r"):format(ns.RARITY_COLORS[rarity], (rarity:gsub("^%l", string.upper))))
    ns.RenderMint(viewer.canvas, mint.traits)
    local lines = {}
    for _, trait in ipairs(ns.MintTraits(mint.traits)) do
        lines[#lines + 1] = ("|cffffd100%s:|r |c%s%s|r"):format(trait[1], ns.RARITY_COLORS[trait[3]], trait[2])
    end
    viewer.traits:SetText(table.concat(lines, "\n"))
    if not frame:IsShown() then ns.ToggleUI() end
    viewer:Show()
end

-- Refresh -------------------------------------------------------------------

function Refresh()
    BuildSidebar()
    local guild = IsInGuild() and GetGuildInfo("player")
    subtitle:SetText(guild and ("|cff40ff40<%s>|r  %s"):format(guild, ns.MyName()) or ns.MyName())
    local current = pages[state.page] or pages.overview
    state.page = current.key
    for key, page in pairs(pages) do
        if key ~= current.key and page.frame and page.frame ~= (current.frame or false) then page.frame:Hide() end
        if navButtons[key] then
            navButtons[key].selected:SetShown(key == current.key)
            navButtons[key].text:SetFontObject(key == current.key and "GameFontNormal" or "GameFontHighlight")
        end
    end
    if not current.frame then
        current.frame = current.create(pageArea)
        current.frame:SetParent(pageArea)
    end
    current.frame:Show()
    current.refresh(current.frame)
end

frame:SetScript("OnShow", Refresh)

-- Public ----------------------------------------------------------------------

function ns.ToggleUI()
    if frame:IsShown() then
        frame:Hide()
        return
    end
    local pos = KillTrackerDB.ui
    if pos then
        frame:ClearAllPoints()
        frame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
    end
    frame:Show()
end

function ns.OnKillsChanged()
    if frame:IsShown() then Refresh() end
end
ns.OnFriendsChanged = ns.OnKillsChanged

ListPage("kills", "Kills", 2)
ListPage("pvp", "PvP", 3, "pvp")
ListPage("achievements", "Achievements", 4, "achievements")
ListPage("collection", "Collection", 5, "collection")
