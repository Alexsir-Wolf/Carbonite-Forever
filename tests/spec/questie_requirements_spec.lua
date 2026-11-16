-- Quest givers: a profession the character lacks, or an excluded quest, is not available (#80)

local function load(fields, opts)
    opts = opts or {}
    local env = wow.lenientEnv()
    env.UnitLevel = function() return 30 end
    env.GetMaxPlayerLevel = function() return 60 end
    env.LibQuestieDB = {
        RequireContract = function() return true, true end,
        Support = { Get = function() return nil end },
        Quest = { GetAll = function(qId) return fields[qId] or {} end },
    }
    env.GetFactionInfoByID = function(id) return "f", "", 0, 0, 0, (opts.rep or {})[id] or 0 end
    env.C_QuestLog = { IsQuestFlaggedCompleted = function(q) return (opts.done or {})[q] or false end }
    env.Carbonite = { Compat = { Api = { Skill = { GetRank = function(_, line) return (opts.ranks or {})[line] or 0 end } } } }
    env.Nx = wow.namespace({ Quest = wow.namespace({ IdToCurQ = opts.inLog or {} }) })
    function env.Nx.Quest:GetQuest() return nil end
    loader.run(env, "Carbonite.Quests/QuestieSource.lua")
    return env.Nx.Quest
end

describe("requisitos do QuestieDB", function()
    it("quest de profissão pede a perícia", function()
        local fields = { [100] = { { 186, 50 } } }               -- Mineração 50
        expect(load(fields, { ranks = { [186] = 75 } }):MeetsQuestieRequirements(100)).toBe(true)
        expect(load(fields, { ranks = { [186] = 20 } }):MeetsQuestieRequirements(100)).toBe(false)
        expect(load(fields):MeetsQuestieRequirements(100)).toBe(false)
    end)

    it("quest excluída por outra já feita ou no registro", function()
        local fields = { [100] = { nil, { 200, 201 } } }
        expect(load(fields):MeetsQuestieRequirements(100)).toBe(true)
        expect(load(fields, { done = { [201] = true } }):MeetsQuestieRequirements(100)).toBe(false)
        expect(load(fields, { inLog = { [200] = 1 } }):MeetsQuestieRequirements(100)).toBe(false)
    end)

    it("reputação fora da faixa pedida", function()
        local fields = { [100] = { nil, nil, { 59, 3000 } }, [101] = { nil, nil, nil, { 59, 9000 } } }
        expect(load(fields, { rep = { [59] = 5000 } }):MeetsQuestieRequirements(100)).toBe(true)
        expect(load(fields, { rep = { [59] = 1000 } }):MeetsQuestieRequirements(100)).toBe(false)
        expect(load(fields, { rep = { [59] = 9500 } }):MeetsQuestieRequirements(101)).toBe(false)
    end)

    it("o filtro de disponíveis do mapa usa os requisitos", function()
        local src = loader.read("Carbonite/Data/Shared/NxMapGuide.lua")
        expect(src:find("Quest:MeetsQuestieRequirements (qId)", 1, true) ~= nil).toBe(true)
    end)
end)
