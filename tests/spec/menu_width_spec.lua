-- Nx.Menu:FitWidth (Carbonite/Modules/UI/UIEngine.lua): the menu widens to its longest item

-- Runs only the FitWidth block of UIEngine.lua, against fake frames.
local function fitWidth()
    local src = loader.read("Carbonite/Modules/UI/UIEngine.lua")
    local first = src:find("local MENU_TEXT_X", 1, true)
    local last = src:find("function Nx.Menu:Update", first, true)
    local env = { Nx = { Menu = {} }, max = math.max, ceil = math.ceil, ipairs = ipairs }
    local chunk = assert(loadstring(src:sub(first, last - 1)))
    setfenv(chunk, env)
    chunk()
    return env.Nx.Menu.FitWidth
end

-- 6 px per character stands in for the font.
local function fontString()
    local fs = { text = "" }
    function fs:SetFontObject() end
    function fs:Hide() end
    function fs:SetText(t) self.text = t end
    function fs:GetStringWidth() return #self.text * 6 end
    function fs:SetWidth(w) self.width = w end
    return fs
end

local function menu(width, texts)
    local m = { Width = width, Items = {}, MainFrm = { CreateFontString = fontString } }
    for _, t in ipairs(texts) do
        local item = { Text = t, ShowState = 1, Frm = { SetWidth = function(f, w) f.width = w end },
            TextFStr = fontString() }
        m.Items[#m.Items + 1] = item
    end
    return m
end

describe("largura do menu", function()
    local FitWidth = fitWidth()

    it("alarga o menu para caber o item mais longo", function()
        local m = menu(240, { "Curto", string.rep("x", 50) })   -- 300 px de texto
        local w = FitWidth(m, 14)
        expect(w).toBe(300 + 20 + 28 + 4)
        expect(m.CurWidth).toBe(w)
        expect(m.Items[2].TextFStr.width).toBe(w - 28 - 20)
        expect(m.Items[2].Frm.width).toBe(w - 28)
    end)

    it("mantém a largura de criação quando tudo cabe", function()
        expect(FitWidth(menu(240, { "Curto" }), 14)).toBe(240)
    end)

    it("ignora itens escondidos", function()
        local m = menu(240, { string.rep("x", 50) })
        m.Items[1].ShowState = false
        expect(FitWidth(m, 14)).toBe(240)
    end)
end)
