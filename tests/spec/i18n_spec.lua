-- Addon in pt-BR and en-US by the client language (#50): every visible text goes through the
-- module's AceLocale, every key used in the code exists in enUS and ptBR, and enUS has no
-- key the code does not use.

-- Namespace -> locale files. Zones, HarvestNodes and FlightMasters hold names from the game
-- client: pt-BR falls back to English where the translated name is not known.
local NAMESPACES = {
    ["Carbonite"] = {
        ui = { "Bindings", "Com", "Guide", "Main", "Map", "Options" },
        names = { "FlightMasters", "HarvestNodes", "Zones" },
        path = function(locale, name) return "Carbonite/Locales/" .. locale .. "/" .. name .. ".lua" end,
    },
    ["Carbonite.Quest"] = { file = "Carbonite.Quests" },
    ["Carbonite.Notes"] = { file = "Carbonite.Notes" },
    ["Carbonite.Warehouse"] = { file = "Carbonite.Warehouse" },
    ["Carbonite.Info"] = { file = "Carbonite.Info" },
}

-- Developer tools, out of scope: the profiler (its report goes into bug reports as is), the
-- /carb debug flags and the sample plugin.
local SKIP = {
    "^Carbonite/Modules/Diagnostics/",
    "^Carbonite/Modules/DebugFlags/",
    "^Carbonite%.Notes/API sample/",
}

-- Text that is not translated on purpose, per file: names from the game or from other
-- addons, internal identifiers that look like words, and output of /carb debug commands.
-- An entry starting with "^" is a Lua pattern.
local ALLOWED = {
    ["Carbonite/Core/SlashCommands.lua"] = { "  /carb debug - " },
    -- /carb debug comt and the channel log of the Com list.
    ["Carbonite/Modules/Comm/AddonPrefix.lua"] = {
        "Carbonite core wire format (position / target / quest sync)",
        "Cross-plugin module sync (Notes, Warehouse, Quests)", "(plugin registered)",
    },
    ["Carbonite/Modules/Comm/CommEngine.lua"] = {
        "CJ:", "CN:", "CL:", "OnJoinChanATimer", "ComZ", "OnJoinChanZTimer ",
        "^Com self:", "^  self keys:", "  no remote player entries",
    },
    -- Gather type ids compared with the profession names in the data.
    ["Carbonite/Modules/Gather/Gather.lua"] = { "Herb Gathering" },
    -- Descriptions listed only by /carb debug bindings.
    ["Carbonite/Modules/HotkeyBindings/HotkeyBindings.lua"] = { "^Toggle ", "^Restore ", "^Skip ",
        "^Clear ", "^Open ", "^Show or hide " },
    ["Carbonite/Modules/InitFlow/SetupPipeline.lua"] = { "Airship Alliance", "Airship Horde" },
    ["Carbonite/Modules/Integrations/LDBEngine.lua"] = { "data source" },
    -- Prefix of a dialog whose text is translated.
    ["Carbonite/Modules/ItemRegistry/ItemEngine.lua"] = { "Carbonite:\\n|cffffff60" },
    ["Carbonite/Modules/Map/AddonButtons.lua"] = { "RareScanner General", "Questie", "HandyNotes",
        "RareScanner", "GatherLite" },
    -- Profiling (/carb debug), the quest objective editor (/carb debug editmode) and the
    -- vehicle dump (/carb debug vehpos).
    -- Placeholder name in the route data, replaced by the kind of vessel.
    ["Carbonite/Modules/Map/Transports.lua"] = { "Unnamed Vessel" },
    ["Carbonite/Modules/Map/MapEngine.lua"] = {
        "^Map:Update ", "^.-Quest Objective", "^.-Ctrl%+Alt%+Click", "^.-Click %[X%]", "Finish",
        "Output all rectangles to chat", "and clear the editor", "Clear", "^.-All rectangles cleared",
        "Clear all rectangles", "without outputting", "^.-Point %%d added", "^.-Rectangle ",
        "^.-No items to output", "^.-Map ID: ", "^.-Raw coordinates:", "^.-Quest database format", "^.-%] POINT ", "^.-%] RECT ",
        "^.-Hex%-encoded rectangles", "^.-Output complete", "no type", "^View3D=", "^heights=",
        "^MapId=", "^first label area",
    },
    ["Carbonite/Modules/Options/Options.lua"] = { "Carbonite-Forever" },
    ["Carbonite/Modules/Options/OptionsEngine.lua"] = {
        "Carbonite-Forever", "EditItem error (%s)",
        -- Expansion names, as the pt-BR client shows them.
        "|cff1eff00The Burning Crusade|r", "|cff0070ddWrath of the Lich King|r", "|cffa335eeCataclysm|r",
        "|cff00ff96Mists of Pandaria|r", "|cffff8000Warlords of Draenor|r", "|cffe268a8Legion|r",
        "|cff4169e1Battle for Azeroth|r", "|cff9370dbShadowlands|r", "|cff33937fDragonflight|r",
        "|cff00ccffThe War Within|r", "|cffaa00ffMidnight|r",
    },
    ["Carbonite/Modules/SlashHandler/SlashCommandEngine.lua"] = { "Item: %s %s" },
    -- Gaps in the flight data, printed for the data maintainers.
    ["Carbonite/Modules/Travel/TravelEngine.lua"] = { "^Travel: missing ", "Taxi #%s %s, %s %f %f" },
    -- Font names.
    ["Carbonite/Modules/UI/UIEngine.lua"] = { "Arial Narrow", "Friz Quadrata TT" },
    ["Carbonite/UI/Font.lua"] = { "Arial Narrow", "Friz Quadrata TT" },
    -- Teleport icons keyed by zone, class name fixes and currency names from the game.
    ["Carbonite/Data/Shared/NxMapGuide.lua"] = {
        "Blasted Lands", "The Exodar", "Isle of Quel'Danas", "Lake Wintergrasp", "Silvermoon City",
        "Stormwind City", "Thunder Bluff", "Demon Hunter", "CapTimer retry", "Badge of Justice",
        "Holy Dust", "Arcane Rune", "Apexis Shard", "Apexis Crystal", "Emblem of Heroism",
        "Emblem of Valor", "Stone Keeper's Shard", "Abyss Crystal", "Dream Shard",
        "Heavy Borean Leather", "Arctic Fur", "^.- Token$",
    },
    -- Class names compared with the API, the options page id and loot patterns of the
    -- English client.
    ["Carbonite.Info/NxInfo.lua"] = { "Death Knight", "Info Windows", "Honor Points%.", "Honor Points x(%d+)" },
    ["Carbonite.Warehouse/Init.lua"] = { "Death Knight" },
    -- Prefixes of English task titles, removed from the title.
    ["Carbonite.Quests/MapIcons.lua"] = { "Daily Objective: ", "Bonus Objective: " },
    -- Pattern built from the client's ITEM_LEVEL, with a fallback that never matches.
    ["Carbonite.Quests/NxQuest.lua"] = { "NO DATA FOR ITEM_LEVEL" },
    -- Reasons kept in the capture log and in the tracking trace.
    ["Carbonite.Quests/ObjectiveCapture.lua"] = { "no Cap2 in SavedVariables at first use",
        "format version %s, expected %s", "%s (parked %d quests in NXQuest.Cap2Old)" },
    ["Carbonite.Quests/Tracking.lua"] = { "^%%%.3f   %.%.%.block above", "objective is inside a dungeon, no position",
        "no position", "inside a dungeon without a map", "  Tracking is empty" },
    ["Carbonite.Quests/QuestCatalog.lua"] = { "Carbonite bundled quest data" },
    -- Technical detail appended to a translated warning.
    ["Carbonite.Quests/QuestieSource.lua"] = { "^QuestieDB has no " },
    ["Carbonite.Quests/SpokenPlay.lua"] = { "Carbonite's watch list", "Carbonite's quest log", " is missing" },
    -- Faction, place and NPC names from the game, compared with the client's text.
    ["Carbonite.Quests/TrackerHider.lua"] = {
        "Argent Crusade", "Argent Dawn", "Ashtongue Deathsworn", "Bloodsail Buccaneers", "Booty Bay",
        "Brood of Nozdormu", "Cenarion Circle", "Cenarion Expedition", "Darkmoon Faire",
        "Darkspear Trolls", "Frenzyheart Tribe", "Frostwolf Clan", "Gelkis Clan Centaur",
        "Gnomeregan Exiles", "Honor Hold", "Hydraxian Waterlords", "Keepers of Time", "Kirin Tor",
        "Knights of the Ebon Blade", "Lower City", "Magram Clan Centaur", "Sha'tari Skyguard",
        "Shattered Sun Offensive", "Silvermoon City", "Silverwing Sentinels", "Stormpike Guard",
        "^The ", "Thorium Brotherhood", "Thunder Bluff", "Timbermaw Hold", "Valiance Expedition",
        "Warsong Offensive", "Warsong Outriders", "Wildhammer Clan", "Wintersaber Trainers",
        "Zandalar Tribe", "Lumber Mill", "Gold Mine", "Bloodberry Bush", "Erratic Sentry",
        "Erratic Sentries",
    },
    -- Item names of the Alchemist's Apprentice quest, compared with the client's text.
    ["Carbonite.Quests/Tooltips.lua"] = {
        "Abomination Guts", "Ancient Ectoplasm", "Blight Crystal", "Chilled Serpent Mucus",
        "Crushed Basilisk Crystals", "Crystallized Hogsnot", "Frozen Spider Ichor", "Ghoul Drool",
        "Hairy Herring Head", "Icecrown Bottled Water", "Muddy Mire Maggots", "Pickled Eagle Egg",
        "Prismatic Mojo", "Pulverized Gargoyle Teeth", "Putrid Pirate Perspiration", "Raptor Claw",
        "Seasoned Slider Cider", "Shrunken Dragon's Claw", "Speckled Guano", "Spiky Spider Egg",
        "Withered Batwing",
    },
    -- Atlas pattern and the /carb debug qwtest output.
    ["Carbonite.Quests/WatchWindow.lua"] = {
        "|A:professions%-icon%-quality[^:|]-tier(%d+)%-questobjective:[^|]*|a", "^atlas API: ",
        "^modern look available: ", "^.-icon test %(/carb debug", "complete, no turn-in coords",
        "in progress", "in progress, super-tracked", "no objectives, tracked", "in progress, no data",
        "^Sync=", "^AddQuestWatch global=", "^win mode=", "^list size=", "^list offset in win:",
        "^row %%d data=", "no CurQ",
    },
    -- Gather node names from the game, read through L[name].
    ["Carbonite/Modules/Gather/GatherStorage.lua"] = {
        "^.-Argentleaf$", "^.-Azeroot$", "^.-Mana Lily$", "^.-Sanguithorn$", "^.-Tranquility Bloom$",
        "^.-Brilliant Silver$", "^.-Refulgent Copper$", "^.-Umbral Tin$",
    },
}

-- pt-BR text equal to the English one on purpose: names of places, factions, addons and
-- translators, words spelled the same in Portuguese, abbreviations, debug formats and
-- patterns matched against chat text of the English client.
local SAME = {}
for _, key in ipairs({
    "Everfrost", "Grace Loom", "Zandalar", "Nazjatar", "Khaz Algar", "CARBONITE", "Forever", "Blizzard",
    "Ogri'la", "Kirin Tor", "frFR - powerstrk", "deDE - atl77 & samyonair", "itIT - ThorwaldOdin",
    "ruRU - NotDead", "zhCN - Raka-loah", "zhTW - kc305chen",
    "Solo", "Menu", "Menus", "Total", "arena", "Ok", "Neon", "Bronze", "Item %d",
    "XP", "iLevel", "Ctrl+C:", "Wowhead (Ctrl+C):",
    " LR %f, %f", " BT %f, %f", "%s#%d %s ID%s (%s) show%d l%d x%d y%d", "!BUT %s", "XOff", "YOff",
    "PXOff", "PYOff", "ZWOff", "ZHOff", "LOOT_OPENED %s (%s %s)",
    " begins? in (%d+) ", "(%d+) minutes? until the battle",
}) do SAME[key] = true end

-- Blocks of dead code, from the line matching the first pattern to the line matching the
-- second: the guide's item browser needs the CarboniteItems addon, which no longer exists,
-- and its folder is commented out.
local SKIP_BLOCKS = {
    ["Carbonite/Data/Shared/NxMapGuide.lua"] = {
        { "^Nx%.Map%.Guide%.ItemCats = {", "^function Nx%.Map%.Guide:UnpackObjective" },
    },
}

-- Lines of a file inside a SKIP_BLOCKS block.
local function skippedLines(path, src)
    local out = {}
    for _, block in ipairs(SKIP_BLOCKS[path] or {}) do
        local n, inside = 0, false
        for line in (src .. "\n"):gmatch("([^\n]*)\n") do
            n = n + 1
            if line:find(block[1]) then inside = true end
            if line:find(block[2]) then inside = false end
            if inside then out[n] = true end
        end
    end
    return out
end

local function listFiles()
    local out = {}
    local p = io.popen('find . -name "*.lua" -not -path "./.git/*" -not -path "./.claude/*" -not -path "./tests/*" '
        .. '-not -path "*/Libs/*" -not -path "*/Locales/*" -not -path "./docs/*" | sort')
    for line in p:lines() do out[#out + 1] = (line:gsub("^%./", "")) end
    p:close()
    return out
end

local function skippedFile(path)
    for _, pat in ipairs(SKIP) do
        if path:find(pat) then return true end
    end
    return false
end

-- Splits source into string literals, skipping comments. Each literal comes with its line
-- number, the code before it on that line and the code after it.
local function literals(src)
    local out, i, n, line = {}, 1, #src, 1
    local function lineStart(pos)
        local s = pos
        while s > 1 and src:sub(s - 1, s - 1) ~= "\n" do s = s - 1 end
        return s
    end
    while i <= n do
        local c = src:sub(i, i)
        if c == "\n" then
            line = line + 1; i = i + 1
        elseif c == "-" and src:sub(i, i + 1) == "--" then
            local eq = src:match("^%[(=*)%[", i + 2)
            if eq then
                local close = src:find("]" .. eq .. "]", i, true)
                local stop = close and close + #eq + 1 or n
                for _ in src:sub(i, stop):gmatch("\n") do line = line + 1 end
                i = stop + 1
            else
                local nl = src:find("\n", i, true) or n + 1
                i = nl
            end
        elseif c == '"' or c == "'" then
            local j = i + 1
            while j <= n do
                local d = src:sub(j, j)
                if d == "\\" then j = j + 2
                elseif d == c or d == "\n" then break
                else j = j + 1 end
            end
            local ls = lineStart(i)
            local le = src:find("\n", j, true) or n + 1
            out[#out + 1] = { text = src:sub(i + 1, j - 1), quote = c, line = line,
                before = src:sub(ls, i - 1), after = src:sub(j + 1, le - 1),
                src = src, pos = i }
            i = j + 1
        elseif c == "[" and src:match("^%[=*%[", i) then
            local eq = src:match("^%[(=*)%[", i)
            local close = src:find("]" .. eq .. "]", i, true)
            local stop = close and close + #eq + 1 or n
            for _ in src:sub(i, stop):gmatch("\n") do line = line + 1 end
            i = stop + 1
        else
            i = i + 1
        end
    end
    return out
end

-- Locale keys as written in the source (escapes kept) -> value, for one locale.
local function localeKeys(ns, locale, which)
    local def, files = NAMESPACES[ns], {}
    if def.file then
        files[1] = def.file .. "/Locales/" .. locale .. ".lua"
    else
        for _, name in ipairs(which == "names" and def.names or def.ui) do files[#files + 1] = def.path(locale, name) end
    end
    local out = {}
    for _, path in ipairs(files) do
        for line in loader.read(path):gmatch("[^\n]+") do
            local key, value = line:match('^%s*L%[%s*"(.-)"%s*%]%s*=%s*(.-)%s*$')
            if key then out[key] = value end
        end
    end
    return out
end

local function namespaceOf(src)
    return src:match('GetLocale%(%s*["\']([%w%.]+)["\']') or (src:find("Carbonite:L()", 1, true) and "Carbonite")
end

-- Literal spelled as a double-quoted Lua key.
local function asKey(lit)
    if lit.quote == '"' then return lit.text end
    return (lit.text:gsub("\\'", "'"):gsub('"', '\\"'))
end

-- Up to n characters of code before the literal.
local function context(lit, n)
    return lit.src:sub(math.max(1, lit.pos - n), lit.pos - 1)
end

local function isKeyUse(lit)
    return lit.before:match("%f[%w_]L%[%s*$") and lit.after:match("^%s*%]")
end

-- Help text of /carb subcommands: an English locale key translated when listed.
local function isHelpKey(lit)
    if not lit.after:match("^%s*%)") then return false end
    local before = context(lit, 3000)
    if not before:match(",%s*$") then return false end
    local last
    for pos in before:gmatch("()Register") do last = pos end
    local call = last and before:sub(last)
    return call and call:match('^Register%a*%s*%(%s*"[^"]*"%s*,') and (call:match("^Register%s*%(")
        or call:match("^RegisterDebug%s*%(")) and true or false
end

-- Code whose text only reaches developers: debug flags and prints, errors, the logger.
local DEBUG_CODE = {
    "prtD", "Debug", "debug", "dbg", "error%s*%(", "assert%s*%(", "log:%a+%s*%(", "Logger",
}

-- Calls whose string arguments are shown to the player.
local CALL_SINKS = {
    "[%.:]prt%s*%(%s*$", "[%.:]prt%s*%(%s*format%s*%(%s*$", "^%s*prt%s*%(%s*$",
    ":SetText%s*%(%s*$", ":SetFormattedText%s*%(%s*$",
    ":AddLine%s*%(%s*$", ":AddDoubleLine%s*%(%s*$", "AddNormalLine%s*%([^,]*,%s*$",
    ":AddMessage%s*%(%s*$", ":AddItem%s*%([^,]*,%s*$", ":ColumnAdd%s*%(%s*$",
    ":SetTitle%s*%(%s*$", ":ShowMessage%s*%(", ":AddInfo%s*%(%s*",
}

-- Table fields whose string value is shown to the player.
local FIELD_SINKS = {
    "%f[%w_]name%s*=%s*$", "%f[%w_]desc%s*=%s*$", "%f[%w_]text%s*=%s*$", "%f[%w_]label%s*=%s*$",
    "%f[%w_]title%s*=%s*$", "%f[%w_]tooltip%s*=%s*$", "%f[%w_]tip%s*=%s*$", "NxTip%s*=%s*$",
    "%f[%w_]button%d%s*=%s*$", "%f[%w_]confirmText%s*=%s*$",
}

local function strip(text)
    return (text:gsub("|c%x%x%x%x%x%x%x%x", " "):gsub("|r", " "):gsub("|T.-|t", " ")
        :gsub("\n", " "):gsub("%%[-%d.]*[sdfxi]", " "))
end

local function matchesAny(text, patterns)
    for _, pat in ipairs(patterns) do
        if text:find(pat) then return true end
    end
    return false
end

local FILES = listFiles()
local SOURCES, LITERALS = {}, {}
for _, path in ipairs(FILES) do
    SOURCES[path] = loader.read(path)
    LITERALS[path] = literals(SOURCES[path])
end

local EN, PT, NAMES = {}, {}, {}
for ns, def in pairs(NAMESPACES) do
    EN[ns], PT[ns] = localeKeys(ns, "enUS", "ui"), localeKeys(ns, "ptBR", "ui")
    NAMES[ns] = def.names and localeKeys(ns, "enUS", "names") or {}
end

local function translated(ns, key)
    return ns and EN[ns][key] and PT[ns][key] and PT[ns][key] ~= "true"
end

-- Text a player would read: words with spaces, or a capitalized word in a visible call or
-- field. A literal that is itself a translated key is read through L[var] (option values,
-- action labels), so it passes outside a visible call.
local function visible(ns, lit)
    ns = ns or "Carbonite"
    if isKeyUse(lit) or isHelpKey(lit) then return false end
    local text = lit.text
    if text:find("\\\\") or text:find("Interface[/\\]") or text:find("%.tga") or text:find("%.blp") then return false end
    local fallback = lit.before:match('L%[%s*"(.-)"%s*%]%s*%)?%s*or%s*$')
    if fallback and fallback == asKey(lit) then return false end
    -- The line itself and the two before it (an `if Debug then` guard).
    local before = context(lit, 400)
    local near = (before:match("[^\n]*\n[^\n]*\n[^\n]*$") or before) .. lit.after
    if matchesAny(near, DEBUG_CODE) then return false end
    local inCall = matchesAny(lit.before, CALL_SINKS)
    if translated(ns, asKey(lit)) and not inCall then return false end
    local plain = strip(text)
    if plain:find("%a%a+%s+%a%a+") then return true end
    if plain:find("^%s*%u%l+") or plain:find("%a%a+[:!?]%s*$") then
        return inCall or matchesAny(lit.before, FIELD_SINKS)
    end
    return false
end

local function allowed(path, text)
    for _, entry in ipairs(ALLOWED[path] or {}) do
        if entry == text or (entry:sub(1, 1) == "^" and text:find(entry)) then return true end
    end
    return false
end

local function namespace(path)
    local src = SOURCES[path]
    local ns = namespaceOf(src)
    if not NAMESPACES[ns] or src:find("local L = Nx%.Quest") then return nil end
    return ns
end

describe("textos visíveis", function()
    it("passam pelo L[...] do módulo", function()
        local found = {}
        for _, path in ipairs(FILES) do
            if not skippedFile(path) and (not path:find("/Data/") or path:find("NxMapGuide")) then
                local ns = namespace(path)
                local skipped = skippedLines(path, SOURCES[path])
                for _, lit in ipairs(LITERALS[path]) do
                    if not skipped[lit.line] and visible(ns, lit) and not allowed(path, lit.text) then
                        found[#found + 1] = path .. ":" .. lit.line .. ": " .. lit.text
                    end
                end
            end
        end
        expect(table.concat(found, "\n")).toBe("")
    end)
end)

describe("chaves de tradução", function()
    local used, missing, unknown = {}, {}, {}
    for ns in pairs(NAMESPACES) do used[ns] = {} end
    local function check(ns, path, lit)
        local key = asKey(lit)
        used[ns][key] = true
        if not NAMES[ns][key] and not translated(ns, key) then
            missing[#missing + 1] = ns .. " " .. path .. ":" .. lit.line .. ": " .. key
                .. (EN[ns][key] and "" or " [enUS]") .. ((PT[ns][key] and PT[ns][key] ~= "true") and "" or " [ptBR]")
        end
    end
    for _, path in ipairs(FILES) do
        local found = namespaceOf(SOURCES[path])
        if found and not NAMESPACES[found] then unknown[#unknown + 1] = path .. ": " .. found end
        local ns = namespace(path)
        for _, lit in ipairs(LITERALS[path]) do
            if isHelpKey(lit) then
                -- SlashCommands translates the help with the core namespace.
                check("Carbonite", path, lit)
            elseif ns and isKeyUse(lit) then
                check(ns, path, lit)
            end
        end
    end

    it("todo arquivo usa um namespace conhecido", function()
        expect(table.concat(unknown, "\n")).toBe("")
    end)

    it("toda chave usada existe em enUS e ptBR", function()
        table.sort(missing)
        expect(table.concat(missing, "\n")).toBe("")
    end)

    it("enUS não tem chave sem uso", function()
        -- Keys also count as used when the code names them in a table read through L[var].
        local literal = {}
        for _, path in ipairs(FILES) do
            for _, lit in ipairs(LITERALS[path]) do literal[asKey(lit)] = true end
        end
        local unused = {}
        for ns in pairs(NAMESPACES) do
            for key in pairs(EN[ns]) do
                if not used[ns][key] and not literal[key] then unused[#unused + 1] = ns .. ": " .. key end
            end
        end
        table.sort(unused)
        expect(table.concat(unused, "\n")).toBe("")
    end)

    it("ptBR só repete o inglês em nomes, siglas e palavras iguais nas duas línguas", function()
        local english = {}
        for ns in pairs(NAMESPACES) do
            for key, value in pairs(PT[ns]) do
                local en = EN[ns][key]
                local text = en == "true" and key or en and en:match('^"(.*)"$')
                if text and value == '"' .. text .. '"' and text:find("%a%a") and not SAME[key] then
                    english[#english + 1] = ns .. ": " .. key
                end
            end
        end
        table.sort(english)
        expect(table.concat(english, "\n")).toBe("")
    end)

    it("ptBR não tem chave que o enUS não tem", function()
        local extra = {}
        for ns in pairs(NAMESPACES) do
            for key in pairs(PT[ns]) do
                if not EN[ns][key] and not NAMES[ns][key] then extra[#extra + 1] = ns .. ": " .. key end
            end
        end
        table.sort(extra)
        expect(table.concat(extra, "\n")).toBe("")
    end)
end)
