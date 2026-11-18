-- Short texts: Options tree item and the quest watch overflow line (#205)

local function has(path, text)
    return loader.read(path):find(text, 1, true) ~= nil
end

describe("textos curtos", function()
    it("o item da seta no menu das Opções usa um nome curto", function()
        expect(has("Carbonite/Modules/Options/Options.lua", 'name = L["Navigation Arrow"] }')).toBe(true)
        expect(has("Carbonite/Modules/Options/Options.lua", 'L["Navigation Arrow (HUD)"]')).toBe(false)
        expect(has("Carbonite/Locales/enUS/Options.lua", 'L["Navigation Arrow"] = true')).toBe(true)
        expect(has("Carbonite/Locales/ptBR/Options.lua", 'L["Navigation Arrow"] = "Seta de navegação"')).toBe(true)
    end)

    it("o nome do item cabe no menu lateral", function()
        local ptBR = loader.read("Carbonite/Locales/ptBR/Options.lua"):match('L%["Navigation Arrow"%] = "([^"]+)"')
        -- Count UTF-8 characters, not bytes
        local chars = select(2, ptBR:gsub("[^\128-\191]", ""))
        expect(chars <= 18).toBe(true)
    end)

    it("o Monitor mostra \"+N missões\" quando há missões ocultas", function()
        expect(has("Carbonite.Quests/Locales/ptBR.lua", 'L["+%d more"] = "+%d missões"')).toBe(true)
        expect(has("Carbonite.Quests/Locales/ptBR.lua", "a mais")).toBe(false)
        expect(has("Carbonite.Quests/WatchWindow.lua", 'format (L["+%d more"], remaining)')).toBe(true)
    end)
end)
