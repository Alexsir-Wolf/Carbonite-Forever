-- Locale files: each key defined once per namespace (#53)

local CORE = { "Bindings", "Com", "FlightMasters", "Guide", "HarvestNodes", "Main", "Map", "Options", "Zones" }
local MODULES = { "Carbonite.Quests", "Carbonite.Notes", "Carbonite.Info", "Carbonite.Warehouse" }

-- Each namespace with the files that fill it, for one locale.
local function namespaces(locale)
    local list = {}
    local core = {}
    for _, name in ipairs(CORE) do core[#core + 1] = "Carbonite/Locales/" .. locale .. "/" .. name .. ".lua" end
    list[#list + 1] = core
    for _, mod in ipairs(MODULES) do list[#list + 1] = { mod .. "/Locales/" .. locale .. ".lua" } end
    return list
end

-- Keys defined more than once across the files, as "key (file, file)".
local function repeated(files)
    local where, out = {}, {}
    for _, path in ipairs(files) do
        for line in loader.read(path):gmatch("[^\n]+") do
            local key = line:match('^%s*L%[(".*")%]%s*=')
            if key then
                if where[key] then out[#out + 1] = key .. " (" .. where[key] .. ", " .. path .. ")" end
                where[key] = where[key] or path
            end
        end
    end
    return out
end

for _, locale in ipairs({ "ptBR", "enUS" }) do
    describe("locale " .. locale, function()
        it("não repete chaves", function()
            for _, files in ipairs(namespaces(locale)) do
                local dups = repeated(files)
                expect(#dups == 0 and "" or table.concat(dups, "; ")).toBe("")
            end
        end)
    end)
end
