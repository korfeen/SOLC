// Whole crayon drawings (own: true) for the Bounty Hunter set (tools/gen-art-bounty.json, the "Bounties claimed" deeds):
// the battered hat with a wanted poster in its band, the tin Sheriff's Star, the duster with its bandolier of rolled-up
// wanted posters. Shapes in each piece's box (0..1).
module.exports = ({ INK }) => {
  const LEATHER = "#a8682e", DARK = "#6a3e20", TIN = "#d8d8e0", PAPER = "#f4e4b8";
  return {
    // A wide floppy brim, a dented crown, a band with a buckle and a little WANTED poster tucked in.
    hunt_sheriff_head: { own: true, draw: (d) => {
      d.fill([[0.0, 0.7], [0.12, 0.56], [0.88, 0.5], [1.0, 0.62], [0.9, 0.86], [0.1, 0.9]], LEATHER, { hatch: 12, line: 10 });
      d.fill([[0.24, 0.62], [0.28, 0.16], [0.5, 0.06], [0.74, 0.14], [0.76, 0.6]], LEATHER, { hatch: 12, line: 10 });
      d.line([[0.26, 0.5], [0.76, 0.48]], 12, DARK);
      d.rect(0.42, 0.44, 0.52, 0.54, "#c8a050", { line: 5 });
      d.fill([[0.58, 0.28], [0.74, 0.24], [0.76, 0.46], [0.6, 0.5]], PAPER, { hatch: 6, line: 6 });
      d.line([[0.61, 0.32], [0.72, 0.3]], 4, INK);
    } },
    // A big six-pointed tin star with a ball on each tip.
    hunt_sheriff_star: { own: true, draw: (d) => {
      const pts = [];
      for (let i = 0; i < 12; i++) {
        const a = -Math.PI / 2 + (i * Math.PI) / 6, rad = i % 2 ? 0.2 : 0.42;
        pts.push([0.5 + Math.cos(a) * rad, 0.5 + Math.sin(a) * rad]);
      }
      d.fill(pts, TIN, { hatch: 10, line: 10 });
      for (let i = 0; i < 12; i += 2) d.circle(pts[i][0], pts[i][1], 0.045, TIN);
      d.circle(0.5, 0.5, 0.1, "#ffffff", { line: 6 });
      d.line([[0.36, 0.36], [0.44, 0.3]], 5, "#ffffff");
    } },
    // A long brown duster over a grubby shirt, a bandolier of rolled-up posters across it, a tin star on the chest.
    hunt_sheriff_body: { own: true, draw: (d) => {
      d.fill([[0.06, 0.08], [0.36, 0.0], [0.64, 0.0], [0.94, 0.08], [1.0, 1.0], [0.0, 1.0]], LEATHER, { hatch: 14, line: 12 });
      d.fill([[0.38, 0.02], [0.62, 0.02], [0.6, 1.0], [0.4, 1.0]], "#e8d8b0", { hatch: 10, line: 8 });
      d.line([[0.18, 0.2], [0.8, 0.82]], 26, DARK);
      for (let k = 0; k < 5; k++) { const t = 0.12 + k * 0.17; d.rect(0.2 + t * 0.6 - 0.03, 0.18 + t * 0.6 - 0.09, 0.2 + t * 0.6 + 0.03, 0.18 + t * 0.6 - 0.01, PAPER, { line: 5 }); }
      d.circle(0.76, 0.26, 0.06, TIN);
      for (const y of [0.4, 0.6, 0.8]) d.circle(0.5, y, 0.018, DARK, { line: 0 });
    } },
  };
};
