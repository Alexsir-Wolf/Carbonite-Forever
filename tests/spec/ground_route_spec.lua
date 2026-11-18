-- Walking legs around the terrain (#79): Carbonite/Modules/Map/GroundRoute.lua

-- Zone 1429 seen by the client: terrain x = 1000 - 2000 v, y = 500 - 3000 u.
local function vector(x, y)
    return { x = x, y = y, GetXY = function(self) return self.x, self.y end }
end

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

-- A search that takes two frames and bends through one corner.
local function fakeEngine(searches)
    return {
        Path = {},
        PathGrid = {
            clock = function() return 0 end,
            Deadline = function() end,
            Reset = function() searches.reset = true end,
        },
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

local function setup(opts)
    opts = opts or {}
    local searches = {}
    local env = wow.env({
        C_Map = fakeCMap(),
        CreateVector2D = vector,
        C_EncodingUtil = { DecodeBase64 = function() end, DecompressString = function() end },
        GatherLiteGroundPathData = (opts.data == nil) and { [0] = { packed = {} } } or opts.data,
        IsInInstance = function() return false end,
        UnitOnTaxi = function() return false end,
        GetTime = function() return opts.time or 100 end,
    })
    env.Enum.CompressionMethod = { Zlib = 0 }
    env.coroutine = coroutine
    env.Carbonite.Modules.Map.Coords = coords
    local map = {
        PlyrX = 10, PlyrY = 10, UpdateTrackingDelay = 45,
        GetDisplayableMapForPlayer = function() return 1429 end,
    }
    env.Nx = { db = { profile = { Map = opts.mapOpts or {} } }, Map = { GetMap = function() return map end } }
    loader.run(env, "Carbonite/Modules/Map/GroundRoute.lua", "Carbonite",
        { GroundNavigation = opts.engine or fakeEngine(searches) })
    return env.Carbonite.Modules.Map.GroundRoute, map, searches
end

local function target(x, y)
    return { TargetMX = x, TargetMY = y, TargetName = "Thelsamar", TargetType = "Goto", MapId = 1429 }
end

describe("GroundRoute: coordenadas", function()
    it("converte do Carbonite para o terreno e volta", function()
        local ground = setup()
        local inst, x, y = ground:ToTerrain(1429, 25, 50)
        expect(inst).toBe(0)
        expect(x).toBe(1000 - 2000 * .5)
        expect(y).toBe(500 - 3000 * .25)
        local wx, wy = ground:FromTerrain(1429, x, y)
        expect(math.abs(wx - 25) < 1e-9).toBe(true)
        expect(math.abs(wy - 50) < 1e-9).toBe(true)
    end)

    it("mapa que o cliente não conhece não converte", function()
        local ground = setup()
        expect(ground:ToTerrain(9999, 1, 1)).toBeNil()
    end)
end)

describe("GroundRoute: sem dados ou desligado", function()
    it("sem o GatherLite a lista de rota fica igual", function()
        local ground, map = setup({ data = false })
        local tracking = { target(60, 10) }
        expect(ground:Available()).toBe(false)
        expect(ground:Expand(map, tracking)).toBe(tracking)
    end)

    it("com a opção desligada a lista fica igual", function()
        local ground, map = setup({ mapOpts = { RouteGround = false } })
        local tracking = { target(60, 10) }
        expect(ground:Expand(map, tracking)).toBe(tracking)
    end)

    it("dados num formato desconhecido desligam o recurso", function()
        local ground = setup({ data = { [0] = { graph = {} } } })
        expect(ground:HasMap(0)).toBe(false)
        expect(ground.disabled).toBe("format")
        expect(ground:Supported()).toBe(false)
    end)

    it("perna curta continua reta e não busca nada", function()
        local ground, map, searches = setup()
        local out = ground:Expand(map, { target(15, 10) })
        expect(#out).toBe(1)
        expect(#searches).toBe(0)
    end)

    it("voo e teleporte não viram caminho a pé", function()
        local ground, map, searches = setup()
        for _, mode in ipairs({ "F", "T" }) do
            local leg = target(60, 10)
            leg.Mode = mode
            ground:Expand(map, { leg })
            ground._pump(); ground._pump()
        end
        expect(#searches).toBe(0)
    end)
end)

describe("GroundRoute: busca e passos", function()
    it("reta enquanto busca; depois os cantos do caminho antes do destino", function()
        local ground, map, searches = setup()
        local dest = target(60, 10)

        local first = ground:Expand(map, { dest })
        expect(#first).toBe(1)                    -- still straight
        ground._pump()                            -- first slice: not done
        expect(ground._job() ~= nil).toBe(true)
        ground._pump()                            -- done
        expect(ground._job()).toBeNil()
        expect(#searches).toBe(1)
        expect(map.UpdateTrackingDelay).toBe(0)   -- redraw at once

        local out = ground:Expand(map, { dest })
        expect(#out).toBe(2)
        expect(out[1].GroundStep).toBe(true)
        expect(out[1].TargetName).toBe("Thelsamar")
        expect(out[2]).toBe(dest)
        -- The corner is 200 terrain units north of the middle: v = -0.1 zone.
        expect(math.abs(out[1].TargetMX - 35) < 1e-9).toBe(true)
        expect(math.abs(out[1].TargetMY - 0) < 1e-9).toBe(true)
    end)

    it("fora do caminho por mais de 40 jd busca de novo", function()
        local ground, map, searches = setup()
        local dest = target(60, 10)
        ground:Expand(map, { dest })
        ground._pump(); ground._pump()

        map.PlyrX, map.PlyrY = 30, 40           -- far from the path
        local out = ground:Expand(map, { dest })
        expect(#out).toBe(1)
        expect(#ground._queue + (ground._job() and 1 or 0)).toBe(1)
        ground._pump(); ground._pump()
        expect(#searches).toBe(2)
    end)

    it("trocar de destino cancela a busca anterior", function()
        local ground, map = setup()
        ground:Expand(map, { target(60, 10) })
        ground._pump()
        expect(ground._job() ~= nil).toBe(true)
        ground:Expand(map, { target(10, 60) })
        expect(ground._job()).toBeNil()
    end)

    it("limpar os destinos libera caminhos e o terreno", function()
        local ground, map, searches = setup()
        ground:Expand(map, { target(60, 10) })
        ground._pump(); ground._pump()
        expect(ground:Busy()).toBe(true)
        ground:Clear()
        expect(ground:Busy()).toBe(false)
        expect(searches.reset).toBe(true)
    end)
end)

describe("GroundRoute: o que sobra do caminho", function()
    it("tira os cantos que ficaram para trás", function()
        local ground = setup()
        local points = { { X = 20, Y = 10 }, { X = 40, Y = 10 } }
        local rest = ground:Remaining(points, 0, 10, 30, 11, 60, 10)
        expect(#rest).toBe(1)
        expect(rest[1].X).toBe(40)
    end)
end)

describe("GroundRoute: integração", function()
    local engine = loader.read("Carbonite/Modules/Map/MapEngine.lua")

    it("os passos não desenham ícone de destino e o HUD soma o caminho", function()
        expect(engine:find("if target and not target.GroundStep", 1, true) ~= nil).toBe(true)
        expect(engine:find("self.Tracking = ground:Expand(self, tr)", 1, true) ~= nil).toBe(true)
        expect(engine:find("dist1 = (dist1 or 0) + (self.TrackDistYd or 0)", 1, true) ~= nil).toBe(true)
    end)

    it("o motor e o módulo entram na carga do Carbonite", function()
        expect(loader.read("Carbonite/Libs/libs.xml"):find("GroundNav\\GroundNav.xml", 1, true) ~= nil).toBe(true)
        expect(loader.read("Carbonite/Modules/Modules.xml"):find("Map\\GroundRoute.lua", 1, true) ~= nil).toBe(true)
    end)

    it("a opção tem texto em pt-BR", function()
        local pt = loader.read("Carbonite/Locales/ptBR/Options.lua")
        expect(pt:find('L["Walking route around the terrain"] = "Rota a pé contornando o terreno"', 1, true) ~= nil).toBe(true)
    end)
end)
