-- What the Pro Shop's steward says while he rings up your cart (ProShopRoom.lua's till): a snooty club steward, dry
-- and politely rude to the buyer. Written by the storyteller agent (.claude/agents/storyteller.md, "The steward's
-- lines"); `node tools/check-steward-lines.js` lists the shop pieces with no line yet ("NO STEWARD LINE").
--   pieces[option id]   a piece's own lines (one is picked at random when it's rung up)
--   layers[layer key][rarity]   for a piece with none of its own (and the name colours: layers.name): %s = its name
--   open, empty, total (%s = the sum), bag   the sale's other moments

local _, ns = ...

ns.StewardLines = {
    open = {
        "Ahem. Let us see what we have here.",
    },
    empty = {
        "Nothing to ring up? Then do stop loitering.",
        "Browsing, are we. How... thrifty.",
        "The mannequin does not bite. Usually.",
    },
    total = {
        "That comes to %s points. Shall I wrap it? Or will you be wearing it out of the shop like a barbarian?",
    },
    bag = {
        "Splendid. Do carry it with both hands. It's a nice bag.",
    },
    layers = {
        outfit = {
            uncommon = { "%s. A sensible choice. For you." },
            rare = { "%s. Well. Someone has been saving up." },
            epic = { "%s. I shall try not to weep as it leaves the shop." },
            legendary = { "%s. Do try to deserve it." },
        },
        headwear = {
            uncommon = { "%s. It will cover most of the problem." },
            rare = { "%s. Do mind the doorframes." },
            epic = { "%s. A hat with ambitions. Unlike some." },
            legendary = { "%s. Even the head beneath it improves." },
        },
        name = {  -- (a name colour, "%s" its name)
            common = { "%s. Your name, in colour. It won't make it any shorter." },
            uncommon = { "%s. Your name, in colour. It won't make it any shorter." },
            rare = { "%s. People will read your name now. Do brace yourself." },
            epic = { "%s on a name like yours. Bold." },
            legendary = { "%s. A colour fit for a member. Very nearly." },
        },
        accessory = {
            uncommon = { "%s. Something to hold. Other than a grudge." },
            rare = { "%s. Do try not to drool on it." },
            epic = { "%s. It will lend you an air. Any air at all." },
            legendary = { "%s. Members have wept for less." },
        },
    },
    pieces = {
        -- headwear
        shop_flat_cap = { "A tweed flat cap. All the old golfer, none of the golf.", "The flat cap. Pull the brim low. Lower. There." },
        shop_tam_pompom = { "A tartan tam. The pom-pom will draw the eye from the face.", "Red and green tartan. Bold. Like your handicap." },
        shop_panama = { "The clubhouse panama. Shade for a face that needs it.", "A panama with our club band. Do try not to sweat on it." },
        shop_golfball_hat = { "A golf ball for a hat. I shan't ask.", "The golf ball helmet. Do duck when somebody shouts 'fore'." },
        shop_putting_green_hat = { "Hole in One. The only one you'll ever get.", "A putting green for the head. Do keep it away from the gopher." },
        shop_bowler_hat = { "A bowler. Very proper. One of us should be.", "The bowler hat. It cannot help the head, but it can hide it." },
        shop_straw_boater = { "A straw boater. Flat on top, much like your conversation.", "The boater. For saying 'what ho' to people who'd rather you didn't." },
        shop_smoking_cap = { "The smoking cap. Velvet, a tassel, and delusions of grandeur.", "A smoking cap. Do keep the tassel out of the soup." },
        shop_yacht_cap = { "The commodore's cap. Do you own a yacht? No. Of course not.", "Gold braid and an anchor. The duck pond will be thrilled." },
        shop_service_bell = { "A service bell. On your head. Do not expect service.", "The bell. Ring it, and I shall pretend not to hear." },
        -- outfits
        shop_argyle_vest = { "The argyle vest. Diamonds, finally within your budget.", "Argyle. For gentlemen who explain golf at dinner." },
        shop_caddie_bib = { "The caddie's bib. Number nineteen. At last, a job.", "A caddie's bib. It suits you. Carry this to the door, would you?" },
        shop_tennis_whites = { "Tennis whites. The jumper goes on the shoulders, not the legs.", "All white. Brave, for someone who eats like you." },
        shop_loud_windbreaker = { "The loud windbreaker. I can hear it from here.", "Orange, teal and purple. The colours of a headache." },
        shop_norfolk_jacket = { "The Norfolk jacket. Tweed, a belt and patience. Two out of three.", "Patch pockets. Somewhere to keep your excuses." },
        shop_smoking_jacket = { "Velvet and quilted satin. The armchair will be jealous.", "The smoking jacket. For lounging. You've had practice." },
        shop_yacht_blazer = { "The regatta blazer. Stripes. The boat is not included.", "Navy and white, anchor on the pocket. Do try not to sink." },
        shop_tuxedo = { "The tuxedo. Black tie. Do learn to tie it.", "A tuxedo with a carnation. The carnation will do most of the work." },
        shop_champions_jacket = { "The champion's jacket. Usually one wins it first.", "Green with gold buttons. Earned, not bought. Well. Bought." },
        shop_founders_robe = { "The founder's robe. You founded nothing. Still. Ermine.", "Purple velvet and a chain of office. Please don't start a club." },
        -- accessories
        shop_champagne_flute = { "A champagne flute. Pinky out. No, the other pinky.", "Crystal. Do hold it by the stem, not in your fist." },
        shop_putter = { "The trusty putter. More trusty than the hands holding it.", "A putter. The green has already heard about you." },
        shop_tennis_racket = { "A wooden racket. An antique, like your backhand.", "The tennis racket. The courts are that way. Far that way." },
        shop_driver = { "The big driver. Do warn the clubhouse windows.", "A polished wooden driver. Long, handsome, and wasted on you." },
        shop_golf_bag = { "The golf bag. Knitted head covers. Your nan would approve.", "A full golf bag. Fourteen clubs, and still no excuse." },
        shop_gopher = { "The course gopher. We've been trying to get rid of him. Thank you.", "He's asleep on a stolen ball. You two will get on." },
        shop_lapdog = { "The poodle. Better groomed than the buyer, I'm afraid.", "A pampered poodle. Do not wake her. She bites members." },
        shop_club_key = { "The golden club key. Please do not let yourself in.", "A key to the club. I shall be changing the locks." },
        shop_trophy_cup = { "The champion's cup. Bought, not won. I shall tell no one. Much.", "A golden cup. The little golfer on the lid looks disappointed too." },
    },
}
