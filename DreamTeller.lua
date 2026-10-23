-- The Dream Bed's storyteller (the recipe: tools/dream/storyteller.js): a picture's traits told as the dream the ogre
-- had, in beats (one per layer: each paints its layer on the easel) and an ending. Its words: DreamStory.lua.
-- The tricks that make it lively:
--   - each piece plays a part: the background is where it happened and how he turns up there; skin, outfit, hat,
--     eyes and face describe him; the accessory is what he does, and its endings land the joke;
--   - a matching hat + outfit (a boss's set, a creature's hood and onesie, a faction's pair) is told as one costume;
--   - tags read off the pieces (fire, water, undead...; morning, night): the place's time picks the opener, some pairs
--     make the dream react ("The whole place hisses with steam.");
--   - blanks in the endings: {mobs} {boss} (the place's crowd), {hat} {outfit} (his clothes' short names), {me} {mate}
--     {n} {kill} (you: your name, guildmates, your most-killed creature), and recent dungeon buddies;
--   - legendary pieces get him excited; "that one AGAIN" for the skin dreamt last time.
-- ns.TellDream(traits, locked, ctx) -> { beats = { { k, pre, say, post } }, ending, set, reaction }
--   traits: { [layer key] = option id }; locked: the layer the bedtime story asked about (or nil);
--   ctx: { me, kills = { n, name }, mates = { names }, buddies = { { name, place } }, lastSkin } (all optional).
-- ns.DreamOgreSpeak(...) the same in ogre words, for ogre mode.

local _, ns = ...

local ORDER = { "background", "skin", "outfit", "headwear", "eyes", "expression", "accessory" }
ns.DREAM_ORDER = ORDER
local OGRE_LINES = { background = "ME AT %s.", skin = "%s OGRE COME.", outfit = "WEAR %s.", headwear = "HAT %s.", eyes = "EYES %s.",
    expression = "FACE %s.", accessory = "HOLD %s." }
local OGRE_ENDS = { "STAB ME!", "EAT ME HAT.", "BONK!", "SAY MRGL.", "TEETH GONE.", "FLOOR LAVA!", "IT ME!", "TAKE LOOT!" }

local BUDGET = 75  -- words: past this a dream drops its extras (TellDream)
local RANK = { uncommon = 1, rare = 2, epic = 3, legendary = 4 }
local TAG_ORDER = { "fire", "ice", "water", "undead", "holy", "fel", "nature", "arcane", "knitted", "metal", "shiny", "stone",
    "dragon", "beast", "pirate", "golf", "sleepy", "royal", "tech", "smelly", "tiny", "huge", "morning", "night" }
local function Pick(list) return list and #list > 0 and list[math.random(#list)] or nil end

local function Option(layerKey, id)
    for _, layer in ipairs(ns.MintLayers) do
        if layer.key == layerKey then
            for _, option in ipairs(layer.options) do
                if option.id == id then return option end
            end
        end
    end
end

-- A piece's short name for callbacks: the main noun ("Crown of Eternal Rest" -> crown).
local function Short(option)
    if not option then return "hat" end
    local D = ns.DreamStory
    if D.SHORT[option.id] then return D.SHORT[option.id] end
    local head = option.name:gsub(" of .*", ""):gsub(" with .*", ""):gsub(" and .*", ""):gsub("'s", "")
    return (head:match("(%S+)$") or head):lower()
end

-- The pieces' tags: { [tag] = the first piece that has it }. Hand-picked ones (D.PIECE_TAGS, by id) when the piece has
-- them; a piece not tagged yet falls back to keywords in its id and name (D.TAGS).
local function Tags(...)
    local D, tags = ns.DreamStory, {}
    for i = 1, select("#", ...) do
        local option = select(i, ...)
        if option then
            local picked = D.PIECE_TAGS and D.PIECE_TAGS[option.id]
            if picked then
                for _, tag in ipairs(picked) do tags[tag] = tags[tag] or option end
            else
                local text = (option.id .. " " .. option.name):lower()
                for tag, words in pairs(D.TAGS) do
                    for _, word in ipairs(words) do
                        if text:find(word, 1, true) then tags[tag] = tags[tag] or option break end
                    end
                end
            end
        end
    end
    return tags
end

-- A matching hat + outfit: { outfit, hat } lines for it, or nil.
local function MatchedSet(traits)
    local o, h = traits.outfit, traits.headwear
    if not o or not h then return nil end
    local kind, set = o:match("^(%a+)_(.+)_body$")
    local hatKind, hatSet = h:match("^(%a+)_(.+)_head$")
    if not kind or kind ~= hatKind or set ~= hatSet then return nil end
    local D = ns.DreamStory
    if kind == "gear" then
        local place = D.PLACE["bg_" .. set]
        local who = place and place.boss and place.boss[1] or "the boss"
        return { outfit = "dressed head to toe as " .. who, hat = who .. "'s own hat and everything. Like, EXACTLY like " .. who, boss = true }
    elseif kind == "crit" then
        local creature = D.SET_CREATURES and D.SET_CREATURES[set] or (set:gsub("_", " "))
        return { outfit = "in a full " .. creature .. " suit", hat = "the " .. creature .. " hood up, the lot. Proper " .. creature .. " behaviour" }
    end
    local who = D.SET_FACTIONS[set] or "someone else"
    return { outfit = "dressed exactly like " .. who, hat = "the full uniform, hat included. Very convincing" }
end

-- The blanks: the place's crowd, his clothes, you.
local function Fill(line, place, options, ctx)
    local mobs = place and place.mobs or { "people" }
    local boss = place and place.boss or { "the manager" }
    local mates = ctx.mates and #ctx.mates > 0 and ctx.mates or { "my nan" }
    line = line:gsub("{mobs}", function() return Pick(mobs) end):gsub("{boss}", function() return Pick(boss) end)
    line = line:gsub("{hat}", function() return Short(options.headwear) end):gsub("{outfit}", function() return Short(options.outfit) end)
    line = line:gsub("{me}", function() return ctx.me or "mate" end):gsub("{mate}", function() return Pick(mates) end)
    line = line:gsub("{n}", function() return tostring(ctx.kills and ctx.kills.n or "forty") end)
    line = line:gsub("{kill}", function() return ctx.kills and ctx.kills.name or "murlocs" end)
    return line
end

function ns.TellDream(traits, locked, ctx)
    local D = ns.DreamStory
    ctx = ctx or {}
    local options = {}
    for _, key in ipairs(ORDER) do options[key] = traits[key] and Option(key, traits[key]) end
    local function Name(key) return options[key] and options[key].name or "something" end
    local place = D.PLACE[traits.background or ""] or { at = { "somewhere I didn't recognise" }, pay = {}, enters = { "turns up" }, back = {} }
    local thing = D.THING[traits.accessory or ""] or { does = { "waves the " .. Name("accessory") .. " about" }, ends = D.GENERIC_ENDS }
    local placeTags = Tags(options.background)
    local hisTags = Tags(options.skin, options.outfit, options.headwear, options.eyes, options.expression, options.accessory)
    local set = MatchedSet(traits)
    local time = placeTags.morning and "morning" or placeTags.night and "night" or nil
    local opener = time and math.random() < 0.7 and Pick(D.OPENERS_TIME[time]) or Pick(D.OPENERS)
    local again = ctx.lastSkin and ctx.lastSkin == traits.skin
    local function Line(key, words) return Pick(words and words[traits[key] or ""]) or Name(key) end
    -- (a line for the dream's tags: the place's first, else his; nil if none fits)
    local function TagLine(byTag)
        if not byTag then return nil end
        for _, tags in ipairs({ placeTags, hisTags }) do
            local lists = {}
            for _, tag in ipairs(TAG_ORDER) do if tags[tag] and byTag[tag] then lists[#lists + 1] = byTag[tag] end end
            if #lists > 0 then return Pick(Pick(lists)) end
        end
    end
    -- The rarer of his outfit and hat gets its full line; the other one of its shortest, so the middle stays short.
    -- (The bedtime story's piece is always the full one.)
    local function Rank(key) return options[key] and RANK[options[key].rarity] or 0 end
    local plain = Rank("outfit") >= Rank("headwear") and "headwear" or "outfit"
    if locked == "outfit" then plain = "headwear" elseif locked == "headwear" then plain = "outfit" end
    local function Wear(key, words)
        local list = words and words[traits[key] or ""]
        if not list or #list == 0 then return Name(key) end
        if key ~= plain or #list < 3 then return Pick(list) end
        local sorted = {}
        for i, text in ipairs(list) do sorted[i] = text end
        table.sort(sorted, function(a, b) return #a < #b end)
        return sorted[math.random(2)]
    end
    -- Excited once at most: one of his legendary pieces (not the one the bedtime story asked for).
    local excitedKey
    do
        local keys = {}
        for _, key in ipairs({ "skin", "outfit", "headwear", "accessory" }) do
            if options[key] and options[key].rarity == "legendary" and key ~= locked then keys[#keys + 1] = key end
        end
        if #keys > 0 and math.random() < 0.8 then excitedKey = Pick(keys) end
    end
    local function Excited(key) return key == excitedKey and Pick(D.EXCITED) or "" end
    -- (the first pair that fits: the place's tags or his against his pieces')
    local reaction = ""
    for _, pair in ipairs(D.REACTIONS) do
        local a, b = pair[1], pair[2]
        if (placeTags[a] or hisTags[a]) and hisTags[b] and (a ~= b or placeTags[a]) then reaction = " " .. pair[3] break end
    end
    if math.random() < 0.3 then reaction = "" end
    local atIndex = math.random(#place.at)
    local beats = {
        { k = "background", pre = opener .. " ", say = place.at[atIndex], post = "..." },
        { k = "skin", pre = "when this ", say = Line("skin", D.SKIN),
            post = Excited("skin") .. " ogre " .. (again and "(that one AGAIN) " or "") .. Pick(place.enters) .. "," },
        { k = "outfit", pre = "", say = set and set.outfit or Wear("outfit", D.OUTFIT), post = Excited("outfit") .. "," },
        { k = "headwear", pre = set and "" or "with ", say = set and set.hat or Wear("headwear", D.HAT), post = Excited("headwear") .. "." .. reaction },
        { k = "eyes", pre = "He looks at me ", say = Line("eyes", D.EYES), post = "," },
        { k = "expression", pre = "", say = Line("expression", D.FACE), post = "..." },
        { k = "accessory", pre = "and then he ", say = Pick(thing.does), post = Excited("accessory") .. "." },
    }
    -- The ending: ONE punchline. Mostly the payoff to the dream's own opening, the thing he's holding's ending, or one
    -- of his own pieces'; now and then dream nonsense that fits the place. A boss's full set takes over the room instead.
    -- His own pieces' endings (D.ENDS): the full-line piece of outfit/hat (or both, in a matching set), and his skin.
    local own = {}
    for _, key in ipairs({ "skin", "outfit", "headwear" }) do
        local ends = D.ENDS and D.ENDS[traits[key] or ""]
        if ends and #ends > 0 and (key ~= plain or set) then own[#own + 1] = ends end
    end
    -- (a TAG_ENDS line for a tag on his clothes or what he's holding; {it} = that piece's short name)
    local function TagEnd()
        local D2 = D.TAG_ENDS
        if not D2 then return nil end
        local wears = Tags(options[plain == "headwear" and "outfit" or "headwear"], options[plain], options.accessory)
        local found = {}
        for _, tag in ipairs(TAG_ORDER) do if wears[tag] and D2[tag] then found[#found + 1] = tag end end
        if #found == 0 then return nil end
        local tag = Pick(found)
        return (Pick(D2[tag]):gsub("{it}", function() return Short(wears[tag]) end))
    end
    local punch, paid
    local roll = math.random()
    if set and set.boss and math.random() < 0.5 then
        punch = "And all the {mobs} started taking orders from him."
    elseif roll < 0.42 and place.pay and place.pay[atIndex] then
        punch, paid = Pick(place.pay[atIndex]), true
    elseif roll < 0.62 then
        punch = Pick(thing.ends)
    elseif roll < 0.8 and #own > 0 then
        punch = Pick(Pick(own))
    elseif roll < 0.92 then
        punch = TagEnd() or Pick(thing.ends)
    else
        punch = (math.random() < 0.7 and TagLine(D.WILD_TAGGED)) or (math.random() < 0.5 and Pick(D.GENERIC_ENDS)) or Pick(D.WILD)
    end
    -- Plus one small extra at most: you say something first, or a guildmate turns up after, or the place has a word.
    local before, after = nil, nil
    local extra = math.random()
    if extra < 0.35 then
        before = (math.random() < 0.6 and TagLine(D.ME)) or Pick(D.ME.any)
    elseif extra < 0.65 then
        if ctx.buddies and #ctx.buddies > 0 and math.random() < 0.5 then
            local buddy = Pick(ctx.buddies)
            after = Pick(D.BUDDY_CAMEOS):gsub("{buddy}", buddy.name):gsub("{buddyPlace}", buddy.place)
        elseif ctx.me or (ctx.mates and #ctx.mates > 0) then
            after = Pick(D.CAMEOS)
        end
    elseif extra < 0.8 and not paid and place.back and #place.back > 0 then
        after = Pick(place.back)
    end
    -- A word budget: a long dream drops the extra first, then the reaction (the beats and the punchline stay).
    local function Words(text) local n = 0 for _ in text:gmatch("%S+") do n = n + 1 end return n end
    local function Length()
        local n = Words(punch) + Words(before or "") + Words(after or "")
        for _, beat in ipairs(beats) do n = n + Words(beat.pre .. beat.say .. beat.post) end
        return n
    end
    if Length() > BUDGET then before, after = nil, nil end
    if Length() > BUDGET and reaction ~= "" then
        beats[4].post = beats[4].post:sub(1, #beats[4].post - #reaction)
        reaction = ""
    end
    local ending = (before and before .. " " or "") .. punch .. (after and " " .. after or "")
    ending = Fill(ending, place, options, ctx)
    for _, beat in ipairs(beats) do beat.post = Fill(beat.post, place, options, ctx) end
    return { beats = beats, ending = ending, set = set ~= nil, reaction = reaction ~= "" and reaction:sub(2) or nil }
end

-- A beat in ogre words: "HAT CAPTAIN TRICORN." (its piece's name, shouted).
function ns.DreamOgreBeat(key, id)
    local option = Option(key, id)
    return OGRE_LINES[key]:format((option and option.name or "THING"):upper())
end
function ns.DreamOgreEnd() return Pick(OGRE_ENDS) end

-- The whole dream as one text (a picture keeps it: the Dream Bed's card, the picture view).
function ns.DreamText(told)
    local parts = {}
    for _, beat in ipairs(told.beats) do parts[#parts + 1] = beat.pre .. beat.say .. beat.post end
    parts[#parts + 1] = told.ending
    return table.concat(parts, " ")
end
