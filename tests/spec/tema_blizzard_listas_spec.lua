-- Tema Blizzard nas listas (#42, #203): cabeçalhos de seção no estilo dos Amigos,
-- botões vermelho e cinza, campo de busca do jogo e fonte base 12/14.

local function loadSkin()
    local env = wow.lenientEnv()
    env.Carbonite.UI = {}
    loader.run(env, "Carbonite/UI/Skin.lua")
    return env.Carbonite.UI.Skin
end

local function fontObject(name)
    local o = { name = name }
    function o:SetFontObject(parent) self.parent = parent end
    function o:GetFont() return self.face, self.size, self.flags end
    function o:SetFont(face, size, flags) self.face, self.size, self.flags = face, size, flags end
    function o:SetShadowColor() end
    function o:SetShadowOffset() end
    return o
end

local function loadFont(fontProfile)
    local env = wow.lenientEnv()
    env.Carbonite.UI = {}
    env.CreateFont = function(name) return fontObject(name) end
    env.LibStub = function() return nil end
    env.Nx = { db = { profile = { Font = fontProfile } } }
    loader.run(env, "Carbonite/UI/Font.lua")
    return env.Carbonite.UI.Font, env
end

local function texture()
    local t = { shown = true, points = {} }
    function t:SetColorTexture(r, g, b, a) self.color = { r, g, b, a } end
    function t:SetPoint(...) table.insert(self.points, { ... }) end
    function t:ClearAllPoints() self.points = {} end
    function t:SetHeight(h) self.h = h end
    function t:SetWidth(w) self.w = w end
    function t:SetSize(w, h) self.w, self.h = w, h end
    function t:SetAlpha(a) self.alpha = a end
    function t:EnableMouse() end
    function t:Show() self.shown = true end
    function t:Hide() self.shown = false end
    function t:CreateTexture() return texture() end
    return t
end

local function loadEngine(gameStyle, atlases)
    local env = wow.lenientEnv()
    env.Nx = wow.namespace()
    env.C_Texture = { GetAtlasInfo = function(name) return atlases and atlases[name] and {} or nil end }
    env.CreateFrame = function() return texture() end
    env.Carbonite.UI = { Skin = {
        Paint = function(_, t, name) t.token = name end,
        GameStyle = function() return gameStyle end,
    } }
    loader.run(env, "Carbonite/Modules/UI/UIEngine.lua")
    return env.Nx
end

-- A list instance with the engine's methods, without the frames of Create.
local function list(gameStyle, num)
    local Nx = loadEngine(gameStyle)
    local frm = texture()
    function frm:GetWidth() return 200 end
    local inst = setmetatable({ Frm = frm, Vis = 4, Top = 1, Num = num or 4, HdrH = 16, Slider = false },
        { __index = function(_, k) return rawget(Nx.List, k) end })
    inst.GetLineH = function() return 16 end
    return inst
end

local function shownBars(inst)
    local n = 0
    for _, bar in ipairs(inst.SectionBars or {}) do if bar.Box.shown then n = n + 1 end end
    return n
end

describe("tema Blizzard: tokens", function()
    it("só o Blizzard usa o estilo do jogo", function()
        local Skin = loadSkin()
        Skin:Set("Blizzard", true)
        expect(Skin:GameStyle()).toBe(true)
        Skin:Set("Modern Dark", true)
        expect(Skin:GameStyle()).toBe(false)
    end)

    it("contorno bronze no Blizzard e invisível nos outros temas", function()
        local Skin = loadSkin()
        Skin:Set("Blizzard", true)
        local _, _, _, a = Skin:GetToken("sectionEdge")
        expect(a).toBe(1)
        expect(Skin:TextCode("sectionSign")).toBe("|cffffd100")
        expect(Skin:TextCode("muted")).toBe("|cff999999")
        Skin:Set("Glass", true)
        _, _, _, a = Skin:GetToken("sectionEdge")
        expect(a).toBe(0)
    end)
end)

describe("fonte base 12/14 (#203)", function()
    it("as listas têm base 12 e o título 14, mesmo com a fonte normal menor", function()
        local Font = loadFont({ Small = "Friz", SmallSize = 10, Medium = "Friz", MediumSize = 9 })
        expect(Font:GetRoleSize("list")).toBe(12)
        expect(Font:GetRoleSize("title")).toBe(14)
    end)

    it("respeitam uma fonte maior e acompanham a escala", function()
        local Font = loadFont({ Medium = "Friz", MediumSize = 13, MediumSpacing = 2, Scale = 1.5 })
        expect(Font:GetRoleSize("list")).toBe(20)
        expect(Font:GetHeight("Role.list")).toBe(22)
        Font = loadFont({ Medium = "Friz", MediumSize = 9, Scale = 1.5 })
        expect(Font:GetRoleSize("list")).toBe(18)
    end)

    it("uma lista pede o papel pelo nome Role.list", function()
        local Font = loadFont({ Medium = "Friz", MediumSize = 12 })
        expect(Font:GetObject("Role.list").name).toBe("NxFontList")
        expect(Font:GetObject("Role.normal")).toBeNil()
    end)

    it("a fonte de itens do Warehouse tem mínimo 12", function()
        local Font, env = loadFont({ Medium = "Friz", MediumSize = 12 })
        env.Nx.wdb = { profile = { Warehouse = { WarehouseFont = "Friz", WarehouseFontSize = 9 } } }
        Font:Define("Warehouse.WarehouseFont", { object = "NxFontWHI", inherit = "GameFontNormal", scope = "wdb", min = 12 })
        Font:Update()
        expect(Font:GetObject("Warehouse.WarehouseFont").size).toBe(12)
        expect(loader.read("Carbonite.Warehouse/Init.lua"):find('"wdb", 12 }', 1, true) ~= nil).toBe(true)
    end)

    it("Guia, Notas e Warehouse usam a fonte das listas", function()
        for _, path in ipairs({ "Carbonite/Data/Shared/NxMapGuide.lua", "Carbonite.Notes/WindowEngine.lua",
                                "Carbonite.Warehouse/Engine.lua" }) do
            local src = loader.read(path)
            expect(path .. ": " .. tostring(src:find('SetCreateFont%s?%("Role.list"') ~= nil)).toBe(path .. ": true")
        end
    end)
end)

describe("cabeçalhos de seção no estilo dos Amigos", function()
    it("desenha a faixa com contorno e o sinal dourado só no estilo do jogo", function()
        local inst = list(true)
        inst:ItemSetSection(true, 1)
        inst:ItemSetSection(false, 3)
        inst:UpdateSections(16, 16)
        expect(shownBars(inst)).toBe(2)
        local open, closed = inst.SectionBars[1], inst.SectionBars[2]
        expect(open.Fill.token).toBe("sectionBg")
        expect(open.Edges[1].token).toBe("sectionEdge")
        expect(open.Minus.token).toBe("sectionSign")
        expect(open.Plus.shown).toBe(false)
        expect(closed.Plus.shown).toBe(true)

        local other = list(false)
        other:ItemSetSection(true, 1)
        other:UpdateSections(16, 16)
        expect(shownBars(other)).toBe(0)
    end)

    it("a faixa troca o botão +/- da janela e o clique no sinal dobra a seção", function()
        local inst = list(true)
        inst:ItemSetSection(true, 2)
        expect(inst:IsSectionBar(2)).toBe(true)
        expect(inst:IsSectionBar(1)).toBe(false)
        expect(inst:SectionSignHit(2, 190)).toBe(true)
        expect(inst:SectionSignHit(2, 40)).toBe(false)
        expect(list(false):IsSectionBar(2)).toBe(false)
    end)

    it("as faixas somem ao esvaziar a lista", function()
        local inst = list(true)
        inst:ItemSetSection(true, 1)
        inst:UpdateSections(16, 16)
        inst.SectionData = {}
        inst:UpdateSections(16, 16)
        expect(shownBars(inst)).toBe(0)
        expect(loader.read("Carbonite/Modules/UI/UIEngine.lua"):find("wipe (self.SectionData)", 1, true) ~= nil)
            .toBe(true)
    end)

    it("o cabeçalho de colunas ganha altura e contorno no estilo do jogo", function()
        local Nx = loadEngine(true)
        Nx.Font.GetH = function() return 12 end
        expect(Nx.List:DefaultHdrH()).toBe(16)
        expect(loadEngine(false).List:DefaultHdrH()).toBe(12)
        local src = loader.read("Carbonite/Modules/UI/UIEngine.lua")
        expect(src:find('hfrm.edges = self:AddEdges (hfrm, "sectionEdge")', 1, true) ~= nil).toBe(true)
    end)

    it("Notas e Warehouse marcam as seções", function()
        local notes = loader.read("Carbonite.Notes/WindowEngine.lua")
        expect(select(2, notes:gsub("ItemSetSection%(not hide%)", ""))).toBe(2)
        local wh = loader.read("Carbonite.Warehouse/Engine.lua")
        expect(wh:find("list:ItemSetSection(open)", 1, true) ~= nil).toBe(true)
        expect(wh:find('eventName == "button") then', 1, true) ~= nil).toBe(true)
    end)
end)

describe("botões vermelho e cinza", function()
    it("os botões de texto têm 22 de altura", function()
        local types = loadEngine(true).Button.TypeData
        for _, name in ipairs({ "Txt64", "Txt64B", "TxtGrey", "TxtGreyB" }) do
            expect(name .. " " .. tostring(types[name].HeightUp)).toBe(name .. " 22")
        end
    end)

    it("o cinza usa o atlas do jogo quando existe e mantém o tom de pressionado", function()
        local Nx = loadEngine(true, { ["128-RedButton-Disable"] = true })
        Nx.Button:UseClientAtlases()
        expect(Nx.Button.TypeData.TxtGrey.AtlasUp).toBe("128-RedButton-Disable")
        expect(Nx.Button.TypeData.TxtGreyB.VRGBADn).toBe("1|.82|.3|1")
    end)

    it("sem o atlas, fica o arquivo do botão cinza do painel", function()
        local Nx = loadEngine(true, {})
        Nx.Button:UseClientAtlases()
        expect(Nx.Button.TypeData.TxtGrey.AtlasUp).toBeNil()
        expect(Nx.Button.TypeData.TxtGrey.Up).toBe("Interface\\Buttons\\UI-Panel-Button-Disabled")
    end)
end)

describe("campo de busca do jogo", function()
    local function fakeFrame()
        local f = wow.frame()
        f.CreateTexture = function() return fakeFrame() end
        f.CreateFontString = function() return fakeFrame() end
        return f
    end

    local function create(gameStyle)
        local SearchBox, env = wow.searchBox({ CreateFrame = function() return fakeFrame() end })
        env.Carbonite.UI.Skin = {
            Paint = function(_, t, name) t.token = name end,
            PaintText = function() end,
            GetToken = function() return 1, 1, 1, 1 end,
            GameStyle = function() return gameStyle end,
        }
        return SearchBox:Create(fakeFrame(), function() end), env
    end

    it("no Blizzard tem borda, fundo escuro e nenhum sublinhado", function()
        local box = create(true)
        expect(#box.Border).toBe(3)
        expect(box.Bg.token).toBe("searchBg")
        expect(box.Line.shown).toBe(false)
    end)

    it("nos outros temas fica a faixa plana", function()
        local box = create(false)
        expect(box.Border).toBeNil()
        expect(box.Bg.token).toBe("listHeader")
        expect(box.Line.shown).toBe(true)
    end)

    it("troca de visual quando o tema muda", function()
        local style = false
        local SearchBox, env = wow.searchBox({ CreateFrame = function() return fakeFrame() end })
        env.Carbonite.UI.Skin = {
            Paint = function(_, t, name) t.token = name end,
            PaintText = function() end,
            GetToken = function() return 1, 1, 1, 1 end,
            GameStyle = function() return style end,
        }
        local box = SearchBox:Create(fakeFrame(), function() end)
        style = true
        env.Carbonite.Core.EventBus:Fire("SKIN_UPDATED", "Blizzard")
        expect(box.Bg.token).toBe("searchBg")
        expect(box.Border[1].shown).toBe(true)
    end)
end)
