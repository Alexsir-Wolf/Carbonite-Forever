-- Carbonite/Modules/Map/TargetsWindow.lua: janela "Destinos" da fila de destinos (#70)

local function load(names)
    local env = wow.lenientEnv()
    local registered = {}
    env.Carbonite.Core.SlashCommands = {
        Register = function(_, cmd, fn, help) registered[cmd] = { fn = fn, help = help } end,
    }
    local map = { Targets = {}, Tracking = { "old" }, UpdateTrackingDelay = 45, PlyrX = 100, PlyrY = 100 }
    for i, name in ipairs(names or { "A", "B", "C", "D" }) do
        map.Targets[i] = { TargetName = name, UniqueId = i, MapId = 1400 + i,
                           TargetMX = 100 + i * 10, TargetMY = 100 }
    end
    env.Nx = wow.namespace({
        Map = wow.namespace({
            Maps = { map },
            IdToName = function(_, id) return "Zone " .. id end,
        }),
    })
    loader.run(env, "Carbonite/Modules/Map/Targets.lua")
    loader.run(env, "Carbonite/Modules/Map/TargetsWindow.lua")
    return env.Carbonite.Modules.Map.TargetsWindow, map, env, registered
end

local function order(map)
    local out = {}
    for _, t in ipairs(map.Targets) do out[#out + 1] = t.TargetName end
    return table.concat(out, ",")
end

describe("Destinos: reordenar", function()
    it("sobe e desce um destino e devolve a nova posição", function()
        local W, map = load()
        expect(W:MoveUp(3)).toBe(2)
        expect(order(map)).toBe("A,C,B,D")
        expect(W:MoveDown(2)).toBe(3)
        expect(order(map)).toBe("A,B,C,D")
    end)

    it("não passa do topo nem do fim", function()
        local W, map = load()
        expect(W:MoveUp(1)).toBe(1)
        expect(W:MoveDown(4)).toBe(4)
        expect(W:MoveUp(9)).toBe(9)
        expect(order(map)).toBe("A,B,C,D")
    end)

    it("refaz a rota da seta na hora e avisa a mudança", function()
        local W, map, env = load()
        W:MoveDown(1)
        expect(#map.Tracking).toBe(0)
        expect(map.UpdateTrackingDelay).toBe(0)
        local fired = env.Carbonite.Core.EventBus.fired
        expect(fired[#fired][1]).toBe("MAP_TARGETS_CHANGED")
    end)
end)

describe("Destinos: remover", function()
    it("remove pelo id e mantém a ordem dos outros", function()
        local W, map, env = load()
        expect(W:Remove(2)).toBe(2)
        expect(order(map)).toBe("A,C,D")
        local removed
        for _, f in ipairs(env.Carbonite.Core.EventBus.fired) do
            if f[1] == "MAP_TARGET_REMOVED" then removed = f[2] end
        end
        expect(removed).toBe(2)
    end)

    it("o último removido deixa a seleção no novo último", function()
        local W, map = load()
        expect(W:Remove(4)).toBe(3)
        expect(order(map)).toBe("A,B,C")
    end)

    it("destino sem id também sai", function()
        local W, map = load()
        map.Targets[3].UniqueId = nil
        W:Remove(3)
        expect(order(map)).toBe("A,B,D")
    end)

    it("limpar tudo esvazia a fila", function()
        local W, map = load()
        W:ClearAll()
        expect(#map.Targets).toBe(0)
    end)
end)

describe("Destinos: ir agora", function()
    it("leva o destino ao começo da fila sem mudar o resto", function()
        local W, map = load()
        expect(W:GoNow(3)).toBe(1)
        expect(order(map)).toBe("C,A,B,D")
        expect(map.UpdateTrackingDelay).toBe(0)
    end)

    it("o primeiro fica onde está", function()
        local W, map = load()
        expect(W:GoNow(1)).toBe(1)
        expect(order(map)).toBe("A,B,C,D")
    end)
end)

describe("Destinos: inverter", function()
    it("inverte a fila", function()
        local W, map = load()
        W:Reverse()
        expect(order(map)).toBe("D,C,B,A")
    end)

    it("fila vazia não quebra", function()
        local W, map = load({})
        W:Reverse()
        W:ClearAll()
        expect(W:MoveUp(1)).toBe(1)
        expect(#map.Targets).toBe(0)
    end)
end)

describe("Destinos: linhas da lista", function()
    it("nome, zona e distância em jardas, na ordem da fila", function()
        local W = load({ "A", "B" })
        local rows = W:Rows()
        expect(#rows).toBe(2)
        expect(rows[1].index).toBe(1)
        expect(rows[1].name).toBe("A")
        expect(rows[1].zone).toBe("Zone 1401")
        expect(math.floor(rows[1].dist + .5)).toBe(46)
        expect(rows[2].name).toBe("B")
    end)

    it("sem posição do jogador, sem distância", function()
        local W, map = load({ "A" })
        map.PlyrX, map.PlyrY = 0, 0
        expect(W:Rows()[1].dist).toBeNil()
    end)
end)

describe("Destinos: como abrir", function()
    it("/carb destinos com ajuda traduzível", function()
        local _, _, _, registered = load()
        expect(registered.destinos.help).toBe("open the destination queue")
        expect(type(registered.destinos.fn)).toBe("function")
    end)

    it("item no submenu Rota do mapa e atalho de teclado", function()
        local engine = loader.read("Carbonite/Modules/Map/MapEngine.lua")
        expect(engine:find('routeMenu:AddItem(0, L["Destinations..."]', 1, true) ~= nil).toBe(true)
        expect(engine:find("function Nx.NXKeyToggleTargets()", 1, true) ~= nil).toBe(true)
        expect(loader.read("Carbonite/Bindings.xml"):find('name="NxTOGGLETARGETS"', 1, true) ~= nil).toBe(true)
        expect(loader.read("Carbonite/Carbonite.lua"):find("BINDING_NAME_NxTOGGLETARGETS", 1, true) ~= nil).toBe(true)
        expect(loader.read("Carbonite/Locales/ptBR/Bindings.lua"):find('L["NxTOGGLETARGETS"]', 1, true) ~= nil).toBe(true)
        expect(loader.read("Carbonite/Modules/Modules.xml"):find("Map\\TargetsWindow.lua", 1, true) ~= nil).toBe(true)
    end)
end)
