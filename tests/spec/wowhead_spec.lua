-- Nx.Quest:WowheadURL in Carbonite.Quests/WatchWindow.lua (#21)

local function url(flags, locale)
    local env = wow.lenientEnv()
    env.GetLocale = function() return locale end
    -- Every flavor flag set, so the namespace does not invent truthy ones.
    local nx = { Quest = { Watch = {} }, isCamelot = false, isClassicEra = false, isTBCClassic = false,
                 isWotlkClassic = false, isCataClassic = false, isMoPClassic = false }
    for k, v in pairs(flags) do nx[k] = v end
    env.Nx = wow.namespace(nx)
    loader.run(env, "Carbonite.Quests/WatchWindow.lua")
    return env.Nx.Quest:WowheadURL(783)
end

describe("Quest:WowheadURL", function()
    it("no Forever aponta para o Wowhead Classic no idioma do cliente", function()
        expect(url({ isCamelot = true }, "ptBR")).toBe("https://www.wowhead.com/classic/pt/quest=783")
        expect(url({ isCamelot = true }, "enUS")).toBe("https://www.wowhead.com/classic/quest=783")
    end)

    it("quest que só existe no Forever não tem link", function()
        local env = wow.lenientEnv()
        env.GetLocale = function() return "ptBR" end
        env.Nx = wow.namespace({ Quest = { Watch = {} }, isCamelot = true,
            Quests = { [783] = {}, [90001] = { ForeverOnly = true } } })
        loader.run(env, "Carbonite.Quests/WatchWindow.lua")
        expect(env.Nx.Quest:WowheadURL(90001)).toBeNil()
        expect(env.Nx.Quest:WowheadURL(783)).toBe("https://www.wowhead.com/classic/pt/quest=783")
        expect(loader.read("Carbonite.Quests/QuestieSource.lua"):find("ForeverOnly = true", 1, true) ~= nil).toBe(true)
    end)

    it("no Retail segue sem subdomínio", function()
        expect(url({ isRetail = true }, "ptBR")).toBe("https://www.wowhead.com/quest=783")
    end)
end)
