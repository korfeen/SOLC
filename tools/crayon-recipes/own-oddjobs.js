// Whole crayon drawings (own: true) for the odd-job bounty posters' props (tools/gen-art-bounty.json): the Stolen Crown,
// the Dungeon Torch, the Dented Shield, the Explorer's Map, the Fishing Rod and the Gathering Sack. Shapes in each
// piece's box (0..1).
module.exports = ({ INK, BONE, GOLD, tri }) => {
  const WOOD = "#a8682e", DARK = "#5a3a1e";
  return {
    // A big gold crown, gems on its points, held up in a fist.
    prop_leaders: { own: true, draw: (d) => {
      d.fill([[0.06, 0.78], [0.06, 0.3], [0.26, 0.52], [0.5, 0.16], [0.74, 0.52], [0.94, 0.3], [0.94, 0.78]], GOLD, { hatch: 12, line: 10 });
      d.rect(0.04, 0.72, 0.96, 0.9, "#c8902a", { line: 8 });
      for (const [x, y, c] of [[0.06, 0.26, "#e8402a"], [0.5, 0.12, "#4f86e8"], [0.94, 0.26, "#3ab08a"]]) d.circle(x, y, 0.05, c);
      for (const [x, c] of [[0.24, "#e8402a"], [0.5, "#4f86e8"], [0.76, "#3ab08a"]]) d.circle(x, 0.81, 0.045, c);
    } },
    // A wooden torch with a big flame.
    prop_dungeons: { own: true, draw: (d) => {
      d.line([[0.5, 0.42], [0.46, 1.0]], 16, WOOD);
      d.rect(0.38, 0.38, 0.62, 0.48, DARK, { line: 6 });
      d.fill([[0.3, 0.38], [0.24, 0.2], [0.36, 0.24], [0.42, 0.0], [0.56, 0.16], [0.68, 0.06], [0.72, 0.26], [0.7, 0.38]], "#ff8a2a", { hatch: 10, line: 9 });
      d.fill([[0.4, 0.38], [0.42, 0.22], [0.5, 0.28], [0.58, 0.2], [0.6, 0.38]], "#ffd23f", { hatch: 6, line: 6 });
    } },
    // A round wooden shield, iron rim, dents and a crack.
    prop_pvp: { own: true, draw: (d) => {
      d.circle(0.5, 0.5, 0.46, "#4a4a52");
      d.circle(0.5, 0.5, 0.38, WOOD);
      for (const x of [0.3, 0.5, 0.7]) d.line([[x, 0.15], [x, 0.85]], 4, DARK);
      d.circle(0.5, 0.5, 0.1, "#8a8a92");
      d.line([[0.62, 0.2], [0.68, 0.34], [0.62, 0.42]], 5, INK);
      d.circle(0.3, 0.68, 0.04, "#6a6a72", { line: 0 });
    } },
    // A rolled-out old map: a red X, a dotted trail, a compass rose.
    prop_explorers: { own: true, draw: (d) => {
      d.fill([[0.06, 0.12], [0.94, 0.06], [0.96, 0.9], [0.04, 0.94]], "#f4e4b8", { hatch: 10, line: 9 });
      for (const y of [0.08, 0.92]) d.line([[0.02, y], [0.98, y - 0.04]], 14, "#d8c08a");
      for (const [x, y] of [[0.2, 0.7], [0.3, 0.6], [0.42, 0.62], [0.52, 0.5], [0.6, 0.4]]) d.circle(x, y, 0.018, "#5a3a1e", { line: 0 });
      d.line([[0.62, 0.28], [0.76, 0.42]], 7, "#d8302e"); d.line([[0.76, 0.28], [0.62, 0.42]], 7, "#d8302e");
      d.line([[0.22, 0.18], [0.22, 0.4]], 4, "#4f86e8"); d.line([[0.11, 0.29], [0.33, 0.29]], 4, "#4f86e8");
      tri(d, [0.19, 0.22], [0.22, 0.14], [0.25, 0.22], "#d8302e");
    } },
    // A bent fishing rod: line, red and white bobber, a little silver fish on the hook.
    prop_fish: { own: true, draw: (d) => {
      d.line([[0.12, 1.0], [0.3, 0.5], [0.56, 0.16], [0.92, 0.04]], 9, WOOD);
      d.circle(0.22, 0.76, 0.05, "#c8c8d0");
      d.line([[0.92, 0.04], [0.86, 0.44], [0.84, 0.66]], 3, "#e8e8e8");
      d.circle(0.86, 0.44, 0.05, "#e8402a"); d.circle(0.86, 0.47, 0.03, "#ffffff", { line: 0 });
      d.fill([[0.72, 0.74], [0.84, 0.68], [0.94, 0.74], [0.84, 0.82]], "#b8c8d8", { hatch: 6, line: 6 });
      tri(d, [0.72, 0.74], [0.64, 0.68], [0.64, 0.8], "#b8c8d8");
      d.circle(0.89, 0.73, 0.015, INK, { line: 0 });
    } },
    // A stuffed burlap sack: herbs and flowers, a lump of copper ore and a rolled hide poking out the top.
    prop_gather: { own: true, draw: (d) => {
      d.fill([[0.2, 0.4], [0.8, 0.4], [0.94, 0.72], [0.82, 0.98], [0.18, 0.98], [0.06, 0.72]], "#c8a060", { hatch: 12, line: 10 });
      d.line([[0.22, 0.46], [0.78, 0.46]], 7, DARK);
      d.fill([[0.58, 0.42], [0.62, 0.22], [0.78, 0.18], [0.84, 0.34], [0.74, 0.42]], "#c87a3a", { hatch: 6, line: 7 });
      d.circle(0.7, 0.28, 0.03, "#3ab08a", { line: 0 });
      d.fill([[0.2, 0.42], [0.14, 0.14], [0.3, 0.1], [0.36, 0.42]], "#a8682e", { hatch: 6, line: 7 });
      for (const [x, y, c] of [[0.4, 0.2, "#ffffff"], [0.5, 0.08, "#ffd23f"], [0.46, 0.3, "#e8b8f0"]]) {
        d.line([[x, y + 0.04], [x, 0.42]], 4, "#3a8a2a");
        d.circle(x, y, 0.05, c);
      }
      d.fill([[0.52, 0.4], [0.56, 0.16], [0.6, 0.4]], "#5a9a2a", { hatch: 4, line: 4 });
    } },
  };
};
