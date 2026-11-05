// The arcade's mobs (SOLC Survivors): every dungeon's real mobs (Questie's classicNpcDB lists, 2026-10-28), each with
// a costume and a SIGNATURE - its own way to fight, inside a family (caster, healer, runner, brute, floor, bomber,
// swarm, trick). No two mobs play the same. Signatures are built on shared attack VERBS (bolt, lob, cone, trail...)
// so the same code can later drive our own weapons and pivots.
//   node tools/arcade-mobs.js      -> writes "mobs" per stage + "signatures" into tools/arcade-stages.json, and sets
//                                     each stage's "foes" (the costumes to load: a missing costume borrows its fallback)
// Costume = a creature kind (crit_<k>_head/_body/_suit) or a faction (fac_<k>_head/_body). NEW = not painted yet.
const fs = require("fs"), path = require("path");

// Costumes we don't have yet, and what they borrow until they're painted. NEW = to paint (no stand-in reads right);
// LATER = would be nice, but the stand-in works (some with a colour tint drawn by code: the 4th field of a mob).
// (looked through 2026-10-28: worgen = our wolf hood; cultist, dryad and robot mobs swapped for ones we have)
const NEW = { alarmbomb: "dwarf", lepergnome: "dwarf", ooze: "elemental", plant: "elemental", snake: "naga", golem: "elemental" };
const LATER = { basilisk: "crocolisk", abomination: "zombie", gargoyle: "bat" };
const BORROW = { ...NEW, ...LATER };

// The signatures: family, the shared verb it's built on, and what it does.
const SIGS = {
  // casters: keep their distance and shoot
  frostbolt:   { family: "caster", verb: "bolt", what: "a slow bolt; a hit slows you" },
  bomblob:     { family: "caster", verb: "lob", what: "lobs a bomb at a red circle where you stand" },
  snipe:       { family: "caster", verb: "snipe", what: "a red laser line, then a fast shot down it" },
  axeboomerang:{ family: "caster", verb: "boomerang", what: "throws an axe that flies past you and comes back" },
  waterbolt:   { family: "caster", verb: "bolt", what: "a water bolt that knocks you back" },
  missiles:    { family: "caster", verb: "volley", what: "three small arcane missiles, one after another" },
  shadowcurse: { family: "caster", verb: "bolt", what: "a shadow bolt; a hit curses you (half speed a while)" },
  summonimp:   { family: "caster", verb: "summon", what: "keeps calling imps that run at you throwing firebolts" },
  poisonspit:  { family: "caster", verb: "bolt", what: "spits poison: a hit poisons you (damage over time)" },
  shapeshift:  { family: "caster", verb: "bolt", what: "lightning bolts; at half health turns into a fast snake" },
  earthspikes: { family: "caster", verb: "below", what: "a circle under you, then spikes burst up out of it" },
  blizzard:    { family: "caster", verb: "rain", what: "a field of falling ice: slows you while you're in it" },
  hex:         { family: "caster", verb: "bolt", what: "hex: a hit turns you into a frog for 2 s (slow, no attacks)" },
  drainlife:   { family: "caster", verb: "beam", what: "a beam on you that heals it while it drains you; break line behind a pillar" },
  arcanebomb:  { family: "caster", verb: "mark", what: "marks you; in 3 s the mark blows up round you" },
  firewall:    { family: "caster", verb: "wall", what: "a line of fire across the floor that cuts the room" },
  volleyfan:   { family: "caster", verb: "volley", what: "a fan of five shadow bolts" },
  rainoffire:  { family: "caster", verb: "rain", what: "fire circles fall at random round you" },
  chainbolt:   { family: "caster", verb: "bolt", what: "a bolt that jumps on to you from foe to foe" },
  blinkfire:   { family: "caster", verb: "bolt", what: "blinks to a new spot, then a big fireball" },
  corpseboom:  { family: "caster", verb: "mark", what: "makes a corpse near you blow up" },
  silence:     { family: "caster", verb: "mark", what: "silence: your attacks stop for 1.5 s, and it splits into mirror images" },
  holynova:    { family: "healer", verb: "nova", what: "holy nova: heals foes round it and hurts you if close" },
  // healers: keep the others going (kill them first)
  healbeam:    { family: "healer", verb: "beam", what: "follows you, stops now and then to heal the boss (Moira, a boss partner)" },
  deathcoil:   { family: "caster", verb: "bolt", what: "a death coil: hurts you, heals the undead it flies past" },
  beastcall:   { family: "healer", verb: "summon", what: "whistles: boars come charging in from the edge" },
  divineshield:{ family: "healer", verb: "buff", what: "when low: a bubble (can't be hurt) while it heals itself up" },
  pileon:      { family: "runner", verb: "dash", what: "the more ghouls close together, the faster they all go" },
  flamebreath: { family: "floor", verb: "cone", what: "fire breath cone that leaves the floor burning" },
  trample:     { family: "runner", verb: "circle", what: "runs circles round you, tighter and tighter" },
  wrenchbounce:{ family: "caster", verb: "bolt", what: "throws wrenches that bounce off pillars and walls" },
  minecart:    { family: "runner", verb: "lane", what: "rides a minecart down a lane across the room" },
  burnbrand:   { family: "brute", verb: "touch", what: "a branding hit: sets you burning a while" },
  shieldally:  { family: "healer", verb: "buff", what: "puts a shield on a friend: can't be hurt for 3 s" },
  healtotem:   { family: "healer", verb: "plonk", what: "plants a healing ward that heals foes round it; break the ward" },
  healwave:    { family: "healer", verb: "beam", what: "a big heal on the most hurt foe nearby" },
  bonearmor:   { family: "healer", verb: "buff", what: "bone armor on the undead round it: half damage" },
  repairbots:  { family: "healer", verb: "beam", what: "repairs robots: mechanical foes near it heal" },
  bloodlust:   { family: "healer", verb: "buff", what: "bloodlust on its own kind: faster and fiercer" },
  warcry:      { family: "healer", verb: "buff", what: "war cry: brutes round it enrage (bigger, harder hits)" },
  bonepiles:   { family: "healer", verb: "summon", what: "raises skeletons from bone piles on the floor; smash the piles" },
  linkedpair:  { family: "healer", verb: "beam", what: "comes in pairs that heal each other; kill both close together" },
  // runners: fast
  packhowl:    { family: "runner", verb: "pack", what: "a howl, then the whole pack comes in from one side" },
  leap:        { family: "runner", verb: "leap", what: "crouches, then leaps onto your spot" },
  holdbite:    { family: "runner", verb: "hold", what: "bites and holds on: you're slowed until you shake it (keys)" },
  zigzagdrain: { family: "runner", verb: "zigzag", what: "zig-zags in; its bites heal it" },
  bleedbite:   { family: "runner", verb: "dash", what: "a bite that bleeds you a while" },
  frenzy:      { family: "runner", verb: "dash", what: "gets faster the more hurt it is" },
  sniff:       { family: "runner", verb: "dash", what: "beelines for you, faster when you're low" },
  lunge:       { family: "runner", verb: "dash", what: "a cutlass lunge: short dash, then a stab" },
  shank:       { family: "runner", verb: "dash", what: "stabs and runs off, then back again" },
  imppop:      { family: "bomber", verb: "burst", what: "dashes in and pops in a puff of flame" },
  swoopline:   { family: "runner", verb: "lane", what: "swoops in from the sky along a line" },
  hitandrun:   { family: "runner", verb: "bolt", what: "throws a spear, then runs off to throw again" },
  // brutes: slow, tough
  shove:       { family: "brute", verb: "shove", what: "shoves you far away on touch" },
  shieldfront: { family: "brute", verb: "guard", what: "a shield that blocks hits from the front; get round it" },
  slamstun:    { family: "brute", verb: "slam", what: "a ground slam round it: stuns" },
  deathroll:   { family: "brute", verb: "hold", what: "grabs you and rolls: you're held a moment" },
  quillnova:   { family: "brute", verb: "nova", what: "sprays quills all round it" },
  charge:      { family: "brute", verb: "lane", what: "scrapes its hoof, then charges along a line" },
  tailsweep:   { family: "brute", verb: "cone", what: "sweeps its tail behind/beside it" },
  grabthrow:   { family: "brute", verb: "hold", what: "grabs you and throws you across the room" },
  sunder:      { family: "brute", verb: "touch", what: "each hit makes the next one hurt more" },
  cleaveknock: { family: "brute", verb: "cone", what: "a wide cleave that knocks you away" },
  tether:      { family: "brute", verb: "tether", what: "chains you: you can't get far from it" },
  smashpillar: { family: "brute", verb: "touch", what: "huge and slow; walks through pillars and breaks them" },
  spin:        { family: "brute", verb: "nova", what: "a short spin with its axe" },
  rockarmor:   { family: "brute", verb: "guard", what: "harder and harder the longer it stands still" },
  boulderroll: { family: "brute", verb: "lane", what: "rolls a boulder down a lane" },
  hookpull:    { family: "brute", verb: "pull", what: "throws a hook and pulls you in" },
  eruption:    { family: "brute", verb: "nova", what: "stops, then a ring of fire bursts out of it" },
  firenova:    { family: "brute", verb: "nova", what: "a fire nova round it, now and then" },
  // the floor
  firetrail:   { family: "floor", verb: "trail", what: "leaves a trail of fire where it walks" },
  icetrail:    { family: "floor", verb: "trail", what: "leaves ice: you slide on it" },
  vomitcone:   { family: "floor", verb: "cone", what: "vomits a cone that leaves a puddle" },
  quicksand:   { family: "floor", verb: "puddle", what: "leaves quicksand that pulls you to its middle" },
  poisoncloud: { family: "floor", verb: "aura", what: "a poison cloud round it" },
  chillaura:   { family: "floor", verb: "aura", what: "a chill round it: slows you when close" },
  rootpatch:   { family: "floor", verb: "puddle", what: "drops seeds that grow roots: stuck if you step in" },
  rotcloud:    { family: "floor", verb: "aura", what: "a cloud of rot: your healing stops while you're in it" },
  // bombers: blow up (each its own way)
  alarm:       { family: "bomber", verb: "burst", what: "beeps and rolls straight at you; if it reaches you: boom + the alarm calls a wave of gnomes" },
  deathburst:  { family: "bomber", verb: "deathpuddle", what: "slow and harmless, but bursts into poison when it dies: don't kill it close" },
  molotov:     { family: "bomber", verb: "lob", what: "throws a bottle that leaves burning floor" },
  mines:       { family: "bomber", verb: "plonk", what: "lays mines behind it as it walks" },
  // swarms: tiny, many
  scuttle:     { family: "swarm", verb: "swarm", what: "scuttles sideways in big groups" },
  spiderlings: { family: "swarm", verb: "swarm", what: "a flood of tiny spiders" },
  sprites:     { family: "swarm", verb: "swarm", what: "little clouds of poison sprites" },
  plaguewhelps:{ family: "swarm", verb: "swarm", what: "plagued hatchlings, a lot of them, weak" },
  eggs:        { family: "swarm", verb: "swarm", what: "whelps pour out of the egg clutches by the walls" },
  riot:        { family: "swarm", verb: "swarm", what: "a riot: prisoners burst out in big waves" },
  cadaverbits: { family: "swarm", verb: "split", what: "falls apart into crawling bits when killed" },
  // tricks
  burrow:      { family: "trick", verb: "below", what: "burrows, then pops up under you" },
  phase:       { family: "trick", verb: "phase", what: "a ghost: goes through pillars, fades in and out" },
  blink:       { family: "trick", verb: "blink", what: "blinks to a spot right next to you" },
  stealth:     { family: "trick", verb: "stealth", what: "invisible until it's close" },
  illusions:   { family: "trick", verb: "split", what: "splits into three; only one is real" },
  flee:        { family: "trick", verb: "flee", what: "runs off when hurt and comes back with friends" },
  shell:       { family: "trick", verb: "guard", what: "hides in its shell when hit: can't be hurt a moment" },
  reassemble:  { family: "trick", verb: "revive", what: "falls to bits, then gets back up once" },
  split:       { family: "trick", verb: "split", what: "splits into two small ones when killed" },
  rockdisguise:{ family: "trick", verb: "stealth", what: "looks like a rock until you pass, then wakes" },
  statue:      { family: "trick", verb: "stealth", what: "a statue that wakes when you come close" },
  stoneform:   { family: "trick", verb: "guard", what: "turns to stone (can't be hurt), then dives at you" },
  petrify:     { family: "trick", verb: "cone", what: "a gaze cone in front of it: stand in it and you're stone for 1 s" },
  stackpoison: { family: "trick", verb: "touch", what: "each sting stacks more poison" },
  swapplaces:  { family: "trick", verb: "blink", what: "swaps places with you" },
  possess:     { family: "trick", verb: "buff", what: "flies into another foe, which grows stronger" },
  manaburn:    { family: "trick", verb: "touch", what: "a hit burns your XP bar back" },
  eatgems:     { family: "trick", verb: "pull", what: "pulls your XP gems to it and eats them" },
  ghostafter:  { family: "trick", verb: "revive", what: "when it dies its ghost keeps chasing you a while" },
  wrapped:     { family: "trick", verb: "guard", what: "wrapped up: half damage until its wraps are off" },
  absorb:      { family: "trick", verb: "grow", what: "eats slain foes and grows bigger" },
  webroot:     { family: "trick", verb: "bolt", what: "shoots web: stuck in place a moment" },
  cocoon:      { family: "trick", verb: "hold", what: "wraps you in a cocoon: mash keys to break out" },
  fear:        { family: "trick", verb: "nova", what: "a wail: you run in fear for 1.5 s" },
  disease:     { family: "trick", verb: "touch", what: "disease: no healing for a while after a hit" },
  graverise:   { family: "trick", verb: "below", what: "rise out of the sand in rows" },
  screech:     { family: "trick", verb: "cone", what: "a screech cone: your attacks stop for 1 s" },
  vinepull:    { family: "trick", verb: "pull", what: "a vine from far off that pulls you in" },
  dodge:       { family: "trick", verb: "blink", what: "sidesteps your shots" },
  shieldbash:  { family: "brute", verb: "touch", what: "a shield bash: stuns a moment" },
  lash:        { family: "brute", verb: "nova", what: "rooted to the spot, whips all round it" },
  seedlings:   { family: "healer", verb: "summon", what: "slow; drops seeds that grow into lashers" },
  rally:       { family: "healer", verb: "buff", what: "rallies the Defias round it: they take less damage" },
  dragonsleep: { family: "trick", verb: "cone", what: "sleep breath cone: you fall asleep (mash keys)" },
  // Scarlet Monastery's four rooms (2026-10-29)
  gravegrab:   { family: "trick", verb: "below", what: "climbs out of the grave nearest you; its first touch grabs you (stuck a moment)" },
  chilltouch:  { family: "runner", verb: "drift", what: "drifts in loops through the gravestones; its touch chills you (slowed)" },
  thumbscrews: { family: "brute", verb: "touch", what: "a pinch: your attacks come slower for a while" },
  bookthrow:   { family: "caster", verb: "volley", what: "flings books off the shelves: three in a curve" },
  renew:       { family: "healer", verb: "buff", what: "renew on hurt Scarlets near it: they heal over time" },
  brace:       { family: "brute", verb: "guard", what: "hit, it braces behind its shield (half damage), then rushes a short way" },
  enrage:      { family: "brute", verb: "grow", what: "at half health: a roar, grows and turns red, comes fast" },
  drill:       { family: "swarm", verb: "line", what: "trainees in a squad of five, marching in step in a line" },
  crusaderstrike: { family: "brute", verb: "cone", what: "a big overhead swing: a red cone in front of it, then a heavy hit" },
  consecrate:  { family: "floor", verb: "puddle", what: "consecrates the floor round it: hurts you, Scarlets in it take less damage" },
};

// The mobs per stage: [real mob name, costume, signature]
const MOBS = {
  rfc: [["Ragefire Trogg", "trogg", "burrow"], ["Ragefire Shaman", "trogg", "healwave"], ["Molten Elemental", "elemental", "eruption"],
    ["Searing Blade Warlock", "burningblade", "summonimp"], ["Searing Blade Enforcer", "burningblade", "burnbrand"]],
  wc: [["Deviate Ravager", "raptor", "leap"], ["Deviate Crocolisk", "crocolisk", "deathroll"], ["Deviate Viper", "snake", "poisonspit"],
    ["Deviate Lasher", "plant", "lash"], ["Druid of the Fang", "snake", "shapeshift"]],
  dm: [["Goblin Engineer", "venture", "bomblob"], ["Defias Overseer", "defias", "rally"], ["Defias Evoker", "defias", "missiles"],
    ["Defias Pirate", "bloodsail", "lunge"], ["Defias Miner", "defias", "minecart"]],
  sfk: [["Shadowfang Moonwalker", "wolf", "packhowl"], ["Shadowfang Darksoul", "wolf", "shadowcurse", "shadow"], ["Haunted Servitor", "ghost", "phase"],
    ["Vile Bat", "bat", "zigzagdrain"], ["Lupine Horror", "wolf", "illusions"]],
  bfd: [["Blackfathom Sea Witch", "naga", "blizzard"], ["Blackfathom Myrmidon", "naga", "tailsweep"], ["Blindlight Murloc", "murloc", "flee"],
    ["Snapping Crustacean", "crab", "scuttle"], ["Blindlight Oracle", "murloc", "waterbolt"], ["Aku'mai Snapjaw", "turtle", "shell"],
    ["Fallenroot Shadowstalker", "satyr", "stealth", "shadow"]],
  stocks: [["Defias Prisoner", "defias", "riot"], ["Defias Convict", "defias", "shank"], ["Defias Insurgent", "defias", "molotov"],
    ["Defias Inmate", "human", "grabthrow"]],
  gnomer: [["Alarm-a-bomb 2600", "alarmbomb", "alarm"], ["Leprous Machinesmith", "lepergnome", "repairbots"], ["Mechano-Frostwalker", "lepergnome", "icetrail", "frost"],
    ["Irradiated Slime", "ooze", "split"], ["Dark Iron Agent", "darkiron", "mines"], ["Leprous Technician", "lepergnome", "wrenchbounce"]],
  rfk: [["Razorfen Quilguard", "quilboar", "quillnova"], ["Razorfen Geomancer", "quilboar", "earthspikes"], ["Agam'ar", "boar", "charge"],
    ["Kraul Bat", "bat", "screech"], ["Razorfen Beastmaster", "quilboar", "beastcall"]],
  // (Scarlet Monastery: four rooms, the four wings - ROOMS below says which room each mob is in)
  sm: [["Haunting Phantasm", "ghost", "blink"], ["Anguished Dead", "zombie", "gravegrab"], ["Unfettered Spirit", "ghost", "chilltouch", "ghost"],
    ["Scarlet Torturer", "scarlet", "thumbscrews"],
    ["Scarlet Monk", "scarlet", "dodge"], ["Scarlet Tracking Hound", "wolf", "bleedbite"], ["Scarlet Diviner", "scarlet", "bookthrow"],
    ["Scarlet Adept", "scarlet", "renew"],
    ["Scarlet Soldier", "scarlet", "shieldbash"], ["Scarlet Defender", "scarlet", "brace"], ["Scarlet Myrmidon", "scarlet", "enrage"],
    ["Scarlet Trainee", "scarlet", "drill"],
    ["Scarlet Chaplain", "scarlet", "shieldally"], ["Scarlet Sorcerer", "scarlet", "frostbolt"], ["Scarlet Champion", "scarlet", "crusaderstrike"],
    ["Scarlet Abbot", "scarlet", "consecrate"]],
  rfd: [["Splinterbone Skeleton", "skeleton", "reassemble"], ["Skeletal Frostweaver", "skeleton", "chillaura"], ["Death's Head Necromancer", "quilboar", "bonepiles"],
    ["Boneflayer Ghoul", "ghoul", "frenzy"], ["Withered Battle Boar", "boar", "trample"]],
  ulda: [["Shadowforge Sharpshooter", "darkiron", "snipe"], ["Earthen Rocksmasher", "golem", "slamstun"], ["Jadespine Basilisk", "basilisk", "petrify"],
    ["Stonevault Cave Lurker", "trogg", "rockdisguise"], ["Venomlash Scorpid", "scorpid", "stackpoison"], ["Stone Keeper", "golem", "rockarmor"]],
  zf: [["Sandfury Shadowhunter", "troll", "hex"], ["Sandfury Blood Drinker", "troll", "drainlife"], ["Sandfury Witch Doctor", "troll", "healtotem"],
    ["Sul'lithuz Sandcrawler", "basilisk", "quicksand"], ["Zul'Farrak Zombie", "zombie", "graverise"]],
  mara: [["Theradrim Guardian", "golem", "boulderroll"], ["Constrictor Vine", "plant", "vinepull"], ["Noxious Slime", "ooze", "poisoncloud"],
    ["Putridus Shadowstalker", "satyr", "hitandrun"], ["Poison Sprite", "elemental", "sprites", "poison"]],
  st: [["Nightmare Wyrmkin", "dragonkin", "dragonsleep"], ["Atal'ai Deathwalker", "troll", "ghostafter"], ["Mummified Atal'ai", "zombie", "wrapped"],
    ["Atal'ai Priest", "troll", "linkedpair"], ["Saturated Ooze", "ooze", "absorb"]],
  brd: [["Anvilrage Guardsman", "darkiron", "shieldfront"], ["Fireguard", "elemental", "firetrail"], ["Bloodhound", "wolf", "sniff"],
    ["Doomforge Arcanasmith", "darkiron", "arcanebomb"], ["Warbringer Construct", "golem", "smashpillar"]],
  lbrs: [["Smolderthorn Axe Thrower", "troll", "axeboomerang"], ["Firebrand Pyromancer", "blackrock", "firewall"], ["Spire Spider", "spider", "webroot"],
    ["Spire Spiderling", "spider", "spiderlings"], ["Spirestone Ogre Magus", "spirestone", "bloodlust"], ["Scarshield Legionnaire", "blackrock", "sunder"]],
  ubrs: [["Blackhand Dreadweaver", "blackrock", "volleyfan"], ["Rage Talon Flamescale", "dragonkin", "flamebreath"], ["Blackhand Incarcerator", "blackrock", "tether"],
    ["Rage Talon Dragonspawn", "dragonkin", "cleaveknock"], ["Black Whelp", "blackflight", "swoopline"]],
  dme: [["Wildspawn Hellcaller", "satyr", "rainoffire"], ["Wildspawn Trickster", "satyr", "swapplaces"], ["Warpwood Treant", "plant", "seedlings"],
    ["Whip Lasher", "plant", "rootpatch"], ["Wildspawn Imp", "demon", "imppop"]],
  dmw: [["Eldreth Apparition", "ghost", "possess"], ["Skeletal Highborne", "skeleton", "manaburn"], ["Arcane Aberration", "elemental", "chainbolt", "arcane"],
    ["Mana Remnant", "elemental", "eatgems", "arcane"], ["Petrified Treant", "plant", "statue"], ["Rotting Highborne", "zombie", "rotcloud"]],
  dmn: [["Gordok Brute", "gordok", "shove"], ["Gordok Mastiff", "wolf", "holdbite"], ["Gordok Mage-Lord", "gordok", "blinkfire"],
    ["Gordok Captain", "gordok", "warcry"], ["Gordok Reaver", "gordok", "spin"]],
  scholo: [["Unstable Corpse", "zombie", "deathburst"], ["Spectral Tutor", "ghost", "silence"], ["Diseased Ghoul", "ghoul", "disease"],
    ["Risen Bonewarder", "skeleton", "bonearmor"], ["Plagued Hatchling", "dragonkin", "plaguewhelps"], ["Scholomance Necromancer", "scourge", "deathcoil"]],
  stratl: [["Crimson Priest", "scarlet", "holynova"], ["Crimson Gallant", "scarlet", "divineshield"], ["Wailing Banshee", "ghost", "fear"],
    ["Rockwing Gargoyle", "gargoyle", "stoneform", "stone"], ["Plague Ghoul", "ghoul", "pileon"]],
  stratu: [["Bile Spewer", "abomination", "vomitcone"], ["Patchwork Horror", "abomination", "hookpull"], ["Crypt Crawler", "spider", "cocoon"],
    ["Thuzadin Necromancer", "scourge", "corpseboom"], ["Ravaged Cadaver", "zombie", "cadaverbits"]],
  ony: [["Onyxian Warder", "dragonkin", "firenova"], ["Onyxian Whelp", "blackflight", "eggs"]],
};

// MARKS: what sets a mob apart from the others in the same costume (user: "if they have different abilities they need
// to be unique in some way"): a held accessory that hints at what it does, a tint (drawn by code), a size. Within a
// dungeon no two mobs may look the same - the writer below checks. (accessories: the painted set accessories)
const MARKS = {
  "rfc:Ragefire Shaman": { acc: "fac_deadwind_acc" },                  // Storm Totem
  "rfc:Searing Blade Warlock": { acc: "crit_demon_acc" },               // Demon Pitchfork (his imps)
  "rfc:Searing Blade Enforcer": { acc: "fac_burningblade_acc" },        // Burning Blade Scimitar
  "wc:Druid of the Fang": { acc: "crit_elemental_acc" },                // Storm Cloud on a Stick (lightning)
  "dm:Goblin Engineer": { acc: "fac_firegut_acc" },                     // Fire Pot (his bombs)
  "dm:Defias Overseer": { acc: "fac_splinterfist_acc" },                // Slaver's Whip
  "dm:Defias Evoker": { acc: "fac_gordunni_acc" },                      // Scroll (arcane missiles)
  "dm:Defias Miner": { acc: "fac_venture_acc" },                        // Pickaxe
  "sfk:Shadowfang Darksoul": { acc: "fac_moshogg_acc" },                // Shrunken Head Staff (curse)
  "sfk:Lupine Horror": { acc: "crit_wolf_acc", size: 1.25 },            // Knitted Wolf Pup (its copies)
  "bfd:Blackfathom Sea Witch": { acc: "crit_elemental_acc", tint: "frost" },
  "bfd:Blackfathom Myrmidon": { acc: "crit_naga_acc" },                 // Sequin Trident
  "bfd:Blindlight Murloc": { acc: "crit_murloc_acc" },                  // Fish on a Stick
  "bfd:Blindlight Oracle": { acc: "fac_deadwind_acc", tint: "water" },
  "stocks:Defias Convict": { acc: "fac_defias_acc" },                   // Throwing Knives (shank)
  "stocks:Defias Insurgent": { acc: "fac_firegut_acc" },                // Fire Pot (molotov)
  "stocks:Defias Prisoner": { size: 0.8 },                              // (the riot: small, many)
  "gnomer:Leprous Machinesmith": { acc: "fac_darkiron_acc" },           // Forge Hammer (repairs)
  "gnomer:Mechano-Frostwalker": { tint: "frost", size: 1.3 },
  "gnomer:Leprous Technician": { acc: "fac_venture_acc" },              // Pickaxe (wrenches)
  "gnomer:Irradiated Slime": { tint: "radiation" },                     // (oozes: see-through, coloured per dungeon - user)
  "rfk:Razorfen Quilguard": { acc: "crit_quilboar_acc" },               // Bramble Club
  "rfk:Razorfen Geomancer": { acc: "crit_trogg_acc" },                  // Rock on a Stick (earth)
  "rfk:Razorfen Beastmaster": { acc: "fac_urok_acc" },                  // Doomhowl Horn (calls boars)
  "sm:Scarlet Torturer": { acc: "fac_darkiron_acc", tint: "blood" },     // Forge Hammer (the thumbscrews)
  "sm:Scarlet Diviner": { acc: "fac_gordunni_acc" },                    // Scroll (the books)
  "sm:Scarlet Adept": { acc: "fac_scarlet_acc" },                       // Scarlet Censer (renew)
  "sm:Scarlet Soldier": { acc: "crit_human_acc" },                      // Quilted Shield (bash)
  "sm:Scarlet Defender": { acc: "crit_human_acc", size: 1.3 },          // Quilted Shield, big (braces)
  "sm:Scarlet Myrmidon": { acc: "fac_blackrock_acc" },                  // War Axe (enrage)
  "sm:Scarlet Trainee": { size: 0.75 },                                 // (the squads: small)
  "sm:Scarlet Sorcerer": { acc: "fac_gordunni_acc", tint: "frost" },
  "sm:Scarlet Chaplain": { acc: "fac_scarlet_acc" },                    // Scarlet Censer
  "sm:Scarlet Champion": { acc: "fac_darkiron_acc", size: 1.3 },        // Forge Hammer, big (the overhead swing)
  "sm:Scarlet Abbot": { acc: "crit_kobold_acc" },                       // Candle on a Stick (consecrate)
  "rfd:Splinterbone Skeleton": { acc: "crit_skeleton_acc" },            // Foam Femur
  "rfd:Skeletal Frostweaver": { tint: "frost" },
  "ulda:Earthen Rocksmasher": { acc: "fac_boulderfist_acc" },           // Boulder (slam)
  "ulda:Stone Keeper": { size: 1.35 },
  "zf:Sandfury Shadowhunter": { acc: "crit_troll_acc" },                // Voodoo Doll (hex)
  "zf:Sandfury Blood Drinker": { acc: "crit_ghoul_acc", tint: "blood" },  // Cleaver
  "zf:Sandfury Witch Doctor": { acc: "fac_moshogg_acc" },               // Shrunken Head Staff (ward)
  "st:Atal'ai Deathwalker": { acc: "crit_ghost_acc", tint: "ghost" },   // Pillowcase Lantern
  "st:Atal'ai Priest": { acc: "crit_troll_acc" },                       // Voodoo Doll
  "brd:Anvilrage Guardsman": { acc: "crit_human_acc" },                 // Quilted Shield (front)
  "brd:Doomforge Arcanasmith": { acc: "pocket_portal" },                // Pocket Portal (arcane bomb)
  "lbrs:Firebrand Pyromancer": { acc: "fac_firegut_acc" },              // Fire Pot (fire wall)
  "lbrs:Scarshield Legionnaire": { acc: "fac_blackrock_acc" },          // Blackrock War Axe
  "lbrs:Smolderthorn Axe Thrower": { acc: "crit_orc_acc" },             // Felt War Axe (thrown)
  "lbrs:Spirestone Ogre Magus": { acc: "fac_spirestone_acc" },          // War Banner (bloodlust)
  "lbrs:Spire Spider": { acc: "crit_spider_acc" },                      // Sticky Web
  "lbrs:Spire Spiderling": { size: 0.55 },
  "ubrs:Blackhand Dreadweaver": { acc: "fac_moshogg_acc" },             // Shrunken Head Staff (volley)
  "ubrs:Blackhand Incarcerator": { acc: "fac_splinterfist_acc" },       // Slaver's Whip (the chain)
  "ubrs:Rage Talon Flamescale": { acc: "crit_dragonkin_acc", tint: "fire" },  // Dragon Kite
  "ubrs:Rage Talon Dragonspawn": { acc: "fac_dreadmaul_acc", size: 1.3 },     // Fel Spiked Maul (cleave)
  "ubrs:Black Whelp": { size: 0.7 },
  "dme:Wildspawn Hellcaller": { acc: "fac_firegut_acc" },               // Fire Pot (rain of fire)
  "dme:Wildspawn Trickster": { acc: "crit_satyr_acc" },                 // Panpipes
  "dme:Warpwood Treant": { size: 1.4 },
  "dme:Whip Lasher": { acc: "gacha_acc_riding_crop", size: 0.8 },       // Riding Crop (the whip)
  "dmw:Arcane Aberration": { acc: "pocket_portal" },
  "dmw:Mana Remnant": { size: 0.7 },
  "mara:Noxious Slime": { tint: "noxious" },
  "st:Saturated Ooze": { tint: "saturated" },
  "dmn:Gordok Mage-Lord": { acc: "fac_gordunni_acc" },                  // Scroll (blink + fireball)
  "dmn:Gordok Captain": { acc: "fac_gordok_acc" },                      // Royal Guard Halberd (war cry)
  "dmn:Gordok Reaver": { acc: "fac_blackrock_acc" },                    // War Axe (spin)
  "stratl:Crimson Priest": { acc: "fac_scarlet_acc" },                  // Scarlet Censer (holy nova)
  "stratl:Crimson Gallant": { acc: "crit_human_acc" },                  // Quilted Shield (bubble)
  "stratu:Bile Spewer": { size: 1.3 },
  "stratu:Patchwork Horror": { acc: "crit_ghoul_acc", size: 1.3 },      // Cleaver (the hook)
  "stratu:Thuzadin Necromancer": { acc: "fac_scourge_acc" },            // Plague Flask
  "ony:Onyxian Whelp": { size: 0.6 },
};

// ROOMS: for a dungeon whose rooms are places of their own (Scarlet Monastery's four wings), the room each mob is in.
const ROOMS = {
  sm: { "Haunting Phantasm": 0, "Anguished Dead": 0, "Unfettered Spirit": 0, "Scarlet Torturer": 0,
    "Scarlet Monk": 1, "Scarlet Tracking Hound": 1, "Scarlet Diviner": 1, "Scarlet Adept": 1,
    "Scarlet Soldier": 2, "Scarlet Defender": 2, "Scarlet Myrmidon": 2, "Scarlet Trainee": 2,
    "Scarlet Chaplain": 3, "Scarlet Sorcerer": 3, "Scarlet Champion": 3, "Scarlet Abbot": 3 },
};

if (require.main === module) {
  const file = path.join(__dirname, "arcade-stages.json"), A = JSON.parse(fs.readFileSync(file, "utf8"));
  const gear = JSON.parse(fs.readFileSync(path.join(__dirname, "gear.json"), "utf8"));
  const have = (k) => gear.pieces[`crit_${k}_head`] || gear.pieces[`fac_${k}_head`];
  const bad = [];
  for (const [k, list] of Object.entries(MOBS)) for (const [n, c, s] of list) { if (!SIGS[s]) bad.push(`${k}: ${n}: no signature ${s}`); if (!have(c) && !BORROW[c]) bad.push(`${k}: ${n}: no costume ${c}`); }
  if (bad.length) { console.error(bad.join("\n")); process.exit(1); }
  A.signatures = SIGS; A.newCostumes = NEW; A.laterCostumes = LATER;
  const uses = {};
  for (const st of A.stages) {
    const list = MOBS[st.key]; if (!list) continue;
    st.mobs = list.map(([name, costume, sig, tint]) => {
      const mk = MARKS[st.key + ":" + name] || {};
      return { name, costume, ...(have(costume) ? {} : { borrows: BORROW[costume], paint: !!NEW[costume] }), sig,
        ...(mk.acc ? { acc: mk.acc } : {}), ...(mk.tint || tint ? { tint: mk.tint || tint } : {}), ...(mk.size ? { size: mk.size } : {}),
        ...(ROOMS[st.key] ? { room: ROOMS[st.key][name] } : {}) };
    });
    st.foes = [...new Set(st.mobs.map((m) => m.borrows || m.costume))];
    // no two mobs in a dungeon (in a room, where its rooms are places of their own) may look the same (costume + accessory + tint + size)
    const looks = {};
    if (ROOMS[st.key]) for (const m of st.mobs) if (m.room == null) bad.push(`${st.key}: ${m.name} isn't in a room (ROOMS)`);
    for (const m of st.mobs) { const k = [m.room, m.costume, m.acc, m.tint, m.size].join("|"); if (looks[k]) bad.push(`${st.key}: ${m.name} looks just like ${looks[k]}`); looks[k] = m.name; }
    for (const m of st.mobs) if (m.acc && !gear.pieces[m.acc]) bad.push(`${st.key}: ${m.name}: no piece ${m.acc}`);
    for (const m of st.mobs) (uses[m.sig] = uses[m.sig] || []).push(st.key + ":" + m.name);
  }
  for (const k of Object.keys(MARKS)) { const [sk, n] = k.split(/:(.*)/); if (!(MOBS[sk] || []).some((m) => m[0] === n)) bad.push(`mark for a mob that isn't there: ${k}`); }
  if (bad.length) { console.error(bad.join("\n")); process.exit(1); }
  fs.writeFileSync(file, JSON.stringify(A, null, 1) + "\n");
  const twice = Object.entries(uses).filter(([, u]) => u.length > 1);
  const unused = Object.keys(SIGS).filter((s) => !uses[s] && s !== "healbeam");  // (healbeam: Moira, a boss partner)
  console.log(`${Object.values(MOBS).flat().length} mobs on ${Object.keys(MOBS).length} stages, ${Object.keys(SIGS).length} signatures`);
  if (twice.length) console.log("used twice: " + twice.map(([s, u]) => `${s} (${u.join(", ")})`).join("; "));
  if (unused.length) console.log("not used: " + unused.join(", "));
  const need = {}; for (const st of A.stages) for (const m of st.mobs || []) if (m.borrows) (need[m.costume] = need[m.costume] || []).push(st.key);
  const line = (keys) => Object.entries(need).filter(([c]) => keys[c]).map(([c, s]) => `${c} (${s.length} mobs: ${[...new Set(s)].join(",")})`).join(", ");
  console.log("TO PAINT: " + line(NEW) + "\nlater (stand-ins work): " + line(LATER));
}
module.exports = { SIGS, MOBS, NEW, LATER, MARKS, ROOMS };
