-- Option "Use only the Blizzard minimap": Carbonite keeps no small map on
-- screen and leaves the minimap to Blizzard; only the full map opens.

local function has(src, text)
    return src:find(text, 1, true) ~= nil
end

describe("usar só o minimapa da Blizzard", function()
    local engine = loader.read("Carbonite/Modules/Map/MapEngine.lua")
    local options = loader.read("Carbonite/Modules/Options/OptionsEngine.lua")
    local defaults = loader.read("Carbonite/Modules/PlayerCharacter/Defaults.lua")

    it("vem desligada", function()
        expect(has(defaults, "BlizzOnly = false,")).toBe(true)
    end)

    it("o Carbonite não assume o minimapa com ela ligada", function()
        expect(engine:find("m%.MMOwn = Nx%.db%.profile%.MiniMap%.Own and not Nx%.db%.profile%.MiniMap%.BlizzOnly")).toBeTruthy()
    end)

    it("o mapa pequeno não abre no login", function()
        expect(has(engine, "m.StartupShown = win:IsShown() and not (index == 1 and Nx.Map:BlizzMinimapOnly())")).toBe(true)
    end)

    it("pedir o mapa pequeno abre o mapa grande", function()
        expect(engine:find("if szmode == 0 and self:BlizzMinimapOnly%(%) then\r?\n%s*szmode = 1")).toBeTruthy()
    end)

    it("fechar o mapa grande esconde o Carbonite", function()
        expect(has(engine, "if Nx.db.profile.Map.MaxRestoreHide or Nx.Map:BlizzMinimapOnly() then")).toBe(true)
    end)

    it("a opção desliga o minimapa combinado e o desabilita", function()
        expect(has(options, 'name = L["Use only the Blizzard minimap"],')).toBe(true)
        expect(has(options, "disabled = function() return Nx.db.profile.MiniMap.BlizzOnly end,")).toBe(true)
        local fn = options:match("function Nx%.Opts:NXCmdBlizzOnlyChange %(on%).-\nend")
        expect(fn).toBeTruthy()
        expect(has(fn, "mm.Own = false")).toBe(true)
        expect(has(fn, "map.Win:Show (false)")).toBe(true)
        expect(has(fn, "self:NXCmdReload()")).toBe(true)
    end)
end)

describe("Nx.Map:BlizzMinimapOnly", function()
    local function only(profile)
        local engine = loader.read("Carbonite/Modules/Map/MapEngine.lua")
        local body = engine:match("(function Nx%.Map:BlizzMinimapOnly%(%).-\nend)")
        local env = { Nx = { Map = {}, db = profile and { profile = profile } } }
        local chunk = assert((loadstring or load)(body, "BlizzMinimapOnly"))
        if setfenv then setfenv(chunk, env) end
        chunk()
        return env.Nx.Map:BlizzMinimapOnly()
    end

    it("lê a opção do perfil", function()
        expect(only({ MiniMap = { BlizzOnly = true } })).toBe(true)
        expect(only({ MiniMap = { BlizzOnly = false } })).toBe(false)
    end)

    it("sem perfil carregado, fica desligada", function()
        expect(only(nil)).toBe(false)
    end)
end)

-- With the LibDBIcon button standing in for the launcher, refreshing the
-- minimap buttons must not bring the launcher back as a second button.
describe("MiniMap:ApplyButtonVisibility com LibDBIcon", function()
    local function frame()
        local f = { shown = true }
        function f:Show() self.shown = true end
        function f:Hide() self.shown = false end
        return f
    end

    local function run(showCarb, withDBIcon)
        local env = wow.lenientEnv()
        env.Carbonite.Compat = { Expansion = {} }
        loader.run(env, "Carbonite/Modules/Map/MiniMap.lua")
        local launcher = frame()
        local icon = { visible = true }
        function icon:Show(name) self.visible = name == "Carbonite" end
        function icon:Hide(name) if name == "Carbonite" then self.visible = false end end
        env.NXMiniMapBut = launcher
        env.MinimapCluster, env.GameTimeFrame, env.TimeManagerClockButton = nil, nil, nil
        env.MiniMapWorldMapButton, env.LFGMinimapFrame = nil, nil
        env.Nx = {
            db = { profile = { MiniMap = { ButShowCarb = showCarb } } },
            NXMiniMapBut = { DBIcon = withDBIcon and icon or nil },
        }
        env.Carbonite.Modules.Map.MiniMap:ApplyButtonVisibility()
        return launcher.shown, icon.visible
    end

    it("mantém o lançador escondido e mostra o botão do LibDBIcon", function()
        local launcher, icon = run(true, true)
        expect(launcher).toBe(false)
        expect(icon).toBe(true)
    end)

    it("a opção desligada esconde o botão do LibDBIcon", function()
        local launcher, icon = run(false, true)
        expect(launcher).toBe(false)
        expect(icon).toBe(false)
    end)

    it("sem LibDBIcon, o lançador segue a opção", function()
        local launcher = run(true, false)
        expect(launcher).toBe(true)
    end)
end)
