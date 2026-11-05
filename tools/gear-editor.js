// The gear editor: a local page over tools/gear.json (the ogre run game's sets, attacks and stats, seeded by
// tools/gear-seed.js). Every set as a row of its layers (Hat, Outfit, Weapon, Eyes, Mouth, then Skin and Stage), so the
// gaps show; drag pieces between sets and the loose tray, add wanted pieces to a gap (the to-paint list), rename,
// merge, make and delete sets, and change a piece's attack, variant, twist and stats. Save writes gear.json and reruns
// the seed (it keeps everything changed here, marked "edited", and works the set bonuses out again).
// Run: node tools/gear-editor.js   (opens http://localhost:5184)
const http = require("http");
const fs = require("fs");
const os = require("os");
const path = require("path");
const { exec, execFileSync } = require("child_process");

const PORT = 5184;
const GEAR = path.join(__dirname, "gear.json");
const PAGE = path.join(__dirname, "gear-editor.html");
const ART = path.join(os.homedir(), "killtracker-art");
const PAINTED = path.join(os.homedir(), "killtracker-art-extra", "Unlocks", "generated", "painted");
const FOLDER = { accessory: "Accessory", background: "Background", expression: "Expression", eyes: "Eyes", headwear: "Headwear", outfit: "Outfit", skin: "Skin" };

// A piece's picture: the generated piece (painted\<id>.png, gacha ones without their gacha_ prefix), else the base
// art by name (killtracker-art\<Layer>\<Rarity>\<name>.png, eyes and mouths in the moss skin).
const kebab = (s) => s.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");
function artFile(id, p) {
  const rarity = p.rarity[0].toUpperCase() + p.rarity.slice(1), dir = path.join(ART, FOLDER[p.layer] || "", rarity);
  const tries = [path.join(PAINTED, id + ".png"), path.join(PAINTED, id.replace(/^gacha_/, "") + ".png"),
    path.join(dir, kebab(p.name) + ".png"), path.join(dir, "moss", kebab(p.name) + ".png"), path.join(dir, kebab(id) + ".png")];
  return tries.find((f) => fs.existsSync(f));
}

let pieces = null, piecesTime = 0;
function piecesNow() {
  const t = fs.statSync(GEAR).mtimeMs;
  if (t !== piecesTime) { pieces = JSON.parse(fs.readFileSync(GEAR, "utf8")).pieces; piecesTime = t; }
  return pieces;
}

const server = http.createServer((req, res) => {
  const url = new URL(req.url, "http://localhost");
  const send = (type, body, code = 200) => { res.writeHead(code, { "Content-Type": type, "Cache-Control": "no-store" }); res.end(body); };
  if (url.pathname === "/") return send("text/html; charset=utf-8", fs.readFileSync(PAGE));
  if (url.pathname === "/gear.json") return send("application/json", fs.readFileSync(GEAR));
  // the arcade's mobs (a look at arcade-stages.json; tools/arcade-mobs.js writes them)
  if (url.pathname === "/mobs") return send("text/html; charset=utf-8", fs.readFileSync(path.join(__dirname, "gear-editor-mobs.html")));
  if (url.pathname === "/arcade.json") return send("application/json", fs.readFileSync(path.join(__dirname, "arcade-stages.json")));
  const art = url.pathname.match(/^\/art\/([\w-]+)\.png$/);
  if (art) {
    const p = piecesNow()[art[1]];
    const file = p && artFile(art[1], p);
    if (!file) return send("text/plain", "no art", 404);
    res.writeHead(200, { "Content-Type": "image/png", "Cache-Control": "max-age=3600" });
    return fs.createReadStream(file).pipe(res);
  }
  if (url.pathname === "/save" && req.method === "POST") {
    let body = "";
    req.on("data", (c) => { body += c; });
    req.on("end", () => {
      try {
        const doc = JSON.parse(body);
        if (!doc.pieces || !doc.sets) throw new Error("not a gear doc");
        fs.writeFileSync(GEAR, JSON.stringify(doc));
        const out = execFileSync(process.execPath, [path.join(__dirname, "gear-seed.js")], { encoding: "utf8" });
        console.log("Saved.\n" + out);
        send("application/json", fs.readFileSync(GEAR));
      } catch (err) {
        console.error("Couldn't save:", err.message);
        send("text/plain", err.message, 500);
      }
    });
    return;
  }
  send("text/plain", "", 404);
});
server.listen(PORT, "127.0.0.1", () => {
  const url = `http://localhost:${PORT}`;
  console.log(`Gear editor: ${url}  (Ctrl+C here to stop)`);
  if (!process.env.NO_OPEN) exec(`start "" "${url}"`);
});
