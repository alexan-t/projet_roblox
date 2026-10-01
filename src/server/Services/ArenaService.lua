--!strict
-- Arène de test (voir docs/ARENA_PROTOTYPE.md) : préparation directement dans le monde.
-- Le joueur prend un héros en main (hotbar ou collection, côté client) et le pose sur une case
-- "CaseHeros" : Remotes.ArenaAction("Place", case, HeroInstanceId). Il peut le déplacer (Place sur
-- une autre case) ou le retirer ("Remove", case). Jusqu'à 4 héros. Près de l'étendard, E
-- ("Combattre") démarre le combat aussitôt. Quitter pendant le combat : ArenaAction("Leave").
-- Les règles sont dans ArenaPrep (pur, testé) ; ce service gère le monde : modèles, prompt,
-- remotes, géométrie passée à CombatService. Le client ne décide jamais d'un placement.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Log = require(ReplicatedStorage.Shared.Utils.Log)
local ArenaConfig = require(ReplicatedStorage.Shared.Config.ArenaConfig)
local ArenaRules = require(script.Parent.Parent.Arena.ArenaRules)
local ArenaPrep = require(script.Parent.Parent.Arena.ArenaPrep)
local CombatService = require(script.Parent.CombatService)
local HeroService = require(script.Parent.HeroService)
local ZoneService = require(script.Parent.ZoneService)

-- Objets du monde d'une préparation (dossier répliqué, mannequins).
type World = {
	prep: ArenaPrep.Prep,
	folder: Folder,
	heroes: Folder,
	enemies: Folder,
	loopWas: any,
	shownPhase: ArenaPrep.Phase?,
	shownFormation: string,
}

local SCOPE = "ArenaService"
local ENEMY_CELLS = 9
-- Laisse PlotService poser le personnage sur son plot avant de le déplacer vers l'arène de test.
local TEST_SPAWN_DELAY = 1

local ArenaService = {}

local arena: Instance? = nil
local poses: { [number]: BasePart } = {}
local front: BasePart? = nil
local stateEvent: RemoteEvent? = nil
local manager: ArenaPrep.Manager
local world: World? = nil

local function resolve(root: Instance, path: { string }): Instance?
	local node: Instance? = root
	for _, name in path do
		node = if node then node:FindFirstChild(name) else nil
	end
	return node
end

local function findFront(root: Instance): BasePart?
	local zones = root:FindFirstChild("Zones")
	if not zones then
		return nil
	end
	for _, zone in zones:GetChildren() do
		if zone:GetAttribute("ZoneId") == ArenaConfig.Zone then
			local sources = zone:FindFirstChild("SourcesEnnemis")
			local part = sources and sources:FindFirstChild("FrontEnnemi")
			return if part and part:IsA("BasePart") then part else nil
		end
	end
	return nil
end

-- Clone un mannequin du design tel quel, pieds sur `feet`, tourné vers `lookAt`.
local function spawnModel(templateName: string, parent: Instance, feet: Vector3, lookAt: Vector3, attributes: { [string]: any }?): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Combat")
	local template = folder and folder:FindFirstChild(templateName)
	if not template or not template:IsA("Model") then
		Log.warn(SCOPE, `Modèle introuvable : ReplicatedStorage.Assets.Combat.{templateName}`)
		return nil
	end
	local model = template:Clone()
	local minY = math.huge
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			minY = math.min(minY, part.Position.Y - part.Size.Y / 2)
		end
	end
	local pivot = model:GetPivot()
	local position = feet + Vector3.new(0, pivot.Position.Y - minY, 0)
	local target = Vector3.new(lookAt.X, position.Y, lookAt.Z)
	if (target - position).Magnitude < 1e-3 then
		target = position + Vector3.new(0, 0, -1)
	end
	model:PivotTo(CFrame.lookAt(position, target))
	-- HeroClass (icône discrète côté client), HeroInstanceId et Slot (sélection d'un héros posé).
	for key, value in attributes or {} do
		model:SetAttribute(key, value)
	end
	model.Parent = parent
	return model
end

local function heroFeet(pose: BasePart): Vector3
	return Vector3.new(pose.Position.X, pose.Position.Y - pose.Size.Y / 2 + 0.1, pose.Position.Z)
end

-- Case 1..9 du 3x3 ennemi, découpé dans FrontEnnemi. Ligne 1 = côté héros, colonnes comme les cases héros.
local function enemyFeet(part: BasePart, cell: number): Vector3
	local column = (cell - 1) % 3
	local row = (cell - 1) // 3
	local offset = Vector3.new((column - 1) * part.Size.X / 3, 0, (1 - row) * part.Size.Z / 3)
	local p = (part.CFrame * CFrame.new(offset)).Position
	return Vector3.new(p.X, part.Position.Y - part.Size.Y / 2 + 0.1, p.Z)
end

local function heroIdOf(player: Player, instanceId: string): string?
	return (HeroService:GetCombatHero(player, instanceId))
end

local function stateOf(player: Player, message: string?): { [string]: any }
	local prep = manager.current
	if not prep or prep.player ~= player then
		return { Phase = "Closed", MaxHeroes = ArenaConfig.MaxHeroes, Message = message }
	end
	local session = ZoneService:GetSession(player)
	local formation = {}
	for slot, instanceId in prep.formation do
		table.insert(formation, { Slot = slot, HeroInstanceId = instanceId, HeroId = heroIdOf(player, instanceId) })
	end
	return {
		Phase = prep.phase,
		Zone = ArenaConfig.Zone,
		Stage = ArenaConfig.Stage,
		Enemies = if session then ArenaRules.summarize(session.Config) else {},
		Formation = formation,
		MaxHeroes = ArenaConfig.MaxHeroes,
		Message = message,
	}
end

local function send(player: Player, message: string?)
	local event = stateEvent
	if event and player.Parent == Players then
		event:FireClient(player, stateOf(player, message))
	end
end

local function formationKey(prep: ArenaPrep.Prep): string
	local parts = {}
	for slot = 1, ArenaRules.GRID_CELLS do
		table.insert(parts, prep.formation[slot] or "")
	end
	return table.concat(parts, "|")
end

local function rebuildHeroes(w: World)
	w.heroes:ClearAllChildren()
	local facing = if front then front.Position else Vector3.zero
	for slot, instanceId in w.prep.formation do
		local pose = poses[slot]
		if pose then
			spawnModel(ArenaConfig.HeroTemplate, w.heroes, heroFeet(pose), facing, {
				HeroClass = heroIdOf(w.prep.player, instanceId),
				HeroInstanceId = instanceId,
				Slot = slot,
			})
		end
	end
end

-- Aligne le monde sur la préparation courante (création, mannequins, rangement).
local function sync()
	local prep = manager.current
	local w = world
	local root = arena
	if w and w.prep ~= prep then
		world = nil
		w.folder:Destroy()
		if root then
			root:SetAttribute("IntroDemoBoucle", w.loopWas)
		end
		w = nil
	end
	if prep and not w and root then
		local folder = Instance.new("Folder")
		folder.Name = `PreparationCombat_{prep.player.UserId}`
		local heroes = Instance.new("Folder")
		heroes.Name = "Heros"
		heroes.Parent = folder
		local enemies = Instance.new("Folder")
		enemies.Name = "Ennemis"
		enemies.Parent = folder
		folder.Parent = Workspace
		w = { prep = prep, folder = folder, heroes = heroes, enemies = enemies, loopWas = root:GetAttribute("IntroDemoBoucle"), shownPhase = nil, shownFormation = "" }
		-- L'intro de démonstration en boucle réutilise les mêmes cases : suspendue (runtime seulement).
		root:SetAttribute("IntroDemoBoucle", false)
		world = w
	end
	if w and w.prep.phase == "Placement" then
		local key = formationKey(w.prep)
		if w.shownPhase ~= "Placement" or w.shownFormation ~= key then
			rebuildHeroes(w)
			w.shownFormation = key
		end
	end
	if w then
		w.shownPhase = w.prep.phase
	end
	if root then
		-- Visible par tous les clients : grise les cases quand l'arène est prise par un autre joueur.
		root:SetAttribute("Occupant", if prep then prep.player.UserId else nil)
	end
end

-- Passe la formation et la géométrie de l'arène à CombatService, qui crée les unités.
local function startCombat(player: Player, sessionId: number, classes: { [number]: string }): (number?, string?)
	local part = front
	local w = world
	if not part or not w then
		return nil, "arène indisponible"
	end
	local heroPositions, enemyPositions = {}, {}
	for slot, pose in poses do
		heroPositions[slot] = heroFeet(pose)
	end
	for cell = 1, ENEMY_CELLS do
		enemyPositions[cell] = enemyFeet(part, cell)
	end
	local formation = table.clone(w.prep.formation)
	w.heroes:ClearAllChildren() -- les mannequins de placement cèdent la place aux unités de combat
	local combatId, reason = CombatService:StartCombat(player, sessionId, classes, {
		HeroPositions = heroPositions,
		EnemyPositions = enemyPositions,
		SpawnUnit = function(unit, feet: Vector3, lookAt: Vector3): Model?
			if unit.Team == "Ally" then
				return spawnModel(ArenaConfig.HeroTemplate, w.heroes, feet, lookAt, {
					HeroClass = unit.TypeId,
					HeroInstanceId = if unit.Slot then formation[unit.Slot] else nil,
				})
			end
			local template = ArenaConfig.EnemyTemplates[unit.TypeId]
			return if template then spawnModel(template, w.enemies, feet, lookAt, nil) else nil
		end,
	})
	if not combatId then
		w.shownPhase = nil -- les mannequins de placement seront reposés
	end
	return combatId, reason
end

local function onAction(player: Player, action: any, slot: any, instanceId: any): (boolean, string?)
	local ok, reason
	if action == "Place" then
		ok, reason = manager:place(player, slot, instanceId)
	elseif action == "Remove" then
		ok, reason = manager:remove(player, slot)
	elseif action == "Leave" then
		ok = manager:leave(player)
		reason = if ok then nil else "aucun combat en cours"
	else
		return false, "action inconnue"
	end
	sync()
	send(player, reason)
	return ok, reason
end

local function onPrompt(player: Player)
	local ok, reason = manager:fight(player)
	sync()
	send(player, if ok then nil else reason)
end

function ArenaService:Init()
	manager = ArenaPrep.new({
		maxHeroes = ArenaConfig.MaxHeroes,
		name = function(player: Player): string
			return player.Name
		end,
		startStage = function(player: Player): (number?, string?)
			local session, reason = ZoneService:StartStage(player, ArenaConfig.Zone, ArenaConfig.Stage)
			return if session then session.Id else nil, reason
		end,
		sessionAlive = function(player: Player, sessionId: number): boolean
			local session = ZoneService:GetSession(player)
			return session ~= nil and session.Id == sessionId
		end,
		cancelStage = function(player: Player)
			ZoneService:CancelStage(player)
		end,
		heroOf = function(player: Player, instanceId: any): (string?, string?)
			return HeroService:GetCombatHero(player, instanceId)
		end,
		startCombat = startCombat,
		cancelCombat = function(player: Player)
			CombatService:CancelCombat(player)
		end,
	})

	local found = resolve(Workspace, ArenaConfig.ArenaPath)
	if not found then
		Log.warn(SCOPE, `Arène de test Workspace.{table.concat(ArenaConfig.ArenaPath, ".")} introuvable ; prototype désactivé`)
		return
	end
	local cases = found:FindFirstChild("Emplacements")
	cases = cases and cases:FindFirstChild("Heros")
	if cases then
		for _, case in cases:GetChildren() do
			local slot = case:GetAttribute("Slot")
			local pose = case:FindFirstChild("PointDePose")
			if typeof(slot) == "number" and pose and pose:IsA("BasePart") then
				poses[slot] = pose
			end
		end
	end
	front = findFront(found)
	local slots = 0
	for slot = 1, ArenaRules.GRID_CELLS do
		if poses[slot] then
			slots += 1
		end
	end
	if slots ~= ArenaRules.GRID_CELLS or not front then
		Log.warn(SCOPE, `Arène de test incomplète ({slots}/9 cases héros, FrontEnnemi {if front then "ok" else "absent"}) ; prototype désactivé`)
		table.clear(poses)
		front = nil
		return
	end
	arena = found
end

function ArenaService:Start()
	local root = arena
	local marker = if root then resolve(root, { "Emplacements", "PointEtendard" }) else nil
	if not root or not marker then
		return
	end
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end
	assert(remotes)
	local event = Instance.new("RemoteEvent")
	event.Name = "ArenaState"
	event.Parent = remotes
	stateEvent = event
	local action = Instance.new("RemoteFunction")
	action.Name = "ArenaAction"
	action.OnServerInvoke = onAction
	action.Parent = remotes

	-- E près de l'étendard : combat immédiat avec les héros posés.
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Combattre"
	prompt.ActionText = "Combattre"
	prompt.ObjectText = `Stage {ArenaConfig.Zone}-{ArenaConfig.Stage}`
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 45
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(onPrompt)
	prompt.Parent = marker

	-- Prototype, Studio uniquement : apparaître directement à côté de l'arène de test.
	local spawnPath = ArenaConfig.TestSpawn
	local spawnMarker = if spawnPath and RunService:IsStudio() then resolve(Workspace, spawnPath) else nil
	if spawnMarker and spawnMarker:IsA("BasePart") then
		local spawnPart: BasePart = spawnMarker
		local function onCharacter(character: Model)
			task.delay(TEST_SPAWN_DELAY, function()
				if character.Parent and character:FindFirstChild("HumanoidRootPart") then
					character:PivotTo(CFrame.new(spawnPart.Position + Vector3.new(0, spawnPart.Size.Y / 2 + 3, 0)))
				end
			end)
		end
		local function watchPlayer(player: Player)
			player.CharacterAdded:Connect(onCharacter)
			if player.Character then
				onCharacter(player.Character)
			end
		end
		Players.PlayerAdded:Connect(watchPlayer)
		for _, player in Players:GetPlayers() do
			watchPlayer(player)
		end
	end

	-- Fin de combat : résultat affiché, arène rangée (ZoneService a déjà été prévenu).
	CombatService:OnCombatEnded(function(player: Player, combatId: number, result: string)
		manager:combatEnded(player, combatId)
		sync()
		send(player, if result == "Victory" then "Victoire !" else "Défaite…")
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		if manager:release(player) then
			sync()
		end
	end)

	-- Session de stage terminée ailleurs (debug, perte de profil) : l'arène est rangée.
	task.spawn(function()
		while true do
			task.wait(1)
			local prep = manager.current
			if prep and manager:check() then
				sync()
				send(prep.player, "Stage terminé")
			end
		end
	end)
end

return ArenaService
