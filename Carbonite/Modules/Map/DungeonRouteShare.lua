-- Carbonite | Modules / Map / DungeonRouteShare
-- Sending routes to the group or the guild (#272), in ForeverDungeonRoutes'
-- protocol so that Carbonite and ForeverDungeonRoutes talk to each other
-- (Share.lua of ForeverDungeonRoutes, Checkov23, MIT). Nothing is taken
-- over without asking. With ForeverDungeonRoutes loaded, it asks the player
-- itself: Carbonite then only sends.
--
-- Addon messages, prefix "FDRoutes", fields separated by tabs:
--   S <key> <routeId>                     use this standard route
--   R <transfer> <parts> <key> <name>     a player route follows in <parts> pieces
--   C <transfer> <index> <piece>          one piece of the "!FDR1!" text
--
-- Public (Nx.DungeonRouteShare):
--   S:Channel()                        INSTANCE_CHAT, RAID, PARTY or nil
--   S:Messages(key, route)             the messages that send a route
--   S:SendRoute(key, route, channel)   true when sending started ("GUILD" or the group)
--   S:OrderLines(key, route)           the boss order as chat lines
--   S:PostOrder(key, route)
--   S:OnMessage(prefix, text, channel, sender)
--   S.Offer(o)                         asks the player (o.text, o.accept)

local Nx = _G.Nx
if not Nx then return end

local L = LibStub("AceLocale-3.0"):GetLocale("Carbonite")

local S = {}
Nx.DungeonRouteShare = S

S.PREFIX = "FDRoutes"
S.PIECE = 240
S.MAX_PARTS = 300
S.TIMEOUT = 120
local SEND_INTERVAL = 0.2
local RETRY = 1

local queue = {}
local sending = false
S.Transfers = {}

local function R() return Nx.DungeonRoutes end
local function C() return Nx.DungeonRouteCodec end

local function prt(msg, ...)
    if Nx.prt then Nx.prt(msg, ...) end
end

local function safe(v)
    if _G.issecretvalue and _G.issecretvalue(v) then return nil end
    return v
end

function S:Channel()
    if _G.LE_PARTY_CATEGORY_INSTANCE and _G.IsInGroup and safe(_G.IsInGroup(_G.LE_PARTY_CATEGORY_INSTANCE)) then
        return "INSTANCE_CHAT"
    end
    if _G.IsInRaid and safe(_G.IsInRaid()) then return "RAID" end
    if _G.IsInGroup and safe(_G.IsInGroup()) then return "PARTY" end
end

local function chat()
    return _G.C_ChatInfo or {}
end

local function lockdown()
    local f = chat().InChatMessagingLockdown
    return f and safe(f()) == true or false
end

local function pump()
    local item = queue[1]
    if not item then
        sending = false
        return
    end
    if lockdown() then
        _G.C_Timer.After(RETRY * 2, pump)
        return
    end
    local send = chat().SendAddonMessage
    local result = send and safe(send(S.PREFIX, item.text, item.channel))
    if result == nil or result == true or result == 0 then
        table.remove(queue, 1)
        if item.done then prt(item.done) end
        _G.C_Timer.After(SEND_INTERVAL, pump)
    elseif result == 3 or result == 8 or result == 11 then  -- throttled / lockdown: try again
        _G.C_Timer.After(RETRY, pump)
    else
        queue = {}
        sending = false
        prt(L["Sending failed."])
    end
end

local function enqueue(channel, texts, done)
    for i, text in ipairs(texts) do
        queue[#queue + 1] = { channel = channel, text = text, done = i == #texts and done or nil }
    end
    if not sending then
        sending = true
        pump()
    end
end

-- The messages that send a route: one hint for a standard route, else the
-- header and the pieces of its export text.
function S:Messages(key, route, transfer)
    if R().IsBuiltIn(route) then
        return { table.concat({ "S", key, route.id }, "\t") }
    end
    local text = C().Export(key, route)
    local parts = math.ceil(#text / S.PIECE)
    transfer = transfer or format("%04x", math.random(0, 65535))
    local name = R():RouteName(route):gsub("[\t|]", " "):sub(1, 60)
    local texts = { table.concat({ "R", transfer, tostring(parts), key, name }, "\t") }
    for i = 1, parts do
        texts[#texts + 1] = table.concat({ "C", transfer, tostring(i), text:sub((i - 1) * S.PIECE + 1, i * S.PIECE) }, "\t")
    end
    return texts
end

function S:SendRoute(key, route, channel)
    if not key or not route then return false end
    local sent = L["Route sent to your group."]
    if channel == "GUILD" then
        if not (_G.IsInGuild and safe(_G.IsInGuild())) then
            prt(L["You are not in a guild."])
            return false
        end
        sent = L["Route sent to your guild."]
    else
        channel = self:Channel()
        if not channel then
            prt(L["You are not in a group."])
            return false
        end
    end
    local register = chat().RegisterAddonMessagePrefix
    if register then register(S.PREFIX) end
    enqueue(channel, self:Messages(key, route), sent)
    return true
end

-- "Dungeon: 1 Boss, R Rare, + Optional" in lines of at most 255 characters.
function S:OrderLines(key, route)
    local Rt = R()
    local labels = Rt.StopLabels(route)
    local head = Rt:KeyName(key) .. ": "
    local lines, line = {}, head
    for i, stop in ipairs(route.stops or {}) do
        local piece = labels[i] .. " " .. Rt:StopName(stop):gsub("|", "")
        if line ~= head and #line + 2 + #piece > 250 then
            lines[#lines + 1] = line
            line = piece
        else
            line = line .. (line ~= head and ", " or "") .. piece
        end
    end
    lines[#lines + 1] = line
    return lines
end

function S:PostOrder(key, route)
    local lines = self:OrderLines(key, route)
    local channel = self:Channel()
    local say = chat().SendChatMessage or _G.SendChatMessage
    if not channel or not say then
        for _, line in ipairs(lines) do prt(line) end
        return false
    end
    for _, line in ipairs(lines) do say(line, channel) end
    return true
end

--------------------------------------------------------------------------------
-- Receiving
--------------------------------------------------------------------------------

local function senderName(sender)
    if _G.Ambiguate then return _G.Ambiguate(sender, "none") end
    return (sender:gsub("%-.*$", ""))
end

local function isMe(sender)
    local me = _G.UnitName and safe(_G.UnitName("player"))
    return me ~= nil and senderName(sender) == me
end

local POPUP = "CARBONITE_DUNGEON_ROUTE_OFFER"
local offers = {}

local function showNext()
    if S.OfferShown then return end
    local o = table.remove(offers, 1)
    if not o then return end
    local dialogs = _G.StaticPopupDialogs
    if not (dialogs and _G.StaticPopup_Show) then return end
    dialogs[POPUP] = dialogs[POPUP] or {
        button1 = _G.ACCEPT or "Accept", button2 = _G.CANCEL or "Cancel",
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
        OnAccept = function(self) if self.data then self.data() end end,
        OnHide = function()
            S.OfferShown = nil
            _G.C_Timer.After(0, showNext)
        end,
    }
    dialogs[POPUP].text = "%s"
    S.OfferShown = true
    local popup = _G.StaticPopup_Show(POPUP, o.text)
    if popup then popup.data = o.accept else S.OfferShown = nil end
end

function S.Offer(o)
    offers[#offers + 1] = o
    showNext()
end

local function openOn(key)
    local DC = Nx.DungeonChart
    if DC then DC:Open("routes", key) end
end

local function receivedStandard(sender, key, id)
    local Rt = R()
    local route = Rt:Route(key, id)
    if not route or not Rt.IsBuiltIn(route) then return end
    S.Offer({
        text = format(L["%s recommends the route \"%s\" for %s. Use it?"], senderName(sender), Rt:RouteName(route), Rt:KeyName(key)),
        accept = function()
            Rt:SetActive(key, id)
            openOn(key)
        end,
    })
end

local function sameRoute(key, text)
    for _, route in ipairs(R():Routes(key)) do
        if not R().IsBuiltIn(route) and C().Export(key, route) == text then return route end
    end
end
S.SameRoute = sameRoute

local function receivedRoute(sender, t)
    local Rt = R()
    local text = table.concat(t.pieces)
    local key, route = C().Import(text)
    if not key or key ~= t.key then
        prt(L["%s sent a route that could not be read."], senderName(sender))
        return
    end
    S.Offer({
        text = format(L["%s sends you the route \"%s\" for %s. Take it over?"], senderName(sender), Rt:RouteName(route), Rt:KeyName(key)),
        accept = function()
            local existing = sameRoute(key, text)
            if existing then
                Rt:SetActive(key, existing.id)
            else
                Rt:AddUserRoute(key, route)
            end
            openOn(key)
        end,
    })
end

local function forever()
    local f = _G.C_AddOns and _G.C_AddOns.IsAddOnLoaded
    return f and f("ForeverDungeonRoutes") and true or false
end

function S:OnMessage(prefix, text, _, sender)
    prefix, text, sender = safe(prefix), safe(text), safe(sender)
    if prefix ~= S.PREFIX or type(text) ~= "string" or type(sender) ~= "string" or isMe(sender) then return end
    if forever() then return end
    local Rt = R()
    if not (Rt and Rt:Load()) then return end
    local f = {}
    for field in (text .. "\t"):gmatch("([^\t]*)\t") do f[#f + 1] = field end
    local t0 = _G.time and _G.time() or 0
    for id, t in pairs(S.Transfers) do
        if t0 - t.time > S.TIMEOUT then S.Transfers[id] = nil end
    end
    if f[1] == "S" and Rt:Dungeon(f[2]) then
        receivedStandard(sender, f[2], f[3])
    elseif f[1] == "R" then
        local parts = tonumber(f[3])
        if not parts or parts < 1 or parts > S.MAX_PARTS or not Rt:Dungeon(f[4]) then return end
        for id, t in pairs(S.Transfers) do
            if t.sender == sender then S.Transfers[id] = nil end
        end
        S.Transfers[sender .. f[2]] = { sender = sender, key = f[4], parts = parts, pieces = {}, got = 0, time = t0 }
    elseif f[1] == "C" then
        local t = S.Transfers[sender .. (f[2] or "")]
        local i = tonumber(f[3])
        if not t or not i or i < 1 or i > t.parts or i ~= math.floor(i) or t.pieces[i] then return end
        t.pieces[i] = f[4] or ""
        t.got = t.got + 1
        t.time = t0
        if t.got == t.parts then
            S.Transfers[sender .. f[2]] = nil
            receivedRoute(sender, t)
        end
    end
end

local events = _G.CreateFrame and _G.CreateFrame("Frame")
if events then
    local register = chat().RegisterAddonMessagePrefix
    if register then register(S.PREFIX) end
    events:RegisterEvent("CHAT_MSG_ADDON")
    events:SetScript("OnEvent", function(_, _, prefix, text, channel, sender)
        S:OnMessage(prefix, text, channel, sender)
    end)
end
