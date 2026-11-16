-- Carbonite | Modules / Map / BlizzardPin
-- Blizzard's 3D waypoint pin, with its distance in the world, on Carbonite's
-- navigation target (#81). The game draws the pin for the user waypoint
-- (C_Map.SetUserWaypoint) when it is super tracked.
--
-- Carbonite already follows the user waypoint the other way round: a pin the
-- player drops on the Blizzard map becomes a Carbonite target
-- (Nx.Quest:OnUserWaypointUpdated). After placing or clearing its own pin this
-- module re-seeds that listener with the new waypoint, so the event that
-- follows reads as "no change" and no target is made back from it.
--
-- The Blizzard map's data providers run on USER_WAYPOINT_UPDATED; to keep
-- Carbonite's taint out of them, nothing changes in combat or while the world
-- map is open: the pin catches up when it closes.
--
--   BP:Desired()  uiMapID, x, y (0..1) of the target the pin should mark, or nil
--   BP:Sync()     place, move or clear the pin to match

local Carbonite = _G.Carbonite
local Nx = _G.Nx
local BP = {}
Carbonite.Modules.Map.BlizzardPin = BP

local SYNC_SECONDS = 0.5

local placed    -- { uiMapID, x, y } of the pin this module put down, nil when none

local function Enabled()
    local profile = Nx.db and Nx.db.profile
    return profile and profile.Track and profile.Track.BlizzardPin
end

local function Available()
    return _G.C_Map and _G.C_Map.SetUserWaypoint and _G.C_Map.ClearUserWaypoint
        and _G.C_SuperTrack and _G.C_SuperTrack.SetSuperTrackedUserWaypoint
        and _G.UiMapPoint and _G.UiMapPoint.CreateFromCoordinates
end

local function Blocked()
    local worldMap = _G.WorldMapFrame
    return InCombatLockdown() or (worldMap and worldMap:IsShown())
end

-- The user waypoint listener takes the waypoint now in place as already seen.
local function Reseed()
    if Nx.Quest and Nx.Quest.SeedUserWaypoint then Nx.Quest:SeedUserWaypoint() end
end

function BP:Desired()
    local map = Nx.Map and Nx.Map.GetMap and Nx.Map:GetMap(1)
    local tar = map and map.Targets and map.Targets[1]
    -- A target made from the Blizzard pin already has its pin.
    if not tar or tar.UserWaypoint or not tar.MapId or not tar.TargetMX then return nil end
    local zx, zy = map:GetZonePos(tar.MapId, tar.TargetMX, tar.TargetMY)
    if type(zx) ~= "number" or type(zy) ~= "number" then return nil end
    zx, zy = zx / 100, zy / 100
    if zx < 0 or zy < 0 or zx > 1 or zy > 1 then return nil end
    local canSet = _G.C_Map.CanSetUserWaypointOnMap
    if canSet and not canSet(tar.MapId) then return nil end
    return tar.MapId, zx, zy
end

-- Whether the user waypoint in place now is the one this module put down.
-- The client keeps the position as floats, so it is compared loosely.
local function StillOurs()
    local get = _G.C_Map.GetUserWaypoint
    local point = get and get()
    local pos = point and point.position
    if not (placed and point and pos and pos.x and pos.y) then return false end
    return point.uiMapID == placed[1] and math.abs(pos.x - placed[2]) < 0.001
        and math.abs(pos.y - placed[3]) < 0.001
end

-- Takes the pin away only while it is still ours: one the player put down
-- on the Blizzard map in the meantime stays.
local function Clear()
    if not placed then return end
    local mine = StillOurs()
    placed = nil
    if mine then
        _G.C_Map.ClearUserWaypoint()
        Reseed()
    end
end

function BP:Sync()
    if not Available() or Blocked() then return end
    local mapId, x, y
    if Enabled() then mapId, x, y = self:Desired() end
    if not mapId then
        Clear()
        return
    end
    if placed and placed[1] == mapId and placed[2] == x and placed[3] == y then return end
    local ok = pcall(_G.C_Map.SetUserWaypoint, _G.UiMapPoint.CreateFromCoordinates(mapId, x, y))
    if not ok then return end
    pcall(_G.C_SuperTrack.SetSuperTrackedUserWaypoint, true)
    placed = { mapId, x, y }
    Reseed()
end

local elapsedTotal = 0
local driver = CreateFrame("Frame")
driver:SetScript("OnUpdate", function(_, elapsed)
    elapsedTotal = elapsedTotal + elapsed
    if elapsedTotal < SYNC_SECONDS then return end
    elapsedTotal = 0
    if Nx.db then BP:Sync() end
end)
