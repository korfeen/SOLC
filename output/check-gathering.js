// Gathering (LifeStats.lua): a mining cast then its loot = 1 ore (and a point), fishing loot = 1 fish, a loot window
// with no gathering cast before it = nothing, and nothing at all while gathering is Off.
const fs = require("fs");
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require("C:/Users/faluk/Projects/solc-activity/node_modules/fengari");
const L = lauxlib.luaL_newstate(); lualib.luaL_openlibs(L);
const run = (code, name) => { if (lauxlib.luaL_loadbuffer(L, to_luastring(code), null, to_luastring(name)) || lua.lua_pcall(L, 0, 0, 0)) throw Error(to_jsstring(lua.lua_tostring(L, -1))); };
run(`ns = { Touch = function() end, IsMember = function() return true end, Config = function(k) return k == "gather" and 1 or 0 end }
  KillTrackerDB = { points = {} }
  now, fishing = 100, false
  GetTime = function() return now end
  IsFishingLoot = function() return fishing end
  C_Spell = { GetSpellName = function(id) return id == 99999 and "Skinning" or "Other" end }
  frames = {}
  CreateFrame = function() local f = { events = {} } function f:RegisterEvent(e) self.events[e] = true end
    function f:RegisterUnitEvent(e) self.events[e] = true end function f:SetScript(_, fn) self.fn = fn end
    frames[#frames + 1] = f return f end
  function fire(event, ...) for _, f in ipairs(frames) do if f.events[event] and f.fn then f.fn(f, event, ...) end end end`, "stubs");
run(`local f = assert(load(${JSON.stringify(fs.readFileSync("LifeStats.lua", "utf8"))}, "LifeStats.lua")) f("SOLC", ns)`, "LifeStats.lua");
run(`fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 2575) fire("LOOT_OPENED")
  fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 99999) fire("LOOT_OPENED")
  fire("LOOT_OPENED")  -- (a corpse: no gathering cast)
  fishing = true fire("LOOT_OPENED") fishing = false
  fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 2366) now = now + 10 fire("LOOT_OPENED")  -- (too late: a different loot)
  local l = ns.Life()
  assert(l.ore == 1 and l.skins == 1 and l.fish == 1 and (l.herbs or 0) == 0, ("counts %s %s %s %s"):format(tostring(l.ore), tostring(l.skins), tostring(l.fish), tostring(l.herbs)))
  assert(KillTrackerDB.points.gather == 3, "points " .. tostring(KillTrackerDB.points.gather))
  KillTrackerDB.privacy = { gathering = "off" }
  fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 2575) fire("LOOT_OPENED")
  assert(l.ore == 1 and KillTrackerDB.points.gather == 3, "counted while Off")
  local shared = ns.SharedLife()
  assert(shared.ore == nil, "shared while Off")
  print("PASS: ore, skins, fish counted once each with a point each; a plain loot and a late one don't count; Off counts nothing.")`, "test");
