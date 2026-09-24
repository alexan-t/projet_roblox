--!strict
-- Réglages globaux du jeu, partagés serveur et client.
-- Uniquement des constantes : aucune logique, aucun require de service.

local GameConfig = {
	Version = "0.0.1-alpha",
	-- Active Log.debug (repasser à false avant une publication).
	Debug = true,
}

return table.freeze(GameConfig)
