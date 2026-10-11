--!strict
-- Zones et stages (voir docs/ZONES.md) : autorise le lancement d'un stage depuis le plot du joueur,
-- tient la session serveur (au plus une par joueur) et reçoit sa fin. Aucun combat ici (#8),
-- aucune récompense ici (RewardService, #9).
-- Une session n'existe qu'en mémoire. Elle est revérifiée à chaque accès (joueur présent,
-- données chargées, même plot) : un départ ou une perte de profil la rend inutilisable
-- sans attendre la livraison d'un signal.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Utils.Log)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local QuestService = require(script.Parent.QuestService)
local RewardService = require(script.Parent.RewardService)
local StageConfig = require(script.Parent.Parent.Config.StageConfig)

type PlayerData = PlayerDataTypes.PlayerData
type Session = { id: number, zone: number, stage: number, plot: Model, config: any }

-- Vue en lecture seule d'une session active (table gelée ; Config gelée en profondeur).
export type StageSession = {
	Id: number,
	Zone: number,
	Stage: number,
	Status: "Running",
	Config: any,
}

local SCOPE = "ZoneService"
local REMOTES_NAME = "Remotes"
local START_REMOTE_NAME = "RequestStartStage"

local ZoneService = {}

-- stages[zone][stage] = config gelée ; false = stage déclaré mais invalide.
local stages: { [number]: { [number]: any } } = {}
local sessions: { [Player]: Session } = {}
local nextSessionId = 0

local function isPositiveInteger(value: any): boolean
	return typeof(value) == "number" and value >= 1 and value % 1 == 0 and value < math.huge
end

-- Vrai si t est une liste 1..n non vide, sans autre clé.
local function isList(t: any): boolean
	if typeof(t) ~= "table" or #t == 0 then
		return false
	end
	local count = 0
	for _ in t do
		count += 1
	end
	return count == #t
end

local function deepFreeze(value: any): any
	if typeof(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, item in value do
		copy[key] = deepFreeze(item)
	end
	return table.freeze(copy)
end

local function stageKey(zone: number, stage: number): string
	return `{zone}-{stage}`
end

-- Problèmes de contenu d'un stage ; vide s'il est jouable.
local function stageProblems(config: any): { string }
	local problems: { string } = {}
	local function checkEnemy(enemy: any, where: string, needsCount: boolean)
		if typeof(enemy) ~= "table" or typeof(enemy.EnemyId) ~= "string" or enemy.EnemyId == "" then
			table.insert(problems, `{where} : EnemyId manquant`)
		elseif needsCount and not isPositiveInteger(enemy.Count) then
			table.insert(problems, `{where} : Count doit être un entier >= 1`)
		end
	end
	if typeof(config) ~= "table" or not isList(config.Waves) then
		table.insert(problems, "Waves doit être une liste non vide")
		return problems
	end
	for waveIndex, wave in config.Waves do
		if typeof(wave) ~= "table" or not isList(wave.Enemies) then
			table.insert(problems, `vague {waveIndex} : Enemies doit être une liste non vide`)
		else
			for enemyIndex, enemy in wave.Enemies do
				checkEnemy(enemy, `vague {waveIndex}, ennemi {enemyIndex}`, true)
			end
		end
	end
	if config.MiniBoss ~= nil then
		checkEnemy(config.MiniBoss, "MiniBoss", false)
	end
	return problems
end

local function loadConfig(config: any): boolean
	if typeof(config) ~= "table" or not isList(config.Zones) then
		Log.warn(SCOPE, "StageConfig.Zones doit être une liste de zones 1..n ; aucun stage lançable")
		return false
	end
	for zoneId, zone in config.Zones do
		if typeof(zone) ~= "table" or not isList(zone.Stages) then
			Log.warn(SCOPE, `Zone {zoneId} : Stages doit être une liste 1..n ; aucun stage lançable`)
			table.clear(stages)
			return false
		end
		stages[zoneId] = {}
		for stageId, stage in zone.Stages do
			local problems = stageProblems(stage)
			if #problems > 0 then
				for _, problem in problems do
					Log.warn(SCOPE, `Stage {stageKey(zoneId, stageId)} invalide : {problem}`)
				end
				stages[zoneId][stageId] = false
			else
				stages[zoneId][stageId] = deepFreeze(stage)
			end
		end
	end
	return true
end

-- Stage qui précède (même zone, sinon dernier stage de la zone précédente), ou nil pour le tout premier.
local function previousStage(zone: number, stage: number): (number?, number?)
	if stage > 1 then
		return zone, stage - 1
	end
	local previousZone = stages[zone - 1]
	if previousZone then
		return zone - 1, #previousZone
	end
	return nil, nil
end

-- Revérifie qu'une session est toujours utilisable ; la supprime sinon.
local function currentSession(player: Player): Session?
	local session = sessions[player]
	if not session then
		return nil
	end
	if player.Parent ~= Players or player:GetAttribute("DataLoaded") ~= true
		or DataService:GetData(player) == nil or PlotService:GetPlot(player) ~= session.plot
	then
		sessions[player] = nil
		Log.debug(SCOPE, `Session {session.id} de {player.Name} invalidée (départ, profil ou plot perdu)`)
		return nil
	end
	return session
end

local function view(session: Session): StageSession
	return table.freeze({
		Id = session.id,
		Zone = session.zone,
		Stage = session.stage,
		Status = "Running" :: "Running",
		Config = session.config,
	})
end

-- Le joueur peut-il lancer ce stage maintenant ? Renvoie false et la raison sinon.
function ZoneService:CanStartStage(player: Player, zone: number, stage: number): (boolean, string?)
	local data: PlayerData? = if player:GetAttribute("DataLoaded") == true then DataService:GetData(player) else nil
	if player.Parent ~= Players or not data then
		return false, "données non chargées"
	end
	if not PlotService:GetPlot(player) then
		return false, "aucun plot"
	end
	local zoneStages = if isPositiveInteger(zone) then stages[zone] else nil
	local config = if zoneStages and isPositiveInteger(stage) then zoneStages[stage] else nil
	if config == nil then
		return false, "stage inconnu"
	end
	if config == false then
		return false, "stage indisponible"
	end
	local previousZone, previous = previousStage(zone, stage)
	if previousZone and previous and data.Progression.FirstClears[stageKey(previousZone, previous)] ~= true then
		return false, "stage verrouillé"
	end
	if currentSession(player) then
		return false, "session déjà en cours"
	end
	return true, nil
end

export type StageEntry = {
	Zone: number,
	Stage: number,
	Status: "Unlocked" | "Locked" | "Unavailable",
	Cleared: boolean,
	Config: any?, -- config gelée (nil si le stage est invalide)
}

-- Tous les stages de StageConfig pour ce joueur, dans l'ordre (zone, puis stage), avec leur état :
-- "Locked" tant que le stage précédent n'est pas dans FirstClears, "Unavailable" si sa config est
-- invalide. Cleared = First Clear déjà obtenu. Liste vide si les données ne sont pas chargées.
function ZoneService:ListStages(player: Player): { StageEntry }
	local data: PlayerData? = if player:GetAttribute("DataLoaded") == true then DataService:GetData(player) else nil
	local list: { StageEntry } = {}
	if player.Parent ~= Players or not data then
		return list
	end
	for zone = 1, #stages do
		local zoneStages = stages[zone]
		for stage = 1, #zoneStages do
			local config = zoneStages[stage]
			local previousZone, previous = previousStage(zone, stage)
			local locked = previousZone ~= nil and previous ~= nil
				and data.Progression.FirstClears[stageKey(previousZone, previous)] ~= true
			table.insert(list, {
				Zone = zone,
				Stage = stage,
				Status = (if config == false then "Unavailable" elseif locked then "Locked" else "Unlocked") :: any,
				Cleared = data.Progression.FirstClears[stageKey(zone, stage)] == true,
				Config = if config == false then nil else config,
			})
		end
	end
	return list
end

-- Crée la session serveur du stage. Ne modifie aucune donnée sauvegardée.
function ZoneService:StartStage(player: Player, zone: number, stage: number): (StageSession?, string?)
	local ok, reason = ZoneService:CanStartStage(player, zone, stage)
	if not ok then
		return nil, reason
	end
	local plot = PlotService:GetPlot(player)
	assert(plot, "plot vérifié par CanStartStage")
	nextSessionId += 1
	local session: Session = { id = nextSessionId, zone = zone, stage = stage, plot = plot, config = stages[zone][stage] }
	sessions[player] = session
	Log.info(SCOPE, `Stage {stageKey(zone, stage)} lancé par {player.Name} (session {session.id})`)
	return view(session), nil
end

-- Session active du joueur (vue en lecture seule), ou nil.
function ZoneService:GetSession(player: Player): StageSession?
	local session = currentSession(player)
	return if session then view(session) else nil
end

-- Fin de session annoncée par le combat (#8). sessionId protège contre la fin tardive d'une
-- ancienne session : une session ne se termine qu'une fois. Une victoire émet "StageCompleted"
-- vers QuestService (progression) puis RewardService (récompenses + First Clear), avec
-- l'identifiant de la session comme identité de completion. ZoneService n'attribue rien lui-même.
-- Renvoie true si la session est terminée, et le résultat des récompenses (victoire seulement).
function ZoneService:CompleteStage(player: Player, sessionId: number, victory: boolean): (boolean, RewardService.Result?)
	local session = currentSession(player)
	if not session or session.id ~= sessionId then
		return false, nil
	end
	sessions[player] = nil
	if victory ~= true then
		Log.info(SCOPE, `Stage {stageKey(session.zone, session.stage)} échoué par {player.Name}`)
		return true, nil
	end
	Log.info(SCOPE, `Stage {stageKey(session.zone, session.stage)} réussi par {player.Name}`)
	QuestService:HandleGameplayEvent(player, "StageCompleted", { Zone = session.zone, Stage = session.stage })
	local rewards, reason = RewardService:HandleStageCompleted(player, session.zone, session.stage, session.id)
	if not rewards then
		Log.warn(SCOPE, `Aucune récompense pour {stageKey(session.zone, session.stage)} ({player.Name}) : {reason}`)
	end
	return true, rewards
end

-- Abandon de la session active, sans aucun effet de progression.
function ZoneService:CancelStage(player: Player): boolean
	local session = currentSession(player)
	if not session then
		return false
	end
	sessions[player] = nil
	Log.info(SCOPE, `Stage {stageKey(session.zone, session.stage)} annulé par {player.Name}`)
	return true
end

function ZoneService:Init()
	loadConfig(StageConfig)
end

function ZoneService:Start()
	Players.PlayerRemoving:Connect(function(player: Player)
		sessions[player] = nil
	end)

	-- Seule action client : demander un stage. Le client ne fournit que deux entiers ;
	-- tout le reste (droits, config, ennemis, résultat) est décidé par le serveur.
	local remotes = ReplicatedStorage:FindFirstChild(REMOTES_NAME)
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = REMOTES_NAME
		remotes.Parent = ReplicatedStorage
	end
	assert(remotes)
	local request = Instance.new("RemoteFunction")
	request.Name = START_REMOTE_NAME
	request.OnServerInvoke = function(player: Player, zone: any, stage: any): (boolean, string?)
		if not isPositiveInteger(zone) or not isPositiveInteger(stage) then
			return false, "requête invalide"
		end
		local session, reason = ZoneService:StartStage(player, zone, stage)
		return session ~= nil, reason
	end
	request.Parent = remotes
end

return ZoneService
