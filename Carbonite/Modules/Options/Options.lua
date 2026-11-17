-- Carbonite | Modules / Options
-- New owner of option-page registration. Replaces the boilerplate
-- around AceConfig that was scattered through NxOptions.lua /
-- Nx:SetupConfig / Nx:AddToConfig.
--
-- Modules now register their own options via this module:
--
--   Carbonite.Modules.Options:Register("Map", function()
--     return { type = "group", args = { ... } }
--   end, { displayName = "Maps", order = 2 })
--
-- Underneath we still call AceConfig + AceConfigDialog, but the
-- caller does not have to know that and we get a single place to
-- inject our profile tab, About tab, etc.

local Carbonite = _G.Carbonite
local Module = Carbonite.Core.Module

local AceConfig       = LibStub("AceConfig-3.0")
local AceConfigReg    = LibStub("AceConfigRegistry-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDBOptions    = LibStub("AceDBOptions-3.0")
local L               = LibStub("AceLocale-3.0"):GetLocale("Carbonite")

local Options = Module:New("Options", {
    defaults = {
        profile = {
            Options = {
                LastOpenedPanel = nil,
            },
        },
    },
})

-- Internal registry. Key = stable id ("Map", "Quests"); value =
-- { provider = fn, displayName = string, order = number }.
local registry = {}

local function unavailableGroup(name, reason)
    return {
        type = "group",
        name = name,
        args = {
            unavailable = {
                type = "description",
                name = L["These settings are not available yet. Reopen the options window after Carbonite finishes loading."] .. "\n\n"
                    .. tostring(reason or L["The options provider did not return a settings group."]),
                order = 1,
                width = "full",
            },
        },
    }
end

-- AceGUI cuts a slider label at the widget width, so a normal-width
-- slider shows "Watch Delay Ti...". Double width fits every label.
local function widenSliders(group)
    for _, opt in pairs(group.args) do
        if opt.type == "range" and (opt.width == nil or opt.width == "normal") then
            opt.width = "double"
        elseif opt.type == "group" then
            widenSliders(opt)
        end
    end
end

-------------------------------------------------------------------------------
-- BASIC AND ADVANCED MODES (#64)
-- The basic mode, the default, shows only the most used options. The
-- "Show advanced options" switch at the top of each page reveals the rest.
-- Only the `hidden` field of the options changes; no saved key does.
-------------------------------------------------------------------------------

-- Order and name of each section, grouped by task: map and navigation,
-- quests, gathering, the module windows, then look and feel.
local LAYOUT = {
    Main                 = { order = 0,  name = L["About"] },
    General              = { order = 1,  name = L["General"] },
    Maps                 = { order = 10, name = L["Map and Minimap"] },
    ["Tracking HUD"]     = { order = 15, name = L["Navigation Arrow (HUD)"] },
    ["Quest Module"]     = { order = 20, name = L["Quests"] },
    ["Guide & Gather"]   = { order = 30, name = L["Guide and Gathering"] },
    ["Notes Module"]     = { order = 40, name = L["Notes and Integrations"] },
    ["Warehouse Module"] = { order = 45, name = L["Warehouse"] },
    ["Info Module"]      = { order = 50, name = L["Info Windows"] },
    Battlegrounds        = { order = 55, name = L["Battlegrounds"] },
    Skin                 = { order = 60, name = L["Appearance"] },
    Fonts                = { order = 62, name = L["Fonts"] },
    Menus                = { order = 65, name = L["Menus"] },
    Privacy              = { order = 70, name = L["Privacy"] },
}

-- Options of the basic mode, as paths inside each section. A group path
-- keeps the whole group. A section listed with no paths only appears in the
-- advanced mode; a section not listed (About, Privacy, plugins) never hides.
local BASIC = {
    General = { "loginMsg", "maxCamera", "hideGriff" },
    Maps = {
        "mainMap.maxMap", "mainMap.hidecombat", "mainMap.useRoute", "mainMap.showTrail",
        "mainMap.showToolBar", "mainMap.showTitleXY", "mainMap.showPOI",
        "miniMap.MMOwn", "miniMap.MMDockAlways", "miniMap.MMIconScale",
        "buttonFrame.MMButOwn", "buttonFrame.MMButShowCarb", "view3d.View3D",
    },
    ["Tracking HUD"] = {
        "hideHUD", "hideLock", "ArrowSize", "showText", "autotaxi", "autocorpse", "emutomtom", "blizzardpin",
    },
    ["Quest Module"] = {
        "quest.qtool", "quest.qauto", "quest.qautoturn", "quest.qobjareas", "quest.qiconscale",
        "watch.qwhide", "watch.qwlock", "watch.qwautonew", "watch.qwremovecomplete", "watch.qwshowdist",
        "watch.qwhideblizz", "watch.QuestWatchFontSize", "sounds.sndEnable",
    },
    ["Guide & Gather"] = { "gatherOpts.gatherEnable" },
    ["Notes Module"] = { "notemap", "handy", "rarescanner", "questie", "questieSE", "rxp", "gatherlite", "tomtomarrow" },
    ["Warehouse Module"] = {
        "main.toolTip", "main.showGold", "seller.greys.sellgreys", "repair.autorepair", "repair.guildrepair",
    },
    ["Info Module"] = { "InfoLock", "KillIconsEnable" },
    Skin = { "SkinSelect" },
    Fonts = { "MediumFontSize", "MapFontSize" },
    Battlegrounds = {},
    Menus = {},
}

-- Same lists as sets of paths.
local basicSets = {}
for id, paths in pairs(BASIC) do
    local set = {}
    for _, path in ipairs(paths) do set[path] = true end
    basicSets[id] = set
end

-- Without a saved-variable database yet, the choice lasts for the session.
local session = {}

local function savedOptions()
    local profile = Carbonite.db and Carbonite.db.profile
    if not profile then return session end
    profile.Options = profile.Options or {}
    return profile.Options
end

local function showAdvanced()
    return savedOptions().ShowAdvanced == true
end

-- The hidden function this module put on each option, to wrap it only once.
local wrappers = setmetatable({}, { __mode = "k" })

-- Hide `opt` in the basic mode, keeping its own hidden rule for the advanced one.
local function hideInBasic(opt)
    if wrappers[opt] and opt.hidden == wrappers[opt] then return end
    local original = opt.hidden
    local function hidden(info, ...)
        if not showAdvanced() then return true end
        if type(original) == "function" then return original(info, ...) end
        if type(original) == "string" then
            local handler = info and info.handler
            return handler and handler[original](handler, info, ...)
        end
        return original
    end
    wrappers[opt] = hidden
    opt.hidden = hidden
end

-- Switch at the top of every section that has advanced options.
local advancedToggle = {
    order = 0,
    type = "toggle",
    width = "full",
    name = L["Show advanced options"],
    desc = L["Shows every Carbonite setting. When off, each page shows only the most used ones."],
    get = function() return showAdvanced() end,
    set = function(_, value)
        savedOptions().ShowAdvanced = value and true or nil
        AceConfigReg:NotifyChange("Carbonite")
    end,
}

local function orderOf(opt)
    return type(opt.order) == "number" and opt.order or 100
end

local function decorative(opt)
    return opt.type == "header" or opt.type == "description"
end

-- Hide in the basic mode what `set` does not list under `group`. Returns true
-- when the group keeps at least one option in the basic mode.
local function applyBasic(group, set, prefix)
    local keys = {}
    for key in pairs(group.args) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b)
        local oa, ob = orderOf(group.args[a]), orderOf(group.args[b])
        if oa ~= ob then return oa < ob end
        return a < b
    end)

    local basic, any = {}, false
    for _, key in ipairs(keys) do
        local opt, path = group.args[key], prefix .. key
        if opt == advancedToggle then
            basic[key] = true
        else
            if set[path] then
                basic[key] = true
            elseif opt.type == "group" then
                basic[key] = applyBasic(opt, set, path .. ".")
            elseif not decorative(opt) then
                basic[key] = false
            end
            any = any or basic[key] == true
        end
    end

    -- A header stays when an option of its block stays; a spacer stays
    -- before an option that stays.
    for i, key in ipairs(keys) do
        local opt = group.args[key]
        if decorative(opt) and not set[prefix .. key] then
            local keep = false
            for j = i + 1, #keys do
                local nextOpt = group.args[keys[j]]
                if nextOpt.type == "header" then break end
                if not decorative(nextOpt) then
                    keep = keep or basic[keys[j]]
                    if opt.type == "description" then break end
                end
            end
            basic[key] = keep
        end
    end

    for key, keep in pairs(basic) do
        if not keep then hideInBasic(group.args[key]) end
    end
    return any
end

-- Root group: built lazily each time AceConfig asks for the table so
-- providers registered after OnEnable (e.g. by plugins loaded later)
-- still appear. The legacy NxOptions section provides a "Main" tab
-- with version blurb and credits; if no module has registered "Main"
-- by the time the panel opens, a small default About tab is rendered
-- instead.
local function buildRootGroup()
    local args = {}
    if not registry["Main"] then
        args.about = {
            order = 0,
            type  = "group",
            name  = L["About"],
            args  = {
                blurb = {
                    type = "description",
                    name = ("|cffc0c0ffCarbonite-Forever|r  -  %s |cffd700ff%s|r\n\n%s\n")
                            :format(L["Version"], Carbonite.VERSION_STRING or "dev",
                                L["Full featured map and questing addon."]),
                    order = 1,
                },
            },
        }
    end

    -- Sort by user-supplied order then displayName for stability.
    local ids = {}
    for id in pairs(registry) do ids[#ids + 1] = id end
    table.sort(ids, function(a, b)
        local ra, rb = registry[a], registry[b]
        if ra.order ~= rb.order then return (ra.order or 100) < (rb.order or 100) end
        return (ra.displayName or a) < (rb.displayName or b)
    end)

    for _, id in ipairs(ids) do
        local entry = registry[id]
        local ok, table_ = pcall(entry.provider)
        if not ok or type(table_) ~= "table" or table_.type ~= "group"
            or type(table_.args) ~= "table" then
            local reason = ok and L["The options provider returned an invalid settings group."] or table_
            table_ = unavailableGroup(entry.displayName or id, reason)
            if Carbonite.Core.Logger then
                pcall(function()
                    Carbonite.Core.Logger:Get("Options"):error("provider for %s failed: %s", id, tostring(reason))
                end)
            end
        end
        widenSliders(table_)
        local layout = LAYOUT[id] or {}
        args[id] = table_
        args[id].order = layout.order or entry.order or 100
        args[id].name  = layout.name or entry.displayName or id
        local set = basicSets[id]
        if set and table_.args.unavailable == nil then
            table_.args.showAdvanced = advancedToggle
            if not applyBasic(table_, set, "") then hideInBasic(table_) end
        end
    end

    -- Profiles options should not prevent every other category from rendering
    -- if the saved-variable database has not completed initialization yet.
    if Carbonite.db then
        local ok, profiles = pcall(AceDBOptions.GetOptionsTable, AceDBOptions, Carbonite.db)
        args.profiles = ok and type(profiles) == "table" and profiles
            or unavailableGroup(L["Profiles"], profiles)
        args.profiles.order = 1000
    end

    return {
        type = "group",
        name = "Carbonite-Forever",
        -- Top-level sections must stay in AceGUI's scrollable navigation tree.
        -- Tabs remain available inside individual sections where appropriate.
        childGroups = "tree",
        args = args,
    }
end

function Options:Register(id, provider, opts)
    opts = opts or {}
    if type(provider) ~= "function" then
        local table_ = provider
        provider = function() return table_ end
    end
    registry[id] = {
        provider    = provider,
        displayName = opts.displayName or id,
        order       = opts.order or 100,
    }

    -- The Blizzard category can already exist when legacy or plugin sections
    -- register. Invalidate AceConfig's cached root so a panel opened during
    -- early startup cannot remain stuck with an empty options table.
    if self._rootRegistered then
        AceConfigReg:NotifyChange("Carbonite")
    end
end

function Options:Open(panelId)
    if self._rootRegistered then
        self:Refresh()
    end
    AceConfigDialog:Open("Carbonite")
    if panelId then
        AceConfigDialog:SelectGroup("Carbonite", panelId)
    end
end

function Options:Refresh()
    AceConfigReg:NotifyChange("Carbonite")
end

-- Basic mode (false, the default) or advanced mode (true).
function Options:ShowAdvanced()
    return showAdvanced()
end

function Options:SetShowAdvanced(value)
    advancedToggle.set(nil, value)
end

function Options:OnEnable()
    AceConfig:RegisterOptionsTable("Carbonite", buildRootGroup)
    self._rootRegistered = true
    self.frame, self.panelID = AceConfigDialog:AddToBlizOptions("Carbonite", "Carbonite-Forever")

    -- The AceConfigDialog default (700 wide) is too narrow for the
    -- multi-control rows on the font pages. Widen the default ONCE here;
    -- SetDefaultSize overwrites the status size, so it must not run on
    -- every Open or it would clobber the user's manual resize (which
    -- AceConfigDialog otherwise remembers across opens).
    if AceConfigDialog.SetDefaultSize then
        AceConfigDialog:SetDefaultSize("Carbonite", 960, 600)
    end

    Carbonite.Core.SlashCommands:Register("options", function() self:Open() end, "open options panel")

    -- Mirror onto legacy namespace so old `Nx.Opts:Open` calls keep
    -- working until those callers are migrated.
    Carbonite.Opts = Carbonite.Opts or {}
    Carbonite.Opts.Open    = function(_, panel) self:Open(panel) end
    Carbonite.Opts.Refresh = function() self:Refresh() end

    -- Providers may have registered before this module was enabled. Force the
    -- first Blizzard-panel render to query the complete live registry.
    self:Refresh()
end
