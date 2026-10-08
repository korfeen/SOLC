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
    { rank = 4, kind = "nameColor", value = { 0.8, 0.84, 0.9 }, text = "Silver name on your card" },
    { rank = 6, kind = "discount", value = 0.1, text = "Pictures cost 10% less" },
    { rank = 8, kind = "voices", value = 2, text = "Ogre voices on clicks twice as often" },
    { rank = 10, kind = "luck", value = 1.25, text = "Lucky minting: epic and legendary layers 25% likelier" },
    { rank = 12, kind = "nameColor", value = { 1, 0.82, 0.25 }, text = "Gold name on your card" },
    { rank = 12, kind = "crayons", value = 2, text = "Two more ogre crayons" },
    { rank = 14, kind = "discount", value = 0.2, text = "Pictures cost 20% less" },
    { rank = 16, kind = "voices", value = 3, text = "Ogre voices on clicks three times as often" },
    { rank = 18, kind = "luck", value = 1.5, text = "Luckier minting: epic and legendary layers 50% likelier" },
    { rank = 20, kind = "crayons", value = 3, text = "Three more ogre crayons" },
    { rank = 22, kind = "discount", value = 0.3, text = "Pictures cost 30% less" },
    { rank = 24, kind = "nameColor", value = { 1, 0.5, 0.2 }, text = "Ogre-orange name on your card" },
    { rank = 26, kind = "luck", value = 2, text = "Luckiest minting: epic and legendary layers twice as likely" },
    { rank = 30, kind = "nameColor", value = { 1, 0.4, 0.75 }, text = "Grand Sleepy Ogre pink name on your card" },
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
