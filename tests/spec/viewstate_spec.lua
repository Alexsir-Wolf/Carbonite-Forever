-- Carbonite/Modules/Map/ViewState.lua (#26)

local function load()
    local env = wow.env()
    loader.run(env, "Carbonite/Modules/Map/ViewState.lua")
    local map = { Scale = 2, MapPosX = 10, MapPosY = 20 }
    env.Nx = { Map = { Maps = { map } } }
    return env, env.Carbonite.Modules.Map.ViewState, map
end

describe("ViewState com Nx.InBG", function()
    it("salva sem prefixo quando Nx.InBG é só o flag", function()
        local env, VS, map = load()
        env.Nx.InBG = true
        expect(function() VS:Save("Main") end).toNotThrow()
        expect(map.ViewSavedData["Main"]).toBeTruthy()
    end)

    it("usa o id do mapa do battleground como prefixo", function()
        local env, VS, map = load()
        env.Nx.InBG = true
        env.Nx.InBGMapId = 1460
        VS:Save("Main")
        expect(map.ViewSavedData["1460Main"]).toBeTruthy()
    end)
end)
