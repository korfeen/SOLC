// Where the designer's frame export (%USERPROFILE%\killtracker-art-extra\Overview\FRAME.png) sits in the window,
// and the parts it's cut into. Shared by tools/convert-overview.js (cuts the textures) and
// tools/overview-layout.js (places them).
// The export is the whole window frame drawn about 4.29 times its size in the game; matched on its corner
// squares and the Close button: export pixel = (window pixel - left or top) * scale.
const FRAME_ART = { left: -0.26, top: -106.87, scaleX: 4.298, scaleY: 4.285 };

// The parts, in window pixels (y down): the posts below the header, and the bottom with the corner squares
// (the parts overlap by a pixel, so no seam shows). width x height: the texture's size.
const FRAME_PARTS = [
  { texture: "FrameLeft", x0: 168, x1: 228, y0: 40, y1: 566, width: 128, height: 1024 },
  { texture: "FrameRight", x0: 900, x1: 964, y0: 40, y1: 566, width: 128, height: 1024 },
  { texture: "FrameBottom", x0: 168, x1: 964, y0: 565, y1: 623, width: 2048, height: 128 },
];

module.exports = { FRAME_ART, FRAME_PARTS };

// The designer's export of everything inside the frame on the new Overview (INSIDE.png: the book of boards, the
// spine, the card with a sample character): about 1.08 times the window's size, matched on the spine's grey
// squares: window pixel = left or top + export pixel * scale.
const INSIDE_ART = { left: 183.7, top: -41.3, scale: 0.927 };
// The sample name and signature painted on it, wiped off (export pixels): the game writes the real ones there.
// fill: "column" takes the label's own wood above and below the letters, "flat" the polaroid's plain grey.
const INSIDE_WIPE = [
  { x0: 528, y0: 121, x1: 712, y1: 150, rows: [118, 152], bright: 140, fill: "column" },
  { x0: 495, y0: 503, x1: 770, y1: 576, dark: 175, fill: "flat", sample: [470, 540] },
];

module.exports.INSIDE_ART = INSIDE_ART;
module.exports.INSIDE_WIPE = INSIDE_WIPE;

// The grey squares on the spine's ends, cut out of the inside export and drawn on their own over the frame's bottom
// and the header (export pixels: their corners, clockwise from the top left).
const INSIDE_CAPS = [
  { texture: "CapTop", corners: [[371.7, 26.7], [456.7, 41.7], [448.3, 110], [363.3, 90]] },
  { texture: "CapBottom", corners: [[378.3, 651.7], [448.3, 658.3], [441.7, 711.7], [373.3, 705]] },
];
// A cap's area in the export: its corners pushed out by a few pixels (the outline's soft edge), and the box round
// them.
function capArea(cap, margin = 3) {
  const cx = cap.corners.reduce((s, c) => s + c[0], 0) / 4, cy = cap.corners.reduce((s, c) => s + c[1], 0) / 4;
  const poly = cap.corners.map(([x, y]) => {
    const d = Math.hypot(x - cx, y - cy);
    return [x + ((x - cx) / d) * margin, y + ((y - cy) / d) * margin];
  });
  const x0 = Math.floor(Math.min(...poly.map((p) => p[0]))), x1 = Math.ceil(Math.max(...poly.map((p) => p[0])));
  const y0 = Math.floor(Math.min(...poly.map((p) => p[1]))), y1 = Math.ceil(Math.max(...poly.map((p) => p[1])));
  return { poly, x0, y0, x1, y1 };
}

module.exports.INSIDE_CAPS = INSIDE_CAPS;
module.exports.capArea = capArea;

// The polaroid in the inside export (export pixels): its rows, where to look for its left edge, its bottom row and
// right edge. Its painted shadow (a hard band, band pixels wide, left of it and under it) is replaced with a soft one
// fading out over soft pixels, darkening by strength at the edge.
const INSIDE_POLAROID = { top: 165, bottom: 577, searchLeft: 430, right: 784, band: 5, soft: 9, strength: 0.42 };

module.exports.INSIDE_POLAROID = INSIDE_POLAROID;
