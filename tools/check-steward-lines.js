// Lists the Pro Shop pieces (MintArt.lua options unlocked by "shop:<id>") with no line of their own in
// StewardLines.lua's pieces table: "NO STEWARD LINE (n): layer: Name (id), ...". The steward falls back to his
// layer-and-rarity lines for those, but every shop piece should get its own (the storyteller agent writes them).
// Run: node tools/check-steward-lines.js   (convert-art.js runs it at the end, after the story check)
const fs = require("fs");
const path = require("path");

function check() {
  const root = path.join(__dirname, "..");
  const art = fs.readFileSync(path.join(root, "MintArt.lua"), "utf8");
  const lines = fs.readFileSync(path.join(root, "StewardLines.lua"), "utf8");
  const piecesAt = lines.indexOf("pieces = {");
  const own = new Set();
  for (const m of lines.slice(piecesAt).matchAll(/^\s*([a-z0-9_]+)\s*=\s*\{/gm)) own.add(m[1]);
  // (the layer each option is in: MintArt.lua's "    layer = {" lines)
  const missing = [];
  let layer = null;
  for (const line of art.split(/\r?\n/)) {
    const l = line.match(/^    ([a-z]+) = \{$/);
    if (l) layer = l[1];
    const o = line.match(/\{ id = "([^"]+)", name = "([^"]+)".*unlock = "shop:/);
    if (o && !/retired = true/.test(line) && !own.has(o[1])) missing.push(`${layer}: ${o[2]} (${o[1]})`);
  }
  if (missing.length) console.log(`NO STEWARD LINE (${missing.length}): ` + missing.join(", "));
  else console.log("Steward lines: every shop piece has its own.");
  return missing;
}

module.exports = { check };
if (require.main === module) check();
