// One-off (2026-11-05): the Collection's way back to the Bedroom is the book's ribbon bookmark (Media/Collection/ribbon,
// tools/make-collection-ribbon.js) hanging over the right page's top-right corner from under the top beam, a gold
// stitched cross on it; hovered it slides down a touch, as if tugged.
const fs = require("fs");
const path = require("path");
process.chdir(path.join(__dirname, ".."));
const f = "PixCollection.lua";
let s = fs.readFileSync(f, "utf8");
const nl = s.includes("\r\n") ? "\r\n" : "\n";
function rep(a, b) {
  a = a.split("\n").join(nl); b = b.split("\n").join(nl);
  if (s.split(a).length !== 2) throw Error(a.slice(0, 60));
  s = s.replace(a, () => b);
}
rep(`    if BOOK then Button(left, "< BEDROOM", 528, 160, 100, function() if ns.OpenPage then ns.OpenPage("dreambed") end end) end`,
`    if BOOK then
        -- The way back to the Bedroom: the book's ribbon bookmark hanging over the right page's top-right corner, from
        -- under the top beam (a gold cross stitched on: close); hovered, it slides down a touch, as if tugged.
        local ribbon = CreateFrame("Button", nil, right)
        ribbon:SetSize(50, 100)
        ribbon:SetFrameLevel(right:GetFrameLevel() + 5)
        local tex = ribbon:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints()
        tex:SetTexture("Interface\\\\AddOns\\\\SOLC\\\\Media\\\\Collection\\\\ribbon")
        local function Hang(drop) ribbon:ClearAllPoints() At(ribbon, "TOPLEFT", 1008, 126 + drop) end
        Hang(0)
        ribbon:SetScript("OnEnter", function(self)
            Hang(7)
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:AddLine("Back to the Bedroom")
            GameTooltip:AddLine("Close the book", 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end)
        ribbon:SetScript("OnLeave", function() Hang(0) GameTooltip_Hide() end)
        ribbon:SetScript("OnClick", function() UI.ClickSound() if ns.OpenPage then ns.OpenPage("dreambed") end end)
    end`);
rep(`    local title = Text(right, 23, 690, 158, 355)`, `    local title = Text(right, 23, 690, 158, BOOK and 305 or 355)  -- (in the book: clear of the ribbon)`);
fs.writeFileSync(f, s);
console.log("done");
