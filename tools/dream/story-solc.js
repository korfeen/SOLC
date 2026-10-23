// SOLC's own jokes: guild in-jokes and running gags, all in one place. Everything here is ADDED to the
// storyteller's normal lines (nothing gets replaced), so a short list is fine.
// Try them out: node tools/dream/preview.js   then build: node tools/dream/build-story-lua.js   then /reload.
//
// Blanks you can use: {me} (the player), {mate} (a guildmate), {n} {kill} (their most-killed creature, "40 murlocs"),
// {hat} {outfit} (the ogre's clothes, short names), {mobs} {boss} (who's around in the dream's place).
// Buddy cameos also get {buddy} and {buddyPlace} (a guildmate you ran a dungeon with lately, and where).
// Keep each line short, and start endings with "And ".
const SOLC = {
  // Endings that can close any dream. "And then he STABBED ME." style.
  wild: [
    // "And then {mate} rolled Need on it.",
  ],
  // Endings about his clothes. "And a goose stole his {hat}." style.
  ends: [
  ],
  // Added to an ending when the player or guildmates are known. "And {mate} was there too, just watching." style.
  cameos: [
  ],
  // About a guildmate you ran a dungeon with lately. "And {buddy} said this was nothing compared to {buddyPlace}." style.
  buddyCameos: [
  ],
  // You, just before the punchline: "I asked if that was my {hat}." style (a short sentence, not starting with "And").
  me: [
  ],
  // How a dream starts: "{opener} in the clubhouse lounge...". "Right, so I was" style.
  openers: [
  ],
  // Said after a legendary piece. " (I SWEAR)" style: start with a space, in brackets.
  excited: [
  ],
  // Callbacks for a club place's ending, by its name in MintArt.lua. "And the club fined ME for it." style.
  // e.g. "Clubhouse Lounge": ["And the club secretary made us all sign the guest book. Again."],
  clubBack: {
  },
  // When two kinds of piece meet: [tag of the place or a piece, tag of one of his pieces, the line].
  // Tags: the ones in piece-tags.js TAG_LIST (fire, knitted, royal, tiny...).
  // e.g. ["golf", "sleepy", "He fell asleep on the eighteenth green. Club rules allow it."],
  reactions: [
  ],
};

// (Merges the lists above into the storyteller's. No need to touch this.)
WILD.push(...SOLC.wild);
GENERIC_ENDS.push(...SOLC.ends);
CAMEOS.push(...SOLC.cameos);
BUDDY_CAMEOS.push(...SOLC.buddyCameos);
OPENERS.push(...SOLC.openers);
ME.any.push(...SOLC.me);
EXCITED.push(...SOLC.excited);
REACTIONS.push(...SOLC.reactions);
for (const [name, lines] of Object.entries(SOLC.clubBack)) {
  if (!SETTING[name]) throw new Error("story-solc.js clubBack: no club place called \"" + name + "\" (check the name in MintArt.lua)");
  SETTING[name].back.push(...lines);
}
