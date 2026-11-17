-- Carbonite.Quests | ForeverCoreColumn
-- The ForeverCore column (SkillUpForever and the other Forever addons dock
-- into it) steps aside for Questie's, EllesmereUI's and EQOT's quest lists,
-- but not for the Carbonite watch list (#85). ForeverCore finds those lists
-- by name, in UI/TrackerHost.lua: Questie_BaseFrame, EUI_CustomQuestTracker
-- and EQOT's API module (EQObjectiveTracker:GetModule("API"), with
-- GetListBounds and AddLayoutListener). It has no registry another addon can
-- join, so this file publishes the watch list's edges in the same shape as
-- EQOT's API, ready for ForeverCore to read once it consults Carbonite.
--
-- Public API, Carbonite.Quests.WatchBounds (inert unless ForeverCore loaded):
--   WatchBounds:GetListBounds()        left, right, top, bottom in UIParent
--                                      units, or nil while the list is hidden
--   WatchBounds:AddLayoutListener(l)   l = { id = "...", onLayout = fn }; fn()
--                                      runs after the list shows, hides, moves,
--                                      resizes, minimizes or restores
--   WatchBounds:RemoveLayoutListener(id)
--
-- Only the watch window is read: nothing of another addon is moved, anchored
-- to or hooked.

local Carbonite = _G.Carbonite
local Nx = _G.Nx
if not Carbonite or not Nx then return end

local WatchBounds = { API = 1 }
Carbonite.Quests = Carbonite.Quests or {}
Carbonite.Quests.WatchBounds = WatchBounds

-- A move or a resize with no script of its own (a drag, minimize to the
-- screen edge, a profile load) is caught by a light poll while someone listens.
local WATCH_INTERVAL = 0.25
-- A list faded to nothing is as good as hidden.
local ALPHA_HIDDEN = 0.01

local enabled = false
local listeners, order = {}, {}
local hooked = setmetatable({}, { __mode = "k" })
local ticker, sinceTick, lastPlace

local function Window()
    local watch = Nx.Quest and Nx.Quest.Watch
    return watch and watch.Win
end

local function Alpha(frame)
    local get = frame.GetEffectiveAlpha or frame.GetAlpha
    if type(get) ~= "function" then return 1 end
    local ok, alpha = pcall(get, frame)
    return ok and type(alpha) == "number" and alpha or 1
end

local function Bounds()
    local win = Window()
    local frame = win and win.Frm
    if not frame or not frame:IsVisible() or Alpha(frame) <= ALPHA_HIDDEN then return nil end
    local left, right, top, bottom = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
    if not (left and right and top and bottom) then return nil end
    local toParent = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    return left * toParent, right * toParent, top * toParent, bottom * toParent
end

local function Place()
    local left, right, top, bottom = Bounds()
    if not left then return "hidden" end
    return format("%.1f|%.1f|%.1f|%.1f", left, right, top, bottom)
end

-- Tell every listener once per real change. While the player drags or sizes
-- the window it is left alone; one call follows where it was let go.
local function Notify()
    if #order == 0 then return end
    local win = Window()
    if win and win.MovSizing then return end
    local place = Place()
    if place == lastPlace then return end
    lastPlace = place
    for _, id in ipairs(order) do
        local fn = listeners[id]
        if fn then pcall(fn) end
    end
end

local function Attach()
    local win = Window()
    local frame = win and win.Frm
    if not frame or hooked[frame] or type(frame.HookScript) ~= "function" then return end
    hooked[frame] = true
    frame:HookScript("OnShow", Notify)
    frame:HookScript("OnHide", Notify)
    frame:HookScript("OnSizeChanged", Notify)
end

local function OnTick(_, elapsed)
    sinceTick = (sinceTick or 0) + (elapsed or 0)
    if sinceTick < WATCH_INTERVAL then return end
    sinceTick = 0
    Attach()
    Notify()
end

local function SyncTicker()
    local listening = enabled and #order > 0
    if not ticker then
        if not listening then return end
        ticker = CreateFrame("Frame")
    end
    ticker:SetScript("OnUpdate", listening and OnTick or nil)
end

function WatchBounds:IsActive()
    return enabled
end

function WatchBounds:GetListBounds()
    if not enabled then return nil end
    return Bounds()
end

function WatchBounds:AddLayoutListener(listener)
    if not enabled or type(listener) ~= "table" or listener.id == nil
        or type(listener.onLayout) ~= "function" then
        return false
    end
    if not listeners[listener.id] then order[#order + 1] = listener.id end
    listeners[listener.id] = listener.onLayout
    Attach()
    lastPlace = Place()
    SyncTicker()
    return true
end

function WatchBounds:RemoveLayoutListener(id)
    if listeners[id] == nil then return false end
    listeners[id] = nil
    for i = #order, 1, -1 do
        if order[i] == id then table.remove(order, i) end
    end
    SyncTicker()
    return true
end

-- Runs at login: with no ForeverCore there is nothing to tell, so nothing runs.
function WatchBounds:Start()
    if enabled or rawget(_G, "ForeverCore") == nil then return false end
    enabled = true
    local watch = Nx.Quest and Nx.Quest.Watch
    if watch and type(watch.Open) == "function" then
        hooksecurefunc(watch, "Open", Attach)
    end
    Attach()
    SyncTicker()
    return true
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    WatchBounds:Start()
end)
