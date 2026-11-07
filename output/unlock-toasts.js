// One-off (2026-11-07): every piece unlocked gets its toast ("Unlocked for your dreams!", its name, its layer) - pieces
// from deeds (exploring, kills, first clears, secret deeds) and combines used to come quietly. Where the piece is shown
// some other way (a chest's cards, the claw machine, the Shop's receipt, a rank-up's toast, the worn and looted toasts
// that were there), ns.UnlockOption's new noToast keeps it to one.
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
[`function ns.UnlockOption(key, quiet)
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
end`,
`-- (each new piece's toast: its name, and what kind of piece it is)
local LAYER_TOAST = { background = "A new background for your dreams", outfit = "New clothes for your dreams",
    headwear = "A new hat for your dreams", accessory = "Something new to hold in your dreams", skin = "A new skin for your dreams",
    eyes = "New eyes for your dreams", expression = "A new mouth for your dreams" }
-- Unlocks a piece. quiet: no feed event, no toast (catching up). noToast: its own toast or show elsewhere (a chest's
-- cards, the claw machine, the Shop, a rank-up). Returns true if it was new.
function ns.UnlockOption(key, quiet, noToast)
    local db = KillTrackerDB
    db.unlocks = db.unlocks or {}
    local found = ns.OptionByKey(key)
    if db.unlocks[key] or not found then return false end
    db.unlocks[key] = time()
    if db.ownUnlocks then db.ownUnlocks[key] = db.unlocks[key] end  -- (this character's own too: Core.lua's wardrobe)
    if ns.CheckCombines then ns.CheckCombines() end  -- (the other half of a combined piece, Minting.lua)
    if not quiet and ns.AddEvent then ns.AddEvent("U", key) end
    if not quiet and not noToast and ns.ShowToast and not (ns.RankLocked and ns.RankLocked("pixcollection")) then
        ns.ShowToast("achievement", "Unlocked!", found.option.name, LAYER_TOAST[found.layer.key] or "New for your dreams")
    end
    return true
end
-- Unlocks a whole pool (dev mode; looted epics; a deed's pieces). Returns how many were new.
function ns.UnlockPool(pool, quiet, noToast)
    local new = 0
    for _, unlocked in ipairs(ns.UnlockOptions(pool)) do
        if ns.UnlockOption(ns.OptionKey(unlocked.layer.key, unlocked.option), quiet, noToast) then new = new + 1 end
    end
    return new
end`],
[`        if item.kind == "unlock" then ns.UnlockOption(item.key)`, `        if item.kind == "unlock" then ns.UnlockOption(item.key, nil, true)  -- (the chest's cards show it)`],
[`        ns.UnlockOption(ns.OptionKey(unlocked.layer.key, unlocked.option))
        items[#items + 1] = { kind = "unlock", layer = unlocked.layer, option = unlocked.option }
        if not guild then`,
 `        ns.UnlockOption(ns.OptionKey(unlocked.layer.key, unlocked.option), nil, true)  -- (the chest's cards show it)
        items[#items + 1] = { kind = "unlock", layer = unlocked.layer, option = unlocked.option }
        if not guild then`],
[`    local function Take(unlocked)
        ns.UnlockOption(ns.OptionKey(unlocked.layer.key, unlocked.option))`,
 `    local function Take(unlocked)
        ns.UnlockOption(ns.OptionKey(unlocked.layer.key, unlocked.option), nil, true)  -- (the chest's cards show it)`],
[`                if key and ns.UnlockOption(key) then`, `                if key and ns.UnlockOption(key, nil, true) then  -- (its own toast, below)`],
[`            if name and ns.UnlockPool(LootKey(name)) > 0 then`, `            if name and ns.UnlockPool(LootKey(name), nil, true) > 0 then  -- (its own toast, below)`],
]);
edit("ClawMachine.lua", [[`                ns.UnlockOption(c.p[1])  -- (yours to mint with now; the guild news hears of it)`,
  `                ns.UnlockOption(c.p[1], nil, true)  -- (yours to mint with now; the guild news hears of it; the machine shows the win)`]]);
edit("ProShop.lua", [[`        else ns.UnlockOption(key) end`, `        else ns.UnlockOption(key, nil, true) end  -- (the receipt shows it)`]]);
edit("Ranks.lua", [[`ns.UnlockOption(perk.key, seen == nil or perk.rank <= seen) end`, `ns.UnlockOption(perk.key, seen == nil or perk.rank <= seen, true) end  -- (the rank-up's toast says it)`]]);
console.log("done");
