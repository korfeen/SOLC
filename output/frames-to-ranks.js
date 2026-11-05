// One-off (2026-11-05): Polaroid and Honey Wood frames to Ogre Ranks 2 and 3; frames listed as rank perks.
const fs = require("fs");
const nlOf = (s) => (s.includes("\r\n") ? "\r\n" : "\n");
const edit = (file, fn) => { const s = fs.readFileSync(file, "utf8"); const t = fn(s, nlOf(s)); if (t === s) throw Error("no change: " + file); fs.writeFileSync(file, t); };
edit("Frames.lua", (s) => s.replace('{ id = "polaroid", name = "Polaroid", inner', '{ id = "polaroid", name = "Polaroid", unlock = "rank:2", inner')
  .replace('{ id = "wood", name = "Honey Wood", inner', '{ id = "wood", name = "Honey Wood", unlock = "rank:3", inner'));
edit("tools/convert-frames.js", (s) => s.replace('{ id: "polaroid", name: "Polaroid", back: "plain" }', '{ id: "polaroid", name: "Polaroid", unlock: "rank:2", back: "plain" }')
  .replace('{ id: "wood", name: "Honey Wood" }', '{ id: "wood", name: "Honey Wood", unlock: "rank:3" }'));
edit("OverviewCard.lua", (s, nl) => s.replace("            if ns.FrameUnlocked(frame) then list[#list + 1]",
  "            -- (the card's own default is always there, locked or not: everyone's card starts in it)" + nl +
  "            if ns.FrameUnlocked(frame) or frame.id == DEFAULT_PORTRAIT_FRAME then list[#list + 1]"));
const frames = [[2, "Polaroid"], [3, "Honey Wood"], [5, "Driftwood"], [8, "Dungeon Iron"], [12, "Gilded"], [20, "Bone and Tusk"]];
edit("Ranks.lua", (s, nl) => s.replace('    { rank = 30, kind = "piece", key = "skin:grand_sleepy_pink"',
  "    -- The rank frames (Frames.lua's unlock \"rank:<n>\", checked there: these are for the list only)." + nl +
  frames.map(([n, name]) => `    { rank = ${n}, kind = "frame", text = "The ${name} picture frame" },`).join(nl) + nl +
  '    { rank = 30, kind = "piece", key = "skin:grand_sleepy_pink"'));
