-- Nx.Map:MinimapSyncBreadcrumbFrame (MapEngine.lua): the route trail stays above the map artwork

local function syncFn()
    local src = loader.read("Carbonite/Modules/Map/MapEngine.lua")
    local first = src:find("function Nx.Map:MinimapSyncBreadcrumbFrame", 1, true)
    local last = src:find("\nend", first, true)
    local env = { Nx = { Map = {} }, max = math.max, type = type }
    local chunk = assert(loadstring(src:sub(first, last + 4)))
    setfenv(chunk, env)
    chunk()
    return env.Nx.Map.MinimapSyncBreadcrumbFrame
end

local function frame(level)
    local f = { level = level, strata = "MEDIUM" }
    function f:GetFrameLevel() return self.level end
    function f:SetFrameLevel(l) self.level = l end
    function f:GetFrameStrata() return self.strata end
    function f:SetFrameStrata(s) self.strata = s end
    return f
end

local function map(visible, mmLevel)
    return {
        MMFrm = frame(mmLevel),
        Frm = frame(1),
        MinimapIsVisibleSurface = function() return visible end,
    }
end

describe("camada das setas da rota", function()
    local sync = syncFn()

    it("com o minimapa baixo, a seta fica onde foi desenhada (acima da arte do mapa)", function()
        local f = frame(40)
        expect(sync(map(true, 0), f)).toBe(true)
        expect(f.level).toBe(40)
    end)

    it("com o minimapa alto, a seta sobe para cima dele", function()
        local f = frame(40)
        sync(map(true, 60), f)
        expect(f.level).toBe(62)
    end)

    it("chamadas repetidas não acumulam e voltam ao nível desenhado quando o minimapa some", function()
        local f = frame(40)
        sync(map(true, 60), f)
        sync(map(true, 60), f)
        expect(f.level).toBe(62)
        sync(map(false, 60), f)
        expect(f.level).toBe(40)
    end)
end)
