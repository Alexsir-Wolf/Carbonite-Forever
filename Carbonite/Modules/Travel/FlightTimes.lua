-- Carbonite | Modules / Travel / FlightTimes
-- Measured flight times per pair of flight-master nodes (#139).
-- Nx.FlightConnection ships empty, so the taxi ETA and the route had no
-- duration for any flight. Each flight the player takes is timed from the
-- loss of control on take-off to the landing and kept account-wide in
-- Nx.db.global.FlightTimes, keyed by "<source node>#<destination node>"
-- (the names TaxiNodeName returns), so every character benefits.
--
-- Public API:
--   FlightTimes:Key(src, dest)          - storage key for a pair
--   FlightTimes:Get(src, dest)          - seconds, or 0 when unknown
--   FlightTimes:Record(src, dest, secs) - store a measured time
--   FlightTimes:Begin(src, dest)        - flight requested (TakeTaxiNode)
--   FlightTimes:OnEvent(event)          - PLAYER_CONTROL_LOST / _GAINED

local Carbonite = _G.Carbonite

local FlightTimes = {}
Carbonite.Modules.FlightTimes = FlightTimes

-- Seconds allowed between the click on the destination and the take-off.
FlightTimes.TAKEOFF_WINDOW = 15
-- Anything shorter is not a real flight (cancelled, failed, teleported off).
FlightTimes.MIN_SECS = 3

local function now()
    return _G.GetTime and _G.GetTime() or 0
end

local function debugOn()
    local Nx = _G.Nx
    return Nx and Nx.db and Nx.db.profile and Nx.db.profile.Debug and Nx.db.profile.Debug.DebugMap
end

-- Account-wide store, created on first use (AceDB is ready only after load).
function FlightTimes:Store()
    local Nx = _G.Nx
    local global = Nx and Nx.db and Nx.db.global
    if not global then return nil end
    global.FlightTimes = global.FlightTimes or {}
    return global.FlightTimes
end

function FlightTimes:Key(src, dest)
    if type(src) ~= "string" or type(dest) ~= "string" or src == "" or dest == "" then
        return nil
    end
    return src .. "#" .. dest
end

function FlightTimes:Get(src, dest)
    local key = self:Key(src, dest)
    local store = key and self:Store()
    local t = store and store[key]
    return type(t) == "number" and t or 0
end

function FlightTimes:Record(src, dest, secs)
    local key = self:Key(src, dest)
    if not key or type(secs) ~= "number" or secs < self.MIN_SECS then return false end
    local store = self:Store()
    if not store then return false end
    store[key] = floor(secs * 10 + .5) / 10
    return true
end

-- A flight was requested from src to dest; timing starts on take-off.
function FlightTimes:Begin(src, dest)
    if not self:Key(src, dest) then
        self.pending = nil
        return
    end
    self.pending = { src = src, dest = dest, asked = now() }
end

function FlightTimes:OnEvent(event)
    local p = self.pending
    if not p then return end
    if event == "PLAYER_CONTROL_LOST" then
        if not p.start and now() - p.asked <= self.TAKEOFF_WINDOW then
            p.start = now()
        end
    elseif event == "PLAYER_CONTROL_GAINED" then
        self.pending = nil
        if not p.start then return end
        local secs = now() - p.start
        if self:Record(p.src, p.dest, secs) and debugOn() then
            _G.Nx.prt("Taxi %s to %s, %.1f secs", p.src, p.dest, secs)
        end
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_CONTROL_LOST")
frame:RegisterEvent("PLAYER_CONTROL_GAINED")
frame:SetScript("OnEvent", function(_, event) FlightTimes:OnEvent(event) end)
