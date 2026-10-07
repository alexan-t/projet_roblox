--!strict
-- Informations de combat dans le monde, côté client (voir docs/COMBAT.md) : consomme Remotes.CombatEvent.
--   • Au-dessus de chaque unité : barre de PV (rouge sous 30 %), barre de mana pour les héros
--     (dorée et pulsante quand l'ultime est prêt, avec un léger contour sur le héros). Barre plus
--     large pour le mini-boss. Petite icône de classe au-dessus des héros, sans nom.
--   • Dégâts : chiffres brefs au-dessus des ennemis (plus gros pour un ultime), qui s'effacent vite.
--   • Mort : les barres disparaissent, puis l'animation de mort (MonsterAnimationController).
--   • Ultime : automatique côté serveur ; UltimateUsed déclenche seulement un éclat doré (le
--     design pourra y brancher animation, VFX, SFX). Le joueur n'a rien à faire.
-- Aucune règle de combat ici : PV, mana, morts et résultat viennent uniquement du serveur.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local HeroConfig = require(ReplicatedStorage.Shared.Config.HeroConfig)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local MonsterAnimationController = require(script.Parent.MonsterAnimationController)
local UIKit = require(script.Parent.Parent.UI.UIKit)

local CombatViewController = {}

local RETRY_DELAY = 0.2
local RETRIES = 10
local LOW_HEALTH = 0.3
local HEALTH = UITheme.Colors.Health
local HEALTH_LOW = UITheme.Colors.HealthLow
local ENEMY_HEALTH = UITheme.Colors.EnemyHealth
local MANA = UITheme.Colors.Energy
local MANA_FULL = UITheme.Colors.EnergyFull

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
for heroId, info in HeroConfig.Heroes do
	icons[heroId] = info.PlaceholderIcon
end

local views: { [number]: View } = {}

local function folder(): Instance?
	return require(script.Parent.Parent.Arena.PlotView).world()
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
			view.pulse = TweenService:Create(manaFill, UITheme.Animation.Pulse, { BackgroundTransparency = UITheme.Transparency.Pulse })
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
	back.BackgroundColor3 = UITheme.Colors.BarTrack
	back.BackgroundTransparency = UITheme.Transparency.Track
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
		glow.OutlineTransparency = UITheme.World.Glow
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
	-- Fredoka One contouré (design system) ; plus gros et doré pour un ultime.
	local size = if big then UITheme.Typography.Size.Button else UITheme.Typography.Size.Caption
	local text = UIKit.text(gui, tostring(math.floor(amount + 0.5)), size, if big then MANA_FULL else UITheme.Colors.TextLight)
	local outline = text:FindFirstChildOfClass("UIStroke")
	gui.Parent = model
	TweenService:Create(gui, UITheme.Animation.Damage, { StudsOffsetWorldSpace = gui.StudsOffsetWorldSpace + Vector3.new(0, 1.2, 0) }):Play()
	TweenService:Create(text, UITheme.Animation.Damage, { TextTransparency = 1 }):Play()
	if outline then
		TweenService:Create(outline, UITheme.Animation.Damage, { Transparency = 1 }):Play()
	end
	task.delay(0.65, function()
		gui:Destroy()
	end)
end

-- Ultime automatique : bref éclat doré sur le héros (point d'accroche pour les VFX du design).
local function flashUltimate(view: View?)
	local model = if view then view.model else nil
	if not model or not model.Parent then
		return
	end
	local burst = Instance.new("Highlight")
	burst.FillColor = MANA_FULL
	burst.OutlineColor = MANA_FULL
	burst.FillTransparency = UITheme.World.Glow
	burst.OutlineTransparency = 0
	burst.DepthMode = Enum.HighlightDepthMode.Occluded
	burst.Parent = model
	TweenService:Create(burst, UITheme.Animation.Burst, { FillTransparency = 1, OutlineTransparency = 1 }):Play()
	task.delay(0.5, function()
		burst:Destroy()
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
			flashUltimate(views[event.UnitId])
		elseif kind == "Damage" then
			local view = views[event.TargetId]
			if view then
				view.health = event.Health
				refresh(view)
				if view.team == "Enemy" then
					popDamage(view, event.Amount, ultimateHits[event.TargetId] == true)
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
			end
			animate(event.UnitId, "Mort")
			views[event.UnitId] = nil
		end
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
	local name = "PreparationCombat"
	Workspace.DescendantAdded:Connect(function(child: Instance)
		if child.Name == name and child:GetAttribute("OwnerUserId") == Players.LocalPlayer.UserId then
			watchFolder(child)
		end
	end)
	local existing = folder()
	if existing then
		watchFolder(existing)
	end

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local events = remotes:WaitForChild("CombatEvent", 30)
	if events and events:IsA("RemoteEvent") then
		events.OnClientEvent:Connect(onEvents)
	end
end

return CombatViewController
