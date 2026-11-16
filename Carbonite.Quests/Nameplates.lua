-- Carbonite.Quests | Nameplates
-- A quest icon on the nameplate of an enemy you still need for a quest in
-- your log (#75). Which NPC counts for which objective comes from
-- Nx.Units2Quests ("questId,objective|..." per NPC id), which QuestieSource
-- fills in for the Forever quests.
--
--   NP:NeededFor(npcId)  the logged quest the NPC still counts for, or nil
--   NP:NpcId(unit)       NPC id of a unit, or nil (players, secret GUIDs)
--   NP:Refresh(unit)     show or hide the icon on that unit's plate

local Nx = _G.Nx
local Quest = Nx.Quest
local NP = {}
Quest.Nameplates = NP

local ICON = "Interface\\TargetingFrame\\PortraitQuestBadge"

local canaccessvalue = _G.canaccessvalue
local issecretvalue = _G.issecretvalue
local function CanUse(value)
    if canaccessvalue and not canaccessvalue(value) then return false end
    return not (issecretvalue and issecretvalue(value))
end

local function Enabled()
    local profile = Nx.qdb and Nx.qdb.profile
    return profile and profile.Quest and profile.Quest.NameplateIcon
end

function NP:NpcId(unit)
    local guid = UnitGUID(unit)
    if not guid or not CanUse(guid) then return nil end
    local kind, id = guid:match("^(%a+)%-[^-]*%-[^-]*%-[^-]*%-[^-]*%-(%d+)")
    if kind ~= "Creature" and kind ~= "Vehicle" then return nil end
    return tonumber(id)
end

-- An objective counts while the quest is not done and that objective's done
-- flag (cur[n + 100]) is not set. Objective 0 or unknown: the whole quest.
function NP:NeededFor(npcId)
    local list = npcId and Nx.Units2Quests and Nx.Units2Quests[npcId]
    if type(list) ~= "string" then return nil end
    for entry in list:gmatch("[^|]+") do
        local qId, objective = entry:match("^(%d+),?(%d*)")
        local _, cur = Quest:FindCur(tonumber(qId))
        if cur and not cur.CompleteMerge then
            local n = tonumber(objective)
            if not n or n == 0 or not cur[n] or not cur[n + 100] then
                return cur
            end
        end
    end
end

local function Icon(plate)
    local icon = plate.CarboniteQuestIcon
    if not icon then
        icon = plate:CreateTexture(nil, "OVERLAY")
        icon:SetTexture(ICON)
        icon:SetSize(18, 18)
        local anchor = plate.UnitFrame and plate.UnitFrame.healthBar or plate
        icon:SetPoint("RIGHT", anchor, "LEFT", -2, 0)
        plate.CarboniteQuestIcon = icon
    end
    return icon
end

function NP:Refresh(unit)
    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    if not plate then return end
    local show = Enabled() and not UnitIsFriend("player", unit) and self:NeededFor(self:NpcId(unit))
    if show then
        Icon(plate):Show()
    elseif plate.CarboniteQuestIcon then
        plate.CarboniteQuestIcon:Hide()
    end
end

function NP:RefreshAll()
    for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
        local unit = plate.namePlateUnitToken
        if unit then self:Refresh(unit) end
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
frame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
frame:RegisterEvent("QUEST_LOG_UPDATE")
frame:SetScript("OnEvent", function(_, event, unit)
    if not Nx.QInit then return end
    if event == "QUEST_LOG_UPDATE" then
        NP:RefreshAll()
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        NP:Refresh(unit)
    else
        local plate = C_NamePlate.GetNamePlateForUnit(unit)
        if plate and plate.CarboniteQuestIcon then plate.CarboniteQuestIcon:Hide() end
    end
end)
