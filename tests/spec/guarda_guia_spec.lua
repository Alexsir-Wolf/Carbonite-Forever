-- Carbonite/Modules/Map/GuardRoute.lua: the guard's directions become a
-- target on the Guide NPC of the option the player chose.

local function load(faction)
    local env = wow.lenientEnv()
    env.UnitFactionGroup = function() return faction or "Horde" end
    env.C_GossipInfo = nil
    env.C_Map = { GetPlayerMapPosition = function() return nil end }
    env.Nx = wow.namespace({
        Map = { RMapId = 1454 },
        GuideData = {
            ["Culinária Treinador"] = { Mode = 32, [1454] = "2,57.4,53.98", [1458] = "2,62.14,44.95" },
            ["Alquimia Treinador"] = { Mode = 32, [1454] = "2,55.7,33.1" },
            ["Banqueiro"] = { Mode = 32, [1454] = "1,10,10|2,49.58,69.15|2,50,68.6" },
        },
    })
    loader.run(env, "Carbonite/Modules/Map/GuardRoute.lua")
    return env.Carbonite.Modules.Map.GuardRoute
end

local function fakeMap()
    local map = { calls = {} }
    function map:SetTargetXY(...) self.calls[#self.calls + 1] = { ... } end
    return map
end

describe("rota do guarda pelo Guia", function()
    it("a opção da conversa acha o tipo do Guia", function()
        local GR = load()
        expect(GR:GuideKey("Culinária")).toBe("Culinária Treinador")
        expect(GR:GuideKey("|cff000000Banqueiro|r")).toBe("Banqueiro")
        expect(GR:GuideKey("Pesca")).toBeNil()
    end)

    it("guarda a opção escolhida pelo id ou pela posição", function()
        local GR = load()
        GR:Remember({ { gossipOptionID = 10, orderIndex = 1, name = "Alquimia" },
            { gossipOptionID = 11, orderIndex = 2, name = "Culinária" } })
        GR:Chosen(11)
        expect(GR.Choice).toBe("Culinária")
        GR:ChosenIndex(1)
        expect(GR.Choice).toBe("Alquimia")
    end)

    it("marca o NPC do Guia no mapa do jogador", function()
        local GR = load()
        GR.Choice = "Culinária"
        local map = fakeMap()
        expect(GR:Target(map)).toBe(true)
        local c = map.calls[1]
        expect(c[1]).toBe(1454)
        expect(c[2]).toBe(57.4)
        expect(c[3]).toBe(53.98)
        expect(c[4]).toBe("Culinária")
    end)

    it("ignora NPC da outra facção", function()
        local GR = load("Horde")
        -- O banqueiro da Aliança em 10,10 é o mais perto, mas não vale.
        local x, y = GR:Nearest("Banqueiro", 1454, 10, 10)
        expect(x).toBe(50)
        expect(y).toBe(68.6)
    end)

    it("sem escolha ou sem NPC no mapa, não marca nada", function()
        local GR = load()
        local map = fakeMap()
        expect(GR:Target(map)).toBe(false)
        GR.Choice = "Pesca"
        expect(GR:Target(map)).toBe(false)
        expect(#map.calls).toBe(0)
    end)

    it("o evento do guarda usa o Guia quando o jogo não dá o ponto", function()
        local src = (loader.read("Carbonite/Modules/Map/MapEngine.lua"):gsub(string.char(13), ""))
        local block = src:match('elseif event == "DYNAMIC_GOSSIP_POI_UPDATED" then(.-)elseif event')
        expect(block:find("if not map:TargetGossipPOI() then", 1, true) ~= nil).toBe(true)
        expect(block:find("guard:Target(map)", 1, true) ~= nil).toBe(true)
        expect(loader.read("Carbonite/Modules/Modules.xml"):find([[Map\GuardRoute.lua]], 1, true) ~= nil).toBe(true)
    end)
end)
