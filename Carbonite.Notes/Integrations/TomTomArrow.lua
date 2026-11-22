-- Carbonite.Notes | Integrations / TomTom arrow
-- With the real TomTom installed, the destinations other addons send it
-- (RareScanner, Attune, Questie, /way) go to TomTom's arrow, not Carbonite's.
-- This follows TomTom's arrow target and points Carbonite's HUD arrow at the
-- same place, and hides TomTom's arrow while it does (#73).
--
-- Integration only: it uses TomTom's public callbacks (ArrowTargetChanged)
-- or, on a TomTom without them, a hook on SetCrazyArrow. No TomTom code.
--
--   Nx.Notes:TomTomArrowFollow(uid)  point Carbonite's arrow at a TomTom
--                                    waypoint ({ mapId, x, y, title = }), nil clears
--   Nx.Notes:TomTomArrowSync()       apply the option (after toggling it)

local Nx = _G.Nx
if not Nx then return end
Nx.Notes = Nx.Notes or {}

local activeUid     -- Carbonite target mirroring TomTom's arrow
local lastWaypoint  -- TomTom's current arrow target
local hiding        -- TomTom's arrow is being hidden by us

-- The TomTom addon itself, not Carbonite's emulation of its API.
local function RealTomTom()
    local loaded = _G.C_AddOns and _G.C_AddOns.IsAddOnLoaded or _G.IsAddOnLoaded
    return loaded and loaded("TomTom") and true or false
end

-- With TomTom chosen to guide (#223), Carbonite's destinations go to
-- TomTom's arrow; following that arrow back would loop.
local function TomTomLeads()
    local C = _G.Carbonite
    local integrations = C and C.Modules and C.Modules.Integrations
    local nav = integrations and integrations.Navigator
    return nav and nav:Active() == "tomtom" or false
end

local function Enabled()
    local notes = Nx.fdb and Nx.fdb.profile and Nx.fdb.profile.Notes
    return notes and notes.TomTomArrow and RealTomTom() and not TomTomLeads() or false
end

local function TomTomArrowFrame()
    return _G.TomTomCrazyArrow
end

local function Clear()
    if activeUid and Nx.TTRemoveWaypoint then Nx:TTRemoveWaypoint(activeUid) end
    activeUid = nil
end

function Nx.Notes:TomTomArrowFollow(waypoint)
    lastWaypoint = waypoint
    if not Enabled() then return end
    Clear()
    if type(waypoint) ~= "table" then return end
    local map, x, y = waypoint[1], waypoint[2], waypoint[3]
    if type(map) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then return end
    local title = waypoint.title or ""
    activeUid = Nx.TTAddWaypoint and Nx:TTAddWaypoint(map, x, y, { title = title }) or nil
    if activeUid and Nx.TTSetCrazyArrow then Nx:TTSetCrazyArrow(activeUid, 0, title) end
    local frame = TomTomArrowFrame()
    if frame then frame:Hide() end
end

function Nx.Notes:TomTomArrowSync()
    local frame = TomTomArrowFrame()
    if Enabled() then
        hiding = true
        self:TomTomArrowFollow(lastWaypoint)
    else
        Clear()
        if hiding and frame and lastWaypoint then frame:Show() end
        hiding = false
    end
end

-- TomTom shows its arrow on every new target; hide it again while we lead.
local function HookFrame()
    local frame = TomTomArrowFrame()
    if not frame or frame.CarboniteHooked then return end
    frame.CarboniteHooked = true
    hooksecurefunc(frame, "Show", function(f)
        if Enabled() then f:Hide() end
    end)
end

local function Follow(_, uid) Nx.Notes:TomTomArrowFollow(uid) end

local driver = CreateFrame("Frame")
driver:RegisterEvent("PLAYER_LOGIN")
driver:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    local tom = _G.TomTom
    if not RealTomTom() or type(tom) ~= "table" then return end
    if type(tom.RegisterCallback) == "function" then
        tom.RegisterCallback(Nx.Notes, "ArrowTargetChanged", Follow)
    elseif type(tom.SetCrazyArrow) == "function" then
        hooksecurefunc(tom, "SetCrazyArrow", Follow)
    end
    HookFrame()
    hiding = Enabled()
end)
