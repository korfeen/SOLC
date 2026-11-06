-- Minimap button: the club logo's sleeping ogre (Media\Icons\Minimap, tools/make-minimap-icon.js). Left-click toggles
-- the Sleepy Ogre Leisure Club window, right-click opens the Bounties, shift-click the Bedroom; drag to move it round the
-- minimap. A badge counts what's waiting (chests to open; "!" for a new rank not seen yet), and it glows while a new rank
-- or an Ogre Godz tribute waits. Its tooltip: your Ogre Rank, this week's bounties, what's waiting, guildmates online.

local _, ns = ...

local ICONS = "Interface\\AddOns\\SOLC\\Media\\Icons\\"
local button = CreateFrame("Button", "SOLCMinimapButton", Minimap)
button:SetSize(31, 31)
button:SetFrameStrata("MEDIUM")
button:SetFrameLevel(8)
button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
button:RegisterForDrag("LeftButton")
button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
button:Hide()

-- (the glow: behind the icon, pulsing while something big waits)
local glow = button:CreateTexture(nil, "BACKGROUND", nil, -1)
glow:SetSize(44, 44)
glow:SetPoint("CENTER", button, "TOPLEFT", 17, -15)
glow:SetTexture(ICONS .. "Fx_Glow")
glow:SetVertexColor(1, 0.82, 0.3)
glow:SetBlendMode("ADD")
glow:Hide()

local icon = button:CreateTexture(nil, "ARTWORK")
icon:SetSize(21, 21)
icon:SetPoint("TOPLEFT", 6, -5)
icon:SetTexture(ICONS .. "Minimap")

local border = button:CreateTexture(nil, "OVERLAY")
border:SetSize(53, 53)
border:SetPoint("TOPLEFT")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

-- (the badge: a little gold coin with the count, on the top right)
local badge = CreateFrame("Frame", nil, button)
badge:SetSize(16, 16)
badge:SetPoint("CENTER", button, "TOPLEFT", 27, -6)
badge:SetFrameLevel(button:GetFrameLevel() + 2)
local coin = badge:CreateTexture(nil, "ARTWORK")
coin:SetAllPoints()
coin:SetTexture(ICONS .. "Fx_Coin")
local count = badge:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
count:SetPoint("CENTER", 0, 0)
count:SetTextColor(0.25, 0.12, 0.02)
badge:Hide()

local function UpdatePosition()
    local angle = math.rad(KillTrackerDB.minimap.angle)
    local radius = Minimap:GetWidth() / 2 + 10
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

-- While dragging, follow the cursor around the minimap edge.
local function FollowCursor()
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    KillTrackerDB.minimap.angle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
    UpdatePosition()
end

-- What's waiting: chests (and whether one is a tribute), and a rank the button hasn't shown you yet.
local function Waiting()
    local chests, tribute = 0, false
    for key, n in pairs(ns.ChestCounts and (ns.ChestCounts()) or {}) do
        chests = chests + n
        if key == ns.TRIBUTE then tribute = true end
    end
    local rank = ns.GetRank and ns.GetRank().rank or 1
    local newRank = KillTrackerDB.minimap.rankSeen ~= nil and rank > KillTrackerDB.minimap.rankSeen
    return chests, tribute, newRank, rank
end

local pulse = 0
local pulser = CreateFrame("Frame")  -- (its own frame: the button's OnUpdate is for dragging)
local function Pulse(_, elapsed)
    pulse = pulse + elapsed
    glow:SetAlpha(0.35 + 0.35 * math.sin(pulse * 3))
end

-- The badge and the glow, from what's waiting (on login, and whenever your stats change).
function ns.RefreshMinimapButton()
    if not KillTrackerDB or not KillTrackerDB.minimap then return end
    if not ns.IsMember or not ns.IsMember() then badge:Hide() glow:Hide() return end
    local chests, tribute, newRank, rank = Waiting()
    if KillTrackerDB.minimap.rankSeen == nil then KillTrackerDB.minimap.rankSeen = rank end  -- (the first time: nothing new)
    badge:SetShown(chests > 0 or newRank)
    count:SetText(newRank and chests == 0 and "!" or (chests > 9 and "9+" or tostring(chests)))
    local shine = newRank or tribute
    glow:SetShown(shine)
    pulser:SetScript("OnUpdate", shine and Pulse or nil)
end

-- Opening the window counts as seeing the new rank.
local function Seen()
    if ns.GetRank then KillTrackerDB.minimap.rankSeen = ns.GetRank().rank end
    ns.RefreshMinimapButton()
end

button:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", FollowCursor)
end)
button:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
end)

button:SetScript("OnClick", function(_, mouse)
    if mouse == "RightButton" then
        ns.OpenPage("bounties")
    elseif IsShiftKeyDown() then
        ns.OpenPage("dreambed")
    else
        ns.ToggleUI()
    end
    Seen()
end)

-- The tooltip's lines for this week's bounties: each poster's progress, and the guild's claims.
local function BountyLines()
    if ns.RankLocked and ns.RankLocked("bounties") then return end
    local board = ns.GetPosterProgress and ns.GetPosterProgress()
    if not board then return end
    local parts = {}
    for _, p in ipairs(board.posters) do
        if not p.extra then
            local label = ns.POSTER_KIND_LABELS and ns.POSTER_KIND_LABELS[p.bounty.kind] or p.bounty.name
            parts[#parts + 1] = p.claimed and ("%s |cff40ff40done|r"):format(label) or ("%s %d/%d"):format(label, p.have or 0, p.goal)
        end
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("This week's bounties")
    for i = 1, #parts, 2 do
        GameTooltip:AddDoubleLine(parts[i], parts[i + 1] or "", 1, 1, 1, 1, 1, 1)
    end
    local guild = ns.GetGuildClaims and ns.GetGuildClaims()
    local last = ns.POSTER_MILESTONES and ns.POSTER_MILESTONES[#ns.POSTER_MILESTONES]
    if guild and last then
        GameTooltip:AddDoubleLine("Guild claims", ("%d / %d"):format(guild.total, ns.MilestoneClaims(last)), 0.8, 0.8, 0.8, 1, 1, 1)
    end
end

-- Guildmates online with SOLC (in your guild roster, online, and in your guildmates' stats).
local function OnlineWithSOLC()
    local names = {}
    for i = 1, GetNumGuildMembers and GetNumGuildMembers() or 0 do
        local name, _, _, _, _, _, _, _, online = GetGuildRosterInfo(i)
        if name and online and not (issecretvalue and issecretvalue(name)) then
            local plain = name:match("^[^-]+")
            if KillTrackerFriends[name] or KillTrackerFriends[plain] then names[#names + 1] = plain:match("^%S+") or plain end
        end
    end
    table.sort(names)
    return names
end

button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Sleepy Ogre Leisure Club")
    if not ns.IsMember or not ns.IsMember() then
        GameTooltip:AddLine("For the Sleepy Ogre Leisure Club's members.", 1, 1, 1, true)
    else
        -- (your Ogre Rank, and how far to the next)
        local current, nextRank, points = ns.GetRank()
        GameTooltip:AddDoubleLine(("Ogre Rank %d"):format(current.rank), current.title, 1, 0.82, 0.25, 1, 1, 1)
        if nextRank then
            GameTooltip:AddDoubleLine("Next rank", ("%d / %d points"):format(points, nextRank.points), 0.8, 0.8, 0.8, 1, 1, 1)
        end
        BountyLines()
        -- (what's waiting for you)
        local chests, tribute = Waiting()
        local waiting = {}
        if tribute then waiting[#waiting + 1] = "|cffffd100A tribute from the Ogre Godz!|r" end
        if chests > 0 then waiting[#waiting + 1] = ("%d chest%s in your Inventory"):format(chests, chests == 1 and "" or "s") end
        if not (ns.RankLocked and ns.RankLocked("dreambed")) and ns.Tokens then
            local stories, bonks = ns.Tokens("story"), ns.Bonks and ns.Bonks() or 0
            if stories + bonks > 0 then
                waiting[#waiting + 1] = ("%d Bedtime Stor%s, %d Bonk%s"):format(stories, stories == 1 and "y" or "ies", bonks, bonks == 1 and "" or "s")
            end
        end
        if #waiting > 0 then
            GameTooltip:AddLine(" ")
            for _, line in ipairs(waiting) do GameTooltip:AddLine(line, 1, 1, 1) end
        end
        -- (guildmates online with SOLC)
        local online = OnlineWithSOLC()
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(#online > 0 and ("Online: " .. table.concat(online, ", ")) or "No other club members online", 0.6, 0.9, 0.6, true)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Click: open  -  Right-click: Bounties  -  Shift-click: Bedroom", 0.6, 0.6, 0.6, true)
    GameTooltip:AddLine("Drag to move.", 0.6, 0.6, 0.6)
    GameTooltip:Show()
end)
button:SetScript("OnLeave", GameTooltip_Hide)

function ns.UpdateMinimapButton()
    UpdatePosition()
    button:SetShown(not KillTrackerDB.minimap.hide)
    ns.RefreshMinimapButton()
end

-- The minimap has its final size by PLAYER_LOGIN; the badge follows your stats (a kill, a chest, a rank).
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    ns.UpdateMinimapButton()
    C_Timer.After(12, ns.RefreshMinimapButton)  -- (the guild is known a bit after login)
end)
C_Timer.NewTicker(5, function() if button:IsShown() then ns.RefreshMinimapButton() end end)
