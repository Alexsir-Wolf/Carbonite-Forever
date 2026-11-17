-- Carbonite | Modules / Map / TargetsWindow
-- "Destinations" window (#70): lists the goto queue (Targets.lua) in order
-- with name, zone and distance, and edits it: move up / down, go now (make
-- it the first), remove, reverse and clear all.
--
-- The queue verbs below work on queue indexes and are the testable part;
-- the window only maps the selected row to an index and calls them.
--
-- Opens with /carb destinos, the "Route..." submenu of the map's right-click
-- menu and the NxTOGGLETARGETS key binding. While shown it refreshes when the
-- queue changes (EventBus) and once a second, because the map engine drops a
-- reached target straight from the table and the distances change as the
-- player moves.

local Carbonite = _G.Carbonite
local L = LibStub("AceLocale-3.0"):GetLocale("Carbonite")

local Window = {}
Carbonite.Modules.Map.TargetsWindow = Window

Window.REFRESH = 1  -- seconds between refreshes while shown

local function targets()
    return Carbonite.Modules.Map.Targets
end

local function primaryMap()
    local NxMap = _G.Nx and _G.Nx.Map
    return NxMap and NxMap.Maps and NxMap.Maps[1]
end

-- After any edit: rebuild the arrow path at once and tell the listeners.
local function changed()
    local map = primaryMap()
    if map then
        map.Tracking = {}
        map.UpdateTrackingDelay = 0
    end
    Carbonite.Core.EventBus:Fire("MAP_TARGETS_CHANGED")
end

-------------------------------------------------------------------------------
-- Queue verbs (by queue index; each returns the new index of the moved row)
-------------------------------------------------------------------------------

local function valid(i)
    return type(i) == "number" and i >= 1 and i <= targets():Count()
end

function Window:MoveUp(i)
    if not valid(i) or i == 1 then return i end
    targets():Reorder(i, i - 1)
    changed()
    return i - 1
end

function Window:MoveDown(i)
    if not valid(i) or i == targets():Count() then return i end
    targets():Reorder(i, i + 1)
    changed()
    return i + 1
end

--- Make the target at `i` the first one: the arrow points to it now.
function Window:GoNow(i)
    if not valid(i) or i == 1 then return i end
    targets():Reorder(i, 1)
    changed()
    return 1
end

function Window:Remove(i)
    if not valid(i) then return i end
    local map = primaryMap()
    local t = map.Targets[i]
    if not (t.UniqueId and targets():Remove(t.UniqueId)) then
        table.remove(map.Targets, i)
    end
    changed()
    return math.min(i, targets():Count())
end

function Window:Reverse()
    targets():Reverse()
    changed()
end

function Window:ClearAll()
    local map = primaryMap()
    if map and map.ClearTargets then map:ClearTargets() else targets():Clear() end
    changed()
end

-------------------------------------------------------------------------------
-- Rows
-------------------------------------------------------------------------------

local function zoneName(mapId)
    local NxMap = _G.Nx and _G.Nx.Map
    if mapId and NxMap and NxMap.IdToName then
        local ok, name = pcall(NxMap.IdToName, NxMap, mapId)
        if ok and type(name) == "string" then return name end
    end
    return ""
end

--- Straight-line distance in yards from the player to `t` (nil when the
--- player position is unknown). Same scale as Nx.Map:UpdateTargets.
function Window:Distance(t)
    local map = primaryMap()
    local px, py = map and map.PlyrX, map and map.PlyrY
    local tx, ty = t.TargetMX, t.TargetMY
    if not (px and py and tx and ty) or (px == 0 and py == 0) then return nil end
    local dx, dy = tx - px, ty - py
    return (dx * dx + dy * dy) ^ .5 * 4.575
end

--- The queue as rows { index, name, zone, dist } in order.
function Window:Rows()
    local rows = {}
    targets():Each(function(t, i)
        local name = t.TargetName
        if type(name) ~= "string" or name == "" then name = L["Goto"] end
        rows[#rows + 1] = { index = i, name = name, zone = zoneName(t.MapId), dist = self:Distance(t) }
    end)
    return rows
end

local function distText(yd)
    if not yd then return "" end
    return format("%d %s", floor(yd + .5), L["yds"])
end

-------------------------------------------------------------------------------
-- Window
-------------------------------------------------------------------------------

function Window:ToggleShow()
    if not self.Win then self:Create() end
    self.Win:Show(not self.Win:IsShown())
    if self.Win:IsShown() then self:Update() end
end

function Window:IsShown()
    return self.Win ~= nil and self.Win:IsShown()
end

-- Toolbar actions, in order: label key, method, acts on the selected row.
Window.ACTIONS = {
    { "Move Up", "MoveUp", true },
    { "Move Down", "MoveDown", true },
    { "Go Now", "GoNow", true },
    { "Remove", "Remove", true },
    { "Reverse Targets", "Reverse" },
    { "Clear All", "ClearAll" },
}

--- Run toolbar / menu action `n` on the selected row.
function Window:Do(n)
    local a = self.ACTIONS[n]
    if not a then return end
    if a[3] then
        local sel = self.List and self.List:GetSelected()
        local index = sel and self.List:ItemGetData(sel)
        if not index then return end
        local new = self[a[2]](self, index)
        if new and new >= 1 and self.List then self.List.Selected = new end
    else
        self[a[2]](self)
    end
    self:Update()
end

function Window:Create()
    local Nx = _G.Nx
    local win = Nx.Window:Create("NxTargets", nil, nil, nil, 1)
    self.Win = win
    win.Frm.NxInst = self
    win:CreateButtons(true, true)
    win:InitLayoutData(nil, -.35, -.25, -.3, -.4)
    win.Frm:SetToplevel(true)
    win:Show(false)
    if type(_G.UISpecialFrames) == "table" then tinsert(_G.UISpecialFrames, win.Frm:GetName()) end

    -- Toolbar on top: one button per action.
    local bar = CreateFrame("Frame", nil, win.Frm)
    self.Bar = bar
    local x = 0
    for n, a in ipairs(self.ACTIONS) do
        local label = L[a[1]]
        local w = string.len(label) * 7 + 16
        Nx.Button:Create(bar, "Txt64", label, nil, x, 0, "TOPLEFT", w, 20, function() self:Do(n) end, self)
        x = x + w + 2
    end
    win:Attach(bar, 0, 1, 0, 22)

    local list = Nx.List:Create(false, 0, 0, 1, 1, win.Frm)
    self.List = list
    list:SetUser(self, self.OnListEvent)
    list:ColumnAdd("#", 1, 24, "RIGHT")
    list:ColumnAdd(L["Name"], 2, 220)
    list:ColumnAdd(L["Zone"], 3, 150)
    list:ColumnAdd(L["Distance"], 4, 80, "RIGHT")
    win:Attach(list.Frm, 0, 1, 22, 1)

    -- Right-click menu on a row: the same actions.
    local menu = Nx.Menu:Create(list.Frm)
    self.Menu = menu
    for n, a in ipairs(self.ACTIONS) do
        menu:AddItem(0, L[a[1]], function() self:Do(n) end, self)
    end

    -- Distances follow the player; a reached target leaves the table.
    local elapsedTotal = 0
    bar:SetScript("OnUpdate", function(_, elapsed)
        elapsedTotal = elapsedTotal + (elapsed or 0)
        if elapsedTotal >= self.REFRESH then
            elapsedTotal = 0
            if self:IsShown() then self:Update() end
        end
    end)
end

function Window:OnListEvent(eventName, sel)
    if eventName == "menu" and sel and sel > 0 and self.Menu then
        self.Menu:Open()
    elseif eventName == "select" and _G.IsShiftKeyDown and _G.IsShiftKeyDown() then
        -- Shift+click: go to it now.
        local index = self.List:ItemGetData(sel)
        if index then
            self:GoNow(index)
            self.List.Selected = 1
            self:Update()
        end
    end
end

function Window:Update()
    if not self.Win then return end
    local rows = self:Rows()
    self.Win:SetTitle(format(L["Destinations (%d)"], #rows))
    local list = self.List
    list:Empty()
    for _, r in ipairs(rows) do
        list:ItemAdd(r.index)
        list:ItemSet(1, tostring(r.index))
        list:ItemSet(2, r.name)
        list:ItemSet(3, r.zone)
        list:ItemSet(4, distText(r.dist))
    end
    if #rows == 0 then
        list:ItemAdd(nil)
        list:ItemSet(2, L["No destinations. Shift+click Goto on the map to queue several."])
    end
    if (list.Selected or 0) > list:ItemGetNum() then list.Selected = list:ItemGetNum() end
    list:Update()
end

local function refresh()
    if Window:IsShown() then Window:Update() end
end
for _, event in ipairs({ "MAP_TARGET_ADDED", "MAP_TARGET_REMOVED", "MAP_TARGETS_CLEARED" }) do
    Carbonite.Core.EventBus:Subscribe(event, refresh)
end

local Slash = Carbonite.Core and Carbonite.Core.SlashCommands
if Slash then
    Slash:Register("destinos", function() Window:ToggleShow() end, "open the destination queue")
    Slash:Register("destinations", function() Window:ToggleShow() end)
end
