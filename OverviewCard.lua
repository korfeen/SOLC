-- The new Overview, being built: shown instead of the Overview while the WIP button under the sidebar is on
-- (KillTrackerDB.wipOverview). An open book of wooden boards with a character card pinned on its right page:
-- the name bar (arrows to step through you and your synced guildmates), a polaroid with the character's model
-- on the background they picked, icons for their race, gender, class and professions on the photo, and their
-- name written under it. The book and the card are the designer's own drawing (Media/Overview/Inside, from
-- tools/convert-overview.js); the live parts go on its spots, placed by OverviewLayout.lua
-- (tools/overview-layout.js) in window coordinates.
-- The gender icon follows the character unless they pick one (right-click it on your own card):
-- KillTrackerDB.card = { gender = "MALE" | "FEMALE" | "NONBINARY", seq }, synced (Sync.lua, the card section).

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
    else
        p.name = ns.MyName()
        p.raceName, p.raceFile = Readable(UnitRace("player")), Readable(select(2, UnitRace("player")))
        p.classFile = Readable(select(2, UnitClass("player")))
        p.sex, p.level = Readable(UnitSex("player")), Readable(UnitLevel("player"))
        p.chosenGender = KillTrackerDB.card and KillTrackerDB.card.gender
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
            if button == "RightButton" and not page.key then UI.PickBackdrop(self) end
        end)
        model:SetScript("OnHide", function(self) self:SetScript("OnUpdate", nil) end)
        model:SetScript("OnEnter", function(self)
            SetTooltip(self, { "Drag to turn, scroll to zoom", not page.key and "Right-click to pick a background" or nil })
        end)
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

        -- The page is usually created while already showing, so the model may not have its size at the first
        -- load; load once more on the next frame, and whenever the page comes back.
        page.Load = function()
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

        -- The model: reloaded only for someone else or new gear, so turning it sticks while the page refreshes.
        local friend = key and KillTrackerFriends[key]
        local gear = friend and friend.gear
        if not page.loaded or key ~= page.key or (key and gear ~= page.model.shownGear) then
            page.loaded, page.key = true, key
            page.Load()
        end
        local option = ns.GetModelBackdrop and ns.GetModelBackdrop(key)
        if option then page.backdrop:SetTexture(ns.MintTexture(option, {})) end
        page.backdrop:SetShown(option ~= nil)

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

        -- The first name under the photo, as big as fits.
        local first = (p.name or ""):match("^(%S+)") or ""
        Fit(page.signature, SIGN_FONT, SIGN_SIZE, 10, first:upper(), page.signatureWidth)
    end,
})
