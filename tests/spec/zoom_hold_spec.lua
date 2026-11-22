-- A zoom chosen by hand during a route is not undone by auto scale.

local engine = loader.read("Carbonite/Modules/Map/MapEngine.lua"):gsub("\r\n", "\n")

local function between(first, last)
    local s = assert(engine:find(first, 1, true), "missing: " .. first)
    local e = assert(engine:find(last, s + #first, true), "missing: " .. last)
    return engine:sub(s, e - 1)
end

local function compile(code, env)
    local f = assert(loadstring(code))
    setfenv(f, env)
    return f()
end

local function baseEnv()
    return setmetatable({
        Nx = { Map = {} },
        abs = math.abs, min = math.min, max = math.max,
        UnitIsDeadOrGhost = function() return false end,
        UnitOnTaxi = function() return false end,
        GetTime = function() return 0 end,
        GetCursorPosition = function() return 200, 150 end,
    }, { __index = _G })
end

local function newMap()
    local env = baseEnv()
    local NxMap = env.Nx.Map

    -- The real zoom entries, hold helpers and follow / auto scale block.
    compile(between("function Nx.Map:MouseWheel(value)", "---\n-- Calculate new scale from scroll input"), env)
    compile(between("function Nx.Map:SetScaleOverTime(steps)",
        "-------------------------------------------------------------------------------\n-- MAIN UPDATE LOOP"), env)
    compile("local Map = Nx.Map\nfunction Map:Follow(plX, plY, plZX, plZY, rid, mapId)\n"
        .. between("            if self.CurOpts.NXPlyrFollow then\n                -- World-route",
            "                if rid ~= mapId then\n                    doSetCurZone = true")
        .. "\nend\nend", env)

    NxMap.IsInstanceMap = function() return false end
    NxMap.IsBattleGroundMap = function() return false end
    NxMap.IsUnmappedInstance = function() return false end
    NxMap.UsesModernInstanceCanvas = function() return false end

    local m = setmetatable({}, { __index = NxMap })
    m.Scale, m.MapPosX, m.MapPosY = 1, 0, 0
    m.MapW, m.MapH, m.PadX, m.TitleH = 400, 300, 0, 0
    m.PlyrX, m.PlyrY = 10, 10
    m.CurOpts = { NXPlyrFollow = true }
    m.LOpts = { NXAutoScaleOn = true, NXAutoScaleMin = .01, NXAutoScaleMax = 4 }
    m.Targets = { {} }
    m.Tracking = { { TargetMX = 110, TargetMY = 10,
        TargetX1 = 110, TargetX2 = 110, TargetY1 = 10, TargetY2 = 10 } }
    m.Win = { IsSizeMax = function() return m.big end }
    m.Frm = {
        GetEffectiveScale = function() return 1 end,
        GetLeft = function() return 0 end, GetRight = function() return 400 end,
        GetTop = function() return 300 end, GetBottom = function() return 0 end,
    }
    m.ScrollScale = function(self, value) return self.Scale * (value > 0 and 1.3 or .77) end
    m.Move = function(self, x, y, scale)
        self.MapPosX, self.MapPosY = x, y
        if scale then self.Scale = scale end
    end
    m.env = env
    m.walk = function() m:Follow(m.PlyrX, m.PlyrY, 50, 50, 1, 1) end
    return m
end

describe("zoom manual com rota", function()
    it("sem zoom manual, o automático enquadra o personagem e o destino", function()
        local m = newMap()
        m.walk()
        expect(m.Scale).toBe(2)
        expect(m.MapPosX).toBe(60)
    end)

    it("zoom da roda fica e o mapa segue o personagem", function()
        local m = newMap()
        m:MouseWheel(1)
        m.walk()
        expect(m.Scale).toBe(1.3)
        expect(m.MapPosX).toBe(10)
        m.PlyrX = 25
        m.walk()
        expect(m.Scale).toBe(1.3)
        expect(m.MapPosX).toBe(25)
    end)

    it("zoom dos botões também fica", function()
        local m = newMap()
        m:SetScaleOverTime(-1)
        m.walk()
        expect(m.Scale).toBe(.77)
    end)

    it("sobrevive à troca do destino", function()
        local m = newMap()
        m:MouseWheel(1)
        m.Targets = { {} }
        m.Tracking[1].TargetMX = 500
        m.walk()
        expect(m.Scale).toBe(1.3)
    end)

    it("o automático volta quando o zoom é solto", function()
        local m = newMap()
        m:MouseWheel(1)
        m:ReleaseZoom()
        m.walk()
        expect(m.MapPosX).toBe(60)
        expect(m.Scale).toBe(2)
    end)

    it("sem rota, o zoom não suspende o automático", function()
        local m = newMap()
        m.Targets = {}
        m:MouseWheel(1)
        expect(m:IsZoomHeld()).toBe(false)
    end)

    it("mapa grande e pequeno são independentes", function()
        local m = newMap()
        m.big = true
        m:MouseWheel(1)
        expect(m:IsZoomHeld()).toBe(true)
        m.big = false
        expect(m:IsZoomHeld()).toBe(false)
    end)

    it("fila vazia por um instante não solta; 2 s sem rota solta", function()
        local m, now = newMap(), 10
        m.env.GetTime = function() return now end
        m:MouseWheel(1)
        m.Targets = {}
        m:SyncZoomHold()
        now = 11
        m:SyncZoomHold()
        expect(m:IsZoomHeld()).toBe(true)
        m.Targets = { {} }
        m:SyncZoomHold()
        now = 20
        m.Targets = {}
        m:SyncZoomHold()
        expect(m:IsZoomHeld()).toBe(true)
        now = 22
        m:SyncZoomHold()
        expect(m:IsZoomHeld()).toBe(false)
    end)

    it("voo sem destino na fila também segura o zoom", function()
        local m = newMap()
        m.Targets = {}
        m.env.UnitOnTaxi = function() return true end
        m.env.Nx.Map.TaxiX = 500
        m:MouseWheel(1)
        expect(m:IsZoomHeld()).toBe(true)
    end)

    it("caminho até o cadáver também segura o zoom", function()
        local m = newMap()
        m.Targets = {}
        m.env.UnitIsDeadOrGhost = function() return true end
        m:MouseWheel(1)
        expect(m:IsZoomHeld()).toBe(true)
    end)

    it("confere a rota em todo quadro e solta no botão de zoom automático", function()
        expect(between("    self.Guide:OnMapUpdate()    -- For closest target",
            "    if #self.Targets > 0 then")).toContain("self:SyncZoomHold()")
        expect(between("    -- Auto-scale toggle button", "    m.ButAutoScaleOn =")).toContain("self:ReleaseZoom()")
    end)

    it("o clique no botão retoma o automático em vez de desligar", function()
        local m = newMap()
        local click = compile(between("    local function func(self, but)\n        -- While a manual zoom",
            "    m.ButAutoScaleOn =") .. "return func", baseEnv())
        local pressed
        local but = {
            SetPressed = function(_, on) pressed = on end,
            GetPressed = function() return pressed end,
        }
        m:MouseWheel(1)
        pressed = false -- the button toggles before it calls back
        click(m, but)
        expect(m.LOpts.NXAutoScaleOn).toBe(true)
        expect(m:IsZoomHeld()).toBe(false)
        pressed = false
        click(m, but)
        expect(m.LOpts.NXAutoScaleOn).toBe(false)
    end)

    it("restaurar a escala salva conta como zoom manual", function()
        expect(between("function Nx.Map:Menu_OnScaleRestore()", "    else")).toContain(":HoldZoom()")
    end)

    it("o ZoomController, que substitui o SetScaleOverTime, também suspende", function()
        local held = false
        local env = baseEnv()
        env._G = env
        env.Carbonite = { Modules = { Map = {} },
            Core = { EventBus = { Subscribe = function() end } } }
        env.Nx.Map.Maps = { { Scale = 1,
            ScrollScale = function() return 2 end,
            HoldZoom = function() held = true end } }
        loader.run(env, "Carbonite/Modules/Map/ZoomController.lua")
        env.Carbonite.Modules.Map.ZoomController:ScrollSteps(1)
        expect(held).toBe(true)
    end)
end)
