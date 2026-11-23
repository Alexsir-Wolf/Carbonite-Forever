-- Carbonite | Modules / Map / IconStyle
-- Item icons on the map without the old square frame (#247). The Guide
-- draws its points (mailbox, inn, bank, trainers, gather nodes...) with
-- the game's item icons, which carry a bevelled frame. Each one is drawn
-- either as the current Blizzard atlas of its kind, when the client has
-- it, or as the same icon with the frame cropped off.
--
-- No round mask: item art fills the whole square, so a circle cut off the
-- tips of the drawing (tested in game, 2026-11-23).
--
-- Only item icons change: Interface\Icons\..., the copies under
-- Carbonite\Gfx\Icons\ and the flight master's wyvern. Quest icons, pins
-- and Carbonite's own graphics stay as they are. Map.ClassicIcons brings
-- the old look back. The icon pool resets the texture coordinates of a
-- reused frame (GetIconStatic), so nothing carries over to the next pin.
--
-- MapNotes mode: the player picked the icons of HandyNotes: MapNotes in the
-- setup assistant (Map.ShowPOI off, Notes.HandyNotes on, HandyNotes and
-- HandyNotes_MapNotes loaded). MapNotes then draws the trainers and town
-- services, and the Guide leaves those points off the map so nothing is
-- drawn twice (NxMapGuide.lua, UpdateMapIcons).
--
-- Public API:
--   IconStyle.Resolve(tex, classic, hasAtlas) -> "atlas", name | "crop" | nil  (pure)
--   IconStyle:Apply(tex, fTex)                style a texture just set to `tex`
--   IconStyle.MapNotesActive()                the MapNotes mode is on

local Carbonite = _G.Carbonite

local IconStyle = {}
Carbonite.Modules.Map.IconStyle = IconStyle

IconStyle.CROP = { .08, .92, .08, .92 }

-- Icon file (lower case, no extension) -> atlases to try, in order. Only
-- icons used by one kind of point: Trade_BlackSmithing is both the anvil
-- and the blacksmithing trainer, so it keeps its own art.
IconStyle.ATLAS = {
    inv_letter_15 = { "Mailbox" },
    spell_shadow_twilight = { "Innkeeper" },
    inv_misc_coin_02 = { "Banker" },
    racial_dwarf_findtreasure = { "Auctioneer" },
    ability_mount_wyvern_01 = { "TaxiNode_Neutral", "FlightMaster" },
    ability_hunter_beasttaming = { "StableMaster" },
}

-- The icon file name when `tex` is an item icon, else nil.
local function iconName(tex)
    if type(tex) ~= "string" then return nil end
    local low = tex:lower()
    local name = low:match("^interface\\icons\\([^\\]+)$")
        or low:match("\\gfx\\icons\\([^\\]+)$")
        or low:match("\\gfx\\(ability_mount_wyvern_01[^\\]*)$")
    if not name then return nil end
    return (name:gsub("%.%w+$", ""))
end
IconStyle.IconName = iconName

function IconStyle.Resolve(tex, classic, hasAtlas)
    if classic then return nil end
    local name = iconName(tex)
    if not name then return nil end
    for _, atlas in ipairs(IconStyle.ATLAS[name] or {}) do
        if hasAtlas(atlas) then return "atlas", atlas end
    end
    return "crop"
end

local atlasKnown = {}
local function hasAtlas(name)
    local known = atlasKnown[name]
    if known == nil then
        local C = _G.C_Texture
        known = (C and C.GetAtlasInfo and C.GetAtlasInfo(name)) and true or false
        atlasKnown[name] = known
    end
    return known
end

local function classic()
    local Nx = _G.Nx
    local map = Nx and Nx.db and Nx.db.profile and Nx.db.profile.Map
    return map ~= nil and map.ClassicIcons == true
end

-- tex -> { kind, atlas } or false; the classic option is checked apart so
-- toggling it needs no cache reset.
local cache = {}

function IconStyle:Apply(tex, fTex)
    if classic() then return end
    local entry = cache[tex]
    if entry == nil then
        local kind, atlas = IconStyle.Resolve(tex, false, hasAtlas)
        entry = kind and { kind, atlas } or false
        cache[tex] = entry
    end
    if not entry then return end
    if entry[1] == "atlas" then
        fTex:SetAtlas(entry[2])
    else
        local c = IconStyle.CROP
        fTex:SetTexCoord(c[1], c[2], c[3], c[4])
    end
end

local function addonLoaded(name)
    local C = _G.C_AddOns
    local loaded = (C and C.IsAddOnLoaded) or _G.IsAddOnLoaded
    return type(loaded) == "function" and loaded(name) and true or false
end

function IconStyle.MapNotesActive()
    local Nx = _G.Nx
    local map = Nx and Nx.db and Nx.db.profile and Nx.db.profile.Map
    if not map or map.ShowPOI ~= false then return false end
    local fdb = Nx.fdb
    local notes = fdb and fdb.profile and fdb.profile.Notes
    if notes and notes.HandyNotes == false then return false end
    return addonLoaded("HandyNotes") and addonLoaded("HandyNotes_MapNotes")
end

return IconStyle
