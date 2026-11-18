-- Round mask of the live minimap: "textures\MinimapMask" does not exist on
-- WoW Forever and left the integrated minimap blank, without the gathering
-- nodes of Find Herbs / Find Minerals.

describe("máscara redonda do minimapa", function()
    local engine = loader.read("Carbonite/Modules/Map/MapEngine.lua")

    it("não usa a textura antiga que o cliente não tem", function()
        expect(engine:find([["textures\\MinimapMask"]], 1, true)).toBeNil()
    end)

    it("usa a máscara redonda que existe no cliente, no início e no modo integrado", function()
        expect(engine:find([[local MINIMAP_ROUND_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"]], 1, true) ~= nil).toBe(true)
        expect(engine:find("mm:SetMaskTexture (MINIMAP_ROUND_MASK)", 1, true) ~= nil).toBe(true)
        expect(engine:find("local roundMask = MINIMAP_ROUND_MASK", 1, true) ~= nil).toBe(true)
    end)
end)
