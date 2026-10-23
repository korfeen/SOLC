// The Dream Bed's light textures (DreamBed.lua): glow.blp, a soft round glow fading smoothly to nothing (the candle's
// light, the flame, halos, the steam: drawn ADD, so its colour fades with its alpha), and disc.blp, a round disc with a
// soft edge (the moon and the sun), and wipe.blp, a mask solid at the top fading out at the bottom (the painting's new
// layer shown down to the brush's tip, a soft edge there). White: the scene tints them.
// Usage: node tools/make-dreambed-fx.js
const path = require("path");
const { writeBlp } = require("./convert-art");

const OUT = path.join(__dirname, "..", "Media", "DreamBed");
const SIZE = 128;

// white: true keeps the colour white all the way out (only the alpha fades) - for shapes drawn normally (the disc:
// overlapping discs then show no grey rings); otherwise premultiplied, for ADD.
function Make(file, alphaAt, w = SIZE, h = SIZE, at = null, white = false) {
  const px = Buffer.alloc(w * h * 4);
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const d = at ? at(x, y) : Math.hypot(x + 0.5 - SIZE / 2, y + 0.5 - SIZE / 2) / (SIZE / 2);  // 0 in the middle, 1 at the edge
    const a = Math.round(255 * Math.max(0, Math.min(1, alphaAt(d))));
    const i = (y * w + x) * 4;
    px[i] = px[i + 1] = px[i + 2] = white ? 255 : a;  // (premultiplied: ADD fades out with it)
    px[i + 3] = a;
  }
  writeBlp(path.join(OUT, file), w, h, px);
}
// (a smooth falloff, exactly 0 well before the square's edge: no hard rim)
Make("glow.blp", (d) => d >= 1 ? 0 : Math.pow(Math.cos(d * Math.PI / 2), 2.2));
// (solid to 85%, then a soft edge)
Make("disc.blp", (d) => d <= 0.85 ? 1 : d >= 1 ? 0 : 1 - (d - 0.85) / 0.15, SIZE, SIZE, null, true);
// (solid down to 80%, then fading out: d is how far down)
Make("wipe.blp", (d) => d <= 0.8 ? 1 : 1 - (d - 0.8) / 0.2, 64, 256, (x, y) => (y + 0.5) / 256);
console.log("Media/DreamBed: glow.blp, disc.blp, wipe.blp");
