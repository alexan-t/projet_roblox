--!strict
-- Zones et stages de l'Alpha (voir docs/ZONES.md). Uniquement des données : ZoneService ne connaît aucun stage.
--   Zones[zoneId].Stages[stageId] : identifiants entiers consécutifs à partir de 1.
--   Waves  : vagues dans l'ordre, chacune avec ses groupes d'ennemis { EnemyId, Count }.
--   MiniBoss : { EnemyId } facultatif, après la dernière vague.
-- EnemyId est un identifiant logique. Il reprend les types de la vague de démonstration de
-- CombatIntroController ("Slime", "Gobelin", "Boss") ; les statistiques, modèles et animations
-- seront associés à ces identifiants par CombatService (#8), pas ici.
-- Aucune récompense ici : elles relèvent de RewardService (#9).

local StageConfig = {
	Zones = {
		[1] = {
			Stages = {
				[1] = {
					Waves = {
						{
							Enemies = {
								{ EnemyId = "Slime", Count = 2 },
								{ EnemyId = "Gobelin", Count = 4 },
							},
						},
					},
					MiniBoss = { EnemyId = "Boss" },
				},
			},
		},
	},
}

return StageConfig
