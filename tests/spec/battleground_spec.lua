-- Carbonite/Modules/Map/Battleground.lua

local function load(overrides)
    local env = wow.env(overrides)
    loader.run(env, "Carbonite/Modules/Map/Battleground.lua")
    return env, env.Carbonite.Modules.Map.Battleground
end

describe("Battleground:IsMicroDungeon", function()
    it("is true for a micro map", function()
        local _, BG = load({ C_Map = { GetMapInfo = function() return { mapType = 5 } end } })
        expect(BG:IsMicroDungeon(1)).toBe(true)
    end)

    it("is false for a zone", function()
        local _, BG = load({ C_Map = { GetMapInfo = function() return { mapType = 3 } end } })
        expect(BG:IsMicroDungeon(1)).toBe(false)
    end)
end)

describe("Battleground:Refresh", function()
    it("marks a pvp instance as battleground", function()
        local env, BG = load({ GetInstanceInfo = function() return "Warsong Gulch", "pvp" end })
        env.Nx = {}
        BG:Refresh()
        expect(env.Nx.InBG).toBe(true)
    end)
end)
