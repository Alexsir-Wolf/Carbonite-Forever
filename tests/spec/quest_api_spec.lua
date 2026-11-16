-- Api.Quest helpers in Carbonite/Compat/Api.lua (#10)

local function load(flags, showQuestComplete)
    local env = wow.env({ ShowQuestComplete = showQuestComplete })
    env.Carbonite.Compat = {}
    for k, v in pairs(flags or {}) do env.Carbonite[k] = v end
    loader.run(env, "Carbonite/Compat/Api.lua")
    return env.Carbonite.Compat.Api.Quest
end

describe("Quest:GetAcceptedQuestID", function()
    local Q = load()

    it("lê o questID do arg1 quando o evento só traz o id (Retail, Forever)", function()
        expect(Q:GetAcceptedQuestID(26914, nil)).toBe(26914)
    end)

    it("lê o questID do arg2 no formato (índice, id) do Classic", function()
        expect(Q:GetAcceptedQuestID(5, 26914)).toBe(26914)
    end)

    it("devolve nil sem dados", function()
        expect(Q:GetAcceptedQuestID(nil, nil)).toBeNil()
    end)
end)

describe("Quest:ShowComplete", function()
    it("passa o questID no Forever", function()
        local got
        local Q = load({ isCamelot = true }, function(v) got = v end)
        expect(Q:ShowComplete(26914, 5)).toBe(true)
        expect(got).toBe(26914)
    end)

    it("passa o índice do log no Classic", function()
        local got
        local Q = load({}, function(v) got = v end)
        expect(Q:ShowComplete(26914, 5)).toBe(true)
        expect(got).toBe(5)
    end)

    it("não chama nada sem a função no cliente", function()
        local Q = load({ isCamelot = true }, nil)
        expect(Q:ShowComplete(26914, 5)).toBe(false)
    end)
end)
