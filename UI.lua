-- The Sleepy Ogre Leisure Club window: a sidebar of pages on the left, the chosen page on the right.
--   Me      Overview, Kills (+ PvP tab), Achievements, Collection
--   Guild   Home, Members (+ Crafters tab), Leaderboard (+ Bounties tab), Gallery (GuildPages.lua)
--   Settings: the cog in the top right
-- A page with tabOf = "<key>" has no sidebar button: it's a tab of that page, in the tabs under the window.
-- Pages register with ns.RegisterPage; this file has the window, the sidebar, and the list pages (Kills,
-- PvP, Achievements, Collection), which show your stats, the combined stats of everyone you follow (see
-- Combined.lua) or a synced guildmate's (see Sync.lua), chosen with the arrows in the page header.

local _, ns = ...

local WIDTH, HEIGHT = 950, 625
local SIDEBAR_LEFT, SIDEBAR_WIDTH = 36, 150  -- the menu column, its right edge against the frame's left post
local VIEWING_WIDTH = 170  -- the name between the "whose stats" arrows: fixed, so the arrows don't move
local ARROW_SIZE = 26     -- the arrows (spellbook page textures, drawn for 32px; smaller clips their edges)
-- The page area: inside the wooden frame (OverviewLayout.lua, tools/overview-layout.js).
local INNER = ns.OverviewLayout and ns.OverviewLayout.inner or { left = 206, right = 923, top = 44, bottom = 588 }
local PAGE_WIDTH, PAGE_HEIGHT = INNER.right - INNER.left - 8, INNER.bottom - INNER.top - 10
local ROW_HEIGHT = 18
local LIST_WIDTH = PAGE_WIDTH - 40
local NORMAL_RANK = "Normal"
local SECTIONS = { { key = "me" }, { key = "guild" } }  -- in this order, one chain; Settings: the cog

ns.UI = { PAGE_WIDTH = PAGE_WIDTH, PAGE_HEIGHT = PAGE_HEIGHT, ROW_HEIGHT = ROW_HEIGHT, VIEWING_WIDTH = VIEWING_WIDTH,
    ARROW_SIZE = ARROW_SIZE }

-- Kill views: levels are the categories (fields of ns.Categorize's result) a view drills through, one
-- click each, before listing the mobs themselves.
local VIEWS = {
    creatures = { label = "Creatures", levels = { "subtype", "faction" } },
    rank = { label = "Rank", levels = { "rank" } },
    mobs = { label = "Mobs", levels = {} },
    pvp = { levels = { "race", "class" }, players = true },
    rares = { levels = { "zone" }, rares = true },  -- every rare in the game (Rares.lua), by zone
}
local PLURALS = { subtype = "subtypes", faction = "factions", rank = "ranks", race = "races", class = "classes", zone = "zones" }

local EMPTY_TEXT = {
    achievements = "No achievements yet - keep killing.",
    rares = "No rares known.",
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
-- Our own crown (Media/Crown.blp, tools/make-crown.js) is drawn in greys, so the escape colours it: gold once
-- killed, a real grey until then.
local CROWN = "|TInterface\\AddOns\\SOLC\\Media\\Crown:16:16:0:1:32:32:0:32:0:32:255:204:60|t"
local CROWN_GREY = "|TInterface\\AddOns\\SOLC\\Media\\Crown:16:16:0:1:32:32:0:32:0:32:140:140:140|t"
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

-- Rares (Rares.lua): a silver star, gold once killed. Each rare's categories (as for kills), and zone.
local RARE_STAR = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:14:14:0:0:64:64:0:64:0:64:255:210:60|t"
local RARE_STAR_GREY = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:14:14:0:0:64:64:0:64:0:64:150:150:150|t"
local rareCategories  -- [npcID] = categories, with zone (built on first use)
local function RareCategories()
    if not rareCategories then
        rareCategories = {}
        for npcID, rare in pairs(ns.Rares or {}) do
            local c = ns.Categorize(npcID, { name = rare[1] })
            c.zone = ns.RareZones[rare[2]]
            rareCategories[npcID] = c
        end
    end
    return rareCategories
end
local function IsRare(npcID) return ns.Rares and ns.Rares[npcID] ~= nil end

-- The rares inside the categories clicked into so far (path: { value } per level of levels), how often the viewed
-- player killed them: { { npcID, name, kills, zone, level, elite, c } }.
local function RaresInside(levels, path)
    local list, kills = {}, Source().kills or {}
    for npcID, c in pairs(RareCategories()) do
        local inside = true
        for i, step in ipairs(path) do
            if CategoryOf(c, levels[i]) ~= step.value then inside = false break end
        end
        if inside then
            local rare, entry = ns.Rares[npcID], kills[npcID]
            list[#list + 1] = { npcID = npcID, name = rare[1], kills = entry and entry.count or 0, zone = c.zone,
                level = rare[3], elite = rare[4], c = c }
        end
    end
    return list
end
-- "rares 1/3" after a category with rares: found / all, gold when all are found.
local function RareNote(found, all)
    if all == 0 then return nil end
    return (found == all and "|cffffd200rares %d/%d|r" or "|cff999999rares %d/%d|r"):format(found, all)
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
-- Functions returning extra Collection rows { label, right, onClick(), onEnter(row) } (SOLC.AddCollectionRows).
ns.CollectionProviders = {}

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
        -- Rows from sister addons (SOLC.AddCollectionRows), e.g. saved paintings. Only your own collection.
        if not state.viewing then
            for _, provider in ipairs(ns.CollectionProviders) do
                for _, extra in ipairs(provider() or {}) do
                    rows[#rows + 1] = { label = extra.label, count = 0, extra = extra }
                end
            end
        end
        local owned = Source().collection or {}
        for _, item in ipairs(ns.Collectibles) do
            rows[#rows + 1] = { label = item.name, count = item.cost, item = item, owned = owned[item.id] ~= nil }
        end
        return rows
    end

    if state.view == "rares" then
        if #state.path == 0 then
            local found, all = {}, {}
            for _, rare in ipairs(RaresInside({}, {})) do
                all[rare.zone] = (all[rare.zone] or 0) + 1
                if rare.kills > 0 then found[rare.zone] = (found[rare.zone] or 0) + 1 end
            end
            for zone, count in pairs(all) do
                rows[#rows + 1] = { label = zone, count = found[zone] or 0, category = zone, rareZone = true,
                    rareAll = count, hint = "Click to see its rares." }
            end
            table.sort(rows, function(a, b)
                local fa, fb = a.count / a.rareAll, b.count / b.rareAll
                if fa ~= fb then return fa > fb end
                return a.label < b.label
            end)
        else
            for _, rare in ipairs(RaresInside({ "zone" }, state.path)) do
                rows[#rows + 1] = { label = rare.name, count = rare.kills, rare = rare }
            end
            table.sort(rows, function(a, b)
                if (a.count > 0) ~= (b.count > 0) then return a.count > 0 end
                return a.rare.level < b.rare.level
            end)
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
                rows[#rows + 1] = { label = mob.name, count = mob.count, mob = mob, leading = IsLeader(mob.npcID),
                    rareMob = IsRare(mob.npcID) }
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
        if not view.players then
            local path = { unpack(state.path) }
            for _, row in ipairs(rows) do
                if row.category then
                    path[#state.path + 1] = { value = row.category }
                    local found, all = 0, 0
                    for _, rare in ipairs(RaresInside(levels, path)) do
                        all = all + 1
                        if rare.kills > 0 then found = found + 1 end
                    end
                    row.rares = RareNote(found, all)
                end
            end
        end
    end

    -- Inside a category, its rares are always listed like the leaders: greyed out until killed. Those in a
    -- category shown below (one you can click into) are listed in there instead.
    if #state.path > 0 and not view.players then
        local listed, shown = {}, {}
        for _, row in ipairs(rows) do
            if row.mob then listed[row.mob.npcID] = true end
            if row.category then shown[row.category] = true end
        end
        local next = levels[#state.path + 1]
        for _, rare in ipairs(RaresInside(levels, state.path)) do
            if not listed[rare.npcID] and rare.kills == 0 and not (next and shown[CategoryOf(rare.c, next)]) then
                rows[#rows + 1] = { label = rare.name, count = 0, rare = rare }
            end
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
    bgFile = ns.WINDOW_BACKGROUND,  -- solid (the dialog texture is see-through)
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
-- The window's background only behind the pages, its edges under the wooden frame (the posts and the bottom
-- planks, further down): the menu column on the left has none, its planks hang in the open under the logo.
-- Outside the frame the window doesn't take the mouse either (clicks there reach the game).
local BODY = { left = INNER.left - 16, right = INNER.right + 16, bottom = INNER.bottom + 12 }  -- under the posts' middles
local body = CreateFrame("Frame", nil, frame, "BackdropTemplate")
body:SetPoint("TOPLEFT", BODY.left, 0)
body:SetPoint("BOTTOMRIGHT", BODY.right - WIDTH, HEIGHT - BODY.bottom)
body:SetFrameLevel(frame:GetFrameLevel())
body:SetBackdrop({ bgFile = ns.WINDOW_BACKGROUND })
body:SetBackdropColor(unpack(ns.WINDOW_COLOR))
frame:SetHitRectInsets(BODY.left, WIDTH - BODY.right, 0, HEIGHT - BODY.bottom)
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

-- The club logo instead of a title: over the top-left corner, centred over the menu column, its two banners
-- hanging down over the menu column's top border (Media/Logo.blp, made by tools/convert-logo.js).
local LOGO_SIZE = 210  -- the texture is square; the logo itself fills its width and about 3/4 of its height
local logo = CreateFrame("Frame", nil, frame)
logo:SetSize(LOGO_SIZE, LOGO_SIZE)
-- Centred over the sidebar; the banner tips (about 0.92 of the texture down) end LOGO_BANNERS px below the
-- window's top edge, just over the sidebar's top (at 44).
local LOGO_BANNERS = 52
local LOGO_Y = LOGO_SIZE * 0.92 - LOGO_BANNERS - 31  -- the logo's top, above the window's top edge
local LOGO_SIGN_BOTTOM = 1060 / 1254  -- the "Leisure Club" sign's bottom edge, share of the texture's height
logo:SetPoint("TOPLEFT", frame, "TOPLEFT", SIDEBAR_LEFT + SIDEBAR_WIDTH / 2 - LOGO_SIZE / 2 - 5, LOGO_Y)
logo:SetFrameLevel(frame:GetFrameLevel() + 50)
logo.texture = logo:CreateTexture(nil, "OVERLAY")
logo.texture:SetAllPoints()
logo.texture:SetTexture("Interface\\AddOns\\SOLC\\Media\\Logo")
-- Keep the logo on screen too when the window is dragged to an edge.
frame:SetClampRectInsets(-20, 0, LOGO_SIZE * 0.92 - LOGO_BANNERS, 0)

-- Dragging the logo moves the window. A frame takes the mouse over its whole rectangle, so instead of the
-- logo frame, invisible handles cover only its visible parts (ns.LogoMask, one per run of opaque cells):
-- clicks on the transparent corners still reach whatever is behind them.
do
    local mask = ns.LogoMask
    local cell = LOGO_SIZE / (mask and mask.cells or 1)
    for row, runs in ipairs(mask and mask.rows or {}) do
        for _, run in ipairs(runs) do
            local handle = CreateFrame("Frame", nil, logo)
            handle:SetPoint("TOPLEFT", (run[1] - 1) * cell, -(row - 1) * cell)
            handle:SetSize((run[2] - run[1] + 1) * cell, cell)
            handle:EnableMouse(true)
            handle:RegisterForDrag("LeftButton")
            handle:SetScript("OnDragStart", function() frame:StartMoving() end)
            handle:SetScript("OnDragStop", function() frame:GetScript("OnDragStop")(frame) end)
        end
    end
end

-- Frame ---------------------------------------------------------------------------------------------------
-- A wooden post down each side of the pages, broken planks along the bottom and grey squares on the corners,
-- on every page (OverviewLayout.lua, from tools/overview-layout.js; the textures in Media/Overview, from
-- tools/convert-overview.js). Over the pages, under the header.
local OVERVIEW_ART = "Interface\\AddOns\\SOLC\\Media\\Overview\\"
local DRAW_LAYERS = { "BACKGROUND", "BORDER", "ARTWORK", "OVERLAY" }
-- Draws a layout piece on parent: { x, y (centre, from the window's top-left, y down), w, h, tilt (degrees
-- clockwise), texture, shade, flip, coords (the part of the texture to draw: left, right, top, bottom) }.
-- order: its place in its list; later pieces go on top (16 per draw layer).
function ns.UI.WoodPiece(parent, piece, order)
    local i = (order or 1) - 1
    local texture = parent:CreateTexture(nil, DRAW_LAYERS[math.min(4, math.floor(i / 16) + 1)], nil, i % 16 - 8)
    texture:SetTexture(OVERVIEW_ART .. piece.texture)
    texture:SetSize(piece.w, piece.h)
    texture:SetPoint("CENTER", frame, "TOPLEFT", piece.x, -piece.y)
    if piece.coords then texture:SetTexCoord(unpack(piece.coords)) end
    if piece.flip then texture:SetTexCoord(1, 0, 0, 1) end
    if piece.tilt ~= 0 then texture:SetRotation(-math.rad(piece.tilt)) end  -- WoW turns anticlockwise
    local shade = piece.shade or 1
    texture:SetVertexColor(shade, shade, shade)
    return texture
end
local woodFrame = CreateFrame("Frame", nil, frame)
woodFrame:SetAllPoints()
woodFrame:SetFrameLevel(frame:GetFrameLevel() + 30)
for i, piece in ipairs(ns.OverviewLayout and ns.OverviewLayout.frame or {}) do ns.UI.WoodPiece(woodFrame, piece, i) end
ns.UI.frame = frame  -- for pages that place things in window coordinates (OverviewCard.lua)
ns.UI.FRAME_LEVEL = { wood = 30, header = 40 }  -- above the window's own level

-- Header ------------------------------------------------------------------------------------------------
-- Wooden planks along the window's top edge, from the logo to the two square buttons (Settings and Close), as
-- laid out in HeaderLayout.lua (tools/header-layout.js, which also draws a preview). Every plank is one of two
-- small textures (Media/Wood, tools/convert-wood.js), stretched and tilted. Under the logo, over the window.
local WOOD = "Interface\\AddOns\\SOLC\\Media\\Wood\\"
local ICONS = "Interface\\AddOns\\SOLC\\Media\\Icons\\"
local HEADER_WOOD_SHADE = 0.81  -- a little darker than painted, like the frame (tools/convert-overview.js WOOD_SHADE)
local woodHeader = CreateFrame("Frame", nil, frame)
woodHeader:SetAllPoints()
woodHeader:SetFrameLevel(frame:GetFrameLevel() + 40)
-- One tilted texture, centred on (x, y) from the window's top-left (y down).
local function Board(layer, file, x, y, w, h, tilt, shade)
    local texture = woodHeader:CreateTexture(nil, "ARTWORK", nil, layer)
    texture:SetTexture(WOOD .. file)
    texture:SetSize(w, h)
    texture:SetPoint("CENTER", frame, "TOPLEFT", x, -y)
    texture:SetRotation(-math.rad(tilt))  -- the layout's tilt is clockwise; WoW turns anticlockwise
    shade = shade * HEADER_WOOD_SHADE
    texture:SetVertexColor(shade, shade, shade)
end
local PLANK_END = ns.HeaderLayout and ns.HeaderLayout.plankEnd or 0.645
for i, plank in ipairs(ns.HeaderLayout and ns.HeaderLayout.planks or {}) do
    local layer = math.min(7, i - 8)  -- later planks on top
    local shade = plank.shade or 1     -- the back row a little darker, for depth
    if plank.texture == "Plank" then
        -- In three parts, like the sidebar buttons: the ends (with the nails) at their own shape, the middle
        -- stretched; each turned by the plank's tilt and placed along its line, so they stay joined.
        local endWidth = math.min(plank.h * PLANK_END, plank.w / 2 - 1)
        local angle = math.rad(plank.tilt)
        local reach = (plank.w - endWidth) / 2
        local dx, dy = math.cos(angle) * reach, math.sin(angle) * reach
        Board(layer, "Plank", plank.x, plank.y, plank.w - 2 * endWidth + 2, plank.h, plank.tilt, shade)
        Board(layer, "PlankLeft", plank.x - dx, plank.y - dy, endWidth, plank.h, plank.tilt, shade)
        Board(layer, "PlankRight", plank.x + dx, plank.y + dy, endWidth, plank.h, plank.tilt, shade)
    else
        Board(layer, plank.texture, plank.x, plank.y, plank.w, plank.h, plank.tilt, shade)
    end
end
-- The plank strip moves the window too, like the logo (just the band the planks cover, so the pages under it
-- still take clicks).
local headerGrip = CreateFrame("Frame", nil, woodHeader)
headerGrip:SetPoint("TOPLEFT", frame, "TOPLEFT", 186, 8)
headerGrip:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -110, -42)
headerGrip:EnableMouse(true)
headerGrip:RegisterForDrag("LeftButton")
headerGrip:SetScript("OnDragStart", function() frame:StartMoving() end)
headerGrip:SetScript("OnDragStop", function() frame:GetScript("OnDragStop")(frame) end)

-- A square wooden button with a painted icon, behaving like the sidebar's planks: dimmed at rest, lit while
-- hovered or pressed, shrinking a little when pressed (as much as the sidebar's pushed art) with the icon
-- dipping, and lit with a gold icon while selected (button:SetSelected, the Settings page being open).
-- Click sounds for the wooden buttons: the game's own clack of putting down a small wooden item, and now and
-- then (1 in 30, 1 in 10 in ogre mode) an ogre's grunt or battle cry instead. Off with /solc sounds
-- (KillTrackerDB.clickSounds = false). Game sound files by id (the original ogre and item sounds).
local CLICK_SOUND = 567566        -- sound/interface/pickup/putdownwoodsmall.ogg
local OGRE_SOUNDS = { 557657, 557662, 557656, 557661, 557651 }  -- mogrefidget1-2, mogreaggro1-3
function ns.UI.ClickSound()
    if KillTrackerDB and KillTrackerDB.clickSounds == false then return end
    local ogre = KillTrackerDB and KillTrackerDB.ogreMode
    local voices = ns.RankPerk and ns.RankPerk("voices") or 1  -- your rank makes them more frequent (Ranks.lua)
    if math.random(math.floor((ogre and 10 or 30) / voices)) == 1 then
        PlaySoundFile(OGRE_SOUNDS[math.random(#OGRE_SOUNDS)], "SFX")
    else
        PlaySoundFile(CLICK_SOUND, "SFX")
    end
end

local HEADER_DIMMED = 0.55  -- as the sidebar's unselected planks (DIMMED, further down)
local HEADER_PUSHED = ns.ButtonArt and ns.ButtonArt.pushed.width / ns.ButtonArt.normal.width or 0.96
ns.UI.HEADER_DIMMED, ns.UI.HEADER_PUSHED = HEADER_DIMMED, HEADER_PUSHED  -- the GEARZ button behaves the same (OverviewCard.lua)
local function HeaderButton(spec, tooltip, onClick)
    local button = CreateFrame("Button", nil, woodHeader)
    button:SetFrameLevel(woodHeader:GetFrameLevel() + 2)
    button:SetSize(spec.w, spec.h)
    button:SetPoint("TOPLEFT", frame, "TOPLEFT", spec.x, -spec.y)
    local wood = button:CreateTexture(nil, "ARTWORK")
    wood:SetPoint("CENTER")
    wood:SetTexture(WOOD .. "Square")
    local icon = button:CreateTexture(nil, "OVERLAY")
    icon:SetTexture(ICONS .. spec.icon)
    -- Runes as on the sidebar planks, one at each side: blue, yellow while selected.
    local runes = {}
    if spec.runes then
        local runeHeight = spec.h * (ns.HeaderLayout.runeHeight or 0.6)
        for side = 1, 2 do
            local rune = button:CreateTexture(nil, "OVERLAY")
            rune:SetTexture(WOOD .. "Rune")
            rune:SetSize(runeHeight / 2, runeHeight)
            rune:SetPoint("CENTER", button, side == 1 and "LEFT" or "RIGHT", (side == 1 and 1 or -1) * (3 + runeHeight / 4), 0)
            if side == 2 then rune:SetTexCoord(1, 0, 0, 1) end  -- mirrored, as the plank's right end
            runes[side] = rune
        end
    end
    local hovered, pressed, selected = false, false, false
    local function Redraw()
        local lit = hovered or pressed or selected
        local shade = lit and 1 or HEADER_DIMMED
        wood:SetVertexColor(shade, shade, shade)
        local scale = pressed and HEADER_PUSHED or 1
        wood:SetSize(spec.w * scale, spec.h * scale)
        icon:SetSize(spec.iconSize * scale, spec.iconSize * scale)
        icon:SetPoint("CENTER", pressed and 1 or 0, pressed and -2 or 0)
        if selected then icon:SetVertexColor(1, 0.82, 0) else icon:SetVertexColor(lit and 1 or 0.85, lit and 1 or 0.85, lit and 1 or 0.85) end
        for _, rune in ipairs(runes) do
            if selected then rune:SetVertexColor(0.92, 0.82, 0.14) else rune:SetVertexColor(0.22 * shade, 0.36 * shade, 0.78 * shade) end
        end
    end
    function button:SetSelected(value)
        selected = value and true or false
        Redraw()
    end
    button:SetScript("OnEnter", function(self)
        hovered = true
        Redraw()
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(tooltip)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        hovered, pressed = false, false
        Redraw()
        GameTooltip_Hide()
    end)
    button:SetScript("OnMouseDown", function() pressed = true Redraw() end)
    button:SetScript("OnMouseUp", function() pressed = false Redraw() end)
    button:SetScript("OnClick", function(...) ns.UI.ClickSound() onClick(...) end)
    Redraw()
    return button
end
local settingsButton  -- lit while the Settings page is open (Refresh)
local buttons = ns.HeaderLayout and ns.HeaderLayout.buttons
if buttons then
    settingsButton = HeaderButton(buttons.settings, "Settings", function() ns.OpenPage("settings") end)
    HeaderButton(buttons.close, "Close", function() frame:Hide() end)
end

-- The menu column: no box of its own, the wooden planks hang straight on the window.
local sidebar = CreateFrame("Frame", nil, frame)
sidebar:SetPoint("TOPLEFT", SIDEBAR_LEFT, -44)
sidebar:SetPoint("BOTTOMLEFT", SIDEBAR_LEFT, 14)
sidebar:SetWidth(SIDEBAR_WIDTH)

-- The pages: inside the wooden frame, on the window's background (a page with bare = true has none: its own
-- wood fills the frame, and the game shows through its gaps).
local pageArea = CreateFrame("Frame", nil, frame, "BackdropTemplate")
pageArea:SetPoint("TOPLEFT", INNER.left, -INNER.top)
pageArea:SetPoint("BOTTOMRIGHT", INNER.right - WIDTH, HEIGHT - INNER.bottom)
pageArea:SetBackdrop({ bgFile = ns.WINDOW_BACKGROUND })
pageArea:SetBackdropColor(0, 0, 0, 0.35)
ns.UI.pageArea = pageArea  -- for things that take over the whole page, like the minting show (MintReel.lua)

-- Pages -------------------------------------------------------------------------------

-- [key] = { key, label, section, order, create(parent) -> frame, refresh(frame), frame }. Pages of one
-- section appear by order.
local pages, pageOrder = {}, {}

function ns.RegisterPage(page)
    pages[page.key] = page
    pageOrder[#pageOrder + 1] = page
end

local navButtons, sidebarBuilt = {}, false
local navList = {}  -- the sidebar's buttons in their normal order
-- Under the sidebar: switches the Overview to the new one being built (OverviewCard.lua), lit while it's on.
local wipButton
-- The sidebar's page buttons (wooden, see ns.UI.SkinButton) keep the art's shape: their height follows the width.
local NAV_WIDTH = 138
local NAV_HEIGHT = math.floor(NAV_WIDTH * ns.ButtonArt.normal.height / ns.ButtonArt.normal.width + 0.5)
local NAV_FONT, NAV_FONT_SIZE = "Interface\\AddOns\\SOLC\\Media\\Fonts\\GermaniaOne-Regular.ttf", 18
local NAV_TEXT_SHARE = 0.64  -- of the button's width, between the swirls: a longer label is drawn smaller
local NAV_LABELS = { achievements = "Deeds", leaderboard = "Rankings" }  -- shorter names, in the sidebar only
local NAV_COLOR, NAV_CURRENT_COLOR = { 1, 0.93, 0.78 }, { 1, 0.82, 0 }  -- cream as in the logo; gold
local NAV_OUTLINE = { 0.18, 0.09, 0.03 }  -- dark brown, like the wood's shadows (ns.UI.OutlineText)

-- Ogre mode (/solc ogre, KillTrackerDB.ogreMode): the sidebar and the tabs in ogre words, 5 letters at most,
-- in an order that reads ME SMASH BIG LOOT, BRAG CAVE FRENZ, PIX THUNK (pages not listed come after).
local OGRE_LABELS = {
    overview = "ME", kills = "SMASH", pvp = "BONK", achievements = "BRAG", collection = "LOOT",
    home = "CAVE", members = "FRENZ", crafters = "MAKE", leaderboard = "BIG", bounties = "HUNTS",
    gallery = "PIX", puzzle = "THUNK",
}
local OGRE_ORDER = {}
for i, key in ipairs({ "overview", "kills", "leaderboard", "collection", "achievements", "home", "members",
    "gallery", "puzzle" }) do OGRE_ORDER[key] = i end
local function OgreMode() return KillTrackerDB and KillTrackerDB.ogreMode end
local function OgreLabel(page) return OgreMode() and OGRE_LABELS[page.key] end
local function NavLabel(page) return OgreLabel(page) or NAV_LABELS[page.key] or page.label end

-- Ogre words are written in crayon (Finger Paint), each letter its own size, height and crayon colour, like
-- an ogre wrote it. The wobble comes from the word itself, so it's the same every time. (No tilt: the client
-- turns neither text with SetRotation nor text in a Rotation animation.)
local OGRE_FONT = "Interface\\AddOns\\SOLC\\Media\\Fonts\\FingerPaint-Regular.ttf"
local OGRE_SIZE_JITTER = 0.2  -- each letter up to this share bigger or smaller
local OGRE_BOUNCE = 2         -- and up to this many pixels up or down
local OGRE_GAP = 2            -- pixels between letters
local OGRE_TEXT_SHARE = 0.86  -- ogre words fill this much of the plank's width, painting over the swirls
local OGRE_MAX_SCALE = 2.3    -- but grow to at most this times the normal size (ME: about 41 px tall)
-- Crayons your rank adds (Ranks.lua, "crayons" perks), in this order.
local RANK_CRAYONS = { { 0.2, 0.85, 0.8 }, { 1, 1, 0.95 }, { 1, 0.82, 0.25 }, { 0.75, 0.78, 0.85 },
    { 0.7, 1, 0.3 }, { 0.85, 0.15, 0.3 }, { 0.5, 0.85, 1 } }
local OGRE_COLORS = {  -- crayons; each letter gets one, never the one next to it
    { 1, 0.3, 0.25 }, { 1, 0.62, 0.15 }, { 1, 0.9, 0.25 }, { 0.45, 0.88, 0.3 },
    { 0.35, 0.65, 1 }, { 0.78, 0.5, 1 }, { 1, 0.55, 0.78 },
}

local function Wobble(word)  -- a random number source (-1 to 1) seeded by the word
    local seed = 7
    for i = 1, #word do seed = (seed * 31 + word:byte(i)) % 2147483647 end
    return function()
        seed = (seed * 16807) % 2147483647
        return seed / 2147483647 * 2 - 1
    end
end

-- Writes word on button in ogre letters (button.ogre holds them; the button's own text is left empty
-- meanwhile). The letters keep their colours on the current page too: its plank is lit.
local function DrawOgreWord(button, word)
    local holder = button.ogre
    if not holder then
        holder = CreateFrame("Frame", nil, button)
        holder:SetPoint("CENTER", 0, 1)
        holder:SetSize(NAV_WIDTH, NAV_HEIGHT)
        holder.letters = {}
        -- Measures letters: no box of its own, and its text is cleared first, so the width is always fresh (a
        -- letter's own width can be stale when its text didn't change, or bound by its box).
        holder.measure = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        holder.measure:Hide()
        button.ogre = holder
    end
    local random = Wobble(word)
    local total, lastColor, sizes, widths = 0, nil, {}, {}
    local measure = holder.measure
    for i = 1, #word do
        local letter = holder.letters[i]
        if not letter then
            letter = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            letter:SetShadowOffset(0, 0)
            letter:SetWordWrap(false)
            holder.letters[i] = letter
        end
        local crayons = { unpack(OGRE_COLORS) }
        for i = 1, math.min(#RANK_CRAYONS, ns.RankPerk and ns.RankPerk("crayons") or 0) do crayons[#crayons + 1] = RANK_CRAYONS[i] end
        local pick = math.floor((random() + 1) / 2 * #crayons) % #crayons + 1
        if pick == lastColor then pick = pick % #crayons + 1 end
        lastColor = pick
        letter:SetTextColor(unpack(crayons[pick]))
        sizes[i] = NAV_FONT_SIZE * (1 + random() * OGRE_SIZE_JITTER)
        if not measure:SetFont(OGRE_FONT, sizes[i], "") then measure:SetFont(NAV_FONT, sizes[i], "") end
        measure:SetText("")
        measure:SetText(word:sub(i, i))
        widths[i] = measure:GetStringWidth()
        total = total + widths[i]
    end
    -- Every letter grows (or shrinks) by the same share to fill OGRE_TEXT_SHARE of the plank, over the swirls,
    -- up to OGRE_MAX_SCALE: short words come out huge. The gaps stay.
    local gaps = (#word - 1) * OGRE_GAP
    local fit = math.min(OGRE_MAX_SCALE, (NAV_WIDTH * OGRE_TEXT_SHARE - gaps) / math.max(total, 1))
    local x = -(total * fit + gaps) / 2
    for i = 1, #word do
        local letter = holder.letters[i]
        local size = sizes[i] * fit
        if not letter:SetFont(OGRE_FONT, size, "") then letter:SetFont(NAV_FONT, size, "") end
        letter:SetText("")
        letter:SetText(word:sub(i, i))
        local advance = widths[i] * fit  -- (text width grows with the font size)
        -- A roomy box of its own: a narrow letter (I) in a box its own width could vanish.
        letter:SetSize(size * 2, size * 2)
        letter:ClearAllPoints()
        letter:SetPoint("CENTER", holder, "CENTER", x + advance / 2, random() * OGRE_BOUNCE)
        x = x + advance + OGRE_GAP
    end
    for i = #word + 1, #holder.letters do holder.letters[i]:SetText("") end
end

-- Shackles like the logo's hold each button to the one above it, a pair per gap. Media/Button/ring is cut
-- from the logo (44x72 in a 64x128 texture); the right one is the left one mirrored.
local RING_ART_W, RING_ART_H, RING_TEXTURE_W, RING_TEXTURE_H = 44, 72, 64, 128
local RING_WIDTH = math.floor(NAV_WIDTH * 0.08 + 0.5)
local RING_HEIGHT = math.floor(RING_WIDTH * RING_ART_H / RING_ART_W + 0.5)
local RING_INSET = NAV_WIDTH * 0.2  -- each ring's centre, in from the button's end (past the swirls)
local TOP_GAP = 5                   -- between the logo's sign and the top button's art box
local TOP_RING_SCALE = 1.25         -- the pair holding the top button to the logo's sign: a bit bigger
-- (The button art's own transparent edges leave the gap between buttons the rings span.)
local ringHolder = CreateFrame("Frame", nil, sidebar)  -- above the buttons' art
ringHolder:SetAllPoints()
ringHolder:SetFrameLevel(sidebar:GetFrameLevel() + 20)
local rings = {}

-- Ring i (created on first use), sized by scale and centred on button's point (+ side LEFT/RIGHT) and dy.
-- It also goes in button.rings, so it shrinks with the button when that's pushed.
local function PlaceRing(i, button, side, scale, point, dy)
    local ring = rings[i]
    if not ring then
        ring = ringHolder:CreateTexture(nil, "ARTWORK")
        ring:SetTexture("Interface\\AddOns\\SOLC\\Media\\Button\\ring")
        local u, v = RING_ART_W / RING_TEXTURE_W, RING_ART_H / RING_TEXTURE_H
        if side == 2 then ring:SetTexCoord(u, 0, 0, v) else ring:SetTexCoord(0, u, 0, v) end  -- right: mirrored
        rings[i] = ring
    end
    ring.width, ring.height = RING_WIDTH * scale, RING_HEIGHT * scale
    ring:SetSize(ring.width, ring.height)
    ring:ClearAllPoints()
    ring:SetPoint("CENTER", button, point .. (side == 1 and "LEFT" or "RIGHT"), side == 1 and RING_INSET or -RING_INSET, dy)
    table.insert(button.rings, ring)
    return ring
end

-- Places the buttons down the sidebar (in the ogre's order in ogre mode), writes their labels and hangs the
-- rings between them.
local function LayoutSidebar()
    local order = navList
    if OgreMode() then
        order = {}
        local normal = {}
        for i, button in ipairs(navList) do order[i], normal[button] = button, i end
        table.sort(order, function(a, b)
            local ra, rb = OGRE_ORDER[a.page.key] or 99, OGRE_ORDER[b.page.key] or 99
            if ra ~= rb then return ra < rb end
            return normal[a] < normal[b]
        end)
    end
    -- The top button hangs TOP_GAP below the logo's sign (the sidebar's top is 44 below the window's), from
    -- rings centred between the two, drawn behind the logo.
    local signBottom = LOGO_Y - LOGO_SIZE * LOGO_SIGN_BOTTOM
    local y = signBottom + 44 - TOP_GAP
    for _, button in ipairs(navList) do button.rings = {} end
    for i, button in ipairs(order) do
        button:SetPoint("TOPLEFT", (SIDEBAR_WIDTH - NAV_WIDTH) / 2, y)  -- centred
        if i == 1 then
            for side = 1, 2 do PlaceRing(side, button, side, TOP_RING_SCALE, "TOP", TOP_GAP / 2) end
        else
            for side = 1, 2 do
                table.insert(order[i - 1].rings, PlaceRing(i * 2 - 2 + side, button, side, 1, "TOP", 0))
            end
        end
        local label = NavLabel(button.page)
        button.text:SetText(OgreMode() and "" or label)
        if OgreMode() then
            DrawOgreWord(button, label)
        else
            local size = NAV_FONT_SIZE
            if button.text:SetFont(NAV_FONT, size, "") then
                while size > 10 and button.text:GetStringWidth() > NAV_WIDTH * NAV_TEXT_SHARE do
                    size = size - 1
                    button.text:SetFont(NAV_FONT, size, "")
                end
            end
        end
        if button.ogre then button.ogre:SetShown(OgreMode()) end
        y = y - NAV_HEIGHT
    end
    if wipButton and order[#order] then
        wipButton:ClearAllPoints()
        wipButton:SetPoint("TOP", order[#order], "BOTTOM", 0, -2)
    end
end

-- A pushed sidebar button's art shrinks; its rings, above and below, and its ogre letters shrink with it in
-- place, so nothing else moves.
local function ScaleRings(button, look, scale)
    if look ~= "pushed" then scale = 1 end
    for _, ring in ipairs(button.rings or {}) do ring:SetSize(ring.width * scale, ring.height * scale) end
    if button.ogre then
        button.ogre:SetScale(scale)
        button.ogre:SetPoint("CENTER", look == "pushed" and 1 or 0, look == "pushed" and -1 or 1)  -- dips, like the text
    end
end

-- Lays the sidebar out now and again a moment later: a font's first use (the crayon font, the first time ogre
-- mode is on) measures wrong until the game has loaded it, so the words would only fit after the next redraw.
local function LayoutSidebarSoon()
    LayoutSidebar()
    C_Timer.After(0.1, LayoutSidebar)
end

function ns.UI.SetOgreMode(on)
    KillTrackerDB.ogreMode = on or nil
    if not sidebarBuilt then return end
    LayoutSidebarSoon()  -- writes and fits the new words
    if ns.OnKillsChanged then ns.OnKillsChanged() end  -- redraws the tabs
end

local lastTab = {}  -- [page key] = the tab last shown in that page's group, which its sidebar button reopens

local function BuildSidebar()
    if sidebarBuilt then return end
    sidebarBuilt = true
    for _, section in ipairs(SECTIONS) do
        local inSection = {}
        for _, page in ipairs(pageOrder) do
            if page.section == section.key and not page.tabOf then inSection[#inSection + 1] = page end
        end
        table.sort(inSection, function(a, b) return (a.order or 99) < (b.order or 99) end)
        for _, page in ipairs(inSection) do
            local button = CreateFrame("Button", nil, sidebar)
            button:SetSize(NAV_WIDTH, NAV_HEIGHT)
            button.page = page
            button.text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            button.text:SetPoint("CENTER", 0, 1)
            if not button.text:SetFont(NAV_FONT, NAV_FONT_SIZE, "") then  -- else the default stays
                button.text:SetFontObject("GameFontHighlight")
            end
            ns.UI.OutlineText(button.text, NAV_OUTLINE)
            button:SetScript("OnClick", function() ns.OpenPage(lastTab[page.key] or page.key) end)
            -- Wooden; the current page is selected (Refresh).
            ns.UI.SkinButton(button, { dimUnselected = true, steady = true, onRedraw = ScaleRings })
            navButtons[page.key] = button
            navList[#navList + 1] = button
        end
    end
    if pages.wipOverview then
        wipButton = CreateFrame("Button", nil, sidebar)
        wipButton:SetSize(math.floor(NAV_WIDTH * 0.55), math.floor(NAV_HEIGHT * 0.55))
        wipButton.text = wipButton:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        wipButton.text:SetPoint("CENTER", 0, 1)
        if not wipButton.text:SetFont(NAV_FONT, 13, "") then wipButton.text:SetFontObject("GameFontHighlightSmall") end
        ns.UI.OutlineText(wipButton.text, NAV_OUTLINE)
        wipButton.text:SetText("WIP")
        wipButton:SetScript("OnClick", function()
            KillTrackerDB.wipOverview = not KillTrackerDB.wipOverview or nil
            ns.OpenPage("overview")
        end)
        wipButton:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Work in progress")
            GameTooltip:AddLine("Shows the new Overview being built instead of the current one.", 1, 1, 1, true)
            GameTooltip:Show()
        end)
        wipButton:SetScript("OnLeave", GameTooltip_Hide)
        ns.UI.SkinButton(wipButton, { dimUnselected = true, steady = true })
    end
    LayoutSidebarSoon()
end

-- Tabs under the window, Blizzard style, for a page and the pages that are its tabs (tabOf).
local tabs = {}
local function ShowTabs(current)
    local groupKey = current.tabOf or current.key
    local group = {}
    for _, page in ipairs(pageOrder) do
        if page.key == groupKey or page.tabOf == groupKey then group[#group + 1] = page end
    end
    table.sort(group, function(a, b)  -- the page itself first, then its tabs by order
        if (a.key == groupKey) ~= (b.key == groupKey) then return a.key == groupKey end
        return (a.order or 99) < (b.order or 99)
    end)
    if #group < 2 then group = {} end
    for i, page in ipairs(group) do
        local tab = tabs[i]
        if not tab then
            tab = CreateFrame("Button", nil, frame, "PanelTabButtonTemplate")
            if i == 1 then
                tab:SetPoint("TOPLEFT", pageArea, "BOTTOMLEFT", 6, -26)  -- below the frame's bottom planks
            else
                tab:SetPoint("LEFT", tabs[i - 1], "RIGHT", 4, 0)  -- (the beta's tabs have no see-through edges to overlap)
            end
            tabs[i] = tab
        end
        tab:SetText(OgreLabel(page) or page.label)
        tab:SetScript("OnClick", function() ns.OpenPage(page.key) end)
        if PanelTemplates_TabResize then PanelTemplates_TabResize(tab, 0) end
        if page == current then
            if PanelTemplates_SelectTab then PanelTemplates_SelectTab(tab) end
        elseif PanelTemplates_DeselectTab then
            PanelTemplates_DeselectTab(tab)
        end
        tab:Show()
    end
    for i = #group + 1, #tabs do tabs[i]:Hide() end
    if #group > 0 then lastTab[groupKey] = current.key end
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

-- A list row: highlight, a bar behind it, a label on the left and a count on the right. width: default
-- the full list width.
function ns.UI.CreateRow(content, i, width)
    width = width or LIST_WIDTH
    local row = CreateFrame("Button", nil, content)
    row:SetSize(width, ROW_HEIGHT)
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
    row.SetBar = function(self, fraction) self.bar:SetWidth(math.max(1, width * math.min(1, fraction))) end
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

-- The wooden button skin (Media/Button/<state>.blp and their sizes in ButtonArt.lua, from
-- tools/convert-buttons.js): ns.UI.SkinButton(button) dresses a standard button in it. The art is drawn in
-- three pieces so it can be any width: the two ends (with the swirls and bolts) keep their shape, the plain
-- wood between them stretches. States: normal, hover, pushed, and selected while the button is "locked"
-- (button:LockHighlight(), as for chosen options). A state whose art is bigger or smaller than normal is
-- drawn that much bigger or smaller, centred: the button swells on hover and dips when pressed.
local BUTTON_FOLDER = "Interface\\AddOns\\SOLC\\Media\\Button\\"
local CAP_SHARE = 44 / 234  -- each end that keeps its shape, as a share of the art's width

-- options.dimUnselected: draw the button darker unless it's selected, hovered or pressed (the sidebar, so
-- the current page is the only fully lit plank). options.onRedraw(button, look, scale): after each redraw,
-- with the state shown and its art's height relative to normal (the sidebar's rings follow it).
local DIMMED = 0.55

function ns.UI.SkinButton(button, options)
    -- Hide the template's own art (its textures stay but draw nothing; the template may re-set them).
    for _, region in ipairs({ button:GetRegions() }) do
        if region:IsObjectType("Texture") then region:SetAlpha(0) end
    end
    -- The art sits on a plate centred on the button, sized per state.
    local plate = CreateFrame("Frame", nil, button)
    plate:SetPoint("CENTER")
    plate:SetFrameLevel(math.max(0, button:GetFrameLevel() - 1))  -- under the button's own text
    local pieces = {}
    for i = 1, 3 do pieces[i] = plate:CreateTexture(nil, "BACKGROUND", nil, 1) end
    local left, middle, right = pieces[1], pieces[2], pieces[3]
    left:SetPoint("TOPLEFT")
    left:SetPoint("BOTTOMLEFT")
    right:SetPoint("TOPRIGHT")
    right:SetPoint("BOTTOMRIGHT")
    middle:SetPoint("TOPLEFT", left, "TOPRIGHT")
    middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")

    local hovered, pressed, selected = false, false, false
    local unpressedFont  -- { file, size, flags } while the text is drawn at the pushed size
    local function Redraw()
        local look = pressed and "pushed" or hovered and "hover" or selected and "selected" or "normal"
        -- options.steady (the sidebar): the same plank in every state, only lit (hover, press, selected) or dimmed,
        -- shrinking a little while pressed, like the window's Settings and Close buttons; the selected art (yellow
        -- runes) while selected. Otherwise each state has its own art (hover swells, pushed dips).
        local steady = options and options.steady
        local artLook = steady and (selected and "selected" or "normal") or look
        local art, base = ns.ButtonArt[artLook], ns.ButtonArt.normal
        -- This state's size relative to normal, applied to the button's size.
        local press = steady and pressed and ns.ButtonArt.pushed.width / base.width or 1
        local scaleX, scaleY = art.width / base.width * press, art.height / base.height * press
        local width, height = button:GetWidth() * scaleX, button:GetHeight() * scaleY
        plate:SetSize(width, height)
        local capArt = art.width * CAP_SHARE
        local cap = capArt * height / art.height
        left:SetWidth(cap)
        right:SetWidth(cap)
        local u, v = art.width / art.textureWidth, art.height / art.textureHeight
        local capU = capArt / art.textureWidth
        local file = BUTTON_FOLDER .. artLook
        local coords = { { 0, capU }, { capU, u - capU }, { u - capU, u } }
        local lit = hovered or pressed or selected
        local shade = options and options.dimUnselected and not lit and DIMMED or 1
        for i, t in ipairs(pieces) do
            t:SetTexture(file)
            t:SetTexCoord(coords[i][1], coords[i][2], 0, v)
            t:SetDesaturated(not button:IsEnabled())
            t:SetVertexColor(shade, shade, shade)
        end
        -- How much the press shrinks it (steady: the press alone, not the bigger selected art).
        local pushScale = steady and press or scaleY
        if options and options.onRedraw then options.onRedraw(button, look, pushScale) end
        -- The text shrinks or grows with the art while pressed (its font as it was is put back on release).
        local text = button.text or button:GetFontString()
        if text and steady then
            text:SetPoint("CENTER", pressed and 1 or 0, pressed and -1 or 1)  -- dips while pressed, like the icons
        end
        if text then
            if look == "pushed" and pushScale ~= 1 and not unpressedFont then
                unpressedFont = { text:GetFont() }
                if unpressedFont[1] then
                    text:SetFont(unpressedFont[1], unpressedFont[2] * pushScale, unpressedFont[3])
                end
            elseif look ~= "pushed" and unpressedFont then
                if unpressedFont[1] then text:SetFont(unpack(unpressedFont)) end
                unpressedFont = nil
            end
        end
    end
    button:HookScript("OnEnter", function() hovered = true Redraw() end)
    button:HookScript("OnLeave", function() hovered, pressed = false, false Redraw() end)
    button:HookScript("OnMouseDown", function() if button:IsEnabled() then pressed = true Redraw() end end)
    button:HookScript("OnMouseUp", function() pressed = false Redraw() end)
    button:HookScript("OnClick", function() ns.UI.ClickSound() end)
    button:HookScript("OnEnable", Redraw)
    button:HookScript("OnDisable", Redraw)
    button:HookScript("OnSizeChanged", Redraw)
    hooksecurefunc(button, "LockHighlight", function() selected = true Redraw() end)
    hooksecurefunc(button, "UnlockHighlight", function() selected = false Redraw() end)
    Redraw()
end

-- A coloured outline for a font string (WoW's own OUTLINE is always black): copies of the text in that colour,
-- shifted a pixel each way, drawn behind it, each over the text's whole box with its alignment and wrapping (so a
-- left-aligned or cut-short text gets an outline that fits). They follow the text's SetText and SetFont (the
-- pushed shrink); colour codes in the text are left out of them, or the copies would show those colours.
local LAYER_BELOW = { BORDER = "BACKGROUND", ARTWORK = "BORDER", OVERLAY = "ARTWORK", HIGHLIGHT = "OVERLAY" }
local OUTLINE_OFFSETS = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 }, { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } }
function ns.UI.OutlineText(text, color)
    text:SetShadowOffset(0, 0)
    local layer = LAYER_BELOW[text:GetDrawLayer()] or "BACKGROUND"  -- a whole layer down: sublevels didn't keep them behind
    local copies = {}
    for i, offset in ipairs(OUTLINE_OFFSETS) do
        local copy = text:GetParent():CreateFontString(nil, layer)
        copy:SetPoint("TOPLEFT", text, "TOPLEFT", offset[1], offset[2])
        copy:SetPoint("BOTTOMRIGHT", text, "BOTTOMRIGHT", offset[1], offset[2])
        copy:SetTextColor(color[1], color[2], color[3], color[4] or 1)
        copy:SetShadowOffset(0, 0)
        copies[i] = copy
    end
    local function Sync()
        local file, size, flags = text:GetFont()
        if not file then return end  -- no font yet: nothing the copies could draw
        local plain = (text:GetText() or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        for _, copy in ipairs(copies) do
            copy:SetFont(file, size, flags)
            copy:SetJustifyH(text:GetJustifyH())
            copy:SetJustifyV(text:GetJustifyV())
            copy:SetWordWrap(text:CanWordWrap())
            copy:SetText(plain)
        end
    end
    hooksecurefunc(text, "SetText", Sync)
    hooksecurefunc(text, "SetFont", Sync)
    hooksecurefunc(text, "SetFontObject", Sync)
    Sync()
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

-- Viewing: you, the combined stats, or a synced guildmate - the arrows step through them. Pages
-- without combined stats (Overview) step through you and guildmates only.
local viewingLabel = list:CreateFontString(nil, "OVERLAY", "GameFontNormal")
local function StepViewing(delta, withCombined)
    local keys = { false }  -- false = you
    if withCombined then keys[2] = COMBINED end
    for _, friend in ipairs(ns.GetFriends()) do keys[#keys + 1] = friend.key end
    local index = 1
    for i, key in ipairs(keys) do
        if key == (state.viewing or false) then index = i end
    end
    state.viewing = keys[(index - 1 + delta) % #keys + 1] or nil
    state.path = {}
    Refresh()
end
ns.UI.StepViewing = StepViewing  -- (delta): the next or previous of you and the synced guildmates
local function CreateArrow(parent, direction, texture, withCombined)
    local arrow = CreateFrame("Button", nil, parent)
    arrow:SetSize(ARROW_SIZE, ARROW_SIZE)
    arrow:SetNormalTexture(texture .. "-Up")
    arrow:SetPushedTexture(texture .. "-Down")
    arrow:SetDisabledTexture(texture .. "-Disabled")
    arrow:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    arrow:SetScript("OnClick", function() StepViewing(direction, withCombined) end)
    arrow:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Whose stats")
        GameTooltip:AddLine(withCombined and "Step through yours, everyone's combined, and each synced guildmate's."
            or "Step through yours and each synced guildmate's.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    arrow:SetScript("OnLeave", GameTooltip_Hide)
    return arrow
end
local nextArrow = CreateArrow(list, 1, "Interface\\Buttons\\UI-SpellbookIcon-NextPage", true)
nextArrow:SetPoint("TOPRIGHT", -10, -7)
viewingLabel:SetPoint("RIGHT", nextArrow, "LEFT", -2, 0)
viewingLabel:SetWidth(VIEWING_WIDTH)
viewingLabel:SetWordWrap(false)
local prevArrow = CreateArrow(list, -1, "Interface\\Buttons\\UI-SpellbookIcon-PrevPage", true)
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
    AddValue((progress.unit or "kills"):gsub("^%l", string.upper), progress.kills)
    GameTooltip:AddLine(" ")
    for _, tier in ipairs(progress.tiers) do
        if tier.earned then
            GameTooltip:AddDoubleLine(tier.name, tier.time and date("%Y-%m-%d", tier.time) or "Earned", 0.2, 1, 0.2, 0.2, 1, 0.2)
        else
            GameTooltip:AddDoubleLine(tier.name, ("%d %s"):format(tier.kills, progress.unit or "kills"), 0.6, 0.6, 0.6, 0.6, 0.6, 0.6)
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
        elseif self.data.extra then
            if self.data.extra.onClick then self.data.extra.onClick() end
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
        elseif self.data.extra then
            if self.data.extra.onEnter then self.data.extra.onEnter(self) end
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
        elseif self.data.rare then
            local rare = self.data.rare
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(rare.name)
            GameTooltip:AddLine(rare.elite and "Rare elite" or "Rare", 0.75, 0.75, 0.85)
            AddValue("Level", rare.level)
            AddValue("Zone", rare.zone)
            AddValue("Creature", rare.c.subtype)
            if rare.c.faction ~= rare.c.subtype then AddValue("Faction", rare.c.faction) end
            AddValue("Kills", rare.kills > 0 and rare.kills or "Not found yet")
            GameTooltip:AddLine(ns.WOWHEAD_NPC_URL:format(rare.npcID), 0.6, 0.6, 0.6)
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

-- Whose page a page without combined stats shows: nil for you, or a key in KillTrackerFriends.
function ns.GetViewing()
    if state.viewing == COMBINED or (state.viewing and not KillTrackerFriends[state.viewing]) then return nil end
    return state.viewing
end

-- Arrows and a name at the top right of a page, stepping through you and each synced guildmate.
-- Call switcher:Update() when the page refreshes.
function ns.UI.CreateViewSwitcher(parent)
    local nextButton = CreateArrow(parent, 1, "Interface\\Buttons\\UI-SpellbookIcon-NextPage")
    nextButton:SetPoint("TOPRIGHT", -10, -7)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("RIGHT", nextButton, "LEFT", -2, 0)
    label:SetWidth(VIEWING_WIDTH)
    label:SetWordWrap(false)
    local prevButton = CreateArrow(parent, -1, "Interface\\Buttons\\UI-SpellbookIcon-PrevPage")
    prevButton:SetPoint("RIGHT", label, "LEFT", -2, 0)
    local switcher = {}
    function switcher:Update()
        local hasFriends = next(KillTrackerFriends) ~= nil
        prevButton:SetShown(hasFriends)
        nextButton:SetShown(hasFriends)
        local key = ns.GetViewing()
        label:SetText(not hasFriends and "" or key and ("|cff66ccff%s|r"):format(Ambiguate(key, "short")) or ns.MyName())
    end
    return switcher
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
        if not d.leader and not d.rare then total = total + d.count end  -- leaders and rares listed from elsewhere don't add up
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
        elseif d.extra then
            row.count:SetText(d.extra.right or "")
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
        elseif d.rare then
            local killed = d.rare.kills > 0
            row.label:SetText((killed and RARE_STAR or RARE_STAR_GREY) .. " " .. (killed and d.label or "|cff888888" .. d.label .. "|r")
                .. ("  |cff999999%d%s|r"):format(d.rare.level, d.rare.elite and " elite" or ""))
            row.count:SetText(killed and d.rare.kills or "|cff888888not found|r")
            barFraction = 0
        elseif d.rareZone then
            row.label:SetText(d.count == d.rareAll and (d.label .. "  " .. RARE_STAR) or d.label)
            row.count:SetText(("%d/%d"):format(d.count, d.rareAll))
            barFraction = d.count / d.rareAll
            row.bar:SetVertexColor(0.85, 0.85, 0.9, 0.35)
        elseif d.leader then
            local killed = d.leader.kills > 0
            row.label:SetText((killed and CROWN or CROWN_GREY) .. " " .. (killed and d.label or "|cff888888" .. d.label .. "|r"))
            row.count:SetText(killed and d.count or "|cff888888not killed|r")
        elseif d.category then
            local label = d.note and ("%s  |cff999999%s|r"):format(d.label, d.note) or d.label
            if d.leaders then label = label .. "  " .. LeaderCrown(d.leaders) end
            row.label:SetText(d.rares and label .. "  " .. d.rares or label)
            row.count:SetText(("%d  |cff999999%d%%|r"):format(d.count, total > 0 and math.floor(d.count / total * 100 + 0.5) or 0))
        else
            if d.leading then row.label:SetText(CROWN .. " " .. d.label)
            elseif d.rareMob then row.label:SetText(RARE_STAR .. " " .. d.label) end
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
local function ListPage(key, label, order, view, tabOf)
    ns.RegisterPage({
        key = key, label = label, section = "me", order = order, tabOf = tabOf,
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
viewer:SetSize(290, 492)  -- the picture, seven trait rows, two buttons
viewer:SetPoint("TOPLEFT", frame, "TOPRIGHT", -6, 0)
viewer:SetBackdrop(DIALOG_BACKDROP)
viewer:SetBackdropColor(unpack(ns.WINDOW_COLOR))
viewer:EnableMouse(true)
viewer:Hide()

viewer.title = viewer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
viewer.title:SetPoint("TOP", 0, -18)
viewer.rarity = viewer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
viewer.rarity:SetPoint("TOP", viewer.title, "BOTTOM", 0, -4)
viewer.canvas = CreateFrame("Frame", nil, viewer)
viewer.canvas:SetSize(256, 256)
viewer.canvas:SetPoint("TOP", 0, -56)
-- The traits, one row per layer; on your own pictures with the crayon edition, click one to draw it in crayon.
viewer.traitRows = {}
for i = 1, 7 do
    local row = CreateFrame("Button", nil, viewer)
    row:SetSize(256, 14)
    row:SetPoint("TOPLEFT", viewer.canvas, "BOTTOMLEFT", 0, -6 - (i - 1) * 14)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("LEFT")
    row.mark = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.mark:SetPoint("RIGHT")
    row:SetScript("OnClick", function(self)
        if not self.editable then return end
        ns.SetLayerEdition(viewer.mint, self.layer, ns.NextEdition(ns.LayerEdition(ns.MintStyle(viewer.mint), self.layer)))
        ns.ShowMint(viewer.mint, nil)
    end)
    row:SetScript("OnEnter", function(self)
        if not self.editable then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Click to draw this one painted, in crayon or sketched, in turn", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)
    viewer.traitRows[i] = row
end
local viewerClose = CreateFrame("Button", nil, viewer, "UIPanelCloseButton")
viewerClose:SetPoint("TOPRIGHT", -6, -6)
-- Your own pictures: put on / take off your Overview's showcase (Minting.lua).
viewer.showcase = CreateFrame("Button", nil, viewer, "UIPanelButtonTemplate")
viewer.showcase:SetSize(180, 22)
viewer.showcase:SetPoint("BOTTOM", 0, 16)
local function UpdateShowcaseButton()
    viewer.showcase:SetText(ns.IsShowcased(viewer.mint.number) and "Take off your Overview" or "Show on your Overview")
end
viewer.showcase:SetScript("OnClick", function()
    local ok, reason = ns.ToggleShowcase(viewer.mint)
    if not ok then ns.Print(reason) end
    UpdateShowcaseButton()
end)
-- Your own pictures with the crayon edition unlocked (Minting.lua): switch it between painted and crayon.
viewer.style = CreateFrame("Button", nil, viewer, "UIPanelButtonTemplate")
viewer.style:SetSize(180, 22)
viewer.style:SetPoint("BOTTOM", viewer.showcase, "TOP", 0, 4)
local function UpdateStyleButton()
    local style = ns.MintStyle(viewer.mint)
    local nextStyle = type(style) == "table" and ns.EDITIONS[1] or ns.NextEdition(style)
    viewer.style:SetText(nextStyle and ("Show it all in %s"):format(ns.EDITION_NAMES[nextStyle]) or "Show it all painted")
end
viewer.style:SetScript("OnClick", function()
    local style = ns.MintStyle(viewer.mint)
    ns.SetMintStyle(viewer.mint, type(style) == "table" and ns.EDITIONS[1] or ns.NextEdition(style))
    ns.ShowMint(viewer.mint, nil)
end)
viewer.style:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Crayon and sketch editions")
    GameTooltip:AddLine("Your picture redrawn in crayon or sketched. Click a trait to switch just that one. Guildmates see it the way you pick.", 1, 1, 1, true)
    GameTooltip:Show()
end)
viewer.style:SetScript("OnLeave", GameTooltip_Hide)

-- Shows a picture next to the window. owner: whose it is, if not yours.
function ns.ShowMint(mint, owner)
    viewer.mint = mint
    viewer.showcase:SetShown(owner == nil)
    if owner == nil then UpdateShowcaseButton() end
    viewer.style:SetShown(owner == nil and ns.CrayonUnlocked(mint))
    if owner == nil then UpdateStyleButton() end
    local rarity = ns.MintRarity(mint.traits)
    viewer.title:SetText(owner and ("%s's #%d"):format(owner, mint.number) or ("Picture #%d"):format(mint.number))
    viewer.rarity:SetText(("|c%s%s|r"):format(ns.RARITY_COLORS[rarity], (rarity:gsub("^%l", string.upper))))
    ns.RenderMint(viewer.canvas, mint.traits, nil, ns.MintStyle(mint))
    local traits, style = ns.MintTraits(mint.traits), ns.MintStyle(mint)
    local editable = owner == nil and ns.CrayonUnlocked(mint)
    for i, row in ipairs(viewer.traitRows) do
        local trait = traits[i]
        row:SetShown(trait ~= nil)
        if trait then
            row.layer, row.editable = trait[4], editable
            row:EnableMouse(editable)
            row.text:SetText(("|cffffd100%s:|r |c%s%s|r"):format(trait[1], ns.RARITY_COLORS[trait[3]], trait[2]))
            local edition = ns.LayerEdition(style, trait[4])
            row.mark:SetText(edition and ("|cffff9a2a%s|r"):format(ns.EDITION_NAMES[edition]) or "")
        end
    end
    if not frame:IsShown() then ns.ToggleUI() end
    viewer:Show()
end

-- Refresh -------------------------------------------------------------------

function Refresh()
    BuildSidebar()
    local current = pages[state.page] or pages.overview
    state.page = current.key
    local navKey = current.tabOf or current.key  -- a tab lights its page's button
    -- The new Overview being built (OverviewCard.lua) stands in for the Overview while the WIP button is on.
    if current.key == "overview" and KillTrackerDB.wipOverview and pages.wipOverview then current = pages.wipOverview end
    if wipButton then
        if KillTrackerDB.wipOverview then wipButton:LockHighlight() else wipButton:UnlockHighlight() end
    end
    body:SetShown(not current.bare)
    pageArea:SetBackdropColor(0, 0, 0, current.bare and 0 or 0.35)
    for key, page in pairs(pages) do
        if key ~= current.key and page.frame and page.frame ~= (current.frame or false) then page.frame:Hide() end
        if navButtons[key] then
            if key == navKey then navButtons[key]:LockHighlight() else navButtons[key]:UnlockHighlight() end
            navButtons[key].text:SetTextColor(unpack(key == navKey and NAV_CURRENT_COLOR or NAV_COLOR))
        end
    end
    ShowTabs(current)
    if settingsButton then settingsButton:SetSelected(current.key == "settings") end
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

-- Kills and guildmates' updates can come several per second (AoE pulls, a busy guild), and a refresh
-- rebuilds the whole page, so changes within a moment share one refresh.
local refreshPending
function ns.OnKillsChanged()
    if not frame:IsShown() or refreshPending then return end
    refreshPending = true
    C_Timer.After(0.25, function()
        refreshPending = nil
        if frame:IsShown() then Refresh() end
    end)
end
ns.OnFriendsChanged = ns.OnKillsChanged

ListPage("kills", "Kills", 2)
ListPage("pvp", "PvP", 3, "pvp", "kills")
ListPage("rares", "Rares", 6, "rares", "kills")
ListPage("achievements", "Achievements", 4, "achievements")
ListPage("collection", "Collection", 5, "collection")
