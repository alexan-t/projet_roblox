--!strict
-- Mise en scène du combat, côté client (voir docs/COMBAT_PRESENTATION.md). Le combat devient une petite scène :
--   « Lancer » (pancarte) ou F dans l'arène → Ready (le serveur revérifie tout) → le moteur est retenu le temps
--   que la 1re vague sorte du décor de SON plot (Slime : la mare ; Gobelin : le camp ; boss : la rampe du camp)
--   jusqu'à ses cases → le combat démarre tout seul.
--   Vagues suivantes et boss : même entrée, pendant la retenue EntranceHold du serveur.
--   Chaque ennemi entre sous la forme d'une copie locale ; à l'arrivée, le modèle du combat (caché jusque-là)
--   la remplace dans la même image : aucun pop.
--   Fin : mort complète du dernier ennemi, sac de récompenses (visuel) près du corps, respiration,
--   « VICTOIRE ! », puis l'écran de fin (ArenaStore.outroFinished). Les modèles du combat restent visibles
--   pendant tout ce temps (CombatConfig.Presentation.EndHold, côté serveur).
-- Les modèles de combat restent ceux du serveur ; ce contrôleur ne fait que des copies locales et des
-- masquages locaux (LocalTransparencyModifier, attribut local « Intro »). Aucune autorité de jeu.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ArenaConfig = require(ReplicatedStorage.Shared.Config.ArenaConfig)
local Config = require(ReplicatedStorage.Shared.Config.EnemyPresentationConfig)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local ArenaStore = require(script.Parent.Parent.Arena.ArenaStore)
local PlotView = require(script.Parent.Parent.Arena.PlotView)
local BossGate = require(script.Parent.Parent.Combat.BossGate)
local OutroGate = require(script.Parent.Parent.Combat.OutroGate)
local RewardBagGuard = require(script.Parent.Parent.Combat.RewardBagGuard)
local ScreenState = require(script.Parent.Parent.UI.ScreenState)
local UIKit = require(script.Parent.Parent.UI.UIKit)
local AudioController = require(script.Parent.AudioController)
local EnemyPresentationController = require(script.Parent.EnemyPresentationController)
local MonsterAnimationController = require(script.Parent.MonsterAnimationController)

local CombatPresentationController = {}

local TAG_CASE = "CaseHeros"
local MODEL_WAIT = 3 -- s max pour voir arriver le modèle d'une unité (réplication)
local SIZE = UITheme.Typography.Size

local guard = RewardBagGuard.new()
local currentCombat: number? = nil
local lastScreen: string? = nil

------------------------------------------------------------------ arène du plot (jamais un autre plot)

type Arena = {
	sources: { BasePart },
	gate: Model?, -- porte du boss du décor de zone (Combat/BossGate), s'il en a une
	heroFeet: Vector3, -- centre de la formation des héros (où regardent les ennemis)
}

local function resolveArena(): Arena?
	local arena = PlotView.arena()
	if not arena then
		return nil
	end
	local folder: Instance? = nil
	local zones = arena:FindFirstChild("Zones")
	for _, zone in if zones then zones:GetChildren() else {} do
		local candidate = zone:FindFirstChild(Config.SourcesFolder)
		if candidate then
			folder = candidate
			break
		end
	end
	if not folder then
		return nil
	end
	local sources: { BasePart } = {}
	for _, child in folder:GetChildren() do
		if child:IsA("BasePart") and typeof(child:GetAttribute("Mode")) == "string" then
			table.insert(sources, child)
		end
	end
	table.sort(sources, function(a, b)
		return a.Name < b.Name
	end)
	local sum, count = Vector3.zero, 0
	for _, case in CollectionService:GetTagged(TAG_CASE) do
		local pose = case:IsDescendantOf(arena) and case:FindFirstChild("PointDePose", true)
		if pose and pose:IsA("BasePart") then
			sum += pose.Position - Vector3.new(0, pose.Size.Y / 2 - 0.1, 0)
			count += 1
		end
	end
	if count == 0 then
		return nil
	end
	return { sources = sources, heroFeet = sum / count, gate = BossGate.find(folder.Parent) }
end

local function sourceFeet(source: BasePart): Vector3
	return source.Position - Vector3.new(0, source.Size.Y / 2, 0)
end

-- Chemin d'entrée : repère du décor (selon le style du profil), ses étapes Etape1, Etape2..., la case.
local used: { [string]: number } = {}
local function pathFor(geometry: Arena, enemyId: string, dest: Vector3): { Vector3 }
	local profile = Config.profile(enemyId)
	local style = Config.spawnStyle(profile)
	local descriptors = {}
	for _, source in geometry.sources do
		table.insert(descriptors, { Name = source.Name, Mode = source:GetAttribute("Mode") })
	end
	local candidates = Config.sourcesFor(style, descriptors)
	if #candidates == 0 then
		return { dest, dest }
	end
	used[profile.SpawnStyle] = (used[profile.SpawnStyle] or 0) % #candidates + 1
	local source = geometry.sources[candidates[used[profile.SpawnStyle]]]
	local path = { sourceFeet(source) }
	local i = 1
	while true do
		local step = source:FindFirstChild("Etape" .. i)
		if not step or not step:IsA("BasePart") then
			break
		end
		table.insert(path, sourceFeet(step))
		i += 1
	end
	table.insert(path, dest)
	return path
end

------------------------------------------------------------------ copies d'entrée

local function introFolder(): Instance
	local name = "IntroEnnemis_" .. Players.LocalPlayer.UserId
	local existing = Workspace:FindFirstChild(name)
	if existing then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = Workspace
	return folder
end

-- Copie locale du modèle de combat d'un ennemi (même asset que ArenaService), cachée jusqu'à son entrée.
local function cloneEnemy(enemyId: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local combat = assets and assets:FindFirstChild("Combat")
	local templateName = ArenaConfig.EnemyTemplates[enemyId]
	local template = combat and templateName and combat:FindFirstChild(templateName)
	if not template or not template:IsA("Model") then
		return nil
	end
	local model = template:Clone()
	local rigged = model:FindFirstChildOfClass("AnimationController") ~= nil and model.PrimaryPart ~= nil
	for _, child in model:GetDescendants() do
		if child:IsA("BaseScript") then
			child:Destroy()
		elseif child:IsA("BasePart") then
			child.Anchored = not rigged or child == model.PrimaryPart
			child.CanCollide, child.CanTouch, child.CanQuery = false, false, false
		end
	end
	model:SetAttribute("Presentation", true)
	EnemyPresentationController.SetHidden(model, true)
	model.Parent = introFolder()
	return model
end

local function destroyIntro()
	local folder = Workspace:FindFirstChild("IntroEnnemis_" .. Players.LocalPlayer.UserId)
	if folder then
		folder:ClearAllChildren()
	end
end

local function stagger(): number
	return Random.new():NextNumber(Config.Stagger.Min, Config.Stagger.Max)
end

------------------------------------------------------------------ entrée → modèle du combat

local function findUnitModel(unitId: number): Model?
	local deadline = os.clock() + MODEL_WAIT
	while os.clock() < deadline do
		local world = PlotView.world()
		for _, model in if world then world:GetDescendants() else {} do
			if model:IsA("Model") and model:GetAttribute("UnitId") == unitId then
				return model
			end
		end
		task.wait(0.05)
	end
	return nil
end

-- Le modèle du combat prend la place de la copie, dans la même image (aucun flash).
local function swap(clone: Model?, model: Model)
	if clone and clone.Parent and model.Parent then
		clone:PivotTo(model:GetPivot())
	end
	EnemyPresentationController.SetHidden(model, false)
	model:SetAttribute("Intro", nil)
	if clone then
		clone:Destroy()
	end
	if model:FindFirstChildOfClass("AnimationController") then
		MonsterAnimationController.Play(model, "Attente")
	end
end

local function feetOf(model: Model): Vector3
	local pivot = model:GetPivot().Position
	return Vector3.new(pivot.X, pivot.Y - EnemyPresentationController.FootOffset(model), pivot.Z)
end

-- Respiration, puis entrée depuis l'origine du décor jusqu'au modèle du combat (caché), puis échange.
local function enter(unitId: number, enemyId: string, breather: number, budget: number, delay: number)
	local model = findUnitModel(unitId)
	if not model then
		return
	end
	model:SetAttribute("Intro", true) -- barres de vie cachées tant que la copie est visible (local)
	EnemyPresentationController.SetHidden(model, true)
	local geometry = resolveArena()
	local clone = cloneEnemy(enemyId)
	if not geometry or not clone then
		swap(clone, model)
		return
	end
	task.wait(breather + delay)
	local alive = function(): boolean
		return clone.Parent ~= nil and model.Parent ~= nil
	end
	-- boss : la porte de sa structure s'ouvre d'abord (forge allumée, chaînes, battants), puis il en sort
	local gate = if Config.spawnStyle(Config.profile(enemyId)).Heavy then geometry.gate else nil
	local opening = 0
	if gate then
		opening = math.min((budget - delay) * Config.Gate.Share, Config.Gate.Open)
		BossGate.open(gate, opening, alive)
	end
	EnemyPresentationController.Enter(clone, enemyId, {
		Path = pathFor(geometry, enemyId, feetOf(model)),
		LookAt = geometry.heroFeet,
		Duration = math.max(budget - delay - opening, 0.6),
		Alive = alive,
	})
	swap(clone, model)
	if gate then
		BossGate.close(gate, Config.Gate.Close)
	end
end

------------------------------------------------------------------ outro (fin de combat)

local function positionOf(unitId: number): Vector3?
	local world = PlotView.world()
	for _, model in if world then world:GetDescendants() else {} do
		if model:IsA("Model") and model:GetAttribute("UnitId") == unitId then
			return feetOf(model)
		end
	end
	return nil
end

local outroToken = 0
local bossUnits: { [number]: boolean } = {}
local lastEnemyBoss = false
local announceScreen: ScreenGui? = nil

local function waitUntil(clock: number, token: number): boolean
	while os.clock() < clock do
		if token ~= outroToken then
			return false
		end
		RunService.Heartbeat:Wait()
	end
	return token == outroToken
end

-- « VICTOIRE ! » (ou « BOSS VAINCU ! ») : texte court au-dessus du combat, pop, rayons dorés, son.
local function announceVictory(boss: boolean)
	local screen = announceScreen
	if not screen then
		local created = Instance.new("ScreenGui")
		created.Name = "AnnonceFinCombat"
		created.ResetOnSpawn = false
		created.DisplayOrder = 5
		created.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
		announceScreen = created
		screen = created
	end
	local hold = Config.Outro.VictoryHold
	local y = 150
	local rays = UIKit.rays(screen :: ScreenGui, 220, 10, UITheme.Colors.GoldLight)
	rays.AnchorPoint = Vector2.new(0.5, 0.5)
	rays.Position = UDim2.new(0.5, 0, 0, y + SIZE.Hero / 2)
	rays.ZIndex = 19
	UIKit.announce(screen :: ScreenGui, if boss then "BOSS VAINCU !" else "VICTOIRE !",
		{ Size = SIZE.Hero, Color = UITheme.Colors.Gold, Hold = hold, Y = y })
	AudioController.Play("Victoire")
	task.delay(hold + 0.6, function()
		rays:Destroy()
	end)
end

-- Outro : mort complète du dernier ennemi → sac près du corps → rebond → respiration → annonce → fin.
-- Puis ArenaStore.outroFinished : l'écran de récompenses peut s'ouvrir (ArenaPlacementController).
local function playOutro(combatId: number, victory: boolean, dropBag: boolean)
	outroToken += 1
	local token = outroToken
	local boss = lastEnemyBoss
	-- après le traitement de ce lot par CombatViewController (qui note le déroulé de la mort)
	task.defer(function()
		local death = EnemyPresentationController.LastDeath()
		local schedule = OutroGate.schedule(victory, if death then { bagAt = death.bagAt, completeAt = death.completeAt } else nil,
			os.clock(), Config.Outro)
		if victory then
			if dropBag and schedule.bagAt and death then
				if not waitUntil(schedule.bagAt, token) then
					return
				end
				local geometry = resolveArena()
				EnemyPresentationController.DropBag(death.feet, if geometry then geometry.heroFeet else nil)
			end
			if schedule.victoryAt then
				if not waitUntil(schedule.victoryAt, token) then
					return
				end
				announceVictory(boss)
			end
		end
		if waitUntil(schedule.finishAt, token) then
			ArenaStore.outroFinished:Fire(combatId, victory)
		end
	end)
end

-- Nouveau combat, Quitter, plot perdu : plus de sac, d'outro ni de copie d'entrée.
local function stopAll()
	outroToken += 1
	EnemyPresentationController.ClearBags()
	destroyIntro()
end

------------------------------------------------------------------ événements du combat

local function onCombatEvents(combatId: number, events: { { [string]: any } })
	-- Sac : exactement un par combat gagné, à la mort du dernier ennemi (garde pure).
	local bag = guard:observe(combatId, events, positionOf)
	local spawns = {}
	local hold: { [string]: any }? = nil
	for _, event in events do
		local kind = event.Type
		if kind == "CombatStarted" then
			currentCombat = combatId
			table.clear(bossUnits)
			lastEnemyBoss = false
			stopAll() -- un nouveau combat retire le sac du précédent
		elseif kind == "UnitSpawned" and event.Team == "Enemy" then
			table.insert(spawns, event)
			if event.MiniBoss == true then
				bossUnits[event.UnitId] = true
			end
		elseif kind == "UnitDied" and event.Team == "Enemy" then
			lastEnemyBoss = bossUnits[event.UnitId] == true
		elseif kind == "EntranceHold" then
			hold = event
		elseif kind == "CombatEnded" then
			playOutro(combatId, event.Result == "Victory", bag ~= nil)
		end
	end
	if combatId ~= currentCombat or #spawns == 0 then
		return
	end
	-- 1re vague, vagues suivantes, boss : même entrée, calée sur la retenue annoncée par le serveur.
	local duration = if hold and typeof(hold.Duration) == "number" then hold.Duration else 0
	local breather = if hold and typeof(hold.Breather) == "number" then hold.Breather else 0
	local budget = math.max(duration - breather - 0.15, 0.6)
	local delay = 0
	for _, event in spawns do
		task.spawn(enter, event.UnitId, event.TypeId, breather, budget, delay)
		delay = math.min(delay + stagger(), budget * 0.4)
	end
end

local function onArenaChanged()
	local state = ArenaStore.arena
	if state.Phase == "Closed" or state.Available == false then
		-- Quitter, arène fermée, plot / session perdus (l'écran de fin, s'il est ouvert, garde son sac)
		if ScreenState.current() ~= "Reward" then
			stopAll()
		end
	end
end

local function onScreenChanged()
	local current = ScreenState.current()
	if lastScreen == "Reward" and current ~= "Reward" then
		-- « Continuer » : sac retiré.
		EnemyPresentationController.ClearBags()
	end
	lastScreen = current
end

function CombatPresentationController:Start()
	ArenaStore.changed.Event:Connect(onArenaChanged)
	ScreenState.changed.Event:Connect(onScreenChanged)
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local events = remotes:WaitForChild("CombatEvent", 30)
	if events and events:IsA("RemoteEvent") then
		events.OnClientEvent:Connect(onCombatEvents)
	end
end

return CombatPresentationController
