-- Sanity checks of the test support itself.

describe("loader", function()
    it("runs a file with the addon arguments and a private environment", function()
        local env = wow.env()
        loader.run(env, "Carbonite/Modules/Map/Battleground.lua")
        expect(env.Carbonite.Modules.Map.Battleground).toBeTruthy()
        expect(rawget(_G, "Battleground")).toBeNil()
    end)
end)
