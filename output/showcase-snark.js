// One-off (2026-11-05): the Overview's empty showcase spots show before minting opens again; clicking one then gets a
// remark from Reginald instead of the inventory (and its tooltip says pictures come at Ogre Rank 3).
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
`-- A remark of his, once per character (tour.seen[id])`,
`-- A remark of his, any time (a line of his on its own, after whatever he was saying). Lines: one picked at random.
function ns.StewardSay(lines)
    local text = type(lines) == "table" and lines[math.random(#lines)] or lines
    if not CanShow() then if ns.Print then ns.Print(text) end return end
    if not panel then Build() end
    current, line = { lines = { { text = text } }, single = true }, 1
    wipe(queue)
    ShowLine()
end

-- A remark of his, once per character (tour.seen[id])`]]);

edit("OverviewCard.lua", [
[`            -- (your empty spots only once you can mint: the Collection's rank, Onboarding.lua)
            holder:SetShown(mint ~= nil or (key == nil and not (ns.RankLocked and ns.RankLocked("pixcollection"))))`,
 `            holder:SetShown(mint ~= nil or key == nil)`],
[`                elseif not self.key then
                    page.ShowPanel("inventory")  -- an empty spot of yours: your inventory, to open one and hang it`,
 `                elseif not self.key and ns.RankLocked and ns.RankLocked("pixcollection") and ns.StewardSay then
                    ns.StewardSay(SHOWCASE_SNARK)  -- (no pictures before minting opens, Ogre Rank 3: he has a word)
                elseif not self.key then
                    page.ShowPanel("inventory")  -- an empty spot of yours: your inventory, to open one and hang it`],
[`                    GameTooltip:AddLine("Showcase")
                    GameTooltip:AddLine("Click to pick from your gallery", 0.6, 0.6, 0.6)`,
 `                    GameTooltip:AddLine("Showcase")
                    if ns.RankLocked and ns.RankLocked("pixcollection") then
                        GameTooltip:AddLine("For your pictures. Minting opens at Ogre Rank 3.", 0.6, 0.6, 0.6)
                    else
                        GameTooltip:AddLine("Click to pick from your gallery", 0.6, 0.6, 0.6)
                    end`],
[`local DEFAULT_PORTRAIT_FRAME = "taped"`,
 `local DEFAULT_PORTRAIT_FRAME = "taped"
-- Reginald, when you click an empty showcase spot before minting opens (Onboarding.lua's ns.StewardSay).
local SHOWCASE_SNARK = {
    "Those are for pictures. You have none. You may admire the dust instead.",
    "An empty frame. Fitting. Earn rank three and perhaps you'll have something to hang.",
    "Do stop prodding the wall. The pictures come later. Much later, in your case.",
    "That space is reserved for art. You are not art.",
}`],
]);
console.log("done");
