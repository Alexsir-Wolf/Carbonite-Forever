-- Notice of a newer Carbonite-Forever (#92): Carbonite/Modules/Comm/VersionCheck.lua

local MINE = "v12.1.0-00023-forever.3"

-- Loads the module with a fake clock, timers, addon messages and chat.
-- Returns the module and a state table: sent, printed, timers, clock, general.
local function load(opts)
    opts = opts or {}
    local st = { sent = {}, printed = {}, timers = {}, clock = 1000, general = {}, registered = {} }
    local env = wow.env({
        GetTime = function() return st.clock end,
        C_Timer = { After = function(delay, fn) st.timers[#st.timers + 1] = { delay = delay, fn = fn } end },
        C_AddOns = { GetAddOnMetadata = function(addon, field)
            if addon == "Carbonite" and field == "Version" then return opts.version or MINE end
        end },
        C_ChatInfo = {
            RegisterAddonMessagePrefix = function(p) st.registered[#st.registered + 1] = p end,
            SendAddonMessage = function(prefix, msg, channel)
                st.sent[#st.sent + 1] = { prefix = prefix, msg = msg, channel = channel }
            end,
        },
        IsInRaid = function() return opts.raid == true end,
        IsInGroup = function() return opts.group == true end,
        IsInGuild = function() return opts.guild == true end,
        GetNumGroupMembers = function() return st.members or 0 end,
        Nx = { prt = function(fmt, ...) st.printed[#st.printed + 1] = string.format(fmt, ...) end },
    })
    env.Nx.db = { profile = { General = st.general } }
    loader.run(env, "Carbonite/Modules/Comm/VersionCheck.lua")
    return env.Carbonite.Modules.Comm.VersionCheck, st
end

-- Logs in and runs the login timer.
local function login(VC, st)
    VC:OnEvent("PLAYER_LOGIN")
    local t = table.remove(st.timers, 1)
    t.fn()
end

describe("VersionCheck.Compare", function()
    local VC = load()

    it("compara as partes numéricas e o número após -forever.", function()
        expect(VC.Compare("v12.1.0-00023-forever.4", MINE)).toBe(1)
        expect(VC.Compare("v12.1.0-00023-forever.2", MINE)).toBe(-1)
        expect(VC.Compare(MINE, MINE)).toBe(0)
        expect(VC.Compare("v12.2.0-00001-forever.1", MINE)).toBe(1)
        expect(VC.Compare("v12.1.0-00024-forever.1", MINE)).toBe(1)
        expect(VC.Compare("v12.1.0-00023-forever.10", "v12.1.0-00023-forever.9")).toBe(1)
        expect(VC.Compare("v13.0.0-00001-forever.1", "v12.9.9-00099-forever.99")).toBe(1)
    end)

    it("ignora versões de desenvolvimento", function()
        expect(VC.Compare("@project-version@", MINE)).toBeNil()
        expect(VC.Compare("v12.1.0-00023-forever.4-dev", MINE)).toBeNil()
        expect(VC.Compare("v12.1.0-00023-forever.4-2-gabc1234", MINE)).toBeNil()
        expect(VC.Compare(MINE, "@project-version@")).toBeNil()
        expect(VC.Parse("v12.1.0-00023")).toBeNil()
        expect(VC.Parse(nil)).toBeNil()
    end)

    it("numeração própria: v1.0.0 é mais nova que qualquer -forever.N", function()
        expect(VC.Compare("v1.0.0", MINE)).toBe(1)
        expect(VC.Compare("v1.0.0", "v99.9.9-00099-forever.99")).toBe(1)
        expect(VC.Compare(MINE, "v1.0.0")).toBe(-1)
        expect(VC.Compare("v1.0.1", "v1.0.0")).toBe(1)
        expect(VC.Compare("v1.10.0", "v1.9.9")).toBe(1)
        expect(VC.Compare("v2.0.0", "v1.99.99")).toBe(1)
        expect(VC.Compare("v1.0.0", "v1.0.0")).toBe(0)
        expect(VC.Compare("v1.0.0-2-gabc1234", "v1.0.0")).toBeNil()
        expect(VC.Parse("v1.0")).toBeNil()
    end)
end)

describe("VersionCheck: anúncio", function()
    it("registra o prefixo e anuncia só a versão ao grupo e à guilda após o login", function()
        local VC, st = load({ group = true, guild = true })
        expect(st.registered[1]).toBe(VC.PREFIX)
        VC:OnEvent("GROUP_ROSTER_UPDATE")
        expect(#st.sent).toBe(0)
        VC:OnEvent("PLAYER_LOGIN")
        expect(st.timers[1].delay).toBe(VC.LOGIN_DELAY)
        st.timers[1].fn()
        expect(#st.sent).toBe(2)
        expect(st.sent[1].channel).toBe("PARTY")
        expect(st.sent[1].msg).toBe(MINE)
        expect(st.sent[2].channel).toBe("GUILD")
    end)

    it("uma cópia de desenvolvimento não anuncia", function()
        local VC, st = load({ group = true, version = "@project-version@" })
        login(VC, st)
        expect(#st.sent).toBe(0)
        expect(VC:MyVersion()).toBeNil()
    end)

    it("respeita o limite de 60 s por canal", function()
        local VC, st = load({ raid = true })
        login(VC, st)
        expect(#st.sent).toBe(1)
        st.clock = st.clock + 10
        expect(VC:Announce("RAID")).toBe(false)
        expect(#st.sent).toBe(1)
        expect(VC:Announce("GUILD")).toBe(true)
        st.clock = st.clock + 60
        expect(VC:Announce("RAID")).toBe(true)
        expect(#st.sent).toBe(3)
    end)

    it("entrada no grupo dentro do limite envia uma vez ao fim da janela", function()
        local VC, st = load({ group = true })
        st.members = 2
        login(VC, st)
        st.clock = st.clock + 20
        st.members = 3
        VC:OnEvent("GROUP_ROSTER_UPDATE")
        st.members = 4
        VC:OnEvent("GROUP_ROSTER_UPDATE")
        expect(#st.sent).toBe(1)
        expect(#st.timers).toBe(1)
        expect(st.timers[1].delay).toBe(40)
        st.clock = st.clock + 40
        st.timers[1].fn()
        expect(#st.sent).toBe(2)
    end)

    it("anuncia à guilda uma vez por sessão", function()
        local VC, st = load({ guild = true })
        login(VC, st)
        st.clock = st.clock + 600
        VC:OnEvent("GUILD_ROSTER_UPDATE")
        expect(#st.sent).toBe(1)
    end)

    it("a opção desligada não anuncia nem avisa", function()
        local VC, st = load({ group = true })
        st.general.VersionCheck = false
        login(VC, st)
        VC:OnEvent("CHAT_MSG_ADDON", VC.PREFIX, "v12.1.0-00023-forever.9", "PARTY", "Outro")
        expect(#st.sent).toBe(0)
        expect(#st.printed).toBe(0)
    end)
end)

describe("VersionCheck: aviso", function()
    it("avisa uma única vez por sessão com a versão mais nova", function()
        local VC, st = load()
        VC:OnEvent("CHAT_MSG_ADDON", VC.PREFIX, "v12.1.0-00023-forever.4", "PARTY", "A")
        VC:OnEvent("CHAT_MSG_ADDON", VC.PREFIX, "v12.1.0-00023-forever.5", "GUILD", "B")
        VC:OnEvent("CHAT_MSG_ADDON", VC.PREFIX, "v12.1.0-00023-forever.4", "PARTY", "A")
        expect(#st.printed).toBe(1)
        expect(st.printed[1]).toContain("(v12.1.0-00023-forever.4)")
        expect(VC:Newest()).toBe("v12.1.0-00023-forever.5")
    end)

    it("não avisa por versão igual, mais velha, de desenvolvimento ou outro prefixo", function()
        local VC, st = load()
        VC:OnEvent("CHAT_MSG_ADDON", VC.PREFIX, MINE, "PARTY", "A")
        VC:OnEvent("CHAT_MSG_ADDON", VC.PREFIX, "v12.1.0-00023-forever.2", "PARTY", "A")
        VC:OnEvent("CHAT_MSG_ADDON", VC.PREFIX, "v12.1.0-00023-forever.9-dev", "PARTY", "A")
        VC:OnEvent("CHAT_MSG_ADDON", "Crb", "v12.1.0-00023-forever.9", "PARTY", "A")
        expect(#st.printed).toBe(0)
    end)

    it("uma cópia de desenvolvimento não avisa", function()
        local VC, st = load({ version = "@project-version@" })
        VC:OnEvent("CHAT_MSG_ADDON", VC.PREFIX, "v12.1.0-00023-forever.9", "PARTY", "A")
        expect(#st.printed).toBe(0)
    end)

    it("responde no canal a quem tem versão mais velha", function()
        local VC, st = load()
        VC:OnEvent("CHAT_MSG_ADDON", VC.PREFIX, "v12.1.0-00023-forever.2", "RAID", "A")
        expect(#st.sent).toBe(1)
        expect(st.sent[1].channel).toBe("RAID")
        VC:OnEvent("CHAT_MSG_ADDON", VC.PREFIX, "v12.1.0-00023-forever.2", "WHISPER", "A")
        expect(#st.sent).toBe(1)
    end)
end)

describe("VersionCheck: registro", function()
    it("está no Modules.xml e no lint", function()
        expect(loader.read("Carbonite/Modules/Modules.xml")).toContain('Comm\\VersionCheck.lua')
        expect(loader.read(".luacheckrc")).toContain("Carbonite/Modules/Comm/VersionCheck.lua")
    end)
end)
