// One-off (2026-11-05): the piece a Bedtime Story picks counts at its own rarity when the painting is graded (it was
// counted as uncommon); the story cloud's note says you pick one thing.
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
  [`-- legendary = top 1.5% of pictures, epic = top 5%, rare = top 17%, else uncommon. asked: a layer the bedtime story
-- picked (the Dream Bed: mint.asked), counted as an everyday piece - it was chosen, not luck.`,
   `-- legendary = top 1.5% of pictures, epic = top 5%, rare = top 17%, else uncommon. (asked: a layer the bedtime story
-- picked, mint.asked - it counts at its own rarity like the rest, since 2026-11-05.)`],
  [`        if layer.key == asked then option = { rarity = RARITY_ORDER[1] } end
`, ``],
]);
edit("tools/render-picture.js", [
  [`    score += layer === asked ? SCORES.uncommon : o ? SCORES[o.rarity] : 0;`,
   `    score += o ? SCORES[o.rarity] : 0;  // (the bedtime story's piece too: its own rarity, as Minting.lua)`],
]);
edit("DreamBed.lua", [
  [`"Pick something and he'll dream about it for sure. Each pick costs one Bedtime Story. (A picked piece won't make the painting rarer.)"`,
   `"Pick one thing and he'll dream about it for sure. It costs a Bedtime Story."`],
]);
console.log("done");
