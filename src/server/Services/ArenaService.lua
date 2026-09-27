--!strict
-- PROTOTYPE de préparation de combat sur l'arène de test (voir docs/ARENA_PROTOTYPE.md).
-- Près de l'arène, le joueur lance le stage (ZoneService), pose jusqu'à 4 héros de sa collection
-- sur le 3x3 des cases "CaseHeros", puis lance le combat : les ennemis du stage apparaissent
-- alors au hasard sur le 3x3 de FrontEnnemi, nouveau tirage à chaque combat.
-- Aucun combat réel (dégâts, PV, IA, victoire) : c'est CombatService (#8).
-- Tout est décidé par le serveur ; le client n'envoie que "case" et "classe"
-- (actions Assign, Clear, Fight, Leave de Remotes.ArenaAction).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Log = require(ReplicatedStorage.Shared.Utils.Log)
local ArenaConfig = require(ReplicatedStorage.Shared.Config.ArenaConfig)
local ArenaRules = require(script.Parent.Parent.Arena.ArenaRules)
local ZoneService = require(script.Parent.ZoneService)

type Phase = "Placement" | "Combat"
type Prep = {
	player: Player,
	sessionId: number,
	phase: Phase,
	formation: ArenaRules.Formation,
	folder: Folder,
	heroes: Folder,
	enemies: Folder,
	layout: { [number]: ArenaRules.Enemy }?,
	loopWas: any,
}

local SCOPE = "ArenaService"
local ENEMY_CELLS = 9
-- Laisse PlotService poser le personnage sur son plot avant de le déplacer vers l'arène de test.
local TEST_SPAWN_DELAY = 1

local ArenaService = {}

local arena: Instance? = nil
local poses: { [number]: BasePart } = {}
local front: BasePart? = nil
local current: Prep? = nil
local stateEvent: RemoteEvent? = nil
local validClasses: { [string]: boolean } = {}
local classNames: { [string]: string } = {}

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

local function average(parts: { [number]: BasePart }): Vector3
	local sum, n = Vector3.zero, 0
	for _, part in parts do
		sum += part.Position
		n += 1
	end
	return if n > 0 then sum / n else Vector3.zero
end

-- Clone un mannequin du design tel quel, pieds sur `feet`, tourné vers `lookAt`.
local function spawnModel(templateName: string, parent: Instance, feet: Vector3, lookAt: Vector3, label: string?): Model?
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
			part.CanQuery = false
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
	if label then
		-- Étiquette provisoire : les vrais modèles de héros distingueront les classes.
		local _, size = model:GetBoundingBox()
		local gui = Instance.new("BillboardGui")
		gui.Name = "Etiquette"
		gui.Size = UDim2.fromOffset(110, 26)
		gui.StudsOffsetWorldSpace = Vector3.new(0, size.Y / 2 + 1, 0)
		gui.AlwaysOnTop = true
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 0.35
		text.TextScaled = true
		text.Text = label
		text.Parent = gui
		gui.Parent = model
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

local function sessionAlive(prep: Prep): boolean
	local session = ZoneService:GetSession(prep.player)
	return session ~= nil and session.Id == prep.sessionId
end

local function stateOf(prep: Prep?, message: string?): { [string]: any }
	if not prep then
		return { Phase = "Closed", Message = message }
	end
	local session = ZoneService:GetSession(prep.player)
	local formation = {}
	for slot, classId in prep.formation do
		table.insert(formation, { Slot = slot, ClassId = classId })
	end
	-- Positions ennemies révélées seulement une fois le combat lancé (elles sont alors visibles).
	local enemyLayout = {}
	if prep.phase == "Combat" and prep.layout then
		for cell, enemy in prep.layout do
			table.insert(enemyLayout, { Cell = cell, EnemyId = enemy.EnemyId, MiniBoss = enemy.MiniBoss })
		end
	end
	return {
		Phase = prep.phase,
		Zone = ArenaConfig.Zone,
		Stage = ArenaConfig.Stage,
		Enemies = if session then ArenaRules.summarize(session.Config) else {},
		Formation = formation,
		EnemyLayout = enemyLayout,
		MaxHeroes = ArenaConfig.MaxHeroes,
		Message = message,
	}
end

local function send(player: Player, prep: Prep?, message: string?)
	local event = stateEvent
	if event and player.Parent == Players then
		event:FireClient(player, stateOf(prep, message))
	end
end

local function cleanup(prep: Prep, message: string?)
	if current ~= prep then
		return
	end
	current = nil
	prep.folder:Destroy()
	if arena then
		arena:SetAttribute("IntroDemoBoucle", prep.loopWas)
	end
	send(prep.player, nil, message)
end

local function rebuildHeroes(prep: Prep)
	prep.heroes:ClearAllChildren()
	local facing = if front then front.Position else Vector3.zero
	for slot, classId in prep.formation do
		local pose = poses[slot]
		if pose then
			spawnModel(ArenaConfig.HeroTemplate, prep.heroes, heroFeet(pose), facing, classNames[classId])
		end
	end
end

local function fight(prep: Prep): (boolean, string?)
	if prep.phase ~= "Placement" then
		return false, "combat déjà lancé"
	end
	if ArenaRules.count(prep.formation) == 0 then
		return false, "place au moins un héros"
	end
	local session = ZoneService:GetSession(prep.player)
	local part = front
	if not session or not part then
		return false, "session ou arène indisponible"
	end
	local layout, problem = ArenaRules.randomLayout(ArenaRules.expandEnemies(session.Config), ENEMY_CELLS, Random.new())
	if not layout then
		return false, problem
	end
	local facing = average(poses)
	for cell, enemy in layout do
		local template = ArenaConfig.EnemyTemplates[enemy.EnemyId]
		local model = if template then spawnModel(template, prep.enemies, enemyFeet(part, cell), facing, nil) else nil
		if model then
			model:SetAttribute("EnemyId", enemy.EnemyId)
			model:SetAttribute("Case", cell)
		else
			Log.warn(SCOPE, `Aucun mannequin pour l'ennemi {enemy.EnemyId}`)
		end
	end
	prep.layout = layout
	prep.phase = "Combat"
	Log.info(SCOPE, `Combat de {prep.player.Name} : ennemis placés au hasard`)
	return true, nil
end

local function open(player: Player)
	local prep = current
	if prep and prep.player ~= player then
		send(player, nil, `Arène occupée par {prep.player.Name}`)
		return
	end
	if prep then
		send(player, prep, nil)
		return
	end
	local session, reason = ZoneService:StartStage(player, ArenaConfig.Zone, ArenaConfig.Stage)
	if not session or not arena then
		send(player, nil, `Impossible de lancer le stage : {reason or "arène indisponible"}`)
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = `PreparationCombat_{player.UserId}`
	local heroes = Instance.new("Folder")
	heroes.Name = "Heros"
	heroes.Parent = folder
	local enemies = Instance.new("Folder")
	enemies.Name = "Ennemis"
	enemies.Parent = folder
	folder.Parent = Workspace
	local newPrep: Prep = {
		player = player,
		sessionId = session.Id,
		phase = "Placement",
		formation = {},
		folder = folder,
		heroes = heroes,
		enemies = enemies,
		layout = nil,
		loopWas = arena:GetAttribute("IntroDemoBoucle"),
	}
	-- L'intro de démonstration en boucle réutilise les mêmes cases : on la suspend (runtime seulement).
	arena:SetAttribute("IntroDemoBoucle", false)
	current = newPrep
	send(player, newPrep, nil)
	-- Fin de session décidée ailleurs (debug, départ, perte de profil) : on range l'arène.
	task.spawn(function()
		while current == newPrep do
			task.wait(1)
			if current == newPrep and not sessionAlive(newPrep) then
				cleanup(newPrep, "Stage terminé")
			end
		end
	end)
end

local function onAction(player: Player, action: any, slot: any, classId: any): (boolean, string?)
	local prep = current
	if not prep or prep.player ~= player or not sessionAlive(prep) then
		return false, "aucune préparation en cours"
	end
	if action == "Assign" or action == "Clear" then
		if prep.phase ~= "Placement" then
			return false, "combat déjà lancé"
		end
		local ok, reason
		if action == "Assign" then
			ok, reason = ArenaRules.assign(prep.formation, slot, classId, validClasses, ArenaConfig.MaxHeroes)
		else
			ok, reason = ArenaRules.clear(prep.formation, slot)
		end
		if ok then
			rebuildHeroes(prep)
		end
		send(player, prep, reason)
		return ok, reason
	elseif action == "Fight" then
		local ok, reason = fight(prep)
		send(player, prep, reason)
		return ok, reason
	elseif action == "Leave" then
		ZoneService:CancelStage(player)
		cleanup(prep, nil)
		return true, nil
	end
	return false, "action inconnue"
end

function ArenaService:Init()
	for _, class in ArenaConfig.HeroClasses do
		validClasses[class.Id] = true
		classNames[class.Id] = class.Name
	end
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

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PreparerCombat"
	prompt.ActionText = "Préparer le combat"
	prompt.ObjectText = `Stage {ArenaConfig.Zone}-{ArenaConfig.Stage}`
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 45
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(open)
	prompt.Parent = marker

	-- Prototype, Studio uniquement : apparaître directement à côté de l'arène de test.
	local spawnPath = ArenaConfig.TestSpawn
	local spawnMarker = if spawnPath and RunService:IsStudio() then resolve(Workspace, spawnPath) else nil
	if spawnMarker and spawnMarker:IsA("BasePart") then
		local marker: BasePart = spawnMarker
		local function onCharacter(character: Model)
			task.delay(TEST_SPAWN_DELAY, function()
				if character.Parent and character:FindFirstChild("HumanoidRootPart") then
					character:PivotTo(CFrame.new(marker.Position + Vector3.new(0, marker.Size.Y / 2 + 3, 0)))
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

	Players.PlayerRemoving:Connect(function(player: Player)
		local prep = current
		if prep and prep.player == player then
			cleanup(prep, nil)
		end
	end)
end

return ArenaService
