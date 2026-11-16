-- Nx.Quest:SynthHeader in Carbonite.Quests/DataAndComm.lua (#2)

local function load(faction)
    local env = wow.lenientEnv()
    env.UnitFactionGroup = function() return faction end
    env.Nx = wow.namespace({ Quest = {}, Split = function(sep, s)
        local out = {}
        for part in (s .. sep):gmatch("(.-)%" .. sep) do out[#out + 1] = part end
        return unpack(out)
    end })
    loader.run(env, "Carbonite.Quests/DataAndComm.lua")
    return env.Nx.Quest
end

describe("Quest:SynthHeader", function()
    it("usa o formato dos dados, sem colchetes no nome", function()
        local Quest = load("Alliance")
        local name, side, level = Quest:Unpack(Quest:SynthHeader("A Ameaça", 12))
        expect(name).toBe("A Ameaça")
        expect(side).toBe(1)
        expect(level).toBe(12)
    end)

    it("marca a Horda como lado 2", function()
        local Quest = load("Horde")
        local _, side = Quest:Unpack(Quest:SynthHeader("X", 5))
        expect(side).toBe(2)
    end)

    it("tira o separador do título e trata título vazio", function()
        local Quest = load("Alliance")
        expect(Quest:UnpackName(Quest:SynthHeader("a|b", 1))).toBe("ab")
        expect(Quest:UnpackName(Quest:SynthHeader("", 1))).toBe("?")
    end)
end)
