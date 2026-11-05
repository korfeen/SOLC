// The shop's sign (2026-11-05: "PRO SHOP" -> "SHOP"): the sign cut out of the shop room's painting
// (tools/proshop-mock/img/scene3.png), repainted by Codex reading SHOP, and pasted back over the board only (soft edges;
// the lamps and wall round it untouched). Then: node tools/make-mannequin.js (the room's textures from the painting).
//   node tools/gen-shop-sign.js           paint it and paste it in
//   node tools/gen-shop-sign.js --paste   paste the repaint made already (sign/new.png) again
// The original painting is kept as scene3-pro-shop.png beside it.
const fs = require("fs");
const os = require("os");
const path = require("path");
const { generate } = require("./gen-art");
const { decodePng, resample } = require("./convert-art");
const { writePng } = require("./make-role-icons");

const SCENE = path.join(__dirname, "proshop-mock", "img", "scene3.png");
const ORIGINAL = path.join(__dirname, "proshop-mock", "img", "scene3-pro-shop.png");
const WORK = path.join(os.homedir(), "killtracker-art-extra", "ProShop", "sign");
const CROP = { x: 270, y: 0, w: 290, h: 90, scale: 4 };  // (the sign and a bit round it, painting pixels)
const BOARD = { x0: 308, x1: 518, y0: 3, y1: 76, feather: 4 };  // (what's pasted back: the sign itself)

fs.mkdirSync(WORK, { recursive: true });
if (!fs.existsSync(ORIGINAL)) fs.copyFileSync(SCENE, ORIGINAL);
const scene = decodePng(ORIGINAL);
const crop = path.join(WORK, "crop.png"), fresh = path.join(WORK, "new.png");

if (!process.argv.includes("--paste")) {
  const { x, y, w, h, scale } = CROP, out = Buffer.alloc(w * scale * h * scale * 4);
  for (let yy = 0; yy < h * scale; yy++) for (let xx = 0; xx < w * scale; xx++) {
    const i = ((y + Math.floor(yy / scale)) * scene.width + x + Math.floor(xx / scale)) * 4;
    scene.rgba.copy(out, (yy * w * scale + xx) * 4, i, i + 4);
  }
  writePng(crop, w * scale, h * scale, out);
  const work = path.join(WORK, "work");
  fs.mkdirSync(work, { recursive: true });
  const made = generate(work, [crop], `Repaint this exact picture (the reference image), keeping EVERYTHING the same - the
same wooden sign board, the same gold scrollwork frame, the same crossed golf clubs and golf ball on top, the same wall,
the same two lamps, the same colours, lighting, size and position - with ONE change: the sign's lettering now reads only
"SHOP" (one word, four letters, centred on the board, the same cream lettering style and size as before). Nothing else
changes. Same wide picture shape as the reference.`, "sign.png", "wide, the reference's shape");
  fs.copyFileSync(made, fresh);
}

// Pasted back: the repaint scaled to the crop, over the board with a soft edge.
const img = decodePng(fresh);
const small = { width: CROP.w, height: CROP.h, rgba: Buffer.from(resample(img, 0, 0, img.width, img.height, CROP.w, CROP.h)) };
const px = Buffer.from(scene.rgba);
for (let y = BOARD.y0; y < BOARD.y1; y++) for (let x = BOARD.x0; x < BOARD.x1; x++) {
  const edge = Math.min(x - BOARD.x0, BOARD.x1 - 1 - x, y - BOARD.y0, BOARD.y1 - 1 - y);
  const a = Math.max(0, Math.min(1, (edge + 1) / BOARD.feather));
  const i = (y * scene.width + x) * 4, j = ((y - CROP.y) * CROP.w + (x - CROP.x)) * 4;
  for (let c = 0; c < 3; c++) px[i + c] = Math.round(small.rgba[j + c] * a + px[i + c] * (1 - a));
}
writePng(SCENE, scene.width, scene.height, px);
// (to look at: the new sign 4x)
const look = Buffer.alloc(CROP.w * 4 * CROP.h * 4 * 4);
for (let y = 0; y < CROP.h * 4; y++) for (let x = 0; x < CROP.w * 4; x++) {
  const i = ((CROP.y + Math.floor(y / 4)) * scene.width + CROP.x + Math.floor(x / 4)) * 4;
  px.copy(look, (y * CROP.w * 4 + x) * 4, i, i + 4);
}
writePng(path.join(WORK, "result.png"), CROP.w * 4, CROP.h * 4, look);
console.log("Pasted into " + SCENE + "; look: " + path.join(WORK, "result.png") + ". Then: node tools/make-mannequin.js");
