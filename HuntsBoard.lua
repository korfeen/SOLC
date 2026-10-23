-- The bounty board: its own page in the sidebar (Bounties; HUNTS in ogre mode), the whole page area, also opened from
-- the CAVE page's NEWS bounty box and /solc bounties. Painted in the ogre
-- pictures' style (tools/gen-board-art.js: Media\Bounty\): this week's posters (Posters.lua) pinned on a tavern's
-- bounty board, the guild's counter of claims with its milestones, and for the guild master and officers a view of
-- next week to pick the posters.
--
-- Member view: the week's title on a wooden plank, your bracket and the time to the reset under it; the guild counter
-- (claims this week, a bar with a mark per milestone and its reward's icon, reached ones lit); the posters in a row,
-- each a sheet of parchment with its engraving (Media\Posters\<id>.blp, tools/gen-poster-art.js), its name (or WANTED
-- and the boss), your progress and its reward, CLAIMED stamped across when it's done; the footer: bounty chests waiting,
-- and the officers' NEXT WEEK button.
-- Officer view: next week's title and a row per slot: EVERYONE (one pick) or BY LEVEL (a pick per bracket); a pick
-- opens the catalogue for it (the rotation, or a bounty by tier). SEND sends it to the guild (ns.SetPosters).

local _, ns = ...
local UI = ns.UI
if not UI then return end
local Fit, Tooltip = UI.FitText, UI.Tooltip

local NAME_FONT = "Interface\\AddOns\\SOLC\\Media\\Fonts\\GermaniaOne-Regular.ttf"
local BOARD = "Interface\\AddOns\\SOLC\\Media\\Bounty\\"
local ART = "Interface\\AddOns\\SOLC\\Media\\Posters\\"
local CREAM, DIM, GOLD = { 0.96, 0.9, 0.78 }, { 0.75, 0.68, 0.56 }, { 1, 0.82, 0.1 }
-- On the board itself: parchment in lamp light, and the molten gold's amber.
local LAMP, AMBER_CODE = { 0.94, 0.85, 0.67 }, "ffffb842"
local INK, INK_DIM, RED = { 0.23, 0.15, 0.08 }, { 0.45, 0.35, 0.24 }, { 0.62, 0.12, 0.08 }
local TIER_COLORS = { easy = { 0.22, 0.5, 0.2 }, medium = { 0.16, 0.38, 0.66 }, hard = { 0.55, 0.2, 0.72 } }
local SEPIA = { 1, 0.78, 0.5 }  -- (an unclaimed poster's picture: desaturated, then this brown)
local SEPIA_PICTURE = { 0.98, 0.7, 0.4 }  -- (an ogre picture's: browner, it's greyer to begin with)
local TIER_REWARD = { easy = 0.25, medium = 0.5, hard = 1 }
-- (a read poster's objective: its size, shrunk down to min when it's long (an officer's loud story) till it fits on
-- that many lines; its gap under the story)
local OBJECTIVE = { size = 24, min = 16, lines = 3, gap = 4 }
local BUTTON, BUTTON_LIT = { 0.3, 0.22, 0.12 }, { 0.65, 0.53, 0.28 }
-- The screen's layout (pixels from its top; the posters fill the room between the counter and the footer).
-- (the plank's carved panel: rows 36 to 88 of its 128; the title and the reset line go in it)
local LAYOUT = { plank = { y = 8, w = 400, h = 88, panel = { 36 / 128, 88 / 128 } }, reset = { w = 84, h = 62, tilt = 3, nail = 115 / 1024 }, counter = { y = 106, h = 112, posts = { 126 / 1024, 900 / 1024 }, bar = 40 },
    note = { w = 44, h = 58 }, posters = { top = 236, bottom = 46, gap = 30, side = 50, aspect = 1.34, max = 132 }, footer = 14 }

local TEST_CLAIMED = {}  -- (TEMPORARY: posters drawn as claimed by their place in the row, /solc claimtest; remove)
local TEST_FILL = nil  -- (TEMPORARY: a fraction fills the counter bar that far, to see how it looks; remove)
-- (TEMPORARY: made-up guild members who claimed some of this week's posters, to see how it looks; remove)
local TEST_CLAIMS = { "Grubnak", "Mossy", "Thalwyn", "Brokka", "Pipsqueak", "Ulgar", "Seraphine", "Durn", "Kazzik",
    "Wobbles", "Tharnok", "Elowen", "Gorrim", "Fizzlebang", "Moraga", "Snorgle", "Valindra", "Hukka", "Bramblewick",
    "Ozzgar", "Lirael", "Thudd" }

-- Lamp-lit text on the board: a soft warm shadow, not an outline (so it sits in the painting).
local function Shade(text)
    text:SetShadowColor(0.1, 0.05, 0.02, 0.8)
    text:SetShadowOffset(1, -1)
end

-- The board's frame on the backdrop: its posts' outer edges and the bottom beam's lower part (fractions of the painting).
local FRAME = { left = 80 / 1024, right = 946 / 1024, bottom = 920 / 1024 }
local MAX_EXTRAS = 8  -- (officers' own posters up at once, at most)
local EXTRA_SIZE = 0.85  -- (theirs, the size of the week's)
local SWING_NUDGE = 0.8  -- (degrees a poster swings when the mouse comes onto it: Hang)

local function Text(parent, size, color, justify)
    local t = parent:CreateFontString(nil, "OVERLAY")
    t:SetFont(NAME_FONT, size, "")
    t:SetTextColor(unpack(color or CREAM))
    t:SetJustifyH(justify or "LEFT")
    t:SetWordWrap(false)
    return t
end

-- Woodburned lettering (a try: /solc burn swaps the counter's header between it and the plank's lettering): on a
-- planed, lighter patch of the board, a dark core with a softer scorch round it, sunk a little into the wood (its
-- lower edge catching the lamp light). burn:SetText(text); burn:SetShown(shown).
local BURN = { core = { 0.14, 0.065, 0.02 }, scorch = { 0.36, 0.17, 0.05 }, lit = { 1, 0.8, 0.5, 0.5 }, sunk = { 0.04, 0.02, 0, 0.6 },
    patch = { 1, 0.86, 0.62, 0.1 } }
local function BurnText(parent, size)
    local burn = { parts = {} }
    local function Part(layer, color, x, y, alpha)
        local t = parent:CreateFontString(nil, layer)
        t:SetFont(NAME_FONT, size, "")
        t:SetTextColor(color[1], color[2], color[3], alpha or color[4] or 1)
        t:SetShadowOffset(0, 0)
        t:SetWordWrap(false)
        t.x, t.y = x, y
        burn.parts[#burn.parts + 1] = t
        return t
    end
    -- (the patch: a soft oval, lighter in its middle, fading out on every side; Media\Bounty\glow)
    burn.patch = parent:CreateTexture(nil, "BACKGROUND")
    burn.patch:SetTexture(BOARD .. "glow")
    burn.patch:SetVertexColor(unpack(BURN.patch))
    for _, o in ipairs({ { -2, 0 }, { 2, 0 }, { 0, -2 }, { 0, 2 }, { -1, -1 }, { 1, 1 }, { -1, 1 }, { 1, -1 } }) do
        Part("BORDER", BURN.scorch, o[1], o[2], 0.22)
    end
    Part("ARTWORK", BURN.lit, 0.5, -1)
    Part("ARTWORK", BURN.sunk, -0.5, 1)
    burn.core = Part("OVERLAY", BURN.core, 0, 0)
    function burn:SetPoint(point, relative, relativePoint, x, y)
        for _, t in ipairs(self.parts) do
            t:ClearAllPoints()
            t:SetPoint(point, relative, relativePoint, x + t.x, y + t.y)
        end
    end
    function burn:SetText(text)
        for _, t in ipairs(self.parts) do t:SetText(text) end
        self.patch:ClearAllPoints()
        self.patch:SetPoint("CENTER", self.core, "CENTER", 0, 0)
        self.patch:SetSize(self.core:GetStringWidth() + 90, size + 22)
    end
    function burn:SetShown(shown)
        for _, t in ipairs(self.parts) do t:SetShown(shown) end
        self.patch:SetShown(shown)
    end
    return burn
end

-- A wooden button: button.text, button.action, button.lines (its tooltip).
local function Button(parent, width, height, size)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, height)
    button.back = button:CreateTexture(nil, "BACKGROUND")
    button.back:SetAllPoints()
    button.text = Text(button, size or 13, CREAM, "CENTER")
    button.text:SetPoint("CENTER", 0, 1)
    button.text:SetWidth(width - 6)
    UI.OutlineText(button.text, { 0, 0, 0 })
    function button:Paint(lit) self.back:SetColorTexture(unpack((lit or self.on) and BUTTON_LIT or BUTTON)) end
    button:SetScript("OnEnter", function(self) self:Paint(true) if self.lines then Tooltip(self, self.lines) end end)
    button:SetScript("OnLeave", function(self) self:Paint(false) GameTooltip_Hide() end)
    button:SetScript("OnClick", function(self, mouse) UI.ClickSound() if self.action then self.action(self, mouse) end end)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:Paint(false)
    return button
end

-- The painted bar (Media\Bounty\beam, barfill, barhead): a crossbeam of the board's frame with a slot cut through
-- it (in three slices: its ends kept in shape, the middle stretched), molten gold behind the slot, its start and its
-- rounded front (barhead) glowing where it ends; the wood hides what's past the slot. The gold rises slowly to the
-- fraction, like magma filling the beam (bar:Set(fraction); bar:Set(fraction, true): at once); full, the front goes
-- (the slot reads full). bar:At(fraction): how far along the bar, in pixels, the gold is then.
local BEAM = { aspect = 2155 / 208, ends = 0.08, slot = { 0.0487, 0.9517, 0.3558, 0.6346 } }  -- (gen-board-art.js beam)
local FILL_ROWS = { 0.36, 0.63 }  -- (the rows of barfill that are gold)
local RISE = 0.18  -- (of the bar a second, at least; more when it has far to go)
local function PaintedBar(parent, width, height)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetSize(width, height)
    local ends = height * BEAM.aspect * BEAM.ends
    local slotLeft = ends * BEAM.slot[1] / BEAM.ends
    local slotRight = width - ends * (1 - BEAM.slot[2]) / BEAM.ends
    local slotTop, slotHeight = height * BEAM.slot[3], height * (BEAM.slot[4] - BEAM.slot[3])
    local slotWidth, lead = slotRight - slotLeft, 6  -- (lead: the gold starts under the wood, before the slot)
    local y = -(slotTop + slotHeight / 2) + height / 2  -- (the slot's middle, from the bar's)
    -- A soft shadow under the beam, so it sits on the board.
    local shadow = bar:CreateTexture(nil, "BACKGROUND", nil, -3)
    shadow:SetColorTexture(1, 1, 1)
    shadow:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", ends * 0.3, 3)
    shadow:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", -ends * 0.3, 3)
    shadow:SetHeight(10)
    shadow:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0), CreateColor(0.05, 0.02, 0, 0.6))
    -- The slot, empty: dark warm wood, shaded under its top edge.
    local groove = bar:CreateTexture(nil, "BACKGROUND", nil, -2)
    groove:SetPoint("LEFT", slotLeft - 2, y)
    groove:SetSize(slotWidth + 4, slotHeight + 4)
    groove:SetColorTexture(0.17, 0.095, 0.05)
    local inner = bar:CreateTexture(nil, "BACKGROUND", nil, -1)
    inner:SetColorTexture(1, 1, 1)
    inner:SetPoint("TOPLEFT", groove)
    inner:SetPoint("TOPRIGHT", groove)
    inner:SetHeight(groove:GetHeight() * 0.55)
    inner:SetGradient("VERTICAL", CreateColor(0.04, 0.02, 0.01, 0), CreateColor(0.04, 0.02, 0.01, 0.85))
    bar.fill = bar:CreateTexture(nil, "BACKGROUND", nil, 1)
    bar.fill:SetTexture(BOARD .. "barfill")
    bar.fill:SetVertexColor(0.95, 0.86, 0.74)  -- (a little less bright: lamp light, like the board)
    bar.fill:SetPoint("LEFT", slotLeft - lead, y)
    bar.fill:SetHeight(slotHeight + 4)
    -- The front: taller than the slot (the wood hides the rest), its faded left part over the gold's end; cut short
    -- before the beam's end.
    local headHeight = slotHeight * 1.5
    local headWidth, fade = headHeight * 2, 0.3  -- (2:1; its left 30% fades in: gen-board-art.js's fadeLeft)
    bar.head = bar:CreateTexture(nil, "BACKGROUND", nil, 2)
    bar.head:SetTexture(BOARD .. "barhead")
    bar.head:SetVertexColor(0.95, 0.86, 0.74)
    bar.head:SetHeight(headHeight)
    bar.head:SetPoint("LEFT", bar.fill, "RIGHT", -headWidth * fade, 0)
    -- Its glow, breathing.
    bar.glow = bar:CreateTexture(nil, "BACKGROUND", nil, 3)
    bar.glow:SetTexture(BOARD .. "barhead")
    bar.glow:SetBlendMode("ADD")
    bar.glow:SetAllPoints(bar.head)
    bar.glow:SetAlpha(0)
    local breathe = bar.glow:CreateAnimationGroup()
    breathe:SetLooping("BOUNCE")
    local pulse = breathe:CreateAnimation("Alpha")
    pulse:SetFromAlpha(0.05)
    pulse:SetToAlpha(0.4)
    pulse:SetDuration(1.6)
    pulse:SetSmoothing("IN_OUT")
    breathe:Play()
    for _, part in ipairs({ { 0, BEAM.ends, "LEFT" }, { BEAM.ends, 1 - BEAM.ends }, { 1 - BEAM.ends, 1, "RIGHT" } }) do
        local t = bar:CreateTexture(nil, "ARTWORK")
        t:SetTexture(BOARD .. "beam")
        t:SetTexCoord(part[1], part[2], 0, 1)
        -- (darker than the backdrop's tint: its painting is brighter than the board's wood; the ends darker still,
        -- as the posts they meet are in the screen's vignette)
        local wood, post = CreateColor(0.46, 0.43, 0.4), CreateColor(0.37, 0.34, 0.32)
        if part[3] == "LEFT" then t:SetGradient("HORIZONTAL", post, wood)
        elseif part[3] == "RIGHT" then t:SetGradient("HORIZONTAL", wood, post)
        else t:SetVertexColor(wood:GetRGB()) end
        t:SetHeight(height)
        if part[3] then t:SetWidth(ends) t:SetPoint(part[3]) else t:SetPoint("LEFT", ends, 0) t:SetPoint("RIGHT", -ends, 0) end
    end
    bar.width, bar.shown, bar.target = width, 0, 0
    function bar:At(fraction) return slotLeft + slotWidth * fraction end
    local function Draw(fraction)
        local w = lead + slotWidth * fraction
        bar.fill:SetShown(fraction > 0)
        bar.fill:SetWidth(w)
        bar.fill:SetTexCoord(0, w / (lead + slotWidth), FILL_ROWS[1], FILL_ROWS[2])
        local front = fraction > 0 and fraction < 1
        bar.head:SetShown(front)
        bar.glow:SetShown(front)
        if front then
            local room = width - 3 - bar:At(fraction)  -- (to the beam's end)
            local shown = headWidth * fade + math.min(headWidth * (1 - fade), room)
            bar.head:SetWidth(shown)
            bar.head:SetTexCoord(0, shown / headWidth, 0, 1)
            bar.glow:SetTexCoord(0, shown / headWidth, 0, 1)
        end
    end
    bar:SetScript("OnUpdate", function(self, elapsed)
        if self.shown == self.target then return end
        local step = math.max(RISE, math.abs(self.target - self.shown) * 1.2) * elapsed
        if math.abs(self.target - self.shown) <= step then self.shown = self.target
        elseif self.target > self.shown then self.shown = self.shown + step
        else self.shown = self.shown - step end
        Draw(self.shown)
    end)
    function bar:Set(fraction, now)
        self.target = math.max(0, math.min(1, fraction))
        if now then self.shown = self.target end
        Draw(self.shown)
    end
    Draw(0)
    return bar
end

local function Reward(p)
    return math.floor(ns.Config("bountyReward") * (TIER_REWARD[p.tier] or 0.5) + 0.5)
end

-- Posters ---------------------------------------------------------------------------------------------------------------

-- Who claimed a poster, short: a few names, then how many more (all of them in the tooltip); you first.
local CLAIM_NAMES = 3
local function ClaimLine(names)
    if not names or #names == 0 then return "" end
    local me = ns.MyName and ns.MyName()
    table.sort(names, function(a, b) if (a == me) ~= (b == me) then return a == me end return a < b end)
    if #names == 1 then return "Claimed by " .. names[1] end
    if #names <= CLAIM_NAMES + 1 then
        return ("Claimed by %s and %s"):format(table.concat(names, ", ", 1, #names - 1), names[#names])
    end
    return ("Claimed by %d hunters: %s and %d more"):format(#names, table.concat(names, ", ", 1, CLAIM_NAMES),
        #names - CLAIM_NAMES)
end

-- A poster: on the board (only its headline, its engraving and its name; a click reads it) or full (the one read,
-- in the middle of the screen: its tier, its story, your progress, its reward and who claimed it too).
local function Poster(parent, full)
    local f = CreateFrame("Frame", nil, parent)
    f.full = full
    f.sheet = f:CreateTexture(nil, "BACKGROUND")
    f.sheet:SetTexture(BOARD .. "poster")
    f.shade = f:CreateTexture(nil, "BORDER")  -- (the tier's colour, faint, until its engraving is painted)
    f.art = f:CreateTexture(nil, "ARTWORK")
    -- (or an ogre picture, drawn from its layers like a mint: f.picture, its traits)
    f.canvas = CreateFrame("Frame", nil, f)
    f.canvas:SetFrameLevel(f:GetFrameLevel() + 1)
    f.canvas:Hide()
    -- (the nail over everything on the sheet, its text too: on a frame of its own over the poster)
    f.nail = CreateFrame("Frame", nil, f)
    f.nail:SetAllPoints()
    f.nail:SetFrameLevel(f:GetFrameLevel() + 2)
    f.pin = f.nail:CreateTexture(nil, "OVERLAY")
    f.pin:SetTexture(BOARD .. "pin")
    f.pin:SetShown(not full)
    -- (an officer's own poster's marks: an hourglass if it's timed, a wax seal with the claims left if it's limited)
    f.hourglass = f.nail:CreateTexture(nil, "OVERLAY", nil, 1)
    f.hourglass:SetTexture(BOARD .. "hourglass")
    f.hourglass:SetDesaturated(true)  -- (sepia, like the poster's picture)
    f.hourglass:SetVertexColor(unpack(SEPIA))
    f.seal = f.nail:CreateTexture(nil, "OVERLAY", nil, 1)
    f.seal:SetTexture(BOARD .. "seal")
    f.seal:SetVertexColor(0.78, 0.58, 0.5)  -- (old wax, not a bright red: it's on a sepia poster)
    f.sealText = Text(f.nail, full and 15 or 11, { 0.95, 0.86, 0.72 }, "CENTER")
    UI.OutlineText(f.sealText, { 0.22, 0.04, 0.02 })
    f.tag = Text(f, full and 28 or 16, RED, "CENTER")
    f.name = Text(f, 18, INK, "CENTER")
    f.stamp = f.nail:CreateTexture(nil, "OVERLAY", nil, 2)  -- (over an ogre picture too)
    f.stamp:SetTexture(BOARD .. "stamp")
    if full then
        f.tier = Text(f, 13, INK_DIM, "CENTER")
        f.desc = Text(f, 14, INK, "CENTER")
        f.desc:SetWordWrap(true)
        f.desc:SetJustifyV("TOP")
        -- (what to do, under the story: big, red, underlined; a wanted poster's SMASH)
        f.objective = Text(f, OBJECTIVE.size, RED, "CENTER")
        f.objective:SetWordWrap(true)  -- (an officer's loud story: smaller and on more lines when it's long)
        f.objectiveLine = f:CreateTexture(nil, "ARTWORK")
        f.objectiveLine:SetColorTexture(unpack(RED))
        f.claim = Text(f, 12, INK_DIM, "CENTER")
        f.claim:SetWordWrap(true)
        f.claim:SetJustifyV("BOTTOM")
        -- (all of them under the mouse; clicks go through to the reader, which puts the poster back)
        f.claimHit = CreateFrame("Frame", nil, f)
        f.claimHit:SetAllPoints(f.claim)
        f.claimHit:SetMouseMotionEnabled(true)
        f.claimHit:SetMouseClickEnabled(false)
        f.claimHit:SetScript("OnEnter", function(self)
            local names = f.claimers
            if not names or #names <= CLAIM_NAMES + 1 then return end
            local lines = { ("Claimed by %d hunters"):format(#names) }
            for _, name in ipairs(names) do lines[#lines + 1] = name end
            Tooltip(self, lines)
        end)
        f.claimHit:SetScript("OnLeave", GameTooltip_Hide)
        f.barBack = f:CreateTexture(nil, "BORDER")
        f.barBack:SetColorTexture(0, 0, 0, 0.55)
        f.barFill = f:CreateTexture(nil, "ARTWORK", nil, 1)
        f.count = Text(f, 16, INK)
        f.reward = Text(f, 14, INK_DIM, "RIGHT")
        return f
    end
    -- (on the board: lighter under the mouse; a click reads it)
    f:EnableMouse(true)
    f:SetScript("OnEnter", function(self)
        self.sheet:SetVertexColor(1, 0.97, 0.9)
        local e = self.poster and self.poster.extra  -- (an officer's own: when it comes down, how many may still claim it)
        if e and (e.ends > 0 or e.limit > 0) then
            local lines = { self.poster.bounty.name }
            if e.ends > 0 then lines[#lines + 1] = "Comes down in " .. ns.BountyTimeLeft(e.ends - GetServerTime()) end
            if e.limit > 0 then
                lines[#lines + 1] = ("%d of %d may still claim it"):format(math.max(0, e.limit - (self.poster.claims or 0)), e.limit)
            end
            Tooltip(self, lines)
        end
        if self.hang and self.hang.swing < 0.3 then
            local x = GetCursorPosition() / self:GetEffectiveScale() - self:GetCenter()
            self.hang.swing, self.hang.t = x < 0 and -SWING_NUDGE or SWING_NUDGE, 0  -- (pushed from the side you came in)
        end
    end)
    f:SetScript("OnLeave", function(self) self.sheet:SetVertexColor(unpack(self.paper or { 1, 1, 1 })) GameTooltip_Hide() end)
    f:SetScript("OnMouseUp", function(self, mouse)
        if self.dropped then self.dropped = nil return end  -- (let go after a drag: not a click)
        if mouse == "RightButton" and self.extra and parent.ExtraMenu then return parent:ExtraMenu(self) end
        if mouse == "LeftButton" and self.poster and parent.Read then UI.ClickSound() parent:Read(self) end
    end)
    -- (an officer's own poster: officers drag it somewhere else)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) if parent.Drag then parent:Drag(self) end end)
    f:SetScript("OnDragStop", function(self)
        if parent.dragging == self then self.dropped = true parent:Drop(self) end
    end)
    return f
end

local DrawPicture  -- (below: an ogre picture on a poster)

-- The objective right under the story's last line, its underline under it (read; once laid out and its text set).
local function PlaceObjective(f)
    local shown = (f.objective:GetText() or "") ~= ""
    f.objectiveLine:SetShown(shown)
    if not shown then return end
    local story = (f.desc:GetText() or "") ~= ""
    local top = f.descTop + (story and f.desc:GetStringHeight() + OBJECTIVE.gap or 0)
    local height = f.objective:GetStringHeight()
    f.Put(f.objective, f.w / 2, top + height / 2, f.artWidth, height)
    -- (under its last line, as wide as its widest)
    f.Put(f.objectiveLine, f.w / 2, top + height + 1, math.min(f.artWidth, f.objective:GetStringWidth()) + 6, 2, true)
end

-- Lays a poster out in w x h, nailed up a little askew: tilt (degrees, clockwise) turns the sheet, its engraving
-- and the stamp round its middle, and moves the texts and the bar with them (WoW can't turn text: they stay level);
-- mirror flips the sheet (its torn edges differ); pin: the nail's offset from the middle (pixels). From the top: the
-- pin, WANTED or BOUNTY, the engraving (square), the name; full, then the tier, the story, who claimed it, the bar and
-- the numbers; the stamp across the middle.
local function LayOut(f, w, h, tilt, mirror, pin)
    f:SetSize(w, h)
    local angle = math.rad(tilt or 0)
    local cos, sin = math.cos(angle), math.sin(angle)
    -- A region's middle at (x, y) from the poster's top-left (y down), turned with the sheet; turn: the region too.
    local function Put(region, x, y, width, height, turn)
        local dx, dy = x - w / 2, h / 2 - y
        region:ClearAllPoints()
        region:SetPoint("CENTER", f, "CENTER", dx * cos + dy * sin, dy * cos - dx * sin)
        if width then region:SetWidth(width) end
        if height then region:SetHeight(height) end
        if turn then region:SetRotation(-angle) end  -- (WoW turns anticlockwise)
    end
    local inset = math.floor(w * (f.full and 0.14 or 0.12))
    local textWidth = w - inset * 2
    local art = textWidth - (f.artShrink or 0)  -- (read: a smaller picture when the sheet can't grow for the story)
    Put(f.sheet, w / 2, h / 2, w, h, true)
    if mirror then f.sheet:SetTexCoord(1, 0, 0, 1) else f.sheet:SetTexCoord(0, 1, 0, 1) end
    local pinSize = math.min(22, math.floor(w * 0.14))
    local pinTop = math.floor(h * 0.02)
    Put(f.pin, w / 2 + (pin or 0), pinTop + pinSize / 2, pinSize, pinSize)
    local tagSize = f.full and 26 or 16
    -- (the nail over the headline's middle, hiding a bit of it; read, off its nail: none)
    -- (below the sheet's torn top edge)
    local tagY = math.floor(h * (f.full and 0.07 or 0.095)) + tagSize / 2 + 1
    Put(f.tag, w / 2, tagY, textWidth)
    local top = math.floor(h * (f.full and 0.135 or 0.19))
    Put(f.art, w / 2, top + art / 2, art, art, true)
    Put(f.canvas, w / 2, top + art / 2, art, art)  -- (a frame can't turn: the picture's layers turn themselves)
    f.canvasTilt = tilt or 0
    if f.picture and f.canvas:IsShown() then DrawPicture(f) end
    Put(f.shade, w / 2, top + art / 2, art, art, true)
    local below = top + art
    f.nameSize = f.full and 26 or 16
    f.nameY = below + 4 + f.nameSize / 2 + 2  -- (one line's middle; two lines: FitName's nameShift lower)
    Put(f.name, w / 2, f.nameY + (f.nameShift or 0), textWidth)
    Put(f.stamp, w / 2, h / 2 - h * 0.08, w * 0.95, w * 0.475, true)
    -- (the stamp is painted tilted already)
    f.artWidth, f.Put, f.w = textWidth, Put, w
    -- (the marks: beside the headline, on the board and read alike; on the board a little smaller, further out)
    local mark = f.full and 30 or 18
    local side = f.full and (inset + mark / 2 - 2) or (inset * 0.7 + mark / 2)
    Put(f.hourglass, side, tagY, mark, mark, true)
    Put(f.seal, w - side, tagY, mark, mark, true)
    Put(f.sealText, w - side, tagY - 1, mark)
    f.markSize = mark
    if not f.full then return end
    -- (an officer's own poster's line: when it comes down, how many may still claim it; others go without)
    Put(f.tier, w / 2, below + 42, textWidth)
    local bottom = h - math.floor(h * 0.07)
    -- (the story right under the name or that line, as far down as who claimed it; then the numbers over the bar)
    f.descTop = below + (f.tierShown and 56 or 40)
    -- (a goal of one: no bar, no count, the reward in the middle; all of it lower)
    local foot = f.single and 30 or 0
    f.descRoom = bottom - 94 + foot - f.descTop  -- (the reader makes the sheet taller when the story needs more)
    Put(f.desc, w / 2, (f.descTop + bottom - 94 + foot) / 2, textWidth, f.descRoom)
    PlaceObjective(f)
    Put(f.claim, w / 2, bottom - 78 + foot, textWidth, 28)  -- (two lines at most, its last one just over the numbers)
    Put(f.count, inset + textWidth / 4, bottom - 50, textWidth / 2)
    f.reward:SetJustifyH(f.single and "CENTER" or "RIGHT")
    Put(f.reward, f.single and w / 2 or w - inset - textWidth / 4, bottom - 50 + foot, f.single and textWidth or textWidth / 2)
    f.count:SetShown(not f.single)
    f.barBack:SetShown(not f.single)
    f.barY, f.barLeft = bottom - 34, inset
    Put(f.barBack, w / 2, f.barY, textWidth, 10, true)
end

-- A poster's name as big as fits: on the board on one line down to TWO_LINES of its size, then on two lines (a long
-- boss's name), only past the smallest size on two cut short; read, on one line.
local TWO_LINES = 0.8
local function FitName(f, text)
    local name, size, width = f.name, f.nameSize, f.artWidth
    name:SetWordWrap(false)
    if f.full then  -- (read: room enough on one line for the longest)
        Fit(name, NAME_FONT, size, 10, text, width)
        f.nameShift = 0
        return
    end
    Fit(name, NAME_FONT, size, math.floor(size * TWO_LINES), text, width)
    local lines = 1
    if name:GetStringWidth() > width then
        name:SetWordWrap(true)
        if name.SetMaxLines then name:SetMaxLines(2) end
        local s = math.floor(size * TWO_LINES)
        repeat
            name:SetFont(NAME_FONT, s, "")
            name:SetText("")
            name:SetText(text)
            s = s - 1
        until s < 10 or not name:IsTruncated()
        lines = 2
    end
    local _, lineSize = name:GetFont()
    name:SetHeight(lines == 2 and lineSize * 2 + 2 or 0)
    f.nameShift = lines == 2 and lineSize / 2 or 0
    f.Put(name, f.w / 2, f.nameY + f.nameShift, width)
end

-- An ogre picture on a poster (f.picture: its traits), turned with the sheet, sepia (claimed too), its edges faded.
DrawPicture = function(f)
    local canvas = f.canvas
    canvas:SetFrameLevel(f:GetFrameLevel() + 1)
    ns.RenderMint(canvas, f.picture, f.canvasTilt or 0)
    -- (feathered: it fades out at the bottom, where the ogre is cut off, and a little at the sides; Media\Bounty\fade)
    if not canvas.fade then
        canvas.fade = canvas:CreateMaskTexture()
        canvas.fade:SetTexture(BOARD .. "fade", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        canvas.fade:SetAllPoints()
    end
    local parts = { canvas.front, canvas.outfitFront, canvas.outfitBack }
    for _, tex in ipairs(canvas.layers or {}) do parts[#parts + 1] = tex end
    for _, tex in pairs(canvas.behinds or {}) do parts[#parts + 1] = tex end
    for _, tex in pairs(parts) do
        if not tex.faded then tex:AddMaskTexture(canvas.fade) tex.faded = true end
        if tex:IsShown() then
            tex:SetDesaturated(true)
            tex:SetVertexColor(unpack(SEPIA_PICTURE))
        end
    end
end

local function DrawPoster(f, p, claimers)
    f.poster, f.claimers = p, claimers
    f.nail:SetFrameLevel(f:GetFrameLevel() + 2)  -- (again: the board's level changes when it opens)
    local wanted = p.bounty.wanted
    local artId = p.extra and p.extra.id or p.id  -- (an officer's own poster: its bounty's picture)
    f.art:SetTexture(ART .. artId:lower())
    -- (sepia, like an inked poster; claimed too, its stamp reads better on it)
    f.art:SetDesaturated(true)
    f.art:SetVertexColor(unpack(SEPIA))
    -- (an officer's own ogre; the poster's: a wanted boss's gear, a creature's costume, a faction's outfit, a special's
    -- prop, Posters.lua; else the engraving)
    f.picture = (p.extra and p.extra.picture) or ns.PosterPicture(artId)
    f.art:SetShown(not f.picture)
    f.canvas:SetShown(f.picture and true or false)
    if f.picture then DrawPicture(f) end
    local c = TIER_COLORS[p.tier] or TIER_COLORS.medium
    f.shade:SetColorTexture(c[1], c[2], c[3], 0.25)
    f.shade:SetShown(not f.picture)  -- (the tier's colour only where an engraving goes)
    -- (WANTED or BOUNTY; an officer's own poster, its own headline)
    local tagline = p.bounty.tagline
    f.tag:SetText(tagline or (wanted and "WANTED" or "BOUNTY"))
    f.tag:SetTextColor(unpack((wanted or tagline) and RED or INK_DIM))
    FitName(f, (not f.full and p.bounty.short) or wanted or p.bounty.name)  -- (a boss's short name on the board)
    f.stamp:SetShown(p.claimed ~= nil)
    f.paper = p.claimed and { 0.7, 0.66, 0.6 } or { 0.86, 0.82, 0.76 }
    f.sheet:SetVertexColor(unpack(f.paper))
    -- (an officer's own: timed, limited)
    local e = p.extra
    f.hourglass:SetShown(e and e.ends > 0 and true or false)
    f.seal:SetShown(e and e.limit > 0 and true or false)
    f.sealText:SetShown(e and e.limit > 0 and true or false)
    if e and e.limit > 0 then  -- (as big as fits the seal: 2 or 3 figures smaller; past 99, "99+")
        local left = math.max(0, e.limit - (p.claims or 0))
        Fit(f.sealText, NAME_FONT, f.full and 15 or 11, 7, left > 99 and "99+" or tostring(left), f.markSize * 0.68)
    end
    f:Show()
    if not f.full then return end
    -- (no tier: the reward says it)
    local line = {}
    if e and e.ends > 0 then line[#line + 1] = "down in " .. ns.BountyTimeLeft(e.ends - GetServerTime()) end
    if e and e.limit > 0 then  -- (a limited one: how many may still claim it)
        line[#line + 1] = ("%d of %d left"):format(math.max(0, e.limit - (p.claims or 0)), e.limit)
    end
    f.tier:SetText(table.concat(line, "  ·  "))
    f.desc:SetText(p.bounty.desc or "")
    -- (as big as fits on OBJECTIVE.lines lines: measured unwrapped, a wrapped one is never wider than its box)
    local objective, size, wide = p.bounty.objective or "", OBJECTIVE.size + 1, 0
    f.objective:SetWidth(f.artWidth)
    f.objective:SetHeight(0)  -- (its own height, till PlaceObjective sets it)
    repeat
        size = size - 1
        f.objective:SetFont(NAME_FONT, size, "")
        f.objective:SetText("")
        f.objective:SetText(objective)
        wide = f.objective.GetUnboundedStringWidth and f.objective:GetUnboundedStringWidth() or f.objective:GetStringWidth()
    until size <= OBJECTIVE.min or wide <= f.artWidth * OBJECTIVE.lines
    PlaceObjective(f)
    f.claim:SetText(ClaimLine(claimers))
    -- (the bar's ink, from its left end, turned with the sheet)
    local fill = f.artWidth * math.max(0, math.min(1, (p.have or 0) / math.max(1, p.goal)))
    f.barFill:SetColorTexture(unpack(INK))
    f.barFill:SetShown(fill > 0.5 and not f.single)
    f.Put(f.barFill, f.barLeft + fill / 2, f.barY, math.max(1, fill - 2), 8, true)
    f.count:SetText(("%d/%d"):format(p.have or 0, p.goal))
    f.reward:SetText(("+%d pts"):format(Reward(p)))
end

-- Reading a poster: it comes off the board to the middle of the screen, bigger and straight, over the board darkened;
-- a click anywhere or Escape puts it back (reader:Read(poster), reader:Close(now), reader:Redraw()).
local READ = { width = 300, aspect = 1.6, time = 0.2 }
local function BuildReader(screen)
    local reader = CreateFrame("Frame", nil, screen)
    reader:SetAllPoints()
    reader:SetFrameLevel(screen:GetFrameLevel() + 40)
    reader:EnableMouse(true)
    reader:Hide()
    local dim = reader:CreateTexture(nil, "BACKGROUND")
    dim:SetAllPoints()
    dim:SetColorTexture(0.02, 0.01, 0, 0.6)
    local sheet = Poster(reader, true)
    local from, source, t, closing = nil, nil, 0, false
    -- Where it is between the board (t = 0) and read (t = 1), eased.
    local function Place()
        local e = 1 - (1 - t) * (1 - t)
        local w, h = sheet:GetSize()
        local scale = from.scale + (1 - from.scale) * e
        LayOut(sheet, w, h, from.tilt * (1 - e), from.mirror, from.pin)
        sheet:SetScale(scale)
        local x = from.x + (reader:GetWidth() / 2 - from.x) * e
        local y = from.y + (reader:GetHeight() / 2 - from.y) * e
        sheet:ClearAllPoints()
        sheet:SetPoint("CENTER", reader, "BOTTOMLEFT", x / scale, y / scale)
        dim:SetAlpha(e)
    end
    local function Done()
        reader:Hide()
        if source then source:SetAlpha(1) end
        from, source = nil, nil
    end
    reader:SetScript("OnUpdate", function(_, elapsed)
        if not from then return end
        t = closing and math.max(0, t - elapsed / READ.time) or math.min(1, t + elapsed / READ.time)
        Place()
        if closing and t == 0 then Done() end
    end)
    function reader:Read(f)
        self:SetFrameLevel(screen:GetFrameLevel() + 40)  -- (again: the board's own level changes when it opens)
        sheet:SetFrameLevel(self:GetFrameLevel() + 1)
        local width = math.floor(math.min(READ.width, (self:GetHeight() - 40) / READ.aspect))
        local w, h = width, math.floor(width * READ.aspect)
        sheet.artShrink = 0
        local e = f.poster.extra
        sheet.tierShown = e and (e.ends > 0 or e.limit > 0) or false
        sheet.single = f.poster.goal <= 1
        sheet:SetScale(1)  -- (text measures differently at another scale: it's left small from the last one read)
        if not self:IsShown() then  -- (shown first, though not seen yet: text on a hidden frame isn't laid out to measure)
            self:SetAlpha(0)
            self:Show()
        end
        LayOut(sheet, w, h)
        DrawPoster(sheet, f.poster, f.claimers)
        -- (the story whole, always: a taller sheet when it needs more lines than there's room for)
        sheet.desc:SetHeight(1000)  -- (a tall box: nothing cut, its real height)
        local need = math.ceil(sheet.desc:GetStringHeight())
        -- (and at least its lines counted by hand: each line of it as wide as it is, wrapped at the sheet's width)
        local text, desc = sheet.desc:GetText() or "", sheet.desc
        local _, size = desc:GetFont()
        local lines, width = 0, desc:GetWidth()
        for line in (text .. "\n"):gmatch("(.-)\n") do
            desc:SetText(line)
            local wide = desc.GetUnboundedStringWidth and desc:GetUnboundedStringWidth() or desc:GetStringWidth()
            lines = lines + math.max(1, math.ceil(wide / math.max(1, width - 4)))
        end
        desc:SetText(text)
        need = math.max(need, math.ceil(lines * (size + desc:GetSpacing() + 1)))
        if (sheet.objective:GetText() or "") ~= "" then  -- (and its underline)
            need = need + OBJECTIVE.gap + math.ceil(sheet.objective:GetStringHeight()) + 3
        end
        if need + 4 > sheet.descRoom then
            h = math.min(h + need + 4 - sheet.descRoom, math.floor(self:GetHeight() - 16))
            LayOut(sheet, w, h)
            -- (no taller than the window: then a smaller picture, down to half, so the story still fits whole)
            if need + 4 > sheet.descRoom then
                sheet.artShrink = math.min(need + 4 - sheet.descRoom, math.floor(sheet.artWidth / 2))
                LayOut(sheet, w, h)
            end
            DrawPoster(sheet, f.poster, f.claimers)
        else
            sheet.desc:SetHeight(sheet.descRoom)
        end
        local x, y = f:GetCenter()
        if source then source:SetAlpha(1) end
        from = { x = x - self:GetLeft(), y = y - self:GetBottom(), scale = f:GetWidth() / w, tilt = f.tilt or 0,
            mirror = f.mirror, pin = f.pinX }
        source, t, closing = f, 0, false
        f:SetAlpha(0)
        self:SetAlpha(1)
        self:Show()
        Place()
    end
    function reader:Close(now)
        if not self:IsShown() then return end
        closing = true
        if now then Done() end
    end
    -- (its data again, when the board is redrawn)
    function reader:Redraw()
        if self:IsShown() and source and source.poster and not closing then DrawPoster(sheet, source.poster, source.claimers) end
    end
    reader:SetScript("OnMouseUp", function(self) self:Close() end)
    reader:EnableKeyboard(true)
    reader:SetScript("OnKeyDown", function(self, key)
        local escape = key == "ESCAPE"
        if not InCombatLockdown() then self:SetPropagateKeyboardInput(not escape) end
        if escape then self:Close() end
    end)
    return reader
end

-- How a poster is nailed up this week, the same every time (from key): whether its sheet is mirrored, its nail's
-- offset from the middle and its own offset from its place in the row (pixels). Its tilt comes from the nail (Hang).
local function Askew(key, w)
    local seed = 5381
    for i = 1, #key do seed = (seed * 33 + key:byte(i)) % 2147483647 end
    local function Roll() seed = (seed * 16807) % 2147483647 return seed / 2147483647 end
    return Roll() < 0.5, math.floor((Roll() * 2 - 1) * w * 0.06 + 0.5),
        math.floor((Roll() * 2 - 1) * 6), math.floor((Roll() * 2 - 1) * 10)
end

-- A poster hangs from its one nail: it turns round the nail until its middle is right under it, so a nail off to one
-- side tilts it that way (rest, in degrees clockwise), and it swings there a little when the board opens or the mouse
-- nudges it, slowing down until it rests (f.hang = { x, y: its place untilted, w, h, mirror, pin, rest, swing, t }).
local SWING = { period = 1.3, fade = 0.5, open = 1.5 }  -- (seconds a swing; seconds to fade; degrees)
local function NailAt(h, w)  -- (the nail's middle, from the poster's top)
    return math.floor(h * 0.02) + math.min(22, math.floor(w * 0.14)) / 2
end
local function Hang(f, angle)
    local g = f.hang
    LayOut(f, g.w, g.h, angle, g.mirror, g.pin)
    -- (turned round its middle, the nail would move: back by as much, so it turns round the nail)
    local a = math.rad(angle)
    local nx, ny = g.pin, g.h / 2 - NailAt(g.h, g.w)
    local tx, ty = nx * math.cos(a) + ny * math.sin(a), ny * math.cos(a) - nx * math.sin(a)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", g.x + nx - tx, g.y + ny - ty)
    f.tilt = angle  -- (the reader takes it off the board from there)
end
local function Swinging(f, elapsed)
    local g = f.hang
    if not g or g.swing == 0 then return end
    g.t = g.t + elapsed
    local amp = g.swing * math.exp(-g.t / SWING.fade)
    if amp < 0.05 then g.swing = 0 Hang(f, g.rest) return end
    Hang(f, g.rest + amp * math.sin(g.t * 2 * math.pi / SWING.period))
end
local function Nudge(f, degrees)
    if not f.hang then return end
    f.hang.swing, f.hang.t = degrees, 0
end

-- Officer view ----------------------------------------------------------------------------------------------------------

-- The catalogue menu for a pick: the rotation, then each tier's posters (for a bracket, or for everyone).
local function PickMenu(owner, bracket, onPick)
    if not MenuUtil then return end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateButton("|cff999999Rotation|r", function() onPick(nil) end)
        for _, group in ipairs(ns.PosterCatalogue(bracket)) do
            local sub = root:CreateButton(group.tier:upper())
            for _, id in ipairs(group.ids) do
                local poster = ns.PosterBounty(id)
                if poster then sub:CreateButton(poster.name, function() onPick({ id = id }) end) end
            end
        end
    end)
end

local function PickName(pick)
    local poster = pick and ns.PosterBounty(pick.id)
    return poster and poster.name or "|cff999999rotation|r"
end

-- The officer view: a dark panel over the board, width x height.
local function BuildOfficer(board, width, height)
    local o = CreateFrame("Frame", nil, board)
    o:SetSize(width, height)
    o:SetPoint("TOP", 0, -(LAYOUT.counter.y))
    o:Hide()
    local back = o:CreateTexture(nil, "BACKGROUND")
    back:SetAllPoints()
    back:SetColorTexture(0.06, 0.04, 0.03, 0.82)
    o.heading = Text(o, 20, GOLD)
    o.heading:SetPoint("TOPLEFT", 14, -10)
    o.heading:SetText("Next week's posters")
    UI.OutlineText(o.heading, { 0, 0, 0 })
    o.back = Button(o, 110, 24)
    o.back:SetPoint("TOPRIGHT", -12, -10)
    o.back.text:SetText("THIS WEEK")
    o.back.action = function() board.officer = false board:Refresh() end
    local label = Text(o, 14, DIM)
    label:SetPoint("TOPLEFT", 14, -48)
    label:SetText("Title")
    o.edit = CreateFrame("EditBox", nil, o, "InputBoxTemplate")
    o.edit:SetSize(width - 90, 22)
    o.edit:SetPoint("TOPLEFT", 64, -44)
    o.edit:SetAutoFocus(false)
    o.edit:SetMaxLetters(40)
    o.edit:SetScript("OnTextChanged", function(self, user) if user then board.draft.title = self:GetText() end end)
    o.edit:SetScript("OnEnterPressed", o.edit.ClearFocus)
    o.edit:SetScript("OnEscapePressed", o.edit.ClearFocus)
    o.rows = {}
    local rowTop, rowH = 78, math.floor((height - 78 - 44) / 5)
    for slot = 1, 5 do
        local row = CreateFrame("Frame", nil, o)
        row:SetPoint("TOPLEFT", 12, -(rowTop + (slot - 1) * rowH))
        row:SetSize(width - 24, rowH - 6)
        local rback = row:CreateTexture(nil, "BACKGROUND")
        rback:SetAllPoints()
        rback:SetColorTexture(1, 1, 1, 0.05)
        row.n = Text(row, 20, GOLD)
        row.n:SetPoint("TOPLEFT", 8, -6)
        row.n:SetText(slot)
        row.mode = Button(row, 96, 22, 12)
        row.mode:SetPoint("TOPLEFT", 32, -6)
        row.mode.lines = { "Who this slot is for", "EVERYONE: one bounty for every level. BY LEVEL: one per level bracket." }
        row.mode.action = function()
            local d = board.draft[slot]
            board.draft[slot] = (d and d.byBracket) and false or { byBracket = {} }
            board:Refresh()
        end
        row.all = Button(row, width - 24 - 146, 22, 13)
        row.all:SetPoint("TOPLEFT", 136, -6)
        row.all.action = function(self)
            PickMenu(self, nil, function(pick) board.draft[slot] = pick and { all = pick } or false board:Refresh() end)
        end
        row.brackets = {}
        local bw = math.floor((width - 24 - 136) / 3)
        for i = 1, #ns.POSTER_BRACKETS do
            local b = Button(row, bw - 4, 20, 11)
            b:SetPoint("TOPLEFT", 136 + ((i - 1) % 3) * bw, -4 - math.floor((i - 1) / 3) * 22)
            b.action = function(self)
                PickMenu(self, i, function(pick)
                    local d = board.draft[slot]
                    if not (d and d.byBracket) then d = { byBracket = {} } board.draft[slot] = d end
                    d.byBracket[i] = pick
                    board:Refresh()
                end)
            end
            row.brackets[i] = b
        end
        o.rows[slot] = row
    end
    o.send = Button(o, 150, 26)
    o.send:SetPoint("BOTTOMRIGHT", -12, 10)
    o.send.text:SetText("SEND TO GUILD")
    o.send.lines = { "Send next week's posters", "Every guildmate's board gets them; empty picks stay the rotation's." }
    o.send.action = function()
        local list = {}
        for slot = 1, 5 do
            local d = board.draft[slot]
            list[slot] = d and (d.all or (d.byBracket and { byBracket = d.byBracket })) or false
        end
        if ns.SetPosters(board.nextWeek, list, board.draft.title) then
            ns.Print("Next week's bounty posters sent to the guild.")
            board.officer = false
        end
        board:Refresh()
    end
    o.hint = Text(o, 12, DIM)
    o.hint:SetPoint("BOTTOMLEFT", 14, 16)
    o.hint:SetWidth(width - 190)
    o.hint:SetText("Empty picks are filled by the rotation.")
    return o
end

local function DrawOfficer(board)
    local o, count = board.officerView, math.max(3, math.min(5, ns.Config("bountyPosters")))
    if not o.edit:HasFocus() then o.edit:SetText(board.draft.title or "") end
    for slot, row in ipairs(o.rows) do
        row:SetShown(slot <= count)
        local d = board.draft[slot]
        local byLevel = d and d.byBracket ~= nil
        row.mode.text:SetText(byLevel and "BY LEVEL" or "EVERYONE")
        row.all:SetShown(not byLevel)
        row.all.text:SetText(PickName(d and d.all))
        for i, b in ipairs(row.brackets) do
            b:SetShown(byLevel)
            b.text:SetText(("%s: %s"):format(ns.BracketName(i), PickName(byLevel and d.byBracket[i])))
        end
    end
end

-- Officers' own posters ---------------------------------------------------------------------------------------------

-- The maker: the guild master or an officer makes a poster (a bounty to hunt, its goal, a headline and a story, how
-- long it stays up) and hammers it onto this week's board where they like (screen:Place). maker:Open().
-- How long one stays up (hours; none: till the reset): from a guild event's half hour to days.
local LASTS = { { "Until the reset" }, { "30 minutes", 0.5 }, { "1 hour", 1 }, { "2 hours", 2 }, { "3 hours", 3 },
    { "6 hours", 6 }, { "12 hours", 12 }, { "1 day", 24 }, { "2 days", 48 }, { "3 days", 72 }, { "5 days", 120 } }
local function BuildMaker(screen)
    local m = CreateFrame("Frame", nil, screen)
    m:SetSize(640, 404)
    m:SetPoint("CENTER")
    m:EnableMouse(true)
    m:Hide()
    local back = m:CreateTexture(nil, "BACKGROUND")
    back:SetAllPoints()
    back:SetColorTexture(0.06, 0.04, 0.03, 0.92)
    local heading = Text(m, 20, GOLD)
    heading:SetPoint("TOPLEFT", 14, -10)
    heading:SetText("Make a poster")
    UI.OutlineText(heading, { 0, 0, 0 })
    local function Label(text, y)
        local l = Text(m, 14, DIM)
        l:SetPoint("TOPLEFT", 14, -y)
        l:SetText(text)
    end
    local function Edit(y, width, letters, numeric)
        local e = CreateFrame("EditBox", nil, m, "InputBoxTemplate")
        e:SetSize(width, 22)
        e:SetPoint("TOPLEFT", 110, -(y - 4))
        e:SetAutoFocus(false)
        e:SetMaxLetters(letters)
        e:SetNumeric(numeric and true or false)
        e:SetScript("OnEnterPressed", e.ClearFocus)
        e:SetScript("OnEscapePressed", e.ClearFocus)
        return e
    end
    Label("Hunt", 50)
    m.target = Button(m, 310, 22, 13)
    m.target:SetPoint("TOPLEFT", 106, -46)
    m.target.lines = { "What it's for", "Any bounty or wanted boss: it counts like that one." }
    m.target.action = function(self)
        PickMenu(self, nil, function(pick) m.pick = pick and pick.id m:Draw() end)
    end
    Label("Goal", 84)
    m.goal = Edit(84, 60, 4, true)
    m.goalHint = Text(m, 12, DIM)
    m.goalHint:SetPoint("LEFT", m.goal, "RIGHT", 10, 0)
    Label("Headline", 116)
    m.top = Edit(116, 110, 8)
    m.topHint = Text(m, 12, DIM)
    m.topHint:SetPoint("LEFT", m.top, "RIGHT", 10, 0)
    m.topHint:SetText("over the picture (BOUNTY if empty)")
    Label("Name", 148)
    m.headline = Edit(148, 300, 32)
    Label("Story", 180)
    m.story = Edit(180, 300, 160)
    Label("Stays up", 214)
    m.lasts = Button(m, 150, 22, 13)
    m.lasts:SetPoint("TOPLEFT", 106, -210)
    Label("Claims", 246)
    m.limit = Edit(246, 60, 3, true)
    m.limitHint = Text(m, 12, DIM)
    m.limitHint:SetPoint("LEFT", m.limit, "RIGHT", 10, 0)
    m.limitHint:SetText("claims till it comes down (empty: none)")
    Label("Story style", 278)
    m.loudButton = Button(m, 150, 22, 13)
    m.loudButton:SetPoint("TOPLEFT", 106, -274)
    m.loudButton.lines = { "How the story looks", "Big and red: like a wanted poster's SMASH. Best for a few words." }
    m.loudButton.action = function() m.loud = not m.loud m:Draw() end
    m.lasts.lines = { "How long it hangs", "It comes down with the weekly reset at the latest." }
    m.lasts.action = function(self)
        if not MenuUtil then m.lastsIndex = m.lastsIndex % #LASTS + 1 return m:Draw() end
        MenuUtil.CreateContextMenu(self, function(_, root)
            for i, option in ipairs(LASTS) do
                root:CreateButton(option[1], function() m.lastsIndex = i m:Draw() end)
            end
        end)
    end
    m.cancel = Button(m, 110, 26)
    m.cancel:SetPoint("BOTTOMLEFT", 12, 12)
    m.cancel.text:SetText("CANCEL")
    m.cancel.action = function() m:Hide() end
    m.hammer = Button(m, 170, 26)
    m.hammer:SetPoint("BOTTOMRIGHT", -12, 12)
    m.hammer.text:SetText("HAMMER IT UP")
    m.hammer.lines = { "Nail it on the board", "Then click where it goes, anywhere on the board (right-click: not now)." }
    -- Its own picture (optional): an ogre from any of the layers, seen as it'll be; none, the bounty's.
    local PIC = { x = 452, y = 46, size = 168 }
    local picLabel = Text(m, 14, DIM)
    picLabel:SetPoint("TOPLEFT", PIC.x, -(PIC.y - 20))
    picLabel:SetText("Picture")
    local frameBack = m:CreateTexture(nil, "BORDER")
    frameBack:SetPoint("TOPLEFT", PIC.x, -PIC.y)
    frameBack:SetSize(PIC.size, PIC.size)
    frameBack:SetColorTexture(0.86, 0.78, 0.62, 0.9)
    m.canvas = CreateFrame("Frame", nil, m)
    m.canvas:SetPoint("TOPLEFT", PIC.x, -PIC.y)
    m.canvas:SetSize(PIC.size, PIC.size)
    m.none = Text(m, 12, INK_DIM, "CENTER")
    m.none:SetPoint("CENTER", frameBack)
    m.none:SetWidth(PIC.size - 20)
    m.none:SetWordWrap(true)
    m.none:SetText("The bounty's own picture")
    m.layerButtons = {}
    local bw = math.floor((PIC.size - 4) / 2)
    for i, layer in ipairs(ns.MintLayers or {}) do
        local b = Button(m, bw, 18, 11)
        b:SetPoint("TOPLEFT", PIC.x + ((i - 1) % 2) * (bw + 4), -(PIC.y + PIC.size + 6 + math.floor((i - 1) / 2) * 20))
        b.lines = { layer.name, "Pick one, or none" }
        b.action = function(self)
            if not MenuUtil then return end
            MenuUtil.CreateContextMenu(self, function(_, root)
                if root.SetScrollMode then root:SetScrollMode(360) end
                root:CreateButton("|cff999999None|r", function() m:SetLayer(layer.key, nil) end)
                for _, option in ipairs(layer.options) do
                    if not option.retired then
                        local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[({ uncommon = 2, rare = 3, epic = 4, legendary = 5 })[option.rarity] or 1]
                        root:CreateButton((color and color.hex or "") .. option.name .. "|r", function() m:SetLayer(layer.key, option.id) end)
                    end
                end
            end)
        end
        b.layer = layer
        m.layerButtons[i] = b
    end
    local rows = math.ceil(#m.layerButtons / 2)
    m.random = Button(m, bw, 20, 11)
    m.random:SetPoint("TOPLEFT", PIC.x, -(PIC.y + PIC.size + 10 + rows * 20))
    m.random.text:SetText("RANDOM")
    m.random.lines = { "A random ogre", "One of each layer (no background)" }
    m.random.action = function()
        local traits = {}
        for _, layer in ipairs(ns.MintLayers or {}) do
            local options = {}
            for _, option in ipairs(layer.options) do if not option.retired then options[#options + 1] = option end end
            if layer.key ~= "background" and #options > 0 then traits[layer.key] = options[math.random(#options)].id end
        end
        m.picture = traits
        m:Draw()
    end
    m.clear = Button(m, bw, 20, 11)
    m.clear:SetPoint("LEFT", m.random, "RIGHT", 4, 0)
    m.clear.text:SetText("NONE")
    m.clear.lines = { "No picture of its own", "The poster shows its bounty's picture." }
    m.clear.action = function() m.picture = nil m:Draw() end
    function m:SetLayer(key, id)
        self.picture = self.picture or {}
        self.picture[key] = id
        if not next(self.picture) then self.picture = nil end
        self:Draw()
    end
    m.hammer.action = function()
        if not m.pick then return end
        local goal = tonumber(m.goal:GetText())
        m:Hide()
        screen:Place({ id = m.pick, goal = goal and goal > 0 and goal or nil, headline = m.headline:GetText(), top = m.top:GetText(), limit = tonumber(m.limit:GetText()),
            picture = m.picture, loud = m.loud,
            text = m.story:GetText(), hours = LASTS[m.lastsIndex][2] })
    end
    function m:Draw()
        local poster = self.pick and ns.PosterBounty(self.pick)
        self.target.text:SetText(poster and poster.name or "pick one...")
        self.goalHint:SetText(poster and ("usually %d"):format(ns.PosterGoal(poster, nil, 1)) or "")
        self.lasts.text:SetText(LASTS[self.lastsIndex][1])
        self.loudButton.text:SetText(self.loud and "BIG AND RED" or "PLAIN")
        self.hammer:SetAlpha(poster and 1 or 0.5)
        -- (the picture as it'll be)
        self.none:SetShown(not self.picture)
        self.canvas:SetShown(self.picture and true or false)
        if self.picture then
            self.canvas:SetFrameLevel(self:GetFrameLevel() + 2)
            ns.RenderMint(self.canvas, self.picture, 0)
        end
        for _, b in ipairs(self.layerButtons) do
            local id = self.picture and self.picture[b.layer.key]
            local name = b.layer.name
            for _, option in ipairs(b.layer.options) do if option.id == id then name = option.name end end
            b.text:SetText(id and name or (b.layer.name .. ": none"))
        end
    end
    function m:Open()
        self:SetFrameLevel(screen:GetFrameLevel() + 45)
        self.pick, self.lastsIndex, self.picture, self.loud = nil, 1, nil, false
        self.goal:SetText("")
        self.headline:SetText("")
        self.top:SetText("")
        self.limit:SetText("")
        self.story:SetText("")
        self:Draw()
        self:Show()
    end
    return m
end

-- Where the officers' posters hang: their nails on the board, from just under the counter's reward notes down to its
-- bottom beam and out to its posts (FRAME); a low one hangs down past the board, over the week's posters too
-- (screen.area = { left, right, top, bottom }, pixels from the screen's top-left, set by Refresh); a nail at x, y
-- (0-1000 across it) and back.
local function AreaPoint(area, x, y)
    return area.left + (area.right - area.left) * x / 1000, area.top + (area.bottom - area.top) * y / 1000
end
local function AreaFraction(area, px, py)
    local x = (px - area.left) / math.max(1, area.right - area.left) * 1000
    local y = (py - area.top) / math.max(1, area.bottom - area.top) * 1000
    return math.floor(math.max(0, math.min(1000, x)) + 0.5), math.floor(math.max(0, math.min(1000, y)) + 0.5)
end
-- The cursor, in pixels from the screen's top-left.
local function Cursor(screen)
    local cx, cy = GetCursorPosition()
    local scale = screen:GetEffectiveScale()
    return cx / scale - screen:GetLeft(), screen:GetTop() - cy / scale
end
-- An officer's poster hung with its nail at x, y of the area.
local function HangAt(f, x, y)
    local g = f.hang
    local px, py = AreaPoint(f.area, x, y)
    g.x, g.y = px - g.w / 2 - g.pin, -(py - NailAt(g.h, g.w))
    Hang(f, g.rest)
end

-- Hammering one up: it follows the mouse over the area, the area lit; a click nails it there, a right-click (or Escape)
-- doesn't. Officers move theirs by dragging, and take one down from its right-click menu.
local function AttachExtras(screen)
    screen.maker = BuildMaker(screen)
    local placer = CreateFrame("Frame", nil, screen)
    placer:SetAllPoints()
    placer:EnableMouse(true)
    placer:Hide()
    placer.lit = placer:CreateTexture(nil, "BACKGROUND")
    placer.lit:SetColorTexture(1, 0.86, 0.6, 0.08)
    placer.hint = Text(placer, 14, CREAM, "CENTER")
    UI.OutlineText(placer.hint, { 0.12, 0.07, 0.03 })
    placer.hint:SetText("Click where it goes  ·  right-click: not now")
    local ghost = Poster(placer)
    ghost:EnableMouse(false)
    ghost:SetAlpha(0.85)
    local function Follow()
        local area = screen.area
        local x, y = AreaFraction(area, Cursor(screen))
        ghost.area = area
        HangAt(ghost, x, y)
        return x, y
    end
    placer:SetScript("OnUpdate", Follow)
    placer:SetScript("OnMouseUp", function(self, mouse)
        self:Hide()
        if mouse ~= "LeftButton" then return end
        local x, y = Follow()
        local e = self.extra
        e.x, e.y = x, y
        if ns.AddPosterExtra(e) then
            screen.hammered = true  -- (Refresh swings the newest one, with a knock or two)
            UI.ClickSound()
            C_Timer.After(0.14, UI.ClickSound)
            screen:Refresh()
        end
    end)
    placer:EnableKeyboard(true)
    placer:SetScript("OnKeyDown", function(self, key)
        local escape = key == "ESCAPE"
        if not InCombatLockdown() then self:SetPropagateKeyboardInput(not escape) end
        if escape then self:Hide() end
    end)
    function screen:Place(extra)
        local area = self.area
        if not area or not self.extraSize then return end
        placer:SetFrameLevel(self:GetFrameLevel() + 30)
        placer.extra = extra
        placer.lit:ClearAllPoints()
        placer.lit:SetPoint("TOPLEFT", self, "TOPLEFT", area.left, -area.top)
        placer.lit:SetPoint("BOTTOMRIGHT", self, "TOPLEFT", area.right, -area.bottom)
        placer.hint:ClearAllPoints()
        placer.hint:SetPoint("BOTTOM", placer.lit, "TOP", 0, 4)
        -- (drawn as it will look: its own headline and story over the bounty's)
        local base = ns.PosterBounty(extra.id)
        local headline = extra.headline and extra.headline:match("%S") and extra.headline
        local top = extra.top and extra.top:match("%S") and extra.top:upper():sub(1, 8)
        local bounty = setmetatable({ name = headline or base.name, short = headline or base.short, tagline = top },
            { __index = base })
        local w, h = self.extraSize[1], self.extraSize[2]
        local mirror, pin = Askew("new", w)
        ghost.hang = { swing = 0, t = 0, w = w, h = h, mirror = mirror, pin = pin,
            rest = -math.deg(math.atan(pin / (h / 2 - NailAt(h, w)))) }
        LayOut(ghost, w, h, 0, mirror, pin)
        DrawPoster(ghost, { id = extra.id, bounty = bounty, tier = base.tier, goal = ns.PosterGoal(base, extra.goal, 1),
            have = 0, extra = { id = extra.id, ends = extra.hours and 1 or 0, limit = extra.limit or 0, picture = extra.picture },
            claims = 0 })
        placer:Show()
        Follow()
    end
    -- Dragging one of theirs (officers): it follows the mouse; let go, it's nailed there.
    function screen:Drag(f)
        if not (f.extra and ns.CanEditConfig()) then return end
        self.dragging = f
        f.hang.swing = 0
    end
    function screen:Drop(f)
        if self.dragging ~= f then return end
        self.dragging = nil
        local x, y = AreaFraction(self.area, Cursor(self))
        UI.ClickSound()
        ns.MovePosterExtra(f.extra.tag, x, y)
        self:Refresh()
    end
    function screen:Dragged()
        local f = self.dragging
        if f then HangAt(f, AreaFraction(self.area, Cursor(self))) end
    end
    -- Its right-click menu (officers): take it down.
    function screen:ExtraMenu(f)
        if not (f.extra and ns.CanEditConfig() and MenuUtil) then return end
        MenuUtil.CreateContextMenu(f, function(_, root)
            root:CreateTitle(f.poster and f.poster.bounty.name or "Poster")
            root:CreateButton("Take it down", function()
                ns.RemovePosterExtra(f.extra.tag)
                self:Refresh()
            end)
        end)
    end
end

-- The screen ------------------------------------------------------------------------------------------------------------

local screen

local function BuildCounter(parent, width)
    local counter = CreateFrame("Frame", nil, parent)
    counter:SetSize(width, LAYOUT.counter.h + 16)
    counter:SetPoint("TOPLEFT", parent:GetWidth() * LAYOUT.counter.posts[1], -LAYOUT.counter.y)
    counter:EnableMouse(true)
    -- Over the beam, burned into the board: the guild's claims and yours.
    -- (over the beam, lettered like the plank's title, or woodburned: up to the reset note, or in the middle)
    counter.total = Text(counter, 26, CREAM, "RIGHT")
    counter.total:SetPoint("BOTTOM", counter, "TOP", 0, -19)
    UI.OutlineText(counter.total, { 0.12, 0.07, 0.03 })
    counter.burn = BurnText(counter, 28)
    counter.burn:SetPoint("BOTTOM", counter, "TOP", 0, -19)
    counter.bar = PaintedBar(counter, width, LAYOUT.counter.bar)
    counter.bar:SetPoint("TOPLEFT", 0, -20)
    -- Under it, a note nailed at each milestone: its reward and its claims, sepia like a poster until it's reached.
    counter.marks = {}
    local N = LAYOUT.note
    for i, mile in ipairs(ns.POSTER_MILESTONES) do
        local mark = CreateFrame("Frame", nil, counter)
        mark:SetSize(N.w, N.h)
        mark:SetFrameLevel(counter.bar:GetFrameLevel() + 2)
        local tilt = math.rad(({ -4, 3, -2, 4, -3 })[(i - 1) % 5 + 1])
        mark.sheet = mark:CreateTexture(nil, "BACKGROUND")
        mark.sheet:SetTexture(BOARD .. "poster")
        mark.sheet:SetAllPoints()
        if i % 2 == 0 then mark.sheet:SetTexCoord(1, 0, 0, 1) end
        mark.sheet:SetRotation(tilt)
        mark.pin = mark:CreateTexture(nil, "OVERLAY")
        mark.pin:SetTexture(BOARD .. "pin")
        mark.pin:SetSize(11, 11)
        mark.pin:SetPoint("TOP", 0, -1)
        mark.icon = mark:CreateTexture(nil, "ARTWORK")
        mark.icon:SetSize(24, 24)
        mark.icon:SetPoint("TOP", 0, -12)
        mark.icon:SetTexture(mile.guildChest and (BOARD .. "chest") or (mile.fuel and ns.IngredientIcon and ns.IngredientIcon(mile.fuel))
            or "Interface\\MoneyFrame\\UI-GoldIcon")
        mark.icon:SetRotation(tilt)
        mark.text = Text(mark, 16, INK, "CENTER")
        mark.text:SetPoint("BOTTOM", 0, 7)
        mark.mile = mile
        mark:EnableMouse(true)
        mark:SetScript("OnEnter", function(self)
            Tooltip(self, { ("%d guild bounties"):format(ns.MilestoneClaims(mile)), ("+%d points%s%s"):format(mile.points,
                mile.fuel and (" and " .. ns.IngredientName(mile.fuel)) or "", mile.guildChest and " and the guild bounty chest" or ""),
                "For everyone who has claimed a bounty this week" })
        end)
        mark:SetScript("OnLeave", GameTooltip_Hide)
        counter.marks[i] = mark
    end
    counter:SetScript("OnEnter", function(self)
        local guild = ns.GetGuildClaims()
        if not guild then return end
        local lines = { ("Guild bounties claimed this week: %d"):format(guild.total),
            "Everyone who has claimed a bounty gets each milestone's reward." }
        for i, mile in ipairs(ns.POSTER_MILESTONES) do
            lines[#lines + 1] = ("%s %d: +%d points%s%s"):format(i <= guild.reached and "|cffffd100done|r" or "-",
                ns.MilestoneClaims(mile), mile.points, mile.fuel and (" and " .. ns.IngredientName(mile.fuel)) or "",
                mile.guildChest and " and the guild bounty chest" or "")
        end
        for _, member in ipairs(guild.members) do lines[#lines + 1] = ("%s: %d"):format(member.name, member.count) end
        Tooltip(self, lines)
    end)
    counter:SetScript("OnLeave", GameTooltip_Hide)
    return counter
end

local function Build()
    screen = CreateFrame("Frame", "SOLCBountyScreen", UIParent)
    screen:EnableMouse(true)
    screen:Hide()
    screen:SetScript("OnHide", function()
        if ns.UI.ClearScreen then ns.UI.ClearScreen("Bounty Board") end
        screen.reader:Close(true)
        if screen.onClose then screen.onClose() end
    end)
    screen.backdrop = screen:CreateTexture(nil, "BACKGROUND")
    screen.backdrop:SetAllPoints()
    screen.backdrop:SetTexture(BOARD .. "backdrop")
    screen.backdrop:SetVertexColor(0.62, 0.58, 0.54)  -- (darker: the posters stand out)
    -- A soft vignette: darker towards the edges.
    for _, side in ipairs({ "LEFT", "RIGHT", "TOP", "BOTTOM" }) do
        local v = screen:CreateTexture(nil, "BACKGROUND", nil, 1)
        v:SetColorTexture(1, 1, 1)
        local horizontal = side == "LEFT" or side == "RIGHT"
        v:SetPoint(side)
        if horizontal then v:SetPoint("TOP") v:SetPoint("BOTTOM") v:SetWidth(140) else v:SetPoint("LEFT") v:SetPoint("RIGHT") v:SetHeight(90) end
        local dark, clear = CreateColor(0, 0, 0, 0.55), CreateColor(0, 0, 0, 0)
        if side == "LEFT" then v:SetGradient("HORIZONTAL", dark, clear)
        elseif side == "RIGHT" then v:SetGradient("HORIZONTAL", clear, dark)
        elseif side == "TOP" then v:SetGradient("VERTICAL", clear, dark)
        else v:SetGradient("VERTICAL", dark, clear) end
    end
    -- The plank with the week's title, and the bracket under it.
    -- (in three slices: the painting is 3:1, its ends with the nails kept in shape, the plain middle stretched; darkened so
    -- the title stands out)
    screen.plank = CreateFrame("Frame", nil, screen)
    screen.plank:SetSize(LAYOUT.plank.w, LAYOUT.plank.h)
    screen.plank:SetPoint("TOP", 0, -LAYOUT.plank.y)
    local cap = LAYOUT.plank.h * 0.5  -- (each end: a sixth of the 3:1 painting, half its height)
    for i, part in ipairs({ { 0, 1 / 6, "LEFT" }, { 1 / 6, 5 / 6 }, { 5 / 6, 1, "RIGHT" } }) do
        local t = screen.plank:CreateTexture(nil, "ARTWORK")
        t:SetTexture(BOARD .. "plank")
        t:SetTexCoord(part[1], part[2], 0, 1)
        t:SetVertexColor(0.62, 0.5, 0.4)
        t:SetHeight(LAYOUT.plank.h)
        if part[3] then
            t:SetWidth(cap)
            t:SetPoint(part[3])
        else
            t:SetPoint("LEFT", cap, 0)
            t:SetPoint("RIGHT", -cap, 0)
        end
    end
    screen.title = Text(screen.plank, 32, CREAM, "CENTER")  -- (on the plank: a frame, it would cover the screen's own text)
    local panel = LAYOUT.plank.h * (LAYOUT.plank.panel[1] + LAYOUT.plank.panel[2]) / 2  -- (its middle, from the top)
    screen.title:SetPoint("CENTER", screen.plank, "TOP", 0, -panel + 1)
    UI.OutlineText(screen.title, { 0.12, 0.07, 0.03 })
    -- The time to the reset, on a note nailed into the top beam right of the plank (the brackets aren't told: the posters just fit you).
    local R = LAYOUT.reset
    screen.reset = CreateFrame("Frame", nil, screen)
    screen.reset:SetSize(R.w, R.h)
    screen.reset.sheet = screen.reset:CreateTexture(nil, "BACKGROUND")
    screen.reset.sheet:SetTexture(BOARD .. "poster")
    screen.reset.sheet:SetAllPoints()
    screen.reset.sheet:SetTexCoord(1, 0, 0, 1)
    screen.reset.sheet:SetRotation(math.rad(R.tilt))
    screen.reset.sheet:SetVertexColor(0.86, 0.82, 0.76)
    local nail = screen.reset:CreateTexture(nil, "OVERLAY")
    nail:SetTexture(BOARD .. "pin")
    nail:SetSize(11, 11)
    nail:SetPoint("TOP", 2, -2)
    local heading = Text(screen.reset, 11, INK_DIM, "CENTER")
    heading:SetPoint("TOP", 0, -15)
    heading:SetText("NEW BOUNTIES")
    screen.meta = Text(screen.reset, 16, INK, "CENTER")
    screen.meta:SetPoint("TOP", heading, "BOTTOM", 0, -3)
    screen.posters = {}
    for i = 1, 5 + MAX_EXTRAS do screen.posters[i] = Poster(screen) end  -- (the week's, then the officers' own)
    screen.reader = BuildReader(screen)
    AttachExtras(screen)
    screen:SetScript("OnUpdate", function(self, elapsed)
        for _, f in ipairs(self.posters) do if f:IsShown() and self.dragging ~= f then Swinging(f, elapsed) end end
        self:Dragged()
        -- (every half minute while an officer's timed poster is up: it comes down on time, its time left kept right)
        self.tick = (self.tick or 0) + elapsed
        if self.tick >= 30 then
            self.tick = 0
            local timed = false
            for _, f in ipairs(self.posters) do if f:IsShown() and f.extra and f.extra.ends > 0 then timed = true end end
            if timed and not self.dragging and not self.reader:IsShown() then self:Refresh() end
        end
    end)
    function screen:Read(f) self.reader:Read(f) end
    screen.chests = Text(screen, 15, LAMP)
    screen.chests:SetPoint("BOTTOMLEFT", 24, LAYOUT.footer + 4)
    Shade(screen.chests)
    screen.next = Button(screen, 130, 26)
    screen.next:SetPoint("BOTTOMRIGHT", -24, LAYOUT.footer)
    screen.next.text:SetText("NEXT WEEK")
    screen.next.lines = { "Pick next week's posters", "Guild master and officers" }
    screen.next.action = function()
        local week = ns.CurrentWeek() + 7
        local picks = ns.GetPosterPicks(week)
        screen.nextWeek, screen.officer = week, true
        screen.draft = { title = picks.title }
        for slot = 1, 5 do screen.draft[slot] = picks[slot] or false end
        screen:Refresh()
    end
    screen.make = Button(screen, 150, 26)
    screen.make:SetPoint("RIGHT", screen.next, "LEFT", -10, 0)
    screen.make.text:SetText("NAIL A POSTER")
    screen.make.lines = { "Make your own poster", "Guild master and officers: hammer an extra bounty onto this week's board." }
    screen.make.action = function()
        if #ns.PosterExtras() >= MAX_EXTRAS then
            ns.Print(("The board holds %d of your own posters at most: take one down first (right-click it)."):format(MAX_EXTRAS))
            return
        end
        screen.maker:Open()
    end
    screen.officer, screen.draft, screen.laidOut, screen.counter, screen.officerView = false, {}, false, false, false

    function screen:Layout()
        local width, height = self:GetWidth(), self:GetHeight()
        if self.laidOut == width .. "x" .. height then return end
        self.laidOut = width .. "x" .. height
        if self.counter then self.counter:Hide() end
        -- (the beam: from post to post, where the backdrop's posts are: its inner edges, measured on the painting)
        local posts = LAYOUT.counter.posts
        self.counter = BuildCounter(self, width * (posts[2] - posts[1]))
        -- (the reset note: halfway between the plank and the right post, where there's room for it, its nail in the
        -- backdrop's top beam: LAYOUT.reset.nail, measured on the painting)
        local room = width * posts[2] - (width / 2 + LAYOUT.plank.w / 2)
        self.resetFits = room >= LAYOUT.reset.w + 12
        self.reset:ClearAllPoints()
        self.reset:SetPoint("TOP", self, "TOPLEFT", width / 2 + LAYOUT.plank.w / 2 + room / 2, -(height * LAYOUT.reset.nail - 7))
        if self.officerView then self.officerView:Hide() end
        self.officerView = BuildOfficer(self, math.min(640, width - 80), height - LAYOUT.counter.y - LAYOUT.posters.bottom)
    end

    function screen:Refresh()
        self:Layout()
        local officer = self.officer and ns.CanEditConfig()
        self.officerView:SetShown(officer and true or false)
        self.counter:SetShown(not officer)
        for _, f in ipairs(self.posters) do f:Hide() end
        self.next:SetShown(not officer and ns.CanEditConfig() and true or false)
        self.make:SetShown(not officer and ns.CanEditConfig() and true or false)
        if officer then self.maker:Hide() end
        if officer then self.reader:Close(true) return DrawOfficer(self) end
        local b = ns.GetPosterProgress()
        if b and TEST_CLAIMED then  -- (TEMPORARY: /solc claimtest, drawn as claimed, nothing given)
            for i, p in ipairs(b.posters) do
                if TEST_CLAIMED[i] then p.claimed, p.have = p.claimed or time(), p.goal end
            end
        end
        if not b then
            self.title:SetText("Bounties are for guilds")
            self.reset:Hide()
            self.counter:Hide()
            self.chests:SetText("")
            return
        end
        Fit(self.title, NAME_FONT, 32, 18, "Bounty Board!", LAYOUT.plank.w - 90)
        self.meta:SetText(ns.BountyTimeLeft(b.resetsIn))
        self.reset:SetShown(self.resetFits)
        -- The counter.
        local guild = ns.GetGuildClaims()
        if TEST_CLAIMS then
            for i, name in ipairs(TEST_CLAIMS) do
                local ids = {}
                for j, p in ipairs(b.posters) do if j == 1 or (i <= 8 and (i + j) % 3 ~= 0) then ids[#ids + 1] = p.id end end
                guild.members[#guild.members + 1] = { name = name, count = #ids, ids = ids }
                guild.total = guild.total + #ids
            end
            for i, m in ipairs(ns.POSTER_MILESTONES) do if guild.total >= ns.MilestoneClaims(m) then guild.reached = i end end
        end
        local c = self.counter
        local last = ns.MilestoneClaims(ns.POSTER_MILESTONES[#ns.POSTER_MILESTONES])
        local header = ("BOUNTIES CLAIMED  %d / %d"):format(math.min(guild.total, last), last)
        local burned = KillTrackerDB and KillTrackerDB.bountyBurn
        c.total:SetText(burned and "" or header)
        c.burn:SetText(header)
        c.burn:SetShown(burned and true or false)
        -- (bigger than fits by the reset note in the middle: its right end just before the note)
        local noteLeft, left = self.resetFits and self.reset:GetLeft(), c:GetLeft()
        c.total:ClearAllPoints()
        if noteLeft and left then
            c.total:SetPoint("BOTTOMRIGHT", c, "TOPLEFT", noteLeft - left - 12, -21)
            c.burn:SetPoint("BOTTOMRIGHT", c, "TOPLEFT", noteLeft - left - 12, -21)
        else
            c.total:SetPoint("BOTTOM", c, "TOP", 0, -21)
            c.burn:SetPoint("BOTTOM", c, "TOP", 0, -21)
        end
        -- (from where you last saw it this week, up to now: KillTrackerDB.bountyBarSeen = { week, fraction })
        local fraction, week = TEST_FILL or guild.total / last, ns.CurrentWeek()
        if self.rise then
            local seen = KillTrackerDB and KillTrackerDB.bountyBarSeen
            c.bar:Set(seen and seen.week == week and seen.fraction or 0, true)
            self.rise = false
        end
        c.bar:Set(fraction)
        if KillTrackerDB then KillTrackerDB.bountyBarSeen = { week = week, fraction = fraction } end
        for i, mark in ipairs(c.marks) do
            local at = ns.MilestoneClaims(mark.mile)
            mark:ClearAllPoints()
            mark:SetPoint("TOP", c.bar, "BOTTOMLEFT", c.bar:At(at / last), 2)
            mark.text:SetText(tostring(at))
            local reached = i <= guild.reached
            mark.text:SetTextColor(unpack(reached and INK or INK_DIM))
            mark.icon:SetDesaturated(not reached)
            mark.icon:SetAlpha(reached and 1 or 0.7)
            mark.sheet:SetVertexColor(unpack(reached and { 1, 0.95, 0.85 } or { 0.72, 0.66, 0.58 }))
        end
        -- Who claimed which.
        local claimers = {}
        for _, member in ipairs(guild.members) do
            for _, id in ipairs(member.ids) do
                claimers[id] = claimers[id] or {}
                table.insert(claimers[id], member.name)
            end
        end
        -- The posters, in a row as big as fits.
        local P = LAYOUT.posters
        local weekly, extras = {}, {}
        for _, p in ipairs(b.posters) do table.insert(p.extra and extras or weekly, p) end
        local n = #weekly
        local width, height = self:GetWidth(), self:GetHeight()
        local roomH = height - P.top - P.bottom
        local w = math.min(P.max, math.floor((width - P.side * 2 - (n - 1) * P.gap) / n), math.floor(roomH / P.aspect))
        local h = math.floor(w * P.aspect)
        local left = (width - (n * w + (n - 1) * P.gap)) / 2
        local week = ns.CurrentWeek()
        for i, p in ipairs(weekly) do
            local f = self.posters[i]
            f.extra = nil
            local mirror, pin, dx, dy = Askew(week .. ":" .. i .. ":" .. p.id, w)
            -- (at rest its middle under the nail: turned by atan(the nail's offset / its height over the middle))
            local rest = -math.deg(math.atan(pin / (h / 2 - NailAt(h, w))))
            local g = f.hang or { swing = 0, t = 0 }
            g.x, g.y = left + (i - 1) * (w + P.gap) + dx, -(P.top + (roomH - h) * 0.3) + dy  -- (high: what room is left goes under them)
            g.w, g.h, g.mirror, g.pin, g.rest = w, h, mirror, pin, rest
            f.hang, f.mirror, f.pinX = g, mirror, pin  -- (pinX: the nail's offset; f.pin is its texture)
            if self.swingIn then Nudge(f, SWING.open * (i % 2 == 0 and -1 or 1)) end
            Hang(f, rest)
            DrawPoster(f, p, claimers[p.id])
        end
        -- The officers' own: smaller, each nailed where it was put in the area under the row (newest swinging).
        local rowTop = P.top + (roomH - h) * 0.3
        local posts = LAYOUT.counter.posts
        local ew = math.floor(w * EXTRA_SIZE)
        local eh = math.floor(ew * P.aspect)
        -- (its top: a few pixels under the reward notes, which hang 2 under the beam: BuildCounter)
        local notes = LAYOUT.counter.y + 20 + LAYOUT.counter.bar - 2 + LAYOUT.note.h
        -- (its sides and bottom: the board's frame, the posts' outer edges and its bottom beam: FRAME, measured on the painting)
        self.area = { left = width * FRAME.left, right = width * FRAME.right, top = notes + 6, bottom = height * FRAME.bottom }
        self.extraSize = { ew, eh }
        local newest
        for i, p in ipairs(extras) do
            local f = self.posters[5 + i]
            if not f then break end
            local mirror, pin = Askew(p.extra.tag, ew)
            local g = f.hang or { swing = 0, t = 0 }
            g.w, g.h, g.mirror, g.pin = ew, eh, mirror, pin
            g.rest = -math.deg(math.atan(pin / (eh / 2 - NailAt(eh, ew))))
            f.hang, f.mirror, f.pinX, f.extra, f.area = g, mirror, pin, p.extra, self.area
            if self.swingIn then Nudge(f, SWING.open * (i % 2 == 0 and 1 or -1)) end
            if not newest or p.extra.tag > newest.extra.tag then newest = f end
            if self.dragging ~= f then HangAt(f, p.extra.x, p.extra.y) end
            f:SetFrameLevel(self:GetFrameLevel() + 10 + i)  -- (over the week's posters and the notes; the later over the earlier)
            DrawPoster(f, p, claimers[p.id])
        end
        if self.hammered and newest then Nudge(newest, SWING.open * 2) end
        self.hammered = false
        self.swingIn = false
        self.reader:Redraw()
        local chests, guildChests = KillTrackerDB.bountyChests or 0, KillTrackerDB.guildBountyChests or 0
        self.chests:SetText((chests + guildChests > 0) and ("|c" .. AMBER_CODE .. "%d|r bounty chest%s%s waiting"):format(chests,
            chests == 1 and "" or "s", guildChests > 0 and (" and |cffc070ff%d guild chest%s|r"):format(guildChests,
            guildChests == 1 and "" or "s") or "") or "")
    end
end

-- The board is its own page in the sidebar (Guild: Bounties; HUNTS in ogre mode), the whole page area.
ns.RegisterPage({
    key = "bounties", label = "Bounties", section = "guild", order = 3,
    bare = true,
    create = function(parent)
        local holder = CreateFrame("Frame", nil, parent)
        holder:SetAllPoints()
        holder:SetScript("OnShow", function()
            if not screen then return end
            screen.officer = false  -- (back to this week's board)
            screen.rise = true  -- (the gold rises from where you last saw it: Refresh)
            screen.swingIn = true  -- (the posters swing a little on their nails as it opens)
        end)
        return holder
    end,
    refresh = function(holder)
        if not screen then
            Build()
            screen.rise, screen.swingIn = true, true
        end
        if screen:GetParent() ~= holder then
            screen:SetParent(holder)
            screen:ClearAllPoints()
            screen:SetAllPoints(holder)
            screen:SetFrameLevel(holder:GetFrameLevel() + 5)
        end
        screen:Show()
        screen:Refresh()
    end,
})

-- Opens the board's page.
function ns.ShowHuntsBoard() ns.OpenPage("bounties") end
function ns.RefreshHuntsBoard() if screen and screen:IsVisible() then screen:Refresh() end end
-- (TEMPORARY: /solc claimtest [n] draws this week's nth poster as claimed, or not again; no points, no chest, no feed)
function ns.ToggleClaimTest(n)
    n = tonumber(n) or 1
    local b = ns.GetPosterProgress()
    local p = b and b.posters[n]
    if not p then return ns.Print(("No poster %d this week."):format(n)) end
    TEST_CLAIMED[n] = not TEST_CLAIMED[n] or nil
    ns.Print(("%s: drawn as %s (just a look, nothing given)."):format(p.bounty.name, TEST_CLAIMED[n] and "claimed" or "not claimed"))
    ns.RefreshHuntsBoard()
end
-- (a try: the counter's header woodburned or lettered like the plank; /solc burn)
function ns.ToggleBountyBurn()
    KillTrackerDB.bountyBurn = not KillTrackerDB.bountyBurn or nil
    ns.Print(("The bounty board's header is %s."):format(KillTrackerDB.bountyBurn and "woodburned" or "lettered"))
    ns.RefreshHuntsBoard()
end
