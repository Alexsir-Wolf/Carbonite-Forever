-- Meeting stones as a Guide category and the closest spirit healer to the corpse (#77)

local function guideEnv()
    local env = wow.lenientEnv()
    env.Nx = { GuideData = {} }
    env.LibStub = function() return { GetLocale = function() return setmetatable({}, { __index = function(_, k) return k end }) end } end
    return env
end

describe("pedras de encontro no Guia", function()
    it("os dados do Forever usam o modo 32 com pontos neutros", function()
        local env = guideEnv()
        loader.run(env, "Carbonite/Data/camelot/Guides/MeetingStone.lua")
        local data = env.Nx.GuideData["Meeting Stone"]
        expect(data.Mode).toBe(32)
        expect(data[1453]).toBe("0,53.23,70.33")     -- Ventobravo
        local zones = 0
        for zone, row in pairs(data) do
            if zone ~= "Mode" then
                zones = zones + 1
                for point in row:gmatch("[^|]+") do
                    expect(point:match("^0,%d+%.%d+,%d+%.%d+$") ~= nil).toBe(true)
                end
            end
        end
        expect(zones > 10).toBe(true)
    end)

    it("o Guia só cria a categoria onde há dados, e o Forever carrega o arquivo", function()
        local src = loader.read("Carbonite/Data/Shared/NxMapGuide.lua")
        expect(src:find('if Nx.GuideData and Nx.GuideData[L["Meeting Stone"]] then', 1, true) ~= nil).toBe(true)
        expect(loader.read("Carbonite/Data/camelot/Guides/guide.xml"):find("MeetingStone.lua", 1, true) ~= nil).toBe(true)
        expect(loader.read("Carbonite/Locales/ptBR/Guide.lua"):find('L["Meeting Stone"] = "Pedra de Encontro"', 1, true) ~= nil).toBe(true)
    end)
end)

describe("curandeiro espiritual mais próximo do cadáver", function()
    local function load()
        local env = wow.lenientEnv()
        env.Nx = wow.namespace({ Map = wow.namespace(), GuideData = {} })
        loader.run(env, "Carbonite/Modules/Map/MapEngine.lua")
        local Map = env.Nx.Map
        local calls = 0
        local map = setmetatable({
            GetWorldPos = function(_, _, x, y) calls = calls + 1; return x * 2, y end,
        }, { __index = Map })
        return env, map, function() return calls end
    end

    it("escolhe o curandeiro mais perto na mesma zona", function()
        local env, map = load()
        env.Nx.GuideData["Spirit Healer"] = { Mode = 32, [1429] = "0,10.00,10.00|0,50.00,50.00|0,90.00,10.00" }
        local x, y = map:NearestSpiritHealer(1429, 55, 45)
        expect(x).toBe(50)
        expect(y).toBe(50)
    end)

    it("usa a distância no mundo, não em porcentagem da zona", function()
        local env, map = load()
        -- x vale o dobro no mundo: (30,10) fica mais longe de (10,10) que (10,35)
        env.Nx.GuideData["Spirit Healer"] = { Mode = 32, [1429] = "0,30.00,10.00|0,10.00,35.00" }
        local x, y = map:NearestSpiritHealer(1429, 10, 10)
        expect(x).toBe(10)
        expect(y).toBe(35)
    end)

    it("não procura de novo enquanto o cadáver não muda", function()
        local env, map, calls = load()
        env.Nx.GuideData["Spirit Healer"] = { Mode = 32, [1429] = "0,10.00,10.00|0,50.00,50.00" }
        map:NearestSpiritHealer(1429, 20, 20)
        local first = calls()
        map:NearestSpiritHealer(1429, 20, 20)
        expect(calls()).toBe(first)
    end)

    it("não devolve nada sem dados da zona", function()
        local env, map = load()
        env.Nx.GuideData["Spirit Healer"] = { Mode = 32 }
        expect(map:NearestSpiritHealer(1429, 20, 20)).toBe(nil)
        expect(map:NearestSpiritHealer(nil, 20, 20)).toBe(nil)
    end)

    it("o mapa desenha o curandeiro só no ramo do cadáver", function()
        local src = loader.read("Carbonite/Modules/Map/MapEngine.lua")
        local corpse = src:find('f.NxTip = "Your corpse"', 1, true)
        local healer = src:find('self:NearestSpiritHealer (corpseMap, cX * 100, cY * 100)', 1, true)
        local taxi = src:find('elseif ontaxi and Map.TaxiX then', 1, true)
        expect(corpse ~= nil and healer ~= nil and taxi ~= nil).toBe(true)
        expect(corpse < healer and healer < taxi).toBe(true)
    end)
end)
