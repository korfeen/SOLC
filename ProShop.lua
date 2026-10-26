-- The Pro Shop's wares: the pieces bought with points (the room and the cart: ProShopRoom.lua; the steward ringing it
-- up: ProShopTill.lua). A piece is in stock when its unlock (MintArt.lua) is "shop:<id>"; buying it unlocks it like
-- any other route (Unlocks.lua), so it can be worn and rolls in your pictures. Prices go by rarity (placeholders until
-- the numbers pass). What you spent here is kept in KillTrackerDB.shop = { spent, bought = { [key] = time } } (for
-- the steward's own pieces later: shop-spending achievements).

local _, ns = ...

ns.SHOP_PRICES = { common = 50, uncommon = 100, rare = 250, epic = 600, legendary = 1500 }

-- A piece's price in points, or nil if the shop doesn't sell it.
function ns.ShopPrice(option)
    if not option or not tostring(option.unlock or ""):find("^shop:") then return end
    return ns.SHOP_PRICES[option.rarity] or ns.SHOP_PRICES.uncommon
end

-- Everything in stock, in layer order: { key = "layer:id", layer, option, price, owned }.
function ns.ShopStock()
    local stock = {}
    for _, layer in ipairs(ns.MintLayers or {}) do
        for _, option in ipairs(layer.options) do
            local price = not option.retired and ns.ShopPrice(option)
            if price then
                local key = ns.OptionKey(layer.key, option)
                stock[#stock + 1] = { key = key, layer = layer, option = option, price = price, owned = ns.IsUnlocked(key) }
            end
        end
    end
    return stock
end

-- What a cart (a list of keys) costs, or nil and why not: something not sold, owned already or in it twice.
function ns.ShopTotal(keys)
    local total, seen = 0, {}
    for _, key in ipairs(keys) do
        local found = ns.OptionByKey(key)
        local price = found and ns.ShopPrice(found.option)
        if not price then return nil, "The shop doesn't sell that." end
        if seen[key] then return nil, found.option.name .. " is in the cart twice." end
        if ns.IsUnlocked(key) then return nil, "You have " .. found.option.name .. " already." end
        seen[key] = true
        total = total + price
    end
    return total
end

-- Buys a cart (a list of keys) all at once. Returns true and the total, or false and why not.
function ns.ShopBuy(keys)
    if #keys == 0 then return false, "The cart is empty." end
    local total, reason = ns.ShopTotal(keys)
    if not total then return false, reason end
    local balance = ns.GetPoints().balance
    if balance < total then return false, ("Not enough points (%d of %d)."):format(balance, total) end
    local db = KillTrackerDB
    db.points.spent = db.points.spent + total
    db.shop = db.shop or { spent = 0, bought = {} }
    db.shop.spent = db.shop.spent + total
    for _, key in ipairs(keys) do
        db.shop.bought[key] = time()
        ns.UnlockOption(key)
    end
    if ns.OnKillsChanged then ns.OnKillsChanged() end
    return true, total
end
