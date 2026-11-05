// The hand-drawn underline under a picked word (the Collection's tabs, the Dream Bed's storybook chapters): an ink
// streak, thin at both ends, a little wobbly and uneven, in white (the game tints it). Media/Icons/Streak.blp (256 x 32).
//   node tools/make-streak.js
const fs = require("fs");
const os = require("os");
const path = require("path");
const crayon = require("./make-role-icons");
const { writeBlp } = require("./convert-art");

const W = 256, H = 32;
crayon.setSize(W);
const { canvas, dab, rng, writePng, toRgba } = crayon;
const c = canvas();
const random = rng(4242);
const white = [255, 255, 255];
// A flick from left to right: a gentle curve, thickest a third of the way along, tapering to points at both ends.
const steps = 420;
for (let i = 0; i <= steps; i++) {
  const t = i / steps;
  const x = 10 + t * (W - 20);
  const y = 16 + Math.sin(t * Math.PI * 1.3 + 0.4) * 2.2 - t * 1.5;
  const body = Math.pow(Math.sin(Math.PI * Math.min(1, t * 1.15)), 0.55);  // (fuller early, thinner at its tail)
  const r = Math.max(0.6, 5.2 * body * (0.88 + random() * 0.24));
  dab(c, x, y, r, white, 0.55);
}
const rgba = toRgba(c);
// (the canvas is square: its top 32 rows hold the streak)
const out = Buffer.from(rgba.subarray(0, W * H * 4));
writeBlp(path.join(__dirname, "..", "Media", "Icons", "Streak.blp"), W, H, out);
const look = path.join(os.homedir(), "killtracker-art-extra", "RoleIcons", "streak.png");
fs.mkdirSync(path.dirname(look), { recursive: true });
writePng(look, W, H, out);
console.log("Wrote Media/Icons/Streak.blp; look: " + look);
