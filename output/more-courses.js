// One-off (2026-11-05): a golf course for every other zone (35 Classic + Forever's Riverglades and Mount Hyjal), each
// unlocked by exploring its zone fully (Achievements.lua's EXPLORE: its map pieces from the game data,
// output/explore/arts.txt). Appended to tools/gen-art-zone-courses.json (painted by gen-art.js --queue) and the deeds'
// list in Achievements.lua.
const fs = require("fs");
const path = require("path");
process.chdir(path.join(__dirname, ".."));
const EX = ["--examples", "Background/Uncommon/golf-course-at-dawn.png,Background/Uncommon/moonlit-fairway.png,Background/Legendary/dragon-over-the-fairway.png"];
// [key, zone, uiMap, pieces, rarity, deed, course description] - Alliance zones first (the queue paints in order)
const Z = [
  ["lochmodan", "Loch Modan", 1432, 11, "uncommon", "Dam Fine Round", "Loch Modan Links: a green course on rolling hills beside the deep blue loch, the huge stone Stonewrought Dam as a backdrop, a dwarven stone clubhouse with a chimney, a trogg peeking out of a cave in the rough, a ram grazing on the fairway, crisp mountain air"],
  ["teldrassil", "Teldrassil", 1438, 11, "uncommon", "Leaf Peeper", "Teldrassil Course: a soft green course in a twilight purple-blue night elf forest on the World Tree, giant glowing trees, moonwells as water hazards, graceful elven arches, glowing wisps floating over the green, a curious nightsaber cub batting at the flag, dreamy violet light"],
  ["darkshore", "Darkshore", 1439, 9, "uncommon", "Moonlit Beachcomber", "Darkshore Course: a seaside course on a misty night-blue shore, fairways of dark grass between grey sand dunes and old elven ruins, the sea as the water hazard, a huge stranded sea creature skeleton on the beach, a murloc chasing a golf ball, a big pale moon"],
  ["duskwood", "Duskwood", 1431, 13, "rare", "Spooky Back Nine", "Duskwood Night Course: a spooky dark-green course in a gloomy forest at night, twisted black trees, a crooked graveyard behind the green, Darkshire's lamplit houses and clock tower, a worgen silhouette howling on a hill, a skeleton caddie holding the flag, purple fog, a full moon"],
  ["wetlands", "Wetlands", 1437, 15, "rare", "Bog Standard Golfer", "Wetlands Course: a soggy green course in misty marshes, fairways between reeds and muddy pools, a crocolisk sunning on the green, the ruined dwarven fortress Grim Batol on a cliff far away, Menethil Harbor's boats in the mist, grey drizzly light"],
  ["hillsbrad", "Hillsbrad Foothills", 1424, 12, "rare", "Hillsbrad Hacker", "Hillsbrad Foothills Course: a pleasant green course on gentle hills with apple orchards, the farming town of Southshore with its little houses and fields, Durnholde Keep on a hill in the distance, a sheep wandering onto the fairway, fresh breezy spring light"],
  ["arathi", "Arathi Highlands", 1417, 16, "rare", "Highland Fling", "Arathi Highlands Course: a windswept course on broad golden-green highlands, standing stone circles and ruined towers, the walls of Stromgarde far off, a raptor peeking over a rock, big rolling clouds, late afternoon light"],
  ["alterac", "Alterac Mountains", 1416, 15, "rare", "Peak Performance", "Alterac Mountains Course: a SNOWY high mountain course, fairways of packed snow between pine trees and craggy grey peaks, a ruined castle of Alterac on a cliff, a yeti caddie carrying the golf bag, cold blue light"],
  ["badlands", "Badlands", 1418, 14, "rare", "Dust Bowl", "Badlands Course: a dry orange DESERT course of cracked red earth and sand traps everywhere, rocky mesas, huge dragon bones half buried in the dust, a putting green of rough dry turf with the red flag, a buzzard watching from a dead tree, harsh hot sun"],
  ["swamp", "Swamp of Sorrows", 1435, 11, "rare", "Sorry State", "Swamp of Sorrows Course: a gloomy green swamp course, fairways of mossy turf between murky pools and giant hanging willows, the sunken temple of Atal'Hakkar's stones rising from the water, a sad dragonkin whelp sulking on the green, dim teal light"],
  ["stranglethorn", "Stranglethorn Vale", 1434, 27, "rare", "Jungle Gym", "Stranglethorn Vale Course: a lush JUNGLE course, bright green fairways between giant palms and ferns, ancient troll ruins with stone heads, a raptor in the rough, a waterfall as the water hazard, the goblin port of Booty Bay's wooden buildings on the coast, steamy tropical sun"],
  ["riverglades", "Riverglades", 2548, 14, "rare", "Glade Runner", "Riverglades Course: a wide green river valley course with lazy winding rivers and reedy glades as water hazards, wooden horse ranches and paddocks of the Brotherhood of the Horse, a busy goblin river port with smoking chimneys and cranes, a rough dark stronghold on a far hill, horses grazing by the green, warm golden light"],
  ["tirisfal", "Tirisfal Glades", 1420, 17, "uncommon", "Grave Lie", "Tirisfal Glades Course: an eerie course of sickly yellow-green grass under a grey-green sky, dead twisted trees, crumbling crypts and graveyards, the ruined towers of Lordaeron far off, a zombie groundskeeper raking a bunker, gloomy light"],
  ["silverpine", "Silverpine Forest", 1421, 15, "uncommon", "Pine Needler", "Silverpine Forest Course: a misty dark-green course among tall grey-green pines, a rocky lakeshore as the water hazard, an old wooden farmhouse, a worgen peeking between the trees, foggy cool light"],
  ["durotar", "Durotar", 1411, 11, "uncommon", "Red Dirt Rumble", "Durotar Course: a hot RED-DIRT desert course, the fairway of dusty orange earth with tufts of dry grass, spiky orcish fences and huts, a boar trotting across the green, scorpions in the bunker, the spiked walls of Orgrimmar far off, blazing sun"],
  ["mulgore", "Mulgore", 1412, 16, "uncommon", "Moo-ving Up", "Mulgore Course: a peaceful course on endless rolling green plains of tall grass, tauren tents and totems, the high mesas of Thunder Bluff on the horizon, a herd of kodos grazing near the green, plainstriders on the fairway, wide sunny blue sky"],
  ["barrens", "The Barrens", 1413, 25, "uncommon", "Barren Fairways", "The Barrens Course: a vast dry savanna course of golden-brown grass, flat-topped acacia trees, termite mounds, a giraffe-like tallstrider wandering across, a zeppelin floating above, the Crossroads' tents far off, hot dusty sun"],
  ["ashenvale", "Ashenvale", 1440, 18, "rare", "Ashes To Ashenvale", "Ashenvale Course: a lush deep-green course in an ancient purple-tinted night elf forest, enormous trees, glowing moonwells, elven ruins with curved roofs, a furbolg caddie, soft magical light through the canopy"],
  ["stonetalon", "Stonetalon Mountains", 1442, 11, "rare", "Talon Clipper", "Stonetalon Mountains Course: a rugged course of brown and grey stone, greens perched on rocky ledges, a burned stump-filled valley on one side, a goblin logging machine smoking far off, a harpy perched on the flag, mountain wind"],
  ["desolace", "Desolace", 1443, 15, "rare", "Desolate Driver", "Desolace Course: a bleak GREY wasteland course of ash-grey dirt and cracked stone, huge ancient bones and skulls sticking out of the ground, centaur tents, a kodo graveyard, a lone kodo on the fairway, pale washed-out sky"],
  ["dustwallow", "Dustwallow Marsh", 1445, 7, "rare", "Marsh Mellow", "Dustwallow Marsh Course: a hazy green swamp course, mossy fairways between murky pools and gnarled trees, Theramore's stone harbour castle on the coast, a black dragon whelp peeking from the reeds, warm humid light"],
  ["feralas", "Feralas", 1444, 16, "epic", "Feral Ogre", "Feralas Course: a lush rainforest course of deep green, giant ancient trees and ferns, crumbling elven ruins overgrown with vines, ogres lounging in the rough (friendly ones), a misty waterfall, rich green light"],
  ["tanaris", "Tanaris", 1446, 20, "epic", "Sand In Everything", "Tanaris Course: a SAND golf course in a golden desert: the fairway is raked smooth sand, the green a small patch of turf at an oasis with palms, the goblin town of Gadgetzan's walls and water tower, a giant sand worm peeking out of a bunker, blazing sun"],
  ["hinterlands", "The Hinterlands", 1425, 14, "epic", "Hinter No More", "The Hinterlands Course: a grand green course on high forested hills, troll ruins with big stone faces, a gryphon soaring overhead from Aerie Peak's mountain nest, a wildhammer dwarf caddie, bright clear light"],
  ["searing", "Searing Gorge", 1427, 7, "epic", "Searing Success", "Searing Gorge Course: a scorched course of black rock and red-hot cracks, lava rivers as water hazards, the green a patch of ashy turf with the flag, dark iron dwarf mining machines, smoke and embers, a fiery orange sky"],
  ["burning", "Burning Steppes", 1428, 10, "epic", "Steppe Up", "Burning Steppes Course: a hellish course of blackened earth and glowing lava pools, burning trees, Blackrock Mountain's giant peak in the background, a little black dragon whelp chasing the ball, ash falling from a red sky"],
  ["azshara", "Azshara", 1447, 19, "epic", "Azshara's Leftovers", "Azshara Course: an autumn course of red, orange and gold trees on coastal cliffs, grand elven ruins and broken columns, the sea crashing below, a naga peeking from the water hazard, golden autumn light"],
  ["felwood", "Felwood", 1448, 12, "epic", "Fel Swoop", "Felwood Course: a corrupted dark course of sickly green grass, twisted black trees and glowing green fel pools as water hazards, a satyr skulking in the rough, an eerie green glow under dark clouds"],
  ["ungoro", "Un'Goro Crater", 1449, 7, "epic", "Crater Raider", "Un'Goro Crater Course: a prehistoric JUNGLE course in a huge crater, giant ferns and mushrooms, a steaming volcano, glowing crystals, a big dinosaur devilsaur stomping across the far fairway, little raptors on the green, steamy golden light"],
  ["blasted", "Blasted Lands", 1419, 9, "epic", "Blasted Them", "Blasted Lands Course: a cracked RED wasteland course, scorched red earth and dead spiky plants, the giant swirling Dark Portal far off, a little demon imp holding the flag, a stormy red sky"],
  ["wpl", "Western Plaguelands", 1422, 13, "epic", "Plague Doctor", "Western Plaguelands Course: a once-pretty farmland course gone grim, sickly grass, abandoned farms and a broken windmill, a scarecrow on the green, skeletal crows, the Bulwark's walls far off, grey sickly light"],
  ["hyjal", "Mount Hyjal", 2482, 9, "epic", "Branch Manager", "Mount Hyjal Course: a magnificent green course on a mountain forest slope, the colossal World Tree Nordrassil towering into the sky, ancient trees with silver and violet leaves, night elf shrines, a glowing wisp near the hole, a peaceful twilight sky with stars"],
  ["epl", "Eastern Plaguelands", 1423, 23, "legendary", "Plague Doctor, Again", "Eastern Plaguelands Course: a haunted course of dead grey grass under a purple-green sky, a floating necropolis in the clouds, ruined chapels, the silver-roofed Light's Hope Chapel far off, a ghoul greenkeeper, eerie light"],
  ["winterspring", "Winterspring", 1452, 13, "legendary", "Winter Is Over", "Winterspring Course: a beautiful SNOW course: fairways of smooth glittering snow, blue-white pines heavy with snow, frozen hot springs steaming, a furry white yeti caddie, a frostsaber on a snowy ridge, the aurora dancing over a pale blue sky"],
  ["silithus", "Silithus", 1451, 7, "legendary", "Bug Hunt", "Silithus Course: an alien yellow DESERT course of sand and strange hives, giant bug mounds and crystal formations, a huge silithid bug peeking from a bunker, the old Cenarion Hold's huts, a hot hazy yellow sky"],
  ["deadwind", "Deadwind Pass", 1430, 3, "legendary", "Haunted Hole In One", "Deadwind Pass Course: a dead grey mountain course of withered grass and bare rocks, the dark tower of Karazhan looming in the background, ghostly lights in its windows, a spectral caddie, storm clouds and lightning"],
  ["moonglade", "Moonglade", 1450, 1, "legendary", "Moonwalker", "Moonglade Course: a serene, magical green course in a hidden valley ringed by mountains, a calm lake reflecting the moon, little druid huts and owlbeasts, glowing flowers, soft silver moonlight"],
];
const list = JSON.parse(fs.readFileSync("tools/gen-art-zone-courses.json", "utf8"));
for (const [k, zone, map, pieces, rarity, deed, desc] of Z) {
  const id = "zone_" + k;
  if (list.some((c) => c.id === id)) continue;
  list.push({ layer: "background", id, rarity, explore: zone, desc, flags: EX, unlock: `deed:feat:explore:${k}:${pieces}` });
}
fs.writeFileSync("tools/gen-art-zone-courses.json", JSON.stringify(list, null, 1));

// The deeds: added to Achievements.lua's EXPLORE list.
let s = fs.readFileSync("Achievements.lua", "utf8");
const nl = s.includes("\r\n") ? "\r\n" : "\n";
const end = s.indexOf(`${nl}}${nl}local function Explored(uiMap)`);
if (end < 0) throw Error("EXPLORE not found");
const rows = Z.filter(([k]) => !s.includes(`{ "${k}",`)).map(([k, zone, map, pieces, , deed]) =>
  `    { "${k}", "${zone.replace(/"/g, '\\"')}", ${map}, ${pieces}, "${deed.replace(/"/g, '\\"')}" },`);
s = s.slice(0, end) + nl + rows.join(nl) + s.slice(end);
fs.writeFileSync("Achievements.lua", s);
console.log(`${Z.length} zones; ${rows.length} deeds added; queue has ${list.length} courses`);
