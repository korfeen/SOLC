// A small painter for the head mask (make-unlock-art.js: what of an outfit goes behind the ogre's head):
//   node tools/mask-painter.js
// opens http://localhost:5179 with the moss ogre and the current mask (head-mask.png, else the oval) over it. Paint the
// head (left mouse), erase (right mouse or Erase), change the brush size (mouse wheel or the slider), Save: it's written
// to %USERPROFILE%\killtracker-art\head-mask.png (white = head). Ctrl+Z undoes. Plain Node, no packages.

const http = require("http");
const fs = require("fs");
const os = require("os");
const path = require("path");
const { exec } = require("child_process");
const { decodePng } = require("./convert-art");
const { writePng } = require("./make-role-icons");

const ART = path.join(os.homedir(), "killtracker-art");
const MASK = path.join(ART, "head-mask.png");
const SIZE = 1254, PORT = 5179;

// The ogre to paint over: the moss skin with a face, as a PNG.
function ogrePng() {
  const pic = Buffer.alloc(SIZE * SIZE * 4);
  for (let i = 0; i < pic.length; i += 4) pic.set([40, 32, 40, 255], i);
  for (const rel of ["Skin/Uncommon/moss.png", "Expression/Uncommon/moss/smug-smile.png", "Eyes/Uncommon/moss/heavy-bags.png"]) {
    const file = path.join(ART, rel);
    if (!fs.existsSync(file)) continue;
    const r = decodePng(file).rgba;
    for (let i = 0; i < pic.length; i += 4) {
      const a = r[i + 3] / 255;
      for (let k = 0; k < 3; k++) pic[i + k] = Math.round(r[i + k] * a + pic[i + k] * (1 - a));
    }
  }
  // Every expression's outline in yellow (all skins'): the mask should cover the lowest chin.
  const union = new Uint8Array(SIZE * SIZE);
  const walk = (dir) => { for (const e of fs.existsSync(dir) ? fs.readdirSync(dir, { withFileTypes: true }) : []) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p);
    else if (/.png$/i.test(e.name)) { const r = decodePng(p).rgba; for (let i = 0; i < union.length; i++) if (r[i * 4 + 3] > 60) union[i] = 1; }
  } };
  walk(path.join(ART, "Expression"));
  const on = (x, y) => x >= 0 && y >= 0 && x < SIZE && y < SIZE && union[y * SIZE + x];
  for (let y = 0; y < SIZE; y++) for (let x = 0; x < SIZE; x++) {
    if (on(x, y) && (!on(x - 1, y) || !on(x + 1, y) || !on(x, y - 1) || !on(x, y + 1))) pic.set([255, 215, 30, 255], (y * SIZE + x) * 4);
  }
  const tmp = path.join(os.tmpdir(), "solc-mask-ogre.png");
  writePng(tmp, SIZE, SIZE, pic);
  return fs.readFileSync(tmp);
}
// The current mask: the saved one, else the build's oval (inside the skin).
function maskPng() {
  if (fs.existsSync(MASK)) return fs.readFileSync(MASK);
  const skin = decodePng(path.join(ART, "Skin/Uncommon/moss.png")).rgba;
  const m = Buffer.alloc(SIZE * SIZE * 4);
  for (let y = 0; y < SIZE; y++) for (let x = 0; x < SIZE; x++) {
    const i = (y * SIZE + x) * 4;
    const ex = (x - 630) / 190, ey = (y - 285) / 128;
    const head = y < 440 && skin[i + 3] > 60 && ((y < 330 && Math.abs(x - 630) < 240) || ex * ex + ey * ey <= 1);
    const v = head ? 255 : 0;
    m.set([v, v, v, 255], i);
  }
  const tmp = path.join(os.tmpdir(), "solc-mask-start.png");
  writePng(tmp, SIZE, SIZE, m);
  return fs.readFileSync(tmp);
}

const PAGE = `<!doctype html><meta charset="utf-8"><title>Head Mask</title>
<style>
body { margin: 0; background: #1a1410; color: #eee0c7; font: 14px system-ui, sans-serif; display: flex; flex-direction: column; height: 100vh; }
.bar { display: flex; gap: 14px; align-items: center; padding: 8px 12px; background: #2a1e14; flex-wrap: wrap; }
button { background: #4a3320; color: #eee0c7; border: 1px solid #8a6a3a; border-radius: 4px; padding: 5px 12px; cursor: pointer; font: inherit; }
button.on { background: #8a6a3a; color: #fff; }
#save { background: #3f6b2a; border-color: #6fa04a; }
.wrap { flex: 1; overflow: auto; }
.wrap canvas { display: block; margin: 20px auto; }
canvas { image-rendering: auto; cursor: none; }
#msg { color: #ffd21a; }
</style>
<div class="bar">
  <button id="paint" class="on">Paint head (left)</button><button id="erase">Erase (right)</button>
  <label>Brush <input id="size" type="range" min="2" max="120" value="24"> <span id="sizeV">24</span></label>
  <label>Mask <input id="alpha" type="range" min="0" max="100" value="45"></label>
  <label>Zoom <input id="zoom" type="range" min="40" max="800" value="70"> <span id="zoomV">70%</span></label>
  <span style="color:#9e8f7a">Ctrl+wheel: zoom · middle mouse or Space+drag: move</span>
  <button id="undo">Undo (Ctrl+Z)</button><button id="save">Save</button><span id="msg"></span>
</div>
<div class="wrap"><canvas id="view" width="${SIZE}" height="${SIZE}"></canvas></div>
<script>
const S = ${SIZE};
const view = document.getElementById("view"), vx = view.getContext("2d");
const mask = document.createElement("canvas"); mask.width = mask.height = S; const mx = mask.getContext("2d");
const ogre = new Image(), start = new Image();
let mode = "paint", size = 24, alpha = 0.45, down = 0, cursor = null;
const undo = [];
function draw() {
  vx.globalAlpha = 1; vx.globalCompositeOperation = "source-over";
  vx.drawImage(ogre, 0, 0);
  // the mask as a red tint where it's head
  const tint = document.createElement("canvas"); tint.width = tint.height = S; const tx = tint.getContext("2d");
  tx.drawImage(mask, 0, 0); tx.globalCompositeOperation = "multiply"; tx.fillStyle = "#ff0000"; tx.fillRect(0, 0, S, S);
  tx.globalCompositeOperation = "destination-in"; tx.drawImage(maskAlpha(), 0, 0);
  vx.globalAlpha = alpha; vx.drawImage(tint, 0, 0); vx.globalAlpha = 1;
  if (cursor) { vx.strokeStyle = mode === "paint" ? "#ffd21a" : "#66ccff"; vx.lineWidth = 2; vx.beginPath(); vx.arc(cursor.x, cursor.y, size / 2, 0, Math.PI * 2); vx.stroke(); }
}
// the mask's white as alpha
let alphaCanvas = null;
function maskAlpha() {
  alphaCanvas = alphaCanvas || document.createElement("canvas"); alphaCanvas.width = alphaCanvas.height = S;
  const ax = alphaCanvas.getContext("2d"); const d = mx.getImageData(0, 0, S, S);
  for (let i = 0; i < d.data.length; i += 4) { d.data[i + 3] = d.data[i]; }
  ax.putImageData(d, 0, 0); return alphaCanvas;
}
function at(e) { const r = view.getBoundingClientRect(); return { x: (e.clientX - r.left) * S / r.width, y: (e.clientY - r.top) * S / r.height }; }
function dab(p, m) {
  mx.fillStyle = m === "paint" ? "#fff" : "#000"; mx.beginPath(); mx.arc(p.x, p.y, size / 2, 0, Math.PI * 2); mx.fill();
}
let last = null;
view.addEventListener("contextmenu", (e) => e.preventDefault());
view.addEventListener("pointerdown", (e) => {
  if (e.button === 1 || space) return;
  down = e.button === 2 ? 2 : 1; undo.push(mx.getImageData(0, 0, S, S)); if (undo.length > 30) undo.shift();
  last = at(e); dab(last, down === 2 ? "erase" : mode); draw();
});
window.addEventListener("pointerup", () => { down = 0; last = null; });
view.addEventListener("pointermove", (e) => {
  cursor = at(e);
  if (down) {
    const p = cursor, m = down === 2 ? "erase" : mode, steps = Math.max(1, Math.ceil(Math.hypot(p.x - last.x, p.y - last.y) / (size / 4)));
    for (let i = 1; i <= steps; i++) dab({ x: last.x + (p.x - last.x) * i / steps, y: last.y + (p.y - last.y) * i / steps }, m);
    last = p;
  }
  draw();
});
view.addEventListener("pointerleave", () => { cursor = null; draw(); });
const wrap = document.querySelector(".wrap");
let zoom = 0.7, space = false, pan = null;
// Zoom towards the cursor: the point under it stays under it.
function setZoom(z, e) {
  z = Math.max(0.4, Math.min(8, z));
  const r = view.getBoundingClientRect();
  const fx = e ? (e.clientX - r.left) / r.width : 0.5, fy = e ? (e.clientY - r.top) / r.height : 0.5;
  const before = { x: e ? e.clientX : 0, y: e ? e.clientY : 0 };
  zoom = z;
  view.style.width = (S * zoom) + "px";
  document.getElementById("zoom").value = Math.round(zoom * 100);
  document.getElementById("zoomV").textContent = Math.round(zoom * 100) + "%";
  if (e) {
    const r2 = view.getBoundingClientRect();
    wrap.scrollLeft += r2.left + fx * r2.width - before.x;
    wrap.scrollTop += r2.top + fy * r2.height - before.y;
  }
}
view.addEventListener("wheel", (e) => {
  e.preventDefault();
  if (e.ctrlKey) setZoom(zoom * (e.deltaY < 0 ? 1.15 : 1 / 1.15), e);
  else { setSize(size + (e.deltaY < 0 ? 4 : -4)); draw(); }
}, { passive: false });
window.addEventListener("keydown", (e) => { if (e.code === "Space") { space = true; e.preventDefault(); } });
window.addEventListener("keyup", (e) => { if (e.code === "Space") space = false; });
wrap.addEventListener("pointerdown", (e) => {
  if (e.button === 1 || space) { e.preventDefault(); e.stopPropagation(); pan = { x: e.clientX, y: e.clientY, l: wrap.scrollLeft, t: wrap.scrollTop }; }
}, true);
window.addEventListener("pointermove", (e) => { if (pan) { wrap.scrollLeft = pan.l - (e.clientX - pan.x); wrap.scrollTop = pan.t - (e.clientY - pan.y); } });
window.addEventListener("pointerup", () => { pan = null; });
function setSize(v) { size = Math.max(2, Math.min(120, v)); document.getElementById("size").value = size; document.getElementById("sizeV").textContent = size; }
document.getElementById("size").oninput = (e) => setSize(+e.target.value);
document.getElementById("alpha").oninput = (e) => { alpha = e.target.value / 100; draw(); };
document.getElementById("zoom").oninput = (e) => setZoom(e.target.value / 100);
setZoom(0.7);
for (const id of ["paint", "erase"]) document.getElementById(id).onclick = () => {
  mode = id; document.getElementById("paint").classList.toggle("on", id === "paint"); document.getElementById("erase").classList.toggle("on", id === "erase");
};
function doUndo() { const d = undo.pop(); if (d) { mx.putImageData(d, 0, 0); draw(); } }
document.getElementById("undo").onclick = doUndo;
window.addEventListener("keydown", (e) => { if ((e.ctrlKey || e.metaKey) && e.key === "z") { e.preventDefault(); doUndo(); } });
document.getElementById("save").onclick = async () => {
  const msg = document.getElementById("msg"); msg.textContent = "Saving...";
  const blob = await new Promise((r) => mask.toBlob(r, "image/png"));
  const res = await fetch("/save", { method: "POST", body: blob });
  msg.textContent = res.ok ? "Saved: " + (await res.text()) : "Couldn't save: " + res.status;
};
let loaded = 0;
function ready() { if (++loaded < 2) return; mx.drawImage(start, 0, 0); draw(); }
ogre.onload = ready; start.onload = ready;
ogre.src = "/ogre.png"; start.src = "/mask.png?" + Date.now();
</script>`;

const server = http.createServer((req, res) => {
  if (req.method === "GET" && req.url === "/") { res.writeHead(200, { "Content-Type": "text/html" }); return res.end(PAGE); }
  if (req.method === "GET" && req.url === "/ogre.png") { res.writeHead(200, { "Content-Type": "image/png" }); return res.end(ogrePng()); }
  if (req.method === "GET" && req.url.startsWith("/mask.png")) { res.writeHead(200, { "Content-Type": "image/png" }); return res.end(maskPng()); }
  if (req.method === "POST" && req.url === "/save") {
    const chunks = [];
    req.on("data", (c) => chunks.push(c));
    req.on("end", () => {
      fs.writeFileSync(MASK, Buffer.concat(chunks));
      console.log("Saved " + MASK);
      res.writeHead(200, { "Content-Type": "text/plain" });
      res.end(MASK);
    });
    return;
  }
  res.writeHead(404);
  res.end();
});
server.listen(PORT, "127.0.0.1", () => {
  const url = `http://localhost:${PORT}`;
  console.log(`Head mask painter: ${url}  (Ctrl+C here to stop)`);
  exec(`start "" "${url}"`);
});
