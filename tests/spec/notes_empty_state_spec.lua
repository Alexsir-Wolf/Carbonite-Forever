-- Janela de Notas: estado vazio com orientação e botões no estilo do jogo (#201)

local PATH = "Carbonite.Notes/WindowEngine.lua"

-- Lista falsa: guarda as linhas e o nome de cada coluna.
local function fakeList()
    local list = { rows = 0, names = {} }
    function list:Empty() self.rows = 0 end
    function list:ItemAdd() self.rows = self.rows + 1 end
    function list:ItemGetNum() return self.rows end
    function list:ColumnSetName(id, name) self.names[id] = name end
    list.ItemSet, list.ItemSetButton, list.Select, list.Update = function() end, function() end,
        function() end, function() end
    list.ItemSetSection = function() end
    return list
end

-- Carrega o arquivo com a janela já criada e devolve Nx.Notes.
local function load(addonNotes)
    local Nx = wow.namespace({ SearchBox = wow.searchBox(), Notes = { addonNotes = addonNotes or {} } })
    local env = wow.lenientEnv({ Nx = Nx, strrep = string.rep })
    env.Carbonite.UI = { Skin = { TextCode = function() return "" end } }
    loader.run(env, PATH, "Carbonite.Notes", {})
    local Notes = Nx.Notes
    Notes.List, Notes.ItemList = fakeList(), fakeList()
    Notes.EmptyHint = wow.frame("hint")
    Notes.Win = { SetTitle = function() end, SetHeaderCounter = function(_, n) Notes.counter = n end }
    return Notes
end

describe("Notas: estado vazio", function()
    it("sem notas, mostra a orientação, esconde as colunas e o contador", function()
        local Notes = load()
        Notes.Folders = {}
        Notes:Update()
        expect(Notes.EmptyHint.shown).toBe(true)
        expect(Notes.ItemList.names[2]).toBe("")
        expect(Notes.ItemList.names[3]).toBe("")
        expect(Notes.ItemList.names[4]).toBe("")
        expect(Notes.counter).toBeNil()
    end)

    it("com notas, some a orientação e volta o contador", function()
        local Notes = load()
        Notes.Folders = { { T = "F", Name = "Minhas notas", { Name = "Orgrimmar" } } }
        Notes:Update()
        expect(Notes.EmptyHint.shown).toBe(false)
        expect(Notes.counter).toBe(1)
    end)

    it("as colunas voltam quando a lista da direita tem itens", function()
        local Notes = load()
        Notes.ItemList.rows = 2
        Notes:UpdateEmptyState()
        expect(Notes.ItemList.names[2]).toBe("Type")
        expect(Notes.ItemList.names[4]).toBe("Location")
    end)

    it("notas de outros addons contam como conteúdo", function()
        local Notes = load({ Hide = true, HandyNotes = {} })
        Notes.FavCnt, Notes.Search = 0, ""
        expect(Notes:IsEmpty()).toBe(false)
    end)

    it("a busca sem resultado não mostra a orientação de criar nota", function()
        local Notes = load()
        Notes.FavCnt, Notes.Search = 0, "xyz"
        expect(Notes:IsEmpty()).toBe(false)
    end)

    it("a raiz e a orientação passam pelo locale", function()
        local src = loader.read(PATH)
        expect(src:find('.. "Root"', 1, true)).toBeNil()
        expect(src:find('L["All notes"]', 1, true) ~= nil).toBe(true)
        for _, locale in ipairs({ "enUS", "ptBR" }) do
            local loc = loader.read("Carbonite.Notes/Locales/" .. locale .. ".lua")
            expect(loc:find('L["All notes"]', 1, true) ~= nil).toBe(true)
            expect(loc:find('L["No notes yet. Right-click the map', 1, true) ~= nil).toBe(true)
        end
    end)
end)

describe("Notas: botões", function()
    it("Gravar, Subir e Descer usam o botão cinza do jogo; só Excluir fica vermelho", function()
        local src = loader.read(PATH)
        expect(src:find('"TxtGreyB", L["Record"]', 1, true) ~= nil).toBe(true)
        expect(src:find('"TxtGrey", L["Up"]', 1, true) ~= nil).toBe(true)
        expect(src:find('"TxtGrey", L["Down"]', 1, true) ~= nil).toBe(true)
        expect(src:find('"Txt64", L["Delete Item"]', 1, true) ~= nil).toBe(true)
    end)

    it("usa os tipos cinza compartilhados, sem tipos próprios (#42)", function()
        local src = loader.read(PATH)
        expect(src:find("NotesTxt", 1, true)).toBeNil()
        expect(src:find("AddButtonTypes", 1, true)).toBeNil()
    end)
end)
