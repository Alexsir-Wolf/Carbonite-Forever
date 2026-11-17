-- Minimap in a dungeon chart's boss panel under Carbonite windows opened over the map

describe("minimapa da planta sob janelas do Carbonite", function()
    local engine = loader.read("Carbonite/Modules/Map/MapEngine.lua")

    it("esconde o minimapa quando uma janela acima do mapa o cobre", function()
        expect(engine:find("if self.UInstChartFrm and self:MinimapCoveredByWindow() then", 1, true) ~= nil).toBe(true)
    end)

    it("só conta janelas acima da janela do mapa (o monitor fica atrás)", function()
        expect(engine:find("aboveMapWindow(win, self.Win)", 1, true) ~= nil).toBe(true)
        expect(engine:find("return (win.RaisedSeq or 0) > (mapWin.RaisedSeq or 0)", 1, true) ~= nil).toBe(true)
        expect(loader.read("Carbonite/Modules/UI/UIEngine.lua"):find('hooksecurefunc (f, "Raise"', 1, true) ~= nil).toBe(true)
    end)
end)
