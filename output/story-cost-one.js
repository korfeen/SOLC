// One-off (2026-11-05): a Bedtime Story per pick, whatever the piece's rarity (the rare ones are hard enough to unlock).
// The cards lose their cost number; the note says it plainly.
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
edit("Minting.lua", [
  [`-- about (its piece for sure; Bedtime Stories by its rarity, STORY_COST), or nil.`,
   `-- about (its piece for sure; a Bedtime Story, STORY_COST), or nil.`],
  [`ns.STORY_COST = { uncommon = 1, rare = 2, epic = 3, legendary = 5 }`,
   `ns.STORY_COST = { uncommon = 1, rare = 1, epic = 1, legendary = 1 }  -- (one a pick, whatever it is: since 2026-11-05)`],
]);
edit("DreamBed.lua", [
  [`            card.cost:SetText(cost)`, `            card.cost:SetText(cost > 1 and cost or "")  -- (one a pick: no number needed)`],
  [`"Pick something and he'll dream about it for sure. The red number is how many Bedtime Stories it costs. (A picked piece won't make the painting rarer.)"`,
   `"Pick something and he'll dream about it for sure. Each pick costs one Bedtime Story. (A picked piece won't make the painting rarer.)"`],
]);
console.log("done");
