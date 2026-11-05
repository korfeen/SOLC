// One-off (2026-11-05): what belongs to a rank-locked page stays hidden until its rank - its news, the Guild page's
// bounty box, chips and ranking tabs, bounty progress, the Dream Bed's chat lines, the shop's wallpapers in EDIT.
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
const reindent = (text, by) => text.split("\n").map((l) => (l ? by + l : l)).join("\n");

edit("Onboarding.lua", [[
`function ns.RankLocked(key)
    local rank = PAGE_RANKS[key]
    return rank ~= nil and ns.TourRank() < rank
end
`,
`function ns.RankLocked(key)
    local rank = PAGE_RANKS[key]
    return rank ~= nil and ns.TourRank() < rank
end
-- News (Feed.lua's kinds) about a locked page's things: kept out of every feed until its rank.
local KIND_PAGES = { A = "deeds", M = "pixcollection", W = "pixcollection", U = "pixcollection", B = "bounties", P = "bounties" }
function ns.KindLocked(kind)
    local page = KIND_PAGES[kind]
    return page ~= nil and ns.RankLocked(page)
end
`]]);

edit("Feed.lua", [[
`            local text = (not guild or ns.FeedWorthy(e.k, e.a, e.b)) and Describe(e, who, source, calm)`,
`            local text = not (ns.KindLocked and ns.KindLocked(e.k)) and (not guild or ns.FeedWorthy(e.k, e.a, e.b))
                and Describe(e, who, source, calm)  -- (news of a page still locked for you: Onboarding.lua)`]]);

// CavePage: chips and metric tabs carry their page (spec[5]); built from the open ones.
let cave = fs.readFileSync("CavePage.lua", "utf8");
const cnl = cave.includes("\r\n") ? "\r\n" : "\n";
const L = cave.split(cnl);
const start = L.findIndex((l) => l.includes("-- The chips: click one to show or hide that kind of news."));
const end = L.findIndex((l, i) => i > start && l === "            page.chips[i] = chip");
if (start < 0 || end < 0 || L[end + 1] !== "        end") throw Error("chips block");
if (!L[start + 1].includes("page.chips = {}") || !L[start + 2].includes("local chipWidth") || !L[start + 3].includes("for i, spec in ipairs(CHIPS)")) throw Error("chips head");
const body = L.slice(start + 4, end + 1).join("\n");  // (inside the loop, through "page.chips[i] = chip")
const chipBlock = [
  "        -- The chips: click one to show or hide that kind of news. Only the ones whose page is open (Onboarding.lua's",
  "        -- rank locks): rebuilt as ranks open more (refresh).",
  "        page.chips = {}",
  "        function page.BuildChips(specs)",
  "            for _, chip in ipairs(page.chips) do chip:Hide() end",
  "            page.chips = {}",
  "            local chipWidth = (slot.right - slot.left - 4) / #specs",
  "            for i, spec in ipairs(specs) do",
  reindent(body, "    "),
  "            end",
  "        end",
].join("\n");
L.splice(start, end + 2 - start, ...chipBlock.split("\n"));
fs.writeFileSync("CavePage.lua", L.join(cnl));

edit("CavePage.lua", [
[`    { "deeds", "DEEDS", "BRAG", "Deeds earned and Ogre Ranks reached" },
    { "kills", "KILLS", "SMASH", "Leaders slain and dungeons cleared with the guild" },
    { "pix", "PIX", "PIX", "Pictures minted and won" },
    { "hunts", "HUNTS", "HUNTS", "Bounties completed" },`,
`    { "deeds", "DEEDS", "BRAG", "Deeds earned and Ogre Ranks reached", "deeds" },  -- (5: the page it waits on)
    { "kills", "KILLS", "SMASH", "Leaders slain and dungeons cleared with the guild" },
    { "pix", "PIX", "PIX", "Pictures minted and won", "pixcollection" },
    { "hunts", "HUNTS", "HUNTS", "Bounties completed", "bounties" },`],
[`    { "bounty", "BOUNTY", "HUNTS", "Bounties claimed this week" },`,
 `    { "bounty", "BOUNTY", "HUNTS", "Bounties claimed this week", "bounties" },  -- (5: the page it waits on)`],
[`    { "pictures", "PIX", "PIX", "Pictures minted" },
}`,
`    { "pictures", "PIX", "PIX", "Pictures minted", "pixcollection" },
}
-- The specs whose page (spec[5]) is open for you (Onboarding.lua's rank locks), and a key naming them.
local function Open(specs)
    local list, key = {}, ""
    for _, spec in ipairs(specs) do
        if not (spec[5] and ns.RankLocked and ns.RankLocked(spec[5])) then list[#list + 1] = spec key = key .. spec[1] .. "," end
    end
    return list, key
end
local function BountiesLocked() return ns.RankLocked ~= nil and ns.RankLocked("bounties") end`],
[`    -- This week's bounty posters: yours claimed, the guild's count.
    local board = ns.GetPosterProgress and ns.GetPosterProgress()
    local b = page.bountyBox
    if board then`,
`    -- This week's bounty posters: yours claimed, the guild's count. (Before the board opens: your way to the next rank.)
    local board = not BountiesLocked() and ns.GetPosterProgress and ns.GetPosterProgress()
    local b = page.bountyBox
    if BountiesLocked() then
        local current, nextRank, points = ns.GetRank()
        Fit(b.name, NAME_FONT, 15, 10, ("|cffffd100Ogre Rank %d|r  %s"):format(current.rank, current.title), b.width)
        local share = nextRank and (points - current.points) / math.max(1, nextRank.points - current.points) or 1
        b.fill:SetWidth(math.max(1, (b.width - 2) * math.min(1, share)))
        b.barText:SetText(nextRank and ("%d/%d points"):format(points, nextRank.points) or "The top rank")
        b.details:SetText(nextRank and ("%d more to rank %d - and more of the club"):format(nextRank.points - points, nextRank.rank) or "")
        b.track:Show()
    elseif board then`],
[`    local hidden = KillTrackerDB.feedHidden or {}
    for _, chip in ipairs(page.chips) do chip:Redraw(false) end`,
`    -- (a chip still locked hides nothing: its page's news is out anyway, ns.GetFeed, and what's left of its group shows)
    local hidden = {}
    for group in pairs(KillTrackerDB.feedHidden or {}) do hidden[group] = true end
    for _, spec in ipairs(CHIPS) do if spec[5] and ns.RankLocked and ns.RankLocked(spec[5]) then hidden[spec[1]] = nil end end
    for _, chip in ipairs(page.chips) do chip:Redraw(false) end`],
[`            UI.ClickSound()
            ns.OpenPage("bounties")
        end)
        box:SetScript("OnEnter", function(self)
            local board = ns.GetPosterProgress and ns.GetPosterProgress()`,
`            UI.ClickSound()
            ns.OpenPage(BountiesLocked() and "overview" or "bounties")
        end)
        box:SetScript("OnEnter", function(self)
            local board = not BountiesLocked() and ns.GetPosterProgress and ns.GetPosterProgress()`],
[`        page.metricTabs = TabStrip(board, METRICS, right.left, right.right, RIGHT.tabs, function() return page.metric end,
            function(key) page.metric = key end)`,
`        -- (the measures whose page is open: rebuilt as ranks open more, like the chips)
        page.metricTabs = {}
        function page.BuildMetricTabs(specs)
            for _, tab in ipairs(page.metricTabs) do tab:Hide() end
            page.metricTabs = TabStrip(board, specs, right.left, right.right, RIGHT.tabs, function() return page.metric end,
                function(key) page.metric = key end)
        end`],
[`    refresh = function(p)
        for _, tab in ipairs(p.tabs) do tab:Redraw(false) end`,
`    refresh = function(p)
        local chips, chipKey = Open(CHIPS)
        if chipKey ~= p.chipKey then p.chipKey = chipKey p.BuildChips(chips) end
        local metrics, metricKey = Open(METRICS)
        if metricKey ~= p.metricKey then p.metricKey = metricKey p.BuildMetricTabs(metrics) end
        if not metricKey:find(p.metric .. ",", 1, true) then p.metric = "points" end
        for _, tab in ipairs(p.tabs) do tab:Redraw(false) end`],
]);

edit("Posters.lua", [[
`local function CountWhere(test)
    local board, mine = MyBoard()`,
`local function CountWhere(test)
    if ns.RankLocked and ns.RankLocked("bounties") then return end  -- (no posters before the board opens: Onboarding.lua)
    local board, mine = MyBoard()`]]);

edit("Unlocks.lua", [
[`    if not quiet then
        ns.Print(("|T%s:16|t You found %s%s, for the Dream Bed."):format(`,
 `    if not quiet and not (ns.RankLocked and ns.RankLocked("pixcollection")) then  -- (quiet till the Dream Bed opens)
        ns.Print(("|T%s:16|t You found %s%s, for the Dream Bed."):format(`],
[`                if key and ns.UnlockOption(key) then
                    new = true
                    ns.ShowToast(`,
 `                if key and ns.UnlockOption(key) then
                    new = true
                    if not (ns.RankLocked and ns.RankLocked("pixcollection")) then ns.ShowToast(`],
[`"Worn: it can roll in your pictures now")`, `"Worn: it can roll in your pictures now") end`],
[`            if name and ns.UnlockPool(LootKey(name)) > 0 then
                ns.ShowToast("achievement", "Unlocked for minting!", name, "It can roll in your pictures now")`,
 `            if name and ns.UnlockPool(LootKey(name)) > 0 then
                if not (ns.RankLocked and ns.RankLocked("pixcollection")) then  -- (quiet till the Collection opens)
                    ns.ShowToast("achievement", "Unlocked for minting!", name, "It can roll in your pictures now")
                end`],
]);

edit("Chests.lua", [[
`    if #names > 0 and not show.preview then ns.Print(`,
`    if #names > 0 and not show.preview and not (ns.RankLocked and ns.RankLocked("pixcollection")) then ns.Print(`]]);

edit("OverviewCard.lua", [[
`            local has, how = ns.WallpaperUnlocked(paper)
            list[#list + 1] =`,
`            local has, how = ns.WallpaperUnlocked(paper)
            -- (the shop's ones only once the Pro Shop is open: Onboarding.lua)
            if has or not paper.price or not (ns.RankLocked and ns.RankLocked("proshop")) then list[#list + 1] =`],
[`                locked = not has, how = how, price = not has and paper.price or nil }`,
 `                locked = not has, how = how, price = not has and paper.price or nil } end`]]);

edit("Wallpaper.lua", [[
`    if ns.WallpaperUnlocked(paper) then return false, "You have it already." end`,
`    if ns.WallpaperUnlocked(paper) then return false, "You have it already." end
    if ns.RankLocked and ns.RankLocked("proshop") then return false, "The Pro Shop isn't open to you yet." end`]]);
console.log("done");
