--!strict
-- PROTOTYPE de préparation de combat (voir docs/ARENA_PROTOTYPE.md).
-- Partagé : le client en lit la limite et l'arène ; le serveur reste seul juge.

local ArenaConfig = {
	-- Arène de test, depuis Workspace (la seule arène complète de la DEV).
	ArenaPath = table.freeze({ "PlotTravail", "Arene" }),
	-- En Studio uniquement : chaque apparition du personnage est déplacée sur ce repère (depuis Workspace),
	-- à côté de l'arène de test, après le placement de PlotService. nil = désactivé.
	TestSpawn = table.freeze({ "PlotTravail", "PointApparition" }),
	-- Stage lancé depuis l'arène de test.
	Zone = 1,
	Stage = 1,
	-- Nombre maximum de héros posés sur le 3x3 (la hotbar en contient 10 : c'est voulu).
	MaxHeroes = 4,
	-- Les héros eux-mêmes (noms, icônes, kit de départ) sont dans HeroConfig.
	-- Modèles temporaires de ReplicatedStorage.Assets.Combat (mannequins du design).
	HeroTemplate = "MannequinHeros",
	EnemyTemplates = table.freeze({
		Slime = "MannequinSlime",
		Gobelin = "MannequinGobelin",
		Boss = "MannequinBoss",
	}),
}

return table.freeze(ArenaConfig)
