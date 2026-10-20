-- The weekly bounty posters: 3 to 5 bounties on the guild's board each week, like weekly quests: everyone can do every
-- one of them, each with their own progress and goal. They come in level brackets (BRACKETS): your character's level
-- the first time you meet the week's board (a kill, opening it) picks your bracket, and you keep it all week. The guild
-- master and officers pick next week's on the Bounty Board, a slot for everyone or one per bracket; what they leave
-- open is filled by the rotation (from the guild name, the week and the bracket, so every member's addon agrees without
-- talking), with a mix of easy, medium and hard that fits the bracket's levels.
-- Picks are kept with the guild settings (Config.lua): KillTrackerConfig[guild].bounties[week] = slots joined by "+":
-- "id.goal" (everyone; .goal = the officer's own personal goal), "1:id/3:id.goal" (by bracket; the brackets not named:
-- the rotation's) or "auto" (the rotation's); and an optional "T-Pirate-Hunting-Week" part, the week's theme title.
-- A poster is a bounty (Guild.lua's catalogue, or a custom one) or a wanted poster ("wanted_<dungeon key>": its end
-- boss, smashed, once).
-- Officers' own posters (extras): nailed up on this week's board wherever they like, for everyone, until the reset or
-- their own timer, or till as many guildmates as its limit have claimed it (0: no limit; as far as each addon has heard,
-- so a close race can let one or two more in); parts "X-tag.id.goal.x.y.ends.name.text.top.limit.picture[.loud]" of the week's
-- picks (picture: its own ogre, the layers' option ids in Minting.lua's order joined by "/", or none: the bounty's;
-- then ".1" if its story is loud: big and red like a wanted poster's SMASH, left off when it isn't);
-- (tag: when it was made, base 36; x, y: its nail on the board, 0-1000; ends: server time, 0 = the reset; its name,
-- story and headline, the word over its picture in place of BOUNTY, in hex). Each
-- counts and is claimed as "X<tag>_<id>", apart from a weekly poster on the same bounty.

local _, ns = ...

-- The level brackets (under 10: the first).
local BRACKETS = { { 10, 19 }, { 20, 29 }, { 30, 39 }, { 40, 49 }, { 50, 59 }, { 60, 60 } }
ns.POSTER_BRACKETS = BRACKETS
function ns.BracketForLevel(level)
    for i, b in ipairs(BRACKETS) do
        if (level or 1) <= b[2] then return i end
    end
    return #BRACKETS
end
function ns.BracketName(i)
    local b = BRACKETS[i]
    return b and (b[1] == b[2] and tostring(b[1]) or ("%d-%d"):format(b[1], b[2])) or "?"
end

-- The tier and personal goal of each catalogue bounty (its guild goal is for the old single bounty).
local TIERS = {
    Murloc = { "easy", 40 }, Troll = { "easy", 40 }, Spider = { "easy", 40 }, Wolf = { "easy", 40 }, Human = { "easy", 40 },
    Orc = { "easy", 40 }, Dwarf = { "easy", 40 }, Cat = { "easy", 40 }, Scorpid = { "easy", 40 }, Raptor = { "easy", 40 },
    defias = { "medium", 40 }, venture = { "medium", 40 }, kolkar = { "medium", 35 }, burningblade = { "medium", 25 },
    syndicate = { "medium", 35 }, scarlet = { "medium", 50 }, bloodsail = { "medium", 25 }, darkiron = { "medium", 60 },
    blackrock = { "medium", 50 }, scourge = { "medium", 75 },
    undead = { "medium", 60 }, demon = { "medium", 25 }, elemental = { "medium", 40 }, dragonkin = { "medium", 15 },
    elites = { "hard", 25 }, rares = { "hard", 2 }, leaders = { "hard", 3 }, dungeons = { "hard", 8 }, pvp = { "hard", 15 },
    explorers = { "hard", 10 },
}
local CUSTOM_TIERS = { kind = { "easy", 40 }, tribe = { "medium", 25 }, pvp = { "hard", 15 } }
-- The levels a bounty is for (the rotation puts it only in the brackets they touch); none: every level.
local LEVELS = {
    defias = { 10, 25 }, venture = { 10, 40 }, kolkar = { 10, 35 }, burningblade = { 10, 40 }, syndicate = { 20, 40 },
    scarlet = { 30, 60 }, bloodsail = { 40, 48 }, darkiron = { 45, 60 }, blackrock = { 20, 60 }, scourge = { 35, 60 },
    demon = { 20, 60 },
    -- The dungeons' wanted posters (wanted_<key>), by the dungeon's levels.
    rfc = { 13, 18 }, thanes = { 13, 18 }, wc = { 17, 24 }, dm = { 17, 26 }, ruins = { 18, 25 }, sfk = { 22, 30 },
    bfd = { 24, 32 }, stocks = { 24, 32 }, excav = { 26, 31 }, gnomer = { 29, 38 }, rfk = { 30, 40 }, smgy = { 28, 38 },
    smlib = { 29, 39 }, smarm = { 32, 42 }, smcath = { 35, 45 }, rfd = { 40, 50 }, ulda = { 42, 52 }, zf = { 44, 54 },
    mara = { 46, 55 }, st = { 50, 60 }, brd = { 52, 60 }, lbrs = { 55, 60 }, ubrs = { 58, 60 }, dme = { 55, 60 },
    dmw = { 57, 60 }, dmn = { 57, 60 }, scholo = { 58, 60 }, stratl = { 58, 60 }, stratu = { 58, 60 },
    ony = { 60, 60 }, barrow = { 60, 60 }, hyjal = { 60, 60 },
}
ns.DUNGEON_LEVELS = LEVELS  -- (a plinko chest's dungeon, at your level: Plinko.lua)
-- The boss on each dungeon's wanted poster: the one whose kill clears it (Guild.lua's final bosses).
local WANTED = {
    rfc = "Bazzalan", wc = "Mutanus the Devourer", dm = "Edwin VanCleef", sfk = "Archmage Arugal", bfd = "Aku'mai",
    stocks = "Bazil Thredd", gnomer = "Mekgineer Thermaplugg", rfk = "Charlga Razorflank", smgy = "Bloodmage Thalnos",
    smlib = "Arcanist Doan", smarm = "Herod", smcath = "High Inquisitor Whitemane", rfd = "Amnennar the Coldbringer",
    ulda = "Archaedas", zf = "Chief Ukorz Sandscalp", mara = "Princess Theradras", st = "Shade of Eranikus",
    brd = "Emperor Dagran Thaurissan", lbrs = "Overlord Wyrmthalak", ubrs = "General Drakkisath",
    dme = "Alzzin the Wildshaper", dmw = "Prince Tortheldrin", dmn = "King Gordok", scholo = "Darkmaster Gandling",
    stratl = "Balnazzar", stratu = "Baron Rivendare", thanes = "Durgen Dirgehammer", ruins = "Rath'mael",
    excav = "Relic Guardian", ony = "Onyxia", barrow = "Sonya Darkhallow", hyjal = "The Wild King",
}
ns.WANTED_BOSSES = WANTED
-- Their short names, on the board's small posters (read, the full one).
local WANTED_SHORT = {
    wc = "Mutanus", dm = "VanCleef", sfk = "Arugal", gnomer = "Thermaplugg", rfk = "Charlga", smgy = "Thalnos",
    smlib = "Doan", smcath = "Whitemane", rfd = "Amnennar", zf = "Ukorz", mara = "Theradras", st = "Eranikus",
    brd = "Thaurissan", lbrs = "Wyrmthalak", ubrs = "Drakkisath", dme = "Alzzin", dmw = "Tortheldrin", dmn = "Gordok",
    scholo = "Gandling", stratu = "Rivendare", thanes = "Durgen", barrow = "Sonya", hyjal = "Wild King",
}
-- A wanted poster's picture: an ogre (the same plain one on each) in the dungeon's gear set, its outfit and helm, as a
-- mint's traits; HELD adds by hand what the boss is known for (only what that boss drops: a headwear piece takes the
-- helm's place).
local WANTED_OGRE = { skin = "moss", eyes = "heavy_bags", expression = "smug_smile" }
local HELD = {
    dm = { accessory = "chase_dm_cruel_barb" },
    sfk = { accessory = "chase_sfk_meteor_shard" },
    smlib = { accessory = "chase_smlib_illusionary_rod" },
    smarm = { accessory = "chase_smarm_ravager" },
    mara = { accessory = "chase_mara_blade_of_eternal_darkness" },
    brd = { accessory = "chase_brd_ironfoe" },
    ubrs = { accessory = "chase_ubrs_draconian_deflector" },
    scholo = { accessory = "chase_scholo_headmasters_charge" },
    stratu = { accessory = "chase_stratu_runeblade_of_baron_rivendare" },
    thanes = { accessory = "chase_thanes_crescent_axe" },
    ruins = { accessory = "chase_ruins_mirror_of_rathmael" },
    excav = { accessory = "chase_excav_golemsight_long_gun" },
    ony = { accessory = "chase_ony_deathbringer" },
    rfd = { headwear = "chase_rfd_icemetal_barbute" },
    dmn = { headwear = "chase_dmn_crown_of_the_ogre_king" },
    gnomer = { headwear = "chase_gnomer_gigaflux_reactivator" },
    smcath = { headwear = "chase_smcath_whitemanes_chapeau" },  -- (the Chapeau has Whitemane's hair under it)
}
-- A dungeon shown as an ogre in its set (its hat and outfit) with the wanted posters' plain face: what stands for the
-- dungeon now that its crayon backdrop and boss skin are retired (a gifted chest in the feed). Traits, or nil.
function ns.DungeonOgre(key)
    if not key then return end
    local traits = { outfit = "gear_" .. key .. "_body", headwear = "gear_" .. key .. "_head" }
    for layer, option in pairs(WANTED_OGRE) do traits[layer] = option end
    return traits
end
function ns.WantedPicture(id)
    local key = id and id:match("^wanted_(%w+)$")
    if not key or not WANTED[key] then return end
    local traits = { outfit = "gear_" .. key .. "_body", headwear = "gear_" .. key .. "_head" }
    for layer, option in pairs(WANTED_OGRE) do traits[layer] = option end
    for layer, option in pairs(HELD[key] or {}) do traits[layer] = option end
    return traits
end
-- The rotation's mix for each board size: the tier of each slot.
local MIX = {
    [3] = { "easy", "medium", "hard" },
    [4] = { "easy", "easy", "medium", "hard" },
    [5] = { "easy", "easy", "medium", "medium", "hard" },
}
local AUTO = "auto"

-- A poster's bounty by its id: a wanted poster, or a bounty with its tier, personal goal and levels added (the bounty
-- tables are Guild.lua's, shared; the poster keeps its own fields). nil if unknown.
local posters = {}
local function PosterBounty(id)
    if not id or id == AUTO then return end
    if posters[id] then return posters[id] end
    local base = id:match("^X%w+_(.+)$")  -- (an officer's own poster: its bounty)
    if base then return PosterBounty(base) end
    local poster
    local key = id:match("^wanted_(%w+)$")
    if key then
        local d = ns.DungeonByKey and ns.DungeonByKey(key)
        if not d or not WANTED[key] then return end
        poster = { id = id, name = "Wanted: " .. WANTED[key], event = "wanted", dungeon = key, tier = "hard", solo = 1,
            wanted = WANTED[key], short = WANTED_SHORT[key] or WANTED[key], levels = LEVELS[key], desc = d.name, objective = "SMASH" }
    else
        local bounty = ns.ResolveBounty and ns.ResolveBounty(id)
        if not bounty then return end
        local tier = TIERS[id] or (bounty.custom and CUSTOM_TIERS[id:match("^(%a+)_")]) or { "medium", 25 }
        poster = setmetatable({ tier = tier[1], solo = tier[2], levels = LEVELS[id] }, { __index = bounty })
    end
    posters[id] = poster
    return poster
end
ns.PosterBounty = PosterBounty

-- Whether a poster fits a bracket's levels.
local function Fits(poster, bracket)
    local l, b = poster.levels, BRACKETS[bracket]
    return not l or not b or (l[1] <= b[2] and l[2] >= b[1])
end

-- A poster's personal goal: the officer's own, else its usual one scaled by the guild's "Goal size %" and, a bracket at
-- a time, its "Goal % more per level bracket" (a wanted poster is always one kill).
function ns.PosterGoal(poster, goal, bracket)
    if goal then return goal end
    if poster.wanted then return 1 end
    local scale = 1 + (ns.Config("bountyLevelScale") or 0) / 100 * ((bracket or 1) - 1)
    return math.max(1, math.floor(poster.solo * ns.Config("bountyGoalPercent") / 100 * scale + 0.5))
end

-- An ogre picture (a mint's traits) as its layers' option ids joined by "/" (Minting.lua's layer order) and back; none: "".
function ns.PictureKey(traits)
    if not traits then return "" end
    local parts, any = {}, false
    for i, layer in ipairs(ns.MintLayers or {}) do
        parts[i] = traits[layer.key] or ""
        if traits[layer.key] then any = true end
    end
    return any and table.concat(parts, "/") or ""
end
function ns.PictureFromKey(key)
    if not key or not key:find("/", 1, true) then return end
    local traits, i, any = {}, 0, false
    for id in (key .. "/"):gmatch("([%w_]*)/") do
        i = i + 1
        local layer = ns.MintLayers and ns.MintLayers[i]
        if layer and id ~= "" then traits[layer.key], any = id, true end
    end
    return any and traits or nil
end

-- Text as hex (the picks only carry letters, digits and a few marks) and back.
local function Hex(text) return ((text or ""):gsub(".", function(c) return ("%02x"):format(c:byte()) end)) end
local function Unhex(hex) return ((hex or ""):gsub("%x%x", function(h) return string.char(tonumber(h, 16)) end)) end
local function Base36(n)
    local digits, out = "0123456789abcdefghijklmnopqrstuvwxyz", ""
    repeat local d = n % 36 out = digits:sub(d + 1, d + 1) .. out n = math.floor(n / 36) until n == 0
    return out
end
-- An officer's own poster from its part: { tag, id, goal, x, y, ends, headline (its name), text, top (its headline) }.
local function ParseExtra(part)
    local tag, id, goal, x, y, ends, head, text, top, limit, picture, loud = part:match("^X%-(%w+)%.([%w_]+)%.(%d*)%.(%d+)%.(%d+)%.(%d+)%.(%x*)%.(%x*)%.?(%x*)%.?(%d*)%.?([%w_/]*)%.?(%d?)$")
    if not tag or not PosterBounty(id) then return end
    return { tag = tag, id = id, goal = tonumber(goal), x = tonumber(x), y = tonumber(y), ends = tonumber(ends),
        headline = head ~= "" and Unhex(head) or nil, text = text ~= "" and Unhex(text) or nil, top = top ~= "" and Unhex(top) or nil,
        limit = tonumber(limit) or 0, picture = ns.PictureFromKey(picture), loud = loud == "1" }
end
local function ExtraPart(e)
    return ("X-%s.%s.%s.%d.%d.%d.%s.%s.%s.%d.%s"):format(e.tag, e.id, e.goal and tostring(math.floor(e.goal)) or "",
        math.floor(e.x), math.floor(e.y), math.floor(e.ends or 0), Hex(e.headline), Hex(e.text), Hex(e.top),
        math.floor(e.limit or 0), ns.PictureKey(e.picture)) .. (e.loud and ".1" or "")
end

-- The officers' picks for a week: { title, [slot] = { all = { id, goal } } or { byBracket = { [i] = { id, goal } } }
-- or false (the rotation's) }.
local function Pick(text)
    local id, goal = (text or ""):match("^([%w_]+)%.?(%d*)$")
    return (id and id ~= AUTO and PosterBounty(id)) and { id = id, goal = tonumber(goal) } or nil
end
local function Picks(week)
    local picks = { extras = {} }
    local text = ns.GetBountyPicks and ns.GetBountyPicks(week)
    if not text or not text:find("+", 1, true) then return picks end
    local slot = 0
    for part in text:gmatch("[^+]+") do
        if part:find("^T%-") then
            picks.title = part:sub(3):gsub("%-", " ")
        elseif part:find("^X%-") then
            local extra = ParseExtra(part)
            if extra then picks.extras[#picks.extras + 1] = extra end
        else
            slot = slot + 1
            if part:find(":", 1, true) then
                local byBracket = {}
                for i, spec in part:gmatch("(%d+):([^/]+)") do byBracket[tonumber(i)] = Pick(spec) end
                picks[slot] = { byBracket = byBracket }
            else
                local all = Pick(part)
                picks[slot] = all and { all = all } or false
            end
        end
    end
    return picks
end
-- A slot's pick for a bracket: { id, goal } or nil (the rotation's).
local function PickFor(slotPick, bracket)
    if not slotPick then return end
    return slotPick.all or (slotPick.byBracket and slotPick.byBracket[bracket])
end

local function Hash(text)
    local h = 5381
    for i = 1, #text do h = (h * 33 + text:byte(i)) % 2147483647 end
    return h
end

-- The rotation's pool for a tier and bracket: catalogue bounties, and for hard also the dungeons' wanted posters, that
-- fit the bracket's levels.
local pools = {}
local function Pool(tier, bracket)
    local key = tier .. ":" .. tostring(bracket)
    if pools[key] then return pools[key] end
    local pool = {}
    for _, bounty in ipairs(ns.BOUNTIES or {}) do
        local poster = TIERS[bounty.id] and TIERS[bounty.id][1] == tier and PosterBounty(bounty.id)
        if poster and Fits(poster, bracket) then pool[#pool + 1] = bounty.id end
    end
    if tier == "hard" then
        for _, d in ipairs(ns.Dungeons and ns.Dungeons() or {}) do
            local poster = WANTED[d.key] and not d.raid and PosterBounty("wanted_" .. d.key)
            if poster and Fits(poster, bracket) then pool[#pool + 1] = poster.id end
        end
    end
    pools[key] = pool
    return pool
end

-- The rotation's poster for a slot: from its tier's pool for the bracket, by the guild, week, slot and bracket, never one
-- already on the board.
local function RotationPick(guild, week, slot, tier, bracket, taken)
    local pool = Pool(tier, bracket)
    if #pool == 0 then return end
    local h = Hash(("%s:%d:%d:%d"):format(guild, week, slot, bracket))
    for _ = 1, 3 do h = (h * 1103515245 + 12345) % 2147483648 end  -- (stirred: the next week is a different board)
    local start = math.floor(h / 65536) % #pool
    for i = 0, #pool - 1 do
        local id = pool[(start + i) % #pool + 1]
        if not taken[id] then return id end
    end
end

-- How many guildmates (you too) have claimed a poster this week, as far as we've heard (key: its id on the board).
function ns.PosterClaimCount(key, week)
    week = week or ns.CurrentWeek()
    local n = 0
    local mine = KillTrackerDB and KillTrackerDB.posters
    if mine and mine.week == week and mine.claimed and mine.claimed[key] then n = n + 1 end
    for _, friend in ipairs(ns.GetFriends and ns.GetFriends() or {}) do
        local theirs = friend.stats and friend.stats.posters
        if theirs and theirs.week == week and theirs.claimed and theirs.claimed[key] then n = n + 1 end
    end
    return n
end

-- The board for a bracket (default: your level's) weeksAhead weeks from now (0 = this week): { week, bracket, title,
-- resetsIn = seconds until this week ends, posters = { { slot, id, bounty, tier, goal, picked = true if an officer
-- chose it } } }, or nil outside a guild.
function ns.GetPosters(weeksAhead, bracket)
    local guild = IsInGuild() and GetGuildInfo("player")
    if not guild or (issecretvalue and issecretvalue(guild)) then return end
    bracket = bracket or ns.BracketForLevel(UnitLevel("player"))
    local week, resetsIn = ns.CurrentWeek()
    week = week + 7 * (weeksAhead or 0)
    local picks = Picks(week)
    local count = math.max(3, math.min(5, ns.Config("bountyPosters")))
    local mix = MIX[count]
    local board, taken = { week = week, bracket = bracket, resetsIn = resetsIn, title = picks.title, posters = {} }, {}
    for slot = 1, count do
        local pick = PickFor(picks[slot], bracket)
        if pick then taken[pick.id] = true end
    end
    for slot = 1, count do
        local pick = PickFor(picks[slot], bracket)
        local id = pick and pick.id or RotationPick(guild, week, slot, mix[slot], bracket, taken)
        local poster = id and PosterBounty(id)
        if poster then
            taken[id] = true
            board.posters[#board.posters + 1] = { slot = slot, id = id, bounty = poster, tier = poster.tier,
                goal = ns.PosterGoal(poster, pick and pick.goal, bracket), picked = pick and true or false }
        end
    end
    -- The officers' own posters, while they're up: their headline and text over the bounty's.
    local now = GetServerTime()
    for _, e in ipairs(picks.extras) do
        local base = PosterBounty(e.id)
        local key = "X" .. e.tag .. "_" .. e.id
        local claims = e.limit > 0 and ns.PosterClaimCount(key, week) or 0
        if base and (e.ends == 0 or e.ends > now) and (e.limit == 0 or claims < e.limit) then
            local poster = setmetatable({ name = e.headline or base.name, short = e.headline or base.short,
                desc = e.text or base.desc, tagline = e.top }, { __index = base })
            if e.loud then poster.desc, poster.objective = false, e.text end  -- (its story big and red, in SMASH's place)
            board.posters[#board.posters + 1] = { slot = "extra", id = key, bounty = poster, tier = base.tier,
                goal = ns.PosterGoal(base, e.goal, bracket), picked = true, extra = e, claims = claims }
        end
    end
    return board
end

-- Officers: picks a week's posters and sends them to the guild. list = { [slot] = { id, goal } (everyone), or
-- { byBracket = { [i] = { id, goal } } }, or false (the rotation's) }; title = the week's theme or nil. Nothing picked
-- and no title: back to the rotation.
function ns.SetPosters(week, list, title)
    local count = math.max(3, math.min(5, ns.Config("bountyPosters")))
    local function Spec(pick) return pick.goal and (pick.id .. "." .. math.floor(pick.goal)) or pick.id end
    local parts, any = {}, false
    for slot = 1, count do
        local pick = list[slot]
        parts[slot] = AUTO
        if pick and pick.byBracket then
            local specs = {}
            for i = 1, #BRACKETS do
                local p = pick.byBracket[i]
                if p and PosterBounty(p.id) then specs[#specs + 1] = i .. ":" .. Spec(p) end
            end
            if #specs > 0 then parts[slot], any = table.concat(specs, "/"), true end
        elseif pick and PosterBounty(pick.id) then
            parts[slot], any = Spec(pick), true
        end
    end
    title = title and title:gsub("[^%w ]", ""):gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", "-")
    if title and title ~= "" then parts[#parts + 1] = "T-" .. title any = true end
    for _, e in ipairs(Picks(week).extras) do parts[#parts + 1] = ExtraPart(e) any = true end  -- (kept as they are)
    return ns.SetBountyPicks and ns.SetBountyPicks(week, any and table.concat(parts, "+") or nil)
end

-- Officers: this week's own posters (extras = { { tag, id, goal, x, y, ends, headline, text } }, the ones that came
-- down left out), sent to the guild with the rest of the week's picks.
local function SetExtras(extras)
    local week = ns.CurrentWeek()
    local text = ns.GetBountyPicks and ns.GetBountyPicks(week)
    local parts = {}
    if text and text:find("+", 1, true) then
        for part in text:gmatch("[^+]+") do if not part:find("^X%-") then parts[#parts + 1] = part end end
    else
        for _ = 1, math.max(3, math.min(5, ns.Config("bountyPosters"))) do parts[#parts + 1] = AUTO end
    end
    local now = GetServerTime()
    for _, e in ipairs(extras) do
        if e.ends == 0 or e.ends > now then parts[#parts + 1] = ExtraPart(e) end
    end
    return ns.SetBountyPicks and ns.SetBountyPicks(week, table.concat(parts, "+"))
end
function ns.PosterExtras() return Picks(ns.CurrentWeek()).extras end
-- A new one: { id, goal, x, y, headline (its name), text, top (its headline, 8 letters), hours (nil: until the reset),
-- limit (claims till it comes down; nil: none), picture (its own ogre: a mint's traits; nil: the bounty's) }.
function ns.AddPosterExtra(e)
    local extras = ns.PosterExtras()
    local _, resetsIn = ns.CurrentWeek()
    local now = GetServerTime()
    local ends = (e.hours and e.hours * 3600 < resetsIn) and (now + e.hours * 3600) or 0
    local headline = e.headline and e.headline:gsub("^%s+", ""):gsub("%s+$", "") or ""
    local text = e.text and e.text:gsub("^%s+", ""):gsub("%s+$", "") or ""
    local top = e.top and e.top:gsub("^%s+", ""):gsub("%s+$", ""):upper() or ""
    extras[#extras + 1] = { tag = Base36(now), id = e.id, goal = e.goal, x = e.x, y = e.y,
        ends = ends, headline = headline ~= "" and headline:sub(1, 32) or nil, text = text ~= "" and text:sub(1, 160) or nil,
        top = top ~= "" and top:sub(1, 8) or nil, limit = math.max(0, math.floor(e.limit or 0)),
        picture = e.picture, loud = e.loud and text ~= "" or nil }
    return SetExtras(extras)
end
function ns.MovePosterExtra(tag, x, y)
    local extras = ns.PosterExtras()
    for _, e in ipairs(extras) do if e.tag == tag then e.x, e.y = x, y end end
    return SetExtras(extras)
end
function ns.RemovePosterExtra(tag)
    local kept = {}
    for _, e in ipairs(ns.PosterExtras()) do if e.tag ~= tag then kept[#kept + 1] = e end end
    return SetExtras(kept)
end

-- What could go on a poster for a bracket, for the officers' picker: { { tier, ids } } (catalogue, then wanted posters).
function ns.PosterCatalogue(bracket)
    local out = {}
    for _, tier in ipairs({ "easy", "medium", "hard" }) do out[#out + 1] = { tier = tier, ids = Pool(tier, bracket) } end
    return out
end

-- Progress and claims ------------------------------------------------------------------------------------------------
-- KillTrackerDB.posters = { week, progress = { [id] = n }, claimed = { [id] = time } }: yours, fresh each week. A kill
-- counts for every poster it fits (a Defias can be a Human too): they overlap, and that's the game. A poster is claimed
-- the moment its goal is reached: points by its tier (the guild's "Reward" setting times TIER_REWARD) and a bounty
-- chest (KillTrackerDB.bountyChests, opened on the board).
local TIER_REWARD = { easy = 0.25, medium = 0.5, hard = 1 }

-- (bracket: locked the first time the week is met, from your level then)
local function Mine(week)
    local db = KillTrackerDB
    if not db.posters or db.posters.week ~= week then
        db.posters = { week = week, bracket = ns.BracketForLevel(UnitLevel("player")), progress = {}, claimed = {} }
    end
    db.posters.bracket = db.posters.bracket or ns.BracketForLevel(UnitLevel("player"))
    return db.posters
end
-- This week's board in your locked bracket, and your record.
local function MyBoard()
    if not ns.GetPosters(0) then return end
    local mine = Mine((ns.CurrentWeek()))
    return ns.GetPosters(0, mine.bracket), mine
end
ns.MyPosterBoard = MyBoard

-- This week's board with your progress: GetPosters(0), each poster also { have, claimed }.
function ns.GetPosterProgress()
    local board, mine = MyBoard()
    if not board then return end
    for _, p in ipairs(board.posters) do
        p.have, p.claimed = math.min(mine.progress[p.id] or 0, p.goal), mine.claimed[p.id]
    end
    return board
end

local function Claim(board, p, mine)
    mine.claimed[p.id] = time()
    local reward = math.floor(ns.Config("bountyReward") * (TIER_REWARD[p.tier] or 0.5) + 0.5)
    local points = KillTrackerDB.points
    points.bounty = (points.bounty or 0) + reward
    ns.Touch(points)
    KillTrackerDB.bountyChests = (KillTrackerDB.bountyChests or 0) + 1
    ns.AddEvent("P", p.id)
    ns.ShowToast("achievement", "Bounty claimed!", p.bounty.name, ("+%d points and a bounty chest"):format(reward))
    ns.Touch(mine)
    if ns.CheckPosterMilestones then ns.CheckPosterMilestones() end
    if ns.OnKillsChanged then ns.OnKillsChanged() end
    if ns.RefreshHuntsBoard then ns.RefreshHuntsBoard() end
end

-- One more towards each of this week's posters that test(poster) says it fits; claims the ones that are done.
local function CountWhere(test)
    local board, mine = MyBoard()
    if not board then return end
    local changed = false
    for _, p in ipairs(board.posters) do
        if not mine.claimed[p.id] and test(p.bounty) then
            mine.progress[p.id] = (mine.progress[p.id] or 0) + 1
            changed = true
            if mine.progress[p.id] >= p.goal then Claim(board, p, mine) end
        end
    end
    if changed then ns.Touch(mine) end
end

table.insert(ns.KillHandlers, function(npcID, entry, c)
    CountWhere(function(bounty) return bounty.count and bounty.count(npcID, entry, c) end)
end)

-- Non-kill posters: "pvp" with the victim { race } if known, "dungeon" (a guild-group boss), "wanted" with the
-- dungeon cleared (its key).
function ns.OnPosterEvent(event, arg)
    CountWhere(function(bounty)
        if bounty.event ~= event then return false end
        if event == "wanted" then return bounty.dungeon == arg end
        if bounty.race then return arg ~= nil and arg.race == bounty.race end
        return true
    end)
end

function ns.PrintPosters()
    local board = ns.GetPosterProgress()
    if not board then
        ns.Print("Bounty posters are for guilds; join one to take part.")
        return
    end
    ns.Print(("This week's bounties, levels %s (reset in %s):"):format(ns.BracketName(board.bracket), ns.BountyTimeLeft and ns.BountyTimeLeft(board.resetsIn) or "?"))
    for _, p in ipairs(board.posters) do
        ns.Print(("  %s %s [%s] %d/%d"):format(p.claimed and "|cff40ff40done|r" or "-", p.bounty.name, p.tier, p.have, p.goal))
    end
end

-- The guild counter ----------------------------------------------------------------------------------------------------
-- Every claim in the guild this week (yours and your guildmates', through sync) counts. At each milestone (MILESTONES,
-- scaled by the guild's "Goal size %") its reward is added to a pile that stacks; everyone who has claimed at least one
-- poster this week gets each milestone's reward once (KillTrackerDB.posters.milestones = { [i] = true }), including the
-- ones reached before their first claim. The last milestone's is the guild bounty chest
-- (KillTrackerDB.guildBountyChests, opened on the board).
local MILESTONES = {
    { claims = 5, points = 25 },
    { claims = 10, points = 50, fuel = "frostwood" },
    { claims = 20, points = 100, fuel = "shimmer" },
    { claims = 35, points = 150, guildChest = true },
}
ns.POSTER_MILESTONES = MILESTONES

function ns.MilestoneClaims(m)
    return math.max(1, math.floor(m.claims * ns.Config("bountyGoalPercent") / 100 + 0.5))
end

-- This week's guild claims: { total, members = { { name, count, ids } }, reached = how many milestones }.
function ns.GetGuildClaims()
    local board, mine = MyBoard()
    if not board then return end
    local out = { total = 0, members = {}, reached = 0 }
    local function Add(name, claimed)
        local ids = {}
        for id in pairs(claimed or {}) do ids[#ids + 1] = id end
        if #ids == 0 then return end
        out.total = out.total + #ids
        out.members[#out.members + 1] = { name = name, count = #ids, ids = ids }
    end
    Add(ns.MyName(), mine.claimed)
    for _, friend in ipairs(ns.GetFriends and ns.GetFriends() or {}) do
        local theirs = friend.stats.posters
        if theirs and theirs.week == board.week then Add(friend.name, theirs.claimed) end
    end
    table.sort(out.members, function(a, b) return a.count > b.count end)
    for i, m in ipairs(MILESTONES) do
        if out.total >= ns.MilestoneClaims(m) then out.reached = i end
    end
    return out
end

-- Pays you the milestones the guild has reached that you haven't had yet, if you've claimed a poster this week.
function ns.CheckPosterMilestones()
    local guild = ns.GetGuildClaims()
    if not guild or guild.reached == 0 then return end
    local _, mine = MyBoard()
    if not mine or not next(mine.claimed) then return end
    mine.milestones = mine.milestones or {}
    for i = 1, guild.reached do
        if not mine.milestones[i] then
            mine.milestones[i] = true
            local m = MILESTONES[i]
            local points = KillTrackerDB.points
            points.bounty = (points.bounty or 0) + m.points
            ns.Touch(points)
            if m.fuel and ns.AddIngredient then ns.AddIngredient(m.fuel, 1, true) end
            if m.guildChest then KillTrackerDB.guildBountyChests = (KillTrackerDB.guildBountyChests or 0) + 1 end
            ns.ShowToast("achievement", "Guild bounties: " .. ns.MilestoneClaims(m) .. " claimed!",
                m.guildChest and "The guild bounty chest!" or "Everyone who claimed gets a reward",
                ("+%d points%s"):format(m.points, m.fuel and (" and " .. (ns.IngredientName and ns.IngredientName(m.fuel) or m.fuel)) or ""))
        end
    end
    ns.Touch(mine)
    if ns.OnKillsChanged then ns.OnKillsChanged() end
end

-- The officers' picks for a week as the board's officer view edits them: { title, [slot] = { all = { id, goal } } or
-- { byBracket = { [i] = { id, goal } } } or false }.
function ns.GetPosterPicks(week) return Picks(week) end
