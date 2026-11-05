// One-off (2026-11-05): the Deeds list shows every deed there is, not only the started ones: the unstarted ones dimmed
// under them (feats, then creature kinds, then tribes, from the mob data). A secret feat (secret = true) hides its name
// and tiers till it's started.
const fs = require("fs");
const path = require("path");
process.chdir(path.join(__dirname, ".."));
function edit(file, pairs) {
  let s = fs.readFileSync(file, "utf8");
  const nl = s.includes("\r\n") ? "\r\n" : "\n";
  for (const [a, b] of pairs) {
    const from = a.replace(/\n/g, nl), to = b.replace(/\n/g, nl);
    const n = s.split(from).length - 1;
    if (n !== 1) throw Error(`${file}: found ${n} times: ${a.slice(0, 70)}`);
    s = s.replace(from, () => to);
  }
  fs.writeFileSync(file, s);
}

edit("Guild.lua", [[
`    table.sort(targets.byType, function(a, b) return a.type < b.type end)
    return targets
end`,
`    table.sort(targets.byType, function(a, b) return a.type < b.type end)
    return targets
end
ns.DeedTargets = Targets  -- (every creature kind and tribe: the Deeds list's unstarted ones, Achievements.lua)`]]);

edit("Achievements.lua", [
[`    { key = "shop", label = "Spent in the Pro Shop", unit = "points",`,
 `    { key = "shop", label = "Spent in the Pro Shop", unit = "points", secret = true,`],
[`    { key = "buddy", label = "Dungeons with one guildmate", unit = "clears together",`,
 `    { key = "buddy", label = "Dungeons with one guildmate", unit = "clears together", secret = true,`],
[`-- Feats: { key, label (the row's name), unit (what's counted, for "5 leaders"), count(source, facts) -> number or
-- nil (unknown for this source: the row isn't shown), tiers = { { target, name, points } } }.`,
 `-- Feats: { key, label (the row's name), unit (what's counted, for "5 leaders"), count(source, facts) -> number or
-- nil (unknown for this source: the row isn't shown), tiers = { { target, name, points } }, secret (its name and tiers
-- hidden on the Deeds page till it's started) }.`],
[`    for _, dim in ipairs(DIMENSIONS) do
        for category, kills in pairs(counts[dim.key]) do
            local list = {}
            for i, tier in ipairs(TiersOf(dim, category)) do
                local id = AchievementID(dim.key, category, tier.kills)
                list[i] = { id, TierName(dim.key, category, i), tier.kills, ns.AchievementPoints(id) }
            end
            Row({ category = ShortName(category), tribe = dim.key == "faction", unit = "kills", kills = kills }, list)
        end
    end
    for _, feat in ipairs(FEATS) do
        local count = feat.count(source, facts)
        if count and count > 0 then
            local list = {}
            for i, tier in ipairs(feat.tiers) do list[i] = { AchievementID("feat", feat.key, tier[1]), tier[2], tier[1], tier[3] } end
            Row({ category = feat.label, feat = true, unit = feat.unit, kills = count }, list)
        end
    end
    return rows`,
`    local function KillRow(dim, category, kills)
        local list = {}
        for i, tier in ipairs(TiersOf(dim, category)) do
            local id = AchievementID(dim.key, category, tier.kills)
            list[i] = { id, TierName(dim.key, category, i), tier.kills, ns.AchievementPoints(id) }
        end
        Row({ category = ShortName(category), tribe = dim.key == "faction", unit = "kills", kills = kills, unstarted = kills == 0 }, list)
    end
    for _, dim in ipairs(DIMENSIONS) do
        for category, kills in pairs(counts[dim.key]) do KillRow(dim, category, kills) end
    end
    -- Every deed there is, not only the started ones (unstarted: 0 so far): each feat, and every creature kind and
    -- enemy tribe in the mob data (Guild.lua's ns.DeedTargets). A secret feat keeps its name and tiers to itself till then.
    local targets = ns.DeedTargets and ns.DeedTargets()
    for _, dim in ipairs(targets and DIMENSIONS or {}) do
        for _, category in pairs(dim.key == "subtype" and targets.kinds or targets.tribes) do
            if not counts[dim.key][category] and not ns.NO_AWARDS[category] then KillRow(dim, category, 0) end
        end
    end
    for _, feat in ipairs(FEATS) do
        local count = feat.count(source, facts)
        if count then
            local list = {}
            for i, tier in ipairs(feat.tiers) do list[i] = { AchievementID("feat", feat.key, tier[1]), tier[2], tier[1], tier[3] } end
            local secret = feat.secret and count == 0
            Row({ category = secret and "A secret deed" or feat.label, feat = true, unit = feat.unit, kills = count,
                unstarted = count == 0, secret = secret }, list)
        end
    end
    return rows`],
]);

edit("UI.lua", [[
`        for _, progress in ipairs(ns.GetAchievementProgress(Source())) do
            -- Sort key: closest to its next tier first, fully completed categories last.
            local sortKey = progress.next and progress.kills / progress.next.kills or -1
            rows[#rows + 1] = { label = progress.category, count = progress.kills, achievement = progress, sortKey = sortKey }
        end`,
`        for _, progress in ipairs(ns.GetAchievementProgress(Source())) do
            -- Sort key: closest to its next tier first, fully completed ones next; then the unstarted ones, dimmed:
            -- feats, creature kinds, tribes.
            local sortKey = progress.next and progress.kills / progress.next.kills or -1
            if progress.unstarted then sortKey = progress.feat and -2 or progress.tribe and -4 or -3 end
            rows[#rows + 1] = { label = progress.unstarted and ("|cff8c8273%s|r"):format(progress.category) or progress.category,
                count = progress.kills, achievement = progress, sortKey = sortKey,
                hint = progress.secret and "A secret deed: nobody says how it starts." or progress.unstarted and "Not started yet." or nil }
        end`]]);

edit("SmashPage.lua", [
[`    for _, progress in ipairs(ns.GetAchievementProgress(List.Source())) do
        if progress.next then list[#list + 1] = progress end
    end`,
`    for _, progress in ipairs(ns.GetAchievementProgress(List.Source())) do
        if progress.next and not progress.unstarted then list[#list + 1] = progress end
    end`],
[`    elseif d and d.achievement then
        local progress = d.achievement
        name = progress.category`,
`    elseif d and d.achievement and d.achievement.secret then  -- (a secret deed, not started: nothing given away)
        name = d.achievement.category
        ShowPanel(page, { { "A secret deed", GOLD }, " ", "Nobody tells you how this one starts.", "Reginald knows. He isn't saying." })
        SetInfo(page, { "Not started yet" })
    elseif d and d.achievement then
        local progress = d.achievement
        name = progress.category`],
]);
console.log("done");
