// Seeds tools/gear.json: every mint piece sorted into sets and given a role and stats for the ogre run game (pick 3
// on level-up; the picks are these pieces). First pass by rules, meant to be tweaked by hand afterwards.
// You dress the ogre: the hat, outfit and accessory attack, the eyes and mouth are passives with an effect; level-ups
// upgrade a layer (the level stays with the layer when you swap the piece) or offer a new piece for it:
//   accessory   -> the hand weapon (WEAPONS, its kind by what it is)
//   headwear    -> Hat Toss, outfit -> Belly Bump (ATTACKS; the piece picks the variant)
//   eyes, mouth -> a CORNERSTONE (a scaling passive for all attacks: pierce, projectiles, area...; a level raises it)
//   a few hats and accessories are passives instead (trinkets, haircuts): no attack, more stat points
//   skin        -> a character (one starting perk)
//   background  -> a stage (tier by rarity; a set's stage drops that set more often)
// An attack's twist (burn, chill, drain...) comes from the piece's story tags; attacks carry a few stat points too.
// Stats come from the piece's hand-picked story tags (tools/dream/tags-*.js), the hand tables below (dungeon bosses,
// factions, creature kinds) and a small lean by layer; the rarity sets the budget.
// Sets: dungeons (boss hat + outfit + chase items + the dungeon's background), factions, creature kinds, the hunters,
// and themed sets (THEMES below) for the club, gacha and base pieces; the rest are loose.
// Pieces or sets marked "edited": true in gear.json are kept as they are; --reseed starts over.
// Usage: node tools/gear-seed.js [--reseed]
const fs = require("fs");
const path = require("path");
const HERE = __dirname, ROOT = path.join(HERE, "..");
const OUT = path.join(HERE, "gear.json");

// --- The stats, weapon kinds and budgets -----------------------------------------------------------------------------
const STATS = {
  bonk: { name: "Bonk", what: "damage", per: "+5%" },
  belly: { name: "Belly", what: "max health", per: "+10" },
  hide: { name: "Hide", what: "armour (less damage taken)", per: "-1 per hit" },
  snooze: { name: "Snooze", what: "healing over time", per: "+0.2 per second" },
  stomp: { name: "Stomp", what: "move speed", per: "+4%" },
  reach: { name: "Reach", what: "attack area", per: "+5%" },
  fury: { name: "Fury", what: "attack speed (shorter cooldowns)", per: "-3%" },
  lots: { name: "Lots", what: "extra projectiles / hits", per: "+1" },
  sniff: { name: "Sniff", what: "pickup range", per: "+10%" },
  luck: { name: "Luck", what: "rarer picks, crits, better chests", per: "+5%" },
  smarts: { name: "Smarts", what: "experience gained", per: "+5%" },
};
const WEAPONS = {
  swipe: { name: "Swipe", what: "slashes the foes in front of him", dmg: 10, cd: 1.3 },
  chuck: { name: "Chuck", what: "throws it high, it arcs down and goes through foes", dmg: 20, cd: 1.6 },
  smash: { name: "Smash", what: "slams the ground around him, knocks foes back", dmg: 25, cd: 2.5 },
  fore: { name: "Fore!", what: "whacks a ball that bounces between foes and walls", dmg: 12, cd: 1.2 },
  zap: { name: "Zap", what: "a magic bolt at the nearest foe", dmg: 10, cd: 1.0 },
  boom: { name: "Boom", what: "a long straight shot through a whole line of foes", dmg: 18, cd: 2.0 },
  guard: { name: "Guard", what: "circles around him all the time, hitting what it touches; one more each other level", dmg: 8, cd: 3.0 },
  buddy: { name: "Buddy", what: "a pet that runs off and bites foes", dmg: 6, cd: 0.6 },
  spill: { name: "Spill", what: "leaves a puddle that hurts foes standing in it", dmg: 4, cd: 3.0 },
  stink: { name: "Stink", what: "a cloud around him that hurts foes nearby", dmg: 3, cd: 0.5 },
  flick: { name: "Flick", what: "flicks small things where he faces, very fast", dmg: 6, cd: 0.4 },
  // (the Trapper's: lay them while you run, lead the crowd through them)
  plonk: { name: "Plonk", what: "plonks it down behind him as he walks; it goes off when a foe steps on it", dmg: 30, cd: 1.4 },
};
// The other layers' attacks: one family per layer, the piece picks the variant (VARIANT_RULES below).
const ATTACKS = {
  headwear: { name: "Hat Toss", what: "throws his hat, it flies out and comes back like a boomerang, cutting through everything", dmg: 9, cd: 1.5, variants: {
    brim: "light and fast, the brim cuts", heavy: "slow, hits hard and goes through foes", crown: "spins back sparkling, crits more",
    magic: "curves toward foes on its own", bite: "the hat chomps whatever it hits" } },
  outfit: { name: "Belly Bump", what: "a shove all around him that knocks foes back", dmg: 14, cd: 2.2, variants: {
    plain: "a good honest shove", plate: "a small ring that hits very hard", robe: "a wide ring, a bit weaker",
    fluffy: "soft and bouncy, sends foes flying", posh: "foes it hits drop a little extra" } },
};
// Eyes and mouths are the CORNERSTONES (user): the scaling passive the whole build rests on, for all your attacks,
// growing with the slot's level; with two slots you commit to two. Eyes are about aim, mouths about appetite. By id.
// (value: what it gives at Lv 1, then per level - the mockup's CS table does the sums.)
const CORNERSTONES = {
  pierce: { name: "Pierce+", what: "every throw goes through 1 more foe (+1 every 4 levels)" },
  crit: { name: "Crit+", what: "+5% crit chance (+1% a level)" },
  damage: { name: "Damage+", what: "+10% damage (+3% a level)" },
  amount: { name: "Projectiles+", what: "+1 of every attack (more at Lv 7, 14, 20)" },
  luck: { name: "Luck+", what: "rarer cards, a few more crits" },
  drowsy: { name: "Drowsy", what: "hits can make foes sluggish (slow)" },
  armour: { name: "Armour", what: "less damage from every hit" },
  duration: { name: "Lingering", what: "puddles, clouds, burns and slows last longer" },
  cooldown: { name: "Faster", what: "-8% time between attacks (more each level)" },
  area: { name: "Bigger", what: "+10% size and area of everything (+3% a level)" },
  regen: { name: "Regen", what: "heal 1 health a second (more each level)" },
  pickup: { name: "Pickup+", what: "+50% pickup range" },
  xp: { name: "XP+", what: "+10% experience (+2% a level)" },
  greed: { name: "Greed", what: "elites and bosses drop more" },
  revival: { name: "Second Dream", what: "wake up instead of dying, once (twice at Lv 10, three times at Lv 20)" },
  burn: { name: "Burn+", what: "all burning hurts more, and hits can set foes alight" },
  critdmg: { name: "Crit Damage+", what: "+50% crit damage (+5% a level)" },
  thorns: { name: "Thorns", what: "foes that touch you get hurt" },
  flock: { name: "Counting Sheep", what: "every 10 kills a sheep joins your flock (up to 5), soaking up hits" },
};
const CORNERSTONE_OF = {
  single_eye_open: "pierce", bloodshot: "crit", dragon_gaze: "damage", starlit_dreamer: "amount", golden_oracle: "luck",
  dreamy_swirl: "drowsy", fully_asleep: "armour", heavy_bags: "cooldown",
  smug_smile: "damage", mid_yawn: "area", snoring_zzz_bubble: "regen", tiny_snore_bubble: "regen", mouth_hanging_open: "pickup",
  drooling: "pickup", crystal_drool: "xp", sea_dog_grin: "greed", stardust_snore: "revival", ember_yawn: "burn",
  gacha_face_cigar: "duration", gacha_face_pipe: "duration", gacha_face_cigarette: "duration",  // (smoke lingers - user: a cloud was hamfisted)
  gacha_face_handlebar: "critdmg", gacha_face_walrus: "critdmg", gacha_face_pencil: "critdmg", gacha_face_muttonchops: "critdmg", gacha_face_imperial: "critdmg",
  gacha_face_tusk_rings: "thorns",  // (spiky: for running into things with shields up)
  plan_face_baa: "flock",
};
// The on-hit and on-kill effects moved from eyes and mouths into the weapon pivots (Lv 5/10/15): they bend ONE attack.
const PIVOT_EFFECTS = {
  double: { name: "Double Take", what: "this attack sometimes fires twice" },
  focus: { name: "Focus", what: "its first hit on each foe always crits" },
  burninggaze: { name: "Burning Crits", what: "its crits set foes on fire" },
  hypnotize: { name: "Hypnotize", what: "its hits can charm a foe into fighting for you" },
  contagious: { name: "Contagious", what: "its hits can make a group drowsy" },
  hothead: { name: "Hothead", what: "its kills burst into flame" },
  slobber: { name: "Slobber", what: "its kills leave slippery puddles" },
  shootingstar: { name: "Shooting Star", what: "every 25 of its kills a star falls on the biggest crowd" },
  smug: { name: "Smug", what: "its kills speed it up for a moment (stacks)" },
};
const SOFT_GUARDS = new Set(["floating_sheep"]);
// The twist a piece's tags give its attack (first matching tag in this order).
const TWISTS = {
  fire: { name: "Burn", what: "sets foes on fire" }, ice: { name: "Chill", what: "slows foes" },
  fel: { name: "Doom", what: "foes take more damage from everything for a while" }, undead: { name: "Drain", what: "heals you a little per hit" },
  holy: { name: "Bless", what: "kills heal you" }, nature: { name: "Poison", what: "stacking poison" },
  arcane: { name: "Chain", what: "jumps on to a second foe" }, water: { name: "Splash", what: "knocks foes back" },
  tech: { name: "Extra", what: "+1 shot" }, shiny: { name: "Lucky", what: "crits more" },
};
const MAX_LEVEL = 20;  // (a milestone every 5: the slot's attack gets one more)
const TIER = { uncommon: 1, rare: 2, epic: 3, legendary: 4 };
const BUDGET = { uncommon: 1, rare: 2, epic: 2, legendary: 3 };        // stat points an attack carries
const PASSIVE_BUDGET = { uncommon: 3, rare: 4, epic: 5, legendary: 6 }; // a passive: no attack, more stats
const POWER = { uncommon: 1, rare: 1.25, epic: 1.5, legendary: 2 };    // an attack's damage multiplier

// Tag -> stat weights (tags as in tools/dream/piece-tags.js TAG_LIST).
const TAG_STATS = {
  fire: { bonk: 2 }, ice: { hide: 2 }, water: { snooze: 2 }, undead: { belly: 2 }, holy: { snooze: 1, hide: 1 },
  fel: { fury: 2 }, nature: { snooze: 1, reach: 1 }, arcane: { smarts: 2 }, knitted: { belly: 2 }, metal: { hide: 2 },
  shiny: { luck: 2 }, stone: { hide: 1, belly: 1 }, dragon: { bonk: 1, reach: 1 }, beast: { stomp: 1, sniff: 1 },
  pirate: { luck: 1, stomp: 1 }, golf: { reach: 1, sniff: 1 }, sleepy: { snooze: 2 }, royal: { luck: 1, smarts: 1 },
  tech: { fury: 2 }, smelly: { reach: 2 }, tiny: { stomp: 2 }, huge: { bonk: 1, belly: 1 },
};
// A small lean by layer (breaks ties, fills pieces with no tags).
const LAYER_LEAN = {
  headwear: { smarts: 1, reach: 1, sniff: 0.5 }, outfit: { belly: 1, hide: 1, stomp: 0.5 },
  accessory: { luck: 1, sniff: 1 }, eyes: { sniff: 1, smarts: 1, luck: 0.5 }, expression: { snooze: 1, bonk: 1, belly: 0.5 },
};

// --- Hand tables ----------------------------------------------------------------------------------------------------
// Dungeons: set name and the two stats its boss stands for.
const DUNGEONS = {
  rfc: ["Searing Blade", "fury", "bonk"], wc: ["Mutanus", "snooze", "belly"], dm: ["VanCleef", "fury", "luck"],
  sfk: ["Arugal", "fury", "stomp"], bfd: ["Aku'mai", "reach", "snooze"], stocks: ["Bazil Thredd", "luck", "fury"],
  gnomer: ["Thermaplugg", "lots", "hide"], rfk: ["Charlga Razorflank", "hide", "reach"], smgy: ["Bloodmage Thalnos", "smarts", "reach"],
  smlib: ["Arcanist Doan", "smarts", "lots"], smarm: ["Herod", "bonk", "reach"], smcath: ["Whitemane", "snooze", "smarts"],
  rfd: ["Amnennar", "hide", "reach"], ulda: ["Archaedas", "hide", "belly"], zf: ["Ukorz Sandscalp", "bonk", "fury"],
  mara: ["Theradras", "reach", "snooze"], st: ["Eranikus", "snooze", "reach"], brd: ["Thaurissan", "bonk", "luck"],
  lbrs: ["Omokk", "bonk", "belly"], ubrs: ["Drakkisath", "bonk", "hide"], dme: ["Alzzin", "stomp", "fury"],
  dmw: ["Tortheldrin", "smarts", "fury"], dmn: ["King Gordok", "luck", "belly"], scholo: ["Gandling", "smarts", "lots"],
  stratl: ["Balnazzar", "fury", "lots"], stratu: ["Rivendare", "belly", "bonk"], excav: ["Relic Guardian", "hide", "lots"],
  thanes: ["Dirgehammer", "bonk", "hide"], ruins: ["Rath'mael", "smarts", "fury"], barrow: ["Barrow Deeps", "snooze", "luck"],
  hyjal: ["Wild King", "reach", "stomp"], ony: ["Onyxia", "bonk", "reach"],
};
// Factions (by the fac_<key> id part): the two stats.
const FACTIONS = {
  bloodsail: ["luck", "stomp"], burningblade: ["bonk", "fury"], kolkar: ["stomp", "fury"], darkiron: ["hide", "bonk"],
  defias: ["fury", "luck"], blackflight: ["bonk", "reach"], blueflight: ["smarts", "reach"], greenflight: ["snooze", "reach"],
  redflight: ["belly", "snooze"], bronzeflight: ["fury", "smarts"], boulderfist: ["bonk", "belly"], crushridge: ["hide", "belly"],
  deadwind: ["reach", "stomp"], dreadmaul: ["bonk", "fury"], dunemaul: ["stomp", "hide"], dustbelcher: ["sniff", "bonk"],
  firegut: ["bonk", "reach"], gordok: ["luck", "belly"], gordunni: ["smarts", "reach"], mogrosh: ["belly", "bonk"],
  moshogg: ["snooze", "smarts"], spirestone: ["hide", "bonk"], splinterfist: ["fury", "stomp"], urok: ["bonk", "lots"],
  blackrock: ["hide", "bonk"], scarlet: ["snooze", "hide"], syndicate: ["fury", "sniff"], scourge: ["lots", "belly"],
  venture: ["sniff", "luck"],
};
// Creature kinds (by the crit_<key> id part).
const KINDS = {
  bat: ["stomp", "sniff"], bear: ["belly", "bonk"], boar: ["bonk", "stomp"], carrion_bird: ["sniff", "stomp"],
  cat: ["stomp", "fury"], centaur: ["stomp", "reach"], crab: ["hide", "belly"], crocolisk: ["hide", "bonk"],
  demon: ["bonk", "fury"], dragonkin: ["reach", "bonk"], dwarf: ["hide", "belly"], elemental: ["reach", "bonk"],
  furbolg: ["belly", "snooze"], ghost: ["reach", "stomp"], ghoul: ["belly", "fury"], gnoll: ["sniff", "lots"],
  gorilla: ["bonk", "belly"], harpy: ["stomp", "fury"], human: ["smarts", "luck"], hyena: ["sniff", "luck"],
  kobold: ["sniff", "luck"], kodo: ["belly", "hide"], murloc: ["lots", "snooze"], naga: ["reach", "snooze"],
  orc: ["bonk", "hide"], quilboar: ["hide", "bonk"], raptor: ["stomp", "fury"], satyr: ["luck", "fury"],
  scorpid: ["fury", "hide"], skeleton: ["lots", "hide"], spider: ["lots", "sniff"], tallstrider: ["stomp", "sniff"],
  trogg: ["belly", "bonk"], troll: ["snooze", "fury"], turtle: ["hide", "belly"], wolf: ["stomp", "bonk"], zombie: ["belly", "snooze"],
};
// Skins = characters: the starting perk.
const CHARACTERS = {
  moss: ["Plain old ogre: a bit of everything", { bonk: 1, belly: 1, stomp: 1 }],
  mud_brown: ["Thick-skinned", { hide: 3 }], swamp_green: ["Swamp-fed", { snooze: 3 }],
  pale_lavender: ["Bookish", { smarts: 3 }], slate_gray: ["Rock solid", { hide: 2, belly: 2 }],
  sunburnt_red: ["Hot-headed", { bonk: 3 }], celestial_blue: ["Star-touched", { luck: 2, reach: 2 }],
  enchanted_jade: ["Enchanted", { reach: 3, smarts: 1 }], gold: ["Rolling in it", { luck: 3, sniff: 2 }],
  grand_sleepy_pink: ["The Grand Napper", { snooze: 3, belly: 2 }], obsidian_ember: ["Smouldering", { bonk: 3, fury: 2 }],
  sea_cursed_teal: ["Sea-cursed", { stomp: 3, luck: 1 }],
};
// Themed sets for the club, gacha and base pieces (game ids; ids that don't exist are skipped and listed).
const THEMES = [
  ["members", "Members Only", ["membership_card", "blazer_with_club_crest", "loincloth_and_member_sash", "gold_chain", "clubhouse_lounge", "gacha_face_tusk_rings"]],
  ["oldmoney", "Old Money", ["monocle", "tiny_top_hat", "tweed_vest", "shop_bowler_hat", "gacha_acc_diamond_monocle", "gacha_face_handlebar"]],
  ["smoking", "Smoking Room", ["shop_smoking_cap", "shop_smoking_jacket", "gacha_acc_cigar_box", "gacha_acc_whiskey", "gacha_acc_brandy", "gacha_face_cigar", "gacha_face_pipe"]],
  ["blacktie", "Black Tie", ["shop_tuxedo", "shop_champagne_flute", "gacha_outfit_opera_cape", "gacha_acc_tiny_butler", "shop_service_bell", "gacha_face_pencil"]],
  ["founders", "Founders", ["shop_founders_robe", "shop_club_key", "shop_chandelier_crown", "shop_lapdog", "gacha_hair_powdered_wig", "gacha_face_imperial"]],
  ["yacht", "Yacht Club", ["shop_yacht_cap", "shop_yacht_blazer", "gacha_outfit_sailor_stripes"]],
  ["rowing", "Rowing Eight", ["gacha_outfit_rowing_blazer", "gacha_acc_oar", "shop_straw_boater"]],
  ["tennis", "Centre Court", ["shop_tennis_whites", "shop_tennis_racket"]],
  ["cricket", "Cricket Club", ["gacha_head_cricket_cap", "gacha_outfit_cricket_whites", "gacha_acc_cricket_bat", "gacha_outfit_umpire"]],
  ["polo", "Polo Match", ["gacha_head_polo_helmet", "gacha_acc_polo_mallet", "gacha_acc_croquet_mallet"]],
  ["derby", "Derby Day", ["gacha_head_jockey_cap", "gacha_outfit_jockey_silks", "gacha_acc_riding_crop", "gacha_head_fascinator", "gacha_head_ascot_hat"]],
  ["fencing", "Fencing Salle", ["gacha_head_fencing_mask", "gacha_outfit_fencing", "gacha_acc_foil"]],
  ["countryhunt", "Country Hunt", ["gacha_head_deerstalker", "gacha_outfit_hunting_pink", "gacha_acc_falcon", "gacha_acc_peacock", "gacha_face_muttonchops"]],
  ["fishing", "Gone Fishing", ["gacha_head_fishing_hat", "gacha_head_souwester", "gacha_acc_trophy_fish"]],
  ["apresski", "Apres-Ski", ["gacha_head_bobble", "gacha_outfit_parka", "gacha_head_aviator"]],
  ["lowlife", "Lowlife", ["gacha_outfit_sleeping_bag", "gacha_head_bin_lid", "gacha_acc_whiskey_bag", "gacha_acc_pigeon", "gacha_acc_rat", "gacha_outfit_mustard_vest", "gacha_head_traffic_cone", "gacha_head_tinfoil", "gacha_face_walrus", "gacha_head_knockoff_cap", "gacha_acc_knockoff_shades", "gacha_outfit_shellsuit", "gacha_acc_scratchcard", "gacha_acc_ale_can", "gacha_head_ear_cigarette", "gacha_outfit_gravy_vest", "gacha_face_cigarette"]],
  ["caddie", "Caddie", ["shop_caddie_bib", "shop_golf_bag", "shop_gopher", "shop_tam_pompom"]],
  ["golf", "Golf", ["sun_visor", "golf_polo", "shop_flat_cap", "shop_putter", "shop_golf_glove_ball", "golf_course_at_dawn", "shop_argyle_vest", "shop_norfolk_jacket", "shop_loud_windbreaker", "shop_driver", "shop_panama", "moonlit_fairway", "shop_champions_jacket", "shop_trophy_cup", "shop_putting_green_hat", "shop_golfball_hat", "gacha_acc_gilded_club"]],
  ["dragongolf", "Dragon Golf", ["dragonhide_golf_jacket", "dragon_hatchling_hat", "dragon_over_the_fairway"]],
  ["bedtime", "Bedtime", ["nightcap_with_pom_pom", "striped_pajamas", "onesie", "sleep_mask", "fully_asleep", "heavy_bags", "snoring_zzz_bubble", "tiny_snore_bubble", "hammock_between_two_trees"]],
  ["starry", "Starry Night", ["astral_nightcap", "celestial_pajamas", "starlit_dreamer", "dreamy_swirl", "stardust_snore", "moonstone_pendant", "floating_sky_spa"]],
  // (counting sheep to fall asleep: the hat, onesie and Baa mouth are drafts in gen-art-set-gaps.json / gen-face-set-gaps.json)
  ["sheep", "Counting Sheep", ["floating_sheep"]],
  ["royalnap", "Royal Nap", ["crown_of_eternal_rest", "royal_nap_robe", "crystal_drool", "pocket_portal"]],
  ["spa", "Spa Day", ["towel_turban", "spa_towel", "fluffy_bathrobe", "cucumber_slices", "flower_crown", "mid_yawn", "spa_steam_room", "pool_with_floaties"]],
  ["swamp", "Swamp Ogre", ["bucket_hat", "bald_with_fly", "pet_frog", "pet_snail", "drooling", "mouth_hanging_open", "swamp_hot_spring"]],
  // The pirate captain pieces join the Bloodsail crew (one pirate set).
  ["faction:bloodsail", "Bloodsail Buccaneers", ["captain_tricorn", "pirate_captain_coat", "pirate_eyepatch", "sea_dog_grin"]],
  ["ember", "Ember", ["ember_yawn", "phoenix_on_shoulder"]],
  ["gilded", "Gilded", ["golden_oracle", "ancient_treasure_lounge"]],
  ["tracker", "Nesingwary", ["hunt_tracker_head", "hunt_tracker_body", "prop_rares"]],
  ["stalker", "Nathanos", ["hunt_stalker_head", "hunt_stalker_body", "prop_elites"]],
  ["master", "Rexxar", ["hunt_master_head", "hunt_master_body"]],
];

// Weapon kind by what the piece is: the name first, then the start of its art description. Ids override.
const WEAPON_WORDS = [
  ["flick", /\bdagger|scratch ?card|membership card|\bcard\b/i],
  ["guard", /\bshield\b|floating sheep/i],
  ["buddy", /\bpet\b|frog|snail|parrot|falcon|peacock|poodle|gopher|butler|pigeon|\brat\b|phoenix/i],
  ["spill", /whiskey|champagne|brandy|\bale\b|bottle|tumbler|flute|snifter/i],
  ["stink", /cigar|trophy fish|trophy skull/i],
  ["fore", /putter|driver|club\b|mallet|cricket bat|racket|golf (glove|bag)/i],
  ["boom", /\bgun\b|rifle|\bbow\b/i],
  ["zap", /staff|\brod\b|\bbook\b|tome|mirror|portal|\bring\b/i],
  ["smash", /\bmace\b|\bmaul\b|hammer|ironfoe|fist of|\boar\b/i],
  ["chuck", /\baxe\b|ravager|deathbringer/i],
  ["swipe", /sword|blade|scimitar|cleaver|barb|carver|foil|crop|thraze|dal'rend/i],
];
const WEAPON_IDS = { chase_rfk_heart_of_agamaggan: "guard", chase_sfk_meteor_shard: "flick", chase_smgy_torturing_poker: "flick" };
// Mouth items: things worn on the mouth (smokes, moustaches, tusk rings), painted as whole mouths for the per-mouth tusk
// spots but really gear, so they count as set pieces; the other mouths are just his face.
const MOUTH_ITEM = (p) => p.layer === "expression" && /moustache|mutton|tusk|cigar|pipe|cigarette/i.test(p.name);
// Passives: things that can't sensibly attack (you can't throw your haircut or glare with your eyes shut).
const PASSIVE = (p) =>
  (p.layer === "accessory" && /monocle|chain|mask|cucumber|eyepatch|pendant|\bkey\b|\bcup\b|spyglass|shades/i.test(p.name)) ||
  (p.layer === "headwear" && /^gacha_hair_/.test(p.id));
// Variant of a layer attack: by id/name first, then tags, else the layer's first variant.
const VARIANT_RULES = {
  headwear: [["bite", (p, t) => /^crit_/.test(p.id) || (t.has("beast") && /hat|hood/i.test(p.name))], ["heavy", (p, t) => t.has("metal") || t.has("stone") || t.has("huge")],
    ["crown", (p, t) => t.has("royal") || /crown|circlet|tiara/i.test(p.name)], ["magic", (p, t) => ["arcane", "holy", "fel", "undead"].some((x) => t.has(x)) || /hood|cowl/i.test(p.name)]],
  outfit: [["plate", (p, t) => t.has("metal") || t.has("stone") || /plate|armou?r|mail|shell/i.test(p.name)], ["fluffy", (p, t) => t.has("knitted") || /onesie|furs?\b|hide/i.test(p.name)],
    ["robe", (p, t) => /robe|gown|shroud|cape|cloak/i.test(p.name) || ["arcane", "holy", "fel", "undead"].some((x) => t.has(x))], ["posh", (p, t) => t.has("golf") || t.has("royal")]],
};

// --- Load the pieces ------------------------------------------------------------------------------------------------
const pieces = [];
{
  let layer = null;
  for (const line of fs.readFileSync(path.join(ROOT, "MintArt.lua"), "utf8").split(/\r?\n/)) {
    const m = line.match(/^    (\w+) = \{$/);
    if (m) { layer = m[1]; continue; }
    const o = line.match(/\{ id = "([^"]+)", name = "([^"]+)", rarity = "(\w+)"/);
    if (!o || !layer || /retired = true/.test(line)) continue;
    pieces.push({ id: o[1], name: o[2], rarity: o[3], layer, unlock: (line.match(/unlock = "([^"]+)"/) || [])[1] || "" });
  }
}
// Art descriptions (by game id) and the pieces still waiting to be painted or built: the gacha series and the sets'
// accessories (gen-art-set-*.json, which also say their weapon and twist).
const descs = {}, planned = {};
const known = new Set(pieces.map((p) => p.id));
for (const f of fs.readdirSync(HERE).filter((f) => /^gen-(art|face)-.*\.json$/.test(f))) {
  let list;
  try { list = JSON.parse(fs.readFileSync(path.join(HERE, f), "utf8")); } catch { continue; }
  if (!Array.isArray(list)) continue;
  for (const p of list) {
    if (!p || !p.id || !p.desc) continue;
    const id = p.gacha ? "gacha_" + p.id : /gacha/.test(f) ? "gacha_" + p.id : p.id;
    descs[id] = descs[id] || p.desc;
    if (/gacha\d/.test(f) && !/redo/.test(f) && !known.has(id) && p.layer) {
      known.add(id);
      pieces.push({ id, name: p.desc.split(":")[0], rarity: p.rarity, layer: p.layer, unlock: "gacha:1", pending: true });
    }
    if (/^gen-(art|face)-set-/.test(f)) {
      planned[id] = { weapon: p.weapon, twist: p.twist, set: p.set, setName: p.setName };
      if (!known.has(id)) {
        known.add(id);
        pieces.push({ id, name: p.desc.split(":")[0], rarity: p.rarity, layer: p.layer, unlock: p.unlock || "", pending: true });
      }
    }
  }
}
// Story tags.
const TAGS = (() => {
  const dir = path.join(HERE, "dream");
  const files = ["piece-tags.js", ...fs.readdirSync(dir).filter((f) => /^tags-.+\.js$/.test(f)).sort()];
  const src = files.map((f) => fs.readFileSync(path.join(dir, f), "utf8")).join("\n");
  return new Function(src + ";return PIECE_TAGS;")();
})();

// --- Sets -----------------------------------------------------------------------------------------------------------
const byId = Object.fromEntries(pieces.map((p) => [p.id, p]));
const sets = new Map();  // id -> { id, name, kind, pieces: [] }
const addTo = (setId, name, kind, id) => {
  if (!sets.has(setId)) sets.set(setId, { id: setId, name, kind, pieces: [] });
  const s = sets.get(setId);
  if (!s.pieces.includes(id)) s.pieces.push(id);
  byId[id].set = setId;
};
const missingThemeIds = [];
// A faction's key is its pieces' id part (fac_<key>_head, crit_<key>_body for the whelps), so its extras (the parrot) join.
const FAC_KEYS = {};
for (const p of pieces) {
  const m = p.unlock.startsWith("deed:faction:") && p.id.match(/^(?:fac|crit)_(\w+?)_(?:head|body)$/);
  if (m) FAC_KEYS[p.unlock.split(":")[2]] = m[1];
}
const facKey = (name) => FAC_KEYS[name] || name.toLowerCase().replace(/[^a-z]/g, "");
for (const p of pieces) {
  const u = p.unlock;
  let m;
  if (u.startsWith("combine:")) continue;  // below, with their parts
  if ((m = u.match(/^(?:clear|chase):(\w+)/)) || (m = u.match(/^deed:feat:clear:(\w+):/))) {
    addTo("dungeon:" + m[1], (DUNGEONS[m[1]] || [m[1]])[0], "dungeon", p.id);
  } else if (u.startsWith("deed:faction:")) {
    addTo("faction:" + facKey(u.split(":")[2]), u.split(":")[2], "faction", p.id);
  } else if ((m = p.id.match(/^crit_(\w+?)_(head|body|acc)$/))) {
    addTo("creature:" + m[1], u.startsWith("deed:subtype:") ? u.split(":")[2] : m[1], "creature", p.id);
  } else if (u.startsWith("deed:subtype:")) {
    const kind = u.split(":")[2];
    addTo("creature:" + kind.toLowerCase().replace(/[^a-z]/g, ""), kind, "creature", p.id);
  }
}
// Combines join their parts' set.
for (const p of pieces) {
  if (!p.unlock.startsWith("combine:")) continue;
  const part = p.unlock.slice(8).split("+")[0].split(":")[1];
  if (byId[part] && byId[part].set && byId[part].set.startsWith("dungeon:")) addTo(byId[part].set, sets.get(byId[part].set).name, "dungeon", p.id);
  else if (/^crit_bronzeflight_/.test(p.id)) addTo("faction:bronzeflight", "Dragonflight, Bronze", "faction", p.id);
  else addTo("combine:" + p.id, p.name, "combine", p.id);
}
for (const [setId, name, ids] of THEMES) {
  // (a full set id, e.g. "faction:bloodsail", adds the pieces to that set)
  const target = setId.includes(":") ? setId : "theme:" + setId, into = sets.get(target);
  for (const id of ids) {
    if (!byId[id]) { missingThemeIds.push(id); continue; }
    addTo(target, into ? into.name : name, into ? into.kind : "theme", id);
  }
}
// Planned pieces that say which set they fill (gen-art-set-*.json "set").
for (const [id, pl] of Object.entries(planned)) {
  const into = pl.set && sets.get(pl.set);
  if (into) addTo(pl.set, into.name, into.kind, id);
  else if (pl.set && pl.setName) addTo(pl.set, pl.setName, pl.set.split(":")[0], id);  // (a new set: the arcade bosses' "boss:<dungeon>:<boss>")
  else if (pl.set) missingThemeIds.push(pl.set + " (for " + id + ")");
}

// --- Roles and stats ------------------------------------------------------------------------------------------------
const hash = (s) => { let h = 2166136261; for (const c of s) h = Math.imul(h ^ c.charCodeAt(0), 16777619); return (h >>> 0) / 4294967296; };
const weaponKind = (p) => {
  if (WEAPON_IDS[p.id]) return WEAPON_IDS[p.id];
  if (planned[p.id] && planned[p.id].weapon) return planned[p.id].weapon;
  const desc = (descs[p.id] || "").split(":").slice(1).join(":").slice(0, 140);
  for (const text of [p.name, desc]) for (const [kind, re] of WEAPON_WORDS) if (re.test(text)) return kind;
  return null;
};
const variantOf = (p) => {
  const t = new Set(TAGS[p.id] || []);
  for (const [v, test] of VARIANT_RULES[p.layer] || []) if (test(p, t)) return v;
  return Object.keys(ATTACKS[p.layer].variants)[0];
};
const setLean = (p) => {
  const s = p.set || "";
  let m;
  if ((m = s.match(/^(?:dungeon|boss):(\w+)/)) && DUNGEONS[m[1]]) return DUNGEONS[m[1]].slice(1);  // (a boss set leans like its dungeon)
  if ((m = s.match(/^faction:(\w+)/)) && FACTIONS[m[1]]) return FACTIONS[m[1]];
  if ((m = s.match(/^creature:(\w+)/)) && KINDS[m[1]]) return KINDS[m[1]];
  return null;
};
const statsFor = (p, budget) => {
  const w = {};
  const add = (k, v) => { w[k] = (w[k] || 0) + v; };
  for (const t of TAGS[p.id] || []) for (const [k, v] of Object.entries(TAG_STATS[t] || {})) add(k, v);
  const lean = setLean(p);
  if (lean) { add(lean[0], 3); add(lean[1], 2); }
  for (const [k, v] of Object.entries(LAYER_LEAN[p.layer] || {})) add(k, v * 0.5);
  for (const k of Object.keys(w)) w[k] += hash(p.id + k) * 0.3;  // ties
  const order = Object.keys(w).filter((k) => k !== "lots" || TIER[p.rarity] >= 3).sort((a, b) => w[b] - w[a]);
  const split = { 1: [1], 2: [2], 3: [2, 1], 4: [3, 1], 5: [3, 2], 6: [4, 2] }[budget[p.rarity] || 1];
  const out = {};
  order.slice(0, split.length).forEach((k, i) => { out[k] = k === "lots" ? 1 : split[i]; });
  return out;
};
const twistOf = (p) => {
  if (planned[p.id] && planned[p.id].twist) return planned[p.id].twist;
  const t = new Set(TAGS[p.id] || []);
  return Object.keys(TWISTS).find((k) => t.has(k));
};

const gear = {};
for (const p of pieces) {
  const g = { name: p.name, layer: p.layer, rarity: p.rarity, set: p.set || null };
  if (p.pending) g.pending = true;
  if (p.layer === "skin") {
    g.role = "character";
    const c = CHARACTERS[p.id] || ["", { bonk: 1 }];
    g.perk = c[0]; g.stats = c[1];
  } else if (p.layer === "background") {
    g.role = "stage";
    g.tier = TIER[p.rarity];
    const d = (p.set || "").match(/^dungeon:(\w+)/);
    if (d) g.foes = d[1];
  } else if (p.layer === "eyes" || p.layer === "expression") {
    // the effect is their power, so only an attack's few stat points
    g.role = "passive";
    if (CORNERSTONE_OF[p.id]) g.cornerstone = CORNERSTONE_OF[p.id];
    g.stats = statsFor(p, BUDGET);
  } else if (PASSIVE(p) || (p.layer === "accessory" && !weaponKind(p))) {
    g.role = "passive";
    g.stats = statsFor(p, PASSIVE_BUDGET);
  } else {
    g.role = "attack";
    if (p.layer === "accessory") g.weapon = weaponKind(p);
    else g.attack = variantOf(p);
    // (soft guards - sheep - don't hit: each soaks up one hit for you, then grows its wool back)
    if (g.weapon === "guard" && SOFT_GUARDS.has(p.id)) g.soft = true;
    g.power = POWER[p.rarity];
    const tw = twistOf(p);
    if (tw) g.twist = tw;
    g.stats = statsFor(p, BUDGET);
  }
  if (MOUTH_ITEM(p)) g.item = true;
  gear[p.id] = g;
}

// --- Merge with hand edits ------------------------------------------------------------------------------------------
// Edited pieces (tools/gear-editor.js) are kept as they are; edited sets keep their name, pieces and wanted list (and
// their bonuses too when "bonusesEdited"), their pieces leave the seeded sets; a "deleted" set stays deleted.
const reseed = process.argv.includes("--reseed");
let old = { pieces: {}, sets: [] };
if (!reseed && fs.existsSync(OUT)) old = JSON.parse(fs.readFileSync(OUT, "utf8"));
for (const [id, g] of Object.entries(old.pieces || {})) if (g.edited && gear[id]) gear[id] = g;
let setList = [...sets.values()].map((s) => ({ id: s.id, name: s.name, kind: s.kind, pieces: s.pieces }));
const editedSets = (old.sets || []).filter((s) => s.edited);
const claimed = new Set(editedSets.flatMap((s) => s.deleted ? [] : s.pieces));
setList = setList.map((s) => ({ ...s, pieces: s.pieces.filter((id) => !claimed.has(id)) }));
for (const e of editedSets) {
  const s = { ...e, pieces: (e.pieces || []).filter((id) => gear[id]) };
  const i = setList.findIndex((x) => x.id === s.id);
  if (i >= 0) setList[i] = s; else setList.push(s);
}
for (const g of Object.values(gear)) g.set = null;
for (const s of setList) if (!s.deleted) for (const id of s.pieces) gear[id].set = s.id;

// --- Set bonuses ----------------------------------------------------------------------------------------------------
// Set pieces are the hat, outfit and accessory (a set may have several on a layer: any of them counts), plus a mouth
// item ("item": cigar, moustache...) as a 4th; eyes, plain mouths and stages can go with a set's theme but don't count.
const CORE = new Set(["headwear", "outfit", "accessory"]);
// Sets whose full bonus is regeneration (a share of max health back each second, double below half health) instead of
// stats: trolls regenerate (for the run-into-them shield build).
const REGEN_SETS = { "creature:troll": "Troll Regeneration" };
// Sets whose full bonus is something of their own: the shepherd's sheep grow their wool back twice as fast.
const SPECIAL_SETS = { "theme:sheep": { fluff: 2, name: "Shepherd" } };
const isSetPiece = (g) => CORE.has(g.layer) || (g.layer === "expression" && g.item);
const unlockOf = (id) => (byId[id] && byId[id].unlock) || "";
for (const g of Object.values(gear)) if (g.role === "stage") delete g.drops;
for (const s of setList) {
  if (s.deleted) continue;
  const stage = s.pieces.find((id) => gear[id].role === "stage");
  if (stage) gear[stage].drops = s.id;
  if (s.bonusesEdited) continue;
  const own = s.pieces.filter((id) => isSetPiece(gear[id]));
  const total = {};
  for (const id of own) for (const [k, v] of Object.entries(gear[id].stats || {})) total[k] = (total[k] || 0) + v;
  const lean = setLean({ set: s.id }) || [];
  const main = Object.keys(total).sort((a, b) => total[b] - total[a]);
  const first = lean[0] || main[0] || "luck", second = (lean[1] !== first && lean[1]) || main.find((k) => k !== first) || "belly";
  const bonuses = [];
  // One piece per layer is worn, so a set counts the set layers it covers ("at" = that many worn; any 3 = the full set, so a set with a mouth item has a spare).
  const n = new Set(own.map((id) => gear[id].layer)).size;
  if (n >= 2) bonuses.push({ at: 2, stats: { [first]: first === "lots" ? 1 : 2 } });
  if (s.kind === "creature" && n >= 2) bonuses.push({ at: 2, look: "hooded onesie", vs: s.name, dmg: 25 });
  if (s.kind === "faction" && n >= 2) bonuses.push({ at: 2, vs: s.name, dmg: 25 });
  if (s.kind === "dungeon") {
    // Evolution: the set's chase piece (or the union of two) at max level, worn with the set's pieces on the other layers.
    const chase = own.filter((id) => /^(chase|combine):/.test(unlockOf(id)) && gear[id].role === "attack");
    const union = chase.find((id) => unlockOf(id).startsWith("combine:"));
    const top = union || chase.sort((a, b) => (gear[b].layer === "accessory") - (gear[a].layer === "accessory") || TIER[gear[b].rarity] - TIER[gear[a].rarity])[0];
    // ...one per layer (Stratholme has two hats and two outfits: the rarer of each).
    const wear = !top ? [] : ["headwear", "outfit"].filter((l) => l !== gear[top].layer).map((l) => own
      .filter((id) => gear[id].layer === l && !unlockOf(id).startsWith("chase:"))
      .sort((a, b) => TIER[gear[b].rarity] - TIER[gear[a].rarity])[0]).filter(Boolean);
    const old = (s.bonuses || []).find((b) => b.evolve && b.evolve.piece === top);
    if (top && wear.length) bonuses.push({ at: 1 + wear.length, evolve: { piece: top, maxLevel: true, with: wear, into: old ? old.evolve.into : null } });
    else if (n >= 3) bonuses.push({ at: 3, stats: { [second]: 3, lots: 1 } });
    for (const id of own.filter((id) => unlockOf(id).startsWith("combine:"))) {
      bonuses.push({ union: { from: unlockOf(id).slice(8).split("+").map((x) => x.split(":")[1]), into: id } });
    }
  } else if (REGEN_SETS[s.id] && n >= 3) bonuses.push({ at: 3, regen: 1.5, name: REGEN_SETS[s.id] });
  else if (SPECIAL_SETS[s.id] && n >= 3) bonuses.push({ at: 3, ...SPECIAL_SETS[s.id] });
  else if (n >= 3) bonuses.push({ at: 3, stats: { [second]: 3, [first]: 1 } });
  s.bonuses = bonuses;
}
const KIND_ORDER = { dungeon: 0, boss: 1, faction: 2, creature: 3, theme: 4, combine: 5 };
setList.sort((a, b) => (KIND_ORDER[a.kind] ?? 9) - (KIND_ORDER[b.kind] ?? 9) || a.name.localeCompare(b.name));

// --- Write ----------------------------------------------------------------------------------------------------------
const doc = {
  _: "Sets, roles and stats of the mint pieces for the ogre run game. Seeded by tools/gear-seed.js, edited in tools/gear-editor.js (pieces and sets marked \"edited\": true keep hand changes when reseeding).",
  stats: STATS, weapons: WEAPONS, attacks: ATTACKS, twists: TWISTS, cornerstones: CORNERSTONES, pivotEffects: PIVOT_EFFECTS,
  rules: { maxLevel: MAX_LEVEL, attackStats: BUDGET, passiveStats: PASSIVE_BUDGET, power: POWER },
  sets: setList,
  pieces: gear,
};
// One line per stat, weapon, set and piece, so the file diffs and reads well.
const block = (obj, arr) => (arr ? "[\n" : "{\n") + Object.entries(obj).map(([k, v]) => "  " + (arr ? "" : JSON.stringify(k) + ": ") + JSON.stringify(v)).join(",\n") + (arr ? "\n ]" : "\n }");
fs.writeFileSync(OUT, "{\n" + Object.entries(doc).map(([k, v]) => ` ${JSON.stringify(k)}: ` +
  (k === "sets" ? block(v, true) : typeof v === "object" && Object.values(v).some((x) => typeof x === "object") ? block(v) : JSON.stringify(v))).join(",\n") + "\n}\n");

// --- Report ---------------------------------------------------------------------------------------------------------
const count = (f) => Object.values(gear).filter(f).length;
const roles = {};
for (const g of Object.values(gear)) roles[g.role] = (roles[g.role] || 0) + 1;
console.log(`${pieces.length} pieces (${count((g) => g.pending)} not built yet): ` + Object.entries(roles).map(([k, v]) => `${v} ${k}s`).join(", "));
const kinds = {};
for (const s of setList) kinds[s.kind] = (kinds[s.kind] || 0) + 1;
console.log(`${setList.length} sets: ` + Object.entries(kinds).map(([k, v]) => `${v} ${k}`).join(", ") + `; ${count((g) => !g.set)} loose pieces`);
const tally = (key) => { const t = {}; for (const g of Object.values(gear)) if (key(g)) t[key(g)] = (t[key(g)] || 0) + 1; return Object.entries(t).map(([k, v]) => `${k} ${v}`).join(", "); };
console.log("weapons: " + tally((g) => g.weapon));
for (const layer of Object.keys(ATTACKS)) console.log(`${ATTACKS[layer].name}: ` + tally((g) => g.layer === layer && g.attack) + `; passive ${count((g) => g.layer === layer && g.role === "passive")}`);
console.log("twists: " + tally((g) => g.twist) + `; none ${count((g) => g.role === "attack" && !g.twist)}`);
const st = {};
for (const g of Object.values(gear)) if (g.role === "passive" || g.role === "attack") for (const [k, v] of Object.entries(g.stats)) st[k] = (st[k] || 0) + v;
console.log("stat points: " + Object.entries(st).sort((a, b) => b[1] - a[1]).map(([k, v]) => `${k} ${v}`).join(", "));
if (missingThemeIds.length) console.log("THEME IDS NOT FOUND: " + missingThemeIds.join(", "));
const noTags = pieces.filter((p) => !TAGS[p.id] && !p.pending && p.layer !== "skin" && p.layer !== "background").map((p) => p.id);
if (noTags.length) console.log(`no story tags (layer lean only): ${noTags.length} - ` + noTags.slice(0, 15).join(", ") + (noTags.length > 15 ? " ..." : ""));
console.log("wrote " + path.relative(ROOT, OUT));
