-- Namespace the vendored Shortest Path Forever search (Path.lua, PathGrid.lua) fills in.
-- Those files read `select(2, ...).GroundNavigation`; here it is Carbonite's own addon table,
-- so this copy never shares state with GatherLite's. See README.md.
local _, addon = ...
addon.GroundNavigation = addon.GroundNavigation or {}
