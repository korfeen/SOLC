// One-off (2026-11-05): no minting in sight before the Collection opens (Ogre Rank 3): the inventory's MINT tile and
// the Overview's empty showcase spots wait for it, and Reginald has a word the first time you open the inventory.
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

edit("Onboarding.lua", [[
`-- Hooks ----------------------------------------------------------------------------------------------------------------
`,
`-- A remark of his, once per character (tour.seen[id]): when the window's open and he isn't already talking (else
-- next time).
function ns.StewardOnce(id, text)
    local tour = DB()
    if not tour or tour.seen[id] or not CanShow() or current then return end
    tour.seen[id] = true
    if not panel then Build() end
    current, line = { lines = { { text = text } }, single = true }, 1
    wipe(queue)
    ShowLine()
end

-- Hooks ----------------------------------------------------------------------------------------------------------------
`]]);

edit("Gallery.lua", [
[`        entries[#entries + 1] = { mintAction = true }`,
 `        local minting = not (ns.RankLocked and ns.RankLocked("pixcollection"))  -- (the Dream Bed opens with the Collection)
        if minting then entries[#entries + 1] = { mintAction = true } end`],
[`        footer:SetText(#mints == 0 and "No pictures yet: mint your first!"`,
 `        footer:SetText(not minting and (#entries == 0 and "Nothing here yet. Chests from dungeons wait here." or "")
            or #mints == 0 and "No pictures yet: mint your first!"`],
]);

edit("OverviewCard.lua", [
[`            holder:SetShown(mint ~= nil or key == nil)`,
 `            -- (your empty spots only once you can mint: the Collection's rank, Onboarding.lua)
            holder:SetShown(mint ~= nil or (key == nil and not (ns.RankLocked and ns.RankLocked("pixcollection"))))`],
[`            page.panel = which
            page.editPanel:SetShown(which == "edit")`,
 `            page.panel = which
            if which == "inventory" and ns.StewardOnce and ns.RankLocked and ns.RankLocked("pixcollection") then
                ns.StewardOnce("inventory", "Your inventory. Chests go here, should you ever find one. Pictures come later, if you earn them. I have my doubts.")
            end
            page.editPanel:SetShown(which == "edit")`],
]);
console.log("done");
