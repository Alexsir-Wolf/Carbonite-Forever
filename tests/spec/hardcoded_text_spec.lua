-- Texto da interface e mensagens de chat passam pelo L[...] (#52)

-- Código sem comentários: blocos --[[ ]] primeiro, depois comentários de linha.
local function code(path)
    local src = loader.read(path)
    src = src:gsub("%-%-%[(=*)%[.-%]%1%]", "")
    src = src:gsub("%-%-[^\n]*", "")
    return src
end

-- Primeira ocorrência de `pattern` em `path` (sem comentários), ou "" se não houver.
local function found(path, pattern)
    local s, e = code(path):find(pattern)
    return s and code(path):sub(s, e) or ""
end

describe("arquivo sem uso", function()
    it("Sliverdragon.lua foi removido", function()
        local fh = io.open(loader.root .. "/Carbonite/Integrations/Sliverdragon.lua", "rb")
        if fh then fh:close() end
        expect(fh).toBeNil()
    end)
end)

describe("menus e janelas", function()
    it("itens de menu não usam texto fixo em inglês", function()
        for _, path in ipairs({ "Carbonite/Modules/UI/UIEngine.lua", "Carbonite.Quests/TrackerHider.lua" }) do
            expect(found(path, 'AddItem%s*%(%s*0,%s*"%a')).toBe("")
        end
    end)

    it("popups de copiar link usam L no texto", function()
        for _, path in ipairs({ "Carbonite.Quests/WatchWindow.lua", "Carbonite.Notes/Integrations/Attune.lua" }) do
            expect(found(path, 'text%s*=%s*"%a')).toBe("")
        end
    end)

    it("página de Opções sem texto fixo, exceto o nome Carbonite", function()
        local src = code("Carbonite/Modules/Options/Options.lua")
        for value in src:gmatch('name%s*=%s*"([^"]*)"') do
            expect(value).toBe("Carbonite")
        end
        expect(src:find('reason or "', 1, true)).toBeNil()
        expect(src:find('ok and "', 1, true)).toBeNil()
        expect(src:find('unavailableGroup("', 1, true)).toBeNil()
    end)

    it("tooltip das rotas do mapa usa L", function()
        local path = "Carbonite/Modules/Map/Renderer.lua"
        expect(found(path, 'AddLine%s*%(%s*"%a')).toBe("")
        expect(found(path, 'AddLine%s*%(%s*sourceTag%s*%.%.')).toBe("")
        expect(found(path, 'or%s*"Patrol"')).toBe("")
    end)
end)

describe("mensagens no chat", function()
    it("arquivos corrigidos não chamam Nx.prt com texto fixo", function()
        local files = {
            "Carbonite/Modules/Gather/GatherStorage.lua",
            "Carbonite/Modules/MainUpdater/NXOnUpdate.lua",
            "Carbonite.Quests/CheckMapAndCom.lua",
            "Carbonite.Quests/QuestieSource.lua",
            "Carbonite.Quests/SpokenPlay.lua",
            "Carbonite.Quests/SuperTrack.lua",
            "Carbonite.Warehouse/Engine.lua",
            "Carbonite.Warehouse/Init.lua",
        }
        for _, path in ipairs(files) do
            expect(found(path, 'Nx%.prt%s*%(%s*"%a')).toBe("")
        end
        expect(code("Carbonite.Quests/SuperTrack.lua"):find("QUEST LOADER|", 1, true)).toBeNil()
    end)

    it("mensagens do mapa e do guia usam L", function()
        local guide = loader.read("Carbonite/Data/Shared/NxMapGuide.lua")
        expect(guide:find('Nx.prt ("No guide data', 1, true)).toBeNil()
        expect(guide:find('("CarboniteItems addon', 1, true)).toBeNil()
        local map = loader.read("Carbonite/Modules/Map/MapEngine.lua")
        for _, text in ipairs({ '"Map Error: "', '("zone %s not found', '("zone coordinate error"',
            '("No Status"', '("Reset map options', '("Routed %s nodes', '("%d reported"' }) do
            expect(map:find(text, 1, true)).toBeNil()
        end
    end)

    it("prints de depuração só saem com o modo debug", function()
        local map = loader.read("Carbonite/Modules/Map/MapEngine.lua")
        expect(map:find('Nx.prt("dupe ', 1, true)).toBeNil()
        expect(map:find('Nx.prt ("Merged ', 1, true)).toBeNil()
        expect(code("Carbonite/Modules/UI/UIEngine.lua"):find('Nx.prt ("Win Event', 1, true)).toBeNil()
        expect(code("Carbonite.Warehouse/Engine.lua"):find('Nx.prt ("OnTRADE_SKILL_SHOW")', 1, true)).toBeNil()
        expect(code("Carbonite/Modules/AuctionAssist/AuctionAssistEngine.lua"):find('Nx.prt("%s", name)', 1, true)).toBeNil()
    end)
end)
