-- Nx.Map:ClipFrameTL3D in Carbonite/Modules/Map/MapEngine.lua (#34)

local function load()
    local env = wow.lenientEnv()
    env.Nx = wow.namespace({ Map = wow.namespace(), db = { profile = { Map = { View3DSub = 3 } } } })
    loader.run(env, "Carbonite/Modules/Map/MapEngine.lua")
    return env.Nx.Map
end

describe("ClipFrameTL3D com cantos atrás da câmera", function()
    it("esconde o tile de mar em vez de dar erro com x3 nulo", function()
        local Map = load()
        local hidden = false
        local frm = {
            NxSea = true,
            texture = { SetVertexOffset = function() end, Show = function() end,
                        SetTexCoord = function() end },
            Hide = function() hidden = true end, Show = function() end,
            SetPoint = function() end, SetWidth = function() end, SetHeight = function() end,
        }
        local map = setmetatable({
            ScaleDraw = 1, MapPosXDraw = 0, MapPosYDraw = 0, MapW = 400, MapH = 300, TitleH = 0,
            Frames3D = {},
            -- the lower-left corner projects behind the camera
            Project3D = function(_, x, y) if x == 200 and y == 250 then return nil end return x, y end,
        }, { __index = Map })
        local ok, err = pcall(Map.ClipFrameTL3D, map, frm, 0, 100, 100, 100)
        expect(ok and "ok" or tostring(err)).toBe("ok")
        expect(hidden).toBe(true)
    end)
end)
