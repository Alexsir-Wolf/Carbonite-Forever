-- Carbonite | Modules / Map / GuardRoute
-- Directions asked to a city guard become a Carbonite target with the arrow
-- and the route. The game fires DYNAMIC_GOSSIP_POI_UPDATED when the guard
-- answers, but this client gives no position for it (GetPoiForUiMapID is nil
-- on every map), so the spot comes from the Guide: the option the player
-- chose in the talk ("Cooking", "Banker"...) names a Guide type, and the
-- nearest NPC of that type on the player's map is the target.
--
--   GR:Remember(options)  options of the talk on screen (GOSSIP_SHOW)
--   GR:Chosen(optionID)   the option the player picked (SelectOption hook)
--   GR:GuideKey(text)     Guide type named by an option text, or nil
--   GR:Target(map)        target the Guide NPC of the last choice; true if set

local Nx = _G.Nx
local GR = {}
_G.Carbonite.Modules.Map.GuardRoute = GR

local options = {}
GR.Choice = nil

-- Lower case, no color codes, no spaces at the ends.
local function plain(s)
    s = tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return (s:lower():gsub("^%s+", ""):gsub("%s+$", ""))
end

function GR:Remember(list)
    options = type(list) == "table" and list or {}
end

function GR:Chosen(optionID)
    for _, opt in ipairs(options) do
        if opt.gossipOptionID == optionID then
            self.Choice = opt.name
            return
        end
    end
end

-- The same, when an addon picks by position in the list.
function GR:ChosenIndex(index)
    for _, opt in ipairs(options) do
        if opt.orderIndex == index then
            self.Choice = opt.name
            return
        end
    end
end

-- The Guide type an option names: the same name ("Banqueiro"), or the
-- shortest type holding it ("Culinária" -> "Culinária Treinador").
function GR:GuideKey(text)
    local data = Nx.GuideData
    local want = plain(text)
    if type(data) ~= "table" or want == "" then return nil end
    local best
    for key in pairs(data) do
        local k = plain(key)
        if k == want then return key end
        if k:find(want, 1, true) and (not best or #key < #best) then
            best = key
        end
    end
    return best
end

-- Player's faction as the Guide writes it: 1 Alliance, 2 Horde (0 is both).
local function myFaction()
    local fac = _G.UnitFactionGroup and _G.UnitFactionGroup("player")
    return fac == "Horde" and 2 or 1
end

-- Nearest entry of a Guide type on a map: zone x, y (0..100), or nil.
function GR:Nearest(key, mapId, px, py)
    local entries = Nx.GuideData[key] and Nx.GuideData[key][mapId]
    if type(entries) ~= "string" then return nil end
    local mine = myFaction()
    local bestX, bestY, bestD
    for entry in entries:gmatch("[^|]+") do
        local fac, x, y = entry:match("^(%d+),([%d%.]+),([%d%.]+)")
        fac, x, y = tonumber(fac), tonumber(x), tonumber(y)
        if x and (fac == 0 or fac == mine) then
            local d = px and ((x - px) ^ 2 + (y - py) ^ 2) or 0
            if not bestD or d < bestD then
                bestX, bestY, bestD = x, y, d
            end
        end
    end
    return bestX, bestY
end

function GR:Target(map)
    local key = self.Choice and self:GuideKey(self.Choice)
    local mapId = Nx.Map.RMapId
        or (_G.C_Map and _G.C_Map.GetBestMapForUnit and _G.C_Map.GetBestMapForUnit("player"))
    if not (key and mapId) then return false end
    local px, py
    local pos = _G.C_Map and _G.C_Map.GetPlayerMapPosition and _G.C_Map.GetPlayerMapPosition(mapId, "player")
    if type(pos) == "table" and pos.GetXY then
        px, py = pos:GetXY()
        if type(px) == "number" and type(py) == "number" then
            px, py = px * 100, py * 100
        else
            px, py = nil, nil
        end
    end
    local x, y = self:Nearest(key, mapId, px, py)
    if not x then return false end
    map:SetTargetXY(mapId, x, y, self.Choice)
    return true
end

-- Watch the talk: its options when shown, the one the player picks.
do
    local gossip = _G.C_GossipInfo
    if gossip and gossip.GetOptions and gossip.SelectOption and _G.hooksecurefunc and _G.CreateFrame then
        local f = _G.CreateFrame("Frame")
        f:RegisterEvent("GOSSIP_SHOW")
        f:SetScript("OnEvent", function() GR:Remember(gossip.GetOptions()) end)
        _G.hooksecurefunc(gossip, "SelectOption", function(optionID) GR:Chosen(optionID) end)
        if gossip.SelectOptionByIndex then
            _G.hooksecurefunc(gossip, "SelectOptionByIndex", function(index) GR:ChosenIndex(index) end)
        end
    end
end
