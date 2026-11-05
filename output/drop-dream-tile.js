// One-off (2026-11-05): the old DREAM tile's code goes (inventory, PIX, the points list): nothing has made one since the
// Dream Bed got its room - a picture is started only there.
const fs = require("fs");
const path = require("path");
process.chdir(path.join(__dirname, ".."));
function edit(f, pairs) {
  let s = fs.readFileSync(f, "utf8");
  const nl = s.includes("\r\n") ? "\r\n" : "\n";
  for (let [a, b] of pairs) {
    a = a.split("\n").join(nl); b = b.split("\n").join(nl);
    if (s.split(a).length !== 2) throw Error(f + ": " + a.slice(0, 70));
    s = s.replace(a, () => b);
  }
  fs.writeFileSync(f, s);
}
edit("Gallery.lua", [
  [`        thumb.plus = thumb.tile:CreateFontString(nil, "OVERLAY")
        thumb.plus:SetFont(NAME_FONT, 44, "")
        thumb.plus:SetTextColor(unpack(GOLD))
        UI.OutlineText(thumb.plus, { 0, 0, 0 })
        thumb.plus:SetPoint("CENTER", 0, 8)
        thumb.plus:SetText("+")
`, ``],
  [`            if entry.mintAction then return ns.ConfirmMint() end
`, ``],
  [`            if entry and entry.mintAction then
                return UI.Tooltip(self, { "Dream a picture", "Off to the Dream Bed: the ogre dreams it, you paint it." })
            elseif entry and entry.ogre then`, `            if entry and entry.ogre then`],
  [`                thumb.plus:Hide()
                thumb.icon:Hide()`, `                thumb.icon:Hide()`],
  [`                thumb.plus:SetShown(entry.mintAction == true)
`, ``],
  [`                    thumb.border:SetColorTexture(1, 0.82, 0.25)
                else
                    thumb.caption:SetText("DREAM")
                    thumb.border:SetColorTexture(0.5, 0.4, 0.2)
                end`, `                    thumb.border:SetColorTexture(1, 0.82, 0.25)
                end`],
  [`        -- Your chests first, a row of their own (gaps fill it out), then minting, then your pictures.`,
   `        -- Your chests first, a row of their own (gaps fill it out), then your pictures.`],
]);
edit("PixPage.lua", [
  [`                tile.canvas:Hide()
                tile.plus:Hide()
                tile.border:SetVertexColor(1, 0.82, 0.25)`, `                tile.canvas:Hide()
                tile.border:SetVertexColor(1, 0.82, 0.25)`],
  [`            elseif picture.mintAction then
                tile.canvas:Hide()
                tile.plus:Show()
                tile.border:SetVertexColor(0.5, 0.4, 0.2)
                tile.caption:SetText(("DREAM  |T%s:12|t|cffffbf66%d|r"):format(ns.IngredientIcon("bonk"), ns.Bonks()))
                tile.band:Show()
                tile.tag:SetText("")
            else
                tile.canvas:Show()
                tile.plus:Hide()
`, `            else
                tile.canvas:Show()
`],
  [`            tile.plus = over:CreateFontString(nil, "OVERLAY")
            tile.plus:SetFont(NAME_FONT, 40, "")
            tile.plus:SetPoint("CENTER", 0, 8)
            tile.plus:SetText("+")
            tile.plus:SetTextColor(unpack(GOLD))
`, ``],
  [`                if self.picture.mintAction then return ns.ConfirmMint() end
`, ``],
  [`                if picture.mintAction then
                    return Tooltip(self, { "Dream a picture", ns.BonksLine() .. ". The ogre dreams it, you paint it." })
                end
`, ``],
  [`            elseif d.mintAction then
                ns.ConfirmMint()
`, ``],
  [`            if not d.mint and not d.mintAction then p.data[#p.data + 1] = d end  -- (pictures and minting: on PIX)`,
   `            if not d.mint then p.data[#p.data + 1] = d end  -- (pictures: on PIX)`],
]);
edit("UI.lua", [
  [`        if not state.viewing then
            rows[#rows + 1] = { label = "Mint a picture", count = 0, mintAction = true }
        end
`, ``],
  [`    elseif self.data.mintAction then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Dream a picture")
        GameTooltip:AddLine("Off to the Dream Bed: one Bonk and the ogre dreams up a picture for you to paint. A Bedtime Story picks a piece.", 1, 1, 1, true)
        GameTooltip:Show()
`, ``],
  [`    if d.mintAction then
        row.label:SetText("|cffffd100+ Dream a picture|r")
        row.count:SetText("Dream Bed")
        barFraction = 0
    elseif d.mint then`, `    if d.mint then`],
]);
console.log("done");
