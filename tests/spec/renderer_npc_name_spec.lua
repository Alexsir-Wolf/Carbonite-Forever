-- Renderer.ResolveNpcName in Carbonite/Modules/Map/Renderer.lua (#3)

local function resolve(questieDB)
    local env = wow.lenientEnv()
    env.Carbonite.Modules.Map = { Pin = {}, Layer = {} }
    env.QuestieLoader = { ImportModule = function() return questieDB end }
    loader.run(env, "Carbonite/Modules/Map/Renderer.lua")
    return env.Carbonite.Modules.Map.Renderer.ResolveNpcName(42)
end

describe("Renderer.ResolveNpcName", function()
    it("lê o nome com QueryNPCSingle", function()
        local db = {
            QueryNPC = function() return { n = 1 } end,
            QueryNPCSingle = function(id, key) return key == "name" and id == 42 and "Marshal Dughan" or nil end,
        }
        expect(resolve(db)).toBe("Marshal Dughan")
    end)

    it("ignora resposta que não é texto", function()
        expect(resolve({ QueryNPCSingle = function() return { n = 1 } end })).toBeNil()
    end)
end)
