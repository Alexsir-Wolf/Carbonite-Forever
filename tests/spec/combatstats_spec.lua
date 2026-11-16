-- Carbonite/Modules/CombatStats/CombatStats.lua: one chat summary per score update (#18)

describe("CombatStats no placar de battleground", function()
    it("atualiza os números sem anunciar no chat", function()
        local env = wow.lenientEnv()
        local said = 0
        local mod = { log = { info = function() said = said + 1 end } }
        env.Carbonite.Core.Module = { New = function() return mod end }
        env.GetNumBattlefieldScores = function() return 1 end
        env.UnitName = function() return "Eu" end
        env.GetBattlefieldScore = function() return "Eu", 3, 5, 1, 120, 0, 0, 0, 0, 900, 50 end
        loader.run(env, "Carbonite/Modules/CombatStats/CombatStats.lua")
        mod:OnBattlefieldScore()
        expect(mod:GetStats().KBs).toBe(3)
        expect(said).toBe(0)
    end)
end)
