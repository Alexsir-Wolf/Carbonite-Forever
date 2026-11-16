-- Carbonite.Notes | Integrations / GatherLite
-- Mirrors GatherLite's gathering nodes (its bundled database plus the
-- player's own gathered history) onto the Carbonite map.

local Nx = _G.Nx
if not Nx then return end
Nx.Notes = Nx.Notes or {}

Nx.Notes.GLVersion    = Nx.Notes.GLVersion or 0
Nx.Notes.GLLastMapId  = nil
Nx.Notes.GLLastSig    = nil
Nx.Notes.PrevGLPins   = 0

local KINDS = { "mining", "herbalism", "containers", "fishing" }
local KIND_LABEL = { mining = "mining", herbalism = "herbalism", fishing = "fish" }

-- Skill line of each kind, for the skill-up color of its nodes (#76).
local SKILL_LINE = { mining = 186, herbalism = 182, fishing = 356 }
-- Red: skill too low to gather. Then orange, yellow, green and gray, as the
-- game colors the chance of a skill point. GatherLite keeps, per node type,
-- the skill where each of the last four starts (levels = { 1, 25, 50, 100 }).
local SKILL_COLORS = { "ff3030", "ff8040", "ffff20", "40c040", "a0a0a0" }

-- Hex color for a node with GatherLite's `levels` at the player's `rank`, or
-- nil (no levels, or the player lacks the skill). It colors the node's name
-- in the tooltip; the icon keeps its own colors.
function Nx.Notes:GatherSkillColor(levels, rank)
    if type(levels) ~= "table" or type(levels[1]) ~= "number"
            or type(rank) ~= "number" or rank <= 0 then
        return nil
    end
    local band = 1
    for i = 1, 4 do
        if type(levels[i]) == "number" and rank >= levels[i] then band = i + 1 end
    end
    return SKILL_COLORS[band]
end

local function SkillRanks()
    local ranks = {}
    local api = _G.Carbonite and _G.Carbonite.Compat and _G.Carbonite.Compat.Api
    local skill = api and api.Skill
    if Nx.fdb.profile.Notes.GatherLiteSkillColor and skill then
        for kind, line in pairs(SKILL_LINE) do
            ranks[kind] = skill:GetRank(line)
        end
    end
    return ranks
end

function Nx.Notes:IsGatherLiteAvailable()
    local GL = _G.GatherLite
    return type(GL) == "table"
        and type(GL.GetNodesForMap) == "function"
        and type(GL.GetNodeObject) == "function"
        and type(GL.IsLoaded) == "function"
        and GL.db ~= nil
end

-- GatherLite installed and shown on the Carbonite map. Then it is the only source of
-- gathering nodes: Carbonite stops drawing its own, which would repeat them.
function Nx.Notes:GatherLiteActive()
    return Nx.fdb and Nx.fdb.profile.Notes.GatherLite and self:IsGatherLiteAvailable() or false
end

local function bump()
    Nx.Notes.GLVersion = Nx.Notes.GLVersion + 1
end

local function ensureHooks()
    if Nx.Notes.GLHooked then return end
    local GL = _G.GatherLite
    if not GL then return end
    Nx.Notes.GLHooked = true
    for _, fn in ipairs({ "InvalidateNodeCache", "SetNodeTracking", "SetIgnored", "LoadTable" }) do
        if type(GL[fn]) == "function" then
            hooksecurefunc(GL, fn, bump)
        end
    end
    if type(GL.On) == "function" then
        pcall(GL.On, GL, "settings:update", bump)
    end
end

local function translate(GL, key)
    local ok, s = pcall(GL.translate, GL, key)
    return ok and s or key
end

-- `color`: hex of the skill-up chance (GatherSkillColor) for the node's name, or nil.
local function buildTip(GL, node, object, color)
    local name = translate(GL, "node." .. object.name)
    if color then name = "|cff" .. color .. name .. "|r" end
    local lines = { "|T" .. object.icon .. ":16:16|t " .. name }
    local label = KIND_LABEL[node.type]
    if label then
        lines[#lines + 1] = "|cff999999" .. translate(GL, label) .. "|r"
    end
    local d = node.date
    if type(d) == "table" and d.year and d.month and d.day then
        lines[#lines + 1] = ("|cff999999%04d-%02d-%02d|r"):format(d.year, d.month, d.day)
    end
    lines[#lines + 1] = "|cff80c0ffGatherLite|r"
    return table.concat(lines, "\n")
end

function Nx.Notes:GatherLite(mapId)
    if not Nx.fdb.profile.Notes.GatherLite then return end
    if not self:IsGatherLiteAvailable() then return end
    local GL = _G.GatherLite
    if not GL:IsLoaded() then return end
    ensureHooks()

    local map = Nx.Map:GetMap(1)
    if not map or not mapId then return end

    local usePredef = GL.db.global.usePredefined and true or false
    local sig = usePredef and 1 or 0
    for i = 1, #KINDS do
        if GL:GetNodeTracking("worldmap", KINDS[i]) then
            sig = sig + 2 ^ i
        end
    end
    local ranks = SkillRanks()
    sig = self.GLVersion * 64 + sig
    local rankSig = format("%d:%d:%d", ranks.mining or 0, ranks.herbalism or 0, ranks.fishing or 0)

    if self.GLLastMapId == mapId and self.GLLastSig == sig and self.GLLastRanks == rankSig then return end
    self.GLLastRanks = rankSig

    map:ClearIconType("!GLT")
    self.GLLastMapId = mapId
    self.GLLastSig   = sig
    self.PrevGLPins  = 0

    local size = Nx.fdb.profile.Notes.GatherLiteSize or 14
    map:InitIconType("!GLT", "WP", "", size, size)
    map:SetIconTypeChop("!GLT", true)
    map:SetIconTypeLevel("!GLT", 10)
    local gatherAtScale = Nx.db.profile.Map and Nx.db.profile.Map.IconGatherAtScale
    if gatherAtScale then
        map:SetIconTypeAtScale("!GLT", gatherAtScale)
    end

    local count = 0
    for _, kind in ipairs(KINDS) do
        if GL:GetNodeTracking("worldmap", kind) then
            local nodes = GL:GetNodesForMap(kind, mapId)
            for i = 1, #nodes do
                local node = nodes[i]
                if (usePredef or not node.predefined)
                    and not GL:IsIgnored(node.object)
                    and node.posX and node.posY then
                    local object = GL:GetNodeObject(node.object)
                    if object then
                        local wx, wy = Nx.Map:GetWorldPos(mapId, node.posX * 100, node.posY * 100)
                        local color = self:GatherSkillColor(object.levels, ranks[kind])
                        local pin = wx and wy and map:AddIconPt("!GLT", wx, wy, nil, nil, object.icon)
                        if pin then
                            pin.mapID, pin.MapId = mapId, mapId
                            map:SetIconTip(pin, buildTip(GL, node, object, color))
                            count = count + 1
                        end
                    end
                end
            end
        end
    end
    self.PrevGLPins = count
end
