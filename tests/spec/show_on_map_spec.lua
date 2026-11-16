-- Carbonite.Quests/ShowOnMap.lua: "Show on map" button on the journal's quest details (#72)

local function load(cur, quest)
    local env = wow.lenientEnv()
    env.Nx = wow.namespace({
        Quests = { [100] = quest },
        Quest = wow.namespace({
            FindCur = function() return 1, cur end,
            UnpackSE = function(_, s) return (s:match("^([^|]*)")) end,
        }),
    })
    loader.run(env, "Carbonite.Quests/ShowOnMap.lua")
    return env.Nx.Quest.ShowOnMap
end

describe("Mostrar no mapa", function()
    it("quest em andamento mostra os objetivos", function()
        expect(load({ Complete = false }, {}):Target(100)).toBe("objectives")
    end)

    it("quest completa mostra para quem entregar", function()
        local kind, npc = load({ Complete = true }, { End = "Maggran Ata Terra|1412|32|30|40" }):Target(100)
        expect(kind).toBe("turnin")
        expect(npc).toBe("Maggran Ata Terra")
    end)

    it("sem nome conhecido de quem recebe, não inventa um", function()
        local _, npc = load({ Complete = true }, { End = "3441|1412|32|30|40" }):Target(100)
        expect(npc).toBeNil()
    end)

    it("o botão do diário mostra a quest selecionada e some sem quest", function()
        local SM = load({}, {})
        local shown
        SM.DetailsButton = { SetShown = function(_, v) shown = v end }
        SM:SetDetailsQuest(100, 3)
        expect(shown).toBe(true)
        expect(SM.DetailsButton.NxQuestID).toBe(100)
        expect(SM.DetailsButton.NxInLog).toBe(true)
        SM:SetDetailsQuest(0, 0)
        expect(shown).toBe(false)
    end)

    it("o diário cria o botão e avisa a quest selecionada", function()
        local src = loader.read("Carbonite.Quests/QuestWindow.lua")
        expect(src:find("Nx.Quest.ShowOnMap:AttachToDetails (f)", 1, true) ~= nil).toBe(true)
        expect(src:find("Quest.ShowOnMap:SetDetailsQuest (qId, qIndex)", 1, true) ~= nil).toBe(true)
    end)

    it("o monitor de missões não tem botão próprio", function()
        expect(loader.read("Carbonite.Quests/ShowOnMap.lua"):find("hooksecurefunc", 1, true)).toBeNil()
    end)

    it("entra em todos os TOCs depois do SpokenPlay", function()
        for _, flavor in ipairs({ "-Camelot", "-Classic", "-Tbc", "-Wrath", "-Cata", "-Mists", "" }) do
            local toc = loader.read("Carbonite.Quests/Carbonite.Quests" .. flavor .. ".toc")
            expect(toc:find("SpokenPlay.lua\r?\nShowOnMap.lua") ~= nil).toBe(true)
        end
    end)
end)
