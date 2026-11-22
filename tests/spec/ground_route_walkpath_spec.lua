-- Trecho a pé pelo WalkPath do Shortest Path Forever, com o GroundNav de reserva (#222)
-- Carbonite/Modules/Map/GroundRoute.lua

local function vector(x, y)
    return { x = x, y = y, GetXY = function(self) return self.x, self.y end }
end

-- Zone 1429 seen by the client: terrain x = 1000 - 2000 v, y = 500 - 3000 u.
local function fakeCMap()
    return {
        GetWorldPosFromMapPos = function(mapId, pos)
            if mapId ~= 1429 then return nil end
            return 0, vector(1000 - 2000 * pos.y, 500 - 3000 * pos.x)
        end,
    }
end

-- Carbonite world == zone percent, to keep the arithmetic readable.
local coords = {
    ZoneFromWorld = function(_, _, wx, wy) return wx, wy end,
    WorldFromZone = function(_, _, x, y) return x, y end,
}

-- GroundNav: a search that takes two frames and bends through one corner.
local function fakeEngine(searches)
    return {
        Path = {},
        PathGrid = { clock = function() return 0 end, Deadline = function() end, Reset = function() end },
        PathSearch = {
            start = function(job)
                searches[#searches + 1] = job
                coroutine.yield()
                local mid = { x = (job.from.x + job.to.x) / 2 + 200, y = (job.from.y + job.to.y) / 2 }
                return { job.from, mid, job.to }, 42
            end,
            scratch = function() return {} end,
            Spare = function() end,
        },
    }
end

-- SPF's WalkPath: keeps the request so the test answers it.
local function fakeSPF(opts)
    local spf = { requests = {}, cancelled = 0, nav = opts.navVersion or "nav-1" }
    spf.API = {
        version = 2,
        NavVersion = function() return spf.nav end,
        WalkPath = function(owner, from, to, cb)
            if opts.refuse then return nil, opts.refuse end
            local req = { owner = owner, from = from, to = to, cb = cb }
            spf.requests[#spf.requests + 1] = req
            return function() spf.cancelled = spf.cancelled + 1; req.cancelled = true end
        end,
    }
    return spf
end

local function setup(opts)
    opts = opts or {}
    local searches = {}
    local spf = fakeSPF(opts)
    local env = wow.env({
        C_Map = fakeCMap(),
        CreateVector2D = vector,
        C_EncodingUtil = { DecodeBase64 = function() end, DecompressString = function() end },
        GatherLiteGroundPathData = (opts.data == nil) and { [0] = { packed = {} } } or (opts.data or nil),
        IsInInstance = function() return false end,
        UnitOnTaxi = function() return false end,
        GetTime = function() return 100 end,
        ShortestPathForever = spf,
    })
    env.Enum.CompressionMethod = { Zlib = 0 }
    env.coroutine = coroutine
    env.Carbonite.Modules.Map.Coords = coords
    local map = {
        PlyrX = 10, PlyrY = 10, UpdateTrackingDelay = 45,
        GetDisplayableMapForPlayer = function() return 1429 end,
    }
    env.Nx = { db = { profile = { Map = {} } }, Map = { GetMap = function() return map end } }
    loader.run(env, "Carbonite/Modules/Map/GroundRoute.lua", "Carbonite",
        { GroundNavigation = fakeEngine(searches) })
    return env.Carbonite.Modules.Map.GroundRoute, map, spf, searches
end

local function target(x, y)
    return { TargetMX = x, TargetMY = y, TargetName = "Thelsamar", TargetType = "Goto", MapId = 1429 }
end

describe("GroundRoute com o Shortest Path Forever", function()
    it("pede o caminho ao SPF em frações do mapa e usa as curvas dele", function()
        local ground, map, spf, searches = setup()
        local dest = target(60, 10)
        local first = ground:Expand(map, { dest })
        expect(#first).toBe(1)                          -- straight while SPF works
        ground._pump()
        local req = spf.requests[1]
        expect(req.owner).toBe("Carbonite")
        expect(req.from.map).toBe(1429)
        expect(math.abs(req.from.x - 0.1) < 1e-9).toBe(true)
        expect(math.abs(req.to.x - 0.6) < 1e-9).toBe(true)

        req.cb({ waypoints = {
            { map = 1429, x = 0.1, y = 0.1 },
            { map = 1429, x = 0.35, y = 0.02 },
            { map = 1429, x = 0.6, y = 0.1 },
        }, yards = 300, navVersion = "nav-1" })
        expect(map.UpdateTrackingDelay).toBe(0)
        expect(#searches).toBe(0)                       -- no GroundNav search

        local out = ground:Expand(map, { dest })
        expect(#out).toBe(2)
        expect(out[1].GroundStep).toBe(true)
        expect(math.abs(out[1].TargetMX - 35) < 1e-9).toBe(true)
        expect(math.abs(out[1].TargetMY - 2) < 1e-9).toBe(true)
        expect(out[2]).toBe(dest)
    end)

    it("sem caminho no SPF, a busca do GroundNav assume a perna", function()
        local ground, map, spf, searches = setup()
        local dest = target(60, 10)
        ground:Expand(map, { dest })
        ground._pump()
        spf.requests[1].cb(nil, "offmesh")
        ground._pump(); ground._pump()
        expect(#searches).toBe(1)
        expect(#ground:Expand(map, { dest })).toBe(2)
    end)

    it("SPF recusa na hora (sem dados do mapa): vai direto ao GroundNav", function()
        local ground, map, spf, searches = setup({ refuse = "nodata" })
        local dest = target(60, 10)
        ground:Expand(map, { dest })
        ground._pump(); ground._pump()
        expect(#spf.requests).toBe(0)
        expect(#searches).toBe(1)
    end)

    it("sem o GatherLite, o SPF sozinho já liga o caminho a pé", function()
        local ground = setup({ data = false })
        expect(ground:Available()).toBe(true)
    end)

    it("SPF sem caminho e sem GatherLite: a perna fica reta", function()
        local ground, map, spf = setup({ data = false })
        local dest = target(60, 10)
        ground:Expand(map, { dest })
        ground._pump()
        spf.requests[1].cb(nil, "unreachable")
        expect(#ground:Expand(map, { dest })).toBe(1)
        expect(#spf.requests).toBe(1)                   -- not asked again at once
    end)

    it("trocar de destino cancela o pedido ao SPF", function()
        local ground, map, spf = setup()
        ground:Expand(map, { target(60, 10) })
        ground._pump()
        ground:Expand(map, { target(10, 60) })
        expect(spf.cancelled).toBe(1)
        expect(ground._job()).toBeNil()
    end)

    it("dados novos do SPF (NavVersion) pedem o caminho de novo", function()
        local ground, map, spf = setup()
        local dest = target(60, 10)
        ground:Expand(map, { dest })
        ground._pump()
        spf.requests[1].cb({ waypoints = {
            { map = 1429, x = 0.1, y = 0.1 }, { map = 1429, x = 0.35, y = 0.02 }, { map = 1429, x = 0.6, y = 0.1 },
        }, navVersion = "nav-1" })
        spf.nav = "nav-2"
        expect(#ground:Expand(map, { dest })).toBe(1)
        ground._pump()
        expect(#spf.requests).toBe(2)
    end)
end)
