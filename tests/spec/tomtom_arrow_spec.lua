-- Carbonite's HUD arrow follows the real TomTom's arrow target (#73)

local function load(opts)
    opts = opts or {}
    local env = wow.lenientEnv()
    local calls = { added = {}, removed = {} }
    local arrow = { shown = true }
    function arrow:Show() self.shown = true end
    function arrow:Hide() self.shown = false end
    env.TomTomCrazyArrow = arrow
    env.C_AddOns = { IsAddOnLoaded = function(name) return name == "TomTom" and not opts.noTomTom end }
    env.hooksecurefunc = function() end
    env.Nx = {
        fdb = { profile = { Notes = { TomTomArrow = opts.off == nil and true or not opts.off } } },
        Notes = {},
    }
    function env.Nx:TTAddWaypoint(m, x, y, o)
        calls.added[#calls.added + 1] = { m, x, y, o.title }
        return "uid" .. #calls.added
    end
    function env.Nx:TTRemoveWaypoint(uid) calls.removed[#calls.removed + 1] = uid end
    function env.Nx:TTSetCrazyArrow() end
    loader.run(env, "Carbonite.Notes/Integrations/TomTomArrow.lua")
    return env.Nx.Notes, calls, arrow, env
end

describe("seta do TomTom", function()
    it("aponta a seta do Carbonite para o destino do TomTom e esconde a dele", function()
        local Notes, calls, arrow = load()
        Notes:TomTomArrowFollow({ 1429, 0.42, 0.65, title = "Hogger" })
        expect(calls.added[1][1]).toBe(1429)
        expect(calls.added[1][4]).toBe("Hogger")
        expect(arrow.shown).toBe(false)
    end)

    it("troca o destino e limpa quando o TomTom fica sem alvo", function()
        local Notes, calls = load()
        Notes:TomTomArrowFollow({ 1429, 0.1, 0.1 })
        Notes:TomTomArrowFollow({ 1429, 0.2, 0.2 })
        expect(calls.removed[1]).toBe("uid1")
        Notes:TomTomArrowFollow(nil)
        expect(calls.removed[2]).toBe("uid2")
        expect(#calls.added).toBe(2)
    end)

    it("desligada, não mexe; ao ligar segue o destino atual e ao desligar devolve a seta", function()
        local Notes, calls, arrow, env = load({ off = true })
        Notes:TomTomArrowFollow({ 1429, 0.3, 0.3 })
        expect(#calls.added).toBe(0)
        env.Nx.fdb.profile.Notes.TomTomArrow = true
        Notes:TomTomArrowSync()
        expect(#calls.added).toBe(1)
        env.Nx.fdb.profile.Notes.TomTomArrow = false
        Notes:TomTomArrowSync()
        expect(calls.removed[1]).toBe("uid1")
        expect(arrow.shown).toBe(true)
    end)

    it("sem o TomTom de verdade (só a emulação do Carbonite) não faz nada", function()
        local Notes, calls = load({ noTomTom = true })
        Notes:TomTomArrowFollow({ 1429, 0.3, 0.3 })
        expect(#calls.added).toBe(0)
    end)
end)
