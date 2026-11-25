-- Carbonite | Modules / Map / DungeonRouteEditor
-- Player routes on the dungeon chart (#272): the routes menu, the route
-- editor and a text window for export, import and names.
--
-- Editor: player routes only; editing a standard route copies it first.
-- Tools: path, side path, stop, note. Path: left-click adds a point,
-- right-click takes the last one away, shift-click starts a new piece.
-- Stop / note: left-click places one (then asks for its name / text);
-- on a pin, left-click renames, right-click deletes. A stop named like a
-- boss fight of the dungeon becomes that boss (it ticks itself off),
-- else it is optional. Undo up to 80 steps.
--
-- Public (Nx.DungeonRouteEditor):
--   E:IsActive() / E:IsEditing(key, route) / E:Start(key) / E:Stop()
--   E:SetTool(tool) / E:Undo() / E:DeletePath()
--   E:OnMapClick(button, floor, x, y, shift) / E:OnPinClick(ref, button)
--   E:UpdateBar(chartFrame, key)          the tool bar on the chart
--   E.TextWindow(title, text, onAccept)   a text box with OK / Cancel
--   Nx.DungeonChart:OpenRouteMenu()

local Nx = _G.Nx
if not Nx then return end

local L = LibStub("AceLocale-3.0"):GetLocale("Carbonite")

local E = {}
Nx.DungeonRouteEditor = E

E.MAX_UNDO = 80
E.TOOLS = { "main", "side", "stop", "note" }

local state -- { key, route, tool, path, undo } while editing

local function R() return Nx.DungeonRoutes end
local function DC() return Nx.DungeonChart end

local function round(v)
    return math.floor(v * 10000 + 0.5) / 10000
end

local function changed()
    R().RecalcProgress(state.route)
    R().Version = R().Version + 1
    if DC() then DC().Dirty = true end
    if Nx.DungeonGuide then Nx.DungeonGuide.Dirty = true end
end

local function snapshot()
    local copy = R().DeepCopy(state.route)
    table.insert(state.undo, { paths = copy.paths, stops = copy.stops, notes = copy.notes, links = copy.links, path = state.path })
    if #state.undo > E.MAX_UNDO then table.remove(state.undo, 1) end
end

function E:IsActive()
    return state ~= nil
end

function E:IsEditing(key, route)
    return state ~= nil and state.key == key and state.route == route
end

function E:State()
    return state
end

-- Starts editing the active route of `key`; a standard route is copied first.
function E:Start(key)
    local Rt = R()
    local route = Rt:ActiveRoute(key)
    if not route then
        route = Rt:AddUserRoute(key, { name = L["New route"], paths = {}, stops = {}, notes = {}, links = {} })
    elseif Rt.IsBuiltIn(route) then
        local copy = Rt:CopyRoute(route)
        Rt.SetNames(copy, nil)
        copy.name = format(L["%s (copy)"], Rt:RouteName(route))
        route = Rt:AddUserRoute(key, copy)
    end
    state = { key = key, route = route, tool = "main", path = nil, undo = {} }
    changed()
    return route
end

function E:Stop()
    state = nil
    if DC() then DC().Dirty = true end
end

function E:SetTool(tool)
    if not state then return end
    state.tool = tool
    state.path = nil
    if DC() then DC().Dirty = true end
end

function E:Undo()
    if not state or #state.undo == 0 then return false end
    local s = table.remove(state.undo)
    state.route.paths, state.route.stops, state.route.notes, state.route.links = s.paths, s.stops, s.notes, s.links
    state.path = s.path
    changed()
    return true
end

function E:DeletePath()
    if not state or not state.path or not state.route.paths[state.path] then return false end
    snapshot()
    table.remove(state.route.paths, state.path)
    state.path = nil
    changed()
    return true
end

-- A stop named like one of the dungeon's boss fights becomes that boss.
local function nameStop(stop, name)
    local Rt = R()
    Rt.SetNames(stop, nil)
    stop.name = tostring(name or ""):gsub("[\t\r\n|]", " "):sub(1, 200)
    local e = Nx.DungeonRouteCodec and Nx.DungeonRouteCodec.EncounterByName(state.key, stop.name)
    if e then
        stop.kind = "boss"
        stop.encounters = Rt.DeepCopy(e.ids)
    else
        stop.kind = stop.kind == "rare" and "rare" or "optional"
        stop.encounters = nil
    end
end
E.NameStop = function(stop, name) return nameStop(stop, name) end

function E:OnMapClick(button, floor, x, y, shift)
    if not state then return end
    local route, tool = state.route, state.tool
    x, y = round(x), round(y)
    if tool == "main" or tool == "side" then
        local path = state.path and route.paths[state.path]
        if button == "RightButton" then
            if path and #path.pts >= 2 then
                snapshot()
                path.pts[#path.pts] = nil
                path.pts[#path.pts] = nil
                if #path.pts == 0 then
                    table.remove(route.paths, state.path)
                    state.path = nil
                end
                changed()
            end
            return
        end
        snapshot()
        if shift or not path or path.floor ~= floor or path.kind ~= tool then
            path = { kind = tool, floor = floor, pts = {} }
            table.insert(route.paths, path)
            state.path = #route.paths
        end
        path.pts[#path.pts + 1] = x
        path.pts[#path.pts + 1] = y
        changed()
    elseif button == "LeftButton" and tool == "stop" then
        snapshot()
        local stop = { kind = "optional", floor = floor, x = x, y = y, name = "" }
        table.insert(route.stops, stop)
        changed()
        E.TextWindow(L["Stop name"], "", function(text)
            if state then
                nameStop(stop, text)
                changed()
            end
        end)
    elseif button == "LeftButton" and tool == "note" then
        E.TextWindow(L["Note"], "", function(text)
            if state and text ~= "" then
                snapshot()
                table.insert(route.notes, { floor = floor, x = x, y = y, text = text:gsub("|", ""):sub(1, 200) })
                changed()
            end
        end)
    end
end

function E:OnPinClick(ref, button)
    if not state then return end
    local route = state.route
    local list = ref.kind == "stop" and route.stops or route.notes
    local entry = list[ref.index]
    if not entry then return end
    if button == "RightButton" then
        snapshot()
        table.remove(list, ref.index)
        changed()
        return
    end
    if ref.kind == "stop" then
        E.TextWindow(L["Stop name"], R():StopName(entry), function(text)
            if state then
                snapshot()
                nameStop(entry, text)
                changed()
            end
        end)
    else
        E.TextWindow(L["Note"], R().Loc(entry, "text") or "", function(text)
            if state then
                snapshot()
                R().SetNames(entry, nil, "text")
                entry.text = text:gsub("|", ""):sub(1, 200)
                changed()
            end
        end)
    end
end

--------------------------------------------------------------------------------
-- Tool bar on the chart
--------------------------------------------------------------------------------

local TOOL_TEXT = { main = "Path", side = "Side path", stop = "Stop", note = "Note" }

local function button(parent, text, onClick)
    local b = _G.CreateFrame("Button", nil, parent)
    b:SetHeight(18)
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(.15, .15, .18, .95)
    b.Bg = bg
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, .15)
    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("CENTER")
    fs:SetText(text)
    b:SetWidth(fs:GetStringWidth() + 14)
    b:SetScript("OnClick", onClick)
    return b
end

local function buildBar(f)
    local bar = _G.CreateFrame("Frame", nil, f)
    bar:SetPoint("TOPLEFT", f.Holder, "TOPLEFT", 4, -4)
    bar:SetSize(10, 20)
    bar:SetFrameLevel(f.Holder:GetFrameLevel() + 40)
    bar.Tools = {}
    local last
    local function place(b)
        b:ClearAllPoints()
        if last then b:SetPoint("LEFT", last, "RIGHT", 3, 0) else b:SetPoint("LEFT", bar, "LEFT", 0, 0) end
        last = b
    end
    for _, tool in ipairs(E.TOOLS) do
        local b = button(bar, L[TOOL_TEXT[tool]], function() E:SetTool(tool) end)
        bar.Tools[tool] = b
        place(b)
    end
    place(button(bar, L["Undo"], function() E:Undo() end))
    place(button(bar, L["Delete piece"], function() E:DeletePath() end))
    place(button(bar, L["Done"], function() E:Stop() end))
    local hint = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -4)
    hint:SetJustifyH("LEFT")
    bar.Hint = hint
    f.EditBar = bar
    return bar
end

local HINT = {
    main = "Left-click: add a point. Right-click: remove the last point. Shift-click: new piece.",
    side = "Left-click: add a point. Right-click: remove the last point. Shift-click: new piece.",
    stop = "Left-click: place a stop. On a stop: left-click renames, right-click deletes.",
    note = "Left-click: place a note. On a note: left-click edits, right-click deletes.",
}

function E:UpdateBar(f, key)
    local on = state ~= nil and key ~= nil and state.key == key
    if not on then
        if f.EditBar then f.EditBar:Hide() end
        return
    end
    local bar = f.EditBar or buildBar(f)
    for tool, b in pairs(bar.Tools) do
        if tool == state.tool then b.Bg:SetColorTexture(.2, .45, .2, .95) else b.Bg:SetColorTexture(.15, .15, .18, .95) end
    end
    bar.Hint:SetText(L[HINT[state.tool]])
    bar:Show()
end

--------------------------------------------------------------------------------
-- Text window
--------------------------------------------------------------------------------

local win
local function buildWindow()
    local f = _G.CreateFrame("Frame", "CarboniteDungeonRouteText", _G.UIParent, "BackdropTemplate")
    f:SetSize(460, 220)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    if f.SetBackdrop then
        f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        f:SetBackdropColor(.05, .05, .07, .96)
        f:SetBackdropBorderColor(.6, .5, .1, 1)
    end
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 10, -10)
    f.Title = title
    local scroll = _G.CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 10, -30)
    scroll:SetPoint("BOTTOMRIGHT", -30, 40)
    local edit = _G.CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(true)
    edit:SetFontObject("ChatFontNormal")
    edit:SetWidth(410)
    edit:SetScript("OnEscapePressed", function() f:Hide() end)
    scroll:SetScrollChild(edit)
    f.Edit = edit
    local ok = _G.CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    ok:SetSize(90, 22)
    ok:SetPoint("BOTTOMRIGHT", -110, 10)
    ok:SetText(_G.OKAY or "OK")
    ok:SetScript("OnClick", function()
        local accept = f.OnAccept
        f:Hide()
        if accept then accept((edit:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")) end
    end)
    local cancel = _G.CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    cancel:SetSize(90, 22)
    cancel:SetPoint("BOTTOMRIGHT", -10, 10)
    cancel:SetText(_G.CANCEL or "Cancel")
    cancel:SetScript("OnClick", function() f:Hide() end)
    _G.tinsert(_G.UISpecialFrames, "CarboniteDungeonRouteText")
    return f
end

-- A text box (Ctrl+C / Ctrl+V); onAccept(text) on OK, nothing on Cancel.
function E.TextWindow(title, text, onAccept)
    win = win or buildWindow()
    win.Title:SetText(title)
    win.OnAccept = onAccept
    win.Edit:SetText(text or "")
    win:Show()
    win.Edit:SetFocus()
    win.Edit:HighlightText()
end

--------------------------------------------------------------------------------
-- Routes menu
--------------------------------------------------------------------------------

-- The dungeon the routes menu acts on: the one on the chart, else the current one.
local function menuKey()
    local chart = DC()
    if chart and chart.Src == "routes" and chart.Shown then return chart.Shown end
    local Rt = R()
    return Rt and Rt:Load() and Rt:CurrentKey()
end

function E:Export(key)
    local route = R():ActiveRoute(key)
    if not route then return end
    E.TextWindow(L["Export route (Ctrl+C)"], Nx.DungeonRouteCodec.Export(key, route))
end

function E:Import()
    E.TextWindow(L["Import route (Ctrl+V)"], "", function(text)
        local key, route = Nx.DungeonRouteCodec.Import(text)
        if not key then
            if Nx.prt then Nx.prt(L[route] or route) end
            return
        end
        local same = Nx.DungeonRouteShare and Nx.DungeonRouteShare.SameRoute(key, Nx.DungeonRouteCodec.Export(key, route))
        if same then
            R():SetActive(key, same.id)
        else
            R():AddUserRoute(key, route)
        end
        if DC() then DC():Open("routes", key) end
    end)
end

function Nx.DungeonChart:OpenRouteMenu()
    local Rt = R()
    if not (Rt and Rt:Load()) then
        if Nx.prt then Nx.prt(L["Dungeon routes are not installed (Carbonite.Dungeons)"]) end
        return
    end
    local key = menuKey()
    self.RouteMenu = self.RouteMenu or Nx.Menu:Create(_G.UIParent, 260)
    local menu = self.RouteMenu
    menu.Items = {}
    menu:AddItem(0, L["Import route..."], function() E:Import() end)
    if not key then
        menu:Open()
        return
    end
    menu:AddItem(0, "|cffffd100" .. Rt:KeyName(key))
    local active = Rt:ActiveRoute(key)
    for _, route in ipairs(Rt:Routes(key)) do
        local item = menu:AddItem(0, "  " .. Rt:RouteName(route), function() Rt:SetActive(key, route.id) end)
        if route == active then item:SetChecked(true) end
    end
    menu:AddItem(0, "")
    menu:AddItem(0, L["Edit route"], function() E:Start(key) end)
    if active and not Rt.IsBuiltIn(active) then
        menu:AddItem(0, L["Rename route..."], function()
            E.TextWindow(L["Route name"], Rt:RouteName(active), function(text)
                if text ~= "" then Rt:RenameRoute(key, active.id, text) end
            end)
        end)
        menu:AddItem(0, L["Delete route"], function()
            if E:IsEditing(key, active) then E:Stop() end
            Rt:DeleteRoute(key, active.id)
        end)
    end
    local rec = Rt.Recorder
    if rec and rec:CanBuild(key) then
        menu:AddItem(0, L["Make route from this run"], function() rec:Build(key) end)
    end
    menu:AddItem(0, L["Export route..."], function() E:Export(key) end)
    local S = Nx.DungeonRouteShare
    if S and active then
        menu:AddItem(0, "")
        menu:AddItem(0, L["Send route to group"], function() S:SendRoute(key, active) end)
        menu:AddItem(0, L["Send route to guild"], function() S:SendRoute(key, active, "GUILD") end)
        menu:AddItem(0, L["Post boss order in chat"], function() S:PostOrder(key, active) end)
    end
    menu:Open()
end
