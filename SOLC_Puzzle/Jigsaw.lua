-- A separate practice game; swap/sliding boards and duel messages keep their original rules.
local _, ns = ...
ns.JIGSAW_SIZES = { 16, 25, 36, 49, 64 }
local GRIDS = { [16] = {4,4}, [25] = {5,5}, [36] = {6,6}, [49] = {7,7}, [64] = {8,8} }
local MEDIA = "Interface\\AddOns\\SOLC_Puzzle\\Media\\Jigsaw\\"
local PAD = .18

-- Edges use -1=inset, 0=straight, 1=tab. Adjacent edges always complement.
function ns.JigsawGrid(count)
    local grid = GRIDS[count]
    if grid then return grid[1], grid[2] end
end
function ns.JigsawEdges(row, col, rows, cols)
    local function sign(r,c) return (r+c)%2 == 0 and -1 or 1 end
    return { row > 0 and -sign(row-1,col) or 0,
        col < cols-1 and sign(row,col) or 0,
        row < rows-1 and sign(row,col) or 0,
        col > 0 and -sign(row,col-1) or 0 }
end
function ns.JigsawMaskKey(edges)
    local key = 0
    for i=1,4 do key=key*3+edges[i]+1 end
    return key
end

function ns.CreateJigsawScene(parent, pictureProvider)
    local scene=CreateFrame("Frame",nil,parent)
    scene:SetAllPoints()
    scene:SetFrameLevel(parent:GetFrameLevel()+100)
    scene:EnableMouse(true)
    local tableFrame=CreateFrame("Frame",nil,scene)
    tableFrame:SetPoint("TOPLEFT")
    tableFrame:SetPoint("BOTTOMRIGHT",-178,0)
    local art=tableFrame:CreateTexture(nil,"BACKGROUND")
    art:SetAllPoints()
    art:SetTexture(MEDIA.."Table.blp")
    local right=CreateFrame("Frame",nil,scene,"BackdropTemplate")
    right:SetPoint("TOPLEFT",tableFrame,"TOPRIGHT")
    right:SetPoint("BOTTOMRIGHT")
    right:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8"})
    right:SetBackdropColor(.025,.075,.04,.98)
    local function Text(font,x,y,width)
        local text=right:CreateFontString(nil,"OVERLAY",font)
        text:SetPoint("TOPLEFT",x,-y)
        text:SetWidth(width or 150)
        text:SetJustifyH("LEFT")
        return text
    end
    local function Button(label,y,action)
        local b=CreateFrame("Button",nil,right,"UIPanelButtonTemplate")
        b:SetPoint("TOPLEFT",12,-y) b:SetSize(154,25) b:SetText(label)
        b:SetScript("OnClick",action)
        return b
    end
    Button("Back to puzzles",12,function() scene:Hide() parent:OpenBookshelf() end)
    Text("GameFontNormalLarge",12,54):SetText("Jigsaw")
    local label=Text("GameFontHighlightSmall",12,80)
    local preview=CreateFrame("Frame",nil,right)
    preview:SetSize(130,130) preview:SetPoint("TOPLEFT",12,-108)
    Text("GameFontNormalSmall",12,250):SetText("Pieces")
    local sizeButtons={}
    local count,playing,started,moves,placed=36,false,nil,0,0
    local pieces,drag={},nil
    local bw,bx,by,pw,ph,cols,rows
    local clock=Text("GameFontNormalLarge",12,328)
    local progress=Text("GameFontHighlight",12,356)
    local result=Text("GameFontHighlightSmall",12,380)
    local help=Text("GameFontDisableSmall",12,472)
    help:SetText("Drag pieces onto the mat. They settle when they fit.\n\nSizes change only this Jigsaw practice game.")
    local guide=CreateFrame("Frame",nil,tableFrame)
    guide:SetAlpha(.14) guide:Hide()
    local guideShown=false
    local startButton
    local currentPicture
    local function Position(piece,x,y)
        piece.x,piece.y=x,y
        piece:ClearAllPoints()
        piece:SetPoint("TOPLEFT",tableFrame,"TOPLEFT",x-pw*PAD,-y+ph*PAD)
    end
    local function Cursor()
        local x,y=GetCursorPosition()
        local scale=tableFrame:GetEffectiveScale()
        return x/scale-tableFrame:GetLeft(),tableFrame:GetTop()-y/scale
    end
    local function UpdateProgress()
        progress:SetText(("%d / %d pieces"):format(placed,count))
    end
    local function CancelDrag()
        if drag then drag:SetFrameLevel(scene:GetFrameLevel()+20+drag.id) end
        drag=nil
    end
    local function FinishDrop(piece)
        if drag~=piece then return end
        CancelDrag()
        moves=moves+1
        local dx,dy=piece.x-piece.tx,piece.y-piece.ty
        if dx*dx+dy*dy < (math.min(pw,ph)*.45)^2 then
            piece.placed=true placed=placed+1
            Position(piece,piece.tx,piece.ty)
            piece:SetFrameLevel(scene:GetFrameLevel()+3)
            piece:EnableMouse(false)
            UpdateProgress()
            if placed==count then
                playing=false
                local seconds=GetTime()-started
                clock:SetText(ns.FormatTime(seconds))
                SOLCPuzzleDB.best=SOLCPuzzleDB.best or {}
                local key="jigsaw"..count
                local best=SOLCPuzzleDB.best[key]
                if not best or seconds<best.time then
                    SOLCPuzzleDB.best[key]={time=seconds,moves=moves}
                    result:SetText("Solved - a new best!")
                else result:SetText("A lovely picture. Nicely done.") end
                startButton:SetText("Again")
            end
        end
    end
    local function Scatter(piece,index)
        local w,h=tableFrame:GetWidth(),tableFrame:GetHeight()
        local band=index%4
        local k=math.floor(index/4)
        local x,y
        if band==0 then x=w*(.06+(k%2)*.11) y=h*(.22+math.floor(k/2)*.065)
        elseif band==1 then x=w*(.08+(k%9)*.09) y=h*(.12+(math.floor(k/9))*.065)
        elseif band==2 then x=w*(.08+(k%9)*.09) y=h*(.82+(math.floor(k/9))*.065)
        else x=w*.87 y=h*(.21+(k%12)*.045) end
        Position(piece,math.max(pw*PAD,math.min(w-pw*(1+PAD),x)),math.max(ph*PAD,math.min(h-ph*(1+PAD),y)))
    end
    local function Build(start)
        CancelDrag()
        for _,piece in ipairs(pieces) do piece:Hide() end
        cols,rows=ns.JigsawGrid(count)
        local w,h=tableFrame:GetWidth(),tableFrame:GetHeight()
        bw=math.min(w*.55,h*.59) bx=w*.31 by=(h-bw)/2
        pw,ph=bw/cols,bw/rows
        guide:SetSize(bw,bw) guide:ClearAllPoints() guide:SetPoint("TOPLEFT",bx,-by)
        currentPicture=pictureProvider()
        if not currentPicture then playing=false result:SetText("Mint a picture first.") return end
        SOLC.RenderPicture(preview,currentPicture.traits,currentPicture.style)
        SOLC.RenderPicture(guide,currentPicture.traits,currentPicture.style)
        label:SetText(("%s's #%d"):format(currentPicture.owner or "Your",currentPicture.number or 0))
        playing=not not start placed=start and 0 or count moves=0 started=start and GetTime() or nil
        result:SetText("") clock:SetText("0:00.0")
        startButton:SetText(start and "Restart" or "Start")
        local order={} for id=1,count do order[id]=id end
        for i=count,2,-1 do local j=math.random(i) order[i],order[j]=order[j],order[i] end
        for index,id in ipairs(order) do
            local piece=pieces[id]
            if not piece then
                piece=CreateFrame("Button",nil,tableFrame)
                piece:SetClipsChildren(true)
                piece.picture=CreateFrame("Frame",nil,piece)
                piece.mask=piece.picture:CreateMaskTexture()
                piece.mask:SetAllPoints(piece)
                piece.masked={}
                piece.id=id
                piece:SetScript("OnMouseDown",function(self,button)
                    if button~="LeftButton" or not playing or self.placed then return end
                    local x,y=Cursor()
                    self.dx,self.dy=x-self.x,y-self.y
                    drag=self self:SetFrameLevel(scene:GetFrameLevel()+99)
                end)
                piece:SetScript("OnMouseUp",function(self) FinishDrop(self) end)
                pieces[id]=piece
            end
            piece:SetSize(pw*(1+2*PAD),ph*(1+2*PAD))
            local row,col=math.floor((id-1)/cols),(id-1)%cols
            piece.tx,piece.ty=bx+col*pw,by+row*ph
            piece.picture:SetSize(bw,bw)
            piece.picture:ClearAllPoints()
            piece.picture:SetPoint("TOPLEFT",-col*pw+pw*PAD,row*ph-ph*PAD)
            SOLC.RenderPicture(piece.picture,currentPicture.traits,currentPicture.style)
            piece.mask:SetTexture(MEDIA.."Mask"..ns.JigsawMaskKey(ns.JigsawEdges(row,col,rows,cols))..".blp","CLAMPTOBLACKADDITIVE","CLAMPTOBLACKADDITIVE")
            for _,texture in ipairs({piece.picture:GetRegions()}) do
                if texture:IsObjectType("Texture") and not texture:IsObjectType("MaskTexture") and not piece.masked[texture] then
                    texture:AddMaskTexture(piece.mask) piece.masked[texture]=true
                end
            end
            piece.placed=not start
            piece:EnableMouse(start)
            piece:SetFrameLevel(scene:GetFrameLevel()+(start and 20+id or 3))
            if start then Scatter(piece,index-1) else Position(piece,piece.tx,piece.ty) end
            piece:Show()
        end
        UpdateProgress()
        guide:SetShown(guideShown)
        for value,button in pairs(sizeButtons) do if value==count then button:LockHighlight() else button:UnlockHighlight() end end
    end
    for i,value in ipairs(ns.JIGSAW_SIZES) do
        local b=CreateFrame("Button",nil,right,"UIPanelButtonTemplate")
        b:SetSize(47,23) b:SetPoint("TOPLEFT",12+((i-1)%3)*53,-270-math.floor((i-1)/3)*27)
        b:SetText(value) b:SetScript("OnClick",function() count=value Build(false) end)
        sizeButtons[value]=b
    end
    startButton=Button("Start",410,function() Build(true) end)
    Button("Show / hide guide",442,function() guideShown=not guideShown guide:SetShown(guideShown) end)
    scene:SetScript("OnUpdate",function()
        if playing then clock:SetText(ns.FormatTime(GetTime()-started)) end
        if drag then local x,y=Cursor() Position(drag,math.max(0,math.min(tableFrame:GetWidth()-pw,x-drag.dx)),math.max(0,math.min(tableFrame:GetHeight()-ph,y-drag.dy))) end
    end)
    scene:SetScript("OnHide",function() CancelDrag() playing=false end)
    tableFrame:SetScript("OnSizeChanged",function() if scene:IsShown() and cols then Build(false) end end)
    function scene:Open() self:Show() Build(false) end
    scene:Hide()
    return scene
end
