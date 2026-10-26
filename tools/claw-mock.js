// The gacha claw machine, as a local playable mockup: one capsule per Series 1 piece (tools/gacha-series1-picks.json),
// a claw you steer and drop, smashes that scramble the pile (each one riskier: TILT loses the go and drains the grip
// meter), and the grip meter that fills on every lost go. Sliders on the page tune the numbers while you play.
// A 3D version (two-step claw, fixed angled or top view) at /3d (tools/claw-mock-3d.html).
// Run: node tools/claw-mock.js   then open http://localhost:5183
const http = require("http");
const fs = require("fs");
const path = require("path");

const PORT = 5183;
const PAGE = path.join(__dirname, "claw-mock.html");

function pieces() {
  const all = JSON.parse(fs.readFileSync(path.join(__dirname, "gacha-series1-candidates.json"), "utf8"));
  const picked = new Set(JSON.parse(fs.readFileSync(path.join(__dirname, "gacha-series1-picks.json"), "utf8")).picked);
  return all.filter((p) => picked.has(p.id)).map(({ id, name, rarity, layer }) => ({ id, name, rarity, layer }));
}

http.createServer((req, res) => {
  const send = (type, body) => { res.writeHead(200, { "Content-Type": type, "Cache-Control": "no-store" }); res.end(body); };
  const url = req.url.split("?")[0];
  if (url === "/") return send("text/html; charset=utf-8", fs.readFileSync(PAGE, "utf8"));  // (read each time: edit and reload)
  if (url === "/3d") return send("text/html; charset=utf-8", fs.readFileSync(path.join(__dirname, "claw-mock-3d.html"), "utf8"));
  if (url === "/pieces") return send("application/json", JSON.stringify(pieces()));
  res.writeHead(404); res.end();
}).listen(PORT, () => console.log(`Claw machine mockup: http://localhost:${PORT}`));
