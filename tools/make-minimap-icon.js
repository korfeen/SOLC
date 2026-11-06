// The minimap button's icon: the sleeping ogre's head (horn, drool and Zzz) cropped from the club logo, on the logo's
// blue, in a circle (the button's border goes round it). Media\Icons\Minimap.blp, plus a preview png in output\.
//   node tools/make-minimap-icon.js
const fs = require("fs");
const os = require("os");
const path = require("path");
const { decodePng, resample, writeBlp } = require("./convert-art");

const LOGO = path.join(os.homedir(), "killtracker-art-extra", "sleepy-ogre-logo.png");
const CROP = { x: 515, y: 105, size: 480 };  // (the head, its horn and the Zzz, in the 1254 px logo)
const SIZE = 64;
const logo = decodePng(LOGO);
const img = resample(logo, CROP.x, CROP.y, CROP.size, CROP.size, SIZE, SIZE);
// (the logo's blue behind it: the logo file's own background is see-through)
const BLUE = [24, 66, 168];
for (let i = 0; i < img.length; i += 4) {
  const a = img[i + 3] / 255;
  for (let c = 0; c < 3; c++) img[i + c] = Math.round(img[i + c] * a + BLUE[c] * (1 - a));
  img[i + 3] = 255;
}
// (a round icon: outside the circle see-through, its edge softened over a pixel)
for (let y = 0; y < SIZE; y++) for (let x = 0; x < SIZE; x++) {
  const d = Math.hypot(x + 0.5 - SIZE / 2, y + 0.5 - SIZE / 2), r = SIZE / 2 - 0.5;
  const a = Math.max(0, Math.min(1, r - d + 0.5));
  img[(y * SIZE + x) * 4 + 3] = Math.round(img[(y * SIZE + x) * 4 + 3] * a);
}
writeBlp(path.join(__dirname, "..", "Media", "Icons", "Minimap.blp"), SIZE, SIZE, img);
// (a preview, 4x, to look at)
const { png } = require("./render-picture.js");
const big = resample({ width: SIZE, height: SIZE, rgba: img }, 0, 0, SIZE, SIZE, SIZE * 4, SIZE * 4);
fs.writeFileSync(path.join(__dirname, "..", "output", "minimap-icon-preview.png"), png({ width: SIZE * 4, height: SIZE * 4, rgba: big }));
console.log("Media/Icons/Minimap.blp");
