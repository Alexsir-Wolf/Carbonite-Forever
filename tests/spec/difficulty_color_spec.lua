-- Nx.Quest.GetCachedDifficultyColorStr in Carbonite.Quests/NxQuest.lua (#29)

describe("cor de dificuldade da quest", function()
    it("recalcula a cor quando o jogador sobe de nível", function()
        local env = wow.lenientEnv()
        local playerLevel = 27
        env.UnitLevel = function() return playerLevel end
        -- Stand-in for the client rule: grey at 6+ levels below the player.
        env.GetQuestDifficultyColor = function(level)
            if playerLevel - level >= 6 then return { r = 0.5, g = 0.5, b = 0.5 } end
            return { r = 0, g = 1, b = 0 }
        end
        env.Nx = wow.namespace({ Quest = {}, MaxPlayerLevel = 60 })
        loader.run(env, "Carbonite.Quests/NxQuest.lua")
        local colorStr = env.Nx.Quest.GetCachedDifficultyColorStr

        expect(colorStr(22)).toBe("|cff00ff00")
        playerLevel = 28
        expect(colorStr(22)).toBe("|cff7f7f7f")
    end)
end)
