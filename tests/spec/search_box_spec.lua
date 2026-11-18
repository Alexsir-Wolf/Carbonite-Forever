-- Carbonite/UI/SearchBox.lua: one search field for every window (#102)

-- Fake frames: an EditBox keeps its text and fires OnTextChanged like the client does.
local function fakeFrame(kind)
    local f = wow.frame()
    f.kind, f.text, f.focus = kind, "", false
    f.CreateTexture = function() return fakeFrame("Texture") end
    f.CreateFontString = function() return fakeFrame("FontString") end
    f.SetText = function(self, text)
        self.text = text or ""
        if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end
    end
    f.GetText = function(self) return self.text end
    f.ClearFocus = function(self) self.focus = false end
    return f
end

local function setup(opts)
    local timers = {}
    local SearchBox = wow.searchBox({
        CreateFrame = function(kind) return fakeFrame(kind) end,
        C_Timer = { After = function(delay, fn) timers[#timers + 1] = { delay = delay, fn = fn } end },
    })
    local calls = {}
    local box = SearchBox:Create(fakeFrame("Frame"), function(text) calls[#calls + 1] = text end, opts)
    local function typeText(text) box.Frm.text = text; box.Frm.scripts.OnTextChanged(box.Frm) end
    local function runTimers()
        local list = timers
        timers = {}
        for _, t in ipairs(list) do t.fn() end
    end
    return box, calls, typeText, runTimers, timers, SearchBox
end

describe("busca: normalização", function()
    local SearchBox = wow.searchBox()

    it("ignora maiúsculas e acentos", function()
        expect(SearchBox.Normalize("Minério de COBRE")).toBe("minerio de cobre")
        expect(SearchBox.Normalize("ÁÉÍÓÚ àèìòù ÂÊÔ ãõ ç Ç ü")).toBe("aeiou aeiou aeo ao c c u")
        expect(SearchBox.Normalize(nil)).toBe("")
    end)

    it("acha o texto digitado sem acento no texto com acento, e o contrário", function()
        expect(SearchBox.Matches("Poção de Cura", "pocao")).toBe(true)
        expect(SearchBox.Matches("Pocao de Cura", "POÇÃO")).toBe(true)
        expect(SearchBox.Matches("Poção de Cura", "mana")).toBe(false)
    end)

    it("busca vazia mostra tudo e caracteres de padrão são texto", function()
        expect(SearchBox.Matches("qualquer", "")).toBe(true)
        expect(SearchBox.Matches("[7] Missão", "[7]")).toBe(true)
        expect(SearchBox.Matches("abc", "a.c")).toBe(false)
    end)
end)

describe("busca: campo", function()
    it("espera um pouco antes de filtrar e filtra uma vez só", function()
        local box, calls, typeText, runTimers, timers = setup()
        typeText("c")
        typeText("co")
        typeText("cob")
        expect(#calls).toBe(0)
        expect(timers[1].delay).toBe(0.2)
        runTimers()
        expect(#calls).toBe(1)
        expect(calls[1]).toBe("cob")
        expect(box:GetText()).toBe("cob")
    end)

    it("Enter filtra na hora e tira o foco", function()
        local box, calls, typeText = setup()
        box.Frm.focus = true
        typeText("ferro")
        box.Frm.scripts.OnEnterPressed(box.Frm)
        expect(calls[1]).toBe("ferro")
        expect(box.Frm.focus).toBe(false)
    end)

    it("Esc limpa, filtra na hora e tira o foco", function()
        local box, calls, typeText, runTimers = setup()
        typeText("ferro")
        runTimers()
        box.Frm.focus = true
        box.Frm.scripts.OnEscapePressed(box.Frm)
        expect(box:GetText()).toBe("")
        expect(box.Frm.text).toBe("")
        expect(calls[#calls]).toBe("")
        expect(box.Frm.focus).toBe(false)
        runTimers()
        expect(#calls).toBe(2)
    end)

    it("o X aparece com texto e limpa a busca", function()
        local box, calls, typeText, runTimers = setup()
        expect(box.ClearBut.shown).toBe(false)
        expect(box.Hint.shown).toBe(true)
        typeText("ouro")
        expect(box.ClearBut.shown).toBe(true)
        expect(box.Hint.shown).toBe(false)
        runTimers()
        box.ClearBut.scripts.OnClick(box.ClearBut)
        expect(box:GetText()).toBe("")
        expect(calls[#calls]).toBe("")
        expect(box.ClearBut.shown).toBe(false)
        expect(box.Hint.shown).toBe(true)
    end)

    it("SetText troca o texto sem filtrar (troca de aba)", function()
        local box, calls, _, runTimers = setup()
        box:SetText("lobo")
        runTimers()
        expect(box:GetText()).toBe("lobo")
        expect(#calls).toBe(0)
    end)

    it("placeholder traduzido, ou o da janela", function()
        local box = setup()
        expect(box.Hint.text).toBe("Search...")
        box = setup({ placeholder = "Search items..." })
        expect(box.Hint.text).toBe("Search items...")
        local pt = loader.read("Carbonite/Locales/ptBR/Main.lua")
        expect(pt:find('L["Search..."] = "Buscar..."', 1, true) ~= nil).toBe(true)
    end)

    it("cores pelos tokens do Skin", function()
        local src = loader.read("Carbonite/UI/SearchBox.lua")
        expect(src:find("SetColorTexture", 1, true)).toBeNil()
        expect(src:find('paint(bg, "listHeader")', 1, true) ~= nil).toBe(true)
    end)
end)

describe("busca: janelas", function()
    local WINDOWS = {
        "Carbonite/Data/Shared/NxMapGuide.lua",
        "Carbonite.Warehouse/Engine.lua",
        "Carbonite.Quests/QuestWindow.lua",
        "Carbonite.Notes/WindowEngine.lua",
        "Carbonite/Modules/Journey/Journey.lua",
    }

    it("Guia, Warehouse, diário, Notas e jornada usam o componente", function()
        for _, path in ipairs(WINDOWS) do
            local src = loader.read(path)
            expect(path .. ": " .. tostring(src:find("Nx.SearchBox:Create", 1, true) ~= nil)).toBe(path .. ": true")
            expect(src:find("Nx.EditBox", 1, true)).toBeNil()
            expect(src:find('CreateFrame ("EditBox"', 1, true)).toBeNil()
            expect(src:find("FilterDesc", 1, true)).toBeNil()
        end
    end)

    it("o campo antigo saiu e o novo carrega com a UI", function()
        expect(loader.read("Carbonite/Modules/UI/UIEngine.lua"):find("Nx.EditBox", 1, true)).toBeNil()
        expect(loader.read("Carbonite/UI/UI.xml"):find('<Script file="SearchBox.lua" />', 1, true) ~= nil).toBe(true)
        expect(loader.read("Carbonite/Carbonite.lua"):find("Nx.SearchBox = Carbonite.UI.SearchBox", 1, true) ~= nil)
            .toBe(true)
    end)

    it("as Notas filtram pelo nome e mostram só as pastas com resultado", function()
        local Nx = wow.namespace({ SearchBox = wow.searchBox() })
        local env = wow.lenientEnv({ Nx = Nx, strrep = string.rep })
        loader.run(env, "Carbonite.Notes/WindowEngine.lua", "Carbonite.Notes", {})
        local rows = {}
        local Notes = Nx.Notes
        Notes.List = {
            ItemAdd = function() end, ItemSetButton = function() end, Select = function() end,
            ItemSetSection = function() end,
            ItemGetNum = function() return #rows end,
            ItemSet = function(_, _, text) rows[#rows + 1] = text end,
        }
        Notes.FavCnt = 0
        Notes.Search = "pocao"
        Notes:UpdateFolder({
            { T = "F", Name = "Alquimia", { T = "N", Name = "Poção de Cura" }, { T = "N", Name = "Elixir" } },
            { T = "F", Name = "Mineração", { T = "N", Name = "Cobre" } },
            { T = "N", Name = "Ferro" },
        }, 1)
        expect(#rows).toBe(2)
        expect(rows[1]:find("Alquimia", 1, true) ~= nil).toBe(true)
        expect(rows[2]:find("Poção de Cura", 1, true) ~= nil).toBe(true)
        expect(Notes.FavCnt).toBe(1)
    end)
end)
