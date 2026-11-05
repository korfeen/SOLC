// One-off (2026-11-05), on storybook-book.js: the storybook's cover drawn by code (red leather, a darker edge, the spine's
// shadow) with the painting's parchment pages on it - no painted gold corners to cut; and the chapters as a grid of
// paper tiles on the left page, each with a piece of its own drawn small (the one picked, else its first), the open one
// with a gold edge and the red streak under its name.
const fs = require("fs");
const path = require("path");
process.chdir(path.join(__dirname, ".."));
const file = "DreamBed.lua";
let s = fs.readFileSync(file, "utf8");
const nl = s.includes("\r\n") ? "\r\n" : "\n";
const N = (t) => t.replace(/\n/g, nl);
function rep(a, b) { a = N(a); b = N(b); if (s.split(a).length !== 2) throw Error("not found: " + a.slice(0, 70)); s = s.replace(a, () => b); }

rep(`local BOOK_CROP = { x0 = 18, x1 = 1495, y0 = 30, y1 = 1010, w = 1536, h = 1024 }  -- (the book in its painting, painting pixels)
-- Its pages in that crop, as fractions: left and right, top and bottom.
local BOOK_PAGES = { l0 = 0.0555, l1 = 0.5058, r0 = 0.5105, r1 = 0.9695, top = 0.0265, bottom = 0.911 }`,
`-- (its parchment pages in the painting, painting pixels: the gold corners left out; the cover is drawn here)
local BOOK_SHEETS = { left = { 175, 760 }, right = { 778, 1375 }, top = 125, bottom = 855, w = 1536, h = 1024 }
local COVER, SPINE = 12, 3  -- (the leather showing round the pages; the gap at the fold, either side)`);
rep(`    local bh = bw * (BOOK_CROP.y1 - BOOK_CROP.y0) / (BOOK_CROP.x1 - BOOK_CROP.x0)`, `    local bh = bw * 0.62`);
rep(`    local book = spread:CreateTexture(nil, "BACKGROUND", nil, -7)
    book:SetAllPoints()
    book:SetTexture(BOOK_ART)
    book:SetTexCoord(BOOK_CROP.x0 / BOOK_CROP.w, BOOK_CROP.x1 / BOOK_CROP.w, BOOK_CROP.y0 / BOOK_CROP.h, BOOK_CROP.y1 / BOOK_CROP.h)
    local P = BOOK_PAGES
    local pad = 22
    local L = { x = P.l0 * bw + pad, y = P.top * bh + pad, w = (P.l1 - P.l0) * bw - 2 * pad, h = (P.bottom - P.top) * bh - 2 * pad }
    local R = { x = P.r0 * bw + pad, y = P.top * bh + pad, w = (P.r1 - P.r0) * bw - 2 * pad, h = (P.bottom - P.top) * bh - 2 * pad }`,
`    -- The cover: red leather, a darker edge, lighter towards the middle; the pages on it, the spine's shadow between.
    local edge = spread:CreateTexture(nil, "BACKGROUND", nil, -8)
    edge:SetAllPoints()
    edge:SetColorTexture(0.22, 0.04, 0.03)
    local leather = spread:CreateTexture(nil, "BACKGROUND", nil, -7)
    leather:SetPoint("TOPLEFT", 3, -3) leather:SetPoint("BOTTOMRIGHT", -3, 3)
    leather:SetColorTexture(1, 1, 1)
    leather:SetGradient("VERTICAL", CreateColor(0.36, 0.07, 0.05, 1), CreateColor(0.52, 0.12, 0.08, 1))
    local B = BOOK_SHEETS
    local pageW, pageH = bw / 2 - COVER - SPINE, bh - 2 * COVER
    for i, side in ipairs({ B.left, B.right }) do
        local sheet = spread:CreateTexture(nil, "BACKGROUND", nil, -6)
        sheet:SetTexture(BOOK_ART)
        sheet:SetTexCoord(side[1] / B.w, side[2] / B.w, B.top / B.h, B.bottom / B.h)
        sheet:SetPoint("TOPLEFT", i == 1 and COVER or bw / 2 + SPINE, -COVER)
        sheet:SetSize(pageW, pageH)
    end
    local spine = spread:CreateTexture(nil, "BACKGROUND", nil, -5)
    spine:SetPoint("TOP", 0, -COVER) spine:SetPoint("BOTTOM", 0, COVER)
    spine:SetWidth(2 * SPINE + 18)
    spine:SetColorTexture(1, 1, 1)
    spine:SetGradient("HORIZONTAL", CreateColor(0, 0, 0, 0), CreateColor(0, 0, 0, 0.28))
    local spineR = spread:CreateTexture(nil, "BACKGROUND", nil, -5)
    spineR:SetPoint("TOPLEFT", spine, "TOP", 0, 0) spineR:SetPoint("BOTTOMRIGHT", spine, "BOTTOMRIGHT")
    spineR:SetColorTexture(1, 1, 1)
    spineR:SetGradient("HORIZONTAL", CreateColor(0, 0, 0, 0.28), CreateColor(0, 0, 0, 0))
    spine:SetPoint("RIGHT", spread, "CENTER", 0, 0)
    local pad = 20
    local L = { x = COVER + pad, y = COVER + pad, w = pageW - 2 * pad, h = pageH - 2 * pad }
    local R = { x = bw / 2 + SPINE + pad, y = COVER + pad, w = pageW - 2 * pad, h = pageH - 2 * pad }`);
rep(`    spread.chapters = {}
    for i, ch in ipairs(CHAPTERS) do
        local b = InkWord(spread, 15, function() spread.chapter, spread.page = ch[1], 0 ShowBook(true) end)
        At(b, L.x, L.y + 98 + (i - 1) * 27)
        spread.chapters[i] = b
    end`,
`    -- The chapters: paper tiles, two across, each with a piece of its own drawn small and its name.
    spread.chapters = {}
    local tileW, tileH, tileGap = (L.w - 8) / 2, 44, 6
    for i, ch in ipairs(CHAPTERS) do
        local b = CreateFrame("Button", nil, spread)
        b:SetSize(tileW, tileH)
        At(b, L.x + ((i - 1) % 2) * (tileW + 8), L.y + 74 + math.floor((i - 1) / 2) * (tileH + tileGap))
        local bg = b:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.86, 0.79, 0.64)
        b.edges = {}
        for e = 1, 4 do
            local line = b:CreateTexture(nil, "BORDER")
            if e <= 2 then line:SetHeight(2) line:SetPoint(e == 1 and "TOPLEFT" or "BOTTOMLEFT") line:SetPoint(e == 1 and "TOPRIGHT" or "BOTTOMRIGHT")
            else line:SetWidth(2) line:SetPoint(e == 3 and "TOPLEFT" or "TOPRIGHT") line:SetPoint(e == 3 and "BOTTOMLEFT" or "BOTTOMRIGHT") end
            b.edges[e] = line
        end
        local hover = b:CreateTexture(nil, "HIGHLIGHT")
        hover:SetPoint("TOPLEFT", 2, -2) hover:SetPoint("BOTTOMRIGHT", -2, 2)
        hover:SetColorTexture(1, 0.95, 0.8, 0.3)
        b.canvas = CreateFrame("Frame", nil, b)
        b.canvas:SetSize(tileH - 6, tileH - 6)
        b.canvas:SetPoint("LEFT", 3, 0)
        b.label = Text(b, 14)
        b.label:SetPoint("LEFT", b.canvas, "RIGHT", 6, 1)
        b.label:SetWidth(tileW - tileH - 10)
        b.label:SetJustifyH("LEFT")
        b.label:SetWordWrap(false)
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
            for _, line in ipairs(self.edges) do
                if on then line:SetColorTexture(0.95, 0.73, 0.32) else line:SetColorTexture(0.62, 0.55, 0.43) end
            end
            local w = math.min(self.label:GetStringWidth(), tileW - tileH - 10) + 6
            for k, t in ipairs(self.streak) do t:SetWidth(w - (k - 1) * 6) t:SetShown(on and true or false) end
            local c = on and RED or INK
            self.label:SetTextColor(c[1], c[2], c[3])
        end
        b:SetScript("OnClick", function() Click() spread.chapter, spread.page = ch[1], 0 ShowBook(true) end)
        spread.chapters[i] = b
    end`);
// ShowBook: each chapter's tile shows a piece of its own (the one picked in it, else its first you could pick).
rep(`    for i, button in ipairs(spread.chapters) do
        button.label:SetText(O(CHAPTERS[i][2], CHAPTERS[i][3]))
        button:Paint(CHAPTERS[i][1] == chapter)
    end`,
`    for i, button in ipairs(spread.chapters) do
        local key = CHAPTERS[i][1]
        button.label:SetText(O(CHAPTERS[i][2], CHAPTERS[i][3]))
        button:Paint(key == chapter)
        local sample = spread.sel and spread.sel.layer == key and spread.sel.option
        if not sample then
            for _, layer in ipairs(ns.MintLayers) do
                if layer.key == key then
                    for _, option in ipairs(layer.options) do if ns.MintAllowed(option) then sample = option break end end
                end
            end
        end
        if sample and button.sample ~= sample then button.sample = sample ns.DrawPiece(button.canvas, key, sample) end
    end`);
fs.writeFileSync(file, s);
console.log("done");
