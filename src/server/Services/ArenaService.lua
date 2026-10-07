--!strict
-- Une préparation et un monde par propriétaire. Aucun chemin vers la sandbox.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config.ArenaConfig)
local ArenaRules = require(script.Parent.Parent.Arena.ArenaRules)
local ArenaPrep = require(script.Parent.Parent.Arena.ArenaPrep)
local PlotService = require(script.Parent.PlotService)
local HeroService = require(script.Parent.HeroService)
local ZoneService = require(script.Parent.ZoneService)
local CombatService = require(script.Parent.CombatService)
local StageConfig = require(script.Parent.Parent.Config.StageConfig)
local ArenaService = {}
local manager: ArenaPrep.Manager
local contexts: { [Player]: any } = {}
local worlds: { [Player]: any } = {}
local stateEvent: RemoteEvent
local lastAction: { [Player]: number } = {}
local stateVersion: { [Player]: number } = {}

local function context(player: Player): any
	local c = contexts[player]
	if c and PlotService:GetPlot(player) == c.plot and PlotService:GetOwner(c.plot) == player
		and PlotService:GetRuntime(player) == c.runtime and c.arena.Parent == c.plot then return c end
	return nil
end

local function flat(v: Vector3): ArenaRules.Point
	return { x = v.X, z = v.Z }
end

-- Le joueur agit-il réellement depuis SA zone de préparation (et, pour une dalle, à portée) ?
-- Position = celle que le serveur connaît du personnage vivant.
local function canInteract(player: Player, c: any, slot: number?): (boolean, string?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
		return false, "Approche-toi de ton arène"
	end
	local pose = if slot then c.poses[slot] else nil
	return ArenaRules.canInteract(flat(root.Position), c.zone, if pose then flat(pose.Position) else nil, Config.InteractionDistance)
end

local function spawnModel(templateName: string, parent: Instance, feet: Vector3, lookAt: Vector3, attributes: any): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local templates = assets and assets:FindFirstChild("Combat")
	local template = templates and templates:FindFirstChild(templateName)
	if not template or not template:IsA("Model") then return nil end
	local model = template:Clone()
	for _, child in model:GetDescendants() do
		if child:IsA("BaseScript") then child:Destroy()
		elseif child:IsA("BasePart") then
			child.Anchored, child.CanCollide, child.CanTouch = true, false, false
		end
	end
	local box, size = model:GetBoundingBox()
	local pivot = model:GetPivot()
	local position = feet + Vector3.new(0, pivot.Position.Y - box.Position.Y + size.Y / 2, 0)
	model:PivotTo(CFrame.lookAt(position, Vector3.new(lookAt.X, position.Y, lookAt.Z)))
	for key, value in attributes or {} do model:SetAttribute(key, value) end
	model.Parent = parent
	return model
end

local function feet(pose: BasePart): Vector3
	return pose.Position - Vector3.new(0, pose.Size.Y / 2 - 0.1, 0)
end

local function heroTemplate(heroId: string): string
	return `Heros_{heroId}` -- modèles provisoires par classe, communs au preview
end

local function stageConfigOf(zone: number, stage: number): any
	local zones = StageConfig.Zones
	local entry = zones and zones[zone]
	return entry and entry.Stages and entry.Stages[stage] or nil
end

local function stateOf(player: Player, message: string?): any
	local prep = manager.preps[player]
	local formation = {}
	if prep then
		for slot, instanceId in prep.formation do
			table.insert(formation, { Slot = slot, HeroInstanceId = instanceId, HeroId = HeroService:GetCombatHero(player, instanceId) })
		end
	end
	-- Stage réellement courant (session) ou stage que l'arène lancera ; ennemis agrégés, sans position.
	local session = if prep then ZoneService:GetSession(player) else nil
	local zone = if session then session.Zone else Config.Zone
	local stageNumber = if session then session.Stage else Config.Stage
	local stage = if session then session.Config else stageConfigOf(zone, stageNumber)
	-- Numéro croissant par joueur : le client ignore un état plus ancien que celui qu'il a déjà
	-- (la lecture initiale GetArenaState peut arriver après un ArenaState plus récent).
	stateVersion[player] = (stateVersion[player] or 0) + 1
	return { Version = stateVersion[player], Phase = if prep then prep.phase else "Closed", Formation = formation,
		MaxHeroes = Config.MaxHeroes, Zone = zone, Stage = stageNumber,
		Enemies = if stage then ArenaRules.summarize(stage) else {},
		Available = context(player) ~= nil, Message = message }
end

local function send(player: Player, message: string?)
	if player.Parent == Players then stateEvent:FireClient(player, stateOf(player, message)) end
end

local function rebuild(player: Player, w: any, c: any)
	w.heroes:ClearAllChildren()
	for slot, id in w.prep.formation do
		local heroId = HeroService:GetCombatHero(player, id)
		if heroId then spawnModel(heroTemplate(heroId), w.heroes, feet(c.poses[slot]), c.front.Position,
			{ HeroClass = heroId, HeroInstanceId = id, Slot = slot, OwnerUserId = player.UserId }) end
	end
end

local function sync(player: Player)
	local prep, c, w = manager.preps[player], context(player), worlds[player]
	if w and (w.prep ~= prep or not c or w.folder.Parent ~= c.runtime) then
		w.folder:Destroy()
		worlds[player], w = nil, nil
	end
	if prep and c and not w then
		local folder = Instance.new("Folder")
		folder.Name = "PreparationCombat"
		folder:SetAttribute("OwnerUserId", player.UserId)
		local heroes, enemies = Instance.new("Folder"), Instance.new("Folder")
		heroes.Name, enemies.Name = "Heros", "Ennemis"
		heroes.Parent, enemies.Parent = folder, folder
		folder.Parent = c.runtime
		w = { prep = prep, folder = folder, heroes = heroes, enemies = enemies }
		worlds[player] = w
	end
	if w and prep.phase == "Placement" then rebuild(player, w, c) end
end

local function startCombat(player: Player, sessionId: number, classes: { [number]: string }): (number?, string?)
	local c, w = context(player), worlds[player]
	if not c or not w then return nil, "arène indisponible" end
	local heroPositions, enemyPositions = {}, {}
	for slot, pose in c.poses do heroPositions[slot] = feet(pose) end
	for cell = 1, 9 do
		local offset = Vector3.new(((cell - 1) % 3 - 1) * c.front.Size.X / 3, -c.front.Size.Y / 2 + 0.1, (1 - (cell - 1) // 3) * c.front.Size.Z / 3)
		enemyPositions[cell] = c.front.CFrame:PointToWorldSpace(offset)
	end
	local formation = table.clone(w.prep.formation)
	w.heroes:ClearAllChildren()
	return CombatService:StartCombat(player, sessionId, classes, {
		HeroPositions = heroPositions, EnemyPositions = enemyPositions,
		SpawnUnit = function(unit, position: Vector3, lookAt: Vector3): Model?
			if context(player) ~= c or worlds[player] ~= w then return nil end
			local ally = unit.Team == "Ally"
			local template = if ally then heroTemplate(unit.TypeId) else Config.EnemyTemplates[unit.TypeId]
			return if template then spawnModel(template, if ally then w.heroes else w.enemies, position, lookAt,
				{ OwnerUserId = player.UserId, HeroClass = if ally then unit.TypeId else nil,
					HeroInstanceId = if ally and unit.Slot then formation[unit.Slot] else nil }) else nil
		end,
	})
end

local function cleanup(player: Player)
	manager:leave(player)
	sync(player)
	contexts[player] = nil
end

local function setup(player: Player, plot: Model)
	cleanup(player)
	local runtime = PlotService:GetRuntime(player)
	local arena = plot:FindFirstChild(Config.ArenaName)
	local emplacements = arena and arena:FindFirstChild("Emplacements")
	local heroes = emplacements and emplacements:FindFirstChild("Heros")
	local marker = emplacements and emplacements:FindFirstChild("PointEtendard")
	local front = arena and arena:FindFirstChild("FrontEnnemi", true)
	if not runtime or not heroes or not marker or not marker:IsA("BasePart") or not front or not front:IsA("BasePart") then
		warn(`ArenaService : repères manquants dans {plot:GetFullName()}`)
		return
	end
	local poses = {}
	for _, case in heroes:GetChildren() do
		local slot, pose = case:GetAttribute("Slot"), case:FindFirstChild("PointDePose")
		if ArenaRules.isSlot(slot) and pose and pose:IsA("BasePart") then poses[slot] = pose end
	end
	for slot = 1, 9 do if not poses[slot] then warn(`ArenaService : case {slot} absente`); return end end
	-- Plus de prompt « Combattre » : E sert au placement (prompt local du client sur la dalle la
	-- plus proche) et le combat démarre par le bouton Prêt (ArenaAction "Ready").
	local points = {}
	for slot, pose in poses do
		points[slot] = flat(pose.Position)
	end
	contexts[player] = { plot = plot, runtime = runtime, arena = arena, poses = poses, front = front,
		zone = ArenaRules.zone(points, Config.ZoneMargin) }
	send(player)
end

function ArenaService:Init()
	manager = ArenaPrep.new({ maxHeroes = Config.MaxHeroes, name = function(p) return p.Name end,
		startStage = function(player)
			local session, reason = ZoneService:StartStage(player, Config.Zone, Config.Stage)
			return if session then session.Id else nil, reason
		end,
		sessionAlive = function(player, id)
			local session = ZoneService:GetSession(player)
			return context(player) ~= nil and session ~= nil and session.Id == id
		end,
		cancelStage = function(player) ZoneService:CancelStage(player) end,
		heroOf = function(player, id) return HeroService:GetCombatHero(player, id) end,
		startCombat = startCombat, cancelCombat = function(player) CombatService:CancelCombat(player) end,
	})
end

function ArenaService:Start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	stateEvent = Instance.new("RemoteEvent")
	stateEvent.Name, stateEvent.Parent = "ArenaState", remotes
	local get = Instance.new("RemoteFunction")
	get.Name = "GetArenaState"
	get.OnServerInvoke = function(player) return stateOf(player) end
	get.Parent = remotes
	local action = Instance.new("RemoteFunction")
	action.Name = "ArenaAction"
	action.OnServerInvoke = function(player, verb, slot, instanceId)
		local now = os.clock()
		if now - (lastAction[player] or -math.huge) < 0.12 then return false, "Patiente un instant" end
		lastAction[player] = now
		local c = context(player)
		if not c then return false, "Ton arène est indisponible" end
		local ok, reason
		-- L'arène visée est toujours celle du plot du joueur (c) : aucune action sur l'arène d'un autre.
		if verb == "Leave" then ok = manager:leave(player) -- abandonner reste possible de partout
		elseif verb == "Ready" then
			local inZone, why = canInteract(player, c, nil)
			if not inZone then return false, why end
			ok, reason = manager:ready(player)
		elseif verb == "Place" or verb == "Remove" then
			if not ArenaRules.isSlot(slot) then return false, "case invalide" end
			local inReach, why = canInteract(player, c, slot)
			if not inReach then return false, why end
			if verb == "Place" then ok, reason = manager:place(player, slot, instanceId)
			else ok, reason = manager:remove(player, slot) end
		else return false, "action inconnue" end
		sync(player)
		send(player)
		return ok, reason, stateOf(player)
	end
	action.Parent = remotes
	PlotService:OnPlotAssigned(setup)
	CombatService:OnCombatEnded(function(player, id, result)
		if manager:combatEnded(player, id) then
			sync(player)
			send(player, if result == "Victory" then "Victoire !" else "Défaite…")
		end
	end)
	local function watch(player: Player)
		player.CharacterRemoving:Connect(function()
			manager:leave(player); sync(player); send(player)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do watch(player) end
	Players.PlayerRemoving:Connect(function(player) cleanup(player); lastAction[player] = nil; stateVersion[player] = nil end)
	task.spawn(function()
		while true do
			task.wait(1)
			for player in contexts do
				if not context(player) then cleanup(player); send(player, "Plot indisponible")
				elseif manager:check(player) then
					CombatService:CancelCombat(player); sync(player); send(player, "Stage terminé")
				end
			end
		end
	end)
end

return ArenaService
