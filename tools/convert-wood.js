// Converts the wooden header art (the planks along the top of the main window, see UI.lua "Header") to small
// game textures. Source: %USERPROFILE%\killtracker-art-extra\Wood\<TINT>_LONG_WOOD.png (4008x563 planks) and
// <TINT>_SQUARE_WOOD.png (1024x1024 boards on a transparent canvas). Only what the header uses is converted:
//   Media/Wood/Plank.blp    a plank cut down to two boards (top and bottom), filling 512x128
//   Media/Wood/Piece.blp    the normal square turned on its side (boards lengthways), for the short tilted pieces
//   Media/Wood/Square.blp   the dark square, for the Settings and Close buttons
// The art fills each texture (no padding), so UI.lua can tilt them with SetRotation without texture coordinates;
// it stretches them to their size on screen anyway. Every plank on screen reuses the one plank texture.
// The sources' background removal left a light halo and stray specks around the wood; clean() takes them out.
// Usage: node tools/convert-wood.js   No dependencies.

const os = require("os");
const path = require("path");
const { decodePng, resample, writeBlp, bleedEdges } = require("./convert-art");

const SOURCE = path.join(os.homedir(), "killtracker-art-extra", "Wood");
const TARGET = path.join(__dirname, "..", "Media", "Wood");

// Removes the background removal's leftovers: partly see-through light pixels (the halo along the edges and
// specks floating around) become fully transparent. Then every transparent pixel takes its neighbours' wood
// colour, so the soft edge that's left blends into wood rather than white when the texture is shrunk.
function clean(image) {
  const { rgba } = image;
  for (let p = 0; p < rgba.length; p += 4) {
    const alpha = rgba[p + 3];
    if (alpha > 0 && alpha < 250 && Math.min(rgba[p], rgba[p + 1], rgba[p + 2]) > 110) rgba[p + 3] = 0;
  }
  for (let p = 0; p < rgba.length; p += 4) if (rgba[p + 3] < 8) rgba[p + 3] = 0;
  bleedEdges(rgba, image.width, image.height);
  return image;
}

function plank(tint, name) {
  const image = clean(decodePng(path.join(SOURCE, `${tint}_LONG_WOOD.png`)));
  // Two boards, not five: a plank on screen is about 30 pixels thick, and all five squeezed into that look too
  // busy. The top board and the bottom board, so the plank keeps its real edges and the nails at all four corners.
  const board = Math.round(image.height * 0.22);
  const top = resample(image, 0, 0, image.width, board, 512, 64);
  const bottom = resample(image, 0, image.height - board, image.width, board, 512, 64);
  const texture = Buffer.concat([Buffer.from(top), Buffer.from(bottom)]);
  bleedEdges(texture, 512, 128);
  writeBlp(path.join(TARGET, name + ".blp"), 512, 128, texture);
  console.log(`${name}: 512x128`);
}

// A square's boards, cropped from its transparent canvas, optionally turned a quarter (boards lengthways).
function square(tint, name, turn = false) {
  const image = clean(decodePng(path.join(SOURCE, `${tint}_SQUARE_WOOD.png`)));
  let x0 = image.width, y0 = image.height, x1 = 0, y1 = 0;
  for (let y = 0; y < image.height; y++) {
    for (let x = 0; x < image.width; x++) {
      if (image.rgba[(y * image.width + x) * 4 + 3] > 8) {
        x0 = Math.min(x0, x); y0 = Math.min(y0, y); x1 = Math.max(x1, x + 1); y1 = Math.max(y1, y + 1);
      }
    }
  }
  let texture = Buffer.from(resample(image, x0, y0, x1 - x0, y1 - y0, 128, 128));
  if (turn) {
    const turned = Buffer.alloc(texture.length);
    for (let y = 0; y < 128; y++) {
      for (let x = 0; x < 128; x++) texture.copy(turned, (x * 128 + (127 - y)) * 4, (y * 128 + x) * 4, (y * 128 + x) * 4 + 4);
    }
    texture = turned;
  }
  bleedEdges(texture, 128, 128);
  writeBlp(path.join(TARGET, name + ".blp"), 128, 128, texture);
  console.log(`${name}: the boards (${x1 - x0}x${y1 - y0} of the source)${turn ? ", turned" : ""}, filling 128x128`);
}

plank("NORMAL", "Plank");
square("NORMAL", "Piece", true);
square("DARK", "Square");
