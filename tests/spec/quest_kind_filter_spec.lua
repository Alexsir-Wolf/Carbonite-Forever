-- Quest givers on the map: daily, repeatable and event quests can be hidden (#80)

local function quest(fields)
    local env = wow.lenientEnv()
    env.UnitLevel = function() return 30 end
    env.LibQuestieDB = {
        RequireContract = function() return true, true end,
        Support = { Get = function() return nil end },
        Quest = { GetAll = function(qId) return fields[qId] or {} end },
    }
    env.Nx = wow.namespace({ Quest = wow.namespace({ IdToCurQ = {} }) })
    function env.Nx.Quest:GetQuest() return nil end
    loader.run(env, "Carbonite.Quests/QuestieSource.lua")
    return env.Nx.Quest
end

local function guide(opts)
    opts = opts or {}
    local env = wow.lenientEnv()
    env.Nx = wow.namespace({
        Map = wow.namespace({ Guide = {} }),
        QuestFreq = opts.freq or {},
        db = { profile = { Map = opts.map or {} } },
        Quest = {
            QuestieQuestKind = function(_, qId) return (opts.kinds or {})[qId] end,
        },
    })
    loader.run(env, "Carbonite/Data/Shared/NxMapGuide.lua")
    return env.Nx.Map.Guide
end

describe("tipo de quest pelo QuestieDB", function()
    it("diária, semanal, repetível, de evento e comum", function()
        local q = quest({
            [1] = { 4096 },                 -- DAILY
            [2] = { 32768 + 8 },            -- WEEKLY + SHARABLE
            [3] = { 8, 1 },                 -- repetível
            [4] = { 4096, 1 + 2 },          -- diária que pede evento
            [5] = { 0, 0, -369 },           -- Solstício (QuestSort)
            [6] = { 4096, 1 },              -- diária, também repetível nos dados
            [7] = { 8, 0, 12 },             -- comum
        })
        expect(q:QuestieQuestKind(1)).toBe("daily")
        expect(q:QuestieQuestKind(2)).toBe("daily")
        expect(q:QuestieQuestKind(3)).toBe("repeatable")
        expect(q:QuestieQuestKind(4)).toBe("event")
        expect(q:QuestieQuestKind(5)).toBe("event")
        expect(q:QuestieQuestKind(6)).toBe("daily")
        expect(q:QuestieQuestKind(7)).toBe(nil)
        expect(q:QuestieQuestKind(999)).toBe(nil)
    end)
end)

describe("quem dá quests: filtro por tipo", function()
    it("tudo aparece com as opções ligadas ou sem valor salvo", function()
        local kinds = { [1] = "daily", [2] = "repeatable", [3] = "event" }
        local g = guide({ kinds = kinds })
        for qId = 1, 4 do expect(g:QuestGiverKindShown(qId)).toBe(true) end
    end)

    it("cada opção desligada esconde só o seu tipo", function()
        local kinds = { [1] = "daily", [2] = "repeatable", [3] = "event", [4] = nil }
        local g = guide({ kinds = kinds, map = { QuestGiversDaily = false } })
        expect(g:QuestGiverKindShown(1)).toBe(false)
        expect(g:QuestGiverKindShown(2)).toBe(true)
        expect(g:QuestGiverKindShown(4)).toBe(true)
        g = guide({ kinds = kinds, map = { QuestGiversRepeatable = false } })
        expect(g:QuestGiverKindShown(2)).toBe(false)
        expect(g:QuestGiverKindShown(1)).toBe(true)
        g = guide({ kinds = kinds, map = { QuestGiversEvent = false } })
        expect(g:QuestGiverKindShown(3)).toBe(false)
        expect(g:QuestGiverKindShown(4)).toBe(true)
    end)

    it("Nx.QuestFreq marca diária que o QuestieDB não conhece, mas não tira o evento", function()
        local g = guide({ freq = { [5] = "d", [3] = "d" }, kinds = { [3] = "event" },
            map = { QuestGiversDaily = false } })
        expect(g:QuestGiverKindShown(5)).toBe(false)
        expect(g:QuestGiverKindShown(3)).toBe(true)
    end)

    it("o mapa usa o filtro, com as opções ligadas por padrão no menu Mostrar", function()
        expect(loader.read("Carbonite/Data/Shared/NxMapGuide.lua"):find("and self:QuestGiverKindShown (qId) then", 1, true) ~= nil).toBe(true)
        local defaults = loader.read("Carbonite/Modules/PlayerCharacter/Defaults.lua")
        local menu = loader.read("Carbonite/Modules/Map/MapEngine.lua")
        for _, key in ipairs({ "Daily", "Repeatable", "Event" }) do
            expect(defaults:find("QuestGivers" .. key .. " = true", 1, true) ~= nil).toBe(true)
            expect(menu:find('"QuestGivers' .. key .. '"', 1, true) ~= nil).toBe(true)
        end
        for _, loc in ipairs({ "enUS", "ptBR" }) do
            local src = loader.read("Carbonite/Locales/" .. loc .. "/Map.lua")
            expect(src:find('L["Quest Givers: Event Quests"]', 1, true) ~= nil).toBe(true)
        end
    end)
end)
