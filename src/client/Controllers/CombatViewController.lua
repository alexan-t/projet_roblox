--!strict
-- Informations de combat dans le monde, côté client (voir docs/COMBAT.md) : consomme Remotes.CombatEvent.
--   • Au-dessus de chaque unité : barre de PV (rouge sous 30 %), barre de mana pour les héros
--     (dorée et pulsante quand l'ultime est prêt, avec un léger contour sur le héros). Barre plus
--     large pour le mini-boss. Petite icône de classe au-dessus des héros, sans nom.
--   • Dégâts : chiffres brefs au-dessus des ennemis (plus gros pour un ultime), qui s'effacent vite.
--   • Mort : les barres disparaissent, puis l'unité se dissout (DefeatEffectController) ; pas
--     d'animation de douleur (« Touche ») ni de mort à jouer pour l'instant.
--   • Ultime : toucher / cliquer un héros dont la mana est pleine (le serveur vérifie tout). Le héros
--     joue « Ultime » et une onde dorée file vers la zone touchée (UltimateEffectController) ; chiffres
--     et disparitions des ennemis touchés attendent l'impact de l'onde.
-- Aucune règle de combat ici : PV, mana, morts et résultat viennent uniquement du serveur.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local ArenaConfig = require(ReplicatedStorage.Shared.Config.ArenaConfig)
local DefeatEffectController = require(script.Parent.DefeatEffectController)
local MonsterAnimationController = require(script.Parent.MonsterAnimationController)
local UltimateEffectController = require(script.Parent.UltimateEffectController)

local CombatViewController = {}

local RETRY_DELAY = 0.2
local RETRIES = 10
local LOW_HEALTH = 0.3
local TAP_RADIUS = 70 -- pixels autour d'un héros pour lancer son ultime
local HEALTH = Color3.fromRGB(90, 205, 90)
local HEALTH_LOW = Color3.fromRGB(235, 60, 50)
local ENEMY_HEALTH = Color3.fromRGB(220, 80, 70)
local MANA = Color3.fromRGB(80, 150, 255)
local MANA_FULL = Color3.fromRGB(255, 205, 80)

type View = {
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
}

local icons: { [string]: string } = {}
for _, class in ArenaConfig.HeroClasses do
	icons[class.Id] = class.Icon
end

local views: { [number]: View } = {}
local combatAction: RemoteFunction? = nil
local active = false

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

-- Petite icône de classe au-dessus d'un héros (placement comme combat).
local function attachIcon(model: Model)
	local classId = model:GetAttribute("HeroClass")
	if typeof(classId) ~= "string" or model:FindFirstChild("IconeClasse") then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "IconeClasse"
	gui.Size = UDim2.fromOffset(18, 18)
	gui.StudsOffsetWorldSpace = Vector3.new(0, top(model) + 1.6, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 150
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.TextScaled = true
	text.Text = icons[classId] or ""
	text.Parent = gui
	gui.Parent = model
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
	end
end

local function bar(parent: Instance, y: number, height: number, color: Color3): Frame
	local back = Instance.new("Frame")
	back.BackgroundColor3 = Color3.new(0, 0, 0)
	back.BackgroundTransparency = 0.35
	back.BorderSizePixel = 0
	back.Position = UDim2.fromOffset(0, y)
	back.Size = UDim2.new(1, 0, 0, height)
	back.Parent = parent
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = back
	return fill
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
	local width = if miniBoss then 110 else 54
	local healthHeight = if miniBoss then 8 else 5
	local gui = Instance.new("BillboardGui")
	gui.Name = "BarresCombat"
	gui.Size = UDim2.fromOffset(width, healthHeight + (if hero then 5 else 0))
	gui.StudsOffsetWorldSpace = Vector3.new(0, top(model) + 0.5, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 150
	view.healthFill = bar(gui, 0, healthHeight, if hero then HEALTH else ENEMY_HEALTH)
	if hero and view.maxEnergy > 0 then
		view.manaFill = bar(gui, healthHeight + 1, 4, MANA)
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

-- Chiffre de dégâts bref au-dessus d'un ennemi.
local function popDamage(view: View, amount: number, big: boolean)
	local model = view.model
	if not model or amount <= 0 then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(60, 24)
	gui.StudsOffsetWorldSpace = Vector3.new(math.random(-8, 8) / 10, top(model) + 1.2, 0)
	gui.AlwaysOnTop = true
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.GothamBold
	text.TextSize = if big then 22 else 14
	text.TextColor3 = if big then MANA_FULL else Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0.4
	text.Text = tostring(math.floor(amount + 0.5))
	text.Parent = gui
	gui.Parent = model
	TweenService:Create(gui, TweenInfo.new(0.6), { StudsOffsetWorldSpace = gui.StudsOffsetWorldSpace + Vector3.new(0, 1.2, 0) }):Play()
	TweenService:Create(text, TweenInfo.new(0.6), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(0.65, function()
		gui:Destroy()
	end)
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
	for _, event in events do
		local kind = event.Type
		if kind == "CombatStarted" then
			table.clear(views)
			active = true
		elseif kind == "UnitSpawned" then
			views[event.UnitId] = {
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
				UltimateEffectController.Play(caster.model, center, radius)
			end
			animate(event.UnitId, "Ultime")
		elseif kind == "Damage" then
			local view = views[event.TargetId]
			if view then
				view.health = event.Health
				refresh(view)
				if view.team == "Enemy" then
					if ultimateHits[event.TargetId] then
						-- Le chiffre tombe avec l'anneau de l'ultime, pas avant.
						task.delay(UltimateEffectController.IMPACT_DELAY, popDamage, view, event.Amount, true)
					else
						popDamage(view, event.Amount, false)
					end
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
				local icon = view.model and view.model:FindFirstChild("IconeClasse")
				if icon then
					icon:Destroy()
				end
				if view.model then
					-- Touché par un ultime : disparaît quand l'onde l'atteint.
					DefeatEffectController.Play(view.model, if ultimateHits[event.UnitId] then UltimateEffectController.IMPACT_DELAY else 0)
				end
			end
			animate(event.UnitId, "Mort")
			views[event.UnitId] = nil
		elseif kind == "CombatEnded" then
			active = false
		end
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
		remote:InvokeServer("UseUltimate", best)
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

function CombatViewController:Start()
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
