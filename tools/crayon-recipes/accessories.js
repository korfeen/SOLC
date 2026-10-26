// Crayon recipes: accessories (the club's held things, pets and bounty props), read off each painting on a tenths grid.
module.exports = (H) => {
  const { GREY, BONE, GOLD, INK, eyes, googly, teeth, tri, belly, buttons } = H;
  return {
    acc_cigar_box: { base: "#8a3a1e", areas: false, draw: (d) => {
      d.fill([[0.38, 0.06], [0.96, 0.08], [0.96, 0.44], [0.36, 0.42]], "#d8703a");
      for (let k = 0; k < 7; k++) { const x = 0.2 + k * 0.105;
        d.fill([[x, 0.52], [x + 0.08, 0.5], [x + 0.06, 0.96], [x - 0.02, 0.98]], "#9a5a30", { hatch: 8, line: 6 });
        d.fill([[x - 0.0, 0.6], [x + 0.077, 0.59], [x + 0.075, 0.65], [x - 0.003, 0.66]], GOLD, { line: 4, hatch: 6 });
        d.circle(x + 0.036, 0.625, 0.018, "#d8302e", { line: 0 }); }
      d.rect(0.44, 0.92, 0.56, 1.0, GOLD); d.rect(0.0, 0.8, 0.06, 1.0, GOLD); d.rect(0.62, 0.0, 0.72, 0.05, GOLD);
    } },
    acc_cricket_bat: { base: "#f0d090", areas: false, draw: (d) => {
      d.line([[0.5, 0.06], [0.52, 0.86]], 10, "#c8a060");
      d.circle(0.5, 0.33, 0.16, "#e8907a", { line: 0, hatch: 8 }); d.circle(0.5, 0.33, 0.07, "#d84a4a", { line: 0 });
      d.rect(0.5, 0.9, 0.85, 1.0, "#2e2a2a");
    } },
    acc_croquet_mallet: { base: "#e8823a", areas: false, draw: (d) => {
      d.rect(0.0, 0.0, 1.0, 0.16, "#d8302e");
      for (const x of [0.18, 0.3, 0.7, 0.82]) d.rect(x, 0.0, x + 0.06, 0.16, "#fff4e0", { line: 6 });
      d.rect(0.4, 0.24, 0.6, 0.27, "#d8302e"); d.rect(0.4, 0.3, 0.6, 0.33, "#fff4e0"); d.rect(0.4, 0.36, 0.6, 0.39, "#d8302e");
    } },
    acc_diamond_monocle: { base: GOLD, areas: false },
    acc_falcon: { base: "#9a5a30", areas: false, draw: (d) => {
      d.fill([[0.5, 0.36], [0.82, 0.38], [0.92, 0.6], [0.84, 0.84], [0.62, 0.9], [0.46, 0.7]], "#f4e2c4");
      for (const [x, y] of [[0.62, 0.5], [0.76, 0.52], [0.58, 0.64], [0.72, 0.66], [0.66, 0.78], [0.82, 0.7]]) d.line([[x - 0.025, y], [x, y + 0.025], [x + 0.025, y]], 8, "#8a4a26");
      for (const [x0, y0] of [[0.12, 0.6], [0.16, 0.75], [0.24, 0.48]]) d.line([[x0, y0], [x0 + 0.18, y0 - 0.1]], 12, "#5a3218");
      d.fill([[0.36, 0.2], [0.5, 0.06], [0.74, 0.02], [0.96, 0.12], [0.98, 0.3], [0.84, 0.38], [0.5, 0.36]], "#c8783a");
      d.circle(0.82, 0.04, 0.05, "#c8783a", { line: 6 });
      d.line([[0.44, 0.24], [0.92, 0.22]], 9, GOLD);
      tri(d, [0.8, 0.34], [0.94, 0.38], [0.84, 0.48], "#e8c050");
      for (const x of [0.5, 0.65]) d.line([[x - 0.05, 1.0], [x, 0.9], [x + 0.05, 1.0]], 11, "#f0b030");
    } },
    acc_foil: { base: "#c0c0cc", areas: false, draw: (d) => {
      d.fill([[0.15, 0.93], [0.5, 0.86], [0.98, 0.93], [0.6, 0.99]], "#e0e0ea");
    } },
    acc_gilded_club: { base: GOLD, areas: false, draw: (d) => {
      for (const y of [0.32, 0.6, 0.84]) d.rect(0.08, y, 0.92, y + 0.035, "#b8862a");
      d.circle(0.72, 0.14, 0.15, "#d8202e"); d.circle(0.3, 0.12, 0.11, "#2a9a4a");
      d.circle(0.45, 0.42, 0.11, "#2a4ad8"); d.circle(0.72, 0.5, 0.1, "#2a9a4a"); d.circle(0.35, 0.72, 0.09, "#d8202e");
    } },
    acc_peacock: { base: "#2a6ae8", areas: false, draw: (d) => {
      d.fill([[0.42, 0.46], [0.78, 0.44], [1.0, 0.64], [0.96, 0.94], [0.6, 0.96], [0.44, 0.72]], "#2a9a4a");
      for (const [x, y] of [[0.62, 0.6], [0.84, 0.7], [0.68, 0.82]]) { d.circle(x, y, 0.08, GOLD, { line: 5 }); d.circle(x, y, 0.045, "#1e3a8a", { line: 0 }); }
      for (const [x, y] of [[0.26, 0.06], [0.38, 0.03], [0.5, 0.08]]) d.circle(x, y, 0.05, "#2ab0c0", { line: 5 });
      d.circle(0.22, 0.3, 0.09, "#f4ecd8", { line: 5 });
      d.line([[0.15, 0.3], [0.22, 0.34], [0.29, 0.3]], 13, INK);
      tri(d, [0.32, 0.33], [0.44, 0.4], [0.32, 0.46], "#e8b040");
    } },
    acc_polo_mallet: { base: "#e8b050", areas: false, draw: (d) => {
      d.rect(0.0, 0.0, 1.0, 0.07, "#f0d090");
      for (const x of [0.2, 0.75]) d.rect(x, 0.0, x + 0.06, 0.07, "#d8302e", { line: 6 });
      for (const y of [0.25, 0.42, 0.6, 0.76]) d.line([[0.35, y], [0.65, y]], 9, "#a86a2a");
      d.rect(0.3, 0.88, 0.7, 1.0, "#d8406a");
    } },
    acc_riding_crop: { base: "#3a3034", areas: false, draw: (d) => {
      d.fill([[0.45, 0.0], [1.0, 0.0], [0.9, 0.09], [0.55, 0.08]], "#8a3a4a");
      for (const y of [0.74, 0.92]) d.rect(0.0, y, 1.0, y + 0.02, "#c8c8d0", { line: 4 });
    } },
    acc_tiny_butler: { base: "#2e2a30", areas: false, draw: (d) => {
      d.fill([[0.27, 0.36], [0.48, 0.36], [0.46, 0.7], [0.29, 0.7]], "#f8f4ec");
      tri(d, [0.37, 0.41], [0.29, 0.37], [0.29, 0.46], INK); tri(d, [0.37, 0.41], [0.45, 0.37], [0.45, 0.46], INK);
      buttons(d, 0.37, [0.53, 0.62], INK, 0.015);
      d.fill([[0.14, 0.04], [0.32, 0.0], [0.5, 0.04], [0.56, 0.18], [0.5, 0.32], [0.32, 0.37], [0.14, 0.32], [0.08, 0.18]], "#8ab83a");
      tri(d, [0.0, 0.08], [0.14, 0.12], [0.12, 0.26], "#8ab83a"); tri(d, [0.66, 0.16], [0.52, 0.12], [0.52, 0.26], "#8ab83a");
      for (const x of [0.23, 0.41]) d.line([[x - 0.04, 0.15], [x, 0.18], [x + 0.04, 0.15]], 12, INK);
      d.line([[0.24, 0.25], [0.32, 0.28], [0.4, 0.25]], 12, INK);
      d.fill(Array.from({ length: 13 }, (_, i) => { const a = Math.PI + (i / 12) * Math.PI; return [0.77 + Math.cos(a) * 0.19, 0.41 + Math.sin(a) * 0.19]; }), "#c8ccd8");
      d.rect(0.52, 0.4, 0.99, 0.44, "#e0e0e8", { line: 6 });
      d.circle(0.25, 0.55, 0.05, "#8ab83a", { line: 6 });
      for (const [x, y] of [[0.21, 0.92], [0.31, 0.95]]) d.circle(x, y, 0.045, "#8ab83a", { line: 6 });
    } },
    acc_trophy_fish: { base: "#2a4aa8", areas: false, draw: (d) => {
      d.fill([[0.18, 0.12], [0.5, 0.2], [0.62, 0.45], [0.56, 0.72], [0.4, 0.5], [0.28, 0.26]], "#f0f0f4");
      for (const y of [0.3, 0.42, 0.54]) d.line([[0.5, y], [0.58, y + 0.04]], 8, "#5a8ae8");
      d.circle(0.4, 0.12, 0.05, "#ffffff"); d.circle(0.41, 0.13, 0.025, INK);
    } },
    acc_whiskey: { base: "#e88a20", areas: false, draw: (d) => {
      d.fill([[0.0, 0.0], [1.0, 0.0], [1.0, 0.3], [0.0, 0.34]], "#eef2f2");
      d.line([[0.0, 0.33], [1.0, 0.29]], 10, "#c86a10");
      d.fill([[0.3, 0.2], [0.52, 0.1], [0.72, 0.22], [0.66, 0.46], [0.36, 0.48]], "#fff4d0");
      d.fill([[0.0, 0.8], [1.0, 0.78], [1.0, 1.0], [0.0, 1.0]], "#f0c070");
      for (let k = 0; k < 6; k++) { const x = 0.05 + k * 0.18; d.line([[x, 0.8], [x + 0.09, 0.9], [x, 1.0]], 6, "#a8661a"); }
    } },
    shop_champagne_flute: { base: "#f0c040", areas: false, draw: (d) => {
      d.fill([[0.0, 0.0], [1.0, 0.0], [1.0, 0.1], [0.0, 0.12]], "#f4f2ea");
      for (const [x, y] of [[0.4, 0.25], [0.55, 0.36], [0.38, 0.46], [0.6, 0.2], [0.5, 0.56], [0.46, 0.32]]) d.circle(x, y, 0.035, "#fffbe8", { line: 0 });
    } },
    shop_golf_glove_ball: { base: "#f4f0e8", areas: false, draw: (d) => {
      d.fill([[0.3, 0.12], [0.78, 0.06], [0.84, 0.24], [0.36, 0.32]], "#c8965a");
      d.circle(0.6, 0.18, 0.07, GOLD);
      for (const x of [0.16, 0.42, 0.62, 0.84]) for (const y of [0.62, 0.7, 0.78]) d.circle(x + (y - 0.7) * 0.1, y, 0.012, INK, { line: 0 });
    } },
    shop_club_key: { base: GOLD, areas: false, draw: (d) => {
      for (const [x, y] of [[0.3, 0.14], [0.42, 0.34], [0.52, 0.5]]) d.line([[x - 0.06, y + 0.05], [x + 0.06, y - 0.05]], 12, "#b8862a");
      d.fill([[0.66, 0.67], [0.71, 0.74], [0.66, 0.81], [0.61, 0.74]], "#2a9a4a", { line: 6 });
      d.fill([[0.79, 0.81], [0.85, 0.9], [0.79, 0.99], [0.73, 0.9]], "#d8202e", { line: 6 });
    } },
    shop_driver: { base: "#a8582a", areas: false, draw: (d) => {
      d.circle(0.35, 0.05, 0.12, "#e8a060", { line: 0 });
      d.line([[0.08, 0.14], [0.6, 0.18], [0.92, 0.12]], 8, "#6a3418");
      d.rect(0.38, 0.88, 0.62, 1.0, "#2e2a2a", { line: 6 });
    } },
    shop_golf_bag: { base: "#8a4a24", areas: false, draw: (d) => {
      d.circle(0.32, 0.2, 0.15, "#2a4aa8"); d.line([[0.24, 0.3], [0.42, 0.26]], 10, "#f0ecd8");
      d.circle(0.48, 0.07, 0.13, "#f0e0c0"); d.line([[0.46, 0.18], [0.62, 0.16]], 10, "#2a4aa8");
      d.circle(0.74, 0.1, 0.13, "#c8282e"); d.line([[0.66, 0.22], [0.84, 0.22]], 10, "#f0ecd8");
      d.line([[0.15, 0.33], [0.95, 0.31]], 16, "#5a2e14");
      d.rect(0.08, 0.5, 0.42, 0.7, "#b06a34"); d.rect(0.24, 0.72, 0.58, 0.9, "#b06a34");
      d.line([[0.96, 0.4], [0.86, 0.7], [0.62, 1.0]], 18, "#c8803e");
      d.rect(0.76, 0.46, 0.88, 0.53, GOLD, { line: 6 });
    } },
    shop_gopher: { base: "#c8783a", areas: false, draw: (d) => {
      // (a tiny piece: the outline takes most of it, so only the ball and the sleepy eyes)
      for (const x of [0.36, 0.66]) d.line([[x - 0.1, 0.29], [x, 0.32], [x + 0.1, 0.29]], 9, INK);
      d.circle(0.5, 0.64, 0.24, "#ffffff", { line: 6 });
    } },
    shop_lapdog: { base: "#f8e8e0", areas: false, draw: (d) => {
      // (a tiny piece: the pink bow, a sleepy eye and the nose)
      tri(d, [0.3, 0.42], [0.16, 0.3], [0.18, 0.56], "#f06a9a"); tri(d, [0.3, 0.42], [0.44, 0.3], [0.42, 0.56], "#f06a9a");
      d.line([[0.42, 0.24], [0.5, 0.27], [0.58, 0.24]], 9, INK);
      d.circle(0.66, 0.18, 0.05, INK, { line: 0 });
    } },
    shop_putter: { base: "#a8a8b4", areas: false, draw: (d) => {
      d.fill([[0.72, 0.75], [0.84, 0.75], [0.96, 1.0], [0.84, 1.0]], "#2e2a2a");
    } },
    shop_tennis_racket: { base: "#e8902e", draw: (d) => {
      for (const y of [0.74, 0.78]) d.line([[0.62, y], [0.7, y - 0.03]], 7, "#5a3418");
    } },
    shop_trophy_cup: { base: GOLD, areas: false, draw: (d) => {
      d.rect(0.14, 0.36, 0.86, 0.42, "#c8902a");
      d.line([[0.32, 0.47], [0.34, 0.68]], 18, "#fff0a0");
      d.rect(0.42, 0.5, 0.6, 0.6, "#c8902a", { line: 6 });
      for (const y of [0.8, 0.9]) d.rect(0.3, y, 0.7, y + 0.025, "#c8902a", { line: 5 });
    } },
    prop_elites: { base: "#7a3e22", areas: false, draw: (d) => {
      d.fill([[0.06, 0.36], [0.1, 0.12], [0.3, 0.0], [0.24, 0.16], [0.36, 0.3]], "#c07a3e");
      d.fill([[0.72, 0.36], [0.92, 0.3], [0.86, 0.46], [0.74, 0.46]], "#c07a3e");
      d.fill([[0.26, 0.28], [0.55, 0.22], [0.8, 0.32], [0.78, 0.5], [0.66, 0.62], [0.42, 0.62], [0.3, 0.5]], BONE);
      d.circle(0.44, 0.4, 0.075, INK); d.circle(0.64, 0.42, 0.07, INK);
      tri(d, [0.52, 0.48], [0.56, 0.54], [0.5, 0.55], INK);
      tri(d, [0.44, 0.6], [0.5, 0.6], [0.46, 0.72], BONE); tri(d, [0.6, 0.6], [0.66, 0.6], [0.64, 0.7], BONE);
      d.rect(0.18, 0.83, 0.38, 0.88, "#c08a5a");
    } },
    prop_rares: { base: GOLD, areas: false, draw: (d) => {
      for (const t of [0.32, 0.46, 0.6, 0.72]) { const cx = 0.85 - 0.8 * t, cy = 0.1 + 0.88 * t;
        d.line([[cx - 0.07, cy - 0.065], [cx + 0.07, cy + 0.065]], 22, "#a8761a"); }
      d.fill([[0.0, 0.9], [0.12, 0.8], [0.24, 0.9], [0.1, 1.02]], "#5a3418");
      d.circle(0.81, 0.13, 0.15, "#2a5ac8");
      d.circle(0.76, 0.09, 0.045, "#cfe4ff", { line: 0 });
    } },
    acc_oar: { base: "#e0a050", areas: false, draw: (d) => {
      d.fill([[0.42, 0.0], [0.9, 0.0], [1.0, 0.08], [0.72, 0.52], [0.5, 0.58], [0.4, 0.3]], "#f4ecd8");
      for (const y of [0.04, 0.2, 0.36]) d.line([[0.35, y + 0.14], [1.0, y - 0.06]], 34, "#1e3a6a");
      d.rect(0.26, 0.64, 0.4, 0.69, "#8a5a2e");
    } },
  };
};
