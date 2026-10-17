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
-- Roster (facultatif, #68) : par case, l'exemplaire réellement posé, figé au lancement par ArenaService
-- (HeroService:GetCombatRoster) : son profil doit être celui de la formation ; ses Stats (niveau) sont
-- celles de l'unité. GrantXP (facultatif) : appelé UNE fois, seulement après une victoire acceptée par
-- ZoneService, avec les HeroInstanceId du roster ; renvoie la vue de progression envoyée au client.
export type RosterEntry = { HeroInstanceId: string, CombatProfile: string, Stats: { [string]: any } }
export type ArenaContext = {
	HeroPositions: { [number]: Vector3 }, -- slot 1..9 -> pieds
	EnemyPositions: { [number]: Vector3 }, -- case 1..9 -> pieds
	SpawnUnit: (unit: { UnitId: number, Team: string, TypeId: string, Slot: number? }, feet: Vector3, lookAt: Vector3) -> Model?,
	Roster: { [number]: RosterEntry }?,
	GrantXP: ((participants: { string }, zone: number, stage: number) -> { any })?,
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
	-- Secondes de simulation encore retenues pour la mise en scène (EntranceHold) : le moteur n'avance pas.
	hold: number,
	-- HeroInstanceId des héros engagés dans CE combat (figés au lancement) : seuls eux gagnent l'XP.
	participants: { string },
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

-- keep : fin normale (victoire / défaite) : les modèles restent EndHold secondes (outro du client),
-- puis sont retirés. Annulation, départ : retirés tout de suite.
local function stop(session: Session, keep: boolean?)
	if sessions[session.player] == session then
		sessions[session.player] = nil
	end
	local models = table.clone(session.models)
	table.clear(session.models)
	if keep then
		task.delay(CombatConfig.Presentation.EndHold, function()
			for _, model in models do
				model:Destroy()
			end
		end)
	else
		for _, model in models do
			model:Destroy()
		end
	end
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
--   (QuestService, puis RewardService à la victoire) → XP des participants (victoire acceptée par
--   ZoneService seulement) → CombatEnded final au client, avec FirstClear, Rewards et HeroProgression
--   réellement attribués et déjà sauvegardés → callbacks (ArenaService).
local function finalize(session: Session)
	local result = session.state.result
	if not result or sessions[session.player] ~= session then
		return
	end
	-- Verrouiller d'abord : aucune seconde fin possible pour cette session (modèles gardés pour l'outro).
	stop(session, true)
	local victory = result == "Victory"
	Log.info(SCOPE, `Combat {session.id} de {session.player.Name} : {if victory then "victoire" else "défaite"}`)
	local completed, reward = ZoneService:CompleteStage(session.player, session.zoneSessionId, victory)
	-- XP : victoire de CETTE session acceptée par ZoneService, une seule fois (la session est déjà verrouillée).
	local progression = {}
	local grant = session.context.GrantXP
	if victory and completed and grant and #session.participants > 0 then
		local ok, views = pcall(grant, table.clone(session.participants), session.zone, session.stage)
		if ok and typeof(views) == "table" then
			progression = views
		elseif not ok then
			Log.warn(SCOPE, `XP du combat {session.id} non attribuée : {tostring(views)}`)
		end
	end
	send(session, { {
		Type = "CombatEnded",
		Result = result,
		FirstClear = if victory and reward then reward.FirstClear else false,
		Rewards = if victory and reward then reward.Rewards else {},
		HeroProgression = progression,
	} })
	for _, callback in endedCallbacks do
		task.spawn(callback, session.player, session.id, result)
	end
end

-- Mise en scène : après une vague suivante ou le mini-boss, le moteur est retenu le temps que le client
-- fasse entrer les nouveaux ennemis depuis le décor (respiration + plus longue entrée de la vague).
-- Le client reçoit la durée exacte (EntranceHold) et cale ses entrées dessus.
-- Durée de retenue pour un lot d'événements contenant une nouvelle vague (1re comprise) ou le mini-boss :
-- respiration + plus longue entrée des ennemis apparus. nil : rien de nouveau.
local function entranceHold(events: { CombatEngine.Event }): (number?, number?)
	local presentation = CombatConfig.Presentation
	local breather: number? = nil
	for _, event in events do
		if event.Type == "WaveStarted" then
			breather = if (event.Wave :: number) > 1 then presentation.WaveBreather else presentation.StartBreather
		elseif event.Type == "MiniBossStarted" then
			breather = presentation.WaveBreather
		end
	end
	if not breather then
		return nil, nil
	end
	local longest = 0
	for _, event in events do
		if event.Type == "UnitSpawned" and event.Team == "Enemy" then
			longest = math.max(longest, presentation.Entrance[event.TypeId :: string] or presentation.DefaultEntrance)
		end
	end
	return breather + longest, breather
end

local function tick(dt: number)
	for player, session in sessions do
		if not contextAlive(session) then
			Log.info(SCOPE, `Combat {session.id} de {player.Name} annulé (départ, profil ou session de stage perdus)`)
			stop(session)
			continue
		end
		-- Temps retenu pour la mise en scène : consommé avant de faire avancer le moteur.
		local step = dt
		if session.hold > 0 then
			local used = math.min(session.hold, step)
			session.hold -= used
			step -= used
		end
		if step > 0 then
			CombatEngine.advance(session.state, step, session.speed)
		end
		local events, moved = CombatEngine.drain(session.state)
		local hold, breather = entranceHold(events)
		if hold then
			session.hold = hold
			table.insert(events, { Type = "EntranceHold", Duration = hold, Breather = breather })
		end
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
	local participants: { string } = {}
	for slot, classId in formation do
		if not CombatConfig.Heroes[classId] then
			return nil, "classe inconnue"
		end
		local feet = context.HeroPositions[slot]
		if not feet then
			return nil, "case héros invalide"
		end
		local entry = if context.Roster then context.Roster[slot] else nil
		if context.Roster and (not entry or entry.CombatProfile ~= classId) then
			return nil, "équipe modifiée"
		end
		table.insert(allies, { TypeId = classId, Slot = slot, Position = flat(feet), Stats = if entry then table.clone(entry.Stats) else nil })
		if entry then
			table.insert(participants, entry.HeroInstanceId)
		end
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
		hold = 0, -- fixé ci-dessous : la 1re vague entre depuis le décor avant que le moteur ne démarre
		participants = participants,
	}
	sessions[player] = session
	Log.info(SCOPE, `Combat {session.id} lancé par {player.Name} (stage {stage.Zone}-{stage.Stage}, {#allies} héros)`)
	local events, moved = CombatEngine.drain(session.state)
	table.insert(events, 2, { Type = "SpeedChanged", Speed = session.speed })
	local hold, breather = entranceHold(events)
	session.hold = hold or 0
	table.insert(events, { Type = "EntranceHold", Duration = session.hold, Breather = breather or 0 })
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
