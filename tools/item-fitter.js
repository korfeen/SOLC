// Fit a painted piece on the ogre by hand (no guessing):
//   node tools/item-fitter.js
// opens http://localhost:5180: pick a piece (killtracker-art-extra\Unlocks\generated\painted\<id>.png), move it (drag),
// scale it (wheel, round the mouse; Alt+wheel: its width), turn it (Shift+wheel), flip it; cut parts out of it to move on
// their own (Part: a box round a bracer, to put it on the wrist); erase bits of it (right mouse: where the fist goes in front of a
// grip), bring them back (Restore); Ctrl+wheel zooms the view, Space+drag or the middle mouse moves it. Save writes the
// piece as placed over painted\<id>.png (then: node tools/make-unlock-art.js gear && node tools/convert-art.js).
// Each piece's first save keeps its original as generated\fits\<id>.source.png, and the placement (fits\<id>.json) and
// the erasing (fits\<id>.erase.png) are kept too: opening it again starts from the original with them, so a fit can be
// changed without losing anything, and a repainted piece (a new painted\<id>.png: delete its fits\<id>.source.png)
// gets the same placement when it's opened. Hide ogre: the brushes paint where the ogre itself vanishes under this piece
// instead (an ear through a hood, a bit of arm past a sleeve, a stray pixel), kept as fits\<id>.hide.png: convert-art.js
// makes it a mask the game puts on the ogre's skin while the piece is worn (Minting.lua). Plain Node, no packages.

const http = require("http");
const fs = require("fs");
const os = require("os");
const path = require("path");
const { exec } = require("child_process");
const { decodePng } = require("./convert-art");
const { writePng } = require("./make-role-icons");

const ART = path.join(os.homedir(), "killtracker-art");
const GEN = path.join(os.homedir(), "killtracker-art-extra", "Unlocks", "generated");
const PAINTED = path.join(GEN, "painted");
const FITS = path.join(GEN, "fits");
const SIZE = 1254, PORT = 5180;

function pngOf(rgba) {
  const tmp = path.join(os.tmpdir(), "solc-fitter-" + process.pid + ".png");
  writePng(tmp, SIZE, SIZE, rgba);
  return fs.readFileSync(tmp);
}
// The ogre underneath: the moss skin, a face, and (pajamas) its striped pajamas.
function ogrePng(pajamas) {
  const pic = Buffer.alloc(SIZE * SIZE * 4);
  for (let i = 0; i < pic.length; i += 4) pic.set([40, 32, 40, 255], i);
  const layers = ["Skin/Uncommon/moss.png"].concat(pajamas ? ["Outfit/Uncommon/striped-pajamas.png"] : [],
    ["Expression/Uncommon/moss/smug-smile.png", "Eyes/Uncommon/moss/heavy-bags.png"]);
  for (const rel of layers) {
    const file = path.join(ART, rel);
    if (!fs.existsSync(file)) continue;
    const r = decodePng(file).rgba;
    for (let i = 0; i < pic.length; i += 4) {
      const a = r[i + 3] / 255;
      for (let k = 0; k < 3; k++) pic[i + k] = Math.round(r[i + k] * a + pic[i + k] * (1 - a));
    }
  }
  return pngOf(pic);
}
const safe = (id) => /^[\w-]+$/.test(id) ? id : null;
function source(id) {
  const kept = path.join(FITS, id + ".source.png");
  return fs.existsSync(kept) ? kept : path.join(PAINTED, id + ".png");
}

const PAGE = `<!doctype html><meta charset="utf-8"><title>Item Fitter</title>
<style>
body { margin: 0; background: #1a1410; color: #eee0c7; font: 14px system-ui, sans-serif; display: flex; height: 100vh; overflow: hidden; }
.side { width: 230px; background: #22180f; overflow: auto; border-right: 1px solid #4a3320; }
.side input { width: calc(100% - 20px); margin: 8px 10px; padding: 5px; background: #120c08; color: #eee0c7; border: 1px solid #5a4128; }
.item { padding: 4px 10px; cursor: pointer; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; font-size: 13px; }
.item:hover { background: #3a2817; } .item.on { background: #6b5030; color: #fff; } .item.fitted::after { content: " ✓"; color: #9fdc6a; }
.main { flex: 1; display: flex; flex-direction: column; min-width: 0; min-height: 0; }
.bar { display: flex; gap: 10px; align-items: center; padding: 8px 12px; background: #2a1e14; flex-wrap: wrap; }
button { background: #4a3320; color: #eee0c7; border: 1px solid #8a6a3a; border-radius: 4px; padding: 5px 10px; cursor: pointer; font: inherit; }
button.on { background: #8a6a3a; color: #fff; } #save { background: #3f6b2a; border-color: #6fa04a; }
.wrap { flex: 1; overflow: auto; min-height: 0; } .wrap canvas { display: block; margin: 20px auto; cursor: crosshair; }
#msg { color: #ffd21a; } .hint { color: #9e8f7a; font-size: 12px; }
</style>
<div class="side"><input id="filter" placeholder="Filter..."><div id="list"></div></div>
<div class="main">
  <div class="bar">
    <b id="name">Pick a piece</b>
    <button id="move" class="on">Move (left)</button><button id="erase">Erase (right)</button><button id="restore">Restore</button>
    <button id="part">Part</button><button id="whole" class="on">Whole</button><button id="delpart" disabled>Delete part</button>
    <button id="wand">Wand</button>
    <label title="Erase/Restore/lasso paint where the ogre vanishes under this piece"><input id="hideOgre" type="checkbox"> Hide ogre</label>
    <label>Shape <select id="shape"><option value="round">round</option><option value="lasso">lasso</option></select></label>
    <label>Brush <input id="size" type="range" min="4" max="160" value="40"></label>
    <label>Strength <input id="strength" type="range" min="10" max="100" value="100"></label>
    <label>Soft <input id="soft" type="range" min="0" max="100" value="0"></label>
    <label>Tolerance <input id="tol" type="range" min="2" max="100" value="25"></label>
    <button id="flip">Flip</button><button id="reset">Reset place</button>
    <label>Scale from <select id="pivot"><option value="mouse">mouse</option><option value="middle">middle</option></select></label>
    <label><input id="pj" type="checkbox"> Pajamas</label>
    <label>Zoom <input id="zoom" type="range" min="30" max="400" value="60"> <span id="zoomV">60%</span></label><button id="fitview">Fit (F)</button>
    <button id="undo">Undo</button><button id="save">Save</button><span id="msg"></span>
  </div>
  <div class="bar hint">Erase/Restore: Shape round paints, lasso fills what you draw round; Strength: how much a stroke erases; Soft: how far its edge fades; Wand: click a colour to erase it and what touches it (Tolerance: how alike) · Hide ogre: the brushes erase the ogre under this piece instead (shown red while on) · Part: draw round a bit (a bracer) to move it on its own; click it to pick it, Whole or a click outside it for the rest · Left drag: move (or paint, in Erase/Restore) · wheel: scale · Alt+wheel: stretch the width · Shift+wheel: turn · right drag: erase · Ctrl+wheel: zoom · Space+drag / middle: move the view · Ctrl+Z: undo</div>
  <div class="wrap"><canvas id="view" width="${SIZE}" height="${SIZE}"></canvas></div>
</div>
<script>
const S = ${SIZE};
const view = document.getElementById("view"), vx = view.getContext("2d"), wrap = document.querySelector(".wrap");
const erase = document.createElement("canvas"); erase.width = erase.height = S; const ex = erase.getContext("2d");
const out = document.createElement("canvas"); out.width = out.height = S; const ox = out.getContext("2d");
// Where the ogre vanishes under this piece (Hide ogre), and the ogre drawn without it.
const hide = document.createElement("canvas"); hide.width = hide.height = S; const hdx = hide.getContext("2d");
const og = document.createElement("canvas"); og.width = og.height = S; const ogx = og.getContext("2d");
const hiding = () => document.getElementById("hideOgre").checked;
const paintX = () => hiding() ? hdx : ex;  // (what the brushes paint on)
let ogre = new Image(), item = null, id = null, fit = null, mode = "move", size = 40, zoom = 0.6, space = false;
let drag = null, pan = null, cursor = null, lasso = null;
const undo = [];
const ogres = {};
function loadImg(src) { return new Promise((r) => { const i = new Image(); i.onload = () => r(i); i.src = src; }); }
async function setOgre() { const pj = document.getElementById("pj").checked; ogres[pj] = ogres[pj] || await loadImg("/ogre.png?pajamas=" + (pj ? 1 : 0)); ogre = ogres[pj]; draw(); }
function plain() { return { x: 0, y: 0, scale: 1, sx: 1, rot: 0, flip: false }; }
const outfit = () => /_(body|suit)$/.test(id || "");  // (an outfit, or a creature's hooded onesie: scaled from the bottom)
const clone = (o) => JSON.parse(JSON.stringify(o));
// Parts (fit.parts): boxes cut out of the piece (box: in the piece's own pixels) that move, scale and turn on their own,
// on top of the whole's placement (x, y: pixels moved; scale, sx, rot round the box's middle) - a bracer onto its wrist.
// sel: what the controls move (-1: the whole, else a part).
let sel = -1;
const hole = document.createElement("canvas"); hole.width = hole.height = S; const hx = hole.getContext("2d");
function mainM() {
  return new DOMMatrix().translate(S / 2 + fit.x, S / 2 + fit.y).rotate(fit.rot * 180 / Math.PI)
    .scale(fit.scale * (fit.sx || 1) * (fit.flip ? -1 : 1), fit.scale).translate(-S / 2, -S / 2);
}
function partBase(p) { return mainM().transformPoint({ x: p.box.x + p.box.w / 2, y: p.box.y + p.box.h / 2 }); }
function partM(p) {
  const c = partBase(p);
  return new DOMMatrix().translate(c.x + p.x, c.y + p.y).rotate(p.rot * 180 / Math.PI)
    .scale(p.scale * (p.sx || 1) * (p.flip ? -1 : 1), p.scale)
    .translate(-c.x, -c.y).multiply(mainM());
}
// A part's outline (poly: drawn with the lasso; older parts: their box), in the piece's own pixels.
function polyOf(p) {
  if (p.poly) return p.poly;
  const b = p.box;
  return [[b.x, b.y], [b.x + b.w, b.y], [b.x + b.w, b.y + b.h], [b.x, b.y + b.h]];
}
function pathOf(p) { const path = new Path2D(); polyOf(p).forEach(([x, y], k) => k ? path.lineTo(x, y) : path.moveTo(x, y)); path.closePath(); return path; }
function partOutline(p) { const m = partM(p); return polyOf(p).map(([x, y]) => m.transformPoint({ x, y })); }
function inside(poly, x, y) {
  let a = false;
  for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    const [xi, yi] = poly[i], [xj, yj] = poly[j];
    if ((yi > y) !== (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) a = !a;
  }
  return a;
}
function partAt(pt) {
  const parts = fit.parts || [];
  for (let i = parts.length - 1; i >= 0; i--) {
    const q = partM(parts[i]).inverse().transformPoint(pt);
    if (inside(polyOf(parts[i]), q.x, q.y)) return i;
  }
  return -1;
}
// A part's mask: its outline a little wider than the cut it leaves in the whole, its edge softened, so a part that hasn't
// moved covers its cut with no seam, and one that has blends in.
const masks = new WeakMap();
function maskOf(p) {
  if (masks.has(p)) return masks.get(p);
  const c = document.createElement("canvas"); c.width = c.height = S;
  const x = c.getContext("2d"), path = pathOf(p);
  x.filter = "blur(1.5px)"; x.fillStyle = x.strokeStyle = "#000"; x.lineWidth = 5; x.lineJoin = "round";
  x.fill(path); x.stroke(path);
  masks.set(p, c);
  return c;
}
const pc = document.createElement("canvas"); pc.width = pc.height = S; const px = pc.getContext("2d");
// The piece as placed (the whole with its parts cut out, then each part), erased, into out.
function render() {
  ox.setTransform(1, 0, 0, 1, 0, 0);
  ox.clearRect(0, 0, S, S);
  if (!item) return;
  const parts = fit.parts || [];
  hx.clearRect(0, 0, S, S); hx.drawImage(item, 0, 0);
  hx.globalCompositeOperation = "destination-out"; for (const p of parts) hx.fill(pathOf(p)); hx.globalCompositeOperation = "source-over";
  ox.setTransform(mainM()); ox.drawImage(hole, 0, 0);
  for (const p of parts) {
    px.clearRect(0, 0, S, S); px.drawImage(maskOf(p), 0, 0);
    px.globalCompositeOperation = "source-in"; px.drawImage(item, 0, 0); px.globalCompositeOperation = "source-over";
    ox.setTransform(partM(p)); ox.drawImage(pc, 0, 0);
  }
  ox.setTransform(1, 0, 0, 1, 0, 0);
  ox.globalCompositeOperation = "destination-out"; ox.drawImage(erase, 0, 0); ox.globalCompositeOperation = "source-over";
}
// Scale by k (stretch: its width only) keeping the point p where it is. The whole of an outfit scales from the picture's
// bottom (at p's x), so its hem stays on the bottom edge; a stretch always widens from its own middle.
function scaleAt(k, p, stretch) {
  const middle = document.getElementById("pivot").value === "middle";
  if (sel >= 0) {
    const part = fit.parts[sel], b = partBase(part), c = { x: b.x + part.x, y: b.y + part.y };
    if (stretch) { part.sx = (part.sx || 1) * k; return; }
    if (middle) p = c;
    part.scale *= k; part.x += (p.x - c.x) * (1 - k); part.y += (p.y - c.y) * (1 - k);
    return;
  }
  const cx = S / 2 + fit.x, cy = S / 2 + fit.y;
  if (stretch) { fit.sx = (fit.sx || 1) * k; return; }
  if (middle) p = { x: cx, y: cy };
  else if (outfit()) p = { x: p.x, y: S };
  fit.scale *= k;
  fit.x = p.x - S / 2 - k * (p.x - cx); fit.y = p.y - S / 2 - k * (p.y - cy);
}
function draw() {
  vx.clearRect(0, 0, S, S);
  if (ogre.complete) {  // (the ogre, without where this piece hides it; that shown red while hiding)
    ogx.clearRect(0, 0, S, S); ogx.drawImage(ogre, 0, 0);
    ogx.globalCompositeOperation = "destination-out"; ogx.drawImage(hide, 0, 0); ogx.globalCompositeOperation = "source-over";
    vx.drawImage(og, 0, 0);
    if (hiding()) {
      ogx.clearRect(0, 0, S, S); ogx.drawImage(hide, 0, 0);
      ogx.globalCompositeOperation = "source-in"; ogx.fillStyle = "rgba(255,60,60,0.45)"; ogx.fillRect(0, 0, S, S); ogx.globalCompositeOperation = "source-over";
      vx.drawImage(og, 0, 0);
    }
  }
  render();
  vx.drawImage(out, 0, 0);
  vx.lineWidth = 2; vx.setLineDash([8, 6]);
  (fit && fit.parts || []).forEach((p, i) => {
    const c = partOutline(p);
    vx.strokeStyle = i === sel ? "#ffd21a" : "rgba(255,210,26,0.35)";
    vx.beginPath(); c.forEach((q, k) => k ? vx.lineTo(q.x, q.y) : vx.moveTo(q.x, q.y)); vx.closePath(); vx.stroke();
  });
  if (lasso) { vx.strokeStyle = drag && drag.lasso && drag.how === "erase" ? "#ff5050" : "#66ccff"; vx.beginPath(); lasso.forEach((q, k) => k ? vx.lineTo(q.x, q.y) : vx.moveTo(q.x, q.y)); vx.stroke(); }
  vx.setLineDash([]);
  if (cursor && (mode === "erase" || mode === "restore") && document.getElementById("shape").value === "round") { vx.strokeStyle = mode === "erase" ? "#ff5050" : "#66ccff"; vx.lineWidth = 2; vx.beginPath(); vx.arc(cursor.x, cursor.y, size / 2, 0, Math.PI * 2); vx.stroke(); }
}
function at(e) { const r = view.getBoundingClientRect(); return { x: (e.clientX - r.left) * S / r.width, y: (e.clientY - r.top) * S / r.height }; }
function snapshot() { undo.push({ fit: clone(fit), sel, erase: ex.getImageData(0, 0, S, S), hide: hdx.getImageData(0, 0, S, S) }); if (undo.length > 40) undo.shift(); }
// What the move, scale and turn controls work on: the selected part, or the whole.
const target = () => sel >= 0 ? fit.parts[sel] : fit;
function select(i) {
  sel = i;
  document.getElementById("whole").classList.toggle("on", i < 0);
  document.getElementById("delpart").disabled = i < 0;
}
// A stroke (a brush drag, a lasso, a wand click) is drawn whole into stroke, then laid over the erasing as it was before
// it (base) at the Strength: so going over the same spot in one stroke doesn't erase it more.
const base = document.createElement("canvas"); base.width = base.height = S; const bx = base.getContext("2d");
const stroke = document.createElement("canvas"); stroke.width = stroke.height = S; const sx = stroke.getContext("2d");
const val = (k) => +document.getElementById(k).value;
function beginStroke() { bx.clearRect(0, 0, S, S); bx.drawImage(paintX().canvas, 0, 0); sx.clearRect(0, 0, S, S); }
function applyStroke(how) {
  const x = paintX();
  x.clearRect(0, 0, S, S); x.drawImage(base, 0, 0);
  x.globalAlpha = val("strength") / 100;
  x.globalCompositeOperation = how === "erase" ? "source-over" : "destination-out";
  x.drawImage(stroke, 0, 0);
  x.globalAlpha = 1; x.globalCompositeOperation = "source-over";
}
// A dab of the round brush: solid, or with Soft its outer part fading out.
function brush(p, how, later) {
  const r = size / 2, soft = val("soft") / 100;
  if (soft > 0) {
    const g = sx.createRadialGradient(p.x, p.y, r * (1 - soft), p.x, p.y, r);
    g.addColorStop(0, "rgba(0,0,0,1)"); g.addColorStop(1, "rgba(0,0,0,0)");
    sx.fillStyle = g;
  } else sx.fillStyle = "#000";
  sx.beginPath(); sx.arc(p.x, p.y, r, 0, Math.PI * 2); sx.fill();
  if (!later) applyStroke(how);
}
// A shape drawn round with the lasso, filled (with Soft, its edge blurred).
function fillLasso(points, how) {
  const soft = val("soft");
  sx.filter = soft ? "blur(" + (soft / 100 * 16) + "px)" : "none"; sx.fillStyle = "#000";
  sx.beginPath(); points.forEach((q, k) => k ? sx.lineTo(q.x, q.y) : sx.moveTo(q.x, q.y)); sx.closePath(); sx.fill();
  sx.filter = "none";
  applyStroke(how);
}
// The wand: the colour clicked, and every pixel touching it that's alike (Tolerance), as the piece is drawn now.
function wand(p) {
  render();
  const d = ox.getImageData(0, 0, S, S).data, x0 = Math.round(p.x), y0 = Math.round(p.y), s0 = (y0 * S + x0) * 4;
  if (x0 < 0 || y0 < 0 || x0 >= S || y0 >= S || d[s0 + 3] < 16) return false;
  const tol = val("tol") * 2.55, seen = new Uint8Array(S * S), st = [y0 * S + x0];
  const m = sx.createImageData(S, S);
  seen[y0 * S + x0] = 1;
  while (st.length) {
    const q = st.pop(), x = q % S, y = (q / S) | 0;
    for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) {  // (itself and a pixel round it: its edge too)
      const nx = x + dx, ny = y + dy;
      if (nx >= 0 && ny >= 0 && nx < S && ny < S) m.data[(ny * S + nx) * 4 + 3] = 255;
    }
    for (const n of [x > 0 ? q - 1 : -1, x < S - 1 ? q + 1 : -1, y > 0 ? q - S : -1, y < S - 1 ? q + S : -1]) {
      if (n < 0 || seen[n]) continue;
      const k = n * 4;
      if (d[k + 3] >= 16 && Math.abs(d[k] - d[s0]) <= tol && Math.abs(d[k + 1] - d[s0 + 1]) <= tol && Math.abs(d[k + 2] - d[s0 + 2]) <= tol) {
        seen[n] = 1; st.push(n);
      }
    }
  }
  const soft = val("soft");
  if (soft) {
    const tmp = document.createElement("canvas"); tmp.width = tmp.height = S; tmp.getContext("2d").putImageData(m, 0, 0);
    sx.filter = "blur(" + (soft / 100 * 16) + "px)"; sx.drawImage(tmp, 0, 0); sx.filter = "none";
  } else sx.putImageData(m, 0, 0);
  applyStroke("erase");
  return true;
}
view.addEventListener("contextmenu", (e) => e.preventDefault());
view.addEventListener("pointerdown", (e) => {
  if (!item || e.button === 1 || space) return;
  snapshot();
  const p = at(e);
  const how = e.button === 2 ? "erase" : mode;
  if (how === "move") select(partAt(p));
  drag = { how, last: p, fx: target().x, fy: target().y, start: p };
  if (how === "part") { lasso = [p]; return; }
  if (how === "wand" && hiding()) { undo.pop(); drag = null; document.getElementById("msg").textContent = "The wand works on the piece: untick Hide ogre"; return; }
  if (how === "wand") { beginStroke(); if (!wand(p)) undo.pop(); drag = null; draw(); return; }
  if (how === "erase" || how === "restore") {
    beginStroke();
    if (document.getElementById("shape").value === "lasso") { drag.lasso = true; lasso = [p]; return; }
    brush(p, how); draw();
  }
});
window.addEventListener("pointermove", (e) => {
  if (pan) { wrap.scrollLeft = pan.l - (e.clientX - pan.x); wrap.scrollTop = pan.t - (e.clientY - pan.y); return; }
  cursor = e.target === view ? at(e) : null;
  if (drag) {
    const p = at(e);
    if (drag.how === "move") { const t = target(); t.x = drag.fx + p.x - drag.start.x; t.y = drag.fy + p.y - drag.start.y; }
    else if (drag.how === "part" || drag.lasso) {
      const last = lasso[lasso.length - 1];
      if (Math.hypot(p.x - last.x, p.y - last.y) > 3) lasso.push(p);
    }
    else {
      const steps = Math.max(1, Math.ceil(Math.hypot(p.x - drag.last.x, p.y - drag.last.y) / (size / 4)));
      for (let i = 1; i <= steps; i++) brush({ x: drag.last.x + (p.x - drag.last.x) * i / steps, y: drag.last.y + (p.y - drag.last.y) * i / steps }, drag.how, true);
      applyStroke(drag.how);
      drag.last = p;
    }
  }
  draw();
});
// A shape drawn round something in Part mode (letting go closes it) becomes a part: the piece's pixels inside it (kept in
// its own pixels, wherever the whole is now).
window.addEventListener("pointerup", () => {
  if (drag && drag.lasso && lasso) {
    if (lasso.length >= 3) fillLasso(lasso, drag.how); else undo.pop();
    lasso = null;
    draw();
  }
  if (drag && drag.how === "part" && lasso) {
    const inv = mainM().inverse();
    const poly = lasso.map((q) => { const s = inv.transformPoint(q); return [Math.round(s.x * 2) / 2, Math.round(s.y * 2) / 2]; });
    const xs = poly.map((q) => q[0]), ys = poly.map((q) => q[1]);
    const x0 = Math.min(...xs), y0 = Math.min(...ys), x1 = Math.max(...xs), y1 = Math.max(...ys);
    if (poly.length >= 3 && x1 - x0 > 8 && y1 - y0 > 8) {
      fit.parts = fit.parts || [];
      fit.parts.push({ poly, box: { x: x0, y: y0, w: x1 - x0, h: y1 - y0 }, x: 0, y: 0, scale: 1, sx: 1, rot: 0 });
      select(fit.parts.length - 1);
      setMode("move");
    } else undo.pop();
    lasso = null;
    draw();
  }
  drag = null; pan = null;
});
wrap.addEventListener("pointerdown", (e) => {
  if (e.button === 1 || space) { e.preventDefault(); pan = { x: e.clientX, y: e.clientY, l: wrap.scrollLeft, t: wrap.scrollTop }; }
}, true);
function setZoom(z, e) {
  z = Math.max(0.3, Math.min(4, z));
  const r = view.getBoundingClientRect();
  const fx = e ? (e.clientX - r.left) / r.width : 0.5, fy = e ? (e.clientY - r.top) / r.height : 0.5;
  zoom = z; view.style.width = (S * zoom) + "px";
  document.getElementById("zoom").value = Math.round(zoom * 100); document.getElementById("zoomV").textContent = Math.round(zoom * 100) + "%";
  if (e) { const r2 = view.getBoundingClientRect(); wrap.scrollLeft += r2.left + fx * r2.width - e.clientX; wrap.scrollTop += r2.top + fy * r2.height - e.clientY; }
}
view.addEventListener("wheel", (e) => {
  e.preventDefault();
  if (e.ctrlKey) return setZoom(zoom * (e.deltaY < 0 ? 1.15 : 1 / 1.15), e);
  if (!item) return;
  if ((mode === "erase" || mode === "restore") && !e.shiftKey) { size = Math.max(4, Math.min(160, size + (e.deltaY < 0 ? 4 : -4))); document.getElementById("size").value = size; draw(); return; }
  snapshot();
  const k = e.deltaY < 0 ? 1.03 : 1 / 1.03;
  if (e.shiftKey) target().rot += (e.deltaY < 0 ? 1 : -1) * Math.PI / 180 * 2;
  else if (e.altKey) scaleAt(e.deltaY < 0 ? 1.01 : 1 / 1.01, at(e), true);
  else scaleAt(k, at(e));
  draw();
}, { passive: false });
window.addEventListener("keydown", (e) => {
  if (e.key === "Alt") e.preventDefault();  // (else letting go of Alt jumps to the browser's menu)
  if (e.code === "Space" && e.target.tagName !== "INPUT") { space = true; e.preventDefault(); }
  if (e.key === "f" && !e.ctrlKey && e.target.tagName !== "INPUT") fitView();
  if ((e.ctrlKey || e.metaKey) && e.key === "z") { e.preventDefault(); doUndo(); }
});
window.addEventListener("keyup", (e) => { if (e.key === "Alt") e.preventDefault(); if (e.code === "Space") space = false; });
function doUndo() { const u = undo.pop(); if (!u) return; fit = u.fit; select(fit.parts && fit.parts[u.sel] ? u.sel : -1); ex.putImageData(u.erase, 0, 0); if (u.hide) hdx.putImageData(u.hide, 0, 0); draw(); }
function setMode(m) { mode = m; for (const k of ["move", "erase", "restore", "part", "wand"]) document.getElementById(k).classList.toggle("on", k === m); }
for (const k of ["move", "erase", "restore", "part", "wand"]) document.getElementById(k).onclick = () => setMode(k);
document.getElementById("whole").onclick = () => { select(-1); draw(); };
document.getElementById("delpart").onclick = () => { if (sel < 0) return; snapshot(); fit.parts.splice(sel, 1); select(-1); draw(); };
document.getElementById("size").oninput = (e) => { size = +e.target.value; };
document.getElementById("flip").onclick = () => { if (!item) return; snapshot(); const t = target(); t.flip = !t.flip; draw(); };
document.getElementById("reset").onclick = () => {
  if (!item) return;
  snapshot();
  if (sel >= 0) Object.assign(fit.parts[sel], { x: 0, y: 0, scale: 1, sx: 1, rot: 0, flip: false });
  else fit = { ...plain(), parts: fit.parts };
  draw();
};
document.getElementById("undo").onclick = doUndo;
document.getElementById("pj").onchange = setOgre;
document.getElementById("hideOgre").onchange = () => draw();
document.getElementById("zoom").oninput = (e) => setZoom(e.target.value / 100);
async function open(name) {
  id = name; document.getElementById("name").textContent = name; document.getElementById("msg").textContent = "";
  for (const el of document.querySelectorAll(".item")) el.classList.toggle("on", el.dataset.id === name);
  const info = await (await fetch("/fit/" + name)).json();
  fit = info.fit || plain();
  select(-1);
  item = await loadImg("/source/" + name + "?" + Date.now());
  ex.clearRect(0, 0, S, S);
  if (info.erase) ex.drawImage(await loadImg("/erase/" + name + "?" + Date.now()), 0, 0);
  hdx.clearRect(0, 0, S, S);
  if (info.hide) hdx.drawImage(await loadImg("/hide/" + name + "?" + Date.now()), 0, 0);
  undo.length = 0;
  draw();
}
document.getElementById("save").onclick = async () => {
  if (!item) return;
  const msg = document.getElementById("msg"); msg.textContent = "Saving...";
  render();
  const blob = (c) => new Promise((r) => c.toBlob(r, "image/png"));
  const body = new FormData();
  body.append("fit", JSON.stringify(fit)); body.append("piece", await blob(out)); body.append("erase", await blob(erase)); body.append("hide", await blob(hide));
  const res = await fetch("/save/" + id, { method: "POST", body });
  msg.textContent = res.ok ? "Saved " + id : "Couldn't save: " + res.status;
  if (res.ok) document.querySelector('.item[data-id="' + id + '"]').classList.add("fitted");
};
async function list() {
  const items = await (await fetch("/list")).json();
  const box = document.getElementById("list");
  const show = () => {
    const f = document.getElementById("filter").value.toLowerCase();
    box.innerHTML = "";
    for (const it of items) {
      if (f && !it.id.toLowerCase().includes(f)) continue;
      const el = document.createElement("div");
      el.className = "item" + (it.fitted ? " fitted" : "") + (it.id === id ? " on" : ""); el.dataset.id = it.id; el.textContent = it.id;
      el.onclick = () => open(it.id); box.appendChild(el);
    }
  };
  document.getElementById("filter").oninput = show; show();
}
// The whole picture in the window.
function fitView() { setZoom(Math.min((wrap.clientWidth - 40) / S, (wrap.clientHeight - 40) / S)); wrap.scrollLeft = wrap.scrollTop = 0; }
document.getElementById("fitview").onclick = fitView;
fitView(); setOgre(); list();
</script>`;

// A multipart form's parts: { name: Buffer }.
function parseForm(body, type) {
  const boundary = "--" + type.split("boundary=")[1];
  const parts = {};
  let start = body.indexOf(boundary);
  while (start >= 0) {
    const next = body.indexOf(boundary, start + boundary.length);
    if (next < 0) break;
    const part = body.slice(start + boundary.length + 2, next - 2);
    const headEnd = part.indexOf("\r\n\r\n");
    const head = part.slice(0, headEnd).toString();
    const name = (head.match(/name="([^"]+)"/) || [])[1];
    if (name) parts[name] = part.slice(headEnd + 4);
    start = next;
  }
  return parts;
}

const server = http.createServer((req, res) => {
  const url = new URL(req.url, "http://localhost");
  const send = (type, data) => { res.writeHead(200, { "Content-Type": type }); res.end(data); };
  const m = url.pathname.match(/^\/(source|fit|erase|hide|save)\/([\w-]+)$/);
  if (url.pathname === "/") return send("text/html", PAGE);
  if (url.pathname === "/ogre.png") return send("image/png", ogrePng(url.searchParams.get("pajamas") === "1"));
  if (url.pathname === "/list") {
    const files = fs.existsSync(PAINTED) ? fs.readdirSync(PAINTED).filter((f) => f.endsWith(".png")) : [];
    return send("application/json", JSON.stringify(files.map((f) => {
      const id = f.slice(0, -4);
      return { id, fitted: fs.existsSync(path.join(FITS, id + ".json")) };
    }).sort((a, b) => a.id.localeCompare(b.id))));
  }
  if (m && safe(m[2])) {
    const id = m[2];
    if (m[1] === "source") return send("image/png", fs.readFileSync(source(id)));
    if (m[1] === "fit") {
      const file = path.join(FITS, id + ".json");
      return send("application/json", JSON.stringify({ fit: fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, "utf8")) : null,
        erase: fs.existsSync(path.join(FITS, id + ".erase.png")), hide: fs.existsSync(path.join(FITS, id + ".hide.png")) }));
    }
    if (m[1] === "erase") return send("image/png", fs.readFileSync(path.join(FITS, id + ".erase.png")));
    if (m[1] === "hide") return send("image/png", fs.readFileSync(path.join(FITS, id + ".hide.png")));
    if (m[1] === "save" && req.method === "POST") {
      const chunks = [];
      req.on("data", (c) => chunks.push(c));
      req.on("end", () => {
        const parts = parseForm(Buffer.concat(chunks), req.headers["content-type"] || "");
        fs.mkdirSync(FITS, { recursive: true });
        const kept = path.join(FITS, id + ".source.png");
        if (!fs.existsSync(kept)) fs.copyFileSync(path.join(PAINTED, id + ".png"), kept);  // (the original, once)
        fs.writeFileSync(path.join(FITS, id + ".json"), parts.fit || "{}");
        if (parts.erase) fs.writeFileSync(path.join(FITS, id + ".erase.png"), parts.erase);
        if (parts.hide) fs.writeFileSync(path.join(FITS, id + ".hide.png"), parts.hide);
        if (parts.piece) fs.writeFileSync(path.join(PAINTED, id + ".png"), parts.piece);
        console.log("Saved " + id);
        send("text/plain", "ok");
      });
      return;
    }
  }
  res.writeHead(404);
  res.end();
});
server.listen(PORT, "127.0.0.1", () => {
  const url = `http://localhost:${PORT}`;
  console.log(`Item fitter: ${url}  (Ctrl+C here to stop)`);
  if (!process.env.NO_OPEN) exec(`start "" "${url}"`);
});
