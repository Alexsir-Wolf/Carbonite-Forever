-- Minimal test runner for Carbonite Forever. Runs on plain Lua 5.1 (CI) and on newer
-- interpreters (fengari, Lua 5.3/5.4), with no external rocks.
--
--   describe("name", function() it("does x", function() expect(a).toBe(b) end) end)

local H = {}

local results = { passed = 0, failed = 0, failures = {} }
local stack = {}

local function fullName(name)
    local parts = {}
    for i = 1, #stack do parts[#parts + 1] = stack[i] end
    parts[#parts + 1] = name
    return table.concat(parts, " > ")
end

function H.describe(name, fn)
    stack[#stack + 1] = name
    fn()
    stack[#stack] = nil
end

function H.it(name, fn)
    local ok, err = pcall(fn)
    if ok then
        results.passed = results.passed + 1
    else
        results.failed = results.failed + 1
        results.failures[#results.failures + 1] = fullName(name) .. "\n    " .. tostring(err)
    end
end

local function show(v)
    if type(v) == "string" then return string.format("%q", v) end
    return tostring(v)
end

local function deepEqual(a, b)
    if a == b then return true end
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    for k, v in pairs(a) do
        if not deepEqual(v, b[k]) then return false end
    end
    for k in pairs(b) do
        if a[k] == nil then return false end
    end
    return true
end

function H.expect(actual)
    local e = {}
    function e.toBe(expected)
        if actual ~= expected then
            error("expected " .. show(expected) .. ", got " .. show(actual), 2)
        end
    end
    function e.toEqual(expected)
        if not deepEqual(actual, expected) then
            error("tables differ", 2)
        end
    end
    function e.toBeTruthy()
        if not actual then error("expected truthy, got " .. show(actual), 2) end
    end
    function e.toBeFalsy()
        if actual then error("expected falsy, got " .. show(actual), 2) end
    end
    function e.toBeNil()
        if actual ~= nil then error("expected nil, got " .. show(actual), 2) end
    end
    function e.toContain(sub)
        if type(actual) ~= "string" or not string.find(actual, sub, 1, true) then
            error("expected " .. show(actual) .. " to contain " .. show(sub), 2)
        end
    end
    function e.toNotThrow()
        local ok, err = pcall(actual)
        if not ok then error("expected no error, got: " .. tostring(err), 2) end
    end
    return e
end

function H.results()
    return results
end

return H
