-- Carbonite | Modules / Map / DungeonRouteRecorder
-- A route from a run (#272): while the player runs a dungeon, the rooms the
-- game names and the boss kills (ENCOUNTER_END) are written down, with the
-- room each boss fell in. Afterwards one click turns this into a player
-- route: the bosses where they fell (else where the standard route has
-- them), the path through the rooms in the order of the run, one main path
-- per stretch on a floor. The method follows ForeverDungeonRoutes'
-- Recorder.lua (Checkov23, MIT).
--
-- Kept per character in Nx.db.char.DungeonRecording:
--   { key, started, time, events = { { room = name } | { kill = encounterID, name, room } } }
--
-- Public (Nx.DungeonRoutes.Recorder):
--   Rec:OnEnter(key) / Rec:OnRoom(key, room) / Rec:OnKill(encounterID, name)
--   Rec:Current() / Rec:CanBuild(key) / Rec:Build(key)   route made active, or nil

local Nx = _G.Nx
if not Nx then return end

local R = Nx.DungeonRoutes
if not R then return end

local L = LibStub("AceLocale-3.0"):GetLocale("Carbonite")

local Rec = {}
R.Recorder = Rec

Rec.MAX_EVENTS = 400
Rec.MAX_AGE = 2 * 60 * 60   -- a pause this long starts a new recording
local SPREAD = 0.025        -- bosses that fell in the same room stand side by side

local function now()
    return _G.time and _G.time() or 0
end

local function char()
    local c = Nx.db and Nx.db.char
    if type(c) ~= "table" then
        Rec.Session = Rec.Session or {}
        return Rec.Session
    end
    return c
end

function Rec:Current()
    local rec = char().DungeonRecording
    return type(rec) == "table" and rec or nil
end

local function start(key)
    local rec = { key = key, started = now(), time = now(), events = {} }
    char().DungeonRecording = rec
    return rec
end

local function lastRoom(rec)
    for i = #rec.events, 1, -1 do
        if rec.events[i].room then return rec.events[i].room end
    end
end

local function add(rec, event)
    if #rec.events >= Rec.MAX_EVENTS then return end
    rec.events[#rec.events + 1] = event
    rec.time = now()
end

-- Entering a dungeon: another dungeon, or the same after a long pause, starts anew.
function Rec:OnEnter(key)
    if not key then return end
    local rec = self:Current()
    if not rec or rec.key ~= key or now() - (rec.time or rec.started or 0) > Rec.MAX_AGE then
        start(key)
    end
end

function Rec:OnRoom(key, room)
    local rec = self:Current()
    if not rec or rec.key ~= key or not room or not room.name then return end
    if room.name ~= lastRoom(rec) then add(rec, { room = room.name }) end
end

-- The game reports a kill once per fight; a boss dies once a run.
function Rec:OnKill(encounterID, name)
    local rec = self:Current()
    local key = R:IsLoaded() and R:CurrentKey()
    if not rec or type(encounterID) ~= "number" or rec.key ~= key then return end
    for _, e in ipairs(rec.events) do
        if e.kill == encounterID then return end
    end
    local room = R:Room()
    add(rec, { kill = encounterID, name = name, room = room and room.name or lastRoom(rec) })
end

function Rec:CanBuild(key)
    local rec = self:Current()
    if not rec or rec.key ~= key then return false end
    for _, e in ipairs(rec.events) do
        if e.kill then return true end
    end
    return false
end

local function roomPoint(key, name)
    if not name then return nil end
    local data = R:Data()
    for _, room in ipairs(data and data.Rooms and data.Rooms[key] or {}) do
        if room.name == name then
            local floor = R.RoomMainFloor(room)
            local x, y = R.RoomCenter(room, floor)
            if x then return floor, x, y end
        end
    end
end

local function standardStop(key, encounterID)
    for _, route in ipairs(R:Routes(key)) do
        if R.IsBuiltIn(route) then
            for _, stop in ipairs(route.stops or {}) do
                for _, id in ipairs(stop.encounters or {}) do
                    if id == encounterID then return stop end
                end
            end
        end
    end
end

local function encounterFor(key, encounterID)
    local d = R:Dungeon(key)
    local data = R:Data()
    for _, e in ipairs(d and data and data.Encounters and data.Encounters[d.instanceID] or {}) do
        for _, id in ipairs(e.ids or {}) do
            if id == encounterID then return e end
        end
    end
end

local function clamp(v)
    return math.max(0.01, math.min(0.99, v))
end

-- Turns the recording into a player route of the dungeon (made active).
function Rec:Build(key)
    if not self:CanBuild(key) then return nil end
    local rec = self:Current()
    local dungeon = R:Dungeon(key)
    if not dungeon then return nil end
    local points, stops, used, last = {}, {}, {}, nil
    for _, e in ipairs(rec.events) do
        local floor, x, y
        if e.kill then
            local standard = standardStop(key, e.kill)
            floor, x, y = roomPoint(key, e.room)
            if not floor and standard then floor, x, y = standard.floor, standard.x, standard.y end
            if not floor and last then floor, x, y = last[1], last[2], last[3] end
            if not floor then floor, x, y = dungeon.floors[1], 0.5, 0.5 end
            local spot = floor .. ":" .. math.floor(x * 200) .. ":" .. math.floor(y * 200)
            used[spot] = (used[spot] or -1) + 1
            local stop = { kind = standard and standard.kind or "boss", floor = floor,
                x = clamp(x + SPREAD * used[spot]), y = clamp(y) }
            local encounter = encounterFor(key, e.kill)
            if encounter then
                R.SetNames(stop, encounter)
                stop.encounters = {}
                for i, id in ipairs(encounter.ids) do stop.encounters[i] = id end
            else
                stop.name, stop.encounters = e.name or "?", { e.kill }
            end
            stops[#stops + 1] = stop
            x, y = stop.x, stop.y
        elseif e.room then
            floor, x, y = roomPoint(key, e.room)
        end
        if floor then
            local p = points[#points]
            if not p or p[1] ~= floor or math.abs(p[2] - x) + math.abs(p[3] - y) > 0.002 then
                points[#points + 1] = { floor, clamp(x), clamp(y) }
            end
            last = points[#points]
        end
    end
    local paths, piece = {}, nil
    for _, p in ipairs(points) do
        if not piece or piece.floor ~= p[1] then
            if piece and #piece.pts >= 4 then paths[#paths + 1] = piece end
            piece = { kind = "main", floor = p[1], pts = {} }
        end
        piece.pts[#piece.pts + 1] = p[2]
        piece.pts[#piece.pts + 1] = p[3]
    end
    if piece and #piece.pts >= 4 then paths[#paths + 1] = piece end
    local stamp = _G.date and _G.date("%Y-%m-%d %H:%M", rec.started) or tostring(rec.started)
    local route = { name = format(L["Recorded run %s"], stamp),
        paths = paths, stops = stops, notes = {}, links = {} }
    return R:AddUserRoute(key, route)
end
