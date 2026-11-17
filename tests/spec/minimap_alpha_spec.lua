-- Minimap transparency options (#32)

describe("transparência do minimapa", function()
    local engine = loader.read("Carbonite/Modules/Map/MapEngine.lua")
    local options = loader.read("Carbonite/Modules/Options/OptionsEngine.lua")

    it("as duas opções gravam onde o mapa lê (MapSettings)", function()
        expect(options:find('mapRange(101, L["Transparency"], 0, 1, .01, mapSettings, "NXMMAlpha")', 1, true) ~= nil).toBe(true)
        expect(options:find('mapRange(104, L["Docked Transparency"], 0, 1, .01, mapSettings, "NXMMDockAlpha")', 1, true) ~= nil).toBe(true)
        expect(engine:find("local al = lOpts.NXMMAlpha", 1, true) ~= nil).toBe(true)
    end)

    it("acoplado usa a transparência acoplada, não 1 fixo", function()
        expect(engine:find("al = lOpts.NXMMDockAlpha or 1", 1, true) ~= nil).toBe(true)
        expect(engine:find("mm:SetAlpha (self.MMUnmappedInstance and 1 or (self.LOpts.NXMMDockAlpha or 1))", 1, true) ~= nil).toBe(true)
        expect(engine:find("if zoomType == 0 then\r?\n%s*al = 1\r?\n")).toBeNil()
        expect(engine:find("if self.MMZoomType == 0 then\r?\n%s*mm:SetAlpha %(1%)")).toBeNil()
    end)

    it("masmorra sem mapa continua opaca", function()
        expect(engine:find("if unmappedInstance then\r?\n%s*zoomType = 0\r?\n%s*al = 1")).toBeTruthy()
    end)
end)
