-- Níveis, voos, entradas e pedras de encontro das zonas e masmorras do Forever (#244)

local function locale()
    return { GetLocale = function()
        return setmetatable({}, { __index = function(_, k) return k end })
    end }
end

local function loadZones()
    local env = wow.lenientEnv()
    env.Nx = {}
    env.LibStub = locale
    loader.run(env, "Carbonite/Data/camelot/Zones.lua")
    return env.Nx
end

local function field(row, n)
    local parts = {}
    for part in (row .. "|"):gmatch("([^|]*)|") do parts[#parts + 1] = part end
    return parts[n]
end

describe("níveis das zonas novas (MapUtils)", function()
    local zones = loadZones().Zones
    local cases = {
        { 2482, "60", "60" },  -- Mount Hyjal
        { 2652, "35", "45" },  -- Shen'dralas
        { 2548, "35", "45" },  -- Riverglades
        { 2521, "1", "12" },   -- Zephras Isle
    }
    for _, c in ipairs(cases) do
        it("mapa " .. c[1] .. " vai de " .. c[2] .. " a " .. c[3], function()
            expect(field(zones[c[1]], 2)).toBe(c[2])
            expect(field(zones[c[1]], 3)).toBe(c[3])
        end)
    end
end)

describe("entradas das masmorras novas", function()
    local zones = loadZones().Zones
    local cases = {
        { 2959, "1416", "8.5", "59.3" },   -- City of Dalaran, Alterac
        { 2998, "1437", "47.7", "56.2" },  -- Excavation Site: Wetlands
        { 2999, "1458", "72.2", "11.5" },  -- Ruins of Lordaeron
        { 3065, "1455", "27.9", "47.7" },  -- The Hall of Thanes
        { 2994, "1445", "75.0", "14.7" },  -- Alcaz Prison
        { 3001, "1449", "48.1", "6.1" },   -- The Shaper's Terrace
    }
    for _, c in ipairs(cases) do
        it("masmorra " .. c[1] .. " entra por " .. c[2] .. " " .. c[3] .. ", " .. c[4], function()
            local row = zones[c[1]]
            expect(field(row, 6)).toBe(c[2])
            expect(field(row, 7)).toBe(c[3])
            expect(field(row, 8)).toBe(c[4])
        end)
    end

    it("Dalaran e Ruins of Lordaeron têm a segunda entrada em Silverpine e Tirisfal", function()
        local extra = loadZones().InstanceExtraEntrances
        expect(extra[2959][1][1]).toBe(1421)
        expect(extra[2999][1][1]).toBe(1420)
        expect(extra[2999][1][2]).toBe(63.4)
    end)
end)

describe("segunda entrada no Guia", function()
    local function guide(extra)
        local env = wow.lenientEnv()
        env.Nx = wow.namespace({ InstanceExtraEntrances = extra })
        env.LibStub = locale
        loader.run(env, "Carbonite/Data/Shared/NxMapGuide.lua")
        return env.Nx.Map.Guide
    end

    it("só devolve as entradas do mapa aberto", function()
        local G = guide({ [2959] = { { 1421, 69.2, 45.5 }, { 1416, 1, 1 } } })
        local on = G.ExtraEntrancesOn(2959, 1421)
        expect(#on).toBe(1)
        expect(on[1][2]).toBe(69.2)
        expect(#G.ExtraEntrancesOn(2959, 1453)).toBe(0)
        expect(#G.ExtraEntrancesOn(213, 1421)).toBe(0)
    end)

    it("sem a tabela não quebra", function()
        local G = guide(nil)
        expect(#G.ExtraEntrancesOn(2959, 1421)).toBe(0)
    end)
end)

describe("voos novos do Forever (SPF)", function()
    local function load()
        local env = wow.lenientEnv()
        env.Nx = { GuideData = {}, Split = function(sep, s)
            local out = {}
            for part in (s .. sep):gmatch("(.-)" .. sep:gsub("%p", "%%%0")) do out[#out + 1] = part end
            return unpack(out)
        end }
        env.LibStub = locale
        env.format = string.format
        loader.run(env, "Carbonite/Data/camelot/Guides/FlightMaster.lua")
        return env.Nx
    end

    local function has(nx, needle)
        for _, row in ipairs(nx.NPCData) do
            if row:find(needle, 1, true) then return row end
        end
    end

    it("Rog'mar é da Horda em Riverglades", function()
        local row = has(load(), "Rog'mar, Riverglades")
        expect(row).toBe("2|Horde Flight|Rog'mar, Riverglades|2548|59.6|45.1|0")
    end)

    it("Hyjal tem os dois voos neutros", function()
        local nx = load()
        expect(has(nx, "Summit of Eternity, Mount Hyjal")).toBe("0|Neutral Flight|Summit of Eternity, Mount Hyjal|2482|68.6|44.1|0")
        expect(has(nx, "Tainted Foothills, Mount Hyjal")).toBe("0|Neutral Flight|Tainted Foothills, Mount Hyjal|2482|55.1|82.5|0")
        expect(nx.GuideData["Flight Master"][2482] ~= nil).toBe(true)
    end)

    it("os nomes novos têm chave de tradução", function()
        local src = loader.read("Carbonite/Locales/enUS/FlightMasters.lua")
        for _, name in ipairs({ "Rog'mar, Riverglades", "Summit of Eternity, Mount Hyjal", "Tainted Foothills, Mount Hyjal" }) do
            expect(src:find('L["' .. name .. '"] = true', 1, true) ~= nil).toBe(true)
        end
    end)
end)

describe("pedras de encontro das masmorras novas (MapUtils)", function()
    it("The Drowned City e Excavation Site", function()
        local env = wow.lenientEnv()
        env.Nx = { GuideData = {} }
        env.LibStub = locale
        loader.run(env, "Carbonite/Data/camelot/Guides/MeetingStone.lua")
        local data = env.Nx.GuideData["Meeting Stone"]
        expect(data[1434]:find("0,21.76,27.75", 1, true) ~= nil).toBe(true)
        expect(data[1437]).toBe("0,53.79,65.72")
    end)
end)
