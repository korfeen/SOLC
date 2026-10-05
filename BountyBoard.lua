-- The Bounty Board: this week's and next week's bounty. The guild master and officers pick one, from the
-- catalogue (Guild.lua) or built their own (PvP against any race or one race; any creature kind, or one
-- tribe or faction of it), and set the goal; it's sent to the guild with the settings (Config.lua).
-- Everyone else can browse. Shown as the Bounties page of the main window (GuildPages.lua).

local _, ns = ...

local WIDTH, HEIGHT, ROW_HEIGHT = 320, 500, 18
local LIST_WIDTH = WIDTH - 52  -- changed when embedded in the main window
local AUTOMATIC = "*automatic*"
-- Catalogue headings, shown above the bounty with this id.
local HEADINGS = { Murloc = "Creature kinds (the automatic rotation)", defias = "Enemy factions",
    undead = "Creature types", elites = "Special" }

-- weeksAhead: 0 this week, 1 next week. mode: "catalogue" or "custom". subtype: the creature kind opened
-- in custom mode, to choose one of its tribes.
local state = { weeksAhead = 1, mode = "catalogue", subtype = nil }

local board = CreateFrame("Frame", "SOLCBountyBoard", UIParent, "BackdropTemplate")
board:SetSize(WIDTH, HEIGHT)
board:SetPoint("CENTER", -180, 0)
board:SetFrameStrata("DIALOG")
board:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
})
board:SetClampedToScreen(true)
board:SetMovable(true)
board:EnableMouse(true)
board:RegisterForDrag("LeftButton")
board:SetScript("OnDragStart", board.StartMoving)
board:SetScript("OnDragStop", board.StopMovingOrSizing)
board:Hide()
tinsert(UISpecialFrames, "SOLCBountyBoard")

local title = board:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", 0, -18)
title:SetText("Bounty Board")

local closeButton = CreateFrame("Button", nil, board, "UIPanelCloseButton")
closeButton:SetPoint("TOPRIGHT", -6, -6)

local Refresh

local function ToggleRow(labels, y, onClick)
    local buttons = {}
    for i, label in ipairs(labels) do
        local button = CreateFrame("Button", nil, board, "UIPanelButtonTemplate")
        button:SetSize(116, 22)
        button:SetPoint("TOP", (i - 1.5) * 122, y)
        button:SetText(label)
        button:SetScript("OnClick", function() onClick(i); Refresh() end)
        buttons[i] = button
    end
    return buttons
end
local weekButtons = ToggleRow({ "This week", "Next week" }, -42, function(i) state.weeksAhead = i - 1 end)
local modeButtons = ToggleRow({ "Catalogue", "Build your own" }, -66, function(i)
    state.mode = i == 1 and "catalogue" or "custom"
    state.subtype = nil
end)

local info = board:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
info:SetPoint("TOP", 0, -94)
info:SetWidth(WIDTH - 40)

local back = CreateFrame("Button", nil, board, "UIPanelButtonTemplate")
back:SetSize(60, 20)
back:SetPoint("TOPLEFT", 18, -124)
back:SetText("< Back")
back:SetScript("OnClick", function() state.subtype = nil; Refresh() end)
local path = board:CreateFontString(nil, "OVERLAY", "GameFontNormal")
path:SetPoint("LEFT", back, "RIGHT", 8, 0)

local footer = board:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
footer:SetPoint("BOTTOM", 0, 18)
footer:SetWidth(WIDTH - 40)

local scroll = CreateFrame("ScrollFrame", nil, board, "UIPanelScrollFrameTemplate")
scroll:SetPoint("BOTTOMRIGHT", -36, 40)
local content = CreateFrame("Frame", nil, scroll)
content:SetSize(LIST_WIDTH, 1)
scroll:SetScrollChild(content)

-- Picking -----------------------------------------------------------------------------

local function EditBoxOf(popup) return popup and (popup.editBox or (popup.GetEditBox and popup:GetEditBox())) end

StaticPopupDialogs["SOLC_BOUNTY"] = {
    text = "%s",
    button1 = ACCEPT or "Accept",
    button2 = CANCEL or "Cancel",
    hasEditBox = 1,
    OnShow = function(self, data)
        data = data or self.data
        local box = EditBoxOf(self)
        if box and data then box:SetText(tostring(data.goal)) end
    end,
    OnAccept = function(self, data)
        data = data or self.data
        local box = EditBoxOf(self)
        local goal = box and tonumber(box:GetText())
        if goal then goal = math.floor(goal) end
        if not goal or goal < 1 or goal == data.usualGoal then goal = nil end  -- nil: the bounty's usual goal
        if ns.ScheduleBounty(data.week, data.id, goal) then
            ns.Print(("%s: %s, goal %d. Sent to your guild."):format(data.weekName, data.name, goal or data.usualGoal))
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

StaticPopupDialogs["SOLC_BOUNTY_AUTO"] = {
    text = "%s",
    button1 = YES or "Yes",
    button2 = NO or "No",
    OnAccept = function(self, data)
        data = data or self.data
        if ns.ScheduleBounty(data.week, nil) then ns.Print(("%s: the automatic rotation."):format(data.weekName)) end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

local function Pick(id)
    local current = ns.GetBounty(state.weeksAhead)
    if not current or not ns.CanEditConfig() then return end
    local weekName = state.weeksAhead == 0 and "This week's bounty" or "Next week's bounty"
    local which = state.weeksAhead == 0 and "this week's" or "next week's"
    local restart = state.weeksAhead == 0 and "\n\nEveryone's progress on the current bounty starts over." or ""
    if id == AUTOMATIC then
        if not ns.GetScheduledBounty(current.week) then return end
        StaticPopup_Show("SOLC_BOUNTY_AUTO", ("Go back to the automatic rotation for %s bounty?%s"):format(which, restart),
            nil, { week = current.week, weekName = weekName })
        return
    end
    local bounty = ns.ResolveBounty(id)
    if not bounty then return end
    local scheduledID, scheduledGoal = ns.GetScheduledBounty(current.week)
    local usualGoal = ns.BountyGoal(bounty)
    if scheduledID == id then restart = "" end  -- same bounty, new goal: progress stays
    StaticPopup_Show("SOLC_BOUNTY", ("Make %s %s bounty?%s\n\nGuild goal:"):format(bounty.name, which, restart), nil,
        { week = current.week, id = id, name = bounty.name, weekName = weekName, usualGoal = usualGoal,
          goal = scheduledID == id and scheduledGoal or usualGoal })
end

-- Rows ----------------------------------------------------------------------------------

local rows = {}
local function GetRow(i)
    if rows[i] then return rows[i] end
    local row = CreateFrame("Button", nil, content)
    row:SetSize(LIST_WIDTH, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row.count = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.count:SetPoint("RIGHT", -4, 0)
    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.label:SetPoint("LEFT", 4, 0)
    row.label:SetPoint("RIGHT", row.count, "LEFT", -6, 0)
    row.label:SetJustifyH("LEFT")
    row.label:SetWordWrap(false)
    row:SetScript("OnClick", function(self)
        local d = self.data
        if d.open then
            state.subtype = d.open
            Refresh()
        elseif d.id then
            Pick(d.id)
        end
    end)
    row:SetScript("OnEnter", function(self)
        local d = self.data
        if d.heading then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if d.open then
            GameTooltip:AddLine(d.label)
            GameTooltip:AddLine(("Click to choose all %s or one of their %d tribes and factions."):format(d.label, #d.open.tribes), 1, 1, 1, true)
        elseif d.bounty then
            GameTooltip:AddLine(d.bounty.name)
            GameTooltip:AddLine(d.bounty.desc, 1, 1, 1, true)
            GameTooltip:AddDoubleLine("Usual guild goal", ns.BountyGoal(d.bounty), 1, 0.82, 0, 1, 1, 1)
            if d.bounty.count then
                GameTooltip:AddDoubleLine("Extra points per kill", ns.Config("bountyExtra") .. "%", 1, 0.82, 0, 1, 1, 1)
            end
            GameTooltip:AddDoubleLine("Reward", ("%d points"):format(ns.Config("bountyReward")), 1, 0.82, 0, 1, 1, 1)
        else
            GameTooltip:AddLine("Automatic rotation")
            GameTooltip:AddLine("Your guild's own order of the creature kinds, a different one each week.", 1, 1, 1, true)
        end
        if ns.CanEditConfig() and (d.id or d.open) then
            GameTooltip:AddLine(d.open and "Click to open" or "Click to pick", 0.6, 0.6, 0.6)
        end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)
    rows[i] = row
    return row
end

-- A pickable row for bounty id (label defaults to the bounty's name).
local function BountyRow(data, id, scheduledID, label)
    local bounty = ns.ResolveBounty(id)
    if bounty then data[#data + 1] = { id = id, bounty = bounty, label = label or bounty.name, selected = scheduledID == id } end
end

local function CatalogueRows(scheduledID)
    local data = { { id = AUTOMATIC, label = "Automatic rotation", selected = scheduledID == nil } }
    for _, bounty in ipairs(ns.BOUNTIES) do
        if HEADINGS[bounty.id] then data[#data + 1] = { heading = HEADINGS[bounty.id] } end
        BountyRow(data, bounty.id, scheduledID)
    end
    return data
end

local function CustomRows(scheduledID)
    local data = {}
    if state.subtype then
        local entry = state.subtype
        BountyRow(data, ns.KindBountyID(entry.subtype), scheduledID, "All " .. ns.ResolveBounty(ns.KindBountyID(entry.subtype)).name)
        if #entry.tribes > 0 then data[#data + 1] = { heading = "Tribes and factions" } end
        for _, faction in ipairs(entry.tribes) do BountyRow(data, ns.TribeBountyID(faction), scheduledID) end
        return data
    end
    data[#data + 1] = { heading = "PvP" }
    BountyRow(data, ns.RaceBountyID(nil), scheduledID, "Any race")
    for _, race in ipairs(ns.PLAYER_RACES) do BountyRow(data, ns.RaceBountyID(race), scheduledID, race) end
    for _, group in ipairs(ns.BountyTargets().byType) do
        data[#data + 1] = { heading = group.type }
        for _, entry in ipairs(group.subtypes) do
            local id = ns.KindBountyID(entry.subtype)
            local bounty = ns.ResolveBounty(id)
            if #entry.tribes > 0 then
                -- Opens the kind to choose all of it or one tribe; marked if the pick is in there.
                local inside = scheduledID == id
                for _, faction in ipairs(entry.tribes) do inside = inside or scheduledID == ns.TribeBountyID(faction) end
                data[#data + 1] = { open = entry, label = bounty.name, selected = inside, tribes = #entry.tribes }
            else
                BountyRow(data, id, scheduledID)
            end
        end
    end
    return data
end

Refresh = function()
    if not board:IsShown() then return end
    for i, button in ipairs(weekButtons) do
        if i - 1 == state.weeksAhead then button:LockHighlight() else button:UnlockHighlight() end
    end
    for i, button in ipairs(modeButtons) do
        if (i == 1) == (state.mode == "catalogue") then button:LockHighlight() else button:UnlockHighlight() end
    end
    local current = ns.GetBounty(state.weeksAhead)
    if not current then
        info:SetText("Weekly bounties are for guilds; join one to take part.")
        footer:SetText("")
        back:Hide(); path:SetText("")
        for _, row in ipairs(rows) do row:Hide() end
        return
    end
    local scheduledID = ns.GetScheduledBounty(current.week)
    local when = state.weeksAhead == 0 and ("ends in " .. ns.BountyTimeLeft(current.resetsIn))
        or ("starts in " .. ns.BountyTimeLeft(current.resetsIn))
    info:SetText(("|cffffd100%s|r - goal %d, %s\n|cff999999%s, %s|r"):format(current.bounty.name,
        current.goal or ns.BountyGoal(current.bounty), current.scheduled and "picked by an officer" or "automatic rotation",
        state.weeksAhead == 0 and "This week" or "Next week", when))
    footer:SetText(not ns.CanEditConfig() and "Only the guild master and officers can pick bounties."
        or ("Click a bounty to pick it for %s."):format(state.weeksAhead == 0 and "this week" or "next week"))

    local drilled = state.mode == "custom" and state.subtype ~= nil
    back:SetShown(drilled)
    path:SetText(drilled and ns.ResolveBounty(ns.KindBountyID(state.subtype.subtype)).name or "")
    scroll:SetPoint("TOPLEFT", 16, drilled and -150 or -126)

    local data = state.mode == "catalogue" and CatalogueRows(scheduledID) or CustomRows(scheduledID)
    for i, d in ipairs(data) do
        local row = GetRow(i)
        row.data = d
        if d.heading then
            row.label:SetText("|cffffd100" .. d.heading .. "|r")
            row.count:SetText("")
        else
            local mark = d.selected and "|cff33ff33> |r" or "   "
            row.label:SetText(mark .. (d.selected and ("|cff33ff33%s|r"):format(d.label) or d.label))
            if d.open then
                row.count:SetText(("|cff999999%d tribes >|r"):format(d.tribes))
            else
                row.count:SetText(d.bounty and ("|cff999999%d|r"):format(ns.BountyGoal(d.bounty)) or "")
            end
        end
        row:Show()
    end
    for i = #data + 1, #rows do rows[i]:Hide() end
    content:SetHeight(#data * ROW_HEIGHT)
end

board:SetScript("OnShow", Refresh)
ns.RefreshBountyBoard = Refresh

function ns.ToggleBountyBoard()
    if board:IsShown() then board:Hide() else board:Show() end
end

-- Moves the board into a page of the main window, filling width x height.
function ns.EmbedBountyBoard(parent, width)
    board:SetParent(parent)
    board:ClearAllPoints()
    board:SetAllPoints(parent)
    board:SetBackdrop(nil)
    board:SetMovable(false)
    board:EnableMouse(false)
    closeButton:Hide()
    title:ClearAllPoints()
    title:SetPoint("TOPLEFT", 12, -12)
    LIST_WIDTH = width - 50
    content:SetWidth(LIST_WIDTH)
    info:SetWidth(width - 40)
    footer:SetWidth(width - 40)
    for i, name in ipairs(UISpecialFrames) do
        if name == "SOLCBountyBoard" then table.remove(UISpecialFrames, i) break end
    end
    return board
end
