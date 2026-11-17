-- Carbonite.Quests | ObjectiveAreas
-- Groups the spawn points of a quest objective into areas (#65). An objective
-- that lists many spawns of the same mob or object draws one shaded rectangle
-- around each group of nearby spawns instead of one icon per spawn; a spawn
-- with no neighbours stays a point.
--
-- Points are zone percentages (0..100). Carbonite's world y is the zone y
-- divided by 1.5 (Coords:WorldFromZone), so distances and padding count a
-- zone y unit as 1/1.5 of an x unit: groups and margins look even on the map.
--
-- The map renderer draws axis-aligned rectangles only (Area pins), so the
-- envelope of a group is its bounding box plus a margin.
--
--   OA.Cluster(points, maxDist, yScale)  groups of {x=, y=} whose chain of
--                                        neighbours is closer than maxDist
--   OA.Bounds(group, padX, padY)         x1, y1, x2, y2 around the group,
--                                        kept inside 0..100
--   OA.Build(locs)                       { areas = {...}, grouped = {[loc]=true} }
--                                        for a list of "desc|map|32|x|y" strings
--   OA:Get(obj)                          Build(obj), cached per objective table

local Nx = _G.Nx
if not Nx or not Nx.Quest then return end

local OA = {}
Nx.Quest.ObjectiveAreas = OA

local ipairs, pairs, setmetatable, tonumber, type = ipairs, pairs, setmetatable, tonumber, type
local min, max = math.min, math.max

OA.MAX_DIST = 6         -- zone % between neighbouring spawns of one group
OA.MIN_POINTS = 3       -- smaller groups stay as points
OA.PAD = 1.5            -- zone % margin around a group (x; y gets * 1.5)
OA.Y_SCALE = 1 / 1.5    -- zone y unit relative to an x unit

---
-- Single-linkage grouping: two points share a group when a chain of points,
-- each closer than maxDist to the next, joins them.
-- @param points   array of { x = n, y = n }
-- @param maxDist  neighbour distance in zone % (x units)
-- @param yScale   weight of a y unit against an x unit (default 1)
-- @return         array of groups, each an array of the input point tables,
--                 in the order of their first point
function OA.Cluster(points, maxDist, yScale)
    yScale = yScale or 1
    local limit = maxDist * maxDist
    local n = #points
    local groupOf = {}
    local groups = {}
    for i = 1, n do
        if not groupOf[i] then
            local group = { points[i] }
            groupOf[i] = group
            groups[#groups + 1] = group
            local queue, head = { i }, 1
            while queue[head] do
                local a = points[queue[head]]
                head = head + 1
                for j = 1, n do
                    if not groupOf[j] then
                        local b = points[j]
                        local dx = a.x - b.x
                        local dy = (a.y - b.y) * yScale
                        if dx * dx + dy * dy <= limit then
                            groupOf[j] = group
                            group[#group + 1] = b
                            queue[#queue + 1] = j
                        end
                    end
                end
            end
        end
    end
    return groups
end

---
-- Bounding box of a group with a margin, clamped to the zone.
-- @return x1, y1, x2, y2 (x1 <= x2, y1 <= y2), or nil for an empty group
function OA.Bounds(group, padX, padY)
    local p = group and group[1]
    if not p then return end
    padX = padX or 0
    padY = padY or padX
    local x1, y1, x2, y2 = p.x, p.y, p.x, p.y
    for i = 2, #group do
        local q = group[i]
        x1, x2 = min(x1, q.x), max(x2, q.x)
        y1, y2 = min(y1, q.y), max(y2, q.y)
    end
    return max(0, x1 - padX), max(0, y1 - padY),
           min(100, x2 + padX), min(100, y2 + padY)
end

-- "desc|uiMapID|typ|x|y" -> mapID, x, y for a point with real coordinates.
local function ParsePoint(loc)
    if type(loc) ~= "string" then return end
    local m, typ, x, y = loc:match("^[^|]*|([^|]*)|([^|]*)|([^|]*)|([^|]*)")
    m, typ, x, y = tonumber(m), tonumber(typ), tonumber(x), tonumber(y)
    if typ ~= 32 or not m or m == 0 or not x or not y then return end
    return m, x, y
end

---
-- Groups the points of one objective, map by map.
-- @param locs  table of location strings (spans and other entries are ignored)
-- @return      { areas = { { mapID, x1, y1, x2, y2, cx, cy, count }, ... },
--                grouped = { [loc] = true } for every point inside an area }
function OA.Build(locs)
    local byMap, maps = {}, {}
    for _, loc in pairs(locs) do
        local m, x, y = ParsePoint(loc)
        if m then
            local list = byMap[m]
            if not list then
                list = {}
                byMap[m] = list
                maps[#maps + 1] = m
            end
            list[#list + 1] = { x = x, y = y, loc = loc }
        end
    end
    table.sort(maps)

    local areas, grouped = {}, {}
    local padY = OA.PAD / OA.Y_SCALE
    for _, m in ipairs(maps) do
        local groups = OA.Cluster(byMap[m], OA.MAX_DIST, OA.Y_SCALE)
        for _, group in ipairs(groups) do
            if #group >= OA.MIN_POINTS then
                local sx, sy = 0, 0
                for _, p in ipairs(group) do
                    sx, sy = sx + p.x, sy + p.y
                    grouped[p.loc] = true
                end
                local x1, y1, x2, y2 = OA.Bounds(group, OA.PAD, padY)
                areas[#areas + 1] = {
                    mapID = m, x1 = x1, y1 = y1, x2 = x2, y2 = y2,
                    cx = sx / #group, cy = sy / #group, count = #group,
                }
            end
        end
    end
    return { areas = areas, grouped = grouped }
end

-- One result per objective table. The live quest patcher can rewrite an
-- objective's points, so the entry is rebuilt when its count or first and
-- last entries change.
local cache = setmetatable({}, { __mode = "k" })

local function Signature(obj)
    local count, first, last = 0
    for _, loc in pairs(obj) do
        count = count + 1
        first = first or loc
        last = loc
    end
    return count, first, last
end

function OA:Get(obj)
    if type(obj) ~= "table" then return end
    local count, first, last = Signature(obj)
    local entry = cache[obj]
    if entry and entry.count == count and entry.first == first
        and entry.last == last then
        return entry.result
    end
    local result = OA.Build(obj)
    cache[obj] = { count = count, first = first, last = last, result = result }
    return result
end

function OA:ClearCache()
    for k in pairs(cache) do cache[k] = nil end
end
