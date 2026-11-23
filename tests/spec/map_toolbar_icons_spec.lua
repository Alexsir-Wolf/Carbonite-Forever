-- Barra do mapa: ícones que dizem o que fazem e uma definição só (#248)

describe("ícones da barra do mapa", function()
    local function types(atlases)
        local env = wow.lenientEnv()
        env.C_Texture = { GetAtlasInfo = function(name) return atlases[name] and {} or nil end }
        env.Nx = wow.namespace()
        loader.run(env, "Carbonite/Modules/UI/UIEngine.lua")
        env.Nx.Button:UseClientAtlases()
        return env.Nx.Button.TypeData
    end

    it("Guia, Combate e Eventos usam lupa, espadas e relógio", function()
        local t = types({
            ["common-search-magnifyingglass"] = true,
            ["UI-HUD-UnitFrame-Player-CombatIcon"] = true,
            ["worldquest-icon-clock"] = true,
        })
        expect(t.MapGuide.AtlasUp).toBe("common-search-magnifyingglass")
        expect(t.MapCombat.AtlasUp).toBe("UI-HUD-UnitFrame-Player-CombatIcon")
        expect(t.MapEvents.AtlasUp).toBe("worldquest-icon-clock")
    end)

    it("zoom usa a lupa com + e − quando o cliente tem", function()
        local t = types({ ["common-icon-zoomin"] = true, ["common-icon-zoomout"] = true })
        expect(t.MapZIn.AtlasUp).toBe("common-icon-zoomin")
        expect(t.MapZOut.AtlasUp).toBe("common-icon-zoomout")
    end)

    it("sem os atlas, o zoom usa os botões do minimapa do jogo", function()
        local t = types({})
        expect(t.MapZIn.Up).toBe("Interface\\Minimap\\UI-Minimap-ZoomInButton-Up")
        expect(t.MapZOut.Dn).toBe("Interface\\Minimap\\UI-Minimap-ZoomOutButton-Down")
    end)

    it("sem os atlas, Guia, Combate e Eventos ficam com o ícone de antes", function()
        local t = types({})
        expect(t.MapGuide.AtlasUp).toBeNil()
        expect(t.MapGuide.Up).toBe("$INV_Misc_QuestionMark")
        expect(t.MapCombat.Up).toBe("$Ability_DualWield")
        expect(t.MapEvents.Up).toBe("$INV_Misc_Note_03")
    end)
end)

describe("uma definição só da barra", function()
    local function load(barData)
        local env = wow.lenientEnv()
        local subs = {}
        env.Carbonite = {
            Modules = { Map = {} },
            Core = { EventBus = { Subscribe = function(_, ev, fn) subs[ev] = fn end } },
            L = function() return setmetatable({}, { __index = function(_, k) return k end }) end,
        }
        local handlers = {}
        for _, name in ipairs({ "OnButToggle3D", "OnButZoomIn", "OnButZoomOut",
                                "OnButToggleGuide", "OnButToggleCombat", "OnButToggleEvent" }) do
            handlers[name] = function() return name end
        end
        env.Nx = { BarData = barData, Map = handlers }
        loader.run(env, "Carbonite/Modules/Map/MapToolBar.lua")
        return env.Carbonite.Modules.Map.MapToolBar, env.Nx, subs
    end

    local function ids(bar)
        local out = {}
        for _, b in ipairs(bar) do out[#out + 1] = b[1] end
        return table.concat(out, ",")
    end

    it("os botões padrão, com o 3D, em ordem e com dica", function()
        local T, Nx = load(nil)
        T:RegisterDefaults(true)
        expect(ids(Nx.BarData)).toBe("Map3D,MapZIn,MapZOut,MapGuide,MapCombat,MapEvents")
        for _, b in ipairs(Nx.BarData) do
            expect(type(b[2])).toBe("string")
            expect(type(b[3])).toBe("function")
        end
    end)

    it("registrar de novo não duplica", function()
        local T, Nx, subs = load(nil)
        T:RegisterDefaults(true)
        subs.CARBONITE_LOADED()
        expect(#Nx.BarData).toBe(6)
    end)

    it("não apaga os botões de addons que já estavam na barra", function()
        local adopted = { "NxAddonBut_Questie", "Questie", function() end, false }
        local T, Nx = load({ adopted })
        T:RegisterDefaults(true)
        expect(ids(Nx.BarData)).toBe("Map3D,MapZIn,MapZOut,MapGuide,MapCombat,MapEvents,NxAddonBut_Questie")
    end)

    it("o mapa não tem mais a própria lista de botões", function()
        local src = loader.read("Carbonite/Modules/Map/MapEngine.lua")
        expect(src:find('{"MapZIn", L["Zoom In"]', 1, true)).toBeNil()
        expect(src:find("MapToolBar:RegisterDefaults(true)", 1, true) ~= nil).toBe(true)
    end)
end)
