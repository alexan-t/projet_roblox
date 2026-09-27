--!strict
-- PROTOTYPE de préparation de combat (voir docs/ARENA_PROTOTYPE.md).
-- Partagé : le client en lit les classes et la limite pour son panneau ; le serveur reste seul juge.

local ArenaConfig = {
	-- Arène de test, depuis Workspace (la seule arène complète de la DEV).
	ArenaPath = table.freeze({ "PlotTravail", "Arene" }),
	-- En Studio uniquement : chaque apparition du personnage est déplacée sur ce repère (depuis Workspace),
	-- à côté de l'arène de test, après le placement de PlotService. nil = désactivé.
	TestSpawn = table.freeze({ "PlotTravail", "PointApparition" }),
	-- Stage lancé depuis l'arène de test.
	Zone = 1,
	Stage = 1,
	-- Nombre maximum de héros posés sur le 3x3.
	MaxHeroes = 4,
	-- Collection de héros du prototype : une unité de chaque classe (PlayerData.Heroes est encore vide).
	HeroClasses = table.freeze({
		table.freeze({ Id = "Archer", Name = "Archer" }),
		table.freeze({ Id = "Epeiste", Name = "Épéiste" }),
		table.freeze({ Id = "Barbare", Name = "Barbare" }),
		table.freeze({ Id = "Paladin", Name = "Paladin" }),
		table.freeze({ Id = "Magicien", Name = "Magicien" }),
		table.freeze({ Id = "Tireur", Name = "Tireur" }),
	}),
	-- Modèles temporaires de ReplicatedStorage.Assets.Combat (mannequins du design).
	HeroTemplate = "MannequinHeros",
	EnemyTemplates = table.freeze({
		Slime = "MannequinSlime",
		Gobelin = "MannequinGobelin",
		Boss = "MannequinBoss",
	}),
}

return table.freeze(ArenaConfig)
