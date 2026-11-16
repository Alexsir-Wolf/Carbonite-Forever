-- Carbonite.Quests/QuestieSource.lua: Era points in the 4 redrawn zones (#5).

-- Linear stand-in for LibQuestieDB.EraToForeverByUiMapId: only Mulgore (1412) moves.
local function project(uiMapId, x, y)
    if uiMapId == 1412 then return x * 0.5 + 10, y * 0.5 + 20 end
    return x, y
end

local function load(quests, lib)
    local env = wow.lenientEnv()
    env.LibQuestieDB = lib
    env.hooksecurefunc = function() end
    env.UnitLevel = function() return 10 end
    env.Nx = wow.namespace({
        Quests = quests,
        Map = { MapWorldInfo = { [1412] = {} } },
        qdb = { profile = { Quest = { LevelsToLoad = 99 } } },
        PlFactionNum = 0,
        Quest = {
            Unpack = function(_, info)
                local name, side, lvl = info:match("^([^|]*)|([^|]*)|([^|]*)")
                return name, tonumber(side), tonumber(lvl)
            end,
            GetSEPos = function(_, s)
                if not s then return end
                local name, zone, _, x, y = s:match("^([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)")
                return name, tonumber(zone), tonumber(x), tonumber(y)
            end,
        },
    })
    loader.run(env, "Carbonite.Quests/QuestieSource.lua")
    return env.Nx.Quest.QuestieSource, env.Nx
end

describe("QuestieSource.ForeverLoc", function()
    local QS = load({}, nil)

    it("projeta um ponto e mantém os campos seguintes", function()
        expect(QS.ForeverLoc(project, "Talon|1412|32|40|60|5.01|3.34")).toBe("Talon|1412|32|30.00|50.00|5.01|3.34")
    end)

    it("projeta uma área pelos dois cantos", function()
        expect(QS.ForeverLoc(project, "Area|1412|35|40|60|10|20")).toBe("Area|1412|35|30.00|50.00|5.00|10.00")
    end)

    it("devolve igual o que está fora das zonas redesenhadas", function()
        local loc = "823|1429|32|48.17|42.94"
        expect(QS.ForeverLoc(project, loc)).toBe(loc)
    end)
end)

describe("QuestieSource.ConvertLoadedCoords", function()
    it("projeta cada registro uma vez e não mexe nos montados do log", function()
        local quests = {
            [1] = { Quest = "A|1|5", Start = "9|1412|32|40|60", Objectives = { { "O|1412|32|20|20" } } },
            [2] = { Quest = "B|1|5", Start = "9|1412|32|40|60", Synth = true },
        }
        local QS = load(quests, nil)
        local lib = { EraToForeverByUiMapId = project }
        QS.ConvertLoadedCoords(lib)
        QS.ConvertLoadedCoords(lib)
        expect(quests[1].Start).toBe("9|1412|32|30.00|50.00")
        expect(quests[1].Objectives[1][1]).toBe("O|1412|32|20.00|30.00")
        expect(quests[2].Start).toBe("9|1412|32|40|60")
    end)
end)
