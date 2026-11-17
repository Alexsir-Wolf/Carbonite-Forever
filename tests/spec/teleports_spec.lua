-- Hearthstone and mage teleports in the route (#37): Carbonite/Modules/Travel/Teleports.lua

local function setup(opts)
    opts = opts or {}
    local items = opts.items or { [6948] = 1 }
    local frames = {}
    local env = wow.env({
        GetTime = function() return opts.time and opts.time() or 100 end,
        GetBindLocation = function() return opts.bind == nil and "Thelsamar" or opts.bind end,
        C_Item = { GetItemCount = function(id) return items[id] or 0 end },
        GetItemCooldown = function() return opts.cooldown or 0, opts.cooldown and 3600 or 0 end,
        IsSpellKnown = function(id) return opts.spells and opts.spells[id] or false end,
        UnitFactionGroup = function() return "Alliance" end,
    })
    env.CreateFrame = function(_, name)
        local f = wow.frame(name)
        frames[#frames + 1] = f
        return f
    end
    -- One continent per map id range: 1400s = 1, 1900s = 2.
    local m1 = {
        PlyrX = 5, PlyrY = 6,
        GetDisplayableMapForPlayer = function() return 1432 end,
    }
    env.Nx = {
        db = { char = opts.char or {}, profile = { Map = opts.mapOpts or {} } },
        Travel = { Speed = .5, GetRidingSkill = function() return 0 end },
        GuideData = { Innkeeper = opts.guide or {} },
        Map = {
            MapWorldInfo = opts.worldInfo or { [1432] = { Name = "Loch Modan" } },
            GetWorldPos = function(_, mapId, x, y) return mapId + x, y end,
            IdToContZone = function(_, mapId) return mapId >= 1900 and 2 or 1 end,
            GetMap = function() return m1 end,
        },
    }
    loader.run(env, "Carbonite/Modules/Travel/Teleports.lua")
    return env.Carbonite.Modules.Travel.Teleports, env, frames
end

local function straightPath(calls)
    return function()
        calls[#calls + 1] = true    -- adds no waypoint: a straight leg
    end
end

describe("Teleports: lugar da pedra", function()
    it("usa o lugar salvo quando o nome ainda é o da pedra", function()
        local tp = setup({ char = { Travel = { Bind = { Name = "Thelsamar", MapId = 1432, X = 1, Y = 2 } } } })
        expect(tp:BindLocation().X).toBe(1)
    end)

    it("ignora o salvo de outro lugar e cai no estalajadeiro único da zona", function()
        local tp = setup({
            char = { Travel = { Bind = { Name = "Goldshire", MapId = 1429, X = 1, Y = 2 } } },
            worldInfo = { [1432] = { Name = "Thelsamar" } },
            guide = { [1432] = "1,35.5,48.4|2,10,10" },
        })
        local bind = tp:BindLocation()
        expect(bind.MapId).toBe(1432)
        expect(bind.X).toBe(1432 + 35.5)
    end)

    it("dois estalajadeiros da facção: lugar desconhecido", function()
        local tp = setup({
            worldInfo = { [1432] = { Name = "Thelsamar" } },
            guide = { [1432] = "1,35.5,48.4|0,10,10" },
        })
        expect(tp:BindLocation()).toBeNil()
    end)

    it("HEARTHSTONE_BOUND grava onde o jogador está", function()
        local tp, env, frames = setup()
        expect(frames[1].events.HEARTHSTONE_BOUND).toBe(true)
        frames[1].scripts.OnEvent(frames[1], "HEARTHSTONE_BOUND")
        local bind = env.Nx.db.char.Travel.Bind
        expect(bind.Name).toBe("Thelsamar")
        expect(bind.MapId).toBe(1432)
        expect(bind.X).toBe(5)
        expect(tp:BindLocation()).toBe(bind)
    end)
end)

describe("Teleports: o que está pronto", function()
    local saved = { Travel = { Bind = { Name = "Thelsamar", MapId = 1432, X = 1, Y = 2 } } }

    it("pedra na bolsa, pronta e com lugar", function()
        local tp = setup({ char = saved })
        local ready = tp:Ready()
        expect(#ready).toBe(1)
        expect(ready[1].Name).toBe("Use Hearthstone (Thelsamar)")
    end)

    it("pedra em recarga ou fora da bolsa não conta", function()
        expect(#setup({ char = saved, cooldown = 90 }):Ready()).toBe(0)
        expect(#setup({ char = saved, items = {} }):Ready()).toBe(0)
    end)

    it("teleporte de mago só com o feitiço e a runa", function()
        expect(#setup({ items = { [17031] = 1 }, spells = {} }):Ready()).toBe(0)
        expect(#setup({ items = {}, spells = { [3561] = true } }):Ready()).toBe(0)
        local ready = setup({ items = { [17031] = 1 }, spells = { [3561] = true } }):Ready()
        expect(#ready).toBe(1)
        expect(ready[1].MapId).toBe(1453)
    end)
end)

describe("Teleports: custo", function()
    it("a pé conta a distância, o voo conta distância x Speed e trocar de continente conta o barco", function()
        local tp = setup()
        expect(tp:Cost(1432, 0, 0, { { MapId = 1432, TargetMX = 30, TargetMY = 40 } })).toBe(50)
        expect(tp:Cost(1432, 0, 0, { { MapId = 1432, TargetMX = 30, TargetMY = 40, Mode = "F" } })).toBe(25)
        local boat = tp:Cost(1432, 0, 0, { { MapId = 1950, TargetMX = 30, TargetMY = 40 } })
        expect(math.abs(boat - tp:SecondsToUnits(120)) < 1e-9).toBe(true)
    end)
end)

describe("Teleports: escolha", function()
    local saved = { Travel = { Bind = { Name = "Thelsamar", MapId = 1432, X = 990, Y = 0 } } }

    it("começa pela pedra quando ela chega bem antes", function()
        local calls = {}
        local tp = setup({ char = saved })
        local plan = tp:Plan(straightPath(calls), 1432, 0, 0, 1432, 1000, 0, "Goto")
        expect(#plan).toBe(2)
        expect(plan[1].TargetMX).toBe(0)                 -- use it here
        expect(plan[1].TargetName).toBe("Use Hearthstone (Thelsamar)")
        expect(plan[2].Mode).toBe("T")                   -- the jump
        expect(plan[2].TargetMX).toBe(990)
    end)

    it("destino perto: a rota não muda", function()
        local tp = setup({ char = saved })
        expect(tp:Plan(straightPath({}), 1432, 0, 0, 1432, 100, 0, "Goto")).toBeNil()
    end)

    it("economia menor que a folga: a rota não muda", function()
        local tp = setup({ char = saved })
        -- Direct 60, via the stone ~38 + 50: never worth it.
        expect(tp:Plan(straightPath({}), 1432, 940, 0, 1432, 1000, 0, "Goto")).toBeNil()
    end)

    it("opção desligada: a rota não muda", function()
        local tp = setup({ char = saved, mapOpts = { RouteTeleports = false } })
        expect(tp:Plan(straightPath({}), 1432, 0, 0, 1432, 1000, 0, "Goto")).toBeNil()
    end)

    it("guarda a escolha por alguns segundos", function()
        local t = 100
        local calls = {}
        local tp = setup({ char = saved, time = function() return t end })
        tp:Plan(straightPath(calls), 1432, 0, 0, 1432, 1000, 0, "Goto")
        local first = #calls                 -- direct + via stone + final route
        tp:Plan(straightPath(calls), 1432, 0, 0, 1432, 1000, 0, "Goto")
        expect(#calls - first).toBe(1)       -- only the final route again
        t = 110
        tp:Plan(straightPath(calls), 1432, 0, 0, 1432, 1000, 0, "Goto")
        expect(#calls - first - 1).toBe(first)
    end)
end)

describe("Teleports: integração", function()
    local engine = loader.read("Carbonite/Modules/Map/MapEngine.lua")

    it("a rota passa pela escolha e o salto não desenha linha", function()
        expect(engine:find("Teleports:Plan(", 1, true) ~= nil).toBe(true)
        expect(engine:find('if mode == "T" then', 1, true) ~= nil).toBe(true)
    end)

    it("cada entrada do MakePath sabe o mapa dela", function()
        local travel = loader.read("Carbonite/Modules/Travel/TravelEngine.lua")
        local _, n = travel:gsub("t1%.MapId = node1%.MapId", "")
        expect(n).toBe(2)
    end)

    it("módulo na carga e textos em pt-BR", function()
        expect(loader.read("Carbonite/Modules/Modules.xml"):find("Travel\\Teleports.lua", 1, true) ~= nil).toBe(true)
        local pt = loader.read("Carbonite/Locales/ptBR/Main.lua")
        expect(pt:find('L["Use Hearthstone (%s)"] = "Usar Pedra de Regresso (%s)"', 1, true) ~= nil).toBe(true)
    end)
end)
