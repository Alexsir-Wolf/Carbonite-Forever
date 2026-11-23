-- Guide icons get their full path, and zone connections cover every map id (#243)

local function band(a, b)
    local r, bit = 0, 1
    a, b = tonumber(a) or 0, tonumber(b) or 0
    while a > 0 and b > 0 do
        if a % 2 == 1 and b % 2 == 1 then r = r + bit end
        a, b, bit = math.floor(a / 2), math.floor(b / 2), bit * 2
    end
    return r
end

local function split(sep, str)
    local out = {}
    for piece in (str .. sep):gmatch("(.-)%" .. sep) do out[#out + 1] = piece end
    return unpack(out)
end

local function guide()
    local env = wow.lenientEnv({ bit = { band = band }, strbyte = string.byte })
    env.Nx = wow.namespace({
        db = { profile = { Map = { IconGatherA = 1, IconGatherAtScale = 1 } }, char = { Map = {} } },
        Map = wow.namespace({ Guide = wow.namespace(), ContCnt = 2, MapWorldInfo = {} }),
    })
    loader.run(env, "Carbonite/Data/Shared/NxMapGuide.lua")
    return env.Nx.Map.Guide, env.Nx
end

-- A map that records the textures handed to AddIconPt.
local function recordingMap(textures)
    local map = {
        GetCurrentMapId = function() return 1429 end,
        IdToContZone = function() return 1 end,
        AddIconPt = function(_, kind, _, _, _, _, tex)
            textures[#textures + 1] = kind .. "=" .. tostring(tex)
            return {}
        end,
    }
    return setmetatable(map, { __index = function() return function() end end })
end

describe("caminho dos ícones do Guia", function()
    local Paths = guide()

    it("nome puro ganha a pasta de ícones do jogo", function()
        expect(Paths.IconPath("INV_Misc_Map02")).toBe("Interface\\Icons\\INV_Misc_Map02")
    end)

    it("caminho completo e atlas ficam como estão", function()
        local gfx = "Interface\\AddOns\\Carbonite\\Gfx\\Icons\\inv_scroll_11"
        expect(Paths.IconPath(gfx)).toBe(gfx)
        expect(Paths.IconPath("atlas:TaxiNode_Neutral")).toBe("atlas:TaxiNode_Neutral")
    end)

    it("nome vazio ou ausente não vira textura", function()
        expect(Paths.IconPath(nil)).toBeNil()
        expect(Paths.IconPath("")).toBeNil()
    end)

    it("a entrada de masmorra no mapa recebe o caminho completo", function()
        local Guide, Nx = guide()
        local textures = {}
        Guide.Map = recordingMap(textures)
        Nx.Map.MapWorldInfo[3039] = { X = 10, Y = 20 }
        Guide.ShowFolders = { ["%In3039"] = { Tx = "INV_Misc_Map02", InstMapId = 3039, InstTip = "Krol'dok" } }
        Guide:UpdateMapIcons()
        expect(table.concat(textures, ",")).toBe("!GIn=Interface\\Icons\\INV_Misc_Map02")
    end)

    it("pasta sem ícone não dá erro", function()
        local Guide, Nx = guide()
        Guide.Map = recordingMap({})
        Nx.Map.MapWorldInfo[3039] = { X = 10, Y = 20 }
        Guide.ShowFolders = { ["%In3039"] = { InstMapId = 3039, InstTip = "Krol'dok" } }
        expect(function() Guide:UpdateMapIcons() end).toNotThrow()
    end)
end)

describe("conexões de zona", function()
    local function engine()
        local env = wow.lenientEnv({ bit = { band = band } })
        env.Nx = wow.namespace({ Map = wow.namespace(), db = { profile = { Map = {} } }, Split = split })
        loader.run(env, "Carbonite/Modules/Map/MapEngine.lua")
        return env.Nx
    end

    local function build(connections)
        local Nx = engine()
        Nx.ZoneConnections = connections
        local worldInfo = { [1429] = {}, [3039] = {} }
        local map = setmetatable({
            GetWorldPos = function(_, _, x, y) return x, y end,
            IdToContZone = function() return 1 end,
        }, { __index = Nx.Map })
        map:InitZoneConnections(worldInfo)
        return worldInfo
    end

    it("mapa com id acima de 2999 também ganha conexões", function()
        local worldInfo = build({ "1|1|Elwynn|1429|10|10|Krol'dok|3039|20|20" })
        expect(#(worldInfo[1429].Connections[3039] or {})).toBe(1)
        expect(#(worldInfo[3039].Connections[1429] or {})).toBe(1)
    end)

    it("conexão de mão única não volta", function()
        local worldInfo = build({ "0|1|Elwynn|1429|10|10|Krol'dok|3039|20|20" })
        expect(#(worldInfo[1429].Connections[3039] or {})).toBe(1)
        expect(worldInfo[3039].Connections[1429]).toBeNil()
    end)
end)
