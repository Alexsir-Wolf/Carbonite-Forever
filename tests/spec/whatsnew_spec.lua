-- Carbonite/Modules/Whatsnew/WhatsnewEngine.lua: Forever changelog, no pop-up on a fresh install (#56)

local function load(lastreadtime)
    local env = wow.lenientEnv()
    env.Nx = wow.namespace({ db = { profile = { Whatsnew = { lastreadtime = lastreadtime } } } })
    loader.run(env, "Carbonite/Modules/Whatsnew/WhatsnewEngine.lua")
    return env.Nx.Whatsnew, env.Nx.db.profile.Whatsnew
end

describe("Novidades", function()
    it("traz só o changelog da edição Forever", function()
        local W = load(0)
        expect(#W.Categories).toBe(1)
        for _, rows in pairs(W[W.Categories[1]]) do
            expect(rows[1]:find("forever", 1, true) ~= nil).toBe(true)
            for _, row in ipairs(rows) do
                expect(row:find("IrcDirk", 1, true)).toBeNil()
                expect(#row <= 58).toBe(true)
            end
        end
    end)

    it("não abre numa instalação nova e marca o changelog atual como lido", function()
        local W, saved = load(0)
        expect(W:ShouldAutoShow()).toBe(false)
        expect(saved.lastreadtime).toBe(W:GetMaxTime())
        expect(W:ShouldAutoShow()).toBe(false)
    end)

    it("abre quando há entrada mais nova que a lida", function()
        local W = load(1000)
        expect(W:ShouldAutoShow()).toBe(true)
    end)
end)

describe("textos herdados do upstream", function()
    it("a página Sobre aponta para a edição Forever e mantém os créditos", function()
        local src = loader.read("Carbonite/Modules/Options/OptionsEngine.lua")
        expect(src:find("Carbonite-Classic", 1, true)).toBeNil()
        expect(src:find("Curse/Twitch", 1, true)).toBeNil()
        expect(src:find("Alexsir-Wolf/Carbonite-Forever", 1, true) ~= nil).toBe(true)
        expect(src:find("Rythal for hard work", 1, true) ~= nil).toBe(true)
    end)

    it("os TOCs carregados no Forever têm autor, descrição e título em pt-BR", function()
        local tocs = {
            "Carbonite/Carbonite-Camelot.toc", "Carbonite.Quests/Carbonite.Quests-Camelot.toc",
            "Carbonite.Info/Carbonite.Info.toc", "Carbonite.Notes/Carbonite.Notes.toc",
            "Carbonite.Warehouse/Carbonite.Warehouse.toc",
        }
        for _, path in ipairs(tocs) do
            local toc = loader.read(path)
            expect(toc:lower():find("author: no one", 1, true)).toBeNil()
            expect(toc:find("Released Under GPL", 1, true)).toBeNil()
            expect(toc:find("## Title-ptBR:", 1, true) ~= nil).toBe(true)
            expect(toc:find("## IconTexture:", 1, true) ~= nil).toBe(true)
        end
    end)
end)
