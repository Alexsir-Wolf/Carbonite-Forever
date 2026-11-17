-- Carbonite | Modules / Map / Transports
-- Ships, zeppelins and the Deeprun Tram moving on the Carbonite map, and the
-- departure time on the tooltip of their piers (#78).
--
-- A vessel runs a fixed loop of `rtt` seconds along a recorded path
-- (Nx.TransportRoutes, Carbonite/Data/camelot/Transports.lua). Its schedule is
-- the phase `p`: the server time, modulo rtt, at which the loop was at 0. With
-- it, the vessel is at (now - p) % rtt seconds into the path. Phases come from
--   * the player: riding a vessel past one of its "trig" points times it;
--   * MapUtils, when installed: the phases it keeps, its own and those other
--     players sent it (Carbonite does not talk to other players for this).
-- With no phase known the vessel is not drawn and its pier keeps the plain
-- tooltip: no time is ever guessed.
--
-- Logic: MapUtils by D4KiR (transports.lua), GPL-3.0 like Carbonite.
--
-- Pure functions (no client API, tested in tests/spec/transports_spec.lua):
--   Transports.Decode(route)                    - path as absolute points
--   Transports.Cycle(route, known, now)         - seconds into the loop
--   Transports.Position(route, cycle)           - instance, world x, y, zoning
--   Transports.PlatformTimes(route, cycle)      - wait / stay per platform
--   Transports.FormatTime(seconds)              - "M:SS"
--   Transports.StatusText(entry, name)          - pier tooltip line
--   Transports.MatchPlatforms(list, i, x, y)    - platforms next to a pier
--   Transports.TriggerCycle(route, i, x, y, dx, dy, moved) - timing a ride
--   Transports.PhaseOf(route, cycle, now)       - phase from a timed point
--   Transports.ZonePercent(rect, x, y)          - world yards to zone percent
--   Transports.PickRect(rects, i, x, y)         - best zone for a point

local Carbonite = _G.Carbonite
local L = LibStub("AceLocale-3.0"):GetLocale("Carbonite")

local Transports = {}
Carbonite.Modules.Map.Transports = Transports

-- World rectangles that turn the packed x, y of routes with coords = -1
-- (0..1 over both continents) into world yards of instance 0 or 1.
Transports.RECTS = {
    [0] = { 44688.53, 29795.11, 32601.04, 9894.93 },
    [1] = { 44878.66, 29916.10, 8723.96, 14824.53 },
}

-- The tram runs in its own instance; on the map it goes between these two
-- surface points (uiMapID, x, y in zone percent): the Forever track ends.
Transports.TRAM_PLATFORMS = {
    [1] = { 1453, 72.06, 28.15 },
    [2] = { 1455, 84.5, 53.2 },
}

Transports.ICONS = {
    ship = "Interface\\AddOns\\Carbonite\\Gfx\\Map\\Transports\\vessel_ship",
    zeppelin = "Interface\\AddOns\\Carbonite\\Gfx\\Map\\Transports\\vessel_zeppelin",
    tram = "Interface\\AddOns\\Carbonite\\Gfx\\Map\\Transports\\vessel_tram",
}

Transports.ICON_TYPE = "!TRN"
Transports.ICON_SIZE = 20
Transports.MAX_AGE = 30 * 86400     -- a phase older than this is dropped
Transports.DOCK_RADIUS = 150        -- yards from a pier to a platform
Transports.DOCK_TOLERANCE = 15      -- platforms this close to the best one also count
Transports.PIN_INTERVAL = .25       -- seconds between vessel moves on the map
Transports.TIP_INTERVAL = 1         -- seconds between pier tooltip refreshes
Transports.TRIGGER_INTERVAL = .8    -- seconds between ride checks
Transports.TRIGGER_RADIUS = 20
Transports.MIN_MOVE = 6.16          -- yards per check: slower is not a vessel
Transports.COMMIT_MOVE = 17
Transports.MAX_MOVE = 80            -- faster is a teleport or a flight
Transports.TRIGGER_COOLDOWN = 30

-------------------------------------------------------------------------------
-- Path
-------------------------------------------------------------------------------

local decoded = setmetatable({}, { __mode = "k" })

local function fields(packed)
    local out = {}
    for field in (packed .. ":"):gmatch("([^:]*):") do
        out[#out + 1] = field
    end
    return out
end

--- The packed deltas of a route as absolute points (cached per route table):
--- x, y, offset (seconds from the loop start to the end of point i), the
--- deltas, plat[n] = point docked at platform n, trig = list of points where
--- a ride is timed, jump / zoning / rawp sets.
function Transports.Decode(route)
    local d = decoded[route]
    if d then return d end
    d = {
        x = {}, y = {}, dx = {}, dy = {}, dt = {},
        offset = { [0] = 0 },
        plat = {}, trig = {}, zoning = {}, jump = {}, rawp = {},
    }
    local x, y, t = 0, 0, 0
    for i, packed in ipairs(route.points or {}) do
        local f = fields(packed)
        local dx, dy, dt = tonumber(f[1]) or 0, tonumber(f[2]) or 0, tonumber(f[3]) or 0
        x, y, t = x + dx, y + dy, t + dt
        d.x[i], d.y[i], d.offset[i] = x, y, t
        d.dx[i], d.dy[i], d.dt[i] = dx, dy, dt
        for k = 6, #f do
            local kind, number = f[k]:sub(1, 4), tonumber(f[k]:sub(5))
            if kind == "plat" and number then
                d.plat[number] = i
            elseif kind == "trig" and number ~= 0 then
                d.trig[#d.trig + 1] = i
            elseif kind == "zone" then
                d.zoning[i] = true
            elseif kind == "jump" then
                d.jump[i] = true
            elseif kind == "rawp" then
                d.rawp[i] = true
            end
        end
    end
    d.count = #(route.points or {})
    -- The recorded times do not add up to the period exactly: the last point
    -- ends the loop.
    d.offset[d.count] = route.rtt
    decoded[route] = d
    return d
end

--- First point whose offset is past `cycle` (the segment the vessel is on).
function Transports.FindIndex(d, cycle)
    local lo, hi = 1, d.count
    if hi < 1 then return 1 end
    if d.offset[hi] <= cycle then return hi end
    while lo < hi do
        local mid = floor((lo + hi) / 2)
        if d.offset[mid] > cycle then hi = mid else lo = mid + 1 end
    end
    return lo
end

--- Seconds into the loop at `now`, or nil without a phase.
function Transports.Cycle(route, known, now)
    if not route or not known or type(known.p) ~= "number" or not now then return nil end
    return (now - known.p) % route.rtt
end

--- Phase that puts the vessel `cycle` seconds into its loop at `now`.
function Transports.PhaseOf(route, cycle, now)
    return (now - cycle) % route.rtt
end

--- Point (x, y in route units) to instance and world yards.
function Transports.ToWorld(route, d, index, x, y)
    if d.rawp[index] then return route.raw, x, y end
    if (route.coords or -1) >= 0 then return route.coords, x, y end
    local instance = x < .5 and 1 or 0
    local rect = Transports.RECTS[instance]
    return instance, rect[3] - rect[1] * x, rect[4] - rect[2] * y
end

--- Where the vessel is `cycle` seconds into its loop: instance, world x, y and
--- whether it is zoning. Nil while it jumps (teleports between instances).
function Transports.Position(route, cycle)
    local d = Transports.Decode(route)
    if not cycle or d.count < 1 then return nil end
    local index = Transports.FindIndex(d, cycle)
    if d.jump[index] then return nil end
    local x, y, zoning = d.x[index], d.y[index], false
    if index > 1 then
        local f = 1
        if d.dt[index] > 0 then
            f = min(1, max(0, (cycle - d.offset[index - 1]) / d.dt[index]))
        end
        x = d.x[index - 1] + d.dx[index] * f
        y = d.y[index - 1] + d.dy[index] * f
        zoning = d.zoning[index] == true
    end
    local instance, wx, wy = Transports.ToWorld(route, d, index, x, y)
    return instance, wx, wy, zoning
end

--- Tram position as a fraction (0 at platform 1, 1 at platform 2) of the
--- way between its platforms, from the route x of Position.
function Transports.TramFraction(route, x)
    local d = Transports.Decode(route)
    local p1, p2 = d.plat[1], d.plat[2]
    if not p1 or not p2 or not x then return nil end
    local x1, x2 = d.x[p1], d.x[p2]
    if x1 == x2 then return nil end
    return min(1, max(0, (x - x1) / (x2 - x1)))
end

--- Per platform, sorted by number: { number, name, docked, wait, stay }.
--- Docked: the vessel is there and leaves in `wait` seconds. Otherwise it
--- arrives in `wait` seconds and stays `stay` seconds.
function Transports.PlatformTimes(route, cycle)
    local d = Transports.Decode(route)
    if not cycle or d.count < 1 then return nil end
    local index = Transports.FindIndex(d, cycle)
    local list = {}
    for number, point in pairs(d.plat) do
        local docked = point == index
        local wait = (docked and d.offset[point] or d.offset[point - 1]) - cycle
        if wait < 0 then wait = wait + route.rtt end
        list[#list + 1] = {
            number = number,
            name = route.platforms and route.platforms[number],
            docked = docked,
            wait = wait,
            stay = d.offset[point] - d.offset[point - 1],
        }
    end
    table.sort(list, function(a, b) return a.number < b.number end)
    return list
end

function Transports.FormatTime(seconds)
    seconds = max(0, floor(seconds))
    return format("%d:%02d", floor(seconds / 60), seconds % 60)
end

--- One tooltip line: "Name: Departs in 0:42" (yellow, red in the last 30
--- seconds) or "Name: Arrives in 1:20, departs in 2:20" (green).
function Transports.StatusText(entry, name)
    local prefix = name and name ~= "" and (name .. ": ") or ""
    local FormatTime = Transports.FormatTime
    if entry.docked then
        local color = entry.wait <= 30 and "ff4040" or "ffd100"
        return format("|cff%s%s%s|r", color, prefix, format(L["Departs in %s"], FormatTime(entry.wait)))
    end
    return format("|cff4cff4c%s%s|r", prefix,
        format(L["Arrives in %s, departs in %s"], FormatTime(entry.wait), FormatTime(entry.wait + entry.stay)))
end

--- Platforms next to a pier at world (instance, x, y). `list` holds
--- { id, number, instance, x, y }. The nearest within DOCK_RADIUS counts, and
--- any other no more than DOCK_TOLERANCE farther (a pier served by two lines).
function Transports.MatchPlatforms(list, instance, x, y)
    local near, best = {}, nil
    for _, p in ipairs(list) do
        if p.instance == instance then
            local dist = math.sqrt((p.x - x) ^ 2 + (p.y - y) ^ 2)
            if dist < Transports.DOCK_RADIUS then
                near[#near + 1] = { id = p.id, number = p.number, dist = dist }
                if not best or dist < best then best = dist end
            end
        end
    end
    local out = {}
    for _, c in ipairs(near) do
        if c.dist <= best + Transports.DOCK_TOLERANCE then out[#out + 1] = c end
    end
    table.sort(out, function(a, b)
        if a.id ~= b.id then return a.id < b.id end
        return a.number < b.number
    end)
    return out
end

local function directionMatches(route, dx, dy, sx, sy)
    local direction = route.direction
    if not direction then return true end
    if direction.x and dx * sx <= 0 then return false end
    if direction.y and dy * sy <= 0 then return false end
    return true
end

--- A player at world (instance, x, y) who moved (dx, dy), `moved` yards since
--- the last check: next to a trig point of `route`, going its way. Returns
--- true when near one, and the loop time it means when the move is fast
--- enough to be the vessel (not the player walking on deck).
function Transports.TriggerCycle(route, instance, x, y, dx, dy, moved)
    local d = Transports.Decode(route)
    for _, index in ipairs(d.trig) do
        if index > 1 then
            local ti, tx, ty = Transports.ToWorld(route, d, index, d.x[index], d.y[index])
            local pi, px, py = Transports.ToWorld(route, d, index - 1, d.x[index - 1], d.y[index - 1])
            if ti == instance and pi == instance
                and math.sqrt((x - tx) ^ 2 + (y - ty) ^ 2) < Transports.TRIGGER_RADIUS
                and directionMatches(route, dx, dy, tx - px, ty - py) then
                if moved <= Transports.COMMIT_MOVE then return true, nil end
                local segment = math.sqrt((tx - px) ^ 2 + (ty - py) ^ 2)
                if segment <= 0 then return true, nil end
                local along = math.sqrt((x - px) ^ 2 + (y - py) ^ 2) / segment
                return true, d.offset[index] - d.dt[index] + d.dt[index] * along
            end
        end
    end
    return false, nil
end

--- Zone percent of world yards in a map rectangle { x0, xs, y0, ys }
--- (x0 + xs spans the zone left to right, y0 + ys top to bottom).
function Transports.ZonePercent(rect, x, y)
    return (x - rect.x0) / rect.xs * 100, (y - rect.y0) / rect.ys * 100
end

--- Zone of `rects` ({ mapId, rect } with rect.instance) to place a world
--- point in: the one that holds it, or else the one it is least outside of,
--- so that open sea between zones still lands on the map. Returns mapId, x, y
--- in zone percent (may be outside 0..100).
function Transports.PickRect(rects, instance, x, y)
    local bestId, bestX, bestY, bestOut
    for _, r in ipairs(rects) do
        if r.rect.instance == instance then
            local px, py = Transports.ZonePercent(r.rect, x, y)
            local out = max(abs(px - 50), abs(py - 50))
            if not bestOut or out < bestOut then
                bestId, bestX, bestY, bestOut = r.mapId, px, py, out
            end
        end
    end
    return bestId, bestX, bestY
end

--- A stored phase usable at `now`: { p, t } numbers, seen within MAX_AGE.
function Transports.ValidKnown(known, now)
    return type(known) == "table" and type(known.p) == "number" and type(known.t) == "number"
        and now - known.t <= Transports.MAX_AGE and known.t <= now + 60
end

-------------------------------------------------------------------------------
-- Client side
-------------------------------------------------------------------------------

function Transports:Routes()
    local Nx = _G.Nx
    return Nx and Nx.TransportRoutes or {}
end

function Transports:Enabled()
    local Nx = _G.Nx
    local map = Nx and Nx.db and Nx.db.profile and Nx.db.profile.Map
    return map ~= nil and map.ShowTransports ~= false
end

-- Server time with sub-second steps: GetServerTime ticks once a second, so
-- the offset to GetTime is taken on the frame the second changes.
function Transports:Now()
    if self.clockOffset then return GetTime() + self.clockOffset end
    local serverTime = _G.GetServerTime
    return serverTime and serverTime() or GetTime()
end

function Transports:CalibrateClock()
    local serverTime = _G.GetServerTime
    if not serverTime then return end
    local frame = CreateFrame("Frame")
    local last = serverTime()
    frame:SetScript("OnUpdate", function(f)
        local now = serverTime()
        if now ~= last then
            Transports.clockOffset = now - GetTime()
            f:SetScript("OnUpdate", nil)
        end
    end)
end

-- Phases the player timed, account-wide.
function Transports:Store()
    local Nx = _G.Nx
    local global = Nx and Nx.db and Nx.db.global
    if not global then return nil end
    global.Transports = global.Transports or {}
    return global.Transports
end

-- Phases MapUtils keeps (its own and other players'), when it is installed.
local function mapUtilsStore()
    local saved = _G.MAUTTAB
    local sync = type(saved) == "table" and type(saved.TRANSPORTSYNC) == "table" and saved.TRANSPORTSYNC
    local store = sync and sync.forever
    return type(store) == "table" and store or nil
end

--- Freshest usable phase of route `id`, from the player or from MapUtils.
function Transports:Known(id)
    local now = self:Now()
    local best
    local own, other = self:Store(), mapUtilsStore()
    for _, store in ipairs({ own or {}, other or {} }) do
        local k = store[id]
        if Transports.ValidKnown(k, now) and (not best or k.t > best.t) then best = k end
    end
    return best
end

function Transports:Observe(id, cycle)
    local route, store = self:Routes()[id], self:Store()
    if not route or not store then return end
    local now = self:Now()
    store[id] = { p = Transports.PhaseOf(route, cycle, now), t = now, s = "self" }
end

function Transports:VesselName(route)
    if route.vessel == "Unnamed Vessel" or not route.vessel then
        return route.kind == "zeppelin" and L["Zeppelin"] or route.kind == "tram" and L["Tram"] or L["Ship"]
    end
    local names = _G.GetLocale and _G.GetLocale() == "ptBR" and _G.Nx and _G.Nx.TransportNamesPtBR
    return names and names[route.vessel] or route.vessel
end

local function shortName(name)
    return (tostring(name or "?"):match("^([^,]+)")) or "?"
end

-- uiMapID -> { x0, xs, y0, ys, instance } in world yards, from the client.
local rectCache = {}
local function mapRect(mapId)
    local cached = rectCache[mapId]
    if cached ~= nil then return cached or nil end
    rectCache[mapId] = false
    local api, vector = _G.C_Map, _G.CreateVector2D
    if not api or not api.GetWorldPosFromMapPos or not vector then return nil end
    local instance, tl = api.GetWorldPosFromMapPos(mapId, vector(0, 0))
    local _, br = api.GetWorldPosFromMapPos(mapId, vector(1, 1))
    if not tl or not br or br.x == tl.x or br.y == tl.y then return nil end
    local rect = { x0 = tl.y, xs = br.y - tl.y, y0 = tl.x, ys = br.x - tl.x, instance = instance }
    rectCache[mapId] = rect
    return rect
end

-- World yards of a zone point: instance, x, y (MapUtils' axes).
local function zoneToYards(mapId, x, y)
    local rect = mapRect(mapId)
    if not rect then return nil end
    return rect.instance, rect.x0 + rect.xs * x / 100, rect.y0 + rect.ys * y / 100
end

-- Zones a route crosses that Carbonite can draw, as PickRect wants them.
local routeRects = setmetatable({}, { __mode = "k" })
local function rectsOf(route)
    local list = routeRects[route]
    if list then return list end
    list = {}
    local info = _G.Nx and _G.Nx.Map and _G.Nx.Map.MapWorldInfo or {}
    local ids = {}
    for mapId in pairs(route.zones or {}) do ids[#ids + 1] = mapId end
    table.sort(ids)
    for _, mapId in ipairs(ids) do
        local rect = info[mapId] and mapRect(mapId)
        if rect then list[#list + 1] = { mapId = mapId, rect = rect } end
    end
    routeRects[route] = list
    return list
end

-- Carbonite world position of a tram platform.
local function tramPlatformMap(number)
    local p = Transports.TRAM_PLATFORMS[number]
    if not p then return nil end
    return _G.Nx.Map:GetWorldPos(p[1], p[2], p[3])
end

--- Carbonite world position of a vessel, or nil (unknown, jumping, off map).
function Transports:VesselMapPos(route, cycle)
    local instance, x, y, zoning = Transports.Position(route, cycle)
    if not instance then return nil end
    local NxMap = _G.Nx.Map
    if route.kind == "tram" then
        local f = Transports.TramFraction(route, x)
        local x1, y1 = tramPlatformMap(1)
        local x2, y2 = tramPlatformMap(2)
        if not f or not x1 or not x2 then return nil end
        return x1 + (x2 - x1) * f, y1 + (y2 - y1) * f, zoning
    end
    local mapId, px, py = Transports.PickRect(rectsOf(route), instance, x, y)
    if not mapId then return nil end
    local wx, wy = NxMap:GetWorldPos(mapId, px, py)
    return wx, wy, zoning
end

function Transports:VesselTip(route, cycle)
    local lines = { "|cffffffff" .. self:VesselName(route) .. "|r" }
    local names = {}
    for n = 1, #(route.platforms or {}) do names[#names + 1] = shortName(route.platforms[n]) end
    if #names > 0 then lines[#lines + 1] = "|cff999999" .. table.concat(names, " - ") .. "|r" end
    for _, entry in ipairs(Transports.PlatformTimes(route, cycle) or {}) do
        lines[#lines + 1] = Transports.StatusText(entry, shortName(entry.name))
    end
    return table.concat(lines, "\n")
end

-- Draws every vessel with a known phase. Each call starts the layer anew:
-- at most a dozen pins, a few times a second.
function Transports:UpdatePins()
    local Nx = _G.Nx
    local map = Nx and Nx.Map and Nx.Map.GetMap and Nx.Map:GetMap(1)
    if not map then return end
    local kind = Transports.ICON_TYPE
    if not self:Enabled() then
        if self.pinsShown then
            map:InitIconType(kind, "WP", "", Transports.ICON_SIZE, Transports.ICON_SIZE)
            self.pinsShown = false
        end
        return
    end
    map:InitIconType(kind, "WP", "", Transports.ICON_SIZE, Transports.ICON_SIZE)
    map:SetIconTypeChop(kind, true)
    map:SetIconTypeLevel(kind, 12)
    self.pinsShown = true
    for id, route in pairs(self:Routes()) do
        local cycle = Transports.Cycle(route, self:Known(id), self:Now())
        local wx, wy = nil, nil
        if cycle then wx, wy = self:VesselMapPos(route, cycle) end
        if wx and wy then
            local pin = map:AddIconPt(kind, wx, wy, nil, nil, Transports.ICONS[route.kind] or Transports.ICONS.ship)
            if pin then map:SetIconTip(pin, self:VesselTip(route, cycle)) end
        end
    end
end

-------------------------------------------------------------------------------
-- Piers: the Guide draws them (NxMapGuide UpdateTravelIcons) and hands each
-- icon over; the tip gets one line per vessel with a known schedule.
-------------------------------------------------------------------------------

Transports.piers = {}

-- Every platform in world yards: { id, number, instance, x, y }.
function Transports:Platforms()
    if self.platformList then return self.platformList end
    local list = {}
    for id, route in pairs(self:Routes()) do
        local d = Transports.Decode(route)
        for number, point in pairs(d.plat) do
            local instance, x, y
            if route.kind == "tram" then
                local p = Transports.TRAM_PLATFORMS[number]
                if p then instance, x, y = zoneToYards(p[1], p[2], p[3]) end
            else
                instance, x, y = Transports.ToWorld(route, d, point, d.x[point], d.y[point])
            end
            if instance then
                list[#list + 1] = { id = id, number = number, instance = instance, x = x, y = y }
            end
        end
    end
    self.platformList = list
    return list
end

function Transports:ResetPiers()
    wipe(self.piers)
end

--- Pier icon drawn by the Guide at (mapId, x, y in zone percent) with tip `tip`.
function Transports:AddPier(icon, mapId, x, y, tip)
    if not icon or not mapId or not x or not y then return end
    local instance, wx, wy = zoneToYards(mapId, x, y)
    if not instance then return end
    local matches = Transports.MatchPlatforms(self:Platforms(), instance, wx, wy)
    if #matches == 0 then return end
    local entry = { icon = icon, base = tip, tip = tip, x = icon.x, y = icon.y, matches = matches }
    self.piers[#self.piers + 1] = entry
    self:UpdatePier(entry)
end

--- Lines for a pier, or nil when no vessel there has a known schedule.
function Transports:PierLines(matches)
    if not self:Enabled() then return nil end
    local lines = {}
    local routes, now = self:Routes(), self:Now()
    for _, m in ipairs(matches) do
        local route = routes[m.id]
        local cycle = route and Transports.Cycle(route, self:Known(m.id), now)
        for _, entry in ipairs(cycle and Transports.PlatformTimes(route, cycle) or {}) do
            if entry.number == m.number then
                lines[#lines + 1] = Transports.StatusText(entry, self:VesselName(route))
            end
        end
    end
    return #lines > 0 and table.concat(lines, "\n") or nil
end

function Transports:UpdatePier(entry)
    local lines = self:PierLines(entry.matches)
    local tip = lines and (entry.base .. "\n" .. lines) or entry.base
    entry.tip = tip
    entry.icon.tip, entry.icon.Tip = tip, tip
end

function Transports:UpdatePierTips()
    local piers = self.piers
    for i = #piers, 1, -1 do
        local e = piers[i]
        local icon = e.icon
        -- The Guide redrew its icons and this pin went to someone else.
        if icon.tip ~= e.tip or icon.x ~= e.x or icon.y ~= e.y then
            table.remove(piers, i)
        else
            self:UpdatePier(e)
        end
    end
end

-------------------------------------------------------------------------------
-- Timing a ride: every TRIGGER_INTERVAL the player's position is compared
-- with the last one; moving at vessel speed next to a trig point of a route
-- that serves the zone gives that route's phase.
-------------------------------------------------------------------------------

function Transports:ZoneIndex()
    if self.zoneIndex then return self.zoneIndex end
    local index = {}
    for id, route in pairs(self:Routes()) do
        for mapId, flag in pairs(route.zones or {}) do
            index[mapId] = index[mapId] or {}
            index[mapId][id] = flag
        end
    end
    self.zoneIndex = index
    return index
end

local function currentZone()
    local api = _G.C_Map
    local mapId = api and api.GetBestMapForUnit and api.GetBestMapForUnit("player")
    if mapId == 1414 or mapId == 1415 then return nil end
    if not mapId or mapId == 0 then mapId = select(8, GetInstanceInfo()) end
    return mapId
end

function Transports:CheckTriggers()
    if not self:Enabled() then
        self.lastPos = nil
        return
    end
    local _, instanceType = GetInstanceInfo()
    local zone = instanceType ~= "party" and instanceType ~= "raid" and currentZone() or nil
    local routes = zone and self:ZoneIndex()[zone]
    if not routes and instanceType == "none" then routes = self:Routes() end
    if not routes then
        self.lastPos = nil
        return
    end
    local unitPosition = _G.UnitPosition
    local u1, u2, _, instance
    if unitPosition then u1, u2, _, instance = unitPosition("player") end
    if not u1 or (_G.issecretvalue and _G.issecretvalue(u1)) then return end
    local last = self.lastPos
    self.lastPos = { u2, u1, instance }
    if not last or last[3] ~= instance then return end
    local x, y = u2, u1
    local dx, dy = x - last[1], y - last[2]
    local moved = math.sqrt(dx * dx + dy * dy)
    if moved <= Transports.MIN_MOVE or moved > Transports.MAX_MOVE then return end
    if (_G.IsSwimming and _G.IsSwimming()) or (_G.UnitOnTaxi and _G.UnitOnTaxi("player")) then return end
    if self.lastTrigger and GetTime() - self.lastTrigger < Transports.TRIGGER_COOLDOWN then return end
    local all = self:Routes()
    for id, flag in pairs(routes) do
        local route = all[id]
        if flag ~= "virtual" and route then
            local near, cycle = Transports.TriggerCycle(route, instance, x, y, dx, dy, moved)
            if near then
                if cycle then
                    self:Observe(id, cycle)
                    self.lastTrigger = GetTime()
                end
                return
            end
        end
    end
end

function Transports:Start()
    if self.started or not next(self:Routes()) then return end
    self.started = true
    self:CalibrateClock()
    local tip = 0
    C_Timer.NewTicker(Transports.PIN_INTERVAL, function()
        Transports:UpdatePins()
        tip = tip + Transports.PIN_INTERVAL
        if tip >= Transports.TIP_INTERVAL then
            tip = 0
            Transports:UpdatePierTips()
        end
    end)
    C_Timer.NewTicker(Transports.TRIGGER_INTERVAL, function() Transports:CheckTriggers() end)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function() Transports:Start() end)
