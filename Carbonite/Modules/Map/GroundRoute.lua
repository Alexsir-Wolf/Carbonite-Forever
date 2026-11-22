-- Carbonite | Modules / Map / GroundRoute
-- Walking legs that go around the terrain (#79).
--
-- The route line and the HUD arrow used to run straight from the player to the
-- target, across mountains, cliffs and deep water. When GatherLite is loaded its
-- terrain data (GatherLiteGroundPathData, from Shortest Path Forever) is in
-- memory; the search engine vendored in Libs/GroundNav walks it and this module
-- turns each walking leg of Nx.Map.Tracking into the found path.
--
--   GroundRoute:Available()            terrain search usable right now
--   GroundRoute:Expand(map, tracking)  replace walking legs with path steps
--   GroundRoute:Busy()                 anything to release
--   GroundRoute:Clear()                drop paths, searches and decoded terrain
--
-- Without the data, with the option off, in instances or on a taxi, nothing
-- changes: the leg stays a straight line. A search runs at most BUDGET_MS per
-- frame, one at a time; until it finishes the straight line is drawn.
--
-- With Shortest Path Forever loaded (API version 2 with WalkPath), each leg
-- asks SPF first (#222): its walking map is updated with every SPF version and
-- knows tunnels and city levels. A leg SPF cannot answer falls back to the
-- GroundNav search above; paths are dropped when SPF's NavVersion changes.

local Carbonite = _G.Carbonite
local _, addon = ...

local GroundRoute = {}
Carbonite.Modules.Map.GroundRoute = GroundRoute

local YARDS = 4.575          -- Carbonite world unit -> yards (as Nx.Map:DrawTracking)
local MIN_LEG_YD = 110       -- shorter legs keep the straight line (MakePath's own cut)
local OFF_PATH_YD = 40       -- farther than this from the path: search again from here
local PASSED_YD = 10         -- path corners this close to the player are behind him
local CACHE_MAX = 8
local FAIL_RETRY = 30        -- seconds before an unreachable leg is tried again
local BUDGET_MS = 2          -- search time per frame (the engine's own budget)

local sqrt, huge = math.sqrt, math.huge

local cache = {}             -- key -> { points, failed, at, used }
local queue = {}             -- keys wanted by the last Expand, in order
local specs = {}             -- key -> search spec for queued keys
local job                    -- running search: { key, co, spec, scratch, mapRect }
local pumpFrame
local warned

local function now()
    return (GetTime and GetTime()) or os.clock()
end

local function ns()
    return addon and addon.GroundNavigation
end

-- Shortest Path Forever's API when it can walk a leg (#222).
local SPF_OWNER = "Carbonite"
local function spfWalk()
    local spf = rawget(_G, "ShortestPathForever")
    local api = type(spf) == "table" and spf.API or nil
    if type(api) ~= "table" or tonumber(api.version) ~= 2 then
        return nil
    end
    return type(api.WalkPath) == "function" and api or nil
end
GroundRoute.SPFWalk = spfWalk

local function debugLog(fmt, ...)
    local logger = Carbonite.Core.Logger and Carbonite.Core.Logger:Get("GroundRoute")
    if logger then
        pcall(logger.debug, logger, fmt, ...)
    end
end

-------------------------------------------------------------------------------
-- Availability
-------------------------------------------------------------------------------

local function optionOn()
    local db = _G.Nx and _G.Nx.db and _G.Nx.db.profile
    return not (db and db.Map and db.Map.RouteGround == false)
end

-- The terrain data, checked once per map before the engine reads it. A format
-- the engine does not know turns the feature off until the next /reload.
local checked = {}
function GroundRoute:HasMap(instance)
    if self.disabled or type(instance) ~= "number" then
        return false
    end
    if checked[instance] ~= nil then
        return checked[instance]
    end
    local all = _G.GatherLiteGroundPathData
    local data = type(all) == "table" and all[instance]
    if data == nil then
        checked[instance] = false
        return false
    end
    if type(data) ~= "table" or type(data.packed) ~= "table" then
        self.disabled = "format"
        if not warned then
            warned = true
            debugLog("terrain data of map %s has an unknown format; walking legs stay straight", tostring(instance))
        end
        return false
    end
    checked[instance] = true
    return true
end

-- Engine, client decoding and data present, and the option on.
function GroundRoute:Supported()
    local n = ns()
    if self.disabled or not (n and n.Path and n.PathGrid and n.PathSearch) then
        return false
    end
    local enc = _G.C_EncodingUtil
    if not (enc and enc.DecodeBase64 and enc.DecompressString
        and Enum and Enum.CompressionMethod and Enum.CompressionMethod.Zlib ~= nil) then
        return false
    end
    if not (C_Map and C_Map.GetWorldPosFromMapPos and _G.CreateVector2D) then
        return false
    end
    return type(_G.GatherLiteGroundPathData) == "table"
end

function GroundRoute:Available()
    return optionOn() and (spfWalk() ~= nil or self:Supported())
end

-------------------------------------------------------------------------------
-- Coordinates
--
-- Carbonite world units -> zone percent (Coords) -> the client's world frame,
-- which the terrain uses: UnitPosition's x north / y west, per instance.
-- Each zone's rectangle comes from two C_Map.GetWorldPosFromMapPos calls, as
-- HereBeDragons does; both directions are then plain interpolation.
-------------------------------------------------------------------------------

local rects = {}

local function rectFor(mapId)
    local rect = rects[mapId]
    if rect ~= nil then
        return rect or nil
    end
    rect = false
    local ok, inst, topLeft = pcall(C_Map.GetWorldPosFromMapPos, mapId, _G.CreateVector2D(0, 0))
    local ok2, inst2, mid = pcall(C_Map.GetWorldPosFromMapPos, mapId, _G.CreateVector2D(.5, .5))
    if ok and ok2 and inst and inst == inst2 and topLeft and mid then
        local top, left = topLeft:GetXY()
        local midX, midY = mid:GetXY()
        local bottom, right = top + (midX - top) * 2, left + (midY - left) * 2
        if bottom ~= top and right ~= left then
            rect = { instance = inst, top = top, left = left, bottom = bottom, right = right }
        end
    end
    rects[mapId] = rect
    return rect or nil
end

local function coords()
    return Carbonite.Modules.Map.Coords
end

-- Carbonite world position seen through zone mapId -> instance, terrain x, y.
function GroundRoute:ToTerrain(mapId, wx, wy)
    local rect = mapId and rectFor(mapId)
    local c = coords()
    if not rect or not c then
        return nil
    end
    local zx, zy = c:ZoneFromWorld(mapId, wx, wy)
    local u, v = zx / 100, zy / 100
    return rect.instance,
        rect.top + (rect.bottom - rect.top) * v,
        rect.left + (rect.right - rect.left) * u
end

-- Terrain x, y -> Carbonite world position, through zone mapId.
function GroundRoute:FromTerrain(mapId, x, y)
    local rect = mapId and rectFor(mapId)
    local c = coords()
    if not rect or not c then
        return nil
    end
    local v = (x - rect.top) / (rect.bottom - rect.top)
    local u = (y - rect.left) / (rect.right - rect.left)
    return c:WorldFromZone(mapId, u * 100, v * 100)
end

-------------------------------------------------------------------------------
-- Search scheduling: one coroutine, sliced by the engine's shared deadline.
-------------------------------------------------------------------------------

local function remember(key, entry)
    entry.at, entry.used = now(), now()
    cache[key] = entry
    local count, oldestKey, oldest = 0, nil, huge
    for k, e in pairs(cache) do
        count = count + 1
        if e.used < oldest then
            oldestKey, oldest = k, e.used
        end
    end
    if count > CACHE_MAX and oldestKey then
        cache[oldestKey] = nil
    end
end

-- Engine points (terrain frame) -> Carbonite world points, endpoints dropped.
local function toWorld(points, mapId)
    local out = {}
    for i = 2, #points - 1 do
        local p = points[i]
        local wx, wy = GroundRoute:FromTerrain(mapId, p.x, p.y)
        if not wx then
            return nil
        end
        out[#out + 1] = { X = wx, Y = wy }
    end
    return out
end

local function redraw()
    local map = _G.Nx and _G.Nx.Map and _G.Nx.Map.GetMap and _G.Nx.Map:GetMap(1)
    if map then
        map.UpdateTrackingDelay = 0    -- draw the new path on the next frame
    end
end

local function finish(points)
    local key, spec = job.key, job.spec
    local search = ns().PathSearch
    search.Spare(job.scratch)
    job = nil
    if type(points) == "table" and #points >= 2 then
        local world = toWorld(points, spec.mapId)
        if world then
            remember(key, { points = world, srcX = spec.srcX, srcY = spec.srcY })
            redraw()
            return
        end
    end
    remember(key, { failed = true })
end

-- The GroundNav search for a leg, or nil when the terrain data cannot walk it.
local function terrainSpec(srcMap, sx, sy, dstMap, dx, dy, fromPlayer)
    if not GroundRoute:Supported() then
        return nil
    end
    local inst, fx, fy = GroundRoute:ToTerrain(srcMap, sx, sy)
    local inst2, tx, ty = GroundRoute:ToTerrain(dstMap or srcMap, dx, dy)
    if not inst or inst ~= inst2 or not GroundRoute:HasMap(inst) then
        return nil
    end
    local from = { x = fx, y = fy }
    if fromPlayer and UnitPosition then
        local py, px, pz, pInst = UnitPosition("player")
        if pInst == inst and py and px then
            from = { x = py, y = px, z = (pz and pz ~= 0) and pz or nil }
        end
    end
    return {
        instance = inst, mapId = srcMap, srcX = sx, srcY = sy,
        from = from, to = { x = tx, y = ty },
    }
end

-- The same leg as SPF places: uiMapID and 0-1 fractions.
local function spfSpec(srcMap, sx, sy, dstMap, dx, dy, fromPlayer)
    local c = coords()
    if not c then
        return nil
    end
    local fx, fy = c:ZoneFromWorld(srcMap, sx, sy)
    local tx, ty = c:ZoneFromWorld(dstMap or srcMap, dx, dy)
    if not (fx and fy and tx and ty) then
        return nil
    end
    return {
        spf = true, mapId = srcMap, srcX = sx, srcY = sy,
        from = { map = srcMap, x = fx / 100, y = fy / 100 },
        to = { map = dstMap or srcMap, x = tx / 100, y = ty / 100 },
        leg = { srcMap = srcMap, sx = sx, sy = sy, dstMap = dstMap, dx = dx, dy = dy, fromPlayer = fromPlayer },
    }
end

-- SPF's waypoints -> Carbonite world points, endpoints dropped. Each
-- waypoint names its own map: a walking map can span several zones.
local function spfToWorld(waypoints)
    local c = coords()
    if not c then
        return nil
    end
    local out = {}
    for i = 2, #waypoints - 1 do
        local p = waypoints[i]
        local wx, wy
        if type(p) == "table" and p.map and p.x and p.y then
            wx, wy = c:WorldFromZone(p.map, p.x * 100, p.y * 100)
        end
        if not wx then
            return nil
        end
        out[#out + 1] = { X = wx, Y = wy }
    end
    return out
end

-- SPF had no path for the leg: the GroundNav search takes it, or it fails.
local function fallBack(key, spec)
    local leg = spec.leg
    local terrain = leg and terrainSpec(leg.srcMap, leg.sx, leg.sy, leg.dstMap, leg.dx, leg.dy, leg.fromPlayer)
    if terrain then
        specs[key] = terrain
        table.insert(queue, 1, key)
        return true
    end
    remember(key, { failed = true })
    return false
end

local function finishSPF(path, reason)
    local key, spec = job.key, job.spec
    job = nil
    if type(path) == "table" and type(path.waypoints) == "table" and #path.waypoints >= 2 then
        local world = spfToWorld(path.waypoints)
        if world then
            remember(key, {
                points = world, srcX = spec.srcX, srcY = spec.srcY,
                spf = true, navVersion = path.navVersion,
            })
            redraw()
            if pumpFrame then pumpFrame:Show() end    -- the next queued leg
            return
        end
    end
    debugLog("WalkPath gave no path (%s); trying the terrain search", tostring(reason))
    fallBack(key, spec)
    if pumpFrame then pumpFrame:Show() end
end

-- Ask SPF for the leg; false when it refused at once.
local function startSPF(key, spec)
    local api = spfWalk()
    if not api then
        return false
    end
    local token = {}
    local ok, cancel, reason = pcall(api.WalkPath, SPF_OWNER, spec.from, spec.to, function(path, why)
        if job and job.token == token then
            finishSPF(path, why)
        end
    end)
    if not ok or type(cancel) ~= "function" then
        debugLog("WalkPath refused: %s", tostring(ok and reason or cancel))
        return false
    end
    job = { key = key, spec = spec, spf = true, token = token, cancel = cancel }
    return true
end

-- Drop the running search; SPF's request is cancelled so it never calls back.
local function dropJob()
    if job and job.cancel then
        pcall(job.cancel)
    end
    job = nil
end

local function startNext()
    while #queue > 0 do
        local key = table.remove(queue, 1)
        local spec = specs[key]
        if spec and spec.spf and not cache[key] then
            if startSPF(key, spec) then
                return true
            end
            -- Refused at once: fallBack queued the terrain search first (or
            -- marked the leg failed); the loop takes it next.
            fallBack(key, spec)
            spec = nil
        end
        if spec and not cache[key] then
            local n = ns()
            job = {
                key = key,
                spec = spec,
                co = coroutine.create(n.PathSearch.start),
                args = { map = spec.instance, from = spec.from, to = spec.to, waterWalking = false },
            }
            return true
        end
    end
    return false
end

local function pump()
    if not job and not startNext() then
        pumpFrame:Hide()
        return
    end
    if job.spf then
        pumpFrame:Hide()      -- SPF calls back; finishSPF shows the frame again
        return
    end
    local n = ns()
    local grid, search = n.PathGrid, n.PathSearch
    grid.Deadline(grid.clock() + BUDGET_MS)
    local previous = search.scratch(job.scratch)
    local ok, points = coroutine.resume(job.co, job.args)
    job.scratch = search.scratch(previous)
    grid.Deadline(huge)
    if not ok then
        debugLog("search failed: %s", tostring(points))
        local key = job.key
        job = nil
        remember(key, { failed = true })
    elseif coroutine.status(job.co) == "dead" then
        finish(points)
    end
end

local wanted = {}             -- keys asked for by the current Expand pass

local function request(key, spec)
    wanted[key] = true
    specs[key] = spec
    if job and job.key == key then
        return
    end
    for _, k in ipairs(queue) do
        if k == key then
            return
        end
    end
    queue[#queue + 1] = key
    if not pumpFrame then
        pumpFrame = CreateFrame("Frame")
        pumpFrame:SetScript("OnUpdate", pump)
    end
    pumpFrame:Show()
end

-------------------------------------------------------------------------------
-- Legs
-------------------------------------------------------------------------------

local function distYd(ax, ay, bx, by)
    local dx, dy = ax - bx, ay - by
    return sqrt(dx * dx + dy * dy) * YARDS
end

-- Distance (yd) from p to segment a-b, and the segment's parameter.
local function segDistYd(px, py, ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    local len2 = dx * dx + dy * dy
    local t = len2 > 0 and ((px - ax) * dx + (py - ay) * dy) / len2 or 0
    t = t < 0 and 0 or (t > 1 and 1 or t)
    return distYd(px, py, ax + dx * t, ay + dy * t), t
end

-- The cached player leg seen from where the player is now: the corners still
-- ahead, or nil when the player left the path.
function GroundRoute:Remaining(points, srcX, srcY, px, py, dstX, dstY)
    local line = { { X = srcX, Y = srcY } }
    for _, p in ipairs(points) do
        line[#line + 1] = p
    end
    line[#line + 1] = { X = dstX, Y = dstY }

    local best, bestI = huge, 1
    for i = 1, #line - 1 do
        local d = segDistYd(px, py, line[i].X, line[i].Y, line[i + 1].X, line[i + 1].Y)
        if d < best then
            best, bestI = d, i
        end
    end
    if best > OFF_PATH_YD then
        return nil
    end
    local out = {}
    for i = bestI + 1, #line - 1 do
        local p = line[i]
        if #out > 0 or distYd(px, py, p.X, p.Y) > PASSED_YD then
            out[#out + 1] = p
        end
    end
    return out
end

local function legKey(fromPlayer, sx, sy, dx, dy)
    local dst = format("%.1f:%.1f", dx, dy)
    if fromPlayer then
        return "P>" .. dst
    end
    return format("%.1f:%.1f>", sx, sy) .. dst
end

-- The world points to walk through between src and dst, or nil for a straight
-- line (no path yet, unreachable, or not a terrain leg). Each end is converted
-- through its own zone; the steps come back through the source zone.
function GroundRoute:Leg(srcMap, sx, sy, dstMap, dx, dy, fromPlayer)
    if distYd(sx, sy, dx, dy) < MIN_LEG_YD then
        return nil
    end
    local key = legKey(fromPlayer, sx, sy, dx, dy)
    local entry = cache[key]
    local api = spfWalk()
    -- A path from older SPF walking data is searched again.
    if entry and entry.spf and api and type(api.NavVersion) == "function"
        and entry.navVersion ~= api.NavVersion() then
        cache[key] = nil
        entry = nil
    end
    if entry then
        entry.used = now()
        if entry.failed then
            if now() - entry.at < FAIL_RETRY then
                return nil
            end
            cache[key] = nil
        elseif fromPlayer then
            local rest = self:Remaining(entry.points, entry.srcX, entry.srcY, sx, sy, dx, dy)
            if rest then
                return rest
            end
            cache[key] = nil      -- left the path: search again from here
        else
            return entry.points
        end
    end

    local spec = (api and spfSpec(srcMap, sx, sy, dstMap, dx, dy, fromPlayer))
        or terrainSpec(srcMap, sx, sy, dstMap, dx, dy, fromPlayer)
    if spec then
        request(key, spec)
    end
    return nil
end

-- A walking leg: not a flight, not a hearthstone or teleport ("T", #37), not a
-- boat or portal hop (those change instance and HasMap/ToTerrain reject them),
-- and not a step this module added.
local function walking(entry)
    return entry.Mode ~= "F" and entry.Mode ~= "T" and not entry.GroundStep
end

---
-- Replace walking legs of map.Tracking with the path steps found so far.
-- Steps are entries with GroundStep = true and no destination icon; they keep
-- the leg's target name and type so the HUD still names the real target.
--
function GroundRoute:Expand(map, tracking)
    local inInstance = IsInInstance and IsInInstance()
    if #tracking == 0 or not self:Available() or inInstance
        or (UnitOnTaxi and UnitOnTaxi("player")) then
        return tracking
    end

    wipe(queue)
    wipe(wanted)
    local mapId = map:GetDisplayableMapForPlayer()
    local srcX, srcY = map.PlyrX, map.PlyrY
    local out = {}
    for n, entry in ipairs(tracking) do
        if walking(entry) and mapId and srcX then
            local steps = self:Leg(mapId, srcX, srcY, entry.MapId or mapId,
                entry.TargetMX, entry.TargetMY, n == 1)
            for _, p in ipairs(steps or {}) do
                out[#out + 1] = {
                    GroundStep = true,
                    Mode = entry.Mode,
                    TargetType = entry.TargetType,
                    TargetName = entry.TargetName,
                    TargetMX = p.X, TargetMY = p.Y,
                    TargetX1 = p.X, TargetY1 = p.Y, TargetX2 = p.X, TargetY2 = p.Y,
                }
            end
        end
        out[#out + 1] = entry
        srcX, srcY = entry.TargetMX, entry.TargetMY
        mapId = entry.MapId or mapId
    end

    -- A search nobody asks for any more (target changed) is dropped.
    if job and not wanted[job.key] then
        dropJob()
    end
    for key in pairs(specs) do
        if not wanted[key] then
            specs[key] = nil
        end
    end
    return out
end

-- Something to release: a path, a search or a queued leg.
function GroundRoute:Busy()
    return job ~= nil or #queue > 0 or next(cache) ~= nil
end

---
-- Targets cleared: drop paths, pending searches and the decoded terrain.
--
function GroundRoute:Clear()
    wipe(cache)
    wipe(queue)
    wipe(specs)
    wipe(wanted)
    dropJob()
    if pumpFrame then
        pumpFrame:Hide()
    end
    local n = ns()
    if n and n.PathGrid and n.PathSearch then
        pcall(function()
            n.PathGrid.Deadline(huge)
            n.PathGrid.Reset()
            n.PathSearch.Spare(nil)
            n.PathSearch.scratch()
        end)
    end
end

-- Tests
GroundRoute._cache = cache
GroundRoute._queue = queue
function GroundRoute._job() return job end
function GroundRoute._pump() return pumpFrame and pump() end

return GroundRoute
