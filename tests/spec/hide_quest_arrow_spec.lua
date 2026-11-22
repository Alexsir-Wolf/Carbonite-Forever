-- The game's gold quest arrow is hidden on the Carbonite map: the game's quest
-- super-track is emptied, and Carbonite must behave exactly as if it were not.
-- The real mirror, helpers, hook and click handlers run on a simulated client;
-- most cases compare the option on with the option off.

local function read(path)
    return (loader.read(path):gsub("\r\n", "\n"))
end

local function between(src, first, last)
    local s = assert(src:find(first, 1, true), "missing: " .. first)
    local e = assert(src:find(last, s + #first, true), "missing: " .. last)
    return src:sub(s, e - 1), src:sub(s + #first, e - 1)
end

local questWindow = read("Carbonite.Quests/QuestWindow.lua")
local engine = read("Carbonite/Modules/Map/MapEngine.lua")

local _, hookBody = between(questWindow,
    'hooksecurefunc(C_SuperTrack, "SetSuperTrackedQuestID", function(qID)',
    "\n            end)\n        end\n    elseif AddQuestWatch")
local listClick = between(questWindow, "function Nx.Quest.List:ToggleWatch (qId, qIndex, qObj, shift)",
    "-------------------------------------------------------------------------------\n-- Make a quest link")
local iconClick = engine:match("(function Nx%.Map:QuestIconClick %(this, button%).-\nend)\n")

local function compile(code, env)
    local f = assert(loadstring(code))
    setfenv(f, env)
    return f()
end

local function client(opts)
    opts = opts or {}
    local s = { quest = 0, now = 100, timers = {}, deferred = {}, saved = opts.saved or {}, writes = 0 }
    local env = wow.lenientEnv(nil, { "securecallfunction", "RXP", "debugstack" })
    env.setfenv, env.loadstring = setfenv, loadstring
    env.GetTime = function() return s.now end
    env.InCombatLockdown = function() return s.combat or false end
    env.IsShiftKeyDown = function() return false end
    env.PlaySound = function() end
    env.SOUNDKIT = {}
    env.C_Timer = { After = function(_, fn) s.timers[#s.timers + 1] = fn end }
    env.C_QuestLog = { IsOnQuest = function() return true end }
    env.C_Map = {}
    env.Enum = { SuperTrackingType = { UserWaypoint = 4 } }
    env.QuestUtils_IsQuestWorldQuest = function() return false end
    env.WorldMapFrame = { IsShown = function() return s.mapOpen or false end }

    local map = { MMOwn = opts.own ~= false, Targets = {} }
    local quest = wow.namespace({})
    local nx = wow.namespace({
        Quest = quest,
        QInit = true,
        db = {
            profile = { MiniMap = { HideQuestArrow = not opts.off } },
            char = { Map = s.saved },
        },
    })
    env.Nx = nx
    function map.GetTargetInfo() if s.route then return "Q", s.route * 100 end end
    function map.ClearTargets() s.route = nil end
    function map.GetMap() return map end
    nx.Map = map
    map.Maps = { map }

    local function changed()
        quest:NoteSuperTrackEvent()
    end
    local function write(q)
        q = q or 0
        s.writes = s.writes + 1
        local before = s.quest
        s.quest = q
        if before ~= q then changed() end
    end
    env.C_SuperTrack = {
        GetSuperTrackedQuestID = function() return s.quest ~= 0 and s.quest or nil end,
        SetSuperTrackedQuestID = function(q)
            write(q)
            s.hook(q)
        end,
        IsSuperTrackingUserWaypoint = function() return s.waypoint or false end,
        GetHighestPrioritySuperTrackingType = function() return nil end,
        SetSuperTrackedUserWaypoint = function(on)
            s.waypoint = on
            changed()
        end,
        IsSuperTrackingQuest = function() return s.quest ~= 0 end,
        IsSuperTrackingAnything = function() return s.quest ~= 0 or s.waypoint or false end,
        ClearAllSuperTracked = function()
            s.waypoint = false
            write(0)
        end,
    }
    env.Carbonite.Modules.CombatLockdown = {
        RunWhenSafe = function(_, fn) s.deferred[#s.deferred + 1] = fn end,
    }

    loader.run(env, "Carbonite/Modules/TaintlessHelpers/TaintlessHelpers.lua")
    loader.run(env, "Carbonite.Quests/SuperTrack.lua", "Carbonite.Quests")

    for _, key in ipairs({ "ActiveQID", "ActiveObjI", "_stLastSet" }) do quest[key] = 0 end
    for _, key in ipairs({ "UserClearedActive", "_stLockoutUntil", "HiddenQID", "SeenSuperQID", "PendingGotoQID",
        "RestoredQID", "HiddenLoaded", "UserObjPick", "RXPSuperTrackQID", "RXPWaypointSig", "_qEvtRing",
        "_stHookQID", "_stHookTime", "_addWatchSuppress" }) do
        -- namespace() invents missing fields: these must read as empty
        quest[key] = false
    end
    quest.CurQ, quest.Tracking = {}, {}
    quest.FindCur = function(_, q) return 1, { QId = q, TrackMask = 1, QI = 0 }, q end
    quest.GetUserObjPick = function() return nil end
    quest.IsFreshUserWaypoint = function() return false end
    quest.IsAutoTrackOn = function() return opts.autoTrack or false end
    quest.OnUserWaypointUpdated = function() end
    quest.UpdateQuestBlob = function(_, q) s.blob = q end
    quest.PatchQuestFromBlizzard = function() end
    quest.PartyStartSend = function() end
    quest.TrackOnMap = function(_, q)
        s.route = q
        s.routed = (s.routed or 0) + 1
    end
    quest.Watch = { Update = function() end, SuspendAutoTarget = function() end, RemoveWatch = function() end }
    quest.List = { Update = function() end }
    nx.GetQuest = function() return "W" end
    quest.GetQuest = nx.GetQuest
    quest.SetQuest = function() end

    s.hook = compile("return function(qID)" .. hookBody .. "\nend", env)
    compile(listClick, env)
    compile(iconClick, env)

    -- From here a field nobody set reads as nil, as in the game.
    setmetatable(quest, nil)
    for _, key in ipairs({ "UserClearedActive", "_stLockoutUntil", "HiddenQID", "SeenSuperQID", "PendingGotoQID",
        "RestoredQID", "HiddenLoaded", "RXPSuperTrackQID", "_qEvtRing", "_addWatchSuppress" }) do
        quest[key] = nil
    end
    s.env, s.Nx, s.Quest, s.map = env, nx, quest, map

    function s.frame()
        local due = s.timers
        s.timers = {}
        for _, fn in ipairs(due) do fn() end
    end
    -- One second of play: the event timers, then the arrow's passes.
    function s.settle()
        for _ = 1, 5 do
            s.frame()
            s.frame()
            s.now = s.now + .2
            local sync = rawget(quest, "SyncQuestArrow")
            if sync then sync(quest) end
        end
        s.frame()
    end

    local actions = {}
    -- A row of the watch (WatchWindow.lua): the secure trio.
    function actions.watch(q)
        nx.SuperTrackSafe(function()
            nx.SetSuperTrackedUserWaypointSafe(false)
            nx.ClearNonQuestSuperTrackSafe()
            nx.SetSuperTrackedQuestIDSafe(q)
        end)
    end
    function actions.list(q) quest.List:ToggleWatch(q, 0, 0, false) end
    function actions.icon(q) map:QuestIconClick({ NXData = { QId = q, QI = 0 }, NXType = 9000 }) end
    function actions.blizzard(q) env.C_SuperTrack.SetSuperTrackedQuestID(q) end
    -- The game tracks an accepted quest when nothing is super tracked.
    function actions.accept(q)
        quest:StampQuestEvent()
        if not env.C_SuperTrack.IsSuperTrackingAnything() then
            env.C_SuperTrack.SetSuperTrackedQuestID(q)
        end
    end
    function actions.progress() quest:OnSuperTrackChanged(true) end
    function actions.clear()
        quest.UserClearedActive = true
        nx.SetSuperTrackedQuestIDSafe(0)
    end
    s.act = function(name, q)
        actions[name](q)
        s.settle()
    end
    return s
end

-- Runs the steps with the option on and off: same route, same active quest.
local function sameAsWithout(steps, opts)
    opts = opts or {}
    local on = client({ autoTrack = opts.autoTrack })
    local off = client({ off = true, autoTrack = opts.autoTrack })
    for i, step in ipairs(steps) do
        on.act(step[1], step[2])
        off.act(step[1], step[2])
        local where = "passo " .. i .. " (" .. step[1] .. "): "
        expect(where .. tostring(on.route)).toBe(where .. tostring(off.route))
        expect(where .. tostring(on.Quest.ActiveQID)).toBe(where .. tostring(off.Quest.ActiveQID))
        expect(where .. on.quest).toBe(where .. 0)
        expect(where .. (on.Nx.GetSuperTrackedQID() or 0)).toBe(where .. off.quest)
    end
    return on, off
end

describe("seta de quest: mesma rota de antes, sem seta", function()
    it("troca de quest pelo Monitor, várias vezes", function()
        local on = sameAsWithout({ { "watch", 11 }, { "watch", 22 }, { "watch", 33 }, { "watch", 22 }, { "watch", 11 } })
        expect(on.route).toBe(11)
    end)

    it("clicar de novo no Monitor mantém a rota", function()
        local on = sameAsWithout({ { "watch", 11 }, { "watch", 11 }, { "watch", 11 } })
        expect(on.route).toBe(11)
    end)

    it("troca pelo diário e desmarca no segundo clique", function()
        local on = sameAsWithout({ { "list", 11 }, { "list", 22 }, { "list", 22 } })
        expect(on.route).toBe(nil)
    end)

    it("troca pelo ícone do mapa e desmarca no segundo clique", function()
        local on = sameAsWithout({ { "icon", 11 }, { "icon", 22 }, { "icon", 22 } })
        expect(on.route).toBe(nil)
    end)

    it("troca pela interface da Blizzard", function()
        sameAsWithout({ { "blizzard", 11 }, { "blizzard", 22 } })
    end)

    it("desmarcar e escolher de novo", function()
        local on = sameAsWithout({ { "watch", 11 }, { "clear" }, { "watch", 22 } })
        expect(on.route).toBe(22)
    end)

    it("aceitar quest não rouba a rota", function()
        local on = sameAsWithout({ { "watch", 11 }, { "accept", 44 } })
        expect(on.route).toBe(11)
    end)

    it("aceitar quest com alvo automático também não rouba", function()
        local on = sameAsWithout({ { "watch", 11 }, { "accept", 44 } }, { autoTrack = true })
        expect(on.route).toBe(11)
    end)

    it("avanço de objetivo recalcula a rota", function()
        local on = client()
        on.act("watch", 11)
        local routed = on.routed
        on.act("progress")
        expect(on.routed).toBe(routed + 1)
        expect(on.quest).toBe(0)
    end)
end)

describe("seta de quest: quando esconder", function()
    it("login com quest rastreada e sem rota: some e não cria rota", function()
        local s = client()
        s.quest = 11
        s.settle()
        expect(s.quest).toBe(0)
        expect(s.route).toBe(nil)
        expect(s.Quest.ActiveQID).toBe(11)
    end)

    it("depois do reload a quest escondida volta destacada, sem rota", function()
        local before = client()
        before.act("watch", 11)
        local after = client({ saved = before.saved })
        after.settle()
        expect(after.Nx.GetSuperTrackedQID()).toBe(11)
        expect(after.Quest.ActiveQID).toBe(11)
        expect(after.quest).toBe(0)
        expect(after.route).toBe(nil)
    end)

    it("em combate não escreve; ao sair traça a rota e esconde", function()
        local s = client()
        s.combat = true
        s.env.C_SuperTrack.SetSuperTrackedQuestID(11)
        s.settle()
        expect(s.quest).toBe(11)
        s.combat = false
        s.settle()
        expect(s.route).toBe(11)
        expect(s.quest).toBe(0)
    end)

    it("com o mapa do jogo aberto espera fechar", function()
        local s = client()
        s.mapOpen = true
        s.act("watch", 11)
        expect(s.quest).toBe(11)
        s.mapOpen = false
        s.settle()
        expect(s.quest).toBe(0)
        expect(s.route).toBe(11)
    end)

    it("não mexe quando um pino está rastreado", function()
        local s = client()
        s.waypoint = true
        s.quest = 11
        local writes = s.writes
        s.settle()
        expect(s.writes).toBe(writes)
    end)

    it("só age com o minimapa no mapa do Carbonite", function()
        local s = client({ own = false })
        s.act("watch", 11)
        expect(s.quest).toBe(11)
    end)

    it("não fica escrevendo parado", function()
        local s = client()
        s.act("watch", 11)
        local writes = s.writes
        s.settle()
        s.settle()
        expect(s.writes).toBe(writes)
    end)
end)

describe("seta de quest: desligar e esquecer", function()
    it("desligar devolve a seta e mantém a rota", function()
        local s = client()
        s.act("watch", 11)
        s.Nx.db.profile.MiniMap.HideQuestArrow = false
        s.settle()
        expect(s.quest).toBe(11)
        expect(s.route).toBe(11)
        expect(s.Quest.ActiveQID).toBe(11)
    end)

    it("desligar sem rota não cria rota", function()
        local s = client()
        s.quest = 11
        s.settle()
        s.Nx.db.profile.MiniMap.HideQuestArrow = false
        s.settle()
        expect(s.quest).toBe(11)
        expect(s.route).toBe(nil)
    end)

    it("quest removida é esquecida", function()
        local s = client()
        s.act("watch", 11)
        s.Quest:ForgetHiddenQuest(11)
        expect(s.Nx.GetSuperTrackedQID() or 0).toBe(0)
        expect(s.saved.HiddenQuest).toBe(nil)
        local removed = between(questWindow, 'elseif event == "QUEST_REMOVED" then', "if QuestUtils_IsQuestWorldQuest")
        expect(removed).toContain("ForgetHiddenQuest")
    end)

    it("deixar de vigiar sem rota esquece; com rota mantém", function()
        local s = client()
        s.act("watch", 11)
        s.Quest:OnHiddenQuestUnwatched(11)
        expect(s.Nx.GetSuperTrackedQID()).toBe(11)
        s.route = nil
        s.Quest:OnHiddenQuestUnwatched(11)
        expect(s.Nx.GetSuperTrackedQID() or 0).toBe(0)
    end)
end)

describe("seta de quest: opção", function()
    it("ligada por padrão, em Opções do Minimapa", function()
        expect(read("Carbonite/Modules/PlayerCharacter/Defaults.lua")).toContain("HideQuestArrow = true,")
        expect(read("Carbonite/Modules/Options/OptionsEngine.lua")).toContain('L["Hide the quest arrow"]')
    end)

    it("quem lia o super-track lê o lógico", function()
        for _, path in ipairs({ "Carbonite/Modules/Map/MapEngine.lua", "Carbonite.Quests/MapIcons.lua",
            "Carbonite.Quests/QuestRouting.lua", "Carbonite.Quests/WatchWindow.lua" }) do
            expect(read(path):find("C_SuperTrack.GetSuperTrackedQuestID()", 1, true)).toBe(nil)
        end
    end)
end)
