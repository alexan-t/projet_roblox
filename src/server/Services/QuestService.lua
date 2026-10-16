--!strict
-- Quêtes du joueur (voir docs/QUESTS.md), pilotées par QuestConfig et sauvegardées dans PlayerData.Quests.
-- La quête active se déduit de la chaîne FirstQuestId -> NextQuestId : c'est la première quête
-- de la chaîne qui n'est pas encore réclamée. Aucun champ supplémentaire n'est sauvegardé.
-- Les autres services signalent le gameplay avec HandleGameplayEvent.
-- Remotes (lecture seule pour le client, le serveur décide tout) :
--   GetActiveQuest (RemoteFunction) -> vue de la quête active ({ Id, Title, Progress, Target, Completed,
--                                      GuideTarget?, GuidePlacement, AutoClaim, Onboarding }) ou nil ;
--   ClaimQuest (RemoteFunction)     -> (ok, raison?, récompenses?) : le client n'envoie que l'Id de quête,
--                                      revérifié ici ; les récompenses de la quête (QuestConfig.Rewards)
--                                      sont ajoutées UNE fois, sans yield, et renvoyées pour l'affichage ;
--   QuestChanged (RemoteEvent)      -> (vue ou nil, terminée?) à l'activation, à chaque progression et à
--                                      la réclamation. Jamais PlayerData. terminée = { Id, Title, Target, Rewards }
--                                      quand une quête AutoClaim vient d'être réclamée par le serveur
--                                      (le client annonce « Quête terminée ! » puis montre la suivante).
-- AutoClaim (QuestConfig) : la quête est réclamée dès qu'elle est terminée, dans la même section
-- synchrone que sa progression (récompenses éventuelles comprises), puis la suivante est activée.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Utils.Log)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)
local QuestGuide = require(ReplicatedStorage.Shared.Quests.QuestGuide)
local DataService = require(script.Parent.DataService)
local QuestConfig = require(script.Parent.Parent.Config.QuestConfig)

type PlayerData = PlayerDataTypes.PlayerData
type QuestState = PlayerDataTypes.QuestState
type Objective = { Event: string, Match: { [string]: any }?, Target: number }
type Reward = { Kind: string, Amount: number }
type Quest = {
	Title: string,
	Objective: Objective,
	NextQuestId: string?,
	Guide: { Target: string, Placement: boolean? }?,
	Rewards: { Reward }?,
	AutoClaim: boolean?,
	Onboarding: boolean?,
}

export type ActiveQuest = {
	Id: string,
	Title: string,
	Progress: number,
	Target: number,
	Completed: boolean,
	-- Présentation seulement : cible du chemin lumineux (QuestGuide), absente une fois la quête terminée ;
	-- GuidePlacement : apprendre d'abord à poser un héros (Guide.Placement).
	GuideTarget: string?,
	GuidePlacement: boolean,
	-- Réclamée par le serveur dès qu'elle est terminée (pas de bouton « Récupérer »).
	AutoClaim: boolean,
	-- Quête d'accueil d'un nouveau profil (caméra vers l'arène au premier spawn de la session).
	Onboarding: boolean,
	-- Récompenses annoncées (copie) : données à la réclamation.
	Rewards: { Reward },
}

-- Récompenses de quête : type -> monnaie de PlayerData.Currencies.
local REWARD_CURRENCY: { [string]: string } = {
	Gold = "Gold",
	Gems = "Gems",
	SummonTicket = "SummonTickets",
}

local SCOPE = "QuestService"

local QuestService = {}

local quests: { [string]: Quest } = {}
local firstQuestId: string? = nil
local changedEvent: RemoteEvent? = nil

export type Finished = { Id: string, Title: string, Target: number, Rewards: { Reward } }

-- Envoie la vue de la quête active au seul joueur concerné (nil : plus de quête), et la quête AutoClaim
-- qui vient d'être réclamée, s'il y en a une.
local function push(player: Player, finished: Finished?)
	local event = changedEvent
	if event and player.Parent ~= nil then
		event:FireClient(player, QuestService:GetActiveQuest(player), finished)
	end
end

local function isPositiveInteger(value: any): boolean
	return typeof(value) == "number" and value >= 1 and value % 1 == 0 and value < math.huge
end

-- Renvoie la liste des problèmes de la config ; vide si elle est utilisable.
local function validate(config: any): { string }
	local problems: { string } = {}
	if typeof(config) ~= "table" or typeof(config.Quests) ~= "table" then
		return { "QuestConfig.Quests doit être une table" }
	end
	for id, quest in config.Quests do
		local objective = if typeof(quest) == "table" then quest.Objective else nil
		if typeof(id) ~= "string" or typeof(quest) ~= "table" or typeof(quest.Title) ~= "string" then
			table.insert(problems, `quête {id} : Title manquant`)
		elseif typeof(objective) ~= "table" or typeof(objective.Event) ~= "string" or objective.Event == "" then
			table.insert(problems, `quête {id} : Objective.Event manquant`)
		elseif not isPositiveInteger(objective.Target) then
			table.insert(problems, `quête {id} : Objective.Target doit être un entier >= 1`)
		elseif objective.Match ~= nil and typeof(objective.Match) ~= "table" then
			table.insert(problems, `quête {id} : Objective.Match doit être une table`)
		elseif quest.NextQuestId ~= nil and config.Quests[quest.NextQuestId] == nil then
			table.insert(problems, `quête {id} : NextQuestId {quest.NextQuestId} inconnu`)
		elseif quest.Guide ~= nil and (typeof(quest.Guide) ~= "table" or not QuestGuide.isTarget(quest.Guide.Target)) then
			table.insert(problems, `quête {id} : Guide.Target inconnu ({if typeof(quest.Guide) == "table" then tostring(quest.Guide.Target) else "?"})`)
		elseif quest.Guide ~= nil and quest.Guide.Placement ~= nil and typeof(quest.Guide.Placement) ~= "boolean" then
			table.insert(problems, `quête {id} : Guide.Placement doit être un booléen`)
		elseif (quest.AutoClaim ~= nil and typeof(quest.AutoClaim) ~= "boolean") or (quest.Onboarding ~= nil and typeof(quest.Onboarding) ~= "boolean") then
			table.insert(problems, `quête {id} : AutoClaim et Onboarding doivent être des booléens`)
		elseif quest.Rewards ~= nil then
			if typeof(quest.Rewards) ~= "table" then
				table.insert(problems, `quête {id} : Rewards doit être une liste`)
			else
				for _, reward in quest.Rewards do
					if typeof(reward) ~= "table" or REWARD_CURRENCY[reward.Kind] == nil or not isPositiveInteger(reward.Amount) then
						table.insert(problems, `quête {id} : récompense invalide (Kind Gold / Gems / SummonTicket, Amount entier >= 1)`)
					end
				end
			end
		end
	end
	if typeof(config.FirstQuestId) ~= "string" or config.Quests[config.FirstQuestId] == nil then
		table.insert(problems, `FirstQuestId {config.FirstQuestId} inconnu`)
	elseif #problems == 0 then
		-- La chaîne doit se terminer : sinon la recherche de la quête active ne finirait pas.
		local seen: { [string]: boolean } = {}
		local id: string? = config.FirstQuestId
		while id do
			if seen[id] then
				table.insert(problems, `boucle dans NextQuestId à partir de {id}`)
				break
			end
			seen[id] = true
			id = config.Quests[id].NextQuestId
		end
	end
	return problems
end

-- Objectif « gagner un stage » (StageCompleted, Target 1, Match.Zone / Match.Stage) déjà atteint :
-- le stage est dans FirstClears (gagné avant que la quête soit active). La quête est alors terminée,
-- jamais réclamée ici : le joueur garde son « Récupérer », sans refaire le stage. Ne fait que monter.
local function syncCleared(data: PlayerData, id: string)
	local objective = quests[id].Objective
	local match = objective.Match
	local state = data.Quests[id]
	if objective.Event ~= "StageCompleted" or objective.Target ~= 1 or not match or state.Progress >= 1 then
		return
	end
	local zone, stage = match.Zone, match.Stage
	if typeof(zone) == "number" and typeof(stage) == "number" and data.Progression.FirstClears[`{zone}-{stage}`] == true then
		state.Progress = 1
	end
end

-- Quête active de la chaîne, activée à Progress 0 si elle n'a jamais été commencée (ou terminée tout
-- de suite si son stage est déjà gagné, voir syncCleared).
-- Idempotent : un état déjà sauvegardé n'est jamais réinitialisé.
local function activeQuestId(data: PlayerData): string?
	local id = firstQuestId
	while id do
		local state = data.Quests[id]
		if not state then
			data.Quests[id] = { Progress = 0, Claimed = false }
			syncCleared(data, id)
			return id
		end
		if not state.Claimed then
			syncCleared(data, id)
			return id
		end
		id = quests[id].NextQuestId
	end
	return nil
end

local function matches(objective: Objective, eventName: string, payload: any): boolean
	if objective.Event ~= eventName then
		return false
	end
	local match = objective.Match
	if match then
		if typeof(payload) ~= "table" then
			return false
		end
		for key, expected in match do
			if payload[key] ~= expected then
				return false
			end
		end
	end
	return true
end

-- Copie des récompenses d'une quête (jamais la table de config).
local function rewardsOf(quest: Quest): { Reward }
	local list: { Reward } = {}
	for _, reward in quest.Rewards or {} do
		table.insert(list, { Kind = reward.Kind, Amount = reward.Amount })
	end
	return list
end

-- Quête en cours du joueur (copie, sans référence aux données), ou nil : données pas prêtes,
-- quêtes désactivées ou chaîne entièrement réclamée.
function QuestService:GetActiveQuest(player: Player): ActiveQuest?
	local data = DataService:GetData(player)
	local id = if data then activeQuestId(data) else nil
	if not data or not id then
		return nil
	end
	local quest = quests[id]
	local state = data.Quests[id]
	local completed = state.Progress >= quest.Objective.Target
	return {
		Id = id,
		Title = quest.Title,
		Progress = state.Progress,
		Target = quest.Objective.Target,
		Completed = completed,
		GuideTarget = if quest.Guide and not completed then quest.Guide.Target else nil,
		GuidePlacement = quest.Guide ~= nil and quest.Guide.Placement == true,
		AutoClaim = quest.AutoClaim == true,
		Onboarding = quest.Onboarding == true,
		Rewards = rewardsOf(quest),
	}
end

-- Réclamation, sans yield : marquée réclamée, récompenses ajoutées une seule fois, suivante activée.
-- L'appelant a vérifié que la quête est commencée, terminée et pas encore réclamée.
local function settle(data: PlayerData, questId: string): { Reward }
	local quest = quests[questId]
	data.Quests[questId].Claimed = true
	local granted = rewardsOf(quest)
	for _, reward in granted do
		local currency = REWARD_CURRENCY[reward.Kind]
		data.Currencies[currency] = (data.Currencies[currency] or 0) + reward.Amount
	end
	activeQuestId(data)
	return granted
end

-- Quêtes AutoClaim déjà terminées mais pas réclamées (ex. sauvegarde d'une version sans AutoClaim) :
-- réclamées au chargement, à la suite. Renvoie la dernière réclamée.
local function autoClaimPending(data: PlayerData): Finished?
	local finished: Finished? = nil
	local id = activeQuestId(data)
	while id do
		local quest = quests[id]
		local state = data.Quests[id]
		if not quest.AutoClaim or state.Claimed or state.Progress < quest.Objective.Target then
			break
		end
		finished = { Id = id, Title = quest.Title, Target = quest.Objective.Target, Rewards = settle(data, id) }
		id = activeQuestId(data)
	end
	return finished
end

-- Copie de l'état sauvegardé d'une quête, ou nil si elle n'a jamais été commencée.
function QuestService:GetQuestState(player: Player, questId: string): QuestState?
	local data = DataService:GetData(player)
	local state = if data then data.Quests[questId] else nil
	return if state then { Progress = state.Progress, Claimed = state.Claimed } else nil
end

-- Point d'entrée des événements gameplay (ex. "StageCompleted", { Zone = 1, Stage = 1 } par ZoneService #7).
-- Fait progresser la quête active si l'événement correspond à son objectif, sans dépasser la cible.
-- Renvoie true si une progression a été enregistrée.
function QuestService:HandleGameplayEvent(player: Player, eventName: string, payload: { [string]: any }?): boolean
	local data = DataService:GetData(player)
	local id = if data then activeQuestId(data) else nil
	if not data or not id then
		return false
	end
	local objective = quests[id].Objective
	local state = data.Quests[id]
	if not matches(objective, eventName, payload) or state.Progress >= objective.Target then
		return false
	end
	state.Progress = math.min(state.Progress + 1, objective.Target)
	Log.debug(SCOPE, `{id} : {state.Progress}/{objective.Target} pour {player.Name}`)
	local quest = quests[id]
	if quest.AutoClaim and state.Progress >= objective.Target then
		-- Même section synchrone : terminée, réclamée, suivante activée.
		local granted = settle(data, id)
		local nextId = activeQuestId(data)
		Log.info(SCOPE, `{id} terminée et réclamée automatiquement pour {player.Name}{if nextId then `, quête suivante : {nextId}` else ""}`)
		push(player, { Id = id, Title = quest.Title, Target = objective.Target, Rewards = granted })
		return true
	end
	push(player)
	return true
end

-- Marque une quête terminée comme réclamée, une seule fois, ajoute ses récompenses (QuestConfig.Rewards,
-- définies ici côté serveur, jamais par le client) et active la suivante (NextQuestId), sans yield.
-- Seules la quête ACTIVE et terminée peuvent être réclamées. Renvoie false et la raison en cas de refus.
function QuestService:ClaimQuest(player: Player, questId: string): (boolean, string?, { Reward }?)
	local data = DataService:GetData(player)
	local quest = quests[questId]
	if not data then
		return false, "données non chargées", nil
	end
	if not quest then
		return false, "quête inconnue", nil
	end
	local state = data.Quests[questId]
	if not state then
		return false, "quête non commencée", nil
	end
	if state.Claimed then
		return false, "déjà réclamée", nil
	end
	if activeQuestId(data) ~= questId then
		return false, "quête non active", nil
	end
	if state.Progress < quest.Objective.Target then
		return false, "quête non terminée", nil
	end
	-- Section critique, sans yield : réclamée, puis récompenses ajoutées une seule fois.
	local granted = settle(data, questId)
	local nextId = activeQuestId(data)
	Log.info(SCOPE, `{questId} réclamée par {player.Name}{if nextId then `, quête suivante : {nextId}` else ""}`)
	push(player)
	return true, nil, granted
end

function QuestService:Init()
	local problems = validate(QuestConfig)
	if #problems > 0 then
		for _, problem in problems do
			Log.warn(SCOPE, `QuestConfig invalide : {problem}`)
		end
		Log.warn(SCOPE, "Quêtes désactivées tant que QuestConfig n'est pas corrigée")
		return
	end
	quests = QuestConfig.Quests :: any
	firstQuestId = QuestConfig.FirstQuestId
end

function QuestService:Start()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end
	assert(remotes)
	local event = Instance.new("RemoteEvent")
	event.Name = "QuestChanged"
	event.Parent = remotes
	changedEvent = event
	local get = Instance.new("RemoteFunction")
	get.Name = "GetActiveQuest"
	get.OnServerInvoke = function(player: Player): ActiveQuest?
		return QuestService:GetActiveQuest(player)
	end
	get.Parent = remotes
	-- Le client n'envoie que l'Id de la quête ; état, cible et réclamation sont revérifiés.
	local claim = Instance.new("RemoteFunction")
	claim.Name = "ClaimQuest"
	claim.OnServerInvoke = function(player: Player, questId: any): (boolean, string?, { Reward }?)
		if typeof(questId) ~= "string" then
			return false, "quête inconnue", nil
		end
		return QuestService:ClaimQuest(player, questId)
	end
	claim.Parent = remotes

	DataService:OnPlayerReady(function(player: Player, data: PlayerData)
		activeQuestId(data)
		autoClaimPending(data)
		push(player)
	end)
end

return QuestService
