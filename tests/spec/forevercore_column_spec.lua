-- Limites do monitor de quests para a coluna do ForeverCore (#85)

-- Frame do monitor: posição, escala e scripts ligados por HookScript.
local function watchFrame()
    local f = { left = 100, top = 700, w = 200, h = 300, scale = 1, alpha = 1, shown = true, hooks = {} }
    function f:GetLeft() return self.left end
    function f:GetRight() return self.left + self.w end
    function f:GetTop() return self.top end
    function f:GetBottom() return self.top - self.h end
    function f:GetEffectiveScale() return self.scale end
    function f:GetEffectiveAlpha() return self.alpha end
    function f:IsVisible() return self.shown end
    function f:HookScript(script, fn)
        self.hooks[script] = self.hooks[script] or {}
        table.insert(self.hooks[script], fn)
    end
    function f:Fire(script)
        for _, fn in ipairs(self.hooks[script] or {}) do fn(self) end
    end
    return f
end

local function load(opts)
    opts = opts or {}
    local env = wow.lenientEnv(nil, { "ForeverCore" })
    local frames = {}
    env.CreateFrame = function(_, name)
        local fr = wow.frame(name)
        table.insert(frames, fr)
        return fr
    end
    env.UIParent = { GetEffectiveScale = function() return opts.uiScale or 1 end }
    env.hooksecurefunc = function(t, key, fn)
        local orig = t[key]
        t[key] = function(...) local r = orig(...); fn(...); return r end
    end
    local frame = watchFrame()
    local win = { Frm = frame }
    env.Nx = wow.namespace({ Quest = wow.namespace() })
    env.Nx.Quest.Watch = { Win = win, Open = function() end }
    if opts.forever then env.ForeverCore = { API = 2 } end
    loader.run(env, "Carbonite.Quests/ForeverCoreColumn.lua")
    local events = frames[1]
    events.scripts.OnEvent(events, "PLAYER_LOGIN")
    local api = env.Carbonite.Quests.WatchBounds
    local function ticker() return frames[2] end
    local function tick() ticker().scripts.OnUpdate(ticker(), 0.3) end
    return api, frame, win, ticker, tick, env
end

local function listen(api)
    local calls = { n = 0 }
    api:AddLayoutListener({ id = "teste", onLayout = function() calls.n = calls.n + 1 end })
    return calls
end

describe("coluna do ForeverCore", function()
    it("não roda sem o ForeverCore carregado", function()
        local api, frame, _, ticker = load()
        expect(api:IsActive()).toBe(false)
        expect(api:GetListBounds()).toBeNil()
        expect(api:AddLayoutListener({ id = "x", onLayout = function() end })).toBe(false)
        expect(ticker()).toBeNil()
        expect(frame.hooks.OnShow).toBeNil()
    end)

    it("expõe os limites do monitor em unidades do UIParent", function()
        local api, frame = load({ forever = true, uiScale = 0.5 })
        expect(api:IsActive()).toBe(true)
        local l, r, t, b = api:GetListBounds()
        expect({ l, r, t, b }).toEqual({ 200, 600, 1400, 800 })
        frame.shown = false
        expect(api:GetListBounds()).toBeNil()
        frame.shown, frame.alpha = true, 0
        expect(api:GetListBounds()).toBeNil()
    end)

    it("avisa ao mostrar, esconder, redimensionar e minimizar, só quando muda", function()
        local api, frame = load({ forever = true })
        local calls = listen(api)
        frame:Fire("OnSizeChanged")
        expect(calls.n).toBe(0)              -- nada mudou
        frame.shown = false; frame:Fire("OnHide")
        expect(calls.n).toBe(1)
        frame.shown = true; frame:Fire("OnShow")
        expect(calls.n).toBe(2)
        frame.h = 20; frame:Fire("OnSizeChanged")  -- minimizado
        expect(calls.n).toBe(3)
    end)

    it("percebe o movimento pelo ticker e espera o fim do arraste", function()
        local api, frame, win, _, tick = load({ forever = true })
        local calls = listen(api)
        win.MovSizing = true
        frame.left = 400
        tick()
        expect(calls.n).toBe(0)
        win.MovSizing = false
        tick()
        expect(calls.n).toBe(1)
        tick()
        expect(calls.n).toBe(1)
    end)

    it("para o ticker quando o último ouvinte sai", function()
        local api, _, _, ticker = load({ forever = true })
        listen(api)
        expect(ticker().scripts.OnUpdate ~= nil).toBe(true)
        expect(api:RemoveLayoutListener("teste")).toBe(true)
        expect(ticker().scripts.OnUpdate).toBeNil()
    end)

    it("engancha a janela recriada por Watch:Open", function()
        local api, _, win, _, _, env = load({ forever = true })
        local calls = listen(api)
        local novo = watchFrame()
        win.Frm = novo
        env.Nx.Quest.Watch.Open()
        novo.shown = false; novo:Fire("OnHide")
        expect(calls.n).toBe(1)
    end)

    it("entra em todos os TOCs do módulo de quests, depois do WatchWindow", function()
        for _, toc in ipairs({ "", "-Camelot", "-Cata", "-Classic", "-Mists", "-Tbc", "-Wrath" }) do
            local text = loader.read("Carbonite.Quests/Carbonite.Quests" .. toc .. ".toc")
            local watch = text:find("WatchWindow.lua", 1, true)
            local column = text:find("ForeverCoreColumn.lua", 1, true)
            expect(column ~= nil and column > watch).toBe(true)
        end
    end)
end)
