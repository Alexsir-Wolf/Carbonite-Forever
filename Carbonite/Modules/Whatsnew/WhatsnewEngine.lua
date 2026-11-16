-- Carbonite | Modules / Whatsnew / WhatsnewEngine
-- The legacy "What's New" changelog window engine, extracted from
-- Carbonite.lua. Owns:
--   * the Nx.Whatsnew data table (categories + per-category dated
--     changelog entries)
--   * Nx.Whatsnew:ShouldAutoShow() (login check against Nx.db.profile.Whatsnew.lastreadtime)
--   * Nx.Whatsnew:ToggleShow / :Create / :Recordtime / :Cat_button /
--     :OnListEvent / :Update
--
-- The new Whatsnew module (Whatsnew.lua) and its public surface
-- (WhatsnewWindow.lua) already proxy through Nx.Whatsnew; nothing
-- changes from their side beyond seeing the data populated by this
-- file at load time instead of by Carbonite.lua.

local L = LibStub("AceLocale-3.0"):GetLocale("Carbonite")

-------------------------------------------------------------------------------
-- Data: changelog categories and entries
-------------------------------------------------------------------------------

-- Lines wider than this get wrapped: the detail list shows one line per row.
local WRAP = 55

--- Split each bullet into rows of at most WRAP characters, indenting the
--- continuation rows, and put a blank row between bullets.
local function entry(title, bullets)
    local rows = { title, "" }
    for i, text in ipairs(bullets) do
        local row = ""
        for word in text:gmatch("%S+") do
            if row ~= "" and #row + 1 + #word > WRAP then
                rows[#rows + 1] = row
                row = "   " .. word
            else
                row = row == "" and word or row .. " " .. word
            end
        end
        rows[#rows + 1] = row
        if i < #bullets then rows[#rows + 1] = "" end
    end
    return rows
end

Nx.Whatsnew = {}
Nx.Whatsnew.Categories = {"Forever"}
Nx.Whatsnew.Forever = {
    [1794744000] = entry("v12.1.0-00023-forever.1", {
        L["Forever quests from QuestieDB: with QuestieDB enabled, Carbonite shows the giver, turn-in and objectives of about 1,300 Forever quests it did not have."],
        L["Spoken narration in the quest list: a play button next to the icon of the quests Spoken narrates."],
        L["Live minimap in dungeons: the map window shows Blizzard's minimap with the dungeon name instead of a blank or wrong map."],
        L["The add-on files no longer carry CurseForge and WoWInterface ids, so add-on managers do not swap this edition for the official one."],
    }),
}
Nx.Whatsnew.WhichCat = 1
Nx.Whatsnew.HasWhatsNew = nil

-------------------------------------------------------------------------------
-- Window
-------------------------------------------------------------------------------

--- Toggle the window's visible state, creating it on first call.
function Nx.Whatsnew:ToggleShow()
    if not self.Win then
        self:Create()
    end

    self.Win:Show(not self.Win:IsShown())

    if self.Win:IsShown() then
        self:Update()
    end
end

--- Build the What's New window: two-pane list view with category
--- buttons across the top.
function Nx.Whatsnew:Create()
    local win = Nx.Window:Create("NxWhatsNew", nil, nil, nil, 1)
    self.Win = win
    self.SelectedLine = 1
    win.Frm.NxInst = self
    win:CreateButtons(true, true)
    win:InitLayoutData(nil, -.25, -.15, -.5, -.6)
    win.Frm:SetToplevel(true)
    win:Show(false)
    -- Note: closing the window no longer marks the update read. Only
    -- the explicit "Don't show this update again" button dismisses it,
    -- so the window keeps popping each login until the player opts out.
    tinsert(UISpecialFrames, win.Frm:GetName())

    Nx.List:SetCreateFont("Font.Medium", 16)

    -- Left list: dated entry index for the currently selected category.
    local list = Nx.List:Create(false, 0, 0, 1, 1, win.Frm)
    self.List = list
    list:SetUser(self, self.OnListEvent)
    list:SetLineHeight(4)
    list:ColumnAdd("", 1, 24)
    list:ColumnAdd("Date", 2, 200)
    list:SetUser(self, self.OnListEvent)
    win:Attach(list.Frm, 0, .2, 0, .94)

    -- Right list: lines of the selected entry.
    local detail = Nx.List:Create(false, 0, 0, 1, 1, win.Frm)
    self.WhatsNewList = detail
    detail:ColumnAdd("", 1, 500)
    win:Attach(detail.Frm, .2, 1, 0, .94)

    -- Category-selector buttons across the top.
    local _, bh = win:GetBorderSize()
    local pos = 150
    for i, name in pairs(Nx.Whatsnew.Categories) do
        local function func() Nx.Whatsnew:Cat_button(i) end
        local but = Nx.Button:Create(win.Frm, "Txt64", name, nil, pos, -bh, "TOPLEFT",
            string.len(name) * 10, 20, func, self)
        pos = pos + but.Frm:GetWidth()
    end

    -- "Don't show this update again" button, bottom-left of the window.
    -- Dismisses the current changelog so it won't auto-pop again until
    -- a newer entry is added.
    local dismissText = L["Don't show for this update again"]
    Nx.Button:Create(win.Frm, "Txt64", dismissText, nil, 12, bh, "BOTTOMLEFT",
        string.len(dismissText) * 8 + 20, 22,
        function() Nx.Whatsnew:DismissUpdate() end, self)

    self:Update()
    self.List:Select(0)
    self.List:FullUpdate()
end

--- Record current time as last-read; clear the minimap-button glow.
function Nx.Whatsnew:Recordtime()
    Nx.db.profile.Whatsnew.lastreadtime = time()
    NXMiniMapBut:SetNormalTexture("Interface\\AddOns\\Carbonite\\Gfx\\MMBut")
end

--- Highest changelog timestamp across all categories.
function Nx.Whatsnew:GetMaxTime()
    local maxTs = 0
    for _, cat in pairs(Nx.Whatsnew.Categories) do
        for ts in pairs(Nx.Whatsnew[cat] or {}) do
            if ts > maxTs then maxTs = ts end
        end
    end
    return maxTs
end

--- True once the player has dismissed the current changelog: lastreadtime
--- equals the newest entry's timestamp. Using equality (not <) means the
--- auto-show fires until the player opts out, and any newer entry (a
--- bigger max timestamp) re-arms it.
function Nx.Whatsnew:DismissedCurrent()
    return (Nx.db.profile.Whatsnew.lastreadtime or 0) == self:GetMaxTime()
end

--- Login check for opening the window by itself. A fresh install has no
--- history to catch up on: it starts with the current changelog marked
--- read, and only a newer entry opens the window.
function Nx.Whatsnew:ShouldAutoShow()
    local saved = Nx.db.profile.Whatsnew
    if (saved.lastreadtime or 0) == 0 then
        saved.lastreadtime = self:GetMaxTime()
        return false
    end
    return not self:DismissedCurrent()
end

--- "Don't show this update again": pin lastreadtime to the newest entry
--- so the window stops auto-popping until a newer changelog is added.
function Nx.Whatsnew:DismissUpdate()
    Nx.db.profile.Whatsnew.lastreadtime = self:GetMaxTime()
    NXMiniMapBut:SetNormalTexture("Interface\\AddOns\\Carbonite\\Gfx\\MMBut")
    if self.Win then self.Win:Show(false) end
end

--- Switch to category N (1-based index into Nx.Whatsnew.Categories).
function Nx.Whatsnew:Cat_button(num)
    Nx.Whatsnew.WhichCat = num
    Nx.Whatsnew.SelectedLine = 1
    Nx.Whatsnew:Update()
end

--- List click handler: store selection, refresh the detail pane.
function Nx.Whatsnew:OnListEvent(eventName, sel)
    local data = self.List:ItemGetData(sel) or 0
    self.SelectedLine = data % 1000
    if eventName == "select" then
        self:Update()
    end
end

--- Redraw both panes for the current category + selection.
function Nx.Whatsnew:Update()
    self.Win:SetTitle(L["Carbonite What's New"])

    local list = self.List
    list:Empty()
    local cnt = 1
    local display = {}
    local cat = Nx.Whatsnew.Categories[Nx.Whatsnew.WhichCat]
    -- Numeric timestamp keys: pairs() yields them in hash order, so
    -- sort newest-first before listing or the dates come out jumbled.
    local entries = Nx.Whatsnew[cat] or {}
    local keys = {}
    for ts in pairs(entries) do keys[#keys + 1] = ts end
    table.sort(keys, function(a, b) return a > b end)
    for _, ts in ipairs(keys) do
        list:ItemAdd(cnt)
        list:ItemSet(2, date(L["%m/%d/%y"], ts))
        if cnt == self.SelectedLine then
            display = entries[ts]
        end
        cnt = cnt + 1
    end
    list:Update()

    list = self.WhatsNewList
    list:Empty()
    cnt = 1
    -- ipairs: the entry's lines are an ordered array; pairs() would
    -- shuffle them.
    for _, line in ipairs(display) do
        list:ItemAdd(cnt)
        list:ItemSet(1, line)
        cnt = cnt + 1
    end
    list:Update()
end
