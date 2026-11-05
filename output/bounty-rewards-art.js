// One-off (2026-11-05): the bounty rewards' art in the Codex queues - the Bounty Hunter set along the "Bounties claimed"
// deeds (hat 10, star 25, duster 50, the Bounty Office background 100: tools/gen-art-bounty.json) and the Wanted Poster
// frame for claiming a wanted poster (tools/gen-frame-art.js, tools/convert-frames.js).
const fs = require("fs");
const path = require("path");
process.chdir(path.join(__dirname, ".."));
const nlOf = (s) => (s.includes("\r\n") ? "\r\n" : "\n");
// The set: appended to the bounty pieces' list.
{
  const f = "tools/gen-art-bounty.json";
  const list = JSON.parse(fs.readFileSync(f, "utf8"));
  if (list.some((e) => e.id === "hunt_sheriff_head")) throw Error("already there");
  const bg = JSON.parse(fs.readFileSync("tools/gen-art-zone-courses.json", "utf8"))[0].flags;
  const add = [
    { layer: "headwear", id: "hunt_sheriff_head", rarity: "rare", unlock: "deed:feat:bounties:10",
      desc: "Bounty Hunter's Hat: a big battered wide-brimmed leather hat, dusty brown, the brim a bit floppy, a torn little WANTED poster tucked into its hatband. It sits on the head, above the brow; the face is fully visible" },
    { layer: "accessory", id: "hunt_sheriff_star", rarity: "rare", unlock: "deed:feat:bounties:25", flags: ["--fit", "wear", "--hold", "right"],
      desc: "Sheriff's Star: a big shiny tin sheriff's star badge, six points with a little ball on each tip, a few dents, gripped directly in the fist and held up proudly to show it off. NO handle, NO stick" },
    { layer: "outfit", id: "hunt_sheriff_body", rarity: "epic", unlock: "deed:feat:bounties:50",
      desc: "Bounty Hunter's Duster: a long dusty brown leather duster coat over a grubby shirt, a leather bandolier across the chest stuffed with rolled-up wanted posters instead of bullets, a big tin sheriff's star pinned on the chest" },
    { layer: "background", id: "bg_bounty_office", rarity: "legendary", unlock: "deed:feat:bounties:100", flags: bg,
      desc: "Bounty Office: inside a dusty frontier-style bounty office built by ogres: the back wall plastered with old WANTED posters (pinned, torn, some crossed out in red), a big rough wooden desk with a lantern and a pile of gold coins, a rack of clubs and a coiled lasso on the wall, a dusty window looking out on golden fields, warm lantern light" },
  ];
  fs.writeFileSync(f, "[\n" + list.concat(add).map((e) => "  " + JSON.stringify(e)).join(",\n") + "\n]\n");
}
function edit(f, a, b) {
  let s = fs.readFileSync(f, "utf8");
  const nl = nlOf(s);
  a = a.split("\n").join(nl); b = b.split("\n").join(nl);
  if (s.split(a).length !== 2) throw Error(f + ": " + a.slice(0, 60));
  fs.writeFileSync(f, s.replace(a, () => b));
}
edit("tools/gen-frame-art.js",
  `  velvet_gilt: "A slim, elegant gilt picture frame`,
  `  // (a bounty reward: claiming a wanted poster, convert-frames.js "deed:feat:wanted:1")
  wanted: "NOT a wooden frame: an old frontier-style WANTED poster of torn, stained, sun-yellowed parchment, nailed up with a rusty nail at each top corner, its edges ragged and curling. The ONLY text allowed: the word WANTED in big bold black wooden-type letters across its top strip (the top strip a bit thicker than the sides), and REWARD in smaller bold letters across its bottom strip. The opening still an exact square.",
  velvet_gilt: "A slim, elegant gilt picture frame`);
edit("tools/convert-frames.js",
  `  { id: "velvet_gilt", name: "Velvet & Gilt", unlock: "shop:velvet_gilt" },`,
  `  { id: "velvet_gilt", name: "Velvet & Gilt", unlock: "shop:velvet_gilt" },
  // (a bounty reward: your first wanted poster claimed, Achievements.lua's "wanted" deeds)
  { id: "wanted", name: "Wanted Poster", unlock: "deed:feat:wanted:1" },`);
console.log("done");
