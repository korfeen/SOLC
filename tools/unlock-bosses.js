// The end bosses as picture skins (tools/make-unlock-art.js): each is one of the ogre skins (base) with the boss drawn
// on in crayon, so outfits, hats and everything else fit it and it wears its base skin's eyes and mouths. The outfit
// covers the body and the face is the eyes' and mouth's, so a boss shows round the ogre: behind() is drawn under the
// skin (wings, horns, hair, ears, a crest, an aura, things floating round his head, a weapon on his back), front() over
// it (a mark on the forehead or the sides of the head, clear of the face: x 515..745, y 205..410), and over() in front
// of the whole picture, over the eyes and mouth too (VanCleef's mask; convert-art.js: the skin's front).
// On the minting art's 1254 canvas: the head is about x 470..800, y 120..400 (centre 632, 255); the shoulders start at
// y 460; the free space is above the head and the top corners (x < 420 or > 840, y < 440).
// Keyed by the dungeon keys (Achievements.lua), upper case. Forever's own bosses are drawn from their names.

module.exports = (h) => {
  const { fill, soft, line, dab, circle, ellipse, star, quad, rotate, hex, OUTLINE } = h;
  const HX = 632, HY = 255;  // the head's centre
  const mirror = (pts) => pts.map(([x, y]) => [2 * HX - x, y]);
  const both = (draw) => { draw((p) => p); draw(mirror); };

  // --- Pieces (behind the ogre unless said) ---
  const aura = (c, r, col, rad = 300, y = HY) => soft(c, circle(HX, y, rad), col, r, { hatch: 26 });
  function horns(c, r, col, { reach = 1, curl = 1 } = {}) {
    both((m) => fill(c, m([...quad([520, 190], [390 - 60 * reach, 150 - 40 * curl], [370 - 70 * reach, -10 - 40 * reach], 14),
      ...quad([370 - 70 * reach, -10 - 40 * reach], [430, 110], [560, 150], 14).slice(1)]), col, r));
  }
  function batWings(c, r, col, bone = "#2a1a1a") {
    both((m) => {
      const wing = m([[420, 470], [80, 60], [150, 250], [-20, 280], [120, 420], [-30, 520], [260, 560]]);
      fill(c, wing, col, r);
      for (const tip of [[80, 60], [-20, 280], [-30, 520]]) line(c, m([[400, 470], tip]), 12, bone, r);
    });
  }
  function hair(c, r, col, { length = 620, width = 1 } = {}) {
    fill(c, [...quad([HX - 190 * width, length], [HX - 260 * width, 120], [HX, 90], 16),
      ...quad([HX, 90], [HX + 260 * width, 120], [HX + 190 * width, length], 16).slice(1)], col, r);
  }
  const ears = (c, r, col, long = 1) => both((m) => fill(c, m([[500, 210], [300 - 60 * long, 120 - 50 * long], [490, 320]]), col, r));
  const floaters = (c, r, spots, draw) => spots.forEach(([x, y], i) => draw(x, y, i));
  const CORNERS = [[200, 160], [1060, 150], [330, 330], [940, 330], [120, 380], [1140, 360]];
  function skull(c, r, x, y, s = 40, col = "#f0ece0") {
    fill(c, circle(x, y, s), col, r, { line: 12 });
    fill(c, [[x - s * 0.55, y + s * 0.6], [x + s * 0.55, y + s * 0.6], [x + s * 0.45, y + s * 1.1], [x - s * 0.45, y + s * 1.1]], col, r, { line: 12 });
    for (const dx of [-0.4, 0.4]) dab(c, x + dx * s, y, s * 0.27, OUTLINE, 0.95);
  }
  function sparkles(c, r, col, n, box, size = 26) {
    for (let i = 0; i < n; i++) fill(c, star(box[0] + r() * (box[2] - box[0]), box[1] + r() * (box[3] - box[1]), size, size * 0.4), col, r, { line: 10 });
  }
  // A weapon on his back, its top over his right shoulder (the picture's right).
  function onBack(c, r, kind, col = "#c0c8d0") {
    const base = [700, 700], tip = [1060, 120];
    const at = (t) => [base[0] + (tip[0] - base[0]) * t, base[1] + (tip[1] - base[1]) * t];
    if (kind === "sword" || kind === "runeblade") {
      const [x0, y0] = at(0.35), [x1, y1] = at(1);
      line(c, [[x0, y0], [x1, y1]], 70, kind === "runeblade" ? "#7ad8ff" : col, r);
      line(c, [at(0.3), at(0.36)], 140, "#3a3236", r);
    } else {
      line(c, [base, at(0.95)], 34, "#6a4020", r);
      const [hx, hy] = at(0.9);
      if (kind === "hammer") fill(c, rotate([[hx - 110, hy - 70], [hx + 110, hy - 70], [hx + 110, hy + 70], [hx - 110, hy + 70]], -1, hx, hy), col, r);
      if (kind === "axe") fill(c, rotate([...quad([hx, hy - 120], [hx + 210, hy - 40], [hx, hy + 120], 12)], -1, hx, hy), col, r);
      if (kind === "staff") fill(c, circle(hx, hy, 70), col, r);
    }
  }
  const chain = (c, r, pts) => pts.slice(1).forEach((p, i) => {
    const [x0, y0] = pts[i], n = 6;
    for (let k = 0; k < n; k++) fill(c, ellipse(x0 + (p[0] - x0) * k / n, y0 + (p[1] - y0) * k / n, 22, 14), "#9aa0a8", r, { line: 8, hatch: 8 });
  });
  function crest(c, r, col, spine = "#3a2414") {  // a fin crest over the head (murlocs)
    fill(c, [...quad([480, 200], [632, -120], [790, 200], 20)], col, r);
    for (const x of [540, 600, 660, 720]) line(c, [[x, 190], [x + (x - 632) * 0.4, 0]], 10, spine, r);
  }
  function quills(c, r, col) {
    for (let i = 0; i < 9; i++) {
      const a = Math.PI * (1.05 + i * 0.1), x = HX + Math.cos(a) * 330, y = 470 + Math.sin(a) * 330;
      fill(c, [[HX + Math.cos(a) * 240 - 22, 470 + Math.sin(a) * 240], [x + Math.cos(a) * 160, y + Math.sin(a) * 160],
        [HX + Math.cos(a) * 240 + 22, 470 + Math.sin(a) * 240]], col, r, { line: 12 });
    }
  }
  function antlers(c, r, col) {
    both((m) => {
      line(c, m([[520, 160], [400, 20], [300, -40]]), 34, col, r);
      line(c, m([[440, 70], [500, -50]]), 28, col, r);
      line(c, m([[350, -10], [220, 30]]), 28, col, r);
      line(c, m([[300, -40], [260, -120]]), 24, col, r);
    });
  }
  function crystalCluster(c, r, x, y, s, col) {
    for (const [dx, hgt, tilt] of [[-50, 0.8, -0.3], [0, 1.2, 0], [50, 0.9, 0.3]]) {
      fill(c, rotate([[x + dx - 26 * s, y], [x + dx, y - 200 * s * hgt], [x + dx + 26 * s, y]], tilt, x + dx, y), col, r, { line: 12 });
    }
  }
  const flameTongue = (c, r, x, y, w, ht, col = "#ff7a1a", inner = "#ffd23f") => {
    fill(c, [...quad([x - w, y], [x - w * 0.6, y - ht * 0.6], [x, y - ht], 10), ...quad([x, y - ht], [x + w * 0.6, y - ht * 0.6], [x + w, y], 10).slice(1)], col, r);
    soft(c, [...quad([x - w * 0.5, y], [x - w * 0.3, y - ht * 0.4], [x, y - ht * 0.6], 8), ...quad([x, y - ht * 0.6], [x + w * 0.3, y - ht * 0.4], [x + w * 0.5, y], 8).slice(1)], inner, r);
  };
  function book(c, r, x, y, col, tilt = 0) {
    fill(c, rotate([[x - 60, y - 44], [x + 60, y - 44], [x + 60, y + 44], [x - 60, y + 44]], tilt, x, y), col, r);
    fill(c, rotate([[x - 46, y - 32], [x + 46, y - 32], [x + 46, y + 32], [x - 46, y + 32]], tilt, x, y), "#f0e0b0", r, { line: 8 });
  }
  const shellSpikes = (c, r, col) => both((m) => {
    for (const [x, y] of [[300, 470], [200, 400], [380, 380]]) fill(c, m([[x - 40, y + 30], [x - 10, y - 90], [x + 40, y + 30]]), col, r);
  });
  function smallHead(c, r, x, y, col, eye) {  // another head on a neck (Aku'mai)
    line(c, quad([HX + (x - HX) * 0.3, 520], [x, 460], [x, y + 40], 10), 70, col, r);
    fill(c, ellipse(x, y, 90, 60), col, r);
    dab(c, x + (x < HX ? -36 : 36), y - 12, 13, hex(eye), 0.95);
  }

  // --- The bosses: base skin, name, and what's drawn ---
  const B = {
    RFC: { name: "Bazzalan", base: "sunburnt-red", behind(c, r) { aura(c, r, "#7aff4a", 310); horns(c, r, "#3a2228"); } },
    WC: { name: "Mutanus the Devourer", base: "sea-cursed-teal", behind(c, r) {
      crest(c, r, "#ff8a3a");
      both((m) => fill(c, m([[480, 300], [330, 250], [360, 330], [300, 380], [480, 360]]), "#4aa890", r));  // gill frills
      floaters(c, r, CORNERS, (x, y, i) => fill(c, circle(x, y, 18 + (i % 3) * 8), "#c8f0ff", r, { line: 8, hatch: 8 }));
    } },
    DM: { name: "Edwin VanCleef", base: "mud-brown", behind(c, r) {
      for (const s of [-1, 1]) line(c, [[HX - s * 120, 640], [HX + s * 420, 60]], 46, "#c0c8d0", r);  // two swords crossed on his back
      for (const s of [-1, 1]) line(c, [[HX + s * 330, 190], [HX + s * 450, 20]], 50, "#3a2414", r);
      hair(c, r, "#2a1a10", { length: 470, width: 0.8 });
      fill(c, [[760, 200], [900, 300], [880, 470], [800, 330]], "#2a1a10", r);  // his ponytail
      fill(c, [[300, 120], [440, 60], [420, 160]], "#c02a2a", r, { line: 10 });  // a red bandana's tails
    }, over(c, r) {  // the Defias mask: red cloth over his nose and mouth, his eyes above it, knotted at the side
      fill(c, [[478, 300], ...quad([478, 300], [632, 276], [790, 300], 14).slice(1), [800, 340], ...quad([800, 340], [790, 420], [632, 450], 14).slice(1),
        ...quad([632, 450], [480, 420], [470, 340], 14).slice(1)], "#c02a2a", r);
      for (const y of [340, 390]) line(c, quad([500, y], [632, y + 14], [770, y], 12), 8, "#8a1a1a", r);  // folds
      fill(c, [[790, 310], [880, 280], [870, 340]], "#c02a2a", r, { line: 12 });  // the knot's tails
      fill(c, [[790, 330], [860, 380], [810, 400]], "#a02020", r, { line: 12 });
    } },
    SFK: { name: "Archmage Arugal", base: "slate-gray", behind(c, r) {
      aura(c, r, "#9a6ad8", 320);
      fill(c, [[380, 420], [300, 120], [500, 300], [632, 260], [764, 300], [964, 120], [884, 420]], "#4a1a6a", r);  // his high collar
      floaters(c, r, CORNERS.slice(0, 4), (x, y) => { soft(c, circle(x, y, 60), "#c8a0ff", r); fill(c, circle(x, y, 30), "#e0c8ff", r, { line: 8 }); });
    } },
    BFD: { name: "Aku'mai", base: "celestial-blue", behind(c, r) {
      shellSpikes(c, r, "#2a4a3a");
      smallHead(c, r, 230, 180, "#3a6a9a", "#ffd23f");
      smallHead(c, r, 1030, 170, "#3a6a9a", "#ffd23f");
    } },
    STOCKS: { name: "Bazil Thredd", base: "mud-brown", behind(c, r) {
      chain(c, r, [[200, 520], [260, 300], [420, 200]]);
      chain(c, r, [[1060, 520], [1000, 300], [840, 200]]);
      fill(c, circle(160, 560, 80), "#3a3a40", r);  // a ball on the chain
      fill(c, [[340, 140], [460, 100], [430, 180]], "#c02a2a", r, { line: 10 });
    } },
    GNOMER: { name: "Mekgineer Thermaplugg", base: "slate-gray", behind(c, r) {
      for (const s of [-1, 1]) {
        fill(c, [[HX + s * 300, 520], [HX + s * 360, 160], [HX + s * 440, 160], [HX + s * 400, 520]], "#8a9098", r);  // exhaust pipes
        for (let k = 0; k < 3; k++) soft(c, circle(HX + s * (400 + k * 40), 120 - k * 70, 50 + k * 14), "#d0d0d0", r);
      }
      line(c, [[HX, 130], [HX + 40, -10]], 14, "#5a5f66", r);  // an antenna
      fill(c, circle(HX + 44, -20, 24), "#ff4a3a", r, { line: 8 });
      h.gear(c, r, 180, 300, 90, 8, "#d0a040");
      h.gear(c, r, 1080, 280, 80, 8, "#a0a8b0");
    } },
    RFK: { name: "Charlga Razorflank", base: "mud-brown", behind(c, r) {
      quills(c, r, "#e8d8b0");
      hair(c, r, "#6a3a1a", { length: 460, width: 1.1 });  // a mane
    } },
    SMGY: { name: "Bloodmage Thalnos", base: "slate-gray", behind(c, r) {
      aura(c, r, "#c02a2a", 320);
      for (const [x, y] of [[180, 170], [1080, 160], [300, 360], [960, 360]]) {
        flameTongue(c, r, x, y + 60, 50, 150, "#c02a2a", "#ff9a6a");
        skull(c, r, x, y + 10, 34);
      }
    } },
    SMLIB: { name: "Arcanist Doan", base: "sunburnt-red", behind(c, r) {
      aura(c, r, "#7a8ae8", 300);
      floaters(c, r, CORNERS.slice(0, 4), (x, y, i) => book(c, r, x, y, ["#c02a2a", "#4f86e8", "#5bd24a", "#ffd23f"][i], (i - 1.5) * 0.3));
      sparkles(c, r, "#c8d8ff", 8, [100, 40, 1150, 420], 20);
    } },
    SMARM: { name: "Herod", base: "sunburnt-red", behind(c, r) {
      onBack(c, r, "axe", "#c0c8d0");
      both((m) => {  // spiked scarlet pauldrons
        fill(c, m([[200, 560], [260, 380], [460, 380], [500, 520]]), "#c02a2a", r);
        for (const x of [270, 350, 430]) fill(c, m([[x - 26, 390], [x, 270], [x + 26, 390]]), "#c0c8d0", r, { line: 10 });
      });
    } },
    SMCATH: { name: "High Inquisitor Whitemane", base: "pale-lavender", behind(c, r) {
      fill(c, circle(HX, 160, 230), "#ffd23f", r, { holes: [circle(HX, 160, 190)] });  // a holy halo
      hair(c, r, "#f8f8f0", { length: 640, width: 1.15 });
    } },
    RFD: { name: "Amnennar the Coldbringer", base: "celestial-blue", behind(c, r) {
      aura(c, r, "#9fe8ff", 320);
      for (let i = 0; i < 7; i++) {  // a crown of ice behind his head
        const a = Math.PI * (1.15 + i * 0.12), x = HX + Math.cos(a) * 190, y = 230 + Math.sin(a) * 190;
        fill(c, [[x - 24, y + 20], [HX + Math.cos(a) * 330, 230 + Math.sin(a) * 330], [x + 24, y + 20]], "#c8f0ff", r, { line: 10 });
      }
      floaters(c, r, CORNERS, (x, y) => fill(c, rotate([[x, y - 40], [x + 20, y], [x, y + 40], [x - 20, y]], 0.4, x, y), "#e8f8ff", r, { line: 8 }));
    } },
    ULDA: { name: "Archaedas", base: "slate-gray", behind(c, r) {
      both((m) => fill(c, m([[170, 600], [200, 360], [460, 340], [480, 560]]), "#7a7068", r));  // stone shoulder blocks
      floaters(c, r, CORNERS.slice(0, 4), (x, y) => fill(c, rotate([[x - 40, y - 30], [x + 40, y - 40], [x + 30, y + 40], [x - 34, y + 30]], 0.3, x, y), "#8a8078", r));
    }, front(c, r) {
      for (const [x, y] of [[632, 170], [500, 300], [764, 300]]) { dab(c, x, y, 22, hex("#5ac8ff"), 0.5); fill(c, star(x, y, 20, 8), "#c8f0ff", r, { line: 8 }); }
    } },
    ZF: { name: "Chief Ukorz Sandscalp", base: "swamp-green", behind(c, r) {
      ears(c, r, "#8a8a5a", 1.4);
      fill(c, [[580, 140], [600, -60], [700, -40], [690, 150]], "#e04a2a", r);  // a mohawk
      for (const [x, y] of [[200, 200], [1060, 200]]) { line(c, [[x, y + 240], [x, y]], 18, "#8a5a30", r); for (const d of [-30, 0, 30]) fill(c, rotate(ellipse(x + d, y - 20, 14, 60), d / 60, x + d, y), "#e04a2a", r, { line: 8 }); }
    }, front(c, r) {
      both((m) => { line(c, m([[490, 250], [520, 250]]), 12, "#c02a2a", r); line(c, m([[485, 290], [518, 290]]), 12, "#c02a2a", r); });  // war paint
    } },
    MARA: { name: "Princess Theradras", base: "mud-brown", behind(c, r) {
      crystalCluster(c, r, 300, 480, 1.3, "#b07aff");
      crystalCluster(c, r, 960, 480, 1.3, "#e07ad8");
      hair(c, r, "#5a3a20", { length: 560 });
      for (const [x, y] of [[470, 140], [790, 140], [632, 80]]) fill(c, circle(x, y, 30), "#ff7ab0", r, { line: 10 });
    } },
    ST: { name: "Shade of Eranikus", base: "enchanted-jade", behind(c, r) {
      aura(c, r, "#9a6ad8", 330);
      batWings(c, r, "#3a8a5a", "#1f4a2a");
      horns(c, r, "#e8e0c0", { reach: 0.7 });
    } },
    BRD: { name: "Emperor Dagran Thaurissan", base: "obsidian-ember", behind(c, r) {
      for (const [x, w, ht] of [[400, 90, 260], [520, 80, 300], [744, 80, 300], [864, 90, 260], [632, 100, 340]]) flameTongue(c, r, x, 260, w, ht);
      onBack(c, r, "hammer", "#3a3236");
    } },
    LBRS: { name: "Overlord Wyrmthalak", base: "sunburnt-red", behind(c, r) {
      batWings(c, r, "#3a2228", "#1a1014");
      horns(c, r, "#e0d0b0", { reach: 1.2, curl: 0.6 });
    } },
    UBRS: { name: "General Drakkisath", base: "slate-gray", behind(c, r) {
      aura(c, r, "#ff7a1a", 320);
      batWings(c, r, "#2a2228", "#c02a2a");
      horns(c, r, "#f0e0c0", { reach: 1.4 });
    } },
    DME: { name: "Alzzin the Wildshaper", base: "enchanted-jade", behind(c, r) {
      aura(c, r, "#9aff5a", 300);
      horns(c, r, "#d8c8a0", { reach: 0.8, curl: 1.4 });
      for (const [x, y] of [[250, 300], [1010, 300], [350, 120], [910, 120]]) fill(c, ellipse(x, y, 30, 60), "#5bd24a", r, { line: 10 });
    } },
    DMW: { name: "Prince Tortheldrin", base: "celestial-blue", behind(c, r) {
      hair(c, r, "#e8e8ff", { length: 600 });
      ears(c, r, "#4a6ac0", 1.6);
      sparkles(c, r, "#9fe8ff", 10, [80, 40, 1180, 420], 22);
    } },
    DMN: { name: "King Gordok", base: "gold", behind(c, r) {
      aura(c, r, "#ffd23f", 320);
      onBack(c, r, "hammer", "#8a5a2e");
      floaters(c, r, CORNERS, (x, y) => { fill(c, circle(x, y, 32), "#ffd23f", r, { line: 10 }); dab(c, x, y, 10, hex("#c89a2a"), 0.9); });
    } },
    SCHOLO: { name: "Darkmaster Gandling", base: "pale-lavender", behind(c, r) {
      aura(c, r, "#4a2a6a", 330);
      fill(c, [...quad([340, 520], [380, 30], [632, 20], 16), ...quad([632, 20], [884, 30], [924, 520], 16).slice(1)], "#1a1418", r);  // his hood, behind
      for (const [x, y] of [[160, 200], [1100, 190], [260, 400], [1000, 400]]) skull(c, r, x, y, 36);
    } },
    STRATL: { name: "Balnazzar", base: "pale-lavender", behind(c, r) {
      aura(c, r, "#7aff4a", 300);
      batWings(c, r, "#2a1a2a");
      horns(c, r, "#d8c8a0", { reach: 1.1 });
    } },
    STRATU: { name: "Baron Rivendare", base: "slate-gray", behind(c, r) {
      aura(c, r, "#9fe8ff", 310);
      onBack(c, r, "runeblade");
      both((m) => { for (const x of [250, 340, 430]) fill(c, m([[x - 30, 440], [x, 280], [x + 30, 440]]), "#3a3a44", r, { line: 10 }); });  // armour spikes
    } },
    THANES: { name: "Durgen Dirgehammer", base: "celestial-blue", behind(c, r) {
      aura(c, r, "#e8f4ff", 330);
      onBack(c, r, "hammer", "#9aa0a8");
      fill(c, [[480, 200], [380, 60], [520, 140]], "#9aa0a8", r);  // the wings of his helm, behind
      fill(c, mirror([[480, 200], [380, 60], [520, 140]]), "#9aa0a8", r);
    } },
    RUINS: { name: "Rath'mael", base: "swamp-green", behind(c, r) {
      aura(c, r, "#7ad86a", 320);
      fill(c, [...quad([360, 520], [400, 40], [632, 30], 16), ...quad([632, 30], [864, 40], [904, 520], 16).slice(1)], "#1a2a1a", r);
      floaters(c, r, CORNERS, (x, y) => fill(c, star(x, y, 28, 11), "#9aff5a", r, { line: 8 }));
    } },
    EXCAV: { name: "Relic Guardian", base: "mud-brown", behind(c, r) {
      both((m) => fill(c, m([[170, 600], [190, 330], [450, 320], [480, 560]]), "#6a6058", r));
      for (const [x, y] of [[200, 160], [1060, 160]]) fill(c, rotate([[x - 50, y - 40], [x + 50, y - 50], [x + 40, y + 50], [x - 44, y + 40]], 0.2, x, y), "#8a8078", r);
    }, front(c, r) {
      fill(c, circle(632, 170, 26), "#5ac8ff", r, { line: 8 });  // a rune on his brow
      both((m) => fill(c, m([[492, 230], [512, 250], [492, 270], [472, 250]]), "#5ac8ff", r, { line: 6 }));
    } },
    ONY: { name: "Onyxia", base: "obsidian-ember", behind(c, r) {
      batWings(c, r, "#2a2228", "#5a3a3a");
      horns(c, r, "#e8d8b8", { reach: 1.3, curl: 0.8 });
      flameTongue(c, r, 140, 520, 80, 220);
    } },
    BARROW: { name: "Sonya Darkhallow", base: "pale-lavender", behind(c, r) {
      fill(c, circle(HX, 140, 250), "#e8e0ff", r);  // the moon behind her
      hair(c, r, "#2a2a4a", { length: 640 });
      ears(c, r, "#9a8ab8", 1.7);
      floaters(c, r, CORNERS.slice(2), (x, y) => soft(c, circle(x, y, 40), "#b8a8ff", r));
    } },
    HYJAL: { name: "The Wild King", base: "enchanted-jade", behind(c, r) {
      aura(c, r, "#c8ff5a", 320);
      antlers(c, r, "#8a6a4a");
      for (const [x, y] of [[420, 150], [844, 150], [330, 60], [934, 60], [632, 60]]) fill(c, ellipse(x, y, 34, 56), "#3a9a3a", r, { line: 10 });
    } },
  };
  // --- Over the face (in front of the eyes and mouth, under the accessory and the hat): where the face is the boss ---
  // The face: eyes at (586, 250) and (704, 250), the nose at (632, 300), the mouth about y 330..400, the chin at 410;
  // a beard can hang on over the outfit.
  function beard(c, r, col, { length = 260, shade = null, rings = null } = {}) {
    const bottom = 300 + length;
    fill(c, [[478, 300], [540, 336], [600, 346], [632, 330], [664, 346], [724, 336], [786, 300], [800, 380],
      ...quad([780, 470], [700, bottom - 40], [632, bottom], 12), ...quad([632, bottom], [564, bottom - 40], [484, 470], 12).slice(1), [464, 380]], col, r);
    if (shade) for (const x of [570, 632, 694]) line(c, quad([x, 380], [x + (x - 632) * 0.2, bottom - 120], [632 + (x - 632) * 0.5, bottom - 40], 10), 10, shade, r);
    if (rings) for (const [x, y] of [[590, bottom - 110], [674, bottom - 110]]) fill(c, ellipse(x, y, 26, 16), rings, r, { line: 8, hatch: 8 });
  }
  const goatee = (c, r, col) => fill(c, [[590, 420], [632, 412], [674, 420], [650, 510], [632, 560], [614, 510]], col, r);  // from the chin
  function tusks(c, r, col = "#f4f0e0", size = 1) {
    both((m) => fill(c, m([...quad([566, 410], [520, 360], [540, 300 - 40 * (size - 1)], 10), ...quad([540, 300 - 40 * (size - 1)], [570, 350], [596, 404], 10).slice(1)]), col, r, { line: 12 }));
  }
  const OVER = {
    RFC(c, r) { goatee(c, r, "#3a2228"); },
    WC(c, r) {  // a wide murloc mouth, full of teeth
      fill(c, ellipse(632, 370, 150, 56), "#5a1a1a", r);
      for (let i = -4; i <= 4; i++) {
        fill(c, [[632 + i * 30 - 12, 322], [632 + i * 30, 352], [632 + i * 30 + 12, 322]], "#ffffff", r, { line: 6, hatch: 6 });
        fill(c, [[632 + i * 30 - 12, 418], [632 + i * 30, 388], [632 + i * 30 + 12, 418]], "#ffffff", r, { line: 6, hatch: 6 });
      }
    },
    GNOMER(c, r) {  // brass goggles, down over his eyes
      both((m) => line(c, m([[470, 236], [524, 246]]), 22, "#4a3020", r));
      line(c, [[648, 252], [616, 252]], 18, "#b08a3a", r);
      for (const x of [586, 704]) {
        fill(c, circle(x, 252, 66), "#d0a040", r, { holes: [circle(x, 252, 46)] });
        fill(c, circle(x, 252, 46), "#9fe8ff", r, { line: 10 });
        dab(c, x - 16, 236, 12, hex("#ffffff"), 0.9);
      }
    },
    RFK(c, r) {  // a quilboar's snout, her tusks in front of it
      fill(c, ellipse(632, 330, 92, 64), "#e0a890", r);
      for (const x of [606, 658]) dab(c, x, 334, 14, OUTLINE, 0.95);
      tusks(c, r, "#f4f0e0", 1.2);
    },
    SMGY(c, r) {  // a bare skull's jaw
      fill(c, [[500, 320], [764, 320], [744, 420], [632, 440], [520, 420]], "#e8e0d0", r);
      fill(c, [[600, 300], [632, 260], [664, 300], [632, 330]], OUTLINE, r, { outline: null });  // the nose hole
      line(c, [[520, 372], [744, 372]], 8, OUTLINE, r);
      for (let x = 548; x <= 716; x += 28) line(c, [[x, 350], [x, 396]], 6, OUTLINE, r);
    },
    SMLIB(c, r) { beard(c, r, "#f4f4f0", { length: 320, shade: "#c8c8c0" }); },
    SMARM(c, r) {  // a scarlet helm's nose guard and cheek plates
      fill(c, [[612, 140], [652, 140], [652, 330], [632, 350], [612, 330]], "#c0c8d0", r);
      both((m) => fill(c, m([[470, 240], [520, 250], [534, 400], [480, 380]]), "#c02a2a", r));
    },
    RFD(c, r) {  // a beard of icicles
      for (let i = 0; i < 9; i++) {
        const x = 520 + i * 28, len = 120 + (i % 3) * 50 + (i === 4 ? 60 : 0);
        fill(c, [[x - 18, 340], [x + 18, 340], [x, 340 + len]], "#c8f0ff", r, { line: 8, hatch: 8 });
      }
    },
    ULDA(c, r) { beard(c, r, "#8a8078", { length: 280, shade: "#5a5048" }); },
    ZF(c, r) { tusks(c, r, "#f4f0e0", 1.5); },
    THANES(c, r) {  // a ghostly braided beard and his helm's nose guard
      beard(c, r, "#e8f4ff", { length: 340, shade: "#a8c8e0", rings: "#ffd23f" });
      fill(c, [[614, 150], [650, 150], [650, 320], [632, 340], [614, 320]], "#9aa0a8", r);
    },
    RUINS(c, r) {  // a tattered plague cloth over his nose and mouth
      fill(c, [[478, 300], [632, 280], [790, 300], [800, 400], [760, 460], [730, 400], [700, 470], [660, 410], [620, 480], [580, 410], [540, 460], [500, 400]], "#5a6a4a", r);
      for (const x of [560, 632, 704]) dab(c, x, 360, 8, hex("#9aff5a"), 0.9);
    },
    BRD(c, r) { beard(c, r, "#1a1418", { length: 340, shade: "#3a3236", rings: "#ffd23f" }); },
    DME(c, r) { goatee(c, r, "#3a5a2a"); },
    DMN(c, r) {  // an ogre king's tusks and a gold ring through his nose
      tusks(c, r, "#f4f0e0", 1.6);
      fill(c, circle(632, 350, 30), "#ffd23f", r, { holes: [circle(632, 344, 16)], line: 10 });
    },
    STRATU(c, r) {  // his helm's faceplate, two cold slits for eyes
      fill(c, [[480, 190], [784, 190], [784, 330], [700, 430], [632, 450], [564, 430], [480, 330]], "#3a3a44", r);
      for (const x of [586, 704]) { fill(c, [[x - 56, 240], [x + 56, 240], [x + 46, 262], [x - 46, 262]], "#7ad8ff", r, { line: 8 }); dab(c, x, 251, 24, hex("#c8f0ff"), 0.6); }
      for (let i = 0; i < 4; i++) line(c, [[600 + i * 22, 360], [600 + i * 22, 400]], 8, OUTLINE, r);
    },
    BARROW(c, r) {  // night elf markings across her eyes
      both((m) => {
        line(c, m(quad([556, 160], [530, 250], [556, 350], 12)), 26, "#3a1a5a", r);
        line(c, m(quad([616, 180], [596, 260], [606, 340], 10)), 18, "#3a1a5a", r);
      });
    },
    HYJAL(c, r) {  // a beard of leaves
      beard(c, r, "#3a8a3a", { length: 330, shade: "#2a6a2a" });
      for (const [x, y] of [[560, 420], [700, 430], [632, 520], [590, 560], [674, 560]]) fill(c, ellipse(x, y, 22, 36), "#5bd24a", r, { line: 8, hatch: 8 });
    },
  };
  for (const [key, draw] of Object.entries(OVER)) B[key].over = draw;
  return B;
};
