-- The public interface for sister addons (SOLC Puzzle): the global SOLC table. Kept small and stable so
-- they don't depend on SOLC's internals; API_VERSION goes up whenever something here changes.

local _, ns = ...

SOLC = {
    API_VERSION = 1,
    UI = ns.UI,  -- page size and widgets: PAGE_WIDTH, PAGE_HEIGHT, CreateHeader, CreateSection, CreateRow...
}

-- Your name as guildmates see it, and chat output in SOLC's style.
function SOLC.MyName() return ns.MyName() end
function SOLC.Print(text) ns.Print(text) end

-- True for a guild officer or guild master.
function SOLC.IsOfficer() return IsInGuild() and ns.CanEditConfig() end

-- Synced guildmates (and your other characters): { { key, name } }, sorted by name.
function SOLC.GetPlayers()
    local list = {}
    for _, friend in ipairs(ns.GetFriends()) do list[#list + 1] = { key = friend.key, name = friend.name } end
    return list
end

-- Your pictures (key nil) or a synced player's: { { number, traits, time, rarity } }, newest first.
function SOLC.GetPictures(key)
    local pictures = {}
    local function Add(mint)
        pictures[#pictures + 1] = { number = mint.number, traits = mint.traits, time = mint.time,
            rarity = ns.MintRarity(mint.traits) }
    end
    if key then
        local friend = KillTrackerFriends[key]
        for _, mint in pairs(friend and friend.mints or {}) do Add(mint) end
    else
        for _, mint in ipairs(KillTrackerDB.mints or {}) do Add(mint) end
    end
    table.sort(pictures, function(a, b) return a.time > b.time end)
    return pictures
end

-- Drawing and describing pictures.
function SOLC.RenderPicture(frame, traits) ns.RenderMint(frame, traits) end
function SOLC.PictureRarity(traits) return ns.MintRarity(traits) end
function SOLC.RarityColor(rarity) return ns.RarityRGB(rarity) end           -- r, g, b
function SOLC.RarityName(rarity) return (rarity:gsub("^%l", string.upper)) end
function SOLC.RarityText(rarity)                                            -- "Rare" in its color
    return ("|c%s%s|r"):format(ns.RARITY_COLORS[rarity] or "ffffffff", SOLC.RarityName(rarity))
end
function SOLC.PictureTraits(traits) return ns.MintTraits(traits) end       -- { { layer, option, rarity } }
function SOLC.PictureLayers(traits) return ns.MintDrawOrder(traits) end    -- { { key, id, perSkin } }, back to front

-- Traits as short text for addon messages and back: option IDs in layer order, "spa_steam_room;mud_brown;...".
-- Under 255 characters with room to spare.
function SOLC.TraitsToText(traits)
    local ids = {}
    for i, layer in ipairs(ns.MintLayers) do ids[i] = traits[layer.key] or "" end
    return table.concat(ids, ";")
end
function SOLC.TextToTraits(text)
    local traits, i = {}, 0
    for id in (text .. ";"):gmatch("([^;]*);") do
        i = i + 1
        local layer = ns.MintLayers[i]
        if layer and id ~= "" then traits[layer.key] = id end
    end
    return traits
end

-- Handing pictures over after a race. GivePicture removes one of yours (returns its traits); the winner's
-- addon calls ReceivePicture with those traits. Both sync to the guild.
function SOLC.GivePicture(number) return ns.RemoveMint(number) end
function SOLC.ReceivePicture(traits, from, mintedAt) return ns.AddWonMint(traits, from, mintedAt) end

-- Mint battles: rolls a picture nobody owns and charges you the mint cost. Returns traits, or nil and why.
function SOLC.MintCost() return ns.MintCost() end
function SOLC.MintForBattle()
    local db = KillTrackerDB
    local balance, cost = ns.GetPoints().balance, ns.MintCost()
    if balance < cost then return nil, ("Not enough points (%d of %d)."):format(balance, cost) end
    local traits = ns.RollFreePicture()
    if not traits then return nil, "Every possible picture is already taken." end
    db.points.spent = db.points.spent + cost
    if ns.OnKillsChanged then ns.OnKillsChanged() end
    return traits
end

-- A page in SOLC's sidebar: { key, label, section = "me" | "guild", order, create(parent) -> frame,
-- refresh(frame), tabOf = "<page key>" (optional: a tab of that page instead of a sidebar button) }. Register
-- while loading, before the window is first opened.
function SOLC.RegisterPage(page) ns.RegisterPage(page) end
function SOLC.OpenPage(key) ns.OpenPage(key) end

-- Extra rows in your Collection page: provider() returns { { label, right (text on the right),
-- onClick(), onEnter(row) (show a tooltip) } }, asked for each time the page is drawn.
function SOLC.AddCollectionRows(provider) table.insert(ns.CollectionProviders, provider) end

-- Redraws the SOLC window (after something a sister addon shows there changed).
function SOLC.Refresh() if ns.OnKillsChanged then ns.OnKillsChanged() end end
