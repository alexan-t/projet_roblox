--!strict
-- Règles de présentation du panneau Quêtes (voir docs/QUESTS.md § Panneau). Module pur, sans Instance :
-- il ne calcule AUCUNE progression, il lit seulement les vues envoyées par QuestService (GetQuestLog,
-- GetActiveQuest / QuestChanged). Le serveur reste seul juge (ClaimQuest revérifie tout).
--   state(entry)      -> "Claimable" (terminée, à récupérer) | "InProgress" | "Claimed" ;
--   sorted(list)      -> copie triée : à récupérer, puis en cours, puis récupérées (ordre de la chaîne) ;
--   claimable(list)   -> nombre de quêtes à récupérer ;
--   summary(list)     -> ligne sous le titre du panneau ;
--   attention(active, seenId) -> le bouton Quêtes doit-il appeler le joueur : récompense à récupérer, dans
--                        n'importe quelle ligne (priorité absolue : ClaimableCount de la vue principale),
--                        ou nouvelle quête principale pas encore vue dans le panneau.
-- Le journal est regroupé par ligne (QuestService) : une entrée par ligne, son palier courant.

export type Entry = {
	Id: string,
	Progress: number,
	Target: number,
	Completed: boolean,
	Claimed: boolean?,
	AutoClaim: boolean?,
	-- vue principale : quêtes à récupérer, toutes lignes confondues
	ClaimableCount: number?,
}

local QuestLog = {}

-- Une quête AutoClaim terminée est réclamée par le serveur : jamais « à récupérer » côté joueur.
function QuestLog.state(entry: Entry): string
	if entry.Claimed == true or (entry.Completed and entry.AutoClaim == true) then
		return "Claimed"
	end
	if entry.Completed then
		return "Claimable"
	end
	return "InProgress"
end

-- Avancement affiché (0..1), borné ; une cible invalide compte pour 1.
function QuestLog.ratio(entry: Entry): number
	local target = math.max(entry.Target, 1)
	return math.clamp(entry.Progress, 0, target) / target
end

local RANK: { [string]: number } = { Claimable = 0, InProgress = 1, Claimed = 2 }

type Ranked = { entry: Entry, index: number, rank: number }

function QuestLog.sorted(list: { Entry }): { Entry }
	local indexed: { Ranked } = {}
	for index, entry in list do
		table.insert(indexed, { entry = entry, index = index, rank = RANK[QuestLog.state(entry)] })
	end
	table.sort(indexed, function(a: Ranked, b: Ranked): boolean
		if a.rank ~= b.rank then
			return a.rank < b.rank
		end
		-- récupérées : la plus récente d'abord ; sinon l'ordre de la chaîne
		if a.rank == RANK.Claimed then
			return a.index > b.index
		end
		return a.index < b.index
	end)
	local out = {}
	for _, item in indexed do
		table.insert(out, item.entry)
	end
	return out
end

function QuestLog.claimable(list: { Entry }): number
	local count = 0
	for _, entry in list do
		if QuestLog.state(entry) == "Claimable" then
			count += 1
		end
	end
	return count
end

function QuestLog.summary(list: { Entry }): string
	local claimable = QuestLog.claimable(list)
	if claimable > 0 then
		return `{claimable} récompense{if claimable > 1 then "s" else ""} à récupérer`
	end
	local running = 0
	for _, entry in list do
		if QuestLog.state(entry) == "InProgress" then
			running += 1
		end
	end
	if running > 0 then
		return `{running} quête{if running > 1 then "s" else ""} en cours`
	end
	return "Toutes les quêtes sont terminées"
end

-- active : vue de la quête active (ou nil) ; seenId : dernière quête active vue dans le panneau (ou nil
-- au chargement : la quête du join compte comme vue, pas de notification au démarrage).
function QuestLog.attention(active: Entry?, seenId: string?): boolean
	if not active then
		return false
	end
	if QuestLog.state(active) == "Claimable" or (active.ClaimableCount or 0) > 0 then
		return true
	end
	return seenId ~= nil and active.Id ~= seenId and QuestLog.state(active) == "InProgress"
end

return QuestLog
