// One-off (2026-11-05): /solc pictures clear yes - a character's pictures gone (testing before launch): its pictures
// (marked removed, so guildmates' copies go too), showcase, photo, the pieces' minted history, its picture news and the
// picture deeds with what they unlocked. Spent Bonks and Bedtime Stories aren't given back.
const fs = require("fs");
const path = require("path");
process.chdir(path.join(__dirname, ".."));
function edit(f, pairs) {
  let s = fs.readFileSync(f, "utf8");
  const nl = s.includes("\r\n") ? "\r\n" : "\n";
  for (let [a, b] of pairs) {
    a = a.split("\n").join(nl);
    b = b.split("\n").join(nl);
    if (s.split(a).length !== 2) throw Error(`${f}: ${a.slice(0, 60)}`);
    s = s.replace(a, () => b);
  }
  fs.writeFileSync(f, s);
}
edit("Minting.lua", [[
`local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", RemoveOutdatedMints)`,
`local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", RemoveOutdatedMints)

-- All of this character's pictures gone (/solc pictures clear yes, SecretDeeds.lua): each marked removed
-- (KillTrackerDB.removedMints: guildmates' copies go too, Sync.lua), the showcase and photo emptied, the pieces' minted
-- history (PixCollection.lua) and the picture news cleared, and the picture deeds taken back with what they unlocked.
-- Spent Bonks and Bedtime Stories aren't given back. Returns how many pictures went.
local PICTURE_FEATS = { pictures = true, epic = true, legendary = true, showcase = true }
function ns.ClearMyPictures()
    local db = KillTrackerDB
    local n = #(db.mints or {})
    db.removedMints = db.removedMints or {}
    for _, mint in ipairs(db.mints or {}) do
        local mark = {}
        db.removedMints[mint.number] = ns.Touch(mark)
    end
    db.mints = {}
    db.dreamPending = nil
    if db.showcase then db.showcase.numbers = {} ns.Touch(db.showcase) end
    if db.card and db.card.portrait then db.card.portrait = nil ns.Touch(db.card) end
    db.pixPieceMinted, db.pixMinted = nil, nil
    for i = #(db.events or {}), 1, -1 do
        local k = db.events[i].k
        if k == "M" or k == "W" then table.remove(db.events, i) end
    end
    for id in pairs(db.achievements or {}) do
        local feat = id:match("^feat:(%a+):%d+$")
        if feat and PICTURE_FEATS[feat] then
            db.achievements[id] = nil
            for _, unlocked in ipairs(ns.UnlockOptions and ns.UnlockOptions("deed:" .. id) or {}) do
                local key = ns.OptionKey(unlocked.layer.key, unlocked.option)
                if db.unlocks then db.unlocks[key] = nil end
                if db.ownUnlocks then db.ownUnlocks[key] = nil end
            end
        end
    end
    if ns.OnKillsChanged then ns.OnKillsChanged() end
    return n
end`]]);
edit("SecretDeeds.lua", [[
`        if strtrim(input or ""):lower() ~= "explore" then return Slash(input) end`,
`        local msg = strtrim(input or ""):lower()
        if msg == "pictures clear" then
            ns.Print("This takes ALL of this character's pictures away for good (and the picture deeds). Sure? /solc pictures clear yes")
            return
        elseif msg == "pictures clear yes" then
            local n = ns.ClearMyPictures and ns.ClearMyPictures() or 0
            ns.Print(("%d picture%s gone, and the picture deeds with them."):format(n, n == 1 and "" or "s"))
            return
        end
        if msg ~= "explore" then return Slash(input) end`]]);
edit("SecretDeeds.lua", [[
`-- /solc explore: each zone's map pieces uncovered`,
`-- /solc pictures clear [yes]: all of this character's pictures gone (Minting.lua's ns.ClearMyPictures; testing).
-- /solc explore: each zone's map pieces uncovered`]]);
console.log("done");
