-- Basic and advanced modes of the options (#64)

-- Builds the options panel as AceConfig gets it, with the real sections of
-- Carbonite, Quests, Notes and Warehouse. Returns the root group, the Options
-- module, the section tables as the providers gave them and the saved data.
local function panel()
    local env = wow.lenientEnv()
    local mod, build = {}, nil
    local db = { profile = {} }
    env.Carbonite.db = db
    env.Carbonite.Core.Module = { New = function() return mod end }
    env.Carbonite.Core.SlashCommands = { Register = function() end }
    env.Carbonite.GetModule = function() return mod end
    env.LibStub = function(name)
        if name == "AceConfig-3.0" then
            return { RegisterOptionsTable = function(_, _, fn) build = fn end }
        elseif name == "AceLocale-3.0" then
            local locale = setmetatable({}, { __index = function(_, k) return k end })
            return { GetLocale = function() return locale end }
        end
        return wow.anything()
    end
    env.Nx = wow.namespace({
        Opts = {}, VERMAJOR = 1, VERMINOR = 0, BUILD = 1, MaxPlayerLevel = 80,
        MapProfiler = false, QuestProfiler = false,
    })
    loader.run(env, "Carbonite/Modules/Options/Options.lua")
    local sections = {}
    local register = mod.Register
    mod.Register = function(self, id, provider, opts)
        sections[id] = type(provider) == "function" and provider() or provider
        return register(self, id, provider, opts)
    end
    loader.run(env, "Carbonite/Modules/Options/OptionsEngine.lua")
    for _, path in ipairs({ "Carbonite.Quests/Options.lua", "Carbonite.Notes/Options.lua",
                            "Carbonite.Warehouse/Options.lua" }) do
        loader.run(env, path)
    end
    local Nx = env.Nx
    Nx:SetupConfig()
    Nx:AddToConfig("Quest Module", Nx.Quest:GetOptionsConfig(), "Quest Module")
    Nx:AddToConfig("Notes Module", Nx.Notes:GetOptionsConfig(), "Notes Module")
    Nx:AddToConfig("Warehouse Module", Nx.Warehouse:GetOptionsConfig(), "Warehouse Module")
    mod:OnEnable()
    return build, mod, sections, db
end

local function isHidden(opt)
    local h = opt.hidden
    if type(h) == "function" then return h({}) == true end
    return h == true
end

-- Calls fn(path, opt, visible) for every option under group.
local function walk(group, path, visible, fn)
    for key, opt in pairs(group.args) do
        local p = path .. "." .. key
        local v = visible and not isHidden(opt)
        fn(p, opt, v)
        if opt.type == "group" then walk(opt, p, v, fn) end
    end
end

local function control(opt)
    return opt.type ~= "group" and opt.type ~= "header" and opt.type ~= "description"
end

-- Basic paths as "Section.path", plus the groups and sections above them.
local BASIC = {
    "General.loginMsg", "Maps.mainMap.maxMap", "Maps.miniMap.MMOwn", "Tracking HUD.hideHUD",
    "Quest Module.watch.qwhide", "Quest Module.sounds.sndEnable", "Guide & Gather.gatherOpts.gatherEnable",
    "Notes Module.questie", "Warehouse Module.repair.autorepair",
    "Warehouse Module.seller.greys.sellgreys", "Skin.SkinSelect", "Fonts.MapFontSize",
}

local ADVANCED = {
    "General.chatWindow", "Maps.mapScale", "Maps.mapAlpha", "Maps.mainMap.ButR", "Fonts.SmallFont",
    "Menus", "Battlegrounds", "Quest Module.database", "Quest Module.quest.qcol1",
    "Guide & Gather.gatherOpts.CmdDelHerb", "Guide & Gather.HerbDisp", "Notes Module.handysize", "Warehouse Module.seller.whites",
    "Skin.skinBord", "Tracking HUD.AXO",
}

local function visibility(root)
    local out = {}
    walk(root, "", true, function(path, opt, visible) out[path:sub(2)] = { opt = opt, visible = visible } end)
    return out
end

describe("modo básico das Opções", function()
    it("é o padrão e esconde as opções avançadas", function()
        local build, mod = panel()
        expect(mod:ShowAdvanced()).toBe(false)
        local seen = visibility(build())
        for _, path in ipairs(BASIC) do
            expect(seen[path] and seen[path].visible and path or "oculta: " .. path).toBe(path)
        end
        for _, path in ipairs(ADVANCED) do
            expect(seen[path] and not seen[path].visible and path or "visível: " .. path).toBe(path)
        end
    end)

    it("mostra no máximo um quarto dos controles", function()
        local build, mod = panel()
        local function count()
            local n = 0
            for _, s in pairs(visibility(build())) do
                if control(s.opt) and s.visible then n = n + 1 end
            end
            return n
        end
        local shown = count()
        mod:SetShowAdvanced(true)
        local total = count()
        expect(shown > 30).toBe(true)
        expect(shown * 4 < total).toBe(true)
    end)

    it("cada caminho da lista básica existe", function()
        local build = panel()
        local seen = visibility(build())
        local src = loader.read("Carbonite/Modules/Options/Options.lua")
        local list = src:match("local BASIC = (%b{})")
        for section, paths in list:gmatch('%[?"?([%w &]+)"?%]?%s*=%s*(%b{})') do
            section = section:match("^%s*(.-)%s*$")
            for path in paths:gmatch('"([^"]+)"') do
                local full = section .. "." .. path
                if section == "Info Module" then
                    expect(loader.read("Carbonite.Info/NxInfo.lua"):find(path .. " = {", 1, true) ~= nil).toBe(true)
                else
                    expect(seen[full] and full or "não existe: " .. full).toBe(full)
                end
            end
        end
    end)

    it("o interruptor de avançadas fica no topo de cada seção simplificada", function()
        local build = panel()
        local root = build()
        for _, id in ipairs({ "General", "Maps", "Quest Module", "Notes Module", "Warehouse Module", "Menus" }) do
            local toggle = root.args[id].args.showAdvanced
            expect(toggle and toggle.type).toBe("toggle")
            expect(toggle.order).toBe(0)
            expect(toggle.name).toBe("Show advanced options")
        end
        expect(root.args.Privacy.args.showAdvanced).toBeNil()
        expect(root.args.Main.args.showAdvanced).toBeNil()
    end)
end)

describe("modo avançado das Opções", function()
    it("o interruptor mostra tudo que cada opção já mostrava", function()
        local build, mod, sections = panel()
        local before = {}
        for id, section in pairs(sections) do
            walk(section, id, true, function(path, _, visible) before[path] = visible end)
        end
        local root = build()
        root.args.General.args.showAdvanced.set(nil, true)
        expect(mod:ShowAdvanced()).toBe(true)
        local seen = visibility(build())
        local wrong = {}
        for path, visible in pairs(before) do
            if seen[path] and seen[path].visible ~= visible then wrong[#wrong + 1] = path end
        end
        expect(table.concat(wrong, ", ")).toBe("")
    end)

    it("desligar volta ao modo básico", function()
        local build, mod = panel()
        mod:SetShowAdvanced(true)
        expect(visibility(build())["Maps.mapScale"].visible).toBe(true)
        mod:SetShowAdvanced(false)
        expect(visibility(build())["Maps.mapScale"].visible).toBe(false)
    end)
end)

describe("chaves salvas", function()
    it("nenhuma opção troca get ou set e o interruptor só grava Options.ShowAdvanced", function()
        local build, mod, sections, db = panel()
        local before = {}
        for id, section in pairs(sections) do
            walk(section, id, true, function(path, opt) before[path] = { opt.get, opt.set } end)
        end
        build()
        mod:SetShowAdvanced(true)
        build()
        local seen = visibility(build())
        for path, fns in pairs(before) do
            if seen[path] then
                expect(seen[path].opt.get == fns[1] and seen[path].opt.set == fns[2]).toBe(true)
            end
        end
        local keys = {}
        for k in pairs(db.profile) do keys[#keys + 1] = k end
        expect(table.concat(keys, ",")).toBe("Options")
        local saved = {}
        for k, v in pairs(db.profile.Options) do saved[#saved + 1] = k .. "=" .. tostring(v) end
        expect(table.concat(saved, ",")).toBe("ShowAdvanced=true")
    end)
end)

describe("organização das Opções", function()
    it("ordena as seções por tarefa com nomes claros", function()
        local build = panel()
        local root = build()
        local order = { "Main", "General", "Maps", "Tracking HUD", "Quest Module", "Guide & Gather",
                        "Notes Module", "Warehouse Module", "Battlegrounds", "Skin", "Fonts", "Menus", "Privacy" }
        for i = 2, #order do
            expect(root.args[order[i - 1]].order < root.args[order[i]].order).toBe(true)
        end
        expect(root.args.Main.name).toBe("About")
        expect(root.args.Maps.name).toBe("Map and Minimap")
        expect(root.args["Quest Module"].name).toBe("Quests")
        expect(root.args.Skin.name).toBe("Appearance")
    end)

    it("toda opção tem uma descrição", function()
        local build = panel()
        local missing = {}
        for path, s in pairs(visibility(build())) do
            if control(s.opt) and not s.opt.desc then missing[#missing + 1] = path end
        end
        table.sort(missing)
        expect(table.concat(missing, ", ")).toBe("")
    end)

    it("sliders de escala, transparência e raio mostram a unidade", function()
        local build = panel()
        local maps = build().args.Maps.args
        for _, tab in ipairs({ "mapScale", "mapAlpha", "mapRoute" }) do
            for key, opt in pairs(maps[tab].args) do
                if opt.type == "range" and key ~= "InstanceScale" then
                    local unit = opt.isPercent or opt.name:find("(", 1, true) ~= nil
                    expect(unit and key or "sem unidade: " .. key).toBe(key)
                end
            end
        end
    end)
end)
