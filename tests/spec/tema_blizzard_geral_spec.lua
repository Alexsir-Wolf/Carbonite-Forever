-- Tema Blizzard geral (#42, R8 e R9): moldura do jogo em toda janela com borda,
-- variante compacta, opt-out por janela, ordem dos botões da faixa de título,
-- faixa de ferramentas ordenada e abas no estilo das abas inferiores do jogo.

-- Frame, textura ou font string falsa: guarda o que recebeu e aceita qualquer método.
local function fake(fontSize, width)
    local r = { points = {}, level = 5, width = width }
    return setmetatable(r, { __index = function(_, k)
        return function(self, ...)
            local a = { ... }
            if k == "SetPoint" then table.insert(self.points, a)
            elseif k == "ClearAllPoints" then self.points = {}
            elseif k == "SetBackdrop" then self.backdrop = a[1]
            elseif k == "SetShown" then self.shown = a[1]
            elseif k == "Show" then self.shown = true
            elseif k == "Hide" then self.shown = false
            elseif k == "SetScale" then self.scale = a[1]
            elseif k == "SetJustifyH" then self.justify = a[1]
            elseif k == "SetHeight" then self.height = a[1]
            elseif k == "SetWidth" then self.width = a[1]
            elseif k == "GetWidth" then return self.width
            elseif k == "SetAtlas" then self.atlas = a[1]
            elseif k == "SetParent" then self.parent = a[1]
            elseif k == "SetFrameLevel" then self.level = a[1]
            elseif k == "GetFrameLevel" then return self.level
            elseif k == "GetFont" then return "font", fontSize or 12
            elseif k == "CreateTexture" or k == "CreateFontString" then return fake()
            end
        end
    end })
end

local function button(width)
    local b = { Frm = fake(nil, width or 64) }
    function b:SetSize(w, h) self.size = { w, h } end
    function b:SetPos(side, x, y) self.pos = { side, x, y } end
    return b
end

local LAYOUT = "ButtonFrameTemplateNoPortrait"

local function load(withLayout)
    local env = wow.lenientEnv({
        CreateFrame = function() return fake() end,
        GameFontNormal = {},
        NineSliceUtil = { ApplyLayoutByName = function(frame, name) frame.layout = name end },
        NineSliceLayouts = withLayout == false and {} or { [LAYOUT] = {} },
    })
    env.Carbonite.UI = {}
    env.Nx = wow.namespace({ db = { profile = { Skin = {} } } })
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
    return env.Nx, Skin, env
end

-- Janela ainda sem escolha de moldura (WantGameFrame nil), com fechar e maximizar.
local function window(Nx, fields)
    local win = {
        Frm = fake(), TitleFStr = { fake(12) }, TitleLineH = 10, TitleLines = 1,
        BorderW = 7, BorderH = 7, Border = true, Sizeable = true, NoButs = false,
        ButClose = button(), ButMaxer = button(), ButMiner = false,
        TitleBar = false, HeaderRule = false, HeaderCounter = false,
        GameFrame = false, GameFrameOn = false, GameFrameSpec = false, GameFrameFailed = false,
        TitleFrm = false, ToolBar = false, PlainBorderW = false, PlainBorderH = false,
        TitleXOff = 0, TitleYOff = 0, BackgndFadeTarget = 0,
        Adjust = function() end,
    }
    for k, v in pairs(fields or {}) do win[k] = v end
    -- Só o que o motor definiu: campos ausentes ficam nil, como no jogo.
    setmetatable(win, { __index = function(_, k) return rawget(Nx.Window, k) end })
    Nx.Window.Wins = { [win] = true }
    return win
end

describe("moldura padrão em toda janela com borda", function()
    it("Create marca a moldura padrão para o primeiro OnUpdate", function()
        local ui = loader.read("Carbonite/Modules/UI/UIEngine.lua")
        local create = ui:match("function Nx%.Window:Create %(.-\nend")
        expect(create:find("win.GameFramePending = true", 1, true) ~= nil).toBe(true)
        local upd = ui:match("function Nx%.Window:OnUpdate %(.-\nend")
        expect(upd:find("win:UseDefaultGameFrame()", 1, true) ~= nil).toBe(true)
    end)

    it("menu suspenso e seta do HUD ficam fora da moldura", function()
        local ui = loader.read("Carbonite/Modules/UI/UIEngine.lua")
        local dd = ui:match("function Nx%.DropDown:Init%(%).-\nend")
        expect(dd:find("win:UseGameFrame (false)", 1, true) ~= nil).toBe(true)
        local hud = loader.read("Carbonite/Modules/HUD/HUDEngine.lua")
        expect(hud:find("win:UseGameFrame(false)", 1, true) ~= nil).toBe(true)
    end)

    it("janela comum ganha a moldura completa sem pedir", function()
        local Nx, Skin = load()
        local win = window(Nx)
        win:UseDefaultGameFrame()
        local _, spec = Skin:GetGameFrame()
        expect(win.GameFrameOn).toBe(true)
        expect(win.GameFrameAuto).toBe(true)
        expect(win.GameFrameSpec.band).toBe(spec.band)
        expect(win.GameFrame.scale).toBe(spec.edgeScale)
    end)

    it("janela pequena (sem título, tamanho fixo ou sem botões) ganha a compacta", function()
        local Nx, Skin = load()
        for _, fields in ipairs({ { TitleLines = 0 }, { Sizeable = false }, { NoButs = true } }) do
            local win = window(Nx, fields)
            win:UseDefaultGameFrame()
            expect(win.GameFrameVariant).toBe("compact")
            expect(win.GameFrameSpec.band).toBe(select(2, Skin:GetGameFrame("compact")).band)
        end
    end)

    it("opt-out: UseGameFrame(false) antes do OnUpdate deixa a janela sem moldura", function()
        local Nx = load()
        local win = window(Nx, { GameFramePending = true })
        win:UseGameFrame(false)
        expect(win.GameFramePending).toBeNil()
        win:UseDefaultGameFrame()
        expect(win.GameFrameOn).toBe(false)
        expect(win.WantGameFrame).toBe(false)
    end)

    it("opt-out depois de ligada tira a moldura e devolve a borda", function()
        local Nx, Skin = load()
        local win = window(Nx)
        win:UseGameFrame()
        win:UseGameFrame(false)
        expect(win.GameFrameOn).toBe(false)
        expect(win.GameFrame.shown).toBe(false)
        expect(win.BorderW).toBe(7)
        expect(win.Frm.backdrop).toBe(Skin:GetBackdrop())
    end)

    it("em outro tema a janela padrão fica como está, e ganha a moldura ao voltar ao Blizzard", function()
        local Nx, Skin = load()
        Skin:Set("Modern Dark", true)
        local win = window(Nx)
        win:UseDefaultGameFrame()
        expect(win.GameFrameOn).toBe(false)
        expect(win.TitleBar).toBe(false)
        expect(rawget(win.TitleFStr[1], "justify")).toBeNil()
        Skin:Set("Blizzard")
        expect(win.GameFrameOn).toBe(true)
    end)
end)

describe("variante compacta", function()
    it("metal em escala 1 e faixa baixa; o resto vem da completa", function()
        local _, Skin = load()
        local _, full = Skin:GetGameFrame()
        local _, compact = Skin:GetGameFrame("compact")
        expect(compact.edgeScale).toBe(1)
        expect(compact.band < full.band).toBe(true)
        expect(compact.side < full.side).toBe(true)
        expect(compact.backdrop).toBe(full.backdrop)
        expect(compact.variant).toBe("compact")
    end)

    it("UseGameFrame({ compact = true }) aplica e troca de variante na hora", function()
        local Nx, Skin = load()
        local win = window(Nx)
        win:UseGameFrame({ compact = true })
        local _, compact = Skin:GetGameFrame("compact")
        expect(win.GameFrame.scale).toBe(1)
        expect(win.TopH).toBe(compact.band + compact.gap)
        expect(win.BorderW).toBe(7)
        expect(win.ButClose.size[1]).toBe(compact.butSize)
        win:UseGameFrame()
        local _, full = Skin:GetGameFrame()
        expect(win.GameFrame.scale).toBe(full.edgeScale)
        expect(win.TopH).toBe(full.band + full.gap)
        expect(win.BorderW).toBe(full.side)
    end)

    it("SetBorderSize e SetTitleLineH com a moldura ligada mantêm o metal e a faixa", function()
        local Nx, Skin = load()
        local win = window(Nx)
        win:UseGameFrame()
        local _, spec = Skin:GetGameFrame()
        win:SetBorderSize(2, 2)
        expect(win.BorderW).toBe(spec.side)
        win:SetTitleLineH(18)
        expect(win.TopH).toBe(spec.band + spec.gap)
        win:UseGameFrame(false)
        expect(win.BorderW).toBe(2)
    end)
end)

describe("botões da faixa de título (R9)", function()
    it("da direita para a esquerda: fechar, maximizar, minimizar e travar, cada um no seu lugar", function()
        local Nx, Skin = load()
        local win = window(Nx, { ButMiner = button(), ButLock = button() })
        win:UseGameFrame()
        local _, spec = Skin:GetGameFrame()
        local step = spec.butSize + 2
        local x0 = win.ButClose.pos[2]
        expect(win.ButMaxer.pos[2]).toBe(x0 - step)
        expect(win.ButMiner.pos[2]).toBe(x0 - 2 * step)
        expect(win.ButLock.pos[2]).toBe(x0 - 3 * step)
        expect(win.ButLock.size[1]).toBe(spec.butSize)
    end)

    it("fora da moldura, maximizar e minimizar continuam dividindo o lugar", function()
        local Nx, Skin = load()
        Skin:Set("Modern Dark", true)
        local win = window(Nx, { ButMiner = button() })
        win:StyleTitleBar()
        expect(win.ButMiner.pos[2]).toBe(win.ButMaxer.pos[2])
    end)
end)

describe("faixa de ferramentas ordenada (R9)", function()
    it("navegação, ações e a destrutiva afastada à esquerda; alternâncias da direita", function()
        local Nx = load()
        local win = window(Nx)
        win:UseGameFrame()
        local back, rec, up, del = button(60), button(70), button(64), button(96)
        local t1, t2 = button(30), button(30)
        local left, right = win:ArrangeToolBar({
            { del, "danger" }, { up }, { t1, "toggle" }, { back, "nav" }, { rec, "action" }, { t2, "toggle" },
        })
        local W = Nx.Window
        local function x(b) return b.Frm.points[1][4] end
        expect(back.Frm.points[1][1]).toBe("LEFT")
        expect(x(back)).toBe(2)
        expect(x(up)).toBe(2 + 60 + W.ToolGap)
        expect(x(rec)).toBe(x(up) + 64 + W.ToolGap)
        expect(x(del)).toBe(x(rec) + 70 + W.ToolDangerGap)
        expect(left).toBe(x(del) + 96)
        expect(t1.Frm.points[1][1]).toBe("RIGHT")
        expect(x(t1)).toBe(0)
        expect(x(t2)).toBe(-(W.ToolIconSize + W.ToolGap))
        expect(t2.size[1]).toBe(W.ToolIconSize)
        expect(right).toBe(2 * W.ToolIconSize + W.ToolGap)
    end)

    it("a faixa tem a largura do conteúdo e a altura da moldura", function()
        local Nx, Skin = load()
        local win = window(Nx)
        win:UseGameFrame()
        local bar = win:GetToolBar()
        local _, spec = Skin:GetGameFrame()
        expect(bar.points[2][1]).toBe("TOPRIGHT")
        expect(bar.points[2][4]).toBe(-win.BorderW)
        expect(bar.height).toBe(spec.toolBarH)
    end)
end)

describe("abas do jogo (R9)", function()
    local function tabs(atlases, gameStyle)
        local env = wow.lenientEnv({
            C_Texture = { GetAtlasInfo = function(name) return atlases and { name = name } or nil end },
        })
        env.Carbonite.UI = {
            Skin = { GameStyle = function() return gameStyle ~= false end, TextCode = function() return "" end },
            Font = { SetRole = function(_, fs, role) fs.role = role end },
        }
        env.Nx = wow.namespace({ TabBar = {}, Button = {} })
        loader.run(env, "Carbonite/Modules/UI/UIEngine.lua")
        local created = {}
        env.Nx.Button.Create = function(_, _, typ, text, _, x, y, _, w, h)
            local frm = fake(nil, w)
            frm.NxTabParts = false
            local b = { typ = typ, x = x, y = y, w = w, h = h, Frm = frm, FStr = { GetStringWidth = function() return 10 end } }
            function b.SetId() end
            function b:SetPressed(on) self.pressed = on end
            function b:GetPressed() return self.pressed end
            function b.SetText() end
            function b:SetPos(_, nx, ny) self.x, self.y = nx, ny end
            function b:SetSize(nw, nh) self.w, self.h = nw, nh end
            created[#created + 1] = b
            return b
        end
        local bar = setmetatable({ Tabs = {}, Frm = { texture = fake() }, TopFrm = { texture = fake() } },
                                 { __index = env.Nx.TabBar })
        return bar, created, env.Nx.TabBar
    end

    it("no tema Blizzard com os atlas, a barra usa as abas do jogo", function()
        local bar, b, TabBar = tabs(true)
        expect(bar:UseGameTabs()).toBe(true)
        expect(bar.Frm.texture.shown).toBe(false)
        bar:AddTab("Atual", 1, nil, true)
        bar:AddTab("Histórico", 2)
        expect(b[1].typ).toBe("GameTab")
        expect(b[1].h).toBe(TabBar.GameTabH)
        expect(bar:GetHeight()).toBe(TabBar.GameTabH)
        expect(b[1].Frm.NxTabParts[2].atlas).toBe(TabBar.GameTabAtlases.On[2])
        expect(b[2].Frm.NxTabParts[2].atlas).toBe(TabBar.GameTabAtlases.Off[2])
        bar:Select(2)
        expect(b[1].Frm.NxTabParts[1].atlas).toBe(TabBar.GameTabAtlases.Off[1])
        expect(b[2].Frm.NxTabParts[3].atlas).toBe(TabBar.GameTabAtlases.On[3])
    end)

    it("sem os atlas ou em outro tema, fica a aba do tema", function()
        for _, case in ipairs({ { false, true }, { true, false } }) do
            local bar, b = tabs(case[1], case[2])
            expect(bar:UseGameTabs()).toBe(false)
            bar:AddTab("Atual", 1)
            expect(b[1].typ).toBe("Tab")
            expect(bar:GetHeight()).toBe(22)
        end
    end)
end)
