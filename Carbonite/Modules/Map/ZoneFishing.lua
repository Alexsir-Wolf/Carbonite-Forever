-- Carbonite | Modules / Map / ZoneFishing
-- Fishing skill each zone asks for, shown in the zone tooltip on the map (#84).
-- "130 (205)": 130 to fish there, 205 for the zone's best pools.
--
-- Data: the zoneFishing table of zonelevels.lua from MapUtils by D4KiR,
-- GPL-3.0 like Carbonite, keyed by uiMapID.
--
--   ZoneFishing:Get(mapID)  the skill text for a zone, or nil

local Carbonite = _G.Carbonite
local ZoneFishing = {}
Carbonite.Modules.Map.ZoneFishing = ZoneFishing

local SKILL = {
    [1411] = "1",
    [1412] = "1",
    [1413] = "1",
    [1416] = "130",
    [1417] = "130",
    [1420] = "1",
    [1421] = "1",
    [1422] = "205",
    [1423] = "330",
    [1424] = "55",
    [1425] = "205",
    [1426] = "1",
    [1428] = "330",
    [1429] = "1",
    [1430] = "330",
    [1431] = "55",
    [1432] = "1",
    [1433] = "55",
    [1434] = "130 (205)",
    [1435] = "130",
    [1436] = "1",
    [1437] = "55",
    [1438] = "1",
    [1439] = "1",
    [1440] = "55",
    [1441] = "130",
    [1442] = "55",
    [1443] = "130",
    [1444] = "205 (330)",
    [1445] = "130",
    [1446] = "205",
    [1447] = "205 (330)",
    [1448] = "205",
    [1449] = "205",
    [1450] = "205",
    [1451] = "330",
    [1452] = "330",
    [1453] = "1",
    [1454] = "1",
    [1455] = "1",
    [1456] = "1",
    [1457] = "1",
    [1458] = "1",
}

function ZoneFishing:Get(mapID)
    return SKILL[mapID]
end
