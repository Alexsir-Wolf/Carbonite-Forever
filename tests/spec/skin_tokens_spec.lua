-- Carbonite/UI/Skin.lua: one theme definition, shared color tokens and the saved colors (#44)

local function load(profileSkin)
    local env = wow.lenientEnv()
    env.Carbonite.UI = {}
    env.Nx = { db = { profile = { Skin = profileSkin or {} } } }
    loader.run(env, "Carbonite/UI/Skin.lua")
    return env.Carbonite.UI.Skin, env
end

local function texture()
    local t = {}
    function t:SetColorTexture(r, g, b, a) self.color = { r, g, b, a } end
    return t
end

describe("tema", function()
    it("os temas existem só no Skin.lua", function()
        local src = loader.read("Carbonite/Modules/UI/UIEngine.lua")
        expect(src:find("Nx.Skins = {", 1, true)).toBeNil()
        expect(src:find("function Nx.Skin:", 1, true)).toBeNil()
    end)

    it("trocar para o Modern Light recolore o que foi pintado com tokens", function()
        local Skin = load()
        Skin:Set("Modern Dark", true)
        local bar = texture()
        Skin:Paint(bar, "scrollTrack")
        expect(bar.color[1]).toBe(0.3)
        Skin:Set("Modern Light")
        expect(bar.color[1]).toBe(0.7)
    end)

    it("um tema sem o token usa o padrão", function()
        local Skin = load()
        Skin:Set("Glass", true)
        local r, g, b, a = Skin:GetToken("listBg")
        expect(r + g + b).toBe(0)
        expect(a).toBe(0.3)
    end)

    it("as cores escolhidas nas opções valem", function()
        local Skin = load({ WinBdColor = "1|0|0|1", WinSizedBgColor = "0|1|0|1" })
        Skin:Set("Modern Dark", true)
        expect(Skin:GetBorderColor()[1]).toBe(1)
        expect(Skin:GetBackgroundColor()[2]).toBe(1)
    end)

    it("a lista, as abas e a rolagem não têm mais cor fixa", function()
        local src = loader.read("Carbonite/Modules/UI/UIEngine.lua")
        expect(src:find('"0.06|0.06|0.250|1"', 1, true)).toBeNil()
        expect(src:find("SetColorTexture (.3, .3, .4, .6)", 1, true)).toBeNil()
        expect(src:find("SetColorTexture (0, 0, 0, .3)", 1, true)).toBeNil()
        expect(src:find('".313|.313|.313|1"', 1, true)).toBeNil()
    end)
    it("sem cor escolhida, valem as cores do tema e os seletores mostram essas cores", function()
        local Skin = load()
        Skin:Set("Modern Light", true)
        expect(Skin:GetBackgroundColor()[1]).toBe(0.88)
        expect(loader.read("Carbonite/Modules/PlayerCharacter/Defaults.lua"):find("WinBdColor", 1, true)).toBeNil()
        expect(loader.read("Carbonite/Modules/Options/OptionsEngine.lua"):find("Carbonite.UI.Skin:GetBorderColor()", 1, true) ~= nil).toBe(true)
    end)
end)

describe("tema Blizzard", function()
    it("é o padrão de quem nunca escolheu um tema e usa a moldura do jogo", function()
        local Skin = load({ Name = "" })
        Skin:Set("", true)
        expect(Skin.activeName).toBe("Blizzard")
        expect(Skin:GetActive().nineSlice).toBe("ButtonFrameTemplateNoPortrait")
    end)

    it("sem a moldura no cliente, cai para a borda de diálogo", function()
        local Skin, env = load({ Name = "Blizzard" })
        Skin:Set("Blizzard", true)
        env.NineSliceLayouts = {}
        expect(Skin:GetBackdrop().edgeFile:find("UI-DialogBox-Border", 1, true) ~= nil).toBe(true)
        env.NineSliceUtil = { ApplyLayoutByName = function() end }
        env.NineSliceLayouts = { ButtonFrameTemplateNoPortrait = {} }
        expect(Skin:GetBackdrop().edgeFile).toBeNil()
    end)

    it("a lista de temas das opções vem dos próprios temas", function()
        expect(loader.read("Carbonite/Modules/Options/OptionsEngine.lua"):find("Carbonite.UI.Skin:ListThemes()", 1, true) ~= nil).toBe(true)
    end)
end)
