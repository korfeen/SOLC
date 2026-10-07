// Converts the wooden header art (the planks along the top of the main window, see UI.lua "Header") to small
// game textures. Source: %USERPROFILE%\killtracker-art-extra\Wood\<TINT>_LONG_WOOD.png (4008x563 planks) and
// <TINT>_SQUARE_WOOD.png (1024x1024 boards on a transparent canvas). Only what the header uses is converted:
//   Media/Wood/Plank.blp    the middle of a plank cut down to two boards (top and bottom), 512x128; PlankLeft
//                           and PlankRight its ends with the nails, 64x128 each
//   Media/Wood/Rune.blp     the sidebar buttons' rune as a white shape (the Settings button wears it)
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

// The plank in three parts, like the sidebar buttons: the two ends with their nails, which UI.lua draws at their
// real shape, and the middle, which it stretches. Two boards, not five: a plank on screen is about 30 pixels
// thick, and all five squeezed into that look too busy; the top and bottom boards keep the real edges and nails.
const END = 160;  // source pixels of each end (the nails are within the first 100)
function plank(tint, name) {
  const image = clean(decodePng(path.join(SOURCE, `${tint}_LONG_WOOD.png`)));
  const board = Math.round(image.height * 0.22);
  // A part of the plank (source columns x0 to x1), its top and bottom boards stacked, at width x 128.
  const part = (x0, x1, width) => {
    const top = resample(image, x0, 0, x1 - x0, board, width, 64);
    const bottom = resample(image, x0, image.height - board, x1 - x0, board, width, 64);
    const texture = Buffer.concat([Buffer.from(top), Buffer.from(bottom)]);
    bleedEdges(texture, width, 128);
    return texture;
  };
  writeBlp(path.join(TARGET, name + "Left.blp"), 64, 128, part(0, END, 64));
  writeBlp(path.join(TARGET, name + ".blp"), 512, 128, part(END, image.width - END, 512));
  writeBlp(path.join(TARGET, name + "Right.blp"), 64, 128, part(image.width - END, image.width, 64));
  // The ends' shape for UI.lua: their width is the plank's thickness times this.
  console.log(`${name}: ends ${(END / (board * 2)).toFixed(3)} of the thickness wide, middle 512x128`);
}

// The blue rune from the sidebar buttons' art (the swirl-chevron-swirl column at their ends), as a white shape
// UI.lua colours: blue, or yellow while selected, as on the sidebar.
function rune() {
  const image = decodePng(path.join(os.homedir(), "killtracker-art-extra", "Button2", "normal.png"));
  const x0 = 14, y0 = 26, w = 22, h = 53;  // around the rune at the button's left end
  const shape = { width: w, height: h, rgba: Buffer.alloc(w * h * 4) };
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const p = ((y0 + y) * image.width + x0 + x) * 4, o = (y * w + x) * 4;
      const [r, g, b] = [image.rgba[p], image.rgba[p + 1], image.rgba[p + 2]];
      const blue = Math.max(0, Math.min(1, (b - Math.max(r, g) - 12) / 36));  // how rune-blue it is
      shape.rgba.set([255, 255, 255, Math.round(blue * 255)], o);
    }
  }
  const texture = Buffer.from(resample(shape, 0, 0, w, h, 32, 64));
  for (let p = 0; p < texture.length; p += 4) texture.set([255, 255, 255], p);  // all white; alpha is the shape
  writeBlp(path.join(TARGET, "Rune.blp"), 32, 64, texture);
  console.log(`Rune: 32x64 (${w}x${h} of the button art)`);
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
rune();
square("NORMAL", "Piece", true);
square("DARK", "Square");
