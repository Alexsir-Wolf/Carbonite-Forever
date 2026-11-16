-- Carbonite.Notes | Integrations / Forever points
-- Two Forever additions on the Carbonite map (#82):
--   * library books: one pin per book, gone once its quest is turned in;
--     the name is the book item's, in the client language;
--   * convergences: for Skyborne characters, or for all with the option.
--
-- Data: MapUtils by D4KiR, GPL-3.0 like Carbonite (data/forever/
-- librarybooks.lua and the CONVERGENCES table of convergences.lua).
-- Coordinates are zone percent by uiMapID.

local Nx = _G.Nx
if not Nx then return end
Nx.Notes = Nx.Notes or {}
local L = LibStub("AceLocale-3.0"):GetLocale("Carbonite.Notes", true)

local BOOKS = {
    { item = 203755, quest = 79092, points = { { 1429, 65.4, 70.1 } } },
    { item = 203754, quest = 79091, points = { { 1455, 75.4, 11.0 } } },
    { item = 209845, quest = 78142, points = { { 1436, 45.4, 70.4 } } },
    { item = 208860, quest = 79093, points = { { 1432, 35.5, 48.3 } } },
    { item = 209849, quest = 78147, points = { { 1431, 16.4, 28.4 } } },
    { item = 209850, quest = 78148, points = { { 1432, 77.4, 14.0 } } },
    { item = 209848, quest = 78146, points = { { 1437, 33.6, 47.9 } } },
    { item = 209844, quest = 78127, points = { { 1421, 63.4, 63.1 } } },
    { item = 208185, quest = 79095, points = { { 1420, 59.4, 52.3 } } },
    { item = 210177, quest = 79096, points = { { 1421, 43.4, 41.2 } } },
    { item = 209843, quest = 78124, points = { { 1439, 59.6, 22.2 } } },
    { item = 209847, quest = 78145, points = { { 1413, 56.3, 8.8 } } },
    { item = 208800, quest = 79097, points = { { 1413, 62.7, 36.3 } } },
    { item = 209846, quest = 78143, points = { { 1413, 46.0, 36.5 } } },
    { item = 209851, quest = 78149, points = { { 1442, 74.4, 85.7 } } },
    { item = 207972, quest = 79094, points = { { 1454, 38.7, 78.4 } } },
    { item = 213165, quest = 79535, points = { { 1434, 41.4, 50.9 } } },
    { item = 215815, quest = 79948, points = { { 1416, 48.4, 57.7 } } },
    { item = 215816, quest = 79949, points = { { 1417, 73.6, 65.2 } } },
    { item = 215820, quest = 79951, points = { { 1418, 56.7, 39.9 } } },
    { item = 215683, quest = 79947, points = { { 1441, 34.4, 40.1 } } },
    { item = 215817, quest = 79950, points = { { 1443, 55.1, 26.2 } } },
    { item = 215822, quest = 79952, points = { { 1445, 57.2, 20.8 } } },
    { item = 220345, quest = 81947, points = { { 1435, 70.3, 51.7 } } },
    { item = 220349, quest = 81953, points = { { 1428, 29.1, 28.9 } } },
    { item = 220350, quest = 81954, points = { { 1425, 36.0, 72.8 } } },
    { item = 220352, quest = 81955, points = { { 1427, 37.8, 49.3 } } },
    { item = 220353, quest = 81956, points = { { 1419, 55.4, 32.2 } } },
    { item = 220346, quest = 81949, points = { { 1446, 72.6, 47.8 } } },
    { item = 220348, quest = 81952, points = { { 1447, 20.8, 62.0 } } },
    { item = 228132, quest = 84395, points = { { 1422, 38.2, 54.6 } } },
    { item = 228141, quest = 84402, points = { { 1422, 69.2, 72.4 } } },
    { item = 228135, quest = 84398, points = { { 1423, 71.8, 48.3 }, { 1423, 81.7, 57.8 } } },
    { item = 228138, quest = 84400, points = { { 1423, 47.2, 42.3 }, { 1423, 54.4, 51.1 } } },
    { item = 228140, quest = 84401, points = { { 1423, 31.2, 21.0 } } },
    { item = 228133, quest = 84396, points = { { 1428, 26.2, 22.4 } } },
    { item = 228134, quest = 84397, points = { { 1448, 65.2, 3.3 } } },
    { item = 228136, quest = 84399, points = { { 1452, 60.7, 37.7 } } },
}

-- uiMapID -> { x1, y1, x2, y2, ... }
local CONVERGENCES = {
    [1411] = { 45.12, 15.75 },
    [1412] = { 38.59, 44.74, 50.24, 53.55, 51.98, 34.17 },
    [1413] = { 43.57, 42.09, 46.97, 80.25, 50.86, 14.55, 54.61, 14.86 },
    [1417] = { 25.44, 30.01, 52.05, 50.68, 68.33, 30.42 },
    [1420] = { 49.24, 63.87 },
    [1421] = { 49.36, 52.77, 56.21, 10.05, 61.25, 79.35 },
    [1424] = { 60.27, 10.64, 72.94, 63.57, 80.76, 45.33, 89.08, 58.77 },
    [1432] = { 27.50, 52.07, 58.99, 36.59 },
    [1434] = { 13.35, 15.02 },
    [1436] = { 34.82, 73.09, 41.60, 82.01, 59.67, 36.22 },
    [1437] = { 54.06, 26.88 },
    [1439] = { 58.42, 19.77 },
    [1440] = { 60.00, 63.04, 76.31, 67.52, 86.07, 58.67, 89.40, 49.78 },
    [1442] = { 80.84, 90.52 },
}

local BOOK_ICON = "Interface\\Icons\\INV_Misc_Book_09"
local CONVERGENCE_ICON = "Interface\\Icons\\Spell_Nature_EarthElemental_Totem"

local function Done(quest)
    local log = _G.C_QuestLog
    return log and log.IsQuestFlaggedCompleted and log.IsQuestFlaggedCompleted(quest) or false
end

local function BookName(item)
    local items = _G.C_Item
    local name = items and items.GetItemNameByID and items.GetItemNameByID(item)
    if not name and items and items.RequestLoadItemDataByID then
        items.RequestLoadItemDataByID(item)
    end
    return name or L["Library book"]
end

local function Skyborne()
    local _, race = UnitRace("player")
    return race == "Skyborne"
end

--- Books still to find on a map: { x, y, name } each.
function Nx.Notes:LibraryBooksOn(mapId)
    local out = {}
    for _, book in ipairs(BOOKS) do
        if not Done(book.quest) then
            for _, p in ipairs(book.points) do
                if p[1] == mapId then
                    out[#out + 1] = { p[2], p[3], BookName(book.item) }
                end
            end
        end
    end
    return out
end

--- Whether convergences show for this character.
function Nx.Notes:ShowsConvergences()
    local notes = Nx.fdb.profile.Notes
    return notes.Convergences and (Skyborne() or notes.ConvergencesAll) or false
end

function Nx.Notes:ForeverPoints(mapId)
    local map = Nx.Map:GetMap(1)
    if not map or not mapId then return end
    local notes = Nx.fdb.profile.Notes
    local books = notes.LibraryBooks and self:LibraryBooksOn(mapId) or {}
    local conv = self:ShowsConvergences() and CONVERGENCES[mapId] or nil
    local sig = ("%d:%d:%d"):format(mapId, #books, conv and #conv or 0)
    for _, b in ipairs(books) do sig = sig .. b[3] end
    if sig == self.FPLastSig then return end
    self.FPLastSig = sig

    map:ClearIconType("!FVB")
    map:InitIconType("!FVB", "WP", "", 18, 18)
    map:SetIconTypeChop("!FVB", true)
    map:SetIconTypeLevel("!FVB", 10)
    for _, b in ipairs(books) do
        local wx, wy = Nx.Map:GetWorldPos(mapId, b[1], b[2])
        local pin = wx and wy and map:AddIconPt("!FVB", wx, wy, nil, nil, BOOK_ICON)
        if pin then
            map:SetIconTip(pin, ("%s\n|cffffd200%s|r"):format(L["Library book"], b[3]))
        end
    end

    map:ClearIconType("!FVC")
    map:InitIconType("!FVC", "WP", "", 16, 16)
    map:SetIconTypeChop("!FVC", true)
    map:SetIconTypeLevel("!FVC", 10)
    for i = 1, conv and #conv or 0, 2 do
        local wx, wy = Nx.Map:GetWorldPos(mapId, conv[i], conv[i + 1])
        local pin = wx and wy and map:AddIconPt("!FVC", wx, wy, nil, nil, CONVERGENCE_ICON)
        if pin then map:SetIconTip(pin, L["Convergence"]) end
    end
end

-- Turning in a book's quest, or learning a book's name, redraws.
local frame = CreateFrame("Frame")
frame:RegisterEvent("QUEST_TURNED_IN")
frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
frame:SetScript("OnEvent", function() Nx.Notes.FPLastSig = nil end)
