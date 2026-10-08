// Where the designer's exports sit in the window, and how they're cut up. Shared by tools/convert-overview.js
// (cuts the textures) and tools/overview-layout.js (places them). Exports in %USERPROFILE%\killtracker-art-extra\
// Overview.

// The frame (FRAME.png): the whole window frame drawn about 4.29 times its size in the game; matched on its corner
// squares and the Close button: export pixel = (window pixel - left or top) * scale.
const FRAME_ART = { left: -0.26, top: -106.87, scaleX: 4.298, scaleY: 4.285 };

// The parts it's cut into, in window pixels (y down): the posts below the header, and the bottom with the corner
// squares (the parts overlap by a pixel, so no seam shows). width x height: the texture's size.
const FRAME_PARTS = [
  { texture: "FrameLeft", x0: 168, x1: 228, y0: 40, y1: 566, width: 128, height: 1024 },
  { texture: "FrameRight", x0: 900, x1: 964, y0: 40, y1: 566, width: 128, height: 1024 },
  { texture: "FrameBottom", x0: 168, x1: 964, y0: 565, y1: 623, width: 2048, height: 128 },
];

// The new Overview's design exports, a quarter of the frame export's size (the same canvas: 1036 x 804 for
// 4143 x 3216): the whole window with the frame, without the content (v2/BG_OVERVIEW_WITHOUT_CONTENT2.png) and
// with it (v2/BG_OVERVIEW_WITH_CONTENT2.png). Their pixels ("quarter pixels") to window pixels:
const QUARTER = { scaleX: 4143 / 1036 / FRAME_ART.scaleX, scaleY: 3216 / 804 / FRAME_ART.scaleY };
const quarterX = (x) => FRAME_ART.left + x * QUARTER.scaleX;
const quarterY = (y) => FRAME_ART.top + y * QUARTER.scaleY;

// The Overview's inside, built from the background without the frame (v2/BG_WITHOUT_BORDERS.png, which sits at
// this spot in the quarter canvas), the spine from the export with the frame (its upper half is on the frame's
// layer there), and the content that doesn't change (KEEP: the stat plaques, the character card with its name bar,
// the list's heading) from the export with content; where the two exports differ is the content.
const INSIDE = {
  at: [196, 156],                    // the background's top-left in the quarter canvas; it's 813 x 601
  // The spine: an upright bar in the export with the frame (the background has only its lower half), taken from
  // there all the way down: quarter x from, to.
  spine: [581, 620],
  // The content that doesn't change, by kind (quarter pixels: x0, y0, x1, y1): the name bar (all but the light board
  // round it), the big polaroid (its grey frame, the photo with its black border, the nail: not the shadow and board
  // round it), the list's heading (where it differs from the export without content).
  keep: [
    // the name bar: its three pieces whole (the arrow planks, the grey label between them)
    { box: [668, 182, 966, 229], take: "rects", rects: [[668.5, 183, 723.5, 228.5], [722.5, 186.5, 910.5, 226], [909.5, 182.5, 965, 228.5]] },
    { box: [648, 232, 985, 656], take: "polaroid", photo: [681, 256, 957, 573], nail: [823, 242, 8] },
    { box: [220, 526, 462, 563], take: "differs" },
  ],
  // The dark boards behind the activity list slant a little each; the game can't slant text, so they're made level:
  // each column of them (x0 to x1, the background's own pixels) slid up or down so the seams between the boards,
  // measured at the columns at, lie level at their average height. Above the first seam nothing moves.
  straighten: { x0: 0, x1: 387, at: [20, 380], seams: [[362, 360], [414, 407], [472, 462], [527, 516], [583, 575]] },
  // The pages' background: one flat, slightly warm dark surface (wood grain behind things tires the eyes), only the
  // frame and the spine's wood cutting through it; in the background's own pixels. Kept as painted: the list's
  // heading board (heading: x0, y0, x1, y1); the spine comes from the export with the frame (spine, above). A shadow
  // falls spineShadow pixels out from the spine and shadow pixels down from the heading board (y0 in feedPanel: its
  // bottom edge).
  feedPanel: { x0: 0, x1: 387, y0: 411, colour: [36, 31, 27], shadow: 7, seamTop: 395, seamRight: 430 },
  heading: [0, 355, 387, 411],
  spineShadow: 10,
  // The spine beside the list, cut out onto its own texture (SpineCut) and drawn over the list's rows, so their
  // stripes and highlight run on under it (as under the frame's post on the other side).
  spineCut: { x0: 386, x1: 428, y0: 405, y1: 601 },
  // The stat plaques without their sample numbers: the designer's separate plaques (v2/<name>.png), laid over the
  // ones in the design at these spots (quarter pixels, their top-left; matched on the icons).
  plaques: [["POINTS", 220, 154], ["ACHIEVMENT", 337, 154], ["KILLS", 458, 159]],
  // The sample name and signature, wiped off (the game writes the real ones there). fill: "column"
  // takes the board's own wood above and below the letters (rows: from, to), "row" the wood left and right of them on
  // the same row (rows: from x, to x; the label's grain runs along it), "flat" the polaroid's plain grey (sampled at
  // sample), "mirror" the whole box (y0 to y1) refilled with the clean rows above and below it, mirrored back and
  // forth (clean: the label's first and last rows; its grain runs along the rows).
  wipe: [
    { x0: 726, y0: 193, x1: 907, y1: 219, clean: [190, 222], fill: "mirror" },
    { x0: 690, y0: 575, x1: 975, y1: 642, dark: 175, fill: "flat", sample: [670, 600] },
  ],
};

// The grey squares on the spine's ends, cut out of the export with the frame and drawn on their own over the
// frame's bottom and the header (quarter pixels: their corners, clockwise from the top left).
const CAPS = [
  { texture: "CapTop", corners: [[567.5, 96.25], [652.5, 110], [640, 178.75], [560, 163.75]] },
  { texture: "CapBottom", corners: [[575, 721.25], [643.75, 728.75], [638.75, 781.25], [571.25, 775]] },
];
// A cap's area: its corners pushed out by a few pixels (the outline's soft edge), and the box round them.
function capArea(cap, margin = 2) {
  const cx = cap.corners.reduce((s, c) => s + c[0], 0) / 4, cy = cap.corners.reduce((s, c) => s + c[1], 0) / 4;
  const poly = cap.corners.map(([x, y]) => {
    const d = Math.hypot(x - cx, y - cy);
    return [x + ((x - cx) / d) * margin, y + ((y - cy) / d) * margin];
  });
  const x0 = Math.floor(Math.min(...poly.map((p) => p[0]))), x1 = Math.ceil(Math.max(...poly.map((p) => p[0])));
  const y0 = Math.floor(Math.min(...poly.map((p) => p[1]))), y1 = Math.ceil(Math.max(...poly.map((p) => p[1])));
  return { poly, x0, y0, x1, y1 };
}

module.exports = { FRAME_ART, FRAME_PARTS, QUARTER, quarterX, quarterY, INSIDE, CAPS, capArea };
