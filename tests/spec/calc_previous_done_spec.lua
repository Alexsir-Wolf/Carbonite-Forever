-- Nx.Quest:CalcPreviousDone in Carbonite.Quests/BlizzardLog.lua (#4)

local function run(quests, qId, done)
    local env = wow.lenientEnv()
    env.time = function() return 0 end
    env.Nx = wow.namespace({ Quest = {}, Quests = quests })
    loader.run(env, "Carbonite.Quests/BlizzardLog.lua")
    local Quest = env.Nx.Quest
    local status = {}
    for _, id in ipairs(done or {}) do status[id] = "C" end
    Quest.UnpackNext = function(_, info) return tonumber(info:match("^[^|]*|[^|]*|[^|]*|[^|]*|([^|]*)")) end
    Quest.GetQuest = function(_, id) return status[id] end
    Quest.SetQuest = function(_, id, s) status[id] = s end
    return Quest:CalcPreviousDone(qId), status
end

-- Real ids, as ProcessQuestDB and QuestieSource store them: 783 -> 7 -> 15.
local function chain()
    return {
        [783] = { Quest = "A|1|1|1|7|0", CNum = 1 },
        [7]   = { Quest = "B|1|2|1|15|0", CNum = 2 },
        [15]  = { Quest = "C|1|3|1|0|0", CNum = 3 },
        [-7]  = 1,
    }
end

describe("Quest:CalcPreviousDone", function()
    it("marca como concluídas as quests antes da atual na cadeia", function()
        local cnt, status = run(chain(), 15)
        expect(cnt).toBe(2)
        expect(status[783]).toBe("C")
        expect(status[7]).toBe("C")
        expect(status[15]).toBeNil()
    end)

    it("não conta as que já estavam concluídas", function()
        local cnt = run(chain(), 15, { 783 })
        expect(cnt).toBe(1)
    end)

    it("termina em cadeia com laço", function()
        local q = { [1] = { Quest = "A|1|1|1|2|0", CNum = 1 }, [2] = { Quest = "B|1|1|1|1|0", CNum = 2 } }
        expect(run(q, 99)).toBe(0)
    end)
end)
