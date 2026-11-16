-- Carbonite | Modules / SlashHandler / SlashCommandEngine
-- The /carb subcommands that used to live in the legacy elseif chain
-- (Nx.slashCommand), now registered on Carbonite.Core.SlashCommands.
-- Commands another module already registers (options, winpos, events,
-- loot, capture, the debug flags...) are not repeated here.

local SlashCommands = Carbonite.Core.SlashCommands

local function map()
    return Nx.Map:GetMap(1)
end

local function firstWord(rest)
    return rest:match("^(%S*)")
end

SlashCommands:Register("goto", function(rest) map():SetTargetAtStr(rest) end,
    "[zone] x y - set the map destination")
SlashCommands:Register("gotoadd", function(rest) map():SetTargetAtStr(rest, true) end,
    "[zone] x y - add a map destination")
SlashCommands:Register("menu", function() Nx.NXMiniMapBut:OpenMenu() end,
    "open the Carbonite menu")
SlashCommands:Register("rl", function() ReloadUI() end, "reload the interface")
SlashCommands:Register("track", function(rest)
    local name = firstWord(rest)
    if name ~= "" then map().TrackPlyrs[name] = true end
end, "name - track a player on the map")
SlashCommands:Register("com", function() Nx.Com.List:Open() end,
    "open the list of Carbonite players")

-- Developer tools: /carb debug <command>.
SlashCommands:RegisterDebug("verbose", function()
    Nx.DebugOn = not Nx.DebugOn
    Nx.prt("Carbonite Debug: %s", Nx.DebugOn and "On" or "Off")
end, "toggle Carbonite debug messages in the chat")
SlashCommands:RegisterDebug("editmode", function() map():ToggleEditMode() end,
    "toggle the quest objective rectangle editor")
SlashCommands:RegisterDebug("comt", function(rest)
    local a1, a2 = rest:match("^(%S*)%s*(%S*)")
    Nx.Com:Test(a1, a2)
end, "send a comm test message")
SlashCommands:RegisterDebug("unitc", function()
    Nx.db.profile.Debug.DebugUnit = true
    Nx:UnitDCapture()
end, "capture the data of the unit under the mouse")
SlashCommands:RegisterDebug("vehpos", function() map():VehicleDumpPos() end,
    "print the vehicle positions on the map")
SlashCommands:RegisterDebug("item", function(rest)
    local id = format("Hitem:%s", firstWord(rest))
    Nx.TooltipText:SetOwner(UIParent, "ANCHOR_LEFT", 0, 0)
    Nx.TooltipText:SetHyperlink(id)
    local name, link = C_Item.GetItemInfo(id)
    Nx.prt("Item: %s %s", name or "nil", link or "")
end, "id - print an item")
SlashCommands:RegisterDebug("questclr", function() Nx.Quest:ClearCaptured() end,
    "clear the captured quest data")
SlashCommands:RegisterDebug("herb", function(rest) Nx.UEvents:AddHerb(strtrim(rest)) end,
    "name - record an herb event")
SlashCommands:RegisterDebug("mine", function(rest) Nx.UEvents:AddMine(strtrim(rest)) end,
    "name - record a mining event")
SlashCommands:RegisterDebug("addopen", function(rest)
    local a1, a2 = rest:match("^(%S*)%s*(%S*)")
    Nx.UEvents:AddOpen(a1, a2)
end, "name - record an opened object")
SlashCommands:RegisterDebug("kill", function(rest) Nx.UEvents:AddKill(firstWord(rest)) end,
    "name - record a kill event")
