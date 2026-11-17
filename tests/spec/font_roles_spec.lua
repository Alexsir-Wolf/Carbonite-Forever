-- Carbonite/UI/Font.lua: font roles with a global scale, and windows without fixed colors (#44)

local function fontObject(name)
    local o = { name = name }
    function o:SetFontObject(parent) self.parent = parent end
    function o:GetFont() return self.face, self.size, self.flags end
    function o:SetFont(face, size, flags) self.face, self.size, self.flags = face, size, flags end
    function o:SetShadowColor(...) self.shadow = { ... } end
    function o:SetShadowOffset() end
    return o
end

local function load(fontProfile)
    local env = wow.lenientEnv()
    env.Carbonite.UI = {}
    env.CreateFont = function(name) return fontObject(name) end
    env.LibStub = function() return nil end
    env.Nx = { db = { profile = { Font = fontProfile or {
        Small = "Friz", SmallSize = 10, Medium = "Friz", MediumSize = 12 } } } }
    loader.run(env, "Carbonite/UI/Font.lua")
    return env.Carbonite.UI.Font, env
end

describe("papéis de fonte", function()
    it("título, normal, pequena e número têm fonte própria ou a do slot", function()
        local Font = load()
        expect(Font:GetRole("small")).toBe("NxFontS")
        expect(Font:GetRole("normal")).toBe("NxFontM")
        expect(Font:GetRole("title")).toBe("NxFontTitle")
        expect(Font:GetRole("number")).toBe("NxFontNumber")
        expect(Font:GetRole("inexistente")).toBe("NxFontS")
    end)

    it("o título segue a fonte normal e a escala global", function()
        local Font = load({ Small = "Friz", SmallSize = 10, Medium = "Arial", MediumSize = 12, Scale = 1.5 })
        Font:Init()
        local title = Font.roles.title.fontObject
        expect(title.size).toBe(21)
        expect(title.face).toBe("Fonts\\ARIALN.TTF")
        expect(Font.slots["Font.Small"].fontObject.size).toBe(15)
    end)

    it("a escala fica entre 70% e 160%", function()
        local Font = load({ SmallSize = 10, MediumSize = 12, Scale = 9 })
        expect(Font:GetScale()).toBe(1.6)
    end)

    it("SetRole aplica o objeto de fonte do papel", function()
        local Font = load()
        local fs = { SetFontObject = function(self, o) self.obj = o end }
        Font:SetRole(fs, "title")
        expect(fs.obj).toBe("NxFontTitle")
    end)

    it("a escala tem opção e padrão", function()
        expect(loader.read("Carbonite/Modules/PlayerCharacter/Defaults.lua"):find("Scale = 1,", 1, true) ~= nil).toBe(true)
        expect(loader.read("Carbonite/Modules/Options/OptionsEngine.lua"):find('L["Font Scale"]', 1, true) ~= nil).toBe(true)
    end)
end)

describe("janelas sem fonte nem cor fixa", function()
    it("os títulos e os botões das janelas pedem um papel de fonte", function()
        local src = loader.read("Carbonite/Modules/UI/UIEngine.lua")
        expect(src:find('local fname = height <= 10 and "NxFontS" or "NxFontM"', 1, true)).toBeNil()
        expect(src:find('Carbonite.UI.Font:SetRole (fstr, "small")', 1, true) ~= nil).toBe(true)
    end)

    it("listas, menus, abas e botões tiram as cores do tema", function()
        local src = loader.read("Carbonite/Modules/UI/UIEngine.lua")
        for _, fixed in ipairs({ "SetTextColor (.8, .8, 1, 1)", '"|cffffbfaf"', '"|cff707070"', '"|cfff7f7f7"',
                                 "SetVertexColor (.2, .2, .5", "SetColorTexture (.5, 1, .5, 1)",
                                 "SetColorTexture (0, 0, 0, .5)", '"|cffffffff" .. name' }) do
            expect(src:find(fixed, 1, true)).toBeNil()
        end
    end)

    it("busca, notas e informações também", function()
        expect(loader.read("Carbonite/UI/SearchBox.lua"):find("SetTextColor(0.55", 1, true)).toBeNil()
        expect(loader.read("Carbonite.Notes/WindowEngine.lua"):find("|cff808080Root", 1, true)).toBeNil()
        expect(loader.read("Carbonite.Info/NxInfo.lua"):find("SetColorTexture (.2, .2, .2, .5)", 1, true)).toBeNil()
        expect(loader.read("Carbonite/UI/List.lua"):find("SetColorTexture(", 1, true)).toBeNil()
    end)
end)

describe("código de cor de um token", function()
    it("vira |cffRRGGBB", function()
        local env = wow.lenientEnv()
        env.Carbonite.UI = {}
        loader.run(env, "Carbonite/UI/Skin.lua")
        local Skin = env.Carbonite.UI.Skin
        Skin:Set("Glass", true)
        expect(Skin:TextCode("tabTextActive")).toBe("|cffffffff")
        Skin:Set("Blizzard", true)
        expect(Skin:TextCode("listHeaderText")).toBe("|cffffd100")
    end)
end)
