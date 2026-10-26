-- The claw machine (the gacha box's minigame; a dev test for now: /solc claw, simple textures, test points, nothing won
-- is kept). One capsule per piece you don't own sits in a glass box drawn at a fixed 2.5D angle (tools/claw-mock-3d.html is
-- the web mockup it copies): pay, steer the claw - hold right, let go; hold up, letting go drops it - and it grabs what it
-- lands on. Losing: a whiff, a weak grip or a drop on the way back (each lights one CLAW POWER light: more grip, less
-- sway; a win puts them out). SMASH the cabinet to scramble the pile before you drop: each smash in a go is riskier, and
-- a TILT loses the go and puts every light out.
--
-- Drawing: each capsule is its own little frame (a shaded disc) placed where the camera sees it and sized by distance;
-- the frames' levels are re-sorted far to near whenever things move, the claw (lines) and its shadow sorted in with
-- them. The box's walls and floor are textures bent onto their corners with SetVertexOffset (the field test's trick).
-- Physics: spheres pushed apart pair by pair, walls, the chute's two glass walls, the hole under the chute; it sleeps
-- once the pile is still, so a still machine costs nothing.

local _, ns = ...
local UI = ns.UI
if not UI then return end

local ROUND = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"  -- (a white disc)
local WHITE = "Interface\\Buttons\\WHITE8X8"
local GLOW = "Interface\\AddOns\\SOLC\\Media\\DreamBed\\glow"  -- (soft, fading to nothing: tools/make-dreambed-fx.js)
local FONT = "Interface\\AddOns\\SOLC\\Media\\Fonts\\GermaniaOne-Regular.ttf"
local VUL, VLL, VUR, VLR = UPPER_LEFT_VERTEX or 1, LOWER_LEFT_VERTEX or 2, UPPER_RIGHT_VERTEX or 3, LOWER_RIGHT_VERTEX or 4

-- The box (x left to right, y up, z from the front glass to the back; the chute is the front-left corner), the camera,
-- the physics and the rules, in one table (Lua 5.1: at most 60 upvalues a function).
local K = {
    W = 420, D = 280, H = 360, R = 22, CX = 120, CZ = 120, BH = 165, TIP = 42,
    VW = 540, VH = 430, PITCH = 0.62, DIST = 1500,
    G = 1500, STEP = 1 / 120, ITER = 2,
    PRICE = 150, STEER = 25, SPEED = 150,
    HOLD0 = 60, DROP0 = 20, SLIP = { uncommon = 0, rare = 7, epic = 13, legendary = 20 }, CENTRE = 0.3, OFFPEN = 60,
    TILTS = { 5, 12, 22, 35, 50, 65, 80 }, POWER = 1,
}
K.TOPY = K.H - 30
K.HOME_X, K.HOME_Z = K.CX / 2, K.CZ / 2  -- (where it lets go: over the chute's middle)
K.START_Z = 26  -- (where a go starts: right at the front glass, still over the chute, so the front row can be reached)
local COLORS = { uncommon = { 0.12, 1, 0 }, rare = { 0.23, 0.61, 1 }, epic = { 0.64, 0.21, 0.93 }, legendary = { 1, 0.5, 0 } }

-- Series 1 (tools/gacha-series1-picks.json) as labels only, until the pieces are in MintArt.lua: { id, name, rarity }.
local PIECES = {
    { "hair_pompadour", "Pompadour", "rare" },
    { "hair_combover", "Comb-Over", "uncommon" },
    { "hair_mullet", "Mullet", "uncommon" },
    { "hair_mohawk", "Mohawk", "rare" },
    { "hair_topknot", "Top Knot", "uncommon" },
    { "hair_curlers", "Hair Curlers", "uncommon" },
    { "hair_powdered_wig", "Powdered Wig", "epic" },
    { "hair_slicked", "Slicked Back", "rare" },
    { "hair_braid", "Warrior Braid", "rare" },
    { "hair_afro", "Big Afro", "epic" },
    { "hair_bowlcut", "Bowl Cut", "uncommon" },
    { "face_handlebar", "Handlebar Moustache", "rare" },
    { "face_walrus", "Walrus Moustache", "uncommon" },
    { "face_pencil", "Pencil Moustache", "uncommon" },
    { "face_muttonchops", "Mutton Chops", "rare" },
    { "face_imperial", "Imperial Moustache", "epic" },
    { "face_cigar", "Fat Cigar", "rare" },
    { "face_pipe", "Briar Pipe", "rare" },
    { "face_cigarette", "Dangling Cigarette", "uncommon" },
    { "acc_whiskey", "Whiskey Tumbler", "uncommon" },
    { "acc_brandy", "Brandy Snifter", "rare" },
    { "acc_cigar_box", "Cigar Box", "rare" },
    { "outfit_sailor_stripes", "Sailor Stripes", "uncommon" },
    { "head_souwester", "Sou'wester", "uncommon" },
    { "head_bicorne", "Admiral's Bicorne", "epic" },
    { "outfit_rowing_blazer", "Rowing Blazer", "rare" },
    { "acc_oar", "Rowing Oar", "uncommon" },
    { "outfit_hunting_pink", "Riding Jacket", "rare" },
    { "outfit_jockey_silks", "Jockey Silks", "rare" },
    { "head_jockey_cap", "Jockey Cap", "uncommon" },
    { "acc_riding_crop", "Riding Crop", "uncommon" },
    { "head_polo_helmet", "Polo Helmet", "rare" },
    { "acc_polo_mallet", "Polo Mallet", "rare" },
    { "head_fascinator", "Derby Fascinator", "rare" },
    { "head_ascot_hat", "Ascot Hat", "epic" },
    { "outfit_cricket_whites", "Cricket Whites", "uncommon" },
    { "head_cricket_cap", "Cricket Cap", "uncommon" },
    { "acc_cricket_bat", "Cricket Bat", "rare" },
    { "outfit_umpire", "Umpire's Coat", "epic" },
    { "head_umpire_hats", "Umpire's Hats", "rare" },
    { "acc_croquet_mallet", "Croquet Mallet", "uncommon" },
    { "outfit_fencing", "Fencing Whites", "rare" },
    { "head_fencing_mask", "Fencing Mask", "rare" },
    { "acc_foil", "Fencing Foil", "rare" },
    { "head_aviator", "Aviator Cap", "rare" },
    { "outfit_opera_cape", "Opera Cape", "rare" },
    { "head_opera_hat", "Opera Top Hat", "rare" },
    { "head_bobble", "Bobble Hat & Goggles", "uncommon" },
    { "outfit_parka", "Apres-Ski Parka", "rare" },
    { "head_fishing_hat", "Lure Hat", "uncommon" },
    { "acc_trophy_fish", "Trophy Fish", "epic" },
    { "face_tusk_rings", "Tusk Rings", "rare" },
    { "acc_gilded_club", "Gilded Club", "legendary" },
    { "acc_diamond_monocle", "Diamond Monocle", "legendary" },
    { "head_deerstalker", "Deerstalker", "uncommon" },
    { "acc_peacock", "Peacock", "epic" },
    { "head_fishbowl", "Fishbowl Helmet", "epic" },
    { "acc_tiny_butler", "Tiny Butler", "legendary" },
    { "acc_falcon", "Sleepy Falcon", "epic" },
    { "head_traffic_cone", "Traffic Cone", "uncommon" },
    { "head_bin_lid", "Bin Lid", "uncommon" },
    { "head_knockoff_cap", "Knock-Off Cap", "uncommon" },
    { "head_tinfoil", "Tin-Foil Hat", "uncommon" },
    { "outfit_mustard_vest", "Mustard-Stained Wifebeater", "uncommon" },
    { "outfit_gravy_vest", "Gravy-Stained Wifebeater", "rare" },
    { "outfit_shellsuit", "Shell Suit", "rare" },
    { "outfit_sleeping_bag", "Sleeping Bag Coat", "rare" },
    { "acc_ale_can", "Cheap Ale Can", "uncommon" },
    { "acc_whiskey_bag", "Bottle in a Bag", "rare" },
    { "acc_scratchcard", "Scratch Card", "uncommon" },
    { "acc_pigeon", "Mangy Pigeon", "rare" },
    { "acc_rat", "Pet Rat", "rare" },
    { "acc_knockoff_shades", "Knock-Off Shades", "uncommon" },
    { "head_ear_cigarette", "Cigarette Behind the Ear", "uncommon" },
}

-- ---- the camera: fixed, fitted once so the whole box fills the view ----
local cam = { f = 1, cy = 0, cos = math.cos(K.PITCH), sin = math.sin(K.PITCH) }
local function P(x, y, z)  -- world -> view x, y (down), scale, depth
    local px, py, pz = x - K.W / 2, y - K.H / 2, z - K.D / 2
    local yc = py * cam.cos + pz * cam.sin
    local d = -py * cam.sin + pz * cam.cos + K.DIST
    local s = cam.f / d
    return K.VW / 2 + px * s, cam.cy - yc * s, s, d
end
do
    local minY, maxY, maxX = 1e9, -1e9, 0
    for _, x in ipairs({ 0, K.W }) do for _, y in ipairs({ 0, K.H }) do for _, z in ipairs({ 0, K.D }) do
        local sx, sy = P(x, y, z)
        maxX = math.max(maxX, math.abs(sx - K.VW / 2)); minY = math.min(minY, sy); maxY = math.max(maxY, sy)
    end end end
    cam.f = math.min((K.VW - 30) / (2 * maxX), (K.VH - 24) / (maxY - minY))
    cam.cy = K.VH / 2 - (minY + maxY) / 2 * cam.f
    -- (how deep the box goes, for the haze: front to back at a quarter of its height)
    cam.near = select(4, P(K.W / 2, K.H / 4, 0))
    cam.far = select(4, P(K.W / 2, K.H / 4, K.D))
end

local panel, view
local caps, owned = {}, {}
local S = { state = "idle", t = 0, meter = 0, smashes = 0, shake = 0, tilt = 0, timer = 0, phase = "x", moved = false,
    points = 3000, msg = "Insert 150 points to play.", go = nil, calm = 0, asleep = false, acc = 0, keys = {}, cost = 0 }
local C = { x = K.HOME_X, z = K.START_Z, y = K.TOPY, vx = 0, vz = 0, open = 1, ax = 0, wx = 0, az = 0, wz = 0,
    held = nil, dropAt = -1, travelled = 0, path = 1 }

local function Tilt(k) return K.TILTS[math.min(k + 1, #K.TILTS)] end
local function HoldAt(l) return K.HOLD0 + (100 - K.HOLD0) * l / 5 end
local function DropAt(l) return K.DROP0 * (1 - l / 5) end
local function Slip(r, l) return (K.SLIP[r] or 0) * (1 - l / 5) end
local function Wake() S.asleep, S.calm = false, 0 end
local function Sound(name, fallback) pcall(PlaySound, SOUNDKIT and SOUNDKIT[name] or fallback) end
-- Our own sounds (tools/make-claw-sounds.js): bonk, tilt, clack, and the two motor loops, played back to back (each
-- loop fades in and out, so the copies overlap by LOOP_OVERLAP) while the claw moves.
local SFX = "Interface\\AddOns\\SOLC\\Media\\Claw\\"
local MOTORS = { whir = 0.96, winch = 0.72 }  -- (their lengths, seconds)
local motor = { kind = nil, handle = nil, next = 0 }
local function Play(name) pcall(PlaySoundFile, SFX .. name .. ".ogg", "SFX") end
local function Motor(kind)  -- kind: "whir" (the carriage), "winch" (the cable) or nil (still)
    if kind ~= motor.kind then
        if motor.handle then StopSound(motor.handle, 150) end
        motor.kind, motor.handle, motor.next = kind, nil, 0
    end
    if kind and GetTime() >= motor.next then
        local ok, _, handle = pcall(PlaySoundFile, SFX .. kind .. ".ogg", "SFX")
        motor.handle = ok and handle or nil
        motor.next = GetTime() + MOTORS[kind] - 0.06
    end
end
local function Say(text) S.msg = text if panel then panel.msg:SetText(text) end end

-- ---- capsules ----
local spare = {}  -- (capsule frames not in use, for the next fill)
local function CapFrame(c)
    local f = table.remove(spare)
    if not f then
        f = CreateFrame("Frame", nil, view)
        f.glow = f:CreateTexture(nil, "BACKGROUND", nil, -2)
        f.glow:SetTexture(GLOW)
        f.glow:SetBlendMode("ADD")
        f.rim = f:CreateTexture(nil, "BACKGROUND")
        f.rim:SetTexture(ROUND)
        f.rim:SetVertexColor(0, 0, 0, 0.6)
        f.body = f:CreateTexture(nil, "ARTWORK")
        f.body:SetTexture(ROUND)
        f.shade = f:CreateTexture(nil, "ARTWORK", nil, 1)  -- (the lower right in shadow)
        f.shade:SetTexture(ROUND)
        f.shade:SetVertexColor(0, 0, 0, 0.28)
        f.shine = f:CreateTexture(nil, "OVERLAY")
        f.shine:SetTexture(ROUND)
        f.shine:SetVertexColor(1, 1, 1, 0.6)
    end
    local col = COLORS[c.p[3]] or COLORS.uncommon
    f.body:SetVertexColor(col[1] * 0.8, col[2] * 0.8, col[3] * 0.8)
    f.glow:SetVertexColor(col[1], col[2], col[3], c.p[3] == "legendary" and 0.9 or 0.6)
    f.glow:SetShown(c.p[3] == "epic" or c.p[3] == "legendary")
    f.lit, f.col = nil, col
    f:Show()
    c.f, c.size = f, 0
    return f
end
local function Spare(c) c.f:Hide() spare[#spare + 1] = c.f c.f = nil end
local function SizeCap(c, size)
    if math.abs(size - c.size) < 0.4 then return end
    c.size = size
    local f = c.f
    f:SetSize(size, size)
    f.rim:SetPoint("TOPLEFT", -1, 1) f.rim:SetPoint("BOTTOMRIGHT", 1, -1)
    f.body:SetAllPoints()
    f.shade:SetPoint("TOPLEFT", size * 0.22, -size * 0.22) f.shade:SetPoint("BOTTOMRIGHT", 0, 0)
    f.shine:SetSize(size * 0.38, size * 0.3)
    f.shine:SetPoint("TOPLEFT", size * 0.17, -size * 0.14)
    f.glow:SetPoint("TOPLEFT", -size * 0.6, size * 0.6) f.glow:SetPoint("BOTTOMRIGHT", size * 0.6, -size * 0.6)
end

local Physics  -- (below)
local function Fill()
    for _, c in ipairs(caps) do Spare(c) end
    wipe(caps)
    S.wonDirty = true
    local left = {}
    for _, p in ipairs(PIECES) do if not owned[p[1]] then left[#left + 1] = p end end
    for i = #left, 2, -1 do local j = math.random(i) left[i], left[j] = left[j], left[i] end
    -- (laid in loose rows from the floor up, outside the chute's corner, then let fall into place)
    local R, k = K.R, 1
    local y = R
    while k <= #left do
        for z = R + 1, K.D - R, 2 * R + 2 do
            for x = R + 1, K.W - R, 2 * R + 2 do
                if k <= #left and not (x < K.CX + R and z < K.CZ + R) then
                    local c = { p = left[k], x = x + math.random() * 4, y = y, z = z + math.random() * 4, vx = 0, vy = 0, vz = 0 }
                    caps[#caps + 1] = c
                    k = k + 1
                end
            end
        end
        y = y + 2 * R
    end
    for _, c in ipairs(caps) do CapFrame(c) end
    for _ = 1, 120 do Physics(K.STEP) end
    Wake()
end

-- ---- physics ----
local function Bounds(c)
    local R = K.R
    if c.x < R then c.x = R c.vx = math.abs(c.vx) * 0.3 end
    if c.x > K.W - R then c.x = K.W - R c.vx = -math.abs(c.vx) * 0.3 end
    if c.z < R then c.z = R c.vz = math.abs(c.vz) * 0.3 end
    if c.z > K.D - R then c.z = K.D - R c.vz = -math.abs(c.vz) * 0.3 end
    if c.y > K.H - R then c.y = K.H - R c.vy = -math.abs(c.vy) * 0.3 end
    if c.y < R and not (c.x < K.CX and c.z < K.CZ) then
        c.y = R
        if c.vy < 0 then c.vy = -c.vy * 0.2 end
        c.vx, c.vz = c.vx * 0.96, c.vz * 0.96
    end
    -- (the chute's two glass walls: x = CX in front of CZ, z = CZ left of CX, BH high)
    for w = 1, 2 do
        local qx, qy, qz
        qy = math.max(0, math.min(K.BH, c.y))
        if w == 1 then qx, qz = K.CX, math.max(0, math.min(K.CZ, c.z)) else qx, qz = math.max(0, math.min(K.CX, c.x)), K.CZ end
        local ex, ey, ez = c.x - qx, c.y - qy, c.z - qz
        local e = math.sqrt(ex * ex + ey * ey + ez * ez)
        if e < R + 3 and e > 0 then
            local nx, ny, nz, o = ex / e, ey / e, ez / e, R + 3 - e
            c.x, c.y, c.z = c.x + nx * o, c.y + ny * o, c.z + nz * o
            local vn = c.vx * nx + c.vy * ny + c.vz * nz
            if vn < 0 then c.vx, c.vy, c.vz = c.vx - nx * vn * 1.3, c.vy - ny * vn * 1.3, c.vz - nz * vn * 1.3 end
        end
    end
    -- (on its way up the claw brushes capsules aside; going down it stops on the first it touches)
    if S.state == "rise" and c ~= C.held then
        local ty = C.y - K.TIP + 6
        local ex, ey, ez = c.x - C.x, c.y - ty, c.z - C.z
        local e = math.sqrt(ex * ex + ey * ey + ez * ez)
        if e < R + 8 and e > 0 then
            local k = (R + 8) / e
            c.x, c.y, c.z = C.x + ex * k, ty + ey * k, C.z + ez * k
        end
    end
    if math.abs(c.vx) + math.abs(c.vy) + math.abs(c.vz) < 20 then c.vx, c.vy, c.vz = c.vx * 0.85, c.vy * 0.92, c.vz * 0.85 end
end
Physics = function(dt)
    local R2, R = 4 * K.R * K.R, K.R
    local n = #caps
    for i = 1, n do
        local c = caps[i]
        if not c.held then
            c.vy = c.vy - K.G * dt
            c.x, c.y, c.z = c.x + c.vx * dt, c.y + c.vy * dt, c.z + c.vz * dt
            c.vx, c.vy, c.vz = c.vx * 0.9985, c.vy * 0.9995, c.vz * 0.9985
        end
    end
    for _ = 1, K.ITER do
        for i = 1, n do
            local a = caps[i]
            for j = i + 1, n do
                local b = caps[j]
                local dx = b.x - a.x
                if dx < 2 * R and dx > -2 * R then
                    local dy, dz = b.y - a.y, b.z - a.z
                    local d2 = dx * dx + dy * dy + dz * dz
                    if d2 < R2 and d2 > 0 then
                        local d = math.sqrt(d2)
                        local nx, ny, nz, o = dx / d, dy / d, dz / d, 2 * R - d
                        local wa = a.held and 0 or (b.held and 1 or 0.5)
                        local wb = 1 - wa
                        a.x, a.y, a.z = a.x - nx * o * wa, a.y - ny * o * wa, a.z - nz * o * wa
                        b.x, b.y, b.z = b.x + nx * o * wb, b.y + ny * o * wb, b.z + nz * o * wb
                        local vn = (b.vx - a.vx) * nx + (b.vy - a.vy) * ny + (b.vz - a.vz) * nz
                        if vn < 0 then
                            local j2 = -1.15 * vn
                            if not a.held then a.vx, a.vy, a.vz = a.vx - nx * j2 * wa, a.vy - ny * j2 * wa, a.vz - nz * j2 * wa end
                            if not b.held then b.vx, b.vy, b.vz = b.vx + nx * j2 * wb, b.vy + ny * j2 * wb, b.vz + nz * j2 * wb end
                        end
                    end
                end
            end
        end
        for i = 1, n do if not caps[i].held then Bounds(caps[i]) end end
    end
    local fastest = 0
    for i = 1, n do
        local c = caps[i]
        if c.held then c.vx, c.vy, c.vz = 0, 0, 0
        else fastest = math.max(fastest, math.abs(c.vx) + math.abs(c.vy) + math.abs(c.vz)) end
    end
    return fastest
end

-- ---- the go ----
local function Insert()
    if S.state ~= "idle" then return end
    if #caps == 0 then return Say("The machine is empty: you have them all!") end
    if S.points < K.PRICE then return Say("Not enough points.") end
    S.points = S.points - K.PRICE
    S.go = { wins = {}, held = false }
    S.smashes, S.timer, S.state, S.phase, S.moved = 0, K.STEER, "steer", "x", false
    C.x, C.z, C.y, C.open, C.held = K.HOME_X, K.START_Z, K.TOPY, 1, nil
    Say("Hold RIGHT to move the claw across...")
end
local function Drop() if S.state == "steer" then S.state = "drop" C.open = 1 Wake() end end
local function Smash()
    if S.state ~= "steer" then return end
    local chance = Tilt(S.smashes)
    if math.random() * 100 < chance then
        S.state, S.t, S.tilt, S.meter = "tilt", 0, 2.2, 0
        S.go.outcome = "tilt"
        Play("tilt")
        return Say(("TILT! (that smash had a %d%% chance) The go is lost and the lights are out."):format(chance))
    end
    S.smashes, S.shake = S.smashes + 1, 0.4
    for _, c in ipairs(caps) do
        if not c.held then
            c.vy = c.vy + (300 + math.random() * 600) * K.POWER
            c.vx = c.vx + (math.random() - 0.5) * 520 * K.POWER
            c.vz = c.vz + (math.random() - 0.5) * 520 * K.POWER
        end
    end
    Wake()
    Play("bonk")
    Say(("BONK! Smash %d survived (%d%%). Next one: %d%%."):format(S.smashes, chance, Tilt(S.smashes)))
end
local function GrabOdds(c, offset)
    local l = S.meter
    local off = offset > K.CENTRE and (offset - K.CENTRE) / (1 - K.CENTRE) * K.OFFPEN or 0
    return math.max(0, math.min(100, HoldAt(l) - Slip(c.p[3], l) - off))
end
local function Target()  -- the capsule the claw closes on, and how far off its middle it is (0..1)
    local ty, best, bh = C.y - K.TIP, nil, 1e9
    for _, c in ipairs(caps) do
        if not c.held then
            local hd = math.sqrt((c.x - C.x) ^ 2 + (c.z - C.z) ^ 2)
            if math.sqrt(hd * hd + (c.y - ty) ^ 2) < K.R + 24 and c.y <= ty + 10 and hd < bh then best, bh = c, hd end
        end
    end
    return best, best and math.min(1, bh / (K.R + 14))
end
local function SurfaceUnder(x, z)  -- where the claw's shadow falls (nil over the hole)
    local h = (x < K.CX and z < K.CZ) and nil or 0
    for _, c in ipairs(caps) do
        if c ~= C.held then
            local hd2 = (c.x - x) ^ 2 + (c.z - z) ^ 2
            if hd2 < K.R * K.R then h = math.max(h or -1e9, c.y + math.sqrt(K.R * K.R - hd2)) end
        end
    end
    return h
end
local function Finish()
    local go = S.go
    S.go, S.state = nil, "idle"
    if #go.wins > 0 then
        local names = {}
        for i, p in ipairs(go.wins) do names[i] = p[2] end
        S.meter = 0
        Sound("UI_EPICLOOT_TOAST", 120)
        Say(((go.held and not go.outcome) and "WON! " or "LUCKY! ") .. table.concat(names, " + "))
    else
        S.meter = math.min(5, S.meter + 1)
        if not go.outcome then Say("Whiff: nothing under the claw. +1 light.") else Say(S.msg .. " +1 light.") end
    end
end

local function Step(dt)
    S.t = S.t + dt
    local pvx, pvz = C.vx, C.vz
    C.vx, C.vz = 0, 0
    local st = S.state
    if st == "steer" then
        S.timer = S.timer - dt
        local key = S.phase == "x" and S.keys.RIGHT or S.keys.UP
        if key then
            S.moved = true
            if S.phase == "x" then C.vx = K.SPEED else C.vz = K.SPEED end
        elseif S.moved then
            if S.phase == "x" then S.phase, S.moved = "z", false Say("Now hold UP to move it back. Letting go drops it.")
            else Drop() end
        end
        if S.phase == "x" and C.x >= K.W - 26 then S.phase, S.moved = "z", false end
        if S.phase == "z" and C.z >= K.D - 26 then Drop() end
        C.x = math.max(26, math.min(K.W - 26, C.x + C.vx * dt))
        C.z = math.max(26, math.min(K.D - 26, C.z + C.vz * dt))
        if S.timer <= 0 then Drop() end
    elseif st == "drop" then
        C.y = C.y - 190 * dt
        local tipY = C.y - K.TIP
        local hit = tipY <= 4
        for _, c in ipairs(caps) do
            if (c.x - C.x) ^ 2 + (c.y - tipY) ^ 2 + (c.z - C.z) ^ 2 < (K.R + 6) ^ 2 then hit = true break end
        end
        if hit then S.state, S.t = "close", 0 Play("clack") end
    elseif st == "close" then
        C.open = math.max(0, 1 - S.t / 0.45)
        if S.t >= 0.5 then
            local c, offset = Target()
            if not c then S.go.outcome = "whiff"
            else
                local odds = GrabOdds(c, offset)
                if math.random() * 100 < odds then
                    C.held, c.held, S.go.held = c, true, true
                    local dropChance = DropAt(S.meter) + Slip(c.p[3], S.meter) * 0.4
                    C.dropAt = math.random() * 100 < dropChance and (0.15 + math.random() * 0.8) or -1
                    Say(("Got hold of %s (%d%% grip)..."):format(c.p[2], math.floor(odds + 0.5)))
                else
                    S.go.outcome = "weak"
                    c.vy, c.vx, c.vz = c.vy + 160, c.vx + (math.random() - 0.5) * 120, c.vz + (math.random() - 0.5) * 120
                    Say(("It slipped off %s (%d%% grip)."):format(c.p[2], math.floor(odds + 0.5)))
                end
            end
            C.travelled = 0
            C.path = (K.TOPY - C.y) + math.sqrt((C.x - K.HOME_X) ^ 2 + (C.z - K.HOME_Z) ^ 2) + 1
            S.state, S.t = "rise", 0
        end
    elseif st == "rise" or st == "carry" then
        if st == "rise" then
            local ny = math.min(K.TOPY, C.y + 150 * dt)
            C.travelled, C.y = C.travelled + ny - C.y, ny
            if C.y >= K.TOPY then S.state = "carry" end
        else
            local dx, dz = K.HOME_X - C.x, K.HOME_Z - C.z
            local d = math.sqrt(dx * dx + dz * dz)
            local mv = math.min(d, 140 * dt)
            if d > 0 then
                C.vx, C.vz = dx / d * mv / dt, dz / d * mv / dt
                C.x, C.z = C.x + dx / d * mv, C.z + dz / d * mv
            end
            C.travelled = C.travelled + mv
            if d < 0.5 then S.state, S.t = "release", 0 end
        end
        if C.held and C.dropAt >= 0 and C.travelled / C.path >= C.dropAt then
            local c = C.held
            c.held, c.vx, c.vz, c.vy = nil, C.vx, C.vz, -40
            C.held, C.dropAt, C.open = nil, -1, 0.6
            S.go.outcome = "drop"
            Say(("Dropped %s on the way!"):format(c.p[2]))
        end
    elseif st == "release" then
        C.open = math.min(1, S.t / 0.3)
        if C.held and S.t > 0.15 then
            local c = C.held
            c.held, c.vx, c.vz, c.vy = nil, 0, 0, -60
            C.held = nil
        end
        if S.t > 0.4 then S.state, S.t = "settle", 0 end
    elseif st == "settle" then
        if S.t > 1.4 then Finish() end
    elseif st == "tilt" then
        S.tilt = S.tilt - dt
        if S.tilt <= 0 then S.state, S.go = "idle", nil end
    end
    -- (the sway, looks only: the drop was rolled at the grab)
    local L = math.max(30, K.TOPY + 30 - C.y) + 30
    for axis = 1, 2 do
        local a, w = axis == 1 and "ax" or "az", axis == 1 and "wx" or "wz"
        local acc = axis == 1 and (C.vx - pvx) / dt or (C.vz - pvz) / dt
        C[w] = (C[w] + (-(900 / L) * math.sin(C[a]) - (acc / L) * math.cos(C[a]) * 0.6) * dt) * math.exp(-1.8 * dt)
        C[a] = math.max(-0.5, math.min(0.5, C[a] + C[w] * dt))
    end
    if C.held then
        C.held.x, C.held.z = C.x + math.sin(C.ax) * K.TIP, C.z + math.sin(C.az) * K.TIP
        C.held.y = C.y - K.TIP - K.R + 6
    end
    -- (fallen through the hole: won, even knocked in; with no go on, back on top of the pile)
    for i = #caps, 1, -1 do
        local c = caps[i]
        if not c.held and c.x < K.CX and c.z < K.CZ and c.y < -K.R * 1.5 then
            if S.go and S.state ~= "tilt" then
                table.remove(caps, i)
                Spare(c)
                owned[c.p[1]] = true
                S.wonDirty = true
                S.go.wins[#S.go.wins + 1] = c.p
            else
                c.x, c.z, c.y = K.CX + K.R + math.random() * (K.W - K.CX - 2 * K.R), K.CZ + K.R + math.random() * (K.D - K.CZ - 2 * K.R), K.H - K.R
                c.vx, c.vy, c.vz = 0, 0, 0
            end
        end
    end
end

-- ---- drawing ----
-- A texture over the whole view, its four corners bent onto these world points (going round the quad).
local function Quad(tex, a, b, c, d)
    local x1, y1 = P(a[1], a[2], a[3])
    local x3, y3 = P(b[1], b[2], b[3])
    local x4, y4 = P(c[1], c[2], c[3])
    local x2, y2 = P(d[1], d[2], d[3])
    tex:SetAllPoints(view)
    tex:SetVertexOffset(VUL, x1, -y1)
    tex:SetVertexOffset(VLL, x2, K.VH - y2)
    tex:SetVertexOffset(VUR, x3 - K.VW, -y3)
    tex:SetVertexOffset(VLR, x4 - K.VW, K.VH - y4)
end
local function Line(line, ax, ay, bx, by)
    line:SetStartPoint("TOPLEFT", view, ax, -ay)
    line:SetEndPoint("TOPLEFT", view, bx, -by)
end
-- A brass block (the gantry's parts): the two faces the camera sees, its top and its front.
local function Box(b, x1, x2, y1, y2, z1, z2)
    Quad(b.top, { x1, y2, z2 }, { x2, y2, z2 }, { x2, y2, z1 }, { x1, y2, z1 })
    Quad(b.front, { x1, y2, z1 }, { x2, y2, z1 }, { x2, y1, z1 }, { x1, y1, z1 })
end

local order = {}
local function Draw()
    local sx, sy = 0, 0
    if S.shake > 0 or S.state == "steer" then  -- (a smash, or the cabinet's rattle as the next smash gets riskier)
        local amount = (S.shake > 0 and 9 * S.shake / 0.4 or 0) + (S.state == "steer" and Tilt(S.smashes) / 100 * 2.2 or 0)
        sx, sy = (math.random() - 0.5) * amount, (math.random() - 0.5) * amount
    end
    view:ClearAllPoints()
    view:SetPoint("TOPLEFT", panel, "TOPLEFT", 16 + sx, -16 - sy)
    wipe(order)
    for _, c in ipairs(caps) do
        local x, y, s, d = P(c.x, c.y, c.z)
        SizeCap(c, 2 * K.R * s)
        c.f:ClearAllPoints()
        c.f:SetPoint("CENTER", view, "TOPLEFT", x, -y)
        c.f.d = d
        order[#order + 1] = c.f
    end
    -- Shade: a capsule with others resting over it is darker (the light comes from above). Eased towards its target
    -- so it doesn't flicker while the pile jostles; a colour is only sent when it changed enough to see.
    local reach = 2.4 * K.R
    for _, a in ipairs(caps) do
        local occ = 0
        for _, b in ipairs(caps) do
            local up = b.y - a.y
            if up > 4 then
                local hd2 = (b.x - a.x) ^ 2 + (b.z - a.z) ^ 2
                if hd2 < reach * reach then occ = occ + (1 - math.sqrt(hd2) / reach) * math.min(1, up / K.R) end
            end
        end
        local target = 1 - 0.55 * math.min(1, occ * 0.7)
        a.lit = a.lit and (a.lit + (target - a.lit) * 0.2) or target
        -- (and haze: the further back, the darker and greyer - by its exact distance, so it shades smoothly, never row
        -- by row)
        local f = a.f
        local fog = math.max(0, math.min(1, (f.d - cam.near) / (cam.far - cam.near)))
        local v = a.lit * (1 - 0.3 * fog)
        if not f.lit or math.abs(v - f.lit) > 0.02 then
            f.lit = v
            local col, k, grey = f.col, v * 0.8, 0.3 * fog
            f.body:SetVertexColor((col[1] * (1 - grey) + 0.4 * grey) * k, (col[2] * (1 - grey) + 0.4 * grey) * k, (col[3] * (1 - grey) + 0.45 * grey) * k)
            f.shine:SetAlpha((0.25 + 0.75 * a.lit * a.lit) * (1 - 0.4 * fog))
        end
    end
    -- the gantry: the crossbar riding the side rails at the claw's depth, its end blocks, the carriage on it
    -- (bending a texture costs, so only when the claw has moved)
    local gy, gw = K.H - 4, view.gantry
    if gw.z ~= C.z then
        gw.z, gw.x = C.z, nil
        Box(gw.bar, 0, K.W, gy - 9, gy, C.z - 6, C.z + 6)
        Box(gw.left, 0, 16, gy - 12, gy + 2, C.z - 11, C.z + 11)
        Box(gw.right, K.W - 16, K.W, gy - 12, gy + 2, C.z - 11, C.z + 11)
    end
    if gw.x ~= C.x then
        gw.x = C.x
        Box(gw.cart, C.x - 17, C.x + 17, gy - 16, gy + 4, C.z - 13, C.z + 13)
    end
    -- the claw: cable, head, three prongs (open / closed)
    local cl = view.claw
    local hx, hz = C.x + math.sin(C.ax) * 6, C.z + math.sin(C.az) * 6
    local tx, ty = P(C.x, gy - 16, C.z)
    local headX, headY, headS, headD = P(hx, C.y, hz)
    Line(cl.cable, tx, ty, headX, headY)
    local spread = 6 + C.open * 22
    local tipx, tipz = C.x + math.sin(C.ax) * K.TIP, C.z + math.sin(C.az) * K.TIP
    for k = 1, 3 do
        local an = (k - 1) * 2.094 + 0.5
        local ox, oz = math.cos(an), math.sin(an)
        local kx, ky = P(hx + ox * (spread + 4), C.y - K.TIP * 0.55, hz + oz * (spread + 4))
        local px, py = P(tipx + ox * spread * 0.55, C.y - K.TIP, tipz + oz * spread * 0.55)
        Line(cl.upper[k], headX, headY, kx, ky)
        Line(cl.lower[k], kx, ky, px, py)
        cl.upper[k]:SetThickness(math.max(2, 4 * K.DIST / headD))
        cl.lower[k]:SetThickness(math.max(2, 4 * K.DIST / headD))
    end
    cl.head:ClearAllPoints()
    cl.head:SetPoint("CENTER", view, "TOPLEFT", headX, -headY)
    cl.head:SetSize(26 * headS, 26 * headS)
    local glow = S.meter >= 5 and (0.5 + 0.5 * math.sin(GetTime() * 5.5)) or 0
    local r, g, b = 0.9, 0.83, 0.64
    if glow > 0 then r, g, b = 1, 0.78 + 0.16 * glow, 0.47 end
    for k = 1, 3 do cl.upper[k]:SetColorTexture(r, g, b) cl.lower[k]:SetColorTexture(r, g, b) end
    cl.head:SetVertexColor(r * 0.95, g * 0.92, b * 0.85)
    local _, _, _, clawD = P(C.x, C.y - K.TIP / 2, C.z)
    cl.d = clawD - 2
    order[#order + 1] = cl
    -- its shadow on what's under it (steering and dropping only)
    local sh = view.shadow
    local h = (S.state == "steer" or S.state == "drop" or S.state == "idle") and SurfaceUnder(C.x, C.z) or nil
    if h then
        local ax, ay, _, ad = P(C.x, h + 0.5, C.z)
        local bx = P(C.x + 18, h + 0.5, C.z)
        local _, cy = P(C.x, h + 0.5, C.z + 18)
        sh:ClearAllPoints()
        sh:SetPoint("CENTER", view, "TOPLEFT", ax, -ay)
        sh:SetSize(2 * math.abs(bx - ax), math.max(3, 2 * math.abs(cy - ay)))
        sh.d = ad - 1
        sh:Show()
        order[#order + 1] = sh
    else
        sh:Hide()
    end
    table.sort(order, function(a, b2) return a.d > b2.d end)
    local base = view:GetFrameLevel() + 2
    for i, f in ipairs(order) do
        if f.lvl ~= base + i then f.lvl = base + i f:SetFrameLevel(base + i) end
    end
    view.gantry:SetFrameLevel(base + #order + 1)  -- (the highest thing in the box: over the capsules and the claw)
    view.front:SetFrameLevel(base + #order + 3)
    view.marquee:SetTextColor(S.state == "tilt" and 1 or 0.95, S.state == "tilt" and 0.23 or 0.76, S.state == "tilt" and 0.16 or 0.3)
    view.marquee:SetText(S.state == "tilt" and "T I L T" or "THE CLAW")
end

local function Refresh()
    panel.points:SetText(("%d test points"):format(S.points))
    for i = 1, 5 do
        local lit = i <= S.meter
        panel.lights[i]:SetVertexColor(lit and 1 or 0.23, lit and 0.84 or 0.17, lit and 0.42 or 0.08)
    end
    local steer = S.state == "steer"
    panel.insert:SetEnabled(S.state == "idle")
    panel.smash:SetEnabled(steer)
    panel.drop:SetEnabled(steer)
    panel.stat:SetText(("%d capsules left   Lua %.1f ms"):format(#caps, S.cost))
    panel.timer:SetText(steer and ("Time %ds   Next smash: %d%% TILT"):format(math.ceil(S.timer), Tilt(S.smashes)) or "")
    if not S.wonDirty then return end
    S.wonDirty = false
    local won = {}
    for _, p in ipairs(PIECES) do
        if owned[p[1]] then
            local col = COLORS[p[3]]
            won[#won + 1] = ("|cff%02x%02x%02x%s|r"):format(math.floor(col[1] * 255), math.floor(col[2] * 255), math.floor(col[3] * 255), p[2])
        end
    end
    panel.won:SetText(#won > 0 and table.concat(won, ", ") or "Nothing won yet.")
end

local function OnUpdate(_, elapsed)
    local t0 = debugprofilestop()
    elapsed = math.min(elapsed, 0.05)
    S.acc = S.acc + elapsed
    if S.shake > 0 then S.shake = S.shake - elapsed end
    local busy = S.state ~= "idle" or not S.asleep or S.shake > 0
    while S.acc >= K.STEP do
        S.acc = S.acc - K.STEP
        Step(K.STEP)
        if not S.asleep then
            local fastest = Physics(K.STEP)
            local active = S.state == "drop" or S.state == "close" or S.state == "rise" or S.state == "carry" or S.state == "release" or S.state == "settle"
            if fastest < 40 and not active then  -- (gravity alone adds ~12 a step to a resting one)
                S.calm = S.calm + K.STEP
                if S.calm > 0.6 then S.asleep = true end
            else
                S.calm = 0
            end
        end
    end
    if busy then Draw() end
    local st = S.state
    if (st == "steer" and (C.vx ~= 0 or C.vz ~= 0)) or st == "carry" then Motor("whir")
    elseif st == "drop" or st == "rise" then Motor("winch")
    else Motor(nil) end
    S.cost = S.cost * 0.9 + (debugprofilestop() - t0) * 0.1
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
    if onClick then b:SetScript("OnClick", onClick) end
    return b
end
local function HoldBtn(parent, text, key)  -- (held with the mouse, as the arrow key)
    local b = Btn(parent, 70, 30, text)
    b:SetScript("OnMouseDown", function() S.keys[key] = true end)
    b:SetScript("OnMouseUp", function() S.keys[key] = nil end)
    b:SetScript("OnHide", function() S.keys[key] = nil end)
    return b
end

local function Build()
    panel = CreateFrame("Frame", "SOLCClaw", UIParent, "BackdropTemplate")
    panel:SetBackdrop({ bgFile = WHITE })
    panel:SetBackdropColor(0.18, 0.04, 0.06, 1)
    panel:EnableMouse(true)
    panel:Hide()
    panel:HookScript("OnHide", function()
        wipe(S.keys)
        Motor(nil)
        if ns.UI.ClearScreen then ns.UI.ClearScreen("Claw") end
    end)

    view = CreateFrame("Frame", nil, panel)
    view:SetSize(K.VW, K.VH)
    view:SetPoint("TOPLEFT", 16, -16)
    view:SetClipsChildren(true)
    local back = view:CreateTexture(nil, "BACKGROUND", nil, -8)
    back:SetAllPoints()
    back:SetColorTexture(0.07, 0.05, 0.06, 1)
    -- the box: back wall, side walls, floor, the hole under the chute
    local W, D, H, CX, CZ = K.W, K.D, K.H, K.CX, K.CZ
    local function Face(r, g, b, a, sub, p1, p2, p3, p4)
        local t = view:CreateTexture(nil, "BACKGROUND", nil, sub)
        t:SetTexture(WHITE)
        t:SetVertexColor(r, g, b, a)
        Quad(t, p1, p2, p3, p4)
        return t
    end
    Face(0.11, 0.1, 0.14, 1, -7, { 0, H, D }, { W, H, D }, { W, 0, D }, { 0, 0, D })
    Face(0.09, 0.08, 0.11, 1, -6, { 0, H, 0 }, { 0, H, D }, { 0, 0, D }, { 0, 0, 0 })
    Face(0.09, 0.08, 0.11, 1, -6, { W, H, D }, { W, H, 0 }, { W, 0, 0 }, { W, 0, D })
    Face(0.17, 0.08, 0.09, 1, -5, { 0, 0, D }, { W, 0, D }, { W, 0, 0 }, { 0, 0, 0 })
    Face(0.02, 0.01, 0.01, 1, -4, { 0, 0, CZ }, { CX, 0, CZ }, { CX, 0, 0 }, { 0, 0, 0 })
    for x = 60, W - 1, 60 do  -- (faint lines on the floor, for depth)
        local l = view:CreateLine(nil, "BACKGROUND", nil, -3)
        l:SetThickness(1)
        l:SetColorTexture(1, 1, 1, 0.05)
        local ax, ay = P(x, 0, x < CX and CZ or 0)
        local bx, by = P(x, 0, D)
        Line(l, ax, ay, bx, by)
    end
    for z = 60, D - 1, 60 do
        local l = view:CreateLine(nil, "BACKGROUND", nil, -3)
        l:SetThickness(1)
        l:SetColorTexture(1, 1, 1, 0.05)
        local ax, ay = P(z < CZ and CX or 0, 0, z)
        local bx, by = P(W, 0, z)
        Line(l, ax, ay, bx, by)
    end
    local prize = Text(view, 13, { 0.95, 0.76, 0.3 })
    local px, py = P(CX / 2, 0, CZ / 2)
    prize:SetPoint("CENTER", view, "TOPLEFT", px, -py)
    prize:SetText("PRIZE")
    -- the claw (lines on a frame of its own, sorted in among the capsules)
    local cl = CreateFrame("Frame", nil, view)
    cl:SetAllPoints()
    local function NewLine(thick, r, g, b, a)
        local l = cl:CreateLine(nil, "ARTWORK")
        l:SetThickness(thick)
        l:SetColorTexture(r, g, b, a or 1)
        return l
    end
    cl.cable = NewLine(2, 0.78, 0.71, 0.54)
    cl.upper, cl.lower = {}, {}
    for k = 1, 3 do cl.upper[k] = NewLine(3, 0.9, 0.83, 0.64) cl.lower[k] = NewLine(3, 0.9, 0.83, 0.64) end
    cl.head = cl:CreateTexture(nil, "OVERLAY")
    cl.head:SetTexture(ROUND)
    view.claw = cl
    -- the gantry: two brass rails along the side walls' tops (still), and the moving parts (Draw places them)
    local gw = CreateFrame("Frame", nil, view)
    gw:SetAllPoints()
    local function Brass(r, g, b, sub)
        local t = gw:CreateTexture(nil, "ARTWORK", nil, sub)
        t:SetTexture(WHITE)
        t:SetVertexColor(r, g, b, 1)
        return t
    end
    local function Block(sub) return { top = Brass(0.83, 0.66, 0.33, sub + 1), front = Brass(0.47, 0.34, 0.16, sub) } end
    local gy = K.H - 4
    for _, x in ipairs({ 0, K.W - 10 }) do
        local inner = x == 0 and 10 or K.W - 10
        Quad(Brass(0.72, 0.56, 0.28, 0), { x, gy, K.D }, { x + 10, gy, K.D }, { x + 10, gy, 0 }, { x, gy, 0 })
        Quad(Brass(0.36, 0.26, 0.12, -1), { inner, gy, 0 }, { inner, gy, K.D }, { inner, gy - 8, K.D }, { inner, gy - 8, 0 })
    end
    gw.bar, gw.left, gw.right, gw.cart = Block(2), Block(4), Block(4), Block(6)
    view.gantry = gw
    local sh = CreateFrame("Frame", nil, view)
    sh.tex = sh:CreateTexture(nil, "ARTWORK")
    sh.tex:SetTexture(ROUND)
    sh.tex:SetVertexColor(0, 0, 0, 0.55)
    sh.tex:SetAllPoints()
    view.shadow = sh
    -- in front of everything: the chute's glass walls, the marquee
    local front = CreateFrame("Frame", nil, view)
    front:SetAllPoints()
    local function Glass(p1, p2, p3, p4)
        local t = front:CreateTexture(nil, "ARTWORK")
        t:SetTexture(WHITE)
        t:SetVertexColor(0.78, 0.9, 1, 0.1)
        Quad(t, p1, p2, p3, p4)
        local pts = { p1, p2, p3, p4 }
        for i = 1, 4 do
            local a, b = pts[i], pts[i % 4 + 1]
            local l = front:CreateLine(nil, "OVERLAY")
            l:SetThickness(1.5)
            l:SetColorTexture(0.78, 0.9, 1, 0.5)
            local ax, ay = P(a[1], a[2], a[3])
            local bx, by = P(b[1], b[2], b[3])
            Line(l, ax, ay, bx, by)
        end
    end
    Glass({ CX, K.BH, 0 }, { CX, K.BH, CZ }, { CX, 0, CZ }, { CX, 0, 0 })
    Glass({ 0, K.BH, CZ }, { CX, K.BH, CZ }, { CX, 0, CZ }, { 0, 0, CZ })
    view.marquee = Text(front, 26)
    view.marquee:SetPoint("TOP", 0, -8)
    view.front = front
    local frame = panel:CreateTexture(nil, "BORDER")  -- (a gold rim round the glass)
    frame:SetColorTexture(0.79, 0.63, 0.29, 1)
    frame:SetPoint("TOPLEFT", view, "TOPLEFT", -3, 3)
    frame:SetPoint("BOTTOMRIGHT", view, "BOTTOMRIGHT", 3, -3)

    -- the right side: points, buttons, CLAW POWER, what happened, what you've won
    local x0 = 16 + K.VW + 18
    panel.points = Text(panel, 20, { 0.95, 0.76, 0.3 })
    panel.points:SetPoint("TOPLEFT", x0, -18)
    panel.insert = Btn(panel, 150, 30, ("Insert %d"):format(K.PRICE), Insert)
    panel.insert:SetPoint("TOPLEFT", x0, -50)
    panel.smash = Btn(panel, 110, 30, "SMASH", Smash)
    panel.smash:SetPoint("LEFT", panel.insert, "RIGHT", 6, 0)
    panel.right = HoldBtn(panel, "RIGHT", "RIGHT")
    panel.right:SetPoint("TOPLEFT", x0, -88)
    panel.up = HoldBtn(panel, "UP", "UP")
    panel.up:SetPoint("LEFT", panel.right, "RIGHT", 6, 0)
    panel.drop = Btn(panel, 110, 30, "Drop", Drop)
    panel.drop:SetPoint("LEFT", panel.up, "RIGHT", 6, 0)
    local help = Text(panel, 12, { 0.73, 0.65, 0.51 })
    help:SetPoint("TOPLEFT", x0, -126)
    help:SetWidth(240)
    help:SetJustifyH("LEFT")
    help:SetText("Keys: Enter pays. Hold Right, let go; hold Up, letting go drops the claw. S smashes - each smash is riskier, a TILT loses the go and puts the lights out.")
    local powerLabel = Text(panel, 15, { 0.79, 0.63, 0.29 })
    powerLabel:SetPoint("TOPLEFT", x0, -200)
    powerLabel:SetText("CLAW POWER")
    panel.lights = {}
    for i = 1, 5 do
        local l = panel:CreateTexture(nil, "ARTWORK")
        l:SetTexture(ROUND)
        l:SetSize(22, 22)
        l:SetPoint("TOPLEFT", x0 + (i - 1) * 30, -224)
        panel.lights[i] = l
    end
    panel.timer = Text(panel, 14)
    panel.timer:SetPoint("TOPLEFT", x0, -258)
    panel.msg = Text(panel, 15)
    panel.msg:SetPoint("TOPLEFT", x0, -284)
    panel.msg:SetWidth(240)
    panel.msg:SetJustifyH("LEFT")
    panel.msg:SetText(S.msg)
    panel.won = Text(panel, 12)
    panel.won:SetPoint("TOPLEFT", x0, -360)
    panel.won:SetWidth(240)
    panel.won:SetJustifyH("LEFT")
    panel.stat = Text(panel, 11, { 0.6, 0.55, 0.45 })
    panel.stat:SetPoint("BOTTOMLEFT", x0, 40)
    local reset = Btn(panel, 120, 22, "Refill (test)", function()
        wipe(owned) S.points = math.max(S.points, 3000) S.meter = 0 S.state, S.go = "idle", nil Fill() Say("Refilled.")
    end)
    reset:SetPoint("BOTTOMRIGHT", -14, 12)

    panel:EnableKeyboard(true)
    local KEYS = { RIGHT = true, UP = true }
    panel:SetScript("OnKeyDown", function(self, key)
        local mine = KEYS[key] or key == "S" or key == "ENTER"
        if not InCombatLockdown() then self:SetPropagateKeyboardInput(not mine) end
        if KEYS[key] then S.keys[key] = true
        elseif key == "S" then Smash()
        elseif key == "ENTER" then Insert() end
    end)
    panel:SetScript("OnKeyUp", function(_, key) if KEYS[key] then S.keys[key] = nil end end)
    panel:SetScript("OnUpdate", OnUpdate)
    Fill()
end

-- Opens it in the window's page area, like Plinko (dev characters only for now: Core.lua).
function ns.ShowClaw()
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
    Wake()
    Draw()
    if ns.UI.SetScreen then ns.UI.SetScreen("Claw", "CLAW", function() panel:Hide() end) end
end
