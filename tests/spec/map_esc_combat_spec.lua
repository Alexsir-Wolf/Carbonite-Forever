-- Esc on the full map in combat (#221): the map must not change
-- UISpecialFrames at run time; a proxy registered once at load closes it.

local function has(src, text)
    return src:find(text, 1, true) ~= nil
end

describe("Esc no mapa grande", function()
    local engine = loader.read("Carbonite/Modules/Map/MapEngine.lua")

    it("registra o procurador uma vez, no carregamento", function()
        expect(has(engine, 'local mapEscProxy = CreateFrame("Frame", "NxMapEscProxy", UIParent)')).toBe(true)
        expect(has(engine, 'tinsert(UISpecialFrames, "NxMapEscProxy")')).toBe(true)
    end)

    it("não insere nem remove a janela do mapa em tempo de execução", function()
        expect(has(engine, "tinsert(UISpecialFrames, self:GetWinName())")).toBe(false)
        expect(has(engine, "tremove(UISpecialFrames")).toBe(false)
    end)

    it("maximizar mostra o procurador e restaurar o esconde sem repetir", function()
        expect(has(engine, "mapEscProxy:Show()")).toBe(true)
        expect(engine:find("mapEscProxy%.NxQuiet = true\r?\n%s*mapEscProxy:Hide%(%)\r?\n%s*mapEscProxy%.NxQuiet = nil")).toBeTruthy()
    end)

    it("o Esc restaura o mapa pelo RestoreSize", function()
        expect(engine:find("if map and map%.Win and map%.Win:IsSizeMax%(%) then\r?\n%s*map:RestoreSize%(%)")).toBeTruthy()
    end)
end)
