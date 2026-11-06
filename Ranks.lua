-- Ogre Rank: the meta progression. Your rank comes from the points you've ever earned (spending them on pictures
-- never costs rank), 30 ranks from Pebble Kicker to Grand Sleepy Ogre. Ranks unlock perks: luckier minting, more ogre crayons and voices, a coloured name on your card. Guildmates' ranks come from their synced
-- points, so everyone sees everyone's. Reaching a rank shows a popup and goes in the activity feed (event K).

local _, ns = ...

-- The points each rank needs: 48 * (rank - 1)^2.2, rounded to tens (rank 5: 1010, 10: 6030, 20: 31220, 30: 79160;
-- doubled 2026-11-05: rank 6 came by level 11).
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
    ns.RANKS[rank] = { rank = rank, title = title, points = math.floor(48 * (rank - 1) ^ 2.2 / 10 + 0.5) * 10 }
end

-- The perks, by the rank that unlocks them. kind: what it does (read by the functions below); text: for the list.
ns.RANK_PERKS = {
    { rank = 3, kind = "crayons", value = 2, text = "Two more ogre crayons (ogre mode's letters)", short = "2 crayons" },
    { rank = 4, kind = "nameColor", id = "silver", name = "Silver", value = { 0.8, 0.84, 0.9 }, text = "Silver name on your card", short = "Silver name" },
    { rank = 6, kind = "ogreStyle", value = "sketch", text = "Your ogre in pencil sketch (EDIT's STYLE)", short = "Pencil sketch" },
    { rank = 8, kind = "voices", value = 2, text = "Ogre voices on clicks twice as often", short = "Voices x2" },
    { rank = 10, kind = "luck", value = 1.25, text = "Lucky dreams: epic and legendary layers 25% likelier", short = "Luck +25%" },
    { rank = 12, kind = "nameColor", id = "gold", name = "Gold", value = { 1, 0.82, 0.25 }, text = "Gold name on your card", short = "Gold name" },
    { rank = 12, kind = "crayons", value = 2, text = "Two more ogre crayons", short = "2 crayons" },
    { rank = 14, kind = "ogreStyle", value = "crayon", text = "Your ogre in crayon (EDIT's STYLE)", short = "Crayon style" },
    { rank = 16, kind = "voices", value = 3, text = "Ogre voices on clicks three times as often", short = "Voices x3" },
    { rank = 18, kind = "luck", value = 1.5, text = "Luckier dreams: epic and legendary layers 50% likelier", short = "Luck +50%" },
    { rank = 20, kind = "crayons", value = 3, text = "Three more ogre crayons", short = "3 crayons" },
    { rank = 22, kind = "wallpaper", value = "blocks", text = "The Blue Blocks wallpaper (EDIT's Wallpaper)", short = "Blue Blocks wallpaper" },
    { rank = 24, kind = "nameColor", id = "orange", name = "Ogre Orange", value = { 1, 0.5, 0.2 }, text = "Ogre-orange name on your card", short = "Orange name" },
    { rank = 26, kind = "luck", value = 2, text = "Luckiest dreams: epic and legendary layers twice as likely", short = "Luck x2" },
    { rank = 30, kind = "nameColor", id = "pink", name = "Grand Sleepy Pink", value = { 1, 0.4, 0.75 }, text = "Grand Sleepy Ogre pink name on your card", short = "Pink name" },
    -- Picture pieces (MintArt.lua options with unlock "rank:<n>", tools/convert-art.js BASE_UNLOCKS): the epics and
    -- legendaries that used to be free, one a rank from 3, when minting opens (2026-11-05). CheckRank unlocks them.
    { rank = 3, kind = "piece", key = "expression:sea_dog_grin" },
    { rank = 4, kind = "piece", key = "eyes:dreamy_swirl" },
    { rank = 5, kind = "piece", key = "accessory:pirate_eyepatch" },
    { rank = 6, kind = "piece", key = "background:pool_with_floaties" },
    { rank = 7, kind = "piece", key = "accessory:floating_sheep" },
    { rank = 8, kind = "piece", key = "outfit:pirate_captain_coat" },
    { rank = 9, kind = "piece", key = "headwear:astral_nightcap" },
    { rank = 10, kind = "piece", key = "expression:crystal_drool" },
    { rank = 11, kind = "piece", key = "accessory:moonstone_pendant" },
    { rank = 13, kind = "piece", key = "expression:stardust_snore" },
    { rank = 14, kind = "piece", key = "eyes:starlit_dreamer" },
    { rank = 15, kind = "piece", key = "outfit:celestial_pajamas" },
    { rank = 17, kind = "piece", key = "skin:sea_cursed_teal" },
    { rank = 19, kind = "piece", key = "headwear:dragon_hatchling_hat" },
    { rank = 21, kind = "piece", key = "outfit:dragonhide_golf_jacket" },
    { rank = 23, kind = "piece", key = "skin:enchanted_jade" },
    { rank = 24, kind = "piece", key = "background:floating_sky_spa" },
    { rank = 25, kind = "piece", key = "outfit:royal_nap_robe" },
    { rank = 26, kind = "piece", key = "accessory:pocket_portal" },
    { rank = 27, kind = "piece", key = "skin:celestial_blue" },
    { rank = 28, kind = "piece", key = "headwear:crown_of_eternal_rest" },
    { rank = 29, kind = "piece", key = "background:dragon_over_the_fairway" },
    -- The rank frames (Frames.lua's unlock "rank:<n>", checked there: these are for the list only).
    { rank = 3, kind = "frame", short = "Polaroid frame" },
    { rank = 4, kind = "frame", short = "Honey Wood frame" },
    { rank = 5, kind = "frame", short = "Driftwood frame" },
    { rank = 8, kind = "frame", short = "Dungeon Iron frame" },
    { rank = 12, kind = "frame", short = "Gilded frame" },
    { rank = 20, kind = "frame", short = "Bone and Tusk frame" },
    { rank = 30, kind = "piece", key = "skin:grand_sleepy_pink" },
}

local KIND_ORDER = { piece = 1, frame = 2 }  -- (within a rank: the picture piece, the frame, then the rest)
table.sort(ns.RANK_PERKS, function(a, b)
    if a.rank ~= b.rank then return a.rank < b.rank end
    local ka, kb = KIND_ORDER[a.kind] or 3, KIND_ORDER[b.kind] or 3
    if ka ~= kb then return ka < kb end
    return (a.short or a.key or "") < (b.short or b.key or "")
end)

-- A perk's short label, for the lists: a picture piece's name in its rarity's colour (MintArt.lua: loaded later, so
-- looked up when asked), else its short.
function ns.PerkLabel(perk)
    if perk.kind == "piece" then
        local found = ns.OptionByKey and ns.OptionByKey(perk.key)
        if found then return ("|c%s%s|r"):format(ns.RARITY_COLORS and ns.RARITY_COLORS[found.option.rarity] or "ffffffff", found.option.name) end
    end
    return perk.short or perk.text or "?"
end
-- What a rank brings, as one line ("Sea Dog Grin, Polaroid frame, 2 crayons"), or nil.
function ns.RankPerksLine(rank)
    local labels = {}
    for _, perk in ipairs(ns.RANK_PERKS) do
        if perk.rank == rank then labels[#labels + 1] = ns.PerkLabel(perk) end
    end
    return #labels > 0 and table.concat(labels, ", ") or nil
end
-- The perks after a rank, summed up: "24 more ranks: 16 picture pieces, 2 frames, 3 name colours, luck, a style".
local SUM = { { "piece", "picture piece", "picture pieces" }, { "frame", "frame", "frames" }, { "nameColor", "name colour", "name colours" },
    { "ogreStyle", "a style", "styles" }, { "crayons", "crayons", "crayons" }, { "voices", "voices", "voices" }, { "luck", "luck", "luck" },
    { "wallpaper", "a wallpaper", "wallpapers" } }
local COUNTED = { piece = true, frame = true, nameColor = true }
function ns.RankPerksAfter(rank)
    local counts, ranks = {}, {}
    for _, perk in ipairs(ns.RANK_PERKS) do
        if perk.rank > rank then
            counts[perk.kind] = (counts[perk.kind] or 0) + 1
            ranks[perk.rank] = true
        end
    end
    local parts, n = {}, 0
    for _ in pairs(ranks) do n = n + 1 end
    if n == 0 then return nil end
    for _, s in ipairs(SUM) do
        local c = counts[s[1]]
        if c then parts[#parts + 1] = COUNTED[s[1]] and ("%d %s"):format(c, c == 1 and s[2] or s[3]) or (c == 1 and s[2] or s[3]) end
    end
    return ("%d more rank%s: %s"):format(n, n == 1 and "" or "s", table.concat(parts, ", "))
end

-- Someone's rank: you (key nil) or a synced guildmate. Returns the rank's entry, the next one's (nil at the top)
-- and their lifetime points.
function ns.GetRank(key)
    local points
    if key then
        local friend = KillTrackerFriends[key]
        points = friend and ns.FriendScore(friend).earned or 0
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
-- Your ogre's styles (the Overview's EDIT, its STYLE row): painted always; sketch and crayon from their Ogre Ranks
-- (the ogreStyle perks, by rank for everyone). OgreStyleRank: the rank one comes at.
function ns.OgreStyleRank(edition)
    for _, perk in ipairs(ns.RANK_PERKS) do
        if perk.kind == "ogreStyle" and perk.value == edition then return perk.rank end
    end
end
function ns.OgreStyleUnlocked(edition)
    if not edition then return true end
    local rank = ns.OgreStyleRank(edition)
    return rank ~= nil and ns.GetRank().rank >= rank
end

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
function ns.CheckRank()
    local db = KillTrackerDB
    if not db or not ns.GetPoints then return end
    local current = ns.GetRank()
    local seen = db.rank
    db.rank = current.rank
    -- (the picture pieces your rank has reached: the piece perks; caught up on login, quietly: only a new rank's are announced)
    for _, perk in ipairs(ns.RANK_PERKS) do
        if perk.kind == "piece" and current.rank >= perk.rank and ns.UnlockOption then ns.UnlockOption(perk.key, seen == nil or perk.rank <= seen) end
    end
    if not seen or current.rank <= seen then return end
    local bonks = 0
    for rank = seen + 1, current.rank do
        if ns.AddEvent then ns.AddEvent("K", rank) end
        bonks = bonks + (rank % 5 == 0 and BONKS_BIG or BONKS)
    end
    if ns.AddIngredient then ns.AddIngredient("bonk", bonks, true) end
    local unlocked = {}
    for rank = seen + 1, current.rank do unlocked[#unlocked + 1] = ns.RankPerksLine(rank) end
    if not (ns.RankLocked and ns.RankLocked("pixcollection")) then  -- (no Dream Bed talk before it's open: Onboarding.lua)
        unlocked[#unlocked + 1] = ("%d %s for the Dream Bed"):format(bonks, bonks == 1 and "Bonk" or "Bonks")
    end
    ns.ShowToast("achievement", ("Rank %d!"):format(current.rank), current.title, ns.RankPerksLine(current.rank) or unlocked[1])
    ns.Print(("You reached rank %d: |cffff8000%s|r%s"):format(current.rank, current.title,
        #unlocked > 0 and (". Unlocked: " .. table.concat(unlocked, "; ")) or ""))
    if ns.OnKillsChanged then ns.OnKillsChanged() end
end

table.insert(ns.KillHandlers, function() ns.CheckRank() end)
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_LOGIN")
watcher:SetScript("OnEvent", function() C_Timer.After(2, ns.CheckRank) end)  -- after the login catch-ups
