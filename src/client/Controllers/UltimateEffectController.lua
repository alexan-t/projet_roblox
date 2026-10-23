--!strict
-- Effets des ultimes (purement visuels, côté client) — issue #16, brief docs/ultimes/ULTIMES.md.
-- Chaque héros choisit son effet par l'attribut texte « EffetUltime » de son modèle de combat
-- (TRAVEL ci-dessous) ; l'instant du coup est l'attribut Impact de sa séquence « Ultime ».
-- Un prélude (PRELUDE) peut partir dès le début de l'animation, avant le coup.
-- Sans attribut : « Charge du Rempart », décrite ci-dessous.
-- Le héros joue son animation « Ultime » (MonsterAnimationController) ; cet effet l'accompagne :
--   1. lueur dorée sur le héros et étincelles qui montent pendant qu'il se ramasse ;
--   2. à l'impact de l'animation (ANIMATION_IMPACT), une lame d'énergie dorée part de l'épée et
--      file vers la cible (TRAVEL_TIME) ;
--   3. elle explose en anneau doré au sol, du rayon de la zone touchée, avec un éclair de lumière,
--      des étincelles et une bouffée de poussière dorée.
-- Le serveur a déjà appliqué les dégâts : CombatViewController retarde de IMPACT_DELAY les chiffres
-- de dégâts et la disparition des ennemis touchés pour qu'ils tombent avec l'anneau.
-- API : UltimateEffectController.Play(caster, center, radius, speed?) ; ImpactDelay(speed?, caster?) :
-- instant réel où le coup touche (impact de l'animation + trajet de l'effet, divisé par la vitesse).
-- Tag "ApercuUltime" (Model riggé, Studio) : démonstration en boucle, cible à 10 studs devant lui.
--   Attribut optionnel ApercuPause (s entre deux ultimes).

local CollectionService = game:GetService("CollectionService")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local AnimationSets = require(ReplicatedStorage.Shared.Animation.AnimationSets)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local AudioController = require(script.Parent.AudioController)

local TAG_APERCU = "ApercuUltime"
-- Instant du coup dans l'animation « Ultime » (style Rempart de tools/animation/AnimationKit.luau).
local ANIMATION_IMPACT = 0.3
local TRAVEL_TIME = 0.15
local RING_TIME = 0.45
local RING_SEGMENTS = 24
local DEFAULT_RADIUS = 8 -- CombatConfig.Ultimate.Radius (le client ne lit pas la config serveur)

-- Couleurs : or des emblèmes de la map (docs/UI_DESIGN_SYSTEM.md).
local GOLD = Color3.fromHex("#E6B23A")
local GOLD_LIGHT = Color3.fromHex("#F5CB5C")
local CREAM = Color3.fromHex("#FFF6E4")
local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local DUST_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"

local UltimateEffectController = {}

UltimateEffectController.IMPACT_DELAY = ANIMATION_IMPACT + TRAVEL_TIME

-- Trajet (s, à x1) entre l'impact de l'animation et le coup sur la cible, par effet.
local SHIELD_TRAVEL = 0.15
local BOLT_TRAVEL = 0.12
local TRAVEL: { [string]: number } = {
	Rempart = TRAVEL_TIME,
	RempartFerme = SHIELD_TRAVEL,
	DernierCarreau = BOLT_TRAVEL,
	HaieDeLances = 0.08,
	BraiseIndocile = 0.2,
	FendailleDeCarriere = 0.03,
	CorDesCimes = 0.15,
	MurailleDeLierre = 0.1,
	LaVeillee = 0.25,
	PiqueDuFauconnier = 0.5,
	SermentDeLaSource = 0.18,
	AccordDeFer = 0.05,
	TroisPasRasants = 0.05,
}

local function effectOf(caster: Model?): string
	local name = caster and caster:GetAttribute("EffetUltime")
	return if typeof(name) == "string" and TRAVEL[name] then name else "Rempart"
end

-- Instant du coup dans l'animation « Ultime » du héros (attribut Impact de la séquence).
local function impactOf(caster: Model?): number
	local sequence = caster and AnimationSets.find(caster, "Ultime", true)
	local impact = sequence and sequence:GetAttribute("Impact")
	return if typeof(impact) == "number" then impact else ANIMATION_IMPACT
end

function UltimateEffectController.ImpactDelay(speed: number?, caster: Model?): number
	if not caster then
		return UltimateEffectController.IMPACT_DELAY / (speed or 1)
	end
	return (impactOf(caster) + TRAVEL[effectOf(caster)]) / (speed or 1)
end

local function effectPart(props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
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

local function sparkEmitter(parent: Instance, size: number, speed: NumberRange): ParticleEmitter
	return emitter(parent, {
		Texture = SPARK_TEXTURE,
		Color = ColorSequence.new(GOLD_LIGHT),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(0.4, 0.8),
		Speed = speed,
		SpreadAngle = Vector2.new(40, 40),
		EmissionDirection = Enum.NormalId.Top,
		Drag = 2,
		LightEmission = 1,
	})
end

-- Point de départ de la lame : l'arme tenue en main droite (os ArmeDroite du squelette commun,
-- sinon d'après le nom de la pièce), sinon le bras droit.
local function weaponPosition(caster: Model, fallback: Vector3): Vector3
	local held = AnimationSets.pieces(caster, "ArmeDroite")
	if #held > 0 then
		return held[1].Position
	end
	for _, item in caster:GetDescendants() do
		if item:IsA("BasePart") then
			local name = string.lower(item.Name)
			if string.find(name, "sword", 1, true) or string.find(name, "epee", 1, true) or string.find(name, "weapon", 1, true) or string.find(name, "blade", 1, true) then
				return item.Position
			end
		end
	end
	local arm = caster:FindFirstChild("right_arm_geom", true)
	return if arm and arm:IsA("BasePart") then arm.Position else fallback
end

-- 1. Lueur sur le héros pendant qu'il se ramasse.
local function aura(caster: Model, box: CFrame, size: Vector3, speed: number, impact: number)
	local glow = Instance.new("Highlight")
	glow.Name = "UltimeLueur"
	glow.Adornee = caster
	glow.FillColor = GOLD_LIGHT
	glow.OutlineColor = GOLD
	glow.FillTransparency = 0.55
	glow.OutlineTransparency = 0.1
	glow.DepthMode = Enum.HighlightDepthMode.Occluded
	glow.Parent = caster
	local fade = TweenInfo.new(0.55 / speed, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, impact * 0.6 / speed)
	TweenService:Create(glow, fade, { FillTransparency = 1, OutlineTransparency = 1 }):Play()
	task.delay((impact + 0.7) / speed, function()
		glow:Destroy()
	end)
	local host = effectPart({ Transparency = 1, Size = Vector3.new(size.X, 0.2, size.Z), CFrame = box * CFrame.new(0, -size.Y / 2, 0) })
	sparkEmitter(host, 0.5, NumberRange.new(3, 6)):Emit(14)
	task.delay(1.5, function()
		host:Destroy()
	end)
end

-- 2 et 3. Lame qui file de l'épée vers le centre, puis anneau au sol.
local function wave(from: Vector3, center: Vector3, radius: number, speed: number)
	local travel = TRAVEL_TIME / speed
	local direction = center - from
	local flat = Vector3.new(direction.X, 0, direction.Z)
	local look = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.zAxis
	local blade = effectPart({
		Name = "UltimeLame",
		Color = GOLD_LIGHT,
		Transparency = 0.15,
		Size = Vector3.new(2.4, 0.25, 1.2),
		CFrame = CFrame.lookAt(from, from + look),
	})
	local trail = sparkEmitter(blade, 0.35, NumberRange.new(0.5, 1.5))
	trail.Rate = 120
	trail.Enabled = true
	TweenService:Create(blade, TweenInfo.new(travel, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		CFrame = CFrame.lookAt(center + Vector3.new(0, 0.6, 0), center + Vector3.new(0, 0.6, 0) + look),
		Size = Vector3.new(3.2, 0.25, 1.6),
	}):Play()
	task.delay(travel, function()
		trail.Enabled = false
		blade.Transparency = 1
		task.delay(0.8, function()
			blade:Destroy()
		end)

		-- Anneau doré : un cercle de segments qui s'élargit jusqu'au rayon de la zone touchée, reste
		-- bien visible puis s'efface sur la fin ; disque clair au centre, plus bref.
		local flatCylinder = CFrame.Angles(0, 0, math.rad(90))
		local ground = center + Vector3.new(0, 0.12, 0)
		local segments: { BasePart } = {}
		for i = 1, RING_SEGMENTS do
			segments[i] = effectPart({ Name = "UltimeAnneau", Color = GOLD, Transparency = 0.05, Size = Vector3.new(0.4, 0.2, 0.35) })
		end
		local disc = effectPart({ Name = "UltimeDisque", Shape = Enum.PartType.Cylinder, Color = CREAM, Transparency = 0.35, Size = Vector3.new(0.1, 1, 1), CFrame = CFrame.new(ground) * flatCylinder })
		TweenService:Create(disc, TweenInfo.new(RING_TIME * 0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.1, radius * 1.2, radius * 1.2), Transparency = 1 }):Play()
		local ringStart = os.clock()
		local ringLoop: RBXScriptConnection
		ringLoop = RunService.RenderStepped:Connect(function()
			local progress = math.clamp((os.clock() - ringStart) / RING_TIME, 0, 1)
			local r = math.max(0.5, radius * (1 - (1 - progress) ^ 4))
			local alpha = if progress < 0.55 then 0.05 else 0.05 + 0.95 * (progress - 0.55) / 0.45
			local length = 2 * math.pi * r / RING_SEGMENTS * 1.05 -- segments jointifs : une onde continue
			for i, segment in segments do
				local angle = 2 * math.pi * i / RING_SEGMENTS
				local offset = Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r)
				segment.Size = Vector3.new(length, 0.2, 0.5)
				segment.CFrame = CFrame.lookAt(ground + offset, ground) -- X (longueur) tangent au cercle
				segment.Transparency = alpha
			end
			if progress >= 1 then
				ringLoop:Disconnect()
				for _, segment in segments do
					segment:Destroy()
				end
			end
		end)

		local light = Instance.new("PointLight")
		light.Color = GOLD_LIGHT
		light.Range = radius * 2
		light.Brightness = 4
		light.Parent = disc
		TweenService:Create(light, TweenInfo.new(RING_TIME), { Brightness = 0 }):Play()

		local host = effectPart({ Transparency = 1, Shape = Enum.PartType.Block, Size = Vector3.new(radius * 1.4, 0.2, radius * 1.4), CFrame = CFrame.new(center) })
		emitter(host, {
			Texture = DUST_TEXTURE,
			Color = ColorSequence.new(GOLD_LIGHT:Lerp(CREAM, 0.5)),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 3) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(0.5, 0.9),
			Speed = NumberRange.new(2, 4),
			SpreadAngle = Vector2.new(70, 70),
			EmissionDirection = Enum.NormalId.Top,
			Drag = 3,
			Shape = Enum.ParticleEmitterShape.Box,
			LightEmission = 0.3,
		}):Emit(math.floor(6 + radius))
		sparkEmitter(host, 0.6, NumberRange.new(5, 10)):Emit(math.floor(14 + radius * 2))

		task.delay(RING_TIME + 1.2, function()
			disc:Destroy()
			host:Destroy()
		end)
	end)
end

local WOOD = Color3.fromHex("#6B4426")

-- Pieds du héros : HauteurPieds (modèle de combat), sinon bas des jambes, sinon bas de la boîte. Le
-- bas de la boîte ne convient pas quand l'arme ou un objet descend sous les pieds.
local function feetOf(caster: Model): Vector3
	local box, size = caster:GetBoundingBox()
	local y = box.Position.Y - size.Y / 2
	local footHeight = caster:GetAttribute("HauteurPieds")
	if typeof(footHeight) == "number" then
		y = caster:GetPivot().Position.Y - footHeight
	else
		local legs = AnimationSets.pieces(caster, "JambeGauche")
		for _, piece in AnimationSets.pieces(caster, "JambeDroite") do
			table.insert(legs, piece)
		end
		if #legs > 0 then
			y = math.huge
			for _, piece in legs do
				y = math.min(y, piece.Position.Y - piece.Size.Y / 2)
			end
		end
	end
	return Vector3.new(box.Position.X, y, box.Position.Z)
end

-- Bouffée au sol : poussière claire et éclats (fin d'un choc, impact d'un carreau).
local function puff(at: Vector3, color: Color3, amount: number)
	local host = effectPart({ Transparency = 1, Size = Vector3.new(1.5, 0.2, 1.5), CFrame = CFrame.new(at) })
	emitter(host, {
		Texture = DUST_TEXTURE,
		Color = ColorSequence.new(color),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1.8) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(0.35, 0.6),
		Speed = NumberRange.new(2, 4),
		SpreadAngle = Vector2.new(60, 60),
		EmissionDirection = Enum.NormalId.Top,
		Drag = 4,
	}):Emit(amount)
	sparkEmitter(host, 0.35, NumberRange.new(4, 8)):Emit(amount)
	task.delay(1, function()
		host:Destroy()
	end)
end

-- 01 Écuyer « Rempart Fermé » : un choc court en forme d'écu (rectangle + pointe) part du bouclier
-- planté et frappe devant lui, quelques studs seulement, puis s'efface.
local function shieldShock(caster: Model, center: Vector3, speed: number)
	local _, size = caster:GetBoundingBox()
	local feet = feetOf(caster)
	local toward = Vector3.new(center.X - feet.X, 0, center.Z - feet.Z)
	local look = if toward.Magnitude > 1e-3 then toward.Unit else caster:GetPivot().LookVector
	local start = feet + look * 1.4 + Vector3.new(0, math.max(1.2, size.Y * 0.32), 0)
	local finish = start + look * math.clamp(toward.Magnitude - 1.5, 2, 5)
	local top = effectPart({ Name = "UltimeEcu", Color = GOLD_LIGHT, Transparency = 0.25, Size = Vector3.new(2, 1.2, 0.15) })
	local tip = effectPart({ Name = "UltimeEcuPointe", Color = GOLD_LIGHT, Transparency = 0.25, Size = Vector3.new(1.42, 1.42, 0.15) })
	local travel = SHIELD_TRAVEL / speed
	local fade = 0.2 / speed
	local started = os.clock()
	local loop: RBXScriptConnection
	loop = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		local eased = 1 - (1 - math.clamp(t / travel, 0, 1)) ^ 2
		local scale = 1 + 0.35 * eased
		local at = start:Lerp(finish, eased)
		local frame = CFrame.lookAt(at, at + look)
		top.Size = Vector3.new(2 * scale, 1.2 * scale, 0.15)
		top.CFrame = frame * CFrame.new(0, 0.35 * scale, 0)
		tip.Size = Vector3.new(1.42 * scale, 1.42 * scale, 0.15)
		tip.CFrame = frame * CFrame.new(0, -0.25 * scale, 0) * CFrame.Angles(0, 0, math.rad(45))
		local alpha = if t <= travel then 0.25 else 0.25 + 0.75 * math.clamp((t - travel) / fade, 0, 1)
		top.Transparency, tip.Transparency = alpha, alpha
		if t >= travel + fade then
			loop:Disconnect()
			top:Destroy()
			tip:Destroy()
		end
	end)
	task.delay(travel, function()
		puff(Vector3.new(finish.X, feet.Y + 0.1, finish.Z), CREAM, 8)
	end)
end

-- 02 Tireuse « Le Dernier Carreau » : un carreau lourd part de l'arbalète et traverse la cible (tir
-- perforant) en laissant une fine traînée tendue ; éclats de bois à l'impact.
local function heavyBolt(caster: Model, center: Vector3, speed: number)
	local box = caster:GetBoundingBox()
	local from = weaponPosition(caster, box.Position)
	local target = center + Vector3.new(0, 1.2, 0)
	local direction = target - from
	if direction.Magnitude < 1e-3 then
		return
	end
	local finish = target + direction.Unit * 3
	local bolt = effectPart({ Name = "UltimeCarreau", Material = Enum.Material.Wood, Color = WOOD, Size = Vector3.new(0.16, 0.16, 1.4), CFrame = CFrame.lookAt(from, target) })
	local tail1 = Instance.new("Attachment")
	tail1.Position = Vector3.new(0, 0.05, 0.7)
	tail1.Parent = bolt
	local tail2 = Instance.new("Attachment")
	tail2.Position = Vector3.new(0, -0.05, 0.7)
	tail2.Parent = bolt
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = tail1, tail2
	trail.Color = ColorSequence.new(CREAM)
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	trail.Lifetime = 0.3 / speed
	trail.LightEmission = 0.6
	trail.FaceCamera = true
	trail.Parent = bolt
	local travel = BOLT_TRAVEL / speed
	local through = travel * (direction.Magnitude + 3) / direction.Magnitude
	TweenService:Create(bolt, TweenInfo.new(through, Enum.EasingStyle.Linear), { CFrame = CFrame.lookAt(finish, finish + direction.Unit) }):Play()
	task.delay(travel, function()
		puff(target, WOOD:Lerp(CREAM, 0.5), 10)
	end)
	task.delay(through + 0.05, function()
		bolt.Transparency = 1
		task.delay(0.4, function()
			bolt:Destroy()
		end)
	end)
end

local IRON = Color3.fromHex("#C9CED6")
local EMBER = Color3.fromHex("#FF8A2B")
local STONE_DARK = Color3.fromHex("#3B2F2A")
local STONE_DUST = Color3.fromHex("#9C8B78")
local PINE = Color3.fromHex("#CDE6A0")

-- Bout de l'arme tenue en main droite : extrémité de sa plus longue dimension, la plus haute (tête du
-- bâton tenu debout), la plus basse (lowest) ou la plus proche de toward (pointe d'une lance), sinon
-- la position de l'arme.
local function weaponTip(caster: Model, fallback: Vector3, lowest: boolean?, toward: Vector3?): Vector3
	local held = AnimationSets.pieces(caster, "ArmeDroite")
	local part = held[1]
	if not part then
		return weaponPosition(caster, fallback)
	end
	local size = part.Size
	local axis = if size.X >= size.Y and size.X >= size.Z then part.CFrame.XVector
		elseif size.Y >= size.Z then part.CFrame.YVector else part.CFrame.ZVector
	local half = math.max(size.X, size.Y, size.Z) / 2
	local a, b = part.Position + axis * half, part.Position - axis * half
	if toward then
		return if (a - toward).Magnitude < (b - toward).Magnitude then a else b
	end
	if lowest then
		return if a.Y < b.Y then a else b
	end
	return if a.Y > b.Y then a else b
end

local function flatLook(from: Vector3, to: Vector3, caster: Model): Vector3
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	return if flat.Magnitude > 1e-3 then flat.Unit else caster:GetPivot().LookVector
end

-- 03 Lancier « Haie de Lances » : trois traits de fer sobres en éventail, un par estoc (0, +0,15, +0,3 s).
local function spearFan(caster: Model, center: Vector3, speed: number)
	local box = caster:GetBoundingBox()
	local look = flatLook(box.Position, center, caster)
	for i, yaw in { -20, 0, 20 } do
		task.delay((i - 1) * 0.15 / speed, function()
			if not caster.Parent then
				return
			end
			local dir = CFrame.Angles(0, math.rad(yaw), 0) * look
			-- part de la pointe de la lance à cet estoc
			local start = weaponTip(caster, box.Position, false, box.Position + dir * 30)
			local streak = effectPart({ Name = "UltimeTraitFer", Material = Enum.Material.Metal, Color = IRON, Transparency = 0.15, Size = Vector3.new(0.3, 0.06, 0.2) })
			local grow = 0.08 / speed
			local t0 = os.clock()
			local loop: RBXScriptConnection
			loop = RunService.RenderStepped:Connect(function()
				local t = os.clock() - t0
				local length = 3.5 * math.clamp(t / grow, 0, 1)
				streak.Size = Vector3.new(0.3, 0.06, math.max(0.2, length))
				streak.CFrame = CFrame.lookAt(start + dir * length / 2, start + dir * length)
				streak.Transparency = if t <= grow then 0.15 else 0.15 + 0.85 * math.clamp((t - grow) / (0.18 / speed), 0, 1)
				if t >= grow + 0.18 / speed then
					loop:Disconnect()
					streak:Destroy()
				end
			end)
		end)
	end
end

local function ember(at: Vector3, size: number): Part
	local ball = effectPart({ Name = "UltimeBraise", Shape = Enum.PartType.Ball, Color = EMBER, Size = Vector3.one * size, CFrame = CFrame.new(at) })
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = EMBER, 4, 1.5
	light.Parent = ball
	return ball
end

-- 04 Pyromancien « Braise Indocile », prélude : la gemme du bâton tousse trois petites braises.
local function emberCough(caster: Model, speed: number)
	task.delay(0.12 / speed, function()
		if not caster.Parent then
			return
		end
		local tip = weaponTip(caster, caster:GetPivot().Position)
		for i = 1, 3 do
			local spark = ember(tip, 0.22)
			local angle = math.rad(120 * i)
			local hop = tip + Vector3.new(math.cos(angle) * 0.7, 0.9, math.sin(angle) * 0.7)
			TweenService:Create(spark, TweenInfo.new(0.25 / speed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = CFrame.new(hop) }):Play()
			TweenService:Create(spark, TweenInfo.new(0.2 / speed, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.22 / speed), { Transparency = 1, Size = Vector3.one * 0.05 }):Play()
			task.delay(0.5 / speed, function()
				spark:Destroy()
			end)
		end
	end)
end

-- 04 Pyromancien, coup : il propulse une braise qui frappe la cible puis rebondit sur une seconde.
local function emberBounce(caster: Model, center: Vector3, speed: number)
	local tip = weaponTip(caster, caster:GetPivot().Position)
	local first = center + Vector3.new(0, 1, 0)
	local look = flatLook(tip, center, caster)
	local second = first + look:Cross(Vector3.yAxis) * 3 + look * 1.5
	local ball = ember(tip, 0.4)
	local trail = sparkEmitter(ball, 0.3, NumberRange.new(0.5, 1.5))
	trail.Color = ColorSequence.new(EMBER)
	trail.Rate = 60
	trail.Enabled = true
	local leg1 = 0.2 / speed
	local leg2 = 0.18 / speed
	TweenService:Create(ball, TweenInfo.new(leg1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = CFrame.new(first) }):Play()
	task.delay(leg1, function()
		puff(first - Vector3.new(0, 1, 0), EMBER, 6)
		TweenService:Create(ball, TweenInfo.new(leg2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = CFrame.new(second) }):Play()
	end)
	task.delay(leg1 + leg2, function()
		trail.Enabled = false
		ball.Transparency = 1
		puff(second - Vector3.new(0, 1, 0), EMBER, 6)
		task.delay(0.6, function()
			ball:Destroy()
		end)
	end)
end

-- 05 Brise-Pierre « Fendaille de Carrière » : sous la masse, le sol s'ouvre en une fissure d'une seule
-- longueur de masse, poussière de pierre.
local function quarryCrack(caster: Model, center: Vector3, speed: number)
	local box = caster:GetBoundingBox()
	-- Sol = pieds du héros, pas le bas de la boîte : la masse y est déjà enfoncée.
	local floor = feetOf(caster).Y + 0.06
	local head = weaponTip(caster, box.Position, true)
	local look = flatLook(caster:GetPivot().Position, center, caster)
	local side = look:Cross(Vector3.yAxis)
	local origin = Vector3.new(head.X, floor, head.Z)
	local segments: { BasePart } = {}
	local count = 6
	local length = 4
	local previous = origin
	for i = 1, count do
		local zig = if i % 2 == 0 then 0.25 else -0.25
		local point = origin + look * length * i / count + side * zig * (1 - i / count)
		local piece = effectPart({ Name = "UltimeFissure", Material = Enum.Material.Slate, Color = STONE_DARK, Transparency = 1, Size = Vector3.new(0.5 * (1 - (i - 1) / count) + 0.15, 0.06, (point - previous).Magnitude + 0.1), CFrame = CFrame.lookAt((previous + point) / 2, point) })
		segments[i] = piece
		task.delay(0.025 * i / speed, function()
			piece.Transparency = 0
		end)
		previous = point
	end
	puff(origin, STONE_DUST, 12)
	task.delay(0.6 / speed, function()
		for _, piece in segments do
			TweenService:Create(piece, TweenInfo.new(0.3 / speed), { Transparency = 1 }):Play()
		end
		task.delay(0.35 / speed, function()
			for _, piece in segments do
				piece:Destroy()
			end
		end)
	end)
end

-- 06 Guetteuse « Cor des Cimes », prélude : l'appel du cor, deux ondes fines qui partent de sa tête.
-- (Le modèle n'a pas de cor : la main libre monte à la bouche, l'onde dit l'appel.)
local function hornCall(caster: Model, speed: number)
	local box, size = caster:GetBoundingBox()
	local head = box.Position + Vector3.new(0, size.Y * 0.35, 0)
	for i = 0, 1 do
		task.delay((0.18 + i * 0.1) / speed, function()
			if not caster.Parent then
				return
			end
			local ring = effectPart({ Name = "UltimeCor", Shape = Enum.PartType.Cylinder, Color = PINE, Transparency = 0.45, Size = Vector3.new(0.05, 0.6, 0.6), CFrame = CFrame.new(head) * CFrame.Angles(0, 0, math.rad(90)) })
			TweenService:Create(ring, TweenInfo.new(0.4 / speed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.05, 5, 5), Transparency = 1 }):Play()
			task.delay(0.45 / speed, function()
				ring:Destroy()
			end)
		end)
	end
end

-- 06 Guetteuse, coup : la flèche file vers la cible, où se dessine le contour très fin d'un pin.
local function pineArrow(caster: Model, center: Vector3, speed: number)
	local box = caster:GetBoundingBox()
	local from = weaponPosition(caster, box.Position)
	local target = center + Vector3.new(0, 1.4, 0)
	local direction = target - from
	if direction.Magnitude < 1e-3 then
		return
	end
	local arrow = effectPart({ Name = "UltimeFleche", Material = Enum.Material.Wood, Color = WOOD, Size = Vector3.new(0.08, 0.08, 1.5), CFrame = CFrame.lookAt(from, target) })
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.04, 0.7)
	a0.Parent = arrow
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.04, 0.7)
	a1.Parent = arrow
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Color = ColorSequence.new(PINE)
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	trail.Lifetime = 0.25 / speed
	trail.LightEmission = 0.7
	trail.FaceCamera = true
	trail.Parent = arrow
	local travel = 0.15 / speed
	TweenService:Create(arrow, TweenInfo.new(travel, Enum.EasingStyle.Linear), { CFrame = CFrame.lookAt(target, target + direction.Unit) }):Play()
	-- Pin : trois étages (deux traits obliques chacun) et un tronc, lignes très fines.
	local look = flatLook(from, center, caster)
	local side = look:Cross(Vector3.yAxis)
	local base = center + Vector3.new(0, 0.1, 0)
	local lines: { BasePart } = {}
	local function line(a: Vector3, b: Vector3)
		local part = effectPart({ Name = "UltimePin", Color = PINE, Transparency = 0.3, Size = Vector3.new(0.05, 0.05, (b - a).Magnitude), CFrame = CFrame.lookAt((a + b) / 2, b) })
		table.insert(lines, part)
	end
	line(base, base + Vector3.new(0, 0.8, 0))
	for tier = 0, 2 do
		local y = 0.8 + tier * 1.1
		local w = 1.5 - tier * 0.4
		local apex = base + Vector3.new(0, y + 1.5, 0)
		line(base + Vector3.new(0, y, 0) - side * w, apex)
		line(base + Vector3.new(0, y, 0) + side * w, apex)
	end
	for _, part in lines do
		TweenService:Create(part, TweenInfo.new(0.35 / speed, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, travel), { Transparency = 1 }):Play()
	end
	task.delay(travel, function()
		arrow.Transparency = 1
		trail.Enabled = false
		puff(target, PINE, 6)
	end)
	task.delay(travel + 0.6 / speed, function()
		arrow:Destroy()
		for _, part in lines do
			part:Destroy()
		end
	end)
end

local IVY = Color3.fromHex("#4F8A3A")
local AMBER = Color3.fromHex("#F2A93B")
local WATER = Color3.fromHex("#5BB8E8")
local STEEL = Color3.fromHex("#B8C2CC")
local WIND = Color3.fromHex("#DDF3FF")

-- Petite pièce qui suit un chemin (t de 0 à 1) en laissant une traînée ; détruite à la fin.
local function ribbon(color: Color3, width: number, duration: number, path: (number) -> Vector3, onDone: (() -> ())?)
	local head = effectPart({ Name = "UltimeRuban", Shape = Enum.PartType.Ball, Color = color, Transparency = 0.2, Size = Vector3.one * width * 1.4, CFrame = CFrame.new(path(0)) })
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, width / 2, 0)
	a0.Parent = head
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -width / 2, 0)
	a1.Parent = head
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Color = ColorSequence.new(color)
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
	trail.Lifetime = math.max(0.15, duration * 0.5)
	trail.LightEmission = 0.5
	trail.FaceCamera = true
	trail.Parent = head
	local started = os.clock()
	local loop: RBXScriptConnection
	loop = RunService.RenderStepped:Connect(function()
		local t = math.clamp((os.clock() - started) / duration, 0, 1)
		head.CFrame = CFrame.new(path(t))
		if t >= 1 then
			loop:Disconnect()
			head.Transparency = 1
			if onDone then
				onDone()
			end
			task.delay(trail.Lifetime + 0.1, function()
				head:Destroy()
			end)
		end
	end)
end

-- Alliés proches du lanceur dans l'arène (modèles frères qui portent HeroInstanceId) ; sinon deux
-- points de part et d'autre, derrière lui (atelier).
local function nearAllies(caster: Model, count: number): { Vector3 }
	local list: { { Vector3 } } = {}
	local origin = caster:GetPivot().Position
	local parent = caster.Parent
	for _, other in if parent then parent:GetChildren() else {} do
		if other ~= caster and other:IsA("Model") and other:GetAttribute("HeroInstanceId") then
			local p = other:GetPivot().Position
			table.insert(list, { p, (p - origin).Magnitude } :: any)
		end
	end
	table.sort(list, function(a: any, b: any): boolean
		return a[2] < b[2]
	end)
	local result: { Vector3 } = {}
	for i = 1, math.min(count, #list) do
		table.insert(result, (list[i] :: any)[1])
	end
	if #result == 0 then
		local frame = caster:GetPivot()
		result = { (frame * CFrame.new(-4, 0, 3)).Position, (frame * CFrame.new(4, 0, 3)).Position }
	end
	return result
end

-- 07 Chevalier du Lierre « Muraille de Lierre » : trois grosses tiges de lierre jaillissent devant
-- le bouclier comme un parapet miniature, puis se rétractent.
local function ivyWall(caster: Model, center: Vector3, speed: number)
	local feet = feetOf(caster)
	local look = flatLook(feet, center, caster)
	local side = look:Cross(Vector3.yAxis)
	for i, offset in { -1.3, 0, 1.3 } do
		local base = feet + look * 2.2 + side * offset
		local height = if i == 2 then 2.6 else 2.1
		local stalk = effectPart({ Name = "UltimeLierre", Material = Enum.Material.Grass, Shape = Enum.PartType.Cylinder, Color = IVY, Size = Vector3.new(0.1, 0.7, 0.7), CFrame = CFrame.new(base) * CFrame.Angles(0, 0, math.rad(90)) })
		local up = TweenInfo.new(0.14 / speed, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, (i - 1) * 0.04 / speed)
		TweenService:Create(stalk, up, { Size = Vector3.new(height, 0.7, 0.7), CFrame = CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)) }):Play()
		task.delay(0.65 / speed, function()
			TweenService:Create(stalk, TweenInfo.new(0.2 / speed, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = Vector3.new(0.1, 0.7, 0.7), CFrame = CFrame.new(base) * CFrame.Angles(0, 0, math.rad(90)) }):Play()
			task.delay(0.22 / speed, function()
				stalk:Destroy()
			end)
		end)
	end
	puff(feet + look * 2.2, IVY:Lerp(CREAM, 0.5), 8)
end

-- 08 Mage des Lanternes « La Veillée » : un ruban ambré part de la lanterne, rejoint deux alliés,
-- puis revient dans la lanterne.
local function lanternVigil(caster: Model, _center: Vector3, speed: number)
	local held = AnimationSets.pieces(caster, "ArmeGauche")
	local box = caster:GetBoundingBox()
	local lantern = if held[1] then held[1].Position else box.Position
	for i, ally in nearAllies(caster, 2) do
		local target = ally + Vector3.new(0, 1.5, 0)
		local function arc(a: Vector3, b: Vector3): (number) -> Vector3
			return function(t: number): Vector3
				return a:Lerp(b, t) + Vector3.new(0, math.sin(t * math.pi) * 1.5, 0)
			end
		end
		task.delay((i - 1) * 0.05 / speed, function()
			ribbon(AMBER, 0.25, 0.25 / speed, arc(lantern, target), function()
				puff(ally, AMBER, 5)
				ribbon(AMBER, 0.18, 0.3 / speed, arc(target, lantern))
			end)
		end)
	end
end

-- 09 Fauconnier Gris « Piqué du Fauconnier » : le faucon quitte le gant en spirale, replie les ailes,
-- pique sur la cible, puis revient se poser. Le vrai faucon est masqué pendant le vol (copie).
local function falconDive(caster: Model, center: Vector3, speed: number)
	local falcon: BasePart? = nil
	for _, item in caster:GetDescendants() do
		if item:IsA("BasePart") and string.find(string.lower(item.Name), "falcon", 1, true) then
			falcon = item
		end
	end
	if not falcon then
		return
	end
	local bird = falcon:Clone()
	for _, child in bird:GetChildren() do
		if not child:IsA("SurfaceAppearance") then
			child:Destroy()
		end
	end
	bird.Name = "UltimeFaucon"
	bird.Anchored, bird.CanCollide, bird.CanQuery, bird.CanTouch = true, false, false, false
	bird.Parent = Workspace
	falcon.LocalTransparencyModifier = 1
	local start = falcon.CFrame
	local target = center + Vector3.new(0, 1.2, 0)
	local apex = start.Position:Lerp(target, 0.35) + Vector3.new(0, 6, 0)
	local rise, dive, back = 0.3 / speed, 0.2 / speed, 0.35 / speed
	local started = os.clock()
	local loop: RBXScriptConnection
	loop = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		local at: Vector3
		local facing: Vector3
		if t < rise then
			local u = t / rise
			local angle = u * math.pi * 2
			at = start.Position:Lerp(apex, u) + Vector3.new(math.cos(angle), 0, math.sin(angle)) * 1.5 * (1 - u)
			facing = apex - at
		elseif t < rise + dive then
			local u = (t - rise) / dive
			at = apex:Lerp(target, u * u)
			facing = target - apex
		else
			local u = math.clamp((t - rise - dive) / back, 0, 1)
			local home = falcon.Position
			at = target:Lerp(home, u) + Vector3.new(0, math.sin(u * math.pi) * 2.5, 0)
			facing = home - target
		end
		bird.CFrame = if facing.Magnitude > 1e-3 then CFrame.lookAt(at, at + facing) else CFrame.new(at)
		if t >= rise + dive + back then
			loop:Disconnect()
			bird:Destroy()
			falcon.LocalTransparencyModifier = 0
		end
	end)
	task.delay(rise + dive, function()
		puff(center, CREAM, 8)
	end)
end

-- 10 Lancière des Sources « Serment de la Source » : un étroit ruban d'eau suit la pointe en
-- demi-cercle devant elle, puis éclate en gouttes contre la première ligne.
local function sourceArc(caster: Model, center: Vector3, speed: number)
	local feet = feetOf(caster)
	local look = flatLook(feet, center, caster)
	local side = look:Cross(Vector3.yAxis)
	local radius = 3.2
	local height = feet.Y + 1.6
	ribbon(WATER, 0.3, 0.18 / speed, function(t: number): Vector3
		local angle = math.rad(-80 + 160 * t)
		local p = feet + look * math.cos(angle) * radius - side * math.sin(angle) * radius
		return Vector3.new(p.X, height, p.Z)
	end, function()
		local front = feet + look * (radius + 1.5)
		local host = effectPart({ Transparency = 1, Size = Vector3.new(2, 0.2, 2), CFrame = CFrame.new(front + Vector3.new(0, 1, 0)) })
		emitter(host, {
			Color = ColorSequence.new(WATER),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0.05) }),
			Lifetime = NumberRange.new(0.3, 0.5),
			Speed = NumberRange.new(5, 9),
			SpreadAngle = Vector2.new(60, 60),
			EmissionDirection = Enum.NormalId.Top,
			Acceleration = Vector3.new(0, -30, 0),
			LightEmission = 0.2,
		}):Emit(18)
		task.delay(1, function()
			host:Destroy()
		end)
	end)
end

-- Onde au sol : anneau fin qui s'élargit (notes du Barde, poussée du Moine).
local function groundRing(at: Vector3, color: Color3, reach: number, duration: number)
	local ring = effectPart({ Name = "UltimeOnde", Shape = Enum.PartType.Cylinder, Color = color, Transparency = 0.25, Size = Vector3.new(0.08, 0.8, 0.8), CFrame = CFrame.new(at + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.rad(90)) })
	TweenService:Create(ring, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.08, reach, reach), Transparency = 1 }):Play()
	task.delay(duration + 0.05, function()
		ring:Destroy()
	end)
end

-- 11 Barde de Fer « Accord de Fer » : la cloche-masse frappe ; deux notes métalliques visibles (deux
-- ondes d'acier) se propagent au sol l'une après l'autre.
local function ironChord(caster: Model, center: Vector3, speed: number)
	local feet = feetOf(caster)
	local look = flatLook(feet, center, caster)
	local origin = feet + look * 1.6
	for i = 0, 1 do
		task.delay(i * 0.14 / speed, function()
			groundRing(origin, STEEL, 9 + i * 3, 0.45 / speed)
		end)
	end
	puff(origin, STEEL:Lerp(CREAM, 0.5), 6)
end

-- 12 Moine du Vent Bas « Trois Pas Rasants » : deux frappes de paume (souffles d'air de part et
-- d'autre) puis une poussée circulaire autour de lui.
local function lowWind(caster: Model, center: Vector3, speed: number)
	local feet = feetOf(caster)
	local look = flatLook(feet, center, caster)
	local side = look:Cross(Vector3.yAxis)
	for i, dir in { side, -side } do
		task.delay((i - 1) * 0.15 / speed, function()
			if caster.Parent then
				puff(feet + look * 1.5 + dir * 1.2 + Vector3.new(0, 1, 0), WIND, 8)
			end
		end)
	end
	task.delay(0.32 / speed, function()
		groundRing(feet, WIND, 8, 0.35 / speed)
	end)
end

-- Effets au coup (impact de l'animation) et préludes (début de l'animation), par EffetUltime.
local STRIKES: { [string]: (Model, Vector3, number) -> () } = {
	RempartFerme = shieldShock,
	DernierCarreau = heavyBolt,
	HaieDeLances = spearFan,
	BraiseIndocile = emberBounce,
	FendailleDeCarriere = quarryCrack,
	CorDesCimes = pineArrow,
	MurailleDeLierre = ivyWall,
	LaVeillee = lanternVigil,
	PiqueDuFauconnier = falconDive,
	SermentDeLaSource = sourceArc,
	AccordDeFer = ironChord,
	TroisPasRasants = lowWind,
}
local PRELUDE: { [string]: (Model, number) -> () } = {
	BraiseIndocile = emberCough,
	CorDesCimes = hornCall,
}

-- Lance l'effet. caster : modèle du héros ; center : point AU SOL au centre de la zone touchée ;
-- radius : rayon de l'anneau (studs). Renvoie IMPACT_DELAY (instant où l'anneau éclate).
-- Annonce « ce héros lance son ultime » (en plus de son animation et de l'onde) : capte l'attention
-- sur le lanceur, pas sur la cible.
--   - « ULTIME ! » au-dessus du héros (Fredoka Title, GoldLight, contour Ink Large) : rebond, tenue,
--     puis montée et fondu ;
--   - colonne de lumière dorée qui jaillit du héros et se resserre ;
--   - onde dorée au sol qui s'élargit sous ses pieds, avec un éclair de lumière.
function UltimateEffectController.Announce(caster: Model, speed: number?)
	local rate = speed or 1
	local box, bounds = caster:GetBoundingBox()
	local size: any = bounds
	local feet = box.Position - Vector3.new(0, size.Y / 2, 0)
	local typography = UITheme.Typography
	local animation: any = UITheme.Animation

	local gui = Instance.new("BillboardGui")
	gui.Name = "AnnonceUltime"
	gui.Size = UDim2.fromOffset(240, 64)
	gui.StudsOffsetWorldSpace = Vector3.new(0, size.Y / 2 + 3.6, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = UITheme.World.CombatDistance
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.FontFace = typography.Display
	text.TextSize = typography.Size.Title
	text.TextColor3 = UITheme.Colors.GoldLight
	text.Text = "ULTIME !"
	text.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = UITheme.Stroke.Color
	stroke.Thickness = typography.TextStroke.Large
	stroke.LineJoinMode = UITheme.Stroke.LineJoin
	stroke.Parent = text
	local scale = Instance.new("UIScale")
	scale.Scale = animation.Scale.OpenFrom
	scale.Parent = text
	gui.Parent = caster
	TweenService:Create(scale, TweenInfo.new(animation.Toast.Time / rate, animation.Toast.EasingStyle, animation.Toast.EasingDirection), {
		Scale = animation.Scale.Pop,
	}):Play()
	task.delay((animation.Toast.Time + 0.55) / rate, function()
		if not gui.Parent then return end
		local fade = TweenInfo.new(0.4 / rate, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(gui, fade, { StudsOffsetWorldSpace = gui.StudsOffsetWorldSpace + Vector3.new(0, 1.5, 0) }):Play()
		TweenService:Create(text, fade, { TextTransparency = 1 }):Play()
		TweenService:Create(stroke, fade, { Transparency = 1 }):Play()
		task.delay(0.45 / rate, function() gui:Destroy() end)
	end)

	-- Colonne de lumière : haute et large au départ, elle se resserre en s'effaçant.
	local height = size.Y * 3.2
	local pillar = effectPart({
		Shape = Enum.PartType.Cylinder,
		Color = GOLD_LIGHT,
		Transparency = 0.5, -- le héros reste visible dans la colonne
		Size = Vector3.new(height, math.max(size.X, size.Z) * 1.1, math.max(size.X, size.Z) * 1.1),
		CFrame = CFrame.new(feet + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
	})
	local flash = Instance.new("PointLight")
	flash.Color = GOLD_LIGHT
	flash.Range = 18
	flash.Brightness = 4
	flash.Parent = pillar
	local pillarFade = TweenInfo.new(0.45 / rate, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(pillar, pillarFade, { Transparency = 1, Size = Vector3.new(height, 0.4, 0.4) }):Play()
	TweenService:Create(flash, pillarFade, { Brightness = 0 }):Play()

	-- Onde au sol sous le héros.
	local ring = effectPart({
		Shape = Enum.PartType.Cylinder,
		Color = GOLD,
		Transparency = 0.2,
		Size = Vector3.new(0.15, 2, 2),
		CFrame = CFrame.new(feet + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
	})
	local reach = math.max(size.X, size.Z) * 3 + 6
	TweenService:Create(ring, TweenInfo.new(0.5 / rate, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.15, reach, reach),
		Transparency = 1,
	}):Play()
	local host = effectPart({ Transparency = 1, Size = Vector3.new(size.X, 0.2, size.Z), CFrame = CFrame.new(feet) })
	sparkEmitter(host, 0.7, NumberRange.new(8, 14)):Emit(24)
	task.delay(1.2 / rate, function()
		pillar:Destroy()
		ring:Destroy()
	end)
	task.delay(1.5, function() host:Destroy() end)
end

function UltimateEffectController.Play(caster: Model, center: Vector3, radius: number?, speed: number?): number
	local scale = speed or 1
	if not caster.Parent then
		return 0
	end
	local box, size = caster:GetBoundingBox()
	local impact = impactOf(caster)
	local effect = effectOf(caster)
	aura(caster, box, size, scale, impact)
	local prelude = PRELUDE[effect]
	if prelude then
		prelude(caster, scale)
	end
	-- sons (#18) : lancement, puis le coup
	AudioController.Play("UltimeLancement", { Position = box.Position })
	AudioController.Play("UltimeImpact", { Delay = UltimateEffectController.ImpactDelay(scale, caster), Position = center })
	task.delay(impact / scale, function()
		if not caster.Parent then
			return
		end
		local strike = STRIKES[effect]
		if strike then
			strike(caster, center, scale)
		else
			wave(weaponPosition(caster, box.Position), center, radius or DEFAULT_RADIUS, scale)
		end
	end)
	return UltimateEffectController.ImpactDelay(scale, caster)
end

-- Démonstration Studio : l'animation « Ultime » du jeu de combat du modèle (attribut
-- JeuAnimationsCombat, sinon JeuAnimations, puis jeu commun : AnimationSets), enregistrée à la volée, puis l'effet.
local function demoTrack(model: Model): AnimationTrack?
	local sequence = AnimationSets.find(model, "Ultime", true)
	local controller = model:FindFirstChildOfClass("AnimationController")
	local animator = controller and controller:FindFirstChildOfClass("Animator")
	if not sequence or not animator then
		warn(`[UltimateEffect] {model:GetFullName()} : animation Ultime ou Animator introuvable`)
		return nil
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = KeyframeSequenceProvider:RegisterKeyframeSequence(sequence)
	local track = (animator :: Animator):LoadAnimation(animation)
	track.Priority = Enum.AnimationPriority.Action
	return track
end

local function runDemo(model: Model)
	-- Avec le streaming, le modèle arrive avant ses pièces : attendre la racine et l'Animator.
	local deadline = os.clock() + 15
	while model.Parent and not (model.PrimaryPart and model:FindFirstChildOfClass("AnimationController")) and os.clock() < deadline do
		task.wait(0.2)
	end
	local track = demoTrack(model)
	while model.Parent and CollectionService:HasTag(model, TAG_APERCU) do
		local pause = model:GetAttribute("ApercuPause")
		local speed = model:GetAttribute("ApercuVitesse") or (model.Parent and model.Parent:GetAttribute("ApercuVitesse"))
		speed = if typeof(speed) == "number" and speed > 0 then speed else 1
		-- tout le cycle (pause comprise) suit la vitesse, comme la cadence du combat en x2
		task.wait((if typeof(pause) == "number" then math.max(pause, 1.5) else 2) / speed)
		local root = model.PrimaryPart
		if not root then
			continue
		end
		if track then
			track:Play(0.1)
			track:AdjustSpeed(speed)
		end
		local box, size = model:GetBoundingBox()
		local feet = Vector3.new(box.Position.X, box.Position.Y - size.Y / 2, box.Position.Z)
		UltimateEffectController.Play(model, feet + root.CFrame.LookVector * 10, DEFAULT_RADIUS, speed)
		task.wait(1 / speed)
	end
end

function UltimateEffectController:Start()
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

return UltimateEffectController
