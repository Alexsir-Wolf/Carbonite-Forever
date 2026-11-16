-- Code that only served Retail, missing addons or nothing at all (#24)

local function tickers(isRetail)
    local env = wow.lenientEnv()
    local count = 0
    env.C_Timer = { After = function() end, NewTicker = function() count = count + 1 end }
    env.C_TaskQuest = { GetQuestsOnMap = function() return {} end }
    env.Nx = wow.namespace({ isRetail = isRetail, Quest = {}, Map = {} })
    loader.run(env, "Carbonite.Quests/MapIcons.lua")
    return count
end

describe("cache de world quests", function()
    it("não cria o timer de 1 s fora do Retail", function()
        expect(tickers(false)).toBe(0)
    end)

    it("cria o timer no Retail", function()
        expect(tickers(true)).toBe(1)
    end)
end)

describe("funções sem uso", function()
    it("Info.Combat não tem mais OnUpdate vazio", function()
        local src = loader.read("Carbonite.Info/NxInfo.lua")
        expect(src:find("Combat:OnUpdate", 1, true)).toBeNil()
        expect(src:find('"OnUpdate", self.OnUpdate', 1, true)).toBeNil()
    end)

    it("Api.Unit não tem mais GetPosition", function()
        expect(loader.read("Carbonite/Compat/Api.lua"):find("Unit:GetPosition", 1, true)).toBeNil()
    end)

    it("Notes não usa mais o WorldMapBlobFrame inexistente", function()
        expect(loader.read("Carbonite.Notes/WindowEngine.lua"):find("WorldMapBlobFrame", 1, true)).toBeNil()
    end)
end)
