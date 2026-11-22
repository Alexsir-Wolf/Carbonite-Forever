-- Carbonite | Modules / Integrations / Navigator
-- Who guides the player to Carbonite's destinations (#222, #223): Carbonite
-- itself, the real TomTom or Shortest Path Forever. The player picks one in
-- the setup assistant or in the Tracking options (Track.Navigator); the map,
-- quests and destination list stay in Carbonite whatever the choice.
--
--   carbonite  Carbonite's HUD arrow and route line (walking legs from SPF's
--              WalkPath when it is loaded, GroundRoute.lua); guides that
--              call TomTom talk to Carbonite's emulation.
--   tomtom     the current destination becomes a TomTom waypoint and TomTom's
--              arrow leads; Carbonite still draws its route line.
--   spf        the destinations go to ShortestPathForever.API.NavigateRoute;
--              SPF plans by time and guides with its own arrow and line.
--
-- The global TomTom is set at load time, so a new choice takes a reload.
-- A saved choice whose addon is no longer enabled falls back to carbonite.
--
-- Public API:
--   Navigator:Saved()            raw saved choice
--   Navigator:Available(choice)  that addon installed and enabled
--   Navigator:Active()           effective choice (with fallback)
--   Navigator:TomTomEnabled()    the TomTom addon itself (not an emulation)
--   Navigator:SPFEnabled()       Shortest Path Forever installed and enabled
--   Navigator:SPFApi()           SPF's API table when usable, else nil
--   Navigator:ShouldEmulateTomTom()
--   Navigator:HidesCarbArrow()   another addon leads the current destination
--   Navigator:HidesCarbRoute()   SPF leads: no Carbonite path or trail
--   Navigator:Sync()             hand the destinations over (ticker)
--   Navigator:Start()            start the ticker when another addon guides

local Carbonite = _G.Carbonite
local L = LibStub("AceLocale-3.0"):GetLocale("Carbonite")

local Navigator = {}
Carbonite.Modules = Carbonite.Modules or {}
Carbonite.Modules.Integrations = Carbonite.Modules.Integrations or {}
Carbonite.Modules.Integrations.Navigator = Navigator

Navigator.OWNER = "Carbonite"
Navigator.CHOICES = { "carbonite", "tomtom", "spf" }
Navigator.MAX_STOPS = 64          -- NavigateRoute's own limit
Navigator.TICK = 0.5              -- seconds between hand-over checks

local VALID = { carbonite = true, tomtom = true, spf = true }

-------------------------------------------------------------------------------
-- Detection
-------------------------------------------------------------------------------

local function addonLoaded(name)
    local C = _G.C_AddOns
    if type(C) == "table" and type(C.IsAddOnLoaded) == "function" then
        return C.IsAddOnLoaded(name) and true or false
    end
    if type(_G.IsAddOnLoaded) == "function" then
        return _G.IsAddOnLoaded(name) and true or false
    end
    return false
end

-- Loaded, or installed and enabled for this character so it loads after
-- Carbonite (TomTom and ShortestPathForever sort after it).
local function addonEnabled(name)
    if addonLoaded(name) then return true end
    local C = _G.C_AddOns
    if type(C) ~= "table" then return false end
    if type(C.DoesAddOnExist) == "function" and not C.DoesAddOnExist(name) then
        return false
    end
    if type(C.GetAddOnEnableState) == "function" then
        local who = _G.UnitGUID and _G.UnitGUID("player") or nil
        local ok, state = pcall(C.GetAddOnEnableState, name, who)
        if ok then return state == nil or (tonumber(state) or 0) > 0 end
    end
    return type(C.DoesAddOnExist) == "function"
end

function Navigator:TomTomEnabled()
    return addonEnabled("TomTom")
end

function Navigator:SPFEnabled()
    return addonEnabled("ShortestPathForever")
end

-- SPF's published API: callers accept versions 1 and 2 and check that each
-- function exists (docs/api.md of Shortest Path Forever).
function Navigator:SPFApi()
    local spf = rawget(_G, "ShortestPathForever")
    local api = type(spf) == "table" and spf.API or nil
    if type(api) ~= "table" then return nil end
    local version = tonumber(api.version)
    if version ~= 1 and version ~= 2 then return nil end
    if type(api.NavigateRoute) ~= "function" or type(api.Cancel) ~= "function" then
        return nil
    end
    return api
end

-- The real TomTom's table, ready to take waypoints.
local function tomtomApi()
    local tom = rawget(_G, "TomTom")
    if not addonLoaded("TomTom") or type(tom) ~= "table" then return nil end
    if type(tom.AddWaypoint) ~= "function" or type(tom.RemoveWaypoint) ~= "function" then
        return nil
    end
    return tom
end

-------------------------------------------------------------------------------
-- Choice
-------------------------------------------------------------------------------

local function track()
    local Nx = _G.Nx
    local profile = Nx and Nx.db and Nx.db.profile
    return profile and profile.Track
end

function Navigator:Saved()
    local t = track()
    local choice = t and t.Navigator
    return VALID[choice] and choice or "carbonite"
end

function Navigator:Set(choice)
    local t = track()
    if t and VALID[choice] then t.Navigator = choice end
end

function Navigator:Available(choice)
    if choice == "carbonite" then return true end
    if choice == "tomtom" then return self:TomTomEnabled() end
    if choice == "spf" then return self:SPFEnabled() end
    return false
end

function Navigator:Active()
    local choice = self:Saved()
    if choice ~= "carbonite" and self:Available(choice) then return choice end
    return "carbonite"
end

-- The saved choice is an addon that is gone: the assistant asks again.
function Navigator:SavedUnavailable()
    return not self:Available(self:Saved())
end

-- Carbonite answers TomTom calls only while it guides, without the real
-- TomTom, and with the emulation option on.
function Navigator:ShouldEmulateTomTom()
    if self:TomTomEnabled() then return false end
    if self:Active() ~= "carbonite" then return false end
    local t = track()
    return not (t and t.EmuTomTom == false)
end

-------------------------------------------------------------------------------
-- Hand-over state
-------------------------------------------------------------------------------

local state = {
    guide = nil,      -- "tomtom" / "spf" the destinations were handed to
    sig = nil,        -- signature of the destinations last handed over
    handed = false,   -- the other addon leads the current destination
    tomUid = nil,     -- TomTom waypoint made for the current destination
    tomTarget = nil,  -- UniqueId of the Carbonite target it stands for
    spfSent = false,  -- SPF has a journey owned by Carbonite
    retry = false,    -- SPF refused in combat: send again after it
    warned = false,   -- refusal message already shown
}
Navigator._state = state

function Navigator:HidesCarbArrow()
    return state.handed and true or false
end

function Navigator:HidesCarbRoute()
    return state.handed and state.guide == "spf" or false
end

local function primaryMap()
    local Nx = _G.Nx
    local Map = Nx and Nx.Map
    if Map and Map.GetMap then return Map:GetMap(1) end
    return Map and Map.Maps and Map.Maps[1]
end

-- A Carbonite target as a uiMapID and 0-1 point, or nil when it has none
-- the client knows.
local function placeOf(map, tar)
    if not (tar and tar.MapId and tar.TargetMX and tar.TargetMY and map and map.GetZonePos) then
        return nil
    end
    local C_Map = _G.C_Map
    if not (C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(tar.MapId)) then return nil end
    local zx, zy = map:GetZonePos(tar.MapId, tar.TargetMX, tar.TargetMY)
    if type(zx) ~= "number" or type(zy) ~= "number" then return nil end
    zx, zy = zx / 100, zy / 100
    if zx < 0 or zy < 0 or zx > 1 or zy > 1 then return nil end
    return tar.MapId, zx, zy
end

local function signature(targets, count)
    local parts = {}
    for i = 1, math.min(#targets, count) do
        local t = targets[i]
        parts[#parts + 1] = string.format("%s@%s:%.1f:%.1f", tostring(t.UniqueId),
            tostring(t.MapId), t.TargetMX or 0, t.TargetMY or 0)
    end
    return table.concat(parts, "|")
end

local function message(text)
    local Nx = _G.Nx
    if Nx and Nx.prt then Nx.prt("%s", text) end
end

-- Remove one Carbonite target, through the Targets module when present.
local function removeTarget(uniqueId)
    local Targets = Carbonite.Modules.Map and Carbonite.Modules.Map.Targets
    if Targets and Targets.Remove and Targets:Remove(uniqueId) then return end
    local map = primaryMap()
    if map and map.ClearTarget then map:ClearTarget(uniqueId) end
end

local function clearTargets()
    local map = primaryMap()
    if map and map.ClearTargets then map:ClearTargets() end
end

-------------------------------------------------------------------------------
-- TomTom (#223)
-------------------------------------------------------------------------------

local function tomRemove()
    local tom = tomtomApi()
    if state.tomUid and tom then pcall(tom.RemoveWaypoint, tom, state.tomUid) end
    state.tomUid, state.tomTarget = nil, nil
end

local function tomSync(map, targets)
    local tom = tomtomApi()
    if not tom then
        state.handed = false
        return
    end
    -- TomTom dropped the waypoint (arrival or removed by the player): the
    -- destination it stood for leaves Carbonite too.
    if state.tomUid and type(tom.IsValidWaypoint) == "function"
        and not tom:IsValidWaypoint(state.tomUid) then
        local gone = state.tomTarget
        state.tomUid, state.tomTarget, state.handed = nil, nil, false
        if gone then
            removeTarget(gone)
            targets = map.Targets or {}
        end
    end

    local sig = signature(targets, 1)
    if sig == state.sig then return end
    state.sig = sig
    tomRemove()

    local tar = targets[1]
    local m, x, y = placeOf(map, tar)
    if not m then
        state.handed = false
        return
    end
    local ok, uid = pcall(tom.AddWaypoint, tom, m, x, y, {
        title = tar.TargetName or "",
        from = "Carbonite",
        persistent = false,
        minimap = true,
        world = true,
        crazy = true,
        silent = true,
    })
    if ok and uid then
        state.tomUid, state.tomTarget, state.handed = uid, tar.UniqueId, true
    else
        state.handed = false
    end
end

-------------------------------------------------------------------------------
-- Shortest Path Forever (#222)
-------------------------------------------------------------------------------

local SPF_ENDS = { arrived = true, cleared = true, replaced = true }

local function spfCancel()
    local api = Navigator:SPFApi()
    if state.spfSent and api then pcall(api.Cancel, Navigator.OWNER) end
    state.spfSent = false
end

-- SPF ended Carbonite's journey on its side: the destinations leave
-- Carbonite too, so the two lists never disagree.
function Navigator:OnSPFChange()
    if not state.spfSent then return end
    local api = self:SPFApi()
    if not api or type(api.Ended) ~= "function" then return end
    local current = type(api.CurrentStop) == "function" and api.CurrentStop(self.OWNER)
    if current then return end
    local why = api.Ended(self.OWNER)
    if SPF_ENDS[why] then
        state.spfSent, state.handed, state.retry = false, false, false
        clearTargets()
        state.sig = ""
    end
end

local function spfSubscribe(api)
    if state.subscribed or type(api.Subscribe) ~= "function" then return end
    state.subscribed = true
    api.Subscribe(function() Navigator:OnSPFChange() end)
end

local function spfSync(map, targets)
    local api = Navigator:SPFApi()
    if not api then
        state.handed = false
        return
    end
    spfSubscribe(api)

    local sig = signature(targets, Navigator.MAX_STOPS)
    local combat = _G.InCombatLockdown and _G.InCombatLockdown()
    if sig == state.sig and not (state.retry and not combat) then return end
    state.sig, state.retry = sig, false

    if #targets == 0 then
        spfCancel()
        state.handed = false
        return
    end

    local stops = {}
    for i = 1, math.min(#targets, Navigator.MAX_STOPS) do
        local tar = targets[i]
        local m, x, y = placeOf(map, tar)
        if m then
            stops[#stops + 1] = { map = m, x = x, y = y, title = tar.TargetName }
        end
    end
    if #stops == 0 then
        spfCancel()
        state.handed = false
        return
    end

    local ok, accepted = pcall(api.NavigateRoute, Navigator.OWNER, stops)
    if ok and accepted == true then
        state.spfSent, state.handed = true, true
        return
    end
    state.handed = false
    if combat then
        state.retry = true
    elseif not state.warned then
        state.warned = true
        message(L["Shortest Path Forever did not accept the route (journeys off?). Carbonite's arrow guides this destination."])
    end
end

-------------------------------------------------------------------------------
-- Driver
-------------------------------------------------------------------------------

-- Give the other addon back its hold: remove the waypoint / cancel the journey.
function Navigator:Release()
    if state.guide == "tomtom" then tomRemove() end
    if state.guide == "spf" then spfCancel() end
    state.guide, state.sig, state.handed, state.retry = nil, nil, false, false
end

function Navigator:Sync()
    local guide = self:Active()
    if guide ~= state.guide then
        self:Release()
        if guide == "carbonite" then return end
        state.guide = guide
    end
    if guide == "carbonite" then return end

    local map = primaryMap()
    if not map then return end
    local targets = map.Targets or {}
    if guide == "tomtom" then
        if #targets == 0 then
            if state.tomUid then tomRemove() end
            state.sig, state.handed = "", false
            return
        end
        tomSync(map, targets)
    else
        spfSync(map, targets)
    end
end

function Navigator:Start()
    if self.ticker or self:Active() == "carbonite" then return end
    local C_Timer = _G.C_Timer
    if not (C_Timer and C_Timer.NewTicker) then return end
    self.ticker = C_Timer.NewTicker(self.TICK, function()
        local ok, err = pcall(Navigator.Sync, Navigator)
        if not ok and not state.errored then
            state.errored = true
            local handler = _G.geterrorhandler and _G.geterrorhandler()
            if handler then handler(err) end
        end
    end)
end

local bus = Carbonite.Core and Carbonite.Core.EventBus
if bus and bus.Subscribe then
    bus:Subscribe("CARBONITE_ENABLE", function() Navigator:Start() end)
end

return Navigator
