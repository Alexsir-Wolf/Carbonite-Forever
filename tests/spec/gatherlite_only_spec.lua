-- Only GatherLite's gathering nodes on the map; GatherMate2_Data leaves the edition

local function guide(glActive, setting)
    local env = wow.lenientEnv()
    env.Nx = wow.namespace({
        db = { char = { Map = { ShowGatherH = setting } } },
        Notes = { GatherLiteActive = function() return glActive end },
        Map = wow.namespace({ Guide = wow.namespace() }),
    })
    loader.run(env, "Carbonite/Data/Shared/NxMapGuide.lua")
    return env.Nx.Map.Guide
end

describe("só o GatherLite", function()
    it("com o GatherLite no mapa, o Carbonite não desenha os próprios nós", function()
        expect(guide(true, true):ShowsOwnGather("ShowGatherH")).toBe(false)
    end)

    it("sem o GatherLite, vale a opção do Carbonite", function()
        expect(guide(false, true):ShowsOwnGather("ShowGatherH")).toBe(true)
        expect(guide(false, false):ShowsOwnGather("ShowGatherH")).toBe(false)
    end)

    it("o GatherMate2_Data e a importação saem da edição", function()
        expect(loader.read(".pkgmeta"):find("Gathermate2_Data", 1, true)).toBeNil()
        expect(loader.read("Carbonite/Modules/Gather/GatherStorage.lua"):find("GatherImport", 1, true)).toBeNil()
        expect(loader.read("Carbonite/Modules/Options/OptionsEngine.lua"):find("NXCmdImportCarb", 1, true)).toBeNil()
        local ok = pcall(loader.read, "Carbonite.Gathermate2_Data/Carbonite.Gathermate2_Data-Camelot.toc")
        expect(ok).toBe(false)
    end)
end)
