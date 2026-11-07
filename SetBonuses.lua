-- Set bonuses: what your ogre wears (your Overview card's, KillTrackerDB.card.ogre) gives small perks in SOLC.
--   Creature and faction pieces: each one +25% kill points for that creature kind or faction; the whole set (hat,
--   clothes and its toy, all three) doubles them. Which kind or faction a piece belongs to comes from its own unlock
--   (a Murloc piece is unlocked by a Murloc deed: "deed:subtype:Murloc:100"; a Defias one by "deed:faction:...").
--   Fishing gear (FISHING_GEAR): each piece makes fishing chests 25% likelier (Unlocks.lua); the angler's whole outfit
--   (hat, waders, something fishy in hand, the pier behind) doubles the chance.
-- Only what the ogre wears now counts: outfits are saved and switched in EDIT (OverviewCard.lua, ns.WearOutfit).

local _, ns = ...

local PIECE, FULL = 0.25, 1  -- (each piece's part, and a whole set's in all: +100%, double)
local SET_SIZE = 3           -- (a creature's or faction's whole set: hat, clothes, toy)
local FISHING_GEAR = { hunt_angler_head = "head", hunt_angler_body = "body", bg_fishing_pier = "place",
    prop_landing_net = "held", prop_tackle_box = "held", prop_fishing_pipe = "held", prop_fish = "held",
    gacha_head_fishing_hat = "head", gacha_head_souwester = "head", gacha_acc_trophy_fish = "held",
    gacha_outfit_sailor_stripes = "body" }
local ANGLER = { "hunt_angler_head", "hunt_angler_body", "bg_fishing_pier" }  -- (the whole outfit: these and one held)
ns.FISHING_GEAR = FISHING_GEAR

-- What an ogre (traits: layer -> id; default: yours) wears, by set: { creatures = { [kind] = pieces },
-- factions = { [faction] = pieces }, fishing = pieces, angler = true if the whole angler outfit }. Kept per look.
local cache = setmetatable({}, { __mode = "k" })
local function Sets(traits)
    traits = traits or (KillTrackerDB and KillTrackerDB.card and KillTrackerDB.card.ogre) or {}
    local key = {}
    for layer, id in pairs(traits) do key[#key + 1] = layer .. "=" .. id end
    table.sort(key)
    key = table.concat(key, ",")
    if cache[traits] and cache[traits].key == key then return cache[traits].sets end
    local sets = { creatures = {}, factions = {}, fishing = 0, angler = false }
    local held = false
    for layer, id in pairs(traits) do
        local found = ns.OptionByKey and ns.OptionByKey(layer .. ":" .. id)
        local unlock = found and found.option.unlock or ""
        local kind = unlock:match("^deed:subtype:(.+):%d+$")
        local faction = unlock:match("^deed:faction:(.+):%d+$")
        if kind then sets.creatures[kind] = (sets.creatures[kind] or 0) + 1 end
        if faction then sets.factions[faction] = (sets.factions[faction] or 0) + 1 end
        if FISHING_GEAR[id] then
            sets.fishing = sets.fishing + 1
            if FISHING_GEAR[id] == "held" then held = true end
        end
    end
    local angler = held
    for _, id in ipairs(ANGLER) do
        local wearing = false
        for _, worn in pairs(traits) do if worn == id then wearing = true end end
        angler = angler and wearing
    end
    sets.angler = angler
    cache[traits] = { key = key, sets = sets }
    return sets
end
ns.WornSets = Sets

-- A set's multiplier for this many pieces: +25% each, the whole set double.
local function Multiplier(pieces, whole)
    if pieces <= 0 then return 1 end
    return 1 + (whole and FULL or PIECE * pieces)
end

-- Kill points for a kill (c: its Categorize result; Points.lua): your creature or faction set's multiplier for it, the
-- better of the two if both fit.
function ns.SetKillMultiplier(c)
    local sets = Sets()
    local kind, faction = sets.creatures[c and c.subtype or ""] or 0, sets.factions[c and c.faction or ""] or 0
    return math.max(Multiplier(kind, kind >= SET_SIZE), Multiplier(faction, faction >= SET_SIZE))
end

-- The fishing chest's chance multiplier (Unlocks.lua), and how many fishing pieces are worn.
function ns.FishingSetMultiplier(traits)
    local sets = Sets(traits)
    return Multiplier(sets.fishing, sets.angler), sets.fishing
end

-- For the Overview (your ogre's or a guildmate's) and the Collection: the sets worn, as lines.
function ns.SetBonusLines(traits)
    local sets, lines = Sets(traits), {}
    local function Line(name, pieces, what)
        local whole = pieces >= SET_SIZE
        lines[#lines + 1] = ("%s set %d/%d: %s"):format(name, math.min(pieces, SET_SIZE), SET_SIZE,
            whole and ("double " .. what) or ("+%d%% %s"):format(PIECE * pieces * 100, what))
    end
    for kind, pieces in pairs(sets.creatures) do Line(kind, pieces, kind .. " kill points") end
    for faction, pieces in pairs(sets.factions) do
        local name = ns.TribeName and ns.TribeName(faction) or faction
        Line(name, pieces, name .. " kill points")
    end
    if sets.fishing > 0 then
        lines[#lines + 1] = sets.angler and "Angler's outfit: fishing chests twice as likely"
            or ("Fishing gear (%d): fishing chests %d%% likelier"):format(sets.fishing, PIECE * sets.fishing * 100)
    end
    table.sort(lines)
    return lines
end

-- For a piece in the Collection: what it does worn, or nil.
function ns.PieceSetText(option)
    if not option then return end
    local unlock = option.unlock or ""
    local kind = unlock:match("^deed:subtype:(.+):%d+$")
    local faction = unlock:match("^deed:faction:(.+):%d+$")
    if kind then return ("Worn: +25%% %s kill points (the whole set of three: double)"):format(kind) end
    if faction then
        local name = ns.TribeName and ns.TribeName(faction) or faction
        return ("Worn: +25%% %s kill points (the whole set of three: double)"):format(name)
    end
    if FISHING_GEAR[option.id] then return "Worn: fishing chests 25% likelier (the angler's whole outfit: double)" end
end
