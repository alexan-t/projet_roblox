--!strict
-- Informations de combat dans le monde, côté client (voir docs/COMBAT.md) : consomme Remotes.CombatEvent.
--   • Au-dessus de chaque unité : barre de PV (rouge sous 30 %), barre de mana pour les héros
--     (dorée et pulsante quand l'ultime est prêt, avec un léger contour sur le héros). Barre plus
--     large pour le mini-boss. Petite icône de classe au-dessus des héros (objet 3D, Icons), sans nom.
--   • Dégâts (DamageFeedbackController), à l'instant du coup : flash et petit recul de la cible, chiffre
--     au design system (clair sur un ennemi, doré pour un ultime, rouge sur un héros), traînée sur la barre.
--   • Mort : les barres disparaissent, puis l'unité se dissout (DefeatEffectController) ; pas
--     d'animation de douleur (« Touche ») ni de mort à jouer pour l'instant.
--   • Ultime : automatique côté serveur. UltimateUsed : le héros joue « Ultime » et une onde dorée file
--     vers la zone touchée (UltimateEffectController) ; chiffres et disparitions des ennemis touchés
--     attendent l'impact de l'onde. Le joueur n'a rien à faire.
--   • Vitesse x2 (SpeedChanged) : animations, instants d'impact et effets suivent la simulation.
--   • Sons (AudioController) : élan de l'attaque ici ; les autres sons partent des effets eux-mêmes.
-- Aucune règle de combat ici : PV, mana, morts et résultat viennent uniquement du serveur.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local AttackEffectController = require(script.Parent.AttackEffectController)
local AudioController = require(script.Parent.AudioController)
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

local views: { [number]: View } = {}
-- Vitesse du combat (SpeedChanged : 1 ou 2). x2 accélère la simulation : les animations, les
-- instants d'impact et les effets suivent, sinon tout serait en retard sur le coup.
local speed = 1

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

-- Hauteur (studs, au-dessus du haut du modèle) de l'icône de classe : au-dessus des barres, sans les couvrir.
local ICON_OFFSET = 2.4

local function top(model: Model): number
	local _, size = model:GetBoundingBox()
	return size.Y / 2
end

-- Petite icône de classe au-dessus d'un héros (placement comme combat) : objet 3D dans une pastille
-- crème contourée Ink (Icons, design system § 7), à la place des monogrammes provisoires.
local function attachIcon(model: Model)
	local classId = model:GetAttribute("HeroClass")
	if typeof(classId) ~= "string" or model:FindFirstChild("IconeClasse") then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "IconeClasse"
	gui.Size = UDim2.fromOffset(26, 26)
	gui.StudsOffsetWorldSpace = Vector3.new(0, top(model) + ICON_OFFSET, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 150
	local chip = Instance.new("Frame")
	chip.Size = UDim2.fromScale(1, 1)
	chip.BackgroundColor3 = UITheme.Colors.Cream
	chip.Parent = gui
	UIKit.corner(chip, UITheme.Radius.Pill)
	UIKit.stroke(chip, UITheme.Stroke.Thin)
	Icons.viewport(chip, classId)
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
	local width = if miniBoss then 120 elseif hero then 72 else 64
	local healthHeight = if miniBoss then 10 elseif hero then 8 else 7
	-- Énergie des héros : sous les PV, séparée par un vrai espace pour que les contours Thin ne se
	-- chevauchent pas (sinon la barre se réduit à un trait sombre).
	local manaGap, manaHeight = 4, 6
	local gui = Instance.new("BillboardGui")
	gui.Name = "BarresCombat"
	gui.Size = UDim2.fromOffset(width, healthHeight + (if hero then manaGap + manaHeight else 0) + 4)
	gui.StudsOffsetWorldSpace = Vector3.new(0, top(model) + 0.5, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 150
	view.healthFill = bar(gui, 0, healthHeight, if hero then HEALTH else ENEMY_HEALTH)
	if hero and view.maxEnergy > 0 then
		view.manaFill = bar(gui, healthHeight + manaGap, manaHeight, MANA)
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
	-- L'icône a pu être posée avant la réplication de toutes les pièces : la recaler au-dessus des barres.
	local icon = model:FindFirstChild("IconeClasse")
	if icon and icon:IsA("BillboardGui") then
		icon.StudsOffsetWorldSpace = Vector3.new(0, top(model) + ICON_OFFSET, 0)
	end
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
			AudioController.Play("Attaque") -- élan de l'arme (#18)
			local attacker = views[event.UnitId]
			if attacker and attacker.model and event.TargetId then
				-- Effet d'impact éventuel (attribut EffetAttaque) ; renvoie l'instant du coup.
				local impact = AttackEffectController.Play(attacker.model, speed)
				if impact > 0 and not hitDelay[event.TargetId] then
					hitDelay[event.TargetId] = impact
				end
			end
			-- À portée, l'unité ne bouge plus : la marche (bouclée) s'arrête.
			if attacker and attacker.model then
				MonsterAnimationController.Stop(attacker.model, "Marche")
			end
			animate(event.UnitId, "Attaque")
		elseif kind == "MoveStarted" then
			animate(event.UnitId, "Marche")
		elseif kind == "UnitDied" then
			local view = views[event.UnitId]
			if view then
				-- Les barres disparaissent d'abord, puis l'unité se dissout.
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
					MonsterAnimationController.Stop(view.model, "Marche")
					-- Disparaît quand le coup l'atteint (onde de l'ultime, impact de l'attaque).
					DefeatEffectController.Play(view.model, hitDelay[event.UnitId] or 0, speed)
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
