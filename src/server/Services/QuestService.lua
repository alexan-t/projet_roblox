--!strict
-- Quêtes du joueur (voir docs/QUESTS.md), pilotées par QuestConfig et sauvegardées dans PlayerData.Quests.
-- Lignes de quêtes (QuestConfig.Lines) : chaque ligne est une chaîne FirstQuestId -> NextQuestId, avec ses
-- paliers (ex. Défense : 1-1, 1-2… ; Héros : premier héros, 2, 5, 10…). Sa quête active est la première de
-- sa chaîne pas encore réclamée ; une ligne avec After ne commence qu'une fois cette quête réclamée. Les
-- lignes avancent en parallèle ; la quête PRINCIPALE (suivi du HUD, guidage) est la quête active de la
-- première ligne ouverte, dans l'ordre de QuestConfig.Lines. Sans Lines : une seule ligne (FirstQuestId).
-- Aucun champ supplémentaire n'est sauvegardé.
-- Les autres services signalent le gameplay avec HandleGameplayEvent ; les objectifs d'état (HeroesOwned :
-- nombre de héros DIFFÉRENTS possédés) se relisent dans PlayerData (SyncState, appelé par HeroService).
-- Remotes (lecture seule pour le client, le serveur décide tout) :
--   GetActiveQuest (RemoteFunction) -> vue de la quête active ({ Id, Title, Description?, Progress, Target,
--                                      Completed, GuideTarget?, GuidePlacement, AutoClaim, Onboarding }) ou nil ;
--   GetQuestLog (RemoteFunction)    -> journal pour le panneau Quêtes : { Quests = { entrée } }, UNE entrée par
--                                      ligne ouverte : sa quête active, ou la dernière si la ligne est finie
--                                      (jamais les suivantes) ; entrée = { Id, Title, Description?, Progress,
--                                      Target, Completed, Claimed, AutoClaim, Rewards, Line, LineTitle, Tier,
--                                      Tiers }. Copies en lecture seule, jamais PlayerData ;
--   ClaimQuest (RemoteFunction)     -> (ok, raison?, récompenses?) : le client n'envoie que l'Id de quête,
--                                      revérifié ici ; les récompenses de la quête (QuestConfig.Rewards)
--                                      sont ajoutées UNE fois, sans yield, et renvoyées pour l'affichage ;
--   QuestChanged (RemoteEvent)      -> (vue principale ou nil, terminée?) à l'activation, à chaque progression
--                                      et à la réclamation, quelle que soit la ligne (la vue porte ClaimableCount :
--                                      quêtes à récupérer, toutes lignes). Jamais PlayerData. terminée = { Id, Title, Target, Rewards }
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
	Description: string?,
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
	-- Présentation seulement : ce qu'il faut faire, en une phrase (panneau Quêtes).
	Description: string?,
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
	-- Quêtes terminées en attente de « Récupérer », toutes lignes confondues (notification du bouton Quêtes).
	ClaimableCount: number,
}

type Line = { Id: string, Title: string, FirstQuestId: string, After: string? }

-- Récompenses de quête : type -> monnaie de PlayerData.Currencies.
local REWARD_CURRENCY: { [string]: string } = {
	Gold = "Gold",
	Gems = "Gems",
	SummonTicket = "SummonTickets",
}

local SCOPE = "QuestService"

local QuestService = {}

local quests: { [string]: Quest } = {}
local lines: { Line } = {}
local changedEvent: RemoteEvent? = nil

-- Objectifs d'état : la progression se relit dans PlayerData (jamais d'événement compté).
local STATE_OBJECTIVES = { HeroesOwned = true }

-- Lignes de la config : QuestConfig.Lines, ou une seule ligne depuis FirstQuestId.
local function linesOf(config: any): { Line }
	if typeof(config.Lines) == "table" then
		return config.Lines
	end
	return { { Id = "Main", Title = "Quêtes", FirstQuestId = config.FirstQuestId } }
end

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
		elseif quest.Description ~= nil and typeof(quest.Description) ~= "string" then
			table.insert(problems, `quête {id} : Description doit être un texte`)
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
	end
	if config.Lines ~= nil and (typeof(config.Lines) ~= "table" or #config.Lines == 0) then
		table.insert(problems, "Lines doit être une liste non vide")
		return problems
	end
	if #problems > 0 then
		return problems
	end
	-- Chaque ligne : chaîne finie (sinon la recherche de la quête active ne finirait pas), quêtes à une
	-- seule ligne, After connu.
	local owner: { [string]: string } = {}
	local lineIds: { [string]: boolean } = {}
	for index, line in linesOf(config) do
		local name = if typeof(line) == "table" and typeof(line.Id) == "string" then line.Id else `#{index}`
		if typeof(line) ~= "table" or typeof(line.Id) ~= "string" or lineIds[line.Id] then
			table.insert(problems, `ligne {name} : Id manquant ou en double`)
			continue
		end
		lineIds[line.Id] = true
		if typeof(line.Title) ~= "string" then
			table.insert(problems, `ligne {name} : Title manquant`)
		end
		if typeof(line.FirstQuestId) ~= "string" or config.Quests[line.FirstQuestId] == nil then
			table.insert(problems, `ligne {name} : FirstQuestId {tostring(line.FirstQuestId)} inconnu`)
			continue
		end
		if line.After ~= nil and (typeof(line.After) ~= "string" or config.Quests[line.After] == nil) then
			table.insert(problems, `ligne {name} : After {tostring(line.After)} inconnu`)
		end
		local id: string? = line.FirstQuestId
		while id do
			if owner[id] then
				table.insert(problems, if owner[id] == line.Id then `boucle dans NextQuestId à partir de {id}` else `quête {id} dans deux lignes ({owner[id]}, {line.Id})`)
				break
			end
			owner[id] = line.Id
			id = config.Quests[id].NextQuestId
		end
	end
	for id, quest in config.Quests do
		local objective = quest.Objective
		if STATE_OBJECTIVES[objective.Event] and (objective.Match ~= nil or quest.AutoClaim) then
			table.insert(problems, `quête {id} : objectif d'état {objective.Event} sans Match ni AutoClaim`)
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

-- Nombre de héros DIFFÉRENTS possédés (HeroId), comme l'Index.
local function uniqueHeroes(data: PlayerData): number
	local seen: { [string]: boolean } = {}
	local count = 0
	for _, hero in data.Heroes do
		if typeof(hero) == "table" and typeof(hero.HeroId) == "string" and not seen[hero.HeroId] then
			seen[hero.HeroId] = true
			count += 1
		end
	end
	return count
end

-- Progression relue dans les données (stage déjà gagné, héros possédés). Ne fait que monter, bornée à la
-- cible. Renvoie true si elle a changé.
local function syncState(data: PlayerData, id: string): boolean
	local objective = quests[id].Objective
	local state = data.Quests[id]
	local before = state.Progress
	syncCleared(data, id)
	if objective.Event == "HeroesOwned" then
		state.Progress = math.max(state.Progress, math.min(uniqueHeroes(data), objective.Target))
	end
	return state.Progress ~= before
end

-- Quête active d'une ligne, activée à Progress 0 si elle n'a jamais été commencée (puis synchronisée :
-- stage déjà gagné, héros déjà possédés). nil : ligne pas encore ouverte (After non réclamée) ou finie.
-- Idempotent : un état déjà sauvegardé n'est jamais réinitialisé.
local function lineActive(data: PlayerData, line: Line): string?
	if line.After then
		local gate = data.Quests[line.After]
		if not gate or not gate.Claimed then
			return nil
		end
	end
	local id: string? = line.FirstQuestId
	while id do
		local state = data.Quests[id]
		if not state then
			data.Quests[id] = { Progress = 0, Claimed = false }
			syncState(data, id)
			return id
		end
		if not state.Claimed then
			syncState(data, id)
			return id
		end
		id = quests[id].NextQuestId
	end
	return nil
end

-- Quêtes actives de toutes les lignes ouvertes, dans l'ordre des lignes (les active si besoin).
local function activeIds(data: PlayerData): { string }
	local list: { string } = {}
	for _, line in lines do
		local id = lineActive(data, line)
		if id then
			table.insert(list, id)
		end
	end
	return list
end

-- Quête principale : la quête active de la première ligne ouverte (suivi du HUD, guidage).
local function activeQuestId(data: PlayerData): string?
	return activeIds(data)[1]
end

local function isClaimable(data: PlayerData, id: string): boolean
	local quest = quests[id]
	local state = data.Quests[id]
	return state ~= nil and not state.Claimed and not quest.AutoClaim and state.Progress >= quest.Objective.Target
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
	local ids = if data then activeIds(data) else {}
	local id = ids[1]
	if not data or not id then
		return nil
	end
	local claimable = 0
	for _, active in ids do
		if isClaimable(data, active) then
			claimable += 1
		end
	end
	local quest = quests[id]
	local state = data.Quests[id]
	local completed = state.Progress >= quest.Objective.Target
	return {
		Id = id,
		Title = quest.Title,
		Description = quest.Description,
		Progress = state.Progress,
		Target = quest.Objective.Target,
		Completed = completed,
		GuideTarget = if quest.Guide and not completed then quest.Guide.Target else nil,
		GuidePlacement = quest.Guide ~= nil and quest.Guide.Placement == true,
		AutoClaim = quest.AutoClaim == true,
		Onboarding = quest.Onboarding == true,
		Rewards = rewardsOf(quest),
		ClaimableCount = claimable,
	}
end

export type LogEntry = {
	Id: string,
	Title: string,
	Description: string?,
	Progress: number,
	Target: number,
	Completed: boolean,
	Claimed: boolean,
	AutoClaim: boolean,
	Rewards: { Reward },
	-- Ligne de la quête (regroupement du panneau) : Id, titre, palier courant (1..Tiers) et nombre de paliers.
	Line: string,
	LineTitle: string,
	Tier: number,
	Tiers: number,
}

-- Journal du panneau Quêtes : UNE entrée par ligne ouverte (ordre de QuestConfig.Lines) : sa quête
-- active, ou la dernière de la chaîne si la ligne est finie. Les quêtes suivantes ne sont jamais envoyées
-- (pas de spoil), seulement le nombre de paliers. Copies uniquement ; nil sans données.
function QuestService:GetQuestLog(player: Player): { Quests: { LogEntry } }?
	local data = DataService:GetData(player)
	if not data then
		return nil
	end
	local list: { LogEntry } = {}
	for _, line in lines do
		local activeId = lineActive(data, line)
		local shown: string? = nil
		local tier, tiers = 0, 0
		local id: string? = line.FirstQuestId
		while id do
			tiers += 1
			local state = data.Quests[id]
			if state and (id == activeId or (activeId == nil and state.Claimed)) then
				shown, tier = id, tiers
			end
			id = quests[id].NextQuestId
		end
		local state = if shown then data.Quests[shown] else nil
		if shown and state then
			local quest = quests[shown]
			local target = quest.Objective.Target
			table.insert(list, {
				Id = shown,
				Title = quest.Title,
				Description = quest.Description,
				Progress = math.min(state.Progress, target),
				Target = target,
				Completed = state.Progress >= target,
				Claimed = state.Claimed,
				AutoClaim = quest.AutoClaim == true,
				Rewards = rewardsOf(quest),
				Line = line.Id,
				LineTitle = line.Title,
				Tier = tier,
				Tiers = tiers,
			})
		end
	end
	return { Quests = list }
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
	local settled = true
	while settled do
		settled = false
		for _, id in activeIds(data) do
			local quest = quests[id]
			local state = data.Quests[id]
			if quest.AutoClaim and not state.Claimed and state.Progress >= quest.Objective.Target then
				finished = { Id = id, Title = quest.Title, Target = quest.Objective.Target, Rewards = settle(data, id) }
				settled = true -- la ligne avance : on relit les quêtes actives
				break
			end
		end
	end
	return finished
end

-- Renvoie au client la vue de la quête active (après une modification de test, DebugService).
function QuestService:Notify(player: Player)
	push(player)
end

-- Copie de l'état sauvegardé d'une quête, ou nil si elle n'a jamais été commencée.
function QuestService:GetQuestState(player: Player, questId: string): QuestState?
	local data = DataService:GetData(player)
	local state = if data then data.Quests[questId] else nil
	return if state then { Progress = state.Progress, Claimed = state.Claimed } else nil
end

-- Point d'entrée des événements gameplay (ex. "StageCompleted", { Zone = 1, Stage = 1 } par ZoneService #7).
-- Fait progresser les quêtes actives (toutes lignes) dont l'objectif correspond, sans dépasser la cible.
-- Les objectifs d'état (HeroesOwned) ne se comptent jamais par événement : voir SyncState.
-- Renvoie true si une progression a été enregistrée.
function QuestService:HandleGameplayEvent(player: Player, eventName: string, payload: { [string]: any }?): boolean
	local data = DataService:GetData(player)
	if not data or STATE_OBJECTIVES[eventName] then
		return false
	end
	local progressed = false
	local finished: { Finished } = {}
	for _, id in activeIds(data) do
		local quest = quests[id]
		local objective = quest.Objective
		local state = data.Quests[id]
		if matches(objective, eventName, payload) and state.Progress < objective.Target then
			progressed = true
			state.Progress = math.min(state.Progress + 1, objective.Target)
			Log.debug(SCOPE, `{id} : {state.Progress}/{objective.Target} pour {player.Name}`)
			if quest.AutoClaim and state.Progress >= objective.Target then
				-- Même section synchrone : terminée, réclamée, suivante activée.
				local granted = settle(data, id)
				Log.info(SCOPE, `{id} terminée et réclamée automatiquement pour {player.Name}`)
				table.insert(finished, { Id = id, Title = quest.Title, Target = objective.Target, Rewards = granted })
			end
		end
	end
	if not progressed then
		return false
	end
	if #finished == 0 then
		push(player)
	end
	for _, done in finished do
		push(player, done)
	end
	return true
end

-- Objectifs d'état (HeroesOwned) : relus dans PlayerData après un changement (HeroService : héros
-- ajouté, retiré). Pousse la vue si une progression a changé. Renvoie true dans ce cas.
function QuestService:SyncState(player: Player): boolean
	local data = DataService:GetData(player)
	if not data then
		return false
	end
	-- activeIds resynchronise déjà les quêtes actives : on compare avant / après
	local before: { [string]: number } = {}
	for id, state in data.Quests do
		before[id] = state.Progress
	end
	local changed = false
	for _, id in activeIds(data) do
		if STATE_OBJECTIVES[quests[id].Objective.Event] then
			syncState(data, id)
			if data.Quests[id].Progress ~= before[id] then
				changed = true
			end
		end
	end
	if changed then
		push(player)
	end
	return changed
end

-- Marque une quête terminée comme réclamée, une seule fois, ajoute ses récompenses (QuestConfig.Rewards,
-- définies ici côté serveur, jamais par le client) et active la suivante (NextQuestId), sans yield.
-- Seule la quête ACTIVE de sa ligne, terminée, peut être réclamée. Renvoie false et la raison en cas de refus.
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
	if not table.find(activeIds(data), questId) then
		return false, "quête non active", nil
	end
	if state.Progress < quest.Objective.Target then
		return false, "quête non terminée", nil
	end
	-- Section critique, sans yield : réclamée, puis récompenses ajoutées une seule fois.
	local granted = settle(data, questId)
	Log.info(SCOPE, `{questId} réclamée par {player.Name}`)
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
	lines = linesOf(QuestConfig)
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
	local log = Instance.new("RemoteFunction")
	log.Name = "GetQuestLog"
	log.OnServerInvoke = function(player: Player): { Quests: { LogEntry } }?
		return QuestService:GetQuestLog(player)
	end
	log.Parent = remotes
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
		activeIds(data)
		autoClaimPending(data)
		push(player)
	end)
end

return QuestService
