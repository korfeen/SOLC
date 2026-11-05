// Checks the rank pieces: the changed Lua files compile, every "piece" perk in Ranks.lua is a MintArt option with the
// same "rank:<n>" unlock (and back), and no epic or legendary is free any more.
const fs = require("fs");
const { lauxlib, lualib, to_luastring, to_jsstring, lua } = require("C:/Users/faluk/Projects/solc-activity/node_modules/fengari");
for (const f of ["Ranks.lua", "Minting.lua", "MintArt.lua", "ProfileHeader.lua"]) {
  const L = lauxlib.luaL_newstate();
  if (lauxlib.luaL_loadbuffer(L, to_luastring(fs.readFileSync(f, "utf8")), null, to_luastring(f))) throw Error(to_jsstring(lua.lua_tostring(L, -1)));
}
const { options } = require("../tools/render-picture.js").loadArt();
const perks = [...fs.readFileSync("Ranks.lua", "utf8").matchAll(/rank = (\d+), kind = "piece", key = "(\w+):(\w+)"/g)];
let bad = 0;
for (const [, rank, layer, id] of perks) {
  const o = options[layer][id];
  if (!o || o.unlock !== "rank:" + rank) { console.log("mismatch", layer, id, rank, o && o.unlock); bad++; }
}
for (const [layer, os] of Object.entries(options)) for (const o of Object.values(os)) {
  if (o.retired) continue;
  if (o.unlock?.startsWith("rank:") && !perks.some((p) => p[2] === layer && p[3] === o.id)) { console.log("no perk", layer, o.id); bad++; }
  if (!o.unlock && (o.rarity === "epic" || o.rarity === "legendary")) { console.log("still free", layer, o.id); bad++; }
}
const free = {};
for (const [layer, os] of Object.entries(options)) free[layer] = Object.values(os).filter((o) => !o.unlock && !o.retired).map((o) => o.rarity[0]).join("");
console.log(perks.length, "piece perks;", bad ? bad + " problems" : "all match"); console.log("free per layer:", free);
