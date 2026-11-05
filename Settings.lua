-- The Settings page (the cog on the top beam): just for you, on this character. How the window looks and sounds
-- (all of SOLC's sounds off: Toast.lua's ns.SoundOff), do not disturb (no toasts or pop-ins: ns.DoNotDisturb), the
-- minimap button, puzzle duel challenges (SOLC Puzzle, when it's on), your main character (an alt's title reads
-- "Alt of <main>": ProfileHeader.lua) and sharing your wardrobe with your other characters (Core.lua). The guild's
-- point values are the dev menu's (Config.lua, Dev.lua).

local _, ns = ...

local UI = ns.UI
local LEFT, ROW = 24, 30

ns.RegisterPage({
    key = "settings", label = "Settings", section = "settings", order = 1,
    create = function(parent)
        local page = CreateFrame("Frame", nil, parent)
        page:SetAllPoints()
        local heading, line = UI.CreateHeader(page)
        heading:SetText("Settings")
        line:SetText("Just for you, on this character.")

        local checks = {}
        -- A checkbox at y: get() says if it's on, set(on) changes it; tip: its tooltip lines.
        local function Check(y, label, tip, get, set)
            local check = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
            check:SetSize(26, 26)
            check:SetPoint("TOPLEFT", LEFT, -y)
            check.label = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            check.label:SetPoint("LEFT", check, "RIGHT", 4, 0)
            check.label:SetText(label)
            check:SetScript("OnClick", function(self)
                UI.ClickSound()
                set(self:GetChecked() and true or false)
                page:Refresh()
            end)
            check:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine(tip[1], 1, 1, 1)
                GameTooltip:AddLine(tip[2], nil, nil, nil, true)
                GameTooltip:Show()
            end)
            check:SetScript("OnLeave", GameTooltip_Hide)
            check.get = get
            checks[#checks + 1] = check
            return check
        end

        local y = 64
        UI.CreateSection(page, "Look and sound", y)
        y = y + 24
        Check(y, "Ogre mode", { "Ogre mode", "The menu, the tabs and the titles in ogre words and crayon. Me smash buttons." },
            function() return KillTrackerDB.ogreMode and true or false end,
            function(on) UI.SetOgreMode(on) end)
        y = y + ROW
        Check(y, "Sounds", { "Sounds", "Off: SOLC makes no sound at all - buttons, toasts, chests, the Dream Bed, the games." },
            function() return not KillTrackerDB.soundOff end,
            function(on) KillTrackerDB.soundOff = not on or nil end)
        y = y + ROW
        Check(y, "Click sounds", { "Click sounds", "The wooden buttons clack when you click them (now and then an ogre grunts)." },
            function() return KillTrackerDB.clickSounds ~= false end,
            function(on) KillTrackerDB.clickSounds = on end)
        y = y + ROW
        Check(y, "Tooltips beside the window", { "Tooltips beside the window",
            "All of SOLC's tooltips open in one place, just outside the window, instead of next to what you point at." },
            function() return KillTrackerDB.fixedTooltips ~= false end,
            function(on) KillTrackerDB.fixedTooltips = on end)
        y = y + ROW
        Check(y, "Minimap button", { "Minimap button", "The skull by the minimap: click it to open SOLC." },
            function() return not (KillTrackerDB.minimap and KillTrackerDB.minimap.hide) end,
            function(on)
                KillTrackerDB.minimap.hide = not on
                ns.UpdateMinimapButton()
            end)

        y = y + ROW
        Check(y, "Do not disturb", { "Do not disturb",
            "No toasts, no ogre pop-ins and no puzzle duel challenges (they're declined). Chat lines still come, and gifts still wait in your Inventory." },
            function() return KillTrackerDB.dnd and true or false end,
            function(on) KillTrackerDB.dnd = on or nil end)

        -- Puzzle duels (SOLC Puzzle's Duel.lua), when that addon is on.
        y = y + ROW + 18
        local puzzleHeading = UI.CreateSection(page, "Puzzle", y)
        y = y + 24
        local duels = Check(y, "Accept duel challenges", { "Accept duel challenges",
            "Off: guildmates' challenges are declined without asking you. Someone you decline can't challenge you again for a minute." },
            function() return SOLC.PuzzleDuels and SOLC.PuzzleDuels.Accepts() or false end,
            function(on) if SOLC.PuzzleDuels then SOLC.PuzzleDuels.Set(on) end end)
        duels.puzzle = true

        -- Your characters: which one is your main, and sharing the wardrobe.
        y = y + ROW + 18
        UI.CreateSection(page, "Your characters", y)
        y = y + 26
        local mainLabel = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        mainLabel:SetPoint("TOPLEFT", LEFT + 4, -(y + 5))
        mainLabel:SetText("This character is")
        local mainPick = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
        mainPick:SetSize(240, 24)
        mainPick:SetPoint("LEFT", mainLabel, "RIGHT", 10, 0)
        local function MyCard()
            KillTrackerDB.card = KillTrackerDB.card or {}
            return KillTrackerDB.card
        end
        local function SetMain(name)
            MyCard().main = name
            ns.Touch(MyCard())  -- syncs it to guildmates
            if ns.OnKillsChanged then ns.OnKillsChanged() end
            page:Refresh()
        end
        mainPick:SetScript("OnClick", function(self)
            if not MenuUtil then return end
            UI.ClickSound()
            local me = Ambiguate(ns.MyName(), "short")
            MenuUtil.CreateContextMenu(self, function(_, root)
                root:CreateTitle("This character is")
                root:CreateRadio("My main", function() return MyCard().main == nil end, function() SetMain(nil) end)
                local names = {}
                for _, c in pairs(SOLCAccount and SOLCAccount.characters or {}) do
                    if c.name and c.name ~= me then names[#names + 1] = c end
                end
                table.sort(names, function(a, b) return (a.level or 0) > (b.level or 0) end)
                for _, c in ipairs(names) do
                    local color = c.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[c.class]
                    local label = ("An alt of %s%s|r (%d)"):format(color and ("|c" .. color.colorStr) or "|cffffffff", c.name, c.level or 0)
                    root:CreateRadio(label, function() return MyCard().main == c.name end, function() SetMain(c.name) end)
                end
                if #names == 0 then root:CreateTitle("Log in your other characters once to list them") end
            end)
        end)
        mainPick:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Main character", 1, 1, 1)
            GameTooltip:AddLine("On an alt, the title under your name reads \"Alt of <main>\" for everyone.", nil, nil, nil, true)
            GameTooltip:Show()
        end)
        mainPick:SetScript("OnLeave", GameTooltip_Hide)
        y = y + ROW + 4
        Check(y, "Share my wardrobe with my other characters", { "Shared wardrobe",
            "Everything this character unlocks goes in one wardrobe with your other characters that share theirs, and it can wear all of it. Off: only what it unlocked itself (kept either way)." },
            function() return KillTrackerDB.shareWardrobe and true or false end,
            function(on) ns.SetWardrobeShared(on) end)

        function page:Refresh()
            for _, check in ipairs(checks) do check:SetChecked(check.get()) end
            local hasPuzzle = SOLC and SOLC.PuzzleDuels ~= nil
            puzzleHeading:SetShown(hasPuzzle)
            duels:SetShown(hasPuzzle)
            duels.label:SetShown(hasPuzzle)
            local main = MyCard().main
            mainPick:SetText(main and ("An alt of " .. main) or "My main")
        end
        page:SetScript("OnShow", page.Refresh)
        return page
    end,
    refresh = function(page) if page and page.Refresh then page:Refresh() end end,
})
function ns.ToggleConfig() ns.OpenPage("settings") end
