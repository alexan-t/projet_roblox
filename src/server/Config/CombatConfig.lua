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

	-- Ennemis : pas d'énergie ni d'ultime pour l'Alpha.
	Enemies = table.freeze({
		Slime = table.freeze({ MaxHealth = 60, AttackDamage = 6, AttackInterval = 1.2, AttackRange = 4, MoveSpeed = 6 }),
		Gobelin = table.freeze({ MaxHealth = 80, AttackDamage = 8, AttackInterval = 1.0, AttackRange = 5, MoveSpeed = 8 }),
		Boss = table.freeze({ MaxHealth = 450, AttackDamage = 18, AttackInterval = 1.5, AttackRange = 7, MoveSpeed = 6 }),
	}),
	-- Mise en scène (docs/COMBAT_PRESENTATION.md) : temps pendant lesquels CombatService ne fait PAS
	-- avancer le moteur, pour laisser le client faire entrer les ennemis. Aucune stat, aucune règle :
	-- le combat est seulement décalé. Envoyé au client par l'événement EntranceHold (Duration).
	Presentation = table.freeze({
		-- Après Prêt : les ennemis déjà présentés rejoignent leur case (tirée par le moteur).
		StartHold = 0.6,
		-- Avant une vague suivante ou le mini-boss : courte respiration, puis entrée depuis le décor.
		WaveBreather = 0.5,
		-- Durée de l'entrée par ennemi (la plus longue de la vague compte) ; inconnu : Default.
		Entrance = table.freeze({ Slime = 1.4, Gobelin = 1.8, Boss = 2.6 }),
		DefaultEntrance = 1.6,
	}),
}

return table.freeze(CombatConfig)
