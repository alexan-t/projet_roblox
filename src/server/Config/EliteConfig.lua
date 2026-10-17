--!strict
-- Mode Élite (voir docs/ZONES.md § Mode Élite). Uniquement des données, lues par ZoneService.
-- L'Élite rejoue les stages de StageConfig (mêmes vagues, mêmes ennemis, mêmes EnemyId, même arène) avec
-- des ennemis plus forts : seules MaxHealth et AttackDamage de CombatConfig.Enemies sont multipliées,
-- côté serveur, pour la session (aucun autre réglage, ni cadence, ni portée, ni vitesse, ni présentation).
--
-- Zones[zone].UnlockAfter : First Clear NORMAL qui débloque l'Élite de la zone (clé de FirstClears).
-- Zones[zone].Stages[stage] : multiplicateurs de ce stage Élite. Un stage Élite n'est jouable qu'après
-- le First Clear Élite du précédent (Progression.EliteFirstClears) ; le premier, dès UnlockAfter.
--
-- VALEURS ALPHA 0.0.2 PROVISOIRES : de quoi tester la difficulté, pas un balancing final.

local EliteConfig = {
	Zones = {
		[1] = {
			UnlockAfter = "1-5", -- Roi Orc vaincu en Normal
			Stages = {
				[1] = table.freeze({ MaxHealth = 1.50, AttackDamage = 1.25 }),
				[2] = table.freeze({ MaxHealth = 1.65, AttackDamage = 1.30 }),
				[3] = table.freeze({ MaxHealth = 1.80, AttackDamage = 1.35 }),
				[4] = table.freeze({ MaxHealth = 2.00, AttackDamage = 1.40 }),
				[5] = table.freeze({ MaxHealth = 2.25, AttackDamage = 1.50 }),
			},
		},
	},
}

return EliteConfig
