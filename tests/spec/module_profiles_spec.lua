-- Nx.Opts:FollowMainProfile in Carbonite/Modules/Options/OptionsEngine.lua: module databases
-- follow the main profile (#58). Uses the real AceDB-3.0 bundled in Carbonite/Libs.

local function env()
    local e = wow.lenientEnv({ UnitName = function() return "Eu" end,
                               GetRealmName = function() return "Reino" end,
                               UnitClass = function() return "Mago", "MAGE" end,
                               UnitRace = function() return "Humano", "Human" end,
                               UnitFactionGroup = function() return "Alliance" end,
                               GetCurrentRegion = function() return 1 end,
                               securecallfunction = function(f, ...) return f(...) end }, { "LibStub", "CarbData", "NXQuest", "NXNotes" })
    local stub = e.LibStub
    e.LibStub = nil
    loader.run(e, "Carbonite/Libs/LibStub/LibStub.lua")
    loader.run(e, "Carbonite/Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua")
    loader.run(e, "Carbonite/Libs/AceDB-3.0/AceDB-3.0.lua")
    -- Libraries the test did not load (AceConfig, AceLocale...) fall back to the stub.
    local real = e.LibStub
    getmetatable(real).__call = function(_, name) return real:GetLibrary(name, true) or stub(name) end
    e.AceDB = real("AceDB-3.0")
    e.Nx = wow.namespace({ Opts = {} })
    loader.run(e, "Carbonite/Modules/Options/OptionsEngine.lua")
    return e
end

describe("perfis dos módulos", function()
    local e = env()
    local Nx = e.Nx
    Nx.db = e.AceDB:New("CarbData", { profile = { x = 1 } }, true)
    local quests = e.AceDB:New("NXQuest", { profile = { y = 1 } }, true)
    local notes = e.AceDB:New("NXNotes", { profile = { z = 1 } }, true)
    notes:SetProfile("Outro")
    Nx.Opts:FollowMainProfile(quests)
    Nx.Opts:FollowMainProfile(notes)

    it("entram no perfil atual do Carbonite", function()
        expect(notes:GetCurrentProfile()).toBe(Nx.db:GetCurrentProfile())
    end)

    it("trocar de perfil troca todos os módulos", function()
        Nx.db:SetProfile("Raide")
        expect(quests:GetCurrentProfile()).toBe("Raide")
        expect(notes:GetCurrentProfile()).toBe("Raide")
    end)

    it("copiar, resetar e apagar valem para todos", function()
        local base = "Eu - Reino"
        Nx.db:SetProfile(base)
        quests.profile.y = 7
        Nx.db:SetProfile("Raide")
        Nx.db:CopyProfile(base)
        expect(quests.profile.y).toBe(7)
        Nx.db:ResetProfile()
        expect(quests.profile.y).toBe(1)
        Nx.db:SetProfile(base)
        Nx.db:DeleteProfile("Raide")
        expect(quests.profiles.Raide).toBeNil()
        expect(notes.profiles.Raide).toBeNil()
    end)
end)
