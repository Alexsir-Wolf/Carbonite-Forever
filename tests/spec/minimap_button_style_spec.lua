-- Minimap button in the LibDBIcon look, dragged without Shift (#46)

local function texture()
    local t = { calls = {} }
    setmetatable(t, { __index = function(_, k)
        return function(self, ...)
            self.calls[#self.calls + 1] = { k, ... }
            if k == "SetSize" then self.w, self.h = ... end
            if k == "SetTexCoord" then self.coord = { ... } end
        end
    end })
    return t
end

local function load(opts)
    opts = opts or {}
    local env = wow.lenientEnv()
    local toggled = 0
    local frm = { icon = texture(), border = texture(), background = texture() }
    env.NXMiniMapBut = frm
    env.IsShiftKeyDown = function() return false end
    env.IsAltKeyDown = function() return false end
    env.Nx = wow.namespace({
        isRetail = opts.retail ~= false,
        db = { profile = { MiniMap = { ButOwn = opts.own or false } } },
        Map = wow.namespace({ ToggleSize = function() toggled = toggled + 1 end }),
    })
    env.Nx.NXMiniMapBut.Move = function() end
    loader.run(env, "Carbonite/Modules/Map/MinimapButtonEngine.lua")
    return env.Nx.NXMiniMapBut, frm, function() return toggled end
end

describe("botão do minimapa no padrão LibDBIcon", function()
    local xml = loader.read("Carbonite/Carbonite.xml")
    local block = xml:sub(xml:find('<Button name="NXMiniMapBut"', 1, true), -1)
    block = block:sub(1, block:find("</Button>", 1, true))

    it("tem ícone redondo com fundo e a borda dourada do minimapa", function()
        expect(block).toContain([[Interface\Minimap\MiniMap-TrackingBorder]])
        expect(block).toContain([[Interface\Minimap\UI-Minimap-Background]])
        expect(block).toContain([[Interface\Minimap\UI-Minimap-ZoomButton-Highlight]])
        expect(block).toContain('parentKey="icon"')
        expect(block:find("IsShiftKeyDown", 1, true)).toBeNil()
        expect(block:find("NormalTexture", 1, true)).toBeNil()
    end)

    it("arrasta com o botão esquerdo sem Shift", function()
        local but, frm = load()
        but:NXOnMouseDown(frm, "LeftButton")
        but:NXOnDragStart(frm, "LeftButton")
        expect(frm.NXDrag).toBe(true)
        but:NXOnDragStop(frm)
        expect(frm.NXDrag).toBe(false)
    end)

    it("não arrasta com o botão direito nem quando está no Dock", function()
        local but, frm = load()
        but:NXOnDragStart(frm, "RightButton")
        expect(frm.NXDrag).toBeFalsy()
        local docked, dfrm = load({ own = true })
        docked:NXOnDragStart(dfrm, "LeftButton")
        expect(dfrm.NXDrag).toBeFalsy()
    end)

    it("clique sem arrastar abre o mapa; o arraste não", function()
        local but, frm, toggled = load()
        but:NXOnMouseDown(frm, "LeftButton")
        but:NXOnDragStart(frm, "LeftButton")
        but:NXOnDragStop(frm)
        but:NXOnMouseUp(frm, "LeftButton")
        but:NXOnClick("LeftButton")
        expect(toggled()).toBe(0)

        but:NXOnMouseDown(frm, "LeftButton")
        but:NXOnMouseUp(frm, "LeftButton")
        but:NXOnClick("LeftButton")
        expect(toggled()).toBe(1)
    end)

    it("o ícone afunda ao pressionar", function()
        local but, frm = load()
        but:ApplyStyle(frm)
        expect(frm.icon.coord[1]).toBe(.05)
        but:NXOnMouseDown(frm, "LeftButton")
        expect(frm.icon.coord[1]).toBe(0)
        but:NXOnMouseUp(frm, "LeftButton")
        expect(frm.icon.coord[1]).toBe(.05)
    end)

    it("usa a borda maior dos clientes Classic", function()
        local but, frm = load({ retail = false })
        but:ApplyStyle(frm)
        expect(frm.border.w).toBe(53)
        expect(frm.icon.w).toBe(17)
        local rbut, rfrm = load()
        rbut:ApplyStyle(rfrm)
        expect(rawget(rfrm.border, "w")).toBeNil()
    end)

    it("o brilho troca o ícone, não a NormalTexture", function()
        expect(loader.read("Carbonite/Modules/Map/MinimapButton.lua")).toContain("f.icon:SetTexture")
        expect(loader.read("Carbonite/Modules/Whatsnew/WhatsnewEngine.lua"):find("SetNormalTexture", 1, true)).toBeNil()
    end)

    it("o tooltip diz para arrastar, em inglês e pt-BR", function()
        expect(loader.read("Carbonite/Modules/Map/MinimapButtonEngine.lua")).toContain('L["Drag to move"]')
        expect(loader.read("Carbonite/Locales/enUS/Main.lua")).toContain('L["Drag to move"] = true')
        expect(loader.read("Carbonite/Locales/ptBR/Main.lua")).toContain('L["Drag to move"] = "Arraste para mover"')
        expect(loader.read("Carbonite/Locales/ptBR/Main.lua"):find("Shift drag to move", 1, true)).toBeNil()
    end)
end)

describe("botão de addon no padrão LibDBIcon (#42)", function()
    local function loadIcon(opts)
        local env = wow.lenientEnv()
        local hidden = false
        env.NXMiniMapBut = { Hide = function() hidden = true end }
        local reg = {}
        local icon = {
            IsRegistered = function(_, name) return reg[name] ~= nil end,
            Register = function(_, name, obj, db) reg[name] = { obj = obj, db = db } end,
        }
        env.LibStub = function(name, silent)
            if name == "LibDBIcon-1.0" then return opts.lib and icon or nil end
            return wow.namespace({})
        end
        local mm = { ButOwn = opts.own or false }
        env.Nx = wow.namespace({ db = { profile = { MiniMap = mm } }, Broker = opts.broker,
            Map = { Dock = { OtherCollector = function() return opts.other or false end } } })
        loader.run(env, "Carbonite/Modules/Map/MinimapButtonEngine.lua")
        return env.Nx.NXMiniMapBut, reg, mm, function() return hidden end
    end

    it("registra o broker no LibDBIcon e esconde o botão próprio", function()
        local broker = {}
        local but, reg, mm, hidden = loadIcon({ lib = true, broker = broker })
        expect(but:RegisterDBIcon()).toBe(true)
        expect(reg.Carbonite.obj).toBe(broker)
        expect(reg.Carbonite.db).toBe(mm.DBIcon)
        expect(hidden()).toBe(true)
    end)

    it("sem LibDBIcon, fica o botão próprio", function()
        local but, _, _, hidden = loadIcon({ lib = false, broker = {} })
        expect(but:RegisterDBIcon()).toBe(false)
        expect(hidden()).toBe(false)
    end)

    it("com o botão na doca do mapa (ButOwn), não registra", function()
        local but, reg = loadIcon({ lib = true, broker = {}, own = true })
        expect(but:RegisterDBIcon()).toBe(false)
        expect(reg.Carbonite).toBeNil()
    end)

    it("com ButOwn mas outro coletor (MinimapButtonButton), registra", function()
        local but, reg = loadIcon({ lib = true, broker = {}, own = true, other = true })
        expect(but:RegisterDBIcon()).toBe(true)
        expect(reg.Carbonite ~= nil).toBe(true)
    end)
end)
