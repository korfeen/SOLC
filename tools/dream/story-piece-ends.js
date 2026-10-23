// Each hat, outfit and skin's own endings, by option id: a punchline about that piece, true wherever the dream is
// ("And his onesie said 'MRGLGLGL' at the wrong moment."). Two per piece, starting "And ", about "his" piece.
// The lines live in story-ends-*.js (one file per group of pieces), each adding to this table:
//   Object.assign(PIECE_ENDS, { "crit_murloc_body": ["And ...", "And ..."], ... });
const PIECE_ENDS = {};
