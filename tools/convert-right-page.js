// Converts the art of the new Overview's right page to game textures.
// Source: %USERPROFILE%\killtracker-art-extra\NewDesign: the designer's exports
//   HANGING_PICTURE.png   the wooden frame the photo hangs in (its middle see-through, a plaque on the bottom plank),
//                         drawn 1:1 in the window
// Target: Media/Overview/HangingPicture (512x512, the frame in its top-left at 1:1), placed by the pages (RIGHT).
// Usage: node tools/convert-right-page.js   No dependencies.

const os = require("os");
const path = require("path");
const { decodePng, writeBlp, bleedEdges } = require("./convert-art");

const SOURCE = path.join(os.homedir(), "killtracker-art-extra", "NewDesign");
const TARGET = path.join(__dirname, "..", "Media", "Overview");

function save(name, texW, texH, w, h, rgba) {
  const out = Buffer.alloc(texW * texH * 4);
  for (let y = 0; y < h; y++) rgba.copy(out, y * texW * 4, y * w * 4, (y + 1) * w * 4);
  bleedEdges(out, texW, texH);
  writeBlp(path.join(TARGET, name + ".blp"), texW, texH, out);
  console.log(`${name}.blp: ${w}x${h} in ${texW}x${texH}`);
}

const frame = decodePng(path.join(SOURCE, "HANGING_PICTURE.png"));
save("HangingPicture", 512, 512, frame.width, frame.height, frame.rgba);
