-- Mapa grande abre na zona do jogador (#199): Nx.Map:MaxSize centra na
-- zona/cidade do jogador e o título usa a zona do jogador, não a do cursor.

local src = loader.read("Carbonite/Modules/Map/MapEngine.lua")

local function fn(env, name)
    local first = src:find("\nfunction Nx.Map:" .. name .. "%s*%(")
    assert(first, name)
    local _, last = src:find("\r?\nend\r?\n", first + 1)
    local chunk = assert(loadstring(src:sub(first + 1, last)))
    setfenv(chunk, env)
    chunk()
end

local ORGRIMMAR, VALE_GRIS = 85, 63

local function setup(opts)
    opts = opts or {}
    local Map = { UpdateMapID = opts.hovered or VALE_GRIS }
    local env = {
        Nx = { Map = Map, db = { profile = { Map = { MaxCenter = opts.center ~= false },
                                             Debug = {} } } },
        min = math.min,
    }
    for _, name in ipairs({ "MaxSize", "GetPlayerZoneMapId", "CenterOnPlayerZone" }) do
        fn(env, name)
    end

    local calls = {}
    local maxed = false
    local map = setmetatable({
        Win = { IsSizeMax = function() return maxed end, ToggleSize = function() maxed = true end },
        MapWorldInfo = { [ORGRIMMAR] = { City = true }, [VALE_GRIS] = {} },
        Scale = 50, StepTime = 0, PlyrX = 1200, PlyrY = 900,
        MaxViewScale = 80,
        SaveView = function() end,
        MouseEnable = function() end,
        IsInstanceMap = function(_, id) return id == opts.instance end,
        GetPlayerMapAreaID = function() return opts.player or ORGRIMMAR end,
        CenterMap = function(self, id)
            calls[#calls + 1] = { "center", id }
            if id then self.Scale = 3 end
        end,
        Move = function(self, x, y, scale)
            calls[#calls + 1] = { "move", x, y, scale }
            if scale then self.Scale = scale end
        end,
    }, { __index = Map })
    return map, calls, Map
end

describe("mapa grande abre na zona do jogador (#199)", function()
    it("centra na cidade do jogador com a escala da zona, não na escala salva", function()
        local map, calls = setup()
        map:MaxSize()
        expect(calls[1][1]).toBe("center")
        expect(calls[1][2]).toBe(ORGRIMMAR)
        expect(map.Scale).toBe(3)
        expect(map.RealScale).toBe(3)
    end)

    it("põe o jogador no meio da janela", function()
        local map, calls = setup()
        map:MaxSize()
        expect(calls[2][1]).toBe("move")
        expect(calls[2][2]).toBe(1200)
        expect(calls[2][3]).toBe(900)
        expect(calls[2][4]).toBeNil()
    end)

    it("nunca chama CenterMap sem mapa (que não faz nada)", function()
        local map, calls = setup()
        map:MaxSize()
        for _, c in ipairs(calls) do
            if c[1] == "center" then expect(c[2] ~= nil).toBe(true) end
        end
    end)

    it("sem a opção de centrar, mantém a vista salva", function()
        local map, calls = setup({ center = false })
        map:MaxSize()
        expect(#calls).toBe(0)
        expect(map.Scale).toBe(80)
    end)

    it("em masmorra mantém o comportamento antigo", function()
        local map, calls = setup({ instance = ORGRIMMAR })
        map:MaxSize()
        expect(#calls).toBe(0)
    end)

    it("sem posição do jogador, só ajusta a zona", function()
        local map, calls = setup()
        map.PlyrX, map.PlyrY = 0, 0
        map:MaxSize()
        expect(#calls).toBe(1)
    end)
end)

describe("título do mapa usa a zona do jogador (#199)", function()
    it("a zona do título é a do jogador, mesmo com o cursor em outra zona", function()
        local map = setup({ hovered = VALE_GRIS })
        expect(map:GetPlayerZoneMapId()).toBe(ORGRIMMAR)
    end)

    it("sem mapa do jogador (carregando), cai no mapa visível", function()
        local map = setup({ hovered = VALE_GRIS, player = 0 })
        expect(map:GetPlayerZoneMapId()).toBe(VALE_GRIS)
    end)

    it("o título junta o nome da zona do jogador com as coordenadas dele", function()
        expect(src:find("title = map:IdToName (map:GetPlayerZoneMapId())", 1, true) ~= nil).toBe(true)
        expect(src:find("title = map:IdToName (map.UpdateMapID)", 1, true)).toBeNil()
    end)
end)
