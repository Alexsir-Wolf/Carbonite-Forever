-- Carbonite | Core / SlashCommands
-- The only router for /carb (alias /cb). Modules register subcommands
-- with SlashCommands:Register("map", handler, help); developer tools
-- go under /carb debug with SlashCommands:RegisterDebug. The help
-- (/carb ajuda) is generated from these registrations, and each help
-- text is an English locale key, translated when the list is shown.

local Carbonite = _G.Carbonite
local L = LibStub("AceLocale-3.0"):GetLocale("Carbonite")

local SlashCommands = {}
Carbonite.Core.SlashCommands = SlashCommands

local commands = {}
local debugCommands = {}

function SlashCommands:Register(cmd, fn, help)
    commands[cmd:lower()] = { fn = fn, help = help }
end

function SlashCommands:RegisterDebug(cmd, fn, help)
    debugCommands[cmd:lower()] = { fn = fn, help = help }
end

local function say(text)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(text) end
end

local function printList(title, list, prefix)
    say("|cffc0c0ff" .. title .. "|r")
    local names = {}
    for name, entry in pairs(list) do
        if entry.help then names[#names + 1] = name end
    end
    table.sort(names)
    for _, name in ipairs(names) do
        say(("  %s %s - %s"):format(prefix, name, L[list[name].help]))
    end
end

local HELP = { [""] = true, ["?"] = true, help = true, ajuda = true }

local function run(list, cmd, rest)
    local entry = list[cmd]
    if entry then
        entry.fn(rest)
    else
        say(L["Unknown command: %s (see /carb help)"]:format(cmd))
    end
end

function SlashCommands.Dispatch(input)
    input = (input or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local cmd, rest = input:match("^(%S*)%s*(.*)$")
    cmd = cmd:lower()
    if HELP[cmd] then
        printList(L["Carbonite commands:"], commands, "/carb")
        say("  /carb debug - " .. L["developer and diagnostic commands"])
    elseif cmd == "debug" then
        local sub, subRest = rest:match("^(%S*)%s*(.*)$")
        sub = sub:lower()
        if HELP[sub] then
            printList(L["Carbonite debug commands:"], debugCommands, "/carb debug")
        else
            run(debugCommands, sub, subRest)
        end
    else
        run(commands, cmd, rest)
    end
end

function SlashCommands:Init()
    -- Blizzard imports aliases as _G["SLASH_" .. key .. index], so the key
    -- ends in a letter to keep "<key><index>" unambiguous.
    _G.SLASH_CARBONITECMD1 = "/carb"
    _G.SLASH_CARBONITECMD2 = "/cb"
    _G.SlashCmdList["CARBONITECMD"] = SlashCommands.Dispatch
end

SlashCommands:RegisterDebug("log", function()
    local Logger = Carbonite.Core.Logger
    if Logger.minLevel == Logger.LEVEL.DEBUG then
        Logger:SetLevel("INFO")
        Logger:info("debug logging OFF")
    else
        Logger:SetLevel("DEBUG")
        Logger:info("debug logging ON")
    end
end, "toggle debug logging")

Carbonite.Core.EventBus:Subscribe("CARBONITE_ENABLE", function()
    SlashCommands:Init()
end)
