-- Missing key bindings and the minimap button menu (#46)

describe("atalhos de teclado", function()
    local xml = loader.read("Carbonite/Bindings.xml")
    local lua = loader.read("Carbonite/Carbonite.lua")
    local pt = loader.read("Carbonite/Locales/ptBR/Bindings.lua")

    it("abrem as Opções, o HUD, o Info e limpam o destino, com nome em pt-BR", function()
        for _, name in ipairs({ "NxMAPCLEARTARGET", "NxOPENOPTIONS", "NxTOGGLEHUD", "NxTOGGLEINFO" }) do
            expect(xml:find('name="' .. name .. '"', 1, true) ~= nil).toBe(true)
            expect(lua:find("BINDING_NAME_" .. name, 1, true) ~= nil).toBe(true)
            expect(pt:find('L["' .. name .. '"]', 1, true) ~= nil).toBe(true)
        end
        expect(pt:find("skip Map target", 1, true)).toBeNil()
    end)

    it("o leilão saiu do menu do botão do minimapa e foi para as Opções Gerais", function()
        expect(loader.read("Carbonite/Modules/Map/MinimapButtonEngine.lua"):find("Show Auction Buyout Per Item", 1, true)).toBeNil()
        expect(loader.read("Carbonite/Modules/Options/OptionsEngine.lua"):find("auctionPerItem = {", 1, true) ~= nil).toBe(true)
    end)
end)
