// The end bosses' gear as picture layers (tools/make-unlock-art.js): one piece per dungeon, in its chest with the
// backdrop and the boss skin. Each is a headwear, an outfit or an accessory, drawn in crayon on the minting art's 1254
// canvas so it fits every skin (the boss skins too):
// - headwear sits on the head: its top about y 120, x 470..800 at the brow (y 200), the face below (x 515..745,
//   y 205..410) left clear;
// - an outfit fills the base outfit's shape (h.outfitFill: the striped pyjamas' outline), body only;
// - an accessory floats in a top corner (x 80..380 or 880..1180, y 60..380) or perches on a shoulder (about (330, 430)
//   or (930, 430)), where it shows round any outfit and hat.
// Each end boss has a set of three: a headwear, an outfit and a charm (an accessory: the last layer drawn, over the rest,
// so it can be anything: a pet, a relic, a weapon), so the boss skin wearing all three is the whole boss. Keyed by the
// dungeon keys (Achievements.lua), upper case: { head, body, charm } = { name, draw }. (G below: the first piece drawn
// for each; SETS builds the rest of each set from the pieces H, B and C.)

module.exports = (h) => {
  const { fill, soft, line, dab, circle, ellipse, star, quad, rotate, hex, OUTLINE, outfitFill, outfitOutline } = h;
  const HX = 632;
  const both = (draw) => { draw((p) => p); draw((pts) => pts.map(([x, y]) => [2 * HX - x, y])); };

  // --- Pieces ---
  // A helm's dome over the head with a band at the brow.
  function dome(c, r, col, band, top = 20) {
    fill(c, [...quad([462, 222], [HX, top - 120], [802, 222], 20)], col, r);
    fill(c, [[456, 190], [808, 190], [812, 232], [452, 232]], band || col, r);
  }
  // A hood round the head, the face left open.
  function hood(c, r, col, lining) {
    const outer = [...quad([400, 520], [380, 40], [HX, 10], 18), ...quad([HX, 10], [884, 40], [864, 520], 18).slice(1)];
    fill(c, outer, col, r, { holes: [ellipse(HX, 290, 160, 190)] });
    if (lining) line(c, ellipse(HX, 290, 166, 196).concat([[HX + 166, 290]]), 14, lining, r);
  }
  function crownOf(c, r, col, gem, spikes = 5, low = 214, high = 60) {
    const pts = [[452, low]];
    for (let i = 0; i <= spikes * 2; i++) {
      const x = 452 + (i / (spikes * 2)) * 360;
      pts.push([x, i % 2 ? low - 50 : high + Math.abs(i - spikes) * 8]);
    }
    pts.push([812, low]);
    fill(c, pts, col, r);
    if (gem) for (let i = 1; i < spikes; i++) fill(c, circle(452 + (i / spikes) * 360, low - 26, 18), gem, r, { line: 10, hatch: 8 });
  }
  const floating = (c, r, x, y, glow) => { if (glow) soft(c, circle(x, y, 110), glow, r, { hatch: 24 }); };
  function sparkle(c, r, x, y, s, col) { fill(c, star(x, y, s, s * 0.4), col, r, { line: 8 }); }
  // Bands across an outfit (keep: which part of the outfit a colour goes on).
  const stripes = (size) => (x, y) => Math.floor(y / size) % 2 === 0;

  const G = {
    // --- Headwear ---
    WC: { layer: "headwear", name: "Druid of the Fang Hood", draw(c, r) {
      hood(c, r, "#3a7a3a", "#a8d070");
      fill(c, [[HX - 60, 40], [HX, -40], [HX + 60, 40], [HX, 80]], "#6ab04a", r);  // the serpent's head on top
      for (const x of [HX - 22, HX + 22]) dab(c, x, 20, 9, hex("#ffd23f"), 0.95);
    } },
    BFD: { layer: "headwear", name: "Twilight Cowl", draw(c, r) {
      hood(c, r, "#2a2a5a", "#7a6ad8");
      fill(c, ellipse(HX, 110, 46, 26), "#ffd23f", r, { line: 10 });  // the Twilight eye
      dab(c, HX, 110, 12, OUTLINE, 0.95);
    } },
    GNOMER: { layer: "headwear", name: "Tinker's Goggle Cap", draw(c, r) {
      dome(c, r, "#8a5a30", "#6a4020", 40);
      for (const x of [578, 686]) {  // goggles pushed up on the cap
        fill(c, circle(x, 168, 44), "#d0a040", r, { holes: [circle(x, 168, 28)] });
        fill(c, circle(x, 168, 28), "#9fe8ff", r, { line: 8 });
      }
      line(c, [[HX, -20], [HX + 30, -90]], 12, "#5a5f66", r);
      fill(c, circle(HX + 34, -100, 18), "#ff4a3a", r, { line: 8 });
    } },
    RFK: { layer: "headwear", name: "Quilboar Bone Helm", draw(c, r) {
      fill(c, [...quad([462, 226], [HX, -60], [802, 226], 18)], "#e8dcc0", r);  // a skull cap
      for (const x of [560, 704]) dab(c, x, 150, 22, OUTLINE, 0.95);
      both((m) => fill(c, m([[480, 200], [380, 120], [400, 60], [460, 160]]), "#f4f0e0", r, { line: 12 }));  // tusks
      for (let i = 0; i < 5; i++) fill(c, [[540 + i * 46, 60 - (i % 2) * 20], [552 + i * 46, -40], [568 + i * 46, 60]], "#c8b890", r, { line: 8 });
    } },
    SMARM: { layer: "headwear", name: "Scarlet Crusader Helm", draw(c, r) {
      dome(c, r, "#c02a2a", "#c0c8d0", 30);
      fill(c, [[HX - 16, 40], [HX + 16, 40], [HX + 16, 200], [HX - 16, 200]], "#ffd23f", r, { line: 10 });  // a gold ridge
      fill(c, circle(HX, 140, 34), "#ffd23f", r, { line: 10 });
    } },
    RFD: { layer: "headwear", name: "Coldbringer's Ice Crown", draw(c, r) {
      for (let i = 0; i < 9; i++) {
        const x = 466 + i * 41, ht = 90 + (i % 2 ? 0 : 60) + (i === 4 ? 70 : 0);
        fill(c, [[x - 22, 214], [x, 214 - ht - 60], [x + 22, 214]], "#c8f0ff", r, { line: 10 });
      }
      fill(c, [[452, 196], [812, 196], [812, 228], [452, 228]], "#9fc8e8", r);
    } },
    ZF: { layer: "headwear", name: "Sandfury Headdress", draw(c, r) {
      for (let i = 0; i < 7; i++) {  // a fan of feathers
        const a = Math.PI * (1.15 + i * 0.117), x = HX + Math.cos(a) * 300, y = 220 + Math.sin(a) * 300;
        fill(c, rotate(ellipse((HX + x) / 2, (220 + y) / 2, 30, 150), a + Math.PI / 2, (HX + x) / 2, (220 + y) / 2),
          i % 2 ? "#e04a2a" : "#ffd23f", r, { line: 10 });
      }
      fill(c, [[452, 186], [812, 186], [812, 232], [452, 232]], "#c89a5a", r);
      for (let x = 480; x <= 790; x += 50) dab(c, x, 209, 12, hex("#4f86e8"), 0.95);
    } },
    THANES: { layer: "headwear", name: "Thane's Winged Helm", draw(c, r) {
      dome(c, r, "#9aa0a8", "#ffd23f", 30);
      both((m) => fill(c, m([[470, 170], [300, 40], [360, 120], [280, 120], [380, 180], [300, 210], [464, 214]]), "#f4f4f0", r));  // wings
    } },
    BRD: { layer: "headwear", name: "Dark Iron Crown", draw(c, r) { crownOf(c, r, "#3a3236", "#ff4a3a", 5, 220, 40); } },
    DME: { layer: "headwear", name: "Satyr Horns", draw(c, r) {
      both((m) => fill(c, m([...quad([520, 180], [380, 130], [370, -10], 14), ...quad([370, -10], [430, 100], [560, 150], 14).slice(1)]), "#8a6a4a", r));
      fill(c, [[460, 200], [804, 200], [804, 228], [460, 228]], "#3a7a3a", r);  // a vine band
      for (const x of [500, 580, 680, 760]) fill(c, ellipse(x, 214, 20, 12), "#5bd24a", r, { line: 6, hatch: 6 });
    } },
    DMN: { layer: "headwear", name: "Gordok Crown", draw(c, r) {
      crownOf(c, r, "#ffd23f", "#c02a2a", 4, 214, 20);
      for (const x of [440, 824]) { fill(c, circle(x, 60, 30), "#f0ece0", r, { line: 10 }); dab(c, x - 10, 58, 7, OUTLINE, 0.9); dab(c, x + 10, 58, 7, OUTLINE, 0.9); }
    } },
    STRATU: { layer: "headwear", name: "Rivendare's Helm", draw(c, r) {
      dome(c, r, "#3a3a44", "#5a5f66", 10);
      for (const [x, ht] of [[500, 120], [HX, 180], [764, 120]]) fill(c, [[x - 24, 110], [x, 110 - ht], [x + 24, 110]], "#5a5f66", r, { line: 10 });
      fill(c, circle(HX, 150, 24), "#7ad8ff", r, { line: 8 });  // a cold rune
    } },
    BARROW: { layer: "headwear", name: "Moonleaf Circlet", draw(c, r) {
      line(c, quad([456, 214], [HX, 170], [808, 214], 20), 18, "#c8c0e8", r);
      fill(c, [[HX - 34, 150], [HX, 70], [HX + 34, 150], [HX, 180]], "#e8e0ff", r, { line: 10 });  // a moon gem
      both((m) => { for (const [x, y] of [[520, 186], [480, 200]]) fill(c, m(rotate(ellipse(x, y - 30, 16, 40), -0.6, x, y)), "#7ab07a", r, { line: 8, hatch: 6 }); });
    } },
    // --- Outfits ---
    DM: { layer: "outfit", name: "Defias Leathers", draw(c, r) {
      const sash = (x, y) => Math.abs((y - 500) - (x - 300) * 0.75) < 70;  // a red sash across
      outfitFill(c, "#6a4a2a", r, (x, y) => !sash(x, y));
      outfitFill(c, "#c02a2a", r, sash);
      outfitOutline(c, r);
      fill(c, [[600, 720], [680, 720], [680, 790], [600, 790]], "#d0a040", r, { line: 10 });  // the buckle
      for (const y of [560, 900]) line(c, [[360, y], [900, y]], 8, "#4a3018", r);
    } },
    STOCKS: { layer: "outfit", name: "Prison Stripes", draw(c, r) {
      outfitFill(c, "#f0ece0", r, stripes(70));
      outfitFill(c, "#2a2228", r, (x, y) => !stripes(70)(x, y));
      outfitOutline(c, r);
      fill(c, [[700, 560], [860, 560], [860, 640], [700, 640]], "#f8f4e8", r, { line: 10 });  // a number patch
      for (const x of [730, 770, 810]) line(c, [[x, 575], [x, 625]], 8, OUTLINE, r);
    } },
    SMCATH: { layer: "outfit", name: "Scarlet Robe", draw(c, r) {
      outfitFill(c, "#c02a2a", r, (x) => x < 560 || x > 700);
      outfitFill(c, "#f8f0e0", r, (x) => x >= 560 && x <= 700);
      outfitOutline(c, r);
      fill(c, circle(630, 700, 54), "#ffd23f", r, { line: 14 });
      line(c, [[630, 664], [630, 736]], 10, "#c02a2a", r);
      line(c, [[594, 700], [666, 700]], 10, "#c02a2a", r);
    } },
    RUINS: { layer: "outfit", name: "Lordaeron Royal Tabard", draw(c, r) {
      outfitFill(c, "#2a4a9a", r, (x) => x < 540 || x > 720);
      outfitFill(c, "#f4f0e0", r, (x) => x >= 540 && x <= 720);
      outfitOutline(c, r);
      fill(c, [[630, 620], [700, 700], [630, 800], [560, 700]], "#ffd23f", r, { line: 12 });  // the crest
      for (const x of [540, 720]) line(c, [[x, 400], [x, 1250]], 10, "#ffd23f", r);
    } },
    LBRS: { layer: "outfit", name: "Blackrock Plate", draw(c, r) {
      outfitFill(c, "#3a3236", r);
      outfitOutline(c, r);
      for (const y of [600, 760, 920, 1080]) line(c, quad([200, y], [630, y + 40], [1060, y], 20), 10, "#1a1418", r);  // plates
      fill(c, circle(630, 700, 60), "#c02a2a", r, { line: 14 });  // the Blackrock emblem
      fill(c, [[600, 670], [660, 670], [630, 740]], "#1a1418", r, { outline: null });
    } },
    HYJAL: { layer: "outfit", name: "Wild Bark Armor", draw(c, r) {
      outfitFill(c, "#6a4a2a", r);
      outfitOutline(c, r);
      for (let x = 220; x < 1060; x += 90) line(c, quad([x, 420], [x + 30, 800], [x - 10, 1240], 16), 10, "#4a3018", r);  // the grain
      for (let i = 0; i < 14; i++) {
        const x = 260 + (i * 137) % 760, y = 480 + (i * 91) % 620;
        fill(c, rotate(ellipse(x, y, 22, 40), i, x, y), i % 2 ? "#5bd24a" : "#3a9a3a", r, { line: 8, hatch: 6 });
      }
    } },
    // --- Accessories ---
    RFC: { layer: "accessory", name: "Ragefire Ember", draw(c, r) {
      floating(c, r, 1040, 200, "#9aff5a");
      fill(c, [...quad([980, 280], [960, 160], [1040, 70], 10), ...quad([1040, 70], [1120, 160], [1100, 280], 10).slice(1)], "#7aff4a", r);
      soft(c, [...quad([1010, 270], [1000, 200], [1040, 150], 8), ...quad([1040, 150], [1080, 200], [1070, 270], 8).slice(1)], "#e8ffd0", r);
    } },
    SFK: { layer: "accessory", name: "Worgen Pup", draw(c, r) {  // on his left shoulder
      fill(c, ellipse(320, 430, 90, 64), "#7a7480", r);
      fill(c, circle(290, 350, 62), "#8a8490", r);
      for (const x of [252, 324]) fill(c, [[x - 20, 310], [x, 250], [x + 22, 316]], "#6a6470", r, { line: 10 });
      for (const x of [270, 312]) dab(c, x, 346, 10, hex("#ffd23f"), 0.95);
      fill(c, ellipse(290, 384, 22, 14), "#3a3236", r, { line: 8 });
    } },
    SMGY: { layer: "accessory", name: "Ghostly Lantern", draw(c, r) {
      floating(c, r, 220, 230, "#9fe8ff");
      line(c, [[220, 100], [220, 140]], 10, "#3a3236", r);
      fill(c, [[170, 150], [270, 150], [260, 300], [180, 300]], "#5a5f66", r);
      soft(c, ellipse(220, 230, 34, 54), "#c8f0ff", r);
      fill(c, [[160, 140], [280, 140], [270, 160], [170, 160]], "#3a3236", r, { line: 8 });
    } },
    SMLIB: { layer: "accessory", name: "Floating Spellbook", draw(c, r) {
      floating(c, r, 1030, 220, "#b0a0ff");
      fill(c, [[900, 250], [1030, 222], [1160, 250], [1160, 346], [1030, 318], [900, 346]], "#c02a2a", r);  // the cover, behind
      fill(c, [[914, 236], [1030, 212], [1030, 304], [914, 330]], "#f8ecc8", r, { line: 12 });  // the pages
      fill(c, [[1030, 212], [1146, 236], [1146, 330], [1030, 304]], "#f8ecc8", r, { line: 12 });
      for (const y of [250, 272, 294]) {
        line(c, [[934, y + 6], [1012, y - 12]], 5, "#8a7050", r);
        line(c, [[1048, y - 12], [1126, y + 6]], 5, "#8a7050", r);
      }
      for (const [x, y] of [[960, 150], [1080, 120], [1020, 170]]) sparkle(c, r, x, y, 22, "#e0d8ff");
    } },
    ULDA: { layer: "accessory", name: "Platinum Disc", draw(c, r) {
      floating(c, r, 220, 220, "#5ac8ff");
      fill(c, circle(220, 220, 90), "#d8dce0", r, { holes: [circle(220, 220, 30)] });
      for (let i = 0; i < 6; i++) { const a = (i / 6) * 2 * Math.PI; dab(c, 220 + Math.cos(a) * 60, 220 + Math.sin(a) * 60, 9, hex("#5ac8ff"), 0.95); }
    } },
    MARA: { layer: "accessory", name: "Crystal Shard", draw(c, r) {
      floating(c, r, 1040, 210, "#e0a0ff");
      fill(c, [[1040, 60], [1100, 180], [1060, 340], [1000, 200]], "#b07aff", r);
      line(c, [[1040, 80], [1050, 320]], 6, "#e8d0ff", r);
    } },
    EXCAV: { layer: "accessory", name: "Ancient Relic", draw(c, r) {
      floating(c, r, 220, 220, "#5ac8ff");
      fill(c, rotate([[150, 120], [290, 120], [300, 330], [140, 330]], -0.15, 220, 225), "#8a8078", r);
      for (const [x, y] of [[200, 180], [240, 230], [200, 280]]) fill(c, star(x, y, 16, 6), "#9fe8ff", r, { line: 6 });
    } },
    ST: { layer: "accessory", name: "Dream Wisp", draw(c, r) {
      floating(c, r, 1040, 200, "#7ad86a");
      fill(c, circle(1040, 200, 50), "#c8ffb0", r);
      line(c, quad([1040, 250], [1000, 320], [1060, 380], 10), 16, "#9ae88a", r);
      for (const [x, y] of [[960, 140], [1110, 120], [1120, 280]]) sparkle(c, r, x, y, 18, "#e8ffe0");
    } },
    UBRS: { layer: "accessory", name: "Black Dragon Egg", draw(c, r) {
      floating(c, r, 1040, 230, "#ff7a1a");
      fill(c, ellipse(1040, 230, 74, 100), "#2a2228", r);
      line(c, [[1010, 170], [1040, 210], [1020, 250], [1060, 290]], 8, "#ff9a2a", r);  // glowing cracks
      line(c, [[1080, 190], [1060, 230]], 6, "#ff9a2a", r);
    } },
    DMW: { layer: "accessory", name: "Arcane Orb", draw(c, r) {
      floating(c, r, 220, 210, "#7ad8ff");
      fill(c, circle(220, 210, 64), "#7ab0ff", r);
      soft(c, circle(200, 190, 26), "#e8f8ff", r);
      line(c, ellipse(220, 210, 104, 30).concat([[324, 210]]), 8, "#c8f0ff", r);  // a ring round it
    } },
    SCHOLO: { layer: "accessory", name: "Floating Skull", draw(c, r) {
      floating(c, r, 1040, 210, "#b07aff");
      fill(c, circle(1040, 200, 70), "#f0ece0", r);
      fill(c, [[1000, 250], [1080, 250], [1070, 300], [1010, 300]], "#f0ece0", r, { line: 12 });
      for (const x of [1012, 1068]) dab(c, x, 196, 20, hex("#9a4ad8"), 0.95);
      for (let x = 1016; x <= 1064; x += 16) line(c, [[x, 260], [x, 292]], 5, OUTLINE, r);
    } },
    STRATL: { layer: "accessory", name: "Bat Familiar", draw(c, r) {
      for (const flip of [1, -1]) {  // its wings, either side of it
        fill(c, [[220, 220], [80, 140], [110, 220], [60, 260], [150, 270], [210, 250]].map(([x, y]) => [220 + (x - 220) * flip, y]), "#3a2a3a", r);
      }
      fill(c, ellipse(220, 230, 46, 40), "#4a3a4a", r);
      for (const x of [206, 234]) dab(c, x, 222, 8, hex("#ff4a3a"), 0.95);
    } },
    ONY: { layer: "accessory", name: "Onyxia Whelpling", draw(c, r) {
      for (const flip of [1, -1]) {  // its wings, spread
        fill(c, [[1040, 230], [1040 + flip * 150, 90], [1040 + flip * 120, 200], [1040 + flip * 170, 230], [1040 + flip * 60, 270]], "#4a2a34", r);
      }
      line(c, quad([1060, 300], [1150, 360], [1170, 290], 10), 28, "#2a2228", r);  // its tail
      fill(c, ellipse(1040, 270, 62, 50), "#2a2228", r);
      fill(c, ellipse(1040, 190, 50, 40), "#2a2228", r);  // its head
      for (const x of [1018, 1062]) fill(c, [[x - 10, 160], [x + (x - 1040) * 0.5, 110], [x + 10, 162]], "#e8d8b8", r, { line: 6 });
      for (const x of [1024, 1056]) dab(c, x, 188, 9, hex("#ffd23f"), 0.95);
      soft(c, ellipse(1040, 290, 34, 22), "#5a4a50", r);
    } },
  };
  // --- The sets: each boss's headwear, outfit and charm (an accessory), the piece above among them ---------------

  // Headwear pieces.
  const H = {
    hood: (col, lining, mark) => (c, r) => {
      hood(c, r, col, lining);
      if (mark) fill(c, circle(HX, 100, 30), mark, r, { line: 10 });
    },
    helm: (col, band, crest) => (c, r) => {
      dome(c, r, col, band, 30);
      if (crest) fill(c, [[HX - 18, 40], [HX + 18, 40], [HX + 18, 196], [HX - 18, 196]], crest, r, { line: 10 });
    },
    crown: (col, gem, spikes) => (c, r) => crownOf(c, r, col, gem, spikes || 5, 214, 40),
    wizard: (col, band, starCol) => (c, r) => {  // a tall pointed hat, its tip flopping over
      fill(c, [[470, 214], ...quad([520, 120], [HX, -40], [HX + 110, -120], 12), [HX + 60, -40], [794, 214]], col, r);
      fill(c, ellipse(HX, 222, 250, 40), col, r);  // the brim
      fill(c, [[478, 186], [786, 186], [794, 220], [470, 220]], band, r, { line: 10 });
      if (starCol) for (const [x, y] of [[580, 120], [670, 60], [620, 10]]) fill(c, star(x, y, 22, 9), starCol, r, { line: 8 });
    },
    circlet: (col, gem) => (c, r) => {
      line(c, quad([456, 214], [HX, 168], [808, 214], 20), 20, col, r);
      fill(c, [[HX - 30, 158], [HX, 96], [HX + 30, 158], [HX, 186]], gem, r, { line: 10 });
    },
    horns: (col, band) => (c, r) => {
      both((m) => fill(c, m([...quad([500, 190], [330, 150], [300, -60], 14), ...quad([300, -60], [380, 100], [540, 160], 14).slice(1)]), col, r));
      fill(c, [[460, 196], [804, 196], [804, 228], [460, 228]], band, r);
    },
    mitre: (col, trim) => (c, r) => {
      fill(c, [[500, 220], ...quad([480, 60], [HX, -110], [784, 60], 16), [764, 220]], col, r);
      fill(c, [[HX - 20, 220], [HX - 20, -60], [HX + 20, -60], [HX + 20, 220]], trim, r, { outline: null });
      fill(c, [[HX - 60, 60], [HX + 60, 60], [HX + 60, 90], [HX - 60, 90]], trim, r, { line: 8 });
      fill(c, [[492, 190], [772, 190], [772, 226], [492, 226]], trim, r, { line: 10 });
    },
    bandana: (col, spots) => (c, r) => {
      fill(c, [...quad([456, 226], [HX, -40], [808, 226], 18)], col, r);
      fill(c, [[790, 150], [900, 100], [920, 200], [800, 196]], col, r);  // its tails
      if (spots) for (const [x, y] of [[560, 90], [660, 70], [720, 140], [580, 170]]) dab(c, x, y, 10, hex(spots), 0.9);
    },
    beanie: (col, stripe) => (c, r) => {
      fill(c, [...quad([462, 226], [HX, -70], [802, 226], 18)], col, r);
      for (const y of [140, 60]) line(c, quad([480, y + 30], [HX, y], [784, y + 30], 12), 22, stripe, r);
      fill(c, circle(HX, -50, 40), stripe, r, { line: 10 });
    },
    pith: (col) => (c, r) => {
      fill(c, ellipse(HX, 214, 270, 46), col, r);  // the brim
      fill(c, [...quad([480, 214], [HX, -40], [784, 214], 18)], col, r);
      line(c, quad([486, 190], [HX, 168], [778, 190], 14), 16, "#8a6a3a", r);
    },
    skull: (col, eyes) => (c, r) => {  // a dragon's skull worn as a helm
      both((m) => fill(c, m([[500, 170], [360, 40], [420, 30], [540, 130]]), "#e8d8b8", r));
      fill(c, [...quad([462, 226], [HX, -40], [802, 226], 18)], col, r);
      for (const x of [560, 704]) fill(c, ellipse(x, 120, 34, 26), eyes, r, { line: 8 });
      fill(c, [[HX - 20, 60], [HX + 20, 60], [HX, 20]], "#e8d8b8", r, { line: 6 });
    },
    spiked: (col, spikes) => (c, r) => {
      dome(c, r, col, col, 20);
      for (const [x, ht] of [[480, 110], [560, 160], [HX, 200], [704, 160], [784, 110]]) {
        fill(c, [[x - 22, 150], [x, 150 - ht], [x + 22, 150]], spikes, r, { line: 10 });
      }
    },
  };
  // Outfit pieces (all in the base outfit's shape).
  const B = {
    robe: (main, trim, emblem) => (c, r) => {
      outfitFill(c, main, r, (x) => x < 570 || x > 690);
      outfitFill(c, trim, r, (x) => x >= 570 && x <= 690);
      outfitOutline(c, r);
      if (emblem) fill(c, circle(630, 700, 54), emblem, r, { line: 14 });
    },
    plate: (main, lines, emblem) => (c, r) => {
      outfitFill(c, main, r);
      outfitOutline(c, r);
      for (const y of [600, 760, 920, 1080]) line(c, quad([200, y], [630, y + 40], [1060, y], 20), 10, lines, r);
      both((m) => fill(c, m([[150, 600], [230, 430], [460, 420], [420, 560]]), lines, r));  // pauldrons
      if (emblem) fill(c, circle(630, 700, 58), emblem, r, { line: 14 });
    },
    leather: (main, strap) => (c, r) => {
      const strapAt = (x, y) => Math.abs((y - 480) + (x - 300) * 0.75) < 46 || Math.abs((y - 480) - (x - 960) * 0.75) < 46;
      outfitFill(c, main, r, (x, y) => !strapAt(x, y));
      outfitFill(c, strap, r, strapAt);
      outfitOutline(c, r);
      fill(c, circle(630, 690, 34), "#d0a040", r, { line: 10 });
    },
    scale: (main, scales) => (c, r) => {
      outfitFill(c, main, r);
      outfitOutline(c, r);
      for (let y = 480; y < 1240; y += 70) for (let x = 120 + ((y / 70) % 2) * 35; x < 1150; x += 70) {
        line(c, quad([x - 28, y], [x, y + 26], [x + 28, y], 6), 7, scales, r);
      }
    },
    fur: (main, collar, trim) => (c, r) => {
      outfitFill(c, main, r, (x, y) => y > 560);
      outfitFill(c, collar, r, (x, y) => y <= 560);
      outfitOutline(c, r);
      for (let x = 160; x < 1110; x += 60) dab(c, x + (x % 3) * 8, 560 + (x % 5) * 6, 22, hex(collar), 0.9);  // fluff
      if (trim) fill(c, [[560, 650], [700, 650], [700, 720], [560, 720]], trim, r, { line: 10 });
    },
    overalls: (main, shirt) => (c, r) => {
      const bib = (x, y) => (x > 470 && x < 790 && y > 600) || y > 980;
      outfitFill(c, shirt, r, (x, y) => !bib(x, y));
      outfitFill(c, main, r, bib);
      outfitOutline(c, r);
      for (const x of [500, 760]) line(c, [[x, 600], [x + (x < 630 ? -60 : 60), 400]], 22, main, r);
      fill(c, [[560, 760], [700, 760], [700, 860], [560, 860]], main, r, { line: 10 });  // a pocket, a wrench in it
      line(c, [[600, 700], [640, 780]], 16, "#c0c8d0", r);
    },
    vest: (main, shirt) => (c, r) => {
      const open = (x) => x > 560 && x < 700;
      outfitFill(c, shirt, r, open);
      outfitFill(c, main, r, (x) => !open(x));
      outfitOutline(c, r);
      for (const [x, y] of [[420, 760], [840, 760], [420, 960], [840, 960]]) fill(c, [[x - 60, y - 40], [x + 60, y - 40], [x + 60, y + 40], [x - 60, y + 40]], main, r, { line: 10 });
    },
    wraps: (main, wrap, beads) => (c, r) => {
      const band = (x, y) => Math.floor((y + x * 0.5) / 90) % 2 === 0;
      outfitFill(c, main, r, (x, y) => !band(x, y));
      outfitFill(c, wrap, r, band);
      outfitOutline(c, r);
      for (let i = 0; i < 9; i++) fill(c, circle(470 + i * 40, 520 + Math.sin(i / 8 * Math.PI) * 80, 16), beads, r, { line: 6, hatch: 6 });
    },
  };
  // Charm pieces (accessories), floating in the top right unless said.
  const X = 1040, Y = 220;
  const C = {
    orb: (col, glow) => (c, r) => { floating(c, r, X, Y, glow); fill(c, circle(X, Y, 62), col, r); soft(c, circle(X - 20, Y - 20, 22), "#ffffff", r); },
    flask: (liquid) => (c, r) => {
      floating(c, r, X, Y, liquid);
      fill(c, [[X - 22, Y - 110], [X + 22, Y - 110], [X + 22, Y - 50], [X - 22, Y - 50]], "#d8f0f0", r, { line: 10 });
      fill(c, circle(X, Y + 10, 70), "#d8f0f0", r);
      soft(c, circle(X, Y + 10, 70).filter(([, y]) => y > Y), liquid, r);
      for (const [x, y] of [[X - 10, Y - 140], [X + 14, Y - 170]]) fill(c, circle(x, y, 12), liquid, r, { line: 6 });
    },
    feather: (col, glow) => (c, r) => {
      floating(c, r, X, Y, glow);
      fill(c, rotate([...quad([X, Y + 120], [X - 70, Y], [X, Y - 130], 12), ...quad([X, Y - 130], [X + 70, Y], [X, Y + 120], 12).slice(1)], 0.5, X, Y), col, r);
      line(c, rotate([[X, Y + 140], [X, Y - 110]], 0.5, X, Y), 8, "#c8b890", r);
    },
    weapon: (kind, col) => (c, r) => {  // floating on a slant
      const b = [X + 90, Y + 150], t = [X - 80, Y - 140];
      line(c, [b, t], kind === "cutlass" ? 18 : 28, kind === "cutlass" ? "#5a3a20" : "#6a4020", r);
      if (kind === "axe") fill(c, rotate([...quad([X - 60, Y - 160], [X + 70, Y - 110], [X - 10, Y - 20], 10)], 0, X, Y), col, r);
      if (kind === "hammer") fill(c, rotate([[X - 170, Y - 170], [X - 20, Y - 170], [X - 20, Y - 80], [X - 170, Y - 80]], 0.53, X - 80, Y - 130), col, r);
      if (kind === "club") fill(c, rotate(ellipse(X - 60, Y - 100, 60, 110), -0.53, X - 60, Y - 100), col, r);
      if (kind === "club") for (const [dx, dy] of [[-110, -150], [-20, -170], [-80, -40], [10, -90]]) fill(c, [[X + dx - 14, Y + dy], [X + dx, Y + dy - 34], [X + dx + 14, Y + dy]], "#c0c8d0", r, { line: 6 });
      if (kind === "cutlass") {
        fill(c, [...quad([X + 40, Y + 90], [X - 80, Y - 40], [X - 110, Y - 170], 12), ...quad([X - 110, Y - 170], [X - 40, Y - 60], [X + 70, Y + 60], 12).slice(1)], col, r);
        fill(c, ellipse(X + 60, Y + 90, 40, 20), "#d0a040", r, { line: 10 });
      }
    },
    banner: (col, emblem) => (c, r) => {
      line(c, [[X - 80, Y + 160], [X - 80, Y - 160]], 18, "#5a3a20", r);
      fill(c, [[X - 74, Y - 150], [X + 100, Y - 150], [X + 100, Y + 40], [X + 10, Y], [X - 74, Y + 40]], col, r);
      fill(c, circle(X + 12, Y - 70, 36), emblem, r, { line: 10 });
    },
    totem: (col, eyes) => (c, r) => {
      floating(c, r, X, Y, eyes);
      fill(c, [[X - 50, Y - 140], [X + 50, Y - 140], [X + 50, Y + 140], [X - 50, Y + 140]], col, r);
      for (const y of [Y - 90, Y + 20]) { dab(c, X - 18, y, 10, hex(eyes), 0.95); dab(c, X + 18, y, 10, hex(eyes), 0.95); line(c, [[X - 24, y + 34], [X + 24, y + 34]], 8, OUTLINE, r); }
      for (const flip of [1, -1]) {  // its wings, either side
        fill(c, [[X - 50, Y - 100], [X - 110, Y - 140], [X - 50, Y - 60]].map(([x, y]) => [X + (x - X) * flip, y]), col, r, { line: 10 });
      }
    },
    anvil: () => (c, r) => {
      floating(c, r, X, Y, "#ff7a1a");
      fill(c, [[X - 130, Y - 50], [X + 110, Y - 50], [X + 80, Y], [X + 30, Y], [X + 20, Y + 60], [X + 60, Y + 100], [X - 70, Y + 100], [X - 30, Y + 60], [X - 40, Y], [X - 130, Y - 20]], "#3a3236", r);
      for (let i = 0; i < 5; i++) sparkle(c, r, X - 80 + i * 40, Y - 90 - (i % 2) * 30, 14, "#ff9a2a");
    },
    horseSkull: (glow) => (c, r) => {
      floating(c, r, X, Y, glow);
      fill(c, [[X - 60, Y - 90], [X + 50, Y - 70], [X + 70, Y + 80], [X + 10, Y + 120], [X - 40, Y + 40]], "#e8e0d0", r);
      dab(c, X - 10, Y - 40, 16, hex(glow), 0.95);
      for (const x of [X + 20, X + 44]) dab(c, x, Y + 96, 7, OUTLINE, 0.9);
    },
    seed: (col, glow) => (c, r) => {
      floating(c, r, X, Y, glow);
      fill(c, ellipse(X, Y + 20, 56, 70), col, r);
      fill(c, ellipse(X, Y - 50, 66, 30), "#6a4020", r);
      line(c, quad([X, Y - 70], [X + 20, Y - 120], [X + 50, Y - 130], 8), 10, "#5bd24a", r);
    },
    wisp: (col) => (c, r) => {
      floating(c, r, X, Y, col);
      fill(c, circle(X, Y, 44), "#ffffff", r, { outline: null });
      line(c, quad([X, Y + 40], [X - 40, Y + 110], [X + 20, Y + 160], 10), 16, col, r);
      for (const [x, y] of [[X - 80, Y - 60], [X + 70, Y - 80], [X + 80, Y + 60]]) sparkle(c, r, x, y, 16, "#ffffff");
    },
    chain: () => (c, r) => {  // a ball and chain, hanging
      for (let k = 0; k < 6; k++) fill(c, ellipse(X - 40 + k * 14, Y - 150 + k * 40, 20, 14), "#9aa0a8", r, { line: 8, hatch: 8 });
      fill(c, circle(X + 50, Y + 110, 70), "#3a3a40", r);
      soft(c, circle(X + 30, Y + 90, 18), "#7a7a80", r);
    },
    murloc: () => (c, r) => {  // a little murloc on his right shoulder
      fill(c, ellipse(930, 420, 80, 66), "#4aa86a", r);
      fill(c, [[880, 360], [930, 300], [980, 360]], "#e07a5a", r, { line: 10 });
      for (const x of [902, 958]) { fill(c, circle(x, 400, 16), "#ffffff", r, { line: 8, hatch: 6 }); dab(c, x, 402, 7, OUTLINE, 0.95); }
      fill(c, ellipse(930, 448, 40, 16), "#5a1a1a", r, { line: 8 });
    },
    hatchling: () => (c, r) => {  // a baby Aku'mai: a shell, three little heads
      floating(c, r, X, Y, "#5aa8d8");
      fill(c, ellipse(X, Y + 30, 90, 60), "#2a4a3a", r);
      for (const [dx, dy] of [[-70, -40], [0, -70], [70, -40]]) {
        line(c, [[X + dx * 0.5, Y], [X + dx, Y + dy]], 22, "#3a7a9a", r);
        fill(c, circle(X + dx, Y + dy - 10, 24), "#3a7a9a", r, { line: 8 });
        dab(c, X + dx + 6, Y + dy - 14, 6, hex("#ffd23f"), 0.95);
      }
    },
    bot: () => (c, r) => {  // a little gnome bot, hovering
      floating(c, r, X, Y, "#9fe8ff");
      fill(c, [[X - 60, Y - 40], [X + 60, Y - 40], [X + 60, Y + 60], [X - 60, Y + 60]], "#a0a8b0", r);
      fill(c, circle(X, Y - 80, 40), "#a0a8b0", r);
      for (const x of [X - 14, X + 14]) dab(c, x, Y - 82, 9, hex("#ff4a3a"), 0.95);
      line(c, [[X, Y - 120], [X, Y - 160]], 8, "#5a5f66", r);
      soft(c, ellipse(X, Y + 90, 50, 14), "#9fe8ff", r);
    },
  };

  // Each boss: its headwear, outfit and charm (a piece drawn above, or a recipe from the pieces).
  const piece = (key) => ({ name: G[key].name, draw: G[key].draw });
  const SETS = {
    RFC: { head: { name: "Fel Horn Circlet", draw: H.horns("#3a2228", "#7aff4a") }, body: { name: "Searing Blade Robe", draw: B.robe("#7a1a1a", "#3a1414", "#7aff4a") }, charm: piece("RFC") },
    WC: { head: piece("WC"), body: { name: "Fang Druid Leathers", draw: B.scale("#3a7a3a", "#a8d070") }, charm: { name: "Murloc Buddy", draw: C.murloc() } },
    DM: { head: { name: "Defias Bandana", draw: H.bandana("#c02a2a", "#f0e0d0") }, body: piece("DM"), charm: { name: "VanCleef's Cutlass", draw: C.weapon("cutlass", "#c0c8d0") } },
    SFK: { head: { name: "Archmage's Hat", draw: H.wizard("#5a2a7a", "#c0c8d0", "#e0d0ff") }, body: { name: "Arugal's Robe", draw: B.robe("#4a1a6a", "#c0c8d0", "#e0e0ff") }, charm: piece("SFK") },
    BFD: { head: piece("BFD"), body: { name: "Twilight Robes", draw: B.robe("#2a2a5a", "#7a6ad8", "#ffd23f") }, charm: { name: "Aku'mai Hatchling", draw: C.hatchling() } },
    STOCKS: { head: { name: "Prison Beanie", draw: H.beanie("#2a2228", "#f0ece0") }, body: piece("STOCKS"), charm: { name: "Ball and Chain", draw: C.chain() } },
    GNOMER: { head: piece("GNOMER"), body: { name: "Mekgineer Overalls", draw: B.overalls("#4f6ab8", "#e8dcc0") }, charm: { name: "Gnome Bot", draw: C.bot() } },
    RFK: { head: piece("RFK"), body: { name: "Razorflank Hide", draw: B.fur("#8a5a30", "#c8b890") }, charm: { name: "Thorn Totem", draw: C.totem("#6a4a2a", "#7aff4a") } },
    SMGY: { head: { name: "Bloodmage Hood", draw: H.hood("#8a1a1a", "#ff6a4a") }, body: { name: "Bloodmage Robe", draw: B.robe("#8a1a1a", "#3a1414", "#f0ece0") }, charm: piece("SMGY") },
    SMLIB: { head: { name: "Arcanist's Hat", draw: H.wizard("#c02a2a", "#ffd23f", "#ffd23f") }, body: { name: "Scarlet Arcanist Robe", draw: B.robe("#c02a2a", "#ffd23f", "#4f86e8") }, charm: piece("SMLIB") },
    SMARM: { head: piece("SMARM"), body: { name: "Scarlet Plate", draw: B.plate("#c02a2a", "#8a1a1a", "#ffd23f") }, charm: { name: "Herod's Axe", draw: C.weapon("axe", "#c0c8d0") } },
    SMCATH: { head: { name: "Inquisitor's Mitre", draw: H.mitre("#f8f0e0", "#c02a2a") }, body: piece("SMCATH"), charm: { name: "Resurrection Feather", draw: C.feather("#f8f4e8", "#ffd23f") } },
    RFD: { head: piece("RFD"), body: { name: "Coldbringer Shroud", draw: B.robe("#3a4a7a", "#9fe8ff", "#c8f0ff") }, charm: { name: "Frost Phylactery", draw: C.orb("#9fe8ff", "#c8f0ff") } },
    ULDA: { head: { name: "Titan Stone Helm", draw: H.helm("#8a8078", "#6a6058", "#5ac8ff") }, body: { name: "Stone Keeper Plate", draw: B.plate("#8a8078", "#5a5048", "#5ac8ff") }, charm: piece("ULDA") },
    ZF: { head: piece("ZF"), body: { name: "Sandfury Wraps", draw: B.wraps("#c8a878", "#8a5a30", "#f0ece0") }, charm: { name: "Sandfury Totem", draw: C.totem("#c89a5a", "#e04a2a") } },
    MARA: { head: { name: "Crystal Crown", draw: H.crown("#b07aff", "#e0c8ff", 4) }, body: { name: "Earthen Gown", draw: B.robe("#6a4a3a", "#b07aff", "#e0c8ff") }, charm: piece("MARA") },
    THANES: { head: piece("THANES"), body: { name: "Thane's Mail", draw: B.scale("#7a8090", "#c0c8d0") }, charm: { name: "Spirit Hammer", draw: C.weapon("hammer", "#c8f0ff") } },
    RUINS: { head: { name: "Plague Hood", draw: H.hood("#2a3a2a", "#7ad86a", "#7ad86a") }, body: piece("RUINS"), charm: { name: "Plague Flask", draw: C.flask("#7ad86a") } },
    EXCAV: { head: { name: "Explorer's Pith Helmet", draw: H.pith("#d8c8a0") }, body: { name: "Explorer's Vest", draw: B.vest("#a08a5a", "#f0e8d0") }, charm: piece("EXCAV") },
    ST: { head: { name: "Dreamweaver Circlet", draw: H.circlet("#3a8a3a", "#7ad86a") }, body: { name: "Emerald Dragonscale", draw: B.scale("#3a8a5a", "#a8e8a0") }, charm: piece("ST") },
    BRD: { head: piece("BRD"), body: { name: "Emperor's Robes", draw: B.robe("#8a2a1a", "#2a2228", "#ffd23f") }, charm: { name: "Black Anvil", draw: C.anvil() } },
    LBRS: { head: { name: "Blackrock Warhelm", draw: H.spiked("#2a2228", "#8a8a90") }, body: piece("LBRS"), charm: { name: "Blackrock Banner", draw: C.banner("#2a2228", "#c02a2a") } },
    UBRS: { head: { name: "Dragonspawn Skull", draw: H.skull("#2a2228", "#ff4a3a") }, body: { name: "Drakkisath's Scale Mail", draw: B.scale("#2a2228", "#c02a2a") }, charm: piece("UBRS") },
    DME: { head: piece("DME"), body: { name: "Felvine Robe", draw: B.robe("#2a4a2a", "#7aff4a", "#9aff5a") }, charm: { name: "Felvine Sprout", draw: C.seed("#7aff4a", "#9aff5a") } },
    DMW: { head: { name: "Highborne Diadem", draw: H.circlet("#c8c8e0", "#4f86e8") }, body: { name: "Highborne Robes", draw: B.robe("#2a4a8a", "#c8c8e0", "#9fe8ff") }, charm: piece("DMW") },
    DMN: { head: piece("DMN"), body: { name: "Ogre King's Furs", draw: B.fur("#6a4a7a", "#c89a6a", "#ffd23f") }, charm: { name: "Gordok Club", draw: C.weapon("club", "#8a5a2e") } },
    SCHOLO: { head: { name: "Darkmaster's Hood", draw: H.hood("#1a1418", "#b07aff", "#b07aff") }, body: { name: "Necromancer Robes", draw: B.robe("#1a1418", "#5a2a7a", "#f0ece0") }, charm: piece("SCHOLO") },
    STRATL: { head: { name: "Dreadlord Horns", draw: H.horns("#d8c8a0", "#3a2a4a") }, body: { name: "Dreadlord Mantle", draw: B.plate("#3a2a4a", "#1a1424", "#7aff4a") }, charm: piece("STRATL") },
    STRATU: { head: piece("STRATU"), body: { name: "Death Knight Plate", draw: B.plate("#3a3a44", "#1a1a24", "#7ad8ff") }, charm: { name: "Deathcharger's Skull", draw: C.horseSkull("#7ad8ff") } },
    ONY: { head: { name: "Black Dragon Skull", draw: H.skull("#2a2228", "#ffd23f") }, body: { name: "Onyxia Scale Cloak", draw: B.scale("#2a2228", "#6a4a5a") }, charm: piece("ONY") },
    BARROW: { head: piece("BARROW"), body: { name: "Barrowmoon Robe", draw: B.robe("#3a2a5a", "#c8b8ff", "#e8e0ff") }, charm: { name: "Barrow Wisp", draw: C.wisp("#b8a8ff") } },
    HYJAL: { head: { name: "Wild King's Antlers", draw: (c, r) => { antlers(c, r) } }, body: piece("HYJAL"), charm: { name: "Nordrassil Seed", draw: C.seed("#a06a3a", "#c8ff5a") } },
  };
  function antlers(c, r) {
    both((m) => {
      line(c, m([[520, 180], [420, 40], [330, -40]]), 34, "#8a6a4a", r);
      line(c, m([[450, 90], [520, -40]]), 28, "#8a6a4a", r);
      line(c, m([[380, 10], [250, 40]]), 28, "#8a6a4a", r);
    });
    line(c, quad([456, 214], [HX, 176], [808, 214], 20), 20, "#3a7a3a", r);
    for (const x of [500, 580, 680, 760]) fill(c, ellipse(x, 196, 22, 34), "#5bd24a", r, { line: 8, hatch: 6 });
  }
  // --- The charms, each somewhere of its own --------------------------------------------------------------------
  // The accessory is drawn last, over everything, so a charm can sit anywhere: on a shoulder (the shoulders' tops
  // about (330, 450) and (930, 450)), across the chest (its middle about (630, 680)), at the bottom corners (in front
  // of the hands, about y 1000..1250), round the head (centre (632, 255)) or above it. enlarge: drawn small, then
  // enlarged round its middle (make-unlock-art.js) - only the ones that float free.
  const SHOULDERS = [[330, 450], [930, 450]];
  function chainTo(c, r, x, y, col = "#9aa0a8") {  // a chain from the neck down to (x, y)
    for (const side of [-1, 1]) {
      const pts = quad([630 + side * 110, 390], [630 + side * 80, (390 + y) / 2 + 40], [x, y], 10);
      for (let k = 0; k < pts.length; k += 2) fill(c, ellipse(pts[k][0], pts[k][1], 14, 10), col, r, { line: 6, hatch: 6 });
    }
  }
  const strapAcross = (c, r, col) =>  // a strap from the left shoulder to the right hip
    fill(c, [[330, 430], [400, 400], [1060, 1080], [990, 1120]], col, r);
  function flame(c, r, x, y, w, ht, col, inner) {
    fill(c, [...quad([x - w, y], [x - w * 0.7, y - ht * 0.6], [x, y - ht], 10), ...quad([x, y - ht], [x + w * 0.7, y - ht * 0.6], [x + w, y], 10).slice(1)], col, r);
    soft(c, [...quad([x - w * 0.5, y], [x - w * 0.3, y - ht * 0.4], [x, y - ht * 0.6], 8), ...quad([x, y - ht * 0.6], [x + w * 0.3, y - ht * 0.4], [x + w * 0.5, y], 8).slice(1)], inner, r);
  }
  function batShape(c, r, x, y, s) {
    for (const flip of [1, -1]) fill(c, [[x, y], [x + flip * 90 * s, y - 50 * s], [x + flip * 70 * s, y], [x + flip * 100 * s, y + 30 * s], [x + flip * 30 * s, y + 20 * s]], "#3a2a3a", r, { line: 8 });
    fill(c, ellipse(x, y + 4 * s, 24 * s, 22 * s), "#4a3a4a", r, { line: 8 });
    for (const dx of [-8, 8]) dab(c, x + dx * s, y, 5 * s, hex("#ff4a3a"), 0.95);
  }
  function skullAt(c, r, x, y, s, col = "#f0ece0", eyes = OUTLINE) {
    fill(c, circle(x, y, 60 * s), col, r);
    fill(c, [[x - 36 * s, y + 40 * s], [x + 36 * s, y + 40 * s], [x + 30 * s, y + 80 * s], [x - 30 * s, y + 80 * s]], col, r, { line: 10 });
    for (const dx of [-24, 24]) dab(c, x + dx * s, y - 4 * s, 16 * s, eyes, 0.95);
  }
  const CHARMS = {
    RFC: { name: "Ragefire Embers", draw(c, r) { for (const [x, y] of SHOULDERS) flame(c, r, x, y + 20, 60, 190, "#7aff4a", "#e8ffd0"); } },
    WC: { name: "Murloc Buddy", draw: C.murloc() },
    DM: { name: "VanCleef's Cutlass", draw(c, r) {  // sheathed, on a strap across his chest
      strapAcross(c, r, "#3a2414");
      fill(c, [[420, 520], [470, 480], [930, 960], [890, 1010]], "#1a1418", r);  // the scabbard
      fill(c, ellipse(400, 480, 50, 30), "#d0a040", r, { line: 10 });  // the hilt
      line(c, [[380, 470], [330, 420]], 22, "#5a3a20", r);
      fill(c, circle(320, 410, 18), "#d0a040", r, { line: 8 });
    } },
    SFK: { ...G.SFK, enlarge: true },
    BFD: { name: "Aku'mai Hatchling", draw(c, r) {  // sitting at the bottom left
      const X0 = 240, Y0 = 1080;
      fill(c, ellipse(X0, Y0 + 30, 130, 90), "#2a4a3a", r);
      for (let i = 0; i < 4; i++) fill(c, circle(X0 - 70 + i * 46, Y0 + 10, 18), "#3a6a4a", r, { line: 6 });
      for (const [dx, dy] of [[-90, -110], [0, -150], [90, -110]]) {
        line(c, [[X0 + dx * 0.4, Y0 - 20], [X0 + dx, Y0 + dy]], 34, "#3a7a9a", r);
        fill(c, circle(X0 + dx, Y0 + dy - 14, 36), "#3a7a9a", r, { line: 10 });
        dab(c, X0 + dx + 10, Y0 + dy - 20, 9, hex("#ffd23f"), 0.95);
      }
    } },
    STOCKS: { name: "Ball and Chain", draw(c, r) {  // an iron collar, its chain down to a ball at his feet
      line(c, ellipse(630, 400, 150, 44).filter(([, y]) => y >= 400).sort((p, q) => p[0] - q[0]), 30, "#5a5f66", r);  // its front half (the back goes round his neck)
      for (let k = 0; k < 9; k++) fill(c, ellipse(630 + (k % 2) * 8, 460 + k * 62, 18, 28), "#9aa0a8", r, { line: 8, hatch: 6 });
      fill(c, circle(630, 1100, 100), "#3a3a40", r);
      soft(c, circle(600, 1070, 26), "#7a7a80", r);
    } },
    GNOMER: { name: "Gnome Bot", enlarge: true, draw(c, r) {  // hovering by his head, on a propeller
      const X0 = 240, Y0 = 200;
      fill(c, [[X0 - 60, Y0 - 40], [X0 + 60, Y0 - 40], [X0 + 60, Y0 + 60], [X0 - 60, Y0 + 60]], "#a0a8b0", r);
      fill(c, circle(X0, Y0 - 80, 40), "#a0a8b0", r);
      for (const x of [X0 - 14, X0 + 14]) dab(c, x, Y0 - 82, 9, hex("#ff4a3a"), 0.95);
      line(c, [[X0, Y0 - 120], [X0, Y0 - 150]], 8, "#5a5f66", r);
      fill(c, ellipse(X0, Y0 - 155, 80, 12), "#d0a040", r, { line: 8 });  // the propeller
      soft(c, ellipse(X0, Y0 + 90, 50, 14), "#9fe8ff", r);
    } },
    RFK: { name: "Thorn Totem", draw(c, r) {  // standing at the bottom right
      const X0 = 1060, Y0 = 1060;
      fill(c, [[X0 - 60, Y0 - 260], [X0 + 60, Y0 - 260], [X0 + 60, Y0 + 200], [X0 - 60, Y0 + 200]], "#6a4a2a", r);
      for (const y of [Y0 - 200, Y0 - 60]) {
        for (const dx of [-22, 22]) dab(c, X0 + dx, y, 12, hex("#7aff4a"), 0.95);
        line(c, [[X0 - 28, y + 40], [X0 + 28, y + 40]], 8, OUTLINE, r);
      }
      for (let i = 0; i < 6; i++) {
        const y = Y0 - 240 + i * 80, side = i % 2 ? 1 : -1;
        fill(c, [[X0 + side * 56, y - 14], [X0 + side * 120, y - 40], [X0 + side * 56, y + 14]], "#c8b890", r, { line: 8 });
      }
    } },
    SMGY: { name: "Ghostly Lantern", draw(c, r) {  // on a pole over his left shoulder
      line(c, [[120, 1250], [260, 120]], 26, "#3a2414", r);
      line(c, quad([260, 120], [310, 90], [340, 140], 8), 14, "#3a2414", r);
      soft(c, circle(340, 260, 110), "#9fe8ff", r, { hatch: 24 });
      fill(c, [[290, 180], [390, 180], [380, 330], [300, 330]], "#5a5f66", r);
      soft(c, ellipse(340, 255, 34, 54), "#e8f8ff", r);
    } },
    SMLIB: { name: "Floating Spellbook", draw(c, r) {  // open in front of him, as if reading it
      const X0 = 630, Y0 = 880;
      soft(c, ellipse(X0, Y0, 300, 150), "#b0a0ff", r, { hatch: 24 });
      fill(c, [[X0 - 260, Y0 - 50], [X0, Y0 - 90], [X0 + 260, Y0 - 50], [X0 + 260, Y0 + 110], [X0, Y0 + 70], [X0 - 260, Y0 + 110]], "#c02a2a", r);
      fill(c, [[X0 - 236, Y0 - 66], [X0, Y0 - 104], [X0, Y0 + 50], [X0 - 236, Y0 + 90]], "#f8ecc8", r, { line: 12 });
      fill(c, [[X0, Y0 - 104], [X0 + 236, Y0 - 66], [X0 + 236, Y0 + 90], [X0, Y0 + 50]], "#f8ecc8", r, { line: 12 });
      for (let k = 0; k < 4; k++) {
        line(c, [[X0 - 200, Y0 - 30 + k * 30], [X0 - 30, Y0 - 60 + k * 30]], 6, "#8a7050", r);
        line(c, [[X0 + 30, Y0 - 60 + k * 30], [X0 + 200, Y0 - 30 + k * 30]], 6, "#8a7050", r);
      }
      for (const [x, y] of [[X0 - 120, Y0 - 200], [X0 + 60, Y0 - 240], [X0 + 180, Y0 - 170]]) sparkle(c, r, x, y, 26, "#e0d8ff");
    } },
    SMARM: { name: "Herod's Axe", draw(c, r) {  // resting on his right shoulder
      line(c, [[1180, 1250], [860, 230]], 34, "#5a3a20", r);
      fill(c, [...quad([840, 140], [1080, 120], [1060, 340], 12), [900, 300]], "#c0c8d0", r);
      fill(c, [...quad([860, 150], [660, 200], [760, 360], 12), [880, 290]], "#c0c8d0", r);
    } },
    SMCATH: { name: "Holy Halo", draw(c, r) {  // a golden halo over her head
      soft(c, ellipse(632, 40, 230, 70), "#fff2a8", r, { hatch: 24 });
      fill(c, ellipse(632, 40, 180, 40), "#ffd23f", r, { holes: [ellipse(632, 40, 140, 22)] });
      for (const [x, y] of [[430, 0], [840, 10], [632, -20]]) sparkle(c, r, x, y + 40, 20, "#ffffff");
    } },
    RFD: { name: "Frost Shards", draw(c, r) {  // ice circling his head
      for (let i = 0; i < 7; i++) {
        const a = (i / 7) * 2 * Math.PI + 0.3, x = 632 + Math.cos(a) * 360, y = 230 + Math.sin(a) * 200;
        if (Math.abs(x - 632) < 200 && y > 150) continue;  // (not across his face)
        fill(c, rotate([[x, y - 50], [x + 22, y], [x, y + 50], [x - 22, y]], a, x, y), "#c8f0ff", r, { line: 8 });
        soft(c, circle(x, y, 40), "#9fe8ff", r);
      }
    } },
    ULDA: { name: "Platinum Disc", draw(c, r) {  // a medallion on his chest
      chainTo(c, r, 630, 580, "#c0c8d0");
      fill(c, circle(630, 700, 130), "#d8dce0", r, { holes: [circle(630, 700, 40)] });
      for (let i = 0; i < 8; i++) { const a = (i / 8) * 2 * Math.PI; dab(c, 630 + Math.cos(a) * 88, 700 + Math.sin(a) * 88, 12, hex("#5ac8ff"), 0.95); }
    } },
    ZF: { name: "Shrunken Head Belt", draw(c, r) {  // heads strung across his belly
      line(c, quad([200, 1000], [630, 1110], [1060, 1000], 20), 14, "#8a5a30", r);
      for (let i = 0; i < 5; i++) {
        const x = 330 + i * 150, y = 1040 + Math.sin((i / 4) * Math.PI) * 50;
        line(c, [[x, y], [x, y + 40]], 6, "#8a5a30", r);
        fill(c, circle(x, y + 80, 40), "#8a6a4a", r, { line: 10 });
        for (const dx of [-14, 14]) line(c, [[x + dx - 8, y + 74], [x + dx + 8, y + 74]], 6, OUTLINE, r);
        fill(c, [[x - 30, y + 50], [x, y + 20], [x + 30, y + 50]], "#e04a2a", r, { line: 6 });
      }
    } },
    MARA: { name: "Crystal Growths", draw(c, r) {  // crystals growing from his shoulders
      for (const [x, y] of SHOULDERS) {
        for (const [dx, ht, tilt] of [[-50, 150, -0.4], [0, 220, 0], [50, 160, 0.4]]) {
          fill(c, rotate([[x + dx - 26, y + 20], [x + dx, y + 20 - ht], [x + dx + 26, y + 20]], tilt, x + dx, y + 20), "#b07aff", r, { line: 10 });
        }
      }
    } },
    THANES: { name: "Spirit Hammer", enlarge: true, draw: C.weapon("hammer", "#c8f0ff") },
    RUINS: { name: "Plague Bandolier", draw(c, r) {  // flasks of plague on a strap across his chest
      strapAcross(c, r, "#4a3a2a");
      for (let i = 0; i < 4; i++) {
        const x = 470 + i * 150, y = 560 + i * 138;
        fill(c, [[x - 14, y - 70], [x + 14, y - 70], [x + 14, y - 40], [x - 14, y - 40]], "#d8f0f0", r, { line: 6 });
        fill(c, circle(x, y, 44), "#d8f0f0", r, { line: 10 });
        soft(c, circle(x, y + 8, 36), "#7ad86a", r);
      }
    } },
    EXCAV: { ...G.EXCAV, enlarge: true },
    ST: { name: "Dream Wisps", draw(c, r) {  // wisps circling him
      for (const [x, y, s] of [[260, 200, 1], [1000, 160, 0.8], [180, 520, 0.7], [1080, 470, 0.9]]) {
        soft(c, circle(x, y, 80 * s), "#7ad86a", r, { hatch: 24 });
        fill(c, circle(x, y, 34 * s), "#e8ffe0", r, { outline: null });
        line(c, quad([x, y + 30 * s], [x - 40 * s, y + 90 * s], [x + 20 * s, y + 130 * s], 8), 12, "#9ae88a", r);
      }
    } },
    BRD: { name: "Anvil Pendant", draw(c, r) {  // a little black anvil, hung on a chain like a medal
      chainTo(c, r, 630, 620, "#d0a040");
      const X0 = 630, Y0 = 690;
      fill(c, [[X0 - 120, Y0 - 40], [X0 + 100, Y0 - 40], [X0 + 70, Y0], [X0 + 30, Y0], [X0 + 20, Y0 + 50], [X0 + 60, Y0 + 90], [X0 - 70, Y0 + 90], [X0 - 30, Y0 + 50], [X0 - 40, Y0], [X0 - 120, Y0 - 16]], "#2a2228", r);
      line(c, [[X0 - 60, Y0 - 30], [X0 + 60, Y0 - 30]], 6, "#ff7a1a", r);
    } },
    LBRS: { name: "Blackrock Banner", draw(c, r) {  // on a pole up past his right shoulder
      line(c, [[1120, 1250], [960, 0]], 26, "#3a2414", r);
      fill(c, [[962, 20], [1200, 50], [1190, 260], [1080, 210], [982, 250]], "#2a2228", r);
      fill(c, circle(1080, 130, 50), "#c02a2a", r, { line: 12 });
    } },
    UBRS: { name: "Black Dragon Egg", draw(c, r) {  // in a nest at the bottom right
      const X0 = 1040, Y0 = 1090;
      for (let i = 0; i < 9; i++) line(c, [[X0 - 160 + i * 20, Y0 + 40 + (i % 3) * 14], [X0 + 10 + i * 18, Y0 + 70 - (i % 2) * 30]], 12, "#6a4a2a", r);
      soft(c, ellipse(X0, Y0 - 60, 150, 180), "#ff7a1a", r, { hatch: 30 });  // its glow, behind it
      fill(c, ellipse(X0, Y0 - 60, 100, 136), "#2a2228", r);
      line(c, [[X0 - 40, Y0 - 140], [X0, Y0 - 90], [X0 - 30, Y0 - 40], [X0 + 30, Y0 + 10]], 10, "#ff9a2a", r);
    } },
    DME: { name: "Felvines", draw(c, r) {  // vines draped over his shoulders, fel flowers on them
      for (const side of [-1, 1]) {
        const vine = quad([630 + side * 260, 380], [630 + side * 420, 700], [630 + side * 300, 1150], 16);
        line(c, vine, 18, "#3a7a3a", r);
        for (let k = 2; k < vine.length; k += 4) fill(c, circle(vine[k][0], vine[k][1], 22), "#7aff4a", r, { line: 8, hatch: 6 });
      }
    } },
    DMW: { name: "Arcane Orbs", draw(c, r) {  // three orbs in an arc over his head
      for (const [x, y] of [[380, 130], [632, 20], [884, 130]]) {
        soft(c, circle(x, y, 80), "#7ad8ff", r, { hatch: 24 });
        fill(c, circle(x, y, 44), "#7ab0ff", r);
        soft(c, circle(x - 14, y - 14, 14), "#ffffff", r);
      }
    } },
    DMN: { name: "Gordok Club", draw(c, r) {  // resting on his left shoulder
      line(c, [[80, 1250], [400, 260]], 40, "#6a4020", r);
      fill(c, rotate(ellipse(420, 180, 90, 150), 0.32, 420, 180), "#8a5a2e", r);
      for (const [x, y] of [[340, 120], [470, 80], [500, 220], [360, 260], [430, 160]]) fill(c, [[x - 16, y + 10], [x, y - 30], [x + 16, y + 10]], "#c0c8d0", r, { line: 6 });
    } },
    SCHOLO: { name: "Shoulder Skull", draw(c, r) {  // a skull perched on his right shoulder, purple light in its eyes
      soft(c, circle(940, 380, 120), "#b07aff", r, { hatch: 24 });
      skullAt(c, r, 940, 360, 1.2, "#f0ece0", hex("#9a4ad8"));
    } },
    STRATL: { name: "Bat Swarm", draw(c, r) {  // bats flapping round his head
      for (const [x, y, s] of [[220, 160, 1.1], [1020, 120, 0.9], [130, 400, 0.7], [1110, 340, 0.8], [880, 40, 0.6]]) batShape(c, r, x, y, s);
    } },
    STRATU: { name: "Deathcharger Pauldron", draw(c, r) {  // a horse's skull worn on his left shoulder
      fill(c, [[200, 520], [260, 380], [460, 360], [470, 520]], "#3a3a44", r);
      fill(c, [[230, 300], [380, 280], [430, 430], [330, 500], [250, 440]], "#e8e0d0", r);
      dab(c, 330, 350, 18, hex("#7ad8ff"), 0.95);
      for (const x of [380, 404]) dab(c, x, 470, 7, OUTLINE, 0.9);
    } },
    ONY: { name: "Onyxia Whelpling", draw(c, r) {  // perched on top of his head, wings out
      const X0 = 632, Y0 = 70;
      for (const flip of [1, -1]) fill(c, [[X0, Y0], [X0 + flip * 200, Y0 - 120], [X0 + flip * 170, Y0 - 20], [X0 + flip * 230, Y0 + 20], [X0 + flip * 70, Y0 + 40]], "#4a2a34", r);
      line(c, quad([X0 + 40, Y0 + 60], [X0 + 180, Y0 + 120], [X0 + 220, Y0 + 40], 10), 26, "#2a2228", r);
      fill(c, ellipse(X0, Y0 + 40, 80, 50), "#2a2228", r);
      fill(c, ellipse(X0 - 70, Y0 - 20, 52, 38), "#2a2228", r);
      for (const x of [X0 - 92, X0 - 60]) fill(c, [[x - 8, Y0 - 50], [x + 4, Y0 - 96], [x + 12, Y0 - 48]], "#e8d8b8", r, { line: 6 });
      dab(c, X0 - 84, Y0 - 24, 9, hex("#ffd23f"), 0.95);
    } },
    BARROW: { name: "Barrow Lanterns", draw(c, r) {  // wisp lanterns hovering at her shoulders
      for (const [x, y] of [[230, 380], [1030, 380]]) {
        soft(c, circle(x, y, 90), "#b8a8ff", r, { hatch: 24 });
        fill(c, [[x - 40, y - 60], [x + 40, y - 60], [x + 34, y + 60], [x - 34, y + 60]], "#3a3a4a", r);
        soft(c, ellipse(x, y, 24, 40), "#e8e0ff", r);
        line(c, [[x, y - 60], [x, y - 110]], 8, "#3a3a4a", r);
      }
    } },
    HYJAL: { name: "Nordrassil Seed", draw(c, r) {  // a glowing seed on a vine, hung on his chest
      chainTo(c, r, 630, 600, "#5bd24a");
      soft(c, circle(630, 700, 110), "#c8ff5a", r, { hatch: 24 });
      fill(c, ellipse(630, 720, 56, 70), "#a06a3a", r);
      fill(c, ellipse(630, 650, 66, 30), "#6a4020", r);
      line(c, quad([630, 630], [650, 580], [690, 570], 8), 10, "#5bd24a", r);
    } },
  };
  for (const [key, charm] of Object.entries(CHARMS)) SETS[key].charm = charm;
  return SETS;
};
