-- Collection: items bought with points (Points.lua). Owned items are saved in KillTrackerDB.collection as
-- [itemID] = { time = bought, claim = true once marked for minting by the companion app }.
-- What there is to collect comes later: add entries to ns.Collectibles.

local _, ns = ...

-- { id, name, rarity, cost, texture, description }. id must never change once released; texture is a
-- file in this addon's folder, e.g. "Interface\\AddOns\\SOLC\\Media\\Collection\\hogger".
ns.Collectibles = {
    -- { id = "example", name = "Example", rarity = "rare", cost = 100,
    --   texture = "Interface\\Icons\\INV_Misc_QuestionMark", description = "What this is." },
}

ns.RARITY_COLORS = {
    common = "ffffffff", uncommon = "ff1eff00", rare = "ff0070dd", epic = "ffa335ee", legendary = "ffff8000",
}

-- Returns true if bought, or false and why not.
function ns.BuyCollectible(item)
    local db = KillTrackerDB
    if db.collection[item.id] then return false, "You already own this." end
    local points = ns.GetPoints()
    if points.balance < item.cost then
        return false, ("Not enough points (%d of %d)."):format(points.balance, item.cost)
    end
    db.points.spent = db.points.spent + item.cost
    db.collection[item.id] = { time = time() }
    ns.Print(("Added |c%s%s|r to your collection (-%d points)."):format(
        ns.RARITY_COLORS[item.rarity] or "ffffffff", item.name, item.cost))
    if ns.OnKillsChanged then ns.OnKillsChanged() end
    return true
end

-- Marks an owned item for minting; the companion app reads KillTrackerDB.collection after logout.
function ns.ClaimCollectible(item)
    local owned = KillTrackerDB.collection[item.id]
    if owned then owned.claim = true end
end

StaticPopupDialogs["SOLC_BUY"] = {
    text = "Buy %s for %d points?",
    button1 = YES or "Yes",
    button2 = NO or "No",
    OnAccept = function(_, item)
        local ok, reason = ns.BuyCollectible(item)
        if not ok then ns.Print(reason) end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

function ns.ConfirmBuy(item)
    StaticPopup_Show("SOLC_BUY", item.name, item.cost, item)
end
