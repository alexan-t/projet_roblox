--!strict
-- Statistiques de combat de l'Alpha (voir docs/COMBAT.md).
-- VALEURS TEMPORAIRES, pas le balancing final : choisies pour un Stage 1-1 lisible, terminable
-- en une à deux minutes à x1 avec 3-4 héros, et perdu avec un héros seul.
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

	-- Ennemis : pas d'énergie ni d'ultime pour l'Alpha.
	Enemies = table.freeze({
		Slime = table.freeze({ MaxHealth = 60, AttackDamage = 6, AttackInterval = 1.2, AttackRange = 4, MoveSpeed = 6 }),
		Gobelin = table.freeze({ MaxHealth = 80, AttackDamage = 8, AttackInterval = 1.0, AttackRange = 5, MoveSpeed = 8 }),
		Boss = table.freeze({ MaxHealth = 450, AttackDamage = 18, AttackInterval = 1.5, AttackRange = 7, MoveSpeed = 6 }),
	}),
}

return table.freeze(CombatConfig)
