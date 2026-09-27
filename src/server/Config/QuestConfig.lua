--!strict
-- Quêtes de l'Alpha (voir docs/QUESTS.md). Uniquement des données : le code ne connaît aucune quête.
--   Objective.Event  : nom de l'événement gameplay qui fait progresser la quête.
--   Objective.Match  : champs que le payload de l'événement doit avoir, à l'identique.
--   Objective.Target : nombre d'événements correspondants pour terminer la quête.
--   NextQuestId      : quête activée après la réclamation de celle-ci (nil = fin de la chaîne).
-- Aucune récompense ici : les récompenses de Stage / First Clear relèvent de RewardService (#9).

local QuestConfig = {
	FirstQuestId = "DefendDomain",
	Quests = {
		DefendDomain = {
			Title = "Défends ton domaine",
			Objective = {
				Event = "StageCompleted",
				Match = { Zone = 1, Stage = 1 },
				Target = 1,
			},
			NextQuestId = nil,
		},
	},
}

return QuestConfig
