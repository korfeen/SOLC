// One-off (2026-11-07): fishing chests. Each fish caught (LifeStats.lua) has a 1 in 50 chance of a fishing chest, more
// for each fishing piece your ogre wears (+25% a piece). It joins the chests in your Inventory (Unlocks.lua: dungeon
// ns.FISHING) and opens like the bounty chests: coins, the tier's stories and bonks, and by chance (for sure after PITY
// without) a fishing piece - the angler set ("chest:fishing", only from these) or the Fishing Rod.
const fs = require("fs");
const path = require("path");
process.chdir(path.join(__dirname, ".."));
function edit(f, pairs) {
  let s = fs.readFileSync(f, "utf8");
  const nl = s.includes("\r\n") ? "\r\n" : "\n";
  for (let [a, b] of pairs) {
    a = a.split("\n").join(nl); b = b.split("\n").join(nl);
    if (s.split(a).length !== 2) throw Error(f + ": " + a.slice(0, 60));
    s = s.replace(a, () => b);
  }
  fs.writeFileSync(f, s);
}
edit("Unlocks.lua", [
[`-- A chest's name, for its tile and its show: "Deadmines", "Bounty", "Guild bounty", "Ogre Godz tribute".
function ns.ChestName(key)
    if key == ns.TRIBUTE then return "Ogre Godz tribute" end`,
`-- Fishing chests: each fish caught (LifeStats.lua) has FISH_CHANCE of one, FISH_GEAR_BONUS more for each fishing piece
-- your ogre wears (your Overview card's: FISHING_GEAR). Inside, like a bounty chest's: coins, the tier's stories and
-- bonks, and by the tier's chance (for sure after PITY without) a fishing piece: the angler set (unlock "chest:fishing",
-- only from these) or the Fishing Rod.
ns.FISHING = "fishing"
local FISH_CHANCE, FISH_GEAR_BONUS = 1 / 50, 0.25
local FISHING_GEAR = { hunt_angler_head = true, hunt_angler_body = true, prop_landing_net = true, bg_fishing_pier = true,
    prop_fish = true, gacha_head_fishing_hat = true, gacha_head_souwester = true, gacha_acc_trophy_fish = true,
    gacha_outfit_sailor_stripes = true }
local FISHING_EXTRA = { "accessory:prop_fish" }  -- (fishing pieces from elsewhere a fishing chest can give too)
-- The fishing chest's chance for one fish, and how many fishing pieces your ogre wears.
function ns.FishingChestChance()
    local worn = 0
    local ogre = KillTrackerDB and KillTrackerDB.card and KillTrackerDB.card.ogre
    for _, id in pairs(ogre or {}) do if FISHING_GEAR[id] then worn = worn + 1 end end
    return FISH_CHANCE * (1 + FISH_GEAR_BONUS * worn), worn
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
    if key == ns.FISHING then return "Fishing" end`],
[`    local guild = chest.dungeon == ns.GUILD_BOUNTY
    local items = {}
    local own = Locked(ns.PosterPieces and chest.poster and ns.PosterPieces(chest.poster) or {})
    local list = #own > 0 and own or Locked(ns.PosterPieces and ns.PosterPieces() or {})
    db.chestPity = db.chestPity or {}
    local dry = db.chestPity[ns.BOUNTY] or 0`,
`    local guild = chest.dungeon == ns.GUILD_BOUNTY
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
    local dry = db.chestPity[pityKey] or 0`],
[`        if not guild then db.chestPity[ns.BOUNTY] = 0 end
    elseif not guild then
        db.chestPity[ns.BOUNTY] = dry + 1
    end`,
`        if not guild then db.chestPity[pityKey] = 0 end
    elseif not guild then
        db.chestPity[pityKey] = dry + 1
    end`],
[`    if dungeonKey == ns.BOUNTY or dungeonKey == ns.GUILD_BOUNTY then return OpenBounty(chest) end`,
 `    if dungeonKey == ns.BOUNTY or dungeonKey == ns.GUILD_BOUNTY or dungeonKey == ns.FISHING then return OpenBounty(chest) end`],
]);
edit("LifeStats.lua", [[
`    if ns.OnBountyEvent then ns.OnBountyEvent(kind == "fish" and "fish" or "gather") end  -- (the odd-job posters)`,
`    if ns.OnBountyEvent then ns.OnBountyEvent(kind == "fish" and "fish" or "gather") end  -- (the odd-job posters)
    if kind == "fish" and ns.OnFishCaught then ns.OnFishCaught() end  -- (a fishing chest, by chance: Unlocks.lua)`]]);
edit("PixCollection.lua", [[
`    if kind == 'gacha' then return 'From the claw machine.' end`,
`    if kind == 'gacha' then return 'From the claw machine.' end
    if unlock == 'chest:fishing' then return 'Find it in fishing chests (catch fish; fishing gear on your ogre helps).' end`]]);
console.log("done");
