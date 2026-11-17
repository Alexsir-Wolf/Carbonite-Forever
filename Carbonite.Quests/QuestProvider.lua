-- Carbonite.Quests | QuestProvider
-- The Quest module's icon producer was historically the only major
-- icon source still using the legacy `map:GetIconStatic` pool-stamp
-- pipeline. That meant the whole 600-line UpdateIcons had to run
-- every frame to keep the pool slots filled — no caching, no early
-- exit, no way for a third party to plug in alongside.
--
-- This file defines a MapProvider for the Quest module so its icons
-- live on a persistent Pin/Layer like every other producer. MapIcons.lua
-- consumes it and gates the per-frame work behind a content-hash
-- dirty-check.
--
-- Three pin kinds:
--   POI        - quest start / end / objective POI icons. WP draw mode.
--                Uses an `onStamp` callback to apply per-icon vertex
--                colors, super-tracked glow visibility, and the
--                objective-number label (NxLabel) that the legacy
--                code wrote directly to the pool frame.
--   LivePOI    - Blizzard watched/tracked quest objective coordinates.
--                Kept above every database-derived quest pin so live
--                objectives remain visible on both Carbonite map sizes.
--   Area       - top-left-anchored quest-area rectangles with raw world
--                dimensions; these remain below the foreground POIs.

local Nx = _G.Nx
if not Nx then return end
Nx.Quest = Nx.Quest or {}

local Carbonite = _G.Carbonite
local unpack = _G.unpack or table.unpack

-- Lazy initialisation: the MapProvider module loads from
-- Carbonite/Modules/Map/MapProvider.lua via Modules.xml during the
-- main addon's loader. Carbonite.Quests is a sibling addon and may
-- load before MapProvider is available, so defer creation until the
-- first read.
local _provider
local function provider()
    if _provider then return _provider end
    if not (Carbonite and Carbonite.Map and Carbonite.Map.CreateProvider) then
        return nil
    end
    local p = Carbonite.Map:CreateProvider("Carbonite.Quests")

    -- Stamping callback shared by the quest pin kinds. Quest icons want full
    -- per-pin control of vertex color, glow, and objective label —
    -- legacy code set these directly on the pool frame after
    -- GetIconStatic. With pin/layer we run the same logic after the
    -- renderer's standard texture stamping via the onStamp hook.
    local function stampQuestFrame(pin, frame)
        local fTex = frame.texture
        if pin.vertexColor then
            local c = pin.vertexColor
            fTex:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
        else
            fTex:SetVertexColor(1, 1, 1, 1)
        end

        -- Retail's POIButton is a composite: the outer quest-number ring is
        -- one atlas and the in-progress/complete/waypoint glyph is a second
        -- texture. Legacy Blizzard providers use the same two-layer shape
        -- with UI-QuestPoi-NumberIcons. Carbonite cannot reparent Blizzard's
        -- MapCanvas pin, so reproduce those two texture layers on the pooled
        -- Carbonite frame while retaining Blizzard's public data source.
        local display = frame.NxQuestDisplay
        if (pin.displayAtlas or pin.displayTex) and not display
            and type(frame.CreateTexture) == "function" then
            display = frame:CreateTexture(nil, "OVERLAY", nil, 1)
            frame.NxQuestDisplay = display
            if display.SetPoint then display:SetPoint("CENTER") end
            if display.SetSnapToPixelGrid then
                display:SetSnapToPixelGrid(false)
            end
            if display.SetTexelSnappingBias then
                display:SetTexelSnappingBias(0)
            end
        end
        if display then
            display:Hide()
            local hasDisplay = false
            if pin.displayAtlas and type(display.SetAtlas) == "function" then
                display:SetTexCoord(0, 1, 0, 1)
                display:SetAtlas(pin.displayAtlas)
                hasDisplay = true
            elseif pin.displayTex and type(display.SetTexture) == "function" then
                display:SetTexture(pin.displayTex)
                if pin.displayTexCoord then
                    display:SetTexCoord(unpack(pin.displayTexCoord))
                else
                    display:SetTexCoord(0, 1, 0, 1)
                end
                hasDisplay = true
            end
            if hasDisplay then
                if pin.displayWidth and pin.displayHeight
                    and type(display.SetSize) == "function" then
                    display:SetSize(pin.displayWidth, pin.displayHeight)
                end
                display:Show()
            end
        end

        local glow = frame.NxGlow
        if glow then
            if pin.showGlow then glow:Show() else glow:Hide() end
        end
        local lbl = frame.NxLabel
        if lbl then
            if pin.label and pin.label ~= "" then
                lbl:SetText(pin.label)
                lbl:Show()
            else
                lbl:Hide()
            end
        end
    end

    -- Quest POIs use the same fixed navigation size as the legacy
    -- GetIconStatic path. Generic WP scaling shrinks them to about one
    -- pixel on a normally zoomed minimap. Frame level 4 keeps the marker
    -- and its objective number above the translucent quest-area layer.
    p:DefinePin("POI", {
        drawMode  = "WP",
        scaleMode = "navigation",
        frameLvl  = 4,
        w         = 16,
        h         = 16,
        onStamp   = stampQuestFrame,
    })

    -- The native Blizzard minimap draws quest POIs inside the Minimap render
    -- object, so those icons cannot be reparented into Carbonite. LivePOI is
    -- Carbonite's explicit mirror of that data. Its larger foreground level
    -- prevents quest blobs and database-area pins from covering it.
    p:DefinePin("LivePOI", {
        drawMode  = "WP",
        scaleMode = "navigation",
        frameLvl  = 6,
        w         = 24,
        h         = 24,
        onStamp   = stampQuestFrame,
    })

    -- Quest-objective area spans (the colored rectangles laid over
    -- the search area). These differ from POI pins in three ways:
    --   * top-left anchored (clipKind = "tl") rather than centered,
    --   * the renderer reads pin.w / pin.h per-pin (the rect's
    --     extent in world units),
    --   * rawSize tells the renderer to pass pin.w / pin.h raw to
    --     the clip function and to skip the center-anchored cull
    --     (the rect's extent isn't bounded by class defaults).
    p:DefinePin("Area", {
        drawMode = "WP",
        clipKind = "tl",
        rawSize  = true,
        frameLvl = 0,
        onStamp  = stampQuestFrame,
    })

    _provider = p
    return p
end

-- Public accessors used by MapIcons.lua.
function Nx.Quest:GetMapProvider()
    return provider()
end

-- Convenience wrapper so call sites can read like the legacy
-- "stamp this icon" code without sprouting nil-checks.
local function IsQuestPinRelevant(opts)
    local mapID = opts and opts.mapID
    local map = Nx.Map
    if map and map.IsMapRelevantToInstance then
        return map:IsMapRelevantToInstance(
            mapID,
            map.UpdateMapID or map.RMapId or map.MapId
        )
    end
    return true
end

function Nx.Quest:AddPOI(wx, wy, opts)
    if not IsQuestPinRelevant(opts) then return nil end
    local p = provider()
    if not p then return nil end
    return p:Add("POI", wx, wy, opts)
end

function Nx.Quest:AddLivePOI(wx, wy, opts)
    if not IsQuestPinRelevant(opts) then return nil end
    local p = provider()
    if not p then return nil end
    return p:Add("LivePOI", wx, wy, opts)
end

function Nx.Quest:AddArea(wx, wy, opts)
    if not IsQuestPinRelevant(opts) then return nil end
    local p = provider()
    if not p then return nil end
    return p:Add("Area", wx, wy, opts)
end

function Nx.Quest:ClearProviderPins()
    local p = provider()
    if p then p:Clear() end
end

-- ---------------------------------------------------------------
-- Quest map icon look (#49)
-- ---------------------------------------------------------------
-- The bundled Gfx\Map icons date from the original Carbonite. The modern
-- client ships the same symbols as atlases (the ones its own world map
-- and minimap use), so quest POIs and quest givers read like the rest of
-- the UI. Each kind lists atlas candidates in order of preference; the
-- first one the client knows wins, and a client without any of them (or
-- without C_Texture) keeps the legacy texture, exactly like
-- Nx.Quest.SetParchment does for the details background.

local GFX = "Interface\\AddOns\\Carbonite\\Gfx\\Map\\"

local MAP_ICON_LEGACY = {
    available        = GFX .. "IconExclaim",
    daily            = GFX .. "IconExclaimB",
    turnin           = GFX .. "IconQuestion",
    repeatableTurnin = GFX .. "IconQuestion",
    inProgress       = GFX .. "IconQuestion",
    objective        = GFX .. "IconQTarget",
}

local MAP_ICON_ATLASES = {
    available        = { "QuestNormal" },
    daily            = { "QuestDaily", "quest-recurring-available" },
    turnin           = { "QuestTurnin" },
    repeatableTurnin = { "QuestRepeatableTurnin", "quest-recurring-turnin" },
    inProgress       = { "Quest-In-Progress-Icon" },
    objective        = { "QuestObjective", "QuestBonusObjective" },
}
Nx.Quest.MapIconAtlases = MAP_ICON_ATLASES

-- Atlas availability never changes during a session, so each name is
-- looked up once (the guide asks for every quest giver on the map).
local atlasKnown = {}

local function HasAtlas(name)
    local known = atlasKnown[name]
    if known == nil then
        local info = _G.C_Texture and _G.C_Texture.GetAtlasInfo
        known = (type(info) == "function" and info(name)) and true or false
        atlasKnown[name] = known
    end
    return known
end

local function QuestProfile()
    local qdb = Nx.qdb
    return qdb and qdb.profile and qdb.profile.Quest
end

function Nx.Quest.UseBlizzardMapIcons()
    local prof = QuestProfile()
    return not prof or prof.MapBlizzardIcons ~= false
end

function Nx.Quest.GetMapIconScale()
    local prof = QuestProfile()
    local s = prof and tonumber(prof.MapQuestIconScale)
    if not s or s <= 0 then return 1 end
    return s
end

-- Returns the texture string for a quest icon kind ("atlas:<name>" when
-- the client has a matching atlas) and whether it is an atlas.
function Nx.Quest.GetMapIconTexture(kind)
    local legacy = MAP_ICON_LEGACY[kind] or MAP_ICON_LEGACY.available
    if Nx.Quest.UseBlizzardMapIcons() then
        local list = MAP_ICON_ATLASES[kind]
        if list then
            for i = 1, #list do
                if HasAtlas(list[i]) then
                    return "atlas:" .. list[i], true
                end
            end
        end
    end
    return legacy, false
end

local function IsRepeatable(cur, questID)
    local freq = cur and cur.Daily
    if freq and freq ~= 0 then return true end
    return questID and Nx.QuestFreq and Nx.QuestFreq[questID] and true or false
end

-- Kind of the start / end marker of a quest. Quests outside the log
-- show where they are picked up; quests in the log show where they are
-- turned in, as "ready" only once every objective is done (`complete`
-- overrides cur.Complete, e.g. with the party-merged state).
function Nx.Quest.GetStartIconKind(questID)
    return IsRepeatable(nil, questID) and "daily" or "available"
end

function Nx.Quest.GetEndIconKind(cur, questID, complete)
    if complete == nil and cur then
        complete = cur.Complete == 1 or cur.Complete == true
    end
    if cur and not complete then
        return "inProgress"
    end
    return IsRepeatable(cur, questID) and "repeatableTurnin" or "turnin"
end

-- Fills the texture and size of a quest POI. Atlases are drawn in their
-- own colors, so the per-quest tint meant for the white legacy icons is
-- dropped (the glow still marks the super-tracked quest).
function Nx.Quest.StyleMapIcon(kind, opts)
    local tex, isAtlas = Nx.Quest.GetMapIconTexture(kind)
    opts.tex = tex
    if isAtlas then opts.vertexColor = nil end
    local size = 16 * Nx.Quest.GetMapIconScale()
    opts.w, opts.h = size, size
    return opts
end

-- Options changed: rebuild the quest POIs and the guide's quest givers.
function Nx.Quest:RefreshMapQuestIcons()
    self._iconDirty = true
    local guide = Nx.Map and Nx.Map.Guide
    if guide and guide.UpdateMapIcons then
        guide:UpdateMapIcons()
    end
end
