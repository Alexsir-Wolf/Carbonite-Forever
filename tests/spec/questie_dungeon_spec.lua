-- Carbonite.Quests/QuestieSource.lua: quests que o QuestieDB põe dentro de masmorras (#8)

local DEADMINES, ALT = 1581, 10029

local function fakeLib(quests, spawns, items)
    return {
        RequireContract = function() return true end,
        Quest = { Get = function() end, GetAll = function(id) return quests[id] end },
        Npc = { Get = function(id, key) return key == "spawns" and spawns["Npc:" .. id] or nil end },
        Object = { Get = function(id, key) return key == "spawns" and spawns["Object:" .. id] or nil end },
        Item = { Get = function(id, key) return items[id] and items[id][key] end },
        Support = { Get = function()
            return {
                instanceIdToAreaId = { [36] = DEADMINES },
                private = {
                    areaIdToUiMapId = { [40] = 1436 },
                    subZoneToParentZone = { [20000] = DEADMINES },
                    dungeons = { [DEADMINES] = { "The Deadmines", { ALT }, 40, {} } },
                },
            }
        end },
    }
end

local function load(lib)
    local env = wow.lenientEnv()
    env.LibQuestieDB = lib
    env.hooksecurefunc = function() end
    env.Nx = wow.namespace({ Quest = {} })
    loader.run(env, "Carbonite.Quests/QuestieSource.lua")
    return env.Nx.Quest.QuestieSource
end

local QUESTS = {
    -- zona da quest é a masmorra
    [1] = { DEADMINES, nil, nil },
    -- item que cai de um NPC lá dentro (id alternativo da masmorra)
    [2] = { 40, { nil, nil, { { 500, "Bandana Vermelha" } } }, nil },
    -- objetivo de NPC numa subzona da masmorra
    [3] = { 40, { { { 600 } } }, nil },
    -- entrega por um NPC lá dentro
    [4] = { 40, nil, { { 700 } } },
    -- tudo fora
    [5] = { 40, { { { 800 } } }, { { 800 } } },
}
local SPAWNS = {
    ["Npc:501"] = { [ALT] = { { -1, -1 } } },
    ["Npc:600"] = { [20000] = { { -1, -1 } } },
    ["Npc:700"] = { [DEADMINES] = { { -1, -1 } } },
    ["Npc:800"] = { [40] = { { 50, 50 } } },
}
local ITEMS = { [500] = { npcDrops = { 501 }, name = "Red Bandana" } }

describe("QuestieSource.InDungeon", function()
    local QS = load(fakeLib(QUESTS, SPAWNS, ITEMS))

    it("acha a quest pela zona, pelo item que cai lá, pelo objetivo e pela entrega", function()
        expect(QS.InDungeon(1, 36) ~= nil).toBe(true)
        expect(QS.InDungeon(3, 36) ~= nil).toBe(true)
        expect(QS.InDungeon(4, 36) ~= nil).toBe(true)
        expect(QS.InDungeon(5, 36)).toBeNil()
    end)

    it("nomeia os itens de objetivo que caem dentro da masmorra", function()
        local r = QS.InDungeon(2, 36)
        expect(r.items[1]).toBe("Bandana Vermelha")
    end)

    it("sem o QuestieDB ou com instância desconhecida não acha nada", function()
        expect(load(nil).InDungeon(1, 36)).toBeNil()
        expect(QS.InDungeon(1, 999)).toBeNil()
    end)
end)

describe("DungeonGuide com o QuestieDB (#8)", function()
    it("lista a quest e o item que cai ali no painel", function()
        local env = wow.env({
            GetTime = function() return 1 end,
            IsInInstance = function() return true end,
            GetInstanceInfo = function() return "Minas Mortas", "party", 1, "", 5, 0, false, 36 end,
        })
        local QS = { InDungeon = function(qId, id) if qId == 2 and id == 36 then return { items = { "Bandana Vermelha" } } end end }
        env.Nx = { DungeonPins = { instances = {}, pins = {}, bosses = {}, quests = {} }, db = { char = {} },
            Quest = { QuestieSource = QS, CurQ = { { QId = 2, Title = "Bandanas", Header = "Westfall" }, { QId = 9, Title = "Outra", Header = "Westfall" } } } }
        loader.run(env, "Carbonite/Modules/Map/DungeonGuide.lua")
        local text = table.concat(env.Nx.DungeonGuide:Lines(), "\n")
        expect(text:find("\nBandanas\n  |cff9d9d9dDrops here: Bandana Vermelha|r", 1, true) ~= nil).toBe(true)
        expect(text:find("Outra", 1, true)).toBeNil()
    end)
end)
