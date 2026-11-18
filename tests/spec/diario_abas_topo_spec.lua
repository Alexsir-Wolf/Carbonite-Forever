-- Diário de missões no tema Blizzard (#42, R9): as abas viram botões cinza na
-- faixa de ferramentas, no estilo das Notas, com a aba ativa pressionada.

local function src()
    return (loader.read("Carbonite.Quests/QuestWindow.lua"):gsub(string.char(13), ""))
end

local function has(s, needle)
    return s:find(needle, 1, true) ~= nil
end

local function load()
    local env = wow.lenientEnv()
    env.Carbonite.UI = { Skin = {
        GetToken = function() return 1, 1, 1, 1 end,
        TextCode = function() return "|cffffffff" end,
    } }
    env.Nx = wow.namespace({ Quest = wow.namespace(), List = {}, Window = {}, Button = {} })
    local created = {}
    env.Nx.Button.Create = function(_, parent, typ, text, _, _, _, _, w, h, func, user)
        local b = { parent = parent, typ = typ, text = text, h = h, func = func, user = user }
        b.Frm = { w = w, SetWidth = function(self, nw) self.w = nw end }
        b.FStr = { GetStringWidth = function() return #text * 6 end }
        function b:SetId(id) self.Id = id end
        function b:SetPressed(on) self.Pressed = on end
        function b:GetPressed() return self.Pressed end
        function b:SetText(t) self.text = t end
        created[#created + 1] = b
        return b
    end
    loader.run(env, "Carbonite.Quests/QuestWindow.lua")
    local strip = {}
    local win = { arranged = nil }
    function win.GetToolBar() return strip end
    function win:ArrangeToolBar(items) self.arranged = items; return 300, 0 end
    return env.Nx.Quest.List.ToolTabs, win, strip, created
end

describe("diário: abas na faixa de ferramentas (tema Blizzard)", function()
    it("cria um botão cinza de alternância de 22 px por aba, na faixa", function()
        local ToolTabs, win, strip, b = load()
        local tabs = ToolTabs:Create(win, { "Atual", "Histórico", "Banco de dados", "Jogador" })
        expect(#b).toBe(4)
        for i = 1, 4 do
            expect(b[i].typ).toBe("TxtGreyB")
            expect(b[i].h).toBe(22)
            expect(b[i].parent).toBe(strip)
            expect(win.arranged[i][2]).toBe("action")
        end
        expect(tabs.Width).toBe(300)
        -- O rótulo longo alarga o botão; o curto fica na largura mínima.
        expect(b[3].Frm.w > ToolTabs.MinW).toBe(true)
        expect(b[1].Frm.w).toBe(ToolTabs.MinW)
    end)

    it("só a aba ativa fica pressionada, e trocar de aba avisa a janela", function()
        local ToolTabs, win, _, b = load()
        local tabs = ToolTabs:Create(win, { "Atual", "Histórico", "Banco de dados", "Jogador" })
        local got = {}
        tabs:SetUser({}, function(_, i) got[#got + 1] = i end)
        tabs:SetActive(1)
        expect(b[1].Pressed).toBe(true)
        expect(b[2].Pressed).toBe(false)
        expect(#got).toBe(0)

        -- Clique na aba 2: o botão alterna para pressionado e a aba muda.
        b[2].Pressed = true
        b[2].func(b[2].user, b[2], 2)
        expect(got[1]).toBe(2)
        expect(b[1].Pressed).toBe(false)
        expect(b[2].Pressed).toBe(true)
        expect(b[2].text).toBe("|cffffffffHistórico")
        expect(b[1].text).toBe("Atual")
    end)

    it("clicar na aba ativa a mantém pressionada, sem trocar", function()
        local ToolTabs, win, _, b = load()
        local tabs = ToolTabs:Create(win, { "Atual", "Histórico" })
        local got = 0
        tabs:SetUser({}, function() got = got + 1 end)
        tabs:SetActive(1)
        b[1].Pressed = false
        b[1].func(b[1].user, b[1], 1)
        expect(b[1].Pressed).toBe(true)
        expect(got).toBe(0)
        -- Select da aba já ativa (como fazem o Monitor e o mapa) não repete.
        tabs:Select(1)
        expect(got).toBe(0)
        expect(tabs:GetHeight()).toBe(0)
    end)
end)

describe("diário: posição das abas e do conteúdo", function()
    local quest = src()

    it("no tema Blizzard, as abas vão para a faixa; nos outros, a barra fica na base", function()
        local open = quest:match("function Nx%.Quest%.List:Open%(%).-\nend\n") or ""
        expect(has(open, "if Carbonite.UI.Skin:GameStyle() then")).toBe(true)
        expect(has(open, "bar = ToolTabs:Create (win, tabNames)")).toBe(true)
        expect(has(open, "win:Attach (bar.Frm, 0, 1, -tbH, 1)")).toBe(true)
        expect(has(open, "UseGameTabs")).toBe(false)
    end)

    it("com as abas no topo, a busca abre o conteúdo e a lista vai até a base", function()
        local attach = quest:match("function Nx%.Quest%.List:AttachFrames%(%).-\nend\n") or ""
        expect(has(quest, "win:Attach (self.FilterFrm, 0, 1, 0, 18)")).toBe(true)
        expect(has(attach, "self.TabsOnTop and 1")).toBe(true)
        expect(has(attach, "self.Bar:GetHeight()")).toBe(true)
    end)
end)
