// One-off (2026-11-05): crayon icons for the seven picture layers (tools/make-role-icons.js, drawn by code), written into
// Media/Icons as Layer_<key>, for wherever a layer is picked (the Dream Bed's storybook, the Collection's tabs).
const fs = require("fs");
const path = require("path");
process.chdir(path.join(__dirname, ".."));
const file = "tools/make-role-icons.js";
let s = fs.readFileSync(file, "utf8");
const nl = s.includes("\r\n") ? "\r\n" : "\n";
const N = (t) => t.replace(/\n/g, nl);
function rep(a, b) { a = N(a); b = N(b); if (s.split(a).length !== 2) throw Error("not found: " + a.slice(0, 60)); s = s.replace(a, () => b); }

rep(`      stroke(c, [[x0, y0], [x1, y1]], 6, OUTLINE, 0.9, random);
    }
  },
};`,
`      stroke(c, [[x0, y0], [x1, y1]], 6, OUTLINE, 0.9, random);
    }
  },

  // --- The picture layers (Media/Icons/Layer_<key>: the storybook's chapters, the Collection's tabs) ---

  // Hats: a floppy striped nightcap with a pom-pom.
  layerHeadwear(c, random) {
    const cap = [...quad([40, 190], [70, 60], [190, 70], 24), ...quad([190, 70], [228, 120], [214, 176], 12).slice(1),
      ...quad([214, 176], [180, 150], [176, 190], 8).slice(1)];
    crayonShape(c, cap, C.blue, random, { line: 14 });
    for (const t of [0.3, 0.55]) {
      const a = [40 + (70 - 40) * t * 2, 190 - 130 * t], b = [176 - 20 * t, 190 - 120 * t];
      stroke(c, [a, b], 16, C.white, 0.9, random);
    }
    crayonShape(c, [[30, 176], [184, 176], [186, 214], [28, 214]], C.white, random, { line: 12, hatch: 7 });
    crayonShape(c, circle(214, 186, 26), C.white, random, { line: 12, hatch: 6 });
  },
  // Clothes: a pajama top with buttons.
  layerOutfit(c, random) {
    const top = [[92, 36], [128, 54], [164, 36], [228, 74], [206, 126], [184, 114], [186, 228], [70, 228], [72, 114], [50, 126], [28, 74]];
    crayonShape(c, top, hex("#7aa7e8"), random, { line: 14 });
    for (const x of [100, 156]) stroke(c, [[x, 60], [x, 224]], 10, C.white, 0.85, random);
    stroke(c, [[128, 56], [128, 226]], 6, OUTLINE, 0.9, random);
    for (const y of [96, 140, 184]) crayonShape(c, circle(140, y, 9), C.white, random, { line: 6, hatch: 4, fit: true });
  },
  // Accessories (anything at all): a gift bow.
  layerAccessory(c, random) {
    crayonShape(c, [...quad([128, 128], [40, 40], [44, 120], 12), ...quad([44, 120], [60, 176], [128, 128], 12).slice(1)], C.red, random, { line: 14 });
    crayonShape(c, [...quad([128, 128], [216, 40], [212, 120], 12), ...quad([212, 120], [196, 176], [128, 128], 12).slice(1)], C.red, random, { line: 14 });
    crayonShape(c, [[118, 130], [92, 226], [116, 214], [128, 236], [134, 132]], hex("#d8322a"), random, { line: 12, hatch: 6 });
    crayonShape(c, [[138, 130], [164, 226], [142, 214], [130, 236], [124, 132]], hex("#d8322a"), random, { line: 12, hatch: 6 });
    crayonShape(c, circle(128, 128, 24), hex("#ff6a5a"), random, { line: 12, hatch: 6 });
  },
  // Places: a little picture of a hill under a sky with the sun.
  layerBackground(c, random) {
    crayonShape(c, [[24, 40], [232, 40], [232, 216], [24, 216]], hex("#9fd2ff"), random, { line: 14 });
    crayonShape(c, [[30, 216], ...quad([30, 170], [110, 96], [226, 168], 24), [226, 216]], C.green, random, { outline: null, hatch: 8, fit: true });
    stroke(c, quad([30, 170], [110, 96], [226, 168], 24), 9, OUTLINE, 0.9, random);
    crayonShape(c, circle(176, 82, 24), C.gold, random, { line: 9, hatch: 6 });
    stroke(c, [[24, 40], [232, 40], [232, 216], [24, 216], [24, 40]], 16, hex("#8a5a2e"), 0.95, random);
  },
  // Ogres (skins): a round green ogre head with tusks.
  layerSkin(c, random) {
    crayonShape(c, ellipse(42, 120, 22, 30), hex("#7fb04a"), random, { line: 12, hatch: 6, fit: true });
    crayonShape(c, ellipse(214, 120, 22, 30), hex("#7fb04a"), random, { line: 12, hatch: 6, fit: true });
    crayonShape(c, ellipse(128, 132, 92, 96), hex("#8cc152"), random, { line: 14 });
    for (const x of [96, 160]) crayonShape(c, ellipse(x, 112, 12, 8), OUTLINE, random, { outline: null, hatch: 4, fit: true });
    crayonShape(c, ellipse(128, 150, 22, 16), hex("#6f9e3e"), random, { line: 8, hatch: 5, fit: true });
    stroke(c, quad([82, 186], [128, 214], [174, 186], 12), 8, OUTLINE, 0.9, random);
    crayonShape(c, [[92, 192], [100, 160], [108, 196]], C.white, random, { line: 7, hatch: 4, fit: true });
    crayonShape(c, [[148, 196], [156, 160], [164, 192]], C.white, random, { line: 7, hatch: 4, fit: true });
  },
  // Eyes: two sleepy eyes, heavy lids.
  layerEyes(c, random) {
    for (const x of [76, 180]) {
      crayonShape(c, ellipse(x, 132, 50, 40), C.white, random, { line: 12, hatch: 7, fit: true });
      crayonShape(c, circle(x + 6, 140, 16), hex("#3a2a1a"), random, { outline: null, hatch: 5, fit: true });
      crayonShape(c, [...quad([x - 52, 128], [x, 72], [x + 52, 128], 16), [x + 52, 112], [x - 52, 112]], hex("#8cc152"), random, { line: 10, hatch: 6, fit: true });
    }
  },
  // Mouths: a wide toothy grin with two tusks.
  layerExpression(c, random) {
    const mouth = [...quad([30, 104], [128, 132], [226, 104], 24), ...quad([226, 104], [128, 260], [30, 104], 24).slice(1)];
    crayonShape(c, mouth, hex("#7a2a2a"), random, { line: 14 });
    crayonShape(c, ellipse(128, 176, 50, 22), hex("#e86a6a"), random, { outline: null, hatch: 6, fit: true });
    crayonShape(c, [[64, 116], [80, 46], [98, 122]], C.white, random, { line: 10, hatch: 5, fit: true });
    crayonShape(c, [[158, 122], [176, 46], [192, 116]], C.white, random, { line: 10, hatch: 5, fit: true });
  },
};`);
rep(`"fxCardBack", "fxOgre", "token", "fxCloud"];`,
 `"fxCardBack", "fxOgre", "token", "fxCloud",
  "layerHeadwear", "layerOutfit", "layerAccessory", "layerBackground", "layerSkin", "layerEyes", "layerExpression"];`);
rep(`fxCardBack: "Fx_CardBack", fxOgre: "Fx_Ogre", token: "Token", fxCloud: "Fx_Cloud" };`,
 `fxCardBack: "Fx_CardBack", fxOgre: "Fx_Ogre", token: "Token", fxCloud: "Fx_Cloud",
  layerHeadwear: "Layer_headwear", layerOutfit: "Layer_outfit", layerAccessory: "Layer_accessory", layerBackground: "Layer_background",
  layerSkin: "Layer_skin", layerEyes: "Layer_eyes", layerExpression: "Layer_expression" };`);
fs.writeFileSync(file, s);
console.log("done");
