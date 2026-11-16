-- Option sliders: full label and the unit of the value (#101)

-- Loads the Options module and returns the root table AceConfig would get.
local function rootWith(provider)
    local env = wow.lenientEnv()
    local mod = {}
    local build
    env.Carbonite.Core.Module = { New = function() return mod end }
    env.Carbonite.Core.SlashCommands = { Register = function() end }
    env.LibStub = function(name)
        if name == "AceConfig-3.0" then
            return { RegisterOptionsTable = function(_, _, fn) build = fn end }
        end
        return wow.anything()
    end
    loader.run(env, "Carbonite/Modules/Options/Options.lua")
    mod:Register("Teste", provider)
    mod:OnEnable()
    return build()
end

describe("sliders das Opções", function()
    it("ganham largura dupla para o rótulo não ser cortado", function()
        local root = rootWith(function()
            return { type = "group", args = {
                atraso = { type = "range", name = "Atraso de atualização do monitor (ms)" },
                cheio = { type = "range", name = "x", width = "full" },
                sub = { type = "group", args = { fonte = { type = "range", name = "y", width = "normal" } } },
            } }
        end)
        local args = root.args.Teste.args
        expect(args.atraso.width).toBe("double")
        expect(args.cheio.width).toBe("full")
        expect(args.sub.args.fonte.width).toBe("double")
    end)

    it("mostram a unidade no rótulo", function()
        local env = wow.lenientEnv()
        env.Nx = wow.namespace({ Opts = {} })
        loader.run(env, "Carbonite/Modules/Options/OptionsEngine.lua")
        expect(env.Nx.Opts.Unit("Atraso", "ms")).toBe("Atraso (ms)")
        local src = loader.read("Carbonite.Quests/Options.lua")
        expect(src:find('Nx.Opts.Unit(L["Watch Delay Time"], "ms")', 1, true) ~= nil).toBe(true)
    end)
end)
