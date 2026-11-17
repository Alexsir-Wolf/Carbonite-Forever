-- Navios, zepelins e bonde em movimento, com horários nos píeres (#78):
-- Carbonite/Modules/Map/Transports.lua e os dados em Carbonite/Data/camelot/Transports.lua.

-- Rota de teste em coordenadas cruas (instância 7): parada de 10 s na plataforma 1,
-- 10 s de viagem passando por um ponto de cronometragem, 10 s na plataforma 2, volta.
local function route(extra)
    local r = {
        vessel = "Unnamed Vessel",
        kind = "ship",
        rtt = 40,
        coords = 7,
        zones = { [1437] = true },
        platforms = { "Menethil Harbor, Wetlands", "Auberdine, Darkshore" },
        points = {
            "100:200:10:0:0:plat1",
            "10:0:5:0:0",
            "10:0:5:0:0:trig1",
            "0:0:10:0:0:plat2",
            "-20:0:10:0:0",
        },
    }
    for k, v in pairs(extra or {}) do r[k] = v end
    return r
end

local function load(overrides, nx)
    local env = wow.lenientEnv(overrides)
    env.Nx = nx or { db = { profile = { Map = {} }, global = {} } }
    loader.run(env, "Carbonite/Modules/Map/Transports.lua")
    return env, env.Carbonite.Modules.Map.Transports
end

describe("transportes: posição no tempo", function()
    it("decodifica o trajeto em pontos absolutos", function()
        local _, T = load()
        local d = T.Decode(route())
        expect(d.count).toBe(5)
        expect(d.x[3]).toBe(120)
        expect(d.offset[2]).toBe(15)
        expect(d.offset[5]).toBe(40)   -- o último ponto fecha o período
        expect(d.plat[1]).toBe(1)
        expect(d.plat[2]).toBe(4)
        expect(d.trig[1]).toBe(3)
    end)

    it("calcula o ponto do ciclo a partir da fase e da hora", function()
        local _, T = load()
        local r = route()
        expect(T.Cycle(r, { p = 1000, t = 1000 }, 1085)).toBe(5)
        expect(T.Cycle(r, nil, 1085)).toBeNil()
        expect(T.PhaseOf(r, 17.5, 1000)).toBe(22.5)
        expect(T.Cycle(r, { p = 22.5 }, 1000)).toBe(17.5)
    end)

    it("interpola a posição entre os pontos", function()
        local _, T = load()
        local r = route()
        local i, x, y, zoning = T.Position(r, 0)
        expect(i).toBe(7)
        expect(x).toBe(100)
        expect(y).toBe(200)
        expect(zoning).toBe(false)
        _, x = T.Position(r, 12.5)
        expect(x).toBe(105)
        _, x = T.Position(r, 25)
        expect(x).toBe(120)
        _, x = T.Position(r, 35)
        expect(x).toBe(110)
    end)

    it("some no salto entre instâncias", function()
        local _, T = load()
        local r = route({ points = { "0:0:10:0:0:plat1", "5:0:10:0:0:jump", "0:0:10:0:0:plat2", "0:0:10:0:0" } })
        expect(T.Position(r, 15)).toBeNil()
        expect(T.Position(r, 25)).toBe(7)
    end)

    it("converte coordenadas de continente e cruas para jardas do mundo", function()
        local _, T = load()
        local r = route({ coords = -1, raw = 2991 })
        local d = T.Decode(r)
        local i, wx, wy = T.ToWorld(r, d, 1, .6, .5)
        expect(i).toBe(0)
        expect(math.abs(wx - (32601.04 - 44688.53 * .6)) < 1e-6).toBe(true)
        expect(math.abs(wy - (9894.93 - 29795.11 * .5)) < 1e-6).toBe(true)
        expect((T.ToWorld(r, d, 1, .3, .5))).toBe(1)
        d.rawp[2] = true
        local ri, rx = T.ToWorld(r, d, 2, 1011.3, 1953.5)
        expect(ri).toBe(2991)
        expect(rx).toBe(1011.3)
    end)

    it("situa o bonde entre as duas plataformas", function()
        local _, T = load()
        local r = route({ kind = "tram" })
        expect(T.TramFraction(r, 100)).toBe(0)
        expect(T.TramFraction(r, 110)).toBe(.5)
        expect(T.TramFraction(r, 120)).toBe(1)
        expect(T.TramFraction(r, 150)).toBe(1)
    end)
end)

describe("transportes: horário de partida", function()
    it("dá a espera de cada plataforma", function()
        local _, T = load()
        local list = T.PlatformTimes(route(), 25)
        expect(#list).toBe(2)
        expect(list[1].number).toBe(1)
        expect(list[1].docked).toBe(false)
        expect(list[1].wait).toBe(15)
        expect(list[1].stay).toBe(10)
        expect(list[1].name).toBe("Menethil Harbor, Wetlands")
        expect(list[2].docked).toBe(true)
        expect(list[2].wait).toBe(5)
    end)

    it("no píer, parte na hora em que acaba a parada", function()
        local _, T = load()
        local list = T.PlatformTimes(route(), 5)
        expect(list[1].docked).toBe(true)
        expect(list[1].wait).toBe(5)
        expect(list[2].docked).toBe(false)
        expect(list[2].wait).toBe(15)
    end)

    it("formata M:SS", function()
        local _, T = load()
        expect(T.FormatTime(80)).toBe("1:20")
        expect(T.FormatTime(5.9)).toBe("0:05")
        expect(T.FormatTime(-3)).toBe("0:00")
        expect(T.FormatTime(605)).toBe("10:05")
    end)

    it("monta a linha do tooltip", function()
        local _, T = load()
        expect(T.StatusText({ docked = true, wait = 42, stay = 60 }, "Navio"))
            .toBe("|cffffd100Navio: Departs in 0:42|r")
        expect(T.StatusText({ docked = true, wait = 20, stay = 60 }, "Navio"))
            .toBe("|cffff4040Navio: Departs in 0:20|r")
        expect(T.StatusText({ docked = false, wait = 80, stay = 60 }, "Navio"))
            .toBe("|cff4cff4cNavio: Arrives in 1:20, departs in 2:20|r")
        expect(T.StatusText({ docked = true, wait = 42, stay = 60 }))
            .toBe("|cffffd100Departs in 0:42|r")
    end)
end)

describe("transportes: píeres e cronometragem", function()
    it("liga o píer à plataforma mais próxima, e às quase tão próximas", function()
        local _, T = load()
        local list = {
            { id = 1, number = 1, instance = 0, x = 100, y = 100 },
            { id = 2, number = 2, instance = 0, x = 110, y = 100 },
            { id = 3, number = 1, instance = 0, x = 140, y = 100 },
            { id = 4, number = 1, instance = 1, x = 100, y = 100 },
            { id = 5, number = 1, instance = 0, x = 400, y = 100 },
        }
        local m = T.MatchPlatforms(list, 0, 100, 100)
        expect(#m).toBe(2)
        expect(m[1].id).toBe(1)
        expect(m[2].id).toBe(2)
        expect(#T.MatchPlatforms(list, 0, 1000, 1000)).toBe(0)
    end)

    it("cronometra quem passa no navio pelo ponto de referência", function()
        local _, T = load()
        local r = route()
        local near, cycle = T.TriggerCycle(r, 7, 115, 200, 20, 0, 20)
        expect(near).toBe(true)
        expect(cycle).toBe(17.5)
        -- Devagar: é o jogador andando no convés, não conta.
        near, cycle = T.TriggerCycle(r, 7, 115, 200, 10, 0, 10)
        expect(near).toBe(true)
        expect(cycle).toBeNil()
        expect((T.TriggerCycle(r, 7, 500, 200, 20, 0, 20))).toBe(false)
        expect((T.TriggerCycle(r, 8, 115, 200, 20, 0, 20))).toBe(false)
        -- Rota com sentido: indo ao contrário não conta.
        local one = route({ direction = { x = true } })
        expect((T.TriggerCycle(one, 7, 115, 200, -20, 0, 20))).toBe(false)
    end)

    it("põe o ponto na zona que o contém, ou na mais próxima no mar", function()
        local _, T = load()
        local rects = {
            { mapId = 1, rect = { x0 = 0, xs = 100, y0 = 0, ys = 100, instance = 0 } },
            { mapId = 2, rect = { x0 = 200, xs = 100, y0 = 0, ys = 100, instance = 0 } },
            { mapId = 3, rect = { x0 = 0, xs = 100, y0 = 0, ys = 100, instance = 1 } },
        }
        local id, x, y = T.PickRect(rects, 0, 250, 50)
        expect(id).toBe(2)
        expect(x).toBe(50)
        expect(y).toBe(50)
        id, x = T.PickRect(rects, 0, 120, 50)
        expect(id).toBe(1)
        expect(x).toBe(120)
        expect((T.PickRect(rects, 1, 50, 50))).toBe(3)
        expect((T.PickRect(rects, 5, 50, 50))).toBeNil()
    end)
end)

describe("transportes: horário conhecido", function()
    local function nx(store, on)
        return {
            db = { profile = { Map = { ShowTransports = on } }, global = { Transports = store } },
            TransportRoutes = { [1] = route() },
        }
    end

    it("usa a fase mais recente, do jogador ou do MapUtils", function()
        local env, T = load({ GetServerTime = function() return 2000 end },
            nx({ [1] = { p = 10, t = 1500, s = "self" } }))
        expect(T:Known(1).p).toBe(10)
        env.MAUTTAB = { TRANSPORTSYNC = { forever = { [1] = { p = 20, t = 1900, s = "Fulano" } } } }
        expect(T:Known(1).p).toBe(20)
        env.MAUTTAB.TRANSPORTSYNC.forever[1].t = 1000
        expect(T:Known(1).p).toBe(10)
    end)

    it("descarta fase velha ou inválida", function()
        local _, T = load({ GetServerTime = function() return 40 * 86400 end },
            nx({ [1] = { p = 10, t = 1 } }))
        expect(T:Known(1)).toBeNil()
        expect(T.ValidKnown({ p = "x", t = 1 }, 2)).toBe(false)
    end)

    it("grava a fase cronometrada pelo jogador", function()
        local env, T = load({ GetServerTime = function() return 1000 end }, nx({}))
        T:Observe(1, 17.5)
        local k = env.Nx.db.global.Transports[1]
        expect(k.p).toBe(22.5)
        expect(k.t).toBe(1000)
        expect(k.s).toBe("self")
    end)

    it("põe 'parte em' no tooltip do píer só com horário conhecido", function()
        -- Fase 1000, agora 1025: 25 s no ciclo, atracado na plataforma 2 por mais 5 s.
        local env, T = load({ GetServerTime = function() return 1025 end },
            nx({ [1] = { p = 1000, t = 1000 } }))
        local icon = { tip = "Boat to Darkshore", x = 1, y = 2 }
        local entry = { icon = icon, base = icon.tip, tip = icon.tip, x = 1, y = 2,
                        matches = { { id = 1, number = 2 } } }
        T.piers[1] = entry
        T:UpdatePierTips()
        expect(icon.tip).toBe("Boat to Darkshore\n|cffff4040Ship: Departs in 0:05|r")
        expect(icon.Tip).toBe(icon.tip)

        -- Sem horário: só o texto do píer.
        env.Nx.db.global.Transports[1] = nil
        T:UpdatePierTips()
        expect(icon.tip).toBe("Boat to Darkshore")

        -- Opção desligada: idem.
        env.Nx.db.global.Transports[1] = { p = 1000, t = 1000 }
        env.Nx.db.profile.Map.ShowTransports = false
        T:UpdatePierTips()
        expect(icon.tip).toBe("Boat to Darkshore")
    end)

    it("larga o ícone que o Guia reaproveitou para outro ponto", function()
        local _, T = load({ GetServerTime = function() return 1025 end },
            nx({ [1] = { p = 1000, t = 1000 } }))
        local icon = { tip = "Boat", x = 1, y = 2 }
        T.piers[1] = { icon = icon, base = "Boat", tip = "Boat", x = 1, y = 2, matches = { { id = 1, number = 2 } } }
        icon.tip, icon.x = "Mailbox", 9
        T:UpdatePierTips()
        expect(#T.piers).toBe(0)
        expect(icon.tip).toBe("Mailbox")
    end)

    it("dá nome ao navio sem nome pelo tipo", function()
        local _, T = load()
        expect(T:VesselName(route())).toBe("Ship")
        expect(T:VesselName(route({ kind = "zeppelin" }))).toBe("Zeppelin")
        expect(T:VesselName(route({ vessel = "The Bravery" }))).toBe("The Bravery")
    end)
end)

describe("transportes: dados do Forever", function()
    local function data()
        local env = wow.lenientEnv()
        env.Nx = {}
        loader.run(env, "Carbonite/Data/camelot/Transports.lua")
        return env.Nx
    end

    it("traz as 14 rotas, com período e plataformas que fecham", function()
        local Nx = data()
        local _, T = load()
        local n = 0
        for id, r in pairs(Nx.TransportRoutes) do
            n = n + 1
            expect(type(id)).toBe("number")
            expect(r.rtt > 0).toBe(true)
            local d = T.Decode(r)
            expect(d.count > 10).toBe(true)
            expect(d.plat[1] ~= nil and d.plat[2] ~= nil).toBe(true)
            for _, e in ipairs(T.PlatformTimes(r, r.rtt / 3)) do
                expect(e.wait >= 0 and e.wait < r.rtt).toBe(true)
                expect(e.stay > 0).toBe(true)
            end
        end
        expect(n).toBe(14)
        -- Rotas do Forever por cima das do Classic.
        expect(Nx.TransportRoutes[5].platforms[3]).toBe("Auberdine, Darkshore")
        expect(Nx.TransportRoutes[14].platforms[1]).toBe("Powderfuse Port, Riverglades")
        expect(Nx.TransportNamesPtBR["The Bravery"]).toBe("O Bravura")
    end)
end)

describe("transportes: ligação com o mapa", function()
    it("carrega módulo e dados, com opção em Mostrar..., ligada por padrão", function()
        expect(loader.read("Carbonite/Modules/Modules.xml"):find('<Script file="Map\\Transports.lua" />', 1, true) ~= nil).toBe(true)
        expect(loader.read("Carbonite/Data/camelot/data.xml"):find('<Include file="Transports.lua" />', 1, true) ~= nil).toBe(true)
        expect(loader.read(".luacheckrc"):find('"Carbonite/Modules/Map/Transports.lua"', 1, true) ~= nil).toBe(true)
        local engine = loader.read("Carbonite/Modules/Map/MapEngine.lua")
        expect(engine:find('showMenu:AddItem(0, L["Show Ships and Zeppelins"]', 1, true) ~= nil).toBe(true)
        expect(engine:find('item:SetChecked(Nx.db.profile.Map, "ShowTransports")', 1, true) ~= nil).toBe(true)
        expect(loader.read("Carbonite/Modules/PlayerCharacter/Defaults.lua"):find("ShowTransports = true", 1, true) ~= nil).toBe(true)
        for _, key in ipairs({ "Show Ships and Zeppelins", "Departs in %s", "Arrives in %s, departs in %s" }) do
            expect(loader.read("Carbonite/Locales/enUS/Map.lua"):find('L["' .. key .. '"] = true', 1, true) ~= nil).toBe(true)
            expect(loader.read("Carbonite/Locales/ptBR/Map.lua"):find('L["' .. key .. '"] = "', 1, true) ~= nil).toBe(true)
        end
        expect(loader.read("Carbonite/Locales/ptBR/Map.lua"):find('L["Departs in %s"] = "Parte em %s"', 1, true) ~= nil).toBe(true)
    end)

    it("os píeres do Guia passam o ícone ao módulo", function()
        local guide = loader.read("Carbonite/Data/Shared/NxMapGuide.lua")
        expect(guide:find("Transports:ResetPiers()", 1, true) ~= nil).toBe(true)
        expect(guide:find("Transports:AddPier (icon, mapId1, x1, y1, tip)", 1, true) ~= nil).toBe(true)
    end)
end)
