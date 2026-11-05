// One-off (2026-11-05): the Collection as an open book (tools/gen-collection-book.js's picture behind its two pages):
// ink on parchment instead of cream on dark, leather tabs for its buttons, paper tiles. Without the picture
// (CollectionBookArt.lua missing) it stays as it was.
const fs = require("fs");
const path = require("path");
process.chdir(path.join(__dirname, ".."));
function edit(file, pairs) {
  let s = fs.readFileSync(file, "utf8");
  const nl = s.includes("\r\n") ? "\r\n" : "\n";
  for (const [a, b] of pairs) {
    const from = a.replace(/\n/g, nl), to = b.replace(/\n/g, nl);
    const n = s.split(from).length - 1;
    if (n !== 1) throw Error(`${file}: found ${n} times: ${a.slice(0, 70)}`);
    s = s.replace(from, () => to);
  }
  fs.writeFileSync(file, s);
}

edit("PixCollection.lua", [
[`function UI.PixCollection(parent)
    local dex = CreateFrame("Frame", nil, parent)`,
 `-- Its look: an open book (CollectionBookArt.lua, tools/gen-collection-book.js: the Dream Bed's red book opened flat)
-- with ink on its parchment pages, else the old dark boards.
local BOOK = ns.CollectionBookArt
local INK = BOOK and {
    panel = { 0, 0, 0, 0 }, backing = { 0, 0, 0, 0 }, text = { 0.22, 0.13, 0.06 }, heading = { 0.55, 0.12, 0.08 },
    dim = { 0.42, 0.31, 0.19 }, track = { 0.74, 0.64, 0.48 }, bar = { 0.62, 0.32, 0.1 },
    tab = { 0.76, 0.65, 0.47 }, tabOn = { 0.55, 0.14, 0.09 }, label = { 0.3, 0.19, 0.09 }, labelOn = { 1, 0.9, 0.7 },
    tile = { 0.86, 0.79, 0.64 }, unseen = { 0.62, 0.55, 0.43 }, rarityDim = 0.9,
} or {
    panel = { 0.065, 0.045, 0.03, 1 }, backing = { 0.045, 0.032, 0.022, 1 }, text = { 0.93, 0.88, 0.78 }, heading = { 1, 0.82, 0.48 },
    dim = { 0.65, 0.59, 0.49 }, track = { 0.2, 0.15, 0.09 }, bar = { 0.73, 0.53, 0.23 },
    tab = { 0.18, 0.12, 0.07 }, tabOn = { 0.38, 0.26, 0.12 }, label = { 0.72, 0.65, 0.53 }, labelOn = { 1, 0.84, 0.5 },
    tile = { 0.06, 0.045, 0.03 }, unseen = { 0.25, 0.22, 0.18 }, rarityDim = 0.45,
}

function UI.PixCollection(parent)
    local dex = CreateFrame("Frame", nil, parent)`],
[`        bg:SetColorTexture(0.065, 0.045, 0.03, 1)
        return panel`,
 `        bg:SetColorTexture(unpack(INK.panel))
        return panel`],
[`        text:SetTextColor(0.93, 0.88, 0.78)
        At(text, "TOPLEFT", x, y)`,
 `        text:SetTextColor(unpack(INK.text))
        At(text, "TOPLEFT", x, y)`],
[`    backing:SetColorTexture(0.045, 0.032, 0.022, 1)`,
 `    backing:SetColorTexture(unpack(INK.backing))
    if BOOK then  -- (the open book behind both pages)
        local book = dex:CreateTexture(nil, "BACKGROUND", nil, -7)
        At(book, "TOPLEFT", BOOK.x, BOOK.y)
        book:SetSize(BOOK.w, BOOK.h)
        book:SetTexture("Interface\\\\AddOns\\\\SOLC\\\\Media\\\\Collection\\\\book")
    end`],
[`    heading:SetTextColor(1, 0.82, 0.48)`, `    heading:SetTextColor(unpack(INK.heading))`],
[`    track:SetColorTexture(0.2, 0.15, 0.09, 1)`, `    track:SetColorTexture(unpack(INK.track))`],
[`    bar:SetColorTexture(0.73, 0.53, 0.23, 1)`, `    bar:SetColorTexture(unpack(INK.bar))`],
[`    footer:SetTextColor(0.65, 0.59, 0.49)`, `    footer:SetTextColor(unpack(INK.dim))`],
[`        bg:SetColorTexture(0.18, 0.12, 0.07)
        button.bg = bg`, `        bg:SetColorTexture(unpack(INK.tab))
        button.bg = bg`],
[`        for key, button in pairs(layerButtons) do
            local active = self.layer == key
            button.bg:SetColorTexture(active and 0.38 or 0.18, active and 0.26 or 0.12, active and 0.12 or 0.07)
            button.label:SetTextColor(active and 1 or 0.72, active and 0.84 or 0.65, active and 0.5 or 0.53)
        end
        for key, button in pairs(filterButtons) do
            local active = self.filter == key
            button.bg:SetColorTexture(active and 0.38 or 0.18, active and 0.26 or 0.12, active and 0.12 or 0.07)
            button.label:SetTextColor(active and 1 or 0.72, active and 0.84 or 0.65, active and 0.5 or 0.53)
        end`,
 `        for _, group in ipairs({ { layerButtons, self.layer }, { filterButtons, self.filter } }) do
            for key, button in pairs(group[1]) do
                local active = group[2] == key
                button.bg:SetColorTexture(unpack(active and INK.tabOn or INK.tab))
                button.label:SetTextColor(unpack(active and INK.labelOn or INK.label))
            end
        end`],
[`                    tile.border:SetColorTexture(r * 0.45, g * 0.45, b * 0.45)
                else tile.border:SetColorTexture(0.25, 0.22, 0.18) end`,
 `                    tile.border:SetColorTexture(r * INK.rarityDim, g * INK.rarityDim, b * INK.rarityDim)
                else tile.border:SetColorTexture(unpack(INK.unseen)) end`],
[`        bg:SetColorTexture(0.06, 0.045, 0.03)
        tile.canvas = CreateFrame("Frame", nil, tile)`,
 `        bg:SetColorTexture(unpack(INK.tile))
        tile.canvas = CreateFrame("Frame", nil, tile)`],
[`        tile.caption:SetFont(FONT, 11, "")`,
 `        tile.caption:SetFont(FONT, 11, "")
        tile.caption:SetTextColor(unpack(INK.text))`],
]);

edit("SOLC.toc", [[`PixCollection.lua`, `CollectionBookArt.lua
PixCollection.lua`]]);
console.log("done");
