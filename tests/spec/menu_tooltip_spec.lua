-- Menus no padrão do tooltip do jogo (#42, R11): no tema Blizzard, fundo
-- azul-escuro, borda prateada e texto de 12 px; nos outros temas, como antes.

local function src(path)
    return (loader.read(path):gsub(string.char(13), ""))
end

local function has(s, needle)
    return s:find(needle, 1, true) ~= nil
end

local function fontObject(name)
    local o = { name = name }
    function o:SetFontObject(parent) self.parent = parent end
    function o:GetFont() return self.face, self.size, self.flags end
    function o:SetFont(face, size, flags) self.face, self.size, self.flags = face, size, flags end
    function o:SetShadowColor() end
    function o:SetShadowOffset() end
    return o
end

local function loadFont(menuSize, scale)
    local env = wow.lenientEnv()
    env.Carbonite.UI = {}
    env.CreateFont = function(name) return fontObject(name) end
    env.LibStub = function() return nil end
    env.Nx = { db = { profile = { Font = {
        Small = "Friz", SmallSize = 10, Medium = "Friz", MediumSize = 12,
        Menu = "Friz", MenuSize = menuSize, Scale = scale } } } }
    loader.run(env, "Carbonite/UI/Font.lua")
    return env.Carbonite.UI.Font
end

describe("menus com o visual do tooltip", function()
    it("o tema Blizzard traz a moldura do tooltip do jogo", function()
        local skin = src("Carbonite/UI/Skin.lua")
        expect(has(skin, [["Interface\\Tooltips\\UI-Tooltip-Background"]])).toBe(true)
        expect(has(skin, 'bgColor     = "0.09|0.09|0.19|0.95"')).toBe(true)
    end)

    it("o menu usa a moldura do tema quando ela existe, senão a da skin", function()
        local ui = src("Carbonite/Modules/UI/UIEngine.lua")
        local set = ui:match("function Nx%.Menu:SetSkin%(%).-\nend\n") or ""
        expect(has(set, "local tip = Carbonite.UI.Skin:GetActive().menu")).toBe(true)
        expect(has(set, "f:SetBackdrop (tip.backdrop)")).toBe(true)
        expect(has(set, "local bk = Nx.Skin:GetBackdrop()")).toBe(true)
    end)

    it("texto e altura do item seguem a fonte do menu", function()
        local ui = src("Carbonite/Modules/UI/UIEngine.lua")
        expect(has(ui, 'return Font:GetRole ("menu"), max (12, Font:GetHeight ("Role.menu")) + 3')).toBe(true)
        expect(has(ui, "local itemH = lineH")).toBe(true)
        expect(has(ui, "fstr:SetFontObject (font)")).toBe(true)
        expect(has(ui, "measure:SetFontObject ((self:GetFont()))")).toBe(true)
    end)

    it("a fonte do menu tem no mínimo 13 px e acompanha a escala", function()
        expect(loadFont(10, 1):GetRoleSize("menu")).toBe(13)
        expect(loadFont(14, 1):GetRoleSize("menu")).toBe(14)
        expect(loadFont(10, 1.5):GetRoleSize("menu")).toBe(20)
    end)
end)
