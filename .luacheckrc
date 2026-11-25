-- luacheck config for the Forever edition. The lint starts with the files the edition owns
-- (see the workflow); the inherited code joins as it is cleaned up.
std = "lua51"
max_line_length = false
unused_args = false

-- Addon and client globals the edition files read.
read_globals = {
    "Nx", "Carbonite", "LibStub", "VoiceOver",
    "C_Map", "C_NamePlate", "C_Timer", "C_QuestLog", "C_SkillInfo", "Enum",
    "CreateFrame", "GetInstanceInfo", "GetQuestLogTitle", "GetNumQuestLogEntries",
    "GetQuestLogIndexByID", "GetTime", "UnitGUID", "UnitName", "GetRealZoneText", "UnitIsFriend", "UnitRace", "InCombatLockdown", "IsInInstance", "UnitFactionGroup", "UnitLevel", "GetMaxPlayerLevel", "BreakUpLargeNumbers",
    "Minimap", "MinimapCluster", "UIParent", "WorldFrame", "GameTooltip",
    "debugprofilestop", "UnitPosition", "UnitOnTaxi", "GetBindLocation", "C_Item", "C_Container", "CombatLogGetCurrentEventInfo", "hooksecurefunc", "issecretvalue", "securecall", "strsplit",
    "format", "max", "min", "floor", "ceil", "abs", "tinsert", "tremove", "wipe",
}

files["tests/"] = {
    std = "lua51+busted",
    globals = { "describe", "it", "expect", "loader", "wow" },
}
files["tests/support/"] = { std = "lua51" }

-- Files linted by `luacheck .` (the CI runs exactly that). Add a file here once it is clean.
include_files = {
    "tests/**/*.lua",
    "Carbonite.Quests/QuestieSource.lua",
    "Carbonite.Quests/SpokenPlay.lua",
    "Carbonite.Quests/Nameplates.lua",
    "Carbonite.Quests/ForeverCoreColumn.lua",
    "Carbonite.Quests/ObjectiveAreas.lua",
    "Carbonite.Notes/Integrations/TomTomArrow.lua",
    "Carbonite/Modules/Map/BlizzardPin.lua",
    "Carbonite/Modules/Map/ZoneFishing.lua",
    "Carbonite.Notes/Integrations/ForeverPoints.lua",
    "Carbonite/Modules/Map/UnmappedInstance.lua",
    "Carbonite/Modules/Map/DungeonGuide.lua",
    "Carbonite/Modules/Map/DungeonPins.lua",
    "Carbonite/Modules/Map/DungeonRoutes.lua",
    "Carbonite/Modules/Map/DungeonRouteCodec.lua",
    "Carbonite/Modules/Map/DungeonRouteRecorder.lua",
    "Carbonite/Modules/Map/DungeonRouteShare.lua",
    "Carbonite/Modules/Map/DungeonRouteEditor.lua",
    "Carbonite.Dungeons/Load.lua",
    "Carbonite/Modules/Map/Battleground.lua",
    "Carbonite/Modules/Map/ViewState.lua",
    "Carbonite/Modules/Travel/FlightTimes.lua",
    "Carbonite/Modules/Map/Transports.lua",
    "Carbonite/Modules/Journey/Journey.lua",
    "Carbonite/Modules/Comm/VersionCheck.lua",
    "Carbonite/Modules/Map/TargetsWindow.lua",
    "Carbonite/Modules/Assistant/Assistant.lua",
    "Carbonite/UI/SearchBox.lua",
    "Carbonite/Modules/Map/GroundRoute.lua",
    "Carbonite/Modules/Travel/Teleports.lua",
    "Carbonite/Util/Distance.lua",
    "Carbonite/Modules/Map/IconStyle.lua",
    "Carbonite/Modules/Map/Motion.lua",
}
