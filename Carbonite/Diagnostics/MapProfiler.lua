-- Maps exposes a scoped view of the shared measurement source.
local Carbonite, Nx = _G.Carbonite, _G.Nx
if not Carbonite or not Nx or not Carbonite.CreateDiagnosticProfiler then return end
local map = Carbonite.CreateDiagnosticProfiler("map")
Nx.MapProfiler = map
Carbonite.Modules.MapProfiler = map
