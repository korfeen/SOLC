// Mockup of the ogre run game (Vampire Survivors-like) on an angled Paper Mario stage: the ogres are paper cutouts of
// their pictures standing on the floor, the stage's painting stands at the back. Your ogre's painted picture is the
// square on the left and changes as you pick pieces (pick 3 on level-up, from tools/gear.json); on the field you're
// the crayon twin (C toggles painted). Foes are painted ogres in creature costumes.
// Run: node tools/dreamrun-mock.js   (opens http://localhost:5185; page: tools/dreamrun-mock.html)
const http = require("http");
const fs = require("fs");
const os = require("os");
const path = require("path");
const { exec } = require("child_process");

const PORT = 5185;
const HOME = os.homedir();
const GEAR = path.join(__dirname, "gear.json");
const PAGE = path.join(__dirname, "dreamrun-mock.html");
// (the rooms' painted props - gravestones and the like, tools/gen-arcade-props.js)
const PROPS = path.join(HOME, "killtracker-art-extra", "Arcade", "props");
const GEN = { painted: path.join(HOME, "killtracker-art-extra", "Unlocks", "generated", "painted"), crayon: path.join(HOME, "killtracker-art-extra", "Unlocks", "generated", "crayon") };
const BASE = { painted: path.join(HOME, "killtracker-art"), crayon: path.join(HOME, "killtracker-art-extra", "CrayonHand") };
const FOLDER = { accessory: "Accessory", background: "Background", expression: "Expression", eyes: "Eyes", headwear: "Headwear", outfit: "Outfit", skin: "Skin" };
const PER_SKIN = { eyes: true, expression: true };
const kebab = (s) => s.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");
const pieces = JSON.parse(fs.readFileSync(GEAR, "utf8")).pieces;

// A layer's picture in an edition: the generated piece (gacha ones without their prefix), else the base art by name
// (eyes and mouths in the skin's own folder). Hooded onesies (crit_<kind>_suit) are only generated.
function layerFile(ed, id, skin) {
  const gen = [path.join(GEN[ed], id + ".png"), path.join(GEN[ed], id.replace(/^gacha_/, "") + ".png")];
  const p = pieces[id];
  if (!p) return gen.find((f) => fs.existsSync(f));
  const dir = path.join(BASE[ed], FOLDER[p.layer], p.rarity[0].toUpperCase() + p.rarity.slice(1));
  const name = kebab(p.name) + ".png";
  const base = PER_SKIN[p.layer] ? [path.join(dir, kebab(skin || "moss"), name), path.join(dir, "moss", name), path.join(dir, name)] : [path.join(dir, name)];
  return gen.concat(base).find((f) => fs.existsSync(f));
}
// What can be offered: built pieces with a painted picture (and whether there's a crayon twin), on the moss skin.
const pool = [];
for (const [id, p] of Object.entries(pieces)) {
  if (p.pending || !["headwear", "outfit", "accessory", "eyes", "expression"].includes(p.layer)) continue;
  if (!layerFile("painted", id, "moss")) continue;
  pool.push({ id, crayon: !!layerFile("crayon", id, "moss") });
}

const server = http.createServer((req, res) => {
  const url = new URL(req.url, "http://localhost");
  const send = (type, body, code = 200) => { res.writeHead(code, { "Content-Type": type }); res.end(body); };
  if (url.pathname === "/") return send("text/html; charset=utf-8", fs.readFileSync(PAGE));
  // (gen: every painted piece on disk, built or not - the arcade's new mob costumes and set accessories show as soon as they're painted)
  if (url.pathname === "/data.json") return send("application/json", JSON.stringify({ gear: JSON.parse(fs.readFileSync(GEAR, "utf8")), pool,
    arcade: JSON.parse(fs.readFileSync(path.join(__dirname, "arcade-stages.json"), "utf8")),
    gen: fs.readdirSync(GEN.painted).filter((f) => f.endsWith(".png")).map((f) => f.slice(0, -4)),
    props: fs.existsSync(PROPS) ? fs.readdirSync(PROPS).filter((f) => f.endsWith(".png")).map((f) => f.slice(0, -4)) : [] }));
  // (props: painted, or their crayon twins - tools/make-crayon-props.js; floors: tools/make-arcade-floors.js)
  const pm = url.pathname.match(/^\/(prop|prop\/crayon|floor)\/([\w-]+)\.png$/);
  const pf = pm && path.join(pm[1] === "floor" ? path.join(PROPS, "..", "floors") : pm[1] === "prop" ? PROPS : path.join(PROPS, "crayon"), pm[2] + ".png");
  if (pf && fs.existsSync(pf)) {
    res.writeHead(200, { "Content-Type": "image/png", "Cache-Control": "no-cache" });
    return fs.createReadStream(pf).pipe(res);
  }
  const m = url.pathname.match(/^\/art\/(painted|crayon)\/([\w-]+)\.png$/);
  if (m) {
    const file = layerFile(m[1], m[2], url.searchParams.get("skin") ? (pieces[url.searchParams.get("skin")] || {}).name : "moss");
    if (!file) return send("text/plain", "no art", 404);
    res.writeHead(200, { "Content-Type": "image/png", "Cache-Control": "max-age=3600" });
    return fs.createReadStream(file).pipe(res);
  }
  send("text/plain", "", 404);
});
server.listen(PORT, "127.0.0.1", () => {
  const url = `http://localhost:${PORT}`;
  console.log(`Run mockup: ${url}  (${pool.length} pieces to pick from; Ctrl+C here to stop)`);
  if (!process.env.NO_OPEN) exec(`start "" "${url}"`);
});
