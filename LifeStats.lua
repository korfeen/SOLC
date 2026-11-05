-- Life in Azeroth, beyond the kills: napping (resting at inns and in cities, and logged out there: an ogre sleeping
-- it off), deaths, quests turned in, places visited (every zone and subzone you've set foot in) and gold (earned and
-- spent). Each has its own privacy choice (KillTrackerDB.privacy[key]): "share" (the default: guildmates see it, by
-- sync and the score relay, Sync.lua), "me" (counted, only you see it) or "off" (not counted; what's counted stays).
-- Chosen in Settings and in Reginald's welcome (Onboarding.lua). Deeds only, no points: opting out never costs rank.
-- KillTrackerDB.life = { nap (minutes), deaths, quests, places = { [zone/subzone] = true }, placeCount, goldIn,
-- goldOut (copper), seq }; changes are stamped (ns.Touch) so they sync like the rest.

local _, ns = ...

ns.LIFE_STATS = {
    { key = "nap", name = "Napping", desc = "Time resting at inns and in cities, and logged out there: an ogre sleeping it off." },
    { key = "deaths", name = "Deaths", desc = "Every time you die." },
    { key = "quests", name = "Quests", desc = "Quests turned in." },
    { key = "places", name = "Exploration", desc = "Places visited: every zone and subzone you've set foot in." },
    { key = "gold", name = "Gold", desc = "Gold that came in (loot, quests, sales, trades, the mail) and went out." },
}
ns.PRIVACY_CHOICES = { { "share", "Share" }, { "me", "Just me" }, { "off", "Off" } }

local NAP_STEP = 10        -- minutes of napping between syncs (it ticks every minute; guildmates needn't hear each one)
local NAP_AWAY_MAX = 14 * 86400  -- seconds of logged-out napping counted at most (a long break isn't one long nap)
local issecret = issecretvalue or function() return false end

local function Life()
    local db = KillTrackerDB
    db.life = db.life or { nap = 0, deaths = 0, quests = 0, places = {}, placeCount = 0, goldIn = 0, goldOut = 0 }
    return db.life
end
ns.Life = Life

function ns.Privacy(key)
    return KillTrackerDB and KillTrackerDB.privacy and KillTrackerDB.privacy[key] or "share"
end
function ns.SetPrivacy(key, value)
    local db = KillTrackerDB
    db.privacy = db.privacy or {}
    db.privacy[key] = value ~= "share" and value or nil
    ns.Touch(Life())  -- (guildmates get the change: shown again, or hidden)
    if ns.OnKillsChanged then ns.OnKillsChanged() end
end

local function Counting(key) return KillTrackerDB and ns.IsMember() and ns.Privacy(key) ~= "off" end

-- What guildmates may see: { nap, deaths, quests, places, goldIn, goldOut }, nil for what isn't shared.
function ns.SharedLife()
    local life, out = Life(), {}
    local shared = function(key) return ns.Privacy(key) == "share" end
    if shared("nap") then out.nap = life.nap end
    if shared("deaths") then out.deaths = life.deaths end
    if shared("quests") then out.quests = life.quests end
    if shared("places") then out.places = life.placeCount end
    if shared("gold") then out.goldIn, out.goldOut = life.goldIn, life.goldOut end
    return out
end

local function Changed(life)
    ns.Touch(life)
    if ns.OnKillsChanged then ns.OnKillsChanged() end
end

local function NotePlace()
    if not Counting("places") then return end
    local zone, sub = GetZoneText and GetZoneText(), GetSubZoneText and GetSubZoneText()
    if not zone or zone == "" or issecret(zone) then return end
    local life, added = Life(), false
    for _, key in ipairs({ zone, (sub and sub ~= "" and not issecret(sub)) and (zone .. "/" .. sub) or nil }) do
        if key and not life.places[key] then
            life.places[key] = true
            life.placeCount = life.placeCount + 1
            added = true
        end
    end
    if added then Changed(life) end
end

local napTicker, napUnsynced = nil, 0
local frame = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_LOGOUT", "PLAYER_DEAD", "QUEST_TURNED_IN", "PLAYER_MONEY",
    "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA" }) do
    frame:RegisterEvent(event)
end
frame:SetScript("OnEvent", function(_, event)
    if not KillTrackerDB then return end
    local life = Life()
    if event == "PLAYER_ENTERING_WORLD" then
        life.lastMoney = GetMoney()  -- (gold: changes from here on)
        -- Logged out at an inn or in a city and back in there: slept it off.
        if life.napOut and Counting("nap") and IsResting() then
            local away = math.min(NAP_AWAY_MAX, math.max(0, GetServerTime() - life.napOut))
            if away >= 60 then life.nap = life.nap + math.floor(away / 60) Changed(life) end
        end
        life.napOut = nil
        NotePlace()
        napTicker = napTicker or C_Timer.NewTicker(60, function()
            if not (KillTrackerDB and Counting("nap") and IsResting()) then return end
            local l = Life()
            l.nap = l.nap + 1
            napUnsynced = napUnsynced + 1
            if napUnsynced >= NAP_STEP then napUnsynced = 0 Changed(l) end
        end)
    elseif event == "PLAYER_LOGOUT" then
        life.napOut = (Counting("nap") and IsResting()) and GetServerTime() or nil
        if napUnsynced > 0 then ns.Touch(life) end
    elseif event == "PLAYER_DEAD" then
        if Counting("deaths") then life.deaths = life.deaths + 1 Changed(life) end
    elseif event == "QUEST_TURNED_IN" then
        if Counting("quests") then life.quests = life.quests + 1 Changed(life) end
    elseif event == "PLAYER_MONEY" then
        local money = GetMoney()
        local delta = money - (life.lastMoney or money)
        life.lastMoney = money
        if delta ~= 0 and Counting("gold") then
            if delta > 0 then life.goldIn = life.goldIn + delta else life.goldOut = life.goldOut - delta end
            Changed(life)
        end
    else
        NotePlace()
    end
end)
