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
-- Play sits inside the window, right after Carbonite's quest icon and before the title, as
-- Spoken's own button sits left of the title: the icon column is widened just enough for it while
-- any listed quest has a recording, so every row's text moves right alike and none is covered.
--
-- Spoken's own "Play button on the tracker" option decides whether a button shows, and Spoken
-- only offers it for quests it has a recording of. Nothing here runs without Spoken loaded.
--
-- The journal's details panel gets one more Play, at its top right, for the quest it shows.
--
-- Public (on Nx.Quest.SpokenPlay):
--   SP:Sweep(list)              lay the buttons over the list's visible quest title rows
--   SP:Reset()                  forget the cached answers and lay the buttons out again
--   SP:AttachToDetails(frame)   the journal's details panel, where its Play goes
--   SP:SetDetailsQuest(qId)     the quest that panel shows; Play shows when Spoken has it

local Nx = _G.Nx
if not Nx or not Nx.List or not Nx.Quest then return end
local L = LibStub("AceLocale-3.0"):GetLocale("Carbonite.Quest", true)

local SP = {}
Nx.Quest.SpokenPlay = SP

local floor, max, min = math.floor, math.max, math.min
local ipairs, pairs, pcall, type = ipairs, pairs, pcall, type

local ORIGIN = "Carbonite's watch list"
local DETAILS_ORIGIN = "Carbonite's quest log"
-- ShowsTrackerButton asks Spoken's voice packs; the list redraws several times a second.
local CACHE_SECONDS = 5
local NEEDED = { "MakePlayButton", "ShowsTrackerButton", "BindPlayButton", "SetPlayButtonState" }
-- Play's largest size. Nx.List draws its icons and text this far from the list's left edge, and
-- its icons are 14 square at a line height of BaseLineH (Nx.List:CreateButtons).
local MAX_SIZE = 16
local LIST_PAD = 1
local ICON_SIZE = 14
-- Play's frame overlaps the icon's by this much: both draw their glyph inside a margin, so the
-- glyphs end up side by side. Then the gap before the title's text.
local ICON_OVERLAP = 2
local TEXT_GAP = 2

local buttons = {}      -- by position among the buttons shown, reused as the list scrolls
local details = {}      -- the journal's details panel: frame, its Play, the quest shown
local shows = {}        -- questID -> { shows, time asked }
local failed, callbacksSet, relaying

local function HideFrom(first)
    for i = first, #buttons do
        buttons[i]:Hide()
    end
end

-- Column 1 holds Carbonite's quest icon (WatchWindow.lua, ColumnAdd). Widened to `width`; the
-- width it had is kept to put it back, and a width set again by Carbonite is taken as the new one.
-- Each returns whether the width changed, so the list must be laid out again.
local function Widen(list, width)
    local column = list.Columns and list.Columns[1]
    if not column then return false end
    if column.Width ~= list.NxSpokenWidth then list.NxSpokenBaseW = column.Width end
    width = max(list.NxSpokenBaseW, width)
    local changed = column.Width ~= width
    column.Width = width
    list.NxSpokenWidth = width
    return changed
end

local function Narrow(list)
    local column = list.Columns and list.Columns[1]
    local widened = list.NxSpokenWidth
    list.NxSpokenWidth = nil
    if not column or not widened or column.Width ~= widened then return false end
    column.Width = list.NxSpokenBaseW
    return true
end

-- Lays the list out again after its icon column changed width; the hook runs once more inside.
local function Relayout(list)
    if relaying then return end
    relaying = true
    pcall(list.Update, list)
    relaying = false
end

local function Fail(err)
    if failed then return end
    failed = true
    HideFrom(1)
    if details.button then details.button:Hide() end
    Nx.prt(L["Spoken Play button turned off for this session: %s"], tostring(err))
    local watch = Nx.Quest.Watch
    local list = watch and watch.List
    if list and Narrow(list) then Relayout(list) end
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

-- Row data is qId * 0x10000 + qi for a quest's title and adds ln * 0x100 for its objectives.
local function TitleQuestID(data)
    if type(data) ~= "number" or data <= 0 or floor(data / 0x100) % 0x100 ~= 0 then return nil end
    local questID = floor(data / 0x10000)
    return questID > 0 and questID or nil
end

-- Whether any quest in the list, shown or scrolled away, gets Play. Keeps the column steady
-- while the list scrolls.
local function AnyShows(ui, list)
    for line = 1, list.Num or 0 do
        local questID = TitleQuestID(list.Data[line])
        if questID and Shows(ui, questID) then return true end
        if failed then return false end
    end
    return false
end

function SP:Reset()
    for questID in pairs(shows) do shows[questID] = nil end
    if details.questID then SP:SetDetailsQuest(details.questID) end
    local watch = Nx.Quest.Watch
    local list = watch and watch.List
    if list and list.Frm then
        local ok, err = pcall(SP.Sweep, SP, list)
        if not ok then Fail(err) end
    end
end

function SP:AttachToDetails(frame)
    details.frame = frame
end

function SP:SetDetailsQuest(qId)
    details.questID = qId
    local ui = Overlay()
    local show = ui and details.frame and type(qId) == "number" and qId > 0 and Shows(ui, qId)
    if not show then
        if details.button then details.button:Hide() end
        return
    end
    local button = details.button
    if not button then
        button = Call(ui, "MakePlayButton", details.frame)
        if not button then return end
        if not button.setPlayState then button.setPlayState = ui.FollowQueue end
        button:SetSize(MAX_SIZE + 4, MAX_SIZE + 4)
        button:SetPoint("TOPRIGHT", details.frame, "TOPRIGHT", -24, -8)
        button:SetFrameLevel(details.frame:GetFrameLevel() + 5)
        details.button = button
    end
    if button.NxQuestID ~= qId then
        local _, ok = Call(ui, "BindPlayButton", button, qId, Title(qId), DETAILS_ORIGIN)
        if not ok then return end
        button.NxQuestID = qId
    end
    button:Show()
    Call(ui, "SetPlayButtonState", button)
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
    if not ui or not AnyShows(ui, list) then
        HideFrom(1)
        if Narrow(list) then Relayout(list) end
        return
    end
    SetCallbacks()

    local lineH = list:GetLineH()
    local size = max(12, min(MAX_SIZE, lineH + 2))
    -- The icon is centred half a line in, at its scale (Nx.List:Update, "Buttons").
    local iconRight = LIST_PAD + lineH / 2 + ICON_SIZE / 2 * lineH / (list.BaseLineH or lineH)
    local left = iconRight - ICON_OVERLAP
    if Widen(list, math.ceil(left + size + TEXT_GAP - LIST_PAD)) and not relaying then
        Relayout(list)      -- lays the buttons out from inside
        return
    end

    local frm = list.Frm
    local hdrH = list.HdrH or 0
    local top = list.Top or 1
    local last = min(top + (list.Vis or 0) - 1, list.Num or 0)
    local x = left + size / 2
    local used = 0

    for line = top, last do
        local questID = TitleQuestID(list.Data[line])
        if questID and Shows(ui, questID) then
            local button = GetButton(ui, used + 1, frm)
            if failed then return end
            if button then
                used = used + 1
                local offX = list.Offsets and list.Offsets[line] or 0
                button:SetSize(size, size)
                button:ClearAllPoints()
                button:SetPoint("CENTER", frm, "TOPLEFT", x + offX, -((line - top) * lineH + hdrH + lineH / 2))
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
