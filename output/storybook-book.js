// One-off (2026-11-05): the Dream Bed's story picker as the Collection's book: the whole red book (Media\Collection\book,
// cover and all) open over the room; on its left page the chapters as inked words (red with a hand-drawn streak under
// the open one, red on hover), on its right the pieces as paper cards 3 x 3 (rarity edges, gold round the picked one).
const fs = require("fs");
const path = require("path");
process.chdir(path.join(__dirname, ".."));
const file = "DreamBed.lua";
let s = fs.readFileSync(file, "utf8");
const nl = s.includes("\r\n") ? "\r\n" : "\n";
const N = (t) => t.replace(/\n/g, nl);
function rep(a, b) { a = N(a); b = N(b); if (s.split(a).length !== 2) throw Error("not found: " + a.slice(0, 70)); s = s.replace(a, () => b); }

rep(`local CARDS_PER_PAGE = 8`, `local CARDS_PER_PAGE = 9  -- (3 x 3 on the storybook's right page)`);

// ShowBook: chapters and cards painted the book's way.
rep(`    for i, button in ipairs(spread.chapters) do
        local on = CHAPTERS[i][1] == chapter
        button.label:SetText(O(CHAPTERS[i][2], CHAPTERS[i][3]))
        button.label:SetTextColor(on and 1 or INK[1], on and 0.91 or INK[2], on and 0.72 or INK[3])
        button.bg:SetShown(on)
    end`,
`    for i, button in ipairs(spread.chapters) do
        button.label:SetText(O(CHAPTERS[i][2], CHAPTERS[i][3]))
        button:Paint(CHAPTERS[i][1] == chapter)
    end`);
rep(`            local rim = RIM[option.rarity] or RIM.uncommon
            for _, edge in ipairs(card.edges) do edge:SetColorTexture(rim[1], rim[2], rim[3]) end`,
`            local picked = spread.sel and spread.sel.option == option
            local rim = picked and { 0.95, 0.73, 0.32 } or RIM[option.rarity] or RIM.uncommon
            for _, edge in ipairs(card.edges) do edge:SetColorTexture(rim[1], rim[2], rim[3]) end`);
rep(`            local picked = spread.sel and spread.sel.option == option
            card.picked:SetShown(picked)`,
`            card.picked:SetShown(picked)`);
rep(`    spread.prev:SetEnabled(spread.page > 0)
    spread.next:SetEnabled(spread.page < pages - 1)`,
`    spread.prev:SetShown(spread.page > 0)
    spread.next:SetShown(spread.page < pages - 1)`);
rep(`    spread.pick:SetEnabled(sel ~= nil)
    spread.pick.label:SetText(sel and O("Think about the " .. sel.option.name, "THIS ONE") or O("Pick a piece", "PICK"))`,
`    spread.pick:SetEnabled(sel ~= nil)
    spread.pick.label:SetText(sel and O("Think about the " .. sel.option.name, "THIS ONE") or O("Pick a piece", "PICK"))
    spread.pick:Paint(sel ~= nil)`);

// BuildBook: replaced whole.
const a = s.indexOf(N("local function BuildBook()"));
const b = s.indexOf(N("-- The thought bubble over his head"), a);
if (a < 0 || b < 0) throw Error("BuildBook");
const build = `-- A word in ink on the storybook's pages that you click: red with a hand-drawn streak under it when it's the one
-- (Paint(true)), red on hover. (The Collection's book does the same: PixCollection.lua.)
local RED = { 0.55, 0.12, 0.08 }
local function InkWord(parent, size, onClick)
    local b = CreateFrame("Button", nil, parent)
    b.label = Text(b, size)
    b.label:SetPoint("LEFT")
    b.label:SetTextColor(INK[1], INK[2], INK[3])
    b.streak = {}
    for i, stroke in ipairs({ { 3, -3, 0.85, -1.2, 0 }, { 2, -6, 0.5, 0.9, 4 } }) do  -- height, y, alpha, tilt, x
        local t = b:CreateTexture(nil, "ARTWORK")
        t:SetColorTexture(RED[1], RED[2], RED[3], stroke[3])
        t:SetHeight(stroke[1])
        t:SetPoint("TOPLEFT", b.label, "BOTTOMLEFT", stroke[5] - 4, stroke[2] + 2)
        t:SetRotation(math.rad(stroke[4]))
        t:Hide()
        b.streak[i] = t
    end
    function b:Paint(on)
        self.on = on
        local w = self.label:GetStringWidth() + 10
        self:SetSize(w, size + 10)
        for i, t in ipairs(self.streak) do t:SetWidth(w - (i - 1) * 8) t:SetShown(on and true or false) end
        local c = (on or self.hovered) and self:IsEnabled() and RED or INK
        self.label:SetTextColor(c[1], c[2], c[3], self:IsEnabled() and 1 or 0.4)
    end
    b:SetScript("OnClick", function(...) Click() onClick(...) end)
    b:SetScript("OnEnter", function(self) self.hovered = true self:Paint(self.on) end)
    b:SetScript("OnLeave", function(self) self.hovered = false self:Paint(self.on) end)
    return b
end

-- The storybook: the Collection's red book (its painting, cover and all) lying open over the room.
local BOOK_ART = "Interface\\\\AddOns\\\\SOLC\\\\Media\\\\Collection\\\\book"
local BOOK_CROP = { x0 = 18, x1 = 1495, y0 = 30, y1 = 1010, w = 1536, h = 1024 }  -- (the book in its painting, painting pixels)
-- Its pages in that crop, as fractions: left and right, top and bottom.
local BOOK_PAGES = { l0 = 0.0555, l1 = 0.5058, r0 = 0.5105, r1 = 0.9695, top = 0.0265, bottom = 0.911 }
local function BuildBook()
    local spread = CreateFrame("Frame", nil, W.screen)
    local bw = S.w * 0.9
    local bh = bw * (BOOK_CROP.y1 - BOOK_CROP.y0) / (BOOK_CROP.x1 - BOOK_CROP.x0)
    spread:SetSize(bw, bh)
    spread:SetPoint("CENTER", 0, -4)
    spread:SetFrameLevel(W.screen:GetFrameLevel() + 40)
    spread:EnableMouse(true)
    spread.chapter, spread.page = "headwear", 0
    local shade = spread:CreateTexture(nil, "BACKGROUND", nil, -8)
    shade:SetPoint("TOPLEFT", W.screen) shade:SetPoint("BOTTOMRIGHT", W.screen)
    shade:SetColorTexture(0.04, 0.03, 0.09, 0.6)
    local book = spread:CreateTexture(nil, "BACKGROUND", nil, -7)
    book:SetAllPoints()
    book:SetTexture(BOOK_ART)
    book:SetTexCoord(BOOK_CROP.x0 / BOOK_CROP.w, BOOK_CROP.x1 / BOOK_CROP.w, BOOK_CROP.y0 / BOOK_CROP.h, BOOK_CROP.y1 / BOOK_CROP.h)
    local P = BOOK_PAGES
    local pad = 22
    local L = { x = P.l0 * bw + pad, y = P.top * bh + pad, w = (P.l1 - P.l0) * bw - 2 * pad, h = (P.bottom - P.top) * bh - 2 * pad }
    local R = { x = P.r0 * bw + pad, y = P.top * bh + pad, w = (P.r1 - P.r0) * bw - 2 * pad, h = (P.bottom - P.top) * bh - 2 * pad }
    local function At(region, x, y) region:SetPoint("TOPLEFT", spread, "TOPLEFT", x, -y) end

    -- The left page: what this is, the chapters, the stories you have, your choice.
    local title = Text(spread, 22)
    At(title, L.x, L.y)
    title:SetTextColor(RED[1], RED[2], RED[3])
    spread.title = title
    local note = Text(spread, 12)
    At(note, L.x, L.y + 32)
    note:SetWidth(L.w)
    note:SetJustifyH("LEFT")
    note:SetTextColor(0.35, 0.26, 0.16)
    spread.note = note
    spread.chapters = {}
    for i, ch in ipairs(CHAPTERS) do
        local b = InkWord(spread, 15, function() spread.chapter, spread.page = ch[1], 0 ShowBook(true) end)
        At(b, L.x, L.y + 98 + (i - 1) * 27)
        spread.chapters[i] = b
    end
    spread.storiesText = Text(spread, 13)
    At(spread.storiesText, L.x, L.y + L.h - 70)
    spread.storiesText:SetTextColor(INK[1], INK[2], INK[3])
    spread.pick = InkWord(spread, 15, function()
        if not spread.sel then return end
        S.story = { layer = spread.sel.layer, option = spread.sel.option }
        ShowBook(false)
        Refresh()
    end)
    At(spread.pick, L.x, L.y + L.h - 44)
    local none = InkWord(spread, 13, function() S.story, spread.sel = nil, nil ShowBook(false) Refresh() end)
    At(none, L.x, L.y + L.h - 18)
    spread.none = none

    -- The right page: the pieces, 3 x 3 paper cards, a page at a time.
    spread.cards = {}
    local cols, rows, gap = 3, 3, 8
    local cw, chh = (R.w + gap) / cols, (R.h - 26 + gap) / rows
    for i = 1, CARDS_PER_PAGE do
        local card = CreateFrame("Button", nil, spread)
        card:SetSize(cw - gap, chh - gap)
        At(card, R.x + ((i - 1) % cols) * cw, R.y + math.floor((i - 1) / cols) * chh)
        local bg = card:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.86, 0.79, 0.64)
        card.edges = {}
        for e = 1, 4 do
            local edge = card:CreateTexture(nil, "BORDER")
            if e <= 2 then edge:SetHeight(2) edge:SetPoint(e == 1 and "TOPLEFT" or "BOTTOMLEFT") edge:SetPoint(e == 1 and "TOPRIGHT" or "BOTTOMRIGHT")
            else edge:SetWidth(2) edge:SetPoint(e == 3 and "TOPLEFT" or "TOPRIGHT") edge:SetPoint(e == 3 and "BOTTOMLEFT" or "BOTTOMRIGHT") end
            card.edges[e] = edge
        end
        local hover = card:CreateTexture(nil, "HIGHLIGHT")
        hover:SetPoint("TOPLEFT", 2, -2) hover:SetPoint("BOTTOMRIGHT", -2, 2)
        hover:SetColorTexture(1, 0.95, 0.8, 0.25)
        local side = math.min(cw - gap - 10, chh - gap - 26)
        card.canvas = CreateFrame("Frame", nil, card)
        card.canvas:SetSize(side, side)
        card.canvas:SetPoint("TOP", 0, -4)
        card.name = Text(card, 11)
        card.name:SetPoint("BOTTOM", 0, 5)
        card.name:SetWidth(cw - gap - 8)
        card.name:SetWordWrap(false)
        card.name:SetTextColor(INK[1], INK[2], INK[3])
        card.cost = Text(card, 13)
        card.cost:SetPoint("TOPRIGHT", -5, -3)
        card.cost:SetTextColor(RED[1], RED[2], RED[3])
        card.picked = card:CreateTexture(nil, "BACKGROUND", nil, -1)
        card.picked:SetPoint("TOPLEFT", -8, 8) card.picked:SetPoint("BOTTOMRIGHT", 8, -8)
        card.picked:SetTexture(GLOW)
        card.picked:SetBlendMode("ADD")
        card.picked:SetVertexColor(1, 0.82, 0.3)
        card:SetScript("OnClick", function(self)
            if not self.option then return end
            Click()
            spread.sel = { layer = spread.chapter, option = self.option }
            ShowBook(true)
        end)
        card:SetScript("OnEnter", function(self)
            if self.option and UI.Tooltip then
                UI.Tooltip(self, { ("|c%s%s|r"):format(ns.RARITY_COLORS[self.option.rarity] or "ffffffff", self.option.name),
                    O(("%d bedtime %s"):format(ns.STORY_COST[self.option.rarity] or 1, (ns.STORY_COST[self.option.rarity] or 1) == 1 and "story" or "stories"), "STORY") })
            end
        end)
        card:SetScript("OnLeave", GameTooltip_Hide)
        spread.cards[i] = card
    end
    spread.pageText = Text(spread, 12)
    spread.pageText:SetPoint("BOTTOM", spread, "TOPLEFT", R.x + R.w / 2, -(R.y + R.h - 4))
    spread.pageText:SetTextColor(INK[1], INK[2], INK[3])
    spread.prev = InkWord(spread, 16, function() spread.page = spread.page - 1 ShowBook(true) end)
    spread.prev.label:SetText("<")
    spread.prev:Paint(false)
    spread.prev:SetPoint("RIGHT", spread.pageText, "LEFT", -14, 0)
    spread.next = InkWord(spread, 16, function() spread.page = spread.page + 1 ShowBook(true) end)
    spread.next.label:SetText(">")
    spread.next:Paint(false)
    spread.next:SetPoint("LEFT", spread.pageText, "RIGHT", 14, 0)
    spread:EnableMouseWheel(true)
    spread:SetScript("OnMouseWheel", function(_, delta)
        local pages = math.ceil(#(spread.options or {}) / CARDS_PER_PAGE)
        spread.page = math.max(0, math.min(pages - 1, spread.page - delta))
        ShowBook(true)
    end)
    spread:Hide()
    W.spread = spread
    hooksecurefunc(spread, "Show", function()
        spread.title:SetText(O("What's he thinking about?", "THINK?"))
        spread.note:SetText(O("Pick a piece and he'll dream about it for sure. It costs Bedtime Stories by its rarity, and doesn't count towards the painting's luck.",
            "PICK THING. HE DREAM IT."))
        none.label:SetText(O("Nothing, thank you", "ZZZ"))
        none:Paint(false)
    end)
end

`;
s = s.slice(0, a) + N(build) + s.slice(b);
fs.writeFileSync(file, s);
console.log("done");
