-- Minimap button: the club logo's sleeping ogre (MediaIconsMinimap, tools/make-minimap-icon.js). Left-click toggles
-- the Sleepy Ogre Leisure Club window; right-click a menu of its pages to open; drag to move it round the minimap. A badge
-- counts what's waiting (chests to open; "!" for a new rank not seen yet), and it glows while a new rank or an Ogre Godz
-- tribute waits. Its tooltip stays short: your Ogre Rank and what the badge is for.

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

-- The right-click menu: the sidebar pages you have, in its order - it fills up as your Ogre Rank opens more.
local function PageMenu(owner)
    if not MenuUtil then return ns.ToggleUI() end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle("Sleepy Ogre Leisure Club")
        for _, page in ipairs(ns.SidebarPages and ns.SidebarPages() or {}) do
            if not page.locked then root:CreateButton(page.label, function() ns.OpenPage(page.key) Seen() end) end
        end
        -- (your saved outfits: put one on straight away, Outfits.lua)
        local outfits = ns.Outfits and ns.Outfits() or {}
        if #outfits > 0 then
            local wear = root:CreateButton("Wear outfit")
            for i, outfit in ipairs(outfits) do wear:CreateButton(outfit.name, function() ns.WearOutfit(i) end) end
        end
    end)
end

button:SetScript("OnClick", function(self, mouse)
    if mouse == "RightButton" and ns.IsMember and ns.IsMember() then return PageMenu(self) end
    ns.ToggleUI()
    Seen()
end)

button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Sleepy Ogre Leisure Club")
    if ns.IsMember and ns.IsMember() then
        local current = ns.GetRank()
        GameTooltip:AddLine(("Ogre Rank %d: %s"):format(current.rank, current.title), 1, 1, 1)
        local chests, tribute, newRank = Waiting()
        if newRank then GameTooltip:AddLine("A new rank! Open to see it.", 1, 0.82, 0.25) end
        if tribute then GameTooltip:AddLine("A tribute from the Ogre Godz!", 1, 0.82, 0.25)
        elseif chests > 0 then GameTooltip:AddLine(("%d chest%s in your Inventory"):format(chests, chests == 1 and "" or "s"), 1, 0.82, 0.25) end
        GameTooltip:AddLine("Click: open   Right-click: pick a page", 0.6, 0.6, 0.6)
    else
        GameTooltip:AddLine("Click: open", 0.6, 0.6, 0.6)
    end
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
