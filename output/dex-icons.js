// One-off (2026-11-05): the Collection book's layer tabs are the seven crayon layer icons in a row (Media/Icons/Layer_<key>),
// each its short name under it - the open one at full size with the brush streak, the rest a little faded; a hand-drawn
// rule under the row and another over the cards; the filters in a row with dots between them.
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
rep(`    for i, layer in ipairs(layers) do
        layerButtons[layer[1]] = Button(left, layer[2], 242 + ((i - 1) % 4) * 98, 193 + math.floor((i - 1) / 4) * 28, 94, function()
            dex.layer, dex.offset, dex.edition, dex.selected = layer[1], 0, nil, nil
            heading:SetText(layer[2])
            dex:Refresh()
        end)
    end`,
`    local SHORT = { background = "PLACE", skin = "SKIN", outfit = "CLOTHES", expression = "MOUTH", eyes = "EYES",
        accessory = "EXTRA", headwear = "HAT" }
    -- A hand-drawn rule across the left page (a brush flick in faint brown ink), between its parts.
    local function Rule(y)
        local t = left:CreateTexture(nil, "ARTWORK")
        UI.Flick(t)
        t:SetRotation(0)
        t:SetVertexColor(0.42, 0.3, 0.17, 0.45)
        At(t, "TOPLEFT", 240, y)
        t:SetSize(388, 6)
    end
    for i, layer in ipairs(layers) do
        local function Pick()
            dex.layer, dex.offset, dex.edition, dex.selected = layer[1], 0, nil, nil
            heading:SetText(layer[2])
            dex:Refresh()
        end
        if BOOK then
            -- (in the book: its crayon icon, its short name under it)
            local b = CreateFrame("Button", nil, left)
            b:SetSize(54, 50)
            At(b, "TOPLEFT", 240 + (i - 1) * 55, 190)
            b.icon = b:CreateTexture(nil, "ARTWORK")
            b.icon:SetPoint("TOP", 0, -1)
            b.icon:SetTexture("Interface\\\\AddOns\\\\SOLC\\\\Media\\\\Icons\\\\Layer_" .. layer[1])
            b.label = b:CreateFontString(nil, "OVERLAY")
            b.label:SetFont(FONT, 11, "")
            b.label:SetPoint("BOTTOM", 0, 6)
            b.label:SetText(SHORT[layer[1]])
            local streak = b:CreateTexture(nil, "ARTWORK")
            streak:SetPoint("TOP", b.label, "BOTTOM", 0, 1)
            streak:SetHeight(6)
            function b:Paint(active)
                if active and not self.picked then UI.Flick(streak) end
                self.picked = active
                streak:SetVertexColor(INK.heading[1], INK.heading[2], INK.heading[3], 0.95)
                streak:SetWidth(math.min(self.label:GetStringWidth() + 8, 52) * (streak.len or 1))
                streak:SetShown(active and true or false)
                local size = (active or self.hovered) and 34 or 28
                self.icon:SetSize(size, size)
                self.icon:SetAlpha((active or self.hovered) and 1 or 0.65)
                self.label:SetTextColor(unpack((active or self.hovered) and INK.heading or INK.text))
            end
            b:SetScript("OnClick", function() UI.ClickSound() Pick() end)
            b:SetScript("OnEnter", function(self) self.hovered = true self:Paint(self.picked) end)
            b:SetScript("OnLeave", function(self) self.hovered = false self:Paint(self.picked) end)
            b:Paint(false)
            layerButtons[layer[1]] = b
        else
            layerButtons[layer[1]] = Button(left, layer[2], 242 + ((i - 1) % 4) * 98, 193 + math.floor((i - 1) / 4) * 28, 94, Pick)
        end
    end
    if BOOK then Rule(244) Rule(314) end`);
rep(`    for i, filter in ipairs(filters) do
        filterButtons[filter[1]] = Button(left, filter[2], 242 + (i - 1) * 98, 286, 94, function()
            dex.filter, dex.offset = filter[1], 0
            dex:Refresh()
        end)
    end`,
`    for i, filter in ipairs(filters) do
        filterButtons[filter[1]] = Button(left, filter[2], 242 + (i - 1) * 98, 286, 94, function()
            dex.filter, dex.offset = filter[1], 0
            dex:Refresh()
        end)
        if BOOK and i > 1 then  -- (a dot between them)
            local dot = left:CreateFontString(nil, "OVERLAY")
            dot:SetFont(FONT, 16, "")
            dot:SetTextColor(INK.dim[1], INK.dim[2], INK.dim[3])
            dot:SetText("·")
            At(dot, "TOPLEFT", 242 + (i - 1) * 98 - 6, 289)
        end
    end`);
fs.writeFileSync(f, s);
console.log("done");
