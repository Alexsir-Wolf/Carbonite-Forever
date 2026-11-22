-- Carbonite | Modules / Assistant
-- First-run setup assistant of the edition (#63). The first time the
-- edition runs on a profile it opens a short window of pages, each one
-- asking one essential question with two clear choices:
--
--   map          - M opens the Carbonite map or the game's world map
--   minimap      - the game minimap inside the Carbonite map, or not
--   theme        - the game's look (Blizzard) or the dark one
--   givers       - quest givers on the map: all, or only the quests the
--                  player can take now
--   navigator    - who guides to the destinations: Carbonite, TomTom or
--                  Shortest Path Forever (#222/#223); addons not installed
--                  are shown but cannot be picked
--   integrations - the companion addons found and what each one adds,
--                  plus the main shortcuts
--
-- Every choice writes the same profile key its option writes (no keys of
-- its own): Map.MaxOverride, MiniMap.Own (with ButOwn and ShowOldNameplate,
-- as the option does), Skin.Name, Map.QuestGiversAvailable and
-- Track.Navigator. The only keys the assistant owns are the "seen" marks in
-- the profile: Version.Assistant and Version.AssistantSeen (the addon
-- version it was last shown for).
--
-- It opens on the first run and again on every new version of the addon
-- (#222), and when the saved navigator is an addon no longer enabled.
-- "Skip", "Done", the close button and ESC all end it and mark it seen.
-- Putting the minimap in or out, or changing the navigator, takes a reload:
-- when one of them changed, ending the assistant asks to reload.
--
-- It replaces the old one-question "quick options" dialog of
-- Nx.Opts:QuickOptsTimer (Version.QuickVer), which only asked the minimap
-- question and reloaded right away.
--
-- Public API:
--   Assistant:ShouldShow()          - true while this profile has not seen it
--   Assistant:MarkSeen()
--   Assistant:AutoShow()            - open it when ShouldShow (login)
--   Assistant:Open(page)            - open it (/carb assistente)
--   Assistant:Get(id)               - current value of a page's choice
--   Assistant:Choose(id, value)     - write a choice to its option key
--   Assistant:Skip() / :Finish(openOptions)
--   Assistant:Integrations()        - { { addon, what, active } } in order

local Carbonite = _G.Carbonite
local L = LibStub("AceLocale-3.0"):GetLocale("Carbonite")

local Assistant = {}
Carbonite.Modules = Carbonite.Modules or {}
Carbonite.Modules.Assistant = Assistant

-- Raise to show the assistant once more on every profile (a page that matters).
Assistant.VERSION = 1

-- Theme id of the dark choice (Carbonite/UI/Skin.lua).
local DARK_THEME = "Modern Dark"

-------------------------------------------------------------------------------
-- Pages
-------------------------------------------------------------------------------

Assistant.PAGES = {
    {
        id = "map",
        title = L["Which map opens with M?"],
        text = L["Carbonite has its own map: zoomable, with quests, routes and gathering nodes. It can take the M key in place of the game's world map."],
        choices = {
            { value = true, label = L["The Carbonite map"],
              desc = L["M opens the Carbonite map. Alt+M still opens the game's world map."] },
            { value = false, label = L["The game's world map"],
              desc = L["M keeps opening the game's world map. The Carbonite map stays in its own small window."] },
        },
    },
    {
        id = "minimap",
        title = L["Minimap"],
        text = L["The game minimap can become part of the Carbonite map, making one unified map whose minimap buttons go into Carbonite's button window."],
        choices = {
            { value = true, label = L["Inside the Carbonite map"],
              desc = L["One unified map. Takes effect after reloading the interface."] },
            { value = false, label = L["Keep the game's minimap"],
              desc = L["The game minimap stays where it is, apart from Carbonite."] },
        },
    },
    {
        id = "theme",
        title = L["Window look"],
        text = L["The look of every Carbonite window. Other themes and colors are in the Appearance options."],
        choices = {
            { value = "Blizzard", label = L["Blizzard"],
              desc = L["The game's own window look: stone background and gold border."] },
            { value = DARK_THEME, label = L["Dark"],
              desc = L["A dark, plain background with a thin border."] },
        },
    },
    {
        id = "givers",
        title = L["Quest givers on the map"],
        text = L["Carbonite marks on the map the characters who give quests. The Show menu of the map changes this later."],
        choices = {
            { value = true, label = L["Only quests I can take now"],
              desc = L["Hides givers of quests already done, in the log, locked or above your level."] },
            { value = false, label = L["All quest givers"],
              desc = L["Every quest giver of the zone, whatever the quest."] },
        },
    },
    {
        id = "navigator",
        title = L["Who guides you to the destination?"],
        text = L["Carbonite, TomTom or Shortest Path Forever can lead you to your destinations. The map, the quests and the destination list stay in Carbonite. Changing it takes a reload."],
        choices = {
            { value = "carbonite", label = "Carbonite",
              desc = L["Carbonite's arrow and route line. Guides that use TomTom (RestedXP, Zygor) send their destinations to Carbonite."] },
            { value = "tomtom", label = "TomTom", addon = "TomTom",
              desc = L["TomTom's arrow points to the current Carbonite destination. Carbonite still draws the route on its map."] },
            { value = "spf", label = "Shortest Path Forever", addon = "ShortestPathForever",
              desc = L["Plans the fastest route (flights, boats, portals, hearthstone) and guides with its own arrow and line."] },
        },
    },
    {
        id = "integrations",
        title = L["Integrations and shortcuts"],
        text = L["Carbonite works with these addons when they are installed and enabled:"],
    },
}

-- Companion addons: folder name, a global it creates (when it has one) and
-- what it adds to Carbonite. TomTom is only checked by name: without it,
-- Carbonite creates a TomTom global of its own.
Assistant.INTEGRATIONS = {
    { addon = "QuestieDB", global = "LibQuestieDB",
      what = L["Givers, turn-ins and objectives of the Forever quests Carbonite does not have."] },
    { addon = "Questie", global = "QuestieLoader",
      what = L["Questie's quest icons on the Carbonite map."] },
    { addon = "Spoken", global = "Spoken",
      what = L["A play button that narrates the quest text in the quest list."] },
    { addon = "ForeverDungeonJournal", global = "ForeverDungeonJournal_NS",
      what = L["Dungeon maps with their bosses in the map window inside dungeons."] },
    { addon = "GatherLite", global = "GatherLite",
      what = L["The herb, ore and treasure nodes of GatherLite on the Carbonite map."] },
    { addon = "TomTom",
      what = L["The destinations other addons send to TomTom go to Carbonite's arrow."] },
    { addon = "ShortestPathForever", global = "ShortestPathForever",
      what = L["The fastest route by time, with flights, boats, portals and the hearthstone, when chosen to guide."] },
    { addon = "MapUtils", global = "MAUTTAB",
      what = L["Ship and zeppelin departure times shared by other MapUtils players."] },
}

-------------------------------------------------------------------------------
-- Saved state
-------------------------------------------------------------------------------

local function profile()
    local Nx = _G.Nx
    return Nx and Nx.db and Nx.db.profile
end

-- A section of the profile, created when missing; nil before AceDB.
local function section(name)
    local p = profile()
    if not p then return nil end
    p[name] = p[name] or {}
    return p[name]
end

local function navigator()
    local integrations = Carbonite.Modules.Integrations
    return integrations and integrations.Navigator
end

--- The addon version the assistant is shown for: the TOC version of a
--- release, or the newest What's New entry on a development build.
function Assistant:CurrentVersion()
    local comm = Carbonite.Modules.Comm
    local check = comm and comm.VersionCheck
    local version = check and check.MyVersion and check:MyVersion()
    if version then return version end
    local whatsnew = _G.Nx and _G.Nx.Whatsnew
    if whatsnew and whatsnew.GetMaxTime then
        local ok, stamp = pcall(whatsnew.GetMaxTime, whatsnew)
        if ok and type(stamp) == "number" and stamp > 0 then return "dev-" .. stamp end
    end
    return nil
end

function Assistant:ShouldShow()
    local version = section("Version")
    if version == nil then return false end
    if (tonumber(version.Assistant) or 0) < self.VERSION then return true end
    -- Every new version of the addon opens it again (#222).
    local current = self:CurrentVersion()
    if current and version.AssistantSeen ~= current then return true end
    local nav = navigator()
    return nav ~= nil and nav:SavedUnavailable()
end

function Assistant:MarkSeen()
    local version = section("Version")
    if version then
        version.Assistant = self.VERSION
        version.AssistantSeen = self:CurrentVersion()
    end
end

--- A choice that can be picked: its addon (when it names one) is enabled.
function Assistant:ChoiceAvailable(id, value)
    if id ~= "navigator" then return true end
    local nav = navigator()
    return nav ~= nil and nav:Available(value)
end

-------------------------------------------------------------------------------
-- Choices: the same keys the options write
-------------------------------------------------------------------------------

local getters = {
    map = function() return section("Map").MaxOverride and true or false end,
    minimap = function() return section("MiniMap").Own and true or false end,
    theme = function()
        local name = section("Skin").Name
        return (name == nil or name == "") and "Blizzard" or name
    end,
    givers = function() return section("Map").QuestGiversAvailable and true or false end,
    navigator = function()
        local nav = navigator()
        return nav and nav:Saved() or "carbonite"
    end,
}

function Assistant:Get(id)
    local get = getters[id]
    if get and profile() then return get() end
end

local setters = {}

-- Options > Map and Minimap > Use Carbonite Map instead of Blizzards.
function setters.map(value)
    section("Map").MaxOverride = value
    local Map = _G.Nx.Map
    if Map and Map.ApplyMapKeyOverrides then Map:ApplyMapKeyOverrides() end
end

-- Options > Map and Minimap > Combine Blizzard Minimap with Carbonite
-- Minimap, with the companions Nx.Opts:NXCmdMMOwnChange sets. The reload it
-- asks for comes when the assistant ends (Finish).
function setters.minimap(value)
    local mm = section("MiniMap")
    mm.Own = value
    mm.ButOwn = value
    mm.ShowOldNameplate = not value
end

-- Options > Appearance > Current Skin.
function setters.theme(value)
    section("Skin").Name = value
    local Skin = _G.Nx.Skin
    if Skin and Skin.Set then Skin:Set(value) end
end

-- Map menu Show > Quest Givers: Only Available Quests.
function setters.givers(value)
    section("Map").QuestGiversAvailable = value
    local Map = _G.Nx.Map
    local map = Map and Map.Maps and Map.Maps[1]
    if map and map.Guide and map.Guide.UpdateGatherFolders then
        pcall(map.Guide.UpdateGatherFolders, map.Guide)
    end
end

-- Options > Tracking > Who guides you to the destination (#222/#223). The
-- reload it takes comes when the assistant ends (Finish).
function setters.navigator(value)
    local nav = navigator()
    if nav then nav:Set(value) end
end

function Assistant:Choose(id, value)
    local set = setters[id]
    if not set or not profile() then return end
    if not self:ChoiceAvailable(id, value) then return end
    set(value)
    if self.Render then self:Render() end
end

-------------------------------------------------------------------------------
-- Integrations
-------------------------------------------------------------------------------

local function addonLoaded(name)
    local Api = Carbonite.Compat and Carbonite.Compat.Api
    if Api and Api.AddOn and Api.AddOn.IsLoaded then
        local ok, loaded = pcall(Api.AddOn.IsLoaded, Api.AddOn, name)
        if ok and loaded then return true end
    end
    local C_AddOns = _G.C_AddOns
    if type(C_AddOns) == "table" and type(C_AddOns.IsAddOnLoaded) == "function" then
        return C_AddOns.IsAddOnLoaded(name) and true or false
    end
    return false
end

function Assistant:Integrations()
    local out = {}
    for _, item in ipairs(self.INTEGRATIONS) do
        local active = addonLoaded(item.addon) or (item.global ~= nil and rawget(_G, item.global) ~= nil)
        out[#out + 1] = { addon = item.addon, what = item.what, active = active and true or false }
    end
    return out
end

-------------------------------------------------------------------------------
-- Flow
-------------------------------------------------------------------------------

function Assistant:Open(page)
    if not profile() then return end
    if not self.active then
        self.active = true
        self.startMinimap = self:Get("minimap")
        self.startNavigator = self:Get("navigator")
    end
    self.page = math.max(1, math.min(tonumber(page) or 1, #self.PAGES))
    if not self.frame then self:Build() end
    self.frame:Show()
    self:Render()
end

function Assistant:AutoShow()
    if self:ShouldShow() and not self.active then
        self:Open(1)
        return true
    end
    return false
end

function Assistant:GoTo(page)
    self.page = math.max(1, math.min(page, #self.PAGES))
    self:Render()
end

--- End the assistant: mark it seen, close the window, ask to reload when
--- the minimap or navigator choice changed, then open the options when
--- asked to. What's New, when it waited (NXOnUpdate), opens after.
function Assistant:Finish(openOptions)
    if self.active then
        self.active = false
        -- A saved navigator whose addon is gone goes back to Carbonite, so
        -- the assistant does not ask again on every login.
        local nav = navigator()
        if nav and nav:SavedUnavailable() then nav:Set("carbonite") end
        self:MarkSeen()
        if self.frame then self.frame:Hide() end
        local minimapChanged = self.startMinimap ~= nil and self:Get("minimap") ~= self.startMinimap
        local navigatorChanged = self.startNavigator ~= nil and self:Get("navigator") ~= self.startNavigator
        if minimapChanged or navigatorChanged then
            local Opts = _G.Nx and _G.Nx.Opts
            if Opts and Opts.NXCmdReload then Opts:NXCmdReload() end
        end
        self.startMinimap = nil
        self.startNavigator = nil
        local after = self.afterFinish
        self.afterFinish = nil
        if after then after() end
    end
    if openOptions then
        local Options = Carbonite.GetModule and Carbonite:GetModule("Options", true)
        if Options and Options.Open then
            Options:Open()
        elseif _G.Nx and _G.Nx.Opts and _G.Nx.Opts.Open then
            _G.Nx.Opts:Open()
        end
    end
end

function Assistant:Skip()
    self:Finish(false)
end

-------------------------------------------------------------------------------
-- Window
-------------------------------------------------------------------------------

local WIDTH, HEIGHT = 540, 480
local TEXT_W = WIDTH - 48

local function fontString(parent, font, width)
    local fs = parent:CreateFontString(nil, "OVERLAY", font)
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("TOP")
    if width then
        fs:SetWidth(width)
        if fs.SetWordWrap then fs:SetWordWrap(true) end
    end
    return fs
end

local function button(parent, text, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(130, 24)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end

local function applySkin(frame)
    local Skin = Carbonite.UI and Carbonite.UI.Skin
    if Skin and Skin.Apply then
        Skin:Apply(frame)
    elseif frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
    end
end

function Assistant:Build()
    local template = _G.BackdropTemplateMixin and "BackdropTemplate" or nil
    local f = CreateFrame("Frame", "CarboniteAssistant", UIParent, template)
    self.frame = f
    f:SetSize(WIDTH, HEIGHT)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetScript("OnHide", function() Assistant:Finish(false) end)
    applySkin(f)
    -- The theme page previews the choice on this window too.
    Carbonite.Core.EventBus:Subscribe("SKIN_UPDATED", function() applySkin(f) end)
    tinsert(_G.UISpecialFrames, "CarboniteAssistant")

    -- Title strip, painted with the theme's tab bar color.
    local strip = f:CreateTexture(nil, "ARTWORK")
    strip:SetPoint("TOPLEFT", 6, -6)
    strip:SetPoint("TOPRIGHT", -6, -6)
    strip:SetHeight(24)
    local Skin = Carbonite.UI and Carbonite.UI.Skin
    if Skin and Skin.Paint then Skin:Paint(strip, "tabBarBg") else strip:SetColorTexture(0, 0, 0, 0.5) end

    self.titleText = fontString(f, "GameFontNormal")
    self.titleText:SetPoint("LEFT", strip, "LEFT", 8, 0)

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)
    close:SetScript("OnClick", function() f:Hide() end)

    self.heading = fontString(f, "GameFontNormalLarge", TEXT_W)
    self.heading:SetPoint("TOPLEFT", 24, -44)
    self.body = fontString(f, "GameFontHighlight", TEXT_W)
    self.body:SetPoint("TOPLEFT", self.heading, "BOTTOMLEFT", 0, -10)

    -- Choice rows: a check button used as a radio, its label and text.
    self.rows = {}
    local rows = 2
    for _, page in ipairs(self.PAGES) do
        rows = math.max(rows, page.choices and #page.choices or 0)
    end
    for i = 1, rows do
        local check = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
        check:SetSize(26, 26)
        check:SetScript("OnClick", function()
            local page = Assistant.PAGES[Assistant.page]
            local choice = page.choices and page.choices[i]
            if choice then Assistant:Choose(page.id, choice.value) end
        end)
        local label = fontString(f, "GameFontNormal", TEXT_W - 34)
        label:SetPoint("TOPLEFT", check, "TOPRIGHT", 4, -5)
        local desc = fontString(f, "GameFontHighlightSmall", TEXT_W - 34)
        desc:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -3)
        self.rows[i] = { check = check, label = label, desc = desc }
    end

    -- Integrations page: one line per addon, then the shortcuts.
    self.lines = {}
    for i = 1, #self.INTEGRATIONS do
        local line = fontString(f, "GameFontHighlightSmall", TEXT_W)
        line:SetPoint("TOPLEFT", i == 1 and self.body or self.lines[i - 1], "BOTTOMLEFT", 0, i == 1 and -10 or -5)
        self.lines[i] = line
    end
    self.shortcuts = fontString(f, "GameFontHighlightSmall", TEXT_W)
    self.shortcuts:SetPoint("TOPLEFT", self.lines[#self.lines], "BOTTOMLEFT", 0, -14)

    -- A note under the choices (navigator page).
    self.note = fontString(f, "GameFontHighlightSmall", TEXT_W)

    -- Footer.
    self.skipBut = button(f, L["Skip"], function() Assistant:Skip() end)
    self.skipBut:SetPoint("BOTTOMLEFT", 16, 14)
    self.nextBut = button(f, L["Next"], function() Assistant:GoTo(Assistant.page + 1) end)
    self.nextBut:SetPoint("BOTTOMRIGHT", -16, 14)
    self.backBut = button(f, L["Back"], function() Assistant:GoTo(Assistant.page - 1) end)
    self.backBut:SetPoint("RIGHT", self.nextBut, "LEFT", -8, 0)
    self.doneBut = button(f, L["Done"], function() Assistant:Finish(false) end)
    self.doneBut:SetPoint("BOTTOMRIGHT", -16, 14)
    self.optionsBut = button(f, L["Open options"], function() Assistant:Finish(true) end)
    self.optionsBut:SetPoint("RIGHT", self.doneBut, "LEFT", -8, 0)
end

local function shown(widget, show)
    if show then widget:Show() else widget:Hide() end
end

function Assistant:Render()
    if not self.frame or not self.frame:IsShown() then return end
    local count = #self.PAGES
    local page = self.PAGES[self.page]
    self.titleText:SetFormattedText(L["Carbonite-Forever setup - step %d of %d"], self.page, count)
    self.heading:SetText(page.title)
    self.body:SetText(page.text)

    local current = self:Get(page.id)
    for i, row in ipairs(self.rows) do
        local choice = page.choices and page.choices[i]
        shown(row.check, choice)
        shown(row.label, choice)
        shown(row.desc, choice)
        if choice then
            row.check:ClearAllPoints()
            if i == 1 then
                row.check:SetPoint("TOPLEFT", self.body, "BOTTOMLEFT", 0, -14)
            else
                -- Under the previous row's text, back at the left edge (check
                -- width plus gap).
                row.check:SetPoint("TOPLEFT", self.rows[i - 1].desc, "BOTTOMLEFT", -30, -10)
            end
            row.check:SetChecked(current == choice.value)
            local available = self:ChoiceAvailable(page.id, choice.value)
            if available then
                row.check:Enable()
                row.label:SetText(choice.label)
                row.desc:SetText(choice.desc)
            else
                row.check:Disable()
                row.label:SetText(("|cff909090%s (%s)|r"):format(choice.label, L["Not installed"]))
                row.desc:SetText("|cff909090" .. choice.desc .. "|r")
            end
        end
    end

    -- Shortest Path Forever follows some guides by itself: with another
    -- navigator there would be two arrows.
    local note = self:Note(page.id)
    shown(self.note, note)
    if note then
        local lastRow
        for i, row in ipairs(self.rows) do
            if page.choices and page.choices[i] then lastRow = row end
        end
        self.note:ClearAllPoints()
        self.note:SetPoint("TOPLEFT", lastRow and lastRow.desc or self.body, "BOTTOMLEFT", lastRow and -30 or 0, -14)
        self.note:SetText(note)
    end

    local integrations = page.id == "integrations"
    local found = integrations and self:Integrations() or {}
    for i, line in ipairs(self.lines) do
        shown(line, integrations)
        if integrations then
            local item = found[i]
            local state = item.active and ("|cff40ff40" .. L["Active"] .. "|r")
                or ("|cff909090" .. L["Not installed"] .. "|r")
            line:SetText(("|cffffd200%s|r (%s): %s"):format(item.addon, state, item.what))
        end
    end
    shown(self.shortcuts, integrations)
    if integrations then
        self.shortcuts:SetText(L["Shortcuts: M opens the map, Alt+M the game's world map, /carb lists the commands and /carb assistente opens this assistant again."])
    end

    local last = self.page == count
    shown(self.backBut, self.page > 1)
    shown(self.nextBut, not last)
    shown(self.doneBut, last)
    shown(self.optionsBut, last)
    -- On the last page "Back" sits left of "Open options" (it was anchored to
    -- the hidden "Next" and landed on top of it); "Skip" makes room, "Done"
    -- ends the assistant the same way.
    shown(self.skipBut, not last)
    self.backBut:ClearAllPoints()
    self.backBut:SetPoint("RIGHT", last and self.optionsBut or self.nextBut, "LEFT", -8, 0)
end

--- The note under a page's choices, or nil.
function Assistant:Note(id)
    if id ~= "navigator" then return nil end
    local nav = navigator()
    if nav and nav:SPFEnabled() and self:Get("navigator") ~= "spf" then
        return "|cffffd200" .. L["Shortest Path Forever keeps following RestedXP and Guidelime by itself. For a single arrow, turn that off in its options or choose it here."] .. "|r"
    end
    return nil
end

-------------------------------------------------------------------------------
-- /carb assistente
-------------------------------------------------------------------------------

local Slash = Carbonite.Core and Carbonite.Core.SlashCommands
if Slash then
    Slash:Register("assistente", function() Assistant:Open(1) end, "open the setup assistant")
    Slash:Register("setup", function() Assistant:Open(1) end)
end
