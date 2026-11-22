-- Carbonite's minimap button hides while the minimap is inside the map window (instances)

local function load(showCarb, collector)
    local env = wow.lenientEnv()
    local but = { shown = true }
    function but:Hide() self.shown = false end
    function but:Show() self.shown = true end
    env.NXMiniMapBut = but
    env.Nx = wow.namespace({
        Map = wow.namespace({ Dock = { OtherCollector = function() return true end } }),
        NXMiniMapBut = { DBIcon = false },
        Broker = {},
        db = { profile = { MiniMap = { ButShowCarb = showCarb, ButOwn = true } } },
    })
    if collector then
        local icon = { IsRegistered = function() return false end, Register = function() end }
        local other = env.LibStub
        env.LibStub = function(name, ...)
            if name == "LibDBIcon-1.0" then return icon end
            return other(name, ...)
        end
        loader.run(env, "Carbonite/Modules/Map/MinimapButtonEngine.lua")
        env.Nx.NXMiniMapBut:RegisterDBIcon()
    end
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

    it("não volta com o botão do LibDBIcon no lugar dele (coletor de botões)", function()
        local map, but = load(true, true)
        expect(but.shown).toBe(false)
        for _ = 1, 2 do
            map.IsUnmappedInstance = function() return true end
            map:UpdateUnmappedInstanceView()
            map.IsUnmappedInstance = function() return false end
            map:UpdateUnmappedInstanceView()
            expect(but.shown).toBe(false)
        end
    end)
end)
