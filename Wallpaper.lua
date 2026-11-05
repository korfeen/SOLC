-- Wallpapers: old-school repeating papers (tools/gen-wallpaper.js; their textures in Media/Wallpaper, their shapes in
-- WallpaperData.lua) behind your photo and showcase on ME, under your inventory and the guild pages' lists, each with its
-- border (a strip repeating sideways) for a divider. You pick yours in EDIT (OverviewCard.lua, ME's Wallpaper tab); it's
-- synced (the card's wallpaper), so guildmates see it behind your photo too.
-- Getting them: Club Stripes is everyone's; one comes with an Ogre Rank (rank: Ranks.lua's wallpaper perk); the rest are
-- bought for points (price; placeholders like the Pro Shop's), counted as Pro Shop spending. Bought ones:
-- KillTrackerDB.wallpapers = { [id] = time }. Dev characters have them all.

local _, ns = ...
local UI = ns.UI

local PATH = "Interface\\AddOns\\SOLC\\Media\\Wallpaper\\"
-- In the order EDIT lists them; the first is everyone's to start with.
ns.WALLPAPER_LIST = {
    { id = "walnut", name = "Club Walnut" },  -- (the first: everyone's, the default)
    { id = "stripes", name = "Club Stripes" },  -- (free, the default before Club Walnut)
    { id = "loops", name = "Loops", price = 100 },
    { id = "ogee", name = "Teardrops", price = 150 },
    { id = "floral_yellow", name = "Sunny Flowers", price = 250 },
    { id = "floral_orange", name = "Orange Flowers", price = 250 },
    { id = "fruit", name = "Fruit Bowl", price = 400 },
    { id = "blocks", name = "Blue Blocks", rank = 22 },
}
local DEFAULT = ns.WALLPAPER_LIST[1].id
local BY_ID = {}
for _, paper in ipairs(ns.WALLPAPER_LIST) do BY_ID[paper.id] = paper end

-- Whether you have it, and if not, how to get it.
function ns.WallpaperUnlocked(paper)
    if not paper.price and not paper.rank then return true end
    if ns.IsDev and ns.IsDev() and not paper.price then return true end  -- (dev characters: all but the shop's, to test buying)
    if paper.rank then
        if ns.GetRank and ns.GetRank().rank >= paper.rank then return true end
        return false, ("Ogre Rank %d"):format(paper.rank)
    end
    if KillTrackerDB.wallpapers and KillTrackerDB.wallpapers[paper.id] then return true end
    return false, ("Pro Shop, %d points"):format(paper.price)
end

-- Buys one (its price in points). Returns true, or false and why not.
function ns.BuyWallpaper(id)
    local paper = BY_ID[id]
    if not (paper and paper.price) then return false, "That one isn't for sale." end
    if ns.WallpaperUnlocked(paper) then return false, "You have it already." end
    if ns.RankLocked and ns.RankLocked("proshop") then return false, "The Pro Shop isn't open to you yet." end
    local balance = ns.GetPoints().balance
    if balance < paper.price then return false, ("Not enough points (%d of %d)."):format(balance, paper.price) end
    local db = KillTrackerDB
    db.points.spent = db.points.spent + paper.price
    db.shop = db.shop or { spent = 0, bought = {} }
    db.shop.spent = db.shop.spent + paper.price
    db.shop.bought["wallpaper:" .. id] = time()
    db.wallpapers = db.wallpapers or {}
    db.wallpapers[id] = time()
    if ns.CheckAchievements then ns.CheckAchievements() end  -- (the Pro Shop spending deeds count it)
    return true
end
StaticPopupDialogs["SOLC_BUY_WALLPAPER"] = {
    text = "Buy the %s wallpaper for %d points?",
    button1 = YES or "Yes",
    button2 = NO or "No",
    OnAccept = function(_, data)
        local bought, reason = ns.BuyWallpaper(data.id)
        if not bought then return ns.Print(reason) end
        if data.after then data.after() end
        if ns.OnKillsChanged then ns.OnKillsChanged() end  -- (the points shown)
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}
function ns.ConfirmBuyWallpaper(id, after)
    local paper = BY_ID[id]
    if paper and paper.price then StaticPopup_Show("SOLC_BUY_WALLPAPER", paper.name, paper.price, { id = id, after = after }) end
end

-- How they show (window pixels; the dev menu's PAPER tab tunes them, kept in SOLCAccount.wallpaperTune): a repeat's
-- height behind your hanging picture (page), behind the photo (photo) and in the inventory (inventory); how much the
-- page's and the inventory's are darkened (0..1); the border's height.
ns.WALLPAPER_TUNE = {
    { key = "page", name = "Behind the picture: repeat height", default = 180, step = 5, min = 40, max = 600 },
    { key = "pageDim", name = "Behind the picture: darken", default = 0, step = 0.05, min = 0, max = 0.9 },
    { key = "photo", name = "Behind the photo: repeat height", default = 165, step = 5, min = 40, max = 600 },
    { key = "inventory", name = "Inventory: repeat height", default = 130, step = 5, min = 40, max = 600 },
    { key = "dim", name = "Inventory: darken", default = 0.45, step = 0.05, min = 0, max = 0.9 },
    { key = "guildDim", name = "Guild pages: darken", default = 0.75, step = 0.05, min = 0, max = 0.95 },
    { key = "plateLight", name = "Podium plates: brightness", default = 0.3, step = 0.02, min = 0, max = 0.8 },
    { key = "guildPattern", name = "Guild border: 0 plain, 1 patterned", default = 0, step = 1, min = 0, max = 1 },
    { key = "guildBorder", name = "Guild border: height", default = 22, step = 1, min = 4, max = 64 },
    { key = "guildBorderDim", name = "Guild border: darken", default = 0.35, step = 0.05, min = 0, max = 0.9 },
    { key = "border", name = "Inventory border: height", default = 22, step = 1, min = 6, max = 64 },
    { key = "invPattern", name = "Inventory border: 0 plain, 1 patterned", default = 1, step = 1, min = 0, max = 1 },
    { key = "borderDim", name = "Inventory border: darken", default = 0, step = 0.05, min = 0, max = 0.9 },
}
local TUNE = {}
for _, spec in ipairs(ns.WALLPAPER_TUNE) do TUNE[spec.key] = spec end
function ns.WallpaperTune(key)
    local tuned = SOLCAccount and SOLCAccount.wallpaperTune
    return tuned and tuned[key] or TUNE[key].default
end
function ns.SetWallpaperTune(key, value)
    SOLCAccount.wallpaperTune = SOLCAccount.wallpaperTune or {}
    SOLCAccount.wallpaperTune[key] = value ~= TUNE[key].default and value or nil
    ns.RefreshWallpapers()
    if UI.RefreshPlates then UI.RefreshPlates() end
    if ns.OnKillsChanged then ns.OnKillsChanged() end
end

-- Someone's wallpaper (key nil: yours, if you still have it): theirs if it's one we have, else the first.
function ns.GetWallpaper(key)
    local card = key and KillTrackerFriends[key] and KillTrackerFriends[key].card or not key and KillTrackerDB.card
    local id = card and card.wallpaper
    if not (id and BY_ID[id] and ns.WALLPAPERS and ns.WALLPAPERS[id]) then return DEFAULT end
    if not key and not ns.WallpaperUnlocked(BY_ID[id]) then return DEFAULT end
    return id
end
ns.WALLPAPER_DEFAULT = DEFAULT

function ns.SetWallpaper(id)
    KillTrackerDB.card = KillTrackerDB.card or {}
    KillTrackerDB.card.wallpaper = id ~= DEFAULT and id or nil
    ns.Touch(KillTrackerDB.card)
    ns.RefreshWallpapers()
    if ns.OnKillsChanged then ns.OnKillsChanged() end
end

-- Fills texture (w x h window pixels) with wallpaper id repeating, a repeat tileH tall (at its true shape). ox, oy:
-- where its top-left is in the paper (window pixels; default 0, 0) - to carry on from another piece of it.
function UI.SetWallpaper(texture, id, w, h, tileH, ox, oy)
    local shape = ns.WALLPAPERS and ns.WALLPAPERS[id]
    if not shape then return texture:Hide() end
    local tileW, x, y = tileH * shape.aspect, ox or 0, oy or 0
    texture:SetTexture(PATH .. id, "REPEAT", "REPEAT")
    texture:SetTexCoord(x / tileW, (x + w) / tileW, y / tileH, (y + h) / tileH)
    texture:Show()
end

-- Your wallpaper over a grey board (a texture sized in window pixels: the guild pages' empty lists), as dark as the
-- inventory's; kept up to date when you pick another or tune them. Returns it (:SetShown with its board).
local overBoards = {}
local PLAIN = { 0.07, 0.14, 0.58, 0.14, 0.07 }  -- (a plain border's strips, top to bottom: UI.PlainBorderIn)
local function PaperBoard(piece)
    if piece.plain then  -- (the guild pages' border: plain - five strips in the wallpaper's three colours - or its
        -- patterned one (guildPattern), darkened either way)
        local shape = ns.WALLPAPERS and ns.WALLPAPERS[ns.GetWallpaper()]
        local keys = piece.keys
        local colours, k = shape and shape.plain, 1 - ns.WallpaperTune(keys.dim)
        local h, top = ns.WallpaperTune(keys.height), 0
        local patterned = ns.WallpaperTune(keys.pattern) == 1
        piece.frame:SetHeight(h)
        piece.pattern:SetShown(patterned)
        if patterned then
            UI.SetWallpaperBorder(piece.pattern, ns.GetWallpaper(), piece.frame:GetWidth(), h)
            piece.pattern:SetVertexColor(k, k, k)
        end
        for i, strip in ipairs(piece.plain) do
            strip:SetShown(not patterned)
            strip:ClearAllPoints()
            strip:SetPoint("TOPLEFT", 0, -top * h)
            strip:SetPoint("TOPRIGHT", 0, -top * h)
            strip:SetHeight(PLAIN[i] * h)
            top = top + PLAIN[i]
            local c = colours and colours[({ 1, 2, 3, 2, 1 })[i]] or { 0.2, 0.2, 0.2 }
            strip:SetColorTexture(c[1] * k, c[2] * k, c[3] * k)
        end
        return
    end
    if piece.border then return UI.SetWallpaperBorder(piece.border, ns.GetWallpaper(), piece.w, piece.h) end
    UI.SetWallpaper(piece.paper, ns.GetWallpaper(), piece.w, piece.h, ns.WallpaperTune("inventory"))
    piece.dim:SetColorTexture(0, 0, 0, ns.WallpaperTune("guildDim"))
end
-- (the guild pages' boards: their empty lists, the toplist's - much darker than the inventory, behind lists)
function UI.WallpaperOver(board)
    local parent = board:GetParent()
    local piece = { paper = parent:CreateTexture(nil, "BACKGROUND", nil, -7), dim = parent:CreateTexture(nil, "BACKGROUND", nil, -6),
        w = board:GetWidth(), h = board:GetHeight() }
    piece.paper:SetAllPoints(board)
    piece.dim:SetAllPoints(board)
    function piece:SetShown(shown) self.paper:SetShown(shown) self.dim:SetShown(shown) end
    overBoards[#overBoards + 1] = piece
    PaperBoard(piece)
    return piece
end
-- Your wallpaper's border on a texture (w x h window pixels: a divider), kept up to date like the boards.
function UI.WallpaperBorderOn(texture, w, h)
    local piece = { border = texture, w = w, h = h }
    overBoards[#overBoards + 1] = piece
    PaperBoard(piece)
    return piece
end
-- A PLAIN border in frame (filling it): a band in three of the wallpaper's colours (tools/plain-borders.js), a dark
-- edge, its main colour, a light middle, mirrored (heights 7 | 14 | 58 | 14 | 7 of a hundred) - quieter than its
-- patterned one, for the guild pages.
-- Its height, style and darkening: the PAPER tab's (keys = { height, pattern, dim }: the guild pages' by default; the
-- frame resized to its height, from its top).
local GUILD_KEYS = { height = "guildBorder", pattern = "guildPattern", dim = "guildBorderDim" }
function UI.PlainBorderIn(frame, keys)
    local strips = {}
    for i in ipairs(PLAIN) do strips[i] = frame:CreateTexture(nil, "ARTWORK") end
    local pattern = frame:CreateTexture(nil, "ARTWORK")
    pattern:SetAllPoints()
    local piece = { plain = strips, frame = frame, pattern = pattern, keys = keys or GUILD_KEYS }
    overBoards[#overBoards + 1] = piece
    PaperBoard(piece)
    return piece
end
function ns.RefreshWallpapers() for _, piece in ipairs(overBoards) do PaperBoard(piece) end end

-- The same for its border: a strip w wide and h tall, repeating sideways.
function UI.SetWallpaperBorder(texture, id, w, h)
    local shape = ns.WALLPAPERS and ns.WALLPAPERS[id]
    if not (shape and shape.border) then return texture:Hide() end
    texture:SetTexture(PATH .. id .. "_Border", "REPEAT", "CLAMP")
    texture:SetTexCoord(0, w / (h * shape.border), 0, 1)
    texture:Show()
end
