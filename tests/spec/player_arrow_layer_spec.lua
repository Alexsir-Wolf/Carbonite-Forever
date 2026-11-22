-- Nx.Map:MinimapSyncPlayerArrowLayer (MapEngine.lua): the player arrow stays above the route

local function syncFns(combat)
    local src = loader.read("Carbonite/Modules/Map/MapEngine.lua"):gsub("\r\n", "\n")
    local env = {
        Nx = { Map = {} }, max = math.max, type = type, ipairs = ipairs,
        InCombatLockdown = function() return combat end,
    }
    for _, name in ipairs({ "MinimapSyncPlayerArrowLayer", "MinimapSyncBreadcrumbFrame" }) do
        local first = assert(src:find("function Nx.Map:" .. name .. "(", 1, true))
        local last = assert(src:find("\nend", first, true))
        local chunk = assert(loadstring(src:sub(first, last + 4)))
        setfenv(chunk, env)
        chunk()
    end
    return env.Nx.Map
end

local function frame(level, strata)
    local f = { level = level, strata = strata or "MEDIUM", shown = true }
    function f:GetFrameLevel() return self.level end
    function f:SetFrameLevel(l) self.level = l end
    function f:GetFrameStrata() return self.strata end
    function f:SetFrameStrata(s) self.strata = s end
    function f:IsShown() return self.shown end
    function f:Hide() self.shown = false end
    return f
end

-- One pass of Nx.Map:Update: route at 60, player arrow at 90, then the minimap layer passes.
local function pass(opts)
    local fns = syncFns(opts.combat or false)
    local map = {
        MMFrm = frame(opts.minimap, opts.minimapStrata),
        Frm = frame(1),
        PlyrFrm = frame(90),
        LOpts = { NXMMFull = opts.full or false },
        MinimapIsVisibleSurface = function() return opts.visible ~= false end,
        MinimapShouldUseBlizzardPlayerArrow = function() return true end,
        IsUnmappedInstance = function() return false end,
    }
    local route = frame(60)
    fns.MinimapSyncBreadcrumbFrame(map, route)
    fns.MinimapSyncPlayerArrowLayer(map)
    return map.PlyrFrm, route
end

describe("camada da seta do jogador", function()
    it("com o minimapa baixo, fica onde foi desenhada, acima da rota", function()
        local player, route = pass({ minimap = 10 })
        expect(player.level).toBe(90)
        expect(player.level > route.level).toBe(true)
    end)

    it("em combate também fica acima da rota", function()
        local player, route = pass({ minimap = 10, combat = true })
        expect(player.level > route.level).toBe(true)
    end)

    it("na camada de cima (coleta, encaixado), fica acima da rota que subiu junto", function()
        local player, route = pass({ minimap = 10, minimapStrata = "HIGH" })
        expect(player.strata).toBe("HIGH")
        expect(player.level > route.level).toBe(true)
    end)

    it("com o minimapa alto, sobe para cima dele e da rota", function()
        local player, route = pass({ minimap = 120 })
        expect(player.level).toBe(123)
        expect(player.level > route.level).toBe(true)
    end)

    it("sem minimapa visível não muda", function()
        local player = pass({ minimap = 10, visible = false })
        expect(player.level).toBe(90)
        expect(player.strata).toBe("MEDIUM")
    end)

    it("minimapa em tamanho cheio continua com a seta da Blizzard", function()
        local player = pass({ minimap = 10, full = true })
        expect(player.shown).toBe(false)
    end)
end)
