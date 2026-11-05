// One-off (2026-11-05), on storybook-book2.js: the story picker is a thought cloud over the sleeping ogre (his thought
// bubble's look, big): two lobes - the chapters on the left (each its crayon layer icon, Media/Icons/Layer_<key>, and
// its name; the open one underlined in red ink) and the pieces' cards on the right - a gap and two small puffs between
// them, and puffs trailing down towards his head. "Things he holds" is "Accessories" (they can be anything).
const fs = require("fs");
const path = require("path");
process.chdir(path.join(__dirname, ".."));
const file = "DreamBed.lua";
let s = fs.readFileSync(file, "utf8");
const nl = s.includes("\r\n") ? "\r\n" : "\n";
const N = (t) => t.replace(/\n/g, nl);
function rep(a, b) { a = N(a); b = N(b); if (s.split(a).length !== 2) throw Error("not found: " + a.slice(0, 70)); s = s.replace(a, () => b); }
function cut(from, to, by) {
  const a = s.indexOf(N(from)), b = s.indexOf(N(to), a);
  if (a < 0 || b < 0) throw Error("cut: " + from.slice(0, 50));
  s = s.slice(0, a) + N(by) + s.slice(b);
}

rep(`{ "accessory", "Things he holds", "STUFF" }`, `{ "accessory", "Accessories", "STUFF" }`);

// The cover and pages -> the cloud.
cut(`    -- The cover: red leather, a darker edge, lighter towards the middle;`, `    local function At(region, x, y)`,
`    -- The cloud: two lobes of cream (a filled middle, puffy discs round its edge - a brown outline disc behind each, as
    -- the little thought bubble's), a gap between them bridged by two small puffs, and puffs trailing down to his head.
    local function Blob(x, y, d, pass)
        local t = spread:CreateTexture(nil, pass == 1 and "BACKGROUND" or "BORDER", nil, pass == 1 and -6 or 0)
        t:SetTexture(DISC)
        t:SetSize(pass == 1 and d + 6 or d, pass == 1 and d + 6 or d)
        t:SetPoint("CENTER", spread, "TOPLEFT", x, -y)
        if pass == 1 then t:SetVertexColor(0.45, 0.3, 0.15) else t:SetVertexColor(PARCH[1], PARCH[2], PARCH[3]) end
    end
    local GAP, PUFF = 18, 44
    local lobes = { { x = PUFF / 2, y = PUFF / 2, w = bw * 0.34 - PUFF, h = bh - PUFF },
        { x = bw * 0.34 + GAP + PUFF / 2, y = PUFF / 2, w = bw * 0.66 - GAP - PUFF, h = bh - PUFF } }
    for pass = 1, 2 do
        for li, lobe in ipairs(lobes) do
            -- (round its edge, a disc every so often, sizes varying a little: puffy)
            local edge = {}
            local function Along(x0, y0, x1, y1)
                local n = math.max(1, math.floor(math.sqrt((x1 - x0) ^ 2 + (y1 - y0) ^ 2) / (PUFF * 0.62)))
                for k = 0, n - 1 do edge[#edge + 1] = { x0 + (x1 - x0) * k / n, y0 + (y1 - y0) * k / n } end
            end
            local x0, y0, x1, y1 = lobe.x, lobe.y, lobe.x + lobe.w, lobe.y + lobe.h
            Along(x0, y0, x1, y0) Along(x1, y0, x1, y1) Along(x1, y1, x0, y1) Along(x0, y1, x0, y0)
            for k, p in ipairs(edge) do Blob(p[1], p[2], PUFF * (0.9 + 0.25 * ((k * 7 + li * 3) % 5) / 4), pass) end
            if pass == 2 then
                local fill = spread:CreateTexture(nil, "BORDER", nil, 1)
                fill:SetColorTexture(PARCH[1], PARCH[2], PARCH[3])
                fill:SetPoint("TOPLEFT", spread, "TOPLEFT", x0, -y0)
                fill:SetSize(lobe.w, lobe.h)
            end
        end
        -- (the bridge between the lobes, and the trail down towards his head)
        local mid = bw * 0.34 + GAP / 2
        Blob(mid, bh * 0.42, PUFF * 0.55, pass)
        Blob(mid, bh * 0.6, PUFF * 0.42, pass)
        for k, p in ipairs({ { 0.06, 1.06, 0.6 }, { 0.0, 1.16, 0.42 }, { -0.04, 1.25, 0.28 } }) do
            Blob(p[1] * bw, p[2] * bh, PUFF * p[3], pass)
        end
    end
    local pad = 16
    local L = { x = lobes[1].x + pad - 8, y = lobes[1].y + pad - 6, w = lobes[1].w - 2 * pad + 16, h = lobes[1].h - 2 * pad + 12 }
    local R = { x = lobes[2].x + pad - 8, y = lobes[2].y + pad - 6, w = lobes[2].w - 2 * pad + 16, h = lobes[2].h - 2 * pad + 12 }
`);

// The chapters: rows of icon + name.
cut(`    -- The chapters: paper tiles, two across,`, `    spread.storiesText = Text(spread, 13)`,
`    -- The chapters: a row each, its crayon icon (Media/Icons/Layer_<key>) and its name; the open one underlined in red
    -- ink, its icon at full strength (the others a little faded); hovered, the name goes red.
    spread.chapters = {}
    local rowH = 30
    for i, ch in ipairs(CHAPTERS) do
        local b = CreateFrame("Button", nil, spread)
        b:SetSize(L.w, rowH)
        At(b, L.x, L.y + 84 + (i - 1) * (rowH + 2))
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetSize(rowH, rowH)
        b.icon:SetPoint("LEFT")
        b.icon:SetTexture("Interface\\\\AddOns\\\\SOLC\\\\Media\\\\Icons\\\\Layer_" .. ch[1])
        b.label = Text(b, 15)
        b.label:SetPoint("LEFT", b.icon, "RIGHT", 8, 1)
        b.streak = {}
        for k, stroke in ipairs({ { 3, -2, 0.85, -1.2, 0 }, { 2, -5, 0.5, 0.9, 4 } }) do
            local t = b:CreateTexture(nil, "ARTWORK")
            t:SetColorTexture(RED[1], RED[2], RED[3], stroke[3])
            t:SetHeight(stroke[1])
            t:SetPoint("TOPLEFT", b.label, "BOTTOMLEFT", stroke[5] - 2, stroke[2] + 2)
            t:SetRotation(math.rad(stroke[4]))
            b.streak[k] = t
        end
        function b:Paint(on)
            self.on = on
            local w = self.label:GetStringWidth() + 6
            for k, t in ipairs(self.streak) do t:SetWidth(w - (k - 1) * 6) t:SetShown(on and true or false) end
            local c = (on or self.hovered) and RED or INK
            self.label:SetTextColor(c[1], c[2], c[3])
            self.icon:SetAlpha(on and 1 or 0.7)
            self.icon:SetSize(on and rowH + 4 or rowH, on and rowH + 4 or rowH)
        end
        b:SetScript("OnEnter", function(self) self.hovered = true self:Paint(self.on) end)
        b:SetScript("OnLeave", function(self) self.hovered = false self:Paint(self.on) end)
        b:SetScript("OnClick", function() Click() spread.chapter, spread.page = ch[1], 0 ShowBook(true) end)
        spread.chapters[i] = b
    end
`);
// ShowBook: no sample pieces any more (the icons).
cut(`        local sample = spread.sel and spread.sel.layer == key and spread.sel.option`, `    end
    local stories = ns.Tokens("story")`, ``);
fs.writeFileSync(file, s);
console.log("done");
