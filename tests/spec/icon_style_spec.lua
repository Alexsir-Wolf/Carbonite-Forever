-- Item icons on the map: Blizzard atlas or frameless, not the old framed square (#247)

local function load(atlases, classic)
    local env = wow.lenientEnv()
    local known = {}
    for _, name in ipairs(atlases or {}) do known[name] = true end
    env.C_Texture = { GetAtlasInfo = function(name) return known[name] and { width = 16 } or nil end }
    env.Nx = { db = { profile = { Map = { ClassicIcons = classic } } } }
    loader.run(env, "Carbonite/Modules/Map/IconStyle.lua")
    return env.Carbonite.Modules.Map.IconStyle, env
end

-- A pooled icon texture that records what was done to it.
local function texture()
    local tex = { log = {} }
    function tex:SetTexCoord(l, r, t, b) self.log[#self.log + 1] = "coord " .. l .. " " .. r .. " " .. t .. " " .. b end
    function tex:SetAtlas(name) self.log[#self.log + 1] = "atlas " .. name end
    function tex.AddMaskTexture() error("no mask: it cuts the item art") end
    return tex
end

local function never() return false end
local function always() return true end

describe("estilo de cada textura", function()
    local IconStyle = load()

    it("ícone de item perde só a moldura quando não há atlas", function()
        expect(IconStyle.Resolve("Interface\\Icons\\Trade_Alchemy", false, never)).toBe("crop")
    end)

    it("correio usa o atlas da Blizzard quando o cliente tem", function()
        local kind, atlas = IconStyle.Resolve("Interface\\Icons\\INV_Letter_15", false, always)
        expect(kind .. " " .. atlas).toBe("atlas Mailbox")
    end)

    it("mestre de estábulo usa o atlas dele", function()
        local kind, atlas = IconStyle.Resolve("Interface\\Icons\\Ability_Hunter_BeastTaming", false, always)
        expect(kind .. " " .. atlas).toBe("atlas StableMaster")
    end)

    it("bigorna e treinador de ferraria dividem o ícone, então ficam com o desenho próprio", function()
        expect(IconStyle.Resolve("Interface\\Icons\\Trade_BlackSmithing", false, always)).toBe("crop")
    end)

    it("mestre de voo tenta os atlas em ordem e cai no recorte", function()
        local wyvern = "Interface\\AddOns\\Carbonite\\Gfx\\Ability_mount_wyvern_01"
        local function onlyFlightMaster(name) return name == "FlightMaster" end
        local kind, atlas = IconStyle.Resolve(wyvern, false, onlyFlightMaster)
        expect(kind .. " " .. atlas).toBe("atlas FlightMaster")
        expect(IconStyle.Resolve(wyvern, false, never)).toBe("crop")
    end)

    it("as cópias de ícone do Carbonite também mudam", function()
        expect(IconStyle.Resolve("Interface\\AddOns\\Carbonite\\Gfx\\Icons\\inv_scroll_11", false, never)).toBe("crop")
    end)

    it("quest, pino e Gfx próprio ficam como estão", function()
        expect(IconStyle.Resolve("Interface\\AddOns\\Carbonite\\Gfx\\Map\\IconExclaim", false, always)).toBeNil()
        expect(IconStyle.Resolve("Interface\\Minimap\\ObjectIconsAtlas", false, always)).toBeNil()
        expect(IconStyle.Resolve(nil, false, always)).toBeNil()
    end)

    it("ícones clássicos não mudam nada", function()
        expect(IconStyle.Resolve("Interface\\Icons\\INV_Letter_15", true, always)).toBeNil()
    end)
end)

describe("aplicar no quadro do mapa", function()
    it("sem atlas: tira a moldura e mostra o desenho inteiro, sem máscara", function()
        local IconStyle = load()
        local tex = texture()
        IconStyle:Apply("Interface\\Icons\\Trade_Alchemy", tex)
        expect(table.concat(tex.log, ",")).toBe("coord 0.08 0.92 0.08 0.92")
    end)

    it("atlas presente no cliente: usa o atlas", function()
        local IconStyle = load({ "Mailbox" })
        local tex = texture()
        IconStyle:Apply("Interface\\Icons\\INV_Letter_15", tex)
        expect(table.concat(tex.log, ",")).toBe("atlas Mailbox")
    end)

    it("atlas ausente no cliente: só tira a moldura, nunca em branco", function()
        local IconStyle = load({})
        local tex = texture()
        IconStyle:Apply("Interface\\Icons\\INV_Letter_15", tex)
        expect(table.concat(tex.log, ",")).toBe("coord 0.08 0.92 0.08 0.92")
    end)

    it("textura que não é ícone de item não é tocada", function()
        local IconStyle = load({ "Mailbox" })
        local tex = texture()
        IconStyle:Apply("Interface\\AddOns\\Carbonite\\Gfx\\Map\\IconExclaim", tex)
        expect(#tex.log).toBe(0)
    end)

    it("ligar ícones clássicos volta à moldura sem recarregar", function()
        local IconStyle, env = load({ "Mailbox" })
        local tex = texture()
        IconStyle:Apply("Interface\\Icons\\INV_Letter_15", tex)
        env.Nx.db.profile.Map.ClassicIcons = true
        IconStyle:Apply("Interface\\Icons\\INV_Letter_15", tex)
        expect(#tex.log).toBe(1)
    end)
end)

describe("ligação com o mapa", function()
    it("o Renderer aplica o estilo depois de pôr a textura", function()
        expect(loader.read("Carbonite/Modules/Map/Renderer.lua"):find("IconStyle:Apply(tex, fTex)", 1, true) ~= nil).toBe(true)
    end)

    it("o pool volta as coordenadas ao reaproveitar o quadro", function()
        local src = loader.read("Carbonite/Modules/Map/MapEngine.lua")
        local body = src:match("function Nx%.Map:GetIconStatic.-\nend")
        expect(body:find("SetTexCoord (0, 1, 0, 1)", 1, true) ~= nil).toBe(true)
    end)

    it("o módulo carrega antes do Renderer", function()
        local xml = loader.read("Carbonite/Modules/Modules.xml")
        expect(xml:find("IconStyle.lua", 1, true) < xml:find("Renderer.lua", 1, true)).toBe(true)
    end)
end)

describe("modo MapNotes (#247)", function()
    local function active(map, notes, addons)
        local env = wow.lenientEnv({ C_AddOns = { IsAddOnLoaded = function(n) return (addons or {})[n] == true end } })
        env.Nx = { db = { profile = { Map = map } }, fdb = notes and { profile = { Notes = notes } } or nil }
        loader.run(env, "Carbonite/Modules/Map/IconStyle.lua")
        return env.Carbonite.Modules.Map.IconStyle.MapNotesActive()
    end
    local BOTH = { HandyNotes = true, HandyNotes_MapNotes = true }

    it("liga só com os pontos do Carbonite desligados, o HandyNotes ligado e o MapNotes carregado", function()
        expect(active({ ShowPOI = false }, { HandyNotes = true }, BOTH)).toBe(true)
    end)

    it("nas opções Blizzard e clássicos fica desligado", function()
        expect(active({ ShowPOI = true }, { HandyNotes = true }, BOTH)).toBe(false)
        expect(active({}, { HandyNotes = true }, BOTH)).toBe(false)
    end)

    it("sem o MapNotes ou com o HandyNotes desligado no Carbonite fica desligado", function()
        expect(active({ ShowPOI = false }, { HandyNotes = true }, { HandyNotes = true })).toBe(false)
        expect(active({ ShowPOI = false }, { HandyNotes = false }, BOTH)).toBe(false)
    end)
end)

describe("Guia no modo MapNotes (#247)", function()
    local function guide(mapNotes)
        local env = wow.lenientEnv({ strbyte = string.byte })
        env.Nx = wow.namespace({
            db = { profile = { Map = {} }, char = { Map = {} } },
            Map = wow.namespace({ Guide = wow.namespace() }),
        })
        env.Carbonite.Modules.Map.IconStyle = { MapNotesActive = function() return mapNotes end }
        loader.run(env, "Carbonite/Data/Shared/NxMapGuide.lua")
        local G = env.Nx.Map.Guide
        local info = env.Nx.GuideInfo
        local function find(test, folder)
            folder = folder or info
            if type(folder) ~= "table" then return nil end
            if test(folder) then return folder end
            for _, child in ipairs(folder) do
                local hit = find(test, child)
                if hit then return hit end
            end
        end
        local shaman = find(function(f) return f.T == "Shaman Trainer" end)
        local alchemy = find(function(f) return f.Pre == "Alchemy" and f.T == "^P" end)
        local stable = find(function(f) return f.T == "Stable Master" end)
        local givers = find(function(f) return f.T == "&" end)
        G.ShowFolders = { ["Shaman Trainer"] = shaman, ["Alchemy Trainer"] = alchemy,
                          ["Stable Master"] = stable, ["&"] = givers }
        return G
    end

    local function keys(t)
        local out = {}
        for k in pairs(t) do out[#out + 1] = k end
        table.sort(out)
        return table.concat(out, ",")
    end

    it("no modo MapNotes, treinadores e serviços saem do mapa; doadores de missão ficam", function()
        expect(keys(guide(true):FoldersToDraw())).toBe("&")
    end)

    it("fora do modo MapNotes, o Guia desenha tudo como antes", function()
        expect(keys(guide(false):FoldersToDraw())).toBe("&,Alchemy Trainer,Shaman Trainer,Stable Master")
    end)

    it("a lista do Guia não muda: só o desenho no mapa", function()
        local G = guide(true)
        G:FoldersToDraw()
        expect(G.ShowFolders["Shaman Trainer"] ~= nil).toBe(true)
    end)
end)
