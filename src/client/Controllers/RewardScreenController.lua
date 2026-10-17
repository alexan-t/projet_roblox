--!strict
-- Écran de fin de combat et récompenses (présentation, côté client) — issue #17, « Effets Reward Screen ».
-- Suit docs/UI_DESIGN_SYSTEM.md (§ 6 Récompenses, § 8 Animations, § 10 Victoire / Défaite) ; toutes les
-- valeurs de style viennent de UITheme. Ne décide d'aucune récompense : RewardService (#9) les fournit.
-- Déroulé (victoire) :
--   1. voile Ink à Overlay (jamais d'écran noir) ;
--   2. « Victoire ! » (Hero, Gold, contour 4) en pop, rayons dorés lents derrière, étincelles ;
--   3. badge « Première victoire » si FirstClear ;
--   4. cartes de récompense en cascade (pop décalé de 0,05 s), objet 3D tournant dans la carte,
--      quantité qui défile (Count) puis pop de l'icône ; badge « Nouveau » sur une récompense nouvelle ;
--   5. section « Héros » (#68) : chaque héros engagé (portrait, nom, Nv., « +25 XP », barre qui se
--      remplit) ; montée de niveau : « NIVEAU SUPÉRIEUR ! », « Nv.1 → Nv.2 », pop et lueur dorée.
--      Valeurs du serveur (CombatEnded.HeroProgression), jamais calculées ici. Possible même sans carte de
--      récompense (stages sans récompense de stage) ;
--   6. bouton principal « Continuer » en dernier.
-- Défaite : titre Error, sans rayons ni étincelles.
-- API : RewardScreenController.Show(data, onContinue?) ; RewardScreenController.Hide().
--   data = { Result: "Victory" | "Defeat", FirstClear: boolean?,
--            Rewards: { { Kind: "Gold" | "Gems" | "SummonTicket", Amount: number, New: boolean? } },
--            Heroes: { { InstanceId, HeroId, XPGranted, LevelBefore, LevelAfter, XP, XPToNext, MaxLevel } }? }
-- Démonstration Studio : attribut Workspace.ApercuEcranRecompenses = true (l'écran s'affiche, puis
--   revient 2 s après « Continuer »).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local HeroConfig = require(ReplicatedStorage.Shared.Config.HeroConfig)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local Icons = require(script.Parent.Parent.UI.Icons)
local UIKit = require(script.Parent.Parent.UI.UIKit)
local AudioController = require(script.Parent.AudioController)

local Colors = UITheme.Colors
local Typography = UITheme.Typography
local Animation = UITheme.Animation
local Spacing = UITheme.Spacing

local CARD_SIZE = Vector2.new(132, 164)
local CASCADE = 0.05 -- décalage entre deux cartes (design system)
local RAY_COUNT = 12
local RAY_LENGTH = 230 -- px, du centre du titre au bout d'un rayon
local SPARKS = 10

export type Reward = { Kind: string, Amount: number, New: boolean? }
-- Silent : le son du résultat a déjà été joué (annonce « VICTOIRE ! » de l'outro de combat).
-- Progression d'un héros engagé (vue serveur, CombatEnded.HeroProgression).
export type HeroProgress = { InstanceId: string, HeroId: string, XPGranted: number, LevelBefore: number, LevelAfter: number, XP: number, XPToNext: number, MaxLevel: number }
export type ScreenData = { Result: string, FirstClear: boolean?, Rewards: { Reward }?, Silent: boolean?, Heroes: { HeroProgress }? }

local HERO_CHIP = Vector2.new(220, 96)
local HEROES_HEIGHT = 30 + HERO_CHIP.Y -- titre « Héros » + une ligne de héros

local KINDS = {
	Gold = { Label = "Or", Color = Colors.CurrencyGold },
	Gems = { Label = "Gemmes", Color = Colors.CurrencyGems },
	SummonTicket = { Label = "Ticket", Color = Colors.CurrencyTickets },
}

local RewardScreenController = {}

local current: ScreenGui? = nil

local function tween(instance: Instance, info: TweenInfo, goal: { [string]: any }): Tween
	local t = TweenService:Create(instance, info, goal)
	t:Play()
	return t
end

local function corner(parent: Instance, radius: UDim)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = parent
end

local function stroke(parent: Instance, thickness: number, color: Color3?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color or UITheme.Stroke.Color
	s.Thickness = thickness
	s.LineJoinMode = UITheme.Stroke.LineJoin
	s.ApplyStrokeMode = if parent:IsA("TextLabel") or parent:IsA("TextButton") then Enum.ApplyStrokeMode.Contextual else Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

-- Texte Fredoka clair contouré Ink (règle du design system pour tout texte sur fond transparent).
local function label(parent: Instance, text: string, size: number, color: Color3?, strokeSize: number?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.FontFace = Typography.Display
	l.TextSize = size
	l.TextColor3 = color or Colors.TextLight
	l.Text = text
	l.Size = UDim2.fromScale(1, 1)
	l.Parent = parent
	if strokeSize then
		stroke(l, strokeSize)
	end
	return l
end

local function popIn(object: GuiObject, delay: number, peak: number?)
	local scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = object
	task.delay(delay, function()
		if not scale.Parent then
			return
		end
		local up = tween(scale, TweenInfo.new(Animation.Toast.Time * 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = peak or Animation.Scale.Pop })
		up.Completed:Wait()
		if scale.Parent then
			tween(scale, TweenInfo.new(Animation.Toast.Time * 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 })
		end
	end)
end

-- Icône = petit objet du monde (design system § 7), en 3D dans un ViewportFrame, éclairé d'en haut à
-- gauche. La silhouette Ink est une copie sombre légèrement plus grande, placée derrière.
local function iconModel(kind: string): Model
	local model = Instance.new("Model")
	local function part(props: { [string]: any }): Part
		local p = Instance.new("Part")
		p.Anchored = true
		p.Material = Enum.Material.SmoothPlastic
		for k, v in props do
			(p :: any)[k] = v
		end
		p.Parent = model
		return p
	end
	if kind == "Gold" then
		-- pièce : disque doré, liseré foncé, centre clair
		local face = CFrame.Angles(0, math.rad(90), 0)
		part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.35, 2.2, 2.2), Color = Colors.GoldDeep, CFrame = face })
		part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.42, 1.8, 1.8), Color = Colors.Gold, CFrame = face })
		part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.46, 1.1, 1.1), Color = Colors.GoldLight, CFrame = face })
	elseif kind == "Gems" then
		-- gemme : cube posé sur la pointe, facette haute plus claire
		local tilt = CFrame.Angles(math.rad(45), 0, math.rad(45))
		part({ Size = Vector3.new(1.5, 1.5, 1.5), Color = Colors.CurrencyGems, CFrame = tilt })
		part({ Size = Vector3.new(0.8, 0.8, 0.8), Color = Colors.Foam, CFrame = CFrame.new(-0.25, 0.35, -0.3) * tilt, Transparency = 0.35 })
	else
		-- ticket d'invocation : toile rouge sur cadre doré, sceau crème
		part({ Size = Vector3.new(2.6, 1.6, 0.2), Color = Colors.Gold })
		part({ Size = Vector3.new(2.3, 1.3, 0.26), Color = Colors.RoyalRed })
		part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 0.7, 0.7), Color = Colors.Cream, CFrame = CFrame.Angles(0, math.rad(90), 0) })
	end
	-- silhouette Ink derrière (contour « cuit » de l'icône)
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") then
			local back = p:Clone()
			back.Color = UITheme.Stroke.Color
			back.Transparency = 0
			back.Size = p.Size * 1.12
			back.CFrame = p.CFrame + Vector3.new(0, 0, 0.25)
			back.Parent = model
		end
	end
	return model
end

local function icon(parent: Instance, kind: string): (ViewportFrame, Model)
	local viewport = Instance.new("ViewportFrame")
	viewport.BackgroundTransparency = 1
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.Ambient = Colors.Cream
	viewport.LightColor = Color3.new(1, 1, 1)
	viewport.LightDirection = Vector3.new(1, -1, 1) -- lumière chaude d'en haut à gauche
	viewport.Parent = parent
	local model = iconModel(kind)
	model.Parent = viewport
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 0.4, -7), Vector3.zero)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	return viewport, model
end

local function badge(parent: GuiObject, text: string, color: Color3): Frame
	local b = Instance.new("Frame")
	b.Name = "Badge"
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.Position = UDim2.new(0.5, 0, 0, 0)
	b.Size = UDim2.fromOffset(84, 24)
	b.BackgroundColor3 = color
	b.ZIndex = 5
	b.Parent = parent
	corner(b, UITheme.Radius.Pill)
	stroke(b, UITheme.Stroke.Thin)
	local l = label(b, text, Typography.Size.Caption, Colors.TextLight, Typography.TextStroke.Small)
	l.ZIndex = 6
	return b
end

local function card(parent: Instance, reward: Reward, index: number, start: number, spins: { Model })
	local info = KINDS[reward.Kind] or KINDS.Gold
	local frame = Instance.new("Frame")
	frame.Name = "Carte_" .. reward.Kind
	frame.Size = UDim2.fromOffset(CARD_SIZE.X, CARD_SIZE.Y)
	frame.BackgroundColor3 = Colors.Cream
	frame.BackgroundTransparency = UITheme.Transparency.PanelStrong
	frame.LayoutOrder = index
	frame.Parent = parent
	corner(frame, UITheme.Radius.Medium)
	local border = stroke(frame, UITheme.Stroke.Regular)
	if reward.New then
		border.Color = Colors.Selected
		border.Thickness = UITheme.Stroke.Thick
	end

	-- grande zone d'illustration (≥ 60 % de la hauteur), sable semi-transparent
	local art = Instance.new("Frame")
	art.Position = UDim2.fromOffset(Spacing.S, Spacing.S + 6)
	art.Size = UDim2.new(1, -2 * Spacing.S, 0.62, 0)
	art.BackgroundColor3 = Colors.Sand
	art.BackgroundTransparency = UITheme.Transparency.PanelStrong
	art.Parent = frame
	corner(art, UITheme.Radius.Small)
	local viewport, model = icon(art, reward.Kind)
	table.insert(spins, model)

	local name = label(frame, info.Label, Typography.Size.Label, Colors.InkSoft)
	name.Position = UDim2.new(0, Spacing.S, 0.62, Spacing.S + 6)
	name.Size = UDim2.new(1, -2 * Spacing.S, 0, 22)
	name.TextXAlignment = Enum.TextXAlignment.Left

	local amount = label(frame, "×0", Typography.Size.Heading, Colors.TextLight, Typography.TextStroke.Medium)
	amount.AnchorPoint = Vector2.new(1, 1)
	amount.Position = UDim2.new(1, -Spacing.S, 1, -Spacing.XS)
	amount.Size = UDim2.fromOffset(90, 30)
	amount.TextXAlignment = Enum.TextXAlignment.Right

	if reward.New then
		badge(frame, "Nouveau", Colors.RoyalRed)
	end

	local appear = start + (index - 1) * CASCADE
	popIn(frame, appear)
	AudioController.Play("Recompense", { Delay = appear, Pitch = 1 + 0.06 * (index - 1) }) -- carte qui apparaît (#18)
	-- la quantité défile (Count, 0,4 s) une fois la carte posée, puis l'icône fait un pop
	task.delay(appear + Animation.Toast.Time, function()
		if not amount.Parent then
			return
		end
		local counter = Instance.new("NumberValue")
		counter.Changed:Connect(function(value)
			amount.Text = "×" .. tostring(math.floor(value + 0.5))
		end)
		local roll = tween(counter, Animation.Count, { Value = reward.Amount })
		roll.Completed:Connect(function()
			counter:Destroy()
			if viewport.Parent then
				local s = Instance.new("UIScale")
				s.Parent = viewport
				local up = tween(s, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = Animation.Scale.Pop })
				up.Completed:Connect(function()
					tween(s, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 })
				end)
			end
		end)
	end)
end

-- Bouton principal « chunky » : face dégradée or + lèvre plus sombre (design system § 6).
local function primaryButton(parent: Instance, text: string, onClick: () -> ()): Frame
	local holder = Instance.new("Frame")
	holder.Name = "Continuer"
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Size = UDim2.fromOffset(220, 56 + UITheme.Shadow.ButtonLip)
	holder.BackgroundTransparency = 1
	holder.Parent = parent
	local lip = Instance.new("Frame")
	lip.Position = UDim2.fromOffset(0, UITheme.Shadow.ButtonLip)
	lip.Size = UDim2.new(1, 0, 1, -UITheme.Shadow.ButtonLip)
	lip.BackgroundColor3 = Colors.GoldDeep:Lerp(Colors.Ink, 0.35)
	lip.Parent = holder
	corner(lip, UITheme.Radius.Medium)
	stroke(lip, UITheme.Stroke.Regular)
	local face = Instance.new("TextButton")
	face.AutoButtonColor = false
	face.Text = ""
	face.Size = UDim2.new(1, 0, 1, -UITheme.Shadow.ButtonLip)
	face.BackgroundColor3 = Color3.new(1, 1, 1)
	face.Parent = holder
	corner(face, UITheme.Radius.Medium)
	stroke(face, UITheme.Stroke.Regular)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Colors.GoldLight, Colors.GoldDeep)
	gradient.Rotation = 90
	gradient.Parent = face
	local l = label(face, text, Typography.Size.Button, Colors.TextLight, Typography.TextStroke.Medium)
	l.ZIndex = 2
	local scale = Instance.new("UIScale")
	scale.Parent = holder
	face.MouseEnter:Connect(function()
		tween(scale, Animation.Hover, { Scale = Animation.Scale.Hover })
	end)
	face.MouseLeave:Connect(function()
		tween(scale, Animation.Hover, { Scale = 1 })
		face.Position = UDim2.fromOffset(0, 0)
	end)
	face.MouseButton1Down:Connect(function()
		tween(scale, Animation.Press, { Scale = Animation.Scale.Pressed })
		face.Position = UDim2.fromOffset(0, UITheme.Shadow.ButtonLip) -- la face descend sur la lèvre
	end)
	face.MouseButton1Up:Connect(function()
		face.Position = UDim2.fromOffset(0, 0)
		tween(scale, Animation.Hover, { Scale = 1 })
	end)
	face.Activated:Connect(onClick)
	return holder
end

local function rays(parent: Instance): Frame
	-- Un GuiObject tourne autour de son propre centre : chaque rayon est donc un carré transparent
	-- centré sur le titre, qui porte un faisceau fin partant du centre vers le haut.
	local holder = Instance.new("Frame")
	holder.Name = "Rayons"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Size = UDim2.fromOffset(RAY_LENGTH * 2, RAY_LENGTH * 2)
	holder.BackgroundTransparency = 1
	holder.Parent = parent
	for i = 1, RAY_COUNT do
		local arm = Instance.new("Frame")
		arm.Size = UDim2.fromScale(1, 1)
		arm.BackgroundTransparency = 1
		arm.Rotation = (i - 1) * 360 / RAY_COUNT
		arm.Parent = holder
		local beam = Instance.new("Frame")
		beam.AnchorPoint = Vector2.new(0.5, 0)
		beam.Position = UDim2.fromScale(0.5, 0)
		beam.Size = UDim2.new(0, if i % 2 == 0 then 22 else 34, 0.5, 0)
		beam.BackgroundColor3 = Colors.GoldLight
		beam.BorderSizePixel = 0
		beam.Parent = arm
		-- plein près du centre, effacé vers l'extérieur ; pas de reflet glossy
		local fade = Instance.new("UIGradient")
		fade.Rotation = 90
		fade.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.75, 0.7),
			NumberSequenceKeypoint.new(1, 0.55),
		})
		fade.Parent = beam
	end
	return holder
end

local function sparkles(parent: Instance, delay: number)
	local random = Random.new()
	for i = 1, SPARKS do
		local spark = Instance.new("Frame")
		spark.AnchorPoint = Vector2.new(0.5, 0.5)
		spark.Rotation = 45
		local size = random:NextInteger(10, 18)
		spark.Size = UDim2.fromOffset(size, size)
		spark.Position = UDim2.new(0.5, random:NextInteger(-230, 230), 0, random:NextInteger(20, 150))
		spark.BackgroundColor3 = if i % 3 == 0 then Colors.TextLight else Colors.GoldLight
		spark.ZIndex = 4
		spark.Parent = parent
		stroke(spark, UITheme.Stroke.Thin)
		local scale = Instance.new("UIScale")
		scale.Scale = 0
		scale.Parent = spark
		task.delay(delay + random:NextNumber(0, 0.5), function()
			if not scale.Parent then
				return
			end
			local up = tween(scale, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			up.Completed:Wait()
			task.wait(0.1)
			if scale.Parent then
				tween(scale, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0 })
			end
		end)
	end
end

function RewardScreenController.Hide()
	local gui = current
	if not gui then
		return
	end
	current = nil
	local root = gui:FindFirstChild("Contenu") :: Frame?
	local veil = gui:FindFirstChild("Voile") :: Frame?
	if root then
		local scale = root:FindFirstChildOfClass("UIScale")
		local base = if scale then scale.Scale else 1
		if scale then
			tween(scale, Animation.Close, { Scale = base * Animation.Scale.OpenFrom })
		end
		for _, item in root:GetDescendants() do
			if item:IsA("GuiObject") then
				tween(item, Animation.Close, { BackgroundTransparency = 1 })
			end
			if item:IsA("TextLabel") then
				tween(item, Animation.Close, { TextTransparency = 1 })
			end
			if item:IsA("UIStroke") then
				tween(item, Animation.Close, { Transparency = 1 })
			end
			if item:IsA("ViewportFrame") then
				tween(item, Animation.Close, { ImageTransparency = 1 })
			end
		end
	end
	if veil then
		tween(veil, Animation.Close, { BackgroundTransparency = 1 })
	end
	task.delay(Animation.Close.Time + 0.05, function()
		gui:Destroy()
	end)
end

-- Un héros engagé : portrait, nom, niveau, « +XP », barre ; la barre part de l'XP d'avant le combat et
-- se remplit ; une montée de niveau la remplit, puis repart du nouveau niveau, avec l'annonce.
local function heroChip(parent: Instance, entry: HeroProgress, index: number, start: number)
	local info = HeroConfig.Heroes[entry.HeroId]
	local levelUp = entry.LevelAfter > entry.LevelBefore
	local chip = UIKit.subPanel(parent, UDim2.fromOffset(HERO_CHIP.X, HERO_CHIP.Y))
	chip.Name = `Heros_{index}`
	chip.LayoutOrder = index
	local border = chip:FindFirstChildOfClass("UIStroke")
	local art = Instance.new("Frame")
	art.BackgroundColor3 = Colors.Sand
	art.BackgroundTransparency = UITheme.Transparency.Art
	art.Position = UDim2.fromOffset(Spacing.S, Spacing.S)
	art.Size = UDim2.fromOffset(HERO_CHIP.Y - 2 * Spacing.S, HERO_CHIP.Y - 2 * Spacing.S)
	art.Parent = chip
	corner(art, UITheme.Radius.Small)
	local model = Icons.heroModel(entry.HeroId)
	if model then
		UIKit.portrait(art, model)
	end
	local left = HERO_CHIP.Y + Spacing.XS
	local name = UIKit.text(chip, if info then info.Name else entry.HeroId, Typography.Size.Caption, { Align = Enum.TextXAlignment.Left })
	name.Position = UDim2.fromOffset(left, Spacing.S)
	name.Size = UDim2.new(1, -left - Spacing.S, 0, 18)
	name.TextTruncate = Enum.TextTruncate.AtEnd
	local level = UIKit.text(chip, `Nv.{entry.LevelBefore}`, Typography.Size.Label, { Align = Enum.TextXAlignment.Left })
	level.Position = UDim2.fromOffset(left, 28)
	level.Size = UDim2.fromOffset(80, 22)
	local gain = UIKit.text(chip, `+{entry.XPGranted} XP`, Typography.Size.Label, { Color = Colors.GoldLight, Align = Enum.TextXAlignment.Right })
	gain.Position = UDim2.new(1, -Spacing.S - 90, 0, 28)
	gain.Size = UDim2.fromOffset(90, 22)
	local bar = UIKit.bar(chip, { Color = Colors.Progress, Size = UDim2.new(1, -left - Spacing.S, 0, 10) })
	bar.Frame.Position = UDim2.fromOffset(left, 56)
	local need = entry.XPToNext
	local maxed = entry.LevelAfter >= entry.MaxLevel
	local ratio = if maxed then 1 elseif need > 0 then entry.XP / need else 0
	local before = if levelUp or maxed or need <= 0 then 0 else math.max(entry.XP - entry.XPGranted, 0) / need
	bar.Set(before)
	local note = UIKit.text(chip, if maxed then "Niveau max" else `{entry.XP} / {need} XP`, Typography.Size.Caption, { Color = Colors.TextMuted, Align = Enum.TextXAlignment.Left })
	note.Position = UDim2.fromOffset(left, 70)
	note.Size = UDim2.new(1, -left - Spacing.S, 0, 18)
	popIn(chip, start + (index - 1) * CASCADE)
	task.delay(start + (index - 1) * CASCADE + Animation.Toast.Time, function()
		if not chip.Parent then
			return
		end
		if not levelUp then
			bar.Set(ratio, true)
			return
		end
		-- montée de niveau : la barre se remplit, le niveau change, annonce dorée
		bar.Set(1, true)
		task.wait(Animation.Count.Time)
		if not chip.Parent then
			return
		end
		bar.Set(0)
		bar.Set(ratio, true)
		level.Text = `Nv.{entry.LevelBefore} → Nv.{entry.LevelAfter}`
		level.Size = UDim2.fromOffset(120, 22)
		level.TextColor3 = Colors.GoldLight
		gain.Visible = false
		local up = UIKit.badge(chip, "NIVEAU SUPÉRIEUR !", Colors.Gold)
		up.AnchorPoint = Vector2.new(0.5, 0.5)
		up.Position = UDim2.new(0.5, 0, 0, 0)
		up.ZIndex = 5
		UIKit.popIn(up, 0, 1.15)
		UIKit.pop(chip)
		if border then
			border.Color = Colors.Gold
			border.Thickness = UITheme.Stroke.Thick
			tween(border, Animation.Pulse, { Color = Colors.GoldLight })
		end
		AudioController.Play("Recompense")
	end)
end

-- Affiche l'écran ; onContinue est appelé au clic sur « Continuer » (après la fermeture).
function RewardScreenController.Show(data: ScreenData, onContinue: (() -> ())?)
	RewardScreenController.Hide()
	local player = Players.LocalPlayer
	local victory = data.Result == "Victory"
	if not data.Silent then
		AudioController.Play(if victory then "Victoire" else "Defaite") -- (#18)
	end
	local rewards = data.Rewards or {}
	local heroes = if victory then data.Heroes or {} else {}

	local gui = Instance.new("ScreenGui")
	gui.Name = "EcranRecompenses"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	current = gui

	local veil = Instance.new("Frame")
	veil.Name = "Voile"
	veil.Size = UDim2.fromScale(1, 1)
	veil.BackgroundColor3 = Colors.Ink
	veil.BackgroundTransparency = 1
	veil.Parent = gui
	tween(veil, Animation.Fade, { BackgroundTransparency = UITheme.Transparency.Overlay })

	local root = Instance.new("Frame")
	root.Name = "Contenu"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromOffset(760, 520)
	root.BackgroundTransparency = 1
	root.Parent = gui
	local uiScale = Instance.new("UIScale")
	uiScale.Parent = root
	local camera = Workspace.CurrentCamera
	local function fit()
		local height = if camera then camera.ViewportSize.Y else 1080
		uiScale.Scale = math.clamp(height / 1080, 0.55, 1.4) -- tailles en px pour un écran de 1080 px
	end
	fit()
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end

	-- titre et décor
	local titleY = 90
	local spins: { Model } = {}
	if victory then
		local r = rays(root)
		r.Position = UDim2.fromOffset(380, titleY)
		popIn(r, 0.05, 1)
		local spin = tween(r, TweenInfo.new(14, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), { Rotation = 360 })
		gui.Destroying:Connect(function()
			spin:Cancel()
		end)
		sparkles(root, 0.25)
	end
	local titleFrame = Instance.new("Frame")
	titleFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	titleFrame.Position = UDim2.fromOffset(380, titleY)
	titleFrame.Size = UDim2.fromOffset(560, 80)
	titleFrame.BackgroundTransparency = 1
	titleFrame.ZIndex = 3
	titleFrame.Parent = root
	local title = label(titleFrame, if victory then "Victoire !" else "Défaite…", Typography.Size.Hero, if victory then Colors.Gold else Colors.Error, Typography.TextStroke.Large)
	title.ZIndex = 3
	popIn(titleFrame, 0.1)

	if victory and data.FirstClear then
		local first = badge(root, "Première victoire", Colors.RoyalRed)
		first.Size = UDim2.fromOffset(170, 30)
		first.Position = UDim2.fromOffset(380, titleY + 58)
		popIn(first, 0.35)
	end

	-- cartes de récompense en cascade
	local cards = Instance.new("Frame")
	cards.Name = "Cartes"
	cards.AnchorPoint = Vector2.new(0.5, 0)
	cards.Position = UDim2.fromOffset(380, titleY + 95)
	cards.Size = UDim2.fromOffset(740, CARD_SIZE.Y + 20)
	cards.BackgroundTransparency = 1
	cards.Parent = root
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, Spacing.XL)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = cards
	local cardsStart = 0.45
	for index, reward in rewards do
		card(cards, reward, index, cardsStart, spins)
	end

	-- objets 3D qui tournent doucement dans leurs cartes
	local spinStart = os.clock()
	local spinner = RunService.RenderStepped:Connect(function()
		local angle = (os.clock() - spinStart) * 0.9
		for i, model in spins do
			model:PivotTo(CFrame.Angles(0, math.sin(angle + i) * 0.6, 0))
		end
	end)
	gui.Destroying:Connect(function()
		spinner:Disconnect()
	end)

	-- héros engagés et leur XP (sous les cartes ; sans carte, juste sous le titre)
	local heroesY = titleY + 95 + (if #rewards > 0 then CARD_SIZE.Y + 30 else 0)
	local heroesStart = cardsStart + #rewards * CASCADE + (if #rewards > 0 then Animation.Toast.Time else 0)
	if #heroes > 0 then
		local section = Instance.new("Frame")
		section.Name = "Heros"
		section.AnchorPoint = Vector2.new(0.5, 0)
		section.Position = UDim2.fromOffset(380, heroesY)
		section.Size = UDim2.fromOffset(740, HEROES_HEIGHT)
		section.BackgroundTransparency = 1
		section.Parent = root
		local heading = UIKit.text(section, "Héros", Typography.Size.Label, { Color = Colors.TextMuted })
		heading.Size = UDim2.new(1, 0, 0, 24)
		popIn(heading, heroesStart)
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.Position = UDim2.fromOffset(0, 30)
		row.Size = UDim2.new(1, 0, 0, HERO_CHIP.Y)
		row.Parent = section
		local rowLayout = Instance.new("UIListLayout")
		rowLayout.FillDirection = Enum.FillDirection.Horizontal
		rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		rowLayout.Padding = UDim.new(0, Spacing.M)
		rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
		rowLayout.Parent = row
		for index, entry in heroes do
			heroChip(row, entry, index, heroesStart + 0.1)
		end
	end

	-- bouton principal en dernier
	local buttonDelay = cardsStart + #rewards * CASCADE + Animation.Toast.Time + Animation.Count.Time
		+ (if #heroes > 0 then #heroes * CASCADE + Animation.Count.Time else 0)
	local button = primaryButton(root, "Continuer", function()
		RewardScreenController.Hide()
		if onContinue then
			task.delay(Animation.Close.Time, onContinue)
		end
	end)
	-- sans récompense ni héros (défaite), le bouton remonte sous le titre
	local below = if #heroes > 0 then heroesY + HEROES_HEIGHT + 20
		elseif #rewards > 0 then titleY + 95 + CARD_SIZE.Y + 50
		else titleY + 95 + 20
	button.Position = UDim2.fromOffset(380, below)
	if #heroes > 0 then
		root.Size = UDim2.fromOffset(760, math.max(520, below + 80))
	end
	popIn(button, if #rewards > 0 or #heroes > 0 then buttonDelay else 0.45, 1.06)

	gui.Parent = player:WaitForChild("PlayerGui")
end

-- Démonstration Studio (attribut Workspace.ApercuEcranRecompenses).
local DEMO = {
	Result = "Victory",
	FirstClear = true,
	Rewards = {
		{ Kind = "Gold", Amount = 120 },
		{ Kind = "Gems", Amount = 15 },
		{ Kind = "SummonTicket", Amount = 1, New = true },
	},
}

local function runDemo()
	while Workspace:GetAttribute("ApercuEcranRecompenses") == true do
		local closed = false
		RewardScreenController.Show(DEMO, function()
			closed = true
		end)
		while not closed and Workspace:GetAttribute("ApercuEcranRecompenses") == true do
			task.wait(0.2)
		end
		task.wait(2)
	end
	RewardScreenController.Hide()
end

function RewardScreenController:Start()
	if not RunService:IsStudio() then
		return
	end
	local running = false
	local function check()
		if Workspace:GetAttribute("ApercuEcranRecompenses") == true and not running then
			running = true
			task.spawn(function()
				task.wait(1.5)
				runDemo()
				running = false
			end)
		end
	end
	Workspace:GetAttributeChangedSignal("ApercuEcranRecompenses"):Connect(check)
	check()
end

return RewardScreenController
