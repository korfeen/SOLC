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

-- Name colours for the profile header (picked in its edit mode, ProfileHeader.lua): white for everyone, the rank
-- perks' colours once reached, and more bought with points (cost). KillTrackerDB.nameColors = { [id] = true } for
-- the bought ones; the one picked is KillTrackerDB.card.nameColor (synced).
ns.NAME_COLORS = { { id = "white", name = "White", value = { 1, 1, 1 } } }
for _, perk in ipairs(ns.RANK_PERKS) do
    if perk.kind == "nameColor" then
        ns.NAME_COLORS[#ns.NAME_COLORS + 1] = { id = perk.id, name = perk.name, value = perk.value, rank = perk.rank }
    end
end
for _, bought in ipairs({
    { id = "swamp", name = "Swamp Green", value = { 0.45, 0.85, 0.35 }, cost = 250 },
    { id = "sky", name = "Sky Blue", value = { 0.45, 0.75, 1 }, cost = 250 },
    { id = "mud", name = "Mud Brown", value = { 0.72, 0.52, 0.32 }, cost = 250 },
    { id = "lava", name = "Lava Red", value = { 1, 0.3, 0.25 }, cost = 500 },
    { id = "purple", name = "Royal Purple", value = { 0.7, 0.45, 1 }, cost = 500 },
    { id = "mint", name = "Fresh Mint", value = { 0.4, 1, 0.8 }, cost = 1000 },
    { id = "fel", name = "Fel Glow", value = { 0.6, 1, 0.1 }, cost = 1000 },
}) do ns.NAME_COLORS[#ns.NAME_COLORS + 1] = bought end

function ns.FindNameColor(id)
    for _, entry in ipairs(ns.NAME_COLORS) do
        if entry.id == id then return entry end
    end
end

-- Whether you can use a name colour (reached its rank, or bought it).
function ns.HasNameColor(entry)
    if entry.rank then return ns.GetRank().rank >= entry.rank end
    if entry.cost then return (KillTrackerDB.nameColors or {})[entry.id] == true end
    return true
end

-- Buys a name colour with points. Returns true, or false and why not.
function ns.BuyNameColor(id)
    local db = KillTrackerDB
    local entry = ns.FindNameColor(id)
    if not entry or not entry.cost then return false, "That colour can't be bought." end
    if ns.HasNameColor(entry) then return false, "You already have it." end
    local balance = ns.GetPoints().balance
    if balance < entry.cost then return false, ("Not enough points (%d of %d)."):format(balance, entry.cost) end
    db.points.spent = db.points.spent + entry.cost
    db.nameColors = db.nameColors or {}
    db.nameColors[id] = true
    return true
end

-- The colour of someone's name (RGB): the one they picked (yours only while you still have it), else their best
-- rank colour, else white.
function ns.GetNameColor(key)
    local card = key and KillTrackerFriends[key] and KillTrackerFriends[key].card or not key and KillTrackerDB.card
    local entry = card and card.nameColor and ns.FindNameColor(card.nameColor)
    if entry and (key or ns.HasNameColor(entry)) then return entry.value end
    return ns.RankPerk("nameColor", ns.GetRank(key).rank) or ns.NAME_COLORS[1].value
end

-- Watches your rank: a popup and a feed event (K, a = rank) each time it goes up. KillTrackerDB.rank is the last
-- rank seen (nil until the first check, which only records it).
function ns.CheckRank()
    local db = KillTrackerDB
    if not db or not ns.GetPoints then return end
    local current = ns.GetRank()
    local seen = db.rank
    db.rank = current.rank
    if not seen or current.rank <= seen then return end
    for rank = seen + 1, current.rank do
        if ns.AddEvent then ns.AddEvent("K", rank) end
    end
    local unlocked = {}
    for _, perk in ipairs(ns.RANK_PERKS) do
        if perk.rank > seen and perk.rank <= current.rank then unlocked[#unlocked + 1] = perk.text end
    end
    ns.ShowToast("achievement", ("Rank %d!"):format(current.rank), current.title, unlocked[1] or "Keep smashing.")
    ns.Print(("You reached rank %d: |cffff8000%s|r%s"):format(current.rank, current.title,
        #unlocked > 0 and (". Unlocked: " .. table.concat(unlocked, "; ")) or ""))
    if ns.OnKillsChanged then ns.OnKillsChanged() end
end

table.insert(ns.KillHandlers, function() ns.CheckRank() end)
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_LOGIN")
watcher:SetScript("OnEvent", function() C_Timer.After(2, ns.CheckRank) end)  -- after the login catch-ups
