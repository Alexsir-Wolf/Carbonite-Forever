-- Objectives wrap by pixel width in the fixed-size quest watch, so a long
-- objective adds lines instead of widening the window.
-- Carbonite.Quests/WatchWindow.lua: WrapWatchLineToWidth, GetObjectiveWrapW

local function load()
    local env = wow.lenientEnv({
        strbyte = string.byte, strsub = string.sub, strfind = string.find,
    })
    env.Nx = wow.namespace({ Quest = { Watch = {} } })
    loader.run(env, "Carbonite.Quests/WatchWindow.lua")
    return env.Nx.Quest
end

-- 6 px per visible character; color codes take no room.
local function measure(s)
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return #s * 6
end

local LONG = "|cffccccccLeve o Globo Estranho para Jeneu Sancrea no Assentamento Zoramgar, no Vale Gris."

describe("WrapWatchLineToWidth", function()
    it("quebra a linha para caber na largura, em palavra inteira", function()
        local wrap = load().WrapWatchLineToWidth
        local line, rest = wrap(LONG, 70, 240, measure)
        expect(measure(line) <= 240).toBe(true)
        expect(line).toBe("|cffccccccLeve o Globo Estranho para Jeneu Sancrea")
        expect(rest).toBe("no Assentamento Zoramgar, no Vale Gris.")
    end)

    it("linha que cabe fica inteira", function()
        local wrap = load().WrapWatchLineToWidth
        local line, rest = wrap("|cffcccccc0/20 Safira", 70, 240, measure)
        expect(line).toBe("|cffcccccc0/20 Safira")
        expect(rest).toBeNil()
    end)

    it("mantém o teto de caracteres quando a largura sobra", function()
        local wrap = load().WrapWatchLineToWidth
        local line = wrap(LONG, 20, 2000, measure)
        expect(measure(line) <= 20 * 6).toBe(true)
    end)

    it("sem medidor, quebra só por caracteres como antes", function()
        local wrap = load().WrapWatchLineToWidth
        local line, rest = wrap(LONG, 70, 240, nil)
        expect(measure(line) > 240).toBe(true)
        expect(rest).toBeTruthy()
    end)

    it("não corta a cor no meio", function()
        local wrap = load().WrapWatchLineToWidth
        local line = wrap("|cff40ff40" .. string.rep("abc ", 30), 70, 60, measure)
        expect(line:sub(1, 10)).toBe("|cff40ff40")
    end)
end)

describe("Watch:GetWrapW", function()
    local function nxWith(fixedW)
        local env = wow.lenientEnv({
            strbyte = string.byte, strsub = string.sub, strfind = string.find,
        })
        env.Nx = wow.namespace({ Quest = { Watch = {} } })
        loader.run(env, "Carbonite.Quests/WatchWindow.lua")
        env.Nx.qdb = { profile = { QuestWatch = { FixedW = fixedW } } }
        local w = env.Nx.Quest.Watch
        w.Win = { BorderW = 7 }
        w.List = { ShowAll = true, Columns = { { Width = 18 }, { Width = 20 } } }
        return w
    end

    it("sem largura salva, usa a do cabeçalho", function()
        local w = nxWith(0)
        w.ModernMinW = 314
        expect(w:GetFixedListW()).toBe(300)
        expect(w:GetWrapW(16)).toBe(300 - 2 - 18 - 16)
    end)

    it("usa a largura arrastada pelo usuário", function()
        local w = nxWith(414)
        w.ModernMinW = 314
        expect(w:GetFixedListW()).toBe(400)
    end)

    it("nunca fica abaixo do cabeçalho", function()
        local w = nxWith(200)
        w.ModernMinW = 314
        expect(w:GetFixedListW()).toBe(300)
    end)

    it("no tamanho livre, usa a largura da janela menos a barra", function()
        local w = nxWith(0)
        w.List.ShowAll = false
        w.List.Frm = { GetWidth = function() return 350 end }
        w.List.Slider = { Frm = { GetWidth = function() return 10 end } }
        expect(w:GetWrapW(0)).toBe(350 - 10 - 2 - 18)
    end)
end)

describe("WatchLineColor", function()
    it("devolve a última cor aberta", function()
        local c = load().WatchLineColor
        expect(c("|cff808080 23 |cffffd100O clamor da")).toBe("|cffffd100")
    end)

    it("sem cor aberta, devolve vazio", function()
        local c = load().WatchLineColor
        expect(c("|cffffd100O clamor|r da")).toBe("")
        expect(c("texto")).toBe("")
    end)
end)

describe("Watch:UpdateList", function()
    it("quebra títulos e objetivos pela largura do monitor", function()
        local f = io.open("Carbonite.Quests/WatchWindow.lua", "r")
        local src = (f:read("*a"):gsub("\r\n", "\n"))
        f:close()
        local update = src:match("function Nx%.Quest%.Watch:UpdateList%(%).-\nend\n")
        expect(update:find("WrapWatchLineToWidth (nameStr, 200, titleWrapW, measure)", 1, true) ~= nil).toBe(true)
        expect(update:find("WrapWatchLineToWidth(str, maxVisible, wrapW, measure)", 1, true) ~= nil).toBe(true)
        expect(update:find("list:SetMinSize (self:GetFixedListW(), 1)", 1, true) ~= nil).toBe(true)
    end)
end)

describe("Monitor de tamanho fixo redimensionável na largura", function()
    local function read(path)
        local f = io.open(path, "r")
        local src = (f:read("*a"):gsub("\r\n", "\n"))
        f:close()
        return src
    end

    it("as bordas laterais redimensionam e a largura fica salva", function()
        local watch = read("Carbonite.Quests/WatchWindow.lua")
        expect(watch:find("win.SizeableW = true", 1, true) ~= nil).toBe(true)
        expect(watch:find("qw.FixedW = floor (max (self.Win.Frm:GetWidth(), self.ModernMinW or 0) + .5)", 1, true) ~= nil).toBe(true)
        local ui = read("Carbonite/Modules/UI/UIEngine.lua")
        expect(ui:find("if not self.Sizeable and self.SizeableW then", 1, true) ~= nil).toBe(true)
        expect(ui:find('win:Notify ("SizeW")', 1, true) ~= nil).toBe(true)
        expect(ui:find("and not win.WidthSizing then", 1, true) ~= nil).toBe(true)
    end)
end)
