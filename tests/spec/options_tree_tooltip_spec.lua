-- Options side menu without the name tooltip over the tabs (#96)

local function setup()
    local env = wow.lenientEnv()
    local mod = {}
    local hooks = {}
    local tip = { shown = true }
    function tip:Hide() self.shown = false end
    local dialog = { OpenFrames = {}, tooltip = tip }
    env.Carbonite.Core.Module = { New = function() return mod end }
    env.Carbonite.Core.SlashCommands = { Register = function() end }
    env.hooksecurefunc = function(t, name, fn) hooks[#hooks + 1] = { t = t, name = name, fn = fn } end
    env.LibStub = function(name)
        if name == "AceConfigDialog-3.0" then
            return dialog
        elseif name == "AceLocale-3.0" then
            local locale = setmetatable({}, { __index = function(_, k) return k end })
            return { GetLocale = function() return locale end }
        end
        return wow.anything()
    end
    loader.run(env, "Carbonite/Modules/Options/Options.lua")
    return mod, dialog, tip, hooks
end

local function tree()
    local t = { type = "TreeGroup", events = {} }
    function t:SetCallback(name, fn) self.events[name] = fn end
    t.events.OnButtonEnter = function() error("tooltip shown") end
    return t
end

describe("menu lateral das Opções", function()
    it("tira o tooltip do nome dos itens da árvore do Carbonite", function()
        local mod, dialog, tip = setup()
        local t = tree()
        dialog.OpenFrames.Carbonite = { children = { t } }
        mod._QuietTree("Carbonite")
        t.events.OnButtonEnter()               -- no error: the tooltip is gone
        expect(tip.shown).toBe(false)
    end)

    it("não mexe em janelas de outros addons", function()
        local mod, dialog, tip = setup()
        local t = tree()
        dialog.OpenFrames.Outro = { children = { t } }
        mod._QuietTree("Outro")
        expect(tip.shown).toBe(true)
        expect(pcall(t.events.OnButtonEnter)).toBe(false)
    end)

    it("vale também quando o AceConfigDialog reabre a janela", function()
        local src = loader.read("Carbonite/Modules/Options/Options.lua")
        expect(src:find('hooksecurefunc(AceConfigDialog, "Open", function(_, appName) QuietTree(appName) end)', 1, true) ~= nil).toBe(true)
    end)
end)
