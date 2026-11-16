-- Carbonite.Quests/Tooltips.lua (#13)

describe("Nx.Quest.UsesPrivateTooltip", function()
    local function load(overrides, missing)
        local env = wow.lenientEnv(overrides, missing)
        env.Nx = wow.namespace()
        loader.run(env, "Carbonite.Quests/Tooltips.lua")
        return env.Nx.Quest
    end

    it("usa o tooltip separado quando o cliente tem TooltipDataProcessor", function()
        local Q = load({ TooltipDataProcessor = {} }, { "issecretvalue" })
        expect(Q.UsesPrivateTooltip()).toBe(true)
    end)

    it("usa o GameTooltip em cliente sem o pipeline moderno", function()
        local Q = load({}, { "issecretvalue", "TooltipDataProcessor" })
        expect(Q.UsesPrivateTooltip()).toBe(false)
    end)
end)
