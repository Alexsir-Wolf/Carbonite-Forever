-- Minimap in a dungeon chart's boss panel under Carbonite windows opened over the map

describe("minimapa da planta sob janelas do Carbonite", function()
    local engine = loader.read("Carbonite/Modules/Map/MapEngine.lua")

    it("esconde o minimapa quando uma janela acima do mapa o cobre", function()
        expect(engine:find("if self.UInstChartFrm and self:MinimapCoveredByWindow() then", 1, true) ~= nil).toBe(true)
    end)

    it("só conta janelas acima da janela do mapa (o monitor fica atrás)", function()
        expect(engine:find("aboveMapWindow(f, host)", 1, true) ~= nil).toBe(true)
        expect(engine:find("return f:GetFrameLevel() > host:GetFrameLevel()", 1, true) ~= nil).toBe(true)
    end)
end)
