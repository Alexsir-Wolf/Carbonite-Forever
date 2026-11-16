-- Carbonite.Quests/QuestieSource.lua: Era points in the 4 redrawn zones (#5) and filling
-- the fields Carbonite records lack (#6).

-- Linear stand-in for LibQuestieDB.EraToForeverByUiMapId: only Mulgore (1412) moves.
local function project(uiMapId, x, y)
    if uiMapId == 1412 then return x * 0.5 + 10, y * 0.5 + 20 end
    return x, y
end

local function fakeLib(quests, npcs)
    local function ids()
        local t = {}
        for id in pairs(quests) do t[#t + 1] = id end
        table.sort(t)
        return t
    end
    return {
        RequireContract = function() return true end,
        Quest = { Get = function() end, GetAll = function(id) return quests[id] end, GetAllIds = ids },
        Npc = { Get = function(id, key) return npcs[id] and npcs[id][key] end },
        Object = { Get = function() end },
        Item = { Get = function() end },
        Support = { Get = function()
            return { private = { areaIdToUiMapId = { [215] = 1412 }, subZoneToParentZone = {} } }
        end },
        EraToForeverByUiMapId = project,
    }
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

describe("QuestieSource:Start com registro incompleto", function()
    it("preenche só os campos ausentes e indexa quem dá a quest", function()
        local quests = {
            [100] = { Quest = "Velha|1|5|1|0|0|0", End = "7|1412|32|11|22" },
        }
        local questie = {
            -- name, startedBy, finishedBy, reqLevel, questLevel, races, classes, objectives,
            -- triggerEnd, preGroup, preSingle, nextId, zone
            [100] = { "Velha", { { 50 } }, { { 51 } }, 1, 5, 0, 0, nil, nil, nil, nil, 0, 215 },
        }
        local npcs = {
            [50] = { name = "Quem Dá", spawns = { [215] = { { 47, 61 } } } },
            [51] = { name = "Quem Recebe", spawns = { [215] = { { 33, 44 } } } },
        }
        local QS, Nx = load(quests, fakeLib(questie, npcs))
        QS:Start()
        expect(quests[100].Start).toBe("Quem Dá|1412|32|47.00|61.00")
        expect(quests[100].End).toBe("7|1412|32|11|22")
        expect(quests[100].Quest).toBe("Velha|1|5|1|0|0|0")
        expect(QS.filled[1]).toBe(100)
        expect(Nx.Quest.QGivers[1412]["Quem Dá=4761"]).toContain("64")
    end)
end)
