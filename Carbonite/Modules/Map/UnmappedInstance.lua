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
-- * DungeonChart.lua's dungeon map does not open by itself here; opened
--   from the map menu, it is raised above the live minimap.
-- * The live minimap sits one strata above the map window, so it is kept
--   out of the toolbar band at the bottom; otherwise it covers the buttons.
-- * The tracking arrow (HUD) hides: the player has no position here, and the
--   distance to an outdoor destination is measured from the entrance.
-- * Carbonite's minimap button hides: it rides the minimap's rim, which now
--   sits inside the map window. It comes back on leaving, if enabled.
--
-- Public (on Nx.Map):
--   map:UpdateUnmappedInstanceView()    show/hide; sets map.UInstViewActive
--   map:RaiseUnmappedInstanceView(lvl)  put the cover above this frame's
--                                       outdoor icons; returns the next level
--   map:GetUnmappedInstanceTitle()      window title, or nil
--   map:GetUnmappedInstanceMinimapBox() size, x, y of the live minimap

local Nx = _G.Nx
local Map = Nx.Map

local STRATA = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG",
    "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP" }

-- The strata just above the live minimap.
local function StrataAbove(strata)
    for i, name in ipairs(STRATA) do
        if name == strata then return STRATA[math.min(i + 1, #STRATA)] end
    end
    return "HIGH"
end

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

-- DungeonChart covers the whole map window; in this view the live minimap
-- sits one strata above the map, so the chart goes one strata above that.
local function SyncChartStrata(map, chart)
    if chart then
        local mm = map.MMFrm
        local strata = StrataAbove(mm and mm.GetFrameStrata and mm:GetFrameStrata() or "MEDIUM")
        if map.UInstChartStrata ~= strata then
            map.UInstChartStrata = strata
            map.UInstChartFrm = chart
            chart:SetFrameStrata(strata)
        end
    elseif map.UInstChartFrm then
        map.UInstChartFrm:SetFrameStrata(map.Frm:GetFrameStrata())
        map.UInstChartFrm, map.UInstChartStrata = nil, nil
    end
end

function Map:UpdateUnmappedInstanceView()
    local w, h = self.MapW or 0, self.MapH or 0
    local active = w > 0 and h > 0 and self:IsUnmappedInstance()

    local DC = Nx.DungeonChart
    local chart = active and DC and DC.IsActive and DC:IsActive() and DC.Frame or nil
    SyncChartStrata(self, chart)

    local cover = self.UInstCoverFrm
    if not active or chart then
        -- The chart already covers the window.
        if cover and cover:IsShown() then cover:Hide() end
    else
        LayoutCover(self, self.PadX or 0, self.TitleH or 0, w, h)
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
    local cover = self.UInstCoverFrm
    if not self.UInstViewActive or not cover or not cover:IsShown() then
        return level
    end
    cover:SetFrameLevel(level)
    return level + 1
end

-- Square box for the live minimap: as large as the map area allows, centered,
-- above the toolbar band. Offsets are from the map area's top left corner.
function Map:GetUnmappedInstanceMinimapBox()
    local w, h = self.MapW or 0, self.MapH or 0
    local band = 0
    local bar = self.ToolBar and self.ToolBar.Frm
    if bar and bar:IsShown() then
        band = (bar:GetHeight() or 0) + 2
    end
    local availH = math.max(h - band, 0)
    local size = math.max(math.min(w, availH), 0)
    return size, (w - size) / 2, (availH - size) / 2
end

function Map:GetUnmappedInstanceTitle()
    if not self:IsUnmappedInstance() or not GetInstanceInfo then return nil end
    local ok, name = pcall(GetInstanceInfo)
    if ok and type(name) == "string" and name ~= "" then return name end
    return nil
end
