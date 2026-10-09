--!strict
-- Combat serveur (voir docs/COMBAT.md) : une CombatSession par joueur, simulée par CombatEngine
-- à pas fixe sur Heartbeat. CombatService possède les unités et le résultat ; il annonce la fin
-- à ZoneService, une seule fois. Il ne connaît aucun asset : l'appelant (ArenaService) fournit
-- les positions et une fonction qui crée le modèle d'une unité.
-- Le combat est entièrement automatique (ultimes compris). Le client ne peut que choisir la
-- vitesse x1/x2 (Remotes.SetCombatSpeed) ; il reçoit les événements de son combat (Remotes.CombatEvent).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Log = require(ReplicatedStorage.Shared.Utils.Log)
local CombatConfig = require(script.Parent.Parent.Config.CombatConfig)
local CombatEngine = require(script.Parent.Parent.Combat.CombatEngine)
local DataService = require(script.Parent.DataService)
local ZoneService = require(script.Parent.ZoneService)

-- Fourni par l'appelant : positions au sol (Vector3) et création des modèles de représentation.
export type ArenaContext = {
	HeroPositions: { [number]: Vector3 }, -- slot 1..9 -> pieds
	EnemyPositions: { [number]: Vector3 }, -- case 1..9 -> pieds
	SpawnUnit: (unit: { UnitId: number, Team: string, TypeId: string, Slot: number? }, feet: Vector3, lookAt: Vector3) -> Model?,
}
export type CombatView = {
	Id: number,
	ZoneSessionId: number,
	Zone: number,
	Stage: number,
	Wave: number,
	WaveCount: number,
	Speed: number,
	Units: { { [string]: any } },
}
type Session = {
	id: number,
	player: Player,
	zoneSessionId: number,
	zone: number,
	stage: number,
	speed: number,
	state: CombatEngine.State,
	context: ArenaContext,
	models: { [number]: Model },
	enemyFacing: Vector3,
	allyFacing: Vector3,
}
type EndedCallback = (player: Player, combatId: number, result: string) -> ()

local SCOPE = "CombatService"
-- Délai avant de retirer le modèle d'une unité morte : laisse jouer sa disparition côté client
-- (DefeatEffectController, 0,85 s), y compris retardée jusqu'au coup visible (ultime 0,45 s,
-- attaque du Roi Orc 0,7 s).
local CORPSE_DELAY = 1.7

local CombatService = {}

local sessions: { [Player]: Session } = {}
local nextCombatId = 0
local eventRemote: RemoteEvent? = nil
local endedCallbacks: { EndedCallback } = {}

local function flat(v: Vector3): CombatEngine.Vec
	return { x = v.X, z = v.Z }
end

local function average(points: { [number]: Vector3 }): Vector3
	local sum, n = Vector3.zero, 0
	for _, p in points do
		sum += p
		n += 1
	end
	return if n > 0 then sum / n else Vector3.zero
end

local function isSpeed(value: any): boolean
	return value == 1 or value == 2
end

local function stop(session: Session)
	if sessions[session.player] == session then
		sessions[session.player] = nil
	end
	for _, model in session.models do
		model:Destroy()
	end
	table.clear(session.models)
end

-- Contexte encore valide : joueur présent, profil chargé, même session de stage.
local function contextAlive(session: Session): boolean
	local player = session.player
	if player.Parent ~= Players or player:GetAttribute("DataLoaded") ~= true or not DataService:GetData(player) then
		return false
	end
	local stage = ZoneService:GetSession(player)
	return stage ~= nil and stage.Id == session.zoneSessionId
end

local function send(session: Session, events: { CombatEngine.Event })
	local remote = eventRemote
	if remote and #events > 0 and session.player.Parent == Players then
		remote:FireClient(session.player, session.id, events)
	end
end

-- Applique les événements du moteur aux modèles (création, déplacement, mort) et à l'UI.
local function present(session: Session, events: { CombatEngine.Event }, moved: { [number]: boolean })
	local state = session.state
	for _, event in events do
		if event.Type == "UnitSpawned" then
			local unit = state.byId[event.UnitId]
			local points = if unit.Team == "Ally" then session.context.HeroPositions else session.context.EnemyPositions
			local anchor = if unit.Team == "Ally" then points[unit.Slot :: number] else points[unit.Cell :: number]
			local facing = if unit.Team == "Ally" then session.enemyFacing else session.allyFacing
			local model = session.context.SpawnUnit({ UnitId = unit.UnitId, Team = unit.Team, TypeId = unit.TypeId, Slot = unit.Slot }, anchor, facing)
			if model then
				model:SetAttribute("UnitId", unit.UnitId)
				model:SetAttribute("Team", unit.Team)
				model:SetAttribute("CombatId", session.id)
				session.models[unit.UnitId] = model
			end
		elseif event.Type == "UnitDied" then
			local model = session.models[event.UnitId]
			if model then
				session.models[event.UnitId] = nil
				model:SetAttribute("Alive", false)
				task.delay(CORPSE_DELAY, function()
					model:Destroy()
				end)
			end
		end
	end
	for unitId in moved do
		local unit = state.byId[unitId]
		local model = session.models[unitId]
		local target = if unit.TargetId then state.byId[unit.TargetId] else nil
		if model and unit.Alive then
			-- Le modèle garde sa hauteur de pivot ; seule la position au sol vient du moteur.
			local pivot = model:GetPivot()
			local position = Vector3.new(unit.Position.x, pivot.Position.Y, unit.Position.z)
			local look = if target then Vector3.new(target.Position.x, position.Y, target.Position.z) else position + pivot.LookVector
			if (look - position).Magnitude < 1e-3 then
				look = position + pivot.LookVector
			end
			model:PivotTo(CFrame.lookAt(position, look))
		end
	end
	-- Le CombatEnded du moteur reste interne : le client reçoit un seul CombatEnded, enrichi des
	-- récompenses, envoyé par finalize une fois le stage complété (voir finalize).
	local outgoing = {}
	for _, event in events do
		if event.Type ~= "CombatEnded" then
			table.insert(outgoing, event)
		end
	end
	send(session, outgoing)
end

-- Fin de combat, dans cet ordre et une seule fois :
--   moteur : Victory / Defeat → verrouillage de la session → ZoneService:CompleteStage
--   (QuestService, puis RewardService à la victoire) → CombatEnded final au client, avec
--   FirstClear et Rewards réellement attribués et déjà sauvegardés → callbacks (ArenaService).
local function finalize(session: Session)
	local result = session.state.result
	if not result or sessions[session.player] ~= session then
		return
	end
	-- Verrouiller d'abord : aucune seconde fin possible pour cette session.
	stop(session)
	local victory = result == "Victory"
	Log.info(SCOPE, `Combat {session.id} de {session.player.Name} : {if victory then "victoire" else "défaite"}`)
	local _, reward = ZoneService:CompleteStage(session.player, session.zoneSessionId, victory)
	send(session, { {
		Type = "CombatEnded",
		Result = result,
		FirstClear = if victory and reward then reward.FirstClear else false,
		Rewards = if victory and reward then reward.Rewards else {},
	} })
	for _, callback in endedCallbacks do
		task.spawn(callback, session.player, session.id, result)
	end
end

local function tick(dt: number)
	for player, session in sessions do
		if not contextAlive(session) then
			Log.info(SCOPE, `Combat {session.id} de {player.Name} annulé (départ, profil ou session de stage perdus)`)
			stop(session)
			continue
		end
		CombatEngine.advance(session.state, dt, session.speed)
		local events, moved = CombatEngine.drain(session.state)
		present(session, events, moved)
		finalize(session)
	end
end

-- Lance le combat de la session de stage zoneSessionId avec la formation choisie (slot -> classe).
-- Les ennemis viennent de la config du stage côté serveur, jamais du client.
function CombatService:StartCombat(player: Player, zoneSessionId: number, formation: { [number]: string }, context: ArenaContext): (number?, string?)
	local stage = ZoneService:GetSession(player)
	if not stage or stage.Id ~= zoneSessionId then
		return nil, "session de stage invalide"
	end
	local data = DataService:GetData(player)
	if not data then
		return nil, "données non chargées"
	end
	if sessions[player] then
		return nil, "combat déjà en cours"
	end
	local allies = {}
	for slot, classId in formation do
		if not CombatConfig.Heroes[classId] then
			return nil, "classe inconnue"
		end
		local feet = context.HeroPositions[slot]
		if not feet then
			return nil, "case héros invalide"
		end
		table.insert(allies, { TypeId = classId, Slot = slot, Position = flat(feet) })
	end
	if #allies == 0 then
		return nil, "formation vide"
	end
	if #allies > CombatConfig.MaxAllies then
		return nil, `{CombatConfig.MaxAllies} héros maximum`
	end
	local cells = {}
	local cellCount = 0
	for cell, feet in context.EnemyPositions do
		cells[cell] = flat(feet)
		cellCount += 1
	end
	local config = stage.Config
	local waves = config.Waves
	for _, wave in waves do
		local count = 0
		for _, group in wave.Enemies do
			if not CombatConfig.Enemies[group.EnemyId] then
				return nil, `ennemi sans stats : {group.EnemyId}`
			end
			count += group.Count
		end
		if count > cellCount then
			return nil, "trop d'ennemis pour l'arène"
		end
	end
	if config.MiniBoss and not CombatConfig.Enemies[config.MiniBoss.EnemyId] then
		return nil, `ennemi sans stats : {config.MiniBoss.EnemyId}`
	end

	local savedSpeed = data.Settings.CombatSpeed
	nextCombatId += 1
	local session: Session = {
		id = nextCombatId,
		player = player,
		zoneSessionId = zoneSessionId,
		zone = stage.Zone,
		stage = stage.Stage,
		speed = if isSpeed(savedSpeed) then savedSpeed else 1,
		state = CombatEngine.new({
			Stage = config,
			Heroes = CombatConfig.Heroes,
			Enemies = CombatConfig.Enemies,
			UltimateRadius = CombatConfig.Ultimate.Radius,
			Allies = allies,
			EnemyCells = cells,
			Random = Random.new(),
			TickRate = CombatConfig.TickRate,
			MaxFrameTime = CombatConfig.MaxFrameTime,
		}),
		context = context,
		models = {},
		enemyFacing = average(context.EnemyPositions),
		allyFacing = average(context.HeroPositions),
	}
	sessions[player] = session
	Log.info(SCOPE, `Combat {session.id} lancé par {player.Name} (stage {stage.Zone}-{stage.Stage}, {#allies} héros)`)
	local events, moved = CombatEngine.drain(session.state)
	table.insert(events, 2, { Type = "SpeedChanged", Speed = session.speed })
	present(session, events, moved)
	return session.id, nil
end

-- État lisible du combat du joueur (copie), ou nil.
function CombatService:GetCombat(player: Player): CombatView?
	local session = sessions[player]
	if not session or not contextAlive(session) then
		return nil
	end
	local units = {}
	for _, unit in session.state.units do
		table.insert(units, {
			UnitId = unit.UnitId,
			Team = unit.Team,
			TypeId = unit.TypeId,
			Slot = unit.Slot,
			Cell = unit.Cell,
			MiniBoss = unit.MiniBoss,
			Health = unit.Health,
			MaxHealth = unit.MaxHealth,
			Energy = unit.Energy,
			MaxEnergy = unit.MaxEnergy,
			Alive = unit.Alive,
		})
	end
	return {
		Id = session.id,
		ZoneSessionId = session.zoneSessionId,
		Zone = session.zone,
		Stage = session.stage,
		Wave = session.state.waveIndex,
		WaveCount = #session.state.waves,
		Speed = session.speed,
		Units = units,
	}
end

-- Arrête le combat sans résultat (Quitter) : aucune fin de stage n'est annoncée.
function CombatService:CancelCombat(player: Player): boolean
	local session = sessions[player]
	if not session then
		return false
	end
	stop(session)
	Log.info(SCOPE, `Combat {session.id} de {player.Name} annulé`)
	return true
end

-- Vitesse x1 ou x2 : accélère la simulation, jamais les stats. Mémorisée dans Settings.CombatSpeed.
function CombatService:SetSpeed(player: Player, speed: any): (boolean, string?)
	if not isSpeed(speed) then
		return false, "vitesse invalide"
	end
	local data = DataService:GetData(player)
	if data then
		data.Settings.CombatSpeed = speed
	end
	local session = sessions[player]
	if session and session.speed ~= speed then
		session.speed = speed
		send(session, { { Type = "SpeedChanged", Speed = speed } })
	end
	return true, nil
end

-- callback(player, combatId, "Victory" | "Defeat") après l'annonce à ZoneService.
function CombatService:OnCombatEnded(callback: EndedCallback)
	table.insert(endedCallbacks, callback)
end

function CombatService:Start()
	Players.PlayerRemoving:Connect(function(player: Player)
		local session = sessions[player]
		if session then
			stop(session)
		end
	end)
	RunService.Heartbeat:Connect(tick)

	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end
	assert(remotes)
	local events = Instance.new("RemoteEvent")
	events.Name = "CombatEvent"
	events.Parent = remotes
	eventRemote = events
	-- Seule demande client pendant un combat : la vitesse, 1 ou 2.
	local speed = Instance.new("RemoteFunction")
	speed.Name = "SetCombatSpeed"
	speed.OnServerInvoke = function(player: Player, value: any): (boolean, string?)
		return CombatService:SetSpeed(player, value)
	end
	speed.Parent = remotes
end

return CombatService
