// Reginald dressed for fishing (his face - club sage, snooty eyes and sneer - in a sou'wester and a tweed shooting
// jacket, the Fishing Rod in hand), head and shoulders, for SOLC Fishing's catch log: SOLC_Fishing\Media\Reginald.blp
// (128 px) and a preview in output\. When the angler set (fishing chests) is painted and fitted, he can wear that.
//   node tools/make-fishing-reginald.js
const fs = require("fs");
const path = require("path");
const { renderPicture, png } = require("./render-picture.js");
const { resample, writeBlp } = require("./convert-art");

const TRAITS = { skin: "club_sage", eyes: "snooty_eyes", expression: "snooty_sneer", headwear: "gacha_head_souwester",
  outfit: "shop_norfolk_jacket", accessory: "prop_fish" };
const CROP = { x: 0.22, y: 0.0, size: 0.66 };  // (head, shoulders and the rod's tip, fractions of the picture)
const FULL = 1024, SIZE = 128;
const pic = renderPicture({ traits: TRAITS }, { size: FULL });
const img = resample(pic, CROP.x * FULL, CROP.y * FULL, CROP.size * FULL, CROP.size * FULL, SIZE, SIZE);
const dir = path.join(__dirname, "..", "SOLC_Fishing", "Media");
fs.mkdirSync(dir, { recursive: true });
writeBlp(path.join(dir, "Reginald.blp"), SIZE, SIZE, img);
const big = resample({ width: SIZE, height: SIZE, rgba: img }, 0, 0, SIZE, SIZE, SIZE * 3, SIZE * 3);
fs.writeFileSync(path.join(__dirname, "..", "output", "fishing-reginald-preview.png"), png({ width: SIZE * 3, height: SIZE * 3, rgba: big }));
console.log("SOLC_Fishing/Media/Reginald.blp");
