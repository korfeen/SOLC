// Who's around in each place, for the endings' blanks: {mobs} (a crowd, plural, lowercase: "And all the {mobs} sat down
// at their desks.") and {boss} (who's in charge there: "And {boss} asked to borrow it."). Club places by name, dungeon
// backgrounds by option id (the Scarlet Monastery wings share a name).
const CROWD = {
  "Clubhouse Lounge": { mobs: ["club members", "waiters", "old golfers"], boss: ["the club secretary", "the head waiter"] },
  "Golf Course at Dawn": { mobs: ["golfers", "caddies", "geese"], boss: ["the head greenskeeper", "the club captain"] },
  "Hammock between Two Trees": { mobs: ["squirrels", "birds", "neighbours"], boss: ["the biggest squirrel"] },
  "Moonlit Fairway": { mobs: ["owls", "night golfers", "moths"], boss: ["the groundskeeper"] },
  "Spa Steam Room": { mobs: ["spa guests", "masseurs", "towel boys"], boss: ["the spa manager"] },
  "Swamp Hot Spring": { mobs: ["frogs", "crocolisks", "bathers"], boss: ["the oldest croc"] },
  "Pool with Floaties": { mobs: ["swimmers", "lifeguards", "rubber ducks"], boss: ["the lifeguard"] },
  "Ancient Treasure Lounge": { mobs: ["treasure goblins", "vault guards"], boss: ["the vault keeper"] },
  "Dragon over the Fairway": { mobs: ["golfers", "caddies", "dragonkin"], boss: ["the dragon"] },
  "Floating Sky Spa": { mobs: ["cloud nymphs", "spa guests", "birds"], boss: ["the sky spa manager"] },
  "Ghost Ship Cove": { mobs: ["ghost pirates", "skeletons", "seagulls"], boss: ["the ghost captain"] },
  bg_rfc: { mobs: ["troggs", "Burning Blade cultists", "imps"], boss: ["Taragaman", "Bazzalan"] },
  bg_wc: { mobs: ["Druids of the Fang", "deviate raptors", "murlocs"], boss: ["Mutanus", "Lord Serpentis"] },
  bg_dm: { mobs: ["Defias", "goblins", "murlocs"], boss: ["VanCleef", "Mr. Smite", "Cookie"] },
  bg_sfk: { mobs: ["worgen", "ghosts", "bats"], boss: ["Arugal", "Baron Silverlaine"] },
  bg_bfd: { mobs: ["naga", "murlocs", "Twilight cultists"], boss: ["Aku'mai", "Lady Sarevess"] },
  bg_stocks: { mobs: ["prisoners", "guards", "Defias convicts"], boss: ["Bazil Thredd", "Targorr the Dread"] },
  bg_gnomer: { mobs: ["leper gnomes", "troggs", "robots"], boss: ["Thermaplugg", "the Electrocutioner 6000"] },
  bg_rfk: { mobs: ["quilboar", "boars", "thorn-spitters"], boss: ["Charlga Razorflank", "Agathelos"] },
  bg_smgy: { mobs: ["ghosts", "Scarlet zealots", "skeletons"], boss: ["Bloodmage Thalnos", "Interrogator Vishas"] },
  bg_smlib: { mobs: ["Scarlet monks", "librarians", "hounds"], boss: ["Arcanist Doan", "Houndmaster Loksey"] },
  bg_smarm: { mobs: ["Scarlet soldiers", "training dummies", "myrmidons"], boss: ["Herod"] },
  bg_smcath: { mobs: ["Scarlet monks", "priests", "crusaders"], boss: ["High Inquisitor Whitemane", "Commander Mograine"] },
  bg_rfd: { mobs: ["undead quilboar", "spiders", "Scourge"], boss: ["Amnennar the Coldbringer", "Tuten'kash"] },
  bg_ulda: { mobs: ["troggs", "stone keepers", "dwarf diggers"], boss: ["Archaedas", "Ironaya"] },
  bg_zf: { mobs: ["Sandfury trolls", "scorpids", "basilisks"], boss: ["Chief Ukorz Sandscalp", "Gahz'rilla"] },
  bg_mara: { mobs: ["centaurs", "satyrs", "elementals"], boss: ["Princess Theradras", "Celebras"] },
  bg_st: { mobs: ["Atal'ai trolls", "green dragonkin", "oozes"], boss: ["the Shade of Eranikus", "Jammal'an"] },
  bg_brd: { mobs: ["Dark Iron dwarves", "fire elementals", "Grim Guzzler regulars"], boss: ["Emperor Thaurissan", "Plugger Spazzring"] },
  bg_lbrs: { mobs: ["Blackrock orcs", "spiders", "ogres"], boss: ["Overlord Wyrmthalak", "Mother Smolderweb"] },
  bg_ubrs: { mobs: ["Blackrock orcs", "black dragonkin", "whelps"], boss: ["General Drakkisath", "Rend Blackhand"] },
  bg_dme: { mobs: ["satyrs", "imps", "treants"], boss: ["Alzzin the Wildshaper", "Pusillin"] },
  bg_dmw: { mobs: ["highborne ghosts", "arcane horrors", "elves"], boss: ["Prince Tortheldrin", "Immol'thar"] },
  bg_dmn: { mobs: ["Gordok ogres", "ogre guards"], boss: ["King Gordok", "Cho'Rush"] },
  bg_scholo: { mobs: ["skeletons", "necromancy students", "ghosts"], boss: ["Darkmaster Gandling", "Ras Frostwhisper"] },
  bg_stratl: { mobs: ["Scarlet crusaders", "ghouls", "postmen"], boss: ["Balnazzar", "Postmaster Malown"] },
  bg_stratu: { mobs: ["abominations", "ghouls", "acolytes"], boss: ["Baron Rivendare", "Ramstein"] },
  bg_thanes: { mobs: ["dwarven thanes", "stone guardians", "dwarves"], boss: ["Dirgehammer"] },
  bg_ruins: { mobs: ["Forsaken", "ghouls", "bats"], boss: ["Rath'mael"] },
  bg_excav: { mobs: ["golems", "Explorers' League dwarves", "raptors"], boss: ["Guardian Stoneskin"] },
  bg_ony: { mobs: ["whelps", "black dragonkin", "raiders"], boss: ["Onyxia"] },
  bg_barrow: { mobs: ["sleeping druids", "wisps", "barrow bears"], boss: ["the oldest druid"] },
  bg_hyjal: { mobs: ["night elves", "demons", "wisps"], boss: ["Archimonde"] },
};
// A line with its blanks filled from the place (by its key); a place with no crowd: anyone.
function FillCrowd(line, placeKey) {
  const crowd = CROWD[placeKey] || { mobs: ["people"], boss: ["the manager"] };
  const pick = (list) => list[Math.floor(Math.random() * list.length)];
  return line.replace(/\{mobs\}/g, () => pick(crowd.mobs)).replace(/\{boss\}/g, () => pick(crowd.boss));
}
