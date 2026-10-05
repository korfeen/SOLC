-- Weight records: every kill gets a weight, and the heaviest kill per subtype is kept as a record.
-- Collected and synced, but not shown for now (no popups, no Records tab): set SHOW_RECORDS to bring
-- the popups back.
-- WoW has no weight data, so weights are invented:
--   base weight of the subtype x size^3 x rank bonus x random roll (0.8 - 1.2)
-- where size is the creature's real height relative to a typical member of its subtype (Data.lua).
-- Cubed because weight follows volume: half as tall is an eighth as heavy.

local _, ns = ...

-- Typical adult weight in kg. Made up, but roughly in proportion to the models.
local SUBTYPE_WEIGHTS = {
    -- Humanoids
    ["Human"] = 80, ["Dwarf"] = 85, ["Orc"] = 120, ["Night Elf"] = 85, ["Forsaken"] = 55,
    ["Tauren"] = 260, ["Troll"] = 105, ["Goblin"] = 35, ["Gnome"] = 25, ["Gnoll"] = 115,
    ["Kobold"] = 40, ["Ogre"] = 400, ["Murloc"] = 60, ["Centaur"] = 600, ["Quilboar"] = 140,
    ["Trogg"] = 90, ["Harpy"] = 50, ["Furbolg"] = 200, ["Satyr"] = 110, ["Naga"] = 180,
    ["High Elf"] = 70, ["Worgen"] = 140, ["Lost One"] = 70, ["Dragonspawn"] = 450,
    ["Tuskarr"] = 250, ["Wendigo"] = 300, ["Makrura"] = 120, ["Dryad"] = 300,
    ["Keeper of the Grove"] = 700,
    -- Beasts and critters
    ["Wolf"] = 70, ["Cat"] = 90, ["Spider"] = 20, ["Bear"] = 300, ["Boar"] = 120,
    ["Crocolisk"] = 350, ["Carrion Bird"] = 15, ["Crab"] = 30, ["Gorilla"] = 200, ["Raptor"] = 150,
    ["Tallstrider"] = 140, ["Scorpid"] = 40, ["Turtle"] = 250, ["Bat"] = 10, ["Hyena"] = 60,
    ["Owl"] = 8, ["Wind Serpent"] = 90, ["Core Hound"] = 800, ["Kodo"] = 1500, ["Basilisk"] = 400,
    ["Thunder Lizard"] = 1200, ["Gryphon"] = 350, ["Wind Rider"] = 300, ["Hippogryph"] = 300,
    ["Ram"] = 120, ["Horse"] = 500, ["Zhevra"] = 300, ["Chimaera"] = 600, ["Threshadon"] = 900,
    ["Worm"] = 5, ["Deer"] = 60, ["Stag"] = 200, ["Gazelle"] = 40, ["Snake"] = 5, ["Frenzy"] = 15, ["Shark"] = 400, ["Parrot"] = 1,
    ["Frog"] = 0.5, ["Chicken"] = 2, ["Rabbit"] = 2, ["Scarab"] = 1, ["Diemetradon"] = 700,
    ["Darkhound"] = 90, ["Devilsaur"] = 6000, ["Hydra"] = 1500, ["Rat"] = 0.5, ["Squirrel"] = 0.5,
    ["Sheep"] = 60, ["Cow"] = 600, ["Cockroach"] = 0.1, ["Prairie Dog"] = 1, ["Fish"] = 3,
    ["Owlbeast"] = 450, ["Pterrordax"] = 250, ["Giraffe"] = 1000, ["Silithid"] = 150, ["Ooze"] = 100,
    ["Lasher"] = 60, ["Salamander"] = 300,
    -- Undead
    ["Ghoul"] = 70, ["Skeleton"] = 20, ["Zombie"] = 65, ["Ghost"] = 1, ["Banshee"] = 1, ["Wraith"] = 1,
    ["Abomination"] = 900, ["Bone Construct"] = 400, ["Death Knight"] = 250, ["Crypt Fiend"] = 400,
    ["Gargoyle"] = 250, ["Lich"] = 40, ["Skeletal Horse"] = 150,
    -- Demons
    ["Felguard"] = 300, ["Doomguard"] = 500, ["Grell"] = 25, ["Felhunter"] = 120, ["Succubus"] = 65,
    ["Infernal"] = 2000, ["Felsteed"] = 500, ["Dreadlord"] = 150, ["Voidwalker"] = 150, ["Imp"] = 20,
    -- Elementals
    ["Bog Beast"] = 600, ["Earth Elemental"] = 1500, ["Fire Elemental"] = 50, ["Water Elemental"] = 800,
    ["Air Elemental"] = 5, ["Treant"] = 2500, ["Mana Fiend"] = 30, ["Obsidian Destroyer"] = 3000, ["Wisp"] = 0.1,
    -- Dragonkin
    ["Whelp"] = 60, ["Drake"] = 1500, ["Dragon"] = 8000, ["Faerie Dragon"] = 10,
    -- Mechanical
    ["Mechanostrider"] = 300, ["Mechano-Tank"] = 600, ["Golem"] = 900, ["Shredder"] = 1200,
    ["Dragonling"] = 30, ["Racer"] = 400,
    -- Giants and others
    ["Mountain Giant"] = 8000, ["Sea Giant"] = 7000, ["Titan Construct"] = 5000, ["Qiraji"] = 600,
    ["Tentacle"] = 1000,
}
-- For subtypes not listed above; also covers subtypes that are just the type name.
local TYPE_WEIGHTS = {
    ["Beast"] = 100, ["Dragonkin"] = 1500, ["Demon"] = 200, ["Elemental"] = 800, ["Giant"] = 6000,
    ["Undead"] = 70, ["Humanoid"] = 90, ["Critter"] = 2, ["Mechanical"] = 500,
}
local DEFAULT_WEIGHT = 80
local SHOW_RECORDS = false
local RANK_BONUS = { ["Elite"] = 1.25, ["Rare"] = 1.15, ["Rare Elite"] = 1.35, ["Boss"] = 1.6 }

local function RollWeight(c)
    local base = SUBTYPE_WEIGHTS[c.subtype] or TYPE_WEIGHTS[c.type] or DEFAULT_WEIGHT
    -- Average of three rolls: most kills land near 1.0, record-breakers near 1.2 are rare.
    local roll = 0.8 + 0.4 * (math.random() + math.random() + math.random()) / 3
    local weight = base * c.size ^ 3 * (RANK_BONUS[c.rank] or 1) * roll
    return math.floor(weight * 1000 + 0.5) / 1000
end

local function FormatWeight(kg)
    if kg < 1 then return ("%d g"):format(math.floor(kg * 1000 + 0.5)) end
    return ("%.1f kg"):format(kg)
end
ns.FormatWeight = FormatWeight

table.insert(ns.KillHandlers, function(npcID, entry, c)
    if ns.NO_AWARDS[c.subtype] then return end
    local key, subtype = "subtype:" .. c.subtype, c.subtype

    local weight = RollWeight(c)
    entry.maxWeight = math.max(entry.maxWeight or 0, weight)

    local records = KillTrackerDB.records
    local previous = records[key]
    if previous and weight <= previous.weight then return end

    local name = entry.name
    records[key] = {
        name = subtype,
        weight = weight,
        mob = name,
        npcID = npcID,
        zone = GetZoneText(),
        time = time(),
    }
    ns.Touch(records[key])

    if not SHOW_RECORDS then return end
    if previous then
        ns.ShowToast("record", "New record!", ("Heaviest %s: %s"):format(subtype, name),
            ("%s  (was %s)"):format(FormatWeight(weight), FormatWeight(previous.weight)))
        ns.Print(("New record! Heaviest %s: %s, %s (was %s)"):format(
            subtype, name, FormatWeight(weight), FormatWeight(previous.weight)))
    else
        ns.ShowToast("info", "First " .. subtype .. " killed", ("%s - %s"):format(name, FormatWeight(weight)))
    end
end)
