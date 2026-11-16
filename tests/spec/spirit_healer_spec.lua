-- Spirit healers as a Guide category (#77)

describe("curandeiros espirituais no Guia", function()
    it("os dados do Forever usam o modo 32 com pontos neutros", function()
        local env = wow.lenientEnv()
        env.Nx = { GuideData = {} }
        env.LibStub = function() return { GetLocale = function() return setmetatable({}, { __index = function(_, k) return k end }) end } end
        loader.run(env, "Carbonite/Data/camelot/Guides/SpiritHealer.lua")
        local data = env.Nx.GuideData["Spirit Healer"]
        expect(data.Mode).toBe(32)
        expect(data[1429]:sub(1, 2)).toBe("0,")      -- Floresta de Elwynn
        for zone, row in pairs(data) do
            if zone ~= "Mode" then
                for point in row:gmatch("[^|]+") do
                    expect(point:match("^0,%d+%.%d+,%d+%.%d+$") ~= nil).toBe(true)
                end
            end
        end
    end)

    it("o Guia só cria a categoria onde há dados, e o Forever carrega o arquivo", function()
        local src = loader.read("Carbonite/Data/Shared/NxMapGuide.lua")
        expect(src:find('if Nx.GuideData and Nx.GuideData[L["Spirit Healer"]] then', 1, true) ~= nil).toBe(true)
        expect(loader.read("Carbonite/Data/camelot/Guides/guide.xml"):find("SpiritHealer.lua", 1, true) ~= nil).toBe(true)
    end)
end)
