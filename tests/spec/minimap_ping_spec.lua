-- MiniMap:CanPing / Ping in Carbonite/Modules/Map/MiniMap.lua (#15)

local function load(expansion)
    local env = wow.lenientEnv()
    env.Carbonite.Compat = { Expansion = expansion }
    loader.run(env, "Carbonite/Modules/Map/MiniMap.lua")
    return env, env.Carbonite.Modules.Map.MiniMap
end

describe("MiniMap:CanPing", function()
    it("bloqueia no Forever", function()
        local _, MM = load({ isCamelot = true })
        expect(MM:CanPing()).toBe(false)
    end)

    it("bloqueia no Retail", function()
        local _, MM = load({ isMainline = true })
        expect(MM:CanPing()).toBe(false)
    end)

    it("permite no Classic", function()
        local _, MM = load({})
        expect(MM:CanPing()).toBe(true)
    end)
end)

describe("MiniMap:Ping no Forever", function()
    it("não chama PingLocation", function()
        local env, MM = load({ isCamelot = true })
        local pinged = false
        env.Nx = { Map = { Maps = { { Frm = {}, MMFrm = { PingLocation = function() pinged = true end } } } } }
        MM:Ping()
        expect(pinged).toBe(false)
    end)
end)
