-- Runs the spec files given on the command line, from the repository root:
--   lua5.1 tests/run.lua tests/spec/*.lua
-- Exit status is 1 when any test fails.

package.path = "tests/support/?.lua;" .. package.path

local H = require("harness")

-- Spec files see describe/it/expect plus the support modules as globals.
describe, it, expect = H.describe, H.it, H.expect
loader = require("loader")
wow = require("wow")

local files = { ... }
if #files == 0 then
    io.stderr:write("usage: lua tests/run.lua <spec files>\n")
    os.exit(2)
end

for _, path in ipairs(files) do
    local chunk, err = loadfile(path)
    if not chunk then
        H.it(path, function() error(err) end)
    else
        H.describe(path, function()
            local ok, runErr = pcall(chunk)
            if not ok then H.it("(load)", function() error(runErr) end) end
        end)
    end
end

local r = H.results()
for _, failure in ipairs(r.failures) do
    print("FAIL " .. failure)
end
print(string.format("%d passed, %d failed", r.passed, r.failed))
os.exit(r.failed == 0 and 0 or 1)
