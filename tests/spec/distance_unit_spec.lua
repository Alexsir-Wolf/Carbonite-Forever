-- Distance in meters and kilometers with the game in pt-BR (#245)

local LABELS_PT = { yd = "jd", m = "m", km = "km" }
local LABELS_EN = { yd = "yds", m = "m", km = "km" }

local function load(locale, unit)
    local env = wow.lenientEnv({ GetLocale = function() return locale end })
    local L = { yds = locale == "ptBR" and "jd" or "yds", m = "m", km = "km" }
    env.LibStub = function()
        return { GetLocale = function() return L end }
    end
    env.Carbonite.Util = {}
    env.Nx = { db = { profile = { Track = { DistUnit = unit } } } }
    loader.run(env, "Carbonite/Util/Distance.lua")
    return env.Carbonite.Util.Distance, env
end

describe("unidade de distância", function()
    local Distance = load("ptBR", "auto")

    it("automática segue o idioma do jogo", function()
        expect(Distance.Unit("auto", "ptBR")).toBe("m")
        expect(Distance.Unit("auto", "enUS")).toBe("yd")
        expect(Distance.Unit(nil, "ptBR")).toBe("m")
    end)

    it("a escolha do jogador vale sobre o idioma", function()
        expect(Distance.Unit("yd", "ptBR")).toBe("yd")
        expect(Distance.Unit("m", "enUS")).toBe("m")
    end)
end)

describe("texto da distância", function()
    local Distance = load("ptBR", "auto")

    it("uma jarda vale um metro", function()
        expect(Distance.Format(319, "m", "ptBR", LABELS_PT)).toBe("319 m")
        expect(Distance.Format(319.4, "m", "ptBR", LABELS_PT)).toBe("319 m")
    end)

    it("a partir de 1000 vira quilômetro com vírgula", function()
        expect(Distance.Format(1260, "m", "ptBR", LABELS_PT)).toBe("1,3 km")
        expect(Distance.Format(999.6, "m", "ptBR", LABELS_PT)).toBe("1,0 km")
        expect(Distance.Format(15040, "m", "ptBR", LABELS_PT)).toBe("15,0 km")
    end)

    it("em inglês o quilômetro usa ponto", function()
        expect(Distance.Format(1260, "m", "enUS", LABELS_EN)).toBe("1.3 km")
    end)

    it("em jardas fica como antes", function()
        expect(Distance.Format(319, "yd", "enUS", LABELS_EN)).toBe("319 yds")
        expect(Distance.Format(319, "yd", "ptBR", LABELS_PT)).toBe("319 jd")
    end)

    it("distância inválida não dá erro", function()
        expect(Distance.Format(nil, "m", "ptBR", LABELS_PT)).toBe("0 m")
        expect(Distance.Format(-5, "yd", "enUS", LABELS_EN)).toBe("0 yds")
    end)
end)

describe("opção salva", function()
    it("jogo em pt-BR e opção automática: metros", function()
        local Distance = load("ptBR", "auto")
        expect(Distance:Text(319)).toBe("319 m")
        expect(Distance:UnitLabel()).toBe("m")
    end)

    it("jogo em inglês e opção automática: jardas, como hoje", function()
        local Distance = load("enUS", "auto")
        expect(Distance:Text(319)).toBe("319 yds")
        expect(Distance:UnitLabel()).toBe("yds")
    end)

    it("opção Jardas com o jogo em pt-BR", function()
        local Distance = load("ptBR", "yd")
        expect(Distance:Text(319)).toBe("319 jd")
    end)

    it("sem perfil carregado segue o idioma", function()
        local Distance, env = load("ptBR", nil)
        env.Nx = nil
        expect(Distance:Text(1260)).toBe("1,3 km")
    end)
end)

describe("telas que mostram distância", function()
    local FILES = {
        "Carbonite/Modules/HUD/HUDEngine.lua",
        "Carbonite/Modules/Map/MapEngine.lua",
        "Carbonite/Data/Shared/NxMapGuide.lua",
        "Carbonite/Modules/Map/TargetsWindow.lua",
        "Carbonite.Quests/WatchWindow.lua",
    }

    it("todas usam a função única, sem montar 'jardas' à mão", function()
        local found = {}
        for _, path in ipairs(FILES) do
            local src = loader.read(path)
            if src:find('L%["yds"%]') then found[#found + 1] = path end
            if not src:find("Util.Distance:Text", 1, true) then found[#found + 1] = path .. " (sem Distance:Text)" end
        end
        expect(table.concat(found, ", ")).toBe("")
    end)

    it("o arquivo é carregado pelo Util.xml", function()
        expect(loader.read("Carbonite/Util/Util.xml"):find('file="Distance.lua"', 1, true) ~= nil).toBe(true)
    end)
end)
