-- Guide: labels without double spaces, Distance and Zone columns, default
-- width and a game-style Back button (#200)

local function split(sep, s)
    local out = {}
    for part in (s .. sep):gmatch("(.-)" .. sep:gsub("%p", "%%%0")) do out[#out + 1] = part end
    return unpack(out)
end

local function guide()
    local env = wow.lenientEnv()
    env.gmatch = string.gmatch
    env.strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
    env.strbyte = string.byte
    env.UnitFactionGroup = function() return "Alliance" end
    env.Nx = wow.namespace({ Map = wow.namespace({ Guide = {} }), db = { char = { Map = {} } } })
    env.Nx.Split = split
    loader.run(env, "Carbonite/Data/Shared/NxMapGuide.lua")
    return env.Nx.Map.Guide, env
end

-- Two continents: map 1 on continent 1, map 2 on continent 2. World pos is x, y doubled.
local function fakeMap()
    return {
        PlyrX = 100, PlyrY = 100, UpdateMapID = 1,
        IdToContZone = function(_, id) return id == 2 and 2 or 1 end,
        GetWorldPos = function(_, _, x, y) return x * 2, y * 2 end,
    }
end

local function fakeList()
    local l = { rows = {}, names = {} }
    function l:Empty() self.rows = {} end
    function l:ItemAdd() self.rows[#self.rows + 1] = {} end
    function l:ItemSet(col, v) self.rows[#self.rows][col] = v end
    function l:ItemSetButton() end
    function l:ColumnSetName(id, name) self.names[id] = name end
    function l:Update() end
    return l
end

describe("Guia (#200)", function()
    it("rótulos do locale não ficam com espaço duplo", function()
        local G = guide()
        expect(G.SplitCaps("Mestre de Estábulo")).toBe("Mestre de Estábulo")
        expect(G.SplitCaps("Caixa de Correio")).toBe("Caixa de Correio")
        expect(G.SplitCaps("Stable Master")).toBe("Stable Master")
        expect(G.SplitCaps("StableMaster")).toBe("Stable Master")
    end)

    it("PatchFolder dá nomes sem espaço duplo às categorias", function()
        local G = guide()
        local root = { Name = "All", Tx = "x", { T = "Curandeiro Espiritual" }, { T = "Pedra de Encontro" } }
        G:PatchFolder(root, nil)
        expect(root[1].Name).toBe("Curandeiro Espiritual")
        expect(root[2].Name).toBe("Pedra de Encontro")
    end)

    it("acha o ponto mais perto no continente do jogador, sem a facção oculta", function()
        local G, env = guide()
        env.Nx.GuideData = { Banker = {
            Mode = 32,
            [1] = "1,10,10|0,40,40|2,50,50",
            [2] = "0,50,50",
        } }
        G.Map = fakeMap()
        local yd, mapId = G:NearestOf("Banker")
        expect(mapId).toBe(1)
        expect(math.floor(yd + .5)).toBe(math.floor((800 ^ .5) * 4.575 + .5))
        expect(G:NearestOf("Nada")).toBeNil()
        G.Map.PlyrX, G.Map.PlyrY = 0, 0
        expect(G:NearestOf("Banker")).toBeNil()
    end)

    it("a lista mostra Distância e Zona nas categorias de NPC", function()
        local G, env = guide()
        env.Nx.GuideData = { Banker = { Mode = 32, [1] = "0,40,40" } }
        env.Nx.SearchBox = { Normalize = function(s) return s end }
        env.Nx.Map.IdToName = function(_, id) return "Zona " .. id end
        G.Map = fakeMap()
        G.EditBox = { GetText = function() return "" end }
        G.IsShowFolders = function() return false end
        local folder = { { Name = "Banker", T = "Banker", Tx = "INV_Misc_Coin_02" } }
        G.PathHistory = { folder }
        local l = fakeList()
        G:UpdateList(l, 1, 2)
        expect(l.rows[1][3]).toBe(string.format("%d yds", math.floor((800 ^ .5) * 4.575 + .5)))
        expect(l.rows[1][4]).toBe("Zona 1")
        expect(l.names[3]).toBe("Distance")
        expect(l.names[4]).toBe("Zone")
    end)

    it("largura padrão fixa, menor que a antiga de 63% da tela", function()
        local G = guide()
        expect(G.DefaultW > 0 and G.DefaultW <= 900).toBe(true)
        local src = loader.read("Carbonite/Data/Shared/NxMapGuide.lua")
        expect(src:find("InitLayoutData (nil, -.15, -.2, Nx.Map.Guide.DefaultW, -.5)", 1, true) ~= nil).toBe(true)
        expect(src:find('win.SaveData["W"] == Nx.Map.Guide.OldDefaultW', 1, true) ~= nil).toBe(true)
    end)

    it("botão Voltar no estilo do jogo, com o texto do locale", function()
        local src = loader.read("Carbonite/Data/Shared/NxMapGuide.lua")
        expect(src:find('CreateFrame ("Button", nil, win.Frm, "UIPanelButtonTemplate")', 1, true) ~= nil).toBe(true)
        expect(src:find('but:SetText (L["Back"])', 1, true) ~= nil).toBe(true)
        expect(src:find('L["Back "]', 1, true)).toBeNil()
    end)
end)
