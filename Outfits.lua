-- Saved outfits: your ogre's looks, named and kept (KillTrackerDB.outfits = { { name, traits, style } }, at most
-- MAX_OUTFITS), to switch between: in EDIT (OverviewCard.lua's OUTFITS button: save the look, or put one on the
-- draft) and from the minimap button's menu (Minimap.lua: wear one straight away). What you wear matters: set bonuses
-- (SetBonuses.lua). Switching is free; OUTFIT_WAIT (seconds between switches) is there to turn on if it's ever needed.

local _, ns = ...

local MAX_OUTFITS = 6
local OUTFIT_WAIT = 0
local lastSwitch = 0

local function Copy(t)
    local out = {}
    for k, v in pairs(t or {}) do out[k] = v end
    return out
end

function ns.Outfits()
    KillTrackerDB.outfits = KillTrackerDB.outfits or {}
    return KillTrackerDB.outfits
end

-- Saves a look under a name (the same name: replaced). Returns false (and says why) when there's no room.
function ns.SaveOutfit(name, traits, style)
    name = (name or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then return false end
    local list = ns.Outfits()
    for _, outfit in ipairs(list) do
        if outfit.name:lower() == name:lower() then
            outfit.name, outfit.traits, outfit.style = name, Copy(traits), next(style or {}) and Copy(style) or nil
            ns.Print(("Outfit |cffffd100%s|r saved."):format(name))
            return true
        end
    end
    if #list >= MAX_OUTFITS then
        ns.Print(("You have %d outfits already: delete one first."):format(MAX_OUTFITS))
        return false
    end
    list[#list + 1] = { name = name, traits = Copy(traits), style = next(style or {}) and Copy(style) or nil }
    ns.Print(("Outfit |cffffd100%s|r saved."):format(name))
    return true
end

function ns.DeleteOutfit(i)
    local list = ns.Outfits()
    local outfit = table.remove(list, i)
    if outfit then ns.Print(("Outfit %s deleted."):format(outfit.name)) end
end

-- Wears an outfit straight away (your Overview card's ogre, synced like any change).
function ns.WearOutfit(i)
    local outfit = ns.Outfits()[i]
    if not outfit then return end
    if OUTFIT_WAIT > 0 and GetTime() - lastSwitch < OUTFIT_WAIT then
        ns.Print(("Not so fast: you can change again in %d s."):format(math.ceil(OUTFIT_WAIT - (GetTime() - lastSwitch))))
        return
    end
    lastSwitch = GetTime()
    KillTrackerDB.card = KillTrackerDB.card or {}
    KillTrackerDB.card.ogreStyle = outfit.style and Copy(outfit.style) or nil
    ns.SetOgre(Copy(outfit.traits))
    ns.Print(("You put on |cffffd100%s|r."):format(outfit.name))
end

-- Asks for a name and saves the look (traits, style) under it.
StaticPopupDialogs.SOLC_SAVE_OUTFIT = {
    text = "Name this outfit:",
    button1 = SAVE or "Save", button2 = CANCEL or "Cancel",
    hasEditBox = true, maxLetters = 24,
    OnShow = function(self) local box = self.editBox or self.EditBox if box then box:SetText("") box:SetFocus() end end,
    OnAccept = function(self, data)
        local box = self.editBox or self.EditBox
        if box and data then ns.SaveOutfit(box:GetText(), data.traits, data.style) end
    end,
    EditBoxOnEnterPressed = function(self)
        local popup = self:GetParent()
        if popup.button1 then popup.button1:Click() end
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}
function ns.AskSaveOutfit(traits, style)
    StaticPopup_Show("SOLC_SAVE_OUTFIT", nil, nil, { traits = Copy(traits), style = Copy(style) })
end
