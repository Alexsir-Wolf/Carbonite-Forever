-- Diário de quests no padrão do registro de missões do jogo (#48)

local function window(atlases, tokens)
    local env = wow.lenientEnv()
    env.C_Texture = { GetAtlasInfo = function(name) return (atlases or {})[name] and {} or nil end }
    env.Carbonite.UI = { Skin = { GetToken = function(_, name)
        local c = (tokens or {})[name] or { 1, 1, 1, 1 }
        return c[1], c[2], c[3], c[4]
    end } }
    env.Nx = wow.namespace({ Quest = wow.namespace(), List = {}, Window = {} })
    loader.run(env, "Carbonite.Quests/QuestWindow.lua")
    return env.Nx.Quest.List
end

local function texture()
    local t = { shown = false }
    function t:ClearAllPoints() end
    function t:SetPoint() end
    function t:SetHeight(h) self.h = h end
    function t:Show() self.shown = true end
    function t:Hide() self.shown = false end
    return t
end

local function list()
    local env = wow.lenientEnv()
    env.Carbonite.UI = { Skin = { Paint = function(_, t, token) t.token = token end } }
    env.Nx = wow.namespace()
    loader.run(env, "Carbonite/Modules/UI/UIEngine.lua")
    local frm = { CreateTexture = function() return texture() end }
    -- Só os métodos do Nx.List: campos ausentes ficam nil (o namespace criaria tabelas)
    local List = env.Nx.List
    return setmetatable({ Num = 0, Data = {}, Columns = {}, Top = 1, Vis = 3, Frm = frm, UsedFrms = {} },
        { __index = function(_, k) return rawget(List, k) end })
end

describe("diário de quests: ícone de estado", function()
    it("usa o atlas do cliente quando existe", function()
        local icon = window({ QuestTurnin = true }).StateIcon("complete")
        expect(icon:find("|A:QuestTurnin:", 1, true) ~= nil).toBe(true)
    end)

    it("sem o atlas, fica no ícone de diálogo que todo cliente tem", function()
        local icon = window({}).StateIcon("complete")
        expect(icon:find("|TInterface\\GossipFrame\\ActiveQuestIcon", 1, true) ~= nil).toBe(true)
        expect(window({}).StateIcon("available"):find("AvailableQuestIcon", 1, true) ~= nil).toBe(true)
    end)

    it("tenta os atlases na ordem e ignora estado desconhecido", function()
        local QList = window({ ["common-icon-checkmark"] = true })
        expect(QList.StateIcon("done"):find("|A:common-icon-checkmark:", 1, true) ~= nil).toBe(true)
        expect(QList.StateIcon("whatever")).toBe("")
    end)
end)

describe("diário de quests: texto da linha", function()
    it("a cor do cabeçalho vem do token do tema, não de cor fixa", function()
        local QList = window({}, { title = { 1, 0.82, 0, 1 } })
        expect(QList.Ink("title")).toBe("|cffffd100")
        QList = window({}, { title = { 0.10, 0.12, 0.20, 1 } })
        expect(QList.Ink("title")).toBe("|cff1a1f33")
    end)

    it("mostra [nível] título na cor de dificuldade", function()
        local QList = window()
        expect(QList.LevelTitle(22, "O clamor da água", "|cffffff00")).toBe("|cffffff00[22] O clamor da água")
        expect(QList.LevelTitle(0, "Sem nível", "|cffffff00")).toBe("|cffffff00Sem nível")
    end)
end)

describe("diário de quests: colunas", function()
    local function fakeList()
        local w = { 20, 300, 0, 600 }
        return {
            ColumnGetWidth = function(_, id) return w[id] end,
            ColumnSetWidth = function(_, id, v) w[id] = v end,
            w = w,
        }
    end

    it("o título ocupa a linha e etiqueta e XP ficam na borda direita", function()
        local QList, l = window(), fakeList()
        expect(QList.FitColumns(l, 600)).toBe(true)
        expect(l.w[2]).toBe(600 - 20 - 185 - 10 - 4)
        expect(l.w[4]).toBe(185)   -- cabe "Masmorra 5.350 XP"
        expect(QList.FitColumns(l, 600)).toBe(false)
        expect(QList.FitColumns(l, 0)).toBe(false)
    end)

    it("a coluna de etiqueta e XP é alinhada à direita", function()
        local src = loader.read("Carbonite.Quests/QuestWindow.lua")
        expect(src:find('list:ColumnAdd ("", 4, TAG_COLUMN_W, "RIGHT")', 1, true) ~= nil).toBe(true)
        expect(src:find("list:ItemSet (4, (tag or \"\") .. Quest:XPText (qId))", 1, true) ~= nil).toBe(true)
    end)
end)

describe("diário de quests: cabeçalho e linhas", function()
    local src = loader.read("Carbonite.Quests/QuestWindow.lua")

    it("o cabeçalho de zona é uma barra recolhível com +/-", function()
        expect(src:find('list:ItemSetButton ("QuestLogHdr", Quest.HeaderHide[cur.Header])', 1, true) ~= nil).toBe(true)
        expect(src:find('list:ItemSetBand ("listHeader")', 1, true) ~= nil).toBe(true)
        expect(src:find("Quest.HeaderHide[hdrCur.Header] = not Quest.HeaderHide[hdrCur.Header] or nil", 1, true) ~= nil).toBe(true)
        local init = loader.read("Carbonite.Quests/Init.lua")
        expect(init:find('["QuestLogHdr"] = { AtlasUp = "QuestLog-icon-shrink", AtlasDn = "QuestLog-icon-expand" }', 1, true) ~= nil).toBe(true)
    end)

    it("linhas alternadas; objetivos na lista só com a opção (a descrição já os mostra)", function()
        expect(src:find('list:ItemSetBand ("rowStripe")', 1, true) ~= nil).toBe(true)
        expect(src:find("if self.QOpts.NXShowObj then", 1, true) ~= nil).toBe(true)
        expect(src:find("if self.QOpts.NXShowObj or selected then", 1, true)).toBeNil()
        expect(src:find("list:Select (keepLine)", 1, true) ~= nil).toBe(true)
    end)

    it("o tema tem a cor das linhas alternadas", function()
        local skin = loader.read("Carbonite/UI/Skin.lua")
        local _, n = skin:gsub("rowStripe%s*=", "")
        expect(n).toBe(3)
    end)
end)

describe("faixas das linhas da lista", function()
    it("pinta a faixa de cada linha com o token e some ao esvaziar", function()
        local l = list()
        l:ItemAdd(1)
        l:ItemSetBand("listHeader")
        l:ItemAdd(2)
        l:ItemAdd(3)
        l:ItemSetBand("rowStripe")
        l:UpdateBands(14, 0)
        expect(l.Bands[1].token).toBe("listHeader")
        expect(l.Bands[1].shown).toBe(true)
        expect(l.Bands[1].h).toBe(14)
        expect(l.Bands[2]).toBeNil()
        expect(l.Bands[3].token).toBe("rowStripe")

        l:Empty()
        l:UpdateBands(14, 0)
        expect(l.Bands[1].shown).toBe(false)
        expect(l.Bands[3].shown).toBe(false)
    end)

    it("aceita a linha pelo índice", function()
        local l = list()
        l:ItemAdd(1)
        l:ItemAdd(2)
        l:ItemSetBand("listHeader", 1)
        expect(l.BandData[1]).toBe("listHeader")
        expect(l.BandData[2]).toBeNil()
    end)
end)
