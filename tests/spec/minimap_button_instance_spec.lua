-- Carbonite's minimap button hides while the minimap is inside the map window (instances)

local function load(showCarb)
    local env = wow.lenientEnv()
    local but = { shown = true }
    function but:Hide() self.shown = false end
    function but:Show() self.shown = true end
    env.NXMiniMapBut = but
    env.Nx = wow.namespace({ Map = wow.namespace(), db = { profile = { MiniMap = { ButShowCarb = showCarb } } } })
    loader.run(env, "Carbonite/Modules/Map/UnmappedInstance.lua")
    local map = setmetatable({ MapW = 100, MapH = 100 }, { __index = env.Nx.Map })
    return map, but
end

describe("botão do minimapa em instância sem mapa", function()
    it("some ao entrar e volta ao sair", function()
        local map, but = load(true)
        map.IsUnmappedInstance = function() return true end
        map:UpdateUnmappedInstanceView()
        expect(but.shown).toBe(false)
        map.IsUnmappedInstance = function() return false end
        map:UpdateUnmappedInstanceView()
        expect(but.shown).toBe(true)
    end)

    it("não volta se o jogador desligou o botão", function()
        local map, but = load(false)
        map.IsUnmappedInstance = function() return true end
        map:UpdateUnmappedInstanceView()
        map.IsUnmappedInstance = function() return false end
        map:UpdateUnmappedInstanceView()
        expect(but.shown).toBe(false)
    end)
end)
