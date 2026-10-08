-- Pages of the main window (UI.lua) beyond the kill lists:
--   Me      Overview: your points, this week's bounty, achievements close to their next tier, recent highlights
--   Guild   Home: the bounty and the activity feed. Members: everyone synced. Leaderboard: rankings.
--           Bounties: the Bounty Board (BountyBoard.lua). Gallery: every picture minted in the guild.
--   Settings (Config.lua)

local _, ns = ...

local UI = ns.UI
local WIDTH, HEIGHT = UI.PAGE_WIDTH, UI.PAGE_HEIGHT

local function Capitalize(text) return (text:gsub("^%l", string.upper)) end

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

-- A page frame with a title and a line under it.
local function NewPage(parent, titleText)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    page.title, page.line = UI.CreateHeader(page)
    page.title:SetText(titleText)
    return page
end

-- A fixed (non-scrolling) stack of rows at y: rows:Set(data, render) with render(row, item). width: default
-- the full list width.
local function RowStack(page, y, count, width)
    width = width or WIDTH - 40
    local holder = CreateFrame("Frame", nil, page)
    holder:SetPoint("TOPLEFT", 10, -y)
    holder:SetSize(width, count * UI.ROW_HEIGHT)
    local stack = { rows = {}, holder = holder, limit = count }
    for i = 1, count do
        local row = UI.CreateRow(holder, i, width)
        row:SetScript("OnLeave", GameTooltip_Hide)
        stack.rows[i] = row
    end
    -- Moves the stack to y and shows at most limit rows (up to the count it was made with).
    function stack:Place(newY, limit)
        holder:ClearAllPoints()
        holder:SetPoint("TOPLEFT", 10, -newY)
        self.limit = math.min(limit, count)
    end
    function stack:Set(data, render)
        for i, row in ipairs(self.rows) do
            local item = i <= self.limit and data[i] or nil
            row:SetShown(item ~= nil)
            if item then
                row.data = item
                row.bar:SetVertexColor(0.8, 0.2, 0.2, 0.45)
                row:SetBar(0)
                render(row, item)
            end
        end
    end
    return stack
end

-- A scrolling list: list:Set(data, render, onClick, onEnter).
local function ScrollList(page, top)
    local scroll = UI.CreateScroll(page, top)
    local list = { rows = {}, scroll = scroll }
    function list:Set(data, render, onClick, onEnter)
        for i, item in ipairs(data) do
            local row = self.rows[i]
            if not row then
                row = UI.CreateRow(scroll.content, i)
                row:SetScript("OnLeave", GameTooltip_Hide)
                self.rows[i] = row
            end
            row.data = item
            row.bar:SetVertexColor(0.8, 0.2, 0.2, 0.45)
            row:SetBar(0)
            row:SetScript("OnClick", onClick and function(self) onClick(self.data) end or nil)
            row:SetScript("OnEnter", onEnter and function(self) onEnter(self, self.data) end or nil)
            render(row, item)
            row:Show()
        end
        for i = #data + 1, #self.rows do self.rows[i]:Hide() end
        scroll.content:SetHeight(math.max(1, #data * UI.ROW_HEIGHT))
    end
    return list
end

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

-- The bounty block shared by Overview and Guild home: name, bar, details. Click opens the Bounty Board.
-- width: default the whole page.
local function BountyBlock(page, y, width)
    width = width or WIDTH - 24
    local block = CreateFrame("Button", nil, page)
    block:SetPoint("TOPLEFT", 12, -y)
    block:SetSize(width, 58)
    block:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    block.name = block:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    block.name:SetPoint("TOPLEFT", 0, -2)
    block.name:SetPoint("RIGHT", block, "RIGHT")
    block.name:SetJustifyH("LEFT")
    block.name:SetWordWrap(false)
    block.bar = UI.CreateBar(block, width)
    block.bar:SetPoint("TOPLEFT", 0, -20)
    block.details = block:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    block.details:SetPoint("TOPLEFT", 0, -40)
    block.details:SetPoint("RIGHT", block, "RIGHT")
    block.details:SetJustifyH("LEFT")
    block:SetScript("OnClick", function() ns.OpenPage("bounties") end)
    block:SetScript("OnEnter", function(self)
        local progress = ns.GetBountyProgress()
        if not progress then return end
        local bounty = progress.current.bounty
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(("Weekly guild bounty: %s"):format(bounty.name))
        GameTooltip:AddLine(bounty.desc, 1, 1, 1, true)
        GameTooltip:AddLine((bounty.count and ("Each one is worth %d%% extra points. "):format(ns.Config("bountyExtra")) or "")
            .. ("If the guild reaches %d, everyone who got at least %d earns %d points."):format(progress.goal, progress.needed,
            ns.Config("bountyReward")), 1, 1, 1, true)
        for _, c in ipairs(progress.contributors) do UI.AddValue(c.name, c.kills) end
        GameTooltip:AddLine("Click for the Bounty Board", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    block:SetScript("OnLeave", GameTooltip_Hide)
    function block:Update(withTop)
        local progress = ns.GetBountyProgress()
        if not progress then
            self.name:SetText("|cff999999Weekly bounties are for guilds.|r")
            self.bar:Hide()
            self.details:SetText("")
            return
        end
        self.bar:Show()
        local bounty = progress.current.bounty
        self.name:SetText(("|cffffd100%s|r  |cff999999%s|r"):format(bounty.name, bounty.desc))
        self.bar:SetProgress(progress.total / progress.goal,
            progress.rewarded and ("%d/%d - done!"):format(progress.total, progress.goal) or ("%d/%d"):format(progress.total, progress.goal))
        local parts = { ("You %d (share: %d)"):format(progress.mine, progress.needed), "resets in " .. ns.BountyTimeLeft(progress.current.resetsIn) }
        if withTop then
            local top = {}
            for i = 1, math.min(3, #progress.contributors) do
                top[i] = ("%s %d"):format(progress.contributors[i].name, progress.contributors[i].kills)
            end
            if #top > 0 then table.insert(parts, 1, "Top: " .. table.concat(top, ", ")) end
        end
        local nextWeek = ns.GetBounty(1)
        if nextWeek then parts[#parts + 1] = "next week: " .. nextWeek.bounty.name end
        self.details:SetText(table.concat(parts, "  |cff666666-|r  "))
    end
    return block
end

-- Overview ----------------------------------------------------------------------------------

-- The character on the right, the rest of the page to its left.
-- As wide as the "whose stats" arrows above it (two arrows, 2px gaps, the name; they sit 10px from
-- the edge, the model box 12px), so their left edges line up.
local MODEL_WIDTH = UI.VIEWING_WIDTH + 2 * UI.ARROW_SIZE + 2 * 2 + 10 - 12
local LEFT_WIDTH = WIDTH - MODEL_WIDTH - 36
local MODEL_HEIGHT = 250  -- the model at the top of its column; below it the buttons, then room for more

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

-- A character in their gear (LoadCharacter). Drag to turn, hover for the items.
-- box:SetPlayer(key) with key nil for you or a key in KillTrackerFriends.
local function CharacterModel(page)
    local box = CreateFrame("Frame", nil, page, "BackdropTemplate")
    box:SetPoint("TOPRIGHT", -12, -44)
    -- Just tall enough for the model, the two text lines and the buttons, with an even margin below them.
    box:SetSize(MODEL_WIDTH, MODEL_HEIGHT + 116)
    box:SetBackdrop(UI.INSET_BACKDROP)
    box:SetBackdropColor(0, 0, 0, 0.5)

    local model = CreateFrame("DressUpModel", nil, box)
    -- The model at the top, its level and item level and the view buttons right under it; the rest of the box
    -- is left free (box.spare, below the box) for more later.
    model:SetPoint("TOPLEFT", 4, -4)
    model:SetPoint("TOPRIGHT", -4, -4)
    model:SetHeight(MODEL_HEIGHT)
    model:EnableMouse(true)

    -- The background behind the model: one from a minted picture (ns.GetModelBackdrop). The pictures are square
    -- and the model area is taller than wide, so the sides are cropped to fill it without stretching.
    local backdrop = box:CreateTexture(nil, "ARTWORK")
    backdrop:SetPoint("TOPLEFT", model, "TOPLEFT")
    backdrop:SetPoint("BOTTOMRIGHT", model, "BOTTOMRIGHT")
    local crop = (1 - (MODEL_WIDTH - 8) / MODEL_HEIGHT) / 2
    backdrop:SetTexCoord(crop, 1 - crop, 0, 1)
    backdrop:Hide()

    box.info = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    box.info:SetPoint("TOP", model, "BOTTOM", 0, -4)
    box.itemLevel = box:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    box.itemLevel:SetPoint("TOP", box.info, "BOTTOM", 0, -2)
    -- The gear and professions views (box.OnViewClick(view), set by the page); clicking the model opens gear.
    local function ViewButton(view, label, anchor, gap)
        local button = CreateFrame("Button", nil, box, "UIPanelButtonTemplate")
        button:SetSize(MODEL_WIDTH - 24, 30)
        UI.SkinButton(button)  -- the wooden buttons (being tried out here first)
        button:SetPoint("TOP", anchor, "BOTTOM", 0, -gap)
        button:SetText(label)
        button:SetScript("OnClick", function() if box.OnViewClick then box.OnViewClick(view) end end)
        return button
    end
    box.gearButton = ViewButton("gear", "Gear", box.itemLevel, 8)
    box.professionsButton = ViewButton("professions", "Professions", box.gearButton, 4)
    box.spare = CreateFrame("Frame", nil, page)
    box.spare:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -8)
    box.spare:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -12, 12)
    box.OnGearClick = function() if box.OnViewClick then box.OnViewClick("gear") end end
    box.empty = box:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    box.empty:SetPoint("CENTER", model, "CENTER")
    box.empty:SetWidth(MODEL_WIDTH - 20)
    box.empty:SetText("No character synced yet. It shows once they log in with SOLC 0.37.0 or newer.")

    local key, shownGear  -- who is shown, and the synced gear table drawn for them
    local facing = 0
    local zoom = 0  -- mouse wheel: added to the race's camera distance, MIN_ZOOM..MAX_ZOOM

    local function Gear()
        local friend = key and KillTrackerFriends[key]
        return friend and friend.gear
    end

    local function ApplyZoom()
        if model.SetCamDistanceScale then model:SetCamDistanceScale(CharacterCamera(key, zoom)) end
    end

    local function Load()
        shownGear = Gear()
        model:Show()
        local shown = LoadCharacter(model, key)
        model:SetShown(shown)
        box.empty:SetShown(not shown)
        model:SetFacing(facing)
        ApplyZoom()
    end

    -- Scroll to zoom.
    model:EnableMouseWheel(true)
    model:SetScript("OnMouseWheel", function(_, delta)
        zoom = math.max(MIN_ZOOM, math.min(MAX_ZOOM, zoom - delta * 0.1))
        ApplyZoom()
    end)

    local function UpdateInfo()
        local level, class, classFile, itemLevel
        if not key then
            level, class = UnitLevel("player"), UnitClass("player")
            classFile = select(2, UnitClass("player"))
            itemLevel = GetAverageItemLevel and select(2, GetAverageItemLevel())
        else
            local gear = Gear()
            if gear then
                level, classFile = gear.level, gear.class
                class = classFile and LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classFile] or classFile
                local sum, count, complete = 0, 0, true
                for slot, itemID in pairs(gear.items) do
                    if not NO_ITEM_LEVEL[slot] then
                        local ilvl = select(4, GetItemInfo(itemID))
                        if ilvl then sum, count = sum + ilvl, count + 1 else complete = false end
                    end
                end
                if complete and count > 0 then itemLevel = sum / count end
            end
        end
        local color = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
        box.info:SetText(level and class and ("Level %d %s"):format(level,
            color and color:WrapTextInColorCode(class) or class) or "")
        box.itemLevel:SetText(itemLevel and ("Item level %d"):format(itemLevel) or "")
    end

    local function UpdateBackdrop()
        local option = ns.GetModelBackdrop and ns.GetModelBackdrop(key)
        if option then
            backdrop:SetTexture(ns.MintTexture(option, {}))
            backdrop:Show()
        else
            backdrop:Hide()
        end
    end

    -- Reloads only for another player or new gear, so turning it sticks while the page refreshes.
    local loaded
    function box:SetPlayer(newKey)
        if loaded and newKey == key and Gear() == shownGear then
            UpdateInfo()  -- item levels may have loaded since
            UpdateBackdrop()
            return
        end
        loaded, key = true, newKey
        Load()
        UpdateInfo()
        UpdateBackdrop()
    end

    -- Drag to turn; a click without dragging opens the gear details.
    local startX
    model:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        local lastX = GetCursorPosition()
        startX = lastX
        self:SetScript("OnUpdate", function()
            local x = GetCursorPosition()
            facing = facing + (x - lastX) / 80
            lastX = x
            self:SetFacing(facing)
        end)
    end)
    model:SetScript("OnMouseUp", function(self, button)
        self:SetScript("OnUpdate", nil)
        if button == "LeftButton" and startX and math.abs(GetCursorPosition() - startX) < 4 and box.OnGearClick then
            box.OnGearClick()
        elseif button == "RightButton" and not key then
            PickBackdrop(self)
        end
        startX = nil
    end)
    model:SetScript("OnHide", function(self) self:SetScript("OnUpdate", nil) end)

    model:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Click for gear details")
        GameTooltip:AddLine("Drag to turn, scroll to zoom", 0.6, 0.6, 0.6)
        if not key then GameTooltip:AddLine("Right-click to pick a background", 0.6, 0.6, 0.6) end
        local gear = Gear()
        if key and gear and not NearbyUnit(gear.guid) then
            GameTooltip:AddLine("Default hair and face - their real look shows when they're nearby.", 0.6, 0.6, 0.6, true)
        end
        GameTooltip:Show()
    end)
    model:SetScript("OnLeave", GameTooltip_Hide)

    box:SetScript("OnShow", function() if loaded then Load() UpdateInfo() end end)
    box:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    box:RegisterUnitEvent("UNIT_MODEL_CHANGED", "player")
    box:SetScript("OnEvent", function(self)
        if self:IsVisible() and loaded and not key then Load() UpdateInfo() end
    end)
    -- The page is usually created while already showing, so the model may not have its size at the
    -- first SetPlayer; load once more on the next frame.
    C_Timer.After(0, function() if loaded then Load() UpdateInfo() end end)
    return box
end

-- Gear details: every slot with icon, name and item level (hover for the full tooltip), and the stats the
-- gear adds up to. Shown in place of the Overview's left side; panel:SetPlayer(key) like the model.
local SLOT_NAMES = {
    "HEADSLOT", "NECKSLOT", "SHOULDERSLOT", "SHIRTSLOT", "CHESTSLOT", "WAISTSLOT", "LEGSSLOT", "FEETSLOT",
    "WRISTSLOT", "HANDSSLOT", "FINGER0SLOT", "FINGER1SLOT", "TRINKET0SLOT", "TRINKET1SLOT", "BACKSLOT",
    "MAINHANDSLOT", "SECONDARYHANDSLOT", "RANGEDSLOT", "TABARDSLOT",
}
local GEAR_COLUMNS = { { 1, 2, 3, 15, 5, 4, 19, 9, 16, 17 }, { 10, 6, 7, 8, 11, 12, 13, 14, 18 } }
local STAT_ORDER = { "ITEM_MOD_STAMINA_SHORT", "ITEM_MOD_STRENGTH_SHORT", "ITEM_MOD_AGILITY_SHORT",
    "ITEM_MOD_INTELLECT_SHORT", "ITEM_MOD_SPIRIT_SHORT", "RESISTANCE0_NAME" }
local MAX_STAT_LINES = 16
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

local function GearPanel(page, width)
    width = width or LEFT_WIDTH
    local panel = CreateFrame("Frame", nil, page)
    panel:SetPoint("TOPLEFT", 0, -44)
    panel:SetSize(width + 12, UI.PAGE_HEIGHT - 56)
    panel:Hide()
    UI.CreateSection(panel, "Gear", 4)
    local back = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    back:SetSize(70, 20)
    back:SetPoint("TOPRIGHT", 0, 0)
    back:SetText("Back")
    back:SetScript("OnClick", function() if panel.OnBack then panel.OnBack() end end)

    local key
    local columnWidth = (width - 8) / 2
    local cells = {}
    for c, slots in ipairs(GEAR_COLUMNS) do
        for r, slot in ipairs(slots) do
            local cell = CreateFrame("Button", nil, panel)
            cell:SetSize(columnWidth, 18)
            cell:SetPoint("TOPLEFT", 12 + (c - 1) * (columnWidth + 8), -24 - (r - 1) * 20)
            cell:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
            cell.icon = cell:CreateTexture(nil, "ARTWORK")
            cell.icon:SetSize(16, 16)
            cell.icon:SetPoint("LEFT")
            cell.level = cell:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            cell.level:SetPoint("RIGHT", -2, 0)
            cell.name = cell:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            cell.name:SetPoint("LEFT", cell.icon, "RIGHT", 4, 0)
            cell.name:SetPoint("RIGHT", cell.level, "LEFT", -4, 0)
            cell.name:SetJustifyH("LEFT")
            cell.name:SetWordWrap(false)
            cell.slot = slot
            cell:SetScript("OnEnter", function(self)
                if not self.item then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                -- No "currently equipped" comparison: it compares with your gear, not theirs.
                self.compared = GameTooltip.supportsItemComparison
                GameTooltip.supportsItemComparison = false
                if key then GameTooltip:SetHyperlink(self.item) else GameTooltip:SetInventoryItem("player", self.slot) end
                GameTooltip:Show()
                for _, shopping in ipairs({ ShoppingTooltip1, ShoppingTooltip2 }) do shopping:Hide() end
            end)
            cell:SetScript("OnLeave", function(self)
                GameTooltip.supportsItemComparison = self.compared
                GameTooltip_Hide()
            end)
            cells[#cells + 1] = cell
        end
    end

    local statsTop = 24 + 10 * 20 + 10
    UI.CreateSection(panel, "Stats from gear", statsTop)
    panel.statsNote = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    panel.statsNote:SetPoint("TOPRIGHT", 0, -statsTop - 2)
    local statLines = {}
    for i = 1, MAX_STAT_LINES do
        local line = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        local column, row = (i - 1) % 2, math.floor((i - 1) / 2)
        line:SetPoint("TOPLEFT", 14 + column * (columnWidth + 8), -statsTop - 20 - row * 14)
        line:SetWidth(columnWidth)
        line:SetJustifyH("LEFT")
        line:SetWordWrap(false)
        statLines[i] = line
    end
    panel.empty = panel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    panel.empty:SetPoint("TOP", 0, -60)
    panel.empty:SetWidth(width - 20)
    panel.empty:SetText("No gear synced yet. It shows once they log in with SOLC 0.37.0 or newer.")

    -- The item in a slot: item link or string, or nil.
    local function SlotItem(slot)
        if not key then return GetInventoryItemLink("player", slot) end
        local friend = KillTrackerFriends[key]
        return ns.GearItemString(friend and friend.gear, slot)
    end

    function panel:Refresh()
        local friend = key and KillTrackerFriends[key]
        local hasGear = not key or (friend and friend.gear) ~= nil
        panel.empty:SetShown(not hasGear)
        local totals, loading = {}, false
        for _, cell in ipairs(cells) do
            local item = hasGear and SlotItem(cell.slot)
            cell.item = item
            cell:SetShown(hasGear)
            if item then
                local name, _, quality, itemLevel, _, _, _, _, _, texture = GetItemInfo(item)
                local itemID = tonumber(item:match("item:(%d+)"))
                if not name then
                    loading = true
                    if C_Item and C_Item.RequestLoadItemDataByID and itemID then C_Item.RequestLoadItemDataByID(itemID) end
                end
                cell.icon:SetTexture(texture or (itemID and GetItemIcon and GetItemIcon(itemID)) or "Interface\\Icons\\INV_Misc_QuestionMark")
                cell.icon:SetDesaturated(false)
                cell.name:SetText(name or ("item %s"):format(itemID or "?"))
                local r, g, b = 1, 1, 1
                if quality and GetItemQualityColor then r, g, b = GetItemQualityColor(quality) end
                cell.name:SetTextColor(r, g, b)
                cell.level:SetText(itemLevel and not NO_ITEM_LEVEL[cell.slot] and itemLevel or "")
                local stats = GetItemStats and GetItemStats(item)
                if stats then
                    for stat, value in pairs(stats) do
                        if not stat:find("DAMAGE_PER_SECOND") then
                            local label = StatLabel(stat)  -- by name: the same stat can come under two keys
                            totals[label] = (totals[label] or 0) + value
                        end
                    end
                elseif name then
                    loading = true
                end
            else
                local emptyTexture = GetInventorySlotInfo and select(2, GetInventorySlotInfo(SLOT_NAMES[cell.slot]))
                cell.icon:SetTexture(emptyTexture)
                cell.icon:SetDesaturated(true)
                cell.name:SetText(_G[SLOT_NAMES[cell.slot]] or "")
                cell.name:SetTextColor(0.4, 0.4, 0.4)
                cell.level:SetText("")
            end
        end

        -- totals are by name: the main stats first, then the rest alphabetically.
        local order, known = {}, {}
        for _, statKey in ipairs(STAT_ORDER) do
            local label = StatLabel(statKey)
            if totals[label] then order[#order + 1] = label end
            known[label] = true
        end
        local rest = {}
        for label in pairs(totals) do if not known[label] then rest[#rest + 1] = label end end
        table.sort(rest)
        for _, label in ipairs(rest) do order[#order + 1] = label end
        local armor = StatLabel("RESISTANCE0_NAME")
        for i, line in ipairs(statLines) do
            local label = order[i]
            if label and i == MAX_STAT_LINES and #order > MAX_STAT_LINES then
                line:SetText(("|cff999999+%d more (hover the items)|r"):format(#order - MAX_STAT_LINES + 1))
            elseif label then
                local value = math.floor(totals[label] + 0.5)
                line:SetText(("%s%d|r %s"):format(label == armor and "|cffffffff" or "|cff40ff40+", value, label))
            else
                line:SetText("")
            end
            line:SetShown(hasGear)
        end
        panel.statsNote:SetText(hasGear and (loading and "loading items..." or (#order == 0 and "none" or "")) or "")
    end

    function panel:SetPlayer(newKey)
        key = newKey
        if self:IsShown() then self:Refresh() end
    end

    -- Item info arrives later for items this client hasn't seen yet; your own gear can change while open.
    local pending
    panel:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    panel:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    panel:SetScript("OnEvent", function(self)
        if not self:IsVisible() or pending then return end
        pending = true
        C_Timer.After(0.2, function()
            pending = nil
            if self:IsVisible() then self:Refresh() end
        end)
    end)
    panel:SetScript("OnShow", function(self) self:Refresh() end)
    return panel
end
UI.CreateGearPanel = GearPanel  -- (page, width): also on the new Overview (OverviewCard.lua)

-- Professions: each profession's level, and the known recipes of the one picked (hover for the recipe).
-- Shown in place of the Overview's left side; panel:SetPlayer(key) like the model.
local MAX_PROFESSIONS = 5

local function ProfessionsPanel(page)
    local panel = CreateFrame("Frame", nil, page)
    panel:SetPoint("TOPLEFT", 0, -44)
    panel:SetSize(LEFT_WIDTH + 12, UI.PAGE_HEIGHT - 56)
    panel:Hide()
    UI.CreateSection(panel, "Professions", 4)
    local back = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    back:SetSize(70, 20)
    back:SetPoint("TOPRIGHT", 0, 0)
    back:SetText("Back")
    back:SetScript("OnClick", function() if panel.OnBack then panel.OnBack() end end)

    local key, selected  -- whose professions, and the skill line whose recipes are listed
    local rows = {}
    for i = 1, MAX_PROFESSIONS do
        local row = CreateFrame("Button", nil, panel)
        row:SetSize(LEFT_WIDTH, 20)
        row:SetPoint("TOPLEFT", 12, -24 - (i - 1) * 22)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(18, 18)
        row.icon:SetPoint("LEFT")
        row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.name:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
        row.name:SetWidth(108)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)
        row.bar = UI.CreateBar(row, LEFT_WIDTH - 132, 0.3, 0.6, 1)
        row.bar:SetPoint("RIGHT")
        row:SetScript("OnClick", function(self)
            selected = self.line
            panel:Refresh()
        end)
        rows[i] = row
    end

    local recipesTop = 24 + MAX_PROFESSIONS * 22 + 8
    panel.recipesHeading = UI.CreateSection(panel, "", recipesTop)
    local scroll = UI.CreateScroll(panel, recipesTop + 18)
    local listWidth = LEFT_WIDTH + 12 - 40  -- the scroll frame's width: the panel minus its scrollbar margins
    scroll.content:SetWidth(listWidth)
    local recipeRows = {}
    panel.empty = panel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    panel.empty:SetPoint("TOPLEFT", 16, -recipesTop - 24)
    panel.empty:SetWidth(LEFT_WIDTH - 20)
    panel.empty:SetJustifyH("LEFT")

    function panel:Refresh()
        local professions = ns.GetProfessions(key)
        local list = professions.list
        local found = false
        for _, prof in ipairs(list) do if prof.line == selected then found = true end end
        if not found then  -- the first with recipes, else the first
            selected = list[1] and list[1].line
            for _, prof in ipairs(list) do
                if professions.recipes[prof.line] then selected = prof.line break end
            end
        end

        local selectedName
        for i, row in ipairs(rows) do
            local prof = list[i]
            row:SetShown(prof ~= nil)
            if prof then
                row.line = prof.line
                row.icon:SetTexture(prof.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
                row.name:SetText(prof.name)
                row.bar:SetProgress(prof.max > 0 and prof.rank / prof.max or 0, ("%d/%d"):format(prof.rank, prof.max))
                if prof.line == selected then
                    row:LockHighlight()
                    selectedName = prof.name
                else
                    row:UnlockHighlight()
                end
            end
        end

        local recipes = {}
        for _, id in ipairs(selected and professions.recipes[selected] or {}) do
            local name, icon = ns.RecipeInfo(id)
            if not name and C_Spell and C_Spell.RequestLoadSpellData then C_Spell.RequestLoadSpellData(id) end
            recipes[#recipes + 1] = { id = id, name = name or ("Recipe %d"):format(id), icon = icon }
        end
        table.sort(recipes, function(a, b) return a.name < b.name end)
        panel.recipesHeading:SetText(selectedName and ("%s recipes (%d)"):format(selectedName, #recipes) or "")

        for i, recipe in ipairs(recipes) do
            local row = recipeRows[i]
            if not row then
                row = UI.CreateRow(scroll.content, i, listWidth)
                row:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetSpellByID(self.recipeID)
                    GameTooltip:Show()
                end)
                row:SetScript("OnLeave", GameTooltip_Hide)
                recipeRows[i] = row
            end
            row.recipeID = recipe.id
            row:SetBar(0)
            row.label:SetText((recipe.icon and ("|T%s:14|t "):format(recipe.icon) or "") .. recipe.name)
            row.count:SetText("")
            row:Show()
        end
        for i = #recipes + 1, #recipeRows do recipeRows[i]:Hide() end
        scroll.content:SetHeight(math.max(1, #recipes * UI.ROW_HEIGHT))

        local empty
        if #list == 0 then
            empty = key and "No professions synced yet. They show once they log in with SOLC 0.37.0 or newer."
                or "You have no professions."
        elseif #recipes == 0 and selectedName then
            empty = key and ("Their %s recipes show once they open their %s window with SOLC 0.37.0 or newer."):format(selectedName, selectedName)
                or ("Open your %s window once to save its recipes."):format(selectedName)
        end
        panel.empty:SetText(empty or "")
        panel.empty:SetShown(empty ~= nil)
    end

    function panel:SetPlayer(newKey)
        if newKey ~= key then selected = nil end
        key = newKey
        if self:IsShown() then self:Refresh() end
    end

    -- Recipe names load a moment later for spells this client hasn't seen yet.
    local pending
    panel:RegisterEvent("SPELL_DATA_LOAD_RESULT")
    panel:SetScript("OnEvent", function(self)
        if not self:IsVisible() or pending then return end
        pending = true
        C_Timer.After(0.3, function()
            pending = nil
            if self:IsVisible() then self:Refresh() end
        end)
    end)
    panel:SetScript("OnShow", function(self) self:Refresh() end)
    return panel
end

-- The showcase: up to ns.SHOWCASE_SIZE pictures someone picked for their Overview (Minting.lua).
-- row:Update(key) with key nil for you or a key in KillTrackerFriends.
-- Tiles fill the row with the same 8px gaps as the stat cards above (6px of each tile is its border).
local SHOWCASE_PICTURE = math.floor((LEFT_WIDTH - (ns.SHOWCASE_SIZE - 1) * 8) / ns.SHOWCASE_SIZE) - 6
local SHOWCASE_TOP = 120

-- Tiles framed in their rarity's color; an empty one of yours shows a +.
local function ShowcaseRow(parent, y)
    local row = { tiles = {} }
    local size = SHOWCASE_PICTURE + 6
    local gap = (LEFT_WIDTH - ns.SHOWCASE_SIZE * size) / (ns.SHOWCASE_SIZE - 1)
    for i = 1, ns.SHOWCASE_SIZE do
        local tile = CreateFrame("Button", nil, parent, "BackdropTemplate")
        tile:SetSize(size, size)
        tile:SetPoint("TOPLEFT", 12 + (i - 1) * (size + gap), -y)
        tile:SetBackdrop(UI.INSET_BACKDROP)
        tile:SetBackdropColor(0, 0, 0, 0.6)
        tile:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        tile.canvas = CreateFrame("Frame", nil, tile)
        tile.canvas:SetSize(SHOWCASE_PICTURE, SHOWCASE_PICTURE)
        tile.canvas:SetPoint("CENTER")
        tile.empty = tile:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
        tile.empty:SetPoint("CENTER")
        tile.empty:SetText("+")
        tile.empty:SetTextColor(0.5, 0.5, 0.5)
        tile:SetScript("OnClick", function(self)
            if self.mint then
                ns.ShowMint(self.mint, row.key and Ambiguate(row.key, "short") or nil)
            elseif not row.key then
                ns.OpenPage("collection")  -- your pictures, to pick one
            end
        end)
        tile:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if self.mint then
                local rarity = ns.MintRarity(self.mint.traits)
                GameTooltip:AddLine(("Picture #%d"):format(self.mint.number))
                GameTooltip:AddLine(Capitalize(rarity), ns.RarityRGB(rarity))
                for _, trait in ipairs(ns.MintTraits(self.mint.traits)) do
                    GameTooltip:AddDoubleLine(trait[1], ("|c%s%s|r"):format(ns.RARITY_COLORS[trait[3]], trait[2]))
                end
                GameTooltip:AddLine("Click to view", 0.6, 0.6, 0.6)
            elseif not row.key then
                GameTooltip:AddLine("Showcase")
                GameTooltip:AddLine(("Open one of your pictures and click \"Show on your Overview\" (up to %d)."):format(ns.SHOWCASE_SIZE),
                    1, 1, 1, true)
                GameTooltip:AddLine("Click to see your pictures", 0.6, 0.6, 0.6)
            else
                GameTooltip:AddLine("Nothing showcased here yet.")
            end
            GameTooltip:Show()
        end)
        tile:SetScript("OnLeave", GameTooltip_Hide)
        row.tiles[i] = tile
    end

    function row:Update(key)
        self.key = key
        local pictures = ns.GetShowcase(key)
        for i, tile in ipairs(self.tiles) do
            local mint = pictures[i]
            tile.mint = mint
            tile.canvas:SetShown(mint ~= nil)
            tile.empty:SetShown(mint == nil and key == nil)
            if mint then
                if tile.drawn ~= mint.traits then  -- only when it shows other traits
                    ns.RenderMint(tile.canvas, mint.traits)
                    tile.drawn = mint.traits
                end
                tile:SetBackdropBorderColor(ns.RarityRGB(ns.MintRarity(mint.traits)))
            else
                tile:SetBackdropBorderColor(0.4, 0.4, 0.4)
            end
        end
    end
    return row
end

-- Overview sections that can take over the space below the showcase (page:Expand).
local EXPANDED_TOP = SHOWCASE_TOP + SHOWCASE_PICTURE + 6 + 12  -- below the showcase
-- Each section is a panel: a title bar (SECTION_BAR tall) and under it a box holding its content, inset
-- SECTION_PAD; SECTION_GAP between panels.
local SECTION_BAR, SECTION_PAD, SECTION_GAP = 20, 4, 6
local EXPANDED_ROWS = math.floor((UI.PAGE_HEIGHT - 8 - EXPANDED_TOP - SECTION_BAR - 2 * SECTION_PAD) / UI.ROW_HEIGHT)

local PANEL_BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 },
}

-- The box under a section's title bar, behind its content. box:Place(y, height).
local function SectionBox(parent)
    local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    box:SetFrameLevel(parent:GetFrameLevel())  -- behind the content, which sits a level above the parent
    box:SetBackdrop(PANEL_BACKDROP)
    box:SetBackdropColor(0.11, 0.12, 0.14, 0.75)  -- dark slate
    box:SetBackdropBorderColor(0.45, 0.45, 0.48, 0.9)
    function box:Place(y, height)
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", 8, -y)
        self:SetSize(LEFT_WIDTH + 8, height)
    end
    return box
end

-- A gold section title you can click, with a +/- on the right. header:Place(y, expanded).
local function ExpandHeader(parent, text, onClick)
    local header = CreateFrame("Button", nil, parent, "BackdropTemplate")
    header:SetSize(LEFT_WIDTH + 8, SECTION_BAR)
    header:SetBackdrop(PANEL_BACKDROP)
    header:SetBackdropColor(0.04, 0.04, 0.05, 0.95)
    header:SetBackdropBorderColor(0.75, 0.62, 0.3, 0.9)  -- muted gold, like the titles
    header.text = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header.text:SetPoint("LEFT", 6, 0)
    header.text:SetText(text)
    header.icon = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")  -- text stays sharp at any size
    header.icon:SetPoint("RIGHT", -6, 0)
    header:SetScript("OnClick", onClick)
    header:SetScript("OnEnter", function(self)
        self.text:SetTextColor(1, 1, 1)
        self.icon:SetTextColor(1, 1, 1)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(self.expanded and "Click to show all sections" or "Click to show more")
        GameTooltip:Show()
    end)
    header:SetScript("OnLeave", function(self)
        self.text:SetTextColor(1, 0.82, 0)
        self.icon:SetTextColor(1, 0.82, 0)
        GameTooltip_Hide()
    end)
    function header:Place(y, expanded)
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", 8, -y)
        self.expanded = expanded
        self.icon:SetText(expanded and "-" or "+")
    end
    return header
end

-- A stat card: an icon on the left, the value and its label beside it.
local CARD_ICON = 34
local ICONS = "Interface\\AddOns\\SOLC\\Media\\Icons\\"  -- painted crayon icons (tools/make-role-icons.js)

local function StatCard(page, index, label, icon)
    local card = CreateFrame("Frame", nil, page, "BackdropTemplate")
    local width = (LEFT_WIDTH - 3 * 8) / 4
    card:SetSize(width, 46)
    card:SetPoint("TOPLEFT", 12 + (index - 1) * (width + 8), -48)
    card:SetBackdrop(UI.INSET_BACKDROP)
    card:SetBackdropColor(0, 0, 0, 0.5)
    card.icon = card:CreateTexture(nil, "ARTWORK")
    card.icon:SetSize(CARD_ICON, CARD_ICON)
    card.icon:SetPoint("LEFT", 5, 0)
    card.icon:SetTexture(icon)
    -- The value with its label under it, as one block beside the icon, centred on the card's height.
    card.value = card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    card.value:SetPoint("BOTTOMLEFT", card.icon, "RIGHT", 8, -1)
    card.value:SetPoint("RIGHT", -6, 0)
    card.value:SetJustifyH("LEFT")
    card.label = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    card.label:SetPoint("TOPLEFT", card.icon, "RIGHT", 8, -1)
    card.label:SetPoint("RIGHT", -6, 0)
    card.label:SetJustifyH("LEFT")
    card.label:SetWordWrap(false)
    card.label:SetText(label)
    return card
end

ns.RegisterPage({
    key = "overview", label = "Overview", section = "me", order = 1,
    create = function(parent)
        local page = NewPage(parent, "Overview")
        -- The left side: stats and lists, swapped for the gear details (page.gear).
        local left = CreateFrame("Frame", nil, page)
        left:SetAllPoints()
        page.left = left
        page.cards = {
            StatCard(left, 1, "points", ICONS .. "Points"),
            StatCard(left, 2, "kills", ICONS .. "Kills"),
            StatCard(left, 3, "achievements", ICONS .. "Achievements"),
            StatCard(left, 4, "PvP kills", ICONS .. "PvP"),
        }
        UI.CreateSection(left, "Showcase", SHOWCASE_TOP - 18)
        page.showcase = ShowcaseRow(left, SHOWCASE_TOP)
        page.bountyHeader = ExpandHeader(left, "Guild bounty", function() page:Expand("bounty") end)
        page.bountyBox, page.closeBox, page.recentBox = SectionBox(left), SectionBox(left), SectionBox(left)
        local contentTop = EXPANDED_TOP + SECTION_BAR + SECTION_PAD
        page.bounty = BountyBlock(left, contentTop, LEFT_WIDTH)
        page.contributors = RowStack(left, contentTop + 62, EXPANDED_ROWS - 4, LEFT_WIDTH)
        page.closeHeader = ExpandHeader(left, "Almost there", function() page:Expand("close") end)
        page.close = RowStack(left, EXPANDED_TOP, EXPANDED_ROWS, LEFT_WIDTH)
        page.recentHeader = ExpandHeader(left, "Recent highlights", function() page:Expand("recent") end)
        page.recent = RowStack(left, EXPANDED_TOP, EXPANDED_ROWS, LEFT_WIDTH)
        page.recentEmpty = left:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        page.recentEmpty:SetWidth(LEFT_WIDTH - 8)
        page.recentEmpty:SetJustifyH("LEFT")
        page.recentEmpty:SetText("Nothing yet - leaders, rares, achievements and pictures show up here.")

        -- Clicking a section's title gives it the space of all three; clicking again shares it again.
        function page:Expand(section, initial)
            self.expanded = self.expanded ~= section and section or nil
            local e = self.expanded
            local function Header(header, which, y)
                header:SetShown(e == nil or e == which)
                header:Place(e == which and EXPANDED_TOP or y, e == which)
            end
            -- Shared: the bounty panel, then the two list panels splitting the rest of the page's height.
            local inner = SECTION_BAR + SECTION_PAD  -- from a panel's top to its content
            local bountyHeight = 58 + 2 * SECTION_PAD
            local closeY = EXPANDED_TOP + SECTION_BAR + bountyHeight + SECTION_GAP
            local listChrome = SECTION_BAR + 2 * SECTION_PAD  -- a list panel without its rows
            local rows = math.max(1, math.floor((UI.PAGE_HEIGHT - 8 - closeY - 2 * listChrome - SECTION_GAP) / 2 / UI.ROW_HEIGHT))
            local recentY = closeY + listChrome + rows * UI.ROW_HEIGHT + SECTION_GAP
            local bottom = UI.PAGE_HEIGHT - 8  -- an expanded panel reaches down to here
            Header(self.bountyHeader, "bounty", EXPANDED_TOP)
            Header(self.closeHeader, "close", closeY)
            Header(self.recentHeader, "recent", recentY)
            local function Box(box, which, y, height)
                box:SetShown(e == nil or e == which)
                if e == which then
                    box:Place(EXPANDED_TOP + SECTION_BAR, bottom - EXPANDED_TOP - SECTION_BAR)
                else
                    box:Place(y + SECTION_BAR, height)
                end
            end
            Box(self.bountyBox, "bounty", EXPANDED_TOP, bountyHeight)
            Box(self.closeBox, "close", closeY, rows * UI.ROW_HEIGHT + 2 * SECTION_PAD)
            Box(self.recentBox, "recent", recentY, rows * UI.ROW_HEIGHT + 2 * SECTION_PAD)
            self.bounty:SetShown(e == nil or e == "bounty")
            self.contributors.holder:SetShown(e == "bounty")
            self.close.holder:SetShown(e == nil or e == "close")
            self.close:Place(e == "close" and EXPANDED_TOP + inner or closeY + inner, e == "close" and EXPANDED_ROWS or rows)
            self.recent.holder:SetShown(e == nil or e == "recent")
            self.recent:Place(e == "recent" and EXPANDED_TOP + inner or recentY + inner, e == "recent" and EXPANDED_ROWS or rows)
            self.recentEmpty:ClearAllPoints()
            self.recentEmpty:SetPoint("TOPLEFT", 16, -((e == "recent" and EXPANDED_TOP or recentY) + inner + 4))
            if not initial then ns.OpenPage("overview") end  -- refill the rows
        end
        page:Expand(nil, true)
        page.model = CharacterModel(page)
        page.gear = GearPanel(page)
        page.professions = ProfessionsPanel(page)
        -- The left side shows the overview, the gear (page.gear) or the professions (page.professions).
        local current
        local function ShowView(view)
            current = view
            page.left:SetShown(view == nil)
            page.gear:SetShown(view == "gear")
            page.professions:SetShown(view == "professions")
            page.model.gearButton:SetText(view == "gear" and "Overview" or "Gear")
            page.model.professionsButton:SetText(view == "professions" and "Overview" or "Professions")
        end
        page.model.OnViewClick = function(view) ShowView(current ~= view and view or nil) end
        page.gear.OnBack = function() ShowView(nil) end
        page.professions.OnBack = function() ShowView(nil) end
        page.switcher = UI.CreateViewSwitcher(page)
        return page
    end,
    -- Yours, or a synced guildmate's (picked with the arrows or on the Members page).
    refresh = function(page)
        local key = ns.GetViewing()
        local source = key and KillTrackerFriends[key] or KillTrackerDB
        local name = key and Ambiguate(key, "short") or ns.MyName()
        page.switcher:Update()
        page.model:SetPlayer(key)
        page.gear:SetPlayer(key)
        page.professions:SetPlayer(key)
        page.showcase:Update(key)
        if key then
            page.line:SetText(("%s - updated %s"):format(name, ns.TimeAgo(source.received)))
            page.cards[1].value:SetText(source.earned or 0)
            page.cards[4].value:SetText(source.pvpTotal or 0)
        else
            page.line:SetText(("%s - %d kills this session"):format(name, ns.GetSessionKills()))
            page.cards[1].value:SetText(ns.GetPoints().balance)
            page.cards[4].value:SetText(source.pvp and source.pvp.total or 0)
        end
        page.cards[2].value:SetText(source.total or 0)
        page.cards[3].value:SetText(ns.GetAchievementTotals(source))
        page.bounty:Update(false)
        local bountyProgress = ns.GetBountyProgress()
        local contributors = bountyProgress and bountyProgress.contributors or {}
        local most = contributors[1] and contributors[1].kills or 0
        page.contributors:Set(contributors, function(row, c)
            row.label:SetText(c.name == ns.MyName() and ("|cffffd100%s|r"):format(c.name) or c.name)
            row.count:SetText(c.kills)
            row.bar:SetVertexColor(0.9, 0.7, 0.1, 0.4)
            row:SetBar(most > 0 and c.kills / most or 0)
        end)
        page.recentEmpty:SetShown(false)

        local close = {}
        for _, progress in ipairs(ns.GetAchievementProgress(source)) do
            if progress.next then close[#close + 1] = progress end
        end
        table.sort(close, function(a, b) return a.kills / a.next.kills > b.kills / b.next.kills end)
        page.close:Set(close, function(row, progress)
            row.label:SetText(("%s  |cff999999%s|r"):format(progress.category, progress.next.name or ""))
            row.count:SetText(("%d/%d"):format(progress.kills, progress.next.kills))
            row.bar:SetVertexColor(1, 0.5, 0.1, 0.45)
            row:SetBar(progress.kills / progress.next.kills)
            row:SetScript("OnClick", function() ns.OpenPage("achievements") end)
        end)

        local mine = {}
        for _, item in ipairs(ns.GetFeed()) do
            if item.who == name then mine[#mine + 1] = item end
        end
        page.recent:Set(mine, function(row, item)
            row.label:SetText(item.text)
            row.count:SetText("|cff999999" .. ns.TimeAgo(item.time) .. "|r")
        end, ShowFeedPicture, FeedTooltip)
        page.recentEmpty:SetShown(#mine == 0 and (page.expanded == nil or page.expanded == "recent"))
    end,
})

-- Guild home ------------------------------------------------------------------------------------

ns.RegisterPage({
    key = "home", label = "Home", section = "guild", order = 1,
    create = function(parent)
        local page = NewPage(parent, "Guild")
        UI.CreateSection(page, "This week's bounty", 48)
        page.bounty = BountyBlock(page, 66)
        UI.CreateSection(page, "Guild activity", 136)
        page.feed = ScrollList(page, 154)
        page.empty = page:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        page.empty:SetPoint("TOP", 0, -200)
        page.empty:SetWidth(WIDTH - 60)
        page.empty:SetText("No guild activity yet. Leader kills, rares, achievements, pictures, bounties and guild dungeon clears from everyone using SOLC show up here.")
        return page
    end,
    refresh = function(page)
        local guild = IsInGuild() and GetGuildInfo("player")
        page.title:SetText(guild or "Guild")
        local members = Members()
        page.line:SetText(guild and ("%d member%s using SOLC"):format(#members, #members == 1 and "" or "s")
            or "You're not in a guild. Guild pages show what you and anyone you /kt sync with do.")
        page.bounty:Update(true)
        local feed = ns.GetFeed()
        page.feed:Set(feed, function(row, item)
            row.label:SetText(item.text)
            row.count:SetText("|cff999999" .. ns.TimeAgo(item.time) .. "|r")
        end, ShowFeedPicture, FeedTooltip)
        page.empty:SetShown(#feed == 0)
    end,
})

-- Members ------------------------------------------------------------------------------------------

local OFFICER = "|TInterface\\GroupFrame\\UI-Group-AssistantIcon:12|t"

ns.RegisterPage({
    key = "members", label = "Members", section = "guild", order = 2,
    create = function(parent)
        local page = NewPage(parent, "Members")
        page.sync = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
        page.sync:SetSize(120, 22)
        page.sync:SetPoint("TOPRIGHT", -12, -12)
        page.sync:SetText("Sync with target")
        page.sync:SetScript("OnClick", function() ns.SyncWithTarget() end)
        page.sync:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Sync with target")
            GameTooltip:AddLine("Guildmates sync by themselves. Use this to swap stats with someone outside the guild.", 1, 1, 1, true)
            GameTooltip:Show()
        end)
        page.sync:SetScript("OnLeave", GameTooltip_Hide)
        local columns = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        columns:SetPoint("TOPLEFT", 14, -50)
        columns:SetText("Name")
        page.columns = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        page.columns:SetPoint("TOPRIGHT", -40, -50)
        page.columns:SetText("kills    points    updated")
        page.list = ScrollList(page, 66)
        return page
    end,
    refresh = function(page)
        local members = Members()
        page.line:SetText(("%d using SOLC. Click someone to see their overview."):format(#members))
        page.list:Set(members, function(row, m)
            local rank = ns.GetRank(not m.me and m.key or nil)
            row.label:SetText((m.officer and OFFICER .. " " or "") .. (m.me and ("|cffffd100%s|r (you)"):format(m.name) or m.name)
                .. ("  |cff999999%d %s|r"):format(rank.rank, rank.title))
            row.count:SetText(("%d    |cffffd100%s|r    |cff999999%s|r"):format(m.kills, m.points or "?", m.me and "now" or ns.TimeAgo(m.updated)))
        end, function(m)
            ns.ViewPlayer(not m.me and m.key or nil, "overview")
        end, function(row, m)
            GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
            GameTooltip:AddLine(m.name)
            if m.officer then GameTooltip:AddLine("Guild master or officer", 1, 0.82, 0) end
            UI.AddValue("Kills", m.kills)
            UI.AddValue("Points earned", m.points or "? (older SOLC)")
            local rank = ns.GetRank(not m.me and m.key or nil)
            UI.AddValue("Ogre Rank", ("%d - %s"):format(rank.rank, rank.title))
            UI.AddValue("PvP kills", m.pvp or "?")
            UI.AddValue("Pictures", m.pictures)
            UI.AddValue("This week's bounty", m.bounty)
            if m.version then
                local outdated = not m.me and ns.IsNewerVersion(ns.ADDON_VERSION, m.version)
                UI.AddValue("SOLC version", outdated and ("|cffff6060%s (outdated)|r"):format(m.version) or m.version)
            end
            if not m.me and m.updated then UI.AddValue("Last update", date("%Y-%m-%d %H:%M", m.updated)) end
            GameTooltip:AddLine("Click to see their kills", 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end)
    end,
})

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

local function RefreshCrafters(page)
    local query = strtrim(page.search:GetText() or ""):lower()
    local rows = CraftersRows(query)
    local people = #Crafters()
    page.line:SetText(query == "" and ("Professions of %d player%s using SOLC. Search for a recipe to see who can make it."):format(people, people == 1 and "" or "s")
        or ("%d recipe%s matching \"%s\""):format(#rows, #rows == 1 and "" or "s", query))
    page.list:Set(rows, function(row, entry)
        local names = {}
        for i, person in ipairs(entry.people) do
            if i > 3 then names[#names + 1] = "..." break end
            names[i] = person.rank and ("%s %d"):format(person.name, person.rank) or person.name
        end
        row.label:SetText(("%s%s  |cff999999%s|r"):format(entry.icon and ("|T%s:14|t "):format(entry.icon) or "", entry.name,
            table.concat(names, ", ")))
        row.count:SetText(#entry.people)
    end, nil, function(row, entry)
        GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
        if entry.id then
            GameTooltip:SetSpellByID(entry.id)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Known by")
        else
            GameTooltip:AddLine(entry.name)
        end
        for _, person in ipairs(entry.people) do
            UI.AddValue(person.name, person.rank and ("%d/%d"):format(person.rank, person.max or 0) or "")
        end
        GameTooltip:Show()
    end)
    page.empty:SetShown(#rows == 0)
    page.empty:SetText(query == "" and "No professions yet. They show once guildmates log in with SOLC 0.37.0 or newer."
        or "Nobody knows a recipe by that name yet. Recipes show once their owner has opened that profession's window.")
end

ns.RegisterPage({
    key = "crafters", label = "Crafters", section = "guild", order = 2.5, tabOf = "members",
    create = function(parent)
        local page = NewPage(parent, "Crafters")
        page.search = CreateFrame("EditBox", nil, page, "SearchBoxTemplate")
        page.search:SetSize(220, 20)
        page.search:SetPoint("TOPLEFT", 18, -50)
        page.search:SetAutoFocus(false)
        page.list = ScrollList(page, 80)
        page.empty = page:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        page.empty:SetPoint("TOP", 0, -120)
        page.empty:SetWidth(WIDTH - 60)
        page.search:HookScript("OnTextChanged", function() RefreshCrafters(page) end)
        -- Recipe names load a moment later for spells this client hasn't seen yet.
        local pending
        page:RegisterEvent("SPELL_DATA_LOAD_RESULT")
        page:SetScript("OnEvent", function(self)
            if not self:IsVisible() or pending then return end
            pending = true
            C_Timer.After(0.5, function()
                pending = nil
                if self:IsVisible() then RefreshCrafters(self) end
            end)
        end)
        return page
    end,
    refresh = RefreshCrafters,
})

-- Leaderboard ---------------------------------------------------------------------------------------

local METRICS = {
    { key = "points", label = "Points" }, { key = "kills", label = "Kills" }, { key = "bounty", label = "Bounty" },
    { key = "pvp", label = "PvP" }, { key = "pictures", label = "Pictures" },
}

ns.RegisterPage({
    key = "leaderboard", label = "Leaderboard", section = "guild", order = 3,
    create = function(parent)
        local page = NewPage(parent, "Leaderboard")
        page.metric = "points"
        page.buttons = {}
        local width = (WIDTH - 24 - 4 * 4) / #METRICS
        for i, metric in ipairs(METRICS) do
            local button = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
            button:SetSize(width, 22)
            button:SetPoint("TOPLEFT", 12 + (i - 1) * (width + 4), -48)
            button:SetText(metric.label)
            button:SetScript("OnClick", function() page.metric = metric.key; ns.OpenPage("leaderboard") end)
            page.buttons[metric.key] = button
        end
        page.list = ScrollList(page, 78)
        return page
    end,
    refresh = function(page)
        for key, button in pairs(page.buttons) do
            if key == page.metric then button:LockHighlight() else button:UnlockHighlight() end
        end
        local ranked = {}
        for _, m in ipairs(Members()) do
            if m[page.metric] then ranked[#ranked + 1] = m end
        end
        table.sort(ranked, function(a, b)
            if a[page.metric] ~= b[page.metric] then return a[page.metric] > b[page.metric] end
            return a.name < b.name
        end)
        local best = ranked[1] and ranked[1][page.metric] or 0
        local bounty = ns.GetBounty()
        page.line:SetText(page.metric == "bounty" and bounty and ("This week: %s"):format(bounty.bounty.name)
            or page.metric == "points" and "Points earned, before spending."
            or ("%d players"):format(#ranked))
        page.list:Set(ranked, function(row, m)
            local rank = 0
            for i, other in ipairs(ranked) do if other == m then rank = i end end
            local medal = rank == 1 and "|cffffd100" or rank == 2 and "|cffc0c0c0" or rank == 3 and "|cffcd7f32" or "|cffffffff"
            row.label:SetText(("%s%d.|r  %s"):format(medal, rank, m.me and ("|cffffd100%s|r"):format(m.name) or m.name))
            row.count:SetText(m[page.metric])
            row.bar:SetVertexColor(0.9, 0.7, 0.1, 0.4)
            row:SetBar(best > 0 and m[page.metric] / best or 0)
        end, function(m)
            if m.me then ns.ViewPlayer(nil) else ns.ViewPlayer(m.key) end
        end)
    end,
})

-- Bounties -----------------------------------------------------------------------------------------

ns.RegisterPage({
    key = "bounties", label = "Bounties", section = "guild", order = 4, tabOf = "leaderboard",
    create = function(parent) return ns.EmbedBountyBoard(parent, WIDTH) end,
    refresh = function() if ns.RefreshBountyBoard then ns.RefreshBountyBoard() end end,
})
function ns.ToggleBountyBoard() ns.OpenPage("bounties") end

-- Gallery ------------------------------------------------------------------------------------------

local TILE, TILE_GAP = 96, 12

ns.RegisterPage({
    key = "gallery", label = "Gallery", section = "guild", order = 5,
    create = function(parent)
        local page = NewPage(parent, "Gallery")
        page.scroll = UI.CreateScroll(page, 48)
        page.tiles = {}
        page.empty = page:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        page.empty:SetPoint("TOP", 0, -120)
        page.empty:SetText("No pictures yet. Mint one in Collection.")
        return page
    end,
    refresh = function(page)
        ns.UpdateDuplicates()
        local pictures = {}
        for _, mint in ipairs(KillTrackerDB.mints or {}) do pictures[#pictures + 1] = { mint = mint, owner = ns.MyName(), me = true } end
        for _, friend in ipairs(ns.GetFriends()) do
            for _, mint in pairs(friend.stats.mints or {}) do pictures[#pictures + 1] = { mint = mint, owner = friend.name } end
        end
        table.sort(pictures, function(a, b) return a.mint.time > b.mint.time end)
        page.line:SetText(("%d picture%s minted in the guild, newest first. Every one is unique."):format(#pictures, #pictures == 1 and "" or "s"))
        local perRow = math.floor((WIDTH - 40 + TILE_GAP) / (TILE + TILE_GAP))
        for i, picture in ipairs(pictures) do
            local tile = page.tiles[i]
            if not tile then
                tile = CreateFrame("Button", nil, page.scroll.content, "BackdropTemplate")
                tile:SetSize(TILE + 6, TILE + 34)
                tile:SetBackdrop(UI.INSET_BACKDROP)
                tile:SetBackdropColor(0, 0, 0, 0.6)
                tile:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
                tile.canvas = CreateFrame("Frame", nil, tile)
                tile.canvas:SetSize(TILE, TILE)
                tile.canvas:SetPoint("TOP", 0, -3)
                tile.owner = tile:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                tile.owner:SetPoint("TOP", tile.canvas, "BOTTOM", 0, -3)
                tile.rarity = tile:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
                tile.rarity:SetPoint("TOP", tile.owner, "BOTTOM", 0, -1)
                tile:SetScript("OnClick", function(self)
                    ns.ShowMint(self.picture.mint, not self.picture.me and self.picture.owner or nil)
                end)
                tile:SetScript("OnEnter", function(self)
                    local mint = self.picture.mint
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:AddLine(("%s's picture #%d"):format(self.picture.owner, mint.number))
                    for _, trait in ipairs(ns.MintTraits(mint.traits)) do
                        GameTooltip:AddDoubleLine(trait[1], ("|c%s%s|r"):format(ns.RARITY_COLORS[trait[3]], trait[2]))
                    end
                    UI.AddValue("Minted", date("%Y-%m-%d", mint.time))
                    if mint.duplicateOf then GameTooltip:AddLine(("Duplicate of %s's"):format(mint.duplicateOf), 1, 0.4, 0.4) end
                    GameTooltip:Show()
                end)
                tile:SetScript("OnLeave", GameTooltip_Hide)
                page.tiles[i] = tile
            end
            tile.picture = picture
            local column, line = (i - 1) % perRow, math.floor((i - 1) / perRow)
            tile:ClearAllPoints()
            tile:SetPoint("TOPLEFT", column * (TILE + TILE_GAP), -line * (TILE + 34 + TILE_GAP))
            -- Redraw only when the tile shows other traits (another picture, or a rerolled one: new traits table).
            if tile.drawn ~= picture.mint.traits then
                ns.RenderMint(tile.canvas, picture.mint.traits)
                tile.drawn = picture.mint.traits
            end
            local rarity = ns.MintRarity(picture.mint.traits)
            tile:SetBackdropBorderColor(ns.RarityRGB(rarity))
            tile.owner:SetText(picture.me and ("|cffffd100%s|r"):format(picture.owner) or picture.owner)
            tile.rarity:SetText(("|c%s%s|r #%d"):format(ns.RARITY_COLORS[rarity], Capitalize(rarity), picture.mint.number))
            tile:Show()
        end
        for i = #pictures + 1, #page.tiles do page.tiles[i]:Hide() end
        page.scroll.content:SetHeight(math.max(1, math.ceil(#pictures / perRow) * (TILE + 34 + TILE_GAP)))
        page.empty:SetShown(#pictures == 0)
    end,
})

-- Settings -----------------------------------------------------------------------------------------

ns.RegisterPage({
    key = "settings", label = "Settings", section = "settings", order = 1,
    create = function(parent) return ns.EmbedConfig(parent, WIDTH) end,
    refresh = function() if ns.RefreshConfigPanel then ns.RefreshConfigPanel() end end,
})
function ns.ToggleConfig() ns.OpenPage("settings") end
