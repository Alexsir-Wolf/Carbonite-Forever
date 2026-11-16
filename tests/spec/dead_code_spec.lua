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
