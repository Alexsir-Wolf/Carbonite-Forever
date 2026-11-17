-- Barra de título e barra de ferramentas do mapa no tema (#47):
-- Nx.Window:StyleTitleBar, Nx.ToolBar:StyleTool e os botões de addons

-- Região falsa (textura, font string ou frame) que guarda o que recebeu.
local function region(font)
    local r = { points = {}, textures = {} }
    function r:SetColorTexture(...) self.color = { ... } end
    function r:SetTextColor(...) self.textColor = { ... } end
    function r:SetTexCoord(...) self.coord = { ... } end
    function r:SetBlendMode(m) self.blend = m end
    function r:SetPoint(...) table.insert(self.points, { ... }) end
    function r:ClearAllPoints() self.points = {} end
    function r:SetAllPoints() self.all = true end
    function r:SetHeight(h) self.height = h end
    function r:SetWordWrap(on) self.wrap = on end
    function r:SetAlpha(a) self.alpha = a end
    function r:SetBackdropBorderColor(...) self.border = { ... } end
    function r:Show() self.shown = true end
    function r:Hide() self.shown = false end
    function r:GetFont() return "font", font or 10 end
    function r:CreateTexture(_, layer)
        local t = region()
        t.layer = layer
        table.insert(self.textures, t)
        return t
    end
    return r
end

local function load()
    local env = wow.lenientEnv()
    env.Carbonite.UI = {}
    env.Nx = wow.namespace({ db = { profile = { Skin = {} } } })
    loader.run(env, "Carbonite/UI/Skin.lua")
    local Skin = env.Carbonite.UI.Skin
    Skin:Set("Blizzard", true)
    env.Nx.Skin = { GetBackdrop = function() return Skin:GetBackdrop() end,
                    GetBorderCol = function() return Skin:GetBorderColor() end }
    loader.run(env, "Carbonite/Modules/UI/UIEngine.lua")
    return env.Nx, Skin
end

local function same(a, b)
    for i = 1, 4 do
        if a[i] ~= b[i] then return false end
    end
    return true
end

describe("tokens da barra do mapa", function()
    it("o tema define a cor do título, a faixa do título e o fundo dos ícones", function()
        local _, Skin = load()
        local r, g, b = Skin:GetToken("title")
        expect(r).toBe(1)
        expect(g).toBe(0.82)
        expect(b).toBe(0)
        local _, _, _, a = Skin:GetToken("toolSlot")
        expect(a > 0).toBe(true)
    end)

    it("texto pintado com token muda de cor com o tema", function()
        local env = wow.lenientEnv()
        env.Carbonite.UI = {}
        env.Nx = { db = { profile = { Skin = {} } } }
        loader.run(env, "Carbonite/UI/Skin.lua")
        local Skin = env.Carbonite.UI.Skin
        Skin:Set("Blizzard", true)
        local fs = region()
        Skin:PaintText(fs, "title")
        expect(fs.textColor[1]).toBe(1)
        Skin:Set("Modern Light")
        expect(fs.textColor[1]).toBe(0.1)
    end)
end)

describe("barra de título do mapa", function()
    local function window(Nx, fontSize)
        local close = { Frm = region() }
        function close:SetSize(w, h) self.size = { w, h } end
        function close:SetPos(side, x, y) self.pos = { side, x, y } end
        local win = setmetatable({
            Frm = region(), TitleFStr = { region(fontSize), region(fontSize) },
            TitleLineH = 10, TitleLines = 2, BorderW = 7, BorderH = 7,
            Border = true, Sizeable = true, ButClose = close,
            ButMaxer = false, ButMiner = false, TitleBar = false,
            SetTitleXOff = function() end,
        }, { __index = Nx.Window })
        return win, close
    end

    it("a linha do título acompanha a fonte e não corta o texto", function()
        local Nx = load()
        local win = window(Nx, 12)
        win:StyleTitleBar()
        expect(win.TitleLineH).toBe(16)
        expect(win.TitleH).toBe(34)
        expect(win.TitleFStr[1].height).toBe(16)
        expect(win.TitleFStr[2].wrap).toBe(false)
    end)

    it("título na cor do tema, sobre uma faixa pintada com token", function()
        local Nx, Skin = load()
        local win = window(Nx)
        win:StyleTitleBar()
        expect(same(win.TitleFStr[1].textColor, { Skin:GetToken("title") })).toBe(true)
        expect(same(win.TitleBar.color, { Skin:GetToken("titleBar") })).toBe(true)
        win:SetBordersFade(0)
        expect(win.TitleBar.alpha).toBe(0)
    end)

    it("o botão de fechar ou destravar ganha a altura da linha", function()
        local Nx = load()
        local win, close = window(Nx, 12)
        win:StyleTitleBar()
        expect(close.size[1]).toBe(16)
        expect(close.pos[1]).toBe("TOPRIGHT")
        expect(win.ButW).toBe(18)
    end)

    it("o mapa usa a barra de título do tema", function()
        local src = loader.read("Carbonite/Modules/Map/MapEngine.lua")
        expect(src:find("win:StyleTitleBar()", 1, true) ~= nil).toBe(true)
    end)
end)

describe("cadeado com atlas do cliente", function()
    local function types(atlases)
        local env = wow.lenientEnv()
        env.C_Texture = { GetAtlasInfo = function(name) return atlases[name] and {} or nil end }
        env.Nx = wow.namespace()
        loader.run(env, "Carbonite/Modules/UI/UIEngine.lua")
        env.Nx.Button:UseClientAtlases()
        return env.Nx.Button.TypeData
    end

    it("usa o primeiro cadeado que o cliente tem", function()
        local t = types({ ["Forge-Lock"] = true })
        expect(t.Lock.AtlasUp).toBe("Forge-Lock")
        expect(t.CloseLock.AtlasUp).toBe("Forge-Lock")
    end)

    it("sem cadeado no cliente, fica a textura do skin", function()
        local t = types({})
        expect(t.Lock.AtlasUp).toBeNil()
        expect(t.Lock.Up).toBe("ButLock")
    end)
end)

describe("barra de ferramentas do mapa", function()
    local function tool(Nx, up)
        local but = { Frm = region(), Type = { Up = up, Bool = true } }
        but.Frm.texture = region()
        function but:Update() self.updated = true end
        Nx.ToolBar:StyleTool(but)
        return but
    end

    it("cada ícone fica numa moldura com as cores do tema", function()
        local Nx, Skin = load()
        local f = tool(Nx, "$Spell_ChargePositive").Frm
        expect(same(f.textures[1].color, { Skin:GetToken("separator") })).toBe(true)
        expect(same(f.NxSlot.color, { Skin:GetToken("toolSlot") })).toBe(true)
        expect(same(f.NxChecked.color, { Skin:GetToken("selection") })).toBe(true)
        expect(f.NxChecked.blend).toBe("ADD")
    end)

    it("ícones alinhados: recuo igual e sem a borda própria do ícone", function()
        local Nx = load()
        local tx = tool(Nx, "$Spell_ChargePositive").Frm.texture
        expect(tx.points[1][4]).toBe(Nx.ToolBar.TOOL_INSET)
        expect(tx.coord[1]).toBe(0.08)
        local addon = tool(Nx, "Interface\\AddOns\\Questie\\Icons\\available.blp").Frm.texture
        expect(addon.coord).toBeNil()
    end)

    it("todo botão da barra passa pela moldura e tem dica", function()
        local src = loader.read("Carbonite/Modules/UI/UIEngine.lua")
        local add = src:match("function Nx%.ToolBar:AddButton.-\nend")
        expect(add:find("self:StyleTool (but)", 1, true) ~= nil).toBe(true)
        expect(add:find("Nx.Button:Create (self.Frm, typ, nil, name,", 1, true) ~= nil).toBe(true)
    end)

    it("sem cores fixas no botão 3D nem nos botões de addons", function()
        local ui = loader.read("Carbonite/Modules/UI/UIEngine.lua")
        local map3d = ui:match('%["Map3D"%] = {.-}')
        expect(map3d:find("RGB", 1, true)).toBeNil()
        local map = loader.read("Carbonite/Modules/Map/MapEngine.lua")
        expect(map:find("|cffffffff3D", 1, true)).toBeNil()
        local addons = loader.read("Carbonite/Modules/Map/AddonButtons.lua")
        expect(addons:find("SetColorTexture%(%s*%d")).toBeNil()
        expect(addons:find("1, 0.84, 0", 1, true)).toBeNil()
        expect(addons:find("0.5, 0.78, 1", 1, true)).toBeNil()
    end)

    it("a barra mantém a ordem e as funções dos botões", function()
        local src = loader.read("Carbonite/Modules/Map/MapToolBar.lua")
        local ids = {}
        for id in src:gmatch('RegisterButton%(%{ id = "(%w+)"') do ids[#ids + 1] = id end
        expect(table.concat(ids, ",")).toBe("Map3D,MapZIn,MapZOut,MapGuide,MapCombat,MapEvents")
    end)
end)
