-- The details of an event in someone's feed, on the Overview's right page (OverviewCard.lua: click a row of ME's
-- feed; click it again or the close button to get the photo back). Over the top: art for the event (crayon scenes,
-- tools/make-overview-art.js: one per dungeon; for a dungeon SOLC doesn't know, the game's own art if any), the picture itself for a
-- picture, the creature's model for a leader or rare, the badge for a rank. A cross beam with its name, then what
-- there is to know: the traits, the points, when, who was there, a dungeon's bosses killed.
-- UI.FeedDetail(page) -> a frame with :ShowItem(item) (an item of ns.GetFeed: its event and source) and .event.

local _, ns = ...
local UI = ns.UI

local NAME_FONT = "Interface\\AddOns\\SOLC\\Media\\Fonts\\GermaniaOne-Regular.ttf"
local ART = "Interface\\AddOns\\SOLC\\Media\\Overview\\Feed\\"
local DUNGEON_ART = "Interface\\AddOns\\SOLC\\Media\\Overview\\Dungeons\\"  -- by dungeon key (Achievements.lua), upper case
local CLOSE_ICON = "Interface\\AddOns\\SOLC\\Media\\Icons\\Close"
local CREAM, GOLD, GREY = { 0.93, 0.88, 0.78 }, { 1, 0.82, 0.25 }, { 0.6, 0.57, 0.52 }
local YES, NO = "|cff55dd55+|r ", "|cff777777-  "

-- In window pixels: the art (from under the top beam to under the cross beam, wood to wood), the part of it that shows,
-- the cross beam's top, the text under it, the close button, the picture and the badge (their centres' y).
local D = {
    art = { top = 130, bottom = 430 }, shown = { left = 674, right = 1064, top = 146, bottom = 420 },
    beam = 420,
    body = { left = 692, top = 474, width = 356, bottom = 726, gap = 5 },
    close = { x = 1044, y = 166, size = 18 },
    picture = { size = 250, y = 283, rim = 3 },
    badge = { size = 150, y = 270 },
}
local MAX_LINES = 16

local function When(t) return date("%A %d %B %Y, %H:%M", t) end

-- The game's own art of a dungeon (its Encounter Journal picture, where the client has one), or nil.
local function DungeonArt(map)
    if not (map and EJ_GetInstanceForMap and EJ_GetInstanceInfo) then return end
    local ok, instanceID = pcall(EJ_GetInstanceForMap, map)
    if not ok or not instanceID or instanceID == 0 then return end
    local ok2, _, _, background, _, lore = pcall(EJ_GetInstanceInfo, instanceID)
    if ok2 then return lore or background end
end

-- What to show for an event: { art, title, lines = { { text, style } }, mint, npc, rank }. style: "head" (gold),
-- "dim" (grey, small), nil (cream).
local function Describe(item)
    local e, source = item.event, item.source or {}
    local kind, out = e.k, { lines = {} }
    local lines = out.lines
    local function Add(text, style) lines[#lines + 1] = { text, style } end

    if kind == "M" or kind == "W" then
        local mint = item.mint
        out.title, out.mint, out.owner = ("Picture #%s"):format(tostring(e.a)), mint, item.owner
        if mint then
            local rarity = ns.MintRarity(mint.traits, mint.asked)
            Add(("|c%s%s|r picture"):format(ns.RARITY_COLORS[rarity] or "ffffffff", (rarity:gsub("^%l", string.upper))), "head")
            for _, trait in ipairs(ns.MintTraits(mint.traits)) do
                Add(("%s:  |c%s%s|r%s"):format(trait[1], ns.RARITY_COLORS[trait[3]] or "ffffffff", trait[2], ns.TraitNote(trait)))
            end
        else
            Add("This picture has a new owner now.", "head")
        end
        Add(kind == "M" and ("Minted by %s"):format(item.who) or ("Won by %s from %s"):format(item.who, e.b or "someone"), "dim")
        Add(When(e.t), "dim")
        if mint then Add("Click the picture to open it.", "dim") end
    elseif kind == "A" then
        local name, detail, points = ns.AchievementInfo(e.a)
        local dungeon = ns.DungeonForAchievement and ns.DungeonForAchievement(e.a)
        out.art, out.title = dungeon and DUNGEON_ART .. dungeon.key:upper() or ART .. "ACHIEVEMENT", name
        if detail then Add(detail, "head") end
        if points then Add(("+%d points"):format(points)) end
        Add(("Earned by %s"):format(item.who), "dim")
        Add(When(e.t), "dim")
    elseif kind == "D" then
        local map = tonumber(e.c) or ns.BossMap(e.a)
        local dungeon = ns.DungeonForBoss(e.a, map)
        out.art = dungeon and DUNGEON_ART .. dungeon.key:upper() or DungeonArt(map) or ART .. "DUNGEON"
        out.title = dungeon and dungeon.name or tostring(e.a)
        Add(tonumber(e.b) == 1 and ("%s  |cffffd100- guild clear!|r"):format(tostring(e.a)) or tostring(e.a), "head")
        Add(When(e.t), "dim")
        if e.d then
            Add(("With %s and %s"):format((e.d:gsub(",", ", ")), item.who))
        else
            Add(("%s and guildmates (who was there wasn't kept back then)"):format(item.who))
        end
        local bosses = map and ns.DungeonBosses(map) or {}
        if #bosses > 0 then
            local down = 0
            for _, boss in ipairs(bosses) do
                local kill = source.kills and source.kills[boss[1]]
                boss.down = kill and (kill.count or 0) > 0
                if boss.down then down = down + 1 end
            end
            Add(("Bosses: %d of %d down"):format(down, #bosses), "head")
            for _, boss in ipairs(bosses) do Add((boss.down and YES or NO) .. boss[2] .. (boss.down and "" or "|r")) end
        end
    elseif kind == "L" or kind == "R" then
        local npcID = tonumber(e.a)
        local entry = source.kills and source.kills[npcID]
        out.art, out.npc = ART .. "CREATURE", npcID
        out.title = entry and entry.name or ("NPC " .. tostring(e.a))
        Add(kind == "L" and "A leader" or "A rare", "head")
        if entry and entry.count then Add(("Killed %d time%s by %s"):format(entry.count, entry.count == 1 and "" or "s", item.who)) end
        Add(("First slain %s"):format(When(e.t)), "dim")
    elseif kind == "K" then
        local rank = ns.RANKS and ns.RANKS[tonumber(e.a)]
        out.art, out.rank = ART .. "RANK", tonumber(e.a)
        out.title = rank and rank.title or "Ogre Rank"
        Add(("Ogre Rank %s"):format(tostring(e.a)), "head")
        if rank then Add(("At %d points earned"):format(rank.points)) end
        Add(("Reached by %s, %s"):format(item.who, When(e.t)), "dim")
        local unlocked = false
        for _, perk in ipairs(ns.RANK_PERKS or {}) do
            if perk.rank == tonumber(e.a) then
                if not unlocked then Add("Unlocked", "head") unlocked = true end
                Add(YES .. perk.text)
            end
        end
    elseif kind == "G" then  -- a gift from an officer (Dev.lua): a chest
        local dungeon = ns.DungeonByKey(tostring(e.b):match("^chest:(%w+)$") or "")
        out.title = (dungeon and dungeon.name or "A") .. " chest"
        -- (its dungeon as an ogre in its set; none known: the achievement art)
        local ogre = dungeon and ns.DungeonOgre and ns.DungeonOgre(dungeon.key)
        if ogre then out.mint, out.noOpen = { traits = ogre }, true else out.art = ART .. "ACHIEVEMENT" end
        Add(("A gift from %s"):format(tostring(e.a)), "head")
        Add(("For %s, to open in the gallery on the Overview"):format(item.owner and item.who or "you"))
        Add(When(e.t), "dim")
    elseif kind == "U" then  -- unlocked for minting (Unlocks.lua): one picture layer (a = its option key)
        local unlocked = ns.OptionByKey(e.a)
        local option, layer = unlocked and unlocked.option, unlocked and unlocked.layer
        local pool = option and option.unlock or ""
        local dungeon = ns.DungeonByKey(pool:match("^clear:(%w+)$") or pool:match("^chase:(%w+):") or "")
        out.title = option and option.name or "Unlocked"
        if option then  -- the piece itself, big, with your ogre wearing it (ns.TryOn) in a corner; not one to open
            out.piece = { layer = layer, option = option }
            out.mint, out.noOpen, out.rim = { traits = ns.TryOn(layer.key, option.id) }, true, option.rarity
        end
        if option then
            Add(("Unlocked for minting: |c%s%s %s|r"):format(ns.RARITY_COLORS[option.rarity] or "ffffffff", (option.rarity:gsub("^%l", string.upper)),
                layer.name:lower()), "head")
        end
        if dungeon then Add(("Out of a chest: %s"):format(dungeon.name))
        elseif pool:match("^loot:") then Add("For looting it") end
        Add(("It can roll in %s pictures now."):format(item.owner and item.who .. "'s" or "your"))
        Add(("Unlocked by %s, %s"):format(item.who, When(e.t)), "dim")
    elseif kind == "P" then
        local poster = ns.PosterBounty and ns.PosterBounty(e.a)
        out.art, out.title = ART .. "BOUNTY", poster and poster.name or "A bounty"
        Add("A bounty off the guild's board", "head")
        if poster and poster.desc then Add(poster.desc) end
        Add(("%s claimed it"):format(item.who))
        Add(When(e.t), "dim")
    elseif kind == "B" then
        local bounty = ns.ResolveBounty and ns.ResolveBounty(e.a)
        out.art, out.title = ART .. "BOUNTY", bounty and bounty.name or "A bounty"
        Add("The guild's weekly bounty", "head")
        if bounty and bounty.desc then Add(bounty.desc) end
        Add(("%s did their share"):format(item.who))
        Add(When(e.t), "dim")
    end
    out.title = out.title or ""
    return out
end

function UI.FeedDetail(page)
    local split = UI.SPLIT
    local function At(region, point, x, y) region:SetPoint(point, UI.window, "TOPLEFT", x, -y) end
    local detail = CreateFrame("Frame", nil, page)
    detail:SetAllPoints()
    detail:SetFrameLevel(page.photo:GetFrameLevel() + 5)
    detail:Hide()

    -- The board, and the art over its top, cropped to the part that shows (2:1 art).
    local board = detail:CreateTexture(nil, "BACKGROUND", nil, -8)
    At(board, "TOPLEFT", split.under.middle, split.under.top)
    board:SetPoint("BOTTOMRIGHT", UI.window, "TOPLEFT", split.under.right, -split.under.bottom)
    board:SetColorTexture(0.05, 0.03, 0.02)
    local artW, artH = split.under.right - split.under.middle, D.art.bottom - D.art.top
    detail.art = detail:CreateTexture(nil, "BACKGROUND", nil, -6)
    At(detail.art, "TOPLEFT", split.under.middle, D.art.top)
    detail.art:SetSize(artW, artH)
    local cut = (1 - artW / artH / 2) / 2
    detail.wideCoords = { cut, 1 - cut, 0, 1 }      -- 2:1 art: its middle
    detail.squareCoords = { 0, 1, 0, artH / artW }  -- square art (a picture's backdrop): its top, where the scene is
    detail.plain = detail:CreateTexture(nil, "BACKGROUND", nil, -6)  -- behind a picture: a plain dark glow
    detail.plain:SetAllPoints(detail.art)
    detail.plain:SetTexture("Interface\\Buttons\\WHITE8X8")
    detail.plain:SetGradient("VERTICAL", CreateColor(0.08, 0.06, 0.05, 1), CreateColor(0.24, 0.18, 0.13, 1))

    local hero = CreateFrame("Frame", nil, detail)  -- the shown part, for what goes over the art
    At(hero, "TOPLEFT", D.shown.left, D.shown.top)
    hero:SetSize(D.shown.right - D.shown.left, D.shown.bottom - D.shown.top)
    local middle = (D.shown.left + D.shown.right) / 2

    -- A creature's model (leaders and rares): drag to turn it.
    local model = CreateFrame("PlayerModel", nil, hero)
    model:SetAllPoints()
    model:EnableMouse(true)
    model.facing = 0
    model:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        local lastX = GetCursorPosition()
        self:SetScript("OnUpdate", function()
            local x = GetCursorPosition()
            self.facing = self.facing + (x - lastX) / 80
            lastX = x
            self:SetFacing(self.facing)
        end)
    end)
    model:SetScript("OnMouseUp", function(self) self:SetScript("OnUpdate", nil) end)
    model:SetScript("OnHide", function(self) self:SetScript("OnUpdate", nil) end)
    detail.model = model

    -- A picture (minted or won), on a rim in its rarity's colour; click to open it in the viewer.
    local picture = CreateFrame("Button", nil, hero)
    picture:SetSize(D.picture.size, D.picture.size)
    At(picture, "CENTER", middle, D.picture.y)
    picture.rim = picture:CreateTexture(nil, "BACKGROUND")
    picture.rim:SetPoint("TOPLEFT", -D.picture.rim, D.picture.rim)
    picture.rim:SetPoint("BOTTOMRIGHT", D.picture.rim, -D.picture.rim)
    picture.canvas = CreateFrame("Frame", nil, picture)
    picture.canvas:SetAllPoints()
    -- An unlock: the piece on a dark stage, a faint glow of its rarity behind it, and "on you" (your ogre wearing it)
    -- small in the corner.
    picture.stage = picture:CreateTexture(nil, "BORDER")
    picture.stage:SetAllPoints()
    picture.stage:SetColorTexture(0.06, 0.05, 0.05)
    picture.glow = picture:CreateTexture(nil, "ARTWORK")
    picture.glow:SetTexture("Interface\\AddOns\\SOLC\\Media\\Icons\\Fx_Glow")
    picture.glow:SetBlendMode("ADD")
    picture.glow:SetPoint("CENTER")
    picture.glow:SetSize(D.picture.size * 0.9, D.picture.size * 0.9)
    picture.glow:SetAlpha(0.22)
    picture.piece = CreateFrame("Frame", nil, picture)
    picture.piece:SetSize(D.picture.size * 0.78, D.picture.size * 0.78)
    picture.piece:SetPoint("CENTER", 0, 6)
    picture.inset = CreateFrame("Frame", nil, picture)
    picture.inset:SetSize(84, 84)
    picture.inset:SetPoint("BOTTOMRIGHT", 14, -14)
    picture.inset:SetFrameLevel(picture.piece:GetFrameLevel() + 2)
    picture.inset.rim = picture.inset:CreateTexture(nil, "BACKGROUND")
    picture.inset.rim:SetPoint("TOPLEFT", -2, 2)
    picture.inset.rim:SetPoint("BOTTOMRIGHT", 2, -2)
    picture.inset.canvas = CreateFrame("Frame", nil, picture.inset)
    picture.inset.canvas:SetAllPoints()
    picture.inset.label = picture.inset:CreateFontString(nil, "OVERLAY")
    picture.inset.label:SetFont(NAME_FONT, 12, "")
    picture.inset.label:SetTextColor(1, 0.93, 0.78)
    UI.OutlineText(picture.inset.label, { 0, 0, 0 })
    picture.inset.label:SetPoint("BOTTOM", picture.inset, "TOP", 0, 3)
    picture.inset.label:SetText("ON YOU")
    picture:SetScript("OnClick", function(self)
        if not self.mint then return end
        UI.ClickSound()
        ns.ShowMint(self.mint, self.owner and Ambiguate(self.owner, "short") or nil)
    end)
    picture:SetScript("OnEnter", function(self) if self.mint then UI.Tooltip(self, { "Click to open the picture" }) end end)
    picture:SetScript("OnLeave", GameTooltip_Hide)
    detail.picture = picture

    -- A rank's badge, its number on it.
    local badge = hero:CreateTexture(nil, "ARTWORK")
    badge:SetSize(D.badge.size, D.badge.size)
    At(badge, "CENTER", middle, D.badge.y)
    badge.number = hero:CreateFontString(nil, "OVERLAY")
    badge.number:SetFont(NAME_FONT, math.floor(D.badge.size * 0.3), "")
    badge.number:SetPoint("CENTER", badge, "CENTER", 0, D.badge.size * 0.15)
    UI.OutlineText(badge.number, { 0.12, 0.07, 0.03 })
    detail.badge = badge

    -- The cross beam with the name on it.
    detail.title = select(2, UI.PhotoBeam(detail, D.beam))

    -- Close: back to the photo.
    local close = CreateFrame("Button", nil, detail)
    close:SetFrameLevel(hero:GetFrameLevel() + 10)
    close:SetSize(D.close.size, D.close.size)
    At(close, "CENTER", D.close.x, D.close.y)
    close.art = close:CreateTexture(nil, "ARTWORK")
    close.art:SetAllPoints()
    close.art:SetTexture(CLOSE_ICON)
    close.art:SetAlpha(0.8)
    close:SetScript("OnEnter", function(self) self.art:SetAlpha(1) UI.Tooltip(self, { "Back to the photo" }) end)
    close:SetScript("OnLeave", function(self) self.art:SetAlpha(0.8) GameTooltip_Hide() end)
    close:SetScript("OnClick", function()
        UI.ClickSound()
        page.CloseDetail()
    end)

    -- The lines under the beam, each under the last (they can wrap); what doesn't fit is left out.
    detail.lines = {}
    for i = 1, MAX_LINES do
        local line = detail:CreateFontString(nil, "OVERLAY")
        line:SetWidth(D.body.width)
        line:SetJustifyH("LEFT")
        line:SetWordWrap(true)
        line:SetShadowOffset(1, -1)
        line:SetShadowColor(0, 0, 0, 0.9)
        detail.lines[i] = line
    end

    function detail:ShowItem(item)
        self.event = item.event
        local d = Describe(item)
        self.art:SetShown(d.art ~= nil)
        self.plain:SetShown(d.art == nil)
        if d.art then
            self.art:SetTexture(d.art)
            self.art:SetTexCoord(unpack(d.square and self.squareCoords or self.wideCoords))
        end

        picture:SetShown(d.mint ~= nil)
        picture.mint, picture.owner = not d.noOpen and d.mint or nil, d.owner
        local piece = d.piece
        picture.canvas:SetShown(not piece)
        picture.stage:SetShown(piece ~= nil)
        picture.glow:SetShown(piece ~= nil)
        picture.piece:SetShown(piece ~= nil)
        picture.inset:SetShown(piece ~= nil)
        if d.mint then
            local r, g, b = ns.RarityRGB(d.rim or ns.MintRarity(d.mint.traits, d.mint.asked))
            picture.rim:SetColorTexture(r, g, b)
            if piece then
                ns.DrawPiece(picture.piece, piece.layer.key, piece.option)
                picture.glow:SetVertexColor(r, g, b)
                picture.inset.rim:SetColorTexture(r, g, b)
                ns.DrawMint(picture.inset.canvas, d.mint)
            else
                ns.DrawMint(picture.canvas, d.mint)
            end
        end
        badge:SetShown(d.rank ~= nil)
        badge.number:SetShown(d.rank ~= nil)
        if d.rank then
            badge:SetTexture(UI.BadgeArt(d.rank))
            badge.number:SetText(d.rank)
        end
        model:SetShown(d.npc ~= nil)
        if d.npc then
            model:ClearModel()
            model:SetCreature(d.npc)
            model.facing = 0
            model:SetFacing(0)
        end

        UI.FitText(self.title, NAME_FONT, 20, 10, d.title, UI.PHOTO_NAME_WIDTH)
        local y = D.body.top
        for i, line in ipairs(self.lines) do
            local spec = d.lines[i]
            line:ClearAllPoints()
            if spec then
                local style = spec[2]
                line:SetFont(NAME_FONT, style == "head" and 16 or style == "dim" and 13 or 14, "")
                line:SetTextColor(unpack(style == "head" and GOLD or style == "dim" and GREY or CREAM))
                line:SetText(spec[1])
                if style == "head" and i > 1 then y = y + 6 end  -- a little room before a heading
                At(line, "TOPLEFT", D.body.left, y)
                y = y + line:GetStringHeight() + D.body.gap
            end
            line:SetShown(spec ~= nil and y <= D.body.bottom)
        end
        self:Show()
    end
    return detail
end
