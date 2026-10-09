--!strict
-- Récompenses de stage (voir docs/REWARDS.md). Uniquement des données, lues par RewardService.
-- Clé = "<zone>-<stage>", la même que Progression.FirstClears.
--   FirstClearReward : donnée UNE seule fois par sauvegarde, à la première victoire du stage.
--   RepeatReward     : donnée à chaque victoire suivante (replay).
-- Une récompense = { Kind = "Gold" | "Gems" | "SummonTicket", Amount = entier >= 0, New = true? }
-- (New : simple indication pour l'écran de fin, badge « Nouveau » ; aucun effet de gameplay).
--
-- VALEURS ALPHA PROVISOIRES : aucun balancing officiel n'existe encore dans le projet.
-- Seul le ticket d'invocation du premier clear de 1-1 est une exigence (#9, nécessaire à #10).
-- Or et gemmes sont des valeurs de départ à ajuster avec le game design.

local RewardConfig = {
	Stages = {
		["1-1"] = {
			FirstClearReward = {
				{ Kind = "Gold", Amount = 100 },
				{ Kind = "Gems", Amount = 10 },
				{ Kind = "SummonTicket", Amount = 1, New = true },
			},
			RepeatReward = {
				{ Kind = "Gold", Amount = 20 },
			},
		},
	},
}

return RewardConfig
