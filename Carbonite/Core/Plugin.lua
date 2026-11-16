-- Carbonite | Core / Plugin
-- Helper used by sibling addons (Carbonite.Notes, Carbonite.Warehouse,
-- Carbonite.Quests, ...) so they can plug into the new Carbonite
-- architecture while remaining standalone AceAddon-3.0 addons that
-- the user can enable / disable independently.
--
-- A plugin addon does NOT become a submodule of Carbonite. It owns
-- its own SavedVariables, its own AceDB, and its own enable/disable
-- toggle. What this helper gives it:
--   - A logger bound to the plugin name (via Carbonite.Core.Logger).
--   - Subscription/Fire on the shared EventBus.
--   - Access to the shared UI mixins and tooltip pool.
--
-- Usage from a plugin addon's main lua file:
--
--   local Notes = LibStub("AceAddon-3.0"):NewAddon("CarboniteNotes",
--       "AceEvent-3.0", "AceTimer-3.0")
--   local Plugin = _G.Carbonite.Core.Plugin
--   Plugin.Bind(Notes, "Notes")

local Carbonite = _G.Carbonite
local Plugin = {}
Carbonite.Core.Plugin = Plugin

local registry = {}

function Plugin.Bind(addonObject, displayName)
    local name = displayName or addonObject:GetName()

    addonObject.log = Carbonite.Core.Logger:Get(name)
    addonObject.Carbonite = Carbonite
    addonObject.bus = Carbonite.Core.EventBus

    registry[#registry + 1] = { addon = addonObject, name = name }

    return addonObject
end

function Plugin.Plugins()
    return registry
end
