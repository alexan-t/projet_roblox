--!strict
-- Nom du store ProfileStore des données joueur (pur, testé par src/server/Tests/StoreName.spec.lua).
-- Hors Studio : toujours "PlayerData". En Studio : "PlayerData_Studio" (profil de travail), ou, pour une
-- recette, un store séparé "PlayerData_Recette_<nom>" choisi par l'attribut StoreRecette de
-- ServerStorage (docs/SECURITY.md § Recettes Studio). Un nom invalide ne retombe jamais sur le profil
-- de travail : il donne le store de recette générique.

local PREFIX = "PlayerData_Recette"

return function(isStudio: boolean, recette: any): string
	if not isStudio then
		return "PlayerData"
	end
	if recette == nil or recette == "" then
		return "PlayerData_Studio"
	end
	if type(recette) == "string" and #recette <= 32 and recette:match("^[%w_%-]+$") then
		return `{PREFIX}_{recette}`
	end
	return PREFIX
end
