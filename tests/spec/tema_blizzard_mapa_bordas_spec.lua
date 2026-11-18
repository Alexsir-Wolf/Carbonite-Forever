-- Tema Blizzard no mapa (#42): o metal das laterais e da base da moldura fica
-- por cima do desenho do mapa. A moldura usava o nível da janela e todas as
-- camadas do mapa (tiles, arte, ícones) ficavam acima dela, cobrindo o metal.

-- Frame falso: guarda o que recebeu e aceita qualquer método.
local function fake(fontSize, width)
    local r = { points = {}, level = 5, width = width }
    return setmetatable(r, { __index = function(_, k)
        return function(self, ...)
            local a = { ... }
            if k == "SetPoint" then table.insert(self.points, a)
            elseif k == "ClearAllPoints" then self.points = {}
            elseif k == "SetShown" then self.shown = a[1]
            elseif k == "Show" then self.shown = true
            elseif k == "Hide" then self.shown = false
            elseif k == "SetScale" then self.scale = a[1]
            elseif k == "SetHeight" then self.height = a[1]
            elseif k == "GetWidth" then return self.width
            elseif k == "SetParent" then self.parent = a[1]
            elseif k == "GetParent" then return self.parent
            elseif k == "SetFrameLevel" then self.level = a[1]
            elseif k == "GetFrameLevel" then return self.level
            elseif k == "SetUsingParentLevel" then self.usingParent = a[1]
            elseif k == "GetFont" then return "font", fontSize or 12
            elseif k == "CreateTexture" or k == "CreateFontString" then return fake()
            end
        end
    end })
end

local function button(width)
    local b = { Frm = fake(nil, width or 22) }
    function b:SetSize(w, h) self.size = { w, h } end
    function b:SetPos(side, x, y) self.pos = { side, x, y } end
    return b
end

local function load()
    local env = wow.lenientEnv({
        CreateFrame = function() return fake() end,
        GameFontNormal = {},
        NineSliceUtil = { ApplyLayoutByName = function(frame, name) frame.layout = name end },
        NineSliceLayouts = { ButtonFrameTemplateNoPortrait = {} },
    })
    env.Carbonite.UI = {}
    env.Nx = wow.namespace({ db = { profile = { Skin = {}, Map = { ShowToolBar = true } } } })
    loader.run(env, "Carbonite/UI/Skin.lua")
    local Skin = env.Carbonite.UI.Skin
    Skin:Set("Blizzard", true)
    env.Carbonite.UI.Font = {
        SetRole = function(_, fs, role) fs.role = role end,
        GetRole = function() return "NxFontTitle" end,
    }
    env.Nx.Skin = { GetBackdrop = function() return Skin:GetBackdrop() end,
                    GetBorderCol = function() return Skin:GetBorderColor() end }
    loader.run(env, "Carbonite/Modules/UI/UIEngine.lua")

    -- Os métodos da moldura do mapa, tirados do MapEngine.lua.
    local src = loader.read("Carbonite/Modules/Map/MapEngine.lua")
    local first = src:find("function Nx.Map:SyncGameFrame", 1, true)
    local lastFn = src:find("function Nx.Map:UpdateAutoScaleBut", first, true)
    local last = src:find("\nend", lastFn, true)
    local chunk = assert(loadstring(src:sub(first, last + 4)))
    setfenv(chunk, env)
    chunk()

    env.Nx.ToolBar.Update = function() end
    return env.Nx, Skin
end

local function map(Nx, max)
    local win = {
        Frm = fake(), TitleFStr = { fake(12), fake(12) }, TitleLineH = 10, TitleLines = 2,
        BorderW = 7, BorderH = 7, Border = true, Sizeable = true, NoButs = false,
        ButClose = button(), ButMaxer = false, ButMiner = false,
        TitleBar = false, HeaderRule = false, HeaderCounter = false,
        GameFrame = false, GameFrameOn = false, GameFrameSpec = false, GameFrameFailed = false,
        TitleFrm = false, ToolBar = false, PlainBorderW = false, PlainBorderH = false,
        TitleXOff = 0, TitleYOff = 0, BackgndFadeTarget = 0,
        LayoutMode = max and "Max" or "",
        Adjust = function() end,
    }
    setmetatable(win, { __index = function(_, k) return rawget(Nx.Window, k) end })
    Nx.Window.Wins = { [win] = true }

    local m = setmetatable({ Win = win, Frm = fake() }, { __index = Nx.Map })
    local tools = { { But = button() }, { But = button() } }
    m.ToolBar = { Frm = fake(), Tools = tools }
    function m.ToolBar:SetLevels(level)
        self.Frm.level = level
        for _, t in ipairs(self.Tools) do t.But.Frm.level = level + 1 end
    end
    m.ButAutoScaleOn = button(12)
    return m
end

describe("metal da moldura acima do desenho do mapa (#42)", function()
    it("a atualização do mapa sobe a moldura depois de fixar os níveis", function()
        local src = loader.read("Carbonite/Modules/Map/MapEngine.lua")
        local first = src:find("function Nx.Map:Update (elapsed)", 1, true)
        local upd = src:sub(first, src:find("\nfunction ", first, true))
        local tip = upd:find("self.LocTipFrm:SetFrameLevel (self.Level + 2)", 1, true)
        local raise = upd:find("self:RaiseGameFrame (self.Level + 3)", 1, true)
        expect(tip ~= nil).toBe(true)
        expect(raise ~= nil and raise > tip).toBe(true)
    end)

    it("mapa grande: metal acima do desenho, título e botões acima do metal", function()
        local Nx = load()
        local m = map(Nx, true)
        m:SyncGameFrame()
        local win = m.Win
        m:RaiseGameFrame(300)
        expect(win.GameFrame.usingParent).toBe(false)
        expect(win.GameFrame.level).toBe(300)
        expect(win.TitleFrm.level).toBe(301)
        expect(win.ButClose.Frm.level).toBe(302)
        -- As ferramentas da faixa não somem sob o metal.
        expect(win.ToolBar.level).toBe(301)
        expect(m.ToolBar.Frm.level).toBe(302)
        expect(m.ToolBar.Tools[1].But.Frm.level).toBe(303)
    end)

    it("a moldura reaplicada (botões de volta ao nível da janela) é corrigida", function()
        local Nx = load()
        local m = map(Nx, true)
        m:SyncGameFrame()
        m:RaiseGameFrame(300)
        m.Win.ButClose.Frm.level = 7
        m:RaiseGameFrame(300)
        expect(m.Win.ButClose.Frm.level).toBe(302)
    end)

    it("a cada atualização as ferramentas voltam para cima do metal", function()
        local Nx = load()
        local m = map(Nx, true)
        m:SyncGameFrame()
        m:RaiseGameFrame(300)
        m.ToolBar:SetLevels(120)    -- a atualização as põe sob o metal
        m:RaiseGameFrame(300)
        expect(m.ToolBar.Frm.level).toBe(302)
    end)

    it("minimapa compacto: o metal também fica acima, sem faixa de ferramentas", function()
        local Nx = load()
        local m = map(Nx, false)
        m:SyncGameFrame()
        m:RaiseGameFrame(80)
        expect(m.Win.GameFrameVariant).toBe("compact")
        expect(m.Win.GameFrame.level).toBe(80)
        expect(m.Win.ButClose.Frm.level).toBe(82)
        expect(m.ToolBar.Frm.level).toBe(5)
    end)

    it("em outro tema, nada muda", function()
        local Nx, Skin = load()
        Skin:Set("Modern Dark", true)
        local m = map(Nx, true)
        m:SyncGameFrame()
        m:RaiseGameFrame(300)
        expect(m.Win.GameFrameOn).toBe(false)
        expect(m.Win.ButClose.Frm.level).toBe(5)
    end)
end)
