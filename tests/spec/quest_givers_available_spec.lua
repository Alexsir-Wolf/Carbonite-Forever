-- Quest givers on the map: only the quests the player can take now (#39)

local function guide(opts)
    opts = opts or {}
    local env = wow.lenientEnv()
    env.Nx = wow.namespace({
        Map = wow.namespace({ Guide = {} }),
        QuestFreq = opts.freq or {},
        Quest = {
            IdToCurQ = opts.inLog or {},
            GetQuest = function(_, qId) return (opts.done or {})[qId] and "C" or nil end,
            PrereqMet = function(_, qId) return not (opts.locked or {})[qId] end,
        },
    })
    loader.run(env, "Carbonite/Data/Shared/NxMapGuide.lua")
    return env.Nx.Map.Guide
end

describe("quem dá quests: só disponíveis", function()
    it("quest que o personagem pode pegar agora aparece", function()
        expect(guide():QuestGiverAvailable(100, 10, 20)).toBe(true)
    end)

    it("some a concluída, a que está no registro, a bloqueada e a de nível mínimo acima", function()
        expect(guide({ done = { [100] = true } }):QuestGiverAvailable(100, 10, 20)).toBe(false)
        expect(guide({ inLog = { [100] = 1 } }):QuestGiverAvailable(100, 10, 20)).toBe(false)
        expect(guide({ locked = { [100] = true } }):QuestGiverAvailable(100, 10, 20)).toBe(false)
        expect(guide():QuestGiverAvailable(100, 25, 20)).toBe(false)
    end)

    it("diária feita antes continua disponível", function()
        expect(guide({ done = { [100] = true }, freq = { [100] = 1 } }):QuestGiverAvailable(100, 10, 20)).toBe(true)
    end)

    it("o mapa usa o filtro, ligado por padrão, com escolha no menu Mostrar", function()
        local src = loader.read("Carbonite/Data/Shared/NxMapGuide.lua")
        expect(src:find("not onlyAvailable or self:QuestGiverAvailable (qId, minlvl, playerLevel)", 1, true) ~= nil).toBe(true)
        expect(loader.read("Carbonite/Modules/PlayerCharacter/Defaults.lua"):find("QuestGiversAvailable = true", 1, true) ~= nil).toBe(true)
        expect(loader.read("Carbonite/Modules/Map/MapEngine.lua"):find('L["Quest Givers: Only Available Quests"]', 1, true) ~= nil).toBe(true)
    end)
end)
