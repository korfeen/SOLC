-- Guild settings: the point values and guild-activity numbers, the same for the whole guild.
-- Only the guild master and officers (the top OFFICER_RANKS ranks) can change them; changes are sent
-- to the guild (Sync.lua) and every member's addon checks the sender's rank in its own guild roster
-- before accepting them, so they can't be faked by other members. Outside a guild you set your own.
--
-- Saved account-wide in KillTrackerConfig[guild name] = { version, by, values = { [key] = number },
-- bounties = { [week] = "bounty id" or "bounty id.goal" } } (values only where they differ from the
-- defaults; bounties are the officers' picks for coming weeks, see Guild.lua). version is the server time of the change; newer wins.
-- The panel is the Settings page of the main window (GuildPages.lua); /kt config opens it.

local _, ns = ...

local OFFICER_RANKS = 2  -- rank indexes 0 (guild master) and 1
local SOLO = "*solo*"    -- settings key outside a guild

-- Every setting, in panel order. Headings have no key. min/max keep values sensible.
local FIELDS = {
    { heading = "Kill points" },
    { key = "killNormal", label = "Normal mob", default = 1, min = 0, max = 1000 },
    { key = "killElite", label = "Elite", default = 3, min = 0, max = 1000 },
    { key = "killRare", label = "Rare", default = 5, min = 0, max = 1000 },
    { key = "killRareElite", label = "Rare elite", default = 10, min = 0, max = 1000 },
    { key = "killBoss", label = "Boss", default = 25, min = 0, max = 1000 },
    { key = "newMob", label = "New mob type", default = 5, min = 0, max = 1000 },
    { key = "pvpKill", label = "PvP kill", default = 3, min = 0, max = 1000 },
    { heading = "Leaders (first kill)" },
    { key = "leaderTribe", label = "Tribe leader", default = 25, min = 0, max = 10000 },
    { key = "leaderCreature", label = "Creature overlord/champion", default = 50, min = 0, max = 10000 },
    { key = "leaderRace", label = "Race ruler", default = 100, min = 0, max = 10000 },
    { heading = "Achievements" },
    { key = "ach10", label = "10 kills", default = 5, min = 0, max = 10000 },
    { key = "ach25", label = "25 kills", default = 10, min = 0, max = 10000 },
    { key = "ach50", label = "50 kills", default = 20, min = 0, max = 10000 },
    { key = "ach100", label = "100 kills", default = 40, min = 0, max = 10000 },
    { key = "ach250", label = "250 kills", default = 75, min = 0, max = 10000 },
    { key = "ach500", label = "500 kills", default = 125, min = 0, max = 10000 },
    { key = "ach1000", label = "1000 kills", default = 200, min = 0, max = 10000 },
    { key = "achTribe", label = "Tribe: 1000 kills", default = 150, min = 0, max = 10000 },
    { heading = "Collection" },
    { key = "mintCost", label = "Mint a picture", default = 100, min = 1, max = 100000 },
    { heading = "Guild groups" },
    { key = "groupBonus", label = "Bonus % per guildmate", default = 25, min = 0, max = 1000 },
    { key = "groupMaxGuildmates", label = "Guildmates counted, max", default = 4, min = 0, max = 40 },
    { heading = "Guild dungeons" },
    { key = "dungeonGuildmates", label = "Guildmates needed", default = 3, min = 1, max = 39 },
    { key = "dungeonBoss", label = "Boss", default = 10, min = 0, max = 10000 },
    { key = "dungeonFinalBoss", label = "Final boss", default = 50, min = 0, max = 10000 },
    { heading = "Weekly bounty" },
    { key = "bountyGoalPercent", label = "Goal size % (100 = normal)", default = 100, min = 1, max = 10000 },
    { key = "bountyMinPercent", label = "Reward share % of goal", default = 4, min = 0, max = 100 },
    { key = "bountyReward", label = "Reward", default = 100, min = 0, max = 100000 },
    { key = "bountyExtra", label = "Extra % per bounty kill", default = 100, min = 0, max = 1000 },
}
ns.CONFIG_FIELDS = FIELDS

local DEFAULTS, FIELD_BY_KEY = {}, {}
for _, field in ipairs(FIELDS) do
    if field.key then DEFAULTS[field.key], FIELD_BY_KEY[field.key] = field.default, field end
end

local issecret = issecretvalue or function() return false end

local function GuildKey()
    local guild = IsInGuild() and GetGuildInfo("player")
    if guild and not issecret(guild) then return guild end
    return IsInGuild() and nil or SOLO  -- nil: in a guild whose name isn't known yet
end

-- This guild's settings record, or nil before the guild name is known.
local function Current()
    local key = GuildKey()
    if not key then return end
    KillTrackerConfig = KillTrackerConfig or {}
    KillTrackerConfig[key] = KillTrackerConfig[key] or { version = 0, values = {} }
    return KillTrackerConfig[key]
end

-- A setting's value: the guild's, or the default.
function ns.Config(key)
    local current = Current()
    local value = current and current.values[key]
    if value == nil then return DEFAULTS[key] end
    return value
end

function ns.ConfigVersion()
    local current = Current()
    return current and current.version or 0
end

function ns.ConfigInfo()
    local current = Current()
    return current and current.version > 0 and current or nil
end

-- True if you may change the settings: guild master or officer, or not in a guild.
function ns.CanEditConfig()
    if not IsInGuild() then return true end
    local rankIndex = select(3, GetGuildInfo("player"))
    return rankIndex ~= nil and not issecret(rankIndex) and rankIndex < OFFICER_RANKS
end

-- True if sender ("Name" or "Name-Realm") is a guild master or officer, by your own guild roster.
function ns.IsGuildOfficer(sender)
    local short = sender:match("^[^-]+")
    for i = 1, GetNumGuildMembers and GetNumGuildMembers() or 0 do
        local fullName, _, rankIndex = GetGuildRosterInfo(i)
        if fullName and not issecret(fullName) and (fullName == sender or fullName:match("^[^-]+") == short) then
            return rankIndex ~= nil and rankIndex < OFFICER_RANKS
        end
    end
    return false
end

-- Settings as text for the wire: "key=value,key=value" (only values that differ from the defaults) and
-- the scheduled bounties as "week=id,week=id".
function ns.SerializeConfig()
    local current = Current()
    local pairsList, bounties = {}, {}
    for key, value in pairs(current and current.values or {}) do pairsList[#pairsList + 1] = key .. "=" .. value end
    for week, id in pairs(current and current.bounties or {}) do bounties[#bounties + 1] = week .. "=" .. id end
    table.sort(pairsList)
    table.sort(bounties)
    return table.concat(pairsList, ","), table.concat(bounties, ",")
end

local function Parse(text)
    local values = {}
    for key, value in (text or ""):gmatch("([%w_]+)=(%-?[%d%.]+)") do
        local field, number = FIELD_BY_KEY[key], tonumber(value)
        if field and number then values[key] = math.min(field.max, math.max(field.min, number)) end
    end
    return values
end

local function ParseBounties(text)
    local bounties = {}
    for week, pick in (text or ""):gmatch("(%d+)=([%w_]+%.?%d*)") do bounties[tonumber(week)] = pick end
    return bounties
end

local function Changed()
    if ns.OnConfigChanged then ns.OnConfigChanged() end
    if ns.RefreshConfigPanel then ns.RefreshConfigPanel() end
    if ns.RefreshBountyBoard then ns.RefreshBountyBoard() end
    if ns.OnKillsChanged then ns.OnKillsChanged() end
end

-- Saves new values (a [key] = number table, any missing key = default) and sends them to the guild.
function ns.SetConfig(values)
    if not ns.CanEditConfig() then return false end
    local current = Current()
    if not current then return false end
    current.values = {}
    for key, value in pairs(values) do
        local field = FIELD_BY_KEY[key]
        if field and value ~= field.default then current.values[key] = math.min(field.max, math.max(field.min, value)) end
    end
    return ns.ConfigSaved(current)
end

-- Stamps a change made here and sends it to the guild.
function ns.ConfigSaved(current)
    current.version = math.max((GetServerTime and GetServerTime() or time()), current.version + 1)
    current.by = UnitName("player")
    Changed()
    if ns.BroadcastConfig then ns.BroadcastConfig() end
    return true
end

-- The bounty an officer picked for a week (a day number from ns.CurrentWeek): its id and the officer's own
-- goal (nil = the bounty's usual goal). Nothing for the rotation.
function ns.GetScheduledBounty(week)
    local current = Current()
    local pick = current and current.bounties and current.bounties[week]
    if not pick then return end
    local id, goal = pick:match("^([%w_]+)%.?(%d*)$")
    return id, tonumber(goal)
end

-- Picks the bounty for a week (id nil = back to the rotation; goal nil = its usual goal) and sends it to
-- the guild. Weeks that are over are forgotten.
function ns.ScheduleBounty(week, id, goal)
    if not ns.CanEditConfig() then return false end
    local current = Current()
    if not current then return false end
    current.bounties = current.bounties or {}
    current.bounties[week] = id and (goal and (id .. "." .. math.floor(goal)) or id)
    local thisWeek = ns.CurrentWeek and ns.CurrentWeek() or week
    for w in pairs(current.bounties) do
        if w < thisWeek then current.bounties[w] = nil end
    end
    return ns.ConfigSaved(current)
end

-- Settings received from a guildmate. Applied if newer and the sender is a guild master or officer.
function ns.ReceiveConfig(sender, version, text, bounties)
    local current = Current()
    if not current or not version or version <= current.version or not ns.IsGuildOfficer(sender) then return false end
    current.values, current.version, current.by = Parse(text), version, sender:match("^[^-]+")
    current.bounties = ParseBounties(bounties)
    Changed()
    return true
end

-- Panel -------------------------------------------------------------------------------

local ROW_HEIGHT, PANEL_WIDTH = 22, 300
local panel = CreateFrame("Frame", "KillTrackerSettings", UIParent, "BackdropTemplate")
panel:SetSize(PANEL_WIDTH, 460)
panel:SetPoint("CENTER", 180, 0)
panel:SetFrameStrata("DIALOG")
panel:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
})
panel:SetClampedToScreen(true)
panel:SetMovable(true)
panel:EnableMouse(true)
panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", panel.StartMoving)
panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
panel:Hide()
tinsert(UISpecialFrames, "KillTrackerSettings")

local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", 0, -18)
title:SetText("KillTracker Settings")
local info = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
info:SetPoint("TOP", title, "BOTTOM", 0, -4)
info:SetWidth(PANEL_WIDTH - 40)

local closeButton = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
closeButton:SetPoint("TOPRIGHT", -6, -6)

local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", 16, -60)
scroll:SetPoint("BOTTOMRIGHT", -36, 46)
local content = CreateFrame("Frame", nil, scroll)
content:SetSize(PANEL_WIDTH - 52, #FIELDS * ROW_HEIGHT)
scroll:SetScrollChild(content)

local boxes = {}  -- [key] = edit box
for i, field in ipairs(FIELDS) do
    local y = -(i - 1) * ROW_HEIGHT
    if field.heading then
        local text = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("TOPLEFT", 0, y - 4)
        text:SetText(field.heading)
    else
        local label = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("TOPLEFT", 8, y - 5)
        label:SetText(field.label)
        local box = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
        box:SetSize(60, 18)
        box:SetPoint("TOPRIGHT", -4, y)
        box:SetAutoFocus(false)
        box:SetNumeric(field.min >= 0)
        box:SetMaxLetters(7)
        box:SetScript("OnEnterPressed", box.ClearFocus)
        box:SetScript("OnEscapePressed", box.ClearFocus)
        boxes[field.key] = box
    end
end

local function Fill(values)
    for key, box in pairs(boxes) do box:SetText(tostring(values[key] or DEFAULTS[key])) end
end

local function ShowState()
    local editable = ns.CanEditConfig()
    for _, box in pairs(boxes) do
        box:SetEnabled(editable)
        box:SetTextColor(editable and 1 or 0.6, editable and 1 or 0.6, editable and 1 or 0.6)
    end
    panel.save:SetShown(editable)
    panel.defaults:SetShown(editable)
    local current = ns.ConfigInfo()
    local changed = current and ("Last changed by %s, %s"):format(current.by or "?", date("%Y-%m-%d %H:%M", current.version)) or "Default settings"
    if not IsInGuild() then
        info:SetText(changed .. "\n|cff999999Not in a guild: these are just for you.|r")
    elseif editable then
        info:SetText(changed .. "\n|cff999999Saving sends them to the whole guild.|r")
    else
        info:SetText(changed .. "\n|cff999999Only the guild master and officers can change these.|r")
    end
end

local function Refresh()
    local values = {}
    for key in pairs(DEFAULTS) do values[key] = ns.Config(key) end
    Fill(values)
    ShowState()
end

panel.save = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
panel.save:SetSize(80, 22)
panel.save:SetPoint("BOTTOMRIGHT", -20, 18)
panel.save:SetText("Save")
panel.save:SetScript("OnClick", function()
    local values = {}
    for key, box in pairs(boxes) do values[key] = tonumber(box:GetText()) or ns.Config(key) end
    if ns.SetConfig(values) then
        ns.Print(IsInGuild() and "Settings saved and sent to your guild." or "Settings saved.")
    end
    Refresh()
end)

panel.defaults = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
panel.defaults:SetSize(80, 22)
panel.defaults:SetPoint("BOTTOMLEFT", 20, 18)
panel.defaults:SetText("Defaults")
panel.defaults:SetScript("OnClick", function() Fill(DEFAULTS) end)  -- shown only; Save applies them
panel.defaults:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Fill in the default values. Click Save to use them.", 1, 1, 1, true)
    GameTooltip:Show()
end)
panel.defaults:SetScript("OnLeave", GameTooltip_Hide)

local boardButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
boardButton:SetSize(96, 22)
boardButton:SetPoint("BOTTOM", 0, 18)
boardButton:SetText("Bounty Board")
boardButton:SetScript("OnClick", function() ns.ToggleBountyBoard() end)

panel:SetScript("OnShow", Refresh)
function ns.ToggleConfig()
    if panel:IsShown() then panel:Hide() else panel:Show() end
end
-- Moves the panel into a page of the main window, filling width.
function ns.EmbedConfig(parent, width)
    panel:SetParent(parent)
    panel:ClearAllPoints()
    panel:SetAllPoints(parent)
    panel:SetBackdrop(nil)
    panel:SetMovable(false)
    panel:EnableMouse(false)
    closeButton:Hide()
    title:ClearAllPoints()
    title:SetPoint("TOPLEFT", 12, -12)
    title:SetText("Settings")
    info:ClearAllPoints()
    info:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    info:SetWidth(width - 40)
    info:SetJustifyH("LEFT")
    content:SetWidth(width - 60)
    for i, name in ipairs(UISpecialFrames) do
        if name == "KillTrackerSettings" then table.remove(UISpecialFrames, i) break end
    end
    return panel
end

-- Received settings while the panel is open: show them.
ns.RefreshConfigPanel = function() if panel:IsShown() then Refresh() end end
