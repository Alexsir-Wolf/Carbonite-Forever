-- Carbonite.Info/NxInfo.lua: an info window with nothing to show is no longer an empty box (#198).

local function split(sep, s)
    local out, pos = {}, 1
    while true do
        local i = string.find(s, sep, pos, true)
        if not i then out[#out + 1] = string.sub(s, pos) break end
        out[#out + 1] = string.sub(s, pos, i - 1)
        pos = i + 1
    end
    return unpack(out)
end

local function fakeList()
    local list = { rows = {}, data = {} }
    function list:ItemAdd(d) self.data[#self.data + 1] = d end
    function list:ItemSet(_, str) self.rows[#self.data] = str end
    function list:ItemSetFrame() end
    return list
end

local function newInfo(items, inCombat)
    local env = wow.lenientEnv({ strsplit = split })
    env.Nx = wow.namespace({ InCombat = inCombat })
    loader.run(env, "Carbonite.Info/NxInfo.lua")
    local Info = env.Nx.Info
    Info.ItemFuncs = { IfCombat = Info.CalcIfCombat, FPS = Info.CalcFPS }
    env.GetFramerate = function() return 60 end
    local info = setmetatable({ Index = 1, Data = { Items = items }, List = fakeList(), Vars = {} },
        { __index = Info })
    info:UpdateItems()
    return info.List
end

describe("Janelas de info sem conteúdo", function()
    it("mostram uma dica de configuração quando nenhuma linha aparece", function()
        local list = newInfo({ "<IfCombat><FPS><c>FPS <t>" }, false)
        expect(#list.data).toBe(1)
        expect(list.rows[1]).toContain("Info #1: nothing to show now. Right-click to configure")
        expect(list.data[1]).toBe(2)
    end)

    it("mostram a dica numa janela nova sem itens", function()
        local list = newInfo({}, false)
        expect(#list.data).toBe(1)
        expect(list.data[1]).toBe(1)
    end)

    it("não mostram a dica quando há linhas visíveis", function()
        local list = newInfo({ "<IfCombat><FPS><c>FPS <t>" }, true)
        expect(#list.data).toBe(1)
        expect(list.rows[1]).toContain("FPS 60")
    end)

    it("a dica existe em enUS e pt-BR", function()
        local key = 'L["Info #%d: nothing to show now. Right-click to configure"]'
        expect(loader.read("Carbonite.Info/Locales/enUS.lua")).toContain(key)
        expect(loader.read("Carbonite.Info/Locales/ptBR.lua")).toContain(key)
    end)
end)

describe("Atualização periódica das janelas de info", function()
    local function load()
        local env = wow.lenientEnv({ strsplit = split }, { "issecretvalue" })
        env.Nx = wow.namespace({})
        local ticker = {}
        env.C_Timer = { NewTicker = function(delay, fn)
            ticker.delay, ticker.fn = delay, fn
            return { Cancel = function() ticker.cancelled = true end }
        end }
        env.UnitHealth = function() return 977 end
        env.UnitHealthMax = function() return 977 end
        env.UnitPower = function() return 1650 end
        env.UnitPowerMax = function() return 1650 end
        env.UnitIsDeadOrGhost = function() return false end
        env.UnitName = function() return nil end
        loader.run(env, "Carbonite.Info/NxInfo.lua")
        local Info = env.Nx.Info
        Info.Vars, Info.Infos = {}, {}
        return env, Info, ticker
    end

    it("agenda um ticker que chama OnTimer e lê vida e mana atuais", function()
        local _, Info, ticker = load()
        Info:StartTimer()
        expect(ticker.delay).toBe(0.1)
        local updated = 0
        Info.Infos[1] = setmetatable({ Data = {}, Update = function() updated = updated + 1 end },
            { __index = Info })
        ticker.fn()
        expect(Info.Vars["Health"]).toBe(977)
        expect(Info.Vars["Health%"]).toBe(1)
        expect(Info.Vars["Mana%"]).toBe(1)
        expect(updated).toBe(1)
    end)

    it("não duplica o ticker quando é iniciado de novo", function()
        local _, Info, ticker = load()
        Info:StartTimer()
        Info:StartTimer()
        expect(ticker.cancelled).toBe(true)
    end)

    it("ToggleShow preenche as janelas na hora, sem esperar o ticker", function()
        local _, Info = load()
        local updated, shown = 0, false
        local win = { IsShown = function() return shown end, Show = function(_, b) shown = b end }
        for n = 1, 2 do
            Info.Infos[n] = setmetatable({ Data = {}, Win = win,
                Update = function() updated = updated + 1 end }, { __index = Info })
        end
        Info:ToggleShow()
        expect(updated > 0).toBe(true)
        expect(Info.Vars["Health"]).toBe(977)
    end)

    it("Init inicia o ticker", function()
        local src = loader.read("Carbonite.Info/NxInfo.lua")
        expect(src).toContain("self:StartTimer()")
    end)
end)
