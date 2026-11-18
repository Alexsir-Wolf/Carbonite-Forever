-- Tema Blizzard: moldura NineSlice do jogo, título centralizado na faixa, fechar
-- RedButton-Exit uniforme e faixa de ferramentas abaixo do título (#42)

-- Frame, textura ou font string falsa: guarda o que recebeu e aceita qualquer método.
local function fake(fontSize)
    local r = { points = {}, level = 5 }
    return setmetatable(r, { __index = function(_, k)
        return function(self, ...)
            local a = { ... }
            if k == "SetPoint" then table.insert(self.points, a)
            elseif k == "ClearAllPoints" then self.points = {}
            elseif k == "SetBackdrop" then self.backdrop = a[1]
            elseif k == "SetShown" then self.shown = a[1]
            elseif k == "Show" then self.shown = true
            elseif k == "Hide" then self.shown = false
            elseif k == "SetJustifyH" then self.justify = a[1]
            elseif k == "SetFontObject" then self.font = a[1]
            elseif k == "SetTextColor" then self.textColor = a
            elseif k == "SetColorTexture" then self.color = a
            elseif k == "SetHeight" then self.height = a[1]
            elseif k == "SetParent" then self.parent = a[1]
            elseif k == "SetFrameLevel" then self.level = a[1]
            elseif k == "GetFrameLevel" then return self.level
            elseif k == "SetAlpha" then self.alpha = a[1]
            elseif k == "GetFont" then return "font", fontSize or 12
            elseif k == "CreateTexture" or k == "CreateFontString" then return fake()
            end
        end
    end })
end

local function button()
    local b = { Frm = fake() }
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
    return env.Nx, Skin
end

-- Janela com fechar e maximizar, como Notas e Armazém. Campos que o
-- namespace falso criaria sozinhos ficam em false.
local function window(Nx)
    local win = setmetatable({
        Frm = fake(), TitleFStr = { fake(12) }, TitleLineH = 18, TitleLines = 1,
        BorderW = 7, BorderH = 7, Border = true, Sizeable = true,
        ButClose = button(), ButMaxer = button(), ButMiner = false,
        TitleBar = false, HeaderRule = false, HeaderCounter = false,
        GameFrame = false, GameFrameOn = false, GameFrameSpec = false, GameFrameFailed = false,
        WantGameFrame = false, TitleFrm = false, ToolBar = false,
        TitleXOff = 220, TitleYOff = 0, BackgndFadeTarget = 0,
        Adjust = function() end,
    }, { __index = Nx.Window })
    Nx.Window.Wins = { [win] = true }
    return win
end

describe("moldura do jogo no tema Blizzard", function()
    it("o tema Blizzard pede a ButtonFrameTemplateNoPortrait e os outros temas não têm moldura", function()
        local _, Skin = load()
        local name, spec = Skin:GetGameFrame()
        expect(name).toBe(LAYOUT)
        expect(spec.backdrop.edgeFile).toBeNil()
        Skin:Set("Modern Dark", true)
        expect(Skin:GetGameFrame()).toBeNil()
    end)

    it("sem o layout no cliente, a janela fica com a backdrop do tema", function()
        local Nx = load(false)
        local win = window(Nx)
        win:UseGameFrame()
        expect(win.GameFrameOn).toBe(false)
        expect(win.Frm.backdrop.edgeFile:find("UI-DialogBox-Border", 1, true) ~= nil).toBe(true)
    end)

    it("aplica o NineSlice num frame filho, sem borda na backdrop, e o conteúdo começa abaixo da faixa", function()
        local Nx, Skin = load()
        local win = window(Nx)
        win:UseGameFrame()
        local _, spec = Skin:GetGameFrame()
        expect(win.GameFrameOn).toBe(true)
        expect(win.GameFrame.layout).toBe(LAYOUT)
        expect(win.Frm.backdrop.edgeFile).toBeNil()
        expect(win.TopH).toBe(spec.band + spec.gap)
        expect(select(2, win:GetClientOffset())).toBe(win.TopH)
    end)

    it("título centralizado em GameFontNormal, branco, entre os botões", function()
        local Nx, Skin = load()
        local win = window(Nx)
        win:UseGameFrame()
        local fs = win.TitleFStr[1]
        expect(fs.justify).toBe("CENTER")
        expect(fs.font).toBe("GameFontNormal")
        expect(fs.parent).toBe(win.TitleFrm)
        local r, g, b = Skin:GetToken("frameTitle")
        expect(fs.textColor[1] == r and fs.textColor[2] == g and fs.textColor[3] == b).toBe(true)
        local left, right = fs.points[1], fs.points[2]
        expect(left[4]).toBe(-right[4])
    end)

    it("fechar e maximizar com o tamanho do botão do jogo, no canto da faixa", function()
        local Nx, Skin = load()
        local win = window(Nx)
        win:UseGameFrame()
        local _, spec = Skin:GetGameFrame()
        expect(win.ButClose.size[1]).toBe(spec.butSize)
        expect(spec.butSize >= 24 and spec.butSize <= 28).toBe(true)
        expect(win.ButClose.pos[1]).toBe("TOPRIGHT")
        expect(win.ButClose.pos[3]).toBe(0)
        expect(win.ButMaxer.size[1]).toBe(spec.butSize)
        expect(win.ButMaxer.pos[2]).toBe(win.ButClose.pos[2] - spec.butSize)
        expect(win.ButClose.Frm.level > win.Frm.level).toBe(true)
    end)

    it("a faixa de ferramentas fica abaixo do título e empurra o conteúdo", function()
        local Nx, Skin = load()
        local win = window(Nx)
        win:UseGameFrame()
        local bar = win:GetToolBar()
        local _, spec = Skin:GetGameFrame()
        expect(bar.points[1][5]).toBe(-(spec.band + 1))
        expect(win.TopH).toBe(spec.band + spec.gap + spec.toolBarH)
    end)

    it("em outro tema a faixa de ferramentas é a linha do título, como antes", function()
        local Nx, Skin = load()
        Skin:Set("Modern Dark", true)
        local win = window(Nx)
        win:UseGameFrame()
        local bar = win:GetToolBar()
        expect(win.GameFrameOn).toBe(false)
        expect(bar.points[1][4]).toBe(win.BorderW)
        expect(bar.points[1][5]).toBe(-win.BorderH)
        expect(win.TopH).toBe(win.TitleH + win.BorderH)
        expect(win.TitleH).toBe(20)
    end)

    it("trocar para outro tema tira a moldura e volta o cabeçalho antigo", function()
        local Nx, Skin = load()
        local win = window(Nx)
        win:UseGameFrame()
        Skin:Set("Modern Dark")
        expect(win.GameFrameOn).toBe(false)
        expect(win.GameFrame.shown).toBe(false)
        expect(win.TitleFStr[1].justify).toBe("LEFT")
        expect(win.TitleFStr[1].parent).toBe(win.Frm)
        expect(win.Frm.backdrop).toBe(Skin:GetBackdrop())
        expect(win.TopH).toBe(win.TitleH + win.BorderH)
        Skin:Set("Blizzard")
        expect(win.GameFrameOn).toBe(true)
        expect(win.GameFrame.shown).toBe(true)
    end)
end)

describe("quem usa a moldura", function()
    it("janelas com cabeçalho moderno pedem a moldura; o mapa não", function()
        local ui = loader.read("Carbonite/Modules/UI/UIEngine.lua")
        local header = ui:match("function Nx%.Window:ApplyModernHeader%(%).-\nend")
        expect(header:find("self:UseGameFrame()", 1, true) ~= nil).toBe(true)
        local map = loader.read("Carbonite/Modules/Map/MapEngine.lua")
        expect(map:find("ApplyModernHeader", 1, true)).toBeNil()
        expect(map:find("UseGameFrame", 1, true)).toBeNil()
    end)

    it("Guia, Notas e Novidades põem os botões de ação na faixa de ferramentas", function()
        local guide = loader.read("Carbonite/Data/Shared/NxMapGuide.lua")
        expect(guide:find('CreateFrame ("Button", nil, win:GetToolBar(), "UIPanelButtonTemplate")', 1, true) ~= nil).toBe(true)
        local notes = loader.read("Carbonite.Notes/WindowEngine.lua")
        expect(notes:find('Nx.Button:Create(bar, "NotesTxtB", L["Record"]', 1, true) ~= nil).toBe(true)
        expect(notes:find('Nx.Button:Create(bar, "NotesTxt", L["Up"]', 1, true) ~= nil).toBe(true)
        local news = loader.read("Carbonite/Modules/Whatsnew/WhatsnewEngine.lua")
        expect(news:find('Nx.Button:Create(bar, "Txt64", label', 1, true) ~= nil).toBe(true)
    end)
end)
