-- Carbonite | Modules / Map / MapToolBar
-- The icon strip at the top of the Carbonite map. The legacy
-- Nx.Map:CreateToolBar / UpdateToolBar built it directly via the
-- old Nx.ToolBar widget; this class owns the registry of buttons
-- so plugins can add their own entries without touching Nx.BarData.
--
-- Public API:
--   MapToolBar:RegisterButton(spec)   - { id, label, handler, pressed,
--                                          icon, order, group, enabled }
--   MapToolBar:UnregisterButton(id)
--   MapToolBar:Each(fn)               - iterate in stable order
--   MapToolBar:Refresh()              - tell the live toolbar to rebuild
--   MapToolBar:SetVisible(bool)       - mirror of Nx.db.profile.Map.ShowToolBar
--   MapToolBar:IsVisible()
--   MapToolBar:RegisterDefaults(silent) - the built-in buttons (DEFAULTS), once
--
-- DEFAULTS is the only definition of the built-in buttons (#248): the
-- map used to carry its own copy, without the 3D toggle.
--
-- The actual UI build still happens through the legacy
-- Nx.Map:CreateToolBar pipeline because the buttons are
-- Nx.Button-typed (TypeData lookup). Our registry is mirrored
-- into Nx.BarData so the legacy creator picks up plugin entries.

local Carbonite = _G.Carbonite

local MapToolBar = {}
Carbonite.Modules.Map.MapToolBar = MapToolBar

local registry = {}            -- id -> spec
local order    = {}            -- ordered list of ids

local function syncToLegacy(silent)
    if not _G.Nx then return end
    local bar = {}
    local inBar = {}
    for _, id in ipairs(order) do
        local s = registry[id]
        local typeId = s.buttonType or id
        bar[#bar + 1] = { typeId, s.label, s.handler, s.pressed or false }
        inBar[typeId] = true
    end
    -- Keep what others put straight into Nx.BarData (AddonButtons adopts
    -- minimap buttons that way); rebuilding from the registry alone
    -- dropped them (#248).
    for _, b in ipairs(_G.Nx.BarData or {}) do
        if not inBar[b[1]] and not registry[b[1]] then
            bar[#bar + 1] = b
        end
    end
    _G.Nx.BarData = bar
    if silent then return end
    -- If the toolbar exists already, prompt a rebuild.
    local mapInst = _G.Nx.Map and _G.Nx.Map.Maps and _G.Nx.Map.Maps[1]
    if mapInst and mapInst.UpdateToolBar then mapInst:UpdateToolBar() end
end

local function insert(spec)
    if not registry[spec.id] then table.insert(order, spec.id) end
    registry[spec.id] = spec
    table.sort(order, function(a, b)
        return (registry[a].order or 100) < (registry[b].order or 100)
    end)
end

function MapToolBar:RegisterButton(spec)
    if not spec or not spec.id then return end
    insert(spec)
    syncToLegacy()
end

function MapToolBar:UnregisterButton(id)
    if not registry[id] then return end
    registry[id] = nil
    for i, v in ipairs(order) do
        if v == id then table.remove(order, i); break end
    end
    syncToLegacy()
end

function MapToolBar:Each(fn)
    for _, id in ipairs(order) do fn(id, registry[id]) end
end

function MapToolBar:Refresh() syncToLegacy() end

function MapToolBar:SetVisible(on)
    local Nx = _G.Nx
    if not Nx or not Nx.db or not Nx.db.profile or not Nx.db.profile.Map then return end
    Nx.db.profile.Map.ShowToolBar = on and true or false
    local mapInst = Nx.Map and Nx.Map.Maps and Nx.Map.Maps[1]
    if mapInst and mapInst.UpdateToolBar then mapInst:UpdateToolBar() end
end

function MapToolBar:IsVisible()
    local Nx = _G.Nx
    return Nx and Nx.db and Nx.db.profile and Nx.db.profile.Map
       and Nx.db.profile.Map.ShowToolBar == true or false
end

-- The built-in buttons: id, label (locale key), Nx.Map handler, order.
-- The handlers stay on Nx.Map because they touch instance state.
MapToolBar.DEFAULTS = {
    { "Map3D",     "3D View",  "OnButToggle3D",     5 },
    { "MapZIn",    "Zoom In",  "OnButZoomIn",       10 },
    { "MapZOut",   "Zoom Out", "OnButZoomOut",      20 },
    { "MapGuide",  "Guide",    "OnButToggleGuide",  30 },
    { "MapCombat", "Combat",   "OnButToggleCombat", 40 },
    { "MapEvents", "Events",   "OnButToggleEvent",  50 },
}

-- Register the built-in buttons (once). `silent` skips the rebuild of a
-- live toolbar: the map calls this while it is creating its own.
function MapToolBar:RegisterDefaults(silent)
    local NxMap = _G.Nx and _G.Nx.Map
    if not NxMap then return end
    local L = Carbonite.L and Carbonite:L() or {}
    for _, d in ipairs(MapToolBar.DEFAULTS) do
        if not registry[d[1]] then
            insert({ id = d[1], label = L[d[2]] or d[2], handler = NxMap[d[3]], order = d[4] })
        end
    end
    syncToLegacy(silent)
end

Carbonite.Core.EventBus:Subscribe("CARBONITE_LOADED", function()
    MapToolBar:RegisterDefaults()
end)
