-- Nx.Button:UseClientAtlases in Carbonite/Modules/UI/UIEngine.lua: Blizzard button art (#45)

local function load(atlases)
    local env = wow.lenientEnv()
    env.C_Texture = { GetAtlasInfo = function(name) return atlases[name] and {} or nil end }
    env.Nx = wow.namespace()
    loader.run(env, "Carbonite/Modules/UI/UIEngine.lua")
    env.Nx.Button:UseClientAtlases()
    return env.Nx.Button.TypeData
end

describe("botões com atlases da Blizzard", function()
    it("usa o X vermelho e a caixa de seleção do jogo quando o cliente tem", function()
        local types = load({ ["RedButton-Exit"] = true, ["RedButton-exit-pressed"] = true,
                             ["checkbox-minimal"] = true, ["checkmark-minimal"] = true })
        expect(types.Close.AtlasUp).toBe("RedButton-Exit")
        expect(types.Chk.AtlasUp).toBe("checkbox-minimal")
        expect(types.Chk.IconDn).toBe("checkmark-minimal")
    end)

    it("mantém a textura do skin para o atlas que falta", function()
        local types = load({ ["RedButton-Exit"] = true })
        expect(types.Close.AtlasUp).toBeNil()
        expect(types.Close.Up).toBe("ButClose")
        expect(types.MaxOn.VRGBAUp).toBe(".5|.5|1|1")
    end)

    it("o botão de restaurar perde o tom azul quando ganha o ícone próprio", function()
        local types = load({ ["RedButton-Condense"] = true, ["RedButton-Condense-Pressed"] = true })
        expect(types.MaxOn.AtlasUp).toBe("RedButton-Condense")
        expect(types.MaxOn.VRGBAUp).toBeNil()
    end)

    it("minimizar usa as setas do rastreador de quests", function()
        local types = load({ ["ui-questtrackerbutton-collapse-all"] = true, ["ui-questtrackerbutton-expand-all"] = true })
        expect(types.Min.AtlasUp).toBe("ui-questtrackerbutton-collapse-all")
        expect(types.Min.VRGBADn).toBeNil()
    end)

    it("os botões de texto usam o botão vermelho do jogo ou, sem o atlas, o arquivo do painel", function()
        local types = load({ ["128-RedButton-UP"] = true, ["128-RedButton-Pressed"] = true })
        expect(types.Txt64.AtlasUp).toBe("128-RedButton-UP")
        local plain = load({})
        expect(plain.Txt64.AtlasUp).toBeNil()
        expect(plain.Txt64.Up).toBe("Interface\\Buttons\\UI-Panel-Button-Up")
        expect(plain.Txt64.Skin).toBeNil()
        expect(plain.Txt64B.Dn).toBe("Interface\\Buttons\\UI-Panel-Button-Down")
        expect(plain.Txt64B.VRGBADn).toBeNil()
    end)

    it("um tipo registrado depois por um módulo também ganha o atlas", function()
        local types = load({ ["QuestLog-icon-shrink"] = true, ["QuestLog-icon-expand"] = true })
        types.QuestHdr = { Bool = true, Skin = true, Up = "RoundMinus", Dn = "RoundPlus", VRGBAUp = ".56|.56|.56|1" }
        expect(types.QuestHdr.AtlasUp).toBe("QuestLog-icon-shrink")
        expect(types.QuestHdr.VRGBAUp).toBeNil()
    end)

    it("sem C_Texture, o tipo cujo atlas falta fica com a textura do skin", function()
        local env = wow.lenientEnv({}, { "C_Texture" })
        env.Nx = wow.namespace()
        loader.run(env, "Carbonite/Modules/UI/UIEngine.lua")
        env.Nx.Button:UseClientAtlases()
        expect(env.Nx.Button.TypeData.Close.Up).toBe("ButClose")
        expect(env.Nx.Button.TypeData.Min.Up).toBe("ButWatchShow")
    end)
end)
