-- Your character and equipped gear, synced to guildmates (Sync.lua) so the Overview page can show
-- their model and gear: KillTrackerDB.gear = { race, sex, class, level, guid, items = { [slot] = itemID },
-- extras = { [slot] = { enchant, suffix } }, seq }. race is the race ID (UnitRace), sex 2 = male,
-- 3 = female (UnitSex), class the class file ("WARRIOR"); extras only for items with an enchant or a random
-- suffix ("of the Bear"), which change their stats.

local _, ns = ...

local issecret = issecretvalue or function() return false end
local function Readable(v)
    if issecret(v) then return nil end
    return v
end

local FIRST_SLOT, LAST_SLOT = 1, 19

local function Collect()
    local _, class = UnitClass("player")
    local gear = {
        race = Readable(select(3, UnitRace("player"))), sex = Readable(UnitSex("player")), class = Readable(class),
        level = Readable(UnitLevel("player")), guid = Readable(UnitGUID("player")), items = {},
    }
    gear.extras = {}
    for slot = FIRST_SLOT, LAST_SLOT do
        gear.items[slot] = Readable(GetInventoryItemID("player", slot))
        local link = Readable(GetInventoryItemLink("player", slot))
        local fields = link and link:match("item:([%-%d:]+)")
        if gear.items[slot] and fields then
            local f = { strsplit(":", fields) }
            local enchant, suffix = tonumber(f[2]) or 0, tonumber(f[7]) or 0
            if enchant ~= 0 or suffix ~= 0 then gear.extras[slot] = { enchant = enchant, suffix = suffix } end
        end
    end
    return gear
end

local function Same(a, b)
    if not a or a.race ~= b.race or a.sex ~= b.sex or a.class ~= b.class or a.level ~= b.level or a.guid ~= b.guid then
        return false
    end
    for slot = FIRST_SLOT, LAST_SLOT do
        if (a.items or {})[slot] ~= b.items[slot] then return false end
        local x, y = (a.extras or {})[slot], b.extras[slot]
        if (x and x.enchant) ~= (y and y.enchant) or (x and x.suffix) ~= (y and y.suffix) then return false end
    end
    return true
end

-- An item string for a slot of a gear table (yours or a guildmate's), with its enchant and random suffix:
-- "item:id:enchant:0:0:0:0:suffix", or nil for an empty slot. Works with GetItemInfo, GetItemStats and
-- GameTooltip:SetHyperlink.
function ns.GearItemString(gear, slot)
    local itemID = gear and gear.items[slot]
    if not itemID then return end
    local extra = gear.extras and gear.extras[slot]
    return ("item:%d:%d:0:0:0:0:%d"):format(itemID, extra and extra.enchant or 0, extra and extra.suffix or 0)
end

-- Stores your gear and marks it changed (so it syncs) if anything differs from what's stored.
local function Update()
    local db = KillTrackerDB
    if not db then return end
    local gear = Collect()
    if Same(db.gear, gear) then return end
    db.gear = gear
    ns.Touch(gear)
    if ns.OnGearChanged then ns.OnGearChanged() end
end

local pending
local function UpdateSoon()  -- equipment events come in bursts when swapping several items
    if pending then return end
    pending = true
    C_Timer.After(1, function()
        pending = nil
        Update()
    end)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
frame:RegisterEvent("PLAYER_LEVEL_UP")
frame:SetScript("OnEvent", UpdateSoon)
