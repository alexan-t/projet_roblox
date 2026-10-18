--!strict
-- Quêtes de l'Alpha (voir docs/QUESTS.md). Uniquement des données : le code ne connaît aucune quête.
--   Objective.Event  : nom de l'événement gameplay qui fait progresser la quête.
--   Objective.Match  : champs que le payload de l'événement doit avoir, à l'identique.
--   Objective.Target : nombre d'événements correspondants pour terminer la quête.
--   NextQuestId      : quête activée après la réclamation de celle-ci (nil = fin de la chaîne).
--   Guide            : optionnel, guidage visuel du client jusqu'à l'objectif (chemin lumineux au sol,
--                      cible qui pulse).
--     Guide.Target   : cible connue de Shared.Quests.QuestGuide (StageSign, SummonPortal, Arena, Kingdom,
--                      HeroPlacement), toujours résolue dans le plot du joueur.
--     Guide.Placement : optionnel (true) : tant qu'aucun héros n'est posé, le guidage apprend à poser un
--                      héros (héros de la hotbar et première dalle libre qui pulsent) avant la cible.
--   AutoClaim        : optionnel (true) : réclamée par le serveur dès qu'elle est terminée (pas de bouton
--                      « Récupérer ») ; le client annonce « Quête terminée ! » et passe à la suivante.
--                      Sans AutoClaim, la quête attend « Récupérer » (quêtes réclamables plus tard).
--   Onboarding       : optionnel (true) : quête d'accueil d'un nouveau profil ; au premier spawn de la
--                      session, la caméra est placée derrière le personnage, vers l'arène du plot.
--   Rewards          : optionnel, donné UNE fois à la réclamation, par le serveur :
--                      { { Kind = "Gold" | "Gems" | "SummonTicket", Amount = entier >= 1 } }.
-- Les récompenses de Stage / First Clear restent celles de RewardService (#9).
--
-- Objectif StageCompleted (Target 1, Match.Zone / Match.Stage) : un stage déjà gagné (First Clear)
-- avant que la quête devienne active la termine aussitôt (jamais de stage à refaire).
--
-- Chaîne de la Zone 1 :
--   SummonStarter (invocation tutorielle gratuite de l'Écuyer, SummonConfig.Starter ; AutoClaim, sans
--   récompense : l'Écuyer et son reveal SONT la récompense)
--   → DefendDomain (1-1) → DefendStage12 → DefendStage13 → DefendStage14 → DefeatRoiOrc (1-5, boss) → fin.
-- Les quêtes de stage attendent « Récupérer » : ce clic ouvre le reveal des récompenses (QuestRewardView).
-- Récompenses ALPHA PROVISOIRES, bonus de progression unique, à rebalancer ici seulement (les
-- récompenses de stage / First Clear / replay restent dans RewardConfig).

local QuestConfig = {
	FirstQuestId = "SummonStarter",
	Quests = {
		SummonStarter = {
			Title = "Invoque ton premier héros",
			Objective = {
				Event = "StarterHeroSummoned",
				Target = 1,
			},
			-- guidé jusqu'au portail de SON plot (invocation tutorielle gratuite)
			Guide = { Target = "SummonPortal" },
			AutoClaim = true,
			Onboarding = true,
			NextQuestId = "DefendDomain",
		},
		DefendDomain = {
			Title = "Gagne la défense 1-1",
			Objective = {
				Event = "StageCompleted",
				Match = { Zone = 1, Stage = 1 },
				Target = 1,
			},
			-- guidé jusqu'à la pancarte du stage de SON arène ; d'abord poser un héros sur une dalle
			Guide = { Target = "StageSign", Placement = true },
			Rewards = { { Kind = "Gold", Amount = 50 } },
			NextQuestId = "DefendStage12",
		},
		DefendStage12 = {
			Title = "Gagne la défense 1-2",
			Objective = { Event = "StageCompleted", Match = { Zone = 1, Stage = 2 }, Target = 1 },
			Guide = { Target = "StageSign" },
			Rewards = { { Kind = "Gold", Amount = 75 }, { Kind = "Gems", Amount = 5 } },
			NextQuestId = "DefendStage13",
		},
		DefendStage13 = {
			Title = "Gagne la défense 1-3",
			Objective = { Event = "StageCompleted", Match = { Zone = 1, Stage = 3 }, Target = 1 },
			Guide = { Target = "StageSign" },
			Rewards = { { Kind = "Gold", Amount = 100 }, { Kind = "Gems", Amount = 10 } },
			NextQuestId = "DefendStage14",
		},
		DefendStage14 = {
			Title = "Gagne la défense 1-4",
			Objective = { Event = "StageCompleted", Match = { Zone = 1, Stage = 4 }, Target = 1 },
			Guide = { Target = "StageSign" },
			Rewards = { { Kind = "Gold", Amount = 150 }, { Kind = "Gems", Amount = 15 } },
			NextQuestId = "DefeatRoiOrc",
		},
		-- 1-5 : gagner tout le stage, donc vaincre le boss de zone. Le nom doit rester celui de
		-- ArenaConfig.EnemyNames.Boss (vérifié par les tests de QuestService).
		DefeatRoiOrc = {
			Title = "Vaincre le Roi Orc",
			Objective = { Event = "StageCompleted", Match = { Zone = 1, Stage = 5 }, Target = 1 },
			Guide = { Target = "StageSign" },
			Rewards = { { Kind = "Gold", Amount = 250 }, { Kind = "Gems", Amount = 25 }, { Kind = "SummonTicket", Amount = 1 } },
			NextQuestId = nil,
		},
	},
}

return QuestConfig
