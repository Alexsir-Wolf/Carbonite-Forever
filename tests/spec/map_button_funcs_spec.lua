-- Map mouse-button actions saved by id, not by translated label (#51)

local ptBR = { ["Show Player Zone"] = "Mostrar Zona do Jogador", ["Menu"] = "Menu", ["None"] = "Nenhum" }

local function load()
    local env = wow.lenientEnv()
    local locale = setmetatable(ptBR, { __index = function(_, k) return k end })
    env.LibStub = function()
        return setmetatable({ GetLocale = function() return locale end },
            { __index = function() return wow.anything() end })
    end
    env.Nx = wow.namespace({ Map = wow.namespace(), db = { profile = { Map = {} } } })
    loader.run(env, "Carbonite/Modules/Map/MapEngine.lua")
    return env.Nx
end

describe("ações dos botões do mapa", function()
    local Nx = load()

    it("as opções mostram o rótulo traduzido de cada id", function()
        local funcs = Nx.Map:GetFuncs()
        expect(funcs.ShowPlayerZone).toBe("Mostrar Zona do Jogador")
        expect(funcs.None).toBe("Nenhum")
    end)

    it("o clique roda a ação pelo id", function()
        local ran
        local map = setmetatable({ OpenMenu = function() ran = "menu" end }, { __index = Nx.Map })
        Nx.db.profile.Map.ButR = "Menu"
        Nx.db.profile.Map.ButRAlt = "None"
        expect(map:CallFunc("ButR")).toBe(true)
        expect(ran).toBe("menu")
        expect(map:CallFunc("ButRAlt")).toBeNil()
    end)

    it("migra os rótulos já salvos, traduzidos ou em inglês", function()
        local saved = { ButM = "Mostrar Zona do Jogador", ButR = "Menu", ButLCtrl = "Goto",
                        But4 = "Show Selected Zone", But4Alt = "Add Note" }
        Nx.Map.MigrateButtonFuncs(saved)
        expect(saved.ButM).toBe("ShowPlayerZone")
        expect(saved.ButR).toBe("Menu")
        expect(saved.ButLCtrl).toBe("Goto")
        expect(saved.But4).toBe("ShowSelectedZone")
        expect(saved.But4Alt).toBe("None")
        expect(saved.ButMAlt).toBeNil()
    end)

    it("os padrões já usam ids", function()
        local src = loader.read("Carbonite/Modules/PlayerCharacter/Defaults.lua")
        expect(src:find('ButR = "Menu"', 1, true) ~= nil).toBe(true)
        expect(src:find('But4Alt = L[', 1, true)).toBeNil()
    end)
end)
