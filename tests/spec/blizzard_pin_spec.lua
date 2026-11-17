-- Blizzard's 3D waypoint pin on Carbonite's navigation target (#81)

local function load(opts)
    opts = opts or {}
    local env = wow.lenientEnv()
    local state = { waypoint = nil, sets = 0, clears = 0, seeds = 0, tracked = false, now = 0 }
    env.GetTime = function() return state.now end
    env.InCombatLockdown = function() return opts.combat or false end
    env.WorldMapFrame = { IsShown = function() return opts.mapOpen or false end }
    env.UiMapPoint = { CreateFromCoordinates = function(m, x, y) return { uiMapID = m, position = { x = x, y = y } } end }
    env.C_Map = {
        SetUserWaypoint = function(p) state.waypoint = p state.sets = state.sets + 1 end,
        GetUserWaypoint = function() return state.waypoint end,
        ClearUserWaypoint = function() state.waypoint = nil state.clears = state.clears + 1 end,
        CanSetUserWaypointOnMap = function() return true end,
    }
    env.C_SuperTrack = { SetSuperTrackedUserWaypoint = function(on) state.tracked = on end }
    local map = { Targets = {} }
    function map:GetZonePos(_, wx, wy) return wx, wy end    -- world == zone percent here
    env.Carbonite = { Modules = { Map = {} } }
    env.Nx = {
        db = { profile = { Track = { BlizzardPin = not opts.off } } },
        Map = { GetMap = function() return map end },
        Quest = { SeedUserWaypoint = function() state.seeds = state.seeds + 1 end },
    }
    loader.run(env, "Carbonite/Modules/Map/BlizzardPin.lua")
    return env.Carbonite.Modules.Map.BlizzardPin, map, state, env
end

local function target(mapId, x, y, extra)
    local t = { MapId = mapId, TargetMX = x, TargetMY = y }
    for k, v in pairs(extra or {}) do t[k] = v end
    return t
end

describe("pino 3D", function()
    it("põe o pino da Blizzard no destino e o super rastreia", function()
        local BP, map, state = load()
        map.Targets[1] = target(1429, 42, 65)
        BP:Sync()
        expect(state.waypoint.uiMapID).toBe(1429)
        expect(state.waypoint.position.x).toBe(0.42)
        expect(state.tracked).toBe(true)
        expect(state.seeds).toBe(1)        -- o ouvinte do pino não cria alvo de volta
        BP:Sync()
        expect(state.sets).toBe(1)         -- mesmo destino: não repõe
    end)

    it("tira o pino quando o destino some, mas só se ainda for o nosso", function()
        local BP, map, state = load()
        map.Targets[1] = target(1429, 42, 65)
        BP:Sync()
        map.Targets[1] = nil
        BP:Sync()
        expect(state.clears).toBe(1)

        map.Targets[1] = target(1429, 10, 10)
        BP:Sync()
        state.now = state.now + 10
        state.waypoint = { uiMapID = 1429, position = { x = 0.9, y = 0.9 } }   -- o jogador pôs outro
        map.Targets[1] = nil
        BP:Sync()
        expect(state.clears).toBe(1)
        expect(state.waypoint.position.x).toBe(0.9)
    end)

    it("alvo que veio do pino da Blizzard não ganha outro pino", function()
        local BP, map, state = load()
        map.Targets[1] = target(1429, 42, 65, { UserWaypoint = true })
        BP:Sync()
        expect(state.sets).toBe(0)
    end)

    it("não mexe em combate, com o mapa do jogo aberto ou com a opção desligada", function()
        for _, opts in ipairs({ { combat = true }, { mapOpen = true }, { off = true } }) do
            local BP, map, state = load(opts)
            map.Targets[1] = target(1429, 42, 65)
            BP:Sync()
            expect(state.sets).toBe(0)
        end
    end)
end)

describe("pino 3D: o marcador devolvido pelo cliente continua sendo nosso", function()
    it("logo após pôr, aceita o ponto como o cliente guardou (outro mapa, posição arredondada)", function()
        local BP, map, state = load()
        state.now = 100
        map.Targets[1] = target(1454, 42, 65)
        BP:Sync()
        -- The client reports it on the parent map, a little moved.
        state.waypoint = { uiMapID = 1411, position = { x = 0.4567, y = 0.1234 } }
        expect(BP:OwnsWaypoint()).toBe(true)
        -- Later, the same reported point is still ours.
        state.now = 130
        expect(BP:OwnsWaypoint()).toBe(true)
        -- A different point dropped later by the player is not.
        state.waypoint = { uiMapID = 1411, position = { x = 0.9, y = 0.9 } }
        expect(BP:OwnsWaypoint()).toBe(false)
    end)

    it("sem pino nosso, nada é nosso", function()
        local BP, _, state = load()
        state.waypoint = { uiMapID = 1429, position = { x = 0.5, y = 0.5 } }
        expect(BP:OwnsWaypoint()).toBe(false)
    end)

    it("o ouvinte do marcador ignora o nosso pino e não troca o destino", function()
        local src = loader.read("Carbonite.Quests/SuperTrack.lua")
        expect(src:find("if pin and pin.OwnsWaypoint and pin:OwnsWaypoint() then", 1, true) ~= nil).toBe(true)
    end)
end)
