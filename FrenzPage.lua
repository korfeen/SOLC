-- The guild's members (FRENZ), with the crafters as the MAKE tab (the key crafters opens it). A split page (ProfileHeader.lua: the profile header over the left page, the middle beam).
-- Left: tabs. FRENZ: everyone using SOLC, you first; clicking someone views them (the header, the right page, every
-- page), the one viewed lit. MAKE: a search box, then each profession and who has it, or the recipes matching the
-- search and who knows them; picking one lists them on the right.
-- Right: whoever is viewed, hung in the Overview's frame: their character (their chosen background behind) or, with
-- no character of them synced, their picture; their name on the plaque; under the frame their rank, numbers, last
-- update and SOLC version, and buttons: their Overview, whisper them, sync with your target (outside the guild).
-- On MAKE with a profession or recipe picked, the frame lists who has it instead.

local _, ns = ...
local UI = ns.UI
if not UI.Members or not UI.CraftersRows or not UI.List then return end
local state = UI.List.state
local Fit, Tooltip = UI.FitText, UI.Tooltip

local ART = "Interface\\AddOns\\SOLC\\Media\\Overview\\"
local NAME_FONT = "Interface\\AddOns\\SOLC\\Media\\Fonts\\GermaniaOne-Regular.ttf"
local SIGN_FONT = "Interface\\AddOns\\SOLC\\Media\\Fonts\\FingerPaint-Regular.ttf"
local INK = { 0.16, 0.16, 0.18 }
local CREAM, DIM = { 0.93, 0.88, 0.78 }, { 0.62, 0.56, 0.48 }
local GOLD = { 1, 0.85, 0.1 }
local HOVER_COLOR, PICKED_COLOR = { 0.65, 0.53, 0.28 }, { 0.45, 0.36, 0.18 }
local PLATE, PLATE_LIT = { 0.3, 0.22, 0.12 }, { 0.65, 0.53, 0.28 }
local AGO_COLOR = { 0.98, 0.64, 0.26 }
local OFFICER = "|TInterface\\GroupFrame\\UI-Group-AssistantIcon:12|t"

local TABS = { { "frenz", "FRENZ", "FRENZ" }, { "make", "MAKE", "MAKE" } }
local TAB_FOR_PAGE = { crafters = "make" }

-- In window pixels (from its top-left, y down).
local LEFT = {
    tabs = { top = 285, bottom = 319, size = 17, color = { 0.16, 0.11, 0.08 } },
    line = { top = 319, bottom = 343, size = 13, color = { 0.12, 0.12, 0.12 } },  -- a line about the tab; MAKE: the search
    rows = { top = 343, height = 24, size = 13, colors = { 0.25, 0.18 }, empty = { 0.1, 0.1, 0.1 } },
}
local RIGHT = {
    color = { 0.094, 0.094, 0.094 },
    frame = { x = 688, y = 156, w = 362, h = 447 },
    photo = { x = 869, y = 389.5, w = 308, h = 329 },
    plaque = { x = 874, y = 578, w = 170, size = 22 },
    info = { x = 700, top = 612, width = 222, line = 18, lines = 4, size = 13 },
    buttons = { x = 930, top = 612, w = 128, h = 24, gap = 4 },
}
local PANEL_LINES = 15

local page
local function Ogre() return KillTrackerDB and KillTrackerDB.ogreMode end
local function At(region, point, x, y) region:SetPoint(point, UI.window, "TOPLEFT", x, -y) end

-- A flat wooden-looking button (as PIX's): button:Set(text, tooltip lines); button.action on click.
local function Plate(parent, w, h)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(w, h)
    local back = button:CreateTexture(nil, "BACKGROUND")
    back:SetAllPoints()
    button.text = button:CreateFontString(nil, "OVERLAY")
    button.text:SetFont(NAME_FONT, 13, "")
    button.text:SetPoint("CENTER", 0, 1)
    UI.OutlineText(button.text, { 0, 0, 0 })
    local function Paint(lit)
        back:SetColorTexture(unpack(lit and PLATE_LIT or PLATE))
        button.text:SetTextColor(unpack(lit and { 1, 1, 1 } or GOLD))
    end
    button:SetScript("OnEnter", function(self) Paint(true) if self.lines then Tooltip(self, self.lines) end end)
    button:SetScript("OnLeave", function() Paint(false) GameTooltip_Hide() end)
    button:SetScript("OnClick", function(self) UI.ClickSound() if self.action then self.action() end end)
    function button:Set(text, lines, action) self.text:SetText(text) self.lines, self.action = lines, action self:Show() end
    Paint(false)
    return button
end

-- The rows, from page.offset on.
local function DrawRows()
    local viewed = state.viewing
    for i, row in ipairs(page.rows) do
        local d = page.data[page.offset + i]
        row.d = d
        row:SetShown(d ~= nil)
        if d then
            if page.tab == "frenz" then
                local rank = ns.GetRank(not d.me and d.key or nil)
                row.label:SetText((d.officer and OFFICER .. " " or "") .. (d.me and ("|cffffd100%s|r"):format(d.name) or d.name)
                    .. ("  |cff999999%d %s|r"):format(rank.rank, rank.title))
                row.count:SetText(("%d  |cff999999%s|r"):format(d.kills or 0, d.me and "now" or ns.TimeAgo(d.updated or 0)))
                row.picked = (d.me and viewed == nil) or (not d.me and d.key == viewed)
            else
                local names = {}
                for n, person in ipairs(d.people) do
                    if n > 3 then names[#names + 1] = "..." break end
                    names[n] = person.rank and ("%s %d"):format(person.name, person.rank) or person.name
                end
                row.label:SetText(("%s%s  |cff999999%s|r"):format(d.icon and ("|T%s:14|t "):format(d.icon) or "", d.name,
                    table.concat(names, ", ")))
                row.count:SetText(#d.people)
                row.picked = page.pick == d
            end
            row:Paint(false)
        end
    end
    page.empty:SetShown(#page.data == 0)
end

-- Who is viewed: their character or picture in the frame, and what's known of them under it.
local function DrawMember()
    local key = state.viewing
    local p = UI.Profile(key)
    for _, line in ipairs(page.panel) do line:SetText("") end
    -- Their character, or (none synced) their chosen, first showcase or newest picture.
    local friend = key and KillTrackerFriends[key]
    local picture = key and not (friend and friend.gear) and (ns.FindMint(key, p.portrait) or ns.GetShowcase(key)[1] or ns.NewestMint(key))
    page.portrait:SetShown(picture ~= nil and picture ~= false)
    if picture then
        page.model:ClearModel()
        page.model:Hide()
        page.unseen:Hide()
        page.modelKey = nil  -- reload the character when it shows again
        ns.DrawMint(page.portrait, picture)
    elseif page.modelKey ~= (key or false) or (key and friend.gear ~= page.model.shownGear) then
        page.modelKey = key or false
        page.model:Show()
        local shown = UI.LoadCharacter(page.model, key)
        page.model:SetShown(shown)
        page.unseen:SetShown(not shown)
        if page.model.SetCamDistanceScale then page.model:SetCamDistanceScale(UI.CharacterCamera(key, 0)) end
    end
    local option = not picture and ns.GetModelBackdrop and ns.GetModelBackdrop(key)
    if option then page.backdrop:SetTexture(ns.MintTexture(option, {})) end
    page.backdrop:SetShown(option ~= nil and option ~= false)
    Fit(page.plaque, SIGN_FONT, RIGHT.plaque.size, 8, ((p.name or ""):match("^(%S+)") or ""):upper(), RIGHT.plaque.w)

    local member
    for _, m in ipairs(UI.Members()) do
        if (m.me and not key) or (not m.me and m.key == key) then member = m end
    end
    local rank = ns.GetRank(key)
    local lines = {
        ("|cffffd100Ogre Rank %d|r  %s"):format(rank.rank, rank.title),
        member and ("Kills |cffffbf66%d|r   Points |cffffbf66%s|r   PvP |cffffbf66%s|r"):format(member.kills or 0,
            member.points or "?", member.pvp or "?") or "",
        member and ("Pictures |cffffbf66%d|r   Bounty |cffffbf66%d|r"):format(member.pictures or 0, member.bounty or 0) or "",
    }
    if member and not member.me then
        local outdated = member.version and ns.IsNewerVersion(ns.ADDON_VERSION, member.version)
        lines[4] = ("Updated %s%s"):format(ns.TimeAgo(member.updated or 0), member.version
            and (outdated and ("  |cffff6060SOLC %s|r"):format(member.version) or ("  |cff999999SOLC %s|r"):format(member.version)) or "")
    else
        lines[4] = ("|cff999999SOLC %s|r"):format(ns.ADDON_VERSION)
    end
    for i, line in ipairs(page.info) do line:SetText(lines[i] or "") end

    local b = page.buttons
    b[1]:Set("OVERVIEW", { "Their Overview" }, function() ns.ViewPlayer(key, "overview") end)
    if key then
        b[2]:Set("WHISPER", { "Whisper " .. (p.name or "") }, function()
            local tell = (ChatFrameUtil and ChatFrameUtil.SendTell) or ChatFrame_SendTell
            if tell then tell(Ambiguate(key, "none")) end
        end)
    else
        b[2]:Hide()
    end
    b[3]:Set("SYNC TARGET", { "Sync with target", "Guildmates sync by themselves. Use this to swap stats with someone outside the guild." },
        function() ns.SyncWithTarget() end)
end

-- MAKE with a profession or recipe picked: who has it, in the frame.
local function DrawCrafters(entry)
    page.model:Hide()
    page.unseen:Hide()
    page.portrait:Hide()
    page.backdrop:Hide()
    page.modelKey = nil
    local lines = { { entry.name, GOLD }, " " }
    for _, person in ipairs(entry.people) do
        lines[#lines + 1] = person.rank and ("%s  |cff999999%d/%d|r"):format(person.name, person.rank, person.max or 0) or person.name
        if #lines >= PANEL_LINES then break end
    end
    for i, line in ipairs(page.panel) do
        local text = lines[i]
        line:SetText(type(text) == "table" and text[1] or text or "")
        line:SetTextColor(unpack(type(text) == "table" and text[2] or CREAM))
    end
    Fit(page.plaque, SIGN_FONT, RIGHT.plaque.size, 8, entry.name:upper(), RIGHT.plaque.w)
    for i, line in ipairs(page.info) do
        line:SetText(i == 1 and ("|cffffbf66%d|r know it"):format(#entry.people) or "")
    end
    for _, button in ipairs(page.buttons) do button:Hide() end
end

ns.RegisterPage({
    key = "members", label = "Members", section = "guild", order = 2,
    bare = true,
    split = true,
    covers = { crafters = true },  -- (UI.lua) on the MAKE tab
    create = function(parent)
        page = CreateFrame("Frame", nil, parent)
        page:SetAllPoints()
        page.tab, page.offset = "frenz", 0
        local slot, under = UI.SPLIT.left, UI.SPLIT.under

        -- The boards.
        local book = CreateFrame("Frame", nil, page)
        book:SetAllPoints()
        local function Band(top, bottom, color, left, right)
            local fill = book:CreateTexture(nil, "BACKGROUND", nil, -8)
            At(fill, "TOPLEFT", left or under.left, top)
            fill:SetSize((right or under.middle) - (left or under.left), bottom - top)
            fill:SetColorTexture(unpack(color))
        end
        Band(LEFT.tabs.top - 5, LEFT.tabs.bottom, LEFT.tabs.color)
        Band(LEFT.line.top, LEFT.line.bottom, LEFT.line.color)
        Band(LEFT.rows.top, under.bottom, LEFT.rows.empty)
        Band(under.top, under.bottom, RIGHT.color, under.middle, under.right + 20)

        local left = CreateFrame("Frame", nil, page)
        left:SetAllPoints()
        left:SetFrameLevel(book:GetFrameLevel() + 2)

        -- The tabs.
        page.tabs = {}
        local tabWidth = (slot.right - slot.left) / #TABS
        for i, tab in ipairs(TABS) do
            local button = UI.TabButton(left, slot.left + (i - 1) * tabWidth, LEFT.tabs, tabWidth)
            function button:Redraw()
                self:SetTab(Ogre() and tab[3] or tab[2], page.tab == tab[1])
            end
            button:SetScript("OnClick", function()
                UI.ClickSound()
                page.tab, page.offset, page.pick = tab[1], 0, nil
                ns.OpenPage(state.page)
            end)
            page.tabs[i] = button
        end

        -- The line: about the roster, or MAKE's search box.
        local lineY = (LEFT.line.top + LEFT.line.bottom) / 2
        page.line = left:CreateFontString(nil, "OVERLAY")
        page.line:SetFont(NAME_FONT, LEFT.line.size, "")
        page.line:SetTextColor(unpack(CREAM))
        At(page.line, "LEFT", slot.left + 10, lineY)
        page.line:SetWidth(slot.right - slot.left - 20)
        page.line:SetJustifyH("LEFT")
        page.line:SetWordWrap(false)
        page.search = CreateFrame("EditBox", nil, left, "SearchBoxTemplate")
        page.search:SetSize(slot.right - slot.left - 26, 20)
        At(page.search, "LEFT", slot.left + 12, lineY)
        page.search:SetAutoFocus(false)
        page.search:HookScript("OnTextChanged", function()
            if page.tab == "make" then
                page.offset, page.pick = 0, nil
                ns.OpenPage(state.page)
            end
        end)
        -- Recipe names load a moment later for spells this client hasn't seen yet.
        local pending
        page:RegisterEvent("SPELL_DATA_LOAD_RESULT")
        page:SetScript("OnEvent", function(self)
            if not self:IsVisible() or page.tab ~= "make" or pending then return end
            pending = true
            C_Timer.After(0.5, function()
                pending = nil
                if self:IsVisible() then ns.OpenPage(state.page) end
            end)
        end)

        -- The rows, over a list area that takes the wheel.
        local spec, overhang = LEFT.rows, 20
        local listArea = CreateFrame("Frame", nil, left)
        At(listArea, "TOPLEFT", slot.left - overhang, spec.top)
        listArea:SetSize(slot.right - slot.left + 2 * overhang, slot.bottom - spec.top)
        listArea:EnableMouse(true)
        listArea:EnableMouseWheel(true)
        listArea:SetScript("OnMouseWheel", function(_, delta)
            local most = math.max(0, #(page.data or {}) - #page.rows)
            local offset = math.max(0, math.min(most, page.offset - delta * 3))
            if offset ~= page.offset then
                page.offset = offset
                DrawRows()
            end
        end)
        page.rows = {}
        for i = 1, math.floor((slot.bottom - spec.top) / spec.height) do
            local row = CreateFrame("Button", nil, left)
            row:SetFrameLevel(listArea:GetFrameLevel() + 1)
            row:SetSize(slot.right - slot.left + 2 * overhang, spec.height)
            At(row, "TOPLEFT", slot.left - overhang, spec.top + (i - 1) * spec.height)
            local shade = spec.colors[i % 2 == 1 and 1 or 2]
            row.stripe = row:CreateTexture(nil, "BACKGROUND")
            row.stripe:SetAllPoints()
            row.count = row:CreateFontString(nil, "OVERLAY")
            row.count:SetFont(NAME_FONT, spec.size, "")
            row.count:SetTextColor(unpack(AGO_COLOR))
            row.count:SetShadowOffset(1, -1)
            row.count:SetPoint("RIGHT", -(overhang + 6), 1)
            row.label = row:CreateFontString(nil, "OVERLAY")
            row.label:SetFont(NAME_FONT, spec.size, "")
            row.label:SetTextColor(0.94, 0.94, 0.94)
            row.label:SetShadowOffset(1, -1)
            row.label:SetPoint("LEFT", overhang + 8, 1)
            row.label:SetPoint("RIGHT", row.count, "LEFT", -8, 0)
            row.label:SetJustifyH("LEFT")
            row.label:SetWordWrap(false)
            function row:Paint(hovered)
                self.stripe:SetColorTexture(unpack(hovered and HOVER_COLOR or self.picked and PICKED_COLOR or { shade, shade, shade }))
            end
            row:SetScript("OnEnter", function(self)
                local d = self.d
                if not d then return end
                self:Paint(true)
                if page.tab == "make" then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    if d.id then GameTooltip:SetSpellByID(d.id) GameTooltip:AddLine(" ") GameTooltip:AddLine("Known by") else GameTooltip:AddLine(d.name) end
                    for _, person in ipairs(d.people) do
                        UI.AddValue(person.name, person.rank and ("%d/%d"):format(person.rank, person.max or 0) or "")
                    end
                    GameTooltip:Show()
                else
                    Tooltip(self, { d.name, d.officer and "Guild master or officer" or nil, "Click to view them" })
                end
            end)
            row:SetScript("OnLeave", function(self) self:Paint(false) GameTooltip_Hide() end)
            row:SetScript("OnClick", function(self)
                local d = self.d
                if not d then return end
                UI.ClickSound()
                if page.tab == "make" then
                    page.pick = page.pick ~= d and d or nil
                    ns.OpenPage(state.page)
                else
                    ns.ViewPlayer(not d.me and d.key or nil, state.page)
                end
            end)
            page.rows[i] = row
        end
        page.empty = left:CreateFontString(nil, "OVERLAY")
        page.empty:SetFont(NAME_FONT, 14, "")
        page.empty:SetTextColor(unpack(DIM))
        page.empty:SetWidth(slot.right - slot.left - 30)
        At(page.empty, "TOP", (slot.left + slot.right) / 2, spec.top + 40)

        -- The right page: the frame, with the character, a picture or a list in its opening.
        local card = CreateFrame("Frame", nil, page)
        card:SetAllPoints()
        card:SetFrameLevel(book:GetFrameLevel() + 2)
        local photo = CreateFrame("Frame", nil, card)
        photo:SetSize(RIGHT.photo.w, RIGHT.photo.h)
        At(photo, "CENTER", RIGHT.photo.x, RIGHT.photo.y)
        photo:SetClipsChildren(true)
        local sky = photo:CreateTexture(nil, "BACKGROUND")
        sky:SetAllPoints()
        sky:SetTexture("Interface\\Buttons\\WHITE8X8")
        sky:SetGradient("VERTICAL", CreateColor(0.42, 0.58, 0.3, 1), CreateColor(0.96, 0.8, 0.74, 1))
        page.backdrop = photo:CreateTexture(nil, "ARTWORK")
        page.backdrop:SetAllPoints()
        local crop = (1 - RIGHT.photo.w / RIGHT.photo.h) / 2
        page.backdrop:SetTexCoord(crop, 1 - crop, 0, 1)
        page.backdrop:Hide()
        page.model = CreateFrame("DressUpModel", nil, photo)
        page.model:SetAllPoints()
        page.model:EnableMouse(true)
        page.model:EnableMouseWheel(true)
        local facing, zoom = 0, 0
        page.model:SetScript("OnMouseWheel", function(self, delta)
            zoom = math.max(UI.MIN_ZOOM, math.min(UI.MAX_ZOOM, zoom - delta * 0.1))
            if self.SetCamDistanceScale then self:SetCamDistanceScale(UI.CharacterCamera(state.viewing, zoom)) end
        end)
        page.model:SetScript("OnMouseDown", function(self, button)
            if button ~= "LeftButton" then return end
            local lastX = GetCursorPosition()
            self:SetScript("OnUpdate", function()
                local x = GetCursorPosition()
                facing = facing + (x - lastX) / 80
                lastX = x
                self:SetFacing(facing)
            end)
        end)
        page.model:SetScript("OnMouseUp", function(self) self:SetScript("OnUpdate", nil) end)
        page.model:SetScript("OnHide", function(self) self:SetScript("OnUpdate", nil) end)
        page.model:SetScript("OnEnter", function(self) Tooltip(self, { "Drag to turn, scroll to zoom" }) end)
        page.model:SetScript("OnLeave", GameTooltip_Hide)
        page.portrait = CreateFrame("Frame", nil, photo)
        page.portrait:SetSize(RIGHT.photo.h, RIGHT.photo.h)
        page.portrait:SetPoint("CENTER")
        page.portrait:Hide()
        page.unseen = photo:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        page.unseen:SetPoint("CENTER")
        page.unseen:SetWidth(RIGHT.photo.w - 30)
        page.unseen:SetText("No character synced yet. It shows once they log in with SOLC 0.37.0 or newer.")
        local panelHolder = CreateFrame("Frame", nil, photo)
        panelHolder:SetAllPoints()
        panelHolder:SetFrameLevel(page.model:GetFrameLevel() + 2)
        page.panel = {}
        for i = 1, PANEL_LINES do
            local line = panelHolder:CreateFontString(nil, "OVERLAY")
            line:SetFont(NAME_FONT, 13, "")
            line:SetPoint("TOPLEFT", 14, -12 - (i - 1) * 20)
            line:SetPoint("RIGHT", -14, 0)
            line:SetJustifyH("LEFT")
            line:SetWordWrap(false)
            page.panel[i] = line
        end
        local panelBack = panelHolder:CreateTexture(nil, "BACKGROUND")
        panelBack:SetAllPoints()
        panelBack:SetColorTexture(0.08, 0.07, 0.06)
        page.panelBack = panelBack
        page.panelHolder = panelHolder

        local hung = CreateFrame("Frame", nil, card)
        hung:SetAllPoints()
        hung:SetFrameLevel(panelHolder:GetFrameLevel() + 10)
        local frameArt = hung:CreateTexture(nil, "ARTWORK")
        frameArt:SetTexture(ART .. "HangingPicture")
        frameArt:SetTexCoord(0, RIGHT.frame.w / 512, 0, RIGHT.frame.h / 512)
        frameArt:SetSize(RIGHT.frame.w, RIGHT.frame.h)
        At(frameArt, "TOPLEFT", RIGHT.frame.x, RIGHT.frame.y)
        page.plaque = hung:CreateFontString(nil, "OVERLAY")
        At(page.plaque, "CENTER", RIGHT.plaque.x, RIGHT.plaque.y)
        page.plaque:SetTextColor(unpack(INK))
        page.plaque:SetShadowOffset(0, 0)

        local info = RIGHT.info
        page.info = {}
        for i = 1, info.lines do
            local line = card:CreateFontString(nil, "OVERLAY")
            line:SetFont(NAME_FONT, info.size, "")
            line:SetTextColor(unpack(CREAM))
            At(line, "TOPLEFT", info.x, info.top + (i - 1) * info.line)
            line:SetWidth(info.width)
            line:SetJustifyH("LEFT")
            line:SetWordWrap(false)
            page.info[i] = line
        end
        page.buttons = {}
        local bs = RIGHT.buttons
        for i = 1, 3 do
            local button = Plate(card, bs.w, bs.h)
            At(button, "TOPLEFT", bs.x, bs.top + (i - 1) * (bs.h + bs.gap))
            button:Hide()
            page.buttons[i] = button
        end
        return page
    end,

    refresh = function(p)
        if state.viewing and not KillTrackerFriends[state.viewing] then state.viewing = nil end
        if p.asked ~= state.page then
            if TAB_FOR_PAGE[state.page] then p.tab, p.offset, p.pick = TAB_FOR_PAGE[state.page], 0, nil end
            p.asked = state.page
        end
        for _, tab in ipairs(p.tabs) do tab:Redraw(false) end
        local make = p.tab == "make"
        p.search:SetShown(make)
        p.line:SetShown(not make)
        if make then
            local query = strtrim(p.search:GetText() or ""):lower()
            p.data = UI.CraftersRows(query)
            p.empty:SetText(query == "" and "No professions yet. They show once guildmates log in with SOLC 0.37.0 or newer."
                or "Nobody knows a recipe by that name yet. Recipes show once their owner has opened that profession's window.")
        else
            p.data = UI.Members()
            p.line:SetText(("|cffffbf66%d|r using SOLC  |cff999999- click someone to view them|r"):format(#p.data))
            p.empty:SetText("")
        end
        p.offset = math.min(p.offset, math.max(0, #p.data - #p.rows))
        DrawRows()
        local listing = make and p.pick
        p.panelHolder:SetShown(listing and true or false)
        if listing then DrawCrafters(p.pick) else DrawMember() end
    end,
})
