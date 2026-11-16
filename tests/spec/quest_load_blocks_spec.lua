-- Quest data above level 60 loads only where the flavor has it (#9)

describe("carga dos blocos de quests", function()
    it("os blocos acima do 60 só são chamados quando existem", function()
        local src = loader.read("Carbonite.Quests/SuperTrack.lua")
        for _, guard in ipairs({ "> 60 and Nx.ModQuests.Load7", "> 70 and Nx.ModQuests.Load8",
                                 "> 80 and Nx.ModQuests.Load9", "> 85 and Nx.ModQuests.Load10" }) do
            expect(src:find("Nx.MaxPlayerLevel " .. guard, 1, true) ~= nil).toBe(true)
        end
    end)

    it("o Forever (camelot) não tem bloco 61-70", function()
        local toc = loader.read("Carbonite.Quests/Carbonite.Quests-Camelot.toc")
        expect(toc:find("Quests61-70", 1, true)).toBeNil()
    end)
end)
