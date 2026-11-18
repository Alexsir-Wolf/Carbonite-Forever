-- Carbonite | Modules / Travel / Teleports
-- Routes that start with the hearthstone or a mage teleport (#37).
--
-- Travel:MakePath never considered teleports. Here each teleport ready now is
-- tried as a whole route: from its destination, with MakePath itself, plus
-- the teleport's own cost. When one beats the direct route by a margin, the
-- route starts with "Use Hearthstone (place)" and goes on from there.
--
--   Teleports:BindLocation()   hearthstone place { Name, MapId, X, Y } or nil
--   Teleports:Ready()          teleports usable now
--   Teleports:Cost(...)        a route's cost in Carbonite world units
--   Teleports:Plan(...)        the entries to put in front of a route, or nil

local Carbonite = _G.Carbonite
local L = LibStub("AceLocale-3.0"):GetLocale("Carbonite")

local Teleports = {}
Carbonite.Modules.Travel = Carbonite.Modules.Travel or {}
Carbonite.Modules.Travel.Teleports = Teleports

local HEARTHSTONE = 6948
local RUNE_OF_TELEPORTATION = 17031
local HEARTH_TEX = "Interface\\Icons\\INV_Misc_Rune_01"

local YARDS = 4.575          -- Carbonite world unit -> yards
local RUN_YPS = 7            -- running speed, yards per second
local CAST_SECONDS = 25      -- 10 s cast + loading screen
local BOAT_SECONDS = 120     -- a boat or zeppelin leg between continents
local MARGIN_SECONDS = 30    -- a teleport must save at least this much
local PLAN_TTL = 5           -- seconds a choice is kept for one destination

-- Mage teleports to the capitals (Classic spell ids). Destinations are the
-- arrival points in zone percent of each city's map (uiMapID); approximate,
-- to be checked in game. A few yards off does not change the choice.
Teleports.MAGE = {
    { spell = 3561, mapId = 1453, x = 38.6, y = 79.8, tex = "Interface\\Icons\\Spell_Arcane_TeleportStormWind" },
    { spell = 3562, mapId = 1455, x = 25.5, y = 7.1,  tex = "Interface\\Icons\\Spell_Arcane_TeleportIronForge" },
    { spell = 3563, mapId = 1458, x = 84.9, y = 17.3, tex = "Interface\\Icons\\Spell_Arcane_TeleportUnderCity" },
    { spell = 3565, mapId = 1457, x = 40.5, y = 81.7, tex = "Interface\\Icons\\Spell_Arcane_TeleportDarnassus" },
    { spell = 3566, mapId = 1456, x = 22.1, y = 17.8, tex = "Interface\\Icons\\Spell_Arcane_TeleportThunderBluff" },
    { spell = 3567, mapId = 1454, x = 38.4, y = 85.7, tex = "Interface\\Icons\\Spell_Arcane_TeleportOrgrimmar" },
}

local plans = {}             -- destination key -> { at, choice }
local announced = {}         -- destination key -> name of the choice told in the chat

local function now()
    return (GetTime and GetTime()) or 0
end

local function nxMap()
    return _G.Nx and _G.Nx.Map
end

local function charTravel()
    local db = _G.Nx and _G.Nx.db and _G.Nx.db.char
    if not db then
        return nil
    end
    db.Travel = db.Travel or {}
    return db.Travel
end

-------------------------------------------------------------------------------
-- Items and spells
-------------------------------------------------------------------------------

local function itemCount(id)
    local f = (C_Item and C_Item.GetItemCount) or _G.GetItemCount
    return f and f(id) or 0
end

local function itemReady(id)
    local f = (C_Container and C_Container.GetItemCooldown) or _G.GetItemCooldown
    if not f then
        return true
    end
    local start, duration = f(id)
    if not start or start == 0 or not duration then
        return true
    end
    return start + duration - now() <= 0
end

local function spellKnown(id)
    local f = _G.IsSpellKnown or (_G.IsPlayerSpell)
    return f and f(id) and true or false
end

local function spellName(id)
    local api = Carbonite.Compat and Carbonite.Compat.Api and Carbonite.Compat.Api.Spell
    local info = api and api:GetInfo(id)
    return info and info.name
end

-------------------------------------------------------------------------------
-- Hearthstone place
-------------------------------------------------------------------------------

-- Innkeepers of a zone the player's faction can use: { {x, y}, ... } in
-- zone percent.
local function innkeepersOf(guide, mapId, mine)
    local list = {}
    if type(guide[mapId]) ~= "string" then
        return list
    end
    for entry in guide[mapId]:gmatch("[^|]+") do
        local side, x, y = entry:match("^(%d+),([%d.]+),([%d.]+)")
        if side and (side == "0" or side == mine) then
            list[#list + 1] = { tonumber(x), tonumber(y) }
        end
    end
    return list
end

-- Room around a subzone's label box where its inn may still stand.
local AREA_MARGIN = 3

-- The innkeeper of the bind place (the client gives its name only): the only
-- one of the zone named like it, or the one closest to the subzone of that
-- name ("Camp Taurajo"), found by its map label (Nx.Map.AreaLabels).
local function innkeeperFor(place)
    local map = nxMap()
    local guide = _G.Nx and _G.Nx.GuideData and _G.Nx.GuideData[L["Innkeeper"]]
    if not (map and map.MapWorldInfo and guide) then
        return nil
    end
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    local mine = faction == "Alliance" and "1" or (faction == "Horde" and "2" or nil)
    local function at(mapId, p)
        local wx, wy = map:GetWorldPos(mapId, p[1], p[2])
        return { Name = place, MapId = mapId, X = wx, Y = wy }
    end

    for mapId, info in pairs(map.MapWorldInfo) do
        if type(mapId) == "number" and info.Name == place then
            local list = innkeepersOf(guide, mapId, mine)
            if #list == 1 then
                return at(mapId, list[1])
            end
        end
    end

    local labels = map.AreaLabels
    local areaInfo = _G.C_Map and _G.C_Map.GetAreaInfo
    if type(labels) ~= "table" or not areaInfo then
        return nil
    end
    for mapId, areas in pairs(labels) do
        for _, a in ipairs(areas) do
            local ok, name = pcall(areaInfo, a[1])
            if ok and name == place then
                local best, bestD
                for _, p in ipairs(innkeepersOf(guide, mapId, mine)) do
                    local dx, dy = math.abs(p[1] - a[2]), math.abs(p[2] - a[3])
                    if dx <= a[4] / 2 + AREA_MARGIN and dy <= a[5] / 2 + AREA_MARGIN then
                        local d = dx * dx + dy * dy
                        if not bestD or d < bestD then
                            best, bestD = p, d
                        end
                    end
                end
                if best then
                    return at(mapId, best)
                end
            end
        end
    end
    return nil
end

function Teleports:BindLocation()
    local place = GetBindLocation and GetBindLocation()
    if not place or place == "" then
        return nil
    end
    local travel = charTravel()
    local bind = travel and travel.Bind
    if bind and bind.Name == place and bind.MapId and bind.X and bind.Y then
        return bind
    end
    return innkeeperFor(place)
end

-- HEARTHSTONE_BOUND: keep where the player stands, with the place name.
function Teleports:RecordBind()
    local map = nxMap()
    local m = map and map.GetMap and map:GetMap(1)
    local travel = charTravel()
    local place = GetBindLocation and GetBindLocation()
    if not (m and travel and place and m.PlyrX) then
        return
    end
    travel.Bind = {
        Name = place,
        MapId = m:GetDisplayableMapForPlayer(),
        X = m.PlyrX,
        Y = m.PlyrY,
    }
    wipe(plans)
end

-------------------------------------------------------------------------------
-- What can be used now
-------------------------------------------------------------------------------

function Teleports:Ready()
    local list = {}
    if itemCount(HEARTHSTONE) > 0 and itemReady(HEARTHSTONE) then
        local bind = self:BindLocation()
        if bind then
            list[#list + 1] = {
                Name = format(L["Use Hearthstone (%s)"], bind.Name),
                Tex = HEARTH_TEX, MapId = bind.MapId, X = bind.X, Y = bind.Y,
            }
        end
    end
    if itemCount(RUNE_OF_TELEPORTATION) > 0 then
        local map = nxMap()
        for _, tp in ipairs(self.MAGE) do
            if spellKnown(tp.spell) and map then
                local wx, wy = map:GetWorldPos(tp.mapId, tp.x, tp.y)
                list[#list + 1] = {
                    Name = spellName(tp.spell) or L["Teleport"],
                    Tex = tp.tex, MapId = tp.mapId, X = wx, Y = wy,
                }
            end
        end
    end
    return list
end

-------------------------------------------------------------------------------
-- Cost, in Carbonite world units (MakePath's own measure)
-------------------------------------------------------------------------------

-- Seconds of travel as ground distance at the player's current speed.
function Teleports:SecondsToUnits(seconds)
    local travel = _G.Nx and _G.Nx.Travel
    local riding = travel and travel.GetRidingSkill and travel:GetRidingSkill() or 0
    local mult = riding >= 150 and 2 or (riding >= 75 and 1.6 or 1)
    return seconds * RUN_YPS * mult / YARDS
end

local function continent(mapId)
    local map = nxMap()
    return mapId and map and map.IdToContZone and map:IdToContZone(mapId) or nil
end

-- Route from (srcMapId, srcX, srcY) through the entries, the last one being
-- the destination. Flights cost distance x Travel.Speed, a change of
-- continent a boat leg; the rest is walking distance.
function Teleports:Cost(srcMapId, srcX, srcY, entries)
    local travel = _G.Nx and _G.Nx.Travel
    local speed = travel and travel.Speed or 1
    local total, x, y, cont = 0, srcX, srcY, continent(srcMapId)
    for _, e in ipairs(entries) do
        local c = e.MapId and continent(e.MapId) or cont
        if c and cont and c ~= cont then
            total = total + self:SecondsToUnits(BOAT_SECONDS)
        else
            local d = ((e.TargetMX - x) ^ 2 + (e.TargetMY - y) ^ 2) ^ .5
            total = total + (e.Mode == "F" and d * speed or d)
        end
        x, y, cont = e.TargetMX, e.TargetMY, c
    end
    return total
end

-------------------------------------------------------------------------------
-- Choice
-------------------------------------------------------------------------------

local function enabled()
    local db = _G.Nx and _G.Nx.db and _G.Nx.db.profile
    return db and db.Map and db.Map.RouteTeleports == true or false
end

local function routeFrom(makePath, mapId, x, y, dstMapId, dstX, dstY, targetType)
    local entries = {}
    makePath(entries, mapId, x, y, dstMapId, dstX, dstY, targetType)
    entries[#entries + 1] = { MapId = dstMapId, TargetMX = dstX, TargetMY = dstY }
    return entries
end

---
-- The entries to put in front of a route, or nil to keep it as it is.
-- makePath(tracking, srcMapId, srcX, srcY, dstMapId, dstX, dstY, type) is
-- Travel:MakePath bound to Travel. The returned list holds the "use" step at
-- the player's position, the jump (Mode "T") to the teleport's destination
-- and MakePath's route from there; the caller adds the target itself.
--
function Teleports:Plan(makePath, srcMapId, srcX, srcY, dstMapId, dstX, dstY, targetType)
    if not enabled() then
        return nil
    end
    local key = format("%s:%.0f:%.0f", tostring(dstMapId), dstX, dstY)
    local cached = plans[key]
    local choice
    if cached and now() - cached.at < PLAN_TTL then
        choice = cached.choice
    else
        local ready = self:Ready()
        if #ready > 0 then
            local direct = self:Cost(srcMapId, srcX, srcY,
                routeFrom(makePath, srcMapId, srcX, srcY, dstMapId, dstX, dstY, targetType))
            local best, bestCost = nil, direct - self:SecondsToUnits(MARGIN_SECONDS)
            local castCost = self:SecondsToUnits(CAST_SECONDS)
            for _, tp in ipairs(ready) do
                local cost = castCost + self:Cost(tp.MapId, tp.X, tp.Y,
                    routeFrom(makePath, tp.MapId, tp.X, tp.Y, dstMapId, dstX, dstY, targetType))
                if cost < bestCost then
                    best, bestCost = tp, cost
                end
            end
            choice = best
        end
        plans[key] = { at = now(), choice = choice or false }
    end
    if not choice then
        announced[key] = nil
        return nil
    end
    -- Once per destination and choice: the icon alone was easy to miss.
    if announced[key] ~= choice.Name then
        announced[key] = choice.Name
        local nx = _G.Nx
        if nx and nx.prt then
            nx.prt(L["Route: %s first"], choice.Name)
        end
    end

    local out = {
        {
            TargetType = targetType, TargetName = choice.Name, TargetTex = choice.Tex,
            TeleportUse = true,     -- drawn large over the player (MapEngine)
            MapId = srcMapId, TargetMX = srcX, TargetMY = srcY,
            TargetX1 = srcX, TargetY1 = srcY, TargetX2 = srcX, TargetY2 = srcY,
        },
        {
            TargetType = targetType, TargetName = choice.Name, TargetTex = choice.Tex,
            MapId = choice.MapId, TargetMX = choice.X, TargetMY = choice.Y,
            TargetX1 = choice.X, TargetY1 = choice.Y, TargetX2 = choice.X, TargetY2 = choice.Y,
            Mode = "T",
        },
    }
    makePath(out, choice.MapId, choice.X, choice.Y, dstMapId, dstX, dstY, targetType)
    return out
end

function Teleports:Forget()
    wipe(plans)
end

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------

if CreateFrame then
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("HEARTHSTONE_BOUND")
    frame:SetScript("OnEvent", function()
        Teleports:RecordBind()
    end)
end

return Teleports
