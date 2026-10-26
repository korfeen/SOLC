-- Ogre Rank: the meta progression. Your rank comes from the points you've ever earned (spending them on pictures
-- never costs rank), 30 ranks from Pebble Kicker to Grand Sleepy Ogre. Ranks unlock perks: cheaper and luckier
-- minting, more ogre crayons and voices, a coloured name on your card. Guildmates' ranks come from their synced
-- points, so everyone sees everyone's. Reaching a rank shows a popup and goes in the activity feed (event K).

local _, ns = ...

-- The points each rank needs: 24 * (rank - 1)^2.2, rounded to tens (rank 5: 500, 10: 3000, 20: 15600, 30: 39500).
local TITLES = {
    "Pebble Kicker", "Rock Licker", "Mud Wallower", "Twig Snapper", "Club Swinger",
    "Stump Thumper", "Knuckle Dragger", "Boulder Hugger", "Belly Drummer", "Cave Bouncer",
    "Snack Hoarder", "Bone Gnawer", "Head Bonker", "Tree Shaker", "Sleepy Brute",
    "Loud Snorer", "Hill Smasher", "Mountain Napper", "Gut Rumbler", "Big Bonker",
    "Thunder Belly", "Nap Champion", "Ogre Of Note", "Club Master", "Snore Lord",
    "Dream Smasher", "Pillow Warlord", "Legendary Lump", "Ogre Of Ogres", "Grand Sleepy Ogre",
}
ns.RANKS = {}
for rank, title in ipairs(TITLES) do
    ns.RANKS[rank] = { rank = rank, title = title, points = math.floor(24 * (rank - 1) ^ 2.2 / 10 + 0.5) * 10 }
end
local MAX_RANK = #ns.RANKS

-- The perks, by the rank that unlocks them. kind: what it does (read by the functions below); text: for the list.
ns.RANK_PERKS = {
    { rank = 3, kind = "crayons", value = 2, text = "Two more ogre crayons (ogre mode's letters)" },
    { rank = 4, kind = "nameColor", id = "silver", name = "Silver", value = { 0.8, 0.84, 0.9 }, text = "Silver name on your card" },
    { rank = 6, kind = "discount", value = 0.1, text = "Pictures cost 10% less" },
    { rank = 8, kind = "voices", value = 2, text = "Ogre voices on clicks twice as often" },
    { rank = 10, kind = "luck", value = 1.25, text = "Lucky minting: epic and legendary layers 25% likelier" },
    { rank = 12, kind = "nameColor", id = "gold", name = "Gold", value = { 1, 0.82, 0.25 }, text = "Gold name on your card" },
    { rank = 12, kind = "crayons", value = 2, text = "Two more ogre crayons" },
    { rank = 14, kind = "discount", value = 0.2, text = "Pictures cost 20% less" },
    { rank = 16, kind = "voices", value = 3, text = "Ogre voices on clicks three times as often" },
    { rank = 18, kind = "luck", value = 1.5, text = "Luckier minting: epic and legendary layers 50% likelier" },
    { rank = 20, kind = "crayons", value = 3, text = "Three more ogre crayons" },
    { rank = 22, kind = "discount", value = 0.3, text = "Pictures cost 30% less" },
    { rank = 24, kind = "nameColor", id = "orange", name = "Ogre Orange", value = { 1, 0.5, 0.2 }, text = "Ogre-orange name on your card" },
    { rank = 26, kind = "luck", value = 2, text = "Luckiest minting: epic and legendary layers twice as likely" },
    { rank = 30, kind = "nameColor", id = "pink", name = "Grand Sleepy Pink", value = { 1, 0.4, 0.75 }, text = "Grand Sleepy Ogre pink name on your card" },
}

-- The minting pot's cauldrons (MintPot.lua), bigger with your rank: how many ingredients fit in it (slots) and how big
-- it's drawn (size). Their perks are in RANK_PERKS too.
ns.CAULDRONS = {
    { rank = 1, name = "Tin Pot", slots = 4, size = 0.78 },
    { rank = 6, name = "Iron Kettle", slots = 6, size = 0.86 },
    { rank = 12, name = "Witch's Cauldron", slots = 8, size = 0.94 },
    { rank = 20, name = "Ogre Stewpot", slots = 10, size = 1.02 },
    { rank = 28, name = "Grand Sleepy Cauldron", slots = 12, size = 1.1 },
}
for i, cauldron in ipairs(ns.CAULDRONS) do
    if i > 1 then
        ns.RANK_PERKS[#ns.RANK_PERKS + 1] = { rank = cauldron.rank, kind = "cauldron", value = i,
            text = ("%s: %d ingredients in the minting pot"):format(cauldron.name, cauldron.slots) }
    end
end
table.sort(ns.RANK_PERKS, function(a, b) return a.rank < b.rank end)
-- Your cauldron (key nil) or a guildmate's, by rank.
function ns.Cauldron(key)
    local rank, best = ns.GetRank(key).rank, ns.CAULDRONS[1]
    for _, cauldron in ipairs(ns.CAULDRONS) do
        if rank >= cauldron.rank then best = cauldron end
    end
    return best
end

-- Someone's rank: you (key nil) or a synced guildmate. Returns the rank's entry, the next one's (nil at the top)
-- and their lifetime points.
function ns.GetRank(key)
    local points
    if key then
        local friend = KillTrackerFriends[key]
        points = friend and friend.earned or 0
    else
        points = ns.GetPoints().earned
    end
    local current = ns.RANKS[1]
    for _, entry in ipairs(ns.RANKS) do
        if points >= entry.points then current = entry end
    end
    return current, ns.RANKS[current.rank + 1], points
end

-- The best value of one kind of perk at a rank (the latest unlocked), or nil.
function ns.RankPerk(kind, rank)
    rank = rank or ns.GetRank().rank
    local best
    for _, perk in ipairs(ns.RANK_PERKS) do
        if perk.kind == kind and perk.rank <= rank then
            if kind == "crayons" then best = (best or 0) + perk.value else best = perk.value end
        end
    end
    return best
end

-- Colours, picked in the header's edit mode (ProfileHeader.lua) for your name, your level 60 glow and your header's
-- background: one per ogre skin, yours once you have the skin (a free one, or its unlock: Unlocks.lua), and white for
-- everyone. The ones picked: KillTrackerDB.card.nameColor / glowColor / bgColor (synced). Built on first use (the
-- skins are in MintArt.lua, which loads after this).
local SKIN_RGB = {  -- each skin's face colour (sampled from the skins, as tools/make-crayon-items.js SKINS)
    celestial_blue = { 66, 72, 107 }, enchanted_jade = { 112, 119, 58 }, gold = { 182, 131, 40 }, obsidian_ember = { 92, 56, 43 },
    sea_cursed_teal = { 70, 114, 104 }, pale_lavender = { 164, 127, 155 }, slate_gray = { 106, 101, 102 }, sunburnt_red = { 182, 67, 54 },
    moss = { 136, 107, 43 }, mud_brown = { 125, 82, 47 }, swamp_green = { 104, 94, 48 }, grand_sleepy_pink = { 214, 112, 158 },
}
ns.NAME_COLORS = { { id = "white", name = "White", value = { 1, 1, 1 }, base = { 0.55, 0.5, 0.45 } } }
local colorsBuilt = false
function ns.Colors()
    if colorsBuilt or not ns.MintLayers then return ns.NAME_COLORS end
    colorsBuilt = true
    for _, layer in ipairs(ns.MintLayers) do
        if layer.key == "skin" then
            for _, option in ipairs(layer.options) do
                local rgb = SKIN_RGB[option.id]
                if rgb and not option.retired then
                    -- (brighter for a name on the dark wood; the background takes the skin's own)
                    local bright = {}
                    for i = 1, 3 do bright[i] = math.min(1, (rgb[i] * 1.3 + 50) / 255) end
                    ns.NAME_COLORS[#ns.NAME_COLORS + 1] = { id = option.id, name = option.name, value = bright,
                        base = { rgb[1] / 255, rgb[2] / 255, rgb[3] / 255 }, skin = option }
                end
            end
        end
    end
    return ns.NAME_COLORS
end

function ns.FindNameColor(id)
    for _, entry in ipairs(ns.Colors()) do
        if entry.id == id then return entry end
    end
end

-- Whether you can use a colour: its skin is yours (free, or unlocked).
function ns.HasNameColor(entry)
    local option = entry.skin
    return not option or not option.unlock or ns.IsUnlocked("skin:" .. option.id)
end

-- (colours aren't bought any more: they come with the skins)
function ns.BuyNameColor() return false, "Colours come with ogre skins." end

-- Someone's colour for one use ("name", "glow", "bg"): the entry they picked (yours only while you have it), or nil.
function ns.GetCardColor(key, use)
    local card = key and KillTrackerFriends[key] and KillTrackerFriends[key].card or not key and KillTrackerDB.card
    local entry = card and ns.FindNameColor(card[use == "name" and "nameColor" or use .. "Color"])
    if entry and (key or ns.HasNameColor(entry)) then return entry end
end

-- The colour of someone's name (RGB): the one they picked (yours only while you still have it), else their best
-- rank colour, else white.
function ns.GetNameColor(key)
    local entry = ns.GetCardColor(key, "name")
    return entry and entry.value or ns.NAME_COLORS[1].value
end

-- Watches your rank: a popup and a feed event (K, a = rank) each time it goes up, and Bonks for the Dream Bed (an extra
-- night: BONKS a rank, BONKS_BIG every fifth). KillTrackerDB.rank is the last rank seen (nil until the first check,
-- which only records it).
local BONKS, BONKS_BIG = 1, 3
local RANK_UNLOCKS = { [30] = "skin:grand_sleepy_pink" }
function ns.CheckRank()
    local db = KillTrackerDB
    if not db or not ns.GetPoints then return end
    local current = ns.GetRank()
    local seen = db.rank
    db.rank = current.rank
    -- (what a rank unlocks in the minting art: option keys by rank - Grand Sleepy Pink at 30; also caught up on login)
    for rank, key in pairs(RANK_UNLOCKS) do
        if current.rank >= rank and ns.UnlockOption then ns.UnlockOption(key, seen == nil) end
    end
    if not seen or current.rank <= seen then return end
    local bonks = 0
    for rank = seen + 1, current.rank do
        if ns.AddEvent then ns.AddEvent("K", rank) end
        bonks = bonks + (rank % 5 == 0 and BONKS_BIG or BONKS)
    end
    if ns.AddIngredient then ns.AddIngredient("bonk", bonks, true) end
    local unlocked = {}
    for _, perk in ipairs(ns.RANK_PERKS) do
        if perk.rank > seen and perk.rank <= current.rank then unlocked[#unlocked + 1] = perk.text end
    end
    unlocked[#unlocked + 1] = ("%d %s for the Dream Bed"):format(bonks, bonks == 1 and "Bonk" or "Bonks")
    ns.ShowToast("achievement", ("Rank %d!"):format(current.rank), current.title, unlocked[1])
    ns.Print(("You reached rank %d: |cffff8000%s|r%s"):format(current.rank, current.title,
        #unlocked > 0 and (". Unlocked: " .. table.concat(unlocked, "; ")) or ""))
    if ns.OnKillsChanged then ns.OnKillsChanged() end
end

table.insert(ns.KillHandlers, function() ns.CheckRank() end)
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_LOGIN")
watcher:SetScript("OnEvent", function() C_Timer.After(2, ns.CheckRank) end)  -- after the login catch-ups
