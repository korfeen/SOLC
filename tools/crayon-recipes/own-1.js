// Whole crayon drawings (own: true; the user picked them over drawing on the traced outline, 2026-11-02): the pigeon,
// the sleeping rat, the howling wolf pup, the voodoo doll, the murloc on a stick, the honey-pot bear and the steward's
// vest and boater. Shapes in each piece's box (0..1). CRAYON_TRACED=1 draws them on the traced outline instead.
module.exports = ({ INK, BONE, GOLD, eyes, googly, teeth, tri }) => {
  const oval = (cx, cy, rx, ry, n = 22) => Array.from({ length: n }, (_, i) => { const t = (i / n) * 2 * Math.PI; return [cx + Math.cos(t) * rx, cy + Math.sin(t) * ry]; });
  const shut = (d, x, y, w = 0.05) => d.line([[x - w, y], [x, y + w * 0.5], [x + w, y]], 5, INK);  // (a closed eye)
  return {
    acc_pigeon: { own: true, draw: (d) => {
      d.line([[0.4, 0.82], [0.38, 0.98]], 7, "#e07a8a"); d.line([[0.56, 0.82], [0.58, 0.98]], 7, "#e07a8a");
      d.fill(oval(0.44, 0.58, 0.36, 0.3), "#9a94a4", { hatch: 12, line: 10 });
      d.fill(oval(0.38, 0.58, 0.24, 0.18), "#7a7488", { hatch: 10, line: 8 });
      for (const y of [0.54, 0.62]) d.line([[0.2, y], [0.5, y - 0.02]], 4, "#5a5468");
      d.fill(oval(0.62, 0.38, 0.12, 0.07), "#5aa878", { hatch: 8, line: 0 });
      d.fill(oval(0.66, 0.24, 0.16, 0.15), "#8a8494", { hatch: 10, line: 9 });
      tri(d, [0.8, 0.22], [0.94, 0.27], [0.8, 0.3], "#e8a040");
      eyes(d, [[0.7, 0.21]], 0.03);
    } },
    acc_rat: { own: true, draw: (d) => {
      d.line([[0.14, 0.72], [0.02, 0.82], [0.1, 0.96], [0.22, 0.9]], 8, "#f0a8b0");
      d.fill(oval(0.45, 0.6, 0.36, 0.28), "#9a7a6a", { hatch: 12, line: 10 });
      d.fill(oval(0.72, 0.5, 0.2, 0.18), "#9a7a6a", { hatch: 10, line: 9 });
      d.fill(oval(0.64, 0.3, 0.1, 0.1), "#f0a8b0", { hatch: 8, line: 8 });
      d.circle(0.92, 0.55, 0.035, "#f07a8a");
      shut(d, 0.76, 0.46, 0.04);
      for (const x of [0.5, 0.62]) d.fill(oval(x, 0.86, 0.06, 0.04), "#f0a8b0", { hatch: 6, line: 6 });
    } },
    crit_wolf_acc: { own: true, draw: (d) => {
      d.fill([[0.68, 0.8], [0.95, 0.66], [0.9, 0.86], [0.7, 0.92]], "#8a8a98", { hatch: 10, line: 9 });
      d.fill(oval(0.48, 0.7, 0.28, 0.27), "#9a9aa8", { hatch: 12, line: 10 });
      d.fill(oval(0.48, 0.74, 0.14, 0.2), "#f0ece8", { hatch: 10, line: 7 });
      tri(d, [0.32, 0.1], [0.28, 0.3], [0.42, 0.24], "#6a6a78"); tri(d, [0.64, 0.12], [0.56, 0.24], [0.7, 0.3], "#6a6a78");
      d.fill(oval(0.5, 0.34, 0.18, 0.16), "#9a9aa8", { hatch: 10, line: 9 });
      d.fill([[0.42, 0.28], [0.5, 0.02], [0.6, 0.06], [0.58, 0.28]], "#c8c8d0", { hatch: 8, line: 8 });
      d.circle(0.55, 0.04, 0.03, INK);
      shut(d, 0.42, 0.34, 0.035); shut(d, 0.6, 0.34, 0.035);
      for (const x of [0.36, 0.6]) d.fill(oval(x, 0.94, 0.08, 0.05), "#9a9aa8", { hatch: 6, line: 7 });
    } },
    crit_troll_acc: { own: true, draw: (d) => {
      d.fill(oval(0.5, 0.7, 0.28, 0.27), "#7a9a3a", { hatch: 12, line: 10 });
      for (const x of [0.2, 0.8]) d.fill(oval(x, 0.66, 0.08, 0.14), "#7a9a3a", { hatch: 8, line: 8 });
      for (const y of [0.62, 0.74]) d.line([[0.4, y], [0.6, y + 0.02]], 4, "#5a3a22");
      tri(d, [0.2, 0.3], [0.02, 0.22], [0.26, 0.4], "#7a9a3a"); tri(d, [0.8, 0.3], [0.98, 0.22], [0.74, 0.4], "#7a9a3a");
      d.fill(oval(0.5, 0.32, 0.27, 0.24), "#8aaa48", { hatch: 12, line: 10 });
      for (const [x, y] of [[0.4, 0.28], [0.6, 0.28]]) { d.line([[x - 0.05, y - 0.05], [x + 0.05, y + 0.05]], 8, INK); d.line([[x - 0.05, y + 0.05], [x + 0.05, y - 0.05]], 8, INK); }
      d.line([[0.38, 0.44], [0.62, 0.44]], 5, "#5a3a22"); teeth(d, 0.4, 0.6, 0.42, 2, -0.07);
      for (const [x, c] of [[0.38, "#2f6ad8"], [0.5, "#d8302a"], [0.62, "#f4c838"]]) { d.line([[x, 0.1], [x, 0.0]], 4, "#c8c8d0"); d.circle(x, 0.0, 0.03, c); }
    } },
    crit_murloc_acc: { own: true, draw: (d) => {
      d.line([[0.5, 0.36], [0.5, 0.99]], 12, "#8a5a2e");
      for (const k of [0, 1, 2, 3]) tri(d, [0.32 + k * 0.1, 0.12], [0.36 + k * 0.1, -0.02], [0.41 + k * 0.1, 0.12], "#f08a30");
      d.fill(oval(0.5, 0.24, 0.26, 0.15), "#3aa8a0", { hatch: 12, line: 10 });
      d.fill([[0.34, 0.3], [0.62, 0.3], [0.5, 0.4]], "#f07a6a", { hatch: 6, line: 7 });
      googly(d, [[0.58, 0.2]], 0.08);
      d.line([[0.42, 0.62], [0.58, 0.58]], 7, "#f0e6d0");
    } },
    // (an outfit and a hat drawn whole too, to compare: they must fit the ogre, which the traced outline guarantees)
    shop_steward_vest: { base: "#f2ead8", areas: false, draw: (d) => {  // (clothes keep the traced outline: it fits them to the ogre)
      d.fill([[0.0, 0.3], [0.2, 0.08], [0.38, 0.02], [0.62, 0.02], [0.8, 0.08], [1.0, 0.3], [1.0, 0.99], [0.0, 0.99]], "#f2ead8", { hatch: 14, line: 10 });
      d.fill([[0.22, 0.12], [0.44, 0.06], [0.5, 0.3], [0.56, 0.06], [0.78, 0.12], [0.82, 0.99], [0.18, 0.99]], "#f4f0e4", { hatch: 12, line: 9 });
      for (const x of [0.25, 0.37, 0.57, 0.69]) d.fill([[x, 0.14], [x + 0.06, 0.13], [x + 0.06 + (x - 0.47) * 0.06, 0.98], [x + (x - 0.47) * 0.06, 0.98]], "#2f62c8", { line: 0, hatch: 8 });
      d.line([[0.5, 0.3], [0.5, 0.99]], 6, "#2b1a10");
      d.fill([[0.5, 0.17], [0.37, 0.1], [0.37, 0.24]], "#1e2c5a"); d.fill([[0.5, 0.17], [0.63, 0.1], [0.63, 0.24]], "#1e2c5a"); d.circle(0.5, 0.17, 0.028, "#1e2c5a");
      for (const y of [0.42, 0.56, 0.7, 0.84]) d.circle(0.53, y, 0.02, GOLD);
    } },
    shop_steward_boater: { base: "#e8b45a", areas: false, draw: (d) => {  // (headwear keeps the traced outline, like clothes)
      d.fill(oval(0.5, 0.8, 0.49, 0.17), "#e8b45a", { hatch: 10, line: 10 });
      d.fill([[0.2, 0.06], [0.84, 0.06], [0.84, 0.74], [0.2, 0.74]], "#e8b45a", { hatch: 10, line: 10 });
      d.fill([[0.2, 0.26], [0.84, 0.26], [0.84, 0.62], [0.2, 0.62]], "#f6f2e8", { hatch: 8, line: 6 });
      for (const x of [0.24, 0.36, 0.48, 0.6, 0.72]) d.fill([[x, 0.26], [x + 0.07, 0.26], [x + 0.07, 0.62], [x, 0.62]], "#2f62c8", { hatch: 6, line: 0 });
    } },
    crit_bear_acc: { own: true, draw: (d) => {
      for (const x of [0.22, 0.78]) d.fill(oval(x, 0.14, 0.11, 0.1), "#a8582a", { hatch: 8, line: 9 });
      d.fill(oval(0.5, 0.58, 0.46, 0.4), "#d86a2a", { hatch: 12, line: 10 });
      d.fill([[0.08, 0.36], [0.92, 0.36], [0.9, 0.46], [0.74, 0.48], [0.7, 0.62], [0.64, 0.48], [0.38, 0.5], [0.33, 0.6], [0.28, 0.48], [0.1, 0.46]], "#f4b830", { hatch: 8, line: 7 });
      d.fill(oval(0.5, 0.25, 0.14, 0.09), "#f0c890", { hatch: 6, line: 6 });
      eyes(d, [[0.38, 0.2], [0.62, 0.2]], 0.035); d.circle(0.5, 0.23, 0.035, INK);
      for (const y of [0.72, 0.84]) d.line([[0.2, y], [0.8, y]], 4, "#a8582a");
    } },
  };
};
