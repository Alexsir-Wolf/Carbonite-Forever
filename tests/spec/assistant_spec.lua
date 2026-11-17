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
    it("tem de 3 a 5 páginas, cada pergunta com duas escolhas e a última com as integrações", function()
        local A = load()
        expect(#A.PAGES >= 3 and #A.PAGES <= 5).toBe(true)
        for i, page in ipairs(A.PAGES) do
            if i < #A.PAGES then expect(#page.choices).toBe(2) end
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
