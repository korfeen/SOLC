-- Popup near the top of the screen. Popups queue up, so several from one kill show one after another.

local _, ns = ...

local HOLD, FADE = 4, 1
local LEVEL_UP_SOUND = 888

-- big = gold title, gold border and a sound; otherwise a quieter grey popup.
local STYLES = {
    record      = { big = true,  title = { 1, 0.82, 0 }, border = { 1, 0.82, 0 } },
    achievement = { big = true,  title = { 1, 0.5, 0.1 }, border = { 1, 0.5, 0.1 } },
    info        = { big = false, title = { 1, 1, 1 },     border = { 0.6, 0.6, 0.6 } },
}

local toast = CreateFrame("Frame", "KillTrackerToast", UIParent, "BackdropTemplate")
toast:SetSize(320, 76)
toast:SetPoint("TOP", 0, -140)
toast:SetFrameStrata("HIGH")
toast:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
toast:SetBackdropColor(0, 0, 0, 0.85)
toast:Hide()

toast.title = toast:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
toast.title:SetPoint("TOP", 0, -12)
toast.line1 = toast:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
toast.line1:SetPoint("TOP", toast.title, "BOTTOM", 0, -6)
toast.line2 = toast:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
toast.line2:SetPoint("TOP", toast.line1, "BOTTOM", 0, -4)

local queue = {}

local function Present(item)
    local style = STYLES[item.style] or STYLES.info
    toast.title:SetFontObject(style.big and "GameFontNormalLarge" or "GameFontHighlight")
    toast.title:SetText(item.title)
    toast.title:SetTextColor(unpack(style.title))
    toast.line1:SetText(item.line1 or "")
    toast.line2:SetText(item.line2 or "")
    toast:SetHeight(item.line2 and 76 or 58)
    toast:SetBackdropBorderColor(unpack(style.border))
    toast.elapsed = 0
    toast:SetAlpha(1)
    toast:Show()
    if style.big then pcall(PlaySound, LEVEL_UP_SOUND) end
end

toast:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = self.elapsed + elapsed
    if self.elapsed >= HOLD + FADE then
        if #queue > 0 then
            Present(table.remove(queue, 1))
        else
            self:Hide()
        end
    elseif self.elapsed > HOLD then
        self:SetAlpha(1 - (self.elapsed - HOLD) / FADE)
    end
end)

-- style: "record", "achievement" or "info". line2 is optional.
function ns.ShowToast(style, title, line1, line2)
    local item = { style = style, title = title, line1 = line1, line2 = line2 }
    if toast:IsShown() then
        queue[#queue + 1] = item
    else
        Present(item)
    end
end
