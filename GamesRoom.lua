-- Step one: the painted overview. Focused artwork is migrated one game at a time.
-- Existing game screens are reached through the room without changing their rules.
local _, ns = ...
local MEDIA = "Interface\\AddOns\\SOLC\\Media\\GamesRoom\\"
local BLEED = 14
local STATIONS = {
    { key="puzzles", label="Puzzle cupboard", description="Find a picture to piece together.", x=.14,y=.04,w=.22,h=.55, mode="bookshelf" },
    { key="paint", label="Painting corner", description="A canvas, some colour, and no hurry.", x=0,y=.23,w=.19,h=.74, mode="paint" },
    { key="couronne", label="Couronne", description="A little aim, a little nerve.", x=.21,y=.52,w=.60,h=.47 },
    { key="arcade", label="Arcade cabinet", description="The club's cartridge cabinet.", x=.61,y=.14,w=.21,h=.45 },
    { key="claw", label="Claw machine", description="Something lovely behind the glass.", x=.82,y=.04,w=.18,h=.69 },
}

local function OpenStation(station)
    if station.mode then
        if SOLC and SOLC.OpenPuzzlePractice then SOLC.OpenPuzzlePractice(station.mode)
        else
            ns.Print("Enable SOLC Puzzle to use the puzzle cupboard and painting corner.")
        end
    elseif station.key=="couronne" and ns.ShowCouronne then ns.ShowCouronne()
    elseif station.key=="claw" and ns.ShowClaw then ns.ShowClaw()
    elseif station.key=="arcade" and ns.ShowArcade then ns.ShowArcade() end
end

ns.RegisterPage({
    key="games", label="Games", section="guild", order=5.5, bare=true,
    create=function(parent)
        local page=CreateFrame("Frame",nil,parent)
        page:SetAllPoints()
        local art=page:CreateTexture(nil,"BACKGROUND")
        art:SetPoint("TOPLEFT",-BLEED,BLEED)
        art:SetPoint("BOTTOMRIGHT",BLEED,-BLEED)
        art:SetTexture(MEDIA.."Overview.blp")
        page.art=art
        page.stations={}
        page.glows={}
        local function Layout()
            local w,h=page:GetWidth()+BLEED*2,page:GetHeight()+BLEED*2
            for _,station in ipairs(STATIONS) do
                local button=page.stations[station.key]
                button:ClearAllPoints()
                button:SetPoint("TOPLEFT",page,"TOPLEFT",station.x*w-BLEED,BLEED-station.y*h)
                button:SetSize(station.w*w,station.h*h)
                local glow=page.glows[station.key]
                if glow then
                    local r=ns.GamesRoomGlows[station.key]
                    glow:ClearAllPoints()
                    glow:SetPoint("TOPLEFT",page,"TOPLEFT",r.x*w-BLEED,BLEED-r.y*h)
                    glow:SetSize(r.w*w,r.h*h)
                end
            end
        end
        for _,station in ipairs(STATIONS) do
            -- Each station opens its native cabinet or game screen.
            local button=CreateFrame("Button",nil,page)
            button:EnableMouse(true)
            local mask=ns.GamesRoomGlows and ns.GamesRoomGlows[station.key]
            if mask then
                local glow=page:CreateTexture(nil,"OVERLAY")
                glow:SetTexture(MEDIA..mask.file..".blp")
                glow:SetBlendMode("ADD")
                glow:SetAlpha(0)
                glow.target,glow.opacity=0,0
                page.glows[station.key]=glow
            end
            button:SetFrameLevel(page:GetFrameLevel()+(station.key=="paint" and 4 or station.key=="couronne" and 3 or station.key=="puzzles" and 2 or 1))
            button:SetScript("OnEnter",function(self)
                for key,glow in pairs(page.glows) do glow.target=key==station.key and .85 or 0 end
                GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
                GameTooltip:AddLine(station.label,1,.85,.5)
                GameTooltip:AddLine(station.description,.85,.8,.65,true)
                GameTooltip:Show()
            end)
            local function Leave()
                local glow=page.glows[station.key]
                if glow then glow.target=0 end
                GameTooltip_Hide()
            end
            button:SetScript("OnLeave",Leave)
            button:SetScript("OnHide",Leave)
            button:SetScript("OnClick",function() OpenStation(station) end)
            page.stations[station.key]=button
        end
        page:SetScript("OnSizeChanged",Layout)
        page:SetScript("OnShow",Layout)
        page:SetScript("OnUpdate",function(_,elapsed)
            local step=math.min(elapsed/.12,1)
            for _,glow in pairs(page.glows) do
                if math.abs(glow.opacity-glow.target)>.005 then
                    glow.opacity=glow.opacity+(glow.target-glow.opacity)*step
                    glow:SetAlpha(glow.opacity)
                elseif glow.opacity~=glow.target then glow.opacity=glow.target glow:SetAlpha(glow.opacity) end
            end
        end)
        page:SetScript("OnHide",function()
            for _,glow in pairs(page.glows) do glow.target,glow.opacity=0,0 glow:SetAlpha(0) end
            GameTooltip_Hide()
        end)
        Layout()
        return page
    end,
    refresh=function() end,
})
