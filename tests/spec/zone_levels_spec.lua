-- Zone level ranges drawn over the continent map (#68):
-- Carbonite/Modules/Map/MapIDs.lua (GetZoneLevelLabel, ZoneLevelLabelAlpha) and the
-- map wiring in MapEngine.lua.

local function split(sep, s)
    local out = {}
    for field in (s .. sep):gmatch("(.-)%" .. sep) do out[#out + 1] = field end
    return unpack(out)
end

local function load(faction)
    local env = wow.lenientEnv()
    env.Nx = wow.namespace({
        Split = split,
        Zones = {
            [1429] = "Elwynn Forest|1|10|0",
            [1411] = "Durotar|1|10|1",
            [1434] = "Stranglethorn Vale|30|45|2",
            [1453] = "Stormwind City|0|0|0",
            [1460] = "Old Zone|0|0|2",
        },
        Map = {
            PlFactionNum = faction,
            GetWorldZone = function(_, mapID) return { City = mapID == 1453 } end,
        },
    })
    loader.run(env, "Carbonite/Modules/Map/MapIDs.lua")
    return env.Carbonite.Modules.Map.MapIDs
end

describe("faixa de nível das zonas no mapa", function()
    it("monta 'Nome\\nmin-max' na cor da facção", function()
        local MapIDs = load(0)
        expect(MapIDs:GetZoneLevelLabel(1429, "Elwynn Forest")).toBe("|cff20ff20Elwynn Forest\n1-10|r")
        expect(MapIDs:GetZoneLevelLabel(1411, "Durotar")).toBe("|cffff6060Durotar\n1-10|r")
        expect(MapIDs:GetZoneLevelLabel(1434, "Stranglethorn Vale")).toBe("|cffffff00Stranglethorn Vale\n30-45|r")
    end)

    it("segue a facção do jogador", function()
        local MapIDs = load(1)
        expect(MapIDs:GetZoneLevelLabel(1411, "Durotar")).toBe("|cff20ff20Durotar\n1-10|r")
        expect(MapIDs:GetZoneLevelLabel(1429, "Elwynn Forest")).toBe("|cffff6060Elwynn Forest\n1-10|r")
    end)

    it("mostra só a faixa quando não há nome", function()
        local MapIDs = load(0)
        expect(MapIDs:GetZoneLevelLabel(1434)).toBe("|cffffff0030-45|r")
        expect(MapIDs:GetZoneLevelLabel(1434, "")).toBe("|cffffff0030-45|r")
    end)

    it("não rotula cidades nem zonas sem faixa", function()
        local MapIDs = load(0)
        expect(MapIDs:GetZoneLevelLabel(1453, "Stormwind City")).toBe(nil)
        expect(MapIDs:GetZoneLevelLabel(1460, "Old Zone")).toBe(nil)
        expect(MapIDs:GetZoneLevelLabel(99999, "Unknown")).toBe(nil)
    end)

    it("aparece no zoom de continente e some ao aproximar da zona", function()
        local MapIDs = load(0)
        local alpha = MapIDs.ZoneLevelLabelAlpha
        -- Zone too small on screen (world zoom): hidden.
        expect(alpha(40, 1000)).toBe(0)
        -- Continent zoom: fully visible.
        expect(alpha(200, 1000)).toBe(1)
        -- Fades in just above the minimum size.
        local a = alpha(80, 1000)
        expect(a > 0 and a < 1).toBe(true)
        -- Zoomed into the zone (zone wider than 60% of the map): hidden.
        expect(alpha(700, 1000)).toBe(0)
        local b = alpha(580, 1000)
        expect(b > 0 and b < 1).toBe(true)
    end)

    it("não aparece em janela de mapa pequena (minimapa)", function()
        local MapIDs = load(0)
        expect(MapIDs.ZoneLevelLabelAlpha(150, 250)).toBe(0)
        expect(MapIDs.ZoneLevelLabelAlpha(nil, 1000)).toBe(0)
    end)

    it("tem opção no menu Mostrar..., ligada por padrão, e é desenhada no update do mapa", function()
        local engine = loader.read("Carbonite/Modules/Map/MapEngine.lua")
        expect(engine:find('showMenu:AddItem(0, L["Show Zone Levels"]', 1, true) ~= nil).toBe(true)
        expect(engine:find('item:SetChecked(Nx.db.profile.Map, "ShowZoneLevels")', 1, true) ~= nil).toBe(true)
        expect(engine:find("self:UpdateZoneLevelLabels()", 1, true) ~= nil).toBe(true)
        local defaults = loader.read("Carbonite/Modules/PlayerCharacter/Defaults.lua")
        expect(defaults:find("ShowZoneLevels = true", 1, true) ~= nil).toBe(true)
        expect(loader.read("Carbonite/Locales/enUS/Map.lua"):find('L["Show Zone Levels"] = true', 1, true) ~= nil).toBe(true)
        expect(loader.read("Carbonite/Locales/ptBR/Map.lua"):find('L["Show Zone Levels"] = "', 1, true) ~= nil).toBe(true)
    end)
end)
