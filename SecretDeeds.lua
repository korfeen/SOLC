-- Secret deeds: one-off surprises (Achievements.lua's FEATS with secret = true, in the Deeds page's Secrets group as
-- "A secret deed" till begun, Reginald's hint on a click). What they count, into your tally (ns.Tally, KillTrackerDB.tally):
--   dance     /dance at a living murloc            wave      /wave at a living ogre
--   naked     a kill with no armour on at all       shoo      a remark of Reginald's waved off (Onboarding.lua)
--   deadTired three deaths inside ten minutes       flights   a flight path taken
--   tribute   an Ogre Godz tribute chest received (Unlocks.lua's ns.AddTribute)
-- Hibernation goes by your napping (LifeStats.lua's life.nap, in minutes).

local _, ns = ...

local issecret = issecretvalue or function() return false end
local ARMOUR_SLOTS = { 1, 3, 5, 6, 7, 8, 9, 10 }  -- head, shoulders, chest, waist, legs, feet, wrists, hands (a shirt is fine)
local DEAD_TIRED = { deaths = 3, within = 600 }
local NAP_GOAL = 24 * 60

local function Counting() return KillTrackerDB and ns.IsMember and ns.IsMember() end

-- Your target, if it's a living NPC: its kind (ns.Categorize: subtype "Murloc", "Ogre"...).
local function TargetKind()
    if not UnitExists("target") or UnitIsPlayer("target") or UnitIsDead("target") then return end
    local guid = UnitGUID("target")
    if not guid or issecret(guid) then return end
    local npcID = tonumber(guid:match("^%a+%-%d+%-%d+%-%d+%-%d+%-(%d+)%-"))
    local c = npcID and ns.Categorize and ns.Categorize(npcID, {})
    return c and c.subtype
end

-- Emotes: your own /dance and /wave (the chat line about them comes with your name as its sender).
local EMOTES = { { "^You dance", "Murloc", "dance" }, { "^You wave", "Ogre", "wave" } }
local function OnEmote(text, sender)
    if not Counting() or not text or issecret(text) or not sender or issecret(sender) then return end
    if Ambiguate(sender, "short") ~= UnitName("player") then return end
    for _, e in ipairs(EMOTES) do
        if text:find(e[1]) and TargetKind() == e[2] and not (KillTrackerDB.tally and KillTrackerDB.tally[e[3]]) then ns.Tally(e[3]) end
    end
end

-- Naked Brawler: a kill with every armour slot empty.
table.insert(ns.KillHandlers, function()
    if not Counting() or (KillTrackerDB.tally and KillTrackerDB.tally.naked) then return end
    for _, slot in ipairs(ARMOUR_SLOTS) do
        if GetInventoryItemID("player", slot) ~= nil then return end  -- (anything on: not naked)
    end
    ns.Tally("naked")
end)

-- Waving Reginald off (Onboarding.lua calls this when a remark of his is clicked away).
function ns.SecretShoo() if Counting() then ns.Tally("shoo") end end

local deaths = {}
local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_TEXT_EMOTE")
frame:RegisterEvent("PLAYER_DEAD")
frame:RegisterEvent("PLAYER_CONTROL_LOST")
frame:SetScript("OnEvent", function(_, event, ...)
    if event == "CHAT_MSG_TEXT_EMOTE" then
        OnEmote(...)
    elseif event == "PLAYER_DEAD" and Counting() then
        local now = GetTime()
        deaths[#deaths + 1] = now
        while deaths[1] and now - deaths[1] > DEAD_TIRED.within do table.remove(deaths, 1) end
        if #deaths >= DEAD_TIRED.deaths and not (KillTrackerDB.tally and KillTrackerDB.tally.deadTired) then ns.Tally("deadTired") end
    elseif event == "PLAYER_CONTROL_LOST" then
        -- (losing control: a flight path, if a moment later you're on a taxi)
        C_Timer.After(1, function()
            if Counting() and UnitOnTaxi and UnitOnTaxi("player") then ns.Tally("flights") end
        end)
    end
end)

-- Hibernation: a look every ten minutes (napping counts by the minute, LifeStats.lua) till it's earned.
C_Timer.NewTicker(600, function()
    local life = KillTrackerDB and KillTrackerDB.life
    local earned = KillTrackerDB and KillTrackerDB.achievements and KillTrackerDB.achievements["feat:hibernation:" .. NAP_GOAL]
    if life and not earned and (life.nap or 0) >= NAP_GOAL and ns.CheckAchievements then ns.CheckAchievements() end
end)
ns.NAP_GOAL = NAP_GOAL
