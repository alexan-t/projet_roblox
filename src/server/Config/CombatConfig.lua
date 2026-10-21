--!strict
-- Statistiques de combat de l'Alpha (voir docs/COMBAT.md).
-- VALEURS TEMPORAIRES, pas le balancing final. Le Stage 1-1 (entrée, sans mini-boss) se gagne avec le
-- seul héros de départ ; un stage avec vague complète + mini-boss demande 3-4 héros (un héros seul y perd).
-- Seul le serveur lit ce fichier. Aucune stat dans StageConfig, ArenaConfig, les modèles ou le client.

local CombatConfig = {
	-- Pas fixe de simulation (1/TickRate s) ; un gros dt après un lag est plafonné à MaxFrameTime.
	TickRate = 20,
	MaxFrameTime = 0.25,
	-- Taille maximale d'une formation.
	MaxAllies = 4,
	-- Ultime générique : UltimateDamage à la cible et aux ennemis à moins de Radius studs d'elle.
	Ultimate = table.freeze({ Radius = 8 }),

	-- Héros : ils gagnent EnergyPerAttack par attaque ; à MaxEnergy, l'ultime est disponible.
	Heroes = table.freeze({
		Archer = table.freeze({ MaxHealth = 90, AttackDamage = 14, AttackInterval = 1.0, AttackRange = 24, MoveSpeed = 8, EnergyPerAttack = 20, MaxEnergy = 100, UltimateDamage = 60 }),
		Epeiste = table.freeze({ MaxHealth = 150, AttackDamage = 16, AttackInterval = 0.9, AttackRange = 5, MoveSpeed = 10, EnergyPerAttack = 20, MaxEnergy = 100, UltimateDamage = 70 }),
		Barbare = table.freeze({ MaxHealth = 170, AttackDamage = 22, AttackInterval = 1.3, AttackRange = 5, MoveSpeed = 9, EnergyPerAttack = 25, MaxEnergy = 100, UltimateDamage = 90 }),
		Paladin = table.freeze({ MaxHealth = 220, AttackDamage = 12, AttackInterval = 1.1, AttackRange = 5, MoveSpeed = 8, EnergyPerAttack = 20, MaxEnergy = 100, UltimateDamage = 60 }),
		Magicien = table.freeze({ MaxHealth = 80, AttackDamage = 18, AttackInterval = 1.4, AttackRange = 22, MoveSpeed = 7, EnergyPerAttack = 25, MaxEnergy = 100, UltimateDamage = 80 }),
		Tireur = table.freeze({ MaxHealth = 85, AttackDamage = 20, AttackInterval = 1.5, AttackRange = 28, MoveSpeed = 8, EnergyPerAttack = 20, MaxEnergy = 100, UltimateDamage = 70 }),
	}),

	-- Ennemis : pas d'énergie ni d'ultime pour l'Alpha. Stats de base, sans la difficulté de zone
	-- (StageConfig.Zones[zone].Difficulty) ni l'Élite, qui les multiplient pour la session.
	Enemies = table.freeze({
		Slime = table.freeze({ MaxHealth = 60, AttackDamage = 6, AttackInterval = 1.2, AttackRange = 4, MoveSpeed = 6 }),
		Gobelin = table.freeze({ MaxHealth = 80, AttackDamage = 8, AttackInterval = 1.0, AttackRange = 5, MoveSpeed = 8 }),
		Boss = table.freeze({ MaxHealth = 450, AttackDamage = 18, AttackInterval = 1.5, AttackRange = 7, MoveSpeed = 6 }),
		-- Zones 2 à 6 (monstres validés, docs/ZONES.md). Slimes : même gabarit, une nuance par élément.
		SlimePlante = table.freeze({ MaxHealth = 70, AttackDamage = 6, AttackInterval = 1.2, AttackRange = 4, MoveSpeed = 6 }),
		SlimeChampignon = table.freeze({ MaxHealth = 55, AttackDamage = 8, AttackInterval = 1.3, AttackRange = 4, MoveSpeed = 5 }),
		SlimeLave = table.freeze({ MaxHealth = 65, AttackDamage = 9, AttackInterval = 1.2, AttackRange = 4, MoveSpeed = 6 }),
		-- Gobelin à dague : moins de PV que le gobelin à lance, frappe plus vite.
		GobelinDague = table.freeze({ MaxHealth = 70, AttackDamage = 9, AttackInterval = 0.8, AttackRange = 4, MoveSpeed = 10 }),
		-- Tréants : monstres moyens (8 à 10 studs), lents et coriaces.
		Treant = table.freeze({ MaxHealth = 160, AttackDamage = 12, AttackInterval = 1.6, AttackRange = 6, MoveSpeed = 5 }),
		TreantArbre = table.freeze({ MaxHealth = 220, AttackDamage = 14, AttackInterval = 1.8, AttackRange = 7, MoveSpeed = 4 }),
		-- Boss validés (Slime King, King Tréant) de la version A des zones 2 à 6 : gardés (modèles, tests, aperçus) ;
		-- le Roi Orc garde l'EnemyId "Boss" en Zone 1.
		KingSlime = table.freeze({ MaxHealth = 520, AttackDamage = 16, AttackInterval = 1.3, AttackRange = 7, MoveSpeed = 5 }),
		KingTreant = table.freeze({ MaxHealth = 600, AttackDamage = 20, AttackInterval = 1.7, AttackRange = 8, MoveSpeed = 4 }),
		-- Zones 2 à 6, version B (faune des fiches automation/briefs, docs/ZONES.md) : chaque monstre reprend
		-- les stats de l'archétype qu'il remplace dans les vagues, l'équilibrage simulé (#13) ne change pas.
		-- Zone 2 — Le Royaume des Sables
		VaseDesSables = table.freeze({ MaxHealth = 60, AttackDamage = 6, AttackInterval = 1.2, AttackRange = 4, MoveSpeed = 6 }), -- comme Slime
		ChacalParchemin = table.freeze({ MaxHealth = 60, AttackDamage = 6, AttackInterval = 1.2, AttackRange = 4, MoveSpeed = 6 }), -- comme Slime
		ScarabeeForgeSoleil = table.freeze({ MaxHealth = 70, AttackDamage = 6, AttackInterval = 1.2, AttackRange = 4, MoveSpeed = 6 }), -- comme SlimePlante
		MangeDune = table.freeze({ MaxHealth = 70, AttackDamage = 6, AttackInterval = 1.2, AttackRange = 4, MoveSpeed = 6 }), -- comme SlimePlante
		GardienSansVisage = table.freeze({ MaxHealth = 55, AttackDamage = 8, AttackInterval = 1.3, AttackRange = 4, MoveSpeed = 5 }), -- comme SlimeChampignon
		ColosseEnseveli = table.freeze({ MaxHealth = 520, AttackDamage = 16, AttackInterval = 1.3, AttackRange = 7, MoveSpeed = 5 }), -- comme KingSlime
		-- Zone 3 — Le Royaume Gelé
		Givrelot = table.freeze({ MaxHealth = 70, AttackDamage = 6, AttackInterval = 1.2, AttackRange = 4, MoveSpeed = 6 }), -- comme SlimePlante
		CrocDeGlacier = table.freeze({ MaxHealth = 70, AttackDamage = 6, AttackInterval = 1.2, AttackRange = 4, MoveSpeed = 6 }), -- comme SlimePlante
		ArmureGelee = table.freeze({ MaxHealth = 80, AttackDamage = 8, AttackInterval = 1.0, AttackRange = 5, MoveSpeed = 8 }), -- comme Gobelin
		BonhommeRoyal = table.freeze({ MaxHealth = 80, AttackDamage = 8, AttackInterval = 1.0, AttackRange = 5, MoveSpeed = 8 }), -- comme Gobelin
		MammouthCristallin = table.freeze({ MaxHealth = 160, AttackDamage = 12, AttackInterval = 1.6, AttackRange = 6, MoveSpeed = 5 }), -- comme Treant
		RoiSansEte = table.freeze({ MaxHealth = 600, AttackDamage = 20, AttackInterval = 1.7, AttackRange = 8, MoveSpeed = 4 }), -- comme KingTreant
		-- Zone 4 — Les Forges
		ChevalierRivete = table.freeze({ MaxHealth = 80, AttackDamage = 8, AttackInterval = 1.0, AttackRange = 5, MoveSpeed = 8 }), -- comme Gobelin
		GolemCloche = table.freeze({ MaxHealth = 80, AttackDamage = 8, AttackInterval = 1.0, AttackRange = 5, MoveSpeed = 8 }), -- comme Gobelin
		FourneauAmbulant = table.freeze({ MaxHealth = 80, AttackDamage = 8, AttackInterval = 1.0, AttackRange = 5, MoveSpeed = 8 }), -- comme Gobelin
		Martelet = table.freeze({ MaxHealth = 70, AttackDamage = 9, AttackInterval = 0.8, AttackRange = 4, MoveSpeed = 10 }), -- comme GobelinDague
		Chaine = table.freeze({ MaxHealth = 70, AttackDamage = 9, AttackInterval = 0.8, AttackRange = 4, MoveSpeed = 10 }), -- comme GobelinDague
		MaitreDesForges = table.freeze({ MaxHealth = 450, AttackDamage = 18, AttackInterval = 1.5, AttackRange = 7, MoveSpeed = 6 }), -- comme Boss
		-- Zone 5 — Les Abysses
		MeduseCouronnee = table.freeze({ MaxHealth = 65, AttackDamage = 9, AttackInterval = 1.2, AttackRange = 4, MoveSpeed = 6 }), -- comme SlimeLave
		MureneMiroir = table.freeze({ MaxHealth = 65, AttackDamage = 9, AttackInterval = 1.2, AttackRange = 4, MoveSpeed = 6 }), -- comme SlimeLave
		CoffreBernard = table.freeze({ MaxHealth = 65, AttackDamage = 9, AttackInterval = 1.2, AttackRange = 4, MoveSpeed = 6 }), -- comme SlimeLave
		ChevalierNoye = table.freeze({ MaxHealth = 70, AttackDamage = 9, AttackInterval = 0.8, AttackRange = 4, MoveSpeed = 10 }), -- comme GobelinDague
		CrabeCathedrale = table.freeze({ MaxHealth = 70, AttackDamage = 9, AttackInterval = 0.8, AttackRange = 4, MoveSpeed = 10 }), -- comme GobelinDague
		Leviathan = table.freeze({ MaxHealth = 520, AttackDamage = 16, AttackInterval = 1.3, AttackRange = 7, MoveSpeed = 5 }), -- comme KingSlime
		-- Zone 6 — Les Îles du Ciel
		GargouilleAilee = table.freeze({ MaxHealth = 160, AttackDamage = 12, AttackInterval = 1.6, AttackRange = 6, MoveSpeed = 5 }), -- comme Treant
		MiniColosseCeleste = table.freeze({ MaxHealth = 160, AttackDamage = 12, AttackInterval = 1.6, AttackRange = 6, MoveSpeed = 5 }), -- comme Treant
		MoutonNuage = table.freeze({ MaxHealth = 55, AttackDamage = 8, AttackInterval = 1.3, AttackRange = 4, MoveSpeed = 5 }), -- comme SlimeChampignon
		PoissonDuCiel = table.freeze({ MaxHealth = 55, AttackDamage = 8, AttackInterval = 1.3, AttackRange = 4, MoveSpeed = 5 }), -- comme SlimeChampignon
		BecTonnerre = table.freeze({ MaxHealth = 220, AttackDamage = 14, AttackInterval = 1.8, AttackRange = 7, MoveSpeed = 4 }), -- comme TreantArbre
		GardienCeleste = table.freeze({ MaxHealth = 600, AttackDamage = 20, AttackInterval = 1.7, AttackRange = 8, MoveSpeed = 4 }), -- comme KingTreant
	}),
	-- Mise en scène (docs/COMBAT_PRESENTATION.md) : temps pendant lesquels CombatService ne fait PAS
	-- avancer le moteur, pour laisser le client faire entrer les ennemis. Aucune stat, aucune règle :
	-- le combat est seulement décalé. Envoyé au client par l'événement EntranceHold (Duration).
	Presentation = table.freeze({
		-- Après Prêt : la 1re vague sort du décor jusqu'à ses cases (respiration courte + plus longue entrée).
		StartBreather = 0.2,
		-- Avant une vague suivante ou le mini-boss : courte respiration, puis entrée depuis le décor.
		WaveBreather = 0.5,
		-- Durée de l'entrée par ennemi (la plus longue de la vague compte) ; inconnu : Default.
		Entrance = table.freeze({
			Slime = 1.4, Gobelin = 1.8, Boss = 2.6,
			SlimePlante = 1.4, SlimeChampignon = 1.4, SlimeLave = 1.4, GobelinDague = 1.8,
			Treant = 2.0, TreantArbre = 2.2, KingSlime = 2.6, KingTreant = 2.6,
			VaseDesSables = 1.4, ChacalParchemin = 1.4, ScarabeeForgeSoleil = 1.4, MangeDune = 1.4,
			GardienSansVisage = 1.4, ColosseEnseveli = 2.6, Givrelot = 1.4, CrocDeGlacier = 1.4, ArmureGelee = 1.8,
			BonhommeRoyal = 1.8, MammouthCristallin = 2.0, RoiSansEte = 2.6, ChevalierRivete = 1.8, GolemCloche = 1.8,
			FourneauAmbulant = 1.8, Martelet = 1.8, Chaine = 1.8, MaitreDesForges = 2.6, MeduseCouronnee = 1.4,
			MureneMiroir = 1.4, CoffreBernard = 1.4, ChevalierNoye = 1.8, CrabeCathedrale = 1.8, Leviathan = 2.6,
			GargouilleAilee = 2.0, MiniColosseCeleste = 2.0, MoutonNuage = 1.4, PoissonDuCiel = 1.4, BecTonnerre = 2.2,
			GardienCeleste = 2.6,
		}),
		DefaultEntrance = 1.6,
		-- Fin de combat : les modèles restent ce temps (outro du client : morts, sac, « VICTOIRE ! »),
		-- puis la préparation est reconstruite. Rien ne disparaît d'un coup.
		EndHold = 6,
	}),
}

return table.freeze(CombatConfig)
