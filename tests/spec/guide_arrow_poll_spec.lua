-- RXP and Zygor arrow polls in Carbonite.Notes/Integrations (#24)

local cases = {
    { file = "Carbonite.Notes/Integrations/RXPArrow.lua", global = "RXP", label = "RXP" },
    { file = "Carbonite.Notes/Integrations/ZygorArrow.lua", global = "ZGV", label = "Zygor" },
}

-- Loads the file and fires PLAYER_LOGIN; returns the poll frame.
local function login(case, installed)
    local env = wow.lenientEnv(nil, installed and {} or { case.global })
    local frames = {}
    env.CreateFrame = function(_, name)
        local f = wow.frame(name)
        frames[#frames + 1] = f
        return f
    end
    env.Nx = wow.namespace({ Notes = {} })
    loader.run(env, case.file)
    local driver = frames[#frames]
    driver.scripts.OnEvent(driver, "PLAYER_LOGIN")
    return driver
end

for _, case in ipairs(cases) do
    describe(case.label .. ": seta de guia", function()
        it("não liga o OnUpdate sem o addon instalado", function()
            local driver = login(case, false)
            expect(driver.scripts.OnUpdate).toBeNil()
            expect(driver.events.PLAYER_LOGIN).toBeNil()
        end)

        it("liga o OnUpdate com o addon instalado", function()
            expect(type(login(case, true).scripts.OnUpdate)).toBe("function")
        end)
    end)
end
