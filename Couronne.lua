-- Couronne (the Games Room's board game; a dev test for now: /solc couronne, practice on your own, simple textures).
-- A square board seen from above, a pocket in each corner; 12 white pucks, 12 black and the red queen start packed in
-- the middle. You shoot the striker from your baseline: click the baseline to move it along, drag back from it to aim
-- (the further, the harder), let go to shoot. Practice: sink every white in as few shots as you can - a black sunk costs
-- a shot and goes back to the middle, so does the striker; the queen sunk must be covered by a white on the same or the
-- next shot (3 shots off), or it goes back. Your best is kept in KillTrackerDB.couronne = { best }.
--
-- Drawing: each disc is three textures (rim, body, shine) placed every frame while anything moves. Physics: discs with
-- a sliding friction, bouncing off each other (the striker heavier) and off the rails, dropped when they reach a pocket.

local _, ns = ...
local UI = ns.UI
if not UI then return end

local ROUND = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"  -- (a white disc)
local WHITE = "Interface\\Buttons\\WHITE8X8"
local FONT = "Interface\\AddOns\\SOLC\\Media\\Fonts\\GermaniaOne-Regular.ttf"

-- The board (pixels, y down from its top-left), the physics and the rules, in one table (Lua 5.1: at most 60 upvalues).
local K = {
    S = 500, RIM = 22,  -- (the playing area, square, and the wooden rim round it)
    PR = 23, POCKET_IN = 17,  -- (a pocket's radius, and how far its middle sits in from the corner)
    R = 12, SR = 17, QR = 12,  -- (puck, striker, queen radii)
    BASE_Y = 440, BASE_X1 = 120, BASE_X2 = 380,  -- (your baseline: where the striker may sit)
    DECEL = 280, DRAG = 0.4, STOP = 5, BOUNCE = 0.9, RAIL = 0.72, STEP = 1 / 240,
    PULL = 130, SPEED = 1500,  -- (a full pull back, and the speed it gives)
    STRIKER_MASS = 1.6, QUEEN_BONUS = 3,
}
local COL = { white = { 0.93, 0.9, 0.82 }, black = { 0.16, 0.14, 0.13 }, queen = { 0.8, 0.12, 0.1 }, striker = { 0.95, 0.82, 0.45 } }

local panel, board
local discs = {}  -- { kind = "white"|"black"|"queen"|"striker", x, y, vx, vy, r, m, sunk, fade, tex = { rim, body, shine } }
local striker
local G = { state = "aim", shots = 0, penalty = 0, bonus = 0, queenWaiting = false, sunkThisShot = {}, aiming = false,
    pullX = 0, pullY = 0, msg = "", acc = 0, cost = 0 }

local function Db()
    KillTrackerDB.couronne = KillTrackerDB.couronne or {}
    return KillTrackerDB.couronne
end
local function Say(text) G.msg = text if panel then panel.msg:SetText(text) end end
local function Score() return G.shots + G.penalty - G.bonus end
local function WhitesLeft()
    local n = 0
    for _, d in ipairs(discs) do if d.kind == "white" and not d.sunk then n = n + 1 end end
    return n
end

-- ---- discs ----
local function DiscTex(d)
    local t = {}
    t.rim = board:CreateTexture(nil, "ARTWORK", nil, 1)
    t.rim:SetTexture(ROUND)
    t.rim:SetVertexColor(0, 0, 0, 0.55)
    t.body = board:CreateTexture(nil, "ARTWORK", nil, 2)
    t.body:SetTexture(ROUND)
    local c = COL[d.kind]
    t.body:SetVertexColor(c[1], c[2], c[3])
    t.ring = board:CreateTexture(nil, "ARTWORK", nil, 3)  -- (a turned groove, as real pucks have)
    t.ring:SetTexture(ROUND)
    t.ring:SetVertexColor(0, 0, 0, d.kind == "black" and 0.35 or 0.12)
    t.inner = board:CreateTexture(nil, "ARTWORK", nil, 4)
    t.inner:SetTexture(ROUND)
    t.inner:SetVertexColor(c[1], c[2], c[3])
    t.shine = board:CreateTexture(nil, "ARTWORK", nil, 5)
    t.shine:SetTexture(ROUND)
    t.shine:SetVertexColor(1, 1, 1, d.kind == "black" and 0.18 or 0.35)
    d.tex = t
end
local function PlaceDisc(d)
    local t, r = d.tex, d.r * (d.fade or 1)
    local shown = not d.sunk or (d.fade and d.fade > 0)
    for _, tex in pairs(t) do tex:SetShown(shown) end
    if not shown then return end
    local x, y = d.x, -d.y
    t.rim:SetPoint("CENTER", board, "TOPLEFT", x + 1, y - 1.5) t.rim:SetSize(2 * r + 2, 2 * r + 2)
    t.body:SetPoint("CENTER", board, "TOPLEFT", x, y) t.body:SetSize(2 * r, 2 * r)
    t.ring:SetPoint("CENTER", board, "TOPLEFT", x, y) t.ring:SetSize(1.45 * r, 1.45 * r)
    t.inner:SetPoint("CENTER", board, "TOPLEFT", x, y) t.inner:SetSize(1.3 * r, 1.3 * r)
    t.shine:SetPoint("CENTER", board, "TOPLEFT", x - r * 0.32, y + r * 0.36) t.shine:SetSize(r * 0.7, r * 0.45)
    local a = d.fade or 1
    for _, tex in pairs(t) do tex:SetAlpha(a) end
end

local function Free(x, y, r, except)  -- no disc (in play) overlapping a disc of radius r there
    for _, d in ipairs(discs) do
        if d ~= except and not d.sunk and (d.x - x) ^ 2 + (d.y - y) ^ 2 < (d.r + r + 1) ^ 2 then return false end
    end
    return true
end
local function BackToMiddle(d)  -- a puck put back: the free spot nearest the middle
    local c = K.S / 2
    for ring = 0, 12 do
        for k = 0, math.max(0, ring * 6 - 1) do
            local a = ring == 0 and 0 or k / (ring * 6) * 2 * math.pi
            local x, y = c + math.cos(a) * ring * (2 * K.R + 1), c + math.sin(a) * ring * (2 * K.R + 1)
            if Free(x, y, d.r, d) then
                d.x, d.y, d.vx, d.vy, d.sunk, d.fade = x, y, 0, 0, nil, nil
                return
            end
        end
    end
end

local function NewGame()
    for _, d in ipairs(discs) do for _, tex in pairs(d.tex) do tex:Hide() end end
    wipe(discs)
    -- The queen in the middle, the 24 pucks round her in tight rings, white and black by turns.
    local c, step = K.S / 2, 2 * K.R + 0.5
    discs[1] = { kind = "queen", x = c, y = c, r = K.QR, m = 1 }
    local spots = {}
    for i = -3, 3 do
        for j = -3, 3 do
            local x, y = c + (i + j * 0.5) * step, c + j * step * 0.866
            local dd = (x - c) ^ 2 + (y - c) ^ 2
            if dd > 1 then spots[#spots + 1] = { x = x, y = y, d = dd, a = (math.atan2 or math.atan)(y - c, x - c) } end
        end
    end
    table.sort(spots, function(a, b) if math.abs(a.d - b.d) > 1 then return a.d < b.d end return a.a < b.a end)
    for k = 1, 24 do
        discs[#discs + 1] = { kind = k % 2 == 1 and "white" or "black", x = spots[k].x, y = spots[k].y, r = K.R, m = 1 }
    end
    striker = { kind = "striker", x = K.S / 2, y = K.BASE_Y, r = K.SR, m = K.STRIKER_MASS }
    discs[#discs + 1] = striker
    for _, d in ipairs(discs) do d.vx, d.vy = 0, 0 DiscTex(d) PlaceDisc(d) end
    G.state, G.shots, G.penalty, G.bonus, G.queenWaiting, G.aiming = "aim", 0, 0, 0, false, false
    wipe(G.sunkThisShot)
    Say("Sink all 12 whites. Click your baseline to move the striker, drag back from it to shoot.")
end

-- ---- physics ----
local POCKETS = {}
for _, p in ipairs({ { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }) do
    POCKETS[#POCKETS + 1] = { x = p[1] == 0 and K.POCKET_IN or K.S - K.POCKET_IN, y = p[2] == 0 and K.POCKET_IN or K.S - K.POCKET_IN }
end
local function Physics(dt)
    local moving = false
    for _, d in ipairs(discs) do
        if not d.sunk then
            local sp = math.sqrt(d.vx * d.vx + d.vy * d.vy)
            if sp > 0 then
                local slow = math.max(0, sp - (K.DECEL + K.DRAG * sp) * dt)
                if slow < K.STOP then slow = 0 end
                d.vx, d.vy = d.vx / sp * slow, d.vy / sp * slow
                d.x, d.y = d.x + d.vx * dt, d.y + d.vy * dt
                if slow > 0 then moving = true end
            end
        elseif d.fade and d.fade > 0 then
            d.fade = math.max(0, d.fade - dt * 4)
            moving = true
        end
    end
    -- each pair: pushed apart, and an elastic-ish bounce by mass
    for i = 1, #discs do
        local a = discs[i]
        if not a.sunk then
            for j = i + 1, #discs do
                local b = discs[j]
                if not b.sunk then
                    local dx, dy = b.x - a.x, b.y - a.y
                    local rr = a.r + b.r
                    local d2 = dx * dx + dy * dy
                    if d2 < rr * rr and d2 > 0 then
                        local d = math.sqrt(d2)
                        local nx, ny, o = dx / d, dy / d, rr - d
                        local ma, mb = a.m, b.m
                        a.x, a.y = a.x - nx * o * mb / (ma + mb), a.y - ny * o * mb / (ma + mb)
                        b.x, b.y = b.x + nx * o * ma / (ma + mb), b.y + ny * o * ma / (ma + mb)
                        local vn = (b.vx - a.vx) * nx + (b.vy - a.vy) * ny
                        if vn < 0 then
                            local jj = -(1 + K.BOUNCE) * vn / (1 / ma + 1 / mb)
                            a.vx, a.vy = a.vx - nx * jj / ma, a.vy - ny * jj / ma
                            b.vx, b.vy = b.vx + nx * jj / mb, b.vy + ny * jj / mb
                            moving = true
                        end
                    end
                end
            end
        end
    end
    -- pockets first (a disc reaching one drops), then the rails
    for _, d in ipairs(discs) do
        if not d.sunk then
            for _, p in ipairs(POCKETS) do
                if (d.x - p.x) ^ 2 + (d.y - p.y) ^ 2 < (K.PR - d.r * 0.25) ^ 2 then
                    d.sunk, d.fade, d.vx, d.vy = true, 1, 0, 0
                    d.x, d.y = d.x + (p.x - d.x) * 0.5, d.y + (p.y - d.y) * 0.5
                    G.sunkThisShot[#G.sunkThisShot + 1] = d
                    pcall(PlaySound, SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)
                    break
                end
            end
        end
        if not d.sunk then
            if d.x < d.r then d.x, d.vx = d.r, math.abs(d.vx) * K.RAIL end
            if d.x > K.S - d.r then d.x, d.vx = K.S - d.r, -math.abs(d.vx) * K.RAIL end
            if d.y < d.r then d.y, d.vy = d.r, math.abs(d.vy) * K.RAIL end
            if d.y > K.S - d.r then d.y, d.vy = K.S - d.r, -math.abs(d.vy) * K.RAIL end
        end
    end
    return moving
end

-- ---- a shot, and what it counts for ----
local function Resolve()
    local whites, blacks, queen, foul = 0, 0, false, false
    for _, d in ipairs(G.sunkThisShot) do
        if d.kind == "white" then whites = whites + 1
        elseif d.kind == "black" then blacks = blacks + 1
        elseif d.kind == "queen" then queen = true
        elseif d.kind == "striker" then foul = true end
    end
    local parts = {}
    if whites > 0 then parts[#parts + 1] = ("%d white%s in"):format(whites, whites > 1 and "s" or "") end
    if blacks > 0 then
        G.penalty = G.penalty + blacks
        parts[#parts + 1] = ("%d black%s: +%d"):format(blacks, blacks > 1 and "s" or "", blacks)
    end
    if foul then G.penalty = G.penalty + 1 parts[#parts + 1] = "striker in: +1" end
    for _, d in ipairs(G.sunkThisShot) do if d.kind == "black" then BackToMiddle(d) end end
    -- the queen: covered by a white on this shot or the next, else back to the middle
    local q
    for _, d in ipairs(discs) do if d.kind == "queen" then q = d end end
    if queen and whites > 0 then
        G.bonus, G.queenWaiting = G.bonus + K.QUEEN_BONUS, false
        parts[#parts + 1] = ("QUEEN covered: -%d!"):format(K.QUEEN_BONUS)
    elseif queen then
        G.queenWaiting = true
        parts[#parts + 1] = "QUEEN in - cover her with a white next shot"
    elseif G.queenWaiting then
        G.queenWaiting = false
        if whites > 0 then
            G.bonus = G.bonus + K.QUEEN_BONUS
            parts[#parts + 1] = ("QUEEN covered: -%d!"):format(K.QUEEN_BONUS)
        else
            BackToMiddle(q)
            parts[#parts + 1] = "queen not covered: back to the middle"
        end
    end
    wipe(G.sunkThisShot)
    -- the striker back on the baseline (where it was, if free)
    local sx = math.max(K.BASE_X1, math.min(K.BASE_X2, striker.sunk and K.S / 2 or striker.x))
    striker.sunk, striker.fade, striker.vx, striker.vy, striker.y = nil, nil, 0, 0, K.BASE_Y
    striker.x = sx
    if not Free(striker.x, striker.y, striker.r, striker) then
        for off = 0, K.BASE_X2 - K.BASE_X1, 6 do
            for _, x in ipairs({ sx + off, sx - off }) do
                if x >= K.BASE_X1 and x <= K.BASE_X2 and Free(x, K.BASE_Y, striker.r, striker) then striker.x = x break end
            end
            if Free(striker.x, striker.y, striker.r, striker) then break end
        end
    end
    if WhitesLeft() == 0 then
        local db, score = Db(), Score()
        local best = not db.best or score < db.best
        if best then db.best = score end
        G.state = "done"
        pcall(PlaySound, SOUNDKIT and SOUNDKIT.UI_EPICLOOT_TOAST or 120)
        Say(("All whites in! Score %d%s"):format(score, best and " - a new best!" or (" (best %d)"):format(db.best)))
    else
        G.state = "aim"
        Say(#parts > 0 and table.concat(parts, ", ") .. "." or "Nothing in.")
    end
end

local function Cursor()  -- the mouse on the board (pixels, y down)
    local x, y = GetCursorPosition()
    local s = board:GetEffectiveScale()
    return x / s - board:GetLeft(), board:GetTop() - y / s
end
local function Shoot()
    local dx, dy = striker.x - G.pullX, striker.y - G.pullY
    local len = math.sqrt(dx * dx + dy * dy)
    local power = math.min(1, len / K.PULL)
    if power < 0.04 then return end
    striker.vx, striker.vy = dx / len * power * K.SPEED, dy / len * power * K.SPEED
    G.state, G.shots = "moving", G.shots + 1
    pcall(PlaySound, SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_TAB or 841)
    Say("...")
end

-- ---- drawing ----
local function DrawAim()
    local show = G.aiming and G.state == "aim"
    board.aim:SetShown(show)
    board.pull:SetShown(show)
    for _, dot in ipairs(board.dots) do dot:SetShown(show) end
    if not show then return end
    G.pullX, G.pullY = Cursor()
    local dx, dy = striker.x - G.pullX, striker.y - G.pullY
    local len = math.max(0.001, math.sqrt(dx * dx + dy * dy))
    local power = math.min(1, len / K.PULL)
    local ux, uy = dx / len, dy / len
    local px, py = striker.x - ux * power * K.PULL, striker.y - uy * power * K.PULL
    board.pull:SetStartPoint("TOPLEFT", board, striker.x, -striker.y)
    board.pull:SetEndPoint("TOPLEFT", board, px, -py)
    board.pull:SetColorTexture(1, 0.9 - 0.6 * power, 0.3 - 0.2 * power, 0.9)
    -- where it goes: dots along the line, as far as the power would roughly carry it (short of the rails)
    local reach = 40 + power * 300
    for k, dot in ipairs(board.dots) do
        local t = k / #board.dots * reach
        local x, y = striker.x + ux * t, striker.y + uy * t
        dot:SetShown(x > 0 and x < K.S and y > 0 and y < K.S)
        dot:SetPoint("CENTER", board, "TOPLEFT", x, -y)
    end
    board.aim:SetText(("%d%%"):format(math.floor(power * 100 + 0.5)))
    board.aim:SetPoint("BOTTOM", board, "TOPLEFT", striker.x, -striker.y + striker.r + 16)
end

local function Refresh()
    panel.shots:SetText(("Shots %d   Penalties %d   Queen -%d"):format(G.shots, G.penalty, G.bonus))
    panel.score:SetText(("Score %d"):format(Score()))
    local best = KillTrackerDB and KillTrackerDB.couronne and KillTrackerDB.couronne.best
    panel.best:SetText(best and ("Best %d"):format(best) or "No best yet")
    panel.left:SetText(("%d whites left%s"):format(WhitesLeft(), G.queenWaiting and "  -  cover the queen!" or ""))
    panel.stat:SetText(("Lua %.1f ms"):format(G.cost))
end

local function OnUpdate(_, elapsed)
    local t0 = debugprofilestop()
    elapsed = math.min(elapsed, 0.05)
    if G.state == "moving" then
        G.acc = G.acc + elapsed
        local moving = true
        while G.acc >= K.STEP do
            G.acc = G.acc - K.STEP
            moving = Physics(K.STEP)
        end
        for _, d in ipairs(discs) do PlaceDisc(d) end
        if not moving then G.acc = 0 Resolve() for _, d in ipairs(discs) do PlaceDisc(d) end end
    end
    DrawAim()
    G.cost = G.cost * 0.9 + (debugprofilestop() - t0) * 0.1
    Refresh()
end

-- ---- the window ----
local function Text(parent, size, color)
    local t = parent:CreateFontString(nil, "OVERLAY")
    t:SetFont(FONT, size, "")
    t:SetTextColor(unpack(color or { 0.96, 0.9, 0.78 }))
    t:SetShadowColor(0, 0, 0, 0.8)
    t:SetShadowOffset(1, -1)
    return t
end
local function Btn(parent, w, h, text, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, h)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end
local function Ring(x, y, r, width, color)  -- a circle drawn on the board: a dark disc with a wood one inside
    local outer = board:CreateTexture(nil, "BORDER", nil, 1)
    outer:SetTexture(ROUND)
    outer:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
    outer:SetSize(2 * r, 2 * r)
    outer:SetPoint("CENTER", board, "TOPLEFT", x, -y)
    local inner = board:CreateTexture(nil, "BORDER", nil, 2)
    inner:SetTexture(ROUND)
    inner:SetVertexColor(0.86, 0.7, 0.47)
    inner:SetSize(2 * (r - width), 2 * (r - width))
    inner:SetPoint("CENTER", board, "TOPLEFT", x, -y)
end

local function Build()
    panel = CreateFrame("Frame", "SOLCCouronne", UIParent, "BackdropTemplate")
    panel:SetBackdrop({ bgFile = WHITE })
    panel:SetBackdropColor(0.1, 0.18, 0.12, 1)  -- (club green baize round the board)
    panel:EnableMouse(true)
    panel:Hide()
    panel:HookScript("OnHide", function()
        G.aiming = false
        if ns.UI.ClearScreen then ns.UI.ClearScreen("Couronne") end
    end)

    -- the rim, then the board: light wood, its lines and circles, the pockets
    local rim = panel:CreateTexture(nil, "BACKGROUND", nil, 1)
    rim:SetColorTexture(0.33, 0.18, 0.09, 1)
    rim:SetSize(K.S + 2 * K.RIM, K.S + 2 * K.RIM)
    rim:SetPoint("TOPLEFT", 20, -20)
    local rimEdge = panel:CreateTexture(nil, "BACKGROUND", nil, 2)
    rimEdge:SetColorTexture(0.22, 0.11, 0.05, 1)
    rimEdge:SetPoint("TOPLEFT", rim, "TOPLEFT", K.RIM - 4, -(K.RIM - 4))
    rimEdge:SetPoint("BOTTOMRIGHT", rim, "BOTTOMRIGHT", -(K.RIM - 4), K.RIM - 4)
    board = CreateFrame("Frame", nil, panel)
    board:SetSize(K.S, K.S)
    board:SetPoint("TOPLEFT", rim, "TOPLEFT", K.RIM, -K.RIM)
    local wood = board:CreateTexture(nil, "BACKGROUND")
    wood:SetAllPoints()
    wood:SetColorTexture(0.86, 0.7, 0.47, 1)
    local function Ln(x1, y1, x2, y2, w, a)
        local l = board:CreateLine(nil, "BORDER", nil, 0)
        l:SetThickness(w or 2)
        l:SetColorTexture(0.25, 0.12, 0.06, a or 0.8)
        l:SetStartPoint("TOPLEFT", board, x1, -y1)
        l:SetEndPoint("TOPLEFT", board, x2, -y2)
    end
    -- (the four baselines, double lines ending in circles, as on a real board; yours is the bottom one)
    for side = 1, 4 do
        for _, off in ipairs({ -K.SR, K.SR }) do
            local a, b, c = K.BASE_X1, K.BASE_X2, K.BASE_Y + off
            if side == 1 then Ln(a, c, b, c)
            elseif side == 2 then Ln(a, K.S - c, b, K.S - c)
            elseif side == 3 then Ln(c, a, c, b)
            else Ln(K.S - c, a, K.S - c, b) end
        end
        local y = K.BASE_Y
        for _, x in ipairs({ K.BASE_X1, K.BASE_X2 }) do
            local px, py = x, y
            if side == 2 then py = K.S - y elseif side == 3 then px, py = y, x elseif side == 4 then px, py = K.S - y, x end
            Ring(px, py, K.SR + 2, 2, { 0.25, 0.12, 0.06, 0.8 })
        end
    end
    Ring(K.S / 2, K.S / 2, 80, 2, { 0.25, 0.12, 0.06, 0.8 })
    Ring(K.S / 2, K.S / 2, 20, 2, { 0.6, 0.12, 0.08, 0.9 })
    for _, p in ipairs(POCKETS) do  -- (pockets: a dark hole with a net's shadow)
        local hole = board:CreateTexture(nil, "BORDER", nil, 4)
        hole:SetTexture(ROUND)
        hole:SetVertexColor(0.05, 0.03, 0.02, 1)
        hole:SetSize(2 * K.PR, 2 * K.PR)
        hole:SetPoint("CENTER", board, "TOPLEFT", p.x, -p.y)
        local lip = board:CreateTexture(nil, "BORDER", nil, 3)
        lip:SetTexture(ROUND)
        lip:SetVertexColor(0.3, 0.16, 0.07, 1)
        lip:SetSize(2 * K.PR + 6, 2 * K.PR + 6)
        lip:SetPoint("CENTER", board, "TOPLEFT", p.x, -p.y)
    end
    -- aiming: the pull (a line back to the mouse), dots where it goes, its power
    board.pull = board:CreateLine(nil, "OVERLAY")
    board.pull:SetThickness(3)
    board.dots = {}
    for k = 1, 14 do
        local dot = board:CreateTexture(nil, "OVERLAY")
        dot:SetTexture(ROUND)
        dot:SetVertexColor(1, 1, 1, 0.75 - k * 0.04)
        dot:SetSize(5, 5)
        board.dots[k] = dot
    end
    board.aim = Text(board, 13)
    board:EnableMouse(true)
    board:SetScript("OnMouseDown", function(_, button)
        if G.state ~= "aim" then return end
        if button == "RightButton" then G.aiming = false return end
        local x, y = Cursor()
        if (x - striker.x) ^ 2 + (y - striker.y) ^ 2 < (striker.r + 14) ^ 2 then
            G.aiming = true
        elseif math.abs(y - K.BASE_Y) < 26 then  -- (the baseline: the striker moves there, if it fits)
            local nx = math.max(K.BASE_X1, math.min(K.BASE_X2, x))
            if Free(nx, K.BASE_Y, striker.r, striker) then striker.x = nx PlaceDisc(striker) end
        end
    end)
    board:SetScript("OnMouseUp", function(_, button)
        if button ~= "LeftButton" or not G.aiming then return end
        G.aiming = false
        G.pullX, G.pullY = Cursor()
        if G.state == "aim" then Shoot() end
    end)

    -- the right side
    local x0 = 20 + K.S + 2 * K.RIM + 22
    local title = Text(panel, 26, { 0.95, 0.76, 0.3 })
    title:SetPoint("TOPLEFT", x0, -22)
    title:SetText("Couronne")
    local sub = Text(panel, 13, { 0.73, 0.65, 0.51 })
    sub:SetPoint("TOPLEFT", x0, -54)
    sub:SetText("Practice: sink every white.")
    panel.score = Text(panel, 22)
    panel.score:SetPoint("TOPLEFT", x0, -84)
    panel.best = Text(panel, 14, { 0.95, 0.76, 0.3 })
    panel.best:SetPoint("TOPLEFT", x0, -112)
    panel.shots = Text(panel, 13)
    panel.shots:SetPoint("TOPLEFT", x0, -138)
    panel.left = Text(panel, 13)
    panel.left:SetPoint("TOPLEFT", x0, -158)
    panel.msg = Text(panel, 15)
    panel.msg:SetPoint("TOPLEFT", x0, -190)
    panel.msg:SetWidth(200)
    panel.msg:SetJustifyH("LEFT")
    local rules = Text(panel, 12, { 0.73, 0.65, 0.51 })
    rules:SetPoint("TOPLEFT", x0, -300)
    rules:SetWidth(200)
    rules:SetJustifyH("LEFT")
    rules:SetText(("Click your baseline (bottom) to move the striker. Drag back from it and let go to shoot; right-click cancels.\n\nA black or the striker in: +1 shot (the black goes back). The queen in: cover her with a white on the same or next shot for -%d, or she goes back."):format(K.QUEEN_BONUS))
    local new = Btn(panel, 140, 28, "New game", function() NewGame() end)
    new:SetPoint("BOTTOMLEFT", x0, 40)
    panel.stat = Text(panel, 11, { 0.6, 0.55, 0.45 })
    panel.stat:SetPoint("BOTTOMLEFT", x0, 16)
    panel:SetScript("OnUpdate", OnUpdate)
    NewGame()
end

-- Opens it in the window's page area, like Plinko (dev characters only for now: Core.lua).
function ns.ShowCouronne()
    if not panel then Build() end
    local pageArea = ns.UI and ns.UI.pageArea
    panel:ClearAllPoints()
    if pageArea then
        if not pageArea:IsVisible() then ns.ToggleUI() end
        panel:SetParent(pageArea)
        panel:SetAllPoints(pageArea)
        panel:SetFrameStrata(pageArea:GetFrameStrata())
        panel:SetFrameLevel(pageArea:GetFrameLevel() + 50)
    else
        panel:SetParent(UIParent)
        panel:SetSize(827, 584)
        panel:SetPoint("CENTER")
        panel:SetFrameStrata("DIALOG")
    end
    panel:Show()
    if ns.UI.SetScreen then ns.UI.SetScreen("Couronne", "PUCK", function() panel:Hide() end) end
end
