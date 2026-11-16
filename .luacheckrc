-- luacheck config for the Forever edition. The lint starts with the files the edition owns
-- (see the workflow); the inherited code joins as it is cleaned up.
std = "lua51"
max_line_length = false
unused_args = false

-- Addon and client globals the edition files read.
read_globals = {
    "Nx", "Carbonite", "LibStub", "VoiceOver",
    "C_Map", "C_Timer", "C_QuestLog", "C_SkillInfo", "Enum",
    "CreateFrame", "GetInstanceInfo", "GetQuestLogTitle", "GetNumQuestLogEntries",
    "GetQuestLogIndexByID", "GetTime", "InCombatLockdown", "IsInInstance", "UnitFactionGroup", "UnitLevel",
    "Minimap", "MinimapCluster", "UIParent", "WorldFrame", "GameTooltip",
    "debugprofilestop", "hooksecurefunc", "issecretvalue", "securecall", "strsplit",
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
    "Carbonite/Modules/Map/UnmappedInstance.lua",
}
