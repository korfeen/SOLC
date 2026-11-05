// SecretDeeds.lua: /dance at a living murloc, /wave at an ogre, a naked kill, three deaths in ten minutes and a flight
// each count; dancing at a boar, a kill in armour, deaths far apart don't.
const fs = require("fs");
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require("C:/Users/faluk/Projects/solc-activity/node_modules/fengari");
const L = lauxlib.luaL_newstate(); lualib.luaL_openlibs(L);
const run = (code, name) => { if (lauxlib.luaL_loadbuffer(L, to_luastring(code), null, to_luastring(name)) || lua.lua_pcall(L, 0, 0, 0)) throw Error(to_jsstring(lua.lua_tostring(L, -1))); };
run(`KillTrackerDB = { tally = {} } SlashCmdList = {}
  ns = { KillHandlers = {}, IsMember = function() return true end }
  function ns.Tally(k) KillTrackerDB.tally[k] = (KillTrackerDB.tally[k] or 0) + 1 end
  KINDS = { [100] = "Murloc", [200] = "Ogre", [300] = "Boar" }
  function ns.Categorize(id) return { subtype = KINDS[id] } end
  target, worn, now, taxi, timers = nil, {}, 0, false, {}
  UnitExists = function() return target ~= nil end
  UnitIsPlayer = function() return false end
  UnitIsDead = function() return false end
  UnitGUID = function() return target and ("Creature-0-1-2-3-%d-0000"):format(target) end
  UnitName = function() return "Bonnie" end
  Ambiguate = function(n) return (n:gsub("%-.*", "")) end
  GetInventoryItemID = function(_, slot) return worn[slot] end
  GetTime = function() return now end
  UnitOnTaxi = function() return taxi end
  C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end, NewTicker = function() end }
  frames = {}
  CreateFrame = function() local f = { ev = {} } function f:RegisterEvent(e) self.ev[e] = true end function f:SetScript(_, fn) self.fn = fn end frames[#frames + 1] = f return f end
  function fire(e, ...) for _, f in ipairs(frames) do if f.ev[e] then f.fn(f, e, ...) end end end`, "stubs");
run(`local f = assert(load(${JSON.stringify(fs.readFileSync("SecretDeeds.lua", "utf8"))}, "SecretDeeds.lua")) f("SOLC", ns)`, "SecretDeeds.lua");
run(`local t = KillTrackerDB.tally
  target = 300 fire("CHAT_MSG_TEXT_EMOTE", "You dance with Boar.", "Bonnie-Realm") assert(not t.dance, "boar dance counted")
  target = 100 fire("CHAT_MSG_TEXT_EMOTE", "You dance with Murloc Forager.", "Bonnie-Realm") assert(t.dance == 1, "murloc dance")
  fire("CHAT_MSG_TEXT_EMOTE", "Someone dances with Murloc.", "Other-Realm") assert(t.dance == 1, "someone else's dance")
  target = 200 fire("CHAT_MSG_TEXT_EMOTE", "You wave at Mosh'Ogg Brute.", "Bonnie") assert(t.wave == 1, "ogre wave")
  worn = { [5] = 123 } ns.KillHandlers[1]() assert(not t.naked, "armoured kill counted")
  worn = { [4] = 45 } ns.KillHandlers[1]() assert(t.naked == 1, "naked kill (a shirt on)")
  now = 0 fire("PLAYER_DEAD") now = 700 fire("PLAYER_DEAD") now = 900 fire("PLAYER_DEAD") assert(not t.deadTired, "spread deaths")
  now = 1000 fire("PLAYER_DEAD") assert(t.deadTired == 1, "three in ten minutes")
  taxi = true fire("PLAYER_CONTROL_LOST") for _, fn in ipairs(timers) do fn() end assert(t.flights == 1, "flight")
  print("PASS: murloc dance, ogre wave, naked kill, dead tired and a flight count; the others don't.")`, "test");
