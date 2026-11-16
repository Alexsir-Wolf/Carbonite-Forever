-- Fishing skill of each zone in the map's zone tooltip (#84)

local function load()
    local env = wow.lenientEnv()
    env.Carbonite = { Modules = { Map = {} } }
    loader.run(env, "Carbonite/Modules/Map/ZoneFishing.lua")
    return env.Carbonite.Modules.Map.ZoneFishing
end

describe("pesca da zona", function()
    it("dá a perícia de pesca por uiMapID", function()
        local ZF = load()
        expect(ZF:Get(1429)).toBe("1")             -- Floresta de Elwynn
        expect(ZF:Get(1444)).toBe("205 (330)")     -- Feralas
        expect(ZF:Get(999999)).toBeNil()
    end)

    it("o tooltip da zona mostra a pesca, e o crédito do MapUtils está no README", function()
        local src = loader.read("Carbonite/Modules/Map/Hotspots.lua")
        expect(src:find("ZoneFishing:Get(mapID)", 1, true) ~= nil).toBe(true)
        expect(loader.read("Carbonite/Modules/Modules.xml"):find("Map\\ZoneFishing.lua", 1, true) ~= nil).toBe(true)
        expect(loader.read("README.md"):find("MapUtils", 1, true) ~= nil).toBe(true)
    end)
end)
