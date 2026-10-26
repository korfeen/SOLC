// Crayon recipes: headwear and haircuts (the gacha hair_/head_ pieces and the Pro Shop's hats).
module.exports = (H) => {
  const { GREY, BONE, GOLD, INK, eyes, googly, teeth, tri, belly, buttons } = H;
  // Points round an ellipse (centre cx, cy; radii rx, ry) from angle a0 to a1 (degrees, 0 = right, 90 = down).
  const arc = (cx, cy, rx, ry, a0, a1, n = 14) => Array.from({ length: n + 1 }, (_, i) => {
    const a = ((a0 + (a1 - a0) * (i / n)) * Math.PI) / 180; return [cx + Math.cos(a) * rx, cy + Math.sin(a) * ry]; });
  const oval = (cx, cy, rx, ry, n = 22) => arc(cx, cy, rx, ry, 0, 360, n).slice(0, -1);
  // A hair curl: a little loop drawn in one stroke.
  const curl = (d, x, y, r, col, w = 9) => d.line(arc(x, y, r, r * 1.1, 200, 520, 12), w, col);
  // (these pieces are small in the canvas - about 250px of 1254 - so every stroke and outline is drawn K times the
  // width the recipe gives (outlines sqrt(K) times), or the details vanish at the size the piece is shown; a recipe with bold: n uses n instead)
  const bold = (d, K) => ({ ...d, line: (p, w, c) => d.line(p, w * K, c),
    fill: (p, c, o = {}) => d.fill(p, c, { ...o, line: (o.line ?? 10) * Math.sqrt(K) }),
    rect: (x0, y0, x1, y1, c, o = {}) => d.rect(x0, y0, x1, y1, c, { ...o, line: (o.line ?? 10) * Math.sqrt(K) }),
    circle: (x, y, rad, c, o = {}) => d.circle(x, y, rad, c, { ...o, line: (o.line ?? 8) * Math.sqrt(K) }) });
  const R = {
    // --- Haircuts ---
    hair_afro: { base: "#6e3e24", areas: false, draw: (d) => {
      for (const [x, y] of [[0.12, 0.2], [0.3, 0.1], [0.5, 0.14], [0.68, 0.24], [0.2, 0.42], [0.4, 0.32], [0.84, 0.44],
        [0.08, 0.66], [0.9, 0.7], [0.6, 0.42], [0.14, 0.86], [0.86, 0.9]]) curl(d, x, y, 0.05, "#3e2014", 13);
      // (the pick stuck in it)
      d.fill([[0.72, 0.24], [0.92, 0.06], [0.99, 0.14], [0.79, 0.32]], "#f08030");
    } },
    hair_bowlcut: { base: "#8e5a30", areas: false, draw: (d) => {
      for (const [x0, y0, x1, y1] of [[0.12, 0.3, 0.08, 0.7], [0.24, 0.18, 0.2, 0.42], [0.38, 0.1, 0.36, 0.36], [0.5, 0.08, 0.5, 0.36],
        [0.62, 0.1, 0.64, 0.36], [0.76, 0.18, 0.8, 0.42], [0.88, 0.3, 0.92, 0.7]]) d.line([[x0, y0], [x1, y1]], 10, "#5a3418");
      d.line(arc(0.5, 0.42, 0.36, 0.3, 200, 340, 10), 9, "#c88a50");
    } },
    // (thin strands: the base's outline is most of it; the lines show where the strands are wide enough)
    hair_combover: { base: "#7a4a28", areas: false, draw: (d) => {
      for (const [top, col] of [[0.02, "#5a3418"], [0.18, "#8a5a32"], [0.34, "#5a3418"], [0.5, "#a06a3a"]])
        d.line(arc(0.52, 0.95, 0.5, 0.93 - top, 180, 355, 18), 12, col);
    } },
    hair_mullet: { base: "#a86a3a", areas: false, draw: (d) => {
      // (spiky short top, long business at the back)
      for (const x of [0.28, 0.38, 0.48, 0.58, 0.68]) d.line([[x, 0.2], [x + 0.04, 0.03]], 10, "#6a3e20");
      for (const x of [0.06, 0.12, 0.17]) d.line([[x + 0.1, 0.35], [x + 0.02, 0.6], [x - 0.02, 0.9]], 9, "#6a3e20");
      for (const x of [0.83, 0.88, 0.94]) d.line([[x - 0.1, 0.35], [x - 0.02, 0.6], [x + 0.02, 0.9]], 9, "#6a3e20");
    } },
    hair_pompadour: { base: "#4e342a", areas: false, draw: (d) => {
      // (the big front wave, swept back in a few bold strokes, with a shine)
      d.line([[0.14, 0.6], [0.24, 0.38], [0.44, 0.26], [0.66, 0.24], [0.82, 0.32]], 7, "#8a6a58");
      d.line([[0.42, 0.14], [0.58, 0.11], [0.72, 0.15]], 7, "#e8c8b0");
    } },
    hair_slicked: { base: "#9a6a3a", areas: false, draw: (d) => {
      // (comb lines running straight back, and a shine)
      d.line(arc(0.52, 0.95, 0.38, 0.7, 200, 340, 14), 11, "#d8a870");
      d.line(arc(0.55, 0.6, 0.3, 0.46, 225, 290, 6), 13, "#f8e0b8");
    } },
    // (a tiny piece, 78px across: thin strokes, or the outline swallows them)
    hair_topknot: { base: "#9a6038", areas: false, bold: 1, draw: (d) => {
      d.line(arc(0.5, 0.3, 0.14, 0.16, 180, 470, 12), 5, "#4a2a18");
      d.line([[0.3, 0.56], [0.7, 0.56]], 7, "#d8402e");
    } },
    hair_braid: { base: "#7a4a2a", areas: false, draw: (d) => {
      // (the plait: crossing strokes down its length, and two ribbon ties)
      const path = [[0.84, 0.05], [0.62, 0.18], [0.5, 0.32], [0.4, 0.46], [0.32, 0.6], [0.24, 0.74], [0.16, 0.88]];
      for (const [x, y] of path) { d.line([[x - 0.1, y - 0.02], [x, y + 0.03]], 12, "#3e2414"); d.line([[x, y + 0.03], [x + 0.1, y - 0.03]], 12, "#3e2414"); }
      for (const [x, y] of [[0.45, 0.39], [0.2, 0.81]]) d.line([[x - 0.12, y - 0.01], [x + 0.12, y - 0.05]], 18, "#f08030");
    } },
    hair_powdered_wig: { base: "#f4e8e0", areas: false, draw: (d) => {
      // (rows of rolled curls: a loop for each roll)
      for (const [x, y] of [[0.3, 0.06], [0.42, 0.04], [0.54, 0.04], [0.66, 0.06], [0.2, 0.14], [0.78, 0.14]]) curl(d, x, y + 0.03, 0.045, "#b08888", 11);
      for (const y of [0.3, 0.45, 0.6, 0.75, 0.9]) { curl(d, 0.07, y, 0.05, "#b08888", 11); curl(d, 0.92, y, 0.05, "#b08888", 11); }
    } },
    // --- Hats ---
    head_bin_lid: { base: "#a8a8b4", areas: false, draw: (d) => {
      d.line([[0.08, 0.62], [0.5, 0.5], [0.94, 0.66]], 10, "#e8e8f0");
      for (const x of [0.25, 0.75]) d.line([[x, 0.62], [x + 0.02, 0.74]], 8, "#6a6a78");
    } },
    head_bobble: { base: "#b83a3a", areas: false, draw: (d) => {
      // (striped knit hat, goggles across it, a big pompom)
      for (const y of [0.56, 0.68]) d.line([[0.05, y + 0.12], [0.5, y], [0.95, y + 0.14]], 6, "#f0e0c8");
      d.fill(oval(0.2, 0.18, 0.16, 0.16), "#f0e0c0", { hatch: 10, line: 9 });
      d.fill([[0.18, 0.42], [0.95, 0.32], [0.98, 0.5], [0.2, 0.6]], "#3a3a44", { line: 8 });
      d.fill(oval(0.42, 0.46, 0.15, 0.1), "#5ab8e8", { line: 8 }); d.fill(oval(0.76, 0.41, 0.15, 0.1), "#5ab8e8", { line: 8 });
    } },
    head_cricket_cap: { base: "#465a44", areas: false, draw: (d) => {
      // (the club crest: a gold shield with crossed bats, a crown on top)
      d.fill([[0.44, 0.28], [0.64, 0.28], [0.64, 0.48], [0.54, 0.58], [0.44, 0.48]], GOLD, { line: 6 });
      d.line([[0.48, 0.33], [0.6, 0.5]], 3, "#7a4a1e"); d.line([[0.6, 0.33], [0.48, 0.5]], 3, "#7a4a1e");
      d.fill([[0.46, 0.25], [0.47, 0.13], [0.51, 0.19], [0.54, 0.11], [0.57, 0.19], [0.61, 0.13], [0.62, 0.25]], GOLD, { line: 5 });
      d.line(arc(0.5, 1.0, 0.44, 0.36, 195, 345, 10), 9, "#6a7e66");
    } },
    head_deerstalker: { base: "#b0703e", areas: false, draw: (d) => {
      // (tweed checks, the bow on top)
      for (const x of [0.25, 0.42, 0.58, 0.75]) d.line([[x, 0.14], [x + (x - 0.5) * 0.3, 0.86]], 7, "#6a3e22");
      for (const y of [0.32, 0.52, 0.72]) d.line([[0.06, y + 0.04], [0.5, y - 0.02], [0.94, y + 0.04]], 7, "#c8402e");
      tri(d, [0.5, 0.07], [0.33, 0.0], [0.36, 0.13], "#6a3a22"); tri(d, [0.5, 0.07], [0.67, 0.0], [0.64, 0.13], "#6a3a22");
      d.circle(0.5, 0.07, 0.035, "#6a3a22");
    } },
    head_fishing_hat: { base: "#8e7e56", areas: false, draw: (d) => {
      // (the band, stuck full of bright flies and lures)
      d.line([[0.08, 0.5], [0.5, 0.36], [0.94, 0.5]], 14, "#5a4a30");
      for (const [x, y, col] of [[0.2, 0.32, "#d8402e"], [0.34, 0.22, "#3a8ad8"], [0.48, 0.18, GOLD], [0.6, 0.2, "#40a050"], [0.74, 0.26, "#d8402e"], [0.86, 0.36, "#3a8ad8"]]) {
        d.fill([[x, y - 0.06], [x + 0.04, y + 0.06], [x - 0.04, y + 0.06]], col, { line: 6, hatch: 6 });
      }
    } },
    head_jockey_cap: { base: "#8e3aa0", areas: false, draw: (d) => {
      // (racing silks: yellow quarters meeting at the button)
      d.fill([[0.47, 0.06], [0.16, 0.42], [0.22, 0.73], [0.42, 0.67]], "#f4b830", { line: 8 });
      d.fill([[0.55, 0.06], [0.66, 0.68], [0.84, 0.73], [0.88, 0.4]], "#f4b830", { line: 8 });
      d.circle(0.5, 0.04, 0.04, "#8e3aa0");
    } },
    head_knockoff_cap: { base: "#a83a4a", areas: false, draw: (d) => {
      // (a lopsided fake-logo patch: a white box with a squiggle, no real brand)
      d.fill([[0.16, 0.5], [0.4, 0.38], [0.44, 0.52], [0.2, 0.66]], "#f4f0e8", { line: 7 });
      d.line([[0.22, 0.56], [0.27, 0.48], [0.31, 0.54], [0.36, 0.46], [0.4, 0.5]], 6, "#a83a4a");
      d.line(arc(0.52, 1.0, 0.46, 0.34, 190, 300, 8), 7, "#d86a7a");
    } },
    head_souwester: { base: "#f4c430", areas: false, draw: (d) => {
      d.line(arc(0.5, 0.42, 0.3, 0.34, 190, 350, 12), 10, "#c8901e");
      for (const x of [0.12, 0.88]) d.line([[x, 0.55], [x + (x < 0.5 ? -0.02 : 0.02), 0.9]], 8, "#c8901e");
    } },
    head_tinfoil: { base: "#cfd0dc", areas: false, draw: (d) => {
      // (crinkles, and the antenna's ball)
      d.line([[0.2, 0.74], [0.32, 0.6], [0.4, 0.72], [0.5, 0.56], [0.6, 0.7], [0.7, 0.58]], 8, "#8a8a9a");
      d.line([[0.36, 0.5], [0.46, 0.4], [0.54, 0.48], [0.6, 0.36]], 8, "#ffffff");
      d.circle(0.66, 0.06, 0.05, "#e8e8f0");
    } },
    head_traffic_cone: { base: "#f47a2a", areas: false, draw: (d) => {
      d.fill([[0.36, 0.26], [0.8, 0.26], [0.84, 0.46], [0.32, 0.46]], "#f8f4ec", { line: 8 });
      d.line([[0.04, 0.84], [0.5, 0.72], [0.96, 0.88]], 10, "#c8501e");
    } },
    head_ascot_hat: { base: "#d0a8d8", areas: false, draw: (d) => {
      // (a race-day brim: a purple ribbon sweeping off it, a bunch of flowers on the crown)
      d.fill([[0.62, 0.42], [0.86, 0.34], [1.0, 0.5], [0.98, 0.86], [0.88, 0.62], [0.68, 0.6]], "#9a5ab8", { line: 8 });
      for (const [x, y] of [[0.18, 0.4], [0.3, 0.22], [0.44, 0.32]]) d.line([[x - 0.06, y + 0.06], [x + 0.06, y - 0.04]], 10, "#4a9a4a");
      for (const [x, y, col] of [[0.22, 0.3, "#f0a0b8"], [0.34, 0.36, "#f8e8c0"], [0.42, 0.2, "#f0a0b8"], [0.52, 0.34, "#e86a8a"]]) { d.circle(x, y, 0.04, col, { line: 6 }); d.circle(x, y, 0.012, GOLD, { line: 0 }); }
    } },
    head_aviator: { base: "#8e522e", areas: false, draw: (d) => {
      // (leather flying helmet: goggles up on top, seams down the ear flaps)
      d.line([[0.06, 0.2], [0.5, 0.1], [0.94, 0.2]], 14, "#4a2a18");
      for (const x of [0.33, 0.67]) { d.circle(x, 0.14, 0.1, GOLD, { line: 8 }); d.circle(x, 0.14, 0.07, "#6a8a9a", { line: 0 }); d.line([[x - 0.03, 0.1], [x + 0.01, 0.07]], 6, "#e8f4f8"); }
      for (const x of [0.12, 0.88]) d.line([[x, 0.4], [x, 0.85]], 7, "#c88a5a");
    } },
    head_fascinator: { base: "#8a2a6a", areas: false, draw: (d) => {
      // (a feather spray out of a little hat, a flower in the middle)
      for (const [x, y] of [[0.06, 0.5], [0.16, 0.22], [0.36, 0.04], [0.6, 0.06]]) d.line([[0.46, 0.5], [(0.46 + x) / 2 + 0.03, (0.5 + y) / 2 - 0.03], [x, y]], 10, "#d870b8");
      d.circle(0.48, 0.5, 0.06, "#e8a0c8", { line: 7 }); d.circle(0.48, 0.5, 0.02, INK, { line: 0 });
    } },
    head_fencing_mask: { base: "#4e4a54", areas: false, draw: (d) => {
      // (the mesh face, a silver rim, the white bib hanging down the side)
      for (let x = 0.36; x < 0.95; x += 0.1) d.line([[x, 0.08], [x + 0.04, 0.6]], 6, "#9a9aa8");
      for (const y of [0.18, 0.3, 0.42, 0.54]) d.line([[0.34, y], [0.95, y + 0.04]], 6, "#9a9aa8");
      d.line([[0.2, 0.52], [0.5, 0.56], [0.9, 0.7]], 14, "#d8d8e0");
      d.fill([[0.0, 0.36], [0.16, 0.3], [0.3, 0.56], [0.26, 0.94], [0.1, 0.98], [0.02, 0.7]], "#f2ece4", { line: 8 });
    } },
    head_fishbowl: { base: "#c4e6f4", areas: false, draw: (d) => {
      // (see-through glass: pale water, a goldfish wearing a tiny crown, a gold stand)
      d.line([[0.06, 0.24], [0.3, 0.2], [0.5, 0.24], [0.7, 0.2], [0.94, 0.24]], 9, "#6ab8e0");
      d.line(arc(0.5, 0.5, 0.4, 0.38, 160, 220, 6), 10, "#ffffff");
      tri(d, [0.3, 0.5], [0.14, 0.36], [0.14, 0.66], "#f08a2a");
      d.fill(oval(0.5, 0.52, 0.2, 0.15), "#f8962e", { line: 9 });
      eyes(d, [[0.6, 0.48]], 0.03);
      d.line([[0.58, 0.6], [0.64, 0.58]], 6, INK);
      d.fill([[0.44, 0.38], [0.44, 0.26], [0.48, 0.32], [0.52, 0.24], [0.56, 0.32], [0.6, 0.26], [0.6, 0.38]], GOLD, { line: 6 });
      d.rect(0.08, 0.88, 0.92, 1.0, GOLD, { line: 8 });
    } },
    head_polo_helmet: { base: "#343a6a", areas: false, draw: (d) => {
      // (navy helmet, a little club crest on the front, a brown chin strap)
      d.fill([[0.44, 0.04], [0.58, 0.04], [0.58, 0.12], [0.51, 0.17], [0.44, 0.12]], GOLD, { line: 6 });
      d.circle(0.51, 0.09, 0.02, "#d8402e", { line: 0 });
      d.line([[0.06, 0.28], [0.5, 0.22], [0.94, 0.28]], 9, "#5a62a0");
      d.line(arc(0.5, 0.72, 0.38, 0.26, 0, 180, 14), 10, "#8a5a32");
    } },
    shop_bowler_hat: { base: "#4a3242", areas: false, draw: (d) => {
      d.line([[0.14, 0.6], [0.5, 0.54], [0.84, 0.6]], 16, "#24161e");
      d.line(arc(0.5, 0.45, 0.24, 0.36, 210, 270, 6), 12, "#9a7a8e");
    } },
    shop_flat_cap: { base: "#b4743e", areas: false, draw: (d) => {
      // (tweed: a few checks, and the snap brim's edge)
      for (const x of [0.2, 0.36, 0.52, 0.68, 0.84]) d.line([[x, 0.12], [x - 0.04, 0.72]], 7, "#6a3e22");
      for (const y of [0.3, 0.52]) d.line([[0.04, y + 0.06], [0.5, y - 0.04], [0.96, y + 0.12]], 7, "#c8402e");
      d.line([[0.5, 0.6], [0.75, 0.68], [0.94, 0.86]], 9, "#7a4a28");
    } },
    shop_panama: { base: "#f2e4c0", areas: false, draw: (d) => {
      d.rect(0.3, 0.24, 0.76, 0.42, "#2a6a3a", { line: 6 });
      d.line([[0.31, 0.33], [0.75, 0.33]], 5, "#f0c040");
      d.line([[0.04, 0.6], [0.3, 0.5], [0.7, 0.52], [0.96, 0.76]], 5, "#c8a870");
    } },
    shop_service_bell: { base: "#e8b040", areas: false, draw: (d) => {
      // (the front-desk bell: a shine on the dome, the darker base ring, the button on top)
      d.line(arc(0.5, 0.62, 0.3, 0.42, 200, 250, 5), 9, "#fff0b0");
      d.rect(0.04, 0.72, 0.96, 0.88, "#b07a20", { line: 8 });
      d.circle(0.5, 0.08, 0.06, "#f0c860", { line: 6 });
    } },
    shop_smoking_cap: { base: "#a82a3a", areas: false, draw: (d) => {
      // (velvet with a gold embroidered band, and the gold tassel)
      d.line([[0.04, 0.24], [0.28, 0.2], [0.52, 0.26], [0.7, 0.4]], 10, GOLD);
      d.fill([[0.8, 0.55], [0.72, 1.0], [0.99, 1.0], [0.92, 0.55]], GOLD, { line: 6 });
      for (const x of [0.8, 0.86, 0.92]) d.line([[x + 0.01, 0.62], [x, 0.96]], 3, "#a87a20");
    } },
    shop_straw_boater: { base: "#e4bc64", areas: false, draw: (d) => {
      // (flat-topped straw, a striped ribbon band)
      d.rect(0.2, 0.16, 0.8, 0.5, "#2a5a3a", { line: 6 });
      d.line([[0.21, 0.33], [0.79, 0.33]], 6, "#c8302e");
      d.line([[0.06, 0.72], [0.5, 0.68], [0.94, 0.72]], 5, "#b08a3a");
    } },
    shop_tam_pompom: { base: "#c8303a", areas: false, draw: (d) => {
      // (tartan tam: a few dark plaid lines, a big red pompom)
      for (const x of [0.2, 0.42, 0.64, 0.84]) d.line([[x, 0.2], [x + 0.04, 0.8]], 7, "#2a3e34");
      for (const y of [0.36, 0.58]) d.line([[0.02, y], [0.5, y - 0.04], [0.98, y + 0.08]], 7, "#2a3e34");
      d.line([[0.04, 0.47], [0.5, 0.43], [0.96, 0.55]], 3, GOLD);
      d.circle(0.6, 0.1, 0.1, "#e8303a", { line: 7 });
      for (const [x, y] of [[0.57, 0.07], [0.63, 0.12], [0.6, 0.15]]) d.line([[x - 0.02, y], [x + 0.02, y]], 4, "#a81e28");
    } },
    shop_golfball_hat: { base: "#f4f0ec", areas: false, draw: (d) => {
      // (half a golf ball: rows of dimples, a red tee stuck in the top)
      for (const [y, xs] of [[0.3, [0.3, 0.45, 0.6, 0.75]], [0.45, [0.15, 0.3, 0.45, 0.6, 0.75, 0.88]], [0.62, [0.08, 0.22, 0.78, 0.92]]])
        for (const x of xs) d.circle(x, y, 0.035, "#c8c4c8", { line: 0 });
      d.fill([[0.6, 0.0], [0.8, 0.0], [0.73, 0.1], [0.72, 0.22], [0.68, 0.22], [0.67, 0.1]], "#e02a2a", { line: 6 });
    } },
    shop_putting_green_hat: { base: "#6aa83a", areas: false, draw: (d) => {
      // (a little putting green: the hole, a ball, the flag)
      d.line([[0.06, 0.86], [0.5, 0.92], [0.94, 0.84]], 9, "#3e7a26");
      d.fill(oval(0.56, 0.62, 0.11, 0.06), "#2a2a22", { line: 5 });
      d.circle(0.38, 0.52, 0.08, "#ffffff", { line: 6 });
      d.line([[0.7, 0.62], [0.7, 0.04]], 6, "#f0f0f0");
      d.fill([[0.7, 0.04], [0.96, 0.14], [0.7, 0.26]], "#e02a2a", { line: 6 });
    } },
    shop_yacht_cap: { base: "#f4f2ee", areas: false, draw: (d) => {
      // (captain's cap: white top, black band and peak, gold braid, an anchor badge)
      d.fill([[0.06, 0.6], [0.5, 0.52], [0.94, 0.6], [0.96, 0.98], [0.5, 0.86], [0.04, 0.92]], "#26283a", { line: 6 });
      d.line([[0.1, 0.66], [0.5, 0.58], [0.92, 0.68]], 8, GOLD);
      d.circle(0.6, 0.26, 0.12, "#26283a", { line: 6 });
      d.line([[0.6, 0.16], [0.6, 0.36]], 5, GOLD); d.line([[0.55, 0.2], [0.65, 0.2]], 4, GOLD);
      d.line(arc(0.6, 0.28, 0.06, 0.07, 20, 160, 6), 4, GOLD);
    } },
  };
  for (const r of Object.values(R)) if (r.draw) { const f = r.draw; r.draw = (d, rr) => f(bold(d, r.bold || 2.2), rr); }
  return R;
};
