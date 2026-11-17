-- Áreas dos objetivos no mapa: spawns próximos viram uma área (#65)

local function load()
    local env = wow.lenientEnv()
    env.Nx = wow.namespace({ Quest = wow.namespace() })
    loader.run(env, "Carbonite.Quests/ObjectiveAreas.lua")
    return env.Nx.Quest.ObjectiveAreas
end

local function pt(x, y) return { x = x, y = y } end

local function loc(map, x, y) return "Kobold|" .. map .. "|32|" .. x .. "|" .. y end

describe("ObjectiveAreas.Cluster", function()
    it("separa pontos distantes e junta os próximos", function()
        local OA = load()
        local groups = OA.Cluster({ pt(10, 10), pt(12, 10), pt(50, 50), pt(11, 12) }, 5)
        expect(#groups).toBe(2)
        expect(#groups[1]).toBe(3)
        expect(#groups[2]).toBe(1)
        expect(groups[2][1].x).toBe(50)
    end)

    it("encadeia vizinhos (ligação simples)", function()
        local OA = load()
        local groups = OA.Cluster({ pt(0, 0), pt(4, 0), pt(8, 0), pt(12, 0) }, 5)
        expect(#groups).toBe(1)
        expect(#groups[1]).toBe(4)
    end)

    it("pesa o y pelo yScale", function()
        local OA = load()
        -- 6 de distância em y; com yScale 0.5 vira 3, abaixo do limite 5
        expect(#OA.Cluster({ pt(0, 0), pt(0, 6) }, 5)).toBe(2)
        expect(#OA.Cluster({ pt(0, 0), pt(0, 6) }, 5, 0.5)).toBe(1)
    end)

    it("lista vazia não gera grupo", function()
        expect(#load().Cluster({}, 5)).toBe(0)
    end)
end)

describe("ObjectiveAreas.Bounds", function()
    it("cobre o grupo com margem", function()
        local x1, y1, x2, y2 = load().Bounds({ pt(10, 20), pt(30, 25), pt(15, 40) }, 2, 3)
        expect(x1).toBe(8)
        expect(y1).toBe(17)
        expect(x2).toBe(32)
        expect(y2).toBe(43)
    end)

    it("não sai da zona (0..100)", function()
        local x1, y1, x2, y2 = load().Bounds({ pt(1, 99), pt(2, 98) }, 5)
        expect(x1).toBe(0)
        expect(y1).toBe(93)
        expect(x2).toBe(7)
        expect(y2).toBe(100)
    end)

    it("grupo vazio não tem envoltória", function()
        expect(load().Bounds({}, 1)).toBeNil()
    end)
end)

describe("ObjectiveAreas.Build", function()
    it("vira área a partir de 3 pontos e deixa os isolados como ponto", function()
        local OA = load()
        local a, b, c = loc(1429, 40, 40), loc(1429, 42, 41), loc(1429, 41, 43)
        local lone = loc(1429, 80, 80)
        local r = OA.Build({ a, b, c, lone })
        expect(#r.areas).toBe(1)
        local area = r.areas[1]
        expect(area.mapID).toBe(1429)
        expect(area.count).toBe(3)
        expect(area.x1 < 40 and area.x2 > 42).toBe(true)
        expect(area.y1 < 40 and area.y2 > 43).toBe(true)
        expect(r.grouped[a] and r.grouped[b] and r.grouped[c]).toBe(true)
        expect(r.grouped[lone]).toBeNil()
    end)

    it("dois pontos próximos continuam pontos", function()
        local r = load().Build({ loc(1429, 40, 40), loc(1429, 41, 40) })
        expect(#r.areas).toBe(0)
    end)

    it("agrupa por mapa e ignora áreas, sentinelas e lixo", function()
        local r = load().Build({
            loc(1429, 40, 40), loc(1429, 41, 40),
            loc(1411, 40, 40),
            "Kobold|1429|35|40|40|10|10",
            "Kobold|0|32|41|41",
            "",
        })
        expect(#r.areas).toBe(0)
    end)
end)

describe("ObjectiveAreas:Get", function()
    it("guarda o resultado por objetivo e refaz quando os pontos mudam", function()
        local OA = load()
        local obj = { loc(1429, 40, 40), loc(1429, 42, 41), loc(1429, 41, 43) }
        local first = OA:Get(obj)
        expect(OA:Get(obj)).toBe(first)
        obj[4] = loc(1429, 43, 42)
        local second = OA:Get(obj)
        expect(second == first).toBe(false)
        expect(second.areas[1].count).toBe(4)
    end)
end)

describe("ObjectiveAreas: integração", function()
    it("todas as TOCs carregam o módulo antes do MapIcons", function()
        for _, flavor in ipairs({ "", "-Camelot", "-Classic", "-Tbc", "-Wrath", "-Cata", "-Mists" }) do
            local toc = loader.read("Carbonite.Quests/Carbonite.Quests" .. flavor .. ".toc")
            local a = toc:find("ObjectiveAreas.lua", 1, true)
            local b = toc:find("MapIcons.lua", 1, true)
            expect(a ~= nil and a < b).toBe(true)
        end
    end)

    it("a opção vem ligada por padrão e tem textos em enUS e ptBR", function()
        expect(loader.read("Carbonite.Quests/NxQuest.lua"):find("MapShowObjectiveAreas = true", 1, true) ~= nil).toBe(true)
        for _, lang in ipairs({ "enUS", "ptBR" }) do
            local src = loader.read("Carbonite.Quests/Locales/" .. lang .. ".lua")
            expect(src:find('L["Show Objective Areas"]', 1, true) ~= nil).toBe(true)
        end
    end)
end)
