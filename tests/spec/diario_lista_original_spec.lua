-- Diário de missões no layout do diário original do jogo (#42, R10): na aba
-- Atual do tema Blizzard, barras de zona, ícone redondo, objetivos sob o
-- título, Play do Spoken, (tag) e caixa de acompanhar à direita.

local function src()
    return (loader.read("Carbonite.Quests/QuestWindow.lua"):gsub(string.char(13), ""))
end

local function has(s, needle)
    return s:find(needle, 1, true) ~= nil
end

local function window(gameStyle, env)
    env = env or wow.lenientEnv()
    env.Carbonite.UI = { Skin = {
        GetToken = function() return 1, 1, 1, 1 end,
        GameStyle = function() return gameStyle end,
    } }
    env.Nx = wow.namespace({ Quest = wow.namespace(), List = {}, Window = {} })
    loader.run(env, "Carbonite.Quests/QuestWindow.lua")
    return env.Nx.Quest.List, env
end

describe("diário original: texto das linhas", function()
    it("objetivo no formato -0/1 Objetivo", function()
        local QList = window(true)
        expect(QList.ObjectiveText("Cabeça de Arugal: 0/1")).toBe("-0/1 Cabeça de Arugal")
        expect(QList.ObjectiveText("Madeireiro da Empreendimentos S.A.: 3/15")).toBe("-3/15 Madeireiro da Empreendimentos S.A.")
        expect(QList.ObjectiveText("Encontre o Sicário Admeto.")).toBe("-Encontre o Sicário Admeto.")
        expect(QList.ObjectiveText(nil)).toBe("-?")
    end)

    it("a marca de tipo fica entre parênteses na cor da missão", function()
        local QList = window(true)
        expect(QList.GameTag("Masmorra", "|cffffff00")).toBe("|cffffff00(Masmorra)")
        expect(QList.GameTag(nil, "|cffffff00")).toBe("")
        expect(QList.GameTag("", "|cffffff00")).toBe("")
    end)
end)

describe("diário original: escopo", function()
    it("vale só para a aba Atual do tema Blizzard", function()
        local QList = window(true)
        expect(QList.GameRows(1)).toBe(true)
        expect(QList.GameRows(2)).toBe(false)
        expect(QList.GameRows(3)).toBe(false)
        expect(QList.GameRows(4)).toBe(false)
        expect(window(false).GameRows(1)).toBe(false)
    end)

    it("as colunas abrem espaço para o ícone de 20 px e a caixa de seleção", function()
        local QList = window(true)
        local w = { 20, 300, 0, 185 }
        local l = {
            NxGameRows = true,
            GetLineH = function() return 22 end,
            ColumnGetWidth = function(_, id) return w[id] end,
            ColumnSetWidth = function(_, id, v) w[id] = v end,
        }
        expect(QList.FitColumns(l, 600)).toBe(true)
        expect(w[1]).toBe(26)
        expect(w[4]).toBe(QList.GAME_TAG_W)
        expect(w[2]).toBe(600 - 26 - QList.GAME_TAG_W - QList.GAME_CHECK_W - 10 - 4)
        expect(QList.FitColumns(l, 600)).toBe(false)
        -- Nos outros temas a linha continua com etiqueta e XP.
        l.NxGameRows = nil
        expect(QList.FitColumns(l, 600)).toBe(true)
        expect(w[1]).toBe(20)
        expect(w[4]).toBe(185)
    end)
end)

describe("diário original: montagem da aba Atual", function()
    local s = src()

    it("o cabeçalho de zona vira barra de seção com o nome em bege", function()
        expect(has(s, "if show and gameRows then")).toBe(true)
        expect(has(s, "list:ItemSet (2, QList.GAME_INK .. header)")).toBe(true)
        expect(has(s, "list:ItemSetSection (not Quest.HeaderHide[cur.Header])")).toBe(true)
        -- Os outros temas mantêm a faixa com o botão +/-.
        expect(has(s, "list:ItemSet (2, headerInk .. header)")).toBe(true)
    end)

    it("ícone redondo do Monitor e nada de faixas alternadas nem XP", function()
        expect(has(s, 'butType = isComplete == 1 and "QuestWatchDone" or "QuestWatchProgTog"')).toBe(true)
        expect(has(s, "list:ItemSet (4, QList.GameTag (tag, color))")).toBe(true)
        local game = s:match("if gameRows then\n%s*%-%- No stripes and no XP.-\n%s*else")
        expect(game ~= nil).toBe(true)
        expect(has(game, "XPText")).toBe(false)
        expect(has(game, "rowStripe")).toBe(false)
    end)

    it("objetivos sempre listados, sem os pontos de rastreio", function()
        expect(has(s, "if self.QOpts.NXShowObj or gameRows then")).toBe(true)
        expect(has(s, "QList.ObjectiveText (desc)")).toBe(true)
        expect(has(s, 'if zone and not gameRows then')).toBe(true)
        -- Sem objetivos, o texto curto do objetivo ou da entrega.
        expect(has(s, "local objText = gameRows and num == 0 and cur.ObjText")).toBe(true)
    end)

    it("fonte maior: título no papel title e objetivos um ponto abaixo", function()
        expect(has(s, 'local font = game and "Role.title" or "Quest.QuestFont"')).toBe(true)
        expect(has(s, "obj:SetFont (face, max (size - 1, 6), flags or \"\")")).toBe(true)
    end)

    it("a caixa de seleção usa a ação de acompanhar no Monitor", function()
        expect(has(s, "qlist:ToggleWatchMembership (b.NxQId, b.NxQi)")).toBe(true)
        expect(has(s, '"Interface\\\\Buttons\\\\UI-CheckBox-Check"')).toBe(true)
    end)

    it("os widgets seguem cada redesenho da lista, inclusive a rolagem", function()
        expect(has(s, "Nx.List.Update (l, showLast)")).toBe(true)
        expect(has(s, "self:DecorateRows (l)")).toBe(true)
    end)
end)

describe("diário original: caixas de seleção nas linhas", function()
    local function fontString(text)
        local f = { text = text }
        function f:SetFontObject(o) self.font = o end
        function f:GetText() return self.text end
        function f:GetStringWidth() return #(self.text or "") * 6 end
        return f
    end

    local function setup(game)
        local env = wow.lenientEnv()
        local made = {}
        env.CreateFrame = function()
            local c = wow.frame()
            c.points = {}
            c.SetChecked = function(self, on) self.checked = on end
            c.SetPoint = function(self, ...) self.points[#self.points + 1] = { ... } end
            made[#made + 1] = c
            return c
        end
        local QList = window(game, env)
        local col = { Width = 100, FontObj = "colFont" }
        local list = {
            NxGameRows = game, Vis = 3, Top = 1, Num = 3, HdrH = 6,
            Columns = { col, col, col, col },
            Strs = {},
            Frm = wow.frame(),
            GetLineH = function() return 22 end,
        }
        list.Frm.GetFrameLevel = function() return 1 end
        for i = 1, 12 do list.Strs[i] = fontString("") end
        local q = setmetatable({ Checks = {}, RowInfo = {
            [1] = { QId = 800, Qi = 3, Watched = true },
            [2] = { Obj = true },
            [3] = { QId = 801, Qi = 4, Watched = false },
        } }, { __index = QList })
        return q, list, made
    end

    it("cria uma caixa por missão, marcada quando acompanhada", function()
        local q, list, made = setup(true)
        q:DecorateRows(list)
        expect(#made).toBe(2)
        expect(made[1].checked).toBe(true)
        expect(made[1].NxQId).toBe(800)
        expect(made[2].checked).toBe(false)
        expect(made[2].NxQi).toBe(4)
        expect(made[1].shown).toBe(true)
    end)

    it("fora do layout do jogo, esconde as caixas", function()
        local q, list, made = setup(true)
        q:DecorateRows(list)
        list.NxGameRows = false
        q:DecorateRows(list)
        expect(made[1].shown).toBe(false)
        expect(made[2].shown).toBe(false)
        -- Os textos voltam à fonte da coluna.
        expect(list.Strs[5].font).toBe("colFont")
    end)
end)

describe("diário original: Play do Spoken à direita do título", function()
    local function button()
        local b = { shown = false }
        function b:SetSize(w) self.size = w end
        function b:ClearAllPoints() end
        function b:SetPoint(_, _, _, x, y) self.x, self.y = x, y end
        function b:Show() self.shown = true end
        function b:Hide() self.shown = false end
        return b
    end

    local function load(recorded)
        local env = wow.lenientEnv(nil, { "Spoken" })
        local calls = { made = 0, bound = {} }
        env.GetTime = function() return 0 end
        env.hooksecurefunc = function() end
        env.C_QuestLog = { GetTitleForQuestID = function(id) return "Quest " .. id end }
        env.VoiceOver = { QuestOverlayUI = {
            MakePlayButton = function() calls.made = calls.made + 1 return button() end,
            ShowsTrackerButton = function(_, id) return recorded[id] or false end,
            BindPlayButton = function(_, b, id) b.bound = id; calls.bound[#calls.bound + 1] = id end,
            SetPlayButtonState = function() end,
            FollowQueue = function() end,
        } }
        env.Nx = wow.namespace({ List = { Update = function() end }, Quest = wow.namespace({ CurQ = {} }) })
        loader.run(env, "Carbonite.Quests/SpokenPlay.lua")
        return env.Nx.Quest.SpokenPlay, calls
    end

    local function list()
        return { Top = 1, Vis = 3, Num = 3, HdrH = 6, Frm = {}, GetLineH = function() return 22 end }
    end

    it("põe o Play só nas linhas de título de missões narradas", function()
        local SP, calls = load({ [800] = true })
        local titles = { [1] = 800, [3] = 801 }
        SP:SweepLog(list(), function(line) return titles[line] end, function() return 200 end)
        expect(calls.made).toBe(1)
        expect(calls.bound[1]).toBe(800)
    end)

    it("posiciona pelo xOf e esconde com a lista nula", function()
        local SP = load({ [800] = true })
        local made
        SP:SweepLog(list(), function(line) return line == 1 and 800 or nil end, function(_, size)
            made = size
            return 300
        end)
        expect(made ~= nil).toBe(true)
        SP:SweepLog(nil)
    end)
end)
