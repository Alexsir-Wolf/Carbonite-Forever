-- Carbonite | Modules / Map
-- Module entry for the Carbonite map. The heavy rendering code still
-- lives in the legacy NxMap.lua and is reachable through `Carbonite.Map`;
-- this file owns module lifecycle, layer registry and
-- the public Pin/Layer API new code should use.
--
-- Public API exposed on `Carbonite:GetModule("Map")`:
--   Map:GetLayer(name)        - returns or creates a named layer
--   Map:AddPin(layerName, kind, opts) - adds a pin and returns it
--   Map:Open()                - opens the Carbonite map window
--   Map:Close()
--   Map:Refresh()             - notifies all layers to re-render
--   Map:GetPlayerMapID()      - convenience accessor
--   Map:OnZoneChanged(fn)     - subscribe to player-zone changes

local Carbonite = _G.Carbonite
local Module = Carbonite.Core.Module
local Pin = Carbonite.Modules.Map.Pin
local Layer = Carbonite.Modules.Map.Layer
local MapApi = Carbonite.Compat.MapApi

local Map = Module:New("Map", {
    defaults = {
        profile = {
            Map = {
                ShowQuests       = true,
            },
        },
    },
})

function Map:GetLayer(name)
    return Layer.Get(name)
end

function Map:RemoveLayer(name)
    Layer.Remove(name)
end

function Map:Layers()
    return Layer.All()
end

function Map:AddPin(layerName, kind, opts)
    local layer = Layer.Get(layerName)
    local pin = Pin.Acquire(kind, opts)
    layer:Add(pin)
    return pin
end

-- Adds a line segment to the layer's pin list. The line connects
-- two world-space points with optional color/thickness. Lines are
-- drawn each frame by Renderer.lua's LINE drawMode path.
--   layerName  the layer to put the line into (usually mirrors kind)
--   kind       the Pin class (must have drawMode = "LINE")
--   opts       table { x, y, x2, y2, mapID, color, thickness, tex }
function Map:AddLine(layerName, kind, opts)
    local layer = Layer.Get(layerName)
    local pin = Pin.Acquire(kind)
    pin.x       = opts.x
    pin.y       = opts.y
    pin.x2      = opts.x2
    pin.y2      = opts.y2
    pin.mapID   = opts.mapID
    pin.color   = opts.color
    pin.thickness = opts.thickness
    pin.tex     = opts.tex
    pin.show    = true
    layer:Add(pin)
    return pin
end

function Map:GetPlayerMapID()
    return MapApi:GetPlayerMapID()
end

-- Main legacy map (window + art frame), once the engine has created it.
local function mainMap()
    local legacy = Carbonite.Map
    if not (legacy and legacy.Created and legacy.GetMap) then return end
    local m = legacy:GetMap(1)
    if m and m.Win and m.Frm then return m end
end

local function isOpen(m)
    return m.Win:IsShown() and m.Frm:IsShown() and true or false
end

function Map:Open()
    local legacy = Carbonite.Map
    -- Legacy Open only creates once; afterwards it toggles the art frame
    -- inside a visible window, leaving it gray (#197).
    if legacy and not legacy.Created and legacy.Open then legacy:Open() end
    local m = mainMap()
    if m then
        if not m.Frm:IsShown() then m.Frm:Show() end
        if not m.Win:IsShown() then m.Win:Show() end
    end
    Carbonite.Core.EventBus:Fire("MAP_OPENED")
end

function Map:Close()
    local m = mainMap()
    if m and m.Win:IsShown() then
        -- Leave max size first so a later show is not stuck maximized
        if m.Win:IsSizeMax() then m:RestoreSize() end
        m.Win:Show(false)
    end
    Carbonite.Core.EventBus:Fire("MAP_CLOSED")
end

function Map:Toggle()
    local m = mainMap()
    if m and isOpen(m) then self:Close() else self:Open() end
end

function Map:Refresh()
    for _, layer in pairs(Layer.All()) do layer.version = layer.version + 1 end
    Carbonite.Core.EventBus:Fire("MAP_REFRESH")
end

-- Path planning shortcuts. Callers should prefer these over reaching
-- into Carbonite.Modules.Map.Pathing directly.
function Map:PlanRoute(points, opts)
    return Carbonite.Modules.Map.Pathing:PlanRoute(points, opts)
end

function Map:BuildPath(tracking, srcMapID, srcX, srcY, dstMapID, dstX, dstY, dstType)
    return Carbonite.Modules.Map.Pathing:BuildPath(tracking,
        srcMapID, srcX, srcY, dstMapID, dstX, dstY, dstType)
end

function Map:OnEnable()
    -- Watch zone changes and broadcast through the EventBus so other
    -- modules can react without independent ZONE_CHANGED listeners.
    self:RegisterEvent("ZONE_CHANGED",            "OnZoneChange")
    self:RegisterEvent("ZONE_CHANGED_INDOORS",    "OnZoneChange")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA",   "OnZoneChange")

    Carbonite.Core.SlashCommands:Register("map", function(rest)
        rest = rest:lower()
        if rest == "show" then self:Open()
        elseif rest == "hide" then self:Close()
        else self:Toggle() end
    end, "show / hide / toggle the Carbonite map")
end

function Map:OnZoneChange()
    Carbonite.Core.EventBus:Fire("MAP_ZONE_CHANGED", MapApi:GetPlayerMapID())
end
