-- Carbonite.Quests | ShowOnMap
-- A "Show on map" button at the end of each quest title row of the watch list.
--
-- The action already existed, hidden in the row's right-click menu ("Show On Map") and on
-- shift-click: Nx.Quest.Watch:Set tracks the quest and Nx.Quest:TrackOnMap points the map at the
-- objectives, or at whoever takes the quest once it is complete. The button makes it one visible
-- click, opens the map, and its tooltip says which of the two it will show.
--
-- Public (on Nx.Quest.ShowOnMap):
--   SM:Target(qId)   "turnin", npc name for a complete quest, else "objectives"
--   SM:Sweep(list)   lay the buttons over the list's visible quest title rows

local Nx = _G.Nx
if not Nx or not Nx.List or not Nx.Quest then return end
local L = LibStub("AceLocale-3.0"):GetLocale("Carbonite.Quest", true)

local SM = {}
Nx.Quest.ShowOnMap = SM

local SIZE = 14
-- Gap between the button and the list's right edge (the scroll bar sits outside the list).
local RIGHT_PAD = 4
local ICON_ATLAS = "Waypoint-MapPin-ChatIcon"
-- The map scroll icon, in every client, when the pin atlas is missing.
local ICON_FILE = "Interface\\Icons\\INV_Misc_Map_01"

local buttons = {}

-- Width the button takes at the end of a quest title row; the row text stops before it.
local function RowRightPad(list, line)
    return Nx.Quest.SpokenPlay.TitleQuestID(list.Data[line]) and SIZE + RIGHT_PAD + 2 or 0
end
SM.RowRightPad = RowRightPad

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

local function OnClick(button)
    Nx.Quest.Watch:Set(button.NxData, true)
    local MapOpen = Carbonite.Modules.Map and Carbonite.Modules.Map.MapOpen
    if MapOpen then MapOpen:Open() end
end

local function GetButton(index, parent)
    local button = buttons[index]
    if button then return button end
    button = CreateFrame("Button", nil, parent)
    button:SetSize(SIZE, SIZE)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(ICON_ATLAS) then
        icon:SetAtlas(ICON_ATLAS)
    else
        icon:SetTexture(ICON_FILE)
        icon:SetTexCoord(.08, .92, .08, .92)
    end
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    button:SetScript("OnEnter", OnEnter)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetScript("OnClick", OnClick)
    buttons[index] = button
    return button
end

function SM:Sweep(list)
    list.RowRightPad = RowRightPad
    local frm = list.Frm
    local lineH = list:GetLineH()
    local hdrH = list.HdrH or 0
    local top = list.Top or 1
    local last = math.min(top + (list.Vis or 0) - 1, list.Num or 0)
    local right = frm:GetWidth() - SIZE / 2 - RIGHT_PAD
    -- Quest item buttons sit at the right end of their rows: the pin goes left of them.
    local itemPads = list:GetWatchItemRightPads(lineH) or {}
    local used = 0
    for line = top, last do
        local data = list.Data[line]
        local qId = Nx.Quest.SpokenPlay.TitleQuestID(data)
        if qId then
            used = used + 1
            local button = GetButton(used, frm)
            button.NxQuestID, button.NxData = qId, data
            button:ClearAllPoints()
            local x = right - (itemPads[line] or 0)
            button:SetPoint("CENTER", frm, "TOPLEFT", x, -((line - top) * lineH + hdrH + lineH / 2))
            button:Show()
        end
    end
    for i = used + 1, #buttons do
        buttons[i]:Hide()
    end
end

-- Same hook as SpokenPlay: every list shares Nx.List.Update; only the watch list gets buttons.
hooksecurefunc(Nx.List, "Update", function(list)
    local watch = Nx.Quest.Watch
    if not watch or list ~= watch.List then return end
    SM:Sweep(list)
end)
