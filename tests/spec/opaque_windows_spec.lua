-- Opaque window backgrounds by default, translucency as an option (#98)

local function load(profileSkin)
    local env = wow.lenientEnv()
    env.Carbonite.UI = {}
    env.Nx = { db = { profile = { Skin = profileSkin } } }
    loader.run(env, "Carbonite/UI/Skin.lua")
    return env.Carbonite.UI.Skin, profileSkin
end

describe("fundo das janelas", function()
    it("os temas modernos têm fundo opaco", function()
        local Skin = load({})
        for _, name in ipairs({ "Modern Dark", "Modern Light", "Class Color", "Faction" }) do
            Skin:Set(name, true)
            expect(Skin:GetBackgroundColor()[4]).toBe(1)
        end
    end)

    it("o fundo translúcido antigo, salvo sem escolha do jogador, volta ao do tema", function()
        local Skin, saved = load({ WinSizedBgColor = "0.06|0.07|0.10|0.92" })
        Skin:Set("Modern Dark", true)
        expect(saved.WinSizedBgColor).toBeNil()
        expect(Skin:GetBackgroundColor()[4]).toBe(1)
    end)

    it("uma cor escolhida pelo jogador continua valendo", function()
        local Skin = load({ WinSizedBgColor = "0|0|0|0.5" })
        Skin:Set("Modern Dark", true)
        expect(Skin:GetBackgroundColor()[4]).toBe(0.5)
    end)

    it("trocar de tema traz as cores do tema novo", function()
        local Skin, saved = load({ WinBdColor = "1|0|0|1" })
        Skin:Set("Modern Light")
        expect(saved.WinBdColor).toBeNil()
    end)

    it("janelas novas não ficam translúcidas com o mouse fora, e as antigas migram uma vez", function()
        local src = loader.read("Carbonite/Modules/UI/UIEngine.lua")
        expect(src:find('svdata["FO"] = self.CFadeOut or 1', 1, true) ~= nil).toBe(true)
        expect(src:find('if svdata["FO"] == .75 then', 1, true) ~= nil).toBe(true)
    end)
end)
