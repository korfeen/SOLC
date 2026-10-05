// Subtype rules: which subcategory (Gnoll, Ghoul, Fire Elemental, Kodo...) a creature belongs to,
// decided from its creature type, beast family and 3D model path (e.g. "creature/ghoul/ghoul.m2").

const TYPE_NAMES = {
    1: "Beast", 2: "Dragonkin", 3: "Demon", 4: "Elemental", 5: "Giant", 6: "Undead",
    7: "Humanoid", 8: "Critter", 9: "Mechanical", 10: "Other", 11: "Totem",
};
const T = { BEAST: 1, DRAGONKIN: 2, DEMON: 3, ELEMENTAL: 4, GIANT: 5, UNDEAD: 6, HUMANOID: 7, CRITTER: 8, MECHANICAL: 9, OTHER: 10 };

// Humanoid races, matched on the full model path. Also used for other types wearing humanoid models.
const RACE_RULES = [
    [/^character\/human\//, "Human"], [/^character\/dwarf\//, "Dwarf"], [/^character\/orc\//, "Orc"],
    [/^character\/nightelf\//, "Night Elf"], [/^character\/scourge\//, "Forsaken"], [/^character\/tauren\//, "Tauren"],
    [/^character\/troll\//, "Troll"], [/^character\/goblin\//, "Goblin"], [/^character\/gnome\//, "Gnome"],
    [/^creature\/gnoll/, "Gnoll"], [/^creature\/kobold/, "Kobold"], [/^creature\/ogre/, "Ogre"],
    [/^creature\/murloc/, "Murloc"], [/^creature\/centaur/, "Centaur"], [/^creature\/quil+boar/, "Quilboar"],
    [/^creature\/troglodyte/, "Trogg"], [/^creature\/harpy/, "Harpy"], [/^creature\/furbolg/, "Furbolg"],
    [/^creature\/satyr/, "Satyr"], [/^creature\/naga/, "Naga"], [/^creature\/highelf/, "High Elf"],
    [/^creature\/(hum|hufm|defias)/, "Human"], [/^creature\/.*dwarf/, "Dwarf"], [/^creature\/orc/, "Orc"],
    [/^creature\/troll/, "Troll"], [/^creature\/goblin(?!rocketcar)/, "Goblin"], [/^creature\/gnome(?!spidertank|rocketcar)/, "Gnome"],
    [/^creature\/tauren/, "Tauren"], [/^creature\/nightelf/, "Night Elf"], [/^creature\/worgen/, "Worgen"],
    [/^creature\/lostone/, "Lost One"], [/^creature\/(dragonspawn|wyrmkin|dragonfootsoldier)/, "Dragonspawn"],
    [/^creature\/tuskarr/, "Tuskarr"], [/^creature\/scourge/, "Forsaken"],
    [/^creature\/wendigo/, "Wendigo"], [/^creature\/lobstrok/, "Makrura"],
];

// Type-specific rules, matched on the model folder (second path segment). First match wins.
const TYPE_RULES = {
    [T.UNDEAD]: [
        [/^ghoul/, "Ghoul"], [/^skeletonmage|^lich|^necromancer/, "Lich"], [/^skeleton/, "Skeleton"],
        [/^zombie/, "Zombie"], [/^(ghost|wight)/, "Ghost"], [/^banshee/, "Banshee"], [/^shade/, "Wraith"],
        [/^(fleshgolem|fleshtitan)/, "Abomination"], [/^bonegolem/, "Bone Construct"],
        [/^mounteddeathknight/, "Death Knight"], [/^crypt(fiend|lord)/, "Crypt Fiend"], [/^gargoyle/, "Gargoyle"],
        [/^undeadhorse/, "Skeletal Horse"], [/^scourge/, "Forsaken"],
    ],
    [T.DEMON]: [
        [/^satyr/, "Satyr"], [/^felguard/, "Felguard"], [/^doomguard/, "Doomguard"], [/^grell/, "Grell"],
        [/^felhound/, "Felhunter"], [/^darkhound/, "Darkhound"], [/^succubus/, "Succubus"], [/^infernal/, "Infernal"],
        [/^nightmare/, "Felsteed"], [/^dreadlord/, "Dreadlord"], [/^void(walker|terror)/, "Voidwalker"], [/^imp/, "Imp"],
    ],
    [T.ELEMENTAL]: [
        [/^bogbeast/, "Bog Beast"], [/^(elementalearth|golemstone)/, "Earth Elemental"],
        [/^(fireelemental|ragnaros)/, "Fire Elemental"], [/^waterelemental|^elementalpoison/, "Water Elemental"],
        [/^(airelemental|thunderaan)/, "Air Elemental"], [/^(ent|ancient)/, "Treant"], [/^manafiend/, "Mana Fiend"],
        [/^obsidiandestroyer/, "Obsidian Destroyer"],
    ],
    [T.DRAGONKIN]: [
        [/^(dragonspawn|dragonfootsoldier)/, "Dragonspawn"], [/^drake/, "Drake"], [/^dragonwhelp/, "Whelp"],
        [/^faeriedragon/, "Faerie Dragon"], [/^dragon$/, "Dragon"],
    ],
    [T.MECHANICAL]: [
        [/^mechastrider/, "Mechanostrider"], [/^(gnomespidertank|steamtonk)/, "Mechano-Tank"], [/^golem/, "Golem"],
        [/^goblin$/, "Shredder"], [/^dragonwhelp/, "Dragonling"], [/^(goblin|gnome)rocketcar/, "Racer"],
    ],
    [T.GIANT]: [
        [/^mountaingiant/, "Mountain Giant"], [/^seagiant/, "Sea Giant"], [/^(titan|stonekeeper)/, "Titan Construct"],
        [/^ancientprotector/, "Treant"],
    ],
    [T.OTHER]: [
        [/^quiraj|^anubisath/, "Qiraji"], [/ofkathune$|^eyestalkofkathune/, "Tentacle"],
    ],
};

// Animals and other creatures that appear under several types. Matched on the model folder.
const GENERIC_RULES = [
    [/^kodobeast/, "Kodo"], [/^(direwolf|wolf)/, "Wolf"], [/^basilisk/, "Basilisk"], [/^(frostsabre|tiger|cat|lion)$/, "Cat"],
    [/^thunderlizard/, "Thunder Lizard"], [/^gryphon/, "Gryphon"], [/^wyvern/, "Wind Rider"], [/^hippogryph/, "Hippogryph"],
    [/^ram$/, "Ram"], [/^(ridinghorse|horse|warhorse)/, "Horse"], [/^unicorn/, "Zhevra"], [/^(ridingraptor|raptor)/, "Raptor"],
    [/^chimera/, "Chimaera"], [/^threshadon/, "Threshadon"], [/^(minespider|tarantula|spider|giantspider)/, "Spider"],
    [/^(larva|worm|sandworm)/, "Worm"], [/^stag/, "Stag"], [/^deer/, "Deer"], [/^gazelle/, "Gazelle"], [/^(serpent|snake)/, "Snake"], [/^frenzy/, "Frenzy"],
    [/^shark/, "Shark"], [/^parrot/, "Parrot"], [/^bear/, "Bear"], [/^frog/, "Frog"], [/^windserpent/, "Wind Serpent"],
    [/^owl/, "Owl"], [/^(sea)?turtle/, "Turtle"], [/^tallstrider/, "Tallstrider"], [/^chicken/, "Chicken"],
    [/^rabbit/, "Rabbit"], [/^felbat|^bat/, "Bat"], [/^(fel)?boar/, "Boar"], [/^(silithidscarab|cryptscarab)/, "Scarab"],
    [/^diemetradon/, "Diemetradon"], [/^felbeast/, "Core Hound"], [/^darkhound/, "Darkhound"], [/^gorilla/, "Gorilla"],
    [/^trex/, "Devilsaur"], [/^hydra/, "Hydra"], [/^crocodile/, "Crocolisk"], [/^carrionbird/, "Carrion Bird"],
    [/^crab/, "Crab"], [/^scorpion/, "Scorpid"], [/^hyena/, "Hyena"], [/^rat$/, "Rat"], [/^squirrel/, "Squirrel"],
    [/^sheep/, "Sheep"], [/^cow/, "Cow"], [/^cockroach/, "Cockroach"], [/^prariedog/, "Prairie Dog"],
    [/^slime/, "Ooze"], [/^silithid/, "Silithid"], [/^lasher/, "Lasher"], [/^wisp/, "Wisp"],
    [/^infernal/, "Infernal"], [/^imp$/, "Imp"], [/^golem/, "Golem"], [/^fish/, "Fish"],
    [/^forceofnature|^druidowlbear/, "Owlbeast"], [/^dryad/, "Dryad"], [/^keeperofthegrove/, "Keeper of the Grove"],
    [/^salamander/, "Salamander"], [/^grell/, "Grell"], [/^pterrordax/, "Pterrordax"], [/^giraffe/, "Giraffe"],
    [/^(ghost|banshee)/, "Ghost"], [/^dragonwhelp/, "Whelp"], [/^druidbear/, "Bear"],
];

const match = (rules, s) => (rules.find(([re]) => re.test(s)) || [])[1];

// Returns the subtype name for a creature. familyName may be undefined; modelPath may be undefined.
function subtypeFor(type, familyName, modelPath) {
    if (familyName) return familyName;
    const folder = modelPath ? modelPath.split("/")[1] || "" : "";
    if (modelPath) {
        if (type === T.HUMANOID) {
            const race = match(RACE_RULES, modelPath);
            if (race) return race;
        }
        const specific = TYPE_RULES[type] && match(TYPE_RULES[type], folder);
        if (specific) return specific;
        const generic = match(GENERIC_RULES, folder);
        if (generic) return generic;
        // Undead wearing a humanoid model, e.g. Mummified Atal'ai -> "Undead Troll".
        if (type === T.UNDEAD) {
            const race = match(RACE_RULES, modelPath);
            if (race) return race === "Forsaken" ? race : "Undead " + race;
        }
    }
    return TYPE_NAMES[type] || "Other";
}

module.exports = { TYPE_NAMES, subtypeFor };
