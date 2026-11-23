-- Plantas das masmorras novas: abrir pelo ID que o jogo informa (#251)

local function load(opts)
    opts = opts or {}
    local env = wow.lenientEnv({
        IsInInstance = function() return true end,
        GetInstanceInfo = function()
            return opts.name or "The Drowned City", "party", 1, "", 5, 0, false, opts.id or 2970
        end,
        GetTime = function() return opts.now or 1 end,
    })
    env.Nx = wow.namespace({
        Zones = { [2970] = "The Drowned City|35|40|3|5|1434|21.3|27.8|5" },
    })
    local names = opts.locale or {}
    env.LibStub = function()
        return { GetLocale = function()
            return setmetatable({}, { __index = function(_, k) return names[k] or k end })
        end }
    end
    loader.run(env, "Carbonite/Modules/Map/DungeonPins.lua")
    loader.run(env, "Carbonite/Modules/Map/DungeonGuide.lua")
    return env.Nx.DungeonGuide, env.Nx.DungeonPins
end

describe("ID do jogo para a planta do MapUtils", function()
    it("as masmorras novas usam a chave provisória da planta", function()
        local DG = load()
        expect(DG.PinsKey(2970)).toBe(900001)   -- The Drowned City
        expect(DG.PinsKey(3039)).toBe(900002)   -- Krol'dok Stronghold
        expect(DG.PinsKey(2994)).toBe(900003)   -- Alcaz Prison
        expect(DG.PinsKey(3001)).toBe(900005)   -- The Shaper's Terrace
    end)

    it("as masmorras de antes continuam pelo próprio ID", function()
        local DG = load()
        expect(DG.PinsKey(389)).toBe(389)       -- Ragefire Chasm
    end)

    it("dentro da Drowned City, a planta é encontrada", function()
        local DG = load({ id = 2970 })
        local here = DG:Here()
        expect(here.id).toBe(900001)
        expect(here.data ~= nil).toBe(true)
    end)

    it("se o jogo informar outro ID, casa pelo nome da zona", function()
        local DG = load({ id = 123456, name = "The Drowned City" })
        expect(DG:Here().id).toBe(900001)
    end)

    it("casa também pelo nome traduzido", function()
        local DG = load({ id = 123456, name = "Prisão de Alcaz",
            locale = { ["dungeon:900003"] = "Prisão de Alcaz" } })
        expect(DG:Here().id).toBe(900003)
    end)

    it("masmorra desconhecida não ganha planta", function()
        local DG = load({ id = 123456, name = "Outro Lugar" })
        local here = DG:Here()
        expect(here.id).toBe(123456)
        expect(here.data).toBeNil()
    end)
end)

describe("andares de Alcaz Prison", function()
    it("tem os dois andares do MapUtils, com nome", function()
        local _, P = load()
        local floors = P.instances[900003].floors
        expect(#floors).toBe(2)
        expect(floors[2].key).toBe("900003_2")
        expect(floors[2].named).toBe(true)
    end)

    it("os andares têm nome em inglês e em português", function()
        expect(loader.read("Carbonite/Locales/enUS/Dungeons.lua")
            :find('L["floor:900003_2"] = "Maximum Security Unit"', 1, true) ~= nil).toBe(true)
        expect(loader.read("Carbonite/Locales/ptBR/Dungeons.lua")
            :find('L["floor:900003_2"]', 1, true) ~= nil).toBe(true)
    end)
end)
