-- The Pro Shop's wares: the pieces bought with points (the room and the cart: ProShopRoom.lua; the steward ringing it
-- up: ProShopTill.lua). A piece is in stock when its unlock (MintArt.lua) is "shop:<id>"; buying it unlocks it like
-- any other route (Unlocks.lua), so it can be worn and rolls in your pictures. Prices go by rarity (placeholders until
-- the numbers pass). What you spent here is kept in KillTrackerDB.shop = { spent, bought = { [key] = time } } (for
-- the steward's own pieces later: shop-spending achievements).

local _, ns = ...

ns.SHOP_PRICES = { common = 50, uncommon = 100, rare = 250, epic = 600, legendary = 1500 }

ns.SHOP_SPECIAL_OFF = 0.2  -- (the daily special: this much off)

local function Sold(option) return option and not option.retired and tostring(option.unlock or ""):find("^shop:") ~= nil end

-- Today's special: one piece in stock a day ("layer:id"), the same for the whole guild (picked from the day's number,
-- UTC), worn by the mannequin on the room's easel (ProShopRoom.lua) and SHOP_SPECIAL_OFF cheaper.
local specialDay, specialKey  -- (worked out once a day)
function ns.ShopSpecial()
    local day = math.floor((GetServerTime and GetServerTime() or time()) / 86400)
    if day == specialDay then return specialKey end
    local keys = {}
    for _, layer in ipairs(ns.MintLayers or {}) do
        for _, option in ipairs(layer.options) do
            if Sold(option) then keys[#keys + 1] = ns.OptionKey(layer.key, option) end
        end
    end
    if #keys == 0 then return end
    table.sort(keys)
    specialDay, specialKey = day, keys[(day * 7919) % #keys + 1]
    return specialKey
end

-- A piece's price in points (today's special: cheaper), or nil if the shop doesn't sell it; and its full price.
function ns.ShopPrice(option)
    if not Sold(option) then return end
    local full = ns.SHOP_PRICES[option.rarity] or ns.SHOP_PRICES.uncommon
    if option.layerKey and ns.ShopSpecial() == option.layerKey .. ":" .. option.id then
        return math.floor(full * (1 - ns.SHOP_SPECIAL_OFF) + 0.5), full
    end
    return full, full
end

-- Everything in stock, in layer order: { key = "layer:id", layer, option, price, full (its price off special), special,
-- owned }.
function ns.ShopStock()
    local stock = {}
    for _, layer in ipairs(ns.MintLayers or {}) do
        for _, option in ipairs(layer.options) do
            local price, full = ns.ShopPrice(option)
            if price then
                local key = ns.OptionKey(layer.key, option)
                stock[#stock + 1] = { key = key, layer = layer, option = option, price = price, full = full, special = price < full,
                    owned = ns.IsUnlocked(key) }
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
