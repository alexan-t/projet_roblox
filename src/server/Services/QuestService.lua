--!strict
-- Quêtes du joueur (voir docs/QUESTS.md), pilotées par QuestConfig et sauvegardées dans PlayerData.Quests.
-- La quête active se déduit de la chaîne FirstQuestId -> NextQuestId : c'est la première quête
-- de la chaîne qui n'est pas encore réclamée. Aucun champ supplémentaire n'est sauvegardé.
-- Serveur uniquement : les autres services signalent le gameplay avec HandleGameplayEvent.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Utils.Log)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)
local DataService = require(script.Parent.DataService)
local QuestConfig = require(script.Parent.Parent.Config.QuestConfig)

type PlayerData = PlayerDataTypes.PlayerData
type QuestState = PlayerDataTypes.QuestState
type Objective = { Event: string, Match: { [string]: any }?, Target: number }
type Quest = { Title: string, Objective: Objective, NextQuestId: string? }

export type ActiveQuest = {
	Id: string,
	Title: string,
	Progress: number,
	Target: number,
	Completed: boolean,
}

local SCOPE = "QuestService"

local QuestService = {}

local quests: { [string]: Quest } = {}
local firstQuestId: string? = nil

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

-- Quête active de la chaîne, activée à Progress 0 si elle n'a jamais été commencée.
-- Idempotent : un état déjà sauvegardé n'est jamais réinitialisé.
local function activeQuestId(data: PlayerData): string?
	local id = firstQuestId
	while id do
		local state = data.Quests[id]
		if not state then
			data.Quests[id] = { Progress = 0, Claimed = false }
			return id
		end
		if not state.Claimed then
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
	DataService:OnPlayerReady(function(_player: Player, data: PlayerData)
		activeQuestId(data)
	end)
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
	return {
		Id = id,
		Title = quest.Title,
		Progress = state.Progress,
		Target = quest.Objective.Target,
		Completed = state.Progress >= quest.Objective.Target,
	}
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
	return true
end

-- Marque une quête terminée comme réclamée, une seule fois, puis active la suivante (NextQuestId).
-- N'attribue aucune récompense : voir docs/QUESTS.md. Renvoie false et la raison en cas de refus.
function QuestService:ClaimQuest(player: Player, questId: string): (boolean, string?)
	local data = DataService:GetData(player)
	local quest = quests[questId]
	if not data then
		return false, "données non chargées"
	end
	if not quest then
		return false, "quête inconnue"
	end
	local state = data.Quests[questId]
	if not state then
		return false, "quête non commencée"
	end
	if state.Claimed then
		return false, "déjà réclamée"
	end
	if state.Progress < quest.Objective.Target then
		return false, "quête non terminée"
	end
	state.Claimed = true
	local nextId = activeQuestId(data)
	Log.info(SCOPE, `{questId} réclamée par {player.Name}{if nextId then `, quête suivante : {nextId}` else ""}`)
	return true, nil
end

return QuestService
