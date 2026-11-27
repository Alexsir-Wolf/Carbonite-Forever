-- Área de missão (blob) no mapa da própria missão e apagada ao desmarcar (#294)
-- Carbonite.Quests/Tracking.lua

describe("blob da área de missão", function()
    local src = loader.read("Carbonite.Quests/Tracking.lua")

    it("desenha no mapa do alvo da missão, não na zona exibida", function()
        expect(src:find("function Nx.Quest:UpdateQuestBlob (qId, mapId)", 1, true) ~= nil).toBe(true)
        expect(src:find("local c, z = QMap:IdToContZone (mapId)", 1, true) ~= nil).toBe(true)
        expect(src:find("QMap.QuestWin:SetMapID (zone)", 1, true) ~= nil).toBe(true)
        expect(src:find("QMap:ClipZoneFrm (cont, zone, QMap.QuestWin, 1)", 1, true) ~= nil).toBe(true)
        expect(src:find("QMap.QuestWin:SetMapID (QMap.Zone)", 1, true)).toBe(nil)
        expect(src:find("and qId or nil, res.mId)", 1, true) ~= nil).toBe(true)
    end)

    it("apaga o blob da missão desmarcada mesmo sem ser o alvo do mapa", function()
        expect(src:find("if tbits == 0 and QMapOff and QMapOff.QuestBlobQId == qId then", 1, true) ~= nil).toBe(true)
    end)
end)
