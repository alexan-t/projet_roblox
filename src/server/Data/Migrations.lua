--!strict
-- Migrations des données joueur entre versions.
-- Pour changer la structure :
--   1. incrémenter CURRENT_VERSION ;
--   2. ajouter STEPS[<ancienne version>] = function(data) ... end qui transforme les données en place ;
--   3. mettre à jour PlayerDataTypes et DefaultPlayerData.
-- Les nouvelles clés simples n'ont pas besoin de migration : Profile:Reconcile() les ajoute.
-- Une migration sert pour renommer, déplacer ou convertir une donnée existante.

local Migrations = {}

Migrations.CURRENT_VERSION = 1

local STEPS: { [number]: (data: { [string]: any }) -> () } = {
	-- [1] = function(data) -- v1 -> v2
	-- end,
}

export type Result = "Ok" | "TooNew" | "MissingStep"

-- Amène data à CURRENT_VERSION. Si le résultat n'est pas "Ok", data n'a pas été modifié :
--   "TooNew"      : données d'une version plus récente du jeu (serveur pas encore mis à jour) ;
--   "MissingStep" : une étape de migration manque dans STEPS.
function Migrations.run(data: { [string]: any }): Result
	local version = if typeof(data.DataVersion) == "number" then data.DataVersion else 1
	if version > Migrations.CURRENT_VERSION then
		return "TooNew"
	end
	for v = version, Migrations.CURRENT_VERSION - 1 do
		if not STEPS[v] then
			return "MissingStep"
		end
	end
	for v = version, Migrations.CURRENT_VERSION - 1 do
		STEPS[v](data)
	end
	data.DataVersion = Migrations.CURRENT_VERSION
	return "Ok"
end

return Migrations
