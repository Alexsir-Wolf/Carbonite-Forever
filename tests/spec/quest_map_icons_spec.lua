-- Quest icons on the map: Blizzard atlases with fallback and scale (#49)

-- Loads QuestProvider.lua with the atlases the simulated client knows and the
-- Quest profile options; returns Nx.Quest.
local function load(atlases, prof, freq)
    local env = wow.lenientEnv()
    if atlases then
        env.C_Texture = { GetAtlasInfo = function(name) return atlases[name] and {} or nil end }
    else
        env.C_Texture = nil
    end
    env.Nx = wow.namespace({
        Quest = wow.namespace(),
        QuestFreq = freq or {},
        qdb = { profile = { Quest = prof or { MapBlizzardIcons = true, MapQuestIconScale = 1 } } },
    })
    loader.run(env, "Carbonite.Quests/QuestProvider.lua")
    return env.Nx.Quest
end

local ALL = {
    QuestNormal = true, QuestDaily = true, QuestTurnin = true,
    QuestRepeatableTurnin = true, ["Quest-In-Progress-Icon"] = true, QuestBonusObjective = true,
}

describe("ícones de quest no mapa: escolha do atlas", function()
    it("quest disponível usa QuestNormal e diária usa QuestDaily", function()
        local Q = load(ALL, nil, { [200] = "d" })
        expect(Q.GetMapIconTexture(Q.GetStartIconKind(100))).toBe("atlas:QuestNormal")
        expect(Q.GetMapIconTexture(Q.GetStartIconKind(200))).toBe("atlas:QuestDaily")
    end)

    it("quest pronta para entregar usa QuestTurnin; repetível usa QuestRepeatableTurnin", function()
        local Q = load(ALL)
        expect(Q.GetEndIconKind({ Complete = 1 }, 100)).toBe("turnin")
        expect(Q.GetMapIconTexture("turnin")).toBe("atlas:QuestTurnin")
        expect(Q.GetEndIconKind({ Complete = 1, Daily = 1 }, 100)).toBe("repeatableTurnin")
        expect(Q.GetMapIconTexture("repeatableTurnin")).toBe("atlas:QuestRepeatableTurnin")
    end)

    it("frequência 0 (padrão) não conta como repetível", function()
        local Q = load(ALL)
        expect(Q.GetEndIconKind({ Complete = 1, Daily = 0 }, 100)).toBe("turnin")
    end)

    it("quest em andamento usa o ícone de progresso; o estado do grupo pode forçar pronto", function()
        local Q = load(ALL)
        expect(Q.GetEndIconKind({}, 100)).toBe("inProgress")
        expect(Q.GetMapIconTexture("inProgress")).toBe("atlas:Quest-In-Progress-Icon")
        expect(Q.GetEndIconKind({}, 100, true)).toBe("turnin")
    end)

    it("objetivo cai no próximo atlas da lista quando o primeiro não existe", function()
        local Q = load(ALL)
        local tex, isAtlas = Q.GetMapIconTexture("objective")
        expect(tex).toBe("atlas:QuestBonusObjective")
        expect(isAtlas).toBe(true)
    end)
end)

describe("ícones de quest no mapa: fallback", function()
    it("sem C_Texture fica nas texturas antigas do Carbonite", function()
        local Q = load(nil)
        local tex, isAtlas = Q.GetMapIconTexture("available")
        expect(tex).toContain("IconExclaim")
        expect(isAtlas).toBe(false)
        expect(Q.GetMapIconTexture("daily")).toContain("IconExclaimB")
        expect(Q.GetMapIconTexture("turnin")).toContain("IconQuestion")
        expect(Q.GetMapIconTexture("objective")).toContain("IconQTarget")
    end)

    it("atlas ausente no cliente cai na textura antiga", function()
        local Q = load({ QuestNormal = true })
        expect(Q.GetMapIconTexture("available")).toBe("atlas:QuestNormal")
        expect(Q.GetMapIconTexture("turnin")).toContain("IconQuestion")
    end)

    it("com a opção desligada usa as texturas antigas", function()
        local Q = load(ALL, { MapBlizzardIcons = false })
        expect(Q.GetMapIconTexture("available")).toContain("IconExclaim")
    end)
end)

describe("ícones de quest no mapa: estilo do POI", function()
    it("atlas descarta o tom por quest e aplica a escala", function()
        local Q = load(ALL, { MapBlizzardIcons = true, MapQuestIconScale = 1.5 })
        local opts = Q.StyleMapIcon("turnin", { vertexColor = { .6, 1, .6, 1 } })
        expect(opts.tex).toBe("atlas:QuestTurnin")
        expect(opts.vertexColor).toBeNil()
        expect(opts.w).toBe(24)
        expect(opts.h).toBe(24)
    end)

    it("textura antiga mantém o tom e usa escala 1 sem opção válida", function()
        local Q = load(nil, {})
        local opts = Q.StyleMapIcon("turnin", { vertexColor = { .6, 1, .6, 1 } })
        expect(opts.vertexColor[1]).toBe(.6)
        expect(opts.w).toBe(16)
    end)

    it("o guia de quest givers usa a textura e a escala do módulo de quests", function()
        local src = loader.read("Carbonite/Data/Shared/NxMapGuide.lua")
        expect(src).toContain('Quest.GetMapIconTexture (anyDaily and "daily" or "available")')
        expect(src).toContain("Quest.GetMapIconScale()")
    end)
end)
