-- Carbonite/Modules/Assistant/Assistant.lua: assistente de primeira execução da edição (#63)

local function load(over)
    over = over or {}
    local env = wow.lenientEnv({ C_AddOns = { IsAddOnLoaded = function(name) return (over.addons or {})[name] == true end } })
    local calls = { keys = 0, skins = {}, reload = 0, options = 0, folders = 0, slash = {} }
    env.Nx = {
        db = { profile = over.profile or { Version = {}, Map = {}, MiniMap = {}, Skin = {} } },
        Map = {
            ApplyMapKeyOverrides = function() calls.keys = calls.keys + 1 end,
            Maps = { { Guide = { UpdateGatherFolders = function() calls.folders = calls.folders + 1 end } } },
        },
        Skin = { Set = function(_, name) calls.skins[#calls.skins + 1] = name end },
        Opts = {
            NXCmdReload = function() calls.reload = calls.reload + 1 end,
            Open = function() calls.options = calls.options + 1 end,
        },
    }
    if over.noDb then env.Nx.db = nil end
    env.Carbonite.Core.SlashCommands = {
        Register = function(_, cmd, fn, help) calls.slash[cmd] = { fn = fn, help = help } end,
    }
    loader.run(env, "Carbonite/Modules/Assistant/Assistant.lua")
    local A = env.Carbonite.Modules.Assistant
    -- The window needs the client; the flow is what is tested here.
    A.Build = function(self) self.frame = wow.frame("CarboniteAssistant") end
    A.Render = function(self) calls.rendered = self.page end
    return A, env.Nx.db and env.Nx.db.profile, calls
end

describe("assistente: quando abre", function()
    it("abre na primeira vez do perfil e não abre de novo depois de concluído", function()
        local A, profile = load()
        expect(A:ShouldShow()).toBe(true)
        expect(A:AutoShow()).toBe(true)
        expect(A.frame.shown).toBe(true)
        A:Finish(false)
        expect(profile.Version.Assistant).toBe(A.VERSION)
        expect(A.frame.shown).toBe(false)
        expect(A:ShouldShow()).toBe(false)
        expect(A:AutoShow()).toBe(false)
    end)

    it("Pular marca como visto", function()
        local A, profile = load()
        A:AutoShow()
        A:Skip()
        expect(profile.Version.Assistant).toBe(A.VERSION)
        expect(A:AutoShow()).toBe(false)
    end)

    it("fechar a janela (X ou ESC) também conclui", function()
        local src = loader.read("Carbonite/Modules/Assistant/Assistant.lua")
        expect(src:find('SetScript("OnHide", function() Assistant:Finish(false) end)', 1, true) ~= nil).toBe(true)
        expect(src:find('tinsert(_G.UISpecialFrames, "CarboniteAssistant")', 1, true) ~= nil).toBe(true)
    end)

    it("não abre antes do banco salvo existir", function()
        local A = load({ noDb = true })
        expect(A:ShouldShow()).toBe(false)
        expect(A:AutoShow()).toBe(false)
        expect(A.frame).toBeNil()
    end)

    it("/carb assistente reabre mesmo depois de visto, na primeira página", function()
        local A, _, calls = load({ profile = { Version = { Assistant = 1 }, Map = {}, MiniMap = {}, Skin = {} } })
        expect(calls.slash.assistente ~= nil).toBe(true)
        expect(calls.slash.assistente.help).toBe("open the setup assistant")
        calls.slash.assistente.fn("")
        expect(A.frame.shown).toBe(true)
        expect(calls.rendered).toBe(1)
    end)

    it("substitui a pergunta antiga do minimapa (QuickVer) das opções", function()
        local src = loader.read("Carbonite/Modules/Options/OptionsEngine.lua")
        expect(src:find("Version.QuickVer = ", 1, true)).toBeNil()
        expect(src:find("Put the game minimap into the Carbonite map?", 1, true)).toBeNil()
        expect(src:find("Assistant:AutoShow()", 1, true) ~= nil).toBe(true)
        expect(loader.read("Carbonite/Modules/Modules.xml"):find('Assistant\\Assistant.lua', 1, true) ~= nil).toBe(true)
    end)
end)

describe("assistente: cada escolha grava a chave das opções", function()
    it("mapa no M: Map.MaxOverride e reaplica a tecla", function()
        local A, profile, calls = load()
        A:Choose("map", false)
        expect(profile.Map.MaxOverride).toBe(false)
        A:Choose("map", true)
        expect(profile.Map.MaxOverride).toBe(true)
        expect(calls.keys).toBe(2)
        expect(A:Get("map")).toBe(true)
    end)

    it("minimapa integrado: MiniMap.Own com ButOwn e ShowOldNameplate, como a opção", function()
        local A, profile = load()
        A:Choose("minimap", true)
        expect(profile.MiniMap.Own).toBe(true)
        expect(profile.MiniMap.ButOwn).toBe(true)
        expect(profile.MiniMap.ShowOldNameplate).toBe(false)
        A:Choose("minimap", false)
        expect(profile.MiniMap.Own).toBe(false)
        expect(profile.MiniMap.ButOwn).toBe(false)
        expect(profile.MiniMap.ShowOldNameplate).toBe(true)
    end)

    it("tema: Skin.Name e aplica o tema", function()
        local A, profile, calls = load()
        A:Choose("theme", "Modern Dark")
        expect(profile.Skin.Name).toBe("Modern Dark")
        expect(calls.skins[1]).toBe("Modern Dark")
        A:Choose("theme", "Blizzard")
        expect(A:Get("theme")).toBe("Blizzard")
    end)

    it("quem dá quests: Map.QuestGiversAvailable e redesenha o mapa", function()
        local A, profile, calls = load()
        A:Choose("givers", true)
        expect(profile.Map.QuestGiversAvailable).toBe(true)
        A:Choose("givers", false)
        expect(profile.Map.QuestGiversAvailable).toBe(false)
        expect(calls.folders).toBe(2)
    end)

    it("não cria chaves próprias além da marca de visto", function()
        local A, profile = load()
        A:Open(1)
        for _, id in ipairs({ "map", "minimap", "givers" }) do A:Choose(id, true) end
        A:Choose("theme", "Blizzard")
        A:Finish(false)
        local sections = {}
        for k in pairs(profile) do sections[#sections + 1] = k end
        table.sort(sections)
        expect(table.concat(sections, ",")).toBe("Map,MiniMap,Skin,Version")
        local versionKeys = {}
        for k in pairs(profile.Version) do versionKeys[#versionKeys + 1] = k end
        expect(table.concat(versionKeys, ",")).toBe("Assistant")
    end)

    it("pede para recarregar só quando o minimapa mudou", function()
        local A, _, calls = load()
        A:Open(1)
        A:Choose("map", true)
        A:Finish(false)
        expect(calls.reload).toBe(0)
        A:Open(2)
        A:Choose("minimap", true)
        A:Finish(false)
        expect(calls.reload).toBe(1)
        A:Open(2)
        A:Choose("minimap", false)
        A:Choose("minimap", true)
        A:Finish(false)
        expect(calls.reload).toBe(1)
    end)

    it("Abrir opções conclui e abre as opções", function()
        local A, profile, calls = load()
        A:AutoShow()
        A:Finish(true)
        expect(profile.Version.Assistant).toBe(A.VERSION)
        expect(calls.options).toBe(1)
    end)
end)

describe("assistente: páginas e integrações", function()
    it("tem de 3 a 7 páginas, cada pergunta com duas ou três escolhas e a última com as integrações", function()
        local A = load()
        expect(#A.PAGES >= 3 and #A.PAGES <= 7).toBe(true)
        for i, page in ipairs(A.PAGES) do
            if i < #A.PAGES then expect(#page.choices >= 2 and #page.choices <= 3).toBe(true) end
        end
        expect(A.PAGES[#A.PAGES].id).toBe("integrations")
    end)

    it("detecta as integrações pelo addon carregado ou pelo global que ele cria", function()
        local A, _, _ = load({ addons = { GatherLite = true, TomTom = true } })
        local byName = {}
        for _, item in ipairs(A:Integrations()) do byName[item.addon] = item end
        for _, name in ipairs({ "QuestieDB", "Questie", "Spoken", "ForeverDungeonJournal", "GatherLite", "TomTom", "MapUtils" }) do
            expect(byName[name] ~= nil).toBe(true)
            expect(type(byName[name].what)).toBe("string")
        end
        expect(byName.GatherLite.active).toBe(true)
        expect(byName.TomTom.active).toBe(true)
        expect(byName.Spoken.active).toBe(false)
    end)
end)

describe("assistente: botões da última página", function()
    local src = loader.read("Carbonite/Modules/Assistant/Assistant.lua")

    it("Voltar fica à esquerda de Abrir opções, não por cima dele", function()
        expect(src:find('self.backBut:SetPoint("RIGHT", last and self.optionsBut or self.nextBut, "LEFT", -8, 0)', 1, true) ~= nil).toBe(true)
        expect(src:find("shown(self.skipBut, not last)", 1, true) ~= nil).toBe(true)
    end)
end)

-- Página "Quem guia você até o destino" e reabertura a cada versão (#222/#223)
local function loadNav(over)
    over = over or {}
    local addons = over.addons or {}
    local env = wow.lenientEnv({
        C_AddOns = {
            IsAddOnLoaded = function(name) return addons[name] == true end,
            DoesAddOnExist = function(name) return addons[name] == true end,
            GetAddOnEnableState = function(name) return addons[name] and 2 or 0 end,
        },
        UnitGUID = function() return "Player-1" end,
    })
    local calls = { reload = 0, after = 0 }
    env.Nx = {
        db = { profile = over.profile or { Version = {}, Map = {}, MiniMap = {}, Skin = {}, Track = {} } },
        Map = { ApplyMapKeyOverrides = function() end, Maps = { {} } },
        Skin = { Set = function() end },
        Opts = { NXCmdReload = function() calls.reload = calls.reload + 1 end, Open = function() end },
    }
    env.Carbonite.Core.SlashCommands = { Register = function() end }
    env.Carbonite.Modules.Comm = { VersionCheck = { MyVersion = function() return over.version end } }
    loader.run(env, "Carbonite/Modules/Integrations/Navigator.lua")
    loader.run(env, "Carbonite/Modules/Assistant/Assistant.lua")
    local A = env.Carbonite.Modules.Assistant
    A.Build = function(self) self.frame = wow.frame("CarboniteAssistant") end
    A.Render = function() end
    return A, env.Nx.db.profile, calls
end

local function navPage(A)
    for i, page in ipairs(A.PAGES) do
        if page.id == "navigator" then return page, i end
    end
end

describe("assistente: quem guia até o destino", function()
    it("tem a página com Carbonite, TomTom e Shortest Path Forever, antes das integrações", function()
        local A = loadNav()
        local page, index = navPage(A)
        expect(page ~= nil).toBe(true)
        expect(index).toBe(#A.PAGES - 1)
        expect(page.choices[1].value).toBe("carbonite")
        expect(page.choices[2].value).toBe("tomtom")
        expect(page.choices[3].value).toBe("spf")
    end)

    it("addon não instalado não pode ser escolhido", function()
        local A, profile = loadNav()
        A:Open(1)
        A:Choose("navigator", "spf")
        expect(profile.Track.Navigator).toBeNil()
        expect(A:ChoiceAvailable("navigator", "spf")).toBe(false)
        expect(A:ChoiceAvailable("navigator", "carbonite")).toBe(true)
    end)

    it("escolher grava Track.Navigator e pede para recarregar ao concluir", function()
        local A, profile, calls = loadNav({ addons = { ShortestPathForever = true } })
        A:Open(1)
        A:Choose("navigator", "spf")
        expect(profile.Track.Navigator).toBe("spf")
        A:Finish(false)
        expect(calls.reload).toBe(1)
    end)

    it("sem mudar a escolha, não recarrega", function()
        local A, _, calls = loadNav({ addons = { ShortestPathForever = true } })
        A:Open(1)
        A:Finish(false)
        expect(calls.reload).toBe(0)
    end)

    it("avisa das duas setas quando o SPF está instalado e não é o escolhido", function()
        local A, profile = loadNav({ addons = { ShortestPathForever = true } })
        expect(A:Note("navigator") ~= nil).toBe(true)
        profile.Track.Navigator = "spf"
        expect(A:Note("navigator")).toBeNil()
        expect(A:Note("map")).toBeNil()
    end)
end)

describe("assistente: abre de novo a cada versão", function()
    it("versão nova reabre; a mesma versão não", function()
        local A, profile = loadNav({ version = "v1.2.0" })
        expect(A:ShouldShow()).toBe(true)
        A:AutoShow()
        A:Finish(false)
        expect(profile.Version.AssistantSeen).toBe("v1.2.0")
        expect(A:ShouldShow()).toBe(false)
        profile.Version.AssistantSeen = "v1.1.0"
        expect(A:ShouldShow()).toBe(true)
    end)

    it("escolha salva desinstalada reabre e, ao concluir, volta ao Carbonite", function()
        local A, profile = loadNav({ version = "v1.2.0" })
        profile.Version = { Assistant = A.VERSION, AssistantSeen = "v1.2.0" }
        profile.Track.Navigator = "tomtom"
        expect(A:ShouldShow()).toBe(true)
        A:AutoShow()
        A:Finish(false)
        expect(profile.Track.Navigator).toBe("carbonite")
        expect(A:ShouldShow()).toBe(false)
    end)

    it("o Novidades espera o assistente fechar", function()
        local A = loadNav({ version = "v1.2.0" })
        local opened = 0
        A:AutoShow()
        A.afterFinish = function() opened = opened + 1 end
        A:Finish(false)
        expect(opened).toBe(1)
        local src = loader.read("Carbonite/Modules/MainUpdater/NXOnUpdate.lua")
        expect(src:find("Assistant.afterFinish = showWhatsNew", 1, true) ~= nil).toBe(true)
    end)
end)

describe("assistente: ícones do mapa (#247)", function()
    local function iconsPage(A)
        for i, page in ipairs(A.PAGES) do
            if page.id == "icons" then return page, i end
        end
    end

    it("tem a página logo depois da aparência, com Blizzard, clássicos e MapNotes", function()
        local A = load()
        local page, index = iconsPage(A)
        expect(page ~= nil).toBe(true)
        expect(A.PAGES[index - 1].id).toBe("theme")
        expect(page.choices[1].value).toBe("blizzard")
        expect(page.choices[2].value).toBe("classic")
        expect(page.choices[3].value).toBe("mapnotes")
    end)

    it("clássicos grava Map.ClassicIcons e mantém os pontos do Carbonite", function()
        local A, profile = load()
        A:Open(1)
        A:Choose("icons", "classic")
        expect(profile.Map.ClassicIcons).toBe(true)
        expect(profile.Map.ShowPOI).toBe(true)
        expect(A:Get("icons")).toBe("classic")
        A:Choose("icons", "blizzard")
        expect(profile.Map.ClassicIcons).toBe(false)
        expect(A:Get("icons")).toBe("blizzard")
    end)

    it("sem o HandyNotes e o MapNotes, o MapNotes não pode ser escolhido", function()
        local A, profile = load({ addons = { HandyNotes = true } })
        A:Open(1)
        expect(A:ChoiceAvailable("icons", "mapnotes")).toBe(false)
        A:Choose("icons", "mapnotes")
        expect(profile.Map.ShowPOI).toBeNil()
        expect(A:ChoiceAvailable("icons", "classic")).toBe(true)
    end)

    it("MapNotes liga o HandyNotes no mapa e esconde os pontos do Carbonite", function()
        local A, profile = load({ addons = { HandyNotes = true, HandyNotes_MapNotes = true } })
        local notes = { HandyNotes = false }
        A.NotesProfile = function() return notes end
        A:Open(1)
        A:Choose("icons", "mapnotes")
        expect(notes.HandyNotes).toBe(true)
        expect(profile.Map.ShowPOI).toBe(false)
        expect(profile.Map.ClassicIcons).toBe(false)
        expect(A:Get("icons")).toBe("mapnotes")
    end)

    it("MapNotes desinstalado depois: a escolha lida volta aos ícones do Carbonite", function()
        local A, profile = load({ addons = {} })
        profile.Map.ShowPOI = false
        expect(A:Get("icons")).toBe("blizzard")
    end)

    it("o HandyNotes aparece na lista de integrações", function()
        local A = load({ addons = { HandyNotes = true } })
        local found
        for _, item in ipairs(A:Integrations()) do
            if item.addon == "HandyNotes" then found = item end
        end
        expect(found ~= nil and found.active).toBe(true)
    end)
end)
