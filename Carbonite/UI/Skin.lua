-- Carbonite | UI / Skin
-- Centralized theming: every Carbonite window/button/frame reads its
-- visual style from here rather than hardcoding colors / textures.
-- Replaces Nx.Skin's hardcoded `Nx.Skins[name]` table with a class
-- that also exposes resolved colors and a `Set` / `Update` lifecycle.
--
-- Two ways to use:
--   - Modern: Skin:GetActive() returns the resolved theme; widgets
--     read backdrop/color fields directly.
--   - Legacy: Nx.Skin:* aliases below keep old call sites working.

local Carbonite = _G.Carbonite
local Skin = {}
Carbonite.UI.Skin = Skin

-- Shared backdrop default. Themes copy and override fields they care
-- about. Kept as a function so theme registration order doesn't matter.
local function backdrop(edgeFile, tile, tileSize, edgeSize, insets)
    return {
        bgFile   = "Interface\\Buttons\\White8x8",
        edgeFile = edgeFile,
        tile     = tile ~= false,
        tileSize = tileSize or 9,
        edgeSize = edgeSize or 9,
        insets   = insets or { left = 1, right = 1, top = 1, bottom = 1 },
    }
end

Skin.themes = {
    -- The game's own window look: the dialog border and dark rock background of
    -- Blizzard's frames, bronze separators and the gold highlight of its lists.
    -- The NineSlice frame of the character sheet was tried and does not fit
    -- Carbonite's windows (its title bar covers their first lines, and on the
    -- map its edges break into stray marks), so the border is a backdrop.
    ["Blizzard"] = {
        backdrop = {
            bgFile   = "Interface\\FrameGeneral\\UI-Background-Rock",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile     = true,
            tileSize = 256,
            edgeSize = 16,
            insets   = { left = 4, right = 4, top = 4, bottom = 4 },
        },
        borderColor = "1|1|1|1",
        bgColor     = "1|1|1|1",
        tokens = {
            hover       = "0.22|0.17|0.04|1",
            pressed     = "0.45|0.36|0.12|1",
            rowHover    = "1|0.82|0|0.12",
            listBg      = "0|0|0|0.35",
            tabBarBg    = "0|0|0|0.45",
            separator   = "0.45|0.36|0.20|1",
            scrollTrack = "0.08|0.07|0.05|0.85",
            scrollThumb = "0.60|0.48|0.24|1",
            listHeader  = "0.22|0.16|0.08|1",
            selection   = "0.55|0.42|0.05|0.45",
        },
    },
    ["Blackout"] = {
        backdrop = backdrop("Interface\\Addons\\Carbonite\\Gfx\\Skin\\EdgeSquare", true, 8, 8, { left=0, right=0, top=0, bottom=0 }),
        borderColor = "0|0|0|1",
        bgColor     = "0|0|0|1",
    },
    ["Blackout Blues"] = {
        backdrop = backdrop("Interface\\Tooltips\\UI-Tooltip-Border"),
        borderColor = ".8|.8|1|1",
        bgColor     = "0|0|0|1",
    },
    ["Dialog Blue"] = {
        backdrop = backdrop("Interface\\DialogFrame\\UI-DialogBox-Border", true, 16, 16, { left=2, right=2, top=2, bottom=2 }),
        borderColor = ".8|.8|1|1",
        bgColor     = ".125|.125|.125|.88",
    },
    ["Dialog Gold"] = {
        backdrop = backdrop("Interface\\DialogFrame\\UI-DialogBox-Gold-Border", true, 16, 16, { left=2, right=2, top=2, bottom=2 }),
        borderColor = "1|1|1|1",
        bgColor     = ".15|.15|0|.88",
    },
    ["Simple Blue"] = {
        backdrop = backdrop("Interface\\Addons\\Carbonite\\Gfx\\Skin\\EdgeSquare", true, 8, 8, { left=0, right=0, top=0, bottom=0 }),
        borderColor = "0.7|0.7|1|0.8",
        bgColor     = ".125|.125|.125|.88",
    },
    ["Stone"] = {
        backdrop = backdrop("Interface\\Glues\\Common\\TextPanel-Border", nil, 256, 16, { left=3, right=2, top=2, bottom=2 }),
        borderColor = "1|1|1|1",
        bgColor     = "0.06|0.06|0.06|.9",
    },
    ["Tool Blue"] = {
        backdrop = backdrop("Interface\\Tooltips\\UI-Tooltip-Border"),
        borderColor = ".8|1|1|.8",
        bgColor     = ".125|.125|.125|.88",
    },
    -- Modern themes use Blizzard's tooltip border (a clean thin edge
    -- that stays sharp at high UI scales) and a couple of live-state
    -- variants that resolve their border color from the player's
    -- class / faction at apply time.
    ["Modern Dark"] = {
        backdrop = backdrop("Interface\\Tooltips\\UI-Tooltip-Border"),
        borderColor = "0.30|0.36|0.46|0.95",
        bgColor     = "0.06|0.07|0.10|1",
    },
    ["Modern Light"] = {
        backdrop = backdrop("Interface\\Tooltips\\UI-Tooltip-Border"),
        borderColor = "0.50|0.55|0.65|0.95",
        bgColor     = "0.88|0.88|0.92|1",
        tokens = {
            hover       = "0.18|0.16|0.04|1",
            pressed     = "0.55|0.62|0.80|1",
            rowHover    = "0.20|0.30|0.60|0.18",
            listBg      = "1|1|1|0.25",
            tabBarBg    = "0.80|0.80|0.85|0.6",
            separator   = "0.60|0.60|0.65|1",
            scrollTrack = "0.70|0.72|0.80|0.6",
            scrollThumb = "0.35|0.42|0.65|0.9",
            listHeader  = "0.75|0.76|0.82|1",
            selection   = "0.25|0.30|0.50|0.35",
        },
    },
    ["Glass"] = {
        backdrop = backdrop("Interface\\Tooltips\\UI-Tooltip-Border"),
        borderColor = "1|1|1|0.40",
        bgColor     = "0|0|0|0.40",
    },
    ["Class Color"] = {
        backdrop = backdrop("Interface\\Tooltips\\UI-Tooltip-Border"),
        borderColor = "0.40|0.55|0.95|0.85",
        bgColor     = "0.06|0.07|0.10|1",
        resolveBorder = function()
            local _, class = UnitClass("player")
            local cc = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)
            local c = class and cc and cc[class]
            if c then return ("%f|%f|%f|0.90"):format(c.r, c.g, c.b) end
        end,
    },
    ["Faction"] = {
        backdrop = backdrop("Interface\\Tooltips\\UI-Tooltip-Border"),
        borderColor = "0.40|0.55|0.95|0.85",
        bgColor     = "0.06|0.07|0.10|1",
        resolveBorder = function()
            local f = UnitFactionGroup("player")
            if f == "Alliance" then return "0.18|0.45|0.95|0.90" end
            if f == "Horde"    then return "0.85|0.20|0.20|0.90" end
        end,
    },
}

Skin.activeName = "Blizzard"

-- Colors of the parts every window shares. A theme overrides the ones it
-- needs in its own `tokens`; the rest come from here (the dark look).
--   hover       mouse-over glow of a button (added on top, ADD blend)
--   pressed     button held down
--   rowHover    mouse-over band of a list row
--   listBg      list body
--   tabBarBg    tab bar strip
--   separator   tab bar border lines
--   scrollTrack scroll bar track
--   scrollThumb scroll bar thumb
--   listHeader  column header strip of a list
--   selection   selected list row (added on top, ADD blend)
Skin.tokens = {
    hover       = "0.06|0.06|0.25|1",
    pressed     = "0.188|0.188|0.5|1",
    rowHover    = "0.5|0.5|0.7|0.18",
    listBg      = "0|0|0|0.3",
    tabBarBg    = "0|0|0|0.5",
    separator   = "0.313|0.313|0.313|1",
    scrollTrack = "0.3|0.3|0.4|0.6",
    scrollThumb = "0.3|0.3|0.7|0.9",
    listHeader  = "0.2|0.2|0.3|1",
    selection   = "0.4|0.4|0.5|0.4",
}

-- Parse a "r|g|b|a" string the legacy save format uses.
local function parseColor(s)
    if type(s) ~= "string" then return 1, 1, 1, 1 end
    local r, g, b, a = s:match("([^|]+)|([^|]+)|([^|]+)|([^|]+)")
    return tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1, tonumber(a) or 1
end

function Skin:GetActive()
    return self.themes[self.activeName] or self.themes["Blizzard"]
end

function Skin:GetBackdrop()
    return self:GetActive().backdrop
end

-- The color the player picked in the options, saved in the profile. Picking a
-- theme writes its colors there (Skin:Set), so this is the theme's color
-- until the player changes it.
local function saved(key)
    local Nx = _G.Nx
    local skin = Nx and Nx.db and Nx.db.profile and Nx.db.profile.Skin
    return skin and skin[key]
end

function Skin:GetBorderColor()
    local t = self:GetActive()
    if type(t.resolveBorder) == "function" then
        local ok, val = pcall(t.resolveBorder)
        if ok and val then return { parseColor(val) } end
    end
    return { parseColor(saved("WinBdColor") or t.borderColor) }
end

function Skin:GetBackgroundColor()
    return { parseColor(saved("WinSizedBgColor") or self:GetActive().bgColor) }
end

function Skin:GetFixedBackgroundColor()
    return { parseColor(saved("WinFixedBgColor") or ".5|.5|.5|.5") }
end

--- r, g, b, a of a shared color (Skin.tokens) in the active theme.
function Skin:GetToken(name)
    local t = self:GetActive().tokens
    return parseColor(t and t[name] or self.tokens[name])
end

-- Textures painted with a token, repainted when the theme changes.
local painted = setmetatable({}, { __mode = "k" })

--- Color a texture with a token and keep it in step with the theme.
function Skin:Paint(texture, name)
    painted[texture] = name
    texture:SetColorTexture(self:GetToken(name))
end

-- Apply current theme's backdrop to a frame in one call.
function Skin:Apply(frame)
    if not frame or not frame.SetBackdrop then return end
    frame:SetBackdrop(self:GetActive().backdrop)
    local r, g, b, a = unpack(self:GetBorderColor())
    if frame.SetBackdropBorderColor then frame:SetBackdropBorderColor(r, g, b, a) end
    local br, bg, bb, ba = unpack(self:GetBackgroundColor())
    if frame.SetBackdropColor then frame:SetBackdropColor(br, bg, bb, ba) end
end

-- Translucent backgrounds the modern themes had before they turned opaque.
-- Picking a theme used to copy its colors into the profile, so a profile
-- still holding one of these never chose it: it goes back to the theme's.
local OLD_BACKGROUNDS = {
    ["0.06|0.07|0.10|0.92"] = true,
    ["0.88|0.88|0.92|0.92"] = true,
}

function Skin:Set(name, init)
    -- A profile that never picked a theme gets the game's own look.
    if not self.themes[name] then name = "Blizzard" end
    self.activeName = name
    local skin = _G.Nx and _G.Nx.db and _G.Nx.db.profile and _G.Nx.db.profile.Skin
    if skin then
        skin.Name = name
        if not init then
            -- A new theme brings its own colors; the pickers start from them.
            skin.WinBdColor, skin.WinFixedBgColor, skin.WinSizedBgColor = nil, nil, nil
        elseif OLD_BACKGROUNDS[skin.WinSizedBgColor] then
            skin.WinSizedBgColor = nil
        end
    end
    self:Update()
end

function Skin:Update()
    for texture, name in pairs(painted) do
        texture:SetColorTexture(self:GetToken(name))
    end
    Carbonite.Core.EventBus:Fire("SKIN_UPDATED", self.activeName)
    -- Push to legacy Window/Menu resets so existing widgets restyle.
    if _G.Nx and _G.Nx.Window and _G.Nx.Window.ResetBackdrops then _G.Nx.Window:ResetBackdrops() end
    if _G.Nx and _G.Nx.Menu   and _G.Nx.Menu.ResetSkins      then _G.Nx.Menu:ResetSkins()      end
end

function Skin:ListThemes()
    local out = {}
    for k in pairs(self.themes) do out[#out + 1] = k end
    table.sort(out)
    return out
end

-- Legacy aliases. Installed after the addon is loaded so that any
-- legacy code that already grabbed `Nx.Skin` gets the new methods.
Carbonite.Core.EventBus:Subscribe("CARBONITE_LOADED", function()
    if not _G.Nx then return end
    _G.Nx.Skin = _G.Nx.Skin or {}
    local target = _G.Nx.Skin
    target.Init                = function() if _G.Nx.db then Skin:Set(_G.Nx.db.profile.Skin.Name, true) end end
    target.Set                 = function(_, name, init) Skin:Set(name, init) end
    target.Update              = function() Skin:Update() end
    target.GetBackdrop         = function() return Skin:GetBackdrop() end
    target.GetBorderCol        = function() return Skin:GetBorderColor() end
    target.GetBGCol            = function() return Skin:GetBackgroundColor() end
    target.GetFixedSizeBGCol   = function() return Skin:GetFixedBackgroundColor() end
    target.GetNineSliceLayout  = function() return Skin:GetActive().nineSlice end
    target.GetTex              = function(_, name) return "Interface\\Addons\\Carbonite\\Gfx\\Skin\\" .. (name or "") end
    -- The legacy code reads Nx.Skins (the full table) and self.Data.
    _G.Nx.Skins = Skin.themes
    target.Data = Skin:GetActive()
    target.Path = "Interface\\Addons\\Carbonite\\Gfx\\Skin\\"
end)
