-- Carbonite.Quests/NxQuest.lua must not replace client functions (#11, #14).

local STUBS = { "GetQuestLogCriteriaSpell", "ProcessQuestLogRewardFactions",
    "GetQuestLogPortraitGiver", "GetQuestLogRewardSkillPoints", "GetQuestLogRewardArtifactXP" }

local function load(env)
    env.Nx = wow.namespace({ MaxPlayerLevel = 60 })
    loader.run(env, "Carbonite.Quests/NxQuest.lua")
    return env
end

describe("NxQuest e funções nativas", function()
    it("mantém as funções de recompensa que o cliente já tem", function()
        local natives = {}
        for _, name in ipairs(STUBS) do natives[name] = function() return "native" end end
        local env = load(wow.lenientEnv(natives, { "IsQuestWatched", "AddQuestWatch", "RemoveQuestWatch" }))
        for _, name in ipairs(STUBS) do
            expect(rawget(env, name)).toBe(natives[name])
        end
    end)

    it("cria os stubs só quando faltam", function()
        local env = load(wow.lenientEnv({}, STUBS))
        expect(rawget(env, "GetQuestLogRewardSkillPoints")()).toBe(0)
    end)

    it("não cria IsUnitOnQuest, IsQuestWatched, AddQuestWatch nem RemoveQuestWatch", function()
        local names = { "IsUnitOnQuest", "IsQuestWatched", "AddQuestWatch", "RemoveQuestWatch" }
        local env = load(wow.lenientEnv({ C_QuestLog = wow.anything() }, names))
        for _, name in ipairs(names) do
            expect(rawget(env, name)).toBeNil()
        end
    end)
end)
