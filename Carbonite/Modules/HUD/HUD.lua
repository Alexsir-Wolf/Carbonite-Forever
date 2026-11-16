-- Carbonite | Modules / HUD
-- Module shell for the heads-up directional arrow. Defines saved-
-- variable defaults, lifecycle (Show/Hide/Toggle) and
-- the /hud slash command. The frame creation, options application
-- and per-frame Update live in HUDEngine.lua, which attaches its
-- methods to this same module instance and re-anchors Nx.HUD so
-- legacy callers (NxMap, NxOptions, Carbonite.lua) continue to
-- resolve `Nx.HUD:Method()` to the module's methods.

local Carbonite = _G.Carbonite
local Module = Carbonite.Core.Module

local HUD = Module:New("HUD", {
    defaults = {
        profile = {
            HUD = {
                Enabled       = false,
            },
        },
    },
})

-- Show / Hide / Toggle wrap the engine in HUDEngine.lua (HUD:Open
-- builds the frame on first call; HUD.Win:Show(false) hides it).
function HUD:ShowWindow()
    if self.Open then self:Open() end
    self.visible = true
    Carbonite.Core.EventBus:Fire("HUD_OPENED")
end

function HUD:HideWindow()
    if self.Win and self.Win.Show then self.Win:Show(false) end
    self.visible = false
    Carbonite.Core.EventBus:Fire("HUD_CLOSED")
end

function HUD:Toggle()
    if self.visible then self:HideWindow() else self:ShowWindow() end
end

function HUD:OnEnable()
    local db = self:DB() and self:DB().profile or {}

    if db.Enabled then self:ShowWindow() end

    Carbonite.Core.SlashCommands:Register("hud", function(rest)
        rest = rest:lower()
        if rest == "show" then self:ShowWindow()
        elseif rest == "hide" then self:HideWindow()
        else self:Toggle() end
    end, "show / hide / toggle the directional HUD")
end
