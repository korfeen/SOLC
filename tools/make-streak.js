// The hand-drawn underline under a picked word (the Collection's tabs, the Dream Bed's storybook chapters): an ink
// streak, thin at both ends, a little wobbly and uneven, in white (the game tints it). Media/Icons/Streak1..5.blp (256 x 32): five, picked at random.
//   node tools/make-streak.js
const fs = require("fs");
const os = require("os");
const path = require("path");
const crayon = require("./make-role-icons");
const { writeBlp } = require("./convert-art");

const W = 256, H = 32;
crayon.setSize(W);
const { canvas, dab, rng, writePng, toRgba } = crayon;
// Five of them, each its own flick (curve, thickness, where it is fullest, its tail), so a picked word gets one at random:
// Media/Icons/Streak1..5.blp.
const VARIANTS = 5;
const looks = [];
for (let v = 1; v <= VARIANTS; v++) {
  const c = canvas();
  const random = rng(4242 + v * 977);
  const white = [255, 255, 255];
  const bend = 1.6 + random() * 2.2, phase = random() * 3, slope = (random() - 0.5) * 4;
  const peak = 0.75 + random() * 0.6, thick = 4.4 + random() * 1.6, start = 6 + random() * 14, end = W - 6 - random() * 18;
  const steps = 420;
  for (let i = 0; i <= steps; i++) {
    const t = i / steps;
    const x = start + t * (end - start);
    const y = 16 + Math.sin(t * Math.PI * 1.3 + phase) * bend - t * slope;
    const body = Math.pow(Math.sin(Math.PI * Math.min(1, t * peak + (1 - peak) * t * t)), 0.55);
    const r = Math.max(0.6, thick * body * (0.86 + random() * 0.28));
    dab(c, x, y, r, white, 0.55);
  }
  const out = Buffer.from(toRgba(c).subarray(0, W * H * 4));  // (the canvas is square: its top 32 rows hold the streak)
  writeBlp(path.join(__dirname, "..", "Media", "Icons", "Streak" + v + ".blp"), W, H, out);
  looks.push(out);
}
// (to look at: all five, one under the other)
const sheet = Buffer.concat(looks);
const look = path.join(os.homedir(), "killtracker-art-extra", "RoleIcons", "streak.png");
fs.mkdirSync(path.dirname(look), { recursive: true });
writePng(look, W, H * VARIANTS, sheet);
console.log("Wrote Media/Icons/Streak1.." + VARIANTS + ".blp; look: " + look);
