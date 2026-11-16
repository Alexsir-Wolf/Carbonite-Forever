if ( GetLocale() ~= "ptBR" ) then
	return;
end

local L = LibStub("AceLocale-3.0"):NewLocale("Carbonite", "ptBR")
if not L then return end

L["NxMAPTOGORIGINAL"] = "Mostrar/ocultar o mapa da Blizzard"
L["NxMAPTOGNORMMAX"] = "Alternar o tamanho do mapa"
L["NxMAPTOGNONEMAX"] = "Mostrar/ocultar o mapa em tela cheia"
L["NxMAPTOGNONENORM"] = "Mostrar/ocultar o mapa"
L["NxMAPSCALERESTORE"] = "Restaurar o zoom do mapa"
L["NxMAPTOGMINIFULL"] = "Alternar minimapa/mapa cheio"
L["NxMAPTOGHERB"] = "Mostrar/ocultar ervas"
L["NxMAPTOGMINE"] = "Mostrar/ocultar minérios"
L["NxTOGGLEGUIDE"] = "Mostrar/ocultar o Guia"
L["NxMAPSKIPTARGET"] = "Pular o destino atual"
L["NxMAPCLEARTARGET"] = "Limpar os destinos"
L["NxOPENOPTIONS"] = "Abrir as Opções"
L["NxTOGGLEHUD"] = "Mostrar/ocultar o HUD de rastreamento"
L["NxTOGGLEINFO"] = "Mostrar/ocultar o Info"
L["NxMAPTOGTIMBER"] = "mostrar/ocultar Madeira"
