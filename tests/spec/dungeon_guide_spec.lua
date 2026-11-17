-- Carbonite/Modules/Map/DungeonGuide.lua e DungeonChart.lua: rota dos chefes (#103)

local PINS = {
    instances = {
        [36] = { name = "The Deadmines", floors = { { key = "291", map = 291 }, { key = "292", map = 292, label = "Ironclad Cove" } } },
    },
    pins = {
        ["291"] = {
            { "entrance", 0.1, 0.1 },
            { "level", 0.9, 0.9, "292" },
            { "boss", 0.8, 0.8, 3 },
            { "boss", 0.2, 0.2, 1 },
            { "boss", 0.5, 0.5, 2 },
            { "boss", 0.52, 0.52, 22 },
        },
        ["292"] = {
            { "level", 0.1, 0.9, "291", true },
            { "boss", 0.9, 0.1, 5 },
            { "boss", 0.2, 0.8, 4 },
        },
    },
    bosses = { [1] = "Rhahk'Zor <The Foreman>", [2] = "Sneed's Shredder / Sneed", [22] = "Sneed's Shredder / Sneed",
        [3] = "Gilnid", [4] = "Mr. Smite", [5] = "Edwin VanCleef" },
    quests = {},
    heights = { ["292"] = 700 },
}

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
    env.Nx = { DungeonPins = PINS, db = { char = opts.char or {} }, Map = { Maps = {} } }
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
    env.Nx = { DungeonPins = pins or PINS, db = { char = {}, profile = { Map = {} } }, Map = { Maps = { map } } }
    loader.run(env, "Carbonite/Modules/Map/DungeonGuide.lua")
    loader.run(env, "Carbonite/Modules/Map/DungeonChart.lua")
    return env.Nx.DungeonChart, env.Nx.DungeonGuide
end

describe("DungeonChart: planta do MapUtils e rota", function()
    it("monta andares, entradas, ligações e chefes no formato do DungeonJournal", function()
        local DC = loadChart({})
        local data = DC.PinMap(PINS.instances[36], PINS.pins, PINS.heights)
        expect(#data.floors).toBe(2)
        expect(data.floors[1].texture).toBe("Interface\\AddOns\\MapUtils\\media\\291")
        expect(data.floors[1].texBottom).toBe(683 / 1024)
        expect(data.floors[2].texBottom).toBe(700 / 1024)
        expect(data.floors[2].label).toBe("Ironclad Cove")
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
        DC.Here = { mu = "The Deadmines" }
        map.max = false
        expect(DC:Current("mu")).toBeNil()
        map.max = true
        expect(DC:Current("mu")).toBe("The Deadmines")
        DC:Close()
        expect(DC:Current("mu")).toBeNil()
    end)
end)
