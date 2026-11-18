-- Nx.Map:TargetGossipPOI (Carbonite/Modules/Map/MapEngine.lua): the spot a
-- city guard points to becomes the target, with arrow and route.

-- Runs only TargetGossipPOI, against a fake map and C_GossipInfo.
local function targetFn(env)
    local src = (loader.read("Carbonite/Modules/Map/MapEngine.lua"):gsub(string.char(13), ""))
    local body = src:match("(function Nx%.Map:TargetGossipPOI%(%).-\nend\n)")
    assert(body, "TargetGossipPOI not found")
    local chunk = assert(loadstring(body))
    setfenv(chunk, env)
    chunk()
    return env.Nx.Map.TargetGossipPOI
end

local function setup(poi)
    local env = { Nx = { Map = { RMapId = 85 } } }
    env._G = env
    env.C_GossipInfo = {
        GetPoiForUiMapID = function(mid) return poi and mid == 85 and 7 or nil end,
        GetPoiInfo = function(mid, id)
            if not (poi and mid == 85 and id == 7) then return nil end
            return { name = poi.name, position = { GetXY = function() return poi.x, poi.y end } }
        end,
    }
    local map = { calls = {} }
    function map:SetTargetXY(...) self.calls[#self.calls + 1] = { ... } end
    return targetFn(env), map
end

describe("rota até o lugar indicado pelo guarda", function()
    it("define o destino no ponto que o guarda marcou", function()
        local target, map = setup({ name = "Treinador de Alquimia", x = .55, y = .34 })
        expect(target(map)).toBe(true)
        local c = map.calls[1]
        expect(c[1]).toBe(85)
        expect(math.abs(c[2] - 55) < 1e-9).toBe(true)
        expect(math.abs(c[3] - 34) < 1e-9).toBe(true)
        expect(c[4]).toBe("Treinador de Alquimia")
    end)

    it("sem ponto no mapa, não muda nada", function()
        local target, map = setup(nil)
        expect(target(map)).toBe(false)
        expect(#map.calls).toBe(0)
    end)

    it("o evento do guarda chama a função", function()
        local src = (loader.read("Carbonite/Modules/Map/MapEngine.lua"):gsub(string.char(13), ""))
        local block = src:match('elseif event == "DYNAMIC_GOSSIP_POI_UPDATED" then(.-)elseif')
        expect(block:find("map:TargetGossipPOI()", 1, true) ~= nil).toBe(true)
    end)
end)
