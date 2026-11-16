-- Warehouse: no English text and slot names from the client (#100)

describe("Warehouse em pt-BR", function()
    local src = loader.read("Carbonite.Warehouse/Engine.lua")

    it("não tem os textos fixos em inglês da crítica", function()
        for _, text in ipairs({ '"|cff80bfffStorage Summary|r"', ' "Character Storage"', '= "Search items..."',
                                '("  Bags scan: %s"', '("  Professions: %s"', 'ColumnAdd ("Name"' }) do
            expect(src:find(text, 1, true)).toBeNil()
        end
    end)

    it("nomeia o slot pela constante do cliente", function()
        expect(src:find("local name = _G[strupper (slot)]", 1, true) ~= nil).toBe(true)
        expect(src:find('gsub (slot, L["Slot"], "")', 1, true)).toBeNil()
    end)

    it("as chaves novas têm tradução pt-BR", function()
        local pt = loader.read("Carbonite.Warehouse/Locales/ptBR.lua")
        for _, key in ipairs({ "Storage Summary", "  Bags scan: %s", "Character Storage", "Search items...", "not scanned", "Name" }) do
            expect(pt:find('L["' .. key .. '"]', 1, true) ~= nil).toBe(true)
        end
    end)
end)
