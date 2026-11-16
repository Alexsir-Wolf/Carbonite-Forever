-- Carbonite.Quests | ShowOnMap
-- A "Show on map" button on the quest details panel of the journal.
--
-- Selecting a quest in the journal already points the map at it, but puts the map back on the
-- current zone and leaves it closed. The button points the map at the objectives, or at whoever
-- takes the quest once it is complete (Nx.Quest:TrackOnMap), opens the map, and its tooltip says
-- which of the two it will show. The watch list keeps its own ways: shift-click and the right-click
-- menu.
--
-- Public (on Nx.Quest.ShowOnMap):
--   SM:Target(qId)                  "turnin", npc name for a complete quest, else "objectives"
--   SM:AttachToDetails(frame)       create the button on the journal's details panel
--   SM:SetDetailsQuest(qId, qIndex) the quest the button shows (qIndex > 0 when in the log)

local Nx = _G.Nx
if not Nx or not Nx.Quest then return end
local L = LibStub("AceLocale-3.0"):GetLocale("Carbonite.Quest", true)

local SM = {}
Nx.Quest.ShowOnMap = SM

function SM:Target(qId)
    local _, cur = Nx.Quest:FindCur(qId)
    if not (cur and cur.Complete) then return "objectives" end
    local quest = Nx.Quests and Nx.Quests[qId]
    local name = quest and quest.End and Nx.Quest:UnpackSE(quest.End)
    if type(name) ~= "string" or name == "" or tonumber(name) then name = nil end
    return "turnin", name
end

local function OnEnter(button)
    local kind, npc = SM:Target(button.NxQuestID)
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetText(L["Show on map"])
    if kind == "turnin" then
        GameTooltip:AddLine(npc and L["Turn in to %s"]:format(npc) or L["Turn in"], 1, 1, 1)
    else
        GameTooltip:AddLine(L["Objectives"], 1, 1, 1)
    end
    GameTooltip:Show()
end

function SM:AttachToDetails(frame)
    local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    button:SetText(L["Show on map"])
    button:SetSize(button:GetFontString():GetStringWidth() + 24, 22)
    button:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -24, -6)
    button:SetFrameLevel(frame:GetFrameLevel() + 5)
    button:SetScript("OnEnter", OnEnter)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetScript("OnClick", function(b)
        Nx.Quest:TrackOnMap(b.NxQuestID, 0, b.NxInLog, true)
        local MapOpen = Carbonite.Modules.Map and Carbonite.Modules.Map.MapOpen
        if MapOpen then MapOpen:Open() end
    end)
    button:Hide()
    self.DetailsButton = button
end

function SM:SetDetailsQuest(qId, qIndex)
    local button = self.DetailsButton
    if not button then return end
    button.NxQuestID, button.NxInLog = qId, (qIndex or 0) > 0
    button:SetShown(qId and qId > 0 or false)
end
