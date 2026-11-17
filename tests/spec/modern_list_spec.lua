-- The modern look of the quest list for every window (#43): Nx.List:SetModernRows,
-- Nx.Window:ApplyModernHeader and the shared helpers of Carbonite/UI/Skin.lua.

local function texture()
    local t = { shown = true, points = {} }
    function t:SetColorTexture(r, g, b, a) self.color = { r, g, b, a } end
    function t:SetGradient(_, from, to) self.gradient = { from, to } end
    function t:SetPoint(...) table.insert(self.points, { ... }) end
    function t:ClearAllPoints() self.points = {} end
    function t:SetHeight(h) self.h = h end
    function t:SetAlpha(a) self.alpha = a end
    function t:Show() self.shown = true end
    function t:Hide() self.shown = false end
    return t
end

local function listFrame()
    local f = { textures = {}, scripts = {} }
    function f:CreateTexture() local t = texture(); table.insert(self.textures, t); return t end
    function f:SetScript(name, fn) self.scripts[name] = fn end
    return f
end

local function loadList()
    local env = wow.lenientEnv()
    env.Nx = wow.namespace()
    env.Carbonite.UI = { Skin = { Paint = function(_, t, name) t.token = name end } }
    loader.run(env, "Carbonite/Modules/UI/UIEngine.lua")
    return env.Nx.List
end

local function list(top, num)
    local List = loadList()
    local inst = setmetatable({ Frm = listFrame(), Vis = 4, Top = top, Num = num, HdrH = 12, Slider = false },
        { __index = function(_, k) return rawget(List, k) end })
    inst.GetLineH = function() return 10 end
    return inst
end

local function shownBands(inst)
    local n = 0
    for _, t in ipairs(inst.RowBands or {}) do if t.shown then n = n + 1 end end
    return n
end

describe("linhas da lista moderna", function()
    it("pinta uma faixa nas linhas pares e o destaque do mouse com tokens", function()
        local inst = list(1, 4)
        inst:SetModernRows()
        expect(shownBands(inst)).toBe(2)
        expect(inst.RowBands[1].token).toBe("rowStripe")
        expect(inst.HoverTex.token).toBe("rowHover")
        expect(inst.Frm.scripts.OnEnter ~= nil).toBe(true)
    end)

    it("as faixas acompanham a rolagem e somem sem linhas", function()
        local inst = list(2, 3)
        inst:SetModernRows()
        -- Visible lines 2 and 3: only line 2 is even, drawn on the first visible row.
        expect(shownBands(inst)).toBe(1)
        expect(inst.RowBands[1].points[1][5]).toBe(-12)
        inst.Num = 0
        inst:UpdateModernRows()
        expect(shownBands(inst)).toBe(0)
    end)

    it("desligar tira as faixas", function()
        local inst = list(1, 4)
        inst:SetModernRows()
        inst:SetModernRows(false)
        expect(shownBands(inst)).toBe(0)
    end)
end)

describe("régua e atlases compartilhados", function()
    local function loadSkin(atlases)
        local env = wow.lenientEnv()
        env.Carbonite.UI = {}
        env.C_Texture = { GetAtlasInfo = function(name) return atlases[name] and {} or nil end }
        env.CreateColor = function(r, g, b, a) return { r, g, b, a } end
        loader.run(env, "Carbonite/UI/Skin.lua")
        return env.Carbonite.UI.Skin
    end

    it("HasAtlases diz qual atlas falta", function()
        local Skin = loadSkin({ a = true })
        expect(Skin:HasAtlases({ "a" })).toBe(true)
        local ok, missing = Skin:HasAtlases({ "a", "b" })
        expect(ok).toBe(false)
        expect(missing).toBe("b")
    end)

    it("a régua do cabeçalho segue o tema", function()
        local Skin = loadSkin({})
        Skin:Set("Blizzard", true)
        local f = listFrame()
        local rule = Skin:AddHeaderRule(f, -20)
        expect(rule.gradient[1][2]).toBe(0.82)
        Skin:Set("Modern Light")
        expect(rule.gradient[1][2]).toBe(0.42)
    end)
end)

describe("cabeçalho moderno nas janelas", function()
    it("Guia, Warehouse, Notas, Novidades, Info e Eventos usam o cabeçalho e as linhas modernas", function()
        for _, path in ipairs({ "Carbonite/Data/Shared/NxMapGuide.lua", "Carbonite.Warehouse/Engine.lua",
                                "Carbonite.Notes/WindowEngine.lua", "Carbonite/Modules/Whatsnew/WhatsnewEngine.lua",
                                "Carbonite.Info/NxInfo.lua", "Carbonite/Modules/UserEvents/UEventsEngine.lua" }) do
            local src = loader.read(path)
            expect(src:find("ApplyModernHeader()", 1, true) ~= nil).toBe(true)
            expect(src:find("SetModernRows()", 1, true) ~= nil).toBe(true)
        end
    end)

    it("a lista de quests usa a API genérica", function()
        local src = loader.read("Carbonite.Quests/WatchWindow.lua")
        expect(src:find("Carbonite.UI.Skin:HasAtlases (MODERN_ATLASES)", 1, true) ~= nil).toBe(true)
        expect(src:find("Carbonite.UI.Skin:AddHeaderRule", 1, true) ~= nil).toBe(true)
        expect(src:find("CreateColor (1, .82, 0, .8)", 1, true)).toBeNil()
    end)

    it("o estilo do título guarda o recuo que a janela deu ao título", function()
        local src = loader.read("Carbonite/Modules/UI/UIEngine.lua")
        expect(src:find("self:SetTitleXOff (self.TitleXOff or 0, self.TitleYOff)", 1, true) ~= nil).toBe(true)
    end)
end)
