-- The Dream Bed: the new minting. Your ogre, tucked into bed (your built ogre's head on a pillow, a quilt over the rest:
-- the minting art), a thought bubble over his head (click it: pick the piece he'll dream about, for Bedtime Stories);
-- on the nightstand a mug of Warm Milk (luck) and the candle (just the room's light: it goes out as he drops off). Ogres go to sleep by bonking their heads: the
-- mallet by the nightstand (a Bonk; one comes back each day) knocks him out. He sleeps, and the window's sky shows the luck (a shooting star, an
-- aurora, a meteor shower); in the morning he wakes, tells you his dream (DreamTeller.lua), and you paint it on your
-- easel, a layer a beat, in the edition you reach for (brush, coloured pencils, crayons); then the painting comes
-- forward, signed by you. The mint itself: ns.DreamMint (Minting.lua). The room is painted (tools/gen-dreambed-art.js)
-- and laid out by hand (tools/dreambed-room.js): DreamBedArt.lua has both.
-- Opened over the page area like the old kitchen: ns.ShowDreamBed().

local _, ns = ...

local UI = ns.UI
local W, S = {}, {}  -- widgets; state (phase, milk, story, mint, told, ...)
local NAME_FONT = "Interface\\AddOns\\SOLC\\Media\\Fonts\\GermaniaOne-Regular.ttf"
local CRAYON_FONT = "Interface\\AddOns\\SOLC\\Media\\Fonts\\FingerPaint-Regular.ttf"
local GLOW = "Interface\\AddOns\\SOLC\\Media\\DreamBed\\glow"  -- (tools/make-dreambed-fx.js: soft, fading to nothing)
local DISC = "Interface\\AddOns\\SOLC\\Media\\DreamBed\\disc"  -- (the moon and the sun)
local PARCH, INK = { 0.96, 0.93, 0.86 }, { 0.16, 0.11, 0.06 }
local RIM = { uncommon = { 0.6, 0.6, 0.6 }, rare = { 0.23, 0.54, 0.88 }, epic = { 0.6, 0.29, 0.88 }, legendary = { 0.88, 0.63, 0.13 } }
local MILK_WORDS, MILK_OGRE = { "empty", "a sip", "a mug", "brimming" }, { "NONE", "SIP", "MUG", "LOTS" }
local CHAPTERS = { { "headwear", "Hats", "HATS" }, { "outfit", "Outfits", "CLOTH" }, { "accessory", "Things he holds", "STUFF" },
    { "background", "Places", "PLACE" }, { "skin", "Ogres", "OGRE" }, { "eyes", "Eyes", "EYES" }, { "expression", "Faces", "FACE" } }
local CARDS_PER_PAGE = 8
-- Your ogre's face for each moment: eyes and expression option ids (the minting art's own).
local FACES = { asleep = { "fully_asleep", "snoring_zzz_bubble" }, yawn = { "heavy_bags", "mid_yawn" }, talk = { nil, "mouth_hanging_open" } }

local function Ogre() return KillTrackerDB and KillTrackerDB.ogreMode end
local function O(normal, ogre) return Ogre() and ogre or normal end
local function Click() if UI.ClickSound then UI.ClickSound() end end

-- Tweens: { t, duration, step(p), done }, run by the screen's OnUpdate.
local tweens = {}
local function Tween(duration, step, done) tweens[#tweens + 1] = { t = 0, d = duration, step = step, done = done } end
-- Timers on the room's own clock (run by the same OnUpdate): they wait while the room's hidden - leave mid-dream and
-- it carries on where it was when you come back - and a click can jump to the next one (Skip).
local timers = {}
local function After(seconds, fn) timers[#timers + 1] = { t = seconds, fn = fn } end
-- The room's clock: elapsed seconds for the tweens, the timers and the reel.
local function Tick(elapsed)
    for i = #tweens, 1, -1 do
        local t = tweens[i]
        if t then
            t.t = t.t + elapsed
            local p = math.min(1, t.t / t.d)
            t.step(p)
            if p >= 1 then table.remove(tweens, i) if t.done then t.done() end end
        end
    end
    local due = {}
    for i = #timers, 1, -1 do
        local timer = timers[i]
        timer.t = timer.t - elapsed
        if timer.t <= 0 then table.remove(timers, i) table.insert(due, 1, timer) end
    end
    table.sort(due, function(a, b) return a.t < b.t end)
    local gen = S.gen
    for _, timer in ipairs(due) do if S.gen == gen then timer.fn() end end  -- (a Reset among them drops the rest)
    if W.reel then W.reel:Update(elapsed) end
end
-- A click mid-dream, step by step: a spinning reel lands; otherwise what's moving finishes and the clock jumps to the
-- next thing due (the next Z, the sky, morning, the next roll...).
local function Skip()
    if W.reel and W.reel:IsSpinning() then W.reel:Land() return end
    for _ = 1, 20 do  -- (finishing one can start another: a few rounds)
        if #tweens == 0 then break end
        local list = tweens
        tweens = {}
        for _, t in ipairs(list) do t.step(1) if t.done then t.done() end end
    end
    local soonest
    for _, timer in ipairs(timers) do soonest = math.min(soonest or timer.t, timer.t) end
    if soonest then Tick(math.max(0, soonest)) end
end

-- The painted room (Media\DreamBed, DreamBedArt.lua: each piece's visible box in its square picture, and the layout:
-- { x, w, bottom | top, rot (degrees clockwise), flat (its height squashed) } as fractions of the room).
local ART_PATH = "Interface\\AddOns\\SOLC\\Media\\DreamBed\\"
local PANEL = 0.035  -- (the strip of the room's wooden wall panel stretched down to the laid-out floor line)
-- A piece's visible part, as laid out: x, y (from the top), w, h in pixels.
local function PieceRect(spec, box)
    local w = spec.w * S.w
    local h = w * box.h / box.w * (spec.flat or 1)
    return spec.x * S.w, spec.top and spec.top * S.h or spec.bottom * S.h - h, w, h
end
-- A piece's picture on parent, placed by spec (its box: another piece's, for the jar's front); the whole square
-- picture drawn, turned round its visible part's middle. Returns the texture and the visible part's rect.
local function Piece(parent, name, spec, box, layer, sub)
    box = box or ns.DreamBedArt.pieces[name].box
    local x, y, w, h = PieceRect(spec, box)
    local tex = parent:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0)
    tex:SetTexture(ART_PATH .. name)
    local iw, ih = w / box.w, h / box.h
    local angle = math.rad(spec.rot or 0)
    local cos, sin = math.cos(angle), math.sin(angle)
    -- (the picture's middle from its visible part's middle, y up, turned clockwise with it)
    local dx, dy = (0.5 - box.x - box.w / 2) * iw, (box.y + box.h / 2 - 0.5) * ih
    tex.cx, tex.cy = x + w / 2 + dx * cos + dy * sin, -(y + h / 2) + dy * cos - dx * sin
    tex:SetPoint("CENTER", W.screen, "TOPLEFT", tex.cx, tex.cy)
    tex:SetSize(iw, ih)
    tex:SetRotation(-angle)  -- (WoW turns anticlockwise)
    return tex, { x = x, y = y, w = w, h = h }
end

-- Helpers to place things by fractions of the room (the page area's size).
local function Text(parent, size, font)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(font or NAME_FONT, size, "")
    return fs
end
local function Place(frame, x, y, w, h)
    frame:SetPoint("TOPLEFT", W.screen, "TOPLEFT", x * S.w, -y * S.h)
    frame:SetSize(w * S.w, h * S.h)
end
local function Parchment(frame, alpha)
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    frame:SetBackdropColor(PARCH[1], PARCH[2], PARCH[3], alpha or 1)
    frame:SetBackdropBorderColor(0.45, 0.3, 0.15)
end

-- Your ogre in bed: your built ogre (no background or held thing; his outfit peeks out above the quilt), its eyes and face
-- for the moment (nil: your own).
local function DrawHead(face)
    local card = KillTrackerDB.card or {}
    local traits = {}
    for key, id in pairs(card.ogre or (ns.BaseTraits and ns.BaseTraits()) or {}) do traits[key] = id end
    traits.background, traits.accessory = nil, nil  -- (his outfit stays on: it shows above the quilt)
    local set = face and FACES[face]
    if set then
        if set[1] then traits.eyes = set[1] end
        if set[2] then traits.expression = set[2] end
    end
    ns.RenderMint(W.head, traits, ns.DreamBedArt.layout.head.rot, card.ogreStyle)  -- (his head on the pillow, tilted as laid out)
    -- (lit like the room: the candle's warm light, the night's blue, the morning sun)
    local light = S.light == "night" and { 0.62, 0.64, 0.82 } or S.light == "day" and { 1, 0.96, 0.88 } or { 0.85, 0.74, 0.6 }
    for _, tex in pairs(W.head.layers or {}) do tex:SetVertexColor(light[1], light[2], light[3]) end
end

-- The painting on the easel: the layers shown so far, in the edition rolled.
local function DrawCanvas()
    ns.RenderMint(W.canvas, S.shown or {}, nil, S.mint and S.mint.style)
end

local function Say(text)
    if not text then W.speech:Hide() return end
    W.speech.text:SetText(text)
    W.speech:SetHeight(W.speech.text:GetStringHeight() + 24)
    W.speech:Show()
end
local function Hint(text) W.hint:SetText(text or "") end

local function SetPhase(phase)
    S.phase = phase
    W.tap:SetShown(phase ~= "bed" and phase ~= "done")  -- (the dream plays by itself; a click skips to its next step)
    W.mallet:SetEnabled(phase == "bed" and ns.Tokens("bonk") > 0)  -- (a Bonk: good night)
    W.back:SetShown(phase == "bed")  -- (only before the bonk: once he's dreaming, you see it through)
    W.mug:SetEnabled(phase == "bed")
    W.bubble:SetShown(phase == "bed")  -- (what he's thinking about: only while he lies there awake)
end

-- The room's light: night (dark over everything), morning (a warm wash), else the lamp.
local function Light(mode)
    S.light = mode
    local dark = mode == "night" and 0.55 or 0
    local warm = mode == "day" and 0.07 or 0  -- (a hint of sunshine: the painting's colours stay true)
    local fromDark, fromWarm = W.dark:GetAlpha(), W.warm:GetAlpha()
    Tween(1.4, function(p)
        W.dark:SetAlpha(fromDark + (dark - fromDark) * p)
        W.easelDark:SetAlpha(fromDark + (dark - fromDark) * p)  -- (the easel's own: it's above the room's light)
        W.warm:SetAlpha(fromWarm + (warm - fromWarm) * p)
    end)
end

-- The sky: its colours from top to bottom, by time; the moon, the sun, the stars follow.
local SKIES = { night = { { 0.04, 0.06, 0.2 }, { 0.1, 0.13, 0.38 } }, dawn = { { 0.35, 0.42, 0.72 }, { 0.94, 0.63, 0.48 } }, day = { { 0.5, 0.77, 1 }, { 0.81, 0.91, 1 } } }
local function Sky(name, seconds)
    local from = S.sky or SKIES.night
    local to = SKIES[name]
    S.sky = to
    local OUT = 1.6  -- (below the window: out of sight, halo and all)
    local moonFrom, sunFrom = S.moonY or 0.15, S.sunY or OUT
    local moonTo, sunTo = name == "night" and 0.15 or OUT, name == "night" and OUT or 0.35
    S.moonY, S.sunY = moonTo, sunTo
    Tween(seconds or 0.01, function(p)
        local function Mix(a, b) return a + (b - a) * p end
        local top = { Mix(from[1][1], to[1][1]), Mix(from[1][2], to[1][2]), Mix(from[1][3], to[1][3]) }
        local bottom = { Mix(from[2][1], to[2][1]), Mix(from[2][2], to[2][2]), Mix(from[2][3], to[2][3]) }
        W.sky:SetGradient("VERTICAL", CreateColor(bottom[1], bottom[2], bottom[3], 1), CreateColor(top[1], top[2], top[3], 1))
        local wh = W.window:GetHeight()
        W.moon:SetPoint("CENTER", W.window, "TOPLEFT", W.window:GetWidth() * 0.66, -wh * Mix(moonFrom, moonTo))
        W.sun:SetPoint("CENTER", W.window, "TOPLEFT", W.window:GetWidth() * 0.3, -wh * Mix(sunFrom, sunTo))
        for _, star in ipairs(W.stars) do star:SetAlpha(name == "night" and star.base * (0.5 + 0.5 * p) or star.base * (1 - p)) end
    end)
end

-- The luck in the sky while he sleeps: a shooting star (rare), an aurora (epic: purple; legendary: gold, and meteors).
local function Shoot()
    local s = W.shooters[(S.shot or 0) % #W.shooters + 1]
    S.shot = (S.shot or 0) + 1
    local ww, wh = W.window:GetWidth(), W.window:GetHeight()
    local x0, y0 = math.random() * ww * 0.4, -math.random() * wh * 0.4
    s:Show()
    Tween(1.1, function(p)
        s:SetPoint("CENTER", W.window, "TOPLEFT", x0 + p * ww * 0.7, y0 - p * wh * 0.3)
        s:SetAlpha(p < 0.2 and p * 5 or 1 - (p - 0.2) / 0.8)
    end, function() s:Hide() end)
end
local function SkyShow(best)
    if best >= 2 then
        for i = 0, (best >= 4 and 5 or 0) do After(i * 0.45, Shoot) end
    end
    if best >= 3 then
        local c = best >= 4 and { 1, 0.7, 0.2 } or { 0.7, 0.4, 1 }
        for _, a in ipairs(W.aurora) do a:SetVertexColor(c[1], c[2], c[3]) end
        Tween(2, function(p) for _, a in ipairs(W.aurora) do a:SetAlpha(0.7 * p) end end)
    end
    local glow = ({ { 0.9, 0.9, 1 }, { 0.35, 0.66, 1 }, { 0.7, 0.42, 1 }, { 1, 0.69, 0.18 } })[best] or { 0.9, 0.9, 1 }
    W.dream:SetVertexColor(glow[1], glow[2], glow[3])
    Tween(1, function(p) W.dream:SetAlpha(0.85 * p) end)
end

local function Z(n)
    local z = W.zs[n]
    local colors = { { 0.9, 0.9, 1 }, { 0.35, 0.66, 1 }, { 0.7, 0.42, 1 }, { 1, 0.69, 0.18 } }
    local c = colors[math.min(S.best or 1, n + 1)] or colors[1]
    z:SetTextColor(c[1], c[2], c[3])
    z:SetFont(CRAYON_FONT, 16 + n * 8, "")
    z:Show()
    local hw = W.head:GetWidth()  -- (rising from his mouth's side)
    local x, y = W.head:GetLeft() - W.screen:GetLeft() + hw * 0.6 + n * 12, W.head:GetTop() - W.screen:GetTop() - hw * 0.28
    Tween(2.2, function(p)
        z:SetPoint("CENTER", W.screen, "TOPLEFT", x + p * 50, y + p * 120)
        z:SetAlpha(p < 0.2 and p * 5 or 1 - (p - 0.2) / 0.8)
    end, function() z:Hide() end)
end

-- Painting: the edition's tool (brush, coloured pencil, crayon: the jar's pieces), held tip-down, zig-zags down the
-- canvas, and the new layer is masked in behind its tip (drawn on a copy of the canvas over it, its mask - wipe.blp,
-- solid with a soft lower edge - growing down; kept when the stroke's done).
local TOOL_COLORS = { painted = { 0.63, 0.45, 0.24 }, sketch = { 0.23, 0.48, 0.85 }, crayon = { 0.88, 0.23, 0.35 } }
local TOOL_PIECE = { painted = "brush", sketch = "pencils", crayon = "crayon" }
local PAINT_TIME, STROKES = 1.6, 3  -- (seconds a layer; back-and-forths across it)
local TOOL_TURN = math.rad(200)  -- (tip down, the handle up to the right: a right hand's)
-- The tool's tip at x, y (pixels from the canvas's top left), turned a little more by wobble.
local function ToolAt(x, y, wobble)
    local t = W.painter
    local angle = TOOL_TURN + wobble
    local cos, sin = math.cos(angle), math.sin(angle)
    t:SetRotation(-angle)  -- (WoW turns anticlockwise)
    t:SetPoint("CENTER", W.canvas, "TOPLEFT", x - (t.tipX * cos + t.tipY * sin), -y - (t.tipY * cos - t.tipX * sin))
end
-- A stroke; reveal: S.shown's new layer masked in as it goes. done: when it's finished.
local function Sweep(reveal, done)
    local edition = type(S.mint and S.mint.style) == "string" and S.mint.style or "painted"
    local name = TOOL_PIECE[edition] or "brush"
    local box = ns.DreamBedArt.pieces[name].box
    local cw = W.canvas:GetWidth()
    local size = cw * 0.55 / box.h  -- (the tool about half the canvas long)
    local t = W.painter
    t:SetTexture(ART_PATH .. name)
    t:SetSize(size, size)
    t.tipX, t.tipY = (box.x + box.w / 2 - 0.5) * size, (0.5 - box.y - 0.01) * size  -- (its tip from its middle, y up)
    t:SetAlpha(1)
    t:Show()
    if reveal then
        ns.RenderMint(W.canvasNew, S.shown, nil, S.mint.style)
        for _, r in ipairs({ W.canvasNew:GetRegions() }) do  -- (each of its textures masked, new ones too)
            if r ~= W.wipe and r.AddMaskTexture and not r:IsObjectType("MaskTexture") and not r.wiped then
                r:AddMaskTexture(W.wipe)
                r.wiped = true
            end
        end
        W.wipe:SetSize(cw, 1)
        W.canvasNew:Show()
    end
    Tween(PAINT_TIME, function(p)
        local edge = p * cw * 1.15  -- (past the bottom at the end: the soft edge too)
        W.wipe:SetSize(cw, math.max(1, edge / 0.9))  -- (its soft edge, the last fifth, round the tip)
        local x = cw * (0.12 + 0.76 * (0.5 - 0.5 * math.cos(p * math.pi * 2 * STROKES)))
        ToolAt(x, math.min(edge, cw * 0.96), math.sin(p * math.pi * 2 * STROKES) * 0.12)
    end, function()
        if reveal then DrawCanvas() W.canvasNew:Hide() end
        Tween(0.3, function(p) t:SetAlpha(1 - p) end, function() t:Hide() end)
        if done then done() end
    end)
end

-- You, for the story: your name, your most-killed creature, guildmates, recent dungeon buddies (Guild.lua's quiet list).
local function StoryContext()
    local db = KillTrackerDB
    local ctx = { me = ns.MyName and Ambiguate(ns.MyName(), "short"), mates = {}, buddies = {}, lastSkin = db.dreamLastSkin }
    local top
    for _, entry in pairs(db.kills or {}) do
        if entry.name and (not top or (entry.count or 0) > (top.count or 0)) then top = entry end
    end
    if top then ctx.kills = { n = top.count or 0, name = top.name } end
    for _, friend in ipairs(ns.GetFriends and ns.GetFriends() or {}) do ctx.mates[#ctx.mates + 1] = Ambiguate(friend.name, "short") end
    local week = time() - 7 * 86400
    for name, c in pairs(db.companions or {}) do
        local d = c.last and ns.DungeonByKey and ns.DungeonByKey(c.last)
        if d and (c.seen or 0) > week then ctx.buddies[#ctx.buddies + 1] = { name = name, place = d.name } end
    end
    return ctx
end

-- The nightstand, the counts, the tags.
local function Refresh()
    ns.TopUpBonks()  -- (today's Bonk, if it's come back)
    local milkHave, storiesHave = ns.Tokens("milk"), ns.Tokens("story")
    if S.milk > milkHave then S.milk = 0 end
    local storyOption = S.story and S.story.option
    if storyOption and (ns.STORY_COST[storyOption.rarity] or 1) > storiesHave then S.story = nil storyOption = nil end
    for i, steam in ipairs(W.steam) do steam:SetShown(i <= S.milk) end  -- (warmer the more milk you pour)
    W.mugTag:SetText(O("Milk: ", "MILK: ") .. (Ogre() and MILK_OGRE or MILK_WORDS)[S.milk + 1] .. (S.milk > 0 and O(" (+luck)", " (LUCK)") or ""))
    W.ShowThought(S.story)
    local bonks = ns.Tokens("bonk")
    W.counts:SetText(("%d %s   %d %s   %d %s"):format(milkHave, O("milk", "MILK"),
        storiesHave, O(storiesHave == 1 and "story" or "stories", "STORY"), bonks, O(bonks == 1 and "bonk" or "bonks", "BONK")))
    W.malletTag:SetText(O("Bonks: ", "BONK: ") .. bonks .. (bonks < ns.BONK_CAP and O(" (one comes back each day)", " (+1 A DAY)") or ""))
    if S.phase ~= "bed" then return end
    if bonks > 0 then
        Hint(O("Pour him some milk, pick a story from the book, then bonk him to sleep with the mallet", "MILK. STORY. BONK!"))
    else  -- (out of Bonks: the next one at the daily reset)
        local left = ns.UntilReset()
        local wait = left >= 3600 and ("%dh %dm"):format(math.floor(left / 3600), math.floor(left % 3600 / 60)) or ("%dm"):format(math.ceil(left / 60))
        Hint(O("He's wide awake, and you're out of Bonks. The next one comes in " .. wait, "NO BONK. WAIT " .. wait:upper()))
    end
end

-- The storybook: tonight's story, from a spread of chapters and picture cards.
local function ShowBook(show)
    W.spread:SetShown(show)
    if not show then return end
    local spread = W.spread
    local chapter = spread.chapter
    local options = {}
    for _, layer in ipairs(ns.MintLayers) do
        if layer.key == chapter then
            for _, option in ipairs(layer.options) do if ns.MintAllowed(option) then options[#options + 1] = option end end
        end
    end
    spread.options = options
    spread.page = math.max(0, math.min(spread.page or 0, math.floor((#options - 1) / CARDS_PER_PAGE)))
    for i, button in ipairs(spread.chapters) do
        local on = CHAPTERS[i][1] == chapter
        button.label:SetText(O(CHAPTERS[i][2], CHAPTERS[i][3]))
        button.label:SetTextColor(on and 1 or INK[1], on and 0.91 or INK[2], on and 0.72 or INK[3])
        button.bg:SetShown(on)
    end
    local stories = ns.Tokens("story")
    for i, card in ipairs(spread.cards) do
        local option = options[spread.page * CARDS_PER_PAGE + i]
        card.option = option
        card:SetShown(option ~= nil)
        if option then
            local cost = ns.STORY_COST[option.rarity] or 1
            local rim = RIM[option.rarity] or RIM.uncommon
            for _, edge in ipairs(card.edges) do edge:SetColorTexture(rim[1], rim[2], rim[3]) end
            ns.DrawPiece(card.canvas, chapter, option)
            card.name:SetText(Ogre() and option.name:upper() or option.name)
            card.cost:SetText(cost)
            card:SetEnabled(cost <= stories)
            card:SetAlpha(cost <= stories and 1 or 0.35)
            local picked = spread.sel and spread.sel.option == option
            card.picked:SetShown(picked)
        end
    end
    local pages = math.max(1, math.ceil(#options / CARDS_PER_PAGE))
    spread.pageText:SetText(("%d / %d"):format(spread.page + 1, pages))
    spread.prev:SetEnabled(spread.page > 0)
    spread.next:SetEnabled(spread.page < pages - 1)
    spread.storiesText:SetText(O("Stories left: ", "STORY: ") .. stories)
    local sel = spread.sel
    spread.pick:SetEnabled(sel ~= nil)
    spread.pick.label:SetText(sel and O("Think about the " .. sel.option.name, "THIS ONE") or O("Pick a piece", "PICK"))
end

-- The night: good night (the mint), sleep, the sky's luck, morning, the telling, the painting.
local Finish, TellNext, Night
-- The bonk: the mallet swings up over his head, then straight down onto it, BONK!, and stars go round his head for a
-- while. It stands head down, handle up, so it comes down head first as it is: up and over (cocked back), then down,
-- a little bounce, and home to its peg. onHit: at the BONK.
local BONK_SKULL = 0.14  -- (his skull's top, down from the head picture's top, in head widths: where the mallet lands)
local function Bonk(onHit)
    local m = W.malletTex
    local hw, ih = W.head:GetWidth(), m:GetHeight()
    local hx = W.head:GetLeft() - W.screen:GetLeft() + hw * 0.5
    local hitY = W.head:GetTop() - W.screen:GetTop() - hw * BONK_SKULL + ih * 0.46  -- (its head's bottom on his skull)
    local upY = hitY + ih * 0.7
    local base = math.rad(ns.DreamBedArt.layout.mallet.rot or 0)
    local cock = math.rad(35)  -- (wound up: its head swung back, away from the bed)
    local function Pose(x, y, tilt)
        m:SetPoint("CENTER", W.screen, "TOPLEFT", x, y)
        m:SetRotation(-(base - tilt))  -- (WoW turns anticlockwise: + tilt swings its head right, back)
    end
    local function Hit()
        Click()
        if onHit then onHit() end
        local pop = W.bonkText
        pop:SetText(O("BONK!", "BONK!"))
        pop:Show()
        Tween(0.7, function(p) pop:SetAlpha(1 - p * p) pop:SetScale(1 + p * 0.6) end, function() pop:Hide() end)
        for i, star in ipairs(W.dizzy) do
            star:Show()
            Tween(3, function(p)
                local a = p * math.pi * 5 + i * math.pi * 2 / #W.dizzy
                star:SetPoint("CENTER", W.head, "TOPLEFT", hw * 0.5 + math.cos(a) * hw * 0.13, -hw * 0.08 + math.sin(a) * hw * 0.035)
                star:SetAlpha(p < 0.75 and 1 or (1 - p) * 4)
            end, function() star:Hide() end)
        end
    end
    -- (up: fast off the peg, slowing at the top)
    Tween(0.35, function(p)
        local e = 1 - (1 - p) ^ 2
        Pose(m.cx + (hx - m.cx) * e, m.cy + (upY - m.cy) * e, cock * e)
    end, function()
        -- (down: speeding up, straightening as it comes)
        Tween(0.1, function(p)
            local e = p * p
            Pose(hx, upY + (hitY - upY) * e, cock * (1 - e))
        end, function()
            Hit()
            Tween(0.15, function(p) Pose(hx, hitY + math.sin(p * math.pi) * ih * 0.08, 0) end, function()
                Tween(0.4, function(p)  -- (and home)
                    local e = p * p * (3 - 2 * p)
                    Pose(hx + (m.cx - hx) * e, hitY + (m.cy - hitY) * e, 0)
                end)
            end)
        end)
    end)
end

-- Good night: bonk him (a Bonk spent). The candle goes out as he drops off.
-- A dream to show: its telling (the story's beats), how lucky it is (S.best: its rarest piece, the story's aside).
local function Begin(mint)
    S.mint, S.shown, S.told, S.taps, S.started, S.revealed, S.lines = mint, {}, 0, 0, false, false, nil
    local told = ns.TellDream(mint.traits, mint.asked, StoryContext())
    S.told_story = told
    mint.tale = mint.tale or ns.DreamText(told)  -- (kept on the picture, for its view)
    local score = { uncommon = 1, rare = 2, epic = 3, legendary = 4 }
    S.best = 1
    for _, layer in ipairs(ns.MintLayers) do
        if layer.key ~= mint.asked then
            for _, option in ipairs(layer.options) do
                if option.id == mint.traits[layer.key] then S.best = math.max(S.best, score[option.rarity] or 1) end
            end
        end
    end
    DrawCanvas()
end

local function GoodNight()
    if S.phase ~= "bed" then return end
    local story = S.story and { layer = S.story.layer, id = S.story.option.id }
    local mint, reason = ns.DreamMint(S.milk, story)
    if not mint then ns.Print(reason) Hint(reason) return end
    Click()
    KillTrackerDB.dreamPending = mint.number  -- (until its painting comes forward: a /reload mid-dream replays it)
    Begin(mint)
    KillTrackerDB.dreamLastSkin = mint.traits.skin
    SetPhase("falling")
    local asked = S.story and S.story.option
    -- (he yawns his good night - tonight's story on his lips - and the mallet comes down mid-word)
    DrawHead("yawn")
    Say(asked and O("Mmm... the " .. asked.name .. "... night ni-", "MMM. " .. asked.name:upper() .. ". NI-") or O("Night ni-", "NI-"))
    Bonk(function() Say(nil) DrawHead("asleep") end)  -- (out cold at the BONK)
    Refresh()
    After(1.6, function()
        Say(nil)
        W.flame:Hide() W.flameGlow:Hide()
        Tween(0.8, function(p) W.candleLight:SetAlpha(1 - p) end, function() W.candleLight:Hide() end)
        W.smoke:Show() W.smoke:SetAlpha(0.8)
        Tween(1.6, function(p) W.smoke:SetAlpha(0.8 * (1 - p)) end, function() W.smoke:Hide() end)
        Light("night")
        DrawHead("asleep")
        SetPhase("sleep")
        Hint("")
        Night()
    end)
end

local function Morning()
    W.dream:SetAlpha(0)
    for _, a in ipairs(W.aurora) do a:SetAlpha(0) end
    Light("bed")
    Sky("dawn", 2.2)
    After(2.2, function() Sky("day", 1.5) Light("day") end)
    After(3.2, function()
        DrawHead("talk")
        SetPhase("tell")
        Say("|cff3a1a10" .. O("Ow. My head. ...Good dream though. You won't BELIEVE what I dreamt...", "OW. HEAD. GOOD DREAM!") .. "|r")
        Hint("")
        After(2.2, function() S.started = true TellNext() end)  -- (and the story starts: the rolls keep the tempo)
    end)
end

-- He talks in his sleep: how lucky the dream is (its rarest piece, the story's aside), said in its rarity's colour.
local MUMBLES = {
    { "mmm... snacks...", "zzz... five more minutes...", "mm... nice and cosy..." },
    { "ooh... shiny...", "heh... that's a nice one...", "mmm... ooh, fancy..." },
    { "whoa... so... sparkly...", "ooooh... the good stuff...", "mmm... nobody's got one of THOSE..." },
    { "GOLD... so much GOLD...", "it's... it's... LEGENDARY...", "the shiniest... thing... EVER..." },
}
local MUMBLES_OGRE = { { "MMM. SNACK." }, { "OOH. SHINY." }, { "OOOH. FANCY!" }, { "GOLD! GOLD!!" } }
local function Mumble(best)
    best = math.max(1, math.min(4, best or 1))
    local lines = (Ogre() and MUMBLES_OGRE or MUMBLES)[best]
    local rarity = ({ "uncommon", "rare", "epic", "legendary" })[best]
    Say(("|c%s%s|r"):format(ns.RARITY_COLORS[rarity] or "ffffffff", lines[math.random(#lines)]))
end

-- A dream left unfinished by a /reload (KillTrackerDB.dreamPending: it's saved already): its show from the night on.
local function Resume(mint)
    Begin(mint)
    W.flame:Hide() W.flameGlow:Hide() W.candleLight:Hide()
    Light("night")
    DrawHead("asleep")
    SetPhase("sleep")
    Hint("")
    Night()
end

-- The night, by itself: the Zs float up, the sky shows the luck, he mumbles it in his sleep, and morning comes.
function Night()
    After(0.6, function() Z(1) end)
    After(1.8, function() Z(2) SkyShow(S.best) end)
    After(2.6, function() Mumble(S.best) end)
    After(3.4, function() Z(3) end)
    After(5.0, function() Say(nil) SetPhase("waiting") After(2.2, Morning) end)
end

local function Tap()
    if S.phase == "ending" then Click() Finish()  -- (the ending read: the painting comes forward)
    else Skip() end  -- (anywhere else in the dream: on to the next step)
end

-- The edition you reach for, before the first stroke (crayon the rarest).
local function RevealTool(nextFn)
    local edition = S.mint.style
    S.busy = true
    Say(edition == "crayon" and O("...wait. The CRAYONS?! Oh, this'll be a good one.", "CRAYN!! YES!!")
        or O("Ooh, the coloured pencils. Very artsy.", "PENCIL. FANCY."))
    Hint(edition == "crayon" and O("CRAYON! The rarest kind.", "CRAYN!") or O("Sketched: coloured pencils", "PENCIL"))
    local c = TOOL_COLORS[edition]
    -- (you pull it out of the jar: it rises, and the burst)
    local tool = W.tools[edition]
    if tool then
        Tween(0.6, function(p) tool:SetPoint("CENTER", W.screen, "TOPLEFT", tool.cx, tool.cy + p * S.h * 0.08) tool:SetAlpha(1 - p * p) end)
    end
    W.burst:SetVertexColor(c[1], c[2], c[3])
    W.burst:Show()
    Tween(1, function(p) W.burst:SetAlpha(1 - p) W.burst:SetSize(80 + p * 260, 80 + p * 260) end, function() W.burst:Hide() end)
    After(1.7, function() S.busy = false nextFn() end)
end

-- A beat: he drifts off remembering ("...and then there was..."), the reel rolls through everything that layer could
-- have been and lands on his, he tells it, you paint it; then on to the next by itself (the rolls keep the tempo; a tap
-- hurries a roll). The piece the story asked about isn't rolled: he knew it all along.
local ROLL_TIME, LEAD_TIME, BEAT_PAUSE = 1.9, 0.6, 0.45
local SOUND_LAND, SOUND_BIG = SOUNDKIT and SOUNDKIT.IG_QUEST_LOG_OPEN or 875, 888
function TellNext()
    if S.busy then return end
    local told, beats = S.told_story, S.told_story.beats
    if S.told == 0 and S.mint.style and not S.revealed then S.revealed = true return RevealTool(TellNext) end
    if S.told >= #beats then  -- the ending: one last dramatic stroke
        Say((W.speech.lines or "") .. "\n|cffc0262c" .. (Ogre() and ns.DreamOgreEnd() or told.ending) .. "|r")
        -- (then it stops: the ending stays up to be read, and a click brings the painting forward)
        SetPhase("waiting")
        Hint("")
        Sweep(nil, function() SetPhase("ending") Hint(O("Click to see your painting", "CLICK. LOOK.")) end)
        return
    end
    S.busy = true
    local beat = beats[S.told + 1]
    local layer = ns.MintLayerByKey(beat.k)
    local option
    for _, o in ipairs(layer and layer.options or {}) do if o.id == S.mint.traits[beat.k] then option = o end end
    local asked = beat.k == S.mint.asked
    local before = W.speech.lines and (W.speech.lines .. " ") or ""
    -- (he tells it, it's painted, and after a breath the next)
    local function Tell()
        DrawHead("talk")
        local color = ns.RARITY_COLORS[option and option.rarity or "uncommon"] or "ff5a5468"
        local line = Ogre() and ns.DreamOgreBeat(beat.k, S.mint.traits[beat.k])
            or (beat.pre .. "|c" .. color .. beat.say .. "|r" .. (asked and " |cff6b4a12[STORY]|r" or "") .. beat.post)
        -- (the bubble keeps the last three lines)
        S.lines = S.lines or {}
        S.lines[#S.lines + 1] = line
        if #S.lines > 3 then table.remove(S.lines, 1) end
        W.speech.lines = table.concat(S.lines, " ")
        Say(W.speech.lines)
        S.shown[beat.k] = S.mint.traits[beat.k]
        S.told = S.told + 1
        Hint(option and option.rarity == "legendary" and not asked and O("LEGENDARY!", "GOLD!") or O("Listening...", "..."))
        Sweep(true, function()
            Tween(0.3, function(p) W.reel.frame:SetAlpha(1 - p) end, function() W.reel.frame:Hide() end)
            After(BEAT_PAUSE, function() S.busy = false TellNext() end)
        end)
    end
    -- (he drifts: the start of the line, trailing off)
    DrawHead("yawn")
    local lead = Ogre() and "..." or ((beat.pre or ""):gsub("%s+$", "") .. "...")
    Say(before .. "|cff6b5a48" .. lead .. "|r")
    if asked or not layer or not option then
        Hint(O("He knew this one all along", "KNOW IT"))
        After(LEAD_TIME + 0.4, Tell)
        return
    end
    Hint(O("Click to skip ahead", "CLICK. FAST."))
    After(LEAD_TIME, function()
        W.reelLabel:SetText(Ogre() and (layer.name or ""):upper() or layer.name or "")
        W.reel.frame:SetAlpha(1)
        W.reel.frame:Show()
        W.reel:Spin(layer, option, S.mint.traits, function()
            pcall(PlaySound, (option.rarity == "rare" or option.rarity == "epic" or option.rarity == "legendary") and SOUND_BIG or SOUND_LAND)
            After(0.35, Tell)
        end, { all = true, time = ROLL_TIME })
    end)
end

function Finish()
    KillTrackerDB.dreamPending = nil  -- (seen through)
    SetPhase("done")
    Say(nil)
    Hint("")
    DrawHead(nil)
    -- (the painting comes off the easel to the middle, big, in its frame: you pick the frame)
    local mint = S.mint
    W.show:Show()
    W.show:SetAlpha(0)
    ns.DrawMint(W.showCanvas, mint)
    W.ShowFrames()
    Tween(0.8, function(p)
        local e = 1 - (1 - p) ^ 3
        W.show:SetAlpha(e)
        W.showCanvas:SetScale(0.6 + 0.4 * e)
        W.easel:SetAlpha(1 - e)
    end)
    W.showSignature:SetText(Ogre() and (mint.paintedBy or "ME"):upper() .. "!!" or (mint.paintedBy or ""))  -- (just your name: a signature)
    W.showSignature:SetFont(mint.style == "crayon" and CRAYON_FONT or NAME_FONT, 13, "")
    local rarity = ns.MintRarity(mint.traits, mint.asked)
    local edition = ({ crayon = O(" - in crayon, the rarest kind", " CRAYN!"), sketch = O(" - sketched in coloured pencil", " PENCIL") })[mint.style] or ""
    W.verdict.text:SetText(("%s #%d %s %s\n|c%s%s|r%s\n\n|cff6b5a48\"%s\"|r"):format(O("Painting", "PIC"), mint.number, O("painted by", "BY"),
        mint.paintedBy or "", ns.RARITY_COLORS[rarity] or "ffffffff", O(rarity:sub(1, 1):upper() .. rarity:sub(2) .. " dream", rarity:upper()),
        edition, O("Yeah. Yeah, that's it. That's EXACTLY it.", "YES. THAT IT.")))
    W.verdict:SetHeight(W.verdict.text:GetStringHeight() + 24)
    W.verdict:Show()
    W.again.label:SetText(O("Frame it!", "HANG IT!"))
    W.again:Show()
    if ns.OnKillsChanged then ns.OnKillsChanged() end
end

local function Reset()
    S.gen = (S.gen or 0) + 1  -- (whatever was still to happen is dropped)
    wipe(tweens)
    wipe(timers)
    if W.reel then W.reel:Stop() end
    for _, b in ipairs(W.dizzy or {}) do b:Hide() end
    W.bonkText:Hide()
    for _, z in ipairs(W.zs) do z:Hide() end
    W.back.label:SetText(O("< Back", "< GO"))  -- (ogre mode may have changed)
    for _, b in ipairs({ W.verdict, W.again, W.signature, W.painter, W.canvasNew, W.burst, W.smoke, W.show }) do b:Hide() end
    W.easel:SetAlpha(1)
    W.flame:Show() W.flameGlow:Show() W.candleLight:Show() W.candleLight:SetAlpha(1)
    W.jar:Show()
    W.malletTex:SetRotation(-math.rad(ns.DreamBedArt.layout.mallet.rot or 0))
    W.malletTex:SetPoint("CENTER", W.screen, "TOPLEFT", W.malletTex.cx, W.malletTex.cy)
    for _, tool in pairs(W.tools) do tool:SetPoint("CENTER", W.screen, "TOPLEFT", tool.cx, tool.cy) tool:SetAlpha(1) end
    W.dream:SetAlpha(0)
    for _, a in ipairs(W.aurora) do a:SetAlpha(0) end
    W.dark:SetAlpha(0) W.warm:SetAlpha(0) W.easelDark:SetAlpha(0)
    S.light = nil  -- (the lamp again: his tint too)
    Sky("night")
    S.mint, S.shown, S.lines, S.revealed, S.busy, S.started = nil, {}, nil, false, false, false
    W.reel:Stop()
    W.reel.frame:Hide()
    W.speech.lines = nil
    DrawCanvas()
    Say(nil)
    DrawHead(nil)
    SetPhase("bed")
    Refresh()
end

-- Building --------------------------------------------------------------------------------------------------------

-- A prop you click (title: its tooltip's first line, a function for ogre mode; its tag's text the second).
local function Prop(x, y, w, h, onClick, title)
    local button = CreateFrame("Button", nil, W.screen)
    Place(button, x, y, w, h)
    button:SetFrameLevel(W.screen:GetFrameLevel() + 6)
    button:SetScript("OnClick", function() if S.phase == "bed" then Click() onClick() end end)
    local hover = button:CreateTexture(nil, "BACKGROUND")
    hover:SetPoint("CENTER")
    hover:SetSize(w * S.w * 1.8, h * S.h * 1.6)
    hover:SetTexture(GLOW)
    hover:SetBlendMode("ADD")
    hover:SetVertexColor(1, 0.85, 0.4)
    hover:Hide()
    button:SetScript("OnEnter", function(self)
        if S.phase == "bed" and self:IsEnabled() then hover:Show() end
        if title and S.phase == "bed" and UI.Tooltip then UI.Tooltip(self, { title(), self.tag:GetText() }) end
    end)
    button:SetScript("OnLeave", function() hover:Hide() GameTooltip_Hide() end)
    button.tag = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")  -- (never shown: the tooltip's text, kept by Refresh)
    button.tag:Hide()
    return button
end
local function ParchButton(parent, w, h, onClick)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(w, h)
    Parchment(b)
    b.label = Text(b, 14)
    b.label:SetPoint("CENTER")
    b.label:SetTextColor(INK[1], INK[2], INK[3])
    b:SetScript("OnClick", function(...) Click() onClick(...) end)
    b:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(1, 0.82, 0.3) end)
    b:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(0.45, 0.3, 0.15) end)
    return b
end

local function BuildBook()
    local spread = CreateFrame("Frame", nil, W.screen, "BackdropTemplate")
    spread:SetSize(S.w * 0.9, S.h * 0.82)
    spread:SetPoint("CENTER")
    spread:SetFrameLevel(W.screen:GetFrameLevel() + 40)
    spread:EnableMouse(true)
    Parchment(spread)
    spread:SetBackdropBorderColor(0.42, 0.1, 0.13)
    spread.chapter, spread.page = "headwear", 0
    local shade = spread:CreateTexture(nil, "BACKGROUND", nil, -8)
    shade:SetPoint("TOPLEFT", W.screen) shade:SetPoint("BOTTOMRIGHT", W.screen)
    shade:SetColorTexture(0.04, 0.03, 0.09, 0.6)
    local leftW = spread:GetWidth() * 0.3
    local title = Text(spread, 22)
    title:SetPoint("TOPLEFT", 16, -14)
    title:SetTextColor(INK[1], INK[2], INK[3])
    spread.title = title
    local note = Text(spread, 12)
    note:SetPoint("TOPLEFT", 16, -44)
    note:SetWidth(leftW - 24)
    note:SetJustifyH("LEFT")
    note:SetTextColor(0.35, 0.28, 0.2)
    spread.note = note
    spread.chapters = {}
    for i, ch in ipairs(CHAPTERS) do
        local b = CreateFrame("Button", nil, spread)
        b:SetSize(leftW - 24, 22)
        b:SetPoint("TOPLEFT", 16, -118 - (i - 1) * 25)
        b.bg = b:CreateTexture(nil, "BACKGROUND")
        b.bg:SetAllPoints()
        b.bg:SetColorTexture(0.42, 0.1, 0.13)
        b.label = Text(b, 14)
        b.label:SetPoint("LEFT", 6, 0)
        b:SetScript("OnClick", function() Click() spread.chapter, spread.page = ch[1], 0 ShowBook(true) end)
        spread.chapters[i] = b
    end
    spread.storiesText = Text(spread, 13)
    spread.storiesText:SetPoint("BOTTOMLEFT", 16, 16)
    spread.storiesText:SetTextColor(INK[1], INK[2], INK[3])
    -- (the cards: 4 x 2 a page)
    spread.cards = {}
    local areaX, cw, chh, gap = leftW + 14, (spread:GetWidth() - leftW - 40) / 4, (spread:GetHeight() - 90) / 2, 8
    for i = 1, CARDS_PER_PAGE do
        local card = CreateFrame("Button", nil, spread)
        card:SetSize(cw - gap, chh - gap)
        card:SetPoint("TOPLEFT", areaX + ((i - 1) % 4) * cw, -16 - math.floor((i - 1) / 4) * chh)
        local bg = card:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(1, 0.98, 0.94)
        card.edges = {}
        for e = 1, 4 do
            local edge = card:CreateTexture(nil, "BORDER")
            if e <= 2 then edge:SetHeight(3) edge:SetPoint(e == 1 and "TOPLEFT" or "BOTTOMLEFT") edge:SetPoint(e == 1 and "TOPRIGHT" or "BOTTOMRIGHT")
            else edge:SetWidth(3) edge:SetPoint(e == 3 and "TOPLEFT" or "TOPRIGHT") edge:SetPoint(e == 3 and "BOTTOMLEFT" or "BOTTOMRIGHT") end
            card.edges[e] = edge
        end
        card.canvas = CreateFrame("Frame", nil, card)
        card.canvas:SetSize(cw * 0.62, cw * 0.62)
        card.canvas:SetPoint("TOP", 0, -6)
        card.name = Text(card, 11)
        card.name:SetPoint("BOTTOM", 0, 6)
        card.name:SetWidth(cw - gap - 8)
        card.name:SetTextColor(INK[1], INK[2], INK[3])
        card.cost = Text(card, 12)
        card.cost:SetPoint("TOPRIGHT", -5, -4)
        card.cost:SetTextColor(0.42, 0.1, 0.13)
        card.picked = card:CreateTexture(nil, "BACKGROUND", nil, -1)
        card.picked:SetPoint("TOPLEFT", -8, 8) card.picked:SetPoint("BOTTOMRIGHT", 8, -8)
        card.picked:SetTexture(GLOW)
        card.picked:SetBlendMode("ADD")
        card.picked:SetVertexColor(1, 0.82, 0.3)
        card:SetScript("OnClick", function(self)
            if not self.option then return end
            Click()
            spread.sel = { layer = spread.chapter, option = self.option }
            ShowBook(true)
        end)
        card:SetScript("OnEnter", function(self)
            if self.option and UI.Tooltip then
                UI.Tooltip(self, { ("|c%s%s|r"):format(ns.RARITY_COLORS[self.option.rarity] or "ffffffff", self.option.name),
                    O(("%d bedtime %s"):format(ns.STORY_COST[self.option.rarity] or 1, (ns.STORY_COST[self.option.rarity] or 1) == 1 and "story" or "stories"), "STORY") })
            end
        end)
        card:SetScript("OnLeave", GameTooltip_Hide)
        spread.cards[i] = card
    end
    spread.prev = ParchButton(spread, 30, 22, function() spread.page = spread.page - 1 ShowBook(true) end)
    spread.prev.label:SetText("<")
    spread.prev:SetPoint("BOTTOMLEFT", areaX, 46)
    spread.next = ParchButton(spread, 30, 22, function() spread.page = spread.page + 1 ShowBook(true) end)
    spread.next.label:SetText(">")
    spread.next:SetPoint("LEFT", spread.prev, "RIGHT", 40, 0)
    spread.pageText = Text(spread, 12)
    spread.pageText:SetPoint("LEFT", spread.prev, "RIGHT", 6, 0)
    spread.pageText:SetTextColor(INK[1], INK[2], INK[3])
    spread:EnableMouseWheel(true)
    spread:SetScript("OnMouseWheel", function(_, delta)
        local pages = math.ceil(#(spread.options or {}) / CARDS_PER_PAGE)
        spread.page = math.max(0, math.min(pages - 1, spread.page - delta))
        ShowBook(true)
    end)
    spread.pick = ParchButton(spread, 240, 26, function()
        if not spread.sel then return end
        S.story = { layer = spread.sel.layer, option = spread.sel.option }
        ShowBook(false)
        Refresh()
    end)
    spread.pick:SetPoint("BOTTOMRIGHT", -120, 14)
    local none = ParchButton(spread, 100, 26, function() S.story, spread.sel = nil, nil ShowBook(false) Refresh() end)
    none:SetPoint("BOTTOMRIGHT", -14, 14)
    spread.none = none
    spread:Hide()
    W.spread = spread
    hooksecurefunc(spread, "Show", function()
        spread.title:SetText(O("What's he thinking about?", "THINK?"))
        spread.note:SetText(O("Pick a piece and he'll dream about it for sure. It costs Bedtime Stories by its rarity, and doesn't count towards the painting's luck.",
            "PICK THING. HE DREAM IT."))
        none.label:SetText(O("Nothing", "ZZZ"))
    end)
end

-- The thought bubble over his head while he lies there: a cloud of soft discs (an outline behind, cream in front) and
-- two puffs trailing down to him. Empty: Zzz. Click it: the picker (W.spread); what you picked shows in it.
-- THOUGHT: its middle and size as fractions of the room; the puffs from it towards his head.
local THOUGHT = { x = 0.335, y = 0.21, w = 0.16, h = 0.18 }
local THOUGHT_PUFFS = { { 0.4, 1.1, 0.12 }, { 0.25, 1.32, 0.075 } }  -- (x, y in the bubble's size from its top-left; radius in its width)
local CLOUD = { { 0.5, 0.5, 0.62 }, { 0.26, 0.55, 0.42 }, { 0.74, 0.55, 0.42 }, { 0.36, 0.3, 0.42 }, { 0.64, 0.3, 0.42 },
    { 0.4, 0.74, 0.38 }, { 0.62, 0.74, 0.38 } }  -- (x, y, diameter: fractions of the bubble)
local function BuildThought()
    local bw, bh = THOUGHT.w * S.w, THOUGHT.h * S.h
    local b = CreateFrame("Button", nil, W.screen)
    b:SetSize(bw, bh)
    b:SetPoint("CENTER", W.screen, "TOPLEFT", THOUGHT.x * S.w, -THOUGHT.y * S.h)
    b:SetFrameLevel(W.screen:GetFrameLevel() + 8)
    -- (pass 1: the brown outline; 2: the cream over it. disc.blp is white to its edge, so the overlaps don't show)
    local function Blob(x, y, d, pass)  -- (a disc at x, y of the bubble, d across)
        local t = b:CreateTexture(nil, pass == 1 and "BACKGROUND" or "BORDER")
        local size = pass == 1 and d + 5 or d
        t:SetTexture(DISC)
        t:SetSize(size, size)
        t:SetPoint("CENTER", b, "TOPLEFT", x, -y)
        if pass == 1 then t:SetVertexColor(0.45, 0.3, 0.15) else t:SetVertexColor(PARCH[1], PARCH[2], PARCH[3]) end
        return t
    end
    for pass = 1, 2 do
        for _, c in ipairs(CLOUD) do Blob(c[1] * bw, c[2] * bh, c[3] * math.min(bw, bh) * 1.25, pass) end
        for _, p in ipairs(THOUGHT_PUFFS) do Blob(p[1] * bw, p[2] * bh, p[3] * bw * 2, pass) end
    end
    local glow = b:CreateTexture(nil, "BACKGROUND", nil, -1)  -- (on hover)
    glow:SetPoint("CENTER")
    glow:SetSize(bw * 1.7, bh * 1.7)
    glow:SetTexture(GLOW)
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(1, 0.85, 0.4)
    glow:Hide()
    b.zzz = Text(b, 22, CRAYON_FONT)
    b.zzz:SetPoint("CENTER", 0, 2)
    b.zzz:SetTextColor(0.42, 0.33, 0.5)
    b.zzz:SetText("Zzz")
    b.canvas = CreateFrame("Frame", nil, b)
    b.canvas:SetSize(math.min(bw, bh) * 0.78, math.min(bw, bh) * 0.78)
    b.canvas:SetPoint("CENTER", 0, 2)
    b:SetScript("OnClick", function()
        if S.phase ~= "bed" then return end
        Click()
        local spread = W.spread
        spread.chapter = S.story and S.story.layer or spread.chapter
        spread.sel = S.story and { layer = S.story.layer, option = S.story.option } or nil
        spread:Show()
        ShowBook(true)
    end)
    b:SetScript("OnEnter", function(self)
        glow:Show()
        local option = S.story and S.story.option
        if UI.Tooltip then
            UI.Tooltip(self, { O("What he's thinking about", "THINK"), option
                and ("|c%s%s|r"):format(ns.RARITY_COLORS[option.rarity] or "ffffffff", option.name)
                or O("Nothing yet. Click to pick a piece he'll dream about", "NOTHING. CLICK.") })
        end
    end)
    b:SetScript("OnLeave", function() glow:Hide() GameTooltip_Hide() end)
    W.bubble = b
    -- What's in it: story = { layer, option } or nil (Zzz).
    function W.ShowThought(story)
        b.zzz:SetShown(story == nil)
        b.canvas:SetShown(story ~= nil)
        if story then ns.DrawPiece(b.canvas, story.layer, story.option) end
    end
end

local function Build()
    local area = UI.pageArea
    S.w = area and area:GetWidth() > 0 and area:GetWidth() or (UI.PAGE_WIDTH or 827)
    S.h = area and area:GetHeight() > 0 and area:GetHeight() or (UI.PAGE_HEIGHT or 584)
    local screen = CreateFrame("Frame", "SOLCDreamBed", UIParent)
    screen:SetSize(S.w, S.h)
    screen:EnableMouse(true)
    screen:SetClipsChildren(true)  -- (the bed and quilt run off the page's edges: cut there)
    screen:Hide()
    W.screen = screen
    screen:SetScript("OnUpdate", function(_, elapsed) Tick(elapsed) end)
    screen:SetScript("OnHide", function() if UI.ClearScreen then UI.ClearScreen("Dream Bed") end end)

    -- The room (the painting, its sides cropped to the page's shape; its wall's wooden panel stretched down to the laid-out
    -- floor line), the window's sky behind it, the floor behind its cut-out floor (below the wall only), the rug on that.
    local art, L = ns.DreamBedArt, ns.DreamBedArt.layout
    local fx = (S.w / S.h) / (art.room.w / art.room.h)
    local left = (1 - fx) / 2
    local wallTo = L.wall and L.wall.floor or art.room.floor
    local panelFrom = art.room.floor - PANEL
    local back = CreateFrame("Frame", nil, screen)
    back:SetAllPoints()
    back:SetFrameLevel(screen:GetFrameLevel() + 2)
    local wall = back:CreateTexture(nil, "BACKGROUND", nil, -8)
    wall:SetTexture(ART_PATH .. "room")
    wall:SetTexCoord(left, left + fx, 0, panelFrom)
    wall:SetPoint("TOPLEFT")
    wall:SetSize(S.w, panelFrom * S.h)
    local panel = back:CreateTexture(nil, "BACKGROUND", nil, -8)
    panel:SetTexture(ART_PATH .. "room")
    panel:SetTexCoord(left, left + fx, panelFrom, art.room.floor)
    panel:SetPoint("TOPLEFT", 0, -panelFrom * S.h)
    panel:SetSize(S.w, (wallTo - panelFrom) * S.h)
    if art.floor then  -- (slid and zoomed as laid out)
        local under = CreateFrame("Frame", nil, screen)
        under:SetPoint("TOPLEFT", 0, -S.h / 2) under:SetPoint("BOTTOMRIGHT")
        under:SetClipsChildren(true)
        under:SetFrameLevel(screen:GetFrameLevel() + 1)
        local f, ff = L.floor or {}, (S.w / S.h) / (art.floor.w / art.floor.h)
        local z = f.zoom or 1
        local floor = under:CreateTexture(nil, "BACKGROUND")
        floor:SetTexture(ART_PATH .. "floor")
        floor:SetTexCoord((1 - ff) / 2, (1 + ff) / 2, 0, 1)
        floor:SetPoint("TOPLEFT", screen, "TOPLEFT", S.w / 2 - S.w * z / 2 + (f.x or 0) * S.w, -(S.h / 2 - S.h * z / 2 + (f.y or 0) * S.h))
        floor:SetSize(S.w * z, S.h * z)
    end
    if L.rug then Piece(back, "rug", L.rug, nil, "BACKGROUND", -6) end

    -- The window and its sky (clipped to the painting's glass).
    local win = art.room.window
    W.window = CreateFrame("Frame", nil, screen)
    W.window:SetPoint("TOPLEFT", (win.x - left) / fx * S.w, -win.y * S.h)
    W.window:SetSize(win.w / fx * S.w, win.h * S.h)
    W.window:SetFrameLevel(screen:GetFrameLevel() + 1)
    W.window:SetClipsChildren(true)
    W.sky = W.window:CreateTexture(nil, "BACKGROUND")
    W.sky:SetAllPoints()
    W.sky:SetColorTexture(1, 1, 1)
    W.stars = {}
    for i = 1, 18 do
        local star = W.window:CreateTexture(nil, "BORDER")
        star:SetSize(3, 3)
        star:SetColorTexture(1, 1, 1)
        star:SetPoint("TOPLEFT", math.random() * W.window:GetWidth(), -math.random() * W.window:GetHeight() * 0.7)
        star.base = 0.4 + math.random() * 0.6
        W.stars[i] = star
    end
    -- (the moon and the sun: a soft-edged disc with a halo round it)
    local function Orb(size, color, halo)
        local orb = W.window:CreateTexture(nil, "ARTWORK", nil, 1)
        orb:SetSize(size, size)
        orb:SetTexture(DISC)
        orb:SetVertexColor(color[1], color[2], color[3])
        local glow = W.window:CreateTexture(nil, "ARTWORK")
        glow:SetSize(size * 3, size * 3)
        glow:SetPoint("CENTER", orb)
        glow:SetTexture(GLOW)
        glow:SetBlendMode("ADD")
        glow:SetVertexColor(halo[1], halo[2], halo[3])
        return orb
    end
    W.moon = Orb(30, { 1, 0.97, 0.82 }, { 0.45, 0.45, 0.4 })
    W.sun = Orb(40, { 1, 0.9, 0.45 }, { 0.75, 0.55, 0.2 })
    W.aurora = {}
    for i = 1, 2 do
        local a = W.window:CreateTexture(nil, "ARTWORK", nil, 1)
        a:SetTexture(GLOW)
        a:SetBlendMode("ADD")
        a:SetSize(W.window:GetWidth() * 1.4, W.window:GetHeight() * 0.5)
        a:SetPoint("CENTER", W.window, "TOP", (i - 1.5) * 50, -W.window:GetHeight() * 0.3)
        a:SetAlpha(0)
        W.aurora[i] = a
    end
    W.shooters = {}
    for i = 1, 4 do
        local s = W.window:CreateTexture(nil, "OVERLAY")
        s:SetSize(40, 2)
        s:SetColorTexture(1, 1, 1)
        s:SetRotation(math.rad(-20))
        s:Hide()
        W.shooters[i] = s
    end

    -- The nightstand, then the bed: headboard, pillow; your ogre's head; the quilt in front.
    Piece(back, "nightstand", L.nightstand, nil, "ARTWORK", 0)
    Piece(back, "headboard", L.headboard, nil, "ARTWORK", 1)
    Piece(back, "pillow", L.pillow, nil, "ARTWORK", 2)
    W.head = CreateFrame("Frame", nil, screen)
    W.head:SetSize(L.head.size * S.h, L.head.size * S.h)
    W.head:SetPoint("TOPLEFT", screen, "TOPLEFT", L.head.x * S.w, -L.head.top * S.h)
    W.head:SetFrameLevel(screen:GetFrameLevel() + 3)
    local quilt = CreateFrame("Frame", nil, screen)
    quilt:SetAllPoints()
    quilt:SetFrameLevel(screen:GetFrameLevel() + 4)
    Piece(quilt, "quilt", L.quilt)
    W.dream = screen:CreateTexture(nil, "OVERLAY", nil, 2)
    W.dream:SetSize(S.w * 0.22, S.h * 0.22)
    W.dream:SetPoint("CENTER", W.head, "TOPRIGHT", 0, -S.h * 0.02)  -- (above his head: the dream's glow)
    W.dream:SetTexture(GLOW)
    W.dream:SetBlendMode("ADD")
    W.dream:SetAlpha(0)
    BuildThought()

    -- On the nightstand: candle (just its light), mug (milk). Each a button over its piece.
    local function PropOver(rect, onClick, title) return Prop(rect.x / S.w, rect.y / S.h, rect.w / S.w, rect.h / S.h, onClick, title) end
    local function At(name) local x, y, w, h = PieceRect(L[name], art.pieces[name].box) return { x = x, y = y, w = w, h = h } end
    local candleAt = At("candle")
    W.candle = PropOver(candleAt, function() end)
    W.candle:EnableMouse(false)  -- (no clicking: it goes out by itself)
    Piece(W.candle, "candle", L.candle)
    -- (the flame on its wick: placed from the candle, as laid out)
    local flameBox = art.pieces.flame.box
    local fw = L.flame.w * S.w
    local fh = fw * flameBox.h / flameBox.w
    local flameSpec = { w = L.flame.w, x = (candleAt.x + candleAt.w * L.flame.dx - fw / 2) / S.w, top = (candleAt.y - fh * L.flame.dy) / S.h }
    local flameAt
    W.flame, flameAt = Piece(W.candle, "flame", flameSpec, flameBox, "OVERLAY")
    W.flameGlow = W.candle:CreateTexture(nil, "OVERLAY", nil, 1)
    W.flameGlow:SetSize(fw * 5, fw * 5)
    W.flameGlow:SetPoint("CENTER", W.screen, "TOPLEFT", flameAt.x + flameAt.w / 2, -(flameAt.y + flameAt.h * 0.6))
    W.flameGlow:SetTexture(GLOW)
    W.flameGlow:SetBlendMode("ADD")
    W.flameGlow:SetVertexColor(1, 0.75, 0.4)
    -- (the candle's light on the room: warm, round, gone when it's blown out)
    local glowLayer = CreateFrame("Frame", nil, screen)
    glowLayer:SetAllPoints()
    glowLayer:SetFrameLevel(screen:GetFrameLevel() + 5)
    W.candleLight = glowLayer:CreateTexture(nil, "OVERLAY")
    W.candleLight:SetSize(S.w * 0.34, S.w * 0.34)
    W.candleLight:SetPoint("CENTER", W.screen, "TOPLEFT", flameAt.x + flameAt.w / 2, -(flameAt.y + flameAt.h))
    W.candleLight:SetTexture(GLOW)
    W.candleLight:SetBlendMode("ADD")
    W.candleLight:SetVertexColor(0.55, 0.36, 0.17)
    W.smoke = W.candle:CreateTexture(nil, "OVERLAY")
    W.smoke:SetSize(26, 40)
    W.smoke:SetPoint("BOTTOM", W.screen, "TOPLEFT", flameAt.x + flameAt.w / 2, -(flameAt.y + flameAt.h * 0.6))
    W.smoke:SetTexture(GLOW)
    W.smoke:SetBlendMode("ADD")
    W.smoke:SetVertexColor(0.45, 0.45, 0.5)
    W.smoke:Hide()
    local mugAt = At("mug")
    W.mug = PropOver(mugAt, function() S.milk = (S.milk + 1) % 4 if S.milk > ns.Tokens("milk") then S.milk = 0 end Refresh() end,
        function() return O("Warm Milk: click to pour", "MILK") end)
    Piece(W.mug, "mug", L.mug)
    W.steam = {}
    for i = 1, 3 do  -- (a wisp of steam for each splash of milk)
        local steam = W.mug:CreateTexture(nil, "OVERLAY", nil, 1)
        steam:SetSize(mugAt.w * 0.35, mugAt.h * 0.7)
        steam:SetPoint("BOTTOM", W.screen, "TOPLEFT", mugAt.x + mugAt.w * (0.25 + i * 0.12), -(mugAt.y + mugAt.h * 0.15))
        steam:SetTexture(GLOW)
        steam:SetBlendMode("ADD")
        steam:SetVertexColor(0.5, 0.5, 0.5)
        W.steam[i] = steam
    end
    -- The mallet by the nightstand: a Bonk, good night (ogres go to sleep by bonking their heads).
    local malletAt = At("mallet")
    W.mallet = PropOver(malletAt, GoodNight, function() return O("The mallet: good night", "BONK HIM") end)
    W.malletTex = Piece(W.mallet, "mallet", L.mallet)
    if L.peg and art.pieces.peg then Piece(W.mallet, "peg", L.peg, nil, "OVERLAY") end  -- (it hangs on it: the peg stays put)
    -- (what's on each, in its tooltip: the milk poured, the bonks)
    W.mugTag, W.malletTag = W.mug.tag, W.mallet.tag

    -- Your easel (its painted picture; the canvas the dream is painted on, where its blank canvas is), the brush's
    -- stroke, the burst when you reach for the crayons. (Not turned: the painting on it stays square.)
    local easelBox = art.pieces.easel.box
    local ex, ey, ew, eh = PieceRect(L.easel, easelBox)
    W.easel = CreateFrame("Frame", nil, screen)
    W.easel.x, W.easel.y = ex, ey
    W.easel:SetSize(ew, eh)
    W.easel:SetPoint("TOPLEFT", screen, "TOPLEFT", ex, -ey)
    W.easel:SetFrameLevel(screen:GetFrameLevel() + 14)  -- (above the room's light: the painting's colours untouched)
    local board = W.easel:CreateTexture(nil, "BACKGROUND")
    board:SetAllPoints()
    board:SetTexture(ART_PATH .. "easel")
    board:SetTexCoord(easelBox.x, easelBox.x + easelBox.w, easelBox.y, easelBox.y + easelBox.h)
    local cv = art.easelCanvas or { x = 0.08, y = 0.12, w = 0.82, h = 0.45 }
    -- (the painting must be square - its layers are placed by its width - so a square as wide as the blank canvas,
    -- in its middle, cut at its edges)
    local blank = CreateFrame("Frame", nil, W.easel)
    blank:SetPoint("TOPLEFT", cv.x * ew, -cv.y * eh)
    blank:SetSize(cv.w * ew, cv.h * eh)
    blank:SetClipsChildren(true)
    local side = math.max(cv.w * ew, cv.h * eh)
    W.canvas = CreateFrame("Frame", nil, blank)
    W.canvas:SetPoint("CENTER")
    W.canvas:SetSize(side, side)
    -- (the copy the new layer is masked in on, over it; the tool painting it, over everything on the easel)
    W.canvasNew = CreateFrame("Frame", nil, blank)
    W.canvasNew:SetPoint("CENTER")
    W.canvasNew:SetSize(side, side)
    W.canvasNew:SetFrameLevel(W.canvas:GetFrameLevel() + 1)
    W.wipe = W.canvasNew:CreateMaskTexture()
    W.wipe:SetTexture(ART_PATH .. "wipe", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    W.wipe:SetPoint("TOPLEFT")
    W.wipe:SetSize(side, 1)
    W.canvasNew:Hide()
    local hand = CreateFrame("Frame", nil, W.easel)
    hand:SetAllPoints()
    hand:SetFrameLevel(W.easel:GetFrameLevel() + 8)
    W.painter = hand:CreateTexture(nil, "OVERLAY")
    W.painter:Hide()
    W.burst = W.easel:CreateTexture(nil, "OVERLAY")
    W.burst:SetPoint("CENTER")
    W.burst:SetTexture(GLOW)
    W.burst:SetBlendMode("ADD")
    W.burst:Hide()
    local shade = CreateFrame("Frame", nil, W.easel)  -- (the night on the easel: over the canvas too)
    shade:SetAllPoints()
    shade:SetFrameLevel(W.easel:GetFrameLevel() + 5)
    W.easelDark = shade:CreateTexture(nil, "OVERLAY")
    W.easelDark:SetAllPoints()
    W.easelDark:SetColorTexture(0.03, 0.02, 0.1)
    W.easelDark:SetAlpha(0)
    -- (cut to the easel's own shape - its picture's see-through parts - or it's a dark box on the wall behind it; the
    -- mask is the whole square picture, placed like the board's cut-out of it)
    local easelMask = shade:CreateMaskTexture()
    easelMask:SetTexture(ART_PATH .. "easel", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    easelMask:SetSize(ew / easelBox.w, eh / easelBox.h)
    easelMask:SetPoint("TOPLEFT", W.easel, "TOPLEFT", -easelBox.x * ew / easelBox.w, easelBox.y * eh / easelBox.h)
    W.easelDark:AddMaskTexture(easelMask)
    W.signature = Text(blank, 12)
    W.signature:SetPoint("BOTTOMRIGHT", -6, 4)
    W.signature:SetTextColor(0.25, 0.16, 0.08)
    W.signature:Hide()

    -- The jar on the easel's ledge: its back, the tools standing in it (brush: painted, pencil: sketched, crayon), its
    -- front over them.
    W.jar = CreateFrame("Frame", nil, W.easel)  -- (on the easel: over it, under its night shade)
    W.jar:SetAllPoints(screen)
    W.jar:SetFrameLevel(W.easel:GetFrameLevel() + 2)
    local jarBox = art.pieces.jar.box
    Piece(W.jar, "jar", L.jar, jarBox, "ARTWORK", 0)
    W.tools = {}
    for edition, name in pairs({ painted = "brush", sketch = "pencils", crayon = "crayon" }) do
        W.tools[edition] = Piece(W.jar, name, L[name], nil, "ARTWORK", 1)
    end
    if art.pieces.jarfront then Piece(W.jar, "jarfront", L.jar, jarBox, "ARTWORK", 2) end

    -- The light over the room: the lamp's night, the morning's warmth.
    local light = CreateFrame("Frame", nil, screen)
    light:SetAllPoints()
    light:SetFrameLevel(screen:GetFrameLevel() + 12)
    W.dark = light:CreateTexture(nil, "OVERLAY")
    W.dark:SetAllPoints()
    W.dark:SetColorTexture(0.03, 0.02, 0.1)
    W.dark:SetAlpha(0)
    W.warm = light:CreateTexture(nil, "OVERLAY")
    W.warm:SetAllPoints()
    W.warm:SetColorTexture(1, 0.83, 0.6)
    W.warm:SetBlendMode("ADD")
    W.warm:SetAlpha(0)

    -- Words: the speech bubble, the Zs, the hint, the counts.
    local words = CreateFrame("Frame", nil, screen)
    words:SetAllPoints()
    words:SetFrameLevel(screen:GetFrameLevel() + 20)
    W.speech = CreateFrame("Frame", nil, words, "BackdropTemplate")
    W.speech:SetPoint("TOPLEFT", screen, "TOPLEFT", S.w * 0.2, -S.h * 0.04)
    W.speech:SetWidth(S.w * 0.44)
    Parchment(W.speech)
    W.speech.text = Text(W.speech, 14)
    W.speech.text:SetPoint("TOPLEFT", 12, -12)
    W.speech.text:SetWidth(S.w * 0.44 - 24)
    W.speech.text:SetJustifyH("LEFT")
    W.speech.text:SetTextColor(INK[1], INK[2], INK[3])
    W.speech.text:SetSpacing(2)
    W.speech:Hide()
    W.zs = {}
    for i = 1, 3 do local z = Text(words, 20, CRAYON_FONT) z:SetText("Z") z:Hide() W.zs[i] = z end
    -- (the bonk: BONK! over his head, and the stars going round it)
    W.bonkText = CreateFrame("Frame", nil, words)
    W.bonkText:SetSize(160, 50)
    W.bonkText:SetPoint("CENTER", W.head, "TOP", 0, -W.head:GetHeight() * 0.1)
    W.bonkText.text = Text(W.bonkText, 34, CRAYON_FONT)
    W.bonkText.text:SetPoint("CENTER")
    W.bonkText.text:SetTextColor(1, 0.85, 0.3)
    W.bonkText.text:SetShadowOffset(2, -2)
    W.bonkText.SetText = function(self, text) self.text:SetText(text) end
    W.bonkText:Hide()
    -- (the roll: the reel of everything a layer could be, at the bottom while he remembers; its layer's name over it)
    W.reel = ns.NewMintReel(words, S.w * 0.5)
    W.reel.frame:SetPoint("BOTTOM", screen, "BOTTOMLEFT", S.w * 0.36, 40)
    W.reel.frame:Hide()
    W.reelLabel = Text(W.reel.frame, 14)
    W.reelLabel:SetPoint("BOTTOM", W.reel.frame, "TOP", 0, 3)
    W.reelLabel:SetTextColor(1, 0.91, 0.72)
    W.reelLabel:SetShadowOffset(1, -1)
    W.dizzy = {}
    for i = 1, 3 do
        local star = words:CreateTexture(nil, "OVERLAY")
        star:SetSize(18, 18)
        star:SetTexture("Interface\\AddOns\\SOLC\\Media\\Icons\\Fx_Star")
        star:SetVertexColor(1, 0.85, 0.3)
        star:Hide()
        W.dizzy[i] = star
    end
    W.hint = Text(words, 18)
    W.hint:SetPoint("BOTTOM", screen, "BOTTOM", 0, 10)
    W.hint:SetTextColor(0.96, 0.9, 0.69)
    W.hint:SetShadowOffset(1, -1)
    -- (the way out: back to the page; a dream already dreamt is saved at the bonk, so leaving only skips its show)
    W.back = ParchButton(words, 84, 24, function() screen:Hide() end)
    W.back.label:SetText(O("< Back", "< GO"))
    W.back:SetPoint("TOPLEFT", screen, "TOPLEFT", 10, -8)
    W.back:SetFrameLevel(screen:GetFrameLevel() + 45)
    W.counts = Text(words, 13)
    W.counts:SetPoint("TOPRIGHT", screen, "TOPRIGHT", -44, -8)  -- (clear of the close button)
    W.counts:SetTextColor(0.96, 0.9, 0.69)
    W.counts:SetShadowOffset(1, -1)

    -- Tapping (asleep: the Zs; morning: the telling).
    W.tap = CreateFrame("Button", nil, screen)
    W.tap:SetAllPoints()
    W.tap:SetFrameLevel(screen:GetFrameLevel() + 30)
    W.tap:SetScript("OnClick", Tap)
    W.tap:Hide()

    -- The finished painting's note and tags.
    W.verdict = CreateFrame("Frame", nil, words, "BackdropTemplate")
    W.verdict:SetPoint("TOPLEFT", screen, "TOPLEFT", 12, -12)
    W.verdict:SetWidth(S.w * 0.28)
    W.verdict:SetFrameLevel(screen:GetFrameLevel() + 35)
    Parchment(W.verdict)
    W.verdict.text = Text(W.verdict, 13)
    W.verdict.text:SetPoint("TOPLEFT", 12, -12)
    W.verdict.text:SetWidth(S.w * 0.28 - 24)
    W.verdict.text:SetJustifyH("LEFT")
    W.verdict.text:SetTextColor(INK[1], INK[2], INK[3])
    W.verdict:Hide()
    -- (the frame's kept as you click it: this one just takes you back to the room)
    W.again = ParchButton(words, 180, 28, function() Reset() end)
    W.again:SetPoint("BOTTOM", screen, "BOTTOM", 0, 12)
    W.again:SetFrameLevel(screen:GetFrameLevel() + 35)
    W.again:Hide()

    -- The finished painting off the easel: in the middle, big, in its frame (Frames.lua); the frames to pick under it.
    W.show = CreateFrame("Frame", nil, screen)
    W.show:SetAllPoints()
    W.show:SetFrameLevel(screen:GetFrameLevel() + 19)  -- (over the room and easel, under the words: the hint shows)
    local dim = W.show:CreateTexture(nil, "BACKGROUND")
    dim:SetAllPoints()
    dim:SetColorTexture(0.03, 0.02, 0.08, 0.6)
    local side = S.h * 0.7  -- (the painting itself 72% of it: its frame round it, clear of the row of frames below)
    W.showCanvas = CreateFrame("Frame", nil, W.show)
    W.showCanvas:SetSize(side, side)
    W.showCanvas:SetPoint("CENTER", screen, "CENTER", 0, S.h * 0.1)
    -- (your signature in the painting's corner, like a painter's: over the picture, with it as it grows)
    local sig = CreateFrame("Frame", nil, W.showCanvas)
    sig:SetAllPoints()
    sig:SetFrameLevel(W.showCanvas:GetFrameLevel() + 6)
    local picture = side * 0.72
    W.showSignature = Text(sig, 13)
    W.showSignature:SetPoint("BOTTOMRIGHT", W.showCanvas, "CENTER", picture / 2 - 6, -picture / 2 + 5)
    W.showSignature:SetTextColor(0.2, 0.12, 0.06)
    W.showSignature:SetShadowColor(1, 0.95, 0.85, 0.6)
    W.showSignature:SetShadowOffset(1, -1)
    -- The frames to pick: your painting in each, small, in a row (the one on it glowing, the ones you haven't got
    -- faded; their names on hover).
    W.frameTiles = {}
    local frames = ns.PICTURE_FRAMES or {}
    local tw, gap = 64, 12
    -- (a dark shelf behind the row: the quilt and floor under it are too busy to read the frames on)
    local shelf = CreateFrame("Frame", nil, W.show, "BackdropTemplate")
    -- (the whole bottom, edge to edge: its border runs off the sides and bottom, cut by the room's edges)
    shelf:SetPoint("BOTTOMLEFT", screen, "BOTTOMLEFT", -6, -6)
    shelf:SetPoint("BOTTOMRIGHT", screen, "BOTTOMRIGHT", 6, -6)
    shelf:SetHeight(48 + tw + 8 + 6)
    shelf:SetFrameLevel(W.showCanvas:GetFrameLevel() + 8)
    shelf:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    shelf:SetBackdropColor(0.09, 0.06, 0.04, 0.88)
    shelf:SetBackdropBorderColor(0.45, 0.3, 0.15)
    for i, frame in ipairs(frames) do
        local tile = CreateFrame("Button", nil, W.show)
        tile:SetSize(tw, tw)
        tile:SetPoint("BOTTOM", screen, "BOTTOM", (i - (#frames + 1) / 2) * (tw + gap), 48)
        tile:SetFrameLevel(W.showCanvas:GetFrameLevel() + 10)  -- (over the big painting's frame, never under it)
        tile.glow = tile:CreateTexture(nil, "BACKGROUND")
        tile.glow:SetPoint("CENTER")
        tile.glow:SetSize(tw * 1.5, tw * 1.5)
        tile.glow:SetTexture(GLOW)
        tile.glow:SetBlendMode("ADD")
        tile.glow:SetVertexColor(1, 0.8, 0.3)
        tile.canvas = CreateFrame("Frame", nil, tile)
        tile.canvas:SetAllPoints()
        tile.frame = frame
        tile:SetScript("OnClick", function()
            if not S.mint or not ns.FrameUnlocked(frame) then return end
            Click()
            ns.SetMintFrame(S.mint, frame.id)
            ns.DrawMint(W.showCanvas, S.mint)
            W.ShowFrames()
        end)
        tile:SetScript("OnEnter", function(self)
            local have, how = ns.FrameUnlocked(frame)
            if UI.Tooltip then UI.Tooltip(self, { frame.name, have and O("Click to frame it", "THIS ONE") or ("|cffff6060" .. (how or "Locked") .. "|r") }) end
        end)
        tile:SetScript("OnLeave", GameTooltip_Hide)
        W.frameTiles[i] = tile
    end
    function W.ShowFrames()
        local mint = S.mint
        if not mint then return end
        local on = mint.frame or ns.DefaultFrame()
        for _, tile in ipairs(W.frameTiles) do
            ns.DrawMint(tile.canvas, { number = mint.number, traits = mint.traits, style = mint.style, frame = tile.frame.id })
            tile:SetAlpha(ns.FrameUnlocked(tile.frame) and 1 or 0.35)
            tile.glow:SetShown(tile.frame.id == on)
        end
    end
    W.show:Hide()

    BuildBook()
end

-- Opens the Dream Bed over the main window's pages. The first time: a few stories and some milk to start with.
function ns.ShowDreamBed()
    if not W.screen then Build() end
    local screen, pageArea = W.screen, UI.pageArea
    screen:ClearAllPoints()
    if pageArea then
        if not pageArea:IsVisible() then ns.ToggleUI() end
        screen:SetParent(pageArea)
        screen:SetAllPoints(pageArea)
        screen:SetFrameStrata(pageArea:GetFrameStrata())
        screen:SetFrameLevel(pageArea:GetFrameLevel() + 50)
    else
        screen:SetParent(UIParent)
        screen:SetPoint("CENTER")
        screen:SetFrameStrata("DIALOG")
    end
    local db = KillTrackerDB
    if not db.dreamGift then
        db.dreamGift = time()
        ns.AddIngredient("story", 3, true)
        ns.AddIngredient("milk", 2, true)
        ns.Print("The Dream Bed: 3 Bedtime Stories and 2 Warm Milk to start you off.")
    end
    S.milk = S.milk or 0
    local dreaming = S.phase and S.phase ~= "bed" and S.phase ~= "done" and S.mint
    screen:Show()
    if not dreaming then  -- (mid-dream: it just carries on - its clock waited while you were away)
        Reset()
        local pending
        for _, mint in ipairs(db.mints) do if mint.number == db.dreamPending then pending = mint end end
        if pending then Resume(pending) elseif db.dreamPending then db.dreamPending = nil end
    end
    if UI.SetScreen then UI.SetScreen("Dream Bed", "DREAM", function() screen:Hide() end) end
end
