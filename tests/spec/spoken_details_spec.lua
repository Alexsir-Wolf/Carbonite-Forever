-- Spoken's Play button on the journal's details panel (#71)

local function button()
    local b = { shown = false }
    function b:SetSize() end
    function b:SetPoint() end
    function b:SetFrameLevel() end
    function b:Show() self.shown = true end
    function b:Hide() self.shown = false end
    return b
end

local function load(recorded)
    local env = wow.lenientEnv(nil, { "Spoken" })
    local calls = { made = 0, bound = {} }
    env.GetTime = function() return 0 end
    env.hooksecurefunc = function() end
    env.C_QuestLog = { GetTitleForQuestID = function(id) return "Quest " .. id end }
    env.VoiceOver = { QuestOverlayUI = {
        MakePlayButton = function() calls.made = calls.made + 1 return button() end,
        ShowsTrackerButton = function(_, id) return recorded[id] or false end,
        BindPlayButton = function(_, _, id, _, origin) calls.bound[#calls.bound + 1] = { id, origin } end,
        SetPlayButtonState = function() end,
        FollowQueue = function() end,
    } }
    env.Nx = wow.namespace({ List = { Update = function() end }, Quest = wow.namespace({ CurQ = {} }) })
    loader.run(env, "Carbonite.Quests/SpokenPlay.lua")
    local SP = env.Nx.Quest.SpokenPlay
    local frame = { GetFrameLevel = function() return 1 end }
    SP:AttachToDetails(frame)
    return SP, calls
end

describe("Spoken no diário", function()
    it("mostra o Play nos detalhes de uma quest narrada", function()
        local SP, calls = load({ [800] = true })
        SP:SetDetailsQuest(800)
        expect(calls.made).toBe(1)
        expect(calls.bound[1][1]).toBe(800)
        expect(calls.bound[1][2]).toBe("Carbonite's quest log")
    end)

    it("esconde para quest sem narração e reaproveita o botão", function()
        local SP, calls = load({ [800] = true, [801] = true })
        SP:SetDetailsQuest(800)
        SP:SetDetailsQuest(900)
        SP:SetDetailsQuest(801)
        expect(calls.made).toBe(1)
        expect(#calls.bound).toBe(2)
    end)

    it("sem quest narrada, nem cria o botão", function()
        local SP, calls = load({})
        SP:SetDetailsQuest(800)
        expect(calls.made).toBe(0)
    end)

    it("o diário avisa o Spoken da quest selecionada", function()
        local src = loader.read("Carbonite.Quests/QuestWindow.lua")
        expect(src:find("SpokenPlay:AttachToDetails (f)", 1, true) ~= nil).toBe(true)
        expect(src:find("SpokenPlay:SetDetailsQuest (qId)", 1, true) ~= nil).toBe(true)
    end)
end)
