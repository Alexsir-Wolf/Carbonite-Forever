-- Gathering nodes on the integrated minimap (#214): Find Herbs/Minerals
-- nodes are minimap blips drawn at the minimap's alpha, so tracking raises
-- the integrated minimap to its own transparency option.

local function has(src, text)
    return src:find(text, 1, true) ~= nil
end

describe("minimapa integrado com Localizar Plantas/Minérios", function()
    local engine = loader.read("Carbonite/Modules/Map/MapEngine.lua")
    local options = loader.read("Carbonite/Modules/Options/OptionsEngine.lua")

    it("tem opção própria, padrão 60%", function()
        expect(has(engine, "NXMMTrackAlpha = .6,")).toBe(true)
        expect(has(options, 'mapRange(101.5, L["Transparency While Tracking on the Minimap"], 0, 1, .01, mapSettings, "NXMMTrackAlpha")')).toBe(true)
    end)

    it("sobe a opacidade só no integrado, sem passar por cima do acoplado nem do Ctrl", function()
        expect(engine:find("elseif self:MinimapBlipTracking%(%) then.-al = math%.max%(al, lOpts%.NXMMTrackAlpha or %.6%)")).toBeTruthy()
        local track = engine:find("al = math.max(al, lOpts.NXMMTrackAlpha or .6)", 1, true)
        local ctrl = engine:find("al = IsAltKeyDown() and 1 or .8", 1, true)
        expect(track < ctrl).toBe(true)
    end)

    it("reconhece as magias de coleta e atualiza no evento de rastreamento", function()
        expect(has(engine, "2383, 2580, 2481, 43308,")).toBe(true)
        expect(has(engine, 'blipTrackingEvents:RegisterEvent("MINIMAP_UPDATE_TRACKING")')).toBe(true)
    end)
end)

describe("rastreamentos de caçador e de outras classes (#284)", function()
    local engine = loader.read("Carbonite/Modules/Map/MapEngine.lua")
    local list = engine:match("local BLIP_TRACKING_SPELLS = (%b{})")

    it("entram na lista dos que sobem o minimapa integrado", function()
        expect(list ~= nil).toBe(true)
        for _, id in ipairs({ 1494, 19883, 19884, 19885, 19880, 19878, 19882, 19879, 5225, 5502, 5500 }) do
            expect(list:find("%f[%d]" .. id .. "%f[%D]") ~= nil).toBe(true)
        end
    end)

    it("deixa de fora os rastreamentos de cidade, sem pontos no minimapa", function()
        expect(engine:find("GetNumTrackingTypes() or 0 do", 1, true) ~= nil).toBe(true)
        expect(engine:find("if active and (blipTrackingNames[name] or blipTrackingTex[tex]) then", 1, true) ~= nil).toBe(true)
    end)
end)

describe("ícones de coleta do Carbonite com rastreamento ativo", function()
    it("ficam abaixo do minimapa para o ponto do rastreamento aparecer", function()
        local engine = loader.read("Carbonite/Modules/Map/MapEngine.lua")
        expect(engine:find("if self:MinimapBlipTracking%(%) then\r?\n%s*frame:SetFrameLevel%(math%.max%(level %- 1, 0%)%)")).toBeTruthy()
    end)
end)

describe("minimapa integrado acima da janela com rastreamento ativo", function()
    it("sobe um strata acima da janela do mapa", function()
        local engine = loader.read("Carbonite/Modules/Map/MapEngine.lua")
        expect(engine:find("lvl = self:MinimapSyncLayer(lvl, above and 15 or 1, self:MinimapBlipTracking())", 1, true) ~= nil).toBe(true)
    end)
end)

describe("ícones maiores no minimapa com rastreamento ativo", function()
    it("usa a escala própria, padrão 1,8, só enquanto rastreia", function()
        local engine = loader.read("Carbonite/Modules/Map/MapEngine.lua")
        local defaults = loader.read("Carbonite/Modules/PlayerCharacter/Defaults.lua")
        expect(engine:find("isc = math.max(isc, Nx.db.profile.MiniMap.TrackIScale or 1.8)", 1, true) ~= nil).toBe(true)
        expect(defaults:find("TrackIScale = 1.8,", 1, true) ~= nil).toBe(true)
    end)
end)

describe("só os pontos de coleta, sem o terreno do minimapa", function()
    local engine = loader.read("Carbonite/Modules/Map/MapEngine.lua")

    it("usa a máscara transparente no integrado enquanto rastreia", function()
        expect(engine:find([[local MINIMAP_CLEAR_MASK = "Interface\\AddOns\\Carbonite\\Gfx\\Map\\32Transparent"]], 1, true) ~= nil).toBe(true)
        expect(engine:find('self:MinimapUpdateMask("Square", nil, self:MinimapHidesTerrain())', 1, true) ~= nil).toBe(true)
    end)

    it("desenha os pontos com alpha cheio e respeita a opção", function()
        expect(engine:find("if self:MinimapHidesTerrain%(%) then\r?\n%s*al = 1")).toBeTruthy()
        expect(engine:find("return Nx.db.profile.MiniMap.TrackHideTerrain ~= false", 1, true) ~= nil).toBe(true)
    end)
end)
