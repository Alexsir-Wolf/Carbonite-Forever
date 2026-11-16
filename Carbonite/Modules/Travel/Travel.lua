-- Carbonite | Modules / Travel
-- Module shell for the taxi / flight-path system. Owns the /travel
-- slash command.
-- The engine (taxi capture, FindFlight, MakePath, GetRidingSkill,
-- etc.) lives in TravelEngine.lua and attaches to the same module
-- instance, re-anchoring Nx.Travel so legacy callsites keep working.

local Carbonite = _G.Carbonite
local Module = Carbonite.Core.Module

local Travel = Module:New("Travel")

function Travel:OnEnable()
    Carbonite.Core.SlashCommands:Register("travel", function(rest)
        local args = {}
        for w in rest:gmatch("%S+") do args[#args + 1] = w end
        if args[1] == "add" and self.Add then
            -- Re-scan the flight-master guide data into self.Travel.
            self:Add(LibStub("AceLocale-3.0"):GetLocale("Carbonite")["Flight Master"])
            self.log:info("flight master locations reloaded")
        else
            self.log:info("usage: /carb travel add")
        end
    end, "travel commands")
end
