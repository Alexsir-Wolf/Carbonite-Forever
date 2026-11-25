-- Rotas das masmorras com os dados do ForeverDungeonRoutes (#272)

local DATA_FILES = { "Dungeons", "Floors", "Encounters", "DefaultRoutes", "Rooms", "Pictures", "Minimaps", "Entrances" }

-- The data of Carbonite.Dungeons, parsed once for the whole file.
local shared
local function data()
    if not shared then
        local env = wow.env()
        env.Nx = {}
        local t = {}
        for _, name in ipairs(DATA_FILES) do
            loader.run(env, "Carbonite.Dungeons/Data/" .. name .. ".lua", "Carbonite.Dungeons", t)
        end
        loader.run(env, "Carbonite.Dungeons/Load.lua", "Carbonite.Dungeons", t)
        shared = env.Nx.DungeonRoutesData
    end
    return shared
end

local ABSENT = { "issecretvalue", "LoadAddOn", "LE_PARTY_CATEGORY_INSTANCE", "Ambiguate", "StaticPopupDialogs",
    "StaticPopup_Show", "IsInGuild", "IsInRaid", "IsInGroup", "SendChatMessage", "GetFileIDFromPath" }

-- opts: inside, id (instance), kind, subzone, locale, loaded (data already in), fdr (FDR loaded)
local function load(opts)
    opts = opts or {}
    local loads = {}
    local env
    env = wow.lenientEnv({
        IsInInstance = function() return opts.inside ~= false, opts.kind or "party" end,
        GetInstanceInfo = function() return opts.name or "Dungeon", opts.kind or "party", 1, "", 5, 0, false, opts.id or 36 end,
        GetSubZoneText = function() return opts.subzone or "" end,
        GetLocale = function() return opts.locale or "enUS" end,
        GetTime = function() return 1 end,
        time = function() return opts.now or 1000 end,
        date = function() return "2026-11-25 10:00" end,
        UnitName = function() return "Eu" end,
        C_AddOns = {
            LoadAddOn = function(name)
                loads[#loads + 1] = name
                env.Nx.DungeonRoutesData = data()
                env.Nx.DungeonRoutes:OnDataLoaded()
            end,
            IsAddOnLoaded = function(name) return opts.fdr and name == "ForeverDungeonRoutes" or false end,
        },
    }, ABSENT)
    env.Nx = { db = { char = {}, global = {}, profile = {} } }
    if opts.loaded ~= false then env.Nx.DungeonRoutesData = data() end
    loader.run(env, "Carbonite/Modules/Map/DungeonPins.lua")
    loader.run(env, "Carbonite/Modules/Map/DungeonRoutes.lua")
    loader.run(env, "Carbonite/Modules/Map/DungeonGuide.lua")
    loader.run(env, "Carbonite/Modules/Map/DungeonRouteCodec.lua")
    loader.run(env, "Carbonite/Modules/Map/DungeonRouteRecorder.lua")
    loader.run(env, "Carbonite/Modules/Map/DungeonRouteShare.lua")
    return env.Nx.DungeonRoutes, env, loads
end

local function names(list)
    local out = {}
    for i, b in ipairs(list) do out[i] = b.name end
    return table.concat(out, ", ")
end

describe("dados do Carbonite.Dungeons", function()
    it("trazem as 41 masmorras e nenhuma arte de fora da MIT", function()
        local d = data()
        expect(#d.Dungeons).toBe(41)
        for _, name in ipairs(DATA_FILES) do
            local src = loader.read("Carbonite.Dungeons/Data/" .. name .. ".lua")
            expect(src:find("maps\\\\", 1, true) == nil and src:find("image =", 1, true) == nil).toBe(true)
        end
        expect(d.Floors[291].tiles).toBeNil()
    end)

    it("o addon de dados só carrega sob demanda e com o aviso MIT", function()
        local toc = loader.read("Carbonite.Dungeons/Carbonite.Dungeons.toc")
        expect(toc:find("## LoadOnDemand: 1", 1, true) ~= nil).toBe(true)
        expect(loader.read("Carbonite.Dungeons/LICENSE-ForeverDungeonRoutes.txt"):find("Checkov23", 1, true) ~= nil).toBe(true)
    end)
end)

describe("carga sob demanda", function()
    it("dentro de masmorra carrega os dados uma vez", function()
        local R, _, loads = load({ loaded = false })
        R:OnEnterWorld()
        R:OnEnterWorld()
        expect(#loads).toBe(1)
        expect(loads[1]).toBe("Carbonite.Dungeons")
        expect(R:IsLoaded()).toBe(true)
    end)

    it("fora de masmorra não carrega", function()
        local R, _, loads = load({ loaded = false, inside = false })
        R:OnEnterWorld()
        expect(#loads).toBe(0)
        expect(R:IsLoaded()).toBe(false)
    end)

    it("em campo de batalha não carrega", function()
        local R = load({ loaded = false, kind = "pvp" })
        R:OnEnterWorld()
        expect(R:IsLoaded()).toBe(false)
    end)

    it("não lê nada do ForeverDungeonRoutes", function()
        for _, f in ipairs({ "DungeonRoutes", "DungeonRouteCodec", "DungeonRouteRecorder", "DungeonRouteShare", "DungeonRouteEditor" }) do
            local src = loader.read("Carbonite/Modules/Map/" .. f .. ".lua"):gsub("%-%-[^\n]*", "")
            expect(src:find("ForeverDungeonRoutesDB", 1, true)).toBeNil()
            expect(src:find("_G.ForeverDungeonRoutes", 1, true)).toBeNil()
        end
    end)
end)

describe("andares", function()
    it("andar de figura vira mapa e nível", function()
        local R = load()
        local map, level = R.PictureMap(1029942)
        expect(map).toBe(2994)
        expect(level).toBe(2)
        expect(R.PictureMap(291)).toBeNil()
    end)

    it("traduz para a chave do DungeonPins (pinos de quest)", function()
        local R = load()
        expect(R.PinFloorKey(291)).toBe("291")
        expect(R.PinFloorKey(1029942)).toBe("900003_2")
    end)

    it("nome do andar no idioma do cliente", function()
        local R = load({ locale = "ptBR" })
        expect(R:FloorName(291)).toBe("Minas Mortas")
    end)
end)

describe("masmorra atual", function()
    it("pelo ID da instância", function()
        local R = load({ id = 36 })
        expect(R:CurrentKey()).toBe("deadmines")
    end)

    it("alas no mesmo ID: a da sala atual", function()
        local d = data()
        local wing, room
        for _, dungeon in ipairs(d.Dungeons) do
            if dungeon.instanceID == 189 and d.Rooms[dungeon.key] and d.Rooms[dungeon.key][1] then
                wing, room = dungeon.key, d.Rooms[dungeon.key][1].name
                break
            end
        end
        local R = load({ id = 189, subzone = room })
        R:OnSubZone(room)
        expect(R:CurrentKey()).toBe(wing)
    end)
end)

describe("rota curada", function()
    it("a ordem dos chefes é a da rota", function()
        local R = load()
        expect(names(R:BossList("deadmines"))).toBe(
            "Rhahk'Zor, Sneed's Shredder, Gilnid, Mr. Smite, Captain Greenskin, Edwin VanCleef")
    end)

    it("nomes no idioma do cliente", function()
        local R = load({ locale = "ptBR" })
        expect(R:BossList("deadmines")[4].name).toBe("Sr. Castiga")
    end)

    it("chefe morto pelo ID do encontro", function()
        local R, env = load()
        env.Nx.DungeonGuide:NoteKill("Rhahk'Zor", nil, 2741)
        local list = R:BossList("deadmines")
        expect(list[1].killed).toBe(true)
        expect(list[2].killed).toBe(false)
    end)

    it("o painel do guia usa a ordem da rota", function()
        local _, env = load()
        local DG = env.Nx.DungeonGuide
        expect(DG:Bosses()[2].name).toBe("Sneed's Shredder")
    end)

    it("sem caminhos no andar: retas entre os chefes, com estado", function()
        local R = load()
        local route = { paths = {}, stops = {
            { kind = "boss", floor = 291, x = .1, y = .1 },
            { kind = "optional", floor = 291, x = .2, y = .2 },
            { kind = "boss", floor = 291, x = .3, y = .3 },
            { kind = "boss", floor = 291, x = .5, y = .5 },
            { kind = "boss", floor = 292, x = .5, y = .5 },
        } }
        local killed = { [1] = true }
        local legs = R.Legs(route, 291, killed)
        expect(#legs).toBe(2)            -- 1 -> 3 -> 4; the optional stop is no leg
        expect(legs[1].state).toBe("next")
        expect(legs[2].state).toBe("ahead")
    end)

    it("com caminhos: trechos feitos, próximo e à frente", function()
        local R = load()
        local route = R:ActiveRoute("alcazprison")
        local legs = R.Legs(route, 1029941, {})
        local seen = {}
        for _, leg in ipairs(legs) do seen[leg.state] = true end
        expect(#legs > 10).toBe(true)
        expect(seen.next).toBe(true)
        expect(seen.done).toBeNil()
    end)

    it("todos os chefes mortos: rota toda feita", function()
        local R = load()
        local route = R:ActiveRoute("alcazprison")
        local killed = {}
        for i in ipairs(route.stops) do killed[i] = true end
        for _, leg in ipairs(R.Legs(route, 1029941, killed)) do
            if leg.kind == "main" then expect(leg.state).toBe("done") end
        end
    end)

    it("masmorra com mais de uma rota: escolher a ativa", function()
        local R = load()
        local routes = R:Routes("diremaul_north")
        expect(#routes > 1).toBe(true)
        expect(R:ActiveRoute("diremaul_north")).toBe(routes[1])
        R:SetActive("diremaul_north", routes[2].id)
        expect(R:ActiveRoute("diremaul_north")).toBe(routes[2])
    end)
end)

describe("sala atual", function()
    it("pelo nome em inglês: sala, andar principal e centro", function()
        local R = load({ id = 36 })
        local room = R:OnSubZone("Goblin Foundry")
        expect(room ~= nil).toBe(true)
        expect(R:Room()).toBe(room)
        expect(R.RoomMainFloor(room)).toBe(292)
        local x, y = R.RoomCenter(room, 292)
        expect(x > 0 and x < 1 and y > 0 and y < 1).toBe(true)
    end)

    it("pelo nome em pt-BR", function()
        local R = load({ id = 36, locale = "ptBR" })
        expect(R:OnSubZone("Fundição dos Goblins") ~= nil).toBe(true)
        expect(R.Loc(R:Room(), "name")).toBe("Fundição dos Goblins")
    end)

    it("lugar sem sala: nada destacado", function()
        local R = load({ id = 36 })
        R:OnSubZone("Goblin Foundry")
        R:OnSubZone("Lugar Nenhum")
        expect(R:Room()).toBeNil()
    end)

    it("o painel diz onde o jogador está", function()
        local R, env = load({ id = 36 })
        R:OnSubZone("Goblin Foundry")
        expect(env.Nx.DungeonGuide:RoomLine():find("Goblin Foundry", 1, true) ~= nil).toBe(true)
    end)
end)

-- Made by ForeverDungeonRoutes' own Serialize.lua (1.3.14): a deadmines route with a main
-- path, a side path, a boss, an optional stop with a note, a note and a floor link.
local FDR_TEXT = "!FDR1!SwlkZWFkbWluZXMKTglNaW5oYSByb3RhClAJbWFpbgkyOTEJMTAwMCwyMDAwLDMwMDAsNDAwMCw1MDAwLDYwMDAJClAJc2lkZQkyOTIJNjAwMCwyNTAwLDY1MDAsMzAwMAkKUwlib3NzCTI5MQkzNjUzCTYxNzMJUmhhaGsnWm9yCQkyNzQxClMJb3B0aW9uYWwJMjkyCTY3NTgJNDAxMglDb29raWUJRmlzaCAgIGNoaXBzCTI3NDYKTwkyOTIJMTk4Nwk1MzE3CUNhbmjDo28KTAkyOTEJOTAwMAk5MDAwCTI5Mgl2"

describe("exportar e importar (!FDR1!)", function()
    it("lê o texto feito pelo ForeverDungeonRoutes", function()
        local _, env = load()
        local key, route = env.Nx.DungeonRouteCodec.Import(FDR_TEXT)
        expect(key).toBe("deadmines")
        expect(route.name).toBe("Minha rota")
        expect(#route.paths).toBe(2)
        expect(#route.stops).toBe(2)
        expect(route.stops[1].encounters[1]).toBe(2741)
        expect(route.notes[1].text).toBe("Canhão")
        expect(route.links[1].to).toBe(292)
        expect(route.paths[1].t0).toBe(0)
        expect(route.paths[1].t1).toBe(1)
    end)

    it("gera o mesmo texto que o ForeverDungeonRoutes", function()
        local _, env = load()
        local C = env.Nx.DungeonRouteCodec
        local key, route = C.Import(FDR_TEXT)
        expect(C.Export(key, route)).toBe(FDR_TEXT)
    end)

    it("ida e volta da rota padrão", function()
        local R, env = load()
        local C = env.Nx.DungeonRouteCodec
        local text = C.Export("alcazprison", R:ActiveRoute("alcazprison"))
        local key, route = C.Import(text)
        expect(key).toBe("alcazprison")
        expect(#route.stops).toBe(#R:ActiveRoute("alcazprison").stops)
        expect(C.Export(key, route)).toBe(text)
    end)

    it("tira | do texto importado", function()
        local _, env = load()
        local C = env.Nx.DungeonRouteCodec
        local text = C.PREFIX .. C.Base64Encode("K\tdeadmines\nO\t291\t100\t100\t|cffff0000x|r")
        local _, route = C.Import(text)
        expect(route.notes[1].text).toBe("cffff0000xr")
    end)

    it("recusa texto estranho, danificado, grande ou vazio", function()
        local _, env = load()
        local C = env.Nx.DungeonRouteCodec
        expect(select(2, C.Import("oi"))).toBe("This is not a route export.")
        expect(select(2, C.Import(C.PREFIX .. "@@@"))).toBe("The text is damaged or incomplete.")
        local lines = { "K\tdeadmines" }
        for i = 1, 121 do lines[#lines + 1] = "S\tboss\t291\t100\t100\tX" .. i end
        expect(select(2, C.Import(C.PREFIX .. C.Base64Encode(table.concat(lines, "\n"))))).toBe("The route is too large.")
        expect(select(2, C.Import(C.PREFIX .. C.Base64Encode("K\tdeadmines")))).toBe("The route is empty.")
        expect(select(2, C.Import(C.PREFIX .. C.Base64Encode("K\tnada\nO\t291\t1\t1\tx")))).toBe("The text is damaged or incomplete.")
    end)

    it("descarta o que não está num andar da masmorra", function()
        local _, env = load()
        local C = env.Nx.DungeonRouteCodec
        local _, route = C.Import(C.PREFIX .. C.Base64Encode("K\tdeadmines\nO\t291\t1\t1\tsim\nO\t213\t1\t1\tnao"))
        expect(#route.notes).toBe(1)
    end)
end)

describe("rotas do jogador", function()
    it("ficam nas SavedVariables e viram a ativa", function()
        local R, env = load()
        local route = R:AddUserRoute("deadmines", { name = "Minha", paths = {}, stops = {}, notes = {}, links = {} })
        expect(route.id).toBe("user:1")
        expect(env.Nx.db.global.DungeonRoutes.routes.deadmines[1]).toBe(route)
        expect(R:ActiveRoute("deadmines")).toBe(route)
        expect(R.IsBuiltIn(R:Routes("deadmines")[1])).toBe(true)
    end)

    it("renomear e excluir só as do jogador", function()
        local R = load()
        local route = R:AddUserRoute("deadmines", { name = "A", paths = {}, stops = {}, notes = {}, links = {} })
        expect(R:RenameRoute("deadmines", route.id, "B|x")).toBe(true)
        expect(route.name).toBe("B x")
        expect(R:RenameRoute("deadmines", "default", "C")).toBe(false)
        expect(R:DeleteRoute("deadmines", route.id)).toBe(true)
        expect(R.IsBuiltIn(R:ActiveRoute("deadmines"))).toBe(true)
    end)

    it("cópia da rota padrão não é padrão", function()
        local R = load()
        local copy = R:CopyRoute(R:ActiveRoute("deadmines"))
        expect(copy.builtin).toBeNil()
        expect(#copy.stops).toBe(#R:ActiveRoute("deadmines").stops)
    end)
end)

describe("gravador", function()
    it("vira rota com os chefes nas salas em que morreram", function()
        local R, env = load({ id = 36 })
        local Rec = R.Recorder
        Rec:OnEnter("deadmines")
        R:OnSubZone("Goblin Foundry")
        env.Nx.DungeonGuide:NoteKill("Gilnid", nil, 2743)
        R:OnSubZone("Ironclad Cove")
        env.Nx.DungeonGuide:NoteKill("Edwin VanCleef", nil, 2747)
        expect(Rec:CanBuild("deadmines")).toBe(true)
        local route = Rec:Build("deadmines")
        expect(#route.stops).toBe(2)
        expect(route.stops[1].name).toBe("Gilnid")
        expect(route.stops[1].encounters[1]).toBe(2743)
        local foundry = R:RoomNamed("deadmines", "Goblin Foundry")
        local x = R.RoomCenter(foundry, R.RoomMainFloor(foundry))
        expect(math.abs(route.stops[1].x - x) < 0.001).toBe(true)
        expect(#route.paths >= 1).toBe(true)
        expect(R:ActiveRoute("deadmines")).toBe(route)
    end)

    it("a mesma morte duas vezes conta uma", function()
        local R, env = load({ id = 36 })
        R.Recorder:OnEnter("deadmines")
        env.Nx.DungeonGuide:NoteKill("Gilnid", nil, 2743)
        env.Nx.DungeonGuide:NoteKill("Gilnid", nil, 2743)
        local kills = 0
        for _, e in ipairs(R.Recorder:Current().events) do if e.kill then kills = kills + 1 end end
        expect(kills).toBe(1)
    end)

    it("sem morte não há rota", function()
        local R = load({ id = 36 })
        R.Recorder:OnEnter("deadmines")
        R:OnSubZone("Goblin Foundry")
        expect(R.Recorder:CanBuild("deadmines")).toBe(false)
    end)

    it("outra masmorra ou pausa longa começa outra gravação", function()
        local R = load({ id = 36 })
        R.Recorder:OnEnter("deadmines")
        local first = R.Recorder:Current()
        R.Recorder:OnEnter("deadmines")
        expect(R.Recorder:Current()).toBe(first)
        R.Recorder:OnEnter("stockade")
        expect(R.Recorder:Current().key).toBe("stockade")
    end)
end)

describe("compartilhar", function()
    local function share(opts)
        local R, env = load(opts)
        local S = env.Nx.DungeonRouteShare
        local offers = {}
        S.Offer = function(o) offers[#offers + 1] = o end
        return R, env, S, offers
    end

    it("rota padrão vai como uma dica só", function()
        local R, _, S = share()
        local msgs = S:Messages("deadmines", R:ActiveRoute("deadmines"))
        expect(#msgs).toBe(1)
        expect(msgs[1]).toBe("S\tdeadmines\tdefault")
    end)

    it("rota do jogador vai em pedaços e volta inteira", function()
        local R, env, S, offers = share()
        local key, route = env.Nx.DungeonRouteCodec.Import(FDR_TEXT)
        R:AddUserRoute(key, route)
        local msgs = S:Messages(key, route, "abcd")
        expect(#msgs > 1).toBe(true)
        for _, m in ipairs(msgs) do expect(#m <= 255).toBe(true) end
        -- received by another player
        local R2, _, S2, offers2 = share()
        for _, m in ipairs(msgs) do S2:OnMessage("FDRoutes", m, "PARTY", "Outro-Reino") end
        expect(#offers2).toBe(1)
        offers2[1].accept()
        expect(R2:ActiveRoute("deadmines").name).toBe("Minha rota")
        expect(#offers).toBe(0)
    end)

    it("ignora as próprias mensagens", function()
        local _, _, S, offers = share()
        S:OnMessage("FDRoutes", "S\tdeadmines\tdefault", "PARTY", "Eu")
        expect(#offers).toBe(0)
    end)

    it("com o ForeverDungeonRoutes carregado, só ele pergunta", function()
        local _, _, S, offers = share({ fdr = true })
        S:OnMessage("FDRoutes", "S\tdeadmines\tdefault", "PARTY", "Outro")
        expect(#offers).toBe(0)
    end)

    it("pedaço sem cabeçalho ou transferência velha é descartado", function()
        local R, env, S, offers = share()
        local key, route = env.Nx.DungeonRouteCodec.Import(FDR_TEXT)
        R:AddUserRoute(key, route)
        local msgs = S:Messages(key, route, "abcd")
        S:OnMessage("FDRoutes", msgs[2], "PARTY", "Outro")
        expect(#offers).toBe(0)
        S:OnMessage("FDRoutes", msgs[1], "PARTY", "Outro")
        S.Transfers["Outroabcd"].time = -1000
        for i = 2, #msgs do S:OnMessage("FDRoutes", msgs[i], "PARTY", "Outro") end
        expect(#offers).toBe(0)
    end)

    it("ordem dos chefes em linhas de chat", function()
        local R, _, S = share()
        local lines = S:OrderLines("deadmines", R:ActiveRoute("deadmines"))
        expect(lines[1]:find("^Deadmines: 1 Rhahk'Zor, R Miner Johnson, 2 Sneed's Shredder") ~= nil).toBe(true)
    end)
end)

local function loadChart(opts)
    local R, env = load(opts)
    loader.run(env, "Carbonite/Modules/Map/DungeonChart.lua")
    loader.run(env, "Carbonite/Modules/Map/DungeonRouteEditor.lua")
    env.Nx.DungeonRouteEditor.TextWindow = function(_, text, accept) env.LastWindow = { text = text, accept = accept } end
    return R, env, env.Nx.DungeonChart, env.Nx.DungeonRouteEditor
end

describe("mapa da masmorra com rota", function()
    it("andares da rota com a arte do minimapa do cliente", function()
        local _, _, DC = loadChart()
        local map = DC.RouteMap("alcazprison")
        expect(#map.floors).toBe(2)
        expect(map.floors[2].fdr).toBe(1029942)
        expect(map.floors[2].key).toBe("900003_2")
        expect(#map.floors[1].minimap > 0).toBe(true)
        expect(DC.FloorIndex(map, 1029942)).toBe(2)
    end)

    it("a fonte do mapa é a rota dentro da masmorra", function()
        local _, _, DC = loadChart({ id = 36 })
        local api = DC.Routes()
        expect(api.CurrentDungeon()).toBe("deadmines")
        expect(api.DUNGEON_MAPS.deadmines.isRoute).toBe(true)
    end)

    it("abre no andar da sala atual", function()
        local R, _, DC = loadChart({ id = 36 })
        R:OnSubZone("Goblin Foundry")
        expect(DC.RouteStartFloor("deadmines", DC.RouteMap("deadmines"))).toBe(2)
    end)

    it("chefes, paradas, notas e ligações do andar", function()
        local _, _, DC = loadChart()
        local view = DC.RouteView("deadmines", DC.RouteMap("deadmines"), 1)
        expect(#view.bosses).toBe(6)
        expect(view.bosses[4].floor).toBe(2)
        local rare = false
        for _, e in ipairs(view.extras) do if e.num == "R" then rare = true end end
        expect(rare).toBe(true)
        expect(#view.legs > 0).toBe(true)
    end)
end)

describe("editor de rotas", function()
    it("editar a rota padrão faz uma cópia", function()
        local R, _, _, E = loadChart()
        local route = E:Start("deadmines")
        expect(R.IsBuiltIn(route)).toBe(false)
        expect(route.name).toBe("Standard route (copy)")
        expect(R.IsBuiltIn(R:Routes("deadmines")[1])).toBe(true)
        expect(R:ActiveRoute("deadmines")).toBe(route)
    end)

    it("caminho: pontos, trecho novo com Shift, desfazer", function()
        local _, _, _, E = loadChart()
        local route = E:Start("deadmines")
        local before = #route.paths
        E:SetTool("main")
        E:OnMapClick("LeftButton", 291, .1, .1)
        E:OnMapClick("LeftButton", 291, .2, .2)
        expect(#route.paths).toBe(before + 1)
        expect(#route.paths[before + 1].pts).toBe(4)
        E:OnMapClick("LeftButton", 291, .3, .3, true)
        expect(#route.paths).toBe(before + 2)
        E:OnMapClick("RightButton", 291, 0, 0)
        expect(#route.paths).toBe(before + 1)
        E:Undo()
        expect(#route.paths).toBe(before + 2)
        expect(route.paths[before + 1].t0 ~= nil).toBe(true)
    end)

    it("parada com nome de chefe vira o chefe; sem, opcional", function()
        local _, env, _, E = loadChart()
        local route = E:Start("deadmines")
        local n = #route.stops
        E:SetTool("stop")
        E:OnMapClick("LeftButton", 291, .5, .5)
        env.LastWindow.accept("Gilnid")
        expect(route.stops[n + 1].kind).toBe("boss")
        expect(route.stops[n + 1].encounters[1]).toBe(2743)
        E:OnPinClick({ kind = "stop", index = n + 1 }, "LeftButton")
        env.LastWindow.accept("Baú")
        expect(route.stops[n + 1].kind).toBe("optional")
        E:OnPinClick({ kind = "stop", index = n + 1 }, "RightButton")
        expect(#route.stops).toBe(n)
    end)

    it("importar pela janela de texto", function()
        local R, env, _, E = loadChart()
        E:Import()
        env.LastWindow.accept(FDR_TEXT)
        expect(R:ActiveRoute("deadmines").name).toBe("Minha rota")
    end)
end)
