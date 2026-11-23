-- Pan e zoom do mapa por tempo, com suavização (#246)

local function load()
    local env = wow.lenientEnv()
    loader.run(env, "Carbonite/Modules/Map/Motion.lua")
    return env.Carbonite.Modules.Map.Motion
end

local function near(a, b) return math.abs(a - b) < 1e-9 end

describe("intervalo de atualização do mapa", function()
    local Motion = load()

    it("parado, usa o mapUpdate do usuário", function()
        expect(Motion.Interval(.05, false)).toBe(.05)
        expect(Motion.Interval(.2, false)).toBe(.2)
    end)

    it("arrastando ou com zoom, atualiza a cada frame até 60 por segundo", function()
        expect(Motion.Interval(.05, true)).toBe(1 / 60)
    end)

    it("se o usuário já pediu mais rápido que 60, fica com o dele", function()
        expect(Motion.Interval(.01, true)).toBe(.01)
    end)

    it("sem opção gravada, usa 0,05", function()
        expect(Motion.Interval(nil, false)).toBe(.05)
    end)
end)

describe("animação de zoom por tempo", function()
    local Motion = load()

    it("um passo de 0,05 s anda 19% (desacelera no fim) e sobram 9", function()
        local f, left = Motion.Step(10, .05)
        expect(near(f, .19)).toBe(true)
        expect(near(left, 9)).toBe(true)
    end)

    it("0,5 s termina a animação de 10 passos", function()
        local f, left = Motion.Step(10, .5)
        expect(f).toBe(1)
        expect(left).toBe(0)
    end)

    it("dois frames de 0,025 s andam o mesmo que um de 0,05 s", function()
        local f1, l1 = Motion.Step(10, .025)
        local f2, l2 = Motion.Step(l1, .025)
        local gap = (1 - f1) * (1 - f2)
        expect(near(1 - gap, .19)).toBe(true)
        expect(near(l2, 9)).toBe(true)
    end)

    it("chega ao alvo no tempo certo em qualquer taxa de quadros", function()
        for _, fps in ipairs({ 20, 60, 144 }) do
            local left, pos = 10, 0
            local frames = 0
            while left > 0 and frames < 1000 do
                local f
                f, left = Motion.Step(left, 1 / fps)
                pos = pos + (1 - pos) * f
                frames = frames + 1
            end
            expect(pos).toBe(1)
            expect(math.abs(frames / fps - .5) < 1 / fps + 1e-9).toBe(true)
        end
    end)

    it("sem tempo decorrido, não anda", function()
        local f, left = Motion.Step(10, 0)
        expect(f).toBe(0)
        expect(left).toBe(10)
    end)

    it("sem passos restantes, já está no alvo", function()
        local f, left = Motion.Step(0, .05)
        expect(f).toBe(1)
        expect(left).toBe(0)
    end)
end)

describe("uso no MapEngine", function()
    local src = loader.read("Carbonite/Modules/Map/MapEngine.lua")

    it("o botão de zoom dá um passo, como a roda", function()
        expect(src:find("function Nx%.Map:OnButZoomIn%(%)%s*self:SetScaleOverTime %(1%)") ~= nil).toBe(true)
        expect(src:find("function Nx%.Map:OnButZoomOut%(%)%s*self:SetScaleOverTime %(%-1%)") ~= nil).toBe(true)
    end)

    it("o Update recebe o tempo desde a última atualização", function()
        expect(src:find("elapsed = ttl", 1, true) ~= nil).toBe(true)
    end)

    it("o perfil de CPU não é lido a cada atualização", function()
        expect(src:find('if GetCVar ("scriptProfile") == "1" then', 1, true)).toBe(nil)
    end)

    it("o Motion é carregado antes do MapEngine", function()
        local xml = loader.read("Carbonite/Modules/Modules.xml")
        local motion = xml:find("Map\\Motion.lua", 1, true)
        local engine = xml:find("Map\\MapEngine.lua", 1, true)
        expect(motion ~= nil and engine ~= nil and motion < engine).toBe(true)
    end)
end)
