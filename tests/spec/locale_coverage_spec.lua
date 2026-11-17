-- pt-BR coverage: every interface text of enUS has a pt-BR translation (#50).
-- Zones, FlightMasters and HarvestNodes are names from the game client: they are translated
-- where the pt-BR name is known (Questie, GatherLite) and otherwise fall back to English.

local UI = { "Bindings", "Com", "Guide", "Main", "Map", "Options" }
local MODULES = { "Carbonite.Quests", "Carbonite.Notes", "Carbonite.Info", "Carbonite.Warehouse" }

local function keys(files)
    local out = {}
    for _, path in ipairs(files) do
        for line in loader.read(path):gmatch("[^\n]+") do
            local key, value = line:match('^%s*L%["(.*)"%]%s*=%s*(.-)%s*$')
            if key then out[key] = value end
        end
    end
    return out
end

local function untranslated(enFiles, ptFiles)
    local en, pt = keys(enFiles), keys(ptFiles)
    local missing = {}
    for key in pairs(en) do
        local value = pt[key]
        if value == nil or value == "true" then missing[#missing + 1] = key end
    end
    table.sort(missing)
    return table.concat(missing, " | ")
end

describe("tradução pt-BR", function()
    it("cobre todos os textos da interface do Carbonite", function()
        local en, pt = {}, {}
        for _, name in ipairs(UI) do
            en[#en + 1] = "Carbonite/Locales/enUS/" .. name .. ".lua"
            pt[#pt + 1] = "Carbonite/Locales/ptBR/" .. name .. ".lua"
        end
        expect(untranslated(en, pt)).toBe("")
    end)

    for _, mod in ipairs(MODULES) do
        it("cobre todos os textos de " .. mod, function()
            expect(untranslated({ mod .. "/Locales/enUS.lua" }, { mod .. "/Locales/ptBR.lua" })).toBe("")
        end)
    end
end)
