-- Default settings a fresh install starts with

local function defaults()
    local env = wow.lenientEnv()
    env.Nx = wow.namespace({})
    loader.run(env, "Carbonite/Modules/PlayerCharacter/Defaults.lua")
    return env.Nx.Defaults.profile
end

describe("padrões de privacidade (#57)", function()
    it("não entra nos canais nem envia a posição", function()
        local comm = defaults().Comm
        expect(comm.Global).toBe(false)
        expect(comm.Zone).toBe(false)
        expect(comm.SendToFriends).toBe(false)
        expect(comm.SendToGuild).toBe(false)
        expect(comm.SendToZone).toBe(false)
    end)
end)

describe("mensagens de carga das quests (#62)", function()
    it("vêm desligadas", function()
        local env = wow.lenientEnv()
        env.Nx = wow.namespace({ Quest = {}, MaxPlayerLevel = 60 })
        loader.run(env, "Carbonite.Quests/NxQuest.lua")
        expect(env.Nx.Quest.defaults.profile.Quest.LoadMessages).toBe(false)
    end)
end)

describe("padrões barulhentos e chaves invertidas (#59)", function()
    local function migrate(general)
        local env = wow.lenientEnv()
        env.Nx = wow.namespace({})
        loader.run(env, "Carbonite/Modules/PlayerCharacter/Defaults.lua")
        env.Nx.MigrateGeneralKeys(general)
        return general
    end

    it("vem com login, tela de abertura, grifos e placar de BG em silêncio", function()
        local p = defaults()
        expect(p.General.LoginMessage).toBe(false)
        expect(p.General.TitleShow).toBe(false)
        expect(p.General.GryphonsHide).toBe(false)
        expect(p.Battleground.ShowStats).toBe(false)
        expect(p.General.LoginHideVer).toBeNil()
        expect(p.General.TitleOff).toBeNil()
    end)

    it("leva a escolha salva com o nome antigo para o nome novo", function()
        local g = migrate({ LoginHideVer = true, TitleOff = false })
        expect(g.LoginMessage).toBe(true)
        expect(g.TitleShow).toBe(false)
        expect(g.LoginHideVer).toBeNil()
        expect(g.TitleOff).toBeNil()
    end)

    it("não sobrescreve um valor já salvo com o nome novo", function()
        local g = migrate({ TitleOff = true, TitleShow = false })
        expect(g.TitleShow).toBe(false)
    end)
end)
