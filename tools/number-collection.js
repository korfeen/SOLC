// The Collection page's catalogue numbers (PixCollectionData.lua): every piece in MintArt.lua needs one (the page stops
// at the first without), and they're permanent - new ids are appended after the highest, in MintArt's order; nothing is
// ever renumbered or reused. Run after every art build (convert-art.js).
// Usage: node tools/number-collection.js
const fs = require("fs");
const path = require("path");

const ROOT = path.join(__dirname, "..");
const DATA = path.join(ROOT, "PixCollectionData.lua");
const art = fs.readFileSync(path.join(ROOT, "MintArt.lua"), "utf8");
let data = fs.readFileSync(DATA, "utf8");
const crlf = data.includes("\r\n");

const numbered = new Set([...data.matchAll(/\["([^"]+)"\] = (\d+)/g)].map((m) => m[1]));
let next = Math.max(0, ...[...data.matchAll(/\] = (\d+)/g)].map((m) => +m[1])) + 1;

// (MintArt.lua: "    <layer> = {" opens a layer, then "{ id = "<id>"" lines)
const added = [];
let layer = null;
for (const line of art.split(/\r?\n/)) {
  const open = line.match(/^    (\w+) = \{\s*$/);
  if (open) { layer = open[1]; continue; }
  const id = layer && line.match(/^\s+\{ id = "([^"]+)"/);
  if (!id) continue;
  const key = layer + ":" + id[1];
  if (numbered.has(key)) continue;
  numbered.add(key);
  added.push(`    ["${key}"] = ${next++},`);
}
if (added.length) {
  const nl = crlf ? "\r\n" : "\n", at = data.lastIndexOf("}");
  data = data.slice(0, at) + added.join(nl) + nl + data.slice(at);
  fs.writeFileSync(DATA, data);
}
console.log(`${added.length} new catalogue numbers${added.length ? " (" + added[0].trim() + " .. " + added[added.length - 1].trim() + ")" : ""}`);
