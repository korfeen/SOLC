-- The new Overview, being built: shown instead of the Overview while the WIP button under the sidebar is on
-- (KillTrackerDB.wipOverview). An open book of wooden boards. On its left page: plaques with their points,
-- achievements and kills, their showcase pictures on three small tilted polaroids, and what happened to them lately.
-- On its right page a character card, with a GEARZ button under it for their gear:
-- the name bar (arrows to step through you and your synced guildmates), a polaroid with the character's model
-- on the background they picked, icons for their race, gender, class and professions on the photo, and their
-- name written under it. The book and the card are the designer's own drawing (Media/Overview/Inside, from
-- tools/convert-overview.js); the live parts go on its spots, placed by OverviewLayout.lua
-- (tools/overview-layout.js) in window coordinates.
-- The gender icon follows the character unless they pick one (right-click it on your own card), and the photo can
-- show one of their pictures instead of their model (right-click your own photo); when there's no model of someone
-- to show (their character isn't synced), their chosen picture shows, else their first showcase picture, else their
-- newest.
-- KillTrackerDB.card = { gender = "MALE" | "FEMALE" | "NONBINARY", portrait = picture number, seq }, synced
-- (Sync.lua, the card section).

local _, ns = ...
local UI = ns.UI
local LAYOUT = ns.OverviewLayout
if not LAYOUT then return end

local ART = "Interface\\AddOns\\SOLC\\Media\\Overview\\"
local ICONS = ART .. "Icons\\"
local NAME_FONT = "Interface\\AddOns\\SOLC\\Media\\Fonts\\GermaniaOne-Regular.ttf"
local SIGN_FONT = "Interface\\AddOns\\SOLC\\Media\\Fonts\\FingerPaint-Regular.ttf"
local NAME_SIZE, SIGN_SIZE = 15, 40          -- at most; a longer name is written smaller to fit
local NAME_COLOR = { 0.95, 0.92, 0.85 }
local INK = { 0.16, 0.16, 0.18 }            -- the signature's crayon
local ARROW_LIT, ARROW_GROW = 0.45, 1.05     -- the light over a hovered arrow: strength, size
local EMPTY_SHAPE = 0.45                     -- an empty icon shape (nothing known yet) is drawn this faint
local STAT_SIZE, GEAR_SIZE = 17, 26          -- the stat plaques' numbers, the GEARZ button's word (at most)
local STAT_COLOR = { 1, 1, 1 }
local FEED_COLOR, FEED_TIME_COLOR = { 0.93, 0.88, 0.78 }, { 0.72, 0.6, 0.36 }  -- cream, muted gold
local FEED_STRIPE, FEED_HOVER = 0.035, 0.08  -- every other row a touch lighter; the row under the mouse lighter still
-- The small icon at the start of a line, by the event's kind (Feed.lua); a picture's line shows the picture itself.
local FEED_ICON = "Interface\\AddOns\\SOLC\\Media\\Icons\\Feed_"  -- the feed's own crayon icons (tools/make-role-icons.js)
local FEED_ICONS = {
    L = "Leader",       -- a leader slain
    R = "Rare",         -- a rare found
    A = "Achievement",
    M = "Mint",         -- a picture minted (shown as the picture itself while they still have it)
    W = "Won",          -- a picture won in a puzzle race
    B = "Bounty",
    D = "Boss",         -- a boss with the guild
}
local GEAR_COLOR = { 1, 0.78, 0.1 }
local TEXT_OUTLINE = { 0.12, 0.07, 0.03 }    -- dark brown round the light text on the boards (ns.UI.OutlineText)
local DATE_COLOR = { 0.3, 0.3, 0.32 }
local RARITY_EDGE, EDGE_FILL = 1.5, 60 / 64  -- the rarity colour round a small polaroid's picture; Media/Overview/Edge's square
local GEAR_PANEL = { left = 214, top = 56, width = 324, height = 522 }  -- the gear over the left page (window pixels)
-- The Ogre Rank badge (Ranks.lua): a sticker on the polaroid's top-left corner (window pixels), tilted; the badge art
-- per five ranks (Media/Icons/Rank_1..7, tools/make-role-icons.js). Clicking it shows the rank over the left page.
local RANK_BADGE = { x = 638, y = 142, size = 46, tilt = -12 }
local RANK_ICON = "Interface\\AddOns\\SOLC\\Media\\Icons\\Rank_"
local RANK_LINES = 18  -- perk lines in the rank panel
local function BadgeArt(rank) return RANK_ICON .. (rank >= 30 and 7 or math.floor(rank / 5) + 1) end

local issecret = issecretvalue or function() return false end
local function Readable(value) if not issecret(value) then return value end end
local function IconKey(text) return text and (text:upper():gsub("[^A-Z]", "")) end

-- Icons there's art for (Media/Overview/Icons/<kind>_<key>).
local RACES = { HUMAN = true, DWARF = true, NIGHTELF = true, GNOME = true, SKYBORNE = true }
local CLASSES = { DRUID = true, HUNTER = true, MAGE = true, PALADIN = true, PRIEST = true, ROGUE = true, SHAMAN = true,
    WARLOCK = true, WARRIOR = true }
local PROFESSIONS = { [171] = "ALCHEMY", [164] = "BLACKSMITHING", [333] = "ENCHANTING", [202] = "ENGINEERING",
    [182] = "HERBALISM", [165] = "LEATHERWORKING", [186] = "MINING", [393] = "SKINNING", [197] = "TAILORING" }
local SECONDARY = { { line = 185, key = "COOKING" }, { line = 356, key = "FISHING" }, { line = 129, key = "FIRSTAID" } }
local GENDERS = { MALE = "Male", FEMALE = "Female", NONBINARY = "Nonbinary" }
local GENDER_ORDER = { "MALE", "FEMALE", "NONBINARY" }
local SEX_GENDER = { [2] = "MALE", [3] = "FEMALE" }  -- UnitSex

-- What the card shows for someone: you (key nil) or a synced guildmate.
local function Profile(key)
    local p = { key = key }
    if key then
        local friend = KillTrackerFriends[key]
        local gear = friend and friend.gear
        p.name = key
        if gear then
            local info = gear.race and gear.race > 0 and C_CreatureInfo and C_CreatureInfo.GetRaceInfo(gear.race)
            if info then p.raceName, p.raceFile = info.raceName, info.clientFileString end
            p.classFile, p.sex, p.level = gear.class, gear.sex, gear.level
        end
        p.chosenGender = friend and friend.card and friend.card.gender
        p.portrait = friend and friend.card and friend.card.portrait
    else
        p.name = ns.MyName()
        p.raceName, p.raceFile = Readable(UnitRace("player")), Readable(select(2, UnitRace("player")))
        p.classFile = Readable(select(2, UnitClass("player")))
        p.sex, p.level = Readable(UnitSex("player")), Readable(UnitLevel("player"))
        p.chosenGender = KillTrackerDB.card and KillTrackerDB.card.gender
        p.portrait = KillTrackerDB.card and KillTrackerDB.card.portrait
    end
    p.gender = GENDERS[p.chosenGender or ""] and p.chosenGender or SEX_GENDER[p.sex]
    p.race = RACES[IconKey(p.raceFile) or ""] and IconKey(p.raceFile) or RACES[IconKey(p.raceName) or ""] and IconKey(p.raceName)
    p.className = p.classFile and LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[p.classFile] or p.classFile
    -- Professions: the two main ones (highest skill first), and the secondary ones they know.
    p.professions, p.secondary = {}, {}
    for _, prof in ipairs(ns.GetProfessions(key).list) do
        local icon = PROFESSIONS[prof.line]
        if icon then
            p.professions[#p.professions + 1] = { icon = icon, prof = prof }
        else
            for _, s in ipairs(SECONDARY) do
                if s.line == prof.line then p.secondary[s.key] = prof end
            end
        end
    end
    table.sort(p.professions, function(a, b) return (a.prof.rank or 0) > (b.prof.rank or 0) end)
    return p
end

-- Your gender icon: chosen, or back to following your character (nil).
local function ChooseGender(gender)
    KillTrackerDB.card = KillTrackerDB.card or {}
    KillTrackerDB.card.gender = gender
    ns.Touch(KillTrackerDB.card)
    ns.OpenPage("overview")
end

-- The picture shown on your photo instead of your model: a picture number, or nil for your model.
local function ChoosePortrait(number)
    KillTrackerDB.card = KillTrackerDB.card or {}
    KillTrackerDB.card.portrait = number
    ns.Touch(KillTrackerDB.card)
    ns.OpenPage("overview")
end

-- Right-clicking your own photo: what it shows (your model or one of your pictures) and the background behind your
-- model (from the ones on your pictures).
local function PhotoMenu(owner)
    if not MenuUtil then return UI.PickBackdrop(owner) end  -- no menus: step through the backgrounds
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle("Photo")
        local chosen = KillTrackerDB.card and KillTrackerDB.card.portrait
        root:CreateRadio("My character", function() return chosen == nil end, function() ChoosePortrait(nil) end)
        local mints = KillTrackerDB.mints or {}
        for _, mint in ipairs(mints) do
            local name = ("|c%s%s|r"):format(ns.RARITY_COLORS[ns.MintRarity(mint.traits)] or "ffffffff", ("Picture #%d"):format(mint.number))
            root:CreateRadio(name, function() return chosen == mint.number end, function() ChoosePortrait(mint.number) end)
        end
        if #mints == 0 then root:CreateTitle("Mint a picture to show one here") end
        local background = root:CreateButton("Background behind my character")
        local function IsCurrent(id) return (KillTrackerDB.showcase and KillTrackerDB.showcase.backdrop) == id end
        background:CreateRadio("None", function() return IsCurrent(nil) end, function() ns.SetModelBackdrop(nil) end)
        local owned = ns.OwnedBackgrounds()
        for _, option in ipairs(owned) do
            local name = ("|c%s%s|r"):format(ns.RARITY_COLORS[option.rarity] or "ffffffff", option.name)
            background:CreateRadio(name, function() return IsCurrent(option.id) end, function() ns.SetModelBackdrop(option.id) end)
        end
        if #owned == 0 then background:CreateTitle("Mint a picture to get backgrounds") end
    end)
end

-- Writes text as big as fits in width (from size down to smallest). The text is cleared first: a font string
-- whose text didn't change can report the width it had in an earlier font.
local function Fit(fontString, font, size, smallest, text, width)
    fontString:SetFont(font, size, "")
    fontString:SetText("")
    fontString:SetText(text)
    while size > smallest and fontString:GetStringWidth() > width do
        size = size - 1
        fontString:SetFont(font, size, "")
    end
end

local function SetTooltip(owner, lines)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    for i, line in ipairs(lines) do
        if i == 1 then GameTooltip:AddLine(line) else GameTooltip:AddLine(line, 0.6, 0.6, 0.6, true) end
    end
    GameTooltip:Show()
end

-- An icon on the photo at a layout spot: icon:Set(texture name or nil, empty shape, tooltip lines).
local function CreateIcon(parent, spot)
    local icon = CreateFrame("Button", nil, parent)
    icon:SetSize(spot.size, spot.size)
    icon:SetPoint("CENTER", UI.frame, "TOPLEFT", spot.x, -spot.y)
    icon:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    icon.texture = icon:CreateTexture(nil, "ARTWORK")
    icon.texture:SetAllPoints()
    function icon:Set(name, empty, lines)
        self.texture:SetTexture(ICONS .. (name or empty))
        self.texture:SetAlpha(name and 1 or EMPTY_SHAPE)
        self.lines = lines
    end
    icon:SetScript("OnEnter", function(self) if self.lines then SetTooltip(self, self.lines) end end)
    icon:SetScript("OnLeave", GameTooltip_Hide)
    return icon
end

ns.RegisterPage({
    key = "wipOverview",
    label = "Overview",
    bare = true,  -- its own wood fills the frame (UI.lua)
    create = function(parent)
        local page = CreateFrame("Frame", nil, parent)
        page:SetAllPoints()
        local card = LAYOUT.card

        -- The book and the card as the designer drew them (one texture, under the frame), the spine's grey squares
        -- again over the frame and the header.
        local book = CreateFrame("Frame", nil, page)
        book:SetAllPoints()
        for i, piece in ipairs(LAYOUT.page) do UI.WoodPiece(book, piece, i) end
        local spineCaps = CreateFrame("Frame", nil, page)
        spineCaps:SetAllPoints()
        spineCaps:SetFrameLevel(UI.frame:GetFrameLevel() + UI.FRAME_LEVEL.header + 1)
        for i, piece in ipairs(LAYOUT.spineCaps) do UI.WoodPiece(spineCaps, piece, i) end

        -- The live parts go on the drawn card's spots (window pixels, from the window's top-left).
        local cardFrame = CreateFrame("Frame", nil, page)
        cardFrame:SetAllPoints()
        cardFrame:SetFrameLevel(book:GetFrameLevel() + 2)
        local function Place(region, area)
            region:SetSize(area.w, area.h)
            region:SetPoint("CENTER", UI.frame, "TOPLEFT", area.x, -area.y)
        end

        local label = card.label
        page.name = cardFrame:CreateFontString(nil, "OVERLAY")
        page.name:SetPoint("CENTER", UI.frame, "TOPLEFT", label.x, -label.y)
        page.name:SetFont(NAME_FONT, NAME_SIZE, "")
        page.name:SetTextColor(unpack(NAME_COLOR))
        page.name:SetShadowOffset(1, -1)
        page.name:SetWordWrap(false)
        page.nameWidth = label.w - 12

        -- The arrows: buttons over the drawn end planks; a white arrow over the drawn one lights it while hovered.
        page.arrows = {}
        for i, delta in ipairs({ -1, 1 }) do
            local arrow = CreateFrame("Button", nil, cardFrame)
            Place(arrow, card.arrows[i])
            local glyph = card.arrowGlyphs[i]
            local lit = arrow:CreateTexture(nil, "OVERLAY")
            lit:SetTexture(ART .. "Arrow")
            lit:SetSize(glyph.w * ARROW_GROW, glyph.h * ARROW_GROW)
            lit:SetPoint("CENTER", UI.frame, "TOPLEFT", glyph.x, -glyph.y)
            if delta < 0 then lit:SetTexCoord(1, 0, 0, 1) end
            lit:SetBlendMode("ADD")
            lit:SetAlpha(ARROW_LIT)
            lit:Hide()
            arrow:SetScript("OnEnter", function(self)
                lit:Show()
                SetTooltip(self, { delta < 0 and "Previous" or "Next", "Step through you and each synced guildmate." })
            end)
            arrow:SetScript("OnLeave", function()
                lit:Hide()
                GameTooltip_Hide()
            end)
            arrow:SetScript("OnClick", function()
                UI.ClickSound()
                UI.StepViewing(delta)
            end)
            page.arrows[i] = arrow
        end

        -- The photo: a picture (their chosen background, else an evening sky over grass) and the model on it.
        local photo = CreateFrame("Frame", nil, cardFrame)
        Place(photo, card.photo)
        page.photo = photo
        photo:SetFrameLevel(cardFrame:GetFrameLevel() + 2)
        local sky = photo:CreateTexture(nil, "BACKGROUND")
        sky:SetAllPoints()
        sky:SetTexture("Interface\\Buttons\\WHITE8X8")
        sky:SetGradient("VERTICAL", CreateColor(0.42, 0.58, 0.3, 1), CreateColor(0.96, 0.8, 0.74, 1))
        page.backdrop = photo:CreateTexture(nil, "ARTWORK")
        page.backdrop:SetAllPoints()
        local crop = (1 - card.photo.w / card.photo.h) / 2  -- the square pictures cropped to the photo's shape
        page.backdrop:SetTexCoord(crop, 1 - crop, 0, 1)
        page.backdrop:Hide()

        local model = CreateFrame("DressUpModel", nil, photo)
        model:SetAllPoints()
        model:EnableMouse(true)
        model:EnableMouseWheel(true)
        page.model, page.facing, page.zoom = model, 0, 0
        local function ApplyZoom()
            if model.SetCamDistanceScale then model:SetCamDistanceScale(UI.CharacterCamera(page.key, page.zoom)) end
        end
        page.ApplyZoom = ApplyZoom
        model:SetScript("OnMouseWheel", function(_, delta)
            page.zoom = math.max(UI.MIN_ZOOM, math.min(UI.MAX_ZOOM, page.zoom - delta * 0.1))
            ApplyZoom()
        end)
        model:SetScript("OnMouseDown", function(self, button)
            if button ~= "LeftButton" then return end
            local lastX = GetCursorPosition()
            self:SetScript("OnUpdate", function()
                local x = GetCursorPosition()
                page.facing = page.facing + (x - lastX) / 80
                lastX = x
                self:SetFacing(page.facing)
            end)
        end)
        model:SetScript("OnMouseUp", function(self, button)
            self:SetScript("OnUpdate", nil)
            if button == "RightButton" and not page.key then PhotoMenu(self) end
        end)
        model:SetScript("OnHide", function(self) self:SetScript("OnUpdate", nil) end)
        model:SetScript("OnEnter", function(self)
            SetTooltip(self, { "Drag to turn, scroll to zoom", not page.key and "Right-click to show a picture instead, or pick a background" or nil })
        end)
        -- A picture instead of the model: square, as tall as the photo, its sides cut off by the photo's edges.
        photo:SetClipsChildren(true)
        page.portrait = CreateFrame("Frame", nil, photo)
        page.portrait:SetSize(card.photo.h, card.photo.h)
        page.portrait:SetPoint("CENTER")
        page.portrait:Hide()
        -- While it shows, the photo takes the clicks: left to open the picture, right (yours) for the menu.
        photo:SetScript("OnMouseUp", function(self, button)
            if not page.portraitMint then return end
            if button == "RightButton" and not page.key then
                PhotoMenu(self)
            elseif button == "LeftButton" then
                UI.ClickSound()
                ns.ShowMint(page.portraitMint, page.key and Ambiguate(page.key, "short") or nil)
            end
        end)
        photo:SetScript("OnEnter", function(self)
            if not page.portraitMint then return end
            SetTooltip(self, { ("Picture #%d"):format(page.portraitMint.number), "Click to view",
                not page.key and "Right-click to show your character instead" or nil })
        end)
        photo:SetScript("OnLeave", GameTooltip_Hide)
        model:SetScript("OnLeave", GameTooltip_Hide)
        page.empty = photo:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        page.empty:SetPoint("CENTER")
        page.empty:SetWidth(card.photo.w - 16)
        page.empty:SetText("No character synced yet. It shows once they log in with SOLC 0.37.0 or newer.")

        -- The icons, over the photo.
        local overlay = CreateFrame("Frame", nil, photo)
        overlay:SetAllPoints(page)
        overlay:SetFrameLevel(model:GetFrameLevel() + 5)
        local spots = card.icons
        page.race = CreateIcon(overlay, spots.race)
        page.gender = CreateIcon(overlay, spots.gender)
        page.class = CreateIcon(overlay, spots.class)
        page.professions, page.secondary = {}, {}
        for i, spot in ipairs(spots.professions) do page.professions[i] = CreateIcon(overlay, spot) end
        for i, spot in ipairs(spots.secondary) do page.secondary[i] = CreateIcon(overlay, spot) end
        page.gender:SetScript("OnClick", function(self, button)
            if button ~= "RightButton" or page.key or not MenuUtil then return end
            MenuUtil.CreateContextMenu(self, function(_, root)
                root:CreateTitle("Gender")
                local chosen = KillTrackerDB.card and KillTrackerDB.card.gender
                root:CreateRadio("As my character", function() return chosen == nil end, function() ChooseGender(nil) end)
                for _, gender in ipairs(GENDER_ORDER) do
                    root:CreateRadio(GENDERS[gender], function() return chosen == gender end, function() ChooseGender(gender) end)
                end
            end)
        end)

        -- The name under the photo, in crayon.
        local sign = card.signature
        page.signature = overlay:CreateFontString(nil, "OVERLAY")
        page.signature:SetPoint("CENTER", UI.frame, "TOPLEFT", sign.x, -sign.y)
        page.signature:SetTextColor(unpack(INK))
        page.signature:SetShadowOffset(0, 0)
        page.signatureWidth = sign.w

        -- The left page: the stat plaques' numbers, the showcase's polaroids, the activity list.
        local left = CreateFrame("Frame", nil, page)
        left:SetAllPoints()
        left:SetFrameLevel(book:GetFrameLevel() + 2)
        page.left = left
        page.stats = {}
        for i, board in ipairs(LAYOUT.stats.boards) do
            local stat = CreateFrame("Frame", nil, left)
            Place(stat, board)
            stat:EnableMouse(true)
            local number = LAYOUT.stats.numbers[i]
            stat.value = left:CreateFontString(nil, "OVERLAY")
            stat.value:SetPoint("CENTER", UI.frame, "TOPLEFT", number.x, -number.y)
            stat.value:SetFont(NAME_FONT, STAT_SIZE, "")
            stat.value:SetTextColor(unpack(STAT_COLOR))
            UI.OutlineText(stat.value, TEXT_OUTLINE)
            stat.width = number.w
            stat:SetScript("OnEnter", function(self) if self.lines then SetTooltip(self, self.lines) end end)
            stat:SetScript("OnLeave", GameTooltip_Hide)
            page.stats[i] = stat
        end

        -- The showcase's polaroids, each turned by its tilt: the picture, its rarity's colour a pixel round it, the
        -- date it was minted, the nail. Frames can't turn, so the textures do (the picture's layers round its centre:
        -- ns.RenderMint's tilt); the date is written straight.
        local small = LAYOUT.polaroid
        page.polaroids = {}
        for i, spot in ipairs(LAYOUT.polaroids) do
            local holder = CreateFrame("Button", nil, left)
            holder:SetFrameLevel(left:GetFrameLevel() + i * 3)  -- in the layout's order, each over the one before
            holder:SetSize(small.w, small.h)
            holder:SetPoint("CENTER", UI.frame, "TOPLEFT", spot.x, -spot.y)
            holder.slot, holder.tilt = spot.slot, spot.tilt
            local angle = math.rad(spot.tilt)
            -- An offset from the polaroid's centre (y down), turned with it, in WoW's terms (y up).
            local function Turned(dx, dy)
                return dx * math.cos(angle) - dy * math.sin(angle), -(dx * math.sin(angle) + dy * math.cos(angle))
            end
            local base = holder:CreateTexture(nil, "BACKGROUND")
            base:SetTexture(ART .. "PolaroidSmall")
            base:SetAllPoints()
            base:SetRotation(-angle)
            holder.border = holder:CreateTexture(nil, "BORDER")
            holder.border:SetTexture(ART .. "Edge")  -- a square with a soft rim: turned, its edges stay smooth
            local edge = (small.photo.size + 2 * RARITY_EDGE) / EDGE_FILL
            holder.border:SetSize(edge, edge)
            holder.border:SetPoint("CENTER", Turned(small.photo.x, small.photo.y))
            holder.border:SetRotation(-angle)
            holder.canvas = CreateFrame("Frame", nil, holder)
            holder.canvas:SetSize(small.photo.size, small.photo.size)
            holder.canvas:SetPoint("CENTER", Turned(small.photo.x, small.photo.y))
            holder.empty = holder:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
            holder.empty:SetPoint("CENTER", Turned(small.photo.x, small.photo.y))
            holder.empty:SetText("+")
            holder.empty:SetTextColor(0.5, 0.5, 0.5)
            holder.date = holder:CreateFontString(nil, "OVERLAY")
            holder.date:SetFont(NAME_FONT, 9, "")
            holder.date:SetTextColor(unpack(DATE_COLOR))
            holder.date:SetPoint("RIGHT", holder, "CENTER", Turned(small.date.x, small.date.y))
            local nail = holder:CreateTexture(nil, "OVERLAY")
            nail:SetTexture(ART .. "Nail")
            nail:SetSize(small.nail, small.nail)
            nail:SetPoint("CENTER", UI.frame, "TOPLEFT", spot.nail.x, -spot.nail.y)
            holder:SetScript("OnClick", function(self)
                UI.ClickSound()
                if self.mint then
                    ns.ShowMint(self.mint, self.key and Ambiguate(self.key, "short") or nil)
                elseif not self.key then
                    ns.OpenPage("collection")  -- your pictures, to pick one
                end
            end)
            holder:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                if self.mint then
                    local rarity = ns.MintRarity(self.mint.traits)
                    GameTooltip:AddLine(("Picture #%d"):format(self.mint.number))
                    GameTooltip:AddLine((rarity:gsub("^%l", string.upper)), ns.RarityRGB(rarity))
                    for _, trait in ipairs(ns.MintTraits(self.mint.traits)) do
                        GameTooltip:AddDoubleLine(trait[1], ("|c%s%s|r"):format(ns.RARITY_COLORS[trait[3]], trait[2]))
                    end
                    GameTooltip:AddLine("Click to view", 0.6, 0.6, 0.6)
                else
                    GameTooltip:AddLine("Showcase")
                    GameTooltip:AddLine(("Open one of your pictures and click \"Show on your Overview\" (up to %d)."):format(ns.SHOWCASE_SIZE),
                        1, 1, 1, true)
                    GameTooltip:AddLine("Click to see your pictures", 0.6, 0.6, 0.6)
                end
                GameTooltip:Show()
            end)
            holder:SetScript("OnLeave", GameTooltip_Hide)
            page.polaroids[i] = holder
        end

        -- What happened to them lately, on the flat panel: a row per event, its kind's icon, the line, its time at the
        -- right end; every other row a touch lighter, the one under the mouse lighter still. The rows run on under the
        -- frame's post and the spine (the spine drawn again over them, below the polaroids).
        local feed = LAYOUT.feed
        local inset, outset = feed.left - feed.rowLeft, feed.rowRight - (feed.left + feed.width)  -- the text inside the row
        page.feed = {}
        for i = 1, feed.rows do
            local row = CreateFrame("Button", nil, left)
            row:SetSize(feed.rowRight - feed.rowLeft, feed.rowHeight)
            row:SetPoint("TOPLEFT", UI.frame, "TOPLEFT", feed.rowLeft, -(feed.top + (i - 1) * feed.rowHeight))
            local stripe = row:CreateTexture(nil, "BACKGROUND")
            stripe:SetAllPoints()
            stripe:SetColorTexture(1, 1, 1, i % 2 == 0 and FEED_STRIPE or 0)
            local hover = row:CreateTexture(nil, "HIGHLIGHT")
            hover:SetAllPoints()
            hover:SetColorTexture(1, 1, 1, FEED_HOVER)
            local iconSize = feed.textSize + 4
            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetSize(iconSize, iconSize)
            row.icon:SetPoint("LEFT", inset + 4, 0)
            row.picture = CreateFrame("Frame", nil, row)  -- a picture's line: the picture, small
            row.picture:SetSize(iconSize, iconSize)
            row.picture:SetPoint("LEFT", inset + 4, 0)
            row.time = row:CreateFontString(nil, "OVERLAY")
            row.time:SetFont(NAME_FONT, feed.timeSize, "")
            row.time:SetTextColor(unpack(FEED_TIME_COLOR))
            row.time:SetShadowOffset(1, -1)
            row.time:SetPoint("RIGHT", -(outset + 6), 0)
            row.text = row:CreateFontString(nil, "OVERLAY")
            row.text:SetFont(NAME_FONT, feed.textSize, "")
            row.text:SetTextColor(unpack(FEED_COLOR))
            row.text:SetShadowOffset(1, -1)
            row.text:SetShadowColor(0, 0, 0, 0.8)
            row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
            row.text:SetPoint("RIGHT", row.time, "LEFT", -8, 0)
            row.text:SetJustifyH("LEFT")
            row.text:SetWordWrap(false)
            row:SetScript("OnClick", function(self) if self.item then UI.ShowFeedPicture(self.item) end end)
            row:SetScript("OnEnter", function(self) if self.item then UI.FeedTooltip(self, self.item) end end)
            row:SetScript("OnLeave", GameTooltip_Hide)
            page.feed[i] = row
        end
        local spine = CreateFrame("Frame", nil, left)
        spine:SetAllPoints()
        spine:SetFrameLevel(left:GetFrameLevel() + 2)  -- over the rows (level + 1), under the polaroids (+ 3 and up)
        UI.WoodPiece(spine, feed.spine)

        -- GEARZ: the wooden button under the card (its art per state: Media/Overview/Button_*), showing their gear
        -- over the left page while selected.
        -- Like the window's Settings and Close buttons: dimmed at rest, lit while hovered or pressed, shrinking a little
        -- when pressed (the word with it, dipping), lit with yellow runes while selected (the gear showing).
        local gearButton = CreateFrame("Button", nil, cardFrame)
        Place(gearButton, card.gear)
        local art = gearButton:CreateTexture(nil, "ARTWORK")
        art:SetPoint("CENTER")
        local word = gearButton:CreateFontString(nil, "OVERLAY")
        word:SetFont(NAME_FONT, GEAR_SIZE, "")
        word:SetTextColor(unpack(GEAR_COLOR))
        word:SetText("GEARZ")
        UI.OutlineText(word, TEXT_OUTLINE)
        local hovered, pressed = false, false
        local function Redraw()
            local lit = hovered or pressed or page.gearShown
            local shade = lit and 1 or UI.HEADER_DIMMED
            art:SetTexture(ART .. (page.gearShown and "Button_SELECTED" or "Button_NORMAL"))
            art:SetVertexColor(shade, shade, shade)
            local scale = pressed and UI.HEADER_PUSHED or 1
            art:SetSize(card.gear.w * scale, card.gear.h * scale)
            local glow = lit and 1 or 0.85  -- the word a little dimmer at rest, like the header buttons' icons
            word:SetTextColor(GEAR_COLOR[1] * glow, GEAR_COLOR[2] * glow, GEAR_COLOR[3] * glow)
            word:SetFont(NAME_FONT, GEAR_SIZE * scale, "")  -- shrinks with the plank while pressed, and dips
            word:SetPoint("CENTER", pressed and 1 or 0, pressed and -2 or 0)
        end
        gearButton:SetScript("OnEnter", function() hovered = true Redraw() end)
        gearButton:SetScript("OnLeave", function() hovered, pressed = false, false Redraw() end)
        gearButton:SetScript("OnMouseDown", function() pressed = true Redraw() end)
        gearButton:SetScript("OnMouseUp", function() pressed = false Redraw() end)
        page.gearPanel = UI.CreateGearPanel(page, GEAR_PANEL.width - 12)
        page.gearPanel:ClearAllPoints()
        page.gearPanel:SetPoint("TOPLEFT", UI.frame, "TOPLEFT", GEAR_PANEL.left, -GEAR_PANEL.top)
        page.gearPanel:SetSize(GEAR_PANEL.width, GEAR_PANEL.height)
        page.gearPanel:SetFrameLevel(left:GetFrameLevel() + 20)
        local shade = page.gearPanel:CreateTexture(nil, "BACKGROUND")
        shade:SetPoint("TOPLEFT", -8, 8)
        shade:SetPoint("BOTTOMRIGHT", 8, -8)
        shade:SetColorTexture(0.05, 0.03, 0.02, 0.92)
        -- The Ogre Rank over the left page: rank, title, points to the next, every perk (unlocked ones lit).
        local rankPanel = CreateFrame("Frame", nil, page)
        rankPanel:SetPoint("TOPLEFT", UI.frame, "TOPLEFT", GEAR_PANEL.left, -GEAR_PANEL.top)
        rankPanel:SetSize(GEAR_PANEL.width, GEAR_PANEL.height)
        rankPanel:SetFrameLevel(left:GetFrameLevel() + 20)
        local rankShade = rankPanel:CreateTexture(nil, "BACKGROUND")
        rankShade:SetPoint("TOPLEFT", -8, 8)
        rankShade:SetPoint("BOTTOMRIGHT", 8, -8)
        rankShade:SetColorTexture(0.05, 0.03, 0.02, 0.92)
        rankPanel.badge = rankPanel:CreateTexture(nil, "ARTWORK")
        rankPanel.badge:SetSize(64, 64)
        rankPanel.badge:SetPoint("TOPLEFT", 4, -4)
        rankPanel.number = rankPanel:CreateFontString(nil, "OVERLAY")
        rankPanel.number:SetFont(NAME_FONT, 20, "")
        rankPanel.number:SetPoint("CENTER", rankPanel.badge, "CENTER", 0, 9)
        UI.OutlineText(rankPanel.number, TEXT_OUTLINE)
        rankPanel.title = rankPanel:CreateFontString(nil, "OVERLAY")
        rankPanel.title:SetFont(NAME_FONT, 18, "")
        rankPanel.title:SetTextColor(1, 0.82, 0.25)
        rankPanel.title:SetPoint("TOPLEFT", rankPanel.badge, "TOPRIGHT", 8, -6)
        rankPanel.points = rankPanel:CreateFontString(nil, "OVERLAY")
        rankPanel.points:SetFont(NAME_FONT, 12, "")
        rankPanel.points:SetTextColor(unpack(FEED_COLOR))
        rankPanel.points:SetPoint("TOPLEFT", rankPanel.title, "BOTTOMLEFT", 0, -4)
        local barBack = rankPanel:CreateTexture(nil, "ARTWORK")
        barBack:SetColorTexture(1, 1, 1, 0.08)
        barBack:SetPoint("TOPLEFT", rankPanel.points, "BOTTOMLEFT", 0, -6)
        barBack:SetSize(GEAR_PANEL.width - 84, 8)
        rankPanel.bar = rankPanel:CreateTexture(nil, "OVERLAY")
        rankPanel.bar:SetColorTexture(1, 0.7, 0.2, 0.85)
        rankPanel.bar:SetPoint("TOPLEFT", barBack)
        rankPanel.bar:SetHeight(8)
        rankPanel.barWidth = GEAR_PANEL.width - 84
        local perksHeading = rankPanel:CreateFontString(nil, "OVERLAY")
        perksHeading:SetFont(NAME_FONT, 14, "")
        perksHeading:SetTextColor(1, 0.82, 0.25)
        perksHeading:SetPoint("TOPLEFT", 4, -84)
        perksHeading:SetText("Rank perks")
        rankPanel.lines = {}
        for i = 1, RANK_LINES do
            local line = rankPanel:CreateFontString(nil, "OVERLAY")
            line:SetFont(NAME_FONT, 12, "")
            line:SetPoint("TOPLEFT", 4, -84 - i * 22)
            line:SetWidth(GEAR_PANEL.width - 8)
            line:SetJustifyH("LEFT")
            line:SetWordWrap(false)
            rankPanel.lines[i] = line
        end
        local back = CreateFrame("Button", nil, rankPanel, "UIPanelButtonTemplate")
        back:SetSize(70, 20)
        back:SetPoint("TOPRIGHT", 0, 0)
        back:SetText("Back")
        function rankPanel:SetPlayer(key)
            local current, nextRank, points = ns.GetRank(key)
            self.badge:SetTexture(BadgeArt(current.rank))
            self.number:SetText(current.rank)
            self.title:SetText(current.title)
            if nextRank then
                self.points:SetText(("%d points - %d more to %s"):format(points, nextRank.points - points, nextRank.title))
                local share = (points - current.points) / math.max(1, nextRank.points - current.points)
                self.bar:SetWidth(math.max(1, self.barWidth * math.min(1, share)))
            else
                self.points:SetText(("%d points - the top rank"):format(points))
                self.bar:SetWidth(self.barWidth)
            end
            for i, line in ipairs(self.lines) do
                local perk = ns.RANK_PERKS[i]
                if perk then
                    local unlocked = perk.rank <= current.rank
                    line:SetText(("%s|cff999999rank %d|r  %s"):format(unlocked and "|cff55dd55+|r " or "   ", perk.rank,
                        unlocked and perk.text or "|cff888888" .. perk.text .. "|r"))
                end
                line:SetShown(perk ~= nil)
            end
        end

        -- One panel at a time over the left page: the gear, the rank, or neither.
        local function ShowPanel(which)
            page.gearShown = which == "gear"
            page.panel = which
            page.gearPanel:SetShown(which == "gear")
            rankPanel:SetShown(which == "rank")
            left:SetShown(which == nil)
            Redraw()
        end
        page.gearPanel.OnBack = function() ShowPanel(nil) end
        back:SetScript("OnClick", function() ShowPanel(nil) end)
        gearButton:SetScript("OnClick", function()
            UI.ClickSound()
            ShowPanel(page.panel ~= "gear" and "gear" or nil)
        end)
        page.rankPanel = rankPanel

        -- The rank badge, a sticker on the polaroid's corner.
        local badge = CreateFrame("Button", nil, cardFrame)
        badge:SetFrameLevel(cardFrame:GetFrameLevel() + 12)
        badge:SetSize(RANK_BADGE.size, RANK_BADGE.size)
        badge:SetPoint("CENTER", UI.frame, "TOPLEFT", RANK_BADGE.x, -RANK_BADGE.y)
        badge.art = badge:CreateTexture(nil, "ARTWORK")
        badge.art:SetAllPoints()
        badge.art:SetRotation(math.rad(-RANK_BADGE.tilt))
        badge.number = badge:CreateFontString(nil, "OVERLAY")
        badge.number:SetFont(NAME_FONT, 15, "")
        badge.number:SetPoint("CENTER", 0, 7)
        UI.OutlineText(badge.number, TEXT_OUTLINE)
        badge:SetScript("OnClick", function()
            UI.ClickSound()
            ShowPanel(page.panel ~= "rank" and "rank" or nil)
        end)
        badge:SetScript("OnEnter", function(self)
            local current, nextRank, points = ns.GetRank(page.key)
            SetTooltip(self, { ("Ogre Rank %d: %s"):format(current.rank, current.title),
                nextRank and ("%d points, %d more to rank %d"):format(points, nextRank.points - points, nextRank.rank)
                    or ("%d points - the top rank"):format(points), "Click to see the perks" })
        end)
        badge:SetScript("OnLeave", GameTooltip_Hide)
        page.badge = badge
        ShowPanel(nil)

        -- The page is usually created while already showing, so the model may not have its size at the first
        -- load; load once more on the next frame, and whenever the page comes back.
        page.Load = function()
            if page.portraitMint then  -- a picture shows instead
                model:ClearModel()
                model:Hide()
                page.empty:Hide()
                return
            end
            model:Show()
            local shown = UI.LoadCharacter(model, page.key)
            model:SetShown(shown)
            page.empty:SetShown(not shown)
            model:SetFacing(page.facing)
            ApplyZoom()
        end
        page:SetScript("OnShow", function() if page.loaded then page.Load() end end)
        C_Timer.After(0, function() if page.loaded then page.Load() end end)
        return page
    end,

    refresh = function(page)
        local key = ns.GetViewing()
        local p = Profile(key)
        local hasFriends = next(KillTrackerFriends) ~= nil
        for _, arrow in ipairs(page.arrows) do arrow:SetShown(hasFriends) end

        -- The full name, as big as fits on the label.
        Fit(page.name, NAME_FONT, NAME_SIZE, 8, (p.name or ""):upper(), page.nameWidth)
        -- Their rank: the badge, and their name in their rank's colour (Ranks.lua).
        local rank = ns.GetRank(key)
        page.badge.art:SetTexture(BadgeArt(rank.rank))
        page.badge.number:SetText(rank.rank)
        page.name:SetTextColor(unpack(ns.RankPerk("nameColor", rank.rank) or NAME_COLOR))
        page.rankPanel:SetPlayer(key)

        -- The photo: their chosen picture, or (no model of them to show) their first showcase picture or else their
        -- newest picture, or the model.
        local friend = key and KillTrackerFriends[key]
        local gear = friend and friend.gear
        local portrait = ns.FindMint(key, p.portrait)
        if not portrait and key and not gear then portrait = ns.GetShowcase(key)[1] or ns.NewestMint(key) end
        local switched = (page.portraitMint ~= nil) ~= (portrait ~= nil)
        page.portraitMint = portrait
        page.portrait:SetShown(portrait ~= nil)
        page.photo:EnableMouse(portrait ~= nil)
        if portrait and page.portraitDrawn ~= portrait.traits then
            ns.RenderMint(page.portrait, portrait.traits)
            page.portraitDrawn = portrait.traits
        end
        -- The model: reloaded only for someone else, new gear or after a picture, so turning it sticks while the page
        -- refreshes.
        if not page.loaded or switched or key ~= page.key or (key and gear ~= page.model.shownGear) then
            page.loaded, page.key = true, key
            page.Load()
        end
        local option = not portrait and ns.GetModelBackdrop and ns.GetModelBackdrop(key)
        if option then page.backdrop:SetTexture(ns.MintTexture(option, {})) end
        page.backdrop:SetShown(option ~= nil and option ~= false)

        -- The icons.
        local color = p.classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[p.classFile]
        local classLine = p.className and ((p.level and ("Level %d "):format(p.level) or "")
            .. (color and color:WrapTextInColorCode(p.className) or p.className))
        page.class:Set(CLASSES[p.classFile or ""] and "Class_" .. p.classFile, "Base_CLASS", { classLine or "Class unknown" })
        page.race:Set(p.race and "Race_" .. p.race, "Base_RACE", { p.raceName or "Race unknown" })
        page.gender:Set(p.gender and "Gender_" .. p.gender, "Base_GENDER",
            { p.gender and GENDERS[p.gender] or "Gender unknown", not key and "Right-click to choose" or nil })
        for i, icon in ipairs(page.professions) do
            local entry = p.professions[i]
            icon:Set(entry and "Prof_" .. entry.icon, "Base_PROFESSION",
                entry and { entry.prof.name, ("%d / %d"):format(entry.prof.rank or 0, entry.prof.max or 0) } or { "No profession" })
        end
        for i, icon in ipairs(page.secondary) do
            local s = SECONDARY[i]
            local prof = p.secondary[s.key]
            icon:Set(prof and "Prof_" .. s.key, "Base_SECONDARY",
                prof and { prof.name, ("%d / %d"):format(prof.rank or 0, prof.max or 0) } or { "Not learned" })
        end

        -- The plaques: points, achievements (earned of those in the kinds of creature they've killed), kills.
        local source = key and KillTrackerFriends[key] or KillTrackerDB
        local earned, possible = 0, 0
        for _, row in ipairs(ns.GetAchievementProgress(source)) do
            earned, possible = earned + row.earned, possible + #row.tiers
        end
        local stats = {
            { key and (source.earned or 0) or ns.GetPoints().balance, { "Points", key and "Earned in all" or "To spend on minting pictures" } },
            { ("%d/%d"):format(earned, possible), { "Achievements", "Earned, of those for the kinds of creature killed so far" } },
            { source.total or 0, { "Kills" } },
        }
        for i, stat in ipairs(page.stats) do
            Fit(stat.value, NAME_FONT, STAT_SIZE, 9, tostring(stats[i][1]), stat.width)
            stat.lines = stats[i][2]
        end

        -- The showcase's pictures on the polaroids (your empty ones show a +; someone else's empty ones aren't there).
        local pictures = ns.GetShowcase(key)
        for _, holder in ipairs(page.polaroids) do
            local mint = pictures[holder.slot]
            holder.mint, holder.key = mint, key
            holder:SetShown(mint ~= nil or key == nil)
            holder.canvas:SetShown(mint ~= nil)
            holder.empty:SetShown(mint == nil)
            if mint then
                if holder.drawn ~= mint.traits then  -- only when it shows other traits
                    ns.RenderMint(holder.canvas, mint.traits, holder.tilt)
                    holder.drawn = mint.traits
                end
                holder.border:SetVertexColor(ns.RarityRGB(ns.MintRarity(mint.traits)))
                holder.date:SetText(mint.time and date("%Y-%m-%d", mint.time) or "")
            else
                holder.border:SetVertexColor(0.35, 0.35, 0.35)
                holder.date:SetText("")
            end
        end

        -- What happened to them lately: the lines without their name in front (it's on the card), calm colours.
        local who = key and Ambiguate(key, "short") or ns.MyName()
        local items = {}
        for _, item in ipairs(ns.GetFeed(true)) do
            if item.who == who then items[#items + 1] = item end
            if #items == #page.feed then break end
        end
        for i, row in ipairs(page.feed) do
            local item = items[i]
            row.item = item
            local line = item and item.text:gsub("^" .. who:gsub("%p", "%%%0") .. " ", "", 1):gsub("^%l", string.upper)
            row.text:SetText(line or (i == 1 and "Nothing yet - go smash something." or ""))
            row.time:SetText(item and ns.TimeAgo(item.time) or "")
            local thumbnail = item and item.kind == "M" and item.mint
            local icon = item and not thumbnail and FEED_ICONS[item.kind]
            row.icon:SetShown(icon ~= nil)
            if icon then row.icon:SetTexture(FEED_ICON .. icon) end
            if item and item.kind == "K" then  -- a rank reached: that rank's badge
                local reached = tonumber(item.text:match("rank (%d+)")) or 1
                row.icon:SetTexture(BadgeArt(reached))
                row.icon:Show()
            end
            row.picture:SetShown(thumbnail and true or false)
            if thumbnail and row.drawn ~= item.mint.traits then
                ns.RenderMint(row.picture, item.mint.traits)
                row.drawn = item.mint.traits
            end
        end
        page.gearPanel:SetPlayer(key)

        -- The first name under the photo, as big as fits.
        local first = (p.name or ""):match("^(%S+)") or ""
        Fit(page.signature, SIGN_FONT, SIGN_SIZE, 10, first:upper(), page.signatureWidth)
    end,
})
