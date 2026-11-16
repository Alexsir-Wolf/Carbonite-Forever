-- Quest icon on the nameplates of enemies a logged quest still needs (#75)

local function texture()
    local t = { shown = false }
    function t:SetTexture() end
    function t:SetSize() end
    function t:SetPoint() end
    function t:Show() self.shown = true end
    function t:Hide() self.shown = false end
    return t
end

local function load(log, opts)
    opts = opts or {}
    local plate = { namePlateUnitToken = "nameplate1" }
    function plate:CreateTexture() return texture() end
    local env = wow.lenientEnv(nil, { "canaccessvalue", "issecretvalue" })
    env.UnitGUID = function() return opts.guid or "Creature-0-1-2-3-3125-0001" end
    env.UnitIsFriend = function() return opts.friend or false end
    env.C_NamePlate = {
        GetNamePlateForUnit = function() return plate end,
        GetNamePlates = function() return { plate } end,
    }
    env.Nx = wow.namespace({
        QInit = true,
        qdb = { profile = { Quest = { NameplateIcon = opts.off == nil and true or not opts.off } } },
        Units2Quests = { [3125] = "800,1|801,2" },
        Quest = wow.namespace(),
    })
    function env.Nx.Quest:FindCur(qId)
        if log[qId] then return 1, log[qId] end
    end
    loader.run(env, "Carbonite.Quests/Nameplates.lua")
    return env.Nx.Quest.Nameplates, plate
end

describe("nameplates de quest", function()
    it("marca o inimigo que uma quest do registro ainda precisa", function()
        local NP, plate = load({ [800] = { "Escorpião: 3/10", [101] = false } })
        NP:Refresh("nameplate1")
        expect(plate.CarboniteQuestIcon.shown).toBe(true)
    end)

    it("não marca quando o objetivo já foi feito ou a quest está pronta", function()
        local NP, plate = load({ [800] = { "Escorpião: 10/10", [101] = true }, [801] = { CompleteMerge = 1 } })
        NP:Refresh("nameplate1")
        expect(plate.CarboniteQuestIcon).toBeNil()
    end)

    it("procura nas outras quests do NPC", function()
        local NP = load({ [801] = { "a", "Garra: 1/5", [102] = false } })
        expect(NP:NeededFor(3125) ~= nil).toBe(true)
    end)

    it("ignora jogadores, amigos e a opção desligada", function()
        local log = { [800] = { "x", [101] = false } }
        expect(load(log, { guid = "Player-1-0001" }):NpcId("nameplate1")).toBeNil()
        local NP, plate = load(log, { friend = true })
        NP:Refresh("nameplate1")
        expect(plate.CarboniteQuestIcon).toBeNil()
        NP, plate = load(log, { off = true })
        NP:Refresh("nameplate1")
        expect(plate.CarboniteQuestIcon).toBeNil()
    end)

    it("desligar a opção esconde o ícone que já estava", function()
        local log = { [800] = { "x", [101] = false } }
        local NP, plate = load(log)
        NP:Refresh("nameplate1")
        log[800] = nil
        NP:RefreshAll()
        expect(plate.CarboniteQuestIcon.shown).toBe(false)
    end)
end)
