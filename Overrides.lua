-- Manual faction overrides for mobs that Data.lua doesn't know (or gets wrong).
-- Find NPC IDs with /kt unknown, look them up on Wowhead, then add a line:
--     [npcID] = "Faction Name",
-- Overrides win over everything else. Edit, then /reload in-game.

local _, ns = ...

ns.Overrides = {
    -- [12345] = "Defias Brotherhood",
}
