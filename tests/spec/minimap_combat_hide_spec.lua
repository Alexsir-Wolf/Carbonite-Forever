-- Nx.Map:MinimapSyncVisibility (MapEngine.lua): map closed in combat leaves no
-- player arrow or blips on screen

local BLANK = "Interface\\Addons\\Carbonite\\Gfx\\Map\\32Transparent"

local function load(state)
    local src = loader.read("Carbonite/Modules/Map/MapEngine.lua"):gsub("\r\n", "\n")
    local env = {
        Nx = { Map = {}, db = { profile = { MiniMap = { NodeGD = state.glow or 0 } } } },
        type = type,
        InCombatLockdown = function() return state.combat end,
    }
    local first = assert(src:find('local MINIMAP_BLANK_TEX', 1, true))
    local stop = assert(src:find("function Nx.Map:MinimapSyncVisibility(", first, true))
    local last = assert(src:find("\nend", stop, true))
    local chunk = assert(loadstring(src:sub(first, last + 4)))
    setfenv(chunk, env)
    chunk()

    local mm = { shown = true, alpha = 1, protected = true }
    function mm:IsShown() return self.shown end
    function mm:Hide() self.shown = false end
    function mm:SetAlpha(a) self.alpha = a end
    function mm:IsProtected() return self.protected end
    function mm:SetPlayerTexture(t) self.player = t end
    function mm:SetBlipTexture(t) self.blip = t end

    local map = setmetatable({
        MMOwn = true,
        MMFrm = mm,
        MinimapIsHostVisible = function() return state.visible end,
        MinimapNodeGlowSet = function(self, letter) mm.blip = "MMOIcons" .. letter end,
    }, { __index = env.Nx.Map })
    return map, mm
end

describe("minimapa ao fechar o mapa em combate", function()
    it("esconde a seta e os pontos quando só dá para zerar o alpha", function()
        local state = { combat = true, visible = false }
        local map, mm = load(state)
        map:MinimapSyncVisibility()
        expect(mm.alpha).toBe(0)
        expect(mm.player).toBe(BLANK)
        expect(mm.blip).toBe(BLANK)
    end)

    it("no fim do combate esconde de verdade e devolve a arte", function()
        local state = { combat = true, visible = false }
        local map, mm = load(state)
        map:MinimapSyncVisibility()
        state.combat = false
        map:MinimapSyncVisibility()
        expect(mm.shown).toBe(false)
        expect(mm.player).toBe("Interface\\Minimap\\MinimapArrow")
        expect(mm.blip).toBe("Interface\\Minimap\\ObjectIconsAtlas")
        expect(map.MMBlankedArt).toBe(nil)
    end)

    it("reabrir o mapa ainda em combate devolve a arte", function()
        local state = { combat = true, visible = false }
        local map, mm = load(state)
        map:MinimapSyncVisibility()
        state.visible = true
        map:MinimapSyncVisibility()
        expect(mm.player).toBe("Interface\\Minimap\\MinimapArrow")
    end)

    it("com o brilho dos pontos ligado, volta para a textura do brilho", function()
        local state = { combat = true, visible = false, glow = 1 }
        local map, mm = load(state)
        map:MinimapSyncVisibility()
        state.combat = false
        map:MinimapSyncVisibility()
        expect(mm.blip).toBe("MMOIcons")
    end)

    it("fora de combate só esconde, sem trocar a arte", function()
        local state = { combat = false, visible = false }
        local map, mm = load(state)
        map:MinimapSyncVisibility()
        expect(mm.shown).toBe(false)
        expect(mm.player).toBe(nil)
    end)
end)
