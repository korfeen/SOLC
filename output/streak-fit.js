// One-off (2026-11-05): the streak fits its word - a little past each end, never wider than its tab or row - and stays in
// the gap under it (a gentler tilt, a slimmer stroke), so it never paints over what's around.
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
edit("PixCollection.lua", [
  [`    t:SetRotation(math.rad(-3 + math.random() * 4))
    t.len = 0.9 + math.random() * 0.25`,
   `    t:SetRotation(math.rad(-1.5 + math.random() * 2.5))  -- (gently: a long one mustn't dip into the line below)
    t.len = 0.94 + math.random() * 0.14`],
  [`{ { 9, -1, 0.95, -1.5, -2 } }`, `{ { 7, 0, 0.95, 0, -2 } }`],
  [`t:SetWidth((w - (i - 1) * 8) * (t.len or 1)) t:SetShown(active and true or false)`,
   `t:SetWidth(math.min((w - (i - 1) * 8) * (t.len or 1), self:GetWidth() - 2)) t:SetShown(active and true or false)  -- (within its tab)`],
]);
edit("DreamBed.lua", [
  [`{ { 9, -1, 0.95, -1.5, -2 } }`, `{ { 7, 0, 0.95, 0, -2 } }`],
  [`t:SetWidth((w - (i - 1) * 8) * (t.len or 1)) t:SetShown(on and true or false)`,
   `t:SetWidth(math.min((w - (i - 1) * 8) * (t.len or 1), w + 2)) t:SetShown(on and true or false)  -- (within its word)`],
  [`{ { 9, 0, 0.95, -1.5, -2 } }`, `{ { 7, 1, 0.95, 0, -2 } }`],
  [`t:SetWidth((w - (k - 1) * 6) * (t.len or 1)) t:SetShown(on and true or false)`,
   `t:SetWidth(math.min((w - (k - 1) * 6) * (t.len or 1), self:GetWidth() - rowH - 10)) t:SetShown(on and true or false)  -- (within its row)`],
]);
console.log("done");
