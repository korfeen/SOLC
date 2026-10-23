// The Dream Bed's room in a browser, to lay it out by hand (like tools/item-fitter.js): the painted pieces
// (tools/gen-dreambed-art.js) placed by tools/dreambed-layout.json, the page's size (827x584) drawn at 2x. Click a piece
// to pick it (or in the list), drag it, mouse wheel to size it, arrow keys to nudge (shift: more), Q/E or alt+wheel to
// tilt it (rot, degrees; shift: more), W/S to stretch or squash its height (flat, 1 = as painted), Save writes the
// layout (DreamBed.lua places the pieces by it; tools/preview-dreambed.js draws it too). Night/morning to check both.
// Usage: node tools/dreambed-room.js   then open http://localhost:5181   (plain Node, no packages)
const fs = require("fs");
const os = require("os");
const path = require("path");
const http = require("http");
const { decodePng } = require("./convert-art");
const { writePng } = require("./make-role-icons");

const PORT = 5181;
const PIECES = path.join(os.homedir(), "killtracker-art-extra", "DreamBed", "pieces");
const ART = path.join(os.homedir(), "killtracker-art");
const LAYOUT = path.join(__dirname, "dreambed-layout.json");
// Front to back is the list's order reversed: the easel and the jar's tools last. The floor (floor.png, the whole page)
// lies behind the room, showing through its cut-out floor as the sky through its window, below the wall only: pick
// "floor" or click the bare floor, drag to slide its boards, wheel to zoom - { x, y, zoom }. The rug lies on it.
// The wall reaches down to wall.floor (pick "wall" or click bare wall, drag or arrows up/down): the room's wooden panel
// (its planks upright) stretched down to it, the rest of the room as painted.
// (the jar in two: its back, the tools standing in it, its front - jarfront, cut by hand from the jar: placed with the jar)
const ORDER = ["rug", "nightstand", "mallet", "peg", "headboard", "pillow", "head", "quilt", "candle", "flame", "mug", "book", "easel", "jar", "brush", "pencils", "crayon", "jarfront"];

function pngOf(w, h, rgba) {
  const tmp = path.join(os.tmpdir(), "dreambed-room-" + process.pid + ".png");
  writePng(tmp, w, h, rgba);
  return fs.readFileSync(tmp);
}
// Each piece's visible box in its picture (fractions).
function Boxes() {
  const out = {};
  for (const f of fs.readdirSync(PIECES).filter((f) => f.endsWith(".png") && f !== "room.png" && f !== "floor.png")) {
    const img = decodePng(path.join(PIECES, f));
    let x0 = img.width, y0 = img.height, x1 = -1, y1 = -1;
    for (let y = 0; y < img.height; y++) for (let x = 0; x < img.width; x++) if (img.rgba[(y * img.width + x) * 4 + 3] > 40) { x0 = Math.min(x0, x); x1 = Math.max(x1, x); y0 = Math.min(y0, y); y1 = Math.max(y1, y); }
    out[f.slice(0, -4)] = { x: x0 / img.width, y: y0 / img.height, w: (x1 - x0 + 1) / img.width, h: (y1 - y0 + 1) / img.height };
  }
  return out;
}
// The ogre in bed (for laying out: moss, a nightcap... as the fitter's): asleep or awake.
function Ogre(awake) {
  // (his outfit stays on in bed: it shows above the quilt; striped pyjamas stand in for yours)
  const layers = ["Skin/Uncommon/moss.png", "Outfit/Uncommon/striped-pajamas.png", "Eyes/Uncommon/moss/" + (awake ? "heavy-bags.png" : "fully-asleep.png"),
    "Expression/Uncommon/moss/" + (awake ? "smug-smile.png" : "mouth-hanging-open.png"), "Headwear/Rare/captain-tricorn.png"];
  let pic = null, size = 0;
  for (const rel of layers) {
    const f = path.join(ART, rel);
    if (!fs.existsSync(f)) continue;
    const img = decodePng(f);
    if (!pic) { size = img.width; pic = Buffer.alloc(size * size * 4); }
    for (let i = 0; i < pic.length; i += 4) {
      const a = img.rgba[i + 3] / 255, b = pic[i + 3] / 255, o = a + b * (1 - a);
      if (!o) continue;
      for (let k = 0; k < 3; k++) pic[i + k] = Math.round((img.rgba[i + k] * a + pic[i + k] * b * (1 - a)) / o);
      pic[i + 3] = Math.round(o * 255);
    }
  }
  return pngOf(size, size, pic);
}

const PAGE = `<!doctype html><meta charset="utf-8"><title>Dream Bed room</title>
<style>
body { margin: 0; background: #15122a; color: #efe7d4; font: 14px system-ui, sans-serif; display: flex; gap: 16px; padding: 14px; }
canvas { background: #000; border-radius: 6px; cursor: grab; box-shadow: 0 6px 24px #000a; }
#side { width: 230px; display: flex; flex-direction: column; gap: 8px; }
#list button { display: block; width: 100%; text-align: left; margin: 2px 0; padding: 4px 8px; border: 0; border-radius: 5px; background: #2a2350; color: #efe7d4; cursor: pointer; }
#list button.on { background: #ffcf4a; color: #2a1a00; }
.row { display: flex; gap: 6px; flex-wrap: wrap; }
.row button, #save { padding: 6px 12px; border: 0; border-radius: 6px; background: #3a2f6a; color: #efe7d4; cursor: pointer; }
#save { background: #ffcf4a; color: #2a1a00; font-weight: 700; }
#info { font: 12px ui-monospace, monospace; color: #a99fc2; white-space: pre; }
small { color: #a99fc2; }
</style>
<canvas id="c" width="1654" height="1168" style="width:1240px;height:876px"></canvas>
<div id="side">
  <b>Dream Bed room</b>
  <small>Click or pick a piece. Drag to move, wheel to size, arrows to nudge, Q/E or alt+wheel to tilt, W/S to stretch/squash (shift: more). Hidden pieces still save.</small>
  <div class="row"><button id="night">Night</button><button id="day">Morning</button></div>
  <div id="list"></div>
  <div id="info"></div>
  <button id="save">Save layout</button>
  <small id="msg"></small>
</div>
<script>
const W = 1654, H = 1168, c = document.getElementById("c"), x = c.getContext("2d");
const ORDER = ${JSON.stringify(ORDER)};
let L, B, sel = null, mode = "night", drag = null, imgs = {}, room, floor, ogres = {}, roomFloor = 0.6;
const PANEL = 0.035;  // (the panel strip stretched: this much of the room above its painted floor line)
function DrawRoom() {
  const fx = (W / H) / (room.width / room.height), sx = (1 - fx) / 2 * room.width, sw = fx * room.width, P = roomFloor - PANEL;
  x.drawImage(room, sx, 0, sw, P * room.height, 0, 0, W, P * H);
  x.drawImage(room, sx, P * room.height, sw, PANEL * room.height, 0, P * H, W, (L.wall.floor - P) * H);
}
const load = (src) => new Promise((r, no) => { const i = new Image(); i.onload = () => r(i); i.onerror = no; i.src = src; });
async function start() {
  L = await (await fetch("/layout")).json(); B = await (await fetch("/boxes")).json(); L.floor = L.floor || { x: 0, y: 0, zoom: 1 };
  room = await load("/piece/room.png"); floor = await load("/piece/floor.png").catch(() => null);
  { // (where the room's painted wall ends: the first row that's see-through across the page)
    const cv = document.createElement("canvas"); cv.width = room.width; cv.height = room.height;
    const g = cv.getContext("2d"); g.drawImage(room, 0, 0); const d = g.getImageData(0, 0, room.width, room.height).data;
    let y = Math.floor(room.height * 0.4);
    for (; y < room.height; y++) { let clear = true; for (let k = 1; k < 10; k++) if (d[(y * room.width + Math.floor(room.width * k / 10)) * 4 + 3] > 20) clear = false; if (clear) break; }
    roomFloor = y / room.height;
  }
  L.wall = L.wall || { floor: roomFloor };
  for (const n of ORDER) if (B[n]) imgs[n] = await load("/piece/" + n + ".png");
  ogres.night = await load("/ogre.png?awake=0"); ogres.day = await load("/ogre.png?awake=1");
  list(); draw();
}
// A piece's rectangle on the canvas (px), from its spec.
function rect(n) {
  const s = L[n] || {};
  if (n === "floor") { const z = s.zoom || 1; return { x: W / 2 - W * z / 2 + (s.x || 0) * W, y: H / 2 - H * z / 2 + (s.y || 0) * H, w: W * z, h: H * z }; }
  if (n === "head") { const S = s.size * H; return { x: s.x * W, y: s.top * H, w: S, h: S }; }
  if (n === "jarfront") return rect("jar");
  if (n === "flame") { const cr = rect("candle"), b = B.flame, fw = s.w * W, fh = fw * b.h / b.w; return { x: cr.x + cr.w * s.dx - fw / 2, y: cr.y - fh * s.dy, w: fw, h: fh }; }
  const b = B[n], w = s.w * W, h = w * b.h / b.w * (s.flat || 1);
  return { x: s.x * W, y: s.top !== undefined ? s.top * H : s.bottom * H - h, w, h };
}
function draw() {
  x.clearRect(0, 0, W, H);
  // (the sky in the window, then the room over it)
  const fx = (W / H) / (room.width / room.height), left = (1 - fx) / 2;
  x.fillStyle = mode === "night" ? "#141d5a" : "#9ad0ff"; x.fillRect(0, 0, W, H);
  if (mode === "night") { x.fillStyle = "#f6f0c8"; x.beginPath(); x.arc(W * 0.21, H * 0.15, 30, 0, 7); x.fill(); }
  if (floor) {
    const ff = (W / H) / (floor.width / floor.height), r = rect("floor");
    x.save(); x.beginPath(); x.rect(0, H / 2, W, H / 2); x.clip();
    x.drawImage(floor, (1 - ff) / 2 * floor.width, 0, ff * floor.width, floor.height, r.x, r.y, r.w, r.h);
    x.restore();
  }
  for (const n of ORDER) {
    if (n === "flame" && mode !== "night") continue;
    if (n === "rug") DrawRoom();
    if (n !== "head" && !imgs[n]) continue;  // (not painted yet)
    const r = rect(n), rot = (L[n] && L[n].rot) || 0;
    x.save();
    if (rot) { x.translate(r.x + r.w / 2, r.y + r.h / 2); x.rotate(rot * Math.PI / 180); x.translate(-(r.x + r.w / 2), -(r.y + r.h / 2)); }
    if (n === "head") {  // (tinted to the room's light, as the game does: the candle's at night, the sun's in the morning)
      x.filter = mode === "night" ? "brightness(.78) sepia(.25) saturate(1.1)" : "brightness(1.02) sepia(.12)";
      x.drawImage(ogres[mode], r.x, r.y, r.w, r.h);
      x.filter = "none";
    }
    else { const b = B[n === "jarfront" ? "jar" : n], i = imgs[n]; x.drawImage(i, b.x * i.width, b.y * i.height, b.w * i.width, b.h * i.height, r.x, r.y, r.w, r.h); }
    if (n === "flame") {
      const g = x.createRadialGradient(r.x + r.w / 2, r.y + r.h, 0, r.x + r.w / 2, r.y + r.h, W * 0.16);
      g.addColorStop(0, "rgba(255,170,80,.45)"); g.addColorStop(1, "rgba(255,170,80,0)");
      x.globalCompositeOperation = "lighter"; x.fillStyle = g; x.fillRect(0, 0, W, H); x.globalCompositeOperation = "source-over";
    }
    x.restore();
    if (n === sel) { x.strokeStyle = "#ffcf4a"; x.lineWidth = 3; x.setLineDash([10, 6]); x.strokeRect(r.x, r.y, r.w, r.h); x.setLineDash([]); }
  }
  if (sel === "wall") { x.strokeStyle = "#ffcf4a"; x.lineWidth = 3; x.setLineDash([10, 6]); x.beginPath(); x.moveTo(0, L.wall.floor * H); x.lineTo(W, L.wall.floor * H); x.stroke(); x.setLineDash([]); }
  if (sel === "floor") { x.strokeStyle = "#ffcf4a"; x.lineWidth = 3; x.setLineDash([10, 6]); x.strokeRect(2, L.wall.floor * H, W - 4, (1 - L.wall.floor) * H - 2); x.setLineDash([]); }
  if (mode === "night") { x.fillStyle = "rgba(8,6,26,.25)"; x.fillRect(0, 0, W, H); }
  document.getElementById("info").textContent = sel ? sel + "\\n" + JSON.stringify(L[sel], null, 1) : "";
}
function list() {
  const el = document.getElementById("list"); el.innerHTML = "";
  for (const n of ["wall", "floor", ...ORDER.filter((n) => n !== "jarfront")]) { const b = document.createElement("button"); b.textContent = n; b.className = n === sel ? "on" : ""; b.onclick = () => { sel = n; list(); draw(); }; el.appendChild(b); }
}
const at = (e) => { const r = c.getBoundingClientRect(); return { px: (e.clientX - r.left) * W / r.width, py: (e.clientY - r.top) * H / r.height }; };
c.onmousedown = (e) => {
  const { px, py } = at(e);
  let hit = false;
  for (const n of [...ORDER].reverse()) { if (n === "jarfront" || (n !== "head" && !imgs[n])) continue; const r = rect(n); if (px >= r.x && px <= r.x + r.w && py >= r.y && py <= r.y + r.h) { sel = n; hit = true; break; } }
  if (!hit) sel = py > L.wall.floor * H ? (floor ? "floor" : sel) : "wall";
  if (sel === "floor" && !L.floor) L.floor = { x: 0, y: 0, zoom: 1 };
  if (sel) drag = { px, py, spec: JSON.parse(JSON.stringify(L[sel])) };
  list(); draw();
};
window.onmousemove = (e) => {
  if (!drag) return;
  const { px, py } = at(e), dx = (px - drag.px) / W, dy = (py - drag.py) / H, s = L[sel];
  if (sel === "flame") { const cr = rect("candle"); s.dx = drag.spec.dx + (px - drag.px) / cr.w; s.dy = drag.spec.dy - (py - drag.py) / rect("flame").h; }
  else if (sel === "floor") { s.x = drag.spec.x + dx; s.y = drag.spec.y + dy; }
  else if (sel === "wall") { s.floor = Math.min(0.98, Math.max(roomFloor - PANEL + 0.01, drag.spec.floor + dy)); }
  else { s.x = drag.spec.x + dx; if (s.top !== undefined) s.top = drag.spec.top + dy; else s.bottom = drag.spec.bottom + dy; }
  draw();
};
window.onmouseup = () => { drag = null; };
c.onwheel = (e) => {
  if (!sel) return; e.preventDefault();
  if (e.altKey) { Tilt((e.deltaY < 0 ? -1 : 1) * (e.shiftKey ? 5 : 1)); return; }
  const s = L[sel], f = e.deltaY < 0 ? 1.03 : 1 / 1.03;
  if (sel === "wall") return;
  if (sel === "head") s.size *= f; else if (sel === "floor") s.zoom = Math.max(1, s.zoom * f); else s.w *= f;
  draw();
};
// Tilting (degrees, clockwise; around the piece's middle, as the game's SetRotation).
function Tilt(by) {
  const s = L[sel], rot = Math.round(((s.rot || 0) + by) * 10) / 10;
  if (rot) s.rot = rot; else delete s.rot;
  draw();
}
window.onkeydown = (e) => {
  const k = e.key.toLowerCase();
  if ((sel === "floor" || sel === "wall") && "qews".includes(k)) return;
  if (sel && sel !== "head" && (k === "w" || k === "s")) {  // (squashed or stretched, its bottom - or top - staying put)
    e.preventDefault();
    const s = L[sel], f = Math.pow(k === "s" ? 0.98 : 1 / 0.98, e.shiftKey ? 5 : 1), flat = Math.round((s.flat || 1) * f * 1000) / 1000;
    if (Math.abs(flat - 1) < 0.005) delete s.flat; else s.flat = flat;
    draw(); return;
  }
  if (sel && (k === "q" || k === "e")) { e.preventDefault(); Tilt((k === "q" ? -1 : 1) * (e.shiftKey ? 5 : 1)); return; }
  if (!sel || !e.key.startsWith("Arrow")) return;
  e.preventDefault();
  const s = L[sel], step = (e.shiftKey ? 10 : 1) / W;
  if (sel === "flame") { if (e.key === "ArrowLeft") s.dx -= 0.02; if (e.key === "ArrowRight") s.dx += 0.02; if (e.key === "ArrowUp") s.dy += 0.02; if (e.key === "ArrowDown") s.dy -= 0.02; }
  else {
    if (e.key === "ArrowLeft") s.x -= step; if (e.key === "ArrowRight") s.x += step;
    const vy = (e.shiftKey ? 10 : 1) / H * (e.key === "ArrowUp" ? -1 : e.key === "ArrowDown" ? 1 : 0);
    if (s.top !== undefined) s.top += vy; else if (s.bottom !== undefined) s.bottom += vy; else if (sel === "floor") s.y += vy; else if (sel === "wall") s.floor += vy;
  }
  draw();
};
document.getElementById("night").onclick = () => { mode = "night"; draw(); };
document.getElementById("day").onclick = () => { mode = "day"; draw(); };
document.getElementById("save").onclick = async () => {
  const round = (o) => { for (const k in o) if (typeof o[k] === "number") o[k] = Math.round(o[k] * 10000) / 10000; return o; };
  for (const n in L) round(L[n]);
  const res = await fetch("/layout", { method: "POST", body: JSON.stringify(L, null, 1) });
  document.getElementById("msg").textContent = res.ok ? "Saved " + new Date().toLocaleTimeString() : "Couldn't save";
};
start();
</script>`;

http.createServer((req, res) => {
  const url = new URL(req.url, "http://localhost");
  const send = (type, body) => { res.writeHead(200, { "Content-Type": type, "Cache-Control": "no-store" }); res.end(body); };
  if (url.pathname === "/") return send("text/html; charset=utf-8", PAGE);
  if (url.pathname === "/layout" && req.method === "GET") return send("application/json", fs.readFileSync(LAYOUT));
  if (url.pathname === "/layout" && req.method === "POST") {
    let body = "";
    req.on("data", (d) => { body += d; });
    req.on("end", () => {
      try { JSON.parse(body); fs.writeFileSync(LAYOUT, body); send("text/plain", "ok"); }
      catch (e) { res.writeHead(400); res.end("bad layout"); }
    });
    return;
  }
  if (url.pathname === "/boxes") return send("application/json", JSON.stringify(Boxes()));
  if (url.pathname === "/ogre.png") return send("image/png", Ogre(url.searchParams.get("awake") === "1"));
  const m = url.pathname.match(/^\/piece\/([\w-]+)\.png$/);
  if (m && fs.existsSync(path.join(PIECES, m[1] + ".png"))) return send("image/png", fs.readFileSync(path.join(PIECES, m[1] + ".png")));
  res.writeHead(404); res.end();
}).listen(PORT, () => console.log(`Dream Bed room: http://localhost:${PORT}`));
