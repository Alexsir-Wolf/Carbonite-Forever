-- Carbonite | Modules / Map / MiniMap
-- Owns the public API around Carbonite's minimap integration. The
-- minimap rendering pipeline is intricate enough that the bulk of
-- the implementation still lives in NxMap.lua and uses the live
-- Nx.Map.Maps[1] instance for state; this class is the front door
-- that other modules (HUD, Quest, Notes, Travel) talk to instead
-- of reaching into the legacy table.
--
-- Public surface:
--   MiniMap:Zoom(delta)            zoom in/out by `delta` levels
--   MiniMap:ZoomIn() / ZoomOut()
--   MiniMap:Ping()                 ping at the cursor location
--   MiniMap:IsOwned()              true when Carbonite has replaced
--                                  Blizzard's minimap with its own
--   MiniMap:GetFrame()             the live minimap frame
--   MiniMap:GetScale() / GetZoom()
--   MiniMap:SetButtonVisible(name, on)  hide/show stock minimap chrome
--   MiniMap:ApplyButtonVisibility()
--   MiniMap:OnEnter(frame, motion) / OnLeave / OnMouseDown / OnMouseUp
--                                  unified mouse routing
--
-- The class fires three EventBus signals so unrelated modules can
-- react without polling:
--   MAP_MINIMAP_OWNED       fires after MinimapOwnInit completes
--   MAP_MINIMAP_ZOOMED      fires after Zoom; args: newScaleIndex
--   MAP_MINIMAP_PINGED      fires after Ping; args: wx, wy

local Carbonite = _G.Carbonite

local MiniMap = {}
Carbonite.Modules.Map.MiniMap = MiniMap

local function legacyMap()
    return _G.Nx and _G.Nx.Map and _G.Nx.Map.Maps and _G.Nx.Map.Maps[1]
end

local function nxMap()
    return _G.Nx and _G.Nx.Map
end

-- ---------------------------------------------------------------
-- Frame / state accessors. Thin wrappers but they centralize the
-- "is the minimap owned by Carbonite right now?" check so calling
-- code stops doing it ad-hoc.
-- ---------------------------------------------------------------

function MiniMap:GetFrame()
    local map = legacyMap()
    return map and map.MMFrm
end

function MiniMap:IsOwned()
    local map = legacyMap()
    return map and map.MMOwn == true or false
end

function MiniMap:GetZoom()
    local frame = self:GetFrame()
    return frame and frame.GetZoom and frame:GetZoom() or 0
end

function MiniMap:GetScale()
    local map = legacyMap()
    return map and map.MMScale
end

-- ---------------------------------------------------------------
-- Zoom verbs.
-- ---------------------------------------------------------------

function MiniMap:Zoom(delta)
    local map = legacyMap()
    if not map or not map.SetScaleOverTime then return end
    if delta and delta ~= 0 then map:SetScaleOverTime(delta) end

    -- Re-enable Blizzard's zoom buttons in case OnClick disabled them.
    local zin  = _G.MinimapZoomIn
    local zout = _G.MinimapZoomOut
    if zin  and zin.Enable  then zin:Enable()  end
    if zout and zout.Enable then zout:Enable() end

    Carbonite.Core.EventBus:Fire("MAP_MINIMAP_ZOOMED", self:GetZoom())
end

function MiniMap:ZoomIn()  self:Zoom(2)  end
function MiniMap:ZoomOut() self:Zoom(-2) end

-- ---------------------------------------------------------------
-- Pinging at the cursor location. The geometry math has to match
-- the legacy Ping function pixel for pixel because users have
-- muscle memory for where their pings land.
-- ---------------------------------------------------------------

function MiniMap:Ping()
    -- Also reached by Shift+click on the map (MapEngine); see CanPing.
    if not self:CanPing() then return end
    local map = legacyMap()
    if not map or not map.Frm or not map.MMFrm then return end
    if not _G.Nx or not _G.Nx.Util_GetMouseClampedXY then return end

    local frm = map.Frm
    local mx, my = _G.Nx.Util_GetMouseClampedXY(frm)
    local top    = frm:GetTop()
    local bottom = frm:GetBottom()
    my = top - (my + bottom)

    local info   = map.MapWorldInfo and map.MapWorldInfo[map.MapId]
    local scales = (info and info.City and not info.MMOutside and map.MMScalesC) or map.MMScales
    if not scales then return end

    local mm   = map.MMFrm
    local zoom = mm:GetZoom() + 1

    local wx, wy = map:FramePosToWorldPos(mx, my)
    local sc = scales[zoom] / mm:GetWidth()
    local x  = wx - map.PlyrX
    local y  = map.PlyrY - wy

    if mm.PingLocation then mm:PingLocation(x / sc, y / sc) end
    Carbonite.Core.EventBus:Fire("MAP_MINIMAP_PINGED", wx, wy)
end

-- ---------------------------------------------------------------
-- Mouse routing. The legacy entry points are object-style
-- (`function Nx.Map:MinimapOnMouseDown(button)` where `self` is
-- the minimap frame). This API takes the frame and the button
-- separately so other handlers can call it without the frame
-- masquerading as `self`.
-- ---------------------------------------------------------------

function MiniMap:OnMouseDown(frame, button)
    local map = legacyMap()
    if not map then return end

    -- Left click without zoom OR shift+click = ping (but not ctrl).
    if (map.MMZoomType == 0 and button == "LeftButton") or
       (IsShiftKeyDown() and not IsControlKeyDown()) then
        frame.NXPing = true
    else
        frame.NXPing = nil
        frame.NxMap = map
        if map.OnMouseDown then map.OnMouseDown(frame, button) end
    end
end

-- Whether addon code may ping the minimap. Forever runs the mainline code
-- base, where the ping is protected, while identifying as a Classic client.
function MiniMap:CanPing()
    local Expansion = Carbonite.Compat.Expansion
    return not (Expansion.isMainline or Expansion.isCamelot)
end

function MiniMap:OnMouseUp(frame, button)
    local map = legacyMap()
    if not map then return end

    if frame.NXPing then
        -- Mainline code bases (Retail, and Forever with its Classic .toc)
        -- forbid invoking Minimap_OnClick or PingLocation from a tainted
        -- addon code path. Suppress the ping there so we do not spew
        -- "AddOn ... blocked" errors; the user can disable MMOwn to get
        -- native Blizzard minimap clicks.
        if not self:CanPing() then return end

        if map.MMZoomType == 0 then
            if _G.Minimap_OnClick then
                _G.Minimap_OnClick(frame)
            elseif frame.OnClick then
                frame:OnClick(button or "LeftButton")
            end
        else
            self:Ping()
        end
    else
        frame.NxMap = map
        if map.OnMouseUp then map.OnMouseUp(frame, button) end
    end
end

-- ---------------------------------------------------------------
-- Gathering nodes under the integrated minimap (#275, #279). With a blip
-- tracking on (herbs, beasts... #284), the live minimap sits over Carbonite's icons
-- so its node blips show (#214), and it takes the mouse: Carbonite's
-- herb/ore icons (its own and GatherLite's) never get OnEnter, and
-- the game gives the blips no tooltip at all. While the cursor is
-- over the minimap:
--   1. the Carbonite icon under the cursor shows its own tooltip;
--   2. else the GatherLite node nearest the cursor names the blip.
-- ---------------------------------------------------------------

MiniMap.HOVER_INTERVAL = 0.1
MiniMap.BLIP_RADIUS = 8          -- pixels around the cursor

local function tracking(map)
    return map and map.MinimapBlipTracking and map:MinimapBlipTracking() or false
end

-- Shown icon frames with a tooltip under the cursor, from pool `frms`
-- (its first Next - 1 frames are the ones in use).
local function scanPool(frms, cx, cy, best, bestD)
    if not frms then return best, bestD end
    local used = (frms.Next or (#frms + 1)) - 1
    for i = 1, math.min(used, #frms) do
        local f = frms[i]
        if f and f.NxTip and f:IsShown() and f:IsMouseOver() then
            local s = f:GetEffectiveScale()
            if not s or s == 0 then s = 1 end
            local fx, fy = f:GetCenter()
            local d = fx and ((cx / s - fx) ^ 2 + (cy / s - fy) ^ 2) or 0
            if not bestD or d < bestD then best, bestD = f, d end
        end
    end
    return best, bestD
end

-- The Carbonite icon under the cursor (closest centre wins), or nil.
function MiniMap:IconAtCursor(map)
    if not tracking(map) then return nil end
    local cx, cy = _G.GetCursorPosition()
    local best, bestD = scanPool(map.IconStaticFrms, cx, cy)
    best = scanPool(map.IconFrms, cx, cy, best, bestD)
    return best
end
MiniMap.GatherPinAtCursor = MiniMap.IconAtCursor

-- World position under the cursor on the Carbonite map, or nil.
function MiniMap:CursorWorldPos(map)
    local frm = map and map.Frm
    local over = _G.Nx and _G.Nx.Util_IsMouseOver
    if not (frm and over and map.FramePosToWorldPos) then return nil end
    local mx, my = over(frm)
    if not mx then return nil end
    my = frm:GetHeight() - my
    if my < (map.TitleH or 0) then return nil end
    return map:FramePosToWorldPos(mx, my)
end

-- Tooltip text for the game's blip under the cursor, or nil.
function MiniMap:BlipTipAtCursor(map)
    if not tracking(map) then return nil end
    local notes = _G.Nx and _G.Nx.Notes
    if not (notes and notes.GatherLiteTipAt and map.GetCurrentMapId) then return nil end
    local wx, wy = self:CursorWorldPos(map)
    local scale = map.MapScale
    if not (wx and scale and scale > 0) then return nil end
    return notes:GatherLiteTipAt(map:GetCurrentMapId(), wx, wy, self.BLIP_RADIUS / 10.02 / scale)
end

local hover, blipAnchor

-- A tiny shown frame that owns the blip tooltip (the tooltip anchors
-- to the cursor; a hidden owner would hide it).
local function anchorFor(map)
    if not blipAnchor then
        local parent = _G.UIParent
        blipAnchor = _G.CreateFrame("Frame", nil, parent)
        blipAnchor:SetSize(1, 1)
        blipAnchor:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
        blipAnchor:Show()
    end
    blipAnchor.NxMap = map
    return blipAnchor
end

local function setHovered(map, target, tip)
    if hover.target == target and hover.tip == tip then return end
    if hover.target and map.IconOnLeave then map.IconOnLeave(hover.target) end
    hover.target, hover.tip = target, tip
    if tip then target.NxTip = tip end    -- after the old one left
    if target and map.IconOnEnter then map.IconOnEnter(target) end
end

function MiniMap:UpdateGatherHover()
    local map = legacyMap()
    if not (map and hover) then return end
    -- A missed OnLeave (docking, map closed) must not keep polling.
    local mm = map.MMFrm
    if map.MMZoomType == 0 or not (mm and mm:IsVisible() and mm:IsMouseOver()) then
        self:StopGatherHover(map)
        return
    end
    local icon = self:IconAtCursor(map)
    if icon then
        setHovered(map, icon)
        return
    end
    local tip = self:BlipTipAtCursor(map)
    if tip then
        setHovered(map, anchorFor(map), tip)
    else
        setHovered(map, nil)
    end
end

function MiniMap:StartGatherHover()
    hover = hover or (_G.CreateFrame and _G.CreateFrame("Frame"))
    if not hover then return end
    hover.wait = 0
    hover:SetScript("OnUpdate", function(_, elapsed)
        hover.wait = hover.wait - (elapsed or 0)
        if hover.wait > 0 then return end
        hover.wait = MiniMap.HOVER_INTERVAL
        MiniMap:UpdateGatherHover()
    end)
end

function MiniMap:StopGatherHover(map)
    if not hover then return end
    hover:SetScript("OnUpdate", nil)
    if map then setHovered(map, nil) end
    hover.target, hover.tip = nil, nil
end

function MiniMap:OnEnter(frame, motion)
    local map = legacyMap()
    if not map or map.MMZoomType == 0 then return end
    frame.NxMap = map
    if map.IconOnEnter then map.IconOnEnter(frame, motion) end
    self:StartGatherHover()
end

function MiniMap:OnLeave(frame, motion)
    local map = legacyMap()
    if not map or map.MMZoomType == 0 then return end
    self:StopGatherHover(map)
    frame.NxMap = map
    if map.IconOnLeave then map.IconOnLeave(frame, motion) end
end

-- ---------------------------------------------------------------
-- Button visibility (Carbonite minimap button, calendar, clock,
-- world map, LFG, nameplate). Each setting key is read from
-- Nx.db.profile.MiniMap so changing the value at runtime persists.
-- ---------------------------------------------------------------

local BUTTON_MAP = {
    { frameName = "MinimapCluster",          setting = "ShowOldNameplate" },
    { frameName = "NXMiniMapBut",            setting = "ButShowCarb" },
    { frameName = "GameTimeFrame",           setting = "ButShowCalendar" },
    { frameName = "TimeManagerClockButton",  setting = "ButShowClock" },
    { frameName = "MiniMapWorldMapButton",   setting = "ButShowWorldMap" },
    { frameName = "LFGMinimapFrame",         setting = "ButShowLFG" },
}

function MiniMap:Buttons() return BUTTON_MAP end

function MiniMap:ApplyButtonVisibility()
    local db = _G.Nx and _G.Nx.db and _G.Nx.db.profile and _G.Nx.db.profile.MiniMap
    if not db then return end
    -- With the LibDBIcon button standing in for the launcher
    -- (RegisterDBIcon), the launcher stays hidden and the option shows or
    -- hides the stand-in; showing both left a loose second button.
    local but = _G.Nx.NXMiniMapBut
    local dbIcon = but and but.DBIcon
    for _, entry in ipairs(BUTTON_MAP) do
        local f = _G[entry.frameName]
        if dbIcon and entry.frameName == "NXMiniMapBut" then
            if f and f.Hide then f:Hide() end
            if db[entry.setting] then
                dbIcon:Show("Carbonite")
            else
                dbIcon:Hide("Carbonite")
            end
        elseif f then
            if db[entry.setting] then
                if f.Show then f:Show() end
            else
                if f.Hide then f:Hide() end
            end
        end
    end
end

-- ---------------------------------------------------------------
-- Legacy rewire. Static (table-style) functions get bound to the
-- new class, and the colon-style methods on Nx.Map are reshaped to
-- delegate as well. We intentionally do not rewire MinimapUpdate /
-- MinimapDetachFrms / MinimapSetScale because they manipulate the
-- private docking state that still lives in NxMap.
-- ---------------------------------------------------------------

local function rewireLegacy()
    local NxMap = nxMap()
    if not NxMap then return end

    NxMap.Minimap_ZoomInClick  = function() MiniMap:ZoomIn()  end
    NxMap.Minimap_ZoomOutClick = function() MiniMap:ZoomOut() end
    NxMap.Minimap_OnEvent      = function() MiniMap:Zoom() end

    NxMap.MinimapZoom              = function(_, value)  MiniMap:Zoom(value) end
    NxMap.MinimapOnMouseDown       = function(frame, button) MiniMap:OnMouseDown(frame, button) end
    NxMap.MinimapOnMouseUp         = function(frame, button) MiniMap:OnMouseUp(frame, button) end
    NxMap.MinimapOnEnter           = function(frame, motion) MiniMap:OnEnter(frame, motion) end
    NxMap.MinimapOnLeave           = function(frame, motion) MiniMap:OnLeave(frame, motion) end
    NxMap.Ping                     = function(_) MiniMap:Ping() end
    NxMap.MinimapButtonShowUpdate  = function(_, justNameplate)
        if justNameplate then
            -- Old code path only refreshed the nameplate toggle. We
            -- still refresh everything because it's cheap and avoids
            -- divergence between the toggles.
        end
        MiniMap:ApplyButtonVisibility()
    end
end

Carbonite.Core.EventBus:Subscribe("CARBONITE_LOADED", rewireLegacy)
Carbonite.Core.EventBus:Subscribe("CARBONITE_ENABLE", rewireLegacy)
