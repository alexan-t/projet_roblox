--!strict
-- VFX d'invocation et d'apparition du héros (purement visuel, côté client) — issue #17.
-- Joué au portail d'invocation de la map (PortailInvocation) ; HeroService (#10) fournit le héros obtenu.
-- Déroulé (≈ 3 s) :
--   1. charge : le vortex s'illumine d'or, des étincelles convergent vers le voile, le halo au sol monte ;
--   2. éclat : flash du voile, lumière, onde dorée au sol ;
--   3. le héros jaillit du voile en silhouette dorée, se pose devant le portail (poussière), puis la
--      silhouette s'efface et révèle le héros ;
--   4. son nom s'affiche au-dessus (Fredoka, contour Ink) avec le badge « Nouveau ».
-- Option Jackpot : utilise le kit EffetJackpot préparé dans le portail par le design (faisceau vers le
-- ciel, cœur, lumière, étincelles, étoile) pour un tirage exceptionnel. Aucune rareté n'est inventée :
-- c'est HeroService qui décidera quand l'utiliser.
-- API : SummonEffectController.Play(portal, heroTemplate, options?) -> modèle affiché (copie locale).
--   options = { Name: string?, New: boolean?, Jackpot: boolean?, Keep: number? (s avant de retirer la
--   copie, 4 par défaut ; 0 = la garder) }
-- Démonstration Studio : tag "ApercuInvocation" sur un dossier qui contient des modèles de héros et un
-- ObjectValue « Portail » ; un héros sort toutes les ApercuPause secondes (6 par défaut), jackpot 1 fois sur 3.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local AudioController = require(script.Parent.AudioController)

local TAG_APERCU = "ApercuInvocation"
local CHARGE = 1.2 -- montée en puissance avant l'éclat
local FLIGHT = 0.45 -- sortie du voile jusqu'au sol
local REVEAL = 0.6 -- la silhouette dorée s'efface
local LANDING_DISTANCE = 7 -- studs devant le voile
local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local DUST_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"

local Colors = UITheme.Colors
local SummonEffectController = {}

export type Options = { Name: string?, New: boolean?, Jackpot: boolean?, Keep: number? }

local function tween(instance: Instance, info: TweenInfo, goal: { [string]: any }): Tween
	local t = TweenService:Create(instance, info, goal)
	t:Play()
	return t
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

-- Onde dorée au sol (cercle de segments jointifs qui s'élargit puis s'efface).
local function ring(center: Vector3, radius: number)
	local count = 28
	local segments: { BasePart } = {}
	for i = 1, count do
		segments[i] = effectPart({ Name = "InvocationOnde", Material = Enum.Material.Neon, Color = Colors.Gold, Size = Vector3.new(1, 0.2, 0.5) })
	end
	local floor = center + Vector3.new(0, 0.12, 0)
	local start = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local progress = math.clamp((os.clock() - start) / 0.5, 0, 1)
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

local function banner(hero: Model, name: string, isNew: boolean)
	local typography = UITheme.Typography
	local _, size = hero:GetBoundingBox()
	local gui = Instance.new("BillboardGui")
	gui.Name = "InvocationNom"
	gui.Size = UDim2.fromOffset(360, 74)
	gui.StudsOffsetWorldSpace = Vector3.new(0, size.Y / 2 + 2, 0)
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

-- Invocation au portail. heroTemplate n'est pas modifié : une copie locale est posée devant le portail.
function SummonEffectController.Play(portal: Model, heroTemplate: Model, options: Options?): Model?
	local opts: Options = options or {}
	-- le voile (disque au centre de l'arche) donne le centre et la face avant du portail
	local structure = portal:FindFirstChild("Structure")
	local found = if structure then structure:FindFirstChild("voile") else portal:FindFirstChild("voile", true)
	local veil: BasePart? = if found and found:IsA("BasePart") then found else nil
	local center = if veil then veil.Position else portal:GetBoundingBox().Position
	local forward = if veil then veil.CFrame.LookVector else portal:GetPivot().LookVector
	forward = Vector3.new(forward.X, 0, forward.Z).Unit
	local landing = ground(center + forward * LANDING_DISTANCE, portal)
	local portalGround = ground(center, portal)

	-- 1. charge : vortex doré, étincelles qui convergent vers le voile, lumière qui monte
	local vortex = portal:FindFirstChild("Vortex")
	local glow = Instance.new("Highlight")
	glow.FillColor = Colors.GoldLight
	glow.OutlineColor = Colors.Gold
	glow.FillTransparency = 1
	glow.OutlineTransparency = 1
	glow.DepthMode = Enum.HighlightDepthMode.Occluded
	glow.Adornee = vortex or portal
	glow.Parent = vortex or portal
	tween(glow, TweenInfo.new(CHARGE, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { FillTransparency = 0.25, OutlineTransparency = 0.2 })

	local core = effectPart({ Name = "InvocationCoeur", Transparency = 1, Shape = Enum.PartType.Ball, Size = Vector3.one * 10, CFrame = CFrame.new(center) })
	local inward = emitter(core, {
		Texture = SPARK_TEXTURE,
		Shape = Enum.ParticleEmitterShape.Sphere,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		Color = ColorSequence.new(Colors.GoldLight),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.5, 0.6), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(0.5, 0.7),
		Speed = NumberRange.new(8, 10),
		LightEmission = 1,
		Rate = 70,
	})
	inward.Enabled = true
	AudioController.Play("InvocationCharge", { Position = center }) -- (#18)
	local light = Instance.new("PointLight")
	light.Color = Colors.GoldLight
	light.Range = 22
	light.Brightness = 0
	light.Parent = core
	tween(light, TweenInfo.new(CHARGE, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Brightness = 3 })
	if opts.Jackpot then
		jackpot(portal, CHARGE + FLIGHT + REVEAL + 1.5)
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
	local function placeFeet(feet: Vector3)
		hero:PivotTo(CFrame.new(feet) * facing * pivotInFeet)
	end
	placeFeet(center - Vector3.new(0, size.Y / 2, 0))
	hero.Parent = Workspace

	local silhouette = Instance.new("Highlight")
	silhouette.FillColor = Colors.GoldLight
	silhouette.OutlineColor = Colors.Gold
	silhouette.FillTransparency = 0
	silhouette.OutlineTransparency = 0
	silhouette.DepthMode = Enum.HighlightDepthMode.Occluded
	silhouette.Adornee = hero

	-- 2. éclat, 3. sortie du voile
	task.delay(CHARGE, function()
		inward.Enabled = false
		AudioController.Play("InvocationEclat", { Position = center })
		light.Brightness = 6
		tween(light, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0 })
		tween(glow, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FillTransparency = 1, OutlineTransparency = 1 })
		emitter(core, {
			Texture = SPARK_TEXTURE,
			Color = ColorSequence.new(Colors.GoldLight, Colors.TextLight),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) }),
			Lifetime = NumberRange.new(0.4, 0.8),
			Speed = NumberRange.new(10, 18),
			SpreadAngle = Vector2.new(180, 180),
			Drag = 3,
			LightEmission = 1,
		}):Emit(40)
		ring(portalGround, 9)

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
				-- poussière à l'atterrissage, puis la silhouette dorée révèle le héros
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
				banner(hero, opts.Name or heroTemplate.Name, opts.New ~= false)
			end
		end)
	end)

	task.delay(CHARGE + 1.5, function()
		core:Destroy()
		glow:Destroy()
	end)
	local keep = opts.Keep or 4
	if keep > 0 then
		task.delay(CHARGE + FLIGHT + REVEAL + keep, function()
			hero:Destroy()
		end)
	end
	return hero
end

-- Démonstration Studio. Le dossier peut être rangé hors du Workspace (ReplicatedStorage) pour que les
-- modèles de héros ne soient pas visibles ; le lien « Portail » est relu à chaque tour (streaming).
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
				Jackpot = index % 3 == 0,
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
