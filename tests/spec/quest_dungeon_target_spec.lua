-- Quest de masmorra: o clique leva até a entrada da masmorra (#224)

local DUNGEON, OUTDOOR = 9001, 1445

local function load(opts)
    opts = opts or {}
    local env = wow.lenientEnv({
        IsInInstance = function() return opts.inside or false end,
    })
    env.Nx = wow.namespace({
        Map = wow.namespace({
            MapWorldInfo = {
                [DUNGEON] = { Instance = true, X = 1234, Y = 567, EntryMId = OUTDOOR },
                [OUTDOOR] = {},
            },
            GetMap = function() return { PlyrX = 0, PlyrY = 0 } end,
        }),
    })
    loader.run(env, "Carbonite.Quests/Tracking.lua")
    local Q = env.Nx.Quest
    Q.UnpackObjectiveNew = function() return "Barão", opts.zone or DUNGEON, nil end
    Q.IsUsableObjective = function() return opts.usable or false end
    Q.IsInstanceZone = function(_, zone)
        local w = env.Nx.Map.MapWorldInfo[zone]
        return w ~= nil and w.Instance == true
    end
    Q.GetClosestObjectivePos = function() return nil end
    return Q
end

local quest = { Objectives = { { "objetivo" } } }

describe("destino de quest com objetivo dentro de masmorra", function()
    it("fora da masmorra, vai até a entrada", function()
        local Q = load()
        local res = Q.ResolveTrackTarget(Q, quest, 100, 1, false)
        expect(res ~= nil).toBe(true)
        expect(res.entrance).toBe(true)
        expect(res.mId).toBe(OUTDOOR)
        expect(res.x1).toBe(1234)
        expect(res.y1).toBe(567)
    end)

    it("dentro da masmorra, sem posição, não dá destino nem mexe no mapa", function()
        local Q = load({ inside = true })
        local res, why = Q.ResolveTrackTarget(Q, quest, 100, 1, false)
        expect(res).toBeNil()
        expect(why).toBe("objective is inside a dungeon, no position")
    end)

    it("objetivo fora de masmorra sem posição continua sem destino de entrada", function()
        local Q = load({ zone = OUTDOOR })
        local res = Q.ResolveTrackTarget(Q, { Objectives = { { "x" } } }, 100, 1, false)
        expect(res == nil or res.entrance == nil).toBe(true)
    end)
end)
