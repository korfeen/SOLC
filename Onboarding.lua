-- Onboarding: the club opens room by room as your Ogre Rank grows, and the Pro Shop's steward shows you round.
-- A page waiting on a rank has no sidebar button and doesn't open (UI.lua asks ns.RankLocked); what it counts (deeds,
-- bounties, points) keeps counting meanwhile, so a page shows everything already earned the day it opens.
-- The tour: the first time you open the window the steward welcomes you; each rank that opens a page, he pops up in the
-- window next time it's open (or at once if it is), opens the page behind him, lights its sidebar button and says a
-- few lines. Next / Skip. Seen steps: KillTrackerDB.tour.seen[id]. /solc tour shows every step up to your rank again.
-- Dev characters: /solc tourrank <n> pretends a rank (only for locks and the tour), /solc tourrank to stop.

local _, ns = ...

local NAME_FONT = "Interface\\AddOns\\SOLC\\Media\\Fonts\\GermaniaOne-Regular.ttf"
local WOOD = "Interface\\AddOns\\SOLC\\Media\\Wood\\"
local OGRE = 190  -- the steward's size in the window
-- As he stands in the Pro Shop (ProShopRoom.lua's STEWARD), cut out.
local STEWARD = { skin = "club_sage", eyes = "snooty_eyes", expression = "snooty_sneer", outfit = "shop_steward_vest",
    headwear = "shop_steward_boater" }

-- The steps, in rank order. page: the one this rank opens (locked below it); each line can light a sidebar button
-- (glow; "tracks": Settings' What SOLC tracks section) and open a page behind him (open). reaction: his line about
-- what you chose in Settings (kill stats, and LifeStats.lua's Share / Just me / Off).
local STEPS = {
    { id = "welcome", rank = 1, lines = {
        { text = "Oh. It's you. Someone let you in. I shall be having words with the doorman.", open = "overview" },
        { text = "I am Reginald, steward of this club. You may call me sir. You may not call me Reggie.", introduce = true },
        { text = "You go about your little adventures and the club keeps score. Every kill, every deed, every pitiful death. Mostly the deaths.", glow = "kills" },
        { text = "Score earns points. Points earn Ogre Rank. Rank opens more of the club. I fully expect you to stay rank one forever.", glow = "overview" },
        { text = "Before you go. The club keeps records. Some members prefer... discretion. Mark what I may write down about you, there, in the Settings. You may change your mind whenever you like.", open = "settings", glow = "tracks" },
        { reaction = true },  -- (what he thinks of your choices: Reaction)
        { text = "The Guild room is open to everyone. Sadly, that includes you. News, members, everyone's pictures. Touch nothing.", glow = "home" },
        { text = "The rest of the club is for members of standing. Should you ever earn a rank, I shall come and find you. Reluctantly." },
    } },
    { id = "deeds", rank = 2, page = "deeds", lines = {
        { text = "Rank two. I am as surprised as you are. The Deeds are open.", open = "deeds", glow = "deeds" },
        { text = "Ladders of things worth doing. Each step pays points, and even what you did before today counts. Generous, if you ask me. Nobody did." },
    } },
    { id = "collection", rank = 3, page = "pixcollection", lines = {
        { text = "Rank three. Persistent, aren't you. Like a rash. Your Collection is open, and the Dream Bed with it.", open = "pixcollection", glow = "pixcollection" },
        { text = "Find \"Mint a picture\" among your pictures. Lie down, an ogre tells you its dream, and you paint it. Badly, I assume." },
        { text = "What you paint becomes a picture all your own. Do keep it somewhere I won't have to look at it." },
    } },
    { id = "bounties", rank = 4, page = "bounties", lines = {
        { text = "Rank four. The bounty board is open. Do try not to bleed on the posters.", open = "bounties", glow = "bounties" },
        { text = "New posters every week. Finish one for its reward. Every claim fills the guild's counter, so even you can be useful." },
    } },
    { id = "proshop", rank = 5, page = "proshop", lines = {
        { text = "Rank five. Against my express wishes, you may now enter my Pro Shop. Wipe your boots. Twice.", open = "proshop", glow = "proshop" },
        { text = "Spend your points on finery for your ogre. Dress the mannequin, fill your cart and bring it to me at the till. I shall pretend to be pleased." },
        { text = "Spending points never costs you rank. So spend them. All of them. It's the least you can do." },
    } },
    { id = "games", rank = 6, page = "games", lines = {
        { text = "Rank six. The Games Room is open. Gentlemen's pastimes. You'll fit in poorly.", open = "games", glow = "games" },
        { text = "Puzzles, Couronne, the arcade, the claw machine. That is the whole club. You've seen everything now, so you may stop bothering me." },
    } },
}
local PAGE_RANKS = {}
for _, step in ipairs(STEPS) do if step.page then PAGE_RANKS[step.page] = step.rank end end

local function DB()
    local db = KillTrackerDB
    if not db then return end
    db.tour = db.tour or { seen = {} }
    return db.tour
end

-- The rank the locks and the tour go by: yours (a dev character's pretend one while set; the last step's during
-- /solc tour all, the preview).
local preview = false
local LAST_RANK = 1
for _, step in ipairs(STEPS) do LAST_RANK = math.max(LAST_RANK, step.rank) end
function ns.TourRank()
    if preview then return LAST_RANK end
    local db = KillTrackerDB
    if db and db.tourRank and ns.IsDev and ns.IsDev() then return db.tourRank end
    return ns.GetRank and ns.GetRank().rank or 1
end

function ns.RankLocked(key)
    local rank = PAGE_RANKS[key]
    return rank ~= nil and ns.TourRank() < rank
end
-- News (Feed.lua's kinds) about a locked page's things: kept out of every feed until its rank.
-- (deeds always show: they earn your first points, before the Deeds page opens)
local KIND_PAGES = { M = "pixcollection", W = "pixcollection", U = "pixcollection", B = "bounties", P = "bounties" }
function ns.KindLocked(kind)
    local page = KIND_PAGES[kind]
    return page ~= nil and ns.RankLocked(page)
end

-- The panel ------------------------------------------------------------------------------------------------------------

local panel, glow
local queue, current, line = {}, nil, 0

local function PlankButton(parent, label)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(96, 24)
    b:SetText(label)
    return b
end

-- His name: "Mystery Ogre" on his plate until he says it (the welcome's introduce line: KillTrackerDB.tour.named).
local NAME, MYSTERY = "Reginald", "Mystery Ogre"

-- Where he stands: peeking over the window's top beam (SkeletonLayout.lua: y 94-146 from the window's top), right of
-- the page's title and left of the gear and the X, cut off at the beam's middle as if standing behind it; his name
-- plate on the beam, his bubble on his left.
local STAND_X = 880        -- his middle, from the window's left
local BEAM_MIDDLE = 120    -- the top beam's middle, down from the window's top
local SUNK = 12            -- how much of him is behind the beam
local TOP_BEAM_TOP = 94    -- the beam's top edge

local function Build()
    local window = ns.UI.window
    local level = window:GetFrameLevel()
    panel = CreateFrame("Frame", nil, window)
    panel:SetAllPoints()
    local header = level + ns.UI.FRAME_LEVEL.header
    panel:SetFrameLevel(header - 5)  -- (under the top beam and the logo)
    panel:Hide()
    -- He's cut off at the beam's middle (the beam itself hides the rest down to its bottom edge).
    panel.clip = CreateFrame("Frame", nil, panel)
    panel.clip:SetPoint("TOPLEFT", window, "TOPLEFT", 0, OGRE)
    panel.clip:SetPoint("BOTTOMRIGHT", window, "TOPRIGHT", 0, -BEAM_MIDDLE)
    panel.clip:SetClipsChildren(true)
    panel.canvas = CreateFrame("Frame", nil, panel.clip)
    panel.canvas:SetSize(OGRE, OGRE)
    panel.canvas:SetPoint("BOTTOM", window, "TOPLEFT", STAND_X, -BEAM_MIDDLE - SUNK)
    -- (the name plate, as the ogre pop-ins': DMSay.lua; on the beam, over it)
    panel.plate = CreateFrame("Frame", nil, panel)
    panel.plate:SetSize(150, 36)
    panel.plate:SetPoint("CENTER", window, "TOPLEFT", STAND_X, -BEAM_MIDDLE)
    panel.plate:SetFrameLevel(header + 10)
    local left = panel.plate:CreateTexture(nil, "ARTWORK")
    left:SetTexture(WOOD .. "PlankLeft") left:SetSize(18, 36) left:SetPoint("LEFT")
    local right = panel.plate:CreateTexture(nil, "ARTWORK")
    right:SetTexture(WOOD .. "PlankRight") right:SetSize(18, 36) right:SetPoint("RIGHT")
    local middle = panel.plate:CreateTexture(nil, "ARTWORK")
    middle:SetTexture(WOOD .. "Plank")
    middle:SetPoint("TOPLEFT", left, "TOPRIGHT") middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
    local name = panel.plate:CreateFontString(nil, "OVERLAY")
    name:SetFont(NAME_FONT, 17, "")
    name:SetTextColor(1, 0.86, 0.55)
    name:SetShadowOffset(1, -1)
    name:SetPoint("CENTER", 0, 1)
    panel.name = name
    -- The bubble, left of him, its bottom just above the beam, its tail pointing at him.
    panel.bubble = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    panel.bubble:SetPoint("BOTTOMRIGHT", window, "TOPLEFT", STAND_X - OGRE * 0.3, -TOP_BEAM_TOP + 46)
    panel.bubble:SetFrameLevel(header + 12)
    panel.bubble:EnableMouse(true)  -- (clicks on it don't fall through to the page)
    panel.bubble:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    panel.bubble:SetBackdropColor(0.98, 0.95, 0.86, 0.97)
    panel.bubble:SetBackdropBorderColor(0.35, 0.24, 0.12)
    local tail = panel.bubble:CreateTexture(nil, "BACKGROUND", nil, -1)
    panel.tail = tail
    tail:SetSize(18, 18)
    tail:SetPoint("CENTER", panel.bubble, "BOTTOMRIGHT", -2, 14)
    tail:SetColorTexture(0.98, 0.95, 0.86, 0.97)
    tail:SetRotation(math.rad(45))
    panel.text = panel.bubble:CreateFontString(nil, "OVERLAY")
    panel.text:SetFont(NAME_FONT, 15, "")
    panel.text:SetTextColor(0.15, 0.1, 0.06)
    panel.text:SetPoint("TOPLEFT", 14, -12)
    panel.text:SetWidth(280)
    panel.text:SetJustifyH("LEFT")
    panel.text:SetSpacing(2)
    panel.next = PlankButton(panel.bubble, "Next")
    panel.next:SetPoint("BOTTOMRIGHT", -10, 10)
    panel.skip = PlankButton(panel.bubble, "Skip tour")
    panel.skip:SetPoint("RIGHT", panel.next, "LEFT", -6, 0)
    panel.next:SetScript("OnClick", function() ns.TourNext() end)
    panel.skip:SetScript("OnClick", function() ns.TourSkip() end)
    -- The glow on a sidebar button: a gold border breathing over it.
    glow = CreateFrame("Frame", nil, window)
    glow:SetFrameStrata("DIALOG")
    glow:Hide()
    glow.tex = glow:CreateTexture(nil, "OVERLAY")
    glow.tex:SetAllPoints()
    glow.tex:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    glow.tex:SetTexCoord(0.2, 0.8, 0.2, 0.8)
    glow.tex:SetBlendMode("ADD")
    glow.tex:SetVertexColor(1, 0.82, 0.3)
    -- (round a whole section instead: a thin gold outline and a faint wash)
    glow.wash = glow:CreateTexture(nil, "BACKGROUND")
    glow.wash:SetAllPoints()
    glow.wash:SetColorTexture(1, 0.82, 0.3, 0.06)
    glow.edges = {}
    for i, side in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" }, { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local edge = glow:CreateTexture(nil, "OVERLAY")
        edge:SetColorTexture(1, 0.82, 0.3, 0.95)
        edge:SetPoint(side[1])
        edge:SetPoint(side[2])
        if i <= 2 then edge:SetHeight(2) else edge:SetWidth(2) end
        glow.edges[i] = edge
    end
    glow.t = 0
    glow:SetScript("OnUpdate", function(self, elapsed)
        self.t = self.t + elapsed
        self:SetAlpha(0.55 + 0.45 * math.sin(self.t * 4))
    end)
end

local function Glow(key)
    -- (a sidebar button by its page, or "tracks": Settings' "What SOLC tracks" section)
    local section = key == "tracks"
    local button = section and ns.UI.settingsTracks or key and ns.UI.NavButton and ns.UI.NavButton(key)
    if not button or not button:IsShown() then glow:Hide() return end
    glow:ClearAllPoints()
    local pad = section and 0 or 10
    glow:SetPoint("TOPLEFT", button, "TOPLEFT", -pad, pad * 0.6)
    glow:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", pad, -pad * 0.6)
    glow.tex:SetShown(not section)
    glow.wash:SetShown(section)
    for _, edge in ipairs(glow.edges) do edge:SetShown(section) end
    glow:SetFrameLevel(button:GetFrameLevel() + 30)
    glow:Show()
end

-- What he thinks of your choices (Settings' "What SOLC tracks").
local function Reaction()
    local hidden = 0
    for _, stat in ipairs(ns.LIFE_STATS or {}) do if ns.Privacy(stat.key) ~= "share" then hidden = hidden + 1 end end
    local killsHidden = KillTrackerDB.sharing == false
    if hidden == 0 and not killsHidden then return "An open book. How vulgar. Very well." end
    if hidden == #(ns.LIFE_STATS or {}) and killsHidden then return "A member of mystery. I approve. Mostly." end
    if hidden == 1 and ns.Privacy("gold") ~= "share" and not killsHidden then return "Wise. Nobody wants to see that." end
    if hidden == 1 and ns.Privacy("deaths") ~= "share" and not killsHidden then return "Hiding the deaths. I would too." end
    return "Noted. Discretion becomes you. Barely."
end

local function Say(text, glowKey, last, single)
    panel.text:SetText(text)
    panel.bubble:ClearAllPoints()
    panel.bubble:SetPoint("BOTTOMRIGHT", ns.UI.window, "TOPLEFT", STAND_X - OGRE * 0.3, -TOP_BEAM_TOP + 46)
    panel.bubble:SetSize(308, panel.text:GetStringHeight() + 58)
    panel.next:SetText(last and "Sorry" or "Next")
    panel.skip:SetShown(not last and not single)
    Glow(glowKey)
    if not panel:IsShown() then
        panel:Show()
        panel.canvas:SetSize(OGRE, OGRE)
        ns.RenderMint(panel.canvas, STEWARD)
        if ns.PlaySound then ns.PlaySound(SOUNDKIT and SOUNDKIT.TELL_MESSAGE or 3081) end
    end
end

local function Close()
    current, line = nil, 0
    wipe(queue)
    if panel then panel:Hide() end
    if glow then glow:Hide() end
    if preview then  -- (the preview's over: the locks are back)
        preview = false
        if ns.UI.RelayoutSidebar then ns.UI.RelayoutSidebar() end
        if ns.UI.window and ns.UI.window:IsShown() and ns.OpenPage then ns.OpenPage("overview") end
        if ns.Print then ns.Print("Tour preview over: back to your own rank. /solc tour reset to start the real one fresh.") end
    end
end

local function ShowLine()
    local step_line = current.lines[line]
    -- (the page he talks about opens too: its own open, else the page whose button he lights up)
    local open = step_line.open or (step_line.glow ~= "tracks" and step_line.glow)
    if open and ns.OpenPage and not (ns.UI.PageLocked and ns.UI.PageLocked(open)) then ns.OpenPage(open) end
    local tour = DB()
    if step_line.introduce and tour then tour.named = true end
    panel.name:SetText(tour and tour.named and NAME or MYSTERY)
    panel.plate:SetWidth(math.max(150, (panel.name:GetStringWidth() or 0) + 48))
    Say(step_line.reaction and Reaction() or step_line.text, step_line.glow, line == #current.lines and #queue == 0, current.single)
end

local function StartNext()
    current = table.remove(queue, 1)
    if not current then Close() return end
    line = 1
    ShowLine()
end

function ns.TourNext()
    if not current then return Close() end
    local tour = DB()
    if line >= #current.lines then
        if tour and current.id and not preview then tour.seen[current.id] = true end
        StartNext()
    else
        line = line + 1
        ShowLine()
    end
end

function ns.TourSkip()
    local tour = DB()
    if tour and not preview then
        local rank = ns.TourRank()
        for _, step in ipairs(STEPS) do if step.rank <= rank then tour.seen[step.id] = true end end
    end
    Close()
end

local function CanShow()
    return ns.UI.window and ns.UI.window:IsShown() and (not ns.IsMember or ns.IsMember())
end

-- Queues every step you've reached and not seen (replay: all of them up to your rank) and starts, if the window's open.
function ns.StartTour(replay)
    local tour = DB()
    if not tour or not CanShow() then return end
    if current then return end  -- (already talking: the rest come next time)
    if not panel then Build() end
    wipe(queue)
    local rank = ns.TourRank()
    for _, step in ipairs(STEPS) do
        if step.rank <= rank and (replay or not tour.seen[step.id]) then queue[#queue + 1] = step end
    end
    if #queue > 0 then StartNext() end
end

-- A locked page asked for (a link, a slash command): the steward says what rank it waits on.
local NAMES = { deeds = "The Deeds", pixcollection = "Your Collection", bounties = "The bounty board", proshop = "My Pro Shop",
    games = "The Games Room", dreambed = "The Dream Bed" }
function ns.SayLocked(key)
    local rank = PAGE_RANKS[key] or (key == "dreambed" and PAGE_RANKS.pixcollection)
    if not rank then return end
    local text = ("%s opens at Ogre Rank %d. You are not Ogre Rank %d. Off you go."):format(NAMES[key] or "That room", rank, rank)
    if not CanShow() or current then
        if ns.Print then ns.Print(text) end
        return
    end
    if not panel then Build() end
    current, line = { lines = { { text = text } }, single = true }, 1
    wipe(queue)
    ShowLine()
end

-- A remark of his, once per character (tour.seen[id]): when the window's open and he isn't already talking (else
-- next time).
function ns.StewardOnce(id, text)
    local tour = DB()
    if not tour or tour.seen[id] or not CanShow() or current then return end
    tour.seen[id] = true
    if not panel then Build() end
    current, line = { lines = { { text = text } }, single = true }, 1
    wipe(queue)
    ShowLine()
end

-- Hooks ----------------------------------------------------------------------------------------------------------------

-- The Dream Bed comes with the Collection.
local ShowDreamBed = ns.ShowDreamBed
if ShowDreamBed then
    ns.ShowDreamBed = function(...)
        if ns.RankLocked("pixcollection") then return ns.SayLocked("dreambed") end
        return ShowDreamBed(...)
    end
end

-- A new rank: its page joins the sidebar and the steward comes (now if the window's open, else when it opens).
local CheckRank = ns.CheckRank
ns.CheckRank = function(...)
    local before = KillTrackerDB and KillTrackerDB.rank
    CheckRank(...)
    local after = KillTrackerDB and KillTrackerDB.rank
    if before ~= after then
        if ns.UI.RelayoutSidebar then ns.UI.RelayoutSidebar() end
        ns.StartTour()
    end
end

-- Pretending a rank (dev): the sidebar and the page follow at once.
function ns.SetTourRank(rank)
    if not KillTrackerDB then return end
    KillTrackerDB.tourRank = rank
    Close()
    if ns.UI.RelayoutSidebar then ns.UI.RelayoutSidebar() end
    if ns.UI.window and ns.UI.window:IsShown() and ns.OpenPage then ns.OpenPage("overview") end
    C_Timer.After(0.2, function() ns.StartTour() end)
end

-- /solc tour (every step up to your rank again), /solc tour all (the preview: every step of every rank, the rooms open
-- till it's over, nothing marked seen), /solc tour reset (as new: next open starts from the welcome);
-- dev: /solc tourrank <n> | /solc tourrank. The rest goes to Core.lua's handler.
local Slash = SlashCmdList.SOLC
if Slash then
    SlashCmdList.SOLC = function(input)
        local msg = strtrim(input or ""):lower()
        if msg == "tour" then
            if not (ns.UI.window and ns.UI.window:IsShown()) and ns.ToggleUI then ns.ToggleUI() end
            C_Timer.After(0.35, function() Close() ns.StartTour(true) end)
            return
        elseif msg == "tour all" then  -- (the preview: every step, every page open till it's over)
            if not (ns.UI.window and ns.UI.window:IsShown()) and ns.ToggleUI then ns.ToggleUI() end
            C_Timer.After(0.35, function()
                Close()
                preview = true
                if ns.UI.RelayoutSidebar then ns.UI.RelayoutSidebar() end
                ns.StartTour(true)
            end)
            if ns.Print then ns.Print("Tour preview: every step, every room open till it's over. Nothing is marked seen.") end
            return
        elseif msg == "tour reset" then
            local tour = DB()
            if tour then wipe(tour.seen) end
            Close()
            if ns.Print then ns.Print("Tour reset: the steward welcomes you next time the window opens.") end
            return
        end
        local rank = msg:match("^tourrank%s*(%d*)$")
        if rank and ns.IsDev and ns.IsDev() then
            ns.SetTourRank(tonumber(rank))
            if ns.Print then ns.Print(rank ~= "" and ("Pretending Ogre Rank " .. rank .. " for the locks and the tour.") or "Back to your own rank.") end
            return
        end
        return Slash(input)
    end
end

if ns.UI.window then
    ns.UI.window:HookScript("OnShow", function() C_Timer.After(0.3, function() ns.StartTour() end) end)
    ns.UI.window:HookScript("OnHide", Close)
end
