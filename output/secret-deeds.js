// One-off (2026-11-05): secret deeds are one-off surprises (SecretDeeds.lua counts them); the Pro Shop and dungeon-buddy
// ladders are plain deeds again.
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
[`{ key = "shop", label = "Spent in the Pro Shop", unit = "points", secret = true,
        hint = "Money talks, darling. In my shop it positively sings.",`,
 `{ key = "shop", label = "Spent in the Pro Shop", unit = "points",`],
[`{ key = "buddy", label = "Dungeons with one guildmate", unit = "clears together", secret = true,
        hint = "Some members go into the dark together. Again and again. I find it touching. Briefly.",`,
 `{ key = "buddy", label = "Dungeons with one guildmate", unit = "clears together",`],
[`        { 3, "Dungeon Buddies", 15 }, { 10, "Partners In Crime", 30 }, { 25, "Inseparable", 60 }, { 50, "Joined At The Hip", 100 } } },
}`,
`        { 3, "Dungeon Buddies", 15 }, { 10, "Partners In Crime", 30 }, { 25, "Inseparable", 60 }, { 50, "Joined At The Hip", 100 } } },
    -- Secret deeds: one-off surprises (SecretDeeds.lua counts them into your tally; hibernation: your napping). Shown as
    -- "A secret deed" till begun, hint: Reginald's nudge when it's clicked (the Deeds page).
    { key = "dance", label = "Murloc Dance Party", unit = "dances", secret = true, count = function(_, f) return f.tally and (f.tally.dance or 0) end,
        hint = "Some creatures appreciate rhythm. Mostly the wet ones.", tiers = { { 1, "Murloc Dance Party", 25 } } },
    { key = "naked", label = "Naked Brawler", unit = "naked kills", secret = true, count = function(_, f) return f.tally and (f.tally.naked or 0) end,
        hint = "Clothing is optional in a fight. Advisable, but optional.", tiers = { { 1, "Naked Brawler", 25 } } },
    { key = "shoo", label = "Shoo", unit = "remarks waved off", secret = true, count = function(_, f) return f.tally and (f.tally.shoo or 0) end,
        hint = "I know when I'm being dismissed. I keep count.", tiers = { { 25, "Shoo", 25 } } },
    { key = "hibernation", label = "Hibernation", unit = "minutes napped", secret = true, count = function(_, f) return f.nap end,
        hint = "The finest members sleep through most of it.", tiers = { { 24 * 60, "Hibernation", 25 } } },
    { key = "deadTired", label = "Dead Tired", unit = "times", secret = true, count = function(_, f) return f.tally and (f.tally.deadTired or 0) end,
        hint = "Persistence is admirable. Usually.", tiers = { { 1, "Dead Tired", 25 } } },
    { key = "wave", label = "Ogre Diplomacy", unit = "waves", secret = true, count = function(_, f) return f.tally and (f.tally.wave or 0) end,
        hint = "Have you tried being friendly to your cousins?", tiers = { { 1, "Ogre Diplomacy", 25 } } },
    { key = "flights", label = "Frequent Flyer", unit = "flights", secret = true, count = function(_, f) return f.tally and (f.tally.flights or 0) end,
        hint = "Some members never walk anywhere. I admire that.", tiers = { { 25, "Frequent Flyer", 25 } } },
}`],
[`        facts.herbs, facts.ore, facts.skins, facts.fish = life.herbs or 0, life.ore or 0, life.skins or 0, life.fish or 0`,
 `        facts.herbs, facts.ore, facts.skins, facts.fish = life.herbs or 0, life.ore or 0, life.skins or 0, life.fish or 0
        facts.tally, facts.nap = tally, life.nap or 0  -- (the secret deeds: SecretDeeds.lua)`],
]);

edit("Onboarding.lua", [[
`    panel.bubble:SetScript("OnMouseUp", function() if current and current.timed then Close() end end)  -- (a remark: off it goes)`,
`    panel.bubble:SetScript("OnMouseUp", function()  -- (a remark: off it goes, and the Shoo deed counts it: SecretDeeds.lua)
        if current and current.timed then
            Close()
            if ns.SecretShoo then ns.SecretShoo() end
        end
    end)`]]);

edit("SOLC.toc", [[`LifeStats.lua`, `LifeStats.lua
SecretDeeds.lua`]]);
console.log("done");
