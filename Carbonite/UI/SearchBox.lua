-- Carbonite | UI / SearchBox
-- The one search field of every window (Guide, Warehouse, quest log, Notes,
-- journey), #102: magnifier icon, translated placeholder, a button that clears
-- the text, Esc clears and leaves the field, Enter confirms, and a short delay
-- before the window filters, so a long list is not rebuilt on every key.
-- Searching ignores case and accents (SearchBox.Normalize / SearchBox.Matches).
--
-- Usage:
--   local box = Nx.SearchBox:Create(win.Frm, function(text, box) self:Update() end,
--       { placeholder = L["Search items..."], maxLetters = 60 })
--   win:Attach(box.Frm, 0, 1, 0, 18)
--   if Nx.SearchBox.Matches(row.name, box:GetText()) then ... end
--
-- Options: placeholder, maxLetters, delay (seconds, 0 = no delay), name (frame
-- name), font, onSubmit(text, box) called on Enter.

local Carbonite = _G.Carbonite
local L = LibStub("AceLocale-3.0"):GetLocale("Carbonite")

local SearchBox = {}
SearchBox.__index = SearchBox
Carbonite.UI.SearchBox = SearchBox

SearchBox.DELAY = 0.2
SearchBox.HEIGHT = 18

local ICON_SEARCH = "Interface\\Common\\UI-Searchbox-Icon"
local ICON_CLEAR = "Interface\\FriendsFrame\\ClearBroadcastIcon"

-------------------------------------------------------------------------------
-- Text matching
-------------------------------------------------------------------------------

-- Accented Latin letters (UTF-8, two bytes starting with \195) -> plain letter.
local ACCENTS = {}
local function plain(letter, chars)
    for ch in chars:gmatch("[\192-\223][\128-\191]") do
        ACCENTS[ch] = letter
    end
end
plain("a", "àáâãäåÀÁÂÃÄÅ")
plain("c", "çÇ")
plain("e", "èéêëÈÉÊË")
plain("i", "ìíîïÌÍÎÏ")
plain("n", "ñÑ")
plain("o", "òóôõöøÒÓÔÕÖØ")
plain("u", "ùúûüÙÚÛÜ")
plain("y", "ýÿÝ")

--- Text in lower case and without accents, for comparing searches.
function SearchBox.Normalize(text)
    if text == nil then return "" end
    text = tostring(text)
    return (text:gsub("[\192-\223][\128-\191]", ACCENTS):lower())
end

--- True when `needle` (the typed search) is inside `haystack`, ignoring case and
--- accents. An empty search matches everything.
function SearchBox.Matches(haystack, needle)
    needle = SearchBox.Normalize(needle)
    if needle == "" then return true end
    return SearchBox.Normalize(haystack):find(needle, 1, true) ~= nil
end

-------------------------------------------------------------------------------
-- Widget
-------------------------------------------------------------------------------

local function paint(texture, token)
    local Skin = Carbonite.UI.Skin
    if Skin and Skin.Paint then Skin:Paint(texture, token) end
end

--- New search field on `parent`. `onChanged(text, box)` runs after the delay,
--- or at once on Enter, Esc and the clear button.
function SearchBox:Create(parent, onChanged, opts)
    opts = opts or {}
    local box = setmetatable({}, self)
    box.OnChanged = onChanged
    box.OnSubmit = opts.onSubmit
    box.Delay = opts.delay or self.DELAY
    box.Text = ""
    box.Seq = 0
    box.Pending = false

    local f = CreateFrame("EditBox", opts.name, parent)
    box.Frm = f
    f.NxInst = box
    f:SetAutoFocus(false)
    f:SetFontObject(opts.font or "NxFontS")
    f:SetMaxLetters(opts.maxLetters or 60)
    f:SetHeight(self.HEIGHT)
    f:SetTextInsets(19, 18, 0, 0)

    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(f)
    paint(bg, "listHeader")
    box.Bg = bg

    local line = f:CreateTexture(nil, "BORDER")
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
    line:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    paint(line, "separator")
    box.Line = line

    local icon = f:CreateTexture(nil, "OVERLAY")
    icon:SetTexture(ICON_SEARCH)
    icon:SetSize(14, 14)
    icon:SetPoint("LEFT", f, "LEFT", 3, -1)
    icon:SetVertexColor(0.7, 0.7, 0.7)
    box.Icon = icon

    local hint = f:CreateFontString(nil, "ARTWORK")
    hint:SetFontObject(opts.font or "NxFontS")
    hint:SetTextColor(0.55, 0.55, 0.55)
    hint:SetPoint("LEFT", f, "LEFT", 19, 0)
    hint:SetText(opts.placeholder or L["Search..."])
    box.Hint = hint

    local clear = CreateFrame("Button", nil, f)
    clear:SetSize(14, 14)
    clear:SetPoint("RIGHT", f, "RIGHT", -3, 0)
    local x = clear:CreateTexture(nil, "ARTWORK")
    x:SetTexture(ICON_CLEAR)
    x:SetAllPoints(clear)
    x:SetAlpha(0.6)
    clear:SetScript("OnEnter", function() x:SetAlpha(1) end)
    clear:SetScript("OnLeave", function() x:SetAlpha(0.6) end)
    clear:SetScript("OnClick", function() box:Clear() end)
    clear:Hide()
    box.ClearBut = clear

    f:SetScript("OnTextChanged", function() box:OnTextChanged() end)
    f:SetScript("OnEditFocusGained", function() paint(line, "scrollThumb") end)
    f:SetScript("OnEditFocusLost", function() paint(line, "separator") end)
    f:SetScript("OnEnterPressed", function()
        box:Flush()
        if box.OnSubmit then box.OnSubmit(box.Text, box) end
        f:ClearFocus()
    end)
    f:SetScript("OnEscapePressed", function()
        box:Clear()
        f:ClearFocus()
    end)

    box:Refresh()
    return box
end

--- The typed search (raw; compare it with SearchBox.Matches).
function SearchBox:GetText()
    return self.Text
end

--- Put text in the field without running onChanged (e.g. switching tabs).
function SearchBox:SetText(text)
    text = text or ""
    self.Silent = true
    self.Frm:SetText(text)
    self.Silent = false
    self.Text = text
    self.Seq = self.Seq + 1
    self.Pending = false
    self:Refresh()
end

--- Empty the field and run onChanged at once.
function SearchBox:Clear()
    local changed = self.Text ~= "" or self.Pending
    self:SetText("")
    if changed then self:Fire() end
end

function SearchBox:OnTextChanged()
    self.Text = self.Frm:GetText() or ""
    self:Refresh()
    if not self.Silent then self:Schedule() end
end

-- Placeholder only while empty, clear button only while there is text.
function SearchBox:Refresh()
    local empty = self.Text == ""
    if empty then
        self.Hint:Show()
        self.ClearBut:Hide()
    else
        self.Hint:Hide()
        self.ClearBut:Show()
    end
end

-- Runs onChanged after the delay; a newer key press restarts the wait.
function SearchBox:Schedule()
    self.Seq = self.Seq + 1
    self.Pending = true
    local timer = _G.C_Timer
    if self.Delay <= 0 or not (timer and timer.After) then
        self:Fire()
        return
    end
    local seq = self.Seq
    timer.After(self.Delay, function()
        if self.Seq == seq then self:Fire() end
    end)
end

--- Run a waiting onChanged now.
function SearchBox:Flush()
    if self.Pending then self:Fire() end
end

function SearchBox:Fire()
    self.Seq = self.Seq + 1
    self.Pending = false
    if self.OnChanged then self.OnChanged(self.Text, self) end
end
