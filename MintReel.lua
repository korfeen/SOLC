-- The minting show: one spinning reel per layer, like opening a case. The result is already decided
-- and saved by ns.Mint (Minting.lua); each reel just scrolls a strip of random options past a marker,
-- slows down and lands on the rolled one, while the picture builds up layer by layer above it. It takes
-- over the main window's page area (UI.lua), opening the window if needed. A reroll plays it; a new mint plays the
-- minting pot's own show (MintPot.lua: the photo developing on its line, its layers dripped on), with a reel of its
-- own from ns.NewMintReel.

local _, ns = ...

-- Skin comes before eyes and expression, which are drawn in the skin's colour.
local REVEAL_ORDER = { "background", "skin", "outfit", "eyes", "expression", "headwear", "accessory" }
local TILE, GAP = 56, 6
local STEP = TILE + GAP
local STRIP_LENGTH = 40          -- tiles per reel
local WINNER_INDEX = 34          -- the rolled option sits here
local SPIN_TIME = 1.9            -- seconds per reel
local PAUSE_TIME = 0.45          -- after a reel lands
local REEL_WIDTH = 600
local PICTURE = 300

local SOUND_TICK = SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856
local SOUND_LAND = SOUNDKIT and SOUNDKIT.IG_QUEST_LOG_OPEN or 875
local SOUND_BIG = 888  -- level-up fanfare, for rare and better
local BIG_RARITIES = { rare = true, epic = true, legendary = true }

local function Play(sound) pcall(PlaySound, sound) end

local function LayerByKey(key)
    for _, layer in ipairs(ns.MintLayers) do
        if layer.key == key then return layer end
    end
end
ns.MintLayerByKey = LayerByKey

local function Weight(option)
    return option.weight or ns.MINT_WEIGHTS[option.rarity]
end

local function RandomOption(layer)  -- (only what you could roll: ns.MintAllowed)
    local total = 0
    for _, option in ipairs(layer.options) do if ns.MintAllowed(option) then total = total + Weight(option) end end
    local pick = math.random() * total
    for _, option in ipairs(layer.options) do
        if ns.MintAllowed(option) then
            pick = pick - Weight(option)
            if pick <= 0 then return option end
        end
    end
    return layer.options[1]
end

local RarityRGB = ns.RarityRGB

-- The layers in the order a show reveals them, then any layer the order doesn't mention: { layer key }.
function ns.MintRevealOrder()
    local order, listed = {}, {}
    for _, key in ipairs(REVEAL_ORDER) do
        if LayerByKey(key) then order[#order + 1] = key; listed[key] = true end
    end
    for _, layer in ipairs(ns.MintLayers) do
        if not listed[layer.key] then order[#order + 1] = layer.key end
    end
    return order
end

-- A reel ------------------------------------------------------------------------------------------------------------

-- Cropped art (a hat, a pet) is shown whole and centred, keeping its shape.
local function FillTile(tile, option, traits)
    local r, g, b = RarityRGB(option.rarity)
    tile.border:SetColorTexture(r, g, b, 0.9)
    tile.fill:SetVertexColor(1, 1, 1)
    tile.text:SetText("")
    tile.fill:ClearAllPoints()
    local inner = TILE - 6
    if option.rect then
        local aspect = option.rect[3] / option.rect[4]
        tile.fill:SetSize(aspect >= 1 and inner or inner * aspect, aspect >= 1 and inner / aspect or inner)
        tile.fill:SetPoint("CENTER")
    else
        tile.fill:SetPoint("TOPLEFT", 3, -3)
        tile.fill:SetPoint("BOTTOMRIGHT", -3, 3)
    end
    local texture = option.texture and ns.MintTexture(option, traits)
    if texture then
        tile.fill:SetTexture(texture)
        if option.color then tile.fill:SetVertexColor(unpack(option.color)) end
    elseif option.color then
        tile.fill:SetColorTexture(unpack(option.color))
    else
        tile.fill:SetColorTexture(0.1, 0.1, 0.1)
        tile.text:SetText("none")
    end
end

-- A reel (a clipped window a strip of tiles slides through, with a marker in the middle) on parent, width wide.
-- reel.frame is to be placed by its owner; reel:Spin(layer, winner, traits, onLand) scrolls it to the winner (onLand
-- when it stops), reel:Update(elapsed) drives it, reel:Stop() ends a spin at once.
function ns.NewMintReel(parent, width)
    local reel = {}
    local firstIndex = math.ceil(width / 2 / STEP) + 1  -- the strip starts with tiles across the whole reel
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetSize(width, TILE + 12)
    frame:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    frame:SetBackdropColor(0, 0, 0, 0.8)
    frame:SetClipsChildren(true)
    reel.frame = frame
    local strip = CreateFrame("Frame", nil, frame)
    strip:SetSize(STRIP_LENGTH * STEP, TILE)
    local marker = frame:CreateTexture(nil, "OVERLAY")
    marker:SetColorTexture(1, 0.82, 0, 0.9)
    marker:SetSize(2, TILE + 12)
    marker:SetPoint("CENTER")
    local tiles = {}
    local function GetTile(i)
        if tiles[i] then return tiles[i] end
        local tile = CreateFrame("Frame", nil, strip)
        tile:SetSize(TILE, TILE)
        tile:SetPoint("LEFT", (i - 1) * STEP, 0)
        tile.border = tile:CreateTexture(nil, "BACKGROUND")
        tile.border:SetAllPoints()
        tile.fill = tile:CreateTexture(nil, "ARTWORK")
        tile.text = tile:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        tile.text:SetPoint("CENTER")
        tiles[i] = tile
        return tile
    end
    -- Strip x so tile index (1-based) is centred on the marker, nudged by jitter (a fraction of a tile).
    local function OffsetFor(index, jitter) return width / 2 - ((index - 1) * STEP + TILE / 2 + jitter * TILE) end
    local spin

    function reel:Spin(layer, winner, traits, onLand)
        for i = 1, STRIP_LENGTH do
            FillTile(GetTile(i), i == WINNER_INDEX and winner or RandomOption(layer), traits)
        end
        -- (lands a bit off-centre, like the real thing)
        spin = { elapsed = 0, from = OffsetFor(firstIndex, 0), to = OffsetFor(WINNER_INDEX, (math.random() - 0.5) * 0.7), onLand = onLand }
        strip:ClearAllPoints()
        strip:SetPoint("LEFT", frame, "LEFT", spin.from, 0)
    end
    function reel:Update(elapsed)
        if not spin then return end
        spin.elapsed = spin.elapsed + elapsed
        local t = math.min(spin.elapsed / SPIN_TIME, 1)
        local eased = 1 - (1 - t) ^ 3  -- fast start, long slow-down
        local x = spin.from + (spin.to - spin.from) * eased
        strip:ClearAllPoints()
        strip:SetPoint("LEFT", frame, "LEFT", x, 0)
        local under = math.floor((width / 2 - x) / STEP)  -- the tile under the marker
        if under ~= spin.lastTile then
            spin.lastTile = under
            Play(SOUND_TICK)
        end
        if t >= 1 then
            local onLand = spin.onLand
            spin = nil
            if onLand then onLand() end
        end
    end
    function reel:Stop() spin = nil end
    function reel:IsSpinning() return spin ~= nil end
    return reel
end

-- The show's panel ------------------------------------------------------------------------------------------------

-- Placed over the main window's page area when a show starts (the window is made later than this file).
local panel = CreateFrame("Frame", "SOLCMintReel", UIParent, "BackdropTemplate")
panel:SetBackdrop({
    bgFile = ns.WINDOW_BACKGROUND,  -- solid (the dialog texture is see-through)
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 32, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
panel:SetBackdropColor(unpack(ns.WINDOW_COLOR))
panel:EnableMouse(true)
panel:Hide()
panel:HookScript("OnHide", function() if ns.UI.ClearScreen then ns.UI.ClearScreen("Minting") end end)

panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
panel.title:SetPoint("TOP", 0, -16)
panel.canvas = CreateFrame("Frame", nil, panel)
panel.canvas:SetSize(PICTURE, PICTURE)
panel.canvas:SetPoint("TOP", 0, -42)

panel.status = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
panel.status:SetPoint("TOP", panel.canvas, "BOTTOM", 0, -8)

local reel = ns.NewMintReel(panel, REEL_WIDTH)
reel.frame:SetPoint("TOP", panel.status, "BOTTOM", 0, -8)

panel.result = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
panel.result:SetPoint("TOP", reel.frame, "BOTTOM", 0, -8)
panel.hint = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
panel.hint:SetPoint("BOTTOM", 0, 16)

-- Show ----------------------------------------------------------------------------

local show  -- { mint, step, order, pause (seconds left after a reel lands), revealed = { traits so far } }

local function Land()
    local option, rarity = show.winner, show.winner.rarity
    show.revealed[show.layer.key] = option.id
    ns.RenderMint(panel.canvas, show.revealed)
    panel.result:SetText(("|c%s%s|r"):format(ns.RARITY_COLORS[rarity] or "ffffffff", option.name))
    Play(BIG_RARITIES[rarity] and SOUND_BIG or SOUND_LAND)
    show.pause = PAUSE_TIME
end

local function StartStep()
    local key = show.order[show.step]
    local layer = LayerByKey(key)
    local winner
    for _, option in ipairs(layer.options) do
        if option.id == show.mint.traits[key] then winner = option end
    end
    show.layer, show.winner, show.pause = layer, winner, nil
    reel:Spin(layer, winner, show.mint.traits, Land)
    panel.status:SetText(("Rolling: %s"):format(layer.name))
    panel.result:SetText("")
end

local function Finish()
    local mint = show.mint
    show = nil
    reel:Stop()
    panel:SetScript("OnUpdate", nil)
    local rarity = ns.MintRarity(mint.traits)
    local big = rarity == "legendary" or rarity == "epic"
    ns.ShowToast(big and "achievement" or "record", "Minted!", ("Picture #%d"):format(mint.number),
        (rarity:gsub("^%l", string.upper)))
    panel.title:SetText(("Picture #%d - |c%s%s|r"):format(mint.number, ns.RARITY_COLORS[rarity], (rarity:gsub("^%l", string.upper))))
    panel.status:SetText("")
    panel.hint:SetText("Click to close")
    if ns.OnKillsChanged then ns.OnKillsChanged() end
end

local function OnUpdate(_, elapsed)
    reel:Update(elapsed)
    if show and show.pause then
        show.pause = show.pause - elapsed
        if show.pause <= 0 then
            show.step = show.step + 1
            if show.order[show.step] then StartStep() else Finish() end
        end
    end
end

-- Skip: reveal everything at once. When the show is over, a click closes the panel.
panel:SetScript("OnMouseDown", function()
    if not show then
        panel:Hide()
        return
    end
    show.revealed = show.mint.traits
    ns.RenderMint(panel.canvas, show.revealed)
    Finish()
end)

function ns.PlayMintReel(mint)
    show = { mint = mint, step = 1, revealed = {}, order = ns.MintRevealOrder() }
    -- Over the main window's pages, covering them (the sidebar stays usable).
    local pageArea = ns.UI and ns.UI.pageArea
    if pageArea then
        if not pageArea:IsVisible() then ns.ToggleUI() end
        panel:SetParent(pageArea)
        panel:ClearAllPoints()
        panel:SetAllPoints(pageArea)
        panel:SetFrameStrata(pageArea:GetFrameStrata())
        panel:SetFrameLevel(pageArea:GetFrameLevel() + 50)
    else
        panel:ClearAllPoints()
        panel:SetSize(REEL_WIDTH + 40, PICTURE + 220)
        panel:SetPoint("CENTER")
        panel:SetFrameStrata("DIALOG")
    end
    ns.RenderMint(panel.canvas, show.revealed)
    panel.title:SetText("Minting...")
    panel.hint:SetText("Click to skip")
    panel:Show()
    if ns.UI.SetScreen then ns.UI.SetScreen("Minting", "SPIN", function() panel:Hide() end) end  -- (the top beam's title)
    StartStep()
    panel:SetScript("OnUpdate", OnUpdate)
end
