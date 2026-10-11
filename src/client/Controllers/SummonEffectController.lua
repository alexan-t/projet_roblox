--!strict
-- VFX d'invocation et d'apparition du héros (purement visuel, côté client) — issue #17, docs/SUMMON.md.
-- Joué au portail d'invocation du plot du joueur (PortailInvocation) ; HeroService fournit le héros
-- obtenu et sa rareté. Déroulé :
--   1. charge : le vortex s'illumine de la couleur de la rareté, des étincelles convergent vers le
--      voile, la lumière monte (la charge dure plus longtemps pour une rareté plus haute) ;
--   2. éclat : flash du voile, lumière, onde(s) au sol ;
--   3. le héros jaillit du voile en silhouette colorée, se pose devant le portail (poussière), puis la
--      silhouette s'efface et révèle le héros ;
--   4. son nom et sa rareté s'affichent au-dessus (Fredoka, contour Ink) avec le badge « Nouveau ».
-- La rareté (RarityConfig, rang 1 Commun → 10 Transcendant) marque le joueur de plus en plus fort :
--   Rare et plus     : colonne de lumière vers le ciel, annonce à l'écran (« Rare ! ») ;
--   Épique et plus   : ondes supplémentaires ;
--   Légendaire et +  : secousse de caméra ; kit doré EffetJackpot (Légendaire, Mythique, Suprême) ;
--   Mythique et plus : flash plein écran, grande annonce ;
--   Maudit           : fumée sombre et voile d'ombre ; Calamité : braises et secousse forte ;
--   Transcendant     : toutes les couleurs du prisme qui tournent.
-- Couleurs : UITheme.Rarity (sans rareté : or, comme la démonstration).
-- API : SummonEffectController.Play(portal, heroTemplate, options?) -> modèle affiché (copie locale).
--   options = { Name: string?, New: boolean?, Rarity: string?, Jackpot: boolean?, Keep: number? (s
--   avant de retirer la copie, 4 par défaut ; 0 = la garder) }
--   SummonEffectController.Duration(rarity?) -> secondes jusqu'à la révélation du héros ;
--   SummonEffectController.Charge(rarity?) -> durée de la charge ; Layout(portal) -> centre du voile,
--   face avant, place du héros. Le héros se pose sur une place d'invocation (cercle au sol, liseré de
--   la couleur de la rareté) qui s'efface avec lui.
-- Démonstration Studio : tag "ApercuInvocation" sur un dossier qui contient des modèles de héros et un
-- ObjectValue « Portail » ; un héros sort toutes les ApercuPause secondes (6 par défaut), avec une
-- rareté qui monte à chaque tour.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local RarityConfig = require(ReplicatedStorage.Shared.Config.RarityConfig)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local RarityStyle = require(script.Parent.Parent.UI.RarityStyle)
local UIKit = require(script.Parent.Parent.UI.UIKit)
local AudioController = require(script.Parent.AudioController)

local TAG_APERCU = "ApercuInvocation"
local CHARGE = 1.2 -- montée en puissance avant l'éclat (Commun) ; +0,2 s par rang
local FLIGHT = 0.45 -- sortie du voile jusqu'au sol
local REVEAL = 0.6 -- la silhouette colorée s'efface
local LANDING_DISTANCE = 7 -- studs devant le voile
local PAD_RADIUS = 4 -- rayon de la place d'invocation (studs), un peu plus grande pour une rareté haute
local PILLAR_HEIGHT = 160 -- colonne de lumière vers le ciel (Rare et plus)
local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local DUST_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE_TEXTURE = "rbxasset://textures/particles/fire_main.dds"

local Colors = UITheme.Colors
local SummonEffectController = {}

export type Options = { Name: string?, New: boolean?, Rarity: string?, Jackpot: boolean?, Keep: number? }

local function tween(instance: Instance, info: TweenInfo, goal: { [string]: any }): Tween
	local t = TweenService:Create(instance, info, goal)
	t:Play()
	return t
end

local function rankOf(rarity: string?): number
	return if rarity then RarityStyle.rank(rarity) else 1
end

local function chargeOf(rank: number): number
	return CHARGE + 0.2 * (rank - 1)
end

function SummonEffectController.Duration(rarity: string?): number
	return chargeOf(rankOf(rarity)) + FLIGHT + REVEAL
end

local function effectPart(props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
	part.CastShadow = false
	for key, value in props do
		(part :: any)[key] = value
	end
	part.Parent = Workspace
	return part
end

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local particles = Instance.new("ParticleEmitter")
	particles.Enabled = false
	for key, value in props do
		(particles :: any)[key] = value
	end
	particles.Parent = parent
	return particles
end

-- Sol sous position, sans compter le portail ni les personnages des joueurs (le héros ne se pose pas
-- sur la tête de quelqu'un). Les héros invoqués ont CanQuery = false.
local function ground(position: Vector3, portal: Instance): Vector3
	local ignore: { Instance } = { portal }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local hit = Workspace:Raycast(position + Vector3.new(0, 12, 0), Vector3.new(0, -60, 0), params)
	return if hit then hit.Position else position
end

-- Avant du modèle : comme AnimationKit, déduit des bras (le pivot des modèles générés est arbitraire),
-- sinon le PrimaryPart, sinon le pivot.
local function frontOf(model: Model): Vector3
	local left = model:FindFirstChild("left_arm_geom", true)
	local right = model:FindFirstChild("right_arm_geom", true)
	if left and right and left:IsA("BasePart") and right:IsA("BasePart") then
		local side = (right.Position - left.Position) * Vector3.new(1, 0, 1)
		if side.Magnitude > 1e-3 then
			return Vector3.yAxis:Cross(side.Unit)
		end
	end
	local look = (if model.PrimaryPart then model.PrimaryPart.CFrame else model:GetPivot()).LookVector * Vector3.new(1, 0, 1)
	return if look.Magnitude > 1e-3 then look.Unit else Vector3.zAxis
end

-- Couleur vivante de l'effet : fixe, ou le prisme qui tourne (Transcendant). paint(fn) applique la
-- couleur courante tout de suite et, pour le prisme, à chaque image tant que l'effet vit.
local function palette(rarity: string?): ((t: number) -> Color3, (apply: (Color3) -> ()) -> (), () -> ())
	local function colorAt(t: number): Color3
		return if rarity then RarityStyle.colorAt(rarity, t) else Colors.GoldLight
	end
	local appliers: { (Color3) -> () } = {}
	local connection: RBXScriptConnection? = nil
	if rarity and RarityStyle.prismatic(rarity) then
		connection = RunService.RenderStepped:Connect(function()
			local color = colorAt(os.clock())
			for _, apply in appliers do
				apply(color)
			end
		end)
	end
	local function paint(apply: (Color3) -> ())
		apply(colorAt(os.clock()))
		table.insert(appliers, apply)
	end
	local function stop()
		if connection then
			connection:Disconnect()
		end
		table.clear(appliers)
	end
	return colorAt, paint, stop
end

-- Onde au sol (cercle de segments jointifs qui s'élargit puis s'efface).
local function ring(center: Vector3, radius: number, color: Color3, duration: number?)
	local count = 28
	local segments: { BasePart } = {}
	for i = 1, count do
		segments[i] = effectPart({ Name = "InvocationOnde", Material = Enum.Material.Neon, Color = color, Size = Vector3.new(1, 0.2, 0.5) })
	end
	local floor = center + Vector3.new(0, 0.12, 0)
	local start = os.clock()
	local length = duration or 0.5
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local progress = math.clamp((os.clock() - start) / length, 0, 1)
		local r = radius * (0.25 + 0.75 * (1 - (1 - progress) ^ 3))
		local alpha = if progress < 0.5 then 0.05 else 0.05 + 0.95 * (progress - 0.5) / 0.5
		for i, segment in segments do
			local angle = 2 * math.pi * i / count
			local offset = Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r)
			segment.Size = Vector3.new(2 * math.pi * r / count * 1.05, 0.2, 0.5)
			segment.CFrame = CFrame.lookAt(floor + offset, floor)
			segment.Transparency = alpha
		end
		if progress >= 1 then
			connection:Disconnect()
			for _, segment in segments do
				segment:Destroy()
			end
		end
	end)
end

-- Kit jackpot du portail (préparé par le design) : allumé le temps de l'invocation.
local function jackpot(portal: Instance, duration: number)
	local kit = portal:FindFirstChild("EffetJackpot")
	if not kit then
		return
	end
	local touched: { Instance } = {}
	for _, item in kit:GetDescendants() do
		if item:IsA("Beam") or item:IsA("Light") or item:IsA("ParticleEmitter") or item:IsA("BillboardGui") then
			local previous = (item :: any).Enabled
			if previous == false then
				(item :: any).Enabled = true
				table.insert(touched, item)
			end
		end
	end
	local halo = kit:FindFirstChild("HaloSol")
	if halo and halo:IsA("BasePart") then
		tween(halo, TweenInfo.new(0.3), { Transparency = 0.35 })
	end
	task.delay(duration, function()
		for _, item in touched do
			(item :: any).Enabled = false
		end
		if halo and halo:IsA("BasePart") then
			tween(halo, TweenInfo.new(0.5), { Transparency = 1 })
		end
	end)
end

-- Colonne de lumière du sol vers le ciel (Rare et plus) : s'élargit à l'éclat puis s'efface.
-- Maudit : colonne d'ombre (mate, assombrie vers Ink) au lieu d'une colonne de lumière.
local function pillar(base: Vector3, rank: number, paint: ((Color3) -> ()) -> (), hold: number, cursed: boolean)
	local width = 1.5 + rank * 0.7
	local column = effectPart({
		Name = "InvocationColonne",
		Shape = Enum.PartType.Cylinder,
		Material = if cursed then Enum.Material.SmoothPlastic else Enum.Material.Neon,
		Transparency = if cursed then 0.3 else 0.15,
		Size = Vector3.new(PILLAR_HEIGHT, 0.2, 0.2),
		CFrame = CFrame.new(base + Vector3.new(0, PILLAR_HEIGHT / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
	})
	paint(function(color: Color3)
		column.Color = if cursed then color:Lerp(Colors.Ink, 0.55) else color
	end)
	tween(column, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = Vector3.new(PILLAR_HEIGHT, width, width) })
	task.delay(hold, function()
		tween(column, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = Vector3.new(PILLAR_HEIGHT, 0.1, 0.1), Transparency = 1 })
		task.delay(0.9, function()
			column:Destroy()
		end)
	end)
end

-- Secousse de la caméra du joueur local (décalage du Humanoid, rendu ensuite).
local function shake(magnitude: number, duration: number)
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local start = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local t = (os.clock() - start) / duration
		if t >= 1 or not humanoid.Parent then
			connection:Disconnect()
			humanoid.CameraOffset = Vector3.zero
			return
		end
		local m = magnitude * (1 - t)
		humanoid.CameraOffset = Vector3.new((math.random() - 0.5) * 2 * m, (math.random() - 0.5) * 2 * m, 0)
	end)
end

-- Flash plein écran (Mythique et plus ; voile d'ombre pour Maudit) et annonce de la rareté.
local function announce(rarity: string, rank: number, paint: ((Color3) -> ()) -> ())
	local screen = UIKit.screen("InvocationRarete", 20)
	if rank >= 6 then
		local flash = Instance.new("Frame")
		flash.Name = "Flash"
		flash.Size = UDim2.fromScale(1, 1)
		flash.BorderSizePixel = 0
		flash.BackgroundTransparency = if rarity == "Maudit" then 0.2 else 0.4
		flash.Parent = screen
		if rarity == "Maudit" then
			flash.BackgroundColor3 = Colors.Ink
		else
			paint(function(color: Color3)
				flash.BackgroundColor3 = color
			end)
		end
		tween(flash, TweenInfo.new(if rarity == "Maudit" then 1.6 else 0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 })
	end
	local label = UIKit.announce(screen, `{RarityStyle.name(rarity)} !`, {
		Size = if rank >= 6 then UITheme.Typography.Size.Hero else UITheme.Typography.Size.Title,
		Hold = 1.5 + rank * 0.15,
		Y = 150,
	})
	RarityStyle.paint(label, rarity)
	task.delay(5, function()
		screen:Destroy()
	end)
end

local function nameplate(hero: Model, name: string, isNew: boolean, rarity: string?)
	local typography = UITheme.Typography
	local _, size = hero:GetBoundingBox()
	local gui = Instance.new("BillboardGui")
	gui.Name = "InvocationNom"
	gui.Size = UDim2.fromOffset(420, if rarity then 100 else 74)
	gui.StudsOffsetWorldSpace = Vector3.new(0, size.Y / 2 + 2.4, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = UITheme.World.EffectDistance
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Position = UDim2.fromOffset(0, 26)
	text.Size = UDim2.new(1, 0, 0, 44)
	text.FontFace = typography.Display
	text.TextSize = typography.Size.Title
	text.TextColor3 = Colors.TextLight
	text.Text = name
	text.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = UITheme.Stroke.Color
	stroke.Thickness = typography.TextStroke.Medium
	stroke.LineJoinMode = UITheme.Stroke.LineJoin
	stroke.Parent = text
	if rarity then
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromOffset(0, 70)
		label.Size = UDim2.new(1, 0, 0, 28)
		label.FontFace = typography.Display
		label.TextSize = typography.Size.Heading
		label.Text = RarityStyle.name(rarity)
		label.Parent = gui
		RarityStyle.paint(label, rarity)
		local labelStroke = Instance.new("UIStroke")
		labelStroke.Color = UITheme.Stroke.Color
		labelStroke.Thickness = typography.TextStroke.Medium
		labelStroke.LineJoinMode = UITheme.Stroke.LineJoin
		labelStroke.Parent = label
	end
	if isNew then
		local badge = Instance.new("Frame")
		badge.AnchorPoint = Vector2.new(0.5, 0)
		badge.Position = UDim2.new(0.5, 0, 0, 0)
		badge.Size = UDim2.fromOffset(92, 24)
		badge.BackgroundColor3 = Colors.RoyalRed
		badge.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UITheme.Radius.Pill
		corner.Parent = badge
		local border = Instance.new("UIStroke")
		border.Color = UITheme.Stroke.Color
		border.Thickness = UITheme.Stroke.Thin
		border.Parent = badge
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.FontFace = typography.Display
		label.TextSize = typography.Size.Caption
		label.TextColor3 = Colors.TextLight
		label.Text = "Nouveau"
		label.Parent = badge
		local labelStroke = Instance.new("UIStroke")
		labelStroke.Color = UITheme.Stroke.Color
		labelStroke.Thickness = typography.TextStroke.Small
		labelStroke.Parent = label
	end
	-- pop (Toast : 0,25 s, un rebond)
	for _, child in gui:GetChildren() do
		if child:IsA("GuiObject") then
			local scale = Instance.new("UIScale")
			scale.Scale = 0
			scale.Parent = child
			tween(scale, UITheme.Animation.Toast, { Scale = 1 })
		end
	end
	gui.Parent = hero
end

-- Géométrie de l'invocation : centre du voile (disque au centre de l'arche), face avant du portail
-- (horizontale) et place où le héros se pose (sol, LANDING_DISTANCE devant le voile).
function SummonEffectController.Layout(portal: Model): (Vector3, Vector3, Vector3)
	local structure = portal:FindFirstChild("Structure")
	local found = if structure then structure:FindFirstChild("voile") else portal:FindFirstChild("voile", true)
	local veil: BasePart? = if found and found:IsA("BasePart") then found else nil
	local center = if veil then veil.Position else portal:GetBoundingBox().Position
	local forward = if veil then veil.CFrame.LookVector else portal:GetPivot().LookVector
	forward = Vector3.new(forward.X, 0, forward.Z).Unit
	return center, forward, ground(center + forward * LANDING_DISTANCE, portal)
end

function SummonEffectController.Charge(rarity: string?): number
	return chargeOf(rankOf(rarity))
end

-- Place d'invocation : cercle au sol où le héros se pose, liseré lumineux de la couleur de la rareté
-- sur un disque de pierre claire. Apparaît pendant la charge ; renvoie la fonction qui l'efface.
local function pad(landing: Vector3, rank: number, paint: ((Color3) -> ()) -> (), charge: number): () -> ()
	local radius = PAD_RADIUS + rank * 0.15
	local flat = CFrame.Angles(0, 0, math.pi / 2)
	local rim = effectPart({
		Name = "InvocationPlace",
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Neon,
		Transparency = 1,
		Size = Vector3.new(0.12, radius * 2, radius * 2),
		CFrame = CFrame.new(landing + Vector3.new(0, 0.06, 0)) * flat,
	})
	paint(function(color: Color3)
		rim.Color = color
	end)
	local stone = effectPart({
		Name = "InvocationPlaceSol",
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.SmoothPlastic,
		Color = Colors.Stone,
		Transparency = 1,
		Size = Vector3.new(0.14, radius * 2 - 0.8, radius * 2 - 0.8),
		CFrame = CFrame.new(landing + Vector3.new(0, 0.08, 0)) * flat,
	})
	local appear = TweenInfo.new(math.min(charge, 1), Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	tween(rim, appear, { Transparency = 0.15 })
	tween(stone, appear, { Transparency = 0.1 })
	local removed = false
	return function()
		if removed then
			return
		end
		removed = true
		local fade = TweenInfo.new(0.4)
		tween(rim, fade, { Transparency = 1 })
		tween(stone, fade, { Transparency = 1 })
		task.delay(0.45, function()
			rim:Destroy()
			stone:Destroy()
		end)
	end
end

-- Invocation au portail. heroTemplate n'est pas modifié : une copie locale est posée devant le portail.
function SummonEffectController.Play(portal: Model, heroTemplate: Model, options: Options?): Model?
	local opts: Options = options or {}
	local rarity = opts.Rarity
	local rank = rankOf(rarity)
	local charge = chargeOf(rank)
	local colorAt, paint, stopPalette = palette(rarity)
	local center, forward, landing = SummonEffectController.Layout(portal)
	local portalGround = ground(center, portal)
	local removePad = pad(landing, rank, paint, charge)

	-- 1. charge : vortex coloré, étincelles qui convergent vers le voile, lumière qui monte
	local vortex = portal:FindFirstChild("Vortex")
	local glow = Instance.new("Highlight")
	glow.FillTransparency = 1
	glow.OutlineTransparency = 1
	glow.DepthMode = Enum.HighlightDepthMode.Occluded
	glow.Adornee = vortex or portal
	glow.Parent = vortex or portal
	paint(function(color: Color3)
		glow.FillColor = color
		glow.OutlineColor = color
	end)
	tween(glow, TweenInfo.new(charge, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { FillTransparency = 0.25, OutlineTransparency = 0.2 })

	local core = effectPart({ Name = "InvocationCoeur", Transparency = 1, Shape = Enum.PartType.Ball, Size = Vector3.one * (10 + rank), CFrame = CFrame.new(center) })
	local inward = emitter(core, {
		Texture = SPARK_TEXTURE,
		Shape = Enum.ParticleEmitterShape.Sphere,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		Color = if rarity then RarityStyle.sequence(rarity) else ColorSequence.new(Colors.GoldLight),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.5, 0.6 + rank * 0.05), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(0.5, 0.7),
		Speed = NumberRange.new(8, 10 + rank),
		LightEmission = 1,
		Rate = 70 + 30 * (rank - 1),
	})
	inward.Enabled = true
	AudioController.Play("InvocationCharge", { Position = center, Pitch = 1 - 0.03 * (rank - 1) }) -- (#18)
	local light = Instance.new("PointLight")
	light.Range = 22 + rank * 2
	light.Brightness = 0
	light.Parent = core
	paint(function(color: Color3)
		light.Color = color
	end)
	tween(light, TweenInfo.new(charge, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Brightness = 3 + rank * 0.3 })
	if rarity == "Maudit" or rarity == "Calamite" then
		-- fumée sombre (Maudit) ou braises (Calamité) qui montent autour du portail pendant la charge
		local cursed = rarity == "Maudit"
		local smoke = emitter(core, {
			Texture = if cursed then DUST_TEXTURE else FIRE_TEXTURE,
			Shape = Enum.ParticleEmitterShape.Sphere,
			Color = if cursed then ColorSequence.new(Colors.Ink, RarityStyle.color("Maudit")) else ColorSequence.new(RarityStyle.color("Calamite"), Colors.Torch),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 4) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(1, 1.6),
			Speed = NumberRange.new(2, 5),
			Acceleration = Vector3.new(0, 4, 0),
			LightEmission = if cursed then 0 else 0.8,
			Rate = 40,
		})
		smoke.Enabled = true
		task.delay(charge + 1, function()
			smoke.Enabled = false
		end)
	end
	-- kit doré du portail : seulement pour les raretés lumineuses (pas Maudit, Calamité ni le prisme)
	if opts.Jackpot or rarity == "Legendaire" or rarity == "Mythique" or rarity == "Supreme" then
		jackpot(portal, charge + FLIGHT + REVEAL + 1.5)
	end

	-- le héros, caché jusqu'à l'éclat
	local hero = heroTemplate:Clone()
	hero.Name = "Invocation_" .. heroTemplate.Name
	for _, tag in CollectionService:GetTags(hero) do
		CollectionService:RemoveTag(hero, tag)
	end
	for _, part in hero:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
			part.LocalTransparencyModifier = 1
		end
	end
	-- repère « pieds » : centre bas de la boîte, tourné comme le modèle (lacet seulement)
	local box, size = hero:GetBoundingBox()
	local pivot = hero:GetPivot()
	local feet = box.Position - Vector3.new(0, size.Y / 2, 0)
	local feetFrame = CFrame.lookAt(feet, feet + frontOf(hero))
	local pivotInFeet = feetFrame:ToObjectSpace(pivot)
	-- le héros regarde à l'opposé du portail (vers le joueur)
	local facing = CFrame.lookAt(Vector3.zero, forward).Rotation
	local function placeFeet(at: Vector3)
		hero:PivotTo(CFrame.new(at) * facing * pivotInFeet)
	end
	placeFeet(center - Vector3.new(0, size.Y / 2, 0))
	hero.Parent = Workspace

	local silhouette = Instance.new("Highlight")
	silhouette.FillTransparency = 0
	silhouette.OutlineTransparency = 0
	silhouette.DepthMode = Enum.HighlightDepthMode.Occluded
	silhouette.Adornee = hero
	paint(function(color: Color3)
		silhouette.FillColor = color
		silhouette.OutlineColor = color
	end)

	-- 2. éclat, 3. sortie du voile
	task.delay(charge, function()
		inward.Enabled = false
		AudioController.Play("InvocationEclat", { Position = center })
		if rank >= 5 then
			AudioController.Play("Royaume", { Position = center })
		end
		if rarity == "Calamite" then
			AudioController.Play("Seisme", { Position = center })
		end
		light.Brightness = 6 + rank
		tween(light, TweenInfo.new(0.8 + rank * 0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0 })
		tween(glow, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FillTransparency = 1, OutlineTransparency = 1 })
		emitter(core, {
			Texture = SPARK_TEXTURE,
			Color = if rarity then RarityStyle.sequence(rarity) else ColorSequence.new(Colors.GoldLight, Colors.TextLight),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8 + rank * 0.05), NumberSequenceKeypoint.new(1, 0) }),
			Lifetime = NumberRange.new(0.4, 0.8 + rank * 0.05),
			Speed = NumberRange.new(10, 18 + rank * 2),
			SpreadAngle = Vector2.new(180, 180),
			Drag = 3,
			LightEmission = 1,
		}):Emit(40 + rank * 12)
		-- ondes : 1 (Commun à Rare), 2 (Épique à Mythique), 3 (Maudit à Calamité), 4 (Transcendant)
		local rings = if rank >= 10 then 4 elseif rank >= 7 then 3 elseif rank >= 4 then 2 else 1
		for i = 1, rings do
			task.delay((i - 1) * 0.18, function()
				ring(portalGround, 9 + (i - 1) * 4 + rank * 0.4, colorAt(os.clock()), 0.5 + (i - 1) * 0.12)
			end)
		end
		if rank >= 3 then
			pillar(portalGround, rank, paint, FLIGHT + REVEAL + 0.6 + rank * 0.15, rarity == "Maudit")
		end
		if rank >= 5 then
			shake(0.12 * (rank - 4) + (if rarity == "Calamite" then 0.35 else 0), 0.5 + rank * 0.06)
		end
		if rarity and rank >= 3 then
			announce(rarity, rank, paint)
		end

		for _, part in hero:GetDescendants() do
			if part:IsA("BasePart") then
				part.LocalTransparencyModifier = 0
			end
		end
		silhouette.Parent = hero
		local from = center - Vector3.new(0, size.Y / 2, 0)
		local start = os.clock()
		local connection: RBXScriptConnection
		connection = RunService.RenderStepped:Connect(function()
			if not hero.Parent then
				connection:Disconnect()
				return
			end
			local t = math.clamp((os.clock() - start) / FLIGHT, 0, 1)
			local horizontal = from:Lerp(landing, t)
			-- arc : bond hors du voile, retombe sur ses pieds devant le portail
			local arc = math.sin(math.pi * t) * 2.5
			local y = from.Y + (landing.Y - from.Y) * (t * t) + arc
			placeFeet(Vector3.new(horizontal.X, y, horizontal.Z))
			if t >= 1 then
				connection:Disconnect()
				placeFeet(landing)
				-- poussière à l'atterrissage, puis la silhouette colorée révèle le héros
				local puff = effectPart({ Transparency = 1, Size = Vector3.new(size.X, 0.4, size.Z), CFrame = CFrame.new(landing + Vector3.new(0, 0.3, 0)) })
				emitter(puff, {
					Texture = DUST_TEXTURE,
					Shape = Enum.ParticleEmitterShape.Box,
					EmissionDirection = Enum.NormalId.Top,
					Color = ColorSequence.new(Colors.Sand),
					Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 2.4) }),
					Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) }),
					Lifetime = NumberRange.new(0.5, 0.8),
					Speed = NumberRange.new(2, 4),
					SpreadAngle = Vector2.new(80, 80),
					Drag = 3,
				}):Emit(14)
				task.delay(1.2, function()
					puff:Destroy()
				end)
				tween(silhouette, TweenInfo.new(REVEAL, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FillTransparency = 1, OutlineTransparency = 1 })
				nameplate(hero, opts.Name or heroTemplate.Name, opts.New ~= false, rarity)
			end
		end)
	end)

	task.delay(charge + 1.5, function()
		core:Destroy()
		glow:Destroy()
	end)
	-- la place d'invocation s'efface avec le héros
	hero.Destroying:Connect(removePad)
	local keep = opts.Keep or 4
	task.delay(charge + FLIGHT + REVEAL + math.max(keep, 2), stopPalette)
	if keep > 0 then
		task.delay(charge + FLIGHT + REVEAL + keep, function()
			hero:Destroy()
		end)
	end
	return hero
end

-- Démonstration Studio. Le dossier peut être rangé hors du Workspace (ReplicatedStorage) pour que les
-- modèles de héros ne soient pas visibles ; le lien « Portail » est relu à chaque tour (streaming).
-- La rareté monte d'un rang à chaque tour (Commun → Transcendant, puis recommence).
local function runDemo(folder: Instance)
	local index = 0
	local shown: Model? = nil
	while folder.Parent and CollectionService:HasTag(folder, TAG_APERCU) do
		local pause = folder:GetAttribute("ApercuPause")
		task.wait(if typeof(pause) == "number" then math.max(pause, 4) else 6)
		local link = folder:FindFirstChild("Portail")
		local portal = if link and link:IsA("ObjectValue") then link.Value else nil
		local heroes: { Model } = {}
		for _, child in folder:GetChildren() do
			if child:IsA("Model") then
				table.insert(heroes, child)
			end
		end
		if portal and portal:IsA("Model") and #heroes > 0 then
			index += 1
			local template = heroes[(index - 1) % #heroes + 1]
			local name = template:GetAttribute("NomAffiche")
			if shown then
				shown:Destroy()
			end
			shown = SummonEffectController.Play(portal, template, {
				Name = if typeof(name) == "string" then name else nil,
				New = true,
				Rarity = RarityConfig.Tiers[(index - 1) % #RarityConfig.Tiers + 1].Id,
				Keep = 0,
			})
		end
	end
end

function SummonEffectController:Start()
	if not RunService:IsStudio() then
		return
	end
	for _, folder in CollectionService:GetTagged(TAG_APERCU) do
		task.spawn(runDemo, folder)
	end
	CollectionService:GetInstanceAddedSignal(TAG_APERCU):Connect(function(folder)
		task.spawn(runDemo, folder)
	end)
end

return SummonEffectController
