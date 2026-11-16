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
end)
