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
	-- Dalle mise en avant par le tutoriel (première pose d'un héros, quête DefendDomain) : le centre,
	-- où le héros de départ seul gagne le 1-1 (simulations de StageConfig).
	PlacementSlot = 5,
	-- Les héros eux-mêmes (noms, icônes, modèle de combat) sont dans HeroConfig.
	HeroTemplate = "MannequinHeros",
	-- Modèles ennemis de ReplicatedStorage.Assets.Combat, copiés des monstres validés du partenaire :
	-- Gobelin et Roi Orc articulés (JeuAnimations : Marche, Attaque…), slime statique (pas de squelette).
	-- Les mannequins MannequinSlime / MannequinGobelin / MannequinBoss restent disponibles.
	-- Zones 2 à 6 : copies de combat des monstres validés du Bestiaire (tools/studio-zones-assets.luau).
	EnemyTemplates = table.freeze({
		Slime = "Ennemi_Slime",
		Gobelin = "Ennemi_Gobelin",
		Boss = "Ennemi_RoiOrc",
		SlimePlante = "Ennemi_SlimePlante",
		SlimeChampignon = "Ennemi_SlimeChampignon",
		SlimeLave = "Ennemi_SlimeLave",
		GobelinDague = "Ennemi_GobelinDague",
		Treant = "Ennemi_Treant",
		TreantArbre = "Ennemi_TreantArbre",
		KingSlime = "Ennemi_KingSlime",
		KingTreant = "Ennemi_KingTreant",
		VaseDesSables = "Ennemi_VaseDesSables",
		ChacalParchemin = "Ennemi_ChacalParchemin",
		ScarabeeForgeSoleil = "Ennemi_ScarabeeForgeSoleil",
		MangeDune = "Ennemi_MangeDune",
		GardienSansVisage = "Ennemi_GardienSansVisage",
		ColosseEnseveli = "Ennemi_ColosseEnseveli",
		Givrelot = "Ennemi_Givrelot",
		CrocDeGlacier = "Ennemi_CrocDeGlacier",
		ArmureGelee = "Ennemi_ArmureGelee",
		BonhommeRoyal = "Ennemi_BonhommeRoyal",
		MammouthCristallin = "Ennemi_MammouthCristallin",
		RoiSansEte = "Ennemi_RoiSansEte",
		ChevalierRivete = "Ennemi_ChevalierRivete",
		GolemCloche = "Ennemi_GolemCloche",
		FourneauAmbulant = "Ennemi_FourneauAmbulant",
		Martelet = "Ennemi_Martelet",
		Chaine = "Ennemi_Chaine",
		MaitreDesForges = "Ennemi_MaitreDesForges",
		MeduseCouronnee = "Ennemi_MeduseCouronnee",
		MureneMiroir = "Ennemi_MureneMiroir",
		CoffreBernard = "Ennemi_CoffreBernard",
		ChevalierNoye = "Ennemi_ChevalierNoye",
		CrabeCathedrale = "Ennemi_CrabeCathedrale",
		Leviathan = "Ennemi_Leviathan",
		GargouilleAilee = "Ennemi_GargouilleAilee",
		MiniColosseCeleste = "Ennemi_MiniColosseCeleste",
		MoutonNuage = "Ennemi_MoutonNuage",
		PoissonDuCiel = "Ennemi_PoissonDuCiel",
		BecTonnerre = "Ennemi_BecTonnerre",
		GardienCeleste = "Ennemi_GardienCeleste",
	}),
	-- Nom d'une zone (fenêtre Expédition « Zone n · Nom ») quand son décor n'est pas dans l'arène : le décor
	-- présent garde la priorité (attribut Nom du modèle de zone).
	ZoneNames = table.freeze({
		[1] = "La Plaine du Royaume",
		[2] = "Le Royaume des Sables",
		[3] = "Le Royaume Gelé",
		[4] = "Les Forges",
		[5] = "La Cité Engloutie",
		[6] = "Les Îles du Ciel",
	} :: { [number]: string }),
	-- Sous-titre d'une zone dans la fenêtre Expédition (texte seulement, maquette figée).
	ZoneSubtitles = table.freeze({
		[1] = "Prairies, slimes et la horde du Roi Orc",
		[2] = "Dunes, ruines ensevelies et le Colosse Enseveli",
		[3] = "Neige, glaciers et le Roi sans Été",
		[4] = "Enclumes, fer rougi et le Maître des Forges",
		[5] = "Une cité sous la mer, sa protection se fissure, et le Léviathan",
		[6] = "Nuages, îles flottantes et le Gardien Céleste",
	} :: { [number]: string }),
	-- Noms affichés (pancarte, fenêtre des stages, annonce de combat). Boss = le Roi Orc (Zone 1).
	EnemyNames = table.freeze({
		Slime = "Slime",
		Gobelin = "Gobelin",
		Boss = "Roi Orc",
		SlimePlante = "Slime des ronces",
		SlimeChampignon = "Slime champignon",
		SlimeLave = "Slime de lave",
		GobelinDague = "Gobelin à dague",
		Treant = "Tréant",
		TreantArbre = "Vieux Tréant",
		KingSlime = "Slime King",
		KingTreant = "King Tréant",
		VaseDesSables = "Vase des Sables",
		ChacalParchemin = "Chacal Parchemin",
		ScarabeeForgeSoleil = "Scarabée Forge-Soleil",
		MangeDune = "Mange-Dune",
		GardienSansVisage = "Gardien sans Visage",
		ColosseEnseveli = "Colosse Enseveli",
		Givrelot = "Givrelot",
		CrocDeGlacier = "Croc de Glacier",
		ArmureGelee = "Armure Gelée",
		BonhommeRoyal = "Bonhomme Royal",
		MammouthCristallin = "Mammouth Cristallin",
		RoiSansEte = "Roi sans Été",
		ChevalierRivete = "Chevalier Riveté",
		GolemCloche = "Golem Cloche",
		FourneauAmbulant = "Fourneau Ambulant",
		Martelet = "Martelet",
		Chaine = "Chaîné",
		MaitreDesForges = "Maître des Forges",
		MeduseCouronnee = "Méduse Couronnée",
		MureneMiroir = "Murène Miroir",
		CoffreBernard = "Coffre Bernard",
		ChevalierNoye = "Chevalier Noyé",
		CrabeCathedrale = "Crabe Cathédrale",
		Leviathan = "Léviathan",
		GargouilleAilee = "Gargouille Ailée",
		MiniColosseCeleste = "Mini Colosse Céleste",
		MoutonNuage = "Mouton Nuage",
		PoissonDuCiel = "Poisson du Ciel",
		BecTonnerre = "Bec Tonnerre",
		GardienCeleste = "Gardien Céleste",
	}),
}

return table.freeze(ArenaConfig)
