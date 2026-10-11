--!strict
-- Contrat des arènes personnelles (voir docs/ARENA_PROTOTYPE.md).

local ArenaConfig = {
	-- Enfant du plot attribué par PlotService.
	ArenaName = "Arene",
	-- Portée du prompt E (Placer / Remplacer / Reprendre) autour du point de pose d'une dalle (studs).
	PromptDistance = 8,
	-- Distance maximale vérifiée côté serveur pour poser / reprendre : portée du prompt + marge réseau.
	InteractionDistance = 14,
	-- Zone de préparation : cercle autour des dalles de l'arène + cette marge (studs). Le serveur
	-- refuse Placer / Reprendre / Prêt hors de cette zone ; le client n'y allume les dalles qu'à l'intérieur.
	ZoneMargin = 10,
	-- Stage proposé par défaut (avant tout choix sur la pancarte).
	Zone = 1,
	Stage = 1,
	-- Pancarte du stage de l'arène (enfant de Arene) et sa bannière (SurfaceGui côté client).
	SignName = "PanneauStage",
	SignBoard = "Banniere",
	-- Portée (studs) de la pancarte : prompt E, et distance vérifiée par le serveur pour choisir un
	-- stage / lancer le combat depuis la pancarte (en plus de la zone de préparation).
	SignDistance = 12,
	-- Nombre maximum de héros posés sur le 3x3 (la hotbar en contient 10 : c'est voulu).
	MaxHeroes = 4,
	-- Les héros eux-mêmes (noms, icônes, modèle de combat) sont dans HeroConfig.
	HeroTemplate = "MannequinHeros",
	-- Modèles ennemis de ReplicatedStorage.Assets.Combat, copiés des monstres validés du partenaire :
	-- Gobelin et Roi Orc articulés (JeuAnimations : Marche, Attaque…), slime statique (pas de squelette).
	-- Les mannequins MannequinSlime / MannequinGobelin / MannequinBoss restent disponibles.
	EnemyTemplates = table.freeze({
		Slime = "Ennemi_Slime",
		Gobelin = "Ennemi_Gobelin",
		Boss = "Ennemi_RoiOrc",
	}),
}

return table.freeze(ArenaConfig)
