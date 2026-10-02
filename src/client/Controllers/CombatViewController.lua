--!strict
-- Informations de combat dans le monde, côté client (voir docs/COMBAT.md) : consomme Remotes.CombatEvent.
--   • Au-dessus de chaque unité : barre de PV (rouge sous 30 %), barre de mana pour les héros
--     (dorée et pulsante quand l'ultime est prêt, avec un léger contour sur le héros). Barre plus
--     large pour le mini-boss. Petite icône de classe au-dessus des héros, sans nom.
--   • Dégâts (DamageFeedbackController), à l'instant du coup : flash et petit recul de la cible, chiffre
--     au design system (clair sur un ennemi, doré pour un ultime, rouge sur un héros), traînée sur la barre.
--   • Mort : les barres disparaissent, puis l'unité se dissout (DefeatEffectController) ; pas
--     d'animation de douleur (« Touche ») ni de mort à jouer pour l'instant.
--   • Ultime : toucher / cliquer un héros dont la mana est pleine (le serveur vérifie tout). Le héros
--     joue « Ultime » et une onde dorée file vers la zone touchée (UltimateEffectController) ; chiffres
--     et disparitions des ennemis touchés attendent l'impact de l'onde. Un bouton « Ultime » doré apparaît
--     aussi au-dessus du héros prêt (zone tactile ≥ 44 px), pour qui ne pense pas à toucher le héros.
-- Présentation (issue #19) : barres, icônes de classe 3D (Icons) et bouton au design system, valeurs
-- de UITheme. Démonstration Studio : tag "ApercuBarres" sur un modèle (attributs Equipe = "Allie" ou
-- "Ennemi", Classe = id de classe) : barres, mana qui se remplit, bouton Ultime cliquable.
-- Aucune règle de combat ici : PV, mana, morts et résultat viennent uniquement du serveur.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local AttackEffectController = require(script.Parent.AttackEffectController)
local DamageFeedbackController = require(script.Parent.DamageFeedbackController)
local DefeatEffectController = require(script.Parent.DefeatEffectController)
local MonsterAnimationController = require(script.Parent.MonsterAnimationController)
local UltimateEffectController = require(script.Parent.UltimateEffectController)
local Icons = require(script.Parent.Parent.UI.Icons)
local UIKit = require(script.Parent.Parent.UI.UIKit)

local CombatViewController = {}

local RETRY_DELAY = 0.2
local RETRIES = 10
local LOW_HEALTH = 0.3
local TAP_RADIUS = 70 -- pixels autour d'un héros pour lancer son ultime
local TAG_APERCU = "ApercuBarres"
local Colors = UITheme.Colors
local HEALTH = Colors.Health
local HEALTH_LOW = Colors.HealthLow
local ENEMY_HEALTH = Colors.EnemyHealth
local MANA = Colors.Energy
local MANA_FULL = Colors.EnergyFull

type View = {
	id: number,
	team: string,
	health: number,
	maxHealth: number,
	energy: number,
	maxEnergy: number,
	model: Model?,
	gui: BillboardGui?,
	healthFill: Frame?,
	manaFill: Frame?,
	glow: Highlight?,
	pulse: Tween?,
	ultimate: BillboardGui?,
}

local views: { [number]: View } = {}
local combatAction: RemoteFunction? = nil
local active = false
-- Vitesse du combat (SpeedChanged : 1 ou 2). x2 accélère la simulation : les animations, les
-- instants d'impact et les effets suivent, sinon tout serait en retard sur le coup.
local speed = 1

local function folder(): Instance?
	return Workspace:FindFirstChild(`PreparationCombat_{Players.LocalPlayer.UserId}`)
end

local function findModel(unitId: number): Model?
	local root = folder()
	if not root then
		return nil
	end
	for _, model in root:GetDescendants() do
		if model:IsA("Model") and model:GetAttribute("UnitId") == unitId then
			return model
		end
	end
	return nil
end

local function top(model: Model): number
	local _, size = model:GetBoundingBox()
	return size.Y / 2
end

-- Petite icône de classe au-dessus d'un héros (placement comme combat) : objet 3D dans une pastille
-- crème contourée Ink (Icons), pas d'emoji.
local function attachIcon(model: Model, classId: string?)
	local class = classId or model:GetAttribute("HeroClass")
	if typeof(class) ~= "string" or model:FindFirstChild("IconeClasse") then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "IconeClasse"
	gui.Size = UDim2.fromOffset(26, 26)
	gui.StudsOffsetWorldSpace = Vector3.new(0, top(model) + 1.7, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 150
	local chip = Instance.new("Frame")
	chip.Size = UDim2.fromScale(1, 1)
	chip.BackgroundColor3 = Colors.Cream
	chip.Parent = gui
	UIKit.corner(chip, UITheme.Radius.Pill)
	UIKit.stroke(chip, UITheme.Stroke.Thin)
	Icons.viewport(chip, class)
	gui.Parent = model
end

-- Bouton « Ultime » au-dessus d'un héros prêt : bouton doré chunky qui pulse doucement. Placé dans
-- PlayerGui (un BillboardGui du Workspace ne reçoit pas les clics), attaché au modèle par Adornee.
local useUltimate: (unitId: number) -> ()

local function setUltimateButton(view: View, ready: boolean)
	local model = view.model
	if ready and not view.ultimate and model and model.Parent then
		local gui = Instance.new("BillboardGui")
		gui.Name = "BoutonUltime"
		gui.Adornee = model
		gui.Size = UDim2.fromOffset(104, 52)
		gui.StudsOffsetWorldSpace = Vector3.new(0, top(model) + 3.4, 0)
		gui.AlwaysOnTop = true
		gui.Active = true
		gui.MaxDistance = 150
		gui.ResetOnSpawn = false
		local button = UIKit.button(gui, {
			Text = "Ultime",
			Style = "Primary",
			Size = Vector2.new(100, 44),
			OnClick = function()
				useUltimate(view.id)
			end,
		})
		button.Holder.AnchorPoint = Vector2.new(0.5, 0)
		button.Holder.Position = UDim2.fromScale(0.5, 0)
		UIKit.popIn(button.Holder)
		local pulse = Instance.new("UIScale")
		pulse.Parent = button.Face
		local tween = TweenService:Create(pulse, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = UITheme.Animation.Scale.Hover })
		tween:Play()
		gui.Destroying:Connect(function()
			tween:Cancel()
		end)
		gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
		view.ultimate = gui
	elseif not ready and view.ultimate then
		view.ultimate:Destroy()
		view.ultimate = nil
	end
end

local function refresh(view: View)
	local healthFill, manaFill = view.healthFill, view.manaFill
	if healthFill then
		local ratio = math.clamp(view.health / view.maxHealth, 0, 1)
		healthFill.Size = UDim2.fromScale(ratio, 1)
		healthFill.BackgroundColor3 = if view.team == "Enemy" then ENEMY_HEALTH elseif ratio <= LOW_HEALTH then HEALTH_LOW else HEALTH
	end
	if manaFill and view.maxEnergy > 0 then
		local full = view.energy >= view.maxEnergy
		manaFill.Size = UDim2.fromScale(math.clamp(view.energy / view.maxEnergy, 0, 1), 1)
		manaFill.BackgroundColor3 = if full then MANA_FULL else MANA
		if full and not view.pulse then
			view.pulse = TweenService:Create(manaFill, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { BackgroundTransparency = 0.45 })
			view.pulse:Play()
		elseif not full and view.pulse then
			view.pulse:Cancel()
			view.pulse = nil
			manaFill.BackgroundTransparency = 0
		end
		local glow = view.glow
		if glow then
			glow.Enabled = full
		end
		setUltimateButton(view, full and view.team == "Ally" and view.health > 0)
	end
end

-- Barre du design system : fond BarTrack à Track, contour Thin, rayon Pill, remplissage opaque.
local function bar(parent: Instance, y: number, height: number, color: Color3): Frame
	local b = UIKit.bar(parent, { Color = color, Size = UDim2.new(1, -4, 0, height) })
	b.Frame.Position = UDim2.fromOffset(2, y + 2)
	return b.Fill
end

local function attachBars(unitId: number, miniBoss: boolean, attempt: number)
	local view = views[unitId]
	if not view then
		return
	end
	local model = findModel(unitId)
	if not model then
		if attempt < RETRIES then
			task.delay(RETRY_DELAY, attachBars, unitId, miniBoss, attempt + 1)
		end
		return
	end
	view.model = model
	local hero = view.team == "Ally"
	local width = if miniBoss then 120 else 64
	local healthHeight = if miniBoss then 10 else 7
	local gui = Instance.new("BillboardGui")
	gui.Name = "BarresCombat"
	gui.Size = UDim2.fromOffset(width, healthHeight + (if hero then 7 else 0) + 4)
	gui.StudsOffsetWorldSpace = Vector3.new(0, top(model) + 0.5, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 150
	view.healthFill = bar(gui, 0, healthHeight, if hero then HEALTH else ENEMY_HEALTH)
	if hero and view.maxEnergy > 0 then
		view.manaFill = bar(gui, healthHeight + 2, 5, MANA)
		local glow = Instance.new("Highlight")
		glow.FillTransparency = 1
		glow.OutlineColor = MANA_FULL
		glow.OutlineTransparency = 0.35
		glow.DepthMode = Enum.HighlightDepthMode.Occluded
		glow.Enabled = false
		glow.Parent = model
		view.glow = glow
	end
	gui.Parent = model
	view.gui = gui
	attachIcon(model)
	refresh(view)
end

local function animate(unitId: number?, name: string)
	local view = if unitId then views[unitId] else nil
	local model = if view then view.model else nil
	if model and model:GetAttribute("JeuAnimations") ~= nil then
		MonsterAnimationController.Play(model, name)
	end
end

local function onEvents(_combatId: number, events: { { [string]: any } })
	local ultimateHits: { [number]: boolean } = {}
	-- Délai jusqu'au coup visible pour chaque cible frappée dans ce lot (ultime ou attaque dont
	-- l'animation a un instant d'impact) : chiffres et disparition attendent le coup.
	local hitDelay: { [number]: number } = {}
	for _, event in events do
		local kind = event.Type
		if kind == "SpeedChanged" then
			speed = if event.Speed == 2 then 2 else 1
			MonsterAnimationController.SetTimeScale(speed)
		elseif kind == "CombatStarted" then
			table.clear(views)
			active = true
		elseif kind == "UnitSpawned" then
			views[event.UnitId] = {
				id = event.UnitId,
				team = event.Team,
				health = event.Health,
				maxHealth = event.MaxHealth,
				energy = event.Energy,
				maxEnergy = event.MaxEnergy,
			}
			attachBars(event.UnitId, event.MiniBoss == true, 0)
		elseif kind == "UltimateUsed" then
			for _, id in event.Hits do
				ultimateHits[id] = true
				hitDelay[id] = UltimateEffectController.ImpactDelay(speed)
			end
			-- Animation « Ultime » du héros et onde dorée jusqu'au centre de la zone touchée
			-- (anneau au rayon des ennemis touchés, au moins celui d'une petite zone).
			local caster = views[event.UnitId]
			local target = views[event.TargetId]
			if caster and caster.model and target and target.model then
				local box, size = target.model:GetBoundingBox()
				local center = Vector3.new(box.Position.X, box.Position.Y - size.Y / 2, box.Position.Z)
				local radius = 4
				for _, id in event.Hits do
					local hit = views[id]
					if hit and hit.model then
						local p = hit.model:GetPivot().Position
						radius = math.max(radius, Vector3.new(p.X - center.X, 0, p.Z - center.Z).Magnitude + 2)
					end
				end
				UltimateEffectController.Play(caster.model, center, radius, speed)
			end
			animate(event.UnitId, "Ultime")
		elseif kind == "Damage" then
			local view = views[event.TargetId]
			if view then
				-- Tout tombe avec le coup visible (impact de l'attaque, anneau de l'ultime), pas avant :
				-- barre de vie (avec traînée), flash, recul et chiffre (DamageFeedbackController).
				local delay = hitDelay[event.TargetId] or 0
				local source = views[event.SourceId]
				local from = if source and source.model then source.model:GetPivot().Position else nil
				local ultimate = ultimateHits[event.TargetId] == true
				local health, amount = event.Health, event.Amount
				local function land()
					local before = math.clamp(view.health / view.maxHealth, 0, 1)
					view.health = health
					refresh(view)
					if view.healthFill then
						DamageFeedbackController.Chip(view.healthFill, before, math.clamp(health / view.maxHealth, 0, 1), speed)
					end
					if view.model then
						DamageFeedbackController.Hit(view.model, {
							Amount = amount,
							Ally = view.team == "Ally",
							Ultimate = ultimate,
							Lethal = health <= 0,
							From = from,
							Speed = speed,
						})
					end
				end
				if delay > 0 then
					task.delay(delay, land)
				else
					land()
				end
			end
			animate(event.TargetId, "Touche")
		elseif kind == "EnergyChanged" then
			local view = views[event.UnitId]
			if view then
				view.energy = event.Energy
				refresh(view)
			end
		elseif kind == "Attack" then
			local attacker = views[event.UnitId]
			if attacker and attacker.model and event.TargetId then
				-- Effet d'impact éventuel (attribut EffetAttaque) ; renvoie l'instant du coup.
				local impact = AttackEffectController.Play(attacker.model, speed)
				if impact > 0 and not hitDelay[event.TargetId] then
					hitDelay[event.TargetId] = impact
				end
			end
			-- À portée, l'unité ne bouge plus : la marche (bouclée) s'arrête.
			local walker = views[event.UnitId]
			if walker and walker.model then
				MonsterAnimationController.Stop(walker.model, "Marche")
			end
			animate(event.UnitId, "Attaque")
		elseif kind == "MoveStarted" then
			animate(event.UnitId, "Marche")
		elseif kind == "UnitDied" then
			local view = views[event.UnitId]
			if view then
				-- Les barres disparaissent d'abord, puis l'animation de mort.
				if view.pulse then
					view.pulse:Cancel()
				end
				if view.gui then
					view.gui:Destroy()
				end
				if view.glow then
					view.glow:Destroy()
				end
				setUltimateButton(view, false)
				local icon = view.model and view.model:FindFirstChild("IconeClasse")
				if icon then
					icon:Destroy()
				end
				if view.model then
					MonsterAnimationController.Stop(view.model, "Marche")
					-- Disparaît quand le coup l'atteint (onde de l'ultime, impact de l'attaque).
					DefeatEffectController.Play(view.model, hitDelay[event.UnitId] or 0, speed)
				end
			end
			animate(event.UnitId, "Mort")
			views[event.UnitId] = nil
		elseif kind == "CombatEnded" then
			active = false
			for _, view in views do
				setUltimateButton(view, false)
			end
		end
	end
end

-- Démonstration Studio : unités factices (identifiants négatifs) ; l'ultime y est simulé.
local demoUse: { [number]: () -> () } = {}

useUltimate = function(unitId: number)
	local simulated = demoUse[unitId]
	if simulated then
		simulated()
		return
	end
	local remote = combatAction
	if remote then
		remote:InvokeServer("UseUltimate", unitId)
	end
end

-- Toucher un héros dont la mana est pleine : demande d'ultime (validée par le serveur).
local function onTap(input: InputObject, processed: boolean)
	if not active or processed then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	local camera = Workspace.CurrentCamera
	local remote = combatAction
	if not camera or not remote then
		return
	end
	local tap = Vector2.new(input.Position.X, input.Position.Y)
	local ready: { [Model]: number } = {}
	local models: { Instance } = {}
	for unitId, view in views do
		local model = view.model
		if view.team == "Ally" and model and model.Parent and view.maxEnergy > 0 and view.energy >= view.maxEnergy then
			ready[model] = unitId
			table.insert(models, model)
		end
	end
	if #models == 0 then
		return
	end
	-- D'abord le héros réellement touché (son corps), sinon le plus proche du doigt.
	local best: number? = nil
	local ray = camera:ScreenPointToRay(tap.X, tap.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = models
	local hit = Workspace:Raycast(ray.Origin, ray.Direction * 500, params)
	if hit then
		local model = hit.Instance:FindFirstAncestorOfClass("Model")
		while model and not ready[model] do
			model = model:FindFirstAncestorOfClass("Model")
		end
		best = if model then ready[model] else nil
	end
	if not best then
		local bestDistance = TAP_RADIUS
		for model, unitId in ready do
			local point, visible = camera:WorldToScreenPoint(model:GetPivot().Position)
			local d = (Vector2.new(point.X, point.Y) - tap).Magnitude
			if visible and d < bestDistance then
				best, bestDistance = unitId, d
			end
		end
	end
	if best then
		useUltimate(best)
	end
end

local function watchFolder(root: Instance)
	for _, model in root:GetDescendants() do
		if model:IsA("Model") then
			attachIcon(model)
		end
	end
	root.DescendantAdded:Connect(function(model: Instance)
		if model:IsA("Model") then
			attachIcon(model)
		end
	end)
end

local demoCount = 0

local function runDemo(model: Instance)
	if not model:IsA("Model") then
		return
	end
	demoCount += 1
	local id = -demoCount
	local hero = model:GetAttribute("Equipe") ~= "Ennemi"
	local view: View = { id = id, team = if hero then "Ally" else "Enemy", health = 100, maxHealth = 100, energy = 0, maxEnergy = if hero then 100 else 0, model = model }
	views[id] = view
	local gui = Instance.new("BillboardGui")
	gui.Name = "BarresCombat"
	gui.Size = UDim2.fromOffset(64, 7 + (if hero then 7 else 0) + 4)
	gui.StudsOffsetWorldSpace = Vector3.new(0, top(model) + 0.5, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 150
	view.healthFill = bar(gui, 0, 7, if hero then HEALTH else ENEMY_HEALTH)
	if hero then
		view.manaFill = bar(gui, 9, 5, MANA)
		local glow = Instance.new("Highlight")
		glow.FillTransparency = 1
		glow.OutlineColor = MANA_FULL
		glow.OutlineTransparency = 0.35
		glow.DepthMode = Enum.HighlightDepthMode.Occluded
		glow.Enabled = false
		glow.Parent = model
		view.glow = glow
		local class = model:GetAttribute("Classe")
		attachIcon(model, if typeof(class) == "string" then class else "Paladin")
	end
	gui.Parent = model
	view.gui = gui
	local used = false
	demoUse[id] = function()
		used = true
	end
	refresh(view)
	while model.Parent and CollectionService:HasTag(model, TAG_APERCU) do
		task.wait(0.7)
		if hero then
			if view.energy < view.maxEnergy then
				view.energy = math.min(view.maxEnergy, view.energy + 25)
				refresh(view)
			elseif used then
				used = false
				view.energy = 0
				refresh(view)
				animate(id, "Ultime")
			end
		end
		if math.random() < 0.4 then
			local before = view.health / view.maxHealth
			view.health = if view.health <= 25 then 100 else view.health - math.random(8, 20)
			refresh(view)
			local fill = view.healthFill
			if fill and view.health / view.maxHealth < before then
				DamageFeedbackController.Chip(fill, before, view.health / view.maxHealth, 1)
			end
		end
	end
end

function CombatViewController:Start()
	if RunService:IsStudio() then
		for _, model in CollectionService:GetTagged(TAG_APERCU) do
			task.spawn(runDemo, model)
		end
		CollectionService:GetInstanceAddedSignal(TAG_APERCU):Connect(function(model)
			task.spawn(runDemo, model)
		end)
	end
	local name = `PreparationCombat_{Players.LocalPlayer.UserId}`
	Workspace.ChildAdded:Connect(function(child: Instance)
		if child.Name == name then
			watchFolder(child)
		end
	end)
	local existing = folder()
	if existing then
		watchFolder(existing)
	end
	UserInputService.InputBegan:Connect(onTap)

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local events = remotes:WaitForChild("CombatEvent", 30)
	local actionRemote = remotes:WaitForChild("CombatAction", 30)
	if actionRemote and actionRemote:IsA("RemoteFunction") then
		combatAction = actionRemote
	end
	if events and events:IsA("RemoteEvent") then
		events.OnClientEvent:Connect(onEvents)
	end
end

return CombatViewController
