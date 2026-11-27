-- Tooltip of the game's tracking blips on the integrated minimap (#284):
-- Carbonite's hover scripts run after the minimap's original ones instead
-- of replacing them, so the game still names beasts, herbs and the like.

describe("tooltip dos pontos de rastreamento no minimapa integrado", function()
    local engine = loader.read("Carbonite/Modules/Map/MapEngine.lua")

    it("chama o OnEnter e o OnLeave originais antes dos do Carbonite", function()
        expect(engine:find("if original%.OnEnter then original%.OnEnter%(frame, motion%) end\r?\n%s*map%.MinimapOnEnter%(frame, motion%)")).toBeTruthy()
        expect(engine:find("if original%.OnLeave then original%.OnLeave%(frame, motion%) end\r?\n%s*map%.MinimapOnLeave%(frame, motion%)")).toBeTruthy()
    end)

    it("instala os mesmos handlers sempre, sem recriar a cada troca de modo", function()
        expect(engine:find("if not self.MMHoverScripts then", 1, true) ~= nil).toBe(true)
        expect(engine:find('setScript("OnEnter", self.MMHoverScripts.OnEnter)', 1, true) ~= nil).toBe(true)
        expect(engine:find('setScript("OnLeave", self.MMHoverScripts.OnLeave)', 1, true) ~= nil).toBe(true)
        expect(engine:find('setScript("OnEnter", self.MinimapOnEnter)', 1, true)).toBe(nil)
    end)
end)

describe("anel da área de missão do minimapa no modo integrado (#284)", function()
    local engine = loader.read("Carbonite/Modules/Map/MapEngine.lua")

    it("esconde o anel só no integrado e o devolve nos outros modos", function()
        expect(engine:find('self:MinimapShowBlobRings(mode ~= "carbonite")', 1, true) ~= nil).toBe(true)
    end)

    it("zera o alpha dos anéis de missão, tarefa e escavação que o cliente tiver", function()
        expect(engine:find('{ "SetQuestBlobRingAlpha", "SetTaskBlobRingAlpha", "SetArchBlobRingAlpha" }', 1, true) ~= nil).toBe(true)
        expect(engine:find('if type(mm[method]) == "function" then', 1, true) ~= nil).toBe(true)
    end)
end)
