-- Nx.Window:OnCloseBut in Carbonite/Modules/UI/UIEngine.lua: the padlock of a locked window
-- unlocks it instead of closing it

local function window(locked)
    local env = wow.lenientEnv()
    env.Nx = wow.namespace()
    loader.run(env, "Carbonite/Modules/UI/UIEngine.lua")
    local calls = {}
    local win = setmetatable({
        Locked = locked, Closer = true,
        Lock = function(_, on) calls.lock = on end,
        Show = function(_, on) calls.show = on end,
        OpenMenu = function() calls.menu = true end,
        RecordLayoutData = function() end,
        Notify = function() end,
    }, { __index = env.Nx.Window })
    return win, calls
end

describe("cadeado da janela", function()
    it("clicar no cadeado destrava a janela e não a fecha", function()
        local win, calls = window(true)
        win:OnCloseBut(nil, nil, "LeftButton")
        expect(calls.lock).toBe(false)
        expect(calls.show).toBeNil()
    end)

    it("sem trava, o X fecha a janela", function()
        local win, calls = window(false)
        win:OnCloseBut(nil, nil, "LeftButton")
        expect(calls.show).toBe(false)
    end)

    it("sem trava, o clique direito abre o menu", function()
        local win, calls = window(false)
        win:OnCloseBut(nil, nil, "RightButton")
        expect(calls.menu).toBe(true)
    end)
end)
