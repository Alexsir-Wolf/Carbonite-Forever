-- Loads addon source files into a sandboxed environment, the same way the WoW client runs
-- them: file globals land in `env`, and `...` is (addonName, addonTable).

local L = {}

L.root = "."

-- Lua 5.1 has setfenv; 5.2+ takes the environment in load/loadfile.
local function loadWithEnv(path, env)
    local f, err
    if setfenv then
        f, err = loadfile(path)
        if f then setfenv(f, env) end
    else
        f, err = loadfile(path, "t", env)
    end
    if not f then error(err, 3) end
    return f
end

-- Run one addon file (path relative to the repository root) inside env.
function L.run(env, relPath, addonName, addonTable)
    local f = loadWithEnv(L.root .. "/" .. relPath, env)
    return f(addonName or "Carbonite", addonTable or {})
end

-- Read a source file as text (for static checks).
function L.read(relPath)
    local fh = assert(io.open(L.root .. "/" .. relPath, "rb"))
    local text = fh:read("*a")
    fh:close()
    return text
end

return L
