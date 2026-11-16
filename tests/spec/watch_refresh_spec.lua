-- Nx.Quest.Watch:RefreshInterval in Carbonite.Quests/WatchWindow.lua (#16)

local function interval(refreshTimer)
    local env = wow.lenientEnv()
    env.Nx = wow.namespace({ Quest = { Watch = {} } })
    loader.run(env, "Carbonite.Quests/WatchWindow.lua")
    env.Nx.qdb = { profile = { QuestWatch = { RefreshTimer = refreshTimer } } }
    return env.Nx.Quest.Watch:RefreshInterval()
end

describe("Watch:RefreshInterval", function()
    it("usa o valor da opção em segundos", function()
        expect(interval(3000)).toBe(3)
    end)

    it("sobe valores antigos abaixo de 1 s para 1 s", function()
        expect(interval(500)).toBe(1)
    end)

    it("usa 1 s sem valor salvo", function()
        expect(interval(nil)).toBe(1)
    end)
end)
