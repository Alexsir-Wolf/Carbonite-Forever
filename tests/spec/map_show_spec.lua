-- Carbonite/Modules/Map/Map.lua: /carb map show / hide / toggle never leave the map
-- window gray, with or without the integrated minimap (#197)

local function frame(shown)
    local f = { shown = shown }
    function f:IsShown() return self.shown end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    return f
end

local function window(shown, max)
    local w = { Frm = frame(shown), max = max }
    function w:IsShown() return self.Frm:IsShown() end
    function w:Show(show) self.Frm.shown = show ~= false end
    function w:IsSizeMax() return self.max end
    return w
end

-- Map module wired to a created legacy map; `docked` mimics MMOwn.
local function load(winShown, frmShown, opts)
    opts = opts or {}
    local env = wow.lenientEnv()
    local mod = {}
    env.Carbonite.Core.Module = { New = function() return mod end }
    env.Carbonite.Compat = { MapApi = {} }
    local m = { Win = window(winShown, opts.max), Frm = frame(frmShown), MMOwn = opts.docked }
    function m:RestoreSize() self.Win.max = false end
    local legacy = { Created = true, opens = 0 }
    function legacy:GetMap(i) return i == 1 and m or nil end
    function legacy:Open() self.opens = self.opens + 1; m.Frm.shown = not m.Frm.shown end
    env.Carbonite.Map = legacy
    loader.run(env, "Carbonite/Modules/Map/Map.lua")
    return mod, m, legacy
end

describe("/carb map show", function()
    it("com o minimapa integrado aberto, mantém o desenho", function()
        local mod, m, legacy = load(true, true, { docked = true })
        mod:Open()
        expect(m.Frm:IsShown()).toBe(true)
        expect(m.Win:IsShown()).toBe(true)
        expect(legacy.opens).toBe(0)
    end)

    it("repõe o desenho de uma janela que ficou cinza", function()
        local mod, m = load(true, false, { docked = true })
        mod:Open()
        expect(m.Frm:IsShown()).toBe(true)
    end)

    it("mostra a janela fechada com o desenho", function()
        local mod, m = load(false, true)
        mod:Open()
        expect(m.Win:IsShown()).toBe(true)
        expect(m.Frm:IsShown()).toBe(true)
    end)

    it("repetido não alterna o desenho", function()
        local mod, m = load(true, true)
        mod:Open()
        mod:Open()
        expect(m.Frm:IsShown()).toBe(true)
    end)
end)

describe("/carb map hide e toggle", function()
    it("hide fecha a janela sem esconder só o desenho", function()
        local mod, m = load(true, true, { docked = true, max = true })
        mod:Close()
        expect(m.Win:IsShown()).toBe(false)
        expect(m.Win:IsSizeMax()).toBe(false)
        expect(m.Frm:IsShown()).toBe(true)
        mod:Open()
        expect(m.Win:IsShown()).toBe(true)
        expect(m.Frm:IsShown()).toBe(true)
    end)

    it("toggle alterna a janela inteira", function()
        local mod, m = load(true, true)
        mod:Toggle()
        expect(m.Win:IsShown()).toBe(false)
        mod:Toggle()
        expect(m.Win:IsShown()).toBe(true)
        expect(m.Frm:IsShown()).toBe(true)
    end)

    it("toggle numa janela cinza devolve o desenho", function()
        local mod, m = load(true, false)
        mod:Toggle()
        expect(m.Win:IsShown()).toBe(true)
        expect(m.Frm:IsShown()).toBe(true)
    end)

    it("antes de criado, show cria pelo motor antigo", function()
        local mod, _, legacy = load(false, false)
        legacy.Created = false
        mod:Open()
        expect(legacy.opens).toBe(1)
    end)
end)
