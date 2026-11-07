-- Unlocks: picture layers you can only roll once you've earned them (MintArt.lua options with an unlock key; see
-- Minting.lua's ns.MintAllowed). Each option is unlocked on its own: KillTrackerDB.unlocks = { [layer:id] = time }
-- (this character's own, KillTrackerDB.ownUnlocks, or while it shares its wardrobe the account's: Core.lua)
-- (ns.OptionKey). Unlocking makes it rollable; getting it into a picture is the mint's luck. Where they come from, by
-- their option's unlock key:
--   clear:<dungeon>         a dungeon's set (the dungeon keys in Achievements.lua): its end boss's hat and outfit; out
--                           of the dungeon's chests by chance (its backdrop: its first clear's deed)
--   chase:<dungeon>:<name>  a chase item: in the dungeon's chests by luck (its option's dropChance, CHASE_CHANCE),
--                           likelier in a better chest
--   loot:<item>             looting that epic item (its name in lower case, letters and digits only)
--   (a chase, combined or loot piece also unlocks by wearing that item: equipping the real Ironfoe, on this character)
--   deed:<achievement id>   earning that achievement, e.g. "deed:subtype:Murloc:100": a creature's hat and onesie
--                           (make-unlock-art.js's creatures; worn together they're one hooded onesie, Minting.lua)
-- Chests: each clear (its end boss down, Guild.lua) finds the dungeon's chest by chance: the guild's chestChance (25%)
-- for you and as much again for each guildmate with you. A chest rolls its quality as it's found (ns.CHEST_TIERS:
-- common to legendary); the first chest of a dungeon you've had nothing from is at least rare. Opened, it always has
-- its coins (points: the guild's chestCoins, more for the higher dungeons and for better chests), and by chance (better
-- in a better chest) a chase item and one of the dungeon's set you don't have yet - that one for sure after PITY
-- chests of it without (KillTrackerDB.chestPity = { [dungeon] = chests since its last piece }). No tokens any more.
-- KillTrackerDB.chests = { { dungeon, time, tier } }: kept, as many as you
-- find, until you open them (Chests.lua, the Inventory's tiles); KillTrackerDB.points.chests = the coins from them.
-- An unlock goes in your feed (event U, a = its option key). The first check ever (data from before unlocks,
-- Achievements.lua after counting your kills) gives a chest of each dungeon you've already cleared.

local _, ns = ...

local CHASE_CHANCE = 0.1  -- a chase item's chance in a chest, unless its option says (dropChance)
local PITY = 3  -- chests of a dungeon in a row without a set piece (while it has any left for you): the next has one
-- A chest's quality: its chance as it's found, its coins' multiplier, its chase item's luck, its chance of a set piece.
ns.CHEST_TIERS = {
    { key = "common", name = "Common", chance = 0.60, coins = 1, chase = 1, piece = 0.4, story = 1, bonk = 0 },
    { key = "rare", name = "Rare", chance = 0.25, coins = 2, chase = 1.5, piece = 0.6, story = 1, bonk = 0 },
    { key = "epic", name = "Epic", chance = 0.12, coins = 4, chase = 2, piece = 0.8, story = 2, bonk = 1 },
    { key = "legendary", name = "Legendary", chance = 0.03, coins = 10, chase = 3, piece = 1, story = 3, bonk = 1 },
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
    if db.ownUnlocks then db.ownUnlocks[key] = db.unlocks[key] end  -- (this character's own too: Core.lua's wardrobe)
    if ns.CheckCombines then ns.CheckCombines() end  -- (the other half of a combined piece, Minting.lua)
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
        ns.ShowToast("achievement", "You found a chest!", d.name .. " chest", "Open it in your Inventory, whenever you like")
        ns.Print(("You found the |cffffd100%s chest|r - open it in your Inventory."):format(d.name))
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

-- Ogre Godz tribute (the dev menu, Dev.lua; sent by Tribute.lua): a chest made by hand, kept with the others as
-- { dungeon = ns.TRIBUTE, time, tier, tribute = spec }, opened like them (Chests.lua, with its own entrance). spec:
-- { tier, note, points, items = { { kind = "unlock", key = option key } or { kind = "ingredient", key, n } } }.
-- Its points count as earned (they go with the chests' coins: they raise your Ogre Rank).
ns.TRIBUTE = "tribute"
ns.TRIBUTE_MAX_ITEMS = 5  -- (the cards the chest show has room for)
function ns.AddTribute(spec)
    local db = KillTrackerDB
    db.chests = db.chests or {}
    local tier = math.max(1, math.min(#TIERS, tonumber(spec.tier) or #TIERS))
    db.chests[#db.chests + 1] = { dungeon = ns.TRIBUTE, time = time(), tier = tier, tribute = spec }
    if ns.Tally then ns.Tally("tribute") end  -- (the secret Graced By The Godz deed, Achievements.lua)
    if ns.OnKillsChanged then ns.OnKillsChanged() end
end
-- The cards a tribute shows (the chest show's items): its pieces and ingredients.
function ns.TributeCards(spec)
    local items = {}
    for _, item in ipairs(spec.items or {}) do
        if item.kind == "unlock" then
            local unlocked = ns.OptionByKey(item.key)
            if unlocked then items[#items + 1] = { kind = "unlock", layer = unlocked.layer, option = unlocked.option } end
        elseif item.kind == "ingredient" and ns.INGREDIENTS[item.key] then
            items[#items + 1] = { kind = "tokens", dungeon = item.key, count = item.n or 1 }
        end
    end
    return items
end
local function OpenTribute(chest)
    local db, spec = KillTrackerDB, chest.tribute or {}
    for _, item in ipairs(spec.items or {}) do
        if item.kind == "unlock" then ns.UnlockOption(item.key)
        elseif item.kind == "ingredient" and ns.INGREDIENTS[item.key] then ns.AddIngredient(item.key, item.n or 1, true) end
    end
    local coins = math.max(0, math.floor(tonumber(spec.points) or 0))
    if coins > 0 then
        db.points.chests = (db.points.chests or 0) + coins
        ns.Touch(db.points)
    end
    if ns.OnKillsChanged then ns.OnKillsChanged() end
    if ns.CheckRank then ns.CheckRank() end
    return chest.tier or #TIERS, coins, ns.TributeCards(spec)
end

-- Bounty chests (Posters.lua): a claimed poster's ({ dungeon = ns.BOUNTY, time, tier, poster = its id }, its tier
-- rolled like a dungeon's) and the guild's milestone chest (ns.GUILD_BOUNTY, epic), opened like the dungeons'. Inside:
-- coins, the tier's stories and bonks, and one of the poster's own pieces (ns.PosterPieces) by the tier's chance - for
-- sure after PITY chests without; all of them had: any poster's. The guild chest: a piece for sure.
ns.BOUNTY, ns.GUILD_BOUNTY = "bounty", "guildbounty"
local function RollAny()
    local pick = math.random()
    for i, t in ipairs(TIERS) do
        if pick < t.chance then return i end
        pick = pick - t.chance
    end
    return 1
end
function ns.AddBountyChest(posterID)
    local db = KillTrackerDB
    db.chests = db.chests or {}
    db.chests[#db.chests + 1] = { dungeon = ns.BOUNTY, time = time(), tier = RollAny(), poster = posterID }
end
function ns.AddGuildBountyChest()
    local db = KillTrackerDB
    db.chests = db.chests or {}
    db.chests[#db.chests + 1] = { dungeon = ns.GUILD_BOUNTY, time = time(), tier = 3 }
end
-- Fishing chests: each fish caught (LifeStats.lua) has FISH_CHANCE of one, more for the fishing gear your ogre wears
-- (SetBonuses.lua: +25% a piece, the whole angler outfit double). Inside, like a bounty chest's: coins, the tier's stories and
-- bonks, and by the tier's chance (for sure after PITY without) a fishing piece: the angler set (unlock "chest:fishing",
-- only from these) or the Fishing Rod.
ns.FISHING = "fishing"
local FISH_CHANCE = 1 / 50  -- (times the fishing gear worn: SetBonuses.lua)
local FISHING_EXTRA = { "accessory:prop_fish" }  -- (fishing pieces from elsewhere a fishing chest can give too)
-- The fishing chest's chance for one fish, and how many fishing pieces your ogre wears.
function ns.FishingChestChance()
    local multiplier, worn = 1, 0
    if ns.FishingSetMultiplier then multiplier, worn = ns.FishingSetMultiplier() end
    return FISH_CHANCE * multiplier, worn
end
function ns.OnFishCaught()
    if ns.RankLocked and ns.RankLocked("pixcollection") then return end  -- (chests come with the Dream Bed's rank)
    if math.random() >= ns.FishingChestChance() then return end
    local db = KillTrackerDB
    db.chests = db.chests or {}
    db.chests[#db.chests + 1] = { dungeon = ns.FISHING, time = time(), tier = RollAny() }
    ns.ShowToast("achievement", "A fishing chest!", "Something heavy on the line", "Open it in your Inventory")
    if ns.OnKillsChanged then ns.OnKillsChanged() end
end
local function FishingPool()
    local list = ns.UnlockOptions("chest:fishing")
    for _, key in ipairs(FISHING_EXTRA) do
        local unlocked = ns.OptionByKey(key)
        if unlocked then list[#list + 1] = unlocked end
    end
    return list
end

-- A chest's name, for its tile and its show: "Deadmines", "Bounty", "Guild bounty", "Fishing", "Ogre Godz tribute".
function ns.ChestName(key)
    if key == ns.TRIBUTE then return "Ogre Godz tribute" end
    if key == ns.FISHING then return "Fishing" end
    if key == ns.BOUNTY then return "Bounty" end
    if key == ns.GUILD_BOUNTY then return "Guild bounty" end
    local d = ns.DungeonByKey and ns.DungeonByKey(key)
    return d and d.name or "A dungeon"
end
-- The pieces of a list ({ { layer, option } }) you don't have yet.
local function Locked(list)
    local out = {}
    for _, unlocked in ipairs(list) do
        if not ns.IsUnlocked(ns.OptionKey(unlocked.layer.key, unlocked.option)) then out[#out + 1] = unlocked end
    end
    return out
end
local function OpenBounty(chest)
    local db = KillTrackerDB
    if ns.Tally then ns.Tally("chests") end  -- (the Chests opened deeds)
    local tier = chest.tier or 1
    local spec = TIERS[tier] or TIERS[1]
    local guild = chest.dungeon == ns.GUILD_BOUNTY
    local fishing = chest.dungeon == ns.FISHING  -- (a fishing chest: the fishing pieces, its own pity)
    local pityKey = fishing and ns.FISHING or ns.BOUNTY
    local items = {}
    local list
    if fishing then
        list = Locked(FishingPool())
    else
        local own = Locked(ns.PosterPieces and chest.poster and ns.PosterPieces(chest.poster) or {})
        list = #own > 0 and own or Locked(ns.PosterPieces and ns.PosterPieces() or {})
    end
    db.chestPity = db.chestPity or {}
    local dry = db.chestPity[pityKey] or 0
    if #list > 0 and (guild or dry >= PITY or math.random() < (spec.piece or 0)) then
        local unlocked = list[math.random(#list)]
        ns.UnlockOption(ns.OptionKey(unlocked.layer.key, unlocked.option))
        items[#items + 1] = { kind = "unlock", layer = unlocked.layer, option = unlocked.option }
        if not guild then db.chestPity[pityKey] = 0 end
    elseif not guild then
        db.chestPity[pityKey] = dry + 1
    end
    for _, key in ipairs({ "story", "bonk" }) do
        if (spec[key] or 0) > 0 then
            ns.AddIngredient(key, spec[key], true)
            items[#items + 1] = { kind = "tokens", dungeon = key, count = spec[key] }
        end
    end
    local coins = math.floor(ns.Config("chestCoins") * (guild and 2 or 1) * spec.coins * (0.5 + math.random()) + 0.5)
    db.points.chests = (db.points.chests or 0) + coins
    ns.Touch(db.points)
    if ns.OnKillsChanged then ns.OnKillsChanged() end
    if ns.CheckRank then ns.CheckRank() end
    return tier, coins, items
end

-- Opens one of your chests of a dungeon. Returns its tier, its coins and its items ({ { kind = "unlock", layer, option } },
-- none to two: a chase item, a set piece); nil if you have no chest of it. It's all yours by the time it returns.
function ns.OpenChest(dungeonKey)
    local db = KillTrackerDB
    local chest
    for i, c in ipairs(db.chests or {}) do
        if c.dungeon == dungeonKey then chest = table.remove(db.chests, i) break end
    end
    if not chest then return nil end
    if dungeonKey == ns.TRIBUTE then return OpenTribute(chest) end
    if dungeonKey == ns.BOUNTY or dungeonKey == ns.GUILD_BOUNTY or dungeonKey == ns.FISHING then return OpenBounty(chest) end
    if ns.Tally then ns.Tally("chests") end  -- (the Chests opened deeds)
    local tier = chest.tier or 1
    local spec = TIERS[tier] or TIERS[1]
    local items, coins = {}, Coins(dungeonKey, tier)
    local function Take(unlocked)
        ns.UnlockOption(ns.OptionKey(unlocked.layer.key, unlocked.option))
        items[#items + 1] = { kind = "unlock", layer = unlocked.layer, option = unlocked.option }
    end
    -- A chase item, by its luck (the chest's tier times it).
    for _, unlocked in ipairs(Locked(ns.ChestPool(dungeonKey))) do
        local option = unlocked.option
        if option.unlock ~= "clear:" .. dungeonKey and math.random() < (option.dropChance or CHASE_CHANCE) * spec.chase then
            Take(unlocked)
            break
        end
    end
    -- One of the set you don't have, by the tier's chance; for sure after PITY chests of it without, and for sure in the
    -- first chest that finds you none of the set yet (a new dungeon cleared should feel like it).
    local set = ns.UnlockOptions("clear:" .. dungeonKey)
    local pieces = Locked(set)
    if #pieces > 0 then
        db.chestPity = db.chestPity or {}
        local dry = db.chestPity[dungeonKey] or 0
        if #pieces == #set or dry >= PITY or math.random() < (spec.piece or 0) then
            Take(pieces[math.random(#pieces)])
            db.chestPity[dungeonKey] = 0
        else
            db.chestPity[dungeonKey] = dry + 1
        end
    end
    -- (and the Dream Bed's stories and bonks, by the tier: cards of their own)
    for _, key in ipairs({ "story", "bonk" }) do
        if (spec[key] or 0) > 0 then
            ns.AddIngredient(key, spec[key], true)
            items[#items + 1] = { kind = "tokens", dungeon = key, count = spec[key] }
        end
    end
    db.points.chests = (db.points.chests or 0) + coins
    ns.Touch(db.points)
    if ns.OnKillsChanged then ns.OnKillsChanged() end
    if ns.CheckRank then ns.CheckRank() end  -- the coins count towards your Ogre Rank
    return tier, coins, items
end

-- After the achievements count your kills (clears per dungeon: { [dungeon key] = clears }): the first time ever, each
-- dungeon already cleared gives its chest.
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
        ns.Print(("You have |cffffd100%d chest%s|r from the dungeons you've cleared - open them in your Inventory."):format(found, found == 1 and "" or "s"))
    end
end

-- The Dream Bed's two (DreamBed.lua): Bedtime Stories (ask about one piece: 1 to 5 by its rarity) and Bonks (ogres go
-- to sleep by bonking their heads: one a dream; one comes back each day). Kept in KillTrackerDB.tokens as "story" and
-- "bonk". From rares, dungeon chests, bounties and Ogre Rank.
ns.DREAM_ITEMS = {
    story = { name = "Bedtime Story", icon = "Interface\\Icons\\INV_Misc_Book_09",
        source = "From rare creatures, dungeon chests and bounties. Ask the ogre to dream about one piece you pick." },
    bonk = { name = "Bonk", icon = "Interface\\Icons\\INV_Hammer_05",
        source = "Ogres go to sleep by bonking their heads: one bonk with the mallet and he's out. One comes back each day (up to 3); more from epic dungeon chests, bounties and Ogre Rank." },
}
ns.INGREDIENTS = {}
for key, item in pairs(ns.DREAM_ITEMS) do ns.INGREDIENTS[key] = item.name end
function ns.IngredientName(key) return ns.INGREDIENTS[key] or key end
function ns.IngredientIcon(key) return ns.DREAM_ITEMS[key] and ns.DREAM_ITEMS[key].icon or "Interface\\Icons\\INV_Misc_QuestionMark" end
function ns.Tokens(key) return KillTrackerDB.tokens and KillTrackerDB.tokens[key] or 0 end
-- Spends some of each ({ [key] = how many }); false (and nothing spent) if you don't have them.
function ns.SpendTokens(spend)
    for key, n in pairs(spend) do
        if n > ns.Tokens(key) then return false end
    end
    for key, n in pairs(spend) do KillTrackerDB.tokens[key] = ns.Tokens(key) - n end
    return true
end
function ns.AddIngredient(key, n, quiet)
    local db = KillTrackerDB
    db.tokens = db.tokens or {}
    db.tokens[key] = (db.tokens[key] or 0) + (n or 1)
    if not quiet and not (ns.RankLocked and ns.RankLocked("pixcollection")) then  -- (quiet till the Dream Bed opens)
        ns.Print(("|T%s:16|t You found %s%s, for the Dream Bed."):format(ns.IngredientIcon(key), (n or 1) > 1 and (n .. " ") or "",
            ns.IngredientName(key)))
    end
end
-- Rares give a Bedtime Story (a rare elite two).
table.insert(ns.KillHandlers, function(_, _, c)
    if c.rank == "Rare" or c.rank == "Rare Elite" then ns.AddIngredient("story", c.rank == "Rare Elite" and 2 or 1) end
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
                    if not (ns.RankLocked and ns.RankLocked("pixcollection")) then ns.ShowToast("achievement", "Unlocked for your dreams!", name, "Worn: it can roll in your pictures now") end
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
                if not (ns.RankLocked and ns.RankLocked("pixcollection")) then  -- (quiet till the Collection opens)
                    ns.ShowToast("achievement", "Unlocked for your dreams!", name, "It can roll in your pictures now")
                end
                if ns.OnKillsChanged then ns.OnKillsChanged() end
            end
            return
        end
    end
end)
