// One-off (2026-11-05): the overview card's default frame is the tape; no exemption for a locked default.
const fs = require("fs");
const s = fs.readFileSync("OverviewCard.lua", "utf8"), nl = s.includes("\r\n") ? "\r\n" : "\n";
const t = s.replace('local DEFAULT_PORTRAIT_FRAME = "wood"', 'local DEFAULT_PORTRAIT_FRAME = "taped"')
  .replace("            -- (the card's own default is always there, locked or not: everyone's card starts in it)" + nl +
    "            if ns.FrameUnlocked(frame) or frame.id == DEFAULT_PORTRAIT_FRAME then list[#list + 1]",
    "            if ns.FrameUnlocked(frame) then list[#list + 1]");
if (t.split(nl).length !== s.split(nl).length - 1 || !t.includes('"taped"')) throw Error("edit missed");
fs.writeFileSync("OverviewCard.lua", t);
