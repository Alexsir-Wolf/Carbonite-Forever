-- Carbonite/Modules/Map/DungeonGuide.lua e DungeonChart.lua: rota dos chefes (#103)

local PINS = {
    instances = {
        [36] = { floors = { { key = "291", map = 291 }, { key = "292", map = 292, named = true } } },
    },
    pins = {
        ["291"] = {
            { "entrance", 0.1, 0.1 },
            { "level", 0.9, 0.9, "292" },
            { "boss", 0.8, 0.8, 3 },
            { "boss", 0.2, 0.2, 1 },
            { "boss", 0.5, 0.5, 2, 22 },
            { "questend", 0.3, 0.3, 100 },
            { "queststart", 0.3, 0.3, 101 },
            { "item", 0.4, 0.4, 900 },
            { "item", 0.45, 0.45, 900 },
        },
        ["292"] = {
            { "level", 0.1, 0.9, "291", true },
            { "boss", 0.9, 0.1, 5 },
            { "boss", 0.2, 0.8, 4 },
        },
    },
    heights = { ["292"] = 700 },
}

-- Carbonite/Locales/<locale>/Dungeons.lua: names the client does not give.
local NAMES = {
    ["boss:1"] = "Rhahk'Zor <The Foreman>", ["boss:2"] = "Sneed's Shredder / Sneed", ["boss:3"] = "Gilnid",
    ["boss:4"] = "Mr. Smite", ["boss:5"] = "Edwin VanCleef", ["quest:100"] = "Old Quest",
    ["quest:101"] = "Next Quest", ["object:900"] = "Crest", ["floor:292"] = "Enseada Couraçada",
    ["dungeon:36"] = "Minas Mortas (reserva)",
}

local function withNames(env)
    local locale = setmetatable({}, { __index = function(_, k) return NAMES[k] or k end })
    env.LibStub = function()
        return setmetatable({ GetLocale = function() return locale end }, { __index = function() return wow.anything() end })
    end
    return env
end

local function load(opts)
    opts = opts or {}
    local env = wow.env({
        GetTime = function() return opts.time or 1 end,
        IsInInstance = function() return opts.inside ~= false end,
        GetInstanceInfo = function() return "Minas Mortas", "party", 1, "", 5, 0, false, opts.id or 36 end,
        EJ_GetInstanceForMap = opts.ej and function() return 63 end,
        EJ_SelectInstance = opts.ej and function() end,
        EJ_GetEncounterInfoByIndex = opts.ej and function(i) return opts.ej[i] end,
    })
    withNames(env)
    env.Nx = { DungeonPins = PINS, db = { char = opts.char or {} }, Map = { Maps = {} }, Quest = opts.quest }
    env.GetNumQuestLeaderBoards = opts.boards and function(qi) return #opts.boards[qi] end
    env.GetQuestLogLeaderBoard = opts.boards and function(i, qi) return opts.boards[qi][i][1], "monster", opts.boards[qi][i][2] end
    loader.run(env, "Carbonite/Modules/Map/DungeonGuide.lua")
    return env.Nx.DungeonGuide, env
end

local function names(list)
    local out = {}
    for i, b in ipairs(list) do out[i] = b.name end
    return table.concat(out, ", ")
end

describe("DungeonGuide: ordem da rota", function()
    it("percorre os chefes do mais perto da entrada, andar por andar, sem repetir", function()
        local DG = load()
        expect(names(DG:Bosses())).toBe("Rhahk'Zor <The Foreman>, Sneed's Shredder / Sneed, Gilnid, Mr. Smite, Edwin VanCleef")
        local list = DG:Bosses()
        expect(list[4].floor).toBe(2)
        expect(list[1].npc).toBe(1)
    end)

    it("sem ponto de partida mantém a ordem dos dados", function()
        local DG = load()
        local order = DG.RouteOrder({ { x = .9, y = .9 }, { x = .1, y = .1 }, { x = .8, y = .8 } })
        expect(table.concat(order, ",")).toBe("1,3,2")
    end)

    it("usa a lista da planta quando ela mostra esta masmorra", function()
        local DG = load()
        DG:SetChartBosses(36, { { name = "A", floor = 1 }, { name = "B", floor = 1, killed = true } })
        local list = DG:Bosses()
        expect(names(list)).toBe("A, B")
        expect(list[2].killed).toBe(true)
        expect(DG.NextBoss(list)).toBe(1)
    end)

    it("usa o Encounter Journal do cliente quando existe", function()
        local DG = load({ ej = { "Primeiro", "Segundo" } })
        expect(names(DG:Bosses())).toBe("Primeiro, Segundo")
    end)

    it("fora de instância não há chefes nem painel", function()
        local DG = load({ inside = false })
        expect(#DG:Bosses()).toBe(0)
        expect(DG:PanelWidth(1000)).toBe(0)
    end)
end)

describe("DungeonGuide: chefes mortos", function()
    it("marca pelo id do NPC no log de combate e destaca o próximo", function()
        local DG = load()
        DG:OnCombatLog("UNIT_DIED", "Creature-0-1-36-1-1-0000ABCD", "Rhahk'Zor")
        DG:OnCombatLog("UNIT_DIED", "Creature-0-1-36-1-999-0000ABCD", "Lacaio")
        local list = DG:Bosses()
        expect(list[1].killed).toBe(true)
        expect(DG.NextBoss(list)).toBe(2)
        expect(DG:IsKilled("Lacaio", 999)).toBe(false)
    end)

    it("reconhece o nome sem o título e qualquer das partes de 'A / B'", function()
        local DG = load()
        DG:NoteKill("Sneed's Shredder")
        expect(DG:IsKilled("Sneed's Shredder / Sneed")).toBe(false)
        DG:NoteKill("Sneed")
        expect(DG:IsKilled("Sneed's Shredder / Sneed")).toBe(true)
        DG:NoteKill("Rhahk'Zor")
        expect(DG:IsKilled("Rhahk'Zor <The Foreman>")).toBe(true)
    end)

    it("guarda no personagem: mantém no /reload e zera ao entrar de novo", function()
        local char = {}
        local DG = load({ char = char })
        DG.WasInside = false
        DG:OnEnterWorld(false, false)
        DG:NoteKill("Gilnid", 3)
        DG:OnEnterWorld(false, true)
        expect(DG:IsKilled("Gilnid", 3)).toBe(true)
        DG.WasInside = false
        DG:OnEnterWorld(false, false)
        expect(DG:IsKilled("Gilnid", 3)).toBe(false)
        expect(char.DungeonKills.id).toBe(36)
    end)

    it("o painel lista os mortos em cinza e o próximo em verde", function()
        local DG = load()
        DG:NoteKill(nil, 1)
        local text = table.concat(DG:Lines(), "\n")
        expect(text:find("|cff8080801. Rhahk'Zor <The Foreman>|r", 1, true) ~= nil).toBe(true)
        expect(text:find("|cff40ff402. Sneed's Shredder / Sneed  (next)|r", 1, true) ~= nil).toBe(true)
        expect(text:find("3. Gilnid", 1, true) ~= nil).toBe(true)
    end)
end)

local function loadChart(map, pins)
    local env = wow.env({
        GetTime = function() return 1 end,
        IsInInstance = function() return true end,
        GetInstanceInfo = function() return "Minas Mortas", "party", 1, "", 5, 0, false, 36 end,
    })
    withNames(env)
    env.Nx = { DungeonPins = pins or PINS, db = { char = {}, profile = { Map = {} } }, Map = { Maps = { map } } }
    loader.run(env, "Carbonite/Modules/Map/DungeonGuide.lua")
    loader.run(env, "Carbonite/Modules/Map/DungeonChart.lua")
    return env.Nx.DungeonChart, env.Nx.DungeonGuide
end

describe("DungeonChart: planta do MapUtils e rota", function()
    it("monta andares, entradas, ligações e chefes no formato do DungeonJournal", function()
        local DC = loadChart({})
        local data = DC.PinMap(PINS.instances[36], PINS.pins, PINS.heights, 36)
        expect(#data.floors).toBe(2)
        expect(data.floors[1].texture).toBe("Interface\\AddOns\\MapUtils\\media\\291")
        expect(data.floors[1].texBottom).toBe(683 / 1024)
        expect(data.floors[2].texBottom).toBe(700 / 1024)
        expect(data.id).toBe(36)
        expect(data.floors[2].named).toBe(true)
        expect(#data.entrances).toBe(1)
        expect(data.transitions[1].to).toBe(2)
        expect(data.transitions[2].to).toBe(1)
        expect(#data.bosses).toBe(5)
    end)

    it("destaca o trecho até o próximo chefe vivo e apaga os já feitos", function()
        local DC = loadChart({})
        local data = { entrance = { floor = 1, x = 0, y = 0 } }
        local bosses = {
            { name = "A", floor = 1, x = .1, y = .1, killed = true },
            { name = "B", floor = 1, x = .2, y = .2 },
            { name = "C", floor = 2, x = .3, y = .3 },
            { name = "D", floor = 1, x = .4, y = .4 },
        }
        local legs = DC.RouteLegs(data, bosses, 1)
        expect(#legs).toBe(3)
        expect(legs[1].state).toBe("done")
        expect(legs[2].state).toBe("next")
        expect(legs[3].state).toBe("ahead")
        expect(legs[3].x1).toBe(.2)
    end)

    it("na instância sem mapa abre sozinha só com a janela maximizada", function()
        local map = { UInstViewActive = true, IsWindowMaximized = function(self) return self.max end }
        local DC = loadChart(map)
        DC.Here = { mu = 36 }
        map.max = false
        expect(DC:Current("mu")).toBeNil()
        map.max = true
        expect(DC:Current("mu")).toBe(36)
        DC:Close()
        expect(DC:Current("mu")).toBeNil()
    end)
end)

local function quests()
    local cur = {
        { QId = 100, QI = 1, Title = "Velha Quest", Header = "Elwynn" },
        { QId = 200, QI = 2, Title = "Na Masmorra", Header = "Minas Mortas", Complete = 1 },
        { QId = 300, QI = 3, Title = "Objetivo Dentro", Header = "Westfall", Q = { Objectives = { { "Gilnid|291|32|50|50" } } } },
        { QId = 400, QI = 4, Title = "Fora", Header = "Westfall", Q = { Objectives = { "Bandido|1436|32|50|50" } } },
    }
    local ids = {}
    for _, c in ipairs(cur) do ids[c.QId] = c end
    return { CurQ = cur, IdToCurQ = ids }
end

describe("DungeonGuide: quests e itens da masmorra (#83)", function()
    it("acha as quests do registro pelo cabeçalho, pelos pinos do MapUtils e pelos objetivos", function()
        local DG = load({ quest = quests(), boards = { [1] = { { "Satchel: 0/1", false } }, [2] = {}, [3] = { { "Gilnid morto", true } } } })
        local list = DG:LogQuests()
        local titles = {}
        for i, q in ipairs(list) do titles[i] = q.title end
        expect(table.concat(titles, ", ")).toBe("Velha Quest, Na Masmorra, Objetivo Dentro")
        expect(list[1].objectives[1].text).toBe("Satchel: 0/1")
        expect(list[2].complete).toBe(true)
        expect(list[3].objectives[1].done).toBe(true)
    end)

    it("na planta: entrega de quest do registro, início de quest não pega e itens", function()
        local DG = load({ quest = quests() })
        local pins = DG:FloorPins("291")
        expect(#pins).toBe(4)
        expect(pins[1].kind).toBe("turnin")
        expect(pins[1].tip).toBe("Turn in: Velha Quest")
        expect(pins[2].kind).toBe("start")
        expect(pins[2].tip).toBe("Starts quest: Next Quest")
        expect(pins[3].tip).toBe("Quest item: Crest")
    end)

    it("não marca a entrega de quest fora do registro nem o início de quest feita", function()
        local q = quests()
        q.IdToCurQ[100] = nil
        q.CurCharacter = { Q = {} }
        q.GetQuest = function(_, id) if id == 101 then return "C" end end
        local DG = load({ quest = q })
        local pins = DG:FloorPins("291")
        expect(#pins).toBe(2)
        expect(pins[1].kind).toBe("item")
    end)

    it("o painel lista as quests, os objetivos e os itens de quest", function()
        local DG = load({ quest = quests(), boards = { [1] = { { "Satchel: 0/1", false } }, [2] = {}, [3] = {} } })
        local text = table.concat(DG:Lines(), "\n")
        expect(text:find("Quests in this dungeon", 1, true) ~= nil).toBe(true)
        expect(text:find("\nVelha Quest\n  - Satchel: 0/1", 1, true) ~= nil).toBe(true)
        expect(text:find("|cff40ff40Na Masmorra (complete)|r", 1, true) ~= nil).toBe(true)
        expect(text:find("Quest items here: Crest (2)", 1, true) ~= nil).toBe(true)
    end)

    it("a planta do DungeonJournal usa os pinos do mesmo mapa do jogo", function()
        local DC = loadChart({})
        expect(DC.PinKey({ floors = { { uiMapID = 291 } } }, 1)).toBe("291")
        expect(DC.PinKey({ floors = { { key = "292" } } }, 1)).toBe("292")
        local here = { data = PINS.instances[36] }
        expect(DC.PinKey({ floors = { { texture = "a" }, { texture = "b" } } }, 2, here)).toBe("292")
        expect(DC.PinKey({ floors = { { texture = "a" } } }, 1, here)).toBeNil()
    end)
end)

describe("DungeonGuide: nomes do cliente, com o AceLocale como reserva", function()
    it("usa o nome do chefe que o cliente mostrou e o guarda no personagem", function()
        local char = {}
        local DG = load({ char = char })
        expect(DG.BossName(1)).toBe("Rhahk'Zor <The Foreman>")
        DG:LearnName("Creature-0-1-36-1-1-0000ABCD", "Rhahk'Zor, o Capataz")
        DG:LearnName("Creature-0-1-36-1-999-0000ABCD", "Lacaio")
        expect(DG.BossName(1)).toBe("Rhahk'Zor, o Capataz")
        expect(char.DungeonNames[999]).toBeNil()
        expect(DG:Bosses()[1].name).toBe("Rhahk'Zor, o Capataz")
    end)

    it("nome da masmorra: o do cliente, senão o da tradução", function()
        local DG, env = load()
        expect(DG.InstanceName(36)).toBe("Minas Mortas")
        env.GetRealZoneText = function(id) return id == 48 and "Profundezas Negras" or "" end
        expect(DG.InstanceName(48)).toBe("Profundezas Negras")
        expect(DG.InstanceName(999)).toBe("999")
    end)

    it("nome do andar: o grupo de mapas do cliente, senão a tradução; andar sem nome fica numerado", function()
        local DG, env = load()
        expect(DG.FloorName({ key = "292", map = 292, named = true })).toBe("Enseada Couraçada")
        expect(DG.FloorName({ key = "291", map = 291 })).toBeNil()
        env.C_Map = {
            GetMapGroupID = function() return 7 end,
            GetMapGroupMembersInfo = function() return { { mapID = 291, name = "Minas" }, { mapID = 292, name = "Enseada do Cliente" } } end,
        }
        expect(DG.FloorName({ key = "292", map = 292, named = true })).toBe("Enseada do Cliente")
    end)
end)

describe("DungeonGuide: valores secretos do cliente", function()
    -- The Forever client hands some GUIDs and names as secret values: reading them raises an error.
    local SECRET_GUID = "Creature-0-1-36-1-1-0000ABCD"

    local function loadSecret()
        local DG, env = load()
        env.issecretvalue = function(v) return v == SECRET_GUID or v == "Segredo" end
        return DG
    end

    it("GUID secreto não é lido nem marca chefe", function()
        local DG = loadSecret()
        expect(DG.NpcID(SECRET_GUID)).toBeNil()
        expect(function() DG:LearnName(SECRET_GUID, "Rhahk'Zor") end).toNotThrow()
        DG:OnCombatLog("UNIT_DIED", SECRET_GUID, "Segredo")
        expect(DG:Bosses()[1].killed).toBeFalsy()
    end)

    it("nome secreto é ignorado e o id do NPC ainda vale", function()
        local DG = loadSecret()
        DG:OnCombatLog("UNIT_DIED", "Creature-0-1-36-1-1-0000ABCE", "Segredo")
        expect(DG:Bosses()[1].killed).toBe(true)
    end)
end)
