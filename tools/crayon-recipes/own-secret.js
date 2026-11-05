// Whole crayon drawings (own: true) for the secret deeds' pieces (tools/gen-art-secret.json): the Barrel, the Bent Halo,
// the Do Not Disturb sign, the Murloc Maraca, the Neck Pillow, the Sleeping Bag and the White Flag. Shapes in each
// piece's box (0..1).
module.exports = ({ INK, BONE, GOLD, googly, teeth, tri }) => {
  const oval = (cx, cy, rx, ry, n = 24) => Array.from({ length: n }, (_, i) => { const t = (i / n) * 2 * Math.PI; return [cx + Math.cos(t) * rx, cy + Math.sin(t) * ry]; });
  const WOOD = "#a8682e", DARK = "#5a3a1e";
  return {
    // Nothing on but a barrel on braces.
    prop_barrel_body: { own: true, draw: (d) => {
      for (const x of [0.24, 0.76]) d.fill([[x - 0.05, 0.0], [x + 0.05, 0.0], [x + 0.06, 0.46], [x - 0.04, 0.46]], "#7a4a26", { hatch: 8, line: 8 });
      d.fill([[0.02, 0.44], [0.98, 0.44], [1.0, 0.72], [0.97, 1.0], [0.03, 1.0], [0.0, 0.72]], WOOD, { hatch: 14, line: 12 });
      for (const y of [0.52, 0.9]) d.line([[0.01, y], [0.99, y]], 12, "#4a4a52");
      for (const x of [0.2, 0.4, 0.6, 0.8]) d.line([[x, 0.46], [x + (x - 0.5) * 0.06, 0.99]], 4, DARK);
      for (const x of [0.24, 0.76]) d.circle(x, 0.47, 0.025, GOLD);
    } },
    // A wonky gold halo, bent as if sat on, and a few sparkles.
    prop_bent_halo: { own: true, draw: (d) => {
      const ring = Array.from({ length: 26 }, (_, i) => { const t = (i / 26) * 2 * Math.PI; return [0.5 + Math.cos(t) * 0.4, 0.5 + Math.sin(t) * (0.3 + 0.1 * Math.cos(t)) - Math.max(0, Math.cos(t)) * 0.12]; });
      d.line([...ring, ring[0]], 18, "#ffc83a");
      d.line(ring.slice(14, 24), 6, "#fff6c0");
      for (const [x, y] of [[0.06, 0.16], [0.94, 0.12], [0.14, 0.92], [0.9, 0.88]]) d.circle(x, y, 0.03, "#fff6a0", { line: 0 });
    } },
    // A hotel door-hanger: its hook, its cream card, a sleepy moon in a nightcap and Zzz.
    prop_dnd_sign: { own: true, draw: (d) => {
      // (one card: an arched tab on top with the hole for the handle)
      const arch = Array.from({ length: 13 }, (_, i) => { const t = Math.PI - (i / 12) * Math.PI; return [0.5 + Math.cos(t) * 0.24, 0.32 - Math.sin(t) * 0.3]; });
      d.fill([[0.12, 1.0], [0.12, 0.34], [0.26, 0.34], ...arch, [0.74, 0.34], [0.88, 0.34], [0.88, 1.0]], "#f4e4b8", { hatch: 10, line: 10 });
      d.circle(0.5, 0.17, 0.09, "#b8986a");
      d.line([[0.15, 0.4], [0.85, 0.4]], 5, GOLD); d.line([[0.15, 0.96], [0.85, 0.96]], 5, GOLD);
      d.circle(0.44, 0.66, 0.2, "#ffd23f");
      d.circle(0.56, 0.58, 0.17, "#f4e4b8", { line: 0 });  // (the crescent: the card over the moon)
      d.fill([[0.3, 0.54], [0.5, 0.44], [0.66, 0.4], [0.48, 0.56]], "#4f86e8", { hatch: 6, line: 6 });  // (its nightcap)
      d.circle(0.67, 0.4, 0.035, "#ffffff");
      d.line([[0.64, 0.66], [0.76, 0.66], [0.64, 0.78], [0.76, 0.78]], 5, "#4f86e8");
      d.line([[0.72, 0.84], [0.8, 0.84], [0.72, 0.92], [0.8, 0.92]], 4, "#4f86e8");
    } },
    // A party maraca with a grinning murloc for its head, a fin crest, on a striped stick.
    prop_murloc_maraca: { own: true, draw: (d) => {
      d.fill([[0.46, 0.52], [0.6, 0.52], [0.82, 1.0], [0.66, 1.0]], "#e8702a", { hatch: 8, line: 9 });
      for (const t of [0.62, 0.76, 0.9]) d.line([[0.5 + (t - 0.52) * 0.66, t], [0.62 + (t - 0.52) * 0.66, t]], 6, "#3ab0a0");
      for (const [x, c] of [[0.2, "#e8402a"], [0.34, "#ffd23f"], [0.5, "#e8402a"], [0.66, "#ffd23f"]]) tri(d, [x - 0.08, 0.2], [x, 0.0], [x + 0.08, 0.2], c);
      d.fill(oval(0.44, 0.34, 0.3, 0.24), "#3ab08a", { hatch: 10, line: 10 });
      googly(d, [[0.3, 0.26], [0.52, 0.24]], 0.07);
      d.fill([[0.26, 0.42], [0.62, 0.4], [0.5, 0.52], [0.32, 0.5]], "#7a1a1a", { hatch: 6, line: 7 });
      teeth(d, 0.28, 0.6, 0.42, 6, 0.05, BONE);
    } },
    // A plump U-shaped travel pillow in sky blue, little gryphons on it.
    prop_neck_pillow: { own: true, draw: (d) => {
      // (a horseshoe opening downwards, as painted: the outer edge over the top from left to right, the inner back)
      const outer = Array.from({ length: 20 }, (_, i) => { const t = Math.PI + (i / 19) * Math.PI; return [0.5 + Math.cos(t) * 0.48, 0.7 + Math.sin(t) * 0.66]; });
      const inner = Array.from({ length: 20 }, (_, i) => { const t = 2 * Math.PI - (i / 19) * Math.PI; return [0.5 + Math.cos(t) * 0.2, 0.7 + Math.sin(t) * 0.3]; });
      d.fill([...outer, [0.98, 0.86], [0.84, 0.98], [0.7, 0.86], ...inner, [0.3, 0.86], [0.16, 0.98], [0.02, 0.86]], "#8ab8f0", { hatch: 12, line: 10 });
      for (const [x, y] of [[0.12, 0.62], [0.3, 0.24], [0.7, 0.24], [0.88, 0.62]]) { d.circle(x, y, 0.045, "#ffffff"); d.line([[x - 0.06, y - 0.02], [x - 0.02, y - 0.06]], 4, "#ffffff"); }
    } },
    // A puffy sleeping bag zipped up to the chin: green, orange sides, quilted, a zip up the middle.
    prop_sleeping_bag_body: { own: true, draw: (d) => {
      d.fill([[0.12, 0.02], [0.4, 0.06], [0.6, 0.06], [0.88, 0.02], [0.98, 0.3], [0.98, 1.0], [0.02, 1.0], [0.02, 0.3]], "#5a8a2a", { hatch: 14, line: 12 });
      for (const x of [0.02, 0.86]) d.fill([[x, 0.3], [x + 0.12, 0.28], [x + 0.12, 1.0], [x, 1.0]], "#ff8a2a", { hatch: 8, line: 8 });
      for (const y of [0.26, 0.44, 0.62, 0.8]) d.line([[0.14, y], [0.86, y]], 5, "#3a6a1a");
      d.line([[0.5, 0.06], [0.5, 1.0]], 7, "#ff8a2a");
      d.circle(0.5, 0.12, 0.03, "#c8c8d0");
    } },
    // A grubby little flag of truce on a thin stick, drooping.
    prop_white_flag: { own: true, draw: (d) => {
      d.line([[0.84, 0.0], [0.74, 1.0]], 9, WOOD);
      d.circle(0.84, 0.02, 0.03, "#c8a060");
      d.fill([[0.83, 0.06], [0.42, 0.1], [0.18, 0.2], [0.3, 0.3], [0.5, 0.38], [0.8, 0.34]], "#f4ecd8", { hatch: 10, line: 9 });
      d.line([[0.5, 0.16], [0.58, 0.26]], 4, "#b8a888");
    } },
  };
};
