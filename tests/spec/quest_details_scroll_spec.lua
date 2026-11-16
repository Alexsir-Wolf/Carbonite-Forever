-- Nx.Quest:FitDetailsScrollChild in Carbonite.Quests/QuestWindow.lua (#94)

local function region(bottom, shown)
    return { GetBottom = function() return bottom end, IsShown = function() return shown ~= false end,
             GetRegions = function() end, GetChildren = function() end }
end

local function load(childTop, contentBottoms, scrollH)
    local env = wow.lenientEnv()
    env.Nx = wow.namespace()
    loader.run(env, "Carbonite.Quests/QuestWindow.lua")
    local regions = {}
    for i, b in ipairs(contentBottoms) do regions[i] = region(b) end
    local child = {
        GetTop = function() return childTop end,
        GetScale = function() return 1 end,
        GetRegions = function() return unpack(regions) end,
        GetChildren = function() end,
        SetHeight = function(self, h) self.h = h end,
    }
    local scroll = {
        GetHeight = function() return scrollH end,
        UpdateScrollChildRect = function(self) self.updated = true end,
    }
    env.NXQuestLogDetailScrollChildFrame = child
    env.NxQuestD = scroll
    return env.Nx.Quest, child, scroll
end

describe("FitDetailsScrollChild", function()
    it("estica o filho até o fim do texto longo", function()
        local Quest, child, scroll = load(1000, { 900, 300 }, 333)
        Quest:FitDetailsScrollChild()
        expect(child.h).toBe(1000 - 300 + 16)
        expect(scroll.updated).toBe(true)
    end)

    it("nunca fica menor que o painel", function()
        local Quest, child = load(1000, { 950 }, 333)
        Quest:FitDetailsScrollChild()
        expect(child.h).toBe(333)
    end)
end)
