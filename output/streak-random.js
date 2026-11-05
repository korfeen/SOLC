// One-off (2026-11-05): the streak's texture set by UI.Flick (a random one of five) only, the fixed path gone.
const fs = require("fs");
const path = require("path");
process.chdir(path.join(__dirname, ".."));
const BS = "\\";
const single = `"Interface${BS}AddOns${BS}SOLC${BS}Media${BS}Icons${BS}Streak"`;
const double = `"Interface${BS}${BS}AddOns${BS}${BS}SOLC${BS}${BS}Media${BS}${BS}Icons${BS}${BS}Streak"`;
for (const f of ["PixCollection.lua", "DreamBed.lua"]) {
  let s = fs.readFileSync(f, "utf8");
  s = s.split(`t:SetTexture(${double}) t:SetVertexColor`).join("t:SetVertexColor");
  s = s.split(`t:SetTexture(${single} .. math.random(5))`).join(`t:SetTexture(${double} .. math.random(5))`);
  fs.writeFileSync(f, s);
}
console.log("done");
