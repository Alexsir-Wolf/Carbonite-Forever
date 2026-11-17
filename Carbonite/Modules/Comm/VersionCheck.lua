-- Carbonite | Modules / Comm / VersionCheck
-- In-game notice of a newer Carbonite-Forever (#92). The addon has no internet
-- access, so each copy tells the others its own version through an addon
-- message (prefix PREFIX) and warns in chat, once per session, when it sees a
-- newer one.
--
-- What is sent: only the "## Version" string of the TOC (for example
-- "v12.1.0-00023-forever.3"). Nothing about the character.
--
-- When it is sent (never more than once every THROTTLE seconds per channel):
--   - LOGIN_DELAY seconds after login, to the group/raid and to the guild;
--   - when someone joins the group or raid (GROUP_ROSTER_UPDATE);
--   - to the guild once per session, when the guild roster first loads
--     (GUILD_ROSTER_UPDATE fires all the time in a big guild);
--   - as a reply on the same channel when an older version is heard, so the
--     older copy learns about the newer one. A send blocked by the throttle
--     of a channel is kept and goes out when the window ends.
--
-- A development copy (the TOC still says "@project-version@", or anything
-- that is not a release tag "...-forever.N") neither announces nor warns, and
-- such versions heard from others are ignored.
-- Nx.db.profile.General.VersionCheck = false turns all of it off.
--
-- Public API:
--   VersionCheck.Parse(version)      -> { nums = {...}, forever = n } or nil
--   VersionCheck.Compare(a, b)       -> -1, 0, 1, or nil when one is not a release
--   VersionCheck:MyVersion()         -> the TOC version, or nil for a development copy
--   VersionCheck:Announce(channel, keep) - send the version (throttled)
--   VersionCheck:OnMessage(version, channel) - a version heard from another copy
--   VersionCheck:OnEvent(event, ...) - client events

local Carbonite = _G.Carbonite
local L = LibStub("AceLocale-3.0"):GetLocale("Carbonite")

local VersionCheck = {}
Carbonite.Modules.Comm = Carbonite.Modules.Comm or {}
Carbonite.Modules.Comm.VersionCheck = VersionCheck

VersionCheck.PREFIX = "CrbFvVer"
VersionCheck.THROTTLE = 60
VersionCheck.LOGIN_DELAY = 15

local lastSent = {}   -- channel -> GetTime() of the last send
local pending = {}    -- channel -> true while a deferred send is scheduled
local ready = false   -- true after the login delay
local guildDone = false
local groupSize = 0
local warned = false
local newest            -- newest version heard, as sent

local function now()
    return _G.GetTime and _G.GetTime() or 0
end

-------------------------------------------------------------------------------
-- Versions
-------------------------------------------------------------------------------

-- Splits a release version into its numbers. "v12.1.0-00023-forever.3" gives
-- { nums = { 12, 1, 0, 23 }, forever = 3 }. Anything else (a development
-- copy, a build between tags such as "...-forever.3-2-gabc123") gives nil.
function VersionCheck.Parse(version)
    if type(version) ~= "string" then return nil end
    local base, forever = version:match("^%s*v?([%d%.%-]+)%-forever%.(%d+)%s*$")
    if not base then return nil end
    local nums = {}
    for n in base:gmatch("%d+") do nums[#nums + 1] = tonumber(n) end
    if #nums == 0 then return nil end
    return { nums = nums, forever = tonumber(forever) }
end

-- -1 when a is older than b, 1 when newer, 0 when the same; nil when either
-- one is not a release version.
function VersionCheck.Compare(a, b)
    local pa, pb = VersionCheck.Parse(a), VersionCheck.Parse(b)
    if not pa or not pb then return nil end
    for i = 1, math.max(#pa.nums, #pb.nums) do
        local x, y = pa.nums[i] or 0, pb.nums[i] or 0
        if x ~= y then return x < y and -1 or 1 end
    end
    if pa.forever ~= pb.forever then return pa.forever < pb.forever and -1 or 1 end
    return 0
end

function VersionCheck:MyVersion()
    local getter = (_G.C_AddOns and _G.C_AddOns.GetAddOnMetadata) or _G.GetAddOnMetadata
    local version = getter and getter("Carbonite", "Version")
    if VersionCheck.Parse(version) then return version end
    return nil
end

local function enabled()
    local Nx = _G.Nx
    local general = Nx and Nx.db and Nx.db.profile and Nx.db.profile.General
    return not general or general.VersionCheck ~= false
end

-------------------------------------------------------------------------------
-- Sending
-------------------------------------------------------------------------------

-- Channel of the current group: RAID, INSTANCE_CHAT, PARTY or nil.
local function groupChannel()
    if _G.IsInRaid and _G.IsInRaid() then return "RAID" end
    local instance = _G.LE_PARTY_CATEGORY_INSTANCE
    if instance and _G.IsInGroup and _G.IsInGroup(instance) then return "INSTANCE_CHAT" end
    if _G.IsInGroup and _G.IsInGroup() then return "PARTY" end
    return nil
end

local function send(channel, version)
    local chat = _G.C_ChatInfo
    local fn = chat and chat.SendAddonMessage or _G.SendAddonMessage
    if fn then fn(VersionCheck.PREFIX, version, channel) end
end

-- Sends the version to channel. Inside the throttle window the send is
-- dropped, or, with keep, done once when the window ends.
function VersionCheck:Announce(channel, keep)
    if not channel or not enabled() then return false end
    local version = self:MyVersion()
    if not version then return false end
    local t, last = now(), lastSent[channel]
    if last and t - last < self.THROTTLE then
        if keep and not pending[channel] and _G.C_Timer then
            pending[channel] = true
            _G.C_Timer.After(self.THROTTLE - (t - last), function()
                pending[channel] = nil
                VersionCheck:Announce(channel)
            end)
        end
        return false
    end
    lastSent[channel] = t
    send(channel, version)
    return true
end

local function announceGroup(keep)
    local channel = groupChannel()
    if channel then VersionCheck:Announce(channel, keep) end
end

local function announceGuild()
    if guildDone or not (_G.IsInGuild and _G.IsInGuild()) then return end
    guildDone = true
    VersionCheck:Announce("GUILD")
end

-------------------------------------------------------------------------------
-- Receiving
-------------------------------------------------------------------------------

-- A version heard from another copy on channel.
function VersionCheck:OnMessage(version, channel)
    if not enabled() then return end
    local mine = self:MyVersion()
    local cmp = mine and VersionCheck.Compare(version, mine)
    if not cmp then return end
    if cmp < 0 then
        -- The sender is behind: tell that channel about this version.
        if channel == "GUILD" or channel == "PARTY" or channel == "RAID" or channel == "INSTANCE_CHAT" then
            self:Announce(channel, true)
        end
        return
    end
    if cmp == 0 then return end
    if not newest or VersionCheck.Compare(version, newest) > 0 then newest = version end
    if warned then return end
    warned = true
    local Nx = _G.Nx
    local text = format(L["There is a new version of Carbonite-Forever (%s). Update it with your addon manager or from the releases page."], newest)
    if Nx and Nx.prt then Nx.prt("%s", text) end
end

-- Newest version heard this session, or nil.
function VersionCheck:Newest()
    return newest
end

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------

function VersionCheck:OnEvent(event, ...)
    if event == "CHAT_MSG_ADDON" then
        local prefix, message, channel = ...
        if prefix == self.PREFIX then self:OnMessage(message, channel) end
    elseif event == "PLAYER_LOGIN" then
        if _G.C_Timer then
            _G.C_Timer.After(self.LOGIN_DELAY, function()
                ready = true
                groupSize = _G.GetNumGroupMembers and _G.GetNumGroupMembers() or 0
                announceGroup()
                announceGuild()
            end)
        end
    elseif not ready then
        return
    elseif event == "GROUP_ROSTER_UPDATE" then
        -- Only when someone joins: leaving or a role change sends nothing.
        local size = _G.GetNumGroupMembers and _G.GetNumGroupMembers() or 0
        local grew = size > groupSize
        groupSize = size
        if grew then announceGroup(true) end
    elseif event == "GUILD_ROSTER_UPDATE" or event == "PLAYER_GUILD_UPDATE" then
        announceGuild()
    end
end

local chat = _G.C_ChatInfo
local register = chat and chat.RegisterAddonMessagePrefix or _G.RegisterAddonMessagePrefix
if register then register(VersionCheck.PREFIX) end

local frame = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_LOGIN", "CHAT_MSG_ADDON", "GROUP_ROSTER_UPDATE",
                         "GUILD_ROSTER_UPDATE", "PLAYER_GUILD_UPDATE" }) do
    frame:RegisterEvent(event)
end
frame:SetScript("OnEvent", function(_, event, ...) VersionCheck:OnEvent(event, ...) end)
VersionCheck.frame = frame
