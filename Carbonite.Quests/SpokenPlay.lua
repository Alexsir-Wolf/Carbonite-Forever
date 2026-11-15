-- Carbonite.Quests | SpokenPlay
-- Spoken's quest narration Play button on Carbonite's watch list.
--
-- Spoken (Spoken_Quests) puts a Play button on the game's quest tracker. Carbonite hides that
-- tracker (TrackerHider.lua) and draws its own watch list, so the button was gone. This module
-- puts it on each quest title row of the watch list, bound by the same calls Spoken uses for the
-- game's tracker (Spoken_Quests/Compatibility.lua). Those live on the `VoiceOver` global and are
-- not Spoken's public API (Spoken/API.lua), so every call is guarded: a failure turns the buttons
-- off for the session with one chat line instead of raising inside the list update.
--
-- Spoken's own "Play button on the tracker" option decides whether a button shows, and Spoken
-- only offers it for quests it has a recording of. Nothing here runs without Spoken loaded.
--
-- Public (on Nx.Quest.SpokenPlay):
--   SP:Sweep(list)   lay the buttons over the list's visible quest title rows
--   SP:Reset()       forget the cached answers and lay the buttons out again

local Nx = _G.Nx
if not Nx or not Nx.List or not Nx.Quest then return end

local SP = {}
Nx.Quest.SpokenPlay = SP

local floor, max, min = math.floor, math.max, math.min
local ipairs, pairs, pcall, type = ipairs, pairs, pcall, type

local ORIGIN = "Carbonite's watch list"
-- ShowsTrackerButton asks Spoken's voice packs; the list redraws several times a second.
local CACHE_SECONDS = 5
local NEEDED = { "MakePlayButton", "ShowsTrackerButton", "BindPlayButton", "SetPlayButtonState" }

local buttons = {}      -- by position among the buttons shown, reused as the list scrolls
local shows = {}        -- questID -> { shows, time asked }
local failed, callbacksSet

local function HideFrom(first)
    for i = first, #buttons do
        buttons[i]:Hide()
    end
end

local function Fail(err)
    if failed then return end
    failed = true
    HideFrom(1)
    Nx.prt("Spoken Play button turned off for this session: %s", tostring(err))
end

-- Spoken's quest overlay, or nil when Spoken_Quests is not loaded. One that lost a call this
-- module needs is a Spoken update this module does not know: said once, then left alone.
local function Overlay()
    if failed then return nil end
    local vo = _G.VoiceOver
    local ui = type(vo) == "table" and vo.QuestOverlayUI
    if type(ui) ~= "table" then return nil end
    for _, name in ipairs(NEEDED) do
        if type(ui[name]) ~= "function" then
            Fail("QuestOverlayUI." .. name .. " is missing")
            return nil
        end
    end
    return ui
end

-- Returns the call's first result and whether it ran.
local function Call(ui, name, ...)
    local ok, result = pcall(ui[name], ui, ...)
    if not ok then
        Fail(result)
        return nil, false
    end
    return result, true
end

local function Shows(ui, questID)
    local now = GetTime()
    local hit = shows[questID]
    if hit and now - hit[2] < CACHE_SECONDS then return hit[1] end
    local value, ok = Call(ui, "ShowsTrackerButton", questID)
    if not ok then return false end
    value = value and true or false
    if hit then
        hit[1], hit[2] = value, now
    else
        shows[questID] = { value, now }
    end
    return value
end

local function Title(questID)
    if C_QuestLog and C_QuestLog.GetTitleForQuestID then
        local ok, title = pcall(C_QuestLog.GetTitleForQuestID, questID)
        if ok and type(title) == "string" and title ~= "" then return title end
    end
    for _, cur in ipairs(Nx.Quest.CurQ or {}) do
        if cur.QId == questID and cur.Title then return cur.Title end
    end
    return ""
end

local function GetButton(ui, index, parent)
    local button = buttons[index]
    if button then return button end
    button = Call(ui, "MakePlayButton", parent)
    if not button then return nil end
    -- As Spoken's own tracker buttons: the glyph follows the queue (Play, Stop, Replay).
    if not button.setPlayState then button.setPlayState = ui.FollowQueue end
    buttons[index] = button
    return button
end

-- Distance from the list's right edge. The modern look draws the quest item button at the right
-- edge of the row (Nx.List:Update, "WatchItem~...~R"); the Play button goes to its left.
local function RightInset(list, line, lineH)
    local slider = list.Slider and list.Slider.Frm
    local data = list.FrmData and list.FrmData[line]
    if type(data) == "string" and data:sub(1, 10) == "WatchItem~" and data:sub(-2) == "~R" then
        local sliderW = slider and slider:GetWidth() or 0
        local scale = (list.ItemFrameScale or 1) * .07 * lineH / 13
        return 2 + sliderW + 29 * scale + 2
    end
    local sliderW = slider and slider:IsShown() and slider:GetWidth() or 0
    return 2 + sliderW
end

-- Row data is qId * 0x10000 + qi for a quest's title and adds ln * 0x100 for its objectives.
local function TitleQuestID(data)
    if type(data) ~= "number" or data <= 0 or floor(data / 0x100) % 0x100 ~= 0 then return nil end
    local questID = floor(data / 0x10000)
    return questID > 0 and questID or nil
end

function SP:Reset()
    for questID in pairs(shows) do shows[questID] = nil end
    local watch = Nx.Quest.Watch
    local list = watch and watch.List
    if list and list.Frm then
        local ok, err = pcall(SP.Sweep, SP, list)
        if not ok then Fail(err) end
    end
end

local function SetCallbacks()
    if callbacksSet then return end
    local spoken = _G.Spoken
    if type(spoken) ~= "table" or type(spoken.RegisterCallback) ~= "function" then return end
    callbacksSet = true
    pcall(spoken.RegisterCallback, spoken, "VOICE_PACKS_LOADED", function() SP:Reset() end)
    pcall(spoken.RegisterCallback, spoken, "PART_SWITCHED", function(key)
        if key == "quests" then SP:Reset() end
    end)
end

function SP:Sweep(list)
    local ui = Overlay()
    if not ui then
        HideFrom(1)
        return
    end
    SetCallbacks()

    local frm = list.Frm
    local lineH = list:GetLineH()
    local hdrH = list.HdrH or 0
    local top = list.Top or 1
    local last = min(top + (list.Vis or 0) - 1, list.Num or 0)
    local size = max(12, min(20, lineH + 2))
    local used = 0

    for line = top, last do
        local questID = TitleQuestID(list.Data[line])
        if questID and Shows(ui, questID) then
            local button = GetButton(ui, used + 1, frm)
            if failed then return end
            if button then
                used = used + 1
                button:SetSize(size, size)
                button:ClearAllPoints()
                button:SetPoint("RIGHT", frm, "TOPRIGHT", -RightInset(list, line, lineH),
                    -((line - top) * lineH + hdrH + lineH / 2))
                if button.NxQuestID ~= questID then
                    local _, ok = Call(ui, "BindPlayButton", button, questID, Title(questID), ORIGIN)
                    if not ok then return end
                    button.NxQuestID = questID
                end
                button:Show()
                Call(ui, "SetPlayButtonState", button)
                if failed then return end
            end
        end
    end

    HideFrom(used + 1)
end

-- Every list shares Nx.List.Update through its metatable; only the watch list gets buttons.
-- Scrolling calls Update directly, so this covers it as well as a rebuilt list.
hooksecurefunc(Nx.List, "Update", function(list)
    local watch = Nx.Quest.Watch
    if failed or not watch or list ~= watch.List then return end
    local ok, err = pcall(SP.Sweep, SP, list)
    if not ok then Fail(err) end
end)
