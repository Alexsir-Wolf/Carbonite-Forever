-- Nx.Quest:FitDetailsScrollChild in Carbonite.Quests/QuestWindow.lua: the scroll range reaches
-- the rewards even when QuestInfo keeps the rewards frame parented elsewhere

local function region(top, bottom, scale)
    return {
        GetTop = function() return top end,
        GetBottom = function() return bottom end,
        IsShown = function() return true end,
        IsVisible = function() return true end,
        GetEffectiveScale = function() return scale or 1 end,
        GetRegions = function() return end,
        GetChildren = function() return end,
    }
end

local function fit(rewards)
    local missing = { "QuestInfoFrame", "MapQuestInfoRewardsFrame" }
    if not rewards then missing[#missing + 1] = "QuestInfoRewardsFrame" end
    local env = wow.lenientEnv(nil, missing)
    local height
    local child = region(1000, 0)
    local text = region(990, 700)
    child.GetRegions = function() return text end
    child.SetHeight = function(_, h) height = h end
    child.GetScale = function() return 1 end
    env.NXQuestLogDetailScrollChildFrame = child
    env.NxQuestD = { GetHeight = function() return 400 end, UpdateScrollChildRect = function() end }
    env.QuestInfoRewardsFrame = rewards
    env.Nx = wow.namespace({ Quest = wow.namespace(), List = {}, Window = {} })
    loader.run(env, "Carbonite.Quests/QuestWindow.lua")
    env.Nx.Quest:FitDetailsScrollChild()
    return height
end

describe("rolagem dos detalhes da quest", function()
    it("mede só o texto quando não há recompensas", function()
        expect(fit(nil)).toBe(400)   -- 1000 - 700 + 16 = 316, abaixo da altura do painel
    end)

    it("inclui o bloco de recompensas desenhado no painel, mesmo de outro pai", function()
        expect(fit(region(690, 500))).toBe(516)
    end)

    it("ignora um bloco de recompensas mostrado fora do painel", function()
        expect(fit(region(1200, 1100))).toBe(400)
    end)
end)
