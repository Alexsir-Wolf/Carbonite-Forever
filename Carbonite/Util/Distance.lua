-- Carbonite | Util / Distance
-- One way to show a distance on every screen (#245): the HUD arrow, the map
-- cursor and target tips, the Guide, the destination list and the quest
-- watch. Distances are kept in yards everywhere; only the text changes.
--
-- Unit: Track.DistUnit = "auto" (the game language: pt-BR shows meters, the
-- others yards), "yd" or "m". One yard is shown as one meter, as the pt-BR
-- client does with spell ranges ("30 m"), so the arrow agrees with them.
-- Meters: "290 m" below 1000, then "1,3 km" (one decimal, with the decimal
-- comma of the game language).
--
-- Public API:
--   Distance.Unit(setting, locale)               -> "m" or "yd"
--   Distance.Format(yards, unit, locale, labels) -> text (pure, tested)
--   Distance:Text(yards)                         -> text with the saved option
--   Distance:UnitLabel()                         -> "m" or the yards label

local Carbonite = _G.Carbonite
local L = LibStub("AceLocale-3.0"):GetLocale("Carbonite")

local Distance = {}
Carbonite.Util.Distance = Distance

local floor = math.floor

-- Languages that write 1.3 rather than 1,3.
local DECIMAL_POINT = { enUS = true, enGB = true, koKR = true, zhCN = true, zhTW = true }

function Distance.Unit(setting, locale)
    if setting == "m" or setting == "yd" then return setting end
    return locale == "ptBR" and "m" or "yd"
end

--- `labels` = { yd = "yds", m = "m", km = "km" } (translated by the caller).
function Distance.Format(yards, unit, locale, labels)
    local n = floor((tonumber(yards) or 0) + .5)
    if n < 0 then n = 0 end
    if unit ~= "m" then
        return n .. " " .. labels.yd
    end
    if n < 1000 then
        return n .. " " .. labels.m
    end
    local km = string.format("%.1f", floor(n / 100 + .5) / 10)
    if not DECIMAL_POINT[locale] then km = km:gsub("%.", ",") end
    return km .. " " .. labels.km
end

local function setting()
    local Nx = _G.Nx
    local track = Nx and Nx.db and Nx.db.profile and Nx.db.profile.Track
    return track and track.DistUnit
end

local function locale()
    return _G.GetLocale and _G.GetLocale() or "enUS"
end

function Distance:Text(yards)
    local loc = locale()
    return Distance.Format(yards, Distance.Unit(setting(), loc), loc,
        { yd = L["yds"], m = L["m"], km = L["km"] })
end

function Distance:UnitLabel()
    return Distance.Unit(setting(), locale()) == "m" and L["m"] or L["yds"]
end

return Distance
