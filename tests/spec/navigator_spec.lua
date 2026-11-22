-- Quem guia até o destino: Carbonite, TomTom ou Shortest Path Forever (#222, #223)
-- Carbonite/Modules/Integrations/Navigator.lua

local function load(opts)
    opts = opts or {}
    local loaded = opts.loaded or {}
    local enabled = opts.enabled or {}
    local calls = { added = {}, removed = {}, routes = {}, cancels = 0, cleared = 0, removedTargets = {}, prt = {} }
    local env = wow.env({
        C_AddOns = {
            IsAddOnLoaded = function(name) return loaded[name] == true end,
            DoesAddOnExist = function(name) return enabled[name] ~= nil or loaded[name] == true end,
            GetAddOnEnableState = function(name) return enabled[name] and 2 or 0 end,
        },
        UnitGUID = function() return "Player-1" end,
        C_Map = { GetMapInfo = function(id) return id < 9000 and { mapID = id } or nil end },
        InCombatLockdown = function() return opts.combat and opts.combat() or false end,
    })
    env.Nx = {
        db = { profile = { Track = opts.track or {} } },
        prt = function(_, msg) calls.prt[#calls.prt + 1] = msg end,
    }
    -- Carbonite world == zone percent (map:GetZonePos), to keep the numbers readable.
    local map = { Targets = {} }
    function map:GetZonePos(_, x, y) return x, y end
    function map:ClearTargets() calls.cleared = calls.cleared + 1; self.Targets = {} end
    env.Nx.Map = { GetMap = function() return map end }
    env.Carbonite.Modules.Map.Targets = {
        Remove = function(_, id)
            calls.removedTargets[#calls.removedTargets + 1] = id
            for i, t in ipairs(map.Targets) do
                if t.UniqueId == id then table.remove(map.Targets, i) return true end
            end
            return false
        end,
    }

    if opts.tomtom then
        local valid = {}
        env.TomTom = {
            AddWaypoint = function(_, m, x, y, o)
                local uid = { m, x, y, title = o.title }
                calls.added[#calls.added + 1] = { m, x, y, o }
                valid[uid] = true
                return uid
            end,
            RemoveWaypoint = function(_, uid) valid[uid] = nil; calls.removed[#calls.removed + 1] = uid end,
            IsValidWaypoint = function(_, uid) return valid[uid] == true end,
        }
        calls.valid = valid
    end
    if opts.spf then
        local api = {
            version = opts.spfVersion or 2,
            NavigateRoute = function(owner, stops)
                calls.routes[#calls.routes + 1] = { owner = owner, stops = stops }
                if opts.refuse then return false end
                calls.current = 1
                return true
            end,
            Cancel = function(owner) calls.cancels = calls.cancels + 1; calls.current = nil; return owner == "Carbonite" end,
            CurrentStop = function() return calls.current end,
            Ended = function() return calls.ended end,
            Subscribe = function(cb) calls.subscriber = cb; return function() end end,
        }
        env.ShortestPathForever = { API = api }
    end

    loader.run(env, "Carbonite/Modules/Integrations/Navigator.lua")
    return env.Carbonite.Modules.Integrations.Navigator, map, calls, env
end

local function target(id, x, y, mapId)
    return { UniqueId = id, MapId = mapId or 1429, TargetMX = x, TargetMY = y, TargetName = "Alvo " .. id }
end

describe("navegador: escolha efetiva", function()
    it("padrão é o Carbonite", function()
        local nav = load()
        expect(nav:Saved()).toBe("carbonite")
        expect(nav:Active()).toBe("carbonite")
    end)

    it("escolha salva cujo addon não está ativo volta ao Carbonite", function()
        local nav = load({ track = { Navigator = "spf" } })
        expect(nav:Active()).toBe("carbonite")
        expect(nav:SavedUnavailable()).toBe(true)
    end)

    it("valor desconhecido vira Carbonite", function()
        local nav = load({ track = { Navigator = "outro" } })
        expect(nav:Saved()).toBe("carbonite")
    end)

    it("TomTom ativo para o personagem conta antes de carregar (carrega depois do Carbonite)", function()
        local nav = load({ track = { Navigator = "tomtom" }, enabled = { TomTom = true } })
        expect(nav:TomTomEnabled()).toBe(true)
        expect(nav:Active()).toBe("tomtom")
    end)

    it("API do SPF: aceita versões 1 e 2 com as funções usadas", function()
        expect(load({ spf = true }):SPFApi() ~= nil).toBe(true)
        expect(load({ spf = true, spfVersion = 3 }):SPFApi()).toBeNil()
    end)
end)

describe("navegador: emulação do TomTom", function()
    it("só emula enquanto o Carbonite guia, sem o TomTom real e com a opção ligada", function()
        expect(load():ShouldEmulateTomTom()).toBe(true)
        expect(load({ enabled = { TomTom = true } }):ShouldEmulateTomTom()).toBe(false)
        expect(load({ track = { EmuTomTom = false } }):ShouldEmulateTomTom()).toBe(false)
        local spf = load({ track = { Navigator = "spf" }, loaded = { ShortestPathForever = true } })
        expect(spf:ShouldEmulateTomTom()).toBe(false)
    end)
end)

describe("navegador: TomTom (#223)", function()
    local function tomtom()
        return load({ tomtom = true, loaded = { TomTom = true }, track = { Navigator = "tomtom" } })
    end

    it("o destino atual vira waypoint do TomTom e a seta do Carbonite some", function()
        local nav, map, calls = tomtom()
        map.Targets = { target(1, 42, 65), target(2, 10, 10) }
        nav:Sync()
        expect(#calls.added).toBe(1)
        expect(calls.added[1][1]).toBe(1429)
        expect(math.abs(calls.added[1][2] - 0.42) < 1e-9).toBe(true)
        expect(calls.added[1][4].title).toBe("Alvo 1")
        expect(calls.added[1][4].from).toBe("Carbonite")
        expect(nav:HidesCarbArrow()).toBe(true)
        expect(nav:HidesCarbRoute()).toBe(false)
        nav:Sync()
        expect(#calls.added).toBe(1)          -- nothing changed, nothing sent
    end)

    it("trocar o destino troca o waypoint; limpar remove", function()
        local nav, map, calls = tomtom()
        map.Targets = { target(1, 42, 65) }
        nav:Sync()
        map.Targets = { target(3, 20, 20) }
        nav:Sync()
        expect(#calls.removed).toBe(1)
        expect(#calls.added).toBe(2)
        map.Targets = {}
        nav:Sync()
        expect(#calls.removed).toBe(2)
        expect(nav:HidesCarbArrow()).toBe(false)
    end)

    it("waypoint removido no TomTom tira o destino do Carbonite e passa ao próximo", function()
        local nav, map, calls = tomtom()
        map.Targets = { target(1, 42, 65), target(2, 10, 10) }
        nav:Sync()
        calls.valid[next(calls.valid)] = nil  -- arrival in TomTom
        nav:Sync()
        expect(calls.removedTargets[1]).toBe(1)
        expect(#calls.added).toBe(2)
        expect(calls.added[2][4].title).toBe("Alvo 2")
    end)

    it("destino num mapa que o cliente não conhece fica com a seta do Carbonite", function()
        local nav, map, calls = tomtom()
        map.Targets = { target(1, 42, 65, 9999) }
        nav:Sync()
        expect(#calls.added).toBe(0)
        expect(nav:HidesCarbArrow()).toBe(false)
    end)
end)

describe("navegador: Shortest Path Forever (#222)", function()
    local function spf(extra)
        local opts = { spf = true, loaded = { ShortestPathForever = true }, track = { Navigator = "spf" } }
        for k, v in pairs(extra or {}) do opts[k] = v end
        return load(opts)
    end

    it("manda os destinos em ordem para NavigateRoute e esconde seta e linha do Carbonite", function()
        local nav, map, calls = spf()
        map.Targets = { target(1, 42, 65), target(2, 10, 20) }
        nav:Sync()
        expect(#calls.routes).toBe(1)
        expect(calls.routes[1].owner).toBe("Carbonite")
        expect(#calls.routes[1].stops).toBe(2)
        expect(calls.routes[1].stops[2].title).toBe("Alvo 2")
        expect(math.abs(calls.routes[1].stops[2].y - 0.2) < 1e-9).toBe(true)
        expect(nav:HidesCarbArrow()).toBe(true)
        expect(nav:HidesCarbRoute()).toBe(true)
    end)

    it("limpar os destinos no Carbonite cancela a jornada no SPF", function()
        local nav, map, calls = spf()
        map.Targets = { target(1, 42, 65) }
        nav:Sync()
        map.Targets = {}
        nav:Sync()
        expect(calls.cancels).toBe(1)
        expect(nav:HidesCarbRoute()).toBe(false)
    end)

    it("jornada encerrada no SPF (limpa, chegou, substituída) limpa os destinos do Carbonite", function()
        local nav, map, calls = spf()
        map.Targets = { target(1, 42, 65) }
        nav:Sync()
        calls.current, calls.ended = nil, "cleared"
        calls.subscriber({ ended = true })
        expect(calls.cleared).toBe(1)
        expect(nav:HidesCarbArrow()).toBe(false)
        nav:Sync()
        expect(#calls.routes).toBe(1)          -- not sent again
    end)

    it("o próprio Cancel do Carbonite não limpa os destinos", function()
        local nav, map, calls = spf()
        map.Targets = { target(1, 42, 65) }
        nav:Sync()
        calls.current, calls.ended = nil, "cancelled"
        calls.subscriber({ ended = true })
        expect(calls.cleared).toBe(0)
    end)

    it("recusa em combate reenvia depois do combate", function()
        local inCombat = true
        local nav, map, calls = spf({ refuse = true, combat = function() return inCombat end })
        map.Targets = { target(1, 42, 65) }
        nav:Sync()
        expect(nav:HidesCarbArrow()).toBe(false)
        nav:Sync()
        expect(#calls.routes).toBe(1)          -- still in combat
        inCombat = false
        nav:Sync()
        expect(#calls.routes).toBe(2)
    end)

    it("recusa fora do combate deixa a seta do Carbonite e avisa uma vez", function()
        local nav, map, calls = spf({ refuse = true })
        map.Targets = { target(1, 42, 65) }
        nav:Sync()
        map.Targets = { target(2, 10, 10) }
        nav:Sync()
        expect(nav:HidesCarbArrow()).toBe(false)
        expect(#calls.prt).toBe(1)
    end)

    it("até 64 paradas, o limite da API", function()
        local nav, map, calls = spf()
        for i = 1, 70 do map.Targets[i] = target(i, i, i) end
        nav:Sync()
        expect(#calls.routes[1].stops).toBe(64)
    end)
end)

describe("navegador: ligação no Carbonite", function()
    it("entra na carga antes da emulação do TomTom", function()
        local xml = loader.read("Carbonite/Modules/Modules.xml")
        local nav = xml:find("Integrations\\Navigator.lua", 1, true)
        local tom = xml:find("Integrations\\TomTom.lua", 1, true)
        expect(nav ~= nil and tom ~= nil and nav < tom).toBe(true)
    end)

    it("HUD, rota e trilha do mapa respeitam quem guia", function()
        local hud = loader.read("Carbonite/Modules/HUD/HUDEngine.lua")
        expect(hud:find("and not navigatorLeads()", 1, true) ~= nil).toBe(true)
        local engine = loader.read("Carbonite/Modules/Map/MapEngine.lua")
        local _, count = engine:gsub("Navigator:HidesCarbRoute%(%)", "")
        expect(count).toBe(2)
    end)

    it("TomTom real é o addon, não o global (que pode ser o shim do SPF)", function()
        local src = loader.read("Carbonite/Modules/InitFlow/SetupPipeline.lua")
        expect(src:find("nav:TomTomEnabled()", 1, true) ~= nil).toBe(true)
    end)

    it("com o TomTom guiando, a seta do Carbonite não segue mais a do TomTom (#73)", function()
        local src = loader.read("Carbonite.Notes/Integrations/TomTomArrow.lua")
        expect(src:find('nav:Active() == "tomtom"', 1, true) ~= nil).toBe(true)
    end)

    it("o padrão salvo é o Carbonite", function()
        local defaults = loader.read("Carbonite/Modules/PlayerCharacter/Defaults.lua")
        expect(defaults:find('Navigator = "carbonite"', 1, true) ~= nil).toBe(true)
    end)
end)

describe("emulação do TomTom segue a escolha", function()
    local function emu(opts)
        opts = opts or {}
        local env = wow.env({
            C_AddOns = {
                IsAddOnLoaded = function(name) return (opts.loaded or {})[name] == true end,
                DoesAddOnExist = function() return false end,
            },
            SlashCmdList = {},
        })
        env.Nx = { db = { profile = { Track = opts.track or {} } } }
        if opts.global then env.TomTom = opts.global end
        loader.run(env, "Carbonite/Modules/Integrations/Navigator.lua")
        loader.run(env, "Carbonite/Modules/Integrations/TomTom.lua")
        return env.Carbonite.Modules.Integrations.TomTom, env
    end

    it("com o Carbonite guiando, cria uma tabela própria no lugar do shim do SPF", function()
        local shim = { AddWaypoint = function() return "spf" end }
        local tom, env = emu({ global = shim })
        expect(tom:Emulate()).toBe(true)
        expect(env.TomTom ~= shim).toBe(true)
        expect(shim.AddWaypoint() == "spf").toBe(true)   -- the shim keeps its own functions
        expect(tom:IsEmulating()).toBe(true)
    end)

    it("com o SPF escolhido, não emula e deixa o global do SPF", function()
        local shim = {}
        local tom, env = emu({ global = shim, track = { Navigator = "spf" }, loaded = { ShortestPathForever = true } })
        expect(tom:Emulate()).toBe(false)
        expect(env.TomTom).toBe(shim)
        tom:Stop()
        expect(env.TomTom).toBe(shim)                     -- not ours to remove
    end)

    it("com a opção de emulação desligada, não emula", function()
        local tom, env = emu({ track = { EmuTomTom = false } })
        expect(tom:Emulate()).toBe(false)
        expect(env.TomTom).toBeNil()
    end)
end)
