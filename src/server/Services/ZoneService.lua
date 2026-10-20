--!strict
-- Zones et stages (voir docs/ZONES.md) : autorise le lancement d'un stage depuis le plot du joueur,
-- dans un MODE ("Normal" ou "Elite", #69 : mêmes stages, ennemis plus forts, progression à part),
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
local EliteConfig = require(script.Parent.Parent.Config.EliteConfig)
local Difficulty = require(script.Parent.Parent.Combat.Difficulty)

type PlayerData = PlayerDataTypes.PlayerData
export type Mode = "Normal" | "Elite"
type Session = { id: number, mode: Mode, zone: number, stage: number, plot: Model, config: any, difficulty: any? }

-- Vue en lecture seule d'une session active (table gelée ; Config gelée en profondeur).
export type StageSession = {
	Id: number,
	Mode: Mode,
	Zone: number,
	Stage: number,
	Status: "Running",
	Config: any,
	-- Multiplicateurs des stats ennemies (Difficulty) : ceux de la zone (StageConfig.Zones[zone].Difficulty)
	-- et, en Élite, ceux du stage Élite, multipliés entre eux ; nil sans aucun (Zone 1 en Normal).
	Difficulty: any?,
}

local SCOPE = "ZoneService"
local REMOTES_NAME = "Remotes"
local START_REMOTE_NAME = "RequestStartStage"

local ZoneService = {}

-- stages[zone][stage] = config gelée ; false = stage déclaré mais invalide.
local stages: { [number]: { [number]: any } } = {}
-- Élite : elite[zone] = { unlockAfter = "<zone>-<stage>", stages = { [stage] = multiplicateurs gelés } }.
local elite: { [number]: { unlockAfter: string, stages: { [number]: any } } } = {}
-- Difficulté de zone : zoneDifficulty[zone] = multiplicateurs gelés (StageConfig.Zones[zone].Difficulty), ou absent.
local zoneDifficulty: { [number]: any } = {}
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

-- Mode demandé : nil = "Normal" ; toute autre valeur que "Normal" / "Elite" est refusée (nil).
local function modeOf(mode: any): Mode?
	if mode == nil or mode == "Normal" then
		return "Normal"
	elseif mode == "Elite" then
		return "Elite"
	end
	return nil
end

local function eliteClears(data: PlayerData): { [string]: boolean }
	local clears = (data.Progression :: any).EliteFirstClears
	return if typeof(clears) == "table" then clears else {}
end

-- Élite de la zone débloquée pour ces données ? (First Clear Normal de UnlockAfter)
local function eliteUnlocked(data: PlayerData, zone: number): boolean
	local entry = elite[zone]
	return entry ~= nil and data.Progression.FirstClears[entry.unlockAfter] == true
end

-- Statut d'un stage Élite pour ces données.
local function eliteStatus(data: PlayerData, zone: number, stage: number): "Unlocked" | "Locked" | "Unavailable"
	local config = stages[zone] and stages[zone][stage]
	if config == false then
		return "Unavailable"
	end
	if not eliteUnlocked(data, zone) then
		return "Locked"
	end
	if stage > 1 and eliteClears(data)[stageKey(zone, stage - 1)] ~= true then
		return "Locked"
	end
	return "Unlocked"
end

-- Charge EliteConfig : seuls les stages Élite d'un stage Normal existant et des multiplicateurs valides.
local function loadElite(config: any)
	table.clear(elite)
	if typeof(config) ~= "table" or typeof(config.Zones) ~= "table" then
		return
	end
	for zone, entry in config.Zones do
		local zoneStages = stages[zone]
		if typeof(entry) ~= "table" or typeof(entry.UnlockAfter) ~= "string" or typeof(entry.Stages) ~= "table" or not zoneStages then
			Log.warn(SCOPE, `Élite zone {tostring(zone)} invalide : UnlockAfter et Stages requis, zone connue`)
			continue
		end
		local loaded = { unlockAfter = entry.UnlockAfter, stages = {} }
		for stage, multipliers in entry.Stages do
			local problems = Difficulty.problems(multipliers)
			if zoneStages[stage] == nil then
				table.insert(problems, "stage Normal inconnu")
			end
			if #problems > 0 then
				for _, problem in problems do
					Log.warn(SCOPE, `Élite {stageKey(zone, stage)} invalide : {problem}`)
				end
			else
				loaded.stages[stage] = table.freeze(table.clone(multipliers))
			end
		end
		elite[zone] = loaded
	end
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
			table.clear(zoneDifficulty)
			return false
		end
		stages[zoneId] = {}
		-- Difficulté de zone (facultative) invalide : avertissement, les stages de CETTE zone sont refusés.
		local zoneProblems = if zone.Difficulty ~= nil then Difficulty.problems(zone.Difficulty) else {}
		for _, problem in zoneProblems do
			Log.warn(SCOPE, `Zone {zoneId} : Difficulty invalide : {problem}`)
		end
		if zone.Difficulty ~= nil and #zoneProblems == 0 then
			zoneDifficulty[zoneId] = table.freeze(table.clone(zone.Difficulty))
		end
		for stageId, stage in zone.Stages do
			local problems = stageProblems(stage)
			if #zoneProblems > 0 then
				table.insert(problems, "difficulté de zone invalide")
			end
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

-- Multiplicateurs d'une session : zone × stage Élite (stat par stat), nil s'il n'y en a aucun.
local function sessionDifficulty(zone: number, eliteMultipliers: any?): any?
	local base = zoneDifficulty[zone]
	if not base or not eliteMultipliers then
		return base or eliteMultipliers
	end
	local combined = table.clone(base)
	for key, factor in eliteMultipliers do
		combined[key] = (combined[key] or 1) * factor
	end
	return table.freeze(combined)
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
		Mode = session.mode,
		Zone = session.zone,
		Stage = session.stage,
		Status = "Running" :: "Running",
		Config = session.config,
		Difficulty = session.difficulty,
	})
end

-- Le joueur peut-il lancer ce stage, dans ce mode (nil = Normal), maintenant ? Renvoie false et la raison sinon.
-- Élite : la zone doit avoir son Élite débloquée (First Clear Normal de UnlockAfter) et le stage Élite
-- précédent doit être terminé en Élite. Le client ne fournit que des entiers et un nom de mode.
function ZoneService:CanStartStage(player: Player, zone: number, stage: number, mode: any?): (boolean, string?)
	local data: PlayerData? = if player:GetAttribute("DataLoaded") == true then DataService:GetData(player) else nil
	if player.Parent ~= Players or not data then
		return false, "données non chargées"
	end
	if not PlotService:GetPlot(player) then
		return false, "aucun plot"
	end
	local kind = modeOf(mode)
	if not kind then
		return false, "mode inconnu"
	end
	local zoneStages = if isPositiveInteger(zone) then stages[zone] else nil
	local config = if zoneStages and isPositiveInteger(stage) then zoneStages[stage] else nil
	if config == nil then
		return false, "stage inconnu"
	end
	if config == false then
		return false, "stage indisponible"
	end
	if kind == "Elite" then
		if not (elite[zone] and elite[zone].stages[stage]) then
			return false, "stage inconnu"
		end
		if not eliteUnlocked(data, zone) then
			return false, "Élite verrouillé"
		end
		if eliteStatus(data, zone, stage) ~= "Unlocked" then
			return false, "stage verrouillé"
		end
	else
		local previousZone, previous = previousStage(zone, stage)
		if previousZone and previous and data.Progression.FirstClears[stageKey(previousZone, previous)] ~= true then
			return false, "stage verrouillé"
		end
	end
	if currentSession(player) then
		return false, "session déjà en cours"
	end
	return true, nil
end

export type StageEntry = {
	Mode: Mode,
	Zone: number,
	Stage: number,
	Status: "Unlocked" | "Locked" | "Unavailable",
	Cleared: boolean,
	Config: any?, -- config gelée (nil si le stage est invalide)
}

-- Tous les stages de StageConfig pour ce joueur, dans l'ordre (zone, puis stage), avec leur état :
-- "Locked" tant que le stage précédent n'est pas dans FirstClears, "Unavailable" si sa config est
-- invalide. Cleared = First Clear déjà obtenu. Liste vide si les données ne sont pas chargées.
-- mode "Elite" : les stages Élite configurés, avec leur statut et leur First Clear ÉLITE.
function ZoneService:ListStages(player: Player, mode: any?): { StageEntry }
	local data: PlayerData? = if player:GetAttribute("DataLoaded") == true then DataService:GetData(player) else nil
	local list: { StageEntry } = {}
	if player.Parent ~= Players or not data then
		return list
	end
	if modeOf(mode) == "Elite" then
		local cleared = eliteClears(data)
		for zone = 1, #stages do
			local entry = elite[zone]
			for stage = 1, if entry then #stages[zone] else 0 do
				if entry.stages[stage] then
					local config = stages[zone][stage]
					table.insert(list, {
						Mode = "Elite" :: Mode,
						Zone = zone,
						Stage = stage,
						Status = eliteStatus(data, zone, stage) :: any,
						Cleared = cleared[stageKey(zone, stage)] == true,
						Config = if config == false then nil else config,
					})
				end
			end
		end
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
				Mode = "Normal" :: Mode,
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

-- Élite de la zone débloquée pour ce joueur ?
function ZoneService:IsEliteUnlocked(player: Player, zone: number): boolean
	local data = DataService:GetData(player)
	return data ~= nil and eliteUnlocked(data, zone)
end

-- Crée la session serveur du stage, dans ce mode (nil = Normal). Ne modifie aucune donnée sauvegardée.
function ZoneService:StartStage(player: Player, zone: number, stage: number, mode: any?): (StageSession?, string?)
	local ok, reason = ZoneService:CanStartStage(player, zone, stage, mode)
	if not ok then
		return nil, reason
	end
	local plot = PlotService:GetPlot(player)
	assert(plot, "plot vérifié par CanStartStage")
	local kind = modeOf(mode) :: Mode
	nextSessionId += 1
	local session: Session = { id = nextSessionId, mode = kind, zone = zone, stage = stage, plot = plot, config = stages[zone][stage],
		difficulty = sessionDifficulty(zone, if kind == "Elite" then elite[zone].stages[stage] else nil) }
	sessions[player] = session
	Log.info(SCOPE, `Stage {stageKey(zone, stage)}{if kind == "Elite" then " Élite" else ""} lancé par {player.Name} (session {session.id})`)
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
		Log.info(SCOPE, `Stage {stageKey(session.zone, session.stage)} ({session.mode}) échoué par {player.Name}`)
		return true, nil
	end
	Log.info(SCOPE, `Stage {stageKey(session.zone, session.stage)} ({session.mode}) réussi par {player.Name}`)
	-- Élite : événement distinct, jamais confondu avec une quête « gagner le stage » du Normal.
	QuestService:HandleGameplayEvent(player, if session.mode == "Elite" then "EliteStageCompleted" else "StageCompleted",
		{ Zone = session.zone, Stage = session.stage })
	local rewards, reason = RewardService:HandleStageCompleted(player, session.zone, session.stage, session.id, session.mode)
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
	loadElite(EliteConfig)
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
	request.OnServerInvoke = function(player: Player, zone: any, stage: any, mode: any): (boolean, string?)
		if not isPositiveInteger(zone) or not isPositiveInteger(stage) or modeOf(mode) == nil then
			return false, "requête invalide"
		end
		local session, reason = ZoneService:StartStage(player, zone, stage, mode)
		return session ~= nil, reason
	end
	request.Parent = remotes
end

return ZoneService
