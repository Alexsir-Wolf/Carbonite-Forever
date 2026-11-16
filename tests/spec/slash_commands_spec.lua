-- Carbonite/Core/SlashCommands.lua: one /carb router, help built from the registry and the
-- developer tools under /carb debug (#61)

local function load()
    local env = wow.lenientEnv()
    local said = {}
    env.DEFAULT_CHAT_FRAME = { AddMessage = function(_, text) said[#said + 1] = text end }
    env.SlashCmdList = {}
    loader.run(env, "Carbonite/Core/SlashCommands.lua")
    local Slash = env.Carbonite.Core.SlashCommands
    Slash:Register("map", function(rest) said.map = rest end, "show / hide / toggle the Carbonite map")
    Slash:RegisterDebug("flags", function(rest) said.flags = rest end, "list / toggle Carbonite debug flags")
    return env, Slash, said
end

local function contains(list, text)
    for _, line in ipairs(list) do
        if line:find(text, 1, true) then return true end
    end
    return false
end

describe("/carb", function()
    it("liga /carb e /cb ao mesmo roteador", function()
        local env = load()
        env.Carbonite.Core.EventBus:Fire("CARBONITE_ENABLE")
        expect(env.SLASH_CARBONITECMD1).toBe("/carb")
        expect(env.SLASH_CARBONITECMD2).toBe("/cb")
        expect(env.SlashCmdList.CARBONITECMD).toBe(env.Carbonite.Core.SlashCommands.Dispatch)
    end)

    it("a ajuda sai do registro e não lista a depuração", function()
        local _, Slash, said = load()
        Slash.Dispatch("ajuda")
        expect(contains(said, "/carb map - show / hide / toggle the Carbonite map")).toBe(true)
        expect(contains(said, "/carb debug - ")).toBe(true)
        expect(contains(said, "flags")).toBe(false)
    end)

    it("repassa o resto da linha ao comando", function()
        local _, Slash, said = load()
        Slash.Dispatch("  MAP show  ")
        expect(said.map).toBe("show")
    end)

    it("as ferramentas de desenvolvimento ficam em /carb debug", function()
        local _, Slash, said = load()
        Slash.Dispatch("flags DebugMap")
        expect(said.flags).toBeNil()
        expect(contains(said, "Unknown command: flags")).toBe(true)
        Slash.Dispatch("debug flags DebugMap")
        expect(said.flags).toBe("DebugMap")
        Slash.Dispatch("debug")
        expect(contains(said, "/carb debug flags - list / toggle Carbonite debug flags")).toBe(true)
    end)
end)

describe("comandos herdados", function()
    it("viram registros, sem o crash e sem o roteador antigo", function()
        local env, _, _ = load()
        env.Nx = wow.namespace()
        loader.run(env, "Carbonite/Modules/SlashHandler/SlashCommandEngine.lua")
        local said = {}
        env.DEFAULT_CHAT_FRAME = { AddMessage = function(_, text) said[#said + 1] = text end }
        local Slash = env.Carbonite.Core.SlashCommands
        Slash.Dispatch("help")
        expect(contains(said, "/carb goto")).toBe(true)
        expect(contains(said, "/carb rl")).toBe(true)
        Slash.Dispatch("debug")
        expect(contains(said, "/carb debug editmode")).toBe(true)
        expect(contains(said, "crash")).toBe(false)
        expect(rawget(env.Nx, "slashCommand")).toBeNil()
        expect(loader.read("Carbonite/Modules/InitFlow/AceAddonLifecycle.lua"):find("slashCommand", 1, true)).toBeNil()
        expect(loader.read("Carbonite/Modules/Modules.xml"):find("SlashHandler.lua", 1, true)).toBeNil()
    end)
end)
