// Prints what the rank panel's rows say (Ranks.lua's ns.RankPerksLine / RankPerksAfter) with MintArt.lua's names.
const fs = require("fs");
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require("C:/Users/faluk/Projects/solc-activity/node_modules/fengari");
const L = lauxlib.luaL_newstate(); lualib.luaL_openlibs(L);
const run = (code, name) => { if (lauxlib.luaL_loadbuffer(L, to_luastring(code), null, to_luastring(name)) || lua.lua_pcall(L, 0, 0, 0)) throw Error(to_jsstring(lua.lua_tostring(L, -1))); };
run(`ns = { RARITY_COLORS = { epic = "ffa335ee", legendary = "ffff8000" }, KillHandlers = {}, UI = {} }
  CreateFrame = function() return setmetatable({}, { __index = function() return function() end end }) end
  wipe = function(t) for k in pairs(t) do t[k] = nil end return t end`, "stubs");
for (const f of ["MintArt.lua", "Ranks.lua"]) run(`local f = assert(load(${JSON.stringify(fs.readFileSync(f, "utf8"))}, "${f}")) f("SOLC", ns)`, f);
run(`function ns.OptionByKey(key)
    local l, id = key:match("^(%w+):(.+)$")
    for _, o in ipairs(ns.MintArt[l] or {}) do if o.id == id then return { option = o } end end
  end
  for r = 1, 30 do local s = ns.RankPerksLine(r) if s then print(("rank %2d  %s"):format(r, (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")))) end end
  print(ns.RankPerksAfter(8))`, "check");
