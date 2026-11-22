-- Closing RXP or Zygor takes the guide's destination off Carbonite's queue (#220).
-- The bridges run over the real Targets and TomTomWaypoints modules; the guides are fakes
-- with the fields RXPGuides and Zygor Forever leave behind when they are closed.

local function carbonite()
    local env = wow.env({ hooksecurefunc = function() end })
    local map = { Targets = {}, Tracking = {}, MapId = 1429 }
    env.Nx = {
        Map = { Maps = { map } },
        Notes = {
            RXPFormatText = function(s) return s end,
            IsRXPIntegrationEnabled = function() return true end,
        },
        fdb = { profile = { Notes = { RXPArrow = true, ZygorArrow = true } } },
        db = { profile = { Map = {} } },
    }
    env.Carbonite.Modules.Map.Coords = {
        WorldFromZone = function(_, _, x, y) return x, y end,
    }
    loader.run(env, "Carbonite/Modules/Map/Targets.lua")
    loader.run(env, "Carbonite/Modules/Integrations/TomTomWaypoints.lua")
    env.Carbonite.Core.EventBus:Fire("CARBONITE_LOADED")

    local function names()
        local out = {}
        for i, tar in ipairs(map.Targets) do out[i] = tar.TargetName end
        return table.concat(out, "|")
    end
    -- What a Shift+Ctrl+click or /way adds: a kept "Goto".
    local function userTarget(name)
        env.Nx.Map.SetTarget(map, "Goto", 1, 1, 1, 1, nil, nil, name, true, 1429)
    end
    return env, names, userTarget
end

local function rxp()
    local env, names, userTarget = carbonite()
    local guide = {
        settings = { profile = { showEnabled = true, hideGuideWindow = false } },
        currentGuide = { name = "1-6 Durotar" },
    }
    local arrow = wow.frame("RXPG_ARROW")
    arrow.element = { zone = 1429, x = 42, y = 65, title = "Guia" }
    env.RXP, env.RXPG_ARROW = guide, arrow
    loader.run(env, "Carbonite.Notes/Integrations/RXPArrow.lua")
    local function sync() env.Nx.Notes:RXPArrowSync() end
    return guide, names, sync, userTarget
end

local function zygor()
    local env, names, userTarget = carbonite()
    local way = { m = 1429, x = 0.42, y = 0.65, type = "way", title = "Guia" }
    local guide = {
        Frame = wow.frame("ZygorGuidesViewerFrame"),
        db = { profile = { hidearrowwithguide = true } },
        Pointer = { ArrowFrame = wow.frame("arrow"), DestinationWaypoint = way },
    }
    guide.Pointer.ArrowFrame.waypoint = way
    env.ZGV = guide
    loader.run(env, "Carbonite.Notes/Integrations/ZygorArrow.lua")
    local function sync() env.Nx.Notes:ZygorArrowSync() end
    return guide, names, sync, userTarget
end

describe("fechar o RXP", function()
    it("remove o destino do guia e esvazia a fila", function()
        local guide, names, sync = rxp()
        sync()
        expect(names()).toBe("Guia")
        guide.settings.profile.showEnabled = false
        sync()
        expect(names()).toBe("")
    end)

    it("não apaga nem reordena os destinos do jogador", function()
        local guide, names, sync, userTarget = rxp()
        userTarget("antes")
        sync()
        userTarget("depois")
        guide.settings.profile.showEnabled = false
        sync()
        sync()
        expect(names()).toBe("antes|depois")
    end)

    it("fechado desde o login não cria destino", function()
        local guide, names, sync = rxp()
        guide.settings.profile.showEnabled = false
        sync()
        expect(names()).toBe("")
    end)

    it("reabrir devolve o destino do passo", function()
        local guide, names, sync = rxp()
        sync()
        guide.settings.profile.showEnabled = false
        sync()
        guide.settings.profile.showEnabled = true
        sync()
        expect(names()).toBe("Guia")
    end)

    it("descarregar o guia remove o destino que ficou no element", function()
        local guide, names, sync = rxp()
        sync()
        guide.currentGuide = { empty = true, name = "" }
        sync()
        expect(names()).toBe("")
    end)

    it("só esconder a janela mantém o destino, como a seta do RXP", function()
        local guide, names, sync = rxp()
        guide.settings.profile.hideGuideWindow = true
        sync()
        expect(names()).toBe("Guia")
    end)

    it("sem os campos de configuração segue como aberto", function()
        local guide, names, sync = rxp()
        guide.settings, guide.currentGuide = nil, nil
        expect(sync).toNotThrow()
        expect(names()).toBe("Guia")
    end)
end)

describe("fechar o Zygor", function()
    it("remove o destino do guia e esvazia a fila", function()
        local guide, names, sync = zygor()
        sync()
        expect(names()).toBe("Guia")
        guide.Frame:Hide()
        sync()
        expect(names()).toBe("")
    end)

    it("não apaga nem reordena os destinos do jogador", function()
        local guide, names, sync, userTarget = zygor()
        userTarget("antes")
        sync()
        userTarget("depois")
        guide.Frame:Hide()
        sync()
        sync()
        expect(names()).toBe("antes|depois")
    end)

    it("fechado desde o login não cria destino", function()
        local guide, names, sync = zygor()
        guide.Frame:Hide()
        sync()
        expect(names()).toBe("")
    end)

    it("reabrir devolve o destino do passo", function()
        local guide, names, sync = zygor()
        sync()
        guide.Frame:Hide()
        sync()
        guide.Frame:Show()
        sync()
        expect(names()).toBe("Guia")
    end)

    it("fechado só com o destino, sem waypoint na seta, também remove", function()
        local guide, names, sync = zygor()
        guide.Pointer.ArrowFrame.waypoint = false
        sync()
        expect(names()).toBe("Guia")
        guide.Frame:Hide()
        sync()
        expect(names()).toBe("")
    end)

    it("fechado remove o trecho de rota até um passo do guia", function()
        local guide, names, sync = zygor()
        guide.Pointer.ArrowFrame.waypoint = { m = 1429, x = 0.2, y = 0.3, type = "route", title = "Voo" }
        sync()
        guide.Frame:Hide()
        sync()
        expect(names()).toBe("")
    end)

    it("waypoint manual fica, sem o texto do passo", function()
        local guide, names, sync = zygor()
        guide.Pointer.ArrowFrame.waypoint.type = "manual"
        guide.CurrentStep = { num = 3 }
        sync()
        expect(names()).toBe("Step 3: Guia")
        guide.Frame:Hide()
        sync()
        expect(names()).toBe("Guia")
    end)

    it("trecho de rota até um waypoint manual fica", function()
        local guide, names, sync = zygor()
        guide.Pointer.ArrowFrame.waypoint = { m = 1429, x = 0.2, y = 0.3, type = "route", title = "Voo" }
        guide.Pointer.DestinationWaypoint.type = "manual"
        guide.Frame:Hide()
        sync()
        expect(names()).toBe("Voo")
    end)

    it("escondido por combate mantém o destino", function()
        local guide, names, sync = zygor()
        guide.hiddenincombat = true
        guide.Frame:Hide()
        sync()
        expect(names()).toBe("Guia")
    end)

    it("interface escondida (Alt+Z) mantém o destino", function()
        local guide, names, sync = zygor()
        guide.Frame = {
            IsShown = function() return true end,
            IsVisible = function() return false end,
        }
        sync()
        expect(names()).toBe("Guia")
    end)

    it("com hidearrowwithguide desligado mantém o destino, como a seta do Zygor", function()
        local guide, names, sync = zygor()
        guide.db.profile.hidearrowwithguide = false
        guide.Frame:Hide()
        sync()
        expect(names()).toBe("Guia")
    end)

    it("sem os campos da janela segue como aberto", function()
        local guide, names, sync = zygor()
        guide.Frame, guide.db = nil, nil
        expect(sync).toNotThrow()
        expect(names()).toBe("Guia")
    end)
end)
