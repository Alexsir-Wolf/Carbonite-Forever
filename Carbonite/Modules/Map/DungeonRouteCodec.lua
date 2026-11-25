-- Carbonite | Modules / Map / DungeonRouteCodec
-- Route export and import in ForeverDungeonRoutes' "!FDR1!" format (#272),
-- so a route made in one addon works in the other. The format and its
-- limits follow ForeverDungeonRoutes' Serialize.lua (Copyright (c) 2026
-- Checkov23, MIT license; see Carbonite.Dungeons/LICENSE-ForeverDungeonRoutes.txt).
--
-- "!FDR1!" followed by base64 of tab separated lines:
--   K <key>                                   dungeon key
--   N <name>
--   P <kind> <floor> <x,y,x,y,...> [title]    path (main / side)
--   S <kind> <floor> <x> <y> <name> [note] [encounterID,...]   stop
--   O <floor> <x> <y> <text>                  note
--   L <floor> <x> <y> <to> <label>            link to another floor
-- Coordinates are integers 0..10000.
--
-- Public (Nx.DungeonRouteCodec):
--   C.Export(key, route)          the export text
--   C.Import(text)                key, route or nil, error key (L[...])
--   C.Base64Encode / C.Base64Decode

local Nx = _G.Nx
if not Nx then return end

local C = {}
Nx.DungeonRouteCodec = C

C.PREFIX = "!FDR1!"
local SCALE = 10000
C.LIMITS = { paths = 300, points = 20000, stops = 120, notes = 200, links = 60, text = 200 }
local LIMITS = C.LIMITS

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64_DECODE = {}
for i = 1, 64 do B64_DECODE[B64:byte(i)] = i - 1 end

function C.Base64Encode(data)
    local out = {}
    for i = 1, #data, 3 do
        local a, b, c = data:byte(i, i + 2)
        local n = a * 65536 + (b or 0) * 256 + (c or 0)
        local c1 = math.floor(n / 262144) % 64
        local c2 = math.floor(n / 4096) % 64
        local c3 = math.floor(n / 64) % 64
        local c4 = n % 64
        out[#out + 1] = B64:sub(c1 + 1, c1 + 1) .. B64:sub(c2 + 1, c2 + 1)
            .. (b and B64:sub(c3 + 1, c3 + 1) or "=") .. (c and B64:sub(c4 + 1, c4 + 1) or "=")
    end
    return table.concat(out)
end

function C.Base64Decode(text)
    text = text:gsub("%s", "")
    if #text % 4 ~= 0 or text:find("[^%w%+/=]") then return nil end
    local out = {}
    for i = 1, #text, 4 do
        local a, b, c, d = text:byte(i, i + 3)
        local va, vb = B64_DECODE[a], B64_DECODE[b]
        local vc, vd = B64_DECODE[c], B64_DECODE[d]
        if not va or not vb then return nil end
        local n = va * 262144 + vb * 4096 + (vc or 0) * 64 + (vd or 0)
        out[#out + 1] = string.char(math.floor(n / 65536) % 256)
        if c ~= 61 then
            if not vc then return nil end
            out[#out + 1] = string.char(math.floor(n / 256) % 256)
        end
        if d ~= 61 then
            if not vd then return nil end
            out[#out + 1] = string.char(n % 256)
        end
    end
    return table.concat(out)
end

local function clean(text)
    text = tostring(text or "")
    text = text:gsub("[\t\r\n|]", " ")
    return text:sub(1, LIMITS.text)
end

local function int(v)
    v = math.max(0, math.min(1, tonumber(v) or 0))
    return tostring(math.floor(v * SCALE + 0.5))
end

local function R()
    return Nx.DungeonRoutes
end

function C.Export(key, route)
    local Rt = R()
    local lines = { "K\t" .. clean(key), "N\t" .. clean(Rt:RouteName(route)) }
    for _, path in ipairs(route.paths or {}) do
        local nums = {}
        for i = 1, #path.pts do nums[i] = int(path.pts[i]) end
        lines[#lines + 1] = table.concat({ "P", path.kind, tostring(path.floor), table.concat(nums, ","),
            clean(path.title) }, "\t")
    end
    for _, stop in ipairs(route.stops or {}) do
        local fights = {}
        for i, id in ipairs(stop.encounters or {}) do fights[i] = tostring(id) end
        lines[#lines + 1] = table.concat({ "S", stop.kind, tostring(stop.floor), int(stop.x), int(stop.y),
            clean(stop.name), clean(Rt.Loc(stop, "note")), table.concat(fights, ",") }, "\t")
    end
    for _, note in ipairs(route.notes or {}) do
        lines[#lines + 1] = table.concat({ "O", tostring(note.floor), int(note.x), int(note.y),
            clean(Rt.Loc(note, "text")) }, "\t")
    end
    for _, link in ipairs(route.links or {}) do
        lines[#lines + 1] = table.concat({ "L", tostring(link.floor), int(link.x), int(link.y),
            tostring(link.to), clean(link.label) }, "\t")
    end
    return C.PREFIX .. C.Base64Encode(table.concat(lines, "\n"))
end

local VALID_PATH = { main = true, side = true }
local VALID_STOP = { boss = true, rare = true, optional = true }

local function split(line)
    local fields = {}
    for field in (line .. "\t"):gmatch("([^\t]*)\t") do
        -- no | in imported text: it would start colour codes, links or pictures
        fields[#fields + 1] = (field:gsub("|", ""))
    end
    return fields
end

local function coord(text)
    local n = tonumber(text)
    if not n or n < 0 or n > SCALE then return nil end
    return n / SCALE
end

local function floorID(text)
    local n = tonumber(text)
    if not n or n < 1 or n ~= math.floor(n) then return nil end
    return n
end

-- The encounter of dungeon `key` with this name (any language).
function C.EncounterByName(key, name)
    local Rt = R()
    local d = Rt:Dungeon(key)
    local data = Rt:Data()
    for _, e in ipairs(d and data and data.Encounters and data.Encounters[d.instanceID] or {}) do
        if Rt.HasName(e, name) then return e end
    end
end

local DAMAGED, TOO_LARGE, EMPTY, NOT_FDR = "The text is damaged or incomplete.", "The route is too large.",
    "The route is empty.", "This is not a route export."

function C.Import(text)
    local Rt = R()
    text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if text:sub(1, #C.PREFIX) ~= C.PREFIX then return nil, NOT_FDR end
    local data = C.Base64Decode(text:sub(#C.PREFIX + 1))
    if not data then return nil, DAMAGED end
    local key
    local route = { paths = {}, stops = {}, notes = {}, links = {} }
    local points = 0
    for line in data:gmatch("[^\n]+") do
        local f = split(line)
        local tag = f[1]
        if tag == "K" then
            key = f[2]
        elseif tag == "N" then
            route.name = f[2]
        elseif tag == "P" then
            local floor = floorID(f[3])
            if not VALID_PATH[f[2]] or not floor then return nil, DAMAGED end
            local pts = {}
            for num in (f[4] or ""):gmatch("[^,]+") do
                local v = coord(num)
                if not v then return nil, DAMAGED end
                pts[#pts + 1] = v
            end
            if #pts >= 4 and #pts % 2 == 0 then
                points = points + #pts / 2
                local title = f[5] ~= "" and f[5] or nil
                table.insert(route.paths, { kind = f[2], floor = floor, title = title, pts = pts })
            end
        elseif tag == "S" then
            local floor, x, y = floorID(f[3]), coord(f[4]), coord(f[5])
            if not VALID_STOP[f[2]] or not floor or not x or not y then return nil, DAMAGED end
            local note = f[7] ~= "" and f[7] or nil
            local stop = { kind = f[2], floor = floor, x = x, y = y, name = f[6] or "", note = note }
            for id in (f[8] or ""):gmatch("%d+") do
                stop.encounters = stop.encounters or {}
                if #stop.encounters < 8 then table.insert(stop.encounters, tonumber(id)) end
            end
            table.insert(route.stops, stop)
        elseif tag == "O" then
            local floor, x, y = floorID(f[2]), coord(f[3]), coord(f[4])
            if not floor or not x or not y then return nil, DAMAGED end
            table.insert(route.notes, { floor = floor, x = x, y = y, text = f[5] or "" })
        elseif tag == "L" then
            local floor, x, y, to = floorID(f[2]), coord(f[3]), coord(f[4]), floorID(f[5])
            if not floor or not x or not y or not to then return nil, DAMAGED end
            table.insert(route.links, { floor = floor, x = x, y = y, to = to, label = f[6] or "" })
        end
        if #route.paths > LIMITS.paths or points > LIMITS.points or #route.stops > LIMITS.stops
            or #route.notes > LIMITS.notes or #route.links > LIMITS.links then
            return nil, TOO_LARGE
        end
    end
    local dungeon = key and Rt:Dungeon(key)
    if not dungeon then return nil, DAMAGED end
    -- Only what lies on a floor of this dungeon can be shown.
    for _, list in ipairs({ route.paths, route.stops, route.notes, route.links }) do
        for i = #list, 1, -1 do
            if Rt:DungeonOfFloor(list[i].floor) ~= dungeon then table.remove(list, i) end
        end
    end
    -- The game's boss names come back in the player's language.
    for _, stop in ipairs(route.stops) do
        local e = C.EncounterByName(key, stop.name)
        if e and e.name == stop.name then Rt.SetNames(stop, e) end
    end
    if #route.paths == 0 and #route.stops == 0 and #route.notes == 0 then return nil, EMPTY end
    Rt.RecalcProgress(route)
    return key, route
end
