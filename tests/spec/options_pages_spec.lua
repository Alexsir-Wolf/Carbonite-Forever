-- Option pages that repeated the legacy ones in English and saved keys nothing read (#55)

describe("páginas de opções duplicadas", function()
    it("Map, HUD e Travel não registram mais página própria", function()
        for _, path in ipairs({ "Carbonite/Modules/Map/Map.lua", "Carbonite/Modules/HUD/HUD.lua",
                                "Carbonite/Modules/Travel/Travel.lua" }) do
            expect(loader.read(path):find("Options:Register", 1, true)).toBeNil()
        end
    end)

    it("Quests, Notes e Warehouse se ligam ao Carbonite sem página de opções", function()
        for _, path in ipairs({ "Carbonite.Quests/Plugin.lua", "Carbonite.Notes/Plugin.lua",
                                "Carbonite.Warehouse/Plugin.lua" }) do
            local src = loader.read(path)
            expect(src:find("options = function", 1, true)).toBeNil()
            expect(src:find('Plugin.Bind%(%w+, "%w+"%)') ~= nil).toBe(true)
        end
    end)

    it("Plugin.Bind registra o addon sem assinar eventos de opções", function()
        local env = wow.lenientEnv()
        local bus = wow.eventBus()
        env.Carbonite.Core.EventBus = bus
        env.Carbonite.Core.Logger = { Get = function() return {} end }
        loader.run(env, "Carbonite/Core/Plugin.lua")
        local Plugin = env.Carbonite.Core.Plugin
        local addon = {}
        Plugin.Bind(addon, "Notes")
        expect(Plugin.Plugins()[1].name).toBe("Notes")
        expect(addon.bus).toBe(bus)
        expect(bus.subs.MODULE_ENABLED).toBeNil()
    end)
end)
