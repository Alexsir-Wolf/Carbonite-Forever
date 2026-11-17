-- Carbonite | Modules / Map / DungeonGuide
-- Boss route for the dungeon the player is in (#103).
--
-- Classic Era based clients (Forever) give no map and no player position
-- inside dungeons (UnmappedInstance.lua). With the map maximized (M) inside
-- such an instance, a panel at the right of the map window lists the bosses
-- in route order: the killed ones dimmed, the next one highlighted.
--
-- * Order: the dungeon chart's when it shows this dungeon (DungeonChart.lua:
--   ForeverDungeonJournal or FojjiCore, in their run order), else the
--   client's Encounter Journal when it has one, else MapUtils' boss pins
--   (DungeonPins.lua) walked from the entrance, nearest boss first, floor
--   by floor.
-- * Kills: the combat log (UNIT_DIED, by NPC id or name) and ENCOUNTER_END.
--   Kept across /reload in Nx.db.char.DungeonKills; reset on entering the
--   instance again from outside, or another instance.
--
-- Public (Nx.DungeonGuide):
--   DG:Here()                   { id, name, data } of the current instance
--   DG:Bosses(here)             { { name, npc, floor, x, y, killed }, ... }
--   DG.NextBoss(list)           index of the first boss alive, or nil
--   DG.RouteOrder(points, x, y) indexes of points, nearest first from x, y
--   DG:SetChartBosses(id, list) the chart's own boss list for instance id
--   DG:NoteKill(name, npc) / DG:IsKilled(name, npc) / DG:ResetKills(id)
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
    return Nx.DungeonPins or { instances = {}, pins = {}, bosses = {}, quests = {} }
end

-- Boss names as the combat log gives them: no "<title>"; "A / B" is either.
local function Names(name)
    local out = {}
    if type(name) ~= "string" then return out end
    name = name:gsub("%s*<.->", "")
    for part in (name .. " / "):gmatch("(.-)%s*/%s+") do
        if part ~= "" then out[#out + 1] = part:lower() end
    end
    return out
end

local function NpcID(guid)
    if type(guid) ~= "string" then return nil end
    local kind, id = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)")
    if kind == "Creature" or kind == "Vehicle" then return tonumber(id) end
end
DG.NpcID = NpcID

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
                points[#points + 1] = { x = row[2], y = row[3], npc = row[4] }
            elseif not x and (kind == "entrance" or (kind == "level" and row[5])) then
                x, y = row[2], row[3]
            end
        end
        for _, i in ipairs(DG.RouteOrder(points, x, y)) do
            local p = points[i]
            local name = P.bosses[p.npc]
            if name and not seen[name] then
                seen[name] = true
                list[#list + 1] = { name = name, npc = p.npc, floor = f, x = p.x, y = p.y }
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
        list[i] = { name = b.name, npc = b.npc, floor = b.floor, x = b.x, y = b.y,
            killed = b.killed or self:IsKilled(b.name, b.npc) }
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
    self.LinesCache, self.LinesFor, self.LinesTime = lines, here.id, now
    return lines
end

function DG:PanelWidth(mapW)
    if (mapW or 0) < PANEL_W * 2.5 then return 0 end
    local here = self:Here()
    if not here then return 0 end
    return PANEL_W
end

local function BuildPanel(map)
    local f = CreateFrame("Frame", nil, map.Frm)
    f:EnableMouse(true)
    f:SetClipsChildren(true)
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(.05, .05, .07, .95)
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 8, -6)
    title:SetPoint("TOPRIGHT", -8, -6)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    f.Title = title
    local text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    text:SetPoint("RIGHT", -8, 0)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    f.Text = text
    return f
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
    local sig = format("%d|%d|%d|%d", x, map.TitleH or 0, w, h)
    if sig ~= self.PanelSig then
        self.PanelSig = sig
        panel:ClearAllPoints()
        panel:SetPoint("TOPLEFT", map.Frm, "TOPLEFT", x, -(map.TitleH or 0))
        panel:SetSize(w, h)
    end
    local lines = self:Lines(here)
    if lines ~= self.PanelLines then
        self.PanelLines = lines
        panel.Title:SetText(here.name)
        panel.Text:SetText(table.concat(lines, "\n"))
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
    if sub ~= "UNIT_DIED" then return end
    local npc = NpcID(guid)
    if not self.Known then self:Bosses() end
    if self:IsBoss(name, npc) then self:NoteKill(name, npc) end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("ENCOUNTER_END")
events:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        if DG:OnEnterWorld(...) then
            self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        else
            self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        end
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        if CombatLogGetCurrentEventInfo then
            local _, sub, _, _, _, _, _, guid, name = CombatLogGetCurrentEventInfo()
            DG:OnCombatLog(sub, guid, name)
        end
    elseif event == "ENCOUNTER_END" then
        local _, name, _, _, success = ...
        if success == 1 or success == true then DG:NoteKill(name) end
    end
end)
