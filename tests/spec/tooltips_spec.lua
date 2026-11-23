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

describe("Nx.Quest.QuestTipIsStale", function()
    local function load(mouseover)
        local env = wow.lenientEnv({
            TooltipDataProcessor = {},
            UnitExists = function() return mouseover.value end,
        }, { "issecretvalue", "canaccessvalue" })
        env.Nx = wow.namespace()
        loader.run(env, "Carbonite.Quests/Tooltips.lua")
        return env.Nx.Quest
    end

    local function source(owner, unit)
        local s = { shown = true, owner = owner, alpha = 1, unit = unit }
        function s:IsShown() return self.shown end
        function s:GetOwner() return self.owner end
        function s:GetAlpha() return self.alpha end
        function s:GetUnit() return self.unit and "Lavrador" or nil, self.unit end
        return s
    end

    it("mantém enquanto o tooltip do jogo mostra a mesma coisa", function()
        local Q = load({ value = true })
        local s = source("bag", nil)
        expect(Q.QuestTipIsStale(s, Q.CaptureQuestTipSource(s))).toBe(false)
    end)

    it("esconde quando o tooltip do jogo some", function()
        local Q = load({ value = true })
        local s = source("bag", nil)
        local cap = Q.CaptureQuestTipSource(s)
        s.shown = false
        expect(Q.QuestTipIsStale(s, cap)).toBe(true)
    end)

    it("esconde quando o tooltip do jogo começa o fade", function()
        local Q = load({ value = true })
        local s = source("world", "mouseover")
        local cap = Q.CaptureQuestTipSource(s)
        s.alpha = .6
        expect(Q.QuestTipIsStale(s, cap)).toBe(true)
    end)

    it("esconde quando o tooltip do jogo passa para outro frame", function()
        local Q = load({ value = true })
        local s = source("bag", nil)
        local cap = Q.CaptureQuestTipSource(s)
        s.owner = "actionbar"
        expect(Q.QuestTipIsStale(s, cap)).toBe(true)
    end)

    it("esconde quando o mouse sai do NPC", function()
        local mouseover = { value = true }
        local Q = load(mouseover)
        local s = source("world", "mouseover")
        local cap = Q.CaptureQuestTipSource(s)
        expect(Q.QuestTipIsStale(s, cap)).toBe(false)
        mouseover.value = false
        expect(Q.QuestTipIsStale(s, cap)).toBe(true)
    end)
end)
