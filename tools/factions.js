// Faction corrections on top of Blizzard's data, used by build-data.js.
// Blizzard lumps many tribes and clans into one faction ("Ogre", "Murloc", "Harpy"...), files whole
// tribes under unrelated ones (Zul'Farrak's Sandfury trolls are "Frostmane"), and has no blue
// dragonflight. Mobs carry their tribe in their name ("Mosh'Ogg Brute"), so they're regrouped by that.

// Our own factions get IDs from here up; they don't exist in the game.
const FIRST_NEW_ID = 100001;

// Tribes per subtype: the name word(s) that mark the tribe, and the faction they get.
const TRIBES = {
    Ogre: [
        ["Gordok", "Ogre, Gordok"], ["Gordunni", "Ogre, Gordunni"], ["Dustbelcher", "Ogre, Dustbelcher"],
        ["Spirestone", "Ogre, Spirestone"], ["Mosh'Ogg", "Ogre, Mosh'Ogg"], ["Crushridge", "Ogre, Crushridge"],
        ["Boulderfist", "Ogre, Boulderfist"], ["Splinter Fist", "Ogre, Splinter Fist"], ["Mo'grosh", "Ogre, Mo'grosh"],
        ["Dunemaul", "Ogre, Dunemaul"], ["Dreadmaul", "Ogre, Dreadmaul"], ["Deadwind", "Ogre, Deadwind"],
        ["Firegut", "Ogre, Firegut"], ["Urok", "Ogre, Urok"],
    ],
    Troll: [
        ["Sandfury", "Troll, Sandfury"], ["Atal'ai", "Troll, Atal'ai"], ["Gurubashi", "Troll, Gurubashi"],
        ["Hakkari", "Troll, Gurubashi"], ["Smolderthorn", "Troll, Smolderthorn"], ["Winterax", "Troll, Winterax"],
        ["Mossflayer", "Troll, Mossflayer"], ["Bloodscalp", "Troll, Bloodscalp"], ["Skullsplitter", "Troll, Skullsplitter"],
        ["Witherbark", "Troll, Witherbark"], ["Vilebranch", "Troll, Vilebranch"], ["Frostmane", "Troll, Frostmane"],
    ],
    Murloc: [
        ["Vile Fin", "Murloc, Vile Fin"], ["Greymist", "Murloc, Greymist"], ["Bluegill", "Murloc, Bluegill"],
        ["Mirefin", "Murloc, Mirefin"], ["Saltscale", "Murloc, Saltscale"], ["Murkgill", "Murloc, Murkgill"],
        ["Torn Fin", "Murloc, Torn Fin"], ["Saltspittle", "Murloc, Saltspittle"], ["Blindlight", "Murloc, Blindlight"],
        ["Storm Bay", "Murloc, Storm Bay"],
    ],
    Harpy: [
        ["Bloodfury", "Harpy, Bloodfury"], ["Bloodfeather", "Harpy, Bloodfeather"], ["Witchwing", "Harpy, Witchwing"],
        ["Windfury", "Harpy, Windfury"], ["Dustwind", "Harpy, Dustwind"], ["Northspring", "Harpy, Northspring"],
        ["Snowblind", "Harpy, Snowblind"],
    ],
    Kobold: [
        ["Tunnel Rat", "Kobold, Tunnel Rat"], ["Gravelsnout", "Kobold, Gravelsnout"], ["Whitewhisker", "Kobold, Whitewhisker"],
        ["Drywhisker", "Kobold, Drywhisker"], ["Windshear", "Kobold, Windshear"], ["Gogger", "Kobold, Gogger"],
    ],
    Furbolg: [
        ["Gnarlpine", "Furbolg, Gnarlpine"], ["Blackwood", "Furbolg, Blackwood"], ["Winterfall", "Furbolg, Winterfall"],
        ["Foulweald", "Furbolg, Foulweald"], ["Thistlefur", "Furbolg, Thistlefur"], ["Deadwood", "Furbolg, Deadwood"],
    ],
    Trogg: [
        ["Stonevault", "Trogg, Stonevault"], ["Stonesplinter", "Trogg, Stonesplinter"], ["Rockjaw", "Trogg, Rockjaw"],
        ["Caverndeep", "Trogg, Caverndeep"], ["Gravelflint", "Trogg, Gravelflint"], ["Ragefire", "Trogg, Ragefire"],
        ["Irondeep", "Trogg, Irondeep"],
    ],
    Naga: [
        ["Spitelash", "Naga, Spitelash"], ["Slitherblade", "Naga, Slitherblade"], ["Daggerspine", "Naga, Daggerspine"],
        ["Hatecrest", "Naga, Hatecrest"], ["Stormscale", "Naga, Stormscale"], ["Wrathtail", "Naga, Wrathtail"],
        ["Strashaz", "Naga, Strashaz"],
    ],
    Satyr: [
        ["Jadefire", "Satyr, Jadefire"], ["Wildspawn", "Satyr, Wildspawn"], ["Hatefury", "Satyr, Hatefury"],
        ["Xavian", "Satyr, Xavian"], ["Felmusk", "Satyr, Felmusk"], ["Bleakheart", "Satyr, Bleakheart"],
        ["Fallenroot", "Satyr, Fallenroot"], ["Haldarr", "Satyr, Haldarr"], ["Legashi", "Satyr, Legashi"],
        ["Putridus", "Satyr, Putridus"],
    ],
    Gnoll: [["Woodpaw", "Gnoll - Woodpaw"], ["Wildpaw", "Gnoll - Wildpaw"], ["Palemane", "Gnoll - Palemane"]],
    Centaur: [
        ["Kolkar", "Centaur, Kolkar"], ["Galak", "Centaur, Galak"], ["Maraudine", "Centaur, Maraudine"],
        ["Magram", "Centaur, Magram"], ["Gelkis", "Centaur, Gelkis"],
    ],
    Quilboar: [["Death's Head", "Quilboar, Deathshead"]],
};

// Named NPCs (exact names) whose names don't carry their tribe: leaders, bosses and their guards.
const NAMED = {
    "Ogre, Gordok": ["King Gordok", "Cho'Rush the Observer", "Captain Kromcrush", "Guard Fengus", "Guard Mol'dar",
        "Guard Slip'kik", "Stomper Kreeg"],
    "Ogre, Spirestone": ["Highlord Omokk"],
    "Ogre, Crushridge": ["Mug'thol"],
    "Ogre, Mo'grosh": ["Chok'sul"],
    "Troll, Sandfury": ["Chief Ukorz Sandscalp", "Ruuzlu", "Hydromancer Velratha", "Shadowpriest Sezz'ziz",
        "Antu'sul", "Witch Doctor Zum'rah", "Nekrum Gutchewer", "Zerillis", "Dustwraith"],
    "Troll, Atal'ai": ["Jammal'an the Prophet", "Ogom the Wretched", "Avatar of Hakkar", "Atal'alarion",
        "Kazkaz the Unholy", "Veyzhak the Cannibal"],
    "Troll, Gurubashi": ["Hakkar", "Jin'do the Hexxer", "Bloodlord Mandokir", "High Priest Venoxis", "High Priest Thekal",
        "High Priestess Mar'li", "High Priestess Jeklik", "High Priestess Arlokk", "Zealot Lor'Khan", "Zealot Zath",
        "Gri'lek", "Hazza'rah", "Renataki", "Wushoolay", "Jin"],
    "Troll, Smolderthorn": ["War Master Voone", "Shadow Hunter Vosh'gajin"],
    "Troll, Winterax": ["Korrak the Bloodrager"],
    "Satyr, Wildspawn": ["Alzzin the Wildshaper"],
    "Trogg, Irondeep": ["Morloch"],
    // Tribe leaders from Wowpedia that the data files under catch-all or wrong factions.
    "Gnoll - Palemane": ["Snagglespear"],
    "Trogg, Stonesplinter": ["Grawmug"],
    "Trogg, Caverndeep": ["Grubbis"],
    "Murloc, Greymist": ["Murkdeep"],
    "Kobold, Gravelsnout": ["Gibblesnik"],
    "Kobold, Gogger": ["Goggeroc"],
    "Harpy, Witchwing": ["Serena Bloodfeather"],
    "Harpy, Northspring": ["Edana Hatetalon"],
    "Furbolg, Foulweald": ["Chief Murgut"],
    "Naga, Slitherblade": ["Lord Kragaru"],
    "Ogre, Dreadmaul": ["Grol the Destroyer"],
    "Satyr, Xavian": ["Prince Raze"],          // Wowpedia: lives in Xavian, roams near Satyrnaar
    "Furbolg, Deadwood": ["Carnivous the Breaker"],  // Wowpedia: presumed Deadwood, roams Blackwood land
    // Leaders Blizzard filed under catch-all or other factions.
    "Quilboar, Razormane": ["Nak", "Lok Orcbane", "Kuz"],
    "Quilboar, Bristleback": ["Chief Sharptusk Thornmantle"],
    "Centaur, Kolkar": ["Barak Kodobane"],
    "Dragonflight, Black": ["Nefarian"],
    "Demon": ["Lord Kazzak"],
    "Syndicate": ["Lord Aliden Perenolde"],
    "Wailing Caverns": ["Mutanus the Devourer"],
    "Troll, Vilebranch": ["Vile Priestess Hexx"],
};

// Leaders per faction (exact NPC names): lore leaders where known, otherwise the chief or quest boss
// of that tribe. Shown in the window with a crown once killed.
const LEADERS = {
    "Defias Brotherhood": ["Edwin VanCleef"],
    "Gnoll - Riverpaw": ["Hogger"], "Gnoll - Redridge": ["Yowler"], "Gnoll - Shadowhide": ["Lieutenant Fangore"],
    "Gnoll - Rothide": ["Thule Ravenclaw"], "Gnoll - Mosshide": ["Gnawbone"], "Gnoll - Mudsnout": ["Ro'Bark"],
    "Quilboar, Bristleback": ["Chief Sharptusk Thornmantle"], "Quilboar, Razormane": ["Kuz", "Nak", "Lok Orcbane"],
    "Quilboar, Razorfen": ["Charlga Razorflank"], "Quilboar, Deathshead": ["Amnennar the Coldbringer"],
    "Centaur, Kolkar": ["Khan Dez'hepah", "Barak Kodobane"], "Centaur, Gelkis": ["Khan Shaka"],
    "Centaur, Magram": ["Khan Jehn"], "Centaur, Maraudine": ["Khan Hratha"],
    "Orc, Blackrock": ["Warchief Rend Blackhand"], "Dark Iron Dwarves": ["Emperor Dagran Thaurissan"],
    "Undead, Scourge": ["Kel'Thuzad"], "Scarlet Crusade": ["Grand Crusader Dathrohan"],
    "Kurzen's Mercenaries": ["Colonel Kurzen"], "Worgen": ["Archmage Arugal"], "Blackfathom": ["Twilight Lord Kelris"],
    "Troll, Bloodscalp": ["Gan'zulah"], "Troll, Witherbark": ["Zalas Witherbark"], "Troll, Vilebranch": ["Vile Priestess Hexx"],
    "Troll, Sandfury": ["Chief Ukorz Sandscalp"], "Troll, Atal'ai": ["Jammal'an the Prophet"], "Troll, Gurubashi": ["Hakkar"],
    "Troll, Smolderthorn": ["War Master Voone"], "Troll, Winterax": ["Korrak the Bloodrager"],
    "Troll, Frostmane": ["Grik'nir the Cold"], "Troll, Mossflayer": ["Zul'Brin Warpbranch"], "Troll, Skullsplitter": ["Mogh the Undying"],
    "Ogre, Gordok": ["King Gordok"], "Ogre, Spirestone": ["Highlord Omokk"], "Ogre, Crushridge": ["Mug'thol"],
    "Ogre, Mo'grosh": ["Chok'sul"], "Ogre, Mosh'Ogg": ["Mai'Zoth"], "Ogre, Boulderfist": ["Or'Kalar"],
    "Ogre, Urok": ["Urok Doomhowl"], "Ogre, Dunemaul": ["Gor'marok the Ravager"], "Ogre, Firegut": ["Krom'Grul"],
    "Ogre, Dustbelcher": ["Boss Tho'grun"], "Ogre, Splinter Fist": ["Zzarc' Vul"],
    "Furbolg, Winterfall": ["High Chief Winterfall"], "Furbolg, Gnarlpine": ["Ursal the Mauler"],
    "Furbolg, Deadwood": ["Overlord Ror"], "Furbolg, Thistlefur": ["Dal Bloodclaw"],
    "Trogg, Stonevault": ["Grimlok"], "Trogg, Ragefire": ["Oggleflint"], "Trogg, Irondeep": ["Morloch"],
    "Kobold, Whitewhisker": ["Taskmaster Snivvle"], "Murloc, Blindlight": ["Gelihast"],
    "Naga, Hatecrest": ["Lord Shalzaru"], "Naga, Stormscale": ["Lady Vespira"], "Naga, Wrathtail": ["Ruuzel"],
    "Naga, Daggerspine": ["Prince Nazjak"], "Naga, Spitelash": ["Warlord Krellian"], "Naga, Strashaz": ["Tidelord Rrurgaz"],
    "Satyr, Jadefire": ["Xavathras"], "Satyr, Xavian": ["Geltharis"], "Satyr, Wildspawn": ["Alzzin the Wildshaper"],
    "Satyr, Putridus": ["Lord Vyletongue"], "Satyr, Hatefury": ["Prince Kellen"], "Satyr, Legashi": ["Master Feardred"],
    "Elemental": ["Ragnaros"], "Demon": ["Lord Kazzak"], "Dragonflight, Black": ["Nefarian"],
    "Dragonflight, Blue": ["Azuregos"], "Dragonflight, Red": ["Vaelastrasz the Red"],
    "Armies of C'Thun": ["C'Thun"], "Silithid": ["C'Thun"], "Titan": ["Archaedas"], "Shen'dralar": ["Prince Tortheldrin"],
    "Jaedenar": ["Lord Banehollow"], "Gnome - Leper": ["Mekgineer Thermaplugg"], "Lost Ones": ["Noboru the Cudgel"],
    "Burning Blade": ["Taragaman the Hungerer"], "Syndicate": ["Lord Aliden Perenolde"],
    "Wailing Caverns": ["Mutanus the Devourer"],
    // From Wowpedia's tribe pages, limited to NPCs that exist in Classic:
    "Gnoll - Wildpaw": ["Grimtooth"], "Gnoll - Palemane": ["Snagglespear"],
    "Trogg, Rockjaw": ["Hammerspine"], "Trogg, Stonesplinter": ["Boss Galgosh"], "Trogg, Caverndeep": ["Grubbis"],
    "Murloc, Bluegill": ["Gobbler"], "Murloc, Vile Fin": ["Muad"], "Murloc, Greymist": ["Murkdeep"],
    "Murloc, Torn Fin": ["Scargil"], "Murloc, Murkgill": ["Gluggle"], "Murloc, Saltspittle": ["Mugglefin"],
    "Murloc, Storm Bay": ["Lord Arkkoroc"],
    "Kobold, Drywhisker": ["Geomancer Flintdagger"], "Kobold, Gravelsnout": ["Gibblesnik"], "Kobold, Gogger": ["Goggeroc"],
    "Harpy, Bloodfeather": ["Fury Shelda"], "Harpy, Witchwing": ["Serena Bloodfeather"], "Harpy, Windfury": ["Sister Hatelash"],
    "Harpy, Bloodfury": ["Bloodfury Ripper"], "Harpy, Northspring": ["Edana Hatetalon"],
    "Furbolg, Foulweald": ["Chief Murgut"], "Centaur, Galak": ["Veng"],
    "Naga, Slitherblade": ["Lord Kragaru"], "Ogre, Dreadmaul": ["Grol the Destroyer"],
    "Ogre, Gordunni": ["King Gordok"],  // Wowpedia: the Dire Maul Gordunni's king
    // No leader on Wowpedia; the highest-ranked named mob living in their camps instead:
    "Murloc, Mirefin": ["Burgle Eye"],
};

// Overlords above all tribes of a creature (subtype), where Classic has a lore one. Every other tribal
// race gets a Champion instead: its mightiest mob in the game (see resolveOverlords).
const SUBTYPE_OVERLORDS = {
    "Troll": ["Hakkar"], "Ogre": ["King Gordok"], "Centaur": ["Princess Theradras"],
    "Silithid": ["C'Thun"], "Qiraji": ["C'Thun"],
    "Fire Elemental": ["Ragnaros"], "Earth Elemental": ["Princess Theradras"], "Air Elemental": ["Prince Thunderaan"],
};
// Overlords of every subtype of a creature type (by the subtype's usual type), except the listed ones.
const TYPE_OVERLORDS = {
    6: { leaders: ["Kel'Thuzad"], except: ["Forsaken"] },  // Undead: the Scourge
    3: { leaders: ["Lord Kazzak"], except: ["Satyr"] },     // Demon: the Burning Legion
};

// Resolves overlords to { subtype: { kind = "overlord" | "champion", leaders = [[npcID, name]] } }.
// Lore overlords first; every tribal race (TRIBES) without one gets a Champion: its mightiest unique
// mob (at most 2 spawn points) that isn't friendly, scored by level plus a bonus for its rank.
// subtypeType: subtype -> usual creature type. spawnCount: Map of NPC ID -> number of spawn points.
const RANK_BONUS = { 3: 5, 2: 3, 1: 3, 4: 1, 0: 0 };  // boss, rare elite, elite, rare, normal
function resolveOverlords(rows, subtypeType, spawnCount, factionName) {
    const byName = new Map(rows.map((n) => [n.name, n]));
    const names = {};
    for (const [subtype, type] of subtypeType) {
        const rule = TYPE_OVERLORDS[type];
        if (rule && !rule.except.includes(subtype)) names[subtype] = rule.leaders;
    }
    Object.assign(names, SUBTYPE_OVERLORDS);
    const overlords = {};
    for (const [subtype, list] of Object.entries(names)) {
        if (!subtypeType.has(subtype)) continue;
        for (const name of list) {
            if (!byName.has(name)) { console.log("Overlord not found in the data: " + name); continue; }
            overlords[subtype] = overlords[subtype] || { kind: "overlord", leaders: [] };
            overlords[subtype].leaders.push([byName.get(name).id, name]);
        }
    }
    for (const subtype of Object.keys(TRIBES)) {
        if (overlords[subtype]) continue;
        let best = null;
        for (const n of rows) {
            const spawns = spawnCount.get(n.id) || 0;
            if (n.subtype !== subtype || spawns < 1 || spawns > 2 || /[[(]|test|unused/i.test(n.name)) continue;
            if (KEEP.test(factionName.get(n.factionID) || "")) continue;
            n.might = n.level + (RANK_BONUS[n.rank] || 0);
            if (!best || n.might > best.might) best = n;
        }
        if (best) overlords[subtype] = { kind: "champion", leaders: [[best.id, best.name]] };
    }
    return overlords;
}

// Rulers of the player races (city raid bosses), shown on the PvP tab's race rows. Keys are the
// English race names UnitRace returns.
const RACE_LEADERS = {
    "Human": ["Highlord Bolvar Fordragon"], "Dwarf": ["King Magni Bronzebeard"], "Gnome": ["High Tinker Mekkatorque"],
    "Night Elf": ["Tyrande Whisperwind"], "Orc": ["Thrall"], "Troll": ["Vol'jin"], "Tauren": ["Cairne Bloodhoof"],
    "Undead": ["Lady Sylvanas Windrunner"],
};

// Resolves RACE_LEADERS to { race: [[npcID, name]] }; unknown names are reported.
function resolveRaceLeaders(rows) {
    const byName = new Map(rows.map((n) => [n.name, n]));
    const leaders = {};
    for (const [race, names] of Object.entries(RACE_LEADERS)) {
        for (const name of names) {
            if (!byName.has(name)) { console.log("Race leader not found in the data: " + name); continue; }
            (leaders[race] = leaders[race] || []).push([byName.get(name).id, name]);
        }
    }
    return leaders;
}

// Resolves LEADERS to { faction: [[npcID, name], ...] }, preferring an NPC filed under that faction when a
// name is used by several NPCs. Factions missing from the data are skipped; unknown names are reported.
function resolveLeaders(rows, factionName) {
    const byName = new Map();
    for (const n of rows) {
        if (!byName.has(n.name)) byName.set(n.name, []);
        byName.get(n.name).push(n);
    }
    const present = new Set(rows.map((n) => factionName.get(n.factionID)));
    const leaders = {}, missing = [];
    for (const [faction, names] of Object.entries(LEADERS)) {
        if (!present.has(faction)) continue;
        for (const name of names) {
            const candidates = byName.get(name);
            if (!candidates) { missing.push(name); continue; }
            const pick = candidates.find((n) => factionName.get(n.factionID) === faction)
                || candidates.sort((a, b) => b.rank - a.rank)[0];
            (leaders[faction] = leaders[faction] || []).push([pick.id, name]);
        }
    }
    if (missing.length) console.log("Leaders not found in the data: " + missing.join(", "));
    return leaders;
}

// Dragonkin by the colour in their name, moved only away from catch-all or odd factions.
// "Corrupted" whelps are black-flight experiments and stay black.
const DRAGONFLIGHTS = [
    [/\b(blue|cobalt|cobaltine|azure)\b|^azuregos$|^spirit of azuregos$/i, "Dragonflight, Blue"],
    [/\bblack\b|\bonyxian?\b|^onyxia's/i, "Dragonflight, Black"],
    [/\b(red|crimson)\b/i, "Dragonflight, Red"],
    [/\b(green|emerald)\b/i, "Dragonflight, Green"],
    [/\bbronze\b/i, "Dragonflight, Bronze"],
];
const DRAGON_MOVABLE = /^(Monster|Creature|Ambient|Beast - .*|Dragonflight, .*)$/;

const RENAMES = {
    "Quilboar, Razormane 2": "Quilboar, Razormane",
    "Maraudine": "Centaur, Maraudine",
    "Magram Clan Centaur": "Centaur, Magram",
    "Gelkis Clan Centaur": "Centaur, Gelkis",
    "Dragonflight, Black - Bait": "Dragonflight, Black",
    "Ogre (Captain Kromcrush)": "Ogre, Gordok",
};

// Friendly, city and reputation factions are never changed.
const KEEP = /^(Friendly|Escortee|Orgrimmar|Stormwind|Ironforge|Darnassus|Undercity|Thunder Bluff|Booty Bay|Gadgetzan|Everlook|Ratchet|Darkspear Trolls|Revantusk Trolls|Zandalar Tribe|Timbermaw Hold|Darkmoon Faire|Battleground Neutral|Argent Dawn|Cenarion Circle|.*Generic)$/;

const escape = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

// Rewrites row.factionID in place. factionName (Map id -> name) gets renames and our new factions.
function fixFactions(rows, factionName) {
    let nextID = FIRST_NEW_ID;
    const idOf = new Map();
    for (const [id, name] of factionName) {
        const renamed = RENAMES[name] || name;
        factionName.set(id, renamed);
        if (!idOf.has(renamed)) idOf.set(renamed, id);
    }
    const factionID = (name) => {
        if (!idOf.has(name)) {
            idOf.set(name, nextID);
            factionName.set(nextID, name);
            nextID++;
        }
        return idOf.get(name);
    };
    // Merge factions that a rename made identical (e.g. "Black - Bait" into "Black").
    for (const n of rows) {
        const name = factionName.get(n.factionID);
        if (name) n.factionID = idOf.get(name);
    }

    const tribeRules = Object.fromEntries(Object.entries(TRIBES).map(([subtype, tribes]) =>
        [subtype, tribes.map(([word, faction]) => [new RegExp(`(^|\\s)${escape(word)}(\\s|$)`, "i"), faction])]));
    const named = new Map();
    for (const [faction, names] of Object.entries(NAMED)) for (const name of names) named.set(name, faction);

    const found = new Set();
    for (const n of rows) {
        // Named NPCs are explicit choices, so they win even over friendly factions (e.g. Witch Doctor
        // Zum'rah starts friendly and turns hostile in his Zul'Farrak event).
        if (named.has(n.name)) {
            n.factionID = factionID(named.get(n.name));
            found.add(n.name);
            continue;
        }
        const current = factionName.get(n.factionID) || "";
        if (KEEP.test(current)) continue;
        const tribe = (tribeRules[n.subtype] || []).find(([re]) => re.test(n.name));
        if (tribe) {
            n.factionID = factionID(tribe[1]);
        } else if (n.type === 2 && !/corrupted/i.test(n.name) && DRAGON_MOVABLE.test(current)) {
            const flight = DRAGONFLIGHTS.find(([re]) => re.test(n.name));
            if (flight) n.factionID = factionID(flight[1]);
        }
    }
    const missing = [...named.keys()].filter((name) => !found.has(name));
    if (missing.length) console.log("Named NPCs not found in the data: " + missing.join(", "));
}

// Beasts and critters: Blizzard files most of them under catch-alls ("Monster"), generic animal factions
// ("Leopard") or the wrong beast faction (a spider in "Beast - Wolf"). They're grouped by their own kind
// instead, so every crocolisk - rares included - is in faction "Crocolisk". Beast factions lose the
// "Beast - " prefix to match. Beasts with a real owner (Zul'Gurub's Zulian tigers, worgen worgs,
// Frostwolf wolves) keep that faction.
const BEAST_MOVABLE = /^(Monster|Creature|Ambient|Prey|Victim|Leopard|Basilisk|Scorpid|Searing Spider|Beast - .*)$/;
const BEAST_TYPES = new Set([1, 8]);  // Beast, Critter

function groupBeasts(rows, factionName) {
    // Each subtype's usual creature type.
    const typeVotes = new Map();
    for (const n of rows) {
        if (n.type === 10) continue;  // invisible triggers borrow animal models (rabbits), skip them
        const votes = typeVotes.get(n.subtype) || new Map();
        votes.set(n.type, (votes.get(n.type) || 0) + 1);
        typeVotes.set(n.subtype, votes);
    }
    const usualType = (subtype) => typeVotes.has(subtype) ? [...typeVotes.get(subtype)].sort((a, b) => b[1] - a[1])[0][0] : 10;

    for (const [id, name] of factionName) {
        if (name.startsWith("Beast - ")) factionName.set(id, name.slice(8));
    }
    const idOf = new Map();
    for (const [id, name] of factionName) if (!idOf.has(name)) idOf.set(name, id);
    let nextID = Math.max(...factionName.keys()) + 1;
    const factionID = (name) => {
        if (!idOf.has(name)) {
            idOf.set(name, nextID);
            factionName.set(nextID, name);
            nextID++;
        }
        return idOf.get(name);
    };

    let moved = 0;
    for (const n of rows) {
        if (!BEAST_TYPES.has(n.type) || !BEAST_TYPES.has(usualType(n.subtype))) continue;
        const current = factionName.get(n.factionID) || "Monster";
        // Already-renamed beast factions ("Wolf") count as movable when they don't match the mob's kind.
        const isBeastFaction = typeVotes.has(current) && BEAST_TYPES.has(usualType(current));
        if (current === n.subtype || !(BEAST_MOVABLE.test(current) || isBeastFaction || n.factionID === 0)) continue;
        n.factionID = factionID(n.subtype);
        moved++;
    }
    return moved;
}

// Rare and named mobs of tribal races often lack the tribe in their name ("Foulbelly"), but spawn
// among their tribe. After fixFactions, such mobs in a race's general or catch-all faction join the
// tribe that clearly dominates the same-race spawns around them.
const TRIBE_FACTION = /^(Ogre|Troll|Murloc|Harpy|Kobold|Furbolg|Trogg|Naga|Satyr|Quilboar|Centaur), |^Gnoll - /;
const UNTRIBED_FACTION = /^(Ogre|Murloc|Harpy|Kobold|Furbolg|Trogg|Naga|Demon|Monster|Creature|Ambient|Troll, Frostmane|Beast - .*)$/;
const NOT_BY_SPAWN = /zanzil/i;  // Zanzil's followers are their own group in Stranglethorn
const SPAWN_RADIUS = 150, MIN_NEIGHBOURS = 4, MIN_SHARE = 0.75;

// spawns: [{ id, map, x, y }]. Returns the number of NPCs moved.
function assignBySpawns(rows, factionName, spawns) {
    const byID = new Map(rows.map((n) => [n.id, n]));
    const tribeOf = (n) => (n && TRIBE_FACTION.test(factionName.get(n.factionID) || "") ? n.factionID : null);
    const tribeSpawns = spawns.filter((s) => tribeOf(byID.get(s.id)));
    const spawnsOf = new Map();
    for (const s of spawns) {
        if (!spawnsOf.has(s.id)) spawnsOf.set(s.id, []);
        spawnsOf.get(s.id).push(s);
    }

    const moves = [];
    for (const n of rows) {
        if (!TRIBES[n.subtype] || NOT_BY_SPAWN.test(n.name) || !spawnsOf.has(n.id)) continue;
        if (!UNTRIBED_FACTION.test(factionName.get(n.factionID) || "")) continue;
        const votes = new Map();
        let total = 0;
        for (const s of spawnsOf.get(n.id)) {
            for (const t of tribeSpawns) {
                if (t.map !== s.map || Math.hypot(t.x - s.x, t.y - s.y) > SPAWN_RADIUS) continue;
                const neighbour = byID.get(t.id);
                if (neighbour.subtype !== n.subtype) continue;
                votes.set(neighbour.factionID, (votes.get(neighbour.factionID) || 0) + 1);
                total++;
            }
        }
        const [tribe, count] = [...votes].sort((a, b) => b[1] - a[1])[0] || [];
        if (tribe && count >= MIN_NEIGHBOURS && count / total >= MIN_SHARE) moves.push([n, tribe]);
    }
    for (const [n, tribe] of moves) n.factionID = tribe;  // after voting, so moves don't sway each other
    return moves.length;
}

module.exports = { fixFactions, assignBySpawns, groupBeasts, resolveLeaders, resolveRaceLeaders, resolveOverlords };
