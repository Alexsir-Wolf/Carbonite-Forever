-- Tema Blizzard nas demais janelas (#42, T10 e T11): diário de missões, Monitor,
-- Info, Destinos, Jornada, Novidades e lista de missões mundiais no padrão do
-- jogo: moldura, faixa de ferramentas ordenada, abas e busca no topo.

-- Sem CR: parte dos arquivos sai do git com CRLF.
local function src(path)
    return (loader.read(path):gsub(string.char(13), ""))
end

local function has(s, needle)
    return s:find(needle, 1, true) ~= nil
end

local function fn(s, pattern)
    return s:match(pattern) or ""
end

-- Abas do diário: tests/spec/diario_abas_topo_spec.lua (faixa de ferramentas).

describe("Monitor de missões", function()
    local watch = src("Carbonite.Quests/WatchWindow.lua")

    it("o Monitor é a única janela transparente: sem moldura, como o rastreador do jogo", function()
        local open = fn(watch, "function Nx%.Quest%.Watch:Open%(%).-\nend\n")
        expect(has(open, "win:UseGameFrame (false)")).toBe(true)
        -- Nem a borda antiga: ela desenhava um quadro em volta do cabeçalho.
        expect(has(open, "win.NoEdgeInGameStyle = true")).toBe(true)
        local fade = fn(src("Carbonite/Modules/UI/UIEngine.lua"), "function Nx%.Window:SetBordersFade %(fade%).-\nend\n")
        expect(has(fade, "(self.NoEdgeInGameStyle and Carbonite.UI.Skin:GameStyle()) and 0")).toBe(true)
        expect(has(open, "self.GameChrome = win.GameFrameOn and true or false")).toBe(true)
        expect(has(open, "self:SetupGameChrome (win)")).toBe(true)
    end)

    it("tem opção própria para a opacidade do fundo (alfa da cor de fundo)", function()
        local opts = src("Carbonite.Quests/Options.lua")
        local block = fn(opts, "qwbgalpha = {.-\n                        },\n")
        expect(has(block, 'type = "range"')).toBe(true)
        expect(has(block, "min = 0")).toBe(true)
        expect(has(block, "QuestWatch.BGColor")).toBe(true)
        expect(has(src("Carbonite.Quests/Locales/ptBR.lua"), 'L["Quest Watch Background Opacity"] = "Opacidade')).toBe(true)
    end)

    it("menus à esquerda e alternâncias à direita na faixa de ferramentas", function()
        local setup = fn(watch, "function Nx%.Quest%.Watch:SetupGameChrome %(win%).-\nend\n")
        expect(has(setup, "win:ArrangeToolBar (items)")).toBe(true)
        expect(has(setup, '{ slot (self.ButMenu), "action" }')).toBe(true)
        expect(has(setup, '{ slot (toggles[i]), "toggle" }')).toBe(true)
        -- Título e contagem na faixa; a segunda linha do título some.
        expect(has(setup, "win:SetHeaderCounter")).toBe(true)
        expect(has(setup, "fs2:Hide()")).toBe(true)
    end)

    it("minimizado usa a moldura compacta, do tamanho da faixa", function()
        local sync = fn(watch, "function Nx%.Quest%.Watch:SyncGameVariant%(%).-\nend\n")
        expect(has(sync, "win:UseGameFrame (isMin and { compact = true } or nil)")).toBe(true)
        expect(has(sync, "spec.band + spec.side")).toBe(true)
    end)

    it("controles com alvo de clique de 22 px no tema Blizzard (antiga #204)", function()
        expect(has(watch, "local WATCH_TARGET = 22")).toBe(true)
        expect(has(watch, "SetHitRectInsets (-k, -k, -k, -k)")).toBe(true)
        local modern = fn(watch, "function Nx%.Quest%.Watch:SetupModernChrome %(win%).-\nend\n")
        expect(has(modern, "big and MODERN_LINE_H_GAME or MODERN_LINE_H")).toBe(true)
        expect(has(modern, "WidenHitRect (but, WATCH_TARGET)")).toBe(true)
    end)

    it("cabeçalho na fonte das missões e as quatro cores juntas", function()
        local modern = fn(watch, "function Nx%.Quest%.Watch:SetupModernChrome %(win%).-\nend\n")
        expect(has(modern, 'fs1:SetFontObject ("NxFontW")')).toBe(true)
        expect(has(modern, 'cnt:SetFontObject ("NxFontW")')).toBe(true)
        expect(has(watch, "local WATCH_TOGGLE_STEP = 16")).toBe(true)
        expect(has(modern, "(#toggles - i) * WATCH_TOGGLE_STEP")).toBe(true)
        expect(has(modern, "WidenHitRect (but, WATCH_TOGGLE_STEP)")).toBe(true)
    end)
end)

describe("WidenHitRect do Monitor", function()
    -- Recorta a função local do arquivo e roda com um botão falso.
    local body = fn(src("Carbonite.Quests/WatchWindow.lua"), "local function WidenHitRect %(but, size%).-\nend\n")
    local chunk = assert(loadstring("local max, floor = math.max, math.floor\n" .. body .. "\nreturn WidenHitRect"))
    local widen = chunk()

    local function but(typ, w)
        local b = { Type = typ, Frm = {} }
        function b.Frm.GetWidth() return w end
        function b.Frm.SetHitRectInsets(_, l) b.inset = l end
        return b
    end

    it("leva o ponto de 10 px a um alvo de 22 px", function()
        local b = but({ SizeUp = 10 }, 13)
        widen(b, 22)
        expect(b.inset).toBe(-6)
    end)

    it("usa o tamanho do primeiro estado nos botões de três estados", function()
        local b = but({ { Size = 10 } }, 13)
        widen(b, 22)
        expect(b.inset).toBe(-6)
    end)

    it("não encolhe um botão já maior que o alvo", function()
        local b = but({}, 30)
        widen(b, 22)
        expect(b.inset).toBe(0)
    end)
end)

describe("janelas de Info: moldura compacta sem cortar as linhas", function()
    local function load()
        local env = wow.lenientEnv()
        env.Nx = wow.namespace({})
        loader.run(env, "Carbonite.Info/NxInfo.lua")
        return env.Nx.Info
    end

    it("pede a compacta antes do layout", function()
        local info = src("Carbonite.Info/NxInfo.lua")
        local create = fn(info, "function Nx%.Info:Create2 %(index%).-\nend\n")
        local use = create:find("win:UseGameFrame ({ compact = true })", 1, true)
        local fit = create:find("Nx.Info.FitGameFrame (win, plainChrome)", 1, true)
        local layout = create:find("win:InitLayoutData", 1, true)
        expect(use ~= nil and fit ~= nil and layout ~= nil).toBe(true)
        expect(use < fit and fit < layout).toBe(true)
    end)

    it("cresce a altura salva uma vez só e devolve sem a moldura", function()
        local Info = load()
        local data = { H = 53 }
        local win = { SaveData = data, GameFrameOn = true, TopH = 25, BorderH = 5 }
        Info.FitGameFrame(win, 19)
        expect(data.H).toBe(64)
        expect(data.GFH).toBe(11)
        Info.FitGameFrame(win, 19)          -- outro login: não soma de novo
        expect(data.H).toBe(64)
        win.GameFrameOn = false             -- outro tema
        Info.FitGameFrame(win, 19)
        expect(data.H).toBe(53)
        expect(data.GFH).toBeNil()
    end)

    it("janela nova não muda: a altura padrão já conta a moldura", function()
        local Info = load()
        local data = {}
        Info.FitGameFrame({ SaveData = data, GameFrameOn = true, TopH = 25, BorderH = 5 }, 19)
        expect(data.H).toBeNil()
        expect(data.GFH).toBe(11)
    end)

    it("altura em fração da tela fica como está", function()
        local Info = load()
        local data = { H = -.2 }
        Info.FitGameFrame({ SaveData = data, GameFrameOn = true, TopH = 25, BorderH = 5 }, 19)
        expect(data.H).toBe(-.2)
    end)
end)

describe("Destinos: ações na faixa de ferramentas", function()
    local function load()
        local env = wow.lenientEnv()
        env.Carbonite.Core.SlashCommands = { Register = function() end }
        env.Nx = wow.namespace({ Map = wow.namespace({ Maps = { { Targets = {} } } }) })
        loader.run(env, "Carbonite/Modules/Map/Targets.lua")
        loader.run(env, "Carbonite/Modules/Map/TargetsWindow.lua")
        return env.Carbonite.Modules.Map.TargetsWindow
    end

    it("remover e limpar tudo são as ações destrutivas", function()
        local W = load()
        local danger = {}
        for _, a in ipairs(W.ACTIONS) do
            if a[4] == "danger" then danger[#danger + 1] = a[2] end
        end
        expect(table.concat(danger, ",")).toBe("Remove,ClearAll")
    end)

    it("na moldura do jogo as ações vão para a faixa, ordenadas", function()
        local s = src("Carbonite/Modules/Map/TargetsWindow.lua")
        expect(has(s, "win:UseGameFrame()")).toBe(true)
        expect(has(s, "local parent = game and win:GetToolBar() or bar")).toBe(true)
        expect(has(s, "win:ArrangeToolBar(items)")).toBe(true)
        expect(has(s, '(game and a[4] ~= "danger") and "TxtGrey" or "Txt64"')).toBe(true)
    end)
end)

describe("Jornada, Novidades e missões mundiais", function()
    it("Jornada: busca no topo, da esquerda, sobre as duas listas", function()
        local s = src("Carbonite/Modules/Journey/Journey.lua")
        expect(has(s, "win:UseGameFrame()")).toBe(true)
        expect(has(s, "win:Attach(box.Frm, game and 0 or .16, 1, 0, 18)")).toBe(true)
        expect(has(s, "win:Attach(groups.Frm, 0, .16, top, 1)")).toBe(true)
    end)

    it("Novidades: categorias na faixa pela ordem padrão", function()
        local s = src("Carbonite/Modules/Whatsnew/WhatsnewEngine.lua")
        expect(has(s, 'items[#items + 1] = { but, "nav" }')).toBe(true)
        expect(has(s, "win:ArrangeToolBar(items)")).toBe(true)
    end)

    it("missões mundiais: o menu sai da faixa de título", function()
        local s = src("Carbonite.Quests/WorldQuestWindow.lua")
        expect(has(s, 'win:ArrangeToolBar({ { self.ButMenu, "action" } })')).toBe(true)
    end)
end)

describe("Opções no painel de Configurações do jogo (R12)", function()
    local s = src("Carbonite/Modules/Options/Options.lua")

    it("no tema Blizzard, Open vai para o painel do jogo", function()
        local open = fn(s, "function Options:Open%(panelId%).-\nend\n")
        expect(has(open, "if gameSettings() then")).toBe(true)
        expect(has(open, "pcall(_G.Settings.OpenToCategory, id)")).toBe(true)
        -- Outros temas, ou sem a API: a janela do Carbonite.
        expect(has(open, 'AceConfigDialog:Open("Carbonite")')).toBe(true)
    end)

    it("cada seção vira subcategoria, e a raiz mostra só o Sobre", function()
        local reg = fn(s, "function Options:RegisterSubcategories%(%).-\nend\n")
        expect(has(reg, '"Carbonite", page.name, ROOT_NAME, page.id')).toBe(true)
        expect(has(reg, 'rootGroup:SetUserData("path", { about })')).toBe(true)
        expect(has(s, '["Quest Watch"] = "Quest Module"')).toBe(true)
    end)
end)

describe("Jornada, Destinos e abas: fonte, colunas e aba ativa", function()
    it("Jornada e Destinos usam a fonte de lista das outras janelas", function()
        local j = src("Carbonite/Modules/Journey/Journey.lua")
        local t = src("Carbonite/Modules/Map/TargetsWindow.lua")
        expect(has(j, 'if game then Nx.List:SetCreateFont("Role.list", 16) end')).toBe(true)
        expect(has(t, 'if game then Nx.List:SetCreateFont("Role.list", 16) end')).toBe(true)
    end)

    it("coluna Nível larga e dica dos Destinos em duas linhas", function()
        expect(has(src("Carbonite/Modules/Journey/Journey.lua"), 'L["Level"], 2, game and 56 or 40')).toBe(true)
        local t = src("Carbonite/Modules/Map/TargetsWindow.lua")
        expect(has(t, 'L["No destinations."]')).toBe(true)
        expect(has(t, 'L["Shift+click Goto on the map to queue several."]')).toBe(true)
    end)

    it("a aba pressionada usa a arte normal, acesa pelo tom dourado", function()
        local ui = src("Carbonite/Modules/UI/UIEngine.lua")
        expect(has(ui, "Nx.Button.ClientAtlases.TxtGreyB = { FileUp = PANEL_UP, FileDn = PANEL_UP")).toBe(true)
        expect(has(ui, [[GlowPressed = "Interface\\Buttons\\UI-Panel-Button-Highlight"]])).toBe(true)
        expect(has(ui, "if typ.GlowPressed and pressed then")).toBe(true)
    end)
end)
