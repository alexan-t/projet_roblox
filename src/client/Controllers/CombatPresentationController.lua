--!strict
-- Mise en scène du combat, côté client (voir docs/COMBAT_PRESENTATION.md). Le combat devient une petite scène :
--   « Lancer » (fenêtre des stages) → le joueur est (ou entre) dans SON arène → les ennemis de la première
--   vague sortent du décor de SON plot (Slime : la mare ; Gobelin : le camp ; boss : la rampe du camp) et
--   prennent position → « DÉFENDRE LA BASE · E » → Ready (le serveur revérifie stage, équipe, plot, combat
--   déjà actif) → le moteur, retenu StartHold, laisse chaque ennemi présenté rejoindre sa vraie case, puis
--   le modèle du combat le remplace dans la même image (aucun pop).
--   Vagues suivantes et boss : le serveur retient le moteur (EntranceHold) ; les nouveaux ennemis entrent
--   depuis leur origine, prennent la place de leur modèle de combat, puis le combat reprend tout seul.
--   Victoire : un sac de récompenses (visuel) tombe à la mort du dernier ennemi, retiré à « Continuer ».
-- État : PresentationFlow (pur, testé). Les modèles de combat restent ceux du serveur ; ce contrôleur ne fait
-- que des copies locales et des masquages locaux (LocalTransparencyModifier, attribut local « Intro »).

local ContextActionService = game:GetService("ContextActionService")
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
local OutroGate = require(script.Parent.Parent.Combat.OutroGate)
local PresentationFlow = require(script.Parent.Parent.Combat.PresentationFlow)
local RewardBagGuard = require(script.Parent.Parent.Combat.RewardBagGuard)
local ScreenState = require(script.Parent.Parent.UI.ScreenState)
local UIKit = require(script.Parent.Parent.UI.UIKit)
local AudioController = require(script.Parent.AudioController)
local EnemyPresentationController = require(script.Parent.EnemyPresentationController)
local MonsterAnimationController = require(script.Parent.MonsterAnimationController)

local CombatPresentationController = {}

local TAG_CASE = "CaseHeros"
local ACTION = "DefendreLaBase"
local REFRESH = 0.1 -- s entre deux vérifications (entrée dans l'arène, CTA)
local MODEL_WAIT = 3 -- s max pour voir arriver le modèle d'une unité (réplication)
local SIZE = UITheme.Typography.Size

local flow = PresentationFlow.new()
local guard = RewardBagGuard.new()

type Clone = { model: Model, enemyId: string, matched: boolean }
local introClones: { Clone } = {}
-- CTA : panneau d'une ScreenGui accroché à un point du monde (au-dessus du champ de bataille de SON arène),
-- recalé à chaque image tant qu'il est affiché. Clic, toucher et manette passent par un vrai bouton d'écran.
local cta: { gui: ScreenGui?, panel: Frame?, shown: boolean, anchor: Vector3?, follow: RBXScriptConnection? } = { shown = false }
local CTA_HEIGHT = 11 -- studs au-dessus du repère : ne cache pas les ennemis
local CTA_SAFE_TOP = 96 -- px réservés en haut (monnaies, annonces de vague)
local CTA_SAFE_BOTTOM = 200 -- px réservés en bas (hotbar, pastille de combat)
local currentCombat: number? = nil
local lastScreen: string? = nil

------------------------------------------------------------------ arène du plot (jamais un autre plot)

type Arena = {
	arena: Instance,
	front: BasePart,
	sources: { BasePart },
	heroFeet: Vector3, -- centre de la formation des héros (où regardent les ennemis)
	center: Vector3,
	radius: number,
	banner: BasePart?,
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
	local front = folder and folder:FindFirstChild(Config.FrontName)
	if not folder or not front or not front:IsA("BasePart") then
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
	local sum, count, poses = Vector3.zero, 0, {}
	for _, case in CollectionService:GetTagged(TAG_CASE) do
		local pose = case:IsDescendantOf(arena) and case:FindFirstChild("PointDePose", true)
		if pose and pose:IsA("BasePart") then
			local feet = pose.Position - Vector3.new(0, pose.Size.Y / 2 - 0.1, 0)
			sum += feet
			count += 1
			table.insert(poses, feet)
		end
	end
	if count == 0 then
		return nil
	end
	local center = sum / count
	local radius = 0
	for _, feet in poses do
		radius = math.max(radius, ((feet - center) * Vector3.new(1, 0, 1)).Magnitude)
	end
	local emplacements = arena:FindFirstChild("Emplacements")
	local banner = emplacements and emplacements:FindFirstChild("PointEtendard")
	return {
		arena = arena,
		front = front,
		sources = sources,
		heroFeet = center,
		center = center,
		radius = radius + ArenaConfig.ZoneMargin, -- même zone de préparation que le serveur
		banner = if banner and banner:IsA("BasePart") then banner else nil,
	}
end

local function inArena(geometry: Arena?): boolean
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not geometry or not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
		return false
	end
	return ((root.Position - geometry.center) * Vector3.new(1, 0, 1)).Magnitude <= geometry.radius
end

-- Pieds d'une case ennemie (même grille 3x3 que ArenaService.startCombat).
local function cellFeet(front: BasePart, cell: number): Vector3
	local offset = Vector3.new(((cell - 1) % 3 - 1) * front.Size.X / 3, -front.Size.Y / 2 + 0.1, (1 - (cell - 1) // 3) * front.Size.Z / 3)
	return front.CFrame:PointToWorldSpace(offset)
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
		return { dest + Vector3.new(0, 0, 0), dest }
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

------------------------------------------------------------------ copies de présentation

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
	for _, clone in introClones do
		clone.model:Destroy()
	end
	table.clear(introClones)
	local folder = Workspace:FindFirstChild("IntroEnnemis_" .. Players.LocalPlayer.UserId)
	if folder then
		folder:ClearAllChildren()
	end
end

local function stagger(): number
	return Random.new():NextNumber(Config.Stagger.Min, Config.Stagger.Max)
end

------------------------------------------------------------------ CTA « Défendre la base »

local function sync()
	ArenaStore.presentation = flow.state
end

local function hideCta()
	if cta.shown then
		cta.shown = false
		ContextActionService:UnbindAction(ACTION)
	end
	if cta.follow then
		cta.follow:Disconnect()
		cta.follow = nil
	end
	if cta.gui then
		cta.gui.Enabled = false
	end
end

local function defend()
	local geometry = resolveArena()
	if not flow:defend(inArena(geometry), ArenaStore.placedCount()) then
		return
	end
	hideCta() -- disparaît immédiatement au lancement
	local ok = ArenaStore.request("Ready") -- le serveur revérifie tout ; un refus remet le CTA
	flow:defendResult(ok)
	sync()
	ArenaStore.notify()
end

local stopOutro: () -> ()
local function cancelLocal()
	if stopOutro then
		stopOutro()
	end
	if flow:cancel() then
		destroyIntro()
		hideCta()
		sync()
		ArenaStore.notify()
	end
end

local function buildCta()
	local gui = Instance.new("ScreenGui")
	gui.Name = "DefendreLaBase"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true -- positions en pixels de la vue (WorldToViewportPoint)
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false
	local panel = UIKit.panel(gui, UITheme.Transparency.HUD, UITheme.Radius.Large, UITheme.Stroke.Regular)
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Size = UDim2.fromOffset(320, 128)
	local title = UIKit.text(panel, "DÉFENDRE LA BASE", SIZE.Heading, UITheme.Colors.Gold)
	title.Position = UDim2.fromOffset(0, UITheme.Spacing.M)
	title.Size = UDim2.new(1, 0, 0, SIZE.Heading + 6)
	local lip = UITheme.Shadow.ButtonLip
	local button = UIKit.button(panel, "E · Défendre", "Primary", UDim2.fromOffset(196, UITheme.Spacing.TouchTarget + lip), defend)
	button.holder.AnchorPoint = Vector2.new(0.5, 1)
	button.holder.Position = UDim2.new(0.5, 0, 1, -UITheme.Spacing.M)
	button.label.TextSize = SIZE.Button
	-- Annuler la défense (garde l'équipe) : les ennemis présentés repartent, la pancarte revient.
	local close = UIKit.button(panel, "X", "Danger", UDim2.fromOffset(36, 36 + lip), cancelLocal)
	close.holder.AnchorPoint = Vector2.new(1, 0)
	close.holder.Position = UDim2.new(1, -UITheme.Spacing.S, 0, UITheme.Spacing.S)
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	cta.gui, cta.panel = gui, panel
end

local function showCta(geometry: Arena)
	local gui = cta.gui
	if not gui or cta.shown then
		return
	end
	cta.shown = true
	local point = geometry.banner or geometry.front
	cta.anchor = point.Position + Vector3.new(0, CTA_HEIGHT, 0)
	local function follow()
		local camera = Workspace.CurrentCamera
		local panel, anchor = cta.panel, cta.anchor
		if not camera or not panel or not anchor then
			return
		end
		local screen, visible = camera:WorldToViewportPoint(anchor)
		local near = (camera.CFrame.Position - anchor).Magnitude <= UITheme.World.CombatDistance
		panel.Visible = visible and near
		-- reste lisible : jamais sur le HUD des monnaies (haut) ni hors de l'écran
		local view = camera.ViewportSize
		local half = panel.AbsoluteSize.X / 2
		local x = math.clamp(screen.X, half + UITheme.Spacing.M, math.max(view.X - half - UITheme.Spacing.M, half))
		local y = math.clamp(screen.Y, CTA_SAFE_TOP + panel.AbsoluteSize.Y, math.max(view.Y - CTA_SAFE_BOTTOM, CTA_SAFE_TOP + panel.AbsoluteSize.Y))
		panel.Position = UDim2.fromOffset(x, y)
	end
	follow()
	cta.follow = RunService.RenderStepped:Connect(follow)
	gui.Enabled = true
	if cta.panel then
		UIKit.popIn(cta.panel) -- apparition légère, petit pulse une fois
	end
	-- E (clavier) et X (manette) déclenchent exactement la même action que le bouton (clic / toucher).
	ContextActionService:BindActionAtPriority(ACTION, function(_name, state)
		if state == Enum.UserInputState.Begin then
			task.spawn(defend)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.E, Enum.KeyCode.ButtonX)
end

------------------------------------------------------------------ intro (avant Prêt)

local function playIntro(generation: number)
	local geometry = resolveArena()
	if not geometry then
		flow:cancel()
		sync()
		return
	end
	destroyIntro()
	table.clear(used)
	local alive = function(): boolean
		return flow:current(generation)
	end
	local entries = {}
	for _, group in ArenaStore.arena.FirstWave or {} do
		for _ = 1, group.Count do
			table.insert(entries, group.EnemyId)
		end
	end
	local pending = 0
	for index, enemyId in entries do
		local cell = Config.IntroCells[(index - 1) % #Config.IntroCells + 1]
		local model = cloneEnemy(enemyId)
		if model then
			table.insert(introClones, { model = model, enemyId = enemyId, matched = false })
			local dest = cellFeet(geometry.front, cell)
			local path = pathFor(geometry, enemyId, dest)
			pending += 1
			task.spawn(function()
				EnemyPresentationController.Enter(model, enemyId, {
					Path = path,
					LookAt = geometry.heroFeet,
					Duration = Config.IntroDuration,
					Alive = function(): boolean
						return alive() and model.Parent ~= nil
					end,
				})
				pending -= 1
			end)
			task.wait(stagger())
			if not alive() then
				return
			end
		end
	end
	while pending > 0 and alive() do
		RunService.Heartbeat:Wait()
	end
	if alive() and flow:introDone(generation) then
		sync()
		ArenaStore.notify()
	end
end

------------------------------------------------------------------ remplacement par les modèles du combat

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

-- Le modèle du combat prend la place de la copie présentée, dans la même image (aucun flash).
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

-- Vague 1 : la copie présentée la plus proche (même ennemi) rejoint la vraie case, puis échange.
local function regroup(unitId: number, enemyId: string, duration: number)
	local model = findUnitModel(unitId)
	if not model then
		return
	end
	model:SetAttribute("Intro", true) -- barres de vie cachées tant que la copie est visible (local)
	EnemyPresentationController.SetHidden(model, true)
	local best: Clone? = nil
	local bestDistance = math.huge
	for _, clone in introClones do
		if not clone.matched and clone.enemyId == enemyId and clone.model.Parent then
			local d = (clone.model:GetPivot().Position - model:GetPivot().Position).Magnitude
			if d < bestDistance then
				best, bestDistance = clone, d
			end
		end
	end
	if not best then
		swap(nil, model)
		return
	end
	best.matched = true
	local clone = best.model
	local geometry = resolveArena()
	EnemyPresentationController.Move(clone, enemyId, feetOf(model),
		if geometry then geometry.heroFeet else model:GetPivot().Position + model:GetPivot().LookVector,
		math.max(duration * 0.85, 0.3), function(): boolean
			return clone.Parent ~= nil and model.Parent ~= nil
		end)
	swap(clone, model)
end

-- Vagues suivantes / boss : respiration, entrée depuis l'origine du décor jusqu'au modèle du combat.
local function enterWave(unitId: number, enemyId: string, breather: number, budget: number, delay: number)
	local model = findUnitModel(unitId)
	if not model then
		return
	end
	model:SetAttribute("Intro", true)
	EnemyPresentationController.SetHidden(model, true)
	local geometry = resolveArena()
	local clone = cloneEnemy(enemyId)
	if not geometry or not clone then
		swap(clone, model)
		return
	end
	task.wait(breather + delay)
	EnemyPresentationController.Enter(clone, enemyId, {
		Path = pathFor(geometry, enemyId, feetOf(model)),
		LookAt = geometry.heroFeet,
		Duration = math.max(budget - delay, 0.6),
		Alive = function(): boolean
			return clone.Parent ~= nil and model.Parent ~= nil
		end,
	})
	swap(clone, model)
end

------------------------------------------------------------------ événements du combat

local function positionOf(unitId: number): Vector3?
	local world = PlotView.world()
	for _, model in if world then world:GetDescendants() else {} do
		if model:IsA("Model") and model:GetAttribute("UnitId") == unitId then
			return feetOf(model)
		end
	end
	return nil
end

local freshWave = false

------------------------------------------------------------------ outro (fin de combat)

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

function stopOutro()
	outroToken += 1
	EnemyPresentationController.ClearBags()
end

local function onCombatEvents(combatId: number, events: { { [string]: any } })
	-- Sac : exactement un par combat gagné, à la mort du dernier ennemi (garde pure).
	local bag = guard:observe(combatId, events, positionOf)
	local spawns = {}
	local hold: { [string]: any }? = nil
	for _, event in events do
		local kind = event.Type
		if kind == "CombatStarted" then
			currentCombat = combatId
			freshWave = false
			table.clear(bossUnits)
			lastEnemyBoss = false
			stopOutro() -- un nouveau combat retire le sac du précédent
			flow:combatStarted()
			hideCta()
			sync()
		elseif kind == "WaveStarted" then
			freshWave = (event.Wave or 1) > 1
		elseif kind == "MiniBossStarted" then
			freshWave = true
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
			flow:combatEnded()
			sync()
			playOutro(combatId, event.Result == "Victory", bag ~= nil)
		end
	end
	if combatId ~= currentCombat or #spawns == 0 then
		return
	end
	local duration = if hold then hold.Duration else 0.6
	if freshWave then
		local breather = if hold and typeof(hold.Breather) == "number" then hold.Breather else 0.5
		local budget = math.max(duration - breather - 0.15, 0.6)
		local delay = 0
		for _, event in spawns do
			task.spawn(enterWave, event.UnitId, event.TypeId, breather, budget, delay)
			delay += stagger()
		end
	else
		for _, event in spawns do
			task.spawn(regroup, event.UnitId, event.TypeId, duration)
		end
		-- copies non utilisées (ne devrait pas arriver) : retirées après le remplacement
		task.delay(duration + 0.5, function()
			for i = #introClones, 1, -1 do
				if not introClones[i].matched then
					introClones[i].model:Destroy()
					table.remove(introClones, i)
				end
			end
		end)
	end
	freshWave = false
end

------------------------------------------------------------------ boucle

local function stageKey(): string
	local state = ArenaStore.arena
	return `{state.Zone or "?"}-{state.Stage or "?"}`
end

local function onArenaChanged()
	local state = ArenaStore.arena
	if state.Phase == "Combat" then
		if flow.state ~= "Combat" and flow.state ~= "Reward" then
			flow:combatStarted()
			hideCta()
		end
	elseif state.Phase == "Closed" or state.Available == false then
		if flow.state ~= "Idle" and flow.state ~= "Reward" then
			cancelLocal()
		end
		if state.Available == false then
			stopOutro() -- plot / session perdus : plus de sac ni d'outro
		end
	elseif flow:stageChanged(stageKey()) then
		destroyIntro()
		hideCta()
	end
	sync()
end

local function onArm()
	if ArenaStore.placedCount() < 1 then
		return
	end
	if flow:arm(stageKey()) then
		destroyIntro()
		hideCta()
		sync()
		if not inArena(resolveArena()) then
			ArenaStore.toast:Fire("Entre dans ton arène pour défendre la base")
		end
		ArenaStore.notify()
	end
end

local function onScreenChanged()
	local current = ScreenState.current()
	if lastScreen == "Reward" and current ~= "Reward" then
		-- « Continuer » : sac retiré, la défense suivante se relance depuis la pancarte.
		EnemyPresentationController.ClearBags()
		flow:rewardClosed()
		destroyIntro()
		sync()
		ArenaStore.notify()
	end
	lastScreen = current
end

local function step()
	local geometry = resolveArena()
	local here = inArena(geometry)
	if flow.state == "WaitingForArenaEntry" and here and geometry then
		local generation = flow:enterArena()
		if generation then
			sync()
			ArenaStore.notify()
			task.spawn(playIntro, generation)
		end
	end
	if geometry and flow:canDefend(here, ArenaStore.placedCount()) then
		showCta(geometry)
	elseif cta.shown then
		hideCta()
	end
end

function CombatPresentationController:Start()
	buildCta()
	ArenaStore.defend.Event:Connect(onArm)
	-- Studio seulement (tests MCP, où la pancarte E n'est pas affichée) : l'attribut local StudioLancer du
	-- joueur arme la défense comme « Lancer ». Inactif en jeu publié ; le serveur revérifie Ready.
	if RunService:IsStudio() then
		Players.LocalPlayer:GetAttributeChangedSignal("StudioLancer"):Connect(onArm)
	end
	ArenaStore.changed.Event:Connect(onArenaChanged)
	ScreenState.changed.Event:Connect(onScreenChanged)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed >= REFRESH then
			elapsed = 0
			step()
		end
	end)
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local events = remotes:WaitForChild("CombatEvent", 30)
	if events and events:IsA("RemoteEvent") then
		events.OnClientEvent:Connect(onCombatEvents)
	end
end

return CombatPresentationController
