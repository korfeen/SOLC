// Hand-picked tags for every mint piece, by option id: what the piece IS, so the storyteller can pick lines that fit
// (the dreamer's lines, reactions, nonsense endings and TAG_ENDS need a tag). 1-3 tags a piece, only ones that are
// plainly true when you look at it; [] when none fits. The tags live in tags-*.js (one file per group of pieces):
//   Object.assign(PIECE_TAGS, { "crit_murloc_body": ["knitted", "beast", "water"], ... });
// The build stops a tag that isn't in TAG_LIST, and lists pieces with no entry.
const TAG_LIST = {
  // Elements and powers
  fire: "on fire, smouldering, lava, embers, fire magic",
  ice: "frozen, frosty, snow, cold",
  water: "wet, sea, swamp, pool, fish and sea creatures",
  undead: "skeletons, ghosts, ghouls, the Scourge, death",
  holy: "the Light, priests, the Scarlet Crusade, churches",
  fel: "demons, satyrs, fel green fire, warlocks",
  nature: "plants, vines, leaves, flowers, druids, forests",
  arcane: "magic runes, wizards, glowing magic, the stars and cosmos",
  // What it's made of
  knitted: "soft and homemade: knitted, felt, fleece, plush, quilted, cardboard costumes",
  metal: "armour or gear that clanks: plate, chainmail, iron, helmets",
  shiny: "sparkles: sequins, gold, gems, crystals, glitter",
  stone: "made of stone or rock, titan stonework, statues",
  // Themes
  dragon: "dragons, whelps, dragonkin, dragon scales",
  beast: "an animal or creature: costumes of one, fur, pelts, pets",
  pirate: "pirates, ships, parrots, eyepatches, the sea life",
  golf: "the golf club life: golf, the clubhouse, spa, membership, posh leisure",
  sleepy: "sleep, naps, pyjamas, nightcaps, yawns, dreams, hammocks",
  royal: "kings, queens, crowns, thrones, royal guards, emperors",
  tech: "gnome and goblin machines, gadgets, buttons, engineering, mining gear",
  // Odd ones
  smelly: "dirty, sooty, swampy, sweaty, plainly smells",
  tiny: "too small for him (a tiny top hat, a little dwarf helmet)",
  huge: "too big, enormous (giant antlers, huge pauldrons, a crown that slips)",
  // Places only: the time of day the place is set at (picks the dream's opener)
  morning: "dawn, sunrise, early morning",
  night: "night, moon, midnight, dusk, the starry sky",
};
const PIECE_TAGS = {};
