-- Carbonite | Modules / Map / DungeonGuide
-- Boss route and quests for the dungeon the player is in (#103, #83).
--
-- Classic Era based clients (Forever) give no map and no player position
-- inside dungeons (UnmappedInstance.lua). With the map maximized (M) inside
-- such an instance, a panel at the right of the map window lists the bosses
-- in route order (the killed ones dimmed, the next one highlighted), then
-- the quests of the player's log for this dungeon with their objectives,
-- and the quest items MapUtils places in it. The dungeon chart shows the
-- same quests where MapUtils has a position (DG:FloorPins).
--
-- * Quests: under the dungeon's name in the quest log, given or turned in
--   inside it (MapUtils' pins), or with an objective or turn-in on its
--   floors in Carbonite's quest data, or placed inside it by QuestieDB
--   (#8; QuestieSource.InDungeon), which also names the objective items
--   that drop there. QuestieDB has no positions inside instances, so those
--   are listed in the panel, not drawn on the chart.
-- * Order: the dungeon chart's when it shows this dungeon (DungeonChart.lua:
--   ForeverDungeonJournal or FojjiCore, in their run order), else the
--   client's Encounter Journal when it has one, else MapUtils' boss pins
--   (DungeonPins.lua) walked from the entrance, nearest boss first, floor
--   by floor.
-- * Kills: the combat log (UNIT_DIED, by NPC id or name) and ENCOUNTER_END.
--   Kept across /reload in Nx.db.char.DungeonKills; reset on entering the
--   instance again from outside, or another instance.
-- * Names shown: the client's. Boss names as the game writes them (combat
--   log, target, mouseover, nameplates; kept in Nx.db.char.DungeonNames),
--   dungeon names from GetInstanceInfo / GetRealZoneText, floor names from
--   the client's map groups, quest titles from the quest log. Else the
--   entries of Carbonite/Locales/<locale>/Dungeons.lua: English, with pt-BR
--   for dungeons, floors and objects.
--
-- Public (Nx.DungeonGuide):
--   DG:Here()                   { id, name, data } of the current instance
--   DG:Bosses(here)             { { name, npc, floor, x, y, killed }, ... }
--   DG.NextBoss(list)           index of the first boss alive, or nil
--   DG.RouteOrder(points, x, y) indexes of points, nearest first from x, y
--   DG:SetChartBosses(id, list) the chart's own boss list for instance id
--   DG:NoteKill(name, npc) / DG:IsKilled(name, npc) / DG:ResetKills(id)
--   DG:LogQuests(here)          { { qId, title, complete, objectives }, ... }
--   DG:FloorPins(key)           quest and item pins of one MapUtils floor
--   DG.PinItems(data)           names of the quest items placed in a dungeon
--   DG:Lines(here)              the panel's text lines
--   DG:PanelWidth(mapW)         panel width for a map area; 0 = no panel
--   DG:UpdatePanel(map, w, h)   lay out the panel (w = 0 hides it)

local Nx = _G.Nx
if not Nx then return end

local L = LibStub("AceLocale-3.0"):GetLocale("Carbonite")

local DG = { Version = 0 }
Nx.DungeonGuide = DG

local PANEL_W = 230
local REFRESH = 1

local function Pins()
    return Nx.DungeonPins or { instances = {}, pins = {} }
end

--------------------------------------------------------------------------------
-- Names: the client's first, else Carbonite/Locales/<locale>/Dungeons.lua
--------------------------------------------------------------------------------

-- A Dungeons.lua entry, or nil when the locale has none.
local function Text(key)
    local ok, s = pcall(function() return L[key] end)
    if ok and type(s) == "string" and s ~= key then return s end
end

-- Boss NPC ids of DungeonPins.lua (first and other ids of each boss row): id -> true.
local bossNpcs
local function BossNpcs()
    if not bossNpcs then
        bossNpcs = {}
        for _, rows in pairs(Pins().pins) do
            for _, row in ipairs(rows) do
                if row[1] == "boss" then
                    for i = 4, #row do bossNpcs[row[i]] = true end
                end
            end
        end
    end
    return bossNpcs
end

-- Boss names as the client wrote them (combat log, target, mouseover, nameplates).
local function ClientNames()
    local char = Nx.db and Nx.db.char
    if type(char) ~= "table" then
        DG.SessionNames = DG.SessionNames or {}
        return DG.SessionNames
    end
    char.DungeonNames = type(char.DungeonNames) == "table" and char.DungeonNames or {}
    return char.DungeonNames
end

function DG.BossName(npc)
    return ClientNames()[npc] or Text("boss:" .. tostring(npc)) or tostring(npc)
end

function DG.InstanceName(id)
    local here = DG:Here()
    if here and here.id == id then return here.name end
    if GetRealZoneText and type(id) == "number" then
        local ok, name = pcall(GetRealZoneText, id)
        if ok and type(name) == "string" and name ~= "" then return name end
    end
    return Text("dungeon:" .. tostring(id)) or tostring(id)
end

-- Name of a named floor: the client's map group entry, else Dungeons.lua.
function DG.FloorName(fl)
    if not (fl and fl.named) then return nil end
    local api = _G.C_Map
    if fl.map and api and api.GetMapGroupID and api.GetMapGroupMembersInfo then
        local ok, group = pcall(api.GetMapGroupID, fl.map)
        local okInfo, members = false, nil
        if ok and group then okInfo, members = pcall(api.GetMapGroupMembersInfo, group) end
        for _, m in ipairs(okInfo and type(members) == "table" and members or {}) do
            if m.mapID == fl.map and type(m.name) == "string" and m.name ~= "" then return m.name end
        end
    end
    return Text("floor:" .. fl.key)
end

function DG.QuestName(qId)
    return Text("quest:" .. tostring(qId)) or tostring(qId)
end

function DG.ObjectName(id)
    return Text("object:" .. tostring(id)) or tostring(id)
end

-- The Forever client hands some unit and combat log values as secret values:
-- type() says "string", but reading them (match, gsub, compare) raises an
-- error. Only plain values are read.
local function Readable(value)
    return not (issecretvalue and issecretvalue(value))
end
DG.Readable = Readable

-- Keeps the client's name of a boss seen in the game.
function DG:LearnName(guid, name)
    local npc = DG.NpcID(guid)
    if npc and type(name) == "string" and Readable(name) and name ~= "" and BossNpcs()[npc] and ClientNames()[npc] ~= name then
        ClientNames()[npc] = name
        self.Dirty = true
        self.Version = self.Version + 1
    end
end

-- Boss names as the combat log gives them: no "<title>"; "A / B" is either.
local function Names(name)
    local out = {}
    if type(name) ~= "string" or not Readable(name) then return out end
    name = name:gsub("%s*<.->", "")
    for part in (name .. " / "):gmatch("(.-)%s*/%s+") do
        if part ~= "" then out[#out + 1] = part:lower() end
    end
    return out
end

local function NpcID(guid)
    if type(guid) ~= "string" or not Readable(guid) then return nil end
    local kind, id = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)")
    if kind == "Creature" or kind == "Vehicle" then return tonumber(id) end
end
DG.NpcID = NpcID

--------------------------------------------------------------------------------
-- Boss portraits
--
-- A creature's portrait needs its display id, which the client does not give
-- for an npc id. ForeverDungeonJournal keeps the ones it found
-- (ForeverDungeonJournalDB.displayIDs) and ships round portraits for many
-- (SetBakedPortrait); the rest are found the way it does: an off-screen
-- PlayerModel shown the creature, then GetDisplayInfo. Read in game only.
--------------------------------------------------------------------------------

local displayIDs, asked, queue = {}, {}, {}
local resolver

local function Resolve(npc)
    if asked[npc] or not CreateFrame then return end
    asked[npc] = true
    queue[#queue + 1] = npc
    if not resolver then
        local ok, model = pcall(CreateFrame, "PlayerModel", nil, UIParent)
        if not ok or not model or not model.SetCreature or not model.GetDisplayInfo then return end
        resolver = model
        model:SetSize(8, 8)
        model:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -100, 100)
        model:SetScript("OnUpdate", function(m)
            if m.Npc then
                m.Tries = m.Tries + 1
                local okInfo, id = pcall(m.GetDisplayInfo, m)
                if okInfo and type(id) == "number" and id > 0 then
                    displayIDs[m.Npc] = id
                    m.Npc = nil
                    DG.Version = DG.Version + 1
                    DG.Dirty = true
                elseif m.Tries > 60 then
                    m.Npc = nil             -- gave up: the skull stays
                end
                return
            end
            local nextNpc = table.remove(queue, 1)
            if not nextNpc then
                m:Hide()
                return
            end
            m.Npc, m.Tries = nextNpc, 0
            pcall(m.SetCreature, m, nextNpc)
        end)
    end
    resolver:Show()
end

-- Display id of a boss npc, or nil while it is being found.
function DG.DisplayID(npc)
    if type(npc) ~= "number" then return nil end
    local id = displayIDs[npc]
    if id then return id end
    -- ForeverDungeonJournal's own table of boss looks (Data/Bosses.lua).
    local ns = _G.ForeverDungeonJournal_NS
    id = ns and type(ns.STATIC_DISPLAY_IDS) == "table" and ns.STATIC_DISPLAY_IDS[npc]
    if type(id) == "number" and id > 0 then
        displayIDs[npc] = id
        return id
    end
    local fdj = _G.ForeverDungeonJournalDB
    id = fdj and type(fdj.displayIDs) == "table" and fdj.displayIDs[npc]
    if type(id) == "number" and id > 0 then
        displayIDs[npc] = id
        return id
    end
    Resolve(npc)
    return nil
end

-- Round portrait of a boss in texture; false when there is none (yet).
function DG.SetBossPortrait(texture, npc)
    local id = DG.DisplayID(npc)
    if not id or not texture then return false end
    texture:SetTexCoord(0, 1, 0, 1)
    local ns = _G.ForeverDungeonJournal_NS
    if ns and ns.SetBakedPortrait then
        local ok, set = pcall(ns.SetBakedPortrait, texture, id)
        if ok and set then return true end
    end
    local setPortrait = _G.SetPortraitTextureFromCreatureDisplayID
    if setPortrait then
        return pcall(setPortrait, texture, id) and true or false
    end
    return false
end

--------------------------------------------------------------------------------
-- Current instance
--------------------------------------------------------------------------------

function DG:Here()
    local now = GetTime and GetTime() or 0
    if self.HereTime == now and self.HereValue ~= nil then
        return self.HereValue or nil
    end
    local value = false
    if IsInInstance and GetInstanceInfo then
        local ok, inside = pcall(IsInInstance)
        if ok and inside then
            local okInfo, name, _, _, _, _, _, _, id = pcall(GetInstanceInfo)
            if okInfo and type(name) == "string" then
                value = { id = id, name = name, data = id and Pins().instances[id] or nil }
            end
        end
    end
    self.HereTime, self.HereValue = now, value
    return value or nil
end

--------------------------------------------------------------------------------
-- Bosses
--------------------------------------------------------------------------------

function DG.RouteOrder(points, x, y)
    local order, used = {}, {}
    for _ = 1, #points do
        local best, bestD
        for i, p in ipairs(points) do
            if not used[i] then
                local d = x and ((p.x - x) ^ 2 + (p.y - y) ^ 2) or 0
                if not bestD or d < bestD then best, bestD = i, d end
            end
        end
        used[best] = true
        order[#order + 1] = best
        x, y = points[best].x, points[best].y
    end
    return order
end

-- MapUtils' boss pins, floor by floor, from where the floor is entered.
local function PinBosses(data)
    local P = Pins()
    local list, seen = {}, {}
    for f, fl in ipairs(data and data.floors or {}) do
        local points, x, y = {}, nil, nil
        for _, row in ipairs(P.pins[fl.key] or {}) do
            local kind = row[1]
            if kind == "boss" then
                local alts = {}
                for i = 5, #row do alts[#alts + 1] = row[i] end
                points[#points + 1] = { x = row[2], y = row[3], npc = row[4], alts = alts }
            elseif not x and (kind == "entrance" or (kind == "level" and row[5])) then
                x, y = row[2], row[3]
            end
        end
        for _, i in ipairs(DG.RouteOrder(points, x, y)) do
            local p = points[i]
            if not seen[p.npc] then
                seen[p.npc] = true
                list[#list + 1] = { name = DG.BossName(p.npc), npc = p.npc, alts = p.alts, floor = f, x = p.x, y = p.y }
            end
        end
    end
    return list
end
DG.PinBosses = PinBosses

-- The client's Encounter Journal, when this client has one (Forever: no).
local function JournalBosses(data)
    local forMap, selectInstance, info = _G.EJ_GetInstanceForMap, _G.EJ_SelectInstance, _G.EJ_GetEncounterInfoByIndex
    local fl = data and data.floors and data.floors[1]
    if not (forMap and selectInstance and info and fl and fl.map) then return nil end
    local ok, journal = pcall(forMap, fl.map)
    if not ok or type(journal) ~= "number" or journal <= 0 then return nil end
    if not pcall(selectInstance, journal) then return nil end
    local list = {}
    for i = 1, 50 do
        local okInfo, name = pcall(info, i, journal)
        if not okInfo or type(name) ~= "string" then break end
        list[#list + 1] = { name = name }
    end
    return list[1] and list or nil
end

function DG:SetChartBosses(id, list)
    local old = self.ChartBosses
    if old and old.id == id and #old.list == #list then
        local same = true
        for i, b in ipairs(list) do
            local o = old.list[i]
            if o.name ~= b.name or (o.killed and true) ~= (b.killed and true) then same = false break end
        end
        if same then return end
    end
    self.ChartBosses = { id = id, list = list }
    self.Dirty = true
end

function DG:Bosses(here)
    here = here or self:Here()
    if not here then return {} end
    local chart = self.ChartBosses
    local src = chart and chart.id == here.id and chart.list
        or JournalBosses(here.data) or PinBosses(here.data)
    local list, known = {}, {}
    for i, b in ipairs(src) do
        local killed = b.killed or self:IsKilled(b.name, b.npc)
        for _, alt in ipairs(b.alts or {}) do
            killed = killed or self:IsKilled(nil, alt)
            known[alt] = true
        end
        list[i] = { name = b.name, npc = b.npc, alts = b.alts, floor = b.floor, x = b.x, y = b.y, killed = killed }
        for _, n in ipairs(Names(b.name)) do known[n] = true end
        if b.npc then known[b.npc] = true end
    end
    self.Known = known
    return list
end

function DG.NextBoss(list)
    for i, b in ipairs(list) do
        if not b.killed then return i end
    end
end

--------------------------------------------------------------------------------
-- Kills
--------------------------------------------------------------------------------

local function Store()
    local char = Nx.db and Nx.db.char
    if type(char) ~= "table" then return nil end
    local s = type(char.DungeonKills) == "table" and char.DungeonKills or {}
    char.DungeonKills = s
    s.names = type(s.names) == "table" and s.names or {}
    s.npcs = type(s.npcs) == "table" and s.npcs or {}
    return s
end

function DG:ResetKills(id)
    local s = Store()
    if s then
        s.id = id
        s.names, s.npcs = {}, {}
    end
    self.Version = self.Version + 1
    self.Dirty = true
end

function DG:NoteKill(name, npc)
    local s = Store()
    if not s then return end
    for _, n in ipairs(Names(name)) do s.names[n] = true end
    if npc then s.npcs[npc] = true end
    self.Version = self.Version + 1
    self.Dirty = true
end

function DG:IsKilled(name, npc)
    local s = Store()
    if not s then return false end
    if npc and s.npcs[npc] then return true end
    local names = Names(name)
    if not names[1] then return false end
    for _, n in ipairs(names) do
        if not s.names[n] then return false end
    end
    return true
end

function DG:IsBoss(name, npc)
    local known = self.Known
    if not known then return false end
    if npc and known[npc] then return true end
    local n = Names(name)[1]
    return n and known[n] or false
end

--------------------------------------------------------------------------------
-- Quests and quest items (#83)
--------------------------------------------------------------------------------

-- uiMapIDs of the dungeon's floors, as a set.
local function MapSet(data)
    local maps = {}
    for _, fl in ipairs(data and data.floors or {}) do
        if fl.map then maps[fl.map] = true end
    end
    return maps
end

-- A Carbonite location string ("desc|uiMapID|...") on one of `maps`.
local function LocIn(loc, maps)
    local id = type(loc) == "string" and tonumber(loc:match("^[^|]*|(%d+)|"))
    return id and maps[id] or false
end

local function RecordIn(record, maps)
    if type(record) ~= "table" or not next(maps) then return false end
    if LocIn(record.End, maps) then return true end
    for _, obj in pairs(type(record.Objectives) == "table" and record.Objectives or {}) do
        for _, loc in ipairs(type(obj) == "table" and obj or { obj }) do
            if LocIn(loc, maps) then return true end
        end
    end
    return false
end

-- MapUtils' quest pins of the dungeon: questID -> true.
local function PinQuests(data)
    local P, ids = Pins(), {}
    for _, fl in ipairs(data and data.floors or {}) do
        for _, row in ipairs(P.pins[fl.key] or {}) do
            if row[1] == "queststart" or row[1] == "questend" then ids[row[4]] = true end
        end
    end
    return ids
end

local function Objectives(cur)
    local count, board = _G.GetNumQuestLeaderBoards, _G.GetQuestLogLeaderBoard
    local out = {}
    if not (count and board and cur.QI) then return out end
    local ok, n = pcall(count, cur.QI)
    for i = 1, ok and tonumber(n) or 0 do
        local okText, text, _, done = pcall(board, i, cur.QI)
        if okText and type(text) == "string" and text ~= "" then
            out[#out + 1] = { text = text, done = done and true or false }
        end
    end
    return out
end

-- Quests of the player's log for this dungeon: under its name in the log,
-- given or turned in inside it (MapUtils), or with an objective or turn-in
-- on its floors (Carbonite's quest data).
function DG:LogQuests(here)
    here = here or self:Here()
    local cur = Nx.Quest and Nx.Quest.CurQ
    if not here or type(cur) ~= "table" then return {} end
    local maps, pinned = MapSet(here.data), PinQuests(here.data)
    local QS = Nx.Quest.QuestieSource
    local list, seen = {}, {}
    for _, c in ipairs(cur) do
        local qId = c.QId
        if qId and not seen[qId] then
            local questie = QS and QS.InDungeon and QS.InDungeon(qId, here.id) or nil
            if c.Header == here.name or pinned[qId] or RecordIn(c.Q, maps) or questie then
                seen[qId] = true
                list[#list + 1] = { qId = qId, title = c.Title or DG.QuestName(qId),
                    complete = c.Complete == 1 or c.Complete == true, objectives = Objectives(c),
                    items = questie and questie.items or {} }
            end
        end
    end
    return list
end

local function InLog(qId)
    local ids = Nx.Quest and Nx.Quest.IdToCurQ
    return type(ids) == "table" and ids[qId] or nil
end

local function QuestDone(qId)
    local Q = Nx.Quest
    if not (Q and Q.GetQuest and Q.CurCharacter) then return false end
    local ok, status = pcall(Q.GetQuest, Q, qId)
    return ok and status == "C" or false
end

local function QuestTitle(qId)
    local cur = InLog(qId)
    if cur and cur.Title then return cur.Title end
    local api = _G.C_QuestLog
    if api and api.GetQuestInfo then
        local ok, title = pcall(api.GetQuestInfo, qId)
        if ok and type(title) == "string" and title ~= "" then return title end
    end
    return DG.QuestName(qId)
end

-- Quest pins of one MapUtils floor for the chart: turn-ins of quests in the
-- log, givers of quests not taken nor done, and quest items.
-- { { kind = "turnin" | "start" | "item", x, y, tip }, ... }
function DG:FloorPins(key)
    local out = {}
    for _, row in ipairs(key and Pins().pins[key] or {}) do
        local kind, x, y, arg = row[1], row[2], row[3], row[4]
        if kind == "questend" and InLog(arg) then
            out[#out + 1] = { kind = "turnin", x = x, y = y, tip = format(L["Turn in: %s"], QuestTitle(arg)) }
        elseif kind == "queststart" and not InLog(arg) and not QuestDone(arg) then
            out[#out + 1] = { kind = "start", x = x, y = y, tip = format(L["Starts quest: %s"], QuestTitle(arg)) }
        elseif kind == "item" then
            out[#out + 1] = { kind = "item", x = x, y = y, tip = format(L["Quest item: %s"], DG.ObjectName(arg)) }
        end
    end
    return out
end

-- Quest items MapUtils places in the dungeon: { "Name (count)", ... }
function DG.PinItems(data)
    local P, counts, order = Pins(), {}, {}
    for _, fl in ipairs(data and data.floors or {}) do
        for _, row in ipairs(P.pins[fl.key] or {}) do
            local name = row[1] == "item" and DG.ObjectName(row[4])
            if name and name ~= "" then
                if not counts[name] then order[#order + 1] = name end
                counts[name] = (counts[name] or 0) + 1
            end
        end
    end
    local out = {}
    for i, name in ipairs(order) do
        out[i] = counts[name] > 1 and format("%s (%d)", name, counts[name]) or name
    end
    return out
end

--------------------------------------------------------------------------------
-- Panel
--------------------------------------------------------------------------------

function DG:Lines(here)
    here = here or self:Here()
    if not here then return {} end
    local now = GetTime and GetTime() or 0
    if not self.Dirty and self.LinesFor == here.id and self.LinesTime and now - self.LinesTime < REFRESH then
        return self.LinesCache
    end
    self.Dirty = nil
    local lines = {}
    local bosses = self:Bosses(here)
    lines[#lines + 1] = "|cffffd100" .. L["Bosses (route order)"] .. "|r"
    if not bosses[1] then
        lines[#lines + 1] = "|cff9d9d9d" .. L["No boss data for this dungeon"] .. "|r"
    end
    local nextBoss = DG.NextBoss(bosses)
    for i, b in ipairs(bosses) do
        if b.killed then
            lines[#lines + 1] = format("|cff808080%d. %s|r", i, b.name)
        elseif i == nextBoss then
            lines[#lines + 1] = format("|cff40ff40%d. %s  %s|r", i, b.name, L["(next)"])
        else
            lines[#lines + 1] = format("%d. %s", i, b.name)
        end
    end
    for _, line in ipairs(self:QuestLines(here)) do
        lines[#lines + 1] = line
    end
    self.LinesFor, self.LinesTime, self.LinesCache = here.id, now, lines
    return lines
end

-- The quest part of the panel: the log's quests for this dungeon and the
-- quest items found here.
function DG:QuestLines(here)
    local lines = {}
    local quests = self:LogQuests(here)
    local items = DG.PinItems(here.data)
    if quests[1] or items[1] then
        lines[#lines + 1] = " "
        lines[#lines + 1] = "|cffffd100" .. L["Quests in this dungeon"] .. "|r"
    end
    for _, q in ipairs(quests) do
        if q.complete then
            lines[#lines + 1] = format("|cff40ff40%s %s|r", q.title, L["(complete)"])
        else
            lines[#lines + 1] = q.title
        end
        for _, o in ipairs(q.objectives) do
            lines[#lines + 1] = format(o.done and "  |cff808080- %s|r" or "  - %s", o.text)
        end
        if q.items[1] then
            lines[#lines + 1] = "  |cff9d9d9d" .. format(L["Drops here: %s"], table.concat(q.items, ", ")) .. "|r"
        end
    end
    if items[1] then
        lines[#lines + 1] = "|cff9d9d9d" .. format(L["Quest items here: %s"], table.concat(items, ", ")) .. "|r"
    end
    return lines
end

function DG:PanelWidth(mapW)
    if (mapW or 0) < PANEL_W * 2.5 then return 0 end
    local here = self:Here()
    if not here then return 0 end
    return PANEL_W
end

local ROW_H = 46
local PORTRAIT = 34
local ROUND = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local SKULL = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull"
local DEAD_MARK = "Interface\\RaidFrame\\ReadyCheck-NotReady"

-- Ring colors: alive, the next one, killed.
DG.RING = { alive = { 1, .82, 0 }, next = { .25, 1, .25 }, killed = { .45, .45, .45 } }

-- State of each boss for the panel and the chart pins.
function DG.BossState(bosses, i)
    if bosses[i].killed then return "killed" end
    if i == DG.NextBoss(bosses) then return "next" end
    return "alive"
end

local function BuildPanel(map)
    local f = CreateFrame("Frame", nil, map.Frm)
    f:EnableMouse(true)
    f:SetClipsChildren(true)
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(.05, .05, .07, .95)
    -- Dungeon name, bosses and quests: one block centered in the panel.
    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("LEFT", 10, 0)
    content:SetPoint("RIGHT", -10, 0)
    f.Content = content
    local title = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT")
    title:SetPoint("TOPRIGHT")
    title:SetJustifyH("CENTER")
    f.Title = title
    local heading = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    heading:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
    heading:SetPoint("TOPRIGHT", title, "BOTTOMRIGHT", 0, -12)
    heading:SetJustifyH("LEFT")
    f.Heading = heading
    local text = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("LEFT")
    text:SetPoint("RIGHT")
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    f.Text = text
    f.Rows = {}
    return f
end

local function BossRow(panel, i)
    local r = panel.Rows[i]
    if r then return r end
    r = CreateFrame("Frame", nil, panel.Content)
    r:SetHeight(ROW_H)
    r:SetPoint("LEFT")
    r:SetPoint("RIGHT")
    r.Ring = r:CreateTexture(nil, "BORDER")
    r.Ring:SetTexture(ROUND)
    r.Ring:SetSize(PORTRAIT + 6, PORTRAIT + 6)
    r.Ring:SetPoint("LEFT", 0, 0)
    r.Portrait = r:CreateTexture(nil, "ARTWORK")
    r.Portrait:SetSize(PORTRAIT, PORTRAIT)
    r.Portrait:SetPoint("CENTER", r.Ring)
    r.Dead = r:CreateTexture(nil, "OVERLAY")
    r.Dead:SetTexture(DEAD_MARK)
    r.Dead:SetSize(18, 18)
    r.Dead:SetPoint("BOTTOMRIGHT", r.Ring, "BOTTOMRIGHT", 3, -3)
    r.Name = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    r.Name:SetPoint("TOPLEFT", r.Ring, "TOPRIGHT", 8, -3)
    r.Name:SetPoint("RIGHT")
    r.Name:SetJustifyH("LEFT")
    r.Name:SetWordWrap(false)
    r.State = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.State:SetPoint("TOPLEFT", r.Name, "BOTTOMLEFT", 0, -3)
    r.State:SetJustifyH("LEFT")
    panel.Rows[i] = r
    return r
end

local STATE_TEXT = {
    alive = function() return "|cffd0d0d0" .. L["Alive"] .. "|r" end,
    next = function() return "|cff40ff40" .. L["Next boss"] .. "|r" end,
    killed = function() return "|cff808080" .. L["Killed"] .. "|r" end,
}

local function FillRows(panel, bosses)
    for i, b in ipairs(bosses) do
        local r = BossRow(panel, i)
        local state = DG.BossState(bosses, i)
        if not DG.SetBossPortrait(r.Portrait, b.npc) then
            r.Portrait:SetTexture(SKULL)
            r.Portrait:SetTexCoord(0, 1, 0, 1)
        end
        local ring = DG.RING[state]
        r.Ring:SetVertexColor(ring[1], ring[2], ring[3])
        r.Portrait:SetDesaturated(state == "killed")
        r.Portrait:SetAlpha(state == "killed" and .6 or 1)
        if state == "killed" then r.Dead:Show() else r.Dead:Hide() end
        r.Name:SetText(format(state == "killed" and "|cff808080%d. %s|r" or "%d. %s", i, b.name))
        r.State:SetText(STATE_TEXT[state]())
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", panel.Heading, "BOTTOMLEFT", 0, -6 - (i - 1) * ROW_H)
        r:SetPoint("RIGHT", panel.Content, "RIGHT")
        r:Show()
    end
    for i = #bosses + 1, #panel.Rows do panel.Rows[i]:Hide() end
end

-- w: panel width (0 hides it); h: height of the map area it may use.
function DG:UpdatePanel(map, w, h)
    local panel = self.Panel
    if not w or w <= 0 or not map or not map.Frm then
        if panel and panel:IsShown() then panel:Hide() end
        return
    end
    if not panel then
        panel = BuildPanel(map)
        self.Panel = panel
    end
    local here = self:Here()
    if not here then
        panel:Hide()
        return
    end
    local x = (map.PadX or 0) + (map.MapW or 0) - w
    local sig = format("%d|%d|%d|%d|%d", x, map.TitleH or 0, w, h, self.Version)
    if sig ~= self.PanelSig or self.Dirty then
        self.PanelSig = sig
        panel:ClearAllPoints()
        panel:SetPoint("TOPLEFT", map.Frm, "TOPLEFT", x, -(map.TitleH or 0))
        panel:SetSize(w, h)
        panel.Title:SetText(here.name)

        local bosses = self:Bosses(here)
        panel.Heading:SetText(bosses[1] and L["Bosses (route order)"] or ("|cff9d9d9d" .. L["No boss data for this dungeon"] .. "|r"))
        FillRows(panel, bosses)
        panel.Text:ClearAllPoints()
        panel.Text:SetPoint("TOPLEFT", panel.Heading, "BOTTOMLEFT", 0, -10 - #bosses * ROW_H)
        panel.Text:SetPoint("RIGHT", panel.Content, "RIGHT")
        panel.Text:SetText(table.concat(self:QuestLines(here), "\n"))

        -- Center the whole block (name, bosses, quests) in the panel.
        local contentH = (panel.Title:GetStringHeight() or 16) + 12
            + (panel.Heading:GetStringHeight() or 14) + 10 + #bosses * ROW_H
            + (panel.Text:GetStringHeight() or 0)
        local top = 10
        local free = h - top - contentH
        panel.Content:ClearAllPoints()
        panel.Content:SetPoint("LEFT", 10, 0)
        panel.Content:SetPoint("RIGHT", -10, 0)
        panel.Content:SetPoint("TOP", panel, "TOP", 0, -(top + max(0, free / 2)))
        panel.Content:SetHeight(contentH)
        self.Dirty = nil
    end
    if not panel:IsShown() then panel:Show() end
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

function DG:OnEnterWorld(isLogin, isReload)
    self.HereTime = nil
    self.ChartBosses, self.Known = nil, nil
    local here = self:Here()
    local s = Store()
    if here and s and (s.id ~= here.id or (not isLogin and not isReload and not self.WasInside)) then
        self:ResetKills(here.id)
    end
    self.WasInside = here and true or false
    self.Dirty = true
    return here
end

function DG:OnCombatLog(sub, guid, name)
    if not Readable(sub) or sub ~= "UNIT_DIED" then return end
    if not Readable(name) then name = nil end
    local npc = NpcID(guid)
    self:LearnName(guid, name)
    if not self.Known then self:Bosses() end
    if self:IsBoss(name, npc) then self:NoteKill(name, npc) end
end

-- Only inside an instance: kills, and the client's boss names.
local INSIDE_EVENTS = { "COMBAT_LOG_EVENT_UNFILTERED", "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT",
    "NAME_PLATE_UNIT_ADDED" }

-- The combat log is restricted on the Forever client inside instances:
-- registering it there raises "action blocked" (ADDON_ACTION_BLOCKED), which
-- pcall cannot stop. Ask the client first, as ObjectiveCapture and NxInfo do;
-- without it, kills still come from ENCOUNTER_END.
local function CombatLogAllowed()
    local log = _G.C_CombatLog
    if not log then
        return true                 -- older clients: no restriction
    end
    if not log.IsCombatLogRestricted then
        return false
    end
    local ok, restricted = pcall(log.IsCombatLogRestricted)
    return ok and restricted == false
end
DG.CombatLogAllowed = CombatLogAllowed

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("ENCOUNTER_END")
events:RegisterEvent("QUEST_LOG_UPDATE")
events:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        local inside = DG:OnEnterWorld(...)
        for _, name in ipairs(INSIDE_EVENTS) do
            if inside and (name ~= "COMBAT_LOG_EVENT_UNFILTERED" or CombatLogAllowed()) then
                self:RegisterEvent(name)
            elseif self:IsEventRegistered(name) then
                self:UnregisterEvent(name)
            end
        end
    elseif event == "PLAYER_TARGET_CHANGED" or event == "UPDATE_MOUSEOVER_UNIT" or event == "NAME_PLATE_UNIT_ADDED" then
        local unit = event == "PLAYER_TARGET_CHANGED" and "target" or event == "UPDATE_MOUSEOVER_UNIT" and "mouseover" or ...
        if unit and UnitGUID then DG:LearnName(UnitGUID(unit), UnitName and UnitName(unit)) end
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        if CombatLogGetCurrentEventInfo then
            local _, sub, _, _, _, _, _, guid, name = CombatLogGetCurrentEventInfo()
            DG:OnCombatLog(sub, guid, name)
        end
    elseif event == "QUEST_LOG_UPDATE" then
        if DG:Here() then
            DG.Version = DG.Version + 1
            DG.Dirty = true
        end
    elseif event == "ENCOUNTER_END" then
        local _, name, _, _, success = ...
        if success == 1 or success == true then DG:NoteKill(name) end
    end
end)
