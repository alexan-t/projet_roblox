--!strict
-- Retour visuel des dégâts (purement visuel, côté client) — issue #17, « Feedback dégâts ».
-- Le jeu est surtout en one-shot : pas d'animation de douleur. Un coup qui ne tue pas se lit par :
--   1. un flash bref sur la cible (clair sur un ennemi, rouge sur un héros : danger) ;
--   2. un petit recul à l'opposé de l'attaquant (atténué pour les gros modèles) ;
--   3. un chiffre de dégâts qui pope puis monte en s'effaçant (design system : Fredoka, contour Ink ;
--      clair sur un ennemi, doré pour un ultime, rouge sur un héros) ;
--   4. sur la barre de vie, une traînée claire qui montre la vie perdue puis se résorbe (Chip).
-- Un coup fatal n'a ni flash ni recul : DefeatEffectController joue la disparition.
-- API : DamageFeedbackController.Hit(model, options) ; DamageFeedbackController.Chip(fill, avant, après, speed?).
--   options = { Amount: number, Ally: boolean?, Ultimate: boolean?, Lethal: boolean?, From: Vector3?, Speed: number? }
-- Tag "ApercuDegats" (Model, Studio) : coups en boucle sur le modèle, avec une barre de vie de
--   démonstration. Attributs optionnels ApercuPauseDegats (s entre deux coups, 1,1 par défaut ;
--   ApercuPause sert déjà aux autres démos), ApercuVitesse (sur le modèle ou son dossier),
--   ApercuAllie (booléen : coups reçus par un héros, en rouge).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local AudioController = require(script.Parent.AudioController)

local TAG_APERCU = "ApercuDegats"
local FLASH_TIME = 0.15
local RECOIL_OUT = 0.06
local RECOIL_BACK = 0.14
local RECOIL_DISTANCE = 0.3 -- studs, pour un modèle de taille humaine (≈ 6 studs)
local NUMBER_HOLD = 0.25 -- le chiffre reste lisible avant de monter et de s'effacer
local CHIP_HOLD = 0.25
local CHIP_SHRINK = 0.3

local Colors = UITheme.Colors
local DamageFeedbackController = {}

export type HitOptions = {
	Amount: number,
	Ally: boolean?,
	Ultimate: boolean?,
	Lethal: boolean?,
	From: Vector3?,
	Speed: number?,
}

local function flash(model: Model, ally: boolean, speed: number)
	local highlight = Instance.new("Highlight")
	highlight.Name = "DegatsFlash"
	highlight.Adornee = model
	highlight.FillColor = if ally then Colors.Error else Colors.TextLight
	highlight.FillTransparency = if ally then 0.45 else 0.3
	highlight.OutlineTransparency = 1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = model
	local tween = TweenService:Create(highlight, TweenInfo.new(FLASH_TIME / speed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FillTransparency = 1 })
	tween.Completed:Connect(function()
		highlight:Destroy()
	end)
	tween:Play()
end

-- Recul appliqué par écarts successifs : il s'ajoute à la position que le serveur donne au modèle.
local function recoil(model: Model, from: Vector3, speed: number)
	local box, size = model:GetBoundingBox()
	local away = Vector3.new(box.Position.X - from.X, 0, box.Position.Z - from.Z)
	if away.Magnitude < 1e-3 then
		return
	end
	local distance = RECOIL_DISTANCE * math.clamp(6 / math.max(size.Y, 1), 0.3, 1)
	local direction = away.Unit
	local applied = Vector3.zero
	local start = os.clock()
	local outTime, backTime = RECOIL_OUT / speed, RECOIL_BACK / speed
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		if not model.Parent then
			connection:Disconnect()
			return
		end
		local t = os.clock() - start
		local amount = if t < outTime then t / outTime else math.max(0, 1 - (t - outTime) / backTime) ^ 2
		local offset = direction * distance * amount
		model:PivotTo(model:GetPivot() + (offset - applied))
		applied = offset
		if t >= outTime + backTime then
			connection:Disconnect()
		end
	end)
end

local function number(model: Model, amount: number, ally: boolean, ultimate: boolean, speed: number)
	local _, size = model:GetBoundingBox()
	local typography = UITheme.Typography
	local gui = Instance.new("BillboardGui")
	gui.Name = "DegatsChiffre"
	-- Plus lisibles : coup de base en Heading (24), ultime en Title (32) doré avec « ! », contour épais.
	gui.Size = if ultimate then UDim2.fromOffset(150, 64) else UDim2.fromOffset(110, 48)
	gui.StudsOffsetWorldSpace = Vector3.new(math.random(-6, 6) / 10, size.Y / 2 + (if ultimate then 1.6 else 1), 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = UITheme.World.CombatDistance
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.FontFace = typography.Display
	text.TextSize = if ultimate then typography.Size.Title else typography.Size.Heading
	text.TextColor3 = if ally then Colors.Error elseif ultimate then Colors.GoldLight else Colors.TextLight
	text.Text = tostring(math.floor(amount + 0.5)) .. (if ultimate then " !" else "")
	text.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = UITheme.Stroke.Color
	stroke.Thickness = if ultimate then typography.TextStroke.Large else typography.TextStroke.Medium
	stroke.LineJoinMode = UITheme.Stroke.LineJoin
	stroke.Parent = text
	local scale = Instance.new("UIScale")
	scale.Scale = UITheme.Animation.Scale.OpenFrom
	scale.Parent = text
	gui.Parent = model

	-- pop (Toast : 0,25 s, un rebond), courte tenue, puis montée et fondu
	local animation = UITheme.Animation
	TweenService:Create(scale, TweenInfo.new(animation.Toast.Time / speed, animation.Toast.EasingStyle, animation.Toast.EasingDirection), {
		Scale = if ultimate then animation.Scale.Pop else 1,
	}):Play()
	task.delay((animation.Toast.Time + NUMBER_HOLD) / speed, function()
		if not gui.Parent then
			return
		end
		local fade = TweenInfo.new(0.35 / speed, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(gui, fade, { StudsOffsetWorldSpace = gui.StudsOffsetWorldSpace + Vector3.new(0, 1.2, 0) }):Play()
		TweenService:Create(text, fade, { TextTransparency = 1 }):Play()
		TweenService:Create(stroke, fade, { Transparency = 1 }):Play()
		task.delay(0.4 / speed, function()
			gui:Destroy()
		end)
	end)
end

-- Coup reçu par model (à appeler à l'instant du coup visible).
function DamageFeedbackController.Hit(model: Model, options: HitOptions)
	if not model.Parent or options.Amount <= 0 then
		return
	end
	local speed = if options.Speed and options.Speed > 0 then options.Speed else 1
	local ally = options.Ally == true
	local ultimate = options.Ultimate == true
	-- son du coup (#18) ; l'ultime a son propre son d'impact (UltimateEffectController)
	if not ultimate then
		AudioController.Play("Impact", { Position = model:GetPivot().Position })
	end
	if not options.Lethal then
		flash(model, ally, speed)
		if options.From then
			recoil(model, options.From, speed)
		end
	end
	number(model, options.Amount, ally, ultimate, speed)
end

-- Traînée de barre de vie : fill est le remplissage (enfant de la piste), ses tailles en échelle.
-- La part perdue reste visible en clair (Cream) puis se résorbe vers la nouvelle valeur.
function DamageFeedbackController.Chip(fill: Frame, before: number, after: number, speed: number?)
	local track = fill.Parent
	if not track or not track:IsA("GuiObject") or after >= before then
		return
	end
	local scale = if speed and speed > 0 then speed else 1
	local chip = Instance.new("Frame")
	chip.Name = "Trainee"
	chip.BackgroundColor3 = Colors.Cream
	chip.BorderSizePixel = 0
	chip.ZIndex = fill.ZIndex
	chip.Position = UDim2.fromScale(after, 0)
	chip.Size = UDim2.fromScale(before - after, 1)
	chip.Parent = track
	local shrink = TweenService:Create(chip, TweenInfo.new(CHIP_SHRINK / scale, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, CHIP_HOLD / scale), {
		Size = UDim2.fromScale(0, 1),
	})
	shrink.Completed:Connect(function()
		chip:Destroy()
	end)
	shrink:Play()
end

-- Démonstration Studio : une barre de vie au-dessus du modèle et des coups réguliers venant de face.
local function demoBar(model: Model): (BillboardGui, Frame)
	local _, size = model:GetBoundingBox()
	local gui = Instance.new("BillboardGui")
	gui.Name = "ApercuBarre"
	gui.Size = UDim2.fromOffset(64, 7)
	gui.StudsOffsetWorldSpace = Vector3.new(0, size.Y / 2 + 0.5, 0)
	gui.AlwaysOnTop = true
	local track = Instance.new("Frame")
	track.BackgroundColor3 = Colors.BarTrack
	track.BackgroundTransparency = UITheme.Transparency.Track
	track.Size = UDim2.fromScale(1, 1)
	track.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UITheme.Radius.Pill
	corner.Parent = track
	local stroke = Instance.new("UIStroke")
	stroke.Color = UITheme.Stroke.Color
	stroke.Thickness = UITheme.Stroke.Thin
	stroke.Parent = track
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = Colors.EnemyHealth
	fill.BorderSizePixel = 0
	fill.ZIndex = 2
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = track
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UITheme.Radius.Pill
	fillCorner.Parent = fill
	gui.Parent = model
	return gui, fill
end

local function runDemo(model: Model)
	local deadline = os.clock() + 15
	while model.Parent and not model.PrimaryPart and os.clock() < deadline do
		task.wait(0.2)
	end
	local gui, fill = demoBar(model)
	local health = 1
	local hits = 0
	while model.Parent and CollectionService:HasTag(model, TAG_APERCU) do
		local pause = model:GetAttribute("ApercuPauseDegats")
		local speed = model:GetAttribute("ApercuVitesse") or (model.Parent and model.Parent:GetAttribute("ApercuVitesse"))
		speed = if typeof(speed) == "number" and speed > 0 then speed else 1
		task.wait((if typeof(pause) == "number" then math.max(pause, 0.4) else 1.1) / speed)
		hits += 1
		local ultimate = hits % 4 == 0
		local amount = if ultimate then 60 else math.random(10, 22)
		local before = health
		health = math.max(0, health - amount / 300)
		local root = model.PrimaryPart
		local from = if root then root.Position + root.CFrame.LookVector * 6 else nil
		local ally = model:GetAttribute("ApercuAllie") == true
		DamageFeedbackController.Hit(model, { Amount = amount, Ally = ally, Ultimate = ultimate and not ally, From = from, Speed = speed })
		fill.BackgroundColor3 = if ally then (if health <= 0.3 then Colors.HealthLow else Colors.Health) else Colors.EnemyHealth
		fill.Size = UDim2.fromScale(health, 1)
		DamageFeedbackController.Chip(fill, before, health, speed)
		if health <= 0 then
			task.wait(0.8 / speed)
			health = 1
			fill.Size = UDim2.fromScale(1, 1)
		end
	end
	gui:Destroy()
end

function DamageFeedbackController:Start()
	if not RunService:IsStudio() then
		return
	end
	for _, model in CollectionService:GetTagged(TAG_APERCU) do
		if model:IsA("Model") then
			task.spawn(runDemo, model)
		end
	end
	CollectionService:GetInstanceAddedSignal(TAG_APERCU):Connect(function(model)
		if model:IsA("Model") then
			task.spawn(runDemo, model)
		end
	end)
end

return DamageFeedbackController
