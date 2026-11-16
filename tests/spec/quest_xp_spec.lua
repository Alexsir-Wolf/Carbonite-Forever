-- Quest XP from QuestieDB with the game's cut by level difference (#74)

local function load(level, maxLevel, db)
    local env = wow.lenientEnv()
    env.UnitLevel = function() return level end
    env.GetMaxPlayerLevel = function() return maxLevel end
    env.BreakUpLargeNumbers = function(n) return tostring(n) end
    env.LibQuestieDB = { Support = { Get = function(name) return name == "QuestXP" and { db = db } or nil end } }
    env.Nx = wow.namespace({ Quest = wow.namespace() })
    loader.run(env, "Carbonite.Quests/QuestieSource.lua")
    return env.Nx.Quest
end

describe("XP das quests", function()
    local QS = load(1, 60, {}).QuestieSource

    it("dá a XP cheia até 5 níveis acima da quest", function()
        expect(QS.XPAt(20, 1650, 20)).toBe(1650)
        expect(QS.XPAt(20, 1650, 25)).toBe(1650)
    end)

    it("corta 20% por nível do sexto ao nono e deixa 10% depois", function()
        expect(QS.XPAt(20, 1650, 26)).toBe(1300)   -- 1320 arredondado de 50 em 50
        expect(QS.XPAt(20, 1650, 29)).toBe(330)    -- 20% de 1650, já múltiplo de 10
        expect(QS.XPAt(20, 1650, 35)).toBe(170)    -- 165 arredondado para cima, de 10 em 10
    end)

    it("arredonda pequenas quantias de 5 em 5", function()
        expect(QS.XPAt(5, 110, 12)).toBe(65)
    end)

    it("lê o QuestXP do QuestieDB e some no nível máximo", function()
        local Quest = load(20, 60, { [2] = { 20, 2450 } })
        expect(Quest:GetXP(2)).toBe(2450)
        expect(Quest:GetXP(3)).toBeNil()
        expect(Quest:XPText(2):find("2450", 1, true) ~= nil).toBe(true)
        expect(load(60, 60, { [2] = { 20, 2450 } }):GetXP(2)).toBeNil()
    end)

    it("sem a tabela no QuestieDB, usa a que o módulo QuestXP do Questie guardou", function()
        local env = wow.lenientEnv()
        env.UnitLevel = function() return 26 end
        env.GetMaxPlayerLevel = function() return 60 end
        env.BreakUpLargeNumbers = function(n) return tostring(n) end
        env.LibQuestieDB = { Support = { Get = function() return nil end } }
        env.QuestieLoader = { ImportModule = function(_, name)
            return name == "QuestXP" and { db = { [2] = { 30, 2450 } } } or nil
        end }
        env.Nx = wow.namespace({ Quest = wow.namespace() })
        loader.run(env, "Carbonite.Quests/QuestieSource.lua")
        expect(env.Nx.Quest:GetXP(2)).toBe(2450)
    end)
end)

describe("XP no diário", function()
    it("quest sem etiqueta (tag nil) não quebra a lista", function()
        local src = loader.read("Carbonite.Quests/QuestWindow.lua")
        expect(src:find('list:ItemSet (4, (tag or "") .. Quest:XPText (qId))', 1, true) ~= nil).toBe(true)
    end)
end)
