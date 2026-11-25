-- Carbonite | Modules / Map / DungeonRoutes
-- Curated dungeon routes and the room the player is in (#272).
--
-- The data (routes, rooms, floors, encounters, the client's minimap pictures
-- of every floor) comes from ForeverDungeonRoutes by Checkov23 (MIT), copied
-- into the load-on-demand addon Carbonite.Dungeons by
-- tools/gen_dungeon_routes.py. It is loaded only inside a dungeon or when the
-- player opens a dungeon map from the picker; ForeverDungeonRoutes itself is
-- never read and need not be installed.
--
-- Coordinates: 0..1 on the 1002x668 map of a floor. Floors are the game's
-- uiMapIDs; the new Forever dungeons have "picture floors"
-- 1000000 + mapID * 10 + level.
--
-- Player routes (#272 phase 2) live in Nx.db.global.DungeonRoutes:
--   { routes = { [key] = { route, ... } }, active = { [key] = routeId }, n = last id }
-- A route: { id, name, paths = { { kind = "main"|"side", floor, pts = { x, y, ... }, t0, t1 } },
--   stops = { { kind = "boss"|"optional"|"rare", floor, x, y, name, note, encounters } },
--   notes = { { floor, x, y, text } }, links = { { floor, x, y, to, label } } }
--
-- Public (Nx.DungeonRoutes):
--   DR:Data() / DR:Load() / DR:IsLoaded()   the data table, loading it on demand
--   DR.Loc(entry, field)                    a field in the client's language
--   DR:Dungeon(key) / DR:DungeonsFor(instanceID) / DR:DungeonOfFloor(floor)
--   DR:Keys()                               all dungeon keys, by name
--   DR:KeyName(key) / DR:FloorName(floor)
--   DR.PictureMap(floor)                    mapID, level of a picture floor
--   DR.PinFloorKey(floor)                   DungeonPins key of a floor (quest pins)
--   DR:Routes(key) / DR:Route(key, id) / DR:ActiveRoute(key) / DR:SetActive(key, id)
--   DR.IsBuiltIn(route) / DR.RecalcProgress(route) / DR.StopProgress(route)
--   DR.StopLabels(route) / DR:StopName(stop)
--   DR:AddUserRoute(key, route) / DR:DeleteRoute(key, id) / DR:RenameRoute(key, id, name)
--   DR:CopyRoute(route)                     a deep copy without the built-in marks
--   DR:CurrentKey()                         key of the dungeon (wing) the player is in
--   DR:RoomNamed(key, text) / DR:Room() / DR.RoomMainFloor(room) / DR.RoomCenter(room, floor)
--   DR:OnSubZone(text)                      the game named a room
--   DR:StopKilled(stop)                     the stop's boss died this run
--   DR:BossList(key)                        { { name, floor, x, y, killed, encounters, stop } }
--   DR.Legs(route, floor, killed)           lines of the route on a floor, with their state

local Nx = _G.Nx
if not Nx then return end

local L = LibStub("AceLocale-3.0"):GetLocale("Carbonite")

local DR = { Version = 0, RoomVersion = 0 }
Nx.DungeonRoutes = DR

DR.ADDON = "Carbonite.Dungeons"
DR.MAP_W, DR.MAP_H = 1002, 668
local ASPECT = DR.MAP_H / DR.MAP_W

--------------------------------------------------------------------------------
-- Data, on demand
--------------------------------------------------------------------------------

function DR:Data()
    return Nx.DungeonRoutesData
end

function DR:IsLoaded()
    return Nx.DungeonRoutesData ~= nil
end

local function addons()
    return _G.C_AddOns or {}
end

-- Loads Carbonite.Dungeons once; nil when it is missing or turned off.
function DR:Load()
    if Nx.DungeonRoutesData then return Nx.DungeonRoutesData end
    if self.LoadTried then return nil end
    self.LoadTried = true
    local load = addons().LoadAddOn or _G.LoadAddOn
    if load then pcall(load, DR.ADDON) end
    return Nx.DungeonRoutesData
end

function DR:OnDataLoaded()
    self.Index = nil
    self.Version = self.Version + 1
    self:RefreshChart()
    if Nx.DungeonGuide then Nx.DungeonGuide.Dirty = true end
end

-- The chart learns which dungeon is current (data loaded, another wing).
function DR:RefreshChart()
    local DC = Nx.DungeonChart
    if not DC then return end
    DC.Dirty = true
    if DC.Refresh and Nx.Map then pcall(DC.Refresh, DC) end
end

local function index()
    local data = Nx.DungeonRoutesData
    if not data then return nil end
    if DR.Index and DR.Index.data == data then return DR.Index end
    local byKey, byInstance, byFloor = {}, {}, {}
    for _, d in ipairs(data.Dungeons or {}) do
        byKey[d.key] = d
        byInstance[d.instanceID] = byInstance[d.instanceID] or {}
        table.insert(byInstance[d.instanceID], d)
        for _, floor in ipairs(d.floors or {}) do byFloor[floor] = byFloor[floor] or d end
    end
    DR.Index = { data = data, byKey = byKey, byInstance = byInstance, byFloor = byFloor }
    return DR.Index
end

--------------------------------------------------------------------------------
-- Languages
--------------------------------------------------------------------------------

local SUFFIX = {
    deDE = "DE", frFR = "FR", esES = "ES", esMX = "ES", ptBR = "PT", ruRU = "RU",
    koKR = "KO", zhCN = "CN", zhTW = "TW",
}
DR.SUFFIXES = { "DE", "FR", "ES", "PT", "RU", "KO", "CN", "TW" }

function DR.Suffix()
    local locale = _G.GetLocale and _G.GetLocale()
    return SUFFIX[locale or ""]
end

function DR.Loc(entry, field)
    if type(entry) ~= "table" then return nil end
    local suffix = DR.Suffix()
    if suffix then
        local text = entry[field .. suffix]
        if type(text) == "string" and text ~= "" then return text end
    end
    return entry[field]
end

-- Whether `text` is one of the names (field) of an entry, in any language.
function DR.HasName(entry, text, field)
    field = field or "name"
    if type(text) ~= "string" or text == "" then return false end
    if entry[field] == text then return true end
    for _, s in ipairs(DR.SUFFIXES) do
        if entry[field .. s] == text then return true end
    end
    return false
end

-- Copies a name in all languages from source (or drops the other languages).
function DR.SetNames(target, source, field)
    field = field or "name"
    if source then target[field] = source[field] end
    for _, s in ipairs(DR.SUFFIXES) do
        target[field .. s] = source and source[field .. s] or nil
    end
end

--------------------------------------------------------------------------------
-- Dungeons and floors
--------------------------------------------------------------------------------

function DR:Dungeon(key)
    local i = index()
    return i and i.byKey[key]
end

function DR:DungeonsFor(instanceID)
    local i = index()
    return i and i.byInstance[instanceID] or {}
end

function DR:DungeonOfFloor(floor)
    local i = index()
    return i and i.byFloor[floor]
end

function DR:KeyName(key)
    local d = self:Dungeon(key)
    return d and DR.Loc(d, "name") or tostring(key)
end

function DR:Keys()
    local data = self:Data()
    local keys = {}
    for _, d in ipairs(data and data.Dungeons or {}) do keys[#keys + 1] = d.key end
    table.sort(keys, function(a, b) return self:KeyName(a) < self:KeyName(b) end)
    return keys
end

function DR:FloorName(floor)
    local data = self:Data()
    local info = data and data.Floors and data.Floors[floor]
    return info and DR.Loc(info, "name") or nil
end

-- mapID and level of a picture floor (1000000 + mapID * 10 + level), else nil.
function DR.PictureMap(floor)
    if type(floor) ~= "number" or floor < 1000000 then return nil end
    local rest = floor - 1000000
    return math.floor(rest / 10), rest % 10
end

-- The DungeonPins key of a floor (Carbonite's quest pins): the uiMapID for the
-- classic floors, the stand-in floor of MapUtils for the new dungeons.
function DR.PinFloorKey(floor)
    local P = Nx.DungeonPins
    if not P then return nil end
    local mapID, level = DR.PictureMap(floor)
    if not mapID then
        local key = tostring(floor)
        return P.pins[key] and key or nil
    end
    local DG = Nx.DungeonGuide
    local standIn = DG and DG.FOREVER_PIN_KEYS[mapID]
    local inst = standIn and P.instances[standIn]
    local fl = inst and inst.floors and inst.floors[level]
    return fl and fl.key or nil
end

--------------------------------------------------------------------------------
-- Routes
--------------------------------------------------------------------------------

local function store()
    local global = Nx.db and Nx.db.global
    if type(global) ~= "table" then
        DR.SessionStore = DR.SessionStore or { routes = {}, active = {}, n = 0 }
        return DR.SessionStore
    end
    local s = type(global.DungeonRoutes) == "table" and global.DungeonRoutes or {}
    global.DungeonRoutes = s
    s.routes = type(s.routes) == "table" and s.routes or {}
    s.active = type(s.active) == "table" and s.active or {}
    s.n = tonumber(s.n) or 0
    return s
end
DR.Store = store

function DR.IsBuiltIn(route)
    return type(route) == "table" and route.builtin == true
end

local function builtIns(key)
    local data = DR:Data()
    local entry = data and data.DefaultRoutes and data.DefaultRoutes[key]
    if type(entry) ~= "table" then return {} end
    if entry.paths or entry.stops then return { entry } end
    return entry
end

function DR:Routes(key)
    local list = {}
    for _, r in ipairs(builtIns(key)) do list[#list + 1] = r end
    for _, r in ipairs(store().routes[key] or {}) do list[#list + 1] = r end
    return list
end

function DR:Route(key, id)
    for _, r in ipairs(self:Routes(key)) do
        if r.id == id then return r end
    end
end

function DR:ActiveRoute(key)
    local id = store().active[key]
    local route = id and self:Route(key, id)
    if route then return route end
    return self:Routes(key)[1]
end

function DR:SetActive(key, id)
    store().active[key] = id
    self.Version = self.Version + 1
    if Nx.DungeonChart then Nx.DungeonChart.Dirty = true end
    if Nx.DungeonGuide then Nx.DungeonGuide.Dirty = true end
end

function DR:RouteName(route)
    if not route then return "" end
    return DR.Loc(route, "name") or (DR.IsBuiltIn(route) and L["Standard route"]) or route.id or ""
end

local function deepCopy(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = deepCopy(x) end
    return t
end
DR.DeepCopy = deepCopy

function DR:CopyRoute(route)
    local copy = deepCopy(route)
    copy.builtin, copy.id, copy.source = nil, nil, nil
    copy.paths = copy.paths or {}
    copy.stops = copy.stops or {}
    copy.notes = copy.notes or {}
    copy.links = copy.links or {}
    return copy
end

-- Adds a player route (made active); returns it.
function DR:AddUserRoute(key, route)
    local s = store()
    s.n = s.n + 1
    route.id = "user:" .. s.n
    route.builtin = nil
    s.routes[key] = s.routes[key] or {}
    table.insert(s.routes[key], route)
    DR.RecalcProgress(route)
    self:SetActive(key, route.id)
    return route
end

function DR:DeleteRoute(key, id)
    local list = store().routes[key] or {}
    for i, r in ipairs(list) do
        if r.id == id then
            table.remove(list, i)
            if store().active[key] == id then store().active[key] = nil end
            self:SetActive(key, store().active[key])
            return true
        end
    end
    return false
end

function DR:RenameRoute(key, id, name)
    local route = self:Route(key, id)
    if not route or DR.IsBuiltIn(route) then return false end
    DR.SetNames(route, nil)
    route.name = tostring(name or ""):gsub("[\t\r\n|]", " "):sub(1, 60)
    self.Version = self.Version + 1
    return true
end

-- Spreads 0..1 over the main paths in their order, by length (the route's progress).
function DR.RecalcProgress(route)
    local total, lengths = 0, {}
    for i, path in ipairs(route.paths or {}) do
        if path.kind == "main" then
            local len, pts = 0, path.pts
            for j = 3, #pts - 1, 2 do
                local dx, dy = pts[j] - pts[j - 2], (pts[j + 1] - pts[j - 1]) * ASPECT
                len = len + math.sqrt(dx * dx + dy * dy)
            end
            lengths[i] = len
            total = total + len
        end
    end
    local run = 0
    for i, path in ipairs(route.paths or {}) do
        if path.kind == "main" then
            path.t0 = total > 0 and run / total or 0
            run = run + lengths[i]
            path.t1 = total > 0 and run / total or 1
        end
    end
end

-- Cumulative lengths of a path's points (aspect corrected).
local function cumulative(pts)
    local cum = { 0 }
    for j = 3, #pts - 1, 2 do
        local dx, dy = pts[j] - pts[j - 2], (pts[j + 1] - pts[j - 1]) * ASPECT
        cum[#cum + 1] = cum[#cum] + math.sqrt(dx * dx + dy * dy)
    end
    return cum
end

-- Progress (0..1) of each stop along the main paths: the nearest point of a
-- main path on its floor. Stops away from every path: nil.
function DR.StopProgress(route)
    local result = {}
    for i, stop in ipairs(route.stops or {}) do
        local best, bestD
        for _, path in ipairs(route.paths or {}) do
            if path.kind == "main" and path.floor == stop.floor and path.t0 and #path.pts >= 4 then
                local pts, cum = path.pts, cumulative(path.pts)
                local total = cum[#cum] > 0 and cum[#cum] or 1
                local py = stop.y * ASPECT
                for j = 1, #pts - 3, 2 do
                    local ax, ay = pts[j], pts[j + 1] * ASPECT
                    local dx, dy = pts[j + 2] - ax, pts[j + 3] * ASPECT - ay
                    local len2 = dx * dx + dy * dy
                    local f = len2 > 0 and math.max(0, math.min(1, ((stop.x - ax) * dx + (py - ay) * dy) / len2)) or 0
                    local qx, qy = ax + dx * f - stop.x, ay + dy * f - py
                    local d = qx * qx + qy * qy
                    if not bestD or d < bestD then
                        local k = (j + 1) / 2
                        local along = cum[k] + f * (cum[k + 1] - cum[k])
                        bestD = d
                        best = path.t0 + (path.t1 - path.t0) * along / total
                    end
                end
            end
        end
        result[i] = best
    end
    return result
end

-- Pin labels: bosses numbered in route order, R for rares, + for optional ones.
function DR.StopLabels(route)
    local labels, n = {}, 0
    for i, stop in ipairs(route.stops or {}) do
        if stop.kind == "boss" then
            n = n + 1
            labels[i] = tostring(n)
        elseif stop.kind == "rare" then
            labels[i] = "R"
        else
            labels[i] = "+"
        end
    end
    return labels
end

function DR:StopName(stop)
    return DR.Loc(stop, "name") or "?"
end

--------------------------------------------------------------------------------
-- Where the player is
--------------------------------------------------------------------------------

local function instanceID()
    if not (_G.IsInInstance and _G.GetInstanceInfo) then return nil end
    local ok, inside, kind = pcall(_G.IsInInstance)
    if not ok or not inside or (kind ~= "party" and kind ~= "raid" and kind ~= nil) then return nil end
    local okInfo, _, _, _, _, _, _, _, id = pcall(_G.GetInstanceInfo)
    if okInfo and type(id) == "number" then return id end
end
DR.InstanceID = instanceID

-- The room of dungeon `key` named `text` (in the client's language or English).
function DR:RoomNamed(key, text)
    local data = self:Data()
    if type(text) ~= "string" or text == "" or not data then return nil end
    for _, room in ipairs(data.Rooms and data.Rooms[key] or {}) do
        if DR.HasName(room, text) then return room end
    end
end

-- The key of the dungeon (wing) the player is in: the one wing of the
-- instance, else the wing that has the current room, else the last one used.
function DR:CurrentKey()
    local id = instanceID()
    if not id then return nil end
    local list = self:DungeonsFor(id)
    if #list == 0 then return nil end
    if #list == 1 then return list[1].key end
    local text = self.SubZone
    for _, d in ipairs(list) do
        if self:RoomNamed(d.key, text) then
            self.LastWing = self.LastWing or {}
            self.LastWing[id] = d.key
            return d.key
        end
    end
    return self.LastWing and self.LastWing[id] or list[1].key
end

function DR:Room()
    local key = self:CurrentKey()
    if key and self.RoomKey == key then return self.CurrentRoom end
end

function DR.RoomMainFloor(room)
    local area, best, bestArea = {}, nil, nil
    for _, box in ipairs(room.boxes or {}) do
        area[box[1]] = (area[box[1]] or 0) + box[4] * box[5]
    end
    for floor, a in pairs(area) do
        if not bestArea or a > bestArea or (a == bestArea and floor < best) then best, bestArea = floor, a end
    end
    return best
end

function DR.RoomCenter(room, floor)
    local su, sv, sum = 0, 0, 0
    for _, box in ipairs(room.boxes or {}) do
        if box[1] == floor then
            local a = box[4] * box[5]
            su, sv, sum = su + box[2] * a, sv + box[3] * a, sum + a
        end
    end
    if sum == 0 then return nil end
    return su / sum, sv / sum
end

-- The game named the place (GetSubZoneText). Returns the room, if any.
function DR:OnSubZone(text)
    self.SubZone = text
    local key = self:IsLoaded() and self:CurrentKey()
    local room = key and self:RoomNamed(key, text) or nil
    if room ~= self.CurrentRoom or key ~= self.RoomKey then
        local wing = key ~= self.RoomKey
        self.CurrentRoom, self.RoomKey = room, key
        if wing then self:RefreshChart() end
        self.RoomVersion = self.RoomVersion + 1
        if Nx.DungeonChart then Nx.DungeonChart.Dirty = true end
        if Nx.DungeonGuide then Nx.DungeonGuide.Dirty = true end
        if room and self.Recorder then self.Recorder:OnRoom(key, room) end
    end
    return room
end

--------------------------------------------------------------------------------
-- Kills and bosses
--------------------------------------------------------------------------------

function DR:StopKilled(stop)
    local DG = Nx.DungeonGuide
    if not DG then return false end
    for _, id in ipairs(stop.encounters or {}) do
        if DG:IsEncounterKilled(id) then return true end
    end
    local name = DR.Loc(stop, "name")
    if name and DG:IsKilled(name) then return true end
    if stop.name and stop.name ~= name and DG:IsKilled(stop.name) then return true end
    return false
end

-- The route's bosses (kind boss) in order, for the guide panel and the chart.
function DR:BossList(key, route)
    route = route or self:ActiveRoute(key)
    local list = {}
    for _, stop in ipairs(route and route.stops or {}) do
        if stop.kind == "boss" then
            list[#list + 1] = { name = DR.Loc(stop, "name") or "?", floor = stop.floor, x = stop.x, y = stop.y,
                killed = self:StopKilled(stop), encounters = stop.encounters, stop = stop }
        end
    end
    return list
end

-- Lines of the route on `floor`: { x1, y1, x2, y2, state, kind }. `killed`
-- tells for each stop index whether it is done. With main paths: each
-- segment is done (before the last boss killed in order), next (up to the
-- next boss alive) or ahead; side paths are "side". Without paths on the
-- floor: straight legs between the stops in route order.
function DR.Legs(route, floor, killed)
    local legs = {}
    local stops = route.stops or {}
    -- the next boss alive in route order
    local nextIdx
    for i, stop in ipairs(stops) do
        if stop.kind == "boss" and not killed[i] then
            nextIdx = i
            break
        end
    end
    local hasPaths = false
    for _, path in ipairs(route.paths or {}) do
        if path.floor == floor and #(path.pts or {}) >= 4 then hasPaths = true break end
    end
    if hasPaths then
        local progress = DR.StopProgress(route)
        local tDone = 0
        for i = 1, #stops do
            if stops[i].kind == "boss" and killed[i] and progress[i] then
                if not nextIdx or i < nextIdx then tDone = math.max(tDone, progress[i]) end
            end
        end
        local tNext = nextIdx and progress[nextIdx] or (nextIdx and tDone) or 1
        if not nextIdx then tDone = 2 end -- all bosses dead: the whole route is done
        for _, path in ipairs(route.paths or {}) do
            local pts = path.pts or {}
            if path.floor == floor and #pts >= 4 then
                local cum = path.kind == "main" and cumulative(pts)
                local total = cum and (cum[#cum] > 0 and cum[#cum] or 1)
                for j = 1, #pts - 3, 2 do
                    local state = "side"
                    if cum then
                        local k = (j + 1) / 2
                        local mid = path.t0 + (path.t1 - path.t0) * ((cum[k] + cum[k + 1]) / 2) / total
                        if mid <= tDone then
                            state = "done"
                        elseif mid <= tNext then
                            state = "next"
                        else
                            state = "ahead"
                        end
                    end
                    legs[#legs + 1] = { x1 = pts[j], y1 = pts[j + 1], x2 = pts[j + 2], y2 = pts[j + 3],
                        state = state, kind = path.kind }
                end
            end
        end
        return legs
    end
    local last
    for i, stop in ipairs(stops) do
        if stop.floor == floor and stop.kind == "boss" then
            if last then
                local state = "ahead"
                if killed[i] or (nextIdx and i < nextIdx) or not nextIdx then
                    state = "done"
                elseif i == nextIdx then
                    state = "next"
                end
                legs[#legs + 1] = { x1 = stops[last].x, y1 = stops[last].y, x2 = stop.x, y2 = stop.y,
                    state = state, kind = "main" }
            end
            last = i
        end
    end
    return legs
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

function DR:OnEnterWorld()
    if instanceID() then
        self:Load()
    end
    self.CurrentRoom, self.RoomKey = nil, nil
    local text = _G.GetSubZoneText and _G.GetSubZoneText()
    self:OnSubZone(text)
    if self.Recorder then self.Recorder:OnEnter(self:IsLoaded() and self:CurrentKey()) end
end

local events = _G.CreateFrame and _G.CreateFrame("Frame")
if events then
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("ZONE_CHANGED")
    events:RegisterEvent("ZONE_CHANGED_INDOORS")
    events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    events:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
            DR:OnEnterWorld()
        else
            DR:OnSubZone(_G.GetSubZoneText and _G.GetSubZoneText())
        end
    end)
end
