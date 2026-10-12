--!strict
-- Zones et stages de l'Alpha (voir docs/ZONES.md). Uniquement des données : ZoneService ne connaît aucun stage.
--   Zones[zoneId].Stages[stageId] : identifiants entiers consécutifs à partir de 1.
--   Waves  : vagues dans l'ordre, chacune avec ses groupes d'ennemis { EnemyId, Count }.
--   MiniBoss : { EnemyId } facultatif, après la dernière vague (le boss de zone).
-- EnemyId est un identifiant logique ("Slime", "Gobelin", "Boss") ; statistiques, modèles et
-- animations y sont associés par CombatConfig et ArenaConfig.EnemyTemplates, pas ici.
-- Aucune récompense ici : elles relèvent de RewardService (#9).
--
-- Convention de progression d'une zone Alpha : X-1 à X-4 = ennemis communs, X-5 = boss de zone.
-- Zone 1 : boss = "Boss" (modèle Ennemi_RoiOrc, le Roi Orc). Simulations (CombatEngine + CombatConfig,
-- 20 tirages) : 1-1 gagné par l'Écuyer seul ; 1-1 à 1-5 gagnés par l'Écuyer + la Tireuse (équipe garantie
-- après la première invocation). PV ennemis totaux : 280, 340, 480, 520, 650.

local StageConfig = {
	Zones = {
		[1] = {
			Stages = {
				-- 1-1 : stage d'entrée, gagnable par le héros de départ seul.
				[1] = {
					Waves = {
						{ Enemies = { { EnemyId = "Slime", Count = 2 }, { EnemyId = "Gobelin", Count = 2 } } },
					},
				},
				[2] = {
					Waves = {
						{ Enemies = { { EnemyId = "Slime", Count = 3 }, { EnemyId = "Gobelin", Count = 2 } } },
					},
				},
				[3] = {
					Waves = {
						{ Enemies = { { EnemyId = "Slime", Count = 2 }, { EnemyId = "Gobelin", Count = 2 } } },
						{ Enemies = { { EnemyId = "Slime", Count = 2 }, { EnemyId = "Gobelin", Count = 1 } } },
					},
				},
				[4] = {
					Waves = {
						{ Enemies = { { EnemyId = "Slime", Count = 2 }, { EnemyId = "Gobelin", Count = 2 } } },
						{ Enemies = { { EnemyId = "Gobelin", Count = 3 } } },
					},
				},
				-- 1-5 : boss de zone (Roi Orc), précédé d'une petite vague.
				[5] = {
					Waves = {
						{ Enemies = { { EnemyId = "Slime", Count = 2 }, { EnemyId = "Gobelin", Count = 1 } } },
					},
					MiniBoss = { EnemyId = "Boss" },
				},
			},
		},
	},
}

return StageConfig
