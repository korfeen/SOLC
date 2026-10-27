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
    PULL = 220, SPEED = 1500, CURVE = 1.6,  -- (a full pull back, the speed it gives; power = pull ^ CURVE: soft shots get
                                            -- most of the pull, so they can be fine-tuned)
    STRIKER_MASS = 1.6, QUEEN_BONUS = 3,
}
local WOOD = { 0.86, 0.7, 0.47 }  -- (the board, also seen through the pucks' holes)
local COL = { white = { 0.93, 0.9, 0.82 }, black = { 0.16, 0.14, 0.13 }, queen = { 0.8, 0.12, 0.1 }, striker = { 0.95, 0.82, 0.45 } }

-- ---- the angled view (like Couronne Deluxe's): the board seen from in front and above, fitted once into A.VW x A.VH ----
-- A point on the board (x, y as the physics has them, y towards you) at height h -> view x, y (down), scale, depth.
local A = { ELEV = 0.8, DIST = 1500, VW = 580, VH = 560, RIMH = 11, T = 7, ST = 8, f = 1, cx = 0, cy = 0 }
A.cos, A.sin = math.cos(A.ELEV), math.sin(A.ELEV)
local function PA(x, y, h)
    local wx, wz = x - K.S / 2, K.S / 2 - y
    local d = -h * A.sin + wz * A.cos + A.DIST
    local s = A.f / d
    return A.cx + wx * s, A.cy - (h * A.cos + wz * A.sin) * s, s, d
end
local function Unproject(sx, sy)  -- a point in the view -> where on the board (height 0) it is
    local k = (A.cy - sy) / A.f
    local wz = k * A.DIST / (A.sin - k * A.cos)
    local s = A.f / (wz * A.cos + A.DIST)
    return (sx - A.cx) / s + K.S / 2, K.S / 2 - wz
end
do
    A.f, A.cx, A.cy = 1, 0, 0
    local minX, maxX, minY, maxY = 1e9, -1e9, 1e9, -1e9
    for _, x in ipairs({ -K.RIM, K.S + K.RIM }) do for _, y in ipairs({ -K.RIM, K.S + K.RIM }) do for _, h in ipairs({ -14, A.RIMH }) do
        local sx, sy = PA(x, y, h)
        minX, maxX, minY, maxY = math.min(minX, sx), math.max(maxX, sx), math.min(minY, sy), math.max(maxY, sy)
    end end end
    A.f = math.min((A.VW - 8) / (maxX - minX), (A.VH - 8) / (maxY - minY))
    A.cx = A.VW / 2 - (minX + maxX) / 2 * A.f
    A.cy = A.VH / 2 - (minY + maxY) / 2 * A.f
end

local panel, board, persp
local discs = {}  -- { kind = "white"|"black"|"queen"|"striker", x, y, vx, vy, r, m, sunk, fade, vis = (its looks, both views) }
local striker
local G = { state = "aim", shots = 0, penalty = 0, bonus = 0, queenWaiting = false, sunkThisShot = {}, aiming = false,
    pullX = 0, pullY = 0, msg = "", acc = 0, cost = 0, view = "angled", streak = 0, comboT = 0, comboShow = "" }

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
-- Each disc's looks, made once and handed out again each game (VIS[k] to the k-th disc): top = textures on the flat
-- board; angled = a frame of its own (so the rings can be sorted far to near) with stacked ellipses for a thick ring.
local VIS = {}
local function Round(parent, layer, sub)
    local t = parent:CreateTexture(nil, layer, nil, sub)
    t:SetTexture(ROUND)
    return t
end
local function DiscVis(d, k)
    local v = VIS[k]
    if not v then
        v = { top = {}, angled = {} }
        local t = v.top
        t.rim, t.body, t.shine = Round(board, "ARTWORK", 1), Round(board, "ARTWORK", 2), Round(board, "ARTWORK", 3)
        t.lip, t.hole = Round(board, "ARTWORK", 4), Round(board, "ARTWORK", 5)  -- (the hole shows the board)
        t.rim:SetVertexColor(0, 0, 0, 0.55)
        t.hole:SetVertexColor(WOOD[1], WOOD[2], WOOD[3])
        local f = CreateFrame("Frame", nil, persp)
        f:SetAllPoints()
        local a = v.angled
        a.shadow, a.side1, a.side2 = Round(f, "ARTWORK", 0), Round(f, "ARTWORK", 1), Round(f, "ARTWORK", 2)
        a.top, a.shine, a.wall, a.floor = Round(f, "ARTWORK", 3), Round(f, "ARTWORK", 4), Round(f, "ARTWORK", 5), Round(f, "ARTWORK", 6)
        a.shadow:SetVertexColor(0, 0, 0, 0.35)
        a.floor:SetVertexColor(WOOD[1] * 0.8, WOOD[2] * 0.8, WOOD[3] * 0.8)
        v.frame = f
        VIS[k] = v
    end
    local c = COL[d.kind]
    v.top.body:SetVertexColor(c[1], c[2], c[3])
    v.top.shine:SetVertexColor(1, 1, 1, d.kind == "black" and 0.2 or 0.4)
    v.top.lip:SetVertexColor(c[1] * 0.45, c[2] * 0.45, c[3] * 0.45)
    local a = v.angled
    a.side1:SetVertexColor(c[1] * 0.5, c[2] * 0.5, c[3] * 0.5)
    a.side2:SetVertexColor(c[1] * 0.62, c[2] * 0.62, c[3] * 0.62)
    a.top:SetVertexColor(c[1], c[2], c[3])
    a.shine:SetVertexColor(1, 1, 1, d.kind == "black" and 0.18 or 0.4)
    a.wall:SetVertexColor(c[1] * 0.35, c[2] * 0.35, c[3] * 0.35)
    d.vis = v
end
-- A flat circle lying on the board at height h, as the angled camera sees it (an ellipse).
local function Ellipse(tex, x, y, h, r)
    local cx, _, s = PA(x, y, h)
    local _, y1 = PA(x, y - r, h)
    local _, y2 = PA(x, y + r, h)
    tex:ClearAllPoints()
    tex:SetPoint("CENTER", persp, "TOPLEFT", cx, -(y1 + y2) / 2)
    tex:SetSize(2 * r * s, math.max(1, math.abs(y2 - y1)))
end
local function PlaceDisc(d)
    local v, r = d.vis, d.r * (d.fade or 1)
    local shown = not d.sunk or (d.fade and d.fade > 0)
    local a = d.fade or 1
    local top = G.view == "top"
    for _, tex in pairs(v.top) do tex:SetShown(shown and top) end
    v.frame:SetShown(shown and not top)
    if not shown then return end
    if top then
        local t, x, y = v.top, d.x, -d.y
        t.rim:SetPoint("CENTER", board, "TOPLEFT", x + 1, y - 1.5) t.rim:SetSize(2 * r + 2, 2 * r + 2)
        t.body:SetPoint("CENTER", board, "TOPLEFT", x, y) t.body:SetSize(2 * r, 2 * r)
        t.shine:SetPoint("CENTER", board, "TOPLEFT", x - r * 0.5, y + r * 0.5) t.shine:SetSize(r * 0.45, r * 0.3)
        t.lip:SetPoint("CENTER", board, "TOPLEFT", x, y) t.lip:SetSize(0.92 * r, 0.92 * r)
        t.hole:SetPoint("CENTER", board, "TOPLEFT", x + r * 0.06, y - r * 0.06) t.hole:SetSize(0.82 * r, 0.82 * r)
        for _, tex in pairs(t) do tex:SetAlpha(a) end
    else
        -- (a thick ring: its side as two ellipses, the top face, a shine, the hole's far wall and the board in it)
        local g, T, x, y = v.angled, d.kind == "striker" and A.ST or A.T, d.x, d.y
        Ellipse(g.shadow, x + 2, y + 2, 0, r * 1.02)
        Ellipse(g.side1, x, y, 0, r)
        Ellipse(g.side2, x, y, T * 0.5, r)
        Ellipse(g.top, x, y, T, r)
        Ellipse(g.shine, x - r * 0.45, y - r * 0.45, T, r * 0.28)
        Ellipse(g.wall, x, y, T, r * 0.42)
        Ellipse(g.floor, x, y + r * 0.08, T * 0.35, r * 0.34)
        for _, tex in pairs(g) do tex:SetAlpha(a) end
        local _, _, _, depth = PA(x, y, 0)
        v.frame.d = depth
    end
end
local order = {}
local function PlaceAll()  -- every disc, and (angled) their frames re-sorted far to near
    wipe(order)
    for _, d in ipairs(discs) do
        PlaceDisc(d)
        if G.view ~= "top" and d.vis.frame:IsShown() then order[#order + 1] = d.vis.frame end
    end
    if G.view == "top" then return end
    table.sort(order, function(p, q) return p.d > q.d end)
    local base = persp:GetFrameLevel() + 2
    for i, f in ipairs(order) do if f.lvl ~= base + i then f.lvl = base + i f:SetFrameLevel(base + i) end end
    persp.near:SetFrameLevel(base + #order + 2)
    persp.over:SetFrameLevel(base + #order + 4)
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
    for _, v in ipairs(VIS) do for _, tex in pairs(v.top) do tex:Hide() end v.frame:Hide() end
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
    for k, d in ipairs(discs) do d.vx, d.vy = 0, 0 DiscVis(d, k) end
    PlaceAll()
    G.state, G.shots, G.penalty, G.bonus, G.queenWaiting, G.aiming, G.streak = "aim", 0, 0, 0, false, false, 0
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
                d.since = (d.since or 0) + slow * dt  -- (how far it has slid since it joined the combo chain)
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
                            -- (the combo chain: a disc hit by one already in this shot's chain is one link further along -
                            -- but only if the hitter slid at least a puck's width on its own first: pucks shoved through
                            -- a tight cluster, as on the break, don't count)
                            -- (for the bank and clean shots: what the striker touched; pucks touching each other are no
                            -- longer clean)
                            if a == striker then striker.touched = true striker.hit[b] = true
                            elseif b == striker then striker.touched = true striker.hit[a] = true
                            else a.dirty, b.dirty = true, true end
                            local ca, cb = a.chain, b.chain
                            local free = 2 * K.R
                            if ca and b.kind ~= "striker" and (a.since or 0) >= free and (cb or 0) < ca + 1 then b.chain, b.since = ca + 1, 0 end
                            if cb and a.kind ~= "striker" and (b.since or 0) >= free and (ca or 0) < cb + 1 then a.chain, a.since = cb + 1, 0 end
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
            -- (the striker off a rail before it touched any puck: a bank shot, if a white goes in)
            local rail = d.x < d.r or d.x > K.S - d.r or d.y < d.r or d.y > K.S - d.r
            if d == striker and not striker.touched and rail then striker.banked = true end
            if d ~= striker and rail then d.dirty = true end  -- (a puck off a rail: not a clean shot)
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
    -- In a row: shots sinking a white with no foul; a combo: the longest chain of hits that led to a white going in
    local db, combo = Db(), 0
    for _, d in ipairs(G.sunkThisShot) do if d.kind == "white" then combo = math.max(combo, d.chain or 0) end end
    if whites > 0 and blacks == 0 and not foul then G.streak = G.streak + 1 else G.streak = 0 end
    if G.streak > (db.bestStreak or 0) then db.bestStreak = G.streak end
    local bank = whites > 0 and striker.banked
    -- A clean shot: the striker touched only one puck, a white, straight off the baseline, and it went in without
    -- touching a rail or another puck.
    local only, n = nil, 0
    for d in pairs(striker.hit or {}) do only, n = d, n + 1 end
    local clean = n == 1 and not striker.banked and not foul and only.kind == "white" and only.sunk and not only.dirty
    if clean then
        parts[#parts + 1] = "CLEAN SHOT!"
        db.cleans = (db.cleans or 0) + 1
    end
    if bank then
        parts[#parts + 1] = "BANK SHOT!"
        db.banks = (db.banks or 0) + 1
    end
    if combo >= 2 then
        parts[#parts + 1] = ("COMBO x%d!"):format(combo)
        if combo > (db.bestCombo or 0) then db.bestCombo = combo end
    end
    if combo >= 2 or bank or clean then  -- (the big words over the board)
        local words = {}
        if clean then words[#words + 1] = "CLEAN SHOT!" end
        if bank then words[#words + 1] = "BANK SHOT!" end
        if combo >= 2 then words[#words + 1] = ("COMBO x%d!"):format(combo) end
        G.comboShow = table.concat(words, "   ")
        G.comboT = 1.8
        pcall(PlaySound, SOUNDKIT and SOUNDKIT.UI_EPICLOOT_TOAST or 120)
    end
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
        local score = Score()
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

local function Cursor()  -- the mouse on the board (pixels, y down; angled: where it points on the tilted board)
    local x, y = GetCursorPosition()
    local f = G.view == "top" and board or persp
    local s = f:GetEffectiveScale()
    local fx, fy = x / s - f:GetLeft(), f:GetTop() - y / s
    if G.view == "top" then return fx, fy end
    return Unproject(fx, fy)
end
local function Shoot()
    local dx, dy = striker.x - G.pullX, striker.y - G.pullY
    local len = math.sqrt(dx * dx + dy * dy)
    local pull = math.min(1, len / K.PULL)
    local power = pull ^ K.CURVE
    if pull < 0.03 then return end  -- (a click, not a pull)
    striker.vx, striker.vy = dx / len * power * K.SPEED, dy / len * power * K.SPEED
    for _, d in ipairs(discs) do d.chain, d.since, d.dirty = nil, 0, nil end
    striker.chain, striker.since, striker.touched, striker.banked, striker.hit = 0, 1e9, false, false, {}  -- (the start of the combo chain: what it hits is link 1)
    G.state, G.shots = "moving", G.shots + 1
    pcall(PlaySound, SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_TAB or 841)
    Say("...")
end

-- ---- drawing ----
-- The aim (in whichever view): the cue drawn back behind the striker as far as you pull, dots where it goes, the power.
local function DrawAim()
    local show = G.aiming and G.state == "aim"
    local top = G.view == "top"
    for _, w in ipairs({ board.aimW, persp.aimW }) do
        local on = show and (w == board.aimW) == top
        w.aim:SetShown(on) w.cue:SetShown(on) w.cueTip:SetShown(on)
        for _, dot in ipairs(w.dots) do dot:SetShown(on) end
    end
    if not show then return end
    local w, f = top and board.aimW or persp.aimW, top and board or persp
    local function At(x, y, h)  -- board point -> this view's point (x, y up from TOPLEFT)
        if top then return x, -y end
        local sx, sy = PA(x, y, h or 0)
        return sx, -sy
    end
    G.pullX, G.pullY = Cursor()
    local dx, dy = striker.x - G.pullX, striker.y - G.pullY
    local len = math.max(0.001, math.sqrt(dx * dx + dy * dy))
    local pull = math.min(1, len / K.PULL)
    local power = pull ^ K.CURVE
    local ux, uy = dx / len, dy / len
    -- the cue: its tip behind the striker (further the harder you pull), its butt off towards you, rising
    local back = striker.r + 4 + pull * 110
    local tx, ty = striker.x - ux * back, striker.y - uy * back
    local bx, by = tx - ux * 340, ty - uy * 340
    local ax1, ay1 = At(tx, ty, A.ST * 0.6)
    local ax2, ay2 = At(bx, by, 70)
    w.cue:SetStartPoint("TOPLEFT", f, ax1, ay1)
    w.cue:SetEndPoint("TOPLEFT", f, ax2, ay2)
    local cx2, cy2 = At(tx - ux * 14, ty - uy * 14, A.ST * 0.6 + 2.5)
    w.cueTip:SetStartPoint("TOPLEFT", f, ax1, ay1)
    w.cueTip:SetEndPoint("TOPLEFT", f, cx2, cy2)
    -- where it goes: dots along the line, as far as the power would roughly carry it (short of the rails)
    local reach = 40 + power * 300
    for k, dot in ipairs(w.dots) do
        local t = k / #w.dots * reach
        local x, y = striker.x + ux * t, striker.y + uy * t
        dot:SetShown(x > 0 and x < K.S and y > 0 and y < K.S)
        dot:SetPoint("CENTER", f, "TOPLEFT", At(x, y, 0))
    end
    w.aim:SetText(("%d%%"):format(math.floor(power * 100 + 0.5)))
    local sx, sy = At(striker.x, striker.y - striker.r - 10, A.ST)
    w.aim:SetPoint("BOTTOM", f, "TOPLEFT", sx, sy)
    w.aim:SetTextColor(1, 0.9 - 0.6 * power, 0.3 - 0.2 * power)
end

local function Refresh()
    panel.shots:SetText(("Shots %d   Penalties %d   Queen -%d"):format(G.shots, G.penalty, G.bonus))
    panel.score:SetText(("Score %d"):format(Score()))
    local best = KillTrackerDB and KillTrackerDB.couronne and KillTrackerDB.couronne.best
    panel.best:SetText(best and ("Best %d"):format(best) or "No best yet")
    panel.left:SetText(("%d whites left%s"):format(WhitesLeft(), G.queenWaiting and "  -  cover the queen!" or ""))
    local db = KillTrackerDB and KillTrackerDB.couronne or {}
    panel.streak:SetText(("In a row %d (best %d)\nBest combo x%d   Bank %d   Clean %d"):format(G.streak, db.bestStreak or 0, db.bestCombo or 0, db.banks or 0, db.cleans or 0))
    -- the combo, big over the board, fading
    if G.comboT and G.comboT > 0 then
        panel.combo:SetText(G.comboShow)
        panel.combo:SetAlpha(math.min(1, G.comboT / 0.5))
        panel.combo:Show()
    else
        panel.combo:Hide()
    end
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
        PlaceAll()
        if not moving then G.acc = 0 Resolve() PlaceAll() end
    end
    DrawAim()
    if G.comboT and G.comboT > 0 then G.comboT = G.comboT - elapsed end
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
    inner:SetVertexColor(WOOD[1], WOOD[2], WOOD[3])
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
    wood:SetColorTexture(WOOD[1], WOOD[2], WOOD[3], 1)
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
    panel.flat = { rim, rimEdge }  -- (the top view's own rim, hidden in the angled view)

    -- The angled view: the board, its rim (inner faces, tops; the near rim in front of the rings), lines, pockets.
    persp = CreateFrame("Frame", nil, panel)
    persp:SetSize(A.VW, A.VH)
    persp:SetPoint("TOPLEFT", 10, -12)
    persp:SetClipsChildren(true)
    local function Quad(tex, p1, p2, p3, p4)  -- a texture bent onto four board points {x, y, h}, going round
        local x1, y1 = PA(p1[1], p1[2], p1[3])
        local x3, y3 = PA(p2[1], p2[2], p2[3])
        local x4, y4 = PA(p3[1], p3[2], p3[3])
        local x2, y2 = PA(p4[1], p4[2], p4[3])
        tex:SetAllPoints(persp)
        tex:SetVertexOffset(UPPER_LEFT_VERTEX or 1, x1, -y1)
        tex:SetVertexOffset(LOWER_LEFT_VERTEX or 2, x2, A.VH - y2)
        tex:SetVertexOffset(UPPER_RIGHT_VERTEX or 3, x3 - A.VW, -y3)
        tex:SetVertexOffset(LOWER_RIGHT_VERTEX or 4, x4 - A.VW, A.VH - y4)
    end
    local function Face(parent, r, g, b, sub, ...)
        local t = parent:CreateTexture(nil, "BACKGROUND", nil, sub)
        t:SetTexture(WHITE)
        t:SetVertexColor(r, g, b, 1)
        Quad(t, ...)
        return t
    end
    local S, RW, RH = K.S, K.RIM, A.RIMH
    Face(persp, WOOD[1], WOOD[2], WOOD[3], -6, { 0, 0, 0 }, { S, 0, 0 }, { S, S, 0 }, { 0, S, 0 })
    Face(persp, 0.5, 0.29, 0.15, -5, { 0, 0, RH }, { S, 0, RH }, { S, 0, 0 }, { 0, 0, 0 })  -- (far rim, its inside)
    Face(persp, 0.42, 0.24, 0.12, -5, { 0, 0, RH }, { 0, S, RH }, { 0, S, 0 }, { 0, 0, 0 })  -- (left rim, inside)
    Face(persp, 0.42, 0.24, 0.12, -5, { S, S, RH }, { S, 0, RH }, { S, 0, 0 }, { S, S, 0 })  -- (right rim, inside)
    Face(persp, 0.4, 0.22, 0.1, -4, { -RW, -RW, RH }, { S + RW, -RW, RH }, { S + RW, 0, RH }, { -RW, 0, RH })
    Face(persp, 0.4, 0.22, 0.1, -4, { -RW, 0, RH }, { 0, 0, RH }, { 0, S, RH }, { -RW, S, RH })
    Face(persp, 0.4, 0.22, 0.1, -4, { S, 0, RH }, { S + RW, 0, RH }, { S + RW, S, RH }, { S, S, RH })
    local function LnA(x1, y1, x2, y2, r, g, b)
        local l = persp:CreateLine(nil, "BORDER", nil, 0)
        l:SetThickness(2)
        l:SetColorTexture(r or 0.72, g or 0.14, b or 0.1, 0.9)
        local ax, ay = PA(x1, y1, 0)
        local bx, by = PA(x2, y2, 0)
        l:SetStartPoint("TOPLEFT", persp, ax, -ay)
        l:SetEndPoint("TOPLEFT", persp, bx, -by)
    end
    local function CircleA(x, y, r, n)
        for k = 0, n - 1 do
            local a1, a2 = k / n * 2 * math.pi, (k + 1) / n * 2 * math.pi
            LnA(x + math.cos(a1) * r, y + math.sin(a1) * r, x + math.cos(a2) * r, y + math.sin(a2) * r)
        end
    end
    -- (red lines, as on Couronne Deluxe's board: the baselines with their corner circles, the centre circle)
    for side = 1, 4 do
        local a, b, c = K.BASE_X1, K.BASE_X2, K.BASE_Y
        if side == 1 then LnA(a, c, b, c) elseif side == 2 then LnA(a, K.S - c, b, K.S - c)
        elseif side == 3 then LnA(c, a, c, b) else LnA(K.S - c, a, K.S - c, b) end
    end
    for _, x in ipairs({ K.BASE_X1, K.BASE_X2 }) do
        for _, y in ipairs({ K.BASE_Y, K.S - K.BASE_Y }) do CircleA(x, y, K.SR + 2, 14) CircleA(y, x, K.SR + 2, 14) end
    end
    CircleA(K.S / 2, K.S / 2, 80, 40)
    CircleA(K.S / 2, K.S / 2, 20, 18)
    for _, p in ipairs(POCKETS) do  -- (blue pocket holes with a darker inside)
        local lip = Round(persp, "BORDER", 3)
        lip:SetVertexColor(0.18, 0.28, 0.5, 1)
        Ellipse(lip, p.x, p.y, 0, K.PR + 2)
        local hole = Round(persp, "BORDER", 4)
        hole:SetVertexColor(0.06, 0.1, 0.22, 1)
        Ellipse(hole, p.x, p.y + 3, 0, K.PR - 3)
    end
    persp.near = CreateFrame("Frame", nil, persp)  -- (the near rim: in front of the rings by it)
    persp.near:SetAllPoints()
    Face(persp.near, 0.4, 0.22, 0.1, 0, { -RW, S, RH }, { S + RW, S, RH }, { S + RW, S + RW, RH }, { -RW, S + RW, RH })
    Face(persp.near, 0.28, 0.15, 0.07, 0, { -RW, S + RW, RH }, { S + RW, S + RW, RH }, { S + RW, S + RW, -14 }, { -RW, S + RW, -14 })
    persp.over = CreateFrame("Frame", nil, persp)  -- (the cue and the aim, over everything)
    persp.over:SetAllPoints()

    -- aiming, in each view: the cue (a tip and the stick), dots where it goes, its power
    local function AimWidgets(f)
        local w = { dots = {} }
        w.cue = f:CreateLine(nil, "OVERLAY", nil, 1)
        w.cue:SetThickness(6)
        w.cue:SetColorTexture(0.24, 0.14, 0.07, 1)
        w.cueTip = f:CreateLine(nil, "OVERLAY", nil, 2)
        w.cueTip:SetThickness(5)
        w.cueTip:SetColorTexture(0.9, 0.86, 0.74, 1)
        for k = 1, 14 do
            local dot = f:CreateTexture(nil, "OVERLAY")
            dot:SetTexture(ROUND)
            dot:SetVertexColor(1, 1, 1, 0.75 - k * 0.04)
            dot:SetSize(5, 5)
            w.dots[k] = dot
        end
        w.aim = Text(f, 13)
        return w
    end
    board.aimW = AimWidgets(board)
    persp.aimW = AimWidgets(persp.over)
    local function OnDown(_, button)
        if G.state ~= "aim" then return end
        if button == "RightButton" then G.aiming = false return end
        local x, y = Cursor()
        if (x - striker.x) ^ 2 + (y - striker.y) ^ 2 < (striker.r + 14) ^ 2 then
            G.aiming = true
        elseif math.abs(y - K.BASE_Y) < 26 then  -- (the baseline: the striker moves there, if it fits)
            local nx = math.max(K.BASE_X1, math.min(K.BASE_X2, x))
            if Free(nx, K.BASE_Y, striker.r, striker) then striker.x = nx PlaceAll() end
        end
    end
    local function OnUp(_, button)
        if button ~= "LeftButton" or not G.aiming then return end
        G.aiming = false
        G.pullX, G.pullY = Cursor()
        if G.state == "aim" then Shoot() end
    end
    for _, f in ipairs({ board, persp }) do
        f:EnableMouse(true)
        f:SetScript("OnMouseDown", OnDown)
        f:SetScript("OnMouseUp", OnUp)
    end

    -- the right side
    local x0 = 602  -- (right of the board, in either view)
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
    panel.streak = Text(panel, 13, { 0.95, 0.76, 0.3 })
    panel.streak:SetPoint("TOPLEFT", x0, -178)
    -- (the shot words: on a frame over the board, in the gap between the window's top and the board's far rim)
    local words = CreateFrame("Frame", nil, panel)
    words:SetAllPoints()
    words:SetFrameLevel(persp:GetFrameLevel() + 200)
    panel.combo = Text(words, 30, { 1, 0.84, 0.2 })
    local _, rimTop = PA(K.S / 2, -K.RIM, A.RIMH)
    panel.combo:SetPoint("CENTER", panel, "TOPLEFT", 10 + A.VW / 2, -(12 + rimTop) / 2)
    panel.combo:Hide()
    panel.msg = Text(panel, 15)
    panel.msg:SetPoint("TOPLEFT", x0, -218)
    panel.msg:SetWidth(200)
    panel.msg:SetJustifyH("LEFT")
    local rules = Text(panel, 12, { 0.73, 0.65, 0.51 })
    rules:SetPoint("TOPLEFT", x0, -300)
    rules:SetWidth(200)
    rules:SetJustifyH("LEFT")
    rules:SetText(("Click your baseline (bottom) to move the striker. Drag back from it and let go to shoot; right-click cancels.\n\nA black or the striker in: +1 shot (the black goes back). The queen in: cover her with a white on the same or next shot for -%d, or she goes back."):format(K.QUEEN_BONUS))
    local new = Btn(panel, 140, 28, "New game", function() NewGame() end)
    new:SetPoint("BOTTOMLEFT", x0, 40)
    panel.viewBtn = Btn(panel, 140, 24, "", function()
        G.view = G.view == "top" and "angled" or "top"
        Db().view = G.view
        panel:ApplyView()
    end)
    panel.viewBtn:SetPoint("BOTTOMLEFT", x0, 74)
    function panel:ApplyView()
        local top = G.view == "top"
        board:SetShown(top)
        for _, t in ipairs(panel.flat) do t:SetShown(top) end
        persp:SetShown(not top)
        panel.viewBtn:SetText(top and "View: from above" or "View: angled")
        PlaceAll()
    end
    panel.stat = Text(panel, 11, { 0.6, 0.55, 0.45 })
    panel.stat:SetPoint("BOTTOMLEFT", x0, 16)
    panel:SetScript("OnUpdate", OnUpdate)
    G.view = (KillTrackerDB and KillTrackerDB.couronne and KillTrackerDB.couronne.view) or "angled"
    NewGame()
    panel:ApplyView()
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
