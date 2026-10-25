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
		-- Boss validés des zones 2, 3, 5 et 6 (le Roi Orc garde l'EnemyId "Boss" en Zone 1 et 4).
		KingSlime = table.freeze({ MaxHealth = 520, AttackDamage = 16, AttackInterval = 1.3, AttackRange = 7, MoveSpeed = 5 }),
		KingTreant = table.freeze({ MaxHealth = 600, AttackDamage = 20, AttackInterval = 1.7, AttackRange = 8, MoveSpeed = 4 }),
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
		}),
		DefaultEntrance = 1.6,
		-- Fin de combat : les modèles restent ce temps (outro du client : morts, sac, « VICTOIRE ! »),
		-- puis la préparation est reconstruite. Rien ne disparaît d'un coup.
		EndHold = 6,
	}),
}

return table.freeze(CombatConfig)
