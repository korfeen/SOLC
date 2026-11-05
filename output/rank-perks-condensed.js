// One-off (2026-11-05): the rank perks condensed: short labels, one line a rank (the rank panel shows the rank you're on
// and the next five, the rest summed up), the rank-up popup and the feed in the same words.
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

edit("Ranks.lua", [
[`table.sort(ns.RANK_PERKS, function(a, b) return a.rank < b.rank end)
`,
`table.sort(ns.RANK_PERKS, function(a, b) return a.rank < b.rank end)

-- A perk's short label, for the lists: a picture piece's name in its rarity's colour (MintArt.lua: loaded later, so
-- looked up when asked), else its short.
function ns.PerkLabel(perk)
    if perk.kind == "piece" then
        local found = ns.OptionByKey and ns.OptionByKey(perk.key)
        if found then return ("|c%s%s|r"):format(ns.RARITY_COLORS and ns.RARITY_COLORS[found.option.rarity] or "ffffffff", found.option.name) end
    end
    return perk.short or perk.text or "?"
end
-- What a rank brings, as one line ("Sea Dog Grin, Polaroid frame, 2 crayons"), or nil.
function ns.RankPerksLine(rank)
    local labels = {}
    for _, perk in ipairs(ns.RANK_PERKS) do
        if perk.rank == rank then labels[#labels + 1] = ns.PerkLabel(perk) end
    end
    return #labels > 0 and table.concat(labels, ", ") or nil
end
-- The perks after a rank, summed up: "24 more ranks: 16 picture pieces, 2 frames, 3 name colours, luck, a style".
local SUM = { { "piece", "picture piece", "picture pieces" }, { "frame", "frame", "frames" }, { "nameColor", "name colour", "name colours" },
    { "ogreStyle", "a style", "styles" }, { "crayons", "crayons", "crayons" }, { "voices", "voices", "voices" }, { "luck", "luck", "luck" },
    { "wallpaper", "a wallpaper", "wallpapers" } }
local COUNTED = { piece = true, frame = true, nameColor = true }
function ns.RankPerksAfter(rank)
    local counts, ranks = {}, {}
    for _, perk in ipairs(ns.RANK_PERKS) do
        if perk.rank > rank then
            counts[perk.kind] = (counts[perk.kind] or 0) + 1
            ranks[perk.rank] = true
        end
    end
    local parts, n = {}, 0
    for _ in pairs(ranks) do n = n + 1 end
    if n == 0 then return nil end
    for _, s in ipairs(SUM) do
        local c = counts[s[1]]
        if c then parts[#parts + 1] = COUNTED[s[1]] and ("%d %s"):format(c, c == 1 and s[2] or s[3]) or (c == 1 and s[2] or s[3]) end
    end
    return ("%d more rank%s: %s"):format(n, n == 1 and "" or "s", table.concat(parts, ", "))
end
`],
[`    local unlocked = {}
    for _, perk in ipairs(ns.RANK_PERKS) do
        if perk.rank > seen and perk.rank <= current.rank then unlocked[#unlocked + 1] = perk.text end
    end
    unlocked[#unlocked + 1] = ("%d %s for the Dream Bed"):format(bonks, bonks == 1 and "Bonk" or "Bonks")
    ns.ShowToast("achievement", ("Rank %d!"):format(current.rank), current.title, unlocked[1])`,
`    local unlocked = {}
    for rank = seen + 1, current.rank do unlocked[#unlocked + 1] = ns.RankPerksLine(rank) end
    if not (ns.RankLocked and ns.RankLocked("pixcollection")) then  -- (no Dream Bed talk before it's open: Onboarding.lua)
        unlocked[#unlocked + 1] = ("%d %s for the Dream Bed"):format(bonks, bonks == 1 and "Bonk" or "Bonks")
    end
    ns.ShowToast("achievement", ("Rank %d!"):format(current.rank), current.title, ns.RankPerksLine(current.rank) or unlocked[1])`],
]);

edit("FeedDetail.lua", [[
`                Add(YES .. perk.text)`,
`                Add(YES .. ns.PerkLabel(perk))`]]);

// ProfileHeader: the rank panel's rows, one a rank.
edit("ProfileHeader.lua", [
[`local RANK_LINES = 20                        -- perk lines in the rank panel`,
 `local RANK_ROWS = 6                          -- ranks listed in the rank panel (the one you're on and the next ones)`],
[`    rank.lines = {}
    for i = 1, RANK_LINES do
        local line = rank:CreateFontString(nil, "OVERLAY")
        line:SetFont(NAME_FONT, 12, "")
        line:SetPoint("TOPLEFT", 4, -68 - i * 16)
        line:SetWidth(slot.right - slot.left - 28)
        line:SetJustifyH("LEFT")
        line:SetWordWrap(false)
        rank.lines[i] = line
    end`,
`    -- A row a rank: "rank 3" and what it brings (wrapping onto a second line if it must), then the rest summed up.
    rank.rows = {}
    local above
    for i = 1, RANK_ROWS + 1 do
        local row = {}
        row.text = rank:CreateFontString(nil, "OVERLAY")
        row.text:SetFont(NAME_FONT, 12, "")
        row.text:SetWidth(slot.right - slot.left - 92)
        row.text:SetJustifyH("LEFT")
        row.text:SetWordWrap(true)
        row.text:SetMaxLines(2)
        if above then row.text:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -4) else row.text:SetPoint("TOPLEFT", 66, -88) end
        row.label = rank:CreateFontString(nil, "OVERLAY")
        row.label:SetFont(NAME_FONT, 12, "")
        row.label:SetWidth(62)
        row.label:SetJustifyH("LEFT")
        row.label:SetPoint("TOPRIGHT", row.text, "TOPLEFT", -2, 0)
        above = row.text
        rank.rows[i] = row
    end`],
[`    -- (more perks than lines: the last few reached, then what comes next)
    local first = 1
    for i, perk in ipairs(ns.RANK_PERKS) do
        if perk.rank <= current.rank then first = i end
    end
    first = math.max(1, math.min(first - 3, #ns.RANK_PERKS - #rank.lines + 1))
    for i, line in ipairs(rank.lines) do
        local perk = ns.RANK_PERKS[first + i - 1]
        if perk then
            local unlocked = perk.rank <= current.rank
            line:SetText(("%s|cff999999rank %d|r  %s"):format(unlocked and "|cff55dd55+|r " or "   ", perk.rank,
                unlocked and perk.text or "|cff888888" .. perk.text .. "|r"))
        end
        line:SetShown(perk ~= nil)
    end`,
`    -- The ranks with perks: the last one you've reached, then the next ones (RANK_ROWS in all), then the rest summed up.
    local ranks, seenRank = {}, {}
    for _, perk in ipairs(ns.RANK_PERKS) do
        if not seenRank[perk.rank] then seenRank[perk.rank] = true ranks[#ranks + 1] = perk.rank end
    end
    local first = 1
    for i, r in ipairs(ranks) do if r <= current.rank then first = i end end
    local last = math.min(#ranks, first + RANK_ROWS - 1)
    first = math.max(1, last - RANK_ROWS + 1)
    for i, row in ipairs(rank.rows) do
        local r = i <= RANK_ROWS and ranks[first + i - 1]
        if r then
            local reached = r <= current.rank
            row.label:SetText(("%s|cff%srank %d|r"):format(reached and "|cff55dd55+|r " or "   ", reached and "cccccc" or "999999", r))
            row.text:SetText(ns.RankPerksLine(r))
            row.text:SetTextColor(unpack(reached and PANEL_TEXT or { 0.62, 0.6, 0.56 }))
        elseif i == #rank.rows then  -- (the summary)
            row.label:SetText("")
            row.text:SetText(ranks[last] and ns.RankPerksAfter(ranks[last]) and ("|cff888888...%s|r"):format(ns.RankPerksAfter(ranks[last])) or "")
        end
        local shown = (r or i == #rank.rows) and true or false
        row.label:SetShown(shown)
        row.text:SetShown(shown)
        if not shown then row.text:SetText("") end
    end`],
]);
console.log("done");
