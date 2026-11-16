-- Money, durations and dates in the client's format (#54)

local function load(symbols)
    local env = wow.lenientEnv()
    local ptBR = { ["%d days, %d hours, %d minutes, %d seconds"] = "%d dias, %d horas, %d minutos e %d segundos" }
    local locale = setmetatable(ptBR, { __index = function(_, k) return k end })
    env.LibStub = function()
        return setmetatable({ GetLocale = function() return locale end },
            { __index = function() return wow.anything() end })
    end
    for k, v in pairs(symbols or {}) do env[k] = v end
    env.mod = math.fmod
    env.strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
    env.bit = { mod = math.fmod }
    env.Nx = wow.namespace()
    loader.run(env, "Carbonite/Modules/UI/UIEngine.lua")
    return env.Nx
end

describe("formatos do cliente", function()
    it("a moeda usa os símbolos do próprio cliente", function()
        local Nx = load({ GOLD_AMOUNT_SYMBOL = "o", SILVER_AMOUNT_SYMBOL = "p", COPPER_AMOUNT_SYMBOL = "c" })
        expect(Nx.Util_GetMoneyStr(12345)).toBe("|cffffff001o |cffbfbfbf23p |cff7f7f0045c")
    end)

    it("a duração é traduzida", function()
        local Nx = load()
        expect(Nx.Util_SecondsToDays(90061)).toBe("1 dias, 1 horas, 1 minutos e 1 segundos")
    end)

    it("as datas vêm do locale, com dia antes do mês no pt-BR", function()
        expect(loader.read("Carbonite/Locales/ptBR/Main.lua"):find('L["%m/%d/%y"] = "%d/%m/%y"', 1, true) ~= nil).toBe(true)
        expect(loader.read("Carbonite.Quests/Locales/ptBR.lua"):find('L["%m/%d %H:%M:%S"] = "%d/%m %H:%M:%S"', 1, true) ~= nil).toBe(true)
        expect(loader.read("Carbonite.Quests/QuestWindow.lua"):find('date ("|cff', 1, true)).toBeNil()
    end)
end)
