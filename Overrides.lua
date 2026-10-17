-- Manual faction overrides for mobs that Data.lua doesn't know (or gets wrong).
-- Find NPC IDs with /kt unknown, look them up on Wowhead, then add a line:
--     [npcID] = "Faction Name",
-- A mob Data.lua doesn't have at all (new WoW Forever ones) can also get its kind:
--     [npcID] = { faction = "Faction Name", subtype = "Crocolisk" },
-- Overrides win over everything else. Edit, then /reload in-game.

local _, ns = ...

ns.Overrides = {
    -- [12345] = "Defias Brotherhood",
    -- Excavation Site: Wetlands (WoW Forever), its bosses in order
    [260322] = { faction = "Crocolisk", subtype = "Crocolisk" },  -- Saltspine
    [260325] = { faction = "Raptor", subtype = "Raptor" },        -- Shadetooth
    [260808] = { faction = "Elemental", subtype = "Bog Beast" },   -- Highland Horror
    [260326] = { faction = "Titan", subtype = "Titan Construct" }, -- Relic Guardian
    -- The Hall of Thanes (WoW Forever)
    [261316] = { faction = "Elemental", subtype = "Fire Elemental" }, -- Infurnus (Magmatus on Wowhead)
}
