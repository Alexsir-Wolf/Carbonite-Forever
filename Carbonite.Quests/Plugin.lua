-- Carbonite.Quests | Plugin entry
-- New front door for the Quests plugin. Behaves like every other
-- Carbonite plugin: exposes a clean API for other plugins and routes
-- events through the shared EventBus.
--
-- The actual quest database parsing, tracker UI, and route planning
-- still live in NxQuest.lua and the Data/<expansion>/ folders. This
-- file is the structural change: a single multi-interface TOC will
-- replace the five per-expansion variants, and runtime detection
-- picks the right data folder via Carbonite.Compat.Expansion.

local Carbonite = _G.Carbonite
if not Carbonite then return end

local AceAddon = LibStub("AceAddon-3.0")
local Plugin = Carbonite.Core.Plugin
local Expansion = Carbonite.Compat.Expansion

local QuestAddon = AceAddon:GetAddon("Carbonite.Quest", true)
if not QuestAddon then
    QuestAddon = AceAddon:NewAddon("Carbonite.Quest",
        "AceEvent-3.0", "AceComm-3.0", "AceTimer-3.0", "AceHook-3.0")
end

local Quests = {}
QuestAddon.Public = Quests
-- Cross-plugin slot. Carbonite == Nx, and NxQuest.lua keeps the
-- legacy Nx.Quest table with the full method surface; don't
-- collide. Sibling .Quests classes (WatchHider, WatchSurface,
-- Routing) ALSO live under Carbonite.Quests so we use a sub-key
-- here rather than replacing the whole bucket.
Carbonite.Plugins = Carbonite.Plugins or {}
Carbonite.Plugins.Quests = Quests
Carbonite.Quests = Carbonite.Quests or {}
Carbonite.Quests.Public = Quests

function Quests:GetExpansionFolder()
    return Expansion:GetMapDataFolder()
end

function Quests:ToggleTracker()
    local Nx = _G.Nx
    if Nx and Nx.Quest and Nx.Quest.ToggleShow then Nx.Quest:ToggleShow() end
end

Plugin.Bind(QuestAddon, "Quests")

-- Push quest objective pins onto the Map module's "Quests" layer when
-- the map asks for a refresh.
Carbonite.Core.EventBus:Subscribe("MAP_REFRESH", function()
    local MapMod = Carbonite:GetModule("Map", true)
    if not MapMod then return end
    if not MapMod:DB().profile.ShowQuests then return end
    local Nx = _G.Nx
    if not Nx or not Nx.Quest or not Nx.Quest.Watched then return end

    local layer = MapMod:GetLayer("Quests")
    layer:Clear()

    for _, q in pairs(Nx.Quest.Watched) do
        if q.mapID and q.x and q.y then
            MapMod:AddPin("Quests", "Quest", {
                mapID   = q.mapID,
                x       = q.x,
                y       = q.y,
                questID = q.id,
                role    = q.role or "objective",
                title   = q.title,
            })
        end
    end
end)
