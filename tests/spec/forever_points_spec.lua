-- Forever library books and convergences on the map (#82)

local function load(opts)
    opts = opts or {}
    local env = wow.lenientEnv()
    env.Nx = { Notes = {}, fdb = { profile = { Notes = { LibraryBooks = true, Convergences = true,
        ConvergencesAll = opts.all or false } } } }
    env.LibStub = function() return { GetLocale = function() return setmetatable({}, { __index = function(_, k) return k end }) end } end
    env.C_QuestLog = { IsQuestFlaggedCompleted = function(q) return (opts.done or {})[q] or false end }
    env.C_Item = { GetItemNameByID = function(id) return id == 203755 and "Diário de Teócrito" or nil end,
                   RequestLoadItemDataByID = function() end }
    env.UnitRace = function() return "x", opts.race or "Orc" end
    loader.run(env, "Carbonite.Notes/Integrations/ForeverPoints.lua")
    return env.Nx.Notes
end

describe("livros da biblioteca e convergências", function()
    it("mostra o livro com o nome do item e some depois da quest entregue", function()
        local books = load():LibraryBooksOn(1429)          -- Floresta de Elwynn
        expect(#books).toBe(1)
        expect(books[1][3]).toBe("Diário de Teócrito")
        expect(#load({ done = { [79092] = true } }):LibraryBooksOn(1429)).toBe(0)
    end)

    it("convergências só para Skyborne, ou para todos com a opção", function()
        expect(load():ShowsConvergences()).toBe(false)
        expect(load({ race = "Skyborne" }):ShowsConvergences()).toBe(true)
        expect(load({ all = true }):ShowsConvergences()).toBe(true)
    end)
end)
