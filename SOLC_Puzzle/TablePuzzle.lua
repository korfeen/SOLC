-- Swap and Sliding on the same overhead table as Jigsaw.
-- Reuse the page's board, scoring callbacks and replay recording.
local _, ns = ...
local MEDIA="Interface\\AddOns\\SOLC_Puzzle\\Media\\Jigsaw\\"
local function SlidingTray(board)
    local tray=CreateFrame("Frame",nil,board)
    tray:SetAllPoints() tray:EnableMouse(false)
    tray.slices={}
    -- Eight independent edges keep the rim thick and the aperture exactly on
    -- the tile edges, even when Board.lua rounds each grid to screen pixels.
    local function Slice(u0,u1,v0,v1)
        local t=tray:CreateTexture(nil,"OVERLAY")
        t:SetTexture(MEDIA.."SlidingFrame.blp") t:SetTexCoord(u0,u1,v0,v1)
        tray.slices[#tray.slices+1]=t return t
    end
    local cut=32/512
    for _,corner in ipairs({
        {"TOPLEFT",-24,24,0,cut,0,cut},
        {"TOPRIGHT",-4,24,1-cut,1,0,cut},
        {"BOTTOMLEFT",-24,4,0,cut,1-cut,1},
        {"BOTTOMRIGHT",-4,4,1-cut,1,1-cut,1},
    })do
        local t=Slice(corner[4],corner[5],corner[6],corner[7])
        t:SetPoint("TOPLEFT",board,corner[1],corner[2],corner[3]) t:SetSize(28,28)
    end
    local top=Slice(cut,1-cut,0,cut)
    top:SetPoint("TOPLEFT",board,"TOPLEFT",4,24) top:SetPoint("BOTTOMRIGHT",board,"TOPRIGHT",-4,-4)
    local bottom=Slice(cut,1-cut,1-cut,1)
    bottom:SetPoint("TOPLEFT",board,"BOTTOMLEFT",4,4) bottom:SetPoint("BOTTOMRIGHT",board,"BOTTOMRIGHT",-4,-24)
    local left=Slice(0,cut,cut,1-cut)
    left:SetPoint("TOPLEFT",board,"TOPLEFT",-24,-4) left:SetPoint("BOTTOMRIGHT",board,"BOTTOMLEFT",4,4)
    local right=Slice(1-cut,1,cut,1-cut)
    right:SetPoint("TOPLEFT",board,"TOPRIGHT",-4,-4) right:SetPoint("BOTTOMRIGHT",board,"BOTTOMRIGHT",24,4)
    tray:Hide()
    return tray
end
function ns.CreateTablePuzzleScene(page)
    local scene=CreateFrame("Frame",nil,page)
    scene:SetAllPoints() scene:SetFrameLevel(page:GetFrameLevel()+100)
    scene:EnableMouse(true)
    local tabletop=CreateFrame("Frame",nil,scene)
    tabletop:SetPoint("TOPLEFT") tabletop:SetPoint("BOTTOMRIGHT",-178,0)
    local art=tabletop:CreateTexture(nil,"BACKGROUND") art:SetAllPoints() art:SetTexture(MEDIA.."Table.blp")
    local right=CreateFrame("Frame",nil,scene,"BackdropTemplate")
    right:SetPoint("TOPLEFT",tabletop,"TOPRIGHT") right:SetPoint("BOTTOMRIGHT")
    right:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8"}) right:SetBackdropColor(.025,.075,.04,.98)
    local function Text(font,x,y,width)
        local t=right:CreateFontString(nil,"OVERLAY",font)
        t:SetPoint("TOPLEFT",x,-y) t:SetWidth(width or 154) t:SetJustifyH("LEFT") return t
    end
    local function Button(text,x,y,w,fn)
        local b=CreateFrame("Button",nil,right,"UIPanelButtonTemplate")
        b:SetPoint("TOPLEFT",x,-y) b:SetSize(w or 154,24) b:SetText(text) b:SetScript("OnClick",fn) return b
    end
    Button("Puzzle cupboard",12,12,154,function() scene:Hide() page:OpenBookshelf() end)
    local heading=Text("GameFontNormalLarge",12,52)
    local modes={}
    modes.swap=Button("Swap",12,80,74,function() page:OpenTablePuzzle("swap") end)
    modes.sliding=Button("Sliding",92,80,74,function() page:OpenTablePuzzle("sliding") end)
    Button("Jigsaw",12,110,154,function()
        scene:Hide()
        if not page.jigsaw then page.jigsaw=ns.CreateJigsawScene(page,function() return page:Picture() end) end
        page.jigsaw:Open()
    end)
    local preview=CreateFrame("Frame",nil,right)
    preview:SetSize(112,112) preview:SetPoint("TOPLEFT",33,-150)
    local pictureLabel=Text("GameFontHighlightSmall",12,270)
    local previous=Button("< Picture",12,304,74,function() page:Pick(-1) scene:Refresh() end)
    local nextPicture=Button("Picture >",92,304,74,function() page:Pick(1) scene:Refresh() end)
    Text("GameFontNormalSmall",12,340):SetText("Grid size")
    local sizes={}
    for i,size in ipairs(ns.SIZES)do
        sizes[size]=Button(("%dx%d"):format(size,size),12+(i-1)*53,360,48,function() page:SetGridSize(size) scene:Refresh() end)
    end
    local start=Button("Start",12,398,154,function() page:StartPractice() scene:Refresh() end)
    local clock=Text("GameFontNormalLarge",12,436)
    local moves=Text("GameFontHighlightSmall",12,462)
    local result=Text("GameFontHighlightSmall",12,485)
    local save=Button("Save replay",12,528,74,function() page:SaveLastRun() scene:Refresh() end)
    Button("My replays",92,528,74,function() scene:Hide() page:OpenReplays() end)
    local help=tabletop:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    help:SetPoint("TOPLEFT",18,-18) help:SetPoint("RIGHT",tabletop,"RIGHT",-18,0) help:SetJustifyH("LEFT")
    local best=tabletop:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    best:SetPoint("BOTTOMLEFT",18,18) best:SetPoint("RIGHT",tabletop,"RIGHT",-18,0) best:SetJustifyH("LEFT")
    local ownsBoard=false
    local slidingTray=SlidingTray(page.board)
    scene.slidingTray=slidingTray
    local function Layout()
        if not ownsBoard then return end
        local w,h=tabletop:GetWidth(),tabletop:GetHeight()
        if w<=0 or h<=0 then return end
        local side=math.min(w*.55,h*.59)
        -- Keep the logical board scale stable while Board.lua rounds its cuts to pixels.
        local scale=side/392
        page.board:SetScale(scale) page.board:ClearAllPoints()
        page.board:SetPoint("TOPLEFT",tabletop,"TOPLEFT",w*.31/scale,-(h-side)/2/scale)
    end
    function scene:Refresh()
        Layout()
        slidingTray:SetShown(ownsBoard and page.mode=="sliding")
        local picture,list=page:Picture()
        heading:SetText(page.mode=="sliding" and "Sliding puzzle" or "Swap pieces")
        help:SetText(page.mode=="sliding" and "Slide a piece into the gap. Arrow keys work too."
            or "Choose two pieces to swap. Arrow keys and Space work too.")
        preview:SetShown(picture~=nil)
        if picture then
            if preview.drawn~=picture.traits or preview.style~=picture.style then
                SOLC.RenderPicture(preview,picture.traits,picture.style)
                preview.drawn,preview.style=picture.traits,picture.style
            end
            pictureLabel:SetText(("%s's #%d"):format(picture.owner or "Your",picture.number or 0))
        else pictureLabel:SetText("Mint a picture first.") end
        previous:SetEnabled(#list>1) nextPicture:SetEnabled(#list>1)
        start:SetEnabled(picture~=nil) start:SetText(page.start:GetText())
        clock:SetText(page.clock:GetText() or "0:00.0")
        moves:SetText(page.movesText:GetText() or "") result:SetText(page.result:GetText() or "")
        best:SetText(page.bestText:GetText() or "")
        save:SetEnabled(page.saveButton:IsEnabled())
        for key,b in pairs(modes)do if key==page.mode then b:LockHighlight()else b:UnlockHighlight()end end
        for size,b in pairs(sizes)do if size==page.size then b:LockHighlight()else b:UnlockHighlight()end end
    end
    function scene:Open()
        ownsBoard=true
        page.board:SetParent(tabletop) page.board:SetFrameLevel(scene:GetFrameLevel()+4)
        slidingTray:SetFrameLevel(page.board:GetFrameLevel()+8)
        self:Show() Layout() page:ShowPicture() self:Refresh()
        local elapsed=0
        self:SetScript("OnUpdate",function(_,dt)
            elapsed=elapsed+dt if elapsed<.05 then return end elapsed=0
            clock:SetText(page.clock:GetText() or "0:00.0")
            moves:SetText(page.movesText:GetText() or "") result:SetText(page.result:GetText() or "")
            start:SetText(page.start:GetText()) save:SetEnabled(page.saveButton:IsEnabled())
        end)
    end
    scene:SetScript("OnHide",function()
        scene:SetScript("OnUpdate",nil)
        slidingTray:Hide()
        if not ownsBoard then return end
        ownsBoard=false page:StopPractice()
        page.board:SetParent(page) page.board:SetScale(1)
        page.board:SetFrameLevel(page:GetFrameLevel()+1)
        page.board:ClearAllPoints() page.board:SetPoint("TOPLEFT",12,-50)
        page:ShowPicture()
    end)
    tabletop:SetScript("OnSizeChanged",Layout)
    scene:Hide()
    return scene
end
