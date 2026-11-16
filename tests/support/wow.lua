-- Small stand-ins for the WoW client API, enough to load single Carbonite files.
-- Each test builds a fresh environment with W.env(overrides).

local W = {}

-- A frame that records what was done to it and accepts any method call.
function W.frame(name)
    local f = { name = name, scripts = {}, events = {}, shown = true }
    local mt = {}
    function mt.__index(t, k)
        return function(self, ...)
            local args = { ... }
            if k == "SetScript" then
                self.scripts[args[1]] = args[2]
            elseif k == "GetScript" then
                return self.scripts[args[1]]
            elseif k == "RegisterEvent" then
                self.events[args[1]] = true
            elseif k == "UnregisterEvent" then
                self.events[args[1]] = nil
            elseif k == "Show" then
                self.shown = true
            elseif k == "Hide" then
                self.shown = false
            elseif k == "IsShown" or k == "IsVisible" then
                return self.shown
            elseif k == "GetName" then
                return self.name
            end
        end
    end
    return setmetatable(f, mt)
end

-- EventBus stand-in: keeps subscribers so tests can fire Carbonite events.
function W.eventBus()
    local bus = { subs = {}, fired = {} }
    function bus:Subscribe(event, fn)
        self.subs[event] = self.subs[event] or {}
        table.insert(self.subs[event], fn)
    end
    function bus:Fire(event, ...)
        table.insert(self.fired, { event, ... })
        for _, fn in ipairs(self.subs[event] or {}) do fn(event, ...) end
    end
    return bus
end

function W.env(overrides)
    local env = {}
    env._G = env
    -- Lua standard library.
    for _, k in ipairs({ "assert", "error", "ipairs", "next", "pairs", "pcall", "print",
                         "rawget", "rawset", "select", "setmetatable", "getmetatable",
                         "tonumber", "tostring", "type", "unpack", "xpcall",
                         "math", "string", "table", "os" }) do
        env[k] = _G[k]
    end
    env.unpack = env.unpack or rawget(table, "unpack")
    -- WoW aliases of the standard library.
    env.format, env.strfind, env.strsub, env.strlower = string.format, string.find, string.sub, string.lower
    env.gsub, env.strmatch, env.strsplit = string.gsub, string.match, nil
    env.floor, env.ceil, env.max, env.min, env.abs = math.floor, math.ceil, math.max, math.min, math.abs
    env.tinsert, env.tremove, env.wipe = table.insert, table.remove, function(t)
        for k in pairs(t) do t[k] = nil end
        return t
    end
    env.CreateFrame = function(_, name) return W.frame(name) end
    -- LibStub("AceLocale-3.0"):GetLocale(...) gives a locale that returns the key.
    local locale = setmetatable({}, { __index = function(_, k) return k end })
    env.LibStub = function()
        return setmetatable({ GetLocale = function() return locale end },
            { __index = function() return W.anything() end })
    end
    env.C_Timer = { After = function(_, fn) fn() end }
    env.Enum = { UIMapType = { Cosmic = 0, World = 1, Continent = 2, Zone = 3, Dungeon = 4, Micro = 5, Orphan = 6 } }
    env.Carbonite = {
        Core = { EventBus = W.eventBus() },
        Modules = { Map = {} },
    }
    for k, v in pairs(overrides or {}) do env[k] = v end
    return env
end

-- A value that accepts anything: indexing, calling and arithmetic-free use return itself.
-- For files whose load-time code touches many client APIs a test does not care about.
function W.anything()
    local any = {}
    setmetatable(any, {
        __index = function() return any end,
        __call = function() return any end,
    })
    return any
end

-- Like W.env, but globals the test did not provide resolve to W.anything(), except the
-- names in `missing`, which stay nil (an API the simulated client lacks).
function W.lenientEnv(overrides, missing)
    local env = W.env(overrides)
    local any = W.anything()
    local absent = {}
    for _, name in ipairs(missing or {}) do absent[name] = true end
    return setmetatable(env, { __index = function(_, k)
        if absent[k] then return nil end
        return any
    end })
end

-- A namespace table such as Nx for files that define methods on many sub-tables: a missing
-- field becomes a new namespace (kept), so `function Nx.Font:Init()` and `Nx.Font.x` work.
function W.namespace(fields)
    local ns = fields or {}
    return setmetatable(ns, {
        __index = function(t, k)
            local sub = W.namespace()
            rawset(t, k, sub)
            return sub
        end,
        __call = function() return W.anything() end,
    })
end

return W
