-- #27: Nx.Map methods replaced at load time (rewireLegacy) must not have a second copy in
-- MapEngine.lua, or fixes land in code that never runs.

local src = loader.read("Carbonite/Modules/Map/MapEngine.lua")

local owners = {
    Ping = "MiniMap.lua",
    SaveView = "ViewState.lua", RestoreView = "ViewState.lua",
    IsBattleGroundMap = "Battleground.lua", IsMicroDungeon = "Battleground.lua",
    IsScenario = "Battleground.lua", GCMI_OVERRIDE = "Battleground.lua",
    GetShortName = "Battleground.lua",
    GetWorldZoneScale = "Coords.lua", GetWorldPos = "Coords.lua",
    GetWorldRect = "Coords.lua", GetZonePos = "Coords.lua",
}

describe("MapEngine sem cópias antigas", function()
    for name, owner in pairs(owners) do
        it(name .. " só existe em " .. owner, function()
            local found = src:find("\nfunction Nx%.Map:" .. name .. "%s*%(")
            expect(found).toBeNil()
            expect(loader.read("Carbonite/Modules/Map/" .. owner)).toContain("." .. name)
        end)
    end
end)
