-- Your professions and known recipes, synced to guildmates (Sync.lua) for the Overview's Professions view
-- and the Crafters page: KillTrackerDB.professions = { list = { { line, name, rank, max, icon } },
-- recipes = { [line] = { recipeID, ... } }, recipeSeq = { [line] = change number }, seq }. line is the profession's skill line ID; recipe IDs are
-- spell IDs, so names and tooltips come from the game (C_Spell / GameTooltip:SetSpellByID).
-- Levels are read any time; recipes only while that profession's window is open, so a profession's
-- recipes appear once its window has been opened.

local _, ns = ...

local issecret = issecretvalue or function() return false end
local function Readable(v)
    if issecret(v) then return nil end
    return v
end

local function Professions()
    local db = KillTrackerDB
    db.professions = db.professions or { list = {}, recipes = {} }
    return db.professions
end

-- Marks the professions changed (so they sync); returns the change number.
local function Changed()
    local seq = ns.Touch(Professions())
    if ns.OnFriendsChanged then ns.OnFriendsChanged() end  -- refreshes the window
    return seq
end

-- Profession levels, from the profession slots (primary, primary, archaeology, fishing, cooking).
local function UpdateLevels()
    if not GetProfessions or not GetProfessionInfo or not KillTrackerDB then return end
    local list = {}
    for _, index in ipairs({ GetProfessions() }) do
        if index and not issecret(index) then
            local name, icon, rank, max, _, _, line = GetProfessionInfo(index)
            name, icon, rank, max, line = Readable(name), Readable(icon), Readable(rank), Readable(max), Readable(line)
            if name and line then list[#list + 1] = { line = line, name = name, rank = rank or 0, max = max or 0, icon = icon } end
        end
    end
    local p = Professions()
    local same = #list == #p.list
    for i, prof in ipairs(list) do
        local old = p.list[i]
        if not old or old.line ~= prof.line or old.rank ~= prof.rank or old.max ~= prof.max then same = false end
    end
    if same then return end
    p.list = list
    -- Forget recipes of professions you dropped.
    local current = {}
    for _, prof in ipairs(list) do current[prof.line] = true end
    for line in pairs(p.recipes) do
        if not current[line] then p.recipes[line] = nil end
        if p.recipeSeq and not current[line] then p.recipeSeq[line] = nil end
    end
    Changed()
end

-- Known recipes of the profession whose window is open (not someone else's linked or guild list).
local function UpdateRecipes()
    local T = C_TradeSkillUI
    if not T or not T.GetAllRecipeIDs or not T.GetRecipeInfo or not KillTrackerDB then return end
    if (T.IsTradeSkillLinked and T.IsTradeSkillLinked()) or (T.IsTradeSkillGuild and T.IsTradeSkillGuild())
        or (T.IsNPCCrafting and T.IsNPCCrafting()) then
        return
    end
    local base = T.GetBaseProfessionInfo and T.GetBaseProfessionInfo()
    local line = base and Readable(base.professionID)
    if not line or line == 0 then return end
    local known = {}
    for _, recipeID in ipairs(T.GetAllRecipeIDs() or {}) do
        local info = T.GetRecipeInfo(recipeID)
        if info and info.learned and not issecret(recipeID) then known[#known + 1] = recipeID end
    end
    if #known == 0 then return end  -- still loading
    table.sort(known)
    local p = Professions()
    local old = p.recipes[line]
    if old and #old == #known then
        local same = true
        for i, id in ipairs(known) do if old[i] ~= id then same = false break end end
        if same then return end
    end
    p.recipes[line] = known
    p.recipeSeq = p.recipeSeq or {}
    p.recipeSeq[line] = Changed()  -- only this profession's recipes need sending again
end

local pendingLevels, pendingRecipes
local function Soon(which)
    if which == "levels" then
        if pendingLevels then return end
        pendingLevels = true
        C_Timer.After(1, function() pendingLevels = nil UpdateLevels() end)
    else
        if pendingRecipes then return end
        pendingRecipes = true
        C_Timer.After(0.5, function() pendingRecipes = nil UpdateRecipes() end)
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("SKILL_LINES_CHANGED")
frame:RegisterEvent("TRADE_SKILL_SHOW")
frame:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
frame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" or event == "SKILL_LINES_CHANGED" then
        Soon("levels")
    else
        Soon("levels")  -- a skill-up while crafting
        Soon("recipes")
    end
end)

-- Shared with the pages ---------------------------------------------------------------------------

local GetSpellName = C_Spell and C_Spell.GetSpellName or function(id) return (GetSpellInfo(id)) end
local GetSpellTexture = C_Spell and C_Spell.GetSpellTexture or function(id) return select(3, GetSpellInfo(id)) end

-- A recipe's name and icon (from its spell), or nil while the game hasn't loaded it.
function ns.RecipeInfo(recipeID)
    return GetSpellName(recipeID), GetSpellTexture(recipeID)
end

-- Someone's professions: KillTrackerDB.professions for you (key nil), or a synced guildmate's. Never nil.
function ns.GetProfessions(key)
    local source = key and KillTrackerFriends[key] or KillTrackerDB
    return source and source.professions or { list = {}, recipes = {} }
end
