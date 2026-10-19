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
-- Tickets de replay : ALPHA 0.0.2 PROVISOIRE, table TicketEconomy ci-dessous.
--
-- Chaque stage DOIT avoir une entrée valide : RewardService est le propriétaire de FirstClears,
-- et le First Clear d'un stage déverrouille le suivant. 1-2 à 1-5 : listes VIDES, PROVISOIRES — le
-- First Clear est enregistré (déverrouillage) sans inventer d'économie ; le game design les définira.

local NONE = table.freeze({})

-- ALPHA 0.0.2 PROVISOIRE (#80). Tickets de replay centralisés : progression, boss et Élite.
-- 1-1 conserve son contrat tutoriel (+1 au First Clear). Accumulation : 20 boss normaux
-- ou 10 boss Élite rejoués donnent 100 tickets, hors quêtes et premiers clears.
local TicketEconomy = table.freeze({ Normal = table.freeze({ 0, 1, 1, 2, 5 }), Elite = table.freeze({ 2, 2, 2, 2, 10 }) })
local function replayTickets(mode: string, stage: number): { any }
	return { { Kind = "SummonTicket", Amount = (TicketEconomy :: any)[mode][stage] } }
end

-- Replay du premier stage d'une zone 2 à 6 : le même que 1-1 (aucun ticket au rang 1 de TicketEconomy).
local ENTRY_REPEAT = table.freeze({ table.freeze({ Kind = "Gold", Amount = 20 }) })

local RewardConfig = {
	TicketEconomy = TicketEconomy,
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
		["1-2"] = { FirstClearReward = NONE, RepeatReward = replayTickets("Normal", 2) },
		["1-3"] = { FirstClearReward = NONE, RepeatReward = replayTickets("Normal", 3) },
		["1-4"] = { FirstClearReward = NONE, RepeatReward = replayTickets("Normal", 4) },
		["1-5"] = { FirstClearReward = NONE, RepeatReward = replayTickets("Normal", 5) },
		-- Zones 2 à 6 : mêmes règles que la Zone 1 (First Clear vide PROVISOIRE, il déverrouille le stage
		-- suivant ; replay : l'or de 1-1 pour X-1, puis les tickets de TicketEconomy selon le rang du stage).
		["2-1"] = { FirstClearReward = NONE, RepeatReward = ENTRY_REPEAT },
		["2-2"] = { FirstClearReward = NONE, RepeatReward = replayTickets("Normal", 2) },
		["2-3"] = { FirstClearReward = NONE, RepeatReward = replayTickets("Normal", 3) },
		["2-4"] = { FirstClearReward = NONE, RepeatReward = replayTickets("Normal", 4) },
		["2-5"] = { FirstClearReward = NONE, RepeatReward = replayTickets("Normal", 5) },
		["3-1"] = { FirstClearReward = NONE, RepeatReward = ENTRY_REPEAT },
		["3-2"] = { FirstClearReward = NONE, RepeatReward = replayTickets("Normal", 2) },
		["3-3"] = { FirstClearReward = NONE, RepeatReward = replayTickets("Normal", 3) },
		["3-4"] = { FirstClearReward = NONE, RepeatReward = replayTickets("Normal", 4) },
		["3-5"] = { FirstClearReward = NONE, RepeatReward = replayTickets("Normal", 5) },
		["4-1"] = { FirstClearReward = NONE, RepeatReward = ENTRY_REPEAT },
		["4-2"] = { FirstClearReward = NONE, RepeatReward = replayTickets("Normal", 2) },
		["4-3"] = { FirstClearReward = NONE, RepeatReward = replayTickets("Normal", 3) },
		["4-4"] = { FirstClearReward = NONE, RepeatReward = replayTickets("Normal", 4) },
		["4-5"] = { FirstClearReward = NONE, RepeatReward = replayTickets("Normal", 5) },
		["5-1"] = { FirstClearReward = NONE, RepeatReward = ENTRY_REPEAT },
		["5-2"] = { FirstClearReward = NONE, RepeatReward = replayTickets("Normal", 2) },
		["5-3"] = { FirstClearReward = NONE, RepeatReward = replayTickets("Normal", 3) },
		["5-4"] = { FirstClearReward = NONE, RepeatReward = replayTickets("Normal", 4) },
		["5-5"] = { FirstClearReward = NONE, RepeatReward = replayTickets("Normal", 5) },
		["6-1"] = { FirstClearReward = NONE, RepeatReward = ENTRY_REPEAT },
		["6-2"] = { FirstClearReward = NONE, RepeatReward = replayTickets("Normal", 2) },
		["6-3"] = { FirstClearReward = NONE, RepeatReward = replayTickets("Normal", 3) },
		["6-4"] = { FirstClearReward = NONE, RepeatReward = replayTickets("Normal", 4) },
		["6-5"] = { FirstClearReward = NONE, RepeatReward = replayTickets("Normal", 5) },
	},
	-- Mode Élite (#69) : même format, clé "<zone>-<stage>" du stage Élite. Le First Clear Élite est
	-- enregistré dans Progression.EliteFirstClears (il débloque le stage Élite suivant). Listes VIDES,
	-- PROVISOIRES pour le First Clear ; les tickets de replay suivent TicketEconomy (#80).
	EliteStages = {
		["1-1"] = { FirstClearReward = NONE, RepeatReward = replayTickets("Elite", 1) },
		["1-2"] = { FirstClearReward = NONE, RepeatReward = replayTickets("Elite", 2) },
		["1-3"] = { FirstClearReward = NONE, RepeatReward = replayTickets("Elite", 3) },
		["1-4"] = { FirstClearReward = NONE, RepeatReward = replayTickets("Elite", 4) },
		["1-5"] = { FirstClearReward = NONE, RepeatReward = replayTickets("Elite", 5) },
	},
}

return RewardConfig
