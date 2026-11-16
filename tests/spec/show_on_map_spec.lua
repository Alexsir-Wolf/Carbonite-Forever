-- Carbonite.Quests/ShowOnMap.lua: "Show on map" button on each quest of the watch list (#72)

local function load(cur, quest)
    local env = wow.lenientEnv()
    env.Nx = wow.namespace({
        List = {},
        Quests = { [100] = quest },
        Quest = wow.namespace({
            FindCur = function() return 1, cur end,
            UnpackSE = function(_, s) return (s:match("^([^|]*)")) end,
        }),
    })
    loader.run(env, "Carbonite.Quests/SpokenPlay.lua")
    loader.run(env, "Carbonite.Quests/ShowOnMap.lua")
    return env.Nx.Quest
end

describe("Mostrar no mapa", function()
    it("quest em andamento mostra os objetivos", function()
        local Quest = load({ Complete = false }, {})
        expect(Quest.ShowOnMap:Target(100)).toBe("objectives")
    end)

    it("quest completa mostra para quem entregar", function()
        local Quest = load({ Complete = true }, { End = "Maggran Ata Terra|1412|32|30|40" })
        local kind, npc = Quest.ShowOnMap:Target(100)
        expect(kind).toBe("turnin")
        expect(npc).toBe("Maggran Ata Terra")
    end)

    it("sem nome conhecido de quem recebe, não inventa um", function()
        local Quest = load({ Complete = true }, { End = "3441|1412|32|30|40" })
        local _, npc = Quest.ShowOnMap:Target(100)
        expect(npc).toBeNil()
    end)

    it("só as linhas de título de quest ganham o botão", function()
        local Quest = load({}, {})
        local title = Quest.SpokenPlay.TitleQuestID
        expect(title(100 * 0x10000 + 3)).toBe(100)
        expect(title(100 * 0x10000 + 2 * 0x100 + 3)).toBeNil()
        expect(title(0)).toBeNil()
    end)

    it("entra em todos os TOCs depois do SpokenPlay", function()
        for _, flavor in ipairs({ "-Camelot", "-Classic", "-Tbc", "-Wrath", "-Cata", "-Mists", "" }) do
            local toc = loader.read("Carbonite.Quests/Carbonite.Quests" .. flavor .. ".toc")
            expect(toc:find("SpokenPlay.lua\r?\nShowOnMap.lua") ~= nil).toBe(true)
        end
    end)
end)
