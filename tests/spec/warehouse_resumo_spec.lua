-- Warehouse: sections folded by default, bag slot translated, readable realm
-- name and a character pane only as wide as it needs (#202)

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
    function list:ItemSetSection(open) self.rows[#self.rows].section = open end
    function list:UsesSectionBars() return false end
    function list:ColumnSetName() end
    function list:Update() end
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
    [104] = { "Carta do Banco", "Material" },
    [105] = { "Pergaminho Enviado", "Consumível" },
    [106] = { "Mochila", "Recipiente" },
}

local function link(id) return "|Hitem:" .. id .. "|h[" .. ITEMS[id][1] .. "]|h" end

local REALM = "CAMWOW US1 Realm 5 PvE"

local function setup(globals, warehouseOpts)
    local character = {
        Level = 80, Class = "WARRIOR", Money = 0, TimePlayed = 0,
        WareInv = { "MainHandSlot^" .. link(101), "Bag0Slot^" .. link(106) },
        WareBags = { ["Poção de Cura"] = "3^" .. link(102) },
        WareBank = { ["Carta do Banco"] = "1^" .. link(104) },
        WareMail = { ["Pergaminho Enviado"] = "2^" .. link(105) },
    }
    local rc = REALM .. ".Alice"
    local opts = warehouseOpts or {}
    opts.ShowGold = false
    local Nx = wow.namespace({
        isRetail = false,
        MaxPlayerLevel = 80,
        RealmChars = { rc },
        wdb = {
            global = { Characters = { [rc] = character } },
            profile = { Warehouse = opts },
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
    local overrides = {
        Nx = Nx, sort = table.sort, strupper = string.upper, strtrim = function(s) return s end,
        time = os.time, difftime = os.difftime, UnitName = function() return "Bob" end,
        UnitLevel = function() return 80 end, ITEM_QUALITY_COLORS = {}, ARMOR = "Armadura",
        MAINHANDSLOT = "Mão Principal",
    }
    for k, v in pairs(globals or {}) do overrides[k] = v end
    local env = wow.lenientEnv(overrides, { "BAGSLOT", "BAG0SLOT" })
    loader.run(env, "Carbonite.Warehouse/Engine.lua", "Carbonite.Warehouse", {})

    local W = Nx.Warehouse
    W.Win = { SetTitle = function() end }
    W.ClassIcons = {}
    W.List, W.ItemList = fakeList(), fakeList()
    W.EditBox = { text = "", GetText = function(self) return self.text end }
    W.ItemTypes = { "Arma", "Consumível", "Material", "Recipiente" }
    W.NXRarityMin, W.NXEqRarityMin = 0, 0
    W.CurCharacter = character
    W.SelectedChar = 1
    return W, Nx
end

local function headerIndex(list, key)
    for i, row in ipairs(list.rows) do
        if row.ex[1] == key then return i end
    end
end

-- Rows listed under a section header, up to the next header.
local function rowsOf(list, key)
    local out, first = {}, headerIndex(list, key)
    for i = first + 1, #list.rows do
        if list.rows[i].ex[1] then break end
        out[#out + 1] = list.rows[i].cols[3] or ""
    end
    return out
end

local function anyRow(rows, text)
    for _, str in ipairs(rows) do
        if string.find(str, text, 1, true) then return true end
    end
    return false
end

describe("Armazém: resumo e seções recolhidas (#202)", function()
    it("abre com o resumo no topo e Equipado, Bolsas e Banco recolhidos", function()
        local W = setup()
        W:UpdateItems()
        expect(headerIndex(W.ItemList, "Summary")).toBe(1)
        expect(#rowsOf(W.ItemList, "Summary") > 0).toBe(true)
        expect(#rowsOf(W.ItemList, "Equipped")).toBe(0)
        expect(#rowsOf(W.ItemList, "Bags")).toBe(0)
        expect(#rowsOf(W.ItemList, "Bank")).toBe(0)
        expect(anyRow(rowsOf(W.ItemList, "Mail"), "Pergaminho Enviado")).toBe(true)
    end)

    it("o cabeçalho recolhido ainda mostra a contagem", function()
        local W = setup()
        W:UpdateItems()
        local header = W.ItemList.rows[headerIndex(W.ItemList, "Bags")].cols[3]
        expect(string.find(header, "(1)", 1, true) ~= nil).toBe(true)
    end)

    it("abrir uma seção recolhida por padrão fica guardado como aberta", function()
        local W, Nx = setup()
        W.Update = function(self) self:UpdateItems() end
        W:UpdateItems()
        W:OnItemListEvent("select", headerIndex(W.ItemList, "Bags"), 0)
        expect(Nx.wdb.profile.Warehouse.CollapsedSections.Bags).toBe(false)
        expect(anyRow(rowsOf(W.ItemList, "Bags"), "Poção de Cura")).toBe(true)

        W:OnItemListEvent("select", headerIndex(W.ItemList, "Bags"), 0)
        expect(Nx.wdb.profile.Warehouse.CollapsedSections.Bags).toBe(true)
        expect(#rowsOf(W.ItemList, "Bags")).toBe(0)
    end)

    it("a busca ainda abre as seções recolhidas por padrão", function()
        local W = setup()
        W.EditBox.text = "cura"
        W:UpdateItems()
        expect(anyRow(rowsOf(W.ItemList, "Bags"), "Poção de Cura")).toBe(true)
    end)
end)

describe("Armazém: textos traduzidos (#202)", function()
    it("a bolsa equipada usa o nome do cliente (BAGSLOT), não \"Bag\"", function()
        local W = setup({ BAGSLOT = "Bolsa" }, { CollapsedSections = { Equipped = false } })
        W:UpdateItems()
        local rows = rowsOf(W.ItemList, "Equipped")
        expect(anyRow(rows, "Bolsa - ")).toBe(true)
        expect(anyRow(rows, "Bag - ")).toBe(false)
        expect(anyRow(rows, "Mão Principal - ")).toBe(true)
    end)

    it("sem BAGSLOT no cliente, a bolsa usa o texto do locale", function()
        local W = setup(nil, { CollapsedSections = { Equipped = false } })
        W:UpdateItems()
        expect(anyRow(rowsOf(W.ItemList, "Equipped"), "Bag - ")).toBe(true)
        local pt = loader.read("Carbonite.Warehouse/Locales/ptBR.lua")
        expect(pt:find('L["Bag"] = "Bolsa"', 1, true) ~= nil).toBe(true)
        local en = loader.read("Carbonite.Warehouse/Locales/enUS.lua")
        expect(en:find('L["Bag"] = true', 1, true) ~= nil).toBe(true)
    end)

    it("o reino aparece sem a etiqueta do servidor e com o tipo entre parênteses", function()
        local W = setup()
        local label = W.RealmLabel(REALM)
        expect(label:find("CAMWOW", 1, true)).toBeNil()
        expect(label:find("Realm 5", 1, true) ~= nil).toBe(true)
        expect(label:find("(PvE)", 1, true) ~= nil).toBe(true)

        W:Update()
        local found = false
        for _, row in ipairs(W.List.rows) do
            local str = row.cols[2] or ""
            if str:find("Realm 5", 1, true) then found = true end
            expect(str:find("CAMWOW", 1, true)).toBeNil()
        end
        expect(found).toBe(true)
    end)

    it("nomes de reino comuns ficam como estão", function()
        local W = setup()
        expect(W.RealmLabel("Azralon")).toBe("Azralon")
        expect(W.RealmLabel("Area 52")).toBe("Area 52")
    end)
end)

describe("Armazém: largura do painel de personagens (#202)", function()
    -- Window, lists and a measuring font string where every character is 7 px.
    local function layout(W, winW)
        local attached = {}
        local frm = {
            GetWidth = function() return winW end,
            CreateFontString = function()
                local fs = { text = "" }
                function fs.Hide() end
                function fs.SetFontObject() end
                function fs.SetText(self, t) self.text = t end
                function fs.GetStringWidth(self) return #self.text * 7 end
                return fs
            end,
        }
        W.Win = {
            Frm = frm, BorderW = 0, SetTitle = function() end,
            Attach = function(_, f, x1, x2) attached[f] = { x1, x2 } end,
        }
        W.List.Frm, W.ItemList.Frm = "chars", "items"
        W.EditBox.Frm = "search"
        W.List.Columns = { [2] = { Data = {} } }
        return attached, W.List.Columns[2].Data
    end

    it("ocupa a largura da linha mais longa e o resto vai para os itens", function()
        local W = setup()
        local attached, data = layout(W, 1600)
        data[1] = string.rep("x", 40)    -- 280 px
        data[2] = "curta"
        W:FitCharPane()
        expect(attached.chars[2]).toBe(280 + 56)
        expect(attached.items[1]).toBe(280 + 56)
        expect(attached.items[2]).toBe(1)
        expect(attached.search[1]).toBe(280 + 56)
    end)

    it("não passa de 40% da janela nem fica abaixo do mínimo", function()
        local W = setup()
        local attached, data = layout(W, 1000)
        data[1] = string.rep("x", 200)
        W:FitCharPane()
        expect(attached.chars[2]).toBe(400)

        W = setup()
        attached, data = layout(W, 1000)
        data[1] = "x"
        W:FitCharPane()
        expect(attached.chars[2]).toBe(200)
    end)
end)
