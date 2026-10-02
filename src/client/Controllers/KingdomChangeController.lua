--!strict
-- Feedback visuel du changement de royaume (purement visuel, côté client) — issue #17.
-- KingdomService remplace le modèle « Kingdom » du plot (Runtime) quand Kingdom.VisualState change.
-- Côté client, ce remplacement devient une montée de niveau lisible (≈ 1,5 s) :
--   1. un nuage de poussière et un flash doré jaillissent du sol : l'ancien royaume disparaît dedans ;
--   2. le nouveau royaume sort du sol et monte, avec un léger dépassement ;
--   3. une onde dorée court au sol, des étincelles montent ;
--   4. « Royaume niveau N ! » s'affiche au-dessus (design system : Fredoka, Gold, contour Ink), puis s'efface.
-- Les royaumes comptent des centaines de pièces : rien n'est animé pièce par pièce (seul le pivot bouge).
-- Détection : un Model « Kingdom » ajouté dans un dossier « Runtime » qui affichait déjà un royaume
-- d'un autre niveau (attribut VisualState). Le premier affichage (arrivée du joueur, streaming) ne
-- déclenche rien.
-- API : KingdomChangeController.Play(kingdom, level?, previous?) ; previous = ancien modèle à cacher.
-- Tag "ApercuRoyaume" (Folder, Studio) : ses Models (attribut VisualState ou Niveau) se succèdent en
--   boucle au même endroit. Attribut optionnel ApercuPause (s entre deux montées, 3 par défaut).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)

local TAG_APERCU = "ApercuRoyaume"
local KINGDOM_NAME = "Kingdom"
local RUNTIME_NAME = "Runtime"
local HIDE_AT = 0.2 -- l'ancien royaume disparaît dans le nuage
local RISE_START = 0.25
local RISE_TIME = 0.75
local RING_AT = RISE_START + RISE_TIME * 0.8
local BANNER_HOLD = 2.5
local DUST_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

local Colors = UITheme.Colors
local KingdomChangeController = {}

local levels: { [Instance]: number } = {} -- dernier niveau affiché par dossier Runtime

local function levelOf(model: Instance): number?
	local value = model:GetAttribute("VisualState") or model:GetAttribute("Niveau")
	return if typeof(value) == "number" then value else nil
end

local hiding: { [Model]: RBXScriptConnection } = {}

local function applyHidden(item: Instance, hidden: boolean)
	if item:IsA("BasePart") or item:IsA("Decal") or item:IsA("Texture") then
		item.LocalTransparencyModifier = if hidden then 1 else 0
	end
end

-- Cache ou montre un modèle. Avec le streaming, ses pièces arrivent par morceaux : tant qu'il est
-- caché, celles qui arrivent ensuite sont cachées aussi.
local function setHidden(model: Model, hidden: boolean)
	local watcher = hiding[model]
	if watcher then
		watcher:Disconnect()
		hiding[model] = nil
	end
	for _, item in model:GetDescendants() do
		applyHidden(item, hidden)
	end
	if hidden then
		hiding[model] = model.DescendantAdded:Connect(function(item)
			applyHidden(item, true)
		end)
	end
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

-- 1. Nuage de poussière et étincelles à la base du royaume.
local function cloud(base: Vector3, footprint: number)
	local host = effectPart({ Name = "RoyaumeNuage", Transparency = 1, Size = Vector3.new(footprint, 1, footprint), CFrame = CFrame.new(base + Vector3.new(0, 0.5, 0)) })
	local size = math.clamp(footprint * 0.18, 3, 7)
	emitter(host, {
		Texture = DUST_TEXTURE,
		Shape = Enum.ParticleEmitterShape.Box,
		EmissionDirection = Enum.NormalId.Top,
		Color = ColorSequence.new(Colors.Sand:Lerp(Colors.Cream, 0.4)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size * 0.6), NumberSequenceKeypoint.new(0.3, size), NumberSequenceKeypoint.new(1, size * 1.6) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(0.9, 1.4),
		Speed = NumberRange.new(4, 9),
		SpreadAngle = Vector2.new(70, 70),
		Drag = 3,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-40, 40),
		LightEmission = 0.15,
	}):Emit(math.floor(footprint * 1.6))
	emitter(host, {
		Texture = SPARK_TEXTURE,
		Shape = Enum.ParticleEmitterShape.Box,
		EmissionDirection = Enum.NormalId.Top,
		Color = ColorSequence.new(Colors.GoldLight),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(0.8, 1.6),
		Speed = NumberRange.new(8, 16),
		SpreadAngle = Vector2.new(30, 30),
		Drag = 1.5,
		LightEmission = 1,
	}):Emit(math.floor(footprint * 0.9))
	local light = Instance.new("PointLight")
	light.Color = Colors.GoldLight
	light.Range = footprint
	light.Brightness = 3
	light.Parent = host
	TweenService:Create(light, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0 }):Play()
	task.delay(2.5, function()
		host:Destroy()
	end)
end

-- 3. Onde dorée au sol : cercle de segments jointifs qui s'élargit puis s'efface.
local function ring(center: Vector3, radius: number)
	local count = 32
	local segments: { BasePart } = {}
	for i = 1, count do
		segments[i] = effectPart({ Name = "RoyaumeOnde", Material = Enum.Material.Neon, Color = Colors.Gold, Size = Vector3.new(1, 0.25, 0.6) })
	end
	local ground = center + Vector3.new(0, 0.15, 0)
	local start = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local progress = math.clamp((os.clock() - start) / 0.6, 0, 1)
		local r = radius * (0.3 + 0.7 * (1 - (1 - progress) ^ 3))
		local alpha = if progress < 0.5 then 0.05 else 0.05 + 0.95 * (progress - 0.5) / 0.5
		for i, segment in segments do
			local angle = 2 * math.pi * i / count
			local offset = Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r)
			segment.Size = Vector3.new(2 * math.pi * r / count * 1.05, 0.25, 0.6)
			segment.CFrame = CFrame.lookAt(ground + offset, ground)
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

-- 4. Panneau « Royaume niveau N ! » au-dessus du royaume.
local function banner(kingdom: Model, level: number?, height: number)
	local typography = UITheme.Typography
	local gui = Instance.new("BillboardGui")
	gui.Name = "RoyaumeNiveau"
	gui.Size = UDim2.fromOffset(420, 70)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height / 2 + 4, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 250
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.FontFace = typography.Display
	text.TextSize = typography.Size.Title
	text.TextColor3 = Colors.Gold
	text.Text = if level then `Royaume niveau {level} !` else "Le royaume grandit !"
	text.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = UITheme.Stroke.Color
	stroke.Thickness = typography.TextStroke.Medium
	stroke.LineJoinMode = UITheme.Stroke.LineJoin
	stroke.Parent = text
	local scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = text
	gui.Parent = kingdom
	local animation = UITheme.Animation
	local up = TweenService:Create(scale, TweenInfo.new(animation.Toast.Time * 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = animation.Scale.Pop })
	up.Completed:Connect(function()
		TweenService:Create(scale, TweenInfo.new(animation.Toast.Time * 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end)
	up:Play()
	task.delay(animation.Toast.Time + BANNER_HOLD, function()
		if not gui.Parent then
			return
		end
		local fade = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(gui, fade, { StudsOffsetWorldSpace = gui.StudsOffsetWorldSpace + Vector3.new(0, 1.5, 0) }):Play()
		TweenService:Create(text, fade, { TextTransparency = 1 }):Play()
		TweenService:Create(stroke, fade, { Transparency = 1 }):Play()
		task.delay(0.4, function()
			gui:Destroy()
		end)
	end)
end

-- Montée de niveau : kingdom est le nouveau royaume (déjà posé à sa place), previous l'ancien s'il
-- est encore là (il est caché dans le nuage). Renvoie la durée de l'effet.
function KingdomChangeController.Play(kingdom: Model, level: number?, previous: Model?): number
	local box, size = kingdom:GetBoundingBox()
	local base = Vector3.new(box.Position.X, box.Position.Y - size.Y / 2, box.Position.Z)
	local footprint = math.max(size.X, size.Z)
	local finalPivot = kingdom:GetPivot()
	local depth = size.Y * 0.85

	-- le nouveau royaume attend sous le sol, caché
	setHidden(kingdom, true)
	kingdom:PivotTo(finalPivot - Vector3.new(0, depth, 0))

	local flash = Instance.new("Highlight")
	flash.FillColor = Colors.GoldLight
	flash.FillTransparency = 0.35
	flash.OutlineTransparency = 1
	flash.DepthMode = Enum.HighlightDepthMode.Occluded
	if previous and previous.Parent then
		flash.Adornee = previous
		flash.Parent = previous
		TweenService:Create(flash, TweenInfo.new(HIDE_AT), { FillTransparency = 0 }):Play()
	end
	cloud(base, footprint)
	task.delay(HIDE_AT, function()
		if previous and previous.Parent then
			setHidden(previous, true)
		end
		flash:Destroy()
	end)

	-- 2. le nouveau royaume sort du sol, léger dépassement (Back) puis se pose
	task.delay(RISE_START, function()
		if not kingdom.Parent then
			return
		end
		setHidden(kingdom, false)
		local start = os.clock()
		local connection: RBXScriptConnection
		connection = RunService.RenderStepped:Connect(function()
			if not kingdom.Parent then
				connection:Disconnect()
				return
			end
			local t = math.clamp((os.clock() - start) / RISE_TIME, 0, 1)
			-- easeOutBack : dépasse un peu sa place puis s'y pose
			local c1, c3 = 1.4, 2.4
			local eased = 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
			kingdom:PivotTo(finalPivot - Vector3.new(0, depth * (1 - eased), 0))
			if t >= 1 then
				connection:Disconnect()
				kingdom:PivotTo(finalPivot)
			end
		end)
	end)

	task.delay(RING_AT, function()
		ring(base, footprint * 0.75)
	end)
	task.delay(RISE_START + RISE_TIME * 0.6, function()
		if kingdom.Parent then
			banner(kingdom, level, size.Y)
		end
	end)
	return RISE_START + RISE_TIME
end

-- Jeu : un royaume « Kingdom » arrive dans un dossier Runtime de plot.
local function onKingdom(kingdom: Model)
	local runtime = kingdom.Parent
	if not runtime or runtime.Name ~= RUNTIME_NAME then
		return
	end
	local level = levelOf(kingdom)
	local previous = levels[runtime]
	levels[runtime] = level or previous
	if previous and level and level ~= previous then
		KingdomChangeController.Play(kingdom, level)
	end
end

-- Démonstration Studio : les royaumes du dossier se succèdent en boucle au même endroit.
local function runDemo(folder: Instance)
	local states: { Model } = {}
	for _, child in folder:GetChildren() do
		if child:IsA("Model") and levelOf(child) then
			table.insert(states, child)
		end
	end
	table.sort(states, function(a: Model, b: Model): boolean
		return (levelOf(a) :: number) < (levelOf(b) :: number)
	end)
	if #states < 2 then
		warn(`[KingdomChange] {folder:GetFullName()} : il faut au moins deux royaumes (attribut VisualState ou Niveau)`)
		return
	end
	for i, model in states do
		setHidden(model, i ~= 1)
	end
	local index = 1
	while folder.Parent and CollectionService:HasTag(folder, TAG_APERCU) do
		local pause = folder:GetAttribute("ApercuPause")
		task.wait(if typeof(pause) == "number" then math.max(pause, 1.5) else 3)
		local previous = states[index]
		index = index % #states + 1
		local nextState = states[index]
		KingdomChangeController.Play(nextState, levelOf(nextState), previous)
	end
	for _, model in states do
		setHidden(model, false)
	end
end

function KingdomChangeController:Start()
	for _, item in Workspace:GetDescendants() do
		if item:IsA("Model") and item.Name == KINGDOM_NAME and item.Parent and item.Parent.Name == RUNTIME_NAME then
			local level = levelOf(item)
			if level then
				levels[item.Parent] = level
			end
		end
	end
	Workspace.DescendantAdded:Connect(function(item)
		if item:IsA("Model") and item.Name == KINGDOM_NAME then
			-- le clone arrive avec ses enfants : laisser passer la réplication du modèle complet
			task.defer(onKingdom, item)
		end
	end)
	Workspace.DescendantRemoving:Connect(function(item)
		if item.Name == RUNTIME_NAME then
			levels[item] = nil
		end
	end)
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

return KingdomChangeController
