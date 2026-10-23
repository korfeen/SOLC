// The storyteller: each piece plays a part in the dream, told in beats (one per tap, each painting its layer):
//   background  "So I was {at}..."                      where you were, what you were doing
//   skin        "when this {skin} ogre {enters},"      the background says how he turns up there
//   outfit      "{outfit},"   headwear "{hat}."         what he's wearing
//   eyes        "He looks at me {eyes},"  expression "{face}..."
//   accessory   "and then he {does}."                    what he does with the thing he's holding
//   the end     one of the accessory's endings, and maybe one of the background's callbacks
const OPENERS = ["So I was", "Right, so I was", "Okay, so I was", "Last night I was"];
const SETTING = {
  "Clubhouse Lounge": { at: ["in the clubhouse lounge, reading the paper upside down", "by the clubhouse fire, about to finally win at cards"],
    enters: ["climbs out of the fireplace", "rolls in on the drinks trolley"], back: ["And the club fined ME for it.", "And the barman just kept polishing the same glass."] },
  "Golf Course at Dawn": { at: ["on the golf course at dawn, lining up the putt of my life", "teeing off at sunrise, all alone, at peace"],
    enters: ["wades out of the water hazard", "pops up out of the eighteenth hole"], back: ["And I missed the putt.", "And he took my tee time."] },
  "Hammock between Two Trees": { at: ["in my hammock between two trees, finally comfy", "swinging in the hammock, not a care in the world"],
    enters: ["drops out of the tree above me", "climbs into the hammock with me"], back: ["And the hammock snapped.", "And now he lives in my hammock."] },
  "Moonlit Fairway": { at: ["sneaking a midnight round on the moonlit fairway", "on the fairway under a full moon, howling a bit"],
    enters: ["glides across the green in the moonlight", "rises out of a bunker"], back: ["And the moon winked at me.", "And the groundskeeper saw everything."] },
  "Spa Steam Room": { at: ["in the spa's steam room, cucumbers on, totally relaxed", "sweating it out in the steam room"],
    enters: ["appears out of the steam", "sits down right next to me, way too close"], back: ["And my cucumber slices were gone.", "And the steam spelled out 'NO REFUNDS'."] },
  "Swamp Hot Spring": { at: ["soaking in the swamp hot spring, up to my chin", "in the hot spring, blowing bubbles"],
    enters: ["surfaces from the bubbling mud", "floats over on a lily pad"], back: ["And the spring went cold.", "And a croc took my towel."] },
  "Pool with Floaties": { at: ["drifting round the club pool on a rubber duck", "lounging in the pool on a floatie"],
    enters: ["cannonballs into the pool", "paddles up on an inflatable dragon"], back: ["And I lost my floatie.", "And the lifeguard just gave him a thumbs up."] },
  "Ancient Treasure Lounge": { at: ["lounging on a mountain of ancient treasure", "in a vault full of gold, counting coins for fun"],
    enters: ["crawls out of a treasure chest", "slides down the gold pile"], back: ["And all the gold turned into chocolate coins.", "And he took the biggest gem as a tip."] },
  "Dragon over the Fairway": { at: ["playing a round while a dragon circled overhead", "on the fairway, trying to ignore the dragon"],
    enters: ["drops off the dragon's back", "rides in on the dragon"], back: ["And the dragon ate my ball.", "And the dragon gave him a better score than me."] },
  "Floating Sky Spa": { at: ["in the spa above the clouds, having a massage", "lying on a cloud miles up in the sky"],
    enters: ["parachutes in", "floats up on a balloon"], back: ["And I fell off the cloud.", "And the cloud charged me extra."] },
  "Ghost Ship Cove": { at: ["on the deck of a ghost ship in a foggy cove", "rowing past a creaking ghost ship"],
    enters: ["drifts up through the floorboards", "swings in on a rope from the crow's nest"], back: ["And I woke up still damp.", "And the ghosts gave him a round of applause."] },
};
const SKIN = { "Moss": ["mossy green", "soft, mossy"], "Mud Brown": ["mud-brown", "freshly-rolled-in-mud"], "Swamp Green": ["swamp-green", "pond-scum green"],
  "Pale Lavender": ["pale lavender", "pastel purple"], "Slate Gray": ["stony grey", "slate-grey"], "Sunburnt Red": ["badly sunburnt", "lobster-red"],
  "Celestial Blue": ["star-speckled blue", "night-sky blue"], "Enchanted Jade": ["glowing jade", "enchanted green"], "Gold": ["solid gold", "gleaming golden"],
  "Grand Sleepy Pink": ["grand, sleepy pink", "bubblegum-pink"], "Obsidian Ember": ["smouldering black", "volcanic"], "Sea Cursed Teal": ["barnacled teal", "sea-cursed"] };
const OUTFIT = { "Fluffy Bathrobe": ["in a fluffy bathrobe", "wrapped in a giant fluffy robe"], "Golf Polo": ["in a golf polo tucked in way too high", "in a crisp golf polo"],
  "Loincloth and Member Sash": ["in nothing but a loincloth and a member's sash", "in a loincloth with a proud club sash"],
  "Spa Towel": ["in a spa towel that barely fits", "wearing a tiny spa towel"], "Striped Pajamas": ["in striped pyjamas", "in pyjamas buttoned up all wrong"],
  "Blazer with Club Crest": ["in the club blazer, crest and all", "in a very official club blazer"], "Onesie": ["in a fuzzy onesie", "zipped up in a onesie"],
  "Tweed Vest": ["in a smart tweed vest", "in his grandpa's tweed vest"], "Pirate Captain Coat": ["in a pirate captain's coat", "in a coat he clearly stole off a pirate"],
  "Celestial Pajamas": ["in pyjamas made of the night sky", "in starry pyjamas"], "Dragonhide Golf Jacket": ["in a dragonhide golf jacket", "in a golf jacket made of actual dragon"],
  "Royal Nap Robe": ["in a royal robe made for napping", "in the king's own nap robe"] };
const HAT = { "Bucket Hat": ["a bucket hat pulled down low", "a floppy bucket hat"], "Nightcap with Pom Pom": ["a nightcap with a bobbing pom-pom", "his nightcap flopping over one ear"],
  "Sun Visor": ["a sun visor on backwards", "a golf visor"], "Captain Tricorn": ["a captain's tricorn tilted at a jaunty angle", "a battered pirate hat three sizes too small", "a tricorn with a parrot feather stuck in it"],
  "Flower Crown": ["a crown of flowers", "a daisy chain on his head"], "Tiny Top Hat": ["a tiny top hat balanced on his head", "the smallest top hat you've ever seen"],
  "Towel Turban": ["a towel wrapped up like a turban", "his head wrapped in a towel"], "Astral Nightcap": ["a nightcap full of stars", "a nightcap glowing like the cosmos"],
  "Bald with Fly": ["nothing on his shiny bald head but a fly", "a bald head and one very determined fly"], "Crown of Eternal Rest": ["a crown that makes everyone around it yawn", "the Crown of Eternal Rest"],
  "Dragon Hatchling Hat": ["a baby dragon curled up on his head", "a dragon hatchling for a hat"] };
const EYES = { "Fully Asleep": ["with his eyes shut", "without even opening his eyes"], "Heavy Bags": ["with bags under his eyes you could pack for a trip", "with heavy, baggy eyes"],
  "Bloodshot": ["with bloodshot eyes", "with eyes red from no sleep at all"], "Cucumber Slices": ["through two cucumber slices", "with cucumber slices over his eyes"], "Pirate Eyepatch": ["with one eye under a pirate patch", "squinting at me past his eyepatch"],
  "Single Eye Open": ["with one droopy eye open", "with one suspicious eye"], "Dreamy Swirl": ["with swirly, dreamy eyes", "with spirals for eyes"],
  "Dragon Gaze": ["with the burning eyes of a dragon", "with a dragon's glare"], "Golden Oracle": ["with golden eyes that know my future", "with eyes glowing like an oracle's"],
  "Starlit Dreamer": ["with starlight in his eyes", "with tiny stars for eyes"] };
const FACE = { "Drooling": ["drooling a little", "dribbling down his chin"], "Mouth Hanging Open": ["mouth hanging wide open", "gawping like a fish"],
  "Smug Smile": ["grinning like he knows something", "with a smirk you could slap"], "Snoring Zzz Bubble": ["snoring, even though he's standing up", "blowing big snore bubbles"],
  "Tiny Snore Bubble": ["one tiny snore bubble at his nose", "a little bubble popping at his nose"], "Mid Yawn": ["yawning the biggest yawn", "caught mid-yawn"],
  "Sea Dog Grin": ["flashing a salty sea-dog grin", "grinning like an old pirate"], "Crystal Drool": ["drooling sparkling crystals", "diamonds dripping off his lip"],
  "Ember Yawn": ["yawning out embers", "breathing little sparks"], "Stardust Snore": ["snoring stardust", "puffing out glitter"] };
const THING = {
  "Eye Mask Pushed Up": { does: ["pulls his sleep mask down over MY eyes", "offers me his sleep mask"], end: ["And when I took it off, everyone was gone.", "And I just fell asleep inside the dream."] },
  "Membership Card": { does: ["shows me his membership card", "slaps his membership card on my forehead"], end: ["And it had MY face on it.", "And it said I'd been a member since 1066.", "And {boss} let him in instead of me."] },
  "Gold Chain": { does: ["takes off his gold chain and hands it to me", "starts swinging his gold chain around"], end: ["And it was made of sausages.", "And now I owe him rent."] },
  "Monocle": { does: ["screws in his monocle and inspects me", "polishes his monocle on my shirt"], end: ["And says 'hmm. No.'", "And the monocle had a tiny ogre inside, also inspecting me.", "And then {boss} inspected me too. Also no."] },
  "Pet Frog": { does: ["holds up his pet frog to my ear", "lets his pet frog hop onto my nose"], end: ["And the frog told me my tee time was cancelled.", "And the frog knew my PIN."] },
  "Pet Snail": { does: ["sets down his pet snail", "challenges me to a race against his pet snail"], end: ["And the snail won.", "And the snail was faster than me. By a lot.", "And all the {mobs} had bet on the snail."] },
  "Floating Sheep": { does: ["starts counting his floating sheep", "lets go of his floating sheep"], end: ["And there were only eleven. One's still missing.", "And it floated off with my hat.", "And all the {mobs} fell asleep counting it."] },
  "Pirate Eyepatch": { does: ["flips up his eyepatch", "swaps his eyepatch to the other eye"], end: ["And there was another eyepatch under it.", "And says 'arr' like it explains everything."] },
  "Sleepy Parrot": { does: ["nudges the sleepy parrot on his shoulder", "asks his parrot what it thinks of me"], end: ["And the parrot said 'zzz'.", "And the parrot just repeated my password."] },
  "Moonstone Pendant": { does: ["holds up his glowing moonstone", "swings his moonstone pendant in front of my face"], end: ["And now I can only speak in whispers.", "And I clucked like a chicken. I'm told.", "And all the {mobs} clucked with me."] },
  "Phoenix on Shoulder": { does: ["lets his phoenix take off", "sends his phoenix to fetch me a drink"], end: ["And it set everything on fire. Nobody minded.", "And it came back with a slightly burnt drink.", "And {boss} put it out with a very small bucket."] },
  "Sleep Mask": { does: ["says he's 'just resting his eyes' behind his quilted sleep mask", "lifts his sleep mask, one eye at a time, to look at me"], end: ["And there were eyes painted on the outside. They blinked.", "And he walked straight into {boss}. Didn't even notice.", "And he could see right through it. He'd been watching me the whole time."] },
  "Cucumber Slices": { does: ["takes the cucumber slices off his eyes and offers me one", "presses two cold cucumber slices on my eyes"], end: ["And I ate it. He was not happy.", "And when I opened my eyes, I was in a salad.", "And all the {mobs} asked where his spa was."] },
  "Pocket Portal": { does: ["opens a portal out of his pocket", "pulls a portal out of his pocket and pushes me in"], end: ["And I landed right back where I started.", "And on the other side was the same ogre, waving.", "And all the {mobs} followed me through."] },
};
// Some endings (instead of the thing's), dream logic for anything.
const WILD = ["And then he STABBED ME.", "And then all my teeth fell out.", "And then the floor was lava.", "And it turned out he was me. It was me all along.",
  "And then I had an exam I never signed up for.", "And he kissed me and flew away."];
