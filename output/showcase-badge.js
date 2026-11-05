// One-off (2026-11-05): a picture on show (its showcase spot, the photo) is marked in the inventory by a small crayon
// gold coin with its spot's number in its corner - no dark shade over the picture any more.
const fs = require("fs");
const path = require("path");
process.chdir(path.join(__dirname, ".."));
const f = "Gallery.lua";
let s = fs.readFileSync(f, "utf8");
const nl = s.includes("\r\n") ? "\r\n" : "\n";
function rep(a, b) {
  a = a.split("\n").join(nl); b = b.split("\n").join(nl);
  if (s.split(a).length !== 2) throw Error(a.slice(0, 60));
  s = s.replace(a, () => b);
}
rep(`        local shade = thumb.cover:CreateTexture(nil, "BACKGROUND")
        shade:SetAllPoints()
        shade:SetColorTexture(0, 0, 0, 0.6)
        thumb.badge = thumb.cover:CreateFontString(nil, "OVERLAY")
        thumb.badge:SetFont(NAME_FONT, 34, "")
        thumb.badge:SetTextColor(unpack(GOLD))
        UI.OutlineText(thumb.badge, { 0, 0, 0 })
        thumb.badge:SetPoint("CENTER", 0, 2)`,
`        -- (on show: a little gold coin in its corner with its spot's number - the picture itself left as it is)
        local coin = thumb.cover:CreateTexture(nil, "ARTWORK")
        coin:SetTexture("Interface\\\\AddOns\\\\SOLC\\\\Media\\\\Icons\\\\Fx_Coin")
        coin:SetSize(28, 28)
        coin:SetPoint("CENTER", thumb.cover, "TOPLEFT", 6, -6)
        thumb.badge = thumb.cover:CreateFontString(nil, "OVERLAY")
        thumb.badge:SetFont(NAME_FONT, 15, "")
        thumb.badge:SetTextColor(0.3, 0.17, 0.03)
        thumb.badge:SetPoint("CENTER", coin, "CENTER", 0, 1)`);
rep(`                thumb.badge:SetFont(NAME_FONT, slot and 34 or 18, "")
                thumb.badge:SetText(slot and (isPhoto and (slot .. "\\nPHOTO") or tostring(slot)) or (isPhoto and "PHOTO" or ""))`,
`                thumb.badge:SetText(slot and tostring(slot) or (isPhoto and "P" or ""))`);
fs.writeFileSync(f, s);
console.log("done");
