// Payoffs: each place's openings ("So I was {at}...") get endings that answer them, in the same order: pay[i] is a list
// of endings for at[i] ("lining up the putt of my life" -> "And I missed the putt."), one picked per dream. This is what
// makes a dream close the loop it opened, so a payoff should only make sense after its own opening.
// Club places by name, dungeons by option id. Keep them short, starting "And ". The build warns when a place has a
// different number of payoff lists than openings.
const PAYOFF = {
  "Clubhouse Lounge": [
    ["And the paper was today's dream, upside down. I'm in it.", "And the headline said 'OGRE IN LOUNGE'. Very old news.", "And the crossword answer was 'ogre'. All of it."],
    ["And he won the hand with a sock.", "And he played every card at once. It counted.", "And I lost the hand, the game and my chair."],
  ],
  "Golf Course at Dawn": [
    ["And I missed the putt.", "And the ball rolled in, then rolled back out to look at him.", "And he putted me instead."],
    ["And the peace lasted about four seconds.", "And he teed off from my head.", "And a goose played through. Then him."],
  ],
  "Hammock between Two Trees": [
    ["And the hammock snapped.", "And now I'm comfy on the ground. Under him.", "And one of the trees left."],
    ["And now I have several cares.", "And we swung so high we did a loop.", "And the hammock filed a complaint."],
  ],
  "Moonlit Fairway": [
    ["And the groundskeeper saw everything.", "And the moon caddied for him.", "And we lost every ball in the dark. Even the glowing one."],
    ["And he howled back. Better than me.", "And the whole course howled along.", "And the moon howled at US."],
  ],
  "Spa Steam Room": [
    ["And my cucumber slices were gone.", "And he relaxed harder than me. Somehow.", "And the cucumbers relaxed too. Into a pickle."],
    ["And when the steam cleared, he'd sweated out a whole second ogre.", "And I sweated so much I was the steam.", "And he turned it up to 'swamp'."],
  ],
  "Swamp Hot Spring": [
    ["And the swamp came up to MY chin too.", "And a croc asked me to move up.", "And the spring was soup now. Ogre soup."],
    ["And the bubbles were his.", "And my bubbles spelled 'HELP'.", "And he blew one big bubble and floated away in it."],
  ],
  "Pool with Floaties": [
    ["And the rubber duck chose him.", "And the duck sank. He didn't.", "And the duck quacked 'no ogres in the pool'."],
    ["And he popped my floatie with his belly.", "And he took my floatie. It fit him like a ring.", "And we both sank. It was nice."],
  ],
  "Ancient Treasure Lounge": [
    ["And the treasure was mostly his old socks.", "And the mountain of treasure slid. With me on top.", "And the treasure belonged to a dragon. Who was home."],
    ["And he took the biggest coin as a tip.", "And I lost count at four. He made me start again.", "And all the gold turned into chocolate coins. He ate them."],
  ],
  "Dragon over the Fairway": [
    ["And the dragon ate my ball.", "And the dragon landed on the green. Penalty stroke.", "And the dragon kept score. It cheated."],
    ["And the dragon asked him for a lesson. Not me.", "And the dragon noticed me.", "And I ignored the dragon so well it went home in a sulk."],
  ],
  "Floating Sky Spa": [
    ["And he massaged me right off the cloud.", "And the masseur was a gryphon. With very sharp hands.", "And it rained, because I was relaxing on the rain."],
    ["And the cloud said he was too heavy and left.", "And I fell off the cloud.", "And the cloud charged me extra for him."],
  ],
  "Ghost Ship Cove": [
    ["And the ghost crew made him captain.", "And the deck was made of fog. I fell through.", "And the ghosts gave him a round of applause."],
    ["And the ghost ship rowed after us.", "And I rowed the wrong way. For hours.", "And the ghost ship waved. Then sank. Then waved again."],
  ],

  bg_rfc: [
    ["And the marshmallows were cultists.", "And the lava toasted me instead.", "And Taragaman ate the lot. Always hungry."],
    ["And the book club made us read the Searing Blade newsletter.", "And the book was 'Ogres and How to Hide From Them'.", "And Jergosh the Invoker gave it one star."],
    ["And all of Oggleflint's post was bills.", "And Oggleflint signed for it with his axe.", "And it was all junk mail from Orgrimmar."],
    ["And they pointed at the lava.", "And there were no toilets. There's never any toilets.", "And the troggs showed us. It was the lava."],
  ],
  bg_wc: [
    ["And Naralex rolled over and said 'five more minutes'.", "And Naralex woke up, saw him, and went back to sleep.", "And it turned out this was Naralex's dream, not mine."],
    ["And I'm still lost. Send help. Bring a map.", "And the fourth hour was worse.", "And we found the exit. It was the entrance."],
    ["And the disciple stopped to chat. Every. Single. Time.", "And the murlocs escorted US.", "And the disciple got lost too. It's the Wailing Caverns."],
    ["And the druid turned into a snake and told me off again.", "And then he got told off too. Same druid.", "And Lord Serpentis said we were both grounded."],
  ],
  bg_dm: [
    ["And the cannon blew the door off. With me on it.", "And the Defias loaded him in the cannon instead.", "And Sneed's shredder helped. Badly."],
    ["And Cookie put me in the soup.", "And the soup had a Defias in it.", "And Cookie served him first. And seconds."],
    ["And the goblins said the food was better than the pay.", "And Gilnid melted my lunch.", "And the goblins asked me to work a shift."],
    ["And Captain Greenskin made me walk the plank. Into a mine.", "And the deck got cleaner, but I didn't.", "And VanCleef had written me a letter about the mop."],
  ],
  bg_sfk: [
    ["And nobody ever came to unlock the cell.", "And he opened the cell door. From the inside.", "And Deathstalker Adamant said he'd been waiting for days. Same."],
    ["And Arugal blinked onto the table and ate the pudding.", "And dinner was worgen-shaped.", "And Arugal said 'I am the pinnacle of dinner hosts'."],
    ["And the wolves walked me instead.", "And Nandos let them all off the lead.", "And Fenrus fetched my leg back. Still attached to me."],
    ["And Silverlaine's portraits all followed us with their eyes.", "And one of the portraits was him. It winked.", "And Silverlaine said they'd been dusty for years. Thanks."],
  ],
  bg_bfd: [
    ["And it turned out I could breathe the whole time.", "And he held his breath longer. Out of spite.", "And Aku'mai ate my snorkel."],
    ["And all the fires went out again.", "And he lit them all with one sneeze.", "And the last fire opened the door to Aku'mai. Whoops."],
    ["And Kelris asked who dared disturb his meditation. It was us.", "And Kelris put us both to sleep.", "And Kelris meditated harder. It didn't help."],
    ["And Ghamoo-ra won by a whole shell.", "And the turtle took a shortcut.", "And Ghamoo-ra asked him for a rematch. Not me."],
  ],
  bg_stocks: [
    ["And the guards locked ME up for it.", "And he started a second riot inside the first one.", "And the riot asked him to keep it down."],
    ["And it turns out I did do it. In the dream.", "And they let him out first.", "And my sentence was nine minutes. Felt like a week."],
    ["And Hamhock snored louder than him.", "And Hamhock moved out.", "And Hamhock ate my bread. And my blanket."],
    ["And I accidentally won the riot.", "And the riot gave up halfway round.", "And he ran the other way. They all followed him."],
  ],
  bg_gnomer: [
    ["And now I glow brighter.", "And I glowed in the dark for a week.", "And the gnomes used me as a nightlight."],
    ["And Thermaplugg pressed the big red button.", "And one of the buttons was 'launch Gnomeregan'.", "And every button did the same thing: radiation."],
    ["And the punch card just said 'NO'.", "And the clean room got very dirty.", "And the machine punched me back."],
    ["And there's a fourth spiral ramp. Nobody knows where it goes.", "And every ramp went down.", "And the gnomes said they'd move back in next week. Any week now."],
  ],
  bg_rfk: [
    ["And I'm still finding thorns.", "And he got me out. By sitting on the thorns.", "And the thorns grew round both of us."],
    ["And I was the barbecue.", "And the quilboar served HIM. Seconds.", "And Charlga burnt the sausages."],
    ["And Willix tripped every trap on purpose.", "And Willix escaped. Without us.", "And Willix said 'is that it?'"],
    ["And Agathelos wanted his mushrooms back.", "And the mushrooms were Agathelos.", "And the boar charged us both."],
  ],
  bg_smgy: [
    ["And the ghosts all clapped.", "And midnight lasted the whole night.", "And Thalnos asked if I wanted to stay forever."],
    ["And we dug up Bloodmage Thalnos. He was not pleased.", "And we found a shovel. Buried by another shovel.", "And I dug a hole big enough for him. He liked it."],
    ["And Vishas said 'tell me everything'. So I did. For hours.", "And Vishas questioned him instead. He just yawned.", "And I told Vishas everything. Even my PIN."],
    ["And Ironspine never came. He never comes.", "And Ironspine came, saw him, and left.", "And we waited so long I became a rare spawn myself."],
  ],
  bg_smlib: [
    ["And Doan set the overdue fine on fire.", "And the book was HIS. He wanted it back.", "And the fine was a hundred years of copying books."],
    ["And the shushing got louder than the noise.", "And he shushed the librarian back.", "And Doan detonated. Loudly. In a library."],
    ["And the only book they had was about the Light. All of it.", "And the book was checked out. By him.", "And the titans wrote it upside down."],
    ["And Loksey walked me back to the entrance.", "And the hounds ate my homework.", "And Loksey shouted 'release the hounds' at me. I was a hound."],
  ],
  bg_smarm: [
    ["And the dummies hit back.", "And he was a training dummy the whole time.", "And the dummies asked for a raise."],
    ["And none of the helmets fit.", "And the helmets all fit him.", "And the shoulders were never seen again."],
    ["And a hundred trainees poured out behind us.", "And he got to the front of the queue. Somehow.", "And the queue was for Herod's whirlwind. Oops."],
    ["And Herod had been waiting for a real challenge. It wasn't me.", "And the axe was so sharp it cut the dream short.", "And Herod made me run laps."],
  ],
  bg_smcath: [
    ["And Whitemane said 'Arise!' and everyone stood up. Even the dead ones.", "And the sermon was about him.", "And he sang the hymn. In ogre. Very loud."],
    ["And the whole crusade noticed me.", "And Whitemane put me to sleep. Best nap ever.", "And I hid behind him. Not a good hiding spot."],
    ["And Fairbanks had been behind the door the whole time.", "And the altar was very loud about it.", "And Fairbanks asked me not to tell anyone. Oops."],
    ["And Mograine's armour was shinier than his reputation.", "And Mograine asked me to do the back too.", "And I polished my face in it."],
  ],
  bg_rfd: [
    ["And the gong brought spiders. So many spiders.", "And he rang it with his head.", "And Tuten'kash knocked on the gong to get back in."],
    ["And Amnennar froze my tea.", "And he lent me his breath. It was warm. And terrible.", "And I froze into a nice statue."],
    ["And Belnistrasz needed just one more minute. For an hour.", "And the quilboar held ME off.", "And Belnistrasz chanted a lullaby by mistake."],
    ["And the Glutton ate the picnic, the blanket and the basket.", "And the Glutton ate HIM. Then gave him back.", "And the Glutton brought sandwiches. Made of quilboar."],
  ],
  bg_ulda: [
    ["And the instructions were upside down.", "And step one was 'wake Archaedas'. Oops.", "And the instructions were in titan. And dwarvish. And ogre."],
    ["And Archaedas woke up and was NOT happy.", "And the keeper poked back.", "And all the statues woke up at once. All of them."],
    ["And the disc just played elevator music.", "And the disc was a dinner plate.", "And the Platinum Disc said 'insert coin'."],
    ["And Eric, Olaf and Baelog kept arguing about who was the fastest.", "And the dwarves found us. We were lost.", "And Baelog's cache was a sandwich."],
  ],
  bg_zf: [
    ["And there were more trolls. There were always more trolls.", "And the trolls brought snacks.", "And we waited so long the trolls went home."],
    ["And the trolls gave me directions. To more trolls.", "And he lent me his shade.", "And Antu'sul said lunch had arrived. Lunch was me."],
    ["And Sergeant Bly turned on us. He always turns on us.", "And he broke us out. With his face.", "And the cage was a dining table."],
    ["And Gahz'rilla came out of the pool and wanted a hug.", "And the gong was very, very loud. And so was Gahz'rilla.", "And he banged the gong with my head."],
  ],
  bg_mara: [
    ["And everything tasted purple.", "And the crystals licked back.", "And I glowed purple for a week."],
    ["And the waterfall turned out to be Theradras crying.", "And Tinkerer Gizlock blew up the waterfall.", "And the waterfall went sideways when he sat in it."],
    ["And the Scepter had one piece left over. It's always one piece.", "And the Scepter was a stick. A good stick.", "And Celebras said 'thanks, but that's upside down'."],
    ["And the orange way was, as always, wrong.", "And the orange way was full of satyrs. And him.", "And we went the purple way after. Also wrong."],
  ],
  bg_st: [
    ["And I got the statue order wrong. Again.", "And the statues did it themselves.", "And the puzzle solved me."],
    ["And we came up with gills.", "And Atal'Hakkar was even wetter than I thought.", "And Eranikus was having the same dream."],
    ["And the egg hatched Hakkar. Oops.", "And the egg hatched him.", "And the egg wanted its mum."],
    ["And the green dragons snored louder.", "And I woke up a dragon. It wasn't happy.", "And Eranikus said he was having a nightmare. About me."],
  ],
  bg_brd: [
    ["And Plugger Spazzring kicked us both out.", "And the sixth ale was him.", "And I was so drunk I started the Grim Guzzler riot."],
    ["And the crowd cheered for him. Not me.", "And the Ring of Law found me guilty. Of what? Everything.", "And High Justice Grimstone made him champion."],
    ["And Rocknot drank all of it. Every single keg.", "And Rocknot asked for ogre ale. We didn't have any.", "And Rocknot passed out on him."],
    ["And Moira married the Emperor anyway.", "And Moira rescued US.", "And Moira said 'I'm fine, thanks, go home'."],
  ],
  bg_lbrs: [
    ["And Mother Smolderweb adopted me.", "And the eggs hatched behind me.", "And he stepped on every egg."],
    ["And the orcs made me do the dishes.", "And the orcs made him a captain.", "And I joined the Blackrock by accident."],
    ["And the seal just said 'ask Vaelan'.", "And the seal was a sticker.", "And Vaelan asked us to bring back everything, again."],
    ["And Omokk fell off the edge. Every time. Every single time.", "And the boots were mine.", "And Omokk said I missed a bit."],
  ],
  bg_ubrs: [
    ["And the plan lasted four seconds. Leeroy, of course.", "And somebody worked out a 32.33, repeating, percent chance.", "And at least we had chicken."],
    ["And Nefarian gave him a better score.", "And Rend Blackhand complained about the commentary.", "And Nefarian said 'well, this isn't going well'."],
    ["And all the eggs hatched at once.", "And I counted one more egg than there was. It was him.", "And the whelps came out counting us."],
    ["And the Emberseer was very hot about it.", "And all the runes lit at once. On him.", "And the Emberseer got out and said thanks. Then attacked."],
  ],
  bg_dme: [
    ["And Pusillin got away. He always gets away.", "And Pusillin had the key the whole time. Of course he did.", "And Pusillin chased US."],
    ["And Alzzin turned me into a shrub.", "And the garden grew over us.", "And Hydrospawn watered the plants. With me."],
    ["And Old Ironbark took his time. Trees always take their time.", "And Ironbark said 'thank you, young one'. To him.", "And I held the door for a hundred years."],
    ["And Lethtendris liked his wings better.", "And Lethtendris trimmed my hair instead.", "And her imp Pimgib said they were perfect already."],
  ],
  bg_dmw: [
    ["And the ghosts made me write an essay.", "And the books whispered spoilers.", "And the highborne asked him to keep it down."],
    ["And Immol'thar wanted his dinner.", "And Immol'thar was pleased. Too pleased.", "And Immol'thar said 'about time'."],
    ["And there were five pylons. I only found four.", "And the pylons switched back on.", "And he sat on the last one."],
    ["And Tortheldrin drained all the magic out of my tea.", "And I forgot my manners. All of them.", "And the prince said his manners were better than mine."],
  ],
  bg_dmn: [
    ["And the ogres made HIM king. Again.", "And the tribute was a nice chest and a nap.", "And King Gordok asked for a tribute. It was me."],
    ["And Cho'Rush said I was the worst ogre he'd ever seen.", "And Mizzle said 'The king is dead! Long live the king!'", "And he said 'nice suit'. He meant it."],
    ["And Kreeg drank all the stock himself.", "And Kreeg sold us water. For gold.", "And Kreeg's shop is now his shop."],
    ["And Knot just tied himself back up again.", "And Knot gave me a gnome hat.", "And Knot said thanks and fixed my shoes."],
  ],
  bg_scholo: [
    ["And my homework got up and walked away.", "And the homework did itself. Badly.", "And Gandling said 'see me after class'."],
    ["And Gandling locked us both in a room.", "And Gandling put him in the cellar. And me.", "And I got there before Gandling. He was already teaching."],
    ["And Kirtonos flapped off with the brazier.", "And the brazier lit me.", "And Kirtonos turned into a bat. Then into him."],
    ["And Jandice turned out to be twelve Jandices.", "And the illusion was me.", "And Jandice said the real show was him."],
  ],
  bg_stratl: [
    ["And Postmaster Malown said it was MY letter.", "And the post was all bones.", "And Malown delivered HIM."],
    ["And it rained. It didn't help.", "And the whole city was on fire. Again. Still.", "And it turned out the Grand Crusader was a dreadlord all along."],
    ["And every postbox had a ghoul in it.", "And the postboxes opened me.", "And the last postbox had a letter for me. From me."],
    ["And the books all burned. It's Stratholme.", "And Galford said 'not THAT one!'", "And Grand Crusader Dathrohan borrowed a book. Never brought it back."],
  ],
  bg_stratu: [
    ["And we didn't make it in time.", "And he made it in thirty. Show-off.", "And Ysida Harmon said 'took your time, didn't you?'"],
    ["And the ziggurats were full of very grumpy acolytes.", "And Maleki the Pallid went even paler.", "And the ziggurats all fell over. Like dominoes."],
    ["And Ramstein the Gorger ate the clock.", "And Ramstein came. Hungry.", "And the slaughterhouse door was made of abominations."],
    ["And Anastari wore it once, then possessed me.", "And the scarf possessed her.", "And she knitted him one back."],
  ],
  bg_thanes: [
    ["And somebody above us in Ironforge shouted 'keep it down'.", "And the thanes asked for a toast. In dwarvish.", "And the hall was so deep I came out in Gnomeregan."],
    ["And the forge went out.", "And the forge lit his eyebrows.", "And Dirgehammer warmed his hands too. Then played a dirge."],
    ["And one of the names was mine. Spelled wrong.", "And the whole hall argued about the War of the Three Hammers.", "And one of the names was 'Ogre'. Just 'Ogre'."],
    ["And the thane sneezed.", "And the beard was stone. My brush broke.", "And the thane's beard grew back. On me."],
  ],
  bg_ruins: [
    ["And the throne was very uncomfortable.", "And the throne was warm. Somebody had just left.", "And he sat on the throne too. It cracked."],
    ["And somebody kept saying 'succeeding you, father'.", "And the king got back up, just to leave.", "And the ghost of Terenas asked us to wipe our feet."],
    ["And they all blew back in again.", "And the petals were his.", "And he swept them all under the throne."],
    ["And dusk lasted all night.", "And the sun set, then rose, then set again.", "And the Forsaken below us asked us to keep the noise down."],
  ],
  bg_excav: [
    ["And the bones were his.", "And the bones got up and helped.", "And the archaeologists put him in a museum."],
    ["And the golem chased him instead. Finally.", "And Guardian Stoneskin said his skin was perfectly soft, thanks.", "And the golem was just lonely."],
    ["And the Explorers' League named the dig after him.", "And every fossil was labelled 'ogre'.", "And I'm now an exhibit."],
    ["And the raptors brought their own tent.", "And the tent was a raptor.", "And it rained the whole time. It's the Wetlands."],
  ],
  bg_ony: [
    ["And Onyxia took a deep breath.", "And I stood right in front of her.", "And she breathed on him. He just yawned."],
    ["And fifty DKP minus.", "And someone shouted 'MORE DOTS!'", "And all forty of us wiped. All forty."],
    ["And it was many whelps. He handled it.", "And the whelps feared me back out.", "And I got feared into his arms."],
    ["And she turned round. Slowly.", "And she flew up. Phase two. Oh no.", "And her tail swept us both into the whelp caves."],
  ],
  bg_barrow: [
    ["And all the druids were dreaming about me.", "And Malfurion asked us to keep it down.", "And I fell asleep too. For a thousand years."],
    ["And everyone woke up.", "And I'd been asleep for a thousand years too.", "And Ysera said this was a members-only dream."],
    ["And the tiptoeing woke the whole barrow anyway.", "And the dens tiptoed after us.", "And the Emerald Dream had a nightmare about us."],
    ["And the bear tucked ME in.", "And the bear asked for a bedtime story.", "And the druid turned back into an elf. Very cross."],
  ],
  bg_hyjal: [
    ["And the World Tree said 'shh'.", "And the World Tree gave him a leaf.", "And Nordrassil said we were standing on its toes."],
    ["And Archimonde fell off the tree.", "And the line held. Barely. Thanks to him.", "And Jaina and Thrall and Tyrande all said 'not again'."],
    ["And Cenarius came, but just to complain about the noise.", "And the horn played a tuba solo.", "And Cenarius said the horn was for emergencies. This wasn't one."],
    ["And the wisps blew up. Very politely.", "And the wisps put HIM in a jar.", "And the jar was Archimonde's."],
  ],
};
