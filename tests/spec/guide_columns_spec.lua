-- Guide: opens with content and names its columns (#99)

local function guide()
    local env = wow.lenientEnv()
    env.Nx = wow.namespace({ Map = wow.namespace({ Guide = {} }), db = { char = { Map = {} } } })
    loader.run(env, "Carbonite/Data/Shared/NxMapGuide.lua")
    return env.Nx.Map.Guide, env
end

local function list()
    local l = { names = {} }
    function l:ColumnSetName(id, name) self.names[id] = name end
    return l
end

describe("Guia", function()
    it("dá nome às colunas pelo que a categoria mostra", function()
        local G, env = guide()
        local l = list()
        G:SetListHeaders(l, env.Nx.GuideHeaders.Instance)
        expect(l.names[3]).toBe("Level")
        expect(l.names[4]).toBe("Players")
        expect(l.names[5]).toBe("")
        G:SetListHeaders(l, nil, true)
        expect(l.names[5]).toBe("Found")
    end)

    it("abre na última categoria usada, ou em Lugares comuns", function()
        local G, env = guide()
        local updated = 0
        G.PathHistory = { env.Nx.GuideInfo }
        G.PathHistorySel = {}
        function G:Update() updated = updated + 1 end
        function G:SelectLists() end
        G:OpenStartFolder()
        expect(G.PathHistory[2].Name).toBe("Common Place")
        env.Nx.db.char.Map.GuideLastFolder = "Class Trainer"
        G.PathHistory = { env.Nx.GuideInfo }
        G:OpenStartFolder()
        expect(G.PathHistory[2].Name).toBe("Class Trainer")
        expect(updated).toBe(2)
    end)

    it("sem Info2/Info3 e sem textos fixos em inglês nas colunas", function()
        local src = loader.read("Carbonite/Data/Shared/NxMapGuide.lua")
        expect(src:find('L["Info2"]', 1, true)).toBeNil()
        expect(src:find('" (Repair)"', 1, true)).toBeNil()
        expect(src:find('"%2d-Man"', 1, true)).toBeNil()
    end)
end)
