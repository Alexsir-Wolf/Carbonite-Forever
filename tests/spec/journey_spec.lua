-- Carbonite/Modules/Journey/Journey.lua: diário da jornada do personagem (#69)

local function load(over)
    local game = {
        clock = 1000, zone = "Elwynn Forest", sub = "Goldshire", level = 5,
        inInstance = false, instType = "none", instName = "",
        questID = 0, title = "", logIndex = 0, logTitle = nil, logLevel = nil,
    }
    for k, v in pairs(over or {}) do game[k] = v end
    local env = wow.lenientEnv({
        time = function() return game.clock end,
        date = function(fmt, t) return fmt .. "@" .. tostring(t) end,
        GetRealZoneText = function() return game.zone end,
        GetSubZoneText = function() return game.sub end,
        UnitLevel = function() return game.level end,
        IsInInstance = function() return game.inInstance, game.instType end,
        GetInstanceInfo = function() return game.instName end,
        GetQuestID = function() return game.questID end,
        GetTitleText = function() return game.title end,
        GetQuestLogIndexByID = function() return game.logIndex end,
        GetQuestLogTitle = function() return game.logTitle, game.logLevel end,
        C_QuestLog = {},
    })
    env.Nx = { db = { char = {}, profile = { General = {} } }, SearchBox = wow.searchBox() }
    loader.run(env, "Carbonite/Modules/Journey/Journey.lua")
    local J = env.Carbonite.Modules.Journey
    local function fire(event, ...)
        J.frame.scripts.OnEvent(J.frame, event, ...)
    end
    return J, game, fire, env
end

local function entries(J)
    return J:Store().entries
end

describe("Jornada: registro", function()
    it("escuta os eventos do cliente", function()
        local J = load()
        for _, ev in ipairs({ "PLAYER_LEVEL_UP", "QUEST_TURNED_IN", "PLAYER_DEAD", "ZONE_CHANGED_NEW_AREA" }) do
            expect(J.frame.events[ev]).toBe(true)
        end
    end)

    it("subida de nível com data, zona e nível", function()
        local J, _, fire = load()
        fire("PLAYER_LEVEL_UP", 6)
        local e = entries(J)[1]
        expect(e.k).toBe("level")
        expect(e.t).toBe(1000)
        expect(e.z).toBe("Elwynn Forest")
        expect(e.l).toBe(6)
        expect(J:Describe(e)).toBe("Reached level 6")
    end)

    it("quest concluída com nome e nível lidos na janela de recompensa", function()
        local J, game, fire = load({ questID = 33, title = "Wolves Across the Border", logIndex = 4,
                                     logTitle = "Wolves Across the Border", logLevel = 2 })
        fire("QUEST_COMPLETE")
        game.logIndex = 0
        fire("QUEST_TURNED_IN", 33, 250, 0)
        local e = entries(J)[1]
        expect(e.k).toBe("quest")
        expect(e.n).toBe("Wolves Across the Border")
        expect(e.q).toBe(2)
        expect(J:Describe(e)).toBe("Quest completed: [2] Wolves Across the Border")
    end)

    it("quest entregue sem janela de recompensa usa o id", function()
        local J, _, fire = load()
        fire("QUEST_TURNED_IN", 77)
        expect(entries(J)[1].n).toBe("#77")
        expect(J:Describe(entries(J)[1])).toBe("Quest completed: #77")
    end)

    it("primeira visita a uma zona só uma vez", function()
        local J, game, fire = load()
        fire("PLAYER_ENTERING_WORLD")
        fire("ZONE_CHANGED_NEW_AREA")
        game.zone = "Westfall"
        fire("ZONE_CHANGED_NEW_AREA")
        game.zone = "Elwynn Forest"
        fire("ZONE_CHANGED_NEW_AREA")
        local list = entries(J)
        expect(#list).toBe(2)
        expect(J:Describe(list[1])).toBe("First visit: Elwynn Forest")
        expect(list[2].z).toBe("Westfall")
    end)

    it("morte com zona e subzona", function()
        local J, _, fire = load()
        fire("PLAYER_DEAD")
        local e = entries(J)[1]
        expect(e.k).toBe("death")
        expect(J:Describe(e)).toBe("Died in Elwynn Forest, Goldshire")
    end)

    it("masmorra: entrada uma vez e chefe derrotado", function()
        local J, game, fire = load({ inInstance = true, instType = "party", instName = "The Deadmines",
                                     zone = "The Deadmines" })
        fire("PLAYER_ENTERING_WORLD")
        fire("ZONE_CHANGED_NEW_AREA")   -- reload dentro da masmorra
        fire("ENCOUNTER_END", 1, "Edwin VanCleef", 1, 5, 0)   -- wipe
        fire("ENCOUNTER_END", 1, "Edwin VanCleef", 1, 5, 1)
        local list = entries(J)
        expect(#list).toBe(2)
        expect(J:Describe(list[1])).toBe("Entered The Deadmines")
        expect(J:Describe(list[2])).toBe("Defeated Edwin VanCleef")
        -- Sai e volta: nova entrada; a masmorra não conta como zona visitada.
        game.inInstance, game.instType, game.zone = false, "none", "Westfall"
        fire("ZONE_CHANGED_NEW_AREA")
        game.inInstance, game.instType, game.zone = true, "party", "The Deadmines"
        fire("ZONE_CHANGED_NEW_AREA")
        list = entries(J)
        expect(#list).toBe(4)
        expect(list[3].k).toBe("zone")
        expect(list[4].k).toBe("dungeon")
    end)

    it("a opção desligada não grava nada", function()
        local J, _, fire, env = load()
        env.Nx.db.profile.General.JourneyRecord = false
        fire("PLAYER_LEVEL_UP", 6)
        fire("PLAYER_DEAD")
        fire("ZONE_CHANGED_NEW_AREA")
        expect(#entries(J)).toBe(0)
    end)

    it("guarda por personagem em Nx.db.char", function()
        local J, _, fire, env = load()
        fire("PLAYER_LEVEL_UP", 6)
        expect(env.Nx.db.char.Journey.entries[1].k).toBe("level")
        env.Nx.db.char = nil
        expect(J:Store()).toBeNil()
        fire("PLAYER_LEVEL_UP", 7)   -- antes do AceDB: ignora sem erro
    end)
end)

describe("Jornada: limite", function()
    it("mantém só as 500 mais recentes", function()
        local J, game = load()
        for i = 1, 520 do
            game.clock = i
            J:Add("level", { n = i })
        end
        local list = entries(J)
        expect(#list).toBe(500)
        expect(list[1].n).toBe(21)
        expect(list[500].n).toBe(520)
    end)
end)

describe("Jornada: filtro", function()
    local function sample()
        local J, game = load()
        game.clock = 1; J:Add("level", { n = 2, l = 2 })
        game.clock = 2; J:Add("quest", { n = "The Fargodeep Mine", q = 7 })
        game.clock = 3; game.zone = "Westfall"; J:Add("zone")
        game.clock = 4; J:Add("dungeon", { n = "The Deadmines" })
        game.clock = 5; J:Add("boss", { n = "Edwin VanCleef" })
        game.clock = 6; J:Add("death", { s = "Moonbrook" })
        return J, entries(J)
    end

    it("tudo, da mais nova para a mais antiga", function()
        local J, list = sample()
        local out = J:Filter(list, "all", "")
        expect(#out).toBe(6)
        expect(out[1].k).toBe("death")
        expect(out[6].k).toBe("level")
    end)

    it("por tipo; masmorras inclui chefes", function()
        local J, list = sample()
        expect(#J:Filter(list, "quest")).toBe(1)
        local dung = J:Filter(list, "dungeon")
        expect(#dung).toBe(2)
        expect(dung[1].k).toBe("boss")
        expect(#J:Filter(list, "death")).toBe(1)
    end)

    it("busca sem diferenciar maiúsculas, no texto e na zona", function()
        local J, list = sample()
        expect(#J:Filter(list, "all", "fargodeep")).toBe(1)
        expect(#J:Filter(list, "all", "WESTFALL")).toBe(4)
        expect(#J:Filter(list, "death", "westfall")).toBe(1)
        expect(#J:Filter(list, "quest", "westfall")).toBe(0)
        expect(#J:Filter(list, "all", "[7]")).toBe(1)
    end)
end)

describe("Jornada: acesso", function()
    it("/carb jornada e item no menu do botão do minimapa", function()
        expect(loader.read("Carbonite/Modules/Journey/Journey.lua"):find('Register("jornada"', 1, true) ~= nil).toBe(true)
        local mm = loader.read("Carbonite/Modules/Map/MinimapButtonEngine.lua")
        expect(mm:find('L["Show Journey"], self.Menu_OnShowJourney', 1, true) ~= nil).toBe(true)
        expect(loader.read("Carbonite/Modules/Modules.xml"):find('Journey\\Journey.lua', 1, true) ~= nil).toBe(true)
    end)
end)
