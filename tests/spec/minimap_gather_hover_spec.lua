-- Tooltips under the integrated minimap with Find Herbs/Minerals on (#275, #279):
-- the live minimap sits over Carbonite's icons (#214) and takes the mouse,
-- and the game gives its own node blips no tooltip. The minimap forwards
-- the hover to the icon under the cursor, else names the blip from the
-- nearest GatherLite node.

local function icon(name, cx, cy, over)
    return {
        NxTip = name,
        IsShown = function() return true end,
        IsMouseOver = function() return over end,
        GetEffectiveScale = function() return 1 end,
        GetCenter = function() return cx, cy end,
    }
end

local function pool(...)
    local t = { ... }
    t.Next = #t + 1
    return t
end

local function setup(tracking)
    local frames = {}
    local env = wow.lenientEnv({
        GetCursorPosition = function() return 100, 100 end,
        CreateFrame = function()
            local f = {
                SetScript = function(self, _, fn) self.onUpdate = fn end,
                SetSize = function() end, SetPoint = function() end, Show = function() end,
            }
            frames[#frames + 1] = f
            return f
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
        IconStaticFrms = pool(), IconFrms = pool(),
        IconOnEnter = function(f) log[#log + 1] = "enter " .. tostring(f.NxTip) end,
        IconOnLeave = function(f) log[#log + 1] = "leave " .. tostring(f.NxTip) end,
    }
    env.Nx = { Map = { Maps = { map } } }
    local MM = env.Carbonite.Modules.Map.MiniMap
    return {
        env = env, MM = MM, map = map, log = log,
        tick = function() frames[1].onUpdate(frames[1], 1) end,
        hoverFrame = function() return frames[1] end,
        leaveMinimap = function() mmOver = false end,
    }
end

describe("ícone do Carbonite embaixo do minimapa integrado", function()
    it("acha o ícone sob o cursor nos dois pools, o mais próximo do centro", function()
        local t = setup(true)
        local far, near = icon("Far", 104, 104, true), icon("Near", 101, 100, true)
        t.map.IconStaticFrms = pool(icon("Out", 100, 100, false), far)
        t.map.IconFrms = pool(near)
        expect(t.MM:IconAtCursor(t.map)).toBe(near)
    end)

    it("só olha os quadros em uso do pool e ignora quadro sem tooltip", function()
        local t = setup(true)
        local stale = icon("Stale", 100, 100, true)
        t.map.IconStaticFrms = pool(icon(nil, 100, 100, true), stale)
        t.map.IconStaticFrms.Next = 2
        expect(t.MM:IconAtCursor(t.map)).toBe(nil)
    end)

    it("sem rastreamento não procura: os ícones já ficam por cima do minimapa", function()
        local t = setup(false)
        t.map.IconStaticFrms = pool(icon("Peacebloom", 100, 100, true))
        expect(t.MM:IconAtCursor(t.map)).toBe(nil)
    end)

    it("mostra e esconde o tooltip conforme o cursor passa pelo ícone", function()
        local t = setup(true)
        local herb = icon("Silverleaf", 100, 100, true)
        t.map.IconStaticFrms = pool(herb)
        t.MM:OnEnter({})
        t.tick()
        expect(t.log[#t.log]).toBe("enter Silverleaf")
        t.tick()
        expect(#t.log).toBe(2)  -- minimap enter + icon enter, no repeat
        herb.IsMouseOver = function() return false end
        t.tick()
        expect(t.log[#t.log]).toBe("leave Silverleaf")
    end)

    it("sair do minimapa fecha o tooltip e para de olhar o cursor", function()
        local t = setup(true)
        t.map.IconStaticFrms = pool(icon("Earthroot", 100, 100, true))
        t.MM:OnEnter({})
        t.tick()
        t.MM:OnLeave({ NxTip = "minimap" })
        expect(t.log[#t.log - 1]).toBe("leave Earthroot")
        expect(t.hoverFrame().onUpdate).toBe(nil)
    end)

    it("para sozinho se o OnLeave do minimapa não vier", function()
        local t = setup(true)
        t.map.IconStaticFrms = pool(icon("Briarthorn", 100, 100, true))
        t.MM:OnEnter({})
        t.tick()
        t.leaveMinimap()
        t.tick()
        expect(t.log[#t.log]).toBe("leave Briarthorn")
        expect(t.hoverFrame().onUpdate).toBe(nil)
    end)

    it("no minimapa acoplado não faz nada", function()
        local t = setup(true)
        t.map.MMZoomType = 0
        t.MM:OnEnter({})
        expect(t.hoverFrame()).toBe(nil)
    end)
end)

describe("ponto do rastreamento do jogo sem ícone do Carbonite", function()
    local function withNotes(t, tips)
        local asked = {}
        t.env.Nx.Util_IsMouseOver = function() return 60, 40 end  -- from bottom-left
        t.map.Frm = { GetHeight = function() return 100 end }
        t.map.TitleH = 10
        t.map.MapScale = 2
        t.map.GetCurrentMapId = function() return 1426 end
        t.map.FramePosToWorldPos = function(_, x, y) return x, y end
        t.env.Nx.Notes = {
            GatherLiteTipAt = function(_, mapId, wx, wy, r)
                asked[#asked + 1] = { mapId, wx, wy, r }
                return tips[#asked]
            end,
        }
        return asked
    end

    it("nomeia o ponto pelo nó do GatherLite mais perto do cursor", function()
        local t = setup(true)
        local asked = withNotes(t, { "Silverleaf" })
        expect(t.MM:BlipTipAtCursor(t.map)).toBe("Silverleaf")
        expect(asked[1][1]).toBe(1426)
        expect(asked[1][2]).toBe(60)
        expect(asked[1][3]).toBe(60)  -- 100 - 40: top-left frame position
        expect(math.abs(asked[1][4] - 8 / 10.02 / 2) < 1e-9).toBe(true)
    end)

    it("mostra, troca e fecha o tooltip do ponto", function()
        local t = setup(true)
        withNotes(t, { "Peacebloom", "Peacebloom", "Mageroyal", nil })
        t.MM:OnEnter({})
        t.tick()
        expect(t.log[#t.log]).toBe("enter Peacebloom")
        t.tick()
        expect(#t.log).toBe(2)
        t.tick()
        expect(t.log[#t.log - 1]).toBe("leave Peacebloom")
        expect(t.log[#t.log]).toBe("enter Mageroyal")
        t.tick()
        expect(t.log[#t.log]).toBe("leave Mageroyal")
    end)

    it("o ícone do Carbonite tem preferência sobre o ponto", function()
        local t = setup(true)
        withNotes(t, { "Blip" })
        t.map.IconStaticFrms = pool(icon("Icon", 100, 100, true))
        t.MM:OnEnter({})
        t.tick()
        expect(t.log[#t.log]).toBe("enter Icon")
    end)

    it("fora da área do mapa (barra de título) não procura", function()
        local t = setup(true)
        local asked = withNotes(t, { "x" })
        t.env.Nx.Util_IsMouseOver = function() return 60, 95 end
        expect(t.MM:BlipTipAtCursor(t.map)).toBe(nil)
        expect(#asked).toBe(0)
    end)
end)

describe("Nx.Notes:GatherLiteTipAt", function()
    local function load(nodes, opts)
        opts = opts or {}
        local env = wow.lenientEnv({ hooksecurefunc = function() end })
        env.Nx = {
            fdb = { profile = { Notes = { GatherLite = opts.off ~= true } } },
            Map = { GetWorldPos = function(_, _, x, y) return x, y end },
        }
        local calls = 0
        env.GatherLite = {
            db = { global = { usePredefined = true } },
            IsLoaded = function() return true end,
            IsIgnored = function(_, obj) return obj == "ignored" end,
            GetNodesForMap = function(_, kind)
                calls = calls + 1
                return nodes[kind] or {}
            end,
            GetNodeObject = function(_, obj) return { name = obj, icon = "icon" } end,
            translate = function(_, key) return key end,
        }
        loader.run(env, "Carbonite.Notes/Integrations/GatherLite.lua")
        return env.Nx.Notes, function() return calls end
    end

    it("devolve o tooltip do nó mais perto dentro do raio", function()
        local N = load({ herbalism = {
            { object = "peacebloom", posX = .5, posY = .5, type = "herbalism" },
            { object = "silverleaf", posX = .52, posY = .5, type = "herbalism" },
        } })
        local tip = N:GatherLiteTipAt(1426, 51.5, 50, 2)
        expect(tip:find("node.silverleaf", 1, true) ~= nil).toBe(true)
        expect(N:GatherLiteTipAt(1426, 60, 60, 2)).toBe(nil)
    end)

    it("ignora nós ignorados no GatherLite", function()
        local N = load({ mining = { { object = "ignored", posX = .5, posY = .5 } } })
        expect(N:GatherLiteTipAt(1426, 50, 50, 2)).toBe(nil)
    end)

    it("guarda as posições por mapa e não relê o GatherLite a cada consulta", function()
        local N, calls = load({ herbalism = { { object = "peacebloom", posX = .5, posY = .5 } } })
        N:GatherLiteTipAt(1426, 50, 50, 2)
        local first = calls()
        N:GatherLiteTipAt(1426, 50, 50, 2)
        expect(calls()).toBe(first)
        N:GatherLiteTipAt(1427, 50, 50, 2)
        expect(calls() > first).toBe(true)
    end)

    it("com a integração do GatherLite desligada não responde", function()
        local N = load({ herbalism = { { object = "peacebloom", posX = .5, posY = .5 } } }, { off = true })
        expect(N:GatherLiteTipAt(1426, 50, 50, 2)).toBe(nil)
    end)
end)
