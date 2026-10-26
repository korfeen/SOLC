// The gacha box's Series 1 picker: a local page listing the candidate pieces (tools/gacha-series1-candidates.json) by
// theme, each with its layer, rarity and what it looks like; tick the ones to paint (about 50) and add a note to any.
// Picks are saved as you go to tools/gacha-series1-picks.json ({ picked: [ids], notes: { id: text } }), which later
// turns into a Codex queue (gen-art.js) for the ticked pieces.
// Run: node tools/gacha-picker.js   then open http://localhost:5182
const http = require("http");
const fs = require("fs");
const path = require("path");

const PORT = 5182;
const CANDIDATES = path.join(__dirname, "gacha-series1-candidates.json");
const PICKS = path.join(__dirname, "gacha-series1-picks.json");

const PAGE = `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Gacha Series 1</title>
<style>
:root{--bg:#17130f;--panel:#24180f;--line:#4a3420;--text:#efe2c6;--muted:#b9a582;--gold:#f2c14e;--velvet:#6b1a21}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--text);font:14px/1.4 Georgia,serif}
header{position:sticky;top:0;z-index:2;background:#1f150d;border-bottom:1px solid var(--line);padding:12px 16px;display:flex;flex-wrap:wrap;gap:10px 18px;align-items:center}
h1{margin:0;font-size:20px;color:var(--gold);font-weight:400}
.tally{color:var(--muted)}.tally b{color:var(--text)}
.big{font-size:18px}.big b{color:var(--gold)}
main{padding:12px 16px 40px;max-width:1200px;margin:0 auto}
h2{color:var(--gold);font-weight:400;margin:22px 0 8px;font-size:18px;border-bottom:1px solid var(--line);padding-bottom:4px}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(260px,1fr));gap:8px}
.card{background:var(--panel);border:1px solid var(--line);border-radius:6px;padding:8px 10px;cursor:pointer;display:grid;grid-template-columns:22px 1fr;gap:2px 8px}
.card.on{border-color:var(--gold);background:#33230f}
.card input[type=checkbox]{margin:3px 0 0;width:16px;height:16px;accent-color:#c9a14a}
.name{font-size:15px}.meta{font-size:12px;color:var(--muted)}.desc{grid-column:2;font-size:12.5px;color:#d8c8a8}
.note{grid-column:2;margin-top:4px;width:100%;background:#120d09;border:1px solid var(--line);color:var(--text);border-radius:4px;padding:3px 6px;font:12px Georgia,serif}
.uncommon{color:#1eff00}.rare{color:#3a9bff}.epic{color:#c070ff}.legendary{color:#ff8000}
.new{color:var(--gold);font-size:11px;border:1px solid var(--gold);border-radius:3px;padding:0 4px;margin-left:4px}
.saved{color:var(--muted);font-size:12px}
</style></head><body>
<header><h1>Gacha box: Series 1</h1><span class="big">Ticked <b id="n">0</b> / 50</span><span class="tally" id="rar"></span><span class="tally" id="lay"></span><span class="saved" id="saved"></span></header>
<main id="main"></main>
<script>
const NEW_LAYERS = { hair: 1, facial: 1 };
let items = [], picks = { picked: [], notes: {} };
const $ = (id) => document.getElementById(id);
async function load() {
  items = await (await fetch("/candidates")).json();
  picks = await (await fetch("/picks")).json();
  draw();
}
let timer;
function save() {
  clearTimeout(timer);
  $("saved").textContent = "saving...";
  timer = setTimeout(async () => {
    await fetch("/picks", { method: "POST", body: JSON.stringify(picks) });
    $("saved").textContent = "saved";
  }, 300);
}
function tally() {
  const on = new Set(picks.picked), rar = {}, lay = {};
  for (const it of items) if (on.has(it.id)) { rar[it.rarity] = (rar[it.rarity] || 0) + 1; lay[it.layer] = (lay[it.layer] || 0) + 1; }
  $("n").textContent = on.size;
  $("rar").innerHTML = ["uncommon", "rare", "epic", "legendary"].map((r) => '<span class="' + r + '">' + r + "</span> <b>" + (rar[r] || 0) + "</b>").join(" &middot; ");
  $("lay").innerHTML = Object.entries(lay).map(([k, v]) => k + " <b>" + v + "</b>").join(" &middot; ");
}
function draw() {
  const on = new Set(picks.picked), themes = [];
  for (const it of items) if (!themes.includes(it.theme)) themes.push(it.theme);
  const esc = (t) => String(t).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]);
  $("main").innerHTML = themes.map((t) => '<h2>' + esc(t) + '</h2><div class="grid">' + items.filter((it) => it.theme === t).map((it) =>
    '<label class="card' + (on.has(it.id) ? " on" : "") + '" data-id="' + it.id + '"><input type="checkbox"' + (on.has(it.id) ? " checked" : "") + '>' +
    '<span><span class="name ' + it.rarity + '">' + esc(it.name) + '</span> <span class="meta">' + it.rarity + " " + it.layer + "</span>" +
    (NEW_LAYERS[it.layer] ? '<span class="new">new layer</span>' : "") + '</span><span class="desc">' + esc(it.desc) + '</span>' +
    '<input class="note" placeholder="note (optional)" value="' + esc(picks.notes[it.id] || "") + '"></label>').join("") + "</div>").join("");
  for (const card of document.querySelectorAll(".card")) {
    const id = card.dataset.id;
    card.querySelector("input[type=checkbox]").onchange = (e) => {
      picks.picked = picks.picked.filter((x) => x !== id);
      if (e.target.checked) picks.picked.push(id);
      card.classList.toggle("on", e.target.checked);
      tally(); save();
    };
    const note = card.querySelector(".note");
    note.onclick = (e) => e.preventDefault();
    note.oninput = () => { if (note.value) picks.notes[id] = note.value; else delete picks.notes[id]; save(); };
  }
  tally();
}
load();
</script></body></html>`;

http.createServer((req, res) => {
  const send = (type, body) => { res.writeHead(200, { "Content-Type": type }); res.end(body); };
  if (req.url === "/") return send("text/html; charset=utf-8", PAGE);
  if (req.url === "/candidates") return send("application/json", fs.readFileSync(CANDIDATES, "utf8"));
  if (req.url === "/picks" && req.method === "GET") {
    return send("application/json", fs.existsSync(PICKS) ? fs.readFileSync(PICKS, "utf8") : JSON.stringify({ picked: [], notes: {} }));
  }
  if (req.url === "/picks" && req.method === "POST") {
    const chunks = [];
    req.on("data", (c) => chunks.push(c));
    req.on("end", () => {
      try {
        const picks = JSON.parse(Buffer.concat(chunks).toString());
        fs.writeFileSync(PICKS, JSON.stringify({ picked: picks.picked || [], notes: picks.notes || {} }, null, 1));
        send("text/plain", "ok");
      } catch (e) { res.writeHead(400); res.end("bad"); }
    });
    return;
  }
  res.writeHead(404); res.end();
}).listen(PORT, () => console.log(`Gacha Series 1 picker: http://localhost:${PORT}`));
