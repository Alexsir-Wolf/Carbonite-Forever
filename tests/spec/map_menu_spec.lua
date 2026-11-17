-- Map right-click menu: at most 15 entries, no sliders; the sliders live in the Options (#60)

local ENGINE = "Carbonite/Modules/Map/MapEngine.lua"

-- Source of the main map menu: its block in Nx.Map:Create and the debug submenu.
local function menuSource()
    local src = loader.read(ENGINE)
    local first = src:find("-- MAIN CONTEXT MENU", 1, true)
    local last = src:find("-- PLAYER ICON CONTEXT MENU", first, true)
    local debugStart = src:find("function Nx.Map:CreateDebugMenu", 1, true)
    local debugEnd = src:find("\nend", debugStart, true)
    return src:sub(first, last), src:sub(debugStart, debugEnd)
end

-- Entries added to the main menu itself (not to its submenus).
local function mainEntries(code)
    local n = 0
    for _ in code:gmatch("%f[%w_]menu:Add%a+%(") do n = n + 1 end
    for _ in code:gmatch("DungeonChart:AddMenu%(") do n = n + 1 end
    return n
end

describe("menu do botão direito do mapa", function()
    local block, debugMenu = menuSource()

    it("tem no máximo 15 itens, contando o submenu de debug", function()
        local n = mainEntries(block) + mainEntries(debugMenu)
        expect(n > 0).toBe(true)
        expect(n <= 15).toBe(true)
    end)

    it("não tem sliders no menu nem nos submenus do dia a dia", function()
        expect(block:find("SetSlider", 1, true)).toBeNil()
        expect(block:find('L["Scale..."]', 1, true)).toBeNil()
        expect(block:find('L["Transparency..."]', 1, true)).toBeNil()
        expect(block:find('L["Instance Scale..."]', 1, true)).toBeNil()
    end)

    it("mantém Ir para, Limpar destino, Mostrar... e Opções...", function()
        for _, key in ipairs({ 'L["Goto"]', 'L["Clear Goto"]', 'L["Show..."]', 'L["Route..."]',
                               'L["Options..."]', 'L["Minimap Full Size"]', 'L["Select Cities Last"]' }) do
            expect(block:find(key, 1, true) ~= nil).toBe(true)
        end
    end)
end)

-- Builds the Maps page of the Options with a fake db and main map.
local function mapsPage(free)
    local env = wow.lenientEnv()
    local providers = {}
    env.Carbonite.GetModule = function()
        return { Register = function(_, name, fn) providers[name] = fn end }
    end
    local refreshed = 0
    local map = {
        DotZoneScale = 1, DotPalScale = 1, DotPartyScale = 1, DotRaidScale = 1,
        IconScale = 3, IconNavScale = 1, BackgndAlphaFull = 1, BackgndAlphaFade = .4,
        ArchAlpha = .3, QuestAlpha = .3,
        Guide = { UpdateGatherFolders = function() refreshed = refreshed + 1 end },
    }
    local db = { profile = { MapSettings = {}, Map = {}, Route = {}, MiniMap = {} }, char = {} }
    env.Nx = wow.namespace({
        Opts = {}, db = db, Free = free,
        Map = wow.namespace({ Maps = { map }, GetMap = function(self, i) return self.Maps[i] end }),
    })
    loader.run(env, "Carbonite/Modules/Options/OptionsEngine.lua")
    env.Nx:SetupConfig()
    return providers.Maps(), db, map, function() return refreshed end
end

-- Every slider that left the menu: Options tab, option, saved table, key, range.
local MOVED = {
    { "mapScale", "AutoScaleMin", "MapSettings", "NXAutoScaleMin", .01, 10 },
    { "mapScale", "AutoScaleMax", "MapSettings", "NXAutoScaleMax", .25, 10 },
    { "mapScale", "DotZoneScale", "MapSettings", "NXDotZoneScale", .1, 10, "DotZoneScale" },
    { "mapScale", "DotPalScale", "MapSettings", "NXDotPalScale", .1, 10, "DotPalScale" },
    { "mapScale", "DotPartyScale", "MapSettings", "NXDotPartyScale", .1, 10, "DotPartyScale" },
    { "mapScale", "DotRaidScale", "MapSettings", "NXDotRaidScale", .1, 10, "DotRaidScale" },
    { "mapScale", "IconScale", "MapSettings", "NXIconScale", .1, 10, "IconScale" },
    { "mapScale", "IconNavScale", "MapSettings", "NXIconNavScale", .1, 10, "IconNavScale" },
    { "mapScale", "DetailScale", "MapSettings", "NXDetailScale", .05, 10 },
    { "mapScale", "IconGatherAtScale", "Map", "IconGatherAtScale", .01, 10 },
    { "mapScale", "POIAtScale", "MapSettings", "NXPOIAtScale", .1, 10 },
    { "mapScale", "InstancePlayerSize", "Map", "InstancePlayerSize", 1, 50 },
    { "mapScale", "InstanceGroupSize", "Map", "InstanceGroupSize", 1, 50 },
    { "mapScale", "InstanceBossSize", "Map", "InstanceBossSize", 1, 50 },
    { "mapScale", "InstanceScale", "Map", "InstanceScale", 1, 50 },
    { "mapAlpha", "DetailAlpha", "MapSettings", "NXDetailAlpha", .25, 1 },
    { "mapAlpha", "BackgndAlphaFull", "MapSettings", "NXBackgndAlphaFull", .25, 1, "BackgndAlphaFull" },
    { "mapAlpha", "BackgndAlphaFade", "MapSettings", "NXBackgndAlphaFade", 0, 1, "BackgndAlphaFade" },
    { "mapAlpha", "IconGatherA", "Map", "IconGatherA", .2, 1 },
    { "mapAlpha", "IconPOIAlpha", "Map", "IconPOIAlpha", .2, 1 },
    { "mapAlpha", "UnexploredAlpha", "MapSettings", "NXUnexploredAlpha", 0, .9 },
    { "mapAlpha", "ArchAlpha", "MapSettings", "NXArchAlpha", 0, 1, "ArchAlpha" },
    { "mapAlpha", "QuestAlpha", "MapSettings", "NXQuestAlpha", 0, 1, "QuestAlpha" },
    { "mapRoute", "GatherRadius", "Route", "GatherRadius", 7, 300 },
    { "mapRoute", "MergeRadius", "Route", "MergeRadius", 0, 100 },
    { "miniMap", "MMAlpha", "MapSettings", "NXMMAlpha", 0, 1 },
    { "miniMap", "MMDockScale", "MapSettings", "NXMMDockScale", .01, 3 },
    { "miniMap", "MMDockScaleBG", "MapSettings", "NXMMDockScaleBG", .01, 3 },
    { "miniMap", "MMDockAlpha", "MapSettings", "NXMMDockAlpha", 0, 1 },
    { "miniMap", "MMDockOnAtScale", "MapSettings", "NXMMDockOnAtScale", 0, 5 },
}

describe("sliders do menu do mapa nas Opções", function()
    it("cada um existe com a mesma faixa e salva na mesma chave", function()
        local page, db, map = mapsPage(false)
        for _, s in ipairs(MOVED) do
            local tab, name, tbl, key, min, max, field = s[1], s[2], s[3], s[4], s[5], s[6], s[7]
            local opt = page.args[tab] and page.args[tab].args[name]
            expect(opt ~= nil and opt.type or name).toBe("range")
            expect(opt.min).toBe(min)
            expect(opt.max).toBe(max)
            opt.set(nil, max)
            expect(db.profile[tbl][key]).toBe(max)
            if field then expect(map[field]).toBe(max) end
            expect(opt.get()).toBe(max)
        end
    end)

    it("cada chave que o menu salvava aparece no código das Opções", function()
        local opts = loader.read("Carbonite/Modules/Options/OptionsEngine.lua")
        for _, s in ipairs(MOVED) do
            expect(opts:find('"' .. s[4] .. '"', 1, true) ~= nil).toBe(true)
        end
    end)

    it("repetem a atualização que o menu fazia", function()
        local page, _, map, refreshed = mapsPage(false)
        page.args.miniMap.args.MMDockScale.set(nil, 1)
        expect(map.MMZoomChanged).toBe(true)
        map.MMZoomChanged = nil
        page.args.miniMap.args.MMDockScaleBG.set(nil, 1)
        expect(map.MMZoomChanged).toBe(true)
        page.args.mapAlpha.args.IconGatherA.set(nil, .5)
        expect(refreshed()).toBe(1)
    end)

    it("os do minimapa ficam ocultos na edição sem minimapa, como no menu", function()
        local page = mapsPage(true)
        expect(page.args.miniMap.args.MMAlpha.hidden()).toBe(true)
        expect(page.args.miniMap.args.MMDockOnAtScale.hidden()).toBe(true)
    end)
end)
