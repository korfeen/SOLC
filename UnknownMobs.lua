-- Mobs we don't know yet: killed by you or any synced guildmate, but missing from Data.lua (and Overrides.lua), so
-- their faction (and maybe their subtype) is only guessed from the name. New content (WoW Forever's) brings plenty.
-- /solc unknown: the list in chat, the most killed first, who met them and a Wowhead link.
-- /solc unknown copy (dev characters): the same as text in a box to copy out (Ctrl+A, Ctrl+C), one mob a line,
-- tab-separated: npcID, name, the guess ("Faction? | Subtype?"), kills, who killed them. Paste it to whoever fills
-- in Overrides.lua.
-- Replaces Core.lua's own /solc unknown (yours only): this wraps the slash command and answers those two first.

local _, ns = ...

local UNCATEGORIZED = "Uncategorized"  -- (as Core.lua's)

-- Every unknown mob, merged by npcID across you and your synced guildmates: { npcID, name, label, count, who = {...} }.
function ns.UnknownMobs()
    local byID, list = {}, {}
    local function Add(source, who)
        ns.ForEachKill(function(npcID, entry)
            local c = ns.Categorize(npcID, entry)
            if not (c.factionGuess or c.faction == UNCATEGORIZED) then return end
            local item = byID[npcID]
            if not item then
                item = { npcID = npcID, name = entry.name or ("NPC " .. npcID), count = 0, who = {},
                    label = ("%s%s | %s%s"):format(c.faction, c.factionGuess and "?" or "", c.subtype, c.subtypeGuess and "?" or "") }
                byID[npcID] = item
                list[#list + 1] = item
            end
            item.count = item.count + (entry.count or 0)
            item.who[#item.who + 1] = who
        end, source)
    end
    Add(nil, UnitName("player") or "You")
    for key, friend in pairs(KillTrackerFriends or {}) do
        if type(friend) == "table" and friend.kills then
            Add(friend, friend.name or (tostring(key):match("^[^-]+") or tostring(key)))
        end
    end
    table.sort(list, function(a, b)
        if a.count ~= b.count then return a.count > b.count end
        return a.npcID < b.npcID
    end)
    return list
end

local MAX_CHAT = 25  -- (more than this: the copy box)

local function ShowInChat()
    local list = ns.UnknownMobs()
    if #list == 0 then return ns.Print("Every mob the guild has killed has a known faction.") end
    ns.Print(("%d mobs without a confirmed faction, from you and your synced guildmates:"):format(#list))
    for i = 1, math.min(#list, MAX_CHAT) do
        local item = list[i]
        ns.Print(("  %s [%s] x%d (%s) - %s"):format(item.name, item.label, item.count, table.concat(item.who, ", "),
            ns.WOWHEAD_NPC_URL:format(item.npcID)))
    end
    if #list > MAX_CHAT then
        ns.Print(("  ...and %d more%s"):format(#list - MAX_CHAT, ns.IsDev() and " (/solc unknown copy for all of them)" or ""))
    end
end

-- The copy box ---------------------------------------------------------------------------------------------------------

local box
local function BuildBox()
    box = CreateFrame("Frame", "SOLCUnknownMobs", UIParent, "BackdropTemplate")
    box:SetSize(640, 420)
    box:SetPoint("CENTER")
    box:SetFrameStrata("FULLSCREEN_DIALOG")
    box:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 24,
        insets = { left = 6, right = 6, top = 6, bottom = 6 } })
    box:EnableMouse(true)
    box:SetMovable(true)
    box:RegisterForDrag("LeftButton")
    box:SetScript("OnDragStart", box.StartMoving)
    box:SetScript("OnDragStop", box.StopMovingOrSizing)
    box.title = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    box.title:SetPoint("TOPLEFT", 16, -14)
    local close = CreateFrame("Button", nil, box, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)
    local scroll = CreateFrame("ScrollFrame", nil, box, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -36)
    scroll:SetPoint("BOTTOMRIGHT", -34, 16)
    box.edit = CreateFrame("EditBox", nil, scroll)
    box.edit:SetMultiLine(true)
    box.edit:SetAutoFocus(false)
    box.edit:SetFontObject("ChatFontNormal")
    box.edit:SetWidth(580)
    box.edit:SetScript("OnEscapePressed", function() box:Hide() end)
    scroll:SetScrollChild(box.edit)
    tinsert(UISpecialFrames, "SOLCUnknownMobs")  -- (Escape closes it)
end

function ns.ShowUnknownCopy()
    local list = ns.UnknownMobs()
    if not box then BuildBox() end
    local lines = { "npcID\tname\tguess\tkills\twho" }
    for _, item in ipairs(list) do
        lines[#lines + 1] = ("%d\t%s\t%s\t%d\t%s"):format(item.npcID, item.name, item.label, item.count, table.concat(item.who, ", "))
    end
    box.title:SetText(("%d unknown mobs - Ctrl+A, Ctrl+C to copy"):format(#list))
    box.edit:SetText(table.concat(lines, "\n"))
    box:Show()
    box.edit:SetFocus()
    box.edit:HighlightText()
end

-- /solc unknown [copy] -------------------------------------------------------------------------------------------------

local Slash = SlashCmdList.SOLC
if Slash then
    SlashCmdList.SOLC = function(input)
        local msg = strtrim(input or ""):lower()
        if msg == "unknown" then return ShowInChat() end
        if msg == "unknown copy" and ns.IsDev() then return ns.ShowUnknownCopy() end
        return Slash(input)
    end
end
