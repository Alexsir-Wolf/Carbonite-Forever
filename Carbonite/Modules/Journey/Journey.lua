-- Carbonite | Modules / Journey
-- Character journey diary (#69): the milestones of each character with date,
-- time, zone and level, newest first in a Carbonite window.
--
-- Recorded (one entry each):
--   level   - PLAYER_LEVEL_UP: the new level
--   quest   - QUEST_TURNED_IN: quest name and quest level (read on
--             QUEST_COMPLETE, while the reward window is open)
--   zone    - first visit of a zone (ZONE_CHANGED_NEW_AREA / login), outside instances
--   death   - PLAYER_DEAD: zone and subzone
--   dungeon - entering a dungeon or raid (once until the player leaves it)
--   boss    - ENCOUNTER_END with success, where the client sends it
--
-- Kept per character in Nx.db.char.Journey (CarbData, the per-character
-- section of AceDB): { entries = { oldest .. newest }, zones = { [zone] = true },
-- instance = name of the instance the player is in }. Only the MAX newest
-- entries are kept. Nx.db.profile.General.JourneyRecord = false stops recording.
--
-- Public API:
--   Journey:Store()                  - the character's table, or nil before AceDB
--   Journey:Add(kind, fields)        - record an entry (respects the option and MAX)
--   Journey:Filter(entries, group, text) - newest first, by group and search text
--   Journey:Describe(entry)          - text of an entry in the current language
--   Journey:OnEvent(event, ...)      - client events
--   Journey:ToggleShow()             - open / close the window (/carb jornada)

local Carbonite = _G.Carbonite
local L = LibStub("AceLocale-3.0"):GetLocale("Carbonite")

local Journey = {}
Carbonite.Modules.Journey = Journey

Journey.MAX = 500

-- Filter groups shown on the left of the window, in order: key, label, kinds.
Journey.GROUPS = {
    { key = "all", label = "All", kinds = nil },
    { key = "level", label = "Levels", kinds = { level = true } },
    { key = "quest", label = "Quests", kinds = { quest = true } },
    { key = "zone", label = "Zones", kinds = { zone = true } },
    { key = "death", label = "Deaths", kinds = { death = true } },
    { key = "dungeon", label = "Dungeons", kinds = { dungeon = true, boss = true } },
}

local function call(name, ...)
    local fn = _G[name]
    if type(fn) == "function" then return fn(...) end
end

local function text(value)
    return type(value) == "string" and value or nil
end

-------------------------------------------------------------------------------
-- Storage
-------------------------------------------------------------------------------

function Journey:Store()
    local Nx = _G.Nx
    local char = Nx and Nx.db and Nx.db.char
    if type(char) ~= "table" then return nil end
    local store = char.Journey
    if type(store) ~= "table" then
        store = {}
        char.Journey = store
    end
    store.entries = store.entries or {}
    store.zones = store.zones or {}
    return store
end

function Journey:Enabled()
    local Nx = _G.Nx
    local general = Nx and Nx.db and Nx.db.profile and Nx.db.profile.General
    return not (general and general.JourneyRecord == false)
end

function Journey:Add(kind, fields)
    if not self:Enabled() then return nil end
    local store = self:Store()
    if not store then return nil end
    local entry = {
        t = call("time") or 0,
        k = kind,
        z = text(call("GetRealZoneText")) or "",
        l = tonumber(call("UnitLevel", "player")) or 0,
    }
    for key, value in pairs(fields or {}) do entry[key] = value end
    local entries = store.entries
    entries[#entries + 1] = entry
    while #entries > self.MAX do tremove(entries, 1) end
    if self.Win and self.Win:IsShown() then self:Update() end
    return entry
end

-------------------------------------------------------------------------------
-- Text and filter
-------------------------------------------------------------------------------

function Journey:Describe(entry)
    local kind, name = entry.k, entry.n or ""
    if kind == "level" then
        return format(L["Reached level %d"], entry.n or entry.l or 0)
    elseif kind == "quest" then
        if (entry.q or 0) > 0 then
            return format(L["Quest completed: [%d] %s"], entry.q, name)
        end
        return format(L["Quest completed: %s"], name)
    elseif kind == "zone" then
        return format(L["First visit: %s"], entry.z or "")
    elseif kind == "death" then
        local where = entry.z or ""
        if entry.s and entry.s ~= "" and entry.s ~= where then
            where = where .. ", " .. entry.s
        end
        return format(L["Died in %s"], where)
    elseif kind == "dungeon" then
        return format(L["Entered %s"], name)
    elseif kind == "boss" then
        return format(L["Defeated %s"], name)
    end
    return name
end

local function group(key)
    for _, g in ipairs(Journey.GROUPS) do
        if g.key == key then return g end
    end
    return Journey.GROUPS[1]
end

--- Entries of `group` (a GROUPS key, nil for all) whose text or zone holds
--- `search` (ignoring case and accents, plain), newest first.
function Journey:Filter(entries, groupKey, search)
    local kinds = group(groupKey).kinds
    local matches = Nx.SearchBox.Matches
    local out = {}
    for i = #(entries or {}), 1, -1 do
        local e = entries[i]
        if not kinds or kinds[e.k] then
            if matches(self:Describe(e) .. " " .. (e.z or ""), search) then
                out[#out + 1] = e
            end
        end
    end
    return out
end

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------

-- Quest level and name from the open quest log (nil when not in the log).
local function questFromLog(id, title)
    local index = id and call("GetQuestLogIndexByID", id)
    if type(index) == "number" and index > 0 then
        local logTitle, level = call("GetQuestLogTitle", index)
        return text(logTitle) or title, tonumber(level)
    end
    return title, nil
end

local function questTitle(id)
    local api = _G.C_QuestLog
    if id and type(api) == "table" and type(api.GetQuestInfo) == "function" then
        return text(api.GetQuestInfo(id))
    end
end

function Journey:OnQuestComplete()
    local id = tonumber(call("GetQuestID"))
    if id == 0 then id = nil end
    local title, level = questFromLog(id, text(call("GetTitleText")))
    self.pendingQuest = { id = id, n = title, q = level }
end

function Journey:OnQuestTurnedIn(id)
    id = tonumber(id)
    local p = self.pendingQuest
    self.pendingQuest = nil
    local name, level
    if p and (p.id == nil or p.id == id) then
        name, level = p.n, p.q
    end
    if not name or not level then
        local logName, logLevel = questFromLog(id, nil)
        name = name or logName
        level = level or logLevel
    end
    name = name or questTitle(id) or (id and ("#" .. id)) or "?"
    self:Add("quest", { n = name, q = level, id = id })
end

-- Zone first visits and dungeon entries.
function Journey:OnZone()
    local store = self:Store()
    if not store then return end
    local inInstance, kind = call("IsInInstance")
    if inInstance and (kind == "party" or kind == "raid") then
        local name = text(call("GetInstanceInfo")) or text(call("GetRealZoneText"))
        if name and name ~= "" and store.instance ~= name then
            if self:Add("dungeon", { n = name }) then store.instance = name end
        end
        return
    end
    store.instance = nil
    if inInstance then return end
    local zone = text(call("GetRealZoneText"))
    if zone and zone ~= "" and not store.zones[zone] then
        if self:Add("zone") then store.zones[zone] = true end
    end
end

function Journey:OnEvent(event, ...)
    if event == "PLAYER_LEVEL_UP" then
        local level = tonumber((...))
        self:Add("level", { n = level, l = level })
    elseif event == "QUEST_COMPLETE" then
        self:OnQuestComplete()
    elseif event == "QUEST_TURNED_IN" then
        self:OnQuestTurnedIn(...)
    elseif event == "PLAYER_DEAD" then
        self:Add("death", { s = text(call("GetSubZoneText")) })
    elseif event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_ENTERING_WORLD" then
        self:OnZone()
    elseif event == "ENCOUNTER_END" then
        local _, name, _, _, success = ...
        if success == 1 and text(name) then self:Add("boss", { n = name }) end
    end
end

local frame = CreateFrame("Frame")
Journey.frame = frame
for _, event in ipairs({ "PLAYER_LEVEL_UP", "QUEST_COMPLETE", "QUEST_TURNED_IN", "PLAYER_DEAD",
                         "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD", "ENCOUNTER_END" }) do
    -- A client without the event refuses the registration; skip it.
    pcall(frame.RegisterEvent, frame, event)
end
frame:SetScript("OnEvent", function(_, event, ...) Journey:OnEvent(event, ...) end)

-------------------------------------------------------------------------------
-- Window
-------------------------------------------------------------------------------

function Journey:ToggleShow()
    if not self.Win then self:Create() end
    self.Win:Show(not self.Win:IsShown())
    if self.Win:IsShown() then self:Update() end
end

function Journey:Create()
    local Nx = _G.Nx
    local win = Nx.Window:Create("NxJourney", nil, nil, nil, 1)
    self.Win = win
    self.Group = self.Group or "all"
    win.Frm.NxInst = self
    win:CreateButtons(true, true)
    win:InitLayoutData(nil, -.2, -.15, -.6, -.6)
    win.Frm:SetToplevel(true)
    win:Show(false)
    if type(_G.UISpecialFrames) == "table" then tinsert(_G.UISpecialFrames, win.Frm:GetName()) end

    -- Left: filter by type.
    local groups = Nx.List:Create(false, 0, 0, 1, 1, win.Frm)
    self.GroupList = groups
    groups:SetUser(self, self.OnGroupEvent)
    groups:ColumnAdd(L["Type"], 1, 120)
    win:Attach(groups.Frm, 0, .16, 0, 1)

    -- Right: search box over the entries.
    local box = Nx.SearchBox:Create(win.Frm, function() self:Update() end,
        { placeholder = L["Search the journey..."], maxLetters = 60 })
    self.EditBox = box
    win:Attach(box.Frm, .16, 1, 0, 18)

    local list = Nx.List:Create(false, 0, 0, 1, 1, win.Frm)
    self.List = list
    list:ColumnAdd(L["Date"], 1, 110)
    list:ColumnAdd(L["Level"], 2, 40, "RIGHT")
    list:ColumnAdd(L["Zone"], 3, 150)
    list:ColumnAdd(L["Event"], 4, 600)
    win:Attach(list.Frm, .16, 1, 18, 1)

    for i, g in ipairs(self.GROUPS) do
        groups:ItemAdd(i)
        groups:ItemSet(1, L[g.label])
    end
    groups:Update()
end

function Journey:OnGroupEvent(eventName, sel)
    local index = self.GroupList:ItemGetData(sel)
    local g = index and self.GROUPS[index]
    if g and eventName == "select" then
        self.Group = g.key
        self:Update()
    end
end

function Journey:Update()
    if not self.Win then return end
    local store = self:Store()
    local search = self.EditBox and self.EditBox:GetText() or ""
    local rows = self:Filter(store and store.entries, self.Group, search)
    self.Win:SetTitle(format(L["Character Journey (%d)"], #rows))
    local list = self.List
    list:Empty()
    for i, e in ipairs(rows) do
        list:ItemAdd(i)
        list:ItemSet(1, call("date", L["%m/%d/%y %H:%M"], e.t) or "")
        list:ItemSet(2, tostring(e.l or ""))
        list:ItemSet(3, e.z or "")
        list:ItemSet(4, self:Describe(e))
    end
    list:Update()
end

local Slash = Carbonite.Core and Carbonite.Core.SlashCommands
if Slash then
    Slash:Register("jornada", function() Journey:ToggleShow() end, "open the character journey")
    Slash:Register("journey", function() Journey:ToggleShow() end)
end
