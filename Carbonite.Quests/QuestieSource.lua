-- Carbonite.Quests | QuestieSource
-- Quests the Forever client has and Carbonite's camelot data lacks, read from QuestieDB.
--
-- Carbonite's camelot quest data was generated offline from an older Questie export, and
-- Forever keeps adding quests. QuestieDB (a library addon, usable without Questie) carries the
-- current Forever data behind a versioned API: `LibQuestieDB`, contract 4. Once Carbonite has
-- processed its own data (Nx.Quest:ProcessQuestDB), this module converts every QuestieDB quest
-- Carbonite does not have into Carbonite's record format and adds it, with the same indexes
-- ProcessQuestDB builds (sorted list, quest givers per map, chains), so the map, the watch list,
-- Goto and the quest window treat it like any other quest.
--
-- * Carbonite's own records are never changed. A record Carbonite synthesized from the quest
--   log for a quest it had no data for (header starting "[[", Tooltips.lua) is replaced.
-- * The work runs in batches over frames; quests in the player's log go first. No chat output
--   except one line when the installed QuestieDB speaks an incompatible contract.
-- * Nothing runs without QuestieDB. Loaded by the Forever (camelot) TOC only.
--
-- Record format written (DataAndComm.lua Unpack / UnpackSE / ParseLoc):
--   Quest      "name|side|level|minLevel|nextId|0|0"   side 1 Alliance, 2 Horde, 3 both
--   Start/End  "name|uiMapID|32|x|y"                   name literal: new NPCs are in no
--                                                      Carbonite table, NPC/object ids collide
--   Objectives { [n] = { "desc|uiMapID|32|x|y", ... } }
--
-- Public (on Nx.Quest.QuestieSource, for tests and diagnostics):
--   QS.Convert(qId)      Carbonite record for one QuestieDB quest, or nil
--   QS:Start()           convert and add the missing quests (runs after ProcessQuestDB)
--   QS.added             quest ids added by the last completed run

local Nx = _G.Nx
if not Nx or not Nx.Quest then return end

local QS = {}
Nx.Quest.QuestieSource = QS

local floor, format, max, min = math.floor, string.format, math.max, math.min
local ipairs, pairs, pcall, tostring, type = ipairs, pairs, pcall, tostring, type
local sort, tinsert = table.sort, table.insert

local CONTRACT = 4
local BATCH = 50
local MAX_POINTS = 20
local BOTH_SIDES = 3

local built = {}        -- qId -> record, or false when it cannot be converted
local spawnCache = {}   -- "Npc:id" / "Object:id" -> spawns table or false
local zoneMap, zoneParents
local said, generation = false, 0

QS.added = {}

local function Say(msg)
    if said then return end
    said = true
    Nx.prt("QuestieDB quests not added: %s", tostring(msg))
end

--------------------------------------------------------------------------------------------
-- QuestieDB access
--------------------------------------------------------------------------------------------

local function DecodeTable(src)
    if type(src) == "table" then return src end
    if type(src) ~= "string" or not loadstring then return {} end
    local fn = loadstring(src)
    if not fn then return {} end
    local ok, t = pcall(fn)
    return ok and type(t) == "table" and t or {}
end

-- AreaTable ids (QuestieDB's spawn and zone keys) to uiMapIDs (Carbonite's maps), from the
-- conversion data QuestieDB ships for Questie's ZoneDB: base table, then its overrides.
local function LoadZones(lib)
    local zoneDB = lib.Support and lib.Support.Get and lib.Support.Get("ZoneDB")
    local private = type(zoneDB) == "table" and zoneDB.private
    if type(private) ~= "table" then return false end
    zoneMap = DecodeTable(private.areaIdToUiMapId)
    for areaId, uiMapId in pairs(DecodeTable(private.areaIdToUiMapIdOverride)) do
        zoneMap[areaId] = uiMapId
    end
    zoneParents = DecodeTable(private.subZoneToParentZone)
    for areaId, parentId in pairs(DecodeTable(private.subZoneToParentZoneOverride)) do
        zoneParents[areaId] = parentId
    end
    return next(zoneMap) ~= nil
end

-- The installed LibQuestieDB, or nil. An incompatible one is said once.
local function Lib()
    local lib = _G.LibQuestieDB
    if type(lib) ~= "table" then return nil end
    if type(lib.RequireContract) ~= "function" then
        Say("QuestieDB has no RequireContract")
        return nil
    end
    local ok, compatible, msg = pcall(lib.RequireContract, CONTRACT)
    if not ok or not compatible then
        Say(ok and msg or compatible)
        return nil
    end
    for _, name in ipairs({ "Quest", "Npc", "Object", "Item" }) do
        if type(lib[name]) ~= "table" or type(lib[name].Get) ~= "function" then
            Say("QuestieDB has no " .. name .. ".Get")
            return nil
        end
    end
    if not zoneMap and not LoadZones(lib) then
        Say("QuestieDB has no zone conversion data")
        return nil
    end
    return lib
end

local function Get(lib, entity, id, key)
    local ok, value = pcall(lib[entity].Get, id, key)
    if ok then return value end
end

local function Spawns(lib, entity, id)
    local key = entity .. ":" .. tostring(id)
    local spawns = spawnCache[key]
    if spawns == nil then
        spawns = Get(lib, entity, id, "spawns")
        spawns = type(spawns) == "table" and spawns or false
        spawnCache[key] = spawns
    end
    return spawns or nil
end

local function Clean(text)
    if type(text) ~= "string" then return nil end
    text = text:gsub("|", "")
    return text ~= "" and text or nil
end

--------------------------------------------------------------------------------------------
-- Conversion
--------------------------------------------------------------------------------------------

-- uiMapID of an AreaTable id, when Carbonite has that map.
local function UiMap(areaId)
    local uiMapId = zoneMap[areaId]
    if not uiMapId and zoneParents[areaId] then uiMapId = zoneMap[zoneParents[areaId]] end
    local worldInfo = Nx.Map and Nx.Map.MapWorldInfo
    if type(uiMapId) == "number" and uiMapId > 0 and worldInfo and worldInfo[uiMapId] then
        return uiMapId
    end
end

local function SortedKeys(t)
    local keys = {}
    for k in pairs(t) do
        if type(k) == "number" then keys[#keys + 1] = k end
    end
    sort(keys)
    return keys
end

-- Spawns are { [areaId] = { {x, y, phase?}, ... } } in percent; -1,-1 means inside an
-- instance. Points on the quest's own map come first.
local function AddPoints(points, spawns, preferMap, limit)
    if type(spawns) ~= "table" then return end
    local areas = SortedKeys(spawns)
    for pass = 1, 2 do
        for _, areaId in ipairs(areas) do
            local uiMapId = UiMap(areaId)
            if uiMapId and (pass == 1) == (uiMapId == preferMap) then
                for _, p in ipairs(spawns[areaId]) do
                    if #points >= limit then return end
                    local x, y = type(p) == "table" and p[1], type(p) == "table" and p[2]
                    if type(x) == "number" and type(y) == "number" and x >= 0 and y >= 0 then
                        points[#points + 1] = { uiMapId, x, y }
                    end
                end
            end
        end
    end
end

local function Loc(name, point)
    return format("%s|%d|32|%.2f|%.2f", name, point[1], point[2], point[3])
end

-- A side for Carbonite from QuestieDB's race mask. Masks reach bit 33 (Skyborne), past what
-- bit.band handles, so bits are tested arithmetically.
local function HasAnyBit(mask, of)
    for bit = 0, 40 do
        local p = 2 ^ bit
        if p > mask or p > of then return false end
        if mask % (2 * p) >= p and of % (2 * p) >= p then return true end
    end
    return false
end

function QS.Side(races, factionMasks)
    if type(races) ~= "number" or races <= 0 or type(factionMasks) ~= "table" then return BOTH_SIDES end
    local alliance = type(factionMasks.Alliance) == "number" and HasAnyBit(races, factionMasks.Alliance)
    local horde = type(factionMasks.Horde) == "number" and HasAnyBit(races, factionMasks.Horde)
    if alliance and not horde then return 1 end
    if horde and not alliance then return 2 end
    return BOTH_SIDES
end

-- Start or End: the first starter/ender with a spawn Carbonite can show, else a name without
-- a position ("|0|..." is Carbonite's no-coordinates sentinel).
local function StartEnd(lib, ids, preferMap)
    if type(ids) ~= "table" then return nil end
    local fallback
    for group, entity in ipairs({ "Npc", "Object" }) do
        for _, id in ipairs(type(ids[group]) == "table" and ids[group] or {}) do
            local name = Clean(Get(lib, entity, id, "name"))
            if name then
                local points = {}
                AddPoints(points, Spawns(lib, entity, id), preferMap, 1)
                if points[1] then return Loc(name, points[1]) end
                fallback = fallback or format("%s|0|32|0|0", name)
            end
        end
    end
    return fallback
end

-- Objective groups in QuestieDB order: creatures, objects, items; then an area to explore.
local function Objectives(lib, objectives, triggerEnd, preferMap, units)
    local list = {}
    local function add(desc, points)
        if desc and points[1] then
            local locs = {}
            for i, point in ipairs(points) do locs[i] = Loc(desc, point) end
            list[#list + 1] = locs
            return #list
        end
    end
    if type(objectives) == "table" then
        for group, entity in ipairs({ "Npc", "Object", "Item" }) do
            for _, entry in ipairs(type(objectives[group]) == "table" and objectives[group] or {}) do
                local id = type(entry) == "table" and entry[1]
                if type(id) == "number" then
                    local desc = Clean(entry[2]) or Clean(Get(lib, entity, id, "name"))
                    local points = {}
                    if entity == "Item" then
                        for _, npcId in ipairs(Get(lib, "Item", id, "npcDrops") or {}) do
                            AddPoints(points, Spawns(lib, "Npc", npcId), preferMap, MAX_POINTS)
                        end
                        for _, objectId in ipairs(Get(lib, "Item", id, "objectDrops") or {}) do
                            AddPoints(points, Spawns(lib, "Object", objectId), preferMap, MAX_POINTS)
                        end
                    else
                        AddPoints(points, Spawns(lib, entity, id), preferMap, MAX_POINTS)
                    end
                    local n = add(desc, points)
                    if n and entity == "Npc" then units[id] = n end
                end
            end
        end
    end
    if type(triggerEnd) == "table" then
        local points = {}
        AddPoints(points, triggerEnd[2], preferMap, MAX_POINTS)
        add(Clean(triggerEnd[1]), points)
    end
    return list[1] and list or nil
end

local QUEST_KEYS = { "name", "startedBy", "finishedBy", "requiredLevel", "questLevel",
    "requiredRaces", "requiredClasses", "objectives", "triggerEnd", "preQuestGroup",
    "preQuestSingle", "nextQuestInChain", "zoneOrSort" }

-- Carbonite record for one QuestieDB quest, plus what goes into Carbonite's side tables.
-- Nil when the quest has nothing Carbonite could place on a map.
function QS.Convert(qId, lib)
    lib = lib or Lib()
    if not lib then return nil end
    local ok, v = pcall(lib.Quest.GetAll, qId, QUEST_KEYS)
    if not ok or type(v) ~= "table" then return nil end
    local name, startedBy, finishedBy, reqLevel, questLevel, races, classes, objectives,
        triggerEnd, preGroup, preSingle, nextId, zone = v[1], v[2], v[3], v[4], v[5], v[6],
        v[7], v[8], v[9], v[10], v[11], v[12], v[13]

    name = Clean(name)
    -- "<NYI>" marks quests the game does not offer (not yet implemented); Questie hides them too.
    if not name or name:find("<NYI>", 1, true) then return nil end
    local preferMap = type(zone) == "number" and zone > 0 and UiMap(zone) or nil
    local units = {}
    local record = {
        Start = StartEnd(lib, startedBy, preferMap),
        End = StartEnd(lib, finishedBy, preferMap),
        Objectives = Objectives(lib, objectives, triggerEnd, preferMap, units),
    }
    local placed = record.Objectives
    for _, se in ipairs({ record.Start, record.End }) do
        if se and not se:find("|0|32|0|0", 1, true) then placed = true end
    end
    if not placed then return nil end

    reqLevel = type(reqLevel) == "number" and reqLevel > 0 and floor(reqLevel) or 0
    local level = type(questLevel) == "number" and questLevel > 0 and floor(questLevel) or reqLevel
    record.Quest = format("%s|%d|%d|%d|%d|0|0", name, QS.Side(races, lib.Enum and lib.Enum.factionRaceMasks),
        level, reqLevel, type(nextId) == "number" and nextId or 0)

    local prev = type(preSingle) == "table" and preSingle[1] or type(preGroup) == "table" and preGroup[1]
    return record, {
        classes = type(classes) == "number" and classes > 0 and classes or nil,
        prev = type(prev) == "number" and prev or nil,
        units = units,
    }
end

--------------------------------------------------------------------------------------------
-- Adding to Carbonite
--------------------------------------------------------------------------------------------

local function IsSynthesized(q)
    return type(q) == "table" and type(q.Quest) == "string" and q.Quest:sub(1, 2) == "[["
end

local function Inject(qId, entry)
    local record, extra = entry[1], entry[2]
    -- A fresh table each time: ProcessQuestDB-style indexing writes CNum/CLvlMax into it.
    Nx.Quests[qId] = { Quest = record.Quest, Start = record.Start, End = record.End,
        Objectives = record.Objectives }
    Nx.Quests[-qId] = nil

    if extra.classes then
        Nx.QuestRequiredClasses = Nx.QuestRequiredClasses or {}
        Nx.QuestRequiredClasses[qId] = Nx.QuestRequiredClasses[qId] or extra.classes
    end
    if extra.prev then
        Nx.QuestPrev = Nx.QuestPrev or {}
        Nx.QuestPrev[qId] = Nx.QuestPrev[qId] or extra.prev
    end
    if Nx.Units2Quests then
        for npcId, objective in pairs(extra.units) do
            local token = format("%d,%d", qId, objective)
            local cur = Nx.Units2Quests[npcId]
            if not cur then
                Nx.Units2Quests[npcId] = token
            elseif not ("|" .. cur .. "|"):find("|" .. token .. "|", 1, true) then
                Nx.Units2Quests[npcId] = cur .. "|" .. token
            end
        end
    end
end

-- What ProcessQuestDB does for each quest (SuperTrack.lua), for the added ones only: the
-- sorted list, chain numbers and quest givers per map. Re-running ProcessQuestDB instead would
-- print its "Quests Loaded" line again.
local function Index(ids)
    local Quest = Nx.Quest
    local profile = Nx.qdb and Nx.qdb.profile and Nx.qdb.profile.Quest or {}
    local enemySide = Nx.PlFactionNum == 1 and 1 or 2
    local loadLevel = max(1, (UnitLevel and UnitLevel("player") or 1) + (profile.LevelsToLoad or 0))
    Quest.Sorted = Quest.Sorted or {}
    Quest.QGivers = Quest.QGivers or {}

    for _, qId in ipairs(ids) do
        local q = Nx.Quests[qId]
        local _, side, level, _, nextId = Quest:Unpack(q.Quest)
        level = level or 0
        if not (side == enemySide or level > 0 and profile.maxLoadLevel and level > loadLevel) then
            tinsert(Quest.Sorted, qId)
            if not q.CNum and nextId and nextId > 0 then
                local maxLevel, qc, count, seen = level, q, 0, {}
                while qc do
                    count = count + 1
                    qc.CNum = count
                    local _, _, lvl, _, nxt = Quest:Unpack(qc.Quest)
                    maxLevel = max(maxLevel, lvl or 0)
                    if not nxt or nxt == 0 or seen[nxt] or count > 40 then break end
                    seen[nxt] = true
                    qc = Nx.Quests[nxt]
                end
                q.CLvlMax = maxLevel
            end
            local giver, zone, x, y = Quest:GetSEPos(q.Start)
            if zone and x and y and x ~= 0 and y ~= 0 then
                local key = format("%s=%d%d", giver, floor(x), floor(y))
                local onMap = Quest.QGivers[zone] or {}
                Quest.QGivers[zone] = onMap
                onMap[key] = (onMap[key] or "") .. format("%6x", qId)
            end
        end
    end

    Nx.QuestsByTitle = nil
    if Quest.RecordQuests then Quest:RecordQuests() end
    if Quest.List and Quest.List.Opened and Quest.List.Update then Quest.List:Update() end
end

-- Quest ids in the player's log, converted first so the live quests get data before Carbonite
-- synthesizes stand-ins for them.
local function LogQuestIds()
    local ids = {}
    local log = C_QuestLog
    if log and log.GetNumQuestLogEntries and log.GetInfo then
        local ok, count = pcall(log.GetNumQuestLogEntries)
        for i = 1, ok and type(count) == "number" and count or 0 do
            local okInfo, info = pcall(log.GetInfo, i)
            if okInfo and type(info) == "table" and not info.isHeader and type(info.questID) == "number" then
                ids[#ids + 1] = info.questID
            end
        end
    end
    return ids
end

function QS:Start()
    local lib = Lib()
    if not lib then return end
    local okIds, all = pcall(lib.Quest.GetAllIds)
    if not okIds or type(all) ~= "table" then return end

    generation = generation + 1
    local run = generation
    local queue = LogQuestIds()
    for _, qId in ipairs(all) do queue[#queue + 1] = qId end

    local added, seen, i = {}, {}, 1
    local function step()
        if run ~= generation then return end      -- Carbonite reloaded its data meanwhile
        local last = min(i + BATCH - 1, #queue)
        for k = i, last do
            local qId = queue[k]
            local q = Nx.Quests[qId]
            if not seen[qId] and (q == nil or IsSynthesized(q)) then
                seen[qId] = true
                local entry = built[qId]
                if entry == nil then
                    local ok, record, extra = pcall(QS.Convert, qId, lib)
                    entry = ok and record and { record, extra } or false
                    built[qId] = entry
                end
                if entry then
                    Inject(qId, entry)
                    added[#added + 1] = qId
                end
            end
        end
        i = last + 1
        if i <= #queue then
            C_Timer.After(0, step)
        else
            QS.added = added
            if added[1] then
                local ok, err = pcall(Index, added)
                if not ok then Say(err) end
            end
        end
    end
    step()
end

-- After each completed ProcessQuestDB: at login, and whenever Carbonite reloads its data
-- (which rebuilds Nx.Quests). In combat ProcessQuestDB defers itself and is called again.
if hooksecurefunc then
    hooksecurefunc(Nx.Quest, "ProcessQuestDB", function()
        if InCombatLockdown and InCombatLockdown() then return end
        local ok, err = pcall(QS.Start, QS)
        if not ok then Say(err) end
    end)
end
