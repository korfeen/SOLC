-- What the main window's pages share (the pages themselves: OverviewCard.lua, SmashPage.lua, PixPage.lua,
-- CavePage.lua, FrenzPage.lua): everyone using SOLC (Members), the activity feed's clicks and tooltips, showing a
-- character on a model, gear and its stats (GearData), everyone's professions and recipes (CraftersRows); and the
-- Settings page (Config.lua).

local _, ns = ...

local UI = ns.UI
local WIDTH = UI.PAGE_WIDTH

-- Everyone on the guild pages: you first, then synced guildmates, as
-- { key (nil = you), name, kills, points, pvp, pictures, bounty (this week's), updated, officer, stats }.
local function Members()
    local bounty = ns.GetBounty()
    local function BountyKills(record)
        if not bounty or not record or record.week ~= bounty.week or record.target ~= bounty.bounty.id then return 0 end
        return record.kills
    end
    local db = KillTrackerDB
    local list = { {
        name = ns.MyName(), kills = db.total, points = ns.GetPoints().earned, pvp = db.pvp and db.pvp.total or 0,
        pictures = #(db.mints or {}), bounty = BountyKills(db.bounty), updated = time(), me = true,
        officer = IsInGuild() and ns.CanEditConfig(), stats = db, version = ns.ADDON_VERSION,
    } }
    for _, friend in ipairs(ns.GetFriends()) do
        local stats = friend.stats
        local pictures = 0
        for _ in pairs(stats.mints or {}) do pictures = pictures + 1 end
        list[#list + 1] = {
            key = friend.key, name = friend.name, kills = stats.total or 0, points = stats.earned, pvp = stats.pvpTotal,
            pictures = pictures, bounty = BountyKills(stats.bounty), updated = stats.received,
            officer = ns.IsGuildOfficer(friend.key), stats = stats, version = stats.version,
        }
    end
    return list
end
UI.Members = Members  -- (CAVE, CavePage.lua)

-- Activity feed rows (Guild home, the Overview's recent list): the event and its date; a minted or won picture
-- opens in the picture viewer on click.
local function ShowFeedPicture(item)
    if item.mint then ns.ShowMint(item.mint, item.owner) end
end
UI.ShowFeedPicture = ShowFeedPicture
local function FeedTooltip(row, item)
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:AddLine(item.text, 1, 1, 1, true)
    GameTooltip:AddLine(date("%Y-%m-%d %H:%M", item.time), 0.6, 0.6, 0.6)
    if item.mint then GameTooltip:AddLine("Click to see the picture", 0.4, 0.8, 1) end
    GameTooltip:Show()
end
UI.FeedTooltip = FeedTooltip

-- Characters and gear ----------------------------------------------------------------------------

-- Model camera distance by race ID (1 = the game's own fit). The fit is limited by width, so short,
-- broad races come out small in the tall model column.
local RACE_CAMERA = { [3] = 0.9, [7] = 0.85 }  -- Dwarf, Gnome
local MIN_ZOOM, MAX_ZOOM = -0.4, 0.4

local NO_ITEM_LEVEL = { [4] = true, [19] = true }  -- shirt and tabard

local issecret = issecretvalue or function() return false end
local GetItemInfo = C_Item and C_Item.GetItemInfo or GetItemInfo

-- The unit for a player with this GUID if they're near enough to draw (target, group), or nil.
local function NearbyUnit(guid)
    if not guid then return end
    local units = { "target", "mouseover", "focus" }
    local prefix, count = "party", 4
    if IsInRaid() then prefix, count = "raid", 40 end
    for i = 1, count do units[#units + 1] = prefix .. i end
    for _, unit in ipairs(units) do
        local unitGUID = UnitGUID(unit)
        if unitGUID and not issecret(unitGUID) and unitGUID == guid then return unit end
    end
end

-- Shows a character on a model: you (key nil), or a synced guildmate (key in KillTrackerFriends): their real look
-- if they're nearby, otherwise their race in their synced gear, with default hair and face. Returns false (and
-- clears the model) if there's nothing to show yet.
local function DressFromGear(model, gear)
    model:Undress()
    for _, itemID in pairs(gear.items) do model:TryOn("item:" .. itemID) end
end
local function LoadCharacter(model, key)
    local friend = key and KillTrackerFriends[key]
    local gear = friend and friend.gear
    model.shownGear = gear
    if not key then
        model:SetUnit("player")
        return true
    end
    local unit = gear and NearbyUnit(gear.guid)
    if unit then
        model:SetUnit(unit)
    elseif gear and gear.race and gear.race > 0 and model.SetCustomRace then
        model:SetCustomRace(gear.race, gear.sex == 3 and 1 or 0)
        DressFromGear(model, gear)
        C_Timer.After(0.2, function()  -- the race model may still be loading
            if model.shownGear == gear then DressFromGear(model, gear) end
        end)
    else
        model:ClearModel()
        return false
    end
    return true
end
UI.LoadCharacter = LoadCharacter

-- The camera distance for someone's model (1 = the game's own fit; zoom added), closer for short, broad races.
local function CharacterCamera(key, zoom)
    local race
    if key then
        local friend = KillTrackerFriends[key]
        race = friend and friend.gear and friend.gear.race
    else
        race = select(3, UnitRace("player"))
    end
    return math.max(0.4, (RACE_CAMERA[race] or 1) + (zoom or 0))
end
UI.CharacterCamera = CharacterCamera
UI.MIN_ZOOM, UI.MAX_ZOOM = MIN_ZOOM, MAX_ZOOM

-- Right-clicking your own model: pick its background from the ones on your pictures.
local function PickBackdrop(owner)
    local owned = ns.OwnedBackgrounds()
    if not MenuUtil then  -- no menus: step through them instead
        local current, nextID = KillTrackerDB.showcase and KillTrackerDB.showcase.backdrop, nil
        for i, option in ipairs(owned) do
            if option.id == current then nextID = owned[i + 1] and owned[i + 1].id end
        end
        ns.SetModelBackdrop(current and nextID or (owned[1] and owned[1].id))
        return
    end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle("Background")
        local function IsCurrent(id) return (KillTrackerDB.showcase and KillTrackerDB.showcase.backdrop) == id end
        root:CreateRadio("None", function() return IsCurrent(nil) end, function() ns.SetModelBackdrop(nil) end)
        for _, option in ipairs(owned) do
            local name = ("|c%s%s|r"):format(ns.RARITY_COLORS[option.rarity] or "ffffffff", option.name)
            root:CreateRadio(name, function() return IsCurrent(option.id) end,
                function() ns.SetModelBackdrop(option.id) end)
        end
        if #owned == 0 then root:CreateTitle("Mint a picture to get backgrounds") end
    end)
end
UI.PickBackdrop = PickBackdrop

-- Gear details: every slot with icon, name and item level (hover for the full tooltip), and the stats the
-- gear adds up to. Shown in place of the Overview's left side; panel:SetPlayer(key) like the model.
local SLOT_NAMES = {
    "HEADSLOT", "NECKSLOT", "SHOULDERSLOT", "SHIRTSLOT", "CHESTSLOT", "WAISTSLOT", "LEGSSLOT", "FEETSLOT",
    "WRISTSLOT", "HANDSSLOT", "FINGER0SLOT", "FINGER1SLOT", "TRINKET0SLOT", "TRINKET1SLOT", "BACKSLOT",
    "MAINHANDSLOT", "SECONDARYHANDSLOT", "RANGEDSLOT", "TABARDSLOT",
}
local STAT_ORDER = { "ITEM_MOD_STAMINA_SHORT", "ITEM_MOD_STRENGTH_SHORT", "ITEM_MOD_AGILITY_SHORT",
    "ITEM_MOD_INTELLECT_SHORT", "ITEM_MOD_SPIRIT_SHORT", "RESISTANCE0_NAME" }
local RESISTANCE_SCHOOLS = { [0] = "Armor", "Holy", "Fire", "Nature", "Frost", "Shadow", "Arcane" }

-- A stat key from GetItemStats as a readable name. The client has names for most keys
-- (ITEM_MOD_STAMINA_SHORT = "Stamina") but not all: "ITEM_MOD_FIRE_RESISTANCE_SHORT" -> "Fire Resistance".
local function StatLabel(key)
    local name = _G[key]
    if type(name) == "string" and name ~= "" and not name:find("%%") then return name end
    local school = tonumber(key:match("^RESISTANCE(%d)_NAME$"))
    if school then return school == 0 and "Armor" or RESISTANCE_SCHOOLS[school] .. " Resistance" end
    local words = key:gsub("^ITEM_MOD_", ""):gsub("_SHORT$", ""):gsub("_NAME$", ""):lower():gsub("_", " ")
    return (words:gsub("(%a)(%a*)", function(first, rest) return first:upper() .. rest end))
end
local GetItemStats = C_Item and C_Item.GetItemStats or GetItemStats
local GetItemQualityColor = C_Item and C_Item.GetItemQualityColor or GetItemQualityColor
local GetItemIcon = C_Item and C_Item.GetItemIconByID or GetItemIcon

-- Someone's gear for the new Overview's GEARZ page (OverviewCard.lua): you (key nil) or a synced guildmate.
-- Returns { has (gear known), loading (items still arriving), slots = { [slot] = { item, name, quality, level,
-- texture, enchanted } }, stats = { { label, value } } (main ones first), average (item level) }.
function UI.GearData(key)
    local friend = key and KillTrackerFriends[key]
    local data = { has = not key or (friend and friend.gear) ~= nil, slots = {}, stats = {}, loading = false }
    if not data.has then return data end
    local totals, sum, count = {}, 0, 0
    for slot = 1, 19 do
        local item
        if key then item = ns.GearItemString(friend.gear, slot) else item = GetInventoryItemLink("player", slot) end
        if item then
            local name, _, quality, itemLevel, _, _, _, _, _, texture = GetItemInfo(item)
            local itemID = tonumber(item:match("item:(%d+)"))
            if not name then
                data.loading = true
                if C_Item and C_Item.RequestLoadItemDataByID and itemID then C_Item.RequestLoadItemDataByID(itemID) end
            end
            local enchant = tonumber(item:match("item:%d+:(%d*)") or "") or 0
            data.slots[slot] = { item = item, name = name, quality = quality, level = not NO_ITEM_LEVEL[slot] and itemLevel or nil,
                texture = texture or (itemID and GetItemIcon and GetItemIcon(itemID)), enchanted = enchant > 0 }
            if itemLevel and not NO_ITEM_LEVEL[slot] then sum, count = sum + itemLevel, count + 1 end
            local stats = GetItemStats and GetItemStats(item)
            for stat, value in pairs(stats or {}) do
                if not stat:find("DAMAGE_PER_SECOND") then
                    local label = StatLabel(stat)
                    totals[label] = (totals[label] or 0) + value
                end
            end
        end
    end
    data.average = count > 0 and sum / count or nil
    local known = {}
    for _, statKey in ipairs(STAT_ORDER) do
        local label = StatLabel(statKey)
        if totals[label] then data.stats[#data.stats + 1] = { label, math.floor(totals[label] + 0.5) } end
        known[label] = true
    end
    local rest = {}
    for label in pairs(totals) do if not known[label] then rest[#rest + 1] = label end end
    table.sort(rest)
    for _, label in ipairs(rest) do data.stats[#data.stats + 1] = { label, math.floor(totals[label] + 0.5) } end
    return data
end
UI.GEAR_SLOT_NAMES = SLOT_NAMES

-- Crafters ------------------------------------------------------------------------------------------

-- Everyone's professions: you first, then synced guildmates: { { key (nil = you), name, professions } }.
local function Crafters()
    local list = { { name = ns.MyName(), professions = ns.GetProfessions(nil) } }
    for _, friend in ipairs(ns.GetFriends()) do
        if friend.stats.professions then
            list[#list + 1] = { key = friend.key, name = friend.name, professions = friend.stats.professions }
        end
    end
    return list
end

local function Rank(professions, line)
    for _, prof in ipairs(professions.list) do
        if prof.line == line then return prof end
    end
end

-- With no search: each profession and who has it. With a search: matching recipes and who knows them.
local function CraftersRows(query)
    local rows = {}
    local crafters = Crafters()
    if query == "" then
        local byLine = {}
        for _, person in ipairs(crafters) do
            for _, prof in ipairs(person.professions.list) do
                local entry = byLine[prof.line]
                if not entry then
                    entry = { name = prof.name, icon = prof.icon, people = {} }
                    byLine[prof.line] = entry
                    rows[#rows + 1] = entry
                end
                entry.people[#entry.people + 1] = { name = person.name, rank = prof.rank, max = prof.max }
            end
        end
        table.sort(rows, function(a, b) return a.name < b.name end)
    else
        local byRecipe = {}
        for _, person in ipairs(crafters) do
            for line, recipes in pairs(person.professions.recipes) do
                local prof = Rank(person.professions, line)
                for _, id in ipairs(recipes) do
                    local name, icon = ns.RecipeInfo(id)
                    if not name and C_Spell and C_Spell.RequestLoadSpellData then C_Spell.RequestLoadSpellData(id) end
                    if name and name:lower():find(query, 1, true) then
                        local entry = byRecipe[id]
                        if not entry then
                            entry = { id = id, name = name, icon = icon, people = {} }
                            byRecipe[id] = entry
                            rows[#rows + 1] = entry
                        end
                        entry.people[#entry.people + 1] = { name = person.name, rank = prof and prof.rank, max = prof and prof.max }
                    end
                end
            end
        end
        table.sort(rows, function(a, b) return a.name < b.name end)
    end
    for _, row in ipairs(rows) do
        table.sort(row.people, function(a, b) return (a.rank or 0) > (b.rank or 0) end)
    end
    return rows
end

UI.Crafters, UI.CraftersRows = Crafters, CraftersRows  -- (FRENZ, FrenzPage.lua)

-- The Bounty Board is CAVE's HUNTS tab (CavePage.lua).
function ns.ToggleBountyBoard() ns.OpenPage("bounties") end

-- Settings -----------------------------------------------------------------------------------------

ns.RegisterPage({
    key = "settings", label = "Settings", section = "settings", order = 1,
    create = function(parent) return ns.EmbedConfig(parent, WIDTH) end,
    refresh = function() if ns.RefreshConfigPanel then ns.RefreshConfigPanel() end end,
})
function ns.ToggleConfig() ns.OpenPage("settings") end
