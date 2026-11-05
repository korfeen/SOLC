// One-off (2026-11-05): four kinds of bounty poster - HUNT (a creature kind), CLAN (a faction or ogre tribe), WANTED (a
// dungeon's end boss) and ODD JOB (rares, elites, leaders, exploring, PvP, gathering, fishing) - one of each on the
// board, each with its own colour and headline. Tiers stay for the reward. New odd jobs: gathering and fishing.
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
edit("Guild.lua", [[
`    { id = "explorers", name = "Explorers",`,
`    { id = "gather", name = "Gather Round", goal = 150, event = "gather", desc = "Herbs picked, ore mined and hides skinned: any of them counts." },
    { id = "fish", name = "Gone Fishing", goal = 100, event = "fish", desc = "Fish, crates and boots: anything you reel in." },
    { id = "explorers", name = "Explorers",`]]);
edit("LifeStats.lua", [[
`    local life = Life()
    life[kind] = (life[kind] or 0) + 1`,
`    local life = Life()
    life[kind] = (life[kind] or 0) + 1
    if ns.OnBountyEvent then ns.OnBountyEvent(kind == "fish" and "fish" or "gather") end  -- (the odd-job posters)`]]);
edit("Posters.lua", [[
`    explorers = { "hard", 10 },`,
`    explorers = { "hard", 10 }, gather = { "medium", 40 }, fish = { "medium", 40 },`],
[`-- The rotation's mix for each board size: the tier of each slot.
local MIX = {
    [3] = { "easy", "medium", "hard" },
    [4] = { "easy", "easy", "medium", "hard" },
    [5] = { "easy", "easy", "medium", "medium", "hard" },
}`,
`-- The four kinds of poster: HUNT (a creature kind), CLAN (a faction or ogre tribe), WANTED (a dungeon's end boss) and
-- ODD JOB (anything that isn't one kind of foe: rares, elites, leaders, exploring, PvP, gathering, fishing).
local ODD = { elites = true, rares = true, leaders = true, dungeons = true, pvp = true, explorers = true, gather = true, fish = true }
local HUNT = { undead = true, demon = true, elemental = true, dragonkin = true }
local function Kind(id)
    if id:find("^wanted_") then return "wanted" end
    if ODD[id] or id:find("^pvp_") then return "odd" end
    if HUNT[id] or id:find("^kind_") or id:find("^%u") then return "hunt" end  -- (the creature kinds: Murloc, Wolf...)
    return "clan"
end
ns.PosterKind = function(id) return id and Kind(id) end
-- The rotation's mix for each board size: the kind of each slot. A kind with nothing for a bracket (no dungeon for
-- the low levels) takes its fallback's.
local MIX = {
    [3] = { "hunt", "clan", "odd" },
    [4] = { "hunt", "clan", "wanted", "odd" },
    [5] = { "hunt", "hunt", "clan", "wanted", "odd" },
}
local FALLBACK = { wanted = "odd", clan = "hunt", odd = "hunt" }`],
[`        poster = { id = id, name = "Wanted: " .. WANTED[key], event = "wanted", dungeon = key, tier = "hard", solo = 1,`,
`        poster = { id = id, name = "Wanted: " .. WANTED[key], event = "wanted", dungeon = key, tier = "hard", kind = "wanted", solo = 1,`],
[`        poster = setmetatable({ tier = tier[1], solo = tier[2], levels = LEVELS[id] }, { __index = bounty })`,
`        poster = setmetatable({ tier = tier[1], kind = Kind(id), solo = tier[2], levels = LEVELS[id] }, { __index = bounty })`],
[`-- The rotation's pool for a tier and bracket: catalogue bounties, and for hard also the dungeons' wanted posters, that
-- fit the bracket's levels - and the guild's side:`,
`-- The rotation's pool for a kind and bracket: catalogue bounties, or the dungeons' wanted posters, that fit the
-- bracket's levels - and the guild's side:`],
[`-- bounties in the rotation too (the Alliance starter zones' foes), by tier.`, `-- bounties in the rotation too (the Alliance starter zones' foes).`],
[`local EXTRA = { easy = { "kind_kobold", "kind_gnoll", "kind_trogg" } }`, `local EXTRA = { "kind_kobold", "kind_gnoll", "kind_trogg" }`],
[`local function Pool(tier, bracket)
    local side = UnitFactionGroup and UnitFactionGroup("player")
    local key = tier .. ":" .. tostring(bracket) .. ":" .. tostring(side)`,
`local function Pool(kind, bracket)
    local side = UnitFactionGroup and UnitFactionGroup("player")
    local key = kind .. ":" .. tostring(bracket) .. ":" .. tostring(side)`],
[`        local poster = TIERS[bounty.id] and TIERS[bounty.id][1] == tier and PosterBounty(bounty.id)`,
`        local poster = TIERS[bounty.id] and Kind(bounty.id) == kind and PosterBounty(bounty.id)`],
[`    for _, id in ipairs(EXTRA[tier] or {}) do
        local poster = PosterBounty(id)`,
`    for _, id in ipairs(EXTRA) do
        local poster = Kind(id) == kind and PosterBounty(id)`],
[`    if tier == "hard" then
        for _, d in ipairs(ns.Dungeons`, `    if kind == "wanted" then
        for _, d in ipairs(ns.Dungeons`],
[`-- The rotation's poster for a slot: from its tier's pool for the bracket, by the guild, week, slot and bracket, never one
-- already on the board.
local function RotationPick(guild, week, slot, tier, bracket, taken)
    local pool = Pool(tier, bracket)
    if #pool == 0 then return end`,
`-- The rotation's poster for a slot: from its kind's pool for the bracket (or its fallback's, empty), by the guild,
-- week, slot and bracket, never one already on the board.
local function RotationPick(guild, week, slot, kind, bracket, taken)
    local pool = Pool(kind, bracket)
    for _ = 1, 3 do
        if #pool > 0 or not FALLBACK[kind] then break end
        kind = FALLBACK[kind]
        pool = Pool(kind, bracket)
    end
    if #pool == 0 then return end`],
[`-- What could go on a poster for a bracket, for the officers' picker: { { tier, ids } } (catalogue, then wanted posters).
function ns.PosterCatalogue(bracket)
    local out = {}
    for _, tier in ipairs({ "easy", "medium", "hard" }) do out[#out + 1] = { tier = tier, ids = Pool(tier, bracket) } end
    return out
end`,
`-- What could go on a poster for a bracket, for the officers' picker: { { kind, label, ids } }, by kind.
local KIND_LABELS = { hunt = "HUNT", clan = "CLAN", wanted = "WANTED", odd = "ODD JOB" }
ns.POSTER_KIND_LABELS = KIND_LABELS
function ns.PosterCatalogue(bracket)
    local out = {}
    for _, kind in ipairs({ "hunt", "clan", "wanted", "odd" }) do
        out[#out + 1] = { kind = kind, label = KIND_LABELS[kind], ids = Pool(kind, bracket) }
    end
    return out
end`],
[`        ns.Print(("  %s %s [%s] %d/%d"):format(p.claimed and "|cff40ff40done|r" or "-", p.bounty.name, p.tier, p.have, p.goal))`,
`        ns.Print(("  %s %s [%s] %d/%d"):format(p.claimed and "|cff40ff40done|r" or "-", p.bounty.name, p.bounty.kind or p.tier, p.have, p.goal))`],
[`-- Non-kill posters: "pvp" with the victim { race } if known, "dungeon" (a guild-group boss), "wanted" with the
-- dungeon cleared (its key).`,
`-- Non-kill posters: "pvp" with the victim { race } if known, "dungeon" (a guild-group boss), "wanted" with the
-- dungeon cleared (its key), "gather" and "fish" (LifeStats.lua).`]]);
edit("HuntsBoard.lua", [[
`local TIER_COLORS = { easy = { 0.22, 0.5, 0.2 }, medium = { 0.16, 0.38, 0.66 }, hard = { 0.55, 0.2, 0.72 } }`,
`-- Each kind of poster its colour (the engraving's shade and its headline's ink): hunt green, clan blue, wanted red,
-- odd job purple.
local KIND_COLORS = { hunt = { 0.22, 0.5, 0.2 }, clan = { 0.16, 0.38, 0.66 }, wanted = { 0.62, 0.12, 0.1 }, odd = { 0.5, 0.2, 0.66 } }`],
[`    local c = TIER_COLORS[p.tier] or TIER_COLORS.medium
    f.shade:SetColorTexture(c[1], c[2], c[3], 0.25)
    f.shade:SetShown(not f.picture)  -- (the tier's colour only where an engraving goes)
    -- (WANTED or BOUNTY; an officer's own poster, its own headline)
    local tagline = p.bounty.tagline
    f.tag:SetText(tagline or (wanted and "WANTED" or "BOUNTY"))
    f.tag:SetTextColor(unpack((wanted or tagline) and RED or INK_DIM))`,
`    local kind = p.bounty.kind or "hunt"
    local c = KIND_COLORS[kind] or KIND_COLORS.hunt
    f.shade:SetColorTexture(c[1], c[2], c[3], 0.25)
    f.shade:SetShown(not f.picture)  -- (the kind's colour only where an engraving goes)
    -- (its kind: HUNT, CLAN, WANTED or ODD JOB, in its colour; an officer's own poster, its own headline)
    local tagline = p.bounty.tagline
    f.tag:SetText(tagline or (ns.POSTER_KIND_LABELS and ns.POSTER_KIND_LABELS[kind]) or "BOUNTY")
    if tagline or wanted then f.tag:SetTextColor(unpack(RED)) else f.tag:SetTextColor(c[1], c[2], c[3]) end`],
[`-- The catalogue menu for a pick: the rotation, then each tier's posters (for a bracket, or for everyone).`,
`-- The catalogue menu for a pick: the rotation, then each kind's posters (for a bracket, or for everyone).`],
[`            local sub = root:CreateButton(group.tier:upper())`, `            local sub = root:CreateButton(group.label)`],
[`-- opens the catalogue for it (the rotation, or a bounty by tier).`, `-- opens the catalogue for it (the rotation, or a bounty by kind).`]]);
console.log("done");
