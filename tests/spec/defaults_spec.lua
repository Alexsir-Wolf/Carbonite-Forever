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
