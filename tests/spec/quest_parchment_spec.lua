-- Nx.Quest.SetParchment in Carbonite.Quests/QuestWindow.lua: the client's HD quest parchment (#42)

local function load(atlases)
    local env = wow.lenientEnv()
    env.C_Texture = { GetAtlasInfo = function(name) return atlases[name] and {} or nil end }
    env.Nx = wow.namespace({ Quest = wow.namespace(), List = {}, Window = {} })
    loader.run(env, "Carbonite.Quests/QuestWindow.lua")
    return env.Nx.Quest
end

-- `missing`: files this fake client does not have (SetTexture gives false).
local function texture(missing)
    local t = {}
    function t:SetAtlas(name) self.atlas = name end
    function t:SetTexture(path, h)
        if missing and missing[path] then return false end
        self.file, self.wrap = path, h
        return true
    end
    function t:SetHorizTile(on) self.htile = on end
    function t:SetVertTile(on) self.vtile = on end
    function t:SetTexCoord() end
    return t
end

local TILE = "Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal"

describe("pergaminho dos detalhes da quest", function()
    it("usa o pergaminho do próprio cliente quando existe", function()
        local t = texture()
        load({ ["QuestBG-Parchment"] = true }).SetParchment(t)
        expect(t.atlas).toBe("QuestBG-Parchment")
        expect(t.file).toBeNil()
    end)

    it("sem o atlas, repete um pergaminho no tamanho dele, sem esticar", function()
        local t = texture()
        load({}).SetParchment(t)
        expect(t.atlas).toBeNil()
        expect(t.file).toBe(TILE)
        expect(t.wrap).toBe("REPEAT")
        expect(t.htile and t.vtile).toBe(true)
    end)

    it("sem atlas nem o arquivo repetível, fica no QuestBG antigo", function()
        local t = texture({ [TILE] = true })
        load({}).SetParchment(t)
        expect(t.atlas).toBeNil()
        expect(t.file:find("QuestBG", 1, true) ~= nil).toBe(true)
    end)
end)
