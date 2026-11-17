-- Tempo real de cada voo gravado por par de mestres de voo (#139)

local function load(clock)
    local env = wow.lenientEnv({ GetTime = function() return clock.t end })
    env.Nx = { db = { global = {}, profile = { Debug = {} } } }
    loader.run(env, "Carbonite/Modules/Travel/FlightTimes.lua")
    return env, env.Carbonite.Modules.FlightTimes
end

describe("FlightTimes", function()
    it("grava um voo e lê o tempo de volta", function()
        local clock = { t = 100 }
        local env, FT = load(clock)
        FT:Begin("Stormwind, Elwynn", "Ironforge, Dun Morogh")
        clock.t = 101
        FT:OnEvent("PLAYER_CONTROL_LOST")
        clock.t = 213.46
        FT:OnEvent("PLAYER_CONTROL_GAINED")
        expect(FT:Get("Stormwind, Elwynn", "Ironforge, Dun Morogh")).toBe(112.5)
        expect(env.Nx.db.global.FlightTimes["Stormwind, Elwynn#Ironforge, Dun Morogh"]).toBe(112.5)
    end)

    it("par desconhecido devolve 0", function()
        local _, FT = load({ t = 0 })
        FT:Record("A", "B", 60)
        expect(FT:Get("B", "A")).toBe(0)
        expect(FT:Get("A", "C")).toBe(0)
        expect(FT:Get(nil, "B")).toBe(0)
    end)

    it("ignora o controle recuperado sem decolagem", function()
        local clock = { t = 0 }
        local _, FT = load(clock)
        FT:Begin("A", "B")
        clock.t = 30
        FT:OnEvent("PLAYER_CONTROL_LOST")   -- fora da janela de decolagem
        clock.t = 90
        FT:OnEvent("PLAYER_CONTROL_GAINED")
        expect(FT:Get("A", "B")).toBe(0)
    end)
end)

describe("Travel:TaxiFindConnectionTime", function()
    local function travel(flightTimes, conn)
        local env = wow.lenientEnv()
        local T = {}
        env.Carbonite = { Modules = { FlightTimes = flightTimes }, GetModule = function() return T end }
        env.Nx = wow.namespace({ FlightConnection = conn })
        -- O arquivo tem BOM UTF-8, que o loadfile do Lua 5.1 não aceita (o cliente aceita).
        local src = loader.read("Carbonite/Modules/Travel/TravelEngine.lua"):gsub("^\239\187\191", "")
        local chunk = assert(loadstring(src, "TravelEngine.lua"))
        setfenv(chunk, env)
        chunk("Carbonite", {})
        return T
    end

    it("usa o tempo gravado quando FlightConnection está vazio", function()
        local _, FT = load({ t = 0 })
        FT:Record("A", "B", 75)
        local T = travel(FT, "")
        expect(T:TaxiFindConnectionTime("A", "B")).toBe(75)
        expect(T:TaxiFindConnectionTime("B", "A")).toBe(0)
    end)
end)
