-- Api.Skill:GetRank in Carbonite/Compat/Api.lua (#20)

local function load(overrides)
    local env = wow.env(overrides)
    env.Carbonite.Compat = {}
    loader.run(env, "Carbonite/Compat/Api.lua")
    return env.Carbonite.Compat.Api.Skill
end

describe("Skill:GetRank", function()
    it("lê pelo id no C_SkillInfo do Forever", function()
        local S = load({ C_SkillInfo = {
            GetSkillLineInfoByID = function(id) return id == 762 and { name = "Montaria", rank = 75 } or nil end,
        } })
        expect(S:GetRank(762, "Montaria")).toBe(75)
    end)

    it("procura pelo nome no C_SkillInfo sem a busca por id", function()
        local lines = { { name = "Perícias", isHeader = true }, { name = "Montaria", rank = 150 } }
        local S = load({ C_SkillInfo = {
            GetNumSkillLines = function() return #lines end,
            GetSkillLineInfo = function(i) return lines[i] end,
        } })
        expect(S:GetRank(762, "Montaria")).toBe(150)
    end)

    it("usa a API antiga nos clientes sem C_SkillInfo", function()
        local S = load({
            GetNumSkillLines = function() return 1 end,
            GetSkillLineInfo = function() return "Riding", nil, nil, 225 end,
        })
        expect(S:GetRank(762, "Riding")).toBe(225)
    end)

    it("devolve 0 sem a perícia", function()
        local S = load({ C_SkillInfo = { GetSkillLineInfoByID = function() return nil end } })
        expect(S:GetRank(762, "Riding")).toBe(0)
    end)
end)
