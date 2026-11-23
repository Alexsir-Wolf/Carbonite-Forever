-- Conexões de Hyjal, Shen'dralas, Southshore e portal de Dalaran (#250)

local function connections()
    local env = wow.lenientEnv()
    env.Nx = {}
    env.LibStub = function()
        return { GetLocale = function()
            return setmetatable({}, { __index = function(_, k) return k end })
        end }
    end
    -- The file starts with a UTF-8 BOM, which the game accepts and Lua 5.1 does not.
    local src = loader.read("Carbonite/Data/camelot/ZoneConnections.lua"):gsub("^\239\187\191", "")
    local chunk = assert(loadstring(src, "ZoneConnections.lua"))
    setfenv(chunk, env)
    chunk()
    local out = {}
    for _, row in ipairs(env.Nx.ZoneConnections) do
        local f = {}
        for part in (row .. "|"):gmatch("([^|]*)|") do f[#f + 1] = part end
        out[#out + 1] = {
            flags = tonumber(f[1]), typ = tonumber(f[2]),
            name1 = f[3], z1 = tonumber(f[4]), x1 = tonumber(f[5]), y1 = tonumber(f[6]),
            name2 = f[7], z2 = tonumber(f[8]), x2 = tonumber(f[9]), y2 = tonumber(f[10]),
        }
    end
    return out
end

local function between(list, a, b)
    for _, c in ipairs(list) do
        if (c.z1 == a and c.z2 == b) or (c.z1 == b and c.z2 == a) then return c end
    end
end

describe("Hyjal e Shen'dralas a pé", function()
    local list = connections()
    local cases = {
        { 2482, 1448 }, { 2482, 1452 },               -- Felwood, Winterspring
        { 2652, 1412 }, { 2652, 1443 }, { 2652, 1444 }, -- Mulgore, Desolace, Feralas
    }
    for _, c in ipairs(cases) do
        it(c[1] .. " liga com " .. c[2] .. " nos dois sentidos, para as duas facções", function()
            local con = between(list, c[1], c[2])
            expect(con ~= nil).toBe(true)
            expect(con.flags).toBe(7)
            expect(con.typ).toBe(1)
            for _, v in ipairs({ con.x1, con.y1, con.x2, con.y2 }) do
                expect(v >= 0 and v <= 100).toBe(true)
            end
        end)
    end
end)

describe("The Bravery por Southshore", function()
    local list = connections()

    it("Menethil e Auberdine chegam a Southshore, só Aliança, ida e volta", function()
        for _, from in ipairs({ 1437, 1439 }) do
            local con = between(list, from, 1424)
            expect(con ~= nil).toBe(true)
            expect(con.flags).toBe(3)
            expect(con.typ).toBe(2)
            expect(con.name1).toBe("Boat to Southshore")
            expect(con.x2).toBe(50.6)
            expect(con.y2).toBe(69.7)
        end
    end)

    it("o rótulo do barco tem tradução", function()
        expect(loader.read("Carbonite/Locales/ptBR/FlightMasters.lua")
            :find('L["Boat to Southshore"] = "Barco para Costa Sul"', 1, true) ~= nil).toBe(true)
    end)
end)

describe("portal de Dalaran para Stormwind", function()
    it("chega no ponto do Shortest Path Forever", function()
        local con = between(connections(), 1416, 1453)
        expect(con.name1).toBe("Portal to Stormwind")
        expect(con.x2).toBe(63.1)
        expect(con.y2).toBe(73.1)
        expect(con.flags).toBe(2)   -- Aliança, só ida
    end)
end)
