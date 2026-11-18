-- Warehouse: the item list in collapsible sections, professions listed once (#100)

-- List stand-in that keeps every row: user data, column texts and extended data.
local function fakeList()
    local list = { rows = {} }
    function list:Empty() self.rows = {} end
    function list:ItemAdd(data) self.rows[#self.rows + 1] = { data = data, cols = {}, ex = {} } end
    function list:ItemGetNum() return #self.rows end
    function list:ItemSet(col, str, index) self.rows[index or #self.rows].cols[col] = str end
    function list:ItemSetDataEx(index, data, num) self.rows[index or #self.rows].ex[num] = data end
    function list:ItemGetDataEx(index, num) return self.rows[index].ex[num] end
    function list:ItemGetData(index) return self.rows[index].data end
    function list:ItemSetButton() end
    function list:ItemGetButtonTip() end
    function list:ColumnSetName() end
    function list:Update() end
    function list:Select() end
    return list
end

local function split(sep, str)
    local out, pos = {}, 1
    while true do
        local s, e = string.find(str, sep, pos, true)
        if not s then out[#out + 1] = string.sub(str, pos); break end
        out[#out + 1] = string.sub(str, pos, s - 1)
        pos = e + 1
    end
    return unpack(out)
end

local ITEMS = {
    [101] = { "Espada Velha", "Arma" },
    [102] = { "Poção de Cura", "Consumível" },
    [103] = { "Minério de Cobre", "Material" },
    [104] = { "Carta do Banco", "Material" },
    [105] = { "Pergaminho Enviado", "Consumível" },
}

local function link(id) return "|Hitem:" .. id .. "|h[" .. ITEMS[id][1] .. "]|h" end

local function setup()
    local character = {
        Level = 80, Class = "WARRIOR", Money = 0, TimePlayed = 0,
        WareInv = { "MainHandSlot^" .. link(101) },
        WareBags = { ["Poção de Cura"] = "3^" .. link(102), ["Minério de Cobre"] = "20^" .. link(103) },
        WareBank = { ["Carta do Banco"] = "1^" .. link(104) },
        WareMail = { ["Pergaminho Enviado"] = "2^" .. link(105) },
        Profs = { ["Mineração"] = { Rank = 75, MaxRank = 150 } },
    }
    local Nx = wow.namespace({
        isRetail = false,
        MaxPlayerLevel = 80,
        RealmChars = { "Reino.Alice" },
        wdb = {
            global = { Characters = { ["Reino.Alice"] = character } },
            -- Sections open, as the #100 cases below expect; #202 folds some by default.
            profile = { Warehouse = { ShowGold = false,
                CollapsedSections = { Equipped = false, Bags = false, Bank = false } } },
        },
        Split = split,
        Item = { Load = function() end },
        SearchBox = wow.searchBox(),
        Util_GetMoneyStr = function() return "0" end,
        Util_GetTimeElapsedStr = function() return "1 min" end,
        prt = function() end,
    })
    Nx.Warehouse = {
        API = {
            HasAccountBank = function() return false end,
            GetItemInfo = function(l)
                local id = tonumber(string.match(tostring(l), "item:(%d+)"))
                local item = ITEMS[id]
                if item then return item[1], l, 1, 10, 1, item[2] end
            end,
        },
    }
    local env = wow.lenientEnv({
        Nx = Nx, sort = table.sort, strupper = string.upper, strtrim = function(s) return s end,
        time = os.time, difftime = os.difftime, UnitName = function() return "Bob" end,
        UnitLevel = function() return 80 end, ITEM_QUALITY_COLORS = {}, ARMOR = "Armadura",
    })
    loader.run(env, "Carbonite.Warehouse/Engine.lua", "Carbonite.Warehouse", {})

    local W = Nx.Warehouse
    W.Win = { SetTitle = function() end }
    W.ClassIcons = {}
    W.List, W.ItemList = fakeList(), fakeList()
    W.EditBox = { text = "", GetText = function(self) return self.text end }
    W.ItemTypes = { "Arma", "Consumível", "Material" }
    W.ShowItemCategory = true
    W.NXRarityMin, W.NXEqRarityMin = 0, 0
    W.CurCharacter = character
    W.SelectedChar = 1
    return W, Nx
end

local function sections(list)
    local keys = {}
    for _, row in ipairs(list.rows) do
        if row.ex[1] then keys[#keys + 1] = row.ex[1] end
    end
    return keys
end

local function headerIndex(list, key)
    for i, row in ipairs(list.rows) do
        if row.ex[1] == key then return i end
    end
end

local function count(list, text)
    local n = 0
    for _, row in ipairs(list.rows) do
        for _, str in pairs(row.cols) do
            if string.find(str, text, 1, true) then n = n + 1 end
        end
    end
    return n
end

describe("Warehouse em seções", function()
    it("lista as seções na ordem, com o resumo no topo", function()
        local W = setup()
        W:UpdateItems()
        expect(table.concat(sections(W.ItemList), ",")).toBe("Summary,Equipped,Bags,Bank,Mail,Professions")
        expect(headerIndex(W.ItemList, "Summary")).toBe(1)
    end)

    it("põe cada item na seção do lugar onde está", function()
        local W = setup()
        W:UpdateItems()
        local function within(key, text)
            local list, first = W.ItemList, headerIndex(W.ItemList, key)
            for i = first + 1, #list.rows do
                if list.rows[i].ex[1] then return false end
                if string.find(list.rows[i].cols[3] or "", text, 1, true) then return true end
            end
            return false
        end
        expect(within("Equipped", "Espada Velha")).toBe(true)
        expect(within("Bags", "Minério de Cobre")).toBe(true)
        expect(within("Bank", "Carta do Banco")).toBe(true)
        expect(within("Mail", "Pergaminho Enviado")).toBe(true)
        expect(within("Professions", "Mineração")).toBe(true)
    end)

    it("recolher pelo clique no cabeçalho esconde as linhas da seção e fica guardado", function()
        local W, Nx = setup()
        W.Update = function(self) self:UpdateItems() end
        W:UpdateItems()
        W:OnItemListEvent("select", headerIndex(W.ItemList, "Bags"), 0)
        expect(Nx.wdb.profile.Warehouse.CollapsedSections.Bags).toBe(true)
        expect(count(W.ItemList, "Minério de Cobre")).toBe(0)
        expect(count(W.ItemList, "Poção de Cura")).toBe(0)
        expect(headerIndex(W.ItemList, "Bank")).toBe(headerIndex(W.ItemList, "Bags") + 1)
        expect(count(W.ItemList, "Carta do Banco")).toBe(1)

        W:OnItemListEvent("select", headerIndex(W.ItemList, "Bags"), 0)
        expect(Nx.wdb.profile.Warehouse.CollapsedSections.Bags).toBe(false)
        expect(count(W.ItemList, "Minério de Cobre")).toBe(1)
    end)

    it("a busca abre as seções recolhidas", function()
        local W, Nx = setup()
        Nx.wdb.profile.Warehouse.CollapsedSections = { Bags = true }
        W.EditBox.text = "cobre"
        W:UpdateItems()
        expect(count(W.ItemList, "Minério de Cobre")).toBe(1)
    end)

    it("mostra as profissões uma vez só", function()
        local W = setup()
        W:Update()
        expect(count(W.List, "Mineração") + count(W.ItemList, "Mineração")).toBe(1)
    end)

    it("clicar na profissão abre as receitas dela", function()
        local W = setup()
        local opened
        W.Update = function(self) opened = self.SelectedProf end
        W:UpdateItems()
        local row
        for i, r in ipairs(W.ItemList.rows) do
            if r.ex[2] then row = i end
        end
        W:OnItemListEvent("select", row, 0)
        expect(opened).toBe("Mineração")
        expect(W.SelectedChar).toBe(1)
    end)

    it("os títulos das seções têm tradução pt-BR", function()
        local pt = loader.read("Carbonite.Warehouse/Locales/ptBR.lua")
        for _, key in ipairs({ "Summary", "Equipped", "Bags", "Bank", "Mail", "Professions" }) do
            expect(pt:find('L["' .. key .. '"]', 1, true) ~= nil).toBe(true)
        end
    end)
end)
