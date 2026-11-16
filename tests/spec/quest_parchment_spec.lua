-- Nx.Quest.SetParchment in Carbonite.Quests/QuestWindow.lua: the client's HD quest parchment (#42)

local function load(atlases)
    local env = wow.lenientEnv()
    env.C_Texture = { GetAtlasInfo = function(name) return atlases[name] and {} or nil end }
    env.Nx = wow.namespace({ Quest = wow.namespace(), List = {}, Window = {} })
    loader.run(env, "Carbonite.Quests/QuestWindow.lua")
    return env.Nx.Quest
end

local function texture()
    local t = {}
    function t:SetAtlas(name) self.atlas = name end
    function t:SetTexture(path) self.file = path end
    function t:SetTexCoord() end
    return t
end

describe("pergaminho dos detalhes da quest", function()
    it("usa o pergaminho do próprio cliente quando existe", function()
        local t = texture()
        load({ ["QuestBG-Parchment"] = true }).SetParchment(t)
        expect(t.atlas).toBe("QuestBG-Parchment")
        expect(t.file).toBeNil()
    end)

    it("sem o atlas, fica no QuestBG antigo", function()
        local t = texture()
        load({}).SetParchment(t)
        expect(t.atlas).toBeNil()
        expect(t.file:find("QuestBG", 1, true) ~= nil).toBe(true)
    end)
end)
