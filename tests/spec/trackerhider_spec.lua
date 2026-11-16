-- Carbonite.Quests/TrackerHider.lua

describe("TrackerHider no Forever (#12)", function()
    it("esconde o ObjectiveTrackerFrame pelo state driver, sem reparentar", function()
        local calls = {}
        local tracker = wow.frame("ObjectiveTrackerFrame")
        tracker.SetParent = function() calls.setParent = true end
        tracker.HookScript = function() calls.hookScript = true end
        tracker.GetAlpha = function() return 1 end
        local env = wow.lenientEnv({
            ObjectiveTrackerFrame = tracker,
            RegisterStateDriver = function(_, _, state) calls.driver = state end,
            UnregisterStateDriver = function() end,
            InCombatLockdown = function() return false end,
        }, { "WatchFrame", "QuestWatchFrame", "QuestTimerFrame", "EventRegistry" })
        env.Nx = wow.namespace({ Quest = {}, isRetail = false, isCamelot = true,
            qdb = { profile = { Quest = { Enable = true }, QuestWatch = { HideBlizz = true } } } })
        loader.run(env, "Carbonite.Quests/TrackerHider.lua")
        env.Nx.Quest:TrackerHider_Apply()
        expect(calls.driver).toBe("hide")
        expect(calls.setParent).toBeNil()
        expect(calls.hookScript).toBeNil()
    end)
end)
