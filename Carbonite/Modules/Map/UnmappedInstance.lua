-- Carbonite | Modules / Map / UnmappedInstance
-- Map window for instances that the client gives no UI map.
--
-- Classic Era based clients (Forever) report no player position inside
-- dungeons: UnitPosition, GetBestMapForUnit and GetPlayerMapPosition all
-- return nil, so only Blizzard's live minimap can show where the player is.
-- MapEngine then shows that minimap full-size and centered
-- (Nx.Map:IsUnmappedInstance). This module completes the window:
--
-- * A black cover over the rest of the map area. The suppressed outdoor
--   map still sits at the dungeon entrance, and its icons (city NPCs,
--   POIs) would otherwise show around the minimap.
-- * The window title names the instance instead of the fallback world map.
-- * With the window maximized (M), DungeonChart.lua's dungeon map opens by
--   itself when there is one (#103), and DungeonGuide.lua's panel with the
--   boss route takes the right side. The docked window keeps the live
--   minimap alone.
-- * The dungeon map replaces the black cover: same strata as the map, level
--   above the outdoor icons. The live minimap, one strata above, then goes
--   small to the bottom left corner, still showing the player's position.
-- * The live minimap sits one strata above the map window, so it is kept
--   out of the toolbar band at the bottom; otherwise it covers the buttons.
-- * The tracking arrow (HUD) hides: the player has no position here, and the
--   distance to an outdoor destination is measured from the entrance.
-- * Carbonite's minimap button hides: it rides the minimap's rim, which now
--   sits inside the map window. It comes back on leaving, if enabled.
--
-- Public (on Nx.Map):
--   map:UpdateUnmappedInstanceView()    show/hide; sets map.UInstViewActive,
--                                       map.UInstChartFrm, map.UInstPanelW
--   map:RaiseUnmappedInstanceView(lvl)  put the cover (or dungeon map) and the
--                                       guide panel above this frame's outdoor
--                                       icons; returns the next level
--   map:GetUnmappedInstanceTitle()      window title, or nil
--   map:GetUnmappedInstanceMinimapBox() size, x, y of the live minimap
--   map:IsWindowMaximized()             the map window is maximized

local Nx = _G.Nx
local Map = Nx.Map

-- Live minimap in a corner of the dungeon map: part of the area, clamped.
local CORNER_PART, CORNER_MIN, CORNER_MAX, CORNER_GAP = .3, 110, 200, 8

local function LayoutCover(map, x, y, w, h)
    local cover = map.UInstCoverFrm
    if not cover then
        cover = CreateFrame("Frame", nil, map.Frm)
        cover:EnableMouse(false)
        local bg = cover:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(cover)
        bg:SetColorTexture(0, 0, 0, 1)
        map.UInstCoverFrm = cover
    end
    cover:ClearAllPoints()
    cover:SetPoint("TOPLEFT", map.Frm, "TOPLEFT", x, -y)
    cover:SetSize(w, h)
    if not cover:IsShown() then cover:Show() end
end

-- Height of the toolbar band at the bottom of the map area.
local function Band(map)
    local bar = map.ToolBar and map.ToolBar.Frm
    if bar and bar:IsShown() then
        return (tonumber(bar:GetHeight()) or 0) + 2
    end
    return 0
end

function Map:IsWindowMaximized()
    local win = self.Win
    return win and win.IsSizeMax and win:IsSizeMax() and true or false
end

function Map:UpdateUnmappedInstanceView()
    local w, h = self.MapW or 0, self.MapH or 0
    local active = w > 0 and h > 0 and self:IsUnmappedInstance()

    local DC = Nx.DungeonChart
    local chart = active and DC and DC.IsActive and DC:IsActive() and DC.Frame or nil
    self.UInstChartFrm = chart

    local DG = Nx.DungeonGuide
    local panelW = 0
    if active and DG and self:IsWindowMaximized() then
        panelW = tonumber(DG:PanelWidth(w)) or 0
    end
    self.UInstPanelW = panelW
    if DG then
        DG:UpdatePanel(self, panelW, math.max(h - Band(self), 0))
    end

    local cover = self.UInstCoverFrm
    if not active or chart then
        -- The chart already covers the window.
        if cover and cover:IsShown() then cover:Hide() end
    else
        LayoutCover(self, self.PadX or 0, self.TitleH or 0, w - panelW, h)
    end

    -- Blizzard redraws a resized minimap only on a zoom change.
    local size = active and self:GetUnmappedInstanceMinimapBox() or nil
    if size ~= self.UInstBoxSize then
        self.UInstBoxSize = size
        if active then self.MMZoomChanged = true end
    end

    active = active and true or false
    local but = _G.NXMiniMapBut
    if but and active ~= (self.UInstViewActive or false) then
        if active then
            but:Hide()
        elseif Nx.db.profile.MiniMap.ButShowCarb then
            but:Show()
        end
    end
    self.UInstViewActive = active
    return self.UInstViewActive
end

-- Called by MapEngine after every icon and label of the frame was drawn,
-- with a level above all of them. Returns the next free level.
function Map:RaiseUnmappedInstanceView(level)
    if not self.UInstViewActive then
        return level
    end
    local top = level
    local chart, cover = self.UInstChartFrm, self.UInstCoverFrm
    if chart and chart:IsShown() then
        if chart:GetFrameLevel() ~= level then
            chart:SetFrameLevel(level)
            if chart.Bar then chart.Bar:SetFrameLevel(level + 50) end
        end
        top = level + 55
    elseif cover and cover:IsShown() then
        cover:SetFrameLevel(level)
        top = level + 1
    end
    local panel = Nx.DungeonGuide and Nx.DungeonGuide.Panel
    if panel and panel:IsShown() then
        if panel:GetFrameLevel() ~= top then panel:SetFrameLevel(top) end
        top = top + 1
    end
    return top
end

-- Square box for the live minimap, offsets from the map area's top left
-- corner. Alone: as large as the area left of the guide panel allows,
-- centered, above the toolbar band. Over a dungeon map: small, bottom left.
function Map:GetUnmappedInstanceMinimapBox()
    local w = math.max((self.MapW or 0) - (self.UInstPanelW or 0), 0)
    local availH = math.max((self.MapH or 0) - Band(self), 0)
    if self.UInstChartFrm then
        local size = math.floor(math.min(w, availH) * CORNER_PART)
        size = math.max(math.min(size, CORNER_MAX), math.min(CORNER_MIN, w, availH))
        return size, CORNER_GAP, math.max(availH - size - CORNER_GAP, 0)
    end
    local size = math.max(math.min(w, availH), 0)
    return size, (w - size) / 2, (availH - size) / 2
end

function Map:GetUnmappedInstanceTitle()
    if not self:IsUnmappedInstance() or not GetInstanceInfo then return nil end
    local ok, name = pcall(GetInstanceInfo)
    if ok and type(name) == "string" and name ~= "" then return name end
    return nil
end
