-- Nx.List:UpdateBands (Carbonite/Modules/UI/UIEngine.lua): alternating row bands

describe("faixas da lista", function()
    local src = loader.read("Carbonite/Modules/UI/UIEngine.lua")

    it("esconde as faixas que sobram sem depender de #bands (a tabela tem buracos)", function()
        expect(src:find("for n = self.Vis + 1, #bands do", 1, true)).toBeNil()
        expect(src:find("for n, t in pairs (bands) do", 1, true) ~= nil).toBe(true)
    end)
end)
