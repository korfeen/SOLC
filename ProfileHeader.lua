-- The profile header and the split layout (UI.lua shows them for a page registered with split = true).
-- The header sits top-left, over the left page: whoever you're viewing (you or a synced guildmate, ns.GetViewing):
-- their Ogre Rank badge with the bar to the next rank, their name and title, icons for their race, class and
-- professions, and a strip with their points, kills and achievements. Arrows beside the name step through you and
-- your synced guildmates; clicking the name lists them. Clicking the badge shows the rank and its perks over the
-- left slot.
-- A split page fills two slots (ns.UI.SPLIT, window pixels): left, under the header, and right, the whole right page;
-- the middle beam between them is drawn here too. A page's backgrounds can run on under the beams (SPLIT.under).
-- Also shared with the pages: ns.UI.Profile(key), ns.UI.FitText, ns.UI.Tooltip, ns.UI.BadgeArt, ns.UI.CreateIcon.

local _, ns = ...
local UI = ns.UI

local NAME_FONT = "Interface\\AddOns\\SOLC\\Media\\Fonts\\GermaniaOne-Regular.ttf"
local ICONS = "Interface\\AddOns\\SOLC\\Media\\Overview\\Icons\\"
local MEDIA_ICONS = "Interface\\AddOns\\SOLC\\Media\\Icons\\"
local ARROW_ART = "Interface\\AddOns\\SOLC\\Media\\Overview\\Arrow"
local EMPTY_SHAPE = 0.45                     -- an empty icon shape (nothing known yet) is drawn this faint
local TEXT_OUTLINE = { 0.12, 0.07, 0.03 }    -- dark brown round the light text on the boards (ns.UI.OutlineText)
local TITLE_COLOR = { 0.94, 0.69, 0.38 }
local BAR_COLOR, BAR_TRACK = { 1, 0.85, 0.01 }, { 0.16, 0.12, 0.11 }
local PANEL_TEXT = { 0.93, 0.88, 0.78 }
local ARROW_DIM = { 0.75, 0.7, 0.62 }
local RANK_LINES = 18                        -- perk lines in the rank panel
-- A title earned (to come): nothing earns one yet, so everyone wears this test one.
local TEST_TITLE = "the Big Napper"

-- The slots of a split page, and the header, in window pixels (from its top-left, y down; centres unless said).
local SPLIT = {
    left = { left = 237, right = 627, top = 285, bottom = 730 },   -- under the header, to the middle beam
    right = { left = 674, right = 1064, top = 146, bottom = 730 }, -- the right page, from the middle beam
    under = { left = 217, middle = 650, right = 1084, top = 130, bottom = 750 },  -- where backgrounds can run to
}
UI.SPLIT = SPLIT
local HEADER = {
    top = 146, bottom = 250, color = { 0.25, 0.2, 0.2 },
    -- The background they picked for the board (edit mode), darkened by dim; zoomed in up to maxZoom.
    backdrop = { dim = 0.45, maxZoom = 3 },
    edit = { x = 619, y = 166, size = 14 },  -- the edit button (your own header): a pencil in the top-right corner
    strip = { top = 250, bottom = 285, shade = { 365, 502, 0.35 } },  -- a cross beam; its middle (the kills) darker
    badge = { x = 282, y = 196, size = 92 },  -- the Ogre Rank badge (Media/Icons/Rank_*)
    -- The rank's progress: from behind the badge to near the professions; its numbers centred on what shows.
    bar = { left = 282, right = 458, top = 220, bottom = 240, shown = 328 },
    name = { x = 332, y = 174, size = 22, right = 488 },  -- right: where the arrows start
    arrows = { x = 498, gap = 18, size = 16 },
    title = { x = 325, y = 203, size = 18 },
    icons = {  -- centre, size
        race = { 546, 188, 40 }, class = { 592, 185, 48 },
        professions = { { 480, 228, 34 }, { 515, 228, 34 } },
        secondary = { { 549, 229, 28 }, { 579, 229, 28 }, { 610, 229, 28 } },
    },
    stats = {  -- the icon's centre and size, where the number starts
        { icon = "Points", x = 270, y = 267, size = 34, text = 290 },
        { icon = "Kills", x = 395, y = 267, size = 30, text = 418 },
        { icon = "Achievements", x = 529, y = 265, size = 36, text = 549 },
    },
    statY = 268, statSize = 18, statWidth = 70,
}

local issecret = issecretvalue or function() return false end
local function Readable(value) if not issecret(value) then return value end end
local function IconKey(text) return text and (text:upper():gsub("[^A-Z]", "")) end

-- Icons there's art for (Media/Overview/Icons/<kind>_<key>).
local RACES = { HUMAN = true, DWARF = true, NIGHTELF = true, GNOME = true, SKYBORNE = true }
local CLASSES = { DRUID = true, HUNTER = true, MAGE = true, PALADIN = true, PRIEST = true, ROGUE = true, SHAMAN = true,
    WARLOCK = true, WARRIOR = true }
local PROFESSIONS = { [171] = "ALCHEMY", [164] = "BLACKSMITHING", [333] = "ENCHANTING", [202] = "ENGINEERING",
    [182] = "HERBALISM", [165] = "LEATHERWORKING", [186] = "MINING", [393] = "SKINNING", [197] = "TAILORING" }
local SECONDARY = { { line = 185, key = "COOKING" }, { line = 356, key = "FISHING" }, { line = 129, key = "FIRSTAID" } }
-- A profession's art key (its icon's, Media/Overview/Icons/Prof_<key>; its background's, Media/Overview/Professions)
-- by its skill line, or nil.
function UI.ProfessionKey(line)
    if PROFESSIONS[line] then return PROFESSIONS[line] end
    for _, s in ipairs(SECONDARY) do
        if s.line == line then return s.key end
    end
end
local GENDERS = { MALE = "Male", FEMALE = "Female", NONBINARY = "Nonbinary" }
local SEX_GENDER = { [2] = "MALE", [3] = "FEMALE" }  -- UnitSex

-- Who someone is: you (key nil) or a synced guildmate. { key, name, raceName, raceFile, race (icon key), classFile,
-- className, sex, level, gender, portrait (a picture number, for the Overview's photo), professions (the main ones,
-- highest skill first: { icon, prof }), secondary ([icon key] = prof) }.
function UI.Profile(key)
    local p = { key = key }
    if key then
        local friend = KillTrackerFriends[key]
        local gear = friend and friend.gear
        p.name = key
        if gear then
            local info = gear.race and gear.race > 0 and C_CreatureInfo and C_CreatureInfo.GetRaceInfo(gear.race)
            if info then p.raceName, p.raceFile = info.raceName, info.clientFileString end
            p.classFile, p.sex, p.level = gear.class, gear.sex, gear.level
        end
        p.chosenGender = friend and friend.card and friend.card.gender
        p.portrait = friend and friend.card and friend.card.portrait
    else
        p.name = ns.MyName()
        p.raceName, p.raceFile = Readable(UnitRace("player")), Readable(select(2, UnitRace("player")))
        p.classFile = Readable(select(2, UnitClass("player")))
        p.sex, p.level = Readable(UnitSex("player")), Readable(UnitLevel("player"))
        p.chosenGender = KillTrackerDB.card and KillTrackerDB.card.gender
        p.portrait = KillTrackerDB.card and KillTrackerDB.card.portrait
    end
    p.gender = GENDERS[p.chosenGender or ""] and p.chosenGender or SEX_GENDER[p.sex]
    p.race = RACES[IconKey(p.raceFile) or ""] and IconKey(p.raceFile) or RACES[IconKey(p.raceName) or ""] and IconKey(p.raceName)
    p.className = p.classFile and LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[p.classFile] or p.classFile
    p.professions, p.secondary = {}, {}
    for _, prof in ipairs(ns.GetProfessions(key).list) do
        local icon = PROFESSIONS[prof.line]
        if icon then
            p.professions[#p.professions + 1] = { icon = icon, prof = prof }
        else
            for _, s in ipairs(SECONDARY) do
                if s.line == prof.line then p.secondary[s.key] = prof end
            end
        end
    end
    table.sort(p.professions, function(a, b) return (a.prof.rank or 0) > (b.prof.rank or 0) end)
    return p
end

-- Writes text as big as fits in width (from size down to smallest). The text is cleared first: a font string
-- whose text didn't change can report the width it had in an earlier font.
function UI.FitText(fontString, font, size, smallest, text, width)
    fontString:SetFont(font, size, "")
    fontString:SetText("")
    fontString:SetText(text)
    while size > smallest and fontString:GetStringWidth() > width do
        size = size - 1
        fontString:SetFont(font, size, "")
    end
end
local Fit = UI.FitText

-- A tooltip: the first line white, the rest grey.
function UI.Tooltip(owner, lines)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    for i, line in ipairs(lines) do
        if i == 1 then GameTooltip:AddLine(line) else GameTooltip:AddLine(line, 0.6, 0.6, 0.6, true) end
    end
    GameTooltip:Show()
end
local Tooltip = UI.Tooltip

-- The Ogre Rank badge art: one per five ranks (Media/Icons/Rank_1..7, tools/make-role-icons.js).
function UI.BadgeArt(rank) return MEDIA_ICONS .. "Rank_" .. (rank >= 30 and 7 or math.floor(rank / 5) + 1) end

-- An icon at a spot ({ x, y (centre), size }, from anchor's top-left; the window's by default):
-- icon:Set(texture name or nil, empty shape, tooltip lines).
function UI.CreateIcon(parent, spot, anchor)
    local icon = CreateFrame("Button", nil, parent)
    icon:SetSize(spot.size, spot.size)
    icon:SetPoint("CENTER", anchor or UI.window, "TOPLEFT", spot.x, -spot.y)
    icon:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    icon.texture = icon:CreateTexture(nil, "ARTWORK")
    icon.texture:SetAllPoints()
    function icon:Set(name, empty, lines)
        self.texture:SetTexture(ICONS .. (name or empty))
        self.texture:SetAlpha(name and 1 or EMPTY_SHAPE)
        self.lines = lines
    end
    icon:SetScript("OnEnter", function(self) if self.lines then Tooltip(self, self.lines) end end)
    icon:SetScript("OnLeave", GameTooltip_Hide)
    return icon
end

-- A photo's bottom edge on a right page: a cross beam from the middle beam to the post, its top at y (window pixels),
-- with a name written on it. Returns the beam and the text (as big as fits PHOTO_NAME_WIDTH: UI.FitText).
local PHOTO_NAME = { 1, 0.93, 0.78 }
UI.PHOTO_NAME_WIDTH = 300
function UI.PhotoBeam(parent, y)
    local beam = UI.CrossBeam(parent, SPLIT.right.left, SPLIT.right.right, y)
    local text = beam:CreateFontString(nil, "OVERLAY")
    text:SetPoint("CENTER", 0, 1)
    text:SetFont(NAME_FONT, 20, "")
    text:SetTextColor(unpack(PHOTO_NAME))
    UI.OutlineText(text, TEXT_OUTLINE)
    return beam, text
end

-- A button: a small wooden plank like the sidebar's (UI.SkinButton): dimmed, lit while hovered or the current one, its
-- word gold while current. Centred in the cell [x, x + width] across spec.top..spec.bottom (window pixels), spec.size
-- its word's size at most. button:SetTab(word, current). Its click sound is the caller's (a click script replaces the
-- skin's); hover and press are the skin's (add to them with HookScript).
local TAB_GAP, TAB_INSET = 6, 3  -- between planks; above and below them in their band
local TAB_WORD = { 1, 0.93, 0.78 }

-- A folder tab, in the cell [x, x + width] across spec.top..spec.bottom (window pixels), spec.size its word's size at
-- most. A rule runs along the strip's bottom (each tab draws its cell's piece) in the open tab's colour: the open tab
-- stands full height and joins it, like a folder's; the others sit lower, darker, set back. tab:SetTab(word, current).
-- Its click sound is the caller's; add to its hover with HookScript.
local FOLDER = {
    gap = 4, rule = 3, drop = 4,  -- between tabs; the rule's height; how much lower a closed tab's top sits
    open = { 0.36, 0.25, 0.15 }, openTop = { 0.55, 0.4, 0.24 },
    closed = { 0.1, 0.07, 0.05 }, closedTop = { 0.2, 0.14, 0.1 }, hover = { 0.2, 0.14, 0.09 },
    side = { 0.03, 0.02, 0.01 },
    word = { 0.78, 0.72, 0.62 }, wordHover = { 1, 0.93, 0.78 }, wordOpen = { 1, 0.82, 0 },
}
function UI.TabButton(parent, x, spec, width)
    local w, h = width - FOLDER.gap, spec.bottom - spec.top - 2
    local tab = CreateFrame("Button", nil, parent)
    tab:SetSize(w, h)
    tab:SetPoint("BOTTOMLEFT", UI.window, "TOPLEFT", x + FOLDER.gap / 2, -spec.bottom)
    local rule = tab:CreateTexture(nil, "BACKGROUND")
    rule:SetPoint("BOTTOMLEFT", -FOLDER.gap / 2, 0)
    rule:SetSize(width, FOLDER.rule)
    rule:SetColorTexture(unpack(FOLDER.open))
    tab.face = tab:CreateTexture(nil, "BORDER")
    tab.face:SetPoint("BOTTOMRIGHT")
    tab.top = tab:CreateTexture(nil, "ARTWORK")
    tab.top:SetPoint("TOPLEFT", tab.face)
    tab.top:SetPoint("TOPRIGHT", tab.face)
    tab.top:SetHeight(2)
    for _, point in ipairs({ "LEFT", "RIGHT" }) do
        local side = tab:CreateTexture(nil, "ARTWORK")
        side:SetPoint("TOP" .. point, tab.face)
        side:SetPoint("BOTTOM" .. point, tab.face)
        side:SetWidth(1)
        side:SetColorTexture(unpack(FOLDER.side))
    end
    tab.text = tab:CreateFontString(nil, "OVERLAY")
    tab.text:SetFont(NAME_FONT, spec.size, "")
    UI.OutlineText(tab.text, TEXT_OUTLINE)
    function tab:Paint()
        local open = self.current
        -- The open one runs down over the rule (its colour); a closed one stands on the rule.
        self.face:SetSize(w, open and h or h - FOLDER.drop - FOLDER.rule)
        self.face:SetPoint("BOTTOMRIGHT", 0, open and 0 or FOLDER.rule)
        self.face:SetColorTexture(unpack(open and FOLDER.open or self.hovered and FOLDER.hover or FOLDER.closed))
        self.top:SetColorTexture(unpack(open and FOLDER.openTop or FOLDER.closedTop))
        self.text:SetPoint("CENTER", self.face, "CENTER", 0, open and 1 or 0)
        self.text:SetTextColor(unpack(open and FOLDER.wordOpen or self.hovered and FOLDER.wordHover or FOLDER.word))
    end
    function tab:SetTab(word, current)
        self.current = current
        Fit(self.text, NAME_FONT, spec.size, 9, word, w * 0.8)
        self:Paint()
    end
    tab:SetScript("PostClick", function() UI.CloseHeaderPanels() end)  -- (callers set OnClick)
    tab:SetScript("OnEnter", function(self) self.hovered = true self:Paint() end)
    tab:SetScript("OnLeave", function(self) self.hovered = false self:Paint() end)
    return tab
end

function UI.PlankButton(parent, x, spec, width)
    local w, h = width - TAB_GAP, spec.bottom - spec.top - 2 * TAB_INSET
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(w, h)
    button:SetPoint("CENTER", UI.window, "TOPLEFT", x + width / 2, -(spec.top + spec.bottom) / 2)
    button.text = button:CreateFontString(nil, "OVERLAY")
    button.text:SetPoint("CENTER", 0, 1)
    button.text:SetFont(NAME_FONT, spec.size, "")
    UI.OutlineText(button.text, TEXT_OUTLINE)
    UI.SkinButton(button, { dimUnselected = true, steady = true })
    function button:SetTab(word, current)
        Fit(self.text, NAME_FONT, spec.size, 9, word, w * 0.64)
        self.text:SetTextColor(unpack(current and { 1, 0.82, 0 } or TAB_WORD))
        if current then self:LockHighlight() else self:UnlockHighlight() end
    end
    return button
end

-- Builds the header (once, on first use).
local header
-- The rank and edit panels open over the left slot under the pages' tabs, on a solid backing from wood to wood.
local PANEL_TOP = 319
local function PanelBacking(texture)
    texture:SetPoint("TOPLEFT", UI.window, "TOPLEFT", SPLIT.under.left, -PANEL_TOP)
    texture:SetPoint("BOTTOMRIGHT", UI.window, "TOPLEFT", SPLIT.under.middle, -SPLIT.under.bottom)
    texture:SetColorTexture(0.05, 0.03, 0.02)
end
-- Closes the rank and edit panels (a page's tab clicked).
function UI.CloseHeaderPanels()
    if not header then return end
    header.rank:Hide()
    header.editor:Hide()
end
local BuildEditor, ShowBackdrop  -- edit mode, below
local function Build()
    local W = UI.window
    local function At(region, point, x, y) region:SetPoint(point, W, "TOPLEFT", x, -y) end
    header = CreateFrame("Frame", nil, W)
    header:SetAllPoints()
    header:SetFrameLevel(W:GetFrameLevel() + 10)  -- over the pages (under the window's wood)
    local back = CreateFrame("Frame", nil, header)  -- the boards, under the rest
    back:SetAllPoints()
    local h = CreateFrame("Frame", nil, header)
    h:SetAllPoints()
    h:SetFrameLevel(back:GetFrameLevel() + 3)

    -- The board, and the stats strip: a cross beam, its middle darker. Both run on under the post and the beams.
    local under = SPLIT.under
    local board = back:CreateTexture(nil, "BACKGROUND")
    At(board, "TOPLEFT", under.left, under.top)
    board:SetSize(under.middle - under.left, HEADER.bottom - under.top)
    board:SetColorTexture(unpack(HEADER.color))
    header.backdrop = back:CreateTexture(nil, "BACKGROUND", nil, 1)
    header.backdrop:SetAllPoints(board)
    header.backdrop:Hide()
    header.dim = back:CreateTexture(nil, "BACKGROUND", nil, 2)
    header.dim:SetAllPoints(board)
    header.dim:SetColorTexture(0, 0, 0, HEADER.backdrop.dim)
    header.dim:Hide()
    local strip = HEADER.strip
    local behind = back:CreateTexture(nil, "BACKGROUND")
    At(behind, "TOPLEFT", under.left, strip.top)
    behind:SetSize(under.middle - under.left, strip.bottom - strip.top)
    behind:SetColorTexture(0.06, 0.04, 0.03)  -- behind the beam's ragged edges
    UI.CrossBeam(back, SPLIT.left.left, SPLIT.left.right, strip.top, nil, strip.bottom - strip.top, true)
    local shade = h:CreateTexture(nil, "BACKGROUND")
    At(shade, "TOPLEFT", strip.shade[1], strip.top)
    shade:SetSize(strip.shade[2] - strip.shade[1], strip.bottom - strip.top)
    shade:SetColorTexture(0, 0, 0, strip.shade[3])
    UI.MiddleBeam(header)

    -- The bar to their next Ogre Rank, starting behind the badge: a black edge, the track, the yellow share, the points.
    local bar = HEADER.bar
    local edge = h:CreateTexture(nil, "BORDER", nil, 0)
    At(edge, "TOPLEFT", bar.left, bar.top)
    edge:SetSize(bar.right - bar.left, bar.bottom - bar.top)
    edge:SetColorTexture(0, 0, 0)
    local track = h:CreateTexture(nil, "BORDER", nil, 1)
    At(track, "TOPLEFT", bar.left, bar.top + 2)
    track:SetSize(bar.right - bar.left - 2, bar.bottom - bar.top - 4)
    track:SetColorTexture(unpack(BAR_TRACK))
    header.barFill = h:CreateTexture(nil, "BORDER", nil, 2)
    At(header.barFill, "TOPLEFT", bar.left, bar.top + 2)
    header.barFill:SetHeight(bar.bottom - bar.top - 4)
    header.barFill:SetColorTexture(unpack(BAR_COLOR))
    header.barWidth = bar.right - bar.left - 2
    header.barText = h:CreateFontString(nil, "OVERLAY")
    At(header.barText, "CENTER", (bar.shown + bar.right) / 2, (bar.top + bar.bottom) / 2)
    header.barText:SetFont(NAME_FONT, 11, "")
    header.barText:SetTextColor(1, 1, 1)
    UI.OutlineText(header.barText, { 0, 0, 0 })

    -- The badge, over the bar's start.
    local spec = HEADER.badge
    local badge = CreateFrame("Button", nil, h)
    badge:SetSize(spec.size, spec.size)
    At(badge, "CENTER", spec.x, spec.y)
    badge.art = badge:CreateTexture(nil, "ARTWORK")
    badge.art:SetAllPoints()
    badge.number = badge:CreateFontString(nil, "OVERLAY")
    badge.number:SetFont(NAME_FONT, math.floor(spec.size * 0.3), "")
    badge.number:SetPoint("CENTER", 0, spec.size * 0.15)
    UI.OutlineText(badge.number, TEXT_OUTLINE)
    badge:SetScript("OnClick", function()
        UI.ClickSound()
        header.editor:Hide()
        header.rank:SetShown(not header.rank:IsShown())
    end)
    badge:SetScript("OnEnter", function(self)
        local current, nextRank, points = ns.GetRank(header.key)
        Tooltip(self, { ("Ogre Rank %d: %s"):format(current.rank, current.title),
            nextRank and ("%d points, %d more to rank %d"):format(points, nextRank.points - points, nextRank.rank)
                or ("%d points - the top rank"):format(points), "Click to see the perks" })
    end)
    badge:SetScript("OnLeave", GameTooltip_Hide)
    header.badge = badge

    -- Their full name (click for the list of you and your guildmates), the arrows after it, their title under it.
    header.name = h:CreateFontString(nil, "OVERLAY")
    At(header.name, "LEFT", HEADER.name.x, HEADER.name.y)
    header.name:SetFont(NAME_FONT, HEADER.name.size, "")
    header.name:SetWordWrap(false)
    UI.OutlineText(header.name, { 0, 0, 0 })
    local nameButton = CreateFrame("Button", nil, h)
    At(nameButton, "TOPLEFT", HEADER.name.x, HEADER.name.y - 13)
    nameButton:SetSize(HEADER.name.right - HEADER.name.x, 26)
    nameButton:SetScript("OnClick", function(self)
        if not next(KillTrackerFriends) then return end
        if not MenuUtil then return UI.StepViewing(1) end
        MenuUtil.CreateContextMenu(self, function(_, root)
            root:CreateTitle("Show")
            root:CreateRadio(ns.MyName() .. " (me)", function() return header.key == nil end, function() ns.ViewPlayer(nil, header.page) end)
            for _, friend in ipairs(ns.GetFriends()) do
                root:CreateRadio(friend.name, function() return header.key == friend.key end,
                    function() ns.ViewPlayer(friend.key, header.page) end)
            end
        end)
    end)
    nameButton:SetScript("OnEnter", function(self)
        if next(KillTrackerFriends) then Tooltip(self, { "Click to pick a guildmate" }) end
    end)
    nameButton:SetScript("OnLeave", GameTooltip_Hide)
    header.arrows = {}
    for i, delta in ipairs({ -1, 1 }) do
        local arrow = CreateFrame("Button", nil, h)
        arrow:SetSize(HEADER.arrows.size, HEADER.arrows.size)
        At(arrow, "CENTER", HEADER.arrows.x + (i - 1) * HEADER.arrows.gap, HEADER.name.y)
        local art = arrow:CreateTexture(nil, "ARTWORK")
        art:SetAllPoints()
        art:SetTexture(ARROW_ART)
        if delta < 0 then art:SetTexCoord(1, 0, 0, 1) end
        art:SetVertexColor(unpack(ARROW_DIM))
        arrow:SetScript("OnEnter", function(self)
            art:SetVertexColor(1, 1, 1)
            Tooltip(self, { delta < 0 and "Previous" or "Next", "Step through you and each synced guildmate." })
        end)
        arrow:SetScript("OnLeave", function()
            art:SetVertexColor(unpack(ARROW_DIM))
            GameTooltip_Hide()
        end)
        arrow:SetScript("OnMouseDown", function() art:SetPoint("TOPLEFT", 1, -1) art:SetPoint("BOTTOMRIGHT", 1, -1) end)
        arrow:SetScript("OnMouseUp", function() art:SetAllPoints() end)
        arrow:SetScript("OnClick", function()
            UI.ClickSound()
            UI.StepViewing(delta)
        end)
        header.arrows[i] = arrow
    end
    header.title = h:CreateFontString(nil, "OVERLAY")
    At(header.title, "LEFT", HEADER.title.x, HEADER.title.y)
    header.title:SetFont(NAME_FONT, HEADER.title.size, "")
    header.title:SetTextColor(unpack(TITLE_COLOR))
    header.title:SetWordWrap(false)
    UI.OutlineText(header.title, { 0, 0, 0 })
    header.titleWidth = HEADER.icons.professions[1][1] - HEADER.icons.professions[1][3] / 2 - HEADER.title.x - 4

    -- The icons: race and class, the professions under them.
    local function Spot(s) return { x = s[1], y = s[2], size = s[3] } end
    header.race = UI.CreateIcon(h, Spot(HEADER.icons.race))
    header.class = UI.CreateIcon(h, Spot(HEADER.icons.class))
    header.professions, header.secondary = {}, {}
    for i, s in ipairs(HEADER.icons.professions) do header.professions[i] = UI.CreateIcon(h, Spot(s)) end
    for i, s in ipairs(HEADER.icons.secondary) do header.secondary[i] = UI.CreateIcon(h, Spot(s)) end

    -- The stats strip: points, kills, achievements, each its icon and number.
    header.stats = {}
    for i, s in ipairs(HEADER.stats) do
        local stat = CreateFrame("Frame", nil, h)
        local from = s.x - s.size / 2
        At(stat, "TOPLEFT", from, strip.top)
        stat:SetSize(s.text + HEADER.statWidth - from, strip.bottom - strip.top)
        stat:EnableMouse(true)
        local icon = stat:CreateTexture(nil, "ARTWORK")
        icon:SetTexture(MEDIA_ICONS .. s.icon)
        icon:SetSize(s.size, s.size)
        At(icon, "CENTER", s.x, s.y)
        stat.value = stat:CreateFontString(nil, "OVERLAY")
        At(stat.value, "LEFT", s.text, HEADER.statY)
        stat.value:SetFont(NAME_FONT, HEADER.statSize, "")
        stat.value:SetTextColor(1, 1, 1)
        UI.OutlineText(stat.value, { 0, 0, 0 })
        stat:SetScript("OnEnter", function(self) if self.lines then Tooltip(self, self.lines) end end)
        stat:SetScript("OnLeave", GameTooltip_Hide)
        header.stats[i] = stat
    end

    -- The rank and its perks, over the left slot (the badge opens and closes it).
    local slot = SPLIT.left
    local rank = CreateFrame("Frame", nil, header)
    rank:SetFrameLevel(W:GetFrameLevel() + 26)  -- over the pages (and their panels), under the beams and posts
    At(rank, "TOPLEFT", slot.left + 10, PANEL_TOP + 8)
    rank:SetSize(slot.right - slot.left - 20, slot.bottom - PANEL_TOP - 16)
    rank:EnableMouse(true)
    rank:Hide()
    local rankShade = rank:CreateTexture(nil, "BACKGROUND")
    PanelBacking(rankShade)
    rank.badge = rank:CreateTexture(nil, "ARTWORK")
    rank.badge:SetSize(56, 56)
    rank.badge:SetPoint("TOPLEFT", 2, -2)
    rank.number = rank:CreateFontString(nil, "OVERLAY")
    rank.number:SetFont(NAME_FONT, 18, "")
    rank.number:SetPoint("CENTER", rank.badge, "CENTER", 0, 8)
    UI.OutlineText(rank.number, TEXT_OUTLINE)
    rank.title = rank:CreateFontString(nil, "OVERLAY")
    rank.title:SetFont(NAME_FONT, 18, "")
    rank.title:SetTextColor(1, 0.82, 0.25)
    rank.title:SetPoint("TOPLEFT", rank.badge, "TOPRIGHT", 8, -4)
    rank.points = rank:CreateFontString(nil, "OVERLAY")
    rank.points:SetFont(NAME_FONT, 12, "")
    rank.points:SetTextColor(unpack(PANEL_TEXT))
    rank.points:SetPoint("TOPLEFT", rank.title, "BOTTOMLEFT", 0, -4)
    local perksHeading = rank:CreateFontString(nil, "OVERLAY")
    perksHeading:SetFont(NAME_FONT, 14, "")
    perksHeading:SetTextColor(1, 0.82, 0.25)
    perksHeading:SetPoint("TOPLEFT", 4, -66)
    perksHeading:SetText("Rank perks")
    rank.lines = {}
    for i = 1, RANK_LINES do
        local line = rank:CreateFontString(nil, "OVERLAY")
        line:SetFont(NAME_FONT, 12, "")
        line:SetPoint("TOPLEFT", 4, -68 - i * 18)
        line:SetWidth(slot.right - slot.left - 28)
        line:SetJustifyH("LEFT")
        line:SetWordWrap(false)
        rank.lines[i] = line
    end
    header.rank = rank
    BuildEditor(W, h, At)
end

-- The board's crop: the square picture zoomed (1..maxZoom) round a centre (cx, cy: 0..1, y down), cut to the board's
-- shape and kept inside the picture. Returns the texture coordinates and the centre and zoom actually used.
local BOARD = { w = SPLIT.under.middle - SPLIT.under.left, h = HEADER.bottom - SPLIT.under.top }
local function Crop(cx, cy, zoom)
    zoom = math.max(1, math.min(HEADER.backdrop.maxZoom, zoom or 1))
    local w, h = 1 / zoom, BOARD.h / BOARD.w / zoom
    cx = math.max(w / 2, math.min(1 - w / 2, cx or 0.5))
    cy = math.max(h / 2, math.min(1 - h / 2, cy or 0.5))
    return cx - w / 2, cx + w / 2, cy - h / 2, cy + h / 2, cx, cy, zoom
end

-- The card someone's header choices are on (Sync.lua's card section): yours (key nil) or a guildmate's.
local function CardOf(key)
    if key then return KillTrackerFriends[key] and KillTrackerFriends[key].card or {} end
    return KillTrackerDB.card or {}
end

-- The background on the board: the one they picked (yours only while you still own a picture with it), cropped.
function ShowBackdrop(key)
    local card = CardOf(key)
    local option = ns.BackgroundOption(key, card.headerBg)
    if option then
        header.backdrop:SetTexture(ns.MintTexture(option, {}))
        local left, right, top, bottom = Crop(card.cropX, card.cropY, card.cropZoom)
        header.backdrop:SetTexCoord(left, right, top, bottom)
    end
    header.backdrop:SetShown(option ~= nil)
    header.dim:SetShown(option ~= nil)
end

-- Your card, to change (KillTrackerDB.card); call Changed() after.
local function MyCard()
    KillTrackerDB.card = KillTrackerDB.card or {}
    return KillTrackerDB.card
end
local function Changed()
    ns.Touch(MyCard())  -- syncs it to guildmates
    ShowBackdrop(nil)
    header.name:SetTextColor(unpack(ns.GetNameColor(nil)))
    if header.editor:IsShown() then header.editor:Refresh() end
end

StaticPopupDialogs["SOLC_BUY_NAME_COLOR"] = {
    text = "Buy %s for your name for %d points?",
    button1 = YES or "Yes",
    button2 = NO or "No",
    OnAccept = function(_, id)
        local bought, reason = ns.BuyNameColor(id)
        if not bought then return ns.Print(reason) end
        MyCard().nameColor = id
        Changed()
        if ns.OnKillsChanged then ns.OnKillsChanged() end  -- the points shown
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

-- Edit mode (your own header): the EDIT button opens a panel over the left slot to pick the board's background and
-- your name's colour; while it's open, drag the board's picture to move it and scroll on it to zoom.
local EDIT = {
    thumb = { top = 54, size = 54, gap = 7, perRow = 6 },
    swatch = { top = 262, w = 54, h = 26, gap = 7, perRow = 6 },
    gold = { 1, 0.82, 0 },
}
function BuildEditor(W, h, At)
    local slot = SPLIT.left
    local panelWidth = slot.right - slot.left - 20

    -- The EDIT button, over everything on the board (also over the cropper).
    local spec = HEADER.edit
    local edit = CreateFrame("Button", nil, h)
    edit:SetFrameLevel(h:GetFrameLevel() + 10)
    edit:SetSize(spec.size, spec.size)
    At(edit, "CENTER", spec.x, spec.y)
    edit.art = edit:CreateTexture(nil, "ARTWORK")
    edit.art:SetAllPoints()
    edit.art:SetTexture(MEDIA_ICONS .. "Edit")  -- tools/make-role-icons.js
    -- A light dark edge (copies a pixel off on each side), so it holds up on a busy background without being bigger
    -- or heavier; it follows the pencil when it dips.
    for _, offset in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
        local copy = edit:CreateTexture(nil, "BORDER")
        copy:SetTexture(MEDIA_ICONS .. "Edit")
        copy:SetPoint("TOPLEFT", edit.art, "TOPLEFT", offset[1], offset[2])
        copy:SetPoint("BOTTOMRIGHT", edit.art, "BOTTOMRIGHT", offset[1], offset[2])
        copy:SetVertexColor(0, 0, 0)
        copy:SetAlpha(0.7)
    end
    -- A glint over it (added light) while hovered or while the editor is open; it dips a pixel while pressed.
    edit.glint = edit:CreateTexture(nil, "OVERLAY")
    edit.glint:SetAllPoints(edit.art)
    edit.glint:SetTexture(MEDIA_ICONS .. "Edit")
    edit.glint:SetBlendMode("ADD")
    edit.glint:SetAlpha(0.35)
    function edit:Paint()
        self.glint:SetShown(self.hovered or (header.editor and header.editor:IsShown()) or false)
    end
    edit:SetScript("OnEnter", function(self)
        self.hovered = true
        self:Paint()
        Tooltip(self, { "Edit your header", "Pick its background and crop it, and your name's colour." })
    end)
    edit:SetScript("OnLeave", function(self)
        self.hovered = false
        self:Paint()
        GameTooltip_Hide()
    end)
    edit:SetScript("OnMouseDown", function(self) self.art:SetPoint("TOPLEFT", 1, -1) self.art:SetPoint("BOTTOMRIGHT", 1, -1) end)
    edit:SetScript("OnMouseUp", function(self) self.art:SetAllPoints() end)
    edit:Paint()
    edit:SetScript("OnClick", function()
        UI.ClickSound()
        header.editor:SetShown(not header.editor:IsShown())
    end)
    header.editButton = edit

    -- The panel.
    local editor = CreateFrame("Frame", nil, header)
    editor:SetFrameLevel(W:GetFrameLevel() + 26)  -- like the rank panel
    At(editor, "TOPLEFT", slot.left + 10, PANEL_TOP + 8)
    editor:SetSize(panelWidth, slot.bottom - PANEL_TOP - 16)
    editor:EnableMouse(true)
    editor:Hide()
    local shade = editor:CreateTexture(nil, "BACKGROUND")
    PanelBacking(shade)
    local function Heading(text, y, size)
        local line = editor:CreateFontString(nil, "OVERLAY")
        line:SetFont(NAME_FONT, size or 14, "")
        line:SetTextColor(1, 0.82, 0.25)
        line:SetPoint("TOPLEFT", 4, -y)
        line:SetText(text)
        return line
    end
    Heading("Edit your header", 2, 18)
    Heading("Background", 32)
    Heading("Crop", 184)
    local hint = editor:CreateFontString(nil, "OVERLAY")
    hint:SetFont(NAME_FONT, 12, "")
    hint:SetTextColor(unpack(PANEL_TEXT))
    hint:SetPoint("TOPLEFT", 4, -204)
    hint:SetWidth(panelWidth - 8)
    hint:SetJustifyH("LEFT")
    hint:SetText("Drag the picture on your header to move it, scroll on it to zoom in and out.")
    Heading("Name colour", 240)

    -- A square or swatch to click: its fill over a dark edge, a gold rim round it while it's the one picked.
    local function Choice(w, hgt, x, y)
        local button = CreateFrame("Button", nil, editor)
        button:SetSize(w, hgt)
        button:SetPoint("TOPLEFT", x, -y)
        button.rim = button:CreateTexture(nil, "BACKGROUND")
        button.rim:SetPoint("TOPLEFT", -3, 3)
        button.rim:SetPoint("BOTTOMRIGHT", 3, -3)
        button.rim:SetColorTexture(unpack(EDIT.gold))
        button.edge = button:CreateTexture(nil, "BORDER")
        button.edge:SetAllPoints()
        button.edge:SetColorTexture(0, 0, 0)
        button.fill = button:CreateTexture(nil, "ARTWORK")
        button.fill:SetPoint("TOPLEFT", 2, -2)
        button.fill:SetPoint("BOTTOMRIGHT", -2, 2)
        button.label = button:CreateFontString(nil, "OVERLAY")
        button.label:SetFont(NAME_FONT, 11, "")
        button.label:SetPoint("CENTER", 0, 1)
        UI.OutlineText(button.label, { 0, 0, 0 })
        button:SetScript("OnEnter", function(self) if self.lines then Tooltip(self, self.lines) end end)
        button:SetScript("OnLeave", GameTooltip_Hide)
        return button
    end

    -- The backgrounds: none, then the ones on your pictures (ns.OwnedBackgrounds, at most one per option).
    local thumb = EDIT.thumb
    editor.thumbs = {}
    for i = 1, 12 do
        local x = ((i - 1) % thumb.perRow) * (thumb.size + thumb.gap) + 2
        local y = thumb.top + math.floor((i - 1) / thumb.perRow) * (thumb.size + thumb.gap)
        local button = Choice(thumb.size, thumb.size, x, y)
        button:SetScript("OnClick", function(self)
            UI.ClickSound()
            local card = MyCard()
            if card.headerBg ~= self.id then card.cropX, card.cropY, card.cropZoom = nil, nil, nil end
            card.headerBg = self.id
            Changed()
        end)
        editor.thumbs[i] = button
    end

    -- The name colours (ns.NAME_COLORS): yours to pick, a rank's (locked until then), or to buy.
    local swatch = EDIT.swatch
    editor.swatches = {}
    for i, entry in ipairs(ns.NAME_COLORS) do
        local x = ((i - 1) % swatch.perRow) * (swatch.w + swatch.gap) + 2
        local y = swatch.top + math.floor((i - 1) / swatch.perRow) * (swatch.h + swatch.gap)
        local button = Choice(swatch.w, swatch.h, x, y)
        button.entry = entry
        -- Not yours yet: a lock and the rank it unlocks at, or a coin and its price.
        button.badge = button:CreateTexture(nil, "OVERLAY")
        button.badge:SetSize(14, 14)
        button.badge:SetPoint("LEFT", 5, 0)
        button.label:ClearAllPoints()
        button.label:SetPoint("LEFT", button.badge, "RIGHT", 2, 1)
        button:SetScript("OnClick", function(self)
            if ns.HasNameColor(self.entry) then
                UI.ClickSound()
                MyCard().nameColor = self.entry.id
                Changed()
            elseif self.entry.cost then
                UI.ClickSound()
                local popup = StaticPopup_Show("SOLC_BUY_NAME_COLOR", self.entry.name, self.entry.cost)
                if popup then popup.data = self.entry.id end
            end
        end)
        editor.swatches[i] = button
    end

    -- Back to the middle of the picture, and done.
    local buttons = { top = slot.bottom - 46, bottom = slot.bottom - 12, size = 16 }
    local reset = UI.PlankButton(editor, slot.left + 10, buttons, 130)
    reset:SetTab("Reset crop", false)
    reset:SetScript("OnClick", function()
        UI.ClickSound()
        local card = MyCard()
        card.cropX, card.cropY, card.cropZoom = nil, nil, nil
        Changed()
    end)
    local done = UI.PlankButton(editor, slot.right - 10 - 110, buttons, 110)
    done:SetTab("Done", false)
    done:SetScript("OnClick", function()
        UI.ClickSound()
        editor:Hide()
    end)

    function editor:Refresh()
        local card = MyCard()
        local owned = ns.OwnedBackgrounds()
        for i, button in ipairs(self.thumbs) do
            local option = i > 1 and owned[i - 1]
            button:SetShown(i == 1 or option ~= nil and option ~= false)
            button.id = option and option.id or nil
            local picked = (ns.BackgroundOption(nil, card.headerBg) and card.headerBg or nil) == button.id
            button.rim:SetShown(picked)
            if option then
                button.fill:SetTexture(ns.MintTexture(option, {}))
                button.fill:SetVertexColor(1, 1, 1)
                button.edge:SetColorTexture(ns.RarityRGB(option.rarity))
                button.label:SetText("")
                button.lines = { ("|c%s%s|r"):format(ns.RARITY_COLORS[option.rarity] or "ffffffff", option.name) }
            else
                button.fill:SetColorTexture(unpack(HEADER.color))
                button.edge:SetColorTexture(0, 0, 0)
                button.label:SetText("None")
                button.lines = { "No background", #owned == 0 and "Mint a picture to get backgrounds" or nil }
            end
        end
        local shown = ns.GetNameColor(nil)
        local balance = ns.GetPoints().balance
        for _, button in ipairs(self.swatches) do
            local entry = button.entry
            local has = ns.HasNameColor(entry)
            button.fill:SetColorTexture(unpack(entry.value))
            button.fill:SetAlpha(has and 1 or 0.3)
            button.rim:SetShown(entry.value == shown)
            button.label:SetText(has and "" or entry.rank and tostring(entry.rank) or tostring(entry.cost))
            button.badge:SetShown(not has)
            button.badge:SetTexture(MEDIA_ICONS .. (entry.rank and "Lock" or "Points"))
            local r, g, b = unpack(entry.value)
            local name = ("|cff%02x%02x%02x%s|r"):format(r * 255, g * 255, b * 255, entry.name)
            if has then
                button.lines = { name }
            elseif entry.rank then
                button.lines = { name, ("Unlocks at Ogre Rank %d"):format(entry.rank) }
            else
                button.lines = { name, ("%d points - click to buy (you have %d)"):format(entry.cost, balance) }
            end
        end
    end
    editor:SetScript("OnShow", function(self)
        header.editButton:Paint()
        header.rank:Hide()
        header.cropper:Show()
        self:Refresh()
    end)
    editor:SetScript("OnHide", function()
        header.cropper:Hide()
        header.editButton:Paint()
    end)
    header.editor = editor

    -- The cropper: over the board while editing, a gold line round it; drag to move the picture, scroll to zoom.
    local under = SPLIT.under
    local cropper = CreateFrame("Frame", nil, h)
    cropper:SetFrameLevel(h:GetFrameLevel() + 5)
    At(cropper, "TOPLEFT", under.left, under.top)
    cropper:SetSize(BOARD.w, BOARD.h)
    cropper:EnableMouse(true)
    cropper:EnableMouseWheel(true)
    cropper:Hide()
    for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" }, { "TOPLEFT", "BOTTOMLEFT" },
        { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local line = cropper:CreateTexture(nil, "OVERLAY")
        line:SetColorTexture(unpack(EDIT.gold))
        line:SetPoint(side[1])
        line:SetPoint(side[2])
        if side[1]:sub(1, 3) == side[2]:sub(1, 3) then line:SetHeight(2) else line:SetWidth(2) end
    end
    local function Current()
        local card = MyCard()
        local _, _, _, _, cx, cy, zoom = Crop(card.cropX, card.cropY, card.cropZoom)
        return card, cx, cy, zoom
    end
    cropper:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" or not header.backdrop:IsShown() then return end
        local card, cx, cy, zoom = Current()
        local scale = self:GetEffectiveScale()
        local x0, y0 = GetCursorPosition()
        self:SetScript("OnUpdate", function()
            local x, y = GetCursorPosition()
            local per = 1 / (BOARD.w * zoom * scale)  -- of the picture, per screen pixel
            card.cropX = cx - (x - x0) * per
            card.cropY = cy + (y - y0) * per
            ShowBackdrop(nil)
        end)
    end)
    cropper:SetScript("OnMouseUp", function(self)
        if not self:GetScript("OnUpdate") then return end
        self:SetScript("OnUpdate", nil)
        local card, cx, cy = Current()
        card.cropX, card.cropY = cx, cy  -- kept inside the picture
        Changed()
    end)
    cropper:SetScript("OnHide", function(self) self:SetScript("OnUpdate", nil) end)
    cropper:SetScript("OnMouseWheel", function(_, delta)
        if not header.backdrop:IsShown() then return end
        local card, cx, cy, zoom = Current()
        card.cropZoom = math.max(1, math.min(HEADER.backdrop.maxZoom, zoom * (1 + 0.1 * delta)))
        card.cropX, card.cropY = select(5, Crop(cx, cy, card.cropZoom))
        Changed()
    end)
    header.cropper = cropper
end

-- Fills the header in for key (you: nil).
local function Fill(key)
    local p = UI.Profile(key)
    header.key = key
    for _, arrow in ipairs(header.arrows) do arrow:SetShown(next(KillTrackerFriends) ~= nil) end
    header.editButton:SetShown(key == nil)
    if key then header.editor:Hide() end
    ShowBackdrop(key)

    -- The rank: the badge, the name in its colour, the bar to the next.
    local current, nextRank, points = ns.GetRank(key)
    header.badge.art:SetTexture(UI.BadgeArt(current.rank))
    header.badge.number:SetText(current.rank)
    Fit(header.name, NAME_FONT, HEADER.name.size, 10, p.name or "", HEADER.name.right - HEADER.name.x)
    header.name:SetTextColor(unpack(ns.GetNameColor(key)))
    Fit(header.title, NAME_FONT, HEADER.title.size, 10, "-" .. TEST_TITLE, header.titleWidth)
    if nextRank then
        local into, span = points - current.points, math.max(1, nextRank.points - current.points)
        header.barFill:SetWidth(math.max(1, header.barWidth * math.min(1, into / span)))
        header.barText:SetText(("%d/%d"):format(into, span))
    else
        header.barFill:SetWidth(header.barWidth)
        header.barText:SetText("MAX")
    end

    -- The rank panel.
    local rank = header.rank
    rank.badge:SetTexture(UI.BadgeArt(current.rank))
    rank.number:SetText(current.rank)
    rank.title:SetText(current.title)
    rank.points:SetText(nextRank and ("%d points - %d more to %s"):format(points, nextRank.points - points, nextRank.title)
        or ("%d points - the top rank"):format(points))
    for i, line in ipairs(rank.lines) do
        local perk = ns.RANK_PERKS[i]
        if perk then
            local unlocked = perk.rank <= current.rank
            line:SetText(("%s|cff999999rank %d|r  %s"):format(unlocked and "|cff55dd55+|r " or "   ", perk.rank,
                unlocked and perk.text or "|cff888888" .. perk.text .. "|r"))
        end
        line:SetShown(perk ~= nil)
    end

    -- The icons.
    local color = p.classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[p.classFile]
    local classLine = p.className and ((p.level and ("Level %d "):format(p.level) or "")
        .. (color and color:WrapTextInColorCode(p.className) or p.className))
    header.class:Set(CLASSES[p.classFile or ""] and "Class_" .. p.classFile, "Base_CLASS", { classLine or "Class unknown" })
    header.race:Set(p.race and "Race_" .. p.race, "Base_RACE", { p.raceName or "Race unknown" })
    for i, icon in ipairs(header.professions) do
        local entry = p.professions[i]
        icon:Set(entry and "Prof_" .. entry.icon, "Base_PROFESSION",
            entry and { entry.prof.name, ("%d / %d"):format(entry.prof.rank or 0, entry.prof.max or 0) } or { "No profession" })
    end
    for i, icon in ipairs(header.secondary) do
        local s = SECONDARY[i]
        local prof = p.secondary[s.key]
        icon:Set(prof and "Prof_" .. s.key, "Base_SECONDARY",
            prof and { prof.name, ("%d / %d"):format(prof.rank or 0, prof.max or 0) } or { "Not learned" })
    end

    -- The stats: points, kills, achievements (earned of those in the kinds of creature they've killed).
    local source = key and KillTrackerFriends[key] or KillTrackerDB
    local earned, possible = 0, 0
    for _, row in ipairs(ns.GetAchievementProgress(source)) do
        earned, possible = earned + row.earned, possible + #row.tiers
    end
    local stats = {
        { key and (source.earned or 0) or ns.GetPoints().balance, { "Points", key and "Earned in all" or "To spend on minting pictures" } },
        { source.total or 0, { "Kills" } },
        { ("%d/%d"):format(earned, possible), { "Achievements", "Earned, of those for the kinds of creature killed so far" } },
    }
    for i, stat in ipairs(header.stats) do
        Fit(stat.value, NAME_FONT, HEADER.statSize, 9, tostring(stats[i][1]), HEADER.statWidth)
        stat.lines = stats[i][2]
    end
end

-- UI.lua, on every refresh: shows the header and the middle beam for a split page (pageKey) and fills them in for
-- key, or hides them. A different page closes the rank panel and edit mode.
function UI.ShowHeader(shown, key, pageKey)
    if not shown then
        if header then header:Hide() end
        return
    end
    if not header then Build() end
    if header.page ~= pageKey then header.rank:Hide() header.editor:Hide() end
    header.page = pageKey
    header:Show()
    Fill(key)
end
