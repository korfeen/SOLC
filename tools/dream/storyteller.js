// The storyteller's word lists (the telling itself is DreamTeller.lua in the addon; read it in the terminal with
// node tools/dream/preview.js). build-story-lua.js puts these in DreamStory.lua with the other story files.
// How a dream goes (DreamTeller.lua):
//   - each piece plays a part: the background is where you were and how he turns up; skin, outfit, hat, eyes and
//     face describe him; the accessory is what he does;
//   - one punchline: the payoff to the dream's own opening (story-payoffs.js), or the accessory's ending, or now and
//     then dream nonsense (WILD, WILD_TAGGED by the place's tags); sometimes you say something first (ME), sometimes
//     a guildmate turns up after (CAMEOS, BUDDY_CAMEOS) - never both;
//   - the rarer of his outfit and hat gets the full line, the other its shortest; a matching hat + outfit is one costume;
//   - tags (hand-picked per piece, piece-tags.js) pick the opener, the reaction, ME, WILD_TAGGED and TAG_ENDS;
//   - "(I SWEAR)" at most once, for a legendary piece; "that one AGAIN" for the skin dreamt last time.

// Some pairs make the dream react: [a tag of the place or a piece, a tag of one of his pieces, the line].
const REACTIONS = [
  ["water", "fire", "The whole place hisses with steam."],
  ["fire", "ice", "He's steaming and frosting at the same time."],
  ["holy", "undead", "He keeps flinching at his own {hat}."],
  ["undead", "holy", "The {mobs} won't go near him."],
  ["pirate", "pirate", "The {mobs} salute him, pirate to pirate."],
  ["golf", "golf", "He keeps asking if he can play through."],
  ["sleepy", "sleepy", "He nearly falls asleep halfway through. So do I."],
  ["dragon", "dragon", "The dragons nod at him, like they've met."],
  ["tech", "tech", "Something on him keeps beeping."],
  ["fel", "holy", "Everything holy nearby starts to fizz."],
  ["nature", "fire", "The plants all lean away from him."],
  ["metal", "water", "He squeaks a bit. Rust, probably."],
  ["royal", "royal", "Everyone bows. He bows back. It takes a while."],
  ["golf", "beast", "Someone asks if pets are allowed. They aren't."],
  ["arcane", "tech", "Sparks keep jumping between him and the walls."],
  ["undead", "fire", "The skeletons warm their hands on him."],
  ["undead", "undead", "Honestly, he fits right in."],
  ["water", "water", "He's dripping on everything."],
  ["ice", "fire", "Everything near him is melting."],
];
const OPENERS_TIME = { morning: ["This morning I dreamt I was", "So, early this morning, I was"], night: ["Last night I was", "So in the middle of the night I was"] };
const EXCITED = [" (I SWEAR)", " (honestly)", " (I'm not making this up)", " (GLOWING, I'm telling you)", " (like, properly)"];
const CAMEOS = ["And {mate} was there too, just watching.", "And he called me {me}.", "And he said I still owed him for those {n} {kill}.",
  "And {mate} said it happens to them all the time.", "And then he asked for {mate}. By name."];
const BUDDY_CAMEOS = ["And {buddy} was there too, still talking about our {buddyPlace} run.", "And {buddy} said this was nothing compared to {buddyPlace}.",
  "And {buddy} turned up, still covered in {buddyPlace}."];
const SET_FACTIONS = { defias: "a Defias thug", venture: "a Venture Co. miner", kolkar: "a Kolkar centaur", burningblade: "a Burning Blade cultist",
  syndicate: "a Syndicate rogue", scarlet: "a Scarlet crusader", bloodsail: "a Bloodsail pirate", darkiron: "a Dark Iron dwarf",
  blackrock: "a Blackrock orc", scourge: "a Cult of the Damned cultist", crimson: "a Crimson Legion knight", tracker: "a rare hunter",
  stalker: "Nathanos Blightcaller", master: "Rexxar", boulderfist: "a Boulderfist ogre", crushridge: "a Crushridge ogre", deadwind: "a Deadwind ogre",
  dreadmaul: "a Dreadmaul ogre", dunemaul: "a Dunemaul ogre", dustbelcher: "a Dustbelcher ogre", firegut: "a Firegut ogre", gordok: "a Gordok royal guard",
  gordunni: "a Gordunni ogre", mogrosh: "a Mo'grosh ogre", moshogg: "a Mosh'Ogg witch doctor", spirestone: "a Spirestone battle lord",
  splinterfist: "a Splinter Fist slaver", urok: "Urok Doomhowl" };
// Creature sets whose id isn't the creature's name (crit_<key>_head/_body): "in a full {name} suit".
const SET_CREATURES = { blackflight: "black whelp", blueflight: "blue whelp", bronzeflight: "bronze whelp", greenflight: "green whelp", redflight: "red whelp" };
const GENERIC_ENDS = ["And a goose stole his {hat}.", "And it turned out his {outfit} was mine all along.", "And his {hat} said goodbye on its own."];

// You, in the dream, just before the punchline: a short sentence, not starting with "And". By tag (the place's
// or his), else "any". Blanks as in the endings: {hat} {outfit} {mobs} {boss} {me} {mate}.
const ME = {
  any: ["I asked if that was my {hat}.", "I just nodded, like this was normal.", "I offered him a biscuit.",
    "I pretended to be asleep. Inside the dream.", "I asked him to wipe his feet.", "I said 'nice {outfit}'. I meant it.",
    "I asked if he'd booked.", "I asked {boss} if this was allowed. It was.", "I tried to wake up. Didn't work."],
  fire: ["I asked him to stand a bit further away.", "I said it was a bit warm for a {outfit}."],
  water: ["I handed him a towel.", "I asked if he could swim. He just blinked."],
  undead: ["I asked if he was feeling alright. He wasn't.", "I checked he had a pulse. Sort of."],
  holy: ["I tried very hard to look holy.", "I said a small prayer. Just in case."],
  pirate: ["I said 'arr'. It felt right.", "I asked where he'd parked the ship."],
  golf: ["I asked if he was a member.", "I asked him to replace his divots."],
  sleepy: ["I yawned too. It's catching.", "I asked if I could have the next nap."],
  dragon: ["I asked if he bites.", "I asked if he was a dragon. He said 'sort of'."],
  ice: ["I lent him my scarf.", "I asked him to close the door, he was letting the cold in."],
  tech: ["I asked what the button does.", "I asked if it was meant to be smoking."],
  fel: ["I asked him to keep the fel to himself.", "I checked I still had my soul. Mostly."],
  nature: ["I asked if he'd been rolling in a hedge.", "I tried not to sneeze. Pollen."],
  arcane: ["I asked him to stop glowing at me.", "I asked if he could do card tricks."],
  knitted: ["I asked who knitted it. 'My nan,' he said.", "I complimented the stitching."],
  metal: ["I asked if he squeaks. He did.", "I knocked on him. Someone said 'come in'."],
  shiny: ["I put my sunglasses on.", "I asked if it was real gold. He bit it to check."],
  stone: ["I asked if he was a statue. He didn't move.", "I asked if he was comfy. He said 'no'."],
  beast: ["I asked if he was house-trained.", "I held out my hand to let him sniff it."],
  royal: ["I curtsied. I don't know why.", "I asked if I should call him Your Majesty. He said yes."],
  smelly: ["I breathed through my mouth.", "I asked if he'd washed. He said 'once'."],
  tiny: ["I asked if it was meant to be that small.", "I tried very hard not to laugh."],
  huge: ["I asked how he got through the door.", "I had to step back to see all of it."],
};
// Endings about one of his pieces that has the tag (hand-picked tags, piece-tags.js): {it} is that piece's short name
// ("And a moth ate a hole in his {it}." -> onesie). Has to be true for ANY piece with the tag.
const TAG_ENDS = {
  fire: ["And his {it} set the curtains on fire. Nobody minded.", "And he toasted a marshmallow on his {it}.", "And his {it} left scorch marks on everything."],
  ice: ["And his {it} froze my drink solid.", "And his {it} made it snow. Just on me.", "And I stuck my tongue to his {it}. Still there."],
  water: ["And his {it} dripped all the way home.", "And his {it} had a fish in it.", "And his {it} squelched every step."],
  undead: ["And his {it} moaned quietly the whole time.", "And his {it} asked to be buried again.", "And his {it} fell off, then crawled back."],
  holy: ["And his {it} glowed whenever anyone swore.", "And his {it} started a small sermon.", "And his {it} blessed me. I feel worse."],
  fel: ["And his {it} whispered offers in my ear.", "And his {it} turned the grass green. Fel green.", "And his {it} tried to sign me up for the Legion."],
  nature: ["And a bird nested in his {it}.", "And his {it} flowered. Then sneezed.", "And his {it} needed watering."],
  arcane: ["And his {it} blinked us both somewhere else.", "And his {it} polymorphed me. Briefly. A sheep.", "And his {it} hummed a tune nobody knew."],
  knitted: ["And a moth ate a hole in his {it}.", "And a loose thread on his {it} unravelled the whole thing.", "And his {it} went in the wash and came out tiny."],
  metal: ["And his {it} clanked the whole way home.", "And a magnet stole his {it}.", "And his {it} rusted shut. Mid-sentence."],
  shiny: ["And his {it} sparkled so hard I had to look away.", "And a magpie tried to steal his {it}.", "And his {it} shed glitter on everyone."],
  stone: ["And his {it} weighed more than the room.", "And his {it} cracked, and a tiny golem walked out.", "And he sat down and his {it} went through the floor."],
  dragon: ["And his {it} breathed a small, polite flame.", "And his {it} demanded a hoard.", "And his {it} tried to sit on a pile of gold."],
  beast: ["And his {it} needed walking.", "And his {it} growled at {boss}.", "And his {it} scratched behind its own ear."],
  pirate: ["And his {it} said 'arr' on its own.", "And his {it} buried itself like treasure.", "And his {it} demanded a share of the loot."],
  golf: ["And his {it} got him into the members' bar. Not me.", "And his {it} was against the club dress code.", "And his {it} won the club raffle."],
  sleepy: ["And his {it} fell asleep before he did.", "And his {it} snored.", "And his {it} tucked him in and turned off the light."],
  royal: ["And everyone bowed to his {it}. Not to him.", "And his {it} declared itself king.", "And his {it} demanded a throne."],
  tech: ["And his {it} beeped, then exploded. Nicely.", "And his {it} needed a software update.", "And his {it} asked if I'd tried turning it off and on again."],
  smelly: ["And his {it} cleared the room.", "And his {it} got its own seat. Far away.", "And the flies followed his {it} home."],
  tiny: ["And his {it} pinged off his head halfway through.", "And his {it} was so small I lost it.", "And his {it} got even smaller when he sneezed."],
  huge: ["And his {it} didn't fit through the door. He stayed in.", "And his {it} knocked over everything behind him.", "And his {it} had its own weather."],
};
// Dream nonsense that fits the place, by its tags (picked over WILD when the place has one).
const WILD_TAGGED = {
  fire: ["And then the floor was lava. Properly, this time.", "And then everything caught fire. Nobody minded."],
  water: ["And then it started raining. Indoors.", "And then the tide came in. Right up to my chin."],
  undead: ["And then I was a skeleton too. It was quite comfy.", "And then the dead all wanted selfies."],
  holy: ["And then the Light told me off.", "And then a choir started, very loudly, right behind me."],
  pirate: ["And then the whole place sank.", "And then a parrot read out my will."],
  golf: ["And then it was my tee time. I wasn't ready.", "And then the clubhouse charged me for the dream."],
  sleepy: ["And then I fell asleep. In the dream. And dreamt about this.", "And then everyone was in pyjamas."],
  dragon: ["And then a dragon landed and asked for directions.", "And then it was whelps. Many whelps."],
  ice: ["And then everything froze, including my face.", "And then it snowed. On the inside."],
  tech: ["And then something exploded. Nicely.", "And then a gnome came out of his pocket and went 'ta-da'."],
  fel: ["And then a satyr asked if we had a minute to talk about the Legion.", "And then everything went green. Very green."],
  nature: ["And then the floor grew moss. On me.", "And then a tree asked me to keep it down."],
  arcane: ["And then gravity went sideways for a bit.", "And then the stars rearranged themselves into a rude word."],
  stone: ["And then the walls started to talk. Slowly.", "And then I turned to stone. Very relaxing."],
  royal: ["And then everyone was crowned. Even me.", "And then a herald announced me, wrongly."],
  smelly: ["And then the smell got its own name tag.", "And then a fly moved in."],
  morning: ["And then the sun came up. Twice.", "And then a rooster told me off."],
  night: ["And then the moon came down to see what the fuss was.", "And then it got even darker. Somehow."],
};
// A piece's short name for callbacks: the main noun ("Crown of Eternal Rest" -> crown, "Captain Tricorn" -> tricorn).
const SHORT = { "Bald with Fly": "fly", "Nightcap with Pom Pom": "nightcap", "Loincloth and Member Sash": "sash", "Dragon Hatchling Hat": "hatchling",
  "Eye Mask Pushed Up": "eye mask", "Sleep Mask": "sleep mask", "Cucumber Slices": "cucumbers", "Mud Brown": "skin",
  // named weapons and items keep their name ("his Deathbringer")
  "Deathbringer": "Deathbringer", "Ironfoe": "Ironfoe", "Ravager": "Ravager", "Stoneslayer": "Stoneslayer", "Venomstrike": "Venomstrike",
  "Strike of the Hydra": "Strike of the Hydra", "Heart of Agamaggan": "Heart of Agamaggan", "Book of the Dead": "Book of the Dead",
  "Dragon's Call": "Dragon's Call", "Fist of Omokk": "Fist of Omokk", "Debt Collector": "Debt Collector", "Mind Carver": "Mind Carver",
  "Dal'Rend's Sacred Charge": "Sacred Charge", "Dal'Rend's Tribal Guardian": "Tribal Guardian", "Headmaster's Charge": "Headmaster's Charge",
  "Sang'thraze the Deflector": "Sang'thraze", "Jang'thraze the Protector": "Jang'thraze", "Sul'thraze the Lasher": "Sul'thraze",
  "Cursed Felblade": "Felblade", "Draconian Deflector": "shield", "Golemsight Long Gun": "gun",
  // better nouns than the last word
  "Dal'Rend's Arms": "swords", "Phoenix on Shoulder": "phoenix", "Firegut Ember Belly": "apron", "Crushridge Plunder": "furs",
  "Bazil's Locks": "hair", "Whitemane's Locks": "hair", "Tortheldrin's Locks": "hair", "Mekgineer's Mech Suit": "mech suit",
  "Electromagnetic Gigaflux Reactivator": "helmet", "Dustbelcher Wyrmhunter Gear": "leathers", "Splinter Fist Slaver Gear": "harness",
  "Nesingwary's Safari Gear": "safari jacket", "Venture Hard Hat": "hard hat", "Tiny Top Hat": "top hat", "Boulderfist War Paint Band": "headband" };
