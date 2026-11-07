// Whole crayon drawings (own: true) for the fishing chests' angler set (tools/gen-art-bounty.json, unlock
// "chest:fishing"): the Angler's Hat, the Fishing Waders, the Landing Net. Shapes in each piece's box (0..1).
module.exports = ({ INK }) => {
  const OLIVE = "#6f7a3a", WADER = "#3f6a3a", WOOL = "#efe4c8", WOOD = "#a8682e";
  return {
    // An olive bucket hat, its band full of colourful lures.
    hunt_angler_head: { own: true, draw: (d) => {
      d.fill([[0.02, 0.74], [0.14, 0.58], [0.86, 0.58], [0.98, 0.74], [0.86, 0.92], [0.14, 0.92]], OLIVE, { hatch: 10, line: 10 });
      d.fill([[0.2, 0.62], [0.26, 0.12], [0.5, 0.04], [0.74, 0.12], [0.8, 0.62]], OLIVE, { hatch: 12, line: 10 });
      d.line([[0.22, 0.52], [0.78, 0.52]], 10, "#4a5228");
      for (const [x, c] of [[0.3, "#e8402a"], [0.42, "#ffd23f"], [0.54, "#4f86e8"], [0.66, "#3ab08a"]]) {
        d.circle(x, 0.5, 0.035, c);
        d.line([[x, 0.53], [x + 0.02, 0.6]], 3, INK);
      }
    } },
    // Dark-green chest waders on straps over a cream cable-knit sweater.
    hunt_angler_body: { own: true, draw: (d) => {
      d.fill([[0.04, 0.12], [0.36, 0.02], [0.64, 0.02], [0.96, 0.12], [1.0, 0.62], [0.0, 0.62]], WOOL, { hatch: 12, line: 10 });
      for (const x of [0.3, 0.42, 0.58, 0.7]) d.line([[x, 0.06], [x, 0.4]], 4, "#d8c8a0");
      d.fill([[0.2, 0.36], [0.8, 0.36], [0.86, 1.0], [0.14, 1.0]], WADER, { hatch: 12, line: 12 });
      for (const x of [0.28, 0.72]) d.line([[x, 0.04], [x, 0.38]], 9, "#2f5a2a");
      for (const x of [0.28, 0.72]) d.rect(x - 0.03, 0.34, x + 0.03, 0.4, "#c8a050", { line: 4 });
      d.rect(0.38, 0.5, 0.62, 0.66, "#355e30", { line: 6 });
    } },
    // A wooden-handled landing net with a silver fish flopping in it.
    prop_landing_net: { own: true, draw: (d) => {
      d.line([[0.86, 1.0], [0.6, 0.48]], 10, WOOD);
      const rim = Array.from({ length: 24 }, (_, i) => { const t = (i / 24) * 2 * Math.PI; return [0.36 + Math.cos(t) * 0.3, 0.28 + Math.sin(t) * 0.24]; });
      d.line([...rim, rim[0]], 8, "#c87a3a");
      for (let k = -2; k <= 2; k++) { d.line([[0.36 + k * 0.1, 0.06], [0.36 + k * 0.1, 0.5]], 2, "#d8d0c0"); d.line([[0.08, 0.28 + k * 0.08], [0.64, 0.28 + k * 0.08]], 2, "#d8d0c0"); }
      d.fill([[0.18, 0.3], [0.36, 0.2], [0.54, 0.28], [0.36, 0.38]], "#b8c8d8", { hatch: 6, line: 6 });
      d.fill([[0.54, 0.28], [0.62, 0.2], [0.62, 0.36]], "#b8c8d8", { hatch: 4, line: 5 });
      d.circle(0.24, 0.28, 0.015, INK, { line: 0 });
    } },
  };
};
