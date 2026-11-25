-- Tooltip of Carbonite's gathering pins under the integrated minimap (#275):
-- with Find Herbs/Minerals on, the pins sit below the live minimap (#214),
-- so the minimap forwards the hover to the pin under the cursor.

local function pin(name, cx, cy, over)
    return {
        NxTip = name, NxGatherOverlayActive = true,
        IsShown = function() return true end,
        IsMouseOver = function() return over end,
        GetEffectiveScale = function() return 1 end,
        GetCenter = function() return cx, cy end,
    }
end

local function setup(tracking)
    local hoverFrame
    local env = wow.lenientEnv({
        GetCursorPosition = function() return 100, 100 end,
        CreateFrame = function()
            hoverFrame = { SetScript = function(self, _, fn) self.onUpdate = fn end }
            return hoverFrame
        end,
    })
    env.Carbonite.Compat = { Expansion = {} }
    loader.run(env, "Carbonite/Modules/Map/MiniMap.lua")
    local log = {}
    local mmOver = true
    local map = {
        MMZoomType = 1,
        MMFrm = { IsVisible = function() return true end, IsMouseOver = function() return mmOver end },
        MinimapGatherTracking = function() return tracking end,
        GatherOverlayFrms = {},
        IconOnEnter = function(f) log[#log + 1] = "enter " .. tostring(f.NxTip) end,
        IconOnLeave = function(f) log[#log + 1] = "leave " .. tostring(f.NxTip) end,
    }
    env.Nx = { Map = { Maps = { map } } }
    local MM = env.Carbonite.Modules.Map.MiniMap
    return {
        MM = MM, map = map, log = log,
        tick = function() hoverFrame.onUpdate(hoverFrame, 1) end,
        frame = function() return hoverFrame end,
        leaveMinimap = function() mmOver = false end,
    }
end

describe("ícone de coleta embaixo do minimapa integrado", function()
    it("acha o ícone sob o cursor, o mais próximo do centro", function()
        local t = setup(true)
        local far, near = pin("Far", 104, 104, true), pin("Near", 101, 100, true)
        t.map.GatherOverlayFrms = { pin("Out", 100, 100, false), far, near }
        expect(t.MM:GatherPinAtCursor(t.map)).toBe(near)
    end)

    it("ignora ícone sem tooltip ou reaproveitado por outro tipo", function()
        local t = setup(true)
        local noTip, reused = pin(nil, 100, 100, true), pin("Reused", 100, 100, true)
        reused.NxGatherOverlayActive = nil
        t.map.GatherOverlayFrms = { noTip, reused }
        expect(t.MM:GatherPinAtCursor(t.map)).toBe(nil)
    end)

    it("sem rastreamento não procura: o ícone já fica por cima do minimapa", function()
        local t = setup(false)
        t.map.GatherOverlayFrms = { pin("Peacebloom", 100, 100, true) }
        expect(t.MM:GatherPinAtCursor(t.map)).toBe(nil)
    end)

    it("mostra e esconde o tooltip conforme o cursor passa pelo ícone", function()
        local t = setup(true)
        local herb = pin("Silverleaf", 100, 100, true)
        t.map.GatherOverlayFrms = { herb }
        local mmFrame = {}
        t.MM:OnEnter(mmFrame)
        t.tick()
        expect(t.log[#t.log]).toBe("enter Silverleaf")
        t.tick()
        expect(#t.log).toBe(2)  -- minimap enter + pin enter, no repeat
        herb.IsMouseOver = function() return false end
        t.tick()
        expect(t.log[#t.log]).toBe("leave Silverleaf")
    end)

    it("sair do minimapa fecha o tooltip do ícone e para de olhar o cursor", function()
        local t = setup(true)
        t.map.GatherOverlayFrms = { pin("Earthroot", 100, 100, true) }
        t.MM:OnEnter({})
        t.tick()
        t.MM:OnLeave({ NxTip = "minimap" })
        expect(t.log[#t.log - 1]).toBe("leave Earthroot")
        expect(t.frame().onUpdate).toBe(nil)
    end)

    it("para sozinho se o OnLeave do minimapa não vier", function()
        local t = setup(true)
        t.map.GatherOverlayFrms = { pin("Briarthorn", 100, 100, true) }
        t.MM:OnEnter({})
        t.tick()
        t.leaveMinimap()
        t.tick()
        expect(t.log[#t.log]).toBe("leave Briarthorn")
        expect(t.frame().onUpdate).toBe(nil)
    end)

    it("no minimapa acoplado não faz nada", function()
        local t = setup(true)
        t.map.MMZoomType = 0
        t.MM:OnEnter({})
        expect(t.frame()).toBe(nil)
    end)
end)
