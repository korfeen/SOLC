-- The chest window: opening your dungeon chests (Unlocks.lua), over the main window's pages like the mint reel. A show
-- in crayon that gets wilder the more you tap, and wildest for the rare chests (a chest's tier: ns.CHEST_TIERS):
-- 1. Shut: the chest bobs on a warm glow. "Tap the chest!"
-- 2. Charging: 2 + the tier taps (3 for a common, 6 for a legendary). Each tap the chest jumps and rocks harder, throws
--    sparkles, a comic word and a shockwave ring, light leaks out under its lid, and the rays behind it spin faster;
--    from the second tap the light climbs a tier's colour a tap (green, blue, purple, orange) and the count beside it
--    with it (x1, x2, ...) up to the chest's: that's how many items are inside. An epic or legendary chest may fake out
--    (it holds a colour a tap, then jumps two).
-- 3. Burst: a flash, a comic burst, the lid flies open, the chest glides up, coins spray out and the points tick up.
--    Epic and up: confetti, the whole window shaking, the coins piling up at the bottom. Legendary: a heartbeat of
--    slow motion first, then rainbow light, a rainbow over the chest, fireworks, and an ogre popping up to cheer.
-- 4. Reveal: each tap pulls the next item out: its card flies from the chest to its place with a bounce, sparkles, and
--    rays behind it for an epic or legendary one; a legendary one comes face down (a "?") and flips; a chase item gets
--    a banner. Then the next chest of that dungeon, if you have more, or close.
-- Everything is drawn with the crayon textures from tools/make-role-icons.js (Chest, ChestOpen, Fx_*), tinted.
-- ns.ShowChest(dungeon key[, preview]): one of your chests of that dungeon (the PIX page's tiles, one per dungeon);
-- preview (dev mode, Dev.lua): everything that dungeon's chest can hold, nothing unlocked.

local _, ns = ...

local ICONS = "Interface\\AddOns\\SOLC\\Media\\Icons\\"
local FX = ICONS .. "Fx_"
local NAME_FONT = "Interface\\AddOns\\SOLC\\Media\\Fonts\\GermaniaOne-Regular.ttf"
-- In the panel (the page area, 827 x 584), top to bottom: the chest's centre (shut: the middle of the window; open:
-- higher, it glides up when it bursts), the hint under it, the coins' line, the cards' row (their centres), the
-- buttons at the bottom; the floor the coins pile up on.
local STAGE = { shut = -275, open = -165, chest = 220 }
local COINS_Y, CARDS_Y, BUTTONS_Y, FLOOR_Y = -336, -432, -560, -566
local CARD, CARD_GAP, MAX_CARDS = 120, 16, 5
local BUTTON_WORD = { 1, 0.93, 0.78 }
local RANK = { uncommon = 1, rare = 2, epic = 3, legendary = 4 }
local LEVELS = { "uncommon", "rare", "epic", "legendary" }
local WARM = { 1, 0.85, 0.5 }  -- before any tier shows
local GRAVITY = -900
local CONFETTI = { { 1, 0.29, 0.23 }, { 1, 0.6, 0.16 }, { 1, 0.82, 0.25 }, { 0.36, 0.82, 0.29 }, { 0.31, 0.53, 0.91 }, { 0.6, 0.42, 0.85 } }
local TAP_WORDS = { "BONK!", "SHAKE!", "OOH!", "WHAM!", "WOW!" }
local OGRE_WORDS = { "SMASH!", "BONK!", "LOOT!", "MORE!", "GOLD!" }
local TAP_HINTS = { "Again!", "Harder!", "It's shaking...", "Something big...", "!!!" }

local function Sound(name)
    local id = SOUNDKIT and SOUNDKIT[name]
    if id then pcall(PlaySound, id) end
end
local function Tint(level) return level and level > 0 and { ns.RarityRGB(LEVELS[level]) } or WARM end
local function Rarity(text) return (text:gsub("^%l", string.upper)) end
local function Hue(h)  -- a rainbow colour, h going round 0..1
    local i, f = math.floor(h * 6) % 6, h * 6 - math.floor(h * 6)
    local rgb = ({ { 1, f, 0 }, { 1 - f, 1, 0 }, { 0, 1, f }, { 0, 1 - f, 1 }, { f, 0, 1 }, { 1, 0, 1 - f } })[i + 1]
    return rgb[1] * 0.6 + 0.4, rgb[2] * 0.6 + 0.4, rgb[3] * 0.6 + 0.4  -- (crayon, not neon)
end

-- The panel --------------------------------------------------------------------------------------------------------

local panel = CreateFrame("Frame", "SOLCChest", UIParent, "BackdropTemplate")
panel:SetBackdrop({
    bgFile = ns.WINDOW_BACKGROUND,  -- solid
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 32, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
panel:SetBackdropColor(unpack(ns.WINDOW_COLOR))
panel:EnableMouse(true)
panel:Hide()

local function Text(parent, size, r, g, b)
    local text = parent:CreateFontString(nil, "OVERLAY")
    text:SetFont(NAME_FONT, size, "")
    text:SetTextColor(r, g, b)
    ns.UI.OutlineText(text, { 0, 0, 0 })
    return text
end
-- A texture on the panel, drawn as light (ADD) or not.
local function Art(file, layer, sublevel, light)
    local tex = panel:CreateTexture(nil, layer or "ARTWORK", nil, sublevel or 0)
    tex:SetTexture(file)
    if light then tex:SetBlendMode("ADD") end
    return tex
end
local function Put(region, x, y) region:ClearAllPoints() region:SetPoint("CENTER", panel, "TOP", x, y) end

panel.title = Text(panel, 30, 1, 0.82, 0.25)
panel.title:SetPoint("TOP", 0, -18)
panel.left = Text(panel, 15, 0.75, 0.7, 0.6)
panel.left:SetPoint("TOP", panel.title, "BOTTOM", 0, -4)
panel.hint = Text(panel, 24, 1, 1, 1)

-- Behind the chest: the rainbow (legendary), the glow, the rays, the shockwave rings.
local rainbow = Art(FX .. "Rainbow", "BACKGROUND", 0)
rainbow:Hide()
local glow = Art(FX .. "Glow", "BACKGROUND", 1, true)
local rays = Art(FX .. "Rays", "BACKGROUND", 2, true)
local rings = {}
for i = 1, 4 do
    rings[i] = Art(FX .. "Ring", "BACKGROUND", 3, true)
    rings[i]:Hide()
end
local chestHolder = CreateFrame("Frame", nil, panel)  -- (scaled for the jumps, moved for the shake)
chestHolder:SetSize(STAGE.chest, STAGE.chest)
local chest = chestHolder:CreateTexture(nil, "ARTWORK")
chest:SetAllPoints()
local leak = chestHolder:CreateTexture(nil, "OVERLAY")  -- light leaking out under the lid
leak:SetTexture(FX .. "Glow")
leak:SetBlendMode("ADD")
leak:SetSize(STAGE.chest * 0.85, 34)
leak:SetPoint("CENTER", 0, 4)
-- Over the chest and the cards (child frames draw over the panel's own textures): the burst, the flash, the particles,
-- the words, the ogre, the banner.
local top = CreateFrame("Frame", nil, panel)
top:SetAllPoints()
local burst = top:CreateTexture(nil, "OVERLAY", nil, 6)
burst:SetTexture(FX .. "Burst")
local flash = top:CreateTexture(nil, "OVERLAY", nil, 7)
flash:SetAllPoints()
flash:SetColorTexture(1, 1, 1)
flash:SetBlendMode("ADD")
local ogre = CreateFrame("Frame", nil, top)  -- the cheering ogre (legendary), from the bottom left
ogre:SetSize(190, 190)
ogre.art = ogre:CreateTexture(nil, "ARTWORK")
ogre.art:SetAllPoints()
ogre.art:SetTexture(FX .. "Ogre")
ogre.say = Text(ogre, 30, 1, 0.85, 0.25)
ogre.say:SetPoint("LEFT", ogre, "RIGHT", 0, 30)
ogre.say:SetText("BIG LOOT!")
ogre:Hide()
local banner = CreateFrame("Frame", nil, top)  -- a chase item's
banner:SetSize(600, 80)
banner.text = Text(banner, 54, 1, 1, 1)
banner.text:SetPoint("CENTER")
banner.text:SetText("CHASE ITEM!")
banner:Hide()

-- How many items are inside, beside the chest while it charges ("x2", in the tier's colour).
local countBadge = CreateFrame("Frame", nil, panel)
countBadge:SetSize(90, 60)
countBadge.text = Text(countBadge, 46, 1, 1, 1)
countBadge.text:SetPoint("CENTER")
countBadge:Hide()

-- The coins: the count ticking up, a coin beside it.
local coins = CreateFrame("Frame", nil, panel)
coins:SetSize(300, 36)
coins:SetPoint("CENTER", panel, "TOP", 0, COINS_Y)
coins.text = Text(coins, 28, 1, 0.85, 0.3)
coins.text:SetPoint("CENTER", 20, 0)
coins.icon = coins:CreateTexture(nil, "ARTWORK")
coins.icon:SetTexture(FX .. "Coin")
coins.icon:SetSize(36, 36)
coins.icon:SetPoint("RIGHT", coins.text, "LEFT", -6, 0)

-- The cards.
local cards = {}
for i = 1, MAX_CARDS do
    local card = CreateFrame("Frame", nil, panel)
    card:SetSize(CARD, CARD)
    card.rays = Art(FX .. "Rays", "BACKGROUND", 3, true)
    card.rays:SetSize(CARD * 2.2, CARD * 2.2)
    card.rim = card:CreateTexture(nil, "BACKGROUND")
    card.rim:SetPoint("TOPLEFT", -3, 3)
    card.rim:SetPoint("BOTTOMRIGHT", 3, -3)
    card.canvas = CreateFrame("Frame", nil, card)
    card.canvas:SetAllPoints()
    card.coin = card:CreateTexture(nil, "ARTWORK")  -- a bag of coins' card
    card.coin:SetTexture(FX .. "Coin")
    card.coin:SetSize(CARD * 0.62, CARD * 0.62)
    card.coin:SetPoint("CENTER")
    card.cover = CreateFrame("Frame", nil, card)  -- a legendary's back, before it flips
    card.cover:SetAllPoints()
    card.back = card.cover:CreateTexture(nil, "OVERLAY")
    card.back:SetTexture(FX .. "CardBack")
    card.back:SetPoint("CENTER")
    card.back:SetSize(CARD + 6, CARD + 6)
    card.name = Text(card, 16, 1, 1, 1)
    card.name:SetPoint("TOP", card, "BOTTOM", 0, -6)
    card.name:SetWidth(CARD + CARD_GAP - 2)
    card.what = Text(card, 13, 0.75, 0.7, 0.6)
    card.what:SetPoint("TOP", card.name, "BOTTOM", 0, -2)
    cards[i] = card
end

-- The buttons: wooden planks like the rest of SOLC's (ns.UI.SkinButton), at the bottom; Later alone while it's shut,
-- then the next chest and Close side by side.
local function Plank(width)
    local button = CreateFrame("Button", nil, panel)
    button:SetSize(width, 34)
    button.word = Text(button, 17, unpack(BUTTON_WORD))
    button.word:SetPoint("CENTER", 0, 1)
    ns.UI.SkinButton(button, { steady = true })
    function button:SetText(text) self.word:SetText(text) end
    return button
end
panel.open = Plank(250)
panel.close = Plank(150)
local function PlaceButtons(both)
    panel.close:ClearAllPoints()
    panel.close:SetPoint("CENTER", panel, "TOP", both and 115 or 0, BUTTONS_Y)
    panel.open:ClearAllPoints()
    panel.open:SetPoint("CENTER", panel, "TOP", -95, BUTTONS_Y)
end
panel.close:SetScript("OnClick", function()
    ns.UI.ClickSound()
    panel:Hide()
    if ns.OnKillsChanged then ns.OnKillsChanged() end
end)

-- Motion: tweens, particles and the show's state, all driven from OnUpdate -----------------------------------------

local tweens, particles, pool = {}, {}, {}
local words, wordPool = {}, {}
local show = {}  -- the show's state (see Shut)
local function Tween(duration, update, done) tweens[#tweens + 1] = { t = 0, d = duration, update = update, done = done } end
local function After(delay, done) Tween(delay, function() end, done) end  -- (cleared with the show, unlike C_Timer)
local function EaseOut(p) return 1 - (1 - p) ^ 3 end
local function Overshoot(p) local s = 1.7 return 1 + (s + 1) * (p - 1) ^ 3 + s * (p - 1) ^ 2 end

-- A particle: a crayon texture flying from (x, y) (the panel's top-middle space). opts: gravity (coins, confetti), floor
-- (lands and stays), flutter (confetti: sways, falls slowly), onEnd (a firework's rocket bursting).
local function Particle(file, x, y, vx, vy, size, tint, life, opts)
    local tex = table.remove(pool) or top:CreateTexture(nil, "OVERLAY", nil, 5)
    tex:SetTexture(file)
    tex:SetSize(size, size)
    tex:SetVertexColor(unpack(tint or { 1, 1, 1 }))
    tex:SetAlpha(1)
    tex:Show()
    opts = opts or {}
    particles[#particles + 1] = { tex = tex, x = x, y = y, vx = vx, vy = vy, life = life, age = 0, gravity = opts.gravity,
        floor = opts.floor, flutter = opts.flutter, onEnd = opts.onEnd, seed = math.random() * 6,
        spin = (math.random() - 0.5) * (opts.flutter and 4 or 8), angle = math.random() * 6 }
end
local function Sparkles(n, x, y, tint, speed)
    for _ = 1, n do
        local a, v = math.random() * 2 * math.pi, (0.4 + math.random()) * (speed or 260)
        Particle(FX .. "Star", x, y, math.cos(a) * v, math.sin(a) * v, 14 + math.random() * 18, tint, 0.5 + math.random() * 0.5)
    end
end
-- A comic word popping off the chest and drifting away.
local function Word(text, tint)
    local word = table.remove(wordPool)
    if not word then
        word = CreateFrame("Frame", nil, top)
        word:SetSize(200, 60)
        word.text = Text(word, 38, 1, 1, 1)
        word.text:SetPoint("CENTER")
    end
    word.text:SetText(text)
    word.text:SetTextColor(unpack(tint))
    word:Show()
    local side = math.random() < 0.5 and -1 or 1
    words[#words + 1] = { frame = word, x = side * (STAGE.chest / 2 + 30), y = (show.y or STAGE.shut) + 40, vx = side * 90,
        vy = 120, age = 0, life = 0.9 }
end
-- A shockwave ring spreading from the chest.
local nextRing = 1
local function Ring(tint, size)
    local ring = rings[nextRing]
    nextRing = nextRing % #rings + 1
    ring:SetVertexColor(unpack(tint))
    ring:Show()
    Tween(0.55, function(p)
        local s = 80 + p * (size or 420)
        ring:SetSize(s, s)
        ring:SetAlpha((1 - p) * 0.8)
        Put(ring, 0, show.y or STAGE.shut)
    end, function() ring:Hide() end)
end

panel:SetScript("OnUpdate", function(_, dt)
    dt = math.min(dt, 0.05)
    for i = #tweens, 1, -1 do
        local tw = tweens[i]
        if tw then
            tw.t = tw.t + dt
            local p = math.min(1, tw.t / tw.d)
            tw.update(p)
            if p >= 1 then
                table.remove(tweens, i)
                if tw.done then tw.done() end
            end
        end
    end
    for i = #particles, 1, -1 do
        local pt = particles[i]
        pt.age = pt.age + dt
        if pt.gravity then pt.vy = pt.vy + GRAVITY * dt end
        if pt.flutter then
            pt.vy = math.max(pt.vy, -170)
            pt.x = pt.x + math.sin(pt.age * 5 + pt.seed) * 70 * dt
        end
        pt.x, pt.y = pt.x + pt.vx * dt, pt.y + pt.vy * dt
        if pt.floor and pt.y < pt.floor then  -- lands, bounces a little, and stays
            pt.y, pt.vy, pt.vx, pt.spin = pt.floor, math.abs(pt.vy) > 120 and -pt.vy * 0.3 or 0, pt.vx * 0.5, pt.spin * 0.5
        end
        pt.angle = pt.angle + pt.spin * dt
        Put(pt.tex, pt.x, pt.y)
        pt.tex:SetRotation(pt.angle)
        pt.tex:SetAlpha(math.max(0, 1 - (pt.age / pt.life) ^ 3))
        if pt.age >= pt.life then
            pt.tex:Hide()
            pool[#pool + 1] = pt.tex
            table.remove(particles, i)
            if pt.onEnd then pt.onEnd(pt.x, pt.y) end
        end
    end
    for i = #words, 1, -1 do
        local w = words[i]
        w.age = w.age + dt
        w.x, w.y = w.x + w.vx * dt, w.y + w.vy * dt
        local s = 0.6 + math.min(1, w.age * 6) * 0.6
        w.frame:SetScale(s)
        w.frame:ClearAllPoints()
        w.frame:SetPoint("CENTER", panel, "TOP", w.x / s, w.y / s)
        w.frame:SetAlpha(math.max(0, 1 - (w.age / w.life) ^ 2))
        if w.age >= w.life then
            w.frame:Hide()
            wordPool[#wordPool + 1] = w.frame
            table.remove(words, i)
        end
    end
    -- The chest: an idle bob, its rock and tilt (quicker and wider each tap), its jumps (show.scale), the rays' spin.
    show.time = (show.time or 0) + dt
    show.angle = (show.angle or 0) + (show.spin or 0) * dt
    rays:SetRotation(show.angle)
    for _, card in ipairs(cards) do
        if card.rays:IsShown() then card.rays:SetRotation(-show.angle * 1.5) end
    end
    if show.rainbow then  -- the light goes round the rainbow
        local r, g, b = Hue(show.time * 0.35)
        rays:SetVertexColor(r, g, b)
        glow:SetVertexColor(Hue(show.time * 0.35 + 0.5))
        banner.text:SetTextColor(Hue(show.time * 0.8))
    end
    local y = show.y or STAGE.shut
    local bob = show.phase == "shut" and math.sin(show.time * 3) * 4 or 0
    local amp = show.shake or 0
    local wobble = show.time * 2 * math.pi * (4.5 + (show.tap or 0) * 0.6)
    local s = show.scale or 1
    chestHolder:SetScale(s)
    chestHolder:ClearAllPoints()
    chestHolder:SetPoint("CENTER", panel, "TOP", math.sin(wobble) * amp / s, (y + bob + math.abs(math.sin(wobble)) * amp * 0.35) / s)
    chest:SetRotation(math.sin(wobble + 0.6) * amp * 0.008)
    for _, region in ipairs({ glow, rays, burst }) do Put(region, 0, y) end
    Put(rainbow, 0, y + 60)
    countBadge:ClearAllPoints()
    countBadge:SetPoint("CENTER", panel, "TOP", (STAGE.chest / 2 + 70) / countBadge:GetScale(), y / countBadge:GetScale())
    Put(panel.hint, 0, y - STAGE.chest / 2 - 28)
    -- The whole window shaking (epic and up, at the burst).
    if (show.windowShake or 0) > 0 and panel.anchor then
        show.windowShake = math.max(0, show.windowShake - dt * 30)
        local dx, dy = (math.random() - 0.5) * show.windowShake, (math.random() - 0.5) * show.windowShake
        panel:ClearAllPoints()
        panel:SetPoint("TOPLEFT", panel.anchor, "TOPLEFT", dx, dy)
        panel:SetPoint("BOTTOMRIGHT", panel.anchor, "BOTTOMRIGHT", dx, dy)
    end
    -- The count ticking up.
    if show.counting then
        show.shown = math.min(show.coins, show.shown + dt * math.max(30, show.coins * 0.9))
        coins.text:SetText(("+%d points"):format(math.floor(show.shown)) .. ((show.tokens or 0) > 0
            and ("    |T%s:30|t +%d"):format(ns.IngredientIcon(show.dungeon), show.tokens) or "")
            .. (show.fuel and ("    |T%s:30|t +1"):format(ns.IngredientIcon(show.fuel)) or ""))
        show.clink = (show.clink or 0) - dt
        if show.clink <= 0 then Sound("LOOT_WINDOW_COIN_SOUND") show.clink = 0.3 end
        if show.shown >= show.coins then show.counting = false end
    end
end)

-- The phases ------------------------------------------------------------------------------------------------------

local Shut  -- (below)

-- The glow, the rays and the light under the lid in a colour (level: a tier; 0 warm), as bright and big as the charge.
local function Light(level, charge)
    local tint = Tint(level)
    glow:SetVertexColor(unpack(tint))
    rays:SetVertexColor(unpack(tint))
    leak:SetVertexColor(unpack(tint))
    local glowSize, raySize = STAGE.chest * 1.15 + charge * 16, STAGE.chest * 1.5 + charge * 26
    glow:SetAlpha(math.min(0.5, 0.15 + charge * 0.06))
    glow:SetSize(glowSize, glowSize)
    rays:SetAlpha(math.min(0.55, charge * 0.09))
    rays:SetSize(raySize, raySize)
    leak:SetAlpha(math.min(1, charge * 0.18))
    leak:SetSize(STAGE.chest * (0.6 + math.min(0.4, charge * 0.06)), 20 + charge * 6)
    show.spin = 0.25 + charge * 0.55
end

-- The chest jumps: squashes up and settles.
local function Jump(height)
    Tween(0.28, function(p) show.scale = 1 + math.sin(p * math.pi) * height end, function() show.scale = 1 end)
end

-- An item pulled out of the chest (an unlock: its picture; coins: a bag): its card flies to its place, bounces,
-- sparkles. A legendary comes face down and flips; a chase item gets its banner.
local function Pull(i)
    local item, card = show.items[i], cards[i]
    local count = math.min(#show.items, MAX_CARDS)
    local x = (i - (count + 1) / 2) * (CARD + CARD_GAP)
    local unlock = item.kind == "unlock"
    local rarity = unlock and item.option.rarity or nil
    local rank = unlock and RANK[rarity] or 1
    local tint = unlock and { ns.RarityRGB(rarity) } or { 0.85, 0.88, 0.92 }
    local flips = rank >= 4
    local chase = unlock and tostring(item.option.unlock):match("^chase:") ~= nil
    card.rim:SetColorTexture(unpack(flips and { 0.42, 0.23, 0.6 } or tint))
    card:SetScale(1)
    Put(card, x, CARDS_Y)
    card:Show()
    card.canvas:SetShown(unlock)
    card.coin:SetShown(not unlock)
    card.cover:SetShown(flips)
    card.cover:SetFrameLevel(card:GetFrameLevel() + 4)  -- (over the picture)
    card.back:SetWidth(CARD + 6)
    if unlock then
        ns.RenderMint(card.canvas, { [item.layer.key] = item.option.id })
        card.name:SetText(("|c%s%s|r"):format(ns.RARITY_COLORS[rarity] or "ffffffff", item.option.name))
        card.what:SetText(("%s %s"):format(Rarity(rarity), item.layer.name:lower()))
    else  -- the dungeon's tokens
        card.coin:SetTexture(ns.IngredientIcon(item.dungeon))
        card.name:SetText(("|cffd8dce0+%d %s|r"):format(item.count, ns.IngredientName(item.dungeon)))
        local dungeon = ns.DungeonByKey and ns.DungeonByKey(item.dungeon)
        card.what:SetText("for the minting pot, from " .. (dungeon and dungeon.name or "the dungeon"))
    end
    card.name:Hide()
    card.what:Hide()
    local function Reveal()
        card.rim:SetColorTexture(unpack(tint))
        card.name:Show()
        card.what:Show()
        Sparkles(6 + rank * 4, x, CARDS_Y, tint, 200 + rank * 40)
        Ring(tint, 260)
        if rank >= 3 then
            Put(card.rays, x, CARDS_Y)
            card.rays:SetVertexColor(unpack(tint))
            card.rays:SetAlpha(0.8)
            card.rays:Show()
        end
        if not unlock then
            Sound("LOOT_WINDOW_COIN_SOUND")
        else
            Sound(rank >= 4 and "UI_LEGENDARY_LOOT_TOAST" or rank >= 3 and "UI_EPICLOOT_TOAST" or "IG_QUEST_LOG_OPEN")
        end
        if chase then  -- the banner across the window, round the rainbow
            show.rainbow = true
            banner:Show()
            Tween(2.2, function(p)
                local s = p < 0.15 and Overshoot(p / 0.15) or 1
                banner:SetScale(math.max(0.05, s))
                banner:ClearAllPoints()
                banner:SetPoint("CENTER", panel, "TOP", 0, -250 / math.max(0.05, s))
                banner:SetAlpha(p > 0.8 and (1 - p) / 0.2 or 1)
            end, function() banner:Hide() end)
        end
    end
    Tween(0.5, function(p)
        local e, s = EaseOut(p), math.max(0.05, Overshoot(p))
        local cy = (show.y or STAGE.shut) + (CARDS_Y - (show.y or STAGE.shut)) * e + math.sin(p * math.pi) * 90
        card:SetScale(s)
        card:ClearAllPoints()
        card:SetPoint("CENTER", panel, "TOP", x * e / s, cy / s)
    end, function()
        if not flips then return Reveal() end
        -- Face down: a wobble, then it flips over (its back narrowing to nothing) and pops.
        After(0.35, function()
            Tween(0.18, function(p) card.back:SetWidth(math.max(1, (CARD + 6) * (1 - p))) end, function()
                card.cover:Hide()
                Tween(0.25, function(p) card:SetScale(1 + math.sin(p * math.pi) * 0.18) end)
                Reveal()
            end)
        end)
    end)
    Jump(0.12)
end

-- When everything's out: the next chest of this dungeon, or close.
local function Done()
    show.phase = "done"
    local left = show.preview and 0 or (ns.ChestCounts())[show.dungeon] or 0
    panel.hint:SetText("")
    panel.left:SetText(left > 0 and ("%d more waiting"):format(left) or "")
    PlaceButtons(left > 0)
    panel.open:SetShown(left > 0)
    panel.open:SetText(("Open the next one (%d left)"):format(left))
    panel.open:SetScript("OnClick", function() ns.UI.ClickSound() Shut(show.dungeon) end)
    panel.close:SetText("Close")
    panel.close:Show()
    local names = {}
    for _, item in ipairs(show.items) do
        if item.kind == "unlock" then
            names[#names + 1] = ("|c%s%s|r"):format(ns.RARITY_COLORS[item.option.rarity] or "ffffffff", item.option.name)
        end
    end
    if #names > 0 and not show.preview then ns.Print(("Unlocked for minting: %s."):format(table.concat(names, ", "))) end
end

-- Legendary: fireworks rising from the bottom and bursting into sparkles.
local function Fireworks(n)
    for k = 1, n do
        After(0.25 + k * 0.32, function()
            local x, tint = (math.random() - 0.5) * 640, CONFETTI[math.random(#CONFETTI)]
            Particle(FX .. "Star", x, FLOOR_Y, (math.random() - 0.5) * 80, 720 + math.random() * 160, 22, tint, 0.62,
                { gravity = true, onEnd = function(px, py) Sparkles(16, px, py, tint, 320) Sound("LOOT_WINDOW_COIN_SOUND") end })
        end)
    end
end
-- Legendary: the ogre pops up from the bottom left, cheers, and ducks away.
local function Cheer()
    ogre:Show()
    local from, to = FLOOR_Y - 140, FLOOR_Y + 70
    Tween(0.45, function(p)
        ogre:ClearAllPoints()
        ogre:SetPoint("CENTER", panel, "TOP", -300, from + (to - from) * Overshoot(p))
    end, function()
        After(1.6, function()
            Tween(0.35, function(p)
                ogre:ClearAllPoints()
                ogre:SetPoint("CENTER", panel, "TOP", -300, to + (from - to) * p * p)
            end, function() ogre:Hide() end)
        end)
    end)
end

-- The burst: flash, the lid flies open, coins spray, the count ticks up; more for the better chests.
local function Burst()
    show.phase = "reveal"
    show.shake = 0
    countBadge:Hide()
    local from = show.y or STAGE.shut
    Tween(0.4, function(p) show.y = from + (STAGE.open - from) * EaseOut(p) end)  -- up, out of the cards' way
    chest:SetTexture(ICONS .. "ChestOpen")
    Light(show.tier, show.taps + 1)
    leak:SetAlpha(0)  -- (the lid is open: no more light leaking from under it)
    show.spin = 0.6
    flash:SetVertexColor(1, 1, 1)
    Tween(0.45, function(p) flash:SetAlpha((1 - p) * 0.9) end)
    burst:SetVertexColor(unpack(Tint(show.tier)))
    burst:Show()
    Tween(0.5, function(p) burst:SetSize(120 + p * 420, 120 + p * 420) burst:SetAlpha(1 - p) burst:SetRotation(p * 0.8) end,
        function() burst:Hide() end)
    Jump(0.3)
    Ring(Tint(show.tier), 640)
    Sound("LOOT_WINDOW_COIN_SOUND")
    local big = show.tier >= 3
    for _ = 1, math.min(big and 60 or 40, 12 + show.coins) do
        local a = math.pi * (0.15 + math.random() * 0.7)
        local v = 380 + math.random() * 320
        Particle(FX .. "Coin", 0, from + 20, math.cos(a) * v, math.sin(a) * v, 26 + math.random() * 16, nil,
            big and 8 or (1.3 + math.random() * 0.6), { gravity = true, floor = big and (FLOOR_Y + math.random() * 20) or nil })
    end
    Sparkles(18, 0, from, Tint(show.tier), 380)
    if big then  -- epic and up: confetti and the whole window shaking
        show.windowShake = show.tier >= 4 and 22 or 14
        for _ = 1, show.tier >= 4 and 90 or 50 do
            Particle(FX .. "Confetti", (math.random() - 0.5) * 820, 30 + math.random() * 120, (math.random() - 0.5) * 80,
                -60 - math.random() * 80, 16 + math.random() * 12, CONFETTI[math.random(#CONFETTI)], 3.5 + math.random() * 2,
                { gravity = true, flutter = true })
        end
    end
    if show.tier >= 4 then  -- legendary: rainbow light, a rainbow, fireworks, an ogre cheering
        show.rainbow = true
        rainbow:Show()
        Tween(0.6, function(p) local s = 200 + EaseOut(p) * 460 rainbow:SetSize(s, s) rainbow:SetAlpha(p) end)
        Fireworks(7)
        Cheer()
        Sound("UI_LEGENDARY_LOOT_TOAST")
    end
    coins:Show()
    show.shown, show.counting = 0, true
    show.pulled = 0
    local n = math.min(#show.items, MAX_CARDS)
    panel.hint:SetText(n == 1 and "Tap to pull it out!" or ("Tap to pull them out! (%d)"):format(n))
end

-- Legendary: before the burst, a heartbeat of slow motion: everything stops, the chest throbs twice.
local function Heartbeat()
    show.phase = "slowmo"
    show.shake, show.spin = 0, 0.05
    panel.hint:SetText("...")
    for k = 0, 1 do
        After(k * 0.42, function()
            ns.UI.ClickSound()
            Tween(0.3, function(p) show.scale = 1 + math.sin(p * math.pi) * 0.14 end, function() show.scale = 1 end)
        end)
    end
    After(1.0, Burst)
end

-- The colours a chest climbs through, a tap each (the first tap: none): up to its tier; an epic or legendary chest may
-- hold one a tap and then jump two.
local function Levels(tier)
    local levels = {}
    for t = 1, tier + 1 do levels[t] = math.min(t - 1, tier) end
    if tier >= 3 and math.random() < 0.5 then
        levels[tier] = tier - 2  -- the hold
        show.fakeAt = tier + 1
    end
    return levels
end

-- A tap anywhere on the panel (not its buttons).
local function Tap()
    if show.phase == "shut" then
        if show.preview then  -- (dev mode: everything the dungeon's chest can hold, nothing unlocked, no coins kept)
            show.items = {}
            for _, unlocked in ipairs(ns.ChestPool(show.dungeon)) do
                show.items[#show.items + 1] = { kind = "unlock", layer = unlocked.layer, option = unlocked.option }
            end
            show.tier = show.previewTier or math.min(#ns.CHEST_TIERS, #show.items)
            show.items[#show.items + 1] = { kind = "tokens", dungeon = show.dungeon, count = ns.CHEST_TIERS[show.tier].tokens }
            show.coins = math.random(10, 60)
            show.tokens = ns.CHEST_TIERS[show.tier].tokens
            show.fuel = ns.CHEST_TIERS[show.tier].fuel
        else
            show.tier, show.coins, show.items, show.tokens, show.fuel = ns.OpenChest(show.dungeon)
        end
        if not show.tier then return panel:Hide() end
        show.taps, show.tap = 2 + show.tier, 0
        show.levels = Levels(show.tier)
        show.phase = "charging"
    end
    if show.phase == "charging" then
        show.tap = show.tap + 1
        ns.UI.ClickSound()
        if show.tap >= show.taps then
            if show.tier >= 4 then return Heartbeat() end
            return Burst()
        end
        local level = show.levels[show.tap] or show.tier
        Light(level, show.tap)
        show.shake = 2 + show.tap * 2.5
        Jump(0.18 + show.tap * 0.03)
        Sparkles(3 + show.tap * 3, 0, (show.y or STAGE.shut), Tint(level), 180 + show.tap * 40)
        Ring(Tint(level))
        local ogreMode = KillTrackerDB and KillTrackerDB.ogreMode
        local wordList = ogreMode and OGRE_WORDS or TAP_WORDS
        Word(wordList[math.random(#wordList)], Tint(math.max(level, 1)))
        if show.fakeAt == show.tap then
            panel.hint:SetText("WHOA!")
        elseif show.fakeAt and show.tap == show.fakeAt - 1 then
            panel.hint:SetText("Hmm...")
        else
            panel.hint:SetText(TAP_HINTS[math.min(show.tap, #TAP_HINTS)])
        end
        if level > 0 then  -- this many items inside
            countBadge.text:SetText(("x%d"):format(level))
            countBadge.text:SetTextColor(unpack(Tint(level)))
            countBadge:Show()
            Tween(0.25, function(p) countBadge:SetScale(1 + math.sin(p * math.pi) * 0.5) end)
        end
        if level >= 3 then Sound("IG_CHAT_EMOTE_BUTTON") end
    elseif show.phase == "reveal" and show.pulled < math.min(#show.items, MAX_CARDS) then
        show.pulled = show.pulled + 1
        Pull(show.pulled)
        if show.pulled >= math.min(#show.items, MAX_CARDS) then
            panel.hint:SetText("")
            After(1.2, function() if show.phase == "reveal" then Done() end end)
        else
            panel.hint:SetText(("Tap for the next! (%d more)"):format(math.min(#show.items, MAX_CARDS) - show.pulled))
        end
    end
end
panel:SetScript("OnMouseDown", function(_, button) if button == "LeftButton" then Tap() end end)

-- One of the dungeon's chests, shut, bobbing, waiting for taps.
function Shut(dungeonKey, preview, previewTier)
    wipe(tweens)
    for _, pt in ipairs(particles) do pt.tex:Hide() pool[#pool + 1] = pt.tex end
    wipe(particles)
    for _, w in ipairs(words) do w.frame:Hide() wordPool[#wordPool + 1] = w.frame end
    wipe(words)
    show = { phase = "shut", dungeon = dungeonKey, time = 0, angle = 0, scale = 1, shake = 0, preview = preview,
        previewTier = previewTier, y = STAGE.shut }
    if panel.anchor then
        panel:ClearAllPoints()
        panel:SetAllPoints(panel.anchor)
    end
    local dungeon = ns.DungeonByKey and ns.DungeonByKey(dungeonKey)
    panel.title:SetText((dungeon and dungeon.name or dungeonKey) .. " chest")
    local left = (ns.ChestCounts())[dungeonKey] or 0
    panel.left:SetText(preview and "|cffff8040DEV PREVIEW - nothing is unlocked|r" or left > 1 and ("%d of them waiting"):format(left) or "")
    chest:SetTexture(ICONS .. "Chest")
    Light(0, 0)
    flash:SetAlpha(0)
    burst:Hide()
    rainbow:Hide()
    ogre:Hide()
    banner:Hide()
    for _, ring in ipairs(rings) do ring:Hide() end
    coins:Hide()
    countBadge:Hide()
    for _, card in ipairs(cards) do card:Hide() card.rays:Hide() end
    panel.hint:SetText("Tap the chest!")
    panel.open:Hide()
    PlaceButtons(false)
    panel.close:SetText("Later")
    panel.close:Show()
end

-- preview (dev mode, Dev.lua): the show with everything the chest can hold, without opening one of yours; previewTier:
-- as a chest of that tier (default: as many items as it shows).
function ns.ShowChest(dungeonKey, preview, previewTier)
    if not preview and ((ns.ChestCounts())[dungeonKey] or 0) == 0 then return end
    -- Over the main window's pages, covering them (the sidebar stays usable).
    local pageArea = ns.UI and ns.UI.pageArea
    if pageArea then
        if not pageArea:IsVisible() then ns.ToggleUI() end
        panel:SetParent(pageArea)
        panel.anchor = pageArea
        panel:ClearAllPoints()
        panel:SetAllPoints(pageArea)
        panel:SetFrameStrata(pageArea:GetFrameStrata())
        panel:SetFrameLevel(pageArea:GetFrameLevel() + 50)
    else
        panel.anchor = nil
        panel:ClearAllPoints()
        panel:SetSize(827, 584)
        panel:SetPoint("CENTER")
        panel:SetFrameStrata("DIALOG")
    end
    -- Back to front over the panel: the chest, the cards, the count, the buttons, the effects.
    chestHolder:SetFrameLevel(panel:GetFrameLevel() + 2)
    for _, card in ipairs(cards) do card:SetFrameLevel(panel:GetFrameLevel() + 4) end
    countBadge:SetFrameLevel(panel:GetFrameLevel() + 7)
    panel.open:SetFrameLevel(panel:GetFrameLevel() + 6)  -- (their wood sits a level under them)
    panel.close:SetFrameLevel(panel:GetFrameLevel() + 6)
    top:SetFrameLevel(panel:GetFrameLevel() + 8)
    Shut(dungeonKey, preview, previewTier)
    panel:Show()
    -- The top beam's title: the page, then the chest (clicking the page's part closes it).
    local dungeon = ns.DungeonByKey and ns.DungeonByKey(dungeonKey)
    if ns.UI.SetScreen then
        ns.UI.SetScreen((dungeon and dungeon.name or "Dungeon") .. " Chest", "LOOT", function() panel:Hide() end)
    end
end
panel:HookScript("OnHide", function() if ns.UI.ClearScreen then ns.UI.ClearScreen() end end)
