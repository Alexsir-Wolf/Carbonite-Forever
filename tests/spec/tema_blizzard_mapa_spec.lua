-- Tema Blizzard no mapa (#42, R8 e R9, T9): moldura completa no mapa grande,
-- compacta no minimapa integrado, ferramentas do mapa na faixa de ferramentas
-- e título do mapa (uma ou duas linhas) dentro da faixa.

-- Frame, textura ou font string falsa: guarda o que recebeu e aceita qualquer método.
local function fake(fontSize, width)
    local r = { points = {}, level = 5, width = width }
    return setmetatable(r, { __index = function(_, k)
        return function(self, ...)
            local a = { ... }
            if k == "SetPoint" then table.insert(self.points, a)
            elseif k == "ClearAllPoints" then self.points = {}
            elseif k == "SetAllPoints" then self.all = a[1]
            elseif k == "SetBackdrop" then self.backdrop = a[1]
            elseif k == "SetShown" then self.shown = a[1]
            elseif k == "Show" then self.shown = true
            elseif k == "Hide" then self.shown = false
            elseif k == "SetScale" then self.scale = a[1]
            elseif k == "SetJustifyH" then self.justify = a[1]
            elseif k == "SetHeight" then self.height = a[1]
            elseif k == "SetWidth" then self.width = a[1]
            elseif k == "GetWidth" then return self.width
            elseif k == "SetParent" then self.parent = a[1]
            elseif k == "GetParent" then return self.parent
            elseif k == "SetFrameLevel" then self.level = a[1]
            elseif k == "GetFrameLevel" then return self.level
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

    -- Os métodos do mapa desta tarefa, tirados do MapEngine.lua.
    local src = loader.read("Carbonite/Modules/Map/MapEngine.lua")
    local first = src:find("function Nx.Map:SyncGameFrame", 1, true)
    local lastFn = src:find("function Nx.Map:UpdateAutoScaleBut", first, true)
    local last = src:find("\nend", lastFn, true)
    local chunk = assert(loadstring(src:sub(first, last + 4)))
    setfenv(chunk, env)
    chunk()

    -- Relayout do mapa na barra antiga: só registra a chamada.
    env.Nx.ToolBar.Update = function(bar) bar.relaid = (bar.relaid or 0) + 1 end
    return env.Nx, Skin
end

-- Janela do mapa (NxMap1): título de duas linhas, só o fechar, sem escolha de moldura.
local function mapWindow(Nx, max)
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
    return win
end

local function map(Nx, max)
    local m = setmetatable({}, { __index = Nx.Map })
    m.Win = mapWindow(Nx, max)
    m.Frm = fake()
    local barFrm = fake()
    barFrm.parent = m.Frm
    m.ToolBar = { Frm = barFrm, Tools = { { But = button() }, { But = button() }, { But = button() } } }
    m.ButAutoScaleOn = button(12)
    return m
end

describe("moldura do mapa (T9)", function()
    it("o mapa não fica mais fora da moldura; a doca dos botões continua fora", function()
        local src = loader.read("Carbonite/Modules/Map/MapEngine.lua")
        local create = src:match("win:StyleTitleBar%(%).-InitLayoutData")
        expect(create:find("UseGameFrame(false)", 1, true)).toBeNil()
        expect(create:find("m:SyncGameFrame()", 1, true) ~= nil).toBe(true)
        local dock = src:match("function Nx%.Map%.Dock:Create%(%).-\nend")
        expect(dock:find("win:UseGameFrame (false)", 1, true) ~= nil).toBe(true)
    end)

    it("alternar o tamanho e cada atualização passam pela troca de variante", function()
        local src = loader.read("Carbonite/Modules/Map/MapEngine.lua")
        local onWin = src:match("function Nx%.Map:OnWin%(typ%).-\nend")
        expect(onWin:find("self:SyncGameFrame()", 1, true) ~= nil).toBe(true)
        local upd = src:match("function Nx%.Map:Update %(elapsed%).-self:UpdateWorld")
        expect(upd:find("self:SyncGameFrame()", 1, true) ~= nil).toBe(true)
    end)

    it("mapa grande: moldura completa", function()
        local Nx, Skin = load()
        local m = map(Nx, true)
        m:SyncGameFrame()
        local _, full = Skin:GetGameFrame()
        expect(m.Win.GameFrameOn).toBe(true)
        expect(m.Win.GameFrameVariant).toBe(false)
        expect(m.Win.GameFrame.scale).toBe(full.edgeScale)
        expect(m.Win.BorderW).toBe(full.side)
    end)

    it("minimapa: moldura compacta, sem faixa de ferramentas", function()
        local Nx, Skin = load()
        local m = map(Nx, false)
        m:SyncGameFrame()
        local _, compact = Skin:GetGameFrame("compact")
        expect(m.Win.GameFrameVariant).toBe("compact")
        expect(m.Win.TopH).toBe(compact.band + compact.gap)
        expect(m.Win.ToolBar).toBe(false)
        expect(m.ToolBarInStrip).toBe(false)
    end)

    it("troca de variante ao alternar o tamanho, e a faixa some no minimapa", function()
        local Nx, Skin = load()
        local m = map(Nx, true)
        m:SyncGameFrame()
        local _, full = Skin:GetGameFrame()
        expect(m.Win.TopH).toBe(full.band + full.gap + full.toolBarH)
        m.Win.LayoutMode = ""
        m:SyncGameFrame()
        local _, compact = Skin:GetGameFrame("compact")
        expect(m.Win.GameFrameVariant).toBe("compact")
        expect(m.Win.ToolBar.shown).toBe(false)
        expect(m.Win.TopH).toBe(compact.band + compact.gap)
        m.Win.LayoutMode = "Max"
        m:SyncGameFrame()
        expect(m.Win.GameFrameVariant).toBe(false)
        expect(m.Win.ToolBar.shown).toBe(true)
    end)

    it("sem mudança, não reaplica a moldura", function()
        local Nx = load()
        local m = map(Nx, true)
        m:SyncGameFrame()
        local applied = 0
        local apply = Nx.Window.ApplyGameFrame
        m.Win.ApplyGameFrame = function(self) applied = applied + 1; return apply(self) end
        m:SyncGameFrame()
        m:SyncGameFrame()
        expect(applied).toBe(0)
    end)
end)

describe("ferramentas do mapa na faixa (R9, antiga #204)", function()
    it("no mapa grande, os ícones vão para a faixa como alternâncias de um tamanho", function()
        local Nx = load()
        local m = map(Nx, true)
        m:SyncGameFrame()
        local tb = m.Win.ToolBar
        expect(m.ToolBarInStrip).toBe(true)
        expect(m.ToolBar.Frm.parent).toBe(tb)
        expect(m.ToolBar.Frm.scale).toBe(1)
        local size = Nx.Window.ToolIconSize
        expect(size >= 20 and size <= 24).toBe(true)
        for _, tool in ipairs(m.ToolBar.Tools) do
            expect(tool.But.size[1]).toBe(size)
            expect(tool.But.Frm.points[1][1]).toBe("RIGHT")
            expect(tool.But.Frm.points[1][2]).toBe(tb)
        end
    end)

    it("da esquerda para a direita na ordem da barra, com a escala automática no fim", function()
        local Nx = load()
        local m = map(Nx, true)
        m:SyncGameFrame()
        local function x(b) return b.Frm.points[1][4] end
        local t = m.ToolBar.Tools
        expect(x(m.ButAutoScaleOn)).toBe(0)
        expect(x(t[3].But) < x(m.ButAutoScaleOn)).toBe(true)
        expect(x(t[1].But) < x(t[2].But)).toBe(true)
        expect(x(t[2].But) < x(t[3].But)).toBe(true)
        expect(m.ButAutoScaleOn.Frm.shown).toBe(true)
    end)

    it("ao voltar ao minimapa, os ícones voltam ao mapa e a escala automática sai da faixa", function()
        local Nx = load()
        local m = map(Nx, true)
        m:SyncGameFrame()
        m.Win.LayoutMode = ""
        m:SyncGameFrame()
        expect(m.ToolBar.Frm.parent).toBe(m.Frm)
        expect(m.ToolBar.relaid).toBe(1)
        expect(#m.ToolBar.Tools[1].But.Frm.points).toBe(0)
        expect(m.ButAutoScaleOn.Frm.shown).toBe(false)
    end)

    it("barra desligada nas opções: sem faixa no mapa grande", function()
        local Nx = load()
        Nx.db.profile.Map.ShowToolBar = false
        local m = map(Nx, true)
        m:SyncGameFrame()
        expect(m.ToolBarInStrip).toBe(false)
        expect(m.Win.ToolBar).toBe(false)
    end)

    it("em outro tema, tudo como antes: ícones no mapa e escala automática na linha do título", function()
        local Nx, Skin = load()
        Skin:Set("Modern Dark", true)
        local m = map(Nx, true)
        m:SyncGameFrame()
        expect(m.Win.GameFrameOn).toBe(false)
        expect(m.ToolBarInStrip).toBe(false)
        expect(m.ButAutoScaleOn.size[1]).toBe(12)
        expect(m.ButAutoScaleOn.pos[1]).toBe("TOPRIGHT")
        expect(m.ButAutoScaleOn.Frm.shown).toBe(true)
    end)
end)

describe("título do mapa na faixa", function()
    it("faixa completa: as duas linhas cabem e dividem a altura", function()
        local Nx, Skin = load()
        local m = map(Nx, true)
        m:SyncGameFrame()
        local _, full = Skin:GetGameFrame()
        local h = math.floor((full.band - 4) / 2)
        local l1, l2 = m.Win.TitleFStr[1], m.Win.TitleFStr[2]
        expect(l1.justify).toBe("CENTER")
        expect(l1.height).toBe(h)
        expect(l2.shown).toBe(true)
        expect(l2.points[1][5]).toBe(-2 - h)
        expect(-l2.points[1][5] + h <= full.band).toBe(true)
    end)

    it("faixa compacta: só a primeira linha (zona e coordenadas)", function()
        local Nx = load()
        local m = map(Nx, false)
        m:SyncGameFrame()
        expect(m.Win.TitleFStr[1].shown).toBe(true)
        expect(m.Win.TitleFStr[2].shown).toBe(false)
    end)
end)
