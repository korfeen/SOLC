-- Minimap button: left-click toggles the Sleepy Ogre Leisure Club window, drag to move it around the minimap.

local _, ns = ...

local button = CreateFrame("Button", "SOLCMinimapButton", Minimap)
button:SetSize(31, 31)
button:SetFrameStrata("MEDIUM")
button:SetFrameLevel(8)
button:RegisterForClicks("LeftButtonUp")
button:RegisterForDrag("LeftButton")
button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
button:Hide()

local background = button:CreateTexture(nil, "BACKGROUND")
background:SetSize(20, 20)
background:SetPoint("TOPLEFT", 7, -5)
background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")

local icon = button:CreateTexture(nil, "ARTWORK")
icon:SetSize(20, 20)
icon:SetPoint("TOPLEFT", 7, -5)
icon:SetTexture("Interface\\Icons\\INV_Misc_Bone_HumanSkull_01")
icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

local border = button:CreateTexture(nil, "OVERLAY")
border:SetSize(53, 53)
border:SetPoint("TOPLEFT")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

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

button:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", FollowCursor)
end)
button:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
end)

button:SetScript("OnClick", function() ns.ToggleUI() end)

button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Sleepy Ogre Leisure Club")
    GameTooltip:AddDoubleLine("Total kills", KillTrackerDB.total, nil, nil, nil, 1, 1, 1)
    GameTooltip:AddDoubleLine("This session", ns.GetSessionKills(), nil, nil, nil, 1, 1, 1)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Left-click to open, drag to move.", 0.6, 0.6, 0.6)
    GameTooltip:Show()
end)
button:SetScript("OnLeave", GameTooltip_Hide)

function ns.UpdateMinimapButton()
    UpdatePosition()
    button:SetShown(not KillTrackerDB.minimap.hide)
end

-- The minimap has its final size by PLAYER_LOGIN.
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", ns.UpdateMinimapButton)
