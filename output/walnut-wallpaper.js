// One-off (2026-11-05): the dark stripes become their own default wallpaper (walnut, "Club Walnut"); Club Stripes
// (stripes) back to its cream, without the faint line down its middle, and sold in the Pro Shop.
const fs = require("fs");
const f = "tools/gen-wallpaper.js", s = fs.readFileSync(f, "utf8"), nl = s.includes("\r\n") ? "\r\n" : "\n";
const start = s.indexOf("  // Club Stripes, everyone's to start with");
const end = s.indexOf("  // Blue blocks, measured");
if (start < 0 || end < 0) throw Error("stripes block not found");
const dark = s.slice(start, end);
const walnut = dark
  .replace(/ {2}\/\/ Club Stripes, everyone's to start with:[^]*?STRIPES: \{ from x, colour \} over a repeat\./,
    `  // Club Walnut, everyone's to start with (2026-11-05): a dark clubhouse stripe, dark so white text reads on it - a walnut${nl}` +
    `  // band edged in a near-black pinstripe and a gold one, then a plain darker band. STRIPES: { from x, colour } over a repeat.`)
  .replace("  stripes: {", "  walnut: {");
const cream = `  // Club Stripes (the Pro Shop's since 2026-11-05; everyone's first wallpaper before): a quiet clubhouse stripe - a wide${nl}` +
  `  // tan band edged in a brown pinstripe and a gold one, then a wide cream band (its faint middle line taken out: it${nl}` +
  `  // showed as a stray pixel line). STRIPES: { from x, colour } over a repeat.${nl}` +
  `  stripes: {${nl}` +
  `    w: 256, h: 256, grain: 0.035,${nl}` +
  `    stripes: [[0, "#b08a5c"], [46, "#5a3a22"], [50, "#ecdfc3"], [54, "#b8925a"], [56, "#ecdfc3"],${nl}` +
  `      [124, "#b8925a"], [126, "#ecdfc3"], [130, "#5a3a22"]],${nl}` +
  dark.slice(dark.indexOf("    period: 134,"))
    .replace("Its border: plain - the tan band with two thin cream lines along it.", "Its border: plain - the tan band with two thin cream lines along it.")
    .replace('hex("#9a7442") : hex("#4a3322")', 'hex("#ecdfc3") : hex("#b08a5c")');
fs.writeFileSync(f, s.slice(0, start) + walnut + cream + s.slice(end));
const w = "Wallpaper.lua", ws = fs.readFileSync(w, "utf8");
const wt = ws.replace('    { id = "stripes", name = "Club Stripes" },', '    { id = "walnut", name = "Club Walnut" },  -- (the first: everyone\'s, the default)' + (ws.includes("\r\n") ? "\r\n" : "\n") + '    { id = "stripes", name = "Club Stripes", price = 100 },');
if (wt === ws) throw Error("Wallpaper.lua not changed");
fs.writeFileSync(w, wt);
