// Converts the art of the wooden window frame and the new Overview (the character card) to game textures.
// Source: %USERPROFILE%\killtracker-art-extra\Overview: the designer's exports of the frame (FRAME.png) and of the
// new Overview's inside (INSIDE.png), placed by tools/frame-art.js, and the grey square (GREY_SQUARE_WOOD.png).
// Target: Media/Overview:
//   FrameLeft, FrameRight, FrameBottom   the window frame, cut from FRAME.png
//   Inside               the designer's export of the new Overview's inside (INSIDE.png), sample text wiped
//   Cap                  the grey square of boards on the spine's ends (drawn again over the frame and header)
//   Arrow                a white arrow pointing right (the name bar's; mirrored for left)
//   Icons/<Kind>_<NAME>  the card's icons: the crayon icons (tools/make-role-icons.js) on the design's shapes,
//                        128x128: Class_DRUID, Race_NIGHTELF, Gender_MALE,
//                        Prof_ALCHEMY ... and the empty shapes Base_CLASS, Base_RACE, Base_GENDER,
//                        Base_PROFESSION, Base_SECONDARY
// Usage: node tools/convert-overview.js   No dependencies.

const fs = require("fs");
const os = require("os");
const path = require("path");
const { decodePng, resample, writeBlp, bleedEdges } = require("./convert-art");

const SOURCE = path.join(os.homedir(), "killtracker-art-extra", "Overview");
const TARGET = path.join(__dirname, "..", "Media", "Overview");
const source = (name) => decodePng(path.join(SOURCE, name + ".png"));

// Smooth (bilinear) resample for enlarging: the icons are painted small, and resample() (area average) would
// blow their pixels up into blocks. Colours weighted by alpha, as in resample().
function enlarge(image, sx, sy, sw, sh, outW, outH) {
  const { width, height, rgba } = image;
  const out = Buffer.alloc(outW * outH * 4);
  const at = (x, y, c) => rgba[(Math.min(height - 1, Math.max(0, y)) * width + Math.min(width - 1, Math.max(0, x))) * 4 + c];
  for (let y = 0; y < outH; y++) {
    for (let x = 0; x < outW; x++) {
      const u = sx + ((x + 0.5) * sw) / outW - 0.5, v = sy + ((y + 0.5) * sh) / outH - 0.5;
      const x0 = Math.floor(u), y0 = Math.floor(v), fx = u - x0, fy = v - y0;
      let r = 0, g = 0, b = 0, a = 0;
      for (const [dx, dy, w] of [[0, 0, (1 - fx) * (1 - fy)], [1, 0, fx * (1 - fy)], [0, 1, (1 - fx) * fy], [1, 1, fx * fy]]) {
        const pa = (at(x0 + dx, y0 + dy, 3) / 255) * w;
        r += at(x0 + dx, y0 + dy, 0) * pa; g += at(x0 + dx, y0 + dy, 1) * pa; b += at(x0 + dx, y0 + dy, 2) * pa; a += pa;
      }
      const o = (y * outW + x) * 4;
      out.set([a ? r / a : 0, a ? g / a : 0, a ? b / a : 0, Math.round(a * 255)], o);
    }
  }
  return out;
}

// The box around the visible pixels.
function bounds(image) {
  let x0 = image.width, y0 = image.height, x1 = 0, y1 = 0;
  for (let y = 0; y < image.height; y++) {
    for (let x = 0; x < image.width; x++) {
      if (image.rgba[(y * image.width + x) * 4 + 3] > 8) {
        x0 = Math.min(x0, x); y0 = Math.min(y0, y); x1 = Math.max(x1, x + 1); y1 = Math.max(y1, y + 1);
      }
    }
  }
  return { x: x0, y: y0, w: x1 - x0, h: y1 - y0 };
}

// The wood is drawn this much darker than painted (the frame, the spine's squares, the wood of the Overview's
// inside; UI.lua's header planks match it).
const WOOD_SHADE = 0.81;
// The Overview's light boards, calmer: less orange (their colour kept at this share) and darker; and a soft shadow
// over the inside, deepest (this much darker) in its corners, so the eye rests on the middle.
const LIGHT_BOARDS = { colour: 0.72, shade: 0.8 }, CORNER_SHADOW = 0.3;
// The polaroids' white, toned down a little (and the skull's, on the kills plaque).
const POLAROID_SHADE = 0.86;
// Darkens the wood in an image: every pixel, or (woodOnly) the brown ones, not the polaroids' grey, the icons'
// white and the gold of the coin, the medal and the lettering.
function darkenWood(rgba, woodOnly) {
  for (let o = 0; o < rgba.length; o += 4) {
    const [r, g, b] = [rgba[o], rgba[o + 1], rgba[o + 2]];
    if (woodOnly) {
      const light = Math.max(r, g, b) - Math.min(r, g, b) < 28 && r > 150;  // the polaroids, the skull
      const gold = r > 150 && g > 0.66 * r;
      if (light) {
        for (let c = 0; c < 3; c++) rgba[o + c] = Math.round(rgba[o + c] * POLAROID_SHADE);
        continue;
      }
      if (gold || !(r >= g && g >= b) && Math.max(r, g, b) - Math.min(r, g, b) > 28) continue;
    }
    for (let c = 0; c < 3; c++) rgba[o + c] = Math.round(rgba[o + c] * WOOD_SHADE);
  }
  return rgba;
}

function save(name, width, height, rgba) {
  bleedEdges(rgba, width, height);
  writeBlp(path.join(TARGET, name + ".blp"), width, height, rgba);
}

fs.rmSync(TARGET, { recursive: true, force: true });
fs.mkdirSync(path.join(TARGET, "Icons"), { recursive: true });

// The frame: the designer's export of the whole window frame (FRAME.png, the window drawn 4.29 times its size in
// the game), cut into the left post, the right post and the bottom (with the corner squares) as they are, crooked
// planks and all; tools/frame-art.js says where each part goes in the window.
const { FRAME_ART, FRAME_PARTS, INSIDE, CAPS, capArea } = require("./frame-art");
{
  const image = source("FRAME");
  for (const part of FRAME_PARTS) {
    const sx = (part.x0 - FRAME_ART.left) * FRAME_ART.scaleX, sy = (part.y0 - FRAME_ART.top) * FRAME_ART.scaleY;
    const sw = (part.x1 - part.x0) * FRAME_ART.scaleX, sh = (part.y1 - part.y0) * FRAME_ART.scaleY;
    save(part.texture, part.width, part.height, darkenWood(resample(image, sx, sy, sw, sh, part.width, part.height)));
  }
}
// The inside of the new Overview (tools/frame-art.js INSIDE): the background without the frame, the spine's
// upper half and the content that doesn't change laid on it from the design exports, the sample text wiped; at its
// own size in the top-left corner of a 1024x1024 texture (OverviewLayout.lua crops it).
{
  const v2 = (name) => decodePng(path.join(SOURCE, "v2", name + ".png"));
  const image = v2("BG_WITHOUT_BORDERS"), { width, height, rgba } = image;
  const bare = v2("BG_OVERVIEW_WITHOUT_CONTENT2"), full = v2("BG_OVERVIEW_WITH_CONTENT2"), W = bare.width;
  const [ax, ay] = INSIDE.at;
  // The activity list's dark boards made level (each column slid so the seams lie level, sampled smoothly).
  {
    const { x0, x1, at, seams } = INSIDE.straighten;
    const level = seams.map(([l, r]) => (l + r) / 2);
    const source = Buffer.from(rgba);
    for (let x = x0; x < x1; x++) {
      const t = (x - at[0]) / (at[1] - at[0]);
      const here = seams.map(([l, r]) => l + (r - l) * t);  // the seams' heights in this column
      for (let y = Math.floor(level[0]); y < height; y++) {
        // Where this row's pixel comes from: between the seams it falls between, in proportion; below the last
        // one, shifted as much as it is.
        let k = 0;
        while (k < level.length - 2 && y > level[k + 1]) k++;
        const sy = y > level[level.length - 1]
          ? y + here[here.length - 1] - level[level.length - 1]
          : here[k] + ((y - level[k]) / (level[k + 1] - level[k])) * (here[k + 1] - here[k]);
        const y0 = Math.max(0, Math.min(height - 1, Math.floor(sy))), y1 = Math.min(height - 1, y0 + 1), f = sy - Math.floor(sy);
        for (let c = 0; c < 4; c++) {
          rgba[(y * width + x) * 4 + c] = Math.round(source[(y0 * width + x) * 4 + c] * (1 - f) + source[(y1 * width + x) * 4 + c] * f);
        }
      }
    }
  }
  const differ = (p, q, o, limit) => Math.abs(p.rgba[o] - q.rgba[o]) + Math.abs(p.rgba[o + 1] - q.rgba[o + 1])
    + Math.abs(p.rgba[o + 2] - q.rgba[o + 2]) + Math.abs(p.rgba[o + 3] - q.rgba[o + 3]) > limit;
  // Copies a pixel of the quarter canvas onto the background, over what's there (alpha "over").
  // (From another image: lay(image, its x, its y, quarter x, quarter y).)
  const lay = (from, fx, fy, qx = fx, qy = fy) => {
    const x = qx - ax, y = qy - ay;
    if (x < 0 || y < 0 || x >= width || y >= height) return;
    const s0 = (fy * (from.width || W) + fx) * 4, o = (y * width + x) * 4, fa = from.rgba[s0 + 3] / 255, ua = rgba[o + 3] / 255;
    const out = fa + ua * (1 - fa);
    if (!out) return;
    for (let c = 0; c < 3; c++) rgba[o + c] = Math.round((from.rgba[s0 + c] * fa + rgba[o + c] * ua * (1 - fa)) / out);
    rgba[o + 3] = Math.round(out * 255);
  };
  // The pages' background (INSIDE.feedPanel and on): one flat, slightly warm dark surface with a faint even grain (a
  // little noise, so it isn't plastic); kept as painted: the list's heading board.
  const original = Buffer.from(rgba);
  const spine = new Uint8Array(width * height);  // the spine's pixels, for the shadow it casts
  {
    const { colour, shadow, y0: headingBottom } = INSIDE.feedPanel, [hx0, hy0, hx1, hy1] = INSIDE.heading;
    let n = 7;
    const noise = () => { n = (n * 16807) % 2147483647; return (n / 2147483647 - 0.5) * 3; };
    for (let y = 0; y < height; y++) {
      for (let x = 0; x < width; x++) {
        const o = (y * width + x) * 4;
        if (x >= hx0 && x < hx1 && y >= hy0 && y < hy1 && original[o + 3] === 255) continue;
        const dark = x < hx1 && y >= headingBottom && y - headingBottom < shadow ? 0.6 + 0.4 * ((y - headingBottom) / shadow) : 1;
        const grain = noise();
        for (let c = 0; c < 3; c++) rgba[o + c] = Math.round((colour[c] + grain) * dark);
        rgba[o + 3] = 255;
      }
    }
  }
  // The spine: its upright bar from the export with the frame, top to bottom.
  for (let y = 0; y < height; y++) {
    for (let qx = INSIDE.spine[0]; qx < INSIDE.spine[1]; qx++) {
      lay(bare, qx, y + ay);
      spine[y * width + qx - ax] = 1;
    }
  }
  // The spine's shadow on the surface either side of it, fading out.
  {
    const reach = INSIDE.spineShadow, before = Buffer.from(rgba);
    for (let y = 0; y < height; y++) {
      for (let x = 0; x < width; x++) {
        if (spine[y * width + x]) continue;
        let d = reach + 1;
        for (let k = 1; k <= reach && d > reach; k++) {
          if ((x - k >= 0 && spine[y * width + x - k]) || (x + k < width && spine[y * width + x + k])) d = k;
        }
        if (d > reach) continue;
        const dark = 1 - 0.4 * (1 - (d - 1) / reach) ** 2, o = (y * width + x) * 4;
        for (let c = 0; c < 3; c++) rgba[o + c] = Math.round(before[o + c] * dark);
      }
    }
  }
  // The content that doesn't change, from the export with content, by kind (INSIDE.keep).
  const lightBoard = (o) => {  // the pages' light wood (orange-brown and bright), and its shadowed bits
    const [r, g, b] = [full.rgba[o], full.rgba[o + 1], full.rgba[o + 2]];
    return r > g && g > b && r - b > 45 && 0.3 * r + 0.59 * g + 0.11 * b > 70;
  };
  const polaroidGrey = (o) => {
    const [r, g, b] = [full.rgba[o], full.rgba[o + 1], full.rgba[o + 2]];
    return Math.max(r, g, b) - Math.min(r, g, b) < 30 && r > 140;
  };
  const polaroid = new Uint8Array(width * height);  // the big polaroid's pixels, for its shadow
  for (const keep of INSIDE.keep) {
    const [x0, y0, x1, y1] = keep.box, bw = x1 - x0, bh = y1 - y0;
    // The polaroid: the photo and the grey joined to it (so not the nails and light edges of the boards behind it,
    // which are grey too), and the nail.
    let joined;
    if (keep.take === "polaroid") {
      const [px0, py0, px1, py1] = keep.photo;
      const candidate = (qx, qy) => (qx >= px0 && qx < px1 && qy >= py0 && qy < py1) || polaroidGrey((qy * W + qx) * 4);
      joined = new Uint8Array(bw * bh);
      const stack = [[Math.round((px0 + px1) / 2), Math.round((py0 + py1) / 2)]];
      joined[(stack[0][1] - y0) * bw + stack[0][0] - x0] = 1;
      while (stack.length) {
        const [cx, cy] = stack.pop();
        for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
          const nx = cx + dx, ny = cy + dy;
          if (nx < x0 || ny < y0 || nx >= x1 || ny >= y1 || joined[(ny - y0) * bw + nx - x0] || !candidate(nx, ny)) continue;
          joined[(ny - y0) * bw + nx - x0] = 1;
          stack.push([nx, ny]);
        }
      }
      // Thin light lines touching it (the board seams behind it) trimmed off: only what's thick enough, grown back.
      const r = 2, at = (x, y, m) => x >= 0 && y >= 0 && x < bw && y < bh && m[y * bw + x] === 1;
      const core = new Uint8Array(bw * bh);
      for (let y = 0; y < bh; y++) {
        for (let x = 0; x < bw; x++) {
          let all = joined[y * bw + x] === 1;
          for (let dy = -r; dy <= r && all; dy++) for (let dx = -r; dx <= r && all; dx++) all = at(x + dx, y + dy, joined);
          core[y * bw + x] = all ? 1 : 0;
        }
      }
      const opened = new Uint8Array(bw * bh);
      for (let y = 0; y < bh; y++) {
        for (let x = 0; x < bw; x++) {
          if (!joined[y * bw + x]) continue;
          let near = false;
          for (let dy = -r; dy <= r && !near; dy++) for (let dx = -r; dx <= r && !near; dx++) near = at(x + dx, y + dy, core);
          opened[y * bw + x] = near ? 1 : 0;
        }
      }
      joined = opened;
    }
    for (let qy = y0; qy < y1; qy++) {
      for (let qx = x0; qx < x1; qx++) {
        const o = (qy * W + qx) * 4;
        let take;
        if (keep.take === "differs") take = differ(full, bare, o, 12);
        else if (keep.take === "rects") take = keep.rects.some(([rx0, ry0, rx1, ry1]) => qx >= rx0 && qx < rx1 && qy >= ry0 && qy < ry1);
        else {
          const [nx, ny, nr] = keep.nail;
          take = joined[(qy - y0) * bw + qx - x0] === 1 || Math.hypot(qx - nx, qy - ny) <= nr;
        }
        if (!take) continue;
        lay(full, qx, qy);
        if (keep.take === "polaroid" && qx - ax >= 0 && qx - ax < width && qy - ay >= 0 && qy - ay < height) polaroid[(qy - ay) * width + qx - ax] = 1;
      }
    }
  }
  // The big polaroid's shadow on the surface: soft, falling down and to the left (as the light comes in the design).
  {
    const reach = 8, [offX, offY] = [-2, 3], before = Buffer.from(rgba);
    for (let y = 0; y < height; y++) {
      for (let x = 0; x < width; x++) {
        if (polaroid[y * width + x]) continue;
        let d = reach + 1;
        for (let dy = -reach; dy <= reach; dy++) {
          for (let dx = -reach; dx <= reach; dx++) {
            const sx = x - offX + dx, sy = y - offY + dy;
            if (sx < 0 || sy < 0 || sx >= width || sy >= height || !polaroid[sy * width + sx]) continue;
            d = Math.min(d, Math.hypot(dx, dy));
          }
        }
        if (d > reach) continue;
        const dark = 1 - 0.5 * (1 - d / reach) ** 2, o = (y * width + x) * 4;
        for (let c = 0; c < 3; c++) rgba[o + c] = Math.round(before[o + c] * dark);
      }
    }
  }
  // The stat plaques, clean (no numbers), over the ones from the design.
  for (const [name, px, py] of INSIDE.plaques) {
    const part = v2(name);
    for (let y = 0; y < part.height; y++) {
      for (let x = 0; x < part.width; x++) {
        const o = (y * part.width + x) * 4;
        if (part.rgba[o + 3]) lay({ rgba: part.rgba, width: part.width }, x, y, px + x, py + y);
      }
    }
  }
  // The sample text, wiped (in quarter pixels, so moved onto the background).
  const lum = (o) => 0.3 * rgba[o] + 0.59 * rgba[o + 1] + 0.11 * rgba[o + 2];
  for (const wipe of INSIDE.wipe) {
    if (wipe.fill === "mirror") {
      const [top, bottom] = wipe.clean, mid = (wipe.y0 + wipe.y1) / 2;
      for (let qy = wipe.y0; qy < wipe.y1; qy++) {
        // The upper half from the clean rows above (top to y0 - 1), the lower from those below (y1 to bottom), each
        // read back and forth.
        const [from, to] = qy < mid ? [wipe.y0 - 1, top] : [wipe.y1, bottom];
        const span = Math.abs(to - from) + 1, k = Math.abs(qy < mid ? wipe.y0 - 1 - qy : qy - wipe.y1);
        const step = k % (2 * span), offset = step < span ? step : 2 * span - 1 - step;
        const sy = from + Math.sign(to - from) * offset;
        for (let qx = wipe.x0; qx < wipe.x1; qx++) {
          const o = ((qy - ay) * width + qx - ax) * 4, so = ((sy - ay) * width + qx - ax) * 4;
          rgba.copy(rgba, o, so, so + 4);
        }
      }
      continue;
    }
    const marked = new Set(), at = (qx, qy) => (qy - ay) * width + qx - ax;
    for (let qy = wipe.y0; qy < wipe.y1; qy++) {
      for (let qx = wipe.x0; qx < wipe.x1; qx++) {
        const v = lum(at(qx, qy) * 4);
        if (wipe.bright ? v > wipe.bright : v < wipe.dark) {
          for (let dy = -2; dy <= 2; dy++) for (let dx = -2; dx <= 2; dx++) marked.add(at(qx + dx, qy + dy));
        }
      }
    }
    const flatAt = wipe.sample && at(wipe.sample[0], wipe.sample[1]) * 4;
    const flat = wipe.sample && Buffer.from(rgba.subarray(flatAt, flatAt + 3));
    for (const i of marked) {
      if (wipe.fill === "flat") { rgba.set(flat, i * 4); continue; }
      if (wipe.fill === "row") {
        // A pixel of the same row's wood outside the letters, picked evenly along it (keeps the grain's variety).
        const y = Math.floor(i / width), choices = [];
        for (let qx = wipe.rows[0]; qx <= wipe.rows[1]; qx++) if (!marked.has(at(qx, y + ay))) choices.push(at(qx, y + ay));
        if (choices.length) {
          const pick = choices[(i * 7919) % choices.length];
          rgba.copy(rgba, i * 4, pick * 4, pick * 4 + 3);
        }
        continue;
      }
      // The middle value of the column's unmarked wood between the board's top and bottom rows.
      const x = i % width, column = [];
      for (let qy = wipe.rows[0]; qy <= wipe.rows[1]; qy++) if (!marked.has(at(x + ax, qy))) column.push(at(x + ax, qy));
      if (!column.length) continue;
      column.sort((p, q) => lum(p * 4) - lum(q * 4));
      rgba.copy(rgba, i * 4, column[column.length >> 1] * 4, column[column.length >> 1] * 4 + 3);
    }
  }
  darkenWood(rgba, true);
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const o = (y * width + x) * 4, [r, g, b] = [rgba[o], rgba[o + 1], rgba[o + 2]];
      // How much it's one of the light boards: orange-brown (red over green over blue, well apart), bright enough;
      // fading in, so the darker grain in them goes along.
      const light = r > g && g > b && r - b > 40 && g < 0.66 * r + 30 ? Math.max(0, Math.min(1, (r - 85) / 35)) : 0;
      const dx = (x / width - 0.5) * 2, dy = (y / height - 0.5) * 2;
      const shadow = 1 - CORNER_SHADOW * Math.min(1, (dx * dx + dy * dy) * 0.6);
      const grey = (r + g + b) / 3;
      for (let c = 0; c < 3; c++) {
        const calm = (grey + (rgba[o + c] - grey) * LIGHT_BOARDS.colour) * LIGHT_BOARDS.shade;
        rgba[o + c] = Math.round((rgba[o + c] * (1 - light) + calm * light) * shadow);
      }
    }
  }
  const canvas = Buffer.alloc(1024 * 1024 * 4);
  for (let y = 0; y < height; y++) rgba.copy(canvas, y * 1024 * 4, y * width * 4, (y + 1) * width * 4);
  save("Inside", 1024, 1024, canvas);
  // The spine beside the list, also on its own texture (from the top left of a 64x256 one), drawn over the list.
  {
    const { x0, x1, y0, y1 } = INSIDE.spineCut, cut = Buffer.alloc(64 * 256 * 4);
    for (let y = y0; y < y1; y++) rgba.copy(cut, (y - y0) * 64 * 4, (y * width + x0) * 4, (y * width + x1) * 4);
    save("SpineCut", 64, 256, cut);
  }

  // The spine's grey squares, cut out of the export with the frame onto their own textures (128x128, from the top
  // left), drawn where they were over the frame and the header.
  for (const cap of CAPS) {
    const { poly, x0, y0, x1, y1 } = capArea(cap);
    const own = Buffer.alloc(128 * 128 * 4);
    for (let y = y0; y < y1; y++) {
      for (let x = x0; x < x1; x++) {
        let inside = false;
        for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) {
          const [xi, yi] = poly[i], [xj, yj] = poly[j];
          if (yi > y + 0.5 !== yj > y + 0.5 && x + 0.5 < ((xj - xi) * (y + 0.5 - yi)) / (yj - yi) + xi) inside = !inside;
        }
        if (inside) bare.rgba.copy(own, ((y - y0) * 128 + x - x0) * 4, (y * W + x) * 4, (y * W + x) * 4 + 4);
      }
    }
    save(cap.texture, 128, 128, darkenWood(own));
  }

  // The small polaroid (the showcase pictures' frame, its photo area black) and the nail that pins it up.
  const small = v2("POLAROIDBASE_2"), smallArt = enlarge(small, 0, 0, small.width, small.height, 256, 256);
  for (let o = 0; o < smallArt.length; o += 4) for (let c = 0; c < 3; c++) smallArt[o + c] = Math.round(smallArt[o + c] * POLAROID_SHADE);
  save("PolaroidSmall", 256, 256, smallArt);
  const nail = v2("NAIL");
  save("Nail", 16, 16, enlarge(nail, 0, 0, nail.width, nail.height, 16, 16));
}
// The wooden button (the GEARZ button), one texture per state, as the designer drew them but: the light halo the
// background removal left round the edges taken off, and the blue runes at the ends coloured by state as on the
// sidebar's buttons (blue at rest, light blue hovered, red pressed, yellow selected).
const RUNES = { NORMAL: null, HOVER: [100, 185, 245], PRESSED: [205, 45, 40], SELECTED: [235, 200, 40] };
for (const [state, colour] of Object.entries(RUNES)) {
  const image = decodePng(path.join(SOURCE, "v2", "button", state + ".png")), { rgba } = image;
  // How rune-blue a pixel is, against its own brightness (the pressed art's runes are as dark as its wood).
  const runeBlue = (o) => Math.max(0, Math.min(1, ((rgba[o + 2] - Math.max(rgba[o], rgba[o + 1])) / (rgba[o + 2] + 1) - 0.12) / 0.25));
  let brightest = 1;  // the brightest rune pixel's blue: that one gets the full new colour
  for (let o = 0; o < rgba.length; o += 4) if (runeBlue(o) > 0.8) brightest = Math.max(brightest, rgba[o + 2]);
  for (let o = 0; o < rgba.length; o += 4) {
    const [r, g, b, alpha] = [rgba[o], rgba[o + 1], rgba[o + 2], rgba[o + 3]];
    if (alpha > 0 && alpha < 250 && Math.min(r, g, b) > 110) { rgba[o + 3] = 0; continue; }  // the halo
    if (!colour) continue;
    const blue = runeBlue(o);
    if (!blue) continue;
    const light = b / brightest;  // the rune's own shading
    for (let c = 0; c < 3; c++) rgba[o + c] = Math.round(rgba[o + c] * (1 - blue) + Math.min(255, colour[c] * light) * blue);
  }
  save("Button_" + state, 256, 128, resample(image, 0, 0, image.width, image.height, 256, 128));
}
// A white square with a soft transparent rim, for the coloured edge round the small polaroids' pictures: turned, a
// plain colour square's edges come out jagged; the rim lets the game smooth them. The square fills EDGE_FILL of it.
{
  const size = 64, rim = 2, rgba = Buffer.alloc(size * size * 4);
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      const inside = Math.min(x + 0.5, y + 0.5, size - x - 0.5, size - y - 0.5) - rim;  // pixels in from the rim
      rgba.set([255, 255, 255, Math.round(Math.max(0, Math.min(1, inside + 0.5)) * 255)], (y * size + x) * 4);
    }
  }
  save("Edge", size, size, rgba);
}
// The arrow: a white arrowhead pointing right, its back edge curving in a little; antialiased by supersampling.
{
  const size = 64, rgba = Buffer.alloc(size * size * 4);
  const inside = (x, y) => {  // in units of the texture (0..1)
    const tip = 0.94, back = 0.12, half = 0.44;
    if (x > tip) return false;
    const reach = ((tip - x) / (tip - back)) * half;  // the sloping sides
    if (Math.abs(y - 0.5) > reach) return false;
    const notch = back + 0.16 * (1 - ((y - 0.5) / half) ** 2);  // the curved back
    return x >= notch;
  };
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      let hits = 0;
      for (let sy = 0; sy < 4; sy++) for (let sx = 0; sx < 4; sx++) if (inside((x + (sx + 0.5) / 4) / size, (y + (sy + 0.5) / 4) / size)) hits++;
      rgba.set([255, 255, 255, Math.round((hits / 16) * 255)], (y * size + x) * 4);
    }
  }
  save("Arrow", size, size, rgba);
}
// The icons: a shape drawn here (as in the design: light grey, a dark slightly wobbly outline) with a crayon icon
// from tools/make-role-icons.js (%USERPROFILE%killtracker-art-extraRoleIcons, 256x256) on it, 128x128.
const ROLE_ICONS = path.join(os.homedir(), "killtracker-art-extra", "RoleIcons");
const SIZE = 128, FILL = [218, 218, 218], LINE = [30, 28, 28], LINE_WIDTH = 9;
// A regular polygon pointing up, filling the canvas (radius r from the centre, its corners nudged a little).
function polygon(sides, r, turn = 0, seed = 1, amount = 2.4) {
  let n = seed;
  const wobble = () => { n = (n * 16807) % 2147483647; return (n / 2147483647 - 0.5) * amount; };
  return Array.from({ length: sides }, (_, i) => {
    const a = -Math.PI / 2 + turn + (i * 2 * Math.PI) / sides;
    return [SIZE / 2 + Math.cos(a) * r + wobble(), SIZE / 2 + Math.sin(a) * r + wobble()];
  });
}
const SHAPES = {
  CLASS: () => polygon(7, 61, 0, 7),
  GENDER: () => polygon(6, 62, 0, 6),
  RACE: () => polygon(64, 59, 0, 3, 0.5),
  PROFESSION: () => polygon(5, 63, 0, 5),
  SECONDARY: () => polygon(4, 62, 0, 4),
};
// The icon's size on its shape (share of the canvas) and how far down its centre sits (the pentagon's middle is
// lower than the canvas's).
const PLACE = { CLASS: [0.6, 0.02], GENDER: [0.62, 0], RACE: [0.66, 0], PROFESSION: [0.56, 0.06], SECONDARY: [0.5, 0] };
function distanceToEdge(x, y, poly) {
  let best = Infinity;
  for (let i = 0; i < poly.length; i++) {
    const [ax, ay] = poly[i], [bx, by] = poly[(i + 1) % poly.length];
    const dx = bx - ax, dy = by - ay, t = Math.max(0, Math.min(1, ((x - ax) * dx + (y - ay) * dy) / (dx * dx + dy * dy)));
    best = Math.min(best, Math.hypot(x - ax - t * dx, y - ay - t * dy));
  }
  return best;
}
function insidePoly(x, y, poly) {
  let inside = false;
  for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    const [xi, yi] = poly[i], [xj, yj] = poly[j];
    if (yi > y !== yj > y && x < ((xj - xi) * (y - yi)) / (yj - yi) + xi) inside = !inside;
  }
  return inside;
}
// The shape alone: the outline straddles the polygon's edge (half its width outside), so it's drawn inset by that.
function shape(kind) {
  const poly = SHAPES[kind]().map(([x, y]) => [SIZE / 2 + (x - SIZE / 2) * (1 - LINE_WIDTH / SIZE), SIZE / 2 + (y - SIZE / 2) * (1 - LINE_WIDTH / SIZE)]);
  const rgba = Buffer.alloc(SIZE * SIZE * 4);
  for (let y = 0; y < SIZE; y++) {
    for (let x = 0; x < SIZE; x++) {
      let fill = 0, line = 0;
      for (let sy = 0; sy < 4; sy++) {
        for (let sx = 0; sx < 4; sx++) {
          const px = x + (sx + 0.5) / 4, py = y + (sy + 0.5) / 4;
          if (distanceToEdge(px, py, poly) < LINE_WIDTH / 2) line++;
          else if (insidePoly(px, py, poly)) fill++;
        }
      }
      const alpha = (fill + line) / 16;
      if (!alpha) continue;
      const mix = line / (fill + line);
      rgba.set([...FILL.map((c, k) => c * (1 - mix) + LINE[k] * mix), Math.round(alpha * 255)], (y * SIZE + x) * 4);
    }
  }
  return rgba;
}
// Lays a crayon icon over a shape (alpha "over"), scaled to share of the canvas, centred (shifted down by drop).
function overlay(rgba, iconFile, share, drop) {
  const icon = decodePng(iconFile), size = Math.round(SIZE * share);
  const small = resample(icon, 0, 0, icon.width, icon.height, size, size);
  const x0 = Math.round((SIZE - size) / 2), y0 = Math.round((SIZE - size) / 2 + drop * SIZE);
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      const i = (y * size + x) * 4, o = ((y0 + y) * SIZE + x0 + x) * 4, a = small[i + 3] / 255;
      if (!a) continue;
      const under = rgba[o + 3] / 255, out = a + under * (1 - a);
      for (let c = 0; c < 3; c++) rgba[o + c] = Math.round((small[i + c] * a + rgba[o + c] * under * (1 - a)) / out);
      rgba[o + 3] = Math.round(out * 255);
    }
  }
  return rgba;
}
const ICONS = {
  Class: ["DRUID", "HUNTER", "MAGE", "PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR"].map((n) => [n, "CLASS"]),
  Race: ["DWARF", "GNOME", "HUMAN", "NIGHTELF", "SKYBORNE"].map((n) => [n, "RACE"]),
  Gender: ["MALE", "FEMALE", "NONBINARY"].map((n) => [n, "GENDER"]),
  Prof: [...["ALCHEMY", "BLACKSMITHING", "ENCHANTING", "ENGINEERING", "HERBALISM", "LEATHERWORKING", "MINING", "SKINNING",
    "TAILORING"].map((n) => [n, "PROFESSION"]), ...["COOKING", "FIRSTAID", "FISHING"].map((n) => [n, "SECONDARY"])],
};
for (const kind of Object.keys(SHAPES)) save(path.join("Icons", "Base_" + kind), SIZE, SIZE, shape(kind));
for (const [prefix, list] of Object.entries(ICONS)) {
  for (const [name, kind] of list) {
    const [share, drop] = PLACE[kind];
    save(path.join("Icons", `${prefix}_${name}`), SIZE, SIZE, overlay(shape(kind), path.join(ROLE_ICONS, name.toLowerCase() + ".png"), share, drop));
  }
}
console.log("Media/Overview written:", fs.readdirSync(TARGET).length - 1, "textures and", fs.readdirSync(path.join(TARGET, "Icons")).length, "icons");
