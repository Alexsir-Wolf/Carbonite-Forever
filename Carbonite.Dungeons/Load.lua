-- Carbonite.Dungeons | hands the route data to Carbonite (#272).
-- The Data\ files are copied from ForeverDungeonRoutes by tools/gen_dungeon_routes.py
-- and fill the addon's private table; Carbonite/Modules/Map/DungeonRoutes.lua reads it.
local _, DR = ...
local Nx = _G.Nx
if not Nx then return end
Nx.DungeonRoutesData = DR
if Nx.DungeonRoutes and Nx.DungeonRoutes.OnDataLoaded then
    Nx.DungeonRoutes:OnDataLoaded(DR)
end
