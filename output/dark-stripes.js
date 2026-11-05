// One-off (2026-11-05): Club Stripes in dark walnut, so white text reads on it.
const fs = require("fs");
const f = "tools/gen-wallpaper.js", s = fs.readFileSync(f, "utf8");
const old = `stripes: [[0, "#b08a5c"], [46, "#5a3a22"], [50, "#ecdfc3"], [54, "#b8925a"], [56, "#ecdfc3"],
      [92, "#d6c19a"], [94, "#ecdfc3"], [124, "#b8925a"], [126, "#ecdfc3"], [130, "#5a3a22"]],`;
const nl = s.includes("\r\n") ? "\r\n" : "\n";
const o = old.replace(/\n/g, nl);
if (!s.includes(o)) throw Error("stripes not found");
let t = s.replace(o, `stripes: [[0, "#4a3322"], [46, "#22150c"], [50, "#3a2819"], [54, "#9a7442"], [56, "#3a2819"],
      [92, "#463021"], [94, "#3a2819"], [124, "#9a7442"], [126, "#3a2819"], [130, "#22150c"]],`.replace(/\n/g, nl));
t = t.replace(`hex("#ecdfc3") : hex("#b08a5c");`, `hex("#9a7442") : hex("#4a3322");`);
t = t.replace("// Club Stripes, everyone's to start with: a quiet clubhouse stripe - a wide tan band edged in a brown pinstripe and a" + nl +
  "  // gold one, then a wide cream band with a faint tan line down its middle.",
  "// Club Stripes, everyone's to start with: a dark clubhouse stripe (dark so white text reads on it, 2026-11-05) - a" + nl +
  "  // walnut band edged in a near-black pinstripe and a gold one, then a darker band with a faint line down its middle.");
fs.writeFileSync(f, t);
