-- Nx.prtStack in Carbonite/Modules/UI/UIEngine.lua (#17)

local function load(debugOn)
    local env = wow.lenientEnv()
    local calls = 0
    env.debugstack = function()
        calls = calls + 1
        return "Interface\\AddOns\\Carbonite\\x.lua:1"
    end
    env.Nx = wow.namespace({ TabBar = {}, Button = {} })
    loader.run(env, "Carbonite/Modules/UI/UIEngine.lua")
    env.Nx.DebugOn = debugOn
    env.Nx.prt = function() end
    return env.Nx, function() return calls end
end

describe("Nx.prtStack", function()
    it("não monta a pilha com a depuração desligada", function()
        local Nx, calls = load(false)
        Nx.prtStack("teste")
        expect(calls()).toBe(0)
    end)

    it("monta a pilha com a depuração ligada", function()
        local Nx, calls = load(true)
        Nx.prtStack("teste")
        expect(calls()).toBe(1)
    end)
end)
