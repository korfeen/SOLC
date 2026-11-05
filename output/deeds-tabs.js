// One-off (2026-11-05), on top of all-deeds.js: the Deeds page gets MINE (the started ones, as before) and ALL (every
// deed, in groups you click into: Creatures, Tribes, Hunting, Rares, Dungeons, Pictures, Professions, Club life,
// Secrets; unstarted ones dimmed). A secret deed shows nothing till started; clicking it gets Reginald's hint.
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

edit("Achievements.lua", [
[`{ key = "shop", label = "Spent in the Pro Shop", unit = "points", secret = true,`,
 `{ key = "shop", label = "Spent in the Pro Shop", unit = "points", secret = true,
        hint = "Money talks, darling. In my shop it positively sings.",`],
[`{ key = "buddy", label = "Dungeons with one guildmate", unit = "clears together", secret = true,`,
 `{ key = "buddy", label = "Dungeons with one guildmate", unit = "clears together", secret = true,
        hint = "Some members go into the dark together. Again and again. I find it touching. Briefly.",`],
[`-- hidden on the Deeds page till it's started) }.`,
 `-- hidden on the Deeds page till it's started; hint: Reginald's nudge when you click it) }.
-- The Deeds page's ALL groups (a feat's own group, else by its key; dungeon and zone feats have theirs).
local FEAT_GROUPS = { pictures = "Pictures", epic = "Pictures", legendary = "Pictures", showcase = "Pictures", puzzles = "Pictures",
    herbs = "Professions", ore = "Professions", skins = "Professions", fish = "Professions", craft = "Professions",
    bounties = "Club life", chests = "Club life", shop = "Club life", buddy = "Club life" }
ns.DEED_GROUPS = { "Creatures", "Tribes", "Hunting", "Rares", "Dungeons", "Pictures", "Professions", "Club life", "Secrets" }`],
[`        Row({ category = ShortName(category), tribe = dim.key == "faction", unit = "kills", kills = kills, unstarted = kills == 0 }, list)`,
 `        Row({ category = ShortName(category), tribe = dim.key == "faction", unit = "kills", kills = kills, unstarted = kills == 0,
            group = dim.key == "faction" and "Tribes" or "Creatures" }, list)`],
[`            Row({ category = secret and "A secret deed" or feat.label, feat = true, unit = feat.unit, kills = count,
                unstarted = count == 0, secret = secret }, list)`,
 `            local group = secret and "Secrets" or feat.group or (feat.dungeon and "Dungeons") or (feat.zoneRares and "Rares")
                or FEAT_GROUPS[feat.key] or "Hunting"
            Row({ category = secret and "A secret deed" or feat.label, feat = true, unit = feat.unit, kills = count,
                unstarted = count == 0, secret = secret, hint = secret and feat.hint or nil, group = group }, list)`],
]);

edit("UI.lua", [
[`    if state.view == "achievements" then
        for _, progress in ipairs(ns.GetAchievementProgress(Source())) do
            -- Sort key: closest to its next tier first, fully completed ones next; then the unstarted ones, dimmed:
            -- feats, creature kinds, tribes.
            local sortKey = progress.next and progress.kills / progress.next.kills or -1
            if progress.unstarted then sortKey = progress.feat and -2 or progress.tribe and -4 or -3 end
            rows[#rows + 1] = { label = progress.unstarted and ("|cff8c8273%s|r"):format(progress.category) or progress.category,
                count = progress.kills, achievement = progress, sortKey = sortKey,
                hint = progress.secret and "A secret deed: nobody says how it starts." or progress.unstarted and "Not started yet." or nil }
        end`,
`    -- ALL deeds, at the top: the groups (Achievements.lua's ns.DEED_GROUPS), each with how many of its deeds are begun.
    if state.view == "alldeeds" and #state.path == 0 then
        local all, begun = {}, {}
        for _, progress in ipairs(ns.GetAchievementProgress(Source())) do
            local g = progress.group or "Hunting"
            all[g] = (all[g] or 0) + 1
            if not progress.unstarted then begun[g] = (begun[g] or 0) + 1 end
        end
        for _, g in ipairs(ns.DEED_GROUPS or {}) do
            if all[g] then
                rows[#rows + 1] = { label = g, count = begun[g] or 0, groupAll = all[g], category = g, deedGroup = true,
                    hint = g == "Secrets" and "Deeds nobody tells you about." or "Click to see them." }
            end
        end
        return rows
    end
    -- MINE: the deeds you've begun; ALL inside a group: all of its deeds, the unstarted ones dimmed at the end.
    if state.view == "achievements" or state.view == "alldeeds" then
        local group = state.view == "alldeeds" and state.path[1].value
        for _, progress in ipairs(ns.GetAchievementProgress(Source())) do
            if (group and (progress.group or "Hunting") == group) or (not group and not progress.unstarted) then
                -- Sort key: closest to its next tier first, fully completed ones next, the unstarted ones last.
                local sortKey = progress.unstarted and -2 or progress.next and progress.kills / progress.next.kills or -1
                rows[#rows + 1] = { label = progress.category, count = progress.kills, achievement = progress, sortKey = sortKey }
            end
        end`],
[`    elseif d.achievement then
        local progress = d.achievement
        row.label:SetText(progress.tribe and ("%s  |cff999999tribe|r"):format(progress.category)
            or ("%s  |cff999999%d/%d|r"):format(progress.category, progress.earned, #progress.tiers))`,
`    elseif d.deedGroup then  -- (ALL deeds' groups: how many of their deeds you've begun)
        row.label:SetText(d.label)
        row.count:SetText(d.label == "Secrets" and ("%d of %d found"):format(d.count, d.groupAll) or ("%d/%d"):format(d.count, d.groupAll))
        barFraction = d.count / math.max(1, d.groupAll)
        row.bar:SetVertexColor(1, 0.5, 0.1, 0.45)
    elseif d.achievement then
        local progress = d.achievement
        local name = progress.unstarted and ("|cff8c8273%s|r"):format(progress.category) or progress.category  -- (not begun: dimmed)
        row.label:SetText(progress.tribe and ("%s  |cff999999tribe|r"):format(name)
            or progress.secret and name
            or ("%s  |cff999999%d/%d|r"):format(name, progress.earned, #progress.tiers))`],
[`local function ShowAchievementTooltip(row)
    local progress = row.data.achievement
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")`,
`local function ShowAchievementTooltip(row)
    local progress = row.data.achievement
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    if progress.secret then  -- (not begun: nothing given away)
        GameTooltip:AddLine("A secret deed")
        GameTooltip:AddLine("Nobody tells you how this one starts. Click it and Reginald might.", 0.6, 0.6, 0.6, true)
        GameTooltip:Show()
        return
    end`],
]);

edit("SmashPage.lua", [
[`    { key = "deeds", label = "Deeds", order = 3, covers = { achievements = true }, deeds = true,
        tabs = { { "achievements", "DEEDS", "BRAG" } }, tabFor = { achievements = "achievements" } },`,
 `    { key = "deeds", label = "Deeds", order = 3, covers = { achievements = true }, deeds = true,
        tabs = { { "achievements", "MINE", "BRAG" }, { "alldeeds", "ALL", "ALL" } }, tabFor = { achievements = "achievements" } },`],
[`                elseif d.mob or d.leader or d.rare or d.player or d.achievement then
                    page.pick = page.pick ~= d and d or nil
                end`,
 `                elseif d.mob or d.leader or d.rare or d.player or d.achievement then
                    page.pick = page.pick ~= d and d or nil
                    -- (a secret deed: Reginald's nudge, Onboarding.lua)
                    if d.achievement and d.achievement.secret and d.achievement.hint and ns.StewardSay then ns.StewardSay(d.achievement.hint) end
                end`],
[`        local root = state.view == "achievements" and "All deeds" or state.view == "rares" and "Rares by zone"`,
 `        local root = state.view == "achievements" and "My deeds" or state.view == "alldeeds" and "Every deed there is"
            or state.view == "rares" and "Rares by zone"`],
[`            or state.view == "achievements" and root`,
 `            or (state.view == "achievements" or state.view == "alldeeds") and root`],
]);
console.log("done");
