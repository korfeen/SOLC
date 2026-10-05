-- PvP kills: your honorable kills of enemy players, kept apart from NPC kills in KillTrackerDB.pvp.
-- The honorable kill counter (GetPVPLifetimeStats) says *that* you got a kill; who it was comes from
-- watching enemy players on target/nameplates (one seen alive that died just before the kill), or
-- else from the "X dies, honorable kill" chat line (unreadable inside instances in 12.0.0). A kill
-- nobody can be named for still counts, as an unknown player.

local _, ns = ...

local ATTRIBUTE_WINDOW = 5  -- seconds a seen death or chat line may precede the honorable kill
local UNKNOWN = "Unknown"

local issecret = issecretvalue or function() return false end

local function Readable(v)
    if issecret(v) then return nil end
    return v
end

local sessionKills = 0
local lastHonorableKills       -- lifetime honorable kills when last checked
local seenAlive = {}           -- [guid] = true: enemy players seen alive
local deaths = {}              -- [guid] = { name, realm, race, class, level, at, credited }
local honorVictim              -- { name, at } from the latest honorable kill chat line

-- Watching enemy players -----------------------------------------------------------

local function WatchUnit(unit)
    if not UnitExists(unit) or Readable(UnitIsPlayer(unit)) ~= true then return end
    if Readable(UnitCanAttack("player", unit)) ~= true then return end
    local guid = Readable(UnitGUID(unit))
    if not guid then return end

    if Readable(UnitIsDeadOrGhost(unit)) ~= true then
        seenAlive[guid] = true
        deaths[guid] = nil  -- alive again (resurrected, or got up from Feign Death): a new life
    elseif seenAlive[guid] and not deaths[guid] then
        local name, realm = UnitName(unit)
        deaths[guid] = {
            name = Readable(name), realm = Readable(realm), race = Readable((UnitRace(unit))),
            class = Readable((UnitClass(unit))), level = Readable(UnitLevel(unit)), at = GetTime(),
        }
        seenAlive[guid] = nil
    end
end

-- "%s dies, honorable kill Rank: %s (%d Honor Points)" -> a Lua pattern capturing the name.
local function ChatPattern(format)
    if type(format) ~= "string" then return end
    local pattern = format:gsub("[%(%)%.%+%-%*%?%[%]%^%$]", "%%%0")
    pattern = pattern:gsub("%%s", "(.-)", 1):gsub("%%s", ".-"):gsub("%%d", "%%d+")
    return "^" .. pattern .. "$"
end
local CHAT_PATTERNS = { ChatPattern(COMBATLOG_HONORGAIN), ChatPattern(COMBATLOG_HONORGAIN_NO_RANK) }

local function OnHonorChat(message)
    message = Readable(message)
    if not message then return end
    for _, pattern in ipairs(CHAT_PATTERNS) do
        local name = message:match(pattern)
        if name then
            honorVictim = { name = name, at = GetTime() }
            return
        end
    end
end

-- Crediting kills --------------------------------------------------------------------

-- The most recent uncredited death within the window, preferring the player the chat line names.
local function FindVictim()
    local now, best = GetTime(), nil
    local chatName = honorVictim and now - honorVictim.at <= ATTRIBUTE_WINDOW and honorVictim.name
    for _, death in pairs(deaths) do
        if not death.credited and now - death.at <= ATTRIBUTE_WINDOW then
            if chatName and death.name == chatName then return death end
            if not best or death.at > best.at then best = death end
        end
    end
    if best then return best end
    if chatName then return { name = chatName } end  -- named by chat only: race/class unknown
end

local function RecordPvPKill(victim)
    local pvp = KillTrackerDB.pvp
    pvp.total = pvp.total + 1
    sessionKills = sessionKills + 1
    if ns.OnBountyEvent then ns.OnBountyEvent("pvp", victim) end

    local key = victim and victim.name and (victim.name .. "-" .. (victim.realm or GetNormalizedRealmName() or ""))
    if not key then
        pvp.unknown = pvp.unknown + 1
        if KillTrackerDB.announce then ns.Print("PvP kill: unknown player") end
        return
    end
    victim.credited = true
    local player = pvp.players[key]
    if not player then
        player = { name = victim.name, realm = victim.realm, count = 0 }
        pvp.players[key] = player
    end
    player.count = player.count + 1
    player.race = victim.race or player.race
    player.class = victim.class or player.class
    player.level = victim.level or player.level
    player.zone = GetZoneText()
    player.time = time()
    if KillTrackerDB.announce then
        ns.Print(("PvP kill: %s (%s %s) x%d"):format(player.name, player.race or "?", player.class or "?", player.count))
    end
end

local function CheckHonorableKills()
    local kills = Readable((GetPVPLifetimeStats()))
    if not kills then return end
    local gained = lastHonorableKills and kills - lastHonorableKills or 0
    lastHonorableKills = kills
    for _ = 1, math.min(gained, 10) do
        RecordPvPKill(FindVictim())
    end
    if gained > 0 and ns.OnKillsChanged then ns.OnKillsChanged() end
    -- Forget old deaths.
    local now = GetTime()
    for guid, death in pairs(deaths) do
        if now - death.at > ATTRIBUTE_WINDOW * 2 then deaths[guid] = nil end
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
frame:RegisterEvent("UNIT_HEALTH")
frame:RegisterEvent("PLAYER_PVP_KILLS_CHANGED")
frame:RegisterEvent("CHAT_MSG_COMBAT_HONOR_GAIN")
frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_LOGIN" then
        lastHonorableKills = Readable((GetPVPLifetimeStats()))
    elseif event == "PLAYER_ENTERING_WORLD" then
        wipe(seenAlive)
        wipe(deaths)
    elseif event == "PLAYER_TARGET_CHANGED" then
        WatchUnit("target")
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        WatchUnit(arg1)
    elseif event == "UNIT_HEALTH" then
        if arg1 == "target" or arg1:find("^nameplate") then WatchUnit(arg1) end
    elseif event == "CHAT_MSG_COMBAT_HONOR_GAIN" then
        OnHonorChat(arg1)
    elseif event == "PLAYER_PVP_KILLS_CHANGED" then
        -- The chat line and the last health update can arrive just after this event.
        C_Timer.After(0.5, CheckHonorableKills)
    end
end)

-- For the UI: every PvP victim as { name, count, player, c = { race, class } }, plus unknown kills.
function ns.CollectPlayers(source)
    local players = {}
    local pvp = source.pvp
    if not pvp then return players end
    for key, p in pairs(pvp.players) do
        players[#players + 1] = { name = p.name, count = p.count, player = p, key = key,
            c = { race = p.race or UNKNOWN, class = p.class or UNKNOWN } }
    end
    if pvp.unknown > 0 then
        players[#players + 1] = { name = "Unknown players", count = pvp.unknown, c = { race = UNKNOWN, class = UNKNOWN } }
    end
    return players
end

ns.GetSessionPvPKills = function() return sessionKills end
