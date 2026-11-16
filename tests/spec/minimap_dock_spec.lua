-- Carbonite's minimap button Dock stays off with MinimapButtonButton (#86)

describe("Dock de botões do minimapa", function()
    local src = loader.read("Carbonite/Modules/Map/MapEngine.lua")

    it("não cria o Dock com o MinimapButtonButton carregado", function()
        expect(src:find('loaded ("MinimapButtonButton")', 1, true) ~= nil).toBe(true)
        expect(src:find("if not Nx.db.profile.MiniMap.ButOwn or self:OtherCollector() then", 1, true) ~= nil).toBe(true)
    end)

    it("a opção fica desligada nesse caso", function()
        local opts = loader.read("Carbonite/Modules/Options/OptionsEngine.lua")
        expect(opts:find("disabled = function() return Nx.Map.Dock:OtherCollector() end", 1, true) ~= nil).toBe(true)
    end)
end)
