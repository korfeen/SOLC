-- Painted cartridge cabinet. Cartridge insertion owns the power/boot lifecycle.
-- GAME: the cartridge's game, or nil while the club has none (no cartridge to drag: you need a game to play).
local _, ns = ...
local MEDIA="Interface\\AddOns\\SOLC\\Media\\GamesRoom\\"
local WHITE="Interface\\Buttons\\WHITE8X8"
local FONT="Interface\\AddOns\\SOLC\\Media\\Fonts\\GermaniaOne-Regular.ttf"
local shell, scene, screen, slot, glow, cartridge, ghost, status, eject, boot, title, ready, throat
local state, elapsed, dragX, dragY = "off", 0, 0, 0
local targetX, targetY, dragScale, reportedError
local SafeUpdate
local GAME = nil
local function Text(parent,size,text)
    local f=parent:CreateFontString(nil,"OVERLAY") f:SetFont(FONT,size,"")
    f:SetTextColor(.94,.83,.62) f:SetText(text or "") return f
end
local function Rect(parent,x,y,w,h,r,g,b,a)
    local t=parent:CreateTexture(nil,"ARTWORK") t:SetColorTexture(r,g,b,a or 1)
    t:SetPoint("TOPLEFT",x,-y) t:SetSize(w,h) return t
end
local function Button(parent,x,y,w,h,text,fn)
    local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
    b:SetPoint("TOPLEFT",x,-y) b:SetSize(w,h) b:SetText(text) b:SetScript("OnClick",fn) return b
end
local function Card(parent)
    local f=CreateFrame("Frame",nil,parent,"BackdropTemplate") f:SetSize(140,112)
    f:SetBackdrop({bgFile=WHITE,edgeFile=WHITE,edgeSize=2})
    f:SetBackdropColor(.10,.13,.09,1) f:SetBackdropBorderColor(.42,.4,.29,1)
    for x=5,132,7 do Rect(f,x,4,2,101,.16,.19,.13) end
    Rect(f,12,12,116,70,.44,.16,.13)
    local brand=Text(f,12,"S.O.L.C.") brand:SetPoint("TOP",0,-21)
    local name=Text(f,20,GAME or "") name:SetPoint("TOP",0,-39)
    local sub=Text(f,10,"CARTRIDGE") sub:SetPoint("TOP",0,-66)
    for x=30,108,6 do Rect(f,x,94,4,16,.72,.56,.25) end
    return f
end
local function Cursor()
    -- Same cursor space and tooltip-level ghost as the picture gallery.
    local x,y=GetCursorPosition() local scale=UIParent:GetEffectiveScale()
    return x/scale,y/scale
end
local function PositionGhost(x,y)
    ghost:ClearAllPoints()
    ghost:SetPoint("CENTER",UIParent,"BOTTOMLEFT",x/dragScale,y/dragScale)
end
local function Off()
    state,elapsed="off",0
    scene:SetScript("OnUpdate",nil)
    throat:Hide()
    ghost:Hide() cartridge:SetShown(GAME~=nil) glow:Hide() screen:Hide() eject:Show() eject:SetEnabled(false)
    cartridge:SetAlpha(1)
    title:Hide() ready:Hide() boot:Hide() status:SetText("No cartridge loaded")
end
local function Release()
    if state~="holding" then return end
    if slot:IsShown() and slot:IsMouseOver() then
        state,elapsed="inserting",0
        dragX,dragY=Cursor() cartridge:Hide()
        -- First align the contacts with the mouth; then slide behind its lip.
        local ratio=scene:GetEffectiveScale()/UIParent:GetEffectiveScale()
        targetX=(scene:GetLeft()+281.17)*ratio
        targetY=(scene:GetTop()-434)*ratio
        status:SetText("Inserting cartridge...")
    else Off() end
end
local function Eject()
    if state~="on" then return end
    state,elapsed="ejecting",0
    screen:Hide() title:Hide() ready:Hide() boot:Hide()
    eject:SetEnabled(false) cartridge:Hide() glow:Show()
    status:SetText("Ejecting cartridge...")
    ghost:SetParent(throat) ghost:SetFrameStrata(scene:GetFrameStrata())
    ghost:SetFrameLevel(throat:GetFrameLevel()+1)
    ghost:SetScale(1) ghost:SetAlpha(1)
    ghost:ClearAllPoints() ghost:SetPoint("CENTER",throat,"TOPLEFT",105,-205)
    throat:Show() ghost:Show()
    scene:SetScript("OnUpdate",SafeUpdate)
end
local function Update(_,dt)
    if state=="holding" then
        local x,y=Cursor() PositionGhost(x,y)
    elseif state=="inserting" then
        elapsed=elapsed+dt local t=math.min(1,elapsed/.65)
        if t<.45 then
            local ease=1-(1-t/.45)^3
            PositionGhost(dragX+(targetX-dragX)*ease,dragY+(targetY-dragY)*ease)
        else
            ghost:SetParent(throat) ghost:SetFrameStrata(scene:GetFrameStrata())
            ghost:SetFrameLevel(throat:GetFrameLevel()+1)
            ghost:SetScale(1) throat:Show()
            ghost:ClearAllPoints()
            ghost:SetPoint("CENTER",throat,"TOPLEFT",105,-(91+114*(t-.45)/.55))
        end
        if t==1 then
            state,elapsed="booting",0 ghost:Hide() throat:Hide() glow:Hide()
            screen:Show() boot:Show() status:SetText(("Starting %s..."):format(GAME or ""))
        end
    elseif state=="booting" then
        elapsed=elapsed+dt
        boot:SetAlpha(math.min(1,elapsed/.12))
        if elapsed>=.55 then
            state="on" boot:Hide() title:Show() ready:Show() eject:SetEnabled(true) eject:Show()
            scene:SetScript("OnUpdate",nil)
            status:SetText(("%s cartridge loaded"):format(GAME or ""))
        end
    elseif state=="ejecting" then
        elapsed=elapsed+dt
        if elapsed<.2 then
            -- Spring the cartridge up through the same clipped mouth it entered.
            local t=elapsed/.2
            ghost:ClearAllPoints()
            ghost:SetPoint("CENTER",throat,"TOPLEFT",105,-(205-114*t))
        elseif elapsed<1 then
            -- A toaster-like pop, then a soft landing in the cartridge tray.
            local t=(elapsed-.2)/.8
            local ratio=scene:GetEffectiveScale()/UIParent:GetEffectiveScale()
            local left,top=scene:GetLeft(),scene:GetTop()
            dragScale=ratio
            ghost:SetParent(UIParent) ghost:SetFrameStrata("TOOLTIP") ghost:SetScale(ratio)
            throat:Hide()
            local x=(left+281.17+(690-281.17)*t)*ratio
            local y=(top-434+(434-281)*t+4*155*t*(1-t))*ratio
            PositionGhost(x,y)
        else
            Off()
        end
    end
end
SafeUpdate=function(self,dt)
    local ok,err=pcall(Update,self,dt)
    if ok then return end
    -- Detach before cleanup so a failing animation can never flood the client.
    self:SetScript("OnUpdate",nil)
    Off()
    if not reportedError then
        reportedError=true
        if ns.Print then ns.Print("Arcade animation stopped: "..tostring(err)) end
    end
end
local function Build()
    shell=CreateFrame("Frame","SOLCArcade",UIParent,"BackdropTemplate")
    shell:SetBackdrop({bgFile=WHITE}) shell:SetBackdropColor(.025,.045,.025,1)
    shell:SetClipsChildren(true) shell:Hide() shell:EnableMouse(true)
    scene=CreateFrame("Frame",nil,shell) scene:SetSize(827,584) scene:EnableMouse(true)
    local art=scene:CreateTexture(nil,"BACKGROUND") art:SetAllPoints()
    art:SetTexture(MEDIA.."ArcadeBackdrop.blp")
    local shade=scene:CreateTexture(nil,"BACKGROUND",nil,1)
    shade:SetColorTexture(.015,.035,.025,.88)
    shade:SetPoint("TOPLEFT",562.36,0) shade:SetPoint("BOTTOMRIGHT")
    Button(scene,582,15,85,26,"< Room",function() shell:Hide() end)
    local heading=Text(scene,26,"THE ARCADE") heading:SetPoint("TOPLEFT",582,-75)
    status=Text(scene,14) status:SetPoint("TOPLEFT",582,-115) status:SetWidth(225) status:SetJustifyH("LEFT")
    local hint=Text(scene,14,GAME and "Drag a cartridge into the brass slot to turn it on."
        or "You need a game to play.\n\nThere are no game cartridges in the club yet.")
    hint:SetPoint("TOPLEFT",582,-155) hint:SetWidth(225) hint:SetJustifyH("LEFT")
    cartridge=Card(scene) cartridge:SetPoint("TOPLEFT",620,-225) cartridge:EnableMouse(true)
    throat=CreateFrame("Frame",nil,scene)
    throat:SetPoint("TOPLEFT",176.17,-343) throat:SetSize(210,150)
    throat:SetClipsChildren(true) throat:Hide()
    ghost=Card(UIParent) ghost:SetFrameStrata("TOOLTIP") ghost:EnableMouse(false) ghost:Hide()
    cartridge:RegisterForDrag("LeftButton")
    cartridge:SetScript("OnDragStart",function()
        if state~="off" then return end
        GameTooltip_Hide()
        state="holding" glow:Show() cartridge:SetAlpha(.3)
        dragScale=scene:GetEffectiveScale()/UIParent:GetEffectiveScale()
        ghost:SetParent(UIParent) ghost:SetFrameStrata("TOOLTIP")
        ghost:SetScale(dragScale) ghost:SetAlpha(1) ghost:Show()
        local x,y=Cursor() PositionGhost(x,y)
        status:SetText("Drop it into the glowing slot")
        scene:SetScript("OnUpdate",SafeUpdate)
    end)
    cartridge:SetScript("OnDragStop",Release)
    slot=CreateFrame("Frame",nil,scene)
    slot:SetPoint("TOPLEFT",179.95,-455.52) slot:SetSize(202.44,67.16)
    glow=CreateFrame("Frame",nil,slot,"BackdropTemplate")
    glow:SetPoint("TOPLEFT",-4,4) glow:SetPoint("BOTTOMRIGHT",4,-4)
    glow:SetBackdrop({bgFile=WHITE,edgeFile=WHITE,edgeSize=2})
    glow:SetBackdropColor(1,.73,.25,.12) glow:SetBackdropBorderColor(1,.78,.37,.9)
    local bloom=glow:CreateTexture(nil,"BACKGROUND") bloom:SetTexture("Interface\\AddOns\\SOLC\\Media\\DreamBed\\glow")
    bloom:SetAllPoints() bloom:SetVertexColor(1,.7,.25,.6) bloom:SetBlendMode("ADD")
    screen=CreateFrame("Frame",nil,scene)
    screen:SetPoint("TOPLEFT",124,-149) screen:SetSize(314,173)
    Rect(screen,0,0,314,173,.015,.08,.04)
    boot=screen:CreateTexture(nil,"OVERLAY") boot:SetColorTexture(.65,1,.7,1)
    boot:SetPoint("CENTER") boot:SetSize(280,2)
    title=Text(screen,27,GAME and GAME:upper() or "") title:SetPoint("CENTER",0,12) title:SetTextColor(.58,.94,.63)
    ready=Text(screen,13,"CARTRIDGE LOADED") ready:SetPoint("TOP",title,"BOTTOM",0,-12)
    -- Physical cabinet hardware, just to the right of the cartridge hatch.
    eject=CreateFrame("Button",nil,scene)
    eject:SetPoint("TOPLEFT",393,-472) eject:SetSize(34,34)
    local buttonArt=MEDIA.."ArcadeEject.blp"
    eject:SetNormalTexture(buttonArt) eject:GetNormalTexture():SetTexCoord(0,.25,0,1)
    eject:SetPushedTexture(buttonArt) eject:GetPushedTexture():SetTexCoord(.25,.5,0,1)
    eject:SetHighlightTexture(buttonArt,"BLEND") eject:GetHighlightTexture():SetTexCoord(.5,.75,0,1)
    eject:SetDisabledTexture(buttonArt) eject:GetDisabledTexture():SetTexCoord(.75,1,0,1)
    eject:SetScript("OnClick",Eject)
    eject:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
        GameTooltip:AddLine("Eject cartridge",1,.85,.5)
        GameTooltip:AddLine(state=="on" and "Pop the cartridge out." or "Insert a cartridge first.",.85,.8,.65)
        GameTooltip:Show()
    end)
    eject:SetScript("OnLeave",GameTooltip_Hide)
    local function Fit()
        if state=="holding" or state=="inserting" or state=="ejecting" then Off() end
        scene:SetScale(math.min(shell:GetWidth()/827,shell:GetHeight()/584))
        scene:ClearAllPoints() scene:SetPoint("CENTER",shell,"CENTER")
    end
    shell:SetScript("OnSizeChanged",Fit) shell:SetScript("OnShow",function() Off() Fit() end)
    shell:SetScript("OnHide",function() Off() if ns.UI.ClearScreen then ns.UI.ClearScreen("Arcade") end end)
    scene:EnableKeyboard(true)
    scene:SetScript("OnKeyDown",function(self,key)
        if not InCombatLockdown() then self:SetPropagateKeyboardInput(key~="ESCAPE") end
        if key=="ESCAPE" then shell:Hide() end
    end)
    ns.UI.CombatSafeKeys(scene)
    Off()
end
function ns.ShowArcade()
    if not shell then Build() end
    local area=ns.UI and ns.UI.pageArea
    shell:ClearAllPoints()
    if area then
        if not area:IsVisible() then ns.ToggleUI() end
        shell:SetParent(area) shell:SetAllPoints(area)
        shell:SetFrameStrata(area:GetFrameStrata()) shell:SetFrameLevel(area:GetFrameLevel()+50)
    else shell:SetParent(UIParent) shell:SetSize(827,584) shell:SetPoint("CENTER") end
    shell:Show()
    if ns.UI.SetScreen then ns.UI.SetScreen("Arcade","ARCADE",function() shell:Hide() end) end
end
