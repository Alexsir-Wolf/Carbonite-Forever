-- GatherLite nodes tinted by the chance of a skill point (#76)

local function notes()
    local env = wow.lenientEnv()
    env.Nx = { Notes = {}, fdb = { profile = { Notes = {} } } }
    loader.run(env, "Carbonite.Notes/Integrations/GatherLite.lua")
    return env.Nx.Notes
end

describe("cor da perícia nos nós de coleta", function()
    local N = notes()
    local copper = { 1, 25, 50, 100 }

    it("segue as faixas do jogo", function()
        expect(N:GatherSkillColor(copper, 10)).toBe("ff8040")   -- laranja
        expect(N:GatherSkillColor(copper, 30)).toBe("ffff20")   -- amarelo
        expect(N:GatherSkillColor(copper, 75)).toBe("40c040")   -- verde
        expect(N:GatherSkillColor(copper, 150)).toBe("a0a0a0")  -- cinza
        expect(N:GatherSkillColor({ 65, 90, 115, 165 }, 40)).toBe("ff3030")  -- estanho com 40: vermelho
    end)

    it("sem a profissão ou sem faixas, não pinta", function()
        expect(N:GatherSkillColor(copper, 0)).toBeNil()
        expect(N:GatherSkillColor(nil, 50)).toBeNil()
    end)
end)
