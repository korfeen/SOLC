// One-off (2026-11-05): the Dream Bed is a room of its own (the sidebar's "Dream Bed", Ogre Rank 3), your wallpaper on
// its wall and the big red book on the rug opening your Collection (under it now, no button of its own). The
// inventory's MINT tile goes; the steward's rank-three lines and the empty showcase spots point at the room.
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

// The book's place: big, on the rug in front of the bed (drag it about in tools/dreambed-room.js).
const layoutFile = "tools/dreambed-layout.json";
const layout = JSON.parse(fs.readFileSync(layoutFile, "utf8"));
layout.book = { bottom: 0.985, rot: -7, w: 0.12, x: 0.355 };
fs.writeFileSync(layoutFile, JSON.stringify(layout, null, 1));

edit("DreamBed.lua", [
[`-- Opened over the page area, as a screen (UI.lua): ns.ShowDreamBed().`,
 `-- A room of its own: the sidebar's Dream Bed (its page only stands in for it: opening it shows the room over the page
-- area, leaving it puts the room away), from Ogre Rank 3 (Onboarding.lua). Your wallpaper is on its wall (the painting's
-- wall is cut out above the rail, tools/convert-dreambed.js), and the big red book on the rug opens your Collection (the
-- pixcollection page, under this one). ns.ShowDreamBed() goes there.`],
[`    W.back:SetShown(phase == "bed")  -- (only before the bonk: once he's dreaming, you see it through)`,
 `    W.back:SetShown(phase == "bed" and not S.asPage)  -- (only before the bonk; never in its own room: it's the page)`],
[`    panel:SetPoint("TOPLEFT", 0, -panelFrom * S.h)
    panel:SetSize(S.w, (wallTo - panelFrom) * S.h)`,
 `    panel:SetPoint("TOPLEFT", 0, -panelFrom * S.h)
    panel:SetSize(S.w, (wallTo - panelFrom) * S.h)
    -- Your wallpaper on the wall (behind the painting, its wall cut out above the rail), a touch dimmer than elsewhere (a
    -- bedroom by lamplight), a soft shadow along the rail. Put up as the room opens (PaperUp).
    local railY = (art.room.rail or panelFrom) * S.h
    W.paper = screen:CreateTexture(nil, "BACKGROUND", nil, -8)
    W.paper:SetPoint("TOPLEFT")
    W.paper:SetSize(S.w, railY + 2)
    W.paper.h = railY + 2
    local paperDim = screen:CreateTexture(nil, "BACKGROUND", nil, -7)
    paperDim:SetAllPoints(W.paper)
    paperDim:SetColorTexture(0.05, 0.03, 0.06, 0.28)
    local railShadow = screen:CreateTexture(nil, "BACKGROUND", nil, -6)
    railShadow:SetPoint("BOTTOMLEFT", W.paper, "BOTTOMLEFT")
    railShadow:SetSize(S.w, 14)
    railShadow:SetColorTexture(1, 1, 1)
    railShadow:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0.45), CreateColor(0, 0, 0, 0))`],
[`    local mugAt = At("mug")
    W.mug = PropOver(mugAt, function() end)
    W.mug:EnableMouse(false)  -- (no clicking: it's just a mug)
    Piece(W.mug, "mug", L.mug)`,
 `    local mugAt = At("mug")
    W.mug = PropOver(mugAt, function() end)
    W.mug:EnableMouse(false)  -- (no clicking: it's just a mug)
    Piece(W.mug, "mug", L.mug)
    -- Your Collection: the big book on the rug (PixCollection.lua's page, under this room's).
    if L.book and art.pieces.book then
        W.book = PropOver(At("book"), function() if ns.OpenPage then ns.OpenPage("pixcollection") end end,
            function() return O("Your Collection", "MY STUFF") end)
        Piece(W.book, "book", L.book)
        W.book.tag:SetText(O("Every piece you have, and every one you could dream of", "LOOK"))
    end`],
[`function ns.ShowDreamBed()
    if not W.screen then Build() end`,
 `-- Your wallpaper on the room's wall (Wallpaper.lua), as it is now.
local function PaperUp()
    if W.paper and UI.SetWallpaper and ns.GetWallpaper then
        UI.SetWallpaper(W.paper, ns.GetWallpaper(), S.w, W.paper.h, ns.WallpaperTune and ns.WallpaperTune("page") or 180)
    end
end

-- The room over the page area: as its own page (asPage: the sidebar's Dream Bed), else as a screen over another.
local function ShowRoom(asPage)
    if not W.screen then Build() end
    S.asPage = asPage
    PaperUp()`],
[`    if UI.SetScreen then UI.SetScreen("Dream Bed", "DREAM", function() screen:Hide() end) end
end`,
 `    if not asPage and UI.SetScreen then UI.SetScreen("Dream Bed", "DREAM", function() screen:Hide() end) end
    W.back:SetShown(S.phase == "bed" and not asPage)
end

-- Anything asking for the Dream Bed (the showcase, /solc dream): its room.
function ns.ShowDreamBed()
    if ns.OpenPage then ns.OpenPage("dreambed") else ShowRoom(false) end
end

-- The room's page (the sidebar's Dream Bed): it shows the room as it opens and puts it away as you leave. (Refreshed
-- often - a kill, a new picture: the room open, only its wallpaper is looked at again, a dream carries on.)
ns.RegisterPage({
    key = "dreambed", label = "Dream Bed", section = "me", order = 4,
    bare = true,
    create = function(parent)
        local page = CreateFrame("Frame", nil, parent)
        page:SetAllPoints()
        page:SetScript("OnHide", function() if W.screen and S.asPage then W.screen:Hide() end end)
        return page
    end,
    refresh = function()
        if W.screen and W.screen:IsShown() and S.asPage then PaperUp() else ShowRoom(true) end
    end,
})`],
]);

edit("PixCollection.lua", [[
`    key = "pixcollection", label = "Collection", section = "me", order = 4,`,
`    key = "pixcollection", label = "Collection", section = "me", order = 4, under = "dreambed",  -- (the Dream Bed's book opens it)`]]);

edit("Onboarding.lua", [
[`    { id = "collection", rank = 3, page = "pixcollection", lines = {
        { text = "Rank three. Persistent, aren't you. Like a rash. Your Collection is open, and the Dream Bed with it.", open = "pixcollection", glow = "pixcollection" },
        { text = "Find \\"Mint a picture\\" among your pictures. Lie down, an ogre tells you its dream, and you paint it. Badly, I assume." },
        { text = "What you paint becomes a picture all your own. Do keep it somewhere I won't have to look at it." },`,
 `    { id = "collection", rank = 3, page = "dreambed", lines = {
        { text = "Rank three. Persistent, aren't you. Like a rash. The Dream Bed is yours. Your own wallpaper, even. I chose none of it.", open = "dreambed", glow = "dreambed" },
        { text = "Bonk yourself to sleep with the mallet, an ogre dreams, and you paint it. Badly, I assume." },
        { text = "What you paint becomes a picture all your own. The big book on the rug is your Collection. Do keep it shut." },`],
[`local PAGE_RANKS = {}
for _, step in ipairs(STEPS) do if step.page then PAGE_RANKS[step.page] = step.rank end end`,
 `local PAGE_RANKS = {}
for _, step in ipairs(STEPS) do if step.page then PAGE_RANKS[step.page] = step.rank end end
PAGE_RANKS.pixcollection = PAGE_RANKS.dreambed  -- (the Collection is the Dream Bed's book: locked with it)`],
[`local NAMES = { deeds = "The Deeds", pixcollection = "Your Collection",`,
 `local NAMES = { deeds = "The Deeds", pixcollection = "The Dream Bed",`],
]);

edit("Gallery.lua", [
[`        local minting = not (ns.RankLocked and ns.RankLocked("pixcollection"))  -- (the Dream Bed opens with the Collection)
        if minting then entries[#entries + 1] = { mintAction = true } end`,
 `        local minting = not (ns.RankLocked and ns.RankLocked("pixcollection"))  -- (no minting here: the Dream Bed's own room)`],
[`            or #mints == 0 and "No pictures yet: mint your first!"`,
 `            or #mints == 0 and "No pictures yet: the Dream Bed awaits."`],
]);

edit("OverviewCard.lua", [[
`                elseif not self.key then
                    page.ShowPanel("inventory")  -- an empty spot of yours: your inventory, to open one and hang it`,
`                elseif not self.key and #(KillTrackerDB.mints or {}) == 0 and ns.ShowDreamBed then
                    ns.ShowDreamBed()  -- (no pictures yet: off to dream one)
                elseif not self.key then
                    page.ShowPanel("inventory")  -- an empty spot of yours: your inventory, to open one and hang it`]]);
console.log("done");
