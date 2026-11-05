-- Reference and live painting on two easels. The existing canvas, tools timer,
-- scoring and saved-painting callbacks continue to own the game.
local _, ns = ...
local MEDIA="Interface\\AddOns\\SOLC_Puzzle\\Media\\Painting\\"
local WHITE="Interface\\Buttons\\WHITE8X8"
local function ControlFont(name,size,r,g,b)
    local font=CreateFont(name)
    font:SetFont("Interface\\AddOns\\SOLC\\Media\\Fonts\\GermaniaOne-Regular.ttf",size,"")
    font:SetTextColor(r,g,b) font:SetShadowColor(0,0,0,1) font:SetShadowOffset(1,-1)
    return font
end
local NORMAL=ControlFont("SOLCPaintControlNormal",16,.98,.9,.72)
local HOVER=ControlFont("SOLCPaintControlHover",16,1,.98,.87)
local DISABLED=ControlFont("SOLCPaintControlDisabled",16,.55,.55,.49)
local LARGE=ControlFont("SOLCPaintControlLarge",20,1,.94,.76)
function ns.CreatePaintingScene(page)
    local scene=CreateFrame("Frame",nil,page)
    scene:SetAllPoints() scene:SetFrameLevel(page:GetFrameLevel()+100) scene:EnableMouse(true)
    local content=CreateFrame("Frame",nil,scene) content:SetSize(827,584)
    local wall=content:CreateTexture(nil,"BACKGROUND") wall:SetAllPoints() wall:SetTexture(MEDIA.."Room.blp")
    local header=CreateFrame("Frame",nil,content)
    header:SetPoint("TOPLEFT") header:SetSize(827,52) header:SetFrameLevel(scene:GetFrameLevel()+24)
    local headerShade=header:CreateTexture(nil,"BACKGROUND") headerShade:SetAllPoints() headerShade:SetColorTexture(.025,.065,.04,.96)
    local function Text(parent,size,text)
        local t=parent:CreateFontString(nil,"OVERLAY")
        t:SetFont("Interface\\AddOns\\SOLC\\Media\\Fonts\\GermaniaOne-Regular.ttf",size,"")
        t:SetTextColor(.94,.84,.65) t:SetText(text or "") return t
    end
    local function Button(label,x,y,w,fn)
        local b=CreateFrame("Button",nil,content,"BackdropTemplate")
        b:SetPoint("TOPLEFT",x,-y) b:SetSize(w,36)
        b:SetBackdrop({bgFile=WHITE,edgeFile=WHITE,edgeSize=2})
        b:SetBackdropColor(.065,.095,.075,1) b:SetBackdropBorderColor(.58,.43,.22,1)
        local labelText=Text(b,16,"") labelText:SetPoint("CENTER") b:SetFontString(labelText)
        b:SetNormalFontObject(NORMAL) b:SetHighlightFontObject(HOVER) b:SetDisabledFontObject(DISABLED)
        b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square","ADD")
        b:SetPushedTextOffset(0,-1)
        b:SetText(label) b:SetScript("OnClick",fn) return b
    end
    local function Dock(x,y,w,h)
        local f=CreateFrame("Frame",nil,content,"BackdropTemplate")
        f:SetPoint("TOPLEFT",x,-y) f:SetSize(w,h)
        f:SetBackdrop({bgFile=WHITE,edgeFile=WHITE,edgeSize=1})
        f:SetBackdropColor(.025,.055,.038,.97) f:SetBackdropBorderColor(.45,.34,.19,1)
        f:SetFrameLevel(content:GetFrameLevel()+1)
        return f
    end
    local function Easel(x,label)
        local f=CreateFrame("Frame",nil,content)
        f:SetPoint("TOPLEFT",x,-14) f:SetSize(413.5,466)
        local aperture=CreateFrame("Frame",nil,f)
        aperture:SetPoint("TOPLEFT",74.0165,-57.318) aperture:SetSize(266.7,266.7)
        local clamp=CreateFrame("Frame",nil,f) clamp:SetFrameLevel(scene:GetFrameLevel()+30)
        clamp:SetPoint("TOPLEFT",177.805,-37.28) clamp:SetSize(57.89,25.63)
        local top=clamp:CreateTexture(nil,"ARTWORK") top:SetAllPoints()
        top:SetTexture(MEDIA.."Room.blp")
        top:SetTexCoord((x+177.805)/827,(x+235.695)/827,51.28/584,76.91/584)
        local caption=Text(header,18,label) caption:SetPoint("TOP",header,"TOPLEFT",x+206.75,-32)
        return aperture
    end
    local referenceHost=Easel(0,"Reference")
    local workHost=Easel(413.5,"Your painting")
    local reference=CreateFrame("Frame",nil,referenceHost) reference:SetAllPoints()
    local blank=Text(workHost,18,"Start when you're ready") blank:SetPoint("CENTER")
    Dock(62,356,288,158)
    Dock(475,348,291,166)
    local colourDock=Dock(350,78,124,336)
    local colourHeading=Text(colourDock,18,"Colours") colourHeading:SetPoint("TOP",0,-9)
    local room=Button("Games Room",16,8,108,function() scene:Hide() SOLC.OpenPage("games") end) room:SetParent(header)
    room:SetHeight(30)
    local pictureLabel=Text(header,15) pictureLabel:SetPoint("TOPLEFT",150,-13) pictureLabel:SetWidth(410)
    local result=Text(header,14) result:SetPoint("TOPLEFT",565,-11) result:SetWidth(245) result:SetHeight(28) result:SetJustifyH("RIGHT")
    local swatches={}
    for i=1,12 do
        local b=CreateFrame("Button",nil,content)
        b:SetFrameLevel(content:GetFrameLevel()+4)
        b:SetPoint("TOPLEFT",360+((i-1)%2)*58,-112-math.floor((i-1)/2)*48) b:SetSize(44,42)
        local edge=b:CreateTexture(nil,"BACKGROUND") edge:SetAllPoints() edge:SetColorTexture(.22,.25,.20,1)
        local outline=b:CreateTexture(nil,"BACKGROUND") outline:SetAllPoints() outline:SetColorTexture(1,.8,.35)
        local fill=b:CreateTexture(nil,"ARTWORK") fill:SetPoint("TOPLEFT",4,-4) fill:SetPoint("BOTTOMRIGHT",-4,4)
        b:SetScript("OnClick",function() if page.canvas:IsActive() then page.canvas.color=i end end)
        b:SetScript("OnEnter",function(self)
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
            GameTooltip:AddLine("Colour "..i,1,.9,.7)
            GameTooltip:AddLine(page.canvas:IsActive() and "Click to choose this colour." or "Start painting to use the palette.",.85,.8,.65)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave",GameTooltip_Hide)
        swatches[i]={button=b,outline=outline,fill=fill}
    end
    local brushes={}
    for i,item in ipairs({{"1","Fine"},{"2","Medium"},{"3","Broad"},{"fill","Fill"}})do
        local key=item[1]
        brushes[key]=Button(item[2],487+(i-1)*69,360,62,function()
            if not page.canvas:IsActive() then return end
            page.canvas.tool=key=="fill" and "fill" or "brush"
            if key~="fill" then page.canvas.brush=tonumber(key) end
        end)
        brushes[key]:SetHeight(40) brushes[key]:SetFrameLevel(content:GetFrameLevel()+4)
    end
    local start=Button("Start",487,412,267,function()
        if page.canvas:IsActive() then page.paintTools:Finish()
        else page:StartPractice() end
        scene:Refresh()
    end)
    start:SetHeight(42) start:SetNormalFontObject(LARGE) start:SetHighlightFontObject(LARGE)
    start:SetFrameLevel(content:GetFrameLevel()+4)
    local previous=Button("<",74,368,40,function() if not page.canvas:IsActive() then page:Pick(-1) end end)
    local nextPicture=Button(">",122,368,40,function() if not page.canvas:IsActive() then page:Pick(1) end end)
    local sizes={}
    for i,size in ipairs(ns.PAINT_SIZES)do
        sizes[size]=Button(("%dx%d"):format(size,size),180+(i-1)*76,368,68,function()
            if not page.canvas:IsActive() then page:SetGridSize(size) end
        end)
    end
    local styles={"painted","crayon","sketch"}
    local style=Button("Style",74,412,126,function()
        if page.canvas:IsActive() then return end
        local index=0 for i,key in ipairs(styles)do if key==page:PaintStyleKey(page:Picture())then index=i end end
        page.paintStyle=styles[index%#styles+1] page:Update()
    end)
    local duration=Button("Time",210,412,130,function()
        if page.canvas:IsActive() then return end
        local index=0 for i,seconds in ipairs(ns.PAINT_TIMES)do if seconds==page.paintTime then index=i end end
        page:SetPaintTime(ns.PAINT_TIMES[index%#ns.PAINT_TIMES+1])
    end)
    local clockHost=CreateFrame("Frame",nil,content) clockHost:SetFrameLevel(content:GetFrameLevel()+4)
    clockHost:SetPoint("TOPLEFT",487,-468) clockHost:SetSize(267,30)
    local clock=Text(clockHost,22) clock:SetAllPoints() clock:SetJustifyH("CENTER")
    local save=Button("Save painting",74,462,128,function() page:SaveLastPainting() scene:Refresh() end)
    Button("My paintings",212,462,128,function() scene:Hide() page:OpenPaintings() end)
    for _,b in ipairs({previous,nextPicture,style,duration,save})do b:SetFrameLevel(content:GetFrameLevel()+4)end
    for _,b in pairs(sizes)do b:SetFrameLevel(content:GetFrameLevel()+4)end
    local ownsCanvas=false
    local originalBackdrop=page.canvas:GetBackdrop()
    local paletteTraits,paletteSize,paletteStyle,previewPalette
    function scene:Refresh()
        local picture,list=page:Picture()
        local active=page.canvas:IsActive()
        local selected=page:PaintStyle(picture)
        if picture and (paletteTraits~=picture.traits or paletteSize~=page.paintSize or paletteStyle~=selected)then
            previewPalette=ns.PaintPalette(ns.PaintTarget(picture.traits,page.paintSize,selected))
            paletteTraits,paletteSize,paletteStyle=picture.traits,page.paintSize,selected
        end
        local palette=page.canvas:IsShown() and page.paintPalette or previewPalette or {}
        reference:SetShown(picture~=nil)
        if picture then
            if reference.drawn~=picture.traits or reference.style~=selected then
                SOLC.RenderPicture(reference,picture.traits,selected)
                reference.drawn,reference.style=picture.traits,selected
            end
            pictureLabel:SetText(("%s's #%d"):format(picture.owner or "Your",picture.number or 0))
        else pictureLabel:SetText("Mint a picture first.") end
        blank:SetShown(not page.canvas:IsShown())
        result:SetText(page.result:GetText() or "")
        previous:SetEnabled(not active and #list>1) nextPicture:SetEnabled(not active and #list>1)
        for size,b in pairs(sizes)do b:SetEnabled(not active) if size==page.paintSize then b:LockHighlight()else b:UnlockHighlight()end end
        local styleKey=page:PaintStyleKey(picture)
        style:SetEnabled(not active) style:SetText(({painted="Painted",crayon="Crayon",sketch="Sketch",mixed="Mixed"})[styleKey] or "Painted")
        duration:SetEnabled(not active) duration:SetText(("%ds"):format(page.paintTime))
        start:SetEnabled(picture~=nil) start:SetText(active and "Done" or (page.start:GetText()=="Again" and "Again" or "Start"))
        for i,s in ipairs(swatches)do
            local c=palette[i] s.button:SetShown(c~=nil) s.button:SetEnabled(active)
            if c then s.fill:SetColorTexture(c[1],c[2],c[3],1) end
            s.outline:SetShown(i==page.canvas.color)
        end
        for key,b in pairs(brushes)do
            b:SetEnabled(active)
            local selectedTool=page.canvas.tool=="fill" and key=="fill" or page.canvas.tool=="brush" and tostring(page.canvas.brush)==key
            if selectedTool then b:LockHighlight()else b:UnlockHighlight()end
            b:SetBackdropBorderColor(selectedTool and 1 or .58,selectedTool and .8 or .43,selectedTool and .35 or .22,1)
        end
        local remaining=page.paintTools:Remaining()
        clock:SetText(remaining and ("%ds left"):format(math.max(0,math.ceil(remaining))) or "")
        clock:SetTextColor(remaining and remaining<=10 and 1 or .94,remaining and remaining<=10 and .3 or .84,.5)
        save:SetEnabled(page.saveButton:IsEnabled())
    end
    local function Fit()
        local w,h=scene:GetWidth(),scene:GetHeight() if w<=0 or h<=0 then return end
        content:SetScale(math.min(w/827,h/584)) content:ClearAllPoints() content:SetPoint("CENTER")
    end
    function scene:Open()
        ownsCanvas=true
        page.canvas.paperColor={.94,.88,.76}
        page.canvas:SetParent(workHost) page.canvas:SetBackdrop(nil)
        page.canvas:SetScale(266.7/392) page.canvas:ClearAllPoints() page.canvas:SetPoint("TOPLEFT")
        page.canvas:SetFrameLevel(scene:GetFrameLevel()+8)
        self:Show() Fit() self:Refresh()
        local elapsed=0
        self:SetScript("OnUpdate",function(_,dt)
            elapsed=elapsed+dt if elapsed<.1 then return end elapsed=0
            self:Refresh()
        end)
    end
    scene:SetScript("OnSizeChanged",Fit)
    scene:SetScript("OnHide",function()
        scene:SetScript("OnUpdate",nil)
        if not ownsCanvas then return end ownsCanvas=false
        page:StopPainting()
        page.canvas:SetParent(page) page.canvas:SetScale(1) page.canvas:SetBackdrop(originalBackdrop)
        page.canvas.paperColor=nil
        page.canvas:SetBackdropColor(0,0,0,.9)
        page.canvas:ClearAllPoints() page.canvas:SetPoint("TOPLEFT",12,-50)
        page.canvas:SetFrameLevel(page:GetFrameLevel()+1)
    end)
    scene:Hide()
    return scene
end
