-- Carbonite/Modules/Map/UnmappedInstance.lua (#95)

local function load(map)
    local env = wow.env()
    env.Nx = { Map = {} }
    loader.run(env, "Carbonite/Modules/Map/UnmappedInstance.lua")
    return setmetatable(map, { __index = env.Nx.Map })
end

local function toolbar(h, shown)
    return { Frm = { GetHeight = function() return h end, IsShown = function() return shown end } }
end

describe("GetUnmappedInstanceMinimapBox", function()
    it("deixa a faixa da barra de ferramentas livre", function()
        local map = load({ MapW = 600, MapH = 400, ToolBar = toolbar(22, true) })
        local size, x, y = map:GetUnmappedInstanceMinimapBox()
        expect(size).toBe(376)
        expect(x).toBe(112)
        expect(y).toBe(0)
        expect(y + size <= 400 - 22).toBe(true)
    end)

    it("usa a altura toda sem a barra", function()
        local map = load({ MapW = 600, MapH = 400, ToolBar = toolbar(22, false) })
        local size, x, y = map:GetUnmappedInstanceMinimapBox()
        expect(size).toBe(400)
        expect(x).toBe(100)
        expect(y).toBe(0)
    end)

    it("centraliza na vertical em janela estreita", function()
        local map = load({ MapW = 300, MapH = 500, ToolBar = toolbar(22, true) })
        local size, x, y = map:GetUnmappedInstanceMinimapBox()
        expect(size).toBe(300)
        expect(x).toBe(0)
        expect(y).toBe(88)
    end)
end)

describe("nível do minimapa em instância sem mapa", function()
    it("fica na camada acima da janela, mas com nível baixo, para não cobrir outros addons", function()
        local src = loader.read("Carbonite/Modules/Map/MapEngine.lua")
        expect(src:find("if unmappedInstance then\n%s+%-%-[^\n]*\n") ~= nil or src:find("if unmappedInstance then\r\n") ~= nil).toBe(true)
        expect(src:find("lvl = self:MinimapSyncLayer(lvl, 1, true)", 1, true) ~= nil).toBe(true)
        expect(src:find("            lvl = 1\n", 1, true) ~= nil or src:find("            lvl = 1\r\n", 1, true) ~= nil).toBe(true)
    end)
end)
