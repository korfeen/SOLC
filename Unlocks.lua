-- Unlocks: picture layers you can only roll once you've earned them (MintArt.lua options with an unlock key; see
-- Minting.lua's ns.MintAllowed). Each option is unlocked on its own: KillTrackerDB.unlocks = { [layer:id] = time }
-- (ns.OptionKey). Unlocking makes it rollable; getting it into a picture is the mint's luck. Where they come from, by
-- their option's unlock key:
--   clear:<dungeon>         a dungeon's pieces (the dungeon keys in Achievements.lua): its backdrop, its end boss as a
--                           skin, the end boss's gear; out of the dungeon's chests, one item at a time
--   chase:<dungeon>:<name>  a chase item: in the dungeon's chests by luck (its option's dropChance, CHASE_CHANCE),
--                           likelier in a better chest
--   loot:<item>             looting that epic item (its name in lower case, letters and digits only)
--   (a chase, combined or loot piece also unlocks by wearing that item: equipping the real Ironfoe, on this character)
--   deed:<achievement id>   earning that achievement, e.g. "deed:subtype:Murloc:100": a creature's hat and onesie
--                           (make-unlock-art.js's creatures; worn together they're one hooded onesie, Minting.lua)
-- Chests: each clear (its end boss down, Guild.lua) finds the dungeon's chest by chance: the guild's chestChance (25%)
-- for you and as much again for each guildmate with you. A chest rolls its quality as it's found (ns.CHEST_TIERS:
-- common to legendary), which is how many items are in it; the first chest of a dungeon you've had nothing from is at
-- least rare (two items). Each item is one of the dungeon's pieces you don't have yet, or a chase item, or once there's
-- nothing left for you, more of the dungeon's tokens; and every chest has its coins and tokens besides (the guild's chestCoins, more for the
-- higher dungeons and for better chests). KillTrackerDB.chests = { { dungeon, time, tier } }: kept, as many as you
-- find, until you open them (Chests.lua, the PIX page's tiles); KillTrackerDB.points.chests = the coins from them.
-- An unlock goes in your feed (event U, a = its option key). The first check ever (data from before unlocks,
-- Achievements.lua after counting your kills) gives a chest of each dungeon you've already cleared.

local _, ns = ...

local CHASE_CHANCE = 0.1  -- a chase item's chance per item slot, unless its option says (dropChance)
-- A chest's quality: its chance as it's found, how many items are in it, its coins' multiplier, its chase items', how many
-- of its dungeon's tokens it has (and an item slot with nothing new left for you holds as many again).
ns.CHEST_TIERS = {
    { key = "common", name = "Common", chance = 0.60, items = 1, coins = 1, chase = 1, tokens = 1 },
    { key = "rare", name = "Rare", chance = 0.25, items = 2, coins = 2, chase = 1.5, tokens = 2, fuel = "frostwood" },
    { key = "epic", name = "Epic", chance = 0.12, items = 3, coins = 4, chase = 2, tokens = 3, fuel = "shimmer" },
    { key = "legendary", name = "Legendary", chance = 0.03, items = 4, coins = 10, chase = 3, tokens = 5, fuel = "sunwood" },
}
local TIERS = ns.CHEST_TIERS
local FIRST_TIER = 2  -- the first chest of a dungeon: at least rare
-- The dungeon's own part of the coins: the guild's chestCoins times this for its tier (its backdrop's rarity).
local DUNGEON_COINS = { uncommon = 1, rare = 1.5, epic = 2, legendary = 3 }
local issecret = issecretvalue or function() return false end

-- The chance a clear finds its dungeon's chest, with this many guildmates in your group.
function ns.ClearUnlockChance(guildmates) return math.min(1, ns.Config("chestChance") / 100 * (1 + (guildmates or 0))) end

-- An option's key in your unlocks ("skin:boss_dm").
function ns.OptionKey(layerKey, option) return layerKey .. ":" .. option.id end

-- The options in a pool (an unlock key: "clear:dm", "chase:dm:...", "loot:..."): { { layer, option } }.
function ns.UnlockOptions(pool)
    local list = {}
    for _, layer in ipairs(ns.MintLayers) do
        for _, option in ipairs(layer.options) do
            if option.unlock == pool then list[#list + 1] = { layer = layer, option = option } end
        end
    end
    return list
end
-- An option by its key ("skin:boss_dm"): { layer, option }, or nil.
function ns.OptionByKey(key)
    local layerKey, id = tostring(key):match("^(%w+):(.+)$")
    for _, layer in ipairs(ns.MintLayers) do
        if layer.key == layerKey then
            for _, option in ipairs(layer.options) do
                if option.id == id then return { layer = layer, option = option } end
            end
        end
    end
end

function ns.IsUnlocked(key)
    local unlocks = KillTrackerDB and KillTrackerDB.unlocks
    return unlocks ~= nil and unlocks[key] ~= nil
end
-- How many of a pool's options you have, and how many it has.
function ns.PoolProgress(pool)
    local have, all = 0, 0
    for _, unlocked in ipairs(ns.UnlockOptions(pool)) do
        all = all + 1
        if ns.IsUnlocked(ns.OptionKey(unlocked.layer.key, unlocked.option)) then have = have + 1 end
    end
    return have, all
end

-- Unlocks one option (its key); quiet: no feed event. Returns true if it's new.
function ns.UnlockOption(key, quiet)
    local db = KillTrackerDB
    db.unlocks = db.unlocks or {}
    if db.unlocks[key] or not ns.OptionByKey(key) then return false end
    db.unlocks[key] = time()
    if not quiet and ns.AddEvent then ns.AddEvent("U", key) end
    return true
end
-- Unlocks a whole pool (dev mode; looted epics). Returns how many were new.
function ns.UnlockPool(pool, quiet)
    local new = 0
    for _, unlocked in ipairs(ns.UnlockOptions(pool)) do
        if ns.UnlockOption(ns.OptionKey(unlocked.layer.key, unlocked.option), quiet) then new = new + 1 end
    end
    return new
end

-- A chest's tier for a dungeon, rolled as it's found; the first of a dungeon you've had nothing from: at least rare.
local function RollTier(dungeonKey)
    local pick, tier = math.random(), 1
    for i, t in ipairs(TIERS) do
        if pick < t.chance then tier = i break end
        pick = pick - t.chance
    end
    local have = ns.PoolProgress("clear:" .. dungeonKey)
    local pending = false
    for _, chest in ipairs(KillTrackerDB.chests or {}) do
        if chest.dungeon == dungeonKey then pending = true end
    end
    if have == 0 and not pending then tier = math.max(tier, FIRST_TIER) end
    return tier
end
-- Adds a chest of a dungeon (a clear's, a gift's): its tier given, or rolled. Returns the tier.
function ns.AddChest(dungeonKey, tier)
    local db = KillTrackerDB
    db.chests = db.chests or {}
    tier = tier or RollTier(dungeonKey)
    db.chests[#db.chests + 1] = { dungeon = dungeonKey, time = time(), tier = tier }
    return tier
end

-- A dungeon's end boss down (Guild.lua; d: its entry in Achievements.lua), with this many guildmates in your group.
function ns.OnDungeonClear(d, guildmates)
    local chance = ns.ClearUnlockChance(guildmates)
    if math.random() < chance then
        ns.AddChest(d.key)
        ns.ShowToast("achievement", "You found a chest!", d.name .. " chest", "Open it on your PIX page, whenever you like")
        ns.Print(("You found the |cffffd100%s chest|r - open it on your PIX page."):format(d.name))
        if ns.OnKillsChanged then ns.OnKillsChanged() end
    else
        ns.Print(("No chest from %s this time (%d%% with %d guildmate%s; more guildmates, better odds)."):format(
            d.name, math.floor(chance * 100 + 0.5), guildmates, guildmates == 1 and "" or "s"))
    end
end

-- Your unopened chests by dungeon: { [dungeon key] = how many }, and the dungeons in the order first found.
function ns.ChestCounts()
    local counts, order = {}, {}
    for _, chest in ipairs(KillTrackerDB.chests or {}) do
        if not counts[chest.dungeon] then order[#order + 1] = chest.dungeon end
        counts[chest.dungeon] = (counts[chest.dungeon] or 0) + 1
    end
    return counts, order
end

-- What a dungeon's chest can hold: its pieces and its chase items, { { layer, option } }.
function ns.ChestPool(dungeonKey)
    local list = ns.UnlockOptions("clear:" .. dungeonKey)
    local prefix = "chase:" .. dungeonKey .. ":"
    for _, layer in ipairs(ns.MintLayers) do
        for _, option in ipairs(layer.options) do
            if option.unlock and option.unlock:sub(1, #prefix) == prefix then list[#list + 1] = { layer = layer, option = option } end
        end
    end
    return list
end

-- Each dungeon's tier (make-unlock-art.js's DUNGEONS; it was its backdrop's rarity, before the crayon backdrops were
-- retired): the levelling ones uncommon, then rare, the high-level ones epic, the raids legendary.
local DUNGEON_RARITY = {}
for rarity, keys in pairs({
    uncommon = { "rfc", "wc", "dm", "sfk", "bfd", "stocks", "gnomer", "rfk" },
    rare = { "smgy", "smlib", "smarm", "smcath", "rfd", "ulda", "zf", "mara", "thanes", "ruins", "excav" },
    epic = { "st", "brd", "lbrs", "ubrs", "dme", "dmw", "dmn", "scholo", "stratl", "stratu" },
    legendary = { "ony", "barrow", "hyjal" },
}) do
    for _, key in ipairs(keys) do DUNGEON_RARITY[key] = rarity end
end
function ns.DungeonRarity(key) return DUNGEON_RARITY[key] or "uncommon" end

-- The coins for a dungeon's chest of a tier: the dungeon's part times the chest's, times 50%..150%.
local function Coins(dungeonKey, tier)
    local dungeonTier = DUNGEON_COINS[ns.DungeonRarity(dungeonKey)] or 1
    return math.floor(ns.Config("chestCoins") * dungeonTier * (TIERS[tier] or TIERS[1]).coins * (0.5 + math.random()) + 0.5)
end

-- Opens one of your chests of a dungeon. Returns its tier, its coins, its items ({ { kind = "unlock", layer, option } or
-- { kind = "tokens", dungeon, count } }), its tokens (all of them, those items' too) and its fuel's key
-- (one of it: rare chests and up, ns.FUELS); nil if you have no chest of
-- it. It's all yours by the time it returns.
function ns.OpenChest(dungeonKey)
    local db = KillTrackerDB
    local chest
    for i, c in ipairs(db.chests or {}) do
        if c.dungeon == dungeonKey then chest = table.remove(db.chests, i) break end
    end
    if not chest then return nil end
    local tier = chest.tier or 1
    local spec = TIERS[tier] or TIERS[1]
    local items, coins, tokens = {}, Coins(dungeonKey, tier), spec.tokens
    local function Locked(list)
        local out = {}
        for _, unlocked in ipairs(list) do
            if not ns.IsUnlocked(ns.OptionKey(unlocked.layer.key, unlocked.option)) then out[#out + 1] = unlocked end
        end
        return out
    end
    for _ = 1, spec.items do
        -- A chase item, by its luck; else one of the dungeon's pieces you don't have; else a bag of coins.
        local got
        for _, unlocked in ipairs(Locked(ns.ChestPool(dungeonKey))) do
            local option = unlocked.option
            if option.unlock ~= "clear:" .. dungeonKey and math.random() < (option.dropChance or CHASE_CHANCE) * spec.chase then
                got = unlocked
                break
            end
        end
        if not got then
            local pieces = Locked(ns.UnlockOptions("clear:" .. dungeonKey))
            got = #pieces > 0 and pieces[math.random(#pieces)] or nil
        end
        if got then
            ns.UnlockOption(ns.OptionKey(got.layer.key, got.option))
            items[#items + 1] = { kind = "unlock", layer = got.layer, option = got.option }
        else  -- nothing new left in it for you: the dungeon's tokens
            tokens = tokens + spec.tokens
            items[#items + 1] = { kind = "tokens", dungeon = dungeonKey, count = spec.tokens }
        end
    end
    db.tokens = db.tokens or {}
    db.tokens[dungeonKey] = (db.tokens[dungeonKey] or 0) + tokens
    if spec.fuel then db.tokens[spec.fuel] = (db.tokens[spec.fuel] or 0) + 1 end
    db.points.chests = (db.points.chests or 0) + coins
    ns.Touch(db.points)
    if ns.OnKillsChanged then ns.OnKillsChanged() end
    if ns.CheckRank then ns.CheckRank() end  -- the coins count towards your Ogre Rank
    return tier, coins, items, tokens, spec.fuel
end

-- After the achievements count your kills (clears per dungeon: { [dungeon key] = clears }): the first time ever, each
-- dungeon already cleared gives its chest. (Unlocks from the test builds, a whole dungeon at a time, become its pieces.)
function ns.CheckUnlocks(clears)
    local db = KillTrackerDB
    if not db or not clears then return end
    -- (deeds earned before their pieces were made: theirs now, quietly)
    local earned = db.achievements or {}
    for _, layer in ipairs(ns.MintLayers) do
        for _, option in ipairs(layer.options) do
            local deed = option.unlock and option.unlock:match("^deed:(.+)$")
            if deed and earned[deed] then ns.UnlockOption(ns.OptionKey(layer.key, option), true) end
        end
    end
    for key in pairs(db.unlocks or {}) do
        if key:match("^clear:") then
            db.unlocks[key] = nil
            ns.UnlockPool(key, true)
        end
    end
    if db.unlocksCaughtUp then return end
    db.unlocksCaughtUp = true
    local found = 0
    for key, count in pairs(clears) do
        if count > 0 then
            ns.AddChest(key)
            found = found + 1
        end
    end
    if found > 0 then
        ns.Print(("You have |cffffd100%d chest%s|r from the dungeons you've cleared - open them on your PIX page."):format(found, found == 1 and "" or "s"))
    end
end

-- Dungeon tokens: from a dungeon's chests (KillTrackerDB.tokens = { [dungeon key] = how many }). Thrown into the minting
-- pot (Minting.lua) they make a mint likelier to roll that dungeon's pieces; or TOKEN_SHOP_PRICE of them buys one of its
-- pieces you're missing (MintPot.lua).
ns.TOKEN_SHOP_PRICE = 15
-- Each dungeon's tokens are an ingredient for the pot (their icons: Media/Icons/Ingredients/<KEY>, tools/make-kitchen-art.js).
ns.INGREDIENTS = {
    rfc = "Searing Embers",
    wc = "Fang Venom",
    dm = "Defias Doubloons",
    sfk = "Worgen Fur",
    bfd = "Twilight Pearls",
    stocks = "Prison Keys",
    gnomer = "Irradiated Cogs",
    rfk = "Bramble Thorns",
    smgy = "Grave Dirt",
    smlib = "Scarlet Scrolls",
    smarm = "Scarlet Ingots",
    smcath = "Holy Candles",
    rfd = "Frost Bones",
    ulda = "Titan Shards",
    zf = "Sandfury Sand",
    mara = "Purple Lotus",
    thanes = "Thane Runes",
    ruins = "Plague Vials",
    excav = "Relic Fragments",
    st = "Dream Leaves",
    brd = "Dark Iron Ore",
    lbrs = "Blackrock Shards",
    ubrs = "Dragon Eggshells",
    dme = "Felvine Shards",
    dmw = "Arcane Shards",
    dmn = "Gordok Green Grog",
    scholo = "Bone Dust",
    stratl = "Stratholme Holy Water",
    stratu = "Righteous Orbs",
    ony = "Onyxia Scales",
    barrow = "Barrow Moss",
    hyjal = "Nordrassil Sap",
}
function ns.IngredientName(dungeonKey) return ns.INGREDIENTS[dungeonKey] or "Tokens" end
function ns.IngredientIcon(dungeonKey) return "Interface\\AddOns\\SOLC\\Media\\Icons\\Ingredients\\" .. dungeonKey:upper() end
function ns.Tokens(dungeonKey) return KillTrackerDB.tokens and KillTrackerDB.tokens[dungeonKey] or 0 end
-- Spends tokens of each dungeon ({ [dungeon key] = how many }); false (and nothing spent) if you don't have them.
function ns.SpendTokens(spend)
    for key, n in pairs(spend) do
        if n > ns.Tokens(key) then return false end
    end
    for key, n in pairs(spend) do KillTrackerDB.tokens[key] = ns.Tokens(key) - n end
    return true
end
-- The dungeons you have tokens of, in the Achievements.lua order: { { dungeon, count } }.
function ns.TokenList()
    local list = {}
    for _, d in ipairs(ns.Dungeons and ns.Dungeons() or {}) do
        if ns.Tokens(d.key) > 0 then list[#list + 1] = { dungeon = d, count = ns.Tokens(d.key) } end
    end
    return list
end
-- A dungeon's pieces you don't have yet: { { layer, option } }.
function ns.MissingPieces(dungeonKey)
    local list = {}
    for _, unlocked in ipairs(ns.UnlockOptions("clear:" .. dungeonKey)) do
        if not ns.IsUnlocked(ns.OptionKey(unlocked.layer.key, unlocked.option)) then list[#list + 1] = unlocked end
    end
    return list
end
-- Buys one of a dungeon's missing pieces with its tokens. Returns true, or false and why not.
function ns.BuyPiece(dungeonKey, key)
    if ns.Tokens(dungeonKey) < ns.TOKEN_SHOP_PRICE then return false, "Not enough tokens." end
    local unlocked = ns.OptionByKey(key)
    if not unlocked or unlocked.option.unlock ~= "clear:" .. dungeonKey then return false, "That isn't one of its pieces." end
    if ns.IsUnlocked(key) then return false, "You have it already." end
    ns.SpendTokens({ [dungeonKey] = ns.TOKEN_SHOP_PRICE })
    ns.UnlockOption(key)
    ns.ShowToast("achievement", "Unlocked for minting!", unlocked.option.name, "Bought with tokens - it can roll in your pictures now")
    if ns.OnKillsChanged then ns.OnKillsChanged() end
    return true
end

-- Layer ingredients (ns.PotPlan, Minting.lua: they aim the pot at a layer, and make it rarer): one per layer, dropped by
-- the creatures of its types (LAYER_DROP of their kills, elites twice that, rares and bosses always). Fuels for the fire
-- under the pot (ns.FUELS: rarer pieces likelier, each its rarity and up, and the fire burns its colour): from rare
-- creatures and rare chests and up. All kept with the tokens, as l_<layer key> and the fuels' keys.
ns.LAYER_INGREDIENTS = {
    { layer = "background", name = "Elemental Mote", types = { "Elemental" } },
    { layer = "skin", name = "Ectoplasm", types = { "Undead" } },
    { layer = "outfit", name = "Bolt of Cloth", types = { "Humanoid" } },
    { layer = "expression", name = "Imp Giggle", types = { "Demon" } },
    { layer = "eyes", name = "Eye of Newt", types = { "Beast" } },
    { layer = "accessory", name = "Shiny Trinket", types = { "Mechanical", "Giant" } },
    { layer = "headwear", name = "Dragon Horn", types = { "Dragonkin" } },
}
local LAYER_DROP = 0.03
local CHEST_DUST = { 0, 0, 1, 2 }  -- by chest tier
local layerByType = {}
for _, spec in ipairs(ns.LAYER_INGREDIENTS) do
    spec.key = "l_" .. spec.layer
    ns.INGREDIENTS[spec.key] = spec.name
    for _, creatureType in ipairs(spec.types) do layerByType[creatureType] = spec end
end
ns.FUELS = {
    { key = "frostwood", name = "Frostwood Kindling", rarity = "rare", color = { 0.45, 0.75, 1 } },
    { key = "shimmer", name = "Shimmer Dust", rarity = "epic", color = { 0.8, 0.45, 1 } },
    { key = "sunwood", name = "Sunwood Log", rarity = "legendary", color = { 1, 0.62, 0.15 } },
}
local fuelByKey = {}
for _, fuel in ipairs(ns.FUELS) do
    fuelByKey[fuel.key] = fuel
    ns.INGREDIENTS[fuel.key] = fuel.name
end
function ns.Fuel(key) return fuelByKey[key] end
-- What kind an ingredient is: "dungeon", "layer" or "fuel".
function ns.IngredientKind(key)
    if fuelByKey[key] then return "fuel" end
    if key:match("^l_") then return "layer" end
    return "dungeon"
end
-- Where an ingredient comes from, for its tooltip.
function ns.IngredientSource(key)
    local kind = ns.IngredientKind(key)
    if kind == "fuel" then
        local fuel = fuelByKey[key]
        local from = ({ rare = "rare creatures and rare chests", epic = "rare elites and epic chests", legendary = "legendary chests" })[fuel.rarity]
        return ("From %s. Feed it to the fire: %s pieces get likelier."):format(from, fuel.rarity == "legendary" and "legendary" or (fuel.rarity .. " and better"))
    end
    if kind == "layer" then
        for _, spec in ipairs(ns.LAYER_INGREDIENTS) do
            if spec.key == key then
                local layer = key:sub(3)
                return ("From %s creatures. Aims the pot at the %s, and makes it rarer."):format(table.concat(spec.types, " and "):lower(), layer)
            end
        end
    end
    local d = ns.DungeonByKey and ns.DungeonByKey(key)
    return ("From %s's chests. Makes its pieces likelier."):format(d and d.name or "a dungeon")
end
function ns.AddIngredient(key, n, quiet)
    local db = KillTrackerDB
    db.tokens = db.tokens or {}
    db.tokens[key] = (db.tokens[key] or 0) + (n or 1)
    if not quiet then
        ns.Print(("|T%s:16|t You found %s%s, for the minting pot."):format(ns.IngredientIcon(key), (n or 1) > 1 and (n .. " ") or "", ns.IngredientName(key)))
    end
end
-- Every ingredient you have, for the pot's shelves: dungeons' (in the Achievements.lua order), layers', then fuels.
-- { { key, count, kind, dungeon (for a dungeon's) } }.
function ns.IngredientList()
    local list = {}
    for _, entry in ipairs(ns.TokenList()) do
        list[#list + 1] = { key = entry.dungeon.key, count = entry.count, kind = "dungeon", dungeon = entry.dungeon }
    end
    for _, spec in ipairs(ns.LAYER_INGREDIENTS) do
        if ns.Tokens(spec.key) > 0 then list[#list + 1] = { key = spec.key, count = ns.Tokens(spec.key), kind = "layer" } end
    end
    for _, fuel in ipairs(ns.FUELS) do
        if ns.Tokens(fuel.key) > 0 then list[#list + 1] = { key = fuel.key, count = ns.Tokens(fuel.key), kind = "fuel" } end
    end
    return list
end
-- Kills drop layer ingredients (and rares fuel: Frostwood, rare elites Shimmer Dust).
table.insert(ns.KillHandlers, function(_, _, c)
    local spec = c.type and layerByType[c.type]
    local rare = c.rank == "Rare" or c.rank == "Rare Elite"
    if spec then
        local chance = (rare or c.rank == "Boss") and 1 or c.rank == "Elite" and LAYER_DROP * 2 or LAYER_DROP
        if math.random() < chance then ns.AddIngredient(spec.key) end
    end
    if rare then ns.AddIngredient(c.rank == "Rare Elite" and "shimmer" or "frostwood") end
end)

-- Wearing a famous drop unlocks its piece on this character (KillTrackerDB is per character): equip the real Ironfoe
-- and the Ironfoe picture piece is yours - any chase, combined (Sul'thraze) or loot piece, matched by the item's name (simplified, as LootKey).
-- Checked at login and whenever the gear changes; a name WoW hasn't loaded yet is checked again once it has.
local function Simple(name) return (name:lower():gsub("[^%w]", "")) end
local wearable  -- ([simplified name] = option key: the chase, combined and loot pieces, made once the layers are known)
local waiting = {}  -- ([itemID] = true: worn, its name not loaded yet)
local function CheckWorn()
    if not KillTrackerDB or not ns.MintLayers or not ns.IsMember() then return end
    if not wearable then
        wearable = {}
        for _, layer in ipairs(ns.MintLayers) do
            for _, option in ipairs(layer.options) do
                if option.unlock and (option.unlock:find("^chase:") or option.unlock:find("^loot:") or option.unlock:find("^combine:")) then
                    wearable[Simple(option.name)] = ns.OptionKey(layer.key, option)
                end
            end
        end
    end
    local new = false
    for slot = 1, 19 do
        local itemID = GetInventoryItemID("player", slot)
        if itemID and not issecret(itemID) then
            local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID) or GetItemInfo(itemID)
            if not name then
                waiting[itemID] = true
            else
                waiting[itemID] = nil
                local key = wearable[Simple(name)]
                if key and ns.UnlockOption(key) then
                    new = true
                    ns.ShowToast("achievement", "Unlocked for minting!", name, "Worn: it can roll in your pictures now")
                end
            end
        end
    end
    if new and ns.OnKillsChanged then ns.OnKillsChanged() end
end
local worn = CreateFrame("Frame")
worn:RegisterEvent("PLAYER_LOGIN")
worn:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
worn:RegisterEvent("GET_ITEM_INFO_RECEIVED")
worn:SetScript("OnEvent", function(_, event, itemID)
    if event == "GET_ITEM_INFO_RECEIVED" and not waiting[itemID] then return end
    CheckWorn()
end)

-- Epic loot: an item you loot unlocks its layer, if there is one ("loot:" .. its name, simplified).
local function LootKey(name) return "loot:" .. name:lower():gsub("[^%w]", "") end
local SELF_PATTERNS = {}
for _, format in ipairs({ LOOT_ITEM_SELF, LOOT_ITEM_SELF_MULTIPLE, LOOT_ITEM_PUSHED_SELF, LOOT_ITEM_PUSHED_SELF_MULTIPLE }) do
    if format then
        -- "You receive loot: %s." -> "^You receive loot: (.+)%.$" (the item link captured)
        local pattern = format:gsub("([%(%)%.%-%+%?%[%]%^%$])", "%%%1"):gsub("%%s", "(.+)"):gsub("%%d", "%%d+")
        SELF_PATTERNS[#SELF_PATTERNS + 1] = "^" .. pattern .. "$"
    end
end
local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_LOOT")
frame:SetScript("OnEvent", function(_, _, message)
    if not KillTrackerDB or not message or issecret(message) or not ns.IsMember() then return end
    for _, pattern in ipairs(SELF_PATTERNS) do
        local link = message:match(pattern)
        if link then
            local name = link:match("|h%[(.-)%]|h")
            if name and ns.UnlockPool(LootKey(name)) > 0 then
                ns.ShowToast("achievement", "Unlocked for minting!", name, "It can roll in your pictures now")
                if ns.OnKillsChanged then ns.OnKillsChanged() end
            end
            return
        end
    end
end)
