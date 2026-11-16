-- Nx.TabBar:AddTab in Carbonite/Modules/UI/UIEngine.lua (#97)

local function load(labelWidth)
    local env = wow.lenientEnv()
    local created = {}
    env.Nx = wow.namespace({ TabBar = {}, Button = {} })
    loader.run(env, "Carbonite/Modules/UI/UIEngine.lua")
    -- Button stand-in recording position and width; the label measures labelWidth[text].
    env.Nx.Button.Create = function(_, _, _, text, _, x, _, _, w)
        local b = { x = x, w = w }
        b.FStr = { GetStringWidth = function() return labelWidth[text] or 10 end }
        b.Frm = { SetWidth = function(_, nw) b.w = nw end, SetID = function() end }
        b.SetId = function() end
        b.SetPressed = function() end
        b.SetText = function() end
        created[#created + 1] = b
        return b
    end
    local bar = setmetatable({ Tabs = {}, TopFrm = {} }, { __index = env.Nx.TabBar })
    return bar, created
end

describe("TabBar:AddTab", function()
    it("aumenta a aba para caber o rótulo e empurra as seguintes", function()
        local bar, b = load({ ["Atual"] = 30, ["Banco de dados"] = 90, ["Jogador"] = 45 })
        bar:AddTab("Atual", 1)
        bar:AddTab("Banco de dados", 2)
        bar:AddTab("Jogador", 3)
        expect(b[1].w).toBe(66)
        expect(b[2].w).toBe(106)
        expect(b[2].x).toBe(1 + 66 + 2)
        expect(b[3].x).toBe(b[2].x + 106 + 2)
    end)

    it("respeita a largura fixa quando informada", function()
        local bar, b = load({ ["Longo demais"] = 200 })
        bar:AddTab("Longo demais", 1, 50)
        bar:AddTab("B", 2, 50)
        expect(b[1].w).toBe(50)
        expect(b[2].x).toBe(1 + 50 + 2)
    end)
end)
