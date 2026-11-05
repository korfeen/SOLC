// One-off (2026-11-05): bounty chests that open. A claimed poster's chest and the guild's milestone chest go with the
// dungeon chests (KillTrackerDB.chests: { dungeon = ns.BOUNTY or ns.GUILD_BOUNTY, poster = its id }), show in the
// Inventory and open in the chest show: coins, the tier's stories and bonks, and by chance (for sure after PITY without)
// one of that poster's own pieces (its ogre's: a creature's hat/onesie/toy, a faction's outfit, an odd job's prop, a
// wanted poster's dungeon set) - all had, any poster's. The guild chest: a piece for sure. And the "Wanted posters
// claimed" deeds (the Wanted Poster frame's unlock).
const fs = require("fs");
const path = require("path");
process.chdir(path.join(__dirname, ".."));
function edit(f, pairs) {
  let s = fs.readFileSync(f, "utf8");
  const nl = s.includes("\r\n") ? "\r\n" : "\n";
  for (let [a, b] of pairs) {
    a = a.split("\n").join(nl); b = b.split("\n").join(nl);
    if (s.split(a).length !== 2) throw Error(f + ": " + a.slice(0, 70));
    s = s.replace(a, () => b);
  }
  fs.writeFileSync(f, s);
}

edit("Unlocks.lua", [
[`-- Opens one of your chests of a dungeon.`,
`-- Bounty chests (Posters.lua): a claimed poster's ({ dungeon = ns.BOUNTY, time, tier, poster = its id }, its tier
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
-- A chest's name, for its tile and its show: "Deadmines", "Bounty", "Guild bounty", "Ogre Godz tribute".
function ns.ChestName(key)
    if key == ns.TRIBUTE then return "Ogre Godz tribute" end
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
    local items = {}
    local own = Locked(ns.PosterPieces and chest.poster and ns.PosterPieces(chest.poster) or {})
    local list = #own > 0 and own or Locked(ns.PosterPieces and ns.PosterPieces() or {})
    db.chestPity = db.chestPity or {}
    local dry = db.chestPity[ns.BOUNTY] or 0
    if #list > 0 and (guild or dry >= PITY or math.random() < (spec.piece or 0)) then
        local unlocked = list[math.random(#list)]
        ns.UnlockOption(ns.OptionKey(unlocked.layer.key, unlocked.option))
        items[#items + 1] = { kind = "unlock", layer = unlocked.layer, option = unlocked.option }
        if not guild then db.chestPity[ns.BOUNTY] = 0 end
    elseif not guild then
        db.chestPity[ns.BOUNTY] = dry + 1
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

-- Opens one of your chests of a dungeon.`],
[`    if dungeonKey == ns.TRIBUTE then return OpenTribute(chest) end`,
`    if dungeonKey == ns.TRIBUTE then return OpenTribute(chest) end
    if dungeonKey == ns.BOUNTY or dungeonKey == ns.GUILD_BOUNTY then return OpenBounty(chest) end`],
[`    local items, coins = {}, Coins(dungeonKey, tier)
    local function Locked(list)
        local out = {}
        for _, unlocked in ipairs(list) do
            if not ns.IsUnlocked(ns.OptionKey(unlocked.layer.key, unlocked.option)) then out[#out + 1] = unlocked end
        end
        return out
    end
`, `    local items, coins = {}, Coins(dungeonKey, tier)
`],
]);

edit("Posters.lua", [
[`-- the moment its goal is reached: points by its tier (the guild's "Reward" setting times TIER_REWARD) and a bounty
-- chest (KillTrackerDB.bountyChests, opened on the board).`,
`-- the moment its goal is reached: points by its tier (the guild's "Reward" setting times TIER_REWARD), a Bedtime Story
-- and a bounty chest (Unlocks.lua: in your Inventory, with a chance at the poster's own pieces, ns.PosterPieces).`],
[`    KillTrackerDB.bountyChests = (KillTrackerDB.bountyChests or 0) + 1`,
`    if ns.AddBountyChest then ns.AddBountyChest(p.id) end
    if p.bounty.kind == "wanted" and ns.Tally then ns.Tally("wanted") end  -- (the Wanted posters claimed deeds: its frame)`],
[`("+%d points, a bounty chest and a Bedtime Story"):format(reward))`,
`("+%d points, a Bedtime Story and a bounty chest (in your Inventory)"):format(reward))`],
[`-- ones reached before their first claim. The last milestone's is the guild bounty chest
-- (KillTrackerDB.guildBountyChests, opened on the board).`,
`-- ones reached before their first claim. The last milestone's is the guild bounty chest (Unlocks.lua: in your
-- Inventory, a piece for sure).`],
[`            if m.guildChest then KillTrackerDB.guildBountyChests = (KillTrackerDB.guildBountyChests or 0) + 1 end`,
`            if m.guildChest and ns.AddGuildBountyChest then ns.AddGuildBountyChest() end`],
[`function ns.WantedPicture(id)`,
`-- A poster's own pieces, { { layer, option } } (its bounty chest's: Unlocks.lua): its ogre's - a creature's hat, onesie
-- and toy, a faction's outfit, an odd job's prop - or a wanted poster's dungeon set. No id: every poster ogre's.
local function PiecesOf(piece, out)
    for _, layer in ipairs(ns.MintLayers or {}) do
        for _, option in ipairs(layer.options) do
            if option.id == piece or option.id:sub(1, #piece + 1) == piece .. "_" then out[#out + 1] = { layer = layer, option = option } end
        end
    end
    return out
end
function ns.PosterPieces(id)
    local out = {}
    if not id then
        local seen = {}
        for _, piece in pairs(POSTER_OGRE) do
            if not seen[piece] then seen[piece] = true PiecesOf(piece, out) end
        end
        return out
    end
    local base = id:match("^X%w+_(.+)$")  -- (an officer's own poster: its bounty's)
    if base then return ns.PosterPieces(base) end
    local key = id:match("^wanted_(%w+)$")
    if key then return ns.UnlockOptions("clear:" .. key) end
    local kind = id:match("^kind_(%w+)$")  -- (a custom creature poster: that creature's, if it has any)
    local piece = POSTER_OGRE[id] or (id:find("^rare_") and POSTER_OGRE.rares) or (kind and "crit_" .. kind)
    return piece and PiecesOf(piece, out) or out
end
function ns.WantedPicture(id)`],
]);

edit("Achievements.lua", [
[`    bounties = "Club life", chests = "Club life",`, `    bounties = "Club life", wanted = "Club life", chests = "Club life",`],
[`    { key = "chests", label = "Chests opened",`,
`    { key = "wanted", label = "Wanted posters claimed", unit = "wanted posters", count = function(_, f) return f.wanted end, tiers = {
        { 1, "Dead Or Alive", 10 }, { 10, "Posse Leader", 30 }, { 25, "Hang 'Em High", 60 } } },
    { key = "chests", label = "Chests opened",`],
[`        facts.bounties, facts.chests = tally.bounties or 0, tally.chests or 0`,
`        facts.bounties, facts.chests, facts.wanted = tally.bounties or 0, tally.chests or 0, tally.wanted or 0`],
]);

edit("HuntsBoard.lua", [
[`        local chests, guildChests = KillTrackerDB.bountyChests or 0, KillTrackerDB.guildBountyChests or 0
        self.chests:SetText((chests + guildChests > 0) and ("|c" .. AMBER_CODE .. "%d|r bounty chest%s%s waiting"):format(chests,
            chests == 1 and "" or "s", guildChests > 0 and (" and |cffc070ff%d guild chest%s|r"):format(guildChests,
            guildChests == 1 and "" or "s") or "") or "")`,
`        local counts = ns.ChestCounts()  -- (bounty chests: opened in your Inventory, Unlocks.lua)
        local chests, guildChests = counts[ns.BOUNTY] or 0, counts[ns.GUILD_BOUNTY] or 0
        self.chests:SetText((chests + guildChests > 0) and ("|c" .. AMBER_CODE .. "%d|r bounty chest%s%s waiting in your Inventory"):format(chests,
            chests == 1 and "" or "s", guildChests > 0 and (" and |cffc070ff%d guild chest%s|r"):format(guildChests,
            guildChests == 1 and "" or "s") or "") or "")`],
]);

edit("Gallery.lua", [
[`                    thumb.dungeonName = tribute and "Ogre Godz tribute" or d and d.name or "A dungeon"`,
`                    thumb.dungeonName = ns.ChestName(entry.chest)`],
]);
edit("PixPage.lua", [
[`                tile.dungeonName = tribute and "Ogre Godz tribute" or dungeon and dungeon.name or "A dungeon"`,
`                tile.dungeonName = ns.ChestName(picture.chest)`],
]);
edit("Chests.lua", [
[`    panel.title:SetText((dungeon and dungeon.name or dungeonKey) .. " chest")`,
`    panel.title:SetText(ns.ChestName(dungeonKey) .. " chest")`],
[`    panel.screenName = dungeonKey == ns.TRIBUTE and "Ogre Godz Tribute" or ((dungeon and dungeon.name or "Dungeon") .. " Chest")`,
`    panel.screenName = dungeonKey == ns.TRIBUTE and "Ogre Godz Tribute" or (ns.ChestName(dungeonKey) .. " Chest")`],
]);
console.log("done");
